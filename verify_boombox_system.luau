--!nonstrict
-- Standalone, non-mutating audit for the paid living-room income boombox.
-- Safe to run from Studio's command bar in edit mode or after play-mode startup.
-- This script only requires the frozen config and reads instances/source/state;
-- it never invokes gameplay APIs, fires events, changes attributes, or saves data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local running = RunService:IsRunning()
local checks = 0

local function check(condition, message)
	checks += 1
	assert(condition, "[BoomboxAudit] " .. message)
end

local function approximate(actual, expected, tolerance, message)
	check(
		type(actual) == "number" and math.abs(actual - expected) <= tolerance,
		string.format("%s (expected %.6f, got %s)", message, expected, tostring(actual))
	)
end

local function need(parent, name, className, recursive)
	check(typeof(parent) == "Instance", "Cannot find " .. name .. " below a missing parent")
	local child = parent:FindFirstChild(name, recursive == true)
	check(child ~= nil, parent:GetFullName() .. " is missing " .. name)
	if className then
		check(child:IsA(className), child:GetFullName() .. " must be a " .. className)
	end
	return child
end

local function sourceOf(scriptObject)
	check(scriptObject:IsA("LuaSourceContainer"), scriptObject:GetFullName() .. " is not source-bearing")
	check(not scriptObject.Disabled, scriptObject:GetFullName() .. " is disabled")
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	check(ok and type(source) == "string", "Studio could not read " .. scriptObject:GetFullName() .. ".Source")
	check(#source > 1000, scriptObject:GetFullName() .. " has empty or placeholder source")
	return source
end

local function has(source, marker, message)
	check(string.find(source, marker, 1, true) ~= nil, message or ("Source is missing " .. marker))
end

local function lacks(source, marker, message)
	check(string.find(source, marker, 1, true) == nil, message or ("Source unexpectedly contains " .. marker))
end

local function section(source, startMarker, endMarker, label)
	local startAt = string.find(source, startMarker, 1, true)
	check(startAt ~= nil, (label or "Source") .. " is missing section start " .. startMarker)
	local endAt = startAt and string.find(source, endMarker, startAt + #startMarker, true) or nil
	check(endAt ~= nil, (label or "Source") .. " is missing section end " .. endMarker)
	return string.sub(source, startAt, endAt - 1)
end

local function countPlain(source, marker)
	local count = 0
	local cursor = 1
	while true do
		local found = string.find(source, marker, cursor, true)
		if not found then
			return count
		end
		count += 1
		cursor = found + #marker
	end
end

local function ordered(source, markers, message)
	local cursor = 1
	for _, marker in ipairs(markers) do
		local found = string.find(source, marker, cursor, true)
		check(found ~= nil, (message or "Required lifecycle ordering is missing") .. ": " .. marker)
		cursor = found + #marker
	end
end

local function vectorClose(actual, expected, tolerance)
	return typeof(actual) == "Vector3" and (actual - expected).Magnitude <= tolerance
end

-- Configuration and economy -------------------------------------------------

local gameRoot = need(ReplicatedStorage, "CooperGame", "Folder")
local configModule = need(gameRoot, "Config", "ModuleScript")
local state = need(gameRoot, "State", "Folder")
local remotes = need(gameRoot, "Remotes", "Folder")
for _, remoteName in ipairs({ "Snapshot", "Feedback", "Request", "BankHack" }) do
	need(remotes, remoteName, "RemoteEvent")
end

local Config
if running then
	Config = require(configModule)
else
	-- Edit-mode command/plugin VMs can cache an older ModuleScript result even
	-- after the installed source changes. Require a disposable clone instead.
	local freshConfig = configModule:Clone()
	freshConfig.Name = "__BoomboxAuditConfig"
	freshConfig.Parent = gameRoot
	Config = require(freshConfig)
	freshConfig:Destroy()
end
check(type(Config) == "table", "CooperGame.Config did not return a table")
check(table.isfrozen(Config), "The top-level gameplay config must remain frozen")
check(Config.SchemaVersion == 12, "Personal persistence schema must be version 12")
check(Config.DataStoreName == "CooperFamilyTasks_v2", "Unexpected profile DataStore name")
check(Config.DataStoreKeyPrefix == "player_", "Unexpected profile key prefix")

local expectedTaskOrder = { "GeorgeBeer", "MaryDishes", "MaryTrash", "MissyPlush", "MedfordBankHack" }
local expectedRewards = { 55, 30, 40, 70 }
check(#Config.Tasks == 5, "Exactly five rotating tasks must remain")
check(#Config.TaskOrder == 5, "TaskOrder must contain exactly five tasks")
local rewardCycle = 0
local largestTaskReward = 0
for index, expectedId in ipairs(expectedTaskOrder) do
	local definition = Config.Tasks[index]
	check(type(definition) == "table", "Task definition " .. index .. " is missing")
	check(definition.id == expectedId, "Task definition order changed at " .. index)
	check(Config.TaskOrder[index] == expectedId, "Runtime task order changed at " .. index)
	local expectedReward = expectedRewards[index]
	if expectedReward then
		check(definition.reward == expectedReward, expectedId .. " has the wrong balanced reward")
		check(definition.reward > 0, expectedId .. " must pay a positive allowance reward")
		rewardCycle += definition.reward
		largestTaskReward = math.max(largestTaskReward, definition.reward)
	end
end
check(rewardCycle == 195, "The four original chore rewards must total $195")
check(Config.Tasks[1].startTarget == "Keyboard", "The opening beer task must begin at Sheldon's computer")
check(Config.Tasks[4].guidance == true, "Missy's search must expose the configured guidance arrow")

check(#Config.MachineStages == 11, "The Time Machine must retain all eleven paid stages")
local machineCost = 0
local previousProgress = 0
for index, definition in ipairs(Config.MachineStages) do
	check(definition.stage == index, "Machine stages must be sequential at stage " .. index)
	check(type(definition.cost) == "number" and definition.cost > 0, "Machine stage " .. index .. " must cost allowance")
	check(definition.progress > previousProgress, "Machine progress must increase at stage " .. index)
	previousProgress = definition.progress
	machineCost += definition.cost
end
check(previousProgress == 100, "The final Time Machine stage must reach 100%")
check(machineCost == 4020, "The final eleven-stage machine curve must cost $4,020")

local boomboxConfig = Config.Boombox
check(type(boomboxConfig) == "table", "Config.Boombox is missing")
check(boomboxConfig.Price == 350, "The delivered income boombox must cost $350")
check(boomboxConfig.AutoplayUpgradePrice == 1250, "The permanent autoplay upgrade must cost $1,250")
check(boomboxConfig.ModelName == "CooperIncomeBoombox", "Unexpected boombox model name")
check(boomboxConfig.AudioId == "rbxassetid://86759598635831", "Boombox audio does not use the uploaded Creator Dashboard asset")
approximate(boomboxConfig.TrackDuration, 22.465306, 0.000001, "Boombox duration no longer matches YouDogSong.mp3")
check(boomboxConfig.PayoutPerTick == 30, "Each authorized boombox tick must pay $30")
check(boomboxConfig.MaximumPaidTicks == 10, "Each complete track must cap at ten paid ticks")
approximate(
	boomboxConfig.PayoutInterval,
	boomboxConfig.TrackDuration / boomboxConfig.MaximumPaidTicks,
	0.000001,
	"Payout interval must divide the exact track into ten ticks"
)
check(boomboxConfig.CooldownSeconds == 120, "Boombox cooldown must remain 120 seconds")
check(boomboxConfig.PreloadTimeoutSeconds == 8, "Boombox preload timeout must remain eight seconds")
check(boomboxConfig.DanceBPM == 130, "NPC dance timing must remain locked to 130 BPM")
approximate(boomboxConfig.DanceBeatOffsetSeconds, 0.16, 0.000001, "NPC dance beat offset changed")
approximate(boomboxConfig.DanceJumpHeight, 1.05, 0.000001, "NPC dance jump height changed")
local maximumPayout = boomboxConfig.PayoutPerTick * boomboxConfig.MaximumPaidTicks
check(maximumPayout == 300, "A complete song must pay exactly $300")
check(boomboxConfig.Price > rewardCycle, "A fresh player must need more than one full chore cycle to buy the boombox")
check(boomboxConfig.Price <= rewardCycle * 2, "The boombox should remain attainable within two complete chore cycles")
check(
	boomboxConfig.AutoplayUpgradePrice > boomboxConfig.Price * 3,
	"Autoplay convenience is too cheap relative to the delivered boombox"
)
check(
	boomboxConfig.AutoplayUpgradePrice < machineCost,
	"Autoplay upgrade should remain attainable before completing the whole Time Machine"
)
check(maximumPayout < boomboxConfig.AutoplayUpgradePrice, "One song must not purchase the autoplay upgrade by itself")
check(machineCost > rewardCycle * 20, "The complete Time Machine curve is still progressing too quickly")
check(largestTaskReward == 70, "No onboarding chore should exceed the $70 reward cap")

local defaults = Config.ProfileDefaults
check(type(defaults) == "table" and defaults.schemaVersion == 12, "Profile defaults are not schema v12")
check(defaults.allowance == 0, "Fresh profiles must begin with no allowance")
check(defaults.machineStage == 0 and defaults.pendingPartStage == 0, "Fresh profiles must not own machine progress or a free pending part")
check(defaults.totalTasks == 0, "Fresh profiles must begin with zero completed chores")
check(defaults.boomboxPurchased == false, "Fresh profiles must not own a boombox")
check(defaults.boomboxPlaced == false, "Fresh profiles must not begin with a placed boombox")
check(defaults.boomboxNextPlayAt == 0, "Fresh profiles must not begin on cooldown")
check(defaults.boomboxAutoplayPurchased == false, "Fresh/legacy profiles must not receive a free autoplay entitlement")
check(type(defaults.taskAutomationInstalled) == "table" and next(defaults.taskAutomationInstalled) == nil, "Fresh profiles must not own task robots")
check(defaults.pendingTaskUpgradeId == "", "Fresh profiles must not begin with an automation delivery")
check(defaults.bankHackSuccesses == 0, "Fresh profiles must begin with zero successful bank hacks")

check(state:GetAttribute("SchemaVersion") == 12, "Shared state does not expose schema version 12")
check(state:GetAttribute("FoundationContract") == "PersonalV4", "Shared state lost the PersonalV4 contract")
check(state:GetAttribute("SupportsPaidPartOrdering") == true, "Shared state does not advertise paid machine parts")
check(state:GetAttribute("SupportsIncomeBoombox") == true, "Shared state does not advertise the income boombox")
check(state:GetAttribute("SupportsBoombox") == true, "Shared state does not advertise boombox lifecycle support")
check(state:GetAttribute("SupportsBoomboxAutoplay") == true, "Shared state does not advertise persistent autoplay support")
check(state:GetAttribute("SupportsTaskAutomation") == true, "Shared state does not advertise task automation")
check(state:GetAttribute("SupportsMedfordBankHack") == true, "Shared state does not advertise Medford Bank hacking")

-- Authored world, placement, and visual quality -----------------------------

local environment = need(workspace, "CooperHouseEnvironment", "Model")
local house = need(environment, "CooperHouse", "Model")
local furniture = need(house, "FurnitureAndProps", "Model")
local rooms = need(house, "InteriorRooms", "Model")
local endTable = need(furniture, "FormalSofaEndTable", "Model")
local endTableTop = need(endTable, "Top", "BasePart")
local formalSofa = need(furniture, "FormalGreenFloralSofa", "Model")
local livingCarpet = need(rooms, "FormalLivingOatmealCarpet", "BasePart")

local taskWorld = need(environment, Config.WorldRootName, "Model")
check(taskWorld:GetAttribute("Ready") == true, "Family task world did not finish installing")
check(taskWorld:GetAttribute("InstallVersion") == "2026-07-21.hackerbot.1", "Family task world is not on the HackerBot geometry version")
check(taskWorld:GetAttribute("StationCount") == 13, "Family task world must advertise thirteen retained stations")
check(taskWorld:GetAttribute("SupportsIncomeBoombox") == true, "Task world does not advertise income-boombox support")
check(taskWorld:GetAttribute("IncomeBoomboxSoundId") == boomboxConfig.AudioId, "Task world and config disagree on boombox audio")

local stations = need(taskWorld, "Stations", "Folder")
local visuals = need(taskWorld, "TaskVisuals", "Folder")
local deliveryWorld = need(taskWorld, "Delivery", "Model")
need(deliveryWorld, "DeliveryDropZone", "BasePart")
local boomboxModel = need(visuals, boomboxConfig.ModelName, "Model")
check(boomboxModel.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Boombox must stream as one complete model")
check(boomboxModel:GetAttribute("InstallVersion") == "2026-07-13.4", "Boombox model install version is stale")
check(boomboxModel:GetAttribute("FamilyTaskVisual") == "IncomeBoombox", "Boombox is not tagged as the income visual")
check(boomboxModel:GetAttribute("RuntimeVisibility") == "PlacedOnly", "Boombox visibility is not locked to placement")
check(boomboxModel:GetAttribute("PlacementFurniture") == "FormalSofaEndTable.Top", "Boombox is not attached to the living-room end table")
check(boomboxModel:GetAttribute("SoundId") == boomboxConfig.AudioId, "Boombox model and config disagree on audio")
approximate(boomboxModel:GetAttribute("ExpectedAudioDuration"), boomboxConfig.TrackDuration, 0.000001, "Boombox model has the wrong expected duration")
check(
	vectorClose(boomboxModel:GetAttribute("PhysicalBoundsSize"), Vector3.new(1.94, 1.11, 0.69), 0.001),
	"Boombox physical-bounds contract changed"
)

local setupCFrame = boomboxModel:GetAttribute("SetupCFrame")
check(typeof(setupCFrame) == "CFrame", "Boombox model has no setup CFrame")
check(taskWorld:GetAttribute("IncomeBoomboxSetupCFrame") == setupCFrame, "Task world and model disagree on boombox placement")
local setupOnTable = endTableTop.CFrame:PointToObjectSpace(setupCFrame.Position)
approximate(setupOnTable.X, 0, 0.03, "Boombox is not centered across the end-table top")
approximate(setupOnTable.Z, 0, 0.03, "Boombox is not centered along the end-table top")
approximate(setupOnTable.Y, endTableTop.Size.Y * 0.5 + 0.025, 0.015, "Boombox base is not resting naturally above the tabletop")
check(setupCFrame.UpVector:Dot(endTableTop.CFrame.UpVector) > 0.999, "Boombox is tilted relative to its end table")
local sofaLook = formalSofa:GetPivot().LookVector
local planarSofaLook = sofaLook - endTableTop.CFrame.UpVector * sofaLook:Dot(endTableTop.CFrame.UpVector)
check(planarSofaLook.Magnitude > 0.5, "Formal sofa has no usable horizontal facing direction")
check(setupCFrame.LookVector:Dot(planarSofaLook.Unit) > 0.999, "Boombox front does not face naturally into the living room")
check((setupCFrame.Position - formalSofa:GetPivot().Position).Magnitude < 12, "Boombox end table is not naturally near the formal living-room sofa")

local collisionHull = need(boomboxModel, "CollisionHull", "BasePart")
check(boomboxModel.PrimaryPart == collisionHull, "CollisionHull must be the boombox PrimaryPart")
check(collisionHull:GetAttribute("PlacedCanCollide") == true, "Boombox collision hull is not enabled after placement")
check(collisionHull:GetAttribute("VisibleTransparency") == 1, "Invisible collision hull must stay visually hidden")
check(
	(collisionHull.CFrame.Position - (setupCFrame * CFrame.new(0, 0.42, 0)).Position).Magnitude < 0.01,
	"Collision hull is not aligned to the setup CFrame"
)

for _, requiredName in ipairs({
	"MainBody",
	"FrontFacePlate",
	"LeftEndCap",
	"RightEndCap",
	"LeftSpeakerOuterRing",
	"LeftSpeakerGrille",
	"LeftSpeakerDustCap",
	"RightSpeakerOuterRing",
	"RightSpeakerGrille",
	"RightSpeakerDustCap",
	"CassetteDoor",
	"CassetteWindow",
	"EqualizerDisplay",
	"PowerButton",
	"TopButton1",
	"ControlKnob1",
	"CarryHandle",
	"Antenna",
	"BrandPlate",
	"AudioEmitter",
}) do
	need(boomboxModel, requiredName, "BasePart", true)
end
need(boomboxModel, "DiscoLightRig", "Folder")
need(boomboxModel, "FloorLightPools", "Folder")

local physicalParts = {}
local effectParts = {}
local floorPools = {}
local lights = {}
local spotLights = {}
local pointLights = {}
local discoLensCount = 0
local equalizerBarCount = 0
local collisionPartCount = 0
local surfaceGuis = {}
local minX, minY, minZ = math.huge, math.huge, math.huge
local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

for _, descendant in ipairs(boomboxModel:GetDescendants()) do
	if descendant:IsA("BasePart") then
		check(descendant.Anchored, descendant.Name .. " must be anchored as living-room furniture")
		check(not descendant.CanTouch, descendant.Name .. " must not create touch noise")
		check(descendant:GetAttribute("BoomboxVisual") == true, descendant.Name .. " is missing its boombox visual tag")
		local visibleTransparency = descendant:GetAttribute("VisibleTransparency")
		local placedCanCollide = descendant:GetAttribute("PlacedCanCollide")
		local effect = descendant:GetAttribute("BoomboxEffectPart")
		check(type(visibleTransparency) == "number" and visibleTransparency >= 0 and visibleTransparency <= 1, descendant.Name .. " has no valid visible transparency")
		check(type(placedCanCollide) == "boolean", descendant.Name .. " has no placement collision contract")
		check(type(effect) == "boolean", descendant.Name .. " has no effect-part contract")
		if placedCanCollide then
			collisionPartCount += 1
			check(descendant == collisionHull, "Only CollisionHull may block the player")
		end
		if effect then
			check(not placedCanCollide, descendant.Name .. " is an effect but can become collidable")
			table.insert(effectParts, {
				part = descendant,
				visibleTransparency = visibleTransparency,
			})
		else
			table.insert(physicalParts, {
				part = descendant,
				visibleTransparency = visibleTransparency,
				placedCanCollide = placedCanCollide,
			})
			for xSign = -1, 1, 2 do
				for ySign = -1, 1, 2 do
					for zSign = -1, 1, 2 do
						local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(
							xSign * descendant.Size.X * 0.5,
							ySign * descendant.Size.Y * 0.5,
							zSign * descendant.Size.Z * 0.5
						))
						local setupLocal = setupCFrame:PointToObjectSpace(corner)
						minX = math.min(minX, setupLocal.X)
						minY = math.min(minY, setupLocal.Y)
						minZ = math.min(minZ, setupLocal.Z)
						maxX = math.max(maxX, setupLocal.X)
						maxY = math.max(maxY, setupLocal.Y)
						maxZ = math.max(maxZ, setupLocal.Z)

						local tableLocal = endTableTop.CFrame:PointToObjectSpace(corner)
						check(math.abs(tableLocal.X) <= endTableTop.Size.X * 0.5 + 0.08, descendant.Name .. " hangs beyond the end-table width")
						check(math.abs(tableLocal.Z) <= endTableTop.Size.Z * 0.5 + 0.08, descendant.Name .. " hangs beyond the end-table depth")
						check(tableLocal.Y >= endTableTop.Size.Y * 0.5 - 0.015, descendant.Name .. " clips into the tabletop")
					end
				end
			end
		end
		if descendant:GetAttribute("BoomboxFloorPool") == true then
			table.insert(floorPools, descendant)
		end
		if descendant:GetAttribute("DiscoLens") == true then
			discoLensCount += 1
			check(descendant.Material == Enum.Material.Neon, descendant.Name .. " must use a neon lens")
		end
		if descendant:GetAttribute("EqualizerBar") == true then
			equalizerBarCount += 1
			check(descendant.Material == Enum.Material.Neon, descendant.Name .. " must use a neon equalizer bar")
		end
	elseif descendant:IsA("Light") then
		table.insert(lights, descendant)
		check(descendant.Parent:IsA("BasePart"), descendant.Name .. " must be mounted to an emitter part")
		check(descendant.Parent:GetAttribute("BoomboxEffectPart") == true, descendant.Name .. " emitter is not tagged as an effect")
		if descendant:IsA("SpotLight") then
			table.insert(spotLights, descendant)
		elseif descendant:IsA("PointLight") then
			table.insert(pointLights, descendant)
		end
	elseif descendant:IsA("SurfaceGui") then
		table.insert(surfaceGuis, descendant)
	end
end

check(#physicalParts + #effectParts == 50, "Boombox must retain its exact 50-part authored assembly")
check(#physicalParts == 41, "Boombox must retain its exact 41-part physical/visible shell")
check(#effectParts == 9, "Boombox must retain its exact nine-part nonphysical effect rig")
check(collisionPartCount == 1, "Boombox must have exactly one placement collision hull")
check(discoLensCount == 4, "Boombox must have four colored disco lenses")
check(equalizerBarCount == 5, "Boombox must have five equalizer bars")
check(#floorPools == 3, "Boombox must paint three colored floor pools")
check(#lights == 5 and #spotLights == 4 and #pointLights == 1, "Boombox must have four spotlights and one room wash")
check(#surfaceGuis == 1, "Boombox should have exactly one restrained brand label")

local authoredBounds = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
local physicalBoundsContract = boomboxModel:GetAttribute("PhysicalBoundsSize")
check(
	math.abs(authoredBounds.X - physicalBoundsContract.X) < 0.02
		and math.abs(authoredBounds.Y - physicalBoundsContract.Y) < 0.02
		and math.abs(authoredBounds.Z - physicalBoundsContract.Z) < 0.02,
	"Authored shell no longer matches its physical-bounds contract"
)
check(minY >= -0.01 and minY <= 0.04, "Boombox feet are not resting on its setup plane")
check(authoredBounds.X < endTableTop.Size.X and authoredBounds.Z < endTableTop.Size.Z, "Boombox shell is too large for its end table")

local function worldAABB(cframe, size)
	local half = size * 0.5
	local right, up, look = cframe.RightVector, cframe.UpVector, cframe.LookVector
	return cframe.Position, Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	)
end
local physicalCenter = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
local boomboxCenter, boomboxHalf = worldAABB(setupCFrame * CFrame.new(physicalCenter), authoredBounds)
for _, furnitureName in ipairs({
	"FormalGreenFloralSofa",
	"FormalGlassCoffeeTable",
	"FormalRustButtonChair",
	"FormalBrassFloorLamp",
	"FormalEntryConsole",
}) do
	local furnishing = need(furniture, furnitureName, "Model")
	local furnishingCFrame, furnishingSize = furnishing:GetBoundingBox()
	local furnishingCenter, furnishingHalf = worldAABB(furnishingCFrame, furnishingSize)
	local delta = boomboxCenter - furnishingCenter
	local overlap = math.abs(delta.X) < boomboxHalf.X + furnishingHalf.X
		and math.abs(delta.Y) < boomboxHalf.Y + furnishingHalf.Y
		and math.abs(delta.Z) < boomboxHalf.Z + furnishingHalf.Z
	check(not overlap, "Boombox physical shell overlaps " .. furnitureName)
end

local brandPlate = need(boomboxModel, "BrandPlate", "BasePart")
local brandGui = need(brandPlate, "BrandGui", "SurfaceGui")
local brandText = need(brandGui, "BrandText", "TextLabel")
check(brandGui:GetAttribute("EnabledWhenPlaced") == true, "Brand label is not tied to placement visibility")
check(brandText.Text == "COOPER SOUND", "Boombox brand plate text changed")
check(brandText.TextScaled and brandText.BackgroundTransparency == 1, "Boombox brand plate is not cleanly authored")

for _, pool in ipairs(floorPools) do
	check(pool:IsDescendantOf(boomboxModel.FloorLightPools), pool.Name .. " is outside FloorLightPools")
	check(pool:GetAttribute("BoomboxEffectPart") == true, pool.Name .. " is not isolated as an effect")
	approximate(pool:GetAttribute("PlayingTransparency"), 0.56, 0.001, pool.Name .. " has the wrong pronounced active transparency")
	check(not pool.CanCollide and not pool.CanTouch and not pool.CanQuery, pool.Name .. " can interfere with the player")
	local carpetLocal = livingCarpet.CFrame:PointToObjectSpace(pool.Position)
	check(math.abs(carpetLocal.X) <= livingCarpet.Size.X * 0.5 + 0.1, pool.Name .. " is outside the living-room carpet width")
	check(math.abs(carpetLocal.Z) <= livingCarpet.Size.Z * 0.5 + 0.1, pool.Name .. " is outside the living-room carpet depth")
	approximate(carpetLocal.Y, livingCarpet.Size.Y * 0.5 + 0.025, 0.04, pool.Name .. " is not resting over the carpet surface")
	for widthSign = -1, 1, 2 do
		for depthSign = -1, 1, 2 do
			local corner = pool.CFrame:PointToWorldSpace(Vector3.new(
				0,
				widthSign * pool.Size.Y * 0.5,
				depthSign * pool.Size.Z * 0.5
			))
			local cornerOnCarpet = livingCarpet.CFrame:PointToObjectSpace(corner)
			check(math.abs(cornerOnCarpet.X) <= livingCarpet.Size.X * 0.5 + 0.04, pool.Name .. " spills beyond the carpet width")
			check(math.abs(cornerOnCarpet.Z) <= livingCarpet.Size.Z * 0.5 + 0.04, pool.Name .. " spills beyond the carpet depth")
		end
	end
end

for _, light in ipairs(spotLights) do
	check(light.Face == Enum.NormalId.Front, light.Name .. " points out of the wrong emitter face")
	approximate(light.Brightness, 5.75, 0.001, light.Name .. " brightness changed")
	approximate(light.Range, 31, 0.001, light.Name .. " range changed")
	approximate(light.Angle, 74, 0.001, light.Name .. " cone changed")
	check(light.Shadows == false, light.Name .. " should not create expensive moving shadows")
	check(typeof(light.Parent:GetAttribute("RestCFrame")) == "CFrame", light.Name .. " emitter has no rest transform")
	check(type(light.Parent:GetAttribute("SweepPhase")) == "number", light.Name .. " emitter has no sweep phase")
end
local partyWash = pointLights[1]
check(partyWash.Name == "PartyWash", "The room-wash PointLight has the wrong name")
approximate(partyWash.Brightness, 2.35, 0.001, "PartyWash brightness changed")
approximate(partyWash.Range, 24, 0.001, "PartyWash range changed")
check(partyWash.Shadows == false, "PartyWash should not create expensive shadows")

local audioEmitter = need(boomboxModel, "AudioEmitter", "BasePart")
local boomboxSound = need(audioEmitter, "BoomboxSound", "Sound")
check(audioEmitter:GetAttribute("BoomboxEffectPart") == true, "Audio emitter must remain invisible/nonphysical")
check(boomboxSound.SoundId == boomboxConfig.AudioId, "Boombox Sound uses the wrong audio asset")
approximate(boomboxSound.Volume, 0.7, 0.001, "Boombox volume changed")
approximate(boomboxSound.PlaybackSpeed, 1, 0.001, "Boombox playback speed changed")
check(boomboxSound.Looped == false, "Boombox song must not loop")
check(boomboxSound.PlayOnRemove == false, "Boombox song must stop if its emitter is removed")
check(boomboxSound.RollOffMode == Enum.RollOffMode.InverseTapered, "Boombox uses the wrong spatial rolloff")
approximate(boomboxSound.RollOffMinDistance, 7, 0.001, "Boombox minimum rolloff distance changed")
approximate(boomboxSound.RollOffMaxDistance, 68, 0.001, "Boombox maximum rolloff distance changed")
approximate(boomboxSound.EmitterSize, 7, 0.001, "Boombox emitter size changed")
approximate(boomboxSound:GetAttribute("ExpectedDuration"), boomboxConfig.TrackDuration, 0.000001, "Sound duration contract changed")
if boomboxSound.IsLoaded and boomboxSound.TimeLength > 1 then
	check(math.abs(boomboxSound.TimeLength - boomboxConfig.TrackDuration) <= 0.75, "Loaded Creator Dashboard audio has an unexpected duration")
end
if boomboxModel:GetAttribute("AudioReady") == true then
	check(boomboxSound.IsLoaded and boomboxSound.TimeLength > 1, "AudioReady is true but the exact Sound is not loaded")
	local loadedDuration = boomboxModel:GetAttribute("LoadedAudioDuration")
	check(type(loadedDuration) == "number", "AudioReady boombox has no measured duration")
	approximate(loadedDuration, boomboxSound.TimeLength, 0.01, "Measured audio duration disagrees with the Sound")
end

check(#stations:GetChildren() == 13, "Exactly thirteen task/economy/automation stations must exist")
local expectedActions = {
	DishesPromptAnchor = "Dishes",
	TrashPickupAnchor = "TrashPickup",
	OutdoorTrashAnchor = "TrashDrop",
	MissyPlushReturnAnchor = "MissyReturn",
	GeorgeBeerDropAnchor = "BeerDrop",
	MachineInstallBay = "MachineInstall",
	BoomboxSetupAnchor = "BoomboxSetup",
	BoomboxPowerAnchor = "BoomboxPower",
}
for stationName, action in pairs(expectedActions) do
	local anchor = need(stations, stationName, "BasePart")
	local prompt = need(anchor, "TaskPrompt", "ProximityPrompt")
	check(anchor.Anchored and not anchor.CanCollide and not anchor.CanTouch, stationName .. " has unsafe prompt-anchor physics")
	check(prompt:GetAttribute("FamilyTaskAction") == action, stationName .. " has the wrong action")
	check(prompt.RequiresLineOfSight == false, stationName .. " must remain usable around furniture")
end

local setupAnchor = stations.BoomboxSetupAnchor
local setupPrompt = setupAnchor.TaskPrompt
local powerAnchor = stations.BoomboxPowerAnchor
local powerPrompt = powerAnchor.TaskPrompt
check(setupAnchor:GetAttribute("FurnitureAnchor") == "FormalSofaEndTable.Top", "Setup station lost its furniture anchor")
check(setupAnchor:GetAttribute("BoomboxModel") == boomboxConfig.ModelName, "Setup station targets the wrong model")
approximate(setupAnchor:GetAttribute("AutoSetupRadius"), 5.5, 0.001, "Setup station has the wrong automatic-placement radius")
check(setupAnchor:GetAttribute("GuidanceColor") == "Purple", "Setup station lost its purple guidance contract")
check(powerAnchor:GetAttribute("FurnitureAnchor") == "FormalSofaEndTable.Top", "Power station lost its furniture anchor")
check(powerAnchor:GetAttribute("BoomboxModel") == boomboxConfig.ModelName, "Power station targets the wrong model")
check((setupAnchor.CFrame.Position - (setupCFrame * CFrame.new(0, 0.42, 0)).Position).Magnitude < 0.01, "Setup station is not on the boombox placement")
check((powerAnchor.CFrame.Position - (setupCFrame * CFrame.new(-0.82, 0.68, -0.39)).Position).Magnitude < 0.01, "Power station is not on the red power button")
check(setupPrompt.ActionText == "Set Up Boombox", "Setup prompt has the wrong action text")
if not running then
	check(powerPrompt.ActionText == "Turn On", "Authored power prompt has the wrong default action text")
else
	local powerText = powerPrompt.ActionText
	check(
		powerText == "Turn On"
			or powerText == "Turn On Boombox"
			or powerText == "Now Playing"
			or string.sub(powerText, 1, 9) == "Ready In ",
		"Play-mode power prompt has an invalid lifecycle label"
	)
end
approximate(setupPrompt.HoldDuration, 0.8, 0.001, "Setup hold duration changed")
approximate(powerPrompt.HoldDuration, 0.35, 0.001, "Power hold duration changed")
approximate(setupPrompt.MaxActivationDistance, 8, 0.001, "Setup activation distance changed")
approximate(powerPrompt.MaxActivationDistance, 8, 0.001, "Power activation distance changed")

-- Current edit/play state. These checks accept legitimate live playback but
-- require the installer defaults and every stable inactive state to be dark.
local rawModelPlaying = boomboxModel:GetAttribute("Playing")
local rawPlacedVisible = boomboxModel:GetAttribute("PlacedVisible")
local rawPlaced = boomboxModel:GetAttribute("Placed")
local modelPlaying = rawModelPlaying == true
local placedVisible = rawPlacedVisible == true
local placed = rawPlaced == true
local allPlayerPlacementKnown = true
local anyPlacedOwner = false
for _, player in ipairs(Players:GetPlayers()) do
	local playerPlaced = player:GetAttribute("CooperBoomboxPlaced")
	check(playerPlaced == nil or type(playerPlaced) == "boolean", player.Name .. " has an invalid CooperBoomboxPlaced attribute")
	if playerPlaced == nil then
		allPlayerPlacementKnown = false
	elseif playerPlaced then
		anyPlacedOwner = true
	end
end

if not running then
	check(boomboxModel:GetAttribute("Placed") == false, "Edit-mode boombox must start unplaced")
	check(boomboxModel:GetAttribute("Playing") == false, "Edit-mode boombox must start stopped")
	check(boomboxModel:GetAttribute("PlacedVisible") ~= true, "Edit-mode boombox must start hidden")
	check(not boomboxSound.Playing, "Edit-mode boombox Sound must start stopped")
	approximate(boomboxSound.TimePosition, 0, 0.001, "Edit-mode boombox Sound must start at zero")
	check(not setupPrompt.Enabled, "Setup prompt must be disabled by default")
	check(not powerPrompt.Enabled, "Power prompt must be disabled by default")
	for _, metadata in ipairs(physicalParts) do
		check(metadata.part.Transparency == 1, metadata.part.Name .. " must be hidden before purchase/setup")
		check(not metadata.part.CanCollide and not metadata.part.CanQuery, metadata.part.Name .. " is physical before setup")
	end
	for _, metadata in ipairs(effectParts) do
		check(metadata.part.Transparency == 1, metadata.part.Name .. " effect is visible in the installer default")
	end
	for _, gui in ipairs(surfaceGuis) do
		check(not gui.Enabled, gui.Name .. " must be disabled before setup")
	end
else
	check(taskWorld:GetAttribute("ControllerReady") == true, "Play-mode TaskWorld controller has not reached its initialized state")
	check(type(rawModelPlaying) == "boolean", "Play-mode boombox Playing attribute is invalid")
	check(type(rawPlacedVisible) == "boolean" and type(rawPlaced) == "boolean", "Play-mode boombox placement attributes are invalid")
	check(placed == placedVisible, "Placed and PlacedVisible runtime attributes disagree")
	if modelPlaying or anyPlacedOwner then
		check(placedVisible, "Owned/playing boombox is hidden")
	elseif allPlayerPlacementKnown then
		check(not placedVisible, "Boombox is visible even though no connected profile placed it")
	end
	if placedVisible then
		local visibleBodyParts = 0
		for _, metadata in ipairs(physicalParts) do
			approximate(metadata.part.Transparency, metadata.visibleTransparency, 0.001, metadata.part.Name .. " has the wrong placed transparency")
			check(metadata.part.CanCollide == metadata.placedCanCollide, metadata.part.Name .. " has the wrong placed collision state")
			if metadata.visibleTransparency < 1 then
				visibleBodyParts += 1
			end
		end
		check(visibleBodyParts >= 35, "Placed boombox does not expose its complete visual shell")
		for _, gui in ipairs(surfaceGuis) do
			check(gui.Enabled, gui.Name .. " did not become visible with the placed boombox")
		end
	else
		for _, metadata in ipairs(physicalParts) do
			check(metadata.part.Transparency == 1, metadata.part.Name .. " remains visible without a placed owner")
			check(not metadata.part.CanCollide and not metadata.part.CanQuery, metadata.part.Name .. " remains physical without a placed owner")
		end
	end
end

if modelPlaying then
	check(placedVisible and placed, "A playing boombox must be placed and visible")
	check(boomboxSound.Playing, "Playing state is active but the exact Sound is stopped")
	check(type(boomboxModel:GetAttribute("PlaybackSession")) == "string", "Playing boombox has no server session id")
	check(type(boomboxModel:GetAttribute("PlaybackOwnerUserId")) == "number", "Playing boombox has no owner id")
	for _, light in ipairs(lights) do
		check(light.Enabled, light.Name .. " did not turn on with playback")
	end
	for _, pool in ipairs(floorPools) do
		-- Beat-synchronized pools pulse around their authored base transparency;
		-- do not require a single frame-specific value in a live non-mutating audit.
		check(
			type(pool.Transparency) == "number"
				and pool.Transparency >= 0.35 - 0.001
				and pool.Transparency <= 0.72 + 0.001,
			pool.Name .. " is outside the authored beat-pulse visibility range"
		)
	end
else
	for _, light in ipairs(lights) do
		check(not light.Enabled, light.Name .. " remains enabled while the boombox is stopped")
	end
	for _, pool in ipairs(floorPools) do
		check(pool.Transparency == 1, pool.Name .. " remains visible while the boombox is stopped")
	end
	check(boomboxModel:GetAttribute("PlaybackSession") == nil, "Stopped boombox retained a playback session")
	check(boomboxModel:GetAttribute("PlaybackOwnerUserId") == nil, "Stopped boombox retained a playback owner")
	if not running or (#Players:GetPlayers() == 0 and not placedVisible) then
		check(not boomboxSound.Playing, "Initial inactive boombox Sound is playing")
	end
end

-- Server, client, persistence, and authorization source contracts -----------

local familyServerObject = need(ServerScriptService, "CooperGame", "Script")
local taskWorldObject = need(ServerScriptService, "CooperTaskWorld", "Script")
local familyClientObject = need(StarterPlayer.StarterPlayerScripts, "CooperGame", "LocalScript")
local backgroundMusicObject = need(StarterPlayer.StarterPlayerScripts, "CooperBackgroundMusic", "LocalScript")
local familySource = sourceOf(familyServerObject)
local taskWorldSource = sourceOf(taskWorldObject)
local clientSource = sourceOf(familyClientObject)
local backgroundMusicSource = sourceOf(backgroundMusicObject)

local serverEvents = need(ServerScriptService, Config.ServerEventsName, "Folder")
for _, specification in ipairs({
	{ "ReportAction", "BindableEvent" },
	{ "RegisterAction", "BindableEvent" },
		{ "RequestDelivery", "BindableEvent" },
		{ "RunTaskAutomation", "BindableEvent" },
		{ "API", "BindableFunction" },
}) do
	need(serverEvents, specification[1], specification[2])
end

for _, marker in ipairs({
	"local boomboxPlaybackOwner = nil",
	"local boomboxSessionSerial = 0",
	"BOOMBOX_TICK_EARLY_TOLERANCE = 0.15",
	"BOOMBOX_FINAL_TICK_TOLERANCE = 0.35",
	"local boomboxPurchased = raw.boomboxPurchased == true or boomboxPlaced",
	"boomboxPlaced = boomboxPlaced",
	"boomboxNextPlayAt = finiteInteger(raw.boomboxNextPlayAt",
	"boomboxAutoplayPurchased = boomboxPurchased and raw.boomboxAutoplayPurchased == true",
	"dataStore:UpdateAsync",
	"local function boomboxSnapshot(profile)",
	"autoplayPrice = Config.Boombox.AutoplayUpgradePrice",
	"autoplayPurchased = autoplayPurchased",
	"canUpgradeAutoplay = purchased and placed and not autoplayPurchased",
	"maximumPayout = Config.Boombox.PayoutPerTick * Config.Boombox.MaximumPaidTicks",
	"syncBoomboxPlacedAttribute(profile)",
	"profile.taskCursor = profile.data.totalTasks % #Config.TaskOrder",
	"profile.data.boomboxPurchased and not profile.data.boomboxPlaced",
	"queueDelivery(profile, \"Boombox\", 0)",
	"endBoomboxPlayback(profile, profile.boomboxPlayback.sessionId, \"PlayerLeaving\", true)",
	"endBoomboxPlayback(profile, profile.boomboxPlayback.sessionId, \"Shutdown\", true)",
}) do
	has(familySource, marker, "Family server is missing lifecycle/persistence marker " .. marker)
end

local machineOrderSection = section(
	familySource,
	"local function orderMachinePart(profile, expectedStage)",
	"local function orderBoombox(profile)",
	"machine order"
)
has(machineOrderSection, "profile.data.allowance < cost", "Machine ordering has no server balance check")
has(machineOrderSection, "profile.data.boomboxPurchased and not profile.data.boomboxPlaced", "Machine and boombox deliveries are not mutually exclusive")
ordered(machineOrderSection, {
	"setAllowance(profile, profile.data.allowance - cost)",
	"profile.data.pendingPartStage = definition.stage",
	"queueDelivery(profile, \"MachinePart\", definition.stage)",
}, "Machine part order must debit, persist pending stage, then deliver")

local purchaseSection = section(
	familySource,
	"local function orderBoombox(profile)",
	"local function upgradeBoomboxAutoplay(profile)",
	"boombox purchase"
)
for _, marker in ipairs({
	"profile.data.boomboxPurchased",
	"profile.data.pendingPartStage > 0",
	"profile.data.allowance < price",
	"Config.Boombox.Price",
}) do
	has(purchaseSection, marker, "Boombox purchase is missing " .. marker)
end
ordered(purchaseSection, {
	"setAllowance(profile, profile.data.allowance - price)",
	"profile.data.boomboxPurchased = true",
	"profile.data.boomboxPlaced = false",
	"profile.data.boomboxNextPlayAt = 0",
	"profile.boomboxDeliveryStep = \"WaitingDelivery\"",
	"queueDelivery(profile, \"Boombox\", 0)",
}, "Boombox order must atomically debit, persist ownership, then deliver")
lacks(purchaseSection, "task.wait", "Atomic boombox purchase path must not yield")

local autoplayPurchaseSection = section(
	familySource,
	"local function upgradeBoomboxAutoplay(profile)",
	"local function reportPlayerAction",
	"autoplay purchase"
)
for _, marker in ipairs({
	"profile.data.boomboxPurchased",
	"profile.data.boomboxPlaced",
	"profile.data.boomboxAutoplayPurchased",
	"Config.Boombox.AutoplayUpgradePrice",
	"profile.data.allowance < price",
	"BoomboxAutoplayPurchased",
	"broadcastState()",
	"task.defer(saveProfile, profile.player, false)",
}) do
	has(autoplayPurchaseSection, marker, "Autoplay purchase is missing " .. marker)
end
ordered(autoplayPurchaseSection, {
	"setAllowance(profile, profile.data.allowance - price)",
	"profile.data.boomboxAutoplayPurchased = true",
	"markDirty(profile)",
	"feedback(profile.player, \"BoomboxAutoplayPurchased\"",
	"broadcastState()",
	"task.defer(saveProfile, profile.player, false)",
}, "Autoplay purchase must atomically debit, persist, notify, broadcast, then save")
lacks(autoplayPurchaseSection, "task.wait", "Atomic autoplay purchase path must not yield")

local reportSection = section(
	familySource,
	"local function reportPlayerAction(eventKey, player, metadata)",
	"local function adjustAllowance",
	"boombox delivery reports"
)
ordered(reportSection, {
	"if eventKey == \"BoomboxPlaybackFailed\"",
	"if not record then",
}, "Playback failures must be handled even when no chore is active")
for _, marker in ipairs({
	"BoomboxDeliverySpawned",
	"BoomboxCratePicked",
	"BoomboxPlaced",
	"BoomboxCarryLost",
	"profile.data.boomboxPlaced = true",
	"profile.boomboxDeliveryStep == \"Install\"",
}) do
	has(reportSection, marker, "Boombox delivery lifecycle is missing " .. marker)
end

local beginSection = section(
	familySource,
	"local function beginBoomboxPlayback(player, requestedSource)",
	"local function creditBoomboxTick",
	"begin playback"
)
for _, marker in ipairs({
	"local playbackSource = requestedSource == \"Autoplay\" and \"Autoplay\" or \"Manual\"",
	"local automatic = playbackSource == \"Autoplay\"",
	"automatic and profile.data.boomboxAutoplayPurchased ~= true",
	"The boombox autoplay upgrade is not installed.",
	"profile.data.boomboxPurchased",
	"profile.data.boomboxPlaced",
	"boomboxPlaybackOwner and boomboxPlaybackOwner ~= player",
	"profile.data.boomboxNextPlayAt - unixNow()",
	"boomboxSessionSerial += 1",
	"string.format(\"boombox:%d:%d:%d\"",
	"paidTicks = 0",
	"totalPaid = 0",
	"source = playbackSource",
	"boomboxPlaybackOwner = player",
	"if not automatic then",
}) do
	has(beginSection, marker, "BeginBoomboxPlayback is missing " .. marker)
end
ordered(beginSection, {
	"automatic and profile.data.boomboxAutoplayPurchased ~= true",
	"announceBoomboxReady(profile, automatic)",
	"profile.data.boomboxNextPlayAt = nextPlayAt",
	"profile.boomboxReadyNoticeKey = nil",
	"profile.boomboxPlayback = {",
	"source = playbackSource",
	"boomboxPlaybackOwner = player",
}, "Ready fallback, next-cycle latch reset, persistent cooldown, and session must commit before payout begins")
check(
	countPlain(beginSection, "if not automatic then") >= 3,
	"Automatic entitlement races must not spam manual missing-setup, occupied, or cooldown feedback"
)
check(
	countPlain(beginSection, "source = playbackSource") >= 3,
	"Playback source must be stored in the session and returned through feedback/result"
)
check(
	countPlain(beginSection, "announceBoomboxReady(profile, automatic)") == 1,
	"BeginBoomboxPlayback must have exactly one ready-event race fallback"
)

local tickSection = section(
	familySource,
	"local function boomboxPayoutTick(player, sessionId)",
	"local function endBoomboxPlayback(profile, sessionId, reason, suppressFeedback)",
	"payout tick"
)
for _, marker in ipairs({
	"playback.sessionId ~= sessionId",
	"boomboxPlaybackOwner ~= player",
	"playback.paidTicks >= Config.Boombox.MaximumPaidTicks",
	"(playback.paidTicks + 1) * Config.Boombox.PayoutInterval",
	"currentTime + BOOMBOX_TICK_EARLY_TOLERANCE < dueAt",
	"Config.Boombox.TrackDuration + BOOMBOX_FINAL_TICK_TOLERANCE",
}) do
	has(tickSection, marker, "Boombox payout authorization is missing " .. marker)
end
ordered(tickSection, {
	"playback.paidTicks >= Config.Boombox.MaximumPaidTicks",
	"currentTime + BOOMBOX_TICK_EARLY_TOLERANCE < dueAt",
	"local awarded = creditBoomboxTick(profile, playback)",
}, "Tick cap and timing checks must precede every award")
check(countPlain(tickSection, "creditBoomboxTick(profile, playback)") == 1, "One tick request can reach more than one credit call")

local endSection = section(
	familySource,
	"local function endBoomboxPlayback(profile, sessionId, reason, suppressFeedback)",
	"local function endBoomboxPlaybackForPlayer",
	"end playback"
)
for _, marker in ipairs({
	"playback.sessionId ~= sessionId",
	"endedReason == \"Completed\"",
	"playback.paidTicks == Config.Boombox.MaximumPaidTicks - 1",
	"Config.Boombox.TrackDuration - BOOMBOX_FINAL_TICK_TOLERANCE",
	"Config.Boombox.TrackDuration + BOOMBOX_FINAL_TICK_TOLERANCE",
	"profile.boomboxPlayback = nil",
	"boomboxPlaybackOwner = nil",
	"BoomboxFinished",
}) do
	has(endSection, marker, "EndBoomboxPlayback is missing " .. marker)
end
ordered(endSection, {
	"creditBoomboxTick(profile, playback)",
	"profile.boomboxPlayback = nil",
	"boomboxPlaybackOwner = nil",
}, "Completed-track final-tick race must settle before session cleanup")
check(countPlain(endSection, "creditBoomboxTick(profile, playback)") == 1, "Completed end path can apply more than one final-race credit")

local apiSection = section(
	familySource,
	"serverAPI.OnInvoke = function(operation, arg1, arg2, arg3, arg4)",
	"local function passRequestCooldown",
	"structured server API"
)
for _, operation in ipairs({ "BeginBoomboxPlayback", "BoomboxPayoutTick", "EndBoomboxPlayback" }) do
	has(apiSection, "operation == \"" .. operation .. "\"", "Structured API is missing " .. operation)
end
lacks(apiSection, "operation == \"OrderBoombox\"", "Ungated server API exposes boombox purchase")
lacks(apiSection, "operation == \"UpgradeBoomboxAutoplay\"", "Ungated server API exposes autoplay purchase")
has(
	apiSection,
	"return beginBoomboxPlayback(arg1, arg2)",
	"Structured API does not forward Manual/Autoplay source into authoritative playback"
)

local computerGateAt = string.find(familySource, "or action == \"OrderBoombox\"", 1, true)
local validSessionAt = computerGateAt and string.find(familySource, "and not validComputerSession(player)", computerGateAt, true) or nil
local remoteOrderAt = validSessionAt and string.find(familySource, "elseif action == \"OrderBoombox\"", validSessionAt, true) or nil
check(
	computerGateAt and validSessionAt and remoteOrderAt and computerGateAt < validSessionAt and validSessionAt < remoteOrderAt,
	"OrderBoombox does not pass the nearby trusted-computer session gate"
)
local autoplayComputerGateAt = string.find(familySource, "or action == \"UpgradeBoomboxAutoplay\"", 1, true)
local autoplayValidSessionAt = autoplayComputerGateAt
	and string.find(familySource, "and not validComputerSession(player)", autoplayComputerGateAt, true)
	or nil
local remoteAutoplayAt = autoplayValidSessionAt
	and string.find(familySource, "elseif action == \"UpgradeBoomboxAutoplay\"", autoplayValidSessionAt, true)
	or nil
check(
	autoplayComputerGateAt and autoplayValidSessionAt and remoteAutoplayAt
		and autoplayComputerGateAt < autoplayValidSessionAt
		and autoplayValidSessionAt < remoteAutoplayAt,
	"UpgradeBoomboxAutoplay does not pass the nearby trusted-computer session gate"
)

for _, marker in ipairs({
	"local activeBoomboxSession = nil",
	"local boomboxActivationInProgress = false",
	"local autoplayRetryAt = {}",
	"local lastAutoplayUserId = 0",
	"current.boombox.canPlay ~= true",
	"local function anyPlacedBoomboxOwner()",
	"CooperBoomboxPlaced",
	"ContentProvider:PreloadAsync({ boomboxSound })",
	"LoadedAudioDuration",
	"BoomboxPlaybackFailed",
	"invokeFamily(\"BeginBoomboxPlayback\", player, source)",
	"invokeFamily(\"BoomboxPayoutTick\", session.player, session.sessionId)",
	"invokeFamily(\"EndBoomboxPlayback\", session.player, session.sessionId, reason)",
	"boomboxSound.Ended:Connect",
	"finishBoomboxPlayback(session, \"Completed\", false)",
	"finishBoomboxPlayback(session, \"Interrupted\", false)",
	"finishBoomboxPlayback(session, \"Watchdog\", true)",
	"finishBoomboxPlayback(activeBoomboxSession, \"PlayerLeft\", true)",
	"Delivery_Boombox_",
	"BoomboxDeliverySpawned",
	"BoomboxCratePicked",
	"BoomboxPlaced",
	"BoomboxCarryLost",
}) do
	has(taskWorldSource, marker, "TaskWorld is missing boombox marker " .. marker)
end
has(taskWorldSource, "descendant:IsA(\"SurfaceGui\")", "Hidden truck does not explicitly clean up its sign GUI")
for _, marker in ipairs({ "globallyPlaying", "occupiedByOther", "playbackOwnerUserId" }) do
	has(familySource, marker, "Family snapshots are missing global boombox occupancy marker " .. marker)
end
for _, forbidden in ipairs({ "AdjustCurrency", "SpendAllowance", "setAllowance(", "allowance.Value" }) do
	lacks(taskWorldSource, forbidden, "TaskWorld directly changes money through " .. forbidden)
end

local taskPayoutSection = section(
	taskWorldSource,
	"local function runBoomboxPayouts(session)",
	"finishBoomboxPlayback = function(session, reason, stopSound)",
	"TaskWorld payout scheduler"
)
for _, marker in ipairs({
	"for tickIndex = 1, session.maxTicks do",
	"session.startedAt + tickIndex * session.interval + 0.035",
	"activeBoomboxSession == session",
	"not boomboxSound.Playing",
	"retryAfter > 0 and retryAfter <= 0.35",
}) do
	has(taskPayoutSection, marker, "TaskWorld payout scheduler is missing " .. marker)
end
check(countPlain(taskPayoutSection, "BoomboxPayoutTick") == 2, "TaskWorld must make one scheduled tick call and at most one short retry")

local discoTimingSection = section(
	taskWorldSource,
	"local function animateDisco(session)",
	"local audioDurationWarningIssued = false",
	"TaskWorld beat-synchronized lights"
)
for _, marker in ipairs({
	"Config.Boombox and Config.Boombox.DanceBPM",
	"Config.Boombox and Config.Boombox.DanceBeatOffsetSeconds",
	"boomboxSound.TimePosition",
	"local beatPeriod = 60 / bpm",
	"local beatPulse = math.exp(-beatPhase * 4.8)",
	"metadata.light.Brightness = metadata.brightness * (0.88 + 0.30 * beatPulse)",
	"math.clamp(metadata.playingTransparency + 0.08 - 0.16 * beatPulse, 0.35, 0.72)",
}) do
	has(discoTimingSection, marker, "Pronounced beat-synchronized disco is missing " .. marker)
end

local taskFinishSection = section(
	taskWorldSource,
	"finishBoomboxPlayback = function(session, reason, stopSound)",
	"local function startBoomboxPlayback(player, automatic)",
	"TaskWorld finish"
)
for _, marker in ipairs({
	"activeBoomboxSession ~= session",
	"boomboxSound:Stop()",
	"setDiscoActive(false)",
	"PlaybackSession",
	"PlaybackOwnerUserId",
}) do
	has(taskFinishSection, marker, "TaskWorld finish path is missing " .. marker)
end
ordered(taskFinishSection, {
	"activeBoomboxSession = nil",
	"setDiscoActive(false)",
	"invokeFamily(\"EndBoomboxPlayback\", session.player, session.sessionId, reason)",
	"refreshBoomboxVisibility()",
}, "TaskWorld must release the lock, darken, end, then refresh")

local taskStartSection = section(
	taskWorldSource,
	"local function startBoomboxPlayback(player, automatic)",
	"boomboxSound.Ended:Connect",
	"TaskWorld start"
)
for _, marker in ipairs({
	"automatic = automatic == true",
	"activeBoomboxSession or boomboxActivationInProgress",
	"current.boombox.placed ~= true",
	"automatic and current.boombox.autoplayPurchased ~= true",
	"local source = automatic and \"Autoplay\" or \"Manual\"",
	"ensureBoomboxAudioLoaded(preloadTimeout)",
	"audio permission",
	"boomboxSound.TimePosition = 0",
	"if not boomboxSound.Playing then",
	"sessionId = beginResult.sessionId",
	"maxTicks = math.clamp",
}) do
	has(taskStartSection, marker, "TaskWorld start path is missing " .. marker)
end
ordered(taskStartSection, {
	"ensureBoomboxAudioLoaded(preloadTimeout)",
	"boomboxSound:Play()",
	"invokeFamily(\"BeginBoomboxPlayback\", player, source)",
	"activeBoomboxSession = session",
	"setDiscoActive(true)",
	"runBoomboxPayouts(session)",
}, "TaskWorld must load/play/authorize/lock/light/schedule in order")
has(taskStartSection, "boomboxSound:Stop()", "Rejected begin authorization does not stop the Sound")
has(
	taskStartSection,
	"The boombox is cooling down. Ready in \" .. formatCountdown(remaining) .. \".",
	"Manual cooldown rejection does not report the exact M:SS remaining time"
)

local autoplaySchedulerSection = section(
	taskWorldSource,
	"-- Autoplay is online-only and reuses the exact manual Sound/session/payout",
	"local function weldToHandle(handle, item)",
	"TaskWorld autoplay scheduler"
)
for _, marker in ipairs({
	"not activeBoomboxSession and not boomboxActivationInProgress",
	"autoplayRetryAt[candidate]",
	"boombox.placed == true",
	"boombox.autoplayPurchased == true",
	"boombox.canPlay == true",
	"table.sort(candidates",
	"left.UserId < right.UserId",
	"candidate.UserId > lastAutoplayUserId",
	"lastAutoplayUserId = selected.UserId",
	"autoplayRetryAt[selected] = now + 20",
	"startBoomboxPlayback(selected, true)",
}) do
	has(autoplaySchedulerSection, marker, "TaskWorld autoplay fairness/retry scheduler is missing " .. marker)
end
check(
	countPlain(taskWorldSource, "local function startBoomboxPlayback") == 1
		and countPlain(autoplaySchedulerSection, "startBoomboxPlayback(selected, true)") == 1,
	"Autoplay must reuse the single manual Sound/session/payout start function"
)

local promptSection = section(
	taskWorldSource,
	"ProximityPromptService.PromptTriggered:Connect(function(prompt, player)",
	"Players.PlayerAdded:Connect(watchPlayer)",
	"TaskWorld prompt authorization"
)
ordered(promptSection, {
	"prompt:IsDescendantOf(world)",
	"passCooldown(player, action, 0.45)",
	"near(player, prompt.Parent, prompt.MaxActivationDistance + 3)",
	"action == \"DeliveryPickup\"",
	"action == \"BoomboxSetup\"",
	"action == \"BoomboxPower\"",
}, "All delivery/setup/power actions must pass the common server proximity gate")
for _, marker in ipairs({
	"tool:GetAttribute(\"OwnerUserId\") ~= player.UserId",
	"recordForTool(tool)",
	"deliveryRecord.player ~= player",
	"deliveryRecord.status ~= \"World\"",
	"tryPlaceBoombox(player, false)",
	"startBoomboxPlayback(player)",
}) do
	has(promptSection, marker, "TaskWorld prompt ownership/lifecycle check is missing " .. marker)
end

local automaticSetupSection = section(
	taskWorldSource,
	"local function insideBoomboxAutoSetupArea(player)",
	"local function createTrashBag(player)",
	"TaskWorld automatic boombox setup"
)
for _, marker in ipairs({
	"BOOMBOX_AUTO_SETUP_RADIUS",
	"formalLivingCarpet.CFrame:PointToObjectSpace",
	"deliveryRecordsByKey[deliveryKey(player.UserId, \"Boombox\")]",
	"record.player ~= player",
	"record.kind ~= \"Boombox\"",
	"record.status ~= \"Carried\"",
	"record.consumed",
	"tool.Parent == player.Character or tool.Parent == backpack",
	"tool:GetAttribute(\"OwnerUserId\") ~= player.UserId",
	"current.delivery.kind ~= \"Boombox\"",
	"current.delivery.status ~= \"Setup\" and current.delivery.status ~= \"Install\"",
	"invokeFamily(\"ReportAction\", player, \"BoomboxPlaced\", {})",
	"tryPlaceBoombox(candidate, true)",
}) do
	has(automaticSetupSection, marker, "Automatic boombox setup is missing " .. marker)
end
ordered(automaticSetupSection, {
	"invokeFamily(\"ReportAction\", player, \"BoomboxPlaced\", {})",
	"clearDeliveryRecord(record, false)",
	"tool:Destroy()",
}, "Automatic setup must confirm placement before consuming the delivered crate")
has(taskWorldSource, "tool:GetAttribute(\"DeliveryId\")", "Delivery records are not bound to unforgeable server delivery ids")
has(taskWorldSource, "deliveryRecordsByKey[record.key] ~= record", "Delivery record is not cross-checked against its owner/kind key")

ordered(taskWorldSource, {
	"setTruckVisible(false)",
	"refreshBoomboxVisibility()",
	"world:SetAttribute(\"ControllerReady\", true)",
}, "TaskWorld initial state must hide the truck, resolve boombox visibility, then advertise ready")

for _, marker in ipairs({
	"Buy / Upgrade Party Boombox",
	"showPage(\"Boombox\")",
	"requestEvent:FireServer(\"OrderBoombox\")",
	"requestEvent:FireServer(\"UpgradeBoomboxAutoplay\")",
	"AUTOPLAY UPGRADE: $%d",
	"AUTOPLAY: INSTALLED / ARMED",
	"boomboxCooldownRemaining",
	"boombox.nextPlayAt",
	"snapshot.serverUnixTime",
	"boombox.occupiedByOther == true",
	"boombox.ownsPlayback == true",
	"return \"Busy\"",
	"your allowance is not earning",
	"maximumPayout",
	"Delivered by truck. Set it up in the living room.",
	"PLACE BOOMBOX HERE",
	"Follow the purple arrow into the living room",
	"delivery.targetHint",
	"workspace:FindFirstChild(hint, true)",
	"configure(\"BoomboxSetupAnchor\"",
	"configure(\"BoomboxPowerAnchor\"",
	"BoomboxPurchased",
	"BoomboxPlaced",
	"BoomboxReady",
	"BoomboxStarted",
	"BoomboxFinished",
	"BoomboxAutoplayPurchased",
	"BOOMBOX AUTOPLAY INSTALLED",
	"BoomboxError",
}) do
	has(clientSource, marker, "Client is missing boombox UI/guidance marker " .. marker)
end

-- Cooldown readiness is server-authored and latched per persisted deadline.
-- This keeps manual and autoplay presentation identical while preventing the
-- half-second autoplay scheduler from racing past the one-time message.
local readyAnnouncementSection = section(
	familySource,
	"local function announceBoomboxReady(profile, automatic)",
	"local function beginBoomboxPlayback(player, requestedSource)",
	"server boombox-ready announcement"
)
for _, marker in ipairs({
	"not profile.data.boomboxPurchased",
	"not profile.data.boomboxPlaced",
	"profile.boomboxPlayback",
	"profile.data.boomboxNextPlayAt",
	"unixNow() < readyAt",
	"profile.boomboxReadyNoticeKey == readyAt",
	"profile.boomboxReadyNoticeKey = readyAt",
	"feedback(profile.player, \"BoomboxReady\"",
	"automatic = automatic == true",
	"source = automatic == true and \"Autoplay\" or \"Manual\"",
}) do
	has(readyAnnouncementSection, marker, "Server ready-cycle announcement is missing " .. marker)
end
ordered(readyAnnouncementSection, {
	"unixNow() < readyAt",
	"profile.boomboxReadyNoticeKey == readyAt",
	"profile.boomboxReadyNoticeKey = readyAt",
	"feedback(profile.player, \"BoomboxReady\"",
}, "Ready-cycle key must be validated and committed before client feedback")
lacks(readyAnnouncementSection, "markDirty", "Transient boombox-ready latch must not dirty persistent profile data")
lacks(readyAnnouncementSection, "saveProfile", "Transient boombox-ready latch must not trigger a profile write")
lacks(readyAnnouncementSection, "task.wait", "Boombox-ready deduplication must not yield between latch and feedback")
check(
	countPlain(familySource, "feedback(profile.player, \"BoomboxReady\"") == 1,
	"Exactly one authoritative server function may emit BoomboxReady"
)
local profileConstructionSection = section(
	familySource,
	"local function loadPlayer(player)",
	"profiles[player] = profile",
	"player profile construction"
)
has(
	profileConstructionSection,
	"boomboxReadyNoticeKey = nil",
	"Player profiles do not initialize the transient boombox-ready cycle latch"
)
local readyMonitorSection = section(
	familySource,
	"task.spawn(function()\n\tlocal nextAutoSave",
	"\n\nbroadcastState()",
	"server boombox-ready monitor"
)
ordered(readyMonitorSection, {
	"profile.loaded",
	"not profile.boomboxPlayback",
	"profile.data.boomboxPurchased",
	"profile.data.boomboxPlaced",
	"profile.data.boomboxNextPlayAt > 0",
	"unixNow() >= profile.data.boomboxNextPlayAt",
	"announceBoomboxReady(profile, profile.data.boomboxAutoplayPurchased == true)",
}, "Server loop does not announce each eligible manual/autoplay cooldown transition")
check(
	countPlain(familySource, "announceBoomboxReady(profile,") == 3,
	"BoomboxReady must have one definition plus only the cooldown monitor and begin-playback race fallback"
)

-- Ready feedback has a dedicated HUD slot. It must use one fixed title for
-- manual and autoplay readiness, remain independent of the shared activity
-- toast, and stay below the interactive computer modal's ZIndex 60 workspace.
local readyNoticeSource = section(
	clientSource,
	"-- Cooldown readiness has a dedicated slot",
	"-- Button-driven Cooper computer",
	"client boombox-ready notice"
)
for _, marker in ipairs({
	'upgradeNoticeUi.readyFrame.Name = "BoomboxReadyNotice"',
	"upgradeNoticeUi.readyFrame.Parent = scaleRoot",
	"upgradeNoticeUi.readyFrame.ZIndex = 52",
	"upgradeNoticeUi.readyTitle.ZIndex = 53",
	"upgradeNoticeUi.readyText.ZIndex = 53",
	"function upgradeNoticeUi.showBoomboxReady(automatic, detailText)",
	'upgradeNoticeUi.readyTitle.Text = "BOOMBOX READY TO PLAY!"',
	"automatic == true",
	"upgradeNoticeUi.readyFrame.Visible = true",
	"upgradeNoticeUi.readyToken += 1",
}) do
	has(readyNoticeSource, marker, "Dedicated boombox-ready notice is missing " .. marker)
end
check(
	countPlain(readyNoticeSource, '"BOOMBOX READY TO PLAY!"') == 2,
	"Manual and autoplay readiness must share one fixed BOOMBOX READY TO PLAY title"
)
lacks(readyNoticeSource, "showToast(", "Boombox readiness still borrows the overwrite-prone activity toast")

local feedbackClientSection = section(
	clientSource,
	"feedbackEvent.OnClientEvent:Connect(function(packet)",
	"UserInputService.InputBegan:Connect(function(input)",
	"client feedback router"
)
ordered(feedbackClientSection, {
	'elseif kind == "BoomboxPlaced" then',
	"upgradeNoticeUi.showBoomboxReady(false",
	'elseif kind == "BoomboxReady" then',
	"upgradeNoticeUi.showBoomboxReady(packet.automatic == true, packet.text)",
	'elseif kind == "BoomboxStarted" then',
	'if tostring(packet.source or "") == "Autoplay" then',
	"upgradeNoticeUi.showBoomboxReady(true",
}, "Client does not preserve the same dedicated ready notice for placement, manual cooldown, and autoplay race fallback")
check(
	countPlain(feedbackClientSection, "upgradeNoticeUi.showBoomboxReady(") == 3,
	"Client ready notice must have exactly placement, authoritative-ready, and autoplay-start fallback call sites"
)

-- The independent affordability banner consumes only server-authored snapshot
-- prices and eligibility. Base ownership retires the boombox candidate; the
-- autoplay candidate is not eligible until that boombox is both owned and
-- placed, and permanent autoplay ownership retires it in turn.
local noticeUpdateSource = section(
	clientSource,
	"function upgradeNoticeUi.update(snapshot)",
	"local function taskIsAutomated",
	"Upgrade-affordability snapshot update"
)
ordered(noticeUpdateSource, {
	"local boombox = type(snapshot.boombox) == \"table\" and snapshot.boombox or {}",
	'"Boombox",',
	'"Cooper Party Boombox",',
	"boombox.price",
	"boombox.purchased == true",
	"boombox.canOrder == true",
	'"BoomboxAutoplay",',
	'"Boombox Autoplay",',
	"boombox.autoplayPrice",
	"boombox.autoplayPurchased == true",
	"boombox.purchased == true",
	"and boombox.placed == true",
	"and boombox.canUpgradeAutoplay == true",
	"upgradeNoticeUi.show(newlyAffordable)",
}, "Boombox affordability candidates do not follow authoritative ownership/purchase gates")
check(
	countPlain(noticeUpdateSource, '"Boombox",') == 1
		and countPlain(noticeUpdateSource, '"BoomboxAutoplay",') == 1,
	"Base boombox and autoplay must each have exactly one affordability candidate"
)
lacks(noticeUpdateSource, "Config.Boombox", "Boombox affordability must not trust a client-side configured price")
local affordabilityApplySource = section(
	clientSource,
	"local function applySnapshot(snapshot)",
	"snapshotEvent.OnClientEvent",
	"Snapshot-driven affordability update"
)
has(affordabilityApplySource, "upgradeNoticeUi.update(snapshot)", "Boombox affordability does not refresh from authoritative snapshots")

-- BOOMBOX AUTOPLAY is deliberately duplicated on the task-robots page while the
-- party-boombox page retains the same upgrade. Both views must derive price/state from
-- the same snapshot and only construct a clickable file in the fully eligible,
-- affordable branch.
local automationTerminalSource = section(
	clientSource,
	'elseif terminalPage == "Automation" then',
	'elseif terminalPage == "Boombox" then',
	"Task-robots terminal page"
)
for _, marker in ipairs({
	'local boombox = type(snapshot.boombox) == "table" and snapshot.boombox or {}',
	"tonumber(boombox.autoplayPrice)",
	'boombox.autoplayPurchased == true',
	'boombox.purchased ~= true',
	'boombox.placed ~= true',
	'allowance < autoplayPrice',
	'boombox.canUpgradeAutoplay ~= true',
	'BOOMBOX AUTOPLAY',
	'BUY BOOMBOX FIRST',
	'SET UP BOOMBOX FIRST',
	'TEMPORARILY UNAVAILABLE',
}) do
	has(automationTerminalSource, marker, "Task-robots autoplay duplicate is missing " .. marker)
end
local automationAutoplayDecision = section(
	clientSource,
	"if boombox.autoplayPurchased ~= true\n",
	'\n\telseif terminalPage == "Boombox" then',
	"Task-robots autoplay purchase decision"
)
ordered(automationAutoplayDecision, {
	"boombox.autoplayPurchased ~= true",
	"and boombox.purchased == true",
	"and boombox.placed == true",
	"and boombox.canUpgradeAutoplay == true",
	"and allowance >= autoplayPrice",
	'treeFile("", false,',
	'"Buy Boombox Autoplay — $"',
	'requestEvent:FireServer("UpgradeBoomboxAutoplay")',
}, "Task-robots page exposes autoplay purchase outside its authoritative eligibility/allowance gate")
check(
	countPlain(automationAutoplayDecision, "treeFile(") == 1
		and countPlain(automationAutoplayDecision, 'requestEvent:FireServer("UpgradeBoomboxAutoplay")') == 1,
	"Task-robots autoplay block must contain exactly one gated clickable purchase path"
)

local boomboxTerminalSource = section(
	clientSource,
	'elseif terminalPage == "Boombox" then',
	'elseif terminalPage == "SecretBunker" then',
	"Party-boombox terminal page"
)
local boomboxAutoplayDecision = section(
	clientSource,
	"if boombox.placed == true then",
	'elseif terminalPage == "SecretBunker" then',
	"Party-boombox autoplay purchase decision"
)
ordered(boomboxAutoplayDecision, {
	"if boombox.canUpgradeAutoplay == true and allowance >= autoplayPrice then",
	'treeFile("", false,',
	'"Buy Boombox Autoplay — $%d"',
	'requestEvent:FireServer("UpgradeBoomboxAutoplay")',
	"elseif allowance < autoplayPrice then",
	'NEED $" .. tostring(autoplayPrice - allowance) .. " MORE',
	"else",
	"UPGRADE TEMPORARILY UNAVAILABLE",
}, "Party-boombox page must render insufficient/blocked autoplay states as non-clickable lines")
check(
	countPlain(boomboxAutoplayDecision, "treeFile(") == 1
		and countPlain(boomboxAutoplayDecision, 'requestEvent:FireServer("UpgradeBoomboxAutoplay")') == 1,
	"Party-boombox autoplay block must contain exactly one gated clickable purchase path"
)

local clientPromptSection = section(
	clientSource,
	"local function updateWorldPrompts(snapshot)",
	"-- Task stations can stream in after the snapshot",
	"Client prompt lifecycle"
)
for _, marker in ipairs({
	"local cooldown = boomboxCooldownRemaining(snapshot)",
	"local boomboxApproachable = boombox.purchased == true",
	"and boombox.placed == true",
	"and not boomboxIsPlaying(boombox)",
	"Cooldown - Ready in \" .. formatCountdown(cooldown)",
	"configure(\"BoomboxPowerAnchor\", boomboxApproachable, powerText)",
}) do
	has(clientPromptSection, marker, "Cooldown-visible power prompt is missing " .. marker)
end
lacks(
	clientPromptSection,
	"and cooldown <= 0",
	"Client disables the power prompt during cooldown instead of exposing the exact countdown"
)

local clientDanceSection = section(
	clientSource,
	"-- The server owns formation and restoration; each client animates the four",
	"local pendingBoomboxIncome = 0",
	"Client NPC beat animation"
)
for _, marker in ipairs({
	"local danceRoster = { \"George\", \"Mary\", \"Missy\", \"Georgie\" }",
	"Config.Boombox.DanceBPM",
	"Config.Boombox.DanceBeatOffsetSeconds",
	"Config.Boombox.DanceJumpHeight",
	"sound.TimePosition",
	"model:GetAttribute(\"BoomboxDancing\") == true",
	"local firstPair = name == \"George\" or name == \"Missy\"",
	"(beatIndex % 2 == 0) == firstPair",
	"math.sin(math.pi * beatPhase) * danceJumpHeight",
	"restoreDanceVisual(model)",
}) do
	has(clientDanceSection, marker, "Client beat-matched alternating dance is missing " .. marker)
end
for _, marker in ipairs({
	"FindFirstChild(\"CooperIncomeBoombox\", true)",
	"boombox:GetAttributeChangedSignal(\"Playing\"):Connect(refreshMix)",
	"if boomboxPlaying then 0 elseif dialoguePlaying then DIALOGUE_VOLUME else NORMAL_VOLUME",
}) do
	has(backgroundMusicSource, marker, "Background music does not duck cleanly for the boombox: " .. marker)
end
local guideSection = section(
	clientSource,
	"local function guideForSnapshot(snapshot)",
	"local function updateArrow(snapshot)",
	"Client boombox guidance priority"
)
ordered(guideSection, {
	"tostring(delivery.kind or \"\") == \"Boombox\"",
	"return delivery.targetHint, \"PLACE BOOMBOX HERE\", COLORS.purple",
	"taskData.id == \"GeorgeBeer\"",
}, "Carried boombox guidance does not override George's opening-task arrow")

local allowedClientRequests = {
	TutorialSeen = true,
	CloseComputer = true,
	OrderBeer = true,
	OrderMachinePart = true,
	OrderBoombox = true,
	OrderSecretBunker = true,
	OrderTaskUpgrade = true,
	UpgradeBoomboxAutoplay = true,
	LegacyCommand = true,
	HiddenSeen = true,
	RequestSnapshot = true,
}
local parsedClientRequests = 0
for action in string.gmatch(clientSource, 'requestEvent:FireServer%("([^"]+)"') do
	parsedClientRequests += 1
	check(allowedClientRequests[action] == true, "Client can send unapproved request action " .. tostring(action))
end
check(parsedClientRequests == countPlain(clientSource, "requestEvent:FireServer("), "Client contains a dynamic/unreviewed Request remote path")
check(countPlain(clientSource, "requestEvent:FireServer(\"OrderBoombox\")") == 1, "Client should expose exactly one boombox purchase request")
check(countPlain(clientSource, "requestEvent:FireServer(\"OrderTaskUpgrade\"") == 1, "Client should expose exactly one task-automation purchase request")
check(
	countPlain(clientSource, "requestEvent:FireServer(\"UpgradeBoomboxAutoplay\")") == 2,
	"Client should expose exactly the party-boombox and task-robots autoplay purchase requests"
)

for _, forbidden in ipairs({
	"BeginBoomboxPlayback",
	"BoomboxPayoutTick",
	"EndBoomboxPlayback",
	"AdjustCurrency",
	"SpendAllowance",
	"setAllowance(",
	"allowance.Value =",
	"leaderstats.Allowance",
	"requestEvent:FireServer(\"BoomboxIncome\"",
	"requestEvent:FireServer(\"BoomboxTick\"",
	"requestEvent:FireServer(\"Award",
	"Instance.new(\"Sound\")",
	"SetAttribute(\"CooperBoomboxPlaced\"",
}) do
	lacks(clientSource, forbidden, "Client contains a forbidden money/playback authority path: " .. forbidden)
end

-- Delivery target names are produced by the server/TaskWorld and consumed as
-- opaque snapshot hints by the client. This prevents three drifting name maps.
has(familySource, "\"Delivery_Boombox_\" .. tostring(profile.player.UserId)", "Family snapshots use the wrong boombox delivery target")
has(taskWorldSource, "\"Delivery_Boombox_\" .. tostring(player.UserId)", "TaskWorld creates the wrong boombox delivery target")
has(familySource, "then \"BoomboxSetupAnchor\"", "Family snapshot uses the wrong setup target")
has(clientSource, "return delivery.targetHint, title, color", "Client does not consume the authoritative delivery target hint")

for _, retiredDependency in ipairs({ "PanicActive", "CooperCrisis", "CooperProgression" }) do
	lacks(familySource, retiredDependency, "Family server unexpectedly depends on " .. retiredDependency)
	lacks(taskWorldSource, retiredDependency, "TaskWorld unexpectedly depends on " .. retiredDependency)
	lacks(clientSource, retiredDependency, "Family client unexpectedly depends on " .. retiredDependency)
end

if running then
	check(type(state:GetAttribute("TaskRevision")) == "number", "Play-mode shared state has no task revision")
	check(type(state:GetAttribute("ServerTime")) == "number", "Play-mode shared state has no server clock")
end

print(string.format(
	"[BoomboxAudit] PASS: %d non-mutating checks in %s mode; $%d boombox, $%d autoplay, $%d/song cap, %d visual parts, %d lights",
	checks,
	running and "play" or "edit",
	boomboxConfig.Price,
	boomboxConfig.AutoplayUpgradePrice,
	maximumPayout,
	#physicalParts + #effectParts,
	#lights
))
return true
