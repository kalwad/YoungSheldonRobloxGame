--!nonstrict
-- Server-authoritative Time Machine construction, upgrades, reactor, campaign
-- finale, apartment transition, and fail-soft persistent progression.
-- Install as ServerScriptService.CooperProgression.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ROOT_TIMEOUT = 30
local progressionRoot = ReplicatedStorage:WaitForChild("CooperProgression", ROOT_TIMEOUT)
assert(progressionRoot and progressionRoot:IsA("Folder"), "ReplicatedStorage.CooperProgression was not installed")
local configModule = progressionRoot:WaitForChild("Config", ROOT_TIMEOUT)
assert(configModule and configModule:IsA("ModuleScript"), "CooperProgression.Config was not installed")
local Config = require(configModule)

local state = progressionRoot:WaitForChild(Config.StateName, ROOT_TIMEOUT)
local remotes = progressionRoot:WaitForChild(Config.RemotesName, ROOT_TIMEOUT)
assert(state and state:IsA("Folder"), "CooperProgression.State must be a Folder")
assert(remotes and remotes:IsA("Folder"), "CooperProgression.Remotes must be a Folder")
local snapshotEvent = remotes:WaitForChild("Snapshot", ROOT_TIMEOUT)
local feedbackEvent = remotes:WaitForChild("Feedback", ROOT_TIMEOUT)
local requestEvent = remotes:WaitForChild("Request", ROOT_TIMEOUT)
local finaleEvent = remotes:WaitForChild("Finale", ROOT_TIMEOUT)
assert(snapshotEvent:IsA("RemoteEvent"), "CooperProgression.Remotes.Snapshot must be a RemoteEvent")
assert(feedbackEvent:IsA("RemoteEvent"), "CooperProgression.Remotes.Feedback must be a RemoteEvent")
assert(requestEvent:IsA("RemoteEvent"), "CooperProgression.Remotes.Request must be a RemoteEvent")
assert(finaleEvent:IsA("RemoteEvent"), "CooperProgression.Remotes.Finale must be a RemoteEvent")

local campaignRoot = ReplicatedStorage:WaitForChild("CooperGame", ROOT_TIMEOUT)
assert(campaignRoot and campaignRoot:IsA("Folder"), "ReplicatedStorage.CooperGame was not installed")
local campaignConfigModule = campaignRoot:WaitForChild("Config", ROOT_TIMEOUT)
local campaignState = campaignRoot:WaitForChild("State", ROOT_TIMEOUT)
assert(campaignConfigModule:IsA("ModuleScript"), "CooperGame.Config was not installed")
assert(campaignState:IsA("Folder"), "CooperGame.State was not installed")
local CampaignConfig = require(campaignConfigModule)

assert(#Config.MachineStages == #CampaignConfig.MachineStages, "Progression and campaign stage counts differ")
for index, definition in ipairs(Config.MachineStages) do
	local campaignDefinition = CampaignConfig.MachineStages[index]
	assert(
		campaignDefinition
			and campaignDefinition.stage == definition.stage
			and campaignDefinition.name == definition.name
			and campaignDefinition.progress == definition.progress
			and campaignDefinition.cost == definition.cost,
		"Progression and campaign stage mismatch at " .. tostring(index)
	)
	assert(
		type(definition.cost) == "number" and definition.cost > 0 and definition.cost % 1 == 0,
		"Every Family machine component must have a positive integer allowance cost (stage " .. tostring(index) .. ")"
	)
end

local foundationEvents = ServerScriptService:WaitForChild(Config.FoundationEventsName, ROOT_TIMEOUT)
assert(foundationEvents and foundationEvents:IsA("Folder"), Config.FoundationEventsName .. " was not installed")
local foundationAPI = foundationEvents:WaitForChild("API", ROOT_TIMEOUT)
assert(foundationAPI:IsA("BindableFunction"), Config.FoundationEventsName .. ".API must be a BindableFunction")

local serverEvents = ServerScriptService:WaitForChild(Config.ServerEventsName, ROOT_TIMEOUT)
assert(serverEvents and serverEvents:IsA("Folder"), Config.ServerEventsName .. " was not installed")
local progressionAPI = serverEvents:WaitForChild("API", ROOT_TIMEOUT)
local registerCrisisEvent = serverEvents:WaitForChild("RegisterCrisis", ROOT_TIMEOUT)
local crisisRequestEvent = serverEvents:WaitForChild("CrisisRequest", ROOT_TIMEOUT)
local crisisResolvedEvent = serverEvents:WaitForChild("CrisisResolved", ROOT_TIMEOUT)
assert(progressionAPI:IsA("BindableFunction"), Config.ServerEventsName .. ".API must be a BindableFunction")
assert(registerCrisisEvent:IsA("BindableEvent"), Config.ServerEventsName .. ".RegisterCrisis must be a BindableEvent")
assert(crisisRequestEvent:IsA("BindableEvent"), Config.ServerEventsName .. ".CrisisRequest must be a BindableEvent")
assert(crisisResolvedEvent:IsA("BindableEvent"), Config.ServerEventsName .. ".CrisisResolved must be a BindableEvent")

local environment = workspace:WaitForChild("CooperHouseEnvironment", ROOT_TIMEOUT)
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment was not installed")
local garage = environment:WaitForChild("DetachedGarage", ROOT_TIMEOUT)
assert(garage and garage:IsA("Model"), "DetachedGarage was not installed")
local machine = garage:WaitForChild("CooperTimeMachine", ROOT_TIMEOUT)
assert(machine and machine:IsA("Model"), "DetachedGarage.CooperTimeMachine was not installed")
local stagesFolder = machine:WaitForChild("Stages", ROOT_TIMEOUT)
local controls = machine:WaitForChild("Controls", ROOT_TIMEOUT)
assert(stagesFolder:IsA("Folder"), "CooperTimeMachine.Stages must be a Folder")
assert(controls:IsA("Folder"), "CooperTimeMachine.Controls must be a Folder")

local futureApartment = workspace:WaitForChild("CooperFutureApartment", ROOT_TIMEOUT)
assert(futureApartment and futureApartment:IsA("Model"), "CooperFutureApartment was not installed")
local futureSpawn = futureApartment:WaitForChild("FutureSpawn", ROOT_TIMEOUT)
local returnPortal = futureApartment:WaitForChild("ReturnPortal", ROOT_TIMEOUT)
assert(futureSpawn:IsA("BasePart"), "CooperFutureApartment.FutureSpawn must be a BasePart")
assert(returnPortal:IsA("BasePart"), "CooperFutureApartment.ReturnPortal must be a BasePart")

local purchaseConsole = controls:WaitForChild("PurchaseConsole", ROOT_TIMEOUT)
local upgradeConsole = controls:WaitForChild("UpgradeConsole", ROOT_TIMEOUT)
local reactorConsole = controls:WaitForChild("ReactorConsole", ROOT_TIMEOUT)
local reactorModeConsole = controls:WaitForChild("ReactorModeConsole", ROOT_TIMEOUT)
local coolantConsole = controls:WaitForChild("CoolantConsole", ROOT_TIMEOUT)
local launchConsole = controls:WaitForChild("LaunchConsole", ROOT_TIMEOUT)
local returnSpawn = controls:WaitForChild("GarageReturnSpawn", ROOT_TIMEOUT)
for _, control in ipairs({
	purchaseConsole,
	upgradeConsole,
	reactorConsole,
	reactorModeConsole,
	coolantConsole,
	launchConsole,
	returnSpawn,
}) do
	assert(control:IsA("BasePart"), control:GetFullName() .. " must be a BasePart")
end

local purchasePrompt = purchaseConsole:WaitForChild("Prompt")
local upgradePrompt = upgradeConsole:WaitForChild("Prompt")
local reactorPrompt = reactorConsole:WaitForChild("Prompt")
local reactorModePrompt = reactorModeConsole:WaitForChild("Prompt")
local coolantPrompt = coolantConsole:WaitForChild("Prompt")
local launchPrompt = launchConsole:WaitForChild("Prompt")
local returnPrompt = returnPortal:WaitForChild("Prompt")
for _, prompt in ipairs({ purchasePrompt, upgradePrompt, reactorPrompt, reactorModePrompt, coolantPrompt, launchPrompt, returnPrompt }) do
	assert(prompt:IsA("ProximityPrompt"), prompt:GetFullName() .. " must be a ProximityPrompt")
end

local calibrationControls = {}
for _, id in ipairs(Config.FinalCalibration.Order) do
	local part = controls:WaitForChild("Calibration" .. id, ROOT_TIMEOUT)
	local prompt = part:WaitForChild("Prompt", ROOT_TIMEOUT)
	assert(part:IsA("BasePart") and prompt:IsA("ProximityPrompt"), "Calibration control " .. id .. " is invalid")
	calibrationControls[id] = { part = part, prompt = prompt }
end

local upgradeById = {}
for _, definition in ipairs(Config.Upgrades) do
	assert(upgradeById[definition.id] == nil, "Duplicate upgrade ID " .. tostring(definition.id))
	assert(#definition.costs == definition.maxLevel, definition.id .. " must have one cost per level")
	for level, cost in ipairs(definition.costs) do
		assert(
			type(cost.allowance) == "number" and cost.allowance > 0 and cost.allowance % 1 == 0,
			string.format("%s level %d must have a positive integer allowance cost", definition.id, level)
		)
	end
	upgradeById[definition.id] = definition
end

local roundedInteger

local function invokeFoundation(operation, ...)
	local arguments = table.pack(...)
	local packed = table.pack(pcall(function()
		return foundationAPI:Invoke(operation, table.unpack(arguments, 1, arguments.n))
	end))
	if not packed[1] then
		return false, nil, tostring(packed[2])
	end
	return true, table.unpack(packed, 2, packed.n)
end

local function foundationSnapshot(player)
	local callOK, result = invokeFoundation(Config.FoundationOperations.GetSnapshot, player)
	if callOK and type(result) == "table" then
		return result
	end
	return nil
end

local function foundationPlayerStage(player)
	local snapshot = foundationSnapshot(player)
	return roundedInteger(snapshot and snapshot.machineStage, 0, 0, #Config.MachineStages), snapshot
end

local function spendAllowance(player, amount, reason)
	amount = roundedInteger(amount, 0, 0, 2_000_000_000)
	if amount <= 0 then
		return false, "A positive allowance cost is required."
	end
	-- Prefer the explicit atomic API once the Family foundation exposes it.
	local callOK, spent, detail = invokeFoundation(
		Config.FoundationOperations.SpendAllowance,
		player,
		amount,
		reason
	)
	if callOK and spent ~= nil then
		return spent == true, detail
	end
	-- Current Family v2 compatibility: AdjustCurrency performs the same
	-- server-side balance check and rejects a negative resulting balance.
	callOK, spent, detail = invokeFoundation(Config.FoundationOperations.AdjustCurrency, player, -amount, reason)
	if not callOK or spent == nil then
		return false, "Family allowance service is unavailable."
	end
	return spent == true, detail
end

local function setFoundationMode(mode, reason)
	local callOK, accepted, publishedMode = invokeFoundation(Config.FoundationOperations.SetMode, mode, reason)
	return callOK and accepted == true, publishedMode
end

local function adjustFoundationStability(delta, reason)
	if campaignState:GetAttribute("SupportsStability") ~= true then
		return false, "Stability is not enabled by the Family foundation."
	end
	local callOK, result = invokeFoundation(Config.FoundationOperations.AdjustStability, delta, reason)
	return callOK and type(result) == "number", result
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function finiteNumber(value, default, minimum, maximum)
	local numeric = tonumber(value)
	if not numeric or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
		return default
	end
	return math.clamp(numeric, minimum, maximum)
end

roundedInteger = function(value, default, minimum, maximum)
	return math.floor(finiteNumber(value, default, minimum, maximum) + 0.5)
end

local function cloneUpgradeLevels(source)
	local result = {}
	if type(source) == "table" then
		for id, definition in pairs(upgradeById) do
			local level = roundedInteger(source[id], 0, 0, definition.maxLevel)
			if level > 0 then
				result[id] = level
			end
		end
	end
	return result
end

local function sanitizeProfile(raw)
	raw = type(raw) == "table" and raw or {}
	return {
		schemaVersion = Config.SchemaVersion,
		upgrades = cloneUpgradeLevels(raw.upgrades),
		victory = raw.victory == true,
		totalVictories = roundedInteger(raw.totalVictories, 0, 0, 1_000_000),
		updatedAt = roundedInteger(raw.updatedAt, 0, 0, 4_000_000_000),
	}
end

local profiles = {}
local requestNextAt = {}
local registeredCrises = {}
local pendingCrisisResults = {}
local teamEffects = {}
local machineStage = roundedInteger(campaignState:GetAttribute("MachineStage"), 0, 0, #Config.MachineStages)
local machineProgress = roundedInteger(campaignState:GetAttribute("MachineProgress"), 0, 0, 100)
local revision = 0
local shuttingDown = false
local reactorLocked = false

local reactor = {
	running = false,
	mode = "Safe",
	coolant = Config.Reactor.BaseCoolantCapacity,
	heat = 0,
	suspicion = 0,
	commissionCharge = 0,
	commissioned = false,
	chronoCoreCharge = 0,
	cooldownUntil = 0,
	operator = nil,
	operatorStage = 0,
}

local calibration = {
	completed = {},
	startedAt = 0,
}

local finale = {
	running = false,
	runId = "",
	phase = "Idle",
	phaseTitle = "",
	objective = "",
	deadline = 0,
	overloadIndex = 0,
	startedBy = nil,
}

local dataStoreEnabled = not RunService:IsStudio() or script:GetAttribute("EnableStudioDataStore") == true
local dataStore = dataStoreEnabled and DataStoreService:GetDataStore(Config.DataStoreName) or nil
local persistenceWarningSent = false

local function warnPersistenceOnce(message)
	if RunService:IsStudio() or persistenceWarningSent then
		return
	end
	persistenceWarningSent = true
	warn("[CooperProgression] Persistence is temporarily unavailable: " .. tostring(message))
end

local function playerRoot(player)
	if not player or player.Parent ~= Players then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function playerNear(player, part, extraDistance)
	local root = playerRoot(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= Config.InteractionDistance + (extraDistance or 0)
end

local function sendFeedback(player, kind, payload)
	payload = type(payload) == "table" and payload or { text = tostring(payload) }
	payload.kind = kind
	if player then
		if player.Parent == Players then
			feedbackEvent:FireClient(player, payload)
		end
	else
		feedbackEvent:FireAllClients(payload)
	end
end

local function cueFinale(kind, payload)
	payload = type(payload) == "table" and payload or {}
	payload.kind = kind
	payload.runId = finale.runId
	finaleEvent:FireAllClients(payload)
end

local function profileFor(player)
	local profile = profiles[player]
	return profile and profile.loaded and profile or nil
end

local function upgradeLevel(player, upgradeId)
	local profile = profileFor(player)
	if not profile then
		return 0
	end
	return roundedInteger(profile.data.upgrades[upgradeId], 0, 0, upgradeById[upgradeId] and upgradeById[upgradeId].maxLevel or 0)
end

local function effectValue(definition, level)
	return math.clamp(definition.default + (definition.perLevel * level), definition.minimum, definition.maximum)
end

local function playerEffect(player, effectKey)
	local definition = Config.Effects[effectKey]
	if not definition then
		return nil
	end
	if definition.scope == "Team" then
		return teamEffects[effectKey] or definition.default
	end
	return effectValue(definition, upgradeLevel(player, definition.upgradeId))
end

local function highestTeamUpgradeLevel(upgradeId)
	local highest = 0
	for player in pairs(profiles) do
		if player.Parent == Players then
			highest = math.max(highest, upgradeLevel(player, upgradeId))
		end
	end
	return highest
end

local function applyPlayerEffects(player)
	for effectKey, definition in pairs(Config.Effects) do
		if definition.scope == "Player" then
			player:SetAttribute("Cooper" .. effectKey, effectValue(definition, upgradeLevel(player, definition.upgradeId)))
		end
	end
	local profile = profileFor(player)
	if profile then
		if profile.autoRescueCharges == nil then
			profile.autoRescueCharges = upgradeLevel(player, "AutoRescue") > 0 and 1 or 0
		end
		if profile.emergencyFuseCharges == nil then
			profile.emergencyFuseCharges = upgradeLevel(player, "EmergencyFuse") > 0 and 1 or 0
		end
		player:SetAttribute("CooperAutoRescueCharges", profile.autoRescueCharges)
		player:SetAttribute("CooperEmergencyFuseCharges", profile.emergencyFuseCharges)
	end
end

local function recomputeTeamEffects()
	for effectKey, definition in pairs(Config.Effects) do
		if definition.scope == "Team" then
			local value = effectValue(definition, highestTeamUpgradeLevel(definition.upgradeId))
			teamEffects[effectKey] = value
			state:SetAttribute(effectKey, value)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		applyPlayerEffects(player)
	end
	local coolantCapacity = Config.Reactor.BaseCoolantCapacity + (teamEffects.CoolantCapacityBonus or 0)
	reactor.coolant = math.clamp(reactor.coolant, 0, coolantCapacity)
end

local function nextStageDefinition(player)
	local stage = machineStage
	if player then
		stage = foundationPlayerStage(player)
	end
	return Config.MachineStages[stage + 1]
end

local function calibrationExpectedId()
	return Config.FinalCalibration.Order[#calibration.completed + 1]
end

local function overloadExpectedId()
	return Config.Finale.OverloadOrder[finale.overloadIndex + 1]
end

local function stageRequirementStatus(definition)
	if not definition or not definition.requirement then
		return true, ""
	elseif definition.requirement == "ReactorCommissioned" then
		return reactor.commissioned, "Commission the Garage Reactor to 20% first."
	elseif definition.requirement == "ChronoCoreCharged" then
		return reactor.chronoCoreCharge >= Config.Reactor.MaximumCharge, "Charge the Chrono-Core to 100% first."
	elseif definition.requirement == "FinalCalibration" then
		return #calibration.completed >= #Config.FinalCalibration.Order, "Complete Clock, Navigation, and Power calibration in order."
	end
	return false, "Unknown stage requirement: " .. tostring(definition.requirement)
end

local function publicNextStage(player)
	local definition = nextStageDefinition(player)
	if not definition then
		return nil
	end
	local ready, reason = stageRequirementStatus(definition)
	return {
		stage = definition.stage,
		name = definition.name,
		progress = definition.progress,
		focus = definition.focus,
		cost = definition.cost,
		allowance = definition.cost,
		ready = ready,
		requirement = definition.requirement,
		blockedReason = reason,
	}
end

local function publicUpgrades(player)
	local profile = profileFor(player)
	local result = {}
	for id, definition in pairs(upgradeById) do
		result[id] = math.clamp(
			roundedInteger(profile and profile.data.upgrades[id], 0, 0, definition.maxLevel),
			0,
			definition.maxLevel
		)
	end
	return result
end

local function publicRegisteredCrises()
	local result = {}
	for crisisId, enabled in pairs(registeredCrises) do
		if enabled then
			table.insert(result, crisisId)
		end
	end
	table.sort(result)
	return result
end

local function snapshotFor(player)
	local foundation = foundationSnapshot(player) or {}
	local profile = profileFor(player)
	local personalStage = roundedInteger(foundation.machineStage, 0, 0, #Config.MachineStages)
	local personalDefinition = Config.MachineStages[personalStage]
	return {
		revision = revision,
		serverTime = serverNow(),
		profileLoaded = profile ~= nil,
		persistenceStatus = player and player:GetAttribute("CooperPersistenceStatus") or "Unknown",
		foundationReady = next(foundation) ~= nil,
		allowance = tonumber(foundation.allowance) or tonumber(foundation.cash) or 0,
		machineStage = personalStage,
		machineProgress = personalDefinition and personalDefinition.progress or 0,
		chapter = tonumber(foundation.chapter) or tonumber(campaignState:GetAttribute("Chapter")) or 0,
		chapterName = foundation.chapterName or campaignState:GetAttribute("ChapterName") or "The Blueprint",
		nextStage = publicNextStage(player),
		upgrades = player and publicUpgrades(player) or {},
		teamEffects = table.clone(teamEffects),
		reactor = {
			running = reactor.running,
			mode = reactor.mode,
			coolant = reactor.coolant,
			coolantCapacity = Config.Reactor.BaseCoolantCapacity + (teamEffects.CoolantCapacityBonus or 0),
			heat = reactor.heat,
			suspicion = reactor.suspicion,
			commissionCharge = reactor.commissionCharge,
			commissioned = reactor.commissioned,
			chronoCoreCharge = reactor.chronoCoreCharge,
			cooldownUntil = reactor.cooldownUntil,
		},
		calibration = {
			completed = table.clone(calibration.completed),
			expected = calibrationExpectedId(),
			startedAt = calibration.startedAt,
		},
		finale = {
			running = finale.running,
			runId = finale.runId,
			phase = finale.phase,
			phaseTitle = finale.phaseTitle,
			objective = finale.objective,
			deadline = finale.deadline,
			expectedSwitch = overloadExpectedId(),
			overloadIndex = finale.overloadIndex,
		},
		registeredCrises = publicRegisteredCrises(),
		victory = profile and profile.data.victory == true or false,
		totalVictories = profile and profile.data.totalVictories or 0,
	}
end

local function writeStateAttributes()
	state:SetAttribute("SchemaVersion", Config.SchemaVersion)
	state:SetAttribute("ServerTime", serverNow())
	state:SetAttribute("Revision", revision)
	state:SetAttribute("MachineStage", machineStage)
	state:SetAttribute("MachineProgress", machineProgress)
	state:SetAttribute("MachineStageScope", "MaxConnectedPresentationOnly")
	state:SetAttribute("EconomyOwner", "CooperGame")
	state:SetAttribute("ComponentOrderingOwner", "CooperGame")
	state:SetAttribute("NextStageName", nextStageDefinition() and nextStageDefinition().name or "Complete")
	state:SetAttribute("ReactorRunning", reactor.running)
	state:SetAttribute("ReactorMode", reactor.mode)
	state:SetAttribute("ReactorCoolant", reactor.coolant)
	state:SetAttribute("ReactorCoolantCapacity", Config.Reactor.BaseCoolantCapacity + (teamEffects.CoolantCapacityBonus or 0))
	state:SetAttribute("ReactorHeat", reactor.heat)
	state:SetAttribute("ReactorSuspicion", reactor.suspicion)
	state:SetAttribute("ReactorCommissionCharge", reactor.commissionCharge)
	state:SetAttribute("ReactorCommissioned", reactor.commissioned)
	state:SetAttribute("ChronoCoreCharge", reactor.chronoCoreCharge)
	state:SetAttribute("ReactorLockedUntil", reactor.cooldownUntil)
	state:SetAttribute("FinaleRunning", finale.running)
	state:SetAttribute("FinaleRunId", finale.runId)
	state:SetAttribute("FinalePhase", finale.phase)
	state:SetAttribute("FinaleDeadline", finale.deadline)
	state:SetAttribute("CalibrationStep", #calibration.completed)
	state:SetAttribute("CalibrationExpected", calibrationExpectedId() or "Complete")
	state:SetAttribute("RegisteredCrisisCount", #publicRegisteredCrises())
end

local function broadcastSnapshot()
	revision += 1
	writeStateAttributes()
	for _, player in ipairs(Players:GetPlayers()) do
		snapshotEvent:FireClient(player, snapshotFor(player))
	end
end

local function setPartStageVisible(part, visible)
	if part:GetAttribute("BaseTransparency") == nil then
		part:SetAttribute("BaseTransparency", part.Transparency)
		part:SetAttribute("BaseCanCollide", part.CanCollide)
		part:SetAttribute("BaseCanQuery", part.CanQuery)
	end
	part.Transparency = visible and (tonumber(part:GetAttribute("BaseTransparency")) or 0) or 1
	part.CanCollide = visible and part:GetAttribute("BaseCanCollide") == true
	part.CanQuery = visible and part:GetAttribute("BaseCanQuery") ~= false
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			if descendant:GetAttribute("BaseTransparency") == nil then
				descendant:SetAttribute("BaseTransparency", descendant.Transparency)
			end
			descendant.Transparency = visible and (tonumber(descendant:GetAttribute("BaseTransparency")) or 0) or 1
		elseif descendant:IsA("Light") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") then
			if descendant:GetAttribute("BaseEnabled") == nil then
				descendant:SetAttribute("BaseEnabled", descendant.Enabled)
			end
			descendant.Enabled = visible and descendant:GetAttribute("BaseEnabled") ~= false
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			if descendant:GetAttribute("BaseEnabled") == nil then
				descendant:SetAttribute("BaseEnabled", descendant.Enabled)
			end
			descendant.Enabled = visible and descendant:GetAttribute("BaseEnabled") ~= false
		end
	end
end

local function applyMachineVisuals()
	for _, stageModel in ipairs(stagesFolder:GetChildren()) do
		local required = roundedInteger(stageModel:GetAttribute("RequiredStage"), 99, 1, 99)
		local visible = required <= machineStage
		for _, descendant in ipairs(stageModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				setPartStageVisible(descendant, visible)
			end
		end
		stageModel:SetAttribute("StageVisible", visible)
	end
	local reactorLights = machine:FindFirstChild("ReactorLights", true)
	if reactorLights and reactorLights:IsA("BasePart") then
		if reactor.running then
			reactorLights.Color = reactor.mode == "Ludicrous" and Color3.fromRGB(255, 54, 60)
				or (reactor.mode == "Fast" and Color3.fromRGB(255, 184, 55) or Color3.fromRGB(67, 220, 255))
			reactorLights.Material = Enum.Material.Neon
		else
			reactorLights.Color = Color3.fromRGB(61, 74, 79)
			reactorLights.Material = Enum.Material.Metal
		end
	end
end

local function reactorControlsLocked()
	return reactorLocked or serverNow() < reactor.cooldownUntil
end

local function updatePromptStates()
	local nextStage = nextStageDefinition()
	local stageReady, blockReason = stageRequirementStatus(nextStage)
	purchasePrompt.Enabled = nextStage ~= nil and not finale.running
	if nextStage then
		if stageReady then
			purchasePrompt.ActionText = string.format("Order at computer ($%d)", nextStage.cost)
		else
			purchasePrompt.ActionText = "Requirement missing"
		end
		purchasePrompt.ObjectText = nextStage.name
		purchaseConsole:SetAttribute("BlockedReason", blockReason)
	else
		purchasePrompt.ActionText = "Machine complete"
		purchasePrompt.ObjectText = "Time Machine"
	end

	upgradePrompt.Enabled = not finale.running
	local reactorAvailable = machineStage >= 7 and not finale.running and not reactorControlsLocked()
	local reactorTargetIncomplete = (machineStage == 7 and not reactor.commissioned)
		or (machineStage >= 8 and reactor.chronoCoreCharge < Config.Reactor.MaximumCharge)
	reactorPrompt.Enabled = reactorAvailable and (reactor.running or reactorTargetIncomplete)
	reactorPrompt.ActionText = reactor.running and "Emergency stop" or "Start reactor"
	reactorModePrompt.Enabled = reactorAvailable and not reactor.running
	reactorModePrompt.ActionText = "Mode: " .. reactor.mode
	coolantPrompt.Enabled = reactorAvailable and reactor.coolant < Config.Reactor.BaseCoolantCapacity + (teamEffects.CoolantCapacityBonus or 0) - 0.01
	coolantPrompt.ActionText = "Refill coolant ($" .. tostring(Config.Reactor.CoolantRefillCash) .. ")"

	local calibrationTeamLevel = highestTeamUpgradeLevel("CalibrationTools")
	local expectedCalibration = calibrationExpectedId()
	local expectedOverload = overloadExpectedId()
	for id, record in pairs(calibrationControls) do
		record.prompt.HoldDuration = math.max(2.5, Config.FinalCalibration.HoldDuration - (calibrationTeamLevel * 0.5))
		if finale.running and finale.phase == "ReactorOverload" then
			record.prompt.Enabled = id == expectedOverload
			record.prompt.ActionText = id == expectedOverload and "Stabilize " .. id or "Waiting"
		elseif machineStage >= 11 and not finale.running and #calibration.completed < #Config.FinalCalibration.Order then
			record.prompt.Enabled = id == expectedCalibration
			record.prompt.ActionText = id == expectedCalibration and "Calibrate " .. id or "Waiting"
		else
			record.prompt.Enabled = false
		end
	end
	launchPrompt.Enabled = machineStage >= 11 and not finale.running
	launchPrompt.ActionText = #calibration.completed < #Config.FinalCalibration.Order and "Calibration required"
		or (reactor.chronoCoreCharge >= Config.Reactor.MaximumCharge and "Launch Time Machine" or "Charge Chrono-Core")
	returnPrompt.Enabled = true
	applyMachineVisuals()
end

local function syncFoundationState()
	local newStage = roundedInteger(campaignState:GetAttribute("MachineStage"), machineStage, 0, #Config.MachineStages)
	local newProgress = roundedInteger(campaignState:GetAttribute("MachineProgress"), machineProgress, 0, 100)
	local changed = newStage ~= machineStage or newProgress ~= machineProgress
	machineStage = newStage
	machineProgress = newProgress
	if machineStage >= 9 and reactor.chronoCoreCharge < Config.Reactor.MaximumCharge then
		-- Stage 9 cannot be purchased without a full core. This also repairs an old
		-- save made before reactor charge persistence existed.
		reactor.chronoCoreCharge = Config.Reactor.MaximumCharge
	end
	if machineStage >= 8 then
		reactor.commissioned = true
		reactor.commissionCharge = Config.Reactor.CommissionCharge
	end
	updatePromptStates()
	if changed then
		broadcastSnapshot()
	end
end

local function persistenceKey(player)
	return Config.DataStoreKeyPrefix .. tostring(player.UserId)
end

local function updateProfileFromRuntime(_player, profile)
	-- Allowance, deliveries, stage, and chapter intentionally never enter this
	-- payload; CooperGame is their only persistence owner.
	profile.data.updatedAt = os.time()
end

local function saveProfile(player, releaseLock)
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.saving or not profile.canSave or not dataStore then
		return false
	end
	profile.saving = true
	updateProfileFromRuntime(player, profile)
	local payload = sanitizeProfile(profile.data)
	payload.updatedAt = os.time()
	local success, message = pcall(function()
		dataStore:UpdateAsync(persistenceKey(player), function(old)
			old = type(old) == "table" and old or {}
			local lock = old.sessionLock
			if type(lock) == "table" and lock.jobId ~= game.JobId then
				return old
			end
			local result = table.clone(payload)
			if not releaseLock then
				result.sessionLock = { jobId = game.JobId, timestamp = os.time() }
			end
			return result
		end)
	end)
	profile.saving = false
	if success then
		profile.dirty = false
		profile.lastSaveAt = serverNow()
		return true
	end
	warnPersistenceOnce(message)
	return false
end

local function acquireProfile(player)
	local raw = nil
	local canSave = dataStore ~= nil
	local status = dataStoreEnabled and "Loading" or "SessionOnly"
	if dataStore then
		local conflict = false
		local success, result = pcall(function()
			return dataStore:UpdateAsync(persistenceKey(player), function(old)
				old = type(old) == "table" and old or {}
				local lock = old.sessionLock
				if type(lock) == "table"
					and lock.jobId ~= game.JobId
					and os.time() - (tonumber(lock.timestamp) or 0) < 180
				then
					conflict = true
					return old
				end
				raw = table.clone(old)
				old.sessionLock = { jobId = game.JobId, timestamp = os.time() }
				return old
			end)
		end)
		if not success then
			warnPersistenceOnce(result)
			canSave = false
			status = "SessionOnly"
		elseif conflict then
			canSave = false
			status = "ReadOnlyConflict"
		else
			status = "Loaded"
		end
	end
	local profile = {
		data = sanitizeProfile(raw),
		loaded = true,
		canSave = canSave,
		dirty = false,
		saving = false,
		lastSaveAt = serverNow(),
		autoRescueCharges = nil,
		emergencyFuseCharges = nil,
	}
	profiles[player] = profile
	player:SetAttribute("CooperPersistenceStatus", status)
	return profile
end

local function setupPlayer(player)
	player:SetAttribute("CooperPersistenceStatus", "Loading")
	acquireProfile(player)
	if player.Parent ~= Players then
		profiles[player] = nil
		return
	end
	local foundationReady = false
	local deadline = serverNow() + 15
	repeat
		foundationReady = foundationSnapshot(player) ~= nil
		if not foundationReady then
			task.wait(0.25)
		end
	until foundationReady or serverNow() >= deadline or player.Parent ~= Players
	player:SetAttribute("CooperProgressionAPIReady", foundationReady)
	recomputeTeamEffects()
	applyPlayerEffects(player)
	updatePromptStates()
	broadcastSnapshot()
end

local function passRequestCooldown(player)
	local currentTime = os.clock()
	if (requestNextAt[player] or 0) > currentTime then
		return false
	end
	requestNextAt[player] = currentTime + Config.RequestCooldown
	return true
end

local function economyUnavailable(player)
	sendFeedback(player, "Error", {
		text = "The campaign economy is still syncing. Try again in a moment.",
		code = "FoundationEconomyUnavailable",
	})
end

local function markAllProfilesProgress()
	-- Reactor and calibration are shared session state. Do not duplicate them
	-- into every player's persistent Family or extension profile.
end

local function buyUpgrade(player, upgradeId)
	local profile = profileFor(player)
	local definition = type(upgradeId) == "string" and upgradeById[upgradeId] or nil
	if not profile or not definition or finale.running then
		return false
	end
	if dataStoreEnabled and not profile.canSave then
		sendFeedback(player, "Error", {
			text = "Upgrade purchases are temporarily locked because progression could not be saved safely.",
		})
		return false
	end
	if profile.upgradeLocked then
		return false
	end
	if not playerNear(player, upgradeConsole, 2) then
		return false
	end
	local currentLevel = upgradeLevel(player, upgradeId)
	if currentLevel >= definition.maxLevel then
		sendFeedback(player, "Error", { text = definition.name .. " is already maxed out." })
		return false
	end
	local nextLevel = currentLevel + 1
	local cost = definition.costs[nextLevel]
	profile.upgradeLocked = true
	local spent, reason = spendAllowance(
		player,
		cost.allowance,
		"Upgrade: " .. definition.name .. " level " .. tostring(nextLevel)
	)
	if not spent then
		profile.upgradeLocked = false
		sendFeedback(player, "Error", { text = tostring(reason or "You cannot afford that upgrade.") })
		return false
	end
	profile.data.upgrades[upgradeId] = nextLevel
	profile.dirty = true
	if upgradeId == "AutoRescue" and currentLevel == 0 then
		profile.autoRescueCharges = 1
	elseif upgradeId == "EmergencyFuse" and currentLevel == 0 then
		profile.emergencyFuseCharges = 1
	end
	profile.upgradeLocked = false
	recomputeTeamEffects()
	updatePromptStates()
	sendFeedback(player, "UpgradePurchased", {
		id = upgradeId,
		name = definition.name,
		level = nextLevel,
		maxLevel = definition.maxLevel,
		allowanceCost = cost.allowance,
	})
	broadcastSnapshot()
	task.defer(saveProfile, player, false)
	return true
end

local function buyNextStage(player)
	if finale.running or not playerNear(player, purchaseConsole, 2) then
		return false
	end
	local personalStage, foundation = foundationPlayerStage(player)
	local definition = Config.MachineStages[personalStage + 1]
	if not definition then
		sendFeedback(player, "Error", { text = "The Time Machine is already complete." })
		return false
	end
	if foundation and foundation.delivery then
		sendFeedback(player, "Error", { text = "You already have a component delivery in progress." })
		return false
	end
	local ready, blockedReason = stageRequirementStatus(definition)
	if not ready then
		sendFeedback(player, "Error", { text = blockedReason })
		return false
	end
	-- Never call Family OrderMachinePart from this callback. Family calls the
	-- read-only CanOrderMachinePart validator before its own atomic computer
	-- order, avoiding a BindableFunction re-entry cycle.
	sendFeedback(player, "UseComputerShop", {
		text = string.format("Order %s for $%d allowance from Sheldon's computer.", definition.name, definition.cost),
		stage = definition.stage,
		cost = definition.cost,
	})
	return false
end

local function cycleReactorMode(player)
	local playerStage = foundationPlayerStage(player)
	if reactorControlsLocked() or reactor.running or playerStage < 7 or finale.running or not playerNear(player, reactorModeConsole, 2) then
		return false
	end
	local currentIndex = table.find(Config.Reactor.ModeOrder, reactor.mode) or 1
	reactor.mode = Config.Reactor.ModeOrder[(currentIndex % #Config.Reactor.ModeOrder) + 1]
	updatePromptStates()
	sendFeedback(nil, "ReactorMode", { mode = reactor.mode })
	broadcastSnapshot()
	return true
end

local function reactorHasTarget(playerStage)
	return (playerStage == 7 and not reactor.commissioned)
		or (playerStage >= 8 and reactor.chronoCoreCharge < Config.Reactor.MaximumCharge)
end

local function toggleReactor(player)
	local playerStage = foundationPlayerStage(player)
	if reactorControlsLocked() or playerStage < 7 or finale.running or not playerNear(player, reactorConsole, 2) then
		return false
	end
	if reactor.running then
		reactor.running = false
		reactor.operator = nil
		reactor.operatorStage = 0
		updatePromptStates()
		sendFeedback(nil, "Reactor", { text = "Reactor stopped safely.", running = false })
		broadcastSnapshot()
		return true
	end
	if serverNow() < reactor.cooldownUntil then
		sendFeedback(player, "Error", { text = "The reactor safety lock is still cooling down." })
		return false
	end
	if not reactorHasTarget(playerStage) then
		sendFeedback(player, "Error", { text = "There is nothing left to charge right now." })
		return false
	end
	if reactor.coolant <= 0.01 then
		sendFeedback(player, "Error", { text = "Refill the reactor coolant first." })
		return false
	end
	reactor.running = true
	reactor.operator = player
	reactor.operatorStage = playerStage
	updatePromptStates()
	sendFeedback(nil, "Reactor", { text = reactor.mode .. " reactor cycle started.", running = true, mode = reactor.mode })
	broadcastSnapshot()
	return true
end

local function refillCoolant(player)
	local playerStage = foundationPlayerStage(player)
	if reactorControlsLocked() or playerStage < 7 or finale.running or not playerNear(player, coolantConsole, 2) then
		return false
	end
	local capacity = Config.Reactor.BaseCoolantCapacity + (teamEffects.CoolantCapacityBonus or 0)
	if reactor.coolant >= capacity - 0.01 then
		sendFeedback(player, "Error", { text = "The coolant tank is already full." })
		return false
	end
	reactorLocked = true
	local spent, reason = spendAllowance(player, Config.Reactor.CoolantRefillCash, "Garage Reactor coolant refill")
	reactorLocked = false
	if not spent then
		sendFeedback(player, "Error", { text = tostring(reason or "You cannot afford coolant.") })
		return false
	end
	reactor.coolant = capacity
	markAllProfilesProgress()
	updatePromptStates()
	sendFeedback(player, "CoolantRefilled", { coolant = reactor.coolant, capacity = capacity })
	broadcastSnapshot()
	return true
end

local function consumeSessionCharge(player, chargeName)
	local profile = profileFor(player)
	if not profile then
		return false
	end
	local field = chargeName == "AutoRescue" and "autoRescueCharges"
		or (chargeName == "EmergencyFuse" and "emergencyFuseCharges" or nil)
	if not field or (profile[field] or 0) <= 0 then
		return false
	end
	profile[field] -= 1
	applyPlayerEffects(player)
	return true
end

local function findEmergencyFuseUser()
	local operator = reactor.operator
	if operator and operator.Parent == Players and playerNear(operator, reactorConsole, 10)
		and consumeSessionCharge(operator, "EmergencyFuse")
	then
		return operator
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= operator and playerNear(player, reactorConsole, 10) and consumeSessionCharge(player, "EmergencyFuse") then
			return player
		end
	end
	return nil
end

local function reactorAccident(reason)
	reactor.running = false
	local operatorStage = reactor.operatorStage
	local fuseUser = findEmergencyFuseUser()
	reactor.operator = nil
	reactor.operatorStage = 0
	if fuseUser then
		reactor.heat = math.min(55, reactor.heat)
		reactor.coolant = math.max(25, reactor.coolant)
		reactor.cooldownUntil = serverNow() + 8
		sendFeedback(nil, "EmergencyFuse", {
			text = fuseUser.DisplayName .. "'s emergency fuse prevented a reactor accident!",
		})
	else
		local stabilizerMultiplier = teamEffects.MachineHeatMultiplier or 1
		local chargeLoss = Config.Reactor.AccidentChargeLoss * stabilizerMultiplier
		if operatorStage == 7 then
			reactor.commissionCharge = math.max(0, reactor.commissionCharge - chargeLoss)
			reactor.commissioned = false
		else
			reactor.chronoCoreCharge = math.max(0, reactor.chronoCoreCharge - chargeLoss)
		end
		reactor.heat = 70
		reactor.coolant = 0
		reactor.cooldownUntil = serverNow() + Config.Reactor.AccidentCooldown
		adjustFoundationStability(-Config.Reactor.StabilityLoss, "Garage reactor accident: " .. tostring(reason))
		sendFeedback(nil, "ReactorAccident", {
			text = "REACTOR SCRAM: " .. tostring(reason),
			chargeLost = chargeLoss,
		})
	end
	markAllProfilesProgress()
	updatePromptStates()
	broadcastSnapshot()
end

local function triggerDESAlert()
	reactor.running = false
	reactor.operator = nil
	reactor.operatorStage = 0
	reactor.suspicion = 65
	local runId = "ReactorAlert:" .. HttpService:GenerateGUID(false)
	crisisRequestEvent:Fire("DESRaid", runId, {
		source = "GarageReactor",
		suspicion = 100,
		finale = false,
	})
	adjustFoundationStability(-10, "D.E.S. detected suspicious garage power")
	sendFeedback(nil, "DESAlert", { text = "D.E.S. detected the reactor spike. Shut everything down!" })
	updatePromptStates()
	broadcastSnapshot()
end

local function resetCalibration(message)
	table.clear(calibration.completed)
	calibration.startedAt = 0
	updatePromptStates()
	if message then
		sendFeedback(nil, "CalibrationReset", { text = message })
	end
	broadcastSnapshot()
end

local function completeConstructionCalibration(player, id)
	local playerStage = foundationPlayerStage(player)
	if finale.running or playerStage < 11 then
		return false
	end
	local record = calibrationControls[id]
	if not record or not playerNear(player, record.part, 2) or calibrationExpectedId() ~= id then
		return false
	end
	if calibration.startedAt == 0 then
		calibration.startedAt = serverNow()
	elseif serverNow() - calibration.startedAt > Config.FinalCalibration.ResetAfterSeconds then
		resetCalibration("The readings drifted. Start calibration again from the Clock control.")
		return false
	end
	table.insert(calibration.completed, id)
	sendFeedback(nil, "CalibrationStep", {
		playerName = player.DisplayName,
		step = #calibration.completed,
		total = #Config.FinalCalibration.Order,
		control = id,
	})
	if #calibration.completed < #Config.FinalCalibration.Order then
		updatePromptStates()
		broadcastSnapshot()
		return true
	end
	calibration.startedAt = 0
	updatePromptStates()
	sendFeedback(nil, "FinalCalibrationComplete", {
		text = "FINAL CALIBRATION COMPLETE — THE TIME MACHINE IS READY",
	})
	broadcastSnapshot()
	return true
end

local function setFinalePhase(phase, title, objective, deadline)
	finale.phase = phase
	finale.phaseTitle = title or phase
	finale.objective = objective or ""
	finale.deadline = deadline or 0
	updatePromptStates()
	writeStateAttributes()
	cueFinale("Phase", {
		phase = finale.phase,
		title = finale.phaseTitle,
		objective = finale.objective,
		deadline = finale.deadline,
	})
	broadcastSnapshot()
end

local function waitUntil(deadline, predicate)
	repeat
		if predicate() then
			return true
		end
		task.wait(0.15)
	until serverNow() >= deadline or not finale.running
	return predicate()
end

local function runCrisisPhase(definition)
	if definition.id == "GeorgePanic" then
		local characterEvents = ServerScriptService:FindFirstChild("CooperCharacterServerEvents")
		local characterAPI = characterEvents and characterEvents:FindFirstChild("API")
		if not characterAPI or not characterAPI:IsA("BindableFunction") then
			return false, "George Panic controller is unavailable"
		end
		local deadline = serverNow() + Config.Finale.ExternalTimeout
		setFinalePhase(definition.id, definition.title, definition.objective, deadline)
		local startedOK, started = pcall(function()
			return characterAPI:Invoke(
				"BeginPanic",
				"Final launch pressure pushed George over the edge",
				"Finale",
				finale.startedBy and finale.startedBy.UserId or 0
			)
		end)
		if not startedOK or started ~= true then
			return false, "George Panic could not start"
		end
		local resolved = waitUntil(deadline, function()
			local ok, characterState = pcall(function()
				return characterAPI:Invoke("GetSnapshot")
			end)
			return ok and type(characterState) == "table" and characterState.panicActive == false
		end)
		if not finale.running then
			return false, "Finale cancelled"
		elseif not resolved then
			pcall(function() characterAPI:Invoke("EndPanic", "Finale George Panic timed out") end)
			adjustFoundationStability(-definition.stabilityLoss, definition.title .. " failed")
			return false, definition.title .. " timed out"
		end
		return true
	end
	local crisisRunId = finale.runId .. ":" .. definition.id
	local hasDirector = registeredCrises[definition.id] == true
	local duration = hasDirector and Config.Finale.ExternalTimeout or Config.Finale.FallbackDuration
	local deadline = serverNow() + duration
	pendingCrisisResults[crisisRunId] = nil
	setFinalePhase(definition.id, definition.title, definition.objective, deadline)
	crisisRequestEvent:Fire(definition.id, crisisRunId, {
		finale = true,
		deadline = deadline,
		teamEffects = table.clone(teamEffects),
	})
	if not hasDirector then
		-- The fallback keeps the campaign completable in isolated test places. A
		-- registered crisis director always owns real success/failure resolution.
		waitUntil(deadline, function()
			return not finale.running
		end)
		return finale.running
	end
	local resolved = waitUntil(deadline, function()
		return pendingCrisisResults[crisisRunId] ~= nil or not finale.running
	end)
	if not finale.running then
		return false, "Finale cancelled"
	end
	local result = pendingCrisisResults[crisisRunId]
	pendingCrisisResults[crisisRunId] = nil
	if not resolved or result == nil then
		return false, definition.title .. " timed out"
	elseif result.success ~= true then
		adjustFoundationStability(-definition.stabilityLoss, definition.title .. " failed")
		return false, tostring(result.reason or (definition.title .. " failed"))
	end
	return true
end

local function failFinale(reason)
	if not finale.running then
		return
	end
	finale.running = false
	finale.phase = "Failed"
	finale.phaseTitle = "LAUNCH ABORTED"
	finale.objective = tostring(reason or "The launch sequence failed safely.")
	finale.deadline = 0
	finale.overloadIndex = 0
	reactor.running = false
	reactor.operator = nil
	reactor.operatorStage = 0
	reactor.cooldownUntil = serverNow() + 12
	setFoundationMode("Normal", "Time Machine launch aborted")
	updatePromptStates()
	cueFinale("Failed", { text = finale.objective })
	sendFeedback(nil, "FinaleFailed", { text = finale.objective })
	broadcastSnapshot()
end

local function teleportToFuture()
	local players = Players:GetPlayers()
	local columns = math.max(1, math.ceil(math.sqrt(#players)))
	for index, player in ipairs(players) do
		local character = player.Character
		local root = playerRoot(player)
		if character and root then
			local row = math.floor((index - 1) / columns)
			local column = (index - 1) % columns
			local offset = Vector3.new((column - (columns - 1) * 0.5) * 4, 3, row * 4)
			character:PivotTo(futureSpawn.CFrame + offset)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		player:SetAttribute("CooperVictory", true)
	end
end

local function completeVictory()
	teleportToFuture()
	local chapterOK, chapterSet = invokeFoundation(
		Config.FoundationOperations.SetChapter,
		12,
		"The Big Bang Theory Apartment",
		"Arrived in the future"
	)
	local modeOK = setFoundationMode("Victory", "Time travel succeeded")
	if not modeOK then
		warn("[CooperProgression] Family foundation could not publish Victory mode after a successful teleport")
	end
	if not chapterOK or chapterSet == nil then
		state:SetAttribute("CompatibilityNotice", "Add Foundation API SetChapter to publish the epilogue globally")
	end
	finale.running = false
	finale.phase = "Victory"
	finale.phaseTitle = "THE FUTURE"
	finale.objective = "Relax in the apartment. You made it."
	finale.deadline = 0
	for player, profile in pairs(profiles) do
		if profile.loaded then
			if not profile.data.victory then
				profile.data.totalVictories += 1
			end
			profile.data.victory = true
			profile.dirty = true
			task.defer(saveProfile, player, false)
		end
	end
	updatePromptStates()
	cueFinale("Victory", {
		title = "WELCOME TO THE FUTURE",
		text = "The Big Bang Theory apartment is real. The ending is safe.",
	})
	sendFeedback(nil, "Victory", { text = "TIME MACHINE COMPLETE — WELCOME TO THE FUTURE" })
	broadcastSnapshot()
end

local function completeOverloadSwitch(player, id)
	if not finale.running or finale.phase ~= "ReactorOverload" or foundationPlayerStage(player) < 11 then
		return false
	end
	local record = calibrationControls[id]
	if not record or not playerNear(player, record.part, 2) or overloadExpectedId() ~= id then
		return false
	end
	finale.overloadIndex += 1
	sendFeedback(nil, "OverloadSwitch", {
		playerName = player.DisplayName,
		control = id,
		step = finale.overloadIndex,
		total = #Config.Finale.OverloadOrder,
	})
	updatePromptStates()
	broadcastSnapshot()
	return true
end

local function beginFinale(player)
	local playerStage = foundationPlayerStage(player)
	if finale.running or playerStage < 11 or not playerNear(player, launchConsole, 2) then
		return false
	end
	if #calibration.completed < #Config.FinalCalibration.Order then
		sendFeedback(player, "Error", { text = "Complete Clock, Navigation, and Power calibration before launch." })
		return false
	end
	if reactor.chronoCoreCharge < Config.Reactor.MaximumCharge then
		sendFeedback(player, "Error", { text = "Charge the Chrono-Core to 100% before launch." })
		return false
	end
	local foundation = foundationSnapshot(player)
	if not foundation then
		economyUnavailable(player)
		return false
	end
	if campaignState:GetAttribute("SupportsStability") == true
		and (tonumber(foundation.stability) or 0) < Config.Finale.MinimumStability
	then
		sendFeedback(player, "Error", {
			text = "House Stability must be at least " .. tostring(Config.Finale.MinimumStability) .. " before launch.",
		})
		return false
	end
	local mode = tostring(foundation.mode or campaignState:GetAttribute("Mode") or "Normal")
	if mode ~= "Normal" then
		sendFeedback(player, "Error", { text = "Finish the current " .. mode .. " event before starting the launch." })
		return false
	end
	local modeSet = setFoundationMode("Finale", player.DisplayName .. " started the Time Machine")
	if not modeSet then
		economyUnavailable(player)
		return false
	end
	finale.running = true
	finale.runId = HttpService:GenerateGUID(false)
	finale.startedBy = player
	finale.overloadIndex = 0
	reactor.running = false
	reactor.operator = nil
	reactor.operatorStage = 0
	setFinalePhase("LaunchArming", "FINAL LAUNCH", "Get ready. Every crisis is about to hit at once.", serverNow() + 5)
	cueFinale("Start", { startedBy = player.DisplayName })
	task.spawn(function()
		local armingDeadline = serverNow() + 5
		waitUntil(armingDeadline, function()
			return not finale.running
		end)
		if not finale.running then
			return
		end
		for _, phase in ipairs(Config.Finale.Phases) do
			local success, reason = runCrisisPhase(phase)
			if not success then
				failFinale(reason)
				return
			end
		end
		finale.overloadIndex = 0
		local window = Config.Finale.SwitchWindow + (teamEffects.CalibrationWindowBonus or 0)
		local overloadDeadline = serverNow() + window
		setFinalePhase(
			"ReactorOverload",
			"REACTOR OVERLOAD",
			"Hit POWER, then CLOCK, then NAVIGATION before the timer reaches zero.",
			overloadDeadline
		)
		local stabilized = waitUntil(overloadDeadline, function()
			return finale.overloadIndex >= #Config.Finale.OverloadOrder or not finale.running
		end)
		if not stabilized or finale.overloadIndex < #Config.Finale.OverloadOrder then
			adjustFoundationStability(-Config.Reactor.StabilityLoss, "Final reactor overload")
			failFinale("The reactor overload was not stabilized in time.")
			return
		end
		local departureDeadline = serverNow() + Config.Finale.DepartureDelay
		setFinalePhase("Departure", "TEMPORAL JUMP", "Stay inside the garage. The future is locking on.", departureDeadline)
		cueFinale("TimeTravel", { duration = Config.Finale.DepartureDelay })
		waitUntil(departureDeadline, function()
			return not finale.running
		end)
		if finale.running then
			completeVictory()
		end
	end)
	return true
end

local function returnPlayerToGarage(player)
	if not playerNear(player, returnPortal, 3) then
		return false
	end
	local character = player.Character
	local root = playerRoot(player)
	if character and root then
		character:PivotTo(returnSpawn.CFrame + Vector3.new(0, 3, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return true
	end
	return false
end

progressionAPI.OnInvoke = function(operation, arg1, arg2)
	if operation == "GetSnapshot" then
		local player = typeof(arg1) == "Instance" and arg1:IsA("Player") and arg1 or nil
		return snapshotFor(player)
	elseif operation == "GetUpgradeLevel" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		return upgradeLevel(arg1, tostring(arg2))
	elseif operation == "GetEffect" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		return playerEffect(arg1, tostring(arg2))
	elseif operation == "GetTeamEffects" then
		return table.clone(teamEffects)
	elseif operation == "CanOrderMachinePart" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		local expectedStage = roundedInteger(arg2, 0, 0, #Config.MachineStages)
		local definition = Config.MachineStages[expectedStage]
		-- Deliberately do not invoke the Family API here: Family calls this from
		-- inside its own atomic order path. Sequence, balance, and pending-delivery
		-- checks remain Family-owned; this read-only hook supplies advanced gates.
		if not definition then
			return false, "Unknown machine component."
		elseif definition.cost <= 0 then
			return false, "This component has no valid allowance cost."
		end
		return stageRequirementStatus(definition)
	elseif operation == "ConsumeAutoRescue" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		local consumed = consumeSessionCharge(arg1, "AutoRescue")
		if consumed then
			broadcastSnapshot()
		end
		return consumed
	elseif operation == "ConsumeEmergencyFuse" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		local consumed = consumeSessionCharge(arg1, "EmergencyFuse")
		if consumed then
			broadcastSnapshot()
		end
		return consumed
	elseif operation == "GetMachineStage" then
		if typeof(arg1) == "Instance" and arg1:IsA("Player") then
			return foundationPlayerStage(arg1)
		end
		return machineStage -- presentation maximum; never use for player authorization
	elseif operation == "GetWorldPresentationStage" then
		return machineStage
	elseif operation == "GetReactorState" then
		return table.clone(snapshotFor(nil).reactor)
	elseif operation == "LockReactorUntil" then
		local requestedUntil = tonumber(arg1)
		if not requestedUntil or requestedUntil ~= requestedUntil or requestedUntil == math.huge or requestedUntil == -math.huge then
			return false, "Invalid reactor lock deadline"
		end
		reactor.cooldownUntil = math.max(reactor.cooldownUntil, requestedUntil)
		reactor.running = false
		reactor.operator = nil
		reactor.operatorStage = 0
		updatePromptStates()
		sendFeedback(nil, "ReactorLocked", {
			untilTime = reactor.cooldownUntil,
			reason = tostring(arg2 or "External safety lock"),
		})
		broadcastSnapshot()
		return true, reactor.cooldownUntil
	elseif operation == "MarkProfileDirty" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		local profile = profileFor(arg1)
		if profile then
			profile.dirty = true
			return true
		end
	end
	return nil
end

registerCrisisEvent.Event:Connect(function(crisisId, enabled)
	if type(crisisId) ~= "string" or #crisisId > 48 then
		return
	end
	registeredCrises[crisisId] = enabled ~= false
	writeStateAttributes()
end)

crisisResolvedEvent.Event:Connect(function(crisisId, runId, success, reason)
	if not finale.running or type(crisisId) ~= "string" or type(runId) ~= "string" or pendingCrisisResults[runId] ~= nil then
		return
	end
	if not string.find(runId, finale.runId, 1, true) then
		return
	end
	pendingCrisisResults[runId] = {
		crisisId = crisisId,
		success = success == true,
		reason = type(reason) == "string" and reason or nil,
	}
end)

purchasePrompt.Triggered:Connect(buyNextStage)
upgradePrompt.Triggered:Connect(function(player)
	if playerNear(player, upgradeConsole, 2) and not finale.running then
		sendFeedback(player, "OpenShop", {})
		snapshotEvent:FireClient(player, snapshotFor(player))
	end
end)
reactorPrompt.Triggered:Connect(toggleReactor)
reactorModePrompt.Triggered:Connect(cycleReactorMode)
coolantPrompt.Triggered:Connect(refillCoolant)
launchPrompt.Triggered:Connect(beginFinale)
returnPrompt.Triggered:Connect(returnPlayerToGarage)
for id, record in pairs(calibrationControls) do
	record.prompt.Triggered:Connect(function(player)
		if finale.running then
			completeOverloadSwitch(player, id)
		else
			completeConstructionCalibration(player, id)
		end
	end)
end

requestEvent.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" or not passRequestCooldown(player) then
		return
	end
	if action == "RequestSnapshot" then
		snapshotEvent:FireClient(player, snapshotFor(player))
	elseif action == "BuyUpgrade" and type(payload) == "string" then
		buyUpgrade(player, payload)
	elseif action == "BuyNextStage" then
		buyNextStage(player)
	elseif action == "CycleReactorMode" then
		cycleReactorMode(player)
	elseif action == "ToggleReactor" then
		toggleReactor(player)
	elseif action == "RefillCoolant" then
		refillCoolant(player)
	elseif action == "BeginFinale" then
		beginFinale(player)
	end
end)

campaignState:GetAttributeChangedSignal("MachineStage"):Connect(syncFoundationState)
campaignState:GetAttributeChangedSignal("MachineProgress"):Connect(syncFoundationState)

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupPlayer, player)
end)
Players.PlayerRemoving:Connect(function(player)
	requestNextAt[player] = nil
	local profile = profiles[player]
	if profile and profile.loaded then
		saveProfile(player, true)
	end
	profiles[player] = nil
	recomputeTeamEffects()
	updatePromptStates()
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

game:BindToClose(function()
	shuttingDown = true
	local waiting = 0
	for player, profile in pairs(profiles) do
		if profile.loaded and profile.canSave then
			waiting += 1
			task.spawn(function()
				saveProfile(player, true)
				waiting -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while waiting > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

recomputeTeamEffects()
syncFoundationState()
updatePromptStates()
broadcastSnapshot()

task.spawn(function()
	local lastUpdate = serverNow()
	local lastBroadcast = 0
	while script.Parent and not shuttingDown do
		local currentTime = serverNow()
		local delta = math.clamp(currentTime - lastUpdate, 0, 0.5)
		lastUpdate = currentTime
		local stateChanged = false
		if reactor.running then
			local modeDefinition = Config.Reactor.Modes[reactor.mode] or Config.Reactor.Modes.Safe
			local heatMultiplier = teamEffects.MachineHeatMultiplier or 1
			local suspicionMultiplier = teamEffects.DESSuspicionMultiplier or 1
			reactor.coolant = math.max(0, reactor.coolant - (modeDefinition.coolantPerSecond * delta))
			reactor.heat = math.min(
				Config.Reactor.MaximumHeat,
				reactor.heat + (modeDefinition.heatPerSecond * heatMultiplier * delta)
			)
			reactor.suspicion = math.min(
				Config.Reactor.MaximumSuspicion,
				reactor.suspicion + (modeDefinition.suspicionPerSecond * suspicionMultiplier * delta)
			)
			local chargeDelta = modeDefinition.chargePerSecond * delta
			local operatorStage = reactor.operatorStage
			if operatorStage == 7 then
				reactor.commissionCharge = math.min(Config.Reactor.CommissionCharge, reactor.commissionCharge + chargeDelta)
				if reactor.commissionCharge >= Config.Reactor.CommissionCharge then
					reactor.commissioned = true
					reactor.running = false
					reactor.operator = nil
					reactor.operatorStage = 0
					sendFeedback(nil, "ReactorCommissioned", { text = "GARAGE REACTOR COMMISSIONED — CHRONO-CORE UNLOCKED" })
				end
			elseif operatorStage >= 8 then
				reactor.chronoCoreCharge = math.min(Config.Reactor.MaximumCharge, reactor.chronoCoreCharge + chargeDelta)
				if reactor.chronoCoreCharge >= Config.Reactor.MaximumCharge then
					reactor.running = false
					reactor.operator = nil
					reactor.operatorStage = 0
					sendFeedback(nil, "ChronoCoreCharged", { text = "CHRONO-CORE CHARGED TO 100%" })
				end
			end
			stateChanged = true
			if reactor.coolant <= 0.001 then
				reactorAccident("coolant exhausted")
			elseif reactor.heat >= Config.Reactor.MaximumHeat then
				reactorAccident("core temperature exceeded safe limits")
			elseif reactor.suspicion >= Config.Reactor.MaximumSuspicion then
				triggerDESAlert()
			end
		else
			local newHeat = math.max(0, reactor.heat - Config.Reactor.IdleCoolingPerSecond * delta)
			local newSuspicion = math.max(0, reactor.suspicion - Config.Reactor.IdleSuspicionLossPerSecond * delta)
			stateChanged = math.abs(newHeat - reactor.heat) > 0.001 or math.abs(newSuspicion - reactor.suspicion) > 0.001
			reactor.heat = newHeat
			reactor.suspicion = newSuspicion
		end

		if calibration.startedAt > 0
			and machineStage >= 11
			and #calibration.completed < #Config.FinalCalibration.Order
			and serverNow() - calibration.startedAt > Config.FinalCalibration.ResetAfterSeconds
		then
			resetCalibration("Calibration expired. Start again from the Clock control.")
		end

		if stateChanged then
			markAllProfilesProgress()
			updatePromptStates()
			writeStateAttributes()
			if currentTime - lastBroadcast >= 0.5 then
				lastBroadcast = currentTime
				broadcastSnapshot()
			end
		else
			state:SetAttribute("ServerTime", currentTime)
		end
		task.wait(0.1)
	end
end)

task.spawn(function()
	while script.Parent and not shuttingDown do
		task.wait(10)
		local currentTime = serverNow()
		for player, profile in pairs(profiles) do
			if player.Parent == Players
				and profile.loaded
				and profile.canSave
				and (profile.dirty or currentTime - profile.lastSaveAt >= Config.AutoSaveSeconds)
			then
				task.spawn(saveProfile, player, false)
			end
		end
	end
end)

print(string.format(
	"[CooperProgression] Ready: %d stages, %d upgrades, persistence=%s",
	#Config.MachineStages,
	#Config.Upgrades,
	tostring(dataStoreEnabled)
))
