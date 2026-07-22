-- Authoritative runtime controller for the Cooper house yard swing and trike.
-- Install as ServerScriptService.CooperYardRideables.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local REMOTES_NAME = "CooperYardRideablesRemotes"
local EVENT_NAME = "RideablesEvent"
local RIDEABLES_NAME = "CooperYardRideables"
local CONTROLLER_VERSION = "2.3.0"

local SWING_PUMP_INTERVAL = 0.09
local SWING_PUMP_DURATION = 0.16
local SWING_MAX_SPEED = 28
local SWING_MAX_DISTANCE = 16
local SWING_IDLE_RESET_SECONDS = 22
local SWING_RIDER_VERTICAL_DROP = 0.78

local TRIKE_INPUT_INTERVAL = 0.045
local TRIKE_INPUT_TIMEOUT = 0.45
local TRIKE_FORWARD_SPEED = 34
local TRIKE_REVERSE_SPEED = 26
local TRIKE_MAX_SPEED = 38
local TRIKE_ACCELERATION = 46
local TRIKE_BRAKING = 58
local TRIKE_COAST_DECELERATION = 20
local TRIKE_STEER_RATE = math.rad(104)
local TRIKE_GROUND_RAY_UP = 5
local TRIKE_GROUND_RAY_DOWN = 14
local TRIKE_MAX_STEP_UP = 2.75
local TRIKE_MAX_DROP = 3.5
local TRIKE_GROUND_LOST_SECONDS = 1.15
local TRIKE_MAX_SUBSTEP_DISTANCE = 0.55
local TRIKE_PARK_DELAY = 3
local TRIKE_OBSTACLE_SAMPLE_DISTANCE = 0.18
local TRIKE_OBSTACLE_GROUND_TOLERANCE = 0.22
local DEFAULT_TRIKE_OBSTACLE_PROBE_SIZE = Vector3.new(3.10, 2.50, 4.80)
local DEFAULT_TRIKE_OBSTACLE_PROBE_OFFSET = Vector3.new(0, 1.02, -0.34)

local remotes = ReplicatedStorage:WaitForChild(REMOTES_NAME, 15)
assert(remotes, REMOTES_NAME .. " was not installed")
local rideablesEvent = remotes:WaitForChild(EVENT_NAME, 15)
assert(rideablesEvent and rideablesEvent:IsA("RemoteEvent"), EVENT_NAME .. " was not installed")

local environment = Workspace:WaitForChild("CooperHouseEnvironment", 15)
assert(environment, "CooperHouseEnvironment was not found")
local siteAndStreet = environment:FindFirstChild("SiteAndStreet")
local landscaping = environment:WaitForChild("Landscaping", 15)
assert(landscaping, "CooperHouseEnvironment.Landscaping was not found")
local rideables = landscaping:WaitForChild(RIDEABLES_NAME, 15)
assert(rideables, RIDEABLES_NAME .. " was not installed")
assert(
	rideables:GetAttribute("InstallVersion") == CONTROLLER_VERSION,
	string.format("%s requires yard rideables installer v%s", script.Name, CONTROLLER_VERSION)
)
rideables:SetAttribute("ControllerVersion", CONTROLLER_VERSION)

local swing = rideables:FindFirstChild("FrontYardTireSwing")
	or rideables:WaitForChild("FrontYardRopeSwing", 15)
assert(swing, "Functional front-yard tire swing was not installed")
local swingSeat = swing:WaitForChild("SwingSeat")
local swingForce = swingSeat:WaitForChild("SwingControlForce")
local swingPrompt = swingSeat:WaitForChild("RidePrompt")
assert(swingSeat:IsA("Seat"), "FrontYardTireSwing.SwingSeat must be a Seat")
assert(swingForce:IsA("VectorForce"), "SwingControlForce must be a VectorForce")
assert(swingPrompt:IsA("ProximityPrompt"), "Swing RidePrompt must be a ProximityPrompt")

local trike = rideables:WaitForChild("CooperRedYellowTrike")
local chassis = trike:WaitForChild("Chassis")
local trikeSeat = trike:WaitForChild("TrikeSeat")
local trikeForce = chassis:WaitForChild("TrikeDriveForce")
local trikeUpright = chassis:WaitForChild("TrikeUpright")
local trikePrompt = trikeSeat:WaitForChild("RidePrompt")
local trikeCollisionProxy = trike:WaitForChild("PlayerCollisionProxy")
assert(trikeSeat:IsA("VehicleSeat"), "CooperRedYellowTrike.TrikeSeat must be a VehicleSeat")
assert(trikeForce:IsA("VectorForce"), "TrikeDriveForce must be a VectorForce")
assert(trikeUpright:IsA("AlignOrientation"), "TrikeUpright must be an AlignOrientation")
assert(trikePrompt:IsA("ProximityPrompt"), "Trike RidePrompt must be a ProximityPrompt")
assert(trikeCollisionProxy:IsA("BasePart"), "Trike PlayerCollisionProxy must be a BasePart")
assert(
	trikeCollisionProxy:GetAttribute("PlayerCollisionProxyVersion") == 1,
	"Trike PlayerCollisionProxy is stale"
)
trike.PrimaryPart = chassis
assert(
	trike:GetAttribute("MotionMode") == "ServerKinematicGroundFollower",
	"Trike requires the v2.3 ground-following/collision installer"
)

local function finiteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) < 100000
end

local function finiteVector3(value)
	return typeof(value) == "Vector3"
		and finiteNumber(value.X)
		and finiteNumber(value.Y)
		and finiteNumber(value.Z)
end

local swingRopes = {}
for _, ropeName in ipairs({ "SwingRopeLeft", "SwingRopeRight" }) do
	local rope = swing:FindFirstChild(ropeName)
	assert(rope and rope:IsA("RopeConstraint"), ropeName .. " is missing")
	assert(rope.Attachment0 and rope.Attachment1, ropeName .. " attachments are missing")
	assert(rope.Attachment1.Parent == swingSeat, ropeName .. " lower attachment must belong to SwingSeat")
	table.insert(swingRopes, rope)
end

-- A previous installer could leave a valid-looking but stale HomeCFrame on the
-- Seat. Resetting to it teleported the tire away from its anchored branch and
-- stretched the ropes across the yard. Reconstruct the only physically valid
-- home position from the top anchors, authored rope lengths, and seat-local
-- lower attachments, then reject any stored pose that disagrees with it.
local storedSwingHome = swingSeat:GetAttribute("HomeCFrame")
local preferredRotation = typeof(storedSwingHome) == "CFrame"
	and storedSwingHome.Rotation
	or swingSeat.CFrame.Rotation

local derivedHomePosition = Vector3.zero
for _, rope in ipairs(swingRopes) do
	assert(finiteNumber(rope.Length) and rope.Length > 1 and rope.Length < 50, rope.Name .. " length is invalid")
	local desiredBottom = rope.Attachment0.WorldPosition - (Vector3.yAxis * rope.Length)
	local lowerOffset = preferredRotation:VectorToWorldSpace(rope.Attachment1.Position)
	derivedHomePosition += desiredBottom - lowerOffset
end
derivedHomePosition /= #swingRopes
assert(finiteVector3(derivedHomePosition), "Derived swing home position is invalid")
local derivedSwingHome = CFrame.new(derivedHomePosition) * preferredRotation

local function maximumRopeError(homeCFrame)
	if typeof(homeCFrame) ~= "CFrame" or not finiteVector3(homeCFrame.Position) then
		return math.huge
	end
	local maximumError = 0
	for _, rope in ipairs(swingRopes) do
		local bottomAtHome = homeCFrame:PointToWorldSpace(rope.Attachment1.Position)
		local distance = (rope.Attachment0.WorldPosition - bottomAtHome).Magnitude
		maximumError = math.max(maximumError, math.abs(distance - rope.Length))
	end
	return maximumError
end

local swingHome = storedSwingHome
if maximumRopeError(swingHome) > 0.2
	or (swingHome.Position - derivedSwingHome.Position).Magnitude > 0.5
then
	swingHome = derivedSwingHome
	warn("[CooperYardRideables] Repaired stale swing HomeCFrame from rope geometry")
end
swingSeat:SetAttribute("HomeCFrame", swingHome)
swing:SetAttribute("HomeSeatCFrame", swingHome)

-- The authored chassis pose is the durable source of truth.  Absolute
-- HomeCFrame attributes can become stale when the complete house environment is
-- moved in Studio; trusting one here used to teleport the trike into the house
-- foundation during the startup reset.  Repair both copies before any reset so
-- future map moves cannot make a correctly placed trike disappear.
local authoredTrikeHome = chassis.CFrame
local storedTrikeHome = chassis:GetAttribute("HomeCFrame") or trike:GetAttribute("HomeCFrame")
local trikeHome = storedTrikeHome
local storedHomeIsStale = typeof(storedTrikeHome) ~= "CFrame"
if not storedHomeIsStale then
	local positionError = (storedTrikeHome.Position - authoredTrikeHome.Position).Magnitude
	local orientationAlignment = math.min(
		storedTrikeHome.RightVector:Dot(authoredTrikeHome.RightVector),
		storedTrikeHome.UpVector:Dot(authoredTrikeHome.UpVector),
		storedTrikeHome.LookVector:Dot(authoredTrikeHome.LookVector)
	)
	storedHomeIsStale = positionError > 0.5 or orientationAlignment < 0.995
end
if storedHomeIsStale then
	trikeHome = authoredTrikeHome
	warn("[CooperYardRideables] Repaired stale trike HomeCFrame from authored chassis pose")
end
chassis:SetAttribute("HomeCFrame", trikeHome)
trike:SetAttribute("HomeCFrame", trikeHome)

local trikeRideHeight = chassis:GetAttribute("RideHeight") or trike:GetAttribute("RideHeight")
assert(finiteNumber(trikeRideHeight) and trikeRideHeight > 0.1 and trikeRideHeight < 3, "Trike RideHeight is invalid")

-- The visible trike remains non-collidable so it can follow uneven yard and
-- sidewalk surfaces without snagging. This slightly padded server-side box is
-- its authoritative obstacle envelope. Its bottom sits above the wheel contact
-- patch, allowing valid supporting ground while still catching walls, furniture,
-- vehicles, and delivery crates before the visible model reaches them.
local chassisProbeSize = chassis:GetAttribute("ObstacleProbeSize")
local modelProbeSize = trike:GetAttribute("ObstacleProbeSize")
local trikeObstacleProbeSize = if finiteVector3(chassisProbeSize)
	then chassisProbeSize
	elseif finiteVector3(modelProbeSize)
	then modelProbeSize
	else DEFAULT_TRIKE_OBSTACLE_PROBE_SIZE
local chassisProbeOffset = chassis:GetAttribute("ObstacleProbeOffset")
local modelProbeOffset = trike:GetAttribute("ObstacleProbeOffset")
local trikeObstacleProbeOffset = if finiteVector3(chassisProbeOffset)
	then chassisProbeOffset
	elseif finiteVector3(modelProbeOffset)
	then modelProbeOffset
	else DEFAULT_TRIKE_OBSTACLE_PROBE_OFFSET
assert(
	trikeObstacleProbeSize.X > 0.5
		and trikeObstacleProbeSize.Y > 0.5
		and trikeObstacleProbeSize.Z > 0.5,
	"Trike ObstacleProbeSize is invalid"
)
chassis:SetAttribute("ObstacleProbeSize", trikeObstacleProbeSize)
chassis:SetAttribute("ObstacleProbeOffset", trikeObstacleProbeOffset)
trike:SetAttribute("ObstacleProbeSize", trikeObstacleProbeSize)
trike:SetAttribute("ObstacleProbeOffset", trikeObstacleProbeOffset)

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function horizontalUnit(vector, fallback)
	local flat = horizontal(vector)
	if flat.Magnitude < 0.001 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function moveToward(current: number, target: number, maximumDelta: number): number
	if current < target then
		return math.min(current + maximumDelta, target)
	end
	return math.max(current - maximumDelta, target)
end

local function playerFromSeat(seat)
	local humanoid = seat.Occupant
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent)
end

local function characterHumanoid(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil
	end
	return humanoid, root
end

local function mayUsePrompt(player, part, maximumDistance)
	local humanoid, root = characterHumanoid(player)
	if not humanoid or humanoid.Sit then
		return nil
	end
	if (root.Position - part.Position).Magnitude > maximumDistance then
		return nil
	end
	return humanoid
end

local function lowerSwingRider()
	-- Preserve Roblox's normal upright seated pose, but lower that pose inside
	-- the tire opening so the avatar's head clears the upper rubber segment.
	-- This only translates the generated weld; it never rotates the character.
	task.spawn(function()
		for _ = 1, 12 do
			if not swingSeat.Occupant then
				return
			end
			local weld = swingSeat:FindFirstChild("SeatWeld")
			if weld and weld:IsA("Weld") then
				if weld:GetAttribute("TireSwingLowered") ~= true then
					-- Pre-multiply so the translation is along the Seat's local Y.
					-- Post-multiplying translates in the character weld's rotated
					-- axes and pushes the rider forward through the tire instead.
					weld.C0 = CFrame.new(0, -SWING_RIDER_VERTICAL_DROP, 0) * weld.C0
					weld:SetAttribute("TireSwingLowered", true)
					weld:SetAttribute("VerticalDrop", SWING_RIDER_VERTICAL_DROP)
					weld:SetAttribute("DropSpace", "SeatLocalY")
				end
				return
			end
			task.wait(0.05)
		end
	end)
end

local function setAssemblyServerOwned(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				local canSet = descendant:CanSetNetworkOwnership()
				if canSet then
					descendant:SetNetworkOwner(nil)
				end
			end)
		end
	end
end

local function zeroModelVelocity(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function configureTrikeKinematicAssembly()
	for _, descendant in ipairs(trike:GetDescendants()) do
		if descendant:IsA("BasePart") then
			-- The chassis is the single anchored server-moved root. Everything else
			-- follows by weld/hinge. Only the raised invisible player blocker remains
			-- solid; the wheels and chassis cannot snag the lawn or sidewalk seams.
			descendant.Anchored = descendant == chassis
			descendant.CanCollide = descendant == trikeCollisionProxy
			descendant.CanTouch = descendant == trikeSeat
			if descendant == trikeCollisionProxy then
				descendant.CanQuery = true
				descendant.CastShadow = false
				descendant.Massless = true
				descendant.Transparency = 1
			end
		end
	end
	trikeForce.Force = Vector3.zero
	trikeForce.Enabled = false
	trikeUpright.Enabled = false
	setAssemblyServerOwned(trike)
end

-- The collision proxy must remain solid to every other player while the active
-- rider's avatar is allowed to occupy the seat directly above it. Pairwise
-- NoCollisionConstraints provide that exception without changing collision
-- groups globally or making the parked trike walk-through again.
local riderCollisionConstraints = {}
local riderDescendantConnection = nil
local riderCollisionGeneration = 0

local function clearRiderCollisionConstraints()
	if riderDescendantConnection then
		riderDescendantConnection:Disconnect()
		riderDescendantConnection = nil
	end
	for part, constraint in pairs(riderCollisionConstraints) do
		riderCollisionConstraints[part] = nil
		if constraint.Parent then
			constraint:Destroy()
		end
	end
end

local function excludeRiderPartFromProxy(part)
	if not part:IsA("BasePart") or riderCollisionConstraints[part] or not part.Parent then
		return
	end
	local constraint = Instance.new("NoCollisionConstraint")
	constraint.Name = "TrikeRiderNoCollision"
	constraint.Part0 = trikeCollisionProxy
	constraint.Part1 = part
	constraint.Parent = trikeCollisionProxy
	riderCollisionConstraints[part] = constraint
end

local function syncTrikeRiderCollision(humanoid)
	riderCollisionGeneration += 1
	local generation = riderCollisionGeneration
	if not humanoid then
		-- Keep the departing rider exempt through the seat-weld teardown and any
		-- same-frame reset teleport, then restore normal solid collision.
		task.delay(0.2, function()
			if riderCollisionGeneration == generation and trikeSeat.Occupant == nil then
				clearRiderCollisionConstraints()
			end
		end)
		return
	end

	clearRiderCollisionConstraints()
	local character = humanoid.Parent
	if not character or not character:IsA("Model") then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		excludeRiderPartFromProxy(descendant)
	end
	riderDescendantConnection = character.DescendantAdded:Connect(excludeRiderPartFromProxy)
end

local function releaseSeatOccupant(seat)
	local occupant = seat.Occupant
	if not occupant then
		return
	end
	-- Explicit recovery must detach before the rideable teleports home; otherwise
	-- a SeatWeld can drag or fling the character during the same physics step.
	local seatWeld = seat:FindFirstChild("SeatWeld")
	if seatWeld and (seatWeld:IsA("Weld") or seatWeld:IsA("WeldConstraint")) then
		seatWeld:Destroy()
	end
	occupant.Sit = false
	occupant:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local rateLimits = {}
local function passesRateLimit(player, action, interval)
	local now = os.clock()
	local playerLimits = rateLimits[player]
	if not playerLimits then
		playerLimits = {}
		rateLimits[player] = playerLimits
	end
	local previous = playerLimits[action] or 0
	if now - previous < interval then
		return false
	end
	playerLimits[action] = now
	return true
end

local swingInput = 0
local swingPumpUntil = 0
local swingEmptySince = os.clock()
local swingUpsideDownSince = nil
local swingResetGeneration = 0

local function resetSwing(dismount)
	swingResetGeneration += 1
	local resetGeneration = swingResetGeneration
	-- Keep the seat disabled and anchored for a brief settle window after a
	-- rider is released. Otherwise the departing avatar can immediately collide
	-- with the freshly reset tire and inject a new pendulum impulse.
	swingSeat.Disabled = true
	if dismount then
		releaseSeatOccupant(swingSeat)
	end
	swingPrompt.Enabled = false
	swingForce.Force = Vector3.zero
	swingSeat.Anchored = true
	swingSeat.CFrame = swingHome
	swingSeat.AssemblyLinearVelocity = Vector3.zero
	swingSeat.AssemblyAngularVelocity = Vector3.zero
	swingInput = 0
	swingPumpUntil = 0
	swingUpsideDownSince = nil
	swingEmptySince = os.clock()
	task.delay(dismount and 0.3 or 0.08, function()
		if swingResetGeneration ~= resetGeneration or not swingSeat.Parent then
			return
		end
		-- Re-apply the exact authored rest pose after the former rider has had a
		-- frame to clear the tire, then release a motionless server-owned assembly.
		swingSeat.CFrame = swingHome
		swingSeat.AssemblyLinearVelocity = Vector3.zero
		swingSeat.AssemblyAngularVelocity = Vector3.zero
		swingSeat.Anchored = false
		setAssemblyServerOwned(swing)
		swingSeat.Disabled = false
		swingPrompt.Enabled = swingSeat.Occupant == nil
	end)
end

local trikeControl = {
	player = nil,
	throttle = 0,
	steer = 0,
	updatedAt = 0,
}
local trikeEmptySince = os.clock()
local trikeTippedSince = nil
local trikeYaw = 0
local trikeParked = true
local trikeSpeed = 0
local trikeLastGroundedAt = os.clock()

local function yawFromCFrame(cframe)
	local look = cframe.LookVector
	return math.atan2(-look.X, -look.Z)
end

local wheelHinges = {}
for _, descendant in ipairs(trike:GetDescendants()) do
	if descendant:IsA("HingeConstraint") and string.find(descendant.Name, "Wheel", 1, true) then
		table.insert(wheelHinges, descendant)
	end
end

local function setWheelSpeed(linearSpeed)
	for _, hinge in ipairs(wheelHinges) do
		local wheel = hinge.Attachment1 and hinge.Attachment1.Parent
		local radius = wheel and wheel:GetAttribute("WheelRadius") or 0.7
		if not finiteNumber(radius) or radius < 0.1 then
			radius = 0.7
		end
		hinge.AngularVelocity = -linearSpeed / radius
	end
end

local trikeGroundParams = RaycastParams.new()
trikeGroundParams.FilterType = Enum.RaycastFilterType.Exclude
trikeGroundParams.IgnoreWater = true
trikeGroundParams.RespectCanCollide = true

local trikeObstacleParams = OverlapParams.new()
trikeObstacleParams.FilterType = Enum.RaycastFilterType.Exclude
trikeObstacleParams.RespectCanCollide = true
trikeObstacleParams.MaxParts = 0

local function refreshTrikeSpatialFilters()
	local groundExcluded = { rideables }
	local obstacleExcluded = { trike }
	-- Characters are never valid ground. Excluding every current character also
	-- prevents a kinematic trike from climbing or blocking on another player in
	-- multiplayer. Other collidable world objects remain eligible obstacles.
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(groundExcluded, player.Character)
			table.insert(obstacleExcluded, player.Character)
		end
	end
	trikeGroundParams.FilterDescendantsInstances = groundExcluded
	trikeObstacleParams.FilterDescendantsInstances = obstacleExcluded
end

local GROUND_NAME_MARKERS = {
	"floor",
	"ground",
	"street",
	"road",
	"driveway",
	"walk",
	"curb",
	"lot",
	"carpet",
	"linoleum",
	"mosaic",
	"rug",
	"subfloor",
	"foundation",
	"porch",
	"patio",
	"sidewalk",
	"lawn",
	"grass",
	"concrete",
}

local function isDesignatedTrikeGroundPart(instance)
	if instance == Workspace.Terrain then
		return true
	end
	if not instance or not instance:IsA("BasePart") or not instance.CanCollide then
		return false
	end
	if instance:GetAttribute("TrikeGroundSurface") == true then
		return true
	end
	-- This model contains only the lot, roads, driveway, walk, and curbs. It is
	-- deliberately separate from PeriodVehicles, so vehicles never become ground.
	if siteAndStreet and instance:IsDescendantOf(siteAndStreet) then
		return true
	end
	if instance.Parent == Workspace and instance.Name == "Baseplate" then
		return true
	end
	local loweredName = string.lower(instance.Name)
	local namedLikeGround = false
	for _, marker in ipairs(GROUND_NAME_MARKERS) do
		if string.find(loweredName, marker, 1, true) then
			namedLikeGround = true
			break
		end
	end
	if not namedLikeGround then
		return false
	end
	-- A wall or tall prop with an unfortunate name must not be whitelisted. Real
	-- floors, rugs, slabs, foundations, and curbs in this map are at most two
	-- studs thick in world Y.
	local verticalThickness = math.abs(instance.CFrame.RightVector.Y) * instance.Size.X
		+ math.abs(instance.CFrame.UpVector.Y) * instance.Size.Y
		+ math.abs(instance.CFrame.LookVector.Y) * instance.Size.Z
	return verticalThickness <= 2.1
end

local function groundRay(horizontalPosition, referenceY)
	local origin = Vector3.new(
		horizontalPosition.X,
		referenceY + TRIKE_GROUND_RAY_UP,
		horizontalPosition.Z
	)
	local result = Workspace:Raycast(
		origin,
		Vector3.new(0, -TRIKE_GROUND_RAY_DOWN, 0),
		trikeGroundParams
	)
	if not result then
		return nil, nil
	end
	if result.Normal.Y >= 0.45 and isDesignatedTrikeGroundPart(result.Instance) then
		return result, nil
	end
	-- A collidable crate, vehicle, furniture item, or wall intercepted the
	-- downward support ray. Report it as an obstacle instead of climbing it.
	return nil, result.Instance
end

local function groundPoseAt(horizontalPosition, yaw, referenceY)
	local yawFrame = CFrame.Angles(0, yaw, 0)
	local forward = yawFrame.LookVector
	local right = yawFrame.RightVector
	local centerHit, centerObstacle = groundRay(horizontalPosition, referenceY)
	if not centerHit then
		return nil, centerObstacle and "Obstacle" or "NoGround", nil, centerObstacle
	end
	local supportParts = {}
	if centerHit.Instance then
		supportParts[centerHit.Instance] = true
	end

	local targetY = centerHit.Position.Y + trikeRideHeight
	local heightDelta = targetY - referenceY
	if heightDelta > TRIKE_MAX_STEP_UP or heightDelta < -TRIKE_MAX_DROP then
		return nil, "UnsafeStep"
	end

	-- Side/front/rear probes improve pitch and roll on grass banks and driveway
	-- transitions. The center hit remains the authoritative ride height so curb
	-- tops cannot wedge a collision box underneath the vehicle.
	local normalSum = centerHit.Normal
	local normalCount = 1
	for _, offset in ipairs({
		forward * 1.20,
		-forward * 1.00,
		right * 0.58,
		-right * 0.58,
	}) do
		local hit = groundRay(horizontalPosition + offset, referenceY)
		if hit and math.abs(hit.Position.Y - centerHit.Position.Y) <= 2.5 then
			normalSum += hit.Normal
			normalCount += 1
			if hit.Instance then
				supportParts[hit.Instance] = true
			end
		end
	end

	local up = normalSum / normalCount
	if up.Magnitude < 0.1 then
		up = Vector3.yAxis
	else
		up = up.Unit
	end
	if up.Y < 0.48 then
		return nil, "UnsafeSlope"
	end

	local groundedForward = forward - up * forward:Dot(up)
	if groundedForward.Magnitude < 0.1 then
		groundedForward = forward
	else
		groundedForward = groundedForward.Unit
	end
	local groundedRight = groundedForward:Cross(up).Unit
	local correctedUp = groundedRight:Cross(groundedForward).Unit
	local position = Vector3.new(horizontalPosition.X, targetY, horizontalPosition.Z)
	return CFrame.fromMatrix(position, groundedRight, correctedUp, -groundedForward), nil, supportParts
end

local function verticalHalfExtent(cframe, size)
	return math.abs(cframe.RightVector.Y) * size.X * 0.5
		+ math.abs(cframe.UpVector.Y) * size.Y * 0.5
		+ math.abs(cframe.LookVector.Y) * size.Z * 0.5
end

local function obstacleProbeCFrame(chassisPose)
	return chassisPose * CFrame.new(trikeObstacleProbeOffset)
end

local function isValidGroundOverlap(part, probeCFrame, supportParts)
	if isDesignatedTrikeGroundPart(part) or (supportParts and supportParts[part]) then
		return true
	end
	-- At floor, lawn, driveway, and sidewalk seams the overlap box can touch a
	-- neighboring support part that one of the downward rays did not select. A
	-- part wholly below the probe's contact band is supporting ground, not a wall.
	local probeBottom = probeCFrame.Position.Y
		- verticalHalfExtent(probeCFrame, trikeObstacleProbeSize)
	local partTop = part.Position.Y + verticalHalfExtent(part.CFrame, part.Size)
	return partTop <= probeBottom + TRIKE_OBSTACLE_GROUND_TOLERANCE
end

local function obstacleAtPose(chassisPose, supportParts)
	local probeCFrame = obstacleProbeCFrame(chassisPose)
	for _, part in ipairs(Workspace:GetPartBoundsInBox(
		probeCFrame,
		trikeObstacleProbeSize,
		trikeObstacleParams
	)) do
		if part.CanCollide and not isValidGroundOverlap(part, probeCFrame, supportParts) then
			return part
		end
	end
	return nil
end

local function firstObstacleBetween(fromPose, toPose, supportParts)
	local linearTravel = (toPose.Position - fromPose.Position).Magnitude
	local _, rotationAngle = fromPose:ToObjectSpace(toPose):ToAxisAngle()
	local cornerRadius = trikeObstacleProbeSize.Magnitude * 0.5
	local sweptTravel = math.max(linearTravel, math.abs(rotationAngle) * cornerRadius)
	local sampleCount = math.max(1, math.ceil(sweptTravel / TRIKE_OBSTACLE_SAMPLE_DISTANCE))
	for index = 1, sampleCount do
		local sampledPose = fromPose:Lerp(toPose, index / sampleCount)
		local obstacle = obstacleAtPose(sampledPose, supportParts)
		if obstacle then
			return obstacle
		end
	end
	return nil
end

local trikeObstacleBlocked = false
local function setTrikeObstacleState(obstacle)
	local blocked = obstacle ~= nil
	if blocked ~= trikeObstacleBlocked or trike:GetAttribute("ObstacleBlocked") ~= blocked then
		trikeObstacleBlocked = blocked
		trike:SetAttribute("ObstacleBlocked", blocked)
	end
	if obstacle then
		local obstacleName = obstacle:GetFullName()
		if trike:GetAttribute("LastObstacleName") ~= obstacleName then
			trike:SetAttribute("LastObstacleName", obstacleName)
		end
	elseif trike:GetAttribute("LastObstacleName") ~= nil then
		trike:SetAttribute("LastObstacleName", nil)
	end
end

local function resetTrike(dismount)
	if dismount then
		releaseSeatOccupant(trikeSeat)
	end
	trikeForce.Force = Vector3.zero
	setWheelSpeed(0)
	configureTrikeKinematicAssembly()
	trike:PivotTo(trikeHome)
	zeroModelVelocity(trike)
	trikeYaw = yawFromCFrame(trikeHome)
	trikeSpeed = 0
	trikeControl.player = nil
	trikeControl.throttle = 0
	trikeControl.steer = 0
	trikeControl.updatedAt = 0
	trikeEmptySince = os.clock()
	trikeTippedSince = nil
	trikeLastGroundedAt = os.clock()
	trikeParked = true
	setTrikeObstacleState(nil)
end

local function unparkTrike()
	if trikeParked then
		configureTrikeKinematicAssembly()
		trikeParked = false
		trikeLastGroundedAt = os.clock()
	end
	setAssemblyServerOwned(trike)
end

swingPrompt.Triggered:Connect(function(player)
	if swingSeat.Occupant then
		return
	end
	local humanoid = mayUsePrompt(player, swingSeat, 11)
	if humanoid then
		-- SwingSeat is already mounted at the tire's inner bottom. Preserve
		-- Roblox's generated SeatWeld orientation so the avatar remains upright.
		swingSeat:Sit(humanoid)
		lowerSwingRider()
	end
end)

trikePrompt.Triggered:Connect(function(player)
	if trikeSeat.Occupant then
		return
	end
	local humanoid = mayUsePrompt(player, trikeSeat, 12)
	if humanoid then
		unparkTrike()
		trikeSeat:Sit(humanoid)
	end
end)

swingSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
	local rider = playerFromSeat(swingSeat)
	swingPrompt.Enabled = swingSeat.Occupant == nil
	swingInput = 0
	swingPumpUntil = 0
	if rider then
		lowerSwingRider()
		setAssemblyServerOwned(swing)
	else
		swingEmptySince = os.clock()
	end
end)

trikeSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
	syncTrikeRiderCollision(trikeSeat.Occupant)
	local rider = playerFromSeat(trikeSeat)
	trikePrompt.Enabled = trikeSeat.Occupant == nil
	trikeControl.player = rider
	trikeControl.throttle = 0
	trikeControl.steer = 0
	trikeControl.updatedAt = 0
	if rider then
		unparkTrike()
	else
		trikeEmptySince = os.clock()
	end
end)

rideablesEvent.OnServerEvent:Connect(function(player, action, valueA, valueB)
	if typeof(action) ~= "string" then
		return
	end

	if action == "SwingPump" then
		if playerFromSeat(swingSeat) ~= player or not passesRateLimit(player, action, SWING_PUMP_INTERVAL) then
			return
		end
		if not finiteNumber(valueA) then
			return
		end
		swingInput = math.clamp(valueA, -1, 1)
		swingPumpUntil = os.clock() + SWING_PUMP_DURATION
	elseif action == "ResetSwing" then
		if playerFromSeat(swingSeat) == player and passesRateLimit(player, action, 1.5) then
			resetSwing(true)
		end
	elseif action == "TrikeControl" then
		if playerFromSeat(trikeSeat) ~= player or not passesRateLimit(player, action, TRIKE_INPUT_INTERVAL) then
			return
		end
		if not finiteNumber(valueA) or not finiteNumber(valueB) then
			return
		end
		trikeControl.player = player
		trikeControl.throttle = math.clamp(valueA, -1, 1)
		trikeControl.steer = math.clamp(valueB, -1, 1)
		trikeControl.updatedAt = os.clock()
	elseif action == "ResetTrike" then
		if playerFromSeat(trikeSeat) == player and passesRateLimit(player, action, 1.5) then
			resetTrike(true)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	rateLimits[player] = nil
	if trikeControl.player == player then
		trikeControl.player = nil
		trikeControl.throttle = 0
		trikeControl.steer = 0
	end
end)

local function updateSwing(now)
	local rider = playerFromSeat(swingSeat)
	local velocity = swingSeat.AssemblyLinearVelocity
	local mass = math.max(swingSeat.AssemblyMass, 1)
	local force = Vector3.zero
	if rider and now <= swingPumpUntil and math.abs(swingInput) > 0.01 then
		local direction = horizontalUnit(swingSeat.CFrame.LookVector)
		force = direction * swingInput * mass * 30
	elseif not rider then
		force = -horizontal(velocity) * mass * 0.65
	end
	swingForce.Force = force

	if velocity.Magnitude > SWING_MAX_SPEED then
		swingSeat.AssemblyLinearVelocity = velocity.Unit * SWING_MAX_SPEED
	end
	local angular = swingSeat.AssemblyAngularVelocity
	if angular.Magnitude > 10 then
		swingSeat.AssemblyAngularVelocity = angular.Unit * 10
	end

	local badPosition = (swingSeat.Position - swingHome.Position).Magnitude > SWING_MAX_DISTANCE
		or swingSeat.Position.Y < -2
		or swingSeat.Position.Y > swingHome.Position.Y + 15
	if badPosition then
		resetSwing(true)
		return
	end

	if not rider and swingSeat.CFrame.UpVector.Y < -0.1 then
		swingUpsideDownSince = swingUpsideDownSince or now
		if now - swingUpsideDownSince > 3 then
			resetSwing(false)
			return
		end
	else
		swingUpsideDownSince = nil
	end

	if not rider and now - swingEmptySince > SWING_IDLE_RESET_SECONDS then
		local displaced = (swingSeat.Position - swingHome.Position).Magnitude > 0.8
		if displaced or velocity.Magnitude > 0.35 then
			resetSwing(false)
		end
	end
end

local function updateTrike(now, deltaTime)
	local rider = playerFromSeat(trikeSeat)
	-- External scripts or an exceptional physics handoff can still tip the model.
	-- Do not silently upright it; preserve the visible fallen state briefly, then
	-- perform the same safe recovery available from the reset control.
	if not trikeParked and chassis.CFrame.UpVector.Y < 0.3 then
		trikeTippedSince = trikeTippedSince or now
		if now - trikeTippedSince > 1.4 then
			resetTrike(true)
		end
		return
	end
	trikeTippedSince = nil

	if rider and (trikeControl.player ~= rider or now - trikeControl.updatedAt > TRIKE_INPUT_TIMEOUT) then
		trikeControl.player = rider
		trikeControl.throttle = 0
		trikeControl.steer = 0
	end

	local desiredSpeed = 0
	local throttle = 0
	local steer = 0
	if rider then
		unparkTrike()
		throttle = trikeControl.throttle
		steer = trikeControl.steer
		desiredSpeed = if throttle >= 0
			then throttle * TRIKE_FORWARD_SPEED
			else throttle * TRIKE_REVERSE_SPEED
	else
		trikeControl.throttle = 0
		trikeControl.steer = 0
	end

	local rate = TRIKE_ACCELERATION
	if math.abs(throttle) < 0.01 then
		rate = rider and TRIKE_COAST_DECELERATION or TRIKE_BRAKING
	elseif trikeSpeed * desiredSpeed < 0 then
		rate = TRIKE_BRAKING
	end
	trikeSpeed = moveToward(trikeSpeed, desiredSpeed, rate * deltaTime)
	trikeSpeed = math.clamp(trikeSpeed, -TRIKE_MAX_SPEED, TRIKE_MAX_SPEED)

	-- Preserve bicycle-like reverse steering while allowing prompt response from
	-- rest. All steering and displacement are computed authoritatively here.
	local steeringSpeed = math.max(math.abs(trikeSpeed), math.abs(desiredSpeed) * 0.22)
	local steeringFactor = math.clamp(steeringSpeed / 10, 0, 1)
	local steeringDirection = if math.abs(trikeSpeed) > 0.25 then trikeSpeed else desiredSpeed
	local reverseFactor = if steeringDirection < -0.1 then -1 else 1
	trikeYaw -= steer * TRIKE_STEER_RATE * deltaTime * steeringFactor * reverseFactor

	refreshTrikeSpatialFilters()
	local movementSucceeded = true
	local blockingObstacle = nil
	if not trikeParked and math.abs(trikeSpeed) > 0.01 then
		local distance = trikeSpeed * deltaTime
		local substeps = math.clamp(math.ceil(math.abs(distance) / TRIKE_MAX_SUBSTEP_DISTANCE), 1, 8)
		local substepDistance = distance / substeps
		for _ = 1, substeps do
			local currentPosition = chassis.Position
			local forward = CFrame.Angles(0, trikeYaw, 0).LookVector
			local candidate = currentPosition + forward * substepDistance
			local targetPose, reason, supportParts, groundObstacle = groundPoseAt(
				candidate,
				trikeYaw,
				currentPosition.Y
			)
			if targetPose then
				local obstacle = firstObstacleBetween(trike:GetPivot(), targetPose, supportParts)
				if obstacle then
					-- Never advance into the obstacle. Stop immediately so continuous
					-- throttle cannot accumulate speed while pressed against a wall;
					-- reverse or steering input can still move away on the next frame.
					blockingObstacle = obstacle
					trikeSpeed = 0
					trikeLastGroundedAt = now
					break
				else
					trike:PivotTo(targetPose)
					trikeLastGroundedAt = now
				end
			elseif reason == "Obstacle" and groundObstacle then
				blockingObstacle = groundObstacle
				trikeSpeed = 0
				trikeLastGroundedAt = now
				break
			else
				movementSucceeded = false
				trikeSpeed = moveToward(trikeSpeed, 0, TRIKE_BRAKING * deltaTime)
				-- A high wall/ledge is an obstacle, not a lost vehicle. Only an actual
				-- absence of supporting ground is eligible for automatic recovery.
				if reason == "UnsafeStep" or reason == "UnsafeSlope" then
					trikeLastGroundedAt = now
				end
				break
			end
		end
	elseif not trikeParked then
		local currentPosition = chassis.Position
		local targetPose, reason, supportParts, groundObstacle = groundPoseAt(
			currentPosition,
			trikeYaw,
			currentPosition.Y
		)
		if targetPose then
			local obstacle = firstObstacleBetween(trike:GetPivot(), targetPose, supportParts)
			if obstacle then
				blockingObstacle = obstacle
				trikeSpeed = 0
				trikeLastGroundedAt = now
			else
				trike:PivotTo(targetPose)
				trikeLastGroundedAt = now
			end
		elseif reason == "Obstacle" and groundObstacle then
			blockingObstacle = groundObstacle
			trikeSpeed = 0
			trikeLastGroundedAt = now
		elseif reason == "UnsafeStep" or reason == "UnsafeSlope" then
			trikeLastGroundedAt = now
		else
			movementSucceeded = false
		end
	end
	setTrikeObstacleState(blockingObstacle)

	setWheelSpeed(trikeSpeed)

	if not rider and not trikeParked and now - trikeEmptySince > TRIKE_PARK_DELAY
		and math.abs(trikeSpeed) < 0.2
	then
		trikeSpeed = 0
		setWheelSpeed(0)
		trikeParked = true
	end

	local position = chassis.Position
	local numericallyLost = not finiteNumber(position.X)
		or not finiteNumber(position.Y)
		or not finiteNumber(position.Z)
		or math.abs(position.Y - trikeHome.Position.Y) > 250
	if numericallyLost or (not movementSucceeded and now - trikeLastGroundedAt > TRIKE_GROUND_LOST_SECONDS) then
		resetTrike(true)
		return
	end

end

resetSwing(false)
resetTrike(false)

RunService.Heartbeat:Connect(function(deltaTime)
	local now = os.clock()
	updateSwing(now)
	updateTrike(now, math.min(deltaTime, 0.1))
end)

print("[CooperYardRideables] Server controller ready")
