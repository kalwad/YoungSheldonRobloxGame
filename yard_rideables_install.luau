-- Idempotent edit-mode installer for the Cooper house front-yard rideables.
--
-- This intentionally replaces the original anchored TireSwing, rope parts,
-- SwingBranch, and RedYellowBigWheel with functional equivalents at the same
-- surveyed locations. Runtime behaviour lives in CooperYardRideables.server.luau
-- and CooperYardRideables.client.luau; install those as Script/LocalScript after
-- running this geometry installer.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local INSTALL_VERSION = "2.3.0"
local RIDEABLES_NAME = "CooperYardRideables"
local REMOTES_NAME = "CooperYardRideablesRemotes"
local EVENT_NAME = "RideablesEvent"

-- Safe fallbacks match the current house, but the installer surveys the legacy
-- display props below so their exact in-place location wins whenever possible.
local REFERENCE_SWING_CENTER = Vector3.new(19.018, 6.555, -18.395)
local REFERENCE_SWING_BRANCH_CFRAME = CFrame.new(18.118, 18.655, -18.395)
	* CFrame.Angles(0, math.rad(180), math.rad(-5.4))
local SWING_CENTER = REFERENCE_SWING_CENTER
local SWING_BRANCH_CFRAME = REFERENCE_SWING_BRANCH_CFRAME
local TRIKE_HOME = CFrame.new(20.068, 1.065, -9.445)

local SWING_TIRE_RADIUS = 2.05
-- Seat sits on the inner bottom of the tire so the avatar rests in the swing,
-- not floating behind it. Keep Z in the tire plane (no back offset).
local SWING_RIDER_SEAT_Y_OFFSET = -1.55
local SWING_RIDER_BACK_OFFSET = 0
local SWING_ROPE_TO_TIRE_CENTER_OFFSET = 0.30
local DEFAULT_SWING_ROPE_LENGTH = 11.25
local MIN_SWING_ROPE_LENGTH = 6
local MAX_SWING_ROPE_LENGTH = 18
local TRIKE_RIDE_HEIGHT = 0.38
-- The runtime uses this padded, raised envelope for obstacle sweeps while the
-- visible assembly remains non-collidable for reliable ground following.
local TRIKE_OBSTACLE_PROBE_SIZE = Vector3.new(3.10, 2.50, 4.80)
local TRIKE_OBSTACLE_PROBE_OFFSET = Vector3.new(0, 1.02, -0.34)
-- A separate raised box blocks players from walking through the trike without
-- putting a collidable wheel or chassis edge against the lawn. Its top ends
-- below the VehicleSeat, leaving Roblox's seated pose unobstructed.
local TRIKE_PLAYER_COLLISION_PROXY_SIZE = Vector3.new(3.00, 1.50, 4.60)
local TRIKE_PLAYER_COLLISION_PROXY_OFFSET = Vector3.new(0, 0.55, -0.25)

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment, "workspace.CooperHouseEnvironment was not found")
local landscaping = environment:FindFirstChild("Landscaping")
assert(landscaping, "CooperHouseEnvironment.Landscaping was not found")

local function beamEndpoints(part)
	local halfLength = part.Size.Z * 0.5
	return part.CFrame:PointToWorldSpace(Vector3.new(0, 0, -halfLength)),
		part.CFrame:PointToWorldSpace(Vector3.new(0, 0, halfLength))
end

local function upperAndLowerEndpoint(part)
	local pointA, pointB = beamEndpoints(part)
	if pointA.Y >= pointB.Y then
		return pointA, pointB
	end
	return pointB, pointA
end

-- Capture the old display props before replacement. This avoids brittle map
-- coordinates and keeps the functional versions exactly where the artist put
-- the originals, even if the whole environment is moved later.
local legacySwing = landscaping:FindFirstChild("TireSwing")
local legacyBranch = landscaping:FindFirstChild("SwingBranch")
local legacyLeftRope = landscaping:FindFirstChild("SwingRopeLeft")
local legacyRightRope = landscaping:FindFirstChild("SwingRopeRight")
local legacyTrike = landscaping:FindFirstChild("RedYellowBigWheel")
local previousRideables = landscaping:FindFirstChild(RIDEABLES_NAME)
local previousSwing = previousRideables
	and (previousRideables:FindFirstChild("FrontYardTireSwing")
		or previousRideables:FindFirstChild("FrontYardRopeSwing"))
local previousTrike = previousRideables and previousRideables:FindFirstChild("CooperRedYellowTrike")

local function groundTrikeHome(candidate, excludedInstances)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = excludedInstances
	raycastParams.IgnoreWater = true

	local position = candidate.Position
	local rayOrigin = Vector3.new(position.X, position.Y + 32, position.Z)
	local result = Workspace:Raycast(rayOrigin, Vector3.new(0, -96, 0), raycastParams)
	if not result then
		return candidate
	end

	local groundedY = result.Position.Y + TRIKE_RIDE_HEIGHT
	return CFrame.new(position.X, groundedY, position.Z) * candidate.Rotation
end

if legacyBranch and legacyBranch:IsA("BasePart") then
	SWING_BRANCH_CFRAME = legacyBranch.CFrame
elseif previousSwing then
	local previousBranch = previousSwing and previousSwing:FindFirstChild("SwingBranch")
	if previousBranch and previousBranch:IsA("BasePart") then
		SWING_BRANCH_CFRAME = previousBranch.CFrame
	end
end

-- Never survey the unanchored tire or seat as a home-position source. Those
-- parts can be saved after a physics preview, and an older controller also
-- carried a stale HomeCFrame attribute. Both failure modes separate the tire
-- from the anchored branch and make the visible ropes stretch across the yard.
-- The branch/top anchors and each RopeConstraint's authored Length are stable,
-- so every reinstall reconstructs the hanging home pose from those values.
local referenceTopPoints = {
	Vector3.new(REFERENCE_SWING_CENTER.X - 1.25, 18.105, REFERENCE_SWING_CENTER.Z),
	Vector3.new(REFERENCE_SWING_CENTER.X + 1.25, 18.105, REFERENCE_SWING_CENTER.Z),
}
local swingTopPoints = {
	SWING_BRANCH_CFRAME:PointToWorldSpace(
		REFERENCE_SWING_BRANCH_CFRAME:PointToObjectSpace(referenceTopPoints[1])
	),
	SWING_BRANCH_CFRAME:PointToWorldSpace(
		REFERENCE_SWING_BRANCH_CFRAME:PointToObjectSpace(referenceTopPoints[2])
	),
}
local swingBottomPoints = {
	swingTopPoints[1] - (Vector3.yAxis * DEFAULT_SWING_ROPE_LENGTH),
	swingTopPoints[2] - (Vector3.yAxis * DEFAULT_SWING_ROPE_LENGTH),
}

local surveyedRopes = false
if legacyLeftRope and legacyLeftRope:IsA("BasePart")
	and legacyRightRope and legacyRightRope:IsA("BasePart")
then
	local leftTop, leftBottom = upperAndLowerEndpoint(legacyLeftRope)
	local rightTop, rightBottom = upperAndLowerEndpoint(legacyRightRope)
	swingTopPoints = { leftTop, rightTop }
	swingBottomPoints = { leftBottom, rightBottom }
	surveyedRopes = true
elseif previousSwing then
	local previousLeftRope = previousSwing:FindFirstChild("SwingRopeLeft")
	local previousRightRope = previousSwing:FindFirstChild("SwingRopeRight")
	if previousLeftRope and previousLeftRope:IsA("RopeConstraint")
		and previousRightRope and previousRightRope:IsA("RopeConstraint")
		and previousLeftRope.Attachment0 and previousLeftRope.Attachment1
		and previousRightRope.Attachment0 and previousRightRope.Attachment1
	then
		local leftTop = previousLeftRope.Attachment0.WorldPosition
		local rightTop = previousRightRope.Attachment0.WorldPosition
		local leftLength = previousLeftRope.Length
		local rightLength = previousRightRope.Length
		local validLengths = leftLength == leftLength and rightLength == rightLength
			and leftLength >= MIN_SWING_ROPE_LENGTH and leftLength <= MAX_SWING_ROPE_LENGTH
			and rightLength >= MIN_SWING_ROPE_LENGTH and rightLength <= MAX_SWING_ROPE_LENGTH
		if validLengths then
			swingTopPoints = { leftTop, rightTop }
			swingBottomPoints = {
				leftTop - (Vector3.yAxis * leftLength),
				rightTop - (Vector3.yAxis * rightLength),
			}
			surveyedRopes = true
		end
	end
end

if not surveyedRopes then
	swingBottomPoints = {
		swingTopPoints[1] - (Vector3.yAxis * DEFAULT_SWING_ROPE_LENGTH),
		swingTopPoints[2] - (Vector3.yAxis * DEFAULT_SWING_ROPE_LENGTH),
	}
end

local bottomMidpoint = (swingBottomPoints[1] + swingBottomPoints[2]) * 0.5
SWING_CENTER = bottomMidpoint - (Vector3.yAxis * SWING_ROPE_TO_TIRE_CENTER_OFFSET)

local sideAxis = Vector3.new(
	swingBottomPoints[1].X - swingBottomPoints[2].X,
	0,
	swingBottomPoints[1].Z - swingBottomPoints[2].Z
)
if sideAxis.Magnitude < 0.1 then
	sideAxis = Vector3.new(-SWING_BRANCH_CFRAME.RightVector.X, 0, -SWING_BRANCH_CFRAME.RightVector.Z)
end
if sideAxis.Magnitude < 0.1 then
	sideAxis = Vector3.xAxis
end
sideAxis = sideAxis.Unit
local swingFrame = CFrame.fromMatrix(
	SWING_CENTER,
	sideAxis,
	Vector3.yAxis,
	sideAxis:Cross(Vector3.yAxis)
)

if legacyTrike and legacyTrike:IsA("Model") then
	local trikeBounds, trikeSize = legacyTrike:GetBoundingBox()
	local legacyBottomY = trikeBounds.Position.Y - (trikeSize.Y * 0.5)
	TRIKE_HOME = CFrame.new(trikeBounds.Position.X, legacyBottomY + 0.38, trikeBounds.Position.Z)
		* legacyTrike:GetPivot().Rotation
elseif previousRideables then
	local previousChassis = previousTrike and previousTrike:FindFirstChild("Chassis")
	if previousChassis and previousChassis:IsA("BasePart") then
		TRIKE_HOME = previousChassis.CFrame
	end
end

local trikeRaycastExclusions = {}
if legacyTrike then
	table.insert(trikeRaycastExclusions, legacyTrike)
end
if previousRideables then
	table.insert(trikeRaycastExclusions, previousRideables)
end
TRIKE_HOME = groundTrikeHome(TRIKE_HOME, trikeRaycastExclusions)

local function replace(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	return object
end

local function destroyNamed(parent, name)
	local object = parent:FindFirstChild(name)
	if object then
		object:Destroy()
		return true
	end
	return false
end

local function finishPart(part, options)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Color = options.color or Color3.fromRGB(163, 76, 47)
	part.Anchored = options.anchored == true
	part.CanCollide = options.canCollide == true
	part.CanTouch = options.canTouch == true
	part.CanQuery = options.canQuery ~= false
	part.CastShadow = options.castShadow ~= false
	part.Massless = options.massless == true
	if options.transparency then
		part.Transparency = options.transparency
	end
	return part
end

local function makePart(parent, name, size, cframe, options)
	local part = Instance.new(options.className or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	finishPart(part, options)
	part.Parent = parent
	return part
end

local function weld(root, child)
	local constraint = Instance.new("WeldConstraint")
	constraint.Name = "RideableWeld"
	constraint.Part0 = root
	constraint.Part1 = child
	constraint.Parent = root
	return constraint
end

local function makeBeam(parent, name, pointA, pointB, thickness, options)
	local delta = pointB - pointA
	local length = delta.Magnitude
	assert(length > 0.001, name .. " beam endpoints overlap")
	return makePart(
		parent,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt((pointA + pointB) / 2, pointB),
		options
	)
end

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"CooperYardRideables",
		"Install functional Cooper yard swing and trike"
	)
end)

local ok, failure = xpcall(function()
	-- These five objects are the anchored display-only originals. Exact-name
	-- deletion makes reruns harmless and avoids leaving duplicate silhouettes.
	for _, legacyName in ipairs({
		"TireSwing",
		"SwingRopeRight",
		"SwingRopeLeft",
		"SwingBranch",
		"RedYellowBigWheel",
	}) do
		destroyNamed(landscaping, legacyName)
	end

	local rideables = replace(landscaping, "Model", RIDEABLES_NAME)
	rideables:SetAttribute("InstallVersion", INSTALL_VERSION)
	rideables:SetAttribute("Purpose", "Server-authoritative usable front-yard swing and trike")

	local remotes = replace(ReplicatedStorage, "Folder", REMOTES_NAME)
	remotes:SetAttribute("InstallVersion", INSTALL_VERSION)
	local rideablesEvent = Instance.new("RemoteEvent")
	rideablesEvent.Name = EVENT_NAME
	rideablesEvent.Parent = remotes

	-- SWING -----------------------------------------------------------------
	-- Keep the recognizable vertical tire from the original map. The Seat sits
	-- at the bottom of the tire opening so R6/R15 avatars rest inside the ring
	-- instead of floating behind it. Two RopeConstraints carry the assembly.
	local swing = Instance.new("Model")
	swing.Name = "FrontYardTireSwing"
	swing:SetAttribute("RideableType", "Swing")
	swing:SetAttribute("HomeGeometryVersion", INSTALL_VERSION)
	swing:SetAttribute("HomeTireCenter", SWING_CENTER)
	swing:SetAttribute("HomeTopLeft", swingTopPoints[1])
	swing:SetAttribute("HomeTopRight", swingTopPoints[2])
	swing:SetAttribute("HomeBottomLeft", swingBottomPoints[1])
	swing:SetAttribute("HomeBottomRight", swingBottomPoints[2])
	swing.Parent = rideables

	local branch = makePart(
		swing,
		"SwingBranch",
		Vector3.new(10.55, 1.2, 1.2),
		SWING_BRANCH_CFRAME,
		{
			anchored = true,
			canCollide = true,
			material = Enum.Material.Wood,
			color = Color3.fromRGB(88, 57, 34),
		}
	)
	branch.Shape = Enum.PartType.Cylinder

	local swingSeat = makePart(
		swing,
		"SwingSeat",
		Vector3.new(2.05, 0.34, 1.12),
		swingFrame * CFrame.new(0, SWING_RIDER_SEAT_Y_OFFSET, SWING_RIDER_BACK_OFFSET),
		{
			className = "Seat",
			anchored = false,
			canCollide = true,
			canTouch = true,
			material = Enum.Material.SmoothPlastic,
			color = Color3.fromRGB(28, 28, 26),
			transparency = 1,
			castShadow = false,
		}
	)
	swingSeat.CustomPhysicalProperties = PhysicalProperties.new(1.8, 0.65, 0.05, 80, 15)
	swingSeat:SetAttribute("RideableType", "Swing")
	swingSeat:SetAttribute("HomeCFrame", swingSeat.CFrame)
	swingSeat:SetAttribute("MaximumSafeSpeed", 28)
	swingSeat:SetAttribute("TireCenterOffset", Vector3.new(0, -SWING_RIDER_SEAT_Y_OFFSET, -SWING_RIDER_BACK_OFFSET))
	swingSeat:SetAttribute("RiderPose", "SitInTireBottom")
	swing:SetAttribute("HomeSeatCFrame", swingSeat.CFrame)

	for segmentIndex = 1, 20 do
		local angle = ((segmentIndex - 1) / 20) * math.pi * 2
		local segmentLocalPosition = Vector3.new(
			math.cos(angle) * SWING_TIRE_RADIUS,
			math.sin(angle) * SWING_TIRE_RADIUS,
			0
		)
		local segment = makePart(
			swing,
			"TireSegment",
			Vector3.new(0.78, 0.56, 0.68),
			swingFrame * CFrame.new(segmentLocalPosition)
				* CFrame.Angles(0, 0, angle + (math.pi * 0.5)),
			{
				anchored = false,
				canCollide = false,
				canTouch = false,
				massless = true,
				material = Enum.Material.Rubber,
				color = Color3.fromRGB(34, 34, 31),
			}
		)
		weld(swingSeat, segment)
	end

	local ballast = makePart(
		swing,
		"StabilityBallast",
		Vector3.new(2.75, 0.38, 1.15),
		swingSeat.CFrame * CFrame.new(0, -0.48, -0.72),
		{
			anchored = false,
			canCollide = false,
			canQuery = false,
			castShadow = false,
			transparency = 1,
			massless = false,
		}
	)
	ballast.CustomPhysicalProperties = PhysicalProperties.new(4.5, 0.3, 0, 10, 10)
	weld(swingSeat, ballast)

	local forceAttachment = Instance.new("Attachment")
	forceAttachment.Name = "SwingForceAttachment"
	forceAttachment.Parent = swingSeat
	local controlForce = Instance.new("VectorForce")
	controlForce.Name = "SwingControlForce"
	controlForce.Attachment0 = forceAttachment
	controlForce.ApplyAtCenterOfMass = true
	controlForce.RelativeTo = Enum.ActuatorRelativeTo.World
	controlForce.Force = Vector3.zero
	controlForce.Parent = swingSeat
	local swingUpright = Instance.new("AlignOrientation")
	swingUpright.Name = "SwingUpright"
	swingUpright.Attachment0 = forceAttachment
	swingUpright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	swingUpright.RigidityEnabled = false
	swingUpright.Responsiveness = 16
	swingUpright.MaxAngularVelocity = 8
	swingUpright.MaxTorque = 38000
	swingUpright.CFrame = swingSeat.CFrame.Rotation
	swingUpright.Parent = swingSeat

	for sideIndex, sideName in ipairs({ "Left", "Right" }) do
		local top = Instance.new("Attachment")
		top.Name = "SwingTop" .. sideName
		top.Parent = branch
		-- Parent first so assigning WorldCFrame is converted into the branch's
		-- rotated local space instead of being transformed a second time.
		top.WorldCFrame = CFrame.new(swingTopPoints[sideIndex])

		local bottom = Instance.new("Attachment")
		bottom.Name = "SwingSeat" .. sideName
		bottom.Parent = swingSeat
		-- Keep the rope/seat assembly in the tire plane so the default Roblox
		-- seated pose remains upright through the opening. This is assigned as an
		-- exact world position; Roblox converts it to the seat-local attachment.
		bottom.WorldCFrame = CFrame.new(swingBottomPoints[sideIndex])

		local rope = Instance.new("RopeConstraint")
		rope.Name = "SwingRope" .. sideName
		rope.Attachment0 = top
		rope.Attachment1 = bottom
		rope.Length = (top.WorldPosition - bottom.WorldPosition).Magnitude
		rope.Restitution = 0
		rope.Thickness = 0.11
		rope.Visible = true
		rope.Color = BrickColor.new("Reddish brown")
		rope.Parent = swing
	end

	local swingPrompt = Instance.new("ProximityPrompt")
	swingPrompt.Name = "RidePrompt"
	swingPrompt.ActionText = "Sit and swing"
	swingPrompt.ObjectText = "Cooper tire swing"
	swingPrompt.KeyboardKeyCode = Enum.KeyCode.E
	swingPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	swingPrompt.HoldDuration = 0.15
	swingPrompt.MaxActivationDistance = 8
	swingPrompt.RequiresLineOfSight = false
	swingPrompt.Parent = swingSeat

	-- TRIKE -----------------------------------------------------------------
	-- The server advances an anchored root through raycast-sampled ground poses.
	-- Wheels and chassis do not collide with terrain, so grass/sidewalk/curb/road
	-- seams cannot catch them. A raised invisible proxy remains solid to players,
	-- and decorative wheels stay hinged for visual rotation.
	local trike = Instance.new("Model")
	trike.Name = "CooperRedYellowTrike"
	trike:SetAttribute("RideableType", "Trike")
	trike:SetAttribute("HomeCFrame", TRIKE_HOME)
	trike:SetAttribute("MotionMode", "ServerKinematicGroundFollower")
	trike:SetAttribute("RideHeight", TRIKE_RIDE_HEIGHT)
	trike:SetAttribute("ObstacleProbeSize", TRIKE_OBSTACLE_PROBE_SIZE)
	trike:SetAttribute("ObstacleProbeOffset", TRIKE_OBSTACLE_PROBE_OFFSET)
	trike:SetAttribute("ObstacleSweepVersion", 1)
	trike:SetAttribute("PlayerCollisionProxyVersion", 1)
	trike.Parent = rideables

	local chassis = makePart(
		trike,
		"Chassis",
		Vector3.new(1.42, 0.28, 2.65),
		TRIKE_HOME,
		{
			anchored = true,
			canCollide = false,
			canTouch = false,
			transparency = 1,
			castShadow = false,
		}
	)
	chassis.CustomPhysicalProperties = PhysicalProperties.new(2.25, 0.05, 0, 100, 25)
	chassis:SetAttribute("HomeCFrame", TRIKE_HOME)
	chassis:SetAttribute("MaximumSafeSpeed", 38)
	chassis:SetAttribute("RideHeight", TRIKE_RIDE_HEIGHT)
	chassis:SetAttribute("ObstacleProbeSize", TRIKE_OBSTACLE_PROBE_SIZE)
	chassis:SetAttribute("ObstacleProbeOffset", TRIKE_OBSTACLE_PROBE_OFFSET)
	chassis:SetAttribute("ObstacleSweepVersion", 1)
	chassis:SetAttribute("PlayerCollisionProxyVersion", 1)
	trike.PrimaryPart = chassis

	local playerCollisionProxy = makePart(
		trike,
		"PlayerCollisionProxy",
		TRIKE_PLAYER_COLLISION_PROXY_SIZE,
		TRIKE_HOME * CFrame.new(TRIKE_PLAYER_COLLISION_PROXY_OFFSET),
		{
			anchored = true,
			canCollide = true,
			canTouch = false,
			canQuery = true,
			transparency = 1,
			castShadow = false,
			massless = true,
		}
	)
	playerCollisionProxy:SetAttribute("CollisionPurpose", "PlayerBlocker")
	playerCollisionProxy:SetAttribute("PlayerCollisionProxyVersion", 1)
	playerCollisionProxy:SetAttribute("ChassisLocalOffset", TRIKE_PLAYER_COLLISION_PROXY_OFFSET)
	weld(chassis, playerCollisionProxy)

	local chassisAttachment = Instance.new("Attachment")
	chassisAttachment.Name = "TrikeForceAttachment"
	chassisAttachment.Parent = chassis
	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "TrikeDriveForce"
	driveForce.Attachment0 = chassisAttachment
	driveForce.ApplyAtCenterOfMass = true
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.Force = Vector3.zero
	driveForce.Parent = chassis
	local upright = Instance.new("AlignOrientation")
	upright.Name = "TrikeUpright"
	upright.Attachment0 = chassisAttachment
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.RigidityEnabled = false
	upright.Responsiveness = 18
	upright.MaxAngularVelocity = 7
	upright.MaxTorque = 45000
	upright.CFrame = TRIKE_HOME.Rotation
	upright.Parent = chassis

	local RED = Color3.fromRGB(183, 47, 37)
	local YELLOW = Color3.fromRGB(239, 179, 33)
	local DARK_RED = Color3.fromRGB(116, 34, 30)
	local METAL = Color3.fromRGB(196, 188, 169)
	local frameOptions = {
		anchored = true,
		canCollide = false,
		canTouch = false,
		massless = true,
		material = Enum.Material.Metal,
		color = RED,
	}

	local frameSpine = makeBeam(
		trike,
		"RedFrameSpine",
		(TRIKE_HOME * CFrame.new(0, 0.65, 1.18)).Position,
		(TRIKE_HOME * CFrame.new(0, 0.82, -1.15)).Position,
		0.27,
		frameOptions
	)
	weld(chassis, frameSpine)
	local seatPost = makeBeam(
		trike,
		"RedSeatPost",
		(TRIKE_HOME * CFrame.new(0, 0.62, 0.9)).Position,
		(TRIKE_HOME * CFrame.new(0, 1.62, 1.35)).Position,
		0.25,
		frameOptions
	)
	weld(chassis, seatPost)
	local frontFork = makeBeam(
		trike,
		"RedFrontFork",
		(TRIKE_HOME * CFrame.new(0, 0.58, -1.55)).Position,
		(TRIKE_HOME * CFrame.new(0, 2.05, -1.25)).Position,
		0.23,
		frameOptions
	)
	weld(chassis, frontFork)
	local rearAxle = makePart(
		trike,
		"RearAxle",
		Vector3.new(2.75, 0.22, 0.22),
		TRIKE_HOME * CFrame.new(0, 0.28, 1.08),
		frameOptions
	)
	rearAxle.Color = METAL
	weld(chassis, rearAxle)
	local handlebar = makePart(
		trike,
		"Handlebar",
		Vector3.new(2.05, 0.2, 0.2),
		TRIKE_HOME * CFrame.new(0, 2.12, -1.25),
		frameOptions
	)
	handlebar.Color = YELLOW
	weld(chassis, handlebar)

	local vehicleSeat = makePart(
		trike,
		"TrikeSeat",
		Vector3.new(1.65, 0.42, 1.08),
		TRIKE_HOME * CFrame.new(0, 1.62, 1.32),
		{
			className = "VehicleSeat",
			anchored = true,
			canCollide = false,
			canTouch = true,
			material = Enum.Material.SmoothPlastic,
			color = YELLOW,
		}
	)
	vehicleSeat.MaxSpeed = 0
	vehicleSeat.Torque = 0
	vehicleSeat.TurnSpeed = 0
	vehicleSeat:SetAttribute("RideableType", "Trike")
	weld(chassis, vehicleSeat)

	local trikePrompt = Instance.new("ProximityPrompt")
	trikePrompt.Name = "RidePrompt"
	trikePrompt.ActionText = "Ride"
	trikePrompt.ObjectText = "Red and yellow trike"
	trikePrompt.KeyboardKeyCode = Enum.KeyCode.E
	trikePrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	trikePrompt.HoldDuration = 0.15
	trikePrompt.MaxActivationDistance = 9
	trikePrompt.RequiresLineOfSight = false
	trikePrompt.Parent = vehicleSeat

	local wheelSpecifications = {
		{ name = "FrontWheel", offset = Vector3.new(0, 0.62, -1.55), diameter = 2.0, width = 0.46 },
		{ name = "RearWheelLeft", offset = Vector3.new(-1.08, 0.32, 1.08), diameter = 1.34, width = 0.42 },
		{ name = "RearWheelRight", offset = Vector3.new(1.08, 0.32, 1.08), diameter = 1.34, width = 0.42 },
	}
	for _, specification in ipairs(wheelSpecifications) do
		local wheelCFrame = TRIKE_HOME * CFrame.new(specification.offset)
		local wheel = makePart(
			trike,
			specification.name,
			Vector3.new(specification.width, specification.diameter, specification.diameter),
			wheelCFrame,
			{
				anchored = true,
				canCollide = false,
				canTouch = false,
				massless = true,
				material = Enum.Material.SmoothPlastic,
				color = DARK_RED,
			}
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel:SetAttribute("WheelRadius", specification.diameter / 2)

		local rootAttachment = Instance.new("Attachment")
		rootAttachment.Name = specification.name .. "Axle"
		rootAttachment.Position = specification.offset
		rootAttachment.Axis = Vector3.xAxis
		rootAttachment.SecondaryAxis = Vector3.yAxis
		rootAttachment.Parent = chassis
		local wheelAttachment = Instance.new("Attachment")
		wheelAttachment.Name = "AxleAttachment"
		wheelAttachment.Axis = Vector3.xAxis
		wheelAttachment.SecondaryAxis = Vector3.yAxis
		wheelAttachment.Parent = wheel

		local hinge = Instance.new("HingeConstraint")
		hinge.Name = specification.name .. "Hinge"
		hinge.Attachment0 = rootAttachment
		hinge.Attachment1 = wheelAttachment
		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.AngularVelocity = 0
		hinge.MotorMaxAcceleration = 500
		hinge.MotorMaxTorque = 7
		hinge.Parent = trike

		local hub = makePart(
			trike,
			specification.name .. "YellowHub",
			Vector3.new(specification.width + 0.08, 0.38, 0.38),
			wheelCFrame,
			{
				anchored = true,
				canCollide = false,
				canTouch = false,
				massless = true,
				material = Enum.Material.SmoothPlastic,
				color = YELLOW,
			}
		)
		hub.Shape = Enum.PartType.Cylinder
		weld(wheel, hub)
	end

	-- Keep every trike assembly parked until the authoritative server script
	-- sees a rider. This prevents a half-installed vehicle rolling away.
	for _, descendant in ipairs(trike:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	print(string.format(
		"[CooperYardRideables] Installed v%s: swing at %s; trike at %s",
		INSTALL_VERSION,
		tostring(SWING_CENTER),
		tostring(TRIKE_HOME.Position)
	))
end, debug.traceback)

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(
			recording,
			ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
		)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("Install Cooper yard rideables")
	end)
end

if not ok then
	error(failure, 0)
end

return landscaping:FindFirstChild(RIDEABLES_NAME)
