--!nonstrict
-- Standalone, non-mutating audit for the five paid family-task robots.
-- Safe to run from Studio's command bar in edit mode or after play-mode startup.
-- It reads config, instances, source, and read-only snapshots; it never orders an
-- upgrade, changes allowance, fires a gameplay event, or writes persistent data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local running = RunService:IsRunning()
local checks = 0

local function check(condition, message)
	checks += 1
	assert(condition, "[TaskAutomationAudit] " .. message)
end

local function need(parent, name, className, recursive)
	check(typeof(parent) == "Instance", "Cannot find " .. name .. " below a missing parent")
	local child = parent:FindFirstChild(name, recursive == true)
	check(child ~= nil, parent:GetFullName() .. " is missing " .. name)
	if className then
		check(child:IsA(className), child:GetFullName() .. " must be a " .. className)
	end
	return child
end

local function sourceOf(scriptObject)
	check(scriptObject:IsA("LuaSourceContainer"), scriptObject:GetFullName() .. " is not source-bearing")
	check(not scriptObject.Disabled, scriptObject:GetFullName() .. " is disabled")
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	check(ok and type(source) == "string", "Studio could not read " .. scriptObject:GetFullName() .. ".Source")
	check(#source > 1000, scriptObject:GetFullName() .. " has empty or placeholder source")
	return source
end

local function has(source, marker, message)
	check(string.find(source, marker, 1, true) ~= nil, message or ("Source is missing " .. marker))
end

local function lacks(source, marker, message)
	check(string.find(source, marker, 1, true) == nil, message or ("Source unexpectedly contains " .. marker))
end

local function section(source, startMarker, endMarker, label)
	local startAt = string.find(source, startMarker, 1, true)
	check(startAt ~= nil, (label or "Source") .. " is missing section start " .. startMarker)
	local endAt = startAt and string.find(source, endMarker, startAt + #startMarker, true) or nil
	check(endAt ~= nil, (label or "Source") .. " is missing section end " .. endMarker)
	return string.sub(source, startAt, endAt - 1)
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

local function ordered(source, markers, message)
	local cursor = 1
	for _, marker in ipairs(markers) do
		local found = string.find(source, marker, cursor, true)
		check(found ~= nil, (message or "Required ordering is missing") .. ": " .. marker)
		cursor = found + #marker
	end
end

local function countWhere(root, predicate)
	local count = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if predicate(descendant) then
			count += 1
		end
	end
	return count
end

local function closeCFrame(actual, expected, positionTolerance, directionTolerance)
	return typeof(actual) == "CFrame"
		and typeof(expected) == "CFrame"
		and (actual.Position - expected.Position).Magnitude <= positionTolerance
		and actual.LookVector:Dot(expected.LookVector) >= 1 - directionTolerance
		and actual.UpVector:Dot(expected.UpVector) >= 1 - directionTolerance
end

local function resolveDotted(root, path)
	local current = root
	local index = 0
	for segment in string.gmatch(tostring(path or ""), "[^%.]+") do
		index += 1
		current = index == 1 and current:FindFirstChild(segment, true) or current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return index > 0 and current or nil
end

-- Exact configuration, schema, and migration defaults ----------------------

local gameRoot = need(ReplicatedStorage, "CooperGame", "Folder")
local configModule = need(gameRoot, "Config", "ModuleScript")
local state = need(gameRoot, "State", "Folder")
local remotes = need(gameRoot, "Remotes", "Folder")
for _, remoteName in ipairs({ "Snapshot", "Feedback", "Request", "BankHack" }) do
	need(remotes, remoteName, "RemoteEvent")
end

local Config
if running then
	Config = require(configModule)
else
	-- Studio's command/plugin VM caches ModuleScript require results across
	-- installer reruns. Audit a fresh clone so this verifier always reads the
	-- source currently saved in the place, then remove it immediately.
	local freshConfig = configModule:Clone()
	freshConfig.Name = "__TaskAutomationAuditConfig"
	freshConfig.Parent = gameRoot
	Config = require(freshConfig)
	freshConfig:Destroy()
end
check(type(Config) == "table", "CooperGame.Config did not return a table")
check(table.isfrozen(Config), "The top-level gameplay config must remain frozen")
check(Config.SchemaVersion == 12, "Task automation must use persistence schema 12")
check(Config.DataStoreName == "CooperFamilyTasks_v2", "Task automation unexpectedly forked the profile DataStore")
check(Config.DataStoreKeyPrefix == "player_", "Unexpected profile key prefix")

local expected = {
	{
		id = "BeerBot",
		taskId = "GeorgeBeer",
		name = "BeerBot",
		price = 750,
		duration = 60,
		installTarget = "BeerBotInstallAnchor",
		modelName = "BeerBot",
		description = "Automatically orders, collects, and refrigerates George's beer.",
		reward = 55,
		parts = { "Base", "BeigeController", "OrderLight", "Antenna", "TypingFinger", "TypingArm" },
	},
	{
		id = "DishBot",
		taskId = "MaryDishes",
		name = "DishBot",
		price = 900,
		duration = 10,
		installTarget = "DishBotInstallAnchor",
		modelName = "DishBot",
		description = "Automatically washes every batch of dirty dishes in the kitchen sink.",
		reward = 30,
		parts = { "SinkHub", "SinkMountBracket", "ControlBox", "WashLight", "DishArm1", "DishArm2", "DishWrist1", "DishWrist2", "Scrubber1", "Scrubber2", "WashBubble1", "WashBubble2" },
	},
	{
		id = "TrashBot",
		taskId = "MaryTrash",
		name = "TrashBot",
		price = 1100,
		duration = 60,
		installTarget = "TrashBotInstallAnchor",
		modelName = "TrashBot",
		description = "Automatically carries kitchen trash to the outdoor garage-side can.",
		reward = 40,
		parts = { "Chassis", "Body", "StatusEye", "WheelLeft", "WheelRight", "LiftMast", "LiftArm", "GrabberLeft", "GrabberRight", "CargoBag", "CargoBagTie" },
	},
	{
		id = "ToyFinder",
		taskId = "MissyPlush",
		name = "Toy Finder",
		price = 1350,
		duration = 36,
		installTarget = "ToyFinderInstallAnchor",
		modelName = "ToyFinder",
		description = "Automatically finds Missy's lost stuffed animal and returns it to her bed.",
		reward = 70,
		parts = { "DroneBody", "Scanner", "RotorLeft", "RotorRight", "RotorLeftStrut", "RotorRightStrut", "PickupCable", "PickupWrist", "ClawLeft", "ClawRight" },
	},
	{
		id = "HackerBot",
		taskId = "MedfordBankHack",
		name = "HackerBot",
		price = 1750,
		duration = 24,
		installTarget = "HackerBotInstallAnchor",
		modelName = "HackerBot",
		description = "Automatically cracks each Medford Bank keyboard sequence and earns its scaling payout.",
		reward = 90,
		parts = {
			"CipherDock", "CipherConsole", "CipherScreen", "BreachStatus", "SignalAntenna",
			"TypingProbeLeft", "TypingProbeRight",
			"ProbeArm1", "ProbeArm2", "ProbeForearm1", "ProbeForearm2", "ProbeWrist1", "ProbeWrist2",
			"DataPulse1", "DataPulse2", "DataPulse3", "DataPulse4", "DataPulse5",
		},
	},
}

check(type(Config.TaskAutomationUpgrades) == "table", "Config.TaskAutomationUpgrades is missing")
check(#Config.TaskAutomationUpgrades == 5, "Exactly five task automation upgrades must exist")
check(#Config.Tasks == 5 and #Config.TaskOrder == 5, "Automation must preserve the five-task loop")
check(Config.TaskDirector.AutomatedNextDelay == 3, "Accepted robot chores must release the next request after three seconds")

local taskById = {}
for _, definition in ipairs(Config.Tasks) do
	taskById[definition.id] = definition
end
local ids, taskIds, modelNames, targets, definitionsById = {}, {}, {}, {}, {}
local previousPrice = 0
for index, contract in ipairs(expected) do
	local definition = Config.TaskAutomationUpgrades[index]
	check(type(definition) == "table", "Upgrade definition " .. index .. " is missing")
	for _, field in ipairs({ "id", "taskId", "name", "price", "duration", "installTarget", "modelName", "description" }) do
		check(definition[field] == contract[field], string.format("%s has the wrong %s", contract.id, field))
	end
	check(not ids[definition.id], "Duplicate task automation id " .. definition.id)
	check(not taskIds[definition.taskId], "More than one upgrade automates " .. definition.taskId)
	check(not modelNames[definition.modelName], "Duplicate automation model name " .. definition.modelName)
	check(not targets[definition.installTarget], "Duplicate automation install target " .. definition.installTarget)
	ids[definition.id] = true
	definitionsById[definition.id] = definition
	taskIds[definition.taskId] = true
	modelNames[definition.modelName] = true
	targets[definition.installTarget] = true
	local taskDefinition = taskById[definition.taskId]
	check(taskDefinition ~= nil, definition.id .. " references an unknown family task")
	check(taskDefinition.reward == contract.reward, definition.id .. " no longer pays its task's ordinary balanced reward")
	check(definition.price > taskDefinition.reward * 10, definition.id .. " is too cheap to be a meaningful progression upgrade")
	check(definition.price > previousPrice, "Automation prices must increase through the task cycle")
	check(definition.duration >= 10 and definition.duration <= 60, definition.id .. " has an unreasonable automatic work duration")
	check(#definition.description >= 35, definition.id .. " needs a useful terminal description")
	previousPrice = definition.price
end
for _, taskId in ipairs(Config.TaskOrder) do
	check(taskIds[taskId] == true, "No task automation upgrade covers " .. taskId)
end

local defaults = Config.ProfileDefaults
check(type(defaults) == "table" and defaults.schemaVersion == 12, "Profile defaults are not schema 12")
check(type(defaults.taskAutomationInstalled) == "table", "Fresh profiles need an empty installed-upgrades map")
check(next(defaults.taskAutomationInstalled) == nil, "Fresh profiles must not receive a free task robot")
check(defaults.pendingTaskUpgradeId == "", "Fresh profiles must not begin with a paid delivery pending")
check(defaults.bankHackSuccesses == 0, "Fresh profiles must begin with zero successful bank hacks")
check(state:GetAttribute("SchemaVersion") == 12, "Shared State does not expose schema 12")
check(state:GetAttribute("FoundationContract") == "PersonalV4", "Task automation must preserve the PersonalV4 foundation contract")
check(state:GetAttribute("SupportsTaskAutomation") == true, "Shared State does not advertise task automation")
check(state:GetAttribute("SupportsMedfordBankHack") == true, "Shared State does not advertise Medford Bank hacking")

-- Installed source and server authority ------------------------------------

local serverScript = need(ServerScriptService, "CooperGame", "Script")
local worldScript = need(ServerScriptService, "CooperTaskWorld", "Script")
local interactionsScript = need(ServerScriptService, "CooperInteractions", "Script")
local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientScript = need(starterScripts, "CooperGame", "LocalScript")
local serverSource = sourceOf(serverScript)
local worldSource = sourceOf(worldScript)
local interactionsSource = sourceOf(interactionsScript)
local clientSource = sourceOf(clientScript)

for _, marker in ipairs({
	"local runTaskAutomation = ensureServerEvent(\"BindableEvent\", \"RunTaskAutomation\")",
	"local automationById = {}",
	"local automationByTaskId = {}",
	"Config.TaskAutomationUpgrades",
}) do
	has(serverSource, marker, "Server did not install automation registry/event marker " .. marker)
end

local sanitizeSource = section(serverSource, "local function sanitizeData(raw)", "local function profileKey", "Profile sanitizer")
for _, marker in ipairs({
	"local installedRaw = type(raw.taskAutomationInstalled) == \"table\"",
	"for _, definition in ipairs(Config.TaskAutomationUpgrades)",
	"installedRaw[definition.id] == true",
	"taskAutomationInstalled[definition.id] = true",
	"type(raw.pendingTaskUpgradeId) == \"string\"",
	"not automationById[pendingTaskUpgradeId]",
	"taskAutomationInstalled[pendingTaskUpgradeId]",
	"taskAutomationInstalled = taskAutomationInstalled",
	"pendingTaskUpgradeId = pendingTaskUpgradeId",
}) do
		has(sanitizeSource, marker, "Profile sanitizer is missing " .. marker)
end
lacks(sanitizeSource, "taskAutomationInstalled = installedRaw", "Sanitizer must not trust arbitrary saved upgrade ids")

local saveSource = section(serverSource, "local function saveProfile(player, releasing)", "local function pickHiddenLocation", "Profile persistence")
for _, marker in ipairs({
	"if profile.saving then",
	"local maximumAttempts = releasing and RELEASE_SAVE_ATTEMPTS or 3",
	"if attempt < maximumAttempts then",
	"until leaseRejected or (writeComplete and not profile.dirty) or attempt >= maximumAttempts",
	"local owner = storedProfileLease(current)",
	"owner ~= profile.leaseToken",
	"payload[PROFILE_LEASE_FIELD]",
	"invalidateLostProfileLease(profile, failure)",
	"releaseProfileLease(profile, RELEASE_SAVE_ATTEMPTS)",
	"if profile.dirty and ok and not releasing and profiles[player] == profile then",
}) do
	has(saveSource, marker, "Profile persistence is missing bounded serialized retry behavior: " .. marker)
end
lacks(saveSource, "if releasing and attempt < maximumAttempts then", "Normal economy saves must retry transient DataStore failures too")
lacks(saveSource, "or (not ok and not releasing)", "Normal economy saves must not stop after their first failed write")

local automationSnapshotSource = section(serverSource, "local function automationSnapshot(profile)", "local function deliverySnapshot", "Automation snapshot")
for _, marker in ipairs({
	"catalog = catalog",
	"installedCount = installedCount",
	"totalCount = #Config.TaskAutomationUpgrades",
	"pendingId = pendingId ~= \"\" and pendingId or nil",
	"activeRuns = activeRuns",
	"activeTaskId",
	"activeUpgradeId",
	"runId = runId",
	"startedAt = record.automationStartedAt",
	"completesAt = record.automationCompletesAt",
	"id = definition.id",
	"taskId = definition.taskId",
	"name = definition.name",
	"price = definition.price",
	"duration = definition.duration",
	"installTarget = definition.installTarget",
		"modelName = definition.modelName",
		"description = definition.description",
		"reward = definition.taskId == BANK_TASK_ID",
		"bankHackReward(profile)",
		"taskById[definition.taskId].reward",
	"installed = isInstalled",
	"pending = isPending",
	"canOrder = profile ~= nil",
}) do
	has(automationSnapshotSource, marker, "Automation snapshot is missing " .. marker)
end

local deliverySnapshotSource = section(serverSource, "local function deliverySnapshot(profile)", "local function snapshotFor", "Delivery snapshot")
for _, marker in ipairs({
	"profile.data.pendingTaskUpgradeId ~= \"\"",
	"kind = \"TaskUpgrade\"",
	"upgradeId = upgradeId",
	"name = definition and definition.name",
	"profile.taskUpgradeDeliveryStep or \"WaitingDelivery\"",
	"then (definition and definition.installTarget or nil)",
	"\"Delivery_TaskUpgrade_\" .. tostring(profile.player.UserId)",
	"else \"DeliveryDropZone\"",
}) do
	has(deliverySnapshotSource, marker, "Task-upgrade delivery snapshot is missing " .. marker)
end

local orderSource = section(serverSource, "local function orderTaskUpgrade(profile, requestedUpgradeId)", "local function reportPlayerAction", "Task-upgrade order")
for _, marker in ipairs({
	"local definition = automationById[upgradeId]",
	"profile.data.taskAutomationInstalled[upgradeId] == true",
	"profile.data.pendingTaskUpgradeId ~= \"\"",
	"profile.data.pendingPartStage > 0",
	"profile.data.boomboxPurchased and not profile.data.boomboxPlaced",
	"profile.data.allowance < price",
	"feedback(profile.player, \"TaskUpgradeOrdered\"",
	"task.defer(saveProfile, profile.player, false)",
}) do
	has(orderSource, marker, "Authoritative task-upgrade ordering is missing " .. marker)
end
lacks(orderSource, "task.wait", "Atomic task-upgrade ordering must not yield")
ordered(orderSource, {
	"setAllowance(profile, profile.data.allowance - price)",
	"profile.data.pendingTaskUpgradeId = upgradeId",
	"profile.taskUpgradeDeliveryStep = \"WaitingDelivery\"",
	"markDirty(profile)",
	"queueDelivery(profile, \"TaskUpgrade\", 0, upgradeId)",
	"feedback(profile.player, \"TaskUpgradeOrdered\"",
	"broadcastState()",
	"task.defer(saveProfile, profile.player, false)",
}, "Upgrade purchase must debit, persist, queue, announce, and save in that order")

local reportSource = section(serverSource, "local function reportPlayerAction(eventKey, player, metadata)", "reportAction.Event:Connect", "World-report handler")
for _, marker in ipairs({
	"local reportedUpgradeId = type(metadata.upgradeId) == \"string\"",
	"reportedUpgradeId == pendingUpgradeId",
	"eventKey == \"TaskUpgradeDeliverySpawned\"",
	"profile.taskUpgradeDeliveryStep = \"Collect\"",
	"eventKey == \"TaskUpgradeCratePicked\"",
	"profile.taskUpgradeDeliveryStep = \"Install\"",
	"eventKey == \"TaskUpgradeInstalled\"",
	"profile.data.taskAutomationInstalled[pendingUpgradeId] = true",
	"profile.data.pendingTaskUpgradeId = \"\"",
	"feedback(player, \"TaskUpgradeInstalled\"",
	"local activeRecord = profile.task",
	"activeRecord.id == pendingUpgrade.taskId",
	"destroyManualCarryForAutomation(player, activeRecord.id)",
	"armTaskAutomation(activeRecord, pendingUpgrade)",
	"launchTaskAutomation(profile, activeRecord, pendingUpgrade)",
	"task.defer(saveProfile, player, false)",
	"eventKey == \"TaskUpgradeCarryLost\"",
	"queueDelivery(profile, \"TaskUpgrade\", 0, pendingUpgradeId)",
	"if record.automated then",
	"Ignore every manual world/client completion path.",
}) do
	has(reportSource, marker, "Task-upgrade lifecycle/manual rejection is missing " .. marker)
end
ordered(reportSource, {
	"eventKey == \"TaskUpgradeInstalled\"",
	"profile.data.taskAutomationInstalled[pendingUpgradeId] = true",
	"profile.data.pendingTaskUpgradeId = \"\"",
	"profile.taskUpgradeDeliveryStep = nil",
	"markDirty(profile)",
	"feedback(player, \"TaskUpgradeInstalled\"",
	"broadcastState()",
	"task.defer(saveProfile, player, false)",
}, "Installation entitlement must be committed and saved before returning")
ordered(reportSource, {
	"feedback(player, \"TaskUpgradeInstalled\"",
	"local activeRecord = profile.task",
	"activeRecord.id == pendingUpgrade.taskId",
	"destroyManualCarryForAutomation(player, activeRecord.id)",
	"armTaskAutomation(activeRecord, pendingUpgrade)",
	"launchTaskAutomation(profile, activeRecord, pendingUpgrade)",
	"broadcastState()",
	"task.defer(saveProfile, player, false)",
}, "Installing a matching robot mid-chore must clean obsolete carry state and immediately transfer that task to server automation")

local carryCleanupSource = section(serverSource, "local function destroyManualCarryForAutomation", "-- The hidden prop is rendered locally", "Automation carry cleanup")
for _, marker in ipairs({
	"player.Character",
	"player:FindFirstChildOfClass(\"Backpack\")",
	"taskId == \"MaryTrash\"",
	"child:GetAttribute(\"FamilyTrashBag\") == true",
	"taskId == \"MissyPlush\"",
	"child:GetAttribute(\"FamilyMissyPlush\") == true",
	"child:Destroy()",
}) do
	has(carryCleanupSource, marker, "Mid-task automation cleanup is missing " .. marker)
end

local armSource = section(serverSource, "local function armTaskAutomation(record, definition)", "local function launchTaskAutomation", "Automation arming")
for _, marker in ipairs({
	"record.automationPreviousStep = record.step",
	"record.automated = true",
	"record.automationUpgradeId = definition.id",
	"record.automationStartedAt = serverNow()",
	"record.automationCompletesAt = record.automationStartedAt + definition.duration",
	"record.step = \"Automated\"",
}) do
	has(armSource, marker, "Automation phase transfer is missing " .. marker)
end

local launchSource = section(serverSource, "local function launchTaskAutomation(profile, record, definition)", "local function startNextTask", "Server automation launcher")
for _, marker in ipairs({
	"profile.task ~= record",
	"record.automated ~= true",
	"record.automationUpgradeId ~= definition.id",
	"local runId = string.format(",
	"record.automationRunId = runId",
	"record.id == BANK_TASK_ID",
	"definition.id ~= \"HackerBot\"",
	"profile.data.taskAutomationInstalled.HackerBot ~= true",
	"cancelBankHackSession(profile, \"HackerBot took over the active bank task.\", true)",
	"record.bankAutomationRunId = runId",
	"profile.automationRuns[runId] = record",
	"runId = runId",
	"previousStep = record.automationPreviousStep",
	"startedAt = record.automationStartedAt",
	"completesAt = record.automationCompletesAt",
	"bankCycle = record.bankCycle",
	"bankReward = record.bankReward",
	"feedback(profile.player, \"TaskAutomationStarted\"",
	"runTaskAutomation:Fire(profile.player, definition.id, metadata)",
	"completeTask(profile, record)",
	"task.delay(definition.duration, function()",
	"profiles[profile.player] == profile",
	"profile.automationRuns[runId] == record",
	"profile.automationRuns[runId] = nil",
	"definition.id == \"BeerBot\"",
	"stockAutomatedBeer()",
	"feedback(profile.player, \"TaskAutomationFinished\"",
}) do
	has(launchSource, marker, "Overlapping authoritative automation is missing " .. marker)
end
lacks(launchSource, "requestEvent", "A client request must not drive automatic task completion")
lacks(launchSource, "bankHackValidated", "HackerBot must use its dedicated run proof instead of impersonating a successful manual key sequence")
ordered(launchSource, {
	"record.automationRunId = runId",
	"record.bankAutomationRunId = runId",
	"profile.automationRuns[runId] = record",
	"runTaskAutomation:Fire(profile.player, definition.id, metadata)",
	"completeTask(profile, record)",
	"task.delay(definition.duration, function()",
	"profile.automationRuns[runId] = nil",
}, "A robot must accept and reward once before its physical background run is cleaned up")

local taskStartSource = section(serverSource, "local function startNextTask(profile)", "local function scheduleNextTask", "Task director")
for _, marker in ipairs({
	"local automationDefinition = automationByTaskId[id]",
	"profile.data.taskAutomationInstalled[automationDefinition.id] == true",
	"automationRunIsActive(profile, automationDefinition.id)",
	"profile.nextTaskAt = serverNow() + 1",
	"armTaskAutomation(record, automationDefinition)",
	"profile.task = record",
	"if record.automated then",
	"launchTaskAutomation(profile, record, automationDefinition)",
}) do
	has(taskStartSource, marker, "New tasks do not enter the shared automation launcher: " .. marker)
end
ordered(taskStartSource, {
	"armTaskAutomation(record, automationDefinition)",
	"profile.task = record",
	"feedback(profile.player, \"TaskStarted\"",
	"launchTaskAutomation(profile, record, automationDefinition)",
}, "A new automated chore must be armed, made current, announced, then launched")

local beerStockSource = section(serverSource, "stockAutomatedBeer = function()", "completeTask = function(profile, expectedRecord)", "Authoritative BeerBot stocking")
for _, marker in ipairs({
		"WhiteHotpointRefrigerator",
		"CooperBeerCount",
		"CooperBeerCapacity",
		"math.min(capacity, current + 6)",
	}) do
	has(beerStockSource, marker, "Authoritative BeerBot stocking is missing " .. marker)
end
lacks(beerStockSource, "current + 12", "BeerBot must stock the six cans shown in its delivered case, not twelve")
has(
	interactionsSource,
	"fridge:GetAttributeChangedSignal(\"CooperBeerCount\"):Connect(updateBeerVisuals)",
	"Refrigerator visuals must refresh immediately when BeerBot changes the authoritative beer count"
)

local completeSource = section(serverSource, "completeTask = function(profile, expectedRecord)", "local function bankRoundCount", "Task completion")
ordered(completeSource, {
	"local record = expectedRecord or profile.task",
	"profile.task ~= record",
	"local reward = finiteInteger(definition.reward",
	"setAllowance(profile, profile.data.allowance + reward)",
	"profile.data.totalTasks += 1",
	"profile.task = nil",
	"markDirty(profile)",
	"Config.TaskDirector.AutomatedNextDelay",
	"feedback(profile.player, \"TaskComplete\"",
	"automated = record.automated == true",
	"task.defer(saveProfile, profile.player, false)",
}, "Automatic chores must use the ordinary authoritative reward/save path")
for _, marker in ipairs({
	"local automatedBankProof = record.automated == true",
	"record.automationUpgradeId == \"HackerBot\"",
	"profile.data.taskAutomationInstalled.HackerBot == true",
	"type(record.bankAutomationRunId) == \"string\"",
	"record.bankAutomationRunId == record.automationRunId",
	"profile.automationRuns[record.automationRunId] == record",
	"local manualBankProof = record.automated ~= true and record.bankHackValidated == true",
	"if (not automatedBankProof and not manualBankProof) or record.bankSuccessCounted == true then",
}) do
	has(completeSource, marker, "Bank automation is missing its separate server-only completion proof: " .. marker)
end
lacks(completeSource, "stockAutomatedBeer()", "Beer must be stocked when BeerBot visibly finishes, not when it merely accepts the chore")

local descriptionSource = section(serverSource, "local function taskDescription(profile)", "local function hiddenSnapshot", "Task presentation")
for _, marker in ipairs({
	"local automationDefinition = record.automated",
	"is handling this task automatically",
	"targetHint = nil",
	"guidance = false",
	"automated = record.automated == true",
	"automationCompletesAt = record.automationCompletesAt",
}) do
	has(descriptionSource, marker, "Automated task snapshot is missing " .. marker)
end
local hiddenSource = section(serverSource, "local function hiddenSnapshot(profile)", "local function boomboxSnapshot", "Hidden-toy snapshot")
has(hiddenSource, "if not record.automated", "Toy Finder must suppress the manual hidden-toy pickup snapshot")

local requestSource = section(serverSource, "requestEvent.OnServerEvent:Connect", "Players.PlayerAdded:Connect", "Remote request router")
ordered(requestSource, {
	"or action == \"OrderTaskUpgrade\"",
	"and not validComputerSession(player)",
	"elseif action == \"OrderTaskUpgrade\" then",
	"payload.upgradeId",
	"orderTaskUpgrade(profile, requestedUpgradeId)",
}, "Remote upgrade orders must pass through the trusted computer-session gate")
local apiSource = section(serverSource, "serverAPI.OnInvoke = function", "requestEvent.OnServerEvent:Connect", "Internal server API")
ordered(apiSource, {
	"elseif operation == \"OrderTaskUpgrade\" then",
	"not validComputerSession(player)",
	"return orderTaskUpgrade(profiles[player], requestedUpgradeId)",
}, "Internal upgrade ordering must enforce the same trusted computer session")

-- Client shop, delivery guidance, and automated-task presentation ----------

local noticeUiSource = section(
	clientSource,
	"local upgradeNoticeUi = {",
	"-- Button-driven Cooper computer",
	"Upgrade-affordability banner"
)
for _, marker in ipairs({
	"entries = {}",
	"announced = {}",
	'upgradeNoticeUi.frame.Name = "UpgradeAffordableNotice"',
	"upgradeNoticeUi.frame.Parent = scaleRoot",
	"upgradeNoticeUi.frame.ZIndex = 50",
	"upgradeNoticeUi.title.ZIndex = 51",
	"upgradeNoticeUi.text.ZIndex = 51",
	"function upgradeNoticeUi.show(entries)",
	"upgradeNoticeUi.entries[entry.key] = entry",
	"for _, entry in pairs(upgradeNoticeUi.entries) do",
	"table.sort(ordered",
	'and "PURCHASE NOW AFFORDABLE!"',
	'or string.format("%d PURCHASES NOW AFFORDABLE!", #ordered)',
	"for index = 1, #ordered, 2 do",
	"for itemIndex = index, math.min(index + 1, #ordered) do",
	'table.clear(upgradeNoticeUi.entries)',
}) do
	has(noticeUiSource, marker, "Separate aggregated upgrade banner is missing " .. marker)
end
check(
	countPlain(clientSource, 'upgradeNoticeUi.frame.Name = "UpgradeAffordableNotice"') == 1,
	"Client must construct exactly one independent upgrade-affordability banner"
)
lacks(noticeUiSource, "showToast(", "Upgrade affordability incorrectly borrows the one-slot activity toast")

local noticeUpdateSource = section(
	clientSource,
	"function upgradeNoticeUi.update(snapshot)",
	"local function taskIsAutomated",
	"Upgrade-affordability snapshot update"
)
for _, marker in ipairs({
	"local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))",
	"local newlyAffordable = {}",
	"local function consider(key, name, priceValue, retired, canBuyNow)",
	"local nextPart = type(snapshot.nextMachinePart) == \"table\"",
	'"MachinePart:" .. tostring(stage)',
	'"Time Machine — " .. tostring(nextPart.name',
	"nextPart.cost",
	"nextPart.canOrder == true",
	"for _, entry in ipairs(automationCatalog(snapshot)) do",
	"local pending = automationEntryPending(snapshot, entry)",
	'"TaskUpgrade:" .. id',
	'entry.name or "Task Robot"',
	"entry.price",
	"entry.installed == true or pending",
	"entry.canOrder == true",
	'"Boombox"',
	'"Cooper Party Boombox"',
	'"BoomboxAutoplay"',
	'"Boombox Autoplay"',
	"upgradeNoticeUi.show(newlyAffordable)",
}) do
		has(noticeUpdateSource, marker, "Task-robot affordability coverage is missing " .. marker)
end
ordered(noticeUpdateSource, {
	"if retired == true then",
	"upgradeNoticeUi.announced[key] = nil",
	"if allowance < price then",
	"upgradeNoticeUi.announced[key] = nil",
	"if canBuyNow == true and upgradeNoticeUi.announced[key] ~= true then",
	"upgradeNoticeUi.announced[key] = true",
	"table.insert(newlyAffordable",
}, "Per-upgrade affordability latch has the wrong threshold lifecycle")
check(
	countPlain(noticeUpdateSource, "upgradeNoticeUi.announced[key] = nil") == 2,
	"An affordability latch may reset only when retired or below its own price"
)
check(
	countPlain(noticeUpdateSource, "upgradeNoticeUi.announced[key] = true") == 1,
	"Each affordability episode must announce an item only once"
)
lacks(noticeUpdateSource, "if canBuyNow == false", "Temporary delivery/session blocking incorrectly rearms an affordability notice")
lacks(noticeUpdateSource, "Config.", "Client affordability uses config prices instead of authoritative snapshot prices")
lacks(noticeUpdateSource, "snapshot.bankHack", "Bank gameplay must not leak into purchase affordability notices")
has(clientSource, "MedfordBankHack = Color3.fromRGB(64, 231, 255)", "HackerBot delivery and task feedback have no cyan visual identity")
has(clientSource, "MedfordBankHack = \"cyan\"", "HackerBot guidance has no readable color name")

local terminalSource = section(clientSource, "function renderTerminal()", "terminalBack.Activated:Connect", "Computer terminal")
for _, marker in ipairs({
	"\"Buy Task Robots\"",
	"showPage(\"Automation\")",
	"terminalPage == \"Automation\"",
	"automationData(snapshot)",
	"automationCatalog(snapshot)",
	"automation.installedCount",
	"automation.totalCount",
	"entry.installed == true",
	"automationEntryPending(snapshot, entry)",
	"entry.canOrder == false",
	"entry.price",
	"selected.reward",
	"selected.duration",
	"selected.description",
	"taskRole(selected.taskId)",
	"AUTOMATIC REWARD",
	"local row = treeLine((entryId == automationSelectedId",
	"\"StatusBadge\"",
	"\"Buy \" .. tostring(selected.name or \"Task Robot\")",
	"requestEvent:FireServer(\"OrderTaskUpgrade\", {",
	"upgradeId = tostring(selected.id",
	"BOOMBOX AUTOPLAY",
	"\"Buy Boombox Autoplay — $\"",
	"requestEvent:FireServer(\"UpgradeBoomboxAutoplay\")",
}) do
	has(terminalSource, marker, "Task-robot terminal page is missing shop contract " .. marker)
end
ordered(terminalSource, {
	"elseif allowance < selectedPrice then",
	"elseif selected.canOrder == false then",
	"requestEvent:FireServer(\"OrderTaskUpgrade\", {",
	"upgradeId = tostring(selected.id",
}, "Blocked or unaffordable upgrades must remain non-clickable before the Order button is created")
check(
	countPlain(terminalSource, "requestEvent:FireServer(\"OrderTaskUpgrade\"") == 1,
	"Task-robot shop must expose exactly one server-authorized purchase route"
)
lacks(
	terminalSource,
	'entryName .. "  —  " .. stateLabel',
	"Robot names and statuses are fused into one terminal-row text string"
)

local terminalRowSource = section(
	clientSource,
	"local function treeLine",
	"local function treeFolder",
	"Terminal row presentation"
)
for _, marker in ipairs({
	"row.TextStrokeTransparency = 1",
	"local outline = stroke(row",
}) do
	has(terminalRowSource, marker, "Terminal action-row styling is missing " .. marker)
end

local sharedStrokeSource = section(
	clientSource,
	"local function stroke",
	"local function label",
	"Shared terminal border-stroke helper"
)
has(
	sharedStrokeSource,
	"item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border",
	"Terminal row and badge strokes must use ApplyStrokeMode.Border"
)

local statusBadgeSource = section(
	clientSource,
	"local row = treeLine((entryId == automationSelectedId",
	"treeLine(\"SELECTED ROBOT\"",
	"Robot status-badge presentation"
)
for _, marker in ipairs({
	"\"StatusBadge\"",
	"stateLabel",
	"statusBadge.TextStrokeTransparency = 1",
	"stroke(statusBadge",
}) do
	has(statusBadgeSource, marker, "Robot status badge is missing " .. marker)
end

local guidanceSource = section(clientSource, "local function automationDeliveryStyle", "local function updateArrow", "Client delivery guidance")
for _, marker in ipairs({
	"automationTaskColors",
	"delivery.targetHint",
	"entry and entry.installTarget",
	"kind == \"TaskUpgrade\"",
	"Follow the ",
	"It installs automatically",
	"INSTALL ",
}) do
	has(guidanceSource, marker, "Task-upgrade guidance is missing " .. marker)
end
local taskUpgradePriorityAt = string.find(guidanceSource, "tostring(delivery.kind or \"\") == \"TaskUpgrade\"", 1, true)
local boomboxPriorityAt = string.find(guidanceSource, "tostring(delivery.kind or \"\") == \"Boombox\"", 1, true)
check(taskUpgradePriorityAt and boomboxPriorityAt and taskUpgradePriorityAt < boomboxPriorityAt, "Carried task robots must outrank boombox and chore arrows")
local arrowRetrySource = section(clientSource, "local function updateArrow(snapshot)", "RunService.RenderStepped:Connect", "Stream-safe task guidance")
for _, marker in ipairs({
	"workspace.DescendantAdded:Connect",
	"arrowResolveScheduled",
	"task.delay(0.1",
	"not arrowModel and resolveTarget(hint)",
	"updateArrow(snapshot)",
}) do
	has(arrowRetrySource, marker, "Streamed install targets cannot recover their arrow: " .. marker)
end

local hiddenClientSource = section(clientSource, "local function updateHidden(snapshot)", "-- Ground-level guidance", "Client hidden-toy presentation")
has(hiddenClientSource, "local automated = taskIsAutomated(taskData)", "Automated Toy Finder task does not suppress manual hidden-toy presentation")
has(hiddenClientSource, "not automated and snapshot.hidden or nil", "Automated Toy Finder task can still create a manual pickup prompt")
has(hiddenClientSource, "local missingKind = taskData and taskData.id == \"MissyPlush\"", "Toy Finder must still hide the selected missing toy from Missy's bed while it works")
has(hiddenClientSource, "upgradeNoticeUi.automationRun(snapshot, \"MissyPlush\")", "The selected bed toy must stay hidden for the full background Toy Finder run")

local dirtyDishesSource = section(clientSource, "local function updateDirtyDishesVisibility(snapshot)", "workspace.DescendantAdded:Connect", "Dirty-dish background run presentation")
has(dirtyDishesSource, "upgradeNoticeUi.automationRun(snapshot, \"MaryDishes\") ~= nil", "Dirty dishes must remain visible until DishBot physically finishes")

local promptSource = section(clientSource, "local function updateWorldPrompts(snapshot)", "-- Task stations can stream", "Client task prompts")
has(promptSource, "local manualTask = not taskIsAutomated(taskData) and taskData or nil", "Automated tasks do not suppress manual world prompts")
for _, manualAnchor in ipairs({
	"DishesPromptAnchor",
	"TrashPickupAnchor",
	"OutdoorTrashAnchor",
	"MissyPlushReturnAnchor",
	"GeorgeBeerDropAnchor",
}) do
	has(promptSource, "configure(\"" .. manualAnchor .. "\", manualTask", manualAnchor .. " can remain active during robot work")
end

local applySource = section(clientSource, "local function applySnapshot(snapshot)", "snapshotEvent.OnClientEvent", "HUD snapshot renderer")
has(applySource, "upgradeNoticeUi.update(snapshot)", "Authoritative snapshots do not drive affordability notifications")
check(
	countPlain(clientSource, "\n\tupgradeNoticeUi.update(snapshot)\n") == 1,
	"Affordability evaluation must run once per accepted snapshot"
)
for _, marker in ipairs({
	"local automated = taskIsAutomated(taskData)",
	"AUTOMATION ",
	"ROBOT WORKING",
	"AUTOMATIC REWARD",
	"taskDescription.Text = tostring(taskData.description)",
}) do
	has(applySource, marker, "Automated-task HUD is missing " .. marker)
end
for _, feedbackKind in ipairs({ "TaskUpgradeOrdered", "TaskUpgradeInstalled", "TaskAutomationStarted", "TaskAutomationFinished" }) do
	has(clientSource, "kind == \"" .. feedbackKind .. "\"", "Client has no feedback for " .. feedbackKind)
end
lacks(clientSource, "runTaskAutomation:Fire", "Client must never start its own task automation timer")
lacks(clientSource, "TaskUpgradeInstalled\", player", "Client must never self-report a paid installation")

-- Authored install stations and permanent robot models ---------------------

local environment = need(workspace, "CooperHouseEnvironment", "Model")
local house = need(environment, "CooperHouse", "Model")
local exteriorDetails = need(house, "ExteriorDetails", "Model")
local furniture = need(house, "FurnitureAndProps", "Model")
local frontDoor = need(exteriorDetails, "InteractiveFrontDoor", "Model")
local patioDoor = need(exteriorDetails, "InteractiveDenPatioDoor", "Model")
local refrigerator = need(furniture, "WhiteHotpointRefrigerator", "Model", true)
local frontDoorSource = sourceOf(need(frontDoor, "FrontDoorController", "Script"))
local patioDoorSource = sourceOf(need(patioDoor, "PatioDoorController", "Script"))
for label, doorSource in pairs({ FrontDoor = frontDoorSource, PatioDoor = patioDoorSource }) do
	for _, marker in ipairs({
		"AutomationDoorCommand",
		"AutomationHoldOpen",
		"local function acquireAutomationHold",
		"local function releaseAutomationHold",
		"command == \"getstate\"",
		"command == \"open\"",
		"command == \"close\"",
		"command == \"acquireholdopen\"",
		"command == \"releaseholdopen\"",
	}) do
		has(doorSource, marker, label .. " is missing its robot-safe door command contract: " .. marker)
	end
	has(doorSource, "if door:GetAttribute(\"AutomationHoldOpen\") == true and isOpen then", label .. " still lets a player close the door on a travelling robot")
end
for _, marker in ipairs({
	"AutomationDoorCommand",
	"AutomationHoldOpen",
	"setFridgeOpen",
	"command == \"getstate\"",
	"command == \"open\"",
	"command == \"close\"",
	"command == \"acquireholdopen\"",
	"command == \"releaseholdopen\"",
}) do
	has(interactionsSource, marker, "Refrigerator is missing its BeerRunner door command contract: " .. marker)
end
if running then
	need(frontDoor, "AutomationDoorCommand", "BindableFunction")
	need(patioDoor, "AutomationDoorCommand", "BindableFunction")
	need(refrigerator, "AutomationDoorCommand", "BindableFunction")
end
local taskWorld = need(environment, Config.WorldRootName, "Model")
local stations = need(taskWorld, "Stations", "Folder")
local visuals = need(taskWorld, "TaskVisuals", "Folder")
local deliveryWorld = need(taskWorld, "Delivery", "Model")
check(taskWorld:GetAttribute("Ready") == true, "Family task world did not finish installing")
check(taskWorld:GetAttribute("SupportsTaskAutomation") == true, "Task world does not advertise robot support")
check(taskWorld:GetAttribute("InstallVersion") == "2026-07-21.hackerbot.1", "Task world HackerBot install version is stale")
check(taskWorld:GetAttribute("StationCount") == 13, "Task world must expose the original eight stations plus five robot install anchors")
check(taskWorld:GetAttribute("TaskAutomationRobotCount") == 5, "Task world does not advertise exactly five robot models")
check(countWhere(visuals, function(item)
	return item:IsA("Model") and item:GetAttribute("TaskAutomationRobot") == true
end) == 5, "TaskVisuals must contain exactly five permanent automation robots")
check(countWhere(stations, function(item)
	return item:IsA("ProximityPrompt") and item:GetAttribute("FamilyTaskAction") == "TaskUpgradeInstall"
end) == 5, "Stations must contain exactly five robot-install interactions")
check(countWhere(visuals, function(item)
	return item:IsA("BasePart") and type(item:GetAttribute("TaskUpgradeInstallPad")) == "string"
end) == 5, "TaskVisuals must contain exactly five color-coded robot setup pads")

local modelsById = {}
for index, contract in ipairs(expected) do
	local definition = Config.TaskAutomationUpgrades[index]
	local anchor = need(stations, definition.installTarget, "BasePart")
	local prompt = need(anchor, "TaskPrompt", "ProximityPrompt")
	local model = need(visuals, definition.modelName, "Model")
	local pad = need(visuals, definition.id .. "InstallPad", "BasePart")
	modelsById[definition.id] = model

	check(anchor:GetAttribute("UpgradeId") == definition.id, definition.id .. " install anchor has the wrong upgrade id")
	check(type(anchor:GetAttribute("FurnitureAnchor")) == "string" and #anchor:GetAttribute("FurnitureAnchor") > 2, definition.id .. " install anchor is not furniture-relative")
	check(anchor.Transparency == 1 and anchor.Anchored, definition.id .. " install anchor must be invisible and stable")
	check(not anchor.CanCollide and not anchor.CanTouch, definition.id .. " install anchor can obstruct the player")
	check(prompt:GetAttribute("FamilyTaskAction") == "TaskUpgradeInstall", definition.id .. " prompt has the wrong action")
	check(prompt:GetAttribute("UpgradeId") == definition.id, definition.id .. " prompt can install the wrong robot")
	check(prompt.RequiresLineOfSight == false and prompt.MaxActivationDistance == 10, definition.id .. " install interaction is not accessible")
	check(math.abs(prompt.HoldDuration - 0.8) < 0.001, definition.id .. " install hold duration changed")

	check(pad:GetAttribute("TaskUpgradeInstallPad") == definition.id, definition.id .. " setup pad has the wrong id")
	check(pad.Anchored and not pad.CanCollide and not pad.CanTouch and not pad.CanQuery, definition.id .. " setup pad has unsafe physics")
	check(pad.Material == Enum.Material.Neon and pad.Size.Y <= 0.08, definition.id .. " setup pad is not a thin color-coded floor marker")
	check((Vector2.new(pad.Position.X, pad.Position.Z) - Vector2.new(anchor.Position.X, anchor.Position.Z)).Magnitude <= 0.05, definition.id .. " setup pad is not below its anchor")

	check(model.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, definition.id .. " must stream as one complete robot")
	check(model:GetAttribute("TaskAutomationRobot") == true, definition.id .. " is missing its robot tag")
	check(model:GetAttribute("UpgradeId") == definition.id, definition.id .. " model has the wrong upgrade id")
	check(model:GetAttribute("InstallAnchor") == definition.installTarget, definition.id .. " model and config disagree on setup target")
	check(typeof(model:GetAttribute("HomePivot")) == "CFrame", definition.id .. " has no stable home pivot")
	check(model.PrimaryPart ~= nil and model.PrimaryPart:IsDescendantOf(model), definition.id .. " has no stable PrimaryPart")
	local robotRunning = running and model:GetAttribute("AutomationRunning") == true
	if robotRunning then
		check(type(model:GetAttribute("AutomationOwnerUserId")) == "number", definition.id .. " active visual has no owner")
		check(model:GetAttribute("AutomationTaskId") == definition.taskId, definition.id .. " active visual is bound to the wrong task")
		local startedAt = model:GetAttribute("AutomationStartedAt")
		local completesAt = model:GetAttribute("AutomationCompletesAt")
		check(type(startedAt) == "number" and type(completesAt) == "number" and completesAt > startedAt, definition.id .. " active visual has an invalid server phase window")
	end
	if not robotRunning then
		check((model:GetPivot().Position - anchor.Position).Magnitude <= 4.5, definition.id .. " robot is not naturally near its setup marker")
	end

	local furniturePath = anchor:GetAttribute("FurnitureAnchor")
	local furnitureAnchor = resolveDotted(environment, furniturePath)
	check(furnitureAnchor ~= nil, definition.id .. " references missing furniture " .. tostring(furniturePath))
	local furniturePosition = if furnitureAnchor:IsA("BasePart") then furnitureAnchor.Position else furnitureAnchor:GetPivot().Position
	if not robotRunning then
		check((model:GetPivot().Position - furniturePosition).Magnitude <= 7, definition.id .. " is detached from its named furniture")
	end

	for _, partName in ipairs(contract.parts) do
		need(model, partName, "BasePart", true)
	end
	local robotPartCount = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			robotPartCount += 1
			check(descendant:GetAttribute("AutomationRobotPart") == true, descendant:GetFullName() .. " is outside the robot visibility contract")
			check(typeof(descendant:GetAttribute("AutomationHomeCFrame")) == "CFrame", descendant:GetFullName() .. " has no home CFrame")
			local visibleTransparency = descendant:GetAttribute("AutomationVisibleTransparency")
			check(type(visibleTransparency) == "number" and visibleTransparency >= 0 and visibleTransparency <= 1, descendant:GetFullName() .. " has no valid installed transparency")
			check(type(descendant:GetAttribute("AutomationVisibleCanCollide")) == "boolean", descendant:GetFullName() .. " has no installed collision contract")
			check(descendant.Anchored and not descendant.CanTouch, descendant:GetFullName() .. " has unsafe robot physics")
			if not running then
				check(descendant.Transparency == 1 and not descendant.CanCollide and not descendant.CanQuery, descendant:GetFullName() .. " must author hidden before ownership is loaded")
			elseif robotRunning then
				check(not descendant.CanCollide and not descendant.CanQuery, descendant:GetFullName() .. " can collide with players while its robot is moving")
			else
				check(descendant.CanQuery == descendant.CanCollide, descendant:GetFullName() .. " runtime query/collision state diverged")
			end
		end
	end
	check(robotPartCount >= 6, definition.id .. " is an underbuilt placeholder instead of a modeled robot")
	if not running then
		check(closeCFrame(model:GetPivot(), model:GetAttribute("HomePivot"), 0.01, 0.001), definition.id .. " authored pivot does not match its saved home")
	end
	check(model:FindFirstChild("AutomationStatusLight", true) ~= nil, definition.id .. " has no status-light feedback")
end

check(modelsById.BeerBot:FindFirstChild("AutomationLabel", true) ~= nil, "BeerBot needs its AUTO ORDER display")
check(modelsById.BeerBot:GetAttribute("TypingArmSegmentCount") == 3, "BeerBot needs a three-segment arm routed around the computer")
check(modelsById.BeerBot:GetAttribute("DeskPlacement") == "RightFrontClear", "BeerBot is not in its cube-safe desk placement")
check(modelsById.BeerBot:GetAttribute("MobileUnitModel") == "BeerRunner", "BeerBot does not declare its visible collection vehicle")
check(modelsById.BeerBot:GetAttribute("CaseVisualModel") == "BeerCaseVisual", "BeerBot does not declare its visible delivered case")
need(modelsById.BeerBot, "TypingArmElbow", "BasePart", true)
need(modelsById.BeerBot, "TypingArmWrist", "BasePart", true)
local beerRunner = need(modelsById.BeerBot, "BeerRunner", "Model", true)
check(beerRunner.PrimaryPart == need(beerRunner, "RunnerChassis", "BasePart"), "BeerRunner must pivot from RunnerChassis")
check(beerRunner:GetAttribute("AutomationMobileUnit") == true, "BeerRunner is not tagged as the mobile unit")
check(beerRunner:GetAttribute("RunnerMoveSpeed") == 11, "BeerRunner must move slowly enough for a player to follow")
check(typeof(beerRunner:GetAttribute("HomePivot")) == "CFrame" and typeof(beerRunner:GetAttribute("AutomationHomePivot")) == "CFrame", "BeerRunner has no exact return pose")
local _, beerRunnerSize = beerRunner:GetBoundingBox()
check(beerRunnerSize.X <= 1.15 and beerRunnerSize.Z <= 1.00, "BeerRunner is too wide to clear the dining-table/fridge lane")
for _, partName in ipairs({
	"RunnerWheelLeft", "RunnerWheelRight", "RunnerStatus", "RunnerBody",
	"RunnerCargoRack", "RunnerLiftMast", "RunnerLiftArm",
	"RunnerGrabberLeft", "RunnerGrabberRight",
}) do
	need(beerRunner, partName, "BasePart", true)
end
local beerCaseVisual = need(modelsById.BeerBot, "BeerCaseVisual", "Model", true)
check(beerCaseVisual.PrimaryPart == need(beerCaseVisual, "CaseBody", "BasePart"), "BeerCaseVisual must pivot from CaseBody")
check(beerCaseVisual:GetAttribute("AutomationBeerCaseVisual") == true, "BeerCaseVisual is not tagged as the carried case")
check(beerCaseVisual:GetAttribute("CaseCanCount") == 6, "BeerCaseVisual must visibly contain six cans")
check(typeof(beerCaseVisual:GetAttribute("HomePivot")) == "CFrame" and typeof(beerCaseVisual:GetAttribute("AutomationHomePivot")) == "CFrame", "BeerCaseVisual has no exact restore pose")
for _, partName in ipairs({ "CaseBandLeft", "CaseBandRight", "CaseLabelPlate" }) do
	need(beerCaseVisual, partName, "BasePart", true)
end
for index = 1, 6 do
	need(beerCaseVisual, string.format("CaseCanBody%02d", index), "BasePart", true)
	need(beerCaseVisual, string.format("CaseCanTop%02d", index), "BasePart", true)
end
for _, descendant in ipairs(beerCaseVisual:GetDescendants()) do
	if descendant:IsA("BasePart") then
		check(descendant:GetAttribute("AutomationBeerCasePart") == true, descendant:GetFullName() .. " is outside the visible beer-case carry contract")
		local activeTransparency = descendant:GetAttribute("AutomationActiveTransparency")
		check(type(activeTransparency) == "number" and activeTransparency < 1, descendant:GetFullName() .. " cannot become visible when BeerRunner collects it")
	end
end
for _, effectContract in ipairs({
	{ "DishBot", "WashBubble1" },
	{ "DishBot", "WashBubble2" },
	{ "TrashBot", "CargoBag" },
	{ "TrashBot", "CargoBagTie" },
	{ "ToyFinder", "PickupCable" },
	{ "ToyFinder", "PickupWrist" },
}) do
	local effect = need(modelsById[effectContract[1]], effectContract[2], "BasePart", true)
	local activeTransparency = effect:GetAttribute("AutomationActiveTransparency")
	check(type(activeTransparency) == "number" and activeTransparency < 1, effect:GetFullName() .. " has no active-only visual state")
end
for _, partName in ipairs({ "LiftMast", "LiftArm", "GrabberLeft", "GrabberRight" }) do
	local liftPart = need(modelsById.TrashBot, partName, "BasePart", true)
	check(liftPart:GetAttribute("AutomationTrashLiftPart") == true, liftPart:GetFullName() .. " is outside the trash extraction mechanism")
end
for _, partName in ipairs({ "CargoBag", "CargoBagTie" }) do
	local cargoPart = need(modelsById.TrashBot, partName, "BasePart", true)
	check(cargoPart:GetAttribute("AutomationTrashCargoPart") == true, cargoPart:GetFullName() .. " is outside the carried-bag visual contract")
end
check(modelsById.TrashBot:GetAttribute("PickupMechanism") == "LiftArmAndGrabbers", "TrashBot does not declare a visible pickup mechanism")
check(modelsById.TrashBot:GetAttribute("TrashLiftPartCount") == 4, "TrashBot needs its four-part lift and grabber mechanism")
check(modelsById.TrashBot:GetAttribute("TrashCargoPartCount") == 2, "TrashBot needs a visible bag and tied top while carrying trash")
check(modelsById.ToyFinder:GetAttribute("PickupMechanism") == "CableClawWithTelescopingWrist", "Toy Finder does not declare its cable, wrist, and claw pickup")
check(modelsById.ToyFinder:GetAttribute("CableClawPartCount") == 4, "Toy Finder needs one cable, one telescoping wrist, and two claws")
check(modelsById.ToyFinder:GetAttribute("UsesSolidScanBeam") == false, "Toy Finder must not use another solid scanner rod")
check(modelsById.ToyFinder:FindFirstChild("ScanBeam", true) == nil, "Toy Finder still contains the obsolete solid scan rod")
check(modelsById.ToyFinder:FindFirstChild("PlushProxy", true) == nil, "Toy Finder still contains the placeholder plush ball")
check(modelsById.HackerBot:GetAttribute("HackingMechanism") == "DualKeyboardProbe", "HackerBot must declare its dual keyboard-probe mechanism")
check(modelsById.HackerBot:GetAttribute("KeyboardProbeCount") == 2, "HackerBot must expose exactly two keyboard probes")
local cipherScreen = need(modelsById.HackerBot, "CipherScreen", "BasePart", true)
local cipherDisplay = need(modelsById.HackerBot, "CipherDisplay", "SurfaceGui", true)
check(cipherDisplay:GetAttribute("AutomationVisibleEnabled") == true, "HackerBot cipher display is outside installed visibility ownership")
check(cipherDisplay.Adornee == nil or cipherDisplay.Adornee == cipherScreen, "HackerBot cipher display is attached to the wrong surface")
check(cipherDisplay.Face == Enum.NormalId.Back, "HackerBot cipher display must face the chair/player side of Sheldon's desk")
local hackerHome = modelsById.HackerBot:GetAttribute("HomePivot")
check(
	typeof(hackerHome) == "CFrame" and hackerHome:PointToObjectSpace(cipherScreen.Position).Z > 0.20,
	"HackerBot cipher screen is mounted on the rear/wall side of its controller"
)
need(cipherDisplay, "CipherText", "TextLabel", true)
check(countWhere(modelsById.HackerBot, function(item)
	return item:IsA("BasePart") and item:GetAttribute("AutomationHackerProbe") == true
end) == 2, "HackerBot must have exactly two tagged typing probes")
check(countWhere(modelsById.HackerBot, function(item)
	return item:IsA("BasePart") and item:GetAttribute("AutomationHackerPulse") == true
end) == 5, "HackerBot must have exactly five tagged data pulses")
for index = 1, 5 do
	local pulse = need(modelsById.HackerBot, "DataPulse" .. tostring(index), "BasePart", true)
	check(pulse:GetAttribute("PulseIndex") == index, pulse:GetFullName() .. " has the wrong pulse ordering")
	check(pulse:GetAttribute("AutomationActiveTransparency") == 0.05, pulse:GetFullName() .. " cannot become pronounced while hacking")
	check(hackerHome:PointToObjectSpace(pulse.Position).Z > 0.20, pulse:GetFullName() .. " is hidden behind the controller")
end

-- Sheldon's dial phone owns the rear-left desk corner. Lock the three solid
-- controller volumes clear of it so buying HackerBot never fuses two props.
local sheldonDialPhone = need(furniture, "SheldonDialPhone", "BasePart", true)
local phoneOnly = OverlapParams.new()
phoneOnly.FilterType = Enum.RaycastFilterType.Include
phoneOnly.FilterDescendantsInstances = { sheldonDialPhone }
for _, partName in ipairs({ "CipherDock", "CipherConsole", "CipherScreen" }) do
	local controllerPart = need(modelsById.HackerBot, partName, "BasePart", true)
	check(
		#workspace:GetPartsInPart(controllerPart, phoneOnly) == 0,
		controllerPart:GetFullName() .. " intersects Sheldon's dial phone"
	)
end

-- World delivery, installation, visibility, and task animation authority ----

for _, marker in ipairs({
	"local runTaskAutomation = serverEvents:WaitForChild(\"RunTaskAutomation\"",
	"local taskAutomationDefinitions = {}",
	"local taskAutomationRobots = {}",
	"local taskAutomationAnchors = {}",
	"kind == \"TaskUpgrade\"",
}) do
	has(worldSource, marker, "Task-world controller is missing base automation contract " .. marker)
end

-- These source markers collectively prove that TaskUpgrade uses the physical
-- truck/carry pipeline, validates owner plus durable snapshot id at every
-- transition, installs only at its matching authored anchor, and consumes the
-- crate only after the server profile accepts the installation.
for _, marker in ipairs({
	"request.kind == \"TaskUpgrade\"",
	"current.delivery.kind == \"TaskUpgrade\"",
	"current.delivery.upgradeId",
	"request.upgradeId",
	"Delivery_TaskUpgrade_",
	"tool:SetAttribute(\"TaskUpgradeId\"",
	"TaskUpgradeDeliverySpawned",
	"TaskUpgradeCratePicked",
	"TaskUpgradeInstalled",
	"TaskUpgradeCarryLost",
	"record.kind == \"TaskUpgrade\"",
	"record.upgradeId",
	"taskAutomationAnchors[",
	"near(player,",
	"clearDeliveryRecord",
}) do
	has(worldSource, marker, "Physical TaskUpgrade lifecycle is missing " .. marker)
end

local worldRequestValidationSource = section(worldSource, "local function requestIsStillValid", "local function spawnDeliveryCrate", "Task-upgrade queue validation")
for _, marker in ipairs({
	"request.kind == \"TaskUpgrade\"",
	"current.delivery.kind == \"TaskUpgrade\"",
	"current.delivery.upgradeId == request.upgradeId",
	"current.delivery.status == \"WaitingDelivery\"",
	"current.delivery.status == \"Collect\"",
	"current.delivery.status == \"Install\"",
}) do
	has(worldRequestValidationSource, marker, "Task-upgrade queue validation is missing " .. marker)
end
local worldSpawnSource = section(worldSource, "local function spawnDeliveryCrate", "runDeliveryQueue = function()", "Physical task-upgrade crate")
for _, marker in ipairs({
	"local isTaskUpgrade = kind == \"TaskUpgrade\"",
	"taskAutomationDefinitions[upgradeId]",
	"\"Delivery_TaskUpgrade_\" .. tostring(player.UserId)",
	"tool:SetAttribute(\"DeliveryKind\", kind)",
	"tool:SetAttribute(\"TaskUpgradeId\"",
	"upgradeId = upgradeId",
	"then \"TaskUpgradeDeliverySpawned\"",
	"then { upgradeId = upgradeId }",
	"report(spawnedEvent, player, spawnedMetadata)",
}) do
	has(worldSpawnSource, marker, "Physical task-upgrade crate is missing " .. marker)
end
local worldEnqueueSource = section(worldSource, "enqueueDelivery = function", "requestDelivery.Event:Connect", "Task-upgrade queue admission")
for _, marker in ipairs({
	"kind ~= \"TaskUpgrade\"",
	"kind == \"TaskUpgrade\" and taskAutomationDefinitions[upgradeId] == nil",
	"upgradeId = if kind == \"TaskUpgrade\" then upgradeId else nil",
	"requestIsStillValid(player, sanitized)",
	"deliveryInFlightKeys[key]",
}) do
	has(worldEnqueueSource, marker, "Task-upgrade queue admission is missing " .. marker)
end

for _, marker in ipairs({
	"runTaskAutomation.Event:Connect",
	"local function migrateAutomationHomeTransforms",
	"local delta = currentHome * savedHome:Inverse()",
	"migrate(instance, \"AutomationHomeCFrame\")",
	"migrate(instance, \"AutomationHomePivot\")",
	"activeTaskAutomation",
	"snapshotOwnsAutomation",
	"setAutomationRobotVisible",
	"refreshAutomationVisibility",
	"restoreAutomationRobot",
	"taskAutomationQueues",
	"AutomationActiveTransparency",
	"AutomationHomeCFrame",
	"InstalledVisible",
	"AutomationRunning",
	"AutomationOwnerUserId",
	"AutomationTaskId",
	"AutomationStartedAt",
	"AutomationCompletesAt",
	"runBeerBot",
	"runDishBot",
		"runTrashBot",
		"runToyFinder",
		"runHackerBot",
}) do
	has(worldSource, marker, "Robot visual activation/animation is missing " .. marker)
end

local automationQueueSource = section(
	worldSource,
	"local function drainTaskAutomationQueue",
	"runTaskAutomation.Event:Connect",
	"Task automation visual queue"
)
for _, marker in ipairs({
	"nextEntry.proofValidated == true",
	"beginTaskAutomation = function(player, upgradeId, metadata, runProofValidated)",
	"if runProofValidated ~= true and not snapshotHasAutomationRun(current, upgradeId, metadata) then",
	"runProofValidated = true",
	"proofValidated = runProofValidated",
	"local visualStartedAt = serverNow()",
	"local visualCompletesAt = visualStartedAt + configuredDuration",
	"local duration = configuredDuration",
	"authoritativeStartedAt = finiteNumber(metadata.startedAt, visualStartedAt)",
	"authoritativeCompletesAt = finiteNumber(metadata.completesAt, visualCompletesAt)",
}) do
	has(
		automationQueueSource,
		marker,
		"Concurrent owners can lose their full paid robot visual while waiting in the shared queue: " .. marker
	)
end
ordered(automationQueueSource, {
	"snapshotHasAutomationRun(current, upgradeId, metadata)",
	"runProofValidated = true",
	"if activeTaskAutomation[upgradeId] then",
	"proofValidated = runProofValidated",
}, "Task robot queue must capture a live server-only run proof before admission")
lacks(
	automationQueueSource,
	"math.max(0, completesAt - serverNow())",
	"Queued robot visuals must not be shortened by the authoritative task wall clock"
)

local worldAutomationSource = section(
	worldSource,
	"-- Installed task-automation setpieces",
	"local function anyPlacedBoomboxOwner",
	"Task robot visuals"
)
for _, marker in ipairs({
	"local function tweenModelPivot",
	"model:PivotTo(current)",
	"local function tweenRobotPivot",
	"local function tweenAutomationParts",
	"local function travelRobotPath",
	"local function reversePositions",
	"local function computeGroundedAutomationPath",
	"local function prepareGroundedAutomationPlans",
	"local function prepareAerialAutomationPlans",
	"GetPartBoundsInBox",
	"RespectCanCollide = true",
	"persistent route obstruction",
	"PathfindingService:CreatePath",
	"local function animateBeerRunnerWheels",
	"local function animateTrashWheels",
	"local function animateToyRotors",
	"local function invokeAutomationDoor",
	"AutomationDoorCommand",
	"local function drainTaskAutomationQueue",
	"while queue and #queue > 0 and activeTaskAutomation[upgradeId] == nil do",
	"table.remove(queue, 1)",
	"local function runBeerBot",
	"fingerHome * CFrame.new(0, -0.10 * math.max(0, math.sin(phase)), 0)",
	"automationTokenActive(token)",
	"local function runDishBot",
	"AutomationCleared",
	"local function runTrashBot",
	"local function runToyFinder",
	"local function runHackerBot",
	"elseif upgradeId == \"HackerBot\" then",
	"runHackerBot(robot, duration, metadata, token)",
	"snapshotOwnsAutomation(current, upgradeId)",
	"local function snapshotHasAutomationRun",
	"automationState.activeRuns",
	"run.runId",
	"metadata.runId",
	"taskAutomationQueues[upgradeId]",
	"proofValidated = runProofValidated",
	"local duration = configuredDuration",
	"cancelled = false",
	"AutomationCancelling",
	"drainTaskAutomationQueue(upgradeId)",
}) do
	has(worldAutomationSource, marker, "Continuous robot visual contract is missing " .. marker)
end
for _, obsoleteMarker in ipairs({
	"phaseRobotTo",
	"AutomationTransferFlash",
	"PhaseTransferActive",
}) do
	lacks(worldAutomationSource, obsoleteMarker, "Robot visuals must never disappear into a phase-transfer artifact: " .. obsoleteMarker)
end

local beerAutomationSource = section(worldAutomationSource, "local function runBeerBot", "local function runDishBot", "Continuous BeerBot workflow")
for _, marker in ipairs({
	"BeerRunner",
	"BeerCaseVisual",
	"RunnerWheelLeft",
	"RunnerWheelRight",
	"animateBeerRunnerWheels",
	"WhiteHotpointRefrigerator",
	"CooperFridgeInterior",
	"travelRobotPath(runner",
	"beerCase:PivotTo",
	"beerCase.Parent = runner",
	"animateRunnerLift",
	"beerCase.Parent = robot",
	"invokeAutomationDoor(fridge, \"AcquireHoldOpen\")",
	"invokeAutomationDoor(fridge, \"ReleaseHoldOpen\"",
	"AcquireHoldOpen",
	"ReleaseHoldOpen",
}) do
	has(beerAutomationSource, marker, "BeerBot must visibly collect, carry, and stock its delivered case: " .. marker)
end
local hackerAutomationSource = section(worldAutomationSource, "local function runHackerBot", "local function runDishBot", "Visible HackerBot workflow")
for _, marker in ipairs({
	"TypingProbeLeft",
	"TypingProbeRight",
	"BreachStatus",
	"CipherDisplay",
	"CipherText",
	"automationPartsWithAttribute(robot, \"AutomationHackerPulse\")",
	"PulseIndex",
	"metadata and metadata.bankCycle",
	"metadata and metadata.bankReward",
	"leftProbe.CFrame = leftHome * CFrame.new(0, -leftTap, 0)",
	"rightProbe.CFrame = rightHome * CFrame.new(0, -rightTap, 0)",
	"pulse.Transparency = index == activeIndex and 0.05 or 0.82",
	"CYCLE %02d",
	"leftProbe.CFrame = leftHome",
	"rightProbe.CFrame = rightHome",
	"pulse.Transparency = 1",
	"cipherText.Text = \"BANK\" .. string.char(10) .. \"READY\"",
}) do
	has(hackerAutomationSource, marker, "HackerBot must visibly type with alternating probes and animated breach pulses: " .. marker)
end
local trashAutomationSource = section(worldAutomationSource, "local function runTrashBot", "local function runToyFinder", "Continuous TrashBot workflow")
for _, marker in ipairs({
	"KitchenGarbageCan",
	"KitchenTrashBag",
	"KitchenTrashBagTie",
	"LiftMast",
	"LiftArm",
	"GrabberLeft",
	"GrabberRight",
	"local outdoorLid",
	"tweenAutomationHinge",
	"animateTrashWheels",
	"WheelLeft",
	"WheelRight",
	"travelRobotPath(robot",
	"OutdoorGarbageCan",
	"setAutomationPartsActive(cargoParts, true)",
	"setAutomationPartsActive(cargoParts, false)",
	"AcquireHoldOpen",
	"ReleaseHoldOpen",
}) do
	has(trashAutomationSource, marker, "TrashBot must visibly extract the real bag, roll outside, open the outdoor lid, and drop it: " .. marker)
end
has(trashAutomationSource, "local patioTransitionReserve = math.min(1.16, duration * 0.1)", "TrashBot does not reserve its two possible patio-door transitions")
has(trashAutomationSource, "math.max(0, duration - patioTransitionReserve) / 1.23", "TrashBot phase weights are not normalized to its authoritative duration")
has(trashAutomationSource, "token.completesAt - serverNow()", "TrashBot does not remain visibly docked through its exact configured deadline")
lacks(trashAutomationSource, "duration * 0.66", "TrashBot still disappears before its authoritative completion deadline")
local toyAutomationSource = section(worldAutomationSource, "local function runToyFinder", "local beginTaskAutomation", "Continuous Toy Finder workflow")
for _, marker in ipairs({
	"metadata.markerName",
	"metadata.plushKind",
	"MissyDetailedTeddyBear",
	"MissyDetailedRabbit",
	":Clone()",
	"DetailedPlushClone",
	"PickupCable",
	"PickupWrist",
	"ClawLeft",
	"ClawRight",
	"tweenAutomationParts(clawTargets",
	"housePointAtHeight",
	"extractionPositions",
	"\"flight\"",
	"animateToyRotors",
	"RotorLeft",
	"RotorRight",
	"travelRobotPath(robot",
	"reversePositions",
	"plushClone.Parent = robot",
	"plushClone.Parent = taskVisuals",
	"plushClone:PivotTo",
	"missyToyHomeCFrame(sourceToy)",
	"Vector3.new(0, 0, 1.8)",
}) do
	has(toyAutomationSource, marker, "Toy Finder must visibly locate, grip, carry, and return the detailed stuffed animal: " .. marker)
end
lacks(toyAutomationSource, "GetAttribute(\"FamilyTaskHomeCFrame\")", "Toy Finder must not consume a stale absolute bed-home attribute")
lacks(toyAutomationSource, "ScanBeam", "Toy Finder must not recreate the obsolete solid scan rod")
lacks(toyAutomationSource, "PlushProxy", "Toy Finder must carry the detailed stuffed animal instead of a placeholder ball")
for _, marker in ipairs({
	"local function automationTokenActive",
	"token.cancelled ~= true",
	"token.cancelled = true",
	"robot:SetAttribute(\"AutomationCancelling\", true)",
}) do
	has(worldSource, marker, "Robot cancellation safety is missing " .. marker)
end
for _, forbiddenAwardMarker in ipairs({ "setAllowance(", "TaskComplete", "report(\"DishesCompleted\"", "report(\"TrashDelivered\"", "report(\"BeerDelivered\"", "report(\"MissyPlushReturned\"" }) do
	lacks(worldAutomationSource, forbiddenAwardMarker, "Robot animation must remain visual-only: " .. forbiddenAwardMarker)
end
lacks(worldAutomationSource, "CooperBeerCount", "BeerBot animation must not stock the refrigerator outside authoritative task completion")
local carryToolSource = section(worldSource, "local function createCarryTool", "local function allocateDeliverySpawnOffset", "Grounded delivery crate creation")
for _, marker in ipairs({
	"driveway.Position.Y + driveway.Size.Y * 0.5",
	"groundY + size.Y * 0.5 + 0.03",
}) do
	has(carryToolSource, marker, "Grounded delivery crate creation is missing " .. marker)
end
lacks(carryToolSource, "dropZone.CFrame * CFrame.new(offset.X, size.Y * 0.5 + 0.12", "Delivery crates must not use the floating guidance marker as their floor")
local crateSlotSource = section(worldSource, "local function allocateDeliverySpawnOffset", "local function ensureCompatibilityTarget", "Curb-safe delivery slots")
has(crateSlotSource, "local baseX = 0", "Delivery crates must remain centered across the driveway")
lacks(crateSlotSource, "baseXByKind", "Delivery crate types must not shift sideways into the curb")
has(worldSource, "local SAFE_DELIVERY_LANES = { 0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6 }", "Delivery allocator is missing its swept-safe lane list")
has(worldSource, "for lane = 7, 18 do", "Delivery allocator must exhaust the safe negative driveway lanes")
has(crateSlotSource, "return nil, nil", "A full driveway must reject unsafe overflow placement")
lacks(crateSlotSource, "41 * slotSpacing", "Delivery allocator must not place overflow crates off-site")
local buyerFairnessSource = section(
	worldSource,
	"runBuyerQueue = function()",
	"candyDeliveryChanged.Event:Connect",
	"Buyer/ordinary delivery fairness"
)
ordered(buyerFairnessSource, {
	"if activeBuyerSession == session then",
	"activeBuyerSession = nil",
	"buyerRouteOccupied = false",
	"workerSession = nil",
	"if #deliveryQueue > 0 then",
	"ordinaryDeliveryTurnReserved = true",
	"if runDeliveryQueue then",
	"runDeliveryQueue()",
	"task.wait(0.5)",
	"buyerQueueRunning = false",
}, "A completed candy-buyer visit must reserve and wake an ordinary delivery before its worker can take another buyer")
ordered(buyerFairnessSource, {
	"buyerQueueRunning = false",
	"not ok and not buyerRouteOccupied and not deliveryRunning and #deliveryQueue > 0",
	"ordinaryDeliveryTurnReserved = true",
	"if not buyerRouteOccupied and runDeliveryQueue then",
	"runDeliveryQueue()",
}, "Candy-buyer failure cleanup must preserve and wake the ordinary-delivery fairness turn")
local queueCapacitySource = section(worldSource, "runDeliveryQueue = function()", "enqueueDelivery = function", "Full-driveway queue backpressure")
for _, marker in ipairs({
	"if not reservedSpawnOffset then",
	"table.insert(deliveryQueue, entry)",
	"local workerOk, workerFailure = xpcall(function()",
	"local itemOk, itemFailure = xpcall(function()",
	"entry.request.reservedSpawnOffset = nil",
	"deliveryInFlightKeys[entry.key] = nil",
	"pcall(setTruckVisible, false)",
	"deliveryRunning = false",
	"Delivery queue recovered safely",
	"buyerQueueRunning or #buyerQueue > 0",
	"local hasReservedOrdinaryTurn",
	"ordinaryDeliveryTurnReserved",
	"and not hasReservedOrdinaryTurn",
	"ordinaryDeliveryTurnReserved = false",
	"task.delay(math.max(0.05, retryDelay)",
}) do
	has(queueCapacitySource, marker, "Failure-safe/fair delivery queue is missing " .. marker)
end
ordered(queueCapacitySource, {
	"local hasReservedOrdinaryTurn = ordinaryDeliveryTurnReserved and #deliveryQueue > 0",
	"and not hasReservedOrdinaryTurn",
	"deliveryRunning = true",
	"ordinaryDeliveryTurnReserved = false",
	"task.spawn(function()",
}, "The reserved ordinary-delivery turn must be claimed atomically before its worker yields")
ordered(queueCapacitySource, {
	"if buyerQueueRunning or #buyerQueue > 0 or entryRequeued then",
	"break",
	"deliveryRunning = false",
	"if buyerQueueRunning or #buyerQueue > 0 then",
	"runBuyerQueue()",
	"elseif #deliveryQueue > 0 then",
}, "An ordinary fairness worker must give the route back after one trip whenever a buyer remains waiting")
local manualBeerStockSource = section(worldSource, 'elseif action == "BeerDrop" then', 'elseif action == "MachineInstall" then', "Manual six-pack stocking")
has(manualBeerStockSource, "math.min(capacity, count + 6)", "Manual Lone Star six-pack does not stock exactly six beers")
lacks(manualBeerStockSource, "count + 12", "Manual Lone Star six-pack still duplicates itself into twelve beers")
local installSource = section(worldSource, "local function tryInstallTaskUpgrade", "local function refreshTaskUpgradeInstallDestinations", "Automatic robot installation")
ordered(installSource, {
	"record.kind ~= \"TaskUpgrade\"",
	"tool:GetAttribute(\"OwnerUserId\") ~= player.UserId",
	"tool:GetAttribute(\"TaskUpgradeId\") ~= upgradeId",
	"not near(player, anchor, 5.5)",
	"current.delivery.kind ~= \"TaskUpgrade\"",
	"current.delivery.status ~= \"Install\"",
	"current.delivery.upgradeId ~= upgradeId",
	"invokeFamily(\"ReportAction\", player, \"TaskUpgradeInstalled\", { upgradeId = upgradeId })",
	"snapshotOwnsAutomation(snapshot(player), upgradeId)",
	"clearCarryPenalty(player, tool)",
	"clearDeliveryRecord(record, false)",
	"tool:Destroy()",
	"setAutomationRobotVisible(upgradeId, true)",
}, "Automatic setup must validate owner/id/proximity/profile before consuming the crate")

local padSource = section(worldSource, "local function refreshTaskUpgradeInstallDestinations", "local taskUpgradeInstallElapsed", "Dynamic setup pads")
for _, marker in ipairs({
	"record.kind == \"TaskUpgrade\" and record.status == \"Carried\"",
	"current.delivery.kind == \"TaskUpgrade\"",
	"current.delivery.status == \"Install\"",
	"current.delivery.upgradeId == record.upgradeId",
	"activeByUpgrade[record.upgradeId] = true",
	"upgradeId .. \"InstallPad\"",
	"pad:GetAttribute(\"VisibleTransparency\")",
	"pad.CanCollide = false",
	"pad.CanQuery = false",
	"prompt.Enabled = false",
}) do
	has(padSource, marker, "Dynamic color-coded setup pad is missing " .. marker)
end
local padHeartbeatSource = section(worldSource, "local taskUpgradeInstallElapsed", "local function insideBoomboxAutoSetupArea", "Automatic setup heartbeat")
ordered(padHeartbeatSource, {
	"RunService.Heartbeat:Connect",
	"refreshTaskUpgradeInstallDestinations()",
	"for _, candidate in ipairs(Players:GetPlayers()) do",
	"tryInstallTaskUpgrade(candidate)",
}, "Setup pads and proximity installation must refresh authoritatively on the server")

-- Runtime-only read-only integration checks --------------------------------

local serverEvents = need(ServerScriptService, Config.ServerEventsName, "Folder")
need(serverEvents, "ReportAction", "BindableEvent")
need(serverEvents, "RequestDelivery", "BindableEvent")
need(serverEvents, "RunTaskAutomation", "BindableEvent")
local familyAPI = need(serverEvents, "API", "BindableFunction")

if running then
	check(taskWorld:GetAttribute("ControllerReady") == true, "Task-world controller did not finish runtime startup")
	check(taskWorld:GetAttribute("TaskAutomationControllerReady") == true, "Task automation controller did not finish runtime startup")
	local snapshot = familyAPI:Invoke("GetSnapshot", nil)
	check(type(snapshot) == "table" and type(snapshot.automation) == "table", "Runtime API has no automation snapshot")
	check(type(snapshot.automation.catalog) == "table" and #snapshot.automation.catalog == 5, "Runtime automation catalog does not expose all five robots")
	check(type(snapshot.automation.activeRuns) == "table", "Runtime automation snapshot has no background-run list")
	check(snapshot.automation.totalCount == 5, "Runtime automation totalCount is not five")
	for index, contract in ipairs(expected) do
		local entry = snapshot.automation.catalog[index]
		check(type(entry) == "table" and entry.id == contract.id, "Runtime catalog order/id changed at " .. index)
		check(entry.taskId == contract.taskId and entry.name == contract.name, contract.id .. " runtime catalog identity is wrong")
		check(entry.price == contract.price and entry.duration == contract.duration, contract.id .. " runtime price/duration is wrong")
		check(entry.installTarget == contract.installTarget and entry.modelName == contract.modelName, contract.id .. " runtime setup contract is wrong")
		check(type(entry.reward) == "number" and entry.reward >= contract.reward, contract.id .. " runtime reward is missing or below its configured base")
		check(type(entry.installed) == "boolean" and type(entry.pending) == "boolean", contract.id .. " runtime ownership state is not explicit")
	end
	for _, player in ipairs(Players:GetPlayers()) do
		check(player:GetAttribute("CooperGameSchemaVersion") == 12, player.Name .. " did not load a schema-12 profile")
		local playerSnapshot = familyAPI:Invoke("GetSnapshot", player)
		check(type(playerSnapshot) == "table" and playerSnapshot.loaded == true, player.Name .. " has no loaded family profile")
		check(type(playerSnapshot.automation) == "table" and #playerSnapshot.automation.catalog == 5, player.Name .. " has an incomplete automation snapshot")
		check(type(playerSnapshot.automation.activeRuns) == "table", player.Name .. " has no authoritative background robot-run list")
		local playerCatalogById = {}
		for _, entry in ipairs(playerSnapshot.automation.catalog) do
			playerCatalogById[entry.id] = entry
		end
		local hackerEntry = playerCatalogById.HackerBot
		check(type(hackerEntry) == "table" and type(hackerEntry.reward) == "number", player.Name .. " has no HackerBot reward quote")
		check(
			type(playerSnapshot.bankHack) == "table" and hackerEntry.reward == playerSnapshot.bankHack.reward,
			player.Name .. " HackerBot shop quote does not use the current scaling bank reward"
		)
		for _, run in ipairs(playerSnapshot.automation.activeRuns) do
			check(type(run) == "table" and type(run.runId) == "string" and #run.runId > 8, player.Name .. " has a robot run without an identity")
			check(ids[run.upgradeId] == true and taskIds[run.taskId] == true, player.Name .. " has a robot run with an unknown upgrade/task")
			check(type(run.startedAt) == "number" and type(run.completesAt) == "number" and run.completesAt > run.startedAt, player.Name .. " has an invalid robot-run window")
		end
		if playerSnapshot.task and playerSnapshot.task.automated == true then
			check(ids[playerSnapshot.task.automationUpgradeId] == true, player.Name .. " has an unknown active task robot")
			check(playerSnapshot.task.guidance == false and playerSnapshot.task.targetHint == nil, player.Name .. " still receives manual guidance during robot work")
			check(type(playerSnapshot.task.automationCompletesAt) == "number", player.Name .. " automated task has no server deadline")
		end
	end
end

-- If this audit is run while a task-upgrade crate exists, validate the live
-- physical artifact as well. Absence is normal when nobody has ordered one.
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Tool") and descendant:GetAttribute("DeliveryKind") == "TaskUpgrade" then
		local upgradeId = descendant:GetAttribute("TaskUpgradeId")
		check(ids[upgradeId] == true, descendant:GetFullName() .. " carries an unknown task-upgrade id")
		check(type(descendant:GetAttribute("DeliveryId")) == "string", descendant:GetFullName() .. " has no delivery identity")
		check(type(descendant:GetAttribute("OwnerUserId")) == "number", descendant:GetFullName() .. " has no owner lock")
		local definition = definitionsById[upgradeId]
		check(definition ~= nil and descendant.Name == definition.name, descendant:GetFullName() .. " exposes an internal delivery id in the Backpack")
		local handle = need(descendant, "Handle", "BasePart")
		check(not handle.CanCollide and handle.Massless, descendant:GetFullName() .. " has unsafe carried-crate physics")
		check(descendant.CanBeDropped == false, descendant:GetFullName() .. " can bypass recovery by being dropped")
	end
end

print(string.format(
	"[TaskAutomationAudit] PASS (%d checks, %s mode): five paid task robots, trusted delivery/install, server-timed rewards, client shop, and visual contracts verified",
	checks,
	running and "runtime" or "edit"
))
