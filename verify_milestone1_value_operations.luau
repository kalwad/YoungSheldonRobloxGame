--!nonstrict
-- Non-mutating Milestone 1 audit for every value-bearing path that was outside
-- the first schema-12 journal pass. Safe in edit mode or a running test.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local checks = 0

local function check(condition, message)
	checks += 1
	assert(condition, "[M1ValueOperations] " .. message)
end

local function need(parent, name, className)
	local child = parent:FindFirstChild(name)
	check(child ~= nil, parent:GetFullName() .. " is missing " .. name)
	check(child and child:IsA(className), child:GetFullName() .. " must be a " .. className)
	return child
end

local function sourceOf(container)
	check(container:IsA("LuaSourceContainer"), container:GetFullName() .. " is not source-bearing")
	local ok, source = pcall(function()
		return container.Source
	end)
	check(ok and type(source) == "string" and #source > 1000, container:GetFullName() .. " source is unreadable")
	return source
end

local function section(source, startMarker, endMarker, label)
	local startAt = string.find(source, startMarker, 1, true)
	check(startAt ~= nil, label .. " is missing start marker " .. startMarker)
	local endAt = startAt and string.find(source, endMarker, startAt + #startMarker, true) or nil
	check(endAt ~= nil, label .. " is missing end marker " .. endMarker)
	return string.sub(source, startAt, endAt - 1)
end

local function has(source, marker, message)
	check(string.find(source, marker, 1, true) ~= nil, message or ("Source is missing " .. marker))
end

local function lacks(source, marker, message)
	check(string.find(source, marker, 1, true) == nil, message or ("Source unexpectedly contains " .. marker))
end

local function countPlain(source, marker)
	local count = 0
	local cursor = 1
	while true do
		local at = string.find(source, marker, cursor, true)
		if not at then
			return count
		end
		count += 1
		cursor = at + #marker
	end
end

local root = need(ReplicatedStorage, "CooperGame", "Folder")
local configModule = need(root, "Config", "ModuleScript")
local ledgerModule = need(root, "TransactionLedger", "ModuleScript")
local gameServer = need(ServerScriptService, "CooperGame", "Script")
local taskWorld = need(ServerScriptService, "CooperTaskWorld", "Script")
local ledgerSource = sourceOf(ledgerModule)
local gameSource = sourceOf(gameServer)
local worldSource = sourceOf(taskWorld)

local Config = require(configModule)
local ledger = require(ledgerModule)
check(type(Config.Boombox) == "table", "Config.Boombox is missing")
check(
	Config.Boombox.PayoutPerTick * Config.Boombox.MaximumPaidTicks == 300,
	"One completed boombox song must equal exactly $300"
)
check(type(ledger.logicalKind) == "function", "TransactionLedger.logicalKind is missing")
check(ledger.logicalKind("CandySale", "abc-123") == "CandySale:abc-123", "Logical kinds are not stable")
check(ledger.logicalKind("CandySale", "bad path") == nil, "Logical kinds accept unsafe text")
check(ledger.logicalKind("CandySale", string.rep("a", 64)) == nil, "Logical kinds exceed the 64-character journal bound")
has(ledgerSource, 'string.match(key, "^[%w_:%-]+$")', "Ledger logical-key allowlist is missing")

local coordinator = section(
	gameSource,
	"function TransactionRuntime.commitPersistentTransition",
	"local function pickHiddenLocation",
	"persistent-transition coordinator"
)
for _, marker in ipairs({
	"TransactionRuntime.findLogicalOperation(profile, kind)",
	"TransactionRuntime.commitProfileValueOperation(",
	"existing and existing.id or nil",
	"TransactionReconciliation",
}) do
	has(coordinator, marker, "Persistent-transition coordinator is missing " .. marker)
end

local candy = section(
	gameSource,
	"local function createCandyBatch",
	"local hostWorldActionEvents",
	"candy value lifecycle"
)
for _, marker in ipairs({
	'logicalOperationKind("CandyProduce"',
	'logicalOperationKind("CandyCollect"',
	'logicalOperationKind("CandySale"',
	"TransactionRuntime.commitPersistentTransition(",
	"profile.data.candyBatchesSold",
	"setAllowance(profile, profile.data.allowance + payout)",
}) do
	has(candy, marker, "Candy lifecycle is missing " .. marker)
end
check(
	countPlain(candy, "TransactionRuntime.commitPersistentTransition(") == 3,
	"Candy production, collection, and sale must each have one operation"
)
check(countPlain(candy, "setAllowance(") == 1, "Candy lifecycle has an extra allowance mutation")
lacks(candy, "task.defer(saveProfile", "Candy value lifecycle bypasses the journal with a deferred save")

local installs = section(
	gameSource,
	"local function reportPlayerAction",
	"reportAction.Event:Connect",
	"paid install transitions"
)
for _, marker in ipairs({
	'"InstallChemistrySetup"',
	'"InstallBoombox"',
	'"InstallTaskUpgrade",',
	'"InstallMachineStage",',
}) do
	has(installs, marker, "Paid install transition is missing " .. marker)
end
check(
	countPlain(installs, "TransactionRuntime.commitPersistentTransition(") == 4,
	"Exactly four paid physical install transitions must use the journal"
)
lacks(installs, "task.defer(saveProfile", "A paid install still relies on a deferred save")

local purchaseSavePending = section(
	gameSource,
	"function TransactionRuntime.commitHostPurchase",
	"local function orderMachinePart",
	"accepted purchase save-pending UX"
)
for _, marker in ipairs({
	"if accepted and not durable then",
	"feedback(profile.player, \"TransactionReconciliation\"",
	"title = \"SAVING PURCHASE\"",
	"return true, false, \"SavePendingAccepted\"",
}) do
	has(purchaseSavePending, marker, "Accepted purchase save-pending UX is missing " .. marker)
end

local sanitizer = section(
	gameSource,
	"local function sanitizeData(raw)",
	"local function profileKey(player)",
	"boombox settlement sanitizer"
)
for _, marker in ipairs({
	"local boomboxPlaced = raw.boomboxPlaced == true",
	"local boomboxPurchased = raw.boomboxPurchased == true or boomboxPlaced",
	"if boomboxPurchased and boomboxPlaced",
	"TransactionLedger.logicalKind(\"BoomboxSettle\", settlementSessionId) ~= nil",
	"totalPaid == paidTicks * payoutPerTick",
	"totalPaid + settlementValue == maximumPayout",
	"boomboxPendingSettlement = boomboxPendingSettlement",
}) do
	has(sanitizer, marker, "Boombox sanitizer is missing " .. marker)
end

local boomboxTick = section(
	gameSource,
	"function TransactionRuntime.creditBoomboxTick",
	"function TransactionRuntime.settleCompletedBoombox",
	"boombox tick lifecycle"
)
for _, marker in ipairs({
	'"BoomboxTick"',
	"requestedTickIndex",
	"TransactionRuntime.commitPersistentTransition(",
	"setAllowance(profile, profile.data.allowance + payout)",
}) do
	has(boomboxTick, marker, "Boombox tick lifecycle is missing " .. marker)
end
check(
	countPlain(boomboxTick, "TransactionRuntime.commitPersistentTransition(") == 1
		and countPlain(boomboxTick, "setAllowance(") == 1,
	"Each indexed boombox tick must have exactly one journaled allowance mutation"
)

local boomboxSettle = section(
	gameSource,
	"function TransactionRuntime.settleCompletedBoombox",
	"-- Recover a completed song without any dependency on the old Sound, Player",
	"live boombox settlement"
)
for _, marker in ipairs({
	'"BoomboxSettle"',
	"profile.data.boomboxPendingSettlement = intent",
	"TransactionRuntime.safeSave(profile)",
	"playback.settlementIntentDurable = true",
	"TransactionRuntime.boomboxValueReconciliationPending(profile, playback.sessionId)",
	"TransactionRuntime.commitPersistentTransition(",
	"setAllowance(profile, profile.data.allowance + settlementValue)",
	"profile.data.boomboxPendingSettlement = false",
	"playback.settlementValue",
}) do
	has(boomboxSettle, marker, "Live boombox settlement is missing " .. marker)
end
check(
	countPlain(boomboxSettle, "TransactionRuntime.commitPersistentTransition(") == 1
		and countPlain(boomboxSettle, "setAllowance(") == 1,
	"Live completed-song settlement must have exactly one catch-up mutation"
)

local boomboxRecovery = section(
	gameSource,
	"function TransactionRuntime.recoverPendingBoomboxSettlement",
	"local function boomboxPayoutTick",
	"detached boombox settlement recovery"
)
for _, marker in ipairs({
	"local intent = profile.data.boomboxPendingSettlement",
	"TransactionRuntime.logicalOperationKind(\"BoomboxSettle\", sessionId)",
	"existing and existing.state == \"Committed\"",
	"existing and existing.state == \"NeedsReconciliation\"",
	"TransactionRuntime.commitPersistentTransition(",
	"setAllowance(profile, profile.data.allowance + settlementValue)",
	"feedback(profile.player, \"BoomboxPayoutSaving\"",
	"title = \"FULL PAYOUT EARNED — SAVING\"",
	"feedback(profile.player, \"BoomboxFinished\"",
	"title = \"FULL PAYOUT SAVED\"",
}) do
	has(boomboxRecovery, marker, "Detached boombox recovery is missing " .. marker)
end
check(
	countPlain(boomboxRecovery, "TransactionRuntime.commitPersistentTransition(") == 1
		and countPlain(boomboxRecovery, "setAllowance(") == 1,
	"Detached settlement recovery must have exactly one catch-up mutation"
)
lacks(
	boomboxRecovery,
	"boomboxPlaybackOwner ==",
	"Detached settlement recovery still depends on the departed playback owner"
)

local boomboxEnd = section(
	gameSource,
	"local function finalizeBoomboxPlayback",
	"local function endBoomboxPlaybackForPlayer",
	"boombox completion presentation"
)
for _, marker in ipairs({
	"if durable == false then",
	"feedback(profile.player, \"BoomboxPayoutSaving\"",
	"title = \"FULL PAYOUT EARNED — SAVING\"",
	"savePending = durable == false",
	"TransactionRuntime.settleCompletedBoombox(profile, playback)",
	"if accepted then",
	"return finalizeBoomboxPlayback(",
}) do
	has(boomboxEnd, marker, "Boombox accepted-save-pending UX is missing " .. marker)
end
lacks(
	boomboxEnd,
	"TransactionRuntime.commitPersistentTransition(",
	"Boombox cleanup/presentation must not own a third settlement mutation"
)

local boomboxDeparture = section(
	gameSource,
	"function TransactionRuntime.playerLifecycle.onPlayerRemoving",
	"function TransactionRuntime.playerLifecycle.onClose",
	"boombox departure detachment"
)
for _, marker in ipairs({
	"endBoomboxPlayback(profile, departingPlayback.sessionId, \"PlayerLeaving\", true)",
	"local intent = profile.data.boomboxPendingSettlement",
	"intent.sessionId == departingPlayback.sessionId",
	"departingPlayback.finalized = true",
	"profile.boomboxPlayback = nil",
}) do
	has(boomboxDeparture, marker, "Boombox departure detachment is missing " .. marker)
end

local boomboxMaintenance = section(
	gameSource,
	"function TransactionRuntime.runMaintenanceLoop",
	"function TransactionRuntime.runSessionHeartbeatLoop",
	"boombox recovery maintenance"
)
for _, marker in ipairs({
	"type(sharedHostProfile.data.boomboxPendingSettlement) == \"table\"",
	"TransactionRuntime.recoverPendingBoomboxSettlement",
	"not TransactionRuntime.boomboxSettlementPending(sharedHostProfile)",
}) do
	has(boomboxMaintenance, marker, "Boombox maintenance recovery is missing " .. marker)
end
has(
	worldSource,
	"session.sessionId,\n\t\t\t\t\ttickIndex",
	"TaskWorld does not send an authoritative tick index"
)
check(
	countPlain(section(
		worldSource,
		"local function runBoomboxPayouts",
		"finishBoomboxPlayback = function",
		"boombox scheduler"
	), "tickIndex") >= 3,
	"Boombox scheduler does not retain the same tick identity through retry"
)
has(
	worldSource,
	"repeat\n\t\t\t\tlocal tickResult = invokeFamily(",
	"Boombox scheduler does not retry a recoverable indexed tick through the song"
)

local api = section(
	gameSource,
	"serverAPI.OnInvoke = function",
	"local function passRequestCooldown",
	"server API"
)
has(
	api,
	'operation == "AdjustCurrency" or operation == "SpendAllowance"',
	"Legacy broad currency operations are not explicitly retired"
)
has(api, "DeprecatedOperation", "Retired currency operations do not fail closed")
lacks(gameSource, "local function adjustAllowance", "Legacy unjournaled allowance helper remains active")

print(string.format(
	"[M1ValueOperations] PASS — %d checks; candy, boombox, paid installs, and legacy currency APIs are journal-safe",
	checks
))
