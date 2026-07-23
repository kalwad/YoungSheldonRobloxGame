local SerializedProfileSave = require("../support/SerializedProfileSave")

return function(test)
	test:test("a yielded old save cannot clear or overwrite a newer revision", function()
		local result = SerializedProfileSave.run({
			allowance = 10,
			calmTaskCheckpoint = {
				logicalId = "101:1:GeorgeBeer",
			},
		}, function(attemptNumber, profile)
			if attemptNumber == 1 then
				SerializedProfileSave.mutate(profile, function(data)
					data.allowance = 25
					data.calmTaskCheckpoint = {
						logicalId = "101:2:MaryDishes",
					}
				end)
			end
		end)

		test:equal(#result.attempts, 2)
		test:equal(result.attempts[1].savedRevision, 0)
		test:equal(result.attempts[1].payload.allowance, 10)
		test:equal(result.attempts[1].payload.calmTaskCheckpoint.logicalId, "101:1:GeorgeBeer")
		test:truthy(result.attempts[1].dirtyAfterCommit)

		test:equal(result.attempts[2].savedRevision, 1)
		test:equal(result.attempts[2].payload.allowance, 25)
		test:equal(result.attempts[2].payload.calmTaskCheckpoint.logicalId, "101:2:MaryDishes")
		test:falsy(result.attempts[2].dirtyAfterCommit)
		test:truthy(result.durable)
		test:equal(result.persistedPayload.allowance, 25)
		test:equal(result.persistedPayload.calmTaskCheckpoint.logicalId, "101:2:MaryDishes")
	end)
end
