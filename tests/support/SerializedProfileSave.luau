local SerializedProfileSave = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

function SerializedProfileSave.mutate(profile, mutation)
	assert(type(profile) == "table", "profile is required")
	assert(type(mutation) == "function", "mutation callback is required")
	mutation(profile.data)
	profile.revision += 1
	profile.dirty = true
end

-- Deterministic model of saveProfile's serialized revision loop. onYield runs
-- after an attempt has captured its payload but before its UpdateAsync success
-- is observed, reproducing a mutation while the real network call yields.
function SerializedProfileSave.run(initialData, onYield, maximumAttempts)
	local profile = {
		data = deepCopy(initialData),
		revision = 0,
		dirty = true,
	}
	local attempts = {}
	maximumAttempts = maximumAttempts or 3

	repeat
		local attemptNumber = #attempts + 1
		local savedRevision = profile.revision
		-- This snapshot deliberately lives inside the retry loop and is paired
		-- with savedRevision, exactly like the production save contract.
		local payload = deepCopy(profile.data)
		local attempt = {
			number = attemptNumber,
			savedRevision = savedRevision,
			payload = payload,
		}
		table.insert(attempts, attempt)

		if onYield then
			onYield(attemptNumber, profile, payload)
		end
		if profile.revision == savedRevision then
			profile.dirty = false
		end
		attempt.dirtyAfterCommit = profile.dirty
	until not profile.dirty or #attempts >= maximumAttempts

	return {
		profile = profile,
		attempts = attempts,
		durable = not profile.dirty,
		persistedPayload = attempts[#attempts] and attempts[#attempts].payload or nil,
	}
end

return SerializedProfileSave
