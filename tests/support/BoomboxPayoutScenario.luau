local Ledger = require("../../CooperTransactionLedger.module")

local BoomboxPayoutScenario = {}
BoomboxPayoutScenario.__index = BoomboxPayoutScenario

local function deepCopy(value, visited)
	if type(value) ~= "table" then
		return value
	end
	visited = visited or {}
	if visited[value] then
		return visited[value]
	end
	local copied = {}
	visited[value] = copied
	for key, child in pairs(value) do
		copied[deepCopy(key, visited)] = deepCopy(child, visited)
	end
	return copied
end

local function findLogicalOperation(journal, kind, userId)
	for index = #journal.pending, 1, -1 do
		local record = journal.pending[index]
		if record.kind == kind and record.userId == userId then
			return record
		end
	end
	for index = #journal.committed, 1, -1 do
		local record = journal.committed[index]
		if record.kind == kind and record.userId == userId then
			return record
		end
	end
	return nil
end

-- A deterministic model of the production boombox payout lock and persistent
-- value-operation contract. It deliberately has no clock, task scheduler, or
-- DataStore dependency, so every scheduler/settlement ordering is explicit.
function BoomboxPayoutScenario.new(options)
	options = options or {}
	local maximumTicks = options.maximumTicks or 10
	local payoutPerTick = options.payoutPerTick or 30
	assert(type(maximumTicks) == "number" and maximumTicks >= 1 and maximumTicks % 1 == 0)
	assert(type(payoutPerTick) == "number" and payoutPerTick >= 0 and payoutPerTick % 1 == 0)

	local scenario = setmetatable({
		journal = Ledger.sanitize(options.journal),
		sessionId = options.sessionId or "boombox:101:1:123456789",
		profileSessionId = options.profileSessionId or "party-m1",
		userId = options.userId or 101,
		maximumTicks = maximumTicks,
		payoutPerTick = payoutPerTick,
		allowance = options.startingAllowance or 0,
		paidTicks = options.paidTicks or 0,
		totalPaid = options.totalPaid or 0,
		settlementValue = options.settlementValue,
		settling = false,
		finalized = false,
		creditInFlight = nil,
		boomboxPendingSettlement = deepCopy(options.boomboxPendingSettlement) or false,
		released = false,
		_operationSerial = options.operationSerial or Ledger.issuedHighWater(Ledger.sanitize(options.journal)),
		mutationCount = options.mutationCount or 0,
	}, BoomboxPayoutScenario)
	if scenario.boomboxPendingSettlement ~= false then
		assert(
			scenario.boomboxPendingSettlement.sessionId == scenario.sessionId,
			"completion intent session mismatch"
		)
		scenario.paidTicks = scenario.boomboxPendingSettlement.paidTicks
		scenario.totalPaid = scenario.boomboxPendingSettlement.totalPaid
		scenario.settlementValue = scenario.boomboxPendingSettlement.settlementValue
		scenario.settling = true
	end
	return scenario
end

function BoomboxPayoutScenario:_issue(kind, value)
	self._operationSerial += 1
	local record = Ledger.issue(
		self.journal,
		self.profileSessionId,
		kind,
		self.userId,
		value,
		self._operationSerial - 1,
		self._operationSerial,
		string.format("00000000-0000-4000-8000-%012d", self._operationSerial)
	)
	local began = Ledger.begin(self.journal, record)
	assert(began, "new deterministic operation must begin")
	return record
end

function BoomboxPayoutScenario:_commitValue(kind, value, result, saveUnconfirmed)
	local existing = findLogicalOperation(self.journal, kind, self.userId)
	if existing then
		return {
			accepted = existing.state == "Committed" or existing.state == "NeedsReconciliation",
			appliedNow = false,
			durable = existing.state == "Committed",
			record = existing,
			status = existing.state == "Committed" and "AlreadyCommitted" or existing.state,
		}
	end

	local record = self:_issue(kind, value)
	self.allowance += value
	self.mutationCount += 1
	local committed = Ledger.commit(self.journal, record.id, result, self._operationSerial + 1)
	assert(committed ~= nil, "issued operation must commit")
	if saveUnconfirmed == true then
		committed = Ledger.markNeedsReconciliation(
			self.journal,
			record.id,
			"Injected ambiguous save",
			"SAVE_UNCONFIRMED"
		)
	end
	return {
		accepted = true,
		appliedNow = true,
		durable = saveUnconfirmed ~= true,
		record = committed,
		status = saveUnconfirmed == true and "NeedsReconciliation" or "Committed",
	}
end

function BoomboxPayoutScenario:beginScheduledTick(tickIndex)
	if self.settling then
		return nil, "BoomboxSettlementActive"
	end
	if self.creditInFlight ~= nil then
		return nil, "BoomboxTickBusy"
	end
	if tickIndex ~= self.paidTicks + 1 or tickIndex > self.maximumTicks then
		return nil, "BoomboxTickNotAuthorized"
	end
	local token = {
		tickIndex = tickIndex,
		priorTotal = self.totalPaid,
	}
	self.creditInFlight = token
	return token, "TickReserved"
end

function BoomboxPayoutScenario:finishScheduledTick(token, saveUnconfirmed)
	if token == nil or self.creditInFlight ~= token then
		return false, "InvalidTickToken"
	end
	local tickIndex = token.tickIndex
	local kind = Ledger.logicalKind(
		"BoomboxTick",
		self.sessionId .. ":" .. tostring(tickIndex)
	)
	assert(kind ~= nil, "test session must make a valid tick key")
	local nextTotal = token.priorTotal + self.payoutPerTick
	local result = self:_commitValue(kind, self.payoutPerTick, {
		paidTicks = tickIndex,
		totalPaid = nextTotal,
		playbackSessionId = self.sessionId,
	}, saveUnconfirmed)
	local recordResult = result.record and result.record.result or {}
	if result.accepted then
		self.paidTicks = math.max(self.paidTicks, tonumber(recordResult.paidTicks) or tickIndex)
		self.totalPaid = math.max(self.totalPaid, tonumber(recordResult.totalPaid) or nextTotal)
	end
	self.creditInFlight = nil
	return result.accepted, result.status
end

function BoomboxPayoutScenario:creditScheduledTick(tickIndex, saveUnconfirmed)
	local token, status = self:beginScheduledTick(tickIndex)
	if not token then
		return false, status
	end
	return self:finishScheduledTick(token, saveUnconfirmed)
end

function BoomboxPayoutScenario:beginSettlement()
	self.settling = true
	if self.creditInFlight ~= nil then
		return false, "WaitingForTick"
	end
	return true, "SettlementLockAcquired"
end

function BoomboxPayoutScenario:continueSettlement(saveUnconfirmed)
	if not self.settling then
		return false, "SettlementNotStarted"
	end
	if self.creditInFlight ~= nil then
		return false, "WaitingForTick"
	end
	for _, record in ipairs(self.journal.pending) do
		if record.state == "NeedsReconciliation"
			and string.sub(record.kind, 1, #"BoomboxTick:") == "BoomboxTick:"
			and string.find(record.kind, self.sessionId, 1, true) ~= nil
		then
			return true, "NeedsReconciliation"
		end
	end
	if self.settlementValue == nil then
		self.settlementValue = math.max(0, self.maximumTicks - self.paidTicks) * self.payoutPerTick
	end
	if self.settlementValue == 0 then
		self.paidTicks = self.maximumTicks
		self.finalized = true
		self.boomboxPendingSettlement = false
		return true, "NoSettlementNeeded"
	end

	local kind = Ledger.logicalKind("BoomboxSettle", self.sessionId)
	assert(kind ~= nil, "test session must make a valid settlement key")
	local targetTotal = self.totalPaid + self.settlementValue
	local result = self:_commitValue(kind, self.settlementValue, {
		paidTicks = self.maximumTicks,
		totalPaid = targetTotal,
		playbackSessionId = self.sessionId,
		settlementValue = self.settlementValue,
	}, saveUnconfirmed)
	local recordResult = result.record and result.record.result or {}
	if result.accepted then
		self.paidTicks = self.maximumTicks
		self.totalPaid = math.max(self.totalPaid, tonumber(recordResult.totalPaid) or targetTotal)
		self.finalized = result.durable
		if result.durable then
			self.boomboxPendingSettlement = false
		end
	end
	return result.accepted, result.status
end

function BoomboxPayoutScenario:settleCompleted(saveUnconfirmed)
	self:beginSettlement()
	return self:continueSettlement(saveUnconfirmed)
end

function BoomboxPayoutScenario:reconcileSettlement()
	local kind = Ledger.logicalKind("BoomboxSettle", self.sessionId)
	local existing = kind and findLogicalOperation(self.journal, kind, self.userId) or nil
	if not existing then
		return false, "NoSettlementOperation"
	end
	if existing.state == "Committed" then
		self.finalized = true
		return true, "AlreadyCommitted"
	end
	if existing.state ~= "NeedsReconciliation" then
		return false, existing.state
	end

	local committed = Ledger.commit(
		self.journal,
		existing.id,
		existing.result,
		self._operationSerial + 2
	)
	assert(committed ~= nil, "reconciliation must finalize the same record")
	self.finalized = true
	self.boomboxPendingSettlement = false
	return true, "Reconciled"
end

function BoomboxPayoutScenario:reconcileTick(tickIndex)
	local kind = Ledger.logicalKind(
		"BoomboxTick",
		self.sessionId .. ":" .. tostring(tickIndex)
	)
	local existing = kind and findLogicalOperation(self.journal, kind, self.userId) or nil
	if not existing then
		return false, "NoTickOperation"
	end
	if existing.state == "Committed" then
		return true, "AlreadyCommitted"
	end
	if existing.state ~= "NeedsReconciliation" then
		return false, existing.state
	end
	local committed = Ledger.commit(
		self.journal,
		existing.id,
		existing.result,
		self._operationSerial + 2
	)
	assert(committed ~= nil, "tick reconciliation must finalize the same record")
	return true, "Reconciled"
end

-- Completion qualification is persisted before transient playback ownership is
-- released. This is the recovery contract being exercised: a reconnect never
-- needs the Sound object or the old server callback to know the full payout is
-- still owed.
function BoomboxPayoutScenario:persistCompletionIntent()
	if self.boomboxPendingSettlement == false then
		self.boomboxPendingSettlement = {
			sessionId = self.sessionId,
			paidTicks = self.paidTicks,
			totalPaid = self.totalPaid,
			settlementValue = math.max(0, self.maximumTicks - self.paidTicks) * self.payoutPerTick,
			completedAt = 123456790,
		}
	end
	return deepCopy(self.boomboxPendingSettlement)
end

function BoomboxPayoutScenario:releaseAndReload()
	assert(self.boomboxPendingSettlement ~= false, "completion intent must be persisted before release")
	self.released = true
	return BoomboxPayoutScenario.new({
		journal = deepCopy(self.journal),
		sessionId = self.sessionId,
		profileSessionId = self.profileSessionId,
		userId = self.userId,
		maximumTicks = self.maximumTicks,
		payoutPerTick = self.payoutPerTick,
		startingAllowance = self.allowance,
		paidTicks = self.paidTicks,
		totalPaid = self.totalPaid,
		settlementValue = self.settlementValue,
		boomboxPendingSettlement = deepCopy(self.boomboxPendingSettlement),
		operationSerial = self._operationSerial,
		mutationCount = self.mutationCount,
	})
end

function BoomboxPayoutScenario:finishState()
	local savePending = false
	for _, record in ipairs(self.journal.pending) do
		if record.state == "NeedsReconciliation"
			and string.find(record.kind, self.sessionId, 1, true) ~= nil
		then
			savePending = true
			break
		end
	end
	return {
		ok = true,
		durable = self.finalized and not savePending,
		savePending = savePending,
		earned = self.totalPaid,
		paidTicks = self.paidTicks,
	}
end

function BoomboxPayoutScenario:seedPaidTicks(count)
	assert(count >= 0 and count <= self.maximumTicks and count % 1 == 0)
	for tickIndex = 1, count do
		local accepted, status = self:creditScheduledTick(tickIndex, false)
		assert(accepted, "seed tick failed: " .. tostring(status))
	end
end

function BoomboxPayoutScenario:settlementRecord()
	local kind = Ledger.logicalKind("BoomboxSettle", self.sessionId)
	return kind and findLogicalOperation(self.journal, kind, self.userId) or nil
end

return BoomboxPayoutScenario
