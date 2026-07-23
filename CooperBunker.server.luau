-- Server-authoritative controller for the Cooper backyard bunker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CONTROLLER_VERSION = "3.3.0"
local gameRoot = ReplicatedStorage:WaitForChild("CooperGame", 30)
local Config = require(gameRoot:WaitForChild("Config", 30))
local chemistryConfig = Config.ChemistrySetup
assert(type(chemistryConfig) == "table", "CooperGame.Config.ChemistrySetup is missing")
local environment = Workspace:WaitForChild("CooperHouseEnvironment")
local bunker = environment:WaitForChild("BackyardBunker")
assert(bunker:IsA("Model"), "BackyardBunker must be a Model")
assert(bunker:GetAttribute("InstallVersion") == "2.0.0", "BackyardBunker installer is stale")

local surface = bunker:WaitForChild("SurfaceEntrance")
local underground = bunker:WaitForChild("Underground")
local hatchDoor = surface:WaitForChild("HatchDoor")
local hatchPanel = hatchDoor:WaitForChild("Panel")
local hatchControl = surface:WaitForChild("HatchControl")
local hatchPrompt = hatchControl:WaitForChild("HatchPrompt")
local shaftOpening = surface:WaitForChild("ShaftOpening")
local warningBeacon = surface:WaitForChild("WarningBeacon")
local beaconLight = warningBeacon:WaitForChild("BeaconLight")

-- This shared-world bunker can be visible because another player built it,
-- while access is still a personal purchase. Keep a solid invisible throat
-- gate in place and selectively exempt only entitled character parts below.
local accessGate = surface:FindFirstChild("BunkerAccessGate")
if accessGate and not accessGate:IsA("BasePart") then
	accessGate:Destroy()
	accessGate = nil
end
if not accessGate then
	accessGate = Instance.new("Part")
	accessGate.Name = "BunkerAccessGate"
	accessGate.Parent = surface
end
accessGate.Anchored = true
accessGate.CanCollide = true
accessGate.CanTouch = false
accessGate.CanQuery = false
accessGate.CastShadow = false
accessGate.Transparency = 1
accessGate.Size = Vector3.new(
	math.max(1, shaftOpening.Size.X),
	0.38,
	math.max(1, shaftOpening.Size.Z)
)
accessGate.CFrame = shaftOpening.CFrame * CFrame.new(0, -0.55, 0)
accessGate:SetAttribute("BunkerAccessGate", true)

local blastDoor = underground:WaitForChild("BlastDoor")
local leftPanel = blastDoor:WaitForChild("LeftPanel")
local rightPanel = blastDoor:WaitForChild("RightPanel")
local blastDoorControl = underground:WaitForChild("BlastDoorControl")
local blastDoorPrompt = blastDoorControl:WaitForChild("BlastDoorPrompt")
local lightControl = underground:WaitForChild("LightControl")
local lightPrompt = lightControl:WaitForChild("LightPrompt")
local recoveryZone = underground:WaitForChild("RecoveryZone")
local recoveryAnchor = underground:WaitForChild("RecoveryAnchor")
local mainLights = underground:WaitForChild("MainLights")
local statusConsole = underground:WaitForChild("StatusConsole")
local ventilation = underground:WaitForChild("Ventilation")
local fanBlades = ventilation:WaitForChild("FanBlades")

assert(hatchDoor:IsA("Model"), "HatchDoor must be a Model")
assert(hatchPanel:IsA("BasePart"), "HatchDoor.Panel must be a BasePart")
assert(hatchPrompt:IsA("ProximityPrompt"), "HatchPrompt must be a ProximityPrompt")
assert(shaftOpening:IsA("BasePart"), "SurfaceEntrance.ShaftOpening must be a BasePart")
assert(leftPanel:IsA("BasePart") and rightPanel:IsA("BasePart"), "BlastDoor panels are missing")
assert(blastDoorPrompt:IsA("ProximityPrompt"), "BlastDoorPrompt must be a ProximityPrompt")
assert(lightPrompt:IsA("ProximityPrompt"), "LightPrompt must be a ProximityPrompt")
assert(recoveryZone:IsA("BasePart"), "RecoveryZone must be a BasePart")
assert(recoveryAnchor:IsA("BasePart"), "RecoveryAnchor must be a BasePart")

local remotes = ReplicatedStorage:WaitForChild("CooperBunkerRemotes")
local event = remotes:WaitForChild("BunkerEvent")
assert(event:IsA("RemoteEvent"), "CooperBunkerRemotes.BunkerEvent must be a RemoteEvent")

-- BUNKER RESEARCH TERMINAL + CHEMISTRY LAB -------------------------------
-- These assemblies are rebuilt from live bunker furniture every server so a
-- relocated house can never leave world-space CFrame attributes behind. Every
-- decorative piece is anchored and noncolliding; only substantial equipment
-- bodies block the player.
local function anchoredPart(parent, name, size, cframe, properties)
	properties = type(properties) == "table" and properties or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = properties.canCollide == true
	part.CanTouch = false
	part.CanQuery = properties.canQuery == true or properties.canCollide == true
	part.CastShadow = properties.castShadow ~= false
	part.Color = properties.color or Color3.fromRGB(38, 47, 54)
	part.Material = properties.material or Enum.Material.Metal
	part.Transparency = tonumber(properties.transparency) or 0
	if properties.shape then
		part.Shape = properties.shape
	end
	part.Parent = parent
	return part
end

local function screenGui(part, name, titleText, bodyText, accent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 450)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = part

	local background = Instance.new("Frame")
	background.Name = "Screen"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(2, 10, 17)
	background.BorderSizePixel = 0
	background.Parent = gui

	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = accent
	border.Thickness = 7
	border.Transparency = 0.12
	border.Parent = background

	for index = 1, 13 do
		local line = Instance.new("Frame")
		line.Name = "GridLine"
		line.Position = UDim2.new(0, 0, (index - 1) / 13, 0)
		line.Size = UDim2.new(1, 0, 0, 2)
		line.BackgroundColor3 = accent
		line.BackgroundTransparency = 0.9
		line.BorderSizePixel = 0
		line.Parent = background
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(28, 22)
	title.Size = UDim2.new(1, -56, 0, 76)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = accent
	title.Font = Enum.Font.RobotoMono
	title.TextSize = 34
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = background

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(28, 108)
	divider.Size = UDim2.new(1, -56, 0, 5)
	divider.BackgroundColor3 = accent
	divider.BackgroundTransparency = 0.22
	divider.BorderSizePixel = 0
	divider.Parent = background

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(28, 132)
	body.Size = UDim2.new(1, -56, 1, -156)
	body.BackgroundTransparency = 1
	body.Text = bodyText
	body.TextColor3 = Color3.fromRGB(189, 244, 255)
	body.Font = Enum.Font.RobotoMono
	body.TextSize = 27
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = background
	return gui, body
end

local mainChamber = underground:WaitForChild("MainChamber")
local workbench = mainChamber:WaitForChild("SteelWorkbench")
assert(workbench:IsA("BasePart"), "Bunker SteelWorkbench is missing")

local oldTerminal = underground:FindFirstChild("BunkerResearchTerminal")
if oldTerminal then
	oldTerminal:Destroy()
end
local researchTerminal = Instance.new("Model")
researchTerminal.Name = "BunkerResearchTerminal"
researchTerminal:SetAttribute("InstallVersion", CONTROLLER_VERSION)
researchTerminal.Parent = underground

local terminalBase = workbench.CFrame
local terminalTop = workbench.Size.Y * 0.5
local function terminalPart(name, size, offset, properties, rotation)
	return anchoredPart(
		researchTerminal,
		name,
		size,
		terminalBase * CFrame.new(offset) * (rotation or CFrame.identity),
		properties
	)
end

terminalPart(
	"ConsoleRiser",
	Vector3.new(9.4, 0.24, 2.9),
	Vector3.new(0, terminalTop + 0.16, 0.22),
	{ color = Color3.fromRGB(22, 29, 36), material = Enum.Material.DiamondPlate }
)
terminalPart(
	"CyanUnderglow",
	Vector3.new(8.9, 0.08, 0.12),
	Vector3.new(0, terminalTop + 0.04, -1.18),
	{ color = Color3.fromRGB(44, 229, 255), material = Enum.Material.Neon, canQuery = false, castShadow = false }
)
for _, x in ipairs({ -3.9, 0, 3.9 }) do
	terminalPart(
		"MonitorSupport",
		Vector3.new(0.24, 2.25, 0.24),
		Vector3.new(x, terminalTop + 1.2, 0.92),
		{ color = Color3.fromRGB(48, 57, 64), material = Enum.Material.Metal, canQuery = false }
	)
end

local centerMonitor = terminalPart(
	"CoreMonitor",
	Vector3.new(4.45, 2.65, 0.24),
	Vector3.new(0, terminalTop + 2.35, 0.82),
	{ color = Color3.fromRGB(12, 18, 24), material = Enum.Material.Metal, canQuery = false }
)
screenGui(
	centerMonitor,
	"ResearchCoreDisplay",
	"COOPER RESEARCH CORE // ONLINE",
	[[LABNET QUANTUM BUS: STABLE
BUNKER POWER: NOMINAL
PROCUREMENT CHANNEL: SECURE]],
	Color3.fromRGB(61, 235, 255)
)

local leftMonitor = terminalPart(
	"MolecularMonitor",
	Vector3.new(2.35, 2.05, 0.22),
	Vector3.new(-3.35, terminalTop + 2.08, 0.67),
	{ color = Color3.fromRGB(13, 18, 26), material = Enum.Material.Metal, canQuery = false },
	CFrame.Angles(0, math.rad(-12), 0)
)
screenGui(
	leftMonitor,
	"MolecularDisplay",
	"MOLECULAR ARRAY",
	[[   ◉──◉
  ╱    ╲
 ◉──◉──◉
SIGNAL: 99.8%]],
	Color3.fromRGB(171, 94, 255)
)

local rightMonitor = terminalPart(
	"ChemistryMonitor",
	Vector3.new(2.35, 2.05, 0.22),
	Vector3.new(3.35, terminalTop + 2.08, 0.67),
	{ color = Color3.fromRGB(13, 18, 26), material = Enum.Material.Metal, canQuery = false },
	CFrame.Angles(0, math.rad(12), 0)
)
local _, terminalChemistryStatus = screenGui(
	rightMonitor,
	"ChemistryDisplay",
	"CHEMISTRY LAB",
	[[EQUIPMENT: AVAILABLE
SELECT LAB PROCUREMENT]],
	Color3.fromRGB(70, 255, 182)
)

local keyboardDeck = terminalPart(
	"BunkerTerminalKeyboard",
	Vector3.new(5.35, 0.18, 1.22),
	Vector3.new(0, terminalTop + 0.42, -0.66),
	{ color = Color3.fromRGB(18, 25, 31), material = Enum.Material.SmoothPlastic, canQuery = false },
	CFrame.Angles(math.rad(-7), 0, 0)
)
for row = 0, 2 do
	for column = 0, 11 do
		local keyColor = if (row + column) % 7 == 0
			then Color3.fromRGB(177, 91, 255)
			else Color3.fromRGB(49, 211, 235)
		terminalPart(
			"ResearchKey",
			Vector3.new(0.31, 0.07, 0.22),
			Vector3.new(-1.84 + column * 0.335, terminalTop + 0.535, -0.95 + row * 0.29),
			{ color = keyColor, material = Enum.Material.Neon, transparency = 0.08, canQuery = false, castShadow = false },
			CFrame.Angles(math.rad(-7), 0, 0)
		)
	end
end
local trackball = terminalPart(
	"QuantumTrackball",
	Vector3.new(0.62, 0.62, 0.62),
	Vector3.new(3.75, terminalTop + 0.61, -0.62),
	{ color = Color3.fromRGB(174, 83, 255), material = Enum.Material.Neon, shape = Enum.PartType.Ball, canQuery = false, castShadow = false }
)
local trackballLight = Instance.new("PointLight")
trackballLight.Name = "TerminalPulseLight"
trackballLight.Color = trackball.Color
trackballLight.Brightness = 1.2
trackballLight.Range = 7
trackballLight.Shadows = false
trackballLight.Parent = trackball

local bunkerTerminalInputAnchor = terminalPart(
	"BunkerTerminalInputAnchor",
	Vector3.new(5.8, 1.5, 2.2),
	Vector3.new(0, terminalTop + 0.72, -1.05),
	{ transparency = 1, canQuery = false, castShadow = false }
)
local researchPrompt = Instance.new("ProximityPrompt")
researchPrompt.Name = "ResearchTerminalPrompt"
researchPrompt.ActionText = "Use Computer"
researchPrompt.ObjectText = "Bunker Research Terminal"
researchPrompt.KeyboardKeyCode = Enum.KeyCode.E
researchPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
researchPrompt.HoldDuration = 0.18
researchPrompt.MaxActivationDistance = 9
researchPrompt.RequiresLineOfSight = false
researchPrompt.Parent = bunkerTerminalInputAnchor

local chemistryBay = underground:WaitForChild("FutureChemistryBay")
local chemistryPad = chemistryBay:WaitForChild("EquipmentPad")
local chemistryInstallAnchor = chemistryBay:WaitForChild(chemistryConfig.InstallTarget)
assert(chemistryPad:IsA("BasePart") and chemistryInstallAnchor:IsA("BasePart"), "Chemistry bay anchors are missing")
chemistryBay:SetAttribute("GameplayEnabled", true)
chemistryInstallAnchor:SetAttribute("GameplayEnabled", true)
bunker:SetAttribute("ChemistryGameplayEnabled", true)

local oldLab = chemistryBay:FindFirstChild(chemistryConfig.ModelName)
if oldLab then
	oldLab:Destroy()
end
local chemistryLab = Instance.new("Model")
chemistryLab.Name = chemistryConfig.ModelName
chemistryLab:SetAttribute("InstallVersion", CONTROLLER_VERSION)
chemistryLab:SetAttribute("Installed", false)
chemistryLab:SetAttribute("ExperimentState", "Idle")
chemistryLab:SetAttribute("ExperimentActive", false)
chemistryLab:SetAttribute("ExperimentStartedAt", 0)
chemistryLab:SetAttribute("ExperimentEndsAt", 0)
chemistryLab:SetAttribute("ExperimentReadyAt", 0)
chemistryLab:SetAttribute("RewardState", "Empty")
chemistryLab:SetAttribute("RewardAvailable", false)
chemistryLab:SetAttribute("RewardOwnerUserId", 0)
chemistryLab:SetAttribute("RewardLeaseExpiresAt", 0)
chemistryLab:SetAttribute("RewardQueueDepth", 0)
chemistryLab.Parent = chemistryBay

local chemistryParts = {}
local chemistryLights = {}
local chemistryGuis = {}
local chemistryBeams = {}
local chemistryFlowBeams = {}
local chemistryEmitters = {}
local chemistryTubeFluids = {}
local chemistryBubbles = {}
local chemistryReservoirs = {}
local chemistryImpellers = {}
local chemistryStatusLamps = {}
local chemistryVisible = false
local chemistryAnimationToken = 0
local chemistryAssemblyActive = false
local chemistryExperimentActive = false
local chemistryExperimentToken = 0
local chemistryExperimentOwnerUserId = 0
local chemistryExperimentReadyAt = 0
local chemistryNextVaporAt = 0
local chemistryRewardAvailable = false
local chemistryRewardOwnerUserId = 0
local chemistryRewardToken = 0
local chemistryRewardClaiming = false
local chemistryDrawerTweens = {}
local CHEMISTRY_EXPERIMENT_DURATION = 12
local CHEMISTRY_EXPERIMENT_COOLDOWN = 4
-- One shared physical output tray is leased, not owned forever. Expired owners
-- rotate to the queue tail and wait through a short retry window so another
-- chemist can collect or start a reaction in the gap.
local candyPresentation = {
	batchToken = "",
	leaseExpiresAt = 0,
	serial = 0,
	queue = {},
	queued = {},
	eligibleAt = {},
	pumping = false,
	leaseSeconds = 35,
	retrySeconds = 12,
	presentRadius = 30,
}

local padFrame = chemistryPad.CFrame
local padTop = chemistryPad.Size.Y * 0.5
local function labPart(name, size, offset, properties, rotation, order)
	properties = type(properties) == "table" and properties or {}
	local part = anchoredPart(
		chemistryLab,
		name,
		size,
		padFrame * CFrame.new(offset) * (rotation or CFrame.identity),
		properties
	)
	part:SetAttribute("ChemistryLabPart", true)
	part:SetAttribute("VisibleTransparency", part.Transparency)
	part:SetAttribute("VisibleCanCollide", part.CanCollide)
	part:SetAttribute("AssemblyOrder", order or 1)
	chemistryParts[part] = {
		cframe = part.CFrame,
		transparency = part.Transparency,
		canCollide = part.CanCollide,
		order = order or 1,
	}
	return part
end

-- Roblox cylinders point along their local X axis. Building every run between
-- explicit local-space endpoints makes the apparatus read as real plumbing from
-- every camera angle instead of as a face-camera beam or a trail of loose dots.
local function cylinderBetween(name, startOffset, endOffset, diameter, properties, order)
	local delta = endOffset - startOffset
	local length = math.max(0.05, delta.Magnitude)
	local right = delta.Magnitude > 0.001 and delta.Unit or Vector3.new(1, 0, 0)
	local upReference = math.abs(right:Dot(Vector3.new(0, 1, 0))) > 0.94
		and Vector3.new(0, 0, 1)
		or Vector3.new(0, 1, 0)
	local back = right:Cross(upReference).Unit
	local up = back:Cross(right).Unit
	local localFrame = CFrame.fromMatrix((startOffset + endOffset) * 0.5, right, up, back)
	properties = type(properties) == "table" and table.clone(properties) or {}
	properties.shape = Enum.PartType.Cylinder
	return labPart(
		name,
		Vector3.new(length, diameter, diameter),
		localFrame.Position,
		properties,
		localFrame.Rotation,
		order
	)
end

local function markChemistryPart(part, attributeName, motionPart)
	part:SetAttribute(attributeName, true)
	if motionPart then
		part:SetAttribute("ChemistryMotionPart", true)
	end
	return part
end

local cabinet = labPart(
	"ReinforcedCabinet",
	Vector3.new(8.8, 1.55, 2.55),
	Vector3.new(0, padTop + 0.78, 3.55),
	{ color = Color3.fromRGB(43, 54, 62), material = Enum.Material.DiamondPlate, canCollide = true },
	nil,
	1
)
for index = 0, 3 do
	labPart(
		"CabinetDoor" .. tostring(index + 1),
		Vector3.new(1.92, 1.22, 0.08),
		Vector3.new(-3.18 + index * 2.12, padTop + 0.78, 2.245),
		{ color = Color3.fromRGB(25, 34, 41), material = Enum.Material.Metal, canQuery = false },
		nil,
		2
	)
	labPart(
		"CabinetHandle" .. tostring(index + 1),
		Vector3.new(0.55, 0.08, 0.08),
		Vector3.new(-3.18 + index * 2.12, padTop + 0.96, 2.19),
		{ color = Color3.fromRGB(77, 231, 244), material = Enum.Material.Neon, canQuery = false, castShadow = false },
		nil,
		4
	)
end
labPart(
	"ChemicalWorkbench",
	Vector3.new(9.2, 0.28, 2.95),
	Vector3.new(0, padTop + 1.68, 3.55),
	{ color = Color3.fromRGB(92, 110, 118), material = Enum.Material.Metal, canCollide = true },
	nil,
	2
)

-- The completed reaction exits through a real under-bench dispenser. The
-- drawer is a reusable anchored assembly: it slides toward the player, vents a
-- short smoke burst, and raises one owner-locked blue rock-candy batch.
local candyOutputBezel = labPart(
	"CandyOutputBezel",
	Vector3.new(2.85, 0.88, 0.16),
	Vector3.new(0, padTop + 1.13, 2.19),
	{ color = Color3.fromRGB(18, 27, 34), material = Enum.Material.Metal, canQuery = false },
	nil,
	3
)
local candyOutputSlot = labPart(
	"CandyOutputSlot",
	Vector3.new(2.3, 0.42, 0.09),
	Vector3.new(0, padTop + 1.28, 2.095),
	{ color = Color3.fromRGB(2, 7, 11), material = Enum.Material.SmoothPlastic, canQuery = false },
	nil,
	4
)
local candyOutputLabelGui = Instance.new("SurfaceGui")
candyOutputLabelGui.Name = "CandyOutputLabel"
candyOutputLabelGui.Face = Enum.NormalId.Front
candyOutputLabelGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
candyOutputLabelGui.PixelsPerStud = 120
candyOutputLabelGui.LightInfluence = 0
candyOutputLabelGui.Parent = candyOutputBezel
local candyOutputLabel = Instance.new("TextLabel")
candyOutputLabel.Size = UDim2.fromScale(1, 1)
candyOutputLabel.BackgroundTransparency = 1
candyOutputLabel.Text = "PRODUCT OUTPUT"
candyOutputLabel.TextColor3 = Color3.fromRGB(67, 231, 255)
candyOutputLabel.Font = Enum.Font.RobotoMono
candyOutputLabel.TextScaled = true
candyOutputLabel.Parent = candyOutputLabelGui
table.insert(chemistryGuis, candyOutputLabelGui)

local chemistryDrawerParts = {}
local function addChemistryDrawerPart(name, size, offset, color, material, primary)
	local part = labPart(
		name,
		size,
		offset,
		{ color = color, material = material, canQuery = false, castShadow = true },
		nil,
		5
	)
	markChemistryPart(part, primary and "ChemistryOutputDrawer" or "ChemistryOutputDrawerDetail", true)
	table.insert(chemistryDrawerParts, {
		part = part,
		homeCFrame = part.CFrame,
		openCFrame = padFrame * CFrame.new(offset + Vector3.new(0, 0, -1.82)),
	})
	return part
end

local chemistryDrawer = addChemistryDrawerPart(
	"ChemistryOutputDrawer",
	Vector3.new(2.34, 0.17, 1.55),
	Vector3.new(0, padTop + 1.61, 2.86),
	Color3.fromRGB(76, 92, 102),
	Enum.Material.Metal,
	true
)
addChemistryDrawerPart(
	"ChemistryOutputDrawerLeftRail",
	Vector3.new(0.13, 0.26, 1.55),
	Vector3.new(-1.105, padTop + 1.75, 2.86),
	Color3.fromRGB(30, 41, 49),
	Enum.Material.Metal,
	false
)
addChemistryDrawerPart(
	"ChemistryOutputDrawerRightRail",
	Vector3.new(0.13, 0.26, 1.55),
	Vector3.new(1.105, padTop + 1.75, 2.86),
	Color3.fromRGB(30, 41, 49),
	Enum.Material.Metal,
	false
)
addChemistryDrawerPart(
	"ChemistryOutputDrawerFrontLip",
	Vector3.new(2.34, 0.34, 0.16),
	Vector3.new(0, padTop + 1.77, 2.12),
	Color3.fromRGB(22, 33, 41),
	Enum.Material.DiamondPlate,
	false
)
local chemistryDrawerHomeCFrame = chemistryDrawer.CFrame

local chemistryRewardPieces = {}
local rewardClosedBase = Vector3.new(0, padTop + 1.61, 2.86)
-- Rest the completed metal pan directly on the extended drawer. The previous
-- height left more than half a stud of empty air beneath it, which made the
-- physical chemistry output read like a levitating magic prop.
local rewardPresentBase = Vector3.new(0, padTop + 1.80, 1.04)
local function addCandyRewardPiece(name, size, relativeOffset, color, material, rotation, visibleTransparency, primary)
	local homeOffset = rewardClosedBase + relativeOffset
	local part = labPart(
		name,
		size,
		homeOffset,
		{
			color = color,
			material = material,
			transparency = 1,
			canQuery = false,
			castShadow = false,
		},
		rotation,
		7
	)
	markChemistryPart(part, primary and "ChemistryCandyReward" or "ChemistryCandyRewardDetail", true)
	table.insert(chemistryRewardPieces, {
		part = part,
		homeCFrame = part.CFrame,
		presentCFrame = padFrame * CFrame.new(rewardPresentBase + relativeOffset) * (rotation or CFrame.identity),
		visibleTransparency = visibleTransparency,
	})
	return part
end

local chemistryReward = addCandyRewardPiece(
	"BlueRockCandyDisplayPan",
	Vector3.new(2.0, 0.14, 1.30),
	Vector3.new(0, 0, 0),
	Color3.fromRGB(131, 145, 151),
	Enum.Material.Metal,
	nil,
	0,
	true
)
for _, definition in ipairs({
	{ name = "Left", size = Vector3.new(0.12, 0.32, 1.30), offset = Vector3.new(-0.94, 0.16, 0) },
	{ name = "Right", size = Vector3.new(0.12, 0.32, 1.30), offset = Vector3.new(0.94, 0.16, 0) },
	{ name = "Front", size = Vector3.new(2.0, 0.32, 0.12), offset = Vector3.new(0, 0.16, -0.59) },
	{ name = "Back", size = Vector3.new(2.0, 0.32, 0.12), offset = Vector3.new(0, 0.16, 0.59) },
}) do
	addCandyRewardPiece(
		"BlueRockCandyDisplayPanRim" .. definition.name,
		definition.size,
		definition.offset,
		Color3.fromRGB(101, 116, 123),
		Enum.Material.Metal,
		nil,
		0,
		false
	)
end
for index, definition in ipairs({
	{ offset = Vector3.new(-0.54, 0.34, -0.22), rotation = CFrame.Angles(math.rad(8), math.rad(18), math.rad(-20)), size = Vector3.new(0.34, 0.58, 0.34) },
	{ offset = Vector3.new(-0.16, 0.30, 0.18), rotation = CFrame.Angles(math.rad(-10), math.rad(-20), math.rad(22)), size = Vector3.new(0.38, 0.52, 0.38) },
	{ offset = Vector3.new(0.25, 0.37, -0.18), rotation = CFrame.Angles(math.rad(20), math.rad(15), math.rad(-10)), size = Vector3.new(0.32, 0.66, 0.32) },
	{ offset = Vector3.new(0.62, 0.28, 0.20), rotation = CFrame.Angles(math.rad(-13), math.rad(26), math.rad(18)), size = Vector3.new(0.30, 0.48, 0.30) },
	{ offset = Vector3.new(0.05, 0.25, -0.30), rotation = CFrame.Angles(math.rad(16), math.rad(-12), math.rad(-16)), size = Vector3.new(0.27, 0.43, 0.27) },
}) do
	addCandyRewardPiece(
		"BlueRockCandyDisplayShard" .. tostring(index),
		definition.size,
		definition.offset,
		index == 2 and Color3.fromRGB(92, 216, 255) or Color3.fromRGB(31, 132, 255),
		Enum.Material.Glass,
		definition.rotation,
		0.08,
		false
	)
end
local chemistryRewardHomeCFrame = chemistryReward.CFrame

local candySmokeNozzle = labPart(
	"CandyOutputSmokeNozzle",
	Vector3.new(0.48, 0.18, 0.28),
	Vector3.new(0, padTop + 1.51, 1.98),
	{ color = Color3.fromRGB(65, 84, 94), material = Enum.Material.Metal, canQuery = false },
	nil,
	5
)
local candySmoke = Instance.new("ParticleEmitter")
candySmoke.Name = "CandySmoke"
candySmoke.Enabled = false
candySmoke.Rate = 0
candySmoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
candySmoke.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(247, 252, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 184, 199)),
})
candySmoke.Lifetime = NumberRange.new(1.65, 2.45)
candySmoke.Speed = NumberRange.new(1.1, 2.35)
candySmoke.Drag = 1.6
candySmoke.Acceleration = Vector3.new(0, 1.45, -0.35)
candySmoke.SpreadAngle = Vector2.new(28, 24)
candySmoke.Rotation = NumberRange.new(0, 360)
candySmoke.RotSpeed = NumberRange.new(-32, 32)
candySmoke.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.42),
	NumberSequenceKeypoint.new(0.45, 0.98),
	NumberSequenceKeypoint.new(1, 1.55),
})
candySmoke.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.02),
	NumberSequenceKeypoint.new(0.65, 0.28),
	NumberSequenceKeypoint.new(1, 1),
})
candySmoke.Parent = candySmokeNozzle
table.insert(chemistryEmitters, candySmoke)

local candyCollectAnchor = labPart(
	"BlueRockCandyCollectAnchor",
	Vector3.new(2.5, 1.8, 2.1),
	Vector3.new(0, padTop + 1.88, 0.92),
	{ transparency = 1, canQuery = false, castShadow = false },
	nil,
	7
)
local collectCandyPrompt = Instance.new("ProximityPrompt")
collectCandyPrompt.Name = "CollectBlueRockCandyPrompt"
collectCandyPrompt.ActionText = "Take Blue Rock Candy"
collectCandyPrompt.ObjectText = "Chemistry Output"
collectCandyPrompt.KeyboardKeyCode = Enum.KeyCode.E
collectCandyPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
collectCandyPrompt.HoldDuration = 0.15
collectCandyPrompt.MaxActivationDistance = 8
collectCandyPrompt.RequiresLineOfSight = false
collectCandyPrompt.Enabled = false
collectCandyPrompt.Parent = candyCollectAnchor

labPart(
	"ExtractionHood",
	Vector3.new(9.1, 0.35, 2.85),
	Vector3.new(0, padTop + 6.15, 3.62),
	{ color = Color3.fromRGB(32, 43, 50), material = Enum.Material.Metal, canQuery = false },
	nil,
	6
)
for _, x in ipairs({ -4.15, 4.15 }) do
	labPart(
		"HoodSupport",
		Vector3.new(0.28, 4.3, 0.28),
		Vector3.new(x, padTop + 3.95, 4.72),
		{ color = Color3.fromRGB(62, 78, 86), material = Enum.Material.Metal, canQuery = false },
		nil,
		3
	)
end
local hoodGlow = labPart(
	"HoodGlow",
	Vector3.new(7.9, 0.08, 1.5),
	Vector3.new(0, padTop + 5.94, 3.25),
	{ color = Color3.fromRGB(75, 229, 255), material = Enum.Material.Neon, transparency = 0.18, canQuery = false, castShadow = false },
	nil,
	7
)
local hoodLight = Instance.new("SurfaceLight")
hoodLight.Name = "LabWorkLight"
hoodLight.Face = Enum.NormalId.Bottom
hoodLight.Color = Color3.fromRGB(133, 241, 255)
hoodLight.Brightness = 1.4
hoodLight.Range = 10
hoodLight.Angle = 100
hoodLight.Shadows = false
hoodLight.Parent = hoodGlow
table.insert(chemistryLights, hoodLight)

local cylinderRotation = CFrame.Angles(0, 0, math.rad(90))
local reactorGlass = labPart(
	"CentralReactorGlass",
	Vector3.new(4.15, 2.55, 2.55),
	Vector3.new(0, padTop + 3.9, 3.45),
	{ color = Color3.fromRGB(157, 236, 244), material = Enum.Material.Glass, transparency = 0.48, canQuery = false },
	cylinderRotation,
	5
)
markChemistryPart(reactorGlass, "ChemistryGlassware", false)
local reactorFluid = labPart(
	"CentralReactorFluid",
	Vector3.new(2.9, 2.12, 2.12),
	Vector3.new(0, padTop + 3.28, 3.45),
	{ color = Color3.fromRGB(32, 226, 242), material = Enum.Material.Neon, transparency = 0.22, canQuery = false, castShadow = false },
	cylinderRotation,
	7
)
markChemistryPart(reactorFluid, "ChemistryContainedFluid", true)
table.insert(chemistryReservoirs, {
	part = reactorFluid,
	baseHeight = reactorFluid.Size.X,
	baseOffset = Vector3.new(0, padTop + 3.28, 3.45),
	baseColor = reactorFluid.Color,
	phase = 0,
	amplitude = 0.34,
})
for index, definition in ipairs({
	{ x = -2.9, color = Color3.fromRGB(255, 74, 195), phase = 1.3 },
	{ x = 2.9, color = Color3.fromRGB(255, 183, 54), phase = 3.2 },
}) do
	local glass = labPart(
		"FeedTankGlass" .. tostring(index),
		Vector3.new(2.85, 1.72, 1.72),
		Vector3.new(definition.x, padTop + 3.35, 3.62),
		{ color = Color3.fromRGB(177, 229, 235), material = Enum.Material.Glass, transparency = 0.5, canQuery = false },
		cylinderRotation,
		5
	)
	markChemistryPart(glass, "ChemistryGlassware", false)
	local fluid = labPart(
		"FeedTankFluid" .. tostring(index),
		Vector3.new(2.08, 1.43, 1.43),
		Vector3.new(definition.x, padTop + 3.02, 3.62),
		{ color = definition.color, material = Enum.Material.Neon, transparency = 0.2, canQuery = false, castShadow = false },
		cylinderRotation,
		7
	)
	markChemistryPart(fluid, "ChemistryContainedFluid", true)
	table.insert(chemistryReservoirs, {
		part = fluid,
		baseHeight = fluid.Size.X,
		baseOffset = Vector3.new(definition.x, padTop + 3.02, 3.62),
		baseColor = fluid.Color,
		phase = definition.phase,
		amplitude = 0.16,
	})
	local tankLight = Instance.new("PointLight")
	tankLight.Name = "FluidGlow"
	tankLight.Color = definition.color
	tankLight.Brightness = 0.75
	tankLight.Range = 5
	tankLight.Shadows = false
	tankLight.Parent = fluid
	table.insert(chemistryLights, tankLight)
	glass:SetAttribute("FeedTank", true)
end

-- Familiar bench glassware keeps the room grounded in chemistry before the
-- high-tech reactor plumbing is noticed. These pieces are intentionally solid
-- silhouettes (not particles) and remain completely still in standby.
local erlenmeyerBase = cylinderBetween(
	"ErlenmeyerFlaskBase",
	Vector3.new(-3.65, padTop + 1.78, 2.28),
	Vector3.new(-3.65, padTop + 2.38, 2.28),
	1.12,
	{ color = Color3.fromRGB(187, 235, 240), material = Enum.Material.Glass, transparency = 0.5, canQuery = false },
	5
)
markChemistryPart(erlenmeyerBase, "ChemistryGlassware", false)
local erlenmeyerShoulder = labPart(
	"ErlenmeyerFlaskShoulder",
	Vector3.new(0.9, 0.72, 0.9),
	Vector3.new(-3.65, padTop + 2.5, 2.28),
	{ color = Color3.fromRGB(187, 235, 240), material = Enum.Material.Glass, transparency = 0.52, shape = Enum.PartType.Ball, canQuery = false },
	nil,
	5
)
markChemistryPart(erlenmeyerShoulder, "ChemistryGlassware", false)
local erlenmeyerNeck = cylinderBetween(
	"ErlenmeyerFlaskNeck",
	Vector3.new(-3.65, padTop + 2.55, 2.28),
	Vector3.new(-3.65, padTop + 3.12, 2.28),
	0.3,
	{ color = Color3.fromRGB(187, 235, 240), material = Enum.Material.Glass, transparency = 0.48, canQuery = false },
	5
)
markChemistryPart(erlenmeyerNeck, "ChemistryGlassware", false)
local erlenmeyerFluid = cylinderBetween(
	"ErlenmeyerFlaskFluid",
	Vector3.new(-3.65, padTop + 1.82, 2.28),
	Vector3.new(-3.65, padTop + 2.08, 2.28),
	0.82,
	{ color = Color3.fromRGB(244, 70, 179), material = Enum.Material.Neon, transparency = 0.2, canQuery = false, castShadow = false },
	7
)
markChemistryPart(erlenmeyerFluid, "ChemistryContainedFluid", false)

local roundFlask = labPart(
	"RoundBottomFlask",
	Vector3.new(1.18, 1.18, 1.18),
	Vector3.new(-1.95, padTop + 2.32, 2.28),
	{ color = Color3.fromRGB(187, 235, 240), material = Enum.Material.Glass, transparency = 0.48, shape = Enum.PartType.Ball, canQuery = false },
	nil,
	5
)
markChemistryPart(roundFlask, "ChemistryGlassware", false)
local roundFlaskNeck = cylinderBetween(
	"RoundBottomFlaskNeck",
	Vector3.new(-1.95, padTop + 2.72, 2.28),
	Vector3.new(-1.95, padTop + 3.2, 2.28),
	0.28,
	{ color = Color3.fromRGB(187, 235, 240), material = Enum.Material.Glass, transparency = 0.48, canQuery = false },
	5
)
markChemistryPart(roundFlaskNeck, "ChemistryGlassware", false)
local roundFlaskFluid = labPart(
	"RoundBottomFlaskFluid",
	Vector3.new(0.78, 0.78, 0.78),
	Vector3.new(-1.95, padTop + 2.17, 2.28),
	{ color = Color3.fromRGB(255, 177, 48), material = Enum.Material.Neon, transparency = 0.2, shape = Enum.PartType.Ball, canQuery = false, castShadow = false },
	nil,
	7
)
markChemistryPart(roundFlaskFluid, "ChemistryContainedFluid", false)

local beaker = cylinderBetween(
	"Beaker",
	Vector3.new(-0.45, padTop + 1.77, 2.28),
	Vector3.new(-0.45, padTop + 2.72, 2.28),
	0.92,
	{ color = Color3.fromRGB(187, 235, 240), material = Enum.Material.Glass, transparency = 0.52, canQuery = false },
	5
)
markChemistryPart(beaker, "ChemistryGlassware", false)
local beakerFluid = cylinderBetween(
	"BeakerFluid",
	Vector3.new(-0.45, padTop + 1.81, 2.28),
	Vector3.new(-0.45, padTop + 2.2, 2.28),
	0.72,
	{ color = Color3.fromRGB(55, 222, 255), material = Enum.Material.Neon, transparency = 0.22, canQuery = false, castShadow = false },
	7
)
markChemistryPart(beakerFluid, "ChemistryContainedFluid", false)

local rackBase = labPart(
	"TestTubeRackBase",
	Vector3.new(3.0, 0.12, 0.72),
	Vector3.new(2.45, padTop + 1.82, 2.42),
	{ color = Color3.fromRGB(49, 65, 72), material = Enum.Material.Metal, canQuery = false },
	nil,
	4
)
rackBase:SetAttribute("ChemistryRack", true)
local rackTop = labPart(
	"TestTubeRackTop",
	Vector3.new(3.0, 0.12, 0.72),
	Vector3.new(2.45, padTop + 2.55, 2.42),
	{ color = Color3.fromRGB(70, 92, 101), material = Enum.Material.Metal, canQuery = false },
	nil,
	4
)
rackTop:SetAttribute("ChemistryRack", true)
for index = 1, 6 do
	local x = 1.25 + (index - 1) * 0.48
	local tubeGlass = cylinderBetween(
		"TestTube" .. tostring(index),
		Vector3.new(x, padTop + 1.9, 2.42),
		Vector3.new(x, padTop + 2.78, 2.42),
		0.25,
		{ color = Color3.fromRGB(194, 240, 245), material = Enum.Material.Glass, transparency = 0.42, canQuery = false },
		5
	)
	markChemistryPart(tubeGlass, "ChemistryGlassware", false)
	local tubeFluid = cylinderBetween(
		"TestTubeFluid" .. tostring(index),
		Vector3.new(x, padTop + 1.94, 2.42),
		Vector3.new(x, padTop + 2.18 + (index % 3) * 0.08, 2.42),
		0.15,
		{
			color = index % 2 == 0 and Color3.fromRGB(255, 91, 190) or Color3.fromRGB(55, 225, 255),
			material = Enum.Material.Neon,
			transparency = 0.18,
			canQuery = false,
			castShadow = false,
		},
		7
	)
	markChemistryPart(tubeFluid, "ChemistryContainedFluid", false)
end

local condenserGlass = cylinderBetween(
	"CondenserGlass",
	Vector3.new(-1.8, padTop + 5.35, 2.45),
	Vector3.new(1.8, padTop + 5.35, 2.45),
	0.55,
	{ color = Color3.fromRGB(181, 235, 242), material = Enum.Material.Glass, transparency = 0.45, canQuery = false },
	5
)
markChemistryPart(condenserGlass, "ChemistryGlassware", false)
local condenserCore = cylinderBetween(
	"CondenserCoolantCore",
	Vector3.new(-1.72, padTop + 5.35, 2.45),
	Vector3.new(1.72, padTop + 5.35, 2.45),
	0.19,
	{ color = Color3.fromRGB(54, 221, 255), material = Enum.Material.Neon, transparency = 0.24, canQuery = false, castShadow = false },
	7
)
markChemistryPart(condenserCore, "ChemistryContainedFluid", false)
for _, x in ipairs({ -1.88, 1.88 }) do
	local collar = cylinderBetween(
		"CondenserCollar",
		Vector3.new(x - 0.1, padTop + 5.35, 2.45),
		Vector3.new(x + 0.1, padTop + 5.35, 2.45),
		0.72,
		{ color = Color3.fromRGB(63, 79, 88), material = Enum.Material.Metal, canQuery = false },
		6
	)
	collar:SetAttribute("ChemistryPipeFitting", true)
end

for index, x in ipairs({ -1.4, 1.4 }) do
	local pump = labPart(
		"PumpHousing" .. tostring(index),
		Vector3.new(0.9, 0.9, 0.45),
		Vector3.new(x, padTop + 2.05, 2.02),
		{ color = Color3.fromRGB(30, 41, 48), material = Enum.Material.Metal, canQuery = false },
		nil,
		4
	)
	local impeller = labPart(
		"PumpImpeller" .. tostring(index),
		Vector3.new(0.56, 0.56, 0.12),
		Vector3.new(x, padTop + 2.05, 1.76),
		{ color = index == 1 and Color3.fromRGB(255, 75, 195) or Color3.fromRGB(61, 226, 255), material = Enum.Material.Neon, canQuery = false, castShadow = false },
		nil,
		7
	)
	markChemistryPart(impeller, "ChemistryPumpImpeller", true)
	table.insert(chemistryImpellers, {
		part = impeller,
		homeLocal = chemistryPad.CFrame:ToObjectSpace(impeller.CFrame),
		direction = index == 1 and 1 or -1,
	})
	pump:SetAttribute("AnimatedPump", true)
end

local function physicalTubeRoute(name, points, color)
	local pieceIndex = 0
	for pointIndex = 1, #points - 1 do
		local routeStart = points[pointIndex]
		local routeEnd = points[pointIndex + 1]
		local flowStart = labPart(
			name .. "FlowStart" .. tostring(pointIndex),
			Vector3.new(0.05, 0.05, 0.05),
			routeStart,
			{ transparency = 1, canQuery = false, castShadow = false },
			nil,
			6
		)
		local flowEnd = labPart(
			name .. "FlowEnd" .. tostring(pointIndex),
			Vector3.new(0.05, 0.05, 0.05),
			routeEnd,
			{ transparency = 1, canQuery = false, castShadow = false },
			nil,
			6
		)
		local attachment0 = Instance.new("Attachment")
		attachment0.Parent = flowStart
		local attachment1 = Instance.new("Attachment")
		attachment1.Parent = flowEnd
		local flowBeam = Instance.new("Beam")
		flowBeam.Name = name .. "ContainedFlow" .. tostring(pointIndex)
		flowBeam.Attachment0 = attachment0
		flowBeam.Attachment1 = attachment1
		flowBeam.FaceCamera = true
		flowBeam.Width0 = 0.14
		flowBeam.Width1 = 0.14
		-- Keep the colored stream optically inside the clear pipe while avoiding
		-- Roblox Glass depth-sorting swallowing it from common camera angles.
		flowBeam.ZOffset = 0.025
		flowBeam.Color = ColorSequence.new(color)
		flowBeam.Transparency = NumberSequence.new(0.08)
		flowBeam.LightEmission = 1
		flowBeam.TextureSpeed = 0
		flowBeam.Enabled = false
		flowBeam:SetAttribute("ChemistryTubeFluid", true)
		flowBeam:SetAttribute("ChemistryContainedInTube", true)
		flowBeam.Parent = flowStart
		table.insert(chemistryFlowBeams, {
			beam = flowBeam,
			color = color,
			phase = pointIndex * 0.8 + #chemistryFlowBeams * 0.31,
		})
		-- Two short rigid pieces per leg make bends and fluid progression easy to
		-- read without using camera-facing Beams.
		for half = 1, 2 do
			pieceIndex += 1
			local startAlpha = (half - 1) * 0.5
			local endAlpha = half * 0.5
			local segmentStart = routeStart:Lerp(routeEnd, startAlpha)
			local segmentEnd = routeStart:Lerp(routeEnd, endAlpha)
			local shell = cylinderBetween(
				name .. "GlassTube" .. tostring(pieceIndex),
				segmentStart,
				segmentEnd,
				0.32,
				{
					color = Color3.fromRGB(184, 232, 239),
					-- Translucent SmoothPlastic reads as glass here but, unlike the
					-- engine Glass material, reliably renders the smaller liquid core.
					material = Enum.Material.SmoothPlastic,
					transparency = 0.58,
					canQuery = false,
				},
				6
			)
			markChemistryPart(shell, "ChemistryTubeSegment", false)
			local fluid = cylinderBetween(
				name .. "TubeFluid" .. tostring(pieceIndex),
				segmentStart,
				segmentEnd,
				0.23,
				{
					color = color,
					material = Enum.Material.Neon,
					transparency = 1,
					canQuery = false,
					castShadow = false,
				},
				7
			)
			markChemistryPart(fluid, "ChemistryTubeFluid", true)
			table.insert(chemistryTubeFluids, {
				part = fluid,
				color = color,
				phase = pieceIndex * 0.67 + pointIndex * 0.29,
				speed = 5.2 + (#chemistryTubeFluids % 4) * 0.35,
			})
		end
	end
end

local function rigidPipeRoute(name, points)
	for index = 1, #points - 1 do
		local pipe = cylinderBetween(
			name .. "Pipe" .. tostring(index),
			points[index],
			points[index + 1],
			0.34,
			{ color = Color3.fromRGB(80, 96, 104), material = Enum.Material.Metal, canQuery = false },
			4
		)
		markChemistryPart(pipe, "ChemistryPipeSegment", false)
	end
end

local fluidRoutes = {
	{
		color = Color3.fromRGB(255, 75, 195),
		points = {
			Vector3.new(-2.9, padTop + 4.25, 3.6),
			Vector3.new(-2.9, padTop + 5.15, 2.25),
			Vector3.new(-1.8, padTop + 5.35, 1.62),
			Vector3.new(-0.95, padTop + 4.95, 1.62),
			Vector3.new(-0.72, padTop + 4.45, 2.62),
		},
	},
	{
		color = Color3.fromRGB(255, 183, 54),
		points = {
			Vector3.new(2.9, padTop + 4.25, 3.6),
			Vector3.new(2.9, padTop + 5.15, 2.25),
			Vector3.new(1.8, padTop + 5.35, 1.62),
			Vector3.new(0.95, padTop + 4.95, 1.62),
			Vector3.new(0.72, padTop + 4.45, 2.62),
		},
	},
	{
		color = Color3.fromRGB(50, 230, 255),
		points = {
			Vector3.new(0, padTop + 2.65, 2.55),
			Vector3.new(0.6, padTop + 2.1, 1.75),
			Vector3.new(2.4, padTop + 2.0, 1.55),
			Vector3.new(3.15, padTop + 2.1, 1.4),
			Vector3.new(3.7, padTop + 2.35, 1.25),
		},
	},
	{
		color = Color3.fromRGB(93, 122, 255),
		points = {
			Vector3.new(-1.8, padTop + 5.35, 2.45),
			Vector3.new(-2.2, padTop + 5.82, 2.2),
			Vector3.new(-3.75, padTop + 5.82, 2.2),
			Vector3.new(-3.75, padTop + 4.75, 2.65),
			Vector3.new(-2.9, padTop + 4.25, 3.6),
		},
	},
}
for routeIndex, route in ipairs(fluidRoutes) do
	physicalTubeRoute("ProcessRoute" .. tostring(routeIndex), route.points, route.color)
end

rigidPipeRoute("LeftUtility", {
	Vector3.new(-4.0, padTop + 2.1, 4.72),
	Vector3.new(-4.0, padTop + 5.65, 4.72),
	Vector3.new(-2.45, padTop + 5.65, 4.72),
	Vector3.new(-2.45, padTop + 5.25, 3.75),
})
rigidPipeRoute("RightUtility", {
	Vector3.new(4.0, padTop + 2.1, 4.72),
	Vector3.new(4.0, padTop + 5.65, 4.72),
	Vector3.new(2.45, padTop + 5.65, 4.72),
	Vector3.new(2.45, padTop + 5.25, 3.75),
})
rigidPipeRoute("ReactorDrain", {
	Vector3.new(0, padTop + 2.15, 4.35),
	Vector3.new(0, padTop + 1.95, 4.85),
	Vector3.new(2.2, padTop + 1.95, 4.85),
	Vector3.new(2.9, padTop + 2.15, 4.25),
})

for index, x in ipairs({ -3.72, 3.72 }) do
	local wheel = cylinderBetween(
		"ValveWheel" .. tostring(index),
		Vector3.new(x, padTop + 4.45, 2.2),
		Vector3.new(x, padTop + 4.45, 2.4),
		0.78,
		{ color = Color3.fromRGB(207, 88, 67), material = Enum.Material.Metal, canQuery = false },
		6
	)
	wheel:SetAttribute("ChemistryValve", true)
	for spokeIndex, angle in ipairs({ 0, math.rad(45) }) do
		local spoke = labPart(
			"ValveSpoke" .. tostring(index) .. "_" .. tostring(spokeIndex),
			Vector3.new(0.08, 0.66, 0.1),
			Vector3.new(x, padTop + 4.45, 2.08),
			{ color = Color3.fromRGB(229, 110, 82), material = Enum.Material.Metal, canQuery = false },
			CFrame.Angles(0, 0, angle),
			6
		)
		spoke:SetAttribute("ChemistryValve", true)
	end
end

-- A few contained bubbles make the active reactor believable, but they are
-- hidden at idle and never travel outside the glass vessel.
for index = 1, 6 do
	local angle = index * 2.399
	local radius = 0.22 + (index % 3) * 0.14
	local bubble = labPart(
		"ReactorBubble",
		Vector3.new(0.1 + (index % 3) * 0.025, 0.1 + (index % 3) * 0.025, 0.1 + (index % 3) * 0.025),
		Vector3.new(math.cos(angle) * radius, padTop + 2.4, 3.45 + math.sin(angle) * radius),
		{ color = Color3.fromRGB(210, 252, 255), material = Enum.Material.Glass, transparency = 1, shape = Enum.PartType.Ball, canQuery = false, castShadow = false },
		nil,
		7
	)
	markChemistryPart(bubble, "ChemistryContainedBubble", true)
	table.insert(chemistryBubbles, {
		part = bubble,
		x = math.cos(angle) * radius,
		z = 3.45 + math.sin(angle) * radius,
		phase = (index - 1) / 6,
		speed = 0.16 + (index % 4) * 0.025,
	})
end

local vaporPort = labPart(
	"ReactorVaporPort",
	Vector3.new(0.28, 0.28, 0.28),
	Vector3.new(0, padTop + 6.15, 3.45),
	{ color = Color3.fromRGB(75, 226, 242), material = Enum.Material.Neon, transparency = 0.1, canQuery = false, castShadow = false },
	nil,
	7
)
local vapor = Instance.new("ParticleEmitter")
vapor.Name = "ReactorVapor"
vapor.Color = ColorSequence.new(Color3.fromRGB(154, 244, 255), Color3.fromRGB(197, 132, 255))
vapor.LightEmission = 0.45
vapor.Rate = 0
vapor.Enabled = false
vapor.Lifetime = NumberRange.new(1.2, 2.1)
vapor.Speed = NumberRange.new(0.25, 0.65)
vapor.SpreadAngle = Vector2.new(18, 18)
vapor.Rotation = NumberRange.new(0, 360)
vapor.RotSpeed = NumberRange.new(-25, 25)
vapor.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.18),
	NumberSequenceKeypoint.new(0.55, 0.45),
	NumberSequenceKeypoint.new(1, 0.7),
})
vapor.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(1, 1),
})
vapor.Parent = vaporPort
table.insert(chemistryEmitters, vapor)

local controlBody = labPart(
	"ResearchControlConsole",
	Vector3.new(0.9, 2.5, 3.2),
	Vector3.new(4.55, padTop + 1.3, 0.25),
	{ color = Color3.fromRGB(32, 43, 51), material = Enum.Material.DiamondPlate, canCollide = true },
	nil,
	3
)
local controlScreen = labPart(
	"ResearchControlScreen",
	Vector3.new(2.45, 1.65, 0.12),
	Vector3.new(5.02, padTop + 1.65, 0.25),
	{ color = Color3.fromRGB(7, 22, 29), material = Enum.Material.SmoothPlastic, canQuery = false },
	CFrame.Angles(0, math.rad(-90), 0),
	6
)
local controlGui, chemistryControlStatus = screenGui(
	controlScreen,
	"ChemistryControlDisplay",
	"COOPER CHEMISTRY",
	[[REACTOR: STANDBY
PUMPS: IDLE
FLOW: STOPPED]],
	Color3.fromRGB(65, 235, 255)
)
controlGui.Face = Enum.NormalId.Front
table.insert(chemistryGuis, controlGui)
for index, data in ipairs({
	{ y = 0.82, color = Color3.fromRGB(52, 240, 173) },
	{ y = 0.25, color = Color3.fromRGB(255, 187, 59) },
	{ y = -0.32, color = Color3.fromRGB(183, 91, 255) },
}) do
	local lamp = labPart(
		"ConsoleStatusLamp" .. tostring(index),
		Vector3.new(0.13, 0.25, 0.25),
		Vector3.new(5.025, padTop + 1.65 + data.y, -1.18),
		{ color = data.color, material = Enum.Material.Neon, canQuery = false, castShadow = false },
		CFrame.Angles(0, math.rad(-90), 0),
		7
	)
	markChemistryPart(lamp, "ChemistryStatusLamp", true)
	table.insert(chemistryStatusLamps, { part = lamp, color = data.color, phase = index * 1.7 })
end
controlBody:SetAttribute("ChemistryControlConsole", true)

local chemistryPromptAnchor = labPart(
	"DoChemistryAnchor",
	Vector3.new(1.5, 2.2, 3.8),
	Vector3.new(5.05, padTop + 1.35, 0.25),
	{ transparency = 1, canQuery = false, castShadow = false },
	nil,
	7
)
local chemistryPrompt = Instance.new("ProximityPrompt")
chemistryPrompt.Name = "DoChemistryPrompt"
chemistryPrompt.ActionText = "Do Chemistry"
chemistryPrompt.ObjectText = "Advanced Chemistry Lab"
chemistryPrompt.KeyboardKeyCode = Enum.KeyCode.E
chemistryPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
chemistryPrompt.HoldDuration = 0.2
chemistryPrompt.MaxActivationDistance = 9
chemistryPrompt.RequiresLineOfSight = false
chemistryPrompt.Enabled = false
chemistryPrompt.Parent = chemistryPromptAnchor

local baySign = chemistryBay:FindFirstChild("ChemistryBaySign")
if baySign and baySign:IsA("BasePart") then
	local gui = baySign:FindFirstChildWhichIsA("SurfaceGui")
	local textLabel = gui and gui:FindFirstChildWhichIsA("TextLabel", true)
	if textLabel then
		textLabel.Text = [[ADVANCED CHEMISTRY BAY
RESEARCH EQUIPMENT READY]]
		textLabel.TextColor3 = Color3.fromRGB(71, 229, 255)
	end
end

local function setLabDescendantsEnabled(enabled)
	for _, beam in ipairs(chemistryBeams) do
		beam.Enabled = enabled
	end
	if not enabled then
		for _, flow in ipairs(chemistryFlowBeams) do
			flow.beam.Enabled = false
		end
	end
	for _, light in ipairs(chemistryLights) do
		light.Enabled = enabled
	end
	for _, gui in ipairs(chemistryGuis) do
		gui.Enabled = enabled
	end
	for _, emitter in ipairs(chemistryEmitters) do
		-- Vapor is a short, deliberate reaction accent. It is never a continuous
		-- idle effect and is emitted only by the active experiment sequence.
		emitter.Enabled = false
		emitter.Rate = 0
		if not enabled then
			emitter:Clear()
		end
	end
end

local function setChemistryExperimentActive(active)
	chemistryExperimentActive = active == true
	chemistryLab:SetAttribute("ExperimentActive", chemistryExperimentActive)
	chemistryLab:SetAttribute("ExperimentState", chemistryExperimentActive and "Running" or "Idle")
end

local function updateChemistryPromptState()
	local now = Workspace:GetServerTimeNow()
	local hasActiveOwner = false
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate:GetAttribute("CooperGameProfileLoaded") == true
			and candidate:GetAttribute("CooperChemistrySetupPlaced") == true
			and candidate:GetAttribute("CooperPartyState") == "Active"
		then
			hasActiveOwner = true
			break
		end
	end
	if not chemistryVisible
		or chemistryAssemblyActive
		or bunker:GetAttribute("UnlockState") ~= "Unlocked"
		or not hasActiveOwner
	then
		chemistryPrompt.ActionText = "Do Chemistry"
		chemistryPrompt.Enabled = false
	elseif chemistryExperimentActive then
		chemistryPrompt.ActionText = "Reaction Running"
		chemistryPrompt.Enabled = false
	elseif chemistryLab:GetAttribute("RewardState") == "Dispensing" then
		chemistryPrompt.ActionText = "Product Dispensing"
		chemistryPrompt.Enabled = false
	elseif chemistryRewardAvailable then
		chemistryPrompt.ActionText = "Collect Candy First"
		chemistryPrompt.Enabled = false
	elseif now < chemistryExperimentReadyAt then
		chemistryPrompt.ActionText = "Cooling Down"
		chemistryPrompt.Enabled = false
	else
		chemistryPrompt.ActionText = "Do Chemistry"
		chemistryPrompt.Enabled = true
	end
end

local function cancelChemistryDrawerTweens()
	for _, tween in ipairs(chemistryDrawerTweens) do
		pcall(function()
			tween:Cancel()
		end)
	end
	table.clear(chemistryDrawerTweens)
end

local function setChemistryRewardState(state, available, ownerUserId)
	chemistryRewardAvailable = available == true
	chemistryRewardOwnerUserId = math.max(0, math.floor(tonumber(ownerUserId) or 0))
	chemistryLab:SetAttribute("RewardState", state)
	chemistryLab:SetAttribute("RewardAvailable", chemistryRewardAvailable)
	chemistryLab:SetAttribute("RewardOwnerUserId", chemistryRewardOwnerUserId)
	if terminalChemistryStatus then
		if chemistryRewardAvailable then
			terminalChemistryStatus.Text = [[PRODUCT: BLUE ROCK CANDY
OUTPUT DRAWER: READY
COLLECT AT LAB]]
		elseif state == "Dispensing" then
			terminalChemistryStatus.Text = [[REACTION: COMPLETE
OUTPUT DRAWER: MOVING
STAND CLEAR]]
		elseif chemistryVisible then
			terminalChemistryStatus.Text = [[EQUIPMENT: INSTALLED
REACTOR NETWORK: ONLINE
SELECT LAB STATUS]]
		end
	end
	if chemistryControlStatus and not chemistryExperimentActive then
		if chemistryRewardAvailable then
			chemistryControlStatus.Text = [[REACTION: COMPLETE
OUTPUT: READY
PRODUCT: BLUE ROCK CANDY]]
		elseif state == "Dispensing" then
			chemistryControlStatus.Text = [[REACTION: COMPLETE
OUTPUT: MOVING
PRODUCT: SECURED]]
		elseif chemistryVisible then
			chemistryControlStatus.Text = [[REACTOR: STANDBY
PUMPS: IDLE
FLOW: STOPPED]]
		end
	end
end

local function resetChemistryReward(immediate)
	chemistryRewardToken += 1
	candyPresentation.serial += 1
	local token = chemistryRewardToken
	cancelChemistryDrawerTweens()
	chemistryRewardClaiming = false
	candyPresentation.batchToken = ""
	candyPresentation.leaseExpiresAt = 0
	chemistryLab:SetAttribute("RewardLeaseExpiresAt", 0)
	collectCandyPrompt.Enabled = false
	chemistryLab:SetAttribute("RewardAvailable", false)
	candySmoke.Enabled = false
	candySmoke.Rate = 0
	candySmoke:Clear()

	-- These explicit primary assignments are also a guard against a cancelled
	-- tween leaving the product or drawer between poses.
	chemistryReward.CFrame = chemistryRewardHomeCFrame
	chemistryDrawer.CFrame = chemistryDrawerHomeCFrame
	for _, piece in ipairs(chemistryRewardPieces) do
		piece.part.CFrame = piece.homeCFrame
		piece.part.Transparency = 1
	end

	if immediate == true then
		for _, drawerPart in ipairs(chemistryDrawerParts) do
			drawerPart.part.CFrame = drawerPart.homeCFrame
		end
		chemistryLab:SetAttribute("RewardOwnerUserId", 0)
		setChemistryRewardState("Empty", false, 0)
		updateChemistryPromptState()
		return
	end

	-- Keep the output occupied while the tray retracts so a second chemistry
	-- cycle cannot open it in the opposite direction.
	setChemistryRewardState("Dispensing", false, chemistryRewardOwnerUserId)
	local longestTween
	for _, drawerPart in ipairs(chemistryDrawerParts) do
		local tween = TweenService:Create(
			drawerPart.part,
			TweenInfo.new(0.58, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
			{ CFrame = drawerPart.homeCFrame }
		)
		table.insert(chemistryDrawerTweens, tween)
		tween:Play()
		if drawerPart.part == chemistryDrawer then
			longestTween = tween
		end
	end
	task.spawn(function()
		if longestTween then
			longestTween.Completed:Wait()
		else
			task.wait(0.58)
		end
		if token ~= chemistryRewardToken then
			return
		end
		cancelChemistryDrawerTweens()
		for _, drawerPart in ipairs(chemistryDrawerParts) do
			drawerPart.part.CFrame = drawerPart.homeCFrame
		end
		setChemistryRewardState("Empty", false, 0)
		updateChemistryPromptState()
	end)
end

local function presentChemistryReward(ownerPlayer, batchToken)
	batchToken = type(batchToken) == "string" and batchToken or ""
	if chemistryRewardAvailable then
		return false
	end
	if chemistryLab:GetAttribute("RewardState") ~= "Empty"
		or not chemistryVisible
		or chemistryAssemblyActive
		or not ownerPlayer
		or ownerPlayer.Parent ~= Players
		or ownerPlayer:GetAttribute("CooperChemistrySetupPlaced") ~= true
		or batchToken == ""
	then
		return false
	end

	chemistryRewardToken += 1
	local token = chemistryRewardToken
	cancelChemistryDrawerTweens()
	chemistryRewardClaiming = false
	collectCandyPrompt.Enabled = false
	chemistryRewardOwnerUserId = ownerPlayer.UserId
	candyPresentation.batchToken = batchToken
	setChemistryRewardState("Dispensing", false, ownerPlayer.UserId)
	chemistryControlStatus.Text = [[REACTION: COMPLETE
OUTPUT: DISPENSING
PRODUCT: CRYSTALLIZING]]
	updateChemistryPromptState()

	for _, drawerPart in ipairs(chemistryDrawerParts) do
		drawerPart.part.CFrame = drawerPart.homeCFrame
	end
	for _, piece in ipairs(chemistryRewardPieces) do
		piece.part.CFrame = piece.homeCFrame
		piece.part.Transparency = 1
	end

	local drawerTween
	for _, drawerPart in ipairs(chemistryDrawerParts) do
		local tween = TweenService:Create(
			drawerPart.part,
			TweenInfo.new(0.82, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ CFrame = drawerPart.openCFrame }
		)
		table.insert(chemistryDrawerTweens, tween)
		tween:Play()
		if drawerPart.part == chemistryDrawer then
			drawerTween = tween
		end
	end
	if drawerTween then
		drawerTween.Completed:Wait()
	else
		task.wait(0.82)
	end
	if token ~= chemistryRewardToken or not chemistryVisible or ownerPlayer.Parent ~= Players then
		return false
	end

	candySmoke:Emit(28)
	local rewardTween
	for _, piece in ipairs(chemistryRewardPieces) do
		-- A short lift through the tray surface, hidden by the bounded smoke
		-- burst, settles the pan naturally instead of making it hover upward.
		piece.part.CFrame = piece.presentCFrame * CFrame.new(0, -0.10, 0)
		local tween = TweenService:Create(
			piece.part,
			TweenInfo.new(0.62, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = piece.presentCFrame, Transparency = piece.visibleTransparency }
		)
		table.insert(chemistryDrawerTweens, tween)
		tween:Play()
		if piece.part == chemistryReward then
			rewardTween = tween
		end
	end
	if rewardTween then
		rewardTween.Completed:Wait()
	else
		task.wait(0.62)
	end
	if token ~= chemistryRewardToken
		or not chemistryVisible
		or ownerPlayer.Parent ~= Players
		or ownerPlayer:GetAttribute("CooperChemistrySetupPlaced") ~= true
	then
		return false
	end

	cancelChemistryDrawerTweens()
	for _, drawerPart in ipairs(chemistryDrawerParts) do
		drawerPart.part.CFrame = drawerPart.openCFrame
	end
	for _, piece in ipairs(chemistryRewardPieces) do
		piece.part.CFrame = piece.presentCFrame
		piece.part.Transparency = piece.visibleTransparency
	end
	setChemistryRewardState("Present", true, ownerPlayer.UserId)
	collectCandyPrompt.Enabled = true
	chemistryControlStatus.Text = [[REACTION: COMPLETE
OUTPUT: READY
PRODUCT: BLUE ROCK CANDY]]
	updateChemistryPromptState()
	return true
end

local function resetChemistryExperimentVisuals()
	setChemistryExperimentActive(false)
	chemistryExperimentOwnerUserId = 0
	chemistryLab:SetAttribute("ExperimentStartedAt", 0)
	chemistryLab:SetAttribute("ExperimentEndsAt", 0)
	chemistryLab:SetAttribute("ExperimentReadyAt", chemistryExperimentReadyAt)
	chemistryNextVaporAt = 0

	for _, reservoir in ipairs(chemistryReservoirs) do
		local fluid = reservoir.part
		local home = chemistryParts[fluid]
		if fluid.Parent and home then
			fluid.Size = Vector3.new(reservoir.baseHeight, fluid.Size.Y, fluid.Size.Z)
			fluid.CFrame = home.cframe
			fluid.Color = reservoir.baseColor
			fluid.Transparency = home.transparency
		end
	end
	for _, flow in ipairs(chemistryTubeFluids) do
		if flow.part.Parent then
			flow.part.Color = flow.color
			flow.part.Transparency = 1
		end
	end
	for _, flow in ipairs(chemistryFlowBeams) do
		flow.beam.Enabled = false
		flow.beam.TextureSpeed = 0
		flow.beam.Color = ColorSequence.new(flow.color)
		flow.beam.Transparency = NumberSequence.new(0.08)
	end
	for _, bubble in ipairs(chemistryBubbles) do
		if bubble.part.Parent then
			bubble.part.Position = chemistryPad.CFrame:PointToWorldSpace(
				Vector3.new(bubble.x, padTop + 2.4, bubble.z)
			)
			bubble.part.Transparency = 1
		end
	end
	for _, impeller in ipairs(chemistryImpellers) do
		if impeller.part.Parent then
			impeller.part.CFrame = chemistryPad.CFrame * impeller.homeLocal
		end
	end
	for _, lamp in ipairs(chemistryStatusLamps) do
		if lamp.part.Parent then
			local home = chemistryParts[lamp.part]
			lamp.part.Color = lamp.color
			lamp.part.Transparency = home and home.transparency or 0
		end
	end
	for _, emitter in ipairs(chemistryEmitters) do
		emitter.Enabled = false
		emitter.Rate = 0
		emitter:Clear()
	end
	chemistryControlStatus.Text = [[REACTOR: STANDBY
PUMPS: IDLE
FLOW: STOPPED]]
	updateChemistryPromptState()
end

local function hideChemistryLab()
	chemistryAnimationToken += 1
	chemistryExperimentToken += 1
	chemistryExperimentReadyAt = 0
	resetChemistryReward(true)
	chemistryAssemblyActive = false
	chemistryVisible = false
	chemistryLab:SetAttribute("Installed", false)
	chemistryLab:SetAttribute("SetupAnimating", false)
	chemistryPrompt.Enabled = false
	resetChemistryExperimentVisuals()
	setLabDescendantsEnabled(false)
	for part in pairs(chemistryParts) do
		if part.Parent then
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
		end
	end
end

local function revealChemistryLab(animate)
	chemistryAnimationToken += 1
	chemistryExperimentToken += 1
	chemistryExperimentReadyAt = 0
	resetChemistryReward(true)
	local token = chemistryAnimationToken
	chemistryVisible = true
	chemistryAssemblyActive = animate == true
	chemistryLab:SetAttribute("Installed", true)
	chemistryLab:SetAttribute("SetupAnimating", animate == true)
	chemistryPrompt.Enabled = false
	resetChemistryExperimentVisuals()
	setLabDescendantsEnabled(false)
	for part, home in pairs(chemistryParts) do
		if part.Parent then
			part.CanCollide = false
			part.CanQuery = false
			if animate then
				part.CFrame = home.cframe * CFrame.new(0, -0.8, 0)
				part.Transparency = 1
			else
				part.CFrame = home.cframe
				part.Transparency = home.transparency
				part.CanCollide = home.canCollide
				part.CanQuery = home.canCollide
			end
		end
	end
	if not animate then
		chemistryAssemblyActive = false
		chemistryLab:SetAttribute("SetupAnimating", false)
		setLabDescendantsEnabled(true)
		resetChemistryExperimentVisuals()
		return
	end

	task.spawn(function()
		for order = 1, 7 do
			if token ~= chemistryAnimationToken or not chemistryVisible then
				return
			end
			local longestTween
			for part, home in pairs(chemistryParts) do
				if part.Parent and home.order == order then
					local tween = TweenService:Create(
						part,
						TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ CFrame = home.cframe, Transparency = home.transparency }
					)
					tween:Play()
					longestTween = tween
				end
			end
			if longestTween then
				longestTween.Completed:Wait()
			else
				task.wait(0.1)
			end
		end
		if token ~= chemistryAnimationToken or not chemistryVisible then
			return
		end
		for part, home in pairs(chemistryParts) do
			if part.Parent then
				part.CFrame = home.cframe
				part.Transparency = home.transparency
				part.CanCollide = home.canCollide
				part.CanQuery = home.canCollide
			end
		end
		setLabDescendantsEnabled(true)
		chemistryAssemblyActive = false
		chemistryLab:SetAttribute("SetupAnimating", false)
		resetChemistryExperimentVisuals()
	end)
end

bunker:SetAttribute("ControllerVersion", CONTROLLER_VERSION)
if bunker:GetAttribute("UnlockState") == nil then
	bunker:SetAttribute("UnlockState", "Locked")
end

local function bunkerIsUnlocked()
	return bunker:GetAttribute("UnlockState") == "Unlocked"
end

local function bunkerAccessSnapshot(player)
	local events = ServerScriptService:FindFirstChild("CooperGameServerEvents")
	local api = events and events:FindFirstChild("API")
	if api and api:IsA("BindableFunction") then
		local ok, snapshot = pcall(function()
			return api:Invoke("GetSnapshot", player)
		end)
		if ok and type(snapshot) == "table" and type(snapshot.secretBunker) == "table" then
			return snapshot.secretBunker
		end
	end
	return {
		unlocked = player:GetAttribute("CooperSecretBunkerUnlocked") == true,
		purchased = player:GetAttribute("CooperSecretBunkerPurchased") == true,
		remaining = 0,
		price = 2500,
	}
end

local function playerHasBunkerAccess(player)
	local snapshot = bunkerAccessSnapshot(player)
	return bunkerIsUnlocked() and snapshot.unlocked == true
end

local accessCharacterConnections = {}
local ACCESS_CONSTRAINT_FOLDER = "CooperBunkerAccessPass"

local function clearCharacterAccess(character)
	local existing = character and character:FindFirstChild(ACCESS_CONSTRAINT_FOLDER)
	if existing then
		existing:Destroy()
	end
end

local function grantCharacterAccess(player, character)
	clearCharacterAccess(character)
	if not character
		or character.Parent == nil
		or player:GetAttribute("CooperSecretBunkerUnlocked") ~= true
	then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = ACCESS_CONSTRAINT_FOLDER
	folder.Parent = character

	local function exemptPart(part)
		if not part:IsA("BasePart") or not part:IsDescendantOf(character) then
			return
		end
		for _, existingConstraint in ipairs(folder:GetChildren()) do
			if existingConstraint:IsA("NoCollisionConstraint")
				and (
					(existingConstraint.Part0 == part and existingConstraint.Part1 == accessGate)
					or (existingConstraint.Part1 == part and existingConstraint.Part0 == accessGate)
				)
			then
				return
			end
		end
		local constraint = Instance.new("NoCollisionConstraint")
		constraint.Name = "BunkerAccessPass"
		constraint.Part0 = part
		constraint.Part1 = accessGate
		constraint.Parent = folder
		local ancestryConnection
		ancestryConnection = part.AncestryChanged:Connect(function()
			task.defer(function()
				if not part:IsDescendantOf(character) then
					if constraint.Parent then
						constraint:Destroy()
					end
					if ancestryConnection then
						ancestryConnection:Disconnect()
						ancestryConnection = nil
					end
				end
			end)
		end)
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		exemptPart(descendant)
	end

	accessCharacterConnections[player] = character.DescendantAdded:Connect(function(descendant)
		if player:GetAttribute("CooperSecretBunkerUnlocked") == true then
			exemptPart(descendant)
		end
	end)
end

local function syncPlayerCharacterAccess(player)
	local oldConnection = accessCharacterConnections[player]
	if oldConnection then
		oldConnection:Disconnect()
		accessCharacterConnections[player] = nil
	end
	local character = player.Character
	if character then
		grantCharacterAccess(player, character)
	end
end

local function watchPlayerAccess(player)
	player.CharacterAdded:Connect(function()
		task.defer(syncPlayerCharacterAccess, player)
	end)
	player:GetAttributeChangedSignal("CooperSecretBunkerUnlocked"):Connect(function()
		syncPlayerCharacterAccess(player)
	end)
	syncPlayerCharacterAccess(player)
end

Players.PlayerAdded:Connect(watchPlayerAccess)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayerAccess(player)
end

-- CFrame attributes do not move with an ancestor Model. Rebase every authored
-- animation pose from the live physical edit pose before the controller reads
-- them, so relocating the complete property cannot fling the hatch, blast
-- door, or ventilation fan back to the bunker's former world coordinates.
do
	local oldClosed = hatchDoor:GetAttribute("ClosedPivot")
	local oldOpen = hatchDoor:GetAttribute("OpenPivot")
	if typeof(oldClosed) == "CFrame" and typeof(oldOpen) == "CFrame" then
		local reference = if bunker:GetAttribute("HatchOpen") == true then oldOpen else oldClosed
		local delta = hatchDoor:GetPivot() * reference:Inverse()
		hatchDoor:SetAttribute("ClosedPivot", delta * oldClosed)
		hatchDoor:SetAttribute("OpenPivot", delta * oldOpen)
	end

	local blastWasOpen = bunker:GetAttribute("BlastDoorOpen") == true
	for _, panel in ipairs({ leftPanel, rightPanel }) do
		local panelClosed = panel:GetAttribute("ClosedCFrame")
		local panelOpen = panel:GetAttribute("OpenCFrame")
		if typeof(panelClosed) == "CFrame" and typeof(panelOpen) == "CFrame" then
			local reference = if blastWasOpen then panelOpen else panelClosed
			local delta = panel.CFrame * reference:Inverse()
			panel:SetAttribute("ClosedCFrame", delta * panelClosed)
			panel:SetAttribute("OpenCFrame", delta * panelOpen)
		end
	end

	fanBlades:SetAttribute("BasePivot", fanBlades:GetPivot())
end

local closedHatchPivot = hatchDoor:GetAttribute("ClosedPivot")
local openHatchPivot = hatchDoor:GetAttribute("OpenPivot")
local leftClosed = leftPanel:GetAttribute("ClosedCFrame")
local leftOpen = leftPanel:GetAttribute("OpenCFrame")
local rightClosed = rightPanel:GetAttribute("ClosedCFrame")
local rightOpen = rightPanel:GetAttribute("OpenCFrame")
local fanBasePivot = fanBlades:GetAttribute("BasePivot")

assert(typeof(closedHatchPivot) == "CFrame" and typeof(openHatchPivot) == "CFrame", "Hatch pivots are missing")
assert(typeof(leftClosed) == "CFrame" and typeof(leftOpen) == "CFrame", "Left blast-door poses are missing")
assert(typeof(rightClosed) == "CFrame" and typeof(rightOpen) == "CFrame", "Right blast-door poses are missing")
assert(typeof(fanBasePivot) == "CFrame", "Ventilation fan BasePivot is missing")

local hatchOpen = false
local hatchMoving = false
local blastDoorOpen = false
local blastDoorMoving = false
local mainLightsOn = true
local recoveryDebounce = {}
local physicalPromptNextAt = {}
local PHYSICAL_PROMPT_RATE_SECONDS = table.freeze({
	Hatch = 0.70,
	BlastDoor = 0.70,
	MainLights = 0.45,
})

local function statusTextLabel()
	local gui = statusConsole:FindFirstChild("BunkerSignGui")
	local label = gui and gui:FindFirstChild("StatusText")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local function updateStatus()
	local unlocked = bunkerIsUnlocked()
	bunker:SetAttribute("HatchOpen", hatchOpen)
	bunker:SetAttribute("BlastDoorOpen", blastDoorOpen)
	bunker:SetAttribute("MainLightsOn", unlocked and mainLightsOn)
	hatchDoor:SetAttribute("IsOpen", hatchOpen)
	blastDoor:SetAttribute("IsOpen", blastDoorOpen)

	hatchPrompt.ActionText = hatchOpen and "Close bunker" or "Open bunker"
	blastDoorPrompt.ActionText = blastDoorOpen and "Seal blast door" or "Open blast door"
	lightPrompt.ActionText = mainLightsOn and "Turn lights off" or "Turn lights on"
	hatchPrompt.Enabled = unlocked and not hatchMoving
	blastDoorPrompt.Enabled = unlocked and not blastDoorMoving
	lightPrompt.Enabled = unlocked
	researchPrompt.Enabled = unlocked
	chemistryPrompt.Enabled = unlocked
		and chemistryVisible
		and not chemistryAssemblyActive
		and not chemistryExperimentActive
		and not chemistryRewardAvailable
		and chemistryLab:GetAttribute("RewardState") == "Empty"
		and Workspace:GetServerTimeNow() >= chemistryExperimentReadyAt
	updateChemistryPromptState()
	beaconLight.Enabled = unlocked and hatchOpen
	if terminalChemistryStatus then
		terminalChemistryStatus.Text = chemistryVisible and chemistryRewardAvailable
			and [[PRODUCT: BLUE ROCK CANDY
OUTPUT DRAWER: READY
COLLECT AT LAB]]
			or chemistryVisible and [[EQUIPMENT: INSTALLED
REACTOR NETWORK: ONLINE
SELECT LAB STATUS]]
			or [[EQUIPMENT: AVAILABLE
OPEN LAB PROCUREMENT
PRICE: $]] .. tostring(chemistryConfig.Price)
	end
	if chemistryControlStatus then
		if not chemistryVisible then
			chemistryControlStatus.Text = [[REACTOR: OFFLINE
AWAITING EQUIPMENT]]
		elseif chemistryExperimentActive then
			chemistryControlStatus.Text = [[REACTION: RUNNING
PUMPS: ACTIVE
FLOW: CHARGING]]
		elseif chemistryRewardAvailable then
			chemistryControlStatus.Text = [[REACTION: COMPLETE
OUTPUT: READY
PRODUCT: BLUE ROCK CANDY]]
		elseif chemistryLab:GetAttribute("RewardState") == "Dispensing" then
			chemistryControlStatus.Text = [[REACTION: COMPLETE
OUTPUT: MOVING
PRODUCT: SECURED]]
		else
			chemistryControlStatus.Text = [[REACTOR: STANDBY
PUMPS: IDLE
FLOW: STOPPED]]
		end
	end

	local label = statusTextLabel()
	if label then
		if unlocked then
			label.Text = string.format(
				[[SHELTER STATUS
HATCH: %s
BLAST DOOR: %s
MAIN POWER: %s]],
				hatchOpen and "OPEN" or "SEALED",
				blastDoorOpen and "OPEN" or "SEALED",
				mainLightsOn and "ONLINE" or "EMERGENCY"
			)
			label.TextColor3 = mainLightsOn and Color3.fromRGB(65, 226, 218) or Color3.fromRGB(255, 171, 55)
			else
				label.Text = table.concat({
					"SHELTER PROJECT",
					"ACCESS: LOCKED",
					"POWER: OFFLINE",
				}, string.char(10))
				label.TextColor3 = Color3.fromRGB(255, 171, 55)
			end
	end
end

local function tweenModelPivot(model, destination, duration, style, direction)
	local driver = Instance.new("CFrameValue")
	driver.Name = "BunkerPivotDriver"
	driver.Value = model:GetPivot()
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:PivotTo(driver.Value)
		end
	end)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.InOut),
		{ Value = destination }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	driver:Destroy()
	if model.Parent then
		model:PivotTo(destination)
	end
end

local function tweenPart(part, destination, duration)
	local tween = TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
		{ CFrame = destination }
	)
	tween:Play()
	return tween
end

local function setHatchState(shouldOpen, instant)
	if not bunkerIsUnlocked() then
		hatchOpen = false
		hatchDoor:PivotTo(closedHatchPivot)
		updateStatus()
		return
	end
	if hatchMoving or hatchOpen == shouldOpen then
		updateStatus()
		return
	end
	hatchMoving = true
	hatchPrompt.Enabled = false
	hatchPanel.CanCollide = true

	local destination = shouldOpen and openHatchPivot or closedHatchPivot
	if instant then
		hatchDoor:PivotTo(destination)
	else
		tweenModelPivot(
			hatchDoor,
			destination,
			shouldOpen and 0.82 or 0.72,
			Enum.EasingStyle.Back,
			shouldOpen and Enum.EasingDirection.Out or Enum.EasingDirection.In
		)
	end

	hatchOpen = shouldOpen
	hatchMoving = false
	hatchPrompt.Enabled = true
	updateStatus()
end

local function setBlastDoorState(shouldOpen, instant)
	if not bunkerIsUnlocked() then
		blastDoorOpen = false
		leftPanel.CFrame = leftClosed
		rightPanel.CFrame = rightClosed
		leftPanel.CanCollide = true
		rightPanel.CanCollide = true
		updateStatus()
		return
	end
	if blastDoorMoving or blastDoorOpen == shouldOpen then
		updateStatus()
		return
	end
	blastDoorMoving = true
	blastDoorPrompt.Enabled = false
	leftPanel.CanCollide = true
	rightPanel.CanCollide = true

	local leftDestination = shouldOpen and leftOpen or leftClosed
	local rightDestination = shouldOpen and rightOpen or rightClosed
	if instant then
		leftPanel.CFrame = leftDestination
		rightPanel.CFrame = rightDestination
	else
		local leftTween = tweenPart(leftPanel, leftDestination, 0.72)
		tweenPart(rightPanel, rightDestination, 0.72)
		leftTween.Completed:Wait()
		leftPanel.CFrame = leftDestination
		rightPanel.CFrame = rightDestination
	end

	blastDoorOpen = shouldOpen
	leftPanel.CanCollide = not shouldOpen
	rightPanel.CanCollide = not shouldOpen
	blastDoorMoving = false
	blastDoorPrompt.Enabled = true
	updateStatus()
end

local function setMainLightsState(shouldEnable)
	mainLightsOn = shouldEnable and bunkerIsUnlocked()
	for _, descendant in ipairs(mainLights:GetDescendants()) do
		if descendant:IsA("Light") and descendant:GetAttribute("BunkerMainLight") == true then
			descendant.Enabled = shouldEnable
		elseif descendant:IsA("BasePart") and descendant:GetAttribute("BunkerMainLight") == true then
			descendant.Transparency = shouldEnable and 0 or 0.72
		end
	end
	updateStatus()
end

local function playerCharacterState(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(Workspace)
		or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") or not root:IsDescendantOf(character)
	then
		return nil
	end
	return character, humanoid, root
end

local function isNear(player, object, maximumDistance)
	local _, _, root = playerCharacterState(player)
	if not root or not object:IsA("BasePart") then
		return false
	end
	return (root.Position - object.Position).Magnitude <= maximumDistance
end

-- Hatch, blast-door, and power controls each get an independent, bounded
-- per-player budget. This executes before access snapshots or sweep queries so
-- forged prompt floods cannot amplify expensive server work.
local function consumePhysicalPromptRate(player, action)
	local _, _, root = playerCharacterState(player)
	local cooldown = PHYSICAL_PROMPT_RATE_SECONDS[action]
	if not root or type(cooldown) ~= "number" then
		return false
	end
	local playerRates = physicalPromptNextAt[player]
	if not playerRates then
		playerRates = {}
		physicalPromptNextAt[player] = playerRates
	end
	local now = Workspace:GetServerTimeNow()
	if now < (playerRates[action] or 0) then
		return false
	end
	playerRates[action] = now + cooldown
	return true
end

local function sendNotice(player, text)
	event:FireClient(player, "Notice", text)
end

local function invokeFamily(operation, ...)
	local events = ServerScriptService:FindFirstChild(Config.ServerEventsName or "CooperGameServerEvents")
	local api = events and events:FindFirstChild("API")
	if not api or not api:IsA("BindableFunction") then
		return false, nil, "Family task API is unavailable"
	end
	local arguments = table.pack(...)
	local ok, result, extra = pcall(function()
		return api:Invoke(operation, table.unpack(arguments, 1, arguments.n))
	end)
	if not ok then
		warn("[CooperBunker] Family API " .. tostring(operation) .. " failed: " .. tostring(result))
		return false, nil, result
	end
	return true, result, extra
end

local function createBlueRockCandyTool(ownerPlayer, batchToken)
	local tool = Instance.new("Tool")
	tool.Name = tostring(Config.CandyDelivery.ProductToolName or "Blue Rock Candy Pan")
	tool.ToolTip = "Fresh Blue Rock Candy in its delivery pan"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- The pan stays level and slightly in front of the torso. As a normal Tool it
	-- uses Roblox's numbered hotbar exactly like the delivered equipment boxes:
	-- press its number to equip, then press the same number again to stash it.
	tool.Grip = CFrame.new(0, -0.58, -1.15) * CFrame.Angles(0, math.rad(90), 0)
	tool:SetAttribute("CooperBlueRockCandy", true)
	tool:SetAttribute("ProductKind", "BlueRockCandy")
	tool:SetAttribute("OwnerUserId", ownerPlayer.UserId)
	tool:SetAttribute("BatchToken", tostring(batchToken or ""))
	tool:SetAttribute("CandyDeliveryCarry", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2.25, 0.16, 1.55)
	handle.Color = Color3.fromRGB(132, 146, 152)
	handle.Material = Enum.Material.Metal
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local function addPiece(name, size, relativeCFrame, color, material, transparency)
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.CFrame = handle.CFrame * relativeCFrame
		piece.Color = color
		piece.Material = material
		piece.Transparency = tonumber(transparency) or 0
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = false
		piece.Massless = true
		piece.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CandyPanWeld"
		weld.Part0 = handle
		weld.Part1 = piece
		weld.Parent = piece
		return piece
	end

	for _, rim in ipairs({
		{ "PanRimLeft", Vector3.new(0.13, 0.34, 1.55), Vector3.new(-1.06, 0.17, 0) },
		{ "PanRimRight", Vector3.new(0.13, 0.34, 1.55), Vector3.new(1.06, 0.17, 0) },
		{ "PanRimFront", Vector3.new(2.25, 0.34, 0.13), Vector3.new(0, 0.17, -0.71) },
		{ "PanRimBack", Vector3.new(2.25, 0.34, 0.13), Vector3.new(0, 0.17, 0.71) },
	}) do
		addPiece(rim[1], rim[2], CFrame.new(rim[3]), Color3.fromRGB(101, 116, 123), Enum.Material.Metal, 0)
	end
	local coreCrystal
	for index, definition in ipairs({
		{ offset = Vector3.new(-0.62, 0.42, -0.24), rotation = CFrame.Angles(math.rad(8), math.rad(18), math.rad(-20)), size = Vector3.new(0.38, 0.66, 0.38), color = Color3.fromRGB(42, 171, 255), material = Enum.Material.Neon },
		{ offset = Vector3.new(-0.18, 0.36, 0.20), rotation = CFrame.Angles(math.rad(-10), math.rad(-20), math.rad(22)), size = Vector3.new(0.42, 0.56, 0.42), color = Color3.fromRGB(31, 129, 255), material = Enum.Material.Glass },
		{ offset = Vector3.new(0.30, 0.44, -0.20), rotation = CFrame.Angles(math.rad(20), math.rad(15), math.rad(-10)), size = Vector3.new(0.36, 0.70, 0.36), color = Color3.fromRGB(91, 218, 255), material = Enum.Material.Glass },
		{ offset = Vector3.new(0.72, 0.33, 0.22), rotation = CFrame.Angles(math.rad(-13), math.rad(26), math.rad(18)), size = Vector3.new(0.34, 0.50, 0.34), color = Color3.fromRGB(58, 188, 255), material = Enum.Material.Glass },
		{ offset = Vector3.new(0.06, 0.30, -0.34), rotation = CFrame.Angles(math.rad(16), math.rad(-12), math.rad(-16)), size = Vector3.new(0.30, 0.45, 0.30), color = Color3.fromRGB(70, 204, 255), material = Enum.Material.Glass },
	}) do
		local crystal = addPiece(
			"BlueCrystal" .. tostring(index),
			definition.size,
			CFrame.new(definition.offset) * definition.rotation,
			definition.color,
			definition.material,
			definition.material == Enum.Material.Glass and 0.08 or 0.02
		)
		coreCrystal = coreCrystal or crystal
	end
	local candyLight = Instance.new("PointLight")
	candyLight.Name = "CandyGlow"
	candyLight.Color = Color3.fromRGB(80, 195, 255)
	candyLight.Brightness = 0.5
	candyLight.Range = 4
	candyLight.Shadows = false
	candyLight.Parent = coreCrystal

	return tool
end

local function playerHasBlueRockCandy(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	for _, container in ipairs({ backpack, character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool")
					and item:GetAttribute("CooperBlueRockCandy") == true
				then
					return item
				end
			end
		end
	end
	return nil
end

local function candyDeliveryState(player)
	local invoked, snapshot = invokeFamily("GetSnapshot", player)
	local delivery = invoked and type(snapshot) == "table" and snapshot.candyDelivery or nil
	return type(delivery) == "table" and delivery or nil
end

candyPresentation.readyToken = function(player)
	local delivery = candyDeliveryState(player)
	if not delivery
		or delivery.active == true
		or delivery.batchReady ~= true
		or type(delivery.readyBatchToken) ~= "string"
		or delivery.readyBatchToken == ""
	then
		return nil
	end
	return delivery.readyBatchToken
end

candyPresentation.updateDepth = function()
	chemistryLab:SetAttribute("RewardQueueDepth", #candyPresentation.queue)
end

candyPresentation.removePlayer = function(player)
	candyPresentation.queued[player] = nil
	for index = #candyPresentation.queue, 1, -1 do
		if candyPresentation.queue[index] == player then
			table.remove(candyPresentation.queue, index)
		end
	end
	candyPresentation.updateDepth()
end

candyPresentation.queuePlayer = function(player)
	if not player or player.Parent ~= Players or candyPresentation.queued[player]
		or chemistryRewardOwnerUserId == player.UserId
	then
		return false
	end
	if player:GetAttribute("CooperCandyBatchReady") ~= true
		or player:GetAttribute("CooperCandyDeliveryActive") == true
	then
		return false
	end
	candyPresentation.queued[player] = true
	table.insert(candyPresentation.queue, player)
	candyPresentation.updateDepth()
	if candyPresentation.pump then
		candyPresentation.pump()
	end
	return true
end

candyPresentation.release = function(ownerPlayer, shouldRequeue, message)
	if not ownerPlayer or chemistryRewardOwnerUserId ~= ownerPlayer.UserId then
		return false
	end
	resetChemistryReward(true)
	if message and ownerPlayer.Parent == Players then
		sendNotice(ownerPlayer, message)
	end
	if shouldRequeue and ownerPlayer.Parent == Players
		and ownerPlayer:GetAttribute("CooperCandyBatchReady") == true
	then
		candyPresentation.eligibleAt[ownerPlayer] = Workspace:GetServerTimeNow() + candyPresentation.retrySeconds
		candyPresentation.queuePlayer(ownerPlayer)
	end
	if candyPresentation.pump then
		task.defer(candyPresentation.pump)
	end
	return true
end

candyPresentation.pump = function()
	if candyPresentation.pumping
		or not chemistryVisible
		or chemistryAssemblyActive
		or chemistryExperimentActive
		or chemistryRewardAvailable
		or chemistryLab:GetAttribute("RewardState") ~= "Empty"
	then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	local candidate
	local candidateToken
	local passes = #candyPresentation.queue
	for _ = 1, passes do
		local queuedPlayer = table.remove(candyPresentation.queue, 1)
		candyPresentation.queued[queuedPlayer] = nil
		if queuedPlayer and queuedPlayer.Parent == Players
			and queuedPlayer:GetAttribute("CooperGameProfileLoaded") == true
			and queuedPlayer:GetAttribute("CooperChemistrySetupPlaced") == true
			and queuedPlayer:GetAttribute("CooperCandyBatchReady") == true
			and queuedPlayer:GetAttribute("CooperCandyDeliveryActive") ~= true
		then
			local token = candyPresentation.readyToken(queuedPlayer)
			local eligibleAt = tonumber(candyPresentation.eligibleAt[queuedPlayer]) or 0
			if token and now >= eligibleAt and playerHasBunkerAccess(queuedPlayer)
				and isNear(queuedPlayer, candyCollectAnchor, candyPresentation.presentRadius)
			then
				candidate = queuedPlayer
				candidateToken = token
				break
			end
			-- Keep durable batches in fair FIFO order while their owner is away,
			-- cooling down after a lease, or still walking back to the bunker.
			candyPresentation.queued[queuedPlayer] = true
			table.insert(candyPresentation.queue, queuedPlayer)
		end
	end
	candyPresentation.updateDepth()
	if not candidate then
		return false
	end

	candyPresentation.pumping = true
	task.spawn(function()
		local presented = presentChemistryReward(candidate, candidateToken)
		candyPresentation.pumping = false
		if presented then
			candyPresentation.serial += 1
			local presentationSerial = candyPresentation.serial
			candyPresentation.leaseExpiresAt = Workspace:GetServerTimeNow() + candyPresentation.leaseSeconds
			chemistryLab:SetAttribute("RewardLeaseExpiresAt", candyPresentation.leaseExpiresAt)
			sendNotice(candidate, "Your finished Blue Rock Candy is in the output pan. Collect it before the tray rotates to the next chemist.")
			task.delay(candyPresentation.leaseSeconds + 0.1, function()
				if presentationSerial == candyPresentation.serial
					and chemistryRewardAvailable
					and chemistryRewardOwnerUserId == candidate.UserId
				then
					candyPresentation.release(
						candidate,
						true,
						"The shared output tray retracted for the next chemist. Your finished batch is saved and will return when you approach the lab."
					)
				end
			end)
		else
			if chemistryRewardOwnerUserId == candidate.UserId then
				resetChemistryReward(true)
			end
			if candidate.Parent == Players and candidate:GetAttribute("CooperCandyBatchReady") == true then
				candyPresentation.queuePlayer(candidate)
			end
		end
		task.defer(candyPresentation.pump)
	end)
	return true
end

local function ensureCandyDeliveryTool(player, shouldEquip)
	if not player or player.Parent ~= Players then
		return false
	end
	local delivery = candyDeliveryState(player)
	local active = delivery and delivery.active == true
	local expectedToken = active and tostring(delivery.batchToken or "") or ""
	local keptTool
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("CooperBlueRockCandy") == true then
					local valid = active
						and expectedToken ~= ""
						and item:GetAttribute("OwnerUserId") == player.UserId
						and item:GetAttribute("ProductKind") == "BlueRockCandy"
						and item:GetAttribute("BatchToken") == expectedToken
					if valid and not keptTool then
						keptTool = item
					else
						item:Destroy()
					end
				end
			end
		end
	end
	if not active or expectedToken == "" then
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not keptTool and backpack then
		keptTool = createBlueRockCandyTool(player, expectedToken)
		keptTool:SetAttribute("RecoveredCandyDelivery", true)
		keptTool.Parent = backpack
		sendNotice(player, "Your undelivered Blue Rock Candy pan was restored to your hotbar.")
	end
	if shouldEquip and keptTool then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				humanoid:EquipTool(keptTool)
			end)
		end
	end
	return keptTool ~= nil
end

local function collectChemistryReward(subjectPlayer)
	local player = subjectPlayer
	if chemistryRewardClaiming
		or not chemistryRewardAvailable
		or chemistryLab:GetAttribute("RewardState") ~= "Present"
	then
		return false
	end
	if player:GetAttribute("CooperPartyState") ~= "Active" then
		sendNotice(player, "Chemistry is paused until the party host reconnects.")
		return false
	end
	if chemistryRewardOwnerUserId ~= player.UserId then
		sendNotice(player, "That blue rock-candy batch belongs to the chemist who ran it.")
		return false
	end
	if not playerHasBunkerAccess(player)
		or player:GetAttribute("CooperChemistrySetupPlaced") ~= true
		or not chemistryVisible
		or not isNear(player, candyCollectAnchor, collectCandyPrompt.MaxActivationDistance + 3)
	then
		return false
	end

	local character, humanoid = playerCharacterState(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not humanoid or not backpack then
		sendNotice(player, "Your backpack is not ready for the candy yet.")
		return false
	end
	if player:GetAttribute("CooperCandyDeliveryActive") == true or playerHasBlueRockCandy(player) then
		sendNotice(player, "Deliver your current Blue Rock Candy pan before making another batch.")
		return false
	end
	local presentedBatchToken = candyPresentation.batchToken
	if presentedBatchToken == "" then
		candyPresentation.release(player, false, "That output token expired. Your saved batch will be reconstructed safely.")
		return false
	end

	chemistryRewardClaiming = true
	collectCandyPrompt.Enabled = false
	local invoked, accepted, batchToken = invokeFamily(
		"ReportAction",
		player,
		"CandyBatchCollected",
		{ productKind = "BlueRockCandy", batchToken = presentedBatchToken }
	)
	if not invoked or accepted ~= true or type(batchToken) ~= "string" or batchToken == "" then
		local stillReadyToken = candyPresentation.readyToken(player)
		if stillReadyToken ~= presentedBatchToken then
			candyPresentation.release(player, false, "That output token is no longer active. The shared tray has been reset safely.")
			return false
		end
		chemistryRewardClaiming = false
		chemistryRewardAvailable = true
		chemistryLab:SetAttribute("RewardAvailable", true)
		chemistryLab:SetAttribute("RewardState", "Present")
		collectCandyPrompt.Enabled = true
		sendNotice(player, "The buyer contract could not be assigned yet. Your candy is still in the output pan.")
		return false
	end

	chemistryRewardAvailable = false
	chemistryLab:SetAttribute("RewardAvailable", false)
	chemistryLab:SetAttribute("RewardState", "Dispensing")
	local staleTool = playerHasBlueRockCandy(player)
	if staleTool then
		staleTool:Destroy()
	end
	local candyTool = createBlueRockCandyTool(player, batchToken)
	candyTool.Parent = backpack
	pcall(function()
		humanoid:EquipTool(candyTool)
	end)

	resetChemistryReward(false)
	chemistryRewardClaiming = false
	chemistryControlStatus.Text = [[REACTOR: STANDBY
PUMPS: IDLE
OUTPUT: RETRACTING]]
	sendNotice(player, "Blue Rock Candy pan equipped! Follow the yellow arrow to the Los Pollos Hermanos truck, or press its hotbar number to stash it.")
	task.delay(0.65, candyPresentation.pump)
	return true
end

local function startChemistryExperiment(player)
	local now = Workspace:GetServerTimeNow()
	if player:GetAttribute("CooperPartyState") ~= "Active" then
		sendNotice(player, "Chemistry is paused until the party host reconnects.")
		return false
	end
	if player:GetAttribute("CooperCandyDeliveryActive") == true or playerHasBlueRockCandy(player) then
		sendNotice(player, "Finish delivering your current Blue Rock Candy pan before starting another batch.")
		return false
	end
	if player:GetAttribute("CooperCandyBatchReady") == true then
		sendNotice(player, "Collect your saved Blue Rock Candy batch before starting another reaction.")
		candyPresentation.queuePlayer(player)
		return false
	end
	if chemistryRewardAvailable then
		sendNotice(player, "Collect the Blue Rock Candy from the output drawer first.")
		return false
	end
	if chemistryLab:GetAttribute("RewardState") == "Dispensing" then
		sendNotice(player, "The chemistry output drawer is still moving.")
		return false
	end
	if chemistryExperimentActive then
		local remaining = math.max(1, math.ceil((chemistryLab:GetAttribute("ExperimentEndsAt") or now) - now))
		sendNotice(player, "Reaction already running — " .. tostring(remaining) .. "s remaining.")
		return false
	end
	if now < chemistryExperimentReadyAt then
		local remaining = math.max(1, math.ceil(chemistryExperimentReadyAt - now))
		sendNotice(player, "The reactor is cooling down. Ready again in " .. tostring(remaining) .. "s.")
		return false
	end

	chemistryExperimentToken += 1
	local token = chemistryExperimentToken
	local endsAt = now + CHEMISTRY_EXPERIMENT_DURATION
	chemistryExperimentReadyAt = endsAt + CHEMISTRY_EXPERIMENT_COOLDOWN
	chemistryExperimentOwnerUserId = player.UserId
	setChemistryExperimentActive(true)
	chemistryLab:SetAttribute("ExperimentStartedAt", now)
	chemistryLab:SetAttribute("ExperimentEndsAt", endsAt)
	chemistryLab:SetAttribute("ExperimentReadyAt", chemistryExperimentReadyAt)
	chemistryControlStatus.Text = [[REACTION: RUNNING
PUMPS: ACTIVE
FLOW: CHARGING]]
	updateChemistryPromptState()
	vapor:Emit(4)
	sendNotice(player, "Chemistry cycle started! Watch the pumps, tubes, and reactor.")

	task.delay(CHEMISTRY_EXPERIMENT_DURATION, function()
		if token ~= chemistryExperimentToken
			or not chemistryVisible
			or not chemistryExperimentActive
		then
			return
		end
		resetChemistryExperimentVisuals()
		-- Persist the completed reaction before leasing the one shared physical
		-- tray. If the owner leaves at any point after this returns, the same token
		-- is restored on their next server and can be presented again.
		local invoked, accepted, batchToken = invokeFamily(
			"ReportAction",
			player,
			"CandyBatchProduced",
			{ productKind = "BlueRockCandy" }
		)
		if invoked and accepted == true and type(batchToken) == "string" and batchToken ~= "" then
			candyPresentation.queuePlayer(player)
			candyPresentation.pump()
			sendNotice(player, "Chemistry complete! Your Blue Rock Candy batch is saved and will slide out when the shared tray is available.")
		else
			sendNotice(player, "Chemistry finished, but its durable output record could not be secured. Please run the reaction again.")
		end
		task.delay(CHEMISTRY_EXPERIMENT_COOLDOWN, function()
			if token == chemistryExperimentToken and chemistryVisible and not chemistryExperimentActive then
				updateChemistryPromptState()
			end
		end)
	end)
	return true
end

local chemistryAttributeConnections = {}
local chemistryPlacedState = {}

local function anyChemistryOwner()
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate:GetAttribute("CooperGameProfileLoaded") == true
			and candidate:GetAttribute("CooperChemistrySetupPlaced") == true
		then
			return true
		end
	end
	return false
end

local function refreshChemistryVisibility(animate)
	local shouldShow = anyChemistryOwner()
	if shouldShow and not chemistryVisible then
		revealChemistryLab(animate == true)
	elseif not shouldShow and chemistryVisible then
		hideChemistryLab()
	end
	updateStatus()
end

local function watchChemistryOwnership(player)
	local old = chemistryAttributeConnections[player]
	if old then
		for _, connection in ipairs(old) do
			connection:Disconnect()
		end
	end
	chemistryPlacedState[player] = player:GetAttribute("CooperChemistrySetupPlaced") == true
	local connections = {}
	table.insert(connections, player:GetAttributeChangedSignal("CooperChemistrySetupPlaced"):Connect(function()
		local wasPlaced = chemistryPlacedState[player] == true
		local isPlaced = player:GetAttribute("CooperChemistrySetupPlaced") == true
		chemistryPlacedState[player] = isPlaced
		if wasPlaced and not isPlaced then
			if chemistryExperimentOwnerUserId == player.UserId then
				chemistryExperimentToken += 1
				chemistryExperimentReadyAt = 0
				resetChemistryExperimentVisuals()
			end
			if chemistryRewardOwnerUserId == player.UserId then
				candyPresentation.release(player, false)
			end
		end
		if player:GetAttribute("CooperGameProfileLoaded") == true then
			refreshChemistryVisibility(isPlaced and not wasPlaced)
			if isPlaced and player:GetAttribute("CooperCandyBatchReady") == true then
				candyPresentation.queuePlayer(player)
			end
		end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("CooperGameProfileLoaded"):Connect(function()
		if player:GetAttribute("CooperGameProfileLoaded") == true then
			-- A lab found at the profile-loaded boundary is a saved installation and
			-- restores instantly. Only a later false->true placement transition runs
			-- the assembly ceremony.
			chemistryPlacedState[player] = player:GetAttribute("CooperChemistrySetupPlaced") == true
			refreshChemistryVisibility(false)
			if player:GetAttribute("CooperCandyBatchReady") == true then
				candyPresentation.queuePlayer(player)
			end
		else
			if chemistryExperimentOwnerUserId == player.UserId then
				chemistryExperimentToken += 1
				chemistryExperimentReadyAt = 0
				resetChemistryExperimentVisuals()
			end
			if chemistryRewardOwnerUserId == player.UserId then
				candyPresentation.release(player, false)
			end
		end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("CooperCandyBatchReady"):Connect(function()
		if player:GetAttribute("CooperCandyBatchReady") == true then
			candyPresentation.queuePlayer(player)
		else
			candyPresentation.removePlayer(player)
			task.delay(0.2, function()
				-- Collection flips ready->false immediately before active->true.
				-- Defer stale-tray cleanup so that atomic transition cannot race the
				-- physical collector while it is creating the Tool.
				if player.Parent == Players
					and chemistryRewardOwnerUserId == player.UserId
					and player:GetAttribute("CooperCandyBatchReady") ~= true
					and player:GetAttribute("CooperCandyDeliveryActive") ~= true
				then
					candyPresentation.release(player, false)
				end
			end)
		end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("CooperCandyDeliveryActive"):Connect(function()
		task.delay(0.25, function()
			ensureCandyDeliveryTool(player, false)
		end)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("CooperPartyState"):Connect(function()
		if player:GetAttribute("CooperPartyState") ~= "Active"
			and chemistryExperimentOwnerUserId == player.UserId
			and chemistryExperimentActive
		then
			-- The profile authority deliberately rejects progression while the host
			-- is absent. Cancel the visual reaction as well so it cannot finish into
			-- an output that no durable profile is allowed to claim.
			chemistryExperimentToken += 1
			chemistryExperimentReadyAt = 0
			resetChemistryExperimentVisuals()
			sendNotice(player, "The reaction paused safely because the party host disconnected. Start it again when the party resumes.")
		end
		updateChemistryPromptState()
	end))
	table.insert(connections, player.CharacterAdded:Connect(function()
		task.delay(0.75, function()
			ensureCandyDeliveryTool(player, false)
			if player:GetAttribute("CooperCandyBatchReady") == true then
				candyPresentation.queuePlayer(player)
			end
		end)
	end))
	table.insert(connections, player.CharacterRemoving:Connect(function()
		player:SetAttribute("CooperBunkerComputerSessionUntil", nil)
		event:FireClient(player, "TerminalClose", "Research terminal closed")
	end))
	chemistryAttributeConnections[player] = connections
	task.defer(refreshChemistryVisibility, false)
	task.delay(0.75, function()
		ensureCandyDeliveryTool(player, false)
		if player:GetAttribute("CooperCandyBatchReady") == true then
			candyPresentation.queuePlayer(player)
		end
	end)
end

researchPrompt.Triggered:Connect(function(player)
	if not playerHasBunkerAccess(player) then
		sendNotice(player, "Unlock your personal bunker before using its research computer.")
		return
	end
	if player:GetAttribute("CooperPartyState") ~= "Active" then
		sendNotice(player, "The research terminal is paused until the party host reconnects.")
		return
	end
	if not isNear(player, bunkerTerminalInputAnchor, researchPrompt.MaxActivationDistance + 3) then
		return
	end
	player:SetAttribute("CooperBunkerComputerSessionUntil", Workspace:GetServerTimeNow() + 300)
	event:FireClient(player, "TerminalOpen", {
		name = "Bunker Research Terminal",
		mode = "ChemistryProcurement",
	})
end)

chemistryPrompt.Triggered:Connect(function(player)
	if not playerHasBunkerAccess(player)
		or player:GetAttribute("CooperChemistrySetupPlaced") ~= true
	then
		sendNotice(player, "This chemistry lab is not installed for your bunker authorization.")
		return
	end
	if not chemistryVisible
		or chemistryAssemblyActive
		or not isNear(player, chemistryPromptAnchor, chemistryPrompt.MaxActivationDistance + 3)
	then
		return
	end
	startChemistryExperiment(player)
end)

collectCandyPrompt.Triggered:Connect(function(player)
	collectChemistryReward(player)
end)

Players.PlayerAdded:Connect(watchChemistryOwnership)
for _, player in ipairs(Players:GetPlayers()) do
	watchChemistryOwnership(player)
end

-- Reconstruct saved output batches lazily when their owners approach the lab.
-- This one-second coordinator also repairs missed attribute events and releases
-- a tray whose owner walked away, so the shared apparatus cannot deadlock.
task.spawn(function()
	while script.Parent do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("CooperGameProfileLoaded") == true
				and player:GetAttribute("CooperCandyBatchReady") == true
			then
				candyPresentation.queuePlayer(player)
			end
		end
		if chemistryRewardAvailable and chemistryRewardOwnerUserId > 0 then
			local owner = Players:GetPlayerByUserId(chemistryRewardOwnerUserId)
			if not owner then
				resetChemistryReward(true)
			elseif owner:GetAttribute("CooperCandyBatchReady") ~= true then
				candyPresentation.release(owner, false)
			elseif not isNear(owner, candyCollectAnchor, candyPresentation.presentRadius + 12) then
				candyPresentation.release(
					owner,
					true,
					"The shared output tray retracted when you left the lab. Your completed batch is still saved."
				)
			end
		end
		candyPresentation.pump()
	end
end)

-- Sweep safety must account for the player's complete physical assembly, not
-- only HumanoidRootPart. That keeps an arm, accessory, or equipped Tool from
-- being clipped by either heavy door while its root happens to be just outside
-- the threshold. Restricting the overlap query to live character models avoids
-- decorative bunker geometry falsely blocking a close.
function candyPresentation.sweepVolumeOccupied(boxCFrame, boxSize)
	local characters = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character, humanoid = playerCharacterState(player)
		if character and humanoid then
			table.insert(characters, character)
		end
	end
	if #characters == 0 then
		return false
	end

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = characters
	overlap.MaxParts = 1
	if #workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlap) > 0 then
		return true
	end

	-- Also protect loose physical props and dropped/held Tools. Static authored
	-- ground-cut panels overlap the shaft volume by design, so ignore anchored
	-- scenery and only treat collidable physics or a Tool assembly as a blocker.
	local physicalOverlap = OverlapParams.new()
	physicalOverlap.FilterType = Enum.RaycastFilterType.Exclude
	physicalOverlap.FilterDescendantsInstances = { bunker }
	for _, part in ipairs(workspace:GetPartBoundsInBox(boxCFrame, boxSize, physicalOverlap)) do
		if (not part.Anchored and part.CanCollide) or part:FindFirstAncestorWhichIsA("Tool") then
			return true
		end
	end
	return false
end

local function hatchSweepOccupied()
	-- Matches the authored shaft's X/Z clearance and the full vertical range
	-- swept by the hatch panel, expressed in shaft-local coordinates so the
	-- safety volume remains correct if the complete property is relocated.
	local sweepCFrame = shaftOpening.CFrame * CFrame.new(0, 1.25, 0)
	return candyPresentation.sweepVolumeOccupied(sweepCFrame, Vector3.new(7.4, 7.5, 7.4))
end

local function blastDoorwayOccupied()
	local doorwayCenter = (leftClosed.Position + rightClosed.Position) * 0.5
	local doorwayFrame = CFrame.new(doorwayCenter) * leftClosed.CFrame.Rotation
	return candyPresentation.sweepVolumeOccupied(doorwayFrame, Vector3.new(9.2, 9.3, 4.0))
end

hatchPrompt.Triggered:Connect(function(player)
	if not consumePhysicalPromptRate(player, "Hatch") then
		return
	end
	if not playerHasBunkerAccess(player) then
		local snapshot = bunkerAccessSnapshot(player)
		if snapshot.purchased == true and snapshot.unlocked ~= true then
			sendNotice(
				player,
				string.format(
					"Heavy bunker construction is still underway. Estimated completion: %d seconds.",
					math.max(0, math.ceil(tonumber(snapshot.remaining) or 0))
				)
			)
		else
			sendNotice(
				player,
				string.format(
					"Buy the Secret Underground Bunker at Sheldon's computer for $%d.",
					math.max(1, math.floor(tonumber(snapshot.price) or 2500))
				)
			)
		end
		return
	end
	if hatchMoving or not isNear(player, hatchControl, hatchPrompt.MaxActivationDistance + 4) then
		return
	end
	if hatchOpen and hatchSweepOccupied() then
		sendNotice(player, "The hatch cannot close while someone is on the ladder.")
		return
	end
	setHatchState(not hatchOpen, false)
end)

blastDoorPrompt.Triggered:Connect(function(player)
	if not consumePhysicalPromptRate(player, "BlastDoor") then
		return
	end
	if not playerHasBunkerAccess(player) then
		sendNotice(player, "This bunker belongs to a different construction authorization.")
		return
	end
	if blastDoorMoving or not isNear(player, blastDoorControl, blastDoorPrompt.MaxActivationDistance + 4) then
		return
	end
	if blastDoorOpen and blastDoorwayOccupied() then
		sendNotice(player, "The blast door cannot close while the doorway is occupied.")
		return
	end
	setBlastDoorState(not blastDoorOpen, false)
end)

lightPrompt.Triggered:Connect(function(player)
	if not consumePhysicalPromptRate(player, "MainLights") then
		return
	end
	if not playerHasBunkerAccess(player) then
		sendNotice(player, "Bunker power controls are locked.")
		return
	end
	if not isNear(player, lightControl, lightPrompt.MaxActivationDistance + 4) then
		return
	end
	setMainLightsState(not mainLightsOn)
end)

recoveryZone.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or recoveryDebounce[player] then
		return
	end
	local currentCharacter, humanoid, root = playerCharacterState(player)
	if not root or humanoid.SeatPart ~= nil then
		return
	end
	if not playerHasBunkerAccess(player) then
		recoveryDebounce[player] = true
		local viewingAnchor = environment:FindFirstChild("BunkerConstructionViewingAnchor", true)
		local destination = if viewingAnchor and viewingAnchor:IsA("BasePart")
			then viewingAnchor.CFrame * CFrame.new(0, 3.2, 0)
			else shaftOpening.CFrame * CFrame.new(0, 3.2, 8)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		currentCharacter:PivotTo(destination)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		sendNotice(player, "Bunker access is locked to its construction authorization.")
		task.delay(1.5, function()
			recoveryDebounce[player] = nil
		end)
		return
	end

	-- This fail-safe is the bunker's only character relocation. Normal entry
	-- and exit always use the physical hatch, shaft, landings, and ladder.
	recoveryDebounce[player] = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	currentCharacter:PivotTo(recoveryAnchor.CFrame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	sendNotice(player, "Emergency floor recovery returned you to the airlock.")
	task.delay(1.5, function()
		recoveryDebounce[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	recoveryDebounce[player] = nil
	physicalPromptNextAt[player] = nil
	candyPresentation.removePlayer(player)
	candyPresentation.eligibleAt[player] = nil
	if chemistryExperimentOwnerUserId == player.UserId then
		chemistryExperimentToken += 1
		chemistryExperimentReadyAt = 0
		resetChemistryExperimentVisuals()
	end
	if chemistryRewardOwnerUserId == player.UserId then
		-- The profile owns the finished batch; only the shared visual lease is
		-- released. CooperGame saves the same ready token during PlayerRemoving.
		candyPresentation.release(player, false)
	end
	chemistryPlacedState[player] = nil
	local chemistryConnections = chemistryAttributeConnections[player]
	if chemistryConnections then
		for _, chemistryConnection in ipairs(chemistryConnections) do
			chemistryConnection:Disconnect()
		end
		chemistryAttributeConnections[player] = nil
	end
	local connection = accessCharacterConnections[player]
	if connection then
		connection:Disconnect()
		accessCharacterConnections[player] = nil
	end
	task.defer(refreshChemistryVisibility, false)
end)

-- Smooth, bounded fan/beacon/lab motion. All moving parts remain anchored, and
-- the 12 Hz cosmetic cadence keeps replicated property traffic modest on mobile.
local fanAngle = 0
local visualAccumulator = 0
RunService.Heartbeat:Connect(function(deltaTime)
	visualAccumulator += deltaTime
	if visualAccumulator < 1 / 12 then
		return
	end
	local step = visualAccumulator
	visualAccumulator = 0
	if bunkerIsUnlocked() and mainLightsOn and fanBlades.Parent then
		fanAngle = (fanAngle + step * 1.8) % (math.pi * 2)
		fanBlades:PivotTo(fanBasePivot * CFrame.Angles(0, 0, fanAngle))
	end
	if hatchOpen and beaconLight.Enabled then
		beaconLight.Brightness = 1.35 + math.sin(os.clock() * 5.5) * 0.65
	end
	local animationTime = os.clock()
	trackballLight.Brightness = bunkerIsUnlocked()
		and (1.15 + math.sin(animationTime * 2.6) * 0.35)
		or 0
	if chemistryVisible and chemistryExperimentActive and not chemistryAssemblyActive then
		local livePadFrame = chemistryPad.CFrame
		for _, reservoir in ipairs(chemistryReservoirs) do
			local fluid = reservoir.part
			if fluid.Parent then
				local height = reservoir.baseHeight
					+ math.sin(animationTime * 0.72 + reservoir.phase) * reservoir.amplitude
				local delta = height - reservoir.baseHeight
				fluid.Size = Vector3.new(height, fluid.Size.Y, fluid.Size.Z)
				fluid.CFrame = livePadFrame
					* CFrame.new(reservoir.baseOffset + Vector3.new(0, delta * 0.5, 0))
					* cylinderRotation
				local shimmer = (math.sin(animationTime * 2.4 + reservoir.phase) + 1) * 0.5
				fluid.Color = reservoir.baseColor:Lerp(Color3.new(1, 1, 1), shimmer * 0.1)
			end
		end
		for _, flow in ipairs(chemistryTubeFluids) do
			if flow.part.Parent then
				local wave = (math.sin(animationTime * flow.speed - flow.phase) + 1) * 0.5
				flow.part.Transparency = 0.03 + (1 - wave) * 0.28
				flow.part.Color = flow.color:Lerp(Color3.new(1, 1, 1), wave * 0.12)
			end
		end
		for _, flow in ipairs(chemistryFlowBeams) do
			local wave = (math.sin(animationTime * 5.4 - flow.phase) + 1) * 0.5
			flow.beam.Enabled = true
			flow.beam.Color = ColorSequence.new(flow.color:Lerp(Color3.new(1, 1, 1), wave * 0.1))
			flow.beam.Transparency = NumberSequence.new(0.03 + (1 - wave) * 0.16)
		end
		for _, bubble in ipairs(chemistryBubbles) do
			if bubble.part.Parent then
				local rise = (animationTime * bubble.speed + bubble.phase) % 1
				local swirl = animationTime * 0.65 + bubble.phase * math.pi * 2
				local localPosition = Vector3.new(
					bubble.x + math.cos(swirl) * 0.09,
					padTop + 2.05 + rise * 3.45,
					bubble.z + math.sin(swirl) * 0.09
				)
				bubble.part.Position = livePadFrame:PointToWorldSpace(localPosition)
				bubble.part.Transparency = 0.12 + (1 - rise) * 0.24
			end
		end
		for _, impeller in ipairs(chemistryImpellers) do
			if impeller.part.Parent then
				impeller.part.CFrame = livePadFrame * impeller.homeLocal
					* CFrame.Angles(0, 0, animationTime * 4.5 * impeller.direction)
			end
		end
		for _, lamp in ipairs(chemistryStatusLamps) do
			if lamp.part.Parent then
				local pulse = 0.78 + (math.sin(animationTime * 2.2 + lamp.phase) + 1) * 0.11
				lamp.part.Color = lamp.color:Lerp(Color3.new(1, 1, 1), pulse * 0.16)
				lamp.part.Transparency = 0.04 + (1 - pulse) * 0.25
			end
		end
		if animationTime >= chemistryNextVaporAt then
			chemistryNextVaporAt = animationTime + 1.6
			vapor:Emit(2)
		end
	end
end)

-- A fresh session always begins in the safest readable state.
hatchDoor:PivotTo(closedHatchPivot)
leftPanel.CFrame = leftClosed
rightPanel.CFrame = rightClosed
hatchOpen = false
blastDoorOpen = false
leftPanel.CanCollide = true
rightPanel.CanCollide = true
hideChemistryLab()
refreshChemistryVisibility(false)
setMainLightsState(bunkerIsUnlocked())
updateStatus()

bunker:GetAttributeChangedSignal("UnlockState"):Connect(function()
	if bunkerIsUnlocked() then
		hatchDoor:PivotTo(closedHatchPivot)
		leftPanel.CFrame = leftClosed
		rightPanel.CFrame = rightClosed
		hatchOpen = false
		blastDoorOpen = false
		leftPanel.CanCollide = true
		rightPanel.CanCollide = true
		setMainLightsState(true)
	else
		hatchOpen = false
		blastDoorOpen = false
		setMainLightsState(false)
	end
	updateStatus()
end)

print("[CooperBunker] Server controller ready v" .. CONTROLLER_VERSION)
