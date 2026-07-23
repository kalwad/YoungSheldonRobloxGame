--!nonstrict
-- Read-only Studio edit/runtime audit for Milestone 0 regressions.
--
-- Run this against either the frozen schema-11/cap-1 rollback or the current
-- schema-12/cap-4 Milestone 1 house. The historical rollback keeps its exact
-- 25-source hashes; the current house must retain those 25 gameplay roles plus
-- the five explicitly approved Milestone 1 sources. This audit never mutates an
-- Instance, profile, DataStore, MemoryStore, or published place.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local failures = {}
local checkCount = 0

local function check(condition, message)
	checkCount += 1
	if not condition then
		table.insert(failures, message)
	end
	return condition
end

local function sourceContains(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local function countPlain(source, marker)
	local count = 0
	local cursor = 1
	while type(source) == "string" do
		local found = string.find(source, marker, cursor, true)
		if not found then
			break
		end
		count += 1
		cursor = found + #marker
	end
	return count
end

-- DJB2 keeps every multiplication below 2^53, so Luau's number type performs
-- this modulo-2^32 checksum exactly. It is a drift detector, not a security
-- primitive; release exports and Git retain the cryptographic rollback hashes.
local function sourceHash(source)
	local hash = 5381
	for index = 1, #source do
		hash = (hash * 33 + string.byte(source, index)) % 4_294_967_296
	end
	return string.format("%08x", hash)
end

local function resolvePath(path)
	local segments = string.split(path, ".")
	local current = nil
	for index, segment in ipairs(segments) do
		if index == 1 then
			local ok, service = pcall(game.GetService, game, segment)
			if not ok then
				return nil
			end
			current = service
		else
			current = current and current:FindFirstChild(segment) or nil
		end
		if not current then
			return nil
		end
	end
	return current
end

local installedConfigModule = resolvePath("ReplicatedStorage.CooperGame.Config")
local installedConfigSource = nil
if installedConfigModule and installedConfigModule:IsA("ModuleScript") then
	local readable, source = pcall(function()
		return installedConfigModule.Source
	end)
	if readable and type(source) == "string" then
		installedConfigSource = source
	end
end
local inspectingMilestone0Rollback =
	sourceContains(installedConfigSource, "Config.SchemaVersion = 11")
local inspectingCurrentMilestone1 =
	sourceContains(installedConfigSource, "Config.SchemaVersion = 12")
check(
	inspectingMilestone0Rollback ~= inspectingCurrentMilestone1,
	"Config must unambiguously identify schema 11 rollback or schema 12 Milestone 1"
)

-- These checksums correspond to the canonical local mirrors after the schema-11
-- Milestone 0 contract was added. Any intentional source edit must update the
-- matching byte count/checksum in a dedicated rollback change. They are not
-- expected to match the forward schema-12 implementation.
local canonicalScripts = {
	{
		path = "Workspace.CooperHouseEnvironment.CooperHouse.ExteriorDetails.InteractiveDenPatioDoor.PatioDoorController",
		className = "Script",
		bytes = 9150,
		hash = "ea6689f2",
		marker = "PatioDoorController",
	},
	{
		path = "Workspace.CooperHouseEnvironment.CooperHouse.ExteriorDetails.InteractiveFrontDoor.FrontDoorController",
		className = "Script",
		bytes = 9034,
		hash = "0db80392",
		marker = "FrontDoorController",
	},
	{
		path = "Workspace.CooperHouseEnvironment.DetachedGarage.InteractiveSectionalGarageDoor.GeorgieGarageDoorController",
		className = "Script",
		bytes = 10787,
		hash = "432d76a6",
		marker = "InteractiveSectionalGarageDoor",
	},
	{
		path = "ServerScriptService.CooperHouseTVAnimator",
		className = "Script",
		bytes = 2660,
		hash = "8a9d38a7",
		marker = "PROF. NEUTRON'S SCIENCE HOUR",
	},
	{
		path = "ServerScriptService.CooperInteractions",
		className = "Script",
		bytes = 80001,
		hash = "d453cc64",
		marker = "Server interaction controller ready",
	},
	{
		path = "ServerScriptService.CooperYardRideables",
		className = "Script",
		bytes = 36643,
		hash = "eab45f7a",
		marker = "Server controller ready",
	},
	{
		path = "ServerScriptService.CooperTaskWorld",
		className = "Script",
		bytes = 197353,
		hash = "a9e6fdf7",
		marker = "Paid house and bunker deliveries",
	},
	{
		path = "ServerScriptService.CooperFamilyNPCs",
		className = "Script",
		bytes = 26213,
		hash = "4651585d",
		marker = "local definitions = {",
	},
	{
		path = "ServerScriptService.CooperFamilyDialogue",
		className = "Script",
		bytes = 4368,
		hash = "4df135e5",
		marker = "Family conversation prompts ready",
	},
	{
		path = "ServerScriptService.CooperGame",
		className = "Script",
		bytes = 149098,
		hash = "1f3980af",
		marker = "Personal, persistent family tasks",
	},
	{
		path = "ServerScriptService.CooperBunker",
		className = "Script",
		bytes = 107972,
		hash = "a0dd3025",
		marker = "Server controller ready v",
	},
	{
		path = "ServerScriptService.CooperSpawnSafety",
		className = "Script",
		bytes = 4297,
		hash = "d6accefa",
		marker = "startup under-map guard",
	},
	{
		path = "ServerScriptService.CooperBunkerConstruction",
		className = "Script",
		bytes = 52132,
		hash = "7c573482",
		marker = "RequestBunkerConstruction",
	},
	{
		path = "ReplicatedStorage.CooperGame.Config",
		className = "ModuleScript",
		bytes = 12318,
		hash = "2a0f330f",
		marker = "Config.SchemaVersion = 11",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperHallCameraController",
		className = "LocalScript",
		bytes = 2600,
		hash = "100c3c04",
		marker = "CooperHallCameraClamp",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperInteractions",
		className = "LocalScript",
		bytes = 37542,
		hash = "19cf9466",
		marker = "Client interaction UI ready",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperYardRideables",
		className = "LocalScript",
		bytes = 14352,
		hash = "1409c2f3",
		marker = "Client controls ready",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperFamilyDialogue",
		className = "LocalScript",
		bytes = 22960,
		hash = "0342c287",
		marker = "Two-stage family dialogue UI ready",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperBackgroundMusic",
		className = "LocalScript",
		bytes = 2885,
		hash = "befe2222",
		marker = "Calm jazz ambience ready",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperGeorgeProximityVoice",
		className = "LocalScript",
		bytes = 2293,
		hash = "c10c159a",
		marker = "HotDamn",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperGeorgieProximityVoice",
		className = "LocalScript",
		bytes = 2325,
		hash = "eafd5767",
		marker = "AnotherDay",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperMaryProximityVoice",
		className = "LocalScript",
		bytes = 2278,
		hash = "4b8464b7",
		marker = "LordHaveMercy",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperMissyProximityVoice",
		className = "LocalScript",
		bytes = 2298,
		hash = "c6a955ce",
		marker = "IncrediblySmart",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperGame",
		className = "LocalScript",
		bytes = 157826,
		hash = "4abfb434",
		marker = "Personal family task HUD",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperBunkerClient",
		className = "LocalScript",
		bytes = 30059,
		hash = "49046983",
		marker = "High-tech research terminal",
	},
}

check(#canonicalScripts == 25, "Canonical script manifest must contain exactly 25 entries")

local milestone1Additions = {
	{
		path = "ReplicatedStorage.CooperGame.TransactionLedger",
		className = "ModuleScript",
		marker = "Ledger.VERSION = 1",
	},
	{
		path = "ReplicatedStorage.CooperPartyProtocol",
		className = "ModuleScript",
		marker = "Protocol.VERSION = 1",
	},
	{
		path = "ReplicatedStorage.CooperUITheme",
		className = "ModuleScript",
		marker = "Theme.VERSION = 1",
	},
	{
		path = "ServerScriptService.CooperMovement",
		className = "Script",
		marker = "Server-authoritative Cooper player movement and sprint stamina.",
	},
	{
		path = "StarterPlayer.StarterPlayerScripts.CooperSprint",
		className = "LocalScript",
		marker = "Shift/gamepad sprint input, 64px mobile toggle, and transient stamina HUD.",
	},
}
check(#milestone1Additions == 5, "Milestone 1 must add exactly five approved house sources")

local publishRoots = {
	Workspace,
	ServerScriptService,
	ServerStorage,
	ReplicatedStorage,
	StarterGui,
	StarterPack,
	StarterPlayer,
}
local actualScripts = {}
local actualScriptCount = 0
for _, root in ipairs(publishRoots) do
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			actualScriptCount += 1
			actualScripts[descendant:GetFullName()] = descendant
		end
	end
end
-- Running Roblox injects PlayerModule, character scripts, and the command
-- bridge into these roots. The exact allowlist therefore belongs to edit mode;
-- runtime still verifies every canonical source below plus live state/NPCs.
if not RunService:IsRunning() then
	local expectedScriptCount = inspectingCurrentMilestone1 and 30 or 25
	check(
		actualScriptCount == expectedScriptCount,
		string.format(
			"Publishable Studio roots must contain exactly %d active/config scripts for this baseline, found %d",
			expectedScriptCount,
			actualScriptCount
		)
	)
end

local expectedPaths = {}
local canonicalSources = {}
for _, specification in ipairs(canonicalScripts) do
	check(not expectedPaths[specification.path], "Duplicate canonical Studio path: " .. specification.path)
	expectedPaths[specification.path] = true

	local instance = resolvePath(specification.path)
	check(instance ~= nil, "Canonical script is missing: " .. specification.path)
	if instance then
		check(instance.ClassName == specification.className, specification.path .. " must be a " .. specification.className)
		if instance:IsA("BaseScript") then
			check(instance.Enabled == true, specification.path .. " is disabled")
		end

		local source = nil
		local readable, result = pcall(function()
			return instance.Source
		end)
		if readable and type(result) == "string" then
			source = result
			canonicalSources[specification.path] = source
			if inspectingMilestone0Rollback then
				check(#source == specification.bytes, string.format(
					"%s source byte count drifted: expected %d, found %d",
					specification.path,
					specification.bytes,
					#source
				))
				check(sourceHash(source) == specification.hash, string.format(
					"%s source checksum drifted: expected %s, found %s",
					specification.path,
					specification.hash,
					sourceHash(source)
				))
				check(sourceContains(source, specification.marker), specification.path .. " lost marker " .. specification.marker)
			else
				check(#source > 100, specification.path .. " is empty or placeholder source")
			end
		else
			check(false, specification.path .. " Source is unreadable; run this audit from a Studio command/plugin context")
		end
	end
end

if inspectingCurrentMilestone1 then
	for _, specification in ipairs(milestone1Additions) do
		check(not expectedPaths[specification.path], "Duplicate Milestone 1 Studio path: " .. specification.path)
		expectedPaths[specification.path] = true
		local instance = resolvePath(specification.path)
		check(instance ~= nil, "Milestone 1 source is missing: " .. specification.path)
		if instance then
			check(instance.ClassName == specification.className, specification.path .. " has the wrong class")
			if instance:IsA("BaseScript") then
				check(instance.Enabled == true, specification.path .. " is disabled")
			end
			local readable, source = pcall(function()
				return instance.Source
			end)
			check(readable and type(source) == "string", specification.path .. " Source is unreadable")
			if readable and type(source) == "string" then
				canonicalSources[specification.path] = source
				check(#source > 100, specification.path .. " is empty or placeholder source")
				check(sourceContains(source, specification.marker), specification.path .. " lost marker " .. specification.marker)
			end
		end
	end
end

if not RunService:IsRunning() then
	for actualPath in pairs(actualScripts) do
		check(expectedPaths[actualPath] == true, "Unexpected publishable script exists outside the canonical manifest: " .. actualPath)
	end
end

-- Core task/config contract -------------------------------------------------

local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
local configModule = gameRoot and gameRoot:FindFirstChild("Config")
local state = gameRoot and gameRoot:FindFirstChild("State")
check(gameRoot and gameRoot:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
check(configModule and configModule:IsA("ModuleScript"), "ReplicatedStorage.CooperGame.Config is missing")
check(state and state:IsA("Folder"), "ReplicatedStorage.CooperGame.State is missing")

local Config = nil
if configModule and configModule:IsA("ModuleScript") then
	-- Edit-mode plugin VMs cache require results even after Source replacement.
	-- Evaluate the already-checksummed source directly when loadstring is exposed,
	-- avoiding both a stale result and the usual temporary clone/reparent mutation.
	local loaded, result
	if not RunService:IsRunning() and type(loadstring) == "function" then
		local compileOk, chunkOrError = pcall(loadstring, configModule.Source, "Milestone0ConfigAudit")
		if compileOk and type(chunkOrError) == "function" then
			loaded, result = pcall(chunkOrError)
		else
			loaded, result = false, chunkOrError
		end
	else
		loaded, result = pcall(require, configModule)
	end
	check(loaded and type(result) == "table", "CooperGame.Config could not be required")
	if loaded and type(result) == "table" then
		Config = result
	end
end

local expectedTaskOrder = {
	"GeorgeBeer",
	"MaryDishes",
	"MaryTrash",
	"MissyPlush",
	"MedfordBankHack",
}

if Config then
	local expectedSchema = inspectingCurrentMilestone1 and 12 or 11
	local expectedPlayerCap = inspectingCurrentMilestone1 and 4 or 1
	check(Config.SchemaVersion == expectedSchema, "Unexpected profile schema for the selected baseline")
	check(Config.DataStoreName == "CooperFamilyTasks_v2", "The established production DataStore must be retained")
	check(Config.ReleasePlayerCap == expectedPlayerCap, "Config.ReleasePlayerCap does not match the selected baseline")
	check(type(Config.Tasks) == "table" and #Config.Tasks == 5, "Config.Tasks must contain exactly five tasks")
	check(type(Config.TaskOrder) == "table" and #Config.TaskOrder == 5, "Config.TaskOrder must contain exactly five tasks")
	for index, taskId in ipairs(expectedTaskOrder) do
		local definition = Config.Tasks and Config.Tasks[index]
		check(type(definition) == "table" and definition.id == taskId, "Task definition order changed at position " .. index)
		check(Config.TaskOrder and Config.TaskOrder[index] == taskId, "TaskOrder changed at position " .. index)
	end
	local plushTask = Config.Tasks and Config.Tasks[4]
	check(
		plushTask and plushTask.startDescription == "One of Missy's stuffed animals is hidden inside the house. Follow the glowing arrow.",
		"Missy's search guidance must be normal player-facing copy"
	)
	check(
		plushTask and not sourceContains(string.lower(plushTask.startDescription or ""), "bathroom")
			and not sourceContains(string.lower(plushTask.startDescription or ""), "temporary")
			and not sourceContains(string.lower(plushTask.startDescription or ""), "development"),
		"Missy's search guidance must not reveal a room or mention development scaffolding"
	)

	check(type(Config.MachineStages) == "table" and #Config.MachineStages == 11, "Config.MachineStages must contain exactly eleven stages")
	local previousProgress = 0
	for stage = 1, 11 do
		local definition = Config.MachineStages and Config.MachineStages[stage]
		check(type(definition) == "table" and definition.stage == stage, "Machine stage " .. stage .. " is missing or out of sequence")
		if type(definition) == "table" then
			check(type(definition.progress) == "number" and definition.progress > previousProgress, "Machine progress must increase at stage " .. stage)
			check(type(definition.cost) == "number" and definition.cost > 0, "Machine stage " .. stage .. " must cost allowance")
			previousProgress = tonumber(definition.progress) or previousProgress
		end
	end
	check(Config.MachineStages and Config.MachineStages[11] and Config.MachineStages[11].progress == 100, "Machine stage 11 must reach 100 percent")

	local expectedFeatures = {
		Lobby = inspectingCurrentMilestone1,
		Horror = false,
		SecretExploration = false,
		TimeMachineFinale = false,
		Postgame = false,
		StudioScenarioTools = false,
	}
	check(type(Config.Features) == "table", "Config.Features is missing")
	local featureCount = 0
	if type(Config.Features) == "table" then
		for featureName, value in pairs(Config.Features) do
			featureCount += 1
			check(expectedFeatures[featureName] ~= nil, "Unexpected future feature flag: " .. tostring(featureName))
			check(value == expectedFeatures[featureName], "Incorrect baseline feature flag: " .. tostring(featureName))
		end
	end
	check(featureCount == 6, "Config.Features must contain exactly six flags")
	for featureName, expectedValue in pairs(expectedFeatures) do
		check(Config.Features and Config.Features[featureName] == expectedValue, "Missing or incorrect feature flag: " .. featureName)
	end
	if inspectingCurrentMilestone1 then
		check(table.isfrozen(Config.Features), "Milestone 1 Config.Features must be frozen")
		check(type(Config.Party) == "table" and table.isfrozen(Config.Party), "Milestone 1 Config.Party must be frozen")
		check(Config.Party and Config.Party.MaxMembers == 4, "Milestone 1 party size must be four")
		check(Config.Party and Config.Party.HostOnlyPersistentPurchases == true, "Milestone 1 purchases must remain host-only")
	end

	local defaults = Config.ProfileDefaults
	check(type(defaults) == "table", "Config.ProfileDefaults is missing")
	if type(defaults) == "table" then
		local expectedFutureDefaults = {
			schemaVersion = expectedSchema,
			cycleIndex = 1,
			cycleTaskIndex = 1,
			postRevealCyclesCompleted = 0,
			firstHorrorRevealed = false,
			horrorEncountersSurvived = 0,
			horrorEncountersCaught = 0,
			horrorCurrentStreak = 0,
			horrorLongestStreak = 0,
			backroomsDiscovered = false,
			domeDiscovered = false,
			endingCompleted = false,
			endingChoice = "",
			postgameUnlocked = false,
		}
		for fieldName, expectedValue in pairs(expectedFutureDefaults) do
			check(defaults[fieldName] == expectedValue, string.format(
				"ProfileDefaults.%s must be %s, found %s",
				fieldName,
				tostring(expectedValue),
				tostring(defaults[fieldName])
			))
		end
		check(defaults.allowance == 0 and defaults.machineStage == 0 and defaults.pendingPartStage == 0, "Baseline granted core progression to a fresh profile")
		check(defaults.boomboxPurchased == false and defaults.boomboxAutoplayPurchased == false, "Baseline granted a fresh boombox entitlement")
		check(type(defaults.taskAutomationInstalled) == "table" and next(defaults.taskAutomationInstalled) == nil, "Baseline granted task automation to a fresh profile")
		check(defaults.secretBunkerPurchased == false and defaults.chemistrySetupPurchased == false, "Baseline granted bunker progression to a fresh profile")
		if inspectingCurrentMilestone1 then
			local journal = defaults.operationJournal
			check(type(journal) == "table" and journal.version == 1, "Schema 12 operation journal is missing")
			check(journal and type(journal.pending) == "table" and next(journal.pending) == nil, "Fresh schema 12 profile has pending operations")
			check(journal and type(journal.committed) == "table" and next(journal.committed) == nil, "Fresh schema 12 profile has committed operations")
		end
	end

	check(Config.Mode == nil and Config.Stability == nil and Config.Chapters == nil, "Retired panic/crisis campaign fields returned to CooperGame.Config")
end

local gameClientSource = canonicalSources["StarterPlayer.StarterPlayerScripts.CooperGame"]
if type(gameClientSource) == "string" then
	for _, marker in ipairs({
		'treeFile("", true, "Credits", function()',
		'showPage("Credits")',
		'terminalTitle.Text = "COOPER TERMINAL // CREDITS"',
		'terminalTreeHeader.Text = "PHOTO ATTRIBUTIONS"',
		'Unofficial parody; not endorsed by the actors, CBS, or the rights holders.',
		'function upgradeNoticeUi.creditCard(text)',
		'terminalBack.Activated:Connect(function()',
		'terminalClose.Activated:Connect(function()',
		'input.KeyCode == Enum.KeyCode.ButtonB',
		'input.KeyCode == Enum.KeyCode.Escape',
	}) do
		check(sourceContains(gameClientSource, marker), "Credits accessibility marker is missing: " .. marker)
	end
	check(
		countPlain(gameClientSource, 'upgradeNoticeUi.creditCard("') == 6,
		"Credits must contain exactly six selectable attribution cards"
	)
end

local televisionSource = canonicalSources["ServerScriptService.CooperHouseTVAnimator"]
if type(televisionSource) == "string" then
	check(not sourceContains(televisionSource, "PANIC LEVEL"), "The active television still advertises a retired panic level")
	check(not sourceContains(televisionSource, "MEDFORD EMERGENCY BROADCAST"), "The active television still presents retired crisis copy")
end

-- Creator Dashboard owns the published Maximum Visitor Count. An already-open
-- Studio edit DataModel keeps its old read-only MaxPlayers cache, so Studio
-- verifies the frozen config contract while live play must match the engine
-- value exactly.
local expectedReleaseCap = inspectingCurrentMilestone1 and 4 or 1
local releaseCapacityMatches = Players.MaxPlayers == expectedReleaseCap
	or (RunService:IsStudio() and Config and Config.ReleasePlayerCap == expectedReleaseCap)
check(
	releaseCapacityMatches,
	string.format(
		"Release capacity must be %d for this baseline; current MaxPlayers is %s",
		expectedReleaseCap,
		tostring(Players.MaxPlayers)
	)
)

local gameServer = ServerScriptService:FindFirstChild("CooperGame")
check(gameServer and gameServer:IsA("Script"), "ServerScriptService.CooperGame is missing")
check(not gameServer or gameServer:GetAttribute("EnableStudioDataStore") ~= true, "EnableStudioDataStore must not be enabled for baseline verification")

-- Migration, task-cycle, and feature-state source contracts ----------------

local gameServerSource = canonicalSources["ServerScriptService.CooperGame"]
if type(gameServerSource) == "string" then
	for _, marker in ipairs({
		"local totalTasks = finiteInteger(raw.totalTasks, 0, 0, 10_000_000)",
		"local cycleIndex = math.floor(totalTasks / #Config.TaskOrder) + 1",
		"local cycleTaskIndex = (totalTasks % #Config.TaskOrder) + 1",
		"postRevealCyclesCompleted = finiteInteger(raw.postRevealCyclesCompleted, 0, 0, 10_000_000)",
		"firstHorrorRevealed = raw.firstHorrorRevealed == true",
		"horrorEncountersSurvived = finiteInteger(raw.horrorEncountersSurvived, 0, 0, 10_000_000)",
		"horrorEncountersCaught = finiteInteger(raw.horrorEncountersCaught, 0, 0, 10_000_000)",
		"horrorCurrentStreak = finiteInteger(raw.horrorCurrentStreak, 0, 0, 10_000_000)",
		"horrorLongestStreak = finiteInteger(raw.horrorLongestStreak, 0, 0, 10_000_000)",
		"backroomsDiscovered = raw.backroomsDiscovered == true",
		"domeDiscovered = raw.domeDiscovered == true",
		"endingCompleted = raw.endingCompleted == true",
		"postgameUnlocked = raw.postgameUnlocked == true",
		"state:SetAttribute(\"SchemaVersion\", Config.SchemaVersion)",
		"state:SetAttribute(\"ReleasePlayerCap\", Config.ReleasePlayerCap)",
		"player:SetAttribute(\"CooperGameSchemaVersion\", Config.SchemaVersion)",
	}) do
		check(sourceContains(gameServerSource, marker), "Schema migration/task-cycle source marker is missing: " .. marker)
	end

	if inspectingMilestone0Rollback then
		local incrementAt = string.find(gameServerSource, "profile.data.totalTasks += 1", 1, true)
		local cycleAt = string.find(
			gameServerSource,
			"profile.data.cycleIndex = math.floor(profile.data.totalTasks / #Config.TaskOrder) + 1",
			1,
			true
		)
		local taskIndexAt = string.find(
			gameServerSource,
			"profile.data.cycleTaskIndex = (profile.data.totalTasks % #Config.TaskOrder) + 1",
			1,
			true
		)
		local clearTaskAt = string.find(gameServerSource, "profile.task = nil", incrementAt or 1, true)
		check(
			incrementAt and cycleAt and taskIndexAt and clearTaskAt
				and incrementAt < cycleAt and cycleAt < taskIndexAt and taskIndexAt < clearTaskAt,
			"Rollback task completion must update cycle fields before clearing its solo task"
		)
	else
		for _, marker in ipairs({
			"M1_SHARED_TASK_SESSION_CONTRACT",
			"M1_TASK_ELIGIBILITY_CONTRACT",
			"local function captureTaskEligibility(version)",
			"local eligibility = captureTaskEligibility(profile.data.totalTasks + 1)",
			"eligibleUserIds = table.clone(eligibility.userIds)",
			"TransactionRuntime.commitCalmTaskStart(profile, false)",
			"CALM_TASK_START_EXPOSURE_AFTER_DURABLE_SAVE",
			"local nextCursor = ((checkpoint.hostOrdinal - 1) % #Config.TaskOrder) + 1",
			"partySession.taskCursor = nextCursor",
			"partySession.taskCursor = profile.data.totalTasks % #Config.TaskOrder",
			"eligibility = TransactionRuntime.eligibilityFromCheckpoint(checkpoint)",
			"record.status = \"Completing\"",
			"local operationKind = \"TaskReward:\" .. tostring(record.logicalId)",
			"TransactionRuntime.commitProfileValueOperation(",
			"setAllowance(recipient, recipient.data.allowance + reward)",
			"recipient.data.totalTasks += 1",
			"recipient.data.cycleIndex = math.floor(recipient.data.totalTasks / #Config.TaskOrder) + 1",
			"recipient.data.cycleTaskIndex = (recipient.data.totalTasks % #Config.TaskOrder) + 1",
			"recipient.data.calmTaskCheckpoint = nil",
			"record.status = \"Completed\"",
			"partySession.completedTasks += 1",
			"partySession.task = nil",
		}) do
			check(sourceContains(gameServerSource, marker), "Milestone 1 shared-task marker is missing: " .. marker)
		end
		for _, forbiddenPersonalScheduler in ipairs({
			"profile.taskCursor",
			"profile.nextTaskAt",
			"local record = profile.task",
			"local activeTask = profile.task",
			"not profile.task and",
			"profile.task ~= bankSession.record",
		}) do
			check(
				not sourceContains(gameServerSource, forbiddenPersonalScheduler),
				"Milestone 1 restored profile-local task state: " .. forbiddenPersonalScheduler
			)
		end
		local exposureStartAt = string.find(
			gameServerSource,
			"function TransactionRuntime.exposeCalmTaskCheckpoint(profile, checkpoint, recovered)",
			1,
			true
		)
		local exposureEndAt = exposureStartAt and string.find(
			gameServerSource,
			"function TransactionRuntime.commitCalmTaskStart(profile, recovered)",
			exposureStartAt,
			true
		) or nil
		local checkpointCursorAt = exposureStartAt and string.find(
			gameServerSource,
			"local nextCursor = ((checkpoint.hostOrdinal - 1) % #Config.TaskOrder) + 1",
			exposureStartAt,
			true
		) or nil
		local durableExposureAt = exposureStartAt and string.find(
			gameServerSource,
			"-- CALM_TASK_START_EXPOSURE_AFTER_DURABLE_SAVE",
			exposureStartAt,
			true
		) or nil
		local sharedCursorAt = durableExposureAt and string.find(
			gameServerSource,
			"partySession.taskCursor = nextCursor",
			durableExposureAt,
			true
		) or nil
		check(
			exposureStartAt and exposureEndAt and checkpointCursorAt and durableExposureAt and sharedCursorAt
				and checkpointCursorAt < durableExposureAt
				and durableExposureAt < sharedCursorAt
				and sharedCursorAt < exposureEndAt,
			"PartyV1 must derive and expose the shared task cursor from the durable host ordinal only after checkpoint save"
		)
		local completingAt = string.find(gameServerSource, "record.status = \"Completing\"", 1, true)
		local valueCommitAt = string.find(
			gameServerSource,
			"TransactionRuntime.commitProfileValueOperation(",
			completingAt or 1,
			true
		)
		local allowanceAt = string.find(
			gameServerSource,
			"setAllowance(recipient, recipient.data.allowance + reward)",
			valueCommitAt or 1,
			true
		)
		local recipientIncrementAt = string.find(
			gameServerSource,
			"recipient.data.totalTasks += 1",
			allowanceAt or 1,
			true
		)
		local recipientCycleAt = string.find(
			gameServerSource,
			"recipient.data.cycleIndex = math.floor(recipient.data.totalTasks / #Config.TaskOrder) + 1",
			recipientIncrementAt or 1,
			true
		)
		local recipientTaskIndexAt = string.find(
			gameServerSource,
			"recipient.data.cycleTaskIndex = (recipient.data.totalTasks % #Config.TaskOrder) + 1",
			recipientCycleAt or 1,
			true
		)
		local checkpointClearAt = string.find(
			gameServerSource,
			"recipient.data.calmTaskCheckpoint = nil",
			recipientTaskIndexAt or 1,
			true
		)
		local completedAt = string.find(gameServerSource, "record.status = \"Completed\"", valueCommitAt or 1, true)
		local sharedAdvanceAt = string.find(gameServerSource, "partySession.completedTasks += 1", completedAt or 1, true)
		local sharedCloseAt = string.find(gameServerSource, "partySession.task = nil", sharedAdvanceAt or 1, true)
		check(
			completingAt and valueCommitAt and allowanceAt and recipientIncrementAt
				and recipientCycleAt and recipientTaskIndexAt and checkpointClearAt
				and completedAt and sharedAdvanceAt and sharedCloseAt
				and completingAt < valueCommitAt
				and valueCommitAt < allowanceAt
				and allowanceAt < recipientIncrementAt
				and recipientIncrementAt < recipientCycleAt
				and recipientCycleAt < recipientTaskIndexAt
				and recipientTaskIndexAt < checkpointClearAt
				and checkpointClearAt < completedAt
				and completedAt < sharedAdvanceAt
				and sharedAdvanceAt < sharedCloseAt,
			"Shared task completion must claim, journal each recipient's reward and cycle progress, clear the host checkpoint, finalize, advance once, then close"
		)
	end

	local stateFeatureMarkers = {
		FeatureLobbyEnabled = "Lobby",
		FeatureHorrorEnabled = "Horror",
		FeatureSecretExplorationEnabled = "SecretExploration",
		FeatureTimeMachineFinaleEnabled = "TimeMachineFinale",
		FeaturePostgameEnabled = "Postgame",
		FeatureStudioScenarioToolsEnabled = "StudioScenarioTools",
	}
	for attributeName, featureName in pairs(stateFeatureMarkers) do
		local marker = string.format(
			"state:SetAttribute(\"%s\", Config.Features.%s == true)",
			attributeName,
			featureName
		)
		check(sourceContains(gameServerSource, marker), "State feature marker is missing: " .. marker)
		check(countPlain(gameServerSource, marker) == 1, "State feature marker must occur exactly once: " .. attributeName)
	end

	-- Execute the production sanitizer in isolation against a representative
	-- schema-10 save. This is stronger than checking field-name strings: an
	-- accidental default, clamp, rename, or entitlement loss fails the baseline
	-- before Studio synchronization. No DataStore key is read or written.
	if not RunService:IsRunning() and Config and configModule and type(loadstring) == "function" then
		local sanitizerStart = string.find(gameServerSource, "local function finiteInteger", 1, true)
		local sanitizerEnd = sanitizerStart
			and string.find(gameServerSource, "\nlocal function profileKey", sanitizerStart, true)
			or nil
		check(sanitizerStart ~= nil and sanitizerEnd ~= nil, "Could not isolate the production profile sanitizer")
		if sanitizerStart and sanitizerEnd then
			local sanitizerSource = string.sub(gameServerSource, sanitizerStart, sanitizerEnd - 1)
			local harnessSource = "local HttpService = game:GetService(\"HttpService\")\n"
				.. "local PROFILE_LEASE_FIELD = \"_sessionLease\"\n"
				.. "local Config = (function()\n" .. configModule.Source .. "\nend)()\n"
				.. (inspectingCurrentMilestone1
					and ("local TransactionLedger = (function()\n"
						.. tostring(
							canonicalSources["ReplicatedStorage.CooperGame.TransactionLedger"]
								or "error(\"TransactionLedger source unavailable\")"
						)
						.. "\nend)()\n")
					or "")
				.. "local automationById = {}\n"
				.. "for _, definition in ipairs(Config.TaskAutomationUpgrades) do automationById[definition.id] = definition end\n"
				.. sanitizerSource
				.. "\nreturn sanitizeData\n"
			local compiled, chunkOrError = pcall(loadstring, harnessSource, "Milestone0MigrationHarness")
			check(compiled and type(chunkOrError) == "function", "Schema-10 migration harness did not compile: " .. tostring(chunkOrError))
			if compiled and type(chunkOrError) == "function" then
				local loaded, sanitizerOrError = pcall(chunkOrError)
				check(loaded and type(sanitizerOrError) == "function", "Schema-10 migration harness did not load: " .. tostring(sanitizerOrError))
				if loaded and type(sanitizerOrError) == "function" then
					local legacy = {
						schemaVersion = 10,
						allowance = 123456,
						machineStage = 7,
						pendingPartStage = 8,
						tutorialSeen = true,
						totalTasks = 17,
						boomboxPurchased = true,
						boomboxPlaced = true,
						boomboxNextPlayAt = 2_000_000_000,
						boomboxAutoplayPurchased = true,
						taskAutomationInstalled = {
							BeerBot = true,
							DishBot = true,
							TrashBot = true,
							ToyFinder = true,
							HackerBot = true,
						},
						pendingTaskUpgradeId = "",
						bankHackSuccesses = 23,
						secretBunkerPurchased = true,
						secretBunkerReadyAt = 2_000_000_100,
						chemistrySetupPurchased = true,
						chemistrySetupPlaced = true,
						candyBatchReady = false,
						candyBatchToken = "",
						candyDeliveryActive = true,
						candyDeliveryToken = "delivery-token-schema10",
						candyBatchesSold = 9,
					}
					local migratedOk, migrated, rewrite = pcall(sanitizerOrError, legacy)
					check(migratedOk and type(migrated) == "table", "Schema-10 profile migration raised an error: " .. tostring(migrated))
					if migratedOk and type(migrated) == "table" then
						local expectedSchema = inspectingCurrentMilestone1 and 12 or 11
						check(rewrite == true, "Schema-10 profile was not marked for a canonical rewrite")
						check(migrated.schemaVersion == expectedSchema, "Schema-10 profile did not migrate to the selected baseline")
						for _, fieldName in ipairs({
							"allowance",
							"machineStage",
							"pendingPartStage",
							"tutorialSeen",
							"totalTasks",
							"boomboxPurchased",
							"boomboxPlaced",
							"boomboxNextPlayAt",
							"boomboxAutoplayPurchased",
							"bankHackSuccesses",
							"secretBunkerPurchased",
							"secretBunkerReadyAt",
							"chemistrySetupPurchased",
							"chemistrySetupPlaced",
							"candyDeliveryActive",
							"candyDeliveryToken",
							"candyBatchesSold",
						}) do
							check(migrated[fieldName] == legacy[fieldName], "Schema-10 migration changed legacy field " .. fieldName)
						end
						for robotId in pairs(legacy.taskAutomationInstalled) do
							check(migrated.taskAutomationInstalled[robotId] == true, "Schema-10 migration lost robot entitlement " .. robotId)
						end
						check(migrated.cycleIndex == 4 and migrated.cycleTaskIndex == 3, "Cycle state was not derived canonically from totalTasks=17")
						check(migrated.firstHorrorRevealed == false and migrated.postRevealCyclesCompleted == 0, "Migration granted horror progress")
						check(migrated.backroomsDiscovered == false and migrated.domeDiscovered == false, "Migration granted secret discoveries")
						check(migrated.endingCompleted == false and migrated.endingChoice == "" and migrated.postgameUnlocked == false, "Migration granted ending/postgame progress")
						if inspectingCurrentMilestone1 then
							check(
								type(migrated.operationJournal) == "table"
									and migrated.operationJournal.version == 1
									and #migrated.operationJournal.pending == 0
									and #migrated.operationJournal.committed == 0,
								"Schema-10 migration did not initialize an empty schema-12 operation journal"
							)
						end
						local rejoinOk, rejoined, rejoinRewrite = pcall(sanitizerOrError, migrated)
						check(rejoinOk and type(rejoined) == "table", "Migrated profile did not survive an in-memory leave/rejoin round trip")
						if rejoinOk and type(rejoined) == "table" then
							check(rejoinRewrite == false, "Canonical profile requested another rewrite after rejoin")
							for _, fieldName in ipairs({
								"allowance",
								"machineStage",
								"pendingPartStage",
								"boomboxPurchased",
								"boomboxPlaced",
								"boomboxAutoplayPurchased",
								"secretBunkerPurchased",
								"secretBunkerReadyAt",
								"chemistrySetupPurchased",
								"chemistrySetupPlaced",
								"candyDeliveryActive",
								"candyDeliveryToken",
							}) do
								check(rejoined[fieldName] == migrated[fieldName], "Leave/rejoin round trip changed " .. fieldName)
							end
						end
					end

					local pendingOk, pending = pcall(sanitizerOrError, {
						schemaVersion = 10,
						taskAutomationInstalled = { BeerBot = true },
						pendingTaskUpgradeId = "DishBot",
					})
					check(pendingOk and pending.pendingTaskUpgradeId == "DishBot", "Migration lost a paid pending robot delivery")
					if pendingOk then
						local pendingRejoinOk, pendingRejoin = pcall(sanitizerOrError, pending)
						check(pendingRejoinOk and pendingRejoin.pendingTaskUpgradeId == "DishBot", "Leave/rejoin round trip lost a paid pending robot delivery")
					end
					local readyOk, ready = pcall(sanitizerOrError, {
						schemaVersion = 10,
						chemistrySetupPlaced = true,
						candyBatchReady = true,
						candyBatchToken = "ready-batch-token-schema10",
					})
					check(readyOk and ready.candyBatchReady == true and ready.candyBatchToken == "ready-batch-token-schema10", "Migration lost a completed chemistry batch")
					if readyOk then
						local readyRejoinOk, readyRejoin = pcall(sanitizerOrError, ready)
						check(readyRejoinOk and readyRejoin.candyBatchReady == true and readyRejoin.candyBatchToken == "ready-batch-token-schema10", "Leave/rejoin round trip lost a completed chemistry batch")
					end

					local paidQueueOk, paidQueue = pcall(sanitizerOrError, {
						schemaVersion = 10,
						pendingPartStage = 5,
						boomboxPurchased = true,
						boomboxPlaced = false,
						secretBunkerPurchased = true,
						secretBunkerReadyAt = 2_000_000_200,
						chemistrySetupPurchased = true,
						chemistrySetupPlaced = false,
					})
					check(paidQueueOk and type(paidQueue) == "table", "Paid-delivery migration fixture failed")
					if paidQueueOk and type(paidQueue) == "table" then
						local paidRejoinOk, paidRejoin = pcall(sanitizerOrError, paidQueue)
						check(
							paidRejoinOk
								and paidRejoin.pendingPartStage == 5
								and paidRejoin.boomboxPurchased == true
								and paidRejoin.boomboxPlaced == false
								and paidRejoin.secretBunkerPurchased == true
								and paidRejoin.secretBunkerReadyAt == 2_000_000_200
								and paidRejoin.chemistrySetupPurchased == true
								and paidRejoin.chemistrySetupPlaced == false,
							"Leave/rejoin round trip lost a pending machine, boombox, bunker, or chemistry delivery"
						)
					end
				end
			end
		end
	elseif not RunService:IsRunning() then
		check(false, "Schema-10 migration execution requires Studio loadstring support")
	end
end

if state and state:IsA("Folder") then
	if RunService:IsRunning() then
		local advertisedSchema = state:GetAttribute("SchemaVersion")
		local expectedSchema = inspectingCurrentMilestone1 and 12 or 11
		local expectedCap = inspectingCurrentMilestone1 and 4 or 1
		check(advertisedSchema == expectedSchema, "CooperGame.State advertises the wrong schema after startup")
		local advertisedPlayerCap = state:GetAttribute("ReleasePlayerCap")
		check(advertisedPlayerCap == expectedCap, "CooperGame.State advertises the wrong release cap")
		local expectedRuntimeFeatures = {
			FeatureLobbyEnabled = inspectingCurrentMilestone1,
			FeatureHorrorEnabled = false,
			FeatureSecretExplorationEnabled = false,
			FeatureTimeMachineFinaleEnabled = false,
			FeaturePostgameEnabled = false,
			FeatureStudioScenarioToolsEnabled = false,
		}
		for attributeName, expectedValue in pairs(expectedRuntimeFeatures) do
			local value = state:GetAttribute(attributeName)
			check(value == expectedValue, attributeName .. " has the wrong baseline value")
		end
		check(
			state:GetAttribute("FoundationContract")
				== (inspectingCurrentMilestone1 and "PartyV1" or "PersonalV4"),
			"CooperGame.State advertises the wrong foundation contract"
		)
	end
	for _, retiredAttribute in ipairs({
		"Mode",
		"Stability",
		"StabilityBand",
		"Chapter",
		"ChapterName",
		"PanicActive",
		"CrisisActive",
		"FinaleActive",
	}) do
		check(state:GetAttribute(retiredAttribute) == nil, "Retired shared-state attribute remains: " .. retiredAttribute)
	end
end

-- Exactly four approved normal PNG cutout NPCs -----------------------------

local approvedNPCs = {
	George = 114737318979057,
	Mary = 109845379583984,
	Missy = 105870837764920,
	Georgie = 137011952735257,
}
local approvedNPCOrder = { "George", "Mary", "Missy", "Georgie" }
local function assetId(value)
	return tonumber(string.match(tostring(value or ""), "(%d+)$")) or 0
end

local imageFolder = ReplicatedStorage:FindFirstChild("CooperFamilyLocalImages")
check(imageFolder and imageFolder:IsA("Folder"), "CooperFamilyLocalImages is missing")
if imageFolder and imageFolder:IsA("Folder") then
	local imageCount = 0
	for _, child in ipairs(imageFolder:GetChildren()) do
		imageCount += 1
		check(child:IsA("StringValue"), "Unexpected non-StringValue in CooperFamilyLocalImages: " .. child.Name)
		check(approvedNPCs[child.Name] ~= nil, "Unapproved family image exists: " .. child.Name)
	end
	check(imageCount == 4, "CooperFamilyLocalImages must contain exactly four approved entries")
	for characterName, expectedImageId in pairs(approvedNPCs) do
		local value = imageFolder:FindFirstChild(characterName)
		check(value and value:IsA("StringValue"), characterName .. " image value is missing")
		check(value and assetId(value.Value) == expectedImageId, characterName .. " image asset changed")
	end
end

local npcServerSource = canonicalSources["ServerScriptService.CooperFamilyNPCs"]
if type(npcServerSource) == "string" then
	local definitionsAt = string.find(npcServerSource, "local definitions = {", 1, true)
	local definitionsEnd = definitionsAt and string.find(npcServerSource, "local randomizer = Random.new()", definitionsAt, true) or nil
	check(definitionsAt ~= nil and definitionsEnd ~= nil, "NPC definition table boundaries are missing")
	if definitionsAt and definitionsEnd then
		local section = string.sub(npcServerSource, definitionsAt, definitionsEnd - 1)
		local foundNames = {}
		for name in string.gmatch(section, "name%s*=%s*\"([^\"]+)\"") do
			table.insert(foundNames, name)
		end
		check(#foundNames == 4, "CooperFamilyNPCs must define exactly four NPCs")
		for index, expectedName in ipairs(approvedNPCOrder) do
			check(foundNames[index] == expectedName, "NPC definition order changed at position " .. index)
		end
	end
	for _, marker in ipairs({
		"world:SetAttribute(\"SimpleFourCharacterSystem\", true)",
		"world:SetAttribute(\"PanicEnabled\", false)",
		"world:SetAttribute(\"CharacterCount\", 4)",
		"model:SetAttribute(\"Cooper2DCharacter\", true)",
		"local billboard = Instance.new(\"BillboardGui\")",
		"local image = Instance.new(\"ImageLabel\")",
		"image.Image = imageFor(definition.name)",
		"image.ScaleType = Enum.ScaleType.Fit",
	}) do
		check(sourceContains(npcServerSource, marker), "Normal cutout NPC source marker is missing: " .. marker)
	end
end

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
check(environment and environment:IsA("Model"), "CooperHouseEnvironment is missing")
local runtimeNPCWorld = environment and environment:FindFirstChild("CooperFamilyNPCs")
if RunService:IsRunning() and not runtimeNPCWorld then
	local deadline = os.clock() + 12
	while not runtimeNPCWorld and os.clock() < deadline do
		task.wait(0.1)
		runtimeNPCWorld = environment and environment:FindFirstChild("CooperFamilyNPCs")
	end
end
if RunService:IsRunning() then
	check(runtimeNPCWorld and runtimeNPCWorld:IsA("Folder"), "Runtime CooperFamilyNPCs world did not start")
end
if runtimeNPCWorld and runtimeNPCWorld:IsA("Folder") then
	check(runtimeNPCWorld:GetAttribute("PanicEnabled") == false, "Runtime family NPC world enabled Panic")
	check(runtimeNPCWorld:GetAttribute("CharacterCount") == 4, "Runtime family NPC CharacterCount is not four")
	local modelCount = 0
	for _, child in ipairs(runtimeNPCWorld:GetChildren()) do
		if child:IsA("Model") then
			modelCount += 1
			check(approvedNPCs[child.Name] ~= nil, "Unapproved runtime NPC exists: " .. child.Name)
		end
	end
	check(modelCount == 4, "Runtime NPC world must contain exactly four models")
	for characterName, expectedImageId in pairs(approvedNPCs) do
		local model = runtimeNPCWorld:FindFirstChild(characterName)
		local rootPart = model and model:FindFirstChild("Root")
		local cutout = rootPart and rootPart:FindFirstChild("Cutout")
		local image = cutout and cutout:FindFirstChild("CharacterImage")
		check(model and model:IsA("Model"), characterName .. " runtime NPC is missing")
		check(model and model:GetAttribute("Cooper2DCharacter") == true, characterName .. " is not marked as a 2D character")
		check(cutout and cutout:IsA("BillboardGui"), characterName .. " cutout BillboardGui is missing")
		check(image and image:IsA("ImageLabel"), characterName .. " CharacterImage is missing")
		check(image and assetId(image.Image) == expectedImageId, characterName .. " runtime image asset changed")
		check(not (model and model:FindFirstChildWhichIsA("TextLabel", true)), characterName .. " has a forbidden card/nameplate text label")
	end
end

-- Retired panic/crisis/progression systems and staging must remain absent ----

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
for _, specification in ipairs({
	{ ReplicatedStorage, "CooperProgression" },
	{ ServerScriptService, "CooperProgression" },
	{ ServerScriptService, "CooperProgressionServerEvents" },
	{ starterScripts, "CooperProgression" },
	{ ReplicatedStorage, "CooperCrisis" },
	{ ServerScriptService, "CooperCrisis" },
	{ ServerScriptService, "CooperCrisisServerEvents" },
	{ starterScripts, "CooperCrisisClient" },
	{ ReplicatedStorage, "CooperCharacters" },
	{ ServerScriptService, "CooperCharacters" },
	{ ServerScriptService, "CooperCharacterServerEvents" },
	{ starterScripts, "CooperCharacters" },
	{ environment, "CooperCrisisWorld" },
	{ environment, "CooperCharacters" },
	{ environment, "CooperTaskWorld" },
	{ Workspace, "CooperFutureApartment" },
	{ StarterGui, "CooperProgressionHUD" },
	{ StarterGui, "CooperCrisisHUD" },
	{ StarterGui, "CooperCharactersHUD" },
	{ Lighting, "CooperCharacterPanicColor" },
	{ SoundService, "TornadoWind" },
	{ SoundService, "CrisisAlert" },
	{ SoundService, "ChaosStinger" },
	{ SoundService, "PanicWarningAudio" },
}) do
	local parent, name = specification[1], specification[2]
	check(not parent or parent:FindFirstChild(name) == nil, "Retired runtime object remains: " .. name)
end

local stagingPrefixes = {
	"_CooperProgression",
	"_CooperCrisisStage_",
	"_CooperCrisisServerStage_",
	"_CooperCrisisClientStage_",
	"_CooperCrisisWorldStage_",
	"__CooperFutureApartment_Staging",
	"__CooperTimeMachine_Staging",
	"CooperGame_Installing",
	"CooperGame_PreviousInstall",
	"CooperTaskWorld_Installing",
	"CooperTaskWorld_PreviousInstall",
}
for _, root in ipairs(publishRoots) do
	for _, descendant in ipairs(root:GetDescendants()) do
		for _, prefix in ipairs(stagingPrefixes) do
			if string.sub(descendant.Name, 1, #prefix) == prefix then
				check(false, "Installer staging/rollback object remains: " .. descendant:GetFullName())
			end
		end
	end
end

local forbiddenSourceMarkers = {
	"CooperCrisis",
	"CooperProgression",
	"DebugSetStability",
	"DebugFinishOnboarding",
	"RegisterCrisis",
	"BeginPanic",
	"PanicStarted",
}
for path, source in pairs(canonicalSources) do
	for _, marker in ipairs(forbiddenSourceMarkers) do
		check(not sourceContains(source, marker), path .. " contains retired source marker " .. marker)
	end
end

if #failures > 0 then
	error("[Milestone0BaselineAudit] FAIL (" .. #failures .. " of " .. checkCount .. " checks):\n - " .. table.concat(failures, "\n - "), 0)
end

local mode = RunService:IsRunning() and "runtime" or "edit"
local baselineName = inspectingCurrentMilestone1
	and "schema 12 PartyV1, cap 4, Lobby-only"
	or "schema 11 PersonalV4 rollback, cap 1, all future flags disabled"
print(string.format(
	"[Milestone0BaselineAudit] PASS: %d read-only checks in %s mode; %s; five tasks, eleven stages, four approved cutout NPCs, canonical rollback protections, and retired-system absence verified",
	checkCount,
	mode,
	baselineName
))
return true
