-- Edit/runtime-safe, non-mutating audit for the Medford Bank keyboard-memory task
-- and the separately authorized HackerBot automation path.
-- Run after CooperFamilyTaskConfig, CooperGame server/client, and the dedicated
-- BankHack RemoteEvent have been installed into the place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local running = RunService:IsRunning()
local checks = 0

local function check(condition, message)
	checks += 1
	assert(condition, "[MedfordBankHackAudit] " .. message)
end

local function need(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	check(child ~= nil, (parent and parent:GetFullName() or "nil") .. " is missing " .. name)
	check(child.ClassName == className, child:GetFullName() .. " must be a " .. className)
	return child
end

local function has(source, marker, message)
	check(string.find(source, marker, 1, true) ~= nil, message .. ": " .. marker)
end

local function lacks(source, marker, message)
	check(string.find(source, marker, 1, true) == nil, message .. ": " .. marker)
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

local function functionSection(source, functionName)
	-- Include the opening parenthesis so a helper such as FooForSuccesses cannot
	-- be mistaken for its shorter Foo wrapper.
	local marker = "local function " .. functionName .. "("
	local startAt = string.find(source, marker, 1, true)
	if not startAt then
		marker = functionName .. " = function"
		startAt = string.find(source, marker, 1, true)
	end
	check(startAt ~= nil, "Server/client source is missing function " .. functionName)
	local nextAt = string.find(source, "\nlocal function ", startAt + #marker, true)
	return string.sub(source, startAt, nextAt and (nextAt - 1) or #source)
end

local function sourceSection(source, startMarker, endMarker, label)
	local startAt = string.find(source, startMarker, 1, true)
	check(startAt ~= nil, label .. " start marker is missing: " .. startMarker)
	local endAt = string.find(source, endMarker, startAt + #startMarker, true)
	check(endAt ~= nil, label .. " end marker is missing: " .. endMarker)
	return string.sub(source, startAt, endAt - 1)
end

local function ordered(source, markers, label)
	local cursor = 1
	for _, marker in ipairs(markers) do
		local found = string.find(source, marker, cursor, true)
		check(found ~= nil, label .. " is missing or misorders " .. marker)
		cursor = found + #marker
	end
end

-- Installed objects and fresh config ---------------------------------------

local root = need(ReplicatedStorage, "CooperGame", "Folder")
local configModule = need(root, "Config", "ModuleScript")
local state = need(root, "State", "Folder")
local remotes = need(root, "Remotes", "Folder")
need(remotes, "Snapshot", "RemoteEvent")
need(remotes, "Feedback", "RemoteEvent")
need(remotes, "Request", "RemoteEvent")
need(remotes, "BankHack", "RemoteEvent")

local Config
if running then
	Config = require(configModule)
else
	-- Plugin/command-bar require caches can outlive a source replacement. Read a
	-- disposable clone so this audit always verifies the saved edit-time source.
	local clone = configModule:Clone()
	clone.Name = "__MedfordBankHackAuditConfig"
	clone.Parent = root
	Config = require(clone)
	clone:Destroy()
end

check(type(Config) == "table" and table.isfrozen(Config), "Gameplay config must be a frozen table")
check(Config.SchemaVersion == 11, "Medford Bank persistence requires schema 11")
check(Config.DataStoreName == "CooperFamilyTasks_v2", "Schema migration must keep the established profile DataStore")
check(Config.DataStoreKeyPrefix == "player_", "Schema migration changed the profile key prefix")

local expectedOrder = { "GeorgeBeer", "MaryDishes", "MaryTrash", "MissyPlush", "MedfordBankHack" }
check(type(Config.Tasks) == "table" and #Config.Tasks == 5, "Exactly five rotating tasks must exist")
check(type(Config.TaskOrder) == "table" and #Config.TaskOrder == 5, "TaskOrder must contain exactly five tasks")
for index, taskId in ipairs(expectedOrder) do
	check(Config.Tasks[index].id == taskId, "Task definition order changed at index " .. index)
	check(Config.TaskOrder[index] == taskId, "Task rotation order changed at index " .. index)
end
local bankTask = Config.Tasks[5]
check(bankTask.title == "HACK THE MEDFORD BANK", "Bank task title changed")
check(bankTask.requester == "Terminal", "Bank task must be requested by the terminal")
check(bankTask.guidance == true and bankTask.startTarget == "Keyboard", "Bank task must guide the player to Sheldon's keyboard")
check(
	type(bankTask.startDescription) == "string"
		and string.find(bankTask.startDescription, "HACK MEDFORD BANK", 1, true) ~= nil,
	"Bank task does not point players to the kid-friendly HACK MEDFORD BANK option"
)

check(type(Config.TaskAutomationUpgrades) == "table" and #Config.TaskAutomationUpgrades == 5, "All five rotating tasks must have an automation robot")
local hackerBot = nil
local bankAutomationCount = 0
for _, definition in ipairs(Config.TaskAutomationUpgrades) do
	if definition.taskId == "MedfordBankHack" then
		bankAutomationCount += 1
		hackerBot = definition
	end
end
check(bankAutomationCount == 1, "Exactly one automation upgrade must cover the Medford Bank task")
check(type(hackerBot) == "table" and hackerBot.id == "HackerBot", "Medford Bank automation must be owned by HackerBot")
check(hackerBot.name == "HackerBot" and hackerBot.modelName == "HackerBot", "HackerBot display/model identity changed")
check(hackerBot.price == 1750, "HackerBot must cost $1750")
check(hackerBot.duration == 24, "HackerBot must run its visible breach sequence for 24 seconds")
check(hackerBot.installTarget == "HackerBotInstallAnchor", "HackerBot has the wrong install anchor")
check(
	hackerBot.description == "Automatically cracks each Medford Bank keyboard sequence and earns its scaling payout.",
	"HackerBot terminal description changed"
)

local bank = Config.BankHack
check(type(bank) == "table", "Config.BankHack is missing")
local requiredFields = {
	"Keys",
	"RoundCount",
	"StartingLength",
	"StartingLengthIncreaseEverySuccesses",
	"MaximumStartingLength",
	"BasePreviewStepSeconds",
	"SpeedupPerSuccess",
	"MinimumPreviewStepSeconds",
	"BaseReward",
	"RewardPerSuccess",
	"MaximumReward",
	"CueLightRatio",
	"LeadInSeconds",
	"RoundPauseSeconds",
	"RetryCooldownSeconds",
	"InputWindowBaseSeconds",
	"InputWindowPerKeySeconds",
	"InputRateLimitSeconds",
}
for _, field in ipairs(requiredFields) do
	check(bank[field] ~= nil, "Config.BankHack is missing " .. field)
end
if bank.TaskId ~= nil then
	check(bank.TaskId == "MedfordBankHack", "Config.BankHack.TaskId must identify the rotating bank task")
end

check(type(bank.Keys) == "table" and #bank.Keys >= 8 and #bank.Keys <= 26, "Bank key pool must be varied but readable")
local keySet = {}
for index, key in ipairs(bank.Keys) do
	check(type(key) == "string" and #key == 1 and string.match(key, "^[A-Z]$") ~= nil, "Bank key " .. index .. " must be one uppercase letter")
	check(keySet[key] == nil, "Bank key pool contains duplicate " .. tostring(key))
	keySet[key] = true
	local validKeyCode, keyCode = pcall(function()
		return Enum.KeyCode[key]
	end)
	check(validKeyCode and typeof(keyCode) == "EnumItem", "Bank key has no matching Enum.KeyCode: " .. tostring(key))
end

check(type(bank.RoundCount) == "number" and bank.RoundCount % 1 == 0 and bank.RoundCount >= 3 and bank.RoundCount <= 6, "RoundCount must remain a short progressive challenge")
check(type(bank.StartingLength) == "number" and bank.StartingLength % 1 == 0 and bank.StartingLength >= 2 and bank.StartingLength <= 4, "StartingLength is not beginner-friendly")
local maximumPatternLength = bank.StartingLength + bank.RoundCount - 1
check(maximumPatternLength <= 8, "The first-cycle final pattern is too long")
check(bank.StartingLengthIncreaseEverySuccesses == 2, "Bank opening-pattern growth must occur every two successful cycles")
check(bank.MaximumStartingLength == 4, "Bank opening patterns must cap at four keys")
check(bank.MaximumStartingLength >= bank.StartingLength, "MaximumStartingLength cannot be below the beginner pattern")
check(bank.MaximumStartingLength + bank.RoundCount - 1 <= 8, "Fully scaled final patterns must remain playable")
check(type(bank.BasePreviewStepSeconds) == "number" and bank.BasePreviewStepSeconds >= 0.5 and bank.BasePreviewStepSeconds <= 1.2, "Initial preview speed is not beginner-friendly")
check(bank.SpeedupPerSuccess == 0.06, "Each successful bank cycle must produce the intended noticeable 0.06-second cue speedup")
check(type(bank.MinimumPreviewStepSeconds) == "number" and bank.MinimumPreviewStepSeconds >= 0.2 and bank.MinimumPreviewStepSeconds < bank.BasePreviewStepSeconds, "Preview speed needs a playable lower bound")
check(type(bank.BaseReward) == "number" and bank.BaseReward % 1 == 0 and bank.BaseReward > 0, "Base bank reward must be a positive integer")
check(type(bank.RewardPerSuccess) == "number" and bank.RewardPerSuccess % 1 == 0 and bank.RewardPerSuccess > 0, "Repeat-success reward growth must be positive")
check(type(bank.MaximumReward) == "number" and bank.MaximumReward % 1 == 0 and bank.MaximumReward >= bank.BaseReward and bank.MaximumReward <= 1000, "Bank reward needs a safe economy cap")
check(bankTask.reward == bank.BaseReward, "The fifth task card reward must match the first bank cycle")
check(type(bank.CueLightRatio) == "number" and bank.CueLightRatio >= 0.35 and bank.CueLightRatio <= 0.85, "Cue light duration ratio is unreadable")
check(type(bank.LeadInSeconds) == "number" and bank.LeadInSeconds >= 0.2 and bank.LeadInSeconds <= 2, "Lead-in time is outside a responsive range")
check(type(bank.RoundPauseSeconds) == "number" and bank.RoundPauseSeconds >= 0.2 and bank.RoundPauseSeconds <= 2, "Round pause is outside a responsive range")
check(type(bank.RetryCooldownSeconds) == "number" and bank.RetryCooldownSeconds >= 0.5 and bank.RetryCooldownSeconds <= 10, "Retry cooldown is unsafe or frustrating")
check(type(bank.InputWindowBaseSeconds) == "number" and bank.InputWindowBaseSeconds >= 2 and bank.InputWindowBaseSeconds <= 15, "Input window base is unreasonable")
check(type(bank.InputWindowPerKeySeconds) == "number" and bank.InputWindowPerKeySeconds >= 0.25 and bank.InputWindowPerKeySeconds <= 3, "Per-key input window is unreasonable")
check(type(bank.InputRateLimitSeconds) == "number" and bank.InputRateLimitSeconds >= 0.02 and bank.InputRateLimitSeconds <= 0.2, "Input limiter must allow normal play while rejecting floods")
check(bank.InputRateLimitSeconds < bank.MinimumPreviewStepSeconds, "Input limiter is slower than the hardest cue interval")

local previousPreview = math.huge
local previousReward = -math.huge
local previousStartingLength = -math.huge
for successes = 0, 100 do
	local preview = math.max(bank.MinimumPreviewStepSeconds, bank.BasePreviewStepSeconds - successes * bank.SpeedupPerSuccess)
	local reward = math.min(bank.MaximumReward, bank.BaseReward + successes * bank.RewardPerSuccess)
	local startingLength = math.min(
		bank.MaximumStartingLength,
		bank.StartingLength + math.floor(successes / bank.StartingLengthIncreaseEverySuccesses)
	)
	check(preview <= previousPreview, "Preview difficulty became easier at success " .. successes)
	check(preview >= bank.MinimumPreviewStepSeconds, "Preview difficulty crossed its speed floor")
	check(reward >= previousReward, "Reward decreased at success " .. successes)
	check(reward <= bank.MaximumReward, "Reward crossed its configured cap")
	check(startingLength >= previousStartingLength, "Opening pattern became shorter at success " .. successes)
	check(startingLength >= bank.StartingLength and startingLength <= bank.MaximumStartingLength, "Opening pattern escaped its configured bounds")
	check(startingLength + bank.RoundCount - 1 <= 8, "Scaled final pattern became unreasonably long at success " .. successes)
	previousPreview = preview
	previousReward = reward
	previousStartingLength = startingLength
end
local expectedPreviewSteps = { 0.78, 0.72, 0.66, 0.60, 0.54 }
local expectedStartingLengths = { 2, 2, 3, 3, 4 }
for index, expectedPreview in ipairs(expectedPreviewSteps) do
	local successes = index - 1
	local preview = math.max(bank.MinimumPreviewStepSeconds, bank.BasePreviewStepSeconds - successes * bank.SpeedupPerSuccess)
	local startingLength = math.min(
		bank.MaximumStartingLength,
		bank.StartingLength + math.floor(successes / bank.StartingLengthIncreaseEverySuccesses)
	)
	check(math.abs(preview - expectedPreview) < 0.000001, string.format("Cycle %d cue interval must be %.2f seconds", index, expectedPreview))
	check(startingLength == expectedStartingLengths[index], string.format("Cycle %d must begin with %d keys", index, expectedStartingLengths[index]))
end
check(
	bank.BasePreviewStepSeconds - math.max(bank.MinimumPreviewStepSeconds, bank.BasePreviewStepSeconds - bank.SpeedupPerSuccess) >= 0.059,
	"The second cycle speedup is too subtle to notice"
)
check(math.min(bank.MaximumReward, bank.BaseReward + bank.RewardPerSuccess) > bank.BaseReward, "The second cycle does not pay more than the first")

local defaults = Config.ProfileDefaults
check(type(defaults) == "table" and defaults.schemaVersion == 11, "Profile defaults are not schema 11")
check(defaults.bankHackSuccesses == 0, "Fresh and migrated profiles must begin at bank cycle zero")
check(state:GetAttribute("SchemaVersion") == 11, "Shared State does not expose schema 11")
check(state:GetAttribute("SupportsMedfordBankHack") == true, "Shared State does not advertise Medford Bank hacking")

-- Server authority, persistence, and state machine -------------------------

local server = need(ServerScriptService, "CooperGame", "Script")
local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local client = need(starterScripts, "CooperGame", "LocalScript")
check(server.Enabled and client.Enabled, "CooperGame server/client must both be enabled")
local serverSource = server.Source
local clientSource = client.Source
check(#serverSource > 50000 and #clientSource > 50000, "Installed CooperGame sources look truncated")

for _, marker in ipairs({
	"ensureRemote(\"BankHack\")",
	"local BANK_TASK_ID = \"MedfordBankHack\"",
	"local bankHackConfig = Config.BankHack",
	"local bankKeySet = {}",
	"local bankHackSessionSerial = 0",
	"local bankInputNextAt = {}",
	"local function bankHackSuccessCount(profile)",
	"local function bankHackPreviewStepForSuccesses(successes)",
	"local function bankHackPreviewStep(profile)",
	"local function bankHackStartingLengthForSuccesses(successes)",
	"local function bankHackStartingLength(profile)",
	"local function bankHackReward(profile)",
	"randomizer:NextInteger(1, #bankKeys)",
	"bankHackEvent.OnServerEvent:Connect",
}) do
	has(serverSource, marker, "Server-authoritative bank state is incomplete")
end

local previewScaleFunction = functionSection(serverSource, "bankHackPreviewStepForSuccesses")
for _, marker in ipairs({
	"successes = finiteInteger(successes, 0, 0, 1_000_000)",
	"bankHackConfig.BasePreviewStepSeconds",
	"bankHackConfig.SpeedupPerSuccess",
	"bankHackConfig.MinimumPreviewStepSeconds",
	"math.max(minimum, base - successes * speedup)",
}) do
	has(previewScaleFunction, marker, "Server cue-speed scaling does not implement the capped per-success formula")
end
local previewProfileFunction = functionSection(serverSource, "bankHackPreviewStep")
has(
	previewProfileFunction,
	"bankHackPreviewStepForSuccesses(bankHackSuccessCount(profile))",
	"Profile cue speed does not derive exclusively from persistent successful hacks"
)

local lengthScaleFunction = functionSection(serverSource, "bankHackStartingLengthForSuccesses")
for _, marker in ipairs({
	"successes = finiteInteger(successes, 0, 0, 1_000_000)",
	"bankHackConfig.StartingLength",
	"bankHackConfig.StartingLengthIncreaseEverySuccesses",
	"bankHackConfig.MaximumStartingLength",
	"math.floor(successes / every)",
	"math.min(maximum, base + math.floor(successes / every))",
}) do
	has(lengthScaleFunction, marker, "Server opening-length scaling does not implement the capped two-success formula")
end
local lengthProfileFunction = functionSection(serverSource, "bankHackStartingLength")
has(
	lengthProfileFunction,
	"bankHackStartingLengthForSuccesses(bankHackSuccessCount(profile))",
	"Profile opening length does not derive exclusively from persistent successful hacks"
)

local sanitizer = sourceSection(serverSource, "local function sanitizeData(raw)", "local function profileKey", "Profile sanitizer")
has(sanitizer, "bankHackSuccesses = finiteInteger(raw.bankHackSuccesses, 0, 0, 1_000_000)", "Profile sanitizer does not safely migrate/cap bank successes")
lacks(sanitizer, "bankHackSuccesses = raw.bankHackSuccesses", "Sanitizer trusts unvalidated bank success data")

local automationSnapshotFunction = functionSection(serverSource, "automationSnapshot")
for _, marker in ipairs({
	"for _, definition in ipairs(Config.TaskAutomationUpgrades)",
	"reward = definition.taskId == BANK_TASK_ID",
	"bankHackReward(profile)",
	"taskById[definition.taskId].reward",
}) do
	has(automationSnapshotFunction, marker, "Automation catalog does not quote HackerBot's authoritative scaling reward")
end

local snapshotFunction = functionSection(serverSource, "bankHackSnapshot")
for _, marker in ipairs({
	"bankHackSuccessCount(profile)",
	"bankHackPreviewStep(profile)",
	"bankHackStartingLength(profile)",
	"bankHackReward(profile)",
	"taskActive =",
	"canStart =",
	"activeSession =",
	"status =",
	"cycle =",
	"successes =",
	"reward =",
	"round =",
	"roundCount =",
	"startingLength =",
	"previewStepSeconds =",
	"retryReadyAt =",
	"retryRemaining =",
}) do
	has(snapshotFunction, marker, "Bank snapshot omits authoritative progression data")
end
has(snapshotFunction, "record.bankStartingLength", "Active bank snapshots must retain the difficulty captured when that task began")
for _, forbidden in ipairs({ "pattern", "sequence", "expectedKey", "bankKeySet" }) do
	lacks(snapshotFunction, forbidden, "Persistent snapshot leaks the live answer")
end
has(serverSource, "bankHack = bankHackSnapshot(profile)", "Loaded snapshots do not expose snapshot.bankHack")
local snapshotFor = functionSection(serverSource, "snapshotFor")
has(snapshotFor, "bankHack = {", "Loading snapshots do not expose a safe snapshot.bankHack shape")
for _, forbidden in ipairs({ "pattern", "sequence", "expectedKey" }) do
	lacks(snapshotFor, forbidden, "Loading/loaded snapshots leak a bank answer")
end

local taskStartFunction = functionSection(serverSource, "startNextTask")
for _, marker in ipairs({
	"record.bankPreviewStepSeconds = bankHackPreviewStep(profile)",
	"record.bankStartingLength = bankHackStartingLength(profile)",
}) do
	has(taskStartFunction, marker, "Bank task assignment does not capture its complete cycle difficulty")
end

local automationLaunchFunction = functionSection(serverSource, "launchTaskAutomation")
for _, marker in ipairs({
	"record.automationRunId = runId",
	"record.id == BANK_TASK_ID",
	"definition.id ~= \"HackerBot\"",
	"profile.data.taskAutomationInstalled.HackerBot ~= true",
	"profile.bankHackSession and cancelBankHackSession",
	"cancelBankHackSession(profile, \"HackerBot took over the active bank task.\", true)",
	"record.bankAutomationRunId = runId",
	"profile.automationRuns[runId] = record",
	"bankCycle = record.bankCycle",
	"bankReward = record.bankReward",
	"completeTask(profile, record)",
}) do
	has(automationLaunchFunction, marker, "HackerBot launch lacks server-only ownership/run proof")
end
ordered(automationLaunchFunction, {
	"record.automationRunId = runId",
	"record.bankAutomationRunId = runId",
	"profile.automationRuns[runId] = record",
	"completeTask(profile, record)",
}, "HackerBot proof registration and completion")
lacks(automationLaunchFunction, "bankHackValidated", "HackerBot must not reuse the manual memory-game validation bit")
lacks(automationLaunchFunction, "bankHackEvent", "HackerBot must not fake client BankHack input packets")

local startFunction = functionSection(serverSource, "startBankHack")
for _, marker in ipairs({
	"validComputerSession(profile.player)",
	"profile.task",
	"BANK_TASK_ID",
	"profile.bankHackSession",
	"bankRetryReadyAt",
	"bankHackSessionSerial += 1",
	"sessionId",
	"profile.player.UserId",
	"HttpService:GenerateGUID(false)",
	"phase = \"Starting\"",
	"BankHackStarted",
	"allowedKeys = table.clone(bankKeys)",
	"cycle = session.cycle",
	"reward = session.reward",
	"roundCount = bankRoundCount()",
	"record.bankStartingLength",
	"bankHackStartingLength(profile)",
	"local sequenceLength = startingLength + bankRoundCount() - 1",
	"startingLength = startingLength",
	"startingLength = session.startingLength",
	"previewStepSeconds = session.previewStepSeconds",
	"serverTime = now",
}) do
	has(startFunction, marker, "Bank start validation/session creation is incomplete")
end
ordered(startFunction, {
	"record.bankStartingLength",
	"local sequenceLength = startingLength + bankRoundCount() - 1",
	"local session = {",
	"startingLength = startingLength",
	"bankPacket(profile.player, \"BankHackStarted\"",
	"startingLength = session.startingLength",
}, "Bank captured-length session construction")

local roundFunction = functionSection(serverSource, "beginBankHackRound")
for _, marker in ipairs({
	"bankSessionIsCurrent(profile, session)",
	"validComputerSession",
	"session.sequence",
	"finiteInteger(session.startingLength",
	"+ round - 1",
	"displayStartsAt",
	"inputOpensAt",
	"inputDeadline",
	"phase = \"Preview\"",
	"bankPacket(profile.player, \"BankHackRound\"",
	"pattern =",
	"round = round",
	"roundCount = roundCount",
	"patternLength = patternLength",
	"cycle = session.cycle",
	"reward = session.reward",
	"previewStepSeconds",
	"cueLightRatio",
	"cueLightSeconds",
	"serverTime",
}) do
	has(roundFunction, marker, "Round generation/timing packet is incomplete")
end
lacks(roundFunction, "bankHackStartingLength(", "A live bank round recalculates difficulty instead of using its captured session length")
lacks(roundFunction, "bankHackSuccessCount(", "A live bank round reads mutable profile progression instead of its captured session length")

local inputFunction = functionSection(serverSource, "submitBankHackInput")
for _, marker in ipairs({
	"type(payload) ~= \"table\"",
	"payload.sessionId",
	"payload.key",
	"#sessionId > 128",
	"#rawKey ~= 1",
	"profile.bankHackSession",
	"session.phase",
	"validComputerSession(profile.player)",
	"bankKeySet[key]",
	"passBankInputCooldown(profile.player)",
	"session.inputOpensAt",
	"session.inputDeadline",
	"session.sequence",
	"BankHackInputAccepted",
	"index = expectedIndex",
	"remaining = session.patternLength - expectedIndex",
	"key = key",
	"BankHackRoundComplete",
	"succeedBankHackSession(profile, session)",
}) do
	has(inputFunction, marker, "Bank input validation is incomplete")
end
local limiterFunction = functionSection(serverSource, "passBankInputCooldown")
for _, marker in ipairs({
	"bankInputNextAt[player]",
	"os.clock()",
	"bankHackConfig.InputRateLimitSeconds",
}) do
	has(limiterFunction, marker, "Dedicated per-key rate limiter is incomplete")
end

for _, functionName in ipairs({ "cancelBankHackSession", "failBankHackSession", "succeedBankHackSession" }) do
	check(
		string.find(serverSource, "local function " .. functionName, 1, true) ~= nil
			or string.find(serverSource, functionName .. " = function", 1, true) ~= nil,
		"Server is missing a terminal bank-hack path: " .. functionName
	)
end
local cancelFunction = functionSection(serverSource, "cancelBankHackSession")
has(cancelFunction, "profile.bankHackSession", "Cancel path does not clear the active server session")
has(cancelFunction, "BankHackCancelled", "Cancel path does not notify the owning client")
local failureFunction = functionSection(serverSource, "failBankHackSession")
has(failureFunction, "profile.bankHackSession", "Failure path does not invalidate the active server session")
has(failureFunction, "RetryCooldownSeconds", "Failure path does not enforce retry cooldown")
has(failureFunction, "BankHackFailed", "Failure path does not report failure")

local successFunction = functionSection(serverSource, "succeedBankHackSession")
for _, marker in ipairs({
	"profile.bankHackSession",
	"session.record.bankHackValidated = true",
	"session.record.step = \"Complete\"",
	"local nextSuccessCount = bankHackSuccessCount(profile) + 1",
	"BankHackSucceeded",
	"reward = session.reward",
	"successes = nextSuccessCount",
	"nextPreviewStepSeconds = bankHackPreviewStepForSuccesses(nextSuccessCount)",
	"nextStartingLength = bankHackStartingLengthForSuccesses(nextSuccessCount)",
	"completeTask(profile)",
}) do
	has(successFunction, marker, "Successful bank award path is incomplete")
end
local invalidateAt = string.find(successFunction, "profile.bankHackSession = nil", 1, true)
local validateAt = string.find(successFunction, "session.record.bankHackValidated = true", 1, true)
local completeAt = string.find(successFunction, "completeTask(profile)", 1, true)
check(invalidateAt ~= nil and validateAt ~= nil and completeAt ~= nil and invalidateAt < validateAt and validateAt < completeAt, "Success must invalidate its session, set server proof, then complete exactly once")

local completionFunction = sourceSection(serverSource, "completeTask = function(profile", "local function bankRoundCount", "Task completion authority")
for _, marker in ipairs({
	"record.id == BANK_TASK_ID",
	"local automatedBankProof = record.automated == true",
	"record.automationUpgradeId == \"HackerBot\"",
	"profile.data.taskAutomationInstalled.HackerBot == true",
	"type(record.bankAutomationRunId) == \"string\"",
	"record.bankAutomationRunId == record.automationRunId",
	"profile.automationRuns[record.automationRunId] == record",
	"local manualBankProof = record.automated ~= true and record.bankHackValidated == true",
	"if (not automatedBankProof and not manualBankProof) or record.bankSuccessCounted == true then",
	"record.bankSuccessCounted == true",
	"record.bankSuccessCounted = true",
	"reward = finiteInteger(record.bankReward, bankHackReward(profile)",
	"profile.data.bankHackSuccesses = bankHackSuccessCount(profile) + 1",
	"setAllowance(profile, profile.data.allowance + reward)",
	"profile.data.totalTasks += 1",
	"markDirty(profile)",
	"broadcastState()",
	"task.defer(saveProfile, profile.player, false)",
}) do
	has(completionFunction, marker, "Idempotent manual/HackerBot bank completion authority is incomplete")
end
ordered(completionFunction, {
	"record.bankSuccessCounted = true",
	"profile.data.bankHackSuccesses = bankHackSuccessCount(profile) + 1",
	"setAllowance(profile, profile.data.allowance + reward)",
	"profile.data.totalTasks += 1",
	"markDirty(profile)",
	"broadcastState()",
	"task.defer(saveProfile, profile.player, false)",
}, "Bank award/save ordering")
check(countPlain(serverSource, "profile.data.bankHackSuccesses = bankHackSuccessCount(profile) + 1") == 1, "Bank success progression has more than one mutation path")

local handler = sourceSection(serverSource, "bankHackEvent.OnServerEvent:Connect", "local function setupLeaderstats", "Dedicated bank remote handler")
for _, action in ipairs({ "Start", "Input", "Cancel" }) do
	has(handler, "action == \"" .. action .. "\"", "Dedicated remote does not explicitly allow " .. action)
end
for _, marker in ipairs({
	"type(action) ~= \"string\"",
	"profiles[player]",
	"profile.loaded",
	"profile.releasing",
	"startBankHack",
	"submitBankHackInput",
	"cancelBankHackSession",
	"BankHackError",
}) do
	has(handler, marker, "Dedicated bank remote entry validation is incomplete")
end
for _, marker in ipairs({
	"reportedId",
	"reportedId ~= session.id",
	"cancelBankHackSession(profile",
}) do
	has(handler, marker, "Cancel is not bound to the current server session")
end

-- Every delayed callback and every player lifecycle must invalidate stale work.
for _, marker in ipairs({
	"profile.bankHackSession == session",
	"validComputerSession(profile.player)",
	"cancelBankHackSession(profile",
	"bankInputNextAt[player] = nil",
}) do
	has(serverSource, marker, "Bank session lifecycle lacks stale-session cleanup")
end
local requestHandler = sourceSection(serverSource, "requestEvent.OnServerEvent:Connect", "local function setupLeaderstats", "Family request handler")
has(requestHandler, "action == \"CloseComputer\"", "Closing the terminal is not handled server-side")
has(requestHandler, "cancelBankHackSession", "Closing/EXIT does not cancel an active bank session")
local removingSection = sourceSection(serverSource, "Players.PlayerRemoving:Connect", "for _, player in ipairs(Players:GetPlayers())", "Player removal cleanup")
has(removingSection, "cancelBankHackSession", "Player removal does not cancel a bank session")
has(removingSection, "bankInputNextAt[player] = nil", "Player removal leaks its bank input limiter")
local watchdog = sourceSection(
	serverSource,
	"task.spawn(function()\n\tlocal nextAutoSave",
	"\n\nbroadcastState()",
	"Server watchdog"
)
has(watchdog, "bankHackSession", "Server watchdog does not inspect active bank sessions")
has(watchdog, "validComputerSession", "Server watchdog does not cancel bank sessions after leaving the computer")

-- The client can report only input intent. It can never report success, reward,
-- cycle, round, pattern, or a currency mutation.
for _, forbidden in ipairs({
	"setAllowance(",
	"AdjustCurrency",
	"SpendAllowance",
	"bankHackSuccesses +=",
	"Random.new(",
	"math.random(",
	"RewardPerSuccess",
	"MaximumReward",
	"bankHackEvent:FireServer(\"BankHackSucceeded\"",
	"requestEvent:FireServer(\"BankHack",
}) do
	lacks(clientSource, forbidden, "Client contains forbidden bank authority")
end

-- Client UI, input, timing, and stale-render protection --------------------

for _, marker in ipairs({
	"local ContextActionService = game:GetService(\"ContextActionService\")",
	"local bankHackEvent = remotes:WaitForChild(\"BankHack\"",
	"\"Hack Medford Bank\"",
	"MEDFORD BANK",
	"BankHackStarted",
	"BankHackRound",
	"BankHackInputAccepted",
	"BankHackRoundComplete",
	"BankHackFailed",
	"BankHackSucceeded",
	"BankHackCancelled",
	"BankHackError",
	"bankHackEvent.OnClientEvent:Connect",
	"ContextActionService:BindActionAtPriority",
	"ContextActionService:UnbindAction",
	"Enum.ContextActionResult.Sink",
	"local bankKeyRows =",
	"bankPanel.Parent = terminal",
	"keyButton.Activated:Connect",
	"submitBankKey(keyName)",
	"bankSnapshotCanStart",
	"packetSessionId ~= bankSessionId",
	"resetBankAttempt",
	"packet.sessionId",
	"packet.pattern",
	"packet.displayStartsAt",
	"packet.inputOpensAt",
	"workspace:GetServerTimeNow()",
}) do
	has(clientSource, marker, "Client bank terminal/UI contract is incomplete")
end

local bankStartConstructor = sourceSection(
	clientSource,
	"local bankStartButton = button(",
	"bankStartButton.ZIndex",
	"Bank ready-button constructor"
)
has(bankStartConstructor, '"HACK BANK"', "Bank ready button must be labeled HACK BANK")
local bankStartRefresh = sourceSection(
	clientSource,
	"local function refreshBankStartButton()",
	"local function bankSnapshotData",
	"Bank ready-button refresh"
)
has(
	bankStartRefresh,
	'elseif enabled then\n\t\tbankStartButton.Text = "HACK BANK"',
	"Available bank attempts must restore the exact HACK BANK label"
)
lacks(clientSource, "DIAL SECURE NODE", "Retired bank-start wording returned")

local bankSuccessPresentation = sourceSection(
	clientSource,
	"elseif kind == \"BankHackSucceeded\" then",
	"elseif kind == \"BankHackCancelled\" then",
	"Bank success presentation"
)
for _, marker in ipairs({
	"packet.nextPreviewStepSeconds",
	"packet.nextStartingLength",
	"Next cycle:",
	"second cues",
	"starting at %d keys",
	"It will be faster",
}) do
	has(bankSuccessPresentation, marker, "Bank success UI does not clearly explain the next difficulty increase")
end

-- Affordability notices may advertise HackerBot through the authoritative task-
-- robot catalog. The bank memory-game state itself must never become a separate
-- purchase candidate merely because a completed cycle raised allowance.
local upgradeNoticeUpdate = sourceSection(
	clientSource,
	"function upgradeNoticeUi.update(snapshot)",
	"local function taskIsAutomated",
	"Upgrade affordability candidates"
)
has(upgradeNoticeUpdate, "for _, entry in ipairs(automationCatalog(snapshot)) do", "HackerBot cannot participate in generic task-robot affordability notices")
lacks(upgradeNoticeUpdate, "snapshot.bankHack", "Bank memory-game state was added as a separate affordability candidate")

local allowedClientActions = { Start = true, Input = true, Cancel = true }
local parsedActions = 0
for action in string.gmatch(clientSource, 'bankHackEvent:FireServer%("([^"]+)"') do
	parsedActions += 1
	check(allowedClientActions[action] == true, "Client sends unapproved BankHack action " .. tostring(action))
end
check(parsedActions >= 3, "Client does not expose Start, Input, and Cancel requests")
check(parsedActions == countPlain(clientSource, "bankHackEvent:FireServer("), "Client contains a dynamic/unreviewed BankHack remote action")
for action in pairs(allowedClientActions) do
	check(countPlain(clientSource, "bankHackEvent:FireServer(\"" .. action .. "\"") >= 1, "Client never sends BankHack " .. action)
end

local inputSendAt = string.find(clientSource, "bankHackEvent:FireServer(\"Input\"", 1, true)
check(inputSendAt ~= nil, "Client input request is missing")
local inputSendTail = string.sub(clientSource, inputSendAt, math.min(#clientSource, inputSendAt + 300))
has(inputSendTail, "sessionId", "Client Input payload is not session-bound")
has(inputSendTail, "key", "Client Input payload does not contain the selected key")
for _, forbiddenField in ipairs({ "reward", "cycle", "round", "pattern", "success" }) do
	lacks(inputSendTail, forbiddenField, "Client Input payload contains server-owned field")
end

-- Persistent GUI construction must not occur inside renderTerminal, whose tree
-- rows are deliberately destroyed/rebuilt on every snapshot.
local renderTerminal = sourceSection(clientSource, "function renderTerminal()", "terminalBack.Activated:Connect", "Terminal renderer")
lacks(renderTerminal, "Instance.new(\"Frame\")", "Bank challenge UI is recreated during terminal rerenders")
lacks(renderTerminal, "bankHackEvent.OnClientEvent:Connect", "Bank remote connection is duplicated by terminal rerenders")
for _, marker in ipairs({
	"bankAnimationToken",
	"bankAnimationToken += 1",
	"sessionId",
	"bankAnimationToken == token",
}) do
	has(clientSource, marker, "Client lacks stale cue/rerender protection")
end

if running then
	for _, player in ipairs(Players:GetPlayers()) do
		check(player:GetAttribute("CooperGameSchemaVersion") == 11, player.Name .. " did not load a schema-11 profile")
		local serverEvents = ServerScriptService:FindFirstChild(Config.ServerEventsName)
		local api = serverEvents and serverEvents:FindFirstChild("API")
		if api and api:IsA("BindableFunction") then
			local snapshot = api:Invoke("GetSnapshot", player)
			check(type(snapshot) == "table" and type(snapshot.bankHack) == "table", player.Name .. " has no runtime snapshot.bankHack")
			check(snapshot.bankHack.pattern == nil and snapshot.bankHack.sequence == nil, player.Name .. " snapshot leaks the answer pattern")
			check(type(snapshot.bankHack.successes) == "number", player.Name .. " bank snapshot lacks success progression")
			check(type(snapshot.automation) == "table" and type(snapshot.automation.catalog) == "table", player.Name .. " has no runtime robot catalog")
			local runtimeHackerBot = nil
			for _, entry in ipairs(snapshot.automation.catalog) do
				if entry.id == "HackerBot" then
					runtimeHackerBot = entry
				end
			end
			check(type(runtimeHackerBot) == "table", player.Name .. " runtime robot catalog omits HackerBot")
			check(runtimeHackerBot.reward == snapshot.bankHack.reward, player.Name .. " HackerBot quote does not match the current scaling bank payout")
			local successes = math.max(0, math.floor(tonumber(snapshot.bankHack.successes) or 0))
			local expectedPreview = math.max(
				bank.MinimumPreviewStepSeconds,
				bank.BasePreviewStepSeconds - successes * bank.SpeedupPerSuccess
			)
			local expectedStartingLength = math.min(
				bank.MaximumStartingLength,
				bank.StartingLength + math.floor(successes / bank.StartingLengthIncreaseEverySuccesses)
			)
			check(
				math.abs((tonumber(snapshot.bankHack.previewStepSeconds) or -1) - expectedPreview) < 0.000001,
				player.Name .. " runtime bank cue speed does not match persistent successes"
			)
			check(
				tonumber(snapshot.bankHack.startingLength) == expectedStartingLength,
				player.Name .. " runtime bank opening length does not match persistent successes"
			)
		end
	end
end

print(string.format(
	"[MedfordBankHackAudit] PASS: %d non-mutating checks in %s mode; secure manual/HackerBot authority, dynamic robot reward, 0.06-second cycle speedup, 2-success pattern growth, session capture, and clear next-cycle UI verified",
	checks,
	running and "runtime" or "edit"
))
return true
