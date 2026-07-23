local FakeProfileStore = require("../support/FakeProfileStore")
local TwoClientTaskScenario = require("../support/TwoClientTaskScenario")

local function scenario(store)
	return TwoClientTaskScenario.new({
		store = store,
		memberIds = { 101, 102 },
		reward = 55,
		sessionId = "house-two-client",
		taskVersion = 3,
	})
end

return function(test)
	test:test("same-frame two-client completion advances once and pays each once", function()
		local store = FakeProfileStore.new({ [101] = 10, [102] = 20 })
		local task = scenario(store)
		local firstOk, firstCode = task:submitCompletion(101, 999999)
		local secondOk, secondCode = task:submitCompletion(102, -500)
		test:truthy(firstOk)
		test:equal(firstCode, "Completed")
		test:truthy(secondOk)
		test:equal(secondCode, "AlreadyCompleted")
		test:equal(task.winner, 101)
		test:equal(task.advanceCount, 1)
		test:equal(store:cash(101), 65)
		test:equal(store:cash(102), 75)
		test:equal(store:attemptCount(101), 1)
		test:equal(store:attemptCount(102), 1)
	end)

	test:test("one fail-before-write retries only the incomplete reward", function()
		local store = FakeProfileStore.new({ [101] = 0, [102] = 0 })
		store:setOutcomes(102, { "FailBeforeWrite", "Success" })
		local task = scenario(store)
		local ok, code = task:submitCompletion(101, 55)
		test:falsy(ok)
		test:equal(code, "ReconciliationPending")
		test:equal(task.advanceCount, 0)
		test:equal(store:cash(101), 55)
		test:equal(store:cash(102), 0)

		ok, code = task:submitCompletion(102, 55)
		test:truthy(ok)
		test:equal(code, "Completed")
		test:equal(task.advanceCount, 1)
		test:equal(store:cash(101), 55)
		test:equal(store:cash(102), 55)
		test:equal(store:attemptCount(101), 1)
		test:equal(store:attemptCount(102), 2)
	end)

	test:test("ambiguous fail-after-write is deduplicated on retry", function()
		local store = FakeProfileStore.new({ [101] = 0, [102] = 0 })
		store:setOutcomes(102, { "FailAfterWrite", "Success" })
		local task = scenario(store)
		local ok = task:submitCompletion(101, 55)
		test:falsy(ok)
		test:equal(store:cash(102), 55)
		ok = task:submitCompletion(102, 55)
		test:truthy(ok)
		test:equal(store:cash(102), 55)
		test:equal(store:attemptCount(102), 2)
		test:equal(task.advanceCount, 1)
	end)

	test:test("outsider completion cannot trigger rewards", function()
		local store = FakeProfileStore.new({ [101] = 0, [102] = 0 })
		local task = scenario(store)
		local ok, code = task:submitCompletion(999, 55)
		test:falsy(ok)
		test:equal(code, "NotEligible")
		test:equal(task.state, "Active")
		test:equal(store:cash(101), 0)
		test:equal(store:cash(102), 0)
	end)

	test:test("completion spam after closure cannot pay or advance again", function()
		local store = FakeProfileStore.new({ [101] = 0, [102] = 0 })
		local task = scenario(store)
		task:submitCompletion(101, 55)
		for index = 1, 50 do
			local actor = if index % 2 == 0 then 101 else 102
			local ok, code = task:submitCompletion(actor, 1000000)
			test:truthy(ok)
			test:equal(code, "AlreadyCompleted")
		end
		test:equal(store:cash(101), 55)
		test:equal(store:cash(102), 55)
		test:equal(task.advanceCount, 1)
	end)
end
