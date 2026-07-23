-- Run in the Studio command bar after installing the family-task foundation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function requireChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(child, parent:GetFullName() .. " is missing " .. name)
	assert(child.ClassName == className, child:GetFullName() .. " must be a " .. className)
	return child
end

local function sourceSection(source, startMarker, endMarker)
	local startAt = string.find(source, startMarker, 1, true)
	assert(startAt, "Source is missing section marker " .. startMarker)
	local endAt = string.find(source, endMarker, startAt + #startMarker, true)
	assert(endAt, "Source is missing section terminator " .. endMarker)
	return string.sub(source, startAt, endAt - 1), startAt, endAt
end

local function countPlain(source, marker)
	local count = 0
	local cursor = 1
	while true do
		local found = string.find(source, marker, cursor, true)
		if not found then
			return count
		end
		count += 1
		cursor = found + #marker
	end
end

local root = requireChild(ReplicatedStorage, "CooperGame", "Folder")
local configModule = requireChild(root, "Config", "ModuleScript")
local transactionLedgerModule = requireChild(root, "TransactionLedger", "ModuleScript")
local state = requireChild(root, "State", "Folder")
local remotes = requireChild(root, "Remotes", "Folder")
for _, name in ipairs({ "Snapshot", "Feedback", "Request", "BankHack" }) do
	requireChild(remotes, name, "RemoteEvent")
end

local config
if RunService:IsRunning() then
	config = require(configModule)
else
	-- Edit-mode command/plugin VMs can retain a stale require result after source
	-- replacement. A disposable clone verifies the source currently saved in Studio.
	local freshConfig = configModule:Clone()
	freshConfig.Name = "__GameFoundationAuditConfig"
	freshConfig.Parent = root
	config = require(freshConfig)
	freshConfig:Destroy()
end
assert(config.SchemaVersion == 12, "The personal profile schema must be version 12")
assert(config.DataStoreName == "CooperFamilyTasks_v2", "Unexpected profile DataStore")
assert(config.ReleasePlayerCap == 4, "The Milestone 1 house release cap must be four")
assert(#config.Tasks == 5, "The family loop must contain exactly five task definitions")
assert(#config.MachineStages == 11, "The Time Machine must retain all 11 stages")
assert(config.MachineStages[11].progress == 100, "The final stage must reach 100%")
assert(config.Mode == nil and config.Stability == nil and config.Chapters == nil, "Retired advanced state remains in the family config")

local expectedFeatures = {
	Lobby = true,
	Horror = false,
	SecretExploration = false,
	TimeMachineFinale = false,
	Postgame = false,
	StudioScenarioTools = false,
}
assert(type(config.Features) == "table" and table.isfrozen(config.Features), "Config.Features must be frozen")
for featureName, expectedValue in pairs(expectedFeatures) do
	assert(
		config.Features[featureName] == expectedValue,
		string.format("Milestone 1 feature %s must be %s", featureName, tostring(expectedValue))
	)
end
local featureCount = 0
for featureName in pairs(config.Features) do
	featureCount += 1
	assert(expectedFeatures[featureName] ~= nil, "Unexpected future feature flag: " .. tostring(featureName))
end
assert(featureCount == 6, "The frozen future-feature interface must contain exactly six flags")

assert(type(config.Party) == "table" and table.isfrozen(config.Party), "Config.Party must be frozen")
assert(config.Party.MaxMembers == 4, "The shared house session must support exactly four party members")
assert(config.Party.HostReconnectGraceSeconds == 60, "Host reconnect grace must remain 60 seconds")
assert(config.Party.GuestReconnectGraceSeconds == 90, "Guest reconnect grace must remain 90 seconds")
assert(config.Party.HostOnlyPersistentPurchases == true, "Persistent world purchases must remain host-only")

local expectedOrder = { "GeorgeBeer", "MaryDishes", "MaryTrash", "MissyPlush", "MedfordBankHack" }
local expectedRewards = { 55, 30, 40, 70 }
local rewardCycle = 0
assert(#config.TaskOrder == #expectedOrder, "TaskOrder must contain all five retained tasks")
for index, expectedId in ipairs(expectedOrder) do
	local definition = config.Tasks[index]
	assert(definition.id == expectedId, "Task definition order changed at " .. index)
	assert(config.TaskOrder[index] == expectedId, "Runtime task order changed at " .. index)
	local expectedReward = expectedRewards[index]
	if expectedReward then
		assert(definition.reward == expectedReward, definition.id .. " reward changed from the balanced amount")
		rewardCycle += definition.reward
	end
	if definition.id == "MissyPlush" then
		assert(definition.guidance == true, definition.id .. " must expose the configured guidance arrow")
	end
end
assert(rewardCycle == 195, "The four original chore rewards must total $195")

local totalCost = 0
local previousProgress = 0
for index, definition in ipairs(config.MachineStages) do
	assert(definition.stage == index, "Machine stages must be sequential")
	assert(definition.progress > previousProgress, "Machine progress must increase at every stage")
	assert(definition.cost > 0, "Every ordered machine component must cost allowance")
	previousProgress = definition.progress
	totalCost += definition.cost
end
assert(totalCost == 4020, "Machine purchase curve changed; rebalance pacing")

local boombox = config.Boombox
assert(type(boombox) == "table", "Config.Boombox is missing")
assert(boombox.Price == 350, "The income boombox must cost $350")
assert(boombox.AutoplayUpgradePrice == 1250, "The permanent boombox autoplay upgrade must cost $1,250")
assert(boombox.ModelName == "CooperIncomeBoombox", "Unexpected income boombox model name")
assert(boombox.AudioId == "rbxassetid://86759598635831", "Unexpected income boombox audio asset")
assert(math.abs(boombox.TrackDuration - 22.465306) < 0.000001, "Boombox duration no longer matches YouDogSong.mp3")
assert(boombox.PayoutPerTick == 30, "Boombox must pay $30 per authorized tick")
assert(boombox.MaximumPaidTicks == 10, "Boombox must cap each song at ten paid ticks")
assert(boombox.PayoutPerTick * boombox.MaximumPaidTicks == 300, "A complete boombox song must pay exactly $300")
assert(
	math.abs(boombox.PayoutInterval - boombox.TrackDuration / boombox.MaximumPaidTicks) < 0.000001,
	"Boombox payout interval must divide the exact track into ten beats"
)
assert(boombox.CooldownSeconds == 120, "Boombox must have a 120-second post-track cooldown")
assert(boombox.PreloadTimeoutSeconds == 8, "Boombox audio preload timeout changed")
assert(boombox.DanceBPM == 130, "Boombox dance timing must remain locked to 130 BPM")
assert(math.abs(boombox.DanceBeatOffsetSeconds - 0.16) < 0.000001, "Boombox dance beat offset changed")
assert(math.abs(boombox.DanceJumpHeight - 1.05) < 0.000001, "Boombox dance jump height changed")

local transactionLedger = require(transactionLedgerModule)
assert(type(transactionLedger) == "table" and transactionLedger.VERSION == 1, "Transaction ledger v1 is missing")
assert(transactionLedger.MAX_COMMITTED >= 256, "Transaction journal capacity fell below 256 committed records")
assert(transactionLedger.MAX_ROLLED_BACK > 0, "Transaction journal rollback tombstones are missing")
assert(type(transactionLedger.issuedHighWater) == "function", "Persistent transaction issuance watermark is missing")

local defaults = config.ProfileDefaults
assert(type(defaults) == "table" and defaults.schemaVersion == 12, "Profile defaults are not v12")
assert(
	type(defaults.operationJournal) == "table"
		and defaults.operationJournal.version == 1
		and #defaults.operationJournal.pending == 0
		and #defaults.operationJournal.committed == 0,
	"Fresh profile operation journal is missing or non-empty"
)
assert(defaults.allowance == 0 and defaults.machineStage == 0 and defaults.pendingPartStage == 0, "Core profile defaults changed")
assert(defaults.totalTasks == 0, "Fresh profiles must start with zero completed tasks")
assert(defaults.boomboxPurchased == false, "Fresh profiles must not own the boombox")
assert(defaults.boomboxPlaced == false, "Fresh profiles must not have a placed boombox")
assert(defaults.boomboxNextPlayAt == 0, "Fresh profiles must not start on boombox cooldown")
assert(defaults.boomboxAutoplayPurchased == false, "Fresh/legacy profiles must not receive a free autoplay upgrade")
assert(type(defaults.taskAutomationInstalled) == "table" and next(defaults.taskAutomationInstalled) == nil, "Fresh profiles must not receive free task robots")
assert(defaults.pendingTaskUpgradeId == "", "Fresh profiles must not begin with a paid automation delivery")
assert(defaults.bankHackSuccesses == 0, "Fresh profiles must begin with zero successful bank hacks")
assert(defaults.candyBatchReady == false and defaults.candyBatchToken == "", "Fresh profiles must not contain a finished chemistry batch")

local server = requireChild(ServerScriptService, "CooperGame", "Script")
local client = requireChild(StarterPlayer.StarterPlayerScripts, "CooperGame", "LocalScript")
assert(server.Enabled and client.Enabled, "CooperGame server/client must be enabled")
for _, marker in ipairs({
	"UpdateAsync",
	"pendingPartStage",
	"PlayerRemoving",
	"BindToClose",
	"M1_SHARED_TASK_SESSION_CONTRACT",
	"M1_TASK_ELIGIBILITY_CONTRACT",
	"local partySession = {",
	"local function sanitizeCalmTaskCheckpoint(raw)",
	"TransactionRuntime.commitCalmTaskStart(profile, recovered)",
	"CALM_TASK_START_EXPOSURE_AFTER_DURABLE_SAVE",
	"M1_SERVER_TRANSACTION_JOURNAL_CONTRACT",
	"TransactionRuntime.commitProfileValueOperation(",
	"TransactionRuntime.commitHostPurchase(",
	"TransactionRuntime.commitPersistentTransition(",
	"TransactionRuntime.reserveProfileValueOperation(",
	"TransactionRuntime.resumePersistedReconciliations(profile)",
	"TransactionRuntime.purchaseStillAuthorized(profile, operationKind, price)",
	"local everyGuestTerminal = true",
	"record.completionWorkerActive = true",
	"TransactionLedger.markNeedsReconciliation(",
	"OrderMachinePart",
		"OrderBoombox",
		"orderBoombox",
		"UpgradeBoomboxAutoplay",
		"upgradeBoomboxAutoplay",
		"OrderTaskUpgrade",
		"orderTaskUpgrade",
	"operation == \"AdjustCurrency\" or operation == \"SpendAllowance\"",
	"DeprecatedOperation: use a named authoritative value operation",
	"MissyPlushCollected",
	"FamilyMissyPlush",
	"createMissyCarryTool",
	"CooperComputerSessionUntil",
	"validComputerSession",
	"BeerCarryLost",
	"TrashCarryLost",
	"MissyPlushCarryLost",
		"MachinePartInstalled",
		"DATA_LOAD_ATTEMPTS = 4",
		"local DELIVERY_RETRY_INTERVAL_SECONDS = 2",
		"local PROFILE_LEASE_FIELD = \"_sessionLease\"",
		"local PROFILE_LEASE_SECONDS = 180",
		"local PROFILE_LEASE_RENEW_WINDOW = 120",
		"Profile load failed closed",
		"profile.revision",
		"savedRevision",
		"local snapshotNextAt = {}",
		"local SNAPSHOT_REQUEST_COOLDOWN = 0.75",
		"local function passSnapshotCooldown(player)",
		"profileDataNeedsCanonicalRewrite",
		"local boomboxPurchased = raw.boomboxPurchased == true or boomboxPlaced",
		"boomboxPlaced = boomboxPlaced",
		"boomboxNextPlayAt = finiteInteger(raw.boomboxNextPlayAt",
		"boomboxAutoplayPurchased = boomboxPurchased and raw.boomboxAutoplayPurchased == true",
	"local function boomboxSnapshot(profile, viewerProfile)",
	"BeginBoomboxPlayback",
	"BoomboxPayoutTick",
	"TransactionRuntime.creditBoomboxTick",
	"EndBoomboxPlayback",
	"BoomboxFinished",
	"BOOMBOX_FINAL_TICK_TOLERANCE",
}) do
	assert(string.find(server.Source, marker, 1, true), "Server source is missing " .. marker)
end

local deliveryRetrySection = sourceSection(
	server.Source,
	"local function queueDelivery(profile, kind, stage, upgradeId)",
	"-- The only server path that creates a component order."
)
local deliveryRetryCursor = 1
for _, marker in ipairs({
	"profile.deliveryQueued = type(profile.deliveryQueued) == \"table\" and profile.deliveryQueued or {}",
	"if profile.deliveryQueued[kind] then",
	"profile.deliveryQueued[kind] = true",
	"local request = {",
	"requestDelivery:Fire(profile.player, request)",
	"task.spawn(function()",
	"while profiles[profile.player] == profile and profile.deliveryQueued[kind] do",
	"task.wait(DELIVERY_RETRY_INTERVAL_SECONDS)",
	"if profiles[profile.player] == profile and profile.deliveryQueued[kind] then",
	"requestDelivery:Fire(profile.player, request)",
}) do
	local found = string.find(deliveryRetrySection, marker, deliveryRetryCursor, true)
	assert(found, "Delivery retry-until-ack contract is missing or misorders " .. marker)
	deliveryRetryCursor = found + #marker
end
assert(
	countPlain(deliveryRetrySection, "requestDelivery:Fire(profile.player, request)") == 2,
	"Delivery retries must reuse one immutable request at the initial send and retry send sites"
)
assert(
	not string.find(deliveryRetrySection, "DELIVERY_RETRY_ATTEMPTS", 1, true)
		and not string.find(deliveryRetrySection, "for attempt", 1, true),
	"Paid deliveries must not be abandoned after a fixed startup retry window"
)
for _, marker in ipairs({
	"ALLOWANCE",
	"YOUR GOAL: BUILD THE TIME MACHINE",
	"Back to Menu",
	"OrderMachinePart",
	"OrderBoombox",
	"UpgradeBoomboxAutoplay",
	"boomboxCooldownRemaining",
	"BoomboxSetup",
	"BoomboxPower",
	"BoomboxPurchased",
	"BoomboxStarted",
		"BoomboxFinished",
		"BoomboxAutoplayPurchased",
		"TaskUpgradeOrdered",
		"TaskUpgradeInstalled",
		"TaskAutomationStarted",
		"Cooldown - Ready in ",
	"LocalTaskGuidance",
	"LocalTransparencyModifier",
	"missingKind == \"Rabbit\"",
	"CloseComputer",
	"TerminalClose",
	"focusTerminalDefault",
	"clearTerminalSelection",
	"Enum.KeyCode.ButtonB",
	"Work together on George, Mary, and Missy's shared requests. Every present player earns the reward as personal allowance.",
}) do
	assert(string.find(client.Source, marker, 1, true), "Client source is missing " .. marker)
end

local terminalInputSection = sourceSection(
	client.Source,
	"UserInputService.InputBegan:Connect(function(input)",
	"upgradeNoticeUi.cameraConnection"
)
assert(
	string.find(terminalInputSection, 'showPage("Home")', 1, true),
	"Controller B must return a terminal subpage, including BANKLINK, to the main menu"
)
assert(
	string.find(terminalInputSection, "closeComputer(true)", 1, true),
	"Controller B must close the terminal from its main menu"
)

-- The home menu is player-facing navigation, not an implementation protocol.
-- Keep its wording clear for kids while the page names and remote actions below
-- remain the exact internal contract verified by the feature-specific audits.
local terminalHomeSection = sourceSection(
	client.Source,
	'elseif terminalPage == "Home" then',
	'elseif terminalPage == "Beer" then'
)
for _, visibleLabel in ipairs({
	"Order Beer",
	"Buy Time Machine Parts",
	"Buy Task Robots",
	"Buy / Upgrade Party Boombox",
	"Secret Underground Bunker",
	"Hack Medford Bank",
	"Type Commands (Optional)",
	"Exit Computer",
}) do
	assert(
		string.find(terminalHomeSection, visibleLabel, 1, true),
		"Terminal home menu is missing the kid-friendly label " .. visibleLabel
	)
end

local terminalRowSection = sourceSection(
	client.Source,
	"local function treeLine",
	"local function treeFolder"
)
assert(
	string.find(terminalRowSection, "row.TextStrokeTransparency = 1", 1, true),
	"Terminal action rows must render text without a shadow stroke"
)
assert(
	string.find(terminalRowSection, "local outline = stroke(row", 1, true),
	"Terminal action rows must use the shared border-stroke helper"
)

local sharedStrokeSection = sourceSection(
	client.Source,
	"local function stroke",
	"local function label"
)
assert(
	string.find(sharedStrokeSection, "item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border", 1, true),
	"Shared UI strokes must use ApplyStrokeMode.Border"
)

local terminalStatusBadgeSection = sourceSection(
	client.Source,
	'local row = treeLine((entryId == automationSelectedId',
	'treeLine("SELECTED ROBOT"'
)
assert(
	string.find(terminalStatusBadgeSection, "statusBadge.TextStrokeTransparency = 1", 1, true),
	"Terminal status badges must render text without a shadow stroke"
)
assert(
	string.find(terminalStatusBadgeSection, "stroke(statusBadge", 1, true),
	"Terminal status badges must use the shared ApplyStrokeMode.Border helper"
)
for _, removedTask in ipairs({
	"MaryLaundry",
	"MaryShower",
	"MaryToilet",
	"GeorgieTire",
	"TireAdvanced",
}) do
	assert(not string.find(server.Source, removedTask, 1, true), "Server still contains removed task " .. removedTask)
	assert(not string.find(client.Source, removedTask, 1, true), "Client still contains removed task " .. removedTask)
end
for _, forbidden in ipairs({
	"CooperProgression",
	"CanOrderMachinePart",
	"House Stability",
	"HOUSE STABILITY",
	"PanicActive",
	"CooperCrisis",
	"BankCode",
	"LocalBankCodeNote",
}) do
	assert(not string.find(server.Source, forbidden, 1, true), "Server still contains retired system marker " .. forbidden)
	assert(not string.find(client.Source, forbidden, 1, true), "Client still contains retired system marker " .. forbidden)
end
for _, forbiddenClientAwardRoute in ipairs({
	"BeginBoomboxPlayback",
	"BoomboxPayoutTick",
	"EndBoomboxPlayback",
	"AdjustCurrency",
	"setAllowance(",
}) do
	assert(
		not string.find(client.Source, forbiddenClientAwardRoute, 1, true),
		"Client contains a forbidden boombox/currency authority route: " .. forbiddenClientAwardRoute
	)
end
assert(
	not string.find(client.Source, "requestEvent:FireServer(\"BoomboxIncome\"", 1, true),
	"Client must never request or report its own boombox earnings"
)
assert(
	not string.find(server.Source, "definition.stage == 8", 1, true)
		and not string.find(server.Source, "definition.stage == 9", 1, true),
	"Machine stages 8 and 9 must use the same allowance-only order path as every other stage"
)
local debitAt = string.find(server.Source, "setAllowance(profile, profile.data.allowance - cost)", 1, true)
local pendingAt = string.find(server.Source, "profile.data.pendingPartStage = definition.stage", 1, true)
assert(debitAt and pendingAt and debitAt < pendingAt, "A component order must debit allowance before creating its paid delivery")

local purchaseSection = sourceSection(
	server.Source,
	"local function orderBoombox(profile)",
	"local function upgradeBoomboxAutoplay(profile)"
)
assert(
	countPlain(purchaseSection, "TransactionRuntime.commitHostPurchase(") == 1,
	"Boombox ordering must use exactly one durable host-purchase transaction"
)
local boomboxDebitAt = string.find(purchaseSection, "setAllowance(profile, profile.data.allowance - price)", 1, true)
local boomboxPurchaseAt = string.find(purchaseSection, "profile.data.boomboxPurchased = true", 1, true)
local boomboxPendingAt = string.find(purchaseSection, "profile.boomboxDeliveryStep = \"WaitingDelivery\"", 1, true)
local boomboxDeliveryAt = string.find(purchaseSection, "queueDelivery(profile, \"Boombox\", 0)", 1, true)
assert(
	boomboxDebitAt and boomboxPurchaseAt and boomboxPendingAt and boomboxDeliveryAt
		and boomboxDebitAt < boomboxPurchaseAt
		and boomboxPurchaseAt < boomboxPendingAt
		and boomboxPendingAt < boomboxDeliveryAt,
	"Boombox ordering must atomically debit, persist ownership/pending state, then queue delivery"
)
assert(string.find(purchaseSection, "profile.data.allowance < price", 1, true), "Boombox purchase lacks a server balance check")
assert(not string.find(purchaseSection, "task.wait", 1, true), "Atomic boombox purchase path must not yield")
assert(not string.find(purchaseSection, "markDirty(profile)", 1, true), "Boombox purchase must not bypass transaction persistence")
assert(not string.find(purchaseSection, "task.defer(saveProfile", 1, true), "Boombox purchase must not append an unjournaled deferred save")

local autoplayPurchaseSection = sourceSection(
	server.Source,
	"local function upgradeBoomboxAutoplay(profile)",
	"local function orderTaskUpgrade(profile, requestedUpgradeId)"
)
for _, marker in ipairs({
	"profile.data.boomboxPurchased",
	"profile.data.boomboxPlaced",
	"profile.data.boomboxAutoplayPurchased",
	"Config.Boombox.AutoplayUpgradePrice",
	"profile.data.allowance < price",
	"TransactionRuntime.commitHostPurchase(",
	"BoomboxAutoplayPurchased",
	"broadcastState()",
}) do
	assert(string.find(autoplayPurchaseSection, marker, 1, true), "Autoplay purchase is missing " .. marker)
end
assert(
	countPlain(autoplayPurchaseSection, "TransactionRuntime.commitHostPurchase(") == 1,
	"Autoplay purchase must use exactly one durable host-purchase transaction"
)
local autoplayTransactionAt =
	string.find(autoplayPurchaseSection, "TransactionRuntime.commitHostPurchase(", 1, true)
local autoplayDebitAt = string.find(autoplayPurchaseSection, "setAllowance(profile, profile.data.allowance - price)", 1, true)
local autoplayEntitlementAt = string.find(autoplayPurchaseSection, "profile.data.boomboxAutoplayPurchased = true", 1, true)
local autoplayFeedbackAt =
	string.find(autoplayPurchaseSection, "feedback(profile.player, \"BoomboxAutoplayPurchased\"", 1, true)
assert(
	autoplayTransactionAt and autoplayDebitAt and autoplayEntitlementAt and autoplayFeedbackAt
		and autoplayTransactionAt < autoplayDebitAt
		and autoplayDebitAt < autoplayEntitlementAt
		and autoplayEntitlementAt < autoplayFeedbackAt,
	"Autoplay upgrade must debit and grant entitlement inside its transaction before notifying"
)
assert(not string.find(autoplayPurchaseSection, "task.wait", 1, true), "Atomic autoplay purchase path must not yield")
assert(not string.find(autoplayPurchaseSection, "markDirty(profile)", 1, true), "Autoplay purchase must not bypass transaction persistence")
assert(not string.find(autoplayPurchaseSection, "task.defer(saveProfile", 1, true), "Autoplay purchase must not append an unjournaled deferred save")

local installSection = sourceSection(
	server.Source,
	"local function reportPlayerAction(eventKey, player, metadata)",
	"local function boomboxFailure(message, remaining, retryAfter)"
)
for _, marker in ipairs({
	"InstallTaskUpgrade",
	"InstallChemistrySetup",
	"InstallBoombox",
	"InstallMachineStage",
}) do
	assert(string.find(installSection, marker, 1, true), "Persistent install handling is missing " .. marker)
end
assert(
	countPlain(installSection, "TransactionRuntime.commitPersistentTransition(") == 4,
	"All four persistent installs must use one durable transition each"
)
assert(
	countPlain(installSection, "if appliedNow then") == 4,
	"Install presentation must run only after each durable transition applies for the first time"
)
assert(not string.find(installSection, "setAllowance(", 1, true), "Install callbacks must never adjust currency")
assert(not string.find(installSection, "markDirty(profile)", 1, true), "Install handlers must not bypass transaction persistence")
assert(not string.find(installSection, "task.defer(saveProfile", 1, true), "Install handlers must not append unjournaled deferred saves")

local trustedOrderMentionAt = string.find(server.Source, "or action == \"OrderBoombox\"", 1, true)
local trustedComputerCheckAt = trustedOrderMentionAt
	and string.find(server.Source, "and not validComputerSession(player)", trustedOrderMentionAt, true)
local boomboxRemoteOrderAt = trustedComputerCheckAt
	and string.find(server.Source, "elseif action == \"OrderBoombox\"", trustedComputerCheckAt, true)
assert(
	trustedOrderMentionAt and trustedComputerCheckAt and boomboxRemoteOrderAt
		and trustedOrderMentionAt < trustedComputerCheckAt
		and trustedComputerCheckAt < boomboxRemoteOrderAt,
	"OrderBoombox must pass the trusted nearby-computer session gate before purchase"
)
assert(
	not string.find(server.Source, "operation == \"OrderBoombox\"", 1, true),
	"Boombox purchase must not be exposed through the ungated server API"
)
local trustedAutoplayMentionAt = string.find(server.Source, "or action == \"UpgradeBoomboxAutoplay\"", 1, true)
local trustedAutoplayCheckAt = trustedAutoplayMentionAt
	and string.find(server.Source, "and not validComputerSession(player)", trustedAutoplayMentionAt, true)
local autoplayRemoteOrderAt = trustedAutoplayCheckAt
	and string.find(server.Source, "elseif action == \"UpgradeBoomboxAutoplay\"", trustedAutoplayCheckAt, true)
assert(
	trustedAutoplayMentionAt and trustedAutoplayCheckAt and autoplayRemoteOrderAt
		and trustedAutoplayMentionAt < trustedAutoplayCheckAt
		and trustedAutoplayCheckAt < autoplayRemoteOrderAt,
	"UpgradeBoomboxAutoplay must pass the trusted nearby-computer session gate before purchase"
)
assert(
	not string.find(server.Source, "operation == \"UpgradeBoomboxAutoplay\"", 1, true),
	"Autoplay purchase must not be exposed through the ungated server API"
)

local beginSection = sourceSection(
	server.Source,
	"local function beginBoomboxPlayback(player, requestedSource)",
	"function TransactionRuntime.creditBoomboxTick"
)
for _, marker in ipairs({
	"local playbackSource = requestedSource == \"Autoplay\" and \"Autoplay\" or \"Manual\"",
	"local automatic = playbackSource == \"Autoplay\"",
	"automatic and profile.data.boomboxAutoplayPurchased ~= true",
	"profile.data.boomboxPurchased",
	"profile.data.boomboxPlaced",
	"profile.data.boomboxNextPlayAt - unixNow()",
	"boomboxSessionSerial += 1",
	"sessionId = sessionId",
	"paidTicks = 0",
	"totalPaid = 0",
	"boomboxPlaybackOwner = player",
	"source = playbackSource",
	"if not automatic then",
	"Config.Boombox.MaximumPaidTicks",
}) do
	assert(string.find(beginSection, marker, 1, true), "BeginBoomboxPlayback is missing " .. marker)
end
local cooldownCommitAt = string.find(beginSection, "profile.data.boomboxNextPlayAt = nextPlayAt", 1, true)
local playbackCommitAt = string.find(beginSection, "profile.boomboxPlayback = {", 1, true)
assert(
	cooldownCommitAt and playbackCommitAt and cooldownCommitAt < playbackCommitAt,
	"Persistent boombox cooldown must be committed before opening a payout session"
)

local creditSection = sourceSection(
	server.Source,
	"function TransactionRuntime.creditBoomboxTick(profile, playback, requestedTickIndex)",
	"function TransactionRuntime.settleCompletedBoombox(profile, playback)"
)
for _, marker in ipairs({
	"local tickIndex = finiteInteger(",
	"\"BoomboxTick\"",
	"tostring(playback.sessionId) .. \":\" .. tostring(tickIndex)",
	"TransactionRuntime.commitPersistentTransition(",
	"setAllowance(profile, profile.data.allowance + payout)",
	"playback.paidTicks == tickIndex - 1",
	"return appliedNow and payout or 0, true, status",
}) do
	assert(string.find(creditSection, marker, 1, true), "Journaled boombox credit is missing " .. marker)
end
assert(
	countPlain(creditSection, "TransactionRuntime.commitPersistentTransition(") == 1
		and countPlain(creditSection, "setAllowance(profile, profile.data.allowance + payout)") == 1,
	"Each indexed boombox tick must have exactly one journaled allowance mutation"
)
assert(not string.find(creditSection, "markDirty(profile)", 1, true), "Boombox ticks must not bypass transaction persistence")
assert(not string.find(creditSection, "task.defer(saveProfile", 1, true), "Boombox ticks must not append unjournaled deferred saves")

local tickSection = sourceSection(
	server.Source,
	"local function boomboxPayoutTick(player, sessionId, requestedTickIndex)",
	"local function finalizeBoomboxPlayback(profile, playback, endedReason, suppressFeedback, durable)"
)
for _, marker in ipairs({
	"playback.sessionId ~= sessionId",
	"boomboxPlaybackOwner ~= player",
	"local tickIndex = finiteInteger(requestedTickIndex",
	"tickIndex > playback.paidTicks + 1",
	"playback.paidTicks >= Config.Boombox.MaximumPaidTicks",
	"playback.startedAt + tickIndex * Config.Boombox.PayoutInterval",
	"BOOMBOX_TICK_EARLY_TOLERANCE",
	"Config.Boombox.TrackDuration + BOOMBOX_FINAL_TICK_TOLERANCE",
	"TransactionRuntime.creditBoomboxTick(profile, playback, tickIndex)",
}) do
	assert(string.find(tickSection, marker, 1, true), "BoomboxPayoutTick is missing " .. marker)
end
local tickCapAt = string.find(tickSection, "playback.paidTicks >= Config.Boombox.MaximumPaidTicks", 1, true)
local tickAwardAt = string.find(tickSection, "TransactionRuntime.creditBoomboxTick(profile, playback, tickIndex)", 1, true)
assert(tickCapAt and tickAwardAt and tickCapAt < tickAwardAt, "Boombox tick cap must be checked before awarding allowance")
assert(
	countPlain(tickSection, "TransactionRuntime.creditBoomboxTick(profile, playback, tickIndex)") == 1,
	"One indexed payout request can reach more than one credit transaction"
)
assert(not string.find(tickSection, "setAllowance(", 1, true), "Payout authorization must not mutate allowance outside the journal helper")
assert(not string.find(tickSection, "markDirty(profile)", 1, true), "Payout authorization must not bypass transaction persistence")
assert(not string.find(tickSection, "task.defer(saveProfile", 1, true), "Payout authorization must not append unjournaled deferred saves")

local endSection = sourceSection(
	server.Source,
	"function TransactionRuntime.settleCompletedBoombox(profile, playback)",
	"local function endBoomboxPlaybackForPlayer"
)
local liveSettlementSection = sourceSection(
	server.Source,
	"function TransactionRuntime.settleCompletedBoombox(profile, playback)",
	"function TransactionRuntime.recoverPendingBoomboxSettlement(profile, announce)"
)
for _, marker in ipairs({
	"\"BoomboxSettle\"",
	"playback.settlementValue",
	"setAllowance(profile, profile.data.allowance + settlementValue)",
	"paidTicks = maximumTicks",
	"playback.sessionId ~= sessionId",
	"endedReason == \"Completed\"",
	"Config.Boombox.TrackDuration - BOOMBOX_FINAL_TICK_TOLERANCE",
	"TransactionRuntime.settleCompletedBoombox(profile, playback)",
	"scheduleBoomboxSettlement(profile, playback, endedReason, suppressFeedback)",
	"profile.boomboxPlayback = nil",
	"BoomboxFinished",
	"BoomboxPayoutSaving",
}) do
	assert(string.find(endSection, marker, 1, true), "EndBoomboxPlayback is missing " .. marker)
end
local finalRaceCreditAt = string.find(endSection, "TransactionRuntime.settleCompletedBoombox(profile, playback)", 1, true)
local sessionClearAt = string.find(endSection, "profile.boomboxPlayback = nil", 1, true)
assert(
	finalRaceCreditAt and sessionClearAt and finalRaceCreditAt < sessionClearAt,
	"Completed-track settlement must begin before the payout session is cleared"
)
assert(
	countPlain(liveSettlementSection, "setAllowance(profile, profile.data.allowance + settlementValue)") == 1,
	"Completed-track recovery must contain exactly one journaled catch-up mutation"
)
assert(
	countPlain(liveSettlementSection, "TransactionRuntime.commitPersistentTransition(") == 1,
	"Completed-track catch-up must use exactly one persistent transition"
)

assert(
	string.find(server.Source, "local nextCursor = (partySession.taskCursor % #order) + 1", 1, true),
	"The five retained tasks no longer cycle in their exact order"
)
assert(
	string.find(server.Source, "partySession.taskCursor = profile.data.totalTasks % #Config.TaskOrder", 1, true),
	"The host-owned shared rotation must resume from persisted totalTasks rather than reset on rejoin"
)
for _, forbiddenPersonalScheduler in ipairs({
	"profile.taskCursor",
	"profile.nextTaskAt",
	"local record = profile.task",
	"local activeTask = profile.task",
	"not profile.task and",
	"profile.task ~= bankSession.record",
}) do
	assert(
		not string.find(server.Source, forbiddenPersonalScheduler, 1, true),
		"Task scheduling must not fall back to profile-local state: " .. forbiddenPersonalScheduler
	)
end
assert(
	not string.find(server.Source, "ProximityPromptService.PromptTriggered", 1, true),
	"Family server still duplicates the authoritative computer-open handler"
)
assert(
	string.find(server.Source, "if not partySession.task and currentTime >= partySession.nextTaskAt then", 1, true),
	"Simple family tasks are still gated by an external mode"
)

local eligibilitySection = sourceSection(
	server.Source,
	"-- M1_TASK_ELIGIBILITY_CONTRACT",
	"function TransactionRuntime.checkpointValidation"
)
for _, marker in ipairs({
	"local function captureTaskEligibility(version)",
	"for userId, player in pairs(partySession.activePlayers) do",
	"partySession.expectedMembers[userId] == true",
	"profile.loaded and not profile.releasing and not profile.leaseLost",
	"profile.detached ~= true",
	"table.sort(userIds)",
	"return table.freeze({",
	"userIds = table.freeze(userIds)",
	"memberSet = table.freeze(memberSet)",
	"record.eligibility.memberSet[userId] ~= true",
	"record.eligibilityResolutionByUserId[userId] ~= nil",
	"status = \"Forfeited\"",
	"return nil, \"NotEligibleAtTaskStart\"",
	"return nil, \"ProfileLoading\"",
	"return nil, \"GuestReconnectGraceExpired\"",
	"return nil, \"RecoveredTaskGraceExpired\"",
}) do
	assert(
		string.find(eligibilitySection, marker, 1, true),
		"Immutable task eligibility is missing " .. marker
	)
end
assert(
	countPlain(eligibilitySection, "local function captureTaskEligibility(version)") == 1,
	"Task eligibility must have exactly one server-owned capture function"
)

local taskStartSection = sourceSection(
	server.Source,
	"local function startNextTask(profile)",
	"local function scheduleNextTask(profile)"
)
for _, marker in ipairs({
	"local eligibility = captureTaskEligibility(profile.data.totalTasks + 1)",
	"eligibility.memberSet[profile.player.UserId] ~= true",
	"profile.data.calmTaskCheckpoint = {",
	"logicalId = string.format(\"%d:%d:%s\"",
	"eligibleUserIds = table.clone(eligibility.userIds)",
	"startedAtUnix = unixNow()",
	"profile.calmTaskCheckpointDurable = false",
	"TransactionRuntime.commitCalmTaskStart(profile, false)",
}) do
	assert(string.find(taskStartSection, marker, 1, true), "Durable shared-task start is missing " .. marker)
end
assert(
	not string.find(taskStartSection, "partySession.task =", 1, true),
	"A task must not become visible before its CalmTaskStart checkpoint is durably saved"
)

local checkpointCommitSection = sourceSection(
	server.Source,
	"function TransactionRuntime.commitCalmTaskStart(profile, recovered)",
	"local function startNextTask(profile)"
)
local checkpointDurableStateAt = string.find(
	checkpointCommitSection,
	"local durable = profile.calmTaskCheckpointDurable == true",
	1,
	true
)
local checkpointSaveGateAt = string.find(
	checkpointCommitSection,
	"if not durable then",
	checkpointDurableStateAt or 1,
	true
)
local checkpointSaveAt = string.find(
	checkpointCommitSection,
	"durable = TransactionRuntime.safeSave(profile)",
	checkpointSaveGateAt or 1,
	true
)
local checkpointDurableRecordedAt = string.find(
	checkpointCommitSection,
	"profile.calmTaskCheckpointDurable = durable == true",
	checkpointSaveAt or 1,
	true
)
local checkpointWriteFinishedAt = string.find(
	checkpointCommitSection,
	"profile.calmTaskCheckpointWriteInFlight = false",
	checkpointDurableRecordedAt or 1,
	true
)
local checkpointRejectAt = string.find(
	checkpointCommitSection,
	"if not durable then",
	checkpointWriteFinishedAt or 1,
	true
)
local checkpointRejectReturnAt = string.find(
	checkpointCommitSection,
	"return false",
	checkpointRejectAt or 1,
	true
)
local checkpointExposeAt = string.find(
	checkpointCommitSection,
	"TransactionRuntime.exposeCalmTaskCheckpoint(profile, checkpoint, recovered)",
	checkpointRejectReturnAt or 1,
	true
)
assert(
	checkpointDurableStateAt and checkpointSaveGateAt and checkpointSaveAt
		and checkpointDurableRecordedAt and checkpointWriteFinishedAt
		and checkpointRejectAt and checkpointRejectReturnAt and checkpointExposeAt
		and checkpointDurableStateAt < checkpointSaveGateAt
		and checkpointSaveGateAt < checkpointSaveAt
		and checkpointSaveAt < checkpointDurableRecordedAt
		and checkpointDurableRecordedAt < checkpointWriteFinishedAt
		and checkpointWriteFinishedAt < checkpointRejectAt
		and checkpointRejectAt < checkpointRejectReturnAt
		and checkpointRejectReturnAt < checkpointExposeAt,
	"CalmTaskStart must be durably saved before the server exposes the task"
)
for _, marker in ipairs({
	"profile.calmTaskCheckpointWriteInFlight",
	"profile.calmTaskCheckpointRetryAt",
	"profile.calmTaskCheckpointRetryCount",
}) do
	assert(
		string.find(checkpointCommitSection, marker, 1, true),
		"CalmTaskStart retry serialization is missing " .. marker
	)
end

local taskExposureSection = sourceSection(
	server.Source,
	"function TransactionRuntime.exposeCalmTaskCheckpoint(profile, checkpoint, recovered)",
	"function TransactionRuntime.commitCalmTaskStart(profile, recovered)"
)
for _, marker in ipairs({
	"eligibility = TransactionRuntime.eligibilityFromCheckpoint(checkpoint)",
	"eligibilityResolutionByUserId = {}",
	"rewardOperationIdsByUserId = {}",
	"-- CALM_TASK_START_EXPOSURE_AFTER_DURABLE_SAVE",
	"partySession.taskCursor = nextCursor",
	"partySession.taskSerial = nextSerial",
	"partySession.task = record",
}) do
	assert(string.find(taskExposureSection, marker, 1, true), "Shared task exposure is missing " .. marker)
end
local exposureGuardAt = string.find(
	taskExposureSection,
	"-- CALM_TASK_START_EXPOSURE_AFTER_DURABLE_SAVE",
	1,
	true
)
local taskVisibleAt = string.find(taskExposureSection, "partySession.task = record", 1, true)
assert(
	exposureGuardAt and taskVisibleAt and exposureGuardAt < taskVisibleAt,
	"The visible shared task must be assigned only after the durable-exposure guard"
)

local completeTaskSection = sourceSection(
	server.Source,
	"completeTask = function(profile, expectedRecord)",
	"local function bankRoundCount()"
)
for _, marker in ipairs({
	"record.status = \"Completing\"",
	"record.completionWorkerActive = true",
	"for _, userId in ipairs(record.eligibility.userIds) do",
	"local everyGuestTerminal = true",
	"if not everyGuestTerminal then",
	"local operationKind = \"TaskReward:\" .. tostring(record.logicalId)",
	"TransactionRuntime.reserveProfileValueOperation(",
	"status = \"Committing\"",
	"TransactionRuntime.commitProfileValueOperation(",
	"setAllowance(recipient, recipient.data.allowance + reward)",
	"recipient.data.totalTasks += 1",
	"recipient.data.cycleIndex = math.floor(recipient.data.totalTasks / #Config.TaskOrder) + 1",
	"recipient.data.cycleTaskIndex = (recipient.data.totalTasks % #Config.TaskOrder) + 1",
	"recipient.data.calmTaskCheckpoint = nil",
	"local allResolved = true",
	"if partySession.task ~= record or record.status ~= \"Completing\" then",
	"record.status = \"Completed\"",
	"partySession.completedTasks += 1",
	"partySession.task = nil",
}) do
	assert(string.find(completeTaskSection, marker, 1, true), "Shared task completion is missing " .. marker)
end
assert(
	countPlain(completeTaskSection, "record.status = \"Completing\"") == 1
		and countPlain(completeTaskSection, "record.status = \"Completed\"") == 1
		and countPlain(completeTaskSection, "partySession.completedTasks += 1") == 1
		and countPlain(completeTaskSection, "partySession.task = nil") == 1,
	"One shared task must have one completion claim, one final CAS, one advance, and one close"
)
local completingAt = string.find(completeTaskSection, "record.status = \"Completing\"", 1, true)
local journalAt = string.find(
	completeTaskSection,
	"TransactionRuntime.commitProfileValueOperation(",
	completingAt or 1,
	true
)
local completedAt = string.find(completeTaskSection, "record.status = \"Completed\"", 1, true)
local advanceAt = string.find(completeTaskSection, "partySession.completedTasks += 1", 1, true)
local taskCloseAt = string.find(completeTaskSection, "partySession.task = nil", 1, true)
assert(
	completingAt and journalAt and completedAt and advanceAt and taskCloseAt
		and completingAt < journalAt
		and journalAt < completedAt
		and completedAt < advanceAt
		and advanceAt < taskCloseAt,
	"Shared completion must claim, journal every recipient, pass the final CAS, advance once, then close"
)
assert(
	not string.find(completeTaskSection, "presentProfiles()", 1, true)
		and not string.find(completeTaskSection, "rewardedUserIds", 1, true),
	"Task completion must consume the immutable start snapshot, not a mutable completion-time roster"
)

local savePayloadAt = string.find(server.Source, "local payload = sanitizeData(profile.data)", 1, true)
assert(savePayloadAt, "Profile saves must pass schema-12 progression fields through sanitizeData")
local sanitizerSection = sourceSection(
	server.Source,
	"local function canonicalProfileValueMatches",
	"local function profileKey"
)
for _, marker in ipairs({
	"local function profileDataNeedsCanonicalRewrite(rawData, sanitizedData)",
	"if rawData == nil then",
	"if type(rawData) ~= \"table\" then",
	"canonicalProfileValueMatches(rawData[fieldName], canonicalValue)",
	"fieldName ~= \"updatedAt\"",
	"fieldName ~= PROFILE_LEASE_FIELD",
	"sanitizedData[fieldName] == nil",
	"return sanitized, profileDataNeedsCanonicalRewrite(originalRaw, sanitized)",
}) do
	assert(
		string.find(sanitizerSection, marker, 1, true),
		"Canonical profile repair detection is missing " .. marker
	)
end

local leaseSection = sourceSection(server.Source, "local function profileKey", "local function findPlayerRoot")
for _, marker in ipairs({
	"local function storedProfileLease(raw)",
	"local function acquireProfileLease(profile)",
	"dataStore:UpdateAsync(profileKey(player), function(current)",
	"owner ~= profile.leaseToken and expiresAt > now",
	"return nil",
	"owner = profile.leaseToken",
	"server = SERVER_PROFILE_SESSION_ID",
	"expiresAt = now + PROFILE_LEASE_SECONDS",
	"local function releaseProfileLease(profile, maximumAttempts)",
	"owner ~= profile.leaseToken",
	"releasedRecord[PROFILE_LEASE_FIELD] = nil",
	"local function invalidateLostProfileLease(profile, reason)",
	"profile.loaded = false",
	"player:Kick",
}) do
	assert(string.find(leaseSection, marker, 1, true), "Cross-server profile lease is missing " .. marker)
end
assert(
	not string.find(server.Source, "dataStore:GetAsync", 1, true),
	"Profile hydration must atomically claim through UpdateAsync instead of racing a GetAsync load"
)

local saveSection = sourceSection(server.Source, "local function saveProfile(player, releasing)", "local function pickHiddenLocation")
for _, marker in ipairs({
	"local leaseRenewalDue = dataStore ~= nil",
	"profile.leaseExpiresAt or 0",
	"PROFILE_LEASE_RENEW_WINDOW",
	"local owner = storedProfileLease(current)",
	"owner ~= profile.leaseToken",
	"leaseRejected = true",
	"payload[PROFILE_LEASE_FIELD]",
	"expiresAt = os.time() + PROFILE_LEASE_SECONDS",
	"resultOwner ~= profile.leaseToken",
	"until leaseRejected or (writeComplete and not profile.dirty) or attempt >= maximumAttempts",
	"invalidateLostProfileLease(profile, failure)",
	"releaseProfileLease(profile, RELEASE_SAVE_ATTEMPTS)",
}) do
	assert(string.find(saveSection, marker, 1, true), "Lease-guarded profile save is missing " .. marker)
end
local loadSection = sourceSection(server.Source, "local function loadPlayer(player)", "Players.PlayerAdded:Connect")
for _, marker in ipairs({
	"leaseToken = HttpService:GenerateGUID(false)",
	"local acquired, result, leaseExpiresAt, lastFailure, liveConflict = acquireProfileLease(profile)",
	"if not acquired then",
	"profile.leaseOwned = true",
	"profile.leaseExpiresAt = leaseExpiresAt",
	"player.Parent ~= Players or shuttingDown",
		"releaseProfileLease(profile, RELEASE_SAVE_ATTEMPTS)",
		"local sanitizedData, didNormalize = sanitizeData(result)",
		"profile.data = sanitizedData",
		"if didNormalize then",
		"profile.dirty = true",
		"partySession.taskCursor = profile.data.totalTasks % #Config.TaskOrder",
		"recoverHostWorldState(profile, player)",
		"if profile.dirty then",
		"task.defer(saveProfile, player, false)",
}) do
	assert(string.find(loadSection, marker, 1, true), "Profile load/recovery is missing " .. marker)
end
local hostSchedulerGateAt = string.find(loadSection, "if partyIsHost(player) then", 1, true)
local hostTaskCursorAt = string.find(
	loadSection,
	"partySession.taskCursor = profile.data.totalTasks % #Config.TaskOrder",
	hostSchedulerGateAt or 1,
	true
)
local hostRecoveryGateAt = string.find(
	loadSection,
	"if partyIsHost(player) then",
	(hostTaskCursorAt or 0) + 1,
	true
)
local hostRecoveryCallAt = string.find(
	loadSection,
	"recoverHostWorldState(profile, player)",
	hostRecoveryGateAt or 1,
	true
)
assert(
	hostSchedulerGateAt and hostTaskCursorAt and hostRecoveryGateAt and hostRecoveryCallAt
		and hostSchedulerGateAt < hostTaskCursorAt
		and hostTaskCursorAt < hostRecoveryGateAt
		and hostRecoveryGateAt < hostRecoveryCallAt,
	"Only the hydrated party host may restore the shared task cursor and paid house deliveries"
)

local hostWorldRecoverySection = sourceSection(
	server.Source,
	"recoverHostWorldState = function(profile, player)",
	"local function rejectHouseAdmission(player, reason)"
)
for _, marker in ipairs({
	"not partyIsHost(player)",
	"profile.deliveryQueued = {}",
	"local function queueWhenPartyReady(kind, stage, extra)",
	"profiles[player] ~= profile or player.Parent ~= Players",
	"or not profile.loaded or profile.releasing or partySession.state == \"Closing\"",
	"if partyCanProgress() then",
	"queueDelivery(profile, kind, stage, extra)",
	"if profile.data.boomboxPurchased and not profile.data.boomboxPlaced then",
	"profile.boomboxDeliveryStep = \"WaitingDelivery\"",
	"if profile.data.pendingPartStage == 0 then",
	"queueWhenPartyReady(\"Boombox\", 0)",
}) do
	assert(string.find(hostWorldRecoverySection, marker, 1, true), "Host-world recovery is missing " .. marker)
end
local recoveryBoomboxAt = string.find(
	hostWorldRecoverySection,
	"if profile.data.boomboxPurchased and not profile.data.boomboxPlaced then",
	1,
	true
)
local recoveryBoomboxStepAt = string.find(
	hostWorldRecoverySection,
	"profile.boomboxDeliveryStep = \"WaitingDelivery\"",
	recoveryBoomboxAt or 1,
	true
)
local recoveryDeliveryPriorityAt = string.find(
	hostWorldRecoverySection,
	"if profile.data.pendingPartStage == 0 then",
	recoveryBoomboxStepAt or 1,
	true
)
local recoveryBoomboxQueueAt = string.find(
	hostWorldRecoverySection,
	"queueWhenPartyReady(\"Boombox\", 0)",
	recoveryDeliveryPriorityAt or 1,
	true
)
assert(
	recoveryBoomboxAt and recoveryBoomboxStepAt and recoveryDeliveryPriorityAt and recoveryBoomboxQueueAt
		and recoveryBoomboxAt < recoveryBoomboxStepAt
		and recoveryBoomboxStepAt < recoveryDeliveryPriorityAt
		and recoveryDeliveryPriorityAt < recoveryBoomboxQueueAt,
	"Host recovery must recognize paid/unplaced ownership, restore its delivery state, honor machine-part priority, then queue safely"
)
assert(
	string.find(server.Source, "if profile.loaded or profile.leaseOwned then", 1, true),
	"Shutdown must release a lease that finished claiming before profile hydration completed"
)
assert(string.find(server.Source, "local hydratingProfiles = {}", 1, true), "Shutdown does not track profile claims still yielding in UpdateAsync")
assert(string.find(server.Source, "hydratingProfiles[profile] = true", 1, true), "Profile hydration is not registered before its lease claim")
assert(
	string.find(server.Source, "pendingSaves > 0 or next(hydratingProfiles) ~= nil", 1, true),
	"BindToClose can return before an in-flight profile claim releases its lease"
)

local requestSection = sourceSection(
	server.Source,
	"local function passRequestCooldown(player)",
	"local function setupLeaderstats"
)
for _, marker in ipairs({
	"local function passSnapshotCooldown(player)",
	"snapshotNextAt[player] = nowClock + SNAPSHOT_REQUEST_COOLDOWN",
	"if action == \"RequestSnapshot\" then",
	"if not passSnapshotCooldown(player) then",
	"elseif action ~= \"CloseComputer\"",
	"and not passRequestCooldown(player)",
}) do
	assert(string.find(requestSection, marker, 1, true), "Snapshot request throttling is missing " .. marker)
end
assert(
	string.find(server.Source, "snapshotNextAt[player] = nil", 1, true),
	"Snapshot request throttling is not cleared when a player leaves"
)

local apiSection = sourceSection(server.Source, "serverAPI.OnInvoke = function", "local function passRequestCooldown")
for _, operation in ipairs({
	"BeginBoomboxPlayback",
	"BoomboxPayoutTick",
	"EndBoomboxPlayback",
}) do
	assert(
		string.find(apiSection, "operation == \"" .. operation .. "\"", 1, true),
		"Trusted TaskWorld API is missing " .. operation
	)
end
assert(
	string.find(apiSection, "return beginBoomboxPlayback(arg1, arg2)", 1, true),
	"TaskWorld playback source is not forwarded into authoritative BeginBoomboxPlayback"
)
assert(
	string.find(apiSection, "return boomboxPayoutTick(arg1, arg2, arg3)", 1, true),
	"TaskWorld's explicit boombox tick index is not forwarded to payout authorization"
)
assert(
	string.find(apiSection, "operation == \"AdjustCurrency\" or operation == \"SpendAllowance\"", 1, true)
		and string.find(
			apiSection,
			"return false, \"DeprecatedOperation: use a named authoritative value operation\"",
			1,
			true
		),
	"Legacy generic currency APIs must fail closed"
)
assert(not string.find(apiSection, "setAllowance(", 1, true), "Structured API contains an unjournaled direct currency mutation")
assert(not string.find(server.Source, "local function adjustAllowance", 1, true), "Legacy broad allowance mutation helper must remain retired")

local serverEvents = requireChild(ServerScriptService, config.ServerEventsName, "Folder")
for _, specification in ipairs({
	{ "ReportAction", "BindableEvent" },
	{ "RegisterAction", "BindableEvent" },
	{ "RequestDelivery", "BindableEvent" },
	{ "RunTaskAutomation", "BindableEvent" },
	{ "API", "BindableFunction" },
}) do
	requireChild(serverEvents, specification[1], specification[2])
end

assert(state:GetAttribute("SchemaVersion") == 12, "Running state does not expose schema version 12")
assert(state:GetAttribute("FoundationContract") == "PartyV1", "Running state does not expose PartyV1")
assert(state:GetAttribute("ReleasePlayerCap") == 4, "Running state does not expose the four-player house cap")
for featureName, expectedValue in pairs(expectedFeatures) do
	assert(
		state:GetAttribute("Feature" .. featureName .. "Enabled") == expectedValue,
		string.format("Running state feature %s must be %s", featureName, tostring(expectedValue))
	)
end
assert(state:GetAttribute("SupportsPaidPartOrdering") == true, "Paid component ordering contract is missing")
assert(state:GetAttribute("SupportsBoombox") == true, "Boombox ownership/delivery contract is missing")
assert(state:GetAttribute("SupportsIncomeBoombox") == true, "Server-authoritative boombox income contract is missing")
assert(state:GetAttribute("SupportsBoomboxAutoplay") == true, "Persistent boombox autoplay contract is missing")
assert(state:GetAttribute("SupportsTaskAutomation") == true, "Persistent task-automation contract is missing")
assert(state:GetAttribute("SupportsMedfordBankHack") == true, "Medford Bank hacking contract is missing")
assert(state:GetAttribute("Mode") == nil, "Retired mode state should be cleared")
assert(state:GetAttribute("Stability") == nil, "Retired stability state should be cleared")
assert(state:GetAttribute("Chapter") == nil, "Retired chapter state should be cleared")
print(string.format(
	"[CooperGameAudit] PASS: %d shared tasks ($%d from original chores), %d machine stages ($%d), $%d income boombox + $%d autoplay; schema 12 PartyV1/Lobby-only",
	#config.Tasks,
	rewardCycle,
	#config.MachineStages,
	totalCost,
	boombox.Price,
	boombox.AutoplayUpgradePrice
))
return true
