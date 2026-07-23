#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "M1 LOCAL GATE FAIL: required command is missing: $1" >&2
		exit 1
	fi
}

require_command git
require_command luau
require_command luau-analyze
require_command luau-compile
require_command rg

echo "[1/8] Compile every version-controlled Luau source"
compiled=0
while IFS= read -r source; do
	luau-compile "$source" >/dev/null
	compiled=$((compiled + 1))
done < <(git ls-files '*.luau' && git ls-files --others --exclude-standard '*.luau')
if (( compiled == 0 )); then
	echo "M1 LOCAL GATE FAIL: no Luau sources were discovered" >&2
	exit 1
fi
echo "PASS: ${compiled} Luau sources compiled"

echo "[2/8] Analyze and run deterministic contract tests"
test_sources=()
while IFS= read -r source; do
	test_sources+=("$source")
done < <(
	{
		printf '%s\n' tests/run.luau CooperTransactionLedger.module.luau
		find tests/support tests/specs -type f -name '*.luau' -print
	} | sort -u
)
luau-analyze "${test_sources[@]}"
luau tests/run.luau

echo "[3/8] Exercise all core-server compiler register profiles"
bash verify_runtime_register_budget.sh

echo "[4/8] Reject whitespace damage"
git diff --check

echo "[5/8] Verify frozen Milestone 1 configuration contracts"
rg -Fq 'Config.SchemaVersion = 12' CooperFamilyTaskConfig.module.luau
rg -Fq 'Config.ReleasePlayerCap = 4' CooperFamilyTaskConfig.module.luau
rg -Fq 'Lobby = true' CooperFamilyTaskConfig.module.luau
for feature in Horror SecretExploration TimeMachineFinale Postgame StudioScenarioTools; do
	rg -Fq "${feature} = false" CooperFamilyTaskConfig.module.luau
done
rg -Fq 'LobbyPlaceId = 100748614383412' CooperFamilyTaskConfig.module.luau lobby/CooperLobbyConfig.module.luau
rg -Fq 'HousePlaceId = 98645411943406' CooperFamilyTaskConfig.module.luau lobby/CooperLobbyConfig.module.luau
rg -Fq 'UniverseId = 10480337589' CooperFamilyTaskConfig.module.luau lobby/CooperLobbyConfig.module.luau
echo "PASS: schema, capacity, place IDs, and feature flags are locked"

echo "[6/8] Verify value-operation closure and retired broad currency APIs"
for marker in \
	'CandyProduce' \
	'CandyCollect' \
	'CandySale' \
	'InstallTaskUpgrade' \
	'InstallChemistrySetup' \
		'InstallBoombox' \
		'InstallMachineStage' \
		'BoomboxTick' \
		'BoomboxSettle'
do
	rg -q "\"${marker}" CooperFamilyTaskGame.server.luau
done
rg -q 'DeprecatedOperation: use a named authoritative value operation' CooperFamilyTaskGame.server.luau
if rg -q 'local function adjustAllowance' CooperFamilyTaskGame.server.luau; then
	echo "M1 LOCAL GATE FAIL: legacy broad allowance helper is active" >&2
	exit 1
fi
echo "PASS: rewards, payouts, installs, and retired APIs use the expected closure"

echo "[7/8] Scan active clients for forbidden progression authority"
active_clients=()
while IFS= read -r source; do
	active_clients+=("$source")
done < <(
	{
		git ls-files '*client.luau' 'lobby/*client.luau'
		git ls-files --others --exclude-standard '*client.luau' 'lobby/*client.luau'
	} | sort -u | rg -v '^legacy/'
)
for client in "${active_clients[@]}"; do
	if rg -n \
		-e ":(FireServer|InvokeServer)\\([\"'](CompleteTask|AwardAllowance|SetAllowance|AdjustAllowance)" \
		-e 'leaderstats\.Allowance\.Value\s*=' \
		-e "SetAttribute\\([\"']PartyHostUserId" \
		-e "GetService\\([\"']MemoryStoreService[\"']\\)" \
		"$client"
	then
		echo "M1 LOCAL GATE FAIL: client authority pattern found in $client" >&2
		exit 1
	fi
done
echo "PASS: ${#active_clients[@]} active clients contain no forbidden authority pattern"

echo "[8/8] Confirm production source excludes retired/debug runtime surfaces"
if rg -n \
	-e 'StudioScenarioTools\\s*=\\s*true' \
	-e 'Horror\\s*=\\s*true' \
	-e 'CooperCrisis' \
	-e 'CooperPanic' \
	--glob '*.luau' \
	--glob '!legacy/**' \
	--glob '!tests/**' \
		--glob '!verify_*.luau' \
		--glob '!**/*install*.luau' \
		--glob '!simple_gameplay_cleanup.luau' \
		--glob '!lobby/StudioHousePreview.server.luau'
then
	echo "M1 LOCAL GATE FAIL: disabled/retired production surface was found" >&2
	exit 1
fi
echo "PASS: future and retired runtime surfaces remain disabled"

echo "M1 LOCAL GATE PASS: local deterministic/static evidence is clean"
echo "NOTE: this command cannot prove published TeleportService/MemoryStore/DataStore,"
echo "      physical-device input, multiplayer replication, or human visual acceptance."
