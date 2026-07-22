--!strict
-- Immutable definitions for the Cooper Time Machine progression layer.
-- Install as ReplicatedStorage.CooperProgression.Config.

local Config = {}

Config.SchemaVersion = 2
Config.InstallVersion = "2026-07-13.family.1"
Config.RootName = "CooperProgression"
Config.StateName = "State"
Config.RemotesName = "Remotes"
Config.ServerEventsName = "CooperProgressionServerEvents"
Config.FoundationEventsName = "CooperGameServerEvents"
-- This store owns only advanced progression data (upgrades, reactor state, and
-- victory history). CooperFamilyTasks_v2 remains the sole owner of allowance,
-- pending deliveries, and each player's installed machine stage.
Config.DataStoreName = "CooperProgressionExtensions_v2"
Config.DataStoreKeyPrefix = "player_"
Config.AutoSaveSeconds = 90
Config.RequestCooldown = 0.18
Config.InteractionDistance = 16

Config.FoundationOperations = {
	GetSnapshot = "GetSnapshot",
	AdjustCurrency = "AdjustCurrency",
	SpendAllowance = "SpendAllowance",
	OrderMachinePart = "OrderMachinePart",
	SetMode = "SetMode",
	SetChapter = "SetChapter",
	AdjustStability = "AdjustStability",
}

-- Integration contract with CooperFamilyTaskGame.server.luau. Operations in
-- `requiredNow` already exist in the Family foundation. The optional additions
-- let the Family computer use one exact atomic ordering path and let advanced
-- systems publish campaign state. Progression consoles never order directly;
-- they point players back to Sheldon's computer.
Config.FoundationAPIContract = {
	requiredNow = {
		"GetSnapshot(player) -> snapshot",
		"AdjustCurrency(player, delta) -> success, reason?",
		"SetMode(mode, reason?) -> success, mode?",
	},
	additions = {
		"SpendAllowance(player, positiveAmount, reason) -> success, newBalanceOrReason",
		"OrderMachinePart(player, expectedStage) -> success, reason; atomically validates positive Config.MachineStages cost, debits allowance, records pendingPartStage, and queues delivery",
		"SetChapter(chapter, chapterName, reason?) -> success, chapter",
	},
}

Config.Ownership = {
	allowance = "CooperGame",
	pendingPartStage = "CooperGame",
	machineStage = "CooperGame",
	upgrades = "CooperProgression",
	reactor = "CooperProgression",
	victory = "CooperProgression",
}

Config.ProgressionAPIContract = {
	CanOrderMachinePart = "CanOrderMachinePart(player, expectedStage) -> allowed, reason?",
}

export type StageDefinition = {
	stage: number,
	name: string,
	progress: number,
	focus: string,
	cost: number,
	requirement: string?,
}

-- These names and progress milestones intentionally mirror CooperGame.Config.
-- Costs are balanced around the starter task pool. Every ordered component costs
-- earned currency so the chore economy matters from the first build.
Config.MachineStages = {
	{ stage = 1, name = "Blueprint Bench", progress = 5, focus = "Tutorial / unlock garage project", cost = 100 },
	{ stage = 2, name = "Clock Core", progress = 12, focus = "Time tracking / timer tasks", cost = 125 },
	{ stage = 3, name = "Power Router", progress = 22, focus = "House power tasks", cost = 175 },
	{ stage = 4, name = "Logic Terminal Array", progress = 32, focus = "DOS / TV / puzzle tasks", cost = 225 },
	{ stage = 5, name = "Temporal Frame", progress = 44, focus = "Heavy delivery / garage assembly", cost = 300 },
	{ stage = 6, name = "Navigation Unit", progress = 55, focus = "Cube / future signal tasks", cost = 350 },
	{ stage = 7, name = "Garage Reactor", progress = 67, focus = "Reactor gameplay", cost = 400 },
	{ stage = 8, name = "Chrono-Core", progress = 78, focus = "Purchase + charging sequence", cost = 475, requirement = "ReactorCommissioned" },
	{ stage = 9, name = "Weather Stabilizer", progress = 88, focus = "Tornado / protection chapter", cost = 550, requirement = "ChronoCoreCharged" },
	{ stage = 10, name = "Passenger Capsule", progress = 96, focus = "Final assembly", cost = 625 },
	{ stage = 11, name = "Final Calibration", progress = 100, focus = "Finale", cost = 695 },
} :: { StageDefinition }

Config.Chapters = {
	{ chapter = 0, name = "The Blueprint" },
	{ chapter = 1, name = "A Clock and a Cold One" },
	{ chapter = 2, name = "TV of the Future" },
	{ chapter = 3, name = "Bathroom Chaos" },
	{ chapter = 4, name = "Garage Build-Up" },
	{ chapter = 5, name = "Tornado Trouble" },
	{ chapter = 6, name = "D.E.S. Is Watching" },
	{ chapter = 7, name = "Reactor Time" },
	{ chapter = 8, name = "Chrono-Core" },
	{ chapter = 9, name = "Time Is Breaking" },
	{ chapter = 10, name = "Final Assembly" },
	{ chapter = 11, name = "The Last Task" },
	{ chapter = 12, name = "The Big Bang Theory Apartment", epilogue = true },
}

export type UpgradeCost = { allowance: number }
export type UpgradeDefinition = {
	id: string,
	name: string,
	category: string,
	description: string,
	maxLevel: number,
	costs: { UpgradeCost },
}

Config.UpgradeCategoryOrder = {
	"House Utility",
	"Storm",
	"Garage / Time Machine",
	"Panic Survival",
}

Config.Upgrades = {
	{
		id = "ExtraFridgeShelf",
		name = "Extra Fridge Shelf",
		category = "House Utility",
		description = "Adds two safe drink slots per level.",
		maxLevel = 2,
		costs = { { allowance = 180 }, { allowance = 400 } },
	},
	{
		id = "RemoteTracker",
		name = "Remote Tracker",
		category = "House Utility",
		description = "Reveals the active TV remote to its owner.",
		maxLevel = 1,
		costs = { { allowance = 325 } },
	},
	{
		id = "LabelMaker",
		name = "Label Maker",
		category = "House Utility",
		description = "Adds readable labels to active task objects.",
		maxLevel = 1,
		costs = { { allowance = 220 } },
	},
	{
		id = "QuietDoors",
		name = "Quiet Doors",
		category = "House Utility",
		description = "Reduces door noise and George investigation range.",
		maxLevel = 2,
		costs = { { allowance = 240 }, { allowance = 620 } },
	},
	{
		id = "FasterInteractionTools",
		name = "Faster Interaction Tools",
		category = "House Utility",
		description = "Speeds up supported hold interactions.",
		maxLevel = 3,
		costs = { { allowance = 250 }, { allowance = 625 }, { allowance = 1100 } },
	},
	{
		id = "UtilityBelt",
		name = "Utility Belt",
		category = "House Utility",
		description = "Reduces the movement penalty from carried task objects.",
		maxLevel = 2,
		costs = { { allowance = 365 }, { allowance = 900 } },
	},
	{
		id = "StormShutters",
		name = "Storm Shutters",
		category = "Storm",
		description = "Reduces tornado damage to the house.",
		maxLevel = 3,
		costs = { { allowance = 500 }, { allowance = 1050 }, { allowance = 1800 } },
	},
	{
		id = "StormStraps",
		name = "Storm Straps",
		category = "Storm",
		description = "Raises the chance that loose equipment stays secured.",
		maxLevel = 2,
		costs = { { allowance = 425 }, { allowance = 1050 } },
	},
	{
		id = "StormLocker",
		name = "Storm Locker",
		category = "Storm",
		description = "Adds protected storage slots for purchased equipment.",
		maxLevel = 2,
		costs = { { allowance = 700 }, { allowance = 1450 } },
	},
	{
		id = "RepairDiscount",
		name = "Repair Discount",
		category = "Storm",
		description = "Reduces aftermath repair prices.",
		maxLevel = 3,
		costs = { { allowance = 300 }, { allowance = 750 }, { allowance = 1350 } },
	},
	{
		id = "CartDolly",
		name = "Cart / Dolly",
		category = "Garage / Time Machine",
		description = "Improves movement speed while hauling machine crates.",
		maxLevel = 2,
		costs = { { allowance = 600 }, { allowance = 1300 } },
	},
	{
		id = "GarageShielding",
		name = "Garage Shielding",
		category = "Garage / Time Machine",
		description = "Reduces reactor suspicion generated during D.E.S. chapters.",
		maxLevel = 3,
		costs = { { allowance = 850 }, { allowance = 1700 }, { allowance = 2900 } },
	},
	{
		id = "CoolantReserve",
		name = "Coolant Reserve",
		category = "Garage / Time Machine",
		description = "Adds 25 reactor coolant capacity per level.",
		maxLevel = 3,
		costs = { { allowance = 800 }, { allowance = 1600 }, { allowance = 2600 } },
	},
	{
		id = "CalibrationTools",
		name = "Bonus Calibration Tools",
		category = "Garage / Time Machine",
		description = "Extends finale switch windows and speeds calibration prompts.",
		maxLevel = 2,
		costs = { { allowance = 1050 }, { allowance = 2150 } },
	},
	{
		id = "MachineStabilizer",
		name = "Machine Stabilizer",
		category = "Garage / Time Machine",
		description = "Reduces heat gain and charge lost in reactor accidents.",
		maxLevel = 3,
		costs = { { allowance = 1150 }, { allowance = 2350 }, { allowance = 3800 } },
	},
	{
		id = "QuietFootsteps",
		name = "Quieter Footsteps",
		category = "Panic Survival",
		description = "Reduces the sound radius George can investigate.",
		maxLevel = 3,
		costs = { { allowance = 400 }, { allowance = 950 }, { allowance = 1700 } },
	},
	{
		id = "AutoRescue",
		name = "One Auto-Rescue",
		category = "Panic Survival",
		description = "Provides one automatic brisket rescue per server session.",
		maxLevel = 1,
		costs = { { allowance = 1900 } },
	},
	{
		id = "DecoyTV",
		name = "Decoy TV",
		category = "Panic Survival",
		description = "Unlocks one football distraction during Panic Mode.",
		maxLevel = 1,
		costs = { { allowance = 1150 } },
	},
	{
		id = "EmergencyFuse",
		name = "Emergency Fuse",
		category = "Panic Survival",
		description = "Cancels one reactor shutdown per server session.",
		maxLevel = 1,
		costs = { { allowance = 1550 } },
	},
	{
		id = "BrisketInsurance",
		name = "Brisket Insurance",
		category = "Panic Survival",
		description = "Reduces paid brisket recovery costs.",
		maxLevel = 2,
		costs = { { allowance = 750 }, { allowance = 1600 } },
	},
} :: { UpgradeDefinition }

-- Every upgrade has an explicit runtime effect. Team effects use the highest
-- connected player's level rather than stacking, which keeps co-op balanced.
Config.Effects = {
	ExtraFridgeCapacity = { upgradeId = "ExtraFridgeShelf", default = 0, perLevel = 2, scope = "Team", minimum = 0, maximum = 4 },
	RemoteTrackerEnabled = { upgradeId = "RemoteTracker", default = 0, perLevel = 1, scope = "Player", minimum = 0, maximum = 1 },
	TaskLabelsEnabled = { upgradeId = "LabelMaker", default = 0, perLevel = 1, scope = "Player", minimum = 0, maximum = 1 },
	DoorNoiseMultiplier = { upgradeId = "QuietDoors", default = 1, perLevel = -0.18, scope = "Team", minimum = 0.64, maximum = 1 },
	InteractionSpeedMultiplier = { upgradeId = "FasterInteractionTools", default = 1, perLevel = 0.12, scope = "Player", minimum = 1, maximum = 1.36 },
	CarrySpeedMultiplier = { upgradeId = "UtilityBelt", default = 1, perLevel = 0.10, scope = "Player", minimum = 1, maximum = 1.2 },
	StormDamageMultiplier = { upgradeId = "StormShutters", default = 1, perLevel = -0.18, scope = "Team", minimum = 0.46, maximum = 1 },
	LooseItemProtectionChance = { upgradeId = "StormStraps", default = 0, perLevel = 0.25, scope = "Team", minimum = 0, maximum = 0.5 },
	StormLockerCapacity = { upgradeId = "StormLocker", default = 0, perLevel = 2, scope = "Team", minimum = 0, maximum = 4 },
	RepairCostMultiplier = { upgradeId = "RepairDiscount", default = 1, perLevel = -0.15, scope = "Team", minimum = 0.55, maximum = 1 },
	CrateCarrySpeedMultiplier = { upgradeId = "CartDolly", default = 1, perLevel = 0.15, scope = "Team", minimum = 1, maximum = 1.3 },
	DESSuspicionMultiplier = { upgradeId = "GarageShielding", default = 1, perLevel = -0.2, scope = "Team", minimum = 0.4, maximum = 1 },
	CoolantCapacityBonus = { upgradeId = "CoolantReserve", default = 0, perLevel = 25, scope = "Team", minimum = 0, maximum = 75 },
	CalibrationWindowBonus = { upgradeId = "CalibrationTools", default = 0, perLevel = 10, scope = "Team", minimum = 0, maximum = 20 },
	MachineHeatMultiplier = { upgradeId = "MachineStabilizer", default = 1, perLevel = -0.15, scope = "Team", minimum = 0.55, maximum = 1 },
	PanicNoiseMultiplier = { upgradeId = "QuietFootsteps", default = 1, perLevel = -0.16, scope = "Player", minimum = 0.52, maximum = 1 },
	AutoRescueUnlocked = { upgradeId = "AutoRescue", default = 0, perLevel = 1, scope = "Player", minimum = 0, maximum = 1 },
	DecoyTVUnlocked = { upgradeId = "DecoyTV", default = 0, perLevel = 1, scope = "Player", minimum = 0, maximum = 1 },
	EmergencyFuseUnlocked = { upgradeId = "EmergencyFuse", default = 0, perLevel = 1, scope = "Player", minimum = 0, maximum = 1 },
	BrisketRecoveryCostMultiplier = { upgradeId = "BrisketInsurance", default = 1, perLevel = -0.25, scope = "Player", minimum = 0.5, maximum = 1 },
}

Config.Reactor = {
	BaseCoolantCapacity = 100,
	CommissionCharge = 20,
	MaximumCharge = 100,
	MaximumHeat = 100,
	MaximumSuspicion = 100,
	CoolantRefillCash = 80,
	AccidentChargeLoss = 15,
	AccidentCooldown = 30,
	StabilityLoss = 15,
	IdleCoolingPerSecond = 2.2,
	IdleSuspicionLossPerSecond = 0.4,
	Modes = {
		Safe = { chargePerSecond = 0.7, heatPerSecond = 0.35, coolantPerSecond = 0.12, suspicionPerSecond = 0.15 },
		Fast = { chargePerSecond = 1.5, heatPerSecond = 0.95, coolantPerSecond = 0.32, suspicionPerSecond = 0.45 },
		Ludicrous = { chargePerSecond = 3.2, heatPerSecond = 2.4, coolantPerSecond = 0.8, suspicionPerSecond = 1.5 },
	},
	ModeOrder = { "Safe", "Fast", "Ludicrous" },
}

Config.FinalCalibration = {
	Order = { "Clock", "Navigation", "Power" },
	HoldDuration = 3.5,
	ResetAfterSeconds = 75,
}

Config.Finale = {
	MinimumStability = 25,
	ExternalTimeout = 55,
	FallbackDuration = 8,
	SwitchWindow = 45,
	DepartureDelay = 7,
	Phases = {
		{ id = "DESRaid", title = "D.E.S. RAID", objective = "Keep the garage project hidden until the agents clear out.", stabilityLoss = 10 },
		{ id = "Tornado", title = "TORNADO PRESSURE", objective = "Hold onto the machine while the storm passes.", stabilityLoss = 10 },
		{ id = "GeorgePanic", title = "GEORGE PANIC", objective = "Survive the final George chase and keep him away from the garage.", stabilityLoss = 20 },
	},
	OverloadOrder = { "Power", "Clock", "Navigation" },
}

Config.ProfileDefaults = {
	schemaVersion = Config.SchemaVersion,
	upgrades = {},
	victory = false,
	totalVictories = 0,
}

return table.freeze(Config)
