--!nonstrict
-- Edit-mode smoke audit for the complete Cooper house realism/interaction pass.
-- Safe to run repeatedly from Studio's command bar or an MCP edit target.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	assert(child, string.format("Missing %s.%s", parent and parent:GetFullName() or "nil", name))
	if className then
		assert(child:IsA(className), child:GetFullName() .. " must be a " .. className)
	end
	return child
end

local function requireLiveSource(container, name, className)
	local scriptObject = requireChild(container, name, className)
	assert(not scriptObject.Disabled, scriptObject:GetFullName() .. " is disabled")
	assert(#scriptObject.Source > 500, scriptObject:GetFullName() .. " has placeholder/empty source")
	assert(not string.find(scriptObject.Source, "Source is installed from", 1, true), scriptObject:GetFullName() .. " still has placeholder source")
	return scriptObject
end

local environment = requireChild(workspace, "CooperHouseEnvironment", "Model")
local house = requireChild(environment, "CooperHouse", "Model")
local structure = requireChild(house, "Structure", "Model")
local furniture = requireChild(house, "FurnitureAndProps", "Model")

local roofClosure = requireChild(structure, "RealisticRoofClosure_V1", "Model")
assert(#roofClosure:GetDescendants() >= 20, "Roof closure is unexpectedly incomplete")
assert(roofClosure:FindFirstChild("LeftFrontGableInfill"), "Left house gable is not closed")
assert(roofClosure:FindFirstChild("RightBackGableInfill"), "Right house gable is not closed")

local garage = requireChild(environment, "DetachedGarage", "Model")
local living = requireChild(garage, "GeorgieMandyLivingUpgrade_V1", "Model")
-- The expanded-garage layout deliberately replaced the older, overpacked
-- conversion with a roomier 25-descendant version so the bed, kitchenette,
-- storm bay, and garage door all have usable clearance.
assert(#living:GetDescendants() >= 20, "Georgie and Mandy living conversion is incomplete")
requireChild(living, "CompactKitchenette", "Model")
requireChild(living, "GeorgieMandyBedNook", "Model")
requireChild(living, "CeeCeeBassinet", "Model")
requireChild(living, "PlaidSleeperCouch", "Model")

local garageDoor = requireChild(garage, "InteractiveSectionalGarageDoor", "Model")
local panels = requireChild(garageDoor, "Panels", "Folder")
local garageFoundation = requireChild(garage, "GarageFoundation", "BasePart")
local garageHeader = requireChild(garage, "GarageDoorHeader", "BasePart")
local collisionBlocker = requireChild(garageDoor, "CollisionBlocker", "BasePart")
assert(math.abs(collisionBlocker.Position.X - garageHeader.Position.X) < 0.25, "Garage door is not centered on its opening")
assert(math.abs(collisionBlocker.Position.Z - garageHeader.Position.Z) < 2, "Garage door is not aligned to the front opening")
local panelCount = 0
for _, panel in ipairs(panels:GetChildren()) do
	if panel:IsA("BasePart") then
		panelCount += 1
		local closedPose = requireChild(panel, "ClosedPose", "CFrameValue")
		requireChild(panel, "OpenPose", "CFrameValue")
		assert(math.abs(closedPose.Value.Position.X - garageHeader.Position.X) < 0.25, panel.Name .. " closed pose is off-center")
		assert(math.abs(closedPose.Value.Position.Z - garageHeader.Position.Z) < 2, panel.Name .. " closed pose is off the opening")
	end
end
assert(panelCount == 6, string.format("Expected 6 garage panels, found %d", panelCount))
requireChild(requireChild(garageDoor, "PromptMount", "BasePart"), "ProximityPrompt", "ProximityPrompt")
local garageController = requireLiveSource(garageDoor, "GeorgieGarageDoorController", "Script")
for _, structuralName in ipairs({ "FrontLeftInteriorReturn", "FrontRightInteriorReturn" }) do
	assert(
		string.find(garageController.Source, '"' .. structuralName .. '"', 1, true),
		"Garage obstruction sweep does not ignore its own " .. structuralName
	)
end
assert(
	string.find(garageController.Source, "doorModel.Parent:FindFirstChild(name, true)", 1, true),
	"Garage obstruction ignore list does not search the nested living conversion"
)

local interactionRoot = requireChild(house, "CooperInteractions", "Model")
assert(interactionRoot:GetAttribute("InstallerVersion") == 2, "Wrong interior interaction installer version")
local bathroom = requireChild(interactionRoot, "BathroomInteractions", "Model")
requireChild(bathroom, "ToiletSeat", "Seat")
requireChild(bathroom, "ShowerUseAnchor", "BasePart")
requireChild(bathroom, "SinkUseAnchor", "BasePart")
requireChild(bathroom, "ToiletFlushSwirl", "BasePart")
local toiletEffect = requireChild(bathroom, "ToiletWaterEffect", "BasePart")
local flushSound = requireChild(toiletEffect, "CooperToiletFlushSound", "Sound")
assert(flushSound.SoundId == interactionRoot:GetAttribute("ToiletFlushSoundId"), "Toilet flush sound/config mismatch")
assert(flushSound.SoundId == "rbxassetid://9125499039", "Unexpected default toilet flush sound")
local showerBeamCount = 0
local sinkBeamCount = 0
for _, descendant in ipairs(bathroom:GetDescendants()) do
	if descendant:IsA("Beam") and descendant:GetAttribute("CooperShowerBeam") == true then
		showerBeamCount += 1
		assert(descendant.Attachment0 and descendant.Attachment1, descendant:GetFullName() .. " is not attached")
	elseif descendant:IsA("Beam") and descendant:GetAttribute("CooperSinkBeam") == true then
		sinkBeamCount += 1
		assert(descendant.Attachment0 and descendant.Attachment1, descendant:GetFullName() .. " is not attached")
	end
end
assert(showerBeamCount >= 7, "Visible shower Beam layer is incomplete")
assert(sinkBeamCount >= 1, "Visible sink Beam layer is incomplete")
local showerWater = requireChild(bathroom, "ShowerWater", "BasePart")
local showerSound = requireChild(showerWater, "CooperShowerWaterSound", "Sound")
assert(showerSound.Looped and showerSound.SoundId ~= "", "Shower water audio is missing")
assert(not furniture:FindFirstChild("KitchenDinetteChairA"), "Kitchen chair still blocks the refrigerator")

local taskWorld = requireChild(environment, "CooperFamilyTaskWorld", "Model")
assert(taskWorld:GetAttribute("InstallVersion") == "2026-07-21.hackerbot.1", "Family task world installer is stale")
assert(taskWorld:GetAttribute("StationCount") == 13, "Family task world does not expose all thirteen stations")
local taskVisuals = requireChild(taskWorld, "TaskVisuals", "Folder")
local dirtyDishes = requireChild(taskVisuals, "DirtyDishesInSink", "Model")
assert(dirtyDishes:GetAttribute("FamilyTaskVisual") == "MaryDishes", "Sink dishes are not connected to Mary's task")
local dirtyDishCount = 0
for _, descendant in ipairs(dirtyDishes:GetDescendants()) do
	if descendant:IsA("BasePart") then
		dirtyDishCount += 1
		assert(descendant.Anchored and not descendant.CanCollide, descendant.Name .. " has unsafe dish physics")
	end
end
assert(dirtyDishCount == 15, "The sink does not contain the complete dirty-dish set")

local incomeBoombox = requireChild(taskVisuals, "CooperIncomeBoombox", "Model")
assert(incomeBoombox.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Income boombox does not stream atomically")
assert(incomeBoombox:GetAttribute("PlacementFurniture") == "FormalSofaEndTable.Top", "Income boombox is not attached to the formal living-room end table")
local boomboxSound = requireChild(requireChild(incomeBoombox, "AudioEmitter", "BasePart"), "BoomboxSound", "Sound")
assert(boomboxSound.SoundId == "rbxassetid://86759598635831", "Income boombox uses the wrong Creator Dashboard audio")
assert(not boomboxSound.Looped and boomboxSound.PlaybackSpeed == 1, "Income boombox playback configuration is unsafe")
local boomboxPartCount = 0
local boomboxLightCount = 0
for _, descendant in ipairs(incomeBoombox:GetDescendants()) do
	if descendant:IsA("BasePart") then
		boomboxPartCount += 1
	elseif descendant:IsA("Light") then
		boomboxLightCount += 1
	end
end
assert(boomboxPartCount >= 50, "Income boombox visual assembly is incomplete")
assert(boomboxLightCount == 5, "Income boombox must have four disco spots and one room wash")
local taskStations = requireChild(taskWorld, "Stations", "Folder")
for anchorName, action in pairs({
	BoomboxSetupAnchor = "BoomboxSetup",
	BoomboxPowerAnchor = "BoomboxPower",
}) do
	local anchor = requireChild(taskStations, anchorName, "BasePart")
	local prompt = requireChild(anchor, "TaskPrompt", "ProximityPrompt")
	assert(prompt:GetAttribute("FamilyTaskAction") == action, anchorName .. " has the wrong action")
end

local expectedPickables = {
	requireChild(requireChild(requireChild(furniture, "YoungSheldonBedroomDetails_V2", "Model"), "SheldonAndMissyRoom", "Model"), "MissyDetailedTeddyBear", "Model"),
	furniture.YoungSheldonBedroomDetails_V2.SheldonAndMissyRoom.MissyDetailedRabbit,
	furniture.YoungSheldonBedroomDetails_V2.GeorgieRoomStoryProps.GeorgieFootballInteractive,
	furniture.YoungSheldonStoryDetails_V2.CharacterDeepCuts.SheldonPuzzleCubeInteractive,
}
for _, pickable in ipairs(expectedPickables) do
	assert(pickable and pickable:GetAttribute("CooperPickable") == true, tostring(pickable) .. " is not pickable")
	assert(pickable.PrimaryPart and pickable.PrimaryPart.Name == "InteractionHandle", pickable:GetFullName() .. " has no interaction handle")
end

local actionCounts = {}
local actionPromptCount = 0
for _, descendant in ipairs(house:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") then
		local action = descendant:GetAttribute("CooperAction")
		if type(action) == "string" then
			actionPromptCount += 1
			actionCounts[action] = (actionCounts[action] or 0) + 1
		end
	end
end
for _, action in ipairs({
	"Pickup",
	"CubePuzzle",
	"ToiletSit",
	"ToiletFlush",
	"ShowerToggle",
	"ShowerUse",
	"SinkWash",
	"BrushTeeth",
	"Computer",
	"FridgeToggle",
	"FridgeBeer",
}) do
	assert(actionCounts[action], "Missing ProximityPrompt action " .. action)
end

local fridge = requireChild(furniture, "WhiteHotpointRefrigerator", "Model")
local fridgeBody = requireChild(fridge, "RefrigeratorBody", "BasePart")
local fridgeDoor = requireChild(fridge, "CooperFridgeDoorAssembly", "Model")
local fridgeHinge = requireChild(fridgeDoor, "FridgeDoorHinge", "BasePart")
local fridgePanel = requireChild(fridgeDoor, "FridgeDoorPanel", "BasePart")
local positiveClearance = fridgeHinge:GetAttribute("PositiveSideClearance")
local negativeClearance = fridgeHinge:GetAttribute("NegativeSideClearance")
local hingeSide = fridgeHinge:GetAttribute("DerivedHingeSide")
assert(type(positiveClearance) == "number" and type(negativeClearance) == "number", "Fridge wall clearance survey missing")
assert(hingeSide == (positiveClearance <= negativeClearance and 1 or -1), "Fridge hinge is not on the wall/low-clearance side")
local handle = fridgeDoor:FindFirstChild("ChromeHandle") or fridgeDoor:FindFirstChild("FridgeDoorHandle")
assert(handle and handle:IsA("BasePart"), "Fridge door handle is missing")
assert(math.sign(fridgeBody.CFrame:PointToObjectSpace(handle.Position).X) == -hingeSide, "Fridge handle is not on the open/free edge")
local closedFridgePose = fridgeHinge:GetAttribute("ClosedCFrame")
local openFridgeAngle = fridgeHinge:GetAttribute("DerivedOpenAngleDegrees")
assert(typeof(closedFridgePose) == "CFrame" and type(openFridgeAngle) == "number", "Fridge door poses are missing")
assert((closedFridgePose.Position - fridgeHinge.Position).Magnitude < 0.05, "Fridge closed pose uses stale world coordinates")
assert((fridgePanel.Position - fridgeBody.Position).Magnitude < 5, "Fridge door is detached from the appliance")
assert(math.abs(openFridgeAngle) <= 90, "Fridge door curls back toward its adjacent wall")
local panelEdgeA = fridgePanel.Position + fridgePanel.CFrame.RightVector * fridgePanel.Size.X * 0.5
local panelEdgeB = fridgePanel.Position - fridgePanel.CFrame.RightVector * fridgePanel.Size.X * 0.5
local closedFreeEdge = if (panelEdgeA - fridgeHinge.Position).Magnitude >= (panelEdgeB - fridgeHinge.Position).Magnitude
	then panelEdgeA
	else panelEdgeB
local openFreeEdge = (closedFridgePose * CFrame.Angles(0, math.rad(openFridgeAngle), 0)):PointToWorldSpace(
	closedFridgePose:PointToObjectSpace(closedFreeEdge)
)
local kitchenWall = requireChild(requireChild(house, "InteriorRooms", "Model"), "KitchenFruitWallpaper", "BasePart")
local wallLocalPoint = kitchenWall.CFrame:PointToObjectSpace(openFreeEdge)
local wallHalfSize = kitchenWall.Size * 0.5
local nearestWallPoint = Vector3.new(
	math.clamp(wallLocalPoint.X, -wallHalfSize.X, wallHalfSize.X),
	math.clamp(wallLocalPoint.Y, -wallHalfSize.Y, wallHalfSize.Y),
	math.clamp(wallLocalPoint.Z, -wallHalfSize.Z, wallHalfSize.Z)
)
assert((wallLocalPoint - nearestWallPoint).Magnitude >= 1.5, "Open fridge free edge is still too close to the wall")
local fridgeInterior = requireChild(fridge, "CooperFridgeInterior", "Model")
for index = 1, 6 do
	requireChild(fridgeInterior, string.format("BeerBottle%02d_Body", index), "BasePart")
	requireChild(fridgeInterior, string.format("BeerBottle%02d_Neck", index), "BasePart")
	requireChild(fridgeInterior, string.format("BeerBottle%02d_Cap", index), "BasePart")
	requireChild(fridgeInterior, string.format("BeerBottle%02d_Label", index), "BasePart")
end

local interactionRemotes = requireChild(ReplicatedStorage, "CooperInteractionsRemotes", "Folder")
requireChild(interactionRemotes, "Request", "RemoteEvent")
requireChild(interactionRemotes, "Client", "RemoteEvent")
local interactionServer = requireLiveSource(ServerScriptService, "CooperInteractions", "Script")
local interactionClient = requireLiveSource(StarterPlayer.StarterPlayerScripts, "CooperInteractions", "LocalScript")
for _, marker in ipairs({
	"CubeGiveUpThrow",
	"throwLoosePickable",
	"Lone Star Beer Bottle",
	"Instance.new(\"IKControl\")",
	"findRigMotor(character, \"Right Shoulder\")",
	"TimePosition = 0",
	"reportAuthoritativeAction",
	"CooperComputerPrioritySuppressed",
	"kind = \"TerminalOpen\"",
	"refrigeratorDoorObstruction",
	"Fridge blocked",
}) do
	assert(string.find(interactionServer.Source, marker, 1, true), "Interaction server is missing " .. marker)
end
for _, marker in ipairs({
	'"GIVE UP"',
	"CubeGiveUpThrow",
	"GuiService.SelectedObject",
	"Enum.KeyCode.ButtonB",
	"Enum.KeyCode.ButtonX",
	"Enum.KeyCode.ButtonY",
	"updateHeldInputHints",
	"externalModalVisible",
}) do
	assert(string.find(interactionClient.Source, marker, 1, true), "Interaction client is missing " .. marker)
end
assert(not string.find(interactionClient.Source, "GIVE UP & THROW", 1, true), "Cube button still promises GIVE UP & THROW")

local landscaping = requireChild(environment, "Landscaping", "Model")
local rideables = requireChild(landscaping, "CooperYardRideables", "Model")
assert(rideables:GetAttribute("InstallVersion") == "2.3.0", "Wrong yard rideables installer version")
local swing = rideables:FindFirstChild("FrontYardTireSwing") or rideables:FindFirstChild("FrontYardRopeSwing")
assert(swing and swing:IsA("Model"), "Functional front-yard swing is missing")
requireChild(swing, "SwingSeat", "Seat")
assert(#swing:GetChildren() >= 20, "Visible tire/rope swing assembly is incomplete")
local trike = requireChild(rideables, "CooperRedYellowTrike", "Model")
assert(trike:GetAttribute("MotionMode") == "ServerKinematicGroundFollower", "Trike is not using terrain-aware server motion")
assert(trike:GetAttribute("ObstacleSweepVersion") == 1, "Trike obstacle sweep is not installed")
local trikeChassis = requireChild(trike, "Chassis", "BasePart")
requireChild(trike, "TrikeSeat", "VehicleSeat")
assert(not trikeChassis.CanCollide, "Trike chassis can still snag terrain seams")
assert(trikeChassis.CustomPhysicalProperties and trikeChassis.CustomPhysicalProperties.Friction < 0.3, "Trike chassis friction is too high to drive")
local trikeCollisionProxy = requireChild(trike, "PlayerCollisionProxy", "BasePart")
assert(trike:GetAttribute("PlayerCollisionProxyVersion") == 1, "Trike player collision proxy version is stale")
assert(trikeCollisionProxy:GetAttribute("PlayerCollisionProxyVersion") == 1, "Trike player collision proxy is stale")
assert(trikeCollisionProxy.CanCollide, "Players can still walk through the trike")
assert(trikeCollisionProxy.CanQuery and not trikeCollisionProxy.CanTouch, "Trike player collision proxy query/touch settings are unsafe")
assert(trikeCollisionProxy.Transparency == 1 and not trikeCollisionProxy.CastShadow, "Trike player collision proxy must remain invisible")
assert(trikeCollisionProxy.Massless, "Trike player collision proxy must not alter ride motion")
local proxyWeldedToChassis = false
for _, descendant in ipairs(trike:GetDescendants()) do
	if descendant:IsA("WeldConstraint")
		and ((descendant.Part0 == trikeChassis and descendant.Part1 == trikeCollisionProxy)
			or (descendant.Part1 == trikeChassis and descendant.Part0 == trikeCollisionProxy))
	then
		proxyWeldedToChassis = true
		break
	end
end
assert(proxyWeldedToChassis, "Trike player collision proxy is not welded to the chassis")
local rideableRemotes = requireChild(ReplicatedStorage, "CooperYardRideablesRemotes", "Folder")
requireChild(rideableRemotes, "RideablesEvent", "RemoteEvent")
local rideableServer = requireLiveSource(ServerScriptService, "CooperYardRideables", "Script")
for _, marker in ipairs({
	"CONTROLLER_VERSION = \"2.3.0\"",
	"firstObstacleBetween",
	"ObstacleBlocked",
	"RespectCanCollide",
	"trikeCollisionProxy",
	"NoCollisionConstraint",
	"descendant.CanCollide = descendant == trikeCollisionProxy",
	"swingResetGeneration",
	"swingSeat.Disabled = true",
}) do
	assert(string.find(rideableServer.Source, marker, 1, true), "Rideable server is missing " .. marker)
end
local rideableClient = requireLiveSource(StarterPlayer.StarterPlayerScripts, "CooperYardRideables", "LocalScript")
assert(string.find(rideableClient.Source, "hudClearance", 1, true), "Touch ride hint is not cleared below the family HUD")
assert(string.find(rideableClient.Source, "hint.AnchorPoint = Vector2.new(0, 0)", 1, true), "Touch ride hint is not kept between the task HUD and ride controls")
assert(string.find(rideableClient.Source, "TOUCH_BUTTON_SIZE = 56", 1, true), "Rideable touch controls are smaller than the audited mobile target")
assert(string.find(rideableClient.Source, "ContextActionService:GetButton", 1, true), "Rideable touch controls are not restyled for phone readability")

print(string.format(
	"[CooperInstallAudit] PASS: %d prompts, %d roof descendants, %d garage-living descendants, %d door panels",
	actionPromptCount,
	#roofClosure:GetDescendants(),
	#living:GetDescendants(),
	panelCount
))

return true
