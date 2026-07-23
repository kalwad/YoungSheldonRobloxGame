local DeterministicRandom = require("../support/DeterministicRandom")

return function(test)
	test:test("maps a scripted sequence to exact integer choices", function()
		local random = DeterministicRandom.fromSequence({ 0, 0.49, 0.999 })
		test:equal(random:nextInteger(1, 4), 1)
		test:equal(random:nextInteger(1, 4), 2)
		test:equal(random:nextInteger(1, 4), 4)
		test:equal(random:calls(), 3)
	end)

	test:test("repeats the same stream for the same seed", function()
		local left = DeterministicRandom.fromSeed(8675309)
		local right = DeterministicRandom.fromSeed(8675309)
		for _ = 1, 12 do
			test:equal(left:nextInteger(1, 1000), right:nextInteger(1, 1000))
		end
	end)

	test:test("supports deterministic array selection", function()
		local random = DeterministicRandom.fromSequence({ 0.5 })
		test:equal(random:choose({ "George", "Mary", "Missy", "Georgie" }), "Missy")
	end)

	test:test("fails loudly instead of becoming nondeterministic on exhaustion", function()
		local random = DeterministicRandom.fromSequence({ 0.2 })
		random:nextNumber()
		test:throws(function() random:nextNumber() end, "sequence exhausted")
	end)
end
