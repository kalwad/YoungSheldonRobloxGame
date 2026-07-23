local PauseSet = {}
PauseSet.__index = PauseSet

function PauseSet.new()
	return setmetatable({
		_nextToken = 0,
		_tokens = {},
		_reasonCounts = {},
		_total = 0,
	}, PauseSet)
end

function PauseSet:acquire(reason)
	assert(type(reason) == "string" and reason ~= "", "pause reason is required")
	self._nextToken += 1
	local token = "pause-" .. tostring(self._nextToken)
	self._tokens[token] = reason
	self._reasonCounts[reason] = (self._reasonCounts[reason] or 0) + 1
	self._total += 1
	return token
end

function PauseSet:release(token)
	local reason = self._tokens[token]
	if not reason then
		return false
	end
	self._tokens[token] = nil
	self._reasonCounts[reason] -= 1
	if self._reasonCounts[reason] == 0 then
		self._reasonCounts[reason] = nil
	end
	self._total -= 1
	return true
end

function PauseSet:isPaused()
	return self._total > 0
end

function PauseSet:count()
	return self._total
end

function PauseSet:reasonCount(reason)
	return self._reasonCounts[reason] or 0
end

function PauseSet:reasons()
	local result = {}
	for reason in pairs(self._reasonCounts) do
		table.insert(result, reason)
	end
	table.sort(result)
	return result
end

return PauseSet
