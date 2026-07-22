--!strict
-- Idempotent, scoped Studio builder for the Milestone 1 start-place lobby.
-- It replaces only CooperPartyLobbyEnvironment and named lobby lighting effects;
-- it never clears Workspace, Terrain, ReplicatedStorage, scripts, or StarterGui.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Lobby visual builder must run in Studio edit mode")

ChangeHistoryService:SetWaypoint("Before 1980s Cooper lobby visual update")

local oldEnvironment = Workspace:FindFirstChild("CooperPartyLobbyEnvironment")
if oldEnvironment then
	oldEnvironment:Destroy()
end
for _, name in ipairs({ "LobbyAtmosphere", "LobbyColorGrade", "LobbyBloom", "LobbyDepthOfField" }) do
	local oldEffect = Lighting:FindFirstChild(name)
	if oldEffect then
		oldEffect:Destroy()
	end
end

-- The lobby is intentionally menu-driven. This removes thumbstick and jump UI
-- that would cover party controls on short phones. The house place retains its
-- own normal movement configuration.
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
StarterPlayer.AutoJumpEnabled = false

Workspace.StreamingEnabled = false
Workspace.FallenPartsDestroyHeight = -80

-- Warm indoor evening light matches the Cooper house and keeps the lobby from
-- reading as a science-fiction control room.
Lighting.ClockTime = 18.4
Lighting.Brightness = 2.65
Lighting.Ambient = Color3.fromRGB(115, 88, 66)
Lighting.OutdoorAmbient = Color3.fromRGB(72, 72, 76)
Lighting.EnvironmentDiffuseScale = 0.58
Lighting.EnvironmentSpecularScale = 0.28
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = 0.18

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "LobbyColorGrade"
colorCorrection.Brightness = 0.03
colorCorrection.Contrast = 0.02
colorCorrection.Saturation = -0.025
colorCorrection.TintColor = Color3.fromRGB(255, 231, 190)
colorCorrection.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "LobbyBloom"
bloom.Intensity = 0.12
bloom.Size = 18
bloom.Threshold = 1.75
bloom.Parent = Lighting

local environment = Instance.new("Model")
environment.Name = "CooperPartyLobbyEnvironment"
environment:SetAttribute("Milestone", 1)
environment:SetAttribute("EnvironmentVersion", "2.0.0")
environment:SetAttribute("Purpose", "PrivatePartyLobby")
environment:SetAttribute("Theme", "1980sSuburbanRecRoom")
environment:SetAttribute("VisualUpdater", "ScopedIdempotent")
environment.Parent = Workspace

local architecture = Instance.new("Folder")
architecture.Name = "Architecture"
architecture.Parent = environment

local furniture = Instance.new("Folder")
furniture.Name = "Furniture"
furniture.Parent = environment

local decor = Instance.new("Folder")
decor.Name = "PeriodDecor"
decor.Parent = environment

local lightingFolder = Instance.new("Folder")
lightingFolder.Name = "PracticalLights"
lightingFolder.Parent = environment

local PALETTE = table.freeze({
	Wood = Color3.fromRGB(100, 57, 34),
	WoodDark = Color3.fromRGB(64, 38, 27),
	WoodLight = Color3.fromRGB(143, 90, 52),
	Cream = Color3.fromRGB(232, 217, 178),
	Carpet = Color3.fromRGB(88, 65, 48),
	CarpetLight = Color3.fromRGB(123, 89, 59),
	Mustard = Color3.fromRGB(211, 157, 44),
	Rust = Color3.fromRGB(157, 68, 42),
	Avocado = Color3.fromRGB(119, 137, 55),
	Teal = Color3.fromRGB(61, 119, 116),
	Brown = Color3.fromRGB(80, 47, 32),
	Screen = Color3.fromRGB(28, 44, 37),
	Twilight = Color3.fromRGB(54, 74, 92),
})

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?,
	canCollide: boolean?
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material
	item.Transparency = transparency or 0
	item.CanCollide = canCollide ~= false
	item.CanTouch = item.CanCollide
	item.CanQuery = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function surfaceText(
	adornee: BasePart,
	name: string,
	text: string,
	face: Enum.NormalId,
	textColor: Color3,
	font: Enum.Font,
	backgroundColor: Color3?,
	backgroundTransparency: number?
): TextLabel
	local surface = Instance.new("SurfaceGui")
	surface.Name = name
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 42
	surface.LightInfluence = 0.25
	surface.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = backgroundColor or Color3.new(0, 0, 0)
	label.BackgroundTransparency = backgroundTransparency or 1
	label.BorderSizePixel = 0
	label.Font = font
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = 52
	constraint.Parent = label
	return label
end

-- Architecture: wood-paneled rec room with a woven geometric carpet.
makePart(architecture, "CarpetFloor", Vector3.new(72, 1, 58), CFrame.new(0, -0.5, 0), PALETTE.Carpet, Enum.Material.Fabric)
makePart(architecture, "CreamCeiling", Vector3.new(72, 1, 58), CFrame.new(0, 19.5, 0), PALETTE.Cream, Enum.Material.Plaster)
makePart(architecture, "BackWoodWall", Vector3.new(72, 20, 1), CFrame.new(0, 9.5, -29), PALETTE.Wood, Enum.Material.WoodPlanks)
makePart(architecture, "FrontWoodWall", Vector3.new(72, 20, 1), CFrame.new(0, 9.5, 29), PALETTE.Wood, Enum.Material.WoodPlanks)
makePart(architecture, "LeftWoodWall", Vector3.new(1, 20, 58), CFrame.new(-36, 9.5, 0), PALETTE.Wood, Enum.Material.WoodPlanks)
makePart(architecture, "RightWoodWall", Vector3.new(1, 20, 58), CFrame.new(36, 9.5, 0), PALETTE.Wood, Enum.Material.WoodPlanks)

for _, z in ipairs({ -28.35, 28.35 }) do
	makePart(architecture, "CreamBaseboard", Vector3.new(71, 0.75, 0.28), CFrame.new(0, 0.4, z), PALETTE.Cream, Enum.Material.Wood)
end
for _, x in ipairs({ -35.35, 35.35 }) do
	makePart(architecture, "CreamBaseboard", Vector3.new(0.28, 0.75, 57), CFrame.new(x, 0.4, 0), PALETTE.Cream, Enum.Material.Wood)
end
for x = -33, 33, 6 do
	makePart(decor, "BackPanelTrim", Vector3.new(0.12, 18.5, 0.08), CFrame.new(x, 9.7, -28.43), PALETTE.WoodDark, Enum.Material.Wood, 0.18, false)
end

-- Low-part-count period carpet pattern.
for index, z in ipairs({ -18, -10, -2, 6, 14, 22 }) do
	local color = if index % 3 == 1 then PALETTE.Mustard elseif index % 3 == 2 then PALETTE.Avocado else PALETTE.Rust
	makePart(decor, "CarpetStripe", Vector3.new(70, 0.025, 0.42), CFrame.new(0, 0.02, z), color, Enum.Material.Fabric, 0.28, false)
end
for index, x in ipairs({ -30, -18, -6, 6, 18, 30 }) do
	local color = if index % 2 == 0 then PALETTE.CarpetLight else PALETTE.WoodLight
	makePart(decor, "CarpetCrossStripe", Vector3.new(0.32, 0.026, 56), CFrame.new(x, 0.022, 0), color, Enum.Material.Fabric, 0.48, false)
end

-- A normal household doorway replaces the old neon portal.
local doorway = Instance.new("Model")
doorway.Name = "PrivateHouseDoorway"
doorway.Parent = architecture
makePart(doorway, "Door", Vector3.new(14, 11, 0.65), CFrame.new(0, 5.75, -28.15), PALETTE.Teal, Enum.Material.WoodPlanks)
makePart(doorway, "LeftTrim", Vector3.new(1, 12.2, 1), CFrame.new(-7.35, 6.1, -27.75), PALETTE.Cream, Enum.Material.Wood)
makePart(doorway, "RightTrim", Vector3.new(1, 12.2, 1), CFrame.new(7.35, 6.1, -27.75), PALETTE.Cream, Enum.Material.Wood)
makePart(doorway, "TopTrim", Vector3.new(15.7, 1, 1), CFrame.new(0, 11.75, -27.75), PALETTE.Cream, Enum.Material.Wood)
local doorSign = makePart(doorway, "DoorSign", Vector3.new(10.5, 3.1, 0.25), CFrame.new(0, 8.5, -27.72), PALETTE.Screen, Enum.Material.SmoothPlastic)
surfaceText(doorSign, "DoorSignDisplay", "COOPER HOUSE\nPRIVATE PARTY", Enum.NormalId.Back, PALETTE.Mustard, Enum.Font.GothamBold, nil, 1)
local knob = makePart(doorway, "DoorKnob", Vector3.new(0.55, 0.55, 0.55), CFrame.new(5.2, 5.3, -27.58), PALETTE.Mustard, Enum.Material.Metal, 0, false)
knob.Shape = Enum.PartType.Ball

-- CRT television and VCR party display.
local tv = Instance.new("Model")
tv.Name = "CRTPartyDisplay"
tv.Parent = furniture
makePart(tv, "Console", Vector3.new(15, 3.1, 3.6), CFrame.new(-23, 1.55, -24.7), PALETTE.WoodDark, Enum.Material.WoodPlanks)
makePart(tv, "TelevisionCabinet", Vector3.new(13.4, 8.6, 3.3), CFrame.new(-23, 7.3, -25.2), PALETTE.WoodLight, Enum.Material.WoodPlanks)
local screenPart = makePart(tv, "GlassScreen", Vector3.new(9.5, 5.7, 0.35), CFrame.new(-23.8, 7.6, -23.48), PALETTE.Screen, Enum.Material.Glass, 0.04, false)
surfaceText(screenPart, "PartyChannel", "COOPER HOUSE\nPARTY CHANNEL 86", Enum.NormalId.Back, PALETTE.Mustard, Enum.Font.RobotoMono, Color3.fromRGB(22, 37, 30), 0.05)
makePart(tv, "ControlPanel", Vector3.new(1.8, 5.8, 0.4), CFrame.new(-18.2, 7.4, -23.45), PALETTE.WoodDark, Enum.Material.SmoothPlastic)
for y = 6.2, 8.8, 1.3 do
	local dial = makePart(tv, "ChannelDial", Vector3.new(0.65, 0.65, 0.35), CFrame.new(-18.2, y, -23.12), PALETTE.Cream, Enum.Material.SmoothPlastic, 0, false)
	dial.Shape = Enum.PartType.Cylinder
	dial.CFrame *= CFrame.Angles(0, math.rad(90), 0)
end
makePart(tv, "VCR", Vector3.new(8.5, 1.05, 2.2), CFrame.new(-23, 3.55, -23.9), Color3.fromRGB(44, 43, 39), Enum.Material.SmoothPlastic)
makePart(tv, "VCRSlot", Vector3.new(5.5, 0.12, 0.12), CFrame.new(-23.7, 3.62, -22.77), Color3.fromRGB(13, 13, 12), Enum.Material.SmoothPlastic, 0, false)
makePart(tv, "LeftAntenna", Vector3.new(0.14, 4.4, 0.14), CFrame.new(-25.4, 13.2, -25.2) * CFrame.Angles(0, 0, math.rad(-28)), Color3.fromRGB(68, 64, 57), Enum.Material.Metal, 0, false)
makePart(tv, "RightAntenna", Vector3.new(0.14, 4.4, 0.14), CFrame.new(-20.6, 13.2, -25.2) * CFrame.Angles(0, 0, math.rad(28)), Color3.fromRGB(68, 64, 57), Enum.Material.Metal, 0, false)

-- Sofa, armchair, and coffee table make the separate lobby feel like it still
-- belongs to the Cooper home.
local sofa = Instance.new("Model")
sofa.Name = "AvocadoSofa"
sofa.Parent = furniture
makePart(sofa, "Seat", Vector3.new(14, 2.2, 5.4), CFrame.new(22, 2.4, 12), PALETTE.Avocado, Enum.Material.Fabric)
makePart(sofa, "Back", Vector3.new(14, 5.8, 2), CFrame.new(22, 5.2, 14.2) * CFrame.Angles(math.rad(-7), 0, 0), PALETTE.Avocado, Enum.Material.Fabric)
makePart(sofa, "LeftArm", Vector3.new(2, 4, 6), CFrame.new(15.8, 3.4, 12), PALETTE.Avocado, Enum.Material.Fabric)
makePart(sofa, "RightArm", Vector3.new(2, 4, 6), CFrame.new(28.2, 3.4, 12), PALETTE.Avocado, Enum.Material.Fabric)
for _, x in ipairs({ 17.7, 26.3 }) do
	makePart(sofa, "WoodenLeg", Vector3.new(0.7, 1.5, 0.7), CFrame.new(x, 0.75, 13.6), PALETTE.WoodDark, Enum.Material.Wood)
end

local chair = Instance.new("Model")
chair.Name = "RustArmchair"
chair.Parent = furniture
makePart(chair, "Seat", Vector3.new(6.5, 2.1, 5.2), CFrame.new(-25, 2.35, 12), PALETTE.Rust, Enum.Material.Fabric)
makePart(chair, "Back", Vector3.new(6.5, 6.6, 1.7), CFrame.new(-25, 5.5, 14), PALETTE.Rust, Enum.Material.Fabric)
makePart(chair, "LeftArm", Vector3.new(1.4, 3.4, 5.6), CFrame.new(-27.8, 3.4, 12), PALETTE.Rust, Enum.Material.Fabric)
makePart(chair, "RightArm", Vector3.new(1.4, 3.4, 5.6), CFrame.new(-22.2, 3.4, 12), PALETTE.Rust, Enum.Material.Fabric)
for _, offset in ipairs({ Vector3.new(-2.25, 0.65, -1.8), Vector3.new(2.25, 0.65, -1.8), Vector3.new(-2.25, 0.65, 1.8), Vector3.new(2.25, 0.65, 1.8) }) do
	makePart(chair, "WoodenLeg", Vector3.new(0.65, 1.3, 0.65), CFrame.new(Vector3.new(-25, 0, 12) + offset), PALETTE.WoodDark, Enum.Material.Wood)
end

makePart(furniture, "CoffeeTableTop", Vector3.new(15, 0.8, 7), CFrame.new(4, 2.4, 12), PALETTE.WoodLight, Enum.Material.WoodPlanks)
for _, offset in ipairs({ Vector3.new(-6, 1.1, -2.3), Vector3.new(6, 1.1, -2.3), Vector3.new(-6, 1.1, 2.3), Vector3.new(6, 1.1, 2.3) }) do
	makePart(furniture, "CoffeeTableLeg", Vector3.new(0.7, 2.2, 0.7), CFrame.new(Vector3.new(4, 0, 12) + offset), PALETTE.WoodDark, Enum.Material.Wood)
end

-- Four woven floor markers replace glowing party pads.
local rugFolder = Instance.new("Folder")
rugFolder.Name = "PartyRugMarkers"
rugFolder.Parent = decor
local rugColors = { PALETTE.Mustard, PALETTE.Rust, PALETTE.Avocado, PALETTE.Teal }
for index, x in ipairs({ -15, -5, 5, 15 }) do
	local rug = makePart(rugFolder, "PartyRug" .. tostring(index), Vector3.new(7.6, 0.12, 7.6), CFrame.new(x, 0.08, -5), rugColors[index], Enum.Material.Fabric, 0.08, false)
	local inner = makePart(rugFolder, "PartyRugInset" .. tostring(index), Vector3.new(6.6, 0.04, 6.6), CFrame.new(x, 0.15, -5), PALETTE.Carpet, Enum.Material.Fabric, 0.16, false)
	surfaceText(inner, "PlayerNumber", tostring(index), Enum.NormalId.Top, PALETTE.Cream, Enum.Font.GothamBold, nil, 1)
	-- Keep rug reference intentionally used for clarity in Studio's hierarchy.
	rug:SetAttribute("PartyPosition", index)
end

-- Bulletin board and blueprints provide an in-world explanation without giant
-- signs or vertical lettering.
local bulletin = makePart(decor, "FamilyBulletinBoard", Vector3.new(11.6, 7, 0.55), CFrame.new(19.8, 10.8, -28.15), Color3.fromRGB(151, 102, 55), Enum.Material.Fabric)
surfaceText(bulletin, "HouseRules", "COOPER HOUSE PARTY\n\n1. INVITE YOUR FRIENDS\n2. EVERYONE PRESSES READY\n3. THE HOST STARTS", Enum.NormalId.Back, Color3.fromRGB(61, 38, 24), Enum.Font.GothamBold, PALETTE.Cream, 0.08)
for index, x in ipairs({ 14.7, 18, 21.5, 24.9 }) do
	local pin = makePart(decor, "BulletinPin" .. tostring(index), Vector3.new(0.28, 0.28, 0.2), CFrame.new(x, 13.35, -27.8), if index % 2 == 0 then PALETTE.Teal else PALETTE.Rust, Enum.Material.SmoothPlastic, 0, false)
	pin.Shape = Enum.PartType.Ball
end

local blueprint = makePart(decor, "HouseBlueprint", Vector3.new(8.4, 6.5, 0.4), CFrame.new(30.3, 10.4, -28.05), Color3.fromRGB(42, 80, 112), Enum.Material.SmoothPlastic)
surfaceText(blueprint, "BlueprintDrawing", "COOPER HOUSE\nFAMILY ROOM PLAN\n\n□ KITCHEN    □ GARAGE\n□ BEDROOMS   □ BACKYARD", Enum.NormalId.Back, Color3.fromRGB(224, 239, 234), Enum.Font.RobotoMono, nil, 1)

-- Analog wall clock (fixed decorative time) and rotary telephone.
local clockBoard = makePart(decor, "AnalogWallClock", Vector3.new(5.5, 5.5, 0.5), CFrame.new(10.75, 14.5, -28.08), PALETTE.Cream, Enum.Material.SmoothPlastic)
local clockFace = surfaceText(clockBoard, "ClockFace", "12\n\n9      •      3\n\n6", Enum.NormalId.Back, PALETTE.WoodDark, Enum.Font.GothamBold, nil, 1)
clockFace.TextSize = 18
local clockGui = clockBoard:FindFirstChild("ClockFace")
if clockGui and clockGui:IsA("SurfaceGui") then
	local hourHand = Instance.new("Frame")
	hourHand.Name = "HourHand"
	hourHand.AnchorPoint = Vector2.new(0.5, 1)
	hourHand.Position = UDim2.fromScale(0.5, 0.5)
	hourHand.Size = UDim2.fromScale(0.025, 0.21)
	hourHand.Rotation = 248
	hourHand.BackgroundColor3 = PALETTE.WoodDark
	hourHand.BorderSizePixel = 0
	hourHand.Parent = clockGui
	local minuteHand = Instance.new("Frame")
	minuteHand.Name = "MinuteHand"
	minuteHand.AnchorPoint = Vector2.new(0.5, 1)
	minuteHand.Position = UDim2.fromScale(0.5, 0.5)
	minuteHand.Size = UDim2.fromScale(0.018, 0.31)
	minuteHand.Rotation = 90
	minuteHand.BackgroundColor3 = PALETTE.Rust
	minuteHand.BorderSizePixel = 0
	minuteHand.Parent = clockGui
end

makePart(furniture, "PhoneTable", Vector3.new(5.5, 0.65, 4.2), CFrame.new(31.2, 3.2, -14), PALETTE.WoodLight, Enum.Material.WoodPlanks)
makePart(furniture, "PhoneTableLeg", Vector3.new(3.6, 5.8, 2.8), CFrame.new(31.2, 0.35, -14), PALETTE.WoodDark, Enum.Material.WoodPlanks)
makePart(decor, "RotaryPhoneBase", Vector3.new(3.6, 1.2, 2.8), CFrame.new(31.2, 4.1, -14), PALETTE.Mustard, Enum.Material.SmoothPlastic)
local phoneDial = makePart(decor, "RotaryDial", Vector3.new(1.5, 0.36, 1.5), CFrame.new(31.2, 4.77, -13.9), PALETTE.Cream, Enum.Material.SmoothPlastic, 0, false)
phoneDial.Shape = Enum.PartType.Cylinder
phoneDial.CFrame *= CFrame.Angles(0, 0, math.rad(90))
makePart(decor, "PhoneReceiver", Vector3.new(3.8, 0.62, 0.7), CFrame.new(31.2, 5.18, -14), PALETTE.WoodDark, Enum.Material.SmoothPlastic, 0, false)

-- A pair of windows prevents the room from feeling like a sealed box.
for _, x in ipairs({ -10, 29 }) do
	local glass = makePart(decor, "TwilightWindow", Vector3.new(10, 7.5, 0.22), CFrame.new(x, 11, 28.38), PALETTE.Twilight, Enum.Material.Glass, 0.28, false)
	makePart(decor, "WindowTop", Vector3.new(11, 0.5, 0.5), CFrame.new(x, 14.95, 28.12), PALETTE.Cream, Enum.Material.Wood)
	makePart(decor, "WindowBottom", Vector3.new(11, 0.5, 0.5), CFrame.new(x, 7.05, 28.12), PALETTE.Cream, Enum.Material.Wood)
	makePart(decor, "WindowLeft", Vector3.new(0.5, 8.4, 0.5), CFrame.new(x - 5.25, 11, 28.12), PALETTE.Cream, Enum.Material.Wood)
	makePart(decor, "WindowRight", Vector3.new(0.5, 8.4, 0.5), CFrame.new(x + 5.25, 11, 28.12), PALETTE.Cream, Enum.Material.Wood)
	makePart(decor, "WindowCross", Vector3.new(0.3, 7.5, 0.34), CFrame.new(x, 11, 28), PALETTE.Cream, Enum.Material.Wood)
	glass.CanQuery = false
end

-- Warm practical ceiling and floor lamps, with restrained brightness for mobile.
for _, x in ipairs({ -24, -8, 8, 24 }) do
	local fixture = makePart(lightingFolder, "CeilingFixture", Vector3.new(5.8, 0.25, 2.5), CFrame.new(x, 18.82, 0), PALETTE.Cream, Enum.Material.SmoothPlastic, 0.04, false)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness = 1.55
	light.Range = 21
	light.Angle = 115
	light.Color = Color3.fromRGB(255, 221, 166)
	light.Shadows = false
	light.Parent = fixture
end

makePart(lightingFolder, "FloorLampBase", Vector3.new(2.5, 0.35, 2.5), CFrame.new(32, 0.2, 12), PALETTE.WoodDark, Enum.Material.Metal)
local pole = makePart(lightingFolder, "FloorLampPole", Vector3.new(0.35, 10.5, 0.35), CFrame.new(32, 5.35, 12), PALETTE.Mustard, Enum.Material.Metal)
pole.Shape = Enum.PartType.Cylinder
local lampShade = makePart(lightingFolder, "FloorLampShade", Vector3.new(4.5, 3, 4.5), CFrame.new(32, 11.4, 12), PALETTE.Cream, Enum.Material.Fabric, 0.08, false)
local lampLight = Instance.new("PointLight")
lampLight.Brightness = 1.65
lampLight.Range = 17
lampLight.Color = Color3.fromRGB(255, 205, 137)
lampLight.Shadows = false
lampLight.Parent = lampShade

-- Invisible neutral spawn; menu-driven lobby avatars do not need a glowing pad.
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 0.35, 8)
-- Default -Z facing looks directly toward the CRT and Cooper-house doorway.
spawn.CFrame = CFrame.new(0, 0.15, 21)
spawn.Color = PALETTE.Carpet
spawn.Material = Enum.Material.Fabric
spawn.Transparency = 1
spawn.CanCollide = true
spawn.Neutral = true
spawn.AllowTeamChangeOnTouch = false
spawn.Duration = 0
spawn.Parent = environment

-- Initial installs still receive source slots, but an updater never overwrites
-- any synchronized runtime source that is already present.
local lobbyFolder = ReplicatedStorage:FindFirstChild("CooperLobby")
if not lobbyFolder then
	lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "CooperLobby"
	lobbyFolder.Parent = ReplicatedStorage
end

if not lobbyFolder:FindFirstChild("Config") then
	local config = Instance.new("ModuleScript")
	config.Name = "Config"
	config.Source = "return {} -- synchronize from lobby/CooperLobbyConfig.module.luau"
	config.Parent = lobbyFolder
end
if not ReplicatedStorage:FindFirstChild("CooperPartyProtocol") then
	local protocol = Instance.new("ModuleScript")
	protocol.Name = "CooperPartyProtocol"
	protocol.Source = "return {} -- synchronize from CooperPartyProtocol.module.luau"
	protocol.Parent = ReplicatedStorage
end
if not ServerScriptService:FindFirstChild("CooperLobby") then
	local server = Instance.new("Script")
	server.Name = "CooperLobby"
	server.Source = "-- synchronize from lobby/CooperLobby.server.luau"
	server.Parent = ServerScriptService
end
if not StarterPlayer.StarterPlayerScripts:FindFirstChild("CooperLobby") then
	local client = Instance.new("LocalScript")
	client.Name = "CooperLobby"
	client.Source = "-- synchronize from lobby/CooperLobby.client.luau"
	client.Parent = StarterPlayer.StarterPlayerScripts
end

ChangeHistoryService:SetWaypoint("1980s Cooper lobby visual update complete")

print("[CooperLobbyBuilder] Scoped 1980s suburban rec-room lobby visuals prepared")
return true
