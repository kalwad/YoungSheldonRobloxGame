local TestHarness = require("./support/TestHarness")

local suites = {
	{ "Fake monotonic clock", require("./specs/FakeClock.spec") },
	{ "Deterministic random source", require("./specs/DeterministicRandom.spec") },
	{ "Historical M0 schema-10-to-11 migration fixtures", require("./specs/ProfileMigration.spec") },
	{ "Schema-11-to-12 operation-journal migration", require("./specs/ProfileSchema12Migration.spec") },
	{ "Immutable eligibility snapshot", require("./specs/EligibilitySnapshot.spec") },
	{ "Durable calm-task checkpoint", require("./specs/CalmTaskCheckpoint.spec") },
	{ "Serialized profile save", require("./specs/SerializedProfileSave.spec") },
	{ "Value-operation retry policy", require("./specs/ValueOperationCommitPolicy.spec") },
	{ "Host-last task payout barrier", require("./specs/TaskPayoutBarrier.spec") },
	{ "At-most-once transaction ledger", require("./specs/TransactionLedger.spec") },
	{ "Production transaction journal", require("./specs/ProductionTransactionLedger.spec") },
	{ "Locked deadline and penalty rules", require("./specs/DeadlineRules.spec") },
	{ "Reason-counted pause handling", require("./specs/PauseSet.spec") },
	{ "Approved hunter mappings", require("./specs/HunterRules.spec") },
}

local harness = TestHarness.new()
for _, suite in ipairs(suites) do
	harness:runSuite(suite[1], suite[2])
end
harness:finish()
