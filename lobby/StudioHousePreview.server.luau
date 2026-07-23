--!strict
-- Studio-only in-place handoff from the party lobby to the verified Cooper
-- house. Roblox does not run cross-place TeleportService calls in Studio, so
-- this bridge clones an inert, edit-time package into the current playtest.
-- It is never a production fallback and never grants saved progression.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local PACKAGE_NAME = "StudioHousePreviewPackage"
local PLAYER_SCRIPTS_FOLDER_NAME = "StudioPlayerScripts"
local REPLICATED_PLAYER_SCRIPTS_NAME = "CooperStudioPlayerScripts"
local LAUNCH_BINDABLE_NAME = "Launch"

local REPLICATED_TEMPLATES = {
	{ name = "CooperGame", className = "Folder" },
	{ name = "CooperFamilyLocalImages", className = "Folder" },
	{ name = "CooperFamilyLocalAudio", className = "Folder" },
}

-- These folders are normally installed directly in the house place. The
-- verified Studio package contains the authoritative scripts and world, but
-- intentionally contains no live RemoteEvents. Recreate only the exact remote
-- surface those scripts require before any house controller is enabled.
local HOUSE_REMOTE_FOLDERS = {
	{ name = "CooperInteractionsRemotes", events = { "Request", "Client" } },
	{ name = "CooperYardRideablesRemotes", events = { "RideablesEvent" } },
	{ name = "CooperBunkerRemotes", events = { "BunkerEvent" } },
}

local SERVER_SCRIPT_START_ORDER = {
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

local PLAYER_SCRIPT_NAMES = {
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

local LOBBY_LIGHTING_EFFECT_NAMES = {
	"LobbyAtmosphere",
	"LobbyColorGrade",
	"LobbyBloom",
	"LobbyDepthOfField",
}

local DOOR_TEMPLATE_NAMES = {
	"InteractiveFrontDoor",
	"InteractiveDenPatioDoor",
	"InteractiveSectionalGarageDoor",
}

type LaunchContext = {
	hostUserId: number,
	memberUserIds: { number },
	partyId: string?,
	partyRevision: number?,
}

type LaunchResult = {
	ok: boolean,
	reasonCode: string,
	message: string,
	coreReady: boolean?,
}

local launchState = "Idle"

local function result(ok: boolean, reasonCode: string, message: string, coreReady: boolean?): LaunchResult
	return {
		ok = ok,
		reasonCode = reasonCode,
		message = message,
		coreReady = coreReady,
	}
end

local function clientCommandRemote(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("CooperPartyLobby")
	local remote = remotes and remotes:FindFirstChild("ClientCommand")
	return if remote and remote:IsA("RemoteEvent") then remote else nil
end

local function tellMembers(players: { Player }, command: string, payload: any?)
	local remote = clientCommandRemote()
	if not remote then
		return
	end
	for _, player in ipairs(players) do
		if player.Parent == Players then
			remote:FireClient(player, command, payload)
		end
	end
end

local function validateLaunchContext(rawContext: any): (LaunchContext?, { Player }?, string?)
	if type(rawContext) ~= "table" then
		return nil, nil, "The Studio house launch did not include a party snapshot."
	end
	local hostUserId = tonumber(rawContext.hostUserId)
	local rawMembers = rawContext.memberUserIds
	if not hostUserId or hostUserId % 1 ~= 0 or hostUserId <= 0 or type(rawMembers) ~= "table" then
		return nil, nil, "The Studio house party snapshot was malformed."
	end
	local members: { number } = {}
	local memberSet: { [number]: boolean } = {}
	local livePlayers: { Player } = {}
	for _, rawUserId in ipairs(rawMembers) do
		local userId = tonumber(rawUserId)
		if not userId or userId % 1 ~= 0 or userId <= 0 or memberSet[userId] then
			return nil, nil, "The Studio house party member list was malformed."
		end
		memberSet[userId] = true
		table.insert(members, userId)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return nil, nil, "Every ready party member must still be present before the Studio house opens."
		end
		table.insert(livePlayers, player)
	end
	if #members < 1 or #members > 4 or memberSet[hostUserId] ~= true then
		return nil, nil, "The Studio house party must contain its host and one to four members."
	end
	return {
		hostUserId = hostUserId,
		memberUserIds = members,
		partyId = if type(rawContext.partyId) == "string" then rawContext.partyId else nil,
		partyRevision = tonumber(rawContext.partyRevision),
	}, livePlayers, nil
end

local function requiredChild(parent: Instance, name: string, className: string): (Instance?, string?)
	local child: Instance? = nil
	for _, candidate in ipairs(parent:GetChildren()) do
		if candidate.Name == name and candidate:IsA(className) then
			child = candidate
			break
		end
	end
	if not child then
		return nil, string.format("Studio preview package is missing %s (%s).", name, className)
	end
	return child, nil
end

local function validatePackage(): (Folder?, Model?, Folder?, string?)
	local packageValue, packageError = requiredChild(ServerStorage, PACKAGE_NAME, "Folder")
	if not packageValue then
		return nil, nil, nil, packageError
	end
	local package = packageValue :: Folder
	local environmentValue, environmentError = requiredChild(package, "CooperHouseEnvironment", "Model")
	if not environmentValue then
		return nil, nil, nil, environmentError
	end
	for _, specification in ipairs(REPLICATED_TEMPLATES) do
		local template = requiredChild(package, specification.name, specification.className)
		if not template then
			return nil, nil, nil, "Studio preview package is missing replicated template " .. specification.name .. "."
		end
	end
	local protocol = ReplicatedStorage:FindFirstChild("CooperPartyProtocol")
	if not protocol or not protocol:IsA("ModuleScript") then
		return nil, nil, nil, "The lobby's shared CooperPartyProtocol module is missing."
	end
	for _, name in ipairs(SERVER_SCRIPT_START_ORDER) do
		local template = requiredChild(package, name, "Script")
		if not template then
			return nil, nil, nil, "Studio preview package is missing server script " .. name .. "."
		end
	end
	for _, name in ipairs(DOOR_TEMPLATE_NAMES) do
		local template = requiredChild(package, name, "Model")
		if not template then
			return nil, nil, nil, "Studio preview package is missing verified door model " .. name .. "."
		end
	end
	local playerScriptsValue, playerScriptsError = requiredChild(package, PLAYER_SCRIPTS_FOLDER_NAME, "Folder")
	if not playerScriptsValue then
		return nil, nil, nil, playerScriptsError
	end
	local playerScripts = playerScriptsValue :: Folder
	for _, name in ipairs(PLAYER_SCRIPT_NAMES) do
		local template = playerScripts:FindFirstChild(name)
		if not template or not template:IsA("LocalScript") then
			return nil, nil, nil, "Studio preview package is missing player script " .. name .. "."
		end
	end
	if Workspace:FindFirstChild("CooperHouseEnvironment")
		or ReplicatedStorage:FindFirstChild("CooperGame")
		or ServerScriptService:FindFirstChild("CooperGame")
	then
		return nil, nil, nil, "A Cooper house runtime is already present in this playtest."
	end
	return package, environmentValue :: Model, playerScripts, nil
end

local function placePlayersAtHouseSpawn(players: { Player }, environment: Model)
	local spawnValue = environment:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawnValue then
		return
	end
	local spawn = spawnValue :: SpawnLocation
	for index, player in ipairs(players) do
		pcall(function()
			player.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
			player.DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice
			player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 14
			player.AutoJumpEnabled = true
		end)
		player.RespawnLocation = spawn
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.Sit = false
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
		end
		if character and rootPart and rootPart:IsA("BasePart") then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(spawn.CFrame * CFrame.new((index - 1) * 3, 4, 0))
		end
	end
end

local function installVerifiedDoors(package: Folder, environment: Model)
	for _, name in ipairs(DOOR_TEMPLATE_NAMES) do
		local oldDoor = environment:FindFirstChild(name, true)
		assert(oldDoor and oldDoor:IsA("Model") and oldDoor.Parent, "House environment is missing door socket " .. name)
		local template = requiredChild(package, name, "Model")
		assert(template and template:IsA("Model"), "Validated door template disappeared: " .. name)
		local parent = oldDoor.Parent
		oldDoor:Destroy()
		local clone = template:Clone()
		clone.Parent = parent
	end
end

local function installHouseRemotes(created: { Instance })
	for _, specification in ipairs(HOUSE_REMOTE_FOLDERS) do
		assert(
			ReplicatedStorage:FindFirstChild(specification.name) == nil,
			"A lobby runtime object conflicts with house remote folder " .. specification.name
		)
		local folder = Instance.new("Folder")
		folder.Name = specification.name
		folder.Parent = ReplicatedStorage
		table.insert(created, folder)
		for _, eventName in ipairs(specification.events) do
			local event = Instance.new("RemoteEvent")
			event.Name = eventName
			event.Parent = folder
		end
	end
end

local function applyVerifiedHousePresentation(created: { Instance })
	pcall(function()
		Workspace.StreamingEnabled = true
		Workspace.FallenPartsDestroyHeight = -500
	end)
	pcall(function()
		StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
		StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice
		StarterPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
		StarterPlayer.CameraMode = Enum.CameraMode.Classic
		StarterPlayer.CameraMinZoomDistance = 0.5
		StarterPlayer.CameraMaxZoomDistance = 14
		StarterPlayer.AutoJumpEnabled = true
	end)

	for _, name in ipairs({ "CooperHouseColorGrade", "CooperHouseBloom", "CooperHouseSunRays" }) do
		local oldEffect = Lighting:FindFirstChild(name)
		if oldEffect then
			oldEffect:Destroy()
		end
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "CooperHouseColorGrade"
	grade.Brightness = 0.015
	grade.Contrast = 0.05
	grade.Saturation = -0.04
	grade.TintColor = Color3.fromRGB(255, 238, 216)
	grade.Parent = Lighting
	table.insert(created, grade)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CooperHouseBloom"
	bloom.Intensity = 0.10
	bloom.Size = 22
	bloom.Threshold = 1.15
	bloom.Parent = Lighting
	table.insert(created, bloom)
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "CooperHouseSunRays"
	sunRays.Intensity = 0.025
	sunRays.Spread = 0.65
	sunRays.Parent = Lighting
	table.insert(created, sunRays)
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 15.4
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(92, 86, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 139, 132)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	Lighting.EnvironmentDiffuseScale = 0.52
	Lighting.EnvironmentSpecularScale = 0.62
	Lighting.ExposureCompensation = 0.05
end

local function coreRuntimeReady(players: { Player }, environment: Model): boolean
	local npcWorld = environment:FindFirstChild("CooperFamilyNPCs")
	local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
	local remotes = gameRoot and gameRoot:FindFirstChild("Remotes")
	if not npcWorld or not remotes then
		return false
	end
	for _, player in ipairs(players) do
		if player.Parent ~= Players
			or player:GetAttribute("CooperGameProfileLoaded") ~= true
			or player:GetAttribute("CooperPartyMember") ~= true
		then
			return false
		end
	end
	return true
end

local function startStudioHouse(rawContext: any): LaunchResult
	if not RunService:IsStudio() then
		return result(false, "STUDIO_ONLY", "The in-place house preview is available only in Studio.")
	end
	if launchState == "Active" then
		return result(true, "STUDIO_HOUSE_ALREADY_ACTIVE", "The Cooper House preview is already running.", true)
	end
	if launchState ~= "Idle" then
		return result(false, "STUDIO_HOUSE_START_BUSY", "The Cooper House preview is already opening.")
	end

	local context, livePlayers, contextError = validateLaunchContext(rawContext)
	if not context or not livePlayers then
		return result(false, "STUDIO_HOUSE_INVALID_PARTY", contextError or "The Studio party was invalid.")
	end
	local package, environmentTemplate, playerScriptsTemplate, packageError = validatePackage()
	if not package or not environmentTemplate or not playerScriptsTemplate then
		return result(false, "STUDIO_HOUSE_PACKAGE_INVALID", packageError or "The Studio house package is incomplete.")
	end

	launchState = "Loading"
	tellMembers(livePlayers, "StudioHouseTransitionBegin", {
		text = "Opening the Cooper House…",
	})

	local created: { Instance } = {}
	local disabledLighting: { { effect: Instance, enabled: boolean } } = {}
	local lobbyEnvironment = Workspace:FindFirstChild("CooperPartyLobbyEnvironment")
	local ok, failure = xpcall(function()
		for _, specification in ipairs(REPLICATED_TEMPLATES) do
			local template = requiredChild(package, specification.name, specification.className)
			assert(template, "Validated replicated template disappeared: " .. specification.name)
			local clone = template:Clone()
			clone.Parent = ReplicatedStorage
			table.insert(created, clone)
		end
		installHouseRemotes(created)

		if lobbyEnvironment then
			lobbyEnvironment.Parent = ServerStorage
		end
		for _, name in ipairs(LOBBY_LIGHTING_EFFECT_NAMES) do
			local effect = Lighting:FindFirstChild(name)
			if effect and (effect:IsA("PostEffect") or effect:IsA("Atmosphere")) then
				local enabled = if effect:IsA("PostEffect") then effect.Enabled else true
				table.insert(disabledLighting, { effect = effect, enabled = enabled })
				if effect:IsA("PostEffect") then
					effect.Enabled = false
				else
					effect.Parent = ServerStorage
				end
			end
		end

		Workspace:SetAttribute("CooperStudioHousePreviewActive", true)
		Workspace:SetAttribute("CooperStudioPartyHostUserId", context.hostUserId)
		Workspace:SetAttribute("CooperStudioPartyId", context.partyId)
		Workspace:SetAttribute("CooperStudioPartyRevision", context.partyRevision)

		local environment = environmentTemplate:Clone()
		installVerifiedDoors(package, environment)
		environment.Parent = Workspace
		table.insert(created, environment)
		applyVerifiedHousePresentation(created)

		local serverClones: { [string]: Script } = {}
		for _, name in ipairs(SERVER_SCRIPT_START_ORDER) do
			local template = requiredChild(package, name, "Script")
			assert(template and template:IsA("Script"), "Validated server template disappeared: " .. name)
			local clone = template:Clone()
			clone.Enabled = false
			clone:SetAttribute("EnableStudioDataStore", nil)
			clone.Parent = ServerScriptService
			serverClones[name] = clone
			table.insert(created, clone)
		end


		-- PlayerScripts is client-owned and is not visible to the server. Replicate
		-- one inert template folder; the already-running lobby LocalScript copies
		-- these verified scripts into its own PlayerScripts when the handoff
		-- completes. This folder exists only in a Studio runtime and is never a
		-- production authority surface.
		local replicatedPlayerScripts = playerScriptsTemplate:Clone()
		replicatedPlayerScripts.Name = REPLICATED_PLAYER_SCRIPTS_NAME
		for _, child in ipairs(replicatedPlayerScripts:GetChildren()) do
			if child:IsA("LocalScript") then
				child.Enabled = false
			end
		end
		replicatedPlayerScripts.Parent = ReplicatedStorage
		table.insert(created, replicatedPlayerScripts)

		for _, name in ipairs(SERVER_SCRIPT_START_ORDER) do
			serverClones[name].Enabled = true
		end
		placePlayersAtHouseSpawn(livePlayers, environment)
	end, debug.traceback)

	if not ok then
		for index = #created, 1, -1 do
			local instance = created[index]
			if instance.Parent then
				instance:Destroy()
			end
		end
		if lobbyEnvironment and lobbyEnvironment.Parent == ServerStorage then
			lobbyEnvironment.Parent = Workspace
		end
		for _, record in ipairs(disabledLighting) do
			if record.effect.Parent == ServerStorage and record.effect:IsA("Atmosphere") then
				record.effect.Parent = Lighting
			elseif record.effect:IsA("PostEffect") then
				record.effect.Enabled = record.enabled
			end
		end
		Workspace:SetAttribute("CooperStudioHousePreviewActive", nil)
		Workspace:SetAttribute("CooperStudioPartyHostUserId", nil)
		Workspace:SetAttribute("CooperStudioPartyId", nil)
		Workspace:SetAttribute("CooperStudioPartyRevision", nil)
		launchState = "Idle"
		warn("[StudioHousePreview] House activation failed: " .. tostring(failure))
		local message = "The Studio house could not open safely. The lobby was restored; check Output for the exact missing component."
		tellMembers(livePlayers, "StudioHouseTransitionFailed", { text = message })
		return result(false, "STUDIO_HOUSE_ACTIVATION_FAILED", message)
	end

	local environment = Workspace:FindFirstChild("CooperHouseEnvironment") :: Model
	local deadline = os.clock() + 20
	while os.clock() < deadline and not coreRuntimeReady(livePlayers, environment) do
		task.wait(0.1)
	end
	local ready = coreRuntimeReady(livePlayers, environment)
	launchState = "Active"
	placePlayersAtHouseSpawn(livePlayers, environment)
	tellMembers(livePlayers, "StudioHouseTransitionComplete", {
		coreReady = ready,
		playerScriptsFolder = REPLICATED_PLAYER_SCRIPTS_NAME,
		text = if ready
			then "Cooper House ready."
			else "Cooper House opened, but one gameplay service is still finishing startup.",
	})
	if not ready then
		warn("[StudioHousePreview] Core readiness timed out; inspect house runtime output before treating this run as verified")
	end
	return result(
		true,
		"STUDIO_HOUSE_STARTED",
		if ready then "Entering the playable Cooper House…" else "Entering the Cooper House; startup is still finishing.",
		ready
	)
end

if not RunService:IsStudio() then
	-- The package may remain in an unpublished/local lobby for repeatable tests,
	-- but a live lobby server must never retain or activate it.
	local package = ServerStorage:FindFirstChild(PACKAGE_NAME)
	if package then
		package:Destroy()
	end
	return
end

local oldLaunch = script:FindFirstChild(LAUNCH_BINDABLE_NAME)
if oldLaunch then
	oldLaunch:Destroy()
end
local launch = Instance.new("BindableFunction")
launch.Name = LAUNCH_BINDABLE_NAME
launch.OnInvoke = startStudioHouse
launch.Parent = script

print("[StudioHousePreview] In-place Cooper House bridge ready")
