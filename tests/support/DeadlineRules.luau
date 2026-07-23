local DeadlineRules = {}

local PRE_REVEAL = {
	[1] = 300,
	[2] = 240,
	[3] = 204,
}

local POST_REVEAL = {
	[1] = 180,
	[2] = 153,
	[3] = 126,
}

local function assertPositiveInteger(value, label)
	assert(type(value) == "number" and value % 1 == 0 and value >= 1, label .. " must be a positive integer")
end

local function assertFinite(value, label)
	assert(type(value) == "number" and value == value and value > -math.huge and value < math.huge,
		label .. " must be finite")
end

function DeadlineRules.preReveal(cycleIndex, taskPosition, naturalTimeoutOccurred)
	assertPositiveInteger(cycleIndex, "cycleIndex")
	assertPositiveInteger(taskPosition, "taskPosition")
	assert(type(naturalTimeoutOccurred) == "boolean", "naturalTimeoutOccurred must be a boolean")

	local duration = PRE_REVEAL[cycleIndex] or PRE_REVEAL[3]
	local forceReveal = cycleIndex >= 4 and taskPosition == 1 and not naturalTimeoutOccurred
	return {
		duration = forceReveal and 0 or duration,
		visible = false,
		failureEnabled = cycleIndex > 1,
		forceReveal = forceReveal,
		storyOnly = cycleIndex == 1,
	}
end

function DeadlineRules.postReveal(postRevealCycleIndex)
	assertPositiveInteger(postRevealCycleIndex, "postRevealCycleIndex")
	return {
		duration = POST_REVEAL[postRevealCycleIndex] or 90,
		visible = true,
		failureEnabled = true,
		forceReveal = false,
		storyOnly = false,
	}
end

function DeadlineRules.deadlineFrom(startedAt, duration)
	assertFinite(startedAt, "startedAt")
	assertFinite(duration, "duration")
	assert(duration >= 0, "duration cannot be negative")
	return startedAt + duration
end

function DeadlineRules.isExpired(now, deadline)
	assertFinite(now, "now")
	assertFinite(deadline, "deadline")
	return now >= deadline
end

function DeadlineRules.capturePenalty(currentCash, cycleIndex, storyReveal)
	assertFinite(currentCash, "currentCash")
	assert(currentCash >= 0, "currentCash cannot be negative")
	assertPositiveInteger(cycleIndex, "cycleIndex")
	assert(type(storyReveal) == "boolean", "storyReveal must be a boolean")
	if storyReveal then
		return 0
	end
	return math.min(currentCash, 25 * (cycleIndex - 1), 500)
end

return DeadlineRules
