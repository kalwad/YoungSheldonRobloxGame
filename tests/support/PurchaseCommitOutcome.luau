local PurchaseCommitOutcome = {}

-- Presentation/workflow policy for a server-authoritative purchase result.
-- "accepted" means the debit and entitlement exist in the live lease-owned
-- profile. Lack of confirmed durability is a save-pending success state, not a
-- failed request that the client should repeat.
function PurchaseCommitOutcome.classify(accepted, durable, status)
	if accepted ~= true then
		return {
			ok = false,
			accepted = false,
			durable = false,
			savePending = false,
			retryable = status == "TransactionBusy" or status == "ProfileNotWritable",
			status = status,
		}
	end
	if durable == true then
		return {
			ok = true,
			accepted = true,
			durable = true,
			savePending = false,
			retryable = false,
			status = status or "Committed",
		}
	end
	return {
		ok = true,
		accepted = true,
		durable = false,
		savePending = true,
		retryable = false,
		status = status or "SavePendingAccepted",
	}
end

return PurchaseCommitOutcome
