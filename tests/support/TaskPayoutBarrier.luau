local TaskPayoutBarrier = {}

local TERMINAL = {
	Committed = true,
	Forfeited = true,
}

local function statusFor(resolutions, userId)
	local resolution = resolutions[userId]
	return type(resolution) == "table" and resolution.status or nil
end

function TaskPayoutBarrier.guestsTerminal(hostUserId, eligibleUserIds, resolutions)
	for _, userId in ipairs(eligibleUserIds) do
		if userId ~= hostUserId and not TERMINAL[statusFor(resolutions, userId)] then
			return false, userId
		end
	end
	return true, nil
end

function TaskPayoutBarrier.canCommitHost(hostUserId, eligibleUserIds, resolutions)
	local guestsReady, blockingUserId = TaskPayoutBarrier.guestsTerminal(
		hostUserId,
		eligibleUserIds,
		resolutions
	)
	if not guestsReady then
		return false, blockingUserId
	end
	return statusFor(resolutions, hostUserId) == nil, nil
end

function TaskPayoutBarrier.canAdvance(hostUserId, eligibleUserIds, resolutions)
	for _, userId in ipairs(eligibleUserIds) do
		if not TERMINAL[statusFor(resolutions, userId)] then
			return false, userId
		end
	end
	return statusFor(resolutions, hostUserId) == "Committed", nil
end

return TaskPayoutBarrier
