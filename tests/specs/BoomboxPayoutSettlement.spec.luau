local Scenario = require("../support/BoomboxPayoutScenario")

local function assertFullPayout(test, scenario)
	test:equal(scenario.allowance, 300)
	test:equal(scenario.totalPaid, 300)
	test:equal(scenario.paidTicks, 10)
end

return function(test)
	for _, paidBeforeSettlement in ipairs({ 0, 4, 9 }) do
		test:test(
			string.format(
				"completed boombox catches up from %d paid ticks to exactly $300",
				paidBeforeSettlement
			),
			function()
				local scenario = Scenario.new()
				scenario:seedPaidTicks(paidBeforeSettlement)
				local accepted, status = scenario:settleCompleted(false)
				test:truthy(accepted)
				test:equal(status, "Committed")
				assertFullPayout(test, scenario)
				test:equal(
					scenario.settlementValue,
					(10 - paidBeforeSettlement) * 30
				)
			end
		)
	end

	test:test("duplicate settlement during and after reconciliation cannot overpay", function()
		local scenario = Scenario.new()
		scenario:seedPaidTicks(4)
		local accepted, status = scenario:settleCompleted(true)
		test:truthy(accepted)
		test:equal(status, "NeedsReconciliation")
		assertFullPayout(test, scenario)
		test:equal(scenario.mutationCount, 5)
		test:equal(scenario:settlementRecord().state, "NeedsReconciliation")

		accepted, status = scenario:continueSettlement(false)
		test:truthy(accepted)
		test:equal(status, "NeedsReconciliation")
		assertFullPayout(test, scenario)
		test:equal(scenario.mutationCount, 5)

		local reconciled, reconcileStatus = scenario:reconcileSettlement()
		test:truthy(reconciled)
		test:equal(reconcileStatus, "Reconciled")
		test:equal(scenario:settlementRecord().state, "Committed")
		assertFullPayout(test, scenario)

		accepted, status = scenario:continueSettlement(false)
		test:truthy(accepted)
		test:equal(status, "AlreadyCommitted")
		assertFullPayout(test, scenario)
		test:equal(scenario.mutationCount, 5)
	end)

	test:test("scheduler tick already in flight settles first and leaves one terminal $300 total", function()
		local scenario = Scenario.new()
		scenario:seedPaidTicks(9)
		local tickToken, tickStatus = scenario:beginScheduledTick(10)
		test:truthy(tickToken)
		test:equal(tickStatus, "TickReserved")

		local settled, settlementStatus = scenario:beginSettlement()
		test:falsy(settled)
		test:equal(settlementStatus, "WaitingForTick")

		local tickAccepted = scenario:finishScheduledTick(tickToken, false)
		test:truthy(tickAccepted)
		settled, settlementStatus = scenario:continueSettlement(false)
		test:truthy(settled)
		test:equal(settlementStatus, "NoSettlementNeeded")
		assertFullPayout(test, scenario)
		test:equal(scenario.mutationCount, 10)
		test:equal(scenario:settlementRecord(), nil)
	end)

	test:test("settlement lock wins scheduler race and rejects the late tenth tick", function()
		local scenario = Scenario.new()
		scenario:seedPaidTicks(9)
		local settled, settlementStatus = scenario:settleCompleted(false)
		test:truthy(settled)
		test:equal(settlementStatus, "Committed")
		local tickToken, tickStatus = scenario:beginScheduledTick(10)
		test:equal(tickToken, nil)
		test:equal(tickStatus, "BoomboxSettlementActive")
		assertFullPayout(test, scenario)
		test:equal(scenario.mutationCount, 10)
		test:equal(scenario:settlementRecord().value, 30)
	end)

	test:test("completed payout intent survives release and reload then settles exactly once", function()
		local beforeLeave = Scenario.new()
		beforeLeave:seedPaidTicks(4)
		local intent = beforeLeave:persistCompletionIntent()
		test:equal(intent.paidTicks, 4)
		test:equal(intent.totalPaid, 120)
		test:equal(intent.settlementValue, 180)
		test:equal(intent.completedAt, 123456790)

		local afterReload = beforeLeave:releaseAndReload()
		test:truthy(beforeLeave.released)
		test:equal(
			afterReload.boomboxPendingSettlement.sessionId,
			beforeLeave.sessionId
		)
		local accepted, status = afterReload:continueSettlement(false)
		test:truthy(accepted)
		test:equal(status, "Committed")
		assertFullPayout(test, afterReload)
		test:equal(afterReload.boomboxPendingSettlement, false)

		accepted, status = afterReload:continueSettlement(false)
		test:truthy(accepted)
		test:equal(status, "AlreadyCommitted")
		assertFullPayout(test, afterReload)
		test:equal(afterReload.mutationCount, 5)
	end)

	test:test("final indexed tick awaiting reconciliation finishes as save-pending", function()
		local scenario = Scenario.new()
		scenario:seedPaidTicks(9)
		local accepted, status = scenario:creditScheduledTick(10, true)
		test:truthy(accepted)
		test:equal(status, "NeedsReconciliation")
		scenario:persistCompletionIntent()

		accepted, status = scenario:settleCompleted(false)
		test:truthy(accepted)
		test:equal(status, "NeedsReconciliation")
		local pendingFinish = scenario:finishState()
		test:truthy(pendingFinish.ok)
		test:falsy(pendingFinish.durable)
		test:truthy(pendingFinish.savePending)
		assertFullPayout(test, scenario)

		local reconciled, reconcileStatus = scenario:reconcileTick(10)
		test:truthy(reconciled)
		test:equal(reconcileStatus, "Reconciled")
		accepted, status = scenario:continueSettlement(false)
		test:truthy(accepted)
		test:equal(status, "NoSettlementNeeded")
		local durableFinish = scenario:finishState()
		test:truthy(durableFinish.durable)
		test:falsy(durableFinish.savePending)
		assertFullPayout(test, scenario)
	end)
end
