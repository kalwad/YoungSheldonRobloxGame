local FailureSequence = {}
FailureSequence.__index = FailureSequence

local function copyArray(values)
	local copied = {}
	for index, value in ipairs(values or {}) do
		copied[index] = value
	end
	return copied
end

function FailureSequence.new(values, fallback)
	assert(values == nil or type(values) == "table", "values must be an array")
	return setmetatable({
		_values = copyArray(values),
		_fallback = if fallback == nil then "Success" else fallback,
		_cursor = 0,
	}, FailureSequence)
end

function FailureSequence:next()
	self._cursor += 1
	local value = self._values[self._cursor]
	if value == nil then
		return self._fallback
	end
	return value
end

function FailureSequence:count()
	return self._cursor
end

function FailureSequence:remaining()
	return math.max(0, #self._values - self._cursor)
end

return FailureSequence
