--!nonstrict
-- Transactional edit-mode installer for the seven physical Cooper campaign tasks.
-- Run in Studio edit mode, inject CooperTaskWorld.server.luau into the disabled
-- ServerScriptService.CooperTaskWorld source target, verify, then enable it.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "cooper_task_world_install.luau may only run in Studio edit mode")

local INSTALL_VERSION = "2026-07-11.1"
local ROOT_NAME = "CooperTaskWorld"
local STAGING_ROOT_NAME = ROOT_NAME .. "_Installing"
local PREVIOUS_ROOT_NAME = ROOT_NAME .. "_PreviousInstall"
local SCRIPT_NAME = "CooperTaskWorld"
local STAGING_SCRIPT_NAME = SCRIPT_NAME .. "_Installing"
local PREVIOUS_SCRIPT_NAME = SCRIPT_NAME .. "_PreviousInstall"

local EVENT_KEYS = {
	"GeorgeDrinkDelivered",
	"TVRemoteReturned",
	"FootballChannelSet",
	"MachineCrateDelivered",
	"GarageObstructionCleared",
	"PorchDeliveryRetrieved",
	"StormItemSecured",
}

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment was not found")
local house = environment:FindFirstChild("CooperHouse")
assert(house and house:IsA("Model"), "CooperHouseEnvironment.CooperHouse was not found")
local structure = house:FindFirstChild("Structure")
local exterior = house:FindFirstChild("ExteriorDetails")
local furniture = house:FindFirstChild("FurnitureAndProps")
assert(structure and structure:IsA("Model"), "CooperHouse.Structure was not found")
assert(exterior and exterior:IsA("Model"), "CooperHouse.ExteriorDetails was not found")
assert(furniture and furniture:IsA("Model"), "CooperHouse.FurnitureAndProps was not found")
local garage = environment:FindFirstChild("DetachedGarage")
assert(garage and garage:IsA("Model"), "DetachedGarage was not found")
local site = environment:FindFirstChild("SiteAndStreet")
assert(site and site:IsA("Model"), "SiteAndStreet was not found")

local function requireChild(parent, name, className)
	local child = assert(parent:FindFirstChild(name), parent:GetFullName() .. "." .. name .. " is missing")
	assert(child:IsA(className), child:GetFullName() .. " must be a " .. className)
	return child
end

local function requireDescendant(parent, name, className)
	local descendant = assert(parent:FindFirstChild(name, true), parent:GetFullName() .. " has no descendant " .. name)
	assert(descendant:IsA(className), descendant:GetFullName() .. " must be a " .. className)
	return descendant
end

-- Complete dependency/class preflight happens before any generated object is changed.
local foundation = requireChild(structure, "Foundation", "BasePart")
local porchDeck = requireChild(structure, "PorchDeck", "BasePart")
local frontDoorAnchor = requireChild(exterior, "FrontDoorPromptAnchor", "BasePart")
local denFloor = requireDescendant(house, "DenHoneyOakFloor", "BasePart")
local television = requireChild(furniture, "WoodCabinetCRTTelevision", "Model")
requireDescendant(television, "CurvedGlassScreen", "BasePart")
local georgeRecliner = requireChild(furniture, "GeorgeOliveRecliner", "Model")
local denSofa = requireChild(furniture, "RedPlaidDenSofa", "Model")
local cooperLot = requireChild(site, "CooperLot", "BasePart")
local garageFoundation = requireChild(garage, "GarageFoundation", "BasePart")
local garageHeader = requireChild(garage, "GarageDoorHeader", "BasePart")
local garageDoor = requireChild(garage, "InteractiveSectionalGarageDoor", "Model")
requireDescendant(garageDoor, "PromptMount", "BasePart")
local openingWidth = assert(tonumber(garageDoor:GetAttribute("OpeningWidth")), "Garage door OpeningWidth is missing")
local openingBottomY = assert(tonumber(garageDoor:GetAttribute("OpeningBottomY")), "Garage door OpeningBottomY is missing")
assert(openingWidth > 4, "Garage door opening is too narrow for task zones")
local refrigerator = requireChild(furniture, "WhiteHotpointRefrigerator", "Model")
requireDescendant(refrigerator, "CooperFridgeInterior", "Model")
requireChild(house, "CooperInteractions", "Model")
requireChild(ServerScriptService, "CooperInteractions", "Script")
local interactionRemotes = requireChild(ReplicatedStorage, "CooperInteractionsRemotes", "Folder")
requireChild(interactionRemotes, "Client", "RemoteEvent")

local campaignRoot = requireChild(ReplicatedStorage, "CooperGame", "Folder")
requireChild(campaignRoot, "Config", "ModuleScript")
local campaignEvents = requireChild(ServerScriptService, "CooperGameServerEvents", "Folder")
requireChild(campaignEvents, "RegisterAction", "BindableEvent")
requireChild(campaignEvents, "ReportAction", "BindableEvent")
requireChild(campaignEvents, "API", "BindableFunction")

local previousRoot = environment:FindFirstChild(ROOT_NAME)
if previousRoot then
	assert(previousRoot:IsA("Model"), environment:GetFullName() .. "." .. ROOT_NAME .. " must be a Model")
end
local previousScript = ServerScriptService:FindFirstChild(SCRIPT_NAME)
if previousScript then
	assert(previousScript:IsA("Script"), "ServerScriptService." .. SCRIPT_NAME .. " must be a Script")
end
assert(not environment:FindFirstChild(PREVIOUS_ROOT_NAME), "A stale task-world previous root requires inspection")
assert(not ServerScriptService:FindFirstChild(PREVIOUS_SCRIPT_NAME), "A stale task-world previous script requires inspection")

local staleRoot = environment:FindFirstChild(STAGING_ROOT_NAME)
if staleRoot then
	staleRoot:Destroy()
end
local staleScript = ServerScriptService:FindFirstChild(STAGING_SCRIPT_NAME)
if staleScript then
	staleScript:Destroy()
end

local function sourceLooksValid(source)
	if type(source) ~= "string" or #source < 5000 then
		return false
	end
	for _, marker in ipairs({
		"TASK_WORLD_CONTROLLER_VERSION",
		"RegisterAction",
		"ReportAction",
		"GetSnapshot",
		"CooperTaskGenerated",
		"OwnerUserId",
		"CooperLoneStarBeer",
	}) do
		if not string.find(source, marker, 1, true) then
			return false
		end
	end
	for _, eventKey in ipairs(EVENT_KEYS) do
		if not string.find(source, eventKey, 1, true) then
			return false
		end
	end
	return true
end

local preservedSource = nil
if previousScript then
	pcall(function()
		if sourceLooksValid(previousScript.Source) then
			preservedSource = previousScript.Source
		end
	end)
end

local function horizontalUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	return flat.Unit
end

local function instancePosition(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	end
	return instance:GetPivot().Position
end

local function partTop(part)
	return part.Position.Y + part.Size.Y * 0.5
end

local function faceFrame(position, forward)
	local direction = horizontalUnit(forward, Vector3.new(0, 0, -1))
	return CFrame.lookAt(position, position + direction, Vector3.yAxis)
end

local function makePart(parent, name, size, cframe, color, material, options)
	options = options or {}
	local part = Instance.new(options.className or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = options.anchored ~= false
	part.CanCollide = options.canCollide == true
	part.CanTouch = options.canTouch == true
	part.CanQuery = options.canQuery ~= false
	part.CastShadow = options.castShadow ~= false
	part.Transparency = options.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if options.shape and part:IsA("Part") then
		part.Shape = options.shape
	end
	part.Parent = parent
	return part
end

local function makeBillboard(parent, name, text, color, enabled)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Size = UDim2.fromOffset(280, 72)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.7, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 75
	billboard.Enabled = enabled == true
	billboard.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(25, 29, 34)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = color
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 241, 224)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = frame
	return billboard
end

local function makePrompt(parent, name, actionText, objectText, action, eventKey, itemId, holdDuration, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = holdDuration or 0.3
	prompt.MaxActivationDistance = distance or 11
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Enabled = false
	prompt:SetAttribute("CooperTaskAction", action)
	prompt:SetAttribute("CooperTaskEventKey", eventKey)
	if itemId then
		prompt:SetAttribute("CooperTaskItemId", itemId)
	end
	prompt.Parent = parent
	return prompt
end

local function makeStation(stations, specification)
	local model = Instance.new("Model")
	model.Name = specification.name
	model:SetAttribute("CooperTaskGenerated", true)
	model:SetAttribute("CooperTaskEventKey", specification.eventKey)
	model:SetAttribute("StationRole", specification.action)
	model:SetAttribute("TaskActive", false)
	if specification.itemId then
		model:SetAttribute("RequiredItemId", specification.itemId)
	end
	model.Parent = stations

	local pad = makePart(
		model,
		"ZonePad",
		specification.size or Vector3.new(3.2, 0.12, 3.2),
		specification.cframe,
		specification.color,
		Enum.Material.SmoothPlastic,
		{ canCollide = false, canQuery = true, transparency = 1, castShadow = false }
	)
	pad:SetAttribute("CooperTaskEventKey", specification.eventKey)
	pad:SetAttribute("ZoneColor", specification.color)

	local anchor = makePart(
		model,
		"PromptAnchor",
		Vector3.new(0.5, 0.5, 0.5),
		specification.cframe * CFrame.new(0, 2.0, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		{ canCollide = false, canQuery = false, castShadow = false, transparency = 1 }
	)
	makePrompt(
		anchor,
		"TaskPrompt",
		specification.actionText,
		specification.objectText,
		specification.action,
		specification.eventKey,
		specification.itemId,
		specification.holdDuration,
		specification.distance
	)
	makeBillboard(anchor, "TaskMarker", specification.label, specification.color, false)

	makePart(
		model,
		"StatusLamp",
		Vector3.new(0.42, 0.42, 0.42),
		specification.cframe * CFrame.new((specification.size and specification.size.X or 3.2) * 0.42, 0.34, 0),
		Color3.fromRGB(92, 96, 101),
		Enum.Material.Metal,
		{ canCollide = false, canQuery = false, shape = Enum.PartType.Ball }
	)
	return model
end

local function addToolDecoration(tool, name, size, relativeCFrame, color, material, options)
	local handle = tool:FindFirstChild("Handle")
	local decoration = makePart(
		tool,
		name,
		size,
		handle.CFrame * relativeCFrame,
		color,
		material,
		{
			anchored = false,
			canCollide = false,
			canQuery = false,
			castShadow = options and options.castShadow ~= false,
			shape = options and options.shape or nil,
			transparency = options and options.transparency or 0,
		}
	)
	decoration.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Name = "TaskItemWeld"
	weld.Part0 = handle
	weld.Part1 = decoration
	weld.Parent = decoration
	return decoration
end

local function addSurfaceLabel(part, text, background, foreground)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "ItemLabel"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 90
	surface.LightInfluence = 0.15
	surface.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = foreground
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
end

local function makeTaskTool(items, specification)
	local tool = Instance.new("Tool")
	tool.Name = specification.itemId
	tool.ToolTip = specification.displayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = specification.grip or CFrame.new(0, -0.35, -0.75)
	tool:SetAttribute("CooperTaskGenerated", true)
	tool:SetAttribute("CooperTaskItemId", specification.itemId)
	tool:SetAttribute("CooperTaskEventKey", specification.eventKey)
	tool:SetAttribute("DisplayName", specification.displayName)
	tool:SetAttribute("OwnerUserId", 0)
	tool:SetAttribute("TaskActive", false)
	tool:SetAttribute("HomeCFrame", specification.homeCFrame)
	tool.Parent = items

	local handle = makePart(
		tool,
		"Handle",
		specification.size,
		specification.homeCFrame,
		specification.color,
		specification.material,
		{
			canCollide = true,
			canTouch = false,
			shape = specification.shape,
		}
	)
	handle:SetAttribute("CooperTaskItemId", specification.itemId)
	handle:SetAttribute("CooperTaskEventKey", specification.eventKey)
	makePrompt(
		handle,
		"PickupPrompt",
		"Pick Up",
		specification.displayName,
		"PickupItem",
		specification.eventKey,
		specification.itemId,
		0.25,
		10
	)
	makeBillboard(handle, "TaskMarker", "TASK ITEM\n" .. string.upper(specification.displayName), specification.markerColor, false)

	local highlight = Instance.new("Highlight")
	highlight.Name = "TaskHighlight"
	highlight.Adornee = handle
	highlight.FillColor = specification.markerColor
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = Color3.fromRGB(255, 245, 190)
	highlight.OutlineTransparency = 0.08
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = tool
	return tool
end

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"InstallCooperTaskWorld",
		"Install seven physical Cooper campaign task producers"
	)
end)

local function finishRecording(commit)
	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(
				recording,
				commit and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
			)
		end)
	elseif commit then
		pcall(function()
			ChangeHistoryService:SetWaypoint("Cooper physical task world installed")
		end)
	end
end

local stagedRoot = nil
local stagedScript = nil
local rootSwapped = false
local scriptSwapped = false

local ok, result = xpcall(function()
	-- Derive all placement frames from the current house, porch, and garage geometry.
	local denY = partTop(denFloor)
	local tvPosition = instancePosition(television)
	local reclinerPosition = instancePosition(georgeRecliner)
	local sofaPosition = instancePosition(denSofa)
	local tvToRoom = horizontalUnit(reclinerPosition - tvPosition, Vector3.new(1, 0, 0))
	local denSide = Vector3.new(-tvToRoom.Z, 0, tvToRoom.X)
	local reclinerToTV = horizontalUnit(tvPosition - reclinerPosition, -tvToRoom)

	local houseCenter = foundation.Position
	local porchOutward = horizontalUnit(porchDeck.Position - houseCenter, Vector3.new(0, 0, -1))
	local porchSide = horizontalUnit(porchDeck.CFrame.RightVector, Vector3.new(1, 0, 0))
	if math.abs(porchSide:Dot(porchOutward)) > 0.8 then
		porchSide = Vector3.new(-porchOutward.Z, 0, porchOutward.X)
	end
	local porchY = partTop(porchDeck)
	local yardY = partTop(cooperLot)

	local insideGarage = horizontalUnit(garageFoundation.Position - garageHeader.Position, Vector3.new(0, 0, 1))
	local garageSide = horizontalUnit(garageHeader.CFrame.RightVector, Vector3.new(1, 0, 0))
	if math.abs(garageSide:Dot(insideGarage)) > 0.8 then
		garageSide = Vector3.new(-insideGarage.Z, 0, insideGarage.X)
	end
	local doorCenter = Vector3.new(garageHeader.Position.X, openingBottomY, garageHeader.Position.Z)

	stagedRoot = Instance.new("Model")
	stagedRoot.Name = STAGING_ROOT_NAME
	stagedRoot:SetAttribute("InstallVersion", INSTALL_VERSION)
	stagedRoot:SetAttribute("GeneratedBy", "cooper_task_world_install.luau")
	stagedRoot:SetAttribute("TaskEventCount", #EVENT_KEYS)
	stagedRoot:SetAttribute("ControllerReady", false)
	stagedRoot:SetAttribute("SnapshotHealthy", false)

	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = stagedRoot
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = stagedRoot

	local amber = Color3.fromRGB(255, 181, 52)
	local blue = Color3.fromRGB(68, 154, 230)
	local green = Color3.fromRGB(67, 203, 116)
	local red = Color3.fromRGB(224, 73, 59)
	local violet = Color3.fromRGB(149, 95, 219)

	local georgeStationPosition = Vector3.new(
		reclinerPosition.X,
		denY + 0.07,
		reclinerPosition.Z
	) + reclinerToTV * 2.8
	makeStation(stations, {
		name = "GeorgeDrinkStation",
		eventKey = "GeorgeDrinkDelivered",
		action = "DeliverGeorgeDrink",
		actionText = "Give Lone Star",
		objectText = "George's recliner",
		label = "GEORGE'S COLD ONE\nHold a Lone Star bottle",
		cframe = faceFrame(georgeStationPosition, reclinerToTV),
		size = Vector3.new(2.7, 0.12, 2.7),
		color = amber,
		holdDuration = 0.55,
		distance = 11,
	})

	local remoteReturnPosition = Vector3.new(tvPosition.X, denY + 0.07, tvPosition.Z) + tvToRoom * 3.0 + denSide * 1.9
	makeStation(stations, {
		name = "TVRemoteReturnStation",
		eventKey = "TVRemoteReturned",
		action = "DeliverItem",
		itemId = "TVRemote",
		actionText = "Return Remote",
		objectText = "Den remote tray",
		label = "RETURN TV REMOTE",
		cframe = faceFrame(remoteReturnPosition, tvToRoom),
		size = Vector3.new(2.8, 0.12, 2.8),
		color = blue,
		holdDuration = 0.45,
		distance = 11,
	})

	local channelPosition = Vector3.new(tvPosition.X, denY + 0.07, tvPosition.Z) + tvToRoom * 2.4 - denSide * 1.7
	makeStation(stations, {
		name = "FootballChannelStation",
		eventKey = "FootballChannelSet",
		action = "SetFootballChannel",
		actionText = "Tune Football",
		objectText = "Den TV controls",
		label = "FOOTBALL CHANNEL\nMEDFORD HOME GAME",
		cframe = faceFrame(channelPosition, tvToRoom),
		size = Vector3.new(2.5, 0.12, 2.5),
		color = green,
		holdDuration = 1.0,
		distance = 11,
	})

	local machineZonePosition = doorCenter + insideGarage * 5.8 + garageSide * (openingWidth * 0.22)
	machineZonePosition = Vector3.new(machineZonePosition.X, openingBottomY + 0.07, machineZonePosition.Z)
	makeStation(stations, {
		name = "MachineCrateDeliveryZone",
		eventKey = "MachineCrateDelivered",
		action = "DeliverItem",
		itemId = "MachineCrate",
		actionText = "Set Down Crate",
		objectText = "Garage machine bay",
		label = "TIME-MACHINE CRATE BAY",
		cframe = faceFrame(machineZonePosition, insideGarage),
		size = Vector3.new(4.0, 0.12, 4.0),
		color = violet,
		holdDuration = 0.65,
		distance = 12,
	})

	local obstructionZonePosition = doorCenter + insideGarage * 4.8 - garageSide * (openingWidth * 0.24)
	obstructionZonePosition = Vector3.new(obstructionZonePosition.X, openingBottomY + 0.07, obstructionZonePosition.Z)
	makeStation(stations, {
		name = "GarageObstructionClearZone",
		eventKey = "GarageObstructionCleared",
		action = "DeliverItem",
		itemId = "GarageObstruction",
		actionText = "Clear Track",
		objectText = "Safe spot beside garage track",
		label = "MOVE OBSTRUCTION HERE",
		cframe = faceFrame(obstructionZonePosition, insideGarage),
		size = Vector3.new(3.4, 0.12, 3.4),
		color = red,
		holdDuration = 0.5,
		distance = 12,
	})

	local porchReturnPosition = Vector3.new(frontDoorAnchor.Position.X, porchY + 0.07, frontDoorAnchor.Position.Z)
		+ porchOutward * 1.1 + porchSide * 2.4
	makeStation(stations, {
		name = "PorchDeliveryReturnZone",
		eventKey = "PorchDeliveryRetrieved",
		action = "DeliverItem",
		itemId = "PorchDelivery",
		actionText = "Leave Package",
		objectText = "Cooper front porch",
		label = "PORCH DELIVERY DROP",
		cframe = faceFrame(porchReturnPosition, porchOutward),
		size = Vector3.new(3.2, 0.12, 3.2),
		color = blue,
		holdDuration = 0.5,
		distance = 11,
	})

	-- The garage conversion's couch and folding table occupy its front-center bay.
	-- Derive a rear-center storage depth from the current foundation instead of
	-- placing the storm pad on top of that furniture.
	local stormStorageDepth = math.max(8, garageFoundation.Size.Z - 7)
	local stormZonePosition = doorCenter + insideGarage * stormStorageDepth
	stormZonePosition = Vector3.new(stormZonePosition.X, openingBottomY + 0.07, stormZonePosition.Z)
	makeStation(stations, {
		name = "StormSafeZone",
		eventKey = "StormItemSecured",
		action = "DeliverItem",
		itemId = "StormItem",
		actionText = "Secure Item",
		objectText = "Garage storm-safe area",
		label = "STORM-SAFE STORAGE",
		cframe = faceFrame(stormZonePosition, insideGarage),
		size = Vector3.new(3.8, 0.12, 3.8),
		color = green,
		holdDuration = 0.6,
		distance = 12,
	})

	local remoteHomePosition = Vector3.new(sofaPosition.X, denY + 0.13, sofaPosition.Z)
		+ horizontalUnit(tvPosition - sofaPosition, tvToRoom) * 1.5 - denSide * 2.8
	local remote = makeTaskTool(items, {
		itemId = "TVRemote",
		eventKey = "TVRemoteReturned",
		displayName = "Den TV Remote",
		homeCFrame = faceFrame(remoteHomePosition, tvToRoom) * CFrame.Angles(0, 0, math.rad(-6)),
		size = Vector3.new(0.72, 0.20, 1.55),
		color = Color3.fromRGB(54, 49, 43),
		material = Enum.Material.SmoothPlastic,
		markerColor = blue,
		grip = CFrame.new(0, -0.08, -0.55),
	})
	for index, z in ipairs({ -0.42, -0.12, 0.18, 0.48 }) do
		addToolDecoration(
			remote,
			"ChannelButton" .. index,
			Vector3.new(0.16, 0.08, 0.16),
			CFrame.new((index % 2 == 0 and 0.15 or -0.15), 0.13, z),
			index == 1 and Color3.fromRGB(190, 50, 43) or Color3.fromRGB(181, 174, 151),
			Enum.Material.SmoothPlastic
		)
	end

	local machineHomePosition = doorCenter - insideGarage * 5.5 + garageSide * (openingWidth * 0.18)
	machineHomePosition = Vector3.new(machineHomePosition.X, openingBottomY + 0.95, machineHomePosition.Z)
	local machineCrate = makeTaskTool(items, {
		itemId = "MachineCrate",
		eventKey = "MachineCrateDelivered",
		displayName = "Time-Machine Parts Crate",
		homeCFrame = faceFrame(machineHomePosition, insideGarage),
		size = Vector3.new(2.7, 1.8, 2.25),
		color = Color3.fromRGB(129, 87, 48),
		material = Enum.Material.WoodPlanks,
		markerColor = violet,
		grip = CFrame.new(0, -0.9, -1.6),
	})
	addToolDecoration(machineCrate, "MetalBandLeft", Vector3.new(0.18, 1.86, 2.31), CFrame.new(-0.82, 0, 0), Color3.fromRGB(91, 91, 84), Enum.Material.Metal)
	addToolDecoration(machineCrate, "MetalBandRight", Vector3.new(0.18, 1.86, 2.31), CFrame.new(0.82, 0, 0), Color3.fromRGB(91, 91, 84), Enum.Material.Metal)
	addSurfaceLabel(machineCrate.Handle, "FRAGILE\nMACHINE PARTS", Color3.fromRGB(230, 211, 166), Color3.fromRGB(92, 46, 40))

	local obstructionHomePosition = doorCenter + insideGarage * 5.4 - garageSide * (openingWidth * 0.18)
	obstructionHomePosition = Vector3.new(obstructionHomePosition.X, openingBottomY + 0.55, obstructionHomePosition.Z)
	local obstruction = makeTaskTool(items, {
		itemId = "GarageObstruction",
		eventKey = "GarageObstructionCleared",
		displayName = "Garage Track Toolbox",
		homeCFrame = faceFrame(obstructionHomePosition, garageSide),
		size = Vector3.new(2.15, 0.78, 1.1),
		color = Color3.fromRGB(178, 45, 40),
		material = Enum.Material.Metal,
		markerColor = red,
		grip = CFrame.new(0, -0.34, -0.9),
	})
	addToolDecoration(obstruction, "ToolboxHandle", Vector3.new(1.1, 0.13, 0.13), CFrame.new(0, 0.62, 0), Color3.fromRGB(58, 57, 52), Enum.Material.Metal)
	addToolDecoration(obstruction, "HandlePostLeft", Vector3.new(0.13, 0.5, 0.13), CFrame.new(-0.48, 0.42, 0), Color3.fromRGB(58, 57, 52), Enum.Material.Metal)
	addToolDecoration(obstruction, "HandlePostRight", Vector3.new(0.13, 0.5, 0.13), CFrame.new(0.48, 0.42, 0), Color3.fromRGB(58, 57, 52), Enum.Material.Metal)

	-- Keep the package fully on the lawn, clear of the raised curved walkway.
	local deliveryHomePosition = porchDeck.Position + porchOutward * 12 + porchSide * 6.6
	-- Sit fully on the lot (half of 1.25 height + small clearance).
	deliveryHomePosition = Vector3.new(deliveryHomePosition.X, yardY + 0.75, deliveryHomePosition.Z)
	local porchDelivery = makeTaskTool(items, {
		itemId = "PorchDelivery",
		eventKey = "PorchDeliveryRetrieved",
		displayName = "Cooper Family Package",
		homeCFrame = faceFrame(deliveryHomePosition, -porchOutward),
		size = Vector3.new(1.8, 1.25, 1.55),
		color = Color3.fromRGB(172, 126, 76),
		material = Enum.Material.Cardboard,
		markerColor = blue,
		grip = CFrame.new(0, -0.58, -1.05),
	})
	addToolDecoration(porchDelivery, "PackingTape", Vector3.new(0.30, 1.29, 1.59), CFrame.new(0, 0, 0), Color3.fromRGB(218, 190, 126), Enum.Material.SmoothPlastic)
	addSurfaceLabel(porchDelivery.Handle, "TO: COOPER FAMILY\nMEDFORD, TEXAS", Color3.fromRGB(232, 219, 180), Color3.fromRGB(63, 60, 52))

	local stormHomePosition = porchDeck.Position + porchOutward * 9.5 - porchSide * 8.5
	stormHomePosition = Vector3.new(stormHomePosition.X, yardY + 0.18, stormHomePosition.Z)
	local stormItem = makeTaskTool(items, {
		itemId = "StormItem",
		eventKey = "StormItemSecured",
		displayName = "Loose Metal Yard Sign",
		homeCFrame = faceFrame(stormHomePosition, porchOutward) * CFrame.Angles(math.rad(8), 0, math.rad(5)),
		size = Vector3.new(2.8, 0.16, 2.0),
		color = Color3.fromRGB(127, 141, 139),
		material = Enum.Material.Metal,
		markerColor = green,
		grip = CFrame.new(0, -0.15, -1.0),
	})
	addSurfaceLabel(stormItem.Handle, "LOOSE IN HIGH WIND", Color3.fromRGB(226, 194, 61), Color3.fromRGB(65, 54, 39))

	stagedScript = Instance.new("Script")
	stagedScript.Name = STAGING_SCRIPT_NAME
	stagedScript:SetAttribute("SourceFile", "CooperTaskWorld.server.luau")
	stagedScript:SetAttribute("InstallVersion", INSTALL_VERSION)
	stagedScript:SetAttribute("SourcePreserved", preservedSource ~= nil)
	stagedScript.Source = preservedSource
		or "error(\"CooperTaskWorld source has not been injected; install CooperTaskWorld.server.luau\")"
	stagedScript.Enabled = false

	-- Validate the complete staged graph before either canonical path changes.
	assert(#stations:GetChildren() == #EVENT_KEYS, "Staged task-world station count is wrong")
	assert(#items:GetChildren() == 5, "Staged task-world item count is wrong")
	local stationEvents = {}
	local promptCount = 0
	for _, descendant in ipairs(stagedRoot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			promptCount += 1
			local eventKey = descendant:GetAttribute("CooperTaskEventKey")
			assert(type(eventKey) == "string", descendant:GetFullName() .. " has no event key")
			if descendant.Name == "TaskPrompt" then
				assert(not stationEvents[eventKey], "Duplicate staged station for " .. eventKey)
				stationEvents[eventKey] = true
			end
		end
	end
	assert(promptCount == 12, "Staged task-world must contain exactly 12 prompts")
	for _, eventKey in ipairs(EVENT_KEYS) do
		assert(stationEvents[eventKey], "Staged task-world has no station for " .. eventKey)
	end
	assert(#stagedScript.Source > 20, "Staged task-world source target is invalid")
	assert(stagedScript.Enabled == false, "Staged task-world controller must remain disabled")

	-- Commit both replacements while the new controller is disabled. Old objects are
	-- retained under rollback names until every canonical-path assertion succeeds.
	if previousRoot then
		previousRoot.Name = PREVIOUS_ROOT_NAME
	end
	stagedRoot.Name = ROOT_NAME
	stagedRoot.Parent = environment
	rootSwapped = true

	if previousScript then
		previousScript.Name = PREVIOUS_SCRIPT_NAME
	end
	stagedScript.Parent = ServerScriptService
	stagedScript.Name = SCRIPT_NAME
	scriptSwapped = true

	assert(environment:FindFirstChild(ROOT_NAME) == stagedRoot, "Task-world root swap failed")
	assert(ServerScriptService:FindFirstChild(SCRIPT_NAME) == stagedScript, "Task-world controller swap failed")
	assert(stagedScript.Enabled == false, "Task-world controller unexpectedly enabled during install")

	if previousRoot then
		previousRoot:Destroy()
	end
	if previousScript then
		previousScript:Destroy()
	end

	return {
		sourcePreserved = preservedSource ~= nil,
		stations = #stations:GetChildren(),
		items = #items:GetChildren(),
	}
end, function(message)
	return debug.traceback(tostring(message), 2)
end)

if not ok then
	if stagedScript and stagedScript.Parent then
		stagedScript:Destroy()
	elseif stagedScript then
		stagedScript:Destroy()
	end
	if previousScript and previousScript.Parent then
		previousScript.Name = SCRIPT_NAME
	end
	if stagedRoot and stagedRoot.Parent then
		stagedRoot:Destroy()
	elseif stagedRoot then
		stagedRoot:Destroy()
	end
	if previousRoot and previousRoot.Parent then
		previousRoot.Name = ROOT_NAME
	end
	rootSwapped = false
	scriptSwapped = false
	finishRecording(false)
	error(result)
end

assert(rootSwapped and scriptSwapped, "Task-world transaction did not commit both canonical paths")
finishRecording(true)
print(string.format(
	"[CooperTaskWorldInstaller] Installed %d stations and %d resettable items; controller disabled; source preserved=%s",
	result.stations,
	result.items,
	tostring(result.sourcePreserved)
))
