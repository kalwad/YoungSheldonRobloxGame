--!nonstrict
-- Idempotent edit-mode cleanup for returning the place to its simple family-task
-- loop. This intentionally does not rebuild or edit any runtime source files.
--
-- Preserved:
--   * Cooper house, detached garage, and garage door
--   * Family task foundation/world and their delivery/install stations
--   * Interior interactions and yard rideables
--   * CooperTimeMachine model, all 11 visual Stages, and FamilyTaskProgress CRT
--
-- Removed:
--   * Advanced progression, crisis, future-apartment, and their staging objects
--   * Advanced Time Machine consoles / prompts
--   * The superseded George-panic controller, HUD, remotes, and world stations
--
-- Run this file in the Studio command bar while the playtest is stopped.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Stop the playtest before running simple_gameplay_cleanup.luau")

local CLEANUP_VERSION = "2026-07-13.simple.1"

local environment = assert(
	Workspace:FindFirstChild("CooperHouseEnvironment"),
	"workspace.CooperHouseEnvironment is missing"
)
assert(environment:IsA("Model"), "CooperHouseEnvironment must be a Model")
local house = assert(environment:FindFirstChild("CooperHouse"), "CooperHouse is missing")
local garage = assert(environment:FindFirstChild("DetachedGarage"), "DetachedGarage is missing")
assert(house:IsA("Model"), "CooperHouse must be a Model")
assert(garage:IsA("Model"), "DetachedGarage must be a Model")

local starterScripts = assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts"),
	"StarterPlayer.StarterPlayerScripts is missing"
)
local machine = assert(garage:FindFirstChild("CooperTimeMachine"), "DetachedGarage.CooperTimeMachine is missing")
assert(machine:IsA("Model"), "CooperTimeMachine must be a Model")
local stages = assert(machine:FindFirstChild("Stages"), "CooperTimeMachine.Stages is missing")
assert(stages:IsA("Folder"), "CooperTimeMachine.Stages must be a Folder")
assert(#stages:GetChildren() == 11, "CooperTimeMachine must have all 11 visual stage folders before cleanup")
local familyTaskProgress = assert(
	machine:FindFirstChild("FamilyTaskProgress", true),
	"CooperTimeMachine FamilyTaskProgress CRT is missing"
)
assert(familyTaskProgress:IsA("SurfaceGui"), "FamilyTaskProgress must be a SurfaceGui")

-- Capture the exact instances that this cleanup is forbidden to replace. The
-- assertions after mutation make an accidental broad deletion fail loudly.
local preserved = {
	environment = environment,
	house = house,
	garage = garage,
	machine = machine,
	stages = stages,
	familyTaskProgress = familyTaskProgress,
	familyRoot = assert(ReplicatedStorage:FindFirstChild("CooperGame"), "ReplicatedStorage.CooperGame is missing"),
	familyServer = assert(ServerScriptService:FindFirstChild("CooperGame"), "ServerScriptService.CooperGame is missing"),
	familyClient = assert(starterScripts:FindFirstChild("CooperGame"), "StarterPlayerScripts.CooperGame is missing"),
	taskWorld = assert(environment:FindFirstChild("CooperFamilyTaskWorld"), "CooperFamilyTaskWorld is missing"),
	taskController = assert(ServerScriptService:FindFirstChild("CooperTaskWorld"), "CooperTaskWorld controller is missing"),
}

-- These are required gameplay systems in the place, but the cleanup also works
-- on a development copy where one has not been installed yet. Any one that is
-- present is identity-checked after cleanup.
preserved.interactionWorld = house:FindFirstChild("CooperInteractions")
preserved.interactionServer = ServerScriptService:FindFirstChild("CooperInteractions")
preserved.interactionClient = starterScripts:FindFirstChild("CooperInteractions")
local landscaping = environment:FindFirstChild("Landscaping")
preserved.rideableWorld = landscaping and landscaping:FindFirstChild("CooperYardRideables")
preserved.rideableRemotes = ReplicatedStorage:FindFirstChild("CooperYardRideablesRemotes")
preserved.rideableServer = ServerScriptService:FindFirstChild("CooperYardRideables")
preserved.rideableClient = starterScripts:FindFirstChild("CooperYardRideables")

local removed = {
	progression = 0,
	crisis = 0,
	future = 0,
	timeMachineControls = 0,
	panic = 0,
	staging = 0,
	presentation = 0,
}

local function remove(instance, bucket)
	if not instance or not instance.Parent then
		return false
	end
	if instance:IsA("BaseScript") then
		instance.Enabled = false
	end
	instance:Destroy()
	removed[bucket] += 1
	return true
end

local function removeNamed(parent, name, bucket)
	if not parent then
		return false
	end
	return remove(parent:FindFirstChild(name), bucket)
end

local function removeChildrenWithPrefix(parent, prefix, bucket)
	if not parent then
		return
	end
	for _, child in ipairs(parent:GetChildren()) do
		if string.sub(child.Name, 1, #prefix) == prefix then
			remove(child, bucket)
		end
	end
end

local function scriptHasAnyMarker(candidate, markers)
	if not candidate or not candidate:IsA("LuaSourceContainer") then
		return false
	end
	local source = ""
	local readable = pcall(function()
		source = candidate.Source
	end)
	if not readable then
		return false
	end
	for _, marker in ipairs(markers) do
		if string.find(source, marker, 1, true) then
			return true
		end
	end
	return false
end

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"ReturnToSimpleCooperGameplay",
		"Remove unrequested progression, crisis, and panic systems"
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
			ChangeHistoryService:SetWaypoint("Returned Cooper game to simple family tasks")
		end)
	end
end

local ok, failure = xpcall(function()
	-- Advanced Time Machine progression runtime.
	removeNamed(ReplicatedStorage, "CooperProgression", "progression")
	removeNamed(ServerScriptService, "CooperProgression", "progression")
	removeNamed(ServerScriptService, "CooperProgressionServerEvents", "progression")
	removeNamed(starterScripts, "CooperProgression", "progression")
	removeChildrenWithPrefix(ReplicatedStorage, "_CooperProgression", "staging")
	removeChildrenWithPrefix(ServerScriptService, "_CooperProgression", "staging")
	removeChildrenWithPrefix(starterScripts, "_CooperProgression", "staging")

	-- Tornado, D.E.S., reactor-chaos, and finale runtime/world presentation.
	removeNamed(ReplicatedStorage, "CooperCrisis", "crisis")
	removeNamed(ServerScriptService, "CooperCrisis", "crisis")
	removeNamed(ServerScriptService, "CooperCrisisServerEvents", "crisis")
	removeNamed(starterScripts, "CooperCrisisClient", "crisis")
	removeNamed(environment, "CooperCrisisWorld", "crisis")
	removeChildrenWithPrefix(ReplicatedStorage, "_CooperCrisisStage_", "staging")
	removeChildrenWithPrefix(ServerScriptService, "_CooperCrisisServerStage_", "staging")
	removeChildrenWithPrefix(starterScripts, "_CooperCrisisClientStage_", "staging")
	removeChildrenWithPrefix(environment, "_CooperCrisisWorldStage_", "staging")

	-- Obsolete generic task-board world from the superseded expansion. The
	-- requested onboarding world is CooperFamilyTaskWorld (preserved above).
	removeNamed(environment, "CooperTaskWorld", "panic")

	-- Finale-only world and any interrupted installer staging models.
	removeNamed(Workspace, "CooperFutureApartment", "future")
	removeChildrenWithPrefix(Workspace, "__CooperFutureApartment_Staging", "staging")
	removeChildrenWithPrefix(garage, "__CooperTimeMachine_Staging", "staging")
	local livingUpgrade = garage:FindFirstChild("GeorgieMandyLivingUpgrade_V1")
	removeNamed(livingUpgrade, "StormEquipmentBay", "crisis")
	removeNamed(garage, "GarageLivingArea", "panic")
	removeNamed(garage, "GarageLivingAreaRef", "panic")
	if livingUpgrade then
		livingUpgrade:SetAttribute("GarageLivingArea", nil)
		local kitchenette = livingUpgrade:FindFirstChild("CompactKitchenette")
		removeNamed(kitchenette, "Remote", "panic")
	end

	-- Preserve the actual Time Machine and task-owned stage/CRT presentation.
	-- Only the advanced shop/reactor/calibration/launch control bank is removed.
	removeNamed(machine, "Controls", "timeMachineControls")
	removeNamed(machine, "ReactorLights", "timeMachineControls")
	for _, descendant in ipairs(machine:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			remove(descendant, "timeMachineControls")
		end
	end
	machine:SetAttribute("ReactorMode", nil)
	machine:SetAttribute("ReactorLockedUntil", nil)
	machine:SetAttribute("SimpleTaskLoop", true)

	-- Remove only the superseded *advanced* CooperCharacters controller. This is
	-- marker-based so rerunning cleanup after a simple NPC replacement will not
	-- delete that replacement. Static NPC artwork is deliberately left for the
	-- simple character installer to retain or replace independently.
	local characterRoot = ReplicatedStorage:FindFirstChild("CooperCharacters")
	local purpose = characterRoot and tostring(characterRoot:GetAttribute("Purpose") or "") or ""
	local characterState = characterRoot and characterRoot:FindFirstChild("State")
	local advancedCharacterRoot = characterRoot ~= nil and (
		string.find(string.lower(purpose), "panic", 1, true) ~= nil
		or (characterState ~= nil and characterState:GetAttribute("PanicActive") ~= nil)
	)
	if advancedCharacterRoot then
		remove(characterRoot, "panic")
	end

	local characterServer = ServerScriptService:FindFirstChild("CooperCharacters")
	local advancedCharacterServer = scriptHasAnyMarker(characterServer, {
		"beginPanic",
		"PanicStarted",
		"BrisketCount",
		"capturePlayer",
	})
	if advancedCharacterServer then
		remove(characterServer, "panic")
	end

	local characterClient = starterScripts:FindFirstChild("CooperCharacters")
	local advancedCharacterClient = scriptHasAnyMarker(characterClient, {
		"PanicOverlay",
		"BrisketControls",
		"PanicStarted",
		"CooperCharacterPanicColor",
	})
	if advancedCharacterClient then
		remove(characterClient, "panic")
	end

	if advancedCharacterRoot or advancedCharacterServer or advancedCharacterClient
		or (not characterRoot and not characterServer and not characterClient)
	then
		removeNamed(ServerScriptService, "CooperCharacterServerEvents", "panic")
	end

	local characterWorld = environment:FindFirstChild("CooperCharacters")
	if characterWorld then
		local oldAdvancedWorld = characterWorld:GetAttribute("RuntimeOwned") == true
			or characterWorld:FindFirstChild("PanicStations") ~= nil
		for _, folderName in ipairs({ "PanicStations", "Briskets" }) do
			removeNamed(characterWorld, folderName, "panic")
		end
		-- Waypoints are not inherently a panic feature. Remove them only from the
		-- known superseded runtime; a later simple NPC mover may legitimately use
		-- its own folder with this name.
		if oldAdvancedWorld then
			removeNamed(characterWorld, "Waypoints", "panic")
		end
		characterWorld:SetAttribute("RuntimeOwned", nil)
		characterWorld:SetAttribute("PanicFeaturesRemoved", true)
	end
	-- Catch an interrupted character install without touching a future simple
	-- system using the canonical CooperCharacters name.
	for _, parent in ipairs({ ReplicatedStorage, environment, ServerScriptService, starterScripts }) do
		removeNamed(parent, "CooperCharacters_Installing", "staging")
		removeNamed(parent, "CooperCharacters_PreviousInstall", "staging")
	end

	-- Attribute-scoped sweep for a panic station that may have escaped its
	-- folder. A future simple Talk prompt using another action is preserved.
	local advancedCharacterActions = {
		RestorePower = true,
		TakeEmergencyRemote = true,
		TuneFootball = true,
		PrepareDecoy = true,
		ContainGeorge = true,
		MicrowaveRescue = true,
		EmergencySelfRescue = true,
	}
	for _, descendant in ipairs(environment:GetDescendants()) do
		if descendant:IsA("ProximityPrompt")
			and advancedCharacterActions[tostring(descendant:GetAttribute("CooperCharacterAction") or "")]
		then
			remove(descendant, "panic")
		end
	end

	-- Edit-mode leftovers and authored presentation objects with exact names.
	for _, guiName in ipairs({ "CooperProgressionHUD", "CooperCrisisHUD", "CooperCharactersHUD" }) do
		removeNamed(StarterGui, guiName, "presentation")
	end
	removeNamed(Lighting, "CooperCharacterPanicColor", "presentation")
	for _, soundName in ipairs({ "TornadoWind", "CrisisAlert", "ChaosStinger", "PanicWarningAudio" }) do
		removeNamed(SoundService, soundName, "presentation")
	end

	-- Leave the shared family state in the ordinary onboarding loop. This does
	-- not modify Config or any profile/runtime source; it only clears stale edit
	-- state left by a stopped advanced playtest.
	local familyState = preserved.familyRoot:FindFirstChild("State")
	if familyState then
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
			familyState:SetAttribute(attributeName, nil)
		end
	end

	-- Preservation contract.
	assert(Workspace:FindFirstChild("CooperHouseEnvironment") == preserved.environment, "Environment was replaced")
	assert(environment:FindFirstChild("CooperHouse") == preserved.house, "House was replaced")
	assert(environment:FindFirstChild("DetachedGarage") == preserved.garage, "Garage was replaced")
	assert(garage:FindFirstChild("CooperTimeMachine") == preserved.machine, "Time Machine was replaced")
	assert(machine:FindFirstChild("Stages") == preserved.stages, "Time Machine stages were replaced")
	assert(#preserved.stages:GetChildren() == 11, "Cleanup removed a Time Machine stage")
	assert(machine:FindFirstChild("FamilyTaskProgress", true) == preserved.familyTaskProgress, "CRT progress was replaced")
	assert(ReplicatedStorage:FindFirstChild("CooperGame") == preserved.familyRoot, "Family root was replaced")
	assert(ServerScriptService:FindFirstChild("CooperGame") == preserved.familyServer, "Family server was replaced")
	assert(starterScripts:FindFirstChild("CooperGame") == preserved.familyClient, "Family client was replaced")
	assert(environment:FindFirstChild("CooperFamilyTaskWorld") == preserved.taskWorld, "Family task world was replaced")
	assert(ServerScriptService:FindFirstChild("CooperTaskWorld") == preserved.taskController, "Task controller was replaced")

	if preserved.interactionWorld then
		assert(house:FindFirstChild("CooperInteractions") == preserved.interactionWorld, "Interaction world was replaced")
	end
	if preserved.interactionServer then
		assert(ServerScriptService:FindFirstChild("CooperInteractions") == preserved.interactionServer, "Interaction server was replaced")
	end
	if preserved.interactionClient then
		assert(starterScripts:FindFirstChild("CooperInteractions") == preserved.interactionClient, "Interaction client was replaced")
	end
	if preserved.rideableWorld then
		assert(landscaping:FindFirstChild("CooperYardRideables") == preserved.rideableWorld, "Yard rideables were replaced")
	end
	if preserved.rideableRemotes then
		assert(ReplicatedStorage:FindFirstChild("CooperYardRideablesRemotes") == preserved.rideableRemotes, "Rideable remotes were replaced")
	end
	if preserved.rideableServer then
		assert(ServerScriptService:FindFirstChild("CooperYardRideables") == preserved.rideableServer, "Rideable server was replaced")
	end
	if preserved.rideableClient then
		assert(starterScripts:FindFirstChild("CooperYardRideables") == preserved.rideableClient, "Rideable client was replaced")
	end

	environment:SetAttribute("SimpleGameplayCleanupVersion", CLEANUP_VERSION)
end, function(message)
	return debug.traceback(tostring(message), 2)
end)

finishRecording(ok)
if not ok then
	error(failure, 0)
end

local totalRemoved = 0
for _, count in pairs(removed) do
	totalRemoved += count
end

print(string.format(
	"[SimpleGameplayCleanup] PASS %s: removed %d advanced objects; preserved house, garage, tasks, interactions, rideables, 11 stages, and CRT",
	CLEANUP_VERSION,
	totalRemoved
))

return {
	version = CLEANUP_VERSION,
	totalRemoved = totalRemoved,
	removed = removed,
	machineStages = #stages:GetChildren(),
	crtPreserved = familyTaskProgress.Parent ~= nil,
}
