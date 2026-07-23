local TransactionLedger = require("../support/TransactionLedger")

return function(test)
	test:test("issues server-owned operation IDs and commits a value once", function()
		local ledger = TransactionLedger.new({ sessionId = "house-a" })
		local operation = ledger:issue("TaskReward", "101", 50, 7)
		local cash = 100
		local first = ledger:commit(operation.operationId, function(authoritative)
			cash += authoritative.authoritativeValue
			return { cash = cash, revision = 8 }
		end)
		test:truthy(first.ok)
		test:truthy(first.applied)
		test:equal(cash, 150)
		test:equal(first.result.revision, 8)

		local duplicate = ledger:commit(operation.operationId, function()
			cash += 9999
		end)
		test:truthy(duplicate.ok)
		test:falsy(duplicate.applied)
		test:equal(duplicate.code, "AlreadyCommitted")
		test:equal(cash, 150)
		test:deepEqual(duplicate.result, first.result)
	end)

	test:test("records a fail-before-write and allows deterministic reconciliation", function()
		local ledger = TransactionLedger.new({ sessionId = "house-a" })
		local operation = ledger:issue("CapturePenalty", "101", 75, 3)
		local cash = 200
		local failed = ledger:commit(operation.operationId, function()
			error("injected datastore timeout before write")
		end)
		test:falsy(failed.ok)
		test:equal(failed.state, "NeedsReconciliation")
		test:equal(cash, 200)

		local retried = ledger:commit(operation.operationId, function(authoritative)
			cash -= authoritative.authoritativeValue
			return { cash = cash }
		end)
		test:truthy(retried.applied)
		test:equal(cash, 125)
		test:equal(ledger:get(operation.operationId).attempts, 2)
	end)

	test:test("rejects unknown client-supplied operation IDs", function()
		local ledger = TransactionLedger.new({ sessionId = "house-a" })
		local applied = false
		local result = ledger:commit("house-a:999:CashGrant:101", function()
			applied = true
		end)
		test:falsy(result.ok)
		test:equal(result.code, "UnknownOperation")
		test:falsy(applied)
	end)

	test:test("rejects stale session callbacks", function()
		local ledger = TransactionLedger.new({ sessionId = "house-a" })
		local old = ledger:issue("TaskReward", "101", 50, 1)
		ledger:supersedeSession("house-b")
		local result = ledger:commit(old.operationId, function()
			error("must not execute")
		end)
		test:falsy(result.ok)
		test:equal(result.code, "StaleSession")
	end)

	test:test("bounds recent results without permitting an evicted replay", function()
		local ledger = TransactionLedger.new({ sessionId = "house-a", capacity = 1 })
		local first = ledger:issue("TaskReward", "101", 10, 1)
		ledger:commit(first.operationId, function() return { revision = 2 } end)
		local second = ledger:issue("TaskReward", "101", 20, 2)
		ledger:commit(second.operationId, function() return { revision = 3 } end)
		test:equal(ledger:get(first.operationId), nil)

		local applied = false
		local replay = ledger:commit(first.operationId, function()
			applied = true
		end)
		test:falsy(replay.ok)
		test:equal(replay.code, "AlreadyFinalizedResultEvicted")
		test:falsy(applied)
	end)

	test:test("cannot roll back a committed value operation", function()
		local ledger = TransactionLedger.new({ sessionId = "house-a" })
		local operation = ledger:issue("Purchase", "101", 400, 9)
		ledger:commit(operation.operationId, function() return { owned = true } end)
		local rolledBack = ledger:rollBack(operation.operationId, "late callback")
		test:falsy(rolledBack.ok)
		test:equal(rolledBack.code, "AlreadyCommitted")
	end)
end
