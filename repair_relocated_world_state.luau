-- Idempotent edit-mode repair for relocation-sensitive world attributes.
--
-- Moving an ancestor Model carries physical descendants but does not transform
-- CFrame/Vector3 attributes.  Runtime guards already repaired most of these
-- values in playtests; this pass persists the same geometry-derived repairs in
-- Studio so edit mode and the first runtime frame agree without warnings.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment was not found")

local house = environment:FindFirstChild("CooperHouse")
local site = environment:FindFirstChild("SiteAndStreet")
local furniture = house and house:FindFirstChild("FurnitureAndProps")
local rooms = house and house:FindFirstChild("InteriorRooms")
local exterior = house and house:FindFirstChild("ExteriorDetails")
local garage = environment:FindFirstChild("DetachedGarage")
local taskWorld = environment:FindFirstChild("CooperFamilyTaskWorld")
local stations = taskWorld and taskWorld:FindFirstChild("Stations")
local visuals = taskWorld and (taskWorld:FindFirstChild("TaskVisuals") or taskWorld:FindFirstChild("Visuals"))
assert(
	house and site and furniture and rooms and exterior and garage and taskWorld and stations and visuals,
	"World hierarchy is incomplete"
)

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"CooperRelocatedStateRepair",
		"Repair relocated Cooper world state"
	)
end)

local repaired = 0
local function mark()
	repaired += 1
end

local function recursive(name)
	return environment:FindFirstChild(name, true)
end

local function setAttributeIfChanged(instance, name, value)
	local old = instance:GetAttribute(name)
	local changed = old ~= value
	if typeof(old) == "CFrame" and typeof(value) == "CFrame" then
		local orientationAlignment = math.min(
			old.RightVector.Unit:Dot(value.RightVector.Unit),
			old.UpVector.Unit:Dot(value.UpVector.Unit),
			old.LookVector.Unit:Dot(value.LookVector.Unit)
		)
		changed = (old.Position - value.Position).Magnitude > 0.0001
			or orientationAlignment < math.cos(math.rad(0.01))
	elseif typeof(old) == "Vector3" and typeof(value) == "Vector3" then
		changed = (old - value).Magnitude > 0.0001
	end
	if changed then
		instance:SetAttribute(name, value)
		mark()
	end
end

-- The original house builder placed Workspace.SpawnLocation at an absolute
-- world coordinate. Once the complete environment was moved, normal Play and
-- respawns still appeared on the baseplate dozens of studs below the home.
-- Mount the one enabled spawn under the movable site and resolve its height
-- from the front walk/yard geometry so future environment moves carry it.
do
	local lot = site:FindFirstChild("CooperLot")
	assert(lot and lot:IsA("BasePart"), "SiteAndStreet.CooperLot was not found")

	local spawnLocations = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			table.insert(spawnLocations, descendant)
		end
	end

	local spawn = spawnLocations[1]
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		mark()
	end
	for index = 2, #spawnLocations do
		if spawnLocations[index].Enabled then
			spawnLocations[index].Enabled = false
			mark()
		end
	end

	local spawnSize = Vector3.new(6, 1, 6)
	local localOffset = Vector3.new(-5, 0, -63)
	local up = lot.CFrame.UpVector.Unit
	local horizontalPoint = lot.CFrame:PointToWorldSpace(localOffset)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { spawn }
	pcall(function()
		raycastParams.RespectCanCollide = true
	end)
	local support = Workspace:Raycast(
		horizontalPoint + up * 12,
		-up * 24,
		raycastParams
	)
	local supportPosition = if support
		then support.Position
		else lot.CFrame:PointToWorldSpace(Vector3.new(
			localOffset.X,
			lot.Size.Y * 0.5,
			localOffset.Z
		))
	local spawnPosition = supportPosition + up * (spawnSize.Y * 0.5 + 0.05)
	local expectedCFrame = CFrame.lookAt(
		spawnPosition,
		spawnPosition - lot.CFrame.LookVector,
		up
	)
	local positionChanged = (spawn.Position - expectedCFrame.Position).Magnitude > 0.001
	local facingChanged = spawn.CFrame.LookVector.Unit:Dot(expectedCFrame.LookVector.Unit) < 0.99999

	if spawn.Parent ~= site then
		spawn.Parent = site
		mark()
	end
	if positionChanged or facingChanged then
		spawn.CFrame = expectedCFrame
		mark()
	end
	if spawn.Size ~= spawnSize then
		spawn.Size = spawnSize
		mark()
	end
	if not spawn.Anchored then
		spawn.Anchored = true
		mark()
	end
	if not spawn.CanCollide then
		spawn.CanCollide = true
		mark()
	end
	spawn.CanTouch = false
	spawn.CanQuery = true
	spawn.Enabled = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	spawn.Transparency = 0.55
	spawn.Material = Enum.Material.Concrete
	spawn.Color = Color3.fromRGB(174, 171, 159)
	for _, child in ipairs(spawn:GetDescendants()) do
		if child:IsA("Decal") then
			child.Transparency = 1
		end
	end
	setAttributeIfChanged(spawn, "CooperSpawnLotLocalOffset", localOffset)
	setAttributeIfChanged(spawn, "CooperSpawnRepairVersion", "2026-07-17.1")
end

-- Bunker geometry moves with the environment, but these authored CFrame
-- attributes do not. Reconstruct every bunker origin from the physical shaft
-- marker and chamber floor so verification and future gameplay never target
-- the bunker's former address.
do
	local bunker = environment:FindFirstChild("BackyardBunker")
	local surfaceEntrance = bunker and bunker:FindFirstChild("SurfaceEntrance")
	local shaftOpening = surfaceEntrance and surfaceEntrance:FindFirstChild("ShaftOpening")
	local hatchDoor = surfaceEntrance and surfaceEntrance:FindFirstChild("HatchDoor")
	local underground = bunker and bunker:FindFirstChild("Underground")
	local shell = underground and underground:FindFirstChild("Shell")
	local foundationFloor = shell and shell:FindFirstChild("FoundationFloor")
	local blastDoor = underground and underground:FindFirstChild("BlastDoor")
	local leftPanel = blastDoor and blastDoor:FindFirstChild("LeftPanel")
	local rightPanel = blastDoor and blastDoor:FindFirstChild("RightPanel")
	local ventilation = underground and underground:FindFirstChild("Ventilation")
	local fanBlades = ventilation and ventilation:FindFirstChild("FanBlades")
	local lot = site:FindFirstChild("CooperLot")
	local neighborhoodGround = site:FindFirstChild("NeighborhoodGround")
	assert(
		bunker and bunker:IsA("Model")
			and shaftOpening and shaftOpening:IsA("BasePart")
			and hatchDoor and hatchDoor:IsA("Model")
			and foundationFloor and foundationFloor:IsA("BasePart")
			and leftPanel and leftPanel:IsA("BasePart")
			and rightPanel and rightPanel:IsA("BasePart")
			and fanBlades and fanBlades:IsA("Model")
			and lot and lot:IsA("BasePart")
			and neighborhoodGround and neighborhoodGround:IsA("BasePart"),
		"Bunker relocation sources are incomplete"
	)

	local roomSize = bunker:GetAttribute("RoomSize")
	assert(typeof(roomSize) == "Vector3", "BackyardBunker.RoomSize is missing")

	local shaftCenter = shaftOpening.CFrame * CFrame.new(0, -0.04, 0)
	local surfaceOrigin = shaftOpening.CFrame * CFrame.new(0, -0.04, 0.15)
	local undergroundOrigin = foundationFloor.CFrame * CFrame.new(0, roomSize.Y * 0.5, 0)
	local shaftSize = Vector3.new(6.55, 8, 6.15)

	setAttributeIfChanged(bunker, "ShaftCenter", shaftCenter)
	setAttributeIfChanged(bunker, "SurfaceOrigin", surfaceOrigin)
	setAttributeIfChanged(bunker, "UndergroundOrigin", undergroundOrigin)
	setAttributeIfChanged(lot, "BunkerShaftCenter", shaftCenter)
	setAttributeIfChanged(lot, "BunkerShaftSize", shaftSize)
	setAttributeIfChanged(neighborhoodGround, "BunkerShaftCenter", shaftCenter)
	setAttributeIfChanged(neighborhoodGround, "BunkerShaftSize", shaftSize)

	-- Runtime animators consume stored world-space poses. Rebase both ends of
	-- each animation from the live physical pose matching the saved state.
	local hatchOpen = bunker:GetAttribute("HatchOpen") == true
	local oldClosedPivot = hatchDoor:GetAttribute("ClosedPivot")
	local oldOpenPivot = hatchDoor:GetAttribute("OpenPivot")
	assert(
		typeof(oldClosedPivot) == "CFrame" and typeof(oldOpenPivot) == "CFrame",
		"BackyardBunker hatch pivots are missing"
	)
	local hatchReference = if hatchOpen then oldOpenPivot else oldClosedPivot
	local hatchDelta = hatchDoor:GetPivot() * hatchReference:Inverse()
	setAttributeIfChanged(hatchDoor, "ClosedPivot", hatchDelta * oldClosedPivot)
	setAttributeIfChanged(hatchDoor, "OpenPivot", hatchDelta * oldOpenPivot)
	setAttributeIfChanged(hatchDoor, "IsOpen", hatchOpen)

	local blastDoorOpen = bunker:GetAttribute("BlastDoorOpen") == true
	for _, panel in ipairs({ leftPanel, rightPanel }) do
		local oldClosed = panel:GetAttribute("ClosedCFrame")
		local oldOpen = panel:GetAttribute("OpenCFrame")
		assert(
			typeof(oldClosed) == "CFrame" and typeof(oldOpen) == "CFrame",
			panel:GetFullName() .. " poses are missing"
		)
		local reference = if blastDoorOpen then oldOpen else oldClosed
		local delta = panel.CFrame * reference:Inverse()
		setAttributeIfChanged(panel, "ClosedCFrame", delta * oldClosed)
		setAttributeIfChanged(panel, "OpenCFrame", delta * oldOpen)
		panel.CanCollide = not blastDoorOpen
	end
	setAttributeIfChanged(blastDoor, "IsOpen", blastDoorOpen)

	setAttributeIfChanged(fanBlades, "BasePivot", fanBlades:GetPivot())
end

-- Income boombox and its placement stations, resolved from the live table.
do
	local boombox = recursive("CooperIncomeBoombox")
	local tableModel = recursive("FormalSofaEndTable")
	local tableTop = tableModel and tableModel:FindFirstChild("Top")
	local sofa = recursive("FormalGreenFloralSofa")
	local setupAnchor = stations:FindFirstChild("BoomboxSetupAnchor")
	local powerAnchor = stations:FindFirstChild("BoomboxPowerAnchor")
	assert(
		boombox and boombox:IsA("Model")
			and tableTop and tableTop:IsA("BasePart")
			and sofa and sofa:IsA("Model")
			and setupAnchor and setupAnchor:IsA("BasePart")
			and powerAnchor and powerAnchor:IsA("BasePart"),
		"Boombox relocation sources are incomplete"
	)
	local tableUp = tableTop.CFrame.UpVector.Unit
	local sofaLook = sofa:GetPivot().LookVector
	local planarLook = sofaLook - tableUp * sofaLook:Dot(tableUp)
	assert(planarLook.Magnitude > 0.5, "Formal sofa has no stable planar facing")
	local basePosition = tableTop.Position + tableUp * (tableTop.Size.Y * 0.5 + 0.025)
	local expected = CFrame.lookAt(basePosition, basePosition + planarLook.Unit, tableUp)
	local saved = boombox:GetAttribute("SetupCFrame")
	if typeof(saved) == "CFrame" then
		local delta = expected * saved:Inverse()
		if (saved.Position - expected.Position).Magnitude > 0.0001 then
			for _, descendant in ipairs(boombox:GetDescendants()) do
				local rest = descendant:GetAttribute("RestCFrame")
				if typeof(rest) == "CFrame" then
					descendant:SetAttribute("RestCFrame", delta * rest)
					mark()
				end
				local target = descendant:GetAttribute("DiscoTarget")
				if typeof(target) == "Vector3" then
					descendant:SetAttribute("DiscoTarget", delta:PointToWorldSpace(target))
					mark()
				end
			end
		end
	end
	boombox:PivotTo(expected * CFrame.new(0, 0.42, 0))
	setAttributeIfChanged(boombox, "SetupCFrame", expected)
	setAttributeIfChanged(taskWorld, "IncomeBoomboxSetupCFrame", expected)
	setupAnchor.CFrame = expected * CFrame.new(0, 0.42, 0)
	powerAnchor.CFrame = expected * CFrame.new(-0.82, 0.68, -0.39)
end

-- Missy's two default toys use mattress-local homes.
do
	local bed = recursive("MissyWalnutTwinBed")
	local mattress = bed and bed:FindFirstChild("Mattress")
	assert(mattress and mattress:IsA("BasePart"), "Missy's mattress was not found")
	for _, toyName in ipairs({ "MissyDetailedTeddyBear", "MissyDetailedRabbit" }) do
		local toy = recursive(toyName)
		assert(toy and toy:IsA("Model"), toyName .. " was not found")
		local localHome = toy:GetAttribute("FamilyTaskHomeLocalCFrame")
		if typeof(localHome) ~= "CFrame" then
			localHome = toyName == "MissyDetailedRabbit"
				and (CFrame.new(0.62, mattress.Size.Y * 0.5 + 0.97, 0.28) * CFrame.Angles(0, math.rad(12), 0))
				or (CFrame.new(-0.68, mattress.Size.Y * 0.5 + 0.93, 0.20) * CFrame.Angles(0, math.rad(-14), 0))
			setAttributeIfChanged(toy, "FamilyTaskHomeLocalCFrame", localHome)
		end
		local home = mattress.CFrame * localHome
		setAttributeIfChanged(toy, "FamilyTaskHomeCFrame", home)
		setAttributeIfChanged(toy, "FamilyTaskHomeAnchor", "MissyWalnutTwinBed.Mattress")
		toy:PivotTo(home)
	end
end

-- Refrigerator hinge pose and safe aisle-facing swing.
do
	local hinge = recursive("FridgeDoorHinge")
	local panel = recursive("FridgeDoorPanel")
	local refrigerator = recursive("WhiteHotpointRefrigerator")
	local body = refrigerator and refrigerator:FindFirstChild("RefrigeratorBody")
	assert(
		hinge and hinge:IsA("BasePart")
			and panel and panel:IsA("BasePart")
			and refrigerator and refrigerator:IsA("Model")
			and body and body:IsA("BasePart"),
		"Refrigerator relocation sources are incomplete"
	)
	setAttributeIfChanged(hinge, "ClosedCFrame", hinge.CFrame)

	local angleMagnitude = math.clamp(
		math.abs(tonumber(hinge:GetAttribute("OpenAngleMagnitude")) or 78),
		70,
		125
	)
	local edgeA = panel.Position + panel.CFrame.RightVector * (panel.Size.X * 0.5)
	local edgeB = panel.Position - panel.CFrame.RightVector * (panel.Size.X * 0.5)
	local closedFreeEdge = if (edgeA - hinge.Position).Magnitude >= (edgeB - hinge.Position).Magnitude
		then edgeA
		else edgeB
	local freeEdgeInHingeSpace = hinge.CFrame:PointToObjectSpace(closedFreeEdge)
	local panelRelative = hinge.CFrame:ToObjectSpace(panel.CFrame)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { refrigerator }
	local function openScore(degrees)
		local openCFrame = hinge.CFrame * CFrame.Angles(0, math.rad(degrees), 0)
		local freeEdge = openCFrame:PointToWorldSpace(freeEdgeInHingeSpace)
		local towardAisle = (freeEdge - body.Position):Dot(body.CFrame.LookVector)
		local collisionCount = 0
		for _, hit in ipairs(Workspace:GetPartBoundsInBox(
			openCFrame * panelRelative,
			panel.Size * 0.9,
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
	setAttributeIfChanged(hinge, "DerivedOpenAngleDegrees", derivedAngle)
	setAttributeIfChanged(hinge, "SwingDirectionDerivedFromGeometry", true)
end

-- Front and patio doors preserve their current open/closed state while their
-- stored swing relationship is rebased onto the physical edit pose.
for _, specification in ipairs({
	{ name = "InteractiveFrontDoor", promptAnchor = "FrontDoorPromptAnchor" },
	{ name = "InteractiveDenPatioDoor", promptAnchor = "DenPatioPromptAnchor" },
}) do
	local door = exterior:FindFirstChild(specification.name)
	local promptAnchor = exterior:FindFirstChild(specification.promptAnchor)
	local prompt = promptAnchor and promptAnchor:FindFirstChild("DoorPrompt")
	assert(door and door:IsA("Model") and prompt and prompt:IsA("ProximityPrompt"), specification.name .. " is incomplete")
	local current = door:GetPivot()
	local oldClosed = door:GetAttribute("ClosedPivot")
	local oldOpen = door:GetAttribute("OpenPivot")
	local isOpen = door:GetAttribute("IsOpen") == true
	local newClosed
	local newOpen
	if typeof(oldClosed) == "CFrame" and typeof(oldOpen) == "CFrame" then
		if isOpen then
			newOpen = current
			newClosed = current * oldOpen:ToObjectSpace(oldClosed)
		else
			newClosed = current
			newOpen = current * oldClosed:ToObjectSpace(oldOpen)
		end
	else
		local swing = math.rad(specification.name == "InteractiveFrontDoor" and -102 or -98)
		if isOpen then
			newOpen = current
			newClosed = current * CFrame.Angles(0, -swing, 0)
		else
			newClosed = current
			newOpen = current * CFrame.Angles(0, swing, 0)
		end
	end
	setAttributeIfChanged(door, "ClosedPivot", newClosed)
	setAttributeIfChanged(door, "OpenPivot", newOpen)
	prompt.ActionText = isOpen and "Close Door" or "Open Door"
end

-- Sectional garage-door track metadata follows the already-correct collision
-- blocker. This is the same rigid repair performed by its runtime controller.
do
	local door = garage:FindFirstChild("InteractiveSectionalGarageDoor")
	assert(door and door:IsA("Model"), "InteractiveSectionalGarageDoor was not found")
	local blocker = door:FindFirstChild("CollisionBlocker")
	local panels = door:FindFirstChild("Panels")
	assert(blocker and blocker:IsA("BasePart") and panels and panels:IsA("Folder"), "Garage-door geometry is incomplete")
	local centerX = door:GetAttribute("DoorCenterX")
	local planeZ = door:GetAttribute("DoorPlaneZ")
	local bottomY = door:GetAttribute("OpeningBottomY")
	local topY = door:GetAttribute("OpeningTopY")
	local overheadY = door:GetAttribute("OverheadY")
	local travelSign = door:GetAttribute("DoorTravelZSign")
	assert(
		type(centerX) == "number"
			and type(planeZ) == "number"
			and type(bottomY) == "number"
			and type(topY) == "number"
			and type(overheadY) == "number"
			and type(travelSign) == "number",
		"Garage-door numeric track attributes are incomplete"
	)
	local expectedBlocker = Vector3.new(
		centerX,
		bottomY + blocker.Size.Y * 0.5,
		planeZ + travelSign * 0.08
	)
	local offset = blocker.Position - expectedBlocker
	if offset.Magnitude > 0.001 then
		setAttributeIfChanged(door, "DoorCenterX", centerX + offset.X)
		setAttributeIfChanged(door, "DoorPlaneZ", planeZ + offset.Z)
		setAttributeIfChanged(door, "OpeningBottomY", bottomY + offset.Y)
		setAttributeIfChanged(door, "OpeningTopY", topY + offset.Y)
		setAttributeIfChanged(door, "OverheadY", overheadY + offset.Y)
		for _, panel in ipairs(panels:GetChildren()) do
			if panel:IsA("BasePart") then
				local closedPose = panel:FindFirstChild("ClosedPose")
				local openPose = panel:FindFirstChild("OpenPose")
				assert(closedPose and closedPose:IsA("CFrameValue") and openPose and openPose:IsA("CFrameValue"), panel.Name .. " poses are missing")
				closedPose.Value += offset
				openPose.Value += offset
				mark()
				mark()
			end
		end
	end
	local isOpen = door:GetAttribute("IsOpen") == true
	for _, panel in ipairs(panels:GetChildren()) do
		if panel:IsA("BasePart") then
			local pose = panel:FindFirstChild(isOpen and "OpenPose" or "ClosedPose")
			assert(pose and pose:IsA("CFrameValue"), panel.Name .. " state pose is missing")
			panel.CFrame = pose.Value
		end
	end
	blocker.CanCollide = not isOpen
	local prompt = door:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.ActionText = isOpen and "Close Garage" or "Open Garage"
	end
end

-- Bathroom effect plus the legacy house/hall bounds. The current camera
-- controller derives these bounds from geometry, but keeping the attributes
-- accurate protects older consumers and makes the authored state self-
-- consistent after a whole-environment move.
do
	local swirl = recursive("ToiletFlushSwirl")
	local crossHall = rooms:FindFirstChild("CrossHallFloor")
	assert(swirl and swirl:IsA("BasePart") and crossHall and crossHall:IsA("BasePart"), "Bathroom/hall repair sources are missing")
	setAttributeIfChanged(swirl, "RestCFrame", swirl.CFrame)
	setAttributeIfChanged(swirl, "RestSize", swirl.Size)
	setAttributeIfChanged(environment, "HallMinZ", crossHall.Position.Z - crossHall.Size.Z * 0.5)
	setAttributeIfChanged(environment, "HallMaxZ", crossHall.Position.Z + crossHall.Size.Z * 0.5)
	local houseBoundsCFrame, houseBoundsSize = house:GetBoundingBox()
	setAttributeIfChanged(environment, "HouseMinX", houseBoundsCFrame.Position.X - houseBoundsSize.X * 0.5)
	setAttributeIfChanged(environment, "HouseMaxX", houseBoundsCFrame.Position.X + houseBoundsSize.X * 0.5)
end

-- Rebase the idempotency sources consumed by core_repairs.luau. Those stored
-- world-space CFrames do not follow a moved CooperHouse ancestor. Leaving them
-- stale would make a future safe rerun of that repair jump the porch glider,
-- dining hutch, and toilet back to the house's former address.
do
	local porchGlider = recursive("PorchGlider")
	assert(porchGlider and porchGlider:IsA("Model"), "PorchGlider was not found")
	setAttributeIfChanged(
		porchGlider,
		"HouseCoreRepairsBaselineCFrame",
		porchGlider:GetPivot() * CFrame.Angles(0, -math.pi, 0)
	)

	local hutchPieceCount = 0
	for _, object in ipairs(furniture:GetDescendants()) do
		local isHutchPiece = object.Name == "DiningChinaHutch"
			or object.Name == "DisplayedChina"
			or string.find(object.Name, "HutchHorizontalShelf", 1, true) == 1
		if isHutchPiece and (object:IsA("BasePart") or object:IsA("Model")) then
			hutchPieceCount += 1
			local currentCFrame = if object:IsA("BasePart") then object.CFrame else object:GetPivot()
			setAttributeIfChanged(
				object,
				"HouseCoreRepairsBaselineCFrame",
				currentCFrame + Vector3.new(-2.62, 0, 0)
			)
		end
	end
	assert(hutchPieceCount > 0, "Dining hutch repair sources were not found")

	local toilet = recursive("SideFacingIvoryToilet")
	local pedestal = toilet and toilet:FindFirstChild("PedestalBase")
	assert(
		toilet and toilet:IsA("Model") and pedestal and pedestal:IsA("BasePart"),
		"Toilet core-repair sources were not found"
	)
	local scale = tonumber(toilet:GetAttribute("CoreRepairScale")) or 1
	setAttributeIfChanged(
		toilet,
		"CoreRepairBaseCFrame",
		pedestal.CFrame * CFrame.new(Vector3.new(0, -0.12, -0.16) * scale)
	)
end

-- Swing home reconstructed from anchored rope tops and authored rope lengths.
do
	local rideables = recursive("CooperYardRideables")
	local swing = rideables and (rideables:FindFirstChild("FrontYardTireSwing") or rideables:FindFirstChild("FrontYardRopeSwing"))
	local seat = swing and swing:FindFirstChild("SwingSeat")
	assert(swing and swing:IsA("Model") and seat and seat:IsA("Seat"), "Front-yard swing is incomplete")
	local stored = seat:GetAttribute("HomeCFrame")
	local rotation = typeof(stored) == "CFrame" and stored.Rotation or seat.CFrame.Rotation
	local ropes = {}
	for _, name in ipairs({ "SwingRopeLeft", "SwingRopeRight" }) do
		local rope = swing:FindFirstChild(name)
		assert(rope and rope:IsA("RopeConstraint") and rope.Attachment0 and rope.Attachment1, name .. " is incomplete")
		assert(rope.Attachment1.Parent == seat, name .. " lower attachment is detached from SwingSeat")
		table.insert(ropes, rope)
	end
	local homePosition = Vector3.zero
	for _, rope in ipairs(ropes) do
		local desiredBottom = rope.Attachment0.WorldPosition - Vector3.yAxis * rope.Length
		local lowerOffset = rotation:VectorToWorldSpace(rope.Attachment1.Position)
		homePosition += desiredBottom - lowerOffset
	end
	homePosition /= #ropes
	local home = CFrame.new(homePosition) * rotation
	seat.CFrame = home
	setAttributeIfChanged(seat, "HomeCFrame", home)
	setAttributeIfChanged(swing, "HomeSeatCFrame", home)
	setAttributeIfChanged(swing, "HomeTopLeft", ropes[1].Attachment0.WorldPosition)
	setAttributeIfChanged(swing, "HomeTopRight", ropes[2].Attachment0.WorldPosition)
	setAttributeIfChanged(swing, "HomeBottomLeft", ropes[1].Attachment1.WorldPosition)
	setAttributeIfChanged(swing, "HomeBottomRight", ropes[2].Attachment1.WorldPosition)
	local tireOffset = seat:GetAttribute("TireCenterOffset")
	if typeof(tireOffset) == "Vector3" then
		setAttributeIfChanged(swing, "HomeTireCenter", home:PointToWorldSpace(tireOffset))
	end
end

-- Trike reset pose comes from its physical authored chassis.
do
	local trike = recursive("CooperRedYellowTrike")
	local chassis = trike and trike:FindFirstChild("Chassis")
	assert(trike and trike:IsA("Model") and chassis and chassis:IsA("BasePart"), "Front-yard trike is incomplete")
	setAttributeIfChanged(trike, "HomeCFrame", chassis.CFrame)
	setAttributeIfChanged(chassis, "HomeCFrame", chassis.CFrame)
end

-- Persist robot nested homes with the same rigid migration used at runtime.
for _, robotName in ipairs({ "BeerBot", "DishBot", "TrashBot", "ToyFinder" }) do
	local robot = visuals:FindFirstChild(robotName)
	assert(robot and robot:IsA("Model"), robotName .. " was not found")
	local savedHome = robot:GetAttribute("HomePivot")
	local currentHome = robot:GetPivot()
	if typeof(savedHome) == "CFrame" then
		local delta = currentHome * savedHome:Inverse()
		local stale = (currentHome.Position - savedHome.Position).Magnitude > 0.001
			or currentHome.LookVector:Dot(savedHome.LookVector) < 0.99999
			or currentHome.UpVector:Dot(savedHome.UpVector) < 0.99999
		if stale then
			for _, instance in ipairs(robot:GetDescendants()) do
				for _, attributeName in ipairs({
					"AutomationHomeCFrame",
					"HomePivot",
					"AutomationHomePivot",
				}) do
					local value = instance:GetAttribute(attributeName)
					if typeof(value) == "CFrame" then
						instance:SetAttribute(attributeName, delta * value)
						mark()
					end
				end
			end
		end
	end
	setAttributeIfChanged(robot, "HomePivot", currentHome)
end

setAttributeIfChanged(environment, "RelocationStateRepairVersion", "2026-07-17.5")

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("Repair relocated Cooper world state")
	end)
end

print(string.format("[CooperSpatialRepair] PASS: %d persisted values repaired", repaired))
