--!nonstrict
-- Read-only audit for the Studio-only lobby -> playable-house handoff.
-- Run once while stopped and again after Ready/Start opens the in-place house.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local failures = {}
local checks = 0

local function check(condition, message)
	checks += 1
	if not condition then
		table.insert(failures, message)
	end
end

local function sourceOf(value)
	if not value or not value:IsA("LuaSourceContainer") then
		return ""
	end
	local ok, source = pcall(function()
		return value.Source
	end)
	return if ok and type(source) == "string" then source else ""
end

local function contains(source, marker)
	return string.find(source, marker, 1, true) ~= nil
end

local function typedChild(parent, name, className)
	if not parent then
		return nil
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name and child:IsA(className) then
			return child
		end
	end
	return nil
end

local serverNames = {
	"CooperMovement",
	"CooperGame",
	"CooperFamilyNPCs",
	"CooperFamilyDialogue",
	"CooperInteractions",
	"CooperTaskWorld",
	"CooperBunker",
	"CooperBunkerConstruction",
	"CooperSpawnSafety",
	"CooperYardRideables",
	"CooperHouseTVAnimator",
}

local playerNames = {
	"CooperHallCameraController",
	"CooperInteractions",
	"CooperYardRideables",
	"CooperFamilyDialogue",
	"CooperBackgroundMusic",
	"CooperGeorgeProximityVoice",
	"CooperGeorgieProximityVoice",
	"CooperMaryProximityVoice",
	"CooperMissyProximityVoice",
	"CooperGame",
	"CooperBunkerClient",
	"CooperSprint",
}

local houseRemoteFolders = {
	CooperInteractionsRemotes = { "Request", "Client" },
	CooperYardRideablesRemotes = { "RideablesEvent" },
	CooperBunkerRemotes = { "BunkerEvent" },
}

local lobbyServer = ServerScriptService:FindFirstChild("CooperLobby")
local bridge = ServerScriptService:FindFirstChild("StudioHousePreview")
local lobbyClient = StarterPlayer.StarterPlayerScripts:FindFirstChild("CooperLobby")
check(lobbyServer and lobbyServer:IsA("Script"), "ServerScriptService.CooperLobby is missing")
check(bridge and bridge:IsA("Script"), "ServerScriptService.StudioHousePreview is missing")
check(lobbyClient and lobbyClient:IsA("LocalScript"), "StarterPlayerScripts.CooperLobby is missing")

local lobbySource = sourceOf(lobbyServer)
local bridgeSource = sourceOf(bridge)
local clientSource = sourceOf(lobbyClient)
for _, marker in ipairs({
	"STUDIO_HOUSE_BRIDGE_UNAVAILABLE",
	"bridgeLaunch:Invoke",
	"STUDIO_HOUSE_STARTED",
}) do
	check(contains(lobbySource, marker), "Lobby server is missing Studio handoff marker: " .. marker)
end
check(not contains(lobbySource, "Studio preview passed; launch was safely skipped."), "Lobby still reports fake Studio launch success")
for _, marker in ipairs({
	"if not RunService:IsStudio() then",
	"StudioHousePreviewPackage",
	"StudioPlayerScripts",
	"CooperStudioHousePreviewActive",
	"EnableStudioDataStore",
	"STUDIO_HOUSE_PACKAGE_INVALID",
	"installHouseRemotes",
}) do
	check(contains(bridgeSource, marker), "Studio bridge is missing safety marker: " .. marker)
end
for _, marker in ipairs({
	"StudioHouseTransitionBegin",
	"StudioHouseTransitionFailed",
	"StudioHouseTransitionComplete",
	"controls:Enable()",
	"camera.CameraType = Enum.CameraType.Custom",
	"gui:Destroy()",
}) do
	check(contains(clientSource, marker), "Lobby client is missing transition cleanup marker: " .. marker)
end

local package = ServerStorage:FindFirstChild("StudioHousePreviewPackage")
check(package and package:IsA("Folder"), "ServerStorage.StudioHousePreviewPackage is missing")
if package and package:IsA("Folder") then
	check(typedChild(package, "CooperHouseEnvironment", "Model") ~= nil, "Preview package is missing CooperHouseEnvironment")
	check(typedChild(package, "CooperGame", "Folder") ~= nil, "Preview package is missing replicated CooperGame folder")
	check(typedChild(package, "CooperFamilyLocalImages", "Folder") ~= nil, "Preview package is missing local-image asset map")
	check(typedChild(package, "CooperFamilyLocalAudio", "Folder") ~= nil, "Preview package is missing local-audio asset map")
	for _, name in ipairs(serverNames) do
		check(typedChild(package, name, "Script") ~= nil, "Preview package is missing server script " .. name)
	end
	local playerTemplates = typedChild(package, "StudioPlayerScripts", "Folder")
	check(playerTemplates ~= nil, "Preview package is missing StudioPlayerScripts")
	for _, name in ipairs(playerNames) do
		local template = typedChild(playerTemplates, name, "LocalScript")
		check(template ~= nil, "Preview package is missing player script " .. name)
		if template then
			check(template.Enabled == true, "Template source should retain its verified enabled state: " .. name)
		end
	end
end

local active = Workspace:GetAttribute("CooperStudioHousePreviewActive") == true
if active then
	local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
	check(environment and environment:IsA("Model"), "Active preview is missing CooperHouseEnvironment")
	check(Workspace:FindFirstChild("CooperPartyLobbyEnvironment") == nil, "Lobby environment still overlaps the active house")
	check(Workspace:FindFirstChild("InteractiveFrontDoor") == nil, "Duplicate top-level front door was cloned")
	check(Workspace:FindFirstChild("InteractiveDenPatioDoor") == nil, "Duplicate top-level patio door was cloned")
	check(Workspace:FindFirstChild("InteractiveSectionalGarageDoor") == nil, "Duplicate top-level garage door was cloned")
	check(ReplicatedStorage:FindFirstChild("CooperGame") ~= nil, "Active preview is missing ReplicatedStorage.CooperGame")
	for folderName, eventNames in pairs(houseRemoteFolders) do
		local folder = typedChild(ReplicatedStorage, folderName, "Folder")
		check(folder ~= nil, "Active preview is missing house remote folder " .. folderName)
		for _, eventName in ipairs(eventNames) do
			check(typedChild(folder, eventName, "RemoteEvent") ~= nil,
				folderName .. " is missing RemoteEvent " .. eventName)
		end
	end
	for _, name in ipairs(serverNames) do
		local liveScript = typedChild(ServerScriptService, name, "Script")
		check(liveScript ~= nil and liveScript.Enabled, "Active preview server script is missing or disabled: " .. name)
	end
	if environment and environment:IsA("Model") then
		local npcWorld = environment:FindFirstChild("CooperFamilyNPCs")
		check(npcWorld and npcWorld:IsA("Folder"), "Active preview NPC world is missing")
		if npcWorld then
			local approved = { George = true, Georgie = true, Mary = true, Missy = true }
			local count = 0
			for _, child in ipairs(npcWorld:GetChildren()) do
				if child:IsA("Model") then
					count += 1
					check(approved[child.Name] == true, "Unexpected Studio preview NPC: " .. child.Name)
				end
			end
			check(count == 4, "Studio preview must contain exactly four approved NPCs")
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		check(player:GetAttribute("CooperGameProfileLoaded") == true, player.Name .. " profile did not finish loading")
		check(player:GetAttribute("CooperPartyMember") == true, player.Name .. " was not admitted to the synthetic Studio party")
	end
	local replicatedPlayerScripts = typedChild(ReplicatedStorage, "CooperStudioPlayerScripts", "Folder")
	check(replicatedPlayerScripts ~= nil, "Active preview is missing its client-owned PlayerScripts handoff folder")
	for _, name in ipairs(playerNames) do
		check(typedChild(replicatedPlayerScripts, name, "LocalScript") ~= nil,
			"PlayerScripts handoff is missing " .. name)
	end
	local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
	local configModule = gameRoot and gameRoot:FindFirstChild("Config")
	if configModule and configModule:IsA("ModuleScript") then
		local config = require(configModule)
		check(config.Features.StudioScenarioTools == false, "Studio preview must not enable scenario grants")
		check(config.Features.Horror == false, "Studio preview must not enable horror")
	end
else
	check(Workspace:FindFirstChild("CooperPartyLobbyEnvironment") ~= nil, "Stopped/pre-launch lobby environment is missing")
	check(Workspace:FindFirstChild("CooperHouseEnvironment") == nil, "House authority leaked into the pre-launch lobby")
	if bridge and bridge:IsA("Script") and RunService:IsRunning() then
		check(bridge:FindFirstChild("Launch") and bridge.Launch:IsA("BindableFunction"), "Runtime Studio bridge Launch bindable is missing")
	end
end

if #failures > 0 then
	error(string.format(
		"[StudioHousePreviewAudit] FAIL (%d of %d checks, %s/%s):\n - %s",
		#failures,
		checks,
		RunService:IsRunning() and "runtime" or "edit",
		active and "house-active" or "lobby",
		table.concat(failures, "\n - ")
	), 0)
end

print(string.format(
	"[StudioHousePreviewAudit] PASS: %d checks; Studio handoff is packaged, production-guarded, and %s (%s mode)",
	checks,
	active and "playable-house active" or "ready in lobby",
	RunService:IsRunning() and "runtime" or "edit"
))
return true
