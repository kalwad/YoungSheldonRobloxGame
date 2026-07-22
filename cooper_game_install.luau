--!nonstrict
-- Transactional edit-mode installer for the Cooper campaign foundation.
-- Run in Studio, then inject the three companion source mirrors into Config,
-- ServerScriptService.CooperGame, and StarterPlayerScripts.CooperGame.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "cooper_game_install.luau may only run in Studio edit mode")

local INSTALL_VERSION = "2026-07-20.chemistry.1"
local ROOT_NAME = "CooperGame"
local TEMP_ROOT_NAME = ROOT_NAME .. "_Installing"
local PREVIOUS_ROOT_NAME = ROOT_NAME .. "_PreviousInstall"
local SERVER_EVENTS_NAME = "CooperGameServerEvents"
local SCRIPT_TEMP_NAME = "CooperGame_Installing"
local SCRIPT_PREVIOUS_NAME = "CooperGame_PreviousInstall"

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment was not found")
local house = environment:FindFirstChild("CooperHouse")
assert(house and house:IsA("Model"), "CooperHouseEnvironment.CooperHouse was not found")
assert(house:FindFirstChild("CooperInteractions"), "Install the Cooper house interactions before the campaign")
local garage = environment:FindFirstChild("DetachedGarage")
assert(garage and garage:IsA("Model"), "DetachedGarage was not found")
assert(garage:FindFirstChild("InteractiveSectionalGarageDoor"), "Install the interactive garage door before the campaign")
local interactionRemotes = ReplicatedStorage:FindFirstChild("CooperInteractionsRemotes")
assert(interactionRemotes and interactionRemotes:IsA("Folder"), "CooperInteractionsRemotes was not installed")

local starterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(starterPlayerScripts, "StarterPlayer.StarterPlayerScripts was not found")

local previousRoot = ReplicatedStorage:FindFirstChild(ROOT_NAME)
if previousRoot then
	assert(previousRoot:IsA("Folder"), "ReplicatedStorage.CooperGame must be a Folder")
end
local previousServer = ServerScriptService:FindFirstChild(ROOT_NAME)
if previousServer then
	assert(previousServer:IsA("Script"), "ServerScriptService.CooperGame must be a Script")
end
local previousClient = starterPlayerScripts:FindFirstChild(ROOT_NAME)
if previousClient then
	assert(previousClient:IsA("LocalScript"), "StarterPlayerScripts.CooperGame must be a LocalScript")
end

assert(not ReplicatedStorage:FindFirstChild(PREVIOUS_ROOT_NAME), "A stale CooperGame previous-install root requires inspection")
assert(not ServerScriptService:FindFirstChild(SCRIPT_PREVIOUS_NAME), "A stale CooperGame previous server script requires inspection")
assert(not starterPlayerScripts:FindFirstChild(SCRIPT_PREVIOUS_NAME), "A stale CooperGame previous client script requires inspection")

local staleTempRoot = ReplicatedStorage:FindFirstChild(TEMP_ROOT_NAME)
if staleTempRoot then
	staleTempRoot:Destroy()
end
local staleServerTemp = ServerScriptService:FindFirstChild(SCRIPT_TEMP_NAME)
if staleServerTemp then
	staleServerTemp:Destroy()
end
local staleClientTemp = starterPlayerScripts:FindFirstChild(SCRIPT_TEMP_NAME)
if staleClientTemp then
	staleClientTemp:Destroy()
end

local previousConfig = previousRoot and previousRoot:FindFirstChild("Config")
local previousConfigSource = nil
if previousConfig and previousConfig:IsA("ModuleScript") then
	pcall(function()
		if #previousConfig.Source > 100 then
			previousConfigSource = previousConfig.Source
		end
	end)
end

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"InstallCooperGameFoundation",
		"Install Cooper campaign state, remotes, and runtime targets"
	)
end)

local function finishRecording(commit)
	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(
				recording,
				commit and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
			)
		end)
	elseif commit then
		pcall(function()
			ChangeHistoryService:SetWaypoint("Cooper campaign foundation installed")
		end)
	end
end

local function stageSource(target, previous, className)
	local validSource = nil
	local desiredEnabled = false
	if previous and previous.ClassName == className then
		pcall(function()
			if #previous.Source > 100 then
				validSource = previous.Source
				desiredEnabled = previous.Enabled
			end
		end)
	end
	if validSource then
		target.Source = validSource
	else
		target.Source = "-- Source target created by cooper_game_install.luau. Inject the matching companion source mirror."
	end
	target.Enabled = false
	return validSource ~= nil, desiredEnabled
end

local stagedRoot
local stagedServer
local stagedClient
local createdServerEvents = false
local createdServerEventChildren = {}
local rootSwapped = false
local serverSwapped = false
local clientSwapped = false

local ok, result = xpcall(function()
	-- Build and validate every replacement before any live object is renamed or
	-- destroyed. Script targets remain unparented and disabled while staged.
	stagedRoot = Instance.new("Folder")
	stagedRoot.Name = TEMP_ROOT_NAME
	stagedRoot:SetAttribute("InstallVersion", INSTALL_VERSION)
	stagedRoot:SetAttribute("Purpose", "Server-authoritative Cooper house campaign")

	local config = Instance.new("ModuleScript")
	config.Name = "Config"
	config.Source = previousConfigSource
		or "error(\"CooperGame.Config source has not been injected; install CooperFamilyTaskConfig.module.luau\")"
	config.Parent = stagedRoot

	local state = Instance.new("Folder")
	state.Name = "State"
state:SetAttribute("SchemaVersion", 10)
	state:SetAttribute("FoundationContract", "PersonalV4")
	state:SetAttribute("MachineStage", 0)
	state:SetAttribute("MachineStageName", "Blueprint Pending")
	state:SetAttribute("MachineProgress", 0)
	state:SetAttribute("TaskRevision", 0)
	state:SetAttribute("SupportsPaidPartOrdering", true)
	state:SetAttribute("SupportsBoombox", true)
	state:SetAttribute("SupportsIncomeBoombox", true)
	state:SetAttribute("SupportsBoomboxAutoplay", true)
	state:SetAttribute("SupportsTaskAutomation", true)
	state:SetAttribute("SupportsMedfordBankHack", true)
	state:SetAttribute("SupportsSecretBunkerUnlock", true)
	state:SetAttribute("SupportsBunkerChemistrySetup", true)
	state.Parent = stagedRoot

	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = stagedRoot
	for _, name in ipairs({ "Snapshot", "Feedback", "Request", "BankHack" }) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remotes
	end

	stagedServer = Instance.new("Script")
	stagedServer.Name = SCRIPT_TEMP_NAME
	local serverPreserved, serverDesiredEnabled = stageSource(stagedServer, previousServer, "Script")

	stagedClient = Instance.new("LocalScript")
	stagedClient.Name = SCRIPT_TEMP_NAME
	local clientPreserved, clientDesiredEnabled = stageSource(stagedClient, previousClient, "LocalScript")

	assert(stagedRoot:FindFirstChild("Config") and stagedRoot:FindFirstChild("State") and stagedRoot:FindFirstChild("Remotes"), "Staged root is incomplete")
	assert(#stagedServer.Source > 20 and #stagedClient.Source > 20, "Staged runtime source targets are invalid")

	-- Server-only API objects are additive. Reject wrong-class collisions instead
	-- of deleting unknown/user-owned objects during an install.
	local serverEvents = ServerScriptService:FindFirstChild(SERVER_EVENTS_NAME)
	if serverEvents then
		assert(serverEvents:IsA("Folder"), SERVER_EVENTS_NAME .. " must be a Folder")
	else
		serverEvents = Instance.new("Folder")
		serverEvents.Name = SERVER_EVENTS_NAME
		serverEvents.Parent = ServerScriptService
		createdServerEvents = true
	end
	for _, specification in ipairs({
		{ className = "BindableEvent", name = "ReportAction" },
		{ className = "BindableEvent", name = "RegisterAction" },
		{ className = "BindableEvent", name = "RequestBunkerConstruction" },
		{ className = "BindableFunction", name = "API" },
	}) do
		local className = specification.className
		local name = specification.name
		local existing = serverEvents:FindFirstChild(name)
		if existing then
			assert(existing.ClassName == className, existing:GetFullName() .. " must be a " .. className)
		else
			local bindable = Instance.new(className)
			bindable.Name = name
			bindable.Parent = serverEvents
			table.insert(createdServerEventChildren, bindable)
		end
	end

	-- Commit by renaming old objects out of the canonical paths. New scripts stay
	-- disabled through the complete swap, so even an accidental runtime call could
	-- never run two campaign loops simultaneously.
	if previousRoot then
		previousRoot.Name = PREVIOUS_ROOT_NAME
	end
	stagedRoot.Name = ROOT_NAME
	stagedRoot.Parent = ReplicatedStorage
	rootSwapped = true

	if previousServer then
		previousServer.Name = SCRIPT_PREVIOUS_NAME
	end
	stagedServer.Parent = ServerScriptService
	stagedServer.Name = ROOT_NAME
	serverSwapped = true

	if previousClient then
		previousClient.Name = SCRIPT_PREVIOUS_NAME
	end
	stagedClient.Parent = starterPlayerScripts
	stagedClient.Name = ROOT_NAME
	clientSwapped = true

	assert(ReplicatedStorage:FindFirstChild(ROOT_NAME) == stagedRoot, "Campaign root swap failed")
	assert(ServerScriptService:FindFirstChild(ROOT_NAME) == stagedServer, "Campaign server swap failed")
	assert(starterPlayerScripts:FindFirstChild(ROOT_NAME) == stagedClient, "Campaign client swap failed")

	stagedServer.Enabled = serverPreserved and serverDesiredEnabled
	stagedClient.Enabled = clientPreserved and clientDesiredEnabled
	-- Destruction is the final no-return step, after every property assignment and
	-- canonical-path assertion that could require rollback has succeeded.
	if previousRoot then
		previousRoot:Destroy()
	end
	if previousServer then
		previousServer:Destroy()
	end
	if previousClient then
		previousClient:Destroy()
	end

	return {
		configPreserved = previousConfigSource ~= nil,
		serverPreserved = serverPreserved,
		clientPreserved = clientPreserved,
	}
end, function(message)
	return debug.traceback(tostring(message), 2)
end)

if not ok then
	-- Roll back every canonical path while the old objects still exist. This is
	-- intentionally fail-closed: staged scripts were never enabled.
	if clientSwapped and stagedClient and stagedClient.Parent then
		stagedClient:Destroy()
	end
	if previousClient and previousClient.Parent then
		previousClient.Name = ROOT_NAME
	end
	if serverSwapped and stagedServer and stagedServer.Parent then
		stagedServer:Destroy()
	end
	if previousServer and previousServer.Parent then
		previousServer.Name = ROOT_NAME
	end
	if rootSwapped and stagedRoot and stagedRoot.Parent then
		stagedRoot:Destroy()
	end
	if previousRoot and previousRoot.Parent then
		previousRoot.Name = ROOT_NAME
	end
	if not createdServerEvents then
		for _, child in ipairs(createdServerEventChildren) do
			if child.Parent then
				child:Destroy()
			end
		end
	else
		local serverEvents = ServerScriptService:FindFirstChild(SERVER_EVENTS_NAME)
		if serverEvents then
			serverEvents:Destroy()
		end
	end
	if stagedRoot and not stagedRoot.Parent then
		stagedRoot:Destroy()
	end
	if stagedServer and not stagedServer.Parent then
		stagedServer:Destroy()
	end
	if stagedClient and not stagedClient.Parent then
		stagedClient:Destroy()
	end
	finishRecording(false)
	error(result, 0)
end

finishRecording(true)
print(string.format(
	"[CooperGameInstaller] Installed %s (config=%s server=%s client=%s)",
	INSTALL_VERSION,
	tostring(result.configPreserved),
	tostring(result.serverPreserved),
	tostring(result.clientPreserved)
))

return result
