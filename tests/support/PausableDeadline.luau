local PauseSet = require("./PauseSet")

local PausableDeadline = {}
PausableDeadline.__index = PausableDeadline

local function assertFinite(value, label)
	assert(type(value) == "number" and value == value and value > -math.huge and value < math.huge,
		label .. " must be finite")
end

function PausableDeadline.new(clock, duration)
	assert(type(clock) == "table" and type(clock.now) == "function", "clock must expose now()")
	assertFinite(duration, "duration")
	assert(duration >= 0, "duration cannot be negative")
	local now = clock:now()
	assertFinite(now, "clock time")
	return setmetatable({
		_clock = clock,
		_duration = duration,
		_deadline = now + duration,
		_pauseStartedAt = nil,
		_pauses = PauseSet.new(),
	}, PausableDeadline)
end

function PausableDeadline:pause(reason)
	local wasPaused = self._pauses:isPaused()
	local token = self._pauses:acquire(reason)
	if not wasPaused then
		self._pauseStartedAt = self._clock:now()
	end
	return token
end

function PausableDeadline:resume(token)
	local released = self._pauses:release(token)
	if not released then
		return false
	end
	if not self._pauses:isPaused() then
		local now = self._clock:now()
		self._deadline += now - self._pauseStartedAt
		self._pauseStartedAt = nil
	end
	return true
end

function PausableDeadline:isPaused()
	return self._pauses:isPaused()
end

function PausableDeadline:pauseCount()
	return self._pauses:count()
end

function PausableDeadline:reasonCount(reason)
	return self._pauses:reasonCount(reason)
end

function PausableDeadline:remaining()
	local effectiveNow = self._pauseStartedAt or self._clock:now()
	return math.max(0, self._deadline - effectiveNow)
end

function PausableDeadline:isExpired()
	return self:remaining() <= 0
end

function PausableDeadline:deadline()
	if self._pauseStartedAt then
		return self._deadline + (self._clock:now() - self._pauseStartedAt)
	end
	return self._deadline
end

return PausableDeadline
