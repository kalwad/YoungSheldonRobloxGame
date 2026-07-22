-- Idempotent edit-mode installer for the Cooper backyard bunker.
--
-- Version 2 replaces the old fade/teleport shortcut with a real, continuous
-- climbable shaft.  The installer cuts only the small hatch aperture through
-- the authored ground layers, frames that opening, and connects it directly to
-- the airlock below.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local INSTALL_VERSION = "2.0.0"
local SHAFT_CUT_REVISION = 3
local BUNKER_NAME = "BackyardBunker"
local REMOTES_NAME = "CooperBunkerRemotes"
local EVENT_NAME = "BunkerEvent"

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "workspace.CooperHouseEnvironment was not found")

local siteAndStreet = environment:FindFirstChild("SiteAndStreet")
local lot = siteAndStreet and siteAndStreet:FindFirstChild("CooperLot")
assert(lot and lot:IsA("BasePart"), "CooperHouseEnvironment.SiteAndStreet.CooperLot was not found")
local neighborhoodGround = siteAndStreet:FindFirstChild("NeighborhoodGround")
assert(
	neighborhoodGround and neighborhoodGround:IsA("BasePart"),
	"CooperHouseEnvironment.SiteAndStreet.NeighborhoodGround was not found"
)

local groundY = lot.Position.Y + lot.Size.Y * 0.5
local surfacePosition = Vector3.new(
	lot.Position.X + 20.56,
	groundY,
	lot.Position.Z + 36.65
)
local surfaceOrigin = CFrame.new(surfacePosition)
local shaftCenter = Vector3.new(surfacePosition.X, groundY, surfacePosition.Z - 0.15)

-- All authored positions are derived from these lot-relative anchors.  This
-- keeps the bunker attached to the Cooper environment even if the whole set is
-- moved in Studio.
local undergroundCenter = Vector3.new(
	surfacePosition.X - 7,
	groundY - 24.735,
	surfacePosition.Z + 8.85
)
local undergroundOrigin = CFrame.new(undergroundCenter)
local roomSize = Vector3.new(34, 12, 28)
local floorTopY = undergroundCenter.Y - roomSize.Y * 0.5 + 0.5

local COLORS = {
	concrete = Color3.fromRGB(54, 59, 62),
	concreteDark = Color3.fromRGB(35, 39, 42),
	gunmetal = Color3.fromRGB(54, 64, 70),
	steel = Color3.fromRGB(112, 125, 128),
	steelLight = Color3.fromRGB(174, 184, 181),
	olive = Color3.fromRGB(83, 92, 62),
	black = Color3.fromRGB(12, 15, 17),
	amber = Color3.fromRGB(255, 171, 55),
	yellow = Color3.fromRGB(244, 195, 60),
	red = Color3.fromRGB(230, 54, 48),
	cyan = Color3.fromRGB(65, 226, 218),
	cyanDark = Color3.fromRGB(17, 92, 91),
	warm = Color3.fromRGB(255, 226, 167),
	paper = Color3.fromRGB(213, 226, 210),
}

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"CooperBackyardBunkerInstall",
		"Install Cooper backyard bunker"
	)
end)

local function makePart(parent, name, size, cframe, options)
	options = options or {}
	local object = Instance.new(options.className or "Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Anchored = if options.anchored == nil then true else options.anchored
	object.CanCollide = if options.canCollide == nil then true else options.canCollide
	object.CanTouch = if options.canTouch == nil then false else options.canTouch
	object.CanQuery = if options.canQuery == nil then true else options.canQuery
	object.CastShadow = if options.castShadow == nil then true else options.castShadow
	object.Transparency = options.transparency or 0
	object.Color = options.color or COLORS.concrete
	object.Material = options.material or Enum.Material.Concrete
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if options.shape then
		object.Shape = options.shape
	end
	object.Parent = parent
	return object
end

local function weld(part0, part1)
	local constraint = Instance.new("WeldConstraint")
	constraint.Name = part1.Name .. "Weld"
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part0
	return constraint
end

local function makePrompt(parent, name, actionText, objectText, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = distance or 9
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = parent
	return prompt
end

local function makeTextSurface(part, face, text, textColor, backgroundColor, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BunkerSignGui"
	gui.Face = face
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0.15
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 38
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = backgroundColor or COLORS.black
	label.BackgroundTransparency = if backgroundColor then 0.12 else 1
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = textColor or COLORS.warm
	label.TextScaled = true
	label.TextSize = textSize or 22
	label.TextWrapped = false
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.055, 0)
	padding.PaddingRight = UDim.new(0.055, 0)
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = label

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = 9
	sizeConstraint.MaxTextSize = textSize or 22
	sizeConstraint.Parent = label
	return label
end

local function copyTags(source, destination)
	for _, tag in ipairs(CollectionService:GetTags(source)) do
		CollectionService:AddTag(destination, tag)
	end
end

local function restoreRectangularGround(source)
	if source:IsA("Part") then
		return source
	end
	assert(
		source:IsA("PartOperation") and source:GetAttribute("BunkerShaftCutVersion") ~= nil,
		source:GetFullName() .. " is not a supported bunker ground sheet"
	)

	local restored = Instance.new("Part")
	restored.Name = source.Name
	restored.Size = source.Size
	restored.CFrame = source.CFrame
	restored.Anchored = source.Anchored
	restored.CanCollide = source.CanCollide
	restored.CanTouch = source.CanTouch
	restored.CanQuery = source.CanQuery
	restored.CastShadow = source.CastShadow
	restored.Transparency = source.Transparency
	restored.Material = source.Material
	restored.Color = source.Color
	restored.CollisionGroup = source.CollisionGroup
	restored.TopSurface = Enum.SurfaceType.Smooth
	restored.BottomSurface = Enum.SurfaceType.Smooth
	for name, value in pairs(source:GetAttributes()) do
		restored:SetAttribute(name, value)
	end
	copyTags(source, restored)
	for _, child in ipairs(source:GetChildren()) do
		child.Parent = restored
	end
	restored.Parent = source.Parent
	source:Destroy()
	return restored
end

local function cutGroundOpening(source, cutterCFrame, cutterSize)
	local panelsName = source.Name .. "BunkerCutPanels"
	local existingPanels = source.Parent:FindFirstChild(panelsName)
	if source:GetAttribute("BunkerShaftCutVersion") == INSTALL_VERSION
		and source:GetAttribute("BunkerShaftCutRevision") == SHAFT_CUT_REVISION
		and source:GetAttribute("BunkerShaftCutMode") == "FourPanelFrame"
		and existingPanels
		and existingPanels:IsA("Model")
	then
		source:SetAttribute("BunkerShaftCenter", cutterCFrame)
		source:SetAttribute("BunkerShaftSize", cutterSize)
		return source
	end

	if existingPanels then
		existingPanels:Destroy()
	end
	source = restoreRectangularGround(source)

	if source:GetAttribute("BunkerOriginalTransparency") == nil then
		source:SetAttribute("BunkerOriginalTransparency", source.Transparency)
		source:SetAttribute("BunkerOriginalCanCollide", source.CanCollide)
		source:SetAttribute("BunkerOriginalCanTouch", source.CanTouch)
		source:SetAttribute("BunkerOriginalCanQuery", source.CanQuery)
		source:SetAttribute("BunkerOriginalCastShadow", source.CastShadow)
	end
	source.Transparency = source:GetAttribute("BunkerOriginalTransparency")
	source.CanCollide = source:GetAttribute("BunkerOriginalCanCollide")
	source.CanTouch = source:GetAttribute("BunkerOriginalCanTouch")
	source.CanQuery = source:GetAttribute("BunkerOriginalCanQuery")
	source.CastShadow = source:GetAttribute("BunkerOriginalCastShadow")

	local localCenter = source.CFrame:PointToObjectSpace(cutterCFrame.Position)
	local halfX = source.Size.X * 0.5
	local halfZ = source.Size.Z * 0.5
	local cutHalfX = cutterSize.X * 0.5
	local cutHalfZ = cutterSize.Z * 0.5
	local cutMinX = localCenter.X - cutHalfX
	local cutMaxX = localCenter.X + cutHalfX
	local cutMinZ = localCenter.Z - cutHalfZ
	local cutMaxZ = localCenter.Z + cutHalfZ
	assert(
		cutMinX > -halfX and cutMaxX < halfX
			and cutMinZ > -halfZ and cutMaxZ < halfZ,
		source:GetFullName() .. " does not fully contain the bunker opening"
	)

	local panels = Instance.new("Model")
	panels.Name = panelsName
	panels:SetAttribute("BunkerShaftCutVersion", INSTALL_VERSION)
	panels:SetAttribute("BunkerShaftCutRevision", SHAFT_CUT_REVISION)
	panels.Parent = source.Parent

	local definitions = {
		{
			name = "West",
			minX = -halfX,
			maxX = cutMinX,
			minZ = -halfZ,
			maxZ = halfZ,
		},
		{
			name = "East",
			minX = cutMaxX,
			maxX = halfX,
			minZ = -halfZ,
			maxZ = halfZ,
		},
		{
			name = "Front",
			minX = cutMinX,
			maxX = cutMaxX,
			minZ = -halfZ,
			maxZ = cutMinZ,
		},
		{
			name = "Rear",
			minX = cutMinX,
			maxX = cutMaxX,
			minZ = cutMaxZ,
			maxZ = halfZ,
		},
	}
	for _, definition in ipairs(definitions) do
		local width = definition.maxX - definition.minX
		local depth = definition.maxZ - definition.minZ
		assert(width > 0.05 and depth > 0.05, source:GetFullName() .. " produced a degenerate ground panel")
		local panel = Instance.new("Part")
		panel.Name = definition.name
		panel.Size = Vector3.new(width, source.Size.Y, depth)
		panel.CFrame = source.CFrame * CFrame.new(
			(definition.minX + definition.maxX) * 0.5,
			0,
			(definition.minZ + definition.maxZ) * 0.5
		)
		panel.Anchored = source.Anchored
		panel.CanCollide = source.CanCollide
		panel.CanTouch = source.CanTouch
		panel.CanQuery = source.CanQuery
		panel.CastShadow = source.CastShadow
		panel.Transparency = source.Transparency
		panel.Material = source.Material
		panel.Color = source.Color
		panel.CollisionGroup = source.CollisionGroup
		panel.TopSurface = Enum.SurfaceType.Smooth
		panel.BottomSurface = Enum.SurfaceType.Smooth
		panel:SetAttribute("BunkerGroundPanel", true)
		panel:SetAttribute("GroundSourceName", source.Name)
		panel:SetAttribute("TrikeGroundSurface", true)
		copyTags(source, panel)
		panel.Parent = panels
	end

	-- Retain the full-size named part only as an invisible spatial locator so
	-- every existing lot-relative script keeps the same reference and bounds.
	source.Transparency = 1
	source.CanCollide = false
	source.CanTouch = false
	source.CanQuery = false
	source.CastShadow = false
	source:SetAttribute("BunkerGroundLocator", true)
	source:SetAttribute("BunkerShaftCutMode", "FourPanelFrame")
	source:SetAttribute("BunkerShaftCutVersion", INSTALL_VERSION)
	source:SetAttribute("BunkerShaftCutRevision", SHAFT_CUT_REVISION)
	source:SetAttribute("BunkerShaftCenter", cutterCFrame)
	source:SetAttribute("BunkerShaftSize", cutterSize)
	return source
end

local function makeCagedLight(parent, name, cframe, color, mainLight)
	local fixture = makePart(
		parent,
		name,
		Vector3.new(3.6, 0.24, 1.1),
		cframe,
		{
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			canCollide = false,
		}
	)
	local lens = makePart(
		parent,
		name .. "Lens",
		Vector3.new(3.1, 0.16, 0.72),
		cframe * CFrame.new(0, -0.18, 0),
		{
			color = color,
			material = Enum.Material.Neon,
			canCollide = false,
		}
	)
	lens:SetAttribute("BunkerMainLight", mainLight)
	local light = Instance.new("SurfaceLight")
	light.Name = "WorkLight"
	light.Face = Enum.NormalId.Bottom
	light.Brightness = mainLight and 2.4 or 1.2
	light.Range = mainLight and 20 or 11
	light.Angle = 120
	light.Color = color
	light.Shadows = mainLight
	light.Enabled = true
	light:SetAttribute("BunkerMainLight", mainLight)
	light.Parent = lens

	for offset = -1.25, 1.25, 0.5 do
		makePart(
			parent,
			name .. "Cage" .. tostring(math.floor((offset + 1.25) * 10)),
			Vector3.new(0.07, 0.42, 0.95),
			cframe * CFrame.new(offset, -0.16, 0),
			{
				color = COLORS.steel,
				material = Enum.Material.Metal,
				canCollide = false,
			}
		)
	end
	return fixture, lens
end

local function makeCrate(parent, name, cframe, color)
	local body = makePart(
		parent,
		name,
		Vector3.new(3.2, 2.2, 2.6),
		cframe,
		{
			color = color or COLORS.olive,
			material = Enum.Material.WoodPlanks,
		}
	)
	for _, offset in ipairs({ -1.48, 1.48 }) do
		makePart(
			parent,
			name .. "Band" .. tostring(offset),
			Vector3.new(0.16, 2.28, 2.68),
			cframe * CFrame.new(offset, 0, 0),
			{
				color = COLORS.steel,
				material = Enum.Material.Metal,
				canCollide = false,
			}
		)
	end
	return body
end

local function makePipe(parent, name, cframe, length, diameter, color)
	return makePart(
		parent,
		name,
		Vector3.new(length, diameter, diameter),
		cframe,
		{
			color = color or COLORS.steel,
			material = Enum.Material.Metal,
			canCollide = false,
			shape = Enum.PartType.Cylinder,
		}
	)
end

local existing = environment:FindFirstChild(BUNKER_NAME)
if existing then
	existing:Destroy()
end

-- Cut the same small aperture through every ground sheet that crosses the
-- shaft.  GeometryService works on clones first, so a failed operation leaves
-- the original world untouched.
local groundCutterCFrame = CFrame.new(shaftCenter.X, groundY, shaftCenter.Z)
local groundCutterSize = Vector3.new(6.55, 8.0, 6.15)
lot = cutGroundOpening(lot, groundCutterCFrame, groundCutterSize)
neighborhoodGround = cutGroundOpening(neighborhoodGround, groundCutterCFrame, groundCutterSize)

local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	local baseBottom = baseplate.Position.Y - baseplate.Size.Y * 0.5
	local baseTop = baseplate.Position.Y + baseplate.Size.Y * 0.5
	if baseTop > floorTopY and baseBottom < groundY then
		baseplate = cutGroundOpening(
			baseplate,
			CFrame.new(shaftCenter.X, baseplate.Position.Y, shaftCenter.Z),
			Vector3.new(6.55, baseplate.Size.Y + 2, 6.15)
		)
	end
end

local remotes = ReplicatedStorage:FindFirstChild(REMOTES_NAME)
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = REMOTES_NAME
	remotes.Parent = ReplicatedStorage
end
local event = remotes:FindFirstChild(EVENT_NAME)
if event and not event:IsA("RemoteEvent") then
	event:Destroy()
	event = nil
end
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = EVENT_NAME
	event.Parent = remotes
end

local bunker = Instance.new("Model")
bunker.Name = BUNKER_NAME
bunker:SetAttribute("InstallVersion", INSTALL_VERSION)
bunker:SetAttribute("Purpose", "Backyard storm-cellar entrance and underground chemistry research bunker")
bunker:SetAttribute("SurfaceOrigin", surfaceOrigin)
bunker:SetAttribute("UndergroundOrigin", undergroundOrigin)
bunker:SetAttribute("RoomSize", roomSize)
bunker:SetAttribute("PhysicalAccess", true)
bunker:SetAttribute("UsesTeleport", false)
bunker:SetAttribute("ShaftCenter", CFrame.new(shaftCenter))
bunker:SetAttribute("ChemistryGameplayEnabled", true)
bunker:SetAttribute("HatchOpen", false)
bunker:SetAttribute("BlastDoorOpen", false)
bunker:SetAttribute("MainLightsOn", true)
bunker.Parent = environment
pcall(function()
	bunker.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end)

-- SURFACE ENTRANCE ---------------------------------------------------------
local surface = Instance.new("Model")
surface.Name = "SurfaceEntrance"
surface.Parent = bunker

local slab = Instance.new("Model")
slab.Name = "FoundationSlab"
slab.Parent = surface
for _, definition in ipairs({
	{
		name = "FoundationWest",
		size = Vector3.new(1.8, 0.55, 9),
		offset = Vector3.new(-4.1, 0.275, 0),
	},
	{
		name = "FoundationEast",
		size = Vector3.new(1.8, 0.55, 9),
		offset = Vector3.new(4.1, 0.275, 0),
	},
	{
		name = "FoundationFront",
		size = Vector3.new(6.4, 0.55, 1.35),
		offset = Vector3.new(0, 0.275, -3.825),
	},
	{
		name = "FoundationRear",
		size = Vector3.new(6.4, 0.55, 1.65),
		offset = Vector3.new(0, 0.275, 3.675),
	},
}) do
	local piece = makePart(
		slab,
		definition.name,
		definition.size,
		CFrame.new(surfacePosition + definition.offset),
		{
			color = Color3.fromRGB(121, 119, 105),
			material = Enum.Material.Concrete,
		}
	)
	piece:SetAttribute("BunkerSurface", true)
end

local shaftOpening = makePart(
	surface,
	"ShaftOpening",
	Vector3.new(6.4, 0.10, 6.0),
	CFrame.new(shaftCenter.X, groundY + 0.04, shaftCenter.Z),
	{
		canCollide = false,
		canTouch = false,
		canQuery = false,
		transparency = 1,
		castShadow = false,
	}
)
shaftOpening:SetAttribute("PhysicalOpening", true)

local collar = Instance.new("Model")
collar.Name = "ConcreteCollar"
collar.Parent = surface
makePart(collar, "LeftWall", Vector3.new(1.0, 1.15, 7.2), CFrame.new(surfacePosition + Vector3.new(-3.9, 1.13, -0.15)), {
	color = Color3.fromRGB(105, 106, 97),
	material = Enum.Material.Concrete,
})
makePart(collar, "RightWall", Vector3.new(1.0, 1.15, 7.2), CFrame.new(surfacePosition + Vector3.new(3.9, 1.13, -0.15)), {
	color = Color3.fromRGB(105, 106, 97),
	material = Enum.Material.Concrete,
})
makePart(collar, "RearWall", Vector3.new(8.8, 1.15, 0.8), CFrame.new(surfacePosition + Vector3.new(0, 1.13, 3.45)), {
	color = Color3.fromRGB(105, 106, 97),
	material = Enum.Material.Concrete,
})
makePart(collar, "FrontLip", Vector3.new(8.8, 0.5, 0.8), CFrame.new(surfacePosition + Vector3.new(0, 0.81, -3.75)), {
	color = Color3.fromRGB(105, 106, 97),
	material = Enum.Material.Concrete,
})

local hatchDoor = Instance.new("Model")
hatchDoor.Name = "HatchDoor"
hatchDoor:SetAttribute("IsOpen", false)
hatchDoor.Parent = surface

local closedHatchPivot = CFrame.new(surfacePosition.X, groundY + 1.20, surfacePosition.Z + 3.05)
local openHatchPivot = closedHatchPivot * CFrame.Angles(math.rad(105), 0, 0)
hatchDoor:SetAttribute("ClosedPivot", closedHatchPivot)
hatchDoor:SetAttribute("OpenPivot", openHatchPivot)

local hingeRoot = makePart(
	hatchDoor,
	"HingeRoot",
	Vector3.new(0.20, 0.20, 0.20),
	closedHatchPivot,
	{
		color = COLORS.black,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
		transparency = 1,
		castShadow = false,
	}
)
hatchDoor.PrimaryPart = hingeRoot
local hatchPanel = makePart(
	hatchDoor,
	"Panel",
	Vector3.new(7.2, 0.40, 6.4),
	CFrame.new(surfacePosition.X, groundY + 1.20, surfacePosition.Z - 0.15),
	{
		color = COLORS.olive,
		material = Enum.Material.DiamondPlate,
	}
)
for _, xOffset in ipairs({ -2.9, 0, 2.9 }) do
	makePart(
		hatchDoor,
		"Reinforcement" .. tostring(xOffset),
		Vector3.new(0.28, 0.18, 6.1),
		CFrame.new(surfacePosition.X + xOffset, groundY + 1.48, surfacePosition.Z - 0.15),
		{
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			canCollide = false,
		}
	)
end
makePart(
	hatchDoor,
	"CrossBrace",
	Vector3.new(6.9, 0.18, 0.30),
	CFrame.new(surfacePosition.X, groundY + 1.49, surfacePosition.Z - 0.15),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
		canCollide = false,
	}
)
makePart(
	hatchDoor,
	"PullHandle",
	Vector3.new(1.8, 0.22, 0.28),
	CFrame.new(surfacePosition.X, groundY + 1.72, surfacePosition.Z - 2.25),
	{
		color = COLORS.steelLight,
		material = Enum.Material.Metal,
		canCollide = false,
	}
)
hatchDoor:PivotTo(closedHatchPivot)

local hatchControl = makePart(
	surface,
	"HatchControl",
	Vector3.new(2.8, 2.6, 1.2),
	CFrame.new(surfacePosition + Vector3.new(6.8, 1.60, -1.7)),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
makeTextSurface(hatchControl, Enum.NormalId.Front, "HATCH\nCONTROL", COLORS.amber, COLORS.black, 18)
makePrompt(hatchControl, "HatchPrompt", "Open bunker", "Backyard shelter hatch", 10)

makePart(
	surface,
	"ControlPad",
	Vector3.new(3.6, 0.30, 2.4),
	CFrame.new(surfacePosition + Vector3.new(6.8, 0.15, -1.7)),
	{
		color = Color3.fromRGB(105, 106, 97),
		material = Enum.Material.Concrete,
	}
)

local warningBeacon = makePart(
	surface,
	"WarningBeacon",
	Vector3.new(0.72, 0.8, 0.72),
	CFrame.new(surfacePosition + Vector3.new(6.8, 3.35, -1.7))
		* CFrame.Angles(0, 0, math.rad(90)),
	{
		color = COLORS.red,
		material = Enum.Material.Neon,
		canCollide = false,
		shape = Enum.PartType.Cylinder,
	}
)
local beaconLight = Instance.new("PointLight")
beaconLight.Name = "BeaconLight"
beaconLight.Color = COLORS.red
beaconLight.Brightness = 1.8
beaconLight.Range = 12
beaconLight.Enabled = false
beaconLight.Parent = warningBeacon

-- The surface and bunker are one continuous physical space.  A climbable
-- TrussPart spans the complete drop; concrete walls surround it, and the lower
-- rear face remains open so the player steps directly into the airlock.
local physicalAccess = Instance.new("Model")
physicalAccess.Name = "PhysicalAccess"
physicalAccess.Parent = surface

local shaftTopY = groundY + 0.02
local shaftBottomY = floorTopY + 0.12
local shaftHeight = shaftTopY - shaftBottomY
local shaftWallY = (shaftTopY + shaftBottomY) * 0.5
local ceilingBottomY = undergroundCenter.Y + roomSize.Y * 0.5 - 0.5
local upperRearHeight = shaftTopY - ceilingBottomY

makePart(
	physicalAccess,
	"ShaftLeftWall",
	Vector3.new(0.5, upperRearHeight, 6.5),
	CFrame.new(
		shaftCenter.X - 3.45,
		(shaftTopY + ceilingBottomY) * 0.5,
		shaftCenter.Z
	),
	{ color = COLORS.concreteDark, material = Enum.Material.Concrete }
)
makePart(
	physicalAccess,
	"ShaftRightWall",
	Vector3.new(0.5, upperRearHeight, 6.5),
	CFrame.new(
		shaftCenter.X + 3.45,
		(shaftTopY + ceilingBottomY) * 0.5,
		shaftCenter.Z
	),
	{ color = COLORS.concreteDark, material = Enum.Material.Concrete }
)
makePart(
	physicalAccess,
	"ShaftFrontWall",
	Vector3.new(7.4, upperRearHeight, 0.5),
	CFrame.new(
		shaftCenter.X,
		(shaftTopY + ceilingBottomY) * 0.5,
		shaftCenter.Z - 3.25
	),
	{ color = COLORS.concreteDark, material = Enum.Material.Concrete }
)
makePart(
	physicalAccess,
	"ShaftUpperRearWall",
	Vector3.new(7.4, upperRearHeight, 0.5),
	CFrame.new(
		shaftCenter.X,
		(shaftTopY + ceilingBottomY) * 0.5,
		shaftCenter.Z + 3.25
	),
	{ color = COLORS.concreteDark, material = Enum.Material.Concrete }
)

local shaftLadder = makePart(
	physicalAccess,
	"ShaftLadder",
	Vector3.new(2.0, shaftHeight - 0.7, 2.0),
	CFrame.new(shaftCenter.X, shaftWallY, shaftCenter.Z + 1.85),
	{
		className = "TrussPart",
		color = COLORS.steelLight,
		material = Enum.Material.Metal,
	}
)
shaftLadder:SetAttribute("ContinuousPhysicalAccess", true)

local bottomLanding = makePart(
	physicalAccess,
	"BottomLanding",
	Vector3.new(5.8, 0.24, 2.4),
	CFrame.new(shaftCenter.X, floorTopY + 0.12, shaftCenter.Z + 1.75),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.DiamondPlate,
	}
)
makePart(
	physicalAccess,
	"LandingStripe",
	Vector3.new(5.5, 0.05, 0.34),
	bottomLanding.CFrame * CFrame.new(0, 0.15, 1.02),
	{
		color = COLORS.yellow,
		material = Enum.Material.Neon,
		canCollide = false,
	}
)
for _, definition in ipairs({
	{ name = "LadderGuardLeft", x = -1.35 },
	{ name = "LadderGuardRight", x = 1.35 },
}) do
	makePart(
		physicalAccess,
		definition.name,
		Vector3.new(0.18, 2.6, 0.18),
		CFrame.new(
			shaftCenter.X + definition.x,
			groundY + 1.65,
			shaftCenter.Z + 2.70
		),
		{
			color = COLORS.steelLight,
			material = Enum.Material.Metal,
			canCollide = false,
		}
	)
end

for _, definition in ipairs({
	{ name = "ShaftLightUpper", y = groundY - 6.0 },
	{ name = "ShaftLightLower", y = (groundY + floorTopY) * 0.5 - 2.5 },
}) do
	local fixture = makePart(
		physicalAccess,
		definition.name,
		Vector3.new(2.5, 0.35, 0.14),
		CFrame.new(shaftCenter.X, definition.y, shaftCenter.Z - 2.96),
		{
			color = COLORS.warm,
			material = Enum.Material.Neon,
			canCollide = false,
		}
	)
	local light = Instance.new("PointLight")
	light.Color = COLORS.warm
	light.Brightness = 1.0
	light.Range = 13
	light.Shadows = true
	light.Parent = fixture
end

local surfaceSign = makePart(
	surface,
	"CooperShelterPlaque",
	Vector3.new(5.8, 1.65, 0.22),
	CFrame.new(surfacePosition + Vector3.new(-8.2, 2.15, 0.8)),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
		canCollide = false,
	}
)
makeTextSurface(surfaceSign, Enum.NormalId.Front, "COOPER SHELTER\nMEDFORD, TEXAS", COLORS.warm, COLORS.black, 18)
for index, xOffset in ipairs({ -2.15, 2.15 }) do
	makePart(
		surface,
		"PlaquePost" .. tostring(index),
		Vector3.new(0.16, 1.75, 0.16),
		CFrame.new(surfacePosition + Vector3.new(-8.2 + xOffset, 0.95, 0.8)),
		{
			color = COLORS.steelLight,
			material = Enum.Material.Metal,
			canCollide = false,
		}
	)
end

for index, xOffset in ipairs({ -4.4, -3.2, 3.2, 4.4 }) do
	makePart(
		surface,
		"HazardStripe" .. tostring(index),
		Vector3.new(0.55, 0.08, 8.6),
		CFrame.new(surfacePosition + Vector3.new(xOffset, 0.60, 0)),
		{
			color = if index % 2 == 0 then COLORS.yellow else COLORS.black,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
		}
	)
end

-- UNDERGROUND SHELTER ------------------------------------------------------
local underground = Instance.new("Model")
underground.Name = "Underground"
underground.Parent = bunker

local shell = Instance.new("Model")
shell.Name = "Shell"
shell.Parent = underground

local halfX = roomSize.X * 0.5
local halfY = roomSize.Y * 0.5
local halfZ = roomSize.Z * 0.5
local floor = makePart(
	shell,
	"FoundationFloor",
	Vector3.new(roomSize.X, 1.0, roomSize.Z),
	CFrame.new(undergroundCenter + Vector3.new(0, -halfY, 0)),
	{
		color = COLORS.concreteDark,
		material = Enum.Material.Concrete,
	}
)
floor:SetAttribute("BunkerFloor", true)
local ceilingSegments = Instance.new("Model")
ceilingSegments.Name = "CeilingSegments"
ceilingSegments.Parent = shell
for _, definition in ipairs({
	{
		name = "CeilingWest",
		size = Vector3.new(20.8, 1.0, roomSize.Z),
		offset = Vector3.new(-6.6, halfY, 0),
	},
	{
		name = "CeilingEast",
		size = Vector3.new(6.8, 1.0, roomSize.Z),
		offset = Vector3.new(13.6, halfY, 0),
	},
	{
		name = "CeilingFront",
		size = Vector3.new(6.4, 1.0, 2.0),
		offset = Vector3.new(7.0, halfY, -13.0),
	},
	{
		name = "CeilingRear",
		size = Vector3.new(6.4, 1.0, 20.0),
		offset = Vector3.new(7.0, halfY, 4.0),
	},
}) do
	makePart(
		ceilingSegments,
		definition.name,
		definition.size,
		CFrame.new(undergroundCenter + definition.offset),
		{
			color = COLORS.concreteDark,
			material = Enum.Material.Concrete,
		}
	)
end
makePart(
	shell,
	"WestWall",
	Vector3.new(1.0, roomSize.Y, roomSize.Z),
	CFrame.new(undergroundCenter + Vector3.new(-halfX, 0, 0)),
	{
		color = COLORS.concrete,
		material = Enum.Material.Concrete,
	}
)
makePart(
	shell,
	"EastWall",
	Vector3.new(1.0, roomSize.Y, roomSize.Z),
	CFrame.new(undergroundCenter + Vector3.new(halfX, 0, 0)),
	{
		color = COLORS.concrete,
		material = Enum.Material.Concrete,
	}
)
makePart(
	shell,
	"FrontWall",
	Vector3.new(roomSize.X, roomSize.Y, 1.0),
	CFrame.new(undergroundCenter + Vector3.new(0, 0, -halfZ)),
	{
		color = COLORS.concrete,
		material = Enum.Material.Concrete,
	}
)
makePart(
	shell,
	"RearWall",
	Vector3.new(roomSize.X, roomSize.Y, 1.0),
	CFrame.new(undergroundCenter + Vector3.new(0, 0, halfZ)),
	{
		color = COLORS.concrete,
		material = Enum.Material.Concrete,
	}
)

-- Steel ribs, floor grid, and drains make the room read as a purpose-built
-- Cold War shelter instead of an empty concrete box.
for x = -14, 14, 7 do
	if math.abs((undergroundCenter.X + x) - shaftCenter.X) > 3.5 then
		makePart(
			shell,
			"CeilingRib" .. tostring(x),
			Vector3.new(0.34, 0.50, roomSize.Z - 1.2),
			CFrame.new(undergroundCenter + Vector3.new(x, halfY - 0.76, 0)),
			{
				color = COLORS.gunmetal,
				material = Enum.Material.Metal,
				canCollide = false,
			}
		)
	end
end
for z = -10.5, 10.5, 3.5 do
	makePart(
		shell,
		"FloorSeam" .. tostring(z),
		Vector3.new(roomSize.X - 1.2, 0.035, 0.10),
		CFrame.new(undergroundCenter.X, floorTopY + 0.02, undergroundCenter.Z + z),
		{
			color = COLORS.black,
			material = Enum.Material.Metal,
			canCollide = false,
		}
	)
end
for x = -14, 14, 4 do
	makePart(
		shell,
		"FloorSeamX" .. tostring(x),
		Vector3.new(0.10, 0.035, roomSize.Z - 1.2),
		CFrame.new(undergroundCenter.X + x, floorTopY + 0.02, undergroundCenter.Z),
		{
			color = COLORS.black,
			material = Enum.Material.Metal,
			canCollide = false,
		}
	)
end
local drain = makePart(
	shell,
	"CenterDrain",
	Vector3.new(4.5, 0.08, 1.2),
	CFrame.new(undergroundCenter.X + 2, floorTopY + 0.06, undergroundCenter.Z + 5),
	{
		color = Color3.fromRGB(31, 35, 36),
		material = Enum.Material.DiamondPlate,
		canCollide = false,
	}
)
for groove = -1.8, 1.8, 0.45 do
	makePart(
		shell,
		"DrainGroove" .. tostring(groove),
		Vector3.new(0.10, 0.04, 0.94),
		drain.CFrame * CFrame.new(groove, -0.055, 0),
		{
			color = COLORS.black,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
		}
	)
end

local entryAirlock = Instance.new("Model")
entryAirlock.Name = "EntryAirlock"
entryAirlock.Parent = underground
local airlockCenterX = surfacePosition.X
local airlockWallZ = undergroundCenter.Z - 4.2
makePart(
	entryAirlock,
	"LeftPartition",
	Vector3.new(19.5, 9.5, 0.65),
	CFrame.new(undergroundCenter + Vector3.new(-7.25, 0, -4.2)),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
makePart(
	entryAirlock,
	"RightPartition",
	Vector3.new(5.5, 9.5, 0.65),
	CFrame.new(undergroundCenter + Vector3.new(14.25, 0, -4.2)),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
makePart(
	entryAirlock,
	"DoorHeader",
	Vector3.new(8.0, 1.5, 0.65),
	CFrame.new(airlockCenterX, undergroundCenter.Y + 5.0, airlockWallZ),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
local airlockStripe = makePart(
	entryAirlock,
	"AirlockWarning",
	Vector3.new(7.2, 1.0, 0.12),
	CFrame.new(airlockCenterX, undergroundCenter.Y + 4.0, undergroundCenter.Z - 4.56),
	{
		color = COLORS.yellow,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	}
)
makeTextSurface(airlockStripe, Enum.NormalId.Front, "AIRLOCK 01", COLORS.black, COLORS.yellow, 23)

local blastDoor = Instance.new("Model")
blastDoor.Name = "BlastDoor"
blastDoor:SetAttribute("IsOpen", false)
blastDoor.Parent = underground
local doorZ = undergroundCenter.Z - 4.56
local doorY = floorTopY + 4.0
local leftClosed = CFrame.new(airlockCenterX - 2, doorY, doorZ)
local rightClosed = CFrame.new(airlockCenterX + 2, doorY, doorZ)
local leftOpen = CFrame.new(airlockCenterX - 6.05, doorY, doorZ)
local rightOpen = CFrame.new(airlockCenterX + 6.05, doorY, doorZ)
local leftPanel = makePart(
	blastDoor,
	"LeftPanel",
	Vector3.new(4.05, 8.0, 0.55),
	leftClosed,
	{
		color = COLORS.olive,
		material = Enum.Material.DiamondPlate,
	}
)
leftPanel:SetAttribute("ClosedCFrame", leftClosed)
leftPanel:SetAttribute("OpenCFrame", leftOpen)
local rightPanel = makePart(
	blastDoor,
	"RightPanel",
	Vector3.new(4.05, 8.0, 0.55),
	rightClosed,
	{
		color = COLORS.olive,
		material = Enum.Material.DiamondPlate,
	}
)
rightPanel:SetAttribute("ClosedCFrame", rightClosed)
rightPanel:SetAttribute("OpenCFrame", rightOpen)
makeTextSurface(leftPanel, Enum.NormalId.Front, "◀  CAUTION", COLORS.yellow, COLORS.olive, 24)
makeTextSurface(rightPanel, Enum.NormalId.Front, "CAUTION  ▶", COLORS.yellow, COLORS.olive, 24)

local blastDoorControl = makePart(
	underground,
	"BlastDoorControl",
	Vector3.new(1.8, 2.4, 0.8),
	CFrame.new(airlockCenterX + 5.5, floorTopY + 2.2, doorZ - 0.7),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
makeTextSurface(blastDoorControl, Enum.NormalId.Front, "BLAST\nDOOR", COLORS.amber, COLORS.black, 16)
makePrompt(blastDoorControl, "BlastDoorPrompt", "Open blast door", "Airlock control", 10)

local recoveryAnchor = makePart(
	underground,
	"RecoveryAnchor",
	Vector3.new(2, 1, 2),
	CFrame.lookAt(
		Vector3.new(airlockCenterX - 5.0, floorTopY + 3.0, shaftCenter.Z + 0.5),
		Vector3.new(airlockCenterX, floorTopY + 3.0, doorZ)
	),
	{
		canCollide = false,
		canTouch = false,
		canQuery = false,
		transparency = 1,
		castShadow = false,
	}
)
recoveryAnchor:SetAttribute("EmergencyOnly", true)

local recoveryZone = makePart(
	underground,
	"RecoveryZone",
	Vector3.new(roomSize.X - 2, 1.0, roomSize.Z - 2),
	CFrame.new(undergroundCenter.X, undergroundCenter.Y - halfY - 5, undergroundCenter.Z),
	{
		canCollide = false,
		canTouch = true,
		canQuery = false,
		transparency = 1,
		castShadow = false,
	}
)

-- LIGHTING -----------------------------------------------------------------
local mainLights = Instance.new("Model")
mainLights.Name = "MainLights"
mainLights.Parent = underground
for index, offset in ipairs({
	Vector3.new(-11, 5.25, -9),
	Vector3.new(1, 5.25, -9),
	Vector3.new(13, 5.25, -9),
	Vector3.new(-11, 5.25, 2),
	Vector3.new(1, 5.25, 2),
	Vector3.new(11, 5.25, 2),
	Vector3.new(-11, 5.25, 11),
	Vector3.new(1, 5.25, 11),
	Vector3.new(11, 5.25, 11),
}) do
	makeCagedLight(
		mainLights,
		"MainLight" .. tostring(index),
		CFrame.new(undergroundCenter + offset),
		COLORS.warm,
		true
	)
end

local emergencyLights = Instance.new("Model")
emergencyLights.Name = "EmergencyLights"
emergencyLights.Parent = underground
for index, offset in ipairs({
	Vector3.new(-16.35, 2.5, -10),
	Vector3.new(-16.35, 2.5, 6),
	Vector3.new(16.35, 2.5, -10),
	Vector3.new(16.35, 2.5, 6),
}) do
	local strip = makePart(
		emergencyLights,
		"EmergencyStrip" .. tostring(index),
		Vector3.new(0.16, 3.4, 0.55),
		CFrame.new(undergroundCenter + offset),
		{
			color = COLORS.red,
			material = Enum.Material.Neon,
			canCollide = false,
		}
	)
	local light = Instance.new("PointLight")
	light.Color = COLORS.red
	light.Brightness = 0.7
	light.Range = 9
	light.Enabled = true
	light.Parent = strip
end

local lightControl = makePart(
	underground,
	"LightControl",
	Vector3.new(0.35, 2.8, 1.8),
	CFrame.new(undergroundCenter.X + 16.30, floorTopY + 2.4, undergroundCenter.Z + 2),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
makeTextSurface(lightControl, Enum.NormalId.Left, "MAIN\nLIGHTS", COLORS.cyan, COLORS.black, 17)
makePrompt(lightControl, "LightPrompt", "Turn lights off", "Bunker breaker", 9)

-- UTILITY ROOM -------------------------------------------------------------
local utility = Instance.new("Model")
utility.Name = "UtilityRoom"
utility.Parent = underground
local generatorBase = makePart(
	utility,
	"GeneratorBase",
	Vector3.new(7.8, 3.2, 4.2),
	CFrame.new(
		undergroundCenter.X - 12.2,
		floorTopY + 1.6,
		undergroundCenter.Z - 9.2
	),
	{
		color = COLORS.olive,
		material = Enum.Material.Metal,
	}
)
makePart(
	utility,
	"GeneratorTop",
	Vector3.new(6.8, 1.1, 3.5),
	CFrame.new(
		undergroundCenter.X - 12.2,
		floorTopY + 3.75,
		undergroundCenter.Z - 9.2
	),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.DiamondPlate,
	}
)
for xOffset = -2.6, 2.6, 1.3 do
	local gauge = makePart(
		utility,
		"GeneratorGauge" .. tostring(xOffset),
		Vector3.new(0.8, 0.8, 0.15),
		CFrame.new(
			undergroundCenter.X - 12.2 + xOffset,
			floorTopY + 3.8,
			undergroundCenter.Z - 11.02
		),
		{
			color = COLORS.cyan,
			material = Enum.Material.Neon,
			canCollide = false,
			shape = Enum.PartType.Cylinder,
		}
	)
	gauge.CFrame *= CFrame.Angles(0, 0, math.rad(90))
end
makeTextSurface(generatorBase, Enum.NormalId.Back, "AUXILIARY POWER\n240 V", COLORS.yellow, COLORS.olive, 19)
makePipe(
	utility,
	"CopperPipeA",
	CFrame.new(
		undergroundCenter.X - 15.7,
		undergroundCenter.Y + 3.2,
		undergroundCenter.Z - 4
	) * CFrame.Angles(0, 0, math.rad(90)),
	5.2,
	0.36,
	Color3.fromRGB(164, 94, 59)
)
makePipe(
	utility,
	"SteelPipeA",
	CFrame.new(
		undergroundCenter.X - 14.9,
		undergroundCenter.Y + 4.8,
		undergroundCenter.Z + 1
	),
	13,
	0.42,
	COLORS.steel
)
makePipe(
	utility,
	"SteelPipeB",
	CFrame.new(
		undergroundCenter.X - 14.9,
		undergroundCenter.Y + 3.9,
		undergroundCenter.Z + 2
	),
	13,
	0.28,
	COLORS.gunmetal
)
local breaker = makePart(
	utility,
	"BreakerPanel",
	Vector3.new(0.65, 5.2, 4.2),
	CFrame.new(
		undergroundCenter.X - 16.15,
		floorTopY + 3.2,
		undergroundCenter.Z + 3
	),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
local breakerHeader = makePart(
	utility,
	"BreakerHeader",
	Vector3.new(0.12, 1.0, 4.0),
	CFrame.new(
		undergroundCenter.X - 15.76,
		floorTopY + 5.20,
		undergroundCenter.Z + 3
	),
	{
		color = COLORS.black,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	}
)
makeTextSurface(
	breakerHeader,
	Enum.NormalId.Right,
	"SHELTER POWER\nAUTHORIZED ONLY",
	COLORS.amber,
	COLORS.black,
	15
)
for switch = 0, 5 do
	local row = math.floor(switch / 2)
	local column = switch % 2
	makePart(
		utility,
		"BreakerSwitch" .. tostring(switch),
		Vector3.new(0.18, 0.32, 0.48),
		CFrame.new(
			undergroundCenter.X - 15.76,
			floorTopY + 1.55 + row * 1.05,
			undergroundCenter.Z + 2.0 + column * 2.0
		),
		{
			color = if switch % 3 == 0 then COLORS.red else COLORS.cyan,
			material = Enum.Material.Neon,
			canCollide = false,
		}
	)
end

-- MAIN CHAMBER -------------------------------------------------------------
local mainChamber = Instance.new("Model")
mainChamber.Name = "MainChamber"
mainChamber.Parent = underground
local workbench = makePart(
	mainChamber,
	"SteelWorkbench",
	Vector3.new(10.5, 0.65, 3.8),
	CFrame.new(
		undergroundCenter.X + 5.5,
		floorTopY + 3.0,
		undergroundCenter.Z + 9.8
	),
	{
		color = COLORS.steel,
		material = Enum.Material.DiamondPlate,
	}
)
for _, xOffset in ipairs({ -4.5, 4.5 }) do
	makePart(
		mainChamber,
		"WorkbenchLeg" .. tostring(xOffset),
		Vector3.new(0.65, 3.0, 3.0),
		CFrame.new(
			undergroundCenter.X + 5.5 + xOffset,
			floorTopY + 1.5,
			undergroundCenter.Z + 9.8
		),
		{
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
		}
	)
end
local blueprintBoard = makePart(
	mainChamber,
	"BlueprintBoard",
	Vector3.new(10, 5.2, 0.3),
	CFrame.new(
		undergroundCenter.X + 11.0,
		floorTopY + 6.2,
		undergroundCenter.Z + 13.32
	),
	{
		color = COLORS.cyanDark,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	}
)
makeTextSurface(
	blueprintBoard,
	Enum.NormalId.Front,
	"COOPER SHELTER SYSTEMS\nVENTILATION  •  POWER  •  STORAGE\nCHEMISTRY RESEARCH NETWORK: READY",
	COLORS.paper,
	COLORS.cyanDark,
	18
)
for index, xOffset in ipairs({ 11.1, 13.2, 15.3 }) do
	local locker = makePart(
		mainChamber,
		"Locker" .. tostring(index),
		Vector3.new(1.8, 6.8, 2.2),
		CFrame.new(
			undergroundCenter.X + xOffset,
			floorTopY + 3.4,
			undergroundCenter.Z + 0.3
		),
		{
			color = COLORS.olive,
			material = Enum.Material.Metal,
		}
	)
	makeTextSurface(locker, Enum.NormalId.Front, tostring(index), COLORS.yellow, COLORS.olive, 30)
end
makeCrate(
	mainChamber,
	"SupplyCrateA",
	CFrame.new(
		undergroundCenter.X + 12.5,
		floorTopY + 1.1,
		undergroundCenter.Z + 11
	),
	COLORS.olive
)
makeCrate(
	mainChamber,
	"SupplyCrateB",
	CFrame.new(
		undergroundCenter.X + 15,
		floorTopY + 1.1,
		undergroundCenter.Z + 8.1
	),
	Color3.fromRGB(110, 78, 49)
)
makePart(
	mainChamber,
	"BenchSeat",
	Vector3.new(7.5, 0.6, 2.1),
	CFrame.new(
		undergroundCenter.X + 5.5,
		floorTopY + 1.7,
		undergroundCenter.Z + 2.0
	),
	{
		color = Color3.fromRGB(96, 70, 48),
		material = Enum.Material.WoodPlanks,
	}
)
for _, xOffset in ipairs({ -3.1, 3.1 }) do
	makePart(
		mainChamber,
		"BenchLeg" .. tostring(xOffset),
		Vector3.new(0.45, 1.7, 1.6),
		CFrame.new(
			undergroundCenter.X + 5.5 + xOffset,
			floorTopY + 0.85,
			undergroundCenter.Z + 2.0
		),
		{
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
		}
	)
end

-- The bay is the owner-safe install destination for the first bunker-phase
-- purchase. The runtime controller creates the terminal and animated lab from
-- these live local anchors, keeping whole-property relocation safe.
local chemistryBay = Instance.new("Model")
chemistryBay.Name = "FutureChemistryBay"
chemistryBay:SetAttribute("GameplayEnabled", true)
chemistryBay.Parent = underground
local chemistryPad = makePart(
	chemistryBay,
	"EquipmentPad",
	Vector3.new(10.5, 0.35, 12.5),
	CFrame.new(
		undergroundCenter.X - 10.4,
		floorTopY + 0.18,
		undergroundCenter.Z + 6.2
	),
	{
		color = Color3.fromRGB(67, 76, 71),
		material = Enum.Material.DiamondPlate,
	}
)
for index, offset in ipairs({
	Vector3.new(-5.0, 0.23, -6.0),
	Vector3.new(5.0, 0.23, -6.0),
	Vector3.new(-5.0, 0.23, 6.0),
	Vector3.new(5.0, 0.23, 6.0),
}) do
	makePart(
		chemistryBay,
		"PadCorner" .. tostring(index),
		Vector3.new(0.45, 0.12, 0.45),
		chemistryPad.CFrame * CFrame.new(offset),
		{
			color = COLORS.cyan,
			material = Enum.Material.Neon,
			canCollide = false,
		}
	)
end
local chemistryAnchor = makePart(
	chemistryBay,
	"ChemistrySetAnchor",
	Vector3.new(8, 5, 9),
	CFrame.new(
		undergroundCenter.X - 10.4,
		floorTopY + 2.6,
		undergroundCenter.Z + 6.2
	),
	{
		canCollide = false,
		canTouch = false,
		canQuery = false,
		transparency = 1,
		castShadow = false,
	}
)
chemistryAnchor:SetAttribute("ReservedFor", "Advanced chemistry setup")
chemistryAnchor:SetAttribute("GameplayEnabled", true)
local chemistrySign = makePart(
	chemistryBay,
	"ChemistryBaySign",
	Vector3.new(9.5, 2.0, 0.25),
	CFrame.new(
		undergroundCenter.X - 10.4,
		floorTopY + 7.0,
		undergroundCenter.Z + 12.95
	),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
		canCollide = false,
	}
)
makeTextSurface(
	chemistrySign,
	Enum.NormalId.Front,
	"ADVANCED CHEMISTRY BAY\nRESEARCH EQUIPMENT READY",
	COLORS.cyan,
	COLORS.black,
	19
)

-- Ventilation fan and ductwork.
local ventilation = Instance.new("Model")
ventilation.Name = "Ventilation"
ventilation.Parent = underground
local fanPosition = Vector3.new(
	undergroundCenter.X + 1.5,
	undergroundCenter.Y + 0.4,
	undergroundCenter.Z + 13.15
)
local fanHousing = makePart(
	ventilation,
	"FanHousing",
	Vector3.new(7.0, 7.0, 0.35),
	CFrame.new(fanPosition + Vector3.new(0, 0, 0.18)),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
makePart(
	ventilation,
	"FanShroud",
	Vector3.new(0.26, 6.35, 6.35),
	CFrame.new(fanPosition + Vector3.new(0, 0, -0.08))
		* CFrame.Angles(0, math.rad(90), 0),
	{
		color = COLORS.black,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
		shape = Enum.PartType.Cylinder,
	}
)
local fanBlades = Instance.new("Model")
fanBlades.Name = "FanBlades"
fanBlades.Parent = ventilation
local fanPivot = CFrame.new(fanPosition + Vector3.new(0, 0, -0.36))
fanBlades:SetAttribute("BasePivot", fanPivot)

local fanPivotRoot = makePart(
	fanBlades,
	"FanPivotRoot",
	Vector3.new(0.12, 0.12, 0.12),
	fanPivot,
	{
		color = COLORS.black,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		canTouch = false,
		canQuery = false,
		transparency = 1,
		castShadow = false,
	}
)
fanBlades.PrimaryPart = fanPivotRoot
local fanHub = makePart(
	fanBlades,
	"FanHub",
	Vector3.new(0.55, 0.82, 0.82),
	fanPivot * CFrame.Angles(0, math.rad(90), 0),
	{
		color = COLORS.steelLight,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
		shape = Enum.PartType.Cylinder,
	}
)
for blade = 0, 5 do
	local angle = math.rad(blade * 60)
	makePart(
		fanBlades,
		"Blade" .. tostring(blade),
		Vector3.new(0.62, 2.15, 0.18),
		fanPivot
			* CFrame.Angles(0, 0, angle + math.rad(18))
			* CFrame.new(0, 1.45, 0),
		{
			color = COLORS.steel,
			material = Enum.Material.Metal,
			canCollide = false,
			canQuery = false,
		}
	)
end

-- A real open guard: short tangent segments and grille bars, never giant
-- translucent cylinder discs projecting into the room.
local guardZ = fanPosition.Z - 0.62
for index = 0, 15 do
	local angle = index * math.pi * 2 / 16
	local radius = 3.22
	makePart(
		ventilation,
		"FanGuardRing" .. tostring(index + 1),
		Vector3.new(1.28, 0.12, 0.12),
		CFrame.new(
			fanPosition.X + math.cos(angle) * radius,
			fanPosition.Y + math.sin(angle) * radius,
			guardZ
		) * CFrame.Angles(0, 0, angle + math.pi * 0.5),
		{
			color = COLORS.steel,
			material = Enum.Material.Metal,
			canCollide = false,
			canQuery = false,
		}
	)
end
makePart(
	ventilation,
	"FanGuardHorizontal",
	Vector3.new(6.15, 0.11, 0.11),
	CFrame.new(fanPosition.X, fanPosition.Y, guardZ),
	{
		color = COLORS.steel,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
	}
)
makePart(
	ventilation,
	"FanGuardVertical",
	Vector3.new(0.11, 6.15, 0.11),
	CFrame.new(fanPosition.X, fanPosition.Y, guardZ),
	{
		color = COLORS.steel,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
	}
)
for index, angle in ipairs({ math.rad(45), math.rad(-45) }) do
	makePart(
		ventilation,
		"FanGuardDiagonal" .. tostring(index),
		Vector3.new(6.0, 0.10, 0.10),
		CFrame.new(fanPosition.X, fanPosition.Y, guardZ)
			* CFrame.Angles(0, 0, angle),
		{
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			canCollide = false,
			canQuery = false,
		}
	)
end
makePipe(
	ventilation,
	"CeilingDuctA",
	CFrame.new(
		undergroundCenter.X + 1.5,
		undergroundCenter.Y + 4.7,
		undergroundCenter.Z
	),
	24,
	1.15,
	COLORS.gunmetal
)
makePipe(
	ventilation,
	"CeilingDuctB",
	CFrame.new(
		undergroundCenter.X + 8,
		undergroundCenter.Y + 4.7,
		undergroundCenter.Z + 5
	),
	13,
	0.85,
	COLORS.gunmetal
)

-- A readable status console ties the bunker interactions together.
local statusConsole = makePart(
	underground,
	"StatusConsole",
	Vector3.new(0.35, 4.0, 5.8),
	CFrame.new(
		undergroundCenter.X + 16.30,
		floorTopY + 4.0,
		undergroundCenter.Z + 6.5
	),
	{
		color = COLORS.gunmetal,
		material = Enum.Material.Metal,
	}
)
local statusText = makeTextSurface(
	statusConsole,
	Enum.NormalId.Left,
	"SHELTER STATUS\nHATCH: SEALED\nBLAST DOOR: SEALED\nMAIN POWER: ONLINE",
	COLORS.cyan,
	COLORS.black,
	16
)
statusText.Name = "StatusText"

local success, failure = pcall(function()
	-- Make every authored bunker part explicit about anchored state.  Runtime
	-- animation uses CFrame/PivotTo, never physics ownership.
	for _, descendant in ipairs(bunker:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end)

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(
			recording,
			success and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
		)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("Install Cooper backyard bunker")
	end)
end

if not success then
	error(failure, 0)
end

print(string.format(
	"[CooperBunker] Installed v%s at surface %s; underground center %s",
	INSTALL_VERSION,
	tostring(surfacePosition),
	tostring(undergroundCenter)
))
