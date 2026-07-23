local ValueOperationCommitPolicy = {}

local function sameIdentity(existing, request)
	return existing.kind == request.kind
		and existing.userId == request.userId
		and existing.value == request.value
end

-- Pure ordering model for the production commitProfileValueOperation API.
-- Terminal records are authoritative retry answers; mutable authorization is
-- consulted only for a Pending record or a brand-new server operation.
function ValueOperationCommitPolicy.evaluate(request)
	local existing = request.existing
	if request.activeSessionId == nil or request.expectedSessionId ~= request.activeSessionId then
		return { status = "StaleSession", shouldMutate = false, authorizeCalls = 0 }
	end
	if existing ~= nil then
		if existing.sessionId ~= request.activeSessionId then
			return { status = "StaleSession", shouldMutate = false, authorizeCalls = 0 }
		end
		if not sameIdentity(existing, request) then
			return { status = "OperationIdentityMismatch", shouldMutate = false, authorizeCalls = 0 }
		end
		if existing.state == "Committed" then
			return {
				status = "AlreadyCommitted",
				shouldMutate = false,
				authorizeCalls = 0,
				result = existing.result,
			}
		elseif existing.state == "RolledBack" then
			return { status = "RolledBack", shouldMutate = false, authorizeCalls = 0 }
		elseif existing.state == "NeedsReconciliation" then
			return { status = "NeedsReconciliation", shouldMutate = false, authorizeCalls = 0 }
		elseif existing.state ~= "Pending" then
			return { status = "InvalidOperationState", shouldMutate = false, authorizeCalls = 0 }
		end
	elseif request.operationId ~= nil then
		return { status = "UnknownServerOperation", shouldMutate = false, authorizeCalls = 0 }
	end
	if request.reconciliationBlocked == true then
		return { status = "ProfileNotWritable", shouldMutate = false, authorizeCalls = 0 }
	end

	local authorizeCalls = 0
	if request.authorize ~= nil then
		authorizeCalls += 1
		local authorized, denial = request.authorize()
		if authorized ~= true then
			return {
				status = denial or "AuthorityRevoked",
				shouldMutate = false,
				authorizeCalls = authorizeCalls,
			}
		end
	end
	return {
		status = existing and "ApplyPending" or "ReserveAndApply",
		shouldMutate = true,
		authorizeCalls = authorizeCalls,
	}
end

return ValueOperationCommitPolicy
