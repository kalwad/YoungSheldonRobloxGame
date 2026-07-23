-- Runtime startup readiness verifier.
--
-- Run from the SERVER Command Bar during a fresh Studio Play session, after
-- startup has had up to 45 seconds. This proves that the core authorities
-- actually executed; enabled Script objects and edit-time instances are not
-- accepted as runtime evidence.

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local STARTUP_TIMEOUT_SECONDS = 45
local POLL_SECONDS = 0.1

if not RunService:IsRunning() then
	error("[RuntimeStartupReadiness] This verifier must run during Studio Play, not edit mode.", 0)
end
if not RunService:IsServer() then
	error("[RuntimeStartupReadiness] Run this verifier in the SERVER Command Bar.", 0)
end

local failures = {}

local function check(condition, message)
	if not condition then
		table.insert(failures, message)
	end
	return condition
end

local function typedChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name) or nil
	if child and child:IsA(className) then
		return child
	end
	return nil
end

local scripts = {
	CooperGame = typedChild(ServerScriptService, "CooperGame", "Script"),
	CooperBunker = typedChild(ServerScriptService, "CooperBunker", "Script"),
	CooperTaskWorld = typedChild(ServerScriptService, "CooperTaskWorld", "Script"),
}
for name, scriptObject in pairs(scripts) do
	check(scriptObject ~= nil, "ServerScriptService." .. name .. " is missing or is not a Script.")
	if scriptObject then
		check(scriptObject.Enabled, "ServerScriptService." .. name .. " is disabled.")
	end
end

local root = typedChild(ReplicatedStorage, "CooperGame", "Folder")
check(root ~= nil, "ReplicatedStorage.CooperGame is missing.")

local config
if root then
	local configModule = typedChild(root, "Config", "ModuleScript")
	check(configModule ~= nil, "ReplicatedStorage.CooperGame.Config is missing.")
	if configModule then
		local ok, result = pcall(require, configModule)
		check(ok and type(result) == "table", "CooperGame.Config could not be required at runtime.")
		if ok and type(result) == "table" then
			config = result
		end
	end
end

local serverEventsName = config and config.ServerEventsName or "CooperGameServerEvents"
local worldRootName = config and config.WorldRootName or "CooperFamilyTaskWorld"

local function currentReadiness()
	local liveRoot = typedChild(ReplicatedStorage, "CooperGame", "Folder")
	local state = typedChild(liveRoot, "State", "Folder")
	local remotes = typedChild(liveRoot, "Remotes", "Folder")
	local serverEvents = typedChild(ServerScriptService, serverEventsName, "Folder")
	local environment = typedChild(Workspace, "CooperHouseEnvironment", "Model")
		or typedChild(Workspace, "CooperHouseEnvironment", "Folder")
	local world = environment and environment:FindFirstChild(worldRootName) or nil
	local bunker = environment and environment:FindFirstChild("BackyardBunker") or nil
	return state ~= nil
		and state:GetAttribute("FoundationContract") == "PartyV1"
		and type(state:GetAttribute("SchemaVersion")) == "number"
		and remotes ~= nil
		and serverEvents ~= nil
		and world ~= nil
		and world:GetAttribute("ControllerReady") == true
		and world:GetAttribute("TaskAutomationControllerReady") == true
		and bunker ~= nil
		and type(bunker:GetAttribute("ControllerVersion")) == "string"
		and bunker:GetAttribute("ControllerVersion") ~= ""
end

local deadline = os.clock() + STARTUP_TIMEOUT_SECONDS
while os.clock() < deadline and not currentReadiness() do
	task.wait(POLL_SECONDS)
end

local state = root and typedChild(root, "State", "Folder") or nil
local remotes = root and typedChild(root, "Remotes", "Folder") or nil
check(state ~= nil, "CooperGame did not create its runtime State folder.")
if state then
	check(
		state:GetAttribute("FoundationContract") == "PartyV1",
		"CooperGame never advertised the PartyV1 runtime foundation."
	)
	check(
		type(state:GetAttribute("SchemaVersion")) == "number",
		"CooperGame never advertised a runtime schema version."
	)
end

check(remotes ~= nil, "CooperGame did not create its runtime Remotes folder.")
if remotes then
	for _, name in ipairs({ "Snapshot", "Feedback", "Request", "BankHack" }) do
		check(
			typedChild(remotes, name, "RemoteEvent") ~= nil,
			"CooperGame runtime RemoteEvent is missing: " .. name
		)
	end
end

local serverEvents = typedChild(ServerScriptService, serverEventsName, "Folder")
check(
	serverEvents ~= nil,
	"Core authority folder " .. serverEventsName
		.. " is absent; CooperTaskWorld errors after this are likely downstream startup fallout."
)
if serverEvents then
	local requiredEvents = {
		ReportAction = "BindableEvent",
		RegisterAction = "BindableEvent",
		RequestDelivery = "BindableEvent",
		RequestBunkerConstruction = "BindableEvent",
		RunTaskAutomation = "BindableEvent",
		CandyDeliveryChanged = "BindableEvent",
		API = "BindableFunction",
	}
	for name, className in pairs(requiredEvents) do
		check(
			typedChild(serverEvents, name, className) ~= nil,
			string.format("%s.%s is missing or is not a %s.", serverEventsName, name, className)
		)
	end
end

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
check(environment ~= nil, "Workspace.CooperHouseEnvironment is missing at runtime.")
local world = environment and environment:FindFirstChild(worldRootName) or nil
check(world ~= nil, "Runtime task world is missing: " .. worldRootName)
if world then
	check(world:GetAttribute("ControllerReady") == true, "CooperTaskWorld never reached ControllerReady.")
	check(
		world:GetAttribute("TaskAutomationControllerReady") == true,
		"CooperTaskWorld never reached TaskAutomationControllerReady."
	)
end

local bunker = environment and environment:FindFirstChild("BackyardBunker") or nil
check(bunker ~= nil, "Workspace.CooperHouseEnvironment.BackyardBunker is missing.")
if bunker then
	check(
		type(bunker:GetAttribute("ControllerVersion")) == "string"
			and bunker:GetAttribute("ControllerVersion") ~= "",
		"CooperBunker did not publish its runtime ControllerVersion."
	)
end

local historyOk, history = pcall(function()
	return LogService:GetLogHistory()
end)
check(
	historyOk and type(history) == "table",
	"LogService history is unavailable; fresh core startup markers cannot be proven."
)

local logText = ""
if historyOk and type(history) == "table" then
	local messages = {}
	for _, entry in ipairs(history) do
		local message = type(entry) == "table" and (entry.message or entry.Message) or nil
		if type(message) == "string" then
			table.insert(messages, message)
		end
	end
	logText = table.concat(messages, "\n")

	local requiredMarkers = {
		"[CooperGame] Personal family tasks, allowance, and paid Time Machine construction ready",
		"[CooperTaskWorld] Paid house and bunker deliveries, task robots, dancing boombox, and chemistry setup ready",
		"[CooperBunker] Server controller ready v",
	}
	for _, marker in ipairs(requiredMarkers) do
		check(
			string.find(logText, marker, 1, true) ~= nil,
			"Fresh runtime startup marker is absent: " .. marker
		)
	end

	local fatalPatterns = {
		"Out of local registers",
		"exceeded limit 200",
		"ReportAction is missing",
		"RequestDelivery is missing",
		"RunTaskAutomation is missing",
		"CandyDeliveryChanged is missing",
		"CooperGame API is missing",
	}
	for _, pattern in ipairs(fatalPatterns) do
		check(
			string.find(logText, pattern, 1, true) == nil,
			"Fatal startup diagnostic was present in Studio Output: " .. pattern
		)
	end
end

if #failures > 0 then
	error(
		string.format(
			"[RuntimeStartupReadiness] FAIL (%d issue%s):\n - %s",
			#failures,
			#failures == 1 and "" or "s",
			table.concat(failures, "\n - ")
		),
		0
	)
end

print("[RuntimeStartupReadiness] PASS: CooperGame, CooperBunker, and CooperTaskWorld reached fresh runtime readiness.")
