local FakeClock = require("../support/FakeClock")

return function(test)
	test:test("starts at the requested monotonic time", function()
		local clock = FakeClock.new(12.5)
		test:equal(clock:now(), 12.5)
	end)

	test:test("advances only when explicitly told", function()
		local clock = FakeClock.new(10)
		test:equal(clock:advance(2.25), 12.25)
		test:equal(clock:now(), 12.25)
	end)

	test:test("allows setting the same or a later time", function()
		local clock = FakeClock.new(4)
		test:equal(clock:set(4), 4)
		test:equal(clock:set(9), 9)
	end)

	test:test("rejects backward and non-finite movement", function()
		local clock = FakeClock.new(5)
		test:throws(function() clock:advance(-0.01) end, "cannot advance backward")
		test:throws(function() clock:set(4.99) end, "cannot be set backward")
		test:throws(function() clock:advance(0 / 0) end, "must be finite")
	end)
end
