--!nonstrict
-- Edit-mode installer for Cooper house interior interactions.
-- Geometry is staged before it replaces the previous generated interaction
-- model. Existing valid runtime scripts are preserved and kept enabled.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local environment = workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment is missing")
local house = environment:FindFirstChild("CooperHouse")
assert(house and house:IsA("Model"), "CooperHouse is missing")
local furniture = house:FindFirstChild("FurnitureAndProps")
assert(furniture and furniture:IsA("Model"), "Cooper house FurnitureAndProps is missing")

local serverScript = ServerScriptService:FindFirstChild("CooperInteractions")
local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientScript = starterScripts:FindFirstChild("CooperInteractions")

local function requireChild(parent, name, expectedClass)
	local child = parent and parent:FindFirstChild(name)
	assert(child, string.format("%s.%s is missing", parent and parent:GetFullName() or "nil", name))
	if expectedClass then
		assert(child:IsA(expectedClass), child:GetFullName() .. " must be a " .. expectedClass)
	end
	return child
end

-- Complete dependency preflight happens before any generated object or source
-- is touched, so a changed house build produces one useful error rather than a
-- half-installed feature set.
local preflightBedroomDetails = requireChild(furniture, "YoungSheldonBedroomDetails_V2", "Model")
local preflightSharedRoom = requireChild(preflightBedroomDetails, "SheldonAndMissyRoom", "Model")
requireChild(preflightSharedRoom, "MissyDetailedTeddyBear", "Model")
requireChild(preflightSharedRoom, "MissyDetailedRabbit", "Model")
local preflightComputer = requireChild(preflightSharedRoom, "Sheldon1980sComputerDesk", "Model")
requireChild(preflightComputer, "Keyboard", "BasePart")
requireChild(preflightBedroomDetails, "GeorgieRoomStoryProps", "Model")
local preflightStory = requireChild(furniture, "YoungSheldonStoryDetails_V2", "Model")
requireChild(preflightStory, "CharacterDeepCuts", "Model")
local preflightToilet = requireChild(furniture, "SideFacingIvoryToilet", "Model")
requireChild(preflightToilet, "WhiteToiletBowl", "BasePart")
requireChild(preflightToilet, "ChromeFlushHandle", "BasePart")
local preflightShower = requireChild(furniture, "BlackTileFrostedShower", "Model")
requireChild(preflightShower, "ChromeShowerPipe", "BasePart")
requireChild(preflightShower, "ShowerThreshold", "BasePart")
local preflightVanity = requireChild(furniture, "OxbloodTileBathroomVanity", "Model")
requireChild(preflightVanity, "CreamSinkBasin", "BasePart")
assert(preflightVanity:FindFirstChild("ChromeTap2") or preflightVanity:FindFirstChild("ChromeTap1"), "Bathroom tap is missing")
requireChild(preflightVanity, "Toothbrush1", "BasePart")
local preflightFridge = requireChild(furniture, "WhiteHotpointRefrigerator", "Model")
requireChild(preflightFridge, "RefrigeratorBody", "BasePart")

ChangeHistoryService:SetWaypoint("Before Cooper interior interaction install")

local function getOrCreate(parent, className, name)
	local current = parent:FindFirstChild(name)
	if current and not current:IsA(className) then
		current:Destroy()
		current = nil
	end
	if not current then
		current = Instance.new(className)
		current.Name = name
		current.Parent = parent
	end
	return current
end

local function makePart(parent, name, size, cframe, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(240, 240, 235)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = canCollide == true
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makePrompt(parent, name, actionText, objectText, action, keyCode, holdDuration, maxDistance)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = keyCode or Enum.KeyCode.E
	prompt.GamepadKeyCode = prompt.KeyboardKeyCode == Enum.KeyCode.F and Enum.KeyCode.ButtonY or Enum.KeyCode.ButtonX
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = maxDistance or 9
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("CooperAction", action)
	prompt.Parent = parent
	return prompt
end

local function removeOldGeneratedWelds(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("WeldConstraint")
			and (descendant.Name == "CooperObjectWeld" or descendant.Name == "CooperHoldWeld")
		then
			descendant:Destroy()
		end
	end
end

local function preparePickable(model, displayName, throwPower, isCube)
	assert(model and model:IsA("Model"), "Missing pickable model: " .. displayName)

	local previousHandle = model:FindFirstChild("InteractionHandle")
	if previousHandle then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= previousHandle then
				descendant.Anchored = true
			end
		end
		previousHandle:Destroy()
	end
	removeOldGeneratedWelds(model)

	local visibleParts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			table.insert(visibleParts, descendant)
		end
	end
	assert(#visibleParts > 0, displayName .. " contains no BaseParts")

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local handle = makePart(
		model,
		"InteractionHandle",
		Vector3.new(
			math.clamp(boundsSize.X * 0.9, 0.45, 2.5),
			math.clamp(boundsSize.Y * 0.9, 0.45, 2.5),
			math.clamp(boundsSize.Z * 0.9, 0.45, 2.5)
		),
		boundsCFrame,
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		1,
		true
	)
	handle.CanTouch = true
	handle:SetAttribute("GeneratedBy", "CooperInteractions")

	for _, part in ipairs(visibleParts) do
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CooperObjectWeld"
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
	end

	model.PrimaryPart = handle
	model:SetAttribute("CooperPickable", true)
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("ThrowPower", throwPower)
	model:SetAttribute("CubePuzzle", isCube == true)
	makePrompt(handle, "CooperPickupPrompt", "Pick Up", displayName, "Pickup", Enum.KeyCode.E, 0.12, 9)
	if isCube then
		makePrompt(handle, "CooperCubePrompt", "Solve Cube", displayName, "CubePuzzle", Enum.KeyCode.F, 0.15, 9)
	end
	return model
end

-- Build under a staging name. Original furniture stays outside this model.
local oldRoot = house:FindFirstChild("CooperInteractions")
local previousFlushSoundId = oldRoot and oldRoot:GetAttribute("ToiletFlushSoundId") or nil
if type(previousFlushSoundId) ~= "string" and oldRoot then
	local oldToiletEffect = oldRoot:FindFirstChild("ToiletWaterEffect", true)
	previousFlushSoundId = oldToiletEffect and oldToiletEffect:GetAttribute("FlushSoundId") or nil
end
local staleStaging = house:FindFirstChild("CooperInteractions_Staging")
if staleStaging then
	staleStaging:Destroy()
end
local interactionRoot = Instance.new("Model")
interactionRoot.Name = "CooperInteractions_Staging"
interactionRoot:SetAttribute("InstallerVersion", 2)
interactionRoot:SetAttribute("ShowerOn", false)
interactionRoot.Parent = house

-- Remove the kitchen chair that blocks direct refrigerator access, plus only its
-- generated invisible functional seat from the earlier seating pass.
local blockingChair = furniture:FindFirstChild("KitchenDinetteChairA")
if blockingChair then
	blockingChair:Destroy()
end
local coreRepairs = house:FindFirstChild("HouseCoreRepairs")
if coreRepairs then
	for _, descendant in ipairs(coreRepairs:GetDescendants()) do
		if string.find(descendant.Name, "KitchenDinetteChairA", 1, true) then
			descendant:Destroy()
		end
	end
end

-- Multi-part pickup props ----------------------------------------------------

local bedroomDetails = furniture:FindFirstChild("YoungSheldonBedroomDetails_V2")
assert(bedroomDetails, "YoungSheldonBedroomDetails_V2 is missing")
local sharedRoom = bedroomDetails:FindFirstChild("SheldonAndMissyRoom")
assert(sharedRoom, "SheldonAndMissyRoom is missing")
preparePickable(sharedRoom:FindFirstChild("MissyDetailedTeddyBear"), "Missy's teddy bear", 50, false)
preparePickable(sharedRoom:FindFirstChild("MissyDetailedRabbit"), "Missy's stuffed rabbit", 50, false)

local georgieProps = bedroomDetails:FindFirstChild("GeorgieRoomStoryProps")
assert(georgieProps, "GeorgieRoomStoryProps is missing")
local footballBundle = georgieProps:FindFirstChild("GeorgieFootballInteractive")
if not footballBundle then
	footballBundle = Instance.new("Model")
	footballBundle.Name = "GeorgieFootballInteractive"
	footballBundle.Parent = georgieProps
end
for _, child in ipairs(georgieProps:GetChildren()) do
	if child ~= footballBundle and (child.Name == "RealisticFootball" or string.sub(child.Name, 1, 12) == "FootballLace") then
		child.Parent = footballBundle
	end
end
preparePickable(footballBundle, "Georgie's football", 72, false)

local storyDetails = furniture:FindFirstChild("YoungSheldonStoryDetails_V2")
local characterDetails = storyDetails and storyDetails:FindFirstChild("CharacterDeepCuts")
assert(characterDetails, "YoungSheldonStoryDetails_V2.CharacterDeepCuts is missing")
local cubeBundle = characterDetails:FindFirstChild("SheldonPuzzleCubeInteractive")
if not cubeBundle then
	cubeBundle = Instance.new("Model")
	cubeBundle.Name = "SheldonPuzzleCubeInteractive"
	cubeBundle.Parent = characterDetails
end
for _, child in ipairs(characterDetails:GetChildren()) do
	if child ~= cubeBundle and child.Name == "PuzzleCubelet" and child:IsA("BasePart") then
		child.Parent = cubeBundle
	end
end
preparePickable(cubeBundle, "Sheldon's puzzle cube", 45, true)

-- Bathroom ------------------------------------------------------------------

local bathroom = Instance.new("Model")
bathroom.Name = "BathroomInteractions"
bathroom.Parent = interactionRoot

local toilet = furniture:FindFirstChild("SideFacingIvoryToilet")
assert(toilet and toilet:IsA("Model"), "SideFacingIvoryToilet is missing")
local bowl = toilet:FindFirstChild("WhiteToiletBowl")
local flushHandle = toilet:FindFirstChild("ChromeFlushHandle")
assert(bowl and flushHandle, "Rebuilt toilet parts are missing")
local toiletLook = toilet:GetPivot().LookVector
local seatPosition = bowl.Position + Vector3.new(0, 0.73, 0)
local toiletSeat = Instance.new("Seat")
toiletSeat.Name = "ToiletSeat"
toiletSeat.Size = Vector3.new(1.35, 0.18, 1.55)
toiletSeat.CFrame = CFrame.lookAt(seatPosition, seatPosition + toiletLook, Vector3.yAxis)
toiletSeat.Transparency = 1
toiletSeat.Anchored = true
toiletSeat.CanCollide = false
toiletSeat.CanTouch = false
toiletSeat.Parent = bathroom
makePrompt(toiletSeat, "CooperToiletPrompt", "Sit / Use", "Bathroom Toilet", "ToiletSit", Enum.KeyCode.E, 0.2, 8)
makePrompt(flushHandle, "CooperToiletFlushPrompt", "Flush", "Bathroom Toilet", "ToiletFlush", Enum.KeyCode.F, 0.15, 8)

local bowlWater = toilet:FindFirstChild("BowlWater") or bowl
local toiletEffect = makePart(
	bathroom,
	"ToiletWaterEffect",
	Vector3.new(0.25, 0.1, 0.25),
	CFrame.new(bowlWater.Position + Vector3.new(0, 0.18, 0)),
	Color3.fromRGB(150, 215, 235),
	Enum.Material.Glass,
	1,
	false
)
local toiletEmitter = Instance.new("ParticleEmitter")
toiletEmitter.Name = "FlushWater"
toiletEmitter.Enabled = false
toiletEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
toiletEmitter.Color = ColorSequence.new(Color3.fromRGB(155, 220, 242), Color3.fromRGB(235, 248, 255))
toiletEmitter.Lifetime = NumberRange.new(0.35, 0.7)
toiletEmitter.Speed = NumberRange.new(2, 5)
toiletEmitter.SpreadAngle = Vector2.new(55, 55)
toiletEmitter.Acceleration = Vector3.new(0, -10, 0)
toiletEmitter.Rate = 0
toiletEmitter.Parent = toiletEffect

local toiletSwirl = makePart(
	bathroom,
	"ToiletFlushSwirl",
	Vector3.new(1.15, 0.055, 0.16),
	CFrame.new(bowlWater.Position + Vector3.new(0, 0.12, 0)),
	Color3.fromRGB(126, 211, 242),
	Enum.Material.Neon,
	1,
	false
)
toiletSwirl.CanQuery = false
toiletSwirl:SetAttribute("RestCFrame", toiletSwirl.CFrame)
toiletSwirl:SetAttribute("RestSize", toiletSwirl.Size)

-- Public Creator Store Pro Sound Effects drain bubbling/gurgle. Runtime restarts
-- it at zero and uses only the first three seconds. Builders can replace this
-- attribute without changing source; an empty/invalid override safely skips it.
local defaultFlushSoundId = "rbxassetid://9125499039"
local legacyDefaultFlushSoundId = "rbxasset://sounds/impact_water.mp3"
local configuredFlushSoundId = if type(previousFlushSoundId) == "string"
		and previousFlushSoundId ~= legacyDefaultFlushSoundId
	then previousFlushSoundId
	else defaultFlushSoundId
interactionRoot:SetAttribute("ToiletFlushSoundId", configuredFlushSoundId)
toiletEffect:SetAttribute("FlushSoundId", configuredFlushSoundId)
local toiletFlushSound = Instance.new("Sound")
toiletFlushSound.Name = "CooperToiletFlushSound"
toiletFlushSound.SoundId = configuredFlushSoundId
toiletFlushSound.Volume = 0.72
toiletFlushSound.PlaybackSpeed = 1
toiletFlushSound.RollOffMinDistance = 4
toiletFlushSound.RollOffMaxDistance = 28
toiletFlushSound.Parent = toiletEffect

local shower = furniture:FindFirstChild("BlackTileFrostedShower")
assert(shower and shower:IsA("Model"), "BlackTileFrostedShower is missing")
local showerPipe = shower:FindFirstChild("ChromeShowerPipe")
local showerThreshold = shower:FindFirstChild("ShowerThreshold")
assert(showerPipe and showerThreshold, "Shower interaction anchors are missing")
makePrompt(showerPipe, "CooperShowerTogglePrompt", "Turn On Shower", "Shower Controls", "ShowerToggle", Enum.KeyCode.E, 0.25, 9)
makePrompt(showerThreshold, "CooperShowerUsePrompt", "Take Shower", "Shower", "ShowerUse", Enum.KeyCode.F, 1.1, 9)
local showerBoundsCFrame = select(1, shower:GetBoundingBox())
local showerWaterPart = makePart(
	bathroom,
	"ShowerWater",
	Vector3.new(2.3, 0.15, 1.9),
	CFrame.new(showerBoundsCFrame.Position.X, showerPipe.Position.Y - 0.35, showerBoundsCFrame.Position.Z),
	Color3.fromRGB(180, 225, 245),
	Enum.Material.Glass,
	1,
	false
)
local showerEmitter = Instance.new("ParticleEmitter")
showerEmitter.Name = "WaterSpray"
showerEmitter.Enabled = false
showerEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
showerEmitter.EmissionDirection = Enum.NormalId.Bottom
showerEmitter.Color = ColorSequence.new(Color3.fromRGB(178, 225, 246), Color3.fromRGB(225, 245, 255))
showerEmitter.LightInfluence = 0.4
showerEmitter.Lifetime = NumberRange.new(0.55, 0.9)
showerEmitter.Speed = NumberRange.new(7, 11)
showerEmitter.Rate = 115
showerEmitter.SpreadAngle = Vector2.new(18, 18)
showerEmitter.Acceleration = Vector3.new(0, -26, 0)
showerEmitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.11),
	NumberSequenceKeypoint.new(1, 0.035),
})
showerEmitter.Parent = showerWaterPart
local showerLight = Instance.new("PointLight")
showerLight.Name = "WaterGlint"
showerLight.Enabled = false
showerLight.Color = Color3.fromRGB(191, 229, 247)
showerLight.Brightness = 0.6
showerLight.Range = 7
showerLight.Parent = showerWaterPart

-- Particle transparency can vary behind frosted glass, so these thin 3D neon
-- strands provide an all-angle silhouette from both inside and outside.
local streamTopY = showerWaterPart.Position.Y - 0.08
local streamBottomY = showerThreshold.Position.Y + showerThreshold.Size.Y * 0.5 + 0.22
local streamLength = math.max(1, streamTopY - streamBottomY)
local streamCenterY = (streamTopY + streamBottomY) * 0.5
for streamIndex, offset in ipairs({
	Vector2.new(-0.76, -0.50),
	Vector2.new(-0.38, 0.02),
	Vector2.new(0, -0.34),
	Vector2.new(0.38, 0.34),
	Vector2.new(0.76, -0.06),
	Vector2.new(-0.62, 0.48),
	Vector2.new(0.62, 0.52),
}) do
	local horizontalOffset = showerBoundsCFrame.RightVector * offset.X
		+ showerBoundsCFrame.LookVector * offset.Y
	local streamPosition = Vector3.new(
		showerBoundsCFrame.Position.X + horizontalOffset.X,
		streamCenterY,
		showerBoundsCFrame.Position.Z + horizontalOffset.Z
	)
	local stream = makePart(
		bathroom,
		"ShowerVisibleStream" .. streamIndex,
		Vector3.new(0.045, streamLength, 0.045),
		CFrame.new(streamPosition),
		Color3.fromRGB(164, 225, 248),
		Enum.Material.Neon,
		1,
		false
	)
	stream.CanQuery = false
	stream:SetAttribute("CooperShowerStream", true)
	stream:SetAttribute("OnTransparency", 0.38 + (streamIndex % 3) * 0.07)
	local beamTop = Instance.new("Attachment")
	beamTop.Name = "WaterBeamTop"
	beamTop.Position = Vector3.new(0, streamLength * 0.5, 0)
	beamTop.Parent = stream
	local beamBottom = Instance.new("Attachment")
	beamBottom.Name = "WaterBeamBottom"
	beamBottom.Position = Vector3.new(0, -streamLength * 0.5, 0)
	beamBottom.Parent = stream
	local waterBeam = Instance.new("Beam")
	waterBeam.Name = "ShowerWaterBeam"
	waterBeam.Attachment0 = beamTop
	waterBeam.Attachment1 = beamBottom
	waterBeam.Width0 = 0.055
	waterBeam.Width1 = 0.03
	waterBeam.FaceCamera = true
	waterBeam.LightEmission = 0.65
	waterBeam.Color = ColorSequence.new(Color3.fromRGB(185, 234, 251))
	waterBeam.Transparency = NumberSequence.new(0.28)
	waterBeam.Enabled = false
	waterBeam:SetAttribute("CooperShowerBeam", true)
	waterBeam.Parent = stream
end

local showerFloorSplash = makePart(
	bathroom,
	"ShowerFloorSplash",
	Vector3.new(0.055, 2.1, 1.55),
	CFrame.new(showerBoundsCFrame.Position.X, streamBottomY, showerBoundsCFrame.Position.Z)
		* CFrame.Angles(0, 0, math.rad(90)),
	Color3.fromRGB(151, 216, 241),
	Enum.Material.Glass,
	1,
	false
)
showerFloorSplash.Shape = Enum.PartType.Cylinder
showerFloorSplash.CanQuery = false
showerFloorSplash:SetAttribute("CooperShowerStream", true)
showerFloorSplash:SetAttribute("OnTransparency", 0.58)

-- Exterior water curtain + steam so the shower reads from the hallway camera
-- (frosted glass otherwise hides interior-only particles).
local exteriorOrigin = showerBoundsCFrame.Position
	- showerBoundsCFrame.LookVector * (select(2, shower:GetBoundingBox()).Z * 0.52 + 0.15)
for exteriorIndex, xOffset in ipairs({ -0.85, -0.28, 0.28, 0.85 }) do
	local exterior = makePart(
		bathroom,
		"ShowerExteriorStream" .. exteriorIndex,
		Vector3.new(0.07, streamLength * 0.92, 0.07),
		CFrame.new(
			exteriorOrigin
				+ showerBoundsCFrame.RightVector * xOffset
				+ Vector3.new(0, streamCenterY - showerBoundsCFrame.Position.Y, 0)
		),
		Color3.fromRGB(164, 225, 248),
		Enum.Material.Neon,
		1,
		false
	)
	exterior.CanQuery = false
	exterior.CastShadow = false
	exterior:SetAttribute("CooperShowerStream", true)
	exterior:SetAttribute("OnTransparency", 0.42)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, streamLength * 0.46, 0)
	top.Parent = exterior
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -streamLength * 0.46, 0)
	bottom.Parent = exterior
	local beam = Instance.new("Beam")
	beam.Name = "ShowerExteriorBeam"
	beam.Attachment0 = top
	beam.Attachment1 = bottom
	beam.Width0 = 0.09
	beam.Width1 = 0.05
	beam.FaceCamera = true
	beam.LightEmission = 0.7
	beam.Color = ColorSequence.new(Color3.fromRGB(185, 234, 251))
	beam.Transparency = NumberSequence.new(0.22)
	beam.Enabled = false
	beam:SetAttribute("CooperShowerBeam", true)
	beam.Parent = exterior
end

local showerSteamPart = makePart(
	bathroom,
	"ShowerSteamCloud",
	Vector3.new(0.4, 0.4, 0.4),
	CFrame.new(exteriorOrigin + Vector3.new(0, streamLength * 0.15, 0)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
showerSteamPart.CanQuery = false
local showerSteam = Instance.new("ParticleEmitter")
showerSteam.Name = "ShowerSteam"
showerSteam.Enabled = false
showerSteam.Texture = "rbxasset://textures/particles/smoke_main.dds"
showerSteam.Color = ColorSequence.new(Color3.fromRGB(225, 235, 240))
showerSteam.Lifetime = NumberRange.new(1.2, 2.2)
showerSteam.Speed = NumberRange.new(0.5, 1.4)
showerSteam.Rate = 28
showerSteam.SpreadAngle = Vector2.new(50, 50)
showerSteam.Acceleration = Vector3.new(0, 1.4, 0)
showerSteam.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(1, 1.8),
})
showerSteam.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})
showerSteam.Parent = showerSteamPart

local showerSound = Instance.new("Sound")
showerSound.Name = "CooperShowerWaterSound"
showerSound.SoundId = "rbxasset://sounds/impact_water.mp3"
showerSound.Volume = 0.62
showerSound.Looped = true
showerSound.RollOffMinDistance = 4
showerSound.RollOffMaxDistance = 30
showerSound.Parent = showerWaterPart

local showerStandPosition = showerThreshold.Position + Vector3.new(0, 2.75, 0)
makePart(
	bathroom,
	"ShowerUseAnchor",
	Vector3.new(0.3, 0.3, 0.3),
	CFrame.lookAt(showerStandPosition, showerStandPosition + Vector3.new(0, 0, 1)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
).CanQuery = false

local vanity = furniture:FindFirstChild("OxbloodTileBathroomVanity")
assert(vanity and vanity:IsA("Model"), "OxbloodTileBathroomVanity is missing")
local basin = vanity:FindFirstChild("CreamSinkBasin")
local tap = vanity:FindFirstChild("ChromeTap2") or vanity:FindFirstChild("ChromeTap1")
local toothbrush = vanity:FindFirstChild("Toothbrush1")
assert(basin and tap and toothbrush, "Bathroom sink or toothbrush anchors are missing")
makePrompt(basin, "CooperSinkWashPrompt", "Wash Hands", "Bathroom Sink", "SinkWash", Enum.KeyCode.E, 0.65, 8)
makePrompt(toothbrush, "CooperBrushTeethPrompt", "Brush Teeth", "Toothbrush", "BrushTeeth", Enum.KeyCode.F, 0.8, 8)
local sinkWaterPart = makePart(
	bathroom,
	"SinkWater",
	Vector3.new(0.12, 0.12, 0.12),
	CFrame.new(tap.Position + Vector3.new(0, -0.34, -0.18)),
	Color3.fromRGB(180, 225, 245),
	Enum.Material.Glass,
	1,
	false
)
local sinkEmitter = Instance.new("ParticleEmitter")
sinkEmitter.Name = "FaucetWater"
sinkEmitter.Enabled = false
sinkEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
sinkEmitter.EmissionDirection = Enum.NormalId.Bottom
sinkEmitter.Color = ColorSequence.new(Color3.fromRGB(170, 220, 245), Color3.fromRGB(230, 248, 255))
sinkEmitter.Lifetime = NumberRange.new(0.28, 0.5)
sinkEmitter.Speed = NumberRange.new(5.5, 8.2)
sinkEmitter.Rate = 140
sinkEmitter.Acceleration = Vector3.new(0, -32, 0)
sinkEmitter.SpreadAngle = Vector2.new(6, 6)
sinkEmitter.LightEmission = 0.25
sinkEmitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.05),
	NumberSequenceKeypoint.new(0.55, 0.09),
	NumberSequenceKeypoint.new(1, 0.02),
})
sinkEmitter.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(1, 0.65),
})
sinkEmitter.Parent = sinkWaterPart

local sinkSplash = Instance.new("ParticleEmitter")
sinkSplash.Name = "BasinSplash"
sinkSplash.Enabled = false
sinkSplash.Texture = "rbxasset://textures/particles/smoke_main.dds"
sinkSplash.EmissionDirection = Enum.NormalId.Top
sinkSplash.Color = ColorSequence.new(Color3.fromRGB(190, 230, 250))
sinkSplash.Lifetime = NumberRange.new(0.2, 0.4)
sinkSplash.Speed = NumberRange.new(0.6, 1.8)
sinkSplash.Rate = 35
sinkSplash.SpreadAngle = Vector2.new(55, 55)
sinkSplash.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.08),
	NumberSequenceKeypoint.new(1, 0.22),
})
sinkSplash.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(1, 1),
})
sinkSplash.Parent = sinkWaterPart

local sinkSteam = Instance.new("ParticleEmitter")
sinkSteam.Name = "SinkSteam"
sinkSteam.Enabled = false
sinkSteam.Texture = "rbxasset://textures/particles/smoke_main.dds"
sinkSteam.EmissionDirection = Enum.NormalId.Top
sinkSteam.Color = ColorSequence.new(Color3.fromRGB(230, 240, 245))
sinkSteam.Lifetime = NumberRange.new(0.9, 1.6)
sinkSteam.Speed = NumberRange.new(0.4, 1.1)
sinkSteam.Rate = 18
sinkSteam.SpreadAngle = Vector2.new(40, 40)
sinkSteam.Acceleration = Vector3.new(0, 1.2, 0)
sinkSteam.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(1, 0.85),
})
sinkSteam.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})
sinkSteam.Parent = sinkWaterPart

local sinkSound = Instance.new("Sound")
sinkSound.Name = "CooperSinkFaucetSound"
sinkSound.SoundId = "rbxasset://sounds/impact_water.mp3" -- bundled water sound; no marketplace permission dependency
sinkSound.Volume = 0.55
sinkSound.Looped = true
sinkSound.RollOffMinDistance = 3
sinkSound.RollOffMaxDistance = 24
sinkSound.Parent = sinkWaterPart
interactionRoot:SetAttribute("SinkFaucetSoundId", sinkSound.SoundId)

local sinkFlowTop = tap.Position + Vector3.new(0, -0.12, -0.18)
local sinkFlowBottom = Vector3.new(sinkFlowTop.X, basin.Position.Y + 0.04, sinkFlowTop.Z)
local sinkFlowLength = math.max(0.22, sinkFlowTop.Y - sinkFlowBottom.Y)
local sinkVisibleFlow = makePart(
	bathroom,
	"SinkVisibleFlow",
	Vector3.new(0.075, sinkFlowLength, 0.075),
	CFrame.new((sinkFlowTop + sinkFlowBottom) * 0.5),
	Color3.fromRGB(157, 224, 249),
	Enum.Material.Neon,
	1,
	false
)
sinkVisibleFlow.CanQuery = false
sinkVisibleFlow:SetAttribute("CooperSinkFlow", true)
sinkVisibleFlow:SetAttribute("OnTransparency", 0.22)
local sinkBeamTop = Instance.new("Attachment")
sinkBeamTop.Name = "WaterBeamTop"
sinkBeamTop.Position = Vector3.new(0, sinkFlowLength * 0.5, 0)
sinkBeamTop.Parent = sinkVisibleFlow
local sinkBeamBottom = Instance.new("Attachment")
sinkBeamBottom.Name = "WaterBeamBottom"
sinkBeamBottom.Position = Vector3.new(0, -sinkFlowLength * 0.5, 0)
sinkBeamBottom.Parent = sinkVisibleFlow
local sinkBeam = Instance.new("Beam")
sinkBeam.Name = "SinkWaterBeam"
sinkBeam.Attachment0 = sinkBeamTop
sinkBeam.Attachment1 = sinkBeamBottom
sinkBeam.Width0 = 0.085
sinkBeam.Width1 = 0.055
sinkBeam.FaceCamera = true
sinkBeam.LightEmission = 0.7
sinkBeam.Color = ColorSequence.new(Color3.fromRGB(184, 235, 252))
sinkBeam.Transparency = NumberSequence.new(0.18)
sinkBeam.Enabled = false
sinkBeam:SetAttribute("CooperSinkBeam", true)
sinkBeam.Parent = sinkVisibleFlow

local sinkBasinGlow = makePart(
	bathroom,
	"SinkBasinWaterGlow",
	Vector3.new(1.15, 0.035, 0.76),
	CFrame.new(basin.Position + Vector3.new(0, 0.14, 0)),
	Color3.fromRGB(139, 211, 239),
	Enum.Material.Glass,
	1,
	false
)
sinkBasinGlow.CanQuery = false
sinkBasinGlow:SetAttribute("CooperSinkFlow", true)
sinkBasinGlow:SetAttribute("OnTransparency", 0.48)
local foamPart = makePart(
	bathroom,
	"ToothbrushFoam",
	Vector3.new(0.1, 0.1, 0.1),
	CFrame.new(toothbrush.Position + Vector3.new(0, 0.35, 0)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
local foamEmitter = Instance.new("ParticleEmitter")
foamEmitter.Name = "Foam"
foamEmitter.Enabled = false
foamEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
foamEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
foamEmitter.Lifetime = NumberRange.new(0.35, 0.65)
foamEmitter.Speed = NumberRange.new(0.2, 0.8)
foamEmitter.Rate = 16
foamEmitter.SpreadAngle = Vector2.new(30, 30)
foamEmitter.Size = NumberSequence.new(0.1)
foamEmitter.Parent = foamPart

local sinkStandPosition = basin.Position + Vector3.new(0, -0.45, -2.35)
makePart(
	bathroom,
	"SinkUseAnchor",
	Vector3.new(0.3, 0.3, 0.3),
	CFrame.lookAt(sinkStandPosition, Vector3.new(basin.Position.X, sinkStandPosition.Y, basin.Position.Z)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
).CanQuery = false

-- Computer ------------------------------------------------------------------

local computer = sharedRoom:FindFirstChild("Sheldon1980sComputerDesk")
assert(computer and computer:IsA("Model"), "Sheldon1980sComputerDesk is missing")
local keyboard = computer:FindFirstChild("Keyboard")
assert(keyboard and keyboard:IsA("BasePart"), "Sheldon's keyboard is missing")
makePrompt(keyboard, "CooperComputerPrompt", "Use Computer", "Sheldon's 1980s Computer", "Computer", Enum.KeyCode.E, 0.4, 9)

-- Refrigerator with a hinged decorated door and beer inventory --------------

local refrigerator = furniture:FindFirstChild("WhiteHotpointRefrigerator")
assert(refrigerator and refrigerator:IsA("Model"), "WhiteHotpointRefrigerator is missing")
local refrigeratorBody = refrigerator:FindFirstChild("RefrigeratorBody")
assert(refrigeratorBody and refrigeratorBody:IsA("BasePart"), "RefrigeratorBody is missing")
if refrigerator:GetAttribute("CooperBeerCount") == nil then
	refrigerator:SetAttribute("CooperBeerCount", 6)
end

-- Face the clearest kitchen aisle before building the hinged door. The stock
-- placement aimed the door into FormalKitchenDivider (~0.6 stud gap).
do
	local orientParams = RaycastParams.new()
	orientParams.FilterType = Enum.RaycastFilterType.Exclude
	orientParams.FilterDescendantsInstances = { refrigerator, interactionRoot }
	local bestDir = refrigeratorBody.CFrame.LookVector
	local bestDist = -1
	for _, dir in ipairs({
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1),
	}) do
		local origin = refrigeratorBody.Position + dir * (math.max(refrigeratorBody.Size.X, refrigeratorBody.Size.Z) * 0.5 + 0.2)
		local hit = workspace:Raycast(origin, dir * 16, orientParams)
		local dist = hit and (hit.Position - origin).Magnitude or 16
		if dist > bestDist then
			bestDist = dist
			bestDir = dir
		end
	end
	if bestDir:Dot(refrigeratorBody.CFrame.LookVector) < 0.95 then
		local pivot = refrigerator:GetPivot()
		refrigerator:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + bestDir, Vector3.yAxis))
		refrigeratorBody = refrigerator:FindFirstChild("RefrigeratorBody") :: BasePart
		refrigerator:SetAttribute("CooperFridgeReoriented", true)
		refrigerator:SetAttribute("CooperFridgeFacingClearance", bestDist)
	end
end

local doorAssembly = refrigerator:FindFirstChild("CooperFridgeDoorAssembly")
if doorAssembly then
	for _, child in ipairs(doorAssembly:GetChildren()) do
		if child:IsA("BasePart")
			and child.Name ~= "FridgeDoorHinge"
			and child.Name ~= "FridgeDoorPanel"
		then
			local oldWeld = child:FindFirstChild("CooperDoorWeld")
			if oldWeld then
				oldWeld:Destroy()
			end
			child.Anchored = true
			child.Parent = refrigerator
		end
	end
	doorAssembly:Destroy()
end
doorAssembly = Instance.new("Model")
doorAssembly.Name = "CooperFridgeDoorAssembly"
doorAssembly.Parent = refrigerator

local frontOffset = -refrigeratorBody.Size.Z * 0.5 - 0.16
local bodyRight = refrigeratorBody.CFrame.RightVector
local clearanceRayLength = 12
local clearanceParams = RaycastParams.new()
clearanceParams.FilterType = Enum.RaycastFilterType.Exclude
clearanceParams.FilterDescendantsInstances = { refrigerator, interactionRoot }
local function sideClearance(direction)
	local rayOrigin = refrigeratorBody.Position
		+ direction * (refrigeratorBody.Size.X * 0.5 + 0.08)
	local hit = workspace:Raycast(rayOrigin, direction * clearanceRayLength, clearanceParams)
	return hit and (hit.Position - rayOrigin).Magnitude or clearanceRayLength
end
local positiveSideClearance = sideClearance(bodyRight)
local negativeSideClearance = sideClearance(-bodyRight)
-- Put the hinge beside the obstruction, exactly as a wall-adjacent refrigerator
-- is installed in real life. This keeps the free/handle edge on the open side of
-- the kitchen instead of trapping it against the wall.
local hingeSide = positiveSideClearance <= negativeSideClearance and 1 or -1
local hingeCFrame = refrigeratorBody.CFrame
	* CFrame.new(hingeSide * (refrigeratorBody.Size.X * 0.5 - 0.11), 0, frontOffset)
local doorHinge = makePart(
	doorAssembly,
	"FridgeDoorHinge",
	Vector3.new(0.16, refrigeratorBody.Size.Y - 0.3, 0.16),
	hingeCFrame,
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
doorHinge.Anchored = true
local closedCFrame = hingeCFrame
doorHinge:SetAttribute("ClosedCFrame", closedCFrame)
doorHinge:SetAttribute("DerivedHingeSide", hingeSide)
doorHinge:SetAttribute("PositiveSideClearance", positiveSideClearance)
doorHinge:SetAttribute("NegativeSideClearance", negativeSideClearance)
doorHinge.CFrame = closedCFrame

local doorPanel = makePart(
	doorAssembly,
	"FridgeDoorPanel",
	Vector3.new(refrigeratorBody.Size.X - 0.2, refrigeratorBody.Size.Y - 0.35, 0.28),
	refrigeratorBody.CFrame * CFrame.new(0, 0, frontOffset),
	Color3.fromRGB(226, 222, 207),
	Enum.Material.SmoothPlastic,
	0,
	true
)

-- Choose the swing sign that opens into the kitchen aisle (toward LookVector)
-- with the fewest colliding parts.
local panelEdgeA = doorPanel.Position + doorPanel.CFrame.RightVector * (doorPanel.Size.X * 0.5)
local panelEdgeB = doorPanel.Position - doorPanel.CFrame.RightVector * (doorPanel.Size.X * 0.5)
local closedFreeEdge = if (panelEdgeA - doorHinge.Position).Magnitude >= (panelEdgeB - doorHinge.Position).Magnitude
	then panelEdgeA
	else panelEdgeB
local freeEdgeInHingeSpace = closedCFrame:PointToObjectSpace(closedFreeEdge)
local openAngleMagnitude = 78
local panelRel = closedCFrame:ToObjectSpace(doorPanel.CFrame)
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.FilterDescendantsInstances = { refrigerator, interactionRoot }
local function openScore(degrees)
	local openCF = closedCFrame * CFrame.Angles(0, math.rad(degrees), 0)
	local freeEdge = openCF:PointToWorldSpace(freeEdgeInHingeSpace)
	local towardPlayer = (freeEdge - refrigeratorBody.Position):Dot(refrigeratorBody.CFrame.LookVector)
	local openPanelCF = openCF * panelRel
	local collideCount = 0
	for _, hit in ipairs(workspace:GetPartBoundsInBox(openPanelCF, doorPanel.Size * 0.9, overlapParams)) do
		if hit.CanCollide then
			collideCount += 1
		end
	end
	return towardPlayer * 10 - collideCount * 25
end
local positiveScore = openScore(openAngleMagnitude)
local negativeScore = openScore(-openAngleMagnitude)
local derivedOpenAngle = positiveScore >= negativeScore and openAngleMagnitude or -openAngleMagnitude
doorHinge:SetAttribute("OpenAngleMagnitude", openAngleMagnitude)
doorHinge:SetAttribute("DerivedOpenAngleDegrees", derivedOpenAngle)
doorHinge:SetAttribute("SwingDirectionDerivedFromGeometry", true)

local decorationNames = {
	ChromeHandle = true,
	FreezerSeam = true,
	MarysGroceryList = true,
	BathroomSchedule = true,
}
for _, child in ipairs(refrigerator:GetChildren()) do
	if child:IsA("BasePart")
		and (decorationNames[child.Name] or string.sub(child.Name, 1, 14) == "SouvenirMagnet")
	then
		child.Parent = doorAssembly
	end
end

for _, part in ipairs(doorAssembly:GetChildren()) do
	if part:IsA("BasePart") and part ~= doorHinge then
		if part.Name == "ChromeHandle" then
			local localHandleCFrame = refrigeratorBody.CFrame:ToObjectSpace(part.CFrame)
			local localRotation = localHandleCFrame - localHandleCFrame.Position
			part.CFrame = refrigeratorBody.CFrame
				* CFrame.new(
					-hingeSide * math.abs(localHandleCFrame.Position.X),
					localHandleCFrame.Position.Y,
					localHandleCFrame.Position.Z
				)
				* localRotation
		end
		if part ~= doorPanel and part:GetAttribute("CooperDoorDecorMoved") ~= true then
			part.CFrame = part.CFrame + refrigeratorBody.CFrame.LookVector * 0.34
			part:SetAttribute("CooperDoorDecorMoved", true)
		end
		-- The runtime controller pivots the complete anchored door model. This is
		-- deterministic in Studio and does not depend on physics welds surviving
		-- installation or streaming.
		part.Anchored = true
		part.Massless = false
		part.CanCollide = part == doorPanel
		local oldWeld = part:FindFirstChild("CooperDoorWeld")
		if oldWeld then
			oldWeld:Destroy()
		end
	end
end
doorAssembly.PrimaryPart = doorHinge
makePrompt(doorHinge, "CooperFridgeTogglePrompt", "Open Fridge", "Hotpoint Refrigerator", "FridgeToggle", Enum.KeyCode.E, 0.25, 10)

local oldInterior = refrigerator:FindFirstChild("CooperFridgeInterior")
if oldInterior then
	oldInterior:Destroy()
end
local fridgeInterior = Instance.new("Model")
fridgeInterior.Name = "CooperFridgeInterior"
fridgeInterior.Parent = refrigerator
local interiorDepth = -refrigeratorBody.Size.Z * 0.5 - 0.035
makePart(
	fridgeInterior,
	"DarkInterior",
	Vector3.new(refrigeratorBody.Size.X - 0.5, refrigeratorBody.Size.Y - 0.72, 0.13),
	refrigeratorBody.CFrame * CFrame.new(0, -0.02, interiorDepth),
	Color3.fromRGB(49, 55, 54),
	Enum.Material.SmoothPlastic,
	0,
	false
)
for index, y in ipairs({ -2.25, -0.9, 0.5, 1.85 }) do
	makePart(
		fridgeInterior,
		"Shelf" .. index,
		Vector3.new(refrigeratorBody.Size.X - 0.65, 0.09, 0.18),
		refrigeratorBody.CFrame * CFrame.new(0, y, interiorDepth - 0.02),
		Color3.fromRGB(190, 199, 194),
		Enum.Material.Metal,
		0.08,
		false
	)
end

for index = 1, 6 do
	local x = -1.38 + (index - 1) * 0.54
	local bottleCFrame = refrigeratorBody.CFrame
		* CFrame.new(x, -1.83, -refrigeratorBody.Size.Z * 0.5 - 0.13)
		* CFrame.Angles(0, 0, math.rad(90))
	local body = makePart(
		fridgeInterior,
		string.format("BeerBottle%02d_Body", index),
		Vector3.new(0.72, 0.3, 0.3),
		bottleCFrame,
		Color3.fromRGB(83, 51, 28),
		Enum.Material.Glass,
		0.08,
		false
	)
	body.Shape = Enum.PartType.Cylinder
	body:SetAttribute("BeerVisualIndex", index)
	body:SetAttribute("VisibleTransparency", body.Transparency)
	local neck = makePart(
		fridgeInterior,
		string.format("BeerBottle%02d_Neck", index),
		Vector3.new(0.28, 0.16, 0.16),
		bottleCFrame * CFrame.new(0.48, 0, 0),
		Color3.fromRGB(79, 48, 26),
		Enum.Material.Glass,
		0.06,
		false
	)
	neck.Shape = Enum.PartType.Cylinder
	neck:SetAttribute("BeerVisualIndex", index)
	neck:SetAttribute("VisibleTransparency", neck.Transparency)
	local cap = makePart(
		fridgeInterior,
		string.format("BeerBottle%02d_Cap", index),
		Vector3.new(0.10, 0.18, 0.18),
		bottleCFrame * CFrame.new(0.67, 0, 0),
		Color3.fromRGB(194, 37, 39),
		Enum.Material.Metal,
		0,
		false
	)
	cap.Shape = Enum.PartType.Cylinder
	cap:SetAttribute("BeerVisualIndex", index)
	cap:SetAttribute("VisibleTransparency", cap.Transparency)
	local labelBand = makePart(
		fridgeInterior,
		string.format("BeerBottle%02d_Label", index),
		Vector3.new(0.28, 0.315, 0.315),
		bottleCFrame * CFrame.new(-0.04, 0, 0),
		Color3.fromRGB(211, 42, 43),
		Enum.Material.SmoothPlastic,
		0,
		false
	)
	labelBand.Shape = Enum.PartType.Cylinder
	labelBand:SetAttribute("BeerVisualIndex", index)
	labelBand:SetAttribute("VisibleTransparency", labelBand.Transparency)
end

local beerPromptAnchor = makePart(
	fridgeInterior,
	"BeerPromptAnchor",
	Vector3.new(refrigeratorBody.Size.X - 0.4, 4.8, 0.25),
	refrigeratorBody.CFrame * CFrame.new(0, -0.5, -refrigeratorBody.Size.Z * 0.5 - 0.72),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
local beerPrompt = makePrompt(beerPromptAnchor, "CooperFridgeBeerPrompt", "Store / Take Beer", "Lone Star Beer (6)", "FridgeBeer", Enum.KeyCode.F, 0.35, 10)
beerPrompt.Enabled = false

-- Commit the staged world model only after every required interaction was
-- successfully built.
if oldRoot then
	oldRoot:Destroy()
end
interactionRoot.Name = "CooperInteractions"

-- Remotes and runtime source targets ----------------------------------------

local remoteFolder = getOrCreate(ReplicatedStorage, "Folder", "CooperInteractionsRemotes")
getOrCreate(remoteFolder, "RemoteEvent", "Request")
getOrCreate(remoteFolder, "RemoteEvent", "Client")

serverScript = getOrCreate(ServerScriptService, "Script", "CooperInteractions")
serverScript:SetAttribute("SourceFile", "CooperInteractions.server.luau")
local serverHasSource = #serverScript.Source > 500
	and not string.find(serverScript.Source, "Source is installed from", 1, true)
if not serverHasSource then
	serverScript.Disabled = true
	serverScript:SetAttribute("InstallState", "AwaitingSource")
	serverScript.Source = "-- Source is installed from CooperInteractions.server.luau"
else
	serverScript:SetAttribute("InstallState", "Ready")
	serverScript.Disabled = false
end

clientScript = getOrCreate(starterScripts, "LocalScript", "CooperInteractions")
clientScript:SetAttribute("SourceFile", "CooperInteractions.client.luau")
local clientHasSource = #clientScript.Source > 500
	and not string.find(clientScript.Source, "Source is installed from", 1, true)
if not clientHasSource then
	clientScript.Disabled = true
	clientScript:SetAttribute("InstallState", "AwaitingSource")
	clientScript.Source = "-- Source is installed from CooperInteractions.client.luau"
else
	clientScript:SetAttribute("InstallState", "Ready")
	clientScript.Disabled = false
end

ChangeHistoryService:SetWaypoint("Installed Cooper interior interactions")
print("[CooperInteractionsInstaller] Installed world objects, prompts, effects, remotes, and runtime targets")
if not serverHasSource or not clientHasSource then
	warn("[CooperInteractionsInstaller] Companion source is still required for one or more new runtime scripts")
end
