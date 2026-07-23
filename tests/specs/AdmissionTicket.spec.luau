local FakeClock = require("../support/FakeClock")
local FakeSessionDirectory = require("../support/FakeSessionDirectory")

local function issuedDirectory(options)
	local clock = FakeClock.new(10)
	local directory = FakeSessionDirectory.new(clock, options)
	local sessionId = directory:createManifest("party-a", 101, { 101, 102 }, 4, 90)
	local tickets = directory:issueTickets(sessionId)
	return clock, directory, sessionId, tickets
end

return function(test)
	test:test("ticket is user-bound and one-use", function()
		local _, directory, sessionId, tickets = issuedDirectory()
		local ok, code = directory:claim(tickets[102], 999, sessionId, 4)
		test:falsy(ok)
		test:equal(code, "UserMismatch")

		ok, code = directory:claim(tickets[102], 102, sessionId, 4)
		test:truthy(ok)
		test:equal(code, "Admitted")

		ok, code = directory:claim(tickets[102], 102, sessionId, 4)
		test:falsy(ok)
		test:equal(code, "TicketConsumed")
	end)

	test:test("altered session and stale membership fail without consuming the ticket", function()
		local _, directory, sessionId, tickets = issuedDirectory()
		local ok, code = directory:claim(tickets[101], 101, "session-forged", 4)
		test:falsy(ok)
		test:equal(code, "SessionMismatch")

		ok, code = directory:claim(tickets[101], 101, sessionId, 3)
		test:falsy(ok)
		test:equal(code, "StaleMembership")

		ok, code = directory:claim(tickets[101], 101, sessionId, 4)
		test:truthy(ok)
		test:equal(code, "Admitted")
	end)

	test:test("ticket is valid immediately before but not at the 90-second boundary", function()
		local clock, directory, sessionId, tickets = issuedDirectory()
		clock:advance(89.999)
		local ok, code = directory:claim(tickets[101], 101, sessionId, 4)
		test:truthy(ok)
		test:equal(code, "Admitted")

		local clock2, directory2, sessionId2, tickets2 = issuedDirectory()
		clock2:advance(90)
		ok, code = directory2:claim(tickets2[101], 101, sessionId2, 4)
		test:falsy(ok)
		test:equal(code, "TicketExpired")
	end)

	test:test("retryable directory failure consumes only the final accepted claim", function()
		local _, directory, sessionId, tickets = issuedDirectory({
			claimOutcomes = { "RetryableDirectoryFailure", "Success" },
		})
		local ok, code = directory:claim(tickets[102], 102, sessionId, 4)
		test:falsy(ok)
		test:equal(code, "RetryableDirectoryFailure")
		ok, code = directory:claim(tickets[102], 102, sessionId, 4)
		test:truthy(ok)
		test:equal(code, "Admitted")
		ok, code = directory:claim(tickets[102], 102, sessionId, 4)
		test:falsy(ok)
		test:equal(code, "TicketConsumed")
		test:equal(directory:claimCount(), 3)
	end)

	test:test("unknown replacement member has no admission path", function()
		local _, directory, sessionId = issuedDirectory()
		local ok, code = directory:claim("ticket:" .. sessionId .. ":103:999", 103, sessionId, 4)
		test:falsy(ok)
		test:equal(code, "MissingTicket")
		test:deepEqual(directory:manifest(sessionId).memberIds, { 101, 102 })
	end)
end
