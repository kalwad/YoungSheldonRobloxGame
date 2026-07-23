-- Test-only oracle for the historical Milestone 0 schema-10-to-11 boundary.
-- This intentionally has no Roblox service dependency and is not a production
-- migration implementation or the final Milestone 1 schema target. Keep
-- expected fixture outputs human-reviewed; schema 11 -> 12 has its own fixture.

local ProfileMigrationOracle = {}

local CURRENT_SCHEMA = 11
local TASK_COUNT = 5
local MACHINE_STAGE_COUNT = 11
local AUTOMATION_IDS = { "BeerBot", "DishBot", "TrashBot", "ToyFinder", "HackerBot" }
local AUTOMATION_SET = {}
for _, upgradeId in ipairs(AUTOMATION_IDS) do
	AUTOMATION_SET[upgradeId] = true
end

local function finiteInteger(value, default, minimum, maximum)
	local numeric = tonumber(value)
	if not numeric or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
		return default
	end
	return math.clamp(math.floor(numeric + 0.5), minimum, maximum)
end

local function validToken(value)
	return type(value) == "string" and #value >= 8 and #value <= 96
end

local function repairedToken(kind, tokenFactory)
	assert(type(tokenFactory) == "function", "active candy state with an invalid token requires a deterministic tokenFactory")
	local token = tokenFactory(kind)
	assert(validToken(token), "tokenFactory must return a string between 8 and 96 characters")
	return token
end

function ProfileMigrationOracle.historicalTargetSchema()
	return CURRENT_SCHEMA
end

function ProfileMigrationOracle.migrate(raw, tokenFactory)
	raw = type(raw) == "table" and raw or {}

	local boomboxPlaced = raw.boomboxPlaced == true
	local boomboxPurchased = raw.boomboxPurchased == true or boomboxPlaced
	local installedRaw = type(raw.taskAutomationInstalled) == "table" and raw.taskAutomationInstalled or {}
	local installed = {}
	for _, upgradeId in ipairs(AUTOMATION_IDS) do
		if installedRaw[upgradeId] == true then
			installed[upgradeId] = true
		end
	end
	local pendingUpgradeId = type(raw.pendingTaskUpgradeId) == "string" and raw.pendingTaskUpgradeId or ""
	if not AUTOMATION_SET[pendingUpgradeId] or installed[pendingUpgradeId] then
		pendingUpgradeId = ""
	end

	local bunkerPurchased = raw.secretBunkerPurchased == true
	local bunkerReadyAt = bunkerPurchased
		and finiteInteger(raw.secretBunkerReadyAt, 1, 1, 4_102_444_800)
		or 0
	local chemistryPlaced = raw.chemistrySetupPlaced == true
	local chemistryPurchased = raw.chemistrySetupPurchased == true or chemistryPlaced

	local candyDeliveryActive = raw.candyDeliveryActive == true
	local candyDeliveryToken = ""
	if candyDeliveryActive then
		candyDeliveryToken = validToken(raw.candyDeliveryToken)
			and raw.candyDeliveryToken
			or repairedToken("delivery", tokenFactory)
	end
	local candyBatchReady = not candyDeliveryActive and raw.candyBatchReady == true
	local candyBatchToken = ""
	if candyBatchReady then
		candyBatchToken = validToken(raw.candyBatchToken)
			and raw.candyBatchToken
			or repairedToken("batch", tokenFactory)
	end

	local totalTasks = finiteInteger(raw.totalTasks, 0, 0, 10_000_000)
	local endingChoice = (raw.endingChoice == "Stay" or raw.endingChoice == "Return")
		and raw.endingChoice
		or ""

	return {
		schemaVersion = CURRENT_SCHEMA,
		allowance = finiteInteger(raw.allowance, 0, 0, 2_000_000_000),
		machineStage = finiteInteger(raw.machineStage, 0, 0, MACHINE_STAGE_COUNT),
		pendingPartStage = finiteInteger(raw.pendingPartStage, 0, 0, MACHINE_STAGE_COUNT),
		tutorialSeen = raw.tutorialSeen == true,
		totalTasks = totalTasks,
		cycleIndex = math.floor(totalTasks / TASK_COUNT) + 1,
		cycleTaskIndex = (totalTasks % TASK_COUNT) + 1,
		postRevealCyclesCompleted = finiteInteger(raw.postRevealCyclesCompleted, 0, 0, 10_000_000),
		firstHorrorRevealed = raw.firstHorrorRevealed == true,
		horrorEncountersSurvived = finiteInteger(raw.horrorEncountersSurvived, 0, 0, 10_000_000),
		horrorEncountersCaught = finiteInteger(raw.horrorEncountersCaught, 0, 0, 10_000_000),
		horrorCurrentStreak = finiteInteger(raw.horrorCurrentStreak, 0, 0, 10_000_000),
		horrorLongestStreak = finiteInteger(raw.horrorLongestStreak, 0, 0, 10_000_000),
		backroomsDiscovered = raw.backroomsDiscovered == true,
		domeDiscovered = raw.domeDiscovered == true,
		endingCompleted = raw.endingCompleted == true,
		endingChoice = endingChoice,
		postgameUnlocked = raw.postgameUnlocked == true,
		boomboxPurchased = boomboxPurchased,
		boomboxPlaced = boomboxPlaced,
		boomboxNextPlayAt = finiteInteger(raw.boomboxNextPlayAt, 0, 0, 4_102_444_800),
		boomboxAutoplayPurchased = boomboxPurchased and raw.boomboxAutoplayPurchased == true,
		taskAutomationInstalled = installed,
		pendingTaskUpgradeId = pendingUpgradeId,
		bankHackSuccesses = finiteInteger(raw.bankHackSuccesses, 0, 0, 1_000_000),
		secretBunkerPurchased = bunkerPurchased,
		secretBunkerReadyAt = bunkerReadyAt,
		chemistrySetupPurchased = chemistryPurchased,
		chemistrySetupPlaced = chemistryPlaced,
		candyBatchReady = candyBatchReady,
		candyBatchToken = candyBatchToken,
		candyDeliveryActive = candyDeliveryActive,
		candyDeliveryToken = candyDeliveryToken,
		candyBatchesSold = finiteInteger(raw.candyBatchesSold, 0, 0, 10_000_000),
	}
end

return ProfileMigrationOracle
