--!nonstrict
-- Read-only production-candidate security audit.
--
-- This verifier is intentionally expected to FAIL in the local lobby authoring
-- place while its in-place Studio preview bridge/package are installed. Run it
-- only against the stripped private release-candidate copy. A runtime
-- RunService:IsStudio() guard is not structural exclusion and cannot satisfy
-- this audit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local failures = {}
local checks = 0

local function check(condition, message)
	checks += 1
	if not condition then
		table.insert(failures, message)
	end
end

local forbiddenExactNames = {
	StudioHousePreview = true,
	StudioHousePreviewPackage = true,
	StudioScenarioRunner = true,
	CooperScenarioRunner = true,
	ScenarioControl = true,
	DebugGrant = true,
	UnlockAll = true,
	GrantAll = true,
}

local forbiddenAuthorityFragments = {
	"scenario",
	"debuggrant",
	"unlockall",
	"grantall",
	"forceending",
	"forcehorror",
}

local function normalized(value)
	return string.lower((tostring(value):gsub("[^%w]", "")))
end

local roots = {
	ReplicatedStorage,
	ServerScriptService,
	ServerStorage,
}

for _, root in ipairs(roots) do
	for _, instance in ipairs(root:GetDescendants()) do
		check(
			forbiddenExactNames[instance.Name] ~= true,
			"Production candidate contains authoring/scenario object: " .. instance:GetFullName()
		)
		if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction")
			or instance:IsA("UnreliableRemoteEvent")
		then
			local compactName = normalized(instance.Name)
			for _, fragment in ipairs(forbiddenAuthorityFragments) do
				check(
					not string.find(compactName, fragment, 1, true),
					"Production candidate exposes suspicious remote authority: " .. instance:GetFullName()
				)
			end
		end
		for _, attributeName in ipairs({
			"StudioScenarioControl",
			"CooperDebugAuthority",
			"UnlockAllEnabled",
		}) do
			check(
				instance:GetAttribute(attributeName) == nil,
				"Production candidate exposes privileged attribute " .. attributeName
					.. " on " .. instance:GetFullName()
			)
		end
	end
end

local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
local configModule = gameRoot and gameRoot:FindFirstChild("Config")
local transactionLedgerModule = gameRoot and gameRoot:FindFirstChild("TransactionLedger")
if configModule and configModule:IsA("ModuleScript") then
	local ok, config = pcall(require, configModule)
	check(ok and type(config) == "table", "CooperGame.Config could not be read")
	if ok and type(config) == "table" then
		check(
			type(config.Features) == "table" and config.Features.StudioScenarioTools == false,
			"StudioScenarioTools must be false in a production candidate"
		)
	end
end
check(
	transactionLedgerModule and transactionLedgerModule:IsA("ModuleScript"),
	"Production house is missing CooperGame.TransactionLedger"
)
if transactionLedgerModule and transactionLedgerModule:IsA("ModuleScript") then
	local ok, ledger = pcall(require, transactionLedgerModule)
	check(ok and type(ledger) == "table", "CooperGame.TransactionLedger could not be read")
	if ok and type(ledger) == "table" then
		check(ledger.VERSION == 1, "Production transaction ledger version changed")
		check(
			type(ledger.MAX_COMMITTED) == "number" and ledger.MAX_COMMITTED >= 256,
			"Production transaction journal retains fewer than 256 committed operations"
		)
		check(
			type(ledger.MAX_ROLLED_BACK) == "number" and ledger.MAX_ROLLED_BACK > 0,
			"Production transaction journal has no separate rollback tombstone capacity"
		)
		check(
			type(ledger.issuedHighWater) == "function",
			"Production transaction journal has no persistent issuance watermark"
		)
	end
end

check(
	ServerScriptService:FindFirstChild("StudioHousePreview") == nil,
	"StudioHousePreview bridge must be structurally absent from a production candidate"
)
check(
	ServerStorage:FindFirstChild("StudioHousePreviewPackage") == nil,
	"StudioHousePreviewPackage must be structurally absent from a production candidate"
)

if #failures > 0 then
	error(string.format(
		"Production build surface audit FAILED (%d/%d):\n- %s",
		#failures,
		checks,
		table.concat(failures, "\n- ")
	))
end

print(string.format(
	"[CooperProductionSurfaceVerifier] PASS — %d checks; no authoring/scenario authority is present",
	checks
))
