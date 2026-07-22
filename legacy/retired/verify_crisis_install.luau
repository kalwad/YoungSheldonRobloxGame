--!nonstrict
-- Read-only verification for the personal-Family-compatible crisis director.
-- Run once in edit mode after source injection, then again in a server playtest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local EXPECTED_VERSION = "2026-07-13.2"
local failures = {}
local function check(condition, message)
	if not condition then
		table.insert(failures, message)
	end
end

-- Family foundation contract. The crisis layer deliberately uses personal
-- snapshots and player-scoped allowance mutations; shared stage/chapter fields
-- are presentation-only and are not authorization inputs.
local familyRoot = ReplicatedStorage:FindFirstChild("CooperGame")
check(familyRoot and familyRoot:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
local familyConfigModule = familyRoot and familyRoot:FindFirstChild("Config")
local familyState = familyRoot and familyRoot:FindFirstChild("State")
check(familyConfigModule and familyConfigModule:IsA("ModuleScript"), "CooperGame.Config is missing")
check(familyState and familyState:IsA("Folder"), "CooperGame.State is missing")
local FamilyConfig = nil
if familyConfigModule and familyConfigModule:IsA("ModuleScript") then
	local ok, result = pcall(require, familyConfigModule)
	check(ok and type(result) == "table", "CooperGame.Config did not load")
	if ok and type(result) == "table" then
		FamilyConfig = result
		check((tonumber(result.SchemaVersion) or 0) >= 2, "Crisis requires personal Family SchemaVersion >= 2")
		check(type(result.Mode) == "table", "CooperGame.Config.Mode is missing")
		for _, modeName in ipairs({ "Normal", "Panic", "Tornado", "DESRaid", "Finale", "Victory" }) do
			check(type(result.Mode) == "table" and type(result.Mode[modeName]) == "string", "Missing Family mode " .. modeName)
		end
	end
end
local familyEventsName = FamilyConfig and FamilyConfig.ServerEventsName or "CooperGameServerEvents"
local familyEvents = ServerScriptService:FindFirstChild(familyEventsName)
local familyAPI = familyEvents and familyEvents:FindFirstChild("API")
local familyServer = ServerScriptService:FindFirstChild("CooperGame")
check(familyEvents and familyEvents:IsA("Folder"), familyEventsName .. " is missing")
check(familyAPI and familyAPI:IsA("BindableFunction"), familyEventsName .. ".API is missing")
check(familyServer and familyServer:IsA("Script"), "ServerScriptService.CooperGame is missing")
if familyServer and familyServer:IsA("Script") then
	check(#familyServer.Source > 10000 and familyServer.Disabled == false, "Current Family server source must be injected and enabled")
end

local root = ReplicatedStorage:FindFirstChild("CooperCrisis")
check(root and root:IsA("Folder"), "ReplicatedStorage.CooperCrisis is missing")
local state = root and root:FindFirstChild("State")
if root then
	check(root:GetAttribute("InstallVersion") == EXPECTED_VERSION, "Unexpected CooperCrisis install version")
	check(state and state:IsA("Folder"), "Crisis State folder is missing")
	check(root:FindFirstChild("Event") and root.Event:IsA("RemoteEvent"), "Crisis Event remote is missing")
	check(root:FindFirstChild("Request") and root.Request:IsA("RemoteEvent"), "Crisis Request remote is missing")
end
if state then
	check(state:GetAttribute("FamilyContract") == "PersonalV2", "Crisis state does not declare PersonalV2 Family compatibility")
	for _, attribute in ipairs({
		"FamilySupportsStability", "MaximumPersonalStage", "MaximumPersonalProgress",
		"LoadedProfileCount", "ProgressionConnected", "BrainEventActive", "BrainEventEndsAt",
		"ExternalRunId", "FinaleOwned", "StormLockerCapacity", "StormLockerUsed",
	}) do
		check(state:GetAttribute(attribute) ~= nil, "Crisis state is missing " .. attribute)
	end
end

local environment = workspace:FindFirstChild("CooperHouseEnvironment")
local world = environment and environment:FindFirstChild("CooperCrisisWorld")
check(world and world:IsA("Model"), "CooperCrisisWorld is missing")
if world then
	check(world:GetAttribute("InstallVersion") == EXPECTED_VERSION, "Unexpected crisis world version")
	for _, name in ipairs({
		"StormLocker", "StormStrapStation", "DESPermitTerminal", "DESFalseCabinet",
		"DESDistractionSwitch", "TornadoVisual", "DESInspectors", "AftermathSpawns",
		"EvidenceHold", "LooseCrisisEquipment",
	}) do
		check(world:FindFirstChild(name) ~= nil, "Missing crisis world object " .. name)
	end
	for _, promptName in ipairs({
		"SecureStormItemPrompt", "ApplyStormStrapPrompt", "PrintPermitPrompt",
		"ConcealTechPrompt", "DistractDESPrompt",
	}) do
			local prompt = world:FindFirstChild(promptName, true)
			check(prompt and prompt:IsA("ProximityPrompt"), "Missing permanent crisis prompt " .. promptName)
			if prompt and prompt:IsA("ProximityPrompt") then
				check(prompt:GetAttribute("CooperCrisisInteraction") == true, promptName .. " is not marked as a supported fast interaction")
				check(type(prompt:GetAttribute("CooperBaseHoldDuration")) == "number", promptName .. " is missing its authoritative base hold duration")
			end
		end
	local stormEligibleCount = 0
	local temporaryProps = world:FindFirstChild("TemporaryEventProps")
	for _, descendant in ipairs(world:GetDescendants()) do
		if descendant:GetAttribute("StormEligible") == true then
			stormEligibleCount += 1
		end
		if temporaryProps and descendant:IsDescendantOf(temporaryProps) and descendant:IsA("BasePart") then
			check(not descendant.CanCollide and not descendant.CanTouch, "Brain-event prop can interfere with Family chores: " .. descendant.Name)
		end
	end
	check(stormEligibleCount >= 3, "Expected at least 3 storm-eligible equipment models")
	local inspectors = world:FindFirstChild("DESInspectors")
	check(inspectors and #inspectors:GetChildren() == 2, "Expected exactly 2 D.E.S. inspector cutouts")
	local aftermath = world:FindFirstChild("AftermathSpawns")
	check(aftermath and #aftermath:GetChildren() == 6, "Expected exactly 6 aftermath recovery points")
	local emitter = world:FindFirstChild("DebrisCloud", true)
	check(emitter and emitter:IsA("ParticleEmitter"), "Tornado DebrisCloud emitter is missing")
end

local server = ServerScriptService:FindFirstChild("CooperCrisis")
local client = StarterPlayer.StarterPlayerScripts:FindFirstChild("CooperCrisisClient")
check(server and server:IsA("Script"), "ServerScriptService.CooperCrisis is missing")
check(client and client:IsA("LocalScript"), "StarterPlayerScripts.CooperCrisisClient is missing")
if server and server:IsA("Script") then
	check(#server.Source > 20000 and server.Source:find("runTornado", 1, true) ~= nil, "CooperCrisis server source was not injected")
	check(server.Source:find("runDES", 1, true) ~= nil, "CooperCrisis server is missing D.E.S. logic")
	check(server.Source:find("BRAIN_EVENTS", 1, true) ~= nil, "CooperCrisis server is missing brain events")
	check(server.Source:find("familySnapshot", 1, true) ~= nil, "Crisis server does not use per-player Family snapshots")
	check(server.Source:find("AdjustCurrency\", nil", 1, true) == nil, "Crisis server still performs a playerless currency mutation")
	check(server.Source:find("campaignState:GetAttribute(\"Chapter\")", 1, true) == nil, "Crisis server still authorizes from shared Chapter")
	check(server.Source:find("campaignState:GetAttribute(\"MachineProgress\")", 1, true) == nil, "Crisis server still authorizes from shared MachineProgress")
	check(server.Source:find("SupportsStability", 1, true) ~= nil, "Optional stability capability guard is missing")
	check(server.Source:find("RegisterCrisis", 1, true) ~= nil and server.Source:find("CrisisResolved", 1, true) ~= nil, "Progression crisis handshake is missing")
	check(server.Disabled == false, "CooperCrisis server is disabled")
end
if client and client:IsA("LocalScript") then
	check(#client.Source > 10000 and client.Source:find("CooperCrisisHUD", 1, true) ~= nil, "CooperCrisis client source was not injected")
	check(client.Source:find("BrainEventEnded", 1, true) ~= nil, "Crisis client cannot cancel brain events for Panic/Finale")
	check(client.Disabled == false, "CooperCrisis client is disabled")
end

local events = ServerScriptService:FindFirstChild("CooperCrisisServerEvents")
check(events and events:IsA("Folder"), "CooperCrisisServerEvents is missing")
if events then
	check(events:FindFirstChild("API") and events.API:IsA("BindableFunction"), "Crisis API is missing")
	check(events:FindFirstChild("Resolved") and events.Resolved:IsA("BindableEvent"), "Crisis Resolved event is missing")
end

for _, container in ipairs({ ReplicatedStorage, ServerScriptService, StarterPlayer.StarterPlayerScripts, environment }) do
	if container then
		for _, child in ipairs(container:GetChildren()) do
			check(not child.Name:match("^_CooperCrisis"), "Temporary crisis install artifact remains: " .. child:GetFullName())
		end
	end
end

if RunService:IsRunning() and events and events:FindFirstChild("API") then
	check(familyState and familyState:GetAttribute("FoundationContract") == "PersonalV2", "Runtime Family foundation did not advertise PersonalV2")
	check(familyState and familyState:GetAttribute("SupportsStability") == true, "Runtime Family foundation did not advertise stability support")
	local ok, available, version = pcall(function()
		return events.API:Invoke("IsAvailable")
	end)
	check(ok and available == true, "Runtime crisis API is not available")
	check(version == EXPECTED_VERSION, "Runtime crisis API version mismatch")
	if ok and available then
		local snapshotOK, snapshot = pcall(function()
			return events.API:Invoke("GetSnapshot")
		end)
		check(snapshotOK and type(snapshot) == "table", "Runtime crisis snapshot failed")
		if snapshotOK and type(snapshot) == "table" then
			check(type(snapshot.suspicion) == "number", "Runtime snapshot lacks suspicion")
			check(type(snapshot.maximumPersonalStage) == "number", "Runtime snapshot lacks personal-stage aggregation")
				check(type(snapshot.loadedProfileCount) == "number", "Runtime snapshot lacks loaded-profile count")
				check(type(snapshot.familySupportsStability) == "boolean", "Runtime snapshot lacks explicit stability capability")
				check(type(snapshot.stormLockerCapacity) == "number" and snapshot.stormLockerCapacity >= 1, "Runtime snapshot lacks Storm Locker capacity")
				check(type(snapshot.stormLockerUsed) == "number" and snapshot.stormLockerUsed >= 0, "Runtime snapshot lacks Storm Locker usage")
		end
		local compatibilityOK, compatibility = pcall(function()
			return events.API:Invoke("GetCompatibility")
		end)
		check(compatibilityOK and type(compatibility) == "table", "Runtime compatibility report failed")
		if compatibilityOK and type(compatibility) == "table" then
			check(compatibility.familyContract == "PersonalV2", "Runtime Family contract mismatch")
			check(compatibility.tornadoUnlockStage == 5 and compatibility.desUnlockStage == 6, "Runtime progression unlocks are wrong")
		end
	end
end

if #failures > 0 then
	error("[CooperCrisisAudit] FAIL:\n- " .. table.concat(failures, "\n- "))
end
print("[CooperCrisisAudit] PASS: PersonalV2 Family contract, upgrade-backed crisis interactions, optional stability, progression/finale handshake")
