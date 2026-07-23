local Migration = require("../support/ProfileMigrationOracle")
local fixtures = require("../support/ProfileMigrationFixtures")

local function valueAtPath(root, path)
	local current = root
	for segment in string.gmatch(path, "[^%.]+") do
		current = current[segment]
	end
	return current
end

return function(test)
	test:test("keeps explicit fixture outputs independent from production runtime", function()
		test:equal(Migration.historicalTargetSchema(), 11)
		test:equal(#fixtures, 3)
		for _, fixture in ipairs(fixtures) do
			test:equal(fixture.inputSchema, 10)
			test:equal(fixture.input.schemaVersion, 10)
			test:equal(fixture.expected.schemaVersion, 11)
		end
	end)

	for _, fixture in ipairs(fixtures) do
		test:test(fixture.name .. " has the reviewed schema-11 output", function()
			local migrated = Migration.migrate(fixture.input)
			test:deepEqual(migrated, fixture.expected)
		end)

		test:test(fixture.name .. " is idempotent", function()
			local first = Migration.migrate(fixture.input)
			local second = Migration.migrate(first)
			test:deepEqual(second, first)
		end)

		if fixture.preservedPaths then
			test:test(fixture.name .. " preserves every declared legacy value", function()
				local migrated = Migration.migrate(fixture.input)
				for _, path in ipairs(fixture.preservedPaths) do
					test:deepEqual(valueAtPath(migrated, path), valueAtPath(fixture.input, path), path .. " changed")
				end
			end)
		end
	end

	test:test("repairs missing active candy tokens through an injected deterministic factory", function()
		local generatedKinds = {}
		local migrated = Migration.migrate({
			schemaVersion = 10,
			candyDeliveryActive = true,
			candyDeliveryToken = "bad",
		}, function(kind)
			table.insert(generatedKinds, kind)
			return "fixture-" .. kind .. "-token"
		end)
		test:deepEqual(generatedKinds, { "delivery" })
		test:equal(migrated.candyDeliveryToken, "fixture-delivery-token")
		test:deepEqual(Migration.migrate(migrated), migrated)
	end)
end
