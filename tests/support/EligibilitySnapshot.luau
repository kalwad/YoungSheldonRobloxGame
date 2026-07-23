local EligibilitySnapshot = {}
EligibilitySnapshot.__index = EligibilitySnapshot

local INCLUDED_PRESENCE = {
	Active = true,
	AFK = true,
	Respawning = true,
	Bunker = true,
	OptionalRoute = true,
}

local function assertFinite(value, label)
	assert(type(value) == "number" and value == value and value > -math.huge and value < math.huge,
		label .. " must be finite")
end

local function copyRecord(record)
	if not record then
		return nil
	end
	local copied = {}
	for key, value in pairs(record) do
		copied[key] = value
	end
	return copied
end

function EligibilitySnapshot.new(sessionId, version, members, startedAt)
	assert(type(sessionId) == "string" and sessionId ~= "", "sessionId is required")
	assert(type(version) == "number" and version % 1 == 0 and version >= 1, "version must be a positive integer")
	assert(type(members) == "table", "members must be a table")
	startedAt = startedAt or 0
	assertFinite(startedAt, "startedAt")

	local records = {}
	local order = {}
	for _, member in ipairs(members) do
		local userId = member.userId
		assert(type(userId) == "number" and userId % 1 == 0 and userId > 0, "member userId must be positive")
		if member.sessionMember == true and member.hydrated == true and INCLUDED_PRESENCE[member.presence] then
			assert(records[userId] == nil, "duplicate eligible userId " .. tostring(userId))
			records[userId] = {
				userId = userId,
				presenceAtStart = member.presence,
				currentPresence = member.presence,
				outcome = "Eligible",
				disconnectedAt = nil,
				disconnectExpiresAt = nil,
			}
			table.insert(order, userId)
		end
	end
	table.sort(order)

	return setmetatable({
		sessionId = sessionId,
		version = version,
		startedAt = startedAt,
		_records = records,
		_order = order,
		_commitSealed = false,
	}, EligibilitySnapshot)
end

function EligibilitySnapshot:count()
	return #self._order
end

function EligibilitySnapshot:contains(userId)
	return self._records[userId] ~= nil
end

function EligibilitySnapshot:userIds()
	local copied = {}
	for index, userId in ipairs(self._order) do
		copied[index] = userId
	end
	return copied
end

function EligibilitySnapshot:record(userId)
	return copyRecord(self._records[userId])
end

function EligibilitySnapshot:markDisconnected(userId, now, graceSeconds)
	assertFinite(now, "now")
	assertFinite(graceSeconds, "graceSeconds")
	assert(graceSeconds >= 0, "graceSeconds cannot be negative")
	local record = self._records[userId]
	if not record or self._commitSealed or record.outcome ~= "Eligible" then
		return false
	end
	record.currentPresence = "DisconnectedGrace"
	record.disconnectedAt = now
	record.disconnectExpiresAt = now + graceSeconds
	return true
end

function EligibilitySnapshot:rejoin(userId, now)
	assertFinite(now, "now")
	local record = self._records[userId]
	if not record or self._commitSealed or record.outcome ~= "Eligible" then
		return false
	end
	if record.currentPresence ~= "DisconnectedGrace" then
		return false
	end
	if now >= record.disconnectExpiresAt then
		return false
	end
	record.currentPresence = "Rejoined"
	record.disconnectedAt = nil
	record.disconnectExpiresAt = nil
	return true
end

function EligibilitySnapshot:forfeitExpired(now)
	assertFinite(now, "now")
	if self._commitSealed then
		return 0
	end
	local count = 0
	for _, userId in ipairs(self._order) do
		local record = self._records[userId]
		if record.currentPresence == "DisconnectedGrace"
			and record.disconnectExpiresAt ~= nil
			and now >= record.disconnectExpiresAt then
			record.outcome = "Forfeited"
			record.currentPresence = "DisconnectedExpired"
			count += 1
		end
	end
	return count
end

function EligibilitySnapshot:eligibleUserIdsForCommit()
	local eligible = {}
	for _, userId in ipairs(self._order) do
		if self._records[userId].outcome == "Eligible" then
			table.insert(eligible, userId)
		end
	end
	return eligible
end

function EligibilitySnapshot:sealCommit()
	self._commitSealed = true
	return self:eligibleUserIdsForCommit()
end

function EligibilitySnapshot:isCommitSealed()
	return self._commitSealed
end

return EligibilitySnapshot
