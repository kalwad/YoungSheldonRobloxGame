local TaskPayoutBarrier = require("../support/TaskPayoutBarrier")

return function(test)
	test:test("unresolved guest blocks the host checkpoint and task advance", function()
		local resolutions = {
			[102] = { status = "Committed" },
		}
		local canCommitHost, blocker = TaskPayoutBarrier.canCommitHost(101, { 101, 102, 103 }, resolutions)
		test:falsy(canCommitHost)
		test:equal(blocker, 103)
		local canAdvance = TaskPayoutBarrier.canAdvance(101, { 101, 102, 103 }, resolutions)
		test:falsy(canAdvance)
	end)

	test:test("guest reconciliation blocks the host until durable", function()
		local resolutions = {
			[102] = { status = "NeedsReconciliation" },
		}
		local canCommitHost, blocker = TaskPayoutBarrier.canCommitHost(101, { 101, 102 }, resolutions)
		test:falsy(canCommitHost)
		test:equal(blocker, 102)

		resolutions[102] = { status = "Committed" }
		canCommitHost, blocker = TaskPayoutBarrier.canCommitHost(101, { 101, 102 }, resolutions)
		test:truthy(canCommitHost)
		test:equal(blocker, nil)
	end)

	test:test("exact-expiry forfeit is terminal but does not invent a reward", function()
		local resolutions = {
			[102] = { status = "Forfeited", reason = "GuestReconnectGraceExpired" },
		}
		local canCommitHost = TaskPayoutBarrier.canCommitHost(101, { 101, 102 }, resolutions)
		test:truthy(canCommitHost)
		resolutions[101] = { status = "Committed" }
		local canAdvance = TaskPayoutBarrier.canAdvance(101, { 101, 102 }, resolutions)
		test:truthy(canAdvance)
	end)

	test:test("host commit is offered exactly once after every guest is terminal", function()
		local resolutions = {
			[102] = { status = "Committed" },
			[103] = { status = "Forfeited" },
		}
		test:truthy(TaskPayoutBarrier.canCommitHost(101, { 101, 102, 103 }, resolutions))
		resolutions[101] = { status = "Committed" }
		test:falsy(TaskPayoutBarrier.canCommitHost(101, { 101, 102, 103 }, resolutions))
		test:truthy(TaskPayoutBarrier.canAdvance(101, { 101, 102, 103 }, resolutions))
	end)
end
