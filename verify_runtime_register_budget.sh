#!/usr/bin/env bash
#
# Core server compiler preflight.
#
# Roblox/Studio can reject a script for exceeding the 200-register limit even
# when the default local `luau-compile` profile succeeds. Run this matrix before
# syncing a candidate into Studio. Invoke with:
#
#   bash verify_runtime_register_budget.sh

set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="${LUAU_COMPILE:-luau-compile}"

if ! command -v "$COMPILER" >/dev/null 2>&1; then
	echo "[RuntimeRegisterPreflight] FAIL: '$COMPILER' is not available."
	exit 2
fi

CORE_SCRIPTS=(
	"CooperFamilyTaskGame.server.luau"
	"CooperBunker.server.luau"
	"CooperFamilyTaskWorld.server.luau"
)

# O1/g1 is the ordinary local baseline that previously produced a false pass.
# Exercise the complete supported optimization/debug matrix so a future change
# cannot move register pressure into a profile that this gate happens to skip.
COMPILE_PROFILES=(
	"0:0:register-guard"
	"0:1:register-guard"
	"0:2:register-guard"
	"1:0:register-guard"
	"1:1:baseline"
	"1:2:studio-debug-guard"
	"2:0:register-guard"
	"2:1:register-guard"
	"2:2:register-guard"
)

failures=0
checks=0

for relative_path in "${CORE_SCRIPTS[@]}"; do
	absolute_path="$ROOT_DIR/$relative_path"
	if [[ ! -f "$absolute_path" ]]; then
		echo "[RuntimeRegisterPreflight] FAIL: missing $relative_path"
		failures=$((failures + 1))
		continue
	fi

	for profile in "${COMPILE_PROFILES[@]}"; do
		optimization="${profile%%:*}"
		remainder="${profile#*:}"
		debug="${remainder%%:*}"
		label="${profile##*:}"
		checks=$((checks + 1))

		if diagnostic="$("$COMPILER" --null -O"$optimization" -g"$debug" "$absolute_path" 2>&1)"; then
			echo "[RuntimeRegisterPreflight] PASS $relative_path O$optimization/g$debug ($label)"
		else
			echo "[RuntimeRegisterPreflight] FAIL $relative_path O$optimization/g$debug ($label)"
			if [[ -n "$diagnostic" ]]; then
				while IFS= read -r line; do
					echo "  $line"
				done <<< "$diagnostic"
			fi
			failures=$((failures + 1))
		fi
	done
done

if [[ "$failures" -ne 0 ]]; then
	echo "[RuntimeRegisterPreflight] RESULT: FAIL — $failures of $checks compiler-profile checks failed."
	echo "[RuntimeRegisterPreflight] Default compilation alone is not release evidence."
	exit 1
fi

echo "[RuntimeRegisterPreflight] RESULT: PASS — $checks compiler-profile checks passed."
