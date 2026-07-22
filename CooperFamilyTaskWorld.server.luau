--!nonstrict
-- Physical task producers, owner-locked carry items, and delivery truck queue.
-- Installed as ServerScriptService.CooperTaskWorld.

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ROOT_TIMEOUT = 30
local environment = workspace:WaitForChild("CooperHouseEnvironment", ROOT_TIMEOUT)
local gameRoot = ReplicatedStorage:WaitForChild("CooperGame", ROOT_TIMEOUT)
local Config = require(gameRoot:WaitForChild("Config", ROOT_TIMEOUT))
local candyDeliveryConfig = Config.CandyDelivery
assert(type(candyDeliveryConfig) == "table", "CooperGame.Config.CandyDelivery is missing")
assert(candyDeliveryConfig.LogoCatalogAssetId == "rbxassetid://74538933380880", "Los Pollos catalog decal is missing")
assert(candyDeliveryConfig.LogoAssetId == "rbxassetid://115114653936657", "Los Pollos resolved image is missing")
local world = environment:WaitForChild(Config.WorldRootName, ROOT_TIMEOUT)
local deliveryWorld = world:WaitForChild("Delivery", ROOT_TIMEOUT)
local truck = deliveryWorld:WaitForChild("CooperDeliveryTruck", ROOT_TIMEOUT)
local route = deliveryWorld:WaitForChild("Route", ROOT_TIMEOUT)
local truckSpawn = route:WaitForChild("TruckSpawn", ROOT_TIMEOUT)
local truckApproach = route:WaitForChild("TruckApproach", ROOT_TIMEOUT)
local truckStop = route:WaitForChild("TruckStop", ROOT_TIMEOUT)
local truckExit = route:WaitForChild("TruckExit", ROOT_TIMEOUT)
local dropZone = deliveryWorld:WaitForChild("DeliveryDropZone", ROOT_TIMEOUT)
local taskVisuals = world:WaitForChild("TaskVisuals", ROOT_TIMEOUT)
local stations = world:WaitForChild("Stations", ROOT_TIMEOUT)
local boomboxSetupAnchor = stations:WaitForChild("BoomboxSetupAnchor", ROOT_TIMEOUT)
local formalLivingCarpet = environment:FindFirstChild("FormalLivingOatmealCarpet", true)
local missyBed = environment:FindFirstChild("MissyWalnutTwinBed", true)
local missyMattress = missyBed and missyBed:FindFirstChild("Mattress") or nil
local bunker = environment:WaitForChild("BackyardBunker", ROOT_TIMEOUT)
local underground = bunker:WaitForChild("Underground", ROOT_TIMEOUT)
local chemistryBay = underground:WaitForChild("FutureChemistryBay", ROOT_TIMEOUT)
local chemistryPad = chemistryBay:WaitForChild("EquipmentPad", ROOT_TIMEOUT)
local chemistryInstallAnchor = chemistryBay:WaitForChild(
	Config.ChemistrySetup and Config.ChemistrySetup.InstallTarget or "ChemistrySetAnchor",
	ROOT_TIMEOUT
)
assert(boomboxSetupAnchor:IsA("BasePart"), "Boombox setup anchor is missing")
assert(formalLivingCarpet and formalLivingCarpet:IsA("BasePart"), "Formal living-room carpet is missing")
assert(missyMattress and missyMattress:IsA("BasePart"), "Missy's mattress is missing")
assert(chemistryPad:IsA("BasePart"), "Bunker chemistry equipment pad is missing")
assert(chemistryInstallAnchor:IsA("BasePart"), "Bunker chemistry install anchor is missing")
local BOOMBOX_AUTO_SETUP_RADIUS = math.clamp(
	tonumber(boomboxSetupAnchor:GetAttribute("AutoSetupRadius")) or 5.5,
	3,
	8
)
local boomboxModelName = Config.Boombox and Config.Boombox.ModelName or "CooperIncomeBoombox"
local boomboxModel = taskVisuals:WaitForChild(boomboxModelName, ROOT_TIMEOUT)
local boomboxSound = boomboxModel:FindFirstChild("BoomboxSound", true)
	 or boomboxModel:FindFirstChildWhichIsA("Sound", true)
assert(boomboxModel:IsA("Model"), "Income boombox model is missing")
assert(boomboxSound and boomboxSound:IsA("Sound"), "Income boombox sound is missing")

local function migrateIncomeBoomboxPlacement()
	local tableModel = environment:FindFirstChild("FormalSofaEndTable", true)
	local tableTop = tableModel and tableModel:FindFirstChild("Top")
	local sofa = environment:FindFirstChild("FormalGreenFloralSofa", true)
	if not tableTop or not tableTop:IsA("BasePart") or not sofa or not sofa:IsA("Model") then
		return
	end
	local tableUp = tableTop.CFrame.UpVector.Unit
	local sofaLook = sofa:GetPivot().LookVector
	local planarLook = sofaLook - tableUp * sofaLook:Dot(tableUp)
	if planarLook.Magnitude <= 0.5 then
		return
	end
	local basePosition = tableTop.Position + tableUp * (tableTop.Size.Y * 0.5 + 0.025)
	local expected = CFrame.lookAt(basePosition, basePosition + planarLook.Unit, tableUp)
	local saved = boomboxModel:GetAttribute("SetupCFrame")
	if typeof(saved) == "CFrame" then
		local delta = expected * saved:Inverse()
		for _, descendant in ipairs(boomboxModel:GetDescendants()) do
			local rest = descendant:GetAttribute("RestCFrame")
			if typeof(rest) == "CFrame" then
				descendant:SetAttribute("RestCFrame", delta * rest)
			end
			local target = descendant:GetAttribute("DiscoTarget")
			if typeof(target) == "Vector3" then
				descendant:SetAttribute("DiscoTarget", delta:PointToWorldSpace(target))
			end
		end
	end
	boomboxModel:PivotTo(expected * CFrame.new(0, 0.42, 0))
	boomboxModel:SetAttribute("SetupCFrame", expected)
	world:SetAttribute("IncomeBoomboxSetupCFrame", expected)
	boomboxSetupAnchor.CFrame = expected * CFrame.new(0, 0.42, 0)
	local powerAnchor = stations:FindFirstChild("BoomboxPowerAnchor")
	if powerAnchor and powerAnchor:IsA("BasePart") then
		powerAnchor.CFrame = expected * CFrame.new(-0.82, 0.68, -0.39)
	end
end

migrateIncomeBoomboxPlacement()

local serverEvents = ServerScriptService:WaitForChild(Config.ServerEventsName, ROOT_TIMEOUT)
local reportAction = serverEvents:WaitForChild("ReportAction", ROOT_TIMEOUT)
local requestDelivery = serverEvents:WaitForChild("RequestDelivery", ROOT_TIMEOUT)
local runTaskAutomation = serverEvents:WaitForChild("RunTaskAutomation", ROOT_TIMEOUT)
local candyDeliveryChanged = serverEvents:WaitForChild("CandyDeliveryChanged", ROOT_TIMEOUT)
local familyAPI = serverEvents:WaitForChild("API", ROOT_TIMEOUT)
assert(reportAction:IsA("BindableEvent"), "ReportAction is missing")
assert(requestDelivery:IsA("BindableEvent"), "RequestDelivery is missing")
assert(runTaskAutomation:IsA("BindableEvent"), "RunTaskAutomation is missing")
assert(candyDeliveryChanged:IsA("BindableEvent"), "CandyDeliveryChanged is missing")
assert(familyAPI:IsA("BindableFunction"), "CooperGame API is missing")

local taskAutomationDefinitions = {}
for _, definition in ipairs(Config.TaskAutomationUpgrades or {}) do
	if type(definition) == "table" and type(definition.id) == "string" then
		taskAutomationDefinitions[definition.id] = definition
	end
end
local taskAutomationRobots = {}
local taskAutomationAnchors = {}
for _, upgradeId in ipairs({ "BeerBot", "DishBot", "TrashBot", "ToyFinder", "HackerBot" }) do
	local robot = taskVisuals:WaitForChild(upgradeId, ROOT_TIMEOUT)
	local anchor = stations:WaitForChild(upgradeId .. "InstallAnchor", ROOT_TIMEOUT)
	assert(robot:IsA("Model"), upgradeId .. " robot model is missing")
	assert(anchor:IsA("BasePart"), upgradeId .. " installation anchor is missing")
	taskAutomationRobots[upgradeId] = robot
	taskAutomationAnchors[upgradeId] = anchor
end

local function migrateAutomationHomeTransforms(robot)
	local savedHome = robot:GetAttribute("HomePivot")
	if typeof(savedHome) ~= "CFrame" then
		return
	end
	local currentHome = robot:GetPivot()
	if (currentHome.Position - savedHome.Position).Magnitude <= 0.05
		and currentHome.LookVector:Dot(savedHome.LookVector) >= 0.9999
		and currentHome.UpVector:Dot(savedHome.UpVector) >= 0.9999
	then
		return
	end
	local delta = currentHome * savedHome:Inverse()
	local function migrate(instance, attributeName)
		local value = instance:GetAttribute(attributeName)
		if typeof(value) == "CFrame" then
			instance:SetAttribute(attributeName, delta * value)
		end
	end
	for _, instance in ipairs(robot:GetDescendants()) do
		migrate(instance, "AutomationHomeCFrame")
		migrate(instance, "HomePivot")
		migrate(instance, "AutomationHomePivot")
	end
	robot:SetAttribute("HomePivot", currentHome)
end

for _, robot in pairs(taskAutomationRobots) do
	migrateAutomationHomeTransforms(robot)
end

local automationHomeState = {}
for upgradeId, robot in pairs(taskAutomationRobots) do
	local state = { parts = {}, lights = {}, guis = {} }
	for _, descendant in ipairs(robot:GetDescendants()) do
		if descendant:IsA("BasePart") then
			state.parts[descendant] = {
				cframe = descendant.CFrame,
				size = descendant.Size,
				color = descendant.Color,
				material = descendant.Material,
				transparency = descendant.Transparency,
				canCollide = descendant.CanCollide,
				canTouch = descendant.CanTouch,
				canQuery = descendant.CanQuery,
			}
		elseif descendant:IsA("Light") then
			state.lights[descendant] = {
				enabled = descendant.Enabled,
				brightness = descendant.Brightness,
				color = descendant.Color,
			}
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			state.guis[descendant] = { enabled = descendant.Enabled }
		end
	end
	automationHomeState[upgradeId] = state
end

local deliveryQueue = {}
local deliveryRunning = false
local promptCooldowns = {}
local deliveryRecordsByKey = {}
local deliveryRecordsById = {}
local compatibilityTargets = {}
local boomboxCompatibilityTargets = {}
local taskUpgradeCompatibilityTargets = {}
local chemistryCompatibilityTargets = {}
local pendingMachineRecoveries = {}
local pendingBoomboxRecoveries = {}
local playerConnections = {}
local deliveryInFlightKeys = {}
local deliverySerial = 0
local activeCarryByPlayer = {}
local activeTaskAutomation = {}
local taskAutomationQueues = {}
for upgradeId in pairs(taskAutomationRobots) do
	taskAutomationQueues[upgradeId] = {}
end

local enqueueDelivery
local runDeliveryQueue
local buyerRouteOccupied = false
-- A candy buyer may remain unresolved for several ninety-second visits. Reserve
-- one ordinary truck turn after each visit so paid deliveries cannot starve
-- behind a continuously replenished buyer queue.
local ordinaryDeliveryTurnReserved = false

local function finiteNumber(value, fallback)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return fallback
	end
	return number
end

local function carrySpeedFactor(kind)
	-- Carrying a bulky crate is slower, with a fixed standalone rule.
	return if kind == "MachinePart"
		then 0.68
		elseif kind == "Boombox"
			then 0.72
		elseif kind == "TaskUpgrade"
			then 0.74
		elseif kind == "ChemistrySetup"
			then 0.70
		elseif kind == "Beer"
			then 0.76
			else 0.82
end

local function clearCarryPenalty(player, expectedTool)
	local active = activeCarryByPlayer[player]
	if not active or (expectedTool and active.tool ~= expectedTool) then
		return
	end
	activeCarryByPlayer[player] = nil
	if active.ancestryConnection then
		active.ancestryConnection:Disconnect()
	end
	local humanoid = active.humanoid
	-- Restore only when our own carried-item speed is still active.
	if humanoid and humanoid.Parent
		and math.abs(humanoid.WalkSpeed - active.appliedSpeed) < 0.05
	then
		humanoid.WalkSpeed = active.baseSpeed
	end
end

local function attachCarryPenalty(player, tool, kind)
	clearCarryPenalty(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not tool or tool.Parent ~= character then
		return
	end
	local baseSpeed = math.max(0, finiteNumber(humanoid.WalkSpeed, 16))
	local factor = carrySpeedFactor(kind)
	local appliedSpeed = baseSpeed * factor
	local active = {
		tool = tool,
		humanoid = humanoid,
		kind = kind,
		baseSpeed = baseSpeed,
		appliedSpeed = appliedSpeed,
	}
	activeCarryByPlayer[player] = active
	tool:SetAttribute("CooperCarryKind", kind)
	tool:SetAttribute("CooperCarrySpeedFactor", factor)
	humanoid.WalkSpeed = appliedSpeed
	active.ancestryConnection = tool.AncestryChanged:Connect(function()
		task.defer(function()
			if activeCarryByPlayer[player] == active
				and (not player.Character or tool.Parent ~= player.Character)
			then
				clearCarryPenalty(player, tool)
			end
		end)
	end)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function missyToyHomeCFrame(toy)
	if not toy or not toy:IsA("Model") then
		return nil
	end
	local localCFrame = toy:GetAttribute("FamilyTaskHomeLocalCFrame")
	if typeof(localCFrame) ~= "CFrame" then
		local current = toy:GetPivot()
		local currentLocal = missyMattress.CFrame:ToObjectSpace(current)
		local insideMattress = math.abs(currentLocal.Position.X) <= missyMattress.Size.X * 0.5 + 0.25
			and math.abs(currentLocal.Position.Z) <= missyMattress.Size.Z * 0.5 + 0.25
		if insideMattress then
			localCFrame = currentLocal
		else
			local mattressTop = missyMattress.Size.Y * 0.5
			localCFrame = toy.Name == "MissyDetailedRabbit"
				and (CFrame.new(0.62, mattressTop + 0.97, 0.28) * CFrame.Angles(0, math.rad(12), 0))
				or (CFrame.new(-0.68, mattressTop + 0.93, 0.2) * CFrame.Angles(0, math.rad(-14), 0))
		end
		toy:SetAttribute("FamilyTaskHomeLocalCFrame", localCFrame)
	end
	local homeCFrame = missyMattress.CFrame * localCFrame
	toy:SetAttribute("FamilyTaskHomeCFrame", homeCFrame)
	toy:SetAttribute("FamilyTaskHomeAnchor", "MissyWalnutTwinBed.Mattress")
	return homeCFrame
end

for _, homeToyName in ipairs({ "MissyDetailedTeddyBear", "MissyDetailedRabbit" }) do
	local homeToy = environment:FindFirstChild(homeToyName, true)
	local homeCFrame = missyToyHomeCFrame(homeToy)
	local homeHandle = homeToy and (homeToy.PrimaryPart or homeToy:FindFirstChild("InteractionHandle", true))
	if homeCFrame and homeHandle and homeHandle:IsA("BasePart") then
		homeHandle.Anchored = true
		homeHandle.AssemblyLinearVelocity = Vector3.zero
		homeHandle.AssemblyAngularVelocity = Vector3.zero
		homeToy:PivotTo(homeCFrame)
	end
end

local function rootPart(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local part = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not part or not part:IsA("BasePart") then
		return nil
	end
	return part
end

local function near(player, instance, distance)
	local playerRoot = rootPart(player)
	if not playerRoot or not instance then
		return false
	end
	local position
	if instance:IsA("BasePart") then
		position = instance.Position
	elseif instance:IsA("Model") then
		position = instance:GetPivot().Position
	else
		local part = instance:FindFirstAncestorWhichIsA("BasePart")
		position = part and part.Position or nil
	end
	return position ~= nil and (playerRoot.Position - position).Magnitude <= distance
end

local function passCooldown(player, key, seconds)
	local byKey = promptCooldowns[player]
	if not byKey then
		byKey = {}
		promptCooldowns[player] = byKey
	end
	local now = serverNow()
	if (byKey[key] or 0) > now then
		return false
	end
	byKey[key] = now + seconds
	return true
end

local function snapshot(player)
	local ok, result = pcall(function()
		return familyAPI:Invoke("GetSnapshot", player)
	end)
	return ok and type(result) == "table" and result or nil
end

local function activeTask(player, id, step)
	local current = snapshot(player)
	local taskData = current and current.task
	if not taskData or taskData.id ~= id or taskData.automated == true then
		return nil
	end
	if step and taskData.step ~= step then
		return nil
	end
	return taskData, current
end

local function report(eventKey, player, metadata)
	reportAction:Fire(eventKey, player, metadata or {})
end

local boomboxParts = {}
local boomboxFloorPools = {}
local boomboxLights = {}
local boomboxDiscoLenses = {}
local boomboxSurfaceGuis = {}
local activeBoomboxSession = nil
local boomboxActivationInProgress = false
local autoplayRetryAt = {}
local lastAutoplayUserId = 0
local finishBoomboxPlayback

local function formatCountdown(seconds)
	local total = math.max(0, math.ceil(finiteNumber(seconds, 0)))
	return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

for _, descendant in ipairs(boomboxModel:GetDescendants()) do
	if descendant:IsA("BasePart") then
		local isPool = descendant:GetAttribute("BoomboxFloorPool") == true
			or string.find(descendant.Name, "FloorPool", 1, true) ~= nil
		local visibleTransparency = descendant:GetAttribute("BoomboxVisibleTransparency")
		if type(visibleTransparency) ~= "number" then
			visibleTransparency = descendant:GetAttribute("VisibleTransparency")
		end
		if type(visibleTransparency) ~= "number" then
			visibleTransparency = descendant.Transparency < 1 and descendant.Transparency or 0
		end
		local visibleCanCollide = descendant:GetAttribute("PlacedCanCollide")
		if type(visibleCanCollide) ~= "boolean" then
			visibleCanCollide = descendant:GetAttribute("BoomboxVisibleCanCollide")
		end
		if type(visibleCanCollide) ~= "boolean" then
			visibleCanCollide = descendant:GetAttribute("BoomboxCollisionHull") == true
				or descendant.Name == "CollisionHull"
				or descendant.CanCollide
		end
		local metadata = {
			part = descendant,
			visibleTransparency = math.clamp(visibleTransparency, 0, 1),
			playingTransparency = math.clamp(
				finiteNumber(descendant:GetAttribute("PlayingTransparency"), visibleTransparency),
				0,
				1
			),
			visibleCanCollide = visibleCanCollide,
		}
		if isPool then
			table.insert(boomboxFloorPools, metadata)
		else
			table.insert(boomboxParts, metadata)
		end
		if descendant:GetAttribute("BoomboxDiscoLens") == true
			or string.find(descendant.Name, "DiscoLens", 1, true) ~= nil
		then
			table.insert(boomboxDiscoLenses, descendant)
		end
	elseif descendant:IsA("Light") then
		table.insert(boomboxLights, {
			light = descendant,
			brightness = descendant.Brightness,
		})
	elseif descendant:IsA("SurfaceGui") then
		table.insert(boomboxSurfaceGuis, descendant)
	end
end

local discoPalette = {
	Color3.fromRGB(255, 65, 170),
	Color3.fromRGB(38, 210, 255),
	Color3.fromRGB(255, 195, 45),
	Color3.fromRGB(135, 82, 255),
	Color3.fromRGB(100, 255, 130),
}

local function invokeFamily(command, ...)
	local arguments = table.pack(...)
	local ok, result = pcall(function()
		return familyAPI:Invoke(command, table.unpack(arguments, 1, arguments.n))
	end)
	if not ok then
		warn(string.format("[CooperTaskWorld] %s failed: %s", tostring(command), tostring(result)))
		return nil
	end
	return result
end

-- Installed task-automation setpieces --------------------------------------
local function snapshotOwnsAutomation(current, upgradeId)
	local automation = current and current.automation
	local catalog = automation and automation.catalog
	if type(catalog) ~= "table" then
		return false
	end
	for key, entry in pairs(catalog) do
		if type(entry) == "table"
			and (entry.id == upgradeId or key == upgradeId)
			and entry.installed == true
		then
			return true
		end
	end
	return false
end

local function setAutomationRobotVisible(upgradeId, visible)
	local robot = taskAutomationRobots[upgradeId]
	if not robot then
		return
	end
	local renderVisible = visible
	local running = robot:GetAttribute("AutomationRunning") == true
	for _, descendant in ipairs(robot:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("AutomationRobotPart") == true then
			local runtimeControlled = running
				and descendant:GetAttribute("AutomationActiveTransparency") ~= nil
			if not runtimeControlled then
				local shownTransparency = finiteNumber(descendant:GetAttribute("AutomationVisibleTransparency"), 0)
				descendant.Transparency = renderVisible and math.clamp(shownTransparency, 0, 1) or 1
			end
			descendant.CanCollide = renderVisible and not running
				and descendant:GetAttribute("AutomationVisibleCanCollide") == true
				or false
			descendant.CanTouch = false
			descendant.CanQuery = descendant.CanCollide
		elseif descendant:IsA("Light") then
			descendant.Enabled = renderVisible and descendant:GetAttribute("AutomationVisibleEnabled") == true
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			local runtimeControlled = running
				and descendant:GetAttribute("AutomationActiveEnabled") ~= nil
			if not runtimeControlled then
				descendant.Enabled = renderVisible and descendant:GetAttribute("AutomationVisibleEnabled") == true
			end
		end
	end
	robot:SetAttribute("InstalledVisible", visible)
end

local function refreshAutomationVisibility()
	for upgradeId in pairs(taskAutomationRobots) do
		local visible = activeTaskAutomation[upgradeId] ~= nil
		if not visible then
			for _, candidate in ipairs(Players:GetPlayers()) do
				if snapshotOwnsAutomation(snapshot(candidate), upgradeId) then
					visible = true
					break
				end
			end
		end
		setAutomationRobotVisible(upgradeId, visible)
	end
end

local function restoreAutomationRobot(robot)
	local homePivot = robot:GetAttribute("HomePivot")
	if typeof(homePivot) == "CFrame" then
		robot:PivotTo(homePivot)
	end
	local upgradeId = tostring(robot:GetAttribute("UpgradeId") or robot.Name)
	local state = automationHomeState[upgradeId]
	for _, descendant in ipairs(robot:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local authored = state and state.parts[descendant]
			local homeCFrame = authored and authored.cframe or descendant:GetAttribute("AutomationHomeCFrame")
			local homeSize = authored and authored.size or descendant:GetAttribute("AutomationHomeSize")
			if typeof(homeCFrame) == "CFrame" then
				descendant.CFrame = homeCFrame
			end
			if typeof(homeSize) == "Vector3" then
				descendant.Size = homeSize
			end
			if authored then
				descendant.Color = authored.color
				descendant.Material = authored.material
				descendant.CanTouch = authored.canTouch
			end
			local shownTransparency = finiteNumber(descendant:GetAttribute("AutomationVisibleTransparency"), 0)
			descendant.Transparency = math.clamp(shownTransparency, 0, 1)
		elseif descendant:IsA("Light") then
			local authored = state and state.lights[descendant]
			if authored then
				descendant.Brightness = authored.brightness
				descendant.Color = authored.color
				descendant.Enabled = authored.enabled
			end
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			local authored = state and state.guis[descendant]
			if authored then
				descendant.Enabled = authored.enabled
			end
		end
	end
end

local function automationTokenActive(token)
	return token ~= nil
		and token.cancelled ~= true
		and activeTaskAutomation[token.upgradeId] == token
end

local function waitForAutomationToken(token, duration)
	local deadline = os.clock() + math.max(0, duration)
	while os.clock() < deadline do
		if not automationTokenActive(token) then
			return false
		end
		RunService.Heartbeat:Wait()
	end
	return automationTokenActive(token)
end

local function tweenModelPivot(model, targetCFrame, duration, token, onStep)
	if not model or not model:IsA("Model") then
		return false
	end
	local startCFrame = model:GetPivot()
	local startedAt = os.clock()
	local safeDuration = math.max(0.02, duration)
	repeat
		if not automationTokenActive(token) or not model.Parent then
			return false
		end
		local alpha = math.clamp((os.clock() - startedAt) / safeDuration, 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		local current = startCFrame:Lerp(targetCFrame, eased)
		model:PivotTo(current)
		if onStep then
			onStep(current, alpha)
		end
		RunService.Heartbeat:Wait()
	until alpha >= 1
	return automationTokenActive(token)
end

local function tweenRobotPivot(robot, targetCFrame, duration, token, onStep)
	return tweenModelPivot(robot, targetCFrame, duration, token, onStep)
end

local function tweenAutomationPart(item, targetCFrame, duration, token, onStep)
	if not item or not item:IsA("BasePart") or not automationTokenActive(token) then
		return false
	end
	local startCFrame = item.CFrame
	local startedAt = os.clock()
	local safeDuration = math.max(0.02, duration)
	repeat
		if not automationTokenActive(token) or not item.Parent then
			return false
		end
		local alpha = math.clamp((os.clock() - startedAt) / safeDuration, 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		item.CFrame = startCFrame:Lerp(targetCFrame, eased)
		if onStep then
			onStep(item.CFrame, alpha)
		end
		RunService.Heartbeat:Wait()
	until alpha >= 1
	return automationTokenActive(token)
end

local function tweenAutomationHinge(item, hingeCFrame, closedOffset, startAngle, endAngle, duration, token)
	local startedAt = os.clock()
	local safeDuration = math.max(0.02, duration)
	repeat
		if not automationTokenActive(token) or not item or not item.Parent then
			return false
		end
		local alpha = math.clamp((os.clock() - startedAt) / safeDuration, 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		local angle = startAngle + (endAngle - startAngle) * eased
		item.CFrame = hingeCFrame * CFrame.Angles(0, angle, 0) * closedOffset
		RunService.Heartbeat:Wait()
	until alpha >= 1
	return automationTokenActive(token)
end

local function tweenAutomationParts(targets, duration, token, onStep)
	local starts = {}
	for part in pairs(targets) do
		if part and part:IsA("BasePart") and part.Parent then
			starts[part] = part.CFrame
		end
	end
	local startedAt = os.clock()
	local safeDuration = math.max(0.02, duration)
	repeat
		if not automationTokenActive(token) then
			return false
		end
		local alpha = math.clamp((os.clock() - startedAt) / safeDuration, 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		for part, startCFrame in pairs(starts) do
			if not part.Parent then
				return false
			end
			part.CFrame = startCFrame:Lerp(targets[part], eased)
		end
		if onStep then
			onStep(alpha)
		end
		RunService.Heartbeat:Wait()
	until alpha >= 1
	return automationTokenActive(token)
end

local automationEnvelope
local automationObstaclesAtPose

local function travelRobotPath(robot, positions, duration, token, onStep, motionStyle)
	local points = { robot:GetPivot().Position }
	for _, position in ipairs(positions) do
		if typeof(position) == "Vector3" and (position - points[#points]).Magnitude > 0.015 then
			table.insert(points, position)
		end
	end
	if #points <= 1 then
		return automationTokenActive(token)
	end

	local segmentLengths = {}
	local cumulative = { 0 }
	local totalDistance = 0
	for index = 1, #points - 1 do
		local length = (points[index + 1] - points[index]).Magnitude
		segmentLengths[index] = length
		totalDistance += length
		cumulative[index + 1] = totalDistance
	end
	if totalDistance <= 0.001 then
		return automationTokenActive(token)
	end

	local function pointAtDistance(distance)
		local clamped = math.clamp(distance, 0, totalDistance)
		for index = 1, #segmentLengths do
			local segmentEnd = cumulative[index + 1]
			if clamped <= segmentEnd or index == #segmentLengths then
				local length = math.max(0.001, segmentLengths[index])
				local alpha = math.clamp((clamped - cumulative[index]) / length, 0, 1)
				return points[index]:Lerp(points[index + 1], alpha)
			end
		end
		return points[#points]
	end

	local startedAt = os.clock()
	local lastUpdate = startedAt
	local safeDuration = math.max(0.05, duration)
	local initialLook = robot:GetPivot().LookVector
	local initialPlanar = Vector3.new(initialLook.X, 0, initialLook.Z)
	local currentFacing = if initialPlanar.Magnitude > 0.01 then initialPlanar.Unit else Vector3.new(0, 0, -1)
	local isFlight = motionStyle == "flight"
	local isReverse = motionStyle == "reverse"
	local isStrafe = motionStyle == "strafe"
	local liveEnvelope = automationEnvelope(robot, 0, 0)
	local liveInitial = automationObstaclesAtPose(
		robot,
		robot:GetPivot().Position,
		liveEnvelope,
		currentFacing,
		true
	)
	local blockedSince = nil
	repeat
		if not automationTokenActive(token) or not robot.Parent then
			return false
		end
		local now = os.clock()
		local alpha = math.clamp((now - startedAt) / safeDuration, 0, 1)
		local eased = alpha * alpha * alpha * (alpha * (alpha * 6 - 15) + 10)
		local travelled = totalDistance * eased
		local position = pointAtDistance(travelled)
		local lookDistance = math.clamp(totalDistance * 0.035, 0.45, 1.25)
		local behind = pointAtDistance(math.max(0, travelled - lookDistance * 0.35))
		local ahead = pointAtDistance(math.min(totalDistance, travelled + lookDistance))
		local tangent = Vector3.new(ahead.X - behind.X, 0, ahead.Z - behind.Z)
		if tangent.Magnitude > 0.015 and not isStrafe then
			local desiredFacing = if isReverse then -tangent.Unit else tangent.Unit
			local turnBlend = math.clamp((now - lastUpdate) * (isFlight and 7.5 or 10.5), 0, 1)
			local blended = currentFacing:Lerp(desiredFacing, turnBlend)
			if blended.Magnitude > 0.01 then
				currentFacing = blended.Unit
			end
		end
		local sensorDistance = math.min(totalDistance, travelled + (isFlight and 0.70 or 0.95))
		local sensorPosition = pointAtDistance(sensorDistance)
		local sensorFacing = if isStrafe
			then currentFacing
			else if tangent.Magnitude > 0.015
			then (if isReverse then -tangent.Unit else tangent.Unit)
			else currentFacing
		local blocked = false
		local blockingNames = {}
		for part in pairs(automationObstaclesAtPose(
			robot,
			sensorPosition,
			liveEnvelope,
			sensorFacing,
			true
		)) do
			if not (liveInitial[part] and travelled <= liveEnvelope.radius * 1.85) then
				blocked = true
				table.insert(blockingNames, part:GetFullName())
			end
		end
		if blocked then
			blockedSince = blockedSince or now
			startedAt += math.max(0, now - lastUpdate)
			lastUpdate = now
			alpha = math.min(alpha, 0.999)
			if now - blockedSince > 6 then
				table.sort(blockingNames)
				local bodyPosition = robot:GetPivot().Position
				warn(string.format(
					"[CooperAutomation] %s stopped for a persistent route obstruction at "
						.. "body(%.2f, %.2f, %.2f) sensor(%.2f, %.2f, %.2f): %s",
					robot.Name,
					bodyPosition.X,
					bodyPosition.Y,
					bodyPosition.Z,
					sensorPosition.X,
					sensorPosition.Y,
					sensorPosition.Z,
					#blockingNames > 0 and table.concat(blockingNames, ", ") or "unknown obstacle"
				))
				return false
			end
			if onStep then
				onStep(robot:GetPivot(), alpha)
			end
			RunService.Heartbeat:Wait()
		else
			blockedSince = nil
			lastUpdate = now

			local displayPosition = position
			local bank = 0
			if isFlight then
				local bob = math.sin(travelled * 1.7) * math.sin(math.pi * alpha) * 0.055
				displayPosition += Vector3.new(0, bob, 0)
				local cross = currentFacing.X * tangent.Z - currentFacing.Z * tangent.X
				bank = math.clamp(cross * 0.10, -math.rad(4), math.rad(4)) * math.sin(math.pi * alpha)
			end
			local displayFacing = currentFacing
			if not isFlight then
				local planarSpan = Vector3.new(ahead.X - behind.X, 0, ahead.Z - behind.Z).Magnitude
				if planarSpan > 0.05 then
					local pitch = math.clamp(
						math.atan2(ahead.Y - behind.Y, planarSpan),
						-math.rad(7),
						math.rad(7)
					)
					displayFacing = currentFacing * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
				end
			end
			local current = CFrame.lookAt(displayPosition, displayPosition + displayFacing)
			if isFlight and math.abs(bank) > 0.0001 then
				current *= CFrame.Angles(0, 0, bank)
			end
			robot:PivotTo(current)
			if onStep then
				onStep(current, alpha)
			end
			RunService.Heartbeat:Wait()
		end
	until alpha >= 1
	return automationTokenActive(token)
end

local function setBeamBetween(part, pointA, pointB, minimumLength)
	if not part or not part:IsA("BasePart") then
		return
	end
	local delta = pointB - pointA
	local length = math.max(minimumLength or 0.04, delta.Magnitude)
	local direction = if delta.Magnitude > 0.001 then delta.Unit else part.CFrame.LookVector
	part.Size = Vector3.new(part.Size.X, part.Size.Y, length)
	part.CFrame = CFrame.lookAt((pointA + pointB) * 0.5, (pointA + pointB) * 0.5 + direction)
end

local function reversePositions(positions)
	local reversed = {}
	for index = #positions, 1, -1 do
		table.insert(reversed, positions[index])
	end
	return reversed
end

automationEnvelope = function(model, minimumRadius, minimumHeight)
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local radius = math.max(
		minimumRadius or 0,
		math.sqrt(boundingSize.X * boundingSize.X + boundingSize.Z * boundingSize.Z) * 0.5 + 0.12
	)
	local height = math.max(minimumHeight or 0, boundingSize.Y - 0.04)
	return {
		radius = radius,
		height = height,
		centerYOffset = boundingCFrame.Position.Y - pivot.Position.Y,
		boundsRelative = pivot:ToObjectSpace(boundingCFrame),
		querySize = Vector3.new(
			boundingSize.X + 0.24,
			math.max(0.20, boundingSize.Y + 0.16),
			boundingSize.Z + 0.24
		),
	}
end

local function automationPartIsObstacle(part, boxBottom, movingModel, includeCharacters)
	if not part or not part:IsA("BasePart") or part:IsDescendantOf(movingModel) then
		return false
	end
	if part == dropZone or part:IsDescendantOf(route) then
		return false
	end
	if part:IsDescendantOf(truck) and truck:GetAttribute("Hidden") == true then
		return false
	end
	local ancestor = part.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor:FindFirstChildOfClass("Humanoid") and not includeCharacters then
			return false
		end
		ancestor = ancestor.Parent
	end
	if part.Transparency >= 0.96 and not part.CanCollide then
		return false
	end
	local partTop = part.Position.Y
		+ math.abs(part.CFrame.RightVector.Y) * part.Size.X * 0.5
		+ math.abs(part.CFrame.UpVector.Y) * part.Size.Y * 0.5
		+ math.abs(part.CFrame.LookVector.Y) * part.Size.Z * 0.5
	local lowerName = string.lower(part.Name)
	local authoredSupport = string.find(lowerName, "floor", 1, true)
		or string.find(lowerName, "carpet", 1, true)
		or string.find(lowerName, "rug", 1, true)
		or string.find(lowerName, "mat", 1, true)
		or string.find(lowerName, "runner", 1, true)
		or string.find(lowerName, "linoleum", 1, true)
		or string.find(lowerName, "driveway", 1, true)
		or string.find(lowerName, "deck", 1, true)
		or string.find(lowerName, "step", 1, true)
		or string.find(lowerName, "threshold", 1, true)
		or string.find(lowerName, "landing", 1, true)
		or string.find(lowerName, "lot", 1, true)
		or string.find(lowerName, "street", 1, true)
		or string.find(lowerName, "subfloor", 1, true)
	if authoredSupport
		and math.abs(part.CFrame.UpVector.Y) >= 0.90
		-- Includes the padded undercarriage while climbing onto DenPatioLanding.
		and partTop <= boxBottom + 0.92
	then
		return false
	end
	if partTop <= boxBottom + 0.14 then
		return false
	end
	return true
end

automationObstaclesAtPose = function(model, position, envelope, facing, includeCharacters)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local planarFacing = facing and Vector3.new(facing.X, 0, facing.Z) or Vector3.zero
	if planarFacing.Magnitude <= 0.01 then
		local look = model:GetPivot().LookVector
		planarFacing = Vector3.new(look.X, 0, look.Z)
	end
	if planarFacing.Magnitude <= 0.01 then
		planarFacing = Vector3.new(0, 0, -1)
	end
	local pivotPose = CFrame.lookAt(position, position + planarFacing.Unit)
	local boundsPose = pivotPose * envelope.boundsRelative
	local boxBottom = boundsPose.Position.Y - envelope.querySize.Y * 0.5
	local obstacles = {}
	for _, part in ipairs(workspace:GetPartBoundsInBox(
		boundsPose,
		envelope.querySize,
		params
	)) do
		if automationPartIsObstacle(part, boxBottom, model, includeCharacters == true) then
			obstacles[part] = true
		end
	end
	return obstacles
end

local function automationPathObstacles(model, positions, envelope, startOverride, motionStyle)
	local start = typeof(startOverride) == "Vector3" and startOverride or model:GetPivot().Position
	local reverseFacing = motionStyle == "reverse"
	local fixedFacing = motionStyle == "strafe"
	local initialLook = model:GetPivot().LookVector
	local initialFacing = Vector3.new(initialLook.X, 0, initialLook.Z)
	if initialFacing.Magnitude <= 0.01 then
		initialFacing = Vector3.new(0, 0, -1)
	else
		initialFacing = initialFacing.Unit
	end
	local initial = automationObstaclesAtPose(model, start, envelope, initialFacing)
	local found = {}
	local previous = start
	local previousFacing = initialFacing
	local travelled = 0
	local function recordAt(samplePosition, facing, sampleDistance)
		for part in pairs(automationObstaclesAtPose(model, samplePosition, envelope, facing)) do
			if not (initial[part] and sampleDistance <= envelope.radius * 1.85) then
				found[part] = true
			end
		end
	end
	for _, position in ipairs(positions) do
		local distance = (position - previous).Magnitude
		local planar = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z)
		local segmentFacing = if fixedFacing
			then initialFacing
			else if planar.Magnitude > 0.01
				then (if reverseFacing then -planar.Unit else planar.Unit)
			else previousFacing
		if previousFacing:Dot(segmentFacing) < 0.999 then
			local fromRotation = CFrame.lookAt(Vector3.zero, previousFacing).Rotation
			local toRotation = CFrame.lookAt(Vector3.zero, segmentFacing).Rotation
			for turnSample = 1, 8 do
				local rotation = fromRotation:Lerp(toRotation, turnSample / 8)
				recordAt(previous, rotation.LookVector, travelled)
			end
		end
		local samples = math.max(1, math.ceil(distance / 0.32))
		for sample = 1, samples do
			local samplePosition = previous:Lerp(position, sample / samples)
			local sampleDistance = travelled + distance * sample / samples
			recordAt(samplePosition, segmentFacing, sampleDistance)
		end
		travelled += distance
		previous = position
		previousFacing = segmentFacing
	end
	return found
end

local function groundAutomationPlans(model, plans, agentHeight, groundClearance)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model, taskVisuals, deliveryWorld, stations }
	rayParams.RespectCanCollide = true
	local grounded = {}
	for _, plan in ipairs(plans) do
		local probeRise = math.max(2.25, agentHeight + 0.60)
		local expectedSupportY = plan.Y - groundClearance
		local highestWalkableSupportY = expectedSupportY + 0.78
		local rayBottomY = plan.Y - 6
		local cursorY = plan.Y + probeRise
		local hit = nil
		for _ = 1, 8 do
			if cursorY <= rayBottomY then
				break
			end
			local candidate = workspace:Raycast(
				Vector3.new(plan.X, cursorY, plan.Z),
				Vector3.new(0, rayBottomY - cursorY, 0),
				rayParams
			)
			if not candidate then
				break
			end
			if candidate.Position.Y <= highestWalkableSupportY + 0.03 then
				hit = candidate
				break
			end

			local blocker = candidate.Instance
			if blocker and blocker:IsA("BasePart") then
				local verticalRadius = math.abs(blocker.CFrame.RightVector.Y) * blocker.Size.X * 0.5
					+ math.abs(blocker.CFrame.UpVector.Y) * blocker.Size.Y * 0.5
					+ math.abs(blocker.CFrame.LookVector.Y) * blocker.Size.Z * 0.5
				cursorY = math.min(
					candidate.Position.Y - 0.03,
					blocker.Position.Y - verticalRadius - 0.03
				)
			else
				cursorY = candidate.Position.Y - 0.03
			end
		end
		local y = (hit and hit.Position.Y or plan.Y) + groundClearance
		table.insert(grounded, Vector3.new(plan.X, y, plan.Z))
	end
	return grounded
end

local function computeGroundedAutomationPath(
	model,
	destination,
	agentRadius,
	agentHeight,
	groundClearance,
	fallback,
	startOverride
)
	local envelope = automationEnvelope(model, agentRadius, agentHeight)
	local start = typeof(startOverride) == "Vector3" and startOverride or model:GetPivot().Position
	local path = PathfindingService:CreatePath({
		AgentRadius = envelope.radius,
		AgentHeight = envelope.height,
		AgentCanJump = false,
		WaypointSpacing = 2.5,
	})
	local ok = pcall(function()
		path:ComputeAsync(start, destination)
	end)
	local plans = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			table.insert(plans, waypoint.Position)
		end
	end
	local grounded = groundAutomationPlans(model, plans, envelope.height, groundClearance)
	local obstacles = automationPathObstacles(model, grounded, envelope, start)
	if next(obstacles) == nil and #grounded > 0 then
		return grounded, envelope
	end

	if type(fallback) == "table" then
		local groundedFallback = groundAutomationPlans(model, fallback, envelope.height, groundClearance)
		local fallbackObstacles = automationPathObstacles(model, groundedFallback, envelope, start)
		if next(fallbackObstacles) == nil and #groundedFallback > 0 then
			return groundedFallback, envelope
		end
	end

	local names = {}
	for part in pairs(obstacles) do
		table.insert(names, part:GetFullName())
		if #names >= 4 then
			break
		end
	end
	warn(string.format(
		"[CooperAutomation] No collision-safe path for %s (%s)",
		model:GetFullName(),
		#names > 0 and table.concat(names, ", ") or tostring(path.Status)
	))
	return {}, envelope
end

local function computeGroundedAutomationRoute(
	model,
	destinations,
	agentRadius,
	agentHeight,
	groundClearance
)
	local combined = {}
	local start = model:GetPivot().Position
	for _, destination in ipairs(destinations) do
		local leg = computeGroundedAutomationPath(
			model,
			destination,
			agentRadius,
			agentHeight,
			groundClearance,
			nil,
			start
		)
		if #leg == 0 then
			return {}
		end
		for _, position in ipairs(leg) do
			if #combined == 0 or (position - combined[#combined]).Magnitude > 0.05 then
				table.insert(combined, position)
			end
		end
		start = combined[#combined]
	end
	return combined
end

local function prepareGroundedAutomationPlans(
	model,
	plans,
	minimumRadius,
	minimumHeight,
	groundClearance,
	startOverride,
	motionStyle,
	routeLabel
)
	local envelope = automationEnvelope(model, minimumRadius, minimumHeight)
	local start = typeof(startOverride) == "Vector3" and startOverride or model:GetPivot().Position
	local grounded = groundAutomationPlans(model, plans, envelope.height, groundClearance)
	local obstacles = automationPathObstacles(model, grounded, envelope, start, motionStyle)
	if next(obstacles) == nil and #grounded > 0 then
		return grounded
	end
	local names = {}
	for part in pairs(obstacles) do
		table.insert(names, part:GetFullName())
		if #names >= 4 then
			break
		end
	end
	warn(string.format(
		"[CooperAutomation] Authored route rejected [%s] for %s (%s)",
		type(routeLabel) == "string" and routeLabel or "unlabeled",
		model:GetFullName(),
		#names > 0 and table.concat(names, ", ") or "empty route"
	))
	return {}
end

local function prepareAerialAutomationPlans(model, plans, startOverride)
	local envelope = automationEnvelope(model, 0, 0)
	local start = typeof(startOverride) == "Vector3" and startOverride or model:GetPivot().Position
	local obstacles = automationPathObstacles(model, plans, envelope, start)
	if next(obstacles) == nil and #plans > 0 then
		return plans
	end
	local names = {}
	for part in pairs(obstacles) do
		table.insert(names, part:GetFullName())
		if #names >= 4 then
			break
		end
	end
	warn(string.format(
		"[CooperAutomation] Aerial route rejected for %s (%s)",
		model:GetFullName(),
		#names > 0 and table.concat(names, ", ") or "empty route"
	))
	return {}
end

local function invokeAutomationDoor(door, command, argument)
	local api = door and door:FindFirstChild("AutomationDoorCommand")
	if not api or not api:IsA("BindableFunction") then
		return false, nil
	end
	local ok, success, state, extra, original = pcall(function()
		return api:Invoke(command, argument)
	end)
	return ok and success == true, state, extra, original
end

local function automationPartsWithAttribute(rootInstance, attributeName)
	local parts = {}
	if not rootInstance then
		return parts
	end
	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute(attributeName) == true then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function setAutomationPartsActive(parts, active)
	for _, part in ipairs(parts) do
		if part.Parent then
			part.Transparency = active
				and math.clamp(finiteNumber(part:GetAttribute("AutomationActiveTransparency"), 0), 0, 1)
				or 1
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
end

local function makeWheelAnimator(model, namePattern)
	local relative = {}
	local wheelRadius = {}
	local pivot = model:GetPivot()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and string.find(descendant.Name, namePattern, 1, true) then
			relative[descendant] = pivot:ToObjectSpace(descendant.CFrame)
			wheelRadius[descendant] = math.max(0.1, math.max(descendant.Size.Y, descendant.Size.Z) * 0.5)
		end
	end
	local lastPosition = pivot.Position
	local spin = 0
	return function(currentPivot)
		local distance = (currentPivot.Position - lastPosition).Magnitude
		lastPosition = currentPivot.Position
		spin += distance
		for wheel, offset in pairs(relative) do
			if wheel.Parent then
				wheel.CFrame = currentPivot * offset * CFrame.Angles(spin / wheelRadius[wheel], 0, 0)
			end
		end
	end
end

local function makeRotorAnimator(model)
	local relative = {}
	local direction = {}
	local pivot = model:GetPivot()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and string.find(descendant.Name, "Rotor", 1, true)
			and not string.find(descendant.Name, "Strut", 1, true)
		then
			relative[descendant] = pivot:ToObjectSpace(descendant.CFrame)
			direction[descendant] = string.find(descendant.Name, "Left", 1, true) and -1 or 1
		end
	end
	local lastUpdate = os.clock()
	local spin = 0
	return function(currentPivot)
		local now = os.clock()
		spin += math.min(0.1, now - lastUpdate) * 40
		lastUpdate = now
		for rotor, offset in pairs(relative) do
			if rotor.Parent then
				rotor.CFrame = currentPivot * offset * CFrame.Angles(spin * direction[rotor], 0, 0)
			end
		end
	end
end

local function runBeerBot(robot, duration, token)
	if not automationTokenActive(token) then
		return
	end
	-- The authored BeerRunner phases originally totaled 1.153 * duration, so the
	-- authoritative automation token could expire while the cart was still on its
	-- way home. Preserve the relative pacing while reserving 13.5% of every cycle
	-- for door handshakes, grounding queries, Heartbeat scheduling, and cleanup.
	local function phaseDuration(fraction)
		return duration * fraction * 0.75
	end
	local finger = robot:FindFirstChild("TypingFinger")
	local wrist = robot:FindFirstChild("TypingArmWrist")
	local status = robot:FindFirstChild("OrderLight")
	local runner = robot:FindFirstChild("BeerRunner")
	local beerCase = robot:FindFirstChild("BeerCaseVisual")
	local runnerWheelLeft = runner and runner:FindFirstChild("RunnerWheelLeft")
	local runnerWheelRight = runner and runner:FindFirstChild("RunnerWheelRight")
	local runnerLiftMast = runner and runner:FindFirstChild("RunnerLiftMast")
	local runnerLiftArm = runner and runner:FindFirstChild("RunnerLiftArm")
	local runnerGrabberLeft = runner and runner:FindFirstChild("RunnerGrabberLeft")
	local runnerGrabberRight = runner and runner:FindFirstChild("RunnerGrabberRight")
	local fingerHome = finger and finger:GetAttribute("AutomationHomeCFrame")
	local frontDoor = environment:FindFirstChild("InteractiveFrontDoor", true)
	local fridge = environment:FindFirstChild("WhiteHotpointRefrigerator", true)
	local fridgeInterior = fridge and fridge:FindFirstChild("CooperFridgeInterior")
	local refrigeratorBody = fridge and fridge:FindFirstChild("RefrigeratorBody")
	local beerPromptAnchor = fridgeInterior and fridgeInterior:FindFirstChild("BeerPromptAnchor", true)
	local bedroomFloor = environment:FindFirstChild("TwinsGreenGrayCarpet", true)
	local kitchenReferenceFloor = environment:FindFirstChild("KitchenPatternLinoleum", true)
	local denBaseboard = environment:FindFirstChild("Baseboard2", true)
	if not (finger and finger:IsA("BasePart")
		and wrist and wrist:IsA("BasePart")
		and runner and runner:IsA("Model")
		and runnerWheelLeft and runnerWheelLeft:IsA("BasePart")
		and runnerWheelRight and runnerWheelRight:IsA("BasePart")
		and runnerLiftMast and runnerLiftMast:IsA("BasePart")
		and runnerLiftArm and runnerLiftArm:IsA("BasePart")
		and runnerGrabberLeft and runnerGrabberLeft:IsA("BasePart")
		and runnerGrabberRight and runnerGrabberRight:IsA("BasePart")
		and beerCase and beerCase:IsA("Model")
		and frontDoor and frontDoor:IsA("Model")
		and fridge and fridge:IsA("Model")
		and fridgeInterior and fridgeInterior:IsA("Model")
		and refrigeratorBody and refrigeratorBody:IsA("BasePart")
		and beerPromptAnchor and beerPromptAnchor:IsA("BasePart")
		and bedroomFloor and bedroomFloor:IsA("BasePart")
		and kitchenReferenceFloor and kitchenReferenceFloor:IsA("BasePart")
		and denBaseboard and denBaseboard:IsA("BasePart")
		and typeof(fingerHome) == "CFrame")
	then
		waitForAutomationToken(token, duration)
		return
	end

	local runnerHome = runner:GetAttribute("HomePivot")
	if typeof(runnerHome) ~= "CFrame" then
		runnerHome = runner:GetPivot()
	end
	local caseHome = beerCase:GetAttribute("HomePivot")
	if typeof(caseHome) ~= "CFrame" then
		caseHome = beerCase:GetPivot()
	end
	local caseParts = automationPartsWithAttribute(beerCase, "AutomationBeerCasePart")
	local function setCaseActive(active)
		setAutomationPartsActive(caseParts, active)
		for _, descendant in ipairs(beerCase:GetDescendants()) do
			if descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
				descendant.Enabled = active and descendant:GetAttribute("AutomationActiveEnabled") == true
			end
		end
	end
	local frontHeld = false
	local frontOriginalOpen = nil
	local fridgeHeld = false
	local fridgeOriginalOpen = nil
	local cleanupDone = false
	local function cleanup()
		if cleanupDone then
			return
		end
		cleanupDone = true
		if beerCase.Parent ~= robot then
			beerCase.Parent = robot
		end
		beerCase:PivotTo(caseHome)
		setCaseActive(false)
		if fridgeHeld then
			invokeAutomationDoor(fridge, "ReleaseHoldOpen", fridgeOriginalOpen)
			fridgeHeld = false
		end
		if frontHeld then
			invokeAutomationDoor(frontDoor, "ReleaseHoldOpen", frontOriginalOpen)
			frontHeld = false
		end
	end
	token.cleanup = cleanup

	local function setRunnerLiftPose(gripPosition, spread, caseCFrame)
		local basis = runner:GetPivot()
		local shoulder = basis:PointToWorldSpace(Vector3.new(0, 1.38, 0.17))
		setBeamBetween(runnerLiftArm, shoulder, gripPosition, 0.10)
		local halfSpread = math.max(0.12, spread * 0.5)
		local rotation = basis.Rotation
		runnerGrabberLeft.CFrame = CFrame.new(gripPosition - basis.RightVector * halfSpread) * rotation
		runnerGrabberRight.CFrame = CFrame.new(gripPosition + basis.RightVector * halfSpread) * rotation
		if caseCFrame then
			beerCase:PivotTo(caseCFrame)
		end
	end

	local function animateRunnerLift(
		startGrip,
		endGrip,
		startSpread,
		endSpread,
		startCase,
		endCase,
		seconds
	)
		local started = os.clock()
		local safeDuration = math.max(0.02, seconds)
		repeat
			if not automationTokenActive(token) then
				return false
			end
			local alpha = math.clamp((os.clock() - started) / safeDuration, 0, 1)
			local eased = alpha * alpha * (3 - 2 * alpha)
			local cargo = startCase and endCase and startCase:Lerp(endCase, eased) or nil
			setRunnerLiftPose(
				startGrip:Lerp(endGrip, eased),
				startSpread + (endSpread - startSpread) * eased,
				cargo
			)
			RunService.Heartbeat:Wait()
		until alpha >= 1
		return automationTokenActive(token)
	end

	local wristAxis = wrist.CFrame.LookVector
	local wristA = wrist.Position - wristAxis * wrist.Size.Z * 0.5
	local wristB = wrist.Position + wristAxis * wrist.Size.Z * 0.5
	local movingEndpoint = if (wristA - finger.Position).Magnitude <= (wristB - finger.Position).Magnitude
		then wristA
		else wristB
	local fixedEndpoint = if movingEndpoint == wristA then wristB else wristA
	local endpointInFinger = fingerHome:PointToObjectSpace(movingEndpoint)
	local startedAt = os.clock()
	local typingDuration = math.max(1.8, phaseDuration(0.08))
	while os.clock() - startedAt < typingDuration and automationTokenActive(token) do
		local phase = (os.clock() - startedAt) * 13
		finger.CFrame = fingerHome * CFrame.new(0, -0.10 * math.max(0, math.sin(phase)), 0)
		setBeamBetween(wrist, fixedEndpoint, finger.CFrame:PointToWorldSpace(endpointInFinger), 0.05)
		if status and status:IsA("BasePart") then
			status.Color = if math.sin(phase) > 0 then Color3.fromRGB(255, 221, 75) else Color3.fromRGB(95, 235, 112)
		end
		RunService.Heartbeat:Wait()
	end
	if not automationTokenActive(token) then
		cleanup()
		return
	end

	local acquired, _, _, originalOpen = invokeAutomationDoor(frontDoor, "AcquireHoldOpen")
	frontHeld = acquired
	frontOriginalOpen = originalOpen
	if not acquired then
		cleanup()
		return
	end

	local bedroomTop = bedroomFloor.Position.Y + bedroomFloor.Size.Y * 0.5
	local runnerClearance = runnerHome.Position.Y - bedroomTop
	local referenceX = -13.920001
	local referenceZ = 41.944015
	local function houseGroundPoint(x, z)
		return kitchenReferenceFloor.CFrame:PointToWorldSpace(Vector3.new(
			x - referenceX,
			runnerHome.Position.Y - kitchenReferenceFloor.Position.Y,
			z - referenceZ
		))
	end
	local baseboardNorthPlan = houseGroundPoint(2.0, 49.80)
	local baseboardSouthPlan = houseGroundPoint(2.0, 48.25)
	local runnerBoundsCFrame, runnerBoundsSize = runner:GetBoundingBox()
	local runnerBottomFromPivot = runnerBoundsCFrame.Position.Y
		- runner:GetPivot().Position.Y
		- runnerBoundsSize.Y * 0.5
	local denBaseboardTop = denBaseboard.Position.Y
		+ math.abs(denBaseboard.CFrame.RightVector.Y) * denBaseboard.Size.X * 0.5
		+ math.abs(denBaseboard.CFrame.UpVector.Y) * denBaseboard.Size.Y * 0.5
		+ math.abs(denBaseboard.CFrame.LookVector.Y) * denBaseboard.Size.Z * 0.5
	local baseboardLiftY = denBaseboardTop - runnerBottomFromPivot + 0.12
	local caseStagePlan = houseGroundPoint(-28.000, 52.159)
	local caseRayParams = RaycastParams.new()
	caseRayParams.FilterType = Enum.RaycastFilterType.Exclude
	caseRayParams.FilterDescendantsInstances = { robot, taskVisuals, deliveryWorld, stations }
	caseRayParams.RespectCanCollide = true
	local caseGroundHit = workspace:Raycast(
		caseStagePlan + Vector3.new(0, 4, 0),
		Vector3.new(0, -9, 0),
		caseRayParams
	)
	local caseBounds, caseBoundsSize = beerCase:GetBoundingBox()
	local caseBottomFromPivot = caseBounds.Position.Y - beerCase:GetPivot().Position.Y - caseBoundsSize.Y * 0.5
	local caseGroundY = caseGroundHit and caseGroundHit.Position.Y or (caseStagePlan.Y - runnerClearance)
	local caseStage = CFrame.new(
		caseStagePlan.X,
		caseGroundY - caseBottomFromPivot,
		caseStagePlan.Z
	) * caseHome.Rotation
	beerCase:PivotTo(caseStage)
	setCaseActive(true)
	local dropApproach = houseGroundPoint(-27.820, 50.700)
	local outboundNorthPlans = {
		houseGroundPoint(1.75, 55.0),
		baseboardNorthPlan,
	}
	local pathToBaseboard = prepareGroundedAutomationPlans(
		runner,
		outboundNorthPlans,
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position
	)
	local beerRunnerWheelAnimator = makeWheelAnimator(runner, "RunnerWheel")
	local function animateBeerRunnerWheels(currentPivot)
		beerRunnerWheelAnimator(currentPivot)
	end
	if #pathToBaseboard == 0
		or not travelRobotPath(runner, pathToBaseboard, phaseDuration(0.035), token, animateBeerRunnerWheels)
	then
		cleanup()
		return
	end

	local groundedBaseboardSouth = groundAutomationPlans(
		runner,
		{ baseboardSouthPlan },
		2.20,
		runnerClearance
	)[1]
	local baseboardCrossing = prepareAerialAutomationPlans(
		runner,
		{
			Vector3.new(runner:GetPivot().Position.X, baseboardLiftY, runner:GetPivot().Position.Z),
			Vector3.new(groundedBaseboardSouth.X, baseboardLiftY, groundedBaseboardSouth.Z),
			groundedBaseboardSouth,
		},
		runner:GetPivot().Position
	)
	if #baseboardCrossing == 0
		or not travelRobotPath(runner, baseboardCrossing, phaseDuration(0.025), token, animateBeerRunnerWheels)
	then
		cleanup()
		return
	end

	local outboundSouthPlans = {
		houseGroundPoint(2.25, 45.0),
		houseGroundPoint(0.8, 39.0),
		houseGroundPoint(-0.8, 34.3),
		houseGroundPoint(-2.3, 29.5),
		houseGroundPoint(-3.8, 24.8),
		houseGroundPoint(-5.3, 20.4),
		houseGroundPoint(-6.392, 18.67),
		houseGroundPoint(-6.392, 15.45),
		houseGroundPoint(-6.392, 12.73),
		houseGroundPoint(-6.392, 11.704),
		houseGroundPoint(-10.8, 10.70),
		houseGroundPoint(-22.6, 10.70),
		houseGroundPoint(-27.82, 10.70),
		dropApproach,
	}
	local pathToCase = prepareGroundedAutomationPlans(
		runner,
		outboundSouthPlans,
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position
	)
	if #pathToCase == 0
		or not travelRobotPath(runner, pathToCase, phaseDuration(0.26), token, animateBeerRunnerWheels)
	then
		cleanup()
		return
	end

	local casePosition = beerCase:GetPivot().Position
	local faceCase = CFrame.lookAt(
		runner:GetPivot().Position,
		Vector3.new(casePosition.X, runner:GetPivot().Position.Y, casePosition.Z)
	)
	if not tweenRobotPivot(runner, faceCase, phaseDuration(0.015), token, animateBeerRunnerWheels) then
		cleanup()
		return
	end
	local _, caseSize = beerCase:GetBoundingBox()
	local caseAtStage = beerCase:GetPivot()
	local caseGrip = caseAtStage.Position + Vector3.new(0, caseSize.Y * 0.18, 0)
	local aboveCaseGrip = caseGrip + Vector3.new(0, caseSize.Y * 0.65 + 0.35, 0)
	local homeGrip = runner:GetPivot():PointToWorldSpace(Vector3.new(0, 1.17, -0.47))
	setRunnerLiftPose(homeGrip, 1.20, caseAtStage)
	if not animateRunnerLift(
		homeGrip, aboveCaseGrip, 1.20, 1.24,
		caseAtStage, caseAtStage, phaseDuration(0.018)
	) or not animateRunnerLift(
		aboveCaseGrip, caseGrip, 1.24, 1.24,
		caseAtStage, caseAtStage, phaseDuration(0.018)
	) or not animateRunnerLift(
		caseGrip, caseGrip, 1.24, 1.02,
		caseAtStage, caseAtStage, phaseDuration(0.012)
	) then
		cleanup()
		return
	end
	local liftedCase = CFrame.new(caseAtStage.Position + Vector3.new(0, 0.78, 0)) * caseAtStage.Rotation
	local liftedGrip = caseGrip + Vector3.new(0, 0.78, 0)
	if not animateRunnerLift(
		caseGrip, liftedGrip, 1.02, 1.02,
		caseAtStage, liftedCase, phaseDuration(0.018)
	) then
		cleanup()
		return
	end
	local carryCFrame = runner:GetPivot() * CFrame.new(0, 1.12, 0.18)
	local carryGrip = carryCFrame.Position + runner:GetPivot().UpVector * (caseSize.Y * 0.18)
	if not animateRunnerLift(
		liftedGrip, carryGrip, 1.02, 0.96,
		liftedCase, carryCFrame, phaseDuration(0.022)
	) then
		cleanup()
		return
	end
	beerCase.Parent = runner
	beerCase:PivotTo(carryCFrame)

	local toFridgeStagingPlans = {
		houseGroundPoint(-27.820, 50.700),
		houseGroundPoint(-27.82, 10.70),
		houseGroundPoint(-22.6, 10.70),
		houseGroundPoint(-10.8, 10.70),
		houseGroundPoint(-6.392, 11.704),
		houseGroundPoint(-6.392, 12.73),
		houseGroundPoint(-6.392, 15.45),
		houseGroundPoint(-6.392, 18.67),
		houseGroundPoint(-6.392, 20.50),
		houseGroundPoint(-5.9, 26.0),
		houseGroundPoint(-5.5, 32.8),
		houseGroundPoint(-5.5, 35.2),
		houseGroundPoint(-6.4, 38.0),
		houseGroundPoint(-7.1, 40.2),
		houseGroundPoint(-9.0, 39.5),
		houseGroundPoint(-12.4, 39.2),
	}
	local pathToFridgeStaging = prepareGroundedAutomationPlans(
		runner,
		toFridgeStagingPlans,
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position
	)
	if #pathToFridgeStaging == 0
		or not travelRobotPath(runner, pathToFridgeStaging, phaseDuration(0.29), token, animateBeerRunnerWheels)
	then
		cleanup()
		return
	end

	local fridgeAcquired, _, _, originalFridgeOpen = invokeAutomationDoor(fridge, "AcquireHoldOpen")
	if not fridgeAcquired then
		cleanup()
		return
	end
	fridgeHeld = true
	fridgeOriginalOpen = originalFridgeOpen == true
	local tunnelFacing = CFrame.lookAt(
		runner:GetPivot().Position,
		runner:GetPivot().Position + Vector3.new(-1, 0, 0)
	)
	if not tweenRobotPivot(runner, tunnelFacing, phaseDuration(0.010), token, animateBeerRunnerWheels) then
		cleanup()
		return
	end

	local fridgeTunnelZ = 37.042
	local fridgeTurnPath = prepareGroundedAutomationPlans(
		runner,
		{ houseGroundPoint(-12.4, fridgeTunnelZ) },
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position,
		"strafe",
		"Beer/fridge-strafe-in"
	)
	if #fridgeTurnPath == 0
		or not travelRobotPath(
			runner,
			fridgeTurnPath,
			phaseDuration(0.018),
			token,
			animateBeerRunnerWheels,
			"strafe"
		)
	then
		cleanup()
		return
	end
	local dockPosition = houseGroundPoint(-16.7, fridgeTunnelZ)
	local faceDock = CFrame.lookAt(
		runner:GetPivot().Position,
		Vector3.new(dockPosition.X, runner:GetPivot().Position.Y, dockPosition.Z)
	)
	if not tweenRobotPivot(runner, faceDock, phaseDuration(0.010), token, animateBeerRunnerWheels) then
		cleanup()
		return
	end
	local fridgeDockPath = prepareGroundedAutomationPlans(
		runner,
		{ dockPosition },
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position,
		nil,
		"Beer/fridge-dock"
	)
	if #fridgeDockPath == 0
		or not travelRobotPath(runner, fridgeDockPath, phaseDuration(0.020), token, animateBeerRunnerWheels)
	then
		cleanup()
		return
	end
	local faceFridge = CFrame.lookAt(
		runner:GetPivot().Position,
		runner:GetPivot().Position + Vector3.new(-1, 0, 0)
	)
	if not tweenRobotPivot(runner, faceFridge, phaseDuration(0.012), token, animateBeerRunnerWheels) then
		cleanup()
		return
	end
	local loadPlan = houseGroundPoint(-18.550, 36.687)
	local loadTarget = CFrame.new(
		loadPlan.X,
		runnerHome.Position.Y + 1.357,
		loadPlan.Z
	) * beerPromptAnchor.CFrame.Rotation
	local carriedCase = beerCase:GetPivot()
	local carriedGrip = carriedCase.Position + runner:GetPivot().UpVector * (caseSize.Y * 0.18)
	local loadGrip = loadTarget.Position + Vector3.new(0, caseSize.Y * 0.18, 0)
	if not animateRunnerLift(
		carriedGrip, loadGrip, 0.96, 0.96,
		carriedCase, loadTarget, phaseDuration(0.035)
	) or not animateRunnerLift(
		loadGrip, loadGrip, 0.96, 1.26,
		loadTarget, loadTarget, phaseDuration(0.012)
	) then
		cleanup()
		return
	end
	setCaseActive(false)
	beerCase.Parent = robot
	beerCase:PivotTo(caseHome)
	local stowedGrip = runner:GetPivot():PointToWorldSpace(Vector3.new(0, 1.17, -0.47))
	if not animateRunnerLift(
		loadGrip, stowedGrip, 1.26, 0.32,
		nil, nil, phaseDuration(0.015)
	) then
		cleanup()
		return
	end

	local backToTurnPath = prepareGroundedAutomationPlans(
		runner,
		{ houseGroundPoint(-12.4, fridgeTunnelZ) },
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position,
		"reverse",
		"Beer/fridge-reverse-out"
	)
	if #backToTurnPath == 0
		or not travelRobotPath(
			runner,
			backToTurnPath,
			phaseDuration(0.020),
			token,
			animateBeerRunnerWheels,
			"reverse"
		)
	then
		cleanup()
		return
	end
	local stagePosition = houseGroundPoint(-12.4, 39.2)
	local backToStagePath = prepareGroundedAutomationPlans(
		runner,
		{ stagePosition },
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position,
		"strafe",
		"Beer/fridge-strafe-out"
	)
	if #backToStagePath == 0
		or not travelRobotPath(
			runner,
			backToStagePath,
			phaseDuration(0.018),
			token,
			animateBeerRunnerWheels,
			"strafe"
		)
	then
		cleanup()
		return
	end
	if fridgeHeld then
		local released = invokeAutomationDoor(fridge, "ReleaseHoldOpen", fridgeOriginalOpen)
		if released then
			fridgeHeld = false
			fridgeOriginalOpen = nil
		end
	end

	local homeSouthPlans = {
		houseGroundPoint(-9.0, 39.5),
		houseGroundPoint(-7.1, 40.2),
		houseGroundPoint(-6.4, 38.0),
		houseGroundPoint(-5.5, 35.2),
		houseGroundPoint(-4.5, 36.2),
		houseGroundPoint(-2.0, 36.2),
		houseGroundPoint(0.8, 39.0),
		houseGroundPoint(2.25, 45.0),
		baseboardSouthPlan,
	}
	local pathHomeSouth = prepareGroundedAutomationPlans(
		runner,
		homeSouthPlans,
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position
	)
	if #pathHomeSouth == 0
		or not travelRobotPath(runner, pathHomeSouth, phaseDuration(0.10), token, animateBeerRunnerWheels)
	then
		cleanup()
		return
	end

	local groundedBaseboardNorth = groundAutomationPlans(
		runner,
		{ baseboardNorthPlan },
		2.20,
		runnerClearance
	)[1]
	local baseboardReturnCrossing = prepareAerialAutomationPlans(
		runner,
		{
			Vector3.new(runner:GetPivot().Position.X, baseboardLiftY, runner:GetPivot().Position.Z),
			Vector3.new(groundedBaseboardNorth.X, baseboardLiftY, groundedBaseboardNorth.Z),
			groundedBaseboardNorth,
		},
		runner:GetPivot().Position
	)
	if #baseboardReturnCrossing == 0
		or not travelRobotPath(
			runner,
			baseboardReturnCrossing,
			phaseDuration(0.025),
			token,
			animateBeerRunnerWheels
		)
	then
		cleanup()
		return
	end

	local homeNorthPlans = {
		houseGroundPoint(1.75, 55.0),
		runnerHome.Position,
	}
	local pathHomeNorth = prepareGroundedAutomationPlans(
		runner,
		homeNorthPlans,
		0.90,
		2.20,
		runnerClearance,
		runner:GetPivot().Position
	)
	if #pathHomeNorth == 0
		or not travelRobotPath(runner, pathHomeNorth, phaseDuration(0.045), token, animateBeerRunnerWheels)
	then
		cleanup()
		return
	end
	if automationTokenActive(token) then
		tweenRobotPivot(runner, runnerHome, phaseDuration(0.035), token, animateBeerRunnerWheels)
	end
	cleanup()
end

local function runHackerBot(robot, duration, metadata, token)
	if not automationTokenActive(token) then
		return
	end
	local leftProbe = robot:FindFirstChild("TypingProbeLeft")
	local rightProbe = robot:FindFirstChild("TypingProbeRight")
	local status = robot:FindFirstChild("BreachStatus")
	local display = robot:FindFirstChild("CipherDisplay", true)
	local cipherText = display and display:FindFirstChild("CipherText", true)
	if not (leftProbe and leftProbe:IsA("BasePart")
		and rightProbe and rightProbe:IsA("BasePart")
		and status and status:IsA("BasePart")
		and cipherText and cipherText:IsA("TextLabel"))
	then
		waitForAutomationToken(token, duration)
		return
	end
	local leftHome = leftProbe:GetAttribute("AutomationHomeCFrame")
	local rightHome = rightProbe:GetAttribute("AutomationHomeCFrame")
	if typeof(leftHome) ~= "CFrame" or typeof(rightHome) ~= "CFrame" then
		waitForAutomationToken(token, duration)
		return
	end
	local pulses = automationPartsWithAttribute(robot, "AutomationHackerPulse")
	table.sort(pulses, function(left, right)
		return finiteNumber(left:GetAttribute("PulseIndex"), 0)
			< finiteNumber(right:GetAttribute("PulseIndex"), 0)
	end)
	local cyan = Color3.fromRGB(48, 224, 232)
	local green = Color3.fromRGB(91, 255, 137)
	local started = os.clock()
	local lastTextStep = -1
	local bankCycle = math.max(1, math.floor(finiteNumber(metadata and metadata.bankCycle, 1)))
	local bankReward = math.max(0, math.floor(finiteNumber(metadata and metadata.bankReward, 0)))
	while os.clock() - started < duration and automationTokenActive(token) do
		local elapsed = os.clock() - started
		local edgeSeconds = math.max(0.12, math.min(0.7, duration * 0.08))
		local envelope = math.clamp(math.min(elapsed, duration - elapsed) / edgeSeconds, 0, 1)
		envelope = envelope * envelope * (3 - 2 * envelope)
		local phase = elapsed * 9.2
		local leftTap = math.max(0, math.sin(phase)) * 0.105 * envelope
		local rightTap = math.max(0, math.sin(phase + math.pi)) * 0.105 * envelope
		leftProbe.CFrame = leftHome * CFrame.new(0, -leftTap, 0)
		rightProbe.CFrame = rightHome * CFrame.new(0, -rightTap, 0)
		status.Color = cyan:Lerp(green, 0.5 + 0.5 * math.sin(elapsed * 5.8))
		for index, pulse in ipairs(pulses) do
			local activeIndex = math.floor(elapsed * 8) % math.max(1, #pulses) + 1
			pulse.Transparency = index == activeIndex and 0.05 or 0.82
		end
		local textStep = math.floor(elapsed / 0.42)
		if textStep ~= lastTextStep then
			lastTextStep = textStep
			local glyphs = { "Q7", "A3", "F9", "X2", "R8", "V4" }
			cipherText.Text = string.format(
				"CYCLE %02d" .. string.char(10) .. "%s%s > $%d",
				bankCycle,
				glyphs[textStep % #glyphs + 1],
				string.rep("*", textStep % 4 + 1),
				bankReward
			)
		end
		RunService.Heartbeat:Wait()
	end
	leftProbe.CFrame = leftHome
	rightProbe.CFrame = rightHome
	status.Color = cyan
	for _, pulse in ipairs(pulses) do
		pulse.Transparency = 1
	end
	cipherText.Text = "BANK" .. string.char(10) .. "READY"
end

local function runDishBot(robot, duration, token)
	if not automationTokenActive(token) then
		return
	end
	local dirtyDishes = taskVisuals:FindFirstChild("DirtyDishesInSink")
	if dirtyDishes then
		dirtyDishes:SetAttribute("AutomationCleared", false)
	end
	local rigs = {}
	for index = 1, 2 do
		local arm = robot:FindFirstChild("DishArm" .. index)
		local wrist = robot:FindFirstChild("DishWrist" .. index)
		local scrubber = robot:FindFirstChild("Scrubber" .. index)
		local bubble = robot:FindFirstChild("WashBubble" .. index)
		local scrubHome = scrubber and scrubber:GetAttribute("AutomationHomeCFrame")
		local bubbleHome = bubble and bubble:GetAttribute("AutomationHomeCFrame")
		if arm and arm:IsA("BasePart")
			and wrist and wrist:IsA("BasePart")
			and scrubber and scrubber:IsA("BasePart")
			and bubble and bubble:IsA("BasePart")
			and typeof(scrubHome) == "CFrame"
			and typeof(bubbleHome) == "CFrame"
		then
			local armEndA = arm.Position - arm.CFrame.LookVector * arm.Size.Z * 0.5
			local armEndB = arm.Position + arm.CFrame.LookVector * arm.Size.Z * 0.5
			local shoulder = if (armEndA - robot:GetPivot().Position).Magnitude
				<= (armEndB - robot:GetPivot().Position).Magnitude
				then armEndA
				else armEndB
			bubble.Transparency = finiteNumber(bubble:GetAttribute("AutomationActiveTransparency"), 0.28)
			table.insert(rigs, {
				index = index,
				arm = arm,
				wrist = wrist,
				scrubber = scrubber,
				bubble = bubble,
				shoulder = shoulder,
				scrubHome = scrubHome,
				bubbleOffset = scrubHome:ToObjectSpace(bubbleHome),
				bubbleHomeSize = bubble.Size,
			})
		end
	end
	if #rigs ~= 2 then
		waitForAutomationToken(token, duration)
		return
	end
	local motionBasis = robot:GetPivot()
	local startedAt = os.clock()
	while os.clock() - startedAt < duration and automationTokenActive(token) do
		local elapsed = os.clock() - startedAt
		local phase = elapsed * 7.4
		local rampDuration = math.max(0.08, math.min(0.65, duration * 0.12))
		local edgeAlpha = math.clamp(math.min(elapsed, duration - elapsed) / rampDuration, 0, 1)
		local engagement = edgeAlpha * edgeAlpha * (3 - 2 * edgeAlpha)
		for _, rig in ipairs(rigs) do
			local pairPhase = phase + (rig.index - 1) * math.pi
			local sweep = (
				motionBasis.RightVector * (math.sin(pairPhase) * 0.18)
					+ motionBasis.LookVector * (math.cos(pairPhase) * 0.12)
			) * engagement
			local plunge = motionBasis.UpVector
				* (-0.025 - math.abs(math.sin(pairPhase * 0.5)) * 0.040)
				* engagement
			local scrubTarget = rig.scrubHome.Position + sweep + plunge
			local scrubberTop = scrubTarget
				+ motionBasis.UpVector * math.max(0.04, rig.scrubber.Size.Y * 0.5)
			local wristTop = scrubTarget + motionBasis.UpVector * 0.58
			setBeamBetween(rig.arm, rig.shoulder, wristTop, 0.12)
			setBeamBetween(rig.wrist, wristTop, scrubberTop, 0.10)
			rig.scrubber.CFrame = CFrame.new(scrubTarget) * rig.scrubHome.Rotation
			local bubblePulse = 0.5 + 0.5 * math.sin(pairPhase * 1.35 + rig.index * 0.7)
			local bubbleLift = motionBasis.UpVector * (0.025 + bubblePulse * 0.035) * engagement
			rig.bubble.CFrame = rig.scrubber.CFrame * rig.bubbleOffset + bubbleLift
			rig.bubble.Size = rig.bubbleHomeSize * (0.94 + bubblePulse * 0.14)
			rig.bubble.Transparency = 0.24 + bubblePulse * 0.16
		end
		RunService.Heartbeat:Wait()
	end
	if automationTokenActive(token) then
		if dirtyDishes then
			dirtyDishes:SetAttribute("AutomationCleared", true)
		end
	end
end

local function runTrashBot(robot, duration, token)
	if not automationTokenActive(token) then
		return
	end
	local kitchenCan = taskVisuals:FindFirstChild("KitchenGarbageCan")
	local outdoorCan = taskVisuals:FindFirstChild("OutdoorGarbageCan")
	local kitchenFloor = environment:FindFirstChild("KitchenPatternLinoleum", true)
	local kitchenBag = taskVisuals:FindFirstChild("KitchenTrashBag")
	local kitchenBagTie = taskVisuals:FindFirstChild("KitchenTrashBagTie")
	local patioDoor = environment:FindFirstChild("InteractiveDenPatioDoor", true)
	local outdoorLid = outdoorCan and outdoorCan:FindFirstChild("Lid")
	local cargoBag = robot:FindFirstChild("CargoBag")
	local cargoBagTie = robot:FindFirstChild("CargoBagTie")
	local wheelLeft = robot:FindFirstChild("WheelLeft")
	local wheelRight = robot:FindFirstChild("WheelRight")
	local liftMast = robot:FindFirstChild("LiftMast")
	local liftArm = robot:FindFirstChild("LiftArm")
	local grabberLeft = robot:FindFirstChild("GrabberLeft")
	local grabberRight = robot:FindFirstChild("GrabberRight")
	if not (kitchenCan and kitchenCan:IsA("Model")
		and outdoorCan and outdoorCan:IsA("Model")
		and outdoorLid and outdoorLid:IsA("BasePart")
		and kitchenFloor and kitchenFloor:IsA("BasePart")
		and kitchenBag and kitchenBag:IsA("BasePart")
		and kitchenBagTie and kitchenBagTie:IsA("BasePart")
		and patioDoor and patioDoor:IsA("Model")
		and cargoBag and cargoBag:IsA("BasePart")
		and cargoBagTie and cargoBagTie:IsA("BasePart")
		and wheelLeft and wheelLeft:IsA("BasePart")
		and wheelRight and wheelRight:IsA("BasePart")
		and liftMast and liftMast:IsA("BasePart")
		and liftArm and liftArm:IsA("BasePart")
		and grabberLeft and grabberLeft:IsA("BasePart")
		and grabberRight and grabberRight:IsA("BasePart"))
	then
		waitForAutomationToken(token, duration)
		return
	end
	-- The sequence below assigns 1.23 total duration-weight across extraction,
	-- travel, lid handling, disposal, and the complete return trip. Reserve the
	-- patio controller's two possible 0.58-second transitions, then normalize the
	-- weighted motion. A final deadline hold below covers an already-open door and
	-- keeps the visible robot aligned to its complete configured run.
	local patioTransitionReserve = math.min(1.16, duration * 0.1)
	local phaseDuration = math.max(0, duration - patioTransitionReserve) / 1.23
	duration = phaseDuration

	local home = robot:GetPivot()
	local kitchenFloorTop = kitchenFloor.Position.Y + kitchenFloor.Size.Y * 0.5
	local pivotGroundClearance = home.Position.Y - kitchenFloorTop
	local cargoParts = automationPartsWithAttribute(robot, "AutomationTrashCargoPart")
	local liftParts = automationPartsWithAttribute(robot, "AutomationTrashLiftPart")
	local cargoOffsets = {}
	for _, cargoPart in ipairs(cargoParts) do
		cargoOffsets[cargoPart] = cargoBag.CFrame:ToObjectSpace(cargoPart.CFrame)
	end
	local lidHome = outdoorLid.CFrame
	local patioHeld = false
	local patioOriginalOpen = nil
	local cleanupDone = false
	local function cleanup()
		if cleanupDone then
			return
		end
		cleanupDone = true
		setAutomationPartsActive(cargoParts, false)
		outdoorLid.CFrame = lidHome
		if patioHeld then
			invokeAutomationDoor(patioDoor, "ReleaseHoldOpen", patioOriginalOpen)
			patioHeld = false
		end
	end
	token.cleanup = cleanup

	local function setCargoCFrame(coreCFrame)
		for cargoPart, offset in pairs(cargoOffsets) do
			if cargoPart.Parent then
				cargoPart.CFrame = coreCFrame * offset
			end
		end
	end

	local function setLiftPose(gripPosition, spread, cargoCFrame)
		local basis = robot:GetPivot()
		local shoulder = basis:PointToWorldSpace(Vector3.new(-0.42, 0.92, 0.23))
		local elbow = shoulder + basis.UpVector * 0.66
		setBeamBetween(liftMast, shoulder, elbow, 0.10)
		setBeamBetween(liftArm, elbow, gripPosition, 0.12)
		local halfSpread = math.max(0.17, spread * 0.5)
		local grabRotation = basis.Rotation
		grabberLeft.CFrame = CFrame.new(gripPosition - basis.RightVector * halfSpread) * grabRotation
		grabberRight.CFrame = CFrame.new(gripPosition + basis.RightVector * halfSpread) * grabRotation
		if cargoCFrame then
			setCargoCFrame(cargoCFrame)
		end
	end

	local function animateLift(
		startGrip,
		endGrip,
		startSpread,
		endSpread,
		startCargo,
		endCargo,
		seconds
	)
		local startedAt = os.clock()
		local safeDuration = math.max(0.02, seconds)
		repeat
			if not automationTokenActive(token) then
				return false
			end
			local alpha = math.clamp((os.clock() - startedAt) / safeDuration, 0, 1)
			local eased = alpha * alpha * (3 - 2 * alpha)
			local grip = startGrip:Lerp(endGrip, eased)
			local cargo = startCargo and endCargo and startCargo:Lerp(endCargo, eased) or nil
			setLiftPose(grip, startSpread + (endSpread - startSpread) * eased, cargo)
			RunService.Heartbeat:Wait()
		until alpha >= 1
		return automationTokenActive(token)
	end

	setAutomationPartsActive(liftParts, true)
	setAutomationPartsActive(cargoParts, true)
	cargoBag.Size = kitchenBag.Size
	cargoBagTie.Size = kitchenBagTie.Size
	setCargoCFrame(kitchenBag.CFrame)
	cargoBagTie.CFrame = kitchenBagTie.CFrame
	cargoOffsets[cargoBagTie] = cargoBag.CFrame:ToObjectSpace(cargoBagTie.CFrame)
	local readyGrip = robot:GetPivot():PointToWorldSpace(Vector3.new(0, 1.25, -0.42))
	local bagGrip = kitchenBagTie.Position - kitchenFloor.CFrame.UpVector * 0.24
	local kitchenCanCFrame, kitchenCanSize = kitchenCan:GetBoundingBox()
	local kitchenCanCenter = kitchenCanCFrame.Position
	local kitchenCanTop = kitchenCanCenter.Y + kitchenCanSize.Y * 0.5
	local bagCore = kitchenBag.CFrame
	local safeBagCoreY = kitchenCanTop + cargoBag.Size.Y * 0.5 + 0.30
	local bagAboveCore = CFrame.new(
		bagCore.Position.X,
		safeBagCoreY,
		bagCore.Position.Z
	) * bagCore.Rotation
	local bagAboveGrip = bagGrip + Vector3.new(0, safeBagCoreY - bagCore.Position.Y, 0)
	setLiftPose(readyGrip, 1.20, kitchenBag.CFrame)
	if not animateLift(
		readyGrip,
		bagAboveGrip,
		1.20,
		1.72,
		kitchenBag.CFrame,
		kitchenBag.CFrame,
		duration * 0.035
	) then
		cleanup()
		return
	end
	if not animateLift(
		bagAboveGrip,
		bagGrip,
		1.72,
		1.72,
		kitchenBag.CFrame,
		kitchenBag.CFrame,
		duration * 0.030
	) then
		cleanup()
		return
	end
	if not animateLift(
		bagGrip,
		bagGrip,
		1.72,
		1.18,
		kitchenBag.CFrame,
		kitchenBag.CFrame,
		duration * 0.025
	) then
		cleanup()
		return
	end
	local carryCFrame = robot:GetPivot() * CFrame.new(0, 1.15, 0.10)
	local carryGrip = carryCFrame.Position + robot:GetPivot().UpVector * 0.23
	if not animateLift(
		bagGrip,
		bagAboveGrip,
		1.18,
		1.12,
		kitchenBag.CFrame,
		bagAboveCore,
		duration * 0.045
	) then
		cleanup()
		return
	end
	local rackAbove = CFrame.new(
		carryCFrame.Position.X,
		safeBagCoreY,
		carryCFrame.Position.Z
	) * carryCFrame.Rotation
	local rackAboveGrip = rackAbove.Position + robot:GetPivot().UpVector * 0.23
	if not animateLift(
		bagAboveGrip,
		rackAboveGrip,
		1.12,
		1.05,
		bagAboveCore,
		rackAbove,
		duration * 0.035
	) or not animateLift(
		rackAboveGrip,
		carryGrip,
		1.05,
		1.05,
		rackAbove,
		carryCFrame,
		duration * 0.030
	) then
		cleanup()
		return
	end

	local acquired, _, _, originalOpen = invokeAutomationDoor(patioDoor, "AcquireHoldOpen")
	patioHeld = acquired
	patioOriginalOpen = originalOpen
	if not acquired then
		cleanup()
		return
	end
	local outdoorCanPosition = outdoorCan:GetPivot().Position
	local outdoorPlan = outdoorCanPosition + Vector3.new(3.15, 0, 0)
	local referenceX = -13.920001
	local referenceZ = 41.944015
	local function houseGroundPoint(x, z)
		return kitchenFloor.CFrame:PointToWorldSpace(Vector3.new(
			x - referenceX,
			home.Position.Y - kitchenFloor.Position.Y,
			z - referenceZ
		))
	end
	local homePlanarLook = Vector3.new(home.LookVector.X, 0, home.LookVector.Z)
	if homePlanarLook.Magnitude <= 0.01 then
		homePlanarLook = Vector3.new(-1, 0, 0)
	else
		homePlanarLook = homePlanarLook.Unit
	end
	local departurePlan = home.Position - homePlanarLook * 1.80
	local departurePath = prepareGroundedAutomationPlans(
		robot,
		{ departurePlan },
		1.55,
		2.75,
		pivotGroundClearance,
		home.Position,
		"reverse"
	)
	local departureStaging = if #departurePath > 0 then departurePath[#departurePath] else departurePlan

	local doorStaging = houseGroundPoint(30.800, 41.242)
	local interiorPlans = {
		departureStaging,
		houseGroundPoint(-11.878, 40.568),
		houseGroundPoint(-8.919, 40.078),
		houseGroundPoint(-5.959, 39.587),
		houseGroundPoint(-3.000, 39.097),
		houseGroundPoint(-0.040, 38.606),
		houseGroundPoint(2.500, 38.185),
		houseGroundPoint(1.716, 35.289),
		houseGroundPoint(1.319, 33.826),
		houseGroundPoint(3.924, 32.337),
		houseGroundPoint(6.529, 30.849),
		houseGroundPoint(9.133, 29.360),
		houseGroundPoint(11.486, 28.016),
		houseGroundPoint(14.485, 28.063),
		houseGroundPoint(14.679, 28.066),
		houseGroundPoint(17.012, 29.951),
		houseGroundPoint(19.346, 31.836),
		houseGroundPoint(20.792, 33.004),
		houseGroundPoint(20.066, 35.915),
		houseGroundPoint(19.500, 38.185),
		houseGroundPoint(22.396, 38.968),
		houseGroundPoint(25.292, 39.752),
		houseGroundPoint(28.188, 40.535),
		doorStaging,
	}
	local interiorPath = {}
	if #departurePath > 0 then
		interiorPath = prepareGroundedAutomationPlans(
			robot,
			interiorPlans,
			1.55,
			2.75,
			pivotGroundClearance,
			departureStaging
		)
	end
	local patioPlans = {
		houseGroundPoint(33.150, 41.242),
		houseGroundPoint(36.800, 41.242),
		houseGroundPoint(39.750, 41.242),
		houseGroundPoint(40.458, 41.242),
		houseGroundPoint(41.700, 41.242),
	}
	local patioPath = prepareGroundedAutomationPlans(
		robot,
		patioPlans,
		1.55,
		2.75,
		pivotGroundClearance,
		doorStaging
	)
	local exteriorPlans = {
		houseGroundPoint(42.300, 46.000),
		houseGroundPoint(42.000, 70.000),
		houseGroundPoint(36.500, 74.500),
		houseGroundPoint(30.000, 76.800),
		houseGroundPoint(20.000, 79.200),
		houseGroundPoint(10.000, 81.670),
		houseGroundPoint(4.000, 84.564),
		Vector3.new(outdoorPlan.X, home.Position.Y, outdoorPlan.Z),
	}
	local exteriorPath = {}
	if #patioPath > 0 then
		exteriorPath = prepareGroundedAutomationPlans(
			robot,
			exteriorPlans,
			1.55,
			2.75,
			pivotGroundClearance,
			patioPath[#patioPath]
		)
	end
	local reversedExterior = reversePositions(exteriorPath)
	local outdoorDeparturePath = {}
	local returnExteriorPath = {}
	if #reversedExterior >= 3 then
		outdoorDeparturePath = prepareGroundedAutomationPlans(
			robot,
			{ reversedExterior[2] },
			1.55,
			2.75,
			pivotGroundClearance,
			reversedExterior[1],
			"reverse"
		)
		if #outdoorDeparturePath > 0 then
			local returnExteriorPlans = {}
			for index = 3, #reversedExterior do
				table.insert(returnExteriorPlans, reversedExterior[index])
			end
			returnExteriorPath = prepareGroundedAutomationPlans(
				robot,
				returnExteriorPlans,
				1.55,
				2.75,
				pivotGroundClearance,
				outdoorDeparturePath[#outdoorDeparturePath]
			)
		end
	end
	local trashWheelAnimator = makeWheelAnimator(robot, "Wheel")
	local function animateTrashWheels(currentPivot)
		trashWheelAnimator(currentPivot)
	end
	if #departurePath == 0 or #interiorPath == 0 or #patioPath == 0 or #exteriorPath == 0
		or #outdoorDeparturePath == 0 or #returnExteriorPath == 0
		or not travelRobotPath(robot, departurePath, duration * 0.018, token, animateTrashWheels, "reverse")
		or not travelRobotPath(robot, interiorPath, duration * 0.12, token, animateTrashWheels)
	then
		cleanup()
		return
	end
	local patioDirection = patioPath[#patioPath] - robot:GetPivot().Position
	patioDirection = Vector3.new(patioDirection.X, 0, patioDirection.Z).Unit
	local facePatio = CFrame.lookAt(robot:GetPivot().Position, robot:GetPivot().Position + patioDirection)
	if not tweenRobotPivot(robot, facePatio, duration * 0.010, token, animateTrashWheels)
		or not travelRobotPath(robot, patioPath, duration * 0.026, token, animateTrashWheels)
		or not travelRobotPath(robot, exteriorPath, duration * 0.16, token, animateTrashWheels)
	then
		cleanup()
		return
	end

	local faceCan = CFrame.lookAt(
		robot:GetPivot().Position,
		Vector3.new(outdoorCanPosition.X, robot:GetPivot().Position.Y, outdoorCanPosition.Z)
	)
	if not tweenRobotPivot(robot, faceCan, duration * 0.015, token, animateTrashWheels)
		or not waitForAutomationToken(token, duration * 0.012)
	then
		cleanup()
		return
	end

	local lidRadius = math.max(outdoorLid.Size.Y, outdoorLid.Size.Z) * 0.46
	local lidHinge = lidHome * CFrame.new(0, 0, lidRadius)
	local lidClosedOffset = CFrame.new(0, 0, -lidRadius)
	local lidOpenAngle = math.rad(-105)
	if not tweenAutomationHinge(
		outdoorLid,
		lidHinge,
		lidClosedOffset,
		0,
		lidOpenAngle,
		duration * 0.035,
		token
	) then
		cleanup()
		return
	end
	local carriedAtCan = cargoBag.CFrame
	local currentCarryGrip = carriedAtCan.Position + robot:GetPivot().UpVector * 0.23
	local outdoorCanBody = outdoorCan:FindFirstChild("Can")
	local outdoorCanTop = if outdoorCanBody and outdoorCanBody:IsA("BasePart")
		then outdoorCanBody.Position.Y
			+ math.abs(outdoorCanBody.CFrame.RightVector.Y) * outdoorCanBody.Size.X * 0.5
			+ math.abs(outdoorCanBody.CFrame.UpVector.Y) * outdoorCanBody.Size.Y * 0.5
			+ math.abs(outdoorCanBody.CFrame.LookVector.Y) * outdoorCanBody.Size.Z * 0.5
		else outdoorCanPosition.Y + 1.25
	local dropClearY = outdoorCanTop + cargoBag.Size.Y * 0.5 + 0.38
	local liftedAtRack = CFrame.new(
		carriedAtCan.Position.X,
		dropClearY,
		carriedAtCan.Position.Z
	) * carriedAtCan.Rotation
	local liftedRackGrip = liftedAtRack.Position + Vector3.new(0, 0.25, 0)
	if not animateLift(
		currentCarryGrip,
		liftedRackGrip,
		1.05,
		1.05,
		carriedAtCan,
		liftedAtRack,
		duration * 0.035
	) then
		cleanup()
		return
	end
	local aboveCan = CFrame.new(
		outdoorCanPosition.X,
		dropClearY,
		outdoorCanPosition.Z
	) * carriedAtCan.Rotation
	local aboveGrip = aboveCan.Position + Vector3.new(0, 0.25, 0)
	if not animateLift(
		liftedRackGrip,
		aboveGrip,
		1.05,
		1.05,
		liftedAtRack,
		aboveCan,
		duration * 0.040
	) then
		cleanup()
		return
	end
	local insideCan = CFrame.new(outdoorCanPosition + Vector3.new(0, 0.38, 0)) * aboveCan.Rotation
	local insideGrip = insideCan.Position + Vector3.new(0, 0.25, 0)
	if not animateLift(
		aboveGrip,
		insideGrip,
		1.05,
		1.05,
		aboveCan,
		insideCan,
		duration * 0.055
	) then
		cleanup()
		return
	end
	if not animateLift(
		insideGrip,
		insideGrip,
		1.05,
		1.72,
		insideCan,
		insideCan,
		duration * 0.025
	) then
		cleanup()
		return
	end
	setAutomationPartsActive(cargoParts, false)
	setCargoCFrame(robot:GetPivot() * CFrame.new(0, 1.15, 0.10))
	if not animateLift(
		insideGrip,
		aboveGrip,
		1.72,
		1.72,
		nil,
		nil,
		duration * 0.035
	) or not animateLift(
		aboveGrip,
		liftedRackGrip,
		1.72,
		1.40,
		nil,
		nil,
		duration * 0.035
	) then
		cleanup()
		return
	end
	local returnGrip = robot:GetPivot():PointToWorldSpace(Vector3.new(0, 1.25, -0.42))
	if not animateLift(
		liftedRackGrip,
		returnGrip,
		1.40,
		1.20,
		nil,
		nil,
		duration * 0.035
	) then
		cleanup()
		return
	end
	if not tweenAutomationHinge(
		outdoorLid,
		lidHinge,
		lidClosedOffset,
		lidOpenAngle,
		0,
		duration * 0.035,
		token
	) then
		cleanup()
		return
	end

	local reversePatio = reversePositions(patioPath)
	local reverseInterior = reversePositions(interiorPath)
	if not travelRobotPath(
		robot,
		outdoorDeparturePath,
		duration * 0.018,
		token,
		animateTrashWheels,
		"reverse"
	) then
		cleanup()
		return
	end
	local returnExteriorDirection = returnExteriorPath[1] - robot:GetPivot().Position
	returnExteriorDirection = Vector3.new(returnExteriorDirection.X, 0, returnExteriorDirection.Z).Unit
	local faceReturnExterior = CFrame.lookAt(
		robot:GetPivot().Position,
		robot:GetPivot().Position + returnExteriorDirection
	)
	if not tweenRobotPivot(robot, faceReturnExterior, duration * 0.010, token, animateTrashWheels)
		or not travelRobotPath(robot, returnExteriorPath, duration * 0.132, token, animateTrashWheels)
	then
		cleanup()
		return
	end
	local returnPatioDirection = reversePatio[#reversePatio] - robot:GetPivot().Position
	returnPatioDirection = Vector3.new(returnPatioDirection.X, 0, returnPatioDirection.Z).Unit
	local faceReturnPatio = CFrame.lookAt(
		robot:GetPivot().Position,
		robot:GetPivot().Position + returnPatioDirection
	)
	if not tweenRobotPivot(robot, faceReturnPatio, duration * 0.010, token, animateTrashWheels)
		or not travelRobotPath(robot, reversePatio, duration * 0.026, token, animateTrashWheels)
		or not travelRobotPath(robot, reverseInterior, duration * 0.12, token, animateTrashWheels)
	then
		cleanup()
		return
	end
	if not travelRobotPath(robot, { home.Position }, duration * 0.018, token, animateTrashWheels) then
		cleanup()
		return
	end
	tweenRobotPivot(robot, home, duration * 0.005, token, animateTrashWheels)
	cleanup()
	local remainingVisibleTime = math.max(0, token.completesAt - serverNow())
	if remainingVisibleTime > 0 then
		waitForAutomationToken(token, remainingVisibleTime)
	end
end

local function runToyFinder(robot, duration, metadata, token)
	if not automationTokenActive(token) then
		return
	end
	local markerName = type(metadata.markerName) == "string" and metadata.markerName or ""
	local marker = markerName ~= "" and world:FindFirstChild(markerName, true) or nil
	local mattress = environment:FindFirstChild("MissyWalnutTwinBed", true)
	mattress = mattress and mattress:FindFirstChild("Mattress") or nil
	local kitchenFloor = environment:FindFirstChild("KitchenPatternLinoleum", true)
	local scanner = robot:FindFirstChild("Scanner")
	local rotorLeft = robot:FindFirstChild("RotorLeft")
	local rotorRight = robot:FindFirstChild("RotorRight")
	local pickupCable = robot:FindFirstChild("PickupCable")
	local pickupWrist = robot:FindFirstChild("PickupWrist")
	local clawLeft = robot:FindFirstChild("ClawLeft")
	local clawRight = robot:FindFirstChild("ClawRight")
	local plushKind = tostring(metadata.plushKind or "Teddy Bear")
	local sourceName = plushKind == "Rabbit" and "MissyDetailedRabbit" or "MissyDetailedTeddyBear"
	local sourceToy = environment:FindFirstChild(sourceName, true)
	if not (marker and marker:IsA("BasePart")
		and mattress and mattress:IsA("BasePart")
		and kitchenFloor and kitchenFloor:IsA("BasePart")
		and scanner and scanner:IsA("BasePart")
		and rotorLeft and rotorLeft:IsA("BasePart")
		and rotorRight and rotorRight:IsA("BasePart")
		and pickupCable and pickupCable:IsA("BasePart")
		and pickupWrist and pickupWrist:IsA("BasePart")
		and clawLeft and clawLeft:IsA("BasePart")
		and clawRight and clawRight:IsA("BasePart")
		and sourceToy and sourceToy:IsA("Model"))
	then
		waitForAutomationToken(token, duration)
		return
	end

	local home = robot:GetPivot()
	local cableClawParts = { pickupCable, pickupWrist, clawLeft, clawRight }
	local pickupStowedState = {}
	for _, pickupPart in ipairs(cableClawParts) do
		pickupStowedState[pickupPart] = {
			relative = home:ToObjectSpace(pickupPart.CFrame),
			size = pickupPart.Size,
		}
	end
	local function stowPickupRig()
		local currentPivot = robot:GetPivot()
		for pickupPart, state in pairs(pickupStowedState) do
			if pickupPart.Parent then
				pickupPart.Size = state.size
				pickupPart.CFrame = currentPivot * state.relative
			end
		end
		setAutomationPartsActive(cableClawParts, false)
	end
	local plushClone = sourceToy:Clone()
	plushClone.Name = "DetailedPlushClone"
	for _, descendant in ipairs(plushClone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("ProximityPrompt")
			or descendant:IsA("Script")
			or descendant:IsA("LocalScript")
		then
			descendant:Destroy()
		end
	end
	plushClone.Parent = taskVisuals
	pcall(function()
		plushClone:ScaleTo(0.82)
	end)
	plushClone:PivotTo(marker.CFrame)

	local scannerHomeColor = scanner.Color
	local scannerLight = scanner:FindFirstChildWhichIsA("Light")
	local scannerHomeBrightness = scannerLight and scannerLight.Brightness or nil
	local cleanupDone = false
	local function cleanup()
		if cleanupDone then
			return
		end
		cleanupDone = true
		stowPickupRig()
		scanner.Color = scannerHomeColor
		if scannerLight and scannerHomeBrightness then
			scannerLight.Brightness = scannerHomeBrightness
		end
		if plushClone and plushClone.Parent then
			plushClone:Destroy()
		end
	end
	token.cleanup = cleanup

	local toyRotorAnimator = makeRotorAnimator(robot)
	local function animateToyRotors(currentPivot)
		toyRotorAnimator(currentPivot)
	end
	local function waitWithRotors(seconds)
		local deadline = os.clock() + math.max(0, seconds)
		while os.clock() < deadline do
			if not automationTokenActive(token) then
				return false
			end
			animateToyRotors(robot:GetPivot())
			RunService.Heartbeat:Wait()
		end
		return automationTokenActive(token)
	end

	-- All route coordinates are stored relative to the kitchen floor's authored
	-- origin. If the complete house is moved or rotated, the entire flight graph
	-- follows it instead of retaining stale world coordinates.
	local kitchenTop = kitchenFloor.Position.Y + kitchenFloor.Size.Y * 0.5
	local flightY = kitchenTop + 6.94
	local referenceX = -13.920001
	local referenceZ = 41.944015
	local function housePoint(x, z)
		return kitchenFloor.CFrame:PointToWorldSpace(Vector3.new(
			x - referenceX,
			flightY - kitchenFloor.Position.Y,
			z - referenceZ
		))
	end
	local function housePointAtHeight(x, y, z)
		return kitchenFloor.CFrame:PointToWorldSpace(Vector3.new(
			x - referenceX,
			y - kitchenFloor.Position.Y,
			z - referenceZ
		))
	end
	local function markerOffsetAtHeight(offsetX, y, offsetZ)
		local markerLocal = kitchenFloor.CFrame:PointToObjectSpace(marker.Position)
		return kitchenFloor.CFrame:PointToWorldSpace(Vector3.new(
			markerLocal.X + offsetX,
			y - kitchenFloor.Position.Y,
			markerLocal.Z + offsetZ
		))
	end
	local function appendRoute(target, points)
		for _, point in ipairs(points) do
			table.insert(target, housePoint(point[1], point[2]))
		end
	end

	local outbound = {}
	if markerName == "MissyVanityCorner" then
		appendRoute(outbound, { { 5.59, 61.38 } })
	elseif markerName == "ParentsDresserCorner" then
		appendRoute(outbound, {
			{ 4, 61 }, { 2.3, 57.2 }, { 2.3, 53.8 },
			{ -19.86, 53.8 }, { -19.86, 59.5 }, { -21.64, 63 },
			{ -21.642, 67.297 },
		})
	else
		appendRoute(outbound, {
			{ 4, 61 }, { 2.3, 57.2 }, { 2.3, 53.8 },
			-- Once through the twins-room/hall opening, move east into the open
			-- den before turning south. The former diagonal to (1.5, 43) swept the
			-- carried plush envelope through both AmberDenLamp.Shade and its full-
			-- height collision proxy. These two guides retain generous horizontal
			-- clearance and are checked in both directions by aerial preflight.
			{ 2.3, 48.3 }, { 5.0, 46.8 }, { 5.0, 43 },
		})
		if markerName == "DenBookcaseCorner" then
			appendRoute(outbound, { { 8, 40 }, { 13.5, 39 }, { 17.60, 37.99 } })
		elseif markerName == "DenTelevisionCorner" then
			appendRoute(outbound, { { 2.0, 40.0 }, { 2.71, 37.40 } })
		elseif markerName == "GeorgieDresserCorner" then
			appendRoute(outbound, {
				{ 8, 40.5 }, { 15.8, 40.2 }, { 19.3, 40.2 },
				{ 21.5, 42 }, { 21.5, 45 }, { 20.28, 46.55 },
			})
		elseif markerName == "DiningHutchCorner" then
			appendRoute(outbound, {
				{ 8, 40.5 }, { 15, 40.2 }, { 20, 40.2 },
				-- Stay west of the complete hutch footprint, then approach its clear
				-- northwest corner. Reversing this exact route keeps the low carried
				-- plush away from shelf three and every displayed plate.
				{ 22, 37 }, { 22, 33 }, { 25, 30 }, { 25.4, 35.0 },
			})
			table.insert(outbound, markerOffsetAtHeight(-1.45, flightY, 1.10))
		elseif markerName == "SofaEndTableHideaway" then
			appendRoute(outbound, {
				{ 1.5, 36 }, { 1.5, 31 }, { -5, 31 },
				-- Square around the tall brass lamp instead of cutting diagonally
				-- through its shade. Stay east until the complete carried envelope is
				-- south of the collision proxy, then cross west toward the end table.
				-- The reversed inbound route retains the identical clearance corridor.
				{ -14, 31 }, { -14, 26 }, { -19, 26 }, { -19.43, 22.40 },
			})
		end
	end
	local takeoff = Vector3.new(home.Position.X, flightY, home.Position.Z)
	local safeTakeoff = prepareAerialAutomationPlans(robot, { takeoff }, home.Position)
	local safeOutbound = prepareAerialAutomationPlans(robot, outbound, takeoff)
	if #safeTakeoff == 0 or #safeOutbound == 0
		or not travelRobotPath(robot, safeTakeoff, duration * 0.055, token, animateToyRotors, "flight")
		or not travelRobotPath(robot, safeOutbound, duration * 0.245, token, animateToyRotors, "flight")
	then
		cleanup()
		return
	end
	local hoverPivot = robot:GetPivot()
	local markerDirection = Vector3.new(
		marker.Position.X - hoverPivot.Position.X,
		0,
		marker.Position.Z - hoverPivot.Position.Z
	)
	if markerDirection.Magnitude <= 0.01 then
		local currentLook = hoverPivot.LookVector
		markerDirection = Vector3.new(currentLook.X, 0, currentLook.Z)
	end
	if markerDirection.Magnitude <= 0.01 then
		markerDirection = Vector3.new(0, 0, -1)
	end
	local faceMarker = CFrame.lookAt(
		hoverPivot.Position,
		hoverPivot.Position + markerDirection.Unit
	)
	if not tweenRobotPivot(robot, faceMarker, duration * 0.018, token, animateToyRotors) then
		cleanup()
		return
	end

	-- The scanner now only pulses as a status lamp. The former solid neon scan
	-- cylinder is gone; the viewer can watch the real claw lower to the real toy.
	scanner.Color = Color3.fromRGB(255, 232, 92)
	if scannerLight then
		scannerLight.Brightness = math.max(scannerLight.Brightness, 3.8)
	end
	if not waitWithRotors(duration * 0.025) then
		cleanup()
		return
	end
	scanner.Color = scannerHomeColor
	if scannerLight and scannerHomeBrightness then
		scannerLight.Brightness = scannerHomeBrightness
	end

	setAutomationPartsActive(cableClawParts, true)
	pickupWrist.Transparency = 1
	local _, plushSize = plushClone:GetBoundingBox()
	local pickupPoint = plushClone:GetPivot().Position + Vector3.new(0, plushSize.Y * 0.28, 0)
	local sofaWristPoint = if markerName == "SofaEndTableHideaway"
		then housePointAtHeight(-19.43, 2.55, 21.65)
		else nil
	if sofaWristPoint then
		pickupWrist.Transparency = finiteNumber(pickupWrist:GetAttribute("AutomationActiveTransparency"), 0.04)
	end
	local function updatePickupRig(gripPoint, spread, wristPoint)
		local halfSpread = math.max(0.12, spread * 0.5)
		local rotation = robot:GetPivot().Rotation
		clawLeft.CFrame = CFrame.new(gripPoint - robot:GetPivot().RightVector * halfSpread) * rotation
		clawRight.CFrame = CFrame.new(gripPoint + robot:GetPivot().RightVector * halfSpread) * rotation
		if wristPoint then
			setBeamBetween(pickupCable, scanner.Position, wristPoint, 0.04)
			setBeamBetween(pickupWrist, wristPoint, gripPoint, 0.04)
		else
			setBeamBetween(pickupCable, scanner.Position, gripPoint, 0.04)
			-- Collapse the unused articulated wrist onto the grip. Leaving its last
			-- sofa-bend CFrame behind makes the carried model's bounds extend to the
			-- floor even though the wrist is invisible.
			setBeamBetween(pickupWrist, gripPoint, gripPoint, 0.04)
			pickupWrist.Transparency = 1
		end
	end
	local clawTargets = {
		[clawLeft] = CFrame.new(pickupPoint - robot:GetPivot().RightVector * 0.34) * robot:GetPivot().Rotation,
		[clawRight] = CFrame.new(pickupPoint + robot:GetPivot().RightVector * 0.34) * robot:GetPivot().Rotation,
	}
	if not tweenAutomationParts(clawTargets, duration * 0.035, token, function()
		animateToyRotors(robot:GetPivot())
		updatePickupRig((clawLeft.Position + clawRight.Position) * 0.5, 0.68, sofaWristPoint)
	end) then
		cleanup()
		return
	end
	local clawTargetsClosed = {
		[clawLeft] = CFrame.new(pickupPoint - robot:GetPivot().RightVector * 0.16) * robot:GetPivot().Rotation,
		[clawRight] = CFrame.new(pickupPoint + robot:GetPivot().RightVector * 0.16) * robot:GetPivot().Rotation,
	}
	if not tweenAutomationParts(clawTargetsClosed, duration * 0.02, token, function()
		animateToyRotors(robot:GetPivot())
		updatePickupRig((clawLeft.Position + clawRight.Position) * 0.5, 0.32, sofaWristPoint)
	end) then
		cleanup()
		return
	end

	plushClone.Parent = robot
	local extractionPositions = {
		MissyVanityCorner = housePointAtHeight(5.46, 3.00, 61.87),
		DenBookcaseCorner = housePointAtHeight(16.98, 2.99, 38.81),
		DiningHutchCorner = markerOffsetAtHeight(-0.70, 2.83, 0.60),
		GeorgieDresserCorner = housePointAtHeight(20.93, 2.95, 46.16),
		DenTelevisionCorner = housePointAtHeight(2.51, 3.01, 39.10),
		ParentsDresserCorner = housePointAtHeight(-21.642, 3.00, 67.297),
		SofaEndTableHideaway = housePointAtHeight(-19.43, 2.25, 21.65),
	}
	local extractionPosition = extractionPositions[markerName]
		or Vector3.new(marker.Position.X, marker.Position.Y + 0.8, marker.Position.Z)
	local plushRotation = plushClone:GetPivot().Rotation
	local function followPlushRig(wristPoint)
		animateToyRotors(robot:GetPivot())
		local carriedPoint = plushClone:GetPivot().Position + Vector3.new(0, plushSize.Y * 0.28, 0)
		updatePickupRig(carriedPoint, 0.32, wristPoint)
	end

	if markerName == "SofaEndTableHideaway" then
		-- The plush is taller than the gap under this table. Tip it onto its side,
		-- extend a real horizontal wrist under the tabletop, and slide it between
		-- the legs before returning it upright in open space.
		local horizontalAtMarker = CFrame.new(
			plushClone:GetPivot().Position.X,
			marker.Position.Y - 0.12,
			plushClone:GetPivot().Position.Z
		) * plushRotation * CFrame.Angles(0, 0, math.rad(90))
		if not tweenModelPivot(plushClone, horizontalAtMarker, duration * 0.025, token, function()
			followPlushRig(sofaWristPoint)
		end) then
			cleanup()
			return
		end
		local horizontalOutside = CFrame.new(extractionPosition) * horizontalAtMarker.Rotation
		if not tweenModelPivot(plushClone, horizontalOutside, duration * 0.035, token, function()
			followPlushRig(sofaWristPoint)
		end) then
			cleanup()
			return
		end
		local uprightOutside = CFrame.new(extractionPosition) * plushRotation
		if not tweenModelPivot(plushClone, uprightOutside, duration * 0.025, token, function()
			followPlushRig(sofaWristPoint)
		end) then
			cleanup()
			return
		end
		sofaWristPoint = nil
		pickupWrist.Transparency = 1
	else
		local extractionStage = CFrame.new(extractionPosition) * plushRotation
		if not tweenModelPivot(plushClone, extractionStage, duration * 0.035, token, function()
			followPlushRig(nil)
		end) then
			cleanup()
			return
		end
	end

	local liftedStage = CFrame.new(
		extractionPosition.X,
		flightY - 1.12,
		extractionPosition.Z
	) * plushRotation
	if not tweenModelPivot(plushClone, liftedStage, duration * 0.04, token, function()
		followPlushRig(nil)
	end) then
		cleanup()
		return
	end
	local carryCFrame = robot:GetPivot() * CFrame.new(0, -0.95, 0.05)
	if not tweenModelPivot(plushClone, carryCFrame, duration * 0.035, token, function()
		followPlushRig(nil)
	end) then
		cleanup()
		return
	end

	local inbound = reversePositions(outbound)
	local safeInbound = prepareAerialAutomationPlans(robot, inbound, robot:GetPivot().Position)
	local function animateToyCarry(currentPivot)
		toyRotorAnimator(currentPivot)
		local carryPosition = currentPivot:PointToWorldSpace(Vector3.new(0, -0.95, 0.05))
		local look = currentPivot.LookVector
		local upright = CFrame.lookAt(
			carryPosition,
			carryPosition + Vector3.new(look.X, 0, look.Z)
		)
		plushClone:PivotTo(upright)
		local carriedPoint = plushClone:GetPivot().Position + Vector3.new(0, plushSize.Y * 0.28, 0)
		updatePickupRig(carriedPoint, 0.32, nil)
	end
	if #safeInbound == 0
		or not travelRobotPath(robot, safeInbound, duration * 0.245, token, animateToyCarry, "flight")
	then
		cleanup()
		return
	end
	-- The +Z 1.8 mattress approach is clear of the stuffed animal that remained
	-- on the bed, so the returned detailed clone never passes through it.
	local bedPlan = mattress.CFrame:PointToWorldSpace(Vector3.new(0, 0, 1.8))
	local bedHover = Vector3.new(bedPlan.X, flightY, bedPlan.Z)
	local safeBedApproach = prepareAerialAutomationPlans(robot, { bedHover }, robot:GetPivot().Position)
	if #safeBedApproach == 0
		or not travelRobotPath(robot, safeBedApproach, duration * 0.04, token, animateToyCarry, "flight")
	then
		cleanup()
		return
	end

	local homeCFrame = missyToyHomeCFrame(sourceToy) or sourceToy:GetPivot()
	local aboveHome = CFrame.new(
		homeCFrame.Position.X,
		flightY - 1.12,
		homeCFrame.Position.Z
	) * homeCFrame.Rotation
	if not tweenModelPivot(plushClone, aboveHome, duration * 0.035, token, function()
		followPlushRig(nil)
	end) or not tweenModelPivot(plushClone, homeCFrame, duration * 0.045, token, function()
		followPlushRig(nil)
	end) then
		cleanup()
		return
	end
	plushClone.Parent = taskVisuals
	plushClone:PivotTo(homeCFrame)
	stowPickupRig()
	local safeReturnToDock = prepareAerialAutomationPlans(
		robot,
		{ takeoff },
		robot:GetPivot().Position
	)
	if #safeReturnToDock == 0 then
		cleanup()
		return
	end

	local returnDuration = duration * 0.07
	local holdDuration = math.max(0, token.completesAt - serverNow() - returnDuration - 0.15)
	if holdDuration > 0 and not waitWithRotors(holdDuration) then
		cleanup()
		return
	end
	if not travelRobotPath(robot, safeReturnToDock, returnDuration * 0.45, token, animateToyRotors, "flight") then
		cleanup()
		return
	end
	-- Rotate while the rotors have full clearance, then descend with a fixed yaw.
	local alignedTakeoff = CFrame.new(takeoff) * home.Rotation
	if not tweenRobotPivot(robot, alignedTakeoff, returnDuration * 0.20, token, animateToyRotors) then
		cleanup()
		return
	end
	tweenRobotPivot(robot, home, returnDuration * 0.35, token, animateToyRotors)
	cleanup()
end

local beginTaskAutomation

local function snapshotHasAutomationRun(current, upgradeId, metadata)
	local automationState = current and current.automation
	local runs = automationState and automationState.activeRuns
	if type(runs) ~= "table" then
		return false
	end
	for _, run in ipairs(runs) do
		if type(run) == "table"
			and tostring(run.upgradeId or "") == upgradeId
			and tostring(run.runId or "") == tostring(metadata.runId or "")
			and (metadata.taskId == nil or tostring(run.taskId or "") == tostring(metadata.taskId))
		then
			return true
		end
	end
	return false
end

local function drainTaskAutomationQueue(upgradeId)
	local queue = taskAutomationQueues[upgradeId]
	while queue and #queue > 0 and activeTaskAutomation[upgradeId] == nil do
		local nextEntry = table.remove(queue, 1)
		if nextEntry.player and nextEntry.player.Parent == Players then
			-- Admission already proved this exact run against CooperGame while its
			-- authoritative record was live. That task may have paid and advanced
			-- while another owner's shared robot visual occupied the physical slot.
			beginTaskAutomation(
				nextEntry.player,
				upgradeId,
				nextEntry.metadata,
				nextEntry.proofValidated == true
			)
		end
	end
end

beginTaskAutomation = function(player, upgradeId, metadata, runProofValidated)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players
		or type(upgradeId) ~= "string" or type(metadata) ~= "table"
	then
		return
	end
	local robot = taskAutomationRobots[upgradeId]
	if not robot then
		return
	end
	-- Fire only comes from CooperGame's BindableEvent, but still confirm the
	-- persistent catalog so a stale internal call cannot animate an unowned bot.
	local current = snapshot(player)
	if not snapshotOwnsAutomation(current, upgradeId) then
		warn("[CooperTaskWorld] Rejected unowned automation visual for " .. upgradeId)
		return
	end
	if runProofValidated ~= true and not snapshotHasAutomationRun(current, upgradeId, metadata) then
		-- Only the initial BindableEvent admission can turn live CooperGame state
		-- into a queued visual proof. Queue drains may reuse that proof, but an
		-- arbitrary late/stale event can never animate an unregistered run.
		return
	end
	runProofValidated = true
	if activeTaskAutomation[upgradeId] then
		local queue = taskAutomationQueues[upgradeId]
		table.insert(queue, {
			player = player,
			metadata = metadata,
			proofValidated = runProofValidated,
		})
		return
	end
	local configuredDuration = math.clamp(finiteNumber(metadata.duration, 8), 1, 60)
	-- Payment and next-task assignment remain on CooperGame's original wall
	-- clock. This second clock belongs only to the shared physical robot: every
	-- admitted owner gets the complete animation even after waiting in line.
	local visualStartedAt = serverNow()
	local visualCompletesAt = visualStartedAt + configuredDuration
	local duration = configuredDuration
	local token = {
		upgradeId = upgradeId,
		player = player,
		startedAt = visualStartedAt,
		completesAt = visualCompletesAt,
		authoritativeStartedAt = finiteNumber(metadata.startedAt, visualStartedAt),
		authoritativeCompletesAt = finiteNumber(metadata.completesAt, visualCompletesAt),
		runId = tostring(metadata.runId or ""),
		cancelled = false,
		finished = false,
	}
	activeTaskAutomation[upgradeId] = token
	robot:SetAttribute("AutomationRunning", true)
	robot:SetAttribute("AutomationCancelling", false)
	robot:SetAttribute("AutomationOwnerUserId", player.UserId)
	robot:SetAttribute("AutomationTaskId", tostring(metadata.taskId or ""))
	robot:SetAttribute("AutomationStartedAt", token.startedAt)
	robot:SetAttribute("AutomationCompletesAt", token.completesAt)
	setAutomationRobotVisible(upgradeId, true)
	task.spawn(function()
		local ok, err = pcall(function()
			if upgradeId == "BeerBot" then
				runBeerBot(robot, duration, token)
			elseif upgradeId == "DishBot" then
				runDishBot(robot, duration, token)
			elseif upgradeId == "TrashBot" then
				runTrashBot(robot, duration, token)
			elseif upgradeId == "ToyFinder" then
				runToyFinder(robot, duration, metadata, token)
			elseif upgradeId == "HackerBot" then
				runHackerBot(robot, duration, metadata, token)
			end
		end)
		if not ok then
			warn("[CooperTaskWorld] " .. upgradeId .. " visual failed: " .. tostring(err))
		end
		-- Every mobile automation can temporarily hold a door open or move a
		-- chore prop out of its authored home. Always run its idempotent cleanup,
		-- including after cancellation or an unexpected animation error.
		if token.cleanup then
			local cleanupOk, cleanupErr = pcall(token.cleanup)
			if not cleanupOk then
				warn("[CooperTaskWorld] " .. upgradeId .. " cleanup failed: " .. tostring(cleanupErr))
			end
			token.cleanup = nil
		end
		if activeTaskAutomation[upgradeId] == token then
			activeTaskAutomation[upgradeId] = nil
			restoreAutomationRobot(robot)
			robot:SetAttribute("AutomationRunning", false)
			robot:SetAttribute("AutomationOwnerUserId", nil)
			robot:SetAttribute("AutomationCancelling", false)
			token.finished = true
			refreshAutomationVisibility()
			drainTaskAutomationQueue(upgradeId)
		end
	end)
end

runTaskAutomation.Event:Connect(beginTaskAutomation)

task.spawn(function()
	while world.Parent do
		refreshAutomationVisibility()
		task.wait(2.5)
	end
end)

local function anyPlacedBoomboxOwner()
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate:GetAttribute("CooperBoomboxPlaced") == true then
			return true
		end
	end
	return false
end

local function setBoomboxVisible(visible)
	for _, metadata in ipairs(boomboxParts) do
		local item = metadata.part
		if item.Parent then
			item.Transparency = visible and metadata.visibleTransparency or 1
			item.CanCollide = visible and metadata.visibleCanCollide or false
			item.CanTouch = false
			item.CanQuery = visible and metadata.visibleCanCollide or false
		end
	end
	for _, gui in ipairs(boomboxSurfaceGuis) do
		if gui.Parent then
			gui.Enabled = visible
		end
	end
	boomboxModel:SetAttribute("PlacedVisible", visible)
	boomboxModel:SetAttribute("Placed", visible)
end

local function setDiscoActive(active)
	for _, metadata in ipairs(boomboxLights) do
		if metadata.light.Parent then
			metadata.light.Enabled = active
			metadata.light.Brightness = metadata.brightness
			local emitter = metadata.light.Parent
			local restCFrame = emitter:IsA("BasePart") and emitter:GetAttribute("RestCFrame") or nil
			if not active and emitter:IsA("BasePart") and typeof(restCFrame) == "CFrame" then
				emitter.CFrame = restCFrame
			end
		end
	end
	for _, metadata in ipairs(boomboxFloorPools) do
		local item = metadata.part
		if item.Parent then
			item.Transparency = active and metadata.playingTransparency or 1
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
		end
	end
	boomboxModel:SetAttribute("Playing", active)
end

local function refreshBoomboxVisibility()
	setBoomboxVisible(activeBoomboxSession ~= nil or anyPlacedBoomboxOwner())
	if activeBoomboxSession == nil then
		setDiscoActive(false)
	end
end

local function animateDisco(session)
	local startedAt = serverNow()
	local bpm = math.max(1, finiteNumber(Config.Boombox and Config.Boombox.DanceBPM, 130))
	local beatPeriod = 60 / bpm
	local beatOffset = finiteNumber(Config.Boombox and Config.Boombox.DanceBeatOffsetSeconds, 0.16)
	task.spawn(function()
		while activeBoomboxSession == session and boomboxSound.Playing do
			local elapsed = serverNow() - startedAt
			local audioTime = math.max(0, finiteNumber(boomboxSound.TimePosition, elapsed))
			local beatPosition = (audioTime - beatOffset) / beatPeriod
			local beatPhase = beatPosition - math.floor(beatPosition)
			local beatPulse = math.exp(-beatPhase * 4.8)
			for index, metadata in ipairs(boomboxLights) do
				local colorPosition = (elapsed * 0.9 + (index - 1) * 0.82) % #discoPalette
				local firstIndex = math.floor(colorPosition) + 1
				local secondIndex = firstIndex % #discoPalette + 1
				local alpha = colorPosition - math.floor(colorPosition)
				metadata.light.Color = discoPalette[firstIndex]:Lerp(discoPalette[secondIndex], alpha)
				metadata.light.Brightness = metadata.brightness * (0.88 + 0.30 * beatPulse)
				local emitter = metadata.light.Parent
				local restCFrame = emitter:IsA("BasePart") and emitter:GetAttribute("RestCFrame") or nil
				if emitter:IsA("BasePart") and typeof(restCFrame) == "CFrame" then
					local phase = finiteNumber(emitter:GetAttribute("SweepPhase"), index)
					emitter.CFrame = restCFrame * CFrame.Angles(
						math.rad(11) * math.sin(elapsed * 1.25 + phase),
						math.rad(21) * math.sin(elapsed * 0.9 + phase * 0.7),
						0
					)
				end
			end
			for index, metadata in ipairs(boomboxFloorPools) do
				local item = metadata.part
				if item.Parent then
					local colorPosition = (elapsed * 0.75 + (index - 1) * 1.17) % #discoPalette
					local firstIndex = math.floor(colorPosition) + 1
					local secondIndex = firstIndex % #discoPalette + 1
					item.Color = discoPalette[firstIndex]:Lerp(
						discoPalette[secondIndex],
						colorPosition - math.floor(colorPosition)
					)
					item.Transparency = math.clamp(metadata.playingTransparency + 0.08 - 0.16 * beatPulse, 0.35, 0.72)
				end
			end
			for index, lens in ipairs(boomboxDiscoLenses) do
				if lens.Parent then
					lens.Color = discoPalette[((index + math.floor(elapsed * 2)) - 1) % #discoPalette + 1]
				end
			end
			task.wait(0.12)
		end
	end)
end

local audioDurationWarningIssued = false
local function boomboxAudioIsReady()
	local ready = boomboxSound.IsLoaded and boomboxSound.TimeLength > 1
	boomboxModel:SetAttribute("AudioReady", ready)
	if ready then
		boomboxModel:SetAttribute("LoadedAudioDuration", boomboxSound.TimeLength)
		local expected = Config.Boombox and Config.Boombox.TrackDuration or 22.465306
		if not audioDurationWarningIssued and math.abs(boomboxSound.TimeLength - expected) > 0.75 then
			audioDurationWarningIssued = true
			warn(string.format(
				"[CooperTaskWorld] Boombox audio duration %.3fs differs from configured %.3fs",
				boomboxSound.TimeLength,
				expected
			))
		end
	end
	return ready
end

local function ensureBoomboxAudioLoaded(timeoutSeconds)
	if boomboxAudioIsReady() then
		return true
	end
	local preloadFinished = false
	local preloadOk = false
	task.spawn(function()
		preloadOk = pcall(function()
			ContentProvider:PreloadAsync({ boomboxSound })
		end)
		preloadFinished = true
	end)
	local deadline = os.clock() + math.clamp(finiteNumber(timeoutSeconds, 8), 2, 15)
	repeat
		if boomboxAudioIsReady() then
			return true
		end
		task.wait(0.1)
	until os.clock() >= deadline or preloadFinished
	local loaded = preloadOk and boomboxAudioIsReady()
	return loaded
end

local function reportBoomboxFailure(player, message)
	report("BoomboxPlaybackFailed", player, {
		message = message,
	})
end

local function runBoomboxPayouts(session)
	task.spawn(function()
		for tickIndex = 1, session.maxTicks do
			-- A small positive margin avoids network-frame jitter being treated as
			-- an early tick. Natural completion authoritatively settles the final
			-- tick if Sound.Ended races this exact boundary.
			local targetTime = session.startedAt + tickIndex * session.interval + 0.035
			while activeBoomboxSession == session and serverNow() < targetTime do
				task.wait(math.min(0.1, math.max(0.02, targetTime - serverNow())))
			end
			if activeBoomboxSession ~= session or not boomboxSound.Playing then
				break
			end
			local tickResult = invokeFamily("BoomboxPayoutTick", session.player, session.sessionId)
			if type(tickResult) ~= "table" or tickResult.ok ~= true then
				local retryAfter = type(tickResult) == "table" and finiteNumber(tickResult.retryAfter, 0) or 0
				if retryAfter > 0 and retryAfter <= 0.35 then
					task.wait(retryAfter + 0.02)
					tickResult = invokeFamily("BoomboxPayoutTick", session.player, session.sessionId)
				end
				if type(tickResult) ~= "table" or tickResult.ok ~= true then
					break
				end
			end
		end
	end)
end

finishBoomboxPlayback = function(session, reason, stopSound)
	if not session or activeBoomboxSession ~= session then
		return
	end
	activeBoomboxSession = nil
	boomboxActivationInProgress = false
	if stopSound and boomboxSound.Playing then
		boomboxSound:Stop()
	end
	setDiscoActive(false)
	boomboxModel:SetAttribute("PlaybackSession", nil)
	boomboxModel:SetAttribute("PlaybackOwnerUserId", nil)
	invokeFamily("EndBoomboxPlayback", session.player, session.sessionId, reason)
	refreshBoomboxVisibility()
end

local function startBoomboxPlayback(player, automatic)
	automatic = automatic == true
	if activeBoomboxSession or boomboxActivationInProgress then
		if not automatic then
			reportBoomboxFailure(player, "The boombox is already playing.")
		end
		return false
	end
	local current = snapshot(player)
	if not current or not current.boombox or current.boombox.placed ~= true then
		if not automatic then
			reportBoomboxFailure(player, "Set up your boombox in the living room first.")
		end
		return false
	end
	if automatic and current.boombox.autoplayPurchased ~= true then
		return false
	end
	-- Prompt.Enabled is presentation, not an authorization boundary. A client
	-- can still attempt to trigger a disabled ProximityPrompt, so reject the
	-- request before loading or starting the shared Sound as well as retaining
	-- CooperGame's authoritative BeginBoomboxPlayback check below.
	if current.boombox.canPlay ~= true then
		if not automatic then
			local remaining = math.max(0, math.ceil(finiteNumber(current.boombox.cooldownRemaining, 0)))
			local message = if current.boombox.occupiedByOther == true
				then "Someone else is already using the living-room boombox."
				elseif remaining > 0
					then "The boombox is cooling down. Ready in " .. formatCountdown(remaining) .. "."
					else "The boombox is not ready yet."
			reportBoomboxFailure(player, message)
		end
		return false
	end
	boomboxActivationInProgress = true
	task.spawn(function()
		local preloadTimeout = Config.Boombox and Config.Boombox.PreloadTimeoutSeconds or 8
		if not ensureBoomboxAudioLoaded(preloadTimeout) then
			boomboxActivationInProgress = false
			reportBoomboxFailure(player, "The song could not load. Check this experience's audio permission and try again.")
			refreshBoomboxVisibility()
			return
		end
		if player.Parent ~= Players or activeBoomboxSession then
			boomboxActivationInProgress = false
			return
		end
		setBoomboxVisible(true)
		boomboxSound.TimePosition = 0
		boomboxSound:Play()
		RunService.Heartbeat:Wait()
		if not boomboxSound.Playing then
			boomboxActivationInProgress = false
			reportBoomboxFailure(player, "The song could not start. Check this experience's audio permission and try again.")
			refreshBoomboxVisibility()
			return
		end
		local source = automatic and "Autoplay" or "Manual"
		local beginResult = invokeFamily("BeginBoomboxPlayback", player, source)
		if type(beginResult) ~= "table" or beginResult.ok ~= true then
			boomboxSound:Stop()
			boomboxActivationInProgress = false
			refreshBoomboxVisibility()
			return
		end
		local session = {
			player = player,
			sessionId = beginResult.sessionId,
			source = source,
			startedAt = serverNow(),
			duration = finiteNumber(beginResult.duration, 22.465306),
			interval = finiteNumber(beginResult.interval, 2.2465306),
			maxTicks = math.clamp(math.floor(finiteNumber(beginResult.maxTicks, 10)), 1, 50),
		}
		activeBoomboxSession = session
		boomboxActivationInProgress = false
		boomboxModel:SetAttribute("PlaybackSession", session.sessionId)
		boomboxModel:SetAttribute("PlaybackOwnerUserId", player.UserId)
		setDiscoActive(true)
		animateDisco(session)
		runBoomboxPayouts(session)
		task.spawn(function()
			local deadline = session.startedAt + session.duration + 2
			while activeBoomboxSession == session and serverNow() < deadline do
				if not boomboxSound.Playing and serverNow() > session.startedAt + 0.5 then
					task.wait(0.25)
					if activeBoomboxSession == session and not boomboxSound.Playing then
						finishBoomboxPlayback(session, "Interrupted", false)
					end
					return
				end
				task.wait(0.1)
			end
			if activeBoomboxSession == session then
				finishBoomboxPlayback(session, "Watchdog", true)
			end
		end)
	end)
	return true
end

boomboxSound.Ended:Connect(function()
	local session = activeBoomboxSession
	if session then
		finishBoomboxPlayback(session, "Completed", false)
	end
end)

task.spawn(function()
	ensureBoomboxAudioLoaded(Config.Boombox and Config.Boombox.PreloadTimeoutSeconds or 8)
end)

-- Autoplay is online-only and reuses the exact manual Sound/session/payout
-- path. A deterministic round-robin keeps multiple upgraded owners fair while
-- the shared living-room setpiece remains globally single-session.
task.spawn(function()
	while task.wait(0.5) do
		if not activeBoomboxSession and not boomboxActivationInProgress then
			local now = serverNow()
			local candidates = {}
			for _, candidate in ipairs(Players:GetPlayers()) do
				if now >= (autoplayRetryAt[candidate] or 0) then
					local current = snapshot(candidate)
					local boombox = current and current.boombox
					if boombox
						and boombox.placed == true
						and boombox.autoplayPurchased == true
						and boombox.canPlay == true
					then
						table.insert(candidates, candidate)
					end
				end
			end
			table.sort(candidates, function(left, right)
				return left.UserId < right.UserId
			end)
			if #candidates > 0 then
				local selected = candidates[1]
				for _, candidate in ipairs(candidates) do
					if candidate.UserId > lastAutoplayUserId then
						selected = candidate
						break
					end
				end
				lastAutoplayUserId = selected.UserId
				autoplayRetryAt[selected] = now + 20
				startBoomboxPlayback(selected, true)
			end
		end
	end
end)

local function weldToHandle(handle, item)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "TaskItemWeld"
	weld.Part0 = handle
	weld.Part1 = item
	weld.Parent = item
end

local function setTruckVisible(visible)
	for _, descendant in ipairs(truck:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local isGlass = descendant.Name == "Windshield"
			if visible then
				descendant.Transparency = isGlass and 0.15 or 0
				descendant.CanCollide = not isGlass
				descendant.CanQuery = true
			else
				descendant.Transparency = 1
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
			descendant.CanTouch = false
			descendant.Anchored = true
		elseif descendant:IsA("SurfaceGui") then
			-- SurfaceGuis can render even while their adornee is transparent.
			-- Explicitly hide the delivery sign with the rest of the truck.
			descendant.Enabled = visible
		end
	end
	truck:SetAttribute("Hidden", not visible)
end

local function animateTruck(fromCFrame, toCFrame, duration)
	local started = os.clock()
	repeat
		local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
		local eased = 1 - (1 - alpha) * (1 - alpha)
		truck:PivotTo(fromCFrame:Lerp(toCFrame, eased))
		RunService.Heartbeat:Wait()
	until alpha >= 1 or not truck.Parent
end

-- Los Pollos buyer truck ---------------------------------------------------
-- This is a sale destination, not another delivery crate. It shares the street
-- route through a short ownership lock, parks for a generous handoff window,
-- then leaves or requeues without ever overlapping the ordinary delivery truck.
local buyerQueue = {}
local buyerQueued = {}
local buyerInProgress = {}
local buyerQueueRunning = false
local activeBuyerSession = nil
local runBuyerQueue

local function buyerPart(model, name, localCFrame, size, color, material, canCollide, transparency, shape)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = CFrame.new(truckSpawn.Position) * localCFrame
	item.Color = color
	item.Material = material or Enum.Material.Metal
	item.Transparency = tonumber(transparency) or 0
	item.Shape = shape or Enum.PartType.Block
	item.Anchored = true
	item.CanCollide = canCollide == true
	item.CanTouch = false
	item.CanQuery = canCollide == true
	item.CastShadow = transparency == nil or transparency < 0.9
	item.Parent = model
	return item
end

local function createLosPollosBuyerTruck(ownerPlayer)
	local model = Instance.new("Model")
	model.Name = tostring(candyDeliveryConfig.TruckModelName or "LosPollosBuyerTruck")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("LosPollosDeliveryTruck", true)
	model:SetAttribute("OwnerUserId", ownerPlayer.UserId)
	model:SetAttribute("LogoAssetName", tostring(candyDeliveryConfig.LogoName or "Los_Pollos_Hermanos_logo"))
	model:SetAttribute("LogoCatalogAssetId", tostring(candyDeliveryConfig.LogoCatalogAssetId))
	model:SetAttribute("LogoAssetId", tostring(candyDeliveryConfig.LogoAssetId))

	local yellow = Color3.fromRGB(247, 190, 34)
	local warmYellow = Color3.fromRGB(255, 210, 58)
	local darkRed = Color3.fromRGB(151, 43, 34)
	local chassis = buyerPart(model, "Chassis", CFrame.new(), Vector3.new(6.4, 1.0, 13.2), Color3.fromRGB(54, 55, 51), Enum.Material.Metal, true)
	model.PrimaryPart = chassis
	buyerPart(model, "YellowCab", CFrame.new(0, 2.2, -3.85), Vector3.new(5.9, 3.6, 4.5), warmYellow, Enum.Material.Metal, true)
	local cargoBox = buyerPart(model, "YellowCargoBox", CFrame.new(0, 3.05, 2.5), Vector3.new(6.05, 5.05, 7.5), yellow, Enum.Material.Metal, true)
	buyerPart(model, "FrontBumper", CFrame.new(0, 0.45, -6.8), Vector3.new(6.35, 0.46, 0.35), Color3.fromRGB(164, 170, 165), Enum.Material.Metal, true)
	buyerPart(model, "RearBumper", CFrame.new(0, 0.45, 6.8), Vector3.new(6.35, 0.46, 0.35), Color3.fromRGB(164, 170, 165), Enum.Material.Metal, true)
	buyerPart(model, "Windshield", CFrame.new(0, 2.75, -6.12), Vector3.new(4.75, 1.65, 0.12), Color3.fromRGB(86, 145, 165), Enum.Material.Glass, false, 0.18)
	for index, wheelOffset in ipairs({
		Vector3.new(-3.18, -0.14, -3.8),
		Vector3.new(3.18, -0.14, -3.8),
		Vector3.new(-3.18, -0.14, 3.9),
		Vector3.new(3.18, -0.14, 3.9),
	}) do
		local wheel = buyerPart(
			model,
			"Wheel" .. tostring(index),
			CFrame.new(wheelOffset),
			Vector3.new(0.92, 2.35, 2.35),
			Color3.fromRGB(24, 25, 23),
			Enum.Material.Rubber,
			true,
			0,
			Enum.PartType.Cylinder
		)
		wheel:SetAttribute("BuyerTruckWheel", true)
	end
	for _, x in ipairs({ -1.75, 1.75 }) do
		local lamp = buyerPart(model, "Headlight", CFrame.new(x, 1.35, -6.14), Vector3.new(0.62, 0.48, 0.13), Color3.fromRGB(255, 247, 187), Enum.Material.Neon, false)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Brightness = 0.65
		light.Range = 8
		light.Angle = 75
		light.Color = lamp.Color
		light.Parent = lamp
	end

	for _, side in ipairs({ -1, 1 }) do
		local plate = buyerPart(
			model,
			"LosPollosLogoPlate" .. (side < 0 and "Left" or "Right"),
			CFrame.new(side * 3.055, 3.15, 2.45),
			Vector3.new(0.08, 3.75, 4.85),
			Color3.fromRGB(255, 232, 113),
			Enum.Material.SmoothPlastic,
			false
		)
		plate:SetAttribute("LosPollosLogoPanel", true)
		local decal = Instance.new("Decal")
		decal.Name = "Los_Pollos_Hermanos_logo"
		decal.Texture = tostring(candyDeliveryConfig.LogoAssetId)
		decal.Face = side < 0 and Enum.NormalId.Left or Enum.NormalId.Right
		decal.Color3 = Color3.new(1, 1, 1)
		decal.Transparency = 0
		decal.Parent = plate
	end
	local rearSign = buyerPart(model, "BuyerRearSign", CFrame.new(0, 3.1, 6.27), Vector3.new(4.5, 1.45, 0.08), darkRed, Enum.Material.SmoothPlastic, false)
	local rearGui = Instance.new("SurfaceGui")
	rearGui.Name = "BuyerRearGui"
	rearGui.Face = Enum.NormalId.Back
	rearGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	rearGui.PixelsPerStud = 55
	rearGui.Parent = rearSign
	local rearText = Instance.new("TextLabel")
	rearText.Size = UDim2.fromScale(1, 1)
	rearText.BackgroundTransparency = 1
	rearText.Text = "LOS POLLOS HERMANOS" .. string.char(10) .. "SPECIAL PICKUP"
	rearText.TextColor3 = Color3.fromRGB(255, 246, 207)
	rearText.Font = Enum.Font.GothamBlack
	rearText.TextScaled = true
	rearText.TextWrapped = true
	rearText.Parent = rearGui

	local stopFacing = CFrame.lookAt(
		truckStop.Position,
		truckStop.Position + (truckStop.Position - truckApproach.Position)
	)
	local dropSide = stopFacing:PointToObjectSpace(dropZone.Position).X >= 0 and 1 or -1
	local dropAnchor = buyerPart(
		model,
		"CandyDeliveryDropoff_" .. tostring(ownerPlayer.UserId),
		CFrame.new(dropSide * 4.25, 1.55, 1.2),
		Vector3.new(2.4, 3.0, 3.2),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false,
		1
	)
	dropAnchor.CanQuery = false
	dropAnchor:SetAttribute("CandyDeliveryDropoff", true)
	dropAnchor:SetAttribute("OwnerUserId", ownerPlayer.UserId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = tostring(candyDeliveryConfig.DropPromptName or "LosPollosCandyDropPrompt")
	prompt.ActionText = "Deliver Candy Pan"
	prompt.ObjectText = "Los Pollos Hermanos Buyer"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("CandyDeliveryDropoff", true)
	prompt:SetAttribute("OwnerUserId", ownerPlayer.UserId)
	prompt.Parent = dropAnchor
	cargoBox:SetAttribute("LosPollosYellowBody", true)
	-- Publish the model only after its complete collidable body, owner lock, logo,
	-- target, and prompt exist. If construction ever errors, no half-built truck is
	-- left behind in the live delivery world.
	model.Parent = deliveryWorld
	return model, dropAnchor, prompt
end

local function animateBuyerTruck(model, fromCFrame, toCFrame, duration, session)
	local started = os.clock()
	repeat
		if not model.Parent or session.cancelled then
			return false
		end
		local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
		local eased = 1 - (1 - alpha) * (1 - alpha)
		model:PivotTo(fromCFrame:Lerp(toCFrame, eased))
		RunService.Heartbeat:Wait()
	until alpha >= 1
	return true
end

local function equippedCandyPan(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool")
			and child:GetAttribute("CooperBlueRockCandy") == true
			and child:GetAttribute("ProductKind") == "BlueRockCandy"
		then
			return child
		end
	end
	return nil
end

local function candyContract(player)
	local current = snapshot(player)
	local contract = current and current.candyDelivery
	return type(contract) == "table" and contract or nil
end

local function queueCandyBuyer(player)
	if not player or player.Parent ~= Players or buyerQueued[player] or buyerInProgress[player] then
		return false
	end
	if activeBuyerSession and activeBuyerSession.player == player then
		return false
	end
	local contract = candyContract(player)
	if not contract or contract.active ~= true or tostring(contract.batchToken or "") == "" then
		return false
	end
	buyerQueued[player] = true
	table.insert(buyerQueue, player)
	if runBuyerQueue then
		runBuyerQueue()
	end
	return true
end

runBuyerQueue = function()
	if buyerQueueRunning or activeBuyerSession or #buyerQueue == 0 then
		return
	end
	-- Reserve the one queue worker before spawning it. Ordinary truck animation
	-- can keep this worker waiting for several seconds, and the periodic recovery
	-- scan must never be able to launch a second waiter for the same route.
	buyerQueueRunning = true
	task.spawn(function()
		local workerPlayer
		local workerSession
		local routeReservationPending = false
		local ok, failure = xpcall(function()
			while #buyerQueue > 0 do
				local player = table.remove(buyerQueue, 1)
				workerPlayer = player
				buyerQueued[player] = nil
				-- This reservation is set before the first possible wait. It prevents
				-- recovery scans from requeueing this player while an ordinary truck owns
				-- the street, while the buyer truck is active, or during its retry pause.
				buyerInProgress[player] = true
				local contract = player and player.Parent == Players and candyContract(player) or nil
				if not contract or contract.active ~= true or tostring(contract.batchToken or "") == "" then
					buyerInProgress[player] = nil
					workerPlayer = nil
					continue
				end

				while deliveryRunning and player.Parent == Players do
					task.wait(0.35)
				end
				contract = player.Parent == Players and candyContract(player) or nil
				if not contract or contract.active ~= true or tostring(contract.batchToken or "") == "" then
					buyerInProgress[player] = nil
					workerPlayer = nil
					continue
				end

				-- Claim the shared street synchronously after the ordinary truck releases
				-- it. No other delivery worker can pass its buyerRouteOccupied guard now.
				buyerRouteOccupied = true
				routeReservationPending = true
				local model, dropAnchor, prompt = createLosPollosBuyerTruck(player)
				local session = {
					player = player,
					model = model,
					dropAnchor = dropAnchor,
					prompt = prompt,
					promptConnection = nil,
					batchToken = tostring(contract.batchToken),
					delivered = false,
					cancelled = false,
				}
				workerSession = session
				activeBuyerSession = session
				routeReservationPending = false

				local start = CFrame.lookAt(truckSpawn.Position, truckApproach.Position)
				local approach = CFrame.lookAt(truckApproach.Position, truckStop.Position)
				local stop = CFrame.lookAt(
					truckStop.Position,
					truckStop.Position + (truckStop.Position - truckApproach.Position)
				)
				model:PivotTo(start)
				local arrived = animateBuyerTruck(model, start, approach, 4.6, session)
					and animateBuyerTruck(model, approach, stop, 1.8, session)
				if arrived and player.Parent == Players then
					prompt.Enabled = true
					session.promptConnection = prompt.Triggered:Connect(function(triggeringPlayer)
						if triggeringPlayer ~= player or session.delivered or session.cancelled then
							return
						end
						local root = rootPart(player)
						local liveContract = candyContract(player)
						local tool = equippedCandyPan(player)
						if not root or (root.Position - dropAnchor.Position).Magnitude > prompt.MaxActivationDistance + 3
							or not liveContract or liveContract.active ~= true
							or tostring(liveContract.batchToken or "") ~= session.batchToken
							or not tool
							or tool:GetAttribute("OwnerUserId") ~= player.UserId
							or tool:GetAttribute("BatchToken") ~= session.batchToken
						then
							return
						end
						prompt.Enabled = false
						local accepted = invokeFamily(
							"ReportAction",
							player,
							"CandyBatchDelivered",
							{ batchToken = session.batchToken }
						)
						if accepted == true then
							session.delivered = true
							if tool.Parent then
								tool:Destroy()
							end
						else
							prompt.Enabled = true
						end
					end)
				end

				local deadline = serverNow() + 90
				while arrived and not session.delivered and not session.cancelled
					and player.Parent == Players and serverNow() < deadline
				do
					local liveContract = candyContract(player)
					if not liveContract or liveContract.active ~= true then
						session.delivered = true
						break
					end
					task.wait(0.25)
				end

				prompt.Enabled = false
				if session.promptConnection then
					session.promptConnection:Disconnect()
					session.promptConnection = nil
				end
				if model.Parent and not session.cancelled then
					local parked = model:GetPivot()
					local exitApproach = CFrame.lookAt(truckApproach.Position, truckExit.Position)
					local exitPose = CFrame.lookAt(
						truckExit.Position,
						truckExit.Position + (truckExit.Position - truckApproach.Position)
					)
					animateBuyerTruck(model, parked, exitApproach, 1.8, session)
					animateBuyerTruck(model, exitApproach, exitPose, 4.6, session)
				end
				if model.Parent then
					model:Destroy()
				end
				-- Clear shared route state only for the exact session that set it. This
				-- prevents a stale callback from releasing another truck's route lock.
				if activeBuyerSession == session then
					activeBuyerSession = nil
					buyerRouteOccupied = false
				end
				workerSession = nil

				if #deliveryQueue > 0 then
					ordinaryDeliveryTurnReserved = true
				end
				if runDeliveryQueue then
					runDeliveryQueue()
				end
				local stillActive = player.Parent == Players and candyContract(player)
				if stillActive and stillActive.active == true and not session.delivered then
					-- Keep buyerInProgress reserved throughout the retry delay so the
					-- periodic recovery scan cannot insert duplicate copies of this owner.
					task.delay(5, function()
						if buyerInProgress[player] ~= true or player.Parent ~= Players then
							buyerInProgress[player] = nil
							return
						end
						local retryContract = candyContract(player)
						if not retryContract or retryContract.active ~= true
							or tostring(retryContract.batchToken or "") == ""
						then
							buyerInProgress[player] = nil
							return
						end
						buyerInProgress[player] = nil
						buyerQueued[player] = true
						table.insert(buyerQueue, player)
						runBuyerQueue()
					end)
				else
					buyerInProgress[player] = nil
				end
				workerPlayer = nil
				task.wait(0.5)
			end
		end, debug.traceback)

		-- A failed animation/build must not strand the shared street, an owner
		-- reservation, or a half-live session. All clears are identity guarded.
		if workerSession then
			workerSession.cancelled = true
			if workerSession.prompt then
				workerSession.prompt.Enabled = false
			end
			if workerSession.promptConnection then
				workerSession.promptConnection:Disconnect()
				workerSession.promptConnection = nil
			end
			if workerSession.model and workerSession.model.Parent then
				workerSession.model:Destroy()
			end
			if activeBuyerSession == workerSession then
				activeBuyerSession = nil
				buyerRouteOccupied = false
			end
		elseif routeReservationPending then
			-- Construction failed before a session was published.
			buyerRouteOccupied = false
		end
		if workerPlayer then
			buyerInProgress[workerPlayer] = nil
		end
		buyerQueueRunning = false
		if not ok then
			warn("[CooperTaskWorld] Buyer queue failed safely: " .. tostring(failure))
		end
		if not ok and not buyerRouteOccupied and not deliveryRunning and #deliveryQueue > 0 then
			ordinaryDeliveryTurnReserved = true
		end
		if not buyerRouteOccupied and runDeliveryQueue then
			runDeliveryQueue()
		end
		if not activeBuyerSession and #buyerQueue > 0 then
			runBuyerQueue()
		end
	end)
end

candyDeliveryChanged.Event:Connect(function(player, action)
	if action == "Start" or action == "Recover" then
		queueCandyBuyer(player)
	elseif action == "Complete" and activeBuyerSession and activeBuyerSession.player == player then
		activeBuyerSession.delivered = true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	buyerQueued[player] = nil
	buyerInProgress[player] = nil
	for index = #buyerQueue, 1, -1 do
		if buyerQueue[index] == player then
			table.remove(buyerQueue, index)
		end
	end
	if activeBuyerSession and activeBuyerSession.player == player then
		activeBuyerSession.cancelled = true
	end
end)

task.spawn(function()
	while task.wait(4) do
		for _, player in ipairs(Players:GetPlayers()) do
			local contract = candyContract(player)
			if contract and contract.active == true then
				queueCandyBuyer(player)
			end
		end
	end
end)

local function addCrateLabel(handle, text, color)
	local plate = Instance.new("Part")
	plate.Name = "LabelPlate"
	plate.Size = Vector3.new(0.06, handle.Size.Y * 0.62, handle.Size.Z * 0.72)
	plate.Material = Enum.Material.SmoothPlastic
	plate.Color = color
	plate.CanCollide = false
	plate.CanTouch = false
	plate.CanQuery = false
	plate.Massless = true
	plate.Anchored = false
	plate.CFrame = handle.CFrame * CFrame.new(handle.Size.X * 0.5 + 0.04, 0, 0)
	plate.Parent = handle.Parent
	weldToHandle(handle, plate)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "CrateLabel"
	gui.Face = Enum.NormalId.Right
	gui.AlwaysOnTop = false
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 247, 220)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
end

local function createCarryTool(name, displayName, ownerUserId, color, size, spawnOffset)
	local tool = Instance.new("Tool")
	-- Backpack slots render Tool.Name, so never expose delivery IDs to players.
	-- The internal identifier remains available as an attribute for diagnostics.
	tool.Name = displayName
	tool.ToolTip = displayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("InternalDeliveryName", name)
	tool:SetAttribute("DisplayName", displayName)
	tool:SetAttribute("OwnerUserId", ownerUserId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = Enum.Material.WoodPlanks
	handle.Anchored = true
	handle.CanCollide = true
	handle.CanTouch = false
	local offset = spawnOffset or Vector3.zero
	local spawnPlan = dropZone.CFrame:PointToWorldSpace(Vector3.new(offset.X, 0, offset.Z))
	-- The neon guidance marker intentionally hovers above the driveway and is
	-- not a physical floor. Ground every crate directly on the authored driveway
	-- top, independent of players, the truck, markers, and earlier deliveries.
	local driveway = environment:FindFirstChild("SideDriveway", true)
	local groundY = driveway and driveway:IsA("BasePart")
		and driveway.Position.Y + driveway.Size.Y * 0.5
		or dropZone.Position.Y - dropZone.Size.Y * 0.5
	handle.CFrame = CFrame.new(spawnPlan.X, groundY + size.Y * 0.5 + 0.03, spawnPlan.Z)
		* dropZone.CFrame.Rotation
	handle.Parent = tool

	local bandLeft = Instance.new("Part")
	bandLeft.Name = "BandLeft"
	bandLeft.Size = Vector3.new(0.18, size.Y + 0.04, size.Z + 0.05)
	bandLeft.Color = Color3.fromRGB(70, 69, 66)
	bandLeft.Material = Enum.Material.Metal
	bandLeft.Anchored = false
	bandLeft.CanCollide = false
	bandLeft.Massless = true
	bandLeft.CFrame = handle.CFrame * CFrame.new(-size.X * 0.27, 0, 0)
	bandLeft.Parent = tool
	weldToHandle(handle, bandLeft)

	local bandRight = bandLeft:Clone()
	bandRight.Name = "BandRight"
	bandRight.CFrame = handle.CFrame * CFrame.new(size.X * 0.27, 0, 0)
	bandRight.Parent = tool
	bandRight:FindFirstChild("TaskItemWeld"):Destroy()
	weldToHandle(handle, bandRight)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeliveryPickupPrompt"
	prompt.ActionText = "Pick Up Delivery"
	prompt.ObjectText = displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.45
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("FamilyTaskAction", "DeliveryPickup")
	prompt.Parent = handle
	return tool
end

local function applyBeerSixPackVisual(tool)
	local beerBot = taskAutomationRobots.BeerBot
	local template = beerBot and beerBot:FindFirstChild("BeerCaseVisual")
	local handle = tool and tool:FindFirstChild("Handle")
	if not template or not template:IsA("Model") or not handle or not handle:IsA("BasePart") then
		return false
	end
	for _, childName in ipairs({ "BandLeft", "BandRight", "LabelPlate" }) do
		local child = tool:FindFirstChild(childName)
		if child then
			child:Destroy()
		end
	end
	handle.Transparency = 1
	handle.Material = Enum.Material.SmoothPlastic
	local visual = template:Clone()
	visual.Name = "LoneStarSixPackVisual"
	visual.Parent = tool
	visual:PivotTo(handle.CFrame)
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local activeTransparency = descendant:GetAttribute("AutomationActiveTransparency")
			descendant.Transparency = type(activeTransparency) == "number"
				and math.clamp(activeTransparency, 0, 1)
				or 0
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			weldToHandle(handle, descendant)
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			local activeEnabled = descendant:GetAttribute("AutomationActiveEnabled")
			descendant.Enabled = activeEnabled ~= false
		elseif descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
	return true
end

local function deliveryKey(ownerUserId, kind)
	return tostring(ownerUserId) .. ":" .. tostring(kind)
end

local SAFE_DELIVERY_LANES = { 0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6 }
for lane = 7, 18 do
	-- The garage occupies the positive end beyond +6. The driveway remains
	-- swept-clear toward the street/rear through -18.
	table.insert(SAFE_DELIVERY_LANES, -lane)
end

local function deliveryCrateSize(kind)
	if kind == "MachinePart" then
		return Vector3.new(3.8, 2.6, 3.2)
	elseif kind == "Boombox" then
		return Vector3.new(3.0, 1.8, 2.4)
	elseif kind == "TaskUpgrade" then
		return Vector3.new(3.1, 2.0, 2.6)
	elseif kind == "ChemistrySetup" then
		-- Compact enough for the physical hatch and ladder route; the full lab
		-- assembles only after the owner reaches the underground equipment pad.
		return Vector3.new(2.4, 1.7, 2.0)
	elseif kind == "Beer" then
		return Vector3.new(1.2, 1.05, 1.0)
	end
	return Vector3.new(3.4, 2.1, 2.8)
end

-- Keep every crate centered across the eight-stud driveway so even the widest
-- box clears both curb and house wall. Concurrent deliveries use only the 25
-- swept-safe longitudinal lanes; extra requests remain queued until one frees.
local function allocateDeliverySpawnOffset(kind, size)
	local baseX = 0
	local slotSpacing = 3.8
	for _, lane in ipairs(SAFE_DELIVERY_LANES) do
		local candidate = Vector3.new(baseX, 0, lane * slotSpacing)
		local occupied = false
		for _, record in pairs(deliveryRecordsById) do
			local handle = record.status == "World" and record.tool and record.tool:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and handle.Parent and not record.consumed then
				local relative = dropZone.CFrame:PointToObjectSpace(handle.Position)
				local separatedX = math.abs(relative.X - candidate.X) >= (handle.Size.X + size.X) * 0.5 + 0.25
				local separatedZ = math.abs(relative.Z - candidate.Z) >= (handle.Size.Z + size.Z) * 0.5 + 0.25
				if not separatedX and not separatedZ then
					occupied = true
					break
				end
			end
		end
		if not occupied then
			return candidate, lane
		end
	end
	return nil, nil
end

local function ensureCompatibilityTarget(player, kind)
	local isBoombox = kind == "Boombox"
	local isTaskUpgrade = kind == "TaskUpgrade"
	local isChemistrySetup = kind == "ChemistrySetup"
	local targetRegistry = if isBoombox
		then boomboxCompatibilityTargets
		elseif isTaskUpgrade
			then taskUpgradeCompatibilityTargets
		elseif isChemistrySetup
			then chemistryCompatibilityTargets
			else compatibilityTargets
	local existing = targetRegistry[player]
	if existing and existing.Parent then
		return existing
	end
	local targetName = if isBoombox
		then "Delivery_Boombox_" .. tostring(player.UserId)
		elseif isTaskUpgrade
			then "Delivery_TaskUpgrade_" .. tostring(player.UserId)
		elseif isChemistrySetup
			then "Delivery_ChemistrySetup_" .. tostring(player.UserId)
			else "Delivery_" .. tostring(player.UserId)
	existing = deliveryWorld:FindFirstChild(targetName)
	if existing and not existing:IsA("BasePart") then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new("Part")
		existing.Name = targetName
		existing.Size = Vector3.new(0.2, 0.2, 0.2)
		existing.Transparency = 1
		existing.Anchored = true
		existing.CanCollide = false
		existing.CanTouch = false
		existing.CanQuery = false
		existing.CastShadow = false
		existing:SetAttribute("DeliveryGuidanceTarget", true)
		existing.Parent = deliveryWorld
	end
	existing.CFrame = dropZone.CFrame * CFrame.new(0, 0.2, 0)
	targetRegistry[player] = existing
	return existing
end

local function recordForTool(tool)
	if not tool then
		return nil
	end
	local id = tool:GetAttribute("DeliveryId")
	local record = type(id) == "string" and deliveryRecordsById[id] or nil
	if not record or record.tool ~= tool then
		return nil
	end
	if deliveryRecordsByKey[record.key] ~= record then
		return nil
	end
	return record
end

local function clearDeliveryRecord(record, destroyTool)
	if not record then
		return
	end
	record.consumed = true
	if deliveryRecordsByKey[record.key] == record then
		deliveryRecordsByKey[record.key] = nil
	end
	if deliveryRecordsById[record.id] == record then
		deliveryRecordsById[record.id] = nil
	end
	if destroyTool and record.tool and record.tool.Parent then
		record.tool:Destroy()
	end
end

local function refreshCompatibilityTarget(player)
	if not player or player.Parent ~= Players then
		return
	end
	local target = ensureCompatibilityTarget(player)
	local boomboxTarget = ensureCompatibilityTarget(player, "Boombox")
	local taskUpgradeTarget = ensureCompatibilityTarget(player, "TaskUpgrade")
	local chemistryTarget = ensureCompatibilityTarget(player, "ChemistrySetup")
	local current = snapshot(player)
	local selected
	local selectedBoombox
	local selectedTaskUpgrade
	local selectedChemistry
	if current and current.task and current.task.id == "GeorgeBeer" and current.task.step == "Collect" then
		selected = deliveryRecordsByKey[deliveryKey(player.UserId, "Beer")]
	elseif current and current.delivery and current.delivery.kind == "MachinePart"
		and current.delivery.status == "Collect"
	then
		selected = deliveryRecordsByKey[deliveryKey(player.UserId, "MachinePart")]
	end
	if current and current.delivery and current.delivery.kind == "Boombox"
		and current.delivery.status == "Collect"
	then
		selectedBoombox = deliveryRecordsByKey[deliveryKey(player.UserId, "Boombox")]
	end
	if current and current.delivery and current.delivery.kind == "TaskUpgrade"
		and current.delivery.status == "Collect"
	then
		selectedTaskUpgrade = deliveryRecordsByKey[deliveryKey(player.UserId, "TaskUpgrade")]
	end
	if current and current.delivery and current.delivery.kind == "ChemistrySetup"
		and current.delivery.status == "Collect"
	then
		selectedChemistry = deliveryRecordsByKey[deliveryKey(player.UserId, "ChemistrySetup")]
	end
	local handle = selected and selected.status == "World" and selected.tool and selected.tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		target.CFrame = handle.CFrame
	else
		target.CFrame = dropZone.CFrame * CFrame.new(0, 0.2, 0)
	end
	local boomboxHandle = selectedBoombox and selectedBoombox.status == "World"
		and selectedBoombox.tool and selectedBoombox.tool:FindFirstChild("Handle")
	if boomboxHandle and boomboxHandle:IsA("BasePart") then
		boomboxTarget.CFrame = boomboxHandle.CFrame
	else
		boomboxTarget.CFrame = dropZone.CFrame * CFrame.new(0, 0.2, 0)
	end
	local taskUpgradeHandle = selectedTaskUpgrade and selectedTaskUpgrade.status == "World"
		and selectedTaskUpgrade.tool and selectedTaskUpgrade.tool:FindFirstChild("Handle")
	if taskUpgradeHandle and taskUpgradeHandle:IsA("BasePart") then
		taskUpgradeTarget.CFrame = taskUpgradeHandle.CFrame
	else
		taskUpgradeTarget.CFrame = dropZone.CFrame * CFrame.new(0, 0.2, 0)
	end
	local chemistryHandle = selectedChemistry and selectedChemistry.status == "World"
		and selectedChemistry.tool and selectedChemistry.tool:FindFirstChild("Handle")
	if chemistryHandle and chemistryHandle:IsA("BasePart") then
		chemistryTarget.CFrame = chemistryHandle.CFrame
	elseif current and current.delivery and current.delivery.kind == "ChemistrySetup"
		and current.delivery.status == "Install"
	then
		-- The drop point sits on the open/front half of the bay. The equipment
		-- itself assembles behind it, so no cabinet or reactor can solidify around
		-- the player who carried the case downstairs.
		chemistryTarget.CFrame = chemistryPad.CFrame * CFrame.new(0, 2.1, -4.55)
	else
		chemistryTarget.CFrame = dropZone.CFrame * CFrame.new(0, 0.2, 0)
	end
end

local function requestIsStillValid(player, request)
	local current = snapshot(player)
	if not current then
		return false
	end
	if request.kind == "Beer" then
		return current.task ~= nil
			and current.task.id == "GeorgeBeer"
			and current.task.step == "WaitingDelivery"
	elseif request.kind == "MachinePart" then
		return current.delivery ~= nil
			and current.delivery.kind == "MachinePart"
			and tonumber(current.delivery.stage) == tonumber(request.stage)
			and (current.delivery.status == "WaitingDelivery"
				or current.delivery.status == "Collect"
				or current.delivery.status == "Install")
	elseif request.kind == "Boombox" then
		return current.delivery ~= nil
			and current.delivery.kind == "Boombox"
			and (current.delivery.status == "WaitingDelivery"
				or current.delivery.status == "Collect"
				or current.delivery.status == "Setup"
				or current.delivery.status == "Install")
	elseif request.kind == "TaskUpgrade" then
		return current.delivery ~= nil
			and current.delivery.kind == "TaskUpgrade"
			and current.delivery.upgradeId == request.upgradeId
			and (current.delivery.status == "WaitingDelivery"
				or current.delivery.status == "Collect"
				or current.delivery.status == "Install")
	elseif request.kind == "ChemistrySetup" then
		return current.delivery ~= nil
			and current.delivery.kind == "ChemistrySetup"
			and (current.delivery.status == "WaitingDelivery"
				or current.delivery.status == "Collect"
				or current.delivery.status == "Install")
	end
	return false
end

local function spawnDeliveryCrate(player, request)
	local kind = tostring(request.kind or "")
	local isPart = kind == "MachinePart"
	local isBoombox = kind == "Boombox"
	local isTaskUpgrade = kind == "TaskUpgrade"
	local isChemistrySetup = kind == "ChemistrySetup"
	local upgradeId = isTaskUpgrade and tostring(request.upgradeId or "") or ""
	local stage = tonumber(request.stage) or 0
	local key = deliveryKey(player.UserId, kind)
	local existing = deliveryRecordsByKey[key]
	if existing and existing.tool and existing.tool.Parent and not existing.consumed then
		return existing.tool
	elseif existing then
		clearDeliveryRecord(existing, true)
	end
	local displayName
	if isPart then
		local definition = Config.MachineStages[stage]
		displayName = definition and definition.name or "Time Machine Component"
	elseif isBoombox then
		displayName = "Living Room Boombox"
	elseif isTaskUpgrade then
		local definition = taskAutomationDefinitions[upgradeId]
		displayName = definition and definition.name or upgradeId
	elseif isChemistrySetup then
		displayName = Config.ChemistrySetup and Config.ChemistrySetup.Name or "Advanced Chemistry Setup"
	else
		displayName = "Lone Star Six-Pack"
	end
	deliverySerial += 1
	local deliveryId = string.format("%d_%s_%d_%d", player.UserId, kind, stage, deliverySerial)
	local crateSize = deliveryCrateSize(kind)
	local crateColor = if isPart
		then Color3.fromRGB(74, 102, 133)
		elseif isBoombox
			then Color3.fromRGB(54, 58, 62)
		elseif isTaskUpgrade
			then Color3.fromRGB(78, 105, 87)
		elseif isChemistrySetup
			then Color3.fromRGB(32, 54, 68)
			else Color3.fromRGB(139, 89, 48)
	local spawnOffset = typeof(request.reservedSpawnOffset) == "Vector3"
		and request.reservedSpawnOffset
		or nil
	local slotLane = type(request.reservedSlotLane) == "number"
		and request.reservedSlotLane
		or nil
	request.reservedSpawnOffset = nil
	request.reservedSlotLane = nil
	if not spawnOffset then
		spawnOffset, slotLane = allocateDeliverySpawnOffset(kind, crateSize)
	end
	if not spawnOffset then
		return nil
	end
	local tool = createCarryTool(
		if isTaskUpgrade
			then "Delivery_TaskUpgrade_" .. tostring(player.UserId)
			elseif isChemistrySetup
				then "Delivery_ChemistrySetup_" .. tostring(player.UserId)
				else "DeliveryCrate_" .. deliveryId,
		displayName,
		player.UserId,
		crateColor,
		crateSize,
		spawnOffset
	)
	tool:SetAttribute("DeliveryId", deliveryId)
	tool:SetAttribute("DeliveryKind", kind)
	tool:SetAttribute("MachineStage", stage)
	tool:SetAttribute("TaskUpgradeId", if isTaskUpgrade then upgradeId else nil)
	tool:SetAttribute("DeliverySlotLane", slotLane)
	tool:SetAttribute("DeliverySlotOffset", spawnOffset)
	local labelText = if isPart
		then "TIME MACHINE" .. string.char(10) .. string.upper(displayName)
		elseif isBoombox
			then "COOPER SOUND" .. string.char(10) .. "BOOMBOX"
		elseif isTaskUpgrade
			then "COOPER AUTOMATION" .. string.char(10) .. string.upper(displayName)
		elseif isChemistrySetup
			then "BUNKER RESEARCH" .. string.char(10) .. "CHEMISTRY LAB"
			else "LONE STAR" .. string.char(10) .. "BEER"
	local labelColor = if isPart
		then Color3.fromRGB(40, 84, 135)
		elseif isBoombox
			then Color3.fromRGB(118, 86, 164)
		elseif isTaskUpgrade
			then Color3.fromRGB(45, 132, 89)
		elseif isChemistrySetup
			then Color3.fromRGB(38, 136, 166)
			else Color3.fromRGB(143, 45, 38)
	local hasBeerVisual = kind == "Beer" and applyBeerSixPackVisual(tool)
	if not hasBeerVisual then
		addCrateLabel(tool.Handle, labelText, labelColor)
	end
	local record = {
		id = deliveryId,
		key = key,
		player = player,
		kind = kind,
		upgradeId = upgradeId,
		stage = stage,
		tool = tool,
		status = "World",
		consumed = false,
		recovering = false,
	}
	deliveryRecordsByKey[key] = record
	deliveryRecordsById[deliveryId] = record
	ensureCompatibilityTarget(player, kind)
	tool.Parent = deliveryWorld
	local spawnedEvent = if isPart
		then "MachineDeliverySpawned"
		elseif isBoombox
			then "BoomboxDeliverySpawned"
		elseif isTaskUpgrade
			then "TaskUpgradeDeliverySpawned"
		elseif isChemistrySetup
			then "ChemistryDeliverySpawned"
			else "BeerDeliverySpawned"
	local spawnedMetadata = if isTaskUpgrade
		then { upgradeId = upgradeId }
		else { stage = stage }
	report(spawnedEvent, player, spawnedMetadata)
	task.defer(refreshCompatibilityTarget, player)
	return tool
end

runDeliveryQueue = function()
	-- A queued buyer gets the next ownership handoff after the ordinary truck's
	-- current trip. Including buyerQueueRunning in this admission gate closes the
	-- short polling window where a new ordinary order could repeatedly reclaim the
	-- street before the already-waiting Los Pollos worker observes our release.
	-- The reserved ordinary turn is the reciprocal guarantee: after a buyer visit,
	-- exactly one paid delivery may run even if another buyer is already queued.
	local hasReservedOrdinaryTurn = ordinaryDeliveryTurnReserved and #deliveryQueue > 0
	if deliveryRunning or buyerRouteOccupied
		or ((buyerQueueRunning or #buyerQueue > 0) and not hasReservedOrdinaryTurn)
	then
		if not buyerRouteOccupied and runBuyerQueue then
			runBuyerQueue()
		end
		return
	end
	deliveryRunning = true
	ordinaryDeliveryTurnReserved = false
	task.spawn(function()
		local retryDelay = 0
		local activeEntry = nil
		local workerOk, workerFailure = xpcall(function()
			while #deliveryQueue > 0 and not buyerRouteOccupied do
				local entry = table.remove(deliveryQueue, 1)
				activeEntry = entry
				local player = entry.player
				local entryRequeued = false
				local spawnedCrate = nil
				deliveryInFlightKeys[entry.key] = true

				local itemOk, itemFailure = xpcall(function()
					if not player or player.Parent ~= Players or not requestIsStillValid(player, entry.request) then
						return
					end
					local reservedSpawnOffset, reservedSlotLane = allocateDeliverySpawnOffset(
						tostring(entry.request.kind or ""),
						deliveryCrateSize(tostring(entry.request.kind or ""))
					)
					if not reservedSpawnOffset then
						-- All 25 safe slots are occupied. Preserve the paid request but
						-- release this worker so an already-queued buyer can use the road.
						table.insert(deliveryQueue, entry)
						entryRequeued = true
						retryDelay = 1
						return
					end

					entry.request.reservedSpawnOffset = reservedSpawnOffset
					entry.request.reservedSlotLane = reservedSlotLane
					local start = CFrame.lookAt(truckSpawn.Position, truckApproach.Position)
					local approach = CFrame.lookAt(truckApproach.Position, truckStop.Position)
					local stop = CFrame.lookAt(
						truckStop.Position,
						truckStop.Position + (truckStop.Position - truckApproach.Position)
					)
					setTruckVisible(true)
					truck:PivotTo(start)
					animateTruck(start, approach, 4.6)
					animateTruck(approach, stop, 1.8)
					if player.Parent == Players then
						spawnedCrate = spawnDeliveryCrate(player, entry.request)
					end
					-- Stay parked long enough for the player to see and grab the crate.
					task.wait(spawnedCrate and 4.5 or 1.5)
					local parked = truck:GetPivot()
					local exitApproach = CFrame.lookAt(truckApproach.Position, truckExit.Position)
					local exitPose = CFrame.lookAt(
						truckExit.Position,
						truckExit.Position + (truckExit.Position - truckApproach.Position)
					)
					animateTruck(parked, exitApproach, 1.8)
					animateTruck(exitApproach, exitPose, 4.6)
					setTruckVisible(false)
					task.wait(0.8)
				end, debug.traceback)

				-- Per-item finalizer: reservations are transient, the singleton truck is
				-- always hidden, and the exact in-flight key is always released even if
				-- construction, animation, or departure raises unexpectedly.
				entry.request.reservedSpawnOffset = nil
				entry.request.reservedSlotLane = nil
				local hiddenOk, hiddenFailure = pcall(setTruckVisible, false)
				if not hiddenOk then
					warn("[CooperTaskWorld] Delivery truck cleanup failed: " .. tostring(hiddenFailure))
				end
				if not itemOk then
					-- A crate returned from spawnDeliveryCrate is already authoritative and
					-- remains collectible. Only an unregistered transient is disposable.
					if spawnedCrate and spawnedCrate.Parent and not recordForTool(spawnedCrate) then
						spawnedCrate:Destroy()
					end
					warn("[CooperTaskWorld] Delivery queue item failed safely: " .. tostring(itemFailure))
					retryDelay = math.max(retryDelay, 0.5)
				end

				-- If a carried crate was lost while this same truck was driving away, or
				-- this attempt failed before publishing one, retain the paid request.
				if not entryRequeued and player and player.Parent == Players
					and requestIsStillValid(player, entry.request)
					and deliveryRecordsByKey[entry.key] == nil
				then
					table.insert(deliveryQueue, entry)
					entryRequeued = true
					retryDelay = math.max(retryDelay, 0.5)
				end

				-- Complete at most the current ordinary trip once a buyer worker is
				-- waiting. Releasing here gives it a deterministic next turn.
				deliveryInFlightKeys[entry.key] = nil
				activeEntry = nil
				if buyerQueueRunning or #buyerQueue > 0 or entryRequeued then
					break
				end
			end
		end, debug.traceback)

		-- Worker finalizer covers even failures in the loop/finalizer itself.
		deliveryRunning = false
		if activeEntry then
			activeEntry.request.reservedSpawnOffset = nil
			activeEntry.request.reservedSlotLane = nil
			deliveryInFlightKeys[activeEntry.key] = nil
			local player = activeEntry.player
			local alreadyQueued = false
			for _, queuedEntry in ipairs(deliveryQueue) do
				if queuedEntry == activeEntry then
					alreadyQueued = true
					break
				end
			end
			if not alreadyQueued and player and player.Parent == Players
				and requestIsStillValid(player, activeEntry.request)
				and deliveryRecordsByKey[activeEntry.key] == nil
			then
				table.insert(deliveryQueue, activeEntry)
				retryDelay = math.max(retryDelay, 0.5)
			end
		end
		local finalHideOk, finalHideFailure = pcall(setTruckVisible, false)
		if not finalHideOk then
			warn("[CooperTaskWorld] Delivery worker truck cleanup failed: " .. tostring(finalHideFailure))
		end
		if not workerOk then
			warn("[CooperTaskWorld] Delivery queue recovered safely: " .. tostring(workerFailure))
		end

		if buyerQueueRunning or #buyerQueue > 0 then
			runBuyerQueue()
		elseif #deliveryQueue > 0 then
			task.delay(math.max(0.05, retryDelay), function()
				runDeliveryQueue()
			end)
		end
	end)
end

enqueueDelivery = function(player, request)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players
		or type(request) ~= "table"
	then
		return false
	end
	local kind = tostring(request.kind or "")
	local stage = math.floor(tonumber(request.stage) or 0)
	local upgradeId = tostring(request.upgradeId or "")
	if kind ~= "Beer" and kind ~= "MachinePart" and kind ~= "Boombox"
		and kind ~= "TaskUpgrade" and kind ~= "ChemistrySetup"
	then
		return false
	elseif kind == "Beer" or kind == "Boombox" or kind == "TaskUpgrade" or kind == "ChemistrySetup" then
		stage = 0
		if kind == "TaskUpgrade" and taskAutomationDefinitions[upgradeId] == nil then
			return false
		end
	elseif stage < 1 or stage > #Config.MachineStages then
		return false
	end
	local sanitized = {
		kind = kind,
		stage = stage,
		upgradeId = if kind == "TaskUpgrade" then upgradeId else nil,
	}
	if not requestIsStillValid(player, sanitized) then
		return false
	end
	local key = deliveryKey(player.UserId, kind)
	if deliveryInFlightKeys[key] then
		return false
	end
	local existing = deliveryRecordsByKey[key]
	if existing and existing.tool and existing.tool.Parent and not existing.consumed then
		return false
	end
	for _, queued in ipairs(deliveryQueue) do
		if queued.key == key then
			return false
		end
	end
	table.insert(deliveryQueue, {
		player = player,
		key = key,
		request = sanitized,
	})
	runDeliveryQueue()
	return true
end

requestDelivery.Event:Connect(function(player, request)
	enqueueDelivery(player, request)
end)

local function scheduleMachineRecovery(player, removedCharacter)
	local key = deliveryKey(player.UserId, "MachinePart")
	local record = deliveryRecordsByKey[key]
	if not record or record.status ~= "Carried" or record.consumed or record.recovering then
		return
	end
	local current = snapshot(player)
	if not current or not current.delivery
		or current.delivery.kind ~= "MachinePart"
		or current.delivery.status ~= "Install"
		or tonumber(current.delivery.stage) ~= record.stage
	then
		return
	end
	record.recovering = true
	local stage = record.stage
	clearDeliveryRecord(record, true)
	pendingMachineRecoveries[player] = {
		stage = stage,
		removedCharacter = removedCharacter,
		attempts = 0,
	}
	task.defer(refreshCompatibilityTarget, player)
end

local function scheduleBoomboxRecovery(player, removedCharacter)
	local key = deliveryKey(player.UserId, "Boombox")
	local record = deliveryRecordsByKey[key]
	if not record or record.status ~= "Carried" or record.consumed or record.recovering then
		return
	end
	local current = snapshot(player)
	if not current or not current.delivery
		or current.delivery.kind ~= "Boombox"
		or (current.delivery.status ~= "Setup" and current.delivery.status ~= "Install")
	then
		return
	end
	record.recovering = true
	clearDeliveryRecord(record, true)
	pendingBoomboxRecoveries[player] = {
		removedCharacter = removedCharacter,
		attempts = 0,
	}
	report("BoomboxCarryLost", player)
	task.defer(refreshCompatibilityTarget, player)
end

local function recoverTaskUpgradeCarry(player)
	local key = deliveryKey(player.UserId, "TaskUpgrade")
	local record = deliveryRecordsByKey[key]
	if not record or record.status ~= "Carried" or record.consumed then
		return
	end
	local current = snapshot(player)
	if not current or not current.delivery
		or current.delivery.kind ~= "TaskUpgrade"
		or current.delivery.status ~= "Install"
		or current.delivery.upgradeId ~= record.upgradeId
	then
		return
	end
	local upgradeId = record.upgradeId
	clearDeliveryRecord(record, true)
	report("TaskUpgradeCarryLost", player, { upgradeId = upgradeId })
	task.defer(refreshCompatibilityTarget, player)
end

local function recoverChemistryCarry(player)
	local key = deliveryKey(player.UserId, "ChemistrySetup")
	local record = deliveryRecordsByKey[key]
	if not record or record.status ~= "Carried" or record.consumed then
		return
	end
	local current = snapshot(player)
	if not current or not current.delivery
		or current.delivery.kind ~= "ChemistrySetup"
		or current.delivery.status ~= "Install"
	then
		return
	end
	clearDeliveryRecord(record, true)
	report("ChemistryCarryLost", player)
	task.defer(refreshCompatibilityTarget, player)
end

-- Ordinary task carry items disappear with a removed character too. Roll the
-- authoritative task back to a recoverable step instead of leaving the player
-- asked to deliver a Tool that no longer exists.
local function recoverFamilyTaskCarry(player, removedCharacter)
	local current = snapshot(player)
	local taskData = current and current.task
	if not taskData then
		return
	end
	if taskData.id == "GeorgeBeer" and taskData.step == "Deliver" then
		local record = deliveryRecordsByKey[deliveryKey(player.UserId, "Beer")]
		if record then
			clearDeliveryRecord(record, true)
		end
		report("BeerCarryLost", player)
		task.defer(refreshCompatibilityTarget, player)
	elseif taskData.id == "MaryTrash" and taskData.step == "Deliver" then
		for _, container in ipairs({ removedCharacter, player:FindFirstChildOfClass("Backpack") }) do
			if container then
				for _, child in ipairs(container:GetChildren()) do
					if child:IsA("Tool") and child:GetAttribute("FamilyTrashBag") == true then
						child:Destroy()
					end
				end
			end
		end
		report("TrashCarryLost", player)
	elseif taskData.id == "MissyPlush" and taskData.step == "Return" then
		for _, container in ipairs({ removedCharacter, player:FindFirstChildOfClass("Backpack") }) do
			if container then
				for _, child in ipairs(container:GetChildren()) do
					if child:IsA("Tool") and child:GetAttribute("FamilyMissyPlush") == true then
						child:Destroy()
					end
				end
			end
		end
		report("MissyPlushCarryLost", player)
	end
end

local function tryMachineRecovery(player, character)
	local pending = pendingMachineRecoveries[player]
	if not pending or player.Parent ~= Players then
		return
	end
	if pending.removedCharacter and player.Character == pending.removedCharacter then
		return
	end
	if character and player.Character ~= character then
		return
	end
	local current = snapshot(player)
	if not current then
		pending.attempts = (pending.attempts or 0) + 1
		if pending.attempts <= 15 then
			task.delay(2, function()
				tryMachineRecovery(player, player.Character)
			end)
		end
		return
	end
	if not current.delivery or current.delivery.kind ~= "MachinePart"
		or tonumber(current.delivery.stage) ~= pending.stage
	then
		pendingMachineRecoveries[player] = nil
		return
	end
	local queued = enqueueDelivery(player, {
		kind = "MachinePart",
		stage = pending.stage,
	})
	if queued
		or deliveryRecordsByKey[deliveryKey(player.UserId, "MachinePart")] ~= nil
	then
		pendingMachineRecoveries[player] = nil
	else
		pending.attempts = (pending.attempts or 0) + 1
		if pending.attempts <= 15 then
			task.delay(2, function()
				tryMachineRecovery(player, player.Character)
			end)
		end
	end
end

local function tryBoomboxRecovery(player, character)
	local pending = pendingBoomboxRecoveries[player]
	if not pending or player.Parent ~= Players then
		return
	end
	if pending.removedCharacter and player.Character == pending.removedCharacter then
		return
	end
	if character and player.Character ~= character then
		return
	end
	local current = snapshot(player)
	if not current then
		pending.attempts = (pending.attempts or 0) + 1
		if pending.attempts <= 15 then
			task.delay(2, function()
				tryBoomboxRecovery(player, player.Character)
			end)
		end
		return
	end
	if not current.delivery or current.delivery.kind ~= "Boombox" then
		pendingBoomboxRecoveries[player] = nil
		return
	end
	local queued = enqueueDelivery(player, {
		kind = "Boombox",
		stage = 0,
	})
	if queued or deliveryRecordsByKey[deliveryKey(player.UserId, "Boombox")] ~= nil then
		pendingBoomboxRecoveries[player] = nil
	else
		pending.attempts = (pending.attempts or 0) + 1
		if pending.attempts <= 15 then
			task.delay(2, function()
				tryBoomboxRecovery(player, player.Character)
			end)
		end
	end
end

local function watchPlayer(player)
	if playerConnections[player] then
		return
	end
	playerConnections[player] = {
		player.CharacterRemoving:Connect(function(character)
			clearCarryPenalty(player)
			scheduleMachineRecovery(player, character)
			scheduleBoomboxRecovery(player, character)
			recoverTaskUpgradeCarry(player)
			recoverChemistryCarry(player)
			recoverFamilyTaskCarry(player, character)
		end),
		player.CharacterAdded:Connect(function(character)
			task.delay(1.25, function()
				tryMachineRecovery(player, character)
				tryBoomboxRecovery(player, character)
			end)
		end),
		player:GetAttributeChangedSignal("CooperBoomboxPlaced"):Connect(function()
			refreshBoomboxVisibility()
		end),
	}
	task.defer(refreshBoomboxVisibility)
end

local function giveTool(player, tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	local handle = tool and tool:FindFirstChild("Handle")
	if not humanoid or not backpack or not handle or not handle:IsA("BasePart") then
		return false
	end
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= handle then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		elseif descendant:IsA("SurfaceGui") and descendant.Name == "CrateLabel" and descendant.Parent == handle then
			descendant:Destroy()
		end
	end
	local prompt = handle:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	attachCarryPenalty(player, tool, tostring(tool:GetAttribute("DeliveryKind") or "Delivery"))
	return true
end

local function heldTool(player, predicate)
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and predicate(child) then
			return child
		end
	end
	return nil
end

local function tryInstallTaskUpgrade(player, expectedUpgradeId)
	if not player or player.Parent ~= Players then
		return false
	end
	local record = deliveryRecordsByKey[deliveryKey(player.UserId, "TaskUpgrade")]
	local tool = record and record.tool or nil
	local upgradeId = record and record.upgradeId or ""
	local anchor = taskAutomationAnchors[upgradeId]
	local roomFloorName = if upgradeId == "BeerBot" or upgradeId == "ToyFinder" or upgradeId == "HackerBot"
		then "TwinsGreenGrayCarpet"
		else "KitchenPatternLinoleum"
	local roomFloor = environment:FindFirstChild(roomFloorName, true)
	local playerRoot = rootPart(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local validParent = tool and (tool.Parent == player.Character or tool.Parent == backpack)
	local roomLocal = roomFloor and roomFloor:IsA("BasePart") and playerRoot
		and roomFloor.CFrame:PointToObjectSpace(playerRoot.Position)
		or nil
	local insideRoom = roomLocal ~= nil
		and math.abs(roomLocal.X) <= roomFloor.Size.X * 0.5 + 0.45
		and math.abs(roomLocal.Z) <= roomFloor.Size.Z * 0.5 + 0.45
		and math.abs(roomLocal.Y) <= 6
	if not record or record.kind ~= "TaskUpgrade" or record.status ~= "Carried"
		or record.consumed or upgradeId == "" or not anchor
		or (expectedUpgradeId and expectedUpgradeId ~= upgradeId)
		or not validParent or tool:GetAttribute("OwnerUserId") ~= player.UserId
		or tool:GetAttribute("TaskUpgradeId") ~= upgradeId
		or not near(player, anchor, 5.5)
		or not insideRoom
	then
		return false
	end
	local current = snapshot(player)
	if not current or not current.delivery
		or current.delivery.kind ~= "TaskUpgrade"
		or current.delivery.status ~= "Install"
		or current.delivery.upgradeId ~= upgradeId
	then
		return false
	end
	-- The BindableEvent handler runs synchronously. Confirm its catalog result
	-- before consuming the paid crate, so API/profile failure cannot lose it.
	local installed = invokeFamily("ReportAction", player, "TaskUpgradeInstalled", { upgradeId = upgradeId })
	if installed ~= true or not snapshotOwnsAutomation(snapshot(player), upgradeId) then
		return false
	end
	clearCarryPenalty(player, tool)
	clearDeliveryRecord(record, false)
	if tool.Parent then
		tool:Destroy()
	end
	setAutomationRobotVisible(upgradeId, true)
	task.defer(refreshCompatibilityTarget, player)
	return true
end

local function refreshTaskUpgradeInstallDestinations()
	local activeByUpgrade = {}
	for _, record in pairs(deliveryRecordsByKey) do
		if record.kind == "TaskUpgrade" and record.status == "Carried"
			and not record.consumed and record.player and record.player.Parent == Players
		then
			local current = snapshot(record.player)
			if current and current.delivery and current.delivery.kind == "TaskUpgrade"
				and current.delivery.status == "Install"
				and current.delivery.upgradeId == record.upgradeId
			then
				activeByUpgrade[record.upgradeId] = true
			end
		end
	end
	for upgradeId, anchor in pairs(taskAutomationAnchors) do
		local pad = taskVisuals:FindFirstChild(upgradeId .. "InstallPad")
		if pad and pad:IsA("BasePart") then
			pad.Transparency = activeByUpgrade[upgradeId]
				and math.clamp(finiteNumber(pad:GetAttribute("VisibleTransparency"), 0.68), 0, 1)
				or 1
			pad.CanCollide = false
			pad.CanQuery = false
		end
		local prompt = anchor:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			-- Owner-safe auto-install below is the interaction. A shared prompt
			-- cannot be made visible to only the crate owner on the server.
			prompt.Enabled = false
		end
	end
end

local taskUpgradeInstallElapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	taskUpgradeInstallElapsed += deltaTime
	if taskUpgradeInstallElapsed < 0.18 then
		return
	end
	taskUpgradeInstallElapsed = 0
	refreshTaskUpgradeInstallDestinations()
	for _, candidate in ipairs(Players:GetPlayers()) do
		tryInstallTaskUpgrade(candidate)
	end
end)

local function tryInstallChemistrySetup(player)
	if not player or player.Parent ~= Players
		or player:GetAttribute("CooperSecretBunkerUnlocked") ~= true
	then
		return false
	end
	local record = deliveryRecordsByKey[deliveryKey(player.UserId, "ChemistrySetup")]
	local tool = record and record.tool or nil
	local playerRoot = rootPart(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local validParent = tool and (tool.Parent == player.Character or tool.Parent == backpack)
	local padLocal = playerRoot and chemistryPad.CFrame:PointToObjectSpace(playerRoot.Position) or nil
	local insideSafeInstallZone = padLocal ~= nil
		and math.abs(padLocal.X) <= 3.7
		and padLocal.Z >= -6.7
		and padLocal.Z <= -2.75
		and padLocal.Y >= -1.5
		and padLocal.Y <= 8
	if not record or record.player ~= player or record.kind ~= "ChemistrySetup"
		or record.status ~= "Carried" or record.consumed
		or not validParent or tool:GetAttribute("OwnerUserId") ~= player.UserId
		or not near(player, chemistryInstallAnchor, 6.5)
		or not insideSafeInstallZone
	then
		return false
	end
	local current = snapshot(player)
	if not current or not current.delivery
		or current.delivery.kind ~= "ChemistrySetup"
		or current.delivery.status ~= "Install"
		or not current.chemistrySetup
		or current.chemistrySetup.purchased ~= true
		or current.chemistrySetup.placed == true
	then
		return false
	end
	-- Persist the entitlement transition before consuming the paid case. The
	-- bunker controller observes CooperChemistrySetupPlaced and performs the
	-- visible multi-stage assembly spectacle independently.
	local installed = invokeFamily("ReportAction", player, "ChemistrySetupPlaced", {})
	local refreshed = snapshot(player)
	if installed ~= true
		or not refreshed or not refreshed.chemistrySetup
		or refreshed.chemistrySetup.placed ~= true
	then
		return false
	end
	clearCarryPenalty(player, tool)
	clearDeliveryRecord(record, false)
	if tool.Parent then
		tool:Destroy()
	end
	task.defer(refreshCompatibilityTarget, player)
	return true
end

local chemistryInstallElapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	chemistryInstallElapsed += deltaTime
	if chemistryInstallElapsed < 0.18 then
		return
	end
	chemistryInstallElapsed = 0
	for _, candidate in ipairs(Players:GetPlayers()) do
		local chemistryRecord = deliveryRecordsByKey[deliveryKey(candidate.UserId, "ChemistrySetup")]
		if chemistryRecord and chemistryRecord.status == "Carried" and not chemistryRecord.consumed then
			local tool = chemistryRecord.tool
			local backpack = candidate:FindFirstChildOfClass("Backpack")
			if not tool or not tool.Parent
				or (tool.Parent ~= candidate.Character and tool.Parent ~= backpack)
			then
				recoverChemistryCarry(candidate)
			end
		end
		tryInstallChemistrySetup(candidate)
	end
end)

local function insideBoomboxAutoSetupArea(player)
	local playerRoot = rootPart(player)
	if not playerRoot then
		return false
	end
	local offset = playerRoot.Position - boomboxSetupAnchor.Position
	local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if horizontalDistance > BOOMBOX_AUTO_SETUP_RADIUS or math.abs(offset.Y) > 6 then
		return false
	end
	-- The end table sits near an exterior wall. Requiring the character to be
	-- over the formal living-room carpet prevents setup from firing through
	-- that wall while keeping the marked destination forgiving to enter.
	local carpetLocal = formalLivingCarpet.CFrame:PointToObjectSpace(playerRoot.Position)
	return math.abs(carpetLocal.X) <= formalLivingCarpet.Size.X * 0.5 + 0.5
		and math.abs(carpetLocal.Z) <= formalLivingCarpet.Size.Z * 0.5 + 0.5
end

local function tryPlaceBoombox(player, requireAutoSetupArea)
	if not player or player.Parent ~= Players or player:GetAttribute("CooperBoomboxPlaced") == true then
		return false
	end
	if requireAutoSetupArea and not insideBoomboxAutoSetupArea(player) then
		return false
	end
	local record = deliveryRecordsByKey[deliveryKey(player.UserId, "Boombox")]
	local tool = record and record.tool or nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	local validParent = tool and (tool.Parent == player.Character or tool.Parent == backpack)
	if not record
		or record.player ~= player
		or record.kind ~= "Boombox"
		or record.status ~= "Carried"
		or record.consumed
		or not validParent
		or tool:GetAttribute("OwnerUserId") ~= player.UserId
	then
		return false
	end
	local current = snapshot(player)
	if not current or not current.delivery
		or current.delivery.kind ~= "Boombox"
		or (current.delivery.status ~= "Setup" and current.delivery.status ~= "Install")
	then
		return false
	end
	-- Confirm the persistent transition before consuming the physical crate so
	-- a transient profile/API failure cannot delete the player's purchase.
	local placed = invokeFamily("ReportAction", player, "BoomboxPlaced", {})
	if placed ~= true then
		return false
	end
	clearCarryPenalty(player, tool)
	clearDeliveryRecord(record, false)
	if tool.Parent then
		tool:Destroy()
	end
	task.defer(refreshCompatibilityTarget, player)
	return true
end

local autoSetupElapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	autoSetupElapsed += deltaTime
	if autoSetupElapsed < 0.18 then
		return
	end
	autoSetupElapsed = 0
	for _, candidate in ipairs(Players:GetPlayers()) do
		tryPlaceBoombox(candidate, true)
	end
end)

local function createTrashBag(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("FamilyTrashBag") == true then
				child:Destroy()
			end
		end
	end
	local tool = Instance.new("Tool")
	tool.Name = "Kitchen Garbage Bag"
	tool.ToolTip = "Take this bag to the outdoor garbage can beside the garage"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("OwnerUserId", player.UserId)
	tool:SetAttribute("FamilyTrashBag", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(2.1, 2.5, 2.1)
	handle.Color = Color3.fromRGB(34, 36, 33)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
		attachCarryPenalty(player, tool, "Trash")
	end
	return tool
end

local function actionForPrompt(prompt)
	local action = prompt:GetAttribute("FamilyTaskAction")
	return type(action) == "string" and action or nil
end

-- A four-second HoldDuration on the client is useful feedback, but it is not
-- security: exploit clients can locally shorten ProximityPrompt holds. Record
-- the sink hold on the server and require the authored duration before paying.
local dishHoldSessions = {}
local DISH_HOLD_TOLERANCE = 0.15

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
	if not prompt:IsDescendantOf(world) or actionForPrompt(prompt) ~= "Dishes" then
		return
	end
	if not activeTask(player, "MaryDishes")
		or not near(player, prompt.Parent, prompt.MaxActivationDistance + 3)
	then
		return
	end
	dishHoldSessions[player] = {
		prompt = prompt,
		startedAt = serverNow(),
	}
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, player)
	local session = dishHoldSessions[player]
	if not session or session.prompt ~= prompt then
		return
	end
	local elapsed = serverNow() - session.startedAt
	if elapsed + DISH_HOLD_TOLERANCE < prompt.HoldDuration then
		dishHoldSessions[player] = nil
		return
	end
	-- Roblox may emit HoldEnded immediately before PromptTriggered. Retain a
	-- completed hold briefly so the succeeding trigger can consume it.
	session.endedAt = serverNow()
	task.delay(0.75, function()
		if dishHoldSessions[player] == session then
			dishHoldSessions[player] = nil
		end
	end)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if not prompt:IsDescendantOf(world) then
		return
	end
	local action = actionForPrompt(prompt)
	if not action or not passCooldown(player, action, 0.45) or not near(player, prompt.Parent, prompt.MaxActivationDistance + 3) then
		return
	end
	if action == "Dishes" then
		local session = dishHoldSessions[player]
		local heldLongEnough = session ~= nil
			and session.prompt == prompt
			and serverNow() - session.startedAt + DISH_HOLD_TOLERANCE >= prompt.HoldDuration
		dishHoldSessions[player] = nil
		if heldLongEnough and activeTask(player, "MaryDishes") then
			report("DishesCompleted", player)
		end
	elseif action == "TrashPickup" then
		if activeTask(player, "MaryTrash", "Pickup") then
			createTrashBag(player)
			report("TrashPicked", player)
		end
	elseif action == "TrashDrop" then
		local bag = heldTool(player, function(tool)
			return tool:GetAttribute("FamilyTrashBag") == true and tool:GetAttribute("OwnerUserId") == player.UserId
		end)
		if bag and activeTask(player, "MaryTrash", "Deliver") then
			bag:Destroy()
			report("TrashDelivered", player)
		end
	elseif action == "MissyReturn" then
		local taskData = activeTask(player, "MissyPlush", "Return")
		local plush = heldTool(player, function(tool)
			return tool:GetAttribute("FamilyMissyPlush") == true
				and tool:GetAttribute("OwnerUserId") == player.UserId
				and taskData ~= nil
				and tool:GetAttribute("PlushKind") == taskData.plushKind
		end)
		if plush and taskData then
			local homeName = taskData.plushKind == "Rabbit"
				and "MissyDetailedRabbit"
				or "MissyDetailedTeddyBear"
			local homeToy = environment:FindFirstChild(homeName, true)
			local homeCFrame = missyToyHomeCFrame(homeToy)
			local homeHandle = homeToy
				and (homeToy.PrimaryPart or homeToy:FindFirstChild("InteractionHandle", true))
			if homeToy and homeToy:IsA("Model")
				and typeof(homeCFrame) == "CFrame"
				and homeHandle and homeHandle:IsA("BasePart")
			then
				homeHandle.Anchored = true
				homeHandle.AssemblyLinearVelocity = Vector3.zero
				homeHandle.AssemblyAngularVelocity = Vector3.zero
				homeToy:PivotTo(homeCFrame)
				plush:Destroy()
				report("MissyPlushReturned", player, { plushKind = taskData.plushKind })
			end
		end
	elseif action == "DeliveryPickup" then
		local tool = prompt:FindFirstAncestorWhichIsA("Tool")
		if not tool or tool.Parent ~= deliveryWorld or tool:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		local deliveryRecord = recordForTool(tool)
		if not deliveryRecord or deliveryRecord.player ~= player or deliveryRecord.status ~= "World" then
			return
		end
		local kind = tool:GetAttribute("DeliveryKind")
		local current = snapshot(player)
		if kind == "Beer" then
			if deliveryRecord.kind ~= "Beer"
				or not current or not current.task or current.task.id ~= "GeorgeBeer" or current.task.step ~= "Collect"
			then
				return
			end
		elseif kind == "MachinePart" then
			if deliveryRecord.kind ~= "MachinePart"
				or not current or not current.delivery or current.delivery.status ~= "Collect"
				or current.delivery.kind ~= "MachinePart"
				or tonumber(current.delivery.stage) ~= deliveryRecord.stage
			then
				return
			end
		elseif kind == "Boombox" then
			if deliveryRecord.kind ~= "Boombox"
				or not current or not current.delivery or current.delivery.kind ~= "Boombox"
				or current.delivery.status ~= "Collect"
			then
				return
			end
		elseif kind == "TaskUpgrade" then
			local upgradeId = tostring(tool:GetAttribute("TaskUpgradeId") or "")
			if deliveryRecord.kind ~= "TaskUpgrade"
				or deliveryRecord.upgradeId ~= upgradeId
				or not current or not current.delivery
				or current.delivery.kind ~= "TaskUpgrade"
				or current.delivery.status ~= "Collect"
				or current.delivery.upgradeId ~= upgradeId
			then
				return
			end
		elseif kind == "ChemistrySetup" then
			if deliveryRecord.kind ~= "ChemistrySetup"
				or not current or not current.delivery
				or current.delivery.kind ~= "ChemistrySetup"
				or current.delivery.status ~= "Collect"
				or not current.chemistrySetup
				or current.chemistrySetup.purchased ~= true
				or current.chemistrySetup.placed == true
			then
				return
			end
		else
			return
		end
		if giveTool(player, tool) then
			deliveryRecord.status = "Carried"
			local pickedEvent = if kind == "Beer"
				then "BeerCratePicked"
				elseif kind == "Boombox"
					then "BoomboxCratePicked"
				elseif kind == "TaskUpgrade"
					then "TaskUpgradeCratePicked"
				elseif kind == "ChemistrySetup"
					then "ChemistryCratePicked"
					else "MachineCratePicked"
			local pickedMetadata = if kind == "TaskUpgrade"
				then { upgradeId = deliveryRecord.upgradeId }
				else { stage = deliveryRecord.stage }
			report(pickedEvent, player, pickedMetadata)
			task.defer(refreshCompatibilityTarget, player)
		end
	elseif action == "BeerDrop" then
		local tool = heldTool(player, function(candidate)
			local record = recordForTool(candidate)
			return record ~= nil and record.status == "Carried" and record.kind == "Beer"
				and candidate:GetAttribute("OwnerUserId") == player.UserId
		end)
		if tool and activeTask(player, "GeorgeBeer", "Deliver") then
			local fridge = environment:FindFirstChild("WhiteHotpointRefrigerator", true)
			if fridge then
				local capacity = 12
				local count = math.max(0, math.floor(tonumber(fridge:GetAttribute("CooperBeerCount")) or 0))
				fridge:SetAttribute("CooperBeerCapacity", capacity)
					fridge:SetAttribute("CooperBeerCount", math.min(capacity, count + 6))
			end
			clearDeliveryRecord(recordForTool(tool), false)
			tool:Destroy()
			report("BeerDelivered", player)
			task.defer(refreshCompatibilityTarget, player)
		end
	elseif action == "MachineInstall" then
		local tool = heldTool(player, function(candidate)
			local record = recordForTool(candidate)
			return record ~= nil and record.status == "Carried" and record.kind == "MachinePart"
				and candidate:GetAttribute("OwnerUserId") == player.UserId
		end)
		local current = snapshot(player)
		if tool and current and current.delivery and current.delivery.status == "Install" then
			local deliveryRecord = recordForTool(tool)
			local stage = deliveryRecord and deliveryRecord.stage or 0
			if deliveryRecord and tonumber(current.delivery.stage) == stage then
				-- A component is a paid, durable purchase. Commit the profile stage
				-- synchronously before consuming its physical crate, matching the
				-- boombox, robot, chemistry, and candy delivery safeguards above. If
				-- the family API is temporarily unavailable or rejects stale state,
				-- the owner keeps the crate and can try the installation again.
				local installed = invokeFamily(
					"ReportAction",
					player,
					"MachinePartInstalled",
					{ stage = stage }
				)
				local refreshed = snapshot(player)
				if installed ~= true
					or not refreshed
					or tonumber(refreshed.machineStage) ~= stage
				then
					return
				end
				clearCarryPenalty(player, tool)
				clearDeliveryRecord(deliveryRecord, false)
				if tool.Parent then
					tool:Destroy()
				end
				task.defer(refreshCompatibilityTarget, player)
			end
		end
	elseif action == "BoomboxSetup" then
		-- Manual prompt remains as an accessibility fallback; normal setup is
		-- automatic as soon as the owner enters the purple marked area.
		tryPlaceBoombox(player, false)
	elseif action == "BoomboxPower" then
		startBoomboxPlayback(player)
	elseif action == "TaskUpgradeInstall" then
		local upgradeId = tostring(prompt:GetAttribute("UpgradeId") or "")
		tryInstallTaskUpgrade(player, upgradeId)
	end
end)

Players.PlayerAdded:Connect(watchPlayer)

Players.PlayerRemoving:Connect(function(player)
	if activeBoomboxSession and activeBoomboxSession.player == player then
		finishBoomboxPlayback(activeBoomboxSession, "PlayerLeft", true)
	end
	clearCarryPenalty(player)
	for upgradeId, token in pairs(activeTaskAutomation) do
		if token.player == player then
			token.cancelled = true
			local robot = taskAutomationRobots[upgradeId]
			if robot then
				robot:SetAttribute("AutomationCancelling", true)
			end
		end
	end
	dishHoldSessions[player] = nil
	promptCooldowns[player] = nil
	pendingMachineRecoveries[player] = nil
	pendingBoomboxRecoveries[player] = nil
	autoplayRetryAt[player] = nil
	local target = compatibilityTargets[player]
	if target then
		target:Destroy()
		compatibilityTargets[player] = nil
	end
	local boomboxTarget = boomboxCompatibilityTargets[player]
	if boomboxTarget then
		boomboxTarget:Destroy()
		boomboxCompatibilityTargets[player] = nil
	end
	local taskUpgradeTarget = taskUpgradeCompatibilityTargets[player]
	if taskUpgradeTarget then
		taskUpgradeTarget:Destroy()
		taskUpgradeCompatibilityTargets[player] = nil
	end
	local chemistryTarget = chemistryCompatibilityTargets[player]
	if chemistryTarget then
		chemistryTarget:Destroy()
		chemistryCompatibilityTargets[player] = nil
	end
	local ownedRecords = {}
	for _, record in pairs(deliveryRecordsByKey) do
		if record.player == player then
			table.insert(ownedRecords, record)
		end
	end
	for _, record in ipairs(ownedRecords) do
		clearDeliveryRecord(record, true)
	end
	for index = #deliveryQueue, 1, -1 do
		if deliveryQueue[index].player == player then
			table.remove(deliveryQueue, index)
		end
	end
	for _, queue in pairs(taskAutomationQueues) do
		for index = #queue, 1, -1 do
			if queue[index].player == player then
				table.remove(queue, index)
			end
		end
	end
	local connections = playerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end
	task.defer(refreshBoomboxVisibility)
	task.defer(refreshAutomationVisibility)
end)

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

setTruckVisible(false)
refreshBoomboxVisibility()
refreshAutomationVisibility()
refreshTaskUpgradeInstallDestinations()
world:SetAttribute("ControllerReady", true)
world:SetAttribute("TaskAutomationControllerReady", true)
print("[CooperTaskWorld] Paid house and bunker deliveries, task robots, dancing boombox, and chemistry setup ready")
