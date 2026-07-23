-- Test-only schema-11-to-12 profile shell. The journal itself is sanitized by
-- the actual production CooperTransactionLedger module; ordinary profile
-- fields use the reviewed historical schema-11 oracle so this remains runnable
-- in the Luau CLI without Roblox services.

local HistoricalSchema11 = require("./ProfileMigrationOracle")
local ProductionLedger = require("../../CooperTransactionLedger.module")

local ProfileSchema12MigrationOracle = {}

function ProfileSchema12MigrationOracle.migrate(raw)
	raw = type(raw) == "table" and raw or {}
	local sanitized = HistoricalSchema11.migrate(raw)
	sanitized.schemaVersion = 12
	sanitized.operationJournal = ProductionLedger.sanitize(raw.operationJournal)
	return sanitized
end

function ProfileSchema12MigrationOracle.productionLedger()
	return ProductionLedger
end

return ProfileSchema12MigrationOracle
