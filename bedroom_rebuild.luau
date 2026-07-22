-- Young Sheldon Cooper-house bedroom rebuild.
-- Intended to run in Roblox Studio edit context through the Roblox MCP plugin.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment, "CooperHouseEnvironment was not found")
local house = environment:FindFirstChild("CooperHouse")
assert(house, "CooperHouse was not found")
local props = house:FindFirstChild("FurnitureAndProps")
assert(props, "FurnitureAndProps was not found")

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"YoungSheldonBedroomRebuild",
		"Rebuild Cooper family bedrooms"
	)
end)

local function smooth(p)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function makePart(parent, name, size, cf, color, material, collide, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.fromRGB(120, 90, 60)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = collide == true
	p.CanQuery = true
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	smooth(p)
	p.Parent = parent
	return p
end

local function makeSeat(parent, name, size, cf)
	local s = Instance.new("Seat")
	s.Name = name
	s.Size = size
	s.CFrame = cf
	s.Anchored = true
	s.CanCollide = false
	s.CanTouch = true
	s.CanQuery = true
	s.Transparency = 1
	s.Disabled = false
	s.Parent = parent
	smooth(s)
	return s
end

local function makeSurfaceSign(part, face, titleText, subtitleText, background, foreground)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Artwork"
	surface.Face = face
	surface.CanvasSize = Vector2.new(700, 420)
	surface.LightInfluence = 0.15
	surface.Brightness = 1.15
	surface.Parent = part

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = background
	bg.BorderSizePixel = 0
	bg.Parent = surface

	local border = Instance.new("UIStroke")
	border.Thickness = 16
	border.Color = Color3.fromRGB(73, 43, 25)
	border.Parent = bg

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.08)
	title.Size = UDim2.fromScale(0.88, subtitleText and 0.56 or 0.82)
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextColor3 = foreground
	title.TextScaled = true
	title.TextWrapped = true
	title.Parent = bg

	if subtitleText then
		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Subtitle"
		subtitle.BackgroundTransparency = 1
		subtitle.Position = UDim2.fromScale(0.08, 0.67)
		subtitle.Size = UDim2.fromScale(0.84, 0.22)
		subtitle.Font = Enum.Font.GothamMedium
		subtitle.Text = subtitleText
		subtitle.TextColor3 = foreground:Lerp(Color3.new(1, 1, 1), 0.18)
		subtitle.TextScaled = true
		subtitle.TextWrapped = true
		subtitle.Parent = bg
	end

	return surface
end

local function destroyTopLevel(name)
	local item = props:FindFirstChild(name)
	if item then
		item:Destroy()
	end
end

local oldDetail = props:FindFirstChild("YoungSheldonBedroomDetails_V2")
if oldDetail then
	oldDetail:Destroy()
end
local detail = Instance.new("Model")
detail.Name = "YoungSheldonBedroomDetails_V2"
detail.Parent = props
detail:SetAttribute("BuildVersion", 2)
detail:SetAttribute("Theme", "Young Sheldon / late 1980s Medford")

-- Parents' room: simplify the visually broken four-poster pieces and turn the rocker
-- into a deliberate sewing/reading corner instead of leaving it beside the bed.
local parentsRocker = props:FindFirstChild("ParentsWoodRocker")
if parentsRocker and parentsRocker:IsA("Model") then
	local pivot = parentsRocker:GetPivot()
	parentsRocker:PivotTo(CFrame.lookAt(
		Vector3.new(-24.20, pivot.Position.Y, 31.20),
		Vector3.new(-18.00, pivot.Position.Y, 35.30)
	))
end
destroyTopLevel("MaryBedsideLamp")
for _, name in ipairs({
	"ChestBlanketStripe-2", "ChestBlanketStripe-1", "ChestBlanketStripe0",
	"ChestBlanketStripe1", "ChestBlanketStripe2",
}) do
	destroyTopLevel(name)
end

local parentsBed = props:FindFirstChild("ParentsOliveFourPosterBed")
if parentsBed then
	for _, child in ipairs(parentsBed:GetChildren()) do
		if child.Name:match("^ParentsBedPost")
			or child.Name:match("^ParentsBedFinial")
			or child.Name:match("^ParentsQuiltChevron") then
			child:Destroy()
		end
	end
	local blanket = parentsBed:FindFirstChild("Blanket")
	if blanket and blanket:IsA("BasePart") then
		blanket.Color = Color3.fromRGB(82, 108, 126)
		blanket.Material = Enum.Material.Fabric
	end
	local headboard = parentsBed:FindFirstChild("Headboard")
	if headboard and headboard:IsA("BasePart") then
		headboard.Color = Color3.fromRGB(78, 91, 59)
		headboard.Material = Enum.Material.Wood
	end
	local frame = parentsBed:FindFirstChild("Frame")
	if frame and frame:IsA("BasePart") then
		frame.Color = Color3.fromRGB(78, 91, 59)
		frame.Material = Enum.Material.Wood
	end
end

local parents = Instance.new("Model")
parents.Name = "ParentsRoomStoryProps"
parents.Parent = detail

local sewingBasket = Instance.new("Model")
sewingBasket.Name = "MarySewingBasket"
sewingBasket.Parent = parents
makePart(sewingBasket, "Basket", Vector3.new(1.35, 0.75, 1.05), CFrame.new(-22.55, 1.90, 31.35), Color3.fromRGB(151, 104, 56), Enum.Material.Wood, true)
makePart(sewingBasket, "FoldedFabric", Vector3.new(1.12, 0.28, 0.84), CFrame.new(-22.55, 2.40, 31.35), Color3.fromRGB(183, 111, 118), Enum.Material.Fabric, false)
makePart(sewingBasket, "HandleLeft", Vector3.new(0.15, 0.95, 0.15), CFrame.new(-23.05, 2.65, 31.35), Color3.fromRGB(112, 73, 39), Enum.Material.Wood, false)
makePart(sewingBasket, "HandleRight", Vector3.new(0.15, 0.95, 0.15), CFrame.new(-22.05, 2.65, 31.35), Color3.fromRGB(112, 73, 39), Enum.Material.Wood, false)
makePart(sewingBasket, "HandleTop", Vector3.new(1.15, 0.15, 0.15), CFrame.new(-22.55, 3.10, 31.35), Color3.fromRGB(112, 73, 39), Enum.Material.Wood, false)

makePart(
	parents,
	"FoldedPatchworkQuilt",
	Vector3.new(7.15, 0.18, 1.35),
	CFrame.new(-17.5, 3.36, 34.93),
	Color3.fromRGB(157, 82, 55),
	Enum.Material.Fabric,
	false
)
makePart(
	parents,
	"QuiltCreamBand",
	Vector3.new(7.18, 0.04, 0.23),
	CFrame.new(-17.5, 3.47, 34.93),
	Color3.fromRGB(225, 207, 169),
	Enum.Material.Fabric,
	false
)

local nightstand = Instance.new("Model")
nightstand.Name = "MaryNightstand"
nightstand.Parent = parents
makePart(nightstand, "Body", Vector3.new(2.15, 2.25, 1.85), CFrame.new(-12.25, 2.63, 39.25), Color3.fromRGB(105, 62, 35), Enum.Material.Wood, true)
makePart(nightstand, "Top", Vector3.new(2.35, 0.18, 2.02), CFrame.new(-12.25, 3.84, 39.25), Color3.fromRGB(130, 78, 41), Enum.Material.Wood, true)
makePart(nightstand, "Drawer", Vector3.new(1.78, 0.65, 0.12), CFrame.new(-12.25, 3.17, 38.30), Color3.fromRGB(121, 70, 38), Enum.Material.Wood, false)
makePart(nightstand, "BrassPull", Vector3.new(0.12, 0.12, 0.50), CFrame.new(-12.25, 3.17, 38.20) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(191, 145, 67), Enum.Material.Metal, false, 0, Enum.PartType.Cylinder)

local lamp = Instance.new("Model")
lamp.Name = "MaryFloralTableLamp"
lamp.Parent = parents
makePart(lamp, "Base", Vector3.new(0.24, 0.78, 0.78), CFrame.new(-12.75, 4.01, 39.25) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(205, 190, 147), Enum.Material.SmoothPlastic, true, 0, Enum.PartType.Cylinder)
makePart(lamp, "Stem", Vector3.new(1.10, 0.12, 0.12), CFrame.new(-12.75, 4.62, 39.25) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(176, 131, 59), Enum.Material.Metal, true, 0, Enum.PartType.Cylinder)
makePart(lamp, "Shade", Vector3.new(0.80, 1.15, 1.15), CFrame.new(-12.75, 5.32, 39.25) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(225, 188, 135), Enum.Material.Fabric, false, 0, Enum.PartType.Cylinder)
local lampBulb = makePart(lamp, "WarmBulb", Vector3.new(0.28, 0.28, 0.28), CFrame.new(-12.75, 5.10, 39.25), Color3.fromRGB(255, 225, 154), Enum.Material.Neon, false)
local point = Instance.new("PointLight")
point.Name = "WarmBedroomGlow"
point.Color = Color3.fromRGB(255, 213, 155)
point.Brightness = 1.1
point.Range = 10
point.Shadows = true
point.Parent = lampBulb

local bible = makePart(parents, "MaryBible", Vector3.new(0.95, 0.18, 1.25), CFrame.new(-11.95, 4.05, 39.20), Color3.fromRGB(45, 35, 30), Enum.Material.Fabric, false)
makeSurfaceSign(bible, Enum.NormalId.Top, "HOLY BIBLE", nil, Color3.fromRGB(48, 36, 30), Color3.fromRGB(218, 178, 74))

local weddingFrame = makePart(parents, "CooperWeddingPhoto", Vector3.new(0.14, 2.55, 3.15), CFrame.new(-26.43, 7.35, 35.20), Color3.fromRGB(83, 48, 29), Enum.Material.Wood, false)
weddingFrame:SetAttribute("PhotoSlot", "ZoePerry")
local crossVertical = makePart(parents, "MaryWallCrossVertical", Vector3.new(0.10, 1.65, 0.22), CFrame.new(-26.34, 8.25, 39.00), Color3.fromRGB(92, 53, 31), Enum.Material.Wood, false)
local crossHorizontal = makePart(parents, "MaryWallCrossHorizontal", Vector3.new(0.10, 0.22, 1.05), CFrame.new(-26.34, 8.50, 39.00), Color3.fromRGB(92, 53, 31), Enum.Material.Wood, false)
crossVertical.CFrame = crossVertical.CFrame * CFrame.Angles(0, 0, 0)
crossHorizontal.CFrame = crossHorizontal.CFrame * CFrame.Angles(0, 0, 0)

local georgeBottle = Instance.new("Model")
georgeBottle.Name = "GeorgeLoneStarBeerBottle"
georgeBottle.Parent = parents
local bottleBase = Vector3.new(-22.45, 5.02, 40.37)
local bottleBody = makePart(
	georgeBottle,
	"BottleBody",
	Vector3.new(0.90, 0.40, 0.40),
	CFrame.new(bottleBase + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Color3.fromRGB(132, 67, 24),
	Enum.Material.Glass,
	false,
	0.12,
	Enum.PartType.Cylinder
)
makePart(georgeBottle, "BottleShoulder", Vector3.new(0.46, 0.46, 0.46), CFrame.new(bottleBase + Vector3.new(0, 0.90, 0)), Color3.fromRGB(132, 67, 24), Enum.Material.Glass, false, 0.12, Enum.PartType.Ball)
makePart(georgeBottle, "BottleNeck", Vector3.new(0.42, 0.20, 0.20), CFrame.new(bottleBase + Vector3.new(0, 1.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(132, 67, 24), Enum.Material.Glass, false, 0.12, Enum.PartType.Cylinder)
makePart(georgeBottle, "BottleCap", Vector3.new(0.12, 0.23, 0.23), CFrame.new(bottleBase + Vector3.new(0, 1.39, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(206, 211, 203), Enum.Material.Metal, false, 0, Enum.PartType.Cylinder)
local bottleLabel = makePart(georgeBottle, "LoneStarBottleLabel", Vector3.new(0.34, 0.48, 0.025), CFrame.new(bottleBase + Vector3.new(0, 0.54, -0.215)), Color3.fromRGB(241, 235, 209), Enum.Material.SmoothPlastic, false)
makeSurfaceSign(bottleLabel, Enum.NormalId.Front, "LONE", "STAR", Color3.fromRGB(31, 78, 127), Color3.fromRGB(245, 244, 224))
georgeBottle.PrimaryPart = bottleBody

-- Sheldon and Missy's shared room: replace the exploded shelf with a readable 1980s computer station.
for _, name in ipairs({
	"SheldonMustardScienceShelf", "SheldonScienceBooks", "SheldonShelf1", "SheldonShelf2",
	"ModelRocket1", "ModelRocket2", "ModelRocket3",
	"RocketNose1", "RocketNose2", "RocketNose3",
	"YellowTaskLampArm", "YellowTaskLampShade", "SheldonDeskBulb",
	"EinsteinPoster",
}) do
	destroyTopLevel(name)
end

local twins = Instance.new("Model")
twins.Name = "SheldonAndMissyRoom"
twins.Parent = detail

local desk = Instance.new("Model")
desk.Name = "Sheldon1980sComputerDesk"
desk.Parent = twins
makePart(desk, "Desktop", Vector3.new(5.25, 0.28, 1.92), CFrame.new(-5.25, 3.85, 29.45), Color3.fromRGB(111, 67, 39), Enum.Material.Wood, true)
makePart(desk, "LeftPedestal", Vector3.new(1.15, 2.35, 1.72), CFrame.new(-7.15, 2.57, 29.45), Color3.fromRGB(100, 59, 34), Enum.Material.Wood, true)
makePart(desk, "RightLeg", Vector3.new(0.28, 2.35, 1.72), CFrame.new(-3.05, 2.57, 29.45), Color3.fromRGB(100, 59, 34), Enum.Material.Wood, true)
for i = 0, 2 do
	makePart(desk, "Drawer" .. tostring(i + 1), Vector3.new(0.92, 0.54, 0.11), CFrame.new(-7.15, 3.28 - i * 0.68, 30.33), Color3.fromRGB(123, 74, 42), Enum.Material.Wood, false)
	makePart(desk, "DrawerPull" .. tostring(i + 1), Vector3.new(0.10, 0.10, 0.38), CFrame.new(-7.15, 3.28 - i * 0.68, 30.42) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(179, 131, 62), Enum.Material.Metal, false, 0, Enum.PartType.Cylinder)
end

makePart(desk, "BeigeComputerBase", Vector3.new(2.65, 0.55, 1.45), CFrame.new(-5.15, 4.25, 29.45), Color3.fromRGB(210, 198, 163), Enum.Material.SmoothPlastic, true)
makePart(desk, "DiskDriveSlot", Vector3.new(0.95, 0.10, 0.06), CFrame.new(-5.40, 4.28, 30.21), Color3.fromRGB(45, 48, 43), Enum.Material.Metal, false)
makePart(desk, "PowerLight", Vector3.new(0.10, 0.10, 0.08), CFrame.new(-4.20, 4.28, 30.22), Color3.fromRGB(90, 220, 109), Enum.Material.Neon, false)
makePart(desk, "CRTCase", Vector3.new(2.65, 1.95, 1.45), CFrame.new(-5.15, 5.48, 29.45), Color3.fromRGB(218, 207, 175), Enum.Material.SmoothPlastic, true)
local computerScreen = makePart(desk, "GreenPhosphorScreen", Vector3.new(1.92, 1.16, 0.08), CFrame.new(-5.15, 5.53, 30.21), Color3.fromRGB(13, 38, 24), Enum.Material.Glass, false)
makeSurfaceSign(computerScreen, Enum.NormalId.Back, "C:\\> TRAIN.EXE", "CALCULATING BRISKET TRAJECTORY...", Color3.fromRGB(8, 28, 17), Color3.fromRGB(98, 238, 128))
makePart(desk, "Keyboard", Vector3.new(2.85, 0.16, 0.88), CFrame.new(-5.15, 4.05, 30.38) * CFrame.Angles(math.rad(-6), 0, 0), Color3.fromRGB(212, 202, 169), Enum.Material.SmoothPlastic, false)
for row = 0, 2 do
	for col = 0, 8 do
		makePart(desk, string.format("Key_%d_%d", row, col), Vector3.new(0.19, 0.05, 0.15), CFrame.new(-6.04 + col * 0.23, 4.18 + row * 0.02, 30.16 + row * 0.22), Color3.fromRGB(78, 74, 64), Enum.Material.SmoothPlastic, false)
	end
end

local sheldonChair = Instance.new("Model")
sheldonChair.Name = "SheldonDeskChair"
sheldonChair.Parent = twins
makePart(sheldonChair, "SeatCushion", Vector3.new(1.72, 0.24, 1.55), CFrame.new(-5.15, 3.05, 32.05), Color3.fromRGB(87, 100, 77), Enum.Material.Fabric, true)
makePart(sheldonChair, "Back", Vector3.new(1.72, 1.85, 0.24), CFrame.new(-5.15, 4.08, 32.76), Color3.fromRGB(82, 91, 69), Enum.Material.Fabric, true)
for _, offset in ipairs({
	Vector3.new(-0.68, 2.05, -0.58), Vector3.new(0.68, 2.05, -0.58),
	Vector3.new(-0.68, 2.05, 0.58), Vector3.new(0.68, 2.05, 0.58),
}) do
	makePart(sheldonChair, "Leg", Vector3.new(0.18, 1.85, 0.18), CFrame.new(-5.15 + offset.X, offset.Y, 32.05 + offset.Z), Color3.fromRGB(82, 49, 30), Enum.Material.Wood, true)
end
makeSeat(sheldonChair, "FunctionalSeat", Vector3.new(1.45, 0.22, 1.32), CFrame.new(-5.15, 3.30, 32.05))

local einsteinFrame = makePart(twins, "EinsteinPortrait", Vector3.new(3.55, 3.20, 0.16), CFrame.new(-6.80, 7.55, 41.84), Color3.fromRGB(66, 42, 28), Enum.Material.Wood, false)
local einsteinGui = makeSurfaceSign(einsteinFrame, Enum.NormalId.Front, "ALBERT EINSTEIN", "E = mc²", Color3.fromRGB(229, 219, 189), Color3.fromRGB(40, 39, 35))
local einsteinBg = einsteinGui:FindFirstChild("Background")
if einsteinBg then
	local title = einsteinBg:FindFirstChild("Title")
	if title then
		title.Position = UDim2.fromScale(0.08, 0.03)
		title.Size = UDim2.fromScale(0.84, 0.16)
	end
	local subtitle = einsteinBg:FindFirstChild("Subtitle")
	if subtitle then
		subtitle.Position = UDim2.fromScale(0.20, 0.76)
		subtitle.Size = UDim2.fromScale(0.60, 0.16)
	end

	local portraitHead = Instance.new("Frame")
	portraitHead.Name = "PortraitHead"
	portraitHead.Position = UDim2.fromScale(0.38, 0.27)
	portraitHead.Size = UDim2.fromScale(0.24, 0.38)
	portraitHead.BackgroundColor3 = Color3.fromRGB(207, 190, 154)
	portraitHead.BorderSizePixel = 0
	portraitHead.Parent = einsteinBg
	local headCorner = Instance.new("UICorner")
	headCorner.CornerRadius = UDim.new(0.48, 0)
	headCorner.Parent = portraitHead

	for index, x in ipairs({0.29, 0.60}) do
		local hair = Instance.new("Frame")
		hair.Name = "WildHair" .. tostring(index)
		hair.Position = UDim2.fromScale(x, 0.22)
		hair.Size = UDim2.fromScale(0.16, 0.30)
		hair.BackgroundColor3 = Color3.fromRGB(224, 222, 207)
		hair.BorderSizePixel = 0
		hair.Rotation = index == 1 and -18 or 18
		hair.Parent = einsteinBg
		local hairCorner = Instance.new("UICorner")
		hairCorner.CornerRadius = UDim.new(0.5, 0)
		hairCorner.Parent = hair
	end

	for index, x in ipairs({0.22, 0.64}) do
		local eye = Instance.new("Frame")
		eye.Name = "Eye" .. tostring(index)
		eye.Position = UDim2.fromScale(x, 0.38)
		eye.Size = UDim2.fromScale(0.14, 0.10)
		eye.BackgroundColor3 = Color3.fromRGB(42, 40, 37)
		eye.BorderSizePixel = 0
		eye.Parent = portraitHead
		local eyeCorner = Instance.new("UICorner")
		eyeCorner.CornerRadius = UDim.new(0.5, 0)
		eyeCorner.Parent = eye
	end

	local moustache = Instance.new("Frame")
	moustache.Name = "Moustache"
	moustache.Position = UDim2.fromScale(0.23, 0.68)
	moustache.Size = UDim2.fromScale(0.54, 0.09)
	moustache.BackgroundColor3 = Color3.fromRGB(102, 101, 94)
	moustache.BorderSizePixel = 0
	moustache.Rotation = -3
	moustache.Parent = portraitHead
	local moustacheCorner = Instance.new("UICorner")
	moustacheCorner.CornerRadius = UDim.new(0.5, 0)
	moustacheCorner.Parent = moustache
end

local trainDiagram = makePart(twins, "SheldonTrainRouteDiagram", Vector3.new(0.14, 3.25, 4.20), CFrame.new(-9.50, 7.35, 36.15), Color3.fromRGB(79, 51, 31), Enum.Material.Wood, false)
makeSurfaceSign(trainDiagram, Enum.NormalId.Right, "TEXAS & PACIFIC", "GALVESTON → HOUSTON → MEDFORD\nDEPARTURE: EXACTLY 07:13", Color3.fromRGB(232, 223, 189), Color3.fromRGB(43, 65, 88))

local trainShelf = Instance.new("Model")
trainShelf.Name = "SheldonModelTrainShelf"
trainShelf.Parent = twins
makePart(trainShelf, "WallShelf", Vector3.new(3.80, 0.18, 0.85), CFrame.new(-2.15, 6.10, 41.55), Color3.fromRGB(94, 56, 33), Enum.Material.Wood, true)
makePart(trainShelf, "LocomotiveBody", Vector3.new(1.05, 0.55, 0.48), CFrame.new(-2.75, 6.48, 41.35), Color3.fromRGB(36, 54, 45), Enum.Material.Metal, false)
makePart(trainShelf, "Cab", Vector3.new(0.45, 0.68, 0.48), CFrame.new(-2.35, 6.74, 41.35), Color3.fromRGB(41, 61, 49), Enum.Material.Metal, false)
makePart(trainShelf, "Smokestack", Vector3.new(0.44, 0.18, 0.18), CFrame.new(-3.08, 6.86, 41.35) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 36, 33), Enum.Material.Metal, false, 0, Enum.PartType.Cylinder)
for _, x in ipairs({-3.02, -2.48}) do
	makePart(trainShelf, "Wheel", Vector3.new(0.20, 0.42, 0.42), CFrame.new(x, 6.30, 41.07), Color3.fromRGB(27, 29, 27), Enum.Material.Metal, false, 0, Enum.PartType.Cylinder)
end

-- Missy's room is narrow; the old oversized armchair intersected the bed.
-- Remove it and keep the smaller functional vanity stool instead.
local missyChair = props:FindFirstChild("MissyPinkStuffedChair")
if missyChair then
	missyChair:Destroy()
end

local vanity = Instance.new("Model")
vanity.Name = "MissyVanity"
vanity.Parent = twins
makePart(vanity, "VanityTop", Vector3.new(3.65, 0.25, 1.35), CFrame.new(4.95, 3.55, 29.05), Color3.fromRGB(199, 133, 139), Enum.Material.Wood, true)
makePart(vanity, "LeftDrawer", Vector3.new(1.10, 1.95, 1.15), CFrame.new(3.70, 2.50, 29.05), Color3.fromRGB(182, 112, 124), Enum.Material.Wood, true)
makePart(vanity, "RightDrawer", Vector3.new(1.10, 1.95, 1.15), CFrame.new(6.20, 2.50, 29.05), Color3.fromRGB(182, 112, 124), Enum.Material.Wood, true)
local mirror = makePart(vanity, "VanityMirror", Vector3.new(2.55, 2.70, 0.12), CFrame.new(4.95, 5.35, 28.45), Color3.fromRGB(177, 199, 204), Enum.Material.Glass, false)
mirror.Reflectance = 0.12
makePart(vanity, "PinkDiary", Vector3.new(0.85, 0.13, 1.05), CFrame.new(4.10, 3.75, 29.10), Color3.fromRGB(222, 94, 137), Enum.Material.Fabric, false)
makePart(vanity, "HairBrush", Vector3.new(0.75, 0.12, 0.22), CFrame.new(5.20, 3.77, 29.10) * CFrame.Angles(0, math.rad(24), 0), Color3.fromRGB(238, 198, 72), Enum.Material.SmoothPlastic, false)
makePart(vanity, "CassettePlayer", Vector3.new(1.05, 0.52, 0.58), CFrame.new(5.95, 3.91, 29.10), Color3.fromRGB(234, 164, 183), Enum.Material.SmoothPlastic, false)

local vanityStool = Instance.new("Model")
vanityStool.Name = "MissyVanityStool"
vanityStool.Parent = twins
makePart(vanityStool, "Cushion", Vector3.new(1.48, 0.28, 1.30), CFrame.new(4.95, 2.72, 31.05), Color3.fromRGB(229, 145, 169), Enum.Material.Fabric, true)
for _, offset in ipairs({
	Vector3.new(-0.55, 1.95, -0.45), Vector3.new(0.55, 1.95, -0.45),
	Vector3.new(-0.55, 1.95, 0.45), Vector3.new(0.55, 1.95, 0.45),
}) do
	makePart(vanityStool, "Leg", Vector3.new(0.17, 1.45, 0.17), CFrame.new(4.95 + offset.X, offset.Y, 31.05 + offset.Z), Color3.fromRGB(105, 62, 41), Enum.Material.Wood, true)
end
makeSeat(vanityStool, "FunctionalSeat", Vector3.new(1.25, 0.22, 1.08), CFrame.new(4.95, 2.98, 31.05))

local function makeBear(parent, position)
	local bear = Instance.new("Model")
	bear.Name = "MissyDetailedTeddyBear"
	bear.Parent = parent
	local brown = Color3.fromRGB(154, 101, 65)
	makePart(bear, "Body", Vector3.new(1.05, 1.28, 0.90), CFrame.new(position), brown, Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	makePart(bear, "Head", Vector3.new(0.95, 0.95, 0.88), CFrame.new(position + Vector3.new(0, 0.93, -0.03)), brown, Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	makePart(bear, "LeftEar", Vector3.new(0.38, 0.38, 0.28), CFrame.new(position + Vector3.new(-0.36, 1.28, -0.02)), Color3.fromRGB(132, 82, 54), Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	makePart(bear, "RightEar", Vector3.new(0.38, 0.38, 0.28), CFrame.new(position + Vector3.new(0.36, 1.28, -0.02)), Color3.fromRGB(132, 82, 54), Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	makePart(bear, "Muzzle", Vector3.new(0.50, 0.38, 0.24), CFrame.new(position + Vector3.new(0, 0.80, -0.44)), Color3.fromRGB(219, 179, 127), Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	for _, x in ipairs({-0.18, 0.18}) do
		makePart(bear, "Eye", Vector3.new(0.12, 0.12, 0.10), CFrame.new(position + Vector3.new(x, 1.06, -0.44)), Color3.fromRGB(28, 25, 23), Enum.Material.SmoothPlastic, false, 0, Enum.PartType.Ball)
	end
	makePart(bear, "Nose", Vector3.new(0.15, 0.13, 0.10), CFrame.new(position + Vector3.new(0, 0.87, -0.58)), Color3.fromRGB(36, 28, 25), Enum.Material.SmoothPlastic, false, 0, Enum.PartType.Ball)
	return bear
end

local function makeRabbit(parent, position)
	local rabbit = Instance.new("Model")
	rabbit.Name = "MissyDetailedRabbit"
	rabbit.Parent = parent
	local cream = Color3.fromRGB(231, 218, 199)
	makePart(rabbit, "Body", Vector3.new(0.82, 1.05, 0.72), CFrame.new(position), cream, Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	makePart(rabbit, "Head", Vector3.new(0.75, 0.75, 0.70), CFrame.new(position + Vector3.new(0, 0.75, -0.03)), cream, Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	makePart(rabbit, "LeftEar", Vector3.new(0.25, 0.85, 0.22), CFrame.new(position + Vector3.new(-0.20, 1.47, 0)), Color3.fromRGB(234, 190, 196), Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	makePart(rabbit, "RightEar", Vector3.new(0.25, 0.85, 0.22), CFrame.new(position + Vector3.new(0.20, 1.47, 0)), Color3.fromRGB(234, 190, 196), Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
	for _, x in ipairs({-0.14, 0.14}) do
		makePart(rabbit, "Eye", Vector3.new(0.10, 0.10, 0.09), CFrame.new(position + Vector3.new(x, 0.90, -0.36)), Color3.fromRGB(35, 31, 31), Enum.Material.SmoothPlastic, false, 0, Enum.PartType.Ball)
	end
	makePart(rabbit, "Nose", Vector3.new(0.11, 0.09, 0.08), CFrame.new(position + Vector3.new(0, 0.74, -0.39)), Color3.fromRGB(202, 106, 124), Enum.Material.SmoothPlastic, false, 0, Enum.PartType.Ball)
	return rabbit
end

makeBear(twins, Vector3.new(4.10, 3.75, 38.10))
makeRabbit(twins, Vector3.new(5.45, 3.70, 37.45))

-- Georgie's room: make football, sports, trucks, music, and teenage clutter immediately readable.
destroyTopLevel("GeorgieFootball")

local georgie = Instance.new("Model")
georgie.Name = "GeorgieRoomStoryProps"
georgie.Parent = detail

local georgieDresser = Instance.new("Model")
georgieDresser.Name = "GeorgieLowDresser"
georgieDresser.Parent = georgie
makePart(georgieDresser, "Body", Vector3.new(4.40, 2.55, 1.55), CFrame.new(12.15, 2.75, 29.25), Color3.fromRGB(97, 57, 35), Enum.Material.Wood, true)
makePart(georgieDresser, "Top", Vector3.new(4.65, 0.20, 1.75), CFrame.new(12.15, 4.10, 29.25), Color3.fromRGB(121, 72, 40), Enum.Material.Wood, true)
for row = 0, 1 do
	for col = 0, 1 do
		local x = 11.10 + col * 2.10
		local y = 3.40 - row * 1.15
		makePart(georgieDresser, "Drawer", Vector3.new(1.80, 0.86, 0.10), CFrame.new(x, y, 30.05), Color3.fromRGB(112, 65, 38), Enum.Material.Wood, false)
		makePart(georgieDresser, "Handle", Vector3.new(0.10, 0.10, 0.55), CFrame.new(x, y, 30.13) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(181, 133, 65), Enum.Material.Metal, false, 0, Enum.PartType.Cylinder)
	end
end

local football = makePart(georgie, "RealisticFootball", Vector3.new(1.75, 1.05, 1.05), CFrame.new(11.20, 2.20, 32.25) * CFrame.Angles(0, math.rad(22), math.rad(12)), Color3.fromRGB(118, 62, 34), Enum.Material.Fabric, true, 0, Enum.PartType.Ball)
for i = -2, 2 do
	makePart(georgie, "FootballLace", Vector3.new(0.08, 0.05, 0.28), football.CFrame * CFrame.new(i * 0.15, 0.51, 0), Color3.fromRGB(235, 225, 199), Enum.Material.Fabric, false)
end
makePart(georgie, "FootballLaceSpine", Vector3.new(0.85, 0.05, 0.08), football.CFrame * CFrame.new(0, 0.51, 0), Color3.fromRGB(235, 225, 199), Enum.Material.Fabric, false)

local helmet = Instance.new("Model")
helmet.Name = "MedfordMustangsHelmet"
helmet.Parent = georgie
makePart(helmet, "Shell", Vector3.new(1.45, 1.35, 1.35), CFrame.new(12.95, 4.75, 29.25), Color3.fromRGB(35, 86, 135), Enum.Material.SmoothPlastic, false, 0, Enum.PartType.Ball)
makePart(helmet, "GoldStripe", Vector3.new(0.16, 1.38, 1.38), CFrame.new(12.95, 4.75, 29.25), Color3.fromRGB(225, 174, 52), Enum.Material.SmoothPlastic, false)
makePart(helmet, "FaceMaskTop", Vector3.new(0.12, 0.12, 1.55), CFrame.new(13.62, 4.45, 29.25), Color3.fromRGB(205, 209, 203), Enum.Material.Metal, false)
for _, z in ipairs({28.68, 29.82}) do
	makePart(helmet, "FaceMaskBar", Vector3.new(0.95, 0.10, 0.10), CFrame.new(13.65, 4.22, z), Color3.fromRGB(205, 209, 203), Enum.Material.Metal, false)
end

makePart(georgie, "CassetteBoombox", Vector3.new(1.65, 0.72, 0.65), CFrame.new(10.65, 4.56, 29.25), Color3.fromRGB(52, 55, 56), Enum.Material.Metal, false)
for _, x in ipairs({10.22, 11.08}) do
	makePart(georgie, "Speaker", Vector3.new(0.14, 0.43, 0.43), CFrame.new(x, 4.55, 29.60) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(25, 27, 27), Enum.Material.Metal, false, 0, Enum.PartType.Cylinder)
end
makePart(georgie, "HairPomade", Vector3.new(0.48, 0.48, 0.48), CFrame.new(13.85, 4.44, 29.20), Color3.fromRGB(210, 191, 128), Enum.Material.SmoothPlastic, false, 0, Enum.PartType.Cylinder)

local trucksMagazine = makePart(georgie, "TexasTrucksMagazine", Vector3.new(0.95, 0.08, 1.20), CFrame.new(11.75, 4.24, 29.15) * CFrame.Angles(0, math.rad(-10), 0), Color3.fromRGB(165, 43, 36), Enum.Material.SmoothPlastic, false)
makeSurfaceSign(trucksMagazine, Enum.NormalId.Top, "TEXAS TRUCKS", "BIGGER. LOUDER. TEXAS.", Color3.fromRGB(170, 45, 37), Color3.fromRGB(247, 219, 158))

-- Group the dresser-top props, then rotate the whole assembly against the
-- right wall. This keeps the doorway and the foot of the bed unobstructed.
for _, child in ipairs(georgie:GetChildren()) do
	if child ~= georgieDresser and (
		child.Name == "MedfordMustangsHelmet"
		or child.Name == "CassetteBoombox"
		or child.Name == "Speaker"
		or child.Name == "HairPomade"
		or child.Name == "TexasTrucksMagazine"
	) then
		child.Parent = georgieDresser
	end
end
local dresserBounds = georgieDresser:GetBoundingBox()
local dresserTarget = CFrame.new(19.35, dresserBounds.Position.Y, 30.25)
	* CFrame.Angles(0, math.rad(-90), 0)
local dresserDelta = dresserTarget * dresserBounds:Inverse()
for _, descendant in ipairs(georgieDresser:GetDescendants()) do
	if descendant:IsA("BasePart") then
		descendant.CFrame = dresserDelta * descendant.CFrame
	end
end

-- Flush, readable hallway gallery to replace the half-detached picture-frame models.
local hallGallery = Instance.new("Model")
hallGallery.Name = "CooperHallGallery"
hallGallery.Parent = detail
local galleryItems = {
	{-16.5, 7.10, "LanceBarber"},
	{-13.3, 7.45, "AnniePotts"},
	{-8.4, 7.00, "IainArmitage"},
	{6.35, 7.25, "RaeganRevord"},
	{19.40, 7.20, "MontanaJordan"},
}
for index, item in ipairs(galleryItems) do
	local frame = makePart(hallGallery, "HallFrame" .. tostring(index), Vector3.new(2.20, 1.70, 0.13), CFrame.new(item[1], item[2], 27.62), Color3.fromRGB(76, 46, 29), Enum.Material.Wood, false)
	frame:SetAttribute("PhotoSlot", item[3])
end

detail:PivotTo(detail:GetPivot())

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("Young Sheldon bedroom rebuild")
	end)
end

print("Young Sheldon bedroom rebuild complete", #detail:GetDescendants())
return #detail:GetDescendants()
