local EligibilitySnapshot = require("./EligibilitySnapshot")

local TwoClientTaskScenario = {}
TwoClientTaskScenario.__index = TwoClientTaskScenario

local function memberRecords(memberIds)
	local records = {}
	for _, userId in ipairs(memberIds) do
		table.insert(records, {
			userId = userId,
			sessionMember = true,
			hydrated = true,
			presence = "Active",
		})
	end
	return records
end

function TwoClientTaskScenario.new(options)
	assert(type(options) == "table", "options are required")
	assert(type(options.store) == "table", "store is required")
	assert(type(options.memberIds) == "table" and #options.memberIds == 2, "exactly two members are required")
	assert(type(options.reward) == "number" and options.reward >= 0, "reward must be non-negative")
	local snapshot = EligibilitySnapshot.new(
		options.sessionId or "house-1",
		options.taskVersion or 1,
		memberRecords(options.memberIds),
		0
	)
	local operations = {}
	for _, userId in ipairs(snapshot:userIds()) do
		operations[userId] = {
			id = table.concat({ snapshot.sessionId, tostring(snapshot.version), "TaskReward", tostring(userId) }, ":"),
			state = "Pending",
		}
	end
	return setmetatable({
		store = options.store,
		snapshot = snapshot,
		reward = options.reward,
		operations = operations,
		state = "Active",
		winner = nil,
		advanceCount = 0,
		submissionCount = 0,
	}, TwoClientTaskScenario)
end

function TwoClientTaskScenario:_allCommitted()
	for _, userId in ipairs(self.snapshot:userIds()) do
		if self.operations[userId].state ~= "Committed" then
			return false
		end
	end
	return true
end

function TwoClientTaskScenario:_commitPending()
	for _, userId in ipairs(self.snapshot:userIds()) do
		local operation = self.operations[userId]
		if operation.state ~= "Committed" then
			local ok, code = self.store:applyValue(userId, operation.id, self.reward)
			if ok then
				operation.state = "Committed"
				operation.code = code
			else
				operation.state = "NeedsReconciliation"
				operation.code = code
			end
		end
	end
	if self:_allCommitted() and self.state ~= "Closed" then
		self.snapshot:sealCommit()
		self.state = "Closed"
		self.advanceCount += 1
	end
end

function TwoClientTaskScenario:submitCompletion(userId, clientReward)
	self.submissionCount += 1
	if not self.snapshot:contains(userId) then
		return false, "NotEligible"
	end
	if type(clientReward) == "number" and clientReward ~= self.reward then
		clientReward = nil
	end
	if self.state == "Closed" then
		return true, "AlreadyCompleted"
	end
	if self.state == "Active" then
		self.state = "Rewarding"
		self.winner = userId
	end
	self:_commitPending()
	return self.state == "Closed", if self.state == "Closed" then "Completed" else "ReconciliationPending"
end

return TwoClientTaskScenario
