--!nonstrict
-- Server-authoritative campaign foundation for the Cooper house.
-- Install as ServerScriptService.CooperGame.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ROOT_TIMEOUT = 20
local gameRoot = ReplicatedStorage:WaitForChild("CooperGame", ROOT_TIMEOUT)
assert(gameRoot, "ReplicatedStorage.CooperGame was not installed")

local configModule = gameRoot:WaitForChild("Config", ROOT_TIMEOUT)
assert(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config was not installed")
local Config = require(configModule)

local stateFolder = gameRoot:WaitForChild(Config.WorldStateName, ROOT_TIMEOUT)
local remotes = gameRoot:WaitForChild(Config.RemotesName, ROOT_TIMEOUT)
assert(stateFolder and stateFolder:IsA("Folder"), "CooperGame.State was not installed")
assert(remotes and remotes:IsA("Folder"), "CooperGame.Remotes was not installed")

local snapshotEvent = remotes:WaitForChild("Snapshot", ROOT_TIMEOUT) :: RemoteEvent
local feedbackEvent = remotes:WaitForChild("Feedback", ROOT_TIMEOUT) :: RemoteEvent
local requestEvent = remotes:WaitForChild("Request", ROOT_TIMEOUT) :: RemoteEvent
assert(snapshotEvent:IsA("RemoteEvent"), "CooperGame.Remotes.Snapshot must be a RemoteEvent")
assert(feedbackEvent:IsA("RemoteEvent"), "CooperGame.Remotes.Feedback must be a RemoteEvent")
assert(requestEvent:IsA("RemoteEvent"), "CooperGame.Remotes.Request must be a RemoteEvent")

local serverEvents = ServerScriptService:FindFirstChild(Config.ServerEventsName)
if not serverEvents then
	serverEvents = Instance.new("Folder")
	serverEvents.Name = Config.ServerEventsName
	serverEvents.Parent = ServerScriptService
end
assert(serverEvents:IsA("Folder"), Config.ServerEventsName .. " must be a Folder")

local function ensureBindable(className: string, name: string): Instance
	local existing = serverEvents:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = serverEvents
	end
	return existing
end

local reportActionEvent = ensureBindable("BindableEvent", "ReportAction") :: BindableEvent
local registerActionEvent = ensureBindable("BindableEvent", "RegisterAction") :: BindableEvent
local serverAPI = ensureBindable("BindableFunction", "API") :: BindableFunction

local environment = workspace:WaitForChild("CooperHouseEnvironment", ROOT_TIMEOUT)
assert(environment, "CooperHouseEnvironment was not found")
local house = environment:WaitForChild("CooperHouse", ROOT_TIMEOUT)
assert(house, "CooperHouseEnvironment.CooperHouse was not found")

type ActiveTask = {
	instanceId: number,
	definition: any,
	startedAt: number,
	expiresAt: number,
}

type ComboState = {
	count: number,
	lastCompletedAt: number,
}

local definitionById: { [string]: any } = {}
local definitionByEventKey: { [string]: any } = {}
for _, definition in ipairs(Config.Tasks) do
	assert(type(definition.id) == "string" and definitionById[definition.id] == nil, "Task IDs must be unique")
	assert(type(definition.eventKey) == "string" and definitionByEventKey[definition.eventKey] == nil, "Task event keys must be unique")
	definitionById[definition.id] = definition
	definitionByEventKey[definition.eventKey] = definition
end

local activeTasks: { ActiveTask } = {}
local combos: { [Player]: ComboState } = {}
local taskSerial = 0
local revision = 0
local stability = Config.Stability.Starting
local mode = Config.Mode.Normal
local machineStage = 0
local machineProgress = 0
local chapter = 0
local nextTaskAt = 0
local randomizer = Random.new()
local lastGaragePlayer: Player? = nil
local lastGaragePromptAt = 0
local sessionStartedAt = 0
local onboardingToastSent = false
local onboardingCompletions = 0
local onboardingComplete = false

local tutorialTaskSet: { [string]: boolean } = {}
for _, taskId in ipairs(Config.TaskDirector.TutorialTaskIds or {}) do
	tutorialTaskSet[taskId] = true
end

local VALID_MODES: { [string]: boolean } = {}
for _, configuredMode in pairs(Config.Mode) do
	VALID_MODES[configuredMode] = true
end

local SUPPORTED_EVENT_KEYS: { [string]: boolean } = {
	ShowerStopped = true,
	HandsWashed = true,
	TeethBrushed = true,
	ToiletFlushed = true,
	TerminalCommandRun = true,
	CubeMoveCompleted = true,
	GarageDoorClosed = true,
}

local function supportedActionCount(): number
	local count = 0
	for eventKey, enabled in pairs(SUPPORTED_EVENT_KEYS) do
		if enabled and definitionByEventKey[eventKey] then
			count += 1
		end
	end
	return count
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function chapterName(value: number): string
	for _, entry in ipairs(Config.Chapters) do
		if entry.chapter == value then
			return entry.name
		end
	end
	return "Unknown Chapter"
end

local function machineStageName(value: number): string
	if value <= 0 then
		return "Blueprint Pending"
	end
	local entry = Config.MachineStages[value]
	return entry and entry.name or "Unknown Component"
end

local function stabilityBand(value: number): string
	if value <= Config.Stability.PanicThreshold then
		return "Panic"
	elseif value <= Config.Stability.DangerThreshold then
		return "Danger"
	elseif value <= Config.Stability.ConcernThreshold then
		return "Concern"
	elseif value < Config.Stability.NormalThreshold then
		return "Uneasy"
	end
	return "Normal"
end

local function writeStateAttributes()
	stateFolder:SetAttribute("SchemaVersion", Config.SchemaVersion)
	stateFolder:SetAttribute("ServerEpoch", stateFolder:GetAttribute("ServerEpoch") or os.time())
	stateFolder:SetAttribute("ServerTime", serverNow())
	stateFolder:SetAttribute("Stability", stability)
	stateFolder:SetAttribute("StabilityBand", stabilityBand(stability))
	stateFolder:SetAttribute("Mode", mode)
	stateFolder:SetAttribute("MachineStage", machineStage)
	stateFolder:SetAttribute("MachineStageName", machineStageName(machineStage))
	stateFolder:SetAttribute("MachineProgress", machineProgress)
	stateFolder:SetAttribute("Chapter", chapter)
	stateFolder:SetAttribute("ChapterName", chapterName(chapter))
	stateFolder:SetAttribute("TaskRevision", revision)
	stateFolder:SetAttribute("SupportedActionCount", supportedActionCount())
	stateFolder:SetAttribute("OnboardingActive", not onboardingComplete and chapter == 0 and machineStage == 0)
	stateFolder:SetAttribute("OnboardingCompletions", onboardingCompletions)
	stateFolder:SetAttribute("OnboardingRequired", Config.TaskDirector.OnboardingRequiredCompletions or 3)
end

local function publicTask(record: ActiveTask)
	local definition = record.definition
	return {
		instanceId = record.instanceId,
		id = definition.id,
		title = definition.title,
		description = definition.description,
		requester = definition.requester,
		category = definition.category,
		startedAt = record.startedAt,
		expiresAt = record.expiresAt,
		deadline = math.max(0.01, record.expiresAt - record.startedAt),
		cash = definition.cash,
		chronons = definition.chronons,
		critical = definition.critical,
		eventKey = definition.eventKey,
		targetHint = definition.id,
	}
end

local function isTutorialPhase(): boolean
	if onboardingComplete or chapter > 0 or machineStage > 0 then
		return false
	end
	return sessionStartedAt > 0
end

local function currentTaskCaps(): (number, number, number)
	if isTutorialPhase() then
		return Config.TaskDirector.TutorialMaximumSharedTasks or 1,
			Config.TaskDirector.TutorialMinimumSpawnDelay or 12,
			Config.TaskDirector.TutorialMaximumSpawnDelay or 20
	end
	if chapter <= (Config.TaskDirector.EarlyChapterMax or 2) then
		return Config.TaskDirector.EarlyMaximumSharedTasks or 2,
			Config.TaskDirector.EarlyMinimumSpawnDelay or 8,
			Config.TaskDirector.EarlyMaximumSpawnDelay or 16
	end
	return Config.TaskDirector.MaximumSharedTasks,
		Config.TaskDirector.MinimumSpawnDelay,
		Config.TaskDirector.MaximumSpawnDelay
end

local function playerCurrency(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil, nil, nil
	end
	return leaderstats:FindFirstChild("Cash"), leaderstats:FindFirstChild("Chronons"), leaderstats:FindFirstChild("Combo")
end

local function snapshotFor(player: Player?)
	local tasks = table.create(#activeTasks)
	for index, record in ipairs(activeTasks) do
		tasks[index] = publicTask(record)
	end
	local cashValue, chrononsValue, comboValue
	if player then
		cashValue, chrononsValue, comboValue = playerCurrency(player)
	end
	return {
		revision = revision,
		serverTime = serverNow(),
		stability = stability,
		stabilityBand = stabilityBand(stability),
		mode = mode,
		machineStage = machineStage,
		machineStageName = machineStageName(machineStage),
		machineProgress = machineProgress,
		chapter = chapter,
		chapterName = chapterName(chapter),
		cash = cashValue and cashValue.Value or 0,
		chronons = chrononsValue and chrononsValue.Value or 0,
		combo = comboValue and comboValue.Value or 0,
		tasks = tasks,
		onboardingActive = isTutorialPhase(),
		onboardingCompletions = onboardingCompletions,
		onboardingRequired = Config.TaskDirector.OnboardingRequiredCompletions or 3,
		onboardingMinimumSeconds = Config.TaskDirector.OnboardingMinimumExploreSeconds or 75,
		onboardingElapsed = sessionStartedAt > 0 and math.max(0, serverNow() - sessionStartedAt) or 0,
	}
end

local function broadcastSnapshot()
	revision += 1
	writeStateAttributes()
	for _, player in ipairs(Players:GetPlayers()) do
		snapshotEvent:FireClient(player, snapshotFor(player))
	end
end

local function sendFeedback(player: Player?, kind: string, payload: any)
	local packet = if type(payload) == "table" then payload else { text = tostring(payload) }
	packet.kind = kind
	if player then
		feedbackEvent:FireClient(player, packet)
	else
		feedbackEvent:FireAllClients(packet)
	end
end

local function setMode(newMode: string, reason: string?)
	if not VALID_MODES[newMode] then
		return false, "Unknown campaign mode"
	end
	if isTutorialPhase() and newMode == Config.Mode.Panic then
		stateFolder:SetAttribute("LastBlockedPanicReason", reason or "")
		return false, "Panic is locked during guided onboarding"
	end
	-- Major crisis controllers hand control back through Normal. If stability
	-- reached zero during that crisis, enter Panic immediately instead of briefly
	-- publishing a desynchronized Normal state at zero stability.
	if newMode == Config.Mode.Normal and stability <= Config.Stability.PanicThreshold then
		newMode = Config.Mode.Panic
		reason = reason or "House Stability reached zero"
	end
	if mode == newMode then
		return true, mode
	end
	mode = newMode
	stateFolder:SetAttribute("LastModeReason", reason or "")
	stateFolder:SetAttribute("LastModeChangeAt", serverNow())
	sendFeedback(nil, "Mode", {
		mode = newMode,
		reason = reason or "",
	})
	broadcastSnapshot()
	return true, mode
end

local function adjustStability(delta: number, reason: string, player: Player?)
	if delta ~= delta or math.abs(delta) > 1000 then
		return
	end
	if delta < 0 and isTutorialPhase() then
		stateFolder:SetAttribute("LastGuidedPenaltyPrevented", reason)
		stateFolder:SetAttribute("LastGuidedPenaltyAt", serverNow())
		return
	end
	local previous = stability
	stability = math.clamp(math.floor(stability + delta + 0.5), 0, Config.Stability.Maximum)
	stateFolder:SetAttribute("LastStabilityReason", reason)
	stateFolder:SetAttribute("LastStabilityDelta", stability - previous)
	stateFolder:SetAttribute("LastStabilityAt", serverNow())
	if stability ~= previous then
		sendFeedback(player, "Stability", {
			delta = stability - previous,
			value = stability,
			reason = reason,
		})
	end
	if stability <= Config.Stability.PanicThreshold and mode == Config.Mode.Normal then
		setMode(Config.Mode.Panic, reason)
	elseif mode == Config.Mode.Panic and stability >= Config.Stability.DangerThreshold then
		setMode(Config.Mode.Normal, "The family recovered control")
	else
		broadcastSnapshot()
	end
end

local function removeActiveTaskAt(index: number): ActiveTask
	local record = activeTasks[index]
	table.remove(activeTasks, index)
	return record
end

local function activeDefinition(id: string): boolean
	for _, record in ipairs(activeTasks) do
		if record.definition.id == id then
			return true
		end
	end
	return false
end

local function installMachineStage(requestedStage: number, player: Player?): (boolean, string)
	if requestedStage ~= machineStage + 1 then
		return false, "Machine stages must be installed in order"
	end
	local entry = Config.MachineStages[requestedStage]
	if not entry then
		return false, "That machine stage does not exist"
	end
	machineStage = requestedStage
	machineProgress = entry.progress
	chapter = math.min(requestedStage, 11)
	stateFolder:SetAttribute("LastMachineInstallAt", serverNow())
	stateFolder:SetAttribute("LastMachineInstallerUserId", player and player.UserId or 0)
	sendFeedback(nil, "MachineStage", {
		stage = requestedStage,
		name = entry.name,
		progress = entry.progress,
	})
	broadcastSnapshot()
	return true, entry.name
end

local function awardCompletion(player: Player, record: ActiveTask)
	local definition = record.definition
	local cash, chronons, comboValue = playerCurrency(player)
	if not cash or not cash:IsA("IntValue") or not chronons or not chronons:IsA("IntValue") then
		warn("[CooperGame] Refused to consume task reward because player currencies are unavailable for " .. player.Name)
		return false
	end

	local currentTime = serverNow()
	local combo = combos[player]
	if not combo or currentTime - combo.lastCompletedAt > Config.TaskDirector.ComboWindow then
		combo = { count = 0, lastCompletedAt = 0 }
		combos[player] = combo
	end
	combo.count += 1
	combo.lastCompletedAt = currentTime
	local comboBonus = math.max(0, combo.count - 1) * 5
	cash.Value += definition.cash + comboBonus
	chronons.Value += definition.chronons
	if comboValue and comboValue:IsA("IntValue") then
		comboValue.Value = combo.count
	end

	adjustStability(definition.stabilityGain, definition.title .. " completed", player)
	if combo.count > 1 and combo.count % 3 == 0 then
		adjustStability(Config.Stability.Gains.Combo, string.format("%dx family combo", combo.count), player)
	end

	sendFeedback(player, "TaskComplete", {
		instanceId = record.instanceId,
		title = definition.title,
		cash = definition.cash + comboBonus,
		chronons = definition.chronons,
		combo = combo.count,
	})
	return true
end

local function finishOnboardingIfReady(): boolean
	if not isTutorialPhase() then
		return false
	end
	local required = Config.TaskDirector.OnboardingRequiredCompletions or 3
	local minimumSeconds = Config.TaskDirector.OnboardingMinimumExploreSeconds or 75
	local elapsed = serverNow() - sessionStartedAt
	if onboardingCompletions < required or elapsed < minimumSeconds then
		return false
	end
	onboardingComplete = true
	stateFolder:SetAttribute("OnboardingCompletedAt", serverNow())
	sendFeedback(nil, "OnboardingComplete", {
		title = "GEORGE IS ON HIS WAY",
		text = "Requests are timed now. Missing chores lowers House Stability. If it reaches 0, George comes after you. Follow each matching colored arrow, and handle red critical requests first.",
	})
	return true
end

local function completeEvent(eventKey: string, player: Player, metadata: any?): boolean
	if player.Parent ~= Players or type(eventKey) ~= "string" then
		return false
	end
	for index, record in ipairs(activeTasks) do
		if record.definition.eventKey == eventKey then
			local guidedCompletion = isTutorialPhase() and tutorialTaskSet[record.definition.id] == true
			-- Reward/state mutation must succeed before the task is consumed. This
			-- prevents a malformed leaderstats folder from silently eating progress.
			if not awardCompletion(player, record) then
				return false
			end
			local completed = removeActiveTaskAt(index)
			stateFolder:SetAttribute("LastCompletedTask", completed.definition.id)
			stateFolder:SetAttribute("LastCompletedByUserId", player.UserId)
			if type(metadata) == "table" then
				stateFolder:SetAttribute("LastCompletionSource", tostring(metadata.source or "Gameplay"))
			end
			if guidedCompletion then
				onboardingCompletions += 1
				local required = Config.TaskDirector.OnboardingRequiredCompletions or 3
				sendFeedback(player, "OnboardingProgress", {
					completed = onboardingCompletions,
					required = required,
					text = if onboardingCompletions >= required
						then "Great job. Explore for a moment while the house gets ready."
						else string.format("%d of %d guided chores complete. Follow the next colored arrow.", onboardingCompletions, required),
				})
				finishOnboardingIfReady()
			end
			broadcastSnapshot()
			return true
		end
	end
	return false
end

local function failTaskAt(index: number, reason: string)
	local record = removeActiveTaskAt(index)
	local definition = record.definition
	local guided = isTutorialPhase()
	sendFeedback(nil, "TaskFailed", {
		instanceId = record.instanceId,
		title = definition.title,
		critical = definition.critical,
		reason = reason,
		guided = guided,
	})
	if guided then
		-- Guided chores can time out, but they never damage the house or summon
		-- George. A fresh chore will be offered so the player can learn safely.
		broadcastSnapshot()
		return
	end
	if definition.critical and Config.TaskDirector.CriticalGeorgePanicOnFailure then
		-- A missed critical George request is an immediate Panic trigger. Route the
		-- entire transition through adjustStability so HUD feedback reports the real
		-- loss instead of a partial configured penalty followed by a silent zero.
		adjustStability(-stability, "George's critical request was ignored", nil)
	else
		adjustStability(-definition.stabilityLoss, definition.title .. " failed", nil)
	end
end

local function showerIsOn(): boolean
	local root = house:FindFirstChild("CooperInteractions")
	return root ~= nil and root:GetAttribute("ShowerOn") == true
end

local function garageDoor(): Instance?
	local garage = environment:FindFirstChild("DetachedGarage")
	return garage and garage:FindFirstChild("InteractiveSectionalGarageDoor")
end

local function definitionCanStart(definition: any): boolean
	if not SUPPORTED_EVENT_KEYS[definition.eventKey] then
		return false
	end
	if definition.minimumChapter > chapter then
		return false
	end
	if activeDefinition(definition.id) then
		return false
	end
	if isTutorialPhase() and not tutorialTaskSet[definition.id] then
		return false
	end
	if definition.eventKey == "ShowerStopped" and not showerIsOn() then
		return false
	elseif definition.eventKey == "GarageDoorClosed" then
		local door = garageDoor()
		if not door or door:GetAttribute("IsOpen") ~= true then
			return false
		end
	end
	return true
end

local function startRandomTask(): boolean
	local maxTasks = currentTaskCaps()
	if #activeTasks >= maxTasks then
		return false
	end
	local eligible = {}
	for _, definition in ipairs(Config.Tasks) do
		if definitionCanStart(definition) then
			table.insert(eligible, definition)
		end
	end
	if #eligible == 0 then
		return false
	end
	local definition = eligible[randomizer:NextInteger(1, #eligible)]
	taskSerial += 1
	local startedAt = serverNow()
	local deadline = definition.deadline
	if isTutorialPhase() then
		deadline = math.max(deadline, Config.TaskDirector.OnboardingTaskDeadlineSeconds or 65)
	end
	table.insert(activeTasks, {
		instanceId = taskSerial,
		definition = definition,
		startedAt = startedAt,
		expiresAt = startedAt + deadline,
	})
	sendFeedback(nil, "TaskStarted", {
		instanceId = taskSerial,
		title = definition.title,
		requester = definition.requester,
		critical = definition.critical,
		guided = isTutorialPhase(),
	})
	if isTutorialPhase() and not onboardingToastSent then
		onboardingToastSent = true
		sendFeedback(nil, "OnboardingStarted", {
			title = "WELCOME TO THE COOPER HOUSE",
			text = "Explore at your own pace. Follow the task's matching colored arrow, use the shown E/F interaction, and complete three simple chores. Guided chores have no failure penalty.",
		})
	end
	broadcastSnapshot()
	return true
end

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	if not prompt:IsDescendantOf(environment) then
		return
	end
	-- The garage controller has no companion integration hook, so attribution is
	-- recorded here and completion waits for its authoritative DoorState change.
	-- Every CooperInteractions action reports through the server-only BindableEvent
	-- after validation/completion; never infer those successes from raw prompts or
	-- client remotes here.
	if prompt.ObjectText == "Georgie & Mandy's garage" then
		lastGaragePlayer = player
		lastGaragePromptAt = serverNow()
	end
end)

local garageDoorConnection = nil
local function bindGarageDoor()
	if garageDoorConnection then
		garageDoorConnection:Disconnect()
		garageDoorConnection = nil
	end
	local boundDoor = garageDoor()
	if not boundDoor then
		warn("[CooperGame] Interactive garage door is unavailable; waiting for installer")
		return
	end
	garageDoorConnection = boundDoor:GetAttributeChangedSignal("DoorState"):Connect(function()
		if boundDoor.Parent
			and boundDoor:GetAttribute("DoorState") == "Closed"
			and lastGaragePlayer
			and lastGaragePlayer.Parent == Players
			and serverNow() - lastGaragePromptAt <= 6
		then
			completeEvent("GarageDoorClosed", lastGaragePlayer, { source = "GarageDoor" })
		end
	end)
end

local detachedGarage = environment:FindFirstChild("DetachedGarage")
assert(detachedGarage, "DetachedGarage is required by CooperGame")
detachedGarage.ChildAdded:Connect(function(child)
	if child.Name == "InteractiveSectionalGarageDoor" then
		task.defer(bindGarageDoor)
	end
end)
detachedGarage.ChildRemoved:Connect(function(child)
	if child.Name == "InteractiveSectionalGarageDoor" then
		task.defer(bindGarageDoor)
	end
end)
bindGarageDoor()

reportActionEvent.Event:Connect(function(eventKey: any, player: any, metadata: any)
	if type(eventKey) ~= "string" then
		return
	end
	if eventKey == "MachineStageInstalled" and type(metadata) == "table" then
		local requestedStage = tonumber(metadata.stage)
		if requestedStage then
			installMachineStage(math.floor(requestedStage), if typeof(player) == "Instance" and player:IsA("Player") then player else nil)
		end
	elseif typeof(player) == "Instance" and player:IsA("Player") then
		completeEvent(eventKey, player, metadata)
	end
end)

registerActionEvent.Event:Connect(function(eventKey: any, enabled: any)
	if type(eventKey) ~= "string" or not definitionByEventKey[eventKey] then
		warn("[CooperGame] Ignored registration for unknown task action " .. tostring(eventKey))
		return
	end
	SUPPORTED_EVENT_KEYS[eventKey] = enabled ~= false
	writeStateAttributes()
end)

local function adjustCurrency(playerOrNil: any, cashDeltaRaw: any, chrononsDeltaRaw: any, reasonRaw: any)
	local cashDelta = tonumber(cashDeltaRaw) or 0
	local chrononsDelta = tonumber(chrononsDeltaRaw) or 0
	if cashDelta ~= cashDelta or chrononsDelta ~= chrononsDelta
		or math.abs(cashDelta) > 100000 or math.abs(chrononsDelta) > 100000
	then
		return false, "Invalid currency delta"
	end
	cashDelta = math.floor(cashDelta)
	chrononsDelta = math.floor(chrononsDelta)
	local recipients = {}
	if typeof(playerOrNil) == "Instance" and playerOrNil:IsA("Player") and playerOrNil.Parent == Players then
		table.insert(recipients, playerOrNil)
	elseif playerOrNil == nil then
		recipients = Players:GetPlayers()
	else
		return false, "Invalid currency recipient"
	end
	local reason = tostring(reasonRaw or "Campaign adjustment")
	local changed = 0
	for _, recipient in ipairs(recipients) do
		local cash, chronons = playerCurrency(recipient)
		if cash and cash:IsA("IntValue") and chronons and chronons:IsA("IntValue") then
			-- Spending is atomic: refuse the entire mutation for this recipient when
			-- either balance would become negative.
			if cash.Value + cashDelta >= 0 and chronons.Value + chrononsDelta >= 0 then
				cash.Value += cashDelta
				chronons.Value += chrononsDelta
				changed += 1
				sendFeedback(recipient, "Currency", {
					cash = cashDelta,
					chronons = chrononsDelta,
					reason = reason,
				})
			end
		end
	end
	if changed > 0 then
		broadcastSnapshot()
		return true, changed
	end
	return false, "Insufficient balance or unavailable currency values"
end

serverAPI.OnInvoke = function(operation: any, arg1: any, arg2: any, arg3: any, arg4: any)
	if operation == "GetSnapshot" then
		local player = if typeof(arg1) == "Instance" and arg1:IsA("Player") then arg1 else nil
		return snapshotFor(player)
	elseif operation == "ReportAction" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		return completeEvent(tostring(arg2), arg1, { source = "ServerAPI" })
	elseif operation == "AdjustStability" and type(arg1) == "number" then
		local attribution = if typeof(arg3) == "Instance" and arg3:IsA("Player") then arg3 else nil
		adjustStability(arg1, tostring(arg2 or "Server API"), attribution)
		return stability
	elseif operation == "AdjustCurrency" then
		return adjustCurrency(arg1, arg2, arg3, arg4)
	elseif operation == "SetMode" and type(arg1) == "string" then
		return setMode(arg1, tostring(arg2 or "Server API"))
	elseif operation == "InstallMachineStage" and type(arg1) == "number" then
		return installMachineStage(math.floor(arg1), if typeof(arg2) == "Instance" and arg2:IsA("Player") then arg2 else nil)
	end
	return nil
end

local requestCooldown: { [Player]: number } = {}
requestEvent.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
	if type(action) ~= "string" then
		return
	end
	local now = os.clock()
	if (requestCooldown[player] or 0) > now then
		return
	end
	requestCooldown[player] = now + 0.2
	if action == "RequestSnapshot" then
		snapshotEvent:FireClient(player, snapshotFor(player))
	elseif RunService:IsStudio() and action == "DebugReportAction" and type(payload) == "string" then
		completeEvent(payload, player, { source = "StudioDebug" })
	elseif RunService:IsStudio() and action == "DebugSetStability" and type(payload) == "number" then
		stability = math.clamp(math.floor(payload), 0, Config.Stability.Maximum)
		if stability <= 0 then
			setMode(Config.Mode.Panic, "Studio debug")
		else
			setMode(Config.Mode.Normal, "Studio debug")
		end
		broadcastSnapshot()
	elseif RunService:IsStudio() and action == "DebugFinishOnboarding" then
		onboardingCompletions = Config.TaskDirector.OnboardingRequiredCompletions or 3
		sessionStartedAt = serverNow() - (Config.TaskDirector.OnboardingMinimumExploreSeconds or 75)
		if finishOnboardingIfReady() then
			broadcastSnapshot()
		end
	end
end)

local function setupPlayer(player: Player)
	local oldLeaderstats = player:FindFirstChild("leaderstats")
	local leaderstats = oldLeaderstats
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	for _, specification in ipairs({
		{ name = "Cash", value = 0 },
		{ name = "Chronons", value = 0 },
		{ name = "Combo", value = 0 },
	}) do
		local value = leaderstats:FindFirstChild(specification.name)
		if not value then
			value = Instance.new("IntValue")
			value.Name = specification.name
			value.Value = specification.value
			value.Parent = leaderstats
		end
		assert(value:IsA("IntValue"), "leaderstats." .. specification.name .. " must be an IntValue")
		value.Changed:Connect(function()
			snapshotEvent:FireClient(player, snapshotFor(player))
		end)
	end
	player:SetAttribute("CooperGameSchemaVersion", Config.SchemaVersion)
	task.defer(function()
		if player.Parent == Players then
			snapshotEvent:FireClient(player, snapshotFor(player))
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	combos[player] = nil
	requestCooldown[player] = nil
	if lastGaragePlayer == player then
		lastGaragePlayer = nil
	end
end)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

writeStateAttributes()
sessionStartedAt = serverNow()
nextTaskAt = sessionStartedAt + (Config.TaskDirector.OnboardingInitialTaskDelay or 8)
broadcastSnapshot()

task.spawn(function()
	while script.Parent do
		local currentTime = serverNow()
		for index = #activeTasks, 1, -1 do
			if currentTime >= activeTasks[index].expiresAt then
				failTaskAt(index, "Time ran out")
			end
		end
		if currentTime >= nextTaskAt then
			startRandomTask()
			local _, minDelay, maxDelay = currentTaskCaps()
			nextTaskAt = currentTime + randomizer:NextNumber(minDelay, maxDelay)
		end
		if finishOnboardingIfReady() then
			broadcastSnapshot()
		end
		stateFolder:SetAttribute("ServerTime", currentTime)
		task.wait(0.25)
	end
end)

print("[CooperGame] Campaign foundation ready")
