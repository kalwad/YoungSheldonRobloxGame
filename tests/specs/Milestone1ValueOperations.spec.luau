local Ledger = require("../../CooperTransactionLedger.module")

local function issueAndCommit(journal, sequence, kind, value, result)
	local record = Ledger.makeRecord(
		string.format("op:%d:101:domain-operation-%08d", sequence, sequence),
		"party-m1",
		kind,
		101,
		value,
		sequence - 1,
		sequence
	)
	local began, existing = Ledger.begin(journal, record)
	if not began then
		return existing, false
	end
	return Ledger.commit(journal, record.id, result or {}, sequence + 1), true
end

return function(test)
	test:test("CVO-001/CVO-002 candy token has one stable production collection and sale identity", function()
		local token = "00000000-0000-4000-8000-000000000101"
		local produce = Ledger.logicalKind("CandyProduce", "101:7:123456")
		local collect = Ledger.logicalKind("CandyCollect", token)
		local sale = Ledger.logicalKind("CandySale", token)
		test:equal(produce, "CandyProduce:101:7:123456")
		test:equal(collect, "CandyCollect:" .. token)
		test:equal(sale, "CandySale:" .. token)

		local journal = Ledger.sanitize(nil)
		local committed = issueAndCommit(journal, 1, sale, 3000, {
			payout = 3000,
			batchesSold = 1,
			batchToken = token,
		})
		test:truthy(committed)
		test:equal(committed.value, 3000)
		test:equal(committed.result.batchesSold, 1)
		local duplicateBegan, duplicate = Ledger.begin(
			journal,
			Ledger.makeRecord(
				committed.id,
				"party-m1",
				sale,
				101,
				3000,
				0,
				1
			)
		)
		test:falsy(duplicateBegan)
		test:equal(duplicate and duplicate.state, "Committed")
		test:equal(#journal.committed, 1)
	end)

	test:test("BVO-001/BVO-002 ten indexed boombox ticks total exactly 300 and duplicates do not add an eleventh", function()
		local journal = Ledger.sanitize(nil)
		local total = 0
		local runId = "boombox:101:9:123456789"
		for tickIndex = 1, 10 do
			local kind = Ledger.logicalKind("BoomboxTick", runId .. ":" .. tostring(tickIndex))
			test:truthy(kind)
			local committed, applied = issueAndCommit(journal, tickIndex, kind, 30, {
				paidTicks = tickIndex,
				totalPaid = tickIndex * 30,
			})
			test:truthy(applied)
			test:truthy(committed)
			total += committed.value
		end
		test:equal(total, 300)
		test:equal(#journal.committed, 10)

		local final = journal.committed[10]
		local duplicateBegan, duplicate = Ledger.begin(
			journal,
			Ledger.makeRecord(
				final.id,
				"party-m1",
				final.kind,
				101,
				30,
				9,
				10
			)
		)
		test:falsy(duplicateBegan)
		test:equal(duplicate and duplicate.result.paidTicks, 10)
		test:equal(#journal.committed, 10)
	end)

	test:test("BVO-003 completed-song settlement pays every missing indexed tick exactly once", function()
		local journal = Ledger.sanitize(nil)
		local runId = "boombox:101:11:123456790"
		local total = 0
		for tickIndex = 1, 4 do
			local committed = issueAndCommit(
				journal,
				tickIndex,
				Ledger.logicalKind("BoomboxTick", runId .. ":" .. tostring(tickIndex)),
				30,
				{ paidTicks = tickIndex, totalPaid = tickIndex * 30 }
			)
			total += committed.value
		end
		local settlementKind = Ledger.logicalKind("BoomboxSettle", runId)
		local settlement, applied = issueAndCommit(journal, 5, settlementKind, 180, {
			paidTicks = 10,
			totalPaid = 300,
			settlementValue = 180,
		})
		test:truthy(applied)
		total += settlement.value
		test:equal(total, 300)

		local duplicateBegan, duplicate = Ledger.begin(
			journal,
			Ledger.makeRecord(
				settlement.id,
				"party-m1",
				settlementKind,
				101,
				180,
				4,
				5
			)
		)
		test:falsy(duplicateBegan)
		test:equal(duplicate and duplicate.result.totalPaid, 300)
		test:equal(#journal.committed, 5)
	end)

	test:test("BVO-004 completed-song settlement identity is stable across reconciliation retry", function()
		local runId = "boombox:101:12:123456791"
		test:equal(
			Ledger.logicalKind("BoomboxSettle", runId),
			Ledger.logicalKind("BoomboxSettle", runId)
		)
	end)

	test:test("IVO-001 all paid install transitions fit the persistent identity contract", function()
		local kinds = {
			Ledger.logicalKind("InstallTaskUpgrade", "TrashBot"),
			Ledger.logicalKind("InstallTaskUpgrade", "HackerBot"),
			"InstallChemistrySetup",
			"InstallBoombox",
			Ledger.logicalKind("InstallMachineStage", 11),
		}
		local seen = {}
		for _, kind in ipairs(kinds) do
			test:truthy(type(kind) == "string" and #kind <= 64)
			test:falsy(seen[kind])
			seen[kind] = true
		end
	end)

	test:test("operation keys reject client-shaped text path syntax controls and oversize data", function()
		for _, invalid in ipairs({
			"",
			"contains spaces",
			"../profile",
			"line\nbreak",
			string.rep("a", 64),
		}) do
			test:equal(Ledger.logicalKind("CandySale", invalid), nil)
		end
		test:equal(Ledger.logicalKind("", "valid"), nil)
		test:equal(Ledger.logicalKind(string.rep("p", 33), "valid"), nil)
	end)
end
