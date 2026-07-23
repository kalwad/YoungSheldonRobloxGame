--!strict
-- Personal, persistent task/economy definitions for the Cooper family loop.
-- Installed as ReplicatedStorage.CooperGame.Config.

local Config = {}

Config.SchemaVersion = 12
Config.DataStoreName = "CooperFamilyTasks_v2"
Config.DataStoreKeyPrefix = "player_"
Config.AutoSaveSeconds = 75
Config.RequestCooldown = 0.18
Config.WorldRootName = "CooperFamilyTaskWorld"
Config.ServerEventsName = "CooperGameServerEvents"
-- Mirrored by the Creator Dashboard place setting. Milestone 1 makes the
-- house authoritative to one private party of at most four players.
Config.ReleasePlayerCap = 4

export type FeatureFlags = {
	Lobby: boolean,
	Horror: boolean,
	SecretExploration: boolean,
	TimeMachineFinale: boolean,
	Postgame: boolean,
	StudioScenarioTools: boolean,
}

-- Milestone 1 enables only the private-party lobby/co-op foundation. Horror,
-- secret exploration, the finale, postgame, and scenario grants stay inert.
Config.Features = table.freeze({
	Lobby = true,
	Horror = false,
	SecretExploration = false,
	TimeMachineFinale = false,
	Postgame = false,
	StudioScenarioTools = false,
}) :: FeatureFlags

-- Ephemeral party/session state never belongs in a persistent player profile.
-- The lobby keeps access codes and authoritative tickets server-side; the
-- destination accepts only a short-lived, one-use ticket from this universe.
Config.Party = table.freeze({
	ProtocolVersion = 1,
	MaxMembers = 4,
	HostReconnectGraceSeconds = 60,
	GuestReconnectGraceSeconds = 90,
	InviteLifetimeSeconds = 300,
	LaunchTicketLifetimeSeconds = 180,
	SessionLifetimeSeconds = 3600,
	SessionHeartbeatSeconds = 120,
	-- The existing start place is the public lobby. The verified house clone is
	-- the only reserved gameplay destination for Milestone 1 parties.
	LobbyPlaceId = 100748614383412,
	HousePlaceId = 98645411943406,
	TicketMapName = "CooperPartyLaunchTickets_v1",
	SessionMapName = "CooperPartySessions_v1",
	RejoinMapName = "CooperPartyRejoin_v1",
	HostOnlyPersistentPurchases = true,
})

Config.Movement = table.freeze({
	WalkSpeed = 16,
	SprintSpeed = 22,
	SprintStaminaSeconds = 6,
	SprintRegenDelaySeconds = 0.8,
	SprintRegenPerSecond = 1.5,
	IntentRateLimitSeconds = 0.08,
})

Config.TaskDirector = {
	InitialDelay = 5,
	MinimumDelay = 7,
	MaximumDelay = 13,
	-- Once an installed robot accepts a chore, the next playable request can
	-- arrive while that robot continues its full physical animation.
	AutomatedNextDelay = 3,
	RecentTaskMemory = 2,
}

export type TaskDefinition = {
	id: string,
	title: string,
	requester: string,
	reward: number,
	guidance: boolean,
	startDescription: string,
	startTarget: string?,
}

Config.Tasks = {
	{
		id = "GeorgeBeer",
		title = "ORDER GEORGE'S BEER",
		requester = "George",
		reward = 55,
		guidance = true,
		startDescription = "Use Sheldon's computer and open the Beer Store.",
		startTarget = "Keyboard",
	},
	{
		id = "MaryDishes",
		title = "WASH THE DISHES",
		requester = "Mary",
		reward = 30,
		guidance = true,
		startDescription = "Wash the dirty dishes at the kitchen sink.",
		startTarget = "DishesPromptAnchor",
	},
	{
		id = "MaryTrash",
		title = "TAKE OUT THE TRASH",
		requester = "Mary",
		reward = 40,
		guidance = true,
		startDescription = "Pick up the kitchen trash bag, then take it to the garage-side outdoor can.",
		startTarget = "TrashPickupAnchor",
	},
	{
		id = "MissyPlush",
		title = "FIND MISSY'S LOST TOY",
		requester = "Missy",
		reward = 70,
		guidance = true,
		startDescription = "One of Missy's stuffed animals is hidden inside the house. Follow the glowing arrow.",
	},
	{
		id = "MedfordBankHack",
		title = "HACK THE MEDFORD BANK",
		requester = "Terminal",
		reward = 90,
		guidance = true,
		startDescription = "Use Sheldon's computer and choose HACK MEDFORD BANK.",
		startTarget = "Keyboard",
	},
} :: { TaskDefinition }

Config.TaskOrder = {
	"GeorgeBeer",
	"MaryDishes",
	"MaryTrash",
	"MissyPlush",
	"MedfordBankHack",
}

-- Permanent task upgrades are bought with allowance at Sheldon's computer,
-- delivered by the truck, and installed at a purpose-built spot in the house.
-- Once installed, the matching chore still enters the five-task rotation, but
-- the server runs that chore automatically and awards its ordinary reward.
-- Every main-house task has a paid automation option. The Medford Bank memory
-- game remains available manually until HackerBot is purchased and installed.
export type TaskAutomationUpgradeDefinition = {
	id: string,
	taskId: string,
	name: string,
	price: number,
	duration: number,
	installTarget: string,
	modelName: string,
	description: string,
}

Config.TaskAutomationUpgrades = {
	{
		id = "BeerBot",
		taskId = "GeorgeBeer",
		name = "BeerBot",
		price = 750,
		duration = 60,
		installTarget = "BeerBotInstallAnchor",
		modelName = "BeerBot",
		description = "Automatically orders, collects, and refrigerates George's beer.",
	},
	{
		id = "DishBot",
		taskId = "MaryDishes",
		name = "DishBot",
		price = 900,
		duration = 10,
		installTarget = "DishBotInstallAnchor",
		modelName = "DishBot",
		description = "Automatically washes every batch of dirty dishes in the kitchen sink.",
	},
	{
		id = "TrashBot",
		taskId = "MaryTrash",
		name = "TrashBot",
		price = 1100,
		duration = 60,
		installTarget = "TrashBotInstallAnchor",
		modelName = "TrashBot",
		description = "Automatically carries kitchen trash to the outdoor garage-side can.",
	},
	{
		id = "ToyFinder",
		taskId = "MissyPlush",
		name = "Toy Finder",
		price = 1350,
		duration = 36,
		installTarget = "ToyFinderInstallAnchor",
		modelName = "ToyFinder",
		description = "Automatically finds Missy's lost stuffed animal and returns it to her bed.",
	},
	{
		id = "HackerBot",
		taskId = "MedfordBankHack",
		name = "HackerBot",
		price = 1750,
		duration = 24,
		installTarget = "HackerBotInstallAnchor",
		modelName = "HackerBot",
		description = "Automatically cracks each Medford Bank keyboard sequence and earns its scaling payout.",
	},
} :: { TaskAutomationUpgradeDefinition }

-- Each hiding place is resolved from a real furniture bounding box when the
-- task world is installed. This keeps the plush tucked beside furniture even
-- if the whole house is moved or rebuilt at a different world origin.
Config.HiddenLocations = {
	{
		name = "MissyVanityCorner",
		anchorName = "MissyVanity",
		localOffset = Vector3.new(-1.25, 0, 0.82),
		yaw = -20,
	},
	{
		name = "DenBookcaseCorner",
		anchorName = "WhiteDenBuiltInBookcase",
		localOffset = Vector3.new(1.28, 0, 0.9),
		yaw = 25,
	},
	{
		name = "DiningHutchCorner",
		anchorName = "DiningChinaHutch",
		-- Sit beyond both the west edge of the displayed plates and the north
		-- edge of the shelves. The former corner put a rotated full-size plush
		-- inside shelf three's footprint during Toy Finder extraction.
		localOffset = Vector3.new(-2.35, 0, 3.15),
		yaw = 70,
	},
	{
		name = "ParentsDresserCorner",
		anchorName = "ParentsOliveWideDresser",
		-- Keep enough room for the full plush and ToyFinder claw. The former
		-- east/rear corner was a 0.05-stud slot between the dresser, bed, and wall,
		-- so no correctly sized toy could ever leave it without clipping.
		localOffset = Vector3.new(0, 0, -1.90),
		yaw = -35,
	},
	{
		name = "GeorgieDresserCorner",
		anchorName = "GeorgieLowDresser",
		localOffset = Vector3.new(-1.18, 0, 1.82),
		yaw = 15,
	},
	{
		name = "SofaEndTableHideaway",
		anchorName = "FormalSofaEndTable",
		localOffset = Vector3.new(0, 0, 0.15),
		yaw = 40,
	},
	{
		name = "DenTelevisionCorner",
		anchorName = "WoodCabinetCRTTelevision",
		localOffset = Vector3.new(-2.82, 0, 1.2),
		yaw = -25,
	},
}

export type MachineStageDefinition = {
	stage: number,
	name: string,
	progress: number,
	cost: number,
}

Config.MachineStages = {
	{ stage = 1, name = "Blueprint Bench", progress = 5, cost = 100 },
	{ stage = 2, name = "Clock Core", progress = 12, cost = 125 },
	{ stage = 3, name = "Power Router", progress = 22, cost = 175 },
	{ stage = 4, name = "Logic Terminal Array", progress = 32, cost = 225 },
	{ stage = 5, name = "Temporal Frame", progress = 44, cost = 300 },
	{ stage = 6, name = "Navigation Unit", progress = 55, cost = 350 },
	{ stage = 7, name = "Garage Reactor", progress = 67, cost = 400 },
	{ stage = 8, name = "Chrono-Core", progress = 78, cost = 475 },
	{ stage = 9, name = "Weather Stabilizer", progress = 88, cost = 550 },
	{ stage = 10, name = "Passenger Capsule", progress = 96, cost = 625 },
	{ stage = 11, name = "Final Calibration", progress = 100, cost = 695 },
} :: { MachineStageDefinition }

-- One permanent side-income purchase, paid for with task allowance and
-- delivered through the same owner-locked truck queue as machine components.
-- The runtime Sound uses the Creator Dashboard asset; the attached local MP3
-- is only a source/reference file and is not addressable by a Roblox client.
Config.Boombox = {
	Price = 350,
	AutoplayUpgradePrice = 1250,
	ModelName = "CooperIncomeBoombox",
	AudioId = "rbxassetid://86759598635831",
	TrackDuration = 22.465306,
	DanceBPM = 130,
	DanceBeatOffsetSeconds = 0.16,
	DanceJumpHeight = 1.05,
	PayoutPerTick = 30,
	MaximumPaidTicks = 10,
	PayoutInterval = 22.465306 / 10,
	CooldownSeconds = 120,
	PreloadTimeoutSeconds = 8,
}

-- The bunker is a permanent, personal phase unlock. Construction is driven by
-- a durable Unix deadline so an interrupted server can resume the spectacle or
-- reveal the finished entrance without ever charging the player twice.
Config.SecretBunker = {
	Id = "secretbunker.underground",
	Name = "Secret Underground Bunker",
	Price = 2500,
	ConstructionSeconds = 45,
}

-- The first bunker-phase purchase. It is ordered only from the research
-- terminal underground, delivered by the existing owner-locked truck, and
-- installed on the reserved chemistry bay equipment pad. The interaction is
-- future-ready: the physical lab now runs a complete reaction and produces a
-- collectible blue rock-candy Tool; recipes and candy sales arrive later.
Config.ChemistrySetup = {
	Id = "chemistry.setup",
	Name = "Advanced Chemistry Setup",
	Price = 1800,
	ModelName = "CooperAdvancedChemistryLab",
	InstallTarget = "ChemistrySetAnchor",
	Description = "A high-tech physical chemistry bench with glassware, pumps, valves, connected tubing, and an interactive reactor that makes collectible Blue Rock Candy.",
}

-- The first bunker production contract. A completed chemistry batch is carried
-- in a real metal pan, then sold through an owner-locked yellow buyer truck.
-- Payout is deliberately phase-two money: it exceeds every chore, every bank
-- cycle, and the complete party-boombox session by a wide margin.
Config.CandyDelivery = {
	Id = "blue_rock_candy.delivery",
	Name = "Deliver Blue Rock Candy",
	ProductToolName = "Blue Rock Candy Pan",
	Payout = 3000,
	LogoName = "Los_Pollos_Hermanos_logo",
	-- 74538933380880 is the Creator Dashboard Decal item. Roblox resolves that
	-- item to image content 115114653936657; Decal.Texture must use the resolved
	-- image ID or the logo can render as a blank panel in playtests.
	LogoCatalogAssetId = "rbxassetid://74538933380880",
	LogoAssetId = "rbxassetid://115114653936657",
	TruckModelName = "LosPollosBuyerTruck",
	DropPromptName = "LosPollosCandyDropPrompt",
}

-- Server-authoritative Simon-style keyboard challenge. A successful bank task
-- advances the persistent cycle, making the next appearance faster and more
-- valuable while retaining hard playability and economy caps.
Config.BankHack = {
	Keys = { "Q", "W", "E", "R", "A", "S", "D", "F", "Z", "X", "C", "V" },
	RoundCount = 4,
	StartingLength = 2,
	BasePreviewStepSeconds = 0.78,
	-- Each successful bank cycle now changes enough to be obvious on the next
	-- visit while the floor keeps late-game rounds humanly playable.
	SpeedupPerSuccess = 0.06,
	MinimumPreviewStepSeconds = 0.32,
	StartingLengthIncreaseEverySuccesses = 2,
	MaximumStartingLength = 4,
	BaseReward = 90,
	RewardPerSuccess = 20,
	MaximumReward = 300,
	CueLightRatio = 0.62,
	LeadInSeconds = 0.65,
	RoundPauseSeconds = 0.75,
	RetryCooldownSeconds = 1.25,
	InputWindowBaseSeconds = 3.5,
	InputWindowPerKeySeconds = 0.9,
	InputRateLimitSeconds = 0.04,
}

Config.ProfileDefaults = {
	schemaVersion = Config.SchemaVersion,
	-- Schema 12 adds a bounded, server-owned exactly-once journal. Runtime
	-- sanitization rebuilds this table through CooperGame.TransactionLedger so
	-- malformed records and client-shaped values never enter a save payload.
	operationJournal = {
		version = 1,
		pending = {},
		committed = {},
	},
	allowance = 0,
	machineStage = 0,
	pendingPartStage = 0,
	tutorialSeen = false,
	totalTasks = 0,
	cycleIndex = 1,
	cycleTaskIndex = 1,
	postRevealCyclesCompleted = 0,
	firstHorrorRevealed = false,
	horrorEncountersSurvived = 0,
	horrorEncountersCaught = 0,
	horrorCurrentStreak = 0,
	horrorLongestStreak = 0,
	backroomsDiscovered = false,
	domeDiscovered = false,
	endingCompleted = false,
	endingChoice = "",
	postgameUnlocked = false,
	boomboxPurchased = false,
	boomboxPlaced = false,
	boomboxNextPlayAt = 0,
	boomboxAutoplayPurchased = false,
	-- A completed song can finish while an earlier indexed beat payment is still
	-- reconciling. Runtime stores the remaining full-song settlement contract
	-- here so leave/shutdown recovery cannot silently turn a $300 session into a
	-- partial payout. `false` is the canonical empty state.
	boomboxPendingSettlement = false,
	taskAutomationInstalled = {},
	pendingTaskUpgradeId = "",
	bankHackSuccesses = 0,
	secretBunkerPurchased = false,
	secretBunkerReadyAt = 0,
	chemistrySetupPurchased = false,
	chemistrySetupPlaced = false,
	-- A finished-but-uncollected chemistry batch is separate from the later
	-- buyer-truck delivery contract. Both fields are persisted so the output can
	-- be reconstructed after a leave, server shutdown, or another player's turn.
	candyBatchReady = false,
	candyBatchToken = "",
	candyDeliveryActive = false,
	candyDeliveryToken = "",
	candyBatchesSold = 0,
}

return table.freeze(Config)
