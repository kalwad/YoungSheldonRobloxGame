local FakeClock = {}
FakeClock.__index = FakeClock

local function assertFinite(value, label)
	assert(type(value) == "number", label .. " must be a number")
	assert(value == value and value > -math.huge and value < math.huge, label .. " must be finite")
end

function FakeClock.new(initialTime)
	initialTime = initialTime or 0
	assertFinite(initialTime, "initialTime")
	return setmetatable({
		_time = initialTime,
	}, FakeClock)
end

function FakeClock:now()
	return self._time
end

function FakeClock:advance(seconds)
	assertFinite(seconds, "seconds")
	assert(seconds >= 0, "a monotonic clock cannot advance backward")
	self._time += seconds
	return self._time
end

function FakeClock:set(newTime)
	assertFinite(newTime, "newTime")
	assert(newTime >= self._time, "a monotonic clock cannot be set backward")
	self._time = newTime
	return self._time
end

return FakeClock
