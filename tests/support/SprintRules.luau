local SprintRules = {}
SprintRules.__index = SprintRules

local WALK_SPEED = 16
local SPRINT_SPEED = 22
local MAX_STAMINA = 6
local REGEN_DELAY = 0.8
local REGEN_PER_SECOND = 1.5

function SprintRules.new(clock)
	assert(type(clock) == "table" and type(clock.now) == "function", "clock is required")
	return setmetatable({
		clock = clock,
		stamina = MAX_STAMINA,
		intent = false,
		sprinting = false,
		exhausted = false,
		locked = false,
		seated = false,
		alive = true,
		lastDrainAt = -math.huge,
		speed = WALK_SPEED,
		multiplier = 1,
	}, SprintRules)
end

function SprintRules:setIntent(value)
	if value == false then
		self.intent = false
		return true, "Released"
	end
	if value ~= true then
		return false, "InvalidIntent"
	end
	if not self.alive or self.locked or self.seated or self.exhausted or self.stamina <= 0 then
		self.intent = false
		return false, "Unavailable"
	end
	self.intent = true
	return true, "Accepted"
end

function SprintRules:setMultiplier(multiplier)
	assert(type(multiplier) == "number" and multiplier > 0, "multiplier must be positive")
	self.multiplier = multiplier
end

function SprintRules:tick(seconds, moving)
	assert(type(seconds) == "number" and seconds >= 0, "seconds must be non-negative")
	local startedAt = self.clock:now()
	self.clock:advance(seconds)
	if not self.alive then
		self.intent = false
		self.sprinting = false
		self.speed = 0
		return
	end
	if (self.locked or self.seated) and self.intent then
		self.intent = false
	end

	local canSprint = self.intent
		and not self.exhausted
		and self.stamina > 0
		and not self.locked
		and not self.seated
	self.sprinting = canSprint and moving == true
	if self.sprinting then
		self.stamina = math.max(0, self.stamina - seconds)
		self.lastDrainAt = self.clock:now()
		if self.stamina <= 0.000001 then
			self.stamina = 0
			self.exhausted = true
			self.intent = false
			self.sprinting = false
		end
	elseif self.stamina < MAX_STAMINA and self.clock:now() - self.lastDrainAt >= REGEN_DELAY then
		local regenStartedAt = startedAt
		local readyAt = self.lastDrainAt + REGEN_DELAY
		if readyAt > regenStartedAt then
			regenStartedAt = readyAt
		end
		local regenSeconds = math.max(0, self.clock:now() - regenStartedAt)
		self.stamina = math.min(MAX_STAMINA, self.stamina + REGEN_PER_SECOND * regenSeconds)
		if self.exhausted and self.stamina >= MAX_STAMINA - 0.001 then
			self.stamina = MAX_STAMINA
			self.exhausted = false
		end
	end

	local baseSpeed = if self.sprinting then SPRINT_SPEED else WALK_SPEED
	self.speed = if self.locked then 0 else baseSpeed * self.multiplier
end

function SprintRules:serverCorrect(clientWalkSpeed)
	if clientWalkSpeed ~= self.speed then
		return self.speed
	end
	return clientWalkSpeed
end

function SprintRules:resetCharacter()
	self.stamina = MAX_STAMINA
	self.intent = false
	self.sprinting = false
	self.exhausted = false
	self.locked = false
	self.seated = false
	self.alive = true
	self.lastDrainAt = -math.huge
	self.speed = WALK_SPEED
	self.multiplier = 1
end

function SprintRules:hudVisible()
	return self.sprinting or self.stamina < MAX_STAMINA - 0.01
end

return SprintRules
