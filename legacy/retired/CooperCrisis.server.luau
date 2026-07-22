--!nonstrict
-- Server-authoritative tornado, D.E.S. raid, and short-form chaos director.
-- Install as ServerScriptService.CooperCrisis.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ROOT_TIMEOUT = 20
local CONTROLLER_VERSION = "2026-07-13.2"
local TORNADO_UNLOCK_STAGE = 5
local DES_UNLOCK_STAGE = 6
local DES_ALLOWANCE_REWARD = 75
local DES_ALLOWANCE_FINE = 100
local RECOVERY_ALLOWANCE_REWARD = 25
local BASE_STORM_LOCKER_CAPACITY = 1
local TORNADO_REPAIR_COST_PER_UNIT = 35
local INTERACTION_HOLD_TOLERANCE = 0.18

local crisisRoot = ReplicatedStorage:WaitForChild("CooperCrisis", ROOT_TIMEOUT)
assert(crisisRoot, "ReplicatedStorage.CooperCrisis was not installed")
local state = crisisRoot:WaitForChild("State", ROOT_TIMEOUT)
local eventRemote = crisisRoot:WaitForChild("Event", ROOT_TIMEOUT)
local requestRemote = crisisRoot:WaitForChild("Request", ROOT_TIMEOUT)
assert(state:IsA("Folder"), "CooperCrisis.State must be a Folder")
assert(eventRemote:IsA("RemoteEvent"), "CooperCrisis.Event must be a RemoteEvent")
assert(requestRemote:IsA("RemoteEvent"), "CooperCrisis.Request must be a RemoteEvent")

local campaignRoot = ReplicatedStorage:WaitForChild("CooperGame", ROOT_TIMEOUT)
local campaignConfigModule = campaignRoot and campaignRoot:WaitForChild("Config", ROOT_TIMEOUT)
local campaignState = campaignRoot and campaignRoot:WaitForChild("State", ROOT_TIMEOUT)
assert(campaignConfigModule and campaignConfigModule:IsA("ModuleScript"), "CooperGame.Config is required")
assert(campaignState and campaignState:IsA("Folder"), "CooperGame.State is required")
local CampaignConfig = require(campaignConfigModule)
local CAMPAIGN_MODE = CampaignConfig.Mode
assert(type(CAMPAIGN_MODE) == "table", "CooperGame.Config.Mode is required")
for _, modeName in ipairs({ "Normal", "Panic", "Tornado", "DESRaid", "Finale", "Victory" }) do
	assert(type(CAMPAIGN_MODE[modeName]) == "string", "CooperGame.Config.Mode." .. modeName .. " is required")
end

local campaignEvents = ServerScriptService:WaitForChild("CooperGameServerEvents", ROOT_TIMEOUT)
local campaignAPI = campaignEvents and campaignEvents:WaitForChild("API", ROOT_TIMEOUT)
assert(campaignAPI and campaignAPI:IsA("BindableFunction"), "CooperGameServerEvents.API is required")

local environment = workspace:WaitForChild("CooperHouseEnvironment", ROOT_TIMEOUT)
local world = environment and environment:WaitForChild("CooperCrisisWorld", ROOT_TIMEOUT)
assert(world and world:IsA("Model"), "CooperHouseEnvironment.CooperCrisisWorld is required")

local stormLocker = world:WaitForChild("StormLocker", ROOT_TIMEOUT)
local strapStation = world:WaitForChild("StormStrapStation", ROOT_TIMEOUT)
local permitTerminal = world:WaitForChild("DESPermitTerminal", ROOT_TIMEOUT)
local concealCabinet = world:WaitForChild("DESFalseCabinet", ROOT_TIMEOUT)
local distractionSwitch = world:WaitForChild("DESDistractionSwitch", ROOT_TIMEOUT)
local tornadoVisual = world:WaitForChild("TornadoVisual", ROOT_TIMEOUT)
local inspectors = world:WaitForChild("DESInspectors", ROOT_TIMEOUT)
local aftermathSpawns = world:WaitForChild("AftermathSpawns", ROOT_TIMEOUT)
local evidenceHold = world:WaitForChild("EvidenceHold", ROOT_TIMEOUT)

local securePrompt = stormLocker:FindFirstChildWhichIsA("ProximityPrompt", true)
local strapPrompt = strapStation:FindFirstChildWhichIsA("ProximityPrompt", true)
local permitPrompt = permitTerminal:FindFirstChildWhichIsA("ProximityPrompt", true)
local concealPrompt = concealCabinet:FindFirstChildWhichIsA("ProximityPrompt", true)
local distractionPrompt = distractionSwitch:FindFirstChildWhichIsA("ProximityPrompt", true)
assert(securePrompt and strapPrompt and permitPrompt and concealPrompt and distractionPrompt, "Crisis prompts are incomplete")

local serverEvents = ServerScriptService:FindFirstChild("CooperCrisisServerEvents")
if not serverEvents then
	serverEvents = Instance.new("Folder")
	serverEvents.Name = "CooperCrisisServerEvents"
	serverEvents.Parent = ServerScriptService
end
assert(serverEvents:IsA("Folder"), "CooperCrisisServerEvents must be a Folder")

local function ensureBindable(className, name)
	local object = serverEvents:FindFirstChild(name)
	if object and object.ClassName ~= className then
		object:Destroy()
		object = nil
	end
	if not object then
		object = Instance.new(className)
		object.Name = name
		object.Parent = serverEvents
	end
	return object
end

local api = ensureBindable("BindableFunction", "API")
local resolvedEvent = ensureBindable("BindableEvent", "Resolved")

local TORNADO_PHASES = {
	{ name = "WeatherWatch", duration = 12, message = "WEATHER WATCH: secure loose equipment" },
	{ name = "Warning", duration = 10, message = "TORNADO WARNING: get inside now" },
	{ name = "ImpactOne", duration = 15, message = "FIRST IMPACT" },
	{ name = "Eye", duration = 8, message = "THE EYE — recover and prepare" },
	{ name = "ImpactTwo", duration = 15, message = "SECOND IMPACT" },
	{ name = "Aftermath", duration = 15, message = "AFTERMATH: recover scattered equipment" },
}

local DES_PHASES = {
	{ name = "Warning", duration = 12, message = "D.E.S. SIGNAL DETECTED" },
	{ name = "Approach", duration = 10, message = "D.E.S. AGENTS ARE APPROACHING" },
	{ name = "Inspection", duration = 38, message = "PASS, CONCEAL, OR DISTRACT THE INSPECTION" },
	{ name = "Resolution", duration = 8, message = "D.E.S. REPORT INCOMING" },
}

local BRAIN_EVENTS = {
	{ id = "SheldonMonologue", title = "SHELDON HAS A 94-MINUTE EXPLANATION", subtitle = "Nobody asked. He started anyway.", duration = 9 },
	{ id = "RemoteDuplication", title = "THE REMOTE HAS MITOSIS", subtitle = "Only one of them controls the TV.", duration = 12 },
	{ id = "GiantCube", title = "THE CUBE IS NOW A STRUCTURAL PROBLEM", subtitle = "Sheldon calls this progress.", duration = 12 },
	{ id = "TVEmergency", title = "EMERGENCY BROADCAST FROM 2019", subtitle = "The future says to finish the machine.", duration = 10 },
	{ id = "BillyChaos", title = "BILLY SPARKS HAS ENTERED THE SITUATION", subtitle = "The situation has immediately worsened.", duration = 9 },
	{ id = "ChairsFaceTV", title = "EVERY CHAIR NOW FACES FOOTBALL", subtitle = "George considers this interior design.", duration = 10 },
	{ id = "FridgeInflation", title = "THE FRIDGE IS BREATHING", subtitle = "Do not acknowledge it.", duration = 9 },
	{ id = "GeorgeCouchRage", title = "GEORGE HAS LOST THE GOOD COUCH CUSHION", subtitle = "The whole house is taking this personally.", duration = 8 },
	{ id = "WrongRoom", title = "EVERYONE IS IN THE WRONG BEDROOM", subtitle = "The timeline is already leaking.", duration = 9 },
	{ id = "FutureMessage", title = "FUTURE MESSAGE RECEIVED", subtitle = "BUY MORE COOLANT. ALSO AVOID TUESDAY.", duration = 10 },
	{ id = "FiveSecondLoop", title = "YOU HAVE ALREADY SEEN THIS", subtitle = "YOU HAVE ALREADY SEEN THIS", duration = 10 },
	{ id = "GiantRemote", title = "REMOTE LOCATED", subtitle = "It is six feet long now.", duration = 11 },
	{ id = "GiantGeorge", title = "GIANT GEORGE SIGHTING", subtitle = "He is checking the fridge from outside.", duration = 8 },
	{ id = "CharacterFlood", title = "2D CHARACTER FLOOD", subtitle = "The sitcom budget has escaped containment.", duration = 10 },
	{ id = "EveryoneStares", title = "EVERYONE STOPPED TALKING", subtitle = "They are all looking at you.", duration = 8 },
}

local randomizer = Random.new()
local activeKind = nil
local activePhase = "Idle"
local activeReason = ""
local phaseEndsAt = 0
local crisisToken = 0
local suspicion = 0
local desScore = 0
local desRoutes = { Legal = 0, Concealment = 0, Distraction = 0 }
local desContributors = {}
local desParticipants = {}
local movedByTornado = {}
local confiscatedByDES = {}
local nextMajorAt = workspace:GetServerTimeNow() + randomizer:NextNumber(135, 190)
local nextBrainEventAt = workspace:GetServerTimeNow() + randomizer:NextNumber(35, 55)
local lastMajorKind = nil
local requestCooldown = {}
local activeRequest = nil
local activeDurationScale = 1
local brainEventEndsAt = 0
local maximumPersonalStage = 0
local maximumPersonalProgress = 0
local loadedProfileCount = 0
local progressionEvents = nil
local progressionRequestConnection = nil
local progressionAncestryConnection = nil
local progressionResolvedEvent = nil
local progressionRegisterEvent = nil
local progressionAPI = nil
local lastModeReassertAt = 0
local nextProgressionRegistrationAt = 0
local progressionTeamEffects = {}
local activeTeamEffects = {}
local securedStormItems = {}
local tornadoStructuralDamageUnits = 0
local promptHoldBegins = setmetatable({}, { __mode = "k" })

local function now()
	return workspace:GetServerTimeNow()
end

local function invokeCampaign(operation, ...)
	local arguments = table.pack(...)
	local packed = table.pack(pcall(function()
		return campaignAPI:Invoke(operation, table.unpack(arguments, 1, arguments.n))
	end))
	if not packed[1] then
		warn("[CooperCrisis] Family API " .. tostring(operation) .. " failed: " .. tostring(packed[2]))
		return false, nil, tostring(packed[2])
	end
	return true, table.unpack(packed, 2, packed.n)
end

local function familyMode()
	return tostring(campaignState:GetAttribute("Mode") or "")
end

local function familySnapshot(player)
	if not player or player.Parent ~= Players then
		return nil
	end
	local callOK, result = invokeCampaign("GetSnapshot", player)
	if callOK and type(result) == "table" and result.loaded == true then
		return result
	end
	return nil
end

local function sanitizeTeamEffects(raw)
	raw = type(raw) == "table" and raw or {}
	return {
		StormDamageMultiplier = math.clamp(tonumber(raw.StormDamageMultiplier) or 1, 0.25, 2),
		LooseItemProtectionChance = math.clamp(tonumber(raw.LooseItemProtectionChance) or 0, 0, 0.9),
		StormLockerCapacity = math.clamp(math.floor((tonumber(raw.StormLockerCapacity) or 0) + 0.5), 0, 20),
		RepairCostMultiplier = math.clamp(tonumber(raw.RepairCostMultiplier) or 1, 0.25, 1),
		DESSuspicionMultiplier = math.clamp(tonumber(raw.DESSuspicionMultiplier) or 1, 0.25, 2),
	}
end

local function currentTeamEffects()
	return if activeKind then activeTeamEffects else progressionTeamEffects
end

local function stormLockerCapacity()
	local bonus = math.max(0, math.floor((tonumber(currentTeamEffects().StormLockerCapacity) or 0) + 0.5))
	return BASE_STORM_LOCKER_CAPACITY + bonus
end

local function stormLockerUsed()
	local count = 0
	for item in pairs(securedStormItems) do
		if item.Parent and item:GetAttribute("StormSecured") == true and item:GetAttribute("StormSecureMethod") == "Locker" then
			count += 1
		else
			securedStormItems[item] = nil
		end
	end
	return count
end

local function refreshProgressionTeamEffects()
	if not progressionAPI or not progressionAPI.Parent then
		progressionTeamEffects = sanitizeTeamEffects(nil)
		return
	end
	local ok, result = pcall(function()
		return progressionAPI:Invoke("GetTeamEffects")
	end)
	progressionTeamEffects = sanitizeTeamEffects(ok and result or nil)
end

local function refreshPersonalProgress()
	local stage = 0
	local progress = 0
	local loaded = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = familySnapshot(player)
		if profile then
			loaded += 1
			stage = math.max(stage, math.clamp(math.floor((tonumber(profile.machineStage) or 0) + 0.5), 0, 100))
			progress = math.max(progress, math.clamp(math.floor((tonumber(profile.machineProgress) or 0) + 0.5), 0, 100))
		end
	end
	maximumPersonalStage = stage
	maximumPersonalProgress = progress
	loadedProfileCount = loaded
	refreshProgressionTeamEffects()
end

local function adjustAllowance(player, delta, reason)
	if not player or player.Parent ~= Players then
		return false, "Player left"
	end
	local numericDelta = tonumber(delta) or 0
	delta = if numericDelta >= 0 then math.floor(numericDelta + 0.5) else math.ceil(numericDelta - 0.5)
	if delta == 0 then
		return true
	end
	local callOK, changed, detail = invokeCampaign("AdjustCurrency", player, delta, reason)
	return callOK and changed == true, detail
end

local function adjustOptionalStability(delta, reason, player)
	if campaignState:GetAttribute("SupportsStability") ~= true then
		return false, "Family foundation does not advertise shared stability"
	end
	local callOK, result = invokeCampaign("AdjustStability", delta, reason, player)
	return callOK and type(result) == "number", result
end

local function reportFamilyAction(player, eventKey, metadata)
	local callOK, accepted = invokeCampaign("ReportAction", player, eventKey, metadata)
	return callOK and accepted == true
end

local function snapshot()
	return {
		kind = activeKind or "None",
		phase = activePhase,
		phaseEndsAt = phaseEndsAt,
		reason = activeReason,
		suspicion = suspicion,
		desScore = desScore,
		desTarget = 4,
		desRoutes = table.clone(desRoutes),
		nextMajorAt = nextMajorAt,
		campaignMode = familyMode(),
		maximumPersonalStage = maximumPersonalStage,
		maximumPersonalProgress = maximumPersonalProgress,
		loadedProfileCount = loadedProfileCount,
		familySupportsStability = campaignState:GetAttribute("SupportsStability") == true,
		progressionConnected = progressionEvents ~= nil,
		brainEventEndsAt = brainEventEndsAt,
		externalRunId = activeRequest and activeRequest.runId or nil,
		finaleOwned = activeRequest and activeRequest.finale == true or false,
		teamEffects = table.clone(activeTeamEffects),
		stormLockerCapacity = stormLockerCapacity(),
		stormLockerUsed = stormLockerUsed(),
	}
end

local function writeState()
	state:SetAttribute("ControllerVersion", CONTROLLER_VERSION)
	state:SetAttribute("ActiveKind", activeKind or "None")
	state:SetAttribute("Phase", activePhase)
	state:SetAttribute("PhaseEndsAt", phaseEndsAt)
	state:SetAttribute("Reason", activeReason)
	state:SetAttribute("Suspicion", suspicion)
	state:SetAttribute("DESScore", desScore)
	state:SetAttribute("DESTarget", 4)
	state:SetAttribute("NextMajorAt", nextMajorAt)
	state:SetAttribute("CampaignMode", familyMode())
	state:SetAttribute("FamilyContract", "PersonalV2")
	state:SetAttribute("FamilySupportsStability", campaignState:GetAttribute("SupportsStability") == true)
	state:SetAttribute("MaximumPersonalStage", maximumPersonalStage)
	state:SetAttribute("MaximumPersonalProgress", maximumPersonalProgress)
	state:SetAttribute("LoadedProfileCount", loadedProfileCount)
	state:SetAttribute("ProgressionConnected", progressionEvents ~= nil)
	state:SetAttribute("BrainEventActive", brainEventEndsAt > now())
	state:SetAttribute("BrainEventEndsAt", brainEventEndsAt)
	state:SetAttribute("ExternalRunId", activeRequest and activeRequest.runId or "")
	state:SetAttribute("FinaleOwned", activeRequest and activeRequest.finale == true or false)
	state:SetAttribute("StormLockerCapacity", stormLockerCapacity())
	state:SetAttribute("StormLockerUsed", stormLockerUsed())
	state:SetAttribute("ServerTime", now())
end

local function broadcast(kind, payload)
	payload = payload or {}
	payload.kind = kind
	payload.serverTime = now()
	eventRemote:FireAllClients(payload)
end

local function setWorldEffects(tornadoEnabled, inspectorsEnabled)
	local emitter = tornadoVisual:FindFirstChildWhichIsA("ParticleEmitter", true)
	if emitter then
		emitter.Enabled = tornadoEnabled
	end
	for _, descendant in ipairs(inspectors:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = inspectorsEnabled and (descendant.Name == "Hitbox" and 1 or 0) or 1
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = inspectorsEnabled
		end
	end
end

local function setCampaignMode(mode, reason)
	local callOK, changed, detail = invokeCampaign("SetMode", mode, reason)
	if not callOK or changed ~= true then
		warn("[CooperCrisis] Family foundation rejected SetMode(" .. tostring(mode) .. "): " .. tostring(detail))
		return false
	end
	return true
end

local function scaledDuration(baseDuration)
	return math.max(1.5, baseDuration * activeDurationScale)
end

local function setPhase(name, duration, message)
	activePhase = name
	phaseEndsAt = now() + duration
	writeState()
	broadcast("Phase", {
		crisis = activeKind,
		phase = name,
		phaseEndsAt = phaseEndsAt,
		message = message,
		desScore = desScore,
		desTarget = 4,
	})
end

local function playerRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function promptWorldPosition(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	local part = parent and parent:FindFirstAncestorWhichIsA("BasePart")
	return part and part.Position or nil
end

local function playerInteractionSpeed(player)
	return math.clamp(tonumber(player:GetAttribute("CooperInteractionSpeedMultiplier")) or 1, 1, 2)
end

local function connectAuthoritativePrompt(prompt, handler)
	local baseHoldDuration = math.max(0, tonumber(prompt:GetAttribute("CooperBaseHoldDuration")) or prompt.HoldDuration)
	prompt:SetAttribute("CooperCrisisInteraction", true)
	prompt:SetAttribute("CooperBaseHoldDuration", baseHoldDuration)
	local begins = {}
	promptHoldBegins[prompt] = begins
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if player and player.Parent == Players then
			begins[player] = now()
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		local startedAt = begins[player]
		task.delay(0.75, function()
			if begins[player] == startedAt then
				begins[player] = nil
			end
		end)
	end)
	prompt.Triggered:Connect(function(player)
		if not player or player.Parent ~= Players or not prompt.Enabled then
			return
		end
		local rootPart = playerRoot(player)
		local position = promptWorldPosition(prompt)
		if not rootPart or not position or (rootPart.Position - position).Magnitude > prompt.MaxActivationDistance + 3 then
			return
		end
		if baseHoldDuration > 0.05 then
			local startedAt = begins[player]
			begins[player] = nil
			local requiredDuration = baseHoldDuration / playerInteractionSpeed(player)
			if not startedAt or now() - startedAt + INTERACTION_HOLD_TOLERANCE < requiredDuration then
				broadcast("Personal", {
					playerUserId = player.UserId,
					message = "Keep holding the interaction until the progress ring finishes.",
				})
				return
			end
		end
		handler(player)
	end)
end

local function isOutdoors(rootPart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rootPart.Parent, world }
	local result = workspace:Raycast(rootPart.Position, Vector3.new(0, 40, 0), params)
	return result == nil
end

local function pushOutdoorPlayers(multiplier)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = playerRoot(player)
		if root and isOutdoors(root) then
			local direction = Vector3.new(randomizer:NextNumber(-1, 1), 0.28, randomizer:NextNumber(-1, 1))
			if direction.Magnitude > 0.1 then
				direction = direction.Unit
			end
			root.AssemblyLinearVelocity += direction * multiplier
		end
	end
end

local function objectPivot(object)
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("Tool") then
		local handle = object:FindFirstChild("Handle")
		return handle and handle:IsA("BasePart") and handle.CFrame or nil
	elseif object:IsA("BasePart") then
		return object.CFrame
	end
	return nil
end

local function moveObject(object, target)
	if object:IsA("Model") then
		object:PivotTo(target)
	elseif object:IsA("Tool") then
		local handle = object:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = target
		end
	elseif object:IsA("BasePart") then
		object.CFrame = target
	end
end

local function eligibleEquipment()
	local found = {}
	local seen = {}
	for _, descendant in ipairs(environment:GetDescendants()) do
		if descendant:GetAttribute("StormEligible") == true or descendant:GetAttribute("TornadoEligible") == true then
			local object = descendant
			while object.Parent and object.Parent ~= environment and object.Parent:GetAttribute("StormEligible") == true do
				object = object.Parent
			end
			if not seen[object]
				and object:IsDescendantOf(workspace)
				and object:GetAttribute("Installed") ~= true
				and object:GetAttribute("MachineInstalled") ~= true
				and object:GetAttribute("StormSecured") ~= true
				and object:GetAttribute("TornadoDisplaced") ~= true
				and object:GetAttribute("DESConfiscated") ~= true
				and objectPivot(object)
			then
				seen[object] = true
				table.insert(found, object)
			end
		end
	end
	return found
end

local function aftermathPoints()
	local points = {}
	for _, child in ipairs(aftermathSpawns:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	table.sort(points, function(a, b) return a.Name < b.Name end)
	return points
end

local function scatterEquipment(limit)
	local candidates = eligibleEquipment()
	local points = aftermathPoints()
	if #candidates == 0 or #points == 0 then
		return 0
	end
	for index = #candidates, 2, -1 do
		local swap = randomizer:NextInteger(1, index)
		candidates[index], candidates[swap] = candidates[swap], candidates[index]
	end
	local protection = math.clamp(tonumber(activeTeamEffects.LooseItemProtectionChance) or 0, 0, 0.9)
	local protectedLimit = math.max(0, math.floor(limit * (1 - protection) + 0.5))
	local count = math.min(protectedLimit, #candidates, #points)
	for index = 1, count do
		local object = candidates[index]
		local original = objectPivot(object)
		if original then
			table.insert(movedByTornado, { object = object, original = original })
			object:SetAttribute("TornadoDisplaced", true)
			object:SetAttribute("RecoveryLocation", points[index].Name)
			moveObject(object, points[index].CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, randomizer:NextNumber(-math.pi, math.pi), 0))
		end
	end
	return count
end

local function recoveryPromptParent(object)
	if object:IsA("Model") then
		return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
	elseif object:IsA("Tool") then
		return object:FindFirstChild("Handle")
	elseif object:IsA("BasePart") then
		return object
	end
	return nil
end

local function makeRecoveryMission(record)
	local object = record.object
	if not object or not object.Parent or record.recovered then
		return
	end
	local parent = recoveryPromptParent(object)
	if not parent or not parent:IsA("BasePart") then
		return
	end
	local oldPrompt = parent:FindFirstChild("TornadoRecoveryPrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TornadoRecoveryPrompt"
	prompt.ActionText = "RECOVER EQUIPMENT"
	prompt.ObjectText = object.Name
	prompt.HoldDuration = 1.25
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = parent
	connectAuthoritativePrompt(prompt, function(player)
		if record.recovered or not object.Parent or object:GetAttribute("TornadoDisplaced") ~= true then
			return
		end
		record.recovered = true
		moveObject(object, record.original)
		object:SetAttribute("TornadoDisplaced", nil)
		object:SetAttribute("RecoveryMission", nil)
		object:SetAttribute("RecoveryLocation", nil)
		prompt:Destroy()
		local rewarded = adjustAllowance(player, RECOVERY_ALLOWANCE_REWARD, "Tornado equipment recovered")
		adjustOptionalStability(3, "Tornado equipment recovered", player)
		broadcast("Recovered", {
			playerUserId = player.UserId,
			item = object.Name,
			allowanceReward = rewarded and RECOVERY_ALLOWANCE_REWARD or 0,
		})
	end)
end

local function restoreTornadoRecord(record)
	local object = record.object
	if not object or not object.Parent then
		return
	end
	local parent = recoveryPromptParent(object)
	local recoveryPrompt = parent and parent:FindFirstChild("TornadoRecoveryPrompt")
	if recoveryPrompt and recoveryPrompt:IsA("ProximityPrompt") then
		recoveryPrompt:Destroy()
	end
	if object:GetAttribute("TornadoDisplaced") == true then
		moveObject(object, record.original)
	end
	object:SetAttribute("TornadoDisplaced", nil)
	object:SetAttribute("RecoveryMission", nil)
	object:SetAttribute("RecoveryLocation", nil)
end

local function settleTornadoRepairs()
	local unresolvedItems = 0
	for _, record in ipairs(movedByTornado) do
		if not record.recovered then
			unresolvedItems += 1
			restoreTornadoRecord(record)
		end
	end
	local repairUnits = tornadoStructuralDamageUnits + unresolvedItems
	local baseCost = repairUnits * TORNADO_REPAIR_COST_PER_UNIT
	local multiplier = math.clamp(tonumber(activeTeamEffects.RepairCostMultiplier) or 1, 0.25, 1)
	local personalCost = math.max(0, math.floor(baseCost * multiplier + 0.5))
	local charges = {}
	local totalCharged = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = familySnapshot(player)
		if profile then
			local allowance = math.max(0, math.floor(tonumber(profile.allowance) or 0))
			local requestedCharge = math.min(personalCost, allowance)
			local charged = 0
			if requestedCharge > 0 and adjustAllowance(player, -requestedCharge, "Tornado aftermath repairs") then
				charged = requestedCharge
				totalCharged += charged
			end
			table.insert(charges, { userId = player.UserId, charged = charged })
		end
	end
	broadcast("TornadoRepairs", {
		repairUnits = repairUnits,
		unresolvedItems = unresolvedItems,
		structuralDamageUnits = tornadoStructuralDamageUnits,
		baseCost = baseCost,
		personalCost = personalCost,
		discountSavings = math.max(0, baseCost - personalCost),
		repairCostMultiplier = multiplier,
		totalCharged = totalCharged,
		charges = charges,
	})
	table.clear(movedByTornado)
	tornadoStructuralDamageUnits = 0
end

local function garageIsOpen()
	local garage = environment:FindFirstChild("DetachedGarage")
	local door = garage and garage:FindFirstChild("InteractiveSectionalGarageDoor")
	return door ~= nil and door:GetAttribute("IsOpen") == true
end

local function waitPhase(token, duration)
	local fallbackDeadline = now() + duration
	while crisisToken == token and activeKind and now() < math.min(fallbackDeadline, phaseEndsAt) do
		state:SetAttribute("ServerTime", now())
		task.wait(0.25)
	end
	return crisisToken == token and activeKind ~= nil
end

local function cancelBrainEvent(reason)
	if brainEventEndsAt <= 0 then
		return false
	end
	brainEventEndsAt = 0
	local props = world:FindFirstChild("TemporaryEventProps")
	if props then
		props:Destroy()
	end
	state:SetAttribute("BrainEventActive", false)
	state:SetAttribute("BrainEventEndsAt", 0)
	broadcast("BrainEventEnded", { reason = reason or "Interrupted" })
	return true
end

local function successfulOutcome(outcome)
	return outcome == "Survived" or outcome == "Passed" or outcome == "Succeeded" or outcome == "StudioFastResolve"
end

local function resolveCrisis(outcome, reason)
	if not activeKind then
		return false
	end
	local completedKind = activeKind
	local completedRequest = activeRequest
	local success = successfulOutcome(outcome)
	if completedKind == "Tornado" then
		for _, record in ipairs(movedByTornado) do
			if not record.recovered then
				restoreTornadoRecord(record)
			end
		end
		table.clear(movedByTornado)
		tornadoStructuralDamageUnits = 0
	end
	crisisToken += 1
	activeKind = nil
	activePhase = "Idle"
	activeReason = reason or outcome
	phaseEndsAt = 0
	activeRequest = nil
	activeDurationScale = 1
	activeTeamEffects = {}
	setWorldEffects(false, false)
	permitPrompt.Enabled = false
	concealPrompt.Enabled = false
	distractionPrompt.Enabled = false
	local currentMode = familyMode()
	if not (completedRequest and completedRequest.finale == true)
		and currentMode ~= CAMPAIGN_MODE.Panic
		and currentMode ~= CAMPAIGN_MODE.Finale
		and currentMode ~= CAMPAIGN_MODE.Victory
	then
		setCampaignMode(CAMPAIGN_MODE.Normal, reason or (completedKind .. " resolved"))
	end
	for item in pairs(securedStormItems) do
		if item.Parent then
			item:SetAttribute("StormSecured", nil)
			item:SetAttribute("StormSecuredBy", nil)
			item:SetAttribute("StormSecuredAt", nil)
			item:SetAttribute("StormSecureMethod", nil)
		end
	end
	table.clear(securedStormItems)
	for _, descendant in ipairs(environment:GetDescendants()) do
		if descendant:GetAttribute("StormSecured") == true then
			descendant:SetAttribute("StormSecured", nil)
			descendant:SetAttribute("StormSecuredBy", nil)
			descendant:SetAttribute("StormSecuredAt", nil)
			descendant:SetAttribute("StormSecureMethod", nil)
		end
	end
	nextMajorAt = now() + randomizer:NextNumber(230, 360)
	writeState()
	broadcast("Resolved", { crisis = completedKind, outcome = outcome, success = success, reason = reason or "" })
	resolvedEvent:Fire(completedKind, outcome, reason or "")
	if completedRequest and completedRequest.runId and progressionResolvedEvent and progressionResolvedEvent.Parent then
		progressionResolvedEvent:Fire(completedKind, completedRequest.runId, success, reason or outcome)
	end
	return true
end

local function runTornado(token)
	for index, phase in ipairs(TORNADO_PHASES) do
		if crisisToken ~= token or activeKind ~= "Tornado" then
			return
		end
		local duration = scaledDuration(phase.duration)
		setPhase(phase.name, duration, phase.message)
		if phase.name == "Warning" then
			setWorldEffects(true, false)
		elseif phase.name == "ImpactOne" or phase.name == "ImpactTwo" then
			local displaced = scatterEquipment(phase.name == "ImpactOne" and 2 or 3)
			local exposed = garageIsOpen()
			if exposed then
				tornadoStructuralDamageUnits += 1
			end
			if displaced > 0 or exposed then
				local multiplier = math.clamp(tonumber(activeTeamEffects.StormDamageMultiplier) or 1, 0.25, 2)
				adjustOptionalStability(-math.max(1, math.floor(10 * multiplier + 0.5)), "Tornado damage")
			end
			broadcast("TornadoImpact", { displaced = displaced, garageExposed = exposed })
			local impactDeadline = now() + duration
			while crisisToken == token and activeKind == "Tornado" and now() < impactDeadline do
				pushOutdoorPlayers(phase.name == "ImpactTwo" and 17 or 13)
				task.wait(1.2)
			end
			continue
		elseif phase.name == "Eye" then
			setWorldEffects(false, false)
		elseif phase.name == "Aftermath" then
			setWorldEffects(false, false)
			for _, record in ipairs(movedByTornado) do
				if record.object and record.object.Parent then
					record.object:SetAttribute("RecoveryMission", true)
					makeRecoveryMission(record)
				end
			end
		end
		if not waitPhase(token, duration) then
			return
		end
	end
	if crisisToken == token and activeKind == "Tornado" then
		settleTornadoRepairs()
	end
	if crisisToken == token and activeKind == "Tornado" then
		resolveCrisis("Survived", "The tornado passed")
	end
end

local function desEquipmentCandidates()
	local list = {}
	for _, object in ipairs(eligibleEquipment()) do
		if object:GetAttribute("SuspiciousTech") == true or object:GetAttribute("MachineEquipment") == true then
			table.insert(list, object)
		end
	end
	return list
end

local function confiscateEquipment(limit)
	local candidates = desEquipmentCandidates()
	local holdPart = evidenceHold:FindFirstChildWhichIsA("BasePart", true)
	if not holdPart then
		return 0
	end
	local count = math.min(limit, #candidates)
	for index = 1, count do
		local object = candidates[index]
		local original = objectPivot(object)
		if original then
			table.insert(confiscatedByDES, { object = object, original = original })
			object:SetAttribute("DESConfiscated", true)
			moveObject(object, holdPart.CFrame * CFrame.new((index - 1) * 2.2, 1.5, 0))
		end
	end
	return count
end

local function finishDES()
	local success = desScore >= 4
	local resolutionDuration = scaledDuration(DES_PHASES[4].duration)
	setPhase("Resolution", resolutionDuration, success and "D.E.S. INSPECTION PASSED" or "D.E.S. FOUND SUSPICIOUS TECHNOLOGY")
	if success then
		local rewarded = 0
		local rewardedUserIds = {}
		for player in pairs(desParticipants) do
			if player.Parent == Players and adjustAllowance(player, DES_ALLOWANCE_REWARD, "D.E.S. inspection passed") then
				rewarded += 1
				table.insert(rewardedUserIds, player.UserId)
			end
		end
		suspicion = math.max(0, suspicion - 35)
		broadcast("DESAllowance", {
			outcome = "Reward",
			amount = DES_ALLOWANCE_REWARD,
			playerCount = rewarded,
			playerUserIds = rewardedUserIds,
		})
	else
		local count = confiscateEquipment(2)
		adjustOptionalStability(-10, "D.E.S. discovered suspicious technology")
		local fined = 0
		local totalFine = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = familySnapshot(player)
			local allowance = profile and math.max(0, math.floor(tonumber(profile.allowance) or 0)) or 0
			local deduction = math.min(DES_ALLOWANCE_FINE, allowance)
			if deduction > 0 and adjustAllowance(player, -deduction, "D.E.S. inspection fine") then
				fined += 1
				totalFine += deduction
			end
		end
		local reactorLocked = false
		if progressionAPI and progressionAPI.Parent then
			local ok, accepted = pcall(function()
				return progressionAPI:Invoke("LockReactorUntil", now() + 45, "D.E.S. confiscation safety lock")
			end)
			reactorLocked = ok and accepted == true
		end
		suspicion = math.max(15, suspicion - 20)
		broadcast("Confiscated", { count = count, releaseAt = now() + 45, finedPlayers = fined, totalAllowanceFine = totalFine, reactorLocked = reactorLocked })
		task.delay(45, function()
			for _, record in ipairs(confiscatedByDES) do
				if record.object and record.object.Parent and record.object:GetAttribute("DESConfiscated") == true then
					record.object:SetAttribute("DESConfiscated", nil)
					moveObject(record.object, record.original)
				end
			end
			table.clear(confiscatedByDES)
		end)
	end
	writeState()
	task.wait(resolutionDuration)
	if activeKind == "DESRaid" then
		resolveCrisis(success and "Passed" or "Failed", success and "The inspectors left satisfied" or "The inspectors issued a fine")
	end
end

local function runDES(token)
	for index = 1, 3 do
		local phase = DES_PHASES[index]
		if crisisToken ~= token or activeKind ~= "DESRaid" then
			return
		end
		local duration = scaledDuration(phase.duration)
		setPhase(phase.name, duration, phase.message)
		if phase.name == "Approach" then
			setWorldEffects(false, true)
		elseif phase.name == "Inspection" then
			permitPrompt.Enabled = true
			concealPrompt.Enabled = true
			distractionPrompt.Enabled = true
		end
		if not waitPhase(token, duration) then
			return
		end
		if phase.name == "Inspection" and desScore >= 4 then
			break
		end
	end
	permitPrompt.Enabled = false
	concealPrompt.Enabled = false
	distractionPrompt.Enabled = false
	if crisisToken == token and activeKind == "DESRaid" then
		finishDES()
	end
end

local function startCrisis(kind, reason, options)
	options = type(options) == "table" and options or {}
	if activeKind then
		return false, "A crisis is already active"
	end
	if kind ~= "Tornado" and kind ~= "DESRaid" then
		return false, "Unknown crisis kind"
	end
	local currentMode = familyMode()
	local externallyOwned = type(options.runId) == "string" and options.runId ~= ""
	local finaleOwned = options.finale == true and externallyOwned
	if finaleOwned then
		if currentMode ~= CAMPAIGN_MODE.Finale then
			return false, "Finale crisis request requires Finale mode"
		end
	elseif currentMode ~= CAMPAIGN_MODE.Normal then
		return false, "Campaign mode " .. tostring(currentMode) .. " does not allow an autonomous crisis"
	end
	local deadline = tonumber(options.deadline) or 0
	if finaleOwned and deadline > 0 then
		local baseDuration = kind == "Tornado" and 75 or 68
		local available = deadline - now() - 2
		if available < 10 then
			return false, "Finale crisis deadline is too short"
		end
		activeDurationScale = math.clamp(available / baseDuration, 0.35, 1)
	else
		activeDurationScale = 1
	end
	activeTeamEffects = sanitizeTeamEffects(options.teamEffects or progressionTeamEffects)
	if not finaleOwned and not setCampaignMode(kind == "Tornado" and CAMPAIGN_MODE.Tornado or CAMPAIGN_MODE.DESRaid, reason) then
		activeDurationScale = 1
		activeTeamEffects = {}
		return false, "Family foundation rejected crisis mode"
	end
	cancelBrainEvent("Major crisis started")
	activeKind = kind
	activeReason = reason or "Event director"
	activePhase = "Starting"
	phaseEndsAt = now()
	activeRequest = externallyOwned and {
		runId = options.runId,
		finale = finaleOwned,
		deadline = deadline,
	} or nil
	crisisToken += 1
	local token = crisisToken
	lastMajorKind = kind
	if kind == "Tornado" then
		table.clear(movedByTornado)
		tornadoStructuralDamageUnits = 0
		task.spawn(runTornado, token)
	else
		desScore = 0
		desRoutes = { Legal = 0, Concealment = 0, Distraction = 0 }
		desContributors = {}
		desParticipants = {}
		task.spawn(runDES, token)
	end
	writeState()
	broadcast("Started", { crisis = kind, reason = activeReason, finale = finaleOwned, deadline = deadline })
	return true, kind
end

local function heldStormItem(player)
	local character = player.Character
	for _, container in ipairs({ character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool")
					and child:GetAttribute("StormSecured") ~= true
					and (child:GetAttribute("StormEligible") == true or child:GetAttribute("TornadoEligible") == true)
				then
					return child
				end
			end
		end
	end
	return nil
end

local function nearestStormItem(player, origin, radius)
	local root = playerRoot(player)
	if not root or (root.Position - origin).Magnitude > radius + 8 then
		return nil
	end
	local best, bestDistance
	for _, object in ipairs(eligibleEquipment()) do
		local pivot = objectPivot(object)
		if pivot then
			local distance = (pivot.Position - origin).Magnitude
			if distance <= radius and (not bestDistance or distance < bestDistance) then
				best, bestDistance = object, distance
			end
		end
	end
	return best
end

connectAuthoritativePrompt(securePrompt, function(player)
	local used = stormLockerUsed()
	local capacity = stormLockerCapacity()
	if used >= capacity then
		broadcast("Personal", {
			playerUserId = player.UserId,
			message = string.format("The Storm Locker is full (%d/%d). Upgrade it for more protected slots.", used, capacity),
		})
		return
	end
	local item = heldStormItem(player) or nearestStormItem(player, stormLocker:GetPivot().Position, 14)
	if not item then
		broadcast("Personal", { playerUserId = player.UserId, message = "Bring a loose storm item to the locker first." })
		return
	end
	item:SetAttribute("StormSecured", true)
	item:SetAttribute("StormSecuredBy", player.UserId)
	item:SetAttribute("StormSecuredAt", now())
	item:SetAttribute("StormSecureMethod", "Locker")
	securedStormItems[item] = true
	used = stormLockerUsed()
	writeState()
	broadcast("Secured", {
		playerUserId = player.UserId,
		item = item.Name,
		method = "Locker",
		lockerUsed = used,
		lockerCapacity = capacity,
	})
	reportFamilyAction(player, "StormItemSecured", { method = "Locker", item = item.Name })
end)

connectAuthoritativePrompt(strapPrompt, function(player)
	local item = nearestStormItem(player, strapStation:GetPivot().Position, 18)
	if not item then
		broadcast("Personal", { playerUserId = player.UserId, message = "No unsecured equipment is close enough for a storm strap." })
		return
	end
	item:SetAttribute("StormSecured", true)
	item:SetAttribute("StormSecuredBy", player.UserId)
	item:SetAttribute("StormSecuredAt", now())
	item:SetAttribute("StormSecureMethod", "StormStrap")
	broadcast("Secured", { playerUserId = player.UserId, item = item.Name, method = "StormStrap" })
	reportFamilyAction(player, "StormItemSecured", { method = "StormStrap", item = item.Name })
end)

local function contributeDES(player, route, amount)
	if activeKind ~= "DESRaid" or activePhase ~= "Inspection" then
		return
	end
	local key = tostring(player.UserId) .. ":" .. route
	if desContributors[key] then
		broadcast("Personal", { playerUserId = player.UserId, message = "You already completed that inspection route." })
		return
	end
	desContributors[key] = true
	desParticipants[player] = true
	desRoutes[route] += amount
	desScore = math.min(4, desScore + amount)
	state:SetAttribute("DESScore", desScore)
	broadcast("DESProgress", {
		playerUserId = player.UserId,
		route = route,
		amount = amount,
		score = desScore,
		target = 4,
	})
	if desScore >= 4 then
		phaseEndsAt = math.min(phaseEndsAt, now() + 0.5)
	end
end

connectAuthoritativePrompt(permitPrompt, function(player)
	contributeDES(player, "Legal", 2)
end)
connectAuthoritativePrompt(concealPrompt, function(player)
	contributeDES(player, "Concealment", 1)
end)
connectAuthoritativePrompt(distractionPrompt, function(player)
	contributeDES(player, "Distraction", 1)
end)

local function createEventProp(eventDefinition)
	local eventProps = world:FindFirstChild("TemporaryEventProps")
	if not eventProps then
		eventProps = Instance.new("Folder")
		eventProps.Name = "TemporaryEventProps"
		eventProps.Parent = world
	end
	local part = nil
	if eventDefinition.id == "GiantCube" then
		part = Instance.new("Part")
		part.Name = "GiantPuzzleCube"
		part.Size = Vector3.new(8, 8, 8)
		part.Color = Color3.fromRGB(245, 205, 48)
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(5, 8, -10) * CFrame.Angles(0.3, 0.5, 0.1)
	elseif eventDefinition.id == "GiantRemote" then
		part = Instance.new("Part")
		part.Name = "GiantTVRemote"
		part.Size = Vector3.new(3, 1, 9)
		part.Color = Color3.fromRGB(35, 35, 38)
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(18, 5, 5) * CFrame.Angles(0, 0.4, 0.25)
	elseif eventDefinition.id == "RemoteDuplication" then
		for index = 1, 12 do
			local clone = Instance.new("Part")
			clone.Name = "DefinitelyTheRealRemote"
			clone.Size = Vector3.new(0.45, 0.18, 1.2)
			clone.Color = Color3.fromRGB(35, 35, 38)
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
			clone.CFrame = CFrame.new(10 + randomizer:NextNumber(-4, 4), 8 + index * 0.2, 26 + randomizer:NextNumber(-4, 4))
			clone.Parent = eventProps
		end
	end
	if part then
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Parent = eventProps
	end
	task.delay(eventDefinition.duration, function()
		if part and part.Parent then
			part:Destroy()
		end
		if eventDefinition.id == "RemoteDuplication" then
			for _, child in ipairs(eventProps:GetChildren()) do
				if child.Name == "DefinitelyTheRealRemote" then
					child:Destroy()
				end
			end
		end
	end)
end

local function runBrainEvent(eventId)
	if activeKind or brainEventEndsAt > now() or familyMode() ~= CAMPAIGN_MODE.Normal then
		return false, "Brain event is suppressed by the current campaign state"
	end
	local selected = nil
	if type(eventId) == "string" then
		for _, entry in ipairs(BRAIN_EVENTS) do
			if entry.id == eventId then
				selected = entry
				break
			end
		end
	end
	selected = selected or BRAIN_EVENTS[randomizer:NextInteger(1, #BRAIN_EVENTS)]
	brainEventEndsAt = now() + selected.duration
	state:SetAttribute("LastBrainEvent", selected.id)
	state:SetAttribute("LastBrainEventAt", now())
	state:SetAttribute("BrainEventActive", true)
	state:SetAttribute("BrainEventEndsAt", brainEventEndsAt)
	broadcast("BrainEvent", {
		eventId = selected.id,
		title = selected.title,
		subtitle = selected.subtitle,
		duration = selected.duration,
		seed = randomizer:NextInteger(1, 1000000),
	})
	createEventProp(selected)
	local expectedEnd = brainEventEndsAt
	task.delay(selected.duration, function()
		if brainEventEndsAt == expectedEnd then
			cancelBrainEvent("Completed")
		end
	end)
	return true
end

local function disconnectProgressionEvents()
	if progressionRequestConnection then
		progressionRequestConnection:Disconnect()
		progressionRequestConnection = nil
	end
	if progressionAncestryConnection then
		progressionAncestryConnection:Disconnect()
		progressionAncestryConnection = nil
	end
	progressionEvents = nil
	progressionResolvedEvent = nil
	progressionRegisterEvent = nil
	progressionAPI = nil
	progressionTeamEffects = sanitizeTeamEffects(nil)
	writeState()
end

local function connectProgressionEvents()
	local folder = ServerScriptService:FindFirstChild("CooperProgressionServerEvents")
	if not folder or not folder:IsA("Folder") then
		if progressionEvents then
			disconnectProgressionEvents()
		end
		return false
	end
	if progressionEvents == folder and progressionRequestConnection and progressionRequestConnection.Connected then
		return true
	end
	local registerEvent = folder:FindFirstChild("RegisterCrisis")
	local requestEvent = folder:FindFirstChild("CrisisRequest")
	local resolved = folder:FindFirstChild("CrisisResolved")
	local progressionFunction = folder:FindFirstChild("API")
	if not registerEvent or not registerEvent:IsA("BindableEvent")
		or not requestEvent or not requestEvent:IsA("BindableEvent")
		or not resolved or not resolved:IsA("BindableEvent")
	then
		return false
	end
	disconnectProgressionEvents()
	progressionEvents = folder
	progressionResolvedEvent = resolved
	progressionRegisterEvent = registerEvent
	progressionAPI = progressionFunction and progressionFunction:IsA("BindableFunction") and progressionFunction or nil
	refreshProgressionTeamEffects()
	progressionRequestConnection = requestEvent.Event:Connect(function(crisisId, runId, payload)
		if (crisisId ~= "Tornado" and crisisId ~= "DESRaid") or type(runId) ~= "string" or runId == "" or #runId > 160 then
			return
		end
		payload = type(payload) == "table" and payload or {}
		if payload.finale ~= true then
			-- Progression may request a reactor-triggered D.E.S. raid outside the finale.
			local started, failure = startCrisis(crisisId, "Progression event request", {
				runId = runId,
				teamEffects = payload.teamEffects,
			})
			if started and type(payload.suspicion) == "number" then
				suspicion = math.clamp(math.floor(payload.suspicion + 0.5), 0, 100)
				writeState()
			end
			if not started then
				resolved:Fire(crisisId, runId, false, tostring(failure))
			end
			return
		end
		local started, failure = startCrisis(crisisId, "Finale sequence", {
			finale = true,
			runId = runId,
			deadline = tonumber(payload.deadline) or 0,
			teamEffects = payload.teamEffects,
		})
		if not started then
			resolved:Fire(crisisId, runId, false, tostring(failure))
		end
	end)
	progressionAncestryConnection = folder.AncestryChanged:Connect(function(_, parent)
		if parent == nil and progressionEvents == folder then
			disconnectProgressionEvents()
		end
	end)
	progressionRegisterEvent:Fire("Tornado", true)
	progressionRegisterEvent:Fire("DESRaid", true)
	nextProgressionRegistrationAt = now() + 5
	writeState()
	return true
end

api.OnInvoke = function(operation, arg1, arg2)
	if operation == "IsAvailable" then
		return true, CONTROLLER_VERSION
	elseif operation == "GetSnapshot" then
		return snapshot()
	elseif operation == "GetCompatibility" then
		return {
			familyContract = "PersonalV2",
			requiredOperations = { "GetSnapshot(player)", "AdjustCurrency(player, delta)", "ReportAction(player, key, metadata)", "SetMode(mode, reason)" },
			optionalOperations = { "AdjustStability(delta, reason, player) when State.SupportsStability=true" },
			tornadoUnlockStage = TORNADO_UNLOCK_STAGE,
			desUnlockStage = DES_UNLOCK_STAGE,
			progressionConnected = progressionEvents ~= nil,
		}
	elseif operation == "Start" then
		return startCrisis(tostring(arg1), tostring(arg2 or "External crisis request"))
	elseif operation == "Resolve" then
		if not activeKind or (arg1 ~= nil and tostring(arg1) ~= activeKind) then
			return false
		end
		return resolveCrisis(tostring(arg2 or "External"), "External resolution")
	elseif operation == "SetSuspicion" and type(arg1) == "number" then
		suspicion = math.clamp(math.floor(arg1 + 0.5), 0, 100)
		writeState()
		return suspicion
	elseif operation == "AddSuspicion" and type(arg1) == "number" then
		suspicion = math.clamp(math.floor(suspicion + arg1 + 0.5), 0, 100)
		writeState()
		return suspicion
	elseif operation == "RunBrainEvent" then
		return runBrainEvent(if type(arg1) == "string" then arg1 else nil)
	elseif operation == "DebugFastResolve" and RunService:IsStudio() then
		return resolveCrisis("StudioFastResolve", "Studio runtime audit")
	end
	return nil
end

requestRemote.OnServerEvent:Connect(function(player, operation, payload)
	if type(operation) ~= "string" then
		return
	end
	local current = os.clock()
	if (requestCooldown[player] or 0) > current then
		return
	end
	requestCooldown[player] = current + 0.25
	if operation == "RequestSnapshot" then
		eventRemote:FireClient(player, { kind = "Snapshot", data = snapshot(), serverTime = now() })
	elseif RunService:IsStudio() and operation == "DebugStart" and (payload == "Tornado" or payload == "DESRaid") then
		startCrisis(payload, "Studio debug")
	elseif RunService:IsStudio() and operation == "DebugBrainEvent" then
		runBrainEvent(type(payload) == "string" and payload or nil)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	requestCooldown[player] = nil
	desParticipants[player] = nil
	for _, begins in pairs(promptHoldBegins) do
		begins[player] = nil
	end
end)

ServerScriptService.ChildAdded:Connect(function(child)
	if child.Name == "CooperProgressionServerEvents" then
		task.defer(connectProgressionEvents)
	end
end)

permitPrompt.Enabled = false
concealPrompt.Enabled = false
distractionPrompt.Enabled = false
setWorldEffects(false, false)
refreshPersonalProgress()
connectProgressionEvents()
writeState()

task.spawn(function()
	local nextProgressRefresh = 0
	while script.Parent do
		local current = now()
		state:SetAttribute("ServerTime", current)
		if current >= nextProgressRefresh then
			nextProgressRefresh = current + 2
			refreshPersonalProgress()
		end
		if not progressionEvents then
			connectProgressionEvents()
		elseif progressionRegisterEvent and progressionRegisterEvent.Parent and current >= nextProgressionRegistrationAt then
			-- BindableEvents do not queue. Repeat the idempotent registration so
			-- startup order cannot make Progression miss this director.
			progressionRegisterEvent:Fire("Tornado", true)
			progressionRegisterEvent:Fire("DESRaid", true)
			nextProgressionRegistrationAt = current + 10
		end
		local campaignMode = familyMode()

		if activeKind then
			local expectedMode = activeKind == "Tornado" and CAMPAIGN_MODE.Tornado or CAMPAIGN_MODE.DESRaid
			if activeRequest and activeRequest.finale == true then
				if campaignMode == CAMPAIGN_MODE.Panic or campaignMode == CAMPAIGN_MODE.Victory then
					resolveCrisis("Aborted", "A higher-priority campaign mode interrupted the finale crisis")
				elseif campaignMode ~= CAMPAIGN_MODE.Finale and current >= lastModeReassertAt then
					lastModeReassertAt = current + 1
					setCampaignMode(CAMPAIGN_MODE.Finale, "Finale crisis still active")
				end
				if activeKind and activeRequest and activeRequest.deadline > 0 and current >= activeRequest.deadline - 0.75 then
					resolveCrisis("Failed", "Finale crisis deadline expired")
				end
			elseif campaignMode == CAMPAIGN_MODE.Panic or campaignMode == CAMPAIGN_MODE.Finale or campaignMode == CAMPAIGN_MODE.Victory then
				resolveCrisis("Aborted", "Campaign mode changed to " .. campaignMode)
			elseif campaignMode ~= expectedMode and current >= lastModeReassertAt then
				lastModeReassertAt = current + 1
				if campaignMode == CAMPAIGN_MODE.Normal then
					setCampaignMode(expectedMode, activeKind .. " still active")
				else
					resolveCrisis("Aborted", "Another campaign mode took control")
				end
			end
		else
			if brainEventEndsAt > 0 and campaignMode ~= CAMPAIGN_MODE.Normal then
				cancelBrainEvent("Campaign mode changed to " .. campaignMode)
			end
			local suspicionMultiplier = math.clamp(tonumber(progressionTeamEffects.DESSuspicionMultiplier) or 1, 0.25, 2)
			local passiveSuspicion = math.floor(maximumPersonalProgress * 0.45 * suspicionMultiplier)
			if garageIsOpen() then
				passiveSuspicion += 15
			end
			local progressionRoot = ReplicatedStorage:FindFirstChild("CooperProgression")
			local progressionState = progressionRoot and progressionRoot:FindFirstChild("State")
			if progressionState and progressionState:IsA("Folder") then
				local reactorMode = progressionState:GetAttribute("ReactorMode")
				if reactorMode == "Fast" then
					passiveSuspicion += 12
				elseif reactorMode == "Ludicrous" then
					passiveSuspicion += 30
				end
			end
			suspicion = math.clamp(math.max(suspicion - 0.15, passiveSuspicion), 0, 100)

			if campaignMode == CAMPAIGN_MODE.Normal and loadedProfileCount > 0 and current >= nextBrainEventAt then
				runBrainEvent(nil)
				nextBrainEventAt = current + randomizer:NextNumber(42, 72)
			end

			if campaignMode == CAMPAIGN_MODE.Normal
				and loadedProfileCount > 0
				and current >= nextMajorAt
				and maximumPersonalStage >= TORNADO_UNLOCK_STAGE
			then
				local kind
				if maximumPersonalStage >= DES_UNLOCK_STAGE and suspicion >= 45 and lastMajorKind ~= "DESRaid" then
					kind = "DESRaid"
				elseif lastMajorKind == "Tornado" and maximumPersonalStage >= DES_UNLOCK_STAGE then
					kind = "DESRaid"
				else
					kind = "Tornado"
				end
				local started = startCrisis(kind, "Campaign event director")
				if not started then
					nextMajorAt = current + 30
				end
			end
		end

		writeState()
		task.wait(1)
	end
end)

print("[CooperCrisis] Personal-family-compatible tornado, D.E.S., and chaos director ready (" .. CONTROLLER_VERSION .. ")")
