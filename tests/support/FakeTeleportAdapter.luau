local FailureSequence = require("./FailureSequence")

local FakeTeleportAdapter = {}
FakeTeleportAdapter.__index = FakeTeleportAdapter

local function copyArray(values)
	local result = {}
	for index, value in ipairs(values or {}) do
		result[index] = value
	end
	return result
end

function FakeTeleportAdapter.new(options)
	options = options or {}
	return setmetatable({
		_reserveOutcomes = FailureSequence.new(options.reserveOutcomes, "Success"),
		_teleportOutcomes = FailureSequence.new(options.teleportOutcomes, "Success"),
		_reserveCalls = {},
		_teleportCalls = {},
		_nextReservation = 0,
	}, FakeTeleportAdapter)
end

function FakeTeleportAdapter:reserve(placeId, launchKey)
	table.insert(self._reserveCalls, {
		placeId = placeId,
		launchKey = launchKey,
	})
	local outcome = self._reserveOutcomes:next()
	if outcome ~= "Success" then
		return false, outcome
	end
	self._nextReservation += 1
	return true, "reservation-" .. tostring(self._nextReservation)
end

function FakeTeleportAdapter:teleport(reservationCode, sessionId, memberIds)
	table.insert(self._teleportCalls, {
		reservationCode = reservationCode,
		sessionId = sessionId,
		memberIds = copyArray(memberIds),
	})
	local outcome = self._teleportOutcomes:next()
	if outcome == "AcceptedThenInitFailed" then
		return true, outcome
	end
	if outcome ~= "Success" then
		return false, outcome
	end
	return true, "TeleportAccepted"
end

-- Mirrors the lobby helper's single-boolean contract even though the injected
-- adapter retains a richer outcome for deterministic TeleportInitFailed tests.
function FakeTeleportAdapter:requestWithContext(context, reservationCode, sessionId, memberIds)
	if context.attempts >= context.maximumAttempts then
		return false
	end
	context.attempts += 1
	local accepted, outcome = self:teleport(reservationCode, sessionId, memberIds)
	context.lastOutcome = outcome
	return accepted == true
end

function FakeTeleportAdapter:reserveCount()
	return #self._reserveCalls
end

function FakeTeleportAdapter:teleportCount()
	return #self._teleportCalls
end

function FakeTeleportAdapter:lastTeleport()
	local record = self._teleportCalls[#self._teleportCalls]
	if not record then
		return nil
	end
	return {
		reservationCode = record.reservationCode,
		sessionId = record.sessionId,
		memberIds = copyArray(record.memberIds),
	}
end

function FakeTeleportAdapter:teleportCall(index)
	local record = self._teleportCalls[index]
	if not record then
		return nil
	end
	return {
		reservationCode = record.reservationCode,
		sessionId = record.sessionId,
		memberIds = copyArray(record.memberIds),
	}
end

return FakeTeleportAdapter
