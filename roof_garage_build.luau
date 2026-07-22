-- Idempotent installer for the Cooper house roof closure and the existing
-- detached garage's Georgie-and-Mandy living conversion.
--
-- Designed against TanishFirstGame / CooperHouseEnvironment on 2026-07-11.
-- Running this twice atomically replaces only the three upgrade models created here.

local INSTALL_VERSION = "2026-07-11.3"

local GARAGE_DOOR_CONTROLLER_SOURCE = [==[
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local doorModel = script.Parent
local panelsFolder = doorModel:WaitForChild("Panels")
local collisionBlocker = doorModel:WaitForChild("CollisionBlocker")
local promptMount = doorModel:WaitForChild("PromptMount")
local prompt = promptMount:WaitForChild("ProximityPrompt")

local MOVE_TIME = 1.55

local function requireNumberAttribute(name)
	local value = doorModel:GetAttribute(name)
	assert(type(value) == "number", doorModel:GetFullName() .. " is missing numeric attribute " .. name)
	return value
end

local doorCenterX = requireNumberAttribute("DoorCenterX")
local doorPlaneZ = requireNumberAttribute("DoorPlaneZ")
local doorTravelZSign = requireNumberAttribute("DoorTravelZSign")
local openingBottomY = requireNumberAttribute("OpeningBottomY")
local overheadY = requireNumberAttribute("OverheadY")
local panelHeight = requireNumberAttribute("PanelHeight")
local trackRadius = requireNumberAttribute("TrackRadius")
local frontRun = requireNumberAttribute("FrontRun")
local travelDistance = requireNumberAttribute("TravelDistance")

-- Repair absolute track data if the complete garage was translated after this
-- door was authored. The blocker moves with the model; attributes/CFrameValues
-- do not.
local expectedBlockerPosition = Vector3.new(
	doorCenterX,
	openingBottomY + collisionBlocker.Size.Y * 0.5,
	doorPlaneZ + doorTravelZSign * 0.08
)
local relocationOffset = collisionBlocker.Position - expectedBlockerPosition
if relocationOffset.Magnitude > 0.01 then
	doorCenterX += relocationOffset.X
	doorPlaneZ += relocationOffset.Z
	openingBottomY += relocationOffset.Y
	overheadY += relocationOffset.Y
	doorModel:SetAttribute("DoorCenterX", doorCenterX)
	doorModel:SetAttribute("DoorPlaneZ", doorPlaneZ)
	doorModel:SetAttribute("OpeningBottomY", openingBottomY)
	doorModel:SetAttribute("OpeningTopY", requireNumberAttribute("OpeningTopY") + relocationOffset.Y)
	doorModel:SetAttribute("OverheadY", overheadY)
end

assert(
	panelHeight > 0
		and trackRadius > 0
		and frontRun >= 0
		and travelDistance > 0
		and math.abs(math.abs(doorTravelZSign) - 1) < 0.001,
	"Garage-door track geometry is invalid"
)

local panels = {}
for _, child in ipairs(panelsFolder:GetChildren()) do
	if child:IsA("BasePart") then
		local index = child:GetAttribute("PanelIndex")
		local closedPose = child:FindFirstChild("ClosedPose")
		local openPose = child:FindFirstChild("OpenPose")
		assert(type(index) == "number", child:GetFullName() .. " is missing PanelIndex")
		assert(closedPose and closedPose:IsA("CFrameValue"), child:GetFullName() .. " is missing ClosedPose")
		assert(openPose and openPose:IsA("CFrameValue"), child:GetFullName() .. " is missing OpenPose")
		local repairedClosedPose = closedPose.Value + relocationOffset
		local repairedOpenPose = openPose.Value + relocationOffset
		closedPose.Value = repairedClosedPose
		openPose.Value = repairedOpenPose
		table.insert(panels, {
			part = child,
			index = index,
			closedPose = repairedClosedPose,
			openPose = repairedOpenPose,
		})
	end
end

table.sort(panels, function(a, b)
	return a.index < b.index
end)
assert(#panels > 0, "InteractiveSectionalGarageDoor has no door panels")
for expectedIndex, panelData in ipairs(panels) do
	assert(panelData.index == expectedIndex, "Garage-door PanelIndex values must be consecutive starting at 1")
end

local verticalDistance = overheadY - trackRadius - openingBottomY
local curveDistance = trackRadius * math.pi * 0.5
assert(verticalDistance >= (panelHeight * (#panels - 0.5)) - 0.02, "Garage-door curve begins below a closed panel")

local busy = false
local isOpen = doorModel:GetAttribute("IsOpen") == true
local currentAlpha = isOpen and 1 or 0

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.FilterDescendantsInstances = { doorModel }

local ignoredDoorwayStructure = {}
for _, name in ipairs({
	"GarageFoundation",
	"GarageDoorHeader",
	"GarageFrontLeft",
	"GarageFrontRight",
	"FrontLeftInteriorReturn",
	"FrontRightInteriorReturn",
}) do
	local part = doorModel.Parent:FindFirstChild(name, true)
	if part and part:IsA("BasePart") then
		ignoredDoorwayStructure[part] = true
	end
end
local living = doorModel.Parent:FindFirstChild("GeorgieMandyLivingUpgrade_V1")
local sealedFloor = living and living:FindFirstChild("SealedConcreteFloor")
if sealedFloor and sealedFloor:IsA("BasePart") then
	ignoredDoorwayStructure[sealedFloor] = true
end

local function isMovableDoorwayObstruction(part)
	local ancestor = part
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Tool")
			or ancestor.Name == "CooperRedYellowTrike"
			or ancestor:GetAttribute("CooperPickable") == true
		then
			return true
		end
		if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
			return true
		end
		ancestor = ancestor.Parent
	end
	return part.CanCollide and not ignoredDoorwayStructure[part]
end

local function isDoorwayObstructed()
	local querySize = collisionBlocker.Size + Vector3.new(0.60, 0.30, 1.50)
	for _, part in ipairs(Workspace:GetPartBoundsInBox(collisionBlocker.CFrame, querySize, overlapParams)) do
		if isMovableDoorwayObstruction(part) then
			return true
		end
	end
	return false
end

local function trackPose(panelData, alpha)
	if alpha <= 0 then
		return panelData.closedPose
	elseif alpha >= 1 then
		return panelData.openPose
	end

	local distanceAlongTrack = ((panelData.index - 0.5) * panelHeight) + (travelDistance * alpha)
	if distanceAlongTrack <= verticalDistance then
		return CFrame.new(
			doorCenterX,
			openingBottomY + distanceAlongTrack,
			doorPlaneZ
		)
	elseif distanceAlongTrack < verticalDistance + curveDistance then
		local angle = (distanceAlongTrack - verticalDistance) / trackRadius
		local y = overheadY - trackRadius + (trackRadius * math.sin(angle))
		local z = doorPlaneZ + (doorTravelZSign * (trackRadius - (trackRadius * math.cos(angle))))
		return CFrame.new(doorCenterX, y, z) * CFrame.Angles(doorTravelZSign * angle, 0, 0)
	else
		local horizontalDistance = distanceAlongTrack - verticalDistance - curveDistance
		return CFrame.new(
			doorCenterX,
			overheadY,
			doorPlaneZ + (doorTravelZSign * (trackRadius + horizontalDistance))
		) * CFrame.Angles(doorTravelZSign * math.rad(90), 0, 0)
	end
end

local function applyAlpha(alpha)
	currentAlpha = math.clamp(alpha, 0, 1)
	for _, panelData in ipairs(panels) do
		if panelData.part.Parent then
			panelData.part.CFrame = trackPose(panelData, currentAlpha)
			-- The single blocker owns collision. Moving sectional panels never trap or fling characters.
			panelData.part.CanCollide = false
		end
	end
end

local function refreshPrompt()
	prompt.ActionText = isOpen and "Close garage" or "Open garage"
	prompt.ObjectText = "Georgie & Mandy's garage"
	doorModel:SetAttribute("DoorState", isOpen and "Open" or "Closed")
	doorModel:SetAttribute("IsOpen", isOpen)
	doorModel:SetAttribute("TravelAlpha", isOpen and 1 or 0)
end

local function animateTo(targetAlpha, monitorObstructions)
	targetAlpha = math.clamp(targetAlpha, 0, 1)
	if math.abs(targetAlpha - currentAlpha) < 0.001 then
		applyAlpha(targetAlpha)
		return true, false
	end

	local driver = Instance.new("NumberValue")
	driver.Name = "GarageDoorTravelDriver"
	driver.Value = currentAlpha
	local connection
	local tween
	local obstructed = false
	local checkingObstruction = false

	local success, completedOrError = xpcall(function()
		local duration = math.max(0.18, MOVE_TIME * math.abs(targetAlpha - currentAlpha))
		tween = TweenService:Create(
			driver,
			TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
			{ Value = targetAlpha }
		)
		connection = driver.Changed:Connect(function(value)
			applyAlpha(value)
			if monitorObstructions and not obstructed and not checkingObstruction then
				checkingObstruction = true
				local querySucceeded, blocked = pcall(isDoorwayObstructed)
				checkingObstruction = false
				if querySucceeded and blocked then
					obstructed = true
					tween:Cancel()
				end
			end
		end)
		tween:Play()
		local playbackState = tween.Completed:Wait()
		return playbackState == Enum.PlaybackState.Completed
	end, function(message)
		return debug.traceback(tostring(message), 2)
	end)

	if connection then
		connection:Disconnect()
	end
	if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
		tween:Cancel()
	end
	driver:Destroy()

	if not success then
		error(completedOrError, 0)
	end
	return completedOrError, obstructed
end

local function moveDoor(open)
	if busy or open == isOpen then
		return
	end

	if not open and isDoorwayObstructed() then
		doorModel:SetAttribute("DoorState", "Blocked")
		prompt.ActionText = "Doorway blocked"
		task.delay(0.9, function()
			if doorModel.Parent and not busy then
				refreshPrompt()
			end
		end)
		return
	end

	busy = true
	prompt.Enabled = false
	collisionBlocker.CanCollide = false
	doorModel:SetAttribute("DoorState", open and "Opening" or "Closing")

	local finalOpen = isOpen
	local success, transitionError = xpcall(function()
		local completed, obstructed = animateTo(open and 1 or 0, not open)
		if not open and (obstructed or isDoorwayObstructed()) then
			doorModel:SetAttribute("DoorState", "Blocked")
			doorModel:SetAttribute("LastDoorIssue", "Obstruction detected; reopened safely")
			local recovered = animateTo(1, false)
			assert(recovered, "Garage door could not finish its safety reopen")
			finalOpen = true
			return
		end
		assert(completed, "Garage-door tween was cancelled before completion")
		applyAlpha(open and 1 or 0)
		finalOpen = open
	end, function(message)
		return debug.traceback(tostring(message), 2)
	end)

	if not success then
		warn("Georgie garage door recovered from a transition error: " .. transitionError)
		doorModel:SetAttribute("LastDoorIssue", transitionError)
		-- A failed transition always fails open so nobody can be trapped.
		finalOpen = true
		local recovered, recoveryError = pcall(applyAlpha, 1)
		if not recovered then
			warn("Garage-door fail-open pose also failed: " .. tostring(recoveryError))
		end
	end

	isOpen = finalOpen
	for _, panelData in ipairs(panels) do
		if panelData.part.Parent then
			panelData.part.CanCollide = false
		end
	end
	collisionBlocker.CanCollide = not isOpen
	refreshPrompt()
	prompt.Enabled = true
	busy = false
end

applyAlpha(currentAlpha)
collisionBlocker.CanCollide = not isOpen
refreshPrompt()

prompt.Triggered:Connect(function()
	moveDoor(not isOpen)
end)
]==]

local environment = workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment model is required")

local house = environment:FindFirstChild("CooperHouse")
assert(house and house:IsA("Model"), "CooperHouse model is required")

local structure = house:FindFirstChild("Structure")
assert(structure and structure:IsA("Model"), "CooperHouse.Structure model is required")

local garage = environment:FindFirstChild("DetachedGarage")
assert(garage and garage:IsA("Model"), "Existing DetachedGarage shell is required")

local function stageModel(parent, finalName)
	local stagingName = "__" .. finalName .. "_Staging"
	local abandonedStaging = parent:FindFirstChild(stagingName)
	if abandonedStaging then
		abandonedStaging:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = stagingName
	model:SetAttribute("InstallerVersion", INSTALL_VERSION)
	model.Parent = parent
	return model
end

local function commitModel(parent, stagedModel, finalName)
	assert(stagedModel.Parent == parent, "Cannot commit a detached staging model: " .. finalName)
	local previous = parent:FindFirstChild(finalName)
	if previous and previous ~= stagedModel then
		previous:Destroy()
	end
	stagedModel.Name = finalName
end

local function requirePart(parent, name)
	local value = parent:FindFirstChild(name)
	assert(value and value:IsA("BasePart"), parent:GetFullName() .. "." .. name .. " is required")
	return value
end

local function makePart(parent, name, size, cframe, color, material, options)
	options = options or {}
	local part = Instance.new(options.ClassName or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = options.Anchored ~= false
	part.CanCollide = options.CanCollide ~= false
	part.CanTouch = options.CanTouch == true
	part.CanQuery = options.CanQuery ~= false
	part.CastShadow = options.CastShadow ~= false
	part.Transparency = options.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if options.Shape and part:IsA("Part") then
		part.Shape = options.Shape
	end
	part.Parent = parent
	return part
end

local function makeSeat(parent, name, size, cframe, color, material)
	local seat = Instance.new("Seat")
	seat.Name = name
	seat.Size = size
	seat.CFrame = cframe
	seat.Color = color
	seat.Material = material
	seat.Anchored = true
	seat.CanCollide = true
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	return seat
end

local function addPointLight(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = part
	return light
end

local function addDoorPanelFace(panel, index, count)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PanelFace"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(960, 140)
	gui.LightInfluence = 0.45
	gui.Parent = panel

	local field = Instance.new("Frame")
	field.Name = "PaintedPanel"
	field.BackgroundColor3 = Color3.fromRGB(225, 216, 190)
	field.BorderColor3 = Color3.fromRGB(112, 100, 77)
	field.BorderSizePixel = 8
	field.Size = UDim2.fromScale(1, 1)
	field.Parent = gui

	for insetIndex = 1, 4 do
		local inset = Instance.new("Frame")
		inset.Name = "Inset" .. insetIndex
		inset.BackgroundColor3 = Color3.fromRGB(207, 197, 172)
		inset.BorderColor3 = Color3.fromRGB(152, 137, 105)
		inset.BorderSizePixel = 4
		inset.Position = UDim2.fromScale(0.035 + ((insetIndex - 1) * 0.245), 0.19)
		inset.Size = UDim2.fromScale(0.195, 0.62)
		inset.Parent = field
	end

	if index == 1 then
		local handle = Instance.new("Frame")
		handle.Name = "PullHandle"
		handle.BackgroundColor3 = Color3.fromRGB(73, 67, 56)
		handle.BorderSizePixel = 0
		handle.AnchorPoint = Vector2.new(0.5, 0.5)
		handle.Position = UDim2.fromScale(0.5, 0.5)
		handle.Size = UDim2.fromScale(0.12, 0.15)
		handle.Parent = field
	end
	panel:SetAttribute("SectionCount", count)
end

local function addPose(panel, name, value)
	local pose = Instance.new("CFrameValue")
	pose.Name = name
	pose.Value = value
	pose.Parent = panel
end

local function makeBeamBetween(parent, name, pointA, pointB, thickness, color, material)
	local length = (pointB - pointA).Magnitude
	assert(length > 0.01, name .. " beam endpoints overlap")
	return makePart(
		parent,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt((pointA + pointB) * 0.5, pointB),
		color,
		material,
		{ CanCollide = false }
	)
end

local function roofUndersideEndpoint(roof, positiveLocalZ)
	return roof.CFrame:PointToWorldSpace(Vector3.new(
		0,
		-roof.Size.Y * 0.5,
		(positiveLocalZ and 1 or -1) * roof.Size.Z * 0.5
	))
end

local function roofTopEndpoint(roof, positiveLocalZ)
	return roof.CFrame:PointToWorldSpace(Vector3.new(
		0,
		roof.Size.Y * 0.5,
		(positiveLocalZ and 1 or -1) * roof.Size.Z * 0.5
	))
end

local function interpolateRoofUndersideY(roof, worldZ)
	local pointA = roofUndersideEndpoint(roof, false)
	local pointB = roofUndersideEndpoint(roof, true)
	local denominator = pointB.Z - pointA.Z
	assert(math.abs(denominator) > 0.01, roof:GetFullName() .. " has no usable Z run")
	local alpha = (worldZ - pointA.Z) / denominator
	return pointA.Y + ((pointB.Y - pointA.Y) * alpha)
end

-- HOUSE ROOF CLOSURE -------------------------------------------------------

local frontRoof = requirePart(structure, "MainRoofFront")
local backRoof = requirePart(structure, "MainRoofBack")
local leftWall = requirePart(structure, "LeftExteriorWall")
local rightFrontWall = requirePart(structure, "RightExteriorWallFront")
local rightBackWall = requirePart(structure, "RightExteriorWallBack")
local fasciaReference = requirePart(structure, "FrontFasciaLeft")
local leftPorchReturn = requirePart(structure, "LeftPorchReturn")
local rightPorchReturn = requirePart(structure, "RightPorchReturn")
local leftBayFront = requirePart(structure, "LeftBaySillWall")
local porchFront = requirePart(structure, "PorchCenterWall")
local rightBayFront = requirePart(structure, "RightBaySillWall")
local backWallReference = requirePart(structure, "BackWallRight")
local porchRoof = requirePart(structure, "PorchRoof")
local wingFrontRoof = requirePart(structure, "ProjectingWingRoofFront")
local wingBackRoof = requirePart(structure, "ProjectingWingRoofBack")

-- Preflight every referenced shell part before staging any of the three upgrades.
-- If the expected live build ever changes, the installer fails without leaving
-- a half-rebuilt roof or garage behind.
local foundation = requirePart(garage, "GarageFoundation")
local garageLeftWall = requirePart(garage, "GarageLeftWall")
local garageRightWall = requirePart(garage, "GarageRightWall")
local garageBackWall = requirePart(garage, "GarageBackWall")
local garageFrontLeft = requirePart(garage, "GarageFrontLeft")
local garageFrontRight = requirePart(garage, "GarageFrontRight")
local garageFrontRoof = requirePart(garage, "GarageRoofFront")
local garageBackRoof = requirePart(garage, "GarageRoofBack")
local garageHeader = requirePart(garage, "GarageDoorHeader")

local roofClosure = stageModel(structure, "RealisticRoofClosure_V1")
roofClosure:SetAttribute("Purpose", "Closes asymmetric main and wing gables and finishes ridge, rake, and eave gaps without replacing the roof")

local wallTop = math.max(
	leftWall.Position.Y + (leftWall.Size.Y * 0.5),
	rightFrontWall.Position.Y + (rightFrontWall.Size.Y * 0.5),
	rightBackWall.Position.Y + (rightBackWall.Size.Y * 0.5)
)

local frontEave = roofUndersideEndpoint(frontRoof, false)
local frontRidge = roofUndersideEndpoint(frontRoof, true)
local backRidge = roofUndersideEndpoint(backRoof, false)
local backEave = roofUndersideEndpoint(backRoof, true)
local ridgeZ = (frontRidge.Z + backRidge.Z) * 0.5
assert(frontRidge.Y - wallTop > 3 and backRidge.Y - wallTop > 3, "Main roof geometry did not produce a usable gable")

local function makeGableHalf(parent, name, x, eavePoint, ridgePoint, baseY, thickness, highAtPositiveZ, wallReference)
	local run = math.abs(ridgePoint.Z - eavePoint.Z)
	local bottomY = baseY - 0.08
	local topY = ridgePoint.Y + 0.08
	local height = topY - bottomY
	assert(run > 0.25 and height > 0.25, name .. " has invalid gable geometry")
	local midZ = (ridgePoint.Z + eavePoint.Z) * 0.5
	local cframe = CFrame.new(x, (bottomY + topY) * 0.5, midZ)
	if not highAtPositiveZ then
		cframe = cframe * CFrame.Angles(0, math.rad(180), 0)
	end
	local wedge = makePart(
		parent,
		name,
		Vector3.new(thickness, height, run),
		cframe,
		wallReference.Color,
		wallReference.Material,
		{ ClassName = "WedgePart" }
	)
	wedge:SetAttribute("HighEnd", highAtPositiveZ and "+Z" or "-Z")
	return wedge
end

local function addAtticVent(parent, sideName, x, outwardSign)
	local ventColor = Color3.fromRGB(62, 57, 48)
	local ventX = x + (outwardSign * 0.47)
	makePart(parent, sideName .. "AtticVentRecess", Vector3.new(0.10, 1.70, 3.60), CFrame.new(ventX, wallTop + 2.65, ridgeZ), ventColor, Enum.Material.Wood, { CanCollide = false })
	for slot = -3, 3 do
		makePart(parent, sideName .. "VentLouver" .. (slot + 4), Vector3.new(0.14, 0.11, 3.12), CFrame.new(ventX + (outwardSign * 0.03), wallTop + 2.65 + (slot * 0.20), ridgeZ), Color3.fromRGB(143, 132, 109), Enum.Material.Wood, { CanCollide = false })
	end
end

local function closeGablePair(parent, sideName, x, outwardSign, wallReference, baseY, pairFrontEave, pairFrontRidge, pairBackEave, pairBackRidge, bandReference, includeVent)
	local thickness = math.max(0.72, wallReference.Size.X)
	makeGableHalf(parent, sideName .. "FrontGableInfill", x, pairFrontEave, pairFrontRidge, baseY, thickness, true, wallReference)
	makeGableHalf(parent, sideName .. "BackGableInfill", x, pairBackEave, pairBackRidge, baseY, thickness, false, wallReference)
	makePart(
		parent,
		sideName .. "GableBottomBand",
		Vector3.new(thickness + 0.12, 0.34, math.abs(pairBackEave.Z - pairFrontEave.Z)),
		CFrame.new(x + (outwardSign * 0.05), baseY + 0.08, (pairFrontEave.Z + pairBackEave.Z) * 0.5),
		bandReference.Color,
		bandReference.Material,
		{ CanCollide = false }
	)
	if includeVent then
		addAtticVent(parent, sideName, x, outwardSign)
	end
end

closeGablePair(roofClosure, "Left", leftWall.Position.X, -1, leftWall, wallTop, frontEave, frontRidge, backEave, backRidge, fasciaReference, true)
closeGablePair(roofClosure, "Right", rightFrontWall.Position.X, 1, rightFrontWall, wallTop, frontEave, frontRidge, backEave, backRidge, fasciaReference, true)

local wingFrontEave = roofUndersideEndpoint(wingFrontRoof, false)
local wingFrontRidge = roofUndersideEndpoint(wingFrontRoof, true)
local wingBackRidge = roofUndersideEndpoint(wingBackRoof, false)
local wingBackEave = roofUndersideEndpoint(wingBackRoof, true)
closeGablePair(roofClosure, "ProjectingWingInner", rightPorchReturn.Position.X, -1, rightPorchReturn, wallTop, wingFrontEave, wingFrontRidge, wingBackEave, wingBackRidge, fasciaReference, false)
closeGablePair(roofClosure, "ProjectingWingOuter", rightFrontWall.Position.X, 1, rightFrontWall, wallTop, wingFrontEave, wingFrontRidge, wingBackEave, wingBackRidge, fasciaReference, false)

local function finishRoofRakes(parent, roof, label, leftWallX, rightWallX, trimReference)
	local roofHalfX = roof.Size.X * 0.5
	for _, side in ipairs({ -1, 1 }) do
		local sideName = side < 0 and "Left" or "Right"
		local wallX = side < 0 and leftWallX or rightWallX
		local outerX = roof.Position.X + (side * roofHalfX)
		local overhang = math.abs(outerX - wallX)
		local soffitCenterWorldX = (outerX + wallX) * 0.5
		local soffitLocalX = soffitCenterWorldX - roof.Position.X

		makePart(
			parent,
			label .. sideName .. "RakeFascia",
			Vector3.new(0.46, roof.Size.Y + 0.24, roof.Size.Z + 0.30),
			roof.CFrame * CFrame.new(side * (roofHalfX + 0.08), 0, 0),
			trimReference.Color,
			trimReference.Material,
			{ CanCollide = false }
		)

		if overhang > 0.4 then
			makePart(
				parent,
				label .. sideName .. "RakeSoffit",
				Vector3.new(overhang, 0.18, roof.Size.Z - 0.20),
				roof.CFrame * CFrame.new(soffitLocalX, -(roof.Size.Y * 0.5) - 0.10, 0),
				Color3.fromRGB(221, 213, 192),
				Enum.Material.WoodPlanks,
				{ CanCollide = false }
			)
		end
	end
end

local function addEaveFinish(parent, label, roof, wallZ, xA, xB, baseY, trimReference, positiveLocalZEave)
	local eave = roofUndersideEndpoint(roof, positiveLocalZEave)
	local width = math.abs(xB - xA)
	local depth = math.abs(wallZ - eave.Z)
	if width < 0.25 or depth < 0.12 then
		return
	end

	makePart(
		parent,
		label .. "Soffit",
		Vector3.new(width, 0.18, depth + 0.10),
		CFrame.new((xA + xB) * 0.5, baseY - 0.09, (wallZ + eave.Z) * 0.5),
		Color3.fromRGB(221, 213, 192),
		Enum.Material.WoodPlanks,
		{ CanCollide = false }
	)

	local roofYAtWall = interpolateRoofUndersideY(roof, wallZ)
	local closureBottom = baseY - 0.08
	local closureTop = math.max(baseY + 0.16, roofYAtWall + 0.08)
	makePart(
		parent,
		label .. "WallTopClosure",
		Vector3.new(width, closureTop - closureBottom, 0.20),
		CFrame.new((xA + xB) * 0.5, (closureBottom + closureTop) * 0.5, wallZ),
		trimReference.Color,
		trimReference.Material,
		{ CanCollide = false }
	)
end

local function addRidgeFlashing(parent, label, frontSlope, backSlope)
	local frontTopRidge = roofTopEndpoint(frontSlope, true)
	local backTopRidge = roofTopEndpoint(backSlope, false)
	local width = math.min(frontSlope.Size.X, backSlope.Size.X) + 0.30
	local pointA = Vector3.new(frontSlope.Position.X, frontTopRidge.Y + 0.08, frontTopRidge.Z)
	local pointB = Vector3.new(backSlope.Position.X, backTopRidge.Y + 0.08, backTopRidge.Z)
	local span = (pointB - pointA).Magnitude
	makePart(
		parent,
		label .. "RidgeFlashing",
		Vector3.new(width, 0.22, span + 0.55),
		CFrame.lookAt((pointA + pointB) * 0.5, pointB),
		frontSlope.Color,
		frontSlope.Material,
		{ CanCollide = false }
	)
end

finishRoofRakes(roofClosure, frontRoof, "MainFrontSlope", leftWall.Position.X, rightFrontWall.Position.X, fasciaReference)
finishRoofRakes(roofClosure, backRoof, "MainBackSlope", leftWall.Position.X, rightFrontWall.Position.X, fasciaReference)
finishRoofRakes(roofClosure, wingFrontRoof, "WingFrontSlope", rightPorchReturn.Position.X, rightFrontWall.Position.X, fasciaReference)
finishRoofRakes(roofClosure, wingBackRoof, "WingBackSlope", rightPorchReturn.Position.X, rightFrontWall.Position.X, fasciaReference)

addEaveFinish(roofClosure, "LeftBayFrontEave", frontRoof, leftBayFront.Position.Z, leftWall.Position.X, leftPorchReturn.Position.X, wallTop, fasciaReference, false)
addEaveFinish(roofClosure, "PorchFrontEave", porchRoof, porchFront.Position.Z, leftPorchReturn.Position.X, rightPorchReturn.Position.X, wallTop, fasciaReference, false)
addEaveFinish(roofClosure, "ProjectingWingFrontEave", wingFrontRoof, rightBayFront.Position.Z, rightPorchReturn.Position.X, rightFrontWall.Position.X, wallTop, fasciaReference, false)
addEaveFinish(roofClosure, "MainBackEave", backRoof, backWallReference.Position.Z, leftWall.Position.X, rightBackWall.Position.X, wallTop, fasciaReference, true)

addRidgeFlashing(roofClosure, "Main", frontRoof, backRoof)
addRidgeFlashing(roofClosure, "ProjectingWing", wingFrontRoof, wingBackRoof)

-- GEORGIE AND MANDY GARAGE CONVERSION ------------------------------------

local living = stageModel(garage, "GeorgieMandyLivingUpgrade_V1")
living:SetAttribute("Residents", "Georgie, Mandy, and baby CeeCee")
living:SetAttribute("Era", "early 1990s")

local centerX = foundation.Position.X
local centerZ = foundation.Position.Z
local floorY = foundation.Position.Y + (foundation.Size.Y * 0.5)
local innerWidth = foundation.Size.X - 0.75
local innerDepth = foundation.Size.Z - 0.75
local innerLeftX = centerX - (innerWidth * 0.5)
local innerRightX = centerX + (innerWidth * 0.5)
local innerFrontZ = centerZ - (innerDepth * 0.5)
local innerBackZ = centerZ + (innerDepth * 0.5)
local garageWallTop = math.min(
	garageLeftWall.Position.Y + (garageLeftWall.Size.Y * 0.5),
	garageRightWall.Position.Y + (garageRightWall.Size.Y * 0.5)
)
local drywallHeight = garageWallTop - floorY - 0.16
local drywallCenterY = floorY + (drywallHeight * 0.5)

-- Finished floor, insulated walls, ceiling, and baseboards make the original
-- utility shell read as a converted starter apartment.
makePart(living, "SealedConcreteFloor", Vector3.new(innerWidth, 0.10, innerDepth), CFrame.new(centerX, floorY + 0.05, centerZ), Color3.fromRGB(130, 121, 106), Enum.Material.Concrete)
makePart(living, "LeftInteriorDrywall", Vector3.new(0.12, drywallHeight, innerDepth), CFrame.new(innerLeftX, drywallCenterY, centerZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "RightInteriorDrywall", Vector3.new(0.12, drywallHeight, innerDepth), CFrame.new(innerRightX, drywallCenterY, centerZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "BackInteriorDrywall", Vector3.new(innerWidth, drywallHeight, 0.12), CFrame.new(centerX, drywallCenterY, innerBackZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "FinishedCeiling", Vector3.new(innerWidth, 0.16, innerDepth), CFrame.new(centerX, garageWallTop - 0.08, centerZ), Color3.fromRGB(236, 231, 218), Enum.Material.SmoothPlastic)
makePart(living, "LeftBaseboard", Vector3.new(0.16, 0.38, innerDepth), CFrame.new(innerLeftX + 0.08, floorY + 0.22, centerZ), Color3.fromRGB(116, 86, 59), Enum.Material.Wood, { CanCollide = false })
makePart(living, "RightBaseboard", Vector3.new(0.16, 0.38, innerDepth), CFrame.new(innerRightX - 0.08, floorY + 0.22, centerZ), Color3.fromRGB(116, 86, 59), Enum.Material.Wood, { CanCollide = false })
makePart(living, "BackBaseboard", Vector3.new(innerWidth, 0.38, 0.16), CFrame.new(centerX, floorY + 0.22, innerBackZ - 0.08), Color3.fromRGB(116, 86, 59), Enum.Material.Wood, { CanCollide = false })
makePart(living, "FrontLeftInteriorReturn", Vector3.new(garageFrontLeft.Size.X, drywallHeight, 0.12), CFrame.new(garageFrontLeft.Position.X, drywallCenterY, innerFrontZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "FrontRightInteriorReturn", Vector3.new(garageFrontRight.Size.X, drywallHeight, 0.12), CFrame.new(garageFrontRight.Position.X, drywallCenterY, innerFrontZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "FrontHeaderInteriorLiner", Vector3.new(garageHeader.Size.X, garageHeader.Size.Y, 0.12), CFrame.new(garageHeader.Position.X, garageHeader.Position.Y, innerFrontZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic, { CanCollide = false })
makePart(living, "FrontLeftBaseboard", Vector3.new(garageFrontLeft.Size.X, 0.38, 0.16), CFrame.new(garageFrontLeft.Position.X, floorY + 0.22, innerFrontZ + 0.08), Color3.fromRGB(116, 86, 59), Enum.Material.Wood, { CanCollide = false })
makePart(living, "FrontRightBaseboard", Vector3.new(garageFrontRight.Size.X, 0.38, 0.16), CFrame.new(garageFrontRight.Position.X, floorY + 0.22, innerFrontZ + 0.08), Color3.fromRGB(116, 86, 59), Enum.Material.Wood, { CanCollide = false })

-- The existing garage roof has gabled ends too; close those above the finished ceiling.
local garageFrontEave = roofUndersideEndpoint(garageFrontRoof, false)
local garageFrontRidge = roofUndersideEndpoint(garageFrontRoof, true)
local garageBackRidge = roofUndersideEndpoint(garageBackRoof, false)
local garageBackEave = roofUndersideEndpoint(garageBackRoof, true)
if math.min(garageFrontRidge.Y, garageBackRidge.Y) - garageWallTop > 2 then
	closeGablePair(living, "GarageLeft", garageLeftWall.Position.X, -1, garageLeftWall, garageWallTop, garageFrontEave, garageFrontRidge, garageBackEave, garageBackRidge, garageHeader, false)
	closeGablePair(living, "GarageRight", garageRightWall.Position.X, 1, garageRightWall, garageWallTop, garageFrontEave, garageFrontRidge, garageBackEave, garageBackRidge, garageHeader, false)
end

finishRoofRakes(living, garageFrontRoof, "GarageFrontSlope", garageLeftWall.Position.X, garageRightWall.Position.X, garageHeader)
finishRoofRakes(living, garageBackRoof, "GarageBackSlope", garageLeftWall.Position.X, garageRightWall.Position.X, garageHeader)
addEaveFinish(living, "GarageFrontEave", garageFrontRoof, garageHeader.Position.Z, garageLeftWall.Position.X, garageRightWall.Position.X, garageWallTop, garageHeader, false)
addEaveFinish(living, "GarageBackEave", garageBackRoof, garageBackWall.Position.Z, garageLeftWall.Position.X, garageRightWall.Position.X, garageWallTop, garageHeader, true)
addRidgeFlashing(living, "Garage", garageFrontRoof, garageBackRoof)

-- Warm ceiling fixtures.
for index, zOffset in ipairs({ -5.2, 5.2 }) do
	local fixture = makePart(living, "CeilingLight" .. index, Vector3.new(2.8, 0.20, 1.15), CFrame.new(centerX, garageWallTop - 0.22, centerZ + zOffset), Color3.fromRGB(241, 224, 176), Enum.Material.Neon, { CanCollide = false })
	addPointLight(fixture, Color3.fromRGB(255, 229, 181), 1.7, 19)
end

-- Kitchenette along the left wall: compact fridge, sink counter, cupboards,
-- microwave, two hot plates, and period-appropriate laminate worktop.
local kitchenette = Instance.new("Model")
kitchenette.Name = "CompactKitchenette"
kitchenette.Parent = living
local counterX = innerLeftX + 0.88
local counterZ = centerZ + 5.1
makePart(kitchenette, "BaseCabinet", Vector3.new(1.55, 2.55, 6.0), CFrame.new(counterX, floorY + 1.28, counterZ), Color3.fromRGB(132, 100, 69), Enum.Material.WoodPlanks)
makePart(kitchenette, "LaminateCounter", Vector3.new(1.78, 0.18, 6.25), CFrame.new(counterX + 0.06, floorY + 2.64, counterZ), Color3.fromRGB(217, 198, 157), Enum.Material.SmoothPlastic)
makePart(kitchenette, "SinkBasin", Vector3.new(0.92, 0.10, 1.55), CFrame.new(counterX + 0.31, floorY + 2.75, counterZ + 1.45), Color3.fromRGB(156, 161, 158), Enum.Material.Metal, { CanCollide = false })
makePart(kitchenette, "FaucetStem", Vector3.new(0.14, 0.75, 0.14), CFrame.new(counterX + 0.55, floorY + 3.04, counterZ + 2.02), Color3.fromRGB(126, 132, 131), Enum.Material.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder })
makePart(kitchenette, "HotPlateOne", Vector3.new(0.10, 0.74, 0.74), CFrame.new(counterX + 0.63, floorY + 2.76, counterZ - 1.45) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 42, 39), Enum.Material.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder })
makePart(kitchenette, "HotPlateTwo", Vector3.new(0.10, 0.62, 0.62), CFrame.new(counterX + 0.63, floorY + 2.76, counterZ - 2.10) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 42, 39), Enum.Material.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder })
makePart(kitchenette, "UpperCupboard", Vector3.new(0.76, 2.45, 5.8), CFrame.new(innerLeftX + 0.44, floorY + 6.35, counterZ), Color3.fromRGB(150, 117, 80), Enum.Material.WoodPlanks)
for doorIndex, doorZ in ipairs({ counterZ - 1.48, counterZ + 1.48 }) do
	makePart(kitchenette, "CupboardDoor" .. doorIndex, Vector3.new(0.12, 2.05, 2.65), CFrame.new(innerLeftX + 0.85, floorY + 6.35, doorZ), Color3.fromRGB(173, 137, 93), Enum.Material.WoodPlanks, { CanCollide = false })
	makePart(kitchenette, "CupboardPull" .. doorIndex, Vector3.new(0.10, 0.44, 0.10), CFrame.new(innerLeftX + 0.93, floorY + 6.35, doorZ + (doorIndex == 1 and 0.95 or -0.95)), Color3.fromRGB(84, 75, 63), Enum.Material.Metal, { CanCollide = false })
end
makePart(kitchenette, "CompactFridge", Vector3.new(1.78, 5.35, 2.65), CFrame.new(counterX, floorY + 2.68, centerZ - 1.7), Color3.fromRGB(219, 215, 196), Enum.Material.SmoothPlastic)
makePart(kitchenette, "FridgeHandle", Vector3.new(0.12, 1.25, 0.13), CFrame.new(counterX + 0.94, floorY + 3.35, centerZ - 0.87), Color3.fromRGB(108, 104, 93), Enum.Material.Metal, { CanCollide = false })
makePart(kitchenette, "Microwave", Vector3.new(1.15, 1.15, 1.85), CFrame.new(counterX + 0.15, floorY + 3.32, counterZ - 0.35), Color3.fromRGB(68, 62, 54), Enum.Material.SmoothPlastic)
makePart(kitchenette, "MicrowaveWindow", Vector3.new(0.08, 0.72, 1.18), CFrame.new(counterX + 0.76, floorY + 3.34, counterZ - 0.46), Color3.fromRGB(35, 39, 38), Enum.Material.Glass, { CanCollide = false })

-- Bed nook and baby bassinet at the rear, leaving a broad path from the door.
local bed = Instance.new("Model")
bed.Name = "GeorgieMandyBedNook"
bed.Parent = living
local bedX = centerX + 4.05
local bedZ = innerBackZ - 3.25
makePart(bed, "BedFrame", Vector3.new(6.45, 0.52, 6.25), CFrame.new(bedX, floorY + 0.52, bedZ), Color3.fromRGB(94, 63, 43), Enum.Material.Wood)
makePart(bed, "Mattress", Vector3.new(6.12, 0.62, 5.92), CFrame.new(bedX, floorY + 1.02, bedZ - 0.04), Color3.fromRGB(223, 214, 192), Enum.Material.Fabric)
makePart(bed, "Quilt", Vector3.new(6.04, 0.16, 3.65), CFrame.new(bedX, floorY + 1.42, bedZ - 0.92), Color3.fromRGB(91, 113, 130), Enum.Material.Fabric, { CanCollide = false })
makePart(bed, "Headboard", Vector3.new(6.55, 2.85, 0.30), CFrame.new(bedX, floorY + 2.05, innerBackZ - 0.25), Color3.fromRGB(103, 69, 46), Enum.Material.Wood)
makePart(bed, "GeorgiePillow", Vector3.new(2.55, 0.40, 1.10), CFrame.new(bedX - 1.55, floorY + 1.52, innerBackZ - 1.00), Color3.fromRGB(231, 222, 202), Enum.Material.Fabric, { CanCollide = false })
makePart(bed, "MandyPillow", Vector3.new(2.55, 0.40, 1.10), CFrame.new(bedX + 1.55, floorY + 1.52, innerBackZ - 1.00), Color3.fromRGB(227, 207, 201), Enum.Material.Fabric, { CanCollide = false })

local bassinet = Instance.new("Model")
bassinet.Name = "CeeCeeBassinet"
bassinet.Parent = living
local bassinetX = centerX - 1.40
local bassinetZ = innerBackZ - 2.1
makePart(bassinet, "BassinetStand", Vector3.new(3.35, 0.34, 2.15), CFrame.new(bassinetX, floorY + 0.70, bassinetZ), Color3.fromRGB(232, 224, 201), Enum.Material.Wood)
makePart(bassinet, "BassinetBasket", Vector3.new(3.60, 1.05, 2.35), CFrame.new(bassinetX, floorY + 1.32, bassinetZ), Color3.fromRGB(214, 198, 162), Enum.Material.Fabric)
makePart(bassinet, "BabyBlanket", Vector3.new(2.88, 0.16, 1.72), CFrame.new(bassinetX, floorY + 1.90, bassinetZ), Color3.fromRGB(231, 186, 177), Enum.Material.Fabric, { CanCollide = false })
for legX = -1, 1, 2 do
	makePart(bassinet, "BassinetLeg" .. legX, Vector3.new(0.22, 1.20, 0.22), CFrame.new(bassinetX + (legX * 1.25), floorY + 0.60, bassinetZ), Color3.fromRGB(151, 126, 91), Enum.Material.Wood)
end

-- Plaid sleeper couch with real Seat instances; it faces the small CRT TV.
local couch = Instance.new("Model")
couch.Name = "PlaidSleeperCouch"
couch.Parent = living
local couchX = innerRightX - 1.12
local couchZ = centerZ - 2.6
local couchColor = Color3.fromRGB(126, 83, 66)
makePart(couch, "CouchBack", Vector3.new(0.72, 2.65, 6.35), CFrame.new(innerRightX - 0.40, floorY + 1.78, couchZ), couchColor, Enum.Material.Fabric)
makePart(couch, "CouchBase", Vector3.new(2.15, 0.55, 6.20), CFrame.new(couchX, floorY + 0.60, couchZ), Color3.fromRGB(94, 61, 50), Enum.Material.Wood)
for seatIndex, zOffset in ipairs({ -1.55, 1.55 }) do
	local seat = makeSeat(couch, "CouchSeat" .. seatIndex, Vector3.new(2.75, 0.44, 2.10), CFrame.new(couchX - 0.12, floorY + 1.05, couchZ + zOffset) * CFrame.Angles(0, math.rad(90), 0), couchColor, Enum.Material.Fabric)
	seat:SetAttribute("FurnitureRole", "Sittable")
end
makePart(couch, "FrontArm", Vector3.new(2.25, 1.75, 0.48), CFrame.new(couchX, floorY + 1.30, couchZ - 3.15), couchColor, Enum.Material.Fabric)
makePart(couch, "BackArm", Vector3.new(2.25, 1.75, 0.48), CFrame.new(couchX, floorY + 1.30, couchZ + 3.15), couchColor, Enum.Material.Fabric)

local tv = Instance.new("Model")
tv.Name = "SecondhandCRTTelevision"
tv.Parent = living
local tvX = innerLeftX + 0.72
local tvZ = couchZ
makePart(tv, "TVStand", Vector3.new(1.28, 2.15, 4.35), CFrame.new(tvX, floorY + 1.08, tvZ), Color3.fromRGB(91, 64, 43), Enum.Material.WoodPlanks)
makePart(tv, "CRTCase", Vector3.new(1.42, 2.65, 3.85), CFrame.new(tvX + 0.18, floorY + 3.30, tvZ), Color3.fromRGB(70, 61, 50), Enum.Material.SmoothPlastic)
makePart(tv, "CurvedScreen", Vector3.new(0.12, 1.78, 2.70), CFrame.new(tvX + 0.95, floorY + 3.42, tvZ), Color3.fromRGB(47, 66, 64), Enum.Material.Glass, { CanCollide = false })
makePart(tv, "ChannelKnob", Vector3.new(0.15, 0.38, 0.38), CFrame.new(tvX + 1.01, floorY + 2.83, tvZ - 1.47) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(184, 170, 137), Enum.Material.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder })

-- A worn rug, folding coffee table, work gear, and moving boxes keep the
-- conversion from feeling like a pristine modern apartment.
makePart(living, "LivingAreaRug", Vector3.new(7.1, 0.08, 7.5), CFrame.new(centerX + 3.0, floorY + 0.11, couchZ), Color3.fromRGB(105, 94, 65), Enum.Material.Fabric, { CanCollide = false })
makePart(living, "FoldingCoffeeTableTop", Vector3.new(3.9, 0.20, 2.25), CFrame.new(centerX + 2.0, floorY + 1.42, couchZ), Color3.fromRGB(126, 93, 61), Enum.Material.Wood)
for _, offset in ipairs({ Vector3.new(-1.55, 0.68, -0.75), Vector3.new(-1.55, 0.68, 0.75), Vector3.new(1.55, 0.68, -0.75), Vector3.new(1.55, 0.68, 0.75) }) do
	makePart(living, "CoffeeTableLeg", Vector3.new(0.17, 1.35, 0.17), CFrame.new(centerX + 2.0 + offset.X, floorY + offset.Y, couchZ + offset.Z), Color3.fromRGB(71, 68, 62), Enum.Material.Metal)
end
for boxIndex, boxData in ipairs({
	{ Vector3.new(2.3, 1.5, 2.0), CFrame.new(centerX - 5.5, floorY + 0.75, centerZ - 5.1) },
	{ Vector3.new(1.8, 1.25, 1.6), CFrame.new(centerX - 5.2, floorY + 2.10, centerZ - 5.0) },
}) do
	makePart(living, "MovingBox" .. boxIndex, boxData[1], boxData[2], Color3.fromRGB(161, 125, 82), Enum.Material.Cardboard)
end
makePart(living, "GeorgieToolbox", Vector3.new(2.55, 0.78, 1.15), CFrame.new(centerX - 4.9, floorY + 0.42, centerZ - 1.9), Color3.fromRGB(151, 49, 40), Enum.Material.Metal)
makePart(living, "ToolboxHandle", Vector3.new(1.15, 0.55, 0.12), CFrame.new(centerX - 4.9, floorY + 1.04, centerZ - 1.9), Color3.fromRGB(68, 61, 51), Enum.Material.Metal, { CanCollide = false })

-- Sectional garage door. A prior install may contribute only translation-invariant
-- dimensions. Every world-space position is re-derived from the current shell so
-- translating the environment can never make a later rerun rebuild at stale coordinates.
local previousDoorModel = garage:FindFirstChild("InteractiveSectionalGarageDoor")
local legacyDoor = garage:FindFirstChild("GarageDoor")
local TRANSLATION_INVARIANT_DOOR_ATTRIBUTES = {
	FoundationOverlap = true,
	OpeningWidth = true,
	PanelCount = true,
	PanelThickness = true,
}
local function previousDoorDimension(attributeName)
	assert(TRANSLATION_INVARIANT_DOOR_ATTRIBUTES[attributeName], attributeName .. " is not a retainable door dimension")
	if previousDoorModel and previousDoorModel:IsA("Model") then
		local value = previousDoorModel:GetAttribute(attributeName)
		if type(value) == "number" then
			return value
		end
	end
	return nil
end

local openingTopY = garageHeader.Position.Y - (garageHeader.Size.Y * 0.5)
local defaultFoundationOverlap = math.min(0.20, foundation.Size.Y * 0.15)
local legacyFoundationOverlap
if legacyDoor and legacyDoor:IsA("BasePart") then
	-- Preserve the legacy panel's small overlap with the threshold as a dimension,
	-- without retaining any of its absolute world position.
	legacyFoundationOverlap = legacyDoor.Size.Y - (openingTopY - floorY)
end
local foundationOverlap = legacyFoundationOverlap
	or previousDoorDimension("FoundationOverlap")
	or defaultFoundationOverlap
foundationOverlap = math.clamp(foundationOverlap, 0, math.min(0.40, foundation.Size.Y * 0.35))

local openingWidth = (legacyDoor and legacyDoor:IsA("BasePart") and legacyDoor.Size.X)
	or previousDoorDimension("OpeningWidth")
	or math.max(4, garageHeader.Size.X - math.max(0.55, garageHeader.Size.Z))
local doorCenterX = garageHeader.Position.X
local doorTravelZSign = foundation.Position.Z >= garageHeader.Position.Z and 1 or -1
local doorZ = garageHeader.Position.Z + (doorTravelZSign * garageHeader.Size.Z * 0.17)
local closedBottomY = floorY - foundationOverlap
local openingHeight = openingTopY - closedBottomY
local panelCount = math.clamp(math.floor((previousDoorDimension("PanelCount") or 6) + 0.5), 4, 10)
local panelThickness = (legacyDoor and legacyDoor:IsA("BasePart") and math.clamp(legacyDoor.Size.Z * 0.86, 0.22, 0.42))
	or previousDoorDimension("PanelThickness")
	or 0.30
local panelHeight = openingHeight / panelCount
local overheadClearance = math.max(0.34, panelThickness + 0.04)
local overheadY = openingTopY + overheadClearance
local trackRadius = math.max(0.35, math.min(
	panelHeight * 0.72,
	overheadClearance + (panelHeight * 0.5) - 0.08
))
local frontRun = math.max(panelHeight * 0.50, trackRadius * 0.72)
local verticalDistance = overheadY - trackRadius - closedBottomY
local curveDistance = trackRadius * math.pi * 0.5
local travelDistance = verticalDistance + curveDistance + frontRun - (panelHeight * 0.5)
assert(openingWidth > 4 and openingHeight > 5 and panelHeight > panelThickness, "Derived garage-door opening is invalid")
assert(verticalDistance >= (panelHeight * (panelCount - 0.5)) - 0.02, "Garage-door track curve intersects its closed panels")

local doorModel = stageModel(garage, "InteractiveSectionalGarageDoor")
doorModel:SetAttribute("IsOpen", false)
doorModel:SetAttribute("DoorState", "Closed")
doorModel:SetAttribute("Interaction", "ProximityPromptSectionalTrack")
doorModel:SetAttribute("OpeningWidth", openingWidth)
doorModel:SetAttribute("OpeningHeight", openingHeight)
doorModel:SetAttribute("OpeningBottomY", closedBottomY)
doorModel:SetAttribute("OpeningTopY", openingTopY)
doorModel:SetAttribute("DoorCenterX", doorCenterX)
doorModel:SetAttribute("DoorPlaneZ", doorZ)
doorModel:SetAttribute("DoorTravelZSign", doorTravelZSign)
doorModel:SetAttribute("FoundationOverlap", foundationOverlap)
doorModel:SetAttribute("PanelCount", panelCount)
doorModel:SetAttribute("PanelHeight", panelHeight)
doorModel:SetAttribute("PanelThickness", panelThickness)
doorModel:SetAttribute("OverheadY", overheadY)
doorModel:SetAttribute("TrackRadius", trackRadius)
doorModel:SetAttribute("FrontRun", frontRun)
doorModel:SetAttribute("TravelDistance", travelDistance)
doorModel:SetAttribute("TravelAlpha", 0)

local panelsFolder = Instance.new("Folder")
panelsFolder.Name = "Panels"
panelsFolder.Parent = doorModel

for index = 1, panelCount do
	local closedY = closedBottomY + (panelHeight * (index - 0.5))
	local closedPose = CFrame.new(doorCenterX, closedY, doorZ)
	local openHorizontalDistance = frontRun + ((index - 1) * panelHeight)
	local openPose = CFrame.new(doorCenterX, overheadY, doorZ + (doorTravelZSign * (trackRadius + openHorizontalDistance)))
		* CFrame.Angles(doorTravelZSign * math.rad(90), 0, 0)
	local panelGap = math.min(0.07, panelHeight * 0.08)
	local panel = makePart(panelsFolder, string.format("DoorPanel%02d", index), Vector3.new(openingWidth, panelHeight - panelGap, panelThickness), closedPose, Color3.fromRGB(219, 210, 184), Enum.Material.WoodPlanks)
	panel:SetAttribute("PanelIndex", index)
	addPose(panel, "ClosedPose", closedPose)
	addPose(panel, "OpenPose", openPose)
	addDoorPanelFace(panel, index, panelCount)
end

local blocker = makePart(doorModel, "CollisionBlocker", Vector3.new(openingWidth, openingHeight, math.max(0.24, panelThickness * 0.80)), CFrame.new(doorCenterX, closedBottomY + (openingHeight * 0.5), doorZ + (doorTravelZSign * 0.08)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false, CastShadow = false })
blocker.CanTouch = false

-- The visible rails use the same vertical/quarter-circle/horizontal path as the controller.
local trackColor = Color3.fromRGB(91, 90, 84)
local trackThickness = math.clamp(panelThickness * 0.60, 0.14, 0.22)
local trackInset = math.max(0.22, panelThickness * 0.78)
local trackZOffset = panelThickness * 0.90
local curveStartY = overheadY - trackRadius
local deepestOpenCenterZ = doorZ + (doorTravelZSign * (trackRadius + frontRun + ((panelCount - 1) * panelHeight)))
local horizontalTrackEndZ = deepestOpenCenterZ + (doorTravelZSign * ((panelHeight * 0.5) + 0.35))
for sideIndex, xOffset in ipairs({ -(openingWidth * 0.5) + trackInset, (openingWidth * 0.5) - trackInset }) do
	local trackX = doorCenterX + xOffset
	local trackPlaneZ = doorZ + (doorTravelZSign * trackZOffset)
	makePart(doorModel, "VerticalDoorTrack" .. sideIndex, Vector3.new(trackThickness, curveStartY - closedBottomY, trackThickness), CFrame.new(trackX, (closedBottomY + curveStartY) * 0.5, trackPlaneZ), trackColor, Enum.Material.Metal, { CanCollide = false })

	local previousPoint = Vector3.new(trackX, curveStartY, trackPlaneZ)
	for segment = 1, 8 do
		local angle = (math.pi * 0.5) * (segment / 8)
		local nextPoint = Vector3.new(
			trackX,
			curveStartY + (trackRadius * math.sin(angle)),
			trackPlaneZ + (doorTravelZSign * (trackRadius - (trackRadius * math.cos(angle))))
		)
		makeBeamBetween(doorModel, "CurvedDoorTrack" .. sideIndex .. "_" .. segment, previousPoint, nextPoint, trackThickness, trackColor, Enum.Material.Metal)
		previousPoint = nextPoint
	end

	local horizontalStartZ = trackPlaneZ + (doorTravelZSign * trackRadius)
	makePart(doorModel, "OverheadDoorTrack" .. sideIndex, Vector3.new(trackThickness, trackThickness, math.abs(horizontalTrackEndZ - horizontalStartZ)), CFrame.new(trackX, overheadY, (horizontalStartZ + horizontalTrackEndZ) * 0.5), trackColor, Enum.Material.Metal, { CanCollide = false })
end

local promptMount = makePart(doorModel, "PromptMount", Vector3.new(1.0, 1.0, 1.0), CFrame.new(doorCenterX - (openingWidth * 0.5) - 0.20, floorY + 4.0, garageHeader.Position.Z - (doorTravelZSign * 0.72)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "ProximityPrompt"
prompt.ActionText = "Open garage"
prompt.ObjectText = "Georgie & Mandy's garage"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
prompt.HoldDuration = 0.20
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
prompt.Parent = promptMount

local controller = Instance.new("Script")
controller.Name = "GeorgieGarageDoorController"
controller.Source = GARAGE_DOOR_CONTROLLER_SOURCE
controller.Disabled = true
controller.Parent = doorModel

-- Commit only after every model and controller has been built successfully.
-- Until here, a failed run leaves the previous installation and legacy door intact.
commitModel(structure, roofClosure, "RealisticRoofClosure_V1")
commitModel(garage, living, "GeorgieMandyLivingUpgrade_V1")
for _, child in ipairs(garage:GetChildren()) do
	if child.Name == "GarageDoor" or child.Name == "GarageDoorSeam" then
		child:Destroy()
	end
end
commitModel(garage, doorModel, "InteractiveSectionalGarageDoor")
controller.Disabled = false

print(string.format(
	"Installed roof/garage upgrade %s: %d roof pieces, %d living-space descendants, %d moving door panels",
	INSTALL_VERSION,
	#roofClosure:GetDescendants(),
	#living:GetDescendants(),
	#panelsFolder:GetChildren()
))
