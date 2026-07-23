local TransactionLedger = {}
TransactionLedger.__index = TransactionLedger

local function copy(value, visited)
	if type(value) ~= "table" then
		return value
	end
	visited = visited or {}
	if visited[value] then
		return visited[value]
	end
	local result = {}
	visited[value] = result
	for key, child in pairs(value) do
		result[copy(key, visited)] = copy(child, visited)
	end
	return result
end

local function validIdentifier(value)
	return type(value) == "string" and value ~= "" and string.match(value, "^[%w_%-]+$") ~= nil
end

local function response(ok, applied, state, code, result)
	return {
		ok = ok,
		applied = applied,
		state = state,
		code = code,
		result = copy(result),
	}
end

function TransactionLedger.new(options)
	options = options or {}
	assert(validIdentifier(options.sessionId), "sessionId must contain only letters, numbers, underscore, or hyphen")
	local capacity = options.capacity or 256
	assert(type(capacity) == "number" and capacity % 1 == 0 and capacity >= 1, "capacity must be a positive integer")
	return setmetatable({
		_activeSessionId = options.sessionId,
		_capacity = capacity,
		_nextSequence = 0,
		_records = {},
		_committedOrder = {},
		_finalizedHighWater = {},
	}, TransactionLedger)
end

function TransactionLedger:activeSessionId()
	return self._activeSessionId
end

function TransactionLedger:issue(operationType, profileId, authoritativeValue, preconditionRevision)
	assert(validIdentifier(operationType), "operationType must be a safe identifier")
	assert(validIdentifier(tostring(profileId)), "profileId must be a safe identifier")
	assert(type(preconditionRevision) == "number" and preconditionRevision % 1 == 0 and preconditionRevision >= 0,
		"preconditionRevision must be a non-negative integer")

	self._nextSequence += 1
	local sequence = self._nextSequence
	local operationId = table.concat({
		self._activeSessionId,
		tostring(sequence),
		operationType,
		tostring(profileId),
	}, ":")
	self._records[operationId] = {
		operationId = operationId,
		sequence = sequence,
		sessionId = self._activeSessionId,
		type = operationType,
		profileId = tostring(profileId),
		authoritativeValue = copy(authoritativeValue),
		preconditionRevision = preconditionRevision,
		state = "Pending",
		attempts = 0,
		result = nil,
		lastError = nil,
	}
	return copy(self._records[operationId])
end

function TransactionLedger:get(operationId)
	return copy(self._records[operationId])
end

function TransactionLedger:_trimCommitted()
	while #self._committedOrder > self._capacity do
		local oldestId = table.remove(self._committedOrder, 1)
		local oldest = self._records[oldestId]
		if oldest and oldest.state == "Committed" then
			self._records[oldestId] = nil
		end
	end
end

function TransactionLedger:_unknownResponse(operationId)
	local sessionId, rawSequence = string.match(tostring(operationId), "^([^:]+):(%d+):")
	if sessionId and sessionId ~= self._activeSessionId then
		return response(false, false, nil, "StaleSession", nil)
	end
	local sequence = tonumber(rawSequence)
	local highWater = sessionId and self._finalizedHighWater[sessionId] or nil
	if sequence and highWater and sequence <= highWater then
		return response(false, false, "Committed", "AlreadyFinalizedResultEvicted", nil)
	end
	return response(false, false, nil, "UnknownOperation", nil)
end

function TransactionLedger:commit(operationId, apply)
	assert(type(apply) == "function", "apply must be a function")
	local record = self._records[operationId]
	if not record then
		return self:_unknownResponse(operationId)
	end
	if record.sessionId ~= self._activeSessionId then
		return response(false, false, record.state, "StaleSession", nil)
	end
	if record.state == "Committed" then
		return response(true, false, record.state, "AlreadyCommitted", record.result)
	end
	if record.state == "RolledBack" then
		return response(false, false, record.state, "RolledBack", record.result)
	end
	if record.state ~= "Pending" and record.state ~= "NeedsReconciliation" then
		return response(false, false, record.state, "InvalidState", nil)
	end

	record.attempts += 1
	local ok, result = pcall(apply, copy(record))
	if not ok then
		record.state = "NeedsReconciliation"
		record.lastError = tostring(result)
		return response(false, false, record.state, "ApplyFailed", record.lastError)
	end

	record.state = "Committed"
	record.result = copy(result)
	record.lastError = nil
	self._finalizedHighWater[record.sessionId] = math.max(
		self._finalizedHighWater[record.sessionId] or 0,
		record.sequence
	)
	table.insert(self._committedOrder, operationId)
	self:_trimCommitted()
	return response(true, true, record.state, "Committed", record.result)
end

function TransactionLedger:rollBack(operationId, reason)
	local record = self._records[operationId]
	if not record then
		return self:_unknownResponse(operationId)
	end
	if record.sessionId ~= self._activeSessionId then
		return response(false, false, record.state, "StaleSession", nil)
	end
	if record.state == "Committed" then
		return response(false, false, record.state, "AlreadyCommitted", record.result)
	end
	record.state = "RolledBack"
	record.result = { reason = reason or "Unspecified" }
	return response(true, false, record.state, "RolledBack", record.result)
end

function TransactionLedger:supersedeSession(newSessionId)
	assert(validIdentifier(newSessionId), "newSessionId must be a safe identifier")
	assert(newSessionId ~= self._activeSessionId, "new session must differ from active session")
	self._activeSessionId = newSessionId
	self._nextSequence = 0
end

return TransactionLedger
