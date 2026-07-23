local PartyLaunchScenario = {}
PartyLaunchScenario.__index = PartyLaunchScenario

local function copyArray(values)
	local result = {}
	for index, value in ipairs(values or {}) do
		result[index] = value
	end
	return result
end

local function copyMap(values)
	local result = {}
	for key, value in pairs(values or {}) do
		result[key] = value
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

function PartyLaunchScenario.new(options)
	assert(type(options) == "table", "options are required")
	assert(type(options.clock) == "table", "clock is required")
	assert(type(options.teleport) == "table", "teleport adapter is required")
	assert(type(options.directory) == "table", "session directory is required")
	assert(type(options.hostUserId) == "number", "hostUserId is required")
	assert(type(options.memberIds) == "table" and #options.memberIds >= 1, "memberIds are required")
	assert(contains(options.memberIds, options.hostUserId), "host must be a member")

	local members = copyArray(options.memberIds)
	table.sort(members)
	local ready = {}
	local requestRecords = {}
	for _, userId in ipairs(members) do
		ready[userId] = false
		requestRecords[userId] = {
			sequence = 0,
			value = false,
		}
	end

	return setmetatable({
		clock = options.clock,
		teleport = options.teleport,
		directory = options.directory,
		hostUserId = options.hostUserId,
		memberIds = members,
		partyId = options.partyId or "party-1",
		placeId = options.placeId or 1,
		membershipRevision = options.membershipRevision or 1,
		partyRevision = 1,
		ready = ready,
		requestRecords = requestRecords,
		partyState = "Open",
		pendingLaunch = nil,
		finalLaunch = nil,
		lastReadyAt = {},
		lastLaunchAt = nil,
		readyCooldown = options.readyCooldown or 0.1,
		launchCooldown = options.launchCooldown or 0.1,
		teleportAttempts = options.teleportAttempts or 2,
	}, PartyLaunchScenario)
end

function PartyLaunchScenario:isMember(userId)
	return contains(self.memberIds, userId)
end

function PartyLaunchScenario:canLaunch()
	if self.partyState == "Cancelled" or self.partyState == "Launched" then
		return false
	end
	for _, userId in ipairs(self.memberIds) do
		if self.ready[userId] ~= true then
			return false
		end
	end
	return true
end

function PartyLaunchScenario:snapshot()
	return {
		partyRevision = self.partyRevision,
		membershipRevision = self.membershipRevision,
		ready = copyMap(self.ready),
		canLaunch = self:canLaunch(),
		partyState = self.partyState,
	}
end

function PartyLaunchScenario:setReady(userId, value, requestSequence)
	if not self:isMember(userId) then
		return false, "NotMember", self:snapshot()
	end
	if type(value) ~= "boolean" then
		return false, "InvalidReadyValue", self:snapshot()
	end
	if type(requestSequence) ~= "number" or requestSequence % 1 ~= 0 or requestSequence < 1 then
		return false, "InvalidRequestSequence", self:snapshot()
	end
	if self.partyState ~= "Open" then
		return false, "PartyLocked", self:snapshot()
	end

	local record = self.requestRecords[userId]
	if requestSequence < record.sequence then
		return false, "StaleRequest", self:snapshot()
	end
	if requestSequence == record.sequence then
		if value ~= record.value then
			return false, "RequestIdentityMismatch", self:snapshot()
		end
		return true, "AlreadyCommitted", self:snapshot()
	end

	local now = self.clock:now()
	local lastAt = self.lastReadyAt[userId]
	if lastAt ~= nil and now - lastAt < self.readyCooldown then
		return false, "ReadyRateLimited", self:snapshot()
	end
	self.lastReadyAt[userId] = now
	record.sequence = requestSequence
	record.value = value
	if self.ready[userId] ~= value then
		self.ready[userId] = value
		self.partyRevision += 1
	end
	return true, "ReadyCommitted", self:snapshot()
end

function PartyLaunchScenario:_ensurePendingLaunch()
	if self.pendingLaunch then
		return self.pendingLaunch
	end
	self.pendingLaunch = {
		launchKey = table.concat({ self.partyId, tostring(self.membershipRevision), tostring(self.partyRevision) }, ":"),
		memberIds = copyArray(self.memberIds),
		membershipRevision = self.membershipRevision,
		reservationCode = nil,
		sessionId = nil,
		tickets = nil,
		teleportAttempts = 0,
		lastTeleportResult = nil,
	}
	return self.pendingLaunch
end

function PartyLaunchScenario:launch(userId)
	if userId ~= self.hostUserId then
		return false, "HostOnly", self.finalLaunch or self.pendingLaunch
	end
	if self.partyState == "Cancelled" then
		return false, "PartyCancelled", nil
	end
	if self.partyState == "Launched" then
		return true, "AlreadyLaunched", self.finalLaunch
	end
	if not self:canLaunch() then
		return false, "MembersNotReady", nil
	end

	local now = self.clock:now()
	if self.lastLaunchAt ~= nil and now - self.lastLaunchAt < self.launchCooldown then
		return false, "LaunchRateLimited", self.pendingLaunch
	end
	self.lastLaunchAt = now
	self.partyState = "Launching"
	local pending = self:_ensurePendingLaunch()

	if not pending.reservationCode then
		local ok, result = self.teleport:reserve(self.placeId, pending.launchKey)
		if not ok then
			self.partyState = "Open"
			return false, "ReservationFailed:" .. tostring(result), pending
		end
		pending.reservationCode = result
	end

	if not pending.sessionId then
		pending.sessionId = self.directory:createManifest(
			self.partyId,
			self.hostUserId,
			pending.memberIds,
			pending.membershipRevision,
			90
		)
		pending.tickets = self.directory:issueTickets(pending.sessionId)
	end

	local teleported = false
	local result = "TeleportNotAttempted"
	for _ = 1, self.teleportAttempts do
		teleported, result = self.teleport:teleport(
			pending.reservationCode,
			pending.sessionId,
			pending.memberIds
		)
		pending.teleportAttempts += 1
		pending.lastTeleportResult = result
		if teleported then
			break
		end
	end
	if not teleported then
		self.partyState = "Open"
		return false, "TeleportFailed:" .. tostring(result), pending
	end

	self.partyState = "Launched"
	self.finalLaunch = pending
	return true, "Launched", self.finalLaunch
end

function PartyLaunchScenario:handleTeleportInitFailed()
	local pending = self.finalLaunch
	if self.partyState ~= "Launched" or not pending then
		return false, "NoActiveLaunch", pending
	end
	if pending.lastTeleportResult ~= "AcceptedThenInitFailed" then
		return false, "NoInitFailure", pending
	end
	if pending.teleportAttempts >= self.teleportAttempts then
		return false, "RetryBudgetExhausted", pending
	end
	local accepted, result = self.teleport:teleport(
		pending.reservationCode,
		pending.sessionId,
		pending.memberIds
	)
	pending.teleportAttempts += 1
	pending.lastTeleportResult = result
	if not accepted then
		return false, "TeleportRetryFailed:" .. tostring(result), pending
	end
	return true, "TeleportRetryAccepted", pending
end

function PartyLaunchScenario:removeMember(userId)
	if not self:isMember(userId) or self.partyState ~= "Open" then
		return false
	end
	if userId == self.hostUserId then
		self.partyState = "Cancelled"
		return true
	end
	for index, memberId in ipairs(self.memberIds) do
		if memberId == userId then
			table.remove(self.memberIds, index)
			break
		end
	end
	self.ready[userId] = nil
	self.requestRecords[userId] = nil
	self.membershipRevision += 1
	self.partyRevision += 1
	return true
end

return PartyLaunchScenario
