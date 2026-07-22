-- Edit-mode installer for the personal Cooper family task world.
-- Run after the house, bedroom rebuild, interactions, and time machine installers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment is missing")
local house = environment:FindFirstChild("CooperHouse")
assert(house and house:IsA("Model"), "CooperHouse is missing")
local furniture = house:FindFirstChild("FurnitureAndProps")
local interiorRooms = house:FindFirstChild("InteriorRooms")
assert(furniture and furniture:IsA("Model"), "CooperHouse.FurnitureAndProps is missing")
assert(interiorRooms and interiorRooms:IsA("Model"), "CooperHouse.InteriorRooms is missing")
local kitchenFloor = interiorRooms:FindFirstChild("KitchenPatternLinoleum")
local kitchenSink = furniture:FindFirstChild("DoublePorcelainSink")
local leftSinkBasin = furniture:FindFirstChild("LeftSinkBasin")
local rightSinkBasin = furniture:FindFirstChild("RightSinkBasin")
local refrigerator = furniture:FindFirstChild("WhiteHotpointRefrigerator")
local formalSofa = furniture:FindFirstChild("FormalGreenFloralSofa")
local formalSofaEndTable = furniture:FindFirstChild("FormalSofaEndTable")
local formalSofaEndTableTop = formalSofaEndTable and formalSofaEndTable:FindFirstChild("Top")
local formalLivingCarpet = interiorRooms:FindFirstChild("FormalLivingOatmealCarpet")
local diningTable = furniture:FindFirstChild("CooperDiningTable")
local diningTableTop = diningTable and diningTable:FindFirstChild("Top")
assert(kitchenFloor and kitchenFloor:IsA("BasePart"), "KitchenPatternLinoleum is missing")
assert(kitchenSink and kitchenSink:IsA("BasePart"), "DoublePorcelainSink is missing")
assert(leftSinkBasin and leftSinkBasin:IsA("BasePart"), "LeftSinkBasin is missing")
assert(rightSinkBasin and rightSinkBasin:IsA("BasePart"), "RightSinkBasin is missing")
assert(refrigerator and refrigerator:IsA("Model"), "WhiteHotpointRefrigerator is missing")
assert(formalSofa and formalSofa:IsA("Model"), "FormalGreenFloralSofa is missing")
assert(formalSofaEndTable and formalSofaEndTable:IsA("Model"), "FormalSofaEndTable is missing")
assert(formalSofaEndTableTop and formalSofaEndTableTop:IsA("BasePart"), "FormalSofaEndTable.Top is missing")
assert(formalLivingCarpet and formalLivingCarpet:IsA("BasePart"), "FormalLivingOatmealCarpet is missing")
assert(diningTable and diningTable:IsA("Model"), "CooperDiningTable is missing")
assert(diningTableTop and diningTableTop:IsA("BasePart"), "CooperDiningTable.Top is missing")

-- Absolute CFrame attributes and CFrameValue objects do not follow when an
-- ancestor Model is translated with Studio's move tools. Rebase every active
-- reset/door pose from the physical objects that did move before rebuilding
-- task markers around them. This keeps this installer safe to rerun after the
-- house or detached garage is repositioned.
local function repairStatefulDoor(door, fallbackSwingDegrees, promptAnchorName)
	if not (door and door:IsA("Model")) then
		return
	end
	local currentPivot = door:GetPivot()
	local closedPivot = door:GetAttribute("ClosedPivot")
	local openPivot = door:GetAttribute("OpenPivot")
	local isOpen = door:GetAttribute("IsOpen") == true
	local expectedPivot = if isOpen then openPivot else closedPivot
	if typeof(closedPivot) ~= "CFrame" or typeof(openPivot) ~= "CFrame" then
		local swing = math.rad(fallbackSwingDegrees)
		if isOpen then
			openPivot = currentPivot
			closedPivot = currentPivot * CFrame.Angles(0, -swing, 0)
		else
			closedPivot = currentPivot
			openPivot = currentPivot * CFrame.Angles(0, swing, 0)
		end
	elseif typeof(expectedPivot) ~= "CFrame"
		or (expectedPivot.Position - currentPivot.Position).Magnitude > 0.05
	then
		local closedToOpen = closedPivot:ToObjectSpace(openPivot)
		local openToClosed = openPivot:ToObjectSpace(closedPivot)
		if isOpen then
			openPivot = currentPivot
			closedPivot = currentPivot * openToClosed
		else
			closedPivot = currentPivot
			openPivot = currentPivot * closedToOpen
		end
	end
	door:SetAttribute("ClosedPivot", closedPivot)
	door:SetAttribute("OpenPivot", openPivot)
	local promptAnchor = door.Parent and door.Parent:FindFirstChild(promptAnchorName)
	local prompt = promptAnchor and promptAnchor:FindFirstChild("DoorPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ActionText = if isOpen then "Close Door" else "Open Door"
	end
end

do
	local doorAssembly = refrigerator:FindFirstChild("CooperFridgeDoorAssembly")
	local fridgeHinge = doorAssembly and doorAssembly:FindFirstChild("FridgeDoorHinge")
	if fridgeHinge and fridgeHinge:IsA("BasePart") then
		fridgeHinge:SetAttribute("ClosedCFrame", fridgeHinge.CFrame)
		if type(fridgeHinge:GetAttribute("DerivedOpenAngleDegrees")) ~= "number" then
			local refrigeratorBody = refrigerator:FindFirstChild("RefrigeratorBody")
			local doorPanel = doorAssembly:FindFirstChild("FridgeDoorPanel")
			if refrigeratorBody and refrigeratorBody:IsA("BasePart")
				and doorPanel and doorPanel:IsA("BasePart")
			then
				local angleMagnitude = math.clamp(
					math.abs(tonumber(fridgeHinge:GetAttribute("OpenAngleMagnitude")) or 78),
					70,
					125
				)
				local edgeA = doorPanel.Position + doorPanel.CFrame.RightVector * (doorPanel.Size.X * 0.5)
				local edgeB = doorPanel.Position - doorPanel.CFrame.RightVector * (doorPanel.Size.X * 0.5)
				local closedFreeEdge = if (edgeA - fridgeHinge.Position).Magnitude
					>= (edgeB - fridgeHinge.Position).Magnitude
					then edgeA
					else edgeB
				local freeEdgeInHingeSpace = fridgeHinge.CFrame:PointToObjectSpace(closedFreeEdge)
				local panelRelative = fridgeHinge.CFrame:ToObjectSpace(doorPanel.CFrame)
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Exclude
				overlapParams.FilterDescendantsInstances = { refrigerator }
				local function openScore(degrees)
					local openCFrame = fridgeHinge.CFrame * CFrame.Angles(0, math.rad(degrees), 0)
					local freeEdge = openCFrame:PointToWorldSpace(freeEdgeInHingeSpace)
					local towardAisle = (freeEdge - refrigeratorBody.Position)
						:Dot(refrigeratorBody.CFrame.LookVector)
					local collisionCount = 0
					for _, hit in ipairs(Workspace:GetPartBoundsInBox(
						openCFrame * panelRelative,
						doorPanel.Size * 0.9,
						overlapParams
					)) do
						if hit.CanCollide then
							collisionCount += 1
						end
					end
					return towardAisle * 10 - collisionCount * 25
				end
				local derivedAngle = if openScore(angleMagnitude) >= openScore(-angleMagnitude)
					then angleMagnitude
					else -angleMagnitude
				fridgeHinge:SetAttribute("DerivedOpenAngleDegrees", derivedAngle)
				fridgeHinge:SetAttribute("SwingDirectionDerivedFromGeometry", true)
			end
		end
	end

	local exterior = house:FindFirstChild("ExteriorDetails")
	if exterior and exterior:IsA("Model") then
		repairStatefulDoor(exterior:FindFirstChild("InteractiveFrontDoor"), -102, "FrontDoorPromptAnchor")
		repairStatefulDoor(exterior:FindFirstChild("InteractiveDenPatioDoor"), -98, "DenPatioPromptAnchor")
	end

	local interactions = house:FindFirstChild("CooperInteractions")
	local bathroom = interactions and interactions:FindFirstChild("BathroomInteractions")
	local toiletSwirl = bathroom and bathroom:FindFirstChild("ToiletFlushSwirl")
	if toiletSwirl and toiletSwirl:IsA("BasePart") then
		toiletSwirl:SetAttribute("RestCFrame", toiletSwirl.CFrame)
		toiletSwirl:SetAttribute("RestSize", toiletSwirl.Size)
	end

	local crossHall = interiorRooms:FindFirstChild("CrossHallFloor")
	if crossHall and crossHall:IsA("BasePart") then
		environment:SetAttribute("HallMinZ", crossHall.Position.Z - crossHall.Size.Z * 0.5)
		environment:SetAttribute("HallMaxZ", crossHall.Position.Z + crossHall.Size.Z * 0.5)
	end
	local houseBoundsCFrame, houseBoundsSize = house:GetBoundingBox()
	environment:SetAttribute("HouseMinX", houseBoundsCFrame.Position.X - houseBoundsSize.X * 0.5)
	environment:SetAttribute("HouseMaxX", houseBoundsCFrame.Position.X + houseBoundsSize.X * 0.5)

	-- Preserve the idempotent metadata used by core_repairs.luau as well. These
	-- baselines predate several historical layout moves, so derive them from the
	-- current repaired geometry instead of applying another guessed map offset.
	local porchGlider = exterior and exterior:FindFirstChild("PorchGlider")
	if porchGlider and porchGlider:IsA("Model") then
		porchGlider:SetAttribute(
			"HouseCoreRepairsBaselineCFrame",
			porchGlider:GetPivot() * CFrame.Angles(0, -math.pi, 0)
		)
	end
	for _, object in ipairs(furniture:GetDescendants()) do
		local isHutchPiece = object.Name == "DiningChinaHutch"
			or object.Name == "DisplayedChina"
			or string.find(object.Name, "HutchHorizontalShelf", 1, true) == 1
		if isHutchPiece and (object:IsA("BasePart") or object:IsA("Model")) then
			local currentCFrame = if object:IsA("BasePart") then object.CFrame else object:GetPivot()
			object:SetAttribute(
				"HouseCoreRepairsBaselineCFrame",
				currentCFrame + Vector3.new(-2.62, 0, 0)
			)
		end
	end
	local toilet = furniture:FindFirstChild("SideFacingIvoryToilet")
	local pedestal = toilet and toilet:FindFirstChild("PedestalBase")
	if toilet and toilet:IsA("Model") and pedestal and pedestal:IsA("BasePart") then
		local scale = tonumber(toilet:GetAttribute("CoreRepairScale")) or 1
		toilet:SetAttribute(
			"CoreRepairBaseCFrame",
			pedestal.CFrame * CFrame.new(Vector3.new(0, -0.12, -0.16) * scale)
		)
	end
end

do
	local garage = environment:FindFirstChild("DetachedGarage")
	local garageDoor = garage and garage:FindFirstChild("InteractiveSectionalGarageDoor")
	if garageDoor and garageDoor:IsA("Model") then
		local blocker = garageDoor:FindFirstChild("CollisionBlocker")
		local panels = garageDoor:FindFirstChild("Panels")
		local doorCenterX = garageDoor:GetAttribute("DoorCenterX")
		local doorPlaneZ = garageDoor:GetAttribute("DoorPlaneZ")
		local travelSign = garageDoor:GetAttribute("DoorTravelZSign")
		local openingBottomY = garageDoor:GetAttribute("OpeningBottomY")
		if blocker and blocker:IsA("BasePart")
			and panels and panels:IsA("Folder")
			and type(doorCenterX) == "number"
			and type(doorPlaneZ) == "number"
			and type(travelSign) == "number"
			and type(openingBottomY) == "number"
		then
			local expectedBlockerPosition = Vector3.new(
				doorCenterX,
				openingBottomY + blocker.Size.Y * 0.5,
				doorPlaneZ + travelSign * 0.08
			)
			local relocationOffset = blocker.Position - expectedBlockerPosition
			if relocationOffset.Magnitude > 0.01 then
				garageDoor:SetAttribute("DoorCenterX", doorCenterX + relocationOffset.X)
				garageDoor:SetAttribute("DoorPlaneZ", doorPlaneZ + relocationOffset.Z)
				garageDoor:SetAttribute("OpeningBottomY", openingBottomY + relocationOffset.Y)
				for _, attributeName in ipairs({ "OpeningTopY", "OverheadY" }) do
					local value = garageDoor:GetAttribute(attributeName)
					if type(value) == "number" then
						garageDoor:SetAttribute(attributeName, value + relocationOffset.Y)
					end
				end
			end

			local isOpen = garageDoor:GetAttribute("IsOpen") == true
			for _, panel in ipairs(panels:GetChildren()) do
				if panel:IsA("BasePart") then
					local closedPose = panel:FindFirstChild("ClosedPose")
					local openPose = panel:FindFirstChild("OpenPose")
					if closedPose and closedPose:IsA("CFrameValue")
						and openPose and openPose:IsA("CFrameValue")
					then
						if relocationOffset.Magnitude > 0.01 then
							closedPose.Value += relocationOffset
							openPose.Value += relocationOffset
						end
						panel.CFrame = if isOpen then openPose.Value else closedPose.Value
					end
				end
			end
			blocker.CanCollide = not isOpen
			garageDoor:SetAttribute("DoorState", if isOpen then "Open" else "Closed")
			garageDoor:SetAttribute("TravelAlpha", if isOpen then 1 else 0)
			local prompt = garageDoor:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				prompt.ActionText = if isOpen then "Close Garage" else "Open Garage"
			end
		end
	end
end

do
	local landscaping = environment:FindFirstChild("Landscaping")
	local rideables = landscaping and landscaping:FindFirstChild("CooperYardRideables")
	if rideables and rideables:IsA("Model") then
		local swing = rideables:FindFirstChild("FrontYardTireSwing")
			or rideables:FindFirstChild("FrontYardRopeSwing")
		local swingSeat = swing and swing:FindFirstChild("SwingSeat")
		if swing and swing:IsA("Model") and swingSeat and swingSeat:IsA("Seat") then
			local storedHome = swingSeat:GetAttribute("HomeCFrame")
			if typeof(storedHome) == "CFrame" then
				local relocationOffset = swingSeat.Position - storedHome.Position
				if relocationOffset.Magnitude > 0.01 then
					for _, attributeName in ipairs({
						"HomeTireCenter",
						"HomeTopLeft",
						"HomeTopRight",
						"HomeBottomLeft",
						"HomeBottomRight",
					}) do
						local value = swing:GetAttribute(attributeName)
						if typeof(value) == "Vector3" then
							swing:SetAttribute(attributeName, value + relocationOffset)
						end
					end
				end
			end
			swingSeat:SetAttribute("HomeCFrame", swingSeat.CFrame)
			swing:SetAttribute("HomeSeatCFrame", swingSeat.CFrame)
		end

		local trike = rideables:FindFirstChild("CooperRedYellowTrike")
		local chassis = trike and trike:FindFirstChild("Chassis")
		if trike and trike:IsA("Model") and chassis and chassis:IsA("BasePart") then
			trike:SetAttribute("HomeCFrame", chassis.CFrame)
			chassis:SetAttribute("HomeCFrame", chassis.CFrame)
		end
	end
end

environment:SetAttribute("RelocationStateRepairVersion", "2026-07-13.1")

-- Older house builds left several supper props visibly hovering, and authored
-- the sixth place setting beyond the table edge. Repair the live house from
-- the tabletop's own coordinate system so this remains correct if the house
-- is moved, rotated, or uniformly rescaled.
local function orientedExtent(part, axis)
	local half = part.Size * 0.5
	return math.abs(axis:Dot(part.CFrame.RightVector)) * half.X
		+ math.abs(axis:Dot(part.CFrame.UpVector)) * half.Y
		+ math.abs(axis:Dot(part.CFrame.LookVector)) * half.Z
end

local function movePartCenter(part, position)
	part.CFrame = CFrame.new(position) * part.CFrame.Rotation
end

local function movePartInTablePlane(part, localX, localZ)
	local localPosition = diningTableTop.CFrame:PointToObjectSpace(part.Position)
	movePartCenter(part, diningTableTop.CFrame:PointToWorldSpace(Vector3.new(
		localX,
		localPosition.Y,
		localZ
	)))
end

local function seatOnDiningTable(part, clearance)
	local localPosition = diningTableTop.CFrame:PointToObjectSpace(part.Position)
	local margin = 0.025
	local halfX = orientedExtent(part, diningTableTop.CFrame.RightVector)
	local halfZ = orientedExtent(part, diningTableTop.CFrame.LookVector)
	local maximumX = math.max(0, diningTableTop.Size.X * 0.5 - halfX - margin)
	local maximumZ = math.max(0, diningTableTop.Size.Z * 0.5 - halfZ - margin)
	local height = diningTableTop.Size.Y * 0.5
		+ orientedExtent(part, diningTableTop.CFrame.UpVector)
		+ (clearance or 0.002)
	movePartCenter(part, diningTableTop.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(localPosition.X, -maximumX, maximumX),
		height,
		math.clamp(localPosition.Z, -maximumZ, maximumZ)
	)))
end

do
	local plate1 = assert(furniture:FindFirstChild("DinnerPlate1"), "DinnerPlate1 is missing")
	local plate6 = assert(furniture:FindFirstChild("DinnerPlate6"), "DinnerPlate6 is missing")
	local glass1 = assert(furniture:FindFirstChild("IcedTeaGlass1"), "IcedTeaGlass1 is missing")
	local glass6 = assert(furniture:FindFirstChild("IcedTeaGlass6"), "IcedTeaGlass6 is missing")
	assert(plate1:IsA("BasePart") and plate6:IsA("BasePart"), "Dining plates must be BaseParts")
	assert(glass1:IsA("BasePart") and glass6:IsA("BasePart"), "Dining glasses must be BaseParts")
	local plate1Local = diningTableTop.CFrame:PointToObjectSpace(plate1.Position)
	local glass1Local = diningTableTop.CFrame:PointToObjectSpace(glass1.Position)
	movePartInTablePlane(plate6, plate1Local.X, 0)
	movePartInTablePlane(glass6, glass1Local.X, glass1Local.Z - plate1Local.Z)

	for index = 1, 6 do
		local plate = assert(furniture:FindFirstChild("DinnerPlate" .. index), "Dining plate is missing")
		local glass = assert(furniture:FindFirstChild("IcedTeaGlass" .. index), "Iced-tea glass is missing")
		assert(plate:IsA("BasePart") and glass:IsA("BasePart"), "Dining place setting is malformed")
		seatOnDiningTable(plate, 0.002)
		seatOnDiningTable(glass, 0.002)
	end

	local servingBowl = assert(furniture:FindFirstChild("ServingBowl"), "ServingBowl is missing")
	local greenBeans = assert(furniture:FindFirstChild("GreenBeans"), "GreenBeans is missing")
	assert(servingBowl:IsA("BasePart") and greenBeans:IsA("BasePart"), "Serving bowl props are malformed")
	seatOnDiningTable(servingBowl, 0.002)
	local bowlLocal = diningTableTop.CFrame:PointToObjectSpace(servingBowl.Position)
	local beansHeight = bowlLocal.Y
		+ orientedExtent(servingBowl, diningTableTop.CFrame.UpVector)
		+ orientedExtent(greenBeans, diningTableTop.CFrame.UpVector)
		+ 0.002
	movePartCenter(greenBeans, diningTableTop.CFrame:PointToWorldSpace(Vector3.new(
		bowlLocal.X,
		beansHeight,
		bowlLocal.Z
	)))
	diningTable:SetAttribute("TabletopPropsGrounded", true)
	diningTable:SetAttribute("TabletopRepairVersion", "2026-07-13.1")
end
local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
assert(gameRoot and gameRoot:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
local configModule = gameRoot:FindFirstChild("Config")
assert(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config is missing")
-- Studio caches ModuleScript requires across installer reruns. Require a short-
-- lived clone so this edit-mode rebuild always uses the source just synced from
-- disk (including newly added automation definitions).
local freshConfig = configModule:Clone()
freshConfig.Name = "__CooperTaskWorldInstallerConfig"
freshConfig.Parent = gameRoot
local Config = require(freshConfig)
freshConfig:Destroy()
local gameState = gameRoot:FindFirstChild("State")
assert(gameState and gameState:IsA("Folder"), "CooperGame.State is missing")
gameState:SetAttribute("SchemaVersion", Config.SchemaVersion)
gameState:SetAttribute("FoundationContract", "PersonalV4")
gameState:SetAttribute("SupportsIncomeBoombox", true)
gameState:SetAttribute("SupportsBoombox", true)
gameState:SetAttribute("SupportsBoomboxAutoplay", true)
gameState:SetAttribute("SupportsPaidPartOrdering", true)
gameState:SetAttribute("SupportsTaskAutomation", true)
gameState:SetAttribute("SupportsMedfordBankHack", true)
gameState:SetAttribute("SupportsSecretBunkerUnlock", true)
gameState:SetAttribute("SupportsBunkerChemistrySetup", true)
gameState:SetAttribute("SupportsCandyDelivery", true)
-- Remove state left by the retired advanced controllers when this installer is
-- rerun over an existing place.
for attributeName in pairs(gameState:GetAttributes()) do
	if attributeName ~= "SchemaVersion"
		and attributeName ~= "FoundationContract"
		and attributeName ~= "SupportsPaidPartOrdering"
		and attributeName ~= "SupportsIncomeBoombox"
		and attributeName ~= "SupportsBoombox"
		and attributeName ~= "SupportsBoomboxAutoplay"
		and attributeName ~= "SupportsTaskAutomation"
		and attributeName ~= "SupportsMedfordBankHack"
		and attributeName ~= "SupportsSecretBunkerUnlock"
		and attributeName ~= "SupportsBunkerChemistrySetup"
		and attributeName ~= "SupportsCandyDelivery"
	then
		gameState:SetAttribute(attributeName, nil)
	end
end

local serverEvents = ServerScriptService:FindFirstChild(Config.ServerEventsName)
if not serverEvents then
	serverEvents = Instance.new("Folder")
	serverEvents.Name = Config.ServerEventsName
	serverEvents.Parent = ServerScriptService
end
for _, specification in ipairs({
	{ className = "BindableEvent", name = "ReportAction" },
	{ className = "BindableEvent", name = "RegisterAction" },
	{ className = "BindableEvent", name = "RequestDelivery" },
	{ className = "BindableEvent", name = "RunTaskAutomation" },
	{ className = "BindableEvent", name = "CandyDeliveryChanged" },
	{ className = "BindableFunction", name = "API" },
}) do
	local item = serverEvents:FindFirstChild(specification.name)
	if item and item.ClassName ~= specification.className then
		item:Destroy()
		item = nil
	end
	if not item then
		item = Instance.new(specification.className)
		item.Name = specification.name
		item.Parent = serverEvents
	end
end

local old = environment:FindFirstChild(Config.WorldRootName)
if old then
	old:Destroy()
end

local root = Instance.new("Model")
root.Name = Config.WorldRootName
root:SetAttribute("InstallVersion", "2026-07-21.hackerbot.1")
root:SetAttribute("SupportsTaskAutomation", true)
root.Parent = environment

local stations = Instance.new("Folder")
stations.Name = "Stations"
stations.Parent = root
local hidden = Instance.new("Folder")
hidden.Name = "HiddenLocations"
hidden.Parent = root
local delivery = Instance.new("Model")
delivery.Name = "Delivery"
delivery.Parent = root
local visuals = Instance.new("Folder")
visuals.Name = "TaskVisuals"
visuals.Parent = root

local function part(parent, name, position, size, color, material, transparency)
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = true
	item.CastShadow = false
	item.Position = position
	item.Size = size
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Transparency = transparency or 0
	item.Parent = parent
	return item
end

local function promptAnchor(name, position, actionText, objectText, action, holdDuration)
	local anchor = part(
		stations,
		name,
		position,
		Vector3.new(0.6, 0.6, 0.6),
		Color3.fromRGB(255, 220, 112),
		Enum.Material.Neon,
		1
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TaskPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = holdDuration or 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("FamilyTaskAction", action)
	prompt.Parent = anchor
	return anchor, prompt
end

local dishesAnchor = promptAnchor(
	"DishesPromptAnchor",
	(kitchenSink.CFrame * CFrame.new(0, 0.355, -1.615)).Position,
	"Wash Dishes",
	"Kitchen sink",
	"Dishes",
	4
)
-- Keep the authoritative prompt enabled on the server so its hold-began and
-- hold-ended events can enforce the full four-second wash. Each player's
-- CooperGame client still hides it locally unless Mary's dish task is active.
local dishesPrompt = dishesAnchor:FindFirstChild("TaskPrompt")
if dishesPrompt and dishesPrompt:IsA("ProximityPrompt") then
	dishesPrompt.Enabled = true
end
local garageForTrash = assert(environment:FindFirstChild("DetachedGarage"), "DetachedGarage is missing")
local garageRightWallForTrash = assert(
	garageForTrash:FindFirstChild("GarageRightWall"),
	"DetachedGarage.GarageRightWall is missing"
)
assert(garageRightWallForTrash:IsA("BasePart"), "GarageRightWall must be a BasePart")
local outdoorTrashPlan = garageRightWallForTrash.Position
	+ garageRightWallForTrash.CFrame.RightVector * (garageRightWallForTrash.Size.X * 0.5 + 1.8)
	+ garageRightWallForTrash.CFrame.LookVector * (garageRightWallForTrash.Size.Z * 0.5 - 4.0)
local outdoorGroundParams = RaycastParams.new()
outdoorGroundParams.FilterType = Enum.RaycastFilterType.Exclude
outdoorGroundParams.FilterDescendantsInstances = { world }
outdoorGroundParams.RespectCanCollide = true
local outdoorGroundHit = workspace:Raycast(
	outdoorTrashPlan + Vector3.new(0, 30, 0),
	Vector3.new(0, -100, 0),
	outdoorGroundParams
)
assert(outdoorGroundHit, "No physical yard surface exists beside the detached garage")
local outdoorGroundTop = outdoorGroundHit.Position.Y
-- The garbage-can cylinder is rotated upright, so Size.X (2.5 studs) is its
-- vertical body height. Ground it from the real relocated yard instead of the
-- obsolete pre-relocation Y=2.25 coordinate.
local outdoorTrashPosition = Vector3.new(
	outdoorTrashPlan.X,
	outdoorGroundTop + 1.25,
	outdoorTrashPlan.Z
)
local kitchenFloorTop = kitchenFloor.Position.Y + kitchenFloor.Size.Y * 0.5
local kitchenCanPlan = kitchenFloor.CFrame:PointToWorldSpace(Vector3.new(-3.468, 0, -0.885))
local kitchenCanPosition = Vector3.new(kitchenCanPlan.X, kitchenFloorTop + 1.137, kitchenCanPlan.Z)
local trashPickupAnchor = promptAnchor(
	"TrashPickupAnchor",
	Vector3.new(kitchenCanPosition.X, kitchenFloorTop + 0.737, kitchenCanPosition.Z),
	"Pick Up Trash",
	"Kitchen trash bag",
	"TrashPickup",
	0.5
)
local outdoorTrashAnchor = promptAnchor(
	"OutdoorTrashAnchor",
	outdoorTrashPosition,
	"Put In Garbage Can",
	"Garage-side outdoor garbage can",
	"TrashDrop",
	0.6
)
local georgeDropAnchor = promptAnchor(
	"GeorgeBeerDropAnchor",
	(refrigerator:GetPivot() * CFrame.new(1.072, -1.327, -0.244)).Position,
	"Stock Beer In Fridge",
	"Kitchen refrigerator",
	"BeerDrop",
	0.55
)
local installBayAnchor = promptAnchor(
	"MachineInstallBay",
	(assert(garageForTrash:FindFirstChild("CooperTimeMachine"), "CooperTimeMachine is missing"):GetPivot()
		* CFrame.new(0, -0.355, -5.605)).Position,
	"Install Component",
	"Time Machine installation bay",
	"MachineInstall",
	0.8
)

local function stationPad(name, anchor, color, size, surfaceTopY)
	local padSize = size or Vector3.new(3.4, 0.08, 3.4)
	local pad = part(
		visuals,
		name,
		Vector3.new(anchor.Position.X, surfaceTopY + padSize.Y * 0.5 + 0.01, anchor.Position.Z),
		padSize,
		color,
		Enum.Material.Neon,
		0.78
	)
	pad.CanQuery = false
	return pad
end

local garageFloor = garageForTrash:FindFirstChild("SealedConcreteFloor", true)
assert(garageFloor and garageFloor:IsA("BasePart"), "Detached garage floor is missing")
local garageFloorTop = garageFloor.Position.Y + garageFloor.Size.Y * 0.5
stationPad("DishesPad", dishesAnchor, Color3.fromRGB(90, 205, 130), Vector3.new(3.0, 0.06, 2.0), kitchenFloorTop)
stationPad("TrashPickupPad", trashPickupAnchor, Color3.fromRGB(90, 205, 130), nil, kitchenFloorTop)
stationPad("OutdoorTrashPad", outdoorTrashAnchor, Color3.fromRGB(90, 205, 130), nil, outdoorGroundTop)
stationPad("GeorgeBeerPad", georgeDropAnchor, Color3.fromRGB(235, 125, 65), nil, kitchenFloorTop)
stationPad("MachineInstallPad", installBayAnchor, Color3.fromRGB(90, 155, 235), Vector3.new(4.8, 0.08, 4.8), garageFloorTop)

-- Living-room income boombox -----------------------------------------------
-- The portable stereo is authored from the empty end-table top rather than a
-- world coordinate. Its physical shell is only 1.94 x 0.69 x 1.11 studs, so it
-- fits the 2.376 x 2.16-stud table without hanging over an edge. Disco floor
-- pools are effect parts and are explicitly marked so physical-bounds audits
-- can exclude them from the boombox shell.
do
	local tableUp = formalSofaEndTableTop.CFrame.UpVector.Unit
	local sofaLook = formalSofa:GetPivot().LookVector
	local planarSofaLook = sofaLook - tableUp * sofaLook:Dot(tableUp)
	assert(planarSofaLook.Magnitude > 0.5, "FormalGreenFloralSofa has no horizontal facing direction")
	local boomboxFront = planarSofaLook.Unit
	local boomboxBasePosition = formalSofaEndTableTop.Position
		+ tableUp * (formalSofaEndTableTop.Size.Y * 0.5 + 0.025)
	local boomboxPlacementCFrame = CFrame.lookAt(
		boomboxBasePosition,
		boomboxBasePosition + boomboxFront,
		tableUp
	)

	local boombox = Instance.new("Model")
	boombox.Name = "CooperIncomeBoombox"
	boombox.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	boombox:SetAttribute("InstallVersion", "2026-07-13.4")
	boombox:SetAttribute("FamilyTaskVisual", "IncomeBoombox")
	boombox:SetAttribute("RuntimeVisibility", "PlacedOnly")
	boombox:SetAttribute("VisualContract", "Placed restores VisibleTransparency and PlacedCanCollide; Playing enables lights, floor pools, and sound")
	boombox:SetAttribute("PlacementFurniture", "FormalSofaEndTable.Top")
	boombox:SetAttribute("SetupCFrame", boomboxPlacementCFrame)
	boombox:SetAttribute("SoundId", "rbxassetid://86759598635831")
	boombox:SetAttribute("ExpectedAudioDuration", 22.465306)
	boombox:SetAttribute("PhysicalBoundsSize", Vector3.new(1.94, 1.11, 0.69))
	boombox:SetAttribute("Placed", false)
	boombox:SetAttribute("Playing", false)
	boombox.Parent = visuals

	local function boomboxPart(
		name,
		localCFrame,
		size,
		color,
		material,
		visibleTransparency,
		shape,
		placedCanCollide,
		isEffectPart
	)
		local shownTransparency = visibleTransparency or 0
		local item = part(
			boombox,
			name,
			(boomboxPlacementCFrame * localCFrame).Position,
			size,
			color,
			material,
			1
		)
		item.CFrame = boomboxPlacementCFrame * localCFrame
		if shape then
			item.Shape = shape
		end
		item.CanCollide = false
		item.CanTouch = false
		item.CanQuery = false
		item.CastShadow = shownTransparency < 1 and not isEffectPart
		item:SetAttribute("BoomboxVisual", true)
		item:SetAttribute("VisibleTransparency", shownTransparency)
		item:SetAttribute("PlacedCanCollide", placedCanCollide == true)
		item:SetAttribute("BoomboxEffectPart", isEffectPart == true)
		return item
	end

	local CHARCOAL = Color3.fromRGB(52, 55, 56)
	local DARK_CHARCOAL = Color3.fromRGB(28, 30, 31)
	local BLACK = Color3.fromRGB(15, 17, 18)
	local SILVER = Color3.fromRGB(154, 163, 165)
	local DARK_SILVER = Color3.fromRGB(86, 93, 95)
	local CASSETTE = Color3.fromRGB(91, 76, 57)
	local DISPLAY = Color3.fromRGB(16, 38, 42)
	local PALETTE = {
		Color3.fromRGB(255, 65, 170),
		Color3.fromRGB(38, 210, 255),
		Color3.fromRGB(255, 195, 45),
		Color3.fromRGB(135, 82, 255),
	}

	local collisionHull = boomboxPart(
		"CollisionHull",
		CFrame.new(0, 0.42, 0),
		Vector3.new(1.90, 0.74, 0.64),
		CHARCOAL,
		Enum.Material.SmoothPlastic,
		1,
		nil,
		true,
		false
	)
	boombox.PrimaryPart = collisionHull

	boomboxPart(
		"MainBody",
		CFrame.new(0, 0.42, 0),
		Vector3.new(1.88, 0.69, 0.58),
		CHARCOAL,
		Enum.Material.Metal,
		0,
		nil,
		false,
		false
	)
	boomboxPart(
		"FrontFacePlate",
		CFrame.new(0, 0.42, -0.305),
		Vector3.new(1.76, 0.56, 0.03),
		DARK_SILVER,
		Enum.Material.Metal,
		0,
		nil,
		false,
		false
	)
	for _, side in ipairs({ -1, 1 }) do
		boomboxPart(
			if side < 0 then "LeftEndCap" else "RightEndCap",
			CFrame.new(side * 0.955, 0.42, 0),
			Vector3.new(0.03, 0.64, 0.55),
			BLACK,
			Enum.Material.SmoothPlastic,
			0.04,
			nil,
			false,
			false
		)
	end

	-- Twin layered speaker grilles read clearly without imported meshes.
	for speakerIndex, speakerX in ipairs({ -0.59, 0.59 }) do
		local speakerPrefix = if speakerIndex == 1 then "LeftSpeaker" else "RightSpeaker"
		boomboxPart(
			speakerPrefix .. "OuterRing",
			CFrame.new(speakerX, 0.40, -0.326) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(0.035, 0.54, 0.54),
			SILVER,
			Enum.Material.Metal,
			0,
			Enum.PartType.Cylinder,
			false,
			false
		)
		boomboxPart(
			speakerPrefix .. "Grille",
			CFrame.new(speakerX, 0.40, -0.346) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(0.025, 0.43, 0.43),
			BLACK,
			Enum.Material.SmoothPlastic,
			0.02,
			Enum.PartType.Cylinder,
			false,
			false
		)
		boomboxPart(
			speakerPrefix .. "DustCap",
			CFrame.new(speakerX, 0.40, -0.361) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(0.018, 0.15, 0.15),
			DARK_CHARCOAL,
			Enum.Material.SmoothPlastic,
			0,
			Enum.PartType.Cylinder,
			false,
			false
		)
	end

	boomboxPart(
		"CassetteDoor",
		CFrame.new(0, 0.35, -0.329),
		Vector3.new(0.39, 0.30, 0.035),
		BLACK,
		Enum.Material.SmoothPlastic,
		0,
		nil,
		false,
		false
	)
	boomboxPart(
		"CassetteWindow",
		CFrame.new(0, 0.35, -0.351),
		Vector3.new(0.31, 0.21, 0.012),
		CASSETTE,
		Enum.Material.Glass,
		0.24,
		nil,
		false,
		false
	)
	for reelIndex, reelX in ipairs({ -0.085, 0.085 }) do
		boomboxPart(
			"CassetteReel" .. reelIndex,
			CFrame.new(reelX, 0.35, -0.361) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(0.012, 0.09, 0.09),
			SILVER,
			Enum.Material.Metal,
			0.04,
			Enum.PartType.Cylinder,
			false,
			false
		)
	end

	boomboxPart(
		"EqualizerDisplay",
		CFrame.new(0, 0.64, -0.329),
		Vector3.new(0.48, 0.12, 0.035),
		DISPLAY,
		Enum.Material.Glass,
		0.08,
		nil,
		false,
		false
	)
	for barIndex, barHeight in ipairs({ 0.045, 0.075, 0.055, 0.085, 0.048 }) do
		local bar = boomboxPart(
			"EqualizerBar" .. barIndex,
			CFrame.new(-0.16 + (barIndex - 1) * 0.08, 0.61 + barHeight * 0.5, -0.351),
			Vector3.new(0.035, barHeight, 0.012),
			if barIndex % 2 == 0 then Color3.fromRGB(81, 234, 205) else Color3.fromRGB(74, 187, 242),
			Enum.Material.Neon,
			0.10,
			nil,
			false,
			false
		)
		bar:SetAttribute("EqualizerBar", true)
	end

	local powerButton = boomboxPart(
		"PowerButton",
		CFrame.new(-0.82, 0.68, -0.329),
		Vector3.new(0.09, 0.09, 0.035),
		Color3.fromRGB(202, 65, 54),
		Enum.Material.SmoothPlastic,
		0,
		nil,
		false,
		false
	)
	powerButton:SetAttribute("BoomboxPowerButton", true)
	for buttonIndex, buttonX in ipairs({ -0.28, -0.09, 0.10, 0.29 }) do
		boomboxPart(
			"TopButton" .. buttonIndex,
			CFrame.new(buttonX, 0.792, -0.06),
			Vector3.new(0.12, 0.045, 0.13),
			DARK_CHARCOAL,
			Enum.Material.SmoothPlastic,
			0,
			nil,
			false,
			false
		)
	end
	for knobIndex, knobX in ipairs({ 0.52, 0.72 }) do
		boomboxPart(
			"ControlKnob" .. knobIndex,
			CFrame.new(knobX, 0.805, 0.05) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(0.05, 0.13, 0.13),
			SILVER,
			Enum.Material.Metal,
			0,
			Enum.PartType.Cylinder,
			false,
			false
		)
	end

	-- A compact silver carry handle and antenna preserve the late-80s silhouette.
	for handleIndex, handleX in ipairs({ -0.73, 0.73 }) do
		boomboxPart(
			"HandlePost" .. handleIndex,
			CFrame.new(handleX, 0.90, 0.10),
			Vector3.new(0.065, 0.30, 0.065),
			SILVER,
			Enum.Material.Metal,
			0,
			nil,
			false,
			false
		)
	end
	boomboxPart(
		"CarryHandle",
		CFrame.new(0, 1.035, 0.10),
		Vector3.new(1.50, 0.055, 0.07),
		SILVER,
		Enum.Material.Metal,
		0,
		nil,
		false,
		false
	)
	boomboxPart(
		"Antenna",
		CFrame.new(0.69, 0.94, 0.18) * CFrame.Angles(0, 0, math.rad(-25)),
		Vector3.new(0.024, 0.36, 0.024),
		Color3.fromRGB(188, 195, 196),
		Enum.Material.Metal,
		0,
		nil,
		false,
		false
	)
	for footIndex, offset in ipairs({
		Vector3.new(-0.70, 0.035, -0.21),
		Vector3.new(0.70, 0.035, -0.21),
		Vector3.new(-0.70, 0.035, 0.21),
		Vector3.new(0.70, 0.035, 0.21),
	}) do
		boomboxPart(
			"RubberFoot" .. footIndex,
			CFrame.new(offset),
			Vector3.new(0.15, 0.07, 0.11),
			BLACK,
			Enum.Material.Rubber,
			0,
			nil,
			false,
			false
		)
	end

	local brandPlate = boomboxPart(
		"BrandPlate",
		CFrame.new(0, 0.535, -0.351),
		Vector3.new(0.32, 0.07, 0.012),
		SILVER,
		Enum.Material.Metal,
		0.04,
		nil,
		false,
		false
	)
	local brandGui = Instance.new("SurfaceGui")
	brandGui.Name = "BrandGui"
	brandGui.Enabled = false
	brandGui.Face = Enum.NormalId.Front
	brandGui.AlwaysOnTop = false
	brandGui.LightInfluence = 1
	brandGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	brandGui.PixelsPerStud = 120
	brandGui:SetAttribute("EnabledWhenPlaced", true)
	brandGui.Parent = brandPlate
	local brandText = Instance.new("TextLabel")
	brandText.Name = "BrandText"
	brandText.Size = UDim2.fromScale(1, 1)
	brandText.BackgroundTransparency = 1
	brandText.Text = "COOPER SOUND"
	brandText.TextColor3 = Color3.fromRGB(24, 29, 30)
	brandText.Font = Enum.Font.GothamBold
	brandText.TextScaled = true
	brandText.Parent = brandGui

	local audioEmitter = boomboxPart(
		"AudioEmitter",
		CFrame.new(0, 0.43, -0.34),
		Vector3.new(0.08, 0.08, 0.08),
		BLACK,
		Enum.Material.SmoothPlastic,
		1,
		nil,
		false,
		true
	)
	local boomboxSound = Instance.new("Sound")
	boomboxSound.Name = "BoomboxSound"
	boomboxSound.SoundId = "rbxassetid://86759598635831"
	boomboxSound.Volume = 0.7
	boomboxSound.PlaybackSpeed = 1
	boomboxSound.Looped = false
	boomboxSound.RollOffMode = Enum.RollOffMode.InverseTapered
	boomboxSound.RollOffMinDistance = 7
	boomboxSound.RollOffMaxDistance = 68
	boomboxSound.EmitterSize = 7
	boomboxSound.PlayOnRemove = false
	boomboxSound:SetAttribute("ExpectedDuration", 22.465306)
	boomboxSound.Parent = audioEmitter

	local lightRig = Instance.new("Folder")
	lightRig.Name = "DiscoLightRig"
	lightRig.Parent = boombox
	local lensOffsets = { -0.66, -0.22, 0.22, 0.66 }
	local lightTargets = {
		boomboxBasePosition + boomboxFront * 5 + boomboxPlacementCFrame.RightVector * 5 + tableUp * 8,
		boomboxBasePosition + boomboxFront * 6 - boomboxPlacementCFrame.RightVector * 3 + tableUp * 3.5,
		boomboxBasePosition + boomboxFront * 4 + boomboxPlacementCFrame.RightVector * 14 + tableUp * 4,
		boomboxBasePosition + boomboxFront * 16 + boomboxPlacementCFrame.RightVector * 3 + tableUp * 4,
	}
	for lightIndex, lensX in ipairs(lensOffsets) do
		local lens = boomboxPart(
			"DiscoLens" .. lightIndex,
			CFrame.new(lensX, 0.795, -0.16) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(0.04, 0.12, 0.12),
			PALETTE[lightIndex],
			Enum.Material.Neon,
			0.10,
			Enum.PartType.Cylinder,
			false,
			false
		)
		lens:SetAttribute("DiscoLens", true)
		lens:SetAttribute("PaletteIndex", lightIndex)

		local emitterOrigin = boomboxPlacementCFrame:PointToWorldSpace(Vector3.new(lensX, 0.82, -0.16))
		local emitterWorldCFrame = CFrame.lookAt(emitterOrigin, lightTargets[lightIndex], tableUp)
		local emitter = boomboxPart(
			"DiscoEmitter" .. lightIndex,
			boomboxPlacementCFrame:ToObjectSpace(emitterWorldCFrame),
			Vector3.new(0.04, 0.04, 0.04),
			PALETTE[lightIndex],
			Enum.Material.SmoothPlastic,
			1,
			nil,
			false,
			true
		)
		emitter.Parent = lightRig
		emitter:SetAttribute("RestCFrame", emitterWorldCFrame)
		emitter:SetAttribute("DiscoTarget", lightTargets[lightIndex])
		emitter:SetAttribute("SweepPhase", (lightIndex - 1) * math.pi * 0.5)
		local spot = Instance.new("SpotLight")
		spot.Name = "DiscoSpotLight" .. lightIndex
		spot.Enabled = false
		spot.Face = Enum.NormalId.Front
		spot.Color = PALETTE[lightIndex]
		spot.Brightness = 5.75
		spot.Range = 31
		spot.Angle = 74
		spot.Shadows = false
		spot:SetAttribute("PaletteIndex", lightIndex)
		spot.Parent = emitter
	end

	local washEmitter = boomboxPart(
		"PartyWashEmitter",
		CFrame.new(0, 0.78, 0),
		Vector3.new(0.05, 0.05, 0.05),
		PALETTE[1],
		Enum.Material.SmoothPlastic,
		1,
		nil,
		false,
		true
	)
	washEmitter.Parent = lightRig
	local partyWash = Instance.new("PointLight")
	partyWash.Name = "PartyWash"
	partyWash.Enabled = false
	partyWash.Color = PALETTE[1]
	partyWash.Brightness = 2.35
	partyWash.Range = 24
	partyWash.Shadows = false
	partyWash.Parent = washEmitter

	local floorPools = Instance.new("Folder")
	floorPools.Name = "FloorLightPools"
	floorPools.Parent = boombox
	for poolIndex, specification in ipairs({
		{ forward = 5.0, side = 2.0, width = 3.0, depth = 2.2, color = PALETTE[1] },
		{ forward = 9.2, side = 6.2, width = 3.4, depth = 2.5, color = PALETTE[2] },
		{ forward = 13.0, side = 10.7, width = 3.1, depth = 2.3, color = PALETTE[3] },
	}) do
		local planPosition = boomboxBasePosition
			+ boomboxFront * specification.forward
			+ boomboxPlacementCFrame.RightVector * specification.side
		local carpetLocal = formalLivingCarpet.CFrame:PointToObjectSpace(planPosition)
		local poolPosition = formalLivingCarpet.CFrame:PointToWorldSpace(Vector3.new(
			carpetLocal.X,
			formalLivingCarpet.Size.Y * 0.5 + 0.025,
			carpetLocal.Z
		))
		local poolWorldCFrame = CFrame.fromMatrix(
			poolPosition,
			formalLivingCarpet.CFrame.UpVector,
			boomboxPlacementCFrame.RightVector,
			boomboxFront
		)
		local pool = boomboxPart(
			"FloorLightPool" .. poolIndex,
			boomboxPlacementCFrame:ToObjectSpace(poolWorldCFrame),
			Vector3.new(0.035, specification.width, specification.depth),
			specification.color,
			Enum.Material.Neon,
			1,
			Enum.PartType.Cylinder,
			false,
			true
		)
		pool.Parent = floorPools
		pool:SetAttribute("BoomboxFloorPool", true)
		pool:SetAttribute("PlayingTransparency", 0.56)
		pool:SetAttribute("PaletteIndex", poolIndex)
	end

	local setupAnchor, setupPrompt = promptAnchor(
		"BoomboxSetupAnchor",
		(boomboxPlacementCFrame * CFrame.new(0, 0.42, 0)).Position,
		"Set Up Boombox",
		"Living room end table",
		"BoomboxSetup",
		0.8
	)
	setupAnchor.CFrame = boomboxPlacementCFrame * CFrame.new(0, 0.42, 0)
	setupAnchor:SetAttribute("FurnitureAnchor", "FormalSofaEndTable.Top")
	setupAnchor:SetAttribute("BoomboxModel", "CooperIncomeBoombox")
	setupAnchor:SetAttribute("AutoSetupRadius", 5.5)
	setupAnchor:SetAttribute("GuidanceColor", "Purple")
	setupPrompt.Enabled = false
	setupPrompt.MaxActivationDistance = 8

	local powerAnchor, powerPrompt = promptAnchor(
		"BoomboxPowerAnchor",
		(boomboxPlacementCFrame * CFrame.new(-0.82, 0.68, -0.39)).Position,
		"Turn On",
		"Living room boombox",
		"BoomboxPower",
		0.35
	)
	powerAnchor.CFrame = boomboxPlacementCFrame * CFrame.new(-0.82, 0.68, -0.39)
	powerAnchor:SetAttribute("FurnitureAnchor", "FormalSofaEndTable.Top")
	powerAnchor:SetAttribute("BoomboxModel", "CooperIncomeBoombox")
	powerPrompt.Enabled = false
	powerPrompt.MaxActivationDistance = 8

	root:SetAttribute("SupportsIncomeBoombox", true)
	root:SetAttribute("SupportsBoomboxAutoplay", true)
	root:SetAttribute("IncomeBoomboxSoundId", boomboxSound.SoundId)
	root:SetAttribute("IncomeBoomboxSetupCFrame", boomboxPlacementCFrame)
end

-- Dirty dishes -------------------------------------------------------------
-- These are authored against the two real basin parts so moving or rotating
-- the complete house cannot leave the chore props floating elsewhere.
local dirtyDishes = Instance.new("Model")
dirtyDishes.Name = "DirtyDishesInSink"
dirtyDishes.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
dirtyDishes:SetAttribute("FamilyTaskVisual", "MaryDishes")
dirtyDishes:SetAttribute("RuntimeVisibility", "MaryDishesOnly")
dirtyDishes:SetAttribute("SinkFurniture", "DoublePorcelainSink")
dirtyDishes.Parent = visuals

local function dirtyDishPart(name, basin, basinName, localCFrame, size, color, material, shape, visibleTransparency)
	local shownTransparency = visibleTransparency or 0
	local item = part(
		dirtyDishes,
		name,
		(basin.CFrame * localCFrame).Position,
		size,
		color,
		material or Enum.Material.SmoothPlastic,
		shownTransparency
	)
	item.CFrame = basin.CFrame * localCFrame
	if shape then
		item.Shape = shape
	end
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.CastShadow = true
	item:SetAttribute("DirtyDishVisual", true)
	item:SetAttribute("SinkBasin", basinName)
	item:SetAttribute("VisibleTransparency", shownTransparency)
	return item
end

local DISH = Color3.fromRGB(232, 224, 198)
local DISH_EDGE = Color3.fromRGB(194, 181, 151)
local GRIME = Color3.fromRGB(119, 68, 38)
local SAUCE = Color3.fromRGB(137, 54, 35)
local METAL = Color3.fromRGB(151, 154, 149)

local function makeDirtyPlate(name, basin, basinName, x, y, z, diameter, yaw, grimeColor)
	local top = basin.Size.Y * 0.5
	local plate = dirtyDishPart(
		name,
		basin,
		basinName,
		CFrame.new(x, top + y, z) * CFrame.Angles(0, math.rad(yaw), math.rad(90)),
		Vector3.new(0.10, diameter, diameter),
		DISH,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder,
		0.03
	)
	dirtyDishPart(
		name .. "FoodStain",
		basin,
		basinName,
		basin.CFrame:ToObjectSpace(plate.CFrame * CFrame.new(0.061, 0, 0)),
		Vector3.new(0.025, diameter * 0.43, diameter * 0.38),
		grimeColor or GRIME,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder,
		0.08
	)
	return plate
end

makeDirtyPlate("DirtyPlateLeft01", leftSinkBasin, "LeftSinkBasin", -0.34, 0.12, -0.05, 1.16, -8, GRIME)
makeDirtyPlate("DirtyPlateLeft02", leftSinkBasin, "LeftSinkBasin", 0.30, 0.18, 0.13, 1.05, 11, SAUCE)
makeDirtyPlate("DirtyPlateRight01", rightSinkBasin, "RightSinkBasin", -0.35, 0.12, -0.14, 1.04, 6, GRIME)

-- A dirty bowl in the right basin.
local rightTop = rightSinkBasin.Size.Y * 0.5
local bowl = dirtyDishPart(
	"DirtyBowl",
	rightSinkBasin,
	"RightSinkBasin",
	CFrame.new(-0.25, rightTop + 0.22, 0.14) * CFrame.Angles(0, 0, math.rad(90)),
	Vector3.new(0.22, 0.94, 0.94),
	DISH_EDGE,
	Enum.Material.SmoothPlastic,
	Enum.PartType.Cylinder,
	0.02
)
dirtyDishPart(
	"DirtyBowlInside",
	rightSinkBasin,
	"RightSinkBasin",
	rightSinkBasin.CFrame:ToObjectSpace(bowl.CFrame * CFrame.new(0.121, 0, 0)),
	Vector3.new(0.025, 0.63, 0.63),
	GRIME,
	Enum.Material.SmoothPlastic,
	Enum.PartType.Cylinder,
	0.06
)

-- A mug and handle tucked beside the bowl.
local mug = dirtyDishPart(
	"DirtyMug",
	rightSinkBasin,
	"RightSinkBasin",
	CFrame.new(0.47, rightTop + 0.40, -0.18) * CFrame.Angles(0, 0, math.rad(90)),
	Vector3.new(0.68, 0.55, 0.55),
	DISH,
	Enum.Material.SmoothPlastic,
	Enum.PartType.Cylinder,
	0.02
)
dirtyDishPart(
	"DirtyMugCoffee",
	rightSinkBasin,
	"RightSinkBasin",
	rightSinkBasin.CFrame:ToObjectSpace(mug.CFrame * CFrame.new(0.351, 0, 0)),
	Vector3.new(0.025, 0.40, 0.40),
	Color3.fromRGB(75, 43, 28),
	Enum.Material.SmoothPlastic,
	Enum.PartType.Cylinder,
	0.04
)
for _, specification in ipairs({
	{ "DirtyMugHandleTop", CFrame.new(0.79, rightTop + 0.57, -0.18), Vector3.new(0.38, 0.08, 0.09) },
	{ "DirtyMugHandleOuter", CFrame.new(0.96, rightTop + 0.40, -0.18), Vector3.new(0.08, 0.40, 0.09) },
	{ "DirtyMugHandleBottom", CFrame.new(0.79, rightTop + 0.23, -0.18), Vector3.new(0.38, 0.08, 0.09) },
}) do
	dirtyDishPart(
		specification[1],
		rightSinkBasin,
		"RightSinkBasin",
		specification[2],
		specification[3],
		DISH_EDGE,
		Enum.Material.SmoothPlastic,
		nil,
		0.02
	)
end

-- Loose utensils make the pile read clearly from the player's standing angle.
local leftTop = leftSinkBasin.Size.Y * 0.5
dirtyDishPart(
	"DirtyForkHandle",
	leftSinkBasin,
	"LeftSinkBasin",
	CFrame.new(-0.66, leftTop + 0.25, 0.04) * CFrame.Angles(0, math.rad(-12), 0),
	Vector3.new(0.09, 0.055, 0.96),
	METAL,
	Enum.Material.Metal,
	nil,
	0.04
)
dirtyDishPart(
	"DirtyForkHead",
	leftSinkBasin,
	"LeftSinkBasin",
	CFrame.new(-0.56, leftTop + 0.25, -0.47) * CFrame.Angles(0, math.rad(-12), 0),
	Vector3.new(0.27, 0.06, 0.22),
	METAL,
	Enum.Material.Metal,
	nil,
	0.04
)

dirtyDishes.PrimaryPart = dirtyDishes:FindFirstChild("DirtyPlateLeft01")

local function garbageCanModel(name, position, color)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = visuals
	local canBody = part(
		model,
		"Can",
		position,
		Vector3.new(2.5, 2.2, 2.2),
		color,
		Enum.Material.Metal,
		0
	)
	canBody.Shape = Enum.PartType.Cylinder
	canBody.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	-- The can is a solid piece of furniture/yard equipment.  Keep the decorative
	-- rim non-colliding, but give the body one clean collider so players cannot
	-- walk through either garbage can.
	canBody.CanCollide = true
	local rim = part(
		model,
		"Rim",
		position + Vector3.new(0, 1.18, 0),
		Vector3.new(0.18, 2.45, 2.45),
		color:Lerp(Color3.new(0, 0, 0), 0.16),
		Enum.Material.Metal,
		0
	)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = CFrame.new(rim.Position) * CFrame.Angles(0, 0, math.rad(90))
	return model
end

-- Kitchen can and bag sit clear of the refrigerator's body and hinged door.
garbageCanModel("KitchenGarbageCan", kitchenCanPosition, Color3.fromRGB(116, 128, 113))
local kitchenBag = part(
	visuals,
	"KitchenTrashBag",
	Vector3.new(kitchenCanPosition.X, kitchenFloorTop + 1.737, kitchenCanPosition.Z),
	Vector3.new(1.75, 1.7, 1.75),
	Color3.fromRGB(35, 38, 34),
	Enum.Material.SmoothPlastic,
	0
)
kitchenBag.Shape = Enum.PartType.Ball
local bagTie = part(
	visuals,
	"KitchenTrashBagTie",
	Vector3.new(kitchenCanPosition.X, kitchenFloorTop + 2.587, kitchenCanPosition.Z),
	Vector3.new(0.35, 0.45, 0.35),
	Color3.fromRGB(29, 32, 29),
	Enum.Material.SmoothPlastic,
	0
)
bagTie.Shape = Enum.PartType.Ball

-- Outdoor can is just beyond the detached garage's east wall, never inside it.
local outdoorCan = garbageCanModel("OutdoorGarbageCan", outdoorTrashPosition, Color3.fromRGB(67, 78, 72))
local outdoorLid = part(
	outdoorCan,
	"Lid",
	outdoorTrashPosition + Vector3.new(0, 1.37, 0),
	Vector3.new(0.25, 2.75, 2.75),
	Color3.fromRGB(55, 65, 60),
	Enum.Material.Metal,
	0
)
outdoorLid.Shape = Enum.PartType.Cylinder
outdoorLid.CFrame = CFrame.new(outdoorLid.Position) * CFrame.Angles(0, 0, math.rad(90))

local function furnitureBounds(name)
	local anchor = furniture:FindFirstChild(name, true)
	assert(anchor, "Furniture anchor is missing: " .. name)
	if anchor:IsA("BasePart") then
		return anchor.CFrame, anchor.Size
	end
	assert(anchor:IsA("Model"), name .. " must be a BasePart or Model")
	return anchor:GetBoundingBox()
end

-- Build every private search marker from the furniture it is tucked beside.
-- Its vertical position is derived from that furniture's bottom edge, so the
-- toy remains just above the room floor instead of inheriting an obsolete Y.
for _, definition in ipairs(Config.HiddenLocations) do
	local anchorCFrame, anchorSize = furnitureBounds(definition.anchorName)
	local offset = definition.localOffset or Vector3.zero
	local markerCFrame = anchorCFrame
		* CFrame.new(offset.X, -anchorSize.Y * 0.5 + 0.82, offset.Z)
		* CFrame.Angles(0, math.rad(definition.yaw or 0), 0)
	local marker = part(
		hidden,
		definition.name,
		markerCFrame.Position,
		Vector3.new(1.2, 1.2, 1.2),
		Color3.fromRGB(255, 90, 180),
		Enum.Material.Neon,
		1
	)
	marker.CFrame = markerCFrame
	marker:SetAttribute("FurnitureAnchor", definition.anchorName)
	marker:SetAttribute("FurnitureLocalOffset", offset)
end

-- Missy's two normal pick-up toys live on her actual mattress. All home and
-- return positions are derived from that mattress, never from world numbers.
local details = furniture and furniture:FindFirstChild("YoungSheldonBedroomDetails_V2")
local twins = details and details:FindFirstChild("SheldonAndMissyRoom")
local teddy = twins and twins:FindFirstChild("MissyDetailedTeddyBear")
local rabbit = twins and twins:FindFirstChild("MissyDetailedRabbit")
local missyBed = furniture:FindFirstChild("MissyWalnutTwinBed")
local mattress = missyBed and missyBed:FindFirstChild("Mattress")
assert(teddy and teddy:IsA("Model"), "Missy's teddy bear is missing")
assert(rabbit and rabbit:IsA("Model"), "Missy's rabbit is missing")
assert(mattress and mattress:IsA("BasePart"), "Missy's mattress is missing")

local mattressTop = mattress.Size.Y * 0.5
local teddyHome = mattress.CFrame
	* CFrame.new(-0.68, mattressTop + 0.93, 0.2)
	* CFrame.Angles(0, math.rad(-14), 0)
local rabbitHome = mattress.CFrame
	* CFrame.new(0.62, mattressTop + 0.97, 0.28)
	* CFrame.Angles(0, math.rad(12), 0)

local function placeHomeToy(toy, homeCFrame)
	local handle = toy.PrimaryPart or toy:FindFirstChild("InteractionHandle", true)
	assert(handle and handle:IsA("BasePart"), toy.Name .. " has no interaction handle")
	handle.Anchored = true
	handle.AssemblyLinearVelocity = Vector3.zero
	handle.AssemblyAngularVelocity = Vector3.zero
	toy:PivotTo(homeCFrame)
	toy:SetAttribute("FamilyTaskHome", true)
	toy:SetAttribute("FamilyTaskHomeCFrame", homeCFrame)
	toy:SetAttribute("FamilyTaskHomeLocalCFrame", mattress.CFrame:ToObjectSpace(homeCFrame))
	toy:SetAttribute("FamilyTaskHomeAnchor", "MissyWalnutTwinBed.Mattress")
	for _, descendant in ipairs(toy:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "CooperPickupPrompt" then
			descendant.Enabled = true
		end
	end
end

placeHomeToy(teddy, teddyHome)
placeHomeToy(rabbit, rabbitHome)

local returnCFrame = mattress.CFrame * CFrame.new(0, mattressTop + 1.2, 0.25)
local missyReturnAnchor, missyReturnPrompt = promptAnchor(
	"MissyPlushReturnAnchor",
	returnCFrame.Position,
	"Return Stuffed Animal",
	"Missy's bed",
	"MissyReturn",
	0.5
)
missyReturnAnchor:SetAttribute("FurnitureAnchor", "MissyWalnutTwinBed.Mattress")
missyReturnPrompt.Enabled = false
local missyFloorParams = RaycastParams.new()
missyFloorParams.FilterType = Enum.RaycastFilterType.Exclude
missyFloorParams.FilterDescendantsInstances = { world, furniture }
missyFloorParams.RespectCanCollide = true
local missyFloorHit = workspace:Raycast(
	missyReturnAnchor.Position + Vector3.new(0, 0.5, 0),
	Vector3.new(0, -20, 0),
	missyFloorParams
)
assert(missyFloorHit, "No bedroom floor exists below Missy's return marker")
stationPad("MissyReturnPad", missyReturnAnchor, Color3.fromRGB(180, 105, 220), nil, missyFloorHit.Position.Y)

-- Permanent chore-automation robots ----------------------------------------
-- Each installation point and robot home is derived from real furniture.
-- Robot geometry starts hidden; CooperTaskWorld reveals it only when at least
-- one connected player's persistent automation catalog owns that upgrade.
local computerDesk = furniture:FindFirstChild("Sheldon1980sComputerDesk", true)
local computerDesktop = computerDesk and computerDesk:FindFirstChild("Desktop")
local computerKeyboard = computerDesk and computerDesk:FindFirstChild("Keyboard")
assert(computerDesk and computerDesk:IsA("Model"), "Sheldon1980sComputerDesk is missing")
assert(computerDesktop and computerDesktop:IsA("BasePart"), "Computer Desktop is missing")
assert(computerKeyboard and computerKeyboard:IsA("BasePart"), "Computer Keyboard is missing")

local automationColors = {
	-- Keep every physical setup pad/status light identical to the client's
	-- task-guidance arrow so a player never follows a blue arrow to a green pad.
	BeerBot = Color3.fromRGB(235, 119, 61),
	DishBot = Color3.fromRGB(86, 205, 123),
	TrashBot = Color3.fromRGB(74, 151, 222),
	ToyFinder = Color3.fromRGB(170, 105, 220),
	HackerBot = Color3.fromRGB(48, 224, 232),
}

local function automationPart(model, name, cframe, size, color, material, visibleTransparency, visibleCanCollide, shape)
	local item = part(
		model,
		name,
		cframe.Position,
		size,
		color,
		material or Enum.Material.SmoothPlastic,
		1
	)
	item.CFrame = cframe
	item.CanCollide = false
	item.CanQuery = false
	item.CastShadow = true
	if shape then
		item.Shape = shape
	end
	item:SetAttribute("AutomationRobotPart", true)
	item:SetAttribute("AutomationVisibleTransparency", visibleTransparency or 0)
	item:SetAttribute("AutomationVisibleCanCollide", visibleCanCollide == true)
	item:SetAttribute("AutomationHomeCFrame", cframe)
	item:SetAttribute("AutomationHomeSize", size)
	return item
end

local function automationBeam(model, name, pointA, pointB, thickness, color, material, visibleTransparency)
	local delta = pointB - pointA
	local midpoint = (pointA + pointB) * 0.5
	return automationPart(
		model,
		name,
		CFrame.lookAt(midpoint, pointB),
		Vector3.new(thickness, thickness, math.max(0.05, delta.Magnitude)),
		color,
		material,
		visibleTransparency,
		false
	)
end

local function automationModel(upgradeId, homeCFrame)
	local model = Instance.new("Model")
	model.Name = upgradeId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("TaskAutomationRobot", true)
	model:SetAttribute("UpgradeId", upgradeId)
	model:SetAttribute("InstallAnchor", upgradeId .. "InstallAnchor")
	model:SetAttribute("HomePivot", homeCFrame)
	model:SetAttribute("InstalledVisible", false)
	model.Parent = visuals
	return model
end

local function automationInstallStation(upgradeId, position, furnitureAnchor, color, padSize)
	local anchor, prompt = promptAnchor(
		upgradeId .. "InstallAnchor",
		position,
		"Install " .. upgradeId,
		upgradeId .. " installation point",
		"TaskUpgradeInstall",
		0.8
	)
	anchor:SetAttribute("UpgradeId", upgradeId)
	anchor:SetAttribute("FurnitureAnchor", furnitureAnchor)
	prompt:SetAttribute("UpgradeId", upgradeId)
	prompt.MaxActivationDistance = 10
	-- Installation is owner-safe and automatic when the matching carried crate
	-- enters this invisible destination. The player's colored guidance arrow
	-- points here; a shared world prompt/pad would leak another owner's state.
	prompt.Enabled = false
	local pad = part(
		visuals,
		upgradeId .. "InstallPad",
		Vector3.new(position.X, kitchenFloorTop + 0.035, position.Z),
		padSize or Vector3.new(2.5, 0.07, 2.5),
		color,
		Enum.Material.Neon,
		1
	)
	pad.CanQuery = false
	pad:SetAttribute("TaskUpgradeInstallPad", upgradeId)
	pad:SetAttribute("GuidanceColor", color)
	pad:SetAttribute("VisibleTransparency", 0.68)
	return anchor, prompt, pad
end

local function automationStatusLight(parent, adornee, color, range)
	local light = Instance.new("PointLight")
	light.Name = "AutomationStatusLight"
	light.Color = color
	light.Brightness = 1.35
	light.Range = range or 7
	light.Enabled = false
	light:SetAttribute("AutomationVisibleEnabled", true)
	light.Parent = adornee
	return light
end

-- BeerBot is a compact late-1980s auto-dial/order module mounted at the free
-- edge of Sheldon's desk. Its articulated finger lands on the real keyboard.
do
	-- The phone occupies the left rear corner and Sheldon's interactive puzzle
	-- cube occupies the right rear corner. Mount the controller in the narrow
	-- right-front corner with a deliberately compact footprint, wholly clear of
	-- both InteractionHandles and the keyboard itself.
	local baseCFrame = computerDesktop.CFrame
		* CFrame.new(
			computerDesktop.Size.X * 0.5 - 0.36,
			computerDesktop.Size.Y * 0.5 + 0.16,
			computerDesktop.Size.Z * 0.25
		)
	local model = automationModel("BeerBot", baseCFrame)
	local base = automationPart(model, "Base", baseCFrame, Vector3.new(0.68, 0.26, 0.72), Color3.fromRGB(82, 77, 65), Enum.Material.Metal, 0, true)
	model.PrimaryPart = base
	automationPart(model, "BeigeController", baseCFrame * CFrame.new(0, 0.34, 0), Vector3.new(0.58, 0.42, 0.56), Color3.fromRGB(211, 199, 163), Enum.Material.SmoothPlastic, 0, false)
	local status = automationPart(model, "OrderLight", baseCFrame * CFrame.new(0.15, 0.57, 0.18), Vector3.new(0.13, 0.13, 0.09), automationColors.BeerBot, Enum.Material.Neon, 0, false)
	automationStatusLight(model, status, automationColors.BeerBot, 6)
	automationPart(model, "Antenna", baseCFrame * CFrame.new(-0.20, 0.78, 0), Vector3.new(0.07, 0.62, 0.07), Color3.fromRGB(145, 148, 144), Enum.Material.Metal, 0, false, Enum.PartType.Cylinder)
	local fingerCFrame = computerKeyboard.CFrame
		* CFrame.new(0.88, computerKeyboard.Size.Y * 0.5 + 0.18, 0.03)
	local finger = automationPart(model, "TypingFinger", fingerCFrame, Vector3.new(0.16, 0.42, 0.16), Color3.fromRGB(182, 185, 177), Enum.Material.Metal, 0, false, Enum.PartType.Cylinder)
	-- Route around the computer's front-right corner rather than drawing one
	-- straight beam through the BeigeComputerBase and CRTCase. The two elbows
	-- stay beyond the computer's front face and above the keyboard plane.
	local shoulder = baseCFrame:PointToWorldSpace(Vector3.new(-0.08, 0.52, 0.18))
	local outsideElbow = baseCFrame:PointToWorldSpace(Vector3.new(-0.08, 0.70, 0.90))
	local keyboardElbow = finger.Position
		- computerDesktop.CFrame.LookVector * 0.48
		+ computerDesktop.CFrame.UpVector * 0.42
	local fingertip = finger.Position + computerDesktop.CFrame.UpVector * 0.16
	automationBeam(model, "TypingArm", shoulder, outsideElbow, 0.11, Color3.fromRGB(143, 146, 141), Enum.Material.Metal, 0)
	automationBeam(model, "TypingArmElbow", outsideElbow, keyboardElbow, 0.11, Color3.fromRGB(143, 146, 141), Enum.Material.Metal, 0)
	automationBeam(model, "TypingArmWrist", keyboardElbow, fingertip, 0.10, Color3.fromRGB(166, 169, 163), Enum.Material.Metal, 0)
	model:SetAttribute("TypingArmSegmentCount", 3)
	model:SetAttribute("DeskPlacement", "RightFrontClear")
	local label = Instance.new("SurfaceGui")
	label.Name = "AutomationLabel"
	label.Face = Enum.NormalId.Front
	label.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	label.PixelsPerStud = 55
	label.Enabled = false
	label:SetAttribute("AutomationVisibleEnabled", true)
	label.Parent = model.BeigeController
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundColor3 = Color3.fromRGB(33, 43, 32)
	textLabel.BorderSizePixel = 0
	textLabel.Text = "AUTO\nORDER"
	textLabel.TextColor3 = Color3.fromRGB(145, 245, 134)
	textLabel.Font = Enum.Font.Code
	textLabel.TextScaled = true
	textLabel.Parent = label

	-- The desk console only places the order. A separate compact floor cart does
	-- the visible collection and refrigerator run, so the automated task never
	-- has to pretend that a stationary box carried the delivered beer.
	local runnerPosition = Vector3.new(
		baseCFrame.Position.X + 2.20,
		kitchenFloorTop + 0.42,
		baseCFrame.Position.Z
	)
	local runnerHome = CFrame.lookAt(
		runnerPosition,
		Vector3.new(baseCFrame.Position.X, runnerPosition.Y, baseCFrame.Position.Z)
	)
	local runner = Instance.new("Model")
	runner.Name = "BeerRunner"
	runner.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	runner:SetAttribute("AutomationMobileUnit", true)
	runner:SetAttribute("HomePivot", runnerHome)
	runner:SetAttribute("AutomationHomePivot", runnerHome)
	runner:SetAttribute("RunnerMoveSpeed", 11)
	runner.Parent = model
	model:SetAttribute("MobileUnitModel", runner.Name)

	local function beerRunnerPart(name, localCFrame, size, color, material, visibleCanCollide, shape)
		local item = automationPart(
			runner,
			name,
			runnerHome * localCFrame,
			size,
			color,
			material,
			0,
			visibleCanCollide,
			shape
		)
		item:SetAttribute("AutomationBeerRunnerPart", true)
		return item
	end

	local runnerChassis = beerRunnerPart(
		"RunnerChassis",
		CFrame.new(),
		Vector3.new(0.82, 0.28, 0.90),
		Color3.fromRGB(71, 75, 70),
		Enum.Material.Metal,
		true
	)
	runner.PrimaryPart = runnerChassis
	beerRunnerPart(
		"RunnerBody",
		CFrame.new(0, 0.42, 0.03),
		Vector3.new(0.72, 0.54, 0.58),
		Color3.fromRGB(211, 199, 163),
		Enum.Material.SmoothPlastic,
		false
	)
	for _, side in ipairs({ -1, 1 }) do
		beerRunnerPart(
			"RunnerWheel" .. (side < 0 and "Left" or "Right"),
			CFrame.new(side * 0.47, -0.07, 0),
			Vector3.new(0.14, 0.48, 0.48),
			Color3.fromRGB(35, 37, 34),
			Enum.Material.Rubber,
			false,
			Enum.PartType.Cylinder
		)
	end
	local runnerStatus = beerRunnerPart(
		"RunnerStatus",
		CFrame.new(0, 0.49, -0.34),
		Vector3.new(0.34, 0.13, 0.07),
		automationColors.BeerBot,
		Enum.Material.Neon,
		false
	)
	automationStatusLight(runner, runnerStatus, automationColors.BeerBot, 7)
	beerRunnerPart(
		"RunnerCargoRack",
		CFrame.new(0, 0.72, 0.18),
		Vector3.new(0.88, 0.10, 0.54),
		Color3.fromRGB(113, 116, 108),
		Enum.Material.Metal,
		false
	)
	beerRunnerPart(
		"RunnerLiftMast",
		CFrame.new(0, 0.99, 0.17),
		Vector3.new(0.10, 0.88, 0.10),
		Color3.fromRGB(146, 149, 142),
		Enum.Material.Metal,
		false
	)
	local runnerArmStart = runnerHome:PointToWorldSpace(Vector3.new(0, 1.38, 0.17))
	local runnerArmEnd = runnerHome:PointToWorldSpace(Vector3.new(0, 1.38, -0.43))
	local runnerLiftArm = automationBeam(
		runner,
		"RunnerLiftArm",
		runnerArmStart,
		runnerArmEnd,
		0.13,
		Color3.fromRGB(158, 161, 154),
		Enum.Material.Metal,
		0
	)
	runnerLiftArm:SetAttribute("AutomationBeerRunnerPart", true)
	for _, side in ipairs({ -1, 1 }) do
		beerRunnerPart(
			"RunnerGrabber" .. (side < 0 and "Left" or "Right"),
			CFrame.new(side * 0.16, 1.17, -0.47)
				* CFrame.Angles(0, 0, math.rad(side * 16)),
			Vector3.new(0.09, 0.46, 0.09),
			Color3.fromRGB(171, 174, 166),
			Enum.Material.Metal,
			false
		)
	end

	-- A separate hidden case can be placed at the truck, lifted as one model, and
	-- carried on the rack. Six modeled cans represent the visible fridge stock;
	-- the authoritative inventory still owns the full twelve-count capacity.
	local caseHome = runnerHome * CFrame.new(0, 1.12, 0.18)
	local beerCase = Instance.new("Model")
	beerCase.Name = "BeerCaseVisual"
	beerCase.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	beerCase:SetAttribute("AutomationBeerCaseVisual", true)
	beerCase:SetAttribute("HomePivot", caseHome)
	beerCase:SetAttribute("AutomationHomePivot", caseHome)
	beerCase:SetAttribute("CaseCanCount", 6)
	beerCase.Parent = model
	model:SetAttribute("CaseVisualModel", beerCase.Name)

	local function beerCasePart(name, localCFrame, size, color, material, activeTransparency, shape)
		local item = automationPart(
			beerCase,
			name,
			caseHome * localCFrame,
			size,
			color,
			material,
			1,
			false,
			shape
		)
		item:SetAttribute("AutomationBeerCasePart", true)
		item:SetAttribute("AutomationActiveTransparency", math.clamp(activeTransparency or 0, 0, 1))
		return item
	end

	local caseBody = beerCasePart(
		"CaseBody",
		CFrame.new(),
		Vector3.new(1.08, 0.58, 0.80),
		Color3.fromRGB(139, 89, 48),
		Enum.Material.WoodPlanks,
		0
	)
	beerCase.PrimaryPart = caseBody
	for _, side in ipairs({ -1, 1 }) do
		beerCasePart(
			"CaseBand" .. (side < 0 and "Left" or "Right"),
			CFrame.new(side * 0.39, 0, 0),
			Vector3.new(0.11, 0.64, 0.84),
			Color3.fromRGB(67, 66, 62),
			Enum.Material.Metal,
			0
		)
	end
	local caseLabelPlate = beerCasePart(
		"CaseLabelPlate",
		CFrame.new(0, 0, -0.42),
		Vector3.new(0.72, 0.34, 0.04),
		Color3.fromRGB(233, 218, 176),
		Enum.Material.SmoothPlastic,
		0
	)
	local caseLabelGui = Instance.new("SurfaceGui")
	caseLabelGui.Name = "CaseLabelGui"
	caseLabelGui.Face = Enum.NormalId.Front
	caseLabelGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	caseLabelGui.PixelsPerStud = 70
	caseLabelGui.Enabled = false
	caseLabelGui:SetAttribute("AutomationActiveEnabled", true)
	caseLabelGui.Parent = caseLabelPlate
	local caseLabelText = Instance.new("TextLabel")
	caseLabelText.Size = UDim2.fromScale(1, 1)
	caseLabelText.BackgroundColor3 = Color3.fromRGB(245, 235, 203)
	caseLabelText.BorderSizePixel = 0
	caseLabelText.Text = "LONE STAR\nBEER"
	caseLabelText.TextColor3 = Color3.fromRGB(143, 45, 38)
	caseLabelText.Font = Enum.Font.RobotoMono
	caseLabelText.TextScaled = true
	caseLabelText.Parent = caseLabelGui
	local canIndex = 0
	for _, rowZ in ipairs({ -0.18, 0.18 }) do
		for _, columnX in ipairs({ -0.30, 0, 0.30 }) do
			canIndex += 1
			local canRotation = CFrame.Angles(0, 0, math.rad(90))
			beerCasePart(
				string.format("CaseCanBody%02d", canIndex),
				CFrame.new(columnX, 0.48, rowZ) * canRotation,
				Vector3.new(0.42, 0.18, 0.18),
				Color3.fromRGB(190, 168, 107),
				Enum.Material.Metal,
				0.04,
				Enum.PartType.Cylinder
			)
			beerCasePart(
				string.format("CaseCanTop%02d", canIndex),
				CFrame.new(columnX, 0.71, rowZ) * canRotation,
				Vector3.new(0.07, 0.15, 0.15),
				Color3.fromRGB(224, 221, 203),
				Enum.Material.Metal,
				0,
				Enum.PartType.Cylinder
			)
		end
	end
	automationInstallStation(
		"BeerBot",
		-- Put the colored setup destination in the open floor beside the desk;
		-- leaving it directly beneath the computer hid most of the pad.
		Vector3.new(baseCFrame.Position.X + 1.5, kitchenFloorTop + 0.75, baseCFrame.Position.Z),
		"Sheldon1980sComputerDesk.Desktop",
		automationColors.BeerBot,
		Vector3.new(2.5, 0.07, 2.0)
	)
end

-- HackerBot is a compact companion controller on the opposite front corner of
-- Sheldon's desk. Two articulated probes type on the real keyboard while a
-- contained cipher display and data lamps make the automated bank breach easy
-- to watch without moving through the chair, walls, or any furniture.
do
	local baseCFrame = computerDesktop.CFrame
		* CFrame.new(
			-computerDesktop.Size.X * 0.5 + 0.40,
			computerDesktop.Size.Y * 0.5 + 0.15,
			-- Keep the left-front controller wholly clear of Sheldon's dial
			-- phone at the rear-left corner. A small, intentional overhang at
			-- the player-facing desk edge reads like a clamp-mounted accessory.
			computerDesktop.Size.Z * 0.39
		)
	local model = automationModel("HackerBot", baseCFrame)
	local base = automationPart(
		model,
		"CipherDock",
		baseCFrame,
		Vector3.new(0.72, 0.24, 0.72),
		Color3.fromRGB(32, 47, 54),
		Enum.Material.Metal,
		0,
		true
	)
	model.PrimaryPart = base
	local console = automationPart(
		model,
		"CipherConsole",
		baseCFrame * CFrame.new(0, 0.37, 0.02),
		Vector3.new(0.62, 0.48, 0.56),
		Color3.fromRGB(16, 29, 34),
		Enum.Material.Metal,
		0,
		false
	)
	local screen = automationPart(
		model,
		"CipherScreen",
		-- The chair and keyboard are on the desk's +Z/player-facing side.
		-- Mount the display on that same side so it is actually visible while
		-- the robot works instead of facing the wall and dial phone.
		baseCFrame * CFrame.new(0, 0.39, 0.305),
		Vector3.new(0.50, 0.29, 0.035),
		Color3.fromRGB(3, 15, 18),
		Enum.Material.SmoothPlastic,
		0,
		false
	)
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Name = "CipherDisplay"
	screenGui.Face = Enum.NormalId.Back
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 100
	screenGui.Enabled = false
	screenGui:SetAttribute("AutomationVisibleEnabled", true)
	screenGui.Parent = screen
	local cipherText = Instance.new("TextLabel")
	cipherText.Name = "CipherText"
	cipherText.Size = UDim2.fromScale(1, 1)
	cipherText.BackgroundColor3 = Color3.fromRGB(2, 13, 15)
	cipherText.BorderSizePixel = 0
	cipherText.Text = "BANK\nREADY"
	cipherText.TextColor3 = automationColors.HackerBot
	cipherText.Font = Enum.Font.RobotoMono
	cipherText.TextScaled = true
	cipherText.Parent = screenGui
	local status = automationPart(
		model,
		"BreachStatus",
		baseCFrame * CFrame.new(0.21, 0.68, 0.10),
		Vector3.new(0.14, 0.14, 0.10),
		automationColors.HackerBot,
		Enum.Material.Neon,
		0,
		false
	)
	automationStatusLight(model, status, automationColors.HackerBot, 7)
	automationPart(
		model,
		"SignalAntenna",
		baseCFrame * CFrame.new(-0.22, 0.88, 0.10),
		Vector3.new(0.07, 0.70, 0.07),
		Color3.fromRGB(140, 155, 158),
		Enum.Material.Metal,
		0,
		false,
		Enum.PartType.Cylinder
	)

	local probeTargets = {
		computerKeyboard.CFrame * CFrame.new(-0.42, computerKeyboard.Size.Y * 0.5 + 0.16, 0.02),
		computerKeyboard.CFrame * CFrame.new(0.42, computerKeyboard.Size.Y * 0.5 + 0.16, 0.02),
	}
	for index, target in ipairs(probeTargets) do
		local side = index == 1 and -1 or 1
		local probe = automationPart(
			model,
			"TypingProbe" .. (side < 0 and "Left" or "Right"),
			target,
			Vector3.new(0.13, 0.34, 0.13),
			Color3.fromRGB(164, 181, 182),
			Enum.Material.Metal,
			0,
			false,
			Enum.PartType.Cylinder
		)
		probe:SetAttribute("AutomationHackerProbe", true)
		probe:SetAttribute("ProbeIndex", index)
		local shoulder = baseCFrame:PointToWorldSpace(Vector3.new(side * 0.20, 0.52, 0.18))
		local outsideElbow = baseCFrame:PointToWorldSpace(Vector3.new(side * 0.26, 0.66, 0.92))
		local wrist = target.Position
			- computerDesktop.CFrame.LookVector * 0.42
			+ computerDesktop.CFrame.UpVector * 0.36
		automationBeam(
			model,
			"ProbeArm" .. tostring(index),
			shoulder,
			outsideElbow,
			0.09,
			Color3.fromRGB(114, 131, 133),
			Enum.Material.Metal,
			0
		)
		automationBeam(
			model,
			"ProbeForearm" .. tostring(index),
			outsideElbow,
			wrist,
			0.09,
			Color3.fromRGB(129, 147, 149),
			Enum.Material.Metal,
			0
		)
		automationBeam(
			model,
			"ProbeWrist" .. tostring(index),
			wrist,
			probe.Position + computerDesktop.CFrame.UpVector * 0.10,
			0.08,
			Color3.fromRGB(153, 170, 171),
			Enum.Material.Metal,
			0
		)
	end

	for index = 1, 5 do
		local pulse = automationPart(
			model,
			"DataPulse" .. tostring(index),
			baseCFrame * CFrame.new(-0.24 + (index - 1) * 0.12, 0.17, 0.39),
			Vector3.new(0.07, 0.07, 0.07),
			automationColors.HackerBot,
			Enum.Material.Neon,
			1,
			false,
			Enum.PartType.Ball
		)
		pulse:SetAttribute("AutomationHackerPulse", true)
		pulse:SetAttribute("AutomationActiveTransparency", 0.05)
		pulse:SetAttribute("PulseIndex", index)
	end
	model:SetAttribute("HackingMechanism", "DualKeyboardProbe")
	model:SetAttribute("KeyboardProbeCount", 2)
	automationInstallStation(
		"HackerBot",
		Vector3.new(baseCFrame.Position.X - 1.5, kitchenFloorTop + 0.75, baseCFrame.Position.Z),
		"Sheldon1980sComputerDesk.Desktop",
		automationColors.HackerBot,
		Vector3.new(2.5, 0.07, 2.0)
	)
end

-- DishBot clamps to the back of the real double sink. Two chrome arms finish
-- over the authored dirty-dish pile without replacing the faucet or basins.
do
	-- Shift the controller toward the left basin so neither it nor its display
	-- intersects the centered ChromeFaucet. A real metal bracket spans the small
	-- vertical gap to the porcelain rim instead of leaving the controller afloat.
	local hubCFrame = kitchenSink.CFrame * CFrame.new(-0.72, 0.86, 0.68)
	local model = automationModel("DishBot", hubCFrame)
	local hub = automationPart(model, "SinkHub", hubCFrame, Vector3.new(1.0, 0.62, 0.62), Color3.fromRGB(67, 116, 115), Enum.Material.Metal, 0, true)
	model.PrimaryPart = hub
	local sinkTop = kitchenSink.Position + kitchenSink.CFrame.UpVector * (kitchenSink.Size.Y * 0.5)
	local hubBottom = hubCFrame:PointToWorldSpace(Vector3.new(0, -0.31, 0))
	automationBeam(
		model,
		"SinkMountBracket",
		Vector3.new(hubCFrame.Position.X, sinkTop.Y, hubCFrame.Position.Z),
		Vector3.new(hubCFrame.Position.X, hubBottom.Y, hubCFrame.Position.Z),
		0.24,
		Color3.fromRGB(126, 134, 131),
		Enum.Material.Metal,
		0
	)
	automationPart(model, "ControlBox", hubCFrame * CFrame.new(0, 0.48, 0), Vector3.new(0.78, 0.42, 0.52), Color3.fromRGB(218, 208, 176), Enum.Material.SmoothPlastic, 0, false)
	local status = automationPart(model, "WashLight", hubCFrame * CFrame.new(0.25, 0.72, -0.27), Vector3.new(0.15, 0.15, 0.10), automationColors.DishBot, Enum.Material.Neon, 0, false)
	automationStatusLight(model, status, automationColors.DishBot, 7)
	for index, basin in ipairs({ leftSinkBasin, rightSinkBasin }) do
		local target = basin.Position + basin.CFrame.UpVector * 0.73
		-- Carry both arms above the centered faucet, then drop through short
		-- vertical wrists over each basin. The segmented path stays attached while
		-- avoiding the real faucet even for the longer right-basin reach.
		local shoulder = hubCFrame:PointToWorldSpace(Vector3.new(index == 1 and -0.32 or 0.32, 0.55, 0))
		local wristTop = target + basin.CFrame.UpVector * 0.58
		local wristBottom = target + basin.CFrame.UpVector * 0.18
		automationBeam(model, "DishArm" .. index, shoulder, wristTop, 0.16, Color3.fromRGB(151, 158, 155), Enum.Material.Metal, 0)
		automationBeam(model, "DishWrist" .. index, wristTop, wristBottom, 0.14, Color3.fromRGB(166, 174, 171), Enum.Material.Metal, 0)
		automationPart(model, "Scrubber" .. index, CFrame.new(target), Vector3.new(0.55, 0.16, 0.55), Color3.fromRGB(232, 192, 63), Enum.Material.Fabric, 0, false, Enum.PartType.Cylinder)
		local bubble = automationPart(model, "WashBubble" .. index, CFrame.new(target + Vector3.new(0, 0.35, 0)), Vector3.new(0.36, 0.36, 0.36), Color3.fromRGB(142, 224, 242), Enum.Material.Glass, 1, false, Enum.PartType.Ball)
		bubble:SetAttribute("AutomationActiveTransparency", 0.28)
	end
	automationInstallStation(
		"DishBot",
		-- Keep the setup pad in the open kitchen aisle instead of underneath the
		-- sink/counter footprint, where its guidance color was mostly occluded.
		Vector3.new(kitchenSink.Position.X, kitchenFloorTop + 0.75, kitchenSink.Position.Z - 2.32),
		"DoublePorcelainSink",
		automationColors.DishBot,
		Vector3.new(3.4, 0.07, 2.0)
	)
end

-- TrashBot docks beside (never inside) the kitchen can. The entire anchored
-- model can safely pivot along its route and is restored to this exact home.
do
	local dockPosition = kitchenCanPosition
		+ kitchenFloor.CFrame.RightVector * 2.55
	dockPosition = Vector3.new(dockPosition.X, kitchenFloorTop + 0.58, dockPosition.Z)
	local homeCFrame = CFrame.lookAt(dockPosition, Vector3.new(kitchenCanPosition.X, dockPosition.Y, kitchenCanPosition.Z))
	local model = automationModel("TrashBot", homeCFrame)
	local base = automationPart(model, "Chassis", homeCFrame, Vector3.new(1.42, 0.42, 1.55), Color3.fromRGB(63, 80, 66), Enum.Material.Metal, 0, true)
	model.PrimaryPart = base
	automationPart(model, "Body", homeCFrame * CFrame.new(0, 0.57, 0.05), Vector3.new(1.15, 0.78, 1.05), Color3.fromRGB(168, 177, 153), Enum.Material.Metal, 0, false)
	local eye = automationPart(model, "StatusEye", homeCFrame * CFrame.new(0, 0.66, -0.54), Vector3.new(0.52, 0.20, 0.10), automationColors.TrashBot, Enum.Material.Neon, 0, false)
	automationStatusLight(model, eye, automationColors.TrashBot, 7)
	for _, side in ipairs({ -1, 1 }) do
		automationPart(model, "Wheel" .. (side < 0 and "Left" or "Right"), homeCFrame * CFrame.new(side * 0.78, -0.10, 0), Vector3.new(0.30, 0.75, 0.75), Color3.fromRGB(36, 38, 34), Enum.Material.Rubber, 0, false, Enum.PartType.Cylinder)
	end
	-- A visible lift mechanism replaces the old instant cargo pop. The arm rests
	-- over the rear rack and can extend toward either real garbage can while the
	-- paired grabbers remain visibly attached to the bag.
	local liftMast = automationPart(
		model,
		"LiftMast",
		homeCFrame * CFrame.new(-0.48, 1.00, 0.28),
		Vector3.new(0.14, 1.24, 0.14),
		Color3.fromRGB(135, 142, 135),
		Enum.Material.Metal,
		0,
		false
	)
	liftMast:SetAttribute("AutomationTrashLiftPart", true)
	local liftArmStart = homeCFrame:PointToWorldSpace(Vector3.new(-0.48, 1.58, 0.28))
	local liftArmEnd = homeCFrame:PointToWorldSpace(Vector3.new(0, 1.58, 0.28))
	local liftArm = automationBeam(
		model,
		"LiftArm",
		liftArmStart,
		liftArmEnd,
		0.14,
		Color3.fromRGB(158, 164, 157),
		Enum.Material.Metal,
		0
	)
	liftArm:SetAttribute("AutomationTrashLiftPart", true)
	for _, side in ipairs({ -1, 1 }) do
		local grabber = automationPart(
			model,
			"Grabber" .. (side < 0 and "Left" or "Right"),
			homeCFrame
				* CFrame.new(side * 0.22, 1.27, 0.28)
				* CFrame.Angles(0, 0, math.rad(side * 18)),
			Vector3.new(0.10, 0.48, 0.10),
			Color3.fromRGB(176, 181, 173),
			Enum.Material.Metal,
			0,
			false
		)
		grabber:SetAttribute("AutomationTrashLiftPart", true)
	end
	model:SetAttribute("PickupMechanism", "LiftArmAndGrabbers")
	model:SetAttribute("TrashLiftPartCount", 4)

	local cargoBag = automationPart(model, "CargoBag", homeCFrame * CFrame.new(0, 1.18, 0.34), Vector3.new(1.75, 1.70, 1.75), Color3.fromRGB(31, 34, 30), Enum.Material.Fabric, 1, false, Enum.PartType.Ball)
	cargoBag:SetAttribute("AutomationActiveTransparency", 0)
	cargoBag:SetAttribute("AutomationTrashCargoPart", true)
	local cargoBagTie = automationPart(
		model,
		"CargoBagTie",
		homeCFrame * CFrame.new(0, 2.03, 0.34),
		Vector3.new(0.35, 0.45, 0.35),
		Color3.fromRGB(24, 27, 24),
		Enum.Material.Fabric,
		1,
		false,
		Enum.PartType.Ball
	)
	cargoBagTie:SetAttribute("AutomationActiveTransparency", 0)
	cargoBagTie:SetAttribute("AutomationTrashCargoPart", true)
	model:SetAttribute("TrashCargoPartCount", 2)
	automationInstallStation(
		"TrashBot",
		dockPosition + Vector3.new(0, 0.65, 0),
		"KitchenGarbageCan",
		automationColors.TrashBot,
		Vector3.new(2.7, 0.07, 2.7)
	)
end

-- ToyFinder is a small propeller drone docked beside Missy's bed. Its scanner
-- travels to the server-selected hidden marker and returns via the mattress.
do
	local dockPlan = mattress.Position
		+ mattress.CFrame.RightVector * (mattress.Size.X * 0.5 + 1.35)
		+ mattress.CFrame.LookVector * 1.35
	local dockPosition = Vector3.new(dockPlan.X, kitchenFloorTop + 1.28, dockPlan.Z)
	local homeCFrame = CFrame.lookAt(dockPosition, Vector3.new(mattress.Position.X, dockPosition.Y, mattress.Position.Z))
	local model = automationModel("ToyFinder", homeCFrame)
	local body = automationPart(model, "DroneBody", homeCFrame, Vector3.new(1.12, 0.42, 0.82), Color3.fromRGB(224, 193, 73), Enum.Material.Metal, 0, false)
	model.PrimaryPart = body
	local scanner = automationPart(model, "Scanner", homeCFrame * CFrame.new(0, -0.27, -0.30), Vector3.new(0.38, 0.18, 0.38), automationColors.ToyFinder, Enum.Material.Neon, 0, false, Enum.PartType.Ball)
	automationStatusLight(model, scanner, automationColors.ToyFinder, 8)
	for _, specification in ipairs({
		{ "RotorLeft", Vector3.new(-0.78, 0.10, 0) },
		{ "RotorRight", Vector3.new(0.78, 0.10, 0) },
	}) do
		automationBeam(model, specification[1] .. "Strut", body.Position, homeCFrame:PointToWorldSpace(specification[2]), 0.09, Color3.fromRGB(123, 125, 116), Enum.Material.Metal, 0)
		automationPart(model, specification[1], homeCFrame * CFrame.new(specification[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.08, 0.92, 0.92), Color3.fromRGB(72, 75, 69), Enum.Material.Metal, 0, false, Enum.PartType.Cylinder)
	end
	-- Retrieval now uses a thin mechanical cable and two real claws. There is no
	-- solid neon scan rod and no featureless plush blob; runtime carries the real
	-- selected stuffed animal between these grabbers.
	local pickupCable = automationPart(
		model,
		"PickupCable",
		homeCFrame * CFrame.new(0, -0.46, -0.30),
		Vector3.new(0.035, 0.035, 0.42),
		Color3.fromRGB(54, 57, 54),
		Enum.Material.Metal,
		1,
		false
	)
	pickupCable:SetAttribute("AutomationActiveTransparency", 0.04)
	pickupCable:SetAttribute("AutomationToyPickupPart", true)
	local pickupWrist = automationPart(
		model,
		"PickupWrist",
		homeCFrame * CFrame.new(0, -0.49, -0.30),
		Vector3.new(0.045, 0.045, 0.08),
		Color3.fromRGB(125, 132, 124),
		Enum.Material.Metal,
		1,
		false
	)
	pickupWrist:SetAttribute("AutomationActiveTransparency", 0.04)
	pickupWrist:SetAttribute("AutomationToyPickupPart", true)
	for _, side in ipairs({ -1, 1 }) do
		local claw = automationPart(
			model,
			"Claw" .. (side < 0 and "Left" or "Right"),
			homeCFrame
				* CFrame.new(side * 0.13, -0.49, -0.30)
				* CFrame.Angles(0, 0, math.rad(side * 18)),
			Vector3.new(0.07, 0.32, 0.07),
			Color3.fromRGB(151, 156, 149),
			Enum.Material.Metal,
			0,
			false
		)
		claw:SetAttribute("AutomationToyPickupPart", true)
	end
	model:SetAttribute("PickupMechanism", "CableClawWithTelescopingWrist")
	model:SetAttribute("CableClawPartCount", 4)
	model:SetAttribute("UsesSolidScanBeam", false)
	automationInstallStation(
		"ToyFinder",
		Vector3.new(dockPosition.X, kitchenFloorTop + 0.65, dockPosition.Z),
		"MissyWalnutTwinBed.Mattress",
		automationColors.ToyFinder,
		Vector3.new(2.8, 0.07, 2.8)
	)
end

-- Delivery route, truck, and drop point.
local site = environment:FindFirstChild("SiteAndStreet")
local sideDriveway = site and site:FindFirstChild("SideDriveway")
local sideStreet = site and site:FindFirstChild("SideStreet")
assert(sideDriveway and sideDriveway:IsA("BasePart"), "SiteAndStreet.SideDriveway is missing")
assert(sideStreet and sideStreet:IsA("BasePart"), "SiteAndStreet.SideStreet is missing")
-- Keep the truck in a swept-clear street lane until it has passed the parked
-- station wagon, then let it pull toward the curb.  The former single straight
-- route crossed through the wagon and parked on top of the beer-crate slot.
local routeY = sideDriveway.Position.Y + 1.335
local safeLaneX = sideStreet.Position.X - sideStreet.Size.X * 0.237108
local curbStopX = sideStreet.Position.X + sideStreet.Size.X * 0.012892
local truckSpawnPosition = Vector3.new(
	safeLaneX,
	routeY,
	sideDriveway.CFrame:PointToWorldSpace(Vector3.new(0, 0, -86.605)).Z
)
local truckApproachPosition = Vector3.new(
	safeLaneX,
	routeY,
	sideDriveway.CFrame:PointToWorldSpace(Vector3.new(0, 0, -13.804)).Z
)
local truckStopPosition = Vector3.new(
	curbStopX,
	routeY,
	sideDriveway.CFrame:PointToWorldSpace(Vector3.new(0, 0, 4.395)).Z
)
-- X=-1.28 resolves to world X=-28.0 in this build: the swept-safe centerline
-- that clears both the curb and the house wall for the widest delivery crate.
local deliveryDropPosition = sideDriveway.CFrame:PointToWorldSpace(Vector3.new(-1.28, 0.485, 6.895))
local route = Instance.new("Folder")
route.Name = "Route"
route.Parent = delivery
local truckSpawn = part(route, "TruckSpawn", truckSpawnPosition, Vector3.one, Color3.new(1, 1, 1), nil, 1)
local truckApproach = part(route, "TruckApproach", truckApproachPosition, Vector3.one, Color3.new(1, 1, 1), nil, 1)
local truckStop = part(route, "TruckStop", truckStopPosition, Vector3.one, Color3.new(1, 1, 1), nil, 1)
local truckExit = part(route, "TruckExit", truckSpawnPosition, Vector3.one, Color3.new(1, 1, 1), nil, 1)
local dropZone = part(
	delivery,
	"DeliveryDropZone",
	deliveryDropPosition,
	Vector3.new(5.5, 0.1, 5.5),
	Color3.fromRGB(244, 191, 67),
	Enum.Material.Neon,
	0.72
)
dropZone.CanQuery = true

local truck = Instance.new("Model")
truck.Name = "CooperDeliveryTruck"
truck.Parent = delivery
local chassis = part(
	truck,
	"Chassis",
	truckSpawn.Position,
	Vector3.new(6.2, 1.0, 13.0),
	Color3.fromRGB(42, 58, 67),
	Enum.Material.Metal,
	0
)
truck.PrimaryPart = chassis
part(truck, "Cab", truckSpawn.Position + Vector3.new(0, 2.2, -3.7), Vector3.new(5.8, 3.6, 4.5), Color3.fromRGB(222, 198, 134), Enum.Material.Metal, 0)
part(truck, "CargoBox", truckSpawn.Position + Vector3.new(0, 3.0, 2.5), Vector3.new(6.0, 5.0, 7.4), Color3.fromRGB(236, 229, 204), Enum.Material.Metal, 0)
part(truck, "Windshield", truckSpawn.Position + Vector3.new(0, 2.75, -6.02), Vector3.new(4.7, 1.65, 0.12), Color3.fromRGB(92, 139, 158), Enum.Material.Glass, 0.15)
for _, wheelOffset in ipairs({
	Vector3.new(-3.15, -0.15, -3.7),
	Vector3.new(3.15, -0.15, -3.7),
	Vector3.new(-3.15, -0.15, 3.8),
	Vector3.new(3.15, -0.15, 3.8),
}) do
	local wheel = part(truck, "Wheel", truckSpawn.Position + wheelOffset, Vector3.new(0.9, 2.3, 2.3), Color3.fromRGB(25, 25, 24), Enum.Material.Rubber, 0)
	wheel.Shape = Enum.PartType.Cylinder
end
local sign = part(truck, "DeliverySign", truckSpawn.Position + Vector3.new(-3.06, 3.2, 2.4), Vector3.new(0.08, 2.2, 5.3), Color3.fromRGB(211, 65, 48), Enum.Material.SmoothPlastic, 0)
local signGui = Instance.new("SurfaceGui")
signGui.Name = "Sign"
signGui.Face = Enum.NormalId.Left
signGui.AlwaysOnTop = false
signGui.Parent = sign
local signText = Instance.new("TextLabel")
signText.Size = UDim2.fromScale(1, 1)
signText.BackgroundTransparency = 1
signText.Text = "MEDFORD" .. string.char(10) .. "DELIVERY"
signText.TextColor3 = Color3.fromRGB(255, 245, 208)
signText.Font = Enum.Font.GothamBlack
signText.TextScaled = true
signText.Parent = signGui
truck:PivotTo(CFrame.new(truckSpawn.Position))
-- Author the parked-at-spawn truck fully hidden. The runtime controller makes
-- both its physical parts and sign visible only while a delivery is active.
for _, descendant in ipairs(truck:GetDescendants()) do
	if descendant:IsA("BasePart") then
		descendant.Transparency = 1
		descendant.CanCollide = false
		descendant.CanTouch = false
		descendant.CanQuery = false
	elseif descendant:IsA("SurfaceGui") then
		descendant.Enabled = false
	end
end
truck:SetAttribute("Hidden", true)

-- Local clients update this display to their own saved percentage.
local garage = environment:FindFirstChild("DetachedGarage")
local machine = garage and garage:FindFirstChild("CooperTimeMachine")
if machine then
	for _, descendant in ipairs(machine:GetDescendants()) do
		-- Retire prompts from the superseded task-machine implementation.
		if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("FamilyTaskLegacyMachinePrompt") == true then
			descendant.Enabled = false
		end
	end
end
local screen = machine and (machine:FindFirstChild("CRTScreen") or machine:FindFirstChild("CRTMonitor"))
if screen and screen:IsA("BasePart") then
	local oldGui = screen:FindFirstChild("FamilyTaskProgress")
	if oldGui then
		oldGui:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FamilyTaskProgress"
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.Name = "Progress"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(5, 18, 10)
	label.TextColor3 = Color3.fromRGB(91, 255, 137)
	label.Font = Enum.Font.RobotoMono
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = "TIME MACHINE" .. string.char(10) .. "0% COMPLETE"
	label.Parent = gui
end

root:SetAttribute("Ready", true)
root:SetAttribute("StationCount", 13)
root:SetAttribute("HiddenLocationCount", #Config.HiddenLocations)
root:SetAttribute("TaskAutomationRobotCount", 5)
print("[CooperFamilyTaskWorld] Installed five rotating tasks, five automation robots, income boombox, owner-safe truck delivery, and machine bay")
