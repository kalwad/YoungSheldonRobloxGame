local RevisionedPartyView = {}
RevisionedPartyView.__index = RevisionedPartyView

local function copyMap(values)
	local result = {}
	for key, value in pairs(values or {}) do
		result[key] = value
	end
	return result
end

local function sameMap(left, right)
	for key, value in pairs(left or {}) do
		if right[key] ~= value then
			return false
		end
	end
	for key in pairs(right or {}) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

function RevisionedPartyView.new()
	return setmetatable({
		revision = 0,
		ready = {},
		canLaunch = false,
		partyState = "Unknown",
	}, RevisionedPartyView)
end

function RevisionedPartyView:apply(snapshot)
	assert(type(snapshot) == "table", "snapshot is required")
	assert(type(snapshot.partyRevision) == "number", "partyRevision is required")
	if snapshot.partyRevision < self.revision then
		return false, "StaleSnapshot"
	end
	if snapshot.partyRevision == self.revision then
		local same = sameMap(self.ready, snapshot.ready)
			and self.canLaunch == snapshot.canLaunch
			and self.partyState == snapshot.partyState
		if not same then
			return false, "RevisionConflict"
		end
		return true, "DuplicateSnapshot"
	end
	self.revision = snapshot.partyRevision
	self.ready = copyMap(snapshot.ready)
	self.canLaunch = snapshot.canLaunch == true
	self.partyState = snapshot.partyState
	return true, "Applied"
end

return RevisionedPartyView
