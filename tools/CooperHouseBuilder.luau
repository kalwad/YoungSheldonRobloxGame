-- Young Sheldon / Cooper family house environment generator.
-- Run in Roblox Studio edit context through robloxstudio-mcp execute_luau.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StarterPlayer = game:GetService("StarterPlayer")

local ENVIRONMENT_NAME = "CooperHouseEnvironment"
local FLOOR_Y = 1.25
local WALL_TOP = 11.25
local PRIVATE_WING_Z_SHIFT = 4.5
local PRIVATE_ROOM_EXTRA_DEPTH = 4.0
local HOUSE_SCALE = 1.08
local RIGHT_EXTERIOR_X = 29
local RIGHT_BAY_FRONT_Z = -17
local PATIO_OPENING_FRONT_Z = 7.2
local PATIO_OPENING_BACK_Z = 13.5
local PATIO_HINGE_Z = 13.1
local PATIO_DOOR_WIDTH = 5.5

local colors = {
	grass = Color3.fromRGB(86, 122, 65),
	grassLight = Color3.fromRGB(109, 139, 77),
	asphalt = Color3.fromRGB(56, 58, 61),
	concrete = Color3.fromRGB(174, 171, 159),
	curb = Color3.fromRGB(199, 197, 184),
	siding = Color3.fromRGB(115, 133, 138),
	sidingDark = Color3.fromRGB(91, 112, 118),
	ivory = Color3.fromRGB(232, 229, 218),
	cream = Color3.fromRGB(217, 212, 196),
	porchWhite = Color3.fromRGB(239, 237, 225),
	brick = Color3.fromRGB(122, 52, 41),
	roof = Color3.fromRGB(166, 111, 93),
	roofDark = Color3.fromRGB(126, 77, 66),
	glass = Color3.fromRGB(168, 194, 204),
	curtain = Color3.fromRGB(226, 215, 191),
	wood = Color3.fromRGB(107, 73, 51),
	darkWood = Color3.fromRGB(70, 48, 35),
	panel = Color3.fromRGB(138, 98, 63),
	rust = Color3.fromRGB(139, 65, 53),
	olive = Color3.fromRGB(109, 112, 69),
	kitchen = Color3.fromRGB(180, 154, 76),
	diningBlue = Color3.fromRGB(170, 184, 182),
	bathOxblood = Color3.fromRGB(74, 32, 37),
	dustyRose = Color3.fromRGB(141, 95, 103),
	black = Color3.fromRGB(28, 29, 27),
	darkGreen = Color3.fromRGB(45, 68, 46),
	leaf = Color3.fromRGB(59, 91, 51),
	leafLight = Color3.fromRGB(84, 116, 61),
	cedar = Color3.fromRGB(67, 93, 56),
	trunk = Color3.fromRGB(83, 61, 42),
	terraCotta = Color3.fromRGB(159, 82, 56),
	white = Color3.fromRGB(244, 241, 230),
	yellow = Color3.fromRGB(228, 180, 49),
	red = Color3.fromRGB(181, 43, 35),
	blue = Color3.fromRGB(63, 91, 129),
	tan = Color3.fromRGB(177, 150, 111),
	carBeige = Color3.fromRGB(178, 166, 138),
	metal = Color3.fromRGB(118, 122, 117),
	water = Color3.fromRGB(114, 170, 188),
}

local previous = Workspace:FindFirstChild(ENVIRONMENT_NAME)
local existingSpawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)

local root = Instance.new("Model")
root.Name = ENVIRONMENT_NAME .. "_Staging"
root:SetAttribute("Inspiration", "Young Sheldon Cooper family home, coherent Season 1-2 / 1989-1990 look")
root:SetAttribute("ExteriorReference", "1949 Valley Village ranch used as fictional Medford, Texas home")
root:SetAttribute("InteriorReference", "Soundstage set: formal parlor, dining room, kitchen, den and early shared twins bedroom")
root:SetAttribute("BuildVersion", "3.0-expanded-early-series-set")

local function container(className, name, parent)
	local object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	return object
end

local site = container("Model", "SiteAndStreet", root)
local house = container("Model", "CooperHouse", root)
local structure = container("Model", "Structure", house)
local exterior = container("Model", "ExteriorDetails", house)
local interior = container("Model", "InteriorRooms", house)
local furniture = container("Model", "FurnitureAndProps", house)
local landscaping = container("Model", "Landscaping", root)
local garage = container("Model", "DetachedGarage", root)
local vehicles = container("Model", "PeriodVehicles", root)
local neighborhood = container("Model", "NeighborhoodBackdrop", root)

local function makePart(parent, name, size, cframe, color, material, transparency, canCollide, shape)
	local part
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
	end
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = (transparency or 0) < 0.65
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function box(parent, name, position, size, color, material, transparency, canCollide, rotation, shape)
	local rot = rotation or Vector3.zero
	return makePart(
		parent,
		name,
		size,
		CFrame.new(position) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)),
		color,
		material,
		transparency,
		canCollide,
		shape
	)
end

local function localBox(parent, name, base, offset, size, color, material, transparency, canCollide, rotation, shape)
	local rot = rotation or Vector3.zero
	return makePart(
		parent,
		name,
		size,
		base * CFrame.new(offset) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)),
		color,
		material,
		transparency,
		canCollide,
		shape
	)
end

local function beam(parent, name, a, b, thickness, color, material, transparency, canCollide)
	local midpoint = (a + b) / 2
	local length = (a - b).Magnitude
	return makePart(
		parent,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt(midpoint, b),
		color,
		material,
		transparency,
		canCollide,
		nil
	)
end

local function cylinderBetween(parent, name, a, b, diameter, color, material, transparency, canCollide)
	local midpoint = (a + b) / 2
	local length = (a - b).Magnitude
	return makePart(
		parent,
		name,
		Vector3.new(length, diameter, diameter),
		CFrame.lookAt(midpoint, b) * CFrame.Angles(0, math.rad(90), 0),
		color,
		material,
		transparency,
		canCollide,
		"Cylinder"
	)
end

-- Keep both exterior swing doors on the same relocation- and obstruction-safe
-- runtime controller.  The builder writes this source after the legacy inline
-- source below so rebuilding the house cannot restore the older unsafe door
-- behavior.
local SWING_DOOR_CONTROLLER_TEMPLATE = [=[
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local door = script.Parent
local prompt = door.Parent:WaitForChild("__PROMPT_ANCHOR__"):WaitForChild("DoorPrompt")
local closedPivot = door:GetAttribute("ClosedPivot")
local openPivot = door:GetAttribute("OpenPivot")
local isOpen = door:GetAttribute("IsOpen") == true
local currentPivot = door:GetPivot()
local expectedPivot = isOpen and openPivot or closedPivot
local swing = math.rad(__SWING_DEGREES__)

if typeof(closedPivot) ~= "CFrame" or typeof(openPivot) ~= "CFrame" then
	if isOpen then
		openPivot = currentPivot
		closedPivot = currentPivot * CFrame.Angles(0, -swing, 0)
	else
		closedPivot = currentPivot
		openPivot = currentPivot * CFrame.Angles(0, swing, 0)
	end
elseif typeof(expectedPivot) ~= "CFrame" or (expectedPivot.Position - currentPivot.Position).Magnitude > 2 then
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
prompt.ActionText = isOpen and "Close Door" or "Open Door"

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.FilterDescendantsInstances = { door }
local exterior = door.Parent
local house = exterior.Parent
local structure = house and house:FindFirstChild("Structure")
local rooms = house and house:FindFirstChild("InteriorRooms")
local colliders = {}
for _, descendant in ipairs(door:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant.CanCollide then
		table.insert(colliders, descendant)
	end
end

local function isDoorObstruction(part)
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
	if not part.CanCollide then
		return false
	end
	return not ((structure and part:IsDescendantOf(structure))
		or (rooms and part:IsDescendantOf(rooms))
		or (exterior and part:IsDescendantOf(exterior)))
end

local function swingPathObstructed()
	for _, collider in ipairs(colliders) do
		local querySize = Vector3.new(
			math.max(0.05, collider.Size.X - 0.08),
			math.max(0.05, collider.Size.Y - 0.08),
			math.max(0.05, collider.Size.Z - 0.08)
		)
		for _, hit in ipairs(Workspace:GetPartBoundsInBox(collider.CFrame, querySize, overlapParams)) do
			if isDoorObstruction(hit) then
				return true
			end
		end
	end
	return false
end

local busy = false
local function setDoor(open)
	if busy then
		return
	end
	busy = true
	local driver = Instance.new("CFrameValue")
	driver.Value = door:GetPivot()
	local startingPivot = door:GetPivot()
	local obstructed = false
	local tween
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		door:PivotTo(driver.Value)
		if not obstructed and swingPathObstructed() then
			obstructed = true
			if tween then
				tween:Cancel()
			end
		end
	end)
	local target = open and openPivot or closedPivot
	tween = TweenService:Create(
		driver,
		TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Value = target }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	if obstructed then
		door:PivotTo(startingPivot)
		driver:Destroy()
		prompt.ActionText = "Door blocked"
		task.delay(0.9, function()
			if door.Parent and not busy then
				prompt.ActionText = isOpen and "Close Door" or "Open Door"
			end
		end)
		busy = false
		return
	end
	door:PivotTo(target)
	driver:Destroy()
	isOpen = open
	door:SetAttribute("IsOpen", open)
	prompt.ActionText = open and "Close Door" or "Open Door"
	busy = false
end

prompt.Triggered:Connect(function()
	setDoor(not (door:GetAttribute("IsOpen") == true))
end)
]=]

local function swingDoorControllerSource(promptAnchorName, swingDegrees)
	local source = SWING_DOOR_CONTROLLER_TEMPLATE:gsub("__PROMPT_ANCHOR__", promptAnchorName)
	source = source:gsub("__SWING_DEGREES__", tostring(swingDegrees))
	return source
end

local function wallAlongX(parent, name, x1, x2, z, y1, y2, thickness, color, material)
	return box(
		parent,
		name,
		Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, z),
		Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), thickness),
		color,
		material
	)
end

local function wallAlongZ(parent, name, x, z1, z2, y1, y2, thickness, color, material)
	return box(
		parent,
		name,
		Vector3.new(x, (y1 + y2) / 2, (z1 + z2) / 2),
		Vector3.new(thickness, math.abs(y2 - y1), math.abs(z2 - z1)),
		color,
		material
	)
end

local function addPointLight(parent, name, position, color, brightness, range)
	local bulb = box(parent, name, position, Vector3.new(0.38, 0.38, 0.38), color, Enum.Material.Neon, 0, false, nil, "Ball")
	local light = Instance.new("PointLight")
	light.Name = name .. "Light"
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = bulb
	return bulb
end

local function addWindowFront(parent, name, x, z, width, height, centerY, shutters, diamonds)
	local model = container("Model", name, parent)
	box(model, "Glass", Vector3.new(x, centerY, z - 0.03), Vector3.new(width, height, 0.18), colors.glass, Enum.Material.Glass, 0.38, false)
	box(model, "Curtain", Vector3.new(x, centerY, z + 0.20), Vector3.new(width - 0.45, height - 0.35, 0.08), colors.curtain, Enum.Material.Fabric, 0.24, false)
	box(model, "TopFrame", Vector3.new(x, centerY + height / 2, z - 0.28), Vector3.new(width + 0.45, 0.28, 0.35), colors.ivory, Enum.Material.Wood, 0, false)
	box(model, "BottomFrame", Vector3.new(x, centerY - height / 2, z - 0.28), Vector3.new(width + 0.45, 0.32, 0.38), colors.ivory, Enum.Material.Wood, 0, false)
	box(model, "LeftFrame", Vector3.new(x - width / 2, centerY, z - 0.28), Vector3.new(0.28, height, 0.35), colors.ivory, Enum.Material.Wood, 0, false)
	box(model, "RightFrame", Vector3.new(x + width / 2, centerY, z - 0.28), Vector3.new(0.28, height, 0.35), colors.ivory, Enum.Material.Wood, 0, false)
	box(model, "CenterFrame", Vector3.new(x, centerY, z - 0.31), Vector3.new(0.20, height - 0.15, 0.22), colors.ivory, Enum.Material.Wood, 0, false)
	if diamonds then
		for index = -1, 1 do
			local centerX = x + index * (width / 3)
			local halfWidth = width / 6
			local halfHeight = height / 2 - 0.18
			beam(model, "DiamondA" .. index, Vector3.new(centerX - halfWidth, centerY, z - 0.43), Vector3.new(centerX, centerY + halfHeight, z - 0.43), 0.11, colors.ivory, Enum.Material.Wood, 0, false)
			beam(model, "DiamondB" .. index, Vector3.new(centerX, centerY + halfHeight, z - 0.43), Vector3.new(centerX + halfWidth, centerY, z - 0.43), 0.11, colors.ivory, Enum.Material.Wood, 0, false)
			beam(model, "DiamondC" .. index, Vector3.new(centerX + halfWidth, centerY, z - 0.43), Vector3.new(centerX, centerY - halfHeight, z - 0.43), 0.11, colors.ivory, Enum.Material.Wood, 0, false)
			beam(model, "DiamondD" .. index, Vector3.new(centerX, centerY - halfHeight, z - 0.43), Vector3.new(centerX - halfWidth, centerY, z - 0.43), 0.11, colors.ivory, Enum.Material.Wood, 0, false)
		end
	end
	if shutters then
		for side = -1, 1, 2 do
			local shutterX = x + side * (width / 2 + 0.85)
			box(model, side < 0 and "LeftShutter" or "RightShutter", Vector3.new(shutterX, centerY, z - 0.23), Vector3.new(1.35, height + 0.45, 0.28), colors.ivory, Enum.Material.WoodPlanks, 0, false)
			for row = -2, 2 do
				box(model, "ShutterSlat", Vector3.new(shutterX, centerY + row * 0.82, z - 0.43), Vector3.new(1.05, 0.12, 0.10), colors.cream, Enum.Material.Wood, 0, false)
			end
		end
	end
	return model
end

local function addFacadeWindowBay(parent, name, x1, x2, z, windowX, windowWidth, shutters, diamonds)
	local openingBottom = 4.0
	local openingTop = 8.8
	local leftEdge = windowX - windowWidth / 2
	local rightEdge = windowX + windowWidth / 2
	wallAlongX(parent, name .. "LeftWall", x1, leftEdge, z, FLOOR_Y, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(parent, name .. "RightWall", rightEdge, x2, z, FLOOR_Y, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(parent, name .. "SillWall", leftEdge, rightEdge, z, FLOOR_Y, openingBottom, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(parent, name .. "HeaderWall", leftEdge, rightEdge, z, openingTop, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	addWindowFront(exterior, name .. "Window", windowX, z, windowWidth, openingTop - openingBottom, (openingBottom + openingTop) / 2, shutters, diamonds)
end

local function makeCouch(parent, name, position, width, color, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Seat", base, Vector3.new(0, 1.25, 0), Vector3.new(width, 1.0, 3.0), color, Enum.Material.Fabric)
	localBox(model, "Back", base, Vector3.new(0, 2.9, 1.25), Vector3.new(width, 3.0, 0.65), color, Enum.Material.Fabric)
	localBox(model, "LeftArm", base, Vector3.new(-width / 2 + 0.42, 2.0, 0), Vector3.new(0.85, 2.3, 3.2), color, Enum.Material.Fabric)
	localBox(model, "RightArm", base, Vector3.new(width / 2 - 0.42, 2.0, 0), Vector3.new(0.85, 2.3, 3.2), color, Enum.Material.Fabric)
	for i = -1, 1 do
		localBox(model, "SeatCushion" .. (i + 2), base, Vector3.new(i * width / 3.4, 1.82, -0.25), Vector3.new(width / 3.3 - 0.12, 0.25, 2.25), color, Enum.Material.Fabric, 0, false)
	end
	for _, x in ipairs({-width / 2 + 0.7, width / 2 - 0.7}) do
		for _, z in ipairs({-1.0, 1.0}) do
			localBox(model, "Leg", base, Vector3.new(x, 0.42, z), Vector3.new(0.24, 0.85, 0.24), colors.darkWood, Enum.Material.Wood)
		end
	end
	return model
end

local function makeArmchair(parent, name, position, color, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Seat", base, Vector3.new(0, 1.35, 0), Vector3.new(3.1, 1.0, 3.1), color, Enum.Material.Fabric)
	localBox(model, "Back", base, Vector3.new(0, 3.1, 1.25), Vector3.new(3.1, 3.6, 0.75), color, Enum.Material.Fabric)
	localBox(model, "LeftArm", base, Vector3.new(-1.35, 2.15, 0), Vector3.new(0.55, 2.2, 3.2), color, Enum.Material.Fabric)
	localBox(model, "RightArm", base, Vector3.new(1.35, 2.15, 0), Vector3.new(0.55, 2.2, 3.2), color, Enum.Material.Fabric)
	for _, x in ipairs({-1.15, 1.15}) do
		for _, z in ipairs({-1.08, 1.08}) do
			localBox(model, "TaperedLeg", base, Vector3.new(x, 0.43, z), Vector3.new(0.24, 0.86, 0.24), colors.darkWood, Enum.Material.Wood)
		end
	end
	return model
end

local function makeRockingChair(parent, name, position, color, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Seat", base, Vector3.new(0, 1.58, 0), Vector3.new(2.0, 0.34, 1.8), color, Enum.Material.Wood)
	localBox(model, "SlattedBack", base, Vector3.new(0, 3.0, 0.72), Vector3.new(2.0, 2.75, 0.28), color, Enum.Material.Wood)
	for _, x in ipairs({-0.86, 0.86}) do
		localBox(model, "Arm", base, Vector3.new(x, 2.18, 0), Vector3.new(0.18, 0.18, 1.75), color, Enum.Material.Wood)
		for _, z in ipairs({-0.58, 0.58}) do
			localBox(model, "Leg", base, Vector3.new(x * 0.82, 0.88, z), Vector3.new(0.18, 1.32, 0.18), colors.darkWood, Enum.Material.Wood)
		end
		localBox(model, "RockerRail", base, Vector3.new(x * 0.82, 0.14, 0), Vector3.new(0.20, 0.18, 2.70), colors.darkWood, Enum.Material.Wood)
	end
	return model
end

local function makeTable(parent, name, position, size, color, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Top", base, Vector3.new(0, 2.65, 0), Vector3.new(size.X, 0.35, size.Z), color, Enum.Material.Wood)
	for _, x in ipairs({-size.X / 2 + 0.45, size.X / 2 - 0.45}) do
		for _, z in ipairs({-size.Z / 2 + 0.45, size.Z / 2 - 0.45}) do
			localBox(model, "Leg", base, Vector3.new(x, 1.3, z), Vector3.new(0.32, 2.6, 0.32), colors.darkWood, Enum.Material.Wood)
		end
	end
	return model
end

local function makeLowTable(parent, name, position, size, color, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Top", base, Vector3.new(0, 1.45, 0), Vector3.new(size.X, 0.28, size.Z), color, Enum.Material.Wood)
	for _, x in ipairs({-size.X / 2 + 0.38, size.X / 2 - 0.38}) do
		for _, z in ipairs({-size.Z / 2 + 0.38, size.Z / 2 - 0.38}) do
			localBox(model, "Leg", base, Vector3.new(x, 0.72, z), Vector3.new(0.26, 1.45, 0.26), colors.darkWood, Enum.Material.Wood)
		end
	end
	return model
end

local function makeDiningChair(parent, name, position, color, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Seat", base, Vector3.new(0, 1.65, 0), Vector3.new(2.0, 0.25, 2.0), color, Enum.Material.Wood, 0, false)
	localBox(model, "BackTop", base, Vector3.new(0, 3.6, 0.82), Vector3.new(2.0, 0.28, 0.28), color, Enum.Material.Wood, 0, false)
	for _, x in ipairs({-0.8, 0.8}) do
		for _, z in ipairs({-0.75, 0.75}) do
			localBox(model, "Leg", base, Vector3.new(x, 0.78, z), Vector3.new(0.22, 1.55, 0.22), color, Enum.Material.Wood, 0, false)
		end
		localBox(model, "BackPost", base, Vector3.new(x, 2.7, 0.82), Vector3.new(0.22, 2.1, 0.22), color, Enum.Material.Wood, 0, false)
	end
	for x = -0.45, 0.45, 0.45 do
		localBox(model, "BackSlat", base, Vector3.new(x, 2.9, 0.82), Vector3.new(0.12, 1.55, 0.12), colors.tan, Enum.Material.Wood, 0, false)
	end
	return model
end

local function makeBed(parent, name, position, width, length, frameColor, blanketColor, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Frame", base, Vector3.new(0, 0.85, 0), Vector3.new(width + 0.35, 0.55, length + 0.35), frameColor, Enum.Material.Wood)
	localBox(model, "Mattress", base, Vector3.new(0, 1.25, 0), Vector3.new(width, 0.55, length), colors.ivory, Enum.Material.Fabric)
	localBox(model, "Blanket", base, Vector3.new(0, 1.62, 0.55), Vector3.new(width - 0.15, 0.22, length - 1.6), blanketColor, Enum.Material.Fabric, 0, false)
	localBox(model, "Pillow", base, Vector3.new(0, 1.78, -length / 2 + 0.9), Vector3.new(width - 0.7, 0.35, 1.2), colors.cream, Enum.Material.Fabric, 0, false)
	localBox(model, "Headboard", base, Vector3.new(0, 2.45, -length / 2), Vector3.new(width + 0.4, 2.4, 0.35), frameColor, Enum.Material.Wood)
	return model
end

local function makeLamp(parent, name, position, shadeColor)
	local model = container("Model", name, parent)
	box(model, "Base", position + Vector3.new(0, 0.25, 0), Vector3.new(0.5, 0.9, 0.9), colors.darkWood, Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	box(model, "Stem", position + Vector3.new(0, 2.5, 0), Vector3.new(4.5, 0.18, 0.18), colors.metal, Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	box(model, "Shade", position + Vector3.new(0, 4.45, 0), Vector3.new(1.6, 2.0, 2.0), shadeColor, Enum.Material.Fabric, 0.12, false, Vector3.new(0, 0, 90), "Cylinder")
	addPointLight(model, "WarmBulb", position + Vector3.new(0, 4.1, 0), Color3.fromRGB(255, 202, 132), 1.2, 12)
	return model
end

local function addSurfaceText(part, name, face, text, textColor, backgroundColor, textSize, font)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 55
	gui.LightInfluence = 0.65
	gui.Brightness = 1.1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = backgroundColor or Color3.fromRGB(238, 233, 215)
	label.BackgroundTransparency = backgroundColor and 0 or 1
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = textColor or colors.black
	label.TextScaled = textSize == nil
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.Font = font or Enum.Font.Garamond
	label.Parent = gui
	return gui
end

local function addWallpaperPattern(part, name, face, motif, motifColor, columns, rows, rotationStep)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.LightInfluence = 1
	gui.Brightness = 0.92
	gui.Parent = part
	for row = 1, rows do
		for column = 1, columns do
			local label = Instance.new("TextLabel")
			label.Name = string.format("Motif_%02d_%02d", row, column)
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1 / columns, 1 / rows)
			label.Position = UDim2.fromScale((column - 1) / columns, (row - 1) / rows)
			label.Text = motif
			label.TextColor3 = motifColor
			label.TextTransparency = 0.16
			label.TextScaled = true
			label.Font = Enum.Font.Garamond
			label.Rotation = ((row + column) % 2 == 0) and (rotationStep or 0) or -(rotationStep or 0)
			label.Parent = gui
		end
	end
	return gui
end

local function addDiamondFruitWallpaper(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GreenDiamondFruitWallpaper"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 34
	gui.LightInfluence = 1
	gui.Parent = part
	for row = 1, 5 do
		for column = 1, 8 do
			local tile = Instance.new("Frame")
			tile.Name = string.format("Diamond_%02d_%02d", row, column)
			tile.AnchorPoint = Vector2.new(0.5, 0.5)
			tile.Size = UDim2.fromScale(0.085, 0.135)
			tile.Position = UDim2.fromScale((column - 0.5 + (row % 2) * 0.5) / 8.5, (row - 0.5) / 5)
			tile.BackgroundColor3 = Color3.fromRGB(211, 214, 176)
			tile.BackgroundTransparency = 0.08
			tile.BorderSizePixel = 0
			tile.Rotation = 45
			tile.Parent = gui
			local fruit = Instance.new("TextLabel")
			fruit.Name = "FruitBouquet"
			fruit.AnchorPoint = Vector2.new(0.5, 0.5)
			fruit.Size = UDim2.fromScale(1.22, 1.22)
			fruit.Position = UDim2.fromScale(0.5, 0.5)
			fruit.BackgroundTransparency = 1
			fruit.Rotation = -45
			fruit.Text = (row + column) % 2 == 0 and "❀" or "❦"
			fruit.TextColor3 = (row + column) % 3 == 0 and Color3.fromRGB(137, 69, 50) or Color3.fromRGB(85, 103, 63)
			fruit.TextScaled = true
			fruit.Font = Enum.Font.Garamond
			fruit.Parent = tile
		end
	end
	return gui
end

local function addTexture(part, name, face, assetId, studsPerTileU, studsPerTileV, transparency)
	local texture = Instance.new("Texture")
	texture.Name = name
	texture.Face = face
	texture.Texture = "rbxassetid://" .. tostring(assetId)
	texture.StudsPerTileU = studsPerTileU or 6
	texture.StudsPerTileV = studsPerTileV or 6
	texture.Transparency = transparency or 0
	texture.Color3 = Color3.fromRGB(255, 255, 255)
	texture.Parent = part
	return texture
end

local function makePlaidCouch(parent, name, position, width, color, yaw)
	local model = makeCouch(parent, name, position, width, color, yaw)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	for _, upholsteredPart in ipairs(model:GetChildren()) do
		if upholsteredPart:IsA("BasePart") and upholsteredPart.Material == Enum.Material.Fabric then
			for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
				addTexture(upholsteredPart, "VettedRustPlaid", face, 30468639, 3.5, 3.5, 0.16)
			end
		end
	end
	for index = -3, 3 do
		local stripeColor = index % 2 == 0 and Color3.fromRGB(202, 145, 101) or Color3.fromRGB(92, 45, 39)
		localBox(model, "PlaidVertical" .. index, base, Vector3.new(index * width / 8, 2.95, 0.88), Vector3.new(0.10, 2.55, 0.05), stripeColor, Enum.Material.Fabric, 0, false)
	end
	for index = -2, 2 do
		localBox(model, "PlaidHorizontal" .. index, base, Vector3.new(0, 2.95 + index * 0.52, 0.88), Vector3.new(width - 0.85, 0.09, 0.05), Color3.fromRGB(219, 178, 119), Enum.Material.Fabric, 0, false)
	end
	return model
end

local function makeCurtainSet(parent, name, position, width, height, color, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Rod", base, Vector3.new(0, height / 2 + 0.3, 0), Vector3.new(width + 0.8, 0.14, 0.14), colors.darkWood, Enum.Material.Metal, 0, false)
	for side = -1, 1, 2 do
		localBox(model, side < 0 and "LeftDrape" or "RightDrape", base, Vector3.new(side * (width / 2 - 0.55), 0, 0.05), Vector3.new(1.05, height, 0.16), color, Enum.Material.Fabric, 0.04, false)
		for fold = -1, 1 do
			localBox(model, "Fold", base, Vector3.new(side * (width / 2 - 0.55) + fold * 0.22, 0, -0.08), Vector3.new(0.08, height - 0.15, 0.08), Color3.fromRGB(math.max(color.R * 255 - 22, 0), math.max(color.G * 255 - 22, 0), math.max(color.B * 255 - 22, 0)), Enum.Material.Fabric, 0, false)
		end
	end
	return model
end

local function makeInteriorWindow(parent, name, position, width, height, yaw, curtainColor)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	localBox(model, "Glass", base, Vector3.zero, Vector3.new(width, height, 0.12), Color3.fromRGB(174, 200, 207), Enum.Material.Glass, 0.24, false)
	localBox(model, "TopTrim", base, Vector3.new(0, height / 2, -0.08), Vector3.new(width + 0.45, 0.25, 0.24), colors.ivory, Enum.Material.Wood, 0, false)
	localBox(model, "BottomTrim", base, Vector3.new(0, -height / 2, -0.08), Vector3.new(width + 0.45, 0.28, 0.26), colors.ivory, Enum.Material.Wood, 0, false)
	for side = -1, 1, 2 do
		localBox(model, "SideTrim", base, Vector3.new(side * width / 2, 0, -0.08), Vector3.new(0.24, height, 0.24), colors.ivory, Enum.Material.Wood, 0, false)
	end
	localBox(model, "CenterMullion", base, Vector3.new(0, 0, -0.08), Vector3.new(0.14, height - 0.2, 0.16), colors.ivory, Enum.Material.Wood, 0, false)
	makeCurtainSet(model, "Curtains", position + Vector3.new(0, 0, -0.18), width + 0.6, height + 0.6, curtainColor or colors.curtain, yaw)
	return model
end

local function makeFramedArt(parent, name, position, size, frameColor, printColor, text, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local frame = localBox(model, "Frame", base, Vector3.zero, Vector3.new(size.X + 0.32, size.Y + 0.32, 0.16), frameColor, Enum.Material.Wood, 0, false)
	local print = localBox(model, "Print", base, Vector3.new(0, 0, -0.11), Vector3.new(size.X, size.Y, 0.06), printColor, Enum.Material.SmoothPlastic, 0, false)
	if text then
		addSurfaceText(print, "Caption", Enum.NormalId.Front, text, colors.black, nil, nil, Enum.Font.Garamond)
	end
	return model
end

local function makeDish(parent, name, position, diameter, color)
	return box(parent, name, position, Vector3.new(0.10, diameter, diameter), color, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 90), "Cylinder")
end

local function makeMug(parent, name, position, color)
	local model = container("Model", name, parent)
	box(model, "Cup", position, Vector3.new(0.72, 0.62, 0.62), color, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	box(model, "Coffee", position + Vector3.new(0, 0.37, 0), Vector3.new(0.06, 0.48, 0.48), Color3.fromRGB(75, 44, 25), Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	return model
end

local function makeBooks(parent, name, basePosition, count, direction, palette)
	local model = container("Model", name, parent)
	for index = 1, count do
		local color = palette[((index - 1) % #palette) + 1]
		local offset = direction * ((index - 1) * 0.34)
		box(model, "Book" .. index, basePosition + offset, Vector3.new(0.28, 1.15 + (index % 3) * 0.18, 0.92), color, Enum.Material.SmoothPlastic, 0, false)
	end
	return model
end

local function makeTree(parent, name, position, height, canopyRadius, canopyColor, cedarStyle)
	local model = container("Model", name, parent)
	box(model, "Trunk", position + Vector3.new(0, height / 2, 0), Vector3.new(height, 2.6, 2.6), colors.trunk, Enum.Material.Wood, 0, true, Vector3.new(0, 0, 90), "Cylinder")
	local branches = cedarStyle and {
		Vector3.new(-11, height * 0.68, -1), Vector3.new(12, height * 0.74, 1), Vector3.new(-8, height * 0.83, 4), Vector3.new(7, height * 0.9, -4)
	} or {
		Vector3.new(-7, height * 0.66, 1), Vector3.new(7, height * 0.72, -1), Vector3.new(-4, height * 0.83, -4), Vector3.new(4, height * 0.88, 4)
	}
	for index, offset in ipairs(branches) do
		cylinderBetween(model, "Branch" .. index, position + Vector3.new(0, height * 0.55, 0), position + offset, cedarStyle and 1.15 or 0.85, colors.trunk, Enum.Material.Wood, 0, true)
	end
	local rng = Random.new(cedarStyle and 1989 or 1991)
	local clusterCount = cedarStyle and 34 or 25
	for index = 1, clusterCount do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(canopyRadius * 0.20, canopyRadius)
		local y = rng:NextNumber(height * 0.52, height * 1.02)
		local flatten = cedarStyle and 0.62 or 0.82
		local p = position + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius * flatten)
		local size = rng:NextNumber(canopyRadius * 0.42, canopyRadius * 0.72)
		box(model, "LeafCluster" .. index, p, Vector3.new(size * (cedarStyle and 1.6 or 1.15), size, size), index % 3 == 0 and colors.leafLight or canopyColor, Enum.Material.Grass, 0, false, nil, "Ball")
	end
	return model
end

local function makeShrub(parent, name, position, size, color)
	local model = container("Model", name, parent)
	for index = 1, 3 do
		local offset = Vector3.new((index - 2) * size * 0.28, (index % 2) * size * 0.08, (index == 2 and 0.25 or -0.1) * size)
		box(model, "LeafMass", position + offset, Vector3.new(size, size * 0.72, size * 0.78), color, Enum.Material.Grass, 0, false, nil, "Ball")
	end
	return model
end

local function makePicketFence(parent, name, x, z1, z2)
	local model = container("Model", name, parent)
	for z = z1, z2, 2.25 do
		box(model, "Picket", Vector3.new(x, 2.1, z), Vector3.new(0.25, 4.2, 0.38), colors.ivory, Enum.Material.Wood)
		box(model, "PicketTip", Vector3.new(x, 4.3, z), Vector3.new(0.28, 0.65, 0.42), colors.ivory, Enum.Material.Wood, 0, true, Vector3.new(0, 0, 45), "Wedge")
	end
	box(model, "TopRail", Vector3.new(x, 3.0, (z1 + z2) / 2), Vector3.new(0.35, 0.3, math.abs(z2 - z1)), colors.ivory, Enum.Material.Wood)
	box(model, "BottomRail", Vector3.new(x, 1.45, (z1 + z2) / 2), Vector3.new(0.35, 0.3, math.abs(z2 - z1)), colors.ivory, Enum.Material.Wood)
	return model
end

local function makeSimpleHouse(parent, name, center, width, depth, wallColor, roofColor, twoStory, yaw)
	local model = container("Model", name, parent)
	local base = CFrame.new(center) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local height = twoStory and 17 or 9
	localBox(model, "Foundation", base, Vector3.new(0, 0.65, 0), Vector3.new(width, 1.3, depth), colors.cream, Enum.Material.Concrete)
	localBox(model, "HouseBlock", base, Vector3.new(0, 1.3 + height / 2, 0), Vector3.new(width, height, depth), wallColor, Enum.Material.WoodPlanks)
	local roofY = 1.3 + height + 2.6
	localBox(model, "RoofFront", base, Vector3.new(0, roofY, -depth * 0.23), Vector3.new(width + 3, 0.8, depth * 0.58), roofColor, Enum.Material.RoofShingles, 0, true, Vector3.new(-15, 0, 0))
	localBox(model, "RoofBack", base, Vector3.new(0, roofY, depth * 0.23), Vector3.new(width + 3, 0.8, depth * 0.58), roofColor, Enum.Material.RoofShingles, 0, true, Vector3.new(15, 0, 0))
	for x = -width * 0.32, width * 0.32, width * 0.32 do
		localBox(model, "Window", base, Vector3.new(x, 1.3 + height * 0.55, -depth / 2 - 0.05), Vector3.new(3.6, 3.2, 0.18), colors.glass, Enum.Material.Glass, 0.30, false)
		localBox(model, "WindowFrame", base, Vector3.new(x, 1.3 + height * 0.55, -depth / 2 - 0.18), Vector3.new(4.1, 3.7, 0.12), colors.ivory, Enum.Material.Wood, 0.42, false)
	end
	return model
end

local ok, result = pcall(function()
	-- Site, corner streets, curbs, lot, side driveway, and curved walk.
	box(site, "NeighborhoodGround", Vector3.new(10, 0.02, 10), Vector3.new(320, 0.35, 270), colors.grass, Enum.Material.Grass)
	box(site, "FrontStreet", Vector3.new(15, 0.28, -61), Vector3.new(220, 0.42, 28), colors.asphalt, Enum.Material.Asphalt)
	box(site, "SideStreet", Vector3.new(-43, 0.29, 10), Vector3.new(20, 0.44, 170), colors.asphalt, Enum.Material.Asphalt)
	box(site, "FrontCurb", Vector3.new(18, 0.55, -47.4), Vector3.new(120, 0.72, 1.2), colors.curb, Enum.Material.Concrete)
	box(site, "SideCurb", Vector3.new(-33.4, 0.55, 18), Vector3.new(1.2, 0.72, 130), colors.curb, Enum.Material.Concrete)
	box(site, "CooperLot", Vector3.new(5, 0.31, 20.5), Vector3.new(76, 0.54, 135), colors.grassLight, Enum.Material.Grass)
	box(site, "SideDriveway", Vector3.new(-29, 0.61, 19), Vector3.new(8.0, 0.36, 132), colors.concrete, Enum.Material.Concrete)
	box(site, "DrivewaySeam", Vector3.new(-29, 0.82, -17), Vector3.new(0.12, 0.04, 58), colors.curb, Enum.Material.Concrete, 0, false)
	local walkPoints = {
		Vector3.new(0, 0.82, -47), Vector3.new(-0.8, 0.84, -40), Vector3.new(-1.6, 0.87, -33),
		Vector3.new(-1.2, 0.92, -26), Vector3.new(-0.4, 1.00, -20), Vector3.new(-0.8, 1.17, -16.4),
		Vector3.new(-1.4, 1.17, -18.6),
	}
	for index = 1, #walkPoints - 1 do
		local a = walkPoints[index]
		local b = walkPoints[index + 1]
		local midpoint = (a + b) / 2
		local length = (a - b).Magnitude
		makePart(site, "CurvedWalk" .. index, Vector3.new(3.4, 0.24, length + 0.35), CFrame.lookAt(midpoint, b), colors.concrete, Enum.Material.Concrete, 0, true)
	end

	-- House foundation, floors, porch, and front steps.
	box(structure, "Foundation", Vector3.new(2, 0.46, 8 + (PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH) / 2), Vector3.new(54, 0.92, 46 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH), colors.cream, Enum.Material.Concrete)
	box(structure, "HouseSubfloor", Vector3.new(2, FLOOR_Y - 0.18, 8 + (PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH) / 2), Vector3.new(53.4, 0.38, 45.4 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH), colors.darkWood, Enum.Material.WoodPlanks)
	box(structure, "ProjectingRightWingFoundation", Vector3.new(19, 0.46, -16), Vector3.new(20, 0.92, 2.2), colors.cream, Enum.Material.Concrete)
	box(structure, "ProjectingRightWingSubfloor", Vector3.new(19, FLOOR_Y - 0.18, -15.85), Vector3.new(19.4, 0.38, 2.5), colors.darkWood, Enum.Material.WoodPlanks)
	box(structure, "PorchDeck", Vector3.new(-1.5, 1.05, -13.0), Vector3.new(21, 0.58, 5.6), colors.concrete, Enum.Material.Concrete)
	box(structure, "PorchStepUpper", Vector3.new(-4.45, 0.70, -16.05), Vector3.new(14.7, 0.42, 1.35), colors.concrete, Enum.Material.Concrete)
	box(structure, "PorchStepLower", Vector3.new(-4.35, 0.40, -17.0), Vector3.new(15.7, 0.36, 1.20), colors.concrete, Enum.Material.Concrete)

	-- Iconic front facade: left bay, recessed white porch wall, and projecting right wing.
	addFacadeWindowBay(structure, "LeftBay", -25, -12, -13.0, -19.2, 4.4, true, false)
	wallAlongX(structure, "PorchLeftWall", -12, -10.5, -10.5, FLOOR_Y, WALL_TOP, 0.72, colors.porchWhite, Enum.Material.WoodPlanks)
	wallAlongX(structure, "PorchDoorHeader", -10.5, -5.5, -10.5, 9.4, WALL_TOP, 0.72, colors.porchWhite, Enum.Material.WoodPlanks)
	wallAlongX(structure, "PorchCenterWall", -5.5, -1.75, -10.5, FLOOR_Y, WALL_TOP, 0.72, colors.porchWhite, Enum.Material.WoodPlanks)
	wallAlongX(structure, "PorchWindowSillWall", -1.75, 8.75, -10.5, FLOOR_Y, 4.0, 0.72, colors.porchWhite, Enum.Material.WoodPlanks)
	wallAlongX(structure, "PorchWindowHeaderWall", -1.75, 8.75, -10.5, 8.8, WALL_TOP, 0.72, colors.porchWhite, Enum.Material.WoodPlanks)
	wallAlongX(structure, "PorchRightWall", 8.75, 9, -10.5, FLOOR_Y, WALL_TOP, 0.72, colors.porchWhite, Enum.Material.WoodPlanks)
	addWindowFront(exterior, "SignatureDiamondPictureWindow", 3.5, -10.5, 10.5, 4.8, 6.4, false, true)
	addFacadeWindowBay(structure, "RightBay", 9, RIGHT_EXTERIOR_X, RIGHT_BAY_FRONT_Z, 20.0, 5.2, false, false)
	wallAlongZ(structure, "LeftPorchReturn", -12, -13.0, -10.5, FLOOR_Y, WALL_TOP, 0.72, colors.siding, Enum.Material.WoodPlanks)
	wallAlongZ(structure, "RightPorchReturn", 9, RIGHT_BAY_FRONT_Z, -10.5, FLOOR_Y, WALL_TOP, 0.72, colors.siding, Enum.Material.WoodPlanks)
	wallAlongZ(structure, "LeftExteriorWall", -25, -13, 31 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH, FLOOR_Y, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	-- Split the east wall around the den's real patio door instead of hiding a false doorway in a bedroom.
	wallAlongZ(structure, "RightExteriorWallFront", RIGHT_EXTERIOR_X, RIGHT_BAY_FRONT_Z, PATIO_OPENING_FRONT_Z, FLOOR_Y, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongZ(structure, "DenPatioDoorHeader", RIGHT_EXTERIOR_X, PATIO_OPENING_FRONT_Z, PATIO_OPENING_BACK_Z, 9.4, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongZ(structure, "RightExteriorWallBack", RIGHT_EXTERIOR_X, PATIO_OPENING_BACK_Z, 31 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH, FLOOR_Y, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(structure, "BackWallLeft", -25, -13.2, 31 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH, FLOOR_Y, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(structure, "BackDoorHeader", -13.2, -9.1, 31 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH, 9.4, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(structure, "BackWallFormerDoorInfill", -13.2, -9.1, 31 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH, FLOOR_Y, 9.4, 0.75, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(structure, "BackWallRight", -9.1, RIGHT_EXTERIOR_X, 31 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH, FLOOR_Y, WALL_TOP, 0.75, colors.siding, Enum.Material.WoodPlanks)

	-- Brick apron and subtle foundation vents.
	box(exterior, "BrickApron", Vector3.new(3.5, 2.55, -10.95), Vector3.new(11.2, 2.55, 0.45), colors.brick, Enum.Material.Brick)
	for _, x in ipairs({-21.5, 15.5, 25.0}) do
		box(exterior, "FoundationVent", Vector3.new(x, 1.15, x < 0 and -13.43 or RIGHT_BAY_FRONT_Z - 0.43), Vector3.new(1.45, 0.55, 0.16), colors.black, Enum.Material.Metal, 0, false)
		for slot = -2, 2 do
			box(exterior, "VentSlot", Vector3.new(x + slot * 0.22, 1.15, x < 0 and -13.54 or RIGHT_BAY_FRONT_Z - 0.54), Vector3.new(0.07, 0.38, 0.04), colors.metal, Enum.Material.Metal, 0, false)
		end
	end

	-- A real, visibly open front door. In play mode the E prompt closes and reopens it.
	local frontDoor = container("Model", "InteractiveFrontDoor", exterior)
	local closedDoorPivot = CFrame.new(-10.28, 5.25, -10.58)
	local openDoorPivot = closedDoorPivot * CFrame.Angles(0, math.rad(-102), 0)
	local hinge = makePart(frontDoor, "HingePivot", Vector3.new(0.20, 8.0, 0.20), openDoorPivot, colors.darkWood, Enum.Material.Metal, 1, false)
	frontDoor.PrimaryPart = hinge
	localBox(frontDoor, "DoorSlab", openDoorPivot, Vector3.new(2.25, 0, 0), Vector3.new(4.45, 7.95, 0.42), Color3.fromRGB(150, 117, 76), Enum.Material.WoodPlanks, 0, true)
	for panelY = -2.15, 2.15, 2.15 do
		localBox(frontDoor, "RaisedPanel", openDoorPivot, Vector3.new(2.25, panelY, -0.24), Vector3.new(3.75, 1.55, 0.10), colors.tan, Enum.Material.Wood, 0, false)
	end
	localBox(frontDoor, "BrassKnobOutside", openDoorPivot, Vector3.new(4.05, -0.05, -0.40), Vector3.new(0.34, 0.56, 0.56), Color3.fromRGB(177, 136, 58), Enum.Material.Metal, 0, false, Vector3.new(0, 90, 0), "Cylinder")
	localBox(frontDoor, "BrassKnobInside", openDoorPivot, Vector3.new(4.05, -0.05, 0.40), Vector3.new(0.34, 0.56, 0.56), Color3.fromRGB(177, 136, 58), Enum.Material.Metal, 0, false, Vector3.new(0, 90, 0), "Cylinder")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.ActionText = "Close Door"
	prompt.ObjectText = "Cooper Front Door"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	-- A fixed prompt anchor prevents the interaction from disappearing after the moving hinge rotates.
	local frontPromptAnchor = makePart(exterior, "FrontDoorPromptAnchor", Vector3.new(0.24, 3.0, 0.24), CFrame.new(-8.03, 5.20, -10.75), colors.ivory, Enum.Material.SmoothPlastic, 1, false)
	prompt.Parent = frontPromptAnchor
	frontDoor:SetAttribute("ClosedPivot", closedDoorPivot)
	frontDoor:SetAttribute("OpenPivot", openDoorPivot)
	frontDoor:SetAttribute("SwingDegrees", -102)
	frontDoor:SetAttribute("IsOpen", true)
	local doorScript = Instance.new("Script")
	doorScript.Name = "FrontDoorController"
	doorScript.Source = [=[
local TweenService = game:GetService("TweenService")
local door = script.Parent
local prompt = door.Parent:WaitForChild("FrontDoorPromptAnchor"):WaitForChild("DoorPrompt")
local closedPivot = door:GetAttribute("ClosedPivot")
local openPivot = door:GetAttribute("OpenPivot")
local isOpen = door:GetAttribute("IsOpen") == true
local currentPivot = door:GetPivot()

-- CFrame attributes do not follow a parent model when the completed house is
-- scaled or translated. Rebase both poses onto the live hinge while preserving
-- the authored swing delta, otherwise the first toggle sends the door back to
-- its pre-transform map coordinates.
local expectedPivot = isOpen and openPivot or closedPivot
if typeof(closedPivot) ~= "CFrame" or typeof(openPivot) ~= "CFrame" then
	local swing = math.rad(tonumber(door:GetAttribute("SwingDegrees")) or -102)
	if isOpen then
		openPivot = currentPivot
		closedPivot = currentPivot * CFrame.Angles(0, -swing, 0)
	else
		closedPivot = currentPivot
		openPivot = currentPivot * CFrame.Angles(0, swing, 0)
	end
elseif typeof(expectedPivot) ~= "CFrame" or (expectedPivot.Position - currentPivot.Position).Magnitude > 2 then
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
prompt.ActionText = isOpen and "Close Door" or "Open Door"
local busy = false

local function setDoor(open)
	if busy then return end
	busy = true
	local driver = Instance.new("CFrameValue")
	driver.Value = door:GetPivot()
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		door:PivotTo(driver.Value)
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Value = open and openPivot or closedPivot,
	})
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	door:PivotTo(open and openPivot or closedPivot)
	driver:Destroy()
	door:SetAttribute("IsOpen", open)
	prompt.ActionText = open and "Close Door" or "Open Door"
	busy = false
end

prompt.Triggered:Connect(function()
	setDoor(not door:GetAttribute("IsOpen"))
end)
]=]
	doorScript.Source = swingDoorControllerSource("FrontDoorPromptAnchor", -102)
	doorScript.Parent = frontDoor
	box(exterior, "FrontThreshold", Vector3.new(-8.03, 1.43, -10.55), Vector3.new(4.9, 0.18, 0.9), Color3.fromRGB(126, 111, 86), Enum.Material.Wood, 0, true)
	box(exterior, "FrontDoormat", Vector3.new(-8.03, 1.40, -12.0), Vector3.new(3.8, 0.10, 1.5), Color3.fromRGB(87, 68, 47), Enum.Material.Fabric, 0, false)

	-- The recurring den exit is a working half-glazed white patio door, not scenery painted over a solid wall.
	local patioDoor = container("Model", "InteractiveDenPatioDoor", exterior)
	local closedPatioPivot = CFrame.new(RIGHT_EXTERIOR_X - 0.42, 5.25, PATIO_HINGE_Z) * CFrame.Angles(0, math.rad(90), 0)
	local openPatioPivot = closedPatioPivot * CFrame.Angles(0, math.rad(-98), 0)
	local patioHinge = makePart(patioDoor, "HingePivot", Vector3.new(0.20, 8.0, 0.20), openPatioPivot, colors.ivory, Enum.Material.Metal, 1, false)
	patioDoor.PrimaryPart = patioHinge
	local doorHalfWidth = PATIO_DOOR_WIDTH / 2
	localBox(patioDoor, "DoorCollisionSlab", openPatioPivot, Vector3.new(doorHalfWidth, 0, 0), Vector3.new(PATIO_DOOR_WIDTH, 7.95, 0.20), colors.ivory, Enum.Material.SmoothPlastic, 1, true)
	localBox(patioDoor, "HingeStile", openPatioPivot, Vector3.new(0.18, 0, 0), Vector3.new(0.36, 7.95, 0.42), colors.ivory, Enum.Material.Wood, 0, true)
	localBox(patioDoor, "LatchStile", openPatioPivot, Vector3.new(PATIO_DOOR_WIDTH - 0.18, 0, 0), Vector3.new(0.36, 7.95, 0.42), colors.ivory, Enum.Material.Wood, 0, true)
	localBox(patioDoor, "TopRail", openPatioPivot, Vector3.new(doorHalfWidth, 3.77, 0), Vector3.new(PATIO_DOOR_WIDTH, 0.42, 0.42), colors.ivory, Enum.Material.Wood, 0, true)
	localBox(patioDoor, "MiddleRail", openPatioPivot, Vector3.new(doorHalfWidth, 0.15, 0), Vector3.new(PATIO_DOOR_WIDTH, 0.42, 0.42), colors.ivory, Enum.Material.Wood, 0, true)
	localBox(patioDoor, "BottomRail", openPatioPivot, Vector3.new(doorHalfWidth, -3.55, 0), Vector3.new(PATIO_DOOR_WIDTH, 0.82, 0.42), colors.ivory, Enum.Material.Wood, 0, true)
	localBox(patioDoor, "UpperGlass", openPatioPivot, Vector3.new(doorHalfWidth, 1.95, 0), Vector3.new(PATIO_DOOR_WIDTH - 0.61, 3.15, 0.16), colors.glass, Enum.Material.Glass, 0.28, false)
	localBox(patioDoor, "LowerFrostedGlass", openPatioPivot, Vector3.new(doorHalfWidth, -1.73, 0), Vector3.new(PATIO_DOOR_WIDTH - 0.61, 3.05, 0.16), Color3.fromRGB(198, 210, 207), Enum.Material.Glass, 0.42, false)
	for slat = -3, 3 do
		localBox(patioDoor, "JalousieSlat" .. slat, openPatioPivot, Vector3.new(doorHalfWidth, -1.72 + slat * 0.38, -0.12), Vector3.new(PATIO_DOOR_WIDTH - 0.67, 0.10, 0.12), colors.ivory, Enum.Material.Metal, 0, false, Vector3.new(10, 0, 0))
	end
	localBox(patioDoor, "BrassKnobOutside", openPatioPivot, Vector3.new(PATIO_DOOR_WIDTH - 0.43, 0.35, -0.40), Vector3.new(0.34, 0.56, 0.56), Color3.fromRGB(177, 136, 58), Enum.Material.Metal, 0, false, Vector3.new(0, 90, 0), "Cylinder")
	localBox(patioDoor, "BrassKnobInside", openPatioPivot, Vector3.new(PATIO_DOOR_WIDTH - 0.43, 0.35, 0.40), Vector3.new(0.34, 0.56, 0.56), Color3.fromRGB(177, 136, 58), Enum.Material.Metal, 0, false, Vector3.new(0, 90, 0), "Cylinder")
	local patioPrompt = Instance.new("ProximityPrompt")
	patioPrompt.Name = "DoorPrompt"
	patioPrompt.ActionText = "Close Door"
	patioPrompt.ObjectText = "Den Patio Door"
	patioPrompt.KeyboardKeyCode = Enum.KeyCode.E
	patioPrompt.HoldDuration = 0
	patioPrompt.MaxActivationDistance = 10
	patioPrompt.RequiresLineOfSight = false
	patioPrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	-- Keep the interaction point fixed in the doorway so it stays available on both sides after the slab swings.
	local patioPromptAnchor = makePart(exterior, "DenPatioPromptAnchor", Vector3.new(0.24, 3.0, 0.24), CFrame.new(RIGHT_EXTERIOR_X - 1.30, 5.20, 10.35), colors.ivory, Enum.Material.SmoothPlastic, 1, false)
	patioPrompt.Parent = patioPromptAnchor
	patioDoor:SetAttribute("ClosedPivot", closedPatioPivot)
	patioDoor:SetAttribute("OpenPivot", openPatioPivot)
	patioDoor:SetAttribute("IsOpen", true)
	local patioDoorScript = Instance.new("Script")
	patioDoorScript.Name = "PatioDoorController"
	patioDoorScript.Source = [=[
local TweenService = game:GetService("TweenService")
local door = script.Parent
local prompt = door.Parent:WaitForChild("DenPatioPromptAnchor"):WaitForChild("DoorPrompt")
	local closedPivot = door:GetAttribute("ClosedPivot")
	local openPivot = door:GetAttribute("OpenPivot")
	local isOpen = door:GetAttribute("IsOpen") == true
	local currentPivot = door:GetPivot()
	local expectedPivot = isOpen and openPivot or closedPivot
	if typeof(closedPivot) ~= "CFrame" or typeof(openPivot) ~= "CFrame" then
		local swing = math.rad(-98)
		if isOpen then
			openPivot = currentPivot
			closedPivot = currentPivot * CFrame.Angles(0, -swing, 0)
		else
			closedPivot = currentPivot
			openPivot = currentPivot * CFrame.Angles(0, swing, 0)
		end
	elseif typeof(expectedPivot) ~= "CFrame" or (expectedPivot.Position - currentPivot.Position).Magnitude > 2 then
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
	prompt.ActionText = isOpen and "Close Door" or "Open Door"
	local busy = false

local function setDoor(open)
	if busy then return end
	busy = true
	local driver = Instance.new("CFrameValue")
	driver.Value = door:GetPivot()
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		door:PivotTo(driver.Value)
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Value = open and openPivot or closedPivot,
	})
		tween:Play()
		tween.Completed:Wait()
		connection:Disconnect()
		door:PivotTo(open and openPivot or closedPivot)
		driver:Destroy()
	door:SetAttribute("IsOpen", open)
	prompt.ActionText = open and "Close Door" or "Open Door"
	busy = false
end

prompt.Triggered:Connect(function()
	setDoor(not door:GetAttribute("IsOpen"))
end)
]=]
	patioDoorScript.Source = swingDoorControllerSource("DenPatioPromptAnchor", -98)
	patioDoorScript.Parent = patioDoor
	box(exterior, "DenPatioThreshold", Vector3.new(RIGHT_EXTERIOR_X - 0.42, 1.43, 10.35), Vector3.new(0.90, 0.18, PATIO_OPENING_BACK_Z - PATIO_OPENING_FRONT_Z), Color3.fromRGB(126, 111, 86), Enum.Material.Wood, 0, true)
	box(exterior, "DenPatioLanding", Vector3.new(RIGHT_EXTERIOR_X + 3.0, 1.05, 10.35), Vector3.new(6.1, 0.58, 7.4), colors.concrete, Enum.Material.Concrete)
	box(exterior, "DenPatioStep", Vector3.new(RIGHT_EXTERIOR_X + 6.35, 0.67, 10.35), Vector3.new(1.1, 0.36, 7.4), colors.concrete, Enum.Material.Concrete)

	-- The former false bedroom back door is infilled above; the private wall now reads continuously.

	-- Main salmon shingle roof, recessed porch roof, fascia, chimney, and porch posts/brackets.
	box(structure, "MainRoofFront", Vector3.new(2, 14.20, -4.4), Vector3.new(60, 0.9, 26.4), colors.roof, Enum.Material.RoofShingles, 0, true, Vector3.new(-14, 0, 0))
	-- The deeper rear slope uses a shallower pitch and raised center so its underside stays above the private-room ceiling.
	box(structure, "MainRoofBack", Vector3.new(2, 14.90, 20.4 + (PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH) / 2), Vector3.new(60, 0.9, 26.4 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH), colors.roof, Enum.Material.RoofShingles, 0, true, Vector3.new(10.5, 0, 0))
	box(structure, "FrontFasciaLeft", Vector3.new(-8, 11.18, -17.2), Vector3.new(40, 0.55, 0.55), colors.ivory, Enum.Material.Wood)
	box(structure, "FrontFasciaProjectingWing", Vector3.new(19, 11.18, RIGHT_BAY_FRONT_Z - 2.2), Vector3.new(22, 0.55, 0.55), colors.ivory, Enum.Material.Wood)
	box(structure, "BackFascia", Vector3.new(2, 11.18, 33.2 + PRIVATE_WING_Z_SHIFT + PRIVATE_ROOM_EXTRA_DEPTH), Vector3.new(60, 0.55, 0.55), colors.ivory, Enum.Material.Wood)
	box(structure, "PorchRoof", Vector3.new(-1.5, 11.35, -13.65), Vector3.new(22.5, 0.65, 7.6), colors.roof, Enum.Material.RoofShingles, 0, true, Vector3.new(-5, 0, 0))
	box(structure, "ProjectingWingRoofFront", Vector3.new(19, 12.75, -12.8), Vector3.new(22.8, 0.78, 14.0), colors.roofDark, Enum.Material.RoofShingles, 0, true, Vector3.new(-12, 0, 0))
	box(structure, "ProjectingWingRoofBack", Vector3.new(19, 12.75, -2.2), Vector3.new(22.8, 0.78, 9.0), colors.roofDark, Enum.Material.RoofShingles, 0, true, Vector3.new(12, 0, 0))
	for _, x in ipairs({-11.0, 7.9}) do
		box(exterior, "PorchPost", Vector3.new(x, 6.1, -15.35), Vector3.new(0.62, 9.8, 0.62), colors.ivory, Enum.Material.Wood)
		beam(exterior, "PorchBracket", Vector3.new(x, 10.4, -15.35), Vector3.new(x + (x < 0 and 2.2 or -2.2), 9.2, -15.35), 0.24, colors.ivory, Enum.Material.Wood, 0, false)
	end
	box(structure, "BrickChimney", Vector3.new(-13.2, 15.25, 10.2), Vector3.new(3.2, 8.2, 4.1), colors.brick, Enum.Material.Brick)
	box(structure, "ChimneyCap", Vector3.new(-13.2, 19.5, 10.2), Vector3.new(3.8, 0.45, 4.7), colors.cream, Enum.Material.Concrete)

	-- Porch glider, potted plants, house number, and warm sconce.
	local glider = container("Model", "PorchGlider", exterior)
	box(glider, "Seat", Vector3.new(3.5, 2.55, -14.4), Vector3.new(5.2, 0.35, 1.5), colors.darkGreen, Enum.Material.Wood)
	box(glider, "Back", Vector3.new(3.5, 4.05, -14.95), Vector3.new(5.2, 2.8, 0.30), colors.darkGreen, Enum.Material.Wood)
	for slat = -2, 2 do
		box(glider, "BackSlat", Vector3.new(3.5 + slat * 0.92, 4.05, -15.13), Vector3.new(0.16, 2.4, 0.12), colors.black, Enum.Material.Metal, 0, false)
	end
	for _, x in ipairs({1.5, 5.5}) do
		beam(glider, "WhiteFrame", Vector3.new(x, 1.25, -14.1), Vector3.new(x, 3.0, -14.55), 0.22, colors.white, Enum.Material.Metal, 0, true)
	end
	for index, x in ipairs({-5.3, -3.5, 8.3}) do
		box(exterior, "TerraCottaPot" .. index, Vector3.new(x, 1.75, -14.35), Vector3.new(1.5, 1.4, 1.4), colors.terraCotta, Enum.Material.Slate, 0, true, Vector3.new(0, 0, 90), "Cylinder")
		makeShrub(exterior, "PorchPlant" .. index, Vector3.new(x, 2.8, -14.35), 1.2, index == 2 and colors.leafLight or colors.leaf)
	end
	addPointLight(exterior, "PorchSconce", Vector3.new(-5.4, 8.3, -11.0), Color3.fromRGB(255, 184, 100), 1.4, 16)

	-- Coherent early-series (1989-1991) floor bands: public rooms, den/kitchen, hall, then private rooms.
	box(interior, "FormalLivingOatmealCarpet", Vector3.new(-7.5, 1.28, -4.6), Vector3.new(34.2, 0.12, 16.2), Color3.fromRGB(194, 184, 165), Enum.Material.Fabric)
	box(interior, "DiningOatmealCarpet", Vector3.new(19.4, 1.29, -6.6), Vector3.new(18.2, 0.12, 20.2), Color3.fromRGB(187, 177, 160), Enum.Material.Fabric)
	box(interior, "DenHoneyOakFloor", Vector3.new(5.0, 1.29, 11.0), Vector3.new(20.0, 0.12, 14.0), Color3.fromRGB(118, 77, 49), Enum.Material.WoodPlanks)
	box(interior, "DenOliveAreaRug", Vector3.new(7.5, 1.40, 11.1), Vector3.new(17.2, 0.08, 9.4), Color3.fromRGB(91, 96, 58), Enum.Material.Fabric, 0, false)
	box(interior, "DenRugCenterField", Vector3.new(7.5, 1.45, 11.1), Vector3.new(15.6, 0.03, 7.8), Color3.fromRGB(118, 112, 67), Enum.Material.Fabric, 0, false)
	local kitchenLinoleum = box(interior, "KitchenPatternLinoleum", Vector3.new(-15.0, 1.29, 11.0), Vector3.new(20.0, 0.12, 14.0), Color3.fromRGB(177, 154, 121), Enum.Material.Slate)
	addTexture(kitchenLinoleum, "VettedBrownGreenLinoleum", Enum.NormalId.Top, 71637580421492, 4.0, 4.0, 0.10)
	box(interior, "DenPatioAlcoveHoneyOakFloor", Vector3.new(22.0, 1.29, 11.0), Vector3.new(14.0, 0.12, 14.0), Color3.fromRGB(118, 77, 49), Enum.Material.WoodPlanks)
	box(interior, "CrossHallFloor", Vector3.new(2, 1.29, 19.7 + PRIVATE_WING_Z_SHIFT / 2), Vector3.new(53.0, 0.12, 3.4 + PRIVATE_WING_Z_SHIFT), Color3.fromRGB(157, 125, 88), Enum.Material.WoodPlanks)
	box(interior, "ParentsGrayCarpet", Vector3.new(-17, 1.29, 26), Vector3.new(15.5, 0.12, 9.5), Color3.fromRGB(120, 115, 108), Enum.Material.Fabric)
	box(interior, "TwinsGreenGrayCarpet", Vector3.new(-0.5, 1.29, 26), Vector3.new(16.5, 0.12, 9.5), Color3.fromRGB(119, 125, 108), Enum.Material.Fabric)
	box(interior, "GeorgieBrownCarpet", Vector3.new(13.5, 1.29, 26), Vector3.new(11.0, 0.12, 9.5), Color3.fromRGB(116, 98, 80), Enum.Material.Fabric)
	box(interior, "BathroomMintMosaic", Vector3.new(24, 1.29, 26), Vector3.new(10.0, 0.12, 9.5), Color3.fromRGB(143, 155, 137), Enum.Material.Slate)
	for x = -22.5, -5.0, 2.5 do
		box(interior, "KitchenLinoleumSeam", Vector3.new(x, 1.36, 11), Vector3.new(0.04, 0.02, 13.7), Color3.fromRGB(213, 199, 171), Enum.Material.SmoothPlastic, 0, false)
	end
	for z = 5.0, 17.0, 2.0 do
		box(interior, "KitchenLinoleumSeam", Vector3.new(-15, 1.36, z), Vector3.new(19.7, 0.02, 0.04), Color3.fromRGB(213, 199, 171), Enum.Material.SmoothPlastic, 0, false)
	end

	-- Continuous ceilings close every playable band, including the former dining-extension and hall gaps.
	box(interior, "FormalLivingCeiling", Vector3.new(-7.5, 10.72, -4.6), Vector3.new(34.2, 0.24, 16.2), colors.ivory, Enum.Material.SmoothPlastic)
	box(interior, "DiningCeiling", Vector3.new(19.4, 10.72, -6.6), Vector3.new(18.2, 0.24, 20.2), colors.ivory, Enum.Material.SmoothPlastic)
	box(interior, "KitchenCeiling", Vector3.new(-15.0, 10.72, 11.0), Vector3.new(20.0, 0.24, 14.0), colors.ivory, Enum.Material.SmoothPlastic)
	box(interior, "DenCeiling", Vector3.new(5.0, 10.72, 11.0), Vector3.new(20.0, 0.24, 14.0), Color3.fromRGB(221, 211, 192), Enum.Material.SmoothPlastic)
	box(interior, "DenPatioAlcoveCeiling", Vector3.new(22.0, 10.72, 11.0), Vector3.new(14.0, 0.24, 14.0), Color3.fromRGB(221, 211, 192), Enum.Material.SmoothPlastic)
	box(interior, "CrossHallCeiling", Vector3.new(2, 10.72, 19.7 + PRIVATE_WING_Z_SHIFT / 2), Vector3.new(53.0, 0.24, 3.4 + PRIVATE_WING_Z_SHIFT), colors.ivory, Enum.Material.SmoothPlastic)
	box(interior, "BedroomWingCeiling", Vector3.new(2, 10.72, 26.15), Vector3.new(53.0, 0.24, 9.3), colors.ivory, Enum.Material.SmoothPlastic)

	-- Public-room partitions preserve the set's long camera sight lines and leave a separate 5-stud kitchen doorway.
	wallAlongX(interior, "FormalKitchenDivider", -25, -9, 3.9, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "FormalDenDividerRight", 8.0, 10, 3.9, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "FormalDenOpeningHeader", -9.0, 8.0, 3.9, 9.3, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "DiningDividerFront", 10, -13, -8.5, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "DiningDividerBack", 10, 0.4, 4.0, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "DiningOpeningHeader", 10, -8.5, 0.4, 9.2, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "KitchenDenFrontNib", -5, 4.0, 4.8, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.kitchen, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "KitchenDenBackPier", -5, 15.5, 18.1, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.kitchen, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "KitchenDenOpeningHeader", -5, 4.8, 15.5, 8.9, WALL_TOP - 0.4, 0.35, colors.kitchen, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "HallWallLeft", -25, -4.5, 18.1, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "HallWallRight", 2.5, RIGHT_EXTERIOR_X, 18.1, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "HallOpeningHeader", -4.5, 2.5, 18.1, 9.0, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	-- Short opaque returns create the set's enclosed vestibule before the sleeping-room corridor opens sideways.
	wallAlongZ(interior, "HallVestibuleLeftReturn", -4.5, 18.1, 21.0, FLOOR_Y, WALL_TOP - 0.4, 0.30, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "HallVestibuleRightReturn", 2.5, 18.1, 21.0, FLOOR_Y, WALL_TOP - 0.4, 0.30, colors.ivory, Enum.Material.SmoothPlastic)

	-- Four recognizable private-room doorways, widened for Roblox avatars and kept free of furniture.
	wallAlongX(interior, "BedroomFrontA", -25, -24, 21.3, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "BedroomFrontB", -17.0, -4.0, 21.3, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "BedroomFrontC", 4.0, 9.0, 21.3, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "BedroomFrontD", 16.0, 20.0, 21.3, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongX(interior, "BedroomFrontE", 27.0, RIGHT_EXTERIOR_X, 21.3, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	local privateOpenings = {
		{"ParentsDoorway", -24, -17.0},
		{"TwinsDoorway", -4.0, 4.0},
		{"GeorgieDoorway", 9.0, 16.0},
		{"BathroomDoorway", 20.0, 27.0},
	}
	for _, opening in ipairs(privateOpenings) do
		wallAlongX(interior, opening[1] .. "Header", opening[2], opening[3], 21.3, 9.0, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
		box(interior, opening[1] .. "LeftJamb", Vector3.new(opening[2], 5.1, 21.08), Vector3.new(0.24, 7.8, 0.24), colors.ivory, Enum.Material.Wood, 0, false)
		box(interior, opening[1] .. "RightJamb", Vector3.new(opening[3], 5.1, 21.08), Vector3.new(0.24, 7.8, 0.24), colors.ivory, Enum.Material.Wood, 0, false)
		box(interior, opening[1] .. "TopTrim", Vector3.new((opening[2] + opening[3]) / 2, 9.0, 21.08), Vector3.new(opening[3] - opening[2] + 0.3, 0.28, 0.24), colors.ivory, Enum.Material.Wood, 0, false)
	end
	wallAlongZ(interior, "ParentsTwinsWall", -9, 21.3, 31, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "TwinsGeorgieWall", 8, 21.3, 31, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	wallAlongZ(interior, "GeorgieBathWall", 19, 21.3, 31, FLOOR_Y, WALL_TOP - 0.4, 0.35, colors.ivory, Enum.Material.SmoothPlastic)
	-- Door slabs are intentionally omitted here: the framed openings are visibly open and remain full-width for avatars.

	-- Finished interior faces cover the exterior siding; patterned surfaces reproduce the recurring set wallpapers.
	box(interior, "FormalLivingLeftInteriorLining", Vector3.new(-24.60, 6.25, -4.6), Vector3.new(0.14, 9.6, 16.0), Color3.fromRGB(224, 219, 202), Enum.Material.SmoothPlastic, 0, false)
	box(interior, "HallLeftInteriorLining", Vector3.new(-24.60, 6.25, 19.7 + PRIVATE_WING_Z_SHIFT / 2), Vector3.new(0.14, 9.6, 3.2 + PRIVATE_WING_Z_SHIFT), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	local patioLiningFront = box(interior, "DenPatioRightPanelingFront", Vector3.new(RIGHT_EXTERIOR_X - 0.40, 6.25, 5.1), Vector3.new(0.14, 9.6, 4.2), colors.panel, Enum.Material.WoodPlanks, 0, false)
	local patioLiningBack = box(interior, "DenPatioRightPanelingBack", Vector3.new(RIGHT_EXTERIOR_X - 0.40, 6.25, 15.6), Vector3.new(0.14, 9.6, 4.2), colors.panel, Enum.Material.WoodPlanks, 0, false)
	local patioLiningHeader = box(interior, "DenPatioRightPanelingHeader", Vector3.new(RIGHT_EXTERIOR_X - 0.40, 10.02, 10.35), Vector3.new(0.14, 1.18, PATIO_OPENING_BACK_Z - PATIO_OPENING_FRONT_Z), colors.panel, Enum.Material.WoodPlanks, 0, false)
	for _, panel in ipairs({patioLiningFront, patioLiningBack, patioLiningHeader}) do
		addTexture(panel, "VettedVerticalWoodPaneling", Enum.NormalId.Left, 15001283987, 6.0, 6.0, 0.20)
	end
	box(interior, "HallRightInteriorLining", Vector3.new(RIGHT_EXTERIOR_X - 0.40, 6.25, 19.7 + PRIVATE_WING_Z_SHIFT / 2), Vector3.new(0.14, 9.6, 3.2 + PRIVATE_WING_Z_SHIFT), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	-- Front-bay linings are split around the real windows so the glass remains visible from inside.
	for index, spec in ipairs({
		{Vector3.new(-23.2, 6.25, -12.60), Vector3.new(3.2, 9.6, 0.14)},
		{Vector3.new(-14.7, 6.25, -12.60), Vector3.new(4.6, 9.6, 0.14)},
		{Vector3.new(-19.2, 2.62, -12.60), Vector3.new(4.4, 2.75, 0.14)},
		{Vector3.new(-19.2, 10.02, -12.60), Vector3.new(4.4, 2.45, 0.14)},
	}) do
		box(interior, "FormalFrontLining" .. index, spec[1], spec[2], Color3.fromRGB(224, 219, 202), Enum.Material.SmoothPlastic, 0, false)
	end
	for index, spec in ipairs({
		{Vector3.new(13.2, 6.25, RIGHT_BAY_FRONT_Z + 0.40), Vector3.new(8.2, 9.6, 0.14)},
		{Vector3.new(25.8, 6.25, RIGHT_BAY_FRONT_Z + 0.40), Vector3.new(6.2, 9.6, 0.14)},
		{Vector3.new(20.0, 2.62, RIGHT_BAY_FRONT_Z + 0.40), Vector3.new(5.2, 2.75, 0.14)},
		{Vector3.new(20.0, 10.02, RIGHT_BAY_FRONT_Z + 0.40), Vector3.new(5.2, 2.45, 0.14)},
	}) do
		local panel = box(interior, "DiningFrontToileLining" .. index, spec[1], spec[2], Color3.fromRGB(236, 231, 211), Enum.Material.SmoothPlastic, 0, false)
		addTexture(panel, "VettedBlueCreamToile", Enum.NormalId.Back, 3324666775, 6.0, 6.0, 0.10)
	end
	-- The paneled den wall is physically split around a real, white-cased hall opening.
	local denBackLeft = box(interior, "DenBackPanelingLeftPier", Vector3.new(-4.65, 6.25, 17.72), Vector3.new(0.30, 9.6, 0.16), colors.panel, Enum.Material.WoodPlanks)
	local denBackRight = box(interior, "DenBackPanelingRightWall", Vector3.new(8.65, 6.25, 17.72), Vector3.new(12.30, 9.6, 0.16), colors.panel, Enum.Material.WoodPlanks)
	local denBackHeader = box(interior, "DenBackPanelingHallHeader", Vector3.new(-1.0, 10.02, 17.72), Vector3.new(7.0, 1.18, 0.16), colors.panel, Enum.Material.WoodPlanks)
	for _, panel in ipairs({denBackLeft, denBackRight, denBackHeader}) do
		addTexture(panel, "VettedVerticalWoodPaneling", Enum.NormalId.Front, 15001283987, 7.0, 7.0, 0.20)
		panel:SetAttribute("Reference", "early-series vertical honey-toned wood paneling")
	end
	for x = 3.0, 14.5, 1.0 do
		box(interior, "DenPanelGroove", Vector3.new(x, 6.2, 17.60), Vector3.new(0.035, 9.1, 0.04), Color3.fromRGB(86, 58, 39), Enum.Material.Wood, 0, false)
	end
	box(interior, "DenHallLeftJamb", Vector3.new(-4.5, 5.1, 17.48), Vector3.new(0.30, 7.8, 0.30), colors.ivory, Enum.Material.Wood, 0, false)
	box(interior, "DenHallRightJamb", Vector3.new(2.5, 5.1, 17.48), Vector3.new(0.30, 7.8, 0.30), colors.ivory, Enum.Material.Wood, 0, false)
	box(interior, "DenHallTopCasing", Vector3.new(-1.0, 9.05, 17.48), Vector3.new(7.3, 0.34, 0.30), colors.ivory, Enum.Material.Wood, 0, false)
	-- Only the fireplace end of this former partition remains; the open side now leads to the working patio door.
	local denFireplaceBacking = box(interior, "DenFireplaceBackingPanel", Vector3.new(14.62, 6.25, 15.4), Vector3.new(0.16, 9.6, 5.2), colors.panel, Enum.Material.WoodPlanks, 0, true)
	addTexture(denFireplaceBacking, "VettedVerticalWoodPaneling", Enum.NormalId.Left, 15001283987, 7.0, 7.0, 0.20)
	local kitchenBack = box(interior, "KitchenOchreBackWall", Vector3.new(-15.0, 6.25, 17.72), Vector3.new(19.6, 9.6, 0.16), Color3.fromRGB(185, 158, 78), Enum.Material.SmoothPlastic, 0, false)
	local kitchenPaper = box(interior, "KitchenFruitWallpaper", Vector3.new(-24.60, 6.25, 11.0), Vector3.new(0.14, 9.6, 13.6), Color3.fromRGB(231, 224, 190), Enum.Material.SmoothPlastic, 0, false)
	addDiamondFruitWallpaper(kitchenPaper, Enum.NormalId.Right)
	addTexture(kitchenPaper, "VettedSageCreamLeafPattern", Enum.NormalId.Right, 4728847017, 5.0, 5.0, 0.18)
	local diningPaper = box(interior, "DiningBlueToileWallpaper", Vector3.new(RIGHT_EXTERIOR_X - 0.40, 6.25, -6.6), Vector3.new(0.14, 9.6, 20.0), Color3.fromRGB(236, 231, 211), Enum.Material.SmoothPlastic, 0, false)
	addWallpaperPattern(diningPaper, "PastoralBlueToile", Enum.NormalId.Left, "♞  ❧", Color3.fromRGB(111, 134, 142), 5, 8, 0)
	addTexture(diningPaper, "VettedBlueCreamToile", Enum.NormalId.Left, 3324666775, 6.0, 6.0, 0.10)
	box(interior, "ParentsLeftInteriorLining", Vector3.new(-24.60, 6.25, 26.0), Vector3.new(0.14, 9.6, 9.4), Color3.fromRGB(222, 217, 196), Enum.Material.SmoothPlastic, 0, false)
	local parentsPaper = box(interior, "ParentsMutedRoseWallpaper", Vector3.new(-17, 6.25, 30.62), Vector3.new(15.5, 9.6, 0.14), Color3.fromRGB(218, 214, 194), Enum.Material.SmoothPlastic, 0, false)
	addWallpaperPattern(parentsPaper, "MutedEnglishChintz", Enum.NormalId.Front, "❀", Color3.fromRGB(151, 123, 105), 8, 5, 8)
	addTexture(parentsPaper, "VettedGreenFloralWallpaper", Enum.NormalId.Front, 15564484679, 7.0, 7.0, 0.68)
	local twinsWall = box(interior, "TwinsPaleYellowWall", Vector3.new(-0.5, 6.25, 30.62), Vector3.new(16.5, 9.6, 0.14), Color3.fromRGB(215, 204, 151), Enum.Material.SmoothPlastic, 0, false)
	local georgieWall = box(interior, "GeorgiePowderBlueWall", Vector3.new(13.5, 6.25, 30.62), Vector3.new(11.0, 9.6, 0.14), Color3.fromRGB(172, 193, 199), Enum.Material.SmoothPlastic, 0, false)
	box(interior, "GeorgieLeftPowderBlueLining", Vector3.new(8.20, 6.25, 26.15), Vector3.new(0.14, 9.6, 9.3), Color3.fromRGB(172, 193, 199), Enum.Material.SmoothPlastic, 0, false)
	box(interior, "GeorgieRightPowderBlueLining", Vector3.new(18.80, 6.25, 26.15), Vector3.new(0.14, 9.6, 9.3), Color3.fromRGB(172, 193, 199), Enum.Material.SmoothPlastic, 0, false)
	box(interior, "GeorgieFrontPowderBlueLining", Vector3.new(17.5, 6.25, 21.48), Vector3.new(3.0, 9.6, 0.14), Color3.fromRGB(172, 193, 199), Enum.Material.SmoothPlastic, 0, false)
	local bathroomPaper = box(interior, "BathroomRedBotanicalWallpaper", Vector3.new(24, 6.25, 30.62), Vector3.new(10.0, 9.6, 0.14), Color3.fromRGB(238, 226, 207), Enum.Material.SmoothPlastic, 0, false)
	addWallpaperPattern(bathroomPaper, "RedBotanicalSprays", Enum.NormalId.Front, "❧", Color3.fromRGB(168, 66, 58), 6, 7, 12)
	addTexture(bathroomPaper, "VettedCoralBotanicalWallpaper", Enum.NormalId.Front, 6954847531, 5.0, 5.0, 0.12)
	local bathroomSidePaper = box(interior, "BathroomSideBotanicalWallpaper", Vector3.new(RIGHT_EXTERIOR_X - 0.40, 6.25, 26), Vector3.new(0.14, 9.6, 9.4), Color3.fromRGB(238, 226, 207), Enum.Material.SmoothPlastic, 0, false)
	addWallpaperPattern(bathroomSidePaper, "RedBotanicalSprays", Enum.NormalId.Left, "❧", Color3.fromRGB(168, 66, 58), 4, 7, 12)
	addTexture(bathroomSidePaper, "VettedCoralBotanicalWallpaper", Enum.NormalId.Left, 6954847531, 5.0, 5.0, 0.12)
	kitchenBack:SetAttribute("Reference", "mustard kitchen walls and cream floral-diamond paper")
	twinsWall:SetAttribute("Reference", "2017 shared Sheldon and Missy bedroom")
	georgieWall:SetAttribute("Reference", "early Georgie football bedroom")

	-- Baseboards, cased openings, and a visible hall photo rail finish the architecture.
	for index, spec in ipairs({
		{Vector3.new(-15, 1.75, 17.56), Vector3.new(20, 0.55, 0.16)},
		{Vector3.new(5, 1.75, 17.56), Vector3.new(20, 0.55, 0.16)},
		{Vector3.new(RIGHT_EXTERIOR_X - 0.55, 1.75, -6.6), Vector3.new(0.16, 0.55, 20)},
		{Vector3.new(-17, 1.75, 30.50), Vector3.new(15.5, 0.55, 0.14)},
		{Vector3.new(-0.5, 1.75, 30.50), Vector3.new(16.5, 0.55, 0.14)},
		{Vector3.new(13.5, 1.75, 30.50), Vector3.new(11, 0.55, 0.14)},
		{Vector3.new(24, 1.75, 30.50), Vector3.new(10, 0.55, 0.14)},
	}) do
		box(interior, "Baseboard" .. index, spec[1], spec[2], colors.ivory, Enum.Material.Wood, 0, false)
	end
	-- Brown striped panels frame the den's white half-glazed exterior door while preserving its full clear opening.
	beam(furniture, "DenPatioCurtainRod", Vector3.new(RIGHT_EXTERIOR_X - 0.75, 9.55, 6.9), Vector3.new(RIGHT_EXTERIOR_X - 0.75, 9.55, 13.8), 0.10, colors.darkWood, Enum.Material.Wood, 0, false)
	for index, z in ipairs({7.15, 13.55}) do
		box(furniture, "DenPatioStripedCurtain" .. index, Vector3.new(RIGHT_EXTERIOR_X - 0.72, 6.55, z), Vector3.new(0.12, 5.8, 0.92), Color3.fromRGB(151, 124, 87), Enum.Material.Fabric, 0, false)
		for stripe = -2, 2 do
			box(furniture, "DenPatioCurtainStripe" .. index .. "_" .. stripe, Vector3.new(RIGHT_EXTERIOR_X - 0.80, 6.55, z + stripe * 0.17), Vector3.new(0.03, 5.6, 0.07), stripe % 2 == 0 and Color3.fromRGB(101, 76, 55) or Color3.fromRGB(211, 188, 141), Enum.Material.Fabric, 0, false)
		end
	end

	-- Early-series formal parlor: compact seating group, clear foyer, broad dining arch and no geometry crossing the facade.
	local formalSofa = makeCouch(furniture, "FormalGreenFloralSofa", Vector3.new(-22.15, FLOOR_Y, -4.7), 8.0, Color3.fromRGB(112, 128, 77), -90)
	for _, upholsteredPart in ipairs(formalSofa:GetChildren()) do
		if upholsteredPart:IsA("BasePart") and upholsteredPart.Material == Enum.Material.Fabric then
			for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
				addTexture(upholsteredPart, "SubtleGreenFloral", face, 15564484679, 4.5, 4.5, 0.66)
			end
		end
	end
	for index, z in ipairs({-7.15, -4.70, -2.25}) do
		local pillow = box(furniture, "FormalBackPillow" .. index, Vector3.new(-22.62, 3.05, z), Vector3.new(0.42, 1.35, 1.55), index == 2 and Color3.fromRGB(198, 175, 132) or Color3.fromRGB(157, 165, 103), Enum.Material.Fabric, 0, false, Vector3.new(0, 0, index == 2 and -7 or 5))
		addTexture(pillow, "SubtlePillowFloral", Enum.NormalId.Right, 15564484679, 2.5, 2.5, 0.58)
	end
	makeArmchair(furniture, "FormalRustButtonChair", Vector3.new(-5.8, FLOOR_Y, -3.3), Color3.fromRGB(149, 66, 49), 58)
	makeLowTable(furniture, "FormalGlassCoffeeTable", Vector3.new(-15.0, FLOOR_Y, -4.7), Vector3.new(6.4, 0, 3.35), colors.darkWood, 0)
	box(furniture, "FormalCoffeeGlassLeft", Vector3.new(-16.65, 2.86, -4.7), Vector3.new(2.55, 0.10, 2.65), colors.glass, Enum.Material.Glass, 0.22, false)
	box(furniture, "FormalCoffeeGlassRight", Vector3.new(-13.35, 2.86, -4.7), Vector3.new(2.55, 0.10, 2.65), colors.glass, Enum.Material.Glass, 0.22, false)
	box(furniture, "FormalCoffeeCenterStretcher", Vector3.new(-15.0, 2.92, -4.7), Vector3.new(0.34, 0.12, 2.85), colors.darkWood, Enum.Material.Wood, 0, false)
	box(furniture, "FormalCrochetRunner", Vector3.new(-15.0, 2.99, -4.7), Vector3.new(1.05, 0.04, 2.35), Color3.fromRGB(225, 213, 184), Enum.Material.Fabric, 0, false)
	makeLowTable(furniture, "FormalSofaEndTable", Vector3.new(-20.1, FLOOR_Y, -9.6), Vector3.new(2.2, 0, 2.0), colors.darkWood, 0)
	makeLamp(furniture, "FormalBrassFloorLamp", Vector3.new(-19.4, FLOOR_Y, 0.5), Color3.fromRGB(231, 217, 180))

	-- The foyer is dressed but keeps a six-stud path from the front door into the parlor.
	box(furniture, "FormalEntryRunner", Vector3.new(-8.0, 1.40, -7.7), Vector3.new(4.6, 0.08, 4.0), Color3.fromRGB(123, 88, 63), Enum.Material.Fabric, 0, false)
	local entryConsole = container("Model", "FormalEntryConsole", furniture)
	box(entryConsole, "ConsoleTop", Vector3.new(-14.0, 3.35, -11.45), Vector3.new(3.6, 0.28, 1.05), colors.darkWood, Enum.Material.Wood)
	for _, x in ipairs({-15.45, -12.55}) do
		box(entryConsole, "ConsoleLeg", Vector3.new(x, 2.25, -11.45), Vector3.new(0.24, 2.2, 0.24), colors.darkWood, Enum.Material.Wood)
	end
	box(entryConsole, "AddressBook", Vector3.new(-14.35, 3.57, -11.38), Vector3.new(1.15, 0.10, 0.75), Color3.fromRGB(78, 99, 123), Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 10, 0))
	box(entryConsole, "SmallLampBase", Vector3.new(-12.9, 3.72, -11.35), Vector3.new(0.30, 0.62, 0.62), colors.darkWood, Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	box(entryConsole, "SmallLampStem", Vector3.new(-12.9, 4.35, -11.35), Vector3.new(1.05, 0.10, 0.10), colors.metal, Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	box(entryConsole, "SmallLampShade", Vector3.new(-12.9, 5.15, -11.35), Vector3.new(0.9, 1.25, 1.25), Color3.fromRGB(222, 199, 158), Enum.Material.Fabric, 0.10, false, Vector3.new(0, 0, 90), "Cylinder")
	addPointLight(entryConsole, "SmallEntryLampBulb", Vector3.new(-12.9, 4.9, -11.35), Color3.fromRGB(255, 209, 146), 0.65, 7)
	box(furniture, "BrassUmbrellaStand", Vector3.new(-11.4, 2.0, -9.6), Vector3.new(2.2, 0.85, 0.85), Color3.fromRGB(142, 105, 47), Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	for index, x in ipairs({-15.45, -14.0, -12.65}) do
		makeFramedArt(furniture, "FoyerFamilyPhoto" .. index, Vector3.new(x, 6.8 + (index % 2) * 0.55, -12.28), Vector2.new(0.9 + index * 0.08, 1.15), index % 2 == 0 and colors.tan or colors.darkWood, Color3.fromRGB(168, 145, 112), "", 180)
	end
	local houseNumber = box(exterior, "HouseNumber5501", Vector3.new(-5.35, 7.2, -10.92), Vector3.new(1.75, 0.90, 0.08), colors.ivory, Enum.Material.Wood, 0, false)
	addSurfaceText(houseNumber, "HouseNumberText", Enum.NormalId.Front, "5501", colors.black, colors.ivory, 24, Enum.Font.Garamond)
	for index, z in ipairs({-9.65, 1.45}) do
		addPointLight(furniture, "FormalArchSconce" .. index, Vector3.new(9.55, 7.7, z), Color3.fromRGB(255, 207, 145), 0.75, 9)
		box(furniture, "FormalArchSconcePlate" .. index, Vector3.new(9.72, 7.7, z), Vector3.new(0.12, 1.25, 0.80), Color3.fromRGB(171, 127, 55), Enum.Material.Metal, 0, false)
	end

	-- Dining room: exact blue toile character, plaid curtains, traditional six-place table, china hutch and family supper props.
	makeTable(furniture, "CooperDiningTable", Vector3.new(18.3, FLOOR_Y, -4.4), Vector3.new(7.4, 0, 4.1), Color3.fromRGB(98, 65, 43), 0)
	for index, spec in ipairs({
		{Vector3.new(14.9, FLOOR_Y, -1.1), 0}, {Vector3.new(18.7, FLOOR_Y, -1.1), 0},
		{Vector3.new(14.9, FLOOR_Y, -7.7), 180}, {Vector3.new(18.7, FLOOR_Y, -7.7), 180},
		{Vector3.new(13.1, FLOOR_Y, -4.4), -90}, {Vector3.new(23.3, FLOOR_Y, -4.4), 90},
	}) do
		makeDiningChair(furniture, "TraditionalDiningChair" .. index, spec[1], colors.darkWood, spec[2])
		box(furniture, "DiningSeatPad" .. index, spec[1] + Vector3.new(0, 1.80, 0), Vector3.new(1.45, 0.12, 1.45), Color3.fromRGB(170, 150, 112), Enum.Material.Fabric, 0, false, Vector3.new(0, spec[2], 0))
	end
	for index, position in ipairs({
		Vector3.new(15.2, 4.125, -3.1), Vector3.new(18.4, 4.125, -3.1), Vector3.new(21.3, 4.125, -4.4),
		Vector3.new(15.2, 4.125, -5.7), Vector3.new(18.4, 4.125, -5.7), Vector3.new(15.2, 4.125, -4.4),
	}) do
		makeDish(furniture, "DinnerPlate" .. index, position, 1.15, colors.ivory)
		local glassXOffset = index == 3 and 0.48 or 0.62
		box(furniture, "IcedTeaGlass" .. index, position + Vector3.new(glassXOffset, 0.35, 0.28), Vector3.new(0.80, 0.32, 0.32), Color3.fromRGB(175, 117, 55), Enum.Material.Glass, 0.18, false, Vector3.new(0, 0, 90), "Cylinder")
	end
	makeDish(furniture, "ServingBowl", Vector3.new(18.3, 4.125, -4.4), 1.65, Color3.fromRGB(225, 213, 184))
	box(furniture, "GreenBeans", Vector3.new(18.3, 4.215, -4.4), Vector3.new(0.08, 1.2, 1.2), Color3.fromRGB(81, 111, 52), Enum.Material.Grass, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	box(furniture, "DiningChinaHutch", Vector3.new(23.65, 4.7, 0.6), Vector3.new(1.55, 6.9, 4.8), colors.darkWood, Enum.Material.Wood)
	for shelf = 1, 3 do
		box(furniture, "HutchHorizontalShelf" .. shelf, Vector3.new(22.80, 2.6 + shelf * 1.35, 0.6), Vector3.new(0.14, 0.16, 4.2), colors.tan, Enum.Material.Wood, 0, false)
		for plateIndex = -1, 1 do
			makeDish(furniture, "DisplayedChina", Vector3.new(22.68, 2.9 + shelf * 1.35, 0.6 + plateIndex * 1.2), 0.72, colors.ivory)
		end
	end
	makeCurtainSet(furniture, "DiningPlaidCurtains", Vector3.new(18.3, 6.4, -14.55), 5.4, 5.2, Color3.fromRGB(151, 138, 111), 0)
	addPointLight(furniture, "DiningMilkGlassChandelier", Vector3.new(18.3, 8.7, -4.4), Color3.fromRGB(255, 208, 146), 1.25, 14)
	for offset = -1, 1 do
		beam(furniture, "DiningChandelierArm", Vector3.new(18.3, 9.6, -4.4), Vector3.new(18.3 + offset * 1.3, 8.8, -4.4), 0.12, Color3.fromRGB(166, 126, 61), Enum.Material.Metal, 0, false)
	end

	-- Wood-paneled TV den: red plaid sofa, George's olive recliner, CRT/VCR, fireplace, stereo and built-in shelves.
	makePlaidCouch(furniture, "RedPlaidDenSofa", Vector3.new(6.6, FLOOR_Y, 15.5), 8.2, Color3.fromRGB(135, 57, 48), 0)
	box(furniture, "DenCrochetThrow", Vector3.new(8.4, 4.3, 15.42), Vector3.new(2.2, 2.6, 0.10), Color3.fromRGB(193, 156, 104), Enum.Material.Fabric, 0, false, Vector3.new(0, 0, 4))
	-- George's recliner stays by the patio/window side but no longer blocks the den-to-patio walking lane.
	makeArmchair(furniture, "GeorgeOliveRecliner", Vector3.new(21.0, FLOOR_Y, 15.2), Color3.fromRGB(104, 105, 65), 225)
	makeLowTable(furniture, "DenWalnutCoffeeTable", Vector3.new(5.8, FLOOR_Y, 9.6), Vector3.new(5.2, 0, 2.6), colors.wood, 0)
	box(furniture, "TVGuideMagazine", Vector3.new(5.1, 2.91, 9.5), Vector3.new(1.4, 0.06, 1.0), Color3.fromRGB(184, 63, 46), Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 18, 0))
	local tv = container("Model", "WoodCabinetCRTTelevision", furniture)
	box(tv, "WalnutCabinet", Vector3.new(4.4, 3.7, 5.55), Vector3.new(6.3, 4.4, 1.85), colors.darkWood, Enum.Material.Wood)
	box(tv, "TanBezel", Vector3.new(3.8, 4.0, 6.53), Vector3.new(4.45, 2.95, 0.16), Color3.fromRGB(165, 139, 102), Enum.Material.SmoothPlastic, 0, false)
	box(tv, "CurvedGlassScreen", Vector3.new(3.8, 4.0, 6.64), Vector3.new(3.85, 2.45, 0.09), Color3.fromRGB(54, 65, 60), Enum.Material.Glass, 0.06, false)
	addSurfaceText(tv.CurvedGlassScreen, "ChannelGlow", Enum.NormalId.Back, "8", Color3.fromRGB(153, 183, 155), Color3.fromRGB(47, 59, 54), 24, Enum.Font.Code)
	for y = 3.2, 4.8, 0.8 do
		box(tv, "ChannelKnob", Vector3.new(6.35, y, 6.66), Vector3.new(0.16, 0.42, 0.42), colors.black, Enum.Material.Metal, 0, false, Vector3.new(0, 90, 0), "Cylinder")
	end
	beam(tv, "RabbitEarLeft", Vector3.new(4.1, 6.0, 5.85), Vector3.new(2.8, 7.8, 6.10), 0.10, colors.metal, Enum.Material.Metal, 0, false)
	beam(tv, "RabbitEarRight", Vector3.new(4.7, 6.0, 5.85), Vector3.new(6.0, 7.8, 6.10), 0.10, colors.metal, Enum.Material.Metal, 0, false)
	box(tv, "BlackVCR", Vector3.new(4.4, 1.75, 6.0), Vector3.new(4.7, 0.62, 1.05), colors.black, Enum.Material.SmoothPlastic, 0, false)
	for index = 1, 5 do
		box(tv, "VHSCase" .. index, Vector3.new(2.3 + index * 0.65, 1.48, 5.95), Vector3.new(0.52, 0.12, 0.85), index % 2 == 0 and colors.blue or colors.red, Enum.Material.SmoothPlastic, 0, false)
	end
	local bookcase = container("Model", "WhiteDenBuiltInBookcase", furniture)
	box(bookcase, "Back", Vector3.new(13.0, 5.1, 4.65), Vector3.new(3.2, 7.4, 0.38), colors.ivory, Enum.Material.Wood)
	for shelf = 0, 4 do
		box(bookcase, "HorizontalShelf" .. shelf, Vector3.new(13.0, 1.55 + shelf * 1.45, 5.15), Vector3.new(3.2, 0.16, 1.25), colors.ivory, Enum.Material.Wood, 0, false)
	end
	makeBooks(bookcase, "PaperbackRow", Vector3.new(12.0, 3.2, 4.95), 7, Vector3.new(0.29, 0, 0), {colors.red, colors.blue, colors.olive, colors.tan})
	for index = 1, 4 do
		box(bookcase, "BoardGame" .. index, Vector3.new(13.0, 6.0 + index * 0.28, 5.0), Vector3.new(2.2 - index * 0.12, 0.22, 0.95), index % 2 == 0 and colors.yellow or colors.blue, Enum.Material.SmoothPlastic, 0, false)
	end
	local fireplace = container("Model", "DenBrickFireplace", furniture)
	box(fireplace, "DarkFirebox", Vector3.new(14.18, 3.2, 14.1), Vector3.new(0.42, 3.2, 4.2), Color3.fromRGB(38, 31, 27), Enum.Material.Brick)
	box(fireplace, "BrickSurround", Vector3.new(14.36, 4.0, 14.1), Vector3.new(0.28, 5.6, 5.4), Color3.fromRGB(113, 67, 50), Enum.Material.Brick, 0, false)
	box(fireplace, "WalnutMantel", Vector3.new(13.78, 6.65, 14.1), Vector3.new(1.2, 0.42, 6.0), colors.darkWood, Enum.Material.Wood)
	for index, z in ipairs({13.25, 14.1, 14.95}) do
		beam(fireplace, "Log" .. index, Vector3.new(13.75, 2.3, z - 0.55), Vector3.new(13.75, 2.3, z + 0.55), 0.22, colors.darkWood, Enum.Material.Wood, 0, false)
		box(fireplace, "Ember" .. index, Vector3.new(13.55, 2.45, z), Vector3.new(0.16, 0.35, 0.35), Color3.fromRGB(224, 106, 42), Enum.Material.Neon, 0, false, nil, "Ball")
	end
	local stereo = container("Model", "DenStereoCassetteDeck", furniture)
	box(stereo, "Receiver", Vector3.new(10.4, 3.0, 16.75), Vector3.new(3.1, 1.0, 1.0), Color3.fromRGB(57, 59, 57), Enum.Material.Metal, 0, false)
	for side = -1, 1, 2 do
		box(stereo, "Speaker", Vector3.new(10.4 + side * 1.3, 3.3, 16.75), Vector3.new(1.25, 2.3, 1.0), colors.darkWood, Enum.Material.Wood, 0, false)
		box(stereo, "SpeakerCone", Vector3.new(10.4 + side * 1.3, 3.3, 16.20), Vector3.new(0.12, 0.72, 0.72), colors.black, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	end
	makeLamp(furniture, "AmberDenLamp", Vector3.new(-2.9, FLOOR_Y, 14.5), Color3.fromRGB(205, 137, 59))
	makeFramedArt(furniture, "DenFootballPhoto", Vector3.new(9.5, 7.5, 17.58), Vector2.new(2.8, 2.0), colors.darkWood, Color3.fromRGB(132, 115, 91), "MEDFORD\nFOOTBALL", 0)

	-- Mustard-and-floral kitchen copied from the recurring set: dark oak cabinets, cream square-tile counters and white appliances.
	for index, spec in ipairs({
		{Vector3.new(-20.3, 2.45, 16.25), Vector3.new(6.2, 2.4, 2.15)},
		{Vector3.new(-14.4, 2.45, 16.25), Vector3.new(5.6, 2.4, 2.15)},
		{Vector3.new(-23.25, 2.45, 11.25), Vector3.new(2.15, 2.4, 7.8)},
	}) do
		box(furniture, "DarkOakLowerCabinet" .. index, spec[1], spec[2], Color3.fromRGB(92, 66, 47), Enum.Material.Wood)
	end
	local backTileCounter = box(furniture, "CreamTileBackCounterLeft", Vector3.new(-17.3, 3.79, 16.25), Vector3.new(12.2, 0.30, 2.45), Color3.fromRGB(218, 208, 181), Enum.Material.Marble)
	addTexture(backTileCounter, "VettedCreamCounterTile", Enum.NormalId.Top, 658619458, 2.0, 2.0, 0.08)
	local sideTileCounter = box(furniture, "CreamTileSideCounter", Vector3.new(-23.25, 3.79, 11.25), Vector3.new(2.45, 0.30, 8.0), Color3.fromRGB(218, 208, 181), Enum.Material.Marble)
	addTexture(sideTileCounter, "VettedCreamCounterTile", Enum.NormalId.Top, 658619458, 2.0, 2.0, 0.08)
	for x = -22.7, -11.7, 1.0 do
		box(furniture, "CounterGroutX", Vector3.new(x, 3.96, 16.25), Vector3.new(0.035, 0.02, 2.35), Color3.fromRGB(156, 148, 132), Enum.Material.SmoothPlastic, 0, false)
	end
	for z = 15.3, 17.2, 0.62 do
		box(furniture, "CounterGroutZ", Vector3.new(-17.3, 3.96, z), Vector3.new(12.0, 0.02, 0.035), Color3.fromRGB(156, 148, 132), Enum.Material.SmoothPlastic, 0, false)
	end
	for index, x in ipairs({-21.2, -11.0}) do
		box(furniture, "UpperOakCabinet" .. index, Vector3.new(x, 7.25, 17.05), Vector3.new(4.0, 3.5, 1.15), Color3.fromRGB(84, 61, 44), Enum.Material.Wood)
		for side = -1, 1, 2 do
			box(furniture, "RaisedCabinetDoor", Vector3.new(x + side * 1.0, 7.25, 16.42), Vector3.new(1.75, 3.0, 0.10), Color3.fromRGB(101, 73, 51), Enum.Material.Wood, 0, false)
			box(furniture, "CabinetPull", Vector3.new(x + side * 0.32, 7.2, 16.31), Vector3.new(0.12, 0.58, 0.12), colors.black, Enum.Material.Metal, 0, false)
		end
	end

	-- Sink under the lace-curtained window, dish rack, radio, rooster ceramics and canister row.
	makeInteriorWindow(furniture, "KitchenSinkWindow", Vector3.new(-15.1, 7.0, 17.46), 5.2, 3.3, 0, colors.ivory)
	box(furniture, "DoublePorcelainSink", Vector3.new(-15.1, 3.88, 16.12), Vector3.new(4.6, 0.32, 1.85), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	box(furniture, "LeftSinkBasin", Vector3.new(-16.25, 4.02, 16.10), Vector3.new(1.9, 0.12, 1.45), colors.metal, Enum.Material.Metal, 0, false)
	box(furniture, "RightSinkBasin", Vector3.new(-13.95, 4.02, 16.10), Vector3.new(1.9, 0.12, 1.45), colors.metal, Enum.Material.Metal, 0, false)
	beam(furniture, "ChromeFaucet", Vector3.new(-15.1, 4.05, 17.0), Vector3.new(-15.1, 5.0, 16.65), 0.15, colors.metal, Enum.Material.Metal, 0, false)
	local rack = container("Model", "WhiteWireDishRack", furniture)
	for index = -3, 3 do
		beam(rack, "RackWire", Vector3.new(-18.3 + index * 0.32, 4.18, 15.55), Vector3.new(-18.3 + index * 0.32, 4.9, 16.45), 0.05, colors.ivory, Enum.Material.Metal, 0, false)
		if index % 2 == 0 then
			makeDish(rack, "DryingPlate", Vector3.new(-18.3 + index * 0.32, 4.55, 16.05), 0.85, colors.ivory)
		end
	end
	for index, x in ipairs({-21.0, -20.0, -19.0}) do
		box(furniture, "KitchenCanister" .. index, Vector3.new(x, 4.55, 16.0), Vector3.new(1.05, 0.78, 0.78), index == 2 and Color3.fromRGB(124, 104, 72) or colors.cream, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 90), "Cylinder")
		box(furniture, "CanisterLid" .. index, Vector3.new(x, 5.10, 16.0), Vector3.new(0.10, 0.86, 0.86), colors.darkWood, Enum.Material.Wood, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	end
	local rooster = container("Model", "CeramicRoosterSet", furniture)
	box(rooster, "Body", Vector3.new(-22.3, 4.65, 15.8), Vector3.new(0.9, 1.15, 0.9), Color3.fromRGB(222, 206, 170), Enum.Material.SmoothPlastic, 0, false, nil, "Ball")
	box(rooster, "Head", Vector3.new(-22.3, 5.35, 15.65), Vector3.new(0.55, 0.55, 0.55), colors.ivory, Enum.Material.SmoothPlastic, 0, false, nil, "Ball")
	box(rooster, "Comb", Vector3.new(-22.3, 5.72, 15.65), Vector3.new(0.18, 0.42, 0.35), colors.red, Enum.Material.SmoothPlastic, 0, false)
	box(rooster, "Beak", Vector3.new(-22.3, 5.32, 15.30), Vector3.new(0.22, 0.22, 0.35), colors.yellow, Enum.Material.SmoothPlastic, 0, false)
	box(furniture, "CounterRadio", Vector3.new(-12.2, 4.55, 16.0), Vector3.new(1.9, 1.0, 0.85), Color3.fromRGB(82, 78, 65), Enum.Material.SmoothPlastic, 0, false)
	for index = -2, 2 do
		box(furniture, "RadioSlot", Vector3.new(-12.2 + index * 0.24, 4.55, 15.53), Vector3.new(0.08, 0.58, 0.04), colors.black, Enum.Material.Metal, 0, false)
	end

	-- White Hotpoint-style refrigerator with early-series grocery note, magnets and Sheldon's bathroom schedule.
	local fridge = container("Model", "WhiteHotpointRefrigerator", furniture)
	box(fridge, "RefrigeratorBody", Vector3.new(-21.4, 4.65, 6.25), Vector3.new(4.0, 6.8, 3.25), Color3.fromRGB(226, 222, 206), Enum.Material.Metal)
	box(fridge, "FreezerSeam", Vector3.new(-21.4, 6.25, 4.60), Vector3.new(3.75, 0.08, 0.06), colors.metal, Enum.Material.Metal, 0, false)
	box(fridge, "ChromeHandle", Vector3.new(-19.58, 5.2, 4.48), Vector3.new(0.18, 2.4, 0.18), colors.metal, Enum.Material.Metal, 0, false)
	local groceryNote = box(fridge, "MarysGroceryList", Vector3.new(-21.65, 5.45, 4.57), Vector3.new(2.5, 1.85, 0.05), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	addSurfaceText(groceryNote, "GroceryListWriting", Enum.NormalId.Front, "GROCERY LIST\nMILK  BREAD  EGGS\nCOFFEE  TUNA", Color3.fromRGB(48, 75, 95), Color3.fromRGB(239, 235, 214), 13, Enum.Font.Cartoon)
	local bathSchedule = box(fridge, "BathroomSchedule", Vector3.new(-20.15, 3.55, 4.57), Vector3.new(1.2, 1.35, 0.05), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	addSurfaceText(bathSchedule, "BathroomWriting", Enum.NormalId.Front, "BATHROOM\nSCHEDULE", Color3.fromRGB(143, 53, 45), Color3.fromRGB(239, 235, 214), 11, Enum.Font.Cartoon)
	for index = 1, 10 do
		box(fridge, "SouvenirMagnet" .. index, Vector3.new(-22.8 + (index % 4) * 0.65, 2.55 + math.floor(index / 4) * 0.52, 4.50), Vector3.new(0.04, 0.26, 0.26), ({colors.red, colors.blue, colors.yellow, colors.olive})[((index - 1) % 4) + 1], Enum.Material.SmoothPlastic, 0, false, nil, "Ball")
	end

	-- White range, black burners, dishwasher and small appliances.
	box(furniture, "WhiteElectricRange", Vector3.new(-7.5, 3.25, 16.0), Vector3.new(4.0, 4.0, 2.7), Color3.fromRGB(226, 222, 206), Enum.Material.Metal)
	box(furniture, "BlackOvenWindow", Vector3.new(-7.5, 2.8, 14.60), Vector3.new(2.8, 1.65, 0.10), colors.black, Enum.Material.Glass, 0.10, false)
	box(furniture, "RangeControlPanel", Vector3.new(-7.5, 4.75, 14.62), Vector3.new(3.5, 0.8, 0.12), colors.ivory, Enum.Material.Metal, 0, false)
	for index, offset in ipairs({Vector3.new(-0.95, 0, -0.55), Vector3.new(0.95, 0, -0.55), Vector3.new(-0.95, 0, 0.55), Vector3.new(0.95, 0, 0.55)}) do
		box(furniture, "BlackCoilBurner" .. index, Vector3.new(-7.5, 5.28, 16.0) + offset, Vector3.new(0.10, 0.85, 0.85), colors.black, Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	end
	box(furniture, "WhiteRangeHood", Vector3.new(-7.5, 7.1, 17.0), Vector3.new(4.2, 1.25, 1.15), colors.ivory, Enum.Material.Metal, 0, false)
	box(furniture, "WhiteDishwasher", Vector3.new(-11.0, 2.65, 16.1), Vector3.new(2.3, 2.8, 2.25), colors.ivory, Enum.Material.Metal)
	box(furniture, "DishwasherControlStrip", Vector3.new(-11.0, 3.65, 14.93), Vector3.new(2.1, 0.38, 0.08), colors.black, Enum.Material.SmoothPlastic, 0, false)
	box(furniture, "CreamCoffeeMaker", Vector3.new(-10.4, 4.65, 16.0), Vector3.new(1.3, 1.45, 0.95), Color3.fromRGB(214, 205, 184), Enum.Material.SmoothPlastic, 0, false)
	box(furniture, "CoffeePot", Vector3.new(-10.4, 4.50, 15.46), Vector3.new(0.68, 0.72, 0.08), Color3.fromRGB(63, 52, 42), Enum.Material.Glass, 0.08, false)

	-- The breakfast pass-through stays behind a true six-stud kitchen doorway.
	box(furniture, "BreakfastBarBase", Vector3.new(-5.35, 2.45, 13.15), Vector3.new(0.75, 2.4, 4.30), Color3.fromRGB(88, 63, 45), Enum.Material.Wood)
	box(furniture, "CreamBreakfastBarTop", Vector3.new(-5.05, 3.82, 13.15), Vector3.new(1.85, 0.30, 4.75), Color3.fromRGB(218, 208, 181), Enum.Material.Marble)
	for index, z in ipairs({11.8, 13.1, 14.4}) do
		makeMug(furniture, "AmberTumbler" .. index, Vector3.new(-4.65, 4.38, z), Color3.fromRGB(176, 113, 43))
	end
	makeTable(furniture, "KitchenDinetteTable", Vector3.new(-13.6, FLOOR_Y, 6.6), Vector3.new(4.6, 0, 2.8), Color3.fromRGB(126, 87, 58), 0)
	makeDiningChair(furniture, "KitchenDinetteChairA", Vector3.new(-16.4, FLOOR_Y, 6.6), colors.tan, -90)
	makeDiningChair(furniture, "KitchenDinetteChairB", Vector3.new(-10.8, FLOOR_Y, 6.6), colors.tan, 90)
	box(furniture, "BreadLoaf", Vector3.new(-13.6, 4.1, 6.4), Vector3.new(1.8, 0.7, 0.85), Color3.fromRGB(189, 138, 79), Enum.Material.SmoothPlastic, 0, false, nil, "Ball")
	makeMug(furniture, "KitchenIcedTea", Vector3.new(-12.3, 4.45, 6.8), Color3.fromRGB(183, 121, 50))
	local phone = box(furniture, "BrownWallPhone", Vector3.new(-5.18, 6.75, 16.55), Vector3.new(0.32, 2.25, 0.95), Color3.fromRGB(87, 63, 49), Enum.Material.SmoothPlastic, 0, false)
	box(furniture, "PhoneHandset", Vector3.new(-4.95, 6.75, 16.55), Vector3.new(0.28, 2.55, 0.42), Color3.fromRGB(67, 49, 39), Enum.Material.SmoothPlastic, 0, false)
	phone:SetAttribute("Reference", "brown corded wall phone by kitchen pass-through")
	box(furniture, "FoldedIroningBoard", Vector3.new(-23.78, 5.1, 9.2), Vector3.new(0.24, 5.6, 1.45), Color3.fromRGB(132, 157, 154), Enum.Material.Fabric, 0, false, Vector3.new(0, 0, 7))

	-- George and Mary's bedroom: muted chintz, olive four-poster bed, blue quilt, blanket chest and mauve window treatment.
	local parentsBed = makeBed(furniture, "ParentsOliveFourPosterBed", Vector3.new(-16.2, FLOOR_Y, 28.0), 7.2, 7.0, Color3.fromRGB(67, 79, 49), Color3.fromRGB(98, 137, 164), 180)
	for index, position in ipairs({
		Vector3.new(-19.65, 5.1, 31.4), Vector3.new(-12.75, 5.1, 31.4),
		Vector3.new(-19.65, 4.0, 24.6), Vector3.new(-12.75, 4.0, 24.6),
	}) do
		box(parentsBed, "ParentsBedPost" .. index, position, Vector3.new(index < 3 and 7.2 or 5.0, 0.28, 0.28), Color3.fromRGB(61, 72, 46), Enum.Material.Wood, 0, true, Vector3.new(0, 0, 90), "Cylinder")
		box(parentsBed, "ParentsBedFinial" .. index, position + Vector3.new(0, index < 3 and 3.8 or 2.7, 0), Vector3.new(0.48, 0.48, 0.48), Color3.fromRGB(61, 72, 46), Enum.Material.Wood, 0, false, nil, "Ball")
	end
	for index, x in ipairs({-18.2, -16.2, -14.2}) do
		box(parentsBed, "ParentsBolsterPillow" .. index, Vector3.new(x, 3.25, 30.35), Vector3.new(1.7, 0.85, 1.15), Color3.fromRGB(107, 118, 81), Enum.Material.Fabric, 0, false)
	end
	for index, z in ipairs({25.7, 26.5, 27.3}) do
		box(parentsBed, "ParentsQuiltChevron" .. index, Vector3.new(-16.2, 2.98, z), Vector3.new(6.8, 0.05, 0.38), index % 2 == 0 and Color3.fromRGB(178, 59, 43) or Color3.fromRGB(224, 184, 94), Enum.Material.Fabric, 0, false, Vector3.new(0, index % 2 == 0 and 16 or -16, 0))
	end
	box(furniture, "ParentsBlanketChest", Vector3.new(-14.8, 2.15, 22.8), Vector3.new(4.8, 1.7, 1.6), colors.darkWood, Enum.Material.Wood)
	for stripe = -2, 2 do
		box(furniture, "ChestBlanketStripe" .. stripe, Vector3.new(-14.8 + stripe * 0.65, 3.04, 22.8), Vector3.new(0.34, 0.08, 1.45), stripe % 2 == 0 and colors.red or colors.olive, Enum.Material.Fabric, 0, false)
	end
	local parentsDresser = container("Model", "ParentsOliveWideDresser", furniture)
	box(parentsDresser, "DresserBody", Vector3.new(-22.15, 3.0, 29.7), Vector3.new(4.2, 3.2, 1.45), Color3.fromRGB(62, 70, 47), Enum.Material.Wood)
	for row = -1, 1 do
		for column = -1, 1, 2 do
			box(parentsDresser, "Drawer", Vector3.new(-22.15 + column * 0.95, 3.0 + row * 0.82, 28.92), Vector3.new(1.68, 0.68, 0.10), Color3.fromRGB(72, 80, 54), Enum.Material.Wood, 0, false)
			box(parentsDresser, "DrawerPull", Vector3.new(-22.15 + column * 0.95, 3.0 + row * 0.82, 28.84), Vector3.new(0.12, 0.32, 0.32), colors.black, Enum.Material.Metal, 0, false, Vector3.new(0, 90, 0), "Cylinder")
		end
	end
	makeInteriorWindow(furniture, "ParentsBedroomWindow", Vector3.new(-11.4, 7.1, 30.48), 4.3, 3.8, 0, Color3.fromRGB(137, 83, 91))
	makeLamp(furniture, "MaryBedsideLamp", Vector3.new(-11.2, FLOOR_Y, 29.0), Color3.fromRGB(230, 211, 174))
	makeRockingChair(furniture, "ParentsWoodRocker", Vector3.new(-10.8, FLOOR_Y, 25.7), Color3.fromRGB(122, 74, 61), 180)
	local texasMap = box(furniture, "FramedTexasMap", Vector3.new(-22.9, 7.4, 30.48), Vector3.new(3.0, 2.2, 0.06), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	addTexture(texasMap, "VettedTexasRoadMap", Enum.NormalId.Front, 14895408993, 3, 2.2, 0)
	box(furniture, "TexasMapFrame", Vector3.new(-22.9, 7.4, 30.54), Vector3.new(3.35, 2.55, 0.08), colors.darkWood, Enum.Material.Wood, 0.30, false)

	-- Early shared twins' room from the 2017 set tour: matching walnut beds around a center window, science on the left, Missy's plush corner on the right.
	local sheldonBed = makeBed(furniture, "SheldonWalnutTwinBed", Vector3.new(-6.3, FLOOR_Y, 28.0), 3.35, 6.9, colors.darkWood, Color3.fromRGB(129, 126, 112), 180)
	local missyBed = makeBed(furniture, "MissyWalnutTwinBed", Vector3.new(4.5, FLOOR_Y, 28.0), 3.35, 6.9, colors.darkWood, Color3.fromRGB(192, 151, 139), 180)
	for index, x in ipairs({-7.75, -4.85, 3.05, 5.95}) do
		local bedModel = x < 0 and sheldonBed or missyBed
		box(bedModel, "TwinBedFinial" .. index, Vector3.new(x, 3.8, 31.4), Vector3.new(0.52, 0.52, 0.52), colors.darkWood, Enum.Material.Wood, 0, false, nil, "Ball")
	end
	local sheldonBlanket = furniture.SheldonWalnutTwinBed:FindFirstChild("Blanket")
	if sheldonBlanket then
		addTexture(sheldonBlanket, "SheldonGeometricBedspread", Enum.NormalId.Top, 3324666775, 2.2, 2.2, 0.42)
	end
	local missyBlanket = furniture.MissyWalnutTwinBed:FindFirstChild("Blanket")
	if missyBlanket then
		addTexture(missyBlanket, "MissyPinkFloralBedspread", Enum.NormalId.Top, 17243120291, 2.2, 2.2, 0.08)
	end
	local centerNightstand = container("Model", "GreenCenterNightstand", furniture)
	box(centerNightstand, "Body", Vector3.new(-0.55, 2.55, 29.35), Vector3.new(2.4, 2.2, 1.45), Color3.fromRGB(89, 103, 74), Enum.Material.Wood)
	for row = 1, 3 do
		box(centerNightstand, "Drawer" .. row, Vector3.new(-0.55, 1.75 + row * 0.55, 28.58), Vector3.new(2.05, 0.42, 0.08), Color3.fromRGB(100, 113, 82), Enum.Material.Wood, 0, false)
		box(centerNightstand, "Pull" .. row, Vector3.new(-0.55, 1.75 + row * 0.55, 28.50), Vector3.new(0.12, 0.28, 0.28), colors.metal, Enum.Material.Metal, 0, false, Vector3.new(0, 90, 0), "Cylinder")
	end
	makeInteriorWindow(furniture, "TwinsCenterWindow", Vector3.new(-0.55, 7.0, 30.47), 4.1, 3.9, 0, Color3.fromRGB(157, 151, 135))
	box(furniture, "SheldonMustardScienceShelf", Vector3.new(-8.55, 3.0, 25.0), Vector3.new(0.70, 3.6, 4.8), Color3.fromRGB(184, 145, 42), Enum.Material.Wood)
	for shelf = 1, 2 do
		box(furniture, "SheldonShelf" .. shelf, Vector3.new(-8.14, 2.35 + shelf * 1.15, 25.0), Vector3.new(0.75, 0.14, 4.35), Color3.fromRGB(211, 174, 54), Enum.Material.Wood, 0, false)
	end
	-- The later white/red computer hutch is intentionally omitted from this coherent Season 1–2 room.
	makeBooks(furniture, "SheldonScienceBooks", Vector3.new(-8.02, 3.15, 23.6), 8, Vector3.new(0, 0, 0.42), {colors.red, colors.blue, colors.olive, colors.tan})
	local periodicPoster = box(furniture, "PeriodicTablePoster", Vector3.new(-8.89, 6.7, 23.7), Vector3.new(0.05, 3.1, 2.45), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	addTexture(periodicPoster, "VettedPeriodicTable", Enum.NormalId.Right, 4770566702, 2.45, 3.1, 0)
	local shuttlePoster = box(furniture, "SpaceShuttleBlueprint", Vector3.new(-4.9, 7.0, 30.47), Vector3.new(2.6, 2.0, 0.05), Color3.fromRGB(42, 62, 94), Enum.Material.SmoothPlastic, 0, false)
	addTexture(shuttlePoster, "VettedShuttleBlueprint", Enum.NormalId.Front, 17571361065, 2.6, 2.0, 0)
	makeFramedArt(furniture, "EinsteinPoster", Vector3.new(-7.0, 7.4, 30.46), Vector2.new(2.1, 2.6), colors.black, Color3.fromRGB(180, 177, 161), "E = mc²\nALBERT\nEINSTEIN", 0)
	local yellowLampBase = Vector3.new(-7.95, 4.75, 26.35)
	beam(furniture, "YellowTaskLampArm", yellowLampBase, yellowLampBase + Vector3.new(0.5, 1.8, 0), 0.16, colors.yellow, Enum.Material.Metal, 0, false)
	box(furniture, "YellowTaskLampShade", yellowLampBase + Vector3.new(0.65, 1.95, 0), Vector3.new(0.9, 0.8, 0.8), colors.yellow, Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	addPointLight(furniture, "SheldonDeskBulb", yellowLampBase + Vector3.new(0.55, 1.7, 0), Color3.fromRGB(255, 210, 139), 0.8, 7)
	for index, z in ipairs({23.4, 24.9, 26.4}) do
		box(furniture, "ModelRocket" .. index, Vector3.new(-7.95, 4.8, z), Vector3.new(0.32, 1.5 + index * 0.18, 0.32), index % 2 == 0 and colors.red or colors.white, Enum.Material.SmoothPlastic, 0, false)
		box(furniture, "RocketNose" .. index, Vector3.new(-7.95, 5.7 + index * 0.09, z), Vector3.new(0.38, 0.38, 0.38), colors.red, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 45), "Wedge")
	end
	local missyChair = makeArmchair(furniture, "MissyPinkStuffedChair", Vector3.new(5.2, FLOOR_Y, 22.8), Color3.fromRGB(190, 137, 126), 170)
	for index, spec in ipairs({
		{Vector3.new(6.2, 4.15, 23.7), Color3.fromRGB(157, 161, 163)},
		{Vector3.new(5.5, 3.75, 23.15), Color3.fromRGB(216, 208, 189)},
		{Vector3.new(6.75, 3.7, 23.15), Color3.fromRGB(179, 137, 89)},
	}) do
		box(missyChair, "MissyPlushAnimal" .. index, spec[1], Vector3.new(0.85, 1.0, 0.85), spec[2], Enum.Material.Fabric, 0, false, nil, "Ball")
		box(missyChair, "PlushEarA" .. index, spec[1] + Vector3.new(-0.25, 0.55, 0), Vector3.new(0.28, 0.45, 0.28), spec[2], Enum.Material.Fabric, 0, false, nil, "Ball")
		box(missyChair, "PlushEarB" .. index, spec[1] + Vector3.new(0.25, 0.55, 0), Vector3.new(0.28, 0.45, 0.28), spec[2], Enum.Material.Fabric, 0, false, nil, "Ball")
	end
	for index, y in ipairs({5.0, 6.2, 7.4}) do
		box(furniture, "MissyStrawHat" .. index, Vector3.new(7.86, y, 27.8), Vector3.new(0.10, 1.2 + index * 0.15, 1.2 + index * 0.15), index % 2 == 0 and Color3.fromRGB(188, 142, 96) or Color3.fromRGB(215, 191, 137), Enum.Material.Fabric, 0, false, nil, "Cylinder")
	end

	-- Georgie's early-series football bedroom: powder-blue walls, Oilers colors, radio/cassettes, and teen clutter.
	-- The bed sits against the outside wall so the doorway side retains a broad avatar-sized aisle.
	local georgieBed = makeBed(furniture, "GeorgieWalnutBed", Vector3.new(16.2, FLOOR_Y, 26.8), 3.6, 6.9, colors.darkWood, Color3.fromRGB(142, 62, 50), 180)
	georgieBed.Frame.CanCollide = false
	georgieBed.Mattress.CanCollide = false
	-- A narrower invisible footprint prevents clipping through the bed center without eroding the doorway-side path.
	box(georgieBed, "AvatarCollisionFootprint", Vector3.new(16.55, 2.2, 27.0), Vector3.new(2.45, 2.3, 6.25), colors.darkWood, Enum.Material.SmoothPlastic, 1, true)
	for stripe = -2, 2 do
		box(georgieBed, "GeorgieBedStripe" .. stripe, Vector3.new(16.2 + stripe * 0.60, 3.02, 26.9), Vector3.new(0.22, 0.05, 5.0), stripe % 2 == 0 and Color3.fromRGB(57, 91, 137) or colors.ivory, Enum.Material.Fabric, 0, false)
	end
	box(furniture, "GeorgieNightstand", Vector3.new(10.0, 2.45, 28.9), Vector3.new(1.65, 2.15, 1.45), colors.wood, Enum.Material.Wood)
	box(furniture, "GeorgieClockRadio", Vector3.new(10.0, 3.85, 28.75), Vector3.new(1.45, 0.75, 0.85), colors.black, Enum.Material.SmoothPlastic, 0, false)
	addSurfaceText(furniture.GeorgieClockRadio, "ClockDisplay", Enum.NormalId.Front, "6:30", Color3.fromRGB(214, 58, 45), Color3.fromRGB(22, 24, 23), 16, Enum.Font.Code)
	local oilersPoster = box(furniture, "HoustonOilersPoster", Vector3.new(15.0, 7.15, 30.47), Vector3.new(3.4, 2.6, 0.05), Color3.fromRGB(92, 150, 190), Enum.Material.SmoothPlastic, 0, false)
	addTexture(oilersPoster, "VettedHoustonOilersHelmet", Enum.NormalId.Front, 16865890904, 3.4, 2.6, 0)
	box(furniture, "GeorgieFootball", Vector3.new(10.2, 2.15, 24.2), Vector3.new(1.15, 1.75, 1.15), Color3.fromRGB(121, 68, 40), Enum.Material.Fabric, 0, false, Vector3.new(0, 0, 90), "Ball")
	for index = 1, 6 do
		box(furniture, "GeorgieCassette" .. index, Vector3.new(10.5 + (index % 2) * 0.6, 1.75 + math.floor(index / 2) * 0.20, 29.9), Vector3.new(0.52, 0.14, 0.85), index % 2 == 0 and colors.red or colors.blue, Enum.Material.SmoothPlastic, 0, false)
	end
	makeFramedArt(furniture, "GeorgieTruckPoster", Vector3.new(10.2, 7.1, 30.46), Vector2.new(1.5, 2.5), colors.darkWood, Color3.fromRGB(172, 134, 88), "TEXAS\nTRUCKS", 0)
	box(furniture, "GeorgieBlueFootRug", Vector3.new(11.9, 1.42, 25.9), Vector3.new(3.8, 0.10, 4.6), Color3.fromRGB(91, 126, 151), Enum.Material.Fabric, 0, false)
	box(furniture, "GeorgieDenimJacket", Vector3.new(8.32, 5.75, 27.8), Vector3.new(0.10, 2.55, 1.45), Color3.fromRGB(70, 103, 129), Enum.Material.Fabric, 0, false)
	box(furniture, "GeorgieJacketLeftSleeve", Vector3.new(8.31, 5.65, 26.75), Vector3.new(0.12, 2.05, 0.52), Color3.fromRGB(64, 96, 123), Enum.Material.Fabric, 0, false, Vector3.new(-32, 0, 0))
	box(furniture, "GeorgieJacketRightSleeve", Vector3.new(8.31, 5.65, 28.85), Vector3.new(0.12, 2.05, 0.52), Color3.fromRGB(64, 96, 123), Enum.Material.Fabric, 0, false, Vector3.new(32, 0, 0))
	beam(furniture, "GeorgieWoodHanger", Vector3.new(8.24, 7.32, 26.65), Vector3.new(8.24, 7.32, 28.95), 0.08, colors.darkWood, Enum.Material.Wood, 0, false)
	for hookIndex, hookY in ipairs({7.45, 6.85}) do
		box(furniture, "GeorgieCoatHook" .. hookIndex, Vector3.new(8.25, hookY, 27.8), Vector3.new(0.20, 0.18, 0.18), colors.metal, Enum.Material.Metal, 0, false)
	end

	-- Family bathroom: coral botanical paper, oxblood tile vanity, black-tile shower, blue towels and braided rug.
	-- Each fixture has its own wall zone and the toilet faces the center aisle instead of into a wall.
	local bathroomVanity = container("Model", "OxbloodTileBathroomVanity", furniture)
	box(bathroomVanity, "WhiteScallopedCabinet", Vector3.new(22.05, 2.65, 29.55), Vector3.new(5.2, 2.75, 1.65), colors.ivory, Enum.Material.Wood)
	local vanityTop = box(bathroomVanity, "OxbloodTileCounter", Vector3.new(22.05, 4.15, 29.55), Vector3.new(5.5, 0.30, 1.95), Color3.fromRGB(72, 31, 37), Enum.Material.Slate)
	for x = 19.65, 24.45, 0.68 do
		box(bathroomVanity, "VanityGrout", Vector3.new(x, 4.31, 29.55), Vector3.new(0.035, 0.02, 1.85), Color3.fromRGB(141, 102, 101), Enum.Material.SmoothPlastic, 0, false)
	end
	box(bathroomVanity, "CreamSinkBasin", Vector3.new(22.05, 4.33, 29.45), Vector3.new(1.7, 0.20, 1.25), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	for index, x in ipairs({21.32, 22.05, 22.78}) do
		box(bathroomVanity, "ChromeTap" .. index, Vector3.new(x, 4.67, 29.88), Vector3.new(0.55, 0.15, 0.15), colors.metal, Enum.Material.Metal, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	end
	for index = 1, 7 do
		box(bathroomVanity, "Scallop" .. index, Vector3.new(19.55 + index * 0.63, 3.55, 28.68), Vector3.new(0.61, 0.58, 0.18), colors.ivory, Enum.Material.Wood, 0, false, nil, "Ball")
	end
	box(bathroomVanity, "MedicineCabinetMirror", Vector3.new(22.05, 7.0, 30.47), Vector3.new(3.2, 3.4, 0.08), Color3.fromRGB(185, 200, 198), Enum.Material.Glass, 0.10, false)
	box(bathroomVanity, "MirrorFrame", Vector3.new(22.05, 7.0, 30.54), Vector3.new(3.55, 3.75, 0.08), colors.metal, Enum.Material.Metal, 0.45, false)
	addPointLight(bathroomVanity, "MirrorVanityLight", Vector3.new(22.05, 9.0, 30.15), Color3.fromRGB(255, 222, 177), 0.8, 7)
	box(bathroomVanity, "IvorySoapDish", Vector3.new(23.65, 4.48, 29.30), Vector3.new(0.85, 0.12, 0.55), colors.ivory, Enum.Material.SmoothPlastic, 0, false)
	box(bathroomVanity, "AmberHandSoap", Vector3.new(23.65, 4.70, 29.30), Vector3.new(0.40, 0.42, 0.34), Color3.fromRGB(188, 132, 77), Enum.Material.Glass, 0.15, false)
	box(bathroomVanity, "ToothbrushCup", Vector3.new(20.35, 4.65, 29.35), Vector3.new(0.42, 0.58, 0.42), colors.ivory, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	for brushIndex, brushX in ipairs({20.25, 20.42}) do
		box(bathroomVanity, "Toothbrush" .. brushIndex, Vector3.new(brushX, 5.15, 29.35), Vector3.new(0.08, 0.90, 0.08), brushIndex == 1 and colors.blue or colors.red, Enum.Material.SmoothPlastic, 0, false)
	end
	local shower = container("Model", "BlackTileFrostedShower", furniture)
	box(shower, "BackTile", Vector3.new(27.05, 5.7, 30.25), Vector3.new(3.10, 8.4, 0.35), Color3.fromRGB(38, 31, 31), Enum.Material.Slate)
	box(shower, "RightTile", Vector3.new(28.55, 5.7, 28.25), Vector3.new(0.30, 8.4, 4.15), Color3.fromRGB(38, 31, 31), Enum.Material.Slate)
	box(shower, "LeftTileJamb", Vector3.new(25.55, 5.7, 28.25), Vector3.new(0.30, 8.4, 4.15), Color3.fromRGB(38, 31, 31), Enum.Material.Slate)
	box(shower, "FrostedGlassDoor", Vector3.new(27.05, 5.7, 26.25), Vector3.new(2.55, 7.5, 0.16), Color3.fromRGB(181, 194, 192), Enum.Material.Glass, 0.42, false)
	box(shower, "ShowerThreshold", Vector3.new(27.05, 1.65, 28.25), Vector3.new(3.10, 0.45, 4.15), Color3.fromRGB(38, 31, 31), Enum.Material.Slate)
	beam(shower, "ChromeShowerPipe", Vector3.new(27.75, 7.8, 30.0), Vector3.new(27.75, 8.5, 29.5), 0.12, colors.metal, Enum.Material.Metal, 0, false)
	box(shower, "BlueShampooBottle", Vector3.new(27.85, 2.2, 29.75), Vector3.new(0.38, 0.95, 0.38), Color3.fromRGB(76, 134, 157), Enum.Material.SmoothPlastic, 0, false)
	box(shower, "IvoryConditionerBottle", Vector3.new(27.35, 2.05, 29.75), Vector3.new(0.40, 0.72, 0.40), colors.ivory, Enum.Material.SmoothPlastic, 0, false)

	local toilet = container("Model", "SideFacingIvoryToilet", furniture)
	box(toilet, "WhiteToiletTank", Vector3.new(28.0, 3.15, 23.8), Vector3.new(1.10, 2.6, 2.10), colors.ivory, Enum.Material.SmoothPlastic, 0, true)
	box(toilet, "TankLid", Vector3.new(28.0, 4.52, 23.8), Vector3.new(1.22, 0.16, 2.22), Color3.fromRGB(229, 226, 212), Enum.Material.SmoothPlastic, 0, false)
	box(toilet, "WhiteToiletBowl", Vector3.new(26.85, 1.95, 23.8), Vector3.new(2.25, 1.25, 1.95), colors.ivory, Enum.Material.SmoothPlastic, 0, true, nil, "Ball")
	-- Four bars form a true open seat ring; there is no solid disk fused through the bowl.
	box(toilet, "ToiletSeatLeftRail", Vector3.new(26.85, 2.63, 22.96), Vector3.new(1.95, 0.12, 0.20), Color3.fromRGB(221, 218, 205), Enum.Material.SmoothPlastic, 0, false)
	box(toilet, "ToiletSeatRightRail", Vector3.new(26.85, 2.63, 24.64), Vector3.new(1.95, 0.12, 0.20), Color3.fromRGB(221, 218, 205), Enum.Material.SmoothPlastic, 0, false)
	box(toilet, "ToiletSeatFront", Vector3.new(25.90, 2.63, 23.8), Vector3.new(0.20, 0.12, 1.48), Color3.fromRGB(221, 218, 205), Enum.Material.SmoothPlastic, 0, false)
	box(toilet, "ToiletSeatBack", Vector3.new(27.80, 2.63, 23.8), Vector3.new(0.20, 0.12, 1.48), Color3.fromRGB(221, 218, 205), Enum.Material.SmoothPlastic, 0, false)
	box(toilet, "ChromeFlushHandle", Vector3.new(27.40, 3.72, 22.68), Vector3.new(0.42, 0.12, 0.12), colors.metal, Enum.Material.Metal, 0, false)

	box(furniture, "BlueBathTowel", Vector3.new(28.72, 5.85, 25.05), Vector3.new(0.10, 2.4, 1.75), Color3.fromRGB(132, 174, 188), Enum.Material.Fabric, 0, false)
	beam(furniture, "ChromeTowelBar", Vector3.new(28.52, 7.15, 24.05), Vector3.new(28.52, 7.15, 26.05), 0.10, colors.metal, Enum.Material.Metal, 0, false)
	box(furniture, "BraidedOvalBathRug", Vector3.new(22.35, 1.42, 25.4), Vector3.new(0.10, 3.0, 4.4), Color3.fromRGB(111, 55, 62), Enum.Material.Fabric, 0, false, Vector3.new(0, 0, 90), "Cylinder")
	for index = -3, 3 do
		box(furniture, "BathroomHeaterVent" .. index, Vector3.new(19.24, 3.4 + index * 0.35, 28.0), Vector3.new(0.06, 0.12, 1.5), colors.metal, Enum.Material.Metal, 0, false)
	end
	makeFramedArt(furniture, "BathroomBotanicalPrint", Vector3.new(19.24, 7.3, 23.8), Vector2.new(1.5, 2.0), colors.tan, Color3.fromRGB(218, 211, 190), "WILDFLOWERS", -90)

	-- Hall set dressing: clustered family photographs and linen-cabinet details without narrowing the walkway.
	for index, spec in ipairs({
		{Vector3.new(-17.0, 6.6, 21.08), Vector2.new(1.1, 1.4)},
		{Vector3.new(-15.4, 7.1, 21.08), Vector2.new(1.3, 1.0)},
		{Vector3.new(4.0, 6.7, 21.08), Vector2.new(1.0, 1.35)},
		{Vector3.new(6.0, 7.2, 21.08), Vector2.new(1.4, 1.0)},
		{Vector3.new(15.4, 6.9, 21.08), Vector2.new(1.2, 1.5)},
	}) do
		makeFramedArt(furniture, "HallFamilyPhoto" .. index, spec[1], spec[2], index % 2 == 0 and colors.darkWood or colors.tan, Color3.fromRGB(155 + index * 8, 137 + index * 5, 113), "", 0)
	end

	-- Warm practical lighting keeps the dense set readable while retaining the show's amber late-1980s grade.
	for index, spec in ipairs({
		{Vector3.new(-7.5, 9.5, -4.6), 1.0, 15}, {Vector3.new(17.6, 9.5, -4.4), 1.0, 13},
		{Vector3.new(5.0, 9.5, 11), 1.0, 14}, {Vector3.new(-15.0, 9.5, 11), 1.1, 14},
		{Vector3.new(0, 9.5, 20.45), 0.7, 10}, {Vector3.new(-17, 9.5, 26), 0.75, 10},
		{Vector3.new(-0.5, 9.5, 26), 0.75, 10}, {Vector3.new(12.5, 9.5, 26), 0.65, 9},
		{Vector3.new(21, 9.5, 26), 0.65, 8},
	}) do
		addPointLight(furniture, "RoomCeilingLight" .. index, spec[1], Color3.fromRGB(255, 211, 155), spec[2], spec[3])
	end

	-- Detached two-car garage toward the rear with side-street driveway access.
	box(garage, "GarageFoundation", Vector3.new(-22.5, 0.75, 56), Vector3.new(21, 1.5, 23), colors.concrete, Enum.Material.Concrete)
	wallAlongZ(garage, "GarageLeftWall", -33, 44.5, 67.5, FLOOR_Y, 10.2, 0.7, colors.siding, Enum.Material.WoodPlanks)
	wallAlongZ(garage, "GarageRightWall", -12, 44.5, 67.5, FLOOR_Y, 10.2, 0.7, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(garage, "GarageBackWall", -33, -12, 67.5, FLOOR_Y, 10.2, 0.7, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(garage, "GarageFrontLeft", -33, -31.5, 44.5, FLOOR_Y, 10.2, 0.7, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(garage, "GarageFrontRight", -13.5, -12, 44.5, FLOOR_Y, 10.2, 0.7, colors.siding, Enum.Material.WoodPlanks)
	wallAlongX(garage, "GarageDoorHeader", -31.5, -13.5, 44.5, 8.5, 10.2, 0.7, colors.siding, Enum.Material.WoodPlanks)
	box(garage, "GarageDoor", Vector3.new(-22.5, 4.7, 44.62), Vector3.new(17.2, 7.2, 0.35), colors.ivory, Enum.Material.WoodPlanks, 0, false)
	for seam = -2, 2 do
		box(garage, "GarageDoorSeam", Vector3.new(-22.5, 4.7 + seam * 1.15, 44.39), Vector3.new(16.7, 0.10, 0.05), colors.cream, Enum.Material.Wood, 0, false)
	end
	box(garage, "GarageRoofFront", Vector3.new(-22.5, 12.2, 50.4), Vector3.new(23.5, 0.75, 13.5), colors.roofDark, Enum.Material.RoofShingles, 0, true, Vector3.new(-16, 0, 0))
	box(garage, "GarageRoofBack", Vector3.new(-22.5, 12.2, 61.6), Vector3.new(23.5, 0.75, 13.5), colors.roofDark, Enum.Material.RoofShingles, 0, true, Vector3.new(16, 0, 0))

	-- Mary's faux-wood station wagon parked in the side drive.
	local car = container("Model", "PeriodStationWagon", vehicles)
	box(car, "LowerBody", Vector3.new(-29, 2.35, -8), Vector3.new(6.2, 2.1, 12.5), colors.carBeige, Enum.Material.Metal)
	box(car, "Cabin", Vector3.new(-29, 4.25, -7.1), Vector3.new(5.7, 2.2, 7.6), colors.carBeige, Enum.Material.Metal)
	box(car, "Windshield", Vector3.new(-29, 4.35, -11.0), Vector3.new(5.0, 1.5, 0.15), colors.glass, Enum.Material.Glass, 0.28, false, Vector3.new(-12, 0, 0))
	for side = -1, 1, 2 do
		box(car, "WoodPanel", Vector3.new(-29 + side * 3.15, 2.7, -7.8), Vector3.new(0.12, 1.2, 8.6), colors.wood, Enum.Material.Wood, 0, false)
		for _, z in ipairs({-12.0, -4.0}) do
			box(car, "Wheel", Vector3.new(-29 + side * 3.0, 1.45, z), Vector3.new(1.0, 2.2, 2.2), colors.black, Enum.Material.Rubber, 0, true, nil, "Cylinder")
			box(car, "Hubcap", Vector3.new(-29 + side * 3.55, 1.45, z), Vector3.new(0.12, 1.0, 1.0), colors.metal, Enum.Material.Metal, 0, false, nil, "Cylinder")
		end
	end
	box(car, "FrontBumper", Vector3.new(-29, 1.85, -14.45), Vector3.new(6.4, 0.45, 0.45), colors.metal, Enum.Material.Metal)
	box(car, "RearBumper", Vector3.new(-29, 1.85, -1.55), Vector3.new(6.4, 0.45, 0.45), colors.metal, Enum.Material.Metal)

	-- Mature cedar and magnolia, with the recognizable tire swing.
	makeTree(landscaping, "FrontCedar", Vector3.new(17.5, 0.45, -34.0), 39, 11.5, colors.cedar, true)
	makeTree(landscaping, "FrontMagnolia", Vector3.new(-25.5, 0.45, -29.0), 31, 8.7, colors.leaf, false)
	cylinderBetween(landscaping, "SwingBranch", Vector3.new(17.5, 19.0, -34), Vector3.new(7.0, 18.0, -34), 1.2, colors.trunk, Enum.Material.Wood, 0, true)
	beam(landscaping, "SwingRopeLeft", Vector3.new(14.4, 18.0, -34), Vector3.new(14.4, 6.7, -34), 0.12, colors.tan, Enum.Material.Fabric, 0, false)
	beam(landscaping, "SwingRopeRight", Vector3.new(11.9, 17.9, -34), Vector3.new(11.9, 6.7, -34), 0.12, colors.tan, Enum.Material.Fabric, 0, false)
	local tire = container("Model", "TireSwing", landscaping)
	for index = 0, 11 do
		local angle = math.rad(index * 30)
		local x = 13.15 + math.cos(angle) * 1.8
		local y = 6.4 + math.sin(angle) * 1.8
		box(tire, "TireSegment", Vector3.new(x, y, -34), Vector3.new(1.25, 0.62, 0.85), colors.black, Enum.Material.Rubber, 0, true, Vector3.new(0, 0, index * 30 + 90))
	end

	-- Foundation shrubs, flowerbeds, side/rear fences, and recurring yard props.
	for index, spec in ipairs({
		{Vector3.new(-23.2, 1.45, -14.8), colors.leaf},
		{Vector3.new(-15.7, 1.45, -14.8), colors.leafLight},
		{Vector3.new(12.4, 1.45, -19.7), colors.leaf},
		{Vector3.new(22.4, 1.45, -19.7), colors.leafLight},
	}) do
		makeShrub(landscaping, "FoundationShrub" .. index, spec[1], 2.7, spec[2])
	end
	makePicketFence(landscaping, "RightPicketFence", 42.0, -11, 65)
	box(landscaping, "RearPrivacyFence", Vector3.new(0, 3.5, 84.5), Vector3.new(65, 7.0, 0.5), colors.darkWood, Enum.Material.WoodPlanks)
	for x = -32, 32, 4 do
		box(landscaping, "RearFencePost", Vector3.new(x, 3.7, 84.3), Vector3.new(0.45, 7.4, 0.65), colors.trunk, Enum.Material.Wood)
	end
	box(landscaping, "GreenYardBall", Vector3.new(10.8, 1.6, -28), Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(100, 164, 63), Enum.Material.SmoothPlastic, 0, true, nil, "Ball")
	local trike = container("Model", "RedYellowBigWheel", landscaping)
	for side = -1, 1, 2 do
		box(trike, "RearWheel", Vector3.new(14.2 + side * 1.05, 1.05, -24), Vector3.new(0.42, 1.3, 1.3), colors.black, Enum.Material.Rubber, 0, true, nil, "Cylinder")
	end
	box(trike, "FrontWheel", Vector3.new(14.2, 1.25, -26.3), Vector3.new(0.48, 2.0, 2.0), colors.black, Enum.Material.Rubber, 0, true, nil, "Cylinder")
	beam(trike, "RedFrameA", Vector3.new(14.2, 2.15, -25.7), Vector3.new(14.2, 1.8, -24), 0.24, colors.red, Enum.Material.Metal, 0, true)
	beam(trike, "RedFrameB", Vector3.new(14.2, 1.8, -24), Vector3.new(14.2, 2.55, -23.1), 0.24, colors.red, Enum.Material.Metal, 0, true)
	box(trike, "YellowSeat", Vector3.new(14.2, 2.65, -23.3), Vector3.new(1.6, 0.3, 1.0), colors.yellow, Enum.Material.SmoothPlastic)
	for index, x in ipairs({-10.5, -6.2}) do
		box(landscaping, "StripedLawnChairSeat" .. index, Vector3.new(x, 1.85, -30.5), Vector3.new(2.2, 0.28, 1.9), index == 1 and colors.yellow or colors.red, Enum.Material.Fabric)
		box(landscaping, "StripedLawnChairBack" .. index, Vector3.new(x, 3.2, -29.8), Vector3.new(2.2, 2.4, 0.28), index == 1 and colors.yellow or colors.red, Enum.Material.Fabric, 0, true, Vector3.new(-10, 0, 0))
	end

	-- Period neighborhood backdrop and Meemaw's stylized colonial across the street.
	makeSimpleHouse(neighborhood, "EastNeighborRanch", Vector3.new(67, 0, -4), 42, 28, Color3.fromRGB(177, 174, 143), Color3.fromRGB(104, 83, 67), false, 0)
	makeSimpleHouse(neighborhood, "WestNeighborRanch", Vector3.new(-78, 0, 6), 38, 26, Color3.fromRGB(154, 168, 153), Color3.fromRGB(91, 76, 67), false, 0)
	makeSimpleHouse(neighborhood, "MeemawColonialBackdrop", Vector3.new(24, 0, -105), 44, 26, Color3.fromRGB(189, 201, 199), Color3.fromRGB(79, 70, 71), true, 180)

	-- Sparse utility poles and wires finish the late-1980s Texas street silhouette.
	for index, x in ipairs({-70, 5, 80}) do
		box(neighborhood, "UtilityPole" .. index, Vector3.new(x, 11, -78), Vector3.new(22, 0.7, 0.7), colors.trunk, Enum.Material.Wood, 0, true, Vector3.new(0, 0, 90), "Cylinder")
		box(neighborhood, "UtilityCrossbar" .. index, Vector3.new(x, 19.0, -78), Vector3.new(7, 0.3, 0.3), colors.trunk, Enum.Material.Wood)
	end
	beam(neighborhood, "UtilityWireA", Vector3.new(-70, 19.7, -78), Vector3.new(5, 19.2, -78), 0.08, colors.black, Enum.Material.Metal, 0, false)
	beam(neighborhood, "UtilityWireB", Vector3.new(5, 19.2, -78), Vector3.new(80, 19.7, -78), 0.08, colors.black, Enum.Material.Metal, 0, false)

	-- The deeper private wing moves the house roof rearward; preserve a visible breezeway to the detached garage.
	garage:PivotTo(garage:GetPivot() + Vector3.new(0, 0, 6))

	-- Move the private wing back, then add real bedroom depth without stretching furniture into distorted shapes.
	for _, descendant in ipairs(interior:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local stationaryHallFinish = descendant.Name == "CrossHallFloor"
				or descendant.Name == "CrossHallCeiling"
				or descendant.Name == "HallLeftInteriorLining"
				or descendant.Name == "HallRightInteriorLining"
			if descendant.Position.Z >= 20.9 and not stationaryHallFinish then
				local alpha = math.clamp((descendant.Position.Z - 21.3) / (31 - 21.3), 0, 1)
				descendant.CFrame = descendant.CFrame + Vector3.new(0, 0, PRIVATE_WING_Z_SHIFT + alpha * PRIVATE_ROOM_EXTRA_DEPTH)
				if descendant.Size.Z > 5 then
					descendant.Size = descendant.Size + Vector3.new(0, 0, PRIVATE_ROOM_EXTRA_DEPTH)
				end
			end
		end
	end
	for _, object in ipairs(furniture:GetChildren()) do
		local position
		if object:IsA("Model") then
			position = object:GetPivot().Position
		elseif object:IsA("BasePart") then
			position = object.Position
		end
		if position and position.Z >= 20.9 then
			local alpha = math.clamp((position.Z - 21.3) / (31 - 21.3), 0, 1)
			local offset = Vector3.new(0, 0, PRIVATE_WING_Z_SHIFT + alpha * PRIVATE_ROOM_EXTRA_DEPTH)
			if object:IsA("Model") then
				object:PivotTo(object:GetPivot() + offset)
			else
				object.CFrame = object.CFrame + offset
			end
		end
	end

	-- Center all dining furniture in the enlarged projecting bay as one coordinated set.
	for _, object in ipairs(furniture:GetChildren()) do
		local position
		if object:IsA("Model") then
			position = object:GetPivot().Position
		elseif object:IsA("BasePart") then
			position = object.Position
		end
		if position and position.X > 10 and position.Z < 3.8 then
			local offset = Vector3.new(1.7, 0, -1.4)
			if object:IsA("Model") then
				object:PivotTo(object:GetPivot() + offset)
			else
				object.CFrame = object.CFrame + offset
			end
		end
	end

	-- A modest uniform scale makes the finished set comfortable for Roblox avatars while retaining proportions.
	for _, descendant in ipairs(house:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local rotation = descendant.CFrame - descendant.Position
			descendant.Size = descendant.Size * HOUSE_SCALE
			descendant.CFrame = CFrame.new(descendant.Position * HOUSE_SCALE) * rotation
		elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
			descendant.Range *= HOUSE_SCALE
		end
	end
	local scaledFrontClosed = CFrame.new(frontDoor:GetPivot().Position)
	frontDoor:SetAttribute("ClosedPivot", scaledFrontClosed)
	frontDoor:SetAttribute("OpenPivot", scaledFrontClosed * CFrame.Angles(0, math.rad(-102), 0))
	local scaledPatioClosed = CFrame.new(patioDoor:GetPivot().Position) * CFrame.Angles(0, math.rad(90), 0)
	patioDoor:SetAttribute("ClosedPivot", scaledPatioClosed)
	patioDoor:SetAttribute("OpenPivot", scaledPatioClosed * CFrame.Angles(0, math.rad(-98), 0))
	root:SetAttribute("HallMinZ", 18.1 * HOUSE_SCALE)
	root:SetAttribute("HallMaxZ", (21.3 + PRIVATE_WING_Z_SHIFT) * HOUSE_SCALE)
	root:SetAttribute("HouseMinX", -25 * HOUSE_SCALE)
	root:SetAttribute("HouseMaxX", RIGHT_EXTERIOR_X * HOUSE_SCALE)
end)

if not ok then
	root:Destroy()
	error(result)
end

root.Parent = Workspace
if previous then
	if existingSpawn and existingSpawn:IsDescendantOf(previous) then
		-- Preserve the one place-level respawn while the previous movable
		-- environment is replaced, then mount it under the new site below.
		existingSpawn.Parent = Workspace
	end
	previous:Destroy()
end
root.Name = ENVIRONMENT_NAME

-- Keep the default camera flexible outdoors, but physically confine it to the enclosed hall while the avatar is there.
StarterPlayer.CameraMinZoomDistance = 0.5
StarterPlayer.CameraMaxZoomDistance = 14
pcall(function()
	StarterPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
end)
local starterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if starterPlayerScripts then
	local previousCameraController = starterPlayerScripts:FindFirstChild("CooperHallCameraController")
	if previousCameraController then
		previousCameraController:Destroy()
	end
	local hallCameraController = Instance.new("LocalScript")
	hallCameraController.Name = "CooperHallCameraController"
	hallCameraController.Source = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NORMAL_MIN = 0.5
local NORMAL_MAX = 14
local HALL_MAX = 4.25
local HALL_MIN_ABOVE_FLOOR = 0.5
local HALL_MAX_ABOVE_FLOOR = 9.35
local BIND_NAME = "CooperHallCameraClamp"

local function restoreZoom()
	player.CameraMinZoomDistance = NORMAL_MIN
	player.CameraMaxZoomDistance = NORMAL_MAX
end

RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		restoreZoom()
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local house = environment and environment:FindFirstChild("CooperHouse")
	local hall = house and house:FindFirstChild("CrossHallFloor", true)
	if not rootPart or not house or not hall or not hall:IsA("BasePart") then
		restoreZoom()
		return
	end
	local hallMinZ = hall.Position.Z - hall.Size.Z * 0.5
	local hallMaxZ = hall.Position.Z + hall.Size.Z * 0.5
	local hallFloorTop = hall.CFrame:PointToWorldSpace(
		Vector3.new(0, hall.Size.Y * 0.5, 0)
	).Y
	local houseCF, houseSize = house:GetBoundingBox()
	local houseMinX = houseCF.Position.X - houseSize.X * 0.5
	local houseMaxX = houseCF.Position.X + houseSize.X * 0.5
	local position = rootPart.Position
	local inHall = position.X > houseMinX and position.X < houseMaxX
		and position.Z > hallMinZ and position.Z < hallMaxZ
	if not inHall then
		restoreZoom()
		return
	end
	player.CameraMinZoomDistance = NORMAL_MIN
	player.CameraMaxZoomDistance = HALL_MAX
	local cameraPosition = camera.CFrame.Position
	local clampedPosition = Vector3.new(
		math.clamp(cameraPosition.X, houseMinX + 0.5, houseMaxX - 0.5),
		math.clamp(
			cameraPosition.Y,
			hallFloorTop + HALL_MIN_ABOVE_FLOOR,
			hallFloorTop + HALL_MAX_ABOVE_FLOOR
		),
		math.clamp(cameraPosition.Z, hallMinZ + 0.35, hallMaxZ - 0.35)
	)
	if (clampedPosition - cameraPosition).Magnitude > 0.01 then
		camera.CFrame = CFrame.new(clampedPosition) * camera.CFrame.Rotation
	end
end)

script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(BIND_NAME)
	restoreZoom()
end)
]=]
	hallCameraController.Parent = starterPlayerScripts
end

local oldGrade = Lighting:FindFirstChild("CooperHouseColorGrade")
if oldGrade then
	oldGrade:Destroy()
end
-- Disable the template's strong generic post-effects so they do not stack with the calibrated house grade.
for _, legacyEffectName in ipairs({"Bloom", "SunRays"}) do
	local legacyEffect = Lighting:FindFirstChild(legacyEffectName)
	if legacyEffect and (legacyEffect:IsA("BloomEffect") or legacyEffect:IsA("SunRaysEffect")) then
		legacyEffect.Enabled = false
	end
end
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "CooperHouseColorGrade"
grade.Brightness = 0.015
grade.Contrast = 0.05
grade.Saturation = -0.04
grade.TintColor = Color3.fromRGB(255, 238, 216)
grade.Parent = Lighting
for _, effectName in ipairs({"CooperHouseBloom", "CooperHouseSunRays"}) do
	local oldEffect = Lighting:FindFirstChild(effectName)
	if oldEffect then oldEffect:Destroy() end
end
local bloom = Instance.new("BloomEffect")
bloom.Name = "CooperHouseBloom"
bloom.Intensity = 0.10
bloom.Size = 22
bloom.Threshold = 1.15
bloom.Parent = Lighting
local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "CooperHouseSunRays"
sunRays.Intensity = 0.025
sunRays.Spread = 0.65
sunRays.Parent = Lighting
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

local spawn = existingSpawn
if not spawn or not spawn.Parent then
	spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
end
local spawnSize = Vector3.new(6, 1, 6)
local spawnLocalOffset = Vector3.new(-5, 0, -63)
local cooperLot = site:FindFirstChild("CooperLot")
assert(cooperLot and cooperLot:IsA("BasePart"), "SiteAndStreet.CooperLot was not built")
local spawnUp = cooperLot.CFrame.UpVector.Unit
local horizontalSpawn = cooperLot.CFrame:PointToWorldSpace(spawnLocalOffset)
local spawnRaycastParams = RaycastParams.new()
spawnRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
spawnRaycastParams.FilterDescendantsInstances = { spawn }
pcall(function()
	spawnRaycastParams.RespectCanCollide = true
end)
local spawnSupport = Workspace:Raycast(
	horizontalSpawn + spawnUp * 12,
	-spawnUp * 24,
	spawnRaycastParams
)
local supportPosition = if spawnSupport
	then spawnSupport.Position
	else cooperLot.CFrame:PointToWorldSpace(Vector3.new(
		spawnLocalOffset.X,
		cooperLot.Size.Y * 0.5,
		spawnLocalOffset.Z
	))
local spawnPosition = supportPosition + spawnUp * (spawnSize.Y * 0.5 + 0.05)
spawn.Size = spawnSize
spawn.CFrame = CFrame.lookAt(
	spawnPosition,
	spawnPosition - cooperLot.CFrame.LookVector,
	spawnUp
)
spawn.Anchored = true
spawn.CanCollide = true
spawn.CanTouch = false
spawn.CanQuery = true
spawn.Enabled = true
spawn.Neutral = true
spawn.Duration = 0
spawn.AllowTeamChangeOnTouch = false
spawn.Transparency = 0.55
spawn.Color = colors.concrete
spawn.Material = Enum.Material.Concrete
spawn:SetAttribute("CooperSpawnLotLocalOffset", spawnLocalOffset)
spawn:SetAttribute("CooperSpawnRepairVersion", "2026-07-17.1")
spawn.Parent = site
for _, child in ipairs(spawn:GetDescendants()) do
	if child:IsA("Decal") then
		child.Transparency = 1
	end
end

local camera = Workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Custom
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 13.5, -76), Vector3.new(0, 6.2, -5))
	camera.FieldOfView = 52
end

ChangeHistoryService:SetWaypoint("Build Cooper House Environment")

local partCount = 0
local modelCount = 0
for _, descendant in ipairs(root:GetDescendants()) do
	if descendant:IsA("BasePart") then
		partCount += 1
	elseif descendant:IsA("Model") then
		modelCount += 1
	end
end

return {
	success = true,
	environment = root:GetFullName(),
	parts = partCount,
	models = modelCount,
	spawn = spawn and tostring(spawn.Position) or "unchanged",
	camera = camera and tostring(camera.CFrame.Position) or "unchanged",
	message = "Cooper house exterior, playable interior, yard, garage, period props, and neighborhood backdrop created",
}
