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

local root = requireChild(ReplicatedStorage, "CooperGame", "Folder")
local configModule = requireChild(root, "Config", "ModuleScript")
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
assert(config.SchemaVersion == 10, "The personal profile schema must be version 10")
assert(config.DataStoreName == "CooperFamilyTasks_v2", "Unexpected profile DataStore")
assert(#config.Tasks == 5, "The family loop must contain exactly five task definitions")
assert(#config.MachineStages == 11, "The Time Machine must retain all 11 stages")
assert(config.MachineStages[11].progress == 100, "The final stage must reach 100%")
assert(config.Mode == nil and config.Stability == nil and config.Chapters == nil, "Retired advanced state remains in the family config")

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
		assert(definition.guidance == true, definition.id .. " must expose the temporary development arrow")
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

local defaults = config.ProfileDefaults
assert(type(defaults) == "table" and defaults.schemaVersion == 10, "Profile defaults are not v10")
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
	"OrderMachinePart",
		"OrderBoombox",
		"orderBoombox",
		"UpgradeBoomboxAutoplay",
		"upgradeBoomboxAutoplay",
		"OrderTaskUpgrade",
		"orderTaskUpgrade",
	"SpendAllowance",
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
		"DELIVERY_RETRY_ATTEMPTS = 15",
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
	"local function boomboxSnapshot(profile)",
	"BeginBoomboxPlayback",
	"BoomboxPayoutTick",
	"EndBoomboxPlayback",
	"BoomboxFinished",
	"BOOMBOX_FINAL_TICK_TOLERANCE",
}) do
	assert(string.find(server.Source, marker, 1, true), "Server source is missing " .. marker)
end
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
	"Help George, Mary, and Missy with their requests",
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

local autoplayPurchaseSection = sourceSection(
	server.Source,
	"local function upgradeBoomboxAutoplay(profile)",
	"local function reportPlayerAction"
)
for _, marker in ipairs({
	"profile.data.boomboxPurchased",
	"profile.data.boomboxPlaced",
	"profile.data.boomboxAutoplayPurchased",
	"Config.Boombox.AutoplayUpgradePrice",
	"profile.data.allowance < price",
	"BoomboxAutoplayPurchased",
	"broadcastState()",
	"task.defer(saveProfile, profile.player, false)",
}) do
	assert(string.find(autoplayPurchaseSection, marker, 1, true), "Autoplay purchase is missing " .. marker)
end
local autoplayDebitAt = string.find(autoplayPurchaseSection, "setAllowance(profile, profile.data.allowance - price)", 1, true)
local autoplayEntitlementAt = string.find(autoplayPurchaseSection, "profile.data.boomboxAutoplayPurchased = true", 1, true)
local autoplayDirtyAt = string.find(autoplayPurchaseSection, "markDirty(profile)", 1, true)
assert(
	autoplayDebitAt and autoplayEntitlementAt and autoplayDirtyAt
		and autoplayDebitAt < autoplayEntitlementAt
		and autoplayEntitlementAt < autoplayDirtyAt,
	"Autoplay upgrade must atomically debit, grant entitlement, then mark the profile dirty"
)
assert(not string.find(autoplayPurchaseSection, "task.wait", 1, true), "Atomic autoplay purchase path must not yield")

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
	"local function creditBoomboxTick"
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

local tickSection = sourceSection(
	server.Source,
	"local function boomboxPayoutTick(player, sessionId)",
	"local function endBoomboxPlayback(profile, sessionId, reason, suppressFeedback)"
)
for _, marker in ipairs({
	"playback.sessionId ~= sessionId",
	"boomboxPlaybackOwner ~= player",
	"playback.paidTicks >= Config.Boombox.MaximumPaidTicks",
	"(playback.paidTicks + 1) * Config.Boombox.PayoutInterval",
	"BOOMBOX_TICK_EARLY_TOLERANCE",
	"Config.Boombox.TrackDuration + BOOMBOX_FINAL_TICK_TOLERANCE",
}) do
	assert(string.find(tickSection, marker, 1, true), "BoomboxPayoutTick is missing " .. marker)
end
local tickCapAt = string.find(tickSection, "playback.paidTicks >= Config.Boombox.MaximumPaidTicks", 1, true)
local tickAwardAt = string.find(tickSection, "local awarded = creditBoomboxTick(profile, playback)", 1, true)
assert(tickCapAt and tickAwardAt and tickCapAt < tickAwardAt, "Boombox tick cap must be checked before awarding allowance")

local endSection = sourceSection(
	server.Source,
	"local function endBoomboxPlayback(profile, sessionId, reason, suppressFeedback)",
	"local function endBoomboxPlaybackForPlayer"
)
for _, marker in ipairs({
	"playback.sessionId ~= sessionId",
	"endedReason == \"Completed\"",
	"playback.paidTicks == Config.Boombox.MaximumPaidTicks - 1",
	"Config.Boombox.TrackDuration - BOOMBOX_FINAL_TICK_TOLERANCE",
	"Config.Boombox.TrackDuration + BOOMBOX_FINAL_TICK_TOLERANCE",
	"creditBoomboxTick(profile, playback)",
	"profile.boomboxPlayback = nil",
	"BoomboxFinished",
}) do
	assert(string.find(endSection, marker, 1, true), "EndBoomboxPlayback is missing " .. marker)
end
local finalRaceCreditAt = string.find(endSection, "creditBoomboxTick(profile, playback)", 1, true)
local sessionClearAt = string.find(endSection, "profile.boomboxPlayback = nil", 1, true)
assert(
	finalRaceCreditAt and sessionClearAt and finalRaceCreditAt < sessionClearAt,
	"Completed-track final-tick race must resolve before the payout session is cleared"
)

assert(
	string.find(server.Source, "local nextCursor = (profile.taskCursor % #order) + 1", 1, true),
	"The four retained tasks no longer cycle in their exact order"
)
assert(
	string.find(server.Source, "profile.taskCursor = profile.data.totalTasks % #Config.TaskOrder", 1, true),
	"Task rotation must resume from persisted totalTasks rather than reset on rejoin"
)
assert(
	not string.find(server.Source, "taskCursor = 0", 1, true),
	"Rejoining must not reset the chore rotation to a farmable first task"
)
assert(
	not string.find(server.Source, "ProximityPromptService.PromptTriggered", 1, true),
	"Family server still duplicates the authoritative computer-open handler"
)
assert(
	string.find(server.Source, "if profile.loaded and not profile.task and currentTime >= profile.nextTaskAt", 1, true),
	"Simple family tasks are still gated by an external mode"
)

local savePayloadAt = string.find(server.Source, "local payload = sanitizeData(profile.data)", 1, true)
assert(savePayloadAt, "Profile saves must pass v8 progression fields through sanitizeData")
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
	"profile.taskCursor = profile.data.totalTasks % #Config.TaskOrder",
	"profile.data.boomboxPurchased and not profile.data.boomboxPlaced",
	"queueDelivery(profile, \"Boombox\", 0)",
	"if profile.dirty then",
	"task.defer(saveProfile, player, false)",
}) do
	assert(string.find(loadSection, marker, 1, true), "Profile load/recovery is missing " .. marker)
end
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

assert(state:GetAttribute("SchemaVersion") == 10, "Running state does not expose schema version 10")
assert(state:GetAttribute("FoundationContract") == "PersonalV4", "Running state does not expose PersonalV4")
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
	"[CooperGameAudit] PASS: %d personal tasks ($%d from original chores), %d machine stages ($%d), $%d income boombox + $%d autoplay",
	#config.Tasks,
	rewardCycle,
	#config.MachineStages,
	totalCost,
	boombox.Price,
	boombox.AutoplayUpgradePrice
))
return true
