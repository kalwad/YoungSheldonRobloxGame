local Ledger = require("../../CooperTransactionLedger.module")

local function operationId(sequence, userId)
	return string.format(
		"server:%d:%d:00000000-0000-4000-8000-%012d",
		sequence,
		userId,
		sequence
	)
end

local function pending(sequence, sessionId, userId)
	return Ledger.makeRecord(
		operationId(sequence, userId),
		sessionId,
		"TaskReward",
		userId,
		25,
		sequence - 1,
		sequence
	)
end

return function(test)
	test:test("commits one authoritative operation and returns its saved result", function()
		local journal = Ledger.sanitize(nil)
		local record = pending(1, "house-a", 101)
		local began = Ledger.begin(journal, record)
		test:truthy(began)
		local committed = Ledger.commit(journal, record.id, { allowance = 125 }, 2)
		test:truthy(committed)
		test:equal(committed.state, "Committed")
		test:equal(committed.result.allowance, 125)
		test:equal(#journal.pending, 0)
		test:equal(#journal.committed, 1)
	end)

	test:test("rejects a duplicate while its committed result is retained", function()
		local journal = Ledger.sanitize(nil)
		local record = pending(1, "house-a", 101)
		test:truthy(Ledger.begin(journal, record))
		test:truthy(Ledger.commit(journal, record.id, { allowance = 125 }, 2))
		local beganAgain, existing = Ledger.begin(journal, pending(1, "house-a", 101))
		test:falsy(beganAgain)
		test:equal(existing and existing.state, "Committed")
	end)

	test:test("rejects same-session replay after the committed result is evicted", function()
		local journal = Ledger.sanitize(nil)
		for sequence = 1, Ledger.MAX_COMMITTED + 1 do
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(journal, record))
			test:truthy(Ledger.commit(journal, record.id, { revision = sequence }, sequence + 1))
		end
		test:equal(Ledger.lookup(journal, operationId(1, 101)), nil)
		local beganReplay = Ledger.begin(journal, pending(1, "house-a", 101))
		test:falsy(beganReplay, "an evicted operation ID must remain finalized")
	end)

	test:test("rejects replay of a rolled-back operation", function()
		local journal = Ledger.sanitize(nil)
		local record = pending(1, "house-a", 101)
		test:truthy(Ledger.begin(journal, record))
		local rolledBack = Ledger.rollback(journal, record.id, "precondition changed", 2)
		test:truthy(rolledBack)
		test:equal(rolledBack.state, "RolledBack")
		local beganReplay = Ledger.begin(journal, pending(1, "house-a", 101))
		test:falsy(beganReplay, "a rolled-back operation ID must remain finalized")
	end)

	test:test("preserves replay watermarks through sanitization", function()
		local journal = Ledger.sanitize(nil)
		for sequence = 1, Ledger.MAX_COMMITTED + 1 do
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(journal, record))
			test:truthy(Ledger.commit(journal, record.id, {}, sequence + 1))
		end
		local reloaded = Ledger.sanitize(journal)
		local beganReplay = Ledger.begin(reloaded, pending(1, "house-a", 101))
		test:falsy(beganReplay, "a save/load cycle must not revive an evicted operation ID")
	end)

	test:test("retains 256 committed results independently from rollback tombstones", function()
		local journal = Ledger.sanitize(nil)
		for sequence = 1, Ledger.MAX_COMMITTED do
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(journal, record))
			test:truthy(Ledger.commit(journal, record.id, { revision = sequence }, sequence + 1))
		end
		for sequence = Ledger.MAX_COMMITTED + 1, Ledger.MAX_COMMITTED + Ledger.MAX_ROLLED_BACK do
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(journal, record))
			test:truthy(Ledger.rollback(journal, record.id, "test rollback", sequence + 1))
		end
		local reloaded = Ledger.sanitize(journal)
		test:equal(#reloaded.committed, Ledger.MAX_COMMITTED)
		test:equal(#(reloaded.rolledBack or {}), Ledger.MAX_ROLLED_BACK)
		test:equal(Ledger.lookup(reloaded, operationId(1, 101)).state, "Committed")
	end)

	test:test("migrates legacy co-mingled rollback tombstones out of committed history", function()
		local journal = Ledger.sanitize(nil)
		for sequence = 1, Ledger.MAX_COMMITTED do
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(journal, record))
			test:truthy(Ledger.commit(journal, record.id, { revision = sequence }, sequence + 1))
		end
		local legacyTerminal = table.clone(journal.committed)
		for sequence = Ledger.MAX_COMMITTED + 1, Ledger.MAX_COMMITTED + Ledger.MAX_ROLLED_BACK do
			local rollbackJournal = Ledger.sanitize(nil)
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(rollbackJournal, record))
			local rolledBack = Ledger.rollback(rollbackJournal, record.id, "legacy rollback", sequence + 1)
			test:truthy(rolledBack)
			table.insert(legacyTerminal, rolledBack)
		end

		local migrated = Ledger.sanitize({
			version = Ledger.VERSION,
			pending = {},
			committed = legacyTerminal,
		})
		test:equal(#migrated.committed, Ledger.MAX_COMMITTED)
		test:equal(#(migrated.rolledBack or {}), Ledger.MAX_ROLLED_BACK)
		test:equal(Ledger.lookup(migrated, operationId(1, 101)).state, "Committed")
	end)

	test:test("rejects an evicted rollback replay after reload", function()
		local journal = Ledger.sanitize(nil)
		for sequence = 1, Ledger.MAX_ROLLED_BACK + 1 do
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(journal, record))
			test:truthy(Ledger.rollback(journal, record.id, "test rollback", sequence + 1))
		end
		test:equal(Ledger.lookup(journal, operationId(1, 101)), nil)
		local reloaded = Ledger.sanitize(journal)
		local beganReplay = Ledger.begin(reloaded, pending(1, "house-a", 101))
		test:falsy(beganReplay, "an evicted rollback tombstone must remain below the issued watermark")
	end)

	test:test("pending and reconciliation records reserve the issuance high-water mark", function()
		local journal = Ledger.sanitize(nil)
		local record = pending(7, "house-a", 101)
		test:truthy(Ledger.begin(journal, record))
		test:equal(Ledger.nextSequence(journal), 8)
		local staleBegan = Ledger.begin(journal, pending(6, "house-a", 101))
		test:falsy(staleBegan, "a lower sequence cannot begin behind a server-issued pending record")

		test:truthy(Ledger.commit(journal, record.id, { allowance = 125 }, 8))
		test:truthy(Ledger.markNeedsReconciliation(journal, record.id, "ambiguous save", "SAVE_UNCONFIRMED"))
		local reloaded = Ledger.sanitize(journal)
		test:equal(Ledger.nextSequence(reloaded), 8)
		local staleAfterReload = Ledger.begin(reloaded, pending(6, "house-a", 101))
		test:falsy(staleAfterReload, "reconciliation must retain its issued high-water mark after reload")
	end)

	test:test("fails closed when the authoritative sequence space is exhausted", function()
		local journal = Ledger.sanitize({
			version = Ledger.VERSION,
			issuedHighWater = Ledger.MAX_SEQUENCE,
			pending = {},
			committed = {},
		})
		test:throws(function()
			Ledger.issue(
				journal,
				"house-a",
				"TaskReward",
				101,
				25,
				0,
				1,
				"00000000-0000-4000-8000-000000000001"
			)
		end, "Operation sequence space is exhausted")
		test:equal(#journal.pending, 0)
		test:equal(#journal.committed, 0)
	end)

	test:test("out-of-order terminal callbacks do not regress the issuance watermark", function()
		local journal = Ledger.sanitize(nil)
		local first = pending(1, "house-a", 101)
		local second = pending(2, "house-a", 101)
		test:truthy(Ledger.begin(journal, first))
		test:truthy(Ledger.begin(journal, second))
		test:truthy(Ledger.commit(journal, second.id, { revision = 2 }, 3))
		test:truthy(Ledger.commit(journal, first.id, { revision = 1 }, 4))
		test:equal(Ledger.nextSequence(journal), 3)

		local reloaded = Ledger.sanitize(journal)
		test:equal(Ledger.nextSequence(reloaded), 3)
		local replay = Ledger.begin(reloaded, pending(1, "house-a", 101))
		test:falsy(replay)
	end)

	test:test("out-of-order committed trimming cannot revive the evicted highest sequence", function()
		local highest = Ledger.MAX_COMMITTED + 1
		local highestJournal = Ledger.sanitize(nil)
		local highestRecord = pending(highest, "house-a", 101)
		test:truthy(Ledger.begin(highestJournal, highestRecord))
		test:truthy(Ledger.commit(highestJournal, highestRecord.id, {}, highest + 1))
		local outOfOrder = { highestJournal.committed[1] }
		for sequence = 1, Ledger.MAX_COMMITTED do
			local one = Ledger.sanitize(nil)
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(one, record))
			test:truthy(Ledger.commit(one, record.id, {}, sequence + 1))
			table.insert(outOfOrder, one.committed[1])
		end

		local reloaded = Ledger.sanitize({
			version = Ledger.VERSION,
			pending = {},
			committed = outOfOrder,
		})
		test:equal(Ledger.lookup(reloaded, highestRecord.id), nil)
		local replay = Ledger.begin(reloaded, pending(highest, "house-a", 101))
		test:falsy(replay, "trimming detail must not lower the persistent issued watermark")
	end)

	test:test("out-of-order rollback trimming cannot revive the evicted highest sequence", function()
		local highest = Ledger.MAX_ROLLED_BACK + 1
		local highestJournal = Ledger.sanitize(nil)
		local highestRecord = pending(highest, "house-a", 101)
		test:truthy(Ledger.begin(highestJournal, highestRecord))
		test:truthy(Ledger.rollback(highestJournal, highestRecord.id, "highest first", highest + 1))
		local outOfOrder = { highestJournal.rolledBack[1] }
		for sequence = 1, Ledger.MAX_ROLLED_BACK do
			local one = Ledger.sanitize(nil)
			local record = pending(sequence, "house-a", 101)
			test:truthy(Ledger.begin(one, record))
			test:truthy(Ledger.rollback(one, record.id, "lower later", sequence + 1))
			table.insert(outOfOrder, one.rolledBack[1])
		end

		local reloaded = Ledger.sanitize({
			version = Ledger.VERSION,
			pending = {},
			committed = {},
			rolledBack = outOfOrder,
		})
		test:equal(Ledger.lookup(reloaded, highestRecord.id), nil)
		local replay = Ledger.begin(reloaded, pending(highest, "house-a", 101))
		test:falsy(replay, "rollback trimming must not lower the persistent issued watermark")
	end)
end
