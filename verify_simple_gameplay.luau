--!nonstrict
-- Edit/runtime audit for simple_gameplay_cleanup.luau.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local EXPECTED_VERSION = "2026-07-13.simple.1"
local failures = {}

local function check(condition, message)
	if not condition then
		table.insert(failures, message)
	end
end

local function hasPrefixChild(parent, prefix)
	if not parent then
		return false
	end
	for _, child in ipairs(parent:GetChildren()) do
		if string.sub(child.Name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function sourceContains(candidate, marker)
	if not candidate or not candidate:IsA("LuaSourceContainer") then
		return false
	end
	local source = ""
	local ok = pcall(function()
		source = candidate.Source
	end)
	return ok and string.find(source, marker, 1, true) ~= nil
end

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
check(starterScripts ~= nil, "StarterPlayerScripts is missing")
local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
check(environment and environment:IsA("Model"), "CooperHouseEnvironment is missing")
local house = environment and environment:FindFirstChild("CooperHouse")
local garage = environment and environment:FindFirstChild("DetachedGarage")
check(house and house:IsA("Model"), "CooperHouse was not preserved")
check(garage and garage:IsA("Model"), "DetachedGarage was not preserved")
local livingUpgrade = garage and garage:FindFirstChild("GeorgieMandyLivingUpgrade_V1")
check(not livingUpgrade or livingUpgrade:FindFirstChild("StormEquipmentBay") == nil, "Obsolete storm-equipment bay remains in Georgie's garage")
check(not garage or garage:FindFirstChild("GarageLivingArea") == nil, "Panic-only garage living-area alias remains")
check(not garage or garage:FindFirstChild("GarageLivingAreaRef") == nil, "Panic-only garage living-area reference remains")
check(not livingUpgrade or livingUpgrade:GetAttribute("GarageLivingArea") == nil, "Panic-only garage living-area attribute remains")
local kitchenette = livingUpgrade and livingUpgrade:FindFirstChild("CompactKitchenette")
check(not kitchenette or kitchenette:FindFirstChild("Remote") == nil, "Orphan emergency remote remains in the garage kitchenette")
check(
	environment and environment:GetAttribute("SimpleGameplayCleanupVersion") == EXPECTED_VERSION,
	"Simple gameplay cleanup marker/version is missing"
)

-- Advanced systems must be absent, including interrupted installer staging.
for _, specification in ipairs({
	{ ReplicatedStorage, "CooperProgression" },
	{ ServerScriptService, "CooperProgression" },
	{ ServerScriptService, "CooperProgressionServerEvents" },
	{ starterScripts, "CooperProgression" },
	{ ReplicatedStorage, "CooperCrisis" },
	{ ServerScriptService, "CooperCrisis" },
	{ ServerScriptService, "CooperCrisisServerEvents" },
	{ starterScripts, "CooperCrisisClient" },
	{ environment, "CooperCrisisWorld" },
	{ Workspace, "CooperFutureApartment" },
}) do
	local parent, name = specification[1], specification[2]
	check(not parent or parent:FindFirstChild(name) == nil, name .. " was not removed")
end

for _, specification in ipairs({
	{ ReplicatedStorage, "_CooperProgression" },
	{ ServerScriptService, "_CooperProgression" },
	{ starterScripts, "_CooperProgression" },
	{ ReplicatedStorage, "_CooperCrisisStage_" },
	{ ServerScriptService, "_CooperCrisisServerStage_" },
	{ starterScripts, "_CooperCrisisClientStage_" },
	{ environment, "_CooperCrisisWorldStage_" },
	{ Workspace, "__CooperFutureApartment_Staging" },
	{ garage, "__CooperTimeMachine_Staging" },
}) do
	check(not hasPrefixChild(specification[1], specification[2]), "Staging object remains with prefix " .. specification[2])
end

-- The task Time Machine itself and all task-owned presentation must remain.
local machine = garage and garage:FindFirstChild("CooperTimeMachine")
check(machine and machine:IsA("Model"), "CooperTimeMachine was not preserved")
local stages = machine and machine:FindFirstChild("Stages")
check(stages and stages:IsA("Folder"), "CooperTimeMachine.Stages was not preserved")
check(stages and #stages:GetChildren() == 11, "Time Machine no longer has exactly 11 visual stages")
if stages then
	for stage = 1, 11 do
		local expectedPrefix = string.format("Stage%02d_", stage)
		local found = false
		for _, child in ipairs(stages:GetChildren()) do
			if string.sub(child.Name, 1, #expectedPrefix) == expectedPrefix then
				found = true
				break
			end
		end
		check(found, "Time Machine visual stage " .. stage .. " is missing")
	end
end
local crt = machine and machine:FindFirstChild("FamilyTaskProgress", true)
check(crt and crt:IsA("SurfaceGui"), "FamilyTaskProgress CRT was not preserved")
local progressLabel = crt and crt:FindFirstChild("Progress")
check(progressLabel and progressLabel:IsA("TextLabel"), "FamilyTaskProgress.Progress label is missing")
check(not machine or machine:FindFirstChild("Controls") == nil, "Advanced Time Machine Controls folder remains")
check(not machine or machine:FindFirstChild("ReactorLights") == nil, "Advanced Time Machine reactor lights remain")
if machine then
	for _, descendant in ipairs(machine:GetDescendants()) do
		check(not descendant:IsA("ProximityPrompt"), "Advanced prompt remains in Time Machine: " .. descendant:GetFullName())
	end
end

-- Family onboarding, interactions, garage, and rideables are untouched.
local familyRoot = ReplicatedStorage:FindFirstChild("CooperGame")
check(familyRoot and familyRoot:IsA("Folder"), "Family task ReplicatedStorage.CooperGame is missing")
check(familyRoot and familyRoot:FindFirstChild("Config"), "Family task Config is missing")
check(familyRoot and familyRoot:FindFirstChild("Remotes"), "Family task Remotes are missing")
local familyState = familyRoot and familyRoot:FindFirstChild("State")
for _, attributeName in ipairs({
	"Mode",
	"Stability",
	"StabilityBand",
	"Chapter",
	"ChapterName",
	"PanicActive",
	"CrisisActive",
	"FinaleActive",
}) do
	check(not familyState or familyState:GetAttribute(attributeName) == nil, "Retired family state remains: " .. attributeName)
end
local familyServer = ServerScriptService:FindFirstChild("CooperGame")
local familyClient = starterScripts and starterScripts:FindFirstChild("CooperGame")
check(familyServer and familyServer:IsA("Script") and familyServer.Enabled, "Family task server is unavailable")
check(familyClient and familyClient:IsA("LocalScript") and familyClient.Enabled, "Family task client is unavailable")

local taskWorld = environment and environment:FindFirstChild("CooperFamilyTaskWorld")
local taskController = ServerScriptService:FindFirstChild("CooperTaskWorld")
check(taskWorld and taskWorld:IsA("Model") and taskWorld:GetAttribute("Ready") == true, "Family task world is unavailable")
check(taskController and taskController:IsA("Script") and taskController.Enabled, "Family task-world controller is unavailable")
check(not environment or environment:FindFirstChild("CooperTaskWorld") == nil, "Obsolete generic task-board world remains")

local interactionWorld = house and house:FindFirstChild("CooperInteractions")
local interactionServer = ServerScriptService:FindFirstChild("CooperInteractions")
local interactionClient = starterScripts and starterScripts:FindFirstChild("CooperInteractions")
check(interactionWorld and interactionWorld:IsA("Model"), "Interior interaction world is missing")
check(interactionServer and interactionServer:IsA("Script") and interactionServer.Enabled, "Interior interaction server is unavailable")
check(interactionClient and interactionClient:IsA("LocalScript") and interactionClient.Enabled, "Interior interaction client is unavailable")

local landscaping = environment and environment:FindFirstChild("Landscaping")
local rideableWorld = landscaping and landscaping:FindFirstChild("CooperYardRideables")
local rideableRemotes = ReplicatedStorage:FindFirstChild("CooperYardRideablesRemotes")
local rideableServer = ServerScriptService:FindFirstChild("CooperYardRideables")
local rideableClient = starterScripts and starterScripts:FindFirstChild("CooperYardRideables")
check(rideableWorld and rideableWorld:IsA("Model"), "Yard rideable world is missing")
check(rideableRemotes and rideableRemotes:IsA("Folder"), "Yard rideable remotes are missing")
check(rideableServer and rideableServer:IsA("Script") and rideableServer.Enabled, "Yard rideable server is unavailable")
check(rideableClient and rideableClient:IsA("LocalScript") and rideableClient.Enabled, "Yard rideable client is unavailable")
check(rideableWorld and rideableWorld:FindFirstChild("CooperRedYellowTrike"), "Front-yard trike is missing")
check(
	rideableWorld and (
		rideableWorld:FindFirstChild("FrontYardTireSwing")
		or rideableWorld:FindFirstChild("FrontYardRopeSwing")
	),
	"Front-yard swing is missing"
)

-- The old panic system may have been replaced by a simple NPC system using the
-- same canonical name. Reject only the advanced markers, never that replacement.
local characterRoot = ReplicatedStorage:FindFirstChild("CooperCharacters")
local characterState = characterRoot and characterRoot:FindFirstChild("State")
check(
	not characterState or characterState:GetAttribute("PanicActive") == nil,
	"Advanced character PanicActive state remains"
)
local characterServer = ServerScriptService:FindFirstChild("CooperCharacters")
local characterClient = starterScripts and starterScripts:FindFirstChild("CooperCharacters")
for _, marker in ipairs({ "beginPanic", "PanicStarted", "capturePlayer", "BrisketCount" }) do
	check(not sourceContains(characterServer, marker), "Advanced character server marker remains: " .. marker)
end
for _, marker in ipairs({ "PanicOverlay", "BrisketControls", "CooperCharacterPanicColor" }) do
	check(not sourceContains(characterClient, marker), "Advanced character client marker remains: " .. marker)
end
local characterWorld = environment and environment:FindFirstChild("CooperCharacters")
if characterWorld then
	for _, name in ipairs({ "PanicStations", "Briskets" }) do
		check(characterWorld:FindFirstChild(name) == nil, "Advanced character world folder remains: " .. name)
	end
end
local advancedCharacterActions = {
	RestorePower = true,
	TakeEmergencyRemote = true,
	TuneFootball = true,
	PrepareDecoy = true,
	ContainGeorge = true,
	MicrowaveRescue = true,
	EmergencySelfRescue = true,
}
if environment then
	for _, descendant in ipairs(environment:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			local action = tostring(descendant:GetAttribute("CooperCharacterAction") or "")
			check(not advancedCharacterActions[action], "Panic action prompt remains: " .. descendant:GetFullName())
		end
	end
end
check(Lighting:FindFirstChild("CooperCharacterPanicColor") == nil, "Panic color correction remains")
for _, guiName in ipairs({ "CooperProgressionHUD", "CooperCrisisHUD", "CooperCharactersHUD" }) do
	check(StarterGui:FindFirstChild(guiName) == nil, "Advanced StarterGui remains: " .. guiName)
end

if #failures > 0 then
	error("[SimpleGameplayAudit] FAIL" .. string.char(10) .. " - " .. table.concat(failures, string.char(10) .. " - "), 0)
end

print(string.format(
	"[SimpleGameplayAudit] PASS: advanced systems absent; house/tasks/interactions/rideables plus %d machine stages and CRT preserved",
	#stages:GetChildren()
))
return true
