local DeterministicRandom = {}
DeterministicRandom.__index = DeterministicRandom

local MODULUS = 2147483647
local MULTIPLIER = 48271

local function assertInteger(value, label)
	assert(type(value) == "number" and value % 1 == 0, label .. " must be an integer")
end

function DeterministicRandom.fromSequence(sequence)
	assert(type(sequence) == "table", "sequence must be a table")
	local copied = {}
	for index, value in ipairs(sequence) do
		assert(type(value) == "number" and value >= 0 and value < 1,
			"sequence value " .. tostring(index) .. " must be in [0, 1)")
		copied[index] = value
	end
	return setmetatable({
		_mode = "sequence",
		_sequence = copied,
		_index = 1,
		_calls = 0,
	}, DeterministicRandom)
end

function DeterministicRandom.fromSeed(seed)
	assertInteger(seed, "seed")
	local state = seed % MODULUS
	if state <= 0 then
		state += MODULUS - 1
	end
	return setmetatable({
		_mode = "seed",
		_state = state,
		_calls = 0,
	}, DeterministicRandom)
end

function DeterministicRandom:_nextUnit()
	local value
	if self._mode == "sequence" then
		value = self._sequence[self._index]
		assert(value ~= nil, "deterministic random sequence exhausted")
		self._index += 1
	else
		self._state = (self._state * MULTIPLIER) % MODULUS
		value = (self._state - 1) / (MODULUS - 1)
	end
	self._calls += 1
	return value
end

function DeterministicRandom:nextNumber(minimum, maximum)
	minimum = minimum or 0
	maximum = maximum or 1
	assert(type(minimum) == "number" and type(maximum) == "number", "range bounds must be numbers")
	assert(maximum >= minimum, "maximum must be greater than or equal to minimum")
	return minimum + ((maximum - minimum) * self:_nextUnit())
end

function DeterministicRandom:nextInteger(minimum, maximum)
	assertInteger(minimum, "minimum")
	assertInteger(maximum, "maximum")
	assert(maximum >= minimum, "maximum must be greater than or equal to minimum")
	local span = maximum - minimum + 1
	return minimum + math.floor(self:_nextUnit() * span)
end

function DeterministicRandom:choose(values)
	assert(type(values) == "table" and #values > 0, "values must be a non-empty array")
	return values[self:nextInteger(1, #values)]
end

function DeterministicRandom:calls()
	return self._calls
end

DeterministicRandom.NextNumber = DeterministicRandom.nextNumber
DeterministicRandom.NextInteger = DeterministicRandom.nextInteger

return DeterministicRandom
