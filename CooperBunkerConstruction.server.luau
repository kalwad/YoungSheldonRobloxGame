-- Server-authoritative, timestamp-resumable construction presentation for
-- secretbunker.underground. The economy/profile script owns purchases and
-- deadlines; this controller owns only the shared-world spectacle.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CONTROLLER_VERSION = "1.0.0"
local DEFAULT_DURATION = 45
local RUNTIME_NAME = "BunkerConstructionRuntime"
local COVER_NAME = "BunkerGrassCover"
local VIEWING_ANCHOR_NAME = "BunkerConstructionViewingAnchor"
local ASSET_ROOT_NAME = "CooperBunkerConstructionAssets"

local ORIGINAL_TRANSPARENCY = "BunkerConstructionOriginalTransparency"
local ORIGINAL_CAN_COLLIDE = "BunkerConstructionOriginalCanCollide"
local ORIGINAL_CAN_TOUCH = "BunkerConstructionOriginalCanTouch"
local ORIGINAL_CAN_QUERY = "BunkerConstructionOriginalCanQuery"
local ORIGINAL_CAST_SHADOW = "BunkerConstructionOriginalCastShadow"
local ORIGINAL_ENABLED = "BunkerConstructionOriginalEnabled"
local ORIGINAL_RATE = "BunkerConstructionOriginalRate"
local RUNTIME_TRANSPARENCY = "ConstructionRuntimeOriginalTransparency"
local RUNTIME_ENABLED = "ConstructionRuntimeOriginalEnabled"
local WORK_POSE_CLEARANCE = 1.75

local REQUIRED_MACHINE_NAMES = {
	"DumpTruck",
	"Excavator",
	"SkidSteer",
	"MobileCrane",
}

local REQUIRED_EFFECT_NAMES = {
	"DustEmitterTemplate",
	"GroundDustEmitterTemplate",
	"ExhaustSmokeEmitterTemplate",
}

local environment = Workspace:WaitForChild("CooperHouseEnvironment")
local site = environment:WaitForChild("SiteAndStreet")
local lot = site:WaitForChild("CooperLot")
local bunker = environment:WaitForChild("BackyardBunker")
local surface = bunker:WaitForChild("SurfaceEntrance")
local shaftOpening = surface:WaitForChild("ShaftOpening")
local hatchDoor = surface:WaitForChild("HatchDoor")
local hatchPanel = hatchDoor:WaitForChild("Panel")
local assetRoot = ServerStorage:WaitForChild(ASSET_ROOT_NAME)
local serverEvents = ServerScriptService:WaitForChild("CooperGameServerEvents")
local requestBunkerConstruction = serverEvents:WaitForChild("RequestBunkerConstruction")

assert(environment:IsA("Model"), "CooperHouseEnvironment must be a Model")
assert(site:IsA("Model"), "CooperHouseEnvironment.SiteAndStreet must be a Model")
assert(lot:IsA("BasePart"), "SiteAndStreet.CooperLot must be a BasePart")
assert(bunker:IsA("Model"), "CooperHouseEnvironment.BackyardBunker must be a Model")
assert(surface:IsA("Model"), "BackyardBunker.SurfaceEntrance must be a Model")
assert(shaftOpening:IsA("BasePart"), "SurfaceEntrance.ShaftOpening must be a BasePart")
assert(hatchDoor:IsA("Model"), "SurfaceEntrance.HatchDoor must be a Model")
assert(hatchPanel:IsA("BasePart"), "HatchDoor.Panel must be a BasePart")
assert(assetRoot:IsA("Folder"), ASSET_ROOT_NAME .. " must be a Folder")
assert(requestBunkerConstruction:IsA("BindableEvent"), "RequestBunkerConstruction must be a BindableEvent")

local protectedSurfaceChildren = {
	PhysicalAccess = true,
	ShaftOpening = true,
	BunkerGrassCover = true,
	BunkerAccessGate = true,
}

local activeSession = nil
local activeRequestKey = nil
local processedRequestKeys = {}
local worldUnlocked = bunker:GetAttribute("UnlockState") == "Unlocked"
local writingUnlockState = false
local lastFailureWarningClock = -math.huge
local unixAtClockOrigin = os.time()
local clockOrigin = time()
local stageForElapsed

local function smoothstep(value)
	local alpha = math.clamp(value, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function currentUnix()
	return unixAtClockOrigin + (time() - clockOrigin)
end

local function storeAttributeOnce(instance, attributeName, value)
	if instance:GetAttribute(attributeName) == nil then
		instance:SetAttribute(attributeName, value)
	end
end

local function isAccessGate(instance)
	local cursor = instance
	while cursor and cursor ~= surface do
		if cursor.Name == "BunkerAccessGate"
			or cursor:GetAttribute("BunkerAccessGate") == true
		then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

local function eachSurfaceRevealInstance(callback)
	for _, surfaceChild in ipairs(surface:GetChildren()) do
		if not protectedSurfaceChildren[surfaceChild.Name]
			and surfaceChild:GetAttribute("BunkerAccessGate") ~= true
		then
			callback(surfaceChild)
			for _, descendant in ipairs(surfaceChild:GetDescendants()) do
				callback(descendant)
			end
		end
	end
end

local function concealSurfaceInstance(instance)
	if isAccessGate(instance) then
		return
	end
	if instance:IsA("BasePart") then
		storeAttributeOnce(instance, ORIGINAL_TRANSPARENCY, instance.Transparency)
		storeAttributeOnce(instance, ORIGINAL_CAN_COLLIDE, instance.CanCollide)
		storeAttributeOnce(instance, ORIGINAL_CAN_TOUCH, instance.CanTouch)
		storeAttributeOnce(instance, ORIGINAL_CAN_QUERY, instance.CanQuery)
		storeAttributeOnce(instance, ORIGINAL_CAST_SHADOW, instance.CastShadow)
		instance.Transparency = 1
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.CastShadow = false
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		storeAttributeOnce(instance, ORIGINAL_TRANSPARENCY, instance.Transparency)
		instance.Transparency = 1
	elseif instance:IsA("Light")
		or instance:IsA("SurfaceGui")
		or instance:IsA("BillboardGui")
		or instance:IsA("ProximityPrompt")
	then
		storeAttributeOnce(instance, ORIGINAL_ENABLED, instance.Enabled)
		instance.Enabled = false
	elseif instance:IsA("ParticleEmitter") then
		storeAttributeOnce(instance, ORIGINAL_ENABLED, instance.Enabled)
		storeAttributeOnce(instance, ORIGINAL_RATE, instance.Rate)
		instance.Enabled = false
		instance.Rate = 0
	end
end

local function restoreBooleanAttribute(instance, attributeName, fallback)
	local value = instance:GetAttribute(attributeName)
	return if type(value) == "boolean" then value else fallback
end

local function restoreNumberAttribute(instance, attributeName, fallback)
	local value = instance:GetAttribute(attributeName)
	return if type(value) == "number" then value else fallback
end

local function restoreSurfaceInstance(instance, allowInteraction)
	if isAccessGate(instance) then
		return
	end
	if instance:IsA("BasePart") then
		instance.Transparency = restoreNumberAttribute(instance, ORIGINAL_TRANSPARENCY, instance.Transparency)
		instance.CanCollide = allowInteraction
			and restoreBooleanAttribute(instance, ORIGINAL_CAN_COLLIDE, instance.CanCollide)
			or false
		instance.CanTouch = allowInteraction
			and restoreBooleanAttribute(instance, ORIGINAL_CAN_TOUCH, instance.CanTouch)
			or false
		instance.CanQuery = allowInteraction
			and restoreBooleanAttribute(instance, ORIGINAL_CAN_QUERY, instance.CanQuery)
			or false
		instance.CastShadow = restoreBooleanAttribute(instance, ORIGINAL_CAST_SHADOW, instance.CastShadow)
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Transparency = restoreNumberAttribute(instance, ORIGINAL_TRANSPARENCY, instance.Transparency)
	elseif instance:IsA("ProximityPrompt") then
		instance.Enabled = allowInteraction
			and restoreBooleanAttribute(instance, ORIGINAL_ENABLED, instance.Enabled)
			or false
	elseif instance:IsA("Light")
		or instance:IsA("SurfaceGui")
		or instance:IsA("BillboardGui")
	then
		instance.Enabled = restoreBooleanAttribute(instance, ORIGINAL_ENABLED, instance.Enabled)
	elseif instance:IsA("ParticleEmitter") then
		instance.Rate = restoreNumberAttribute(instance, ORIGINAL_RATE, instance.Rate)
		instance.Enabled = restoreBooleanAttribute(instance, ORIGINAL_ENABLED, instance.Enabled)
	end
end

local function concealSurface()
	eachSurfaceRevealInstance(concealSurfaceInstance)
end

local function restoreSurface(allowInteraction)
	eachSurfaceRevealInstance(function(instance)
		restoreSurfaceInstance(instance, allowInteraction)
	end)
end

local function ensureClosedHatchSupport()
	-- Construction begins from the saved edit-mode closed pose, and all hatch
	-- interaction stays disabled until completion. Do not PivotTo the raw
	-- ClosedPivot attribute here: CooperBunker rebases that world-space
	-- metadata after a moved-environment repair, and script startup ordering is
	-- intentionally unspecified.
	bunker:SetAttribute("HatchOpen", false)
	hatchDoor:SetAttribute("IsOpen", false)
	hatchPanel.CanCollide = restoreBooleanAttribute(hatchPanel, ORIGINAL_CAN_COLLIDE, true)
	hatchPanel.CanTouch = restoreBooleanAttribute(hatchPanel, ORIGINAL_CAN_TOUCH, false)
	hatchPanel.CanQuery = restoreBooleanAttribute(hatchPanel, ORIGINAL_CAN_QUERY, true)
end

local function ensureGrassCover()
	local existing = bunker:FindFirstChild(COVER_NAME)
	if existing and not existing:IsA("BasePart") then
		existing:Destroy()
		existing = nil
	end
	local cover = existing
	if not cover then
		cover = Instance.new("Part")
		cover.Name = COVER_NAME
		cover.Parent = bunker
	end

	local cutterSize = lot:GetAttribute("BunkerShaftSize")
	if typeof(cutterSize) ~= "Vector3" then
		cutterSize = Vector3.new(6.55, 8, 6.15)
	end
	local localShaft = lot.CFrame:PointToObjectSpace(shaftOpening.Position)
	cover.Size = Vector3.new(cutterSize.X, lot.Size.Y, cutterSize.Z)
	cover.CFrame = lot.CFrame * CFrame.new(localShaft.X, 0, localShaft.Z)
	cover.Anchored = true
	cover.CanTouch = false
	cover.Material = Enum.Material.Grass
	cover.Color = lot.Color
	cover.TopSurface = Enum.SurfaceType.Smooth
	cover.BottomSurface = Enum.SurfaceType.Smooth
	cover:SetAttribute("BunkerConstructionCover", true)
	cover:SetAttribute("ConstructionRole", COVER_NAME)
	cover:SetAttribute("TrikeGroundSurface", true)
	cover:SetAttribute("ConstructionSafetySupport", true)
	return cover
end

local function setCoverEnabled(enabled)
	local cover = ensureGrassCover()
	cover.Transparency = if enabled then 0 else 1
	cover.CanCollide = enabled
	cover.CanQuery = enabled
	cover.CanTouch = false
	cover.CastShadow = enabled
end

local function ensureViewingAnchor()
	local existing = environment:FindFirstChild(VIEWING_ANCHOR_NAME)
	if existing and not existing:IsA("BasePart") then
		existing:Destroy()
		existing = nil
	end
	local anchor = existing
	if not anchor then
		anchor = Instance.new("Part")
		anchor.Name = VIEWING_ANCHOR_NAME
		anchor.Parent = environment
	end
	local viewPlan = shaftOpening.CFrame:PointToWorldSpace(Vector3.new(-18, 0, 0.15))
	local localView = lot.CFrame:PointToObjectSpace(viewPlan)
	anchor.Size = Vector3.new(0.3, 0.3, 0.3)
	anchor.CFrame = lot.CFrame
		* CFrame.new(localView.X, lot.Size.Y * 0.5 + anchor.Size.Y * 0.5, localView.Z)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor:SetAttribute("BunkerConstructionViewingAnchor", true)
	return anchor
end

local function setUnlockState(stateName)
	if worldUnlocked and stateName ~= "Unlocked" then
		return
	end
	writingUnlockState = true
	bunker:SetAttribute("UnlockState", stateName)
	writingUnlockState = false
end

local function publishStage(stageName, progress)
	local clampedProgress = math.clamp(progress, 0, 1)
	bunker:SetAttribute("ConstructionStage", stageName)
	bunker:SetAttribute("ConstructionProgress", clampedProgress)
	if activeSession and activeSession.root then
		activeSession.root:SetAttribute("ConstructionStage", stageName)
		activeSession.root:SetAttribute("ConstructionProgress", clampedProgress)
	end
end

local function groundPointFromOffset(offset)
	local planPoint = shaftOpening.CFrame:PointToWorldSpace(Vector3.new(offset.X, 0, offset.Z))
	local localPoint = lot.CFrame:PointToObjectSpace(planPoint)
	return lot.CFrame:PointToWorldSpace(Vector3.new(localPoint.X, lot.Size.Y * 0.5, localPoint.Z))
end

local function makeRuntimePart(parent, name, size, cframe, options)
	options = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = options.canCollide == true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = options.castShadow ~= false
	part.Transparency = options.transparency or 0
	part.Color = options.color or Color3.fromRGB(225, 132, 35)
	part.Material = options.material or Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function frameBetween(pointA, pointB, verticalOffset)
	local up = lot.CFrame.UpVector
	local startPoint = pointA + up * verticalOffset
	local endPoint = pointB + up * verticalOffset
	return CFrame.lookAt((startPoint + endPoint) * 0.5, endPoint, up)
end

local function addBarrierLine(parent, name, offsetA, offsetB)
	local pointA = groundPointFromOffset(offsetA)
	local pointB = groundPointFromOffset(offsetB)
	local length = (pointB - pointA).Magnitude
	local up = lot.CFrame.UpVector

	local blocker = makeRuntimePart(
		parent,
		name .. "SafetyCollider",
		Vector3.new(0.28, 4.2, length),
		frameBetween(pointA, pointB, 2.1),
		{
			canCollide = true,
			transparency = 1,
			castShadow = false,
		}
	)
	blocker:SetAttribute("ConstructionSafetyPerimeter", true)

	for index, point in ipairs({ pointA, pointB }) do
		local post = makeRuntimePart(
			parent,
			name .. "Post" .. tostring(index),
			Vector3.new(0.42, 2.6, 0.42),
			CFrame.new(point + up * 1.3),
			{
				canCollide = true,
				color = Color3.fromRGB(236, 139, 31),
				material = Enum.Material.Metal,
			}
		)
		post:SetAttribute("ConstructionSafetyPerimeter", true)
	end

	for railIndex, height in ipairs({ 0.85, 1.75 }) do
		local rail = makeRuntimePart(
			parent,
			name .. "Rail" .. tostring(railIndex),
			Vector3.new(0.22, 0.32, length),
			frameBetween(pointA, pointB, height),
			{
				canCollide = true,
				color = if railIndex % 2 == 0
					then Color3.fromRGB(245, 237, 207)
					else Color3.fromRGB(224, 116, 26),
				material = Enum.Material.SmoothPlastic,
			}
		)
		rail:SetAttribute("ConstructionSafetyPerimeter", true)
	end
end

local function addConstructionSign(parent)
	local up = lot.CFrame.UpVector
	-- Keep this as a compact notice mounted at the southeast perimeter edge,
	-- not a billboard in the player's view of the machinery.
	local center = groundPointFromOffset(Vector3.new(9.4, 0, -10.12))
	local lookTarget = groundPointFromOffset(Vector3.new(9.4, 0, -9.12))
	local sign = makeRuntimePart(
		parent,
		"AuthorizedConstructionSign",
		Vector3.new(3.3, 0.78, 0.14),
		CFrame.lookAt(center + up * 1.34, lookTarget + up * 1.34, up),
		{
			canCollide = false,
			color = Color3.fromRGB(34, 38, 39),
			material = Enum.Material.Metal,
		}
	)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "HorizontalConstructionNotice"
		gui.Face = face
		gui.PixelsPerStud = 44
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.LightInfluence = 0.15
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Name = "Notice"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = table.concat({
			"AUTHORIZED CONSTRUCTION",
			"KEEP CLEAR",
		}, string.char(10))
		label.TextColor3 = Color3.fromRGB(255, 188, 68)
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = gui
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = 7
		constraint.MaxTextSize = 16
		constraint.Parent = label
	end
end

local function buildSafetyPerimeter(runtimeRoot)
	local perimeter = Instance.new("Model")
	perimeter.Name = "ConstructionSafetyPerimeter"
	perimeter:SetAttribute("ConstructionSafetyPerimeter", true)
	perimeter.Parent = runtimeRoot
	-- Leave a deliberate northwest equipment gate. The convoy comes around
	-- the rear of Georgie's garage from the existing side driveway.
	addBarrierLine(perimeter, "West", Vector3.new(-12, 0, -10), Vector3.new(-12, 0, 4))
	addBarrierLine(perimeter, "South", Vector3.new(-12, 0, -10), Vector3.new(12, 0, -10))
	addBarrierLine(perimeter, "North", Vector3.new(4, 0, 10), Vector3.new(12, 0, 10))
	addBarrierLine(perimeter, "East", Vector3.new(12, 0, -10), Vector3.new(12, 0, 10))
	addConstructionSign(perimeter)
	return perimeter
end

local function setRuntimeOriginals(machine)
	for _, descendant in ipairs(machine:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			storeAttributeOnce(descendant, RUNTIME_TRANSPARENCY, descendant.Transparency)
			descendant.Transparency = 1
		elseif descendant:IsA("Light") then
			storeAttributeOnce(descendant, RUNTIME_ENABLED, descendant.Enabled)
			descendant.Enabled = false
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			storeAttributeOnce(descendant, RUNTIME_ENABLED, descendant.Enabled)
			descendant.Enabled = false
		end
	end
end

local function setMachineVisible(machine, visible)
	for _, descendant in ipairs(machine:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if visible
				then restoreNumberAttribute(descendant, RUNTIME_TRANSPARENCY, descendant.Transparency)
				else 1
		elseif descendant:IsA("Light") then
			descendant.Enabled = visible
				and restoreBooleanAttribute(descendant, RUNTIME_ENABLED, false)
				or false
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
				and restoreBooleanAttribute(descendant, RUNTIME_ENABLED, false)
				or false
		elseif descendant:IsA("ParticleEmitter") and not visible then
			descendant.Enabled = false
			descendant.Rate = 0
		end
	end
	machine:SetAttribute("ConstructionVisible", visible)
end

local function setSubmodelVisible(machine, modelName, visible)
	local submodel = machine:FindFirstChild(modelName, true)
	if not submodel or not submodel:IsA("Model") then
		return
	end
	for _, descendant in ipairs(submodel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if visible
				then restoreNumberAttribute(descendant, RUNTIME_TRANSPARENCY, descendant.Transparency)
				else 1
		elseif descendant:IsA("Light") then
			descendant.Enabled = visible
				and restoreBooleanAttribute(descendant, RUNTIME_ENABLED, false)
				or false
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
				and restoreBooleanAttribute(descendant, RUNTIME_ENABLED, false)
				or false
		elseif descendant:IsA("ParticleEmitter") and not visible then
			descendant.Enabled = false
			descendant.Rate = 0
		end
	end
end

local function validateConstructionAssets()
	if assetRoot:GetAttribute("Ready") ~= true then
		return false, ASSET_ROOT_NAME .. " is not marked Ready"
	end
	for _, machineName in ipairs(REQUIRED_MACHINE_NAMES) do
		local template = assetRoot:FindFirstChild(machineName)
		if not template or not template:IsA("Model") or not template.PrimaryPart then
			return false, string.format("%s.%s is missing or invalid", ASSET_ROOT_NAME, machineName)
		end
		local hasVisiblePart = false
		for _, descendant in ipairs(template:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				hasVisiblePart = true
				break
			end
		end
		if not hasVisiblePart then
			return false, string.format("%s.%s has no visible construction geometry", ASSET_ROOT_NAME, machineName)
		end
	end
	local effects = assetRoot:FindFirstChild("Effects")
	if not effects or not effects:IsA("Folder") then
		return false, ASSET_ROOT_NAME .. ".Effects is missing"
	end
	for _, effectName in ipairs(REQUIRED_EFFECT_NAMES) do
		local carrier = effects:FindFirstChild(effectName)
		if not carrier or not carrier:IsA("BasePart")
			or not carrier:FindFirstChildWhichIsA("ParticleEmitter", true)
		then
			return false, string.format("%s.Effects.%s is missing or invalid", ASSET_ROOT_NAME, effectName)
		end
	end
	return true
end

local function addMachineExhaust(machine)
	local effects = assetRoot:FindFirstChild("Effects")
	local carrier = effects and effects:FindFirstChild("ExhaustSmokeEmitterTemplate")
	local template = carrier and carrier:FindFirstChildOfClass("ParticleEmitter")
	if not template then
		return
	end
	for _, descendant in ipairs(machine:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant:GetAttribute("ConstructionExhaustMount") == true
		then
			local emitter = template:Clone()
			emitter.Name = "ConstructionExhaust"
			emitter.Enabled = false
			emitter.Rate = 0
			emitter.Parent = descendant
		end
	end
end

local function setMachineExhaust(machine, enabled, multiplier)
	for _, descendant in ipairs(machine:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") and descendant.Name == "ConstructionExhaust" then
			local baseRate = tonumber(descendant:GetAttribute("ConstructionBaseRate")) or 7
			descendant.Rate = if enabled then baseRate * multiplier else 0
			descendant.Enabled = enabled
		end
	end
end

local function machineBottomFromPivot(machine)
	local boundsCFrame, boundsSize = machine:GetBoundingBox()
	local localBounds = machine:GetPivot():ToObjectSpace(boundsCFrame)
	return localBounds.Position.Y - boundsSize.Y * 0.5
end

local function cloneMachine(parent, name)
	local template = assetRoot:FindFirstChild(name)
	assert(template and template:IsA("Model"), ASSET_ROOT_NAME .. "." .. name .. " is missing")
	local machine = template:Clone()
	machine.Name = name
	setRuntimeOriginals(machine)
	addMachineExhaust(machine)
	machine.Parent = parent
	pcall(function()
		machine.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	return {
		name = name,
		model = machine,
		bottomFromPivot = machineBottomFromPivot(machine),
		visible = false,
		parked = false,
	}
end

local function routeCFrame(record, route, progress, finalLookOffset)
	local segmentCount = #route - 1
	local scaled = math.clamp(progress, 0, 1) * segmentCount
	local segment = math.min(segmentCount, math.floor(scaled) + 1)
	local alpha = smoothstep(scaled - (segment - 1))
	local offset = route[segment]:Lerp(route[segment + 1], alpha)
	local tangentStart
	if segment == 1 then
		tangentStart = route[2] - route[1]
	else
		tangentStart = (route[segment + 1] - route[segment - 1]) * 0.5
	end
	local tangentEnd
	if segment + 1 == #route then
		tangentEnd = if finalLookOffset
			then finalLookOffset - route[#route]
			else route[#route] - route[#route - 1]
	else
		tangentEnd = (route[segment + 2] - route[segment]) * 0.5
	end
	local tangent = tangentStart:Lerp(tangentEnd, alpha)
	local lookOffset = offset + tangent
	local point = groundPointFromOffset(offset)
	local lookPoint = groundPointFromOffset(lookOffset)
	if (lookPoint - point).Magnitude < 0.05 then
		lookPoint = groundPointFromOffset(offset + Vector3.new(0, 0, -1))
	end
	local up = lot.CFrame.UpVector
	local pivotPoint = point + up * (-record.bottomFromPivot)
	local targetPoint = lookPoint + up * (-record.bottomFromPivot)
	return CFrame.lookAt(pivotPoint, targetPoint, up)
end

local function articulationModel(machine, modelName)
	local candidate = machine:FindFirstChild(modelName, true)
	return if candidate and candidate:IsA("Model") then candidate else nil
end

local function setArticulation(machine, modelName, delta)
	local articulated = articulationModel(machine, modelName)
	if not articulated then
		return
	end
	local parentModel = articulated.Parent
	while parentModel and not parentModel:IsA("Model") do
		parentModel = parentModel.Parent
	end
	local localPivot = articulated:GetAttribute("ConstructionParentLocalPivot")
	if parentModel and parentModel:IsA("Model") and typeof(localPivot) == "CFrame" then
		articulated:PivotTo(parentModel:GetPivot() * localPivot * delta)
	end
end

local function cloneEffectCarrier(parent, templateName, runtimeName, offset)
	local effects = assetRoot:FindFirstChild("Effects")
	local template = effects and effects:FindFirstChild(templateName)
	if not template or not template:IsA("BasePart") then
		return nil
	end
	local carrier = template:Clone()
	carrier.Name = runtimeName
	carrier.Anchored = true
	carrier.CanCollide = false
	carrier.CanTouch = false
	carrier.CanQuery = false
	carrier.CFrame = CFrame.new(groundPointFromOffset(offset) + lot.CFrame.UpVector * 0.15)
	carrier.Parent = parent
	for _, descendant in ipairs(carrier:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant.Rate = 0
		end
	end
	return carrier
end

local function setDustRate(effectFolder, rateMultiplier)
	for _, descendant in ipairs(effectFolder:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local baseRate = tonumber(descendant:GetAttribute("ConstructionBaseRate")) or 24
			descendant.Rate = baseRate * math.max(0, rateMultiplier)
			descendant.Enabled = rateMultiplier > 0
		end
	end
end

local function emitDust(effectFolder, multiplier)
	for _, descendant in ipairs(effectFolder:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local burst = tonumber(descendant:GetAttribute("ConstructionBurstCount")) or 24
			descendant:Emit(math.max(1, math.floor(burst * multiplier)))
		end
	end
end

local function removeOldRuntimeRoots()
	for _, descendant in ipairs(environment:GetDescendants()) do
		if (descendant:IsA("Model") or descendant:IsA("Folder"))
			and (
				descendant.Name == RUNTIME_NAME
				or descendant:GetAttribute("BunkerConstructionRuntime") == true
				or descendant:GetAttribute("ConstructionRuntime") == true
			)
		then
			descendant:Destroy()
		end
	end
end

local function buildRuntime(requestKey, readyAt, duration, resumed)
	local assetsValid, assetProblem = validateConstructionAssets()
	if not assetsValid then
		return nil, nil, nil, assetProblem
	end

	local root = Instance.new("Model")
	root.Name = RUNTIME_NAME
	root:SetAttribute("BunkerConstructionRuntime", true)
	root:SetAttribute("ConstructionRuntime", true)
	root:SetAttribute("ConstructionControllerVersion", CONTROLLER_VERSION)
	root:SetAttribute("ConstructionRequestKey", requestKey)
	root:SetAttribute("ConstructionReadyAt", readyAt)
	root:SetAttribute("ConstructionDuration", duration)
	root:SetAttribute("ConstructionResumed", resumed)
	pcall(function()
		root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local machines
	local effects
	local built, failure = xpcall(function()
		buildSafetyPerimeter(root)

		local machinery = Instance.new("Folder")
		machinery.Name = "ActiveMachinery"
		machinery.Parent = root
		machines = {
			DumpTruck = cloneMachine(machinery, "DumpTruck"),
			Excavator = cloneMachine(machinery, "Excavator"),
			SkidSteer = cloneMachine(machinery, "SkidSteer"),
			MobileCrane = cloneMachine(machinery, "MobileCrane"),
		}

		-- A mobile crane never drives with deployed stabilizers or a swinging
		-- hook. They remain cleanly concealed until the carrier is parked.
		setSubmodelVisible(machines.MobileCrane.model, "Outriggers", false)
		setSubmodelVisible(machines.MobileCrane.model, "Hook", false)

		effects = Instance.new("Folder")
		effects.Name = "ConstructionEffects"
		effects.Parent = root
		assert(
			cloneEffectCarrier(effects, "DustEmitterTemplate", "CentralDustCloud", Vector3.new(0, 0, 1)),
			"Central dust carrier could not be built"
		)
		assert(
			cloneEffectCarrier(
				effects,
				"GroundDustEmitterTemplate",
				"ExcavationDustWest",
				Vector3.new(-4, 0, 2)
			),
			"West excavation dust carrier could not be built"
		)
		assert(
			cloneEffectCarrier(
				effects,
				"GroundDustEmitterTemplate",
				"ExcavationDustEast",
				Vector3.new(5, 0, 4)
			),
			"East excavation dust carrier could not be built"
		)
		assert(
			cloneEffectCarrier(effects, "DustEmitterTemplate", "RevealDustScreen", Vector3.new(0, 0, -2)),
			"Reveal dust carrier could not be built"
		)
		setDustRate(effects, 0)
	end, debug.traceback)
	if not built then
		root:Destroy()
		return nil, nil, nil, tostring(failure)
	end

	-- Keep the complete candidate unparented until every required piece has
	-- validated. The caller performs one atomic swap only after route and work
	-- pose checks pass, so a damaged template can never strand half a site.
	return root, machines, effects
end

local sideDriveway = site:FindFirstChild("SideDriveway")
assert(sideDriveway and sideDriveway:IsA("BasePart"), "SiteAndStreet.SideDriveway must be a BasePart")
local detachedGarage = environment:FindFirstChild("DetachedGarage", true)
assert(detachedGarage and detachedGarage:IsA("Model"), "CooperHouseEnvironment.DetachedGarage must be a Model")

local maximumCarrierHalfWidth = 0
local maximumCarrierPlanRadius = 0
for _, machineName in ipairs(REQUIRED_MACHINE_NAMES) do
	local template = assetRoot:FindFirstChild(machineName)
	if template and template:IsA("Model") then
		local _, boundsSize = template:GetBoundingBox()
		maximumCarrierHalfWidth = math.max(maximumCarrierHalfWidth, boundsSize.X * 0.5)
		maximumCarrierPlanRadius = math.max(
			maximumCarrierPlanRadius,
			Vector2.new(boundsSize.X, boundsSize.Z).Magnitude * 0.5
		)
	end
end

local garageBoundsCFrame, garageBoundsSize = detachedGarage:GetBoundingBox()
local maximumGarageDrivewayZ = -math.huge
local maximumGarageShaftX = -math.huge
for xSign = -1, 1, 2 do
	for ySign = -1, 1, 2 do
		for zSign = -1, 1, 2 do
			local corner = garageBoundsCFrame:PointToWorldSpace(Vector3.new(
				garageBoundsSize.X * 0.5 * xSign,
				garageBoundsSize.Y * 0.5 * ySign,
				garageBoundsSize.Z * 0.5 * zSign
			))
			maximumGarageDrivewayZ = math.max(
				maximumGarageDrivewayZ,
				sideDriveway.CFrame:PointToObjectSpace(corner).Z
			)
			maximumGarageShaftX = math.max(
				maximumGarageShaftX,
				shaftOpening.CFrame:PointToObjectSpace(corner).X
			)
		end
	end
end

local drivewayRearLimit = sideDriveway.Size.Z * 0.5 - 0.35
local rearLaneZ = math.min(
	drivewayRearLimit,
	maximumGarageDrivewayZ + maximumCarrierHalfWidth + 0.65
)
assert(
	rearLaneZ > maximumGarageDrivewayZ + maximumCarrierHalfWidth,
	"SideDriveway has no garage-safe construction lane"
)
local rearDrivewayPoint = sideDriveway.CFrame:PointToWorldSpace(Vector3.new(0, 0, rearLaneZ))
local rearDrivewayLocal = shaftOpening.CFrame:PointToObjectSpace(rearDrivewayPoint)
local rearDrivewayOffset = Vector3.new(rearDrivewayLocal.X, 0, rearDrivewayLocal.Z)
local garageClearTurnX = math.max(
	rearDrivewayOffset.X + 31,
	maximumGarageShaftX + maximumCarrierPlanRadius + 1.5
)

-- Enter from the real side driveway at the left of the property, pass behind
-- Georgie's garage, then turn into the open rear yard. Every point is stored
-- as a live ShaftOpening-local offset so a relocated Cooper environment keeps
-- the entire convoy attached to the correct backyard.
local machineRoutes = {
	DumpTruck = {
		rearDrivewayOffset,
		rearDrivewayOffset + Vector3.new(15, 0, 0),
		Vector3.new(garageClearTurnX, 0, rearDrivewayOffset.Z - 1),
		Vector3.new(-12, 0, 12),
		Vector3.new(10, 0, 20),
	},
	Excavator = {
		rearDrivewayOffset + Vector3.new(0, 0, 0.8),
		rearDrivewayOffset + Vector3.new(15, 0, 0.8),
		Vector3.new(garageClearTurnX + 0.6, 0, rearDrivewayOffset.Z - 0.2),
		Vector3.new(-11, 0, 12),
		Vector3.new(8, 0, 4),
	},
	SkidSteer = {
		rearDrivewayOffset + Vector3.new(0, 0, 1.6),
		rearDrivewayOffset + Vector3.new(15, 0, 1.6),
		Vector3.new(garageClearTurnX + 1.2, 0, rearDrivewayOffset.Z + 0.6),
		Vector3.new(-10, 0, 12),
		Vector3.new(-6, 0, 6),
	},
	MobileCrane = {
		rearDrivewayOffset + Vector3.new(0, 0, 2.4),
		rearDrivewayOffset + Vector3.new(15, 0, 2.4),
		Vector3.new(garageClearTurnX + 1.8, 0, rearDrivewayOffset.Z + 1.4),
		Vector3.new(-9, 0, 13),
		Vector3.new(-20, 0, 16),
	},
}

local arrivalWindows = {
	DumpTruck = { 0.0, 2.3 },
	Excavator = { 1.5, 4.3 },
	SkidSteer = { 3.2, 6.1 },
	MobileCrane = { 5.0, 8.0 },
}

local function updateMachineArrival(record, route, elapsed, window)
	local progress = math.clamp((elapsed - window[1]) / (window[2] - window[1]), 0, 1)
	local shouldShow = elapsed >= window[1]
	if shouldShow ~= record.visible then
		record.visible = shouldShow
		setMachineVisible(record.model, shouldShow)
	end
	record.model:PivotTo(routeCFrame(record, route, progress, Vector3.zero))
	setMachineExhaust(record.model, shouldShow and progress < 1, 1.05)
	if record.name == "MobileCrane" and progress < 1 then
		setSubmodelVisible(record.model, "Outriggers", false)
		setSubmodelVisible(record.model, "Hook", false)
	end
	if progress >= 1 and not record.parked then
		record.parked = true
		if record.name == "MobileCrane" then
			setSubmodelVisible(record.model, "Outriggers", true)
			setSubmodelVisible(record.model, "Hook", true)
		end
	end
end

local function updateArrival(session, elapsed)
	for machineName, record in pairs(session.machines) do
		updateMachineArrival(record, machineRoutes[machineName], elapsed, arrivalWindows[machineName])
	end
	setDustRate(session.effects, 0.08)
end

local function ensureMachinesParked(session)
	for machineName, record in pairs(session.machines) do
		if not record.parked then
			record.model:PivotTo(routeCFrame(record, machineRoutes[machineName], 1, Vector3.zero))
			record.visible = true
			record.parked = true
			setMachineVisible(record.model, true)
			if machineName == "MobileCrane" then
				setSubmodelVisible(record.model, "Outriggers", true)
				setSubmodelVisible(record.model, "Hook", true)
			end
		end
	end
end

local function updateExcavation(session, elapsed)
	ensureMachinesParked(session)
	local cycle = (elapsed - 8) * math.pi * 0.62
	local digging = (math.sin(cycle) + 1) * 0.5
	local excavator = session.machines.Excavator.model
	local skid = session.machines.SkidSteer.model
	local truck = session.machines.DumpTruck.model
	setArticulation(excavator, "UpperBody", CFrame.Angles(0, math.rad(math.sin(cycle * 0.48) * 15), 0))
	setArticulation(excavator, "Boom", CFrame.Angles(math.rad(-10 - digging * 19), 0, 0))
	setArticulation(excavator, "Stick", CFrame.Angles(math.rad(7 + digging * 23), 0, 0))
	setArticulation(excavator, "Bucket", CFrame.Angles(math.rad(-8 + digging * 37), 0, 0))
	setArticulation(skid, "LiftArms", CFrame.Angles(math.rad(-3 - digging * 10), 0, 0))
	setArticulation(skid, "Bucket", CFrame.Angles(math.rad(-5 + digging * 18), 0, 0))
	setArticulation(truck, "Bed", CFrame.Angles(math.rad(-math.max(0, math.sin(cycle * 0.38)) * 8), 0, 0))
	setMachineExhaust(excavator, true, 1.15)
	setMachineExhaust(skid, true, 0.8)
	setMachineExhaust(truck, true, 0.45)
	setMachineExhaust(session.machines.MobileCrane.model, false, 0)
	setDustRate(session.effects, 0.42 + digging * 0.28)
end

local function updateCrane(session, elapsed)
	ensureMachinesParked(session)
	local cycle = (elapsed - 18) * math.pi * 0.42
	local lift = (math.sin(cycle) + 1) * 0.5
	local crane = session.machines.MobileCrane.model
	local excavator = session.machines.Excavator.model
	local skid = session.machines.SkidSteer.model
	setArticulation(crane, "Turret", CFrame.Angles(0, math.rad(math.sin(cycle * 0.45) * 19), 0))
	setArticulation(crane, "Boom", CFrame.Angles(math.rad(-3 - lift * 10), 0, 0))
	setArticulation(crane, "Hook", CFrame.new(0, -lift * 1.35, 0))
	setArticulation(excavator, "Boom", CFrame.Angles(math.rad(-8), 0, 0))
	setArticulation(excavator, "Stick", CFrame.Angles(math.rad(11), 0, 0))
	setArticulation(skid, "LiftArms", CFrame.Angles(math.rad(-2), 0, 0))
	setMachineExhaust(crane, true, 0.9)
	setMachineExhaust(excavator, true, 0.35)
	setMachineExhaust(skid, true, 0.25)
	setMachineExhaust(session.machines.DumpTruck.model, false, 0)
	setDustRate(session.effects, 0.48 + lift * 0.22)
end

local function updateDust(session, elapsed)
	ensureMachinesParked(session)
	local ramp = smoothstep((elapsed - 27) / 7)
	setDustRate(session.effects, 0.9 + ramp * 2.4)
	for _, record in pairs(session.machines) do
		setMachineExhaust(record.model, true, 0.75 + ramp * 0.35)
	end
end

local function beginSurfaceReveal(session)
	if session.surfaceRevealStarted then
		return
	end
	session.surfaceRevealStarted = true
	-- Keep the finished entrance fully concealed and nonphysical until the
	-- deadline. The peak dust cloud sells the build, then completeWorld swaps
	-- the grass cover and finished entrance in one clean frame.
	emitDust(session.effects, 2.2)
end

local function updateReveal(session, elapsed)
	ensureMachinesParked(session)
	beginSurfaceReveal(session)
	local pulse = 0.5 + 0.5 * math.sin((elapsed - 34) * math.pi * 0.9)
	setDustRate(session.effects, 3.0 + pulse * 0.9)
	for _, record in pairs(session.machines) do
		setMachineExhaust(record.model, true, 0.65)
	end
end

local function updateDeparture(session, elapsed)
	ensureMachinesParked(session)
	beginSurfaceReveal(session)
	local departureProgress = smoothstep((elapsed - 38) / 7)
	for machineName, record in pairs(session.machines) do
		local reversedRoute = {}
		for index = #machineRoutes[machineName], 1, -1 do
			table.insert(reversedRoute, machineRoutes[machineName][index])
		end
		if machineName == "MobileCrane" then
			setSubmodelVisible(record.model, "Outriggers", false)
			setSubmodelVisible(record.model, "Hook", false)
		end
		record.model:PivotTo(routeCFrame(record, reversedRoute, departureProgress))
		setMachineExhaust(record.model, departureProgress < 1, 1.1)
		if departureProgress >= 0.92 then
			setMachineVisible(record.model, false)
		end
	end
	setDustRate(session.effects, 3.4 - departureProgress * 0.8)
end

local function makeFinalRevealDust()
	local old = environment:FindFirstChild("BunkerRevealDust")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BunkerRevealDust"
	folder.Parent = environment
	for index, definition in ipairs({
		{ "DustEmitterTemplate", Vector3.new(0, 0, 0) },
		{ "GroundDustEmitterTemplate", Vector3.new(-3.5, 0, 1.5) },
		{ "GroundDustEmitterTemplate", Vector3.new(3.5, 0, -1.5) },
	}) do
		local carrier = cloneEffectCarrier(
			folder,
			definition[1],
			"FinalRevealDust" .. tostring(index),
			definition[2]
		)
		if carrier then
			for _, descendant in ipairs(carrier:GetDescendants()) do
				if descendant:IsA("ParticleEmitter") then
					local burst = tonumber(descendant:GetAttribute("ConstructionBurstCount")) or 28
					descendant:Emit(math.floor(burst * 1.8))
				end
			end
		end
	end
	Debris:AddItem(folder, 5)
end

local function completeWorld(session, reason)
	if worldUnlocked then
		return
	end
	worldUnlocked = true
	beginSurfaceReveal(session)
	makeFinalRevealDust()
	ensureClosedHatchSupport()
	restoreSurface(true)
	-- The cover remains a solid, queryable grass support through every active
	-- phase. At the final reveal, with dust at maximum, it becomes a retained
	-- transparent noncollider so no player ever sees or falls into a startup
	-- void and the installed cover contract remains inspectable.
	setCoverEnabled(false)
	setUnlockState("Unlocked")
	publishStage("Complete", 1)
	bunker:SetAttribute("ConstructionCompletionReason", tostring(reason or "DeadlineReached"))
	bunker:SetAttribute("ConstructionCompletedAt", os.time())
	processedRequestKeys[session.requestKey] = true
	activeRequestKey = nil
	activeSession = nil
	if session.root and session.root.Parent then
		session.root:Destroy()
	end
end

local function validateWorkPoseSeparation(machines)
	local bounds = {}
	for _, machineName in ipairs(REQUIRED_MACHINE_NAMES) do
		local record = machines[machineName]
		assert(record and record.model and record.model.Parent, machineName .. " runtime record is missing")
		record.model:PivotTo(routeCFrame(record, machineRoutes[machineName], 1, Vector3.zero))
		local boundsCFrame, boundsSize = record.model:GetBoundingBox()
		bounds[machineName] = {
			cframe = boundsCFrame,
			size = boundsSize,
		}
	end
	for firstIndex = 1, #REQUIRED_MACHINE_NAMES do
		for secondIndex = firstIndex + 1, #REQUIRED_MACHINE_NAMES do
			local firstName = REQUIRED_MACHINE_NAMES[firstIndex]
			local secondName = REQUIRED_MACHINE_NAMES[secondIndex]
			local first = bounds[firstName]
			local second = bounds[secondName]
			local xGap = math.abs(first.cframe.Position.X - second.cframe.Position.X)
				- (first.size.X + second.size.X) * 0.5
			local zGap = math.abs(first.cframe.Position.Z - second.cframe.Position.Z)
				- (first.size.Z + second.size.Z) * 0.5
			assert(
				xGap >= WORK_POSE_CLEARANCE or zGap >= WORK_POSE_CLEARANCE,
				string.format("%s and %s construction work envelopes overlap", firstName, secondName)
			)
		end
	end
end

local function failClosedConstruction(problem)
	local failedSession = activeSession
	activeSession = nil
	activeRequestKey = nil
	if failedSession and failedSession.root and failedSession.root.Parent then
		failedSession.root:Destroy()
	end
	removeOldRuntimeRoots()
	if not worldUnlocked then
		concealSurface()
		setCoverEnabled(true)
		setUnlockState("Locked")
		publishStage("Locked", 0)
	end
	bunker:SetAttribute("ConstructionFailure", tostring(problem or "Unknown construction failure"))
	if time() - lastFailureWarningClock >= 3 then
		lastFailureWarningClock = time()
		warn("[CooperBunkerConstruction] Recovered safely: " .. tostring(problem))
	end
end

local function instantReveal(requestKey, readyAt, reason)
	if not worldUnlocked then
		if activeSession then
			completeWorld(activeSession, reason or "CompletedOwnerJoined")
			return
		end
		local syntheticSession = {
			requestKey = requestKey,
			readyAt = readyAt,
			duration = DEFAULT_DURATION,
			root = nil,
			machines = {},
			effects = Instance.new("Folder"),
			surfaceRevealStarted = false,
		}
		completeWorld(syntheticSession, reason or "CompletedOwnerJoined")
		syntheticSession.effects:Destroy()
	else
		ensureClosedHatchSupport()
		restoreSurface(true)
		setCoverEnabled(false)
		setUnlockState("Unlocked")
		publishStage("Complete", 1)
	end
end

local function beginConstruction(requestKey, readyAt, duration, resumed)
	local root, machines, effects, buildProblem = buildRuntime(requestKey, readyAt, duration, resumed)
	if not root then
		failClosedConstruction(buildProblem or "Construction runtime could not be built")
		return nil, buildProblem
	end
	local posesValid, poseProblem = xpcall(function()
		validateWorkPoseSeparation(machines)
	end, debug.traceback)
	if not posesValid then
		root:Destroy()
		failClosedConstruction(poseProblem)
		return nil, poseProblem
	end
	for machineName, record in pairs(machines) do
		record.model:PivotTo(routeCFrame(record, machineRoutes[machineName], 0, Vector3.zero))
	end
	removeOldRuntimeRoots()
	root.Parent = environment
	activeRequestKey = requestKey
	activeSession = {
		requestKey = requestKey,
		readyAt = readyAt,
		duration = duration,
		startedAt = readyAt - duration,
		root = root,
		machines = machines,
		effects = effects,
		surfaceRevealStarted = false,
		lastStage = "",
		lastProgressPublishClock = 0,
	}
	concealSurface()
	setCoverEnabled(true)
	setUnlockState("Constructing")
	bunker:SetAttribute("ConstructionReadyAt", readyAt)
	bunker:SetAttribute("ConstructionRequestKey", requestKey)
	bunker:SetAttribute("ConstructionControllerVersion", CONTROLLER_VERSION)
	local elapsed = math.max(0, currentUnix() - activeSession.startedAt)
	local normalizedElapsed = if duration == DEFAULT_DURATION
		then elapsed
		else elapsed * (DEFAULT_DURATION / duration)
	local progress = math.clamp(elapsed / duration, 0, 1)
	activeSession.lastStage = stageForElapsed(normalizedElapsed)
	activeSession.lastProgressPublishClock = time()
	publishStage(activeSession.lastStage, progress)
	if normalizedElapsed < 8 then
		updateArrival(activeSession, normalizedElapsed)
	elseif normalizedElapsed < 18 then
		updateExcavation(activeSession, normalizedElapsed)
	elseif normalizedElapsed < 27 then
		updateCrane(activeSession, normalizedElapsed)
	elseif normalizedElapsed < 34 then
		updateDust(activeSession, normalizedElapsed)
	elseif normalizedElapsed < 38 then
		updateReveal(activeSession, normalizedElapsed)
	else
		updateDeparture(activeSession, normalizedElapsed)
	end
	bunker:SetAttribute("ConstructionFailure", "")
	return activeSession
end

local function normalizeRequest(player, payload)
	if type(payload) ~= "table" then
		return nil, "Construction request payload must be a table"
	end
	local readyAt = tonumber(payload.readyAt)
	if not readyAt or readyAt ~= readyAt or readyAt <= 0 or readyAt > 4_102_444_800 then
		return nil, "Construction request has an invalid readyAt timestamp"
	end
	local rawDuration = tonumber(payload.constructionSeconds)
	if rawDuration and (rawDuration ~= rawDuration or rawDuration <= 0 or rawDuration > 86_400) then
		return nil, "Construction request has an invalid duration"
	end
	local duration = math.clamp(math.floor(rawDuration or DEFAULT_DURATION), 1, 86_400)
	local requestKey = tostring(payload.requestKey or "")
	if requestKey == "" then
		local userId = player and player.UserId or 0
		requestKey = string.format("%d:%d", userId, math.floor(readyAt))
	end
	if #requestKey > 160 then
		return nil, "Construction request key is too long"
	end
	local personallyUnlocked = player
		and player:IsA("Player")
		and player:GetAttribute("CooperSecretBunkerUnlocked") == true
	return {
		requestKey = requestKey,
		readyAt = readyAt,
		duration = duration,
		remaining = math.max(0, readyAt - currentUnix()),
		resumed = payload.resumed == true,
		instant = payload.instant == true and personallyUnlocked,
		unlocked = payload.unlocked == true and personallyUnlocked,
		reason = tostring(payload.reason or "PresentationRequest"),
	}
end

local function handleConstructionRequest(player, payload)
	local request, requestProblem = normalizeRequest(player, payload)
	if not request then
		if time() - lastFailureWarningClock >= 3 then
			lastFailureWarningClock = time()
			warn("[CooperBunkerConstruction] Rejected request: " .. tostring(requestProblem))
		end
		return false
	end
	local requestKey = request.requestKey
	if processedRequestKeys[requestKey] then
		return
	end

	if worldUnlocked then
		processedRequestKeys[requestKey] = true
		instantReveal(requestKey, request.readyAt, "WorldAlreadyUnlocked")
		return
	end

	if request.instant
		or request.unlocked
		or request.remaining <= 0
		or currentUnix() >= request.readyAt
	then
		processedRequestKeys[requestKey] = true
		instantReveal(requestKey, request.readyAt, request.reason)
		return
	end

	if activeSession then
		if activeRequestKey == requestKey then
			return
		end
		-- The earliest deadline owns the one shared spectacle. A later personal
		-- entitlement can never restart, duplicate, or downgrade the world.
		if request.readyAt >= activeSession.readyAt then
			processedRequestKeys[requestKey] = true
			return
		end
		processedRequestKeys[activeRequestKey] = true
	end

	local session = beginConstruction(requestKey, request.readyAt, request.duration, request.resumed)
	return session ~= nil
end

stageForElapsed = function(elapsed)
	if elapsed < 8 then
		return "Arrival"
	elseif elapsed < 18 then
		return "Excavation"
	elseif elapsed < 27 then
		return "Crane"
	elseif elapsed < 34 then
		return "Dust"
	elseif elapsed < 38 then
		return "Reveal"
	elseif elapsed < 45 then
		return "Departure"
	else
		return "Complete"
	end
end

local function updateActiveSession()
	local session = activeSession
	if not session or worldUnlocked then
		return
	end
	if not session.root or session.root.Parent ~= environment then
		error("Active construction runtime was removed unexpectedly")
	end
	local elapsed = math.max(0, currentUnix() - session.startedAt)
	local normalizedElapsed = if session.duration == DEFAULT_DURATION
		then elapsed
		else elapsed * (DEFAULT_DURATION / session.duration)
	local progress = math.clamp(elapsed / session.duration, 0, 1)
	local stageName = stageForElapsed(normalizedElapsed)
	if stageName ~= session.lastStage then
		session.lastStage = stageName
		session.lastProgressPublishClock = time()
		publishStage(stageName, progress)
	elseif time() - session.lastProgressPublishClock >= 0.1 then
		session.lastProgressPublishClock = time()
		bunker:SetAttribute("ConstructionProgress", progress)
		if session.root then
			session.root:SetAttribute("ConstructionProgress", progress)
		end
	end

	if normalizedElapsed < 8 then
		updateArrival(session, normalizedElapsed)
	elseif normalizedElapsed < 18 then
		updateExcavation(session, normalizedElapsed)
	elseif normalizedElapsed < 27 then
		updateCrane(session, normalizedElapsed)
	elseif normalizedElapsed < 34 then
		updateDust(session, normalizedElapsed)
	elseif normalizedElapsed < 38 then
		updateReveal(session, normalizedElapsed)
	elseif normalizedElapsed < 45 then
		updateDeparture(session, normalizedElapsed)
	else
		completeWorld(session, "DeadlineReached")
	end
end

local watchedPlayers = {}

local function scanPlayer(player)
	if player.Parent ~= Players then
		return
	end
	if player:GetAttribute("CooperSecretBunkerPurchased") ~= true then
		return
	end
	local readyAt = tonumber(player:GetAttribute("CooperSecretBunkerReadyAt")) or 0
	if readyAt <= 0 then
		return
	end
	local unlocked = player:GetAttribute("CooperSecretBunkerUnlocked") == true
	handleConstructionRequest(player, {
		requestKey = string.format("%d:%d", player.UserId, math.floor(readyAt)),
		readyAt = readyAt,
		constructionSeconds = DEFAULT_DURATION,
		remaining = math.max(0, readyAt - os.time()),
		resumed = true,
		instant = unlocked,
		unlocked = unlocked,
		reason = unlocked and "AttributeReplayUnlocked" or "AttributeReplayResume",
	})
end

local function watchPlayer(player)
	if watchedPlayers[player] then
		return
	end
	local connections = {}
	watchedPlayers[player] = connections
	for _, attributeName in ipairs({
		"CooperSecretBunkerPurchased",
		"CooperSecretBunkerReadyAt",
		"CooperSecretBunkerUnlocked",
		"CooperSecretBunkerStatus",
	}) do
		table.insert(connections, player:GetAttributeChangedSignal(attributeName):Connect(function()
			task.defer(scanPlayer, player)
		end))
	end
	task.defer(scanPlayer, player)
end

local function unwatchPlayer(player)
	local connections = watchedPlayers[player]
	if not connections then
		return
	end
	watchedPlayers[player] = nil
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
end

-- Establish a safe saved-place baseline before listening. The persistent edit
-- installer already does this, but the runtime repeats it idempotently for old
-- places and for script-only syncs.
ensureViewingAnchor()
bunker:SetAttribute("ConstructionControllerVersion", CONTROLLER_VERSION)
bunker:SetAttribute("ConstructionReadyAt", tonumber(bunker:GetAttribute("ConstructionReadyAt")) or 0)
bunker:SetAttribute("ConstructionRequestKey", tostring(bunker:GetAttribute("ConstructionRequestKey") or ""))
removeOldRuntimeRoots()
if worldUnlocked then
	instantReveal("startup:unlocked", tonumber(bunker:GetAttribute("ConstructionReadyAt")) or 0, "StartupUnlocked")
else
	concealSurface()
	setCoverEnabled(true)
	setUnlockState("Locked")
	publishStage("Locked", 0)
end

requestBunkerConstruction.Event:Connect(function(player, payload)
	local succeeded, problem = xpcall(function()
		handleConstructionRequest(player, payload)
	end, debug.traceback)
	if not succeeded then
		failClosedConstruction(problem)
		if typeof(player) == "Instance" and player:IsA("Player") then
			task.delay(1, scanPlayer, player)
		end
	end
end)
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(unwatchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

bunker:GetAttributeChangedSignal("UnlockState"):Connect(function()
	if writingUnlockState then
		return
	end
	if bunker:GetAttribute("UnlockState") == "Unlocked" then
		if not worldUnlocked then
			instantReveal(
				"external:unlocked",
				tonumber(bunker:GetAttribute("ConstructionReadyAt")) or os.time(),
				"ExternalUnlock"
			)
		end
	elseif worldUnlocked then
		setUnlockState("Unlocked")
	end
end)

RunService.Heartbeat:Connect(function()
	local succeeded, problem = xpcall(updateActiveSession, debug.traceback)
	if not succeeded then
		failClosedConstruction(problem)
		for _, player in ipairs(Players:GetPlayers()) do
			task.delay(1, scanPlayer, player)
		end
	end
end)
