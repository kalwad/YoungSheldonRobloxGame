-- Run once from the Studio command bar in EDIT mode.
-- Creates the replicated contract, crisis world, server controller placeholder,
-- and responsive client placeholder. Inject the companion sources afterward.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

assert(not RunService:IsRunning(), "Stop the playtest before installing CooperCrisis")

local familyRoot = ReplicatedStorage:FindFirstChild("CooperGame")
assert(familyRoot and familyRoot:IsA("Folder"), "Install the personal Family game foundation before CooperCrisis")
local familyConfigModule = familyRoot:FindFirstChild("Config")
local familyState = familyRoot:FindFirstChild("State")
assert(familyConfigModule and familyConfigModule:IsA("ModuleScript"), "ReplicatedStorage.CooperGame.Config is required")
assert(familyState and familyState:IsA("Folder"), "ReplicatedStorage.CooperGame.State is required")
local configOK, FamilyConfig = pcall(require, familyConfigModule)
assert(configOK and type(FamilyConfig) == "table", "CooperGame.Config must load before installing CooperCrisis")
assert((tonumber(FamilyConfig.SchemaVersion) or 0) >= 2, "CooperCrisis requires the personal Family schema (SchemaVersion >= 2)")
assert(type(FamilyConfig.Mode) == "table", "CooperGame.Config.Mode is required")
for _, modeName in ipairs({ "Normal", "Panic", "Tornado", "DESRaid", "Finale", "Victory" }) do
	assert(type(FamilyConfig.Mode[modeName]) == "string", "CooperGame.Config.Mode." .. modeName .. " is required")
end
local familyEvents = ServerScriptService:FindFirstChild(FamilyConfig.ServerEventsName or "CooperGameServerEvents")
local familyAPI = familyEvents and familyEvents:FindFirstChild("API")
local familyServer = ServerScriptService:FindFirstChild("CooperGame")
assert(familyEvents and familyEvents:IsA("Folder"), "CooperGameServerEvents is required")
assert(familyAPI and familyAPI:IsA("BindableFunction"), "CooperGameServerEvents.API is required")
assert(familyServer and familyServer:IsA("Script"), "ServerScriptService.CooperGame is required")
assert(#familyServer.Source > 10000 and familyServer.Source:find("Personal, persistent family tasks", 1, true), "Inject the current Family server source before installing CooperCrisis")
assert(familyServer.Disabled == false, "Enable ServerScriptService.CooperGame before installing CooperCrisis")

local environment = workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment is required")
local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(starterScripts, "StarterPlayerScripts is required")

local INSTALL_VERSION = "2026-07-13.2"
local stageSuffix = tostring(math.floor(os.clock() * 100000))

for _, child in ipairs(ReplicatedStorage:GetChildren()) do
	if child.Name:match("^_CooperCrisisStage_") then
		child:Destroy()
	end
end
for _, child in ipairs(ServerScriptService:GetChildren()) do
	if child.Name:match("^_CooperCrisisServerStage_") then
		child:Destroy()
	end
end
for _, child in ipairs(starterScripts:GetChildren()) do
	if child.Name:match("^_CooperCrisisClientStage_") then
		child:Destroy()
	end
end
for _, child in ipairs(environment:GetChildren()) do
	if child.Name:match("^_CooperCrisisWorldStage_") then
		child:Destroy()
	end
end

-- Prefer DetachedGarage-relative storm placement so props do not fuse into the
-- Georgie/Mandy living furniture after garage expansion.
local garage = environment:FindFirstChild("DetachedGarage")
local foundation = garage and garage:FindFirstChild("GarageFoundation")
local garageFloorY = foundation and (foundation.Position.Y + foundation.Size.Y * 0.5) or 1.6
local stormX = foundation and (foundation.Position.X - foundation.Size.X * 0.5 + 2.8) or -28.1
local stormZ = foundation and (foundation.Position.Z + foundation.Size.Z * 0.5 - 4.5) or 88.8
local stormLockerCF = CFrame.new(stormX, garageFloorY + 2.9, stormZ - 2.2)
local stormStrapCF = CFrame.new(stormX + 0.1, garageFloorY + 2.2, stormZ + 2.6)
local falseCabinetCF = CFrame.new(stormX + 0.8, garageFloorY + 2.8, (foundation and foundation.Position.Z or 80) + 1.0)
	* CFrame.Angles(0, math.rad(90), 0)

local function setAttrs(instance, attrs)
	for name, value in pairs(attrs or {}) do
		instance:SetAttribute(name, value)
	end
end

local function part(parent, name, size, cframe, color, material, attrs)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	setAttrs(object, attrs)
	object.Parent = parent
	return object
end

local function prompt(parent, name, actionText, objectText, holdDuration)
	local object = Instance.new("ProximityPrompt")
	local baseHoldDuration = holdDuration or 0.8
	object.Name = name
	object.ActionText = actionText
	object.ObjectText = objectText
	object.HoldDuration = baseHoldDuration
	object.MaxActivationDistance = 11
	object.RequiresLineOfSight = false
	object.KeyboardKeyCode = Enum.KeyCode.E
	object.GamepadKeyCode = Enum.KeyCode.ButtonX
	object:SetAttribute("CooperCrisisInteraction", true)
	object:SetAttribute("CooperBaseHoldDuration", baseHoldDuration)
	object.Parent = parent
	return object
end

local function label(partObject, title, subtitle, color)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Display"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 42
	surface.Parent = partObject
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(17, 23, 29)
	frame.BorderSizePixel = 0
	frame.Parent = surface
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromScale(0.05, 0.08)
	titleLabel.Size = UDim2.fromScale(0.9, 0.52)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = true
	titleLabel.Parent = frame
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Position = UDim2.fromScale(0.07, 0.62)
	subtitleLabel.Size = UDim2.fromScale(0.86, 0.25)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(224, 232, 237)
	subtitleLabel.TextScaled = true
	subtitleLabel.TextWrapped = true
	subtitleLabel.Parent = frame
end

local stageReplicated = Instance.new("Folder")
stageReplicated.Name = "_CooperCrisisStage_" .. stageSuffix
stageReplicated:SetAttribute("InstallVersion", INSTALL_VERSION)
stageReplicated.Parent = ReplicatedStorage

local state = Instance.new("Folder")
state.Name = "State"
state:SetAttribute("ActiveKind", "None")
state:SetAttribute("Phase", "Idle")
state:SetAttribute("PhaseEndsAt", 0)
state:SetAttribute("Suspicion", 0)
state:SetAttribute("DESScore", 0)
state:SetAttribute("DESTarget", 4)
state:SetAttribute("FamilyContract", "PersonalV2")
state:SetAttribute("FamilySupportsStability", familyState:GetAttribute("SupportsStability") == true)
state:SetAttribute("MaximumPersonalStage", 0)
state:SetAttribute("MaximumPersonalProgress", 0)
state:SetAttribute("LoadedProfileCount", 0)
state:SetAttribute("ProgressionConnected", false)
state:SetAttribute("BrainEventActive", false)
state:SetAttribute("BrainEventEndsAt", 0)
state:SetAttribute("ExternalRunId", "")
state:SetAttribute("FinaleOwned", false)
state:SetAttribute("StormLockerCapacity", 1)
state:SetAttribute("StormLockerUsed", 0)
state.Parent = stageReplicated

for _, name in ipairs({ "Event", "Request" }) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = stageReplicated
end

local stageWorld = Instance.new("Model")
stageWorld.Name = "_CooperCrisisWorldStage_" .. stageSuffix
stageWorld:SetAttribute("InstallVersion", INSTALL_VERSION)
stageWorld.Parent = environment

local locker = Instance.new("Model")
locker.Name = "StormLocker"
locker.Parent = stageWorld
local lockerBody = part(locker, "LockerBody", Vector3.new(4.6, 5.7, 2.2), stormLockerCF, Color3.fromRGB(72, 103, 86), Enum.Material.Metal)
local lockerDoor = part(locker, "LockerDoor", Vector3.new(4.15, 5.15, 0.22), stormLockerCF * CFrame.new(0, 0, -1.22), Color3.fromRGB(93, 133, 108), Enum.Material.Metal)
part(locker, "LockerHandle", Vector3.new(0.18, 1.1, 0.25), stormLockerCF * CFrame.new(1.45, 0, -1.4), Color3.fromRGB(220, 220, 205), Enum.Material.Metal)
label(lockerDoor, "STORM LOCKER", "SECURE LOOSE EQUIPMENT", Color3.fromRGB(159, 242, 176))
prompt(lockerDoor, "SecureStormItemPrompt", "SECURE ITEM", "Storm locker", 1.2)
locker.PrimaryPart = lockerBody

local straps = Instance.new("Model")
straps.Name = "StormStrapStation"
straps.Parent = stageWorld
local strapBody = part(straps, "StationBody", Vector3.new(3.3, 4.2, 1.7), stormStrapCF, Color3.fromRGB(116, 71, 42), Enum.Material.WoodPlanks)
local strapPanel = part(straps, "Panel", Vector3.new(2.9, 3.6, 0.18), stormStrapCF * CFrame.new(0, 0.1, -0.95), Color3.fromRGB(54, 41, 31), Enum.Material.SmoothPlastic)
for index = -1, 1 do
	part(straps, "YellowStrap" .. index, Vector3.new(0.26, 3.2, 0.2), stormStrapCF * CFrame.new(index * 0.76, 0.1, -1.08), Color3.fromRGB(239, 191, 50), Enum.Material.Fabric)
end
label(strapPanel, "STORM STRAPS", "LOCK DOWN NEARBY GEAR", Color3.fromRGB(255, 209, 78))
prompt(strapPanel, "ApplyStormStrapPrompt", "APPLY STRAP", "Storm strap rack", 1.1)
straps.PrimaryPart = strapBody

local permit = Instance.new("Model")
permit.Name = "DESPermitTerminal"
permit.Parent = stageWorld
local permitBody = part(permit, "TerminalBody", Vector3.new(3.8, 4.2, 2.0), CFrame.new(-3.7, 3.2, 76.8) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(61, 78, 83), Enum.Material.Metal)
local permitScreen = part(permit, "PermitScreen", Vector3.new(3.15, 2.15, 0.18), CFrame.new(-4.76, 3.65, 76.8) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(15, 40, 46), Enum.Material.Neon)
label(permitScreen, "D.E.S. FORM 1955-A", "PRINT LEGAL PERMIT", Color3.fromRGB(119, 230, 245))
prompt(permitScreen, "PrintPermitPrompt", "PRINT PERMIT", "Legal route", 2.4).Enabled = false
permit.PrimaryPart = permitBody

local cabinet = Instance.new("Model")
cabinet.Name = "DESFalseCabinet"
cabinet.Parent = stageWorld
local cabinetBody = part(cabinet, "CabinetBody", Vector3.new(5.1, 5.4, 1.9), falseCabinetCF, Color3.fromRGB(104, 72, 43), Enum.Material.WoodPlanks)
local cabinetFront = part(cabinet, "FalseFront", Vector3.new(4.6, 4.85, 0.18), falseCabinetCF * CFrame.new(0, 0, -1.04), Color3.fromRGB(128, 91, 54), Enum.Material.WoodPlanks)
label(cabinetFront, "TOTALLY NORMAL CABINET", "NO TIME TECHNOLOGY HERE", Color3.fromRGB(245, 211, 134))
prompt(cabinetFront, "ConcealTechPrompt", "HIDE TECH", "Concealment route", 2).Enabled = false
cabinet.PrimaryPart = cabinetBody

local distraction = Instance.new("Model")
distraction.Name = "DESDistractionSwitch"
distraction.Parent = stageWorld
-- Wall-mounted beside the den TV. Keep the button below the labeled panel so
-- it never hides the text.
local distractionFacing = -Vector3.xAxis
local distractionBodyPosition = Vector3.new(16.19, 6.60, 18.00)
local distractionButtonPosition = Vector3.new(16.22, 3.85, 18.00)
local distractionBody = part(
	distraction,
	"SwitchBox",
	Vector3.new(3.4, 3.6, 0.45),
	CFrame.lookAt(distractionBodyPosition, distractionBodyPosition + distractionFacing, Vector3.yAxis),
	Color3.fromRGB(76, 79, 74),
	Enum.Material.Metal
)
local redButton = part(
	distraction,
	"RedButton",
	Vector3.new(1.1, 1.1, 0.35),
	CFrame.lookAt(distractionButtonPosition, distractionButtonPosition + distractionFacing, Vector3.yAxis),
	Color3.fromRGB(210, 52, 42),
	Enum.Material.Neon
)
label(distractionBody, "HARMLESS\nHOUSE ISSUE", "D.E.S. LOOK OVER HERE", Color3.fromRGB(255, 127, 100))
prompt(redButton, "DistractDESPrompt", "CAUSE DISTRACTION", "Distraction route", 1.8).Enabled = false
distraction.PrimaryPart = distractionBody

local visual = Instance.new("Model")
visual.Name = "TornadoVisual"
visual.Parent = stageWorld
local visualAnchor = part(visual, "StormCenter", Vector3.new(1, 1, 1), CFrame.new(48, 21, 75), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
visualAnchor.Transparency = 1
visualAnchor.CanCollide = false
local attachment = Instance.new("Attachment")
attachment.Name = "WindAttachment"
attachment.Parent = visualAnchor
local emitter = Instance.new("ParticleEmitter")
emitter.Name = "DebrisCloud"
emitter.Enabled = false
emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
emitter.Color = ColorSequence.new(Color3.fromRGB(92, 91, 78), Color3.fromRGB(44, 49, 53))
emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(0.6, 17), NumberSequenceKeypoint.new(1, 2) })
emitter.Lifetime = NumberRange.new(4, 7)
emitter.Rate = 125
emitter.Speed = NumberRange.new(19, 32)
emitter.Rotation = NumberRange.new(0, 360)
emitter.RotSpeed = NumberRange.new(-180, 180)
emitter.SpreadAngle = Vector2.new(55, 55)
emitter.Acceleration = Vector3.new(-14, 12, 3)
emitter.Parent = attachment
visual.PrimaryPart = visualAnchor

local inspectorFolder = Instance.new("Folder")
inspectorFolder.Name = "DESInspectors"
inspectorFolder.Parent = stageWorld
for index, position in ipairs({ Vector3.new(-20.5, 4.1, 61.8), Vector3.new(-13.0, 4.1, 61.6) }) do
	local inspector = Instance.new("Model")
	inspector.Name = "DESAgent" .. index
	inspector.Parent = inspectorFolder
	local hitbox = part(inspector, "Hitbox", Vector3.new(2.4, 6.2, 0.8), CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(18, 25, 28), Enum.Material.SmoothPlastic)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Name = "Cutout"
	gui.Size = UDim2.fromOffset(220, 330)
	gui.StudsOffset = Vector3.new(0, 0.3, 0)
	gui.AlwaysOnTop = false
	gui.Enabled = false
	gui.Parent = hitbox
	local cutout = Instance.new("TextLabel")
	cutout.Size = UDim2.fromScale(1, 1)
	cutout.BackgroundColor3 = Color3.fromRGB(27, 39, 44)
	cutout.BackgroundTransparency = 0.03
	cutout.BorderSizePixel = 0
	cutout.Font = Enum.Font.GothamBlack
	cutout.Text = "D.E.S.\nAGENT\n▣"
	cutout.TextColor3 = Color3.fromRGB(180, 231, 238)
	cutout.TextScaled = true
	cutout.TextWrapped = true
	cutout.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = cutout
	inspector.PrimaryPart = hitbox
end

local aftermath = Instance.new("Folder")
aftermath.Name = "AftermathSpawns"
aftermath.Parent = stageWorld
local aftermathPositions = {
	Vector3.new(6, 20.5, 26), -- roof
	Vector3.new(31, 2.1, -12), -- front yard
	Vector3.new(-35, 2.1, 15), -- street edge
	Vector3.new(43, 8, 42), -- tree area
	Vector3.new(-23, 5.9, 8), -- station wagon
	Vector3.new(56, 11, 4), -- utility-side high point
}
for index, position in ipairs(aftermathPositions) do
	local marker = part(aftermath, string.format("RecoveryPoint%02d", index), Vector3.new(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	marker.Transparency = 1
	marker.CanCollide = false
end

local evidence = Instance.new("Model")
evidence.Name = "EvidenceHold"
evidence.Parent = stageWorld
local holdFloor = part(evidence, "EvidencePlatform", Vector3.new(8, 0.5, 6), CFrame.new(-38, 1.4, 73), Color3.fromRGB(53, 61, 64), Enum.Material.Metal)
for _, data in ipairs({
	{ Vector3.new(8, 4, 0.18), CFrame.new(-38, 3.5, 70) },
	{ Vector3.new(8, 4, 0.18), CFrame.new(-38, 3.5, 76) },
	{ Vector3.new(0.18, 4, 6), CFrame.new(-42, 3.5, 73) },
	{ Vector3.new(0.18, 4, 6), CFrame.new(-34, 3.5, 73) },
}) do
	local bar = part(evidence, "EvidenceFence", data[1], data[2], Color3.fromRGB(92, 109, 112), Enum.Material.Metal)
	bar.Transparency = 0.35
	bar.CanCollide = true
end
evidence.PrimaryPart = holdFloor

local loose = Instance.new("Folder")
loose.Name = "LooseCrisisEquipment"
loose.Parent = stageWorld
-- Keep loose storm gear in the west utility lane. The Time Machine workbench
-- occupies the garage center/right, so hard-coded legacy positions there fuse
-- the coolant tank and antenna into its controls.
local looseX = stormX + 3.7
local looseCenterZ = foundation and foundation.Position.Z or 80
local toolboxModel = Instance.new("Model")
toolboxModel.Name = "PortableToolbox"
setAttrs(toolboxModel, { StormEligible = true, TornadoEligible = true, MachineEquipment = true, SuspiciousTech = false })
toolboxModel.Parent = loose
local toolbox = part(toolboxModel, "Body", Vector3.new(2.8, 1.3, 1.5), CFrame.new(looseX, garageFloorY + 0.8, looseCenterZ), Color3.fromRGB(176, 50, 43), Enum.Material.Metal)
part(toolboxModel, "Handle", Vector3.new(1.5, 0.18, 0.18), toolbox.CFrame * CFrame.new(0, 0.95, 0), Color3.fromRGB(40, 43, 45), Enum.Material.Metal).CanCollide = false
toolboxModel.PrimaryPart = toolbox

local coolantModel = Instance.new("Model")
coolantModel.Name = "FictionalCoolantCanister"
setAttrs(coolantModel, { StormEligible = true, TornadoEligible = true, MachineEquipment = true, SuspiciousTech = true })
coolantModel.Parent = loose
local coolant = part(coolantModel, "Tank", Vector3.new(3.1, 1.5, 1.5), CFrame.new(looseX, garageFloorY + 1.4, looseCenterZ - 3.3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(76, 168, 188), Enum.Material.Metal)
coolant.Shape = Enum.PartType.Cylinder
local coolantCap = part(coolantModel, "Cap", Vector3.new(0.35, 0.65, 0.65), coolant.CFrame * CFrame.new(1.7, 0, 0), Color3.fromRGB(34, 77, 88), Enum.Material.Metal)
coolantCap.Shape = Enum.PartType.Cylinder
coolantModel.PrimaryPart = coolant

local antennaModel = Instance.new("Model")
antennaModel.Name = "TemporalAntenna"
setAttrs(antennaModel, { StormEligible = true, TornadoEligible = true, MachineEquipment = true, SuspiciousTech = true })
antennaModel.Parent = loose
local antenna = part(antennaModel, "Mast", Vector3.new(0.5, 4.8, 0.5), CFrame.new(looseX, garageFloorY + 2.5, looseCenterZ + 3.3), Color3.fromRGB(178, 180, 168), Enum.Material.Metal)
local dish = part(antennaModel, "Dish", Vector3.new(2.3, 0.35, 2.3), antenna.CFrame * CFrame.new(0, 2.1, 0), Color3.fromRGB(122, 134, 135), Enum.Material.Metal)
dish.Shape = Enum.PartType.Ball
antennaModel.PrimaryPart = antenna

local stageServer = Instance.new("Script")
stageServer.Name = "_CooperCrisisServerStage_" .. stageSuffix
stageServer.Source = "-- Source is injected from CooperCrisis.server.luau after installation."
stageServer.Disabled = true
stageServer.Parent = ServerScriptService

local stageClient = Instance.new("LocalScript")
stageClient.Name = "_CooperCrisisClientStage_" .. stageSuffix
stageClient.Source = "-- Source is injected from CooperCrisis.client.luau after installation."
stageClient.Disabled = true
stageClient.Parent = starterScripts

assert(stageReplicated:FindFirstChild("State") and stageReplicated:FindFirstChild("Event") and stageReplicated:FindFirstChild("Request"), "Replicated preflight failed")
assert(stageWorld:FindFirstChild("StormLocker") and stageWorld:FindFirstChild("DESInspectors") and stageWorld:FindFirstChild("AftermathSpawns"), "World preflight failed")
assert(#stageWorld:GetDescendants() >= 40, "Crisis world was unexpectedly sparse")

local oldReplicated = ReplicatedStorage:FindFirstChild("CooperCrisis")
local oldWorld = environment:FindFirstChild("CooperCrisisWorld")
local oldServer = ServerScriptService:FindFirstChild("CooperCrisis")
local oldClient = starterScripts:FindFirstChild("CooperCrisisClient")
assert(not oldReplicated or oldReplicated:IsA("Folder"), "ReplicatedStorage.CooperCrisis must be a Folder")
assert(not oldWorld or oldWorld:IsA("Model"), "CooperCrisisWorld must be a Model")
assert(not oldServer or oldServer:IsA("Script"), "ServerScriptService.CooperCrisis must be a Script")
assert(not oldClient or oldClient:IsA("LocalScript"), "StarterPlayerScripts.CooperCrisisClient must be a LocalScript")
if oldServer and oldServer:IsA("Script") then oldServer.Disabled = true end
if oldClient and oldClient:IsA("LocalScript") then oldClient.Disabled = true end

stageReplicated.Name = "CooperCrisis"
stageWorld.Name = "CooperCrisisWorld"
stageServer.Name = "CooperCrisis"
stageClient.Name = "CooperCrisisClient"

if oldReplicated then oldReplicated:Destroy() end
if oldWorld then oldWorld:Destroy() end
if oldServer then oldServer:Destroy() end
if oldClient then oldClient:Destroy() end

local crisisEvents = ServerScriptService:FindFirstChild("CooperCrisisServerEvents")
if not crisisEvents then
	crisisEvents = Instance.new("Folder")
	crisisEvents.Name = "CooperCrisisServerEvents"
	crisisEvents.Parent = ServerScriptService
end
for className, name in pairs({ BindableFunction = "API", BindableEvent = "Resolved" }) do
	local existing = crisisEvents:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		local bindable = Instance.new(className)
		bindable.Name = name
		bindable.Parent = crisisEvents
	end
end

ChangeHistoryService:SetWaypoint("Install Cooper Crisis Director " .. INSTALL_VERSION)
print(string.format("[CooperCrisisInstaller] Installed %s (%d world descendants); inject controller sources, then enable both scripts", INSTALL_VERSION, #stageWorld:GetDescendants()))
