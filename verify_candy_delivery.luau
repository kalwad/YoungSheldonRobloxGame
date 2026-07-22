--!nonstrict
-- Static + live audit for the server-authoritative Blue Rock Candy delivery.
-- This verifier intentionally keys off persistent fields, object attributes,
-- and configured names instead of local helper-function names.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, "[CandyDeliveryAudit] " .. message)
end

local function has(source, token, message)
	check(string.find(source, token, 1, true) ~= nil, message)
end

local function hasAny(source, tokens, message)
	for _, token in ipairs(tokens) do
		if string.find(source, token, 1, true) then
			check(true, message)
			return token
		end
	end
	check(false, message)
	return nil
end

local function countPlain(source, token)
	local count = 0
	local cursor = 1
	while true do
		local at = string.find(source, token, cursor, true)
		if not at then return count end
		count += 1
		cursor = at + #token
	end
end

local function contextContaining(source, anchorTokens, requiredTokens, radius, label)
	for _, anchor in ipairs(anchorTokens) do
		local cursor = 1
		while true do
			local at = string.find(source, anchor, cursor, true)
			if not at then break end
			local candidate = string.sub(source, math.max(1, at - radius), math.min(#source, at + #anchor + radius))
			local containsAll = true
			for _, required in ipairs(requiredTokens) do
				if not string.find(candidate, required, 1, true) then
					containsAll = false
					break
				end
			end
			if containsAll then
				check(true, label)
				return candidate
			end
			cursor = at + #anchor
		end
	end
	check(false, label)
	return ""
end

local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
check(gameRoot and gameRoot:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
local configModule = gameRoot:FindFirstChild("Config")
check(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config is missing")
local Config
if RunService:IsRunning() then
	Config = require(configModule)
else
	-- Plugin-mode requires survive source syncs, so audit a disposable clone of
	-- the Config currently saved in the place instead of a stale cached result.
	local freshConfig = configModule:Clone()
	freshConfig.Name = "__CandyDeliveryAuditConfig"
	freshConfig.Parent = gameRoot
	Config = require(freshConfig)
	freshConfig:Destroy()
end
local delivery = Config.CandyDelivery
check(Config.SchemaVersion == 11, "Candy delivery persistence must use schema 11")
check(type(delivery) == "table", "Config.CandyDelivery is missing")
check(delivery.Id == "blue_rock_candy.delivery", "Candy delivery id changed")
check(delivery.Name == "Deliver Blue Rock Candy", "Candy delivery player-facing name changed")
check(delivery.ProductToolName == "Blue Rock Candy Pan", "Candy must be carried in a metal pan Tool")
check(delivery.Payout == 3000, "Los Pollos delivery payout must be $3000")
check(delivery.LogoName == "Los_Pollos_Hermanos_logo", "Uploaded logo name changed")
check(delivery.LogoCatalogAssetId == "rbxassetid://74538933380880", "Los Pollos catalog decal changed")
check(delivery.LogoAssetId == "rbxassetid://115114653936657", "Los Pollos truck must use the resolved image content")
check(delivery.TruckModelName == "LosPollosBuyerTruck", "Candy buyer truck model name changed")
check(delivery.DropPromptName == "LosPollosCandyDropPrompt", "Candy drop-off prompt name changed")
check(Config.ProfileDefaults.candyBatchReady == false, "Fresh profiles must not contain a finished chemistry batch")
check(Config.ProfileDefaults.candyBatchToken == "", "Fresh profiles must not contain a chemistry batch token")
check(Config.ProfileDefaults.candyDeliveryActive == false, "Fresh profiles must not have an active candy delivery")
check(Config.ProfileDefaults.candyBatchesSold == 0, "Fresh profiles must start with zero candy sales")

local largestTaskReward = 0
for _, taskDefinition in ipairs(Config.Tasks) do
	largestTaskReward = math.max(largestTaskReward, tonumber(taskDefinition.reward) or 0)
end
local largestPriorIncome = math.max(
	largestTaskReward,
	type(Config.BankHack) == "table" and (tonumber(Config.BankHack.MaximumReward) or 0) or 0,
	type(Config.Boombox) == "table"
		and (tonumber(Config.Boombox.PayoutPerTick) or 0) * (tonumber(Config.Boombox.MaximumPaidTicks) or 0)
		or 0
)
check(delivery.Payout > largestPriorIncome * 5, "Candy payout is not meaningfully above every prior task/income cycle")

local mainServer = ServerScriptService:FindFirstChild("CooperGame")
local taskWorld = ServerScriptService:FindFirstChild("CooperTaskWorld")
local bunkerServer = ServerScriptService:FindFirstChild("CooperBunker")
local mainClient = StarterPlayer.StarterPlayerScripts:FindFirstChild("CooperGame")
for label, item in pairs({
	["CooperGame server"] = mainServer,
	["CooperTaskWorld"] = taskWorld,
	["CooperBunker server"] = bunkerServer,
	["CooperGame client"] = mainClient,
}) do
	check(item and item:IsA("LuaSourceContainer"), label .. " is missing")
end

local mainSource = mainServer.Source
local worldSource = taskWorld.Source
local bunkerSource = bunkerServer.Source
local clientSource = mainClient.Source
has(mainSource, 'state:SetAttribute("SupportsCandyDelivery", true)', "Shared runtime state does not advertise candy delivery")

for _, token in ipairs({
	"candyBatchReady",
	"candyBatchToken",
	"candyDeliveryActive",
	"candyDeliveryToken",
	"candyBatchesSold",
	"candyDelivery",
	"CandyDeliveryDropoff",
}) do
	has(mainSource, token, "Family server is missing " .. token)
end
has(mainSource, "CooperGameProfileLoaded", "Candy delivery must wait for the authoritative profile")
has(mainSource, "local candyBatchReady = chemistrySetupPlaced", "Schema-11 sanitizer does not restore ready batches")
has(mainSource, "and not candyDeliveryActive", "Legacy active delivery contracts must win over impossible simultaneous ready state")
local producedSource = contextContaining(
	mainSource,
	{ "local function createCandyBatch" },
	{ "candyBatchReady", "candyBatchToken", "GenerateGUID", "markDirty", "saveProfile" },
	5200,
	"Reaction completion must create and immediately persist one durable ready-batch token"
)
has(producedSource, 'metadata.productKind ~= "BlueRockCandy"', "Only the trusted BlueRockCandy product may create a ready batch")
has(producedSource, "profile.data.candyDeliveryActive == true", "A new reaction batch must be blocked by an active delivery")
has(producedSource, "profile.data.candyBatchReady == true", "Reaction completion retries must reuse an existing ready batch")
has(producedSource, "saveProfile(profile.player, false)", "Finished candy must be saved before relying on the physical tray")

local collectionTransitionSource = contextContaining(
	mainSource,
	{ "local function beginCandyDelivery" },
	{ "reportedToken", "candyBatchReady", "candyBatchToken", "candyDeliveryActive", "candyDeliveryToken" },
	5200,
	"Collection must atomically move the exact ready token into the buyer contract"
)
has(collectionTransitionSource, "reportedToken ~= profile.data.candyBatchToken", "Collection must reject a stale or forged ready-batch token")
has(collectionTransitionSource, "profile.data.candyBatchReady = false", "Collection must consume ready state")
has(collectionTransitionSource, 'profile.data.candyBatchToken = ""', "Collection must consume the ready token")
has(collectionTransitionSource, "profile.data.candyDeliveryToken = reportedToken", "Collection must reuse the same one-time token for delivery")
local readyClearAt = string.find(collectionTransitionSource, "profile.data.candyBatchReady = false", 1, true)
local activeSetAt = string.find(collectionTransitionSource, "profile.data.candyDeliveryActive = true", 1, true)
check(readyClearAt ~= nil and activeSetAt ~= nil and readyClearAt < activeSetAt, "Ready state must be consumed before delivery becomes active")
hasAny(mainSource, {
	"CandyBatchCollected",
	"CandyBatchReady",
	"CandyPanCollected",
	"ChemistryCandyCollected",
}, "Family server is missing the server-only chemistry production event")
local completionEventName = hasAny(mainSource, {
	"CandyBatchDelivered",
	"CandyDeliveryCompleted",
	"LosPollosCandyDelivered",
}, "Family server is missing the server-only candy completion event")

hasAny(mainSource, {
	'ensureServerEvent("BindableEvent", "ReportAction")',
	'ensureServerEvent("BindableEvent", "CandyDeliveryCompleted")',
	'ensureServerEvent("BindableEvent", "CandyBatchDelivered")',
}, "Candy completion must enter the Family server through a server-only BindableEvent")
local payoutSource = contextContaining(
	mainSource,
	{ completionEventName or "CandyBatchDelivered" },
	{ "candyDeliveryActive", "candyBatchesSold", "setAllowance", "candyDeliveryConfig.Payout" },
	3900,
	"Candy payout path must validate active state, count the sale, and award allowance"
)
has(payoutSource, "profile.data.candyDeliveryActive", "Candy payout must consume the persistent active state")
has(payoutSource, "profile.data.candyDeliveryToken", "Candy payout must validate and consume the one-time batch token")
has(payoutSource, "reportedToken", "Candy payout must reject a missing or replayed batch token")
has(payoutSource, "profile.data.candyBatchesSold", "Candy payout must persist the completed sale count")
has(payoutSource, "candyDeliveryConfig.Payout", "Candy payout must use the configured server value")
check(countPlain(payoutSource, "setAllowance(") == 1, "Candy completion context has more than one allowance mutation")
local activeClearAt = string.find(payoutSource, "profile.data.candyDeliveryActive = false", 1, true)
local tokenClearAt = string.find(payoutSource, 'profile.data.candyDeliveryToken = ""', 1, true)
local allowanceAt = string.find(payoutSource, "setAllowance(", 1, true)
check(
	activeClearAt ~= nil and tokenClearAt ~= nil and allowanceAt ~= nil
		and activeClearAt < allowanceAt and tokenClearAt < allowanceAt,
	"Candy active state and one-time token must be consumed before allowance is awarded"
)

local snapshotSource = contextContaining(
	mainSource,
	{ "targetHint = active", "CandyDeliveryDropoff_" },
	{ "candyDeliveryActive", "CandyDeliveryDropoff", "Payout" },
	2200,
	"Authoritative snapshot must expose the active candy task, target, and payout"
)
has(snapshotSource, "candyDeliveryActive", "Candy snapshot must derive active state from the profile")
has(snapshotSource, "CandyDeliveryDropoff", "Candy snapshot must route guidance to the buyer truck")
has(mainSource, "readyBatchToken", "Candy snapshot/API must restore the finished uncollected token")
has(mainSource, 'SetAttribute("CooperCandyBatchReady"', "Ready-batch restoration must have a server-owned player attribute")

for _, token in ipairs({
	"LosPollosBuyerTruck",
	"LosPollosDeliveryTruck",
	"LosPollosCandyDropPrompt",
	"CandyDeliveryDropoff",
	"OwnerUserId",
	"CooperBlueRockCandy",
	"BlueRockCandy",
	"LogoAssetId",
	"batchToken",
	"BatchToken",
	"Recover",
}) do
	has(worldSource, token, "Task world is missing " .. token)
end

-- Queue authority: one worker owns the shared street, and a player remains
-- reserved from the instant they leave the FIFO through arrival, parking, exit,
-- and any timed retry. This catches the former ordinary-truck race where the
-- four-second recovery scan launched several waiting workers for one contract.
has(worldSource, "local buyerQueueRunning = false", "Buyer route is missing its single-worker lock")
has(worldSource, "local buyerInProgress = {}", "Buyer route is missing per-owner in-progress reservations")
has(worldSource, "local ordinaryDeliveryTurnReserved = false", "Buyer route is missing its reciprocal ordinary-delivery turn")
has(
	worldSource,
	"buyerQueued[player] or buyerInProgress[player]",
	"Buyer recovery can requeue an owner who is already queued or in progress"
)
local buyerQueueSource = contextContaining(
	worldSource,
	{ "runBuyerQueue = function()" },
	{ "buyerQueueRunning = true", "buyerInProgress[player] = true", "xpcall", "activeBuyerSession == session" },
	18000,
	"Buyer route must use one failure-safe worker with owner and session reservations"
)
for _, marker in ipairs({
	"if buyerQueueRunning or activeBuyerSession or #buyerQueue == 0 then",
	"buyerQueueRunning = true",
	"buyerInProgress[player] = true",
	"while deliveryRunning and player.Parent == Players do",
	"buyerRouteOccupied = true",
	"routeReservationPending = true",
	"if activeBuyerSession == session then",
	"if activeBuyerSession == workerSession then",
	"buyerInProgress[player] ~= true",
	"buyerQueueRunning = false",
	"ordinaryDeliveryTurnReserved = true",
}) do
	has(buyerQueueSource, marker, "Buyer queue lifecycle is missing: " .. marker)
end
local workerLockAt = string.find(buyerQueueSource, "buyerQueueRunning = true", 1, true)
local workerSpawnAt = string.find(buyerQueueSource, "task.spawn(function()", workerLockAt or 1, true)
check(
	workerLockAt ~= nil and workerSpawnAt ~= nil and workerLockAt < workerSpawnAt,
	"Buyer queue must reserve its worker synchronously before spawning or yielding"
)
local ownerReservationAt = string.find(buyerQueueSource, "buyerInProgress[player] = true", 1, true)
local ordinaryWaitAt = string.find(buyerQueueSource, "while deliveryRunning and player.Parent == Players do", ownerReservationAt or 1, true)
local routeLockAt = string.find(buyerQueueSource, "buyerRouteOccupied = true", ordinaryWaitAt or 1, true)
local truckCreateAt = string.find(buyerQueueSource, "createLosPollosBuyerTruck(player)", routeLockAt or 1, true)
check(
	ownerReservationAt ~= nil and ordinaryWaitAt ~= nil and routeLockAt ~= nil and truckCreateAt ~= nil
		and ownerReservationAt < ordinaryWaitAt and ordinaryWaitAt < routeLockAt and routeLockAt < truckCreateAt,
	"Buyer owner/route reservations must bracket the ordinary-truck wait and truck construction"
)
has(
	buyerQueueSource,
	"warn(\"[CooperTaskWorld] Buyer queue failed safely: \"",
	"Buyer worker errors are not surfaced after fail-safe cleanup"
)
local normalReleaseGuardAt = string.find(buyerQueueSource, "if activeBuyerSession == session then", 1, true)
local activeSessionClearAt = string.find(buyerQueueSource, "activeBuyerSession = nil", normalReleaseGuardAt or 1, true)
local routeReleaseAt = string.find(buyerQueueSource, "buyerRouteOccupied = false", activeSessionClearAt or 1, true)
local sessionReleaseAt = string.find(buyerQueueSource, "workerSession = nil", routeReleaseAt or 1, true)
local pendingOrdinaryAt = string.find(buyerQueueSource, "if #deliveryQueue > 0 then", sessionReleaseAt or 1, true)
local ordinaryReservationAt = string.find(buyerQueueSource, "ordinaryDeliveryTurnReserved = true", pendingOrdinaryAt or 1, true)
local ordinaryWakeGuardAt = string.find(buyerQueueSource, "if runDeliveryQueue then", ordinaryReservationAt or 1, true)
local ordinaryWakeAt = string.find(buyerQueueSource, "runDeliveryQueue()", ordinaryWakeGuardAt or 1, true)
local perSessionYieldAt = string.find(buyerQueueSource, "task.wait(0.5)", ordinaryWakeAt or 1, true)
local buyerWorkerStoppedAt = string.find(buyerQueueSource, "buyerQueueRunning = false", perSessionYieldAt or 1, true)
check(
	normalReleaseGuardAt ~= nil and activeSessionClearAt ~= nil and routeReleaseAt ~= nil
		and sessionReleaseAt ~= nil and pendingOrdinaryAt ~= nil and ordinaryReservationAt ~= nil
		and ordinaryWakeGuardAt ~= nil and ordinaryWakeAt ~= nil and perSessionYieldAt ~= nil
		and buyerWorkerStoppedAt ~= nil
		and normalReleaseGuardAt < activeSessionClearAt and activeSessionClearAt < routeReleaseAt
		and routeReleaseAt < sessionReleaseAt and sessionReleaseAt < pendingOrdinaryAt
		and pendingOrdinaryAt < ordinaryReservationAt and ordinaryReservationAt < ordinaryWakeGuardAt
		and ordinaryWakeGuardAt < ordinaryWakeAt and ordinaryWakeAt < perSessionYieldAt
		and perSessionYieldAt < buyerWorkerStoppedAt,
	"Each completed buyer visit must yield one turn to an already-paid ordinary delivery"
)
local failureGuardAt = string.find(
	buyerQueueSource,
	"not ok and not buyerRouteOccupied and not deliveryRunning and #deliveryQueue > 0",
	buyerWorkerStoppedAt or 1,
	true
)
local failureReservationAt = string.find(buyerQueueSource, "ordinaryDeliveryTurnReserved = true", failureGuardAt or 1, true)
local failureWakeGuardAt = string.find(
	buyerQueueSource,
	"if not buyerRouteOccupied and runDeliveryQueue then",
	failureReservationAt or 1,
	true
)
local failureWakeAt = string.find(buyerQueueSource, "runDeliveryQueue()", failureWakeGuardAt or 1, true)
check(
	failureGuardAt ~= nil and failureReservationAt ~= nil and failureWakeGuardAt ~= nil and failureWakeAt ~= nil
		and buyerWorkerStoppedAt < failureGuardAt and failureGuardAt < failureReservationAt
		and failureReservationAt < failureWakeGuardAt and failureWakeGuardAt < failureWakeAt,
	"A failed buyer worker must reserve and wake one ordinary paid-delivery turn after releasing its locks"
)
has(
	worldSource,
	"buyerInProgress[player] = nil",
	"Leaving players do not release their buyer in-progress reservation"
)

local ordinaryQueueSource = contextContaining(
	worldSource,
	{ "runDeliveryQueue = function()" },
	{
		"buyerQueueRunning or #buyerQueue > 0",
		"local hasReservedOrdinaryTurn = ordinaryDeliveryTurnReserved and #deliveryQueue > 0",
		"and not hasReservedOrdinaryTurn",
		"ordinaryDeliveryTurnReserved = false",
		"local workerOk, workerFailure = xpcall(function()",
		"local itemOk, itemFailure = xpcall(function()",
		"deliveryInFlightKeys[entry.key] = nil",
		"deliveryRunning = false",
		"runBuyerQueue()",
	},
	15000,
	"Ordinary delivery route must fail safely and yield deterministically to a waiting buyer"
)
local reservedTurnAt = string.find(ordinaryQueueSource, "local hasReservedOrdinaryTurn", 1, true)
local reservedGateAt = string.find(ordinaryQueueSource, "and not hasReservedOrdinaryTurn", reservedTurnAt or 1, true)
local ordinaryLockAt = string.find(ordinaryQueueSource, "deliveryRunning = true", reservedGateAt or 1, true)
local reservationClearAt = string.find(ordinaryQueueSource, "ordinaryDeliveryTurnReserved = false", ordinaryLockAt or 1, true)
local ordinarySpawnAt = string.find(ordinaryQueueSource, "task.spawn(function()", reservationClearAt or 1, true)
check(
	reservedTurnAt ~= nil and reservedGateAt ~= nil and ordinaryLockAt ~= nil
		and reservationClearAt ~= nil and ordinarySpawnAt ~= nil
		and reservedTurnAt < reservedGateAt and reservedGateAt < ordinaryLockAt
		and ordinaryLockAt < reservationClearAt and reservationClearAt < ordinarySpawnAt,
	"An ordinary fairness turn must be claimed atomically before its worker yields"
)
local oneTripGuardAt = string.find(
	ordinaryQueueSource,
	"if buyerQueueRunning or #buyerQueue > 0 or entryRequeued then",
	ordinarySpawnAt or 1,
	true
)
local oneTripBreakAt = string.find(ordinaryQueueSource, "break", oneTripGuardAt or 1, true)
local ordinaryWorkerReleaseAt = string.find(ordinaryQueueSource, "deliveryRunning = false", oneTripBreakAt or 1, true)
local buyerResumeGuardAt = string.find(
	ordinaryQueueSource,
	"if buyerQueueRunning or #buyerQueue > 0 then",
	ordinaryWorkerReleaseAt or 1,
	true
)
local buyerResumeAt = string.find(ordinaryQueueSource, "runBuyerQueue()", buyerResumeGuardAt or 1, true)
local ordinaryRetryBranchAt = string.find(
	ordinaryQueueSource,
	"elseif #deliveryQueue > 0 then",
	buyerResumeAt or 1,
	true
)
check(
	oneTripGuardAt ~= nil and oneTripBreakAt ~= nil and ordinaryWorkerReleaseAt ~= nil
		and buyerResumeGuardAt ~= nil and buyerResumeAt ~= nil and ordinaryRetryBranchAt ~= nil
		and ordinarySpawnAt < oneTripGuardAt and oneTripGuardAt < oneTripBreakAt
		and oneTripBreakAt < ordinaryWorkerReleaseAt and ordinaryWorkerReleaseAt < buyerResumeGuardAt
		and buyerResumeGuardAt < buyerResumeAt and buyerResumeAt < ordinaryRetryBranchAt,
	"A reserved ordinary worker must complete at most one trip before returning the shared street to waiting buyers"
)
has(ordinaryQueueSource, "pcall(setTruckVisible, false)", "Ordinary truck errors do not force the shared route vehicle hidden")
has(ordinaryQueueSource, "Delivery queue item failed safely", "Ordinary delivery item failures are not surfaced after cleanup")
has(ordinaryQueueSource, "task.delay(math.max(0.05, retryDelay)", "Ordinary paid deliveries do not resume after a safe retry delay")

hasAny(worldSource, {
	'Instance.new("Decal")',
	'Instance.new("ImageLabel")',
	'Instance.new("ImageButton")',
}, "Buyer truck must render the uploaded logo on a Roblox image object")
has(worldSource, 'SetAttribute("LosPollosDeliveryTruck", true)', "Buyer truck must carry its runtime identity attribute")
local truckBuildSource = contextContaining(
	worldSource,
	{ 'SetAttribute("LosPollosDeliveryTruck", true)' },
	{ "OwnerUserId", "ownerPlayer.UserId", "LogoAssetId", "YellowCab", "YellowCargoBox" },
	6200,
	"Buyer truck build must bind its owner, yellow body, and configured logo"
)
has(truckBuildSource, 'SetAttribute("OwnerUserId", ownerPlayer.UserId)', "Buyer truck must be owner-locked")
has(truckBuildSource, "candyDeliveryConfig.LogoCatalogAssetId", "Buyer truck must retain the uploaded decal identity")
has(truckBuildSource, "candyDeliveryConfig.LogoAssetId", "Buyer truck logo must come from the authoritative config")
hasAny(truckBuildSource, {
	'Instance.new("Decal")',
	'Instance.new("ImageLabel")',
	'Instance.new("ImageButton")',
}, "Buyer truck build does not actually create its configured logo image")
hasAny(worldSource, {
	"CollectionService:AddTag",
	'SetAttribute("CandyDeliveryDropoff", true)',
}, "Candy drop-off anchor must be tagged or attributed for guidance")

local dropoffSource = contextContaining(
	worldSource,
	{ "LosPollosCandyDropPrompt", "DropPromptName" },
	{ "OwnerUserId", "CooperBlueRockCandy", "BlueRockCandy", "CandyDeliveryDropoff" },
	7000,
	"Candy drop-off must validate the owner, product, and drop zone"
)
hasAny(dropoffSource, {
	"tool.Parent ~= character",
	"tool.Parent == character",
	"candidate.Parent == character",
	"candidate.Parent ~= character",
	"character:GetChildren()",
}, "Candy delivery must require the pan to be equipped")
hasAny(dropoffSource, {
	'tool:GetAttribute("OwnerUserId") ~= player.UserId',
	'tool:GetAttribute("OwnerUserId") == player.UserId',
	'candidate:GetAttribute("OwnerUserId") ~= player.UserId',
	'candidate:GetAttribute("OwnerUserId") == player.UserId',
}, "Candy drop-off must validate Tool ownership")
hasAny(dropoffSource, {
	".Magnitude",
	"isNear(",
	"withinDistance",
}, "Candy drop-off must validate player proximity")
hasAny(dropoffSource, {
	"candyDeliveryRecords",
	"activeCandyDeliveries",
	"candyDeliveryByPlayer",
	"CandyDeliveryActive",
	"candyDeliveryActive",
	"liveContract.active",
	"contract.active",
}, "Task world must validate active server delivery state")
has(dropoffSource, "prompt.Enabled = true", "Buyer truck must enable its drop-off prompt after parking")
has(dropoffSource, "prompt.Triggered:Connect", "Buyer truck is missing its server-side drop-off handler")
has(dropoffSource, ":Destroy()", "A successful delivery must consume the physical candy pan")
hasAny(dropoffSource, {
	':Invoke("ReportAction"',
	":Invoke(",
	":Fire(",
	"invokeFamily(",
}, "Task world must report completion through a server-only event or API")
local reportCallAt = string.find(dropoffSource, "invokeFamily(", 1, true)
	or string.find(dropoffSource, ':Invoke("ReportAction"', 1, true)
	or string.find(dropoffSource, ":Invoke(", 1, true)
local acceptedAt = string.find(dropoffSource, "accepted == true", reportCallAt or 1, true)
	or string.find(dropoffSource, "if accepted then", reportCallAt or 1, true)
local destroyAt = string.find(dropoffSource, "tool:Destroy()", acceptedAt or 1, true)
check(
	reportCallAt ~= nil and acceptedAt ~= nil and destroyAt ~= nil
		and reportCallAt < acceptedAt and acceptedAt < destroyAt,
	"Candy pan must only be destroyed after the Family server accepts the one-time payout"
)
check(not string.find(dropoffSource, "allowance", 1, true), "Task world must never award candy money directly")
check(not string.find(worldSource, "setAllowance(", 1, true), "Only the Family server may mutate allowance")

has(bunkerSource, '"CooperBlueRockCandy"', "Chemistry output must retain the authoritative candy marker")
has(bunkerSource, '"BlueRockCandy"', "Chemistry output must retain the product kind")
has(bunkerSource, 'SetAttribute("RecoveredCandyDelivery", true)', "Recovered candy pan must be marked for diagnostics")
has(bunkerSource, 'GetAttributeChangedSignal("CooperCandyDeliveryActive")', "Candy pan recovery must follow authoritative delivery state")
has(bunkerSource, 'GetAttributeChangedSignal("CooperCandyBatchReady")', "Finished uncollected batches must react to profile restoration")
has(bunkerSource, "CharacterAdded", "Candy pan recovery must run after respawn")
hasAny(bunkerSource, {
	"CandyBatchCollected",
	"CandyBatchReady",
	"CandyPanCollected",
	"ChemistryCandyCollected",
}, "Collecting the chemistry output must notify the Family server")
local productionSource = contextContaining(
	bunkerSource,
	{ "CandyBatchCollected", "CandyBatchReady", "CandyPanCollected", "ChemistryCandyCollected" },
	{ "ReportAction", "batchToken", "backpack", "RewardAvailable" },
	4300,
	"Chemistry collection must obtain an authoritative contract token before granting the pan"
)
hasAny(productionSource, {
	"invokeFamily(",
	":Invoke(",
	":Fire(",
}, "Chemistry must assign the delivery task through a server-only API")
has(productionSource, "accepted ~= true", "A rejected buyer contract must leave the chemistry reward collectible")
has(productionSource, "candyTool.Parent = backpack", "Accepted chemistry output must enter the numbered hotbar")
has(productionSource, "batchToken = presentedBatchToken", "Collection must submit the exact durable tray token")
for _, token in ipairs({
	"CandyBatchProduced",
	"candyPresentation.queuePlayer",
	"candyPresentation.release",
	"candyPresentation.pump",
	"leaseSeconds = 35",
	"retrySeconds = 12",
	"presentRadius = 30",
	"RewardLeaseExpiresAt",
	"RewardQueueDepth",
}) do
	has(bunkerSource, token, "Durable/fair chemistry output is missing " .. token)
end
has(bunkerSource, "readyBatchToken", "Bunker must reconstruct the physical tray from the saved snapshot token")
has(bunkerSource, "presentationSerial == candyPresentation.serial", "An expired tray lease must be cancellation-safe")
has(bunkerSource, "The shared output tray retracted for the next chemist", "Lease expiry must explain that the durable batch remains saved")
check(not string.find(bunkerSource, "CandyCount", 1, true), "Candy production must create one physical pan per delivery, not stack a count")
check(not string.find(bunkerSource, "BlueRockCandyDisplayStick", 1, true), "Chemistry output still contains the old wooden stick")

check(not string.find(clientSource, completionEventName or "CandyDeliveryCompleted", 1, true), "Client must not invoke the server completion event")
check(not string.find(clientSource, "setAllowance", 1, true), "Client must never mutate candy allowance")
check(not string.find(clientSource, 'FireServer("CompleteCandyDelivery"', 1, true), "Client exposes a fake candy-completion request")
for _, token in ipairs({
	"snapshot.candyDelivery",
	"DELIVER BLUE ROCK CANDY TO LOS POLLOS TRUCK",
	"CandyDeliveryStarted",
	"CandyDeliveryComplete",
}) do
	has(clientSource, token, "Client is missing candy task/UI marker " .. token)
end

if RunService:IsRunning() then
	local state = gameRoot:FindFirstChild("State")
	check(state and state:IsA("Folder"), "Runtime CooperGame.State is missing")
	check(state:GetAttribute("SchemaVersion") == 11, "Runtime shared state does not expose schema 11")
	check(state:GetAttribute("SupportsCandyDelivery") == true, "Runtime shared state has candy delivery disabled")
	local serverEvents = ServerScriptService:FindFirstChild(Config.ServerEventsName or "CooperGameServerEvents")
	local familyAPI = serverEvents and serverEvents:FindFirstChild("API")
	check(familyAPI and familyAPI:IsA("BindableFunction"), "Runtime Family API is missing")
	for _, player in ipairs(Players:GetPlayers()) do
		local snapshot = familyAPI:Invoke("GetSnapshot", player)
		local candyState = type(snapshot) == "table" and snapshot.candyDelivery or nil
		check(type(candyState) == "table", player.Name .. " has no candy snapshot")
		check(not (candyState.batchReady == true and candyState.active == true), player.Name .. " owns ready and delivery states simultaneously")
		check(player:GetAttribute("CooperCandyBatchReady") == (candyState.batchReady == true), player.Name .. " ready-batch attribute disagrees with snapshot")
		if candyState.batchReady == true then
			check(type(candyState.readyBatchToken) == "string" and #candyState.readyBatchToken >= 8, player.Name .. " ready batch has no durable token")
			check(candyState.batchToken == nil, player.Name .. " ready batch leaked into the buyer contract token")
		end
	end
	local trucks = {}
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("Model") and (item:GetAttribute("LosPollosDeliveryTruck") == true or item.Name == delivery.TruckModelName) then
			table.insert(trucks, item)
		end
	end
	check(#trucks <= 1, "Shared buyer route has multiple active Los Pollos trucks")
	if #trucks > 0 then
		local ordinaryTruck = Workspace:FindFirstChild("CooperDeliveryTruck", true)
		check(ordinaryTruck and ordinaryTruck:IsA("Model"), "Ordinary delivery truck is missing during buyer-route audit")
		check(
			ordinaryTruck:GetAttribute("Hidden") == true,
			"Ordinary and Los Pollos trucks are occupying the shared route together"
		)
	end

	local seenOwners = {}
	for _, truck in ipairs(trucks) do
		check(truck.Name == delivery.TruckModelName, "Buyer truck has the wrong model name")
		check(truck:GetAttribute("LosPollosDeliveryTruck") == true, "Buyer truck is missing its identity attribute")
		local ownerUserId = tonumber(truck:GetAttribute("OwnerUserId")) or 0
		check(ownerUserId > 0, "Buyer truck is missing a valid owner")
		check(seenOwners[ownerUserId] == nil, "One player has multiple active buyer trucks")
		seenOwners[ownerUserId] = true
		local owner = Players:GetPlayerByUserId(ownerUserId)
		check(owner ~= nil, "Buyer truck belongs to a player who left")

		local yellowParts = 0
		local collidableParts = 0
		local visibleParts = 0
		local wheels = 0
		local logos = 0
		local prompts = {}
		local dropAnchors = {}
		for _, descendant in ipairs(truck:GetDescendants()) do
			if descendant:IsA("BasePart") then
				if descendant.Transparency < 0.95 then
					visibleParts += 1
					if descendant.CanCollide then collidableParts += 1 end
				end
				if descendant.Color.R >= 0.72 and descendant.Color.G >= 0.48 and descendant.Color.B <= 0.28 then
					yellowParts += 1
				end
				if string.find(string.lower(descendant.Name), "wheel", 1, true) then wheels += 1 end
				if descendant:GetAttribute("CandyDeliveryDropoff") == true
					or CollectionService:HasTag(descendant, "CandyDeliveryDropoff")
				then
					table.insert(dropAnchors, descendant)
				end
			elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
				if descendant.Texture == delivery.LogoAssetId then logos += 1 end
			elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				if descendant.Image == delivery.LogoAssetId then logos += 1 end
			elseif descendant:IsA("ProximityPrompt") and descendant.Name == delivery.DropPromptName then
				table.insert(prompts, descendant)
			end
		end

		check(visibleParts >= 15, "Buyer truck is missing physical vehicle detail")
		check(yellowParts >= 2, "Buyer truck does not read clearly as yellow")
		check(collidableParts >= 4, "Player can walk through too much of the buyer truck")
		check(wheels >= 4, "Buyer truck needs four recognizable wheels")
		check(logos >= 1, "Buyer truck does not display the uploaded Los Pollos logo")
		check(#prompts == 1, "Buyer truck must have exactly one candy drop-off prompt")
		check(#dropAnchors >= 1, "Buyer truck is missing its tagged candy drop-off anchor")
		local prompt = prompts[1]
		check(not prompt.RequiresLineOfSight, "Truck drop-off should remain accessible beside the vehicle")
		check(prompt.MaxActivationDistance >= 5 and prompt.MaxActivationDistance <= 12, "Truck drop-off distance is unreasonable")
		check(prompt.Parent and prompt.Parent:IsA("BasePart"), "Truck drop-off prompt must be attached to a physical anchor")

		if owner then
			local pans = {}
			for _, container in ipairs({ owner:FindFirstChildOfClass("Backpack"), owner.Character }) do
				if container then
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("Tool") and child.Name == delivery.ProductToolName then
							table.insert(pans, child)
						end
					end
				end
			end
			local deliveryActive = owner:GetAttribute("CooperCandyDeliveryActive") == true
			check(
				(deliveryActive and #pans == 1) or (not deliveryActive and #pans == 0),
				"Buyer-truck lifecycle and the owner's physical candy pan disagree"
			)
			if deliveryActive then
				local panTool = pans[1]
				check(panTool:GetAttribute("OwnerUserId") == ownerUserId, "Candy pan owner does not match its buyer truck")
				check(panTool:GetAttribute("CooperBlueRockCandy") == true, "Candy pan lost its authoritative marker")
				check(panTool:GetAttribute("ProductKind") == "BlueRockCandy", "Candy pan has the wrong product kind")
				check(type(panTool:GetAttribute("BatchToken")) == "string", "Candy pan is missing its one-time batch token")
				check(panTool:GetAttribute("CandyCount") == nil, "Active delivery uses an invisible stacked candy count")
				local handle = panTool:FindFirstChild("Handle")
				check(handle and handle:IsA("BasePart"), "Carried candy pan is missing its Handle")
				check(
					handle.Material == Enum.Material.Metal or handle.Material == Enum.Material.DiamondPlate,
					"Carried candy pan Handle is not metal"
				)
				check(handle.Size.Y < handle.Size.X and handle.Size.Y < handle.Size.Z, "Carried candy pan is not wide and shallow")
			end
		end
	end
end

print(string.format(
	"[CandyDeliveryAudit] PASS: %d checks, $%d payout, logo %s",
	checks,
	delivery.Payout,
	delivery.LogoAssetId
))
