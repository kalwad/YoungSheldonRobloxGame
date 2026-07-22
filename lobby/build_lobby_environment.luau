--!strict
-- One-time, idempotent Studio builder for the Milestone 1 start-place lobby.
-- Run only in edit mode after the original house has been backed up and cloned.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

assert(not game:GetService("RunService"):IsRunning(), "Lobby builder must run in Studio edit mode")

ChangeHistoryService:SetWaypoint("Before Milestone 1 lobby conversion")

local function clearChildren(parent: Instance, preserve: { [Instance]: boolean }?)
	for _, child in ipairs(parent:GetChildren()) do
		if not preserve or preserve[child] ~= true then
			child:Destroy()
		end
	end
end

local terrain = Workspace:FindFirstChildOfClass("Terrain")
local camera = Workspace.CurrentCamera
local preserveWorkspace: { [Instance]: boolean } = {}
if terrain then
	preserveWorkspace[terrain] = true
end
if camera then
	preserveWorkspace[camera] = true
end
clearChildren(Workspace, preserveWorkspace)
if terrain then
	terrain:Clear()
end
clearChildren(ReplicatedStorage)
clearChildren(ServerScriptService)
clearChildren(StarterGui)
clearChildren(StarterPlayer.StarterPlayerScripts)

-- The lobby is intentionally UI-driven. Suppressing avatar locomotion removes
-- the mobile thumbstick/jump overlays that otherwise cover party controls on
-- short landscape phones; the reserved house restores its normal controls.
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
StarterPlayer.AutoJumpEnabled = false

Workspace.StreamingEnabled = false
Workspace.FallenPartsDestroyHeight = -80

Lighting.ClockTime = 19.2
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(42, 56, 61)
Lighting.OutdoorAmbient = Color3.fromRGB(27, 39, 45)
Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = 0.05

for _, effect in ipairs(Lighting:GetChildren()) do
	if effect:IsA("PostEffect") or effect:IsA("Atmosphere") or effect:IsA("Sky") then
		effect:Destroy()
	end
end

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "LobbyAtmosphere"
atmosphere.Density = 0.18
atmosphere.Offset = 0.15
atmosphere.Color = Color3.fromRGB(160, 194, 202)
atmosphere.Decay = Color3.fromRGB(36, 50, 58)
atmosphere.Glare = 0.08
atmosphere.Haze = 1.1
atmosphere.Parent = Lighting

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "LobbyColorGrade"
colorCorrection.Brightness = 0.01
colorCorrection.Contrast = 0.08
colorCorrection.Saturation = -0.08
colorCorrection.TintColor = Color3.fromRGB(226, 246, 239)
colorCorrection.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "LobbyBloom"
bloom.Intensity = 0.28
bloom.Size = 22
bloom.Threshold = 1.35
bloom.Parent = Lighting

local environment = Instance.new("Model")
environment.Name = "CooperPartyLobbyEnvironment"
environment:SetAttribute("Milestone", 1)
environment:SetAttribute("EnvironmentVersion", "1.0.0")
environment:SetAttribute("Purpose", "PrivatePartyLobby")
environment.Parent = Workspace

local architecture = Instance.new("Folder")
architecture.Name = "Architecture"
architecture.Parent = environment

local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = environment

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

local dark = Color3.fromRGB(18, 29, 34)
local darkRaised = Color3.fromRGB(27, 45, 50)
local steel = Color3.fromRGB(64, 83, 87)
local teal = Color3.fromRGB(74, 213, 184)
local amber = Color3.fromRGB(255, 187, 66)

makePart(architecture, "Floor", Vector3.new(72, 1, 58), CFrame.new(0, -0.5, 0), dark, Enum.Material.Slate)
makePart(architecture, "Ceiling", Vector3.new(72, 1, 58), CFrame.new(0, 19.5, 0), dark, Enum.Material.Metal)
makePart(architecture, "BackWall", Vector3.new(72, 20, 1), CFrame.new(0, 9.5, -29), darkRaised, Enum.Material.Concrete)
makePart(architecture, "FrontWall", Vector3.new(72, 20, 1), CFrame.new(0, 9.5, 29), darkRaised, Enum.Material.Concrete)
makePart(architecture, "LeftWall", Vector3.new(1, 20, 58), CFrame.new(-36, 9.5, 0), darkRaised, Enum.Material.Concrete)
makePart(architecture, "RightWall", Vector3.new(1, 20, 58), CFrame.new(36, 9.5, 0), darkRaised, Enum.Material.Concrete)

for x = -30, 30, 6 do
	makePart(decor, "FloorGridX", Vector3.new(0.08, 0.025, 56), CFrame.new(x, 0.025, 0), steel, Enum.Material.Metal, 0.55, false)
end
for z = -24, 24, 6 do
	makePart(decor, "FloorGridZ", Vector3.new(70, 0.025, 0.08), CFrame.new(0, 0.025, z), steel, Enum.Material.Metal, 0.55, false)
end

local portal = Instance.new("Model")
portal.Name = "PrivateHousePortal"
portal.Parent = decor
makePart(portal, "LeftColumn", Vector3.new(2.2, 11, 2.2), CFrame.new(-8.1, 5.5, -25.7), steel, Enum.Material.Metal)
makePart(portal, "RightColumn", Vector3.new(2.2, 11, 2.2), CFrame.new(8.1, 5.5, -25.7), steel, Enum.Material.Metal)
makePart(portal, "Header", Vector3.new(18.4, 2.2, 2.2), CFrame.new(0, 10, -25.7), steel, Enum.Material.Metal)
local portalField = makePart(portal, "PortalField", Vector3.new(14, 8.7, 0.35), CFrame.new(0, 4.6, -26), Color3.fromRGB(54, 174, 156), Enum.Material.Neon, 0.58, false)
portalField.CanQuery = false
local portalLight = Instance.new("SurfaceLight")
portalLight.Face = Enum.NormalId.Front
portalLight.Angle = 110
portalLight.Brightness = 1.6
portalLight.Range = 18
portalLight.Color = teal
portalLight.Parent = portalField

local headerGui = Instance.new("SurfaceGui")
headerGui.Name = "PortalSign"
headerGui.Face = Enum.NormalId.Front
headerGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
headerGui.PixelsPerStud = 42
headerGui.AlwaysOnTop = false
headerGui.Parent = portal.Header
local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.fromScale(1, 1)
headerLabel.BackgroundTransparency = 1
headerLabel.Font = Enum.Font.GothamBold
headerLabel.Text = "PRIVATE HOUSE LINK"
headerLabel.TextColor3 = Color3.fromRGB(230, 255, 245)
headerLabel.TextScaled = true
headerLabel.Parent = headerGui

local marquee = makePart(decor, "LobbyMarquee", Vector3.new(32, 7, 0.7), CFrame.new(0, 14.4, -28.2), Color3.fromRGB(8, 18, 21), Enum.Material.SmoothPlastic)
local marqueeGui = Instance.new("SurfaceGui")
marqueeGui.Name = "MarqueeDisplay"
marqueeGui.Face = Enum.NormalId.Front
marqueeGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
marqueeGui.PixelsPerStud = 34
marqueeGui.Parent = marquee
local marqueeLabel = Instance.new("TextLabel")
marqueeLabel.Size = UDim2.fromScale(1, 1)
marqueeLabel.BackgroundTransparency = 1
marqueeLabel.Font = Enum.Font.GothamBold
marqueeLabel.Text = "COOPER HOUSE\nPARTY LOBBY"
marqueeLabel.TextColor3 = amber
marqueeLabel.TextScaled = true
marqueeLabel.TextWrapped = true
marqueeLabel.Parent = marqueeGui

local padFolder = Instance.new("Folder")
padFolder.Name = "PartyPads"
padFolder.Parent = decor
for index, x in ipairs({ -18, -6, 6, 18 }) do
	local pad = makePart(
		padFolder,
		"PartyPad" .. tostring(index),
		Vector3.new(0.35, 7, 7),
		CFrame.new(x, 0.18, 6) * CFrame.Angles(0, 0, math.rad(90)),
		index == 1 and amber or teal,
		Enum.Material.Neon,
		0.25,
		true
	)
	pad.Shape = Enum.PartType.Cylinder
	local point = Instance.new("PointLight")
	point.Brightness = 0.7
	point.Range = 9
	point.Color = pad.Color
	point.Parent = pad
	local numberGui = Instance.new("SurfaceGui")
	numberGui.Face = Enum.NormalId.Right
	numberGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	numberGui.PixelsPerStud = 36
	numberGui.Parent = pad
	local number = Instance.new("TextLabel")
	number.Size = UDim2.fromScale(1, 1)
	number.BackgroundTransparency = 1
	number.Font = Enum.Font.GothamBold
	number.Text = tostring(index)
	number.TextColor3 = Color3.fromRGB(245, 250, 242)
	number.TextScaled = true
	number.Parent = numberGui
end

local function makeInfoPanel(name: string, x: number, heading: string, body: string)
	local board = makePart(decor, name, Vector3.new(14, 9, 0.6), CFrame.new(x, 8, -27.9), Color3.fromRGB(9, 23, 27), Enum.Material.SmoothPlastic)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	surface.Parent = board
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromScale(0.07, 0.07)
	title.Size = UDim2.fromScale(0.86, 0.24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = heading
	title.TextColor3 = teal
	title.TextScaled = true
	title.Parent = surface
	local details = Instance.new("TextLabel")
	details.Position = UDim2.fromScale(0.08, 0.34)
	details.Size = UDim2.fromScale(0.84, 0.56)
	details.BackgroundTransparency = 1
	details.Font = Enum.Font.GothamMedium
	details.Text = body
	details.TextColor3 = Color3.fromRGB(222, 236, 231)
	details.TextScaled = true
	details.TextWrapped = true
	details.Parent = surface
end

makeInfoPanel("SoloPanel", -24, "PLAY SOLO", "Start immediately in your own private Cooper house.")
makeInfoPanel("PartyPanel", 24, "PLAY WITH FRIENDS", "Invite up to three friends, ready up, then launch together.")

for _, x in ipairs({ -27, -18, -9, 0, 9, 18, 27 }) do
	local strip = makePart(decor, "CeilingLight", Vector3.new(5.5, 0.2, 0.8), CFrame.new(x, 18.85, 3), Color3.fromRGB(190, 255, 233), Enum.Material.Neon, 0.12, false)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness = 1.1
	light.Range = 17
	light.Angle = 110
	light.Color = Color3.fromRGB(204, 255, 236)
	light.Parent = strip
end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 0.35, 8)
spawn.CFrame = CFrame.new(0, 0.25, 18) * CFrame.Angles(0, math.rad(180), 0)
spawn.Color = amber
spawn.Material = Enum.Material.Neon
spawn.Transparency = 0.2
spawn.Neutral = true
spawn.AllowTeamChangeOnTouch = false
spawn.Duration = 0
spawn.Parent = environment

local lobbyFolder = Instance.new("Folder")
lobbyFolder.Name = "CooperLobby"
lobbyFolder.Parent = ReplicatedStorage

local config = Instance.new("ModuleScript")
config.Name = "Config"
config.Source = "return {} -- synchronized from lobby/CooperLobbyConfig.module.luau"
config.Parent = lobbyFolder

local protocol = Instance.new("ModuleScript")
protocol.Name = "CooperPartyProtocol"
protocol.Source = "return {} -- synchronized from CooperPartyProtocol.module.luau"
protocol.Parent = ReplicatedStorage

local server = Instance.new("Script")
server.Name = "CooperLobby"
server.Source = "-- synchronized from lobby/CooperLobby.server.luau"
server.Parent = ServerScriptService

local client = Instance.new("LocalScript")
client.Name = "CooperLobby"
client.Source = "-- synchronized from lobby/CooperLobby.client.luau"
client.Parent = StarterPlayer.StarterPlayerScripts

ChangeHistoryService:SetWaypoint("Milestone 1 lobby environment installed")

print("[CooperLobbyBuilder] Lightweight party lobby environment and source slots installed")
return true
