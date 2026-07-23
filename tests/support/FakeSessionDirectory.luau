local FailureSequence = require("./FailureSequence")

local FakeSessionDirectory = {}
FakeSessionDirectory.__index = FakeSessionDirectory

local function copyArray(values)
	local result = {}
	for index, value in ipairs(values or {}) do
		result[index] = value
	end
	return result
end

local function contains(values, expected)
	for _, value in ipairs(values) do
		if value == expected then
			return true
		end
	end
	return false
end

function FakeSessionDirectory.new(clock, options)
	options = options or {}
	assert(type(clock) == "table" and type(clock.now) == "function", "clock is required")
	return setmetatable({
		_clock = clock,
		_claimOutcomes = FailureSequence.new(options.claimOutcomes, "Success"),
		_nextSession = 0,
		_nextTicket = 0,
		_manifests = {},
		_tickets = {},
		_createCount = 0,
		_issueCount = 0,
		_claimCount = 0,
	}, FakeSessionDirectory)
end

function FakeSessionDirectory:createManifest(partyId, hostUserId, memberIds, membershipRevision, admissionSeconds)
	assert(type(partyId) == "string" and partyId ~= "", "partyId is required")
	assert(type(hostUserId) == "number", "hostUserId is required")
	assert(type(memberIds) == "table" and #memberIds >= 1, "memberIds are required")
	assert(contains(memberIds, hostUserId), "host must be a manifest member")
	assert(type(membershipRevision) == "number", "membershipRevision is required")

	self._nextSession += 1
	self._createCount += 1
	local sessionId = "session-" .. tostring(self._nextSession)
	self._manifests[sessionId] = {
		sessionId = sessionId,
		partyId = partyId,
		hostUserId = hostUserId,
		memberIds = copyArray(memberIds),
		membershipRevision = membershipRevision,
		createdAt = self._clock:now(),
		expiresAt = self._clock:now() + (admissionSeconds or 90),
	}
	return sessionId
end

function FakeSessionDirectory:issueTickets(sessionId)
	local manifest = self._manifests[sessionId]
	assert(manifest, "unknown session")
	local issued = {}
	for _, userId in ipairs(manifest.memberIds) do
		self._nextTicket += 1
		self._issueCount += 1
		local token = table.concat({ "ticket", sessionId, tostring(userId), tostring(self._nextTicket) }, ":")
		self._tickets[token] = {
			token = token,
			sessionId = sessionId,
			userId = userId,
			membershipRevision = manifest.membershipRevision,
			expiresAt = manifest.expiresAt,
			consumed = false,
		}
		issued[userId] = token
	end
	return issued
end

function FakeSessionDirectory:claim(token, userId, sessionId, membershipRevision)
	self._claimCount += 1
	local ticket = self._tickets[token]
	if not ticket then
		return false, "MissingTicket"
	end
	if ticket.sessionId ~= sessionId then
		return false, "SessionMismatch"
	end
	if ticket.userId ~= userId then
		return false, "UserMismatch"
	end
	if ticket.membershipRevision ~= membershipRevision then
		return false, "StaleMembership"
	end
	if self._clock:now() >= ticket.expiresAt then
		return false, "TicketExpired"
	end
	if ticket.consumed then
		return false, "TicketConsumed"
	end

	local storeOutcome = self._claimOutcomes:next()
	if storeOutcome ~= "Success" then
		return false, storeOutcome
	end

	ticket.consumed = true
	return true, "Admitted"
end

function FakeSessionDirectory:manifest(sessionId)
	local manifest = self._manifests[sessionId]
	if not manifest then
		return nil
	end
	return {
		sessionId = manifest.sessionId,
		partyId = manifest.partyId,
		hostUserId = manifest.hostUserId,
		memberIds = copyArray(manifest.memberIds),
		membershipRevision = manifest.membershipRevision,
		createdAt = manifest.createdAt,
		expiresAt = manifest.expiresAt,
	}
end

function FakeSessionDirectory:createCount()
	return self._createCount
end

function FakeSessionDirectory:issueCount()
	return self._issueCount
end

function FakeSessionDirectory:claimCount()
	return self._claimCount
end

return FakeSessionDirectory
