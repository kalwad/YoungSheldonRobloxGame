-- Complete Cooper Time Machine + advanced progression world installer.
-- Run in Studio edit mode after the detached garage exists. Idempotent and
-- staged: canonical models are replaced only after the new build validates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Run time_machine_install.luau in edit mode")

local INSTALL_VERSION = "2026-07-13.tm.family.3"
local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment missing")
local garage = environment:FindFirstChild("DetachedGarage")
assert(garage and garage:IsA("Model"), "DetachedGarage missing")
local foundation = garage:FindFirstChild("GarageFoundation")
assert(foundation and foundation:IsA("BasePart"), "DetachedGarage.GarageFoundation missing")
local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(starterScripts, "StarterPlayer.StarterPlayerScripts missing")

local function ensure(parent, className, name)
	local item = parent:FindFirstChild(name)
	if item and item.ClassName ~= className then
		item:Destroy()
		item = nil
	end
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Parent = parent
	end
	return item
end

-- Runtime hierarchy. Source injection remains an explicit post-install step so
-- this command never overwrites newer local Config/server sources.
local progressionRoot = ensure(ReplicatedStorage, "Folder", "CooperProgression")
progressionRoot:SetAttribute("InstallVersion", INSTALL_VERSION)
ensure(progressionRoot, "Folder", "State")
local remotes = ensure(progressionRoot, "Folder", "Remotes")
for _, name in ipairs({ "Snapshot", "Feedback", "Request", "Finale" }) do
	ensure(remotes, "RemoteEvent", name)
end
local configModule = ensure(progressionRoot, "ModuleScript", "Config")
if configModule.Source == "" or configModule.Source == "return {}" then
	configModule.Source = "error('Inject CooperProgressionConfig.module.luau before enabling CooperProgression')"
	configModule:SetAttribute("NeedsSourceInjection", true)
end

local serverEvents = ensure(ServerScriptService, "Folder", "CooperProgressionServerEvents")
ensure(serverEvents, "BindableFunction", "API")
for _, name in ipairs({ "RegisterCrisis", "CrisisRequest", "CrisisResolved" }) do
	ensure(serverEvents, "BindableEvent", name)
end
local progressionScript = ensure(ServerScriptService, "Script", "CooperProgression")
if progressionScript.Source == "" or string.find(progressionScript.Source, "Hello world", 1, true) then
	progressionScript.Source = "error('Inject CooperProgression.server.luau before enabling CooperProgression')"
	progressionScript:SetAttribute("NeedsSourceInjection", true)
	progressionScript.Disabled = true
end

-- Preserve an already-injected presentation client across idempotent world
-- reinstalls. A new or placeholder client remains disabled until the companion
-- CooperProgression.client.luau source is injected explicitly.
local progressionClient = starterScripts:FindFirstChild("CooperProgression")
if progressionClient then
	assert(progressionClient:IsA("LocalScript"), "StarterPlayerScripts.CooperProgression must be a LocalScript")
else
	progressionClient = Instance.new("LocalScript")
	progressionClient.Name = "CooperProgression"
	progressionClient.Parent = starterScripts
end
progressionClient:SetAttribute("SourceFile", "CooperProgression.client.luau")
progressionClient:SetAttribute("InstallVersion", INSTALL_VERSION)
local clientSource = progressionClient.Source
local clientHasSource = #clientSource > 500
	and not string.find(clientSource, "Inject CooperProgression.client.luau", 1, true)
	and not string.find(clientSource, "Hello world", 1, true)
if clientHasSource then
	progressionClient:SetAttribute("NeedsSourceInjection", nil)
	progressionClient:SetAttribute("InstallState", "Ready")
else
	progressionClient.Source = "error('Inject CooperProgression.client.luau before enabling CooperProgression client')"
	progressionClient:SetAttribute("NeedsSourceInjection", true)
	progressionClient:SetAttribute("InstallState", "AwaitingSource")
	progressionClient.Disabled = true
end

local function part(parent, name, size, cframe, color, material, transparency, canCollide)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Transparency = transparency or 0
	item.Anchored = true
	item.CanCollide = canCollide == true
	item.CanTouch = false
	item.CanQuery = true
	item.CastShadow = item.Transparency < 0.8
	item.Parent = parent
	return item
end

local function prompt(parent, actionText, objectText, holdDuration)
	local item = Instance.new("ProximityPrompt")
	item.Name = "Prompt"
	item.ActionText = actionText
	item.ObjectText = objectText
	item.HoldDuration = holdDuration or 0.45
	item.MaxActivationDistance = 12
	item.RequiresLineOfSight = false
	item.KeyboardKeyCode = Enum.KeyCode.E
	item.GamepadKeyCode = Enum.KeyCode.ButtonX
	item.Parent = parent
	return item
end

local floorY = foundation.Position.Y + foundation.Size.Y * 0.5
local center = foundation.Position
local buildX = center.X + 2.5
local buildZ = center.Z + 1.5

local machine = Instance.new("Model")
machine.Name = "__CooperTimeMachine_Staging"
machine:SetAttribute("InstallVersion", INSTALL_VERSION)
machine:SetAttribute("MachineStage", 0)
machine:SetAttribute("MachineProgress", 0)
machine:SetAttribute("EconomyOwner", "CooperGame")
machine:SetAttribute("OrderingOwner", "CooperGame")
machine.Parent = garage

local base = part(
	machine,
	"WorkbenchBase",
	Vector3.new(10, 0.6, 6.5),
	CFrame.new(buildX, floorY + 0.35, buildZ),
	Color3.fromRGB(92, 68, 45),
	Enum.Material.WoodPlanks,
	0,
	true
)
machine.PrimaryPart = base

local stages = Instance.new("Folder")
stages.Name = "Stages"
stages.Parent = machine

local stageDefs = {
	{ 1, "BlueprintBench", Color3.fromRGB(214, 196, 150), Vector3.new(3.2, 1.4, 2.2), CFrame.new(buildX - 2.8, floorY + 1.4, buildZ - 1.4), Enum.Material.WoodPlanks },
	{ 2, "ClockCore", Color3.fromRGB(180, 170, 120), Vector3.new(1.6, 1.6, 1.6), CFrame.new(buildX - 0.5, floorY + 2.0, buildZ - 1.6), Enum.Material.Metal },
	{ 3, "PowerRouter", Color3.fromRGB(70, 90, 110), Vector3.new(2.4, 1.8, 1.5), CFrame.new(buildX + 2.2, floorY + 1.6, buildZ - 1.5), Enum.Material.Metal },
	{ 4, "LogicTerminalArray", Color3.fromRGB(40, 48, 55), Vector3.new(3.0, 2.2, 1.2), CFrame.new(buildX - 2.4, floorY + 2.2, buildZ + 1.5), Enum.Material.Metal },
	{ 5, "TemporalFrame", Color3.fromRGB(120, 125, 130), Vector3.new(5.5, 0.35, 4.2), CFrame.new(buildX, floorY + 3.4, buildZ), Enum.Material.DiamondPlate },
	{ 6, "NavigationUnit", Color3.fromRGB(90, 140, 170), Vector3.new(1.8, 1.2, 1.8), CFrame.new(buildX + 2.4, floorY + 2.4, buildZ + 1.4), Enum.Material.Metal },
	{ 7, "GarageReactor", Color3.fromRGB(70, 130, 90), Vector3.new(2.6, 3.2, 2.6), CFrame.new(buildX + 0.2, floorY + 2.4, buildZ + 0.2), Enum.Material.Metal },
	{ 8, "ChronoCore", Color3.fromRGB(180, 90, 220), Vector3.new(1.4, 1.4, 1.4), CFrame.new(buildX, floorY + 4.2, buildZ), Enum.Material.Neon },
	{ 9, "WeatherStabilizer", Color3.fromRGB(90, 160, 210), Vector3.new(3.4, 0.5, 3.4), CFrame.new(buildX, floorY + 5.0, buildZ), Enum.Material.Metal },
	{ 10, "PassengerCapsule", Color3.fromRGB(170, 180, 190), Vector3.new(2.4, 3.0, 2.4), CFrame.new(buildX - 2.6, floorY + 2.4, buildZ - 0.2), Enum.Material.Metal },
	{ 11, "FinalCalibration", Color3.fromRGB(240, 210, 90), Vector3.new(0.8, 0.8, 0.8), CFrame.new(buildX, floorY + 5.7, buildZ), Enum.Material.Neon },
}

for _, definition in ipairs(stageDefs) do
	local stage = definition[1]
	local folder = Instance.new("Folder")
	folder.Name = string.format("Stage%02d_%s", stage, definition[2])
	folder:SetAttribute("Stage", stage)
	folder:SetAttribute("RequiredStage", stage)
	folder:SetAttribute("Installed", false)
	folder.Parent = stages
	local piece = part(folder, definition[2], definition[4], definition[5], definition[3], definition[6], 0.08, false)
	piece:SetAttribute("StageVisual", true)
	piece:SetAttribute("BaseTransparency", piece.Transparency)
end

local monitor = part(machine, "CRTMonitor", Vector3.new(1.8, 1.4, 1.1), CFrame.new(buildX - 2.5, floorY + 2.6, buildZ + 1.5), Color3.fromRGB(45, 48, 42), Enum.Material.SmoothPlastic, 0, false)
local screen = part(machine, "CRTScreen", Vector3.new(1.4, 1.0, 0.08), monitor.CFrame * CFrame.new(0, 0, -0.59), Color3.fromRGB(70, 180, 120), Enum.Material.Neon, 0.08, false)
local progressGui = Instance.new("SurfaceGui")
progressGui.Name = "FamilyTaskProgress"
progressGui.Face = Enum.NormalId.Front
progressGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
progressGui.PixelsPerStud = 60
progressGui.Parent = screen
local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "Progress"
progressLabel.Size = UDim2.fromScale(1, 1)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "TIME MACHINE\n0% COMPLETE"
progressLabel.TextColor3 = Color3.fromRGB(155, 255, 190)
progressLabel.Font = Enum.Font.Code
progressLabel.TextScaled = true
progressLabel.Parent = progressGui

for index = 1, 4 do
	local tube = part(
		machine,
		"VacuumTube" .. index,
		Vector3.new(0.35, 1.1, 0.35),
		CFrame.new(buildX - 1.2 + index * 0.45, floorY + 1.5, buildZ - 2.2),
		Color3.fromRGB(180, 90, 70),
		Enum.Material.Glass,
		0.25,
		false
	)
	tube.Shape = Enum.PartType.Cylinder
end
part(machine, "CableBundle", Vector3.new(4.5, 0.18, 0.35), CFrame.new(buildX, floorY + 1.05, buildZ + 2.4) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, 0, false)
part(machine, "ReactorLights", Vector3.new(0.35, 1.6, 0.35), CFrame.new(buildX + 0.2, floorY + 2.5, buildZ - 1.25), Color3.fromRGB(61, 74, 79), Enum.Material.Metal, 0, false)

local controls = Instance.new("Folder")
controls.Name = "Controls"
controls.Parent = machine

local function console(name, actionText, objectText, offset, color)
	local body = part(
		controls,
		name,
		Vector3.new(2.15, 2.5, 1.05),
		CFrame.new(buildX + offset.X, floorY + 1.55, buildZ + offset.Z),
		Color3.fromRGB(55, 62, 70),
		Enum.Material.Metal,
		0,
		true
	)
	local consoleScreen = part(controls, name .. "Screen", Vector3.new(1.65, 0.92, 0.08), body.CFrame * CFrame.new(0, 0.38, -0.565), color or Color3.fromRGB(30, 115, 82), Enum.Material.Neon, 0.08, false)
	consoleScreen.CanQuery = false
	prompt(body, actionText, objectText, 0.45)
	return body
end

console("PurchaseConsole", "Order at Sheldon's Computer", "Component Catalog", Vector3.new(-5.6, 0, 3.1), Color3.fromRGB(65, 140, 220))
console("UpgradeConsole", "Open Upgrade Shop", "Garage Upgrades", Vector3.new(-3.3, 0, 3.25), Color3.fromRGB(190, 125, 240))
console("ReactorConsole", "Manage Reactor", "Garage Reactor", Vector3.new(-1.0, 0, 3.35), Color3.fromRGB(60, 210, 130))
console("ReactorModeConsole", "Cycle Reactor Mode", "Reactor Governor", Vector3.new(1.3, 0, 3.35), Color3.fromRGB(245, 165, 65))
console("CoolantConsole", "Refill Coolant", "Coolant Pump", Vector3.new(3.6, 0, 3.25), Color3.fromRGB(65, 190, 245))
console("LaunchConsole", "Launch Sequence", "Final Calibration", Vector3.new(5.9, 0, 3.1), Color3.fromRGB(245, 210, 70))

local calibrationColors = {
	Clock = Color3.fromRGB(90, 210, 245),
	Navigation = Color3.fromRGB(190, 110, 245),
	Power = Color3.fromRGB(245, 100, 75),
}
for index, id in ipairs({ "Clock", "Navigation", "Power" }) do
	local x = buildX + (index - 2) * 2.2
	local control = part(controls, "Calibration" .. id, Vector3.new(1.7, 1.0, 1.7), CFrame.new(x, floorY + 0.65, buildZ - 3.7), Color3.fromRGB(50, 55, 62), Enum.Material.Metal, 0, true)
	part(controls, "Calibration" .. id .. "Light", Vector3.new(0.9, 0.12, 0.9), control.CFrame * CFrame.new(0, 0.56, 0), calibrationColors[id], Enum.Material.Neon, 0.05, false).CanQuery = false
	prompt(control, "Calibrate " .. id, id .. " control", 3.5)
end

-- This is a private teleport target, not a Roblox respawn point. A plain Part
-- remains in the runtime hierarchy; SpawnLocation instances may be consumed or
-- removed by place-level spawn management after the progression controller has
-- cached them.
local returnSpawn = Instance.new("Part")
returnSpawn.Name = "GarageReturnSpawn"
returnSpawn.Size = Vector3.new(4, 1, 4)
returnSpawn.CFrame = CFrame.new(center.X, floorY + 1.1, center.Z - foundation.Size.Z * 0.35)
returnSpawn.Transparency = 1
returnSpawn.CanCollide = false
returnSpawn.CanTouch = false
returnSpawn.Parent = controls

machine:SetAttribute("ReactorMode", "Safe")
machine:SetAttribute("ReactorLockedUntil", 0)

assert(#stages:GetChildren() == 11, "Time Machine stage build is incomplete")
for _, name in ipairs({ "PurchaseConsole", "UpgradeConsole", "ReactorConsole", "ReactorModeConsole", "CoolantConsole", "LaunchConsole", "CalibrationClock", "CalibrationNavigation", "CalibrationPower", "GarageReturnSpawn" }) do
	assert(controls:FindFirstChild(name), "Missing Time Machine control " .. name)
end

local oldMachine = garage:FindFirstChild("CooperTimeMachine")
if oldMachine then
	oldMachine:Destroy()
end
machine.Name = "CooperTimeMachine"

-- Small sitcom-inspired future apartment used by the finale. It is isolated
-- from the house map and can always return the player to the garage.
local apartment = Instance.new("Model")
apartment.Name = "__CooperFutureApartment_Staging"
apartment:SetAttribute("InstallVersion", INSTALL_VERSION)
apartment.Parent = Workspace
local apartmentOrigin = Vector3.new(center.X + 700, floorY + 35, center.Z)
part(apartment, "ApartmentFloor", Vector3.new(42, 1, 30), CFrame.new(apartmentOrigin), Color3.fromRGB(113, 80, 56), Enum.Material.WoodPlanks, 0, true)
part(apartment, "BackWall", Vector3.new(42, 13, 1), CFrame.new(apartmentOrigin + Vector3.new(0, 6.5, 14.5)), Color3.fromRGB(213, 198, 165), Enum.Material.SmoothPlastic, 0, true)
part(apartment, "LeftWall", Vector3.new(1, 13, 30), CFrame.new(apartmentOrigin + Vector3.new(-20.5, 6.5, 0)), Color3.fromRGB(199, 181, 148), Enum.Material.SmoothPlastic, 0, true)
part(apartment, "RightWall", Vector3.new(1, 13, 30), CFrame.new(apartmentOrigin + Vector3.new(20.5, 6.5, 0)), Color3.fromRGB(199, 181, 148), Enum.Material.SmoothPlastic, 0, true)
part(apartment, "BlueCouch", Vector3.new(9, 3, 3.5), CFrame.new(apartmentOrigin + Vector3.new(0, 2, 6)), Color3.fromRGB(55, 91, 132), Enum.Material.Fabric, 0, true)
part(apartment, "CoffeeTable", Vector3.new(6, 1, 3.2), CFrame.new(apartmentOrigin + Vector3.new(0, 1.1, 1.2)), Color3.fromRGB(83, 54, 36), Enum.Material.Wood, 0, true)
part(apartment, "Whiteboard", Vector3.new(8, 5, 0.3), CFrame.new(apartmentOrigin + Vector3.new(-10, 6, 13.8)), Color3.fromRGB(229, 232, 222), Enum.Material.SmoothPlastic, 0, false)

local futureSpawn = part(apartment, "FutureSpawn", Vector3.new(5, 1, 5), CFrame.new(apartmentOrigin + Vector3.new(0, 1.2, -7)), Color3.fromRGB(90, 215, 255), Enum.Material.Neon, 1, false)
futureSpawn.CanQuery = false
local returnPortal = part(apartment, "ReturnPortal", Vector3.new(4, 7, 0.5), CFrame.new(apartmentOrigin + Vector3.new(14, 3.8, 13.7)), Color3.fromRGB(102, 215, 255), Enum.Material.Neon, 0.18, false)
prompt(returnPortal, "Return to Garage", "Temporal Return Portal", 0.5)

assert(apartment:FindFirstChild("FutureSpawn") and apartment:FindFirstChild("ReturnPortal"), "Future apartment travel anchors missing")
local oldApartment = Workspace:FindFirstChild("CooperFutureApartment")
if oldApartment then
	oldApartment:Destroy()
end
apartment.Name = "CooperFutureApartment"

return {
	version = INSTALL_VERSION,
	machinePath = machine:GetFullName(),
	apartmentPath = apartment:GetFullName(),
	stages = #stages:GetChildren(),
	controls = #controls:GetChildren(),
	configNeedsSource = configModule:GetAttribute("NeedsSourceInjection") == true,
	serverNeedsSource = progressionScript:GetAttribute("NeedsSourceInjection") == true,
	clientNeedsSource = not clientHasSource,
	clientPreserved = clientHasSource,
	clientEnabled = clientHasSource and not progressionClient.Disabled,
}
