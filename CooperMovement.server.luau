--!strict
-- Server-authoritative Cooper player movement and sprint stamina.
-- Install as ServerScriptService.CooperMovement.
--
-- Other server scripts must use ServerScriptService.CooperMovementAPI instead
-- of writing Humanoid.WalkSpeed. SetLock composes named movement locks, while
-- SetSpeedMultiplier composes named effects such as the delivery carry penalty.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local cooperGame = ReplicatedStorage:WaitForChild("CooperGame", 15)
assert(cooperGame and cooperGame:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
local configModule = cooperGame:WaitForChild("Config", 15)
assert(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config is missing")
local Config = require(configModule)
local movementConfig = Config.Movement
assert(type(movementConfig) == "table", "Config.Movement is missing")

-- Milestone 1 locks these three values. Keep the explicit constants so a
-- verifier can catch an accidental design change, and require Config to agree.
local WALK_SPEED = 16
local SPRINT_SPEED = 22
local MAX_STAMINA = 6
assert(movementConfig.WalkSpeed == WALK_SPEED, "Config.Movement.WalkSpeed must remain 16")
assert(movementConfig.SprintSpeed == SPRINT_SPEED, "Config.Movement.SprintSpeed must remain 22")
assert(movementConfig.SprintStaminaSeconds == MAX_STAMINA, "Config.Movement.SprintStaminaSeconds must remain 6")

local REGEN_DELAY = math.max(0, tonumber(movementConfig.SprintRegenDelaySeconds) or 0.8)
local REGEN_PER_SECOND = math.max(0.1, tonumber(movementConfig.SprintRegenPerSecond) or 1.5)
local INTENT_RATE_LIMIT = math.max(0.03, tonumber(movementConfig.IntentRateLimitSeconds) or 0.08)
local INTENT_BUCKET_CAPACITY = 6
local ATTRIBUTE_INTERVAL = 0.1
local MOVE_EPSILON = 0.05
local SPEED_EPSILON = 0.025
local MIN_MULTIPLIER = 0.1
local MAX_MULTIPLIER = 2

local REMOTES_NAME = "CooperMovementRemotes"
local INTENT_EVENT_NAME = "SprintIntent"
local API_NAME = "CooperMovementAPI"

type MovementState = {
	player: Player,
	character: Model?,
	humanoid: Humanoid?,
	intent: boolean,
	stamina: number,
	exhausted: boolean,
	sprinting: boolean,
	computedLocked: boolean,
	currentSpeed: number,
	currentMultiplier: number,
	lastDrainAt: number,
	intentTokens: number,
	lastTokenAt: number,
	lastAttributeAt: number,
	lastAttributeStamina: number,
	locks: { [string]: boolean },
	multipliers: { [string]: number },
	connections: { RBXScriptConnection },
	characterConnections: { RBXScriptConnection },
}

local states: { [Player]: MovementState } = {}

local function getOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, string.format("%s must be a %s", existing:GetFullName(), className))
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local remotes = getOrCreate(ReplicatedStorage, "Folder", REMOTES_NAME) :: Folder
local sprintIntent = getOrCreate(remotes, "RemoteEvent", INTENT_EVENT_NAME) :: RemoteEvent
remotes:SetAttribute("WalkSpeed", WALK_SPEED)
remotes:SetAttribute("SprintSpeed", SPRINT_SPEED)
remotes:SetAttribute("SprintStaminaSeconds", MAX_STAMINA)
remotes:SetAttribute("SprintRegenDelaySeconds", REGEN_DELAY)
remotes:SetAttribute("SprintRegenPerSecond", REGEN_PER_SECOND)
remotes:SetAttribute("ServerAuthoritative", true)

local movementAPI = getOrCreate(ServerScriptService, "Folder", API_NAME) :: Folder
local setLockFunction = getOrCreate(movementAPI, "BindableFunction", "SetLock") :: BindableFunction
local setMultiplierFunction = getOrCreate(movementAPI, "BindableFunction", "SetSpeedMultiplier") :: BindableFunction
local releaseSourceEvent = getOrCreate(movementAPI, "BindableEvent", "ReleaseSource") :: BindableEvent
local stateChangedEvent = getOrCreate(movementAPI, "BindableEvent", "StateChanged") :: BindableEvent
movementAPI:SetAttribute("ContractVersion", 1)

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function setAttribute(instance: Instance, name: string, value: any): boolean
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
		return true
	end
	return false
end

local function validSource(sourceValue: any): string?
	if type(sourceValue) ~= "string" then
		return nil
	end
	local source = string.match(sourceValue, "^%s*(.-)%s*$") or ""
	if #source < 1 or #source > 80 then
		return nil
	end
	return source
end

local function combinedMultiplier(state: MovementState): number
	local result = 1
	for _, multiplier in pairs(state.multipliers) do
		result *= multiplier
	end
	return math.clamp(result, MIN_MULTIPLIER, MAX_MULTIPLIER)
end

local function hasNamedLock(state: MovementState): boolean
	return next(state.locks) ~= nil
end

local function sessionAttributeActive(player: Player, attributeName: string, now: number): boolean
	local value = player:GetAttribute(attributeName)
	return type(value) == "number" and value == value and value > now
end

local function modalSessionActive(player: Player, now: number): boolean
	return sessionAttributeActive(player, "CooperComputerSessionUntil", now)
		or sessionAttributeActive(player, "CooperBunkerComputerSessionUntil", now)
end

local function publishState(state: MovementState, force: boolean?)
	local now = serverNow()
	local roundedStamina = math.floor(state.stamina * 100 + 0.5) / 100
	if not force and now - state.lastAttributeAt < ATTRIBUTE_INTERVAL then
		return
	end
	state.lastAttributeAt = now
	state.lastAttributeStamina = roundedStamina

	local player = state.player
	local changed = setAttribute(player, "CooperMovementReady", state.humanoid ~= nil)
	changed = setAttribute(player, "CooperStamina", roundedStamina) or changed
	changed = setAttribute(player, "CooperStaminaMax", MAX_STAMINA) or changed
	changed = setAttribute(player, "CooperSprinting", state.sprinting) or changed
	changed = setAttribute(player, "CooperSprintExhausted", state.exhausted) or changed
	changed = setAttribute(player, "CooperSprintIntent", state.intent) or changed
	changed = setAttribute(player, "CooperMovementLocked", state.computedLocked) or changed
	changed = setAttribute(player, "CooperMovementSpeed", math.floor(state.currentSpeed * 100 + 0.5) / 100) or changed
	changed = setAttribute(player, "CooperCarrySpeedMultiplier", math.floor(state.currentMultiplier * 1000 + 0.5) / 1000) or changed

	if changed then
		stateChangedEvent:Fire(player, {
			stamina = roundedStamina,
			staminaMax = MAX_STAMINA,
			sprinting = state.sprinting,
			exhausted = state.exhausted,
			locked = state.computedLocked,
			speed = state.currentSpeed,
			multiplier = state.currentMultiplier,
		})
	end
end

local function clearCharacterConnections(state: MovementState)
	for _, connection in ipairs(state.characterConnections) do
		connection:Disconnect()
	end
	table.clear(state.characterConnections)
end

local function detachCharacter(state: MovementState, character: Model?)
	if character and state.character ~= character then
		return
	end
	clearCharacterConnections(state)
	state.character = nil
	state.humanoid = nil
	state.intent = false
	state.sprinting = false
	state.computedLocked = hasNamedLock(state)
	state.currentSpeed = 0
	publishState(state, true)
end

local function attachCharacter(state: MovementState, character: Model)
	clearCharacterConnections(state)
	state.character = character
	state.humanoid = nil
	state.intent = false
	state.stamina = MAX_STAMINA
	state.exhausted = false
	state.sprinting = false
	state.computedLocked = hasNamedLock(state)
	state.currentMultiplier = combinedMultiplier(state)
	state.currentSpeed = 0
	state.lastDrainAt = serverNow()
	publishState(state, true)

	task.spawn(function()
		local humanoidValue = character:WaitForChild("Humanoid", 10)
		if states[state.player] ~= state or state.character ~= character then
			return
		end
		if not humanoidValue or not humanoidValue:IsA("Humanoid") then
			detachCharacter(state, character)
			return
		end
		local humanoid = humanoidValue :: Humanoid
		state.humanoid = humanoid
		table.insert(state.characterConnections, humanoid.Died:Connect(function()
			state.intent = false
			state.sprinting = false
			state.currentSpeed = 0
			publishState(state, true)
		end))
		state.currentSpeed = WALK_SPEED * state.currentMultiplier
		humanoid.WalkSpeed = state.currentSpeed
		publishState(state, true)
	end)
end

local function createState(player: Player): MovementState
	local now = serverNow()
	local state: MovementState = {
		player = player,
		character = nil,
		humanoid = nil,
		intent = false,
		stamina = MAX_STAMINA,
		exhausted = false,
		sprinting = false,
		computedLocked = false,
		currentSpeed = 0,
		currentMultiplier = 1,
		lastDrainAt = now,
		intentTokens = INTENT_BUCKET_CAPACITY,
		lastTokenAt = now,
		lastAttributeAt = 0,
		lastAttributeStamina = -1,
		locks = {},
		multipliers = {},
		connections = {},
		characterConnections = {},
	}
	states[player] = state
	table.insert(state.connections, player.CharacterAdded:Connect(function(character)
		attachCharacter(state, character)
	end))
	table.insert(state.connections, player.CharacterRemoving:Connect(function(character)
		detachCharacter(state, character)
	end))
	if player.Character then
		attachCharacter(state, player.Character)
	else
		publishState(state, true)
	end
	return state
end

local function stateFor(playerValue: any): MovementState?
	if typeof(playerValue) ~= "Instance" or not playerValue:IsA("Player") then
		return nil
	end
	local player = playerValue :: Player
	if player.Parent ~= Players then
		return nil
	end
	return states[player] or createState(player)
end

local function releaseSource(state: MovementState, source: string): boolean
	local changed = false
	if state.locks[source] ~= nil then
		state.locks[source] = nil
		changed = true
	end
	if state.multipliers[source] ~= nil then
		state.multipliers[source] = nil
		changed = true
	end
	if changed then
		state.computedLocked = hasNamedLock(state) or modalSessionActive(state.player, serverNow())
		state.currentMultiplier = combinedMultiplier(state)
		publishState(state, true)
	end
	return changed
end

setLockFunction.OnInvoke = function(playerValue: any, sourceValue: any, lockedValue: any): (boolean, string)
	local state = stateFor(playerValue)
	local source = validSource(sourceValue)
	if not state or not source or type(lockedValue) ~= "boolean" then
		return false, "invalid arguments"
	end
	if lockedValue then
		state.locks[source] = true
		local hadIntent = state.intent
		state.intent = false
		if hadIntent then
			sprintIntent:FireClient(state.player, false, "locked")
		end
	else
		state.locks[source] = nil
	end
	state.computedLocked = hasNamedLock(state) or modalSessionActive(state.player, serverNow())
	publishState(state, true)
	return true, if lockedValue then "locked" else "unlocked"
end

setMultiplierFunction.OnInvoke = function(playerValue: any, sourceValue: any, multiplierValue: any): (boolean, string)
	local state = stateFor(playerValue)
	local source = validSource(sourceValue)
	if not state or not source then
		return false, "invalid arguments"
	end
	if multiplierValue == nil then
		state.multipliers[source] = nil
		state.currentMultiplier = combinedMultiplier(state)
		publishState(state, true)
		return true, "removed"
	end
	local multiplier = tonumber(multiplierValue)
	if not multiplier or multiplier ~= multiplier or multiplier == math.huge or multiplier == -math.huge then
		return false, "invalid multiplier"
	end
	if multiplier < MIN_MULTIPLIER or multiplier > MAX_MULTIPLIER then
		return false, string.format("multiplier must be between %.1f and %.1f", MIN_MULTIPLIER, MAX_MULTIPLIER)
	end
	state.multipliers[source] = multiplier
	state.currentMultiplier = combinedMultiplier(state)
	publishState(state, true)
	return true, "applied"
end

releaseSourceEvent.Event:Connect(function(playerValue: any, sourceValue: any)
	local state = stateFor(playerValue)
	local source = validSource(sourceValue)
	if state and source then
		releaseSource(state, source)
	end
end)

local function consumeIntentToken(state: MovementState, now: number): boolean
	local refillRate = 1 / INTENT_RATE_LIMIT
	local elapsed = math.max(0, now - state.lastTokenAt)
	state.lastTokenAt = now
	state.intentTokens = math.min(INTENT_BUCKET_CAPACITY, state.intentTokens + elapsed * refillRate)
	if state.intentTokens < 1 then
		return false
	end
	state.intentTokens -= 1
	return true
end

sprintIntent.OnServerEvent:Connect(function(player: Player, intentValue: any)
	local state = states[player] or createState(player)
	if type(intentValue) ~= "boolean" then
		return
	end
	-- A release is always accepted, even if a noisy client depleted its bucket;
	-- this prevents a dropped key-up packet from leaving sprint latched on.
	if intentValue == false then
		local hadIntent = state.intent or state.sprinting
		state.intent = false
		if hadIntent then
			publishState(state, true)
			sprintIntent:FireClient(player, false, "released")
		end
		return
	end
	local now = serverNow()
	if not consumeIntentToken(state, now) then
		return
	end
	local humanoid = state.humanoid
	if not humanoid
		or humanoid.Health <= 0
		or humanoid.SeatPart ~= nil
		or state.exhausted
		or state.stamina <= 0
		or hasNamedLock(state)
		or modalSessionActive(player, now)
	then
		state.intent = false
		publishState(state, true)
		sprintIntent:FireClient(player, false, "unavailable")
		return
	end
	state.intent = true
	publishState(state, true)
	sprintIntent:FireClient(player, true, "accepted")
end)

RunService.Heartbeat:Connect(function(deltaTime: number)
	local now = serverNow()
	-- Clamp a single severe stall; normal Heartbeat deltas remain real seconds,
	-- so uninterrupted movement consumes the six-second budget predictably.
	local dt = math.min(math.max(deltaTime, 0), 0.25)
	for player, state in pairs(states) do
		if player.Parent ~= Players then
			continue
		end
		local humanoid = state.humanoid
		if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
			state.intent = false
			state.sprinting = false
			state.currentSpeed = 0
			publishState(state)
			continue
		end

		local modalLocked = modalSessionActive(player, now)
		local namedLocked = hasNamedLock(state)
		local locked = namedLocked or modalLocked
		local seated = humanoid.SeatPart ~= nil
		if (locked or seated) and state.intent then
			state.intent = false
			sprintIntent:FireClient(player, false, if seated then "seated" else "locked")
		end

		local moving = humanoid.MoveDirection.Magnitude > MOVE_EPSILON
		local canSprint = state.intent
			and not state.exhausted
			and state.stamina > 0
			and not locked
			and not seated
		local sprinting = canSprint and moving
		if sprinting then
			state.stamina = math.max(0, state.stamina - dt)
			state.lastDrainAt = now
			if state.stamina <= 0 then
				state.stamina = 0
				state.exhausted = true
				state.intent = false
				sprinting = false
				sprintIntent:FireClient(player, false, "exhausted")
			end
		elseif state.stamina < MAX_STAMINA and now - state.lastDrainAt >= REGEN_DELAY then
			state.stamina = math.min(MAX_STAMINA, state.stamina + REGEN_PER_SECOND * dt)
			if state.exhausted and state.stamina >= MAX_STAMINA - 0.001 then
				state.stamina = MAX_STAMINA
				state.exhausted = false
			end
		end

		state.sprinting = sprinting
		state.computedLocked = locked
		state.currentMultiplier = combinedMultiplier(state)
		local baseSpeed = if sprinting then SPRINT_SPEED else WALK_SPEED
		local desiredSpeed = if locked then 0 else baseSpeed * state.currentMultiplier
		state.currentSpeed = desiredSpeed
		if math.abs(humanoid.WalkSpeed - desiredSpeed) > SPEED_EPSILON then
			humanoid.WalkSpeed = desiredSpeed
		end
		publishState(state)
	end
end)

local function removePlayer(player: Player)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	clearCharacterConnections(state)
	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end
	table.clear(state.connections)
end

Players.PlayerAdded:Connect(function(player)
	if not states[player] then
		createState(player)
	end
end)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in ipairs(Players:GetPlayers()) do
	if not states[player] then
		createState(player)
	end
end

print(string.format(
	"[CooperMovement] Server-authoritative movement ready (walk %d, sprint %d, stamina %ds)",
	WALK_SPEED,
	SPRINT_SPEED,
	MAX_STAMINA
))
