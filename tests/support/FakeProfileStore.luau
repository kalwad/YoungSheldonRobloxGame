local FailureSequence = require("./FailureSequence")

local FakeProfileStore = {}
FakeProfileStore.__index = FakeProfileStore

function FakeProfileStore.new(initialCash)
	local profiles = {}
	for userId, cash in pairs(initialCash or {}) do
		profiles[userId] = {
			cash = cash,
			appliedOperations = {},
		}
	end
	return setmetatable({
		_profiles = profiles,
		_failures = {},
		_attempts = {},
	}, FakeProfileStore)
end

function FakeProfileStore:setOutcomes(userId, outcomes)
	self._failures[userId] = FailureSequence.new(outcomes, "Success")
end

function FakeProfileStore:applyValue(userId, operationId, amount)
	local profile = self._profiles[userId]
	assert(profile, "unknown profile " .. tostring(userId))
	self._attempts[userId] = (self._attempts[userId] or 0) + 1
	if profile.appliedOperations[operationId] then
		return true, "AlreadyCommitted", profile.cash
	end

	local failures = self._failures[userId]
	local outcome = failures and failures:next() or "Success"
	if outcome == "FailBeforeWrite" then
		return false, "RetryableFailure", profile.cash
	end
	if outcome == "FailAfterWrite" then
		profile.cash += amount
		profile.appliedOperations[operationId] = true
		return false, "AmbiguousFailure", profile.cash
	end
	assert(outcome == "Success", "unknown fake store outcome " .. tostring(outcome))

	profile.cash += amount
	profile.appliedOperations[operationId] = true
	return true, "Committed", profile.cash
end

function FakeProfileStore:cash(userId)
	return self._profiles[userId].cash
end

function FakeProfileStore:attemptCount(userId)
	return self._attempts[userId] or 0
end

return FakeProfileStore
