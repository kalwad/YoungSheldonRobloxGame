local Migration = require("../support/ProfileSchema12MigrationOracle")
local fixtures = require("../support/ProfileSchema12Fixtures")

local Ledger = Migration.productionLedger()

local function countKeys(values)
	local count = 0
	for _ in pairs(values) do
		count += 1
	end
	return count
end

local function record(id, state, index)
	return {
		id = id,
		sessionId = "bounds-session",
		kind = "BoundsTest",
		userId = 1000 + index,
		value = index,
		preconditionRevision = index,
		state = state,
		createdAt = index,
		committedAt = state == "Committed" and index + 1 or 0,
		result = {},
	}
end

return function(test)
	test:test("uses the production schema-12 journal contract", function()
		test:equal(Ledger.VERSION, 1)
		test:equal(Ledger.MAX_PENDING, 32)
		test:equal(Ledger.MAX_COMMITTED, 256)
	end)

	test:test("migrates a complete schema-11 profile without losing a field", function()
		local fixture = fixtures.canonicalSchema11
		local migrated = Migration.migrate(fixture.input)
		test:deepEqual(migrated, fixture.expected)
		for _, fieldName in ipairs(fixture.preservedFields) do
			test:deepEqual(migrated[fieldName], fixture.input[fieldName], fieldName .. " changed")
		end
		test:equal(#fixture.preservedFields, 34)
	end)

	test:test("adds an empty journal when schema 11 has none", function()
		local migrated = Migration.migrate(fixtures.canonicalSchema11.input)
		test:deepEqual(migrated.operationJournal, {
			version = 1,
			pending = {},
			committed = {},
		})
	end)

	test:test("schema-12 migration is idempotent", function()
		local first = Migration.migrate(fixtures.canonicalSchema11.input)
		local second = Migration.migrate(first)
		test:deepEqual(second, first)
	end)

	test:test("production sanitizer rejects malformed and duplicate journal records", function()
		local fixture = fixtures.malformedJournal
		local sanitized = Ledger.sanitize(fixture.input)
		test:deepEqual(sanitized, fixture.expected)
		test:deepEqual(Ledger.sanitize(sanitized), sanitized)
	end)

	test:test("production sanitizer bounds committed and pending history", function()
		local raw = { version = -1, committed = {}, pending = {} }
		for index = 1, 260 do
			table.insert(raw.committed, record(string.format("committed-%03d", index), "Committed", index))
		end
		for index = 1, 36 do
			table.insert(raw.pending, record(string.format("pending-%03d", index), "Pending", index))
		end
		local sanitized = Ledger.sanitize(raw)
		test:equal(#sanitized.committed, 256)
		test:equal(sanitized.committed[1].id, "committed-005")
		test:equal(sanitized.committed[256].id, "committed-260")
		test:equal(#sanitized.pending, 32)
		test:equal(sanitized.pending[1].id, "pending-005")
		test:equal(sanitized.pending[32].id, "pending-036")
		test:deepEqual(Ledger.sanitize(sanitized), sanitized)
	end)

	test:test("production sanitizer bounds result payload keys", function()
		local result = {}
		for index = 1, 20 do
			result[string.format("field%02d", index)] = index
		end
		local raw = {
			committed = {
				{
					id = "result-bounds-0001",
					sessionId = "house-result",
					kind = "TaskReward",
					userId = 404,
					value = 25,
					preconditionRevision = 1,
					state = "Committed",
					createdAt = 1,
					committedAt = 2,
					result = result,
				},
			},
			pending = {},
		}
		local sanitized = Ledger.sanitize(raw)
		test:equal(countKeys(sanitized.committed[1].result), 16)
		test:deepEqual(Ledger.sanitize(sanitized), sanitized)
	end)
end
