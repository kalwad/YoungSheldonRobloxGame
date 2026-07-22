-- Edit/runtime-safe audit for the Family-owned allowance/delivery/stage contract.
-- Run after time_machine_install.luau and source injection.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local familyRoot = ReplicatedStorage:FindFirstChild("CooperGame")
local progressionRoot = ReplicatedStorage:FindFirstChild("CooperProgression")
assert(familyRoot and familyRoot:IsA("Folder"), "ReplicatedStorage.CooperGame missing")
if not progressionRoot then
	-- This audit belongs to the retired advanced-progression install. The current
	-- simple-gameplay build intentionally keeps the eleven paid machine stages in
	-- CooperGame and requires every CooperProgression runtime object to be absent.
	-- Treat that mutually exclusive configuration as an explicit skip instead of
	-- reporting a false regression when the complete verifier suite is run.
	print("[CooperProgressionFamilyAudit] SKIP: retired CooperProgression system is intentionally not installed")
	return true
end
assert(progressionRoot:IsA("Folder"), "ReplicatedStorage.CooperProgression must be a Folder when installed")
assert(progressionRoot:GetAttribute("InstallVersion") == "2026-07-13.tm.family.3", "Progression world/client installer version is stale")

local familyModule = familyRoot:FindFirstChild("Config")
local progressionModule = progressionRoot:FindFirstChild("Config")
assert(familyModule and familyModule:IsA("ModuleScript"), "CooperGame.Config missing")
assert(progressionModule and progressionModule:IsA("ModuleScript"), "CooperProgression.Config missing")
local Family = require(familyModule)
local Progression = require(progressionModule)

assert(Progression.Ownership.allowance == "CooperGame", "Allowance ownership must stay in CooperGame")
assert(Progression.Ownership.pendingPartStage == "CooperGame", "Pending delivery ownership must stay in CooperGame")
assert(Progression.Ownership.machineStage == "CooperGame", "Machine stage ownership must stay in CooperGame")
for _, forbidden in ipairs({ "cash", "chronons", "allowance", "machineStage", "pendingPartStage", "highestChapter" }) do
	assert(Progression.ProfileDefaults[forbidden] == nil, "Progression profile duplicates Family field " .. forbidden)
end

assert(#Family.MachineStages == 11, "Family config must define 11 machine stages")
assert(#Progression.MachineStages == #Family.MachineStages, "Stage count mismatch")
for index, familyStage in ipairs(Family.MachineStages) do
	local advancedStage = Progression.MachineStages[index]
	assert(advancedStage.stage == index and familyStage.stage == index, "Non-sequential stage " .. index)
	assert(advancedStage.name == familyStage.name, "Stage name mismatch at " .. index)
	assert(advancedStage.progress == familyStage.progress, "Stage progress mismatch at " .. index)
	assert(type(familyStage.cost) == "number" and familyStage.cost > 0 and familyStage.cost % 1 == 0, "Family stage " .. index .. " has no positive integer cost")
	assert(advancedStage.cost == familyStage.cost, "Advanced cost mismatch at stage " .. index)
end

for _, upgrade in ipairs(Progression.Upgrades) do
	assert(#upgrade.costs == upgrade.maxLevel, upgrade.id .. " cost level count mismatch")
	for level, cost in ipairs(upgrade.costs) do
		assert(type(cost.allowance) == "number" and cost.allowance > 0 and cost.allowance % 1 == 0, string.format("%s level %d has invalid allowance cost", upgrade.id, level))
		assert(cost.cash == nil and cost.chronons == nil, upgrade.id .. " still uses the obsolete dual-currency schema")
	end
end

local familyEvents = ServerScriptService:FindFirstChild(Family.ServerEventsName)
assert(familyEvents and familyEvents:IsA("Folder"), Family.ServerEventsName .. " missing")
assert(familyEvents:FindFirstChild("API") and familyEvents.API:IsA("BindableFunction"), "Family API missing")

local progressionEvents = ServerScriptService:FindFirstChild(Progression.ServerEventsName)
assert(progressionEvents and progressionEvents:IsA("Folder"), Progression.ServerEventsName .. " missing")
for name, className in pairs({
	API = "BindableFunction",
	RegisterCrisis = "BindableEvent",
	CrisisRequest = "BindableEvent",
	CrisisResolved = "BindableEvent",
}) do
	local item = progressionEvents:FindFirstChild(name)
	assert(item and item.ClassName == className, "Progression server event invalid: " .. name)
end

local progressionRemotes = progressionRoot:FindFirstChild(Progression.RemotesName)
assert(progressionRemotes and progressionRemotes:IsA("Folder"), "CooperProgression.Remotes missing")
for _, name in ipairs({ "Snapshot", "Feedback", "Request", "Finale" }) do
	local remote = progressionRemotes:FindFirstChild(name)
	assert(remote and remote:IsA("RemoteEvent"), "Progression remote invalid: " .. name)
end

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
local garage = environment and environment:FindFirstChild("DetachedGarage")
local machine = garage and garage:FindFirstChild("CooperTimeMachine")
assert(machine and machine:IsA("Model"), "DetachedGarage.CooperTimeMachine missing")
local stages = machine:FindFirstChild("Stages")
local controls = machine:FindFirstChild("Controls")
assert(stages and stages:IsA("Folder") and #stages:GetChildren() == 11, "Machine must have 11 visual stages")
assert(controls and controls:IsA("Folder"), "Machine controls missing")
local seenVisualStages = {}
for _, stageFolder in ipairs(stages:GetChildren()) do
	local required = tonumber(stageFolder:GetAttribute("RequiredStage"))
	assert(required and required >= 1 and required <= 11, "Visual stage has invalid RequiredStage: " .. stageFolder.Name)
	assert(not seenVisualStages[required], "Duplicate visual RequiredStage " .. tostring(required))
	seenVisualStages[required] = true
end
for index = 1, 11 do
	assert(seenVisualStages[index], "Missing visual RequiredStage " .. index)
end
for _, name in ipairs({
	"PurchaseConsole",
	"UpgradeConsole",
	"ReactorConsole",
	"ReactorModeConsole",
	"CoolantConsole",
	"LaunchConsole",
	"CalibrationClock",
	"CalibrationNavigation",
	"CalibrationPower",
	"GarageReturnSpawn",
}) do
	assert(controls:FindFirstChild(name), "Missing advanced control " .. name)
end

local apartment = Workspace:FindFirstChild("CooperFutureApartment")
assert(apartment and apartment:IsA("Model"), "CooperFutureApartment missing")
assert(apartment:FindFirstChild("FutureSpawn") and apartment.FutureSpawn:IsA("BasePart"), "FutureSpawn missing")
local returnPortal = apartment:FindFirstChild("ReturnPortal")
assert(returnPortal and returnPortal:IsA("BasePart"), "ReturnPortal missing")
assert(returnPortal:FindFirstChild("Prompt") and returnPortal.Prompt:IsA("ProximityPrompt"), "Return portal prompt missing")

local progressionScript = ServerScriptService:FindFirstChild("CooperProgression")
assert(progressionScript and progressionScript:IsA("Script"), "CooperProgression server script missing")
local source = progressionScript.Source
for _, requiredToken in ipairs({ "SpendAllowance", "OrderMachinePart", "foundationPlayerStage", "SetChapter" }) do
	assert(string.find(source, requiredToken, 1, true), "Progression source missing Family integration token " .. requiredToken)
end
for _, forbiddenToken in ipairs({ "HydratePlayerEconomy", "HydrateCampaignProgress", "PurchaseMachineStage" }) do
	assert(not string.find(source, forbiddenToken, 1, true), "Progression source still contains obsolete ownership path " .. forbiddenToken)
end


local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local progressionClient = starterScripts and starterScripts:FindFirstChild("CooperProgression")
assert(progressionClient and progressionClient:IsA("LocalScript"), "StarterPlayerScripts.CooperProgression client missing")
assert(progressionClient.Disabled == false, "CooperProgression client is disabled")
assert(progressionClient:GetAttribute("SourceFile") == "CooperProgression.client.luau", "Progression client source mirror marker missing")
assert(progressionClient:GetAttribute("InstallVersion") == "2026-07-13.tm.family.3", "Progression client install version is stale")
local clientSource = progressionClient.Source
assert(#clientSource > 20000, "CooperProgression client source was not injected")
for _, requiredToken in ipairs({
	"CooperProgressionHUD",
	"updateResponsiveLayout",
	"COOPER GARAGE UPGRADES",
	"RequestSnapshot",
	"BuyUpgrade",
	"BuyNextStage",
	"CycleReactorMode",
	"ToggleReactor",
	"RefillCoolant",
	"BeginFinale",
	"OpenShop",
	"Snapshot render failed",
	"Feedback render failed",
	"Finale render failed",
	"TemporalTransition",
	"WELCOME TO THE FUTURE",
}) do
	assert(string.find(clientSource, requiredToken, 1, true), "Progression client missing runtime token " .. requiredToken)
end

print(string.format(
	"[CooperProgressionFamilyAudit] PASS: %d paid stages, %d allowance upgrades, %d controls, responsive client and future apartment ready",
	#Family.MachineStages,
	#Progression.Upgrades,
	#controls:GetChildren()
))
