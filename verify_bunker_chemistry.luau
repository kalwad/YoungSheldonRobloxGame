--!nonstrict
-- Static + live audit for the bunker research terminal, physical chemistry
-- apparatus, and its carryable metal-pan candy output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, "[BunkerChemistryAudit] " .. message)
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

local function ordered(source, tokens, message)
	local cursor = 1
	for _, token in ipairs(tokens) do
		local at = string.find(source, token, cursor, true)
		check(at ~= nil, message .. ": missing or out-of-order " .. token)
		if not at then
			return
		end
		cursor = at + #token
	end
end

local function section(source, firstToken, nextToken, label)
	local first = string.find(source, firstToken, 1, true)
	check(first ~= nil, label .. " start is missing")
	local after = string.find(source, nextToken, first + #firstToken, true)
	check(after ~= nil, label .. " end is missing")
	return string.sub(source, first, after - 1)
end

-- Isolate a stable data contract without depending on the implementation's
-- local function name. This keeps the audit useful when helpers are renamed.
local function contextAround(source, token, beforeCharacters, afterCharacters, label)
	local at = string.find(source, token, 1, true)
	check(at ~= nil, label .. " marker is missing")
	if not at then return "" end
	return string.sub(
		source,
		math.max(1, at - beforeCharacters),
		math.min(#source, at + #token + afterCharacters)
	)
end

local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
check(gameRoot and gameRoot:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
local configModule = gameRoot:FindFirstChild("Config")
check(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config is missing")
local Config
if RunService:IsRunning() then
	Config = require(configModule)
else
	-- Studio's plugin VM can retain an old ModuleScript require result after a
	-- source sync. Audit a disposable clone of the Config currently saved.
	local freshConfig = configModule:Clone()
	freshConfig.Name = "__BunkerChemistryAuditConfig"
	freshConfig.Parent = gameRoot
	Config = require(freshConfig)
	freshConfig:Destroy()
end
local chemistry = Config.ChemistrySetup
local candyDelivery = Config.CandyDelivery
check(Config.SchemaVersion == 12, "Chemistry/candy persistence must use schema 12")
check(type(chemistry) == "table", "Config.ChemistrySetup is missing")
check(chemistry.Id == "chemistry.setup", "Chemistry setup id changed")
check(chemistry.Name == "Advanced Chemistry Setup", "Chemistry setup name changed")
check(chemistry.Price == 1800, "Chemistry setup must cost $1800")
check(chemistry.InstallTarget == "ChemistrySetAnchor", "Chemistry install anchor changed")
check(Config.ProfileDefaults.chemistrySetupPurchased == false, "Fresh profiles must not own chemistry equipment")
check(Config.ProfileDefaults.chemistrySetupPlaced == false, "Fresh profiles must not have a placed chemistry lab")
check(type(candyDelivery) == "table", "Config.CandyDelivery is missing")
check(candyDelivery.ProductToolName == "Blue Rock Candy Pan", "Chemistry must produce a Blue Rock Candy Pan")
check(candyDelivery.LogoCatalogAssetId == "rbxassetid://74538933380880", "Candy buyer catalog decal changed")
check(candyDelivery.LogoAssetId == "rbxassetid://115114653936657", "Candy buyer resolved image changed")
check(Config.ProfileDefaults.candyBatchReady == false, "Fresh profiles must not have a finished uncollected candy batch")
check(Config.ProfileDefaults.candyBatchToken == "", "Fresh profiles must not have a candy batch token")
check(Config.ProfileDefaults.candyDeliveryActive == false, "Fresh profiles must not begin with an active candy delivery")
check(Config.ProfileDefaults.candyBatchesSold == 0, "Fresh profiles must begin with zero candy sales")

local state = gameRoot:FindFirstChild("State")
check(state and state:IsA("Folder"), "CooperGame.State is missing")
check(state:GetAttribute("SchemaVersion") == 12, "Shared State must advertise schema 12")
check(state:GetAttribute("SupportsSecretBunkerUnlock") == true, "Shared State lost bunker progression support")
check(state:GetAttribute("SupportsBunkerChemistrySetup") == true, "Shared State does not advertise bunker chemistry")

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
local bunker = environment and environment:FindFirstChild("BackyardBunker")
local underground = bunker and bunker:FindFirstChild("Underground")
local bay = underground and underground:FindFirstChild("FutureChemistryBay")
local pad = bay and bay:FindFirstChild("EquipmentPad")
local anchor = bay and bay:FindFirstChild("ChemistrySetAnchor")
check(bunker and bunker:IsA("Model"), "BackyardBunker is missing")
check(underground and underground:IsA("Model"), "Bunker Underground model is missing")
check(bay and bay:IsA("Model"), "FutureChemistryBay is missing")
check(pad and pad:IsA("BasePart"), "Chemistry EquipmentPad is missing")
check(anchor and anchor:IsA("BasePart"), "ChemistrySetAnchor is missing")
check(bunker:GetAttribute("ChemistryGameplayEnabled") == true, "Bunker chemistry gameplay flag is disabled")
check(bay:GetAttribute("GameplayEnabled") == true, "Chemistry bay gameplay flag is disabled")
check(anchor:GetAttribute("GameplayEnabled") == true, "Chemistry install anchor gameplay flag is disabled")
check(pad.Size.X >= 10 and pad.Size.Z >= 12, "Chemistry pad is too small for the laboratory")

local mainServer = ServerScriptService:FindFirstChild("CooperGame")
local taskWorld = ServerScriptService:FindFirstChild("CooperTaskWorld")
local bunkerServer = ServerScriptService:FindFirstChild("CooperBunker")
local mainClient = StarterPlayer.StarterPlayerScripts:FindFirstChild("CooperGame")
local bunkerClient = StarterPlayer.StarterPlayerScripts:FindFirstChild("CooperBunkerClient")
for label, item in pairs({
	["CooperGame server"] = mainServer,
	["CooperTaskWorld"] = taskWorld,
	["CooperBunker server"] = bunkerServer,
	["CooperGame client"] = mainClient,
	["CooperBunker client"] = bunkerClient,
}) do
	check(item and item:IsA("LuaSourceContainer"), label .. " is missing")
end

local mainServerSource = mainServer.Source
local taskWorldSource = taskWorld.Source
local bunkerServerSource = bunkerServer.Source
local mainClientSource = mainClient.Source
local bunkerClientSource = bunkerClient.Source

for _, token in ipairs({
	"OrderChemistrySetup",
	"validBunkerComputerSession",
	"ChemistryDeliverySpawned",
	"ChemistryCratePicked",
	"ChemistrySetupPlaced",
	"ChemistryCarryLost",
	"CooperGameProfileLoaded",
}) do
	has(mainServerSource, token, "Main server is missing " .. token)
end
has(mainServerSource, 'then "Delivery_ChemistrySetup_"', "Installed-case snapshot must use the safe per-player drop target")
local chemistryOrderSource = section(
	mainServerSource,
	"local function orderChemistrySetup(profile)",
	"local function completeSecretBunkerIfReady",
	"Chemistry purchase"
)
check(
	countPlain(chemistryOrderSource, "setAllowance(profile, profile.data.allowance - price)") == 1,
	"Chemistry purchase must have exactly one debit path"
)
check(
	countPlain(chemistryOrderSource, "profile.data.chemistrySetupPurchased = true") == 1,
	"Chemistry purchase must have exactly one entitlement mutation"
)
has(
	chemistryOrderSource,
	"TransactionRuntime.commitHostPurchase(",
	"Chemistry purchase must use the durable operation journal"
)
has(chemistryOrderSource, '"PurchaseChemistrySetup"', "Chemistry purchase needs a stable logical operation kind")
has(
	chemistryOrderSource,
	"if not purchased then",
	"Chemistry delivery must not start unless its paid entitlement was committed"
)
check(not string.find(chemistryOrderSource, "task.wait", 1, true), "Atomic chemistry purchase path must not yield")

local persistentTransitionSource = section(
	mainServerSource,
	"function TransactionRuntime.commitPersistentTransition",
	"local function pickHiddenLocation",
	"Persistent transition helper"
)
for _, marker in ipairs({
	"local existing = TransactionRuntime.findLogicalOperation(profile, kind)",
	"TransactionRuntime.commitProfileValueOperation(",
	"existing and existing.id or nil",
	"if accepted and not durable",
	'"TransactionReconciliation"',
}) do
	has(
		persistentTransitionSource,
		marker,
		"Chemistry transition durability/replay support is missing " .. marker
	)
end

local chemistryInstallSource = section(
	mainServerSource,
	'elseif eventKey == "ChemistrySetupPlaced"',
	'elseif eventKey == "ChemistryCarryLost"',
	"Chemistry install transition"
)
has(chemistryInstallSource, "profile.data.chemistrySetupPurchased", "Only a purchased chemistry setup may be installed")
has(chemistryInstallSource, '"InstallChemistrySetup"', "Chemistry installation needs a stable logical replay key")
check(
	countPlain(chemistryInstallSource, "TransactionRuntime.commitPersistentTransition(") == 1,
	"Chemistry installation must use exactly one journaled persistent transition"
)
check(
	countPlain(chemistryInstallSource, "profile.data.chemistrySetupPlaced = true") == 1,
	"Chemistry installation must have exactly one entitlement mutation"
)
has(chemistryInstallSource, "profile.data.chemistrySetupPlaced ~= true", "A duplicate chemistry install must fail mutable authorization")
has(chemistryInstallSource, 'profile.chemistryDeliveryStep == "Install"', "Chemistry installation must require its physical install phase")
has(chemistryInstallSource, '"ChemistryInstallNotAuthorized"', "Chemistry installation is missing an authoritative denial result")
has(chemistryInstallSource, "if not accepted then", "An undurable/rejected chemistry install must not consume presentation state")
has(chemistryInstallSource, "if appliedNow then", "Replay must not duplicate chemistry installation feedback or assembly")
check(
	not string.find(chemistryInstallSource, "markDirty(", 1, true)
		and not string.find(chemistryInstallSource, "saveProfile(", 1, true)
		and not string.find(chemistryInstallSource, "task.defer(saveProfile", 1, true),
	"Chemistry install must rely on commitPersistentTransition durability, not a deferred direct save"
)

for _, token in ipairs({
	"Delivery_ChemistrySetup_",
	"insideSafeInstallZone",
	"chemistryPad.CFrame * CFrame.new(0, 2.1, -4.55)",
	"recoverChemistryCarry",
	"tryInstallChemistrySetup",
}) do
	has(taskWorldSource, token, "Task world is missing " .. token)
end
local physicalInstallSource = section(
	taskWorldSource,
	"local function tryInstallChemistrySetup",
	"local chemistryInstallElapsed",
	"Physical chemistry installation"
)
local reportInstallAt = string.find(
	physicalInstallSource,
	'invokeFamily("ReportAction", player, "ChemistrySetupPlaced", {})',
	1,
	true
)
local refreshSnapshotAt = string.find(physicalInstallSource, "local refreshed = snapshot(player)", 1, true)
local consumeToolAt = string.find(physicalInstallSource, "tool:Destroy()", 1, true)
check(
	reportInstallAt ~= nil and refreshSnapshotAt ~= nil and consumeToolAt ~= nil
		and reportInstallAt < refreshSnapshotAt and refreshSnapshotAt < consumeToolAt,
	"The chemistry case must remain physical until the durable install is accepted and verified"
)
has(
	physicalInstallSource,
	"refreshed.chemistrySetup.placed ~= true",
	"World installation must verify the journaled placed entitlement before consuming the paid case"
)

for _, token in ipairs({
	"BunkerResearchTerminal",
	"BunkerTerminalInputAnchor",
	"chemistryLab.Name = chemistryConfig.ModelName",
	"DoChemistryPrompt",
	"ErlenmeyerFlask",
	"RoundBottomFlask",
	"Beaker",
	"Condenser",
	"TestTubeRack",
	"TestTube",
	'"ChemistryGlassware"',
	'"ChemistryTubeSegment"',
	'"ChemistryTubeFluid"',
	'"ChemistryPipeSegment"',
	'"ChemistryMotionPart"',
	"CHEMISTRY_EXPERIMENT_DURATION",
	"chemistryExperimentActive",
	"startChemistryExperiment",
	"resetChemistryExperimentVisuals",
	'chemistryLab:SetAttribute("ExperimentState"',
	'chemistryLab:SetAttribute("ExperimentActive"',
	'chemistryLab:SetAttribute("RewardState"',
	'chemistryLab:SetAttribute("RewardAvailable"',
	'chemistryLab:SetAttribute("RewardOwnerUserId"',
	'"ChemistryOutputDrawer"',
	'"ChemistryCandyReward"',
	'"CandySmoke"',
	'"CollectBlueRockCandyPrompt"',
	'"CooperBlueRockCandy"',
	'"BlueRockCandy"',
	'"Blue Rock Candy Pan"',
	"ChemistrySetupPlaced",
}) do
	has(bunkerServerSource, token, "Bunker server is missing " .. token)
end
check(
	not string.find(bunkerServerSource, '"FluidCapsule"', 1, true),
	"Bunker server must not rebuild the old free-floating FluidCapsule effect"
)
check(
	countPlain(bunkerServerSource, "resetChemistryExperimentVisuals(") >= 3,
	"Chemistry visuals must be reset at initialization and after every experiment"
)
has(bunkerServerSource, "vapor.Rate = 0", "Chemistry vapor must not emit continuously while the lab is idle")

-- Verify the candy Tool by stable attributes rather than by a local helper's
-- name. The product is a shallow metal pan containing loose blue crystals; it
-- must not regress to the former wood-stick prop or stack batches in an
-- invisible CandyCount value.
local candyToolSource = contextAround(
	bunkerServerSource,
	'"CooperBlueRockCandy"',
	2200,
	6200,
	"Blue Rock Candy Pan Tool"
)
has(candyToolSource, 'Instance.new("Tool")', "Blue Rock Candy Pan must be a real Roblox Tool")
hasAny(candyToolSource, {
	'Name = "Blue Rock Candy Pan"',
	"Name = candyDeliveryConfig.ProductToolName",
	"Name = candyDelivery.ProductToolName",
	"Name = Config.CandyDelivery.ProductToolName",
	"Config.CandyDelivery.ProductToolName",
}, "Candy Tool must use Config.CandyDelivery.ProductToolName")
has(candyToolSource, "RequiresHandle = true", "Candy pan must require a physical Handle")
has(candyToolSource, "CanBeDropped = false", "Candy pan must not create unmanaged Workspace duplicates")
has(candyToolSource, '"Handle"', "Candy pan must have an equippable Handle")
has(candyToolSource, "Anchored = false", "Candy pan Handle must be unanchored for equipping")
has(candyToolSource, "CanCollide = false", "Candy pan Handle must not collide with the player")
has(candyToolSource, '"ProductKind", "BlueRockCandy"', "Candy pan must retain the BlueRockCandy product marker")
has(candyToolSource, '"OwnerUserId"', "Candy pan must be owner-locked")
hasAny(candyToolSource, {
	"Enum.Material.Metal",
	"Enum.Material.DiamondPlate",
}, "Candy Tool must contain a physical metal pan")
hasAny(candyToolSource, {
	"CandyPan",
	"CandyTray",
	"MetalPan",
	"MetalTray",
	"Blue Rock Candy Pan",
}, "Candy Tool source does not describe a pan or tray")
check(not string.find(candyToolSource, "Enum.Material.Wood", 1, true), "Candy Tool still contains a wooden stick")
check(not string.find(candyToolSource, "CandyCount", 1, true), "Candy batches must not stack in one Tool")
check(not string.find(candyToolSource, "CandyStick", 1, true), "Candy Tool still constructs a stick")

has(bunkerServerSource, "Backpack", "Candy collection must place the physical pan in the player's Backpack")
has(bunkerServerSource, "Character", "Candy ownership checks must inspect equipped Tools")
has(bunkerServerSource, "chemistryRewardAvailable", "Reward presentation must guard the one outstanding pan")
has(bunkerServerSource, "chemistryRewardOwnerUserId", "Presented candy must be assigned to the experiment owner")
has(bunkerServerSource, '"Dispensing"', "Reward presentation must enter a dispensing animation state")
has(bunkerServerSource, '"Present"', "Reward presentation must finish in a collectible state")
has(bunkerServerSource, "TweenService:Create", "Chemistry output drawer must physically slide out")
has(bunkerServerSource, "candySmoke:Emit(", "Candy smoke must be a bounded completion burst")
has(bunkerServerSource, "chemistryRewardOwnerUserId ~= player.UserId", "Candy collection must validate its owner server-side")
has(bunkerServerSource, "isNear(player, candyCollectAnchor", "Candy collection must validate proximity server-side")
has(bunkerServerSource, "chemistryLab:SetAttribute(\"RewardAvailable\", false)", "Candy collection must atomically consume availability")
has(bunkerServerSource, "chemistryRewardHomeCFrame", "Reward reset must restore the candy display")
has(bunkerServerSource, "chemistryDrawerHomeCFrame", "Reward reset must retract the output drawer")
has(bunkerServerSource, "collectCandyPrompt.Enabled = false", "Reward reset must disable collection")
has(bunkerServerSource, "candySmoke:Clear()", "Reward reset must clear lingering smoke particles")
check(not string.find(bunkerServerSource, "CandyCount", 1, true), "Chemistry still stacks multiple batches in one inventory Tool")
check(not string.find(bunkerServerSource, "BlueRockCandyDisplayStick", 1, true), "World reward still includes the old candy stick")

check(
	countPlain(bunkerServerSource, "collectCandyPrompt.Triggered:Connect(function(player)") == 1,
	"Blue Rock Candy Pan must have exactly one server-authoritative collection handler"
)
check(
	countPlain(bunkerServerSource, 'setChemistryRewardState("Present", true') == 1,
	"A chemistry cycle must expose exactly one outstanding candy pan"
)
has(bunkerServerSource, "candySmoke.Rate = 0", "Candy smoke must never use continuous emission")
has(bunkerServerSource, "candySmoke.Enabled = false", "Candy smoke emitter must stay disabled between bounded bursts")
has(bunkerServerSource, "if chemistryRewardAvailable then", "New chemistry cycles must be blocked while candy awaits collection")
for _, marker in ipairs({
	"CandyBatchProduced",
	"local productionKey = string.format(",
	"productionKey = productionKey",
	"candyPresentation.readyToken",
	"candyPresentation.queuePlayer",
	"candyPresentation.release",
	"candyPresentation.pump",
	"leaseSeconds = 35",
	"retrySeconds = 12",
	"presentRadius = 30",
	"batchToken = presentedBatchToken",
	"RewardLeaseExpiresAt",
	"RewardQueueDepth",
}) do
	has(bunkerServerSource, marker, "Durable multiplayer output is missing " .. marker)
end
has(mainServerSource, "candyBatchReady", "Family persistence is missing finished-uncollected batch state")
has(mainServerSource, "candyBatchToken", "Family persistence is missing the durable ready-batch token")
has(mainServerSource, 'eventKey == "CandyBatchProduced"', "Reaction completion cannot create its durable batch through the server API")
for _, marker in ipairs({
	'TransactionRuntime.logicalOperationKind("CandyProduce", productionKey)',
	'TransactionRuntime.logicalOperationKind("CandyCollect", reportedToken)',
	'TransactionRuntime.logicalOperationKind("CandySale", reportedToken)',
}) do
	has(mainServerSource, marker, "Candy persistence is missing stable logical transition key " .. marker)
end
local candyProduceSource = section(
	mainServerSource,
	"local function createCandyBatch",
	"local function beginCandyDelivery",
	"Candy production transition"
)
local candyCollectSource = section(
	mainServerSource,
	"local function beginCandyDelivery",
	"local function completeCandyDelivery",
	"Candy collection transition"
)
local candySaleSource = section(
	mainServerSource,
	"local function completeCandyDelivery",
	"local hostWorldActionEvents",
	"Candy sale transition"
)
for label, transitionSource in pairs({
	["production"] = candyProduceSource,
	["collection"] = candyCollectSource,
	["sale"] = candySaleSource,
}) do
	check(
		countPlain(transitionSource, "TransactionRuntime.commitPersistentTransition(") == 1,
		"Candy " .. label .. " must use exactly one journaled persistent transition"
	)
	check(
		not string.find(transitionSource, "task.defer(saveProfile", 1, true),
		"Candy " .. label .. " must not rely on a deferred save after accepting the transition"
	)
end
has(candyProduceSource, "operationRecord.result.batchToken", "A repeated production callback must recover its original batch token")
has(candyCollectSource, "profile.data.candyBatchToken == reportedToken", "Collection does not require the exact durable ready token")
has(candySaleSource, "profile.data.candyDeliveryToken == reportedToken", "Sale does not require the exact active contract token")
has(candySaleSource, "if appliedNow then", "A duplicate candy-sale callback must not repeat payout presentation")
has(mainServerSource, "profile.data.candyDeliveryToken = reportedToken", "Collection must carry the same token into delivery")
has(
	bunkerServerSource,
	"chemistryRewardOwnerUserId == player.UserId",
	"Player cleanup must identify and reset candy assigned to a departing owner"
)

local updateStatusSource = section(
	bunkerServerSource,
	"local function updateStatus()",
	"local function setMainLightsState",
	"Bunker status refresh"
)
has(
	updateStatusSource,
	"not chemistryExperimentActive",
	"Do Chemistry prompt must stay disabled while an experiment is running"
)
local chemistryPromptSource = section(
	bunkerServerSource,
	"chemistryPrompt.Triggered:Connect(function(player)",
	"Players.PlayerAdded:Connect(watchChemistryOwnership)",
	"Do Chemistry prompt handler"
)
check(
	countPlain(chemistryPromptSource, "startChemistryExperiment(player)") == 1,
	"Do Chemistry prompt must start exactly one server-authoritative experiment"
)
check(
	not string.find(chemistryPromptSource, "Chemistry experiments are coming next", 1, true),
	"Do Chemistry prompt still uses the old notice-only placeholder"
)
local chemistryHeartbeatSource = section(
	bunkerServerSource,
	"RunService.Heartbeat:Connect(function(deltaTime)",
	"-- A fresh session always begins",
	"Bunker cosmetic heartbeat"
)
has(
	chemistryHeartbeatSource,
	"chemistryVisible and chemistryExperimentActive and not chemistryAssemblyActive",
	"Fluid, reactor, and pump motion must be gated by an active chemistry experiment"
)
check(
	not string.find(
		chemistryHeartbeatSource,
		"if chemistryVisible and not chemistryAssemblyActive then",
		1,
		true
	),
	"Legacy always-running chemistry animation gate is still present"
)
ordered(chemistryHeartbeatSource, {
	"visualState.accumulator += deltaTime",
	"if visualState.accumulator < 1 / 12 then",
	"return",
	"local step = visualState.accumulator",
	"visualState.accumulator = 0",
}, "Lab cosmetics must accumulate elapsed time and keep the mobile-safe 12 Hz replication cap")
has(mainClientSource, "TAKE CHEMISTRY CASE THROUGH BUNKER HATCH", "Outdoor chemistry guidance does not route through the hatch")
has(mainClientSource, "INSTALL ADVANCED CHEMISTRY LAB HERE", "Underground chemistry setup guidance is missing")
for _, token in ipairs({
	"COOPER LABNET",
	"Advanced Chemistry Setup",
	"narrowPortrait",
	"compactLayout",
	"RequestSnapshot",
	"OrderChemistrySetup",
	"CloseBunkerComputer",
	"ContextActionService",
	"BindActionAtPriority",
	"unbindTerminalMovementSink",
	"Enum.KeyCode.ButtonB",
}) do
	has(bunkerClientSource, token, "Bunker client is missing " .. token)
end
check(not string.find(bunkerClientSource, "ChemistrySetupPurchased", 1, true), "Bunker client must not duplicate global chemistry toasts")
check(not string.find(bunkerClientSource, "What Happens After Buying?", 1, true), "Bunker terminal still shows the distracting post-purchase card")
check(
	countPlain(bunkerClientSource, 'requestEvent:FireServer("CloseBunkerComputer")') == 1,
	"Bunker terminal must have one canonical server-close request"
)
check(
	not string.find(bunkerClientSource, '"Exit Computer",', 1, true),
	"Bunker terminal must not duplicate the top-right Exit control beneath the chemistry section"
)
local topExitSource = section(
	bunkerClientSource,
	"local closeButton = button(",
	"local statusPanel = Instance.new",
	"Bunker top-right Exit button"
)
has(topExitSource, '"Exit"', "Bunker top-right button must have a clear Exit label")
has(
	bunkerClientSource,
	"closeButton.Activated:Connect(function()",
	"Bunker top-right Exit button is not wired"
)
has(
	bunkerClientSource,
	"closeTerminal(true)",
	"Bunker top-right Exit button must use the canonical terminal close path"
)
local closeTerminalSource = section(
	bunkerClientSource,
	"closeTerminal = function(notifyServer)",
	"local function openTerminal()",
	"Bunker terminal close routine"
)
check(
	not string.find(closeTerminalSource, "if not terminalOpen then", 1, true),
	"Bunker close must remain idempotent so server close echoes can clear the UI"
)
has(
	closeTerminalSource,
	"unbindTerminalMovementSink()",
	"Every bunker terminal close must release its scoped movement sink"
)
check(
	not string.find(bunkerClientSource, "GetControls", 1, true)
		and not string.find(bunkerClientSource, "controls:Disable", 1, true)
		and not string.find(bunkerClientSource, "controls:Enable", 1, true),
	"Bunker terminal must never own or rebind the shared PlayerModule movement controls"
)
has(bunkerClientSource, "Enum.PlayerActions.CharacterForward", "Bunker terminal movement lock is missing forward movement")
has(bunkerClientSource, "Enum.PlayerActions.CharacterJump", "Bunker terminal movement lock is missing jump")
has(bunkerClientSource, "script.Destroying:Connect(unbindTerminalMovementSink)", "Bunker client destruction cannot leave movement bound")
has(bunkerClientSource, "UDim2.fromOffset(108, 44)", "Compact bunker Exit target is smaller than 44 pixels")
has(bunkerClientSource, "narrowPortrait and 108 or 112, 44", "Compact bunker Back target is smaller than 44 pixels")
has(bunkerClientSource, 'kind == "BunkerTerminalClose"', "Server feedback close route is missing")
has(bunkerClientSource, 'action == "TerminalClose"', "Bunker controller close route is missing")
check(
	countPlain(bunkerClientSource, "closeTerminal(false)") >= 3,
	"Server, controller, and character cleanup paths must all close the terminal UI"
)

if RunService:IsRunning() then
	local terminal = underground:FindFirstChild("BunkerResearchTerminal")
	local lab = bay:FindFirstChild("CooperAdvancedChemistryLab")
	check(terminal and terminal:IsA("Model"), "Runtime research terminal was not built")
	check(lab and lab:IsA("Model"), "Runtime chemistry laboratory was not built")
	check(terminal:FindFirstChild("BunkerTerminalInputAnchor", true) ~= nil, "Runtime terminal input anchor is missing")
	check(terminal:FindFirstChild("ResearchTerminalPrompt", true) ~= nil, "Runtime terminal prompt is missing")
	local chemistryPrompt = lab:FindFirstChild("DoChemistryPrompt", true)
	check(chemistryPrompt and chemistryPrompt:IsA("ProximityPrompt"), "Runtime Do Chemistry prompt is missing")
	local collectCandyPrompt = lab:FindFirstChild("CollectBlueRockCandyPrompt", true)
	check(collectCandyPrompt and collectCandyPrompt:IsA("ProximityPrompt"), "Runtime candy collection prompt is missing")

	local terminalParts, terminalScreens = 0, 0
	local labParts = 0
	local beams = 0
	local glassware = 0
	local tubeSegments = 0
	local tubeCylinders = 0
	local tubeFluids = 0
	local pipeSegments = 0
	local motionParts = {}
	local legacyCapsules = 0
	local testTubes = 0
	local namedEquipment = {}
	local particleEmitters = {}
	local fluidBeams = {}
	local outputDrawers = {}
	local candyRewards = {}
	local candyRewardParts = {}
	local candyPans = {}
	local candyWoodParts = {}
	local candyCrystalParts = {}
	local candySmokeEmitters = {}
	local requiredEquipmentNames = {
		"ErlenmeyerFlask",
		"RoundBottomFlask",
		"Beaker",
		"Condenser",
		"TestTubeRack",
	}
	for _, item in ipairs(terminal:GetDescendants()) do
		if item:IsA("BasePart") then terminalParts += 1 end
		if item:IsA("SurfaceGui") then terminalScreens += 1 end
	end
	for _, item in ipairs(lab:GetDescendants()) do
		for _, equipmentName in ipairs(requiredEquipmentNames) do
			if string.find(item.Name, equipmentName, 1, true) then
				namedEquipment[equipmentName] = true
			end
		end
		if string.find(item.Name, "TestTube", 1, true)
			and not string.find(item.Name, "Rack", 1, true)
			and item:IsA("BasePart")
		then
			testTubes += 1
		end
		if item:IsA("BasePart") then
			labParts += 1
			if item:GetAttribute("ChemistryOutputDrawer") == true then
				table.insert(outputDrawers, item)
			end
			local isCandyRewardPart = item:GetAttribute("ChemistryCandyReward") == true
				or item:GetAttribute("ChemistryCandyRewardDetail") == true
				or item:GetAttribute("ChemistryCandyPan") == true
				or item:GetAttribute("ChemistryCandyRewardPan") == true
			if item:GetAttribute("ChemistryCandyReward") == true then
				table.insert(candyRewards, item)
			end
			if isCandyRewardPart then
				table.insert(candyRewardParts, item)
				local lowerName = string.lower(item.Name)
				if item:GetAttribute("ChemistryCandyPan") == true
					or item:GetAttribute("ChemistryCandyRewardPan") == true
					or string.find(lowerName, "pan", 1, true)
					or string.find(lowerName, "tray", 1, true)
				then
					table.insert(candyPans, item)
				end
				if item.Material == Enum.Material.Wood or item.Material == Enum.Material.WoodPlanks then
					table.insert(candyWoodParts, item)
				end
				if item.Color.B > item.Color.R + 0.12
					and item.Color.B >= item.Color.G - 0.08
				then
					table.insert(candyCrystalParts, item)
				end
			end
			if item.Name == "FluidCapsule" then legacyCapsules += 1 end
			if item:GetAttribute("ChemistryGlassware") == true then
				glassware += 1
				check(item.Anchored, item.Name .. " glassware must remain anchored")
				check(not item.CanCollide, item.Name .. " glassware must not snag the player")
				check(item.Material == Enum.Material.Glass, item.Name .. " must use physical glass material")
				local visibleTransparency = tonumber(item:GetAttribute("VisibleTransparency")) or item.Transparency
				check(
					visibleTransparency > 0 and visibleTransparency < 0.9,
					item.Name .. " glass must remain visibly translucent when installed"
				)
			end
			if item:GetAttribute("ChemistryTubeSegment") == true then
				tubeSegments += 1
				if item.Shape == Enum.PartType.Cylinder then tubeCylinders += 1 end
				check(item.Anchored and not item.CanCollide, item.Name .. " tube segment must be anchored and noncolliding")
				local tubeTransparency = tonumber(item:GetAttribute("VisibleTransparency")) or item.Transparency
				check(
					(item.Material == Enum.Material.Glass or item.Material == Enum.Material.SmoothPlastic)
						and tubeTransparency >= 0.4
						and tubeTransparency < 0.85,
					item.Name .. " tube segment must use a visibly translucent glass-compatible shell"
				)
				check(math.abs(item.Size.Y - item.Size.Z) <= 0.08, item.Name .. " tube diameter must be round")
			end
			if item:GetAttribute("ChemistryTubeFluid") == true then
				tubeFluids += 1
				check(item.Anchored and not item.CanCollide, item.Name .. " contained fluid must be anchored and noncolliding")
			end
			if item:GetAttribute("ChemistryPipeSegment") == true then
				pipeSegments += 1
				check(item.Anchored and not item.CanCollide, item.Name .. " pipe segment must be anchored and noncolliding")
			end
			if item:GetAttribute("ChemistryMotionPart") == true then
				table.insert(motionParts, item)
			end
		elseif item:IsA("Beam") then
			beams += 1
			if item:GetAttribute("ChemistryTubeFluid") == true
				or string.find(item.Name, "Fluid", 1, true)
			then
				table.insert(fluidBeams, item)
			end
		elseif item:IsA("ParticleEmitter") then
			table.insert(particleEmitters, item)
			if item.Name == "CandySmoke" then
				table.insert(candySmokeEmitters, item)
			end
		end
	end
	check(terminalParts >= 40, "Runtime terminal is missing physical detail")
	check(terminalScreens == 3, "Runtime terminal must have three readable displays")
	check(labParts >= 85, "Runtime chemistry lab is missing recognizable physical detail")
	for _, equipmentName in ipairs(requiredEquipmentNames) do
		check(namedEquipment[equipmentName] == true, "Runtime chemistry lab is missing " .. equipmentName)
	end
	check(testTubes >= 6, "Runtime chemistry lab must have at least six physical test tubes")
	check(glassware >= 5, "Runtime chemistry lab needs multiple recognizable glass vessels")
	check(tubeSegments >= 18, "Runtime chemistry lab needs a substantial physical glass-tube network")
	check(tubeCylinders == tubeSegments, "Every tagged chemistry tube segment must be a physical cylinder")
	check(tubeFluids >= 12, "Runtime chemistry lab needs visible fluid contained inside its tubes")
	check(pipeSegments >= 8, "Runtime chemistry lab needs a recognizable rigid plumbing network")
	check(#motionParts >= 6, "Runtime chemistry lab is missing tagged experiment motion components")
	check(legacyCapsules == 0, "Runtime chemistry lab still contains free-floating FluidCapsule particles")
	check(tubeSegments > beams, "Physical tube geometry must dominate any supplemental Beam effects")
	check(#outputDrawers == 1, "Runtime lab must reuse exactly one physical chemistry output drawer")
	check(#candyRewards == 1, "Runtime lab must expose exactly one primary Blue Rock Candy Pan reward")
	check(#candyRewardParts >= 4, "Runtime candy batch is missing its metal pan or loose crystal pieces")
	check(#candyPans >= 1, "Runtime candy output must sit inside a recognizable metal pan")
	check(#candyWoodParts == 0, "Runtime candy output still contains the old wooden stick")
	check(#candyCrystalParts >= 2, "Runtime pan needs multiple clearly blue rock-candy pieces")
	check(#candySmokeEmitters == 1, "Runtime lab must have exactly one contained CandySmoke emitter")

	local outputDrawer = outputDrawers[1]
	local candyReward = candyRewards[1]
	local candyPan = candyPans[1]
	local candySmoke = candySmokeEmitters[1]
	check(outputDrawer.Anchored, "Chemistry output drawer must remain anchored during tweened motion")
	check(not outputDrawer.CanCollide, "Chemistry output drawer must not obstruct the player")
	check(outputDrawer:GetAttribute("ChemistryMotionPart") == true, "Output drawer must participate in idle-motion auditing")
	check(candyReward.Anchored, "World Blue Rock Candy Pan must remain server-positioned until collection")
	check(not candyReward.CanCollide, "World Blue Rock Candy Pan must not collide with the player or apparatus")
	check(candyPan.Anchored, "World candy pan must remain anchored while the drawer presents it")
	check(not candyPan.CanCollide, "World candy pan must not obstruct the player or apparatus")
	check(
		candyPan.Material == Enum.Material.Metal or candyPan.Material == Enum.Material.DiamondPlate,
		"Chemistry output pan must use a metal material"
	)
	check(
		candyPan.Size.Y < candyPan.Size.X and candyPan.Size.Y < candyPan.Size.Z,
		"Chemistry output pan must read as a wide, shallow metal vessel"
	)
	if lab:GetAttribute("RewardAvailable") == true then
		local verticalCenterDistance = (candyPan.Position - outputDrawer.Position):Dot(outputDrawer.CFrame.UpVector)
		local drawerToPanGap = verticalCenterDistance - outputDrawer.Size.Y * 0.5 - candyPan.Size.Y * 0.5
		check(drawerToPanGap >= -0.03, "Presented candy pan intersects the metal output drawer")
		check(drawerToPanGap <= 0.12, "Presented candy pan is floating above the metal output drawer")
	end
	check(candySmoke.Rate == 0, "CandySmoke must use Emit bursts, never a continuous Rate")
	check(not candySmoke.Enabled, "CandySmoke must remain disabled outside explicit Emit bursts")
	check(candySmoke.Lifetime.Max <= 2.6, "Candy smoke lifetime is too long and would fill the bunker")
	check(candySmoke.Speed.Max <= 3.2, "Candy smoke speed is too high to remain near the drawer")
	check(
		math.abs(candySmoke.SpreadAngle.X) <= 40 and math.abs(candySmoke.SpreadAngle.Y) <= 40,
		"Candy smoke spread must remain visually contained around the output drawer"
	)
	local smokeParent = candySmoke.Parent
	check(smokeParent and smokeParent:IsA("BasePart"), "CandySmoke must emit from a physical drawer nozzle")
	check((smokeParent.Position - outputDrawer.Position).Magnitude <= 4, "CandySmoke emitter is not contained near the drawer")

	local rewardState = lab:GetAttribute("RewardState")
	local rewardAvailable = lab:GetAttribute("RewardAvailable")
	local rewardOwnerUserId = lab:GetAttribute("RewardOwnerUserId")
	local rewardLeaseExpiresAt = lab:GetAttribute("RewardLeaseExpiresAt")
	local rewardQueueDepth = lab:GetAttribute("RewardQueueDepth")
	check(
		rewardState == "Empty" or rewardState == "Dispensing" or rewardState == "Present",
		"Runtime chemistry lab has an invalid RewardState"
	)
	check(type(rewardAvailable) == "boolean", "Runtime chemistry lab is missing RewardAvailable")
	check(type(rewardOwnerUserId) == "number", "Runtime chemistry lab is missing RewardOwnerUserId")
	check(type(rewardLeaseExpiresAt) == "number" and rewardLeaseExpiresAt >= 0, "Runtime chemistry lab has an invalid tray lease")
	check(type(rewardQueueDepth) == "number" and rewardQueueDepth >= 0 and rewardQueueDepth % 1 == 0, "Runtime chemistry queue depth is invalid")
	check((rewardState == "Present") == rewardAvailable, "Reward state and availability flag disagree")
	check(collectCandyPrompt.Enabled == rewardAvailable, "Candy prompt availability does not match reward state")
	if rewardState == "Empty" then
		check(rewardOwnerUserId == 0, "Empty chemistry output retained a stale reward owner")
		check(rewardLeaseExpiresAt == 0, "Empty chemistry output retained a stale lease")
		for _, rewardPart in ipairs(candyRewardParts) do
			check(rewardPart.Transparency >= 0.99, rewardPart.Name .. " must be hidden before a cycle completes")
		end
	elseif rewardState == "Dispensing" then
		check(rewardOwnerUserId > 0, "Dispensing chemistry output is missing its owner")
		check(not collectCandyPrompt.Enabled, "Candy cannot be collected until the drawer finishes extending")
	else
		check(rewardOwnerUserId > 0, "Available Blue Rock Candy Pan is missing its owner")
		check(rewardLeaseExpiresAt > Workspace:GetServerTimeNow(), "Available chemistry output has an expired lease")
		check(rewardLeaseExpiresAt <= Workspace:GetServerTimeNow() + 36, "Chemistry output lease can block the shared lab for too long")
		check(candyPan.Transparency < 0.9, "Available metal candy pan is not visibly presented")
		local visibleBluePieces = 0
		for _, crystal in ipairs(candyCrystalParts) do
			if crystal.Transparency < 0.9 then visibleBluePieces += 1 end
		end
		check(visibleBluePieces >= 2, "Available pan does not visibly contain blue rock candy")
		local rewardOwner = Players:GetPlayerByUserId(rewardOwnerUserId)
		check(rewardOwner ~= nil, "Available candy belongs to a player who left")
		check(rewardOwner:GetAttribute("CooperCandyBatchReady") == true, "Presented tray owner has no durable ready batch")
	end

	for _, player in ipairs(Players:GetPlayers()) do
		check(
			not (player:GetAttribute("CooperCandyBatchReady") == true and player:GetAttribute("CooperCandyDeliveryActive") == true),
			player.Name .. " cannot own a ready output and active buyer contract simultaneously"
		)
		local candyTools = {}
		for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
			if container then
				for _, item in ipairs(container:GetChildren()) do
					if item:IsA("Tool") and item.Name == candyDelivery.ProductToolName then
						table.insert(candyTools, item)
					end
				end
			end
		end
		check(#candyTools <= 1, player.Name .. " has duplicate Blue Rock Candy Pan Tools")
		for _, candyTool in ipairs(candyTools) do
			local handle = candyTool:FindFirstChild("Handle")
			check(candyTool.RequiresHandle, "Blue Rock Candy Pan must require its Handle")
			check(not candyTool.CanBeDropped, "Blue Rock Candy Pan must not be droppable into unmanaged Workspace state")
			check(candyTool:GetAttribute("CooperBlueRockCandy") == true, "Candy pan lost its authoritative product marker")
			check(candyTool:GetAttribute("ProductKind") == "BlueRockCandy", "Candy pan has the wrong product kind")
			check(candyTool:GetAttribute("OwnerUserId") == player.UserId, "Candy pan is not locked to its owner")
			check(candyTool:GetAttribute("CandyCount") == nil, "Candy batches must not stack in a CandyCount attribute")
			check(handle and handle:IsA("BasePart"), "Blue Rock Candy Pan is missing its physical Handle")
			check(not handle.Anchored, "Equipped Blue Rock Candy Pan Handle must be unanchored")
			check(not handle.CanCollide, "Equipped Blue Rock Candy Pan Handle must not collide")
			check(not handle.CanTouch, "Equipped Blue Rock Candy Pan Handle must not trigger unrelated touch gameplay")
			check(handle.Massless, "Equipped Blue Rock Candy Pan Handle must not affect player movement")
			check(
				handle.Material == Enum.Material.Metal or handle.Material == Enum.Material.DiamondPlate,
				"Candy Tool Handle must be the physical metal pan"
			)
			check(
				handle.Size.Y < handle.Size.X and handle.Size.Y < handle.Size.Z,
				"Carried candy pan must be wide and shallow"
			)
			local toolBluePieces = 0
			for _, part in ipairs(candyTool:GetDescendants()) do
				if part:IsA("BasePart") then
					check(
						part.Material ~= Enum.Material.Wood and part.Material ~= Enum.Material.WoodPlanks,
						part.Name .. " reintroduced a wooden candy stick"
					)
					if part.Color.B > part.Color.R + 0.12 and part.Color.B >= part.Color.G - 0.08 then
						toolBluePieces += 1
					end
				end
			end
			check(toolBluePieces >= 2, "Carried pan must visibly contain multiple blue rock-candy pieces")
		end
	end

	local experimentState = lab:GetAttribute("ExperimentState")
	local experimentActive = lab:GetAttribute("ExperimentActive")
	check(experimentState == "Idle" or experimentState == "Running", "Runtime chemistry lab has an invalid ExperimentState")
	check(type(experimentActive) == "boolean", "Runtime chemistry lab is missing its ExperimentActive boolean")
	check((experimentState == "Running") == experimentActive, "Runtime chemistry state and active flag disagree")
	if experimentActive then
		check(not chemistryPrompt.Enabled, "Do Chemistry prompt must be disabled during an active experiment")
	else
		for _, emitter in ipairs(particleEmitters) do
			check(emitter.Rate == 0, emitter.Name .. " must have zero continuous emission while idle")
			check(not emitter.Enabled, emitter.Name .. " must be disabled while idle")
		end
		for _, beam in ipairs(fluidBeams) do
			check(math.abs(beam.TextureSpeed) < 0.001, beam.Name .. " fluid texture must be stopped while idle")
			check(not beam.Enabled, beam.Name .. " contained flow must be hidden while idle")
		end

		-- Observe rather than trigger the apparatus: a verifier must never change
		-- progression or begin an experiment in the player's live session.
		if lab:GetAttribute("SetupAnimating") ~= true and rewardState ~= "Dispensing" then
			local idleSnapshot = {}
			for _, part in ipairs(motionParts) do
				idleSnapshot[part] = {
					cframe = part.CFrame,
					size = part.Size,
					color = part.Color,
					transparency = part.Transparency,
				}
			end
			task.wait(0.8)
			for part, before in pairs(idleSnapshot) do
				if part.Parent then
					local relative = before.cframe:ToObjectSpace(part.CFrame)
					local _, angle = relative:ToAxisAngle()
					local colorDelta = math.abs(part.Color.R - before.color.R)
						+ math.abs(part.Color.G - before.color.G)
						+ math.abs(part.Color.B - before.color.B)
					check(relative.Position.Magnitude < 0.001, part.Name .. " moved while chemistry was idle")
					check(math.abs(angle) < 0.001, part.Name .. " rotated while chemistry was idle")
					check((part.Size - before.size).Magnitude < 0.001, part.Name .. " changed size while chemistry was idle")
					check(colorDelta < 0.001, part.Name .. " changed color while chemistry was idle")
					check(
						math.abs(part.Transparency - before.transparency) < 0.001,
						part.Name .. " pulsed while chemistry was idle"
					)
				end
			end
		end
	end
end

print(string.format("[BunkerChemistryAudit] PASS: %d checks", checks))
