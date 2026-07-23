local FakeClock = require("../support/FakeClock")
local FakeSessionDirectory = require("../support/FakeSessionDirectory")
local FakeTeleportAdapter = require("../support/FakeTeleportAdapter")
local PartyLaunchScenario = require("../support/PartyLaunchScenario")
local RevisionedPartyView = require("../support/RevisionedPartyView")

local function scenario(options)
	options = options or {}
	local clock = FakeClock.new(100)
	local teleport = FakeTeleportAdapter.new({
		reserveOutcomes = options.reserveOutcomes,
		teleportOutcomes = options.teleportOutcomes,
	})
	local directory = FakeSessionDirectory.new(clock)
	local party = PartyLaunchScenario.new({
		clock = clock,
		teleport = teleport,
		directory = directory,
		hostUserId = 101,
		memberIds = options.memberIds or { 101, 102 },
		partyId = "party-ready",
		placeId = 98645411943406,
		membershipRevision = 7,
	})
	return party, clock, teleport, directory
end

local function readyEveryone(test, party, clock)
	local ok, code = party:setReady(101, true, 1)
	test:truthy(ok)
	test:equal(code, "ReadyCommitted")
	ok, code = party:setReady(102, true, 1)
	test:truthy(ok)
	test:equal(code, "ReadyCommitted")
	test:truthy(party:canLaunch())
	clock:advance(0)
end

return function(test)
	test:test("one Ready request stays committed through repeated authoritative polls", function()
		local party = scenario()
		local ok, code, committed = party:setReady(101, true, 1)
		test:truthy(ok)
		test:equal(code, "ReadyCommitted")
		test:truthy(committed.ready[101])
		for _ = 1, 10 do
			local poll = party:snapshot()
			test:truthy(poll.ready[101])
			test:equal(poll.partyRevision, committed.partyRevision)
		end
	end)

	test:test("reordered Ready replies cannot roll a client view backward", function()
		local party, clock = scenario()
		local view = RevisionedPartyView.new()
		local _, _, readySnapshot = party:setReady(101, true, 1)
		clock:advance(0.101)
		local _, _, unreadySnapshot = party:setReady(101, false, 2)

		local applied, code = view:apply(unreadySnapshot)
		test:truthy(applied)
		test:equal(code, "Applied")
		test:falsy(view.ready[101])

		applied, code = view:apply(readySnapshot)
		test:falsy(applied)
		test:equal(code, "StaleSnapshot")
		test:falsy(view.ready[101])
	end)

	test:test("stale and conflicting Ready request identities do not mutate server state", function()
		local party, clock = scenario()
		party:setReady(101, true, 2)
		clock:advance(0.101)
		local ok, code = party:setReady(101, false, 1)
		test:falsy(ok)
		test:equal(code, "StaleRequest")
		test:truthy(party:snapshot().ready[101])

		ok, code = party:setReady(101, false, 2)
		test:falsy(ok)
		test:equal(code, "RequestIdentityMismatch")
		test:truthy(party:snapshot().ready[101])

		ok, code = party:setReady(101, true, 2)
		test:truthy(ok)
		test:equal(code, "AlreadyCommitted")
	end)

	test:test("Ready and Start have independent cooldowns", function()
		local party, clock, teleport, directory = scenario()
		readyEveryone(test, party, clock)
		local ok, code = party:launch(101)
		test:truthy(ok)
		test:equal(code, "Launched")
		test:equal(teleport:reserveCount(), 1)
		test:equal(teleport:teleportCount(), 1)
		test:equal(directory:createCount(), 1)
	end)

	test:test("guest Start is rejected without creating launch artifacts", function()
		local party, clock, teleport, directory = scenario()
		readyEveryone(test, party, clock)
		local ok, code = party:launch(102)
		test:falsy(ok)
		test:equal(code, "HostOnly")
		test:equal(teleport:reserveCount(), 0)
		test:equal(teleport:teleportCount(), 0)
		test:equal(directory:createCount(), 0)
		test:truthy(party:canLaunch())
	end)

	test:test("double Start produces one reservation manifest ticket set and teleport", function()
		local party, clock, teleport, directory = scenario()
		readyEveryone(test, party, clock)
		local firstOk, firstCode, firstLaunch = party:launch(101)
		local secondOk, secondCode, secondLaunch = party:launch(101)
		test:truthy(firstOk)
		test:equal(firstCode, "Launched")
		test:truthy(secondOk)
		test:equal(secondCode, "AlreadyLaunched")
		test:equal(firstLaunch.sessionId, secondLaunch.sessionId)
		test:equal(teleport:reserveCount(), 1)
		test:equal(teleport:teleportCount(), 1)
		test:equal(directory:createCount(), 1)
		test:equal(directory:issueCount(), 2)
	end)

	test:test("reservation fail then retry creates only one successful manifest", function()
		local party, clock, teleport, directory = scenario({
			reserveOutcomes = { "InjectedReserveFailure", "Success" },
		})
		readyEveryone(test, party, clock)
		local ok, code = party:launch(101)
		test:falsy(ok)
		test:equal(code, "ReservationFailed:InjectedReserveFailure")
		test:equal(directory:createCount(), 0)
		test:equal(teleport:teleportCount(), 0)

		clock:advance(0.101)
		ok, code = party:launch(101)
		test:truthy(ok)
		test:equal(code, "Launched")
		test:equal(teleport:reserveCount(), 2)
		test:equal(directory:createCount(), 1)
		test:equal(directory:issueCount(), 2)
		test:equal(teleport:teleportCount(), 1)
	end)

	test:test("bounded teleport retry reuses reservation manifest and tickets", function()
		local party, clock, teleport, directory = scenario({
			teleportOutcomes = { "InjectedTeleportFailure", "Success" },
		})
		readyEveryone(test, party, clock)
		local ok, code, firstResult = party:launch(101)
		test:truthy(ok)
		test:equal(code, "Launched")
		test:truthy(firstResult.sessionId ~= nil)
		test:truthy(firstResult.reservationCode ~= nil)
		test:equal(teleport:reserveCount(), 1)
		test:equal(directory:createCount(), 1)
		test:equal(directory:issueCount(), 2)
		test:equal(teleport:teleportCount(), 2)
	end)

	test:test("asynchronous init failure consumes the same bounded retry budget", function()
		local party, clock, teleport, directory = scenario({
			teleportOutcomes = { "AcceptedThenInitFailed", "Success" },
		})
		readyEveryone(test, party, clock)
		local ok, code, firstResult = party:launch(101)
		test:truthy(ok)
		test:equal(code, "Launched")
		local originalReservation = firstResult.reservationCode
		local originalSession = firstResult.sessionId

		ok, code, firstResult = party:handleTeleportInitFailed()
		test:truthy(ok)
		test:equal(code, "TeleportRetryAccepted")
		test:equal(firstResult.reservationCode, originalReservation)
		test:equal(firstResult.sessionId, originalSession)
		test:equal(teleport:reserveCount(), 1)
		test:equal(directory:createCount(), 1)
		test:equal(directory:issueCount(), 2)
		test:equal(teleport:teleportCount(), 2)
	end)

	test:test("async retry reuses every launch artifact and cannot mint a second identity", function()
		local party, clock, teleport, directory = scenario({
			teleportOutcomes = { "AcceptedThenInitFailed", "Success" },
		})
		readyEveryone(test, party, clock)
		local ok, _, launch = party:launch(101)
		test:truthy(ok)
		local firstCall = teleport:teleportCall(1)
		local originalTickets = launch.tickets

		ok = party:handleTeleportInitFailed()
		test:truthy(ok)
		local retryCall = teleport:teleportCall(2)
		test:equal(retryCall.reservationCode, firstCall.reservationCode)
		test:equal(retryCall.sessionId, firstCall.sessionId)
		test:deepEqual(retryCall.memberIds, firstCall.memberIds)
		test:equal(launch.tickets, originalTickets)
		test:equal(teleport:reserveCount(), 1)
		test:equal(directory:createCount(), 1)
		test:equal(directory:issueCount(), 2)
		test:equal(launch.teleportAttempts, 2)
	end)

	test:test("exhausted asynchronous init retry cannot loop or create launch artifacts", function()
		local party, clock, teleport, directory = scenario({
			teleportOutcomes = {
				"AcceptedThenInitFailed",
				"AcceptedThenInitFailed",
				"Success",
			},
		})
		readyEveryone(test, party, clock)
		local ok, code, launch = party:launch(101)
		test:truthy(ok)
		test:equal(code, "Launched")

		ok, code = party:handleTeleportInitFailed()
		test:truthy(ok)
		test:equal(code, "TeleportRetryAccepted")
		test:equal(launch.teleportAttempts, 2)

		for _ = 1, 5 do
			ok, code = party:handleTeleportInitFailed()
			test:falsy(ok)
			test:equal(code, "RetryBudgetExhausted")
		end
		test:equal(teleport:teleportCount(), 2)
		test:equal(teleport:reserveCount(), 1)
		test:equal(directory:createCount(), 1)
		test:equal(directory:issueCount(), 2)
	end)

	test:test("teleport request helper returns exactly one boolean result", function()
		local _, _, teleport = scenario({
			teleportOutcomes = { "AcceptedThenInitFailed" },
		})
		local context = {
			attempts = 0,
			maximumAttempts = 2,
		}
		local resultCount = select(
			"#",
			teleport:requestWithContext(
				context,
				"reservation-1",
				"session-1",
				{ 101, 102 }
			)
		)
		test:equal(resultCount, 1)
		local accepted = teleport:requestWithContext(
			{
				attempts = 2,
				maximumAttempts = 2,
			},
			"reservation-1",
			"session-1",
			{ 101, 102 }
		)
		test:falsy(accepted)
	end)

	test:test("guest departure invalidates stale readiness before launch", function()
		local party, clock, teleport = scenario({ memberIds = { 101, 102 } })
		readyEveryone(test, party, clock)
		local oldMembershipRevision = party.membershipRevision
		test:truthy(party:removeMember(102))
		test:equal(party.membershipRevision, oldMembershipRevision + 1)
		test:equal(party:snapshot().ready[102], nil)
		local ok = party:launch(101)
		test:truthy(ok)
		test:equal(teleport:lastTeleport().memberIds[1], 101)
		test:equal(#teleport:lastTeleport().memberIds, 1)
	end)

	test:test("host departure cancels an unlaunched party", function()
		local party = scenario()
		test:truthy(party:removeMember(101))
		test:equal(party:snapshot().partyState, "Cancelled")
		local ok, code = party:launch(101)
		test:falsy(ok)
		test:equal(code, "PartyCancelled")
	end)
end
