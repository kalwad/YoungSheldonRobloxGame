local CalmTaskCheckpoint = {}

local TERMINAL = {
	Committed = true,
	Forfeited = true,
}

local function copyArray(source)
	local copy = {}
	for index, value in ipairs(source) do
		copy[index] = value
	end
	return copy
end

local function expectedTask(taskOrder, hostOrdinal)
	return taskOrder[((hostOrdinal - 1) % #taskOrder) + 1]
end

function CalmTaskCheckpoint.new(hostUserId, totalTasks, taskOrder, eligibleUserIds, startedAtUnix)
	assert(type(hostUserId) == "number" and hostUserId > 0 and hostUserId % 1 == 0)
	assert(type(totalTasks) == "number" and totalTasks >= 0 and totalTasks % 1 == 0)
	assert(type(taskOrder) == "table" and #taskOrder > 0)
	local seen = {}
	local eligible = copyArray(eligibleUserIds)
	for _, userId in ipairs(eligible) do
		assert(type(userId) == "number" and userId > 0 and userId % 1 == 0)
		assert(not seen[userId], "duplicate eligible identity")
		seen[userId] = true
	end
	assert(seen[hostUserId], "host must be eligible")
	table.sort(eligible)

	local hostOrdinal = totalTasks + 1
	local taskId = expectedTask(taskOrder, hostOrdinal)
	return {
		version = 1,
		hostUserId = hostUserId,
		hostOrdinal = hostOrdinal,
		taskId = taskId,
		logicalId = string.format("%d:%d:%s", hostUserId, hostOrdinal, taskId),
		eligibleUserIds = eligible,
		startedAtUnix = startedAtUnix,
		recoveryGraceExpiresAt = 0,
	}
end

function CalmTaskCheckpoint.validate(checkpoint, hostUserId, totalTasks, taskOrder)
	if type(checkpoint) ~= "table" or checkpoint.version ~= 1 then
		return false, "MissingCheckpoint"
	end
	if checkpoint.hostUserId ~= hostUserId then
		return false, "WrongCheckpointHost"
	end
	if type(checkpoint.eligibleUserIds) ~= "table" then
		return false, "InvalidEligibility"
	end
	local seen = {}
	for _, userId in ipairs(checkpoint.eligibleUserIds) do
		if type(userId) ~= "number" or userId <= 0 or userId % 1 ~= 0 or seen[userId] then
			return false, "InvalidEligibility"
		end
		seen[userId] = true
	end
	if not seen[hostUserId] then
		return false, "InvalidEligibility"
	end
	local expectedOrdinal = totalTasks + 1
	if checkpoint.hostOrdinal < expectedOrdinal then
		return false, "StaleCheckpoint"
	elseif checkpoint.hostOrdinal > expectedOrdinal then
		return false, "FutureCheckpoint"
	end
	local taskId = expectedTask(taskOrder, expectedOrdinal)
	local logicalId = string.format("%d:%d:%s", hostUserId, expectedOrdinal, taskId)
	if checkpoint.taskId ~= taskId or checkpoint.logicalId ~= logicalId then
		return false, "CheckpointIdentityMismatch"
	end
	return true, nil
end

-- Pure task-start model used to pin the save-before-exposure contract. The
-- durable profile checkpoint and the transient runtime task intentionally live
-- in separate tables so a test can model a server crash between those steps.
function CalmTaskCheckpoint.attemptStart(profileState, runtimeState, options)
	if profileState.calmTaskCheckpoint == nil then
		profileState.calmTaskCheckpoint = CalmTaskCheckpoint.new(
			options.hostUserId,
			profileState.totalTasks,
			options.taskOrder,
			options.eligibleUserIds,
			options.startedAtUnix
		)
		profileState.calmTaskCheckpointDurable = false
	end

	local checkpoint = profileState.calmTaskCheckpoint
	local valid, reason = CalmTaskCheckpoint.validate(
		checkpoint,
		options.hostUserId,
		profileState.totalTasks,
		options.taskOrder
	)
	if not valid then
		return false, reason, checkpoint
	end
	if profileState.calmTaskCheckpointDurable ~= true then
		if options.saveSucceeded ~= true then
			return false, "CheckpointNotDurable", checkpoint
		end
		profileState.calmTaskCheckpointDurable = true
	end
	if runtimeState.activeTask ~= nil then
		if runtimeState.activeTask.logicalId == checkpoint.logicalId then
			return false, "AlreadyExposed", checkpoint
		end
		return false, "DifferentTaskAlreadyActive", checkpoint
	end
	runtimeState.activeTask = {
		logicalId = checkpoint.logicalId,
		taskId = checkpoint.taskId,
		eligibleUserIds = copyArray(checkpoint.eligibleUserIds),
	}
	runtimeState.exposureCount = (runtimeState.exposureCount or 0) + 1
	return true, nil, checkpoint
end

function CalmTaskCheckpoint.canExpose(checkpointDurable, checkpoint, hostUserId, totalTasks, taskOrder)
	if checkpointDurable ~= true then
		return false, "CheckpointNotDurable"
	end
	return CalmTaskCheckpoint.validate(checkpoint, hostUserId, totalTasks, taskOrder)
end

function CalmTaskCheckpoint.recover(checkpoint, nowUnix, graceSeconds)
	local recovered = {}
	for key, value in pairs(checkpoint) do
		recovered[key] = type(value) == "table" and copyArray(value) or value
	end
	if recovered.recoveryGraceExpiresAt <= 0 then
		recovered.recoveryGraceExpiresAt = nowUnix + graceSeconds
	end
	return recovered
end

function CalmTaskCheckpoint.sweepRecoveredEligibility(checkpoint, memberStateByUserId, resolutions, nowUnix)
	if nowUnix < checkpoint.recoveryGraceExpiresAt then
		return 0, checkpoint.recoveryGraceExpiresAt
	end
	local forfeited = 0
	local nextBoundary = nil
	for _, userId in ipairs(checkpoint.eligibleUserIds) do
		if userId ~= checkpoint.hostUserId and resolutions[userId] == nil then
			local member = memberStateByUserId[userId]
			local retainedUntil = nil
			if type(member) == "table" then
				if member.active == true then
					retainedUntil = math.huge
				elseif member.detached == true then
					retainedUntil = member.guestGraceExpiresAt
				elseif member.loading == true or member.admitted == true then
					retainedUntil = member.loadingGraceExpiresAt
				end
			end
			if type(retainedUntil) == "number" and retainedUntil > nowUnix then
				if retainedUntil < math.huge
					and (nextBoundary == nil or retainedUntil < nextBoundary)
				then
					nextBoundary = retainedUntil
				end
			else
				resolutions[userId] = {
					status = "Forfeited",
					reason = "RecoveredTaskGraceExpired",
				}
				forfeited += 1
			end
		end
	end
	return forfeited, nextBoundary
end

function CalmTaskCheckpoint.forfeitAbsentAt(checkpoint, activeUserIds, resolutions, nowUnix)
	local states = {}
	for _, userId in ipairs(activeUserIds) do
		states[userId] = { active = true }
	end
	return CalmTaskCheckpoint.sweepRecoveredEligibility(checkpoint, states, resolutions, nowUnix)
end

function CalmTaskCheckpoint.commitHostAtomically(profileState, checkpoint, resolutions)
	for _, userId in ipairs(checkpoint.eligibleUserIds) do
		if userId ~= checkpoint.hostUserId then
			local resolution = resolutions[userId]
			if type(resolution) ~= "table" or not TERMINAL[resolution.status] then
				return nil, "GuestNotTerminal"
			end
		end
	end
	if profileState.totalTasks + 1 ~= checkpoint.hostOrdinal
		or profileState.calmTaskCheckpoint ~= checkpoint
	then
		return nil, "CheckpointPreconditionChanged"
	end
	return {
		totalTasks = profileState.totalTasks + 1,
		calmTaskCheckpoint = nil,
	}, nil
end

return CalmTaskCheckpoint
