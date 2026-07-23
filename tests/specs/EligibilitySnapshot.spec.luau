local EligibilitySnapshot = require("../support/EligibilitySnapshot")
local Parties = require("../support/Parties")

return function(test)
	test:test("snapshots only fully hydrated active session membership", function()
		local snapshot = EligibilitySnapshot.new("session-a", 3, Parties.mixedPresence(), 50)
		test:deepEqual(snapshot:userIds(), { 101, 102, 103, 104, 105 })
		test:equal(snapshot:count(), 5)
		test:falsy(snapshot:contains(106), "loading players are not eligible")
		test:falsy(snapshot:contains(107), "outsiders are not eligible")
		test:falsy(snapshot:contains(108), "already disconnected members are not active at snapshot start")
	end)

	test:test("copies inputs and returned membership arrays", function()
		local members = Parties.mixedPresence()
		local snapshot = EligibilitySnapshot.new("session-a", 1, members, 0)
		members[1].userId = 999
		local returned = snapshot:userIds()
		returned[1] = 888
		test:truthy(snapshot:contains(101))
		test:deepEqual(snapshot:userIds(), { 101, 102, 103, 104, 105 })
	end)

	test:test("preserves one identity through disconnect and in-grace rejoin", function()
		local snapshot = EligibilitySnapshot.new("session-a", 1, Parties.mixedPresence(), 0)
		test:truthy(snapshot:markDisconnected(103, 100, 90))
		test:truthy(snapshot:rejoin(103, 189.999))
		test:equal(snapshot:count(), 5)
		test:deepEqual(snapshot:eligibleUserIdsForCommit(), { 101, 102, 103, 104, 105 })
		test:equal(snapshot:record(103).currentPresence, "Rejoined")
	end)

	test:test("forfeits a disconnected member at the exact grace boundary before commit", function()
		local snapshot = EligibilitySnapshot.new("session-a", 1, Parties.mixedPresence(), 0)
		snapshot:markDisconnected(102, 10, 90)
		test:equal(snapshot:forfeitExpired(99.999), 0)
		test:equal(snapshot:forfeitExpired(100), 1)
		test:deepEqual(snapshot:eligibleUserIdsForCommit(), { 101, 103, 104, 105 })
		test:falsy(snapshot:rejoin(102, 100))
	end)

	test:test("never recalculates committed eligibility", function()
		local snapshot = EligibilitySnapshot.new("session-a", 1, Parties.mixedPresence(), 0)
		snapshot:markDisconnected(104, 5, 90)
		local committed = snapshot:sealCommit()
		test:deepEqual(committed, { 101, 102, 103, 104, 105 })
		test:equal(snapshot:forfeitExpired(1000), 0)
		test:falsy(snapshot:markDisconnected(101, 1000, 90))
		test:deepEqual(snapshot:eligibleUserIdsForCommit(), committed)
	end)

	test:test("rejects duplicate eligible identities", function()
		test:throws(function()
			EligibilitySnapshot.new("session-a", 1, {
				{ userId = 1, sessionMember = true, hydrated = true, presence = "Active" },
				{ userId = 1, sessionMember = true, hydrated = true, presence = "AFK" },
			}, 0)
		end, "duplicate eligible userId")
	end)
end
