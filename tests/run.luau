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
	{ "Milestone 1 domain value-operation identities", require("./specs/Milestone1ValueOperations.spec") },
	{ "Boombox completion settlement and races", require("./specs/BoomboxPayoutSettlement.spec") },
	{ "Purchase commit outcome classification", require("./specs/PurchaseCommitOutcome.spec") },
	{ "Party Ready and launch coordinator contracts", require("./specs/PartyReadyLaunch.spec") },
	{ "One-use admission ticket contracts", require("./specs/AdmissionTicket.spec") },
	{ "Host grace and reconnect boundaries", require("./specs/HostGrace.spec") },
	{ "Server-authoritative sprint rules", require("./specs/SprintRules.spec") },
	{ "Two-client task completion and retry", require("./specs/TwoClientTaskScenario.spec") },
	{ "Locked deadline and penalty rules", require("./specs/DeadlineRules.spec") },
	{ "Reason-counted pause handling", require("./specs/PauseSet.spec") },
	{ "Approved hunter mappings", require("./specs/HunterRules.spec") },
}

local harness = TestHarness.new()
for _, suite in ipairs(suites) do
	harness:runSuite(suite[1], suite[2])
end
harness:finish()
