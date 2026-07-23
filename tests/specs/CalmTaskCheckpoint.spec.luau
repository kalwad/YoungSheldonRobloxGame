local CalmTaskCheckpoint = require("../support/CalmTaskCheckpoint")

local TASK_ORDER = {
	"GeorgeBeer",
	"MaryDishes",
	"MaryTrash",
	"MissyPlush",
	"MedfordBankHack",
}

return function(test)
	test:test("failed start save exposes no task", function()
		local profileState = { totalTasks = 0 }
		local runtimeState = {}
		local started, reason, firstCheckpoint = CalmTaskCheckpoint.attemptStart(profileState, runtimeState, {
			hostUserId = 101,
			taskOrder = TASK_ORDER,
			eligibleUserIds = { 101, 102 },
			startedAtUnix = 1000,
			saveSucceeded = false,
		})
		test:falsy(started)
		test:equal(reason, "CheckpointNotDurable")
		test:equal(runtimeState.activeTask, nil)
		test:equal(firstCheckpoint.hostOrdinal, 1)

		started, reason, firstCheckpoint = CalmTaskCheckpoint.attemptStart(profileState, runtimeState, {
			hostUserId = 101,
			taskOrder = TASK_ORDER,
			eligibleUserIds = { 101 }, -- Retry must not recapture a changed party.
			startedAtUnix = 2000,
			saveSucceeded = true,
		})
		test:truthy(started)
		test:equal(reason, nil)
		test:equal(firstCheckpoint.hostOrdinal, 1)
		test:equal(firstCheckpoint.startedAtUnix, 1000)
		test:deepEqual(firstCheckpoint.eligibleUserIds, { 101, 102 })
		test:equal(runtimeState.exposureCount, 1)
	end)

	test:test("crash after start save recovers the same identity and eligibility once", function()
		local checkpoint = CalmTaskCheckpoint.new(101, 2, TASK_ORDER, { 103, 101, 102 }, 1000)
		local persistedProfile = {
			totalTasks = 2,
			calmTaskCheckpoint = checkpoint,
			calmTaskCheckpointDurable = true,
		}
		local recoveredRuntime = {}
		local started, reason = CalmTaskCheckpoint.attemptStart(persistedProfile, recoveredRuntime, {
			hostUserId = 101,
			taskOrder = TASK_ORDER,
			eligibleUserIds = { 101 },
			startedAtUnix = 1100,
			saveSucceeded = true,
		})
		test:truthy(started)
		test:equal(reason, nil)
		started, reason = CalmTaskCheckpoint.attemptStart(persistedProfile, recoveredRuntime, {
			hostUserId = 101,
			taskOrder = TASK_ORDER,
			eligibleUserIds = { 101 },
			startedAtUnix = 1100,
			saveSucceeded = true,
		})
		test:falsy(started)
		test:equal(reason, "AlreadyExposed")
		test:equal(recoveredRuntime.exposureCount, 1)

		local recovered = CalmTaskCheckpoint.recover(checkpoint, 1100, 90)
		test:equal(recovered.logicalId, checkpoint.logicalId)
		test:equal(recovered.taskId, "MaryTrash")
		test:deepEqual(recovered.eligibleUserIds, { 101, 102, 103 })
		test:equal(recovered.recoveryGraceExpiresAt, 1190)
	end)

	test:test("recovery rejects invalid host ordinal task and duplicate eligibility", function()
		local checkpoint = CalmTaskCheckpoint.new(101, 4, TASK_ORDER, { 101, 102 }, 1000)
		local valid, reason = CalmTaskCheckpoint.validate(checkpoint, 999, 4, TASK_ORDER)
		test:falsy(valid)
		test:equal(reason, "WrongCheckpointHost")

		valid, reason = CalmTaskCheckpoint.validate(checkpoint, 101, 3, TASK_ORDER)
		test:falsy(valid)
		test:equal(reason, "FutureCheckpoint")

		local wrongTask = {}
		for key, value in pairs(checkpoint) do
			wrongTask[key] = value
		end
		wrongTask.taskId = "MaryTrash"
		valid, reason = CalmTaskCheckpoint.validate(wrongTask, 101, 4, TASK_ORDER)
		test:falsy(valid)
		test:equal(reason, "CheckpointIdentityMismatch")

		local duplicateEligibility = {}
		for key, value in pairs(checkpoint) do
			duplicateEligibility[key] = value
		end
		duplicateEligibility.eligibleUserIds = { 101, 102, 102 }
		valid, reason = CalmTaskCheckpoint.validate(duplicateEligibility, 101, 4, TASK_ORDER)
		test:falsy(valid)
		test:equal(reason, "InvalidEligibility")
	end)

	test:test("recovery rejects wrong cursor, host, and logical identity", function()
		local checkpoint = CalmTaskCheckpoint.new(101, 4, TASK_ORDER, { 101 }, 1000)
		local valid, reason = CalmTaskCheckpoint.validate(checkpoint, 101, 5, TASK_ORDER)
		test:falsy(valid)
		test:equal(reason, "StaleCheckpoint")
		valid, reason = CalmTaskCheckpoint.validate(checkpoint, 999, 4, TASK_ORDER)
		test:falsy(valid)
		test:equal(reason, "WrongCheckpointHost")
		checkpoint.logicalId = "101:5:wrong"
		valid, reason = CalmTaskCheckpoint.validate(checkpoint, 101, 4, TASK_ORDER)
		test:falsy(valid)
		test:equal(reason, "CheckpointIdentityMismatch")
	end)

	test:test("absent recovered guest keeps eligibility until the exact grace boundary", function()
		local checkpoint = CalmTaskCheckpoint.recover(
			CalmTaskCheckpoint.new(101, 0, TASK_ORDER, { 101, 102, 103 }, 1000),
			1100,
			90
		)
		local resolutions = {}
		test:equal(CalmTaskCheckpoint.forfeitAbsentAt(checkpoint, { 101, 103 }, resolutions, 1189), 0)
		test:equal(CalmTaskCheckpoint.forfeitAbsentAt(checkpoint, { 101, 103 }, resolutions, 1190), 1)
		test:equal(resolutions[102].status, "Forfeited")
		test:equal(resolutions[103], nil)
	end)

	test:test("detached and loading identities use their own bounded exact grace", function()
		local checkpoint = CalmTaskCheckpoint.recover(
			CalmTaskCheckpoint.new(101, 0, TASK_ORDER, { 101, 102, 103 }, 1000),
			1100,
			90
		)
		local resolutions = {}
		local states = {
			[101] = { active = true },
			[102] = { detached = true, guestGraceExpiresAt = 1200 },
			[103] = { admitted = true, loading = true, loadingGraceExpiresAt = 1210 },
		}
		local forfeited, nextBoundary = CalmTaskCheckpoint.sweepRecoveredEligibility(
			checkpoint,
			states,
			resolutions,
			1190
		)
		test:equal(forfeited, 0)
		test:equal(nextBoundary, 1200)
		test:equal(resolutions[102], nil)
		test:equal(resolutions[103], nil)

		forfeited, nextBoundary = CalmTaskCheckpoint.sweepRecoveredEligibility(
			checkpoint,
			states,
			resolutions,
			1200
		)
		test:equal(forfeited, 1)
		test:equal(resolutions[102].status, "Forfeited")
		test:equal(resolutions[103], nil)
		test:equal(nextBoundary, 1210)

		forfeited, nextBoundary = CalmTaskCheckpoint.sweepRecoveredEligibility(
			checkpoint,
			states,
			resolutions,
			1210
		)
		test:equal(forfeited, 1)
		test:equal(resolutions[103].status, "Forfeited")
		test:equal(nextBoundary, nil)
	end)

	test:test("host ordinal advance and checkpoint clear are one atomic state", function()
		local checkpoint = CalmTaskCheckpoint.new(101, 0, TASK_ORDER, { 101, 102 }, 1000)
		local before = {
			totalTasks = 0,
			calmTaskCheckpoint = checkpoint,
		}
		local after, reason = CalmTaskCheckpoint.commitHostAtomically(before, checkpoint, {})
		test:equal(after, nil)
		test:equal(reason, "GuestNotTerminal")

		after, reason = CalmTaskCheckpoint.commitHostAtomically(before, checkpoint, {
			[102] = { status = "Committed" },
		})
		test:equal(reason, nil)
		test:equal(after.totalTasks, 1)
		test:equal(after.calmTaskCheckpoint, nil)
		-- A crash can restore either complete snapshot, never a mixed state.
		test:equal(before.totalTasks, 0)
		test:equal(before.calmTaskCheckpoint, checkpoint)
	end)
end
