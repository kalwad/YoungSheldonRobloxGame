local Policy = require("../support/ValueOperationCommitPolicy")

local function record(overrides)
	local value = {
		id = "op:1:101:abcdefgh",
		sessionId = "party-A",
		kind = "PurchaseBoombox",
		userId = 101,
		value = -900,
		state = "Committed",
		result = { allowance = 100, boomboxPurchased = true },
	}
	for key, child in pairs(overrides or {}) do
		value[key] = child
	end
	return value
end

local function request(existing, overrides)
	local value = {
		activeSessionId = "party-A",
		expectedSessionId = "party-A",
		operationId = existing and existing.id or nil,
		existing = existing,
		kind = "PurchaseBoombox",
		userId = 101,
		value = -900,
	}
	for key, child in pairs(overrides or {}) do
		value[key] = child
	end
	return value
end

return function(test)
	test:test("committed retry returns saved result before now-false authorization", function()
		local authorizeInvoked = false
		local input = request(record())
		input.authorize = function()
			authorizeInvoked = true
			return false, "EntitlementAlreadyOwned"
		end
		local outcome = Policy.evaluate(input)
		test:equal(outcome.status, "AlreadyCommitted")
		test:falsy(outcome.shouldMutate)
		test:equal(outcome.authorizeCalls, 0)
		test:falsy(authorizeInvoked)
		test:equal(outcome.result.boomboxPurchased, true)
	end)

	test:test("pending first application authorizes and denial blocks mutation", function()
		local input = request(record({ state = "Pending", result = {} }))
		input.authorize = function()
			return false, "AllowanceChanged"
		end
		local outcome = Policy.evaluate(input)
		test:equal(outcome.status, "AllowanceChanged")
		test:falsy(outcome.shouldMutate)
		test:equal(outcome.authorizeCalls, 1)
	end)

	test:test("existing operation must match kind user and value", function()
		for _, override in ipairs({
			{ kind = "PurchaseSecretBunker" },
			{ userId = 202 },
			{ value = -899 },
		}) do
			local outcome = Policy.evaluate(request(record(), override))
			test:equal(outcome.status, "OperationIdentityMismatch")
			test:falsy(outcome.shouldMutate)
			test:equal(outcome.authorizeCalls, 0)
		end
	end)

	test:test("stale session fails before a committed terminal return", function()
		local outcome = Policy.evaluate(request(record(), {
			expectedSessionId = "party-B",
		}))
		test:equal(outcome.status, "StaleSession")
		test:falsy(outcome.shouldMutate)
		test:equal(outcome.authorizeCalls, 0)
	end)

	test:test("reconciliation block does not hide terminal retry answers", function()
		local committed = Policy.evaluate(request(record(), {
			reconciliationBlocked = true,
		}))
		test:equal(committed.status, "AlreadyCommitted")

		local needsReconciliation = Policy.evaluate(request(record({
			state = "NeedsReconciliation",
		}), {
			reconciliationBlocked = true,
		}))
		test:equal(needsReconciliation.status, "NeedsReconciliation")

		local pending = Policy.evaluate(request(record({ state = "Pending" }), {
			reconciliationBlocked = true,
		}))
		test:equal(pending.status, "ProfileNotWritable")
		test:falsy(pending.shouldMutate)
	end)
end
