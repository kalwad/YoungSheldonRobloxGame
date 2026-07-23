local PauseSet = require("./PauseSet")

local HostGraceScenario = {}
HostGraceScenario.__index = HostGraceScenario

function HostGraceScenario.new(clock, hostUserId, graceSeconds)
	assert(type(clock) == "table" and type(clock.now) == "function", "clock is required")
	assert(type(hostUserId) == "number", "hostUserId is required")
	return setmetatable({
		clock = clock,
		hostUserId = hostUserId,
		graceSeconds = graceSeconds or 60,
		pauses = PauseSet.new(),
		hostGraceToken = nil,
		hostGraceDeadline = nil,
		phase = "Tasks",
		resumeCount = 0,
		closeCount = 0,
		saveCount = 0,
		returnCount = 0,
	}, HostGraceScenario)
end

function HostGraceScenario:disconnectHost()
	if self.phase == "Closing" then
		return false, "Closing"
	end
	if self.hostGraceToken then
		return true, "AlreadyInHostGrace"
	end
	self.hostGraceToken = self.pauses:acquire("HostGrace")
	self.hostGraceDeadline = self.clock:now() + self.graceSeconds
	return true, "HostGraceStarted"
end

function HostGraceScenario:canMutate()
	return self.phase == "Tasks" and not self.pauses:isPaused()
end

function HostGraceScenario:rejoin(userId)
	if userId ~= self.hostUserId then
		return false, "NotHost"
	end
	if not self.hostGraceToken then
		return false, "NoHostGrace"
	end
	if self.clock:now() >= self.hostGraceDeadline then
		self:tick()
		return false, "HostGraceExpired"
	end
	self.pauses:release(self.hostGraceToken)
	self.hostGraceToken = nil
	self.hostGraceDeadline = nil
	self.resumeCount += 1
	return true, "Resumed"
end

function HostGraceScenario:tick()
	if not self.hostGraceToken or self.phase == "Closing" then
		return false
	end
	if self.clock:now() < self.hostGraceDeadline then
		return false
	end
	self.pauses:release(self.hostGraceToken)
	self.hostGraceToken = nil
	self.hostGraceDeadline = nil
	self.phase = "Closing"
	self.saveCount += 1
	self.returnCount += 1
	self.closeCount += 1
	return true
end

return HostGraceScenario
