--!nonstrict
-- High-signal edit/runtime spatial and collision audit for the retained game.
-- This intentionally checks relationships instead of old absolute coordinates,
-- so moving the complete house cannot silently detach doors, tasks, or effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function need(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	assert(item, string.format("Missing %s.%s", parent and parent:GetFullName() or "nil", name))
	if className then
		assert(item:IsA(className), item:GetFullName() .. " must be a " .. className)
	end
	return item
end

local function worldFind(parent, name, className)
	local item = parent and parent:FindFirstChild(name, true)
	assert(item, "Missing descendant " .. name)
	if className then
		assert(item:IsA(className), item:GetFullName() .. " must be a " .. className)
	end
	return item
end

local function cframeClose(a, b, positionTolerance, angleTolerance)
	if typeof(a) ~= "CFrame" or typeof(b) ~= "CFrame" then
		return false
	end
	if (a.Position - b.Position).Magnitude > (positionTolerance or 0.05) then
		return false
	end
	local _, angle = a:ToObjectSpace(b):ToAxisAngle()
	return math.abs(angle) <= math.rad(angleTolerance or 1)
end

local function modelOrPartBounds(item)
	if item:IsA("Model") then
		return item:GetBoundingBox()
	end
	assert(item:IsA("BasePart"), item:GetFullName() .. " has no physical bounds")
	return item.CFrame, item.Size
end

local function boundsOverlap(a, b)
	local aCF, aSize = modelOrPartBounds(a)
	local bCF, bSize = modelOrPartBounds(b)
	local delta = aCF.Position - bCF.Position
	return math.abs(delta.X) < (aSize.X + bSize.X) * 0.5
		and math.abs(delta.Y) < (aSize.Y + bSize.Y) * 0.5
		and math.abs(delta.Z) < (aSize.Z + bSize.Z) * 0.5
end

local function insidePartXZ(container, itemCF, itemSize, margin)
	margin = margin or 0
	for xSign = -1, 1, 2 do
		for zSign = -1, 1, 2 do
			local corner = itemCF:PointToWorldSpace(Vector3.new(
				xSign * itemSize.X * 0.5,
				0,
				zSign * itemSize.Z * 0.5
			))
			local localCorner = container.CFrame:PointToObjectSpace(corner)
			if math.abs(localCorner.X) > container.Size.X * 0.5 - margin
				or math.abs(localCorner.Z) > container.Size.Z * 0.5 - margin
			then
				return false
			end
		end
	end
	return true
end

local function partBoundsInFrame(part, frame)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for xSign = -1, 1, 2 do
		for ySign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(
					xSign * part.Size.X * 0.5,
					ySign * part.Size.Y * 0.5,
					zSign * part.Size.Z * 0.5
				))
				local localCorner = frame:PointToObjectSpace(corner)
				minimum = Vector3.new(
					math.min(minimum.X, localCorner.X),
					math.min(minimum.Y, localCorner.Y),
					math.min(minimum.Z, localCorner.Z)
				)
				maximum = Vector3.new(
					math.max(maximum.X, localCorner.X),
					math.max(maximum.Y, localCorner.Y),
					math.max(maximum.Z, localCorner.Z)
				)
			end
		end
	end
	return minimum, maximum
end

local environment = need(Workspace, "CooperHouseEnvironment", "Model")
local site = need(environment, "SiteAndStreet", "Model")
local cooperLot = need(site, "CooperLot", "BasePart")
local house = need(environment, "CooperHouse", "Model")
local structure = need(house, "Structure", "Model")
local rooms = need(house, "InteriorRooms", "Model")
local furniture = need(house, "FurnitureAndProps", "Model")
local garage = need(environment, "DetachedGarage", "Model")
local gameRoot = need(ReplicatedStorage, "CooperGame", "Folder")
local Config = require(need(gameRoot, "Config", "ModuleScript"))
local taskWorld = need(environment, Config.WorldRootName, "Model")
local stations = need(taskWorld, "Stations", "Folder")
local visuals = need(taskWorld, "TaskVisuals", "Folder")
local hidden = need(taskWorld, "HiddenLocations", "Folder")

-- Normal Play and every respawn must start on the movable front walk, not on
-- the old absolute baseplate location underneath the elevated house.
local enabledSpawns = {}
for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("SpawnLocation") and descendant.Enabled then
		table.insert(enabledSpawns, descendant)
	end
end
assert(#enabledSpawns == 1, "Exactly one enabled SpawnLocation is required")
local spawnLocation = enabledSpawns[1]
assert(spawnLocation:IsDescendantOf(site), "SpawnLocation is not mounted under the movable site")
assert(spawnLocation.Anchored and spawnLocation.CanCollide, "SpawnLocation is not stable/collidable")
assert(spawnLocation.Neutral and spawnLocation.Duration == 0, "SpawnLocation team/force-field settings changed")
assert(
	spawnLocation:GetAttribute("CooperSpawnRepairVersion") == "2026-07-17.1",
	"SpawnLocation relocation repair is stale"
)
assert(insidePartXZ(cooperLot, spawnLocation.CFrame, spawnLocation.Size, 0.25), "SpawnLocation is outside CooperLot")
local spawnSupportParams = RaycastParams.new()
spawnSupportParams.FilterType = Enum.RaycastFilterType.Exclude
spawnSupportParams.FilterDescendantsInstances = { spawnLocation }
pcall(function()
	spawnSupportParams.RespectCanCollide = true
end)
for _, localCorner in ipairs({
	Vector3.new(-2.4, -spawnLocation.Size.Y * 0.5 + 0.1, -2.4),
	Vector3.new(-2.4, -spawnLocation.Size.Y * 0.5 + 0.1, 2.4),
	Vector3.new(2.4, -spawnLocation.Size.Y * 0.5 + 0.1, -2.4),
	Vector3.new(2.4, -spawnLocation.Size.Y * 0.5 + 0.1, 2.4),
}) do
	local corner = spawnLocation.CFrame:PointToWorldSpace(localCorner)
	local support = Workspace:Raycast(
		corner + cooperLot.CFrame.UpVector * 0.25,
		-cooperLot.CFrame.UpVector * 3,
		spawnSupportParams
	)
	assert(support and support.Instance:IsA("BasePart"), "SpawnLocation has an unsupported corner")
	assert(support.Instance.CanCollide and support.Instance.Anchored, "SpawnLocation support is unsafe")
	assert(
		support.Instance:IsDescendantOf(environment) and support.Instance.Name ~= "Baseplate",
		"SpawnLocation is supported by the under-map baseplate instead of the game world"
	)
end
local spawnSafety = need(ServerScriptService, "CooperSpawnSafety", "Script")
for _, marker in ipairs({
	"lotSurfaceY - 8",
	"insideLegitimateBunkerSpace",
	"for _ = 1, 20 do",
	"spawnLocation.CFrame * CFrame.new(0, 4, 0)",
}) do
	assert(string.find(spawnSafety.Source, marker, 1, true), "Spawn safety is missing " .. marker)
end

assert(taskWorld:GetAttribute("InstallVersion") == "2026-07-21.hackerbot.1", "Family task world spatial version is stale")
assert(taskWorld:GetAttribute("StationCount") == 13 and #stations:GetChildren() == 13, "Exactly thirteen task/economy/boombox/automation stations are required")
for stationName, action in pairs({
	DishesPromptAnchor = "Dishes",
	TrashPickupAnchor = "TrashPickup",
	OutdoorTrashAnchor = "TrashDrop",
	MissyPlushReturnAnchor = "MissyReturn",
	GeorgeBeerDropAnchor = "BeerDrop",
	MachineInstallBay = "MachineInstall",
	BoomboxSetupAnchor = "BoomboxSetup",
	BoomboxPowerAnchor = "BoomboxPower",
	BeerBotInstallAnchor = "TaskUpgradeInstall",
	DishBotInstallAnchor = "TaskUpgradeInstall",
	TrashBotInstallAnchor = "TaskUpgradeInstall",
	ToyFinderInstallAnchor = "TaskUpgradeInstall",
	HackerBotInstallAnchor = "TaskUpgradeInstall",
}) do
	local prompt = need(need(stations, stationName, "BasePart"), "TaskPrompt", "ProximityPrompt")
	assert(prompt:GetAttribute("FamilyTaskAction") == action, stationName .. " has the wrong spatial action")
end

-- The retained onboarding is exact and deterministic.
local exactOrder = { "GeorgeBeer", "MaryDishes", "MaryTrash", "MissyPlush", "MedfordBankHack" }
assert(#Config.Tasks == 5 and #Config.TaskOrder == 5, "Exactly five family tasks must remain")
for index, id in ipairs(exactOrder) do
	assert(Config.Tasks[index].id == id, "Task definition order changed at " .. index)
	assert(Config.TaskOrder[index] == id, "Runtime task order changed at " .. index)
end
assert(Config.Tasks[1].startTarget == "Keyboard", "The first task must point to Sheldon's computer")

-- The six place settings and serving bowl must be supported by the dining
-- table in every axis. These checks use each rotated part's complete OBB so a
-- cylinder cannot pass merely because its center happens to be over the top.
do
	local diningTable = worldFind(furniture, "CooperDiningTable", "Model")
	local tableTop = need(diningTable, "Top", "BasePart")
	assert(diningTable:GetAttribute("TabletopPropsGrounded") == true, "Dining tabletop repair did not complete")
	assert(diningTable:GetAttribute("TabletopRepairVersion") == "2026-07-13.1", "Dining tabletop repair version is stale")
	local surfaceY = tableTop.Size.Y * 0.5
	local halfX = tableTop.Size.X * 0.5
	local halfZ = tableTop.Size.Z * 0.5
	local contactTolerance = 0.006
	local footprintTolerance = 0.006

	local function groundedTabletopProp(name)
		local part = worldFind(furniture, name, "BasePart")
		assert(part.Anchored and not part.CanCollide, name .. " has unsafe tabletop physics")
		local minimum, maximum = partBoundsInFrame(part, tableTop.CFrame)
		assert(math.abs(minimum.Y - surfaceY) <= contactTolerance, string.format(
			"%s does not contact the dining table (gap %.4f)",
			name,
			minimum.Y - surfaceY
		))
		assert(minimum.X >= -halfX - footprintTolerance and maximum.X <= halfX + footprintTolerance, name .. " leaves the dining-table width")
		assert(minimum.Z >= -halfZ - footprintTolerance and maximum.Z <= halfZ + footprintTolerance, name .. " leaves the dining-table depth")
		return part, minimum, maximum
	end

	for index = 1, 6 do
		groundedTabletopProp("DinnerPlate" .. index)
		groundedTabletopProp("IcedTeaGlass" .. index)
	end
	local servingBowl, _, bowlMaximum = groundedTabletopProp("ServingBowl")
	local greenBeans = worldFind(furniture, "GreenBeans", "BasePart")
	assert(greenBeans.Anchored and not greenBeans.CanCollide, "GreenBeans have unsafe tabletop physics")
	local beansMinimum, beansMaximum = partBoundsInFrame(greenBeans, tableTop.CFrame)
	assert(math.abs(beansMinimum.Y - bowlMaximum.Y) <= contactTolerance, string.format(
		"GreenBeans do not contact ServingBowl (gap %.4f)",
		beansMinimum.Y - bowlMaximum.Y
	))
	assert(beansMinimum.X >= -halfX - footprintTolerance and beansMaximum.X <= halfX + footprintTolerance, "GreenBeans leave the dining-table width")
	assert(beansMinimum.Z >= -halfZ - footprintTolerance and beansMaximum.Z <= halfZ + footprintTolerance, "GreenBeans leave the dining-table depth")
	local bowlLocal = tableTop.CFrame:PointToObjectSpace(servingBowl.Position)
	local beansLocal = tableTop.CFrame:PointToObjectSpace(greenBeans.Position)
	assert((Vector2.new(bowlLocal.X, bowlLocal.Z) - Vector2.new(beansLocal.X, beansLocal.Z)).Magnitude <= contactTolerance, "GreenBeans are not centered in ServingBowl")
end

-- Task stations must stay attached to the objects they describe.
local sink = worldFind(furniture, "DoublePorcelainSink", "BasePart")
local dishesAnchor = need(stations, "DishesPromptAnchor", "BasePart")
assert((dishesAnchor.Position - sink.Position).Magnitude < 3, "Dish task is not at the kitchen sink")
local dirtyDishes = need(visuals, "DirtyDishesInSink", "Model")
local sinkBasins = {
	LeftSinkBasin = worldFind(furniture, "LeftSinkBasin", "BasePart"),
	RightSinkBasin = worldFind(furniture, "RightSinkBasin", "BasePart"),
}
local dishCount = 0
for _, item in ipairs(dirtyDishes:GetDescendants()) do
	if item:IsA("BasePart") then
		dishCount += 1
		local basin = sinkBasins[item:GetAttribute("SinkBasin")]
		assert(basin, item.Name .. " lost its sink-basin attachment")
		local localPosition = basin.CFrame:PointToObjectSpace(item.Position)
		assert(math.abs(localPosition.X) <= basin.Size.X * 0.5 + 0.08, item.Name .. " is outside the sink width")
		assert(math.abs(localPosition.Z) <= basin.Size.Z * 0.5 + 0.08, item.Name .. " is outside the sink depth")
		assert(localPosition.Y >= basin.Size.Y * 0.5 - 0.02 and localPosition.Y <= 0.85, item.Name .. " is detached vertically from the sink")
		assert(item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery, item.Name .. " has unsafe dish physics")
	end
end
assert(dishCount == 15, "The visible sink dish set is incomplete")
local fridge = worldFind(furniture, "WhiteHotpointRefrigerator", "Model")
local beerAnchor = need(stations, "GeorgeBeerDropAnchor", "BasePart")
assert((beerAnchor.Position - fridge:GetPivot().Position).Magnitude < 4, "Beer drop is not at the refrigerator")
local installBay = need(stations, "MachineInstallBay", "BasePart")
local garageFoundation = need(garage, "GarageFoundation", "BasePart")
local bayLocal = garageFoundation.CFrame:PointToObjectSpace(installBay.Position)
assert(math.abs(bayLocal.X) < garageFoundation.Size.X * 0.5, "Machine install bay is outside the garage width")
assert(math.abs(bayLocal.Z) < garageFoundation.Size.Z * 0.5, "Machine install bay is outside the garage depth")

-- The income boombox occupies the previously empty formal-sofa end table.
-- Floor pools are visual-only room effects and therefore do not contribute to
-- the compact physical shell or furniture-overlap calculation.
do
	local boombox = need(visuals, "CooperIncomeBoombox", "Model")
	assert(boombox.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Boombox does not stream as one setpiece")
	assert(boombox:GetAttribute("InstallVersion") == "2026-07-13.4", "Boombox spatial geometry version is stale")
	assert(boombox:GetAttribute("Placed") == false and boombox:GetAttribute("Playing") == false, "Boombox edit state is not idle/hidden")
	assert(boombox:GetAttribute("PlacementFurniture") == "FormalSofaEndTable.Top", "Boombox is not attached to its intended table")
	local setupCFrame = boombox:GetAttribute("SetupCFrame")
	assert(typeof(setupCFrame) == "CFrame", "Boombox has no furniture-relative setup CFrame")

	local endTable = worldFind(furniture, "FormalSofaEndTable", "Model")
	local tableTop = need(endTable, "Top", "BasePart")
	local formalSofa = worldFind(furniture, "FormalGreenFloralSofa", "Model")
	local formalCarpet = need(rooms, "FormalLivingOatmealCarpet", "BasePart")
	local tableUp = tableTop.CFrame.UpVector.Unit
	local sofaLook = formalSofa:GetPivot().LookVector
	local planarLook = sofaLook - tableUp * sofaLook:Dot(tableUp)
	assert(planarLook.Magnitude > 0.5, "Formal sofa has no horizontal facing direction")
	local expectedBase = tableTop.Position + tableUp * (tableTop.Size.Y * 0.5 + 0.025)
	assert((setupCFrame.Position - expectedBase).Magnitude < 0.01, "Boombox is floating away from the end-table surface")
	assert(setupCFrame.LookVector:Dot(planarLook.Unit) > 0.999, "Boombox front does not face into the living room")

	local minimumX, minimumY, minimumZ = math.huge, math.huge, math.huge
	local maximumX, maximumY, maximumZ = -math.huge, -math.huge, -math.huge
	local authoredParts = 0
	local placedColliders = 0
	local spotLights = 0
	local pointLights = 0
	for _, item in ipairs(boombox:GetDescendants()) do
		if item:IsA("BasePart") then
			authoredParts += 1
			assert(item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery, item.Name .. " has unsafe pre-placement physics")
			assert(item.Transparency == 1, item.Name .. " leaks into the room before purchase/setup")
			assert(type(item:GetAttribute("VisibleTransparency")) == "number", item.Name .. " is missing its placed transparency")
			assert(type(item:GetAttribute("PlacedCanCollide")) == "boolean", item.Name .. " is missing its placed collision rule")
			if item:GetAttribute("PlacedCanCollide") == true then
				placedColliders += 1
				assert(item.Name == "CollisionHull" and item:GetAttribute("VisibleTransparency") == 1, "Boombox collider must be a single invisible hull")
			end
			if item:GetAttribute("BoomboxEffectPart") ~= true then
				for xSign = -1, 1, 2 do
					for ySign = -1, 1, 2 do
						for zSign = -1, 1, 2 do
							local corner = item.CFrame:PointToWorldSpace(Vector3.new(
								xSign * item.Size.X * 0.5,
								ySign * item.Size.Y * 0.5,
								zSign * item.Size.Z * 0.5
							))
							local setupLocal = setupCFrame:PointToObjectSpace(corner)
							minimumX = math.min(minimumX, setupLocal.X)
							minimumY = math.min(minimumY, setupLocal.Y)
							minimumZ = math.min(minimumZ, setupLocal.Z)
							maximumX = math.max(maximumX, setupLocal.X)
							maximumY = math.max(maximumY, setupLocal.Y)
							maximumZ = math.max(maximumZ, setupLocal.Z)
							local tableLocal = tableTop.CFrame:PointToObjectSpace(corner)
							assert(math.abs(tableLocal.X) <= tableTop.Size.X * 0.5 + 0.01, item.Name .. " overhangs the table width")
							assert(math.abs(tableLocal.Z) <= tableTop.Size.Z * 0.5 + 0.01, item.Name .. " overhangs the table depth")
						end
					end
				end
			end
		elseif item:IsA("SpotLight") then
			spotLights += 1
			assert(not item.Enabled and not item.Shadows, item.Name .. " has the wrong idle disco-light contract")
			assert(math.abs(item.Brightness - 5.75) < 0.001, item.Name .. " has the wrong pronounced brightness")
			assert(math.abs(item.Range - 31) < 0.001, item.Name .. " has the wrong pronounced range")
			assert(math.abs(item.Angle - 74) < 0.001, item.Name .. " has the wrong pronounced cone")
		elseif item:IsA("PointLight") then
			pointLights += 1
			assert(not item.Enabled and not item.Shadows and item.Name == "PartyWash", "Boombox party wash has the wrong idle contract")
			assert(math.abs(item.Brightness - 2.35) < 0.001 and math.abs(item.Range - 24) < 0.001, "Boombox party wash has the wrong pronounced-light contract")
		end
	end
	assert(authoredParts == 50, string.format("Boombox authored part set changed: expected 50, found %d", authoredParts))
	assert(placedColliders == 1 and boombox.PrimaryPart == boombox:FindFirstChild("CollisionHull"), "Boombox collision hull contract changed")
	assert(spotLights == 4 and pointLights == 1, "Boombox disco rig must contain four spots and one wash")
	local physicalSize = Vector3.new(maximumX - minimumX, maximumY - minimumY, maximumZ - minimumZ)
	assert(physicalSize.X <= 1.95 and physicalSize.Y <= 1.15 and physicalSize.Z <= 0.72, "Boombox no longer fits naturally on the end table")
	assert(minimumY >= -0.01 and minimumY <= 0.04, "Boombox feet do not rest on the table")
	local physicalCenter = Vector3.new(
		(minimumX + maximumX) * 0.5,
		(minimumY + maximumY) * 0.5,
		(minimumZ + maximumZ) * 0.5
	)
	local physicalCFrame = setupCFrame * CFrame.new(physicalCenter)
	assert(insidePartXZ(tableTop, physicalCFrame, physicalSize, 0), "Boombox physical footprint leaves the end table")
	assert(insidePartXZ(formalCarpet, physicalCFrame, physicalSize, 0), "Boombox is outside the formal living-room bounds")

	local sound = worldFind(boombox, "BoomboxSound", "Sound")
	assert(sound.SoundId == "rbxassetid://86759598635831", "Boombox is wired to the wrong song")
	assert(not sound.Looped and not sound.Playing and math.abs(sound.Volume - 0.7) < 0.001, "Boombox sound does not install idle/nonlooping at the authored mix")
	assert(sound.RollOffMode == Enum.RollOffMode.InverseTapered and sound.RollOffMinDistance == 7 and sound.RollOffMaxDistance == 68, "Boombox spatial audio rolloff changed")

	local floorPools = need(boombox, "FloorLightPools", "Folder")
	assert(#floorPools:GetChildren() == 3, "Boombox must project exactly three subtle floor pools")
	for poolIndex = 1, 3 do
		local pool = need(floorPools, "FloorLightPool" .. poolIndex, "BasePart")
		assert(pool.Transparency == 1 and pool:GetAttribute("VisibleTransparency") == 1, pool.Name .. " is visible while playback is off")
		assert(pool:GetAttribute("BoomboxFloorPool") == true and pool:GetAttribute("BoomboxEffectPart") == true, pool.Name .. " is not marked as a visual-only effect")
		assert(math.abs((pool:GetAttribute("PlayingTransparency") or 0) - 0.56) < 0.001, pool.Name .. " has the wrong pronounced playing transparency")
		assert(not pool.CanCollide and not pool.CanTouch and not pool.CanQuery, pool.Name .. " can obstruct the living room")
		for ySign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local corner = pool.CFrame:PointToWorldSpace(Vector3.new(0, ySign * pool.Size.Y * 0.5, zSign * pool.Size.Z * 0.5))
				local carpetLocal = formalCarpet.CFrame:PointToObjectSpace(corner)
				assert(math.abs(carpetLocal.X) <= formalCarpet.Size.X * 0.5 + 0.03, pool.Name .. " leaves the formal living-room width")
				assert(math.abs(carpetLocal.Z) <= formalCarpet.Size.Z * 0.5 + 0.03, pool.Name .. " leaves the formal living-room depth")
			end
		end
	end

	local setupAnchor = need(stations, "BoomboxSetupAnchor", "BasePart")
	local powerAnchor = need(stations, "BoomboxPowerAnchor", "BasePart")
	assert((setupAnchor.Position - (setupCFrame * CFrame.new(0, 0.42, 0)).Position).Magnitude < 0.01, "Boombox setup station is detached from the table")
	assert((powerAnchor.Position - (setupCFrame * CFrame.new(-0.82, 0.68, -0.39)).Position).Magnitude < 0.01, "Boombox power station is detached from its button")

	local function worldAABB(cf, size)
		local half = size * 0.5
		local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
		return cf.Position, Vector3.new(
			math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
			math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
			math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
		)
	end
	local boomboxCenter, boomboxHalf = worldAABB(physicalCFrame, physicalSize)
	for _, furnitureName in ipairs({
		"FormalSofaEndTable",
		"FormalGreenFloralSofa",
		"FormalGlassCoffeeTable",
		"FormalRustButtonChair",
		"FormalBrassFloorLamp",
		"FormalEntryConsole",
	}) do
		local item = worldFind(furniture, furnitureName, "Model")
		local itemCF, itemSize = item:GetBoundingBox()
		local itemCenter, itemHalf = worldAABB(itemCF, itemSize)
		local delta = boomboxCenter - itemCenter
		local overlaps = math.abs(delta.X) < boomboxHalf.X + itemHalf.X
			and math.abs(delta.Y) < boomboxHalf.Y + itemHalf.Y
			and math.abs(delta.Z) < boomboxHalf.Z + itemHalf.Z
		assert(not overlaps, "Boombox intersects " .. furnitureName)
	end
end

-- The indoor can is genuinely inside the kitchen, not fused with the fridge.
local kitchenFloor = need(rooms, "KitchenPatternLinoleum", "BasePart")
local kitchenCan = need(visuals, "KitchenGarbageCan", "Model")
local kitchenCanCF, kitchenCanSize = kitchenCan:GetBoundingBox()
assert(insidePartXZ(kitchenFloor, kitchenCanCF, kitchenCanSize, 0.15), "Kitchen garbage can is outside the kitchen")
assert(not boundsOverlap(kitchenCan, fridge), "Kitchen garbage can intersects the refrigerator")
local kitchenCanBody = need(kitchenCan, "Can", "BasePart")
assert(kitchenCanBody.CanCollide, "Players can walk through the kitchen garbage can")
local trashPickup = need(stations, "TrashPickupAnchor", "BasePart")
assert((trashPickup.Position - kitchenCanCF.Position).Magnitude < 1.5, "Trash pickup is detached from the kitchen can")

-- The outdoor can is on the garage exterior and has the delivery arrow target.
local outdoorCan = need(visuals, "OutdoorGarbageCan", "Model")
local outdoorCanCF, outdoorCanSize = outdoorCan:GetBoundingBox()
assert(need(outdoorCan, "Can", "BasePart").CanCollide, "Players can walk through the outdoor garbage can")
local leftWall = need(garage, "GarageLeftWall", "BasePart")
local rightWall = need(garage, "GarageRightWall", "BasePart")
local westFace = leftWall.Position.X - leftWall.Size.X * 0.5
local eastFace = rightWall.Position.X + rightWall.Size.X * 0.5
assert(
	outdoorCanCF.Position.X + outdoorCanSize.X * 0.5 < westFace - 0.2
		or outdoorCanCF.Position.X - outdoorCanSize.X * 0.5 > eastFace + 0.2,
	"Outdoor garbage can is inside the garage"
)
local outdoorTrashAnchor = need(stations, "OutdoorTrashAnchor", "BasePart")
assert((outdoorTrashAnchor.Position - outdoorCanCF.Position).Magnitude < 0.6, "Trash arrow is not aligned with the outdoor can")

-- The property was raised long after the first task-world prototype. Pin every
-- visible task pad and the outdoor can to a real support surface so an obsolete
-- world-space Y value can never put guidance or TrashBot's destination below
-- the relocated house again.
local supportParams = RaycastParams.new()
supportParams.FilterType = Enum.RaycastFilterType.Exclude
supportParams.FilterDescendantsInstances = { taskWorld }
supportParams.RespectCanCollide = true
local function assertGroundedFromEnvironment(part, label, tolerance)
	local result = workspace:Raycast(
		part.Position + Vector3.new(0, 0.5, 0),
		Vector3.new(0, -4, 0),
		supportParams
	)
	assert(result, label .. " has no physical support below it")
	local bottomY = part.Position.Y - part.Size.Y * 0.5
	assert(math.abs(bottomY - result.Position.Y) <= (tolerance or 0.15), label .. " is floating or below the floor")
end
for _, padName in ipairs({
	"DishesPad",
	"TrashPickupPad",
	"OutdoorTrashPad",
	"GeorgeBeerPad",
	"MachineInstallPad",
	"MissyReturnPad",
}) do
	assertGroundedFromEnvironment(need(visuals, padName, "BasePart"), padName, 0.16)
end
local outdoorCanBody = need(outdoorCan, "Can", "BasePart")
local canBottom = outdoorCanBody.Position.Y
	- math.abs(outdoorCanBody.CFrame.RightVector.Y) * outdoorCanBody.Size.X * 0.5
	- math.abs(outdoorCanBody.CFrame.UpVector.Y) * outdoorCanBody.Size.Y * 0.5
	- math.abs(outdoorCanBody.CFrame.LookVector.Y) * outdoorCanBody.Size.Z * 0.5
local outdoorSupport = workspace:Raycast(
	outdoorCanBody.Position,
	Vector3.new(0, -5, 0),
	supportParams
)
assert(outdoorSupport and math.abs(canBottom - outdoorSupport.Position.Y) <= 0.16, "Outdoor garbage can is below the relocated yard")

local starterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local familyClient = starterPlayerScripts and starterPlayerScripts:FindFirstChild("CooperGame")
assert(familyClient and familyClient:IsA("LocalScript"), "Family task client is missing")
for _, marker in ipairs({
	"upgradeNoticeUi.taskPadNames",
	"function upgradeNoticeUi.setTaskPadVisible",
	"pad.LocalTransparencyModifier = visible == true and 0 or 1",
	"upgradeNoticeUi.setTaskPadVisible(visuals, \"MissyReturnPad\"",
	"upgradeNoticeUi.setTaskPadVisible(visuals, \"MachineInstallPad\"",
}) do
	assert(string.find(familyClient.Source, marker, 1, true), "Personal task-pad visibility is missing " .. marker)
end

-- Both normal toys and the task-return point belong to Missy's real mattress.
local missyBed = worldFind(furniture, "MissyWalnutTwinBed", "Model")
local mattress = need(missyBed, "Mattress", "BasePart")
local mattressTop = mattress.Position.Y + mattress.Size.Y * 0.5
for _, toyName in ipairs({ "MissyDetailedTeddyBear", "MissyDetailedRabbit" }) do
	local toy = worldFind(furniture, toyName, "Model")
	local home = toy:GetAttribute("FamilyTaskHomeCFrame")
	assert(typeof(home) == "CFrame", toyName .. " has no bed-relative home CFrame")
	assert(cframeClose(toy:GetPivot(), home, 0.05, 1), toyName .. " is not at its home pose")
	local localHome = mattress.CFrame:PointToObjectSpace(home.Position)
	assert(math.abs(localHome.X) < mattress.Size.X * 0.5, toyName .. " is outside the mattress width")
	assert(math.abs(localHome.Z) < mattress.Size.Z * 0.5, toyName .. " is outside the mattress length")
	local toyCF, toySize = toy:GetBoundingBox()
	assert(toyCF.Position.Y - toySize.Y * 0.5 >= mattressTop - 0.08, toyName .. " is below the mattress surface")
end
local returnAnchor = need(stations, "MissyPlushReturnAnchor", "BasePart")
assert((returnAnchor.Position - mattress.Position).Magnitude < 3, "Lost-toy return is not on Missy's bed")
assert(#hidden:GetChildren() == #Config.HiddenLocations, "Hidden plush marker count changed")
for _, definition in ipairs(Config.HiddenLocations) do
	local marker = need(hidden, definition.name, "BasePart")
	assert(marker:GetAttribute("FurnitureAnchor") == definition.anchorName, definition.name .. " lost its furniture anchor")
	local anchor = worldFind(furniture, definition.anchorName)
	local anchorCF, anchorSize = modelOrPartBounds(anchor)
	assert(
		(marker.Position - anchorCF.Position).Magnitude <= math.max(anchorSize.X, anchorSize.Y, anchorSize.Z) + 5,
		definition.name .. " is no longer tucked near its furniture"
	)
	assert((marker.Position - mattress.Position).Magnitude > 4, definition.name .. " incorrectly hides the toy on Missy's bed")
end

-- Refrigerator pose data must follow the actual refrigerator instead of an old
-- map origin. The visible slab and body must remain one compact appliance.
local fridgeBody = need(fridge, "RefrigeratorBody", "BasePart")
local fridgeDoor = need(fridge, "CooperFridgeDoorAssembly", "Model")
local fridgeHinge = need(fridgeDoor, "FridgeDoorHinge", "BasePart")
local fridgePanel = need(fridgeDoor, "FridgeDoorPanel", "BasePart")
local closedFridge = fridgeHinge:GetAttribute("ClosedCFrame")
assert(typeof(closedFridge) == "CFrame", "Fridge closed pose is missing")
assert((closedFridge.Position - fridgeHinge.Position).Magnitude < 0.05, "Fridge closed pose uses stale world coordinates")
assert((fridgePanel.Position - fridgeBody.Position).Magnitude < 5, "Fridge door is detached from the refrigerator")
assert(fridgePanel.CanCollide and fridgeBody.CanCollide, "Fridge body/door are walk-through")

-- Front and patio doors may be authored open, but their state, prompt, and
-- current physical pose must agree exactly.
local exterior = need(house, "ExteriorDetails", "Model")
for _, spec in ipairs({
	{ model = "InteractiveFrontDoor", anchor = "FrontDoorPromptAnchor", slab = "DoorSlab" },
	{ model = "InteractiveDenPatioDoor", anchor = "DenPatioPromptAnchor", slab = "DoorCollisionSlab" },
}) do
	local door = need(exterior, spec.model, "Model")
	local isOpen = door:GetAttribute("IsOpen") == true
	local expected = door:GetAttribute(isOpen and "OpenPivot" or "ClosedPivot")
	assert(typeof(expected) == "CFrame", spec.model .. " is missing a state pose")
	assert(cframeClose(door:GetPivot(), expected, 0.05, 1), spec.model .. " physical pose disagrees with IsOpen")
	assert(need(door, spec.slab, "BasePart").CanCollide, spec.model .. " is walk-through")
	local prompt = need(need(exterior, spec.anchor, "BasePart"), "DoorPrompt", "ProximityPrompt")
	assert(prompt.ActionText == (isOpen and "Close Door" or "Open Door"), spec.model .. " prompt text disagrees with state")
end

-- Sectional garage door poses must be aligned to the physical garage shell.
local garageDoor = need(garage, "InteractiveSectionalGarageDoor", "Model")
local panels = need(garageDoor, "Panels", "Folder")
local garageHeader = need(garage, "GarageDoorHeader", "BasePart")
assert(math.abs((garageDoor:GetAttribute("DoorCenterX") or math.huge) - garageFoundation.Position.X) < 0.25, "Garage door center is stale")
assert(math.abs((garageDoor:GetAttribute("DoorPlaneZ") or math.huge) - garageHeader.Position.Z) < 2, "Garage door plane is stale")
local panelCount = 0
for _, panel in ipairs(panels:GetChildren()) do
	if panel:IsA("BasePart") then
		panelCount += 1
		local closedPose = need(panel, "ClosedPose", "CFrameValue").Value
		need(panel, "OpenPose", "CFrameValue")
		assert(math.abs(closedPose.Position.X - garageFoundation.Position.X) < 0.25, panel.Name .. " closed pose is off-center")
		assert(math.abs(closedPose.Position.Z - garageHeader.Position.Z) < 2, panel.Name .. " closed pose is off the opening")
		if garageDoor:GetAttribute("IsOpen") ~= true then
			assert(cframeClose(panel.CFrame, closedPose, 0.05, 1), panel.Name .. " is not physically closed")
		end
	end
end
assert(panelCount == 6, "Garage door must contain six panels")
local blocker = need(garageDoor, "CollisionBlocker", "BasePart")
assert(garageDoor:GetAttribute("IsOpen") == true or blocker.CanCollide, "Closed garage opening has no collision blocker")

-- Relocation-sensitive bathroom and hall state.
local interactions = need(house, "CooperInteractions", "Model")
local bathroom = need(interactions, "BathroomInteractions", "Model")
local swirl = need(bathroom, "ToiletFlushSwirl", "BasePart")
assert(cframeClose(swirl.CFrame, swirl:GetAttribute("RestCFrame"), 0.05, 1), "Toilet effect rest pose is stale")
assert(swirl:GetAttribute("RestSize") == swirl.Size, "Toilet effect rest size is stale")
local showerWater = need(bathroom, "ShowerWater", "BasePart")
local showerSound = need(showerWater, "CooperShowerWaterSound", "Sound")
assert(showerSound.Looped and showerSound.SoundId ~= "", "Shower water sound is not configured")
local crossHall = need(rooms, "CrossHallFloor", "BasePart")
assert(math.abs((environment:GetAttribute("HallMinZ") or math.huge) - (crossHall.Position.Z - crossHall.Size.Z * 0.5)) < 0.05, "HallMinZ is stale")
assert(math.abs((environment:GetAttribute("HallMaxZ") or math.huge) - (crossHall.Position.Z + crossHall.Size.Z * 0.5)) < 0.05, "HallMaxZ is stale")

-- Swing reset pose and rope constraints must agree with the physical branch.
local landscaping = need(environment, "Landscaping", "Model")
local rideables = need(landscaping, "CooperYardRideables", "Model")
local swing = rideables:FindFirstChild("FrontYardTireSwing") or rideables:FindFirstChild("FrontYardRopeSwing")
assert(swing and swing:IsA("Model"), "Front-yard swing is missing")
local swingSeat = need(swing, "SwingSeat", "Seat")
-- An unoccupied rope-constrained seat settles about 0.05 studs below its
-- authored kinematic home once the physics solver takes ownership. Keep this
-- pose tolerance just above that deterministic slack; the per-rope assertions
-- below remain stricter and still reject any visibly stretched swing.
assert(cframeClose(swingSeat.CFrame, swingSeat:GetAttribute("HomeCFrame"), 0.08, 1), "Swing is stretched away from its home pose")
assert(swingSeat.CanCollide, "Swing seat is walk-through")
local ropeCount = 0
for _, item in ipairs(swing:GetDescendants()) do
	if item:IsA("RopeConstraint") then
		ropeCount += 1
		assert(item.Attachment0 and item.Attachment1, item:GetFullName() .. " has missing attachments")
		local distance = (item.Attachment0.WorldPosition - item.Attachment1.WorldPosition).Magnitude
		assert(math.abs(item.Length - distance) < 0.06, item:GetFullName() .. " is stretched at rest")
	end
end
assert(ropeCount >= 2, "Swing is missing rope constraints")

local trike = need(rideables, "CooperRedYellowTrike", "Model")
local trikeChassis = need(trike, "Chassis", "BasePart")
local trikeSeat = need(trike, "TrikeSeat", "VehicleSeat")
local trikeCollisionProxy = need(trike, "PlayerCollisionProxy", "BasePart")
assert(trike:GetAttribute("MotionMode") == "ServerKinematicGroundFollower", "Trike motion mode changed")
assert(rideables:GetAttribute("InstallVersion") == "2.3.0", "Trike collision-safe installer is stale")
assert(trike:GetAttribute("ObstacleSweepVersion") == 1, "Trike swept collision is missing")
assert(trike:GetAttribute("PlayerCollisionProxyVersion") == 1, "Trike player collision proxy version is stale")
assert(typeof(trike:GetAttribute("ObstacleProbeSize")) == "Vector3", "Trike obstacle probe size is missing")
assert(cframeClose(trikeChassis.CFrame, trike:GetAttribute("HomeCFrame"), 0.5, 1), "Trike home pose is stale")
assert(trikeCollisionProxy.CanCollide, "Parked trike is walk-through")
assert(trikeCollisionProxy.CanQuery and not trikeCollisionProxy.CanTouch, "Trike collision proxy query/touch settings changed")
assert(trikeCollisionProxy.Transparency == 1 and not trikeCollisionProxy.CastShadow, "Trike collision proxy is visible")
assert(trikeCollisionProxy.Massless, "Trike collision proxy changes ride mass")
local proxyOffset = trikeCollisionProxy:GetAttribute("ChassisLocalOffset")
assert(typeof(proxyOffset) == "Vector3", "Trike collision proxy has no chassis-local offset")
assert(
	cframeClose(trikeCollisionProxy.CFrame, trikeChassis.CFrame * CFrame.new(proxyOffset), 0.02, 0.25),
	"Trike collision proxy is detached from its chassis-local pose"
)
local rideHeight = trike:GetAttribute("RideHeight")
assert(type(rideHeight) == "number", "Trike ride height is missing")
local proxyBottom = proxyOffset.Y - trikeCollisionProxy.Size.Y * 0.5
assert(proxyBottom > -rideHeight + 0.08, "Trike collision proxy can snag the supporting ground")
local seatRelative = trikeChassis.CFrame:ToObjectSpace(trikeSeat.CFrame)
local seatHalfHeight = math.abs(seatRelative.RightVector.Y) * trikeSeat.Size.X * 0.5
	+ math.abs(seatRelative.UpVector.Y) * trikeSeat.Size.Y * 0.5
	+ math.abs(seatRelative.LookVector.Y) * trikeSeat.Size.Z * 0.5
local seatBottom = seatRelative.Position.Y - seatHalfHeight
local proxyTop = proxyOffset.Y + trikeCollisionProxy.Size.Y * 0.5
assert(proxyTop < seatBottom - 0.04, "Trike collision proxy intrudes into the rider seat")
local proxyWelded = false
for _, descendant in ipairs(trike:GetDescendants()) do
	if descendant:IsA("WeldConstraint")
		and ((descendant.Part0 == trikeChassis and descendant.Part1 == trikeCollisionProxy)
			or (descendant.Part1 == trikeChassis and descendant.Part0 == trikeCollisionProxy))
	then
		proxyWelded = true
		break
	end
end
assert(proxyWelded, "Trike collision proxy is not welded to the chassis")
local rideableController = need(ServerScriptService, "CooperYardRideables", "Script")
for _, marker in ipairs({
	"CONTROLLER_VERSION = \"2.3.0\"",
	"trikeCollisionProxy",
	"NoCollisionConstraint",
	"descendant.CanCollide = descendant == trikeCollisionProxy",
}) do
	assert(string.find(rideableController.Source, marker, 1, true), "Trike controller is missing " .. marker)
end

-- The two-leg delivery route is swept clear of the parked wagon/house and the
-- truck parks clear of all three crate slots. Runtime makes every opaque truck part
-- collidable while it is visible.
local delivery = need(taskWorld, "Delivery", "Model")
local route = need(delivery, "Route", "Folder")
local truck = need(delivery, "CooperDeliveryTruck", "Model")
local truckSpawn = need(route, "TruckSpawn", "BasePart")
local truckApproach = need(route, "TruckApproach", "BasePart")
local truckStop = need(route, "TruckStop", "BasePart")
local truckExit = need(route, "TruckExit", "BasePart")
local dropZone = need(delivery, "DeliveryDropZone", "BasePart")
assert((truckSpawn.Position - truckExit.Position).Magnitude < 0.05, "Truck exit no longer returns to spawn")
assert(math.abs(truckSpawn.Position.X - truckApproach.Position.X) < 0.05, "Truck approaches in an unsafe diagonal lane")
assert((truckApproach.Position - truckStop.Position).Magnitude < 22, "Truck curb pull-in is too long")

local truckPivot = truck:GetPivot()
local truckBoundsCF, truckBoundsSize = truck:GetBoundingBox()
local boundsRelative = truckPivot:ToObjectSpace(truckBoundsCF)
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { truck, route }
overlap.MaxParts = 100

local startPose = CFrame.lookAt(truckSpawn.Position, truckApproach.Position)
local approachPose = CFrame.lookAt(truckApproach.Position, truckStop.Position)
local stopPose = CFrame.lookAt(truckStop.Position, truckStop.Position + (truckStop.Position - truckApproach.Position))
local exitApproachPose = CFrame.lookAt(truckApproach.Position, truckExit.Position)
local exitPose = CFrame.lookAt(truckExit.Position, truckExit.Position + (truckExit.Position - truckApproach.Position))
local function checkTruckLeg(fromPose, toPose, label)
	for sample = 0, 48 do
		local pose = fromPose:Lerp(toPose, sample / 48)
		for _, hit in ipairs(Workspace:GetPartBoundsInBox(pose * boundsRelative, truckBoundsSize - Vector3.new(0.06, 0.06, 0.06), overlap)) do
			if hit.CanCollide and not hit:IsDescendantOf(truck) then
				error(string.format("Truck route %s intersects %s", label, hit:GetFullName()), 0)
			end
		end
	end
end
checkTruckLeg(startPose, approachPose, "spawn-to-approach")
checkTruckLeg(approachPose, stopPose, "approach-to-stop")
checkTruckLeg(stopPose, exitApproachPose, "stop-to-exit-approach")
checkTruckLeg(exitApproachPose, exitPose, "exit-approach-to-exit")

local function worldAABB(cf, size)
	local half = size * 0.5
	local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
	return cf.Position, Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	)
end
local parkedCenter, parkedHalf = worldAABB(stopPose * boundsRelative, truckBoundsSize)
for _, crate in ipairs({
	{ name = "beer", offset = -2.8, size = Vector3.new(3.4, 2.1, 2.8) },
	{ name = "boombox", offset = 0, size = Vector3.new(3.0, 1.8, 2.4) },
	{ name = "machine", offset = 2.8, size = Vector3.new(3.8, 2.6, 3.2) },
}) do
	local center = (dropZone.CFrame * CFrame.new(crate.offset, crate.size.Y * 0.5 + 0.12, 0)).Position
	local half = crate.size * 0.5
	local delta = parkedCenter - center
	local overlaps = math.abs(delta.X) < parkedHalf.X + half.X
		and math.abs(delta.Y) < parkedHalf.Y + half.Y
		and math.abs(delta.Z) < parkedHalf.Z + half.Z
	assert(not overlaps, "Parked truck blocks the " .. crate.name .. " crate")
end
local taskController = need(ServerScriptService, "CooperTaskWorld", "Script")
for _, marker in ipairs({
	"TruckApproach",
	"descendant.CanCollide = not isGlass",
	"BeerCarryLost",
	"TrashCarryLost",
	"MissyPlushCarryLost",
	"Delivery_Boombox_",
	"COOPER SOUND",
	"BoomboxCarryLost",
	"scheduleBoomboxRecovery",
	"tryBoomboxRecovery",
	"BoomboxSetup",
	"BoomboxPlaced",
	"ContentProvider:PreloadAsync",
	"BeginBoomboxPlayback",
	"BoomboxPayoutTick",
	"EndBoomboxPlayback",
	"boomboxSound.Ended",
	"finishBoomboxPlayback",
	"setDiscoActive(false)",
	"PlaybackOwnerUserId",
	"candidate:GetAttribute(\"OwnerUserId\") == player.UserId",
}) do
	assert(string.find(taskController.Source, marker, 1, true), "Task controller is missing " .. marker)
end
for _, laneMarker in ipairs({
	"local SAFE_DELIVERY_LANES = { 0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6 }",
	"for lane = 7, 18 do",
	"table.insert(SAFE_DELIVERY_LANES, -lane)",
	"local function deliveryCrateSize(kind)",
	"for _, lane in ipairs(SAFE_DELIVERY_LANES) do",
	"return nil, nil",
	"if not reservedSpawnOffset then",
	"table.insert(deliveryQueue, entry)",
}) do
	assert(string.find(taskController.Source, laneMarker, 1, true), "Task controller is missing swept-safe delivery behavior " .. laneMarker)
end

-- High-level solid-object collision contract. Decorative skins may be
-- non-colliding, but every large usable furnishing must own a real collider.
for _, floorName in ipairs({
	"KitchenPatternLinoleum",
	"CrossHallFloor",
	"DenHoneyOakFloor",
	"FormalLivingOatmealCarpet",
	"DiningOatmealCarpet",
	"TwinsGreenGrayCarpet",
	"GeorgieBrownCarpet",
	"ParentsGrayCarpet",
}) do
	assert(worldFind(rooms, floorName, "BasePart").CanCollide, floorName .. " is walk-through")
end
for _, shellName in ipairs({
	"GarageFoundation",
	"GarageLeftWall",
	"GarageRightWall",
	"GarageBackWall",
	"GarageFrontLeft",
	"GarageFrontRight",
	"GarageDoorHeader",
	"GarageRoofFront",
	"GarageRoofBack",
}) do
	assert(need(garage, shellName, "BasePart").CanCollide, shellName .. " is walk-through")
end
for _, furnitureName in ipairs({
	"FormalGreenFloralSofa",
	"RedPlaidDenSofa",
	"CooperDiningTable",
	"KitchenDinetteTable",
	"MissyWalnutTwinBed",
	"SheldonWalnutTwinBed",
	"GeorgieWalnutBed",
	"ParentsOliveFourPosterBed",
	"WhiteHotpointRefrigerator",
	"BlackTileFrostedShower",
	"WoodCabinetCRTTelevision",
	"WhiteDenBuiltInBookcase",
}) do
	local item = worldFind(furniture, furnitureName)
	local colliderCount = 0
	if item:IsA("BasePart") and item.CanCollide then
		colliderCount = 1
	end
	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			colliderCount += 1
		end
	end
	assert(colliderCount > 0, furnitureName .. " has no physical collider")
end

local interactionServer = need(ServerScriptService, "CooperInteractions", "Script")
assert(string.find(interactionServer.Source, "CooperShowerWaterSound", 1, true), "Interaction server cannot self-heal shower audio")
local hallClient = need(StarterPlayer.StarterPlayerScripts, "CooperHallCameraController", "LocalScript")
assert(string.find(hallClient.Source, "CrossHallFloor", 1, true), "Hall camera does not derive its bounds from the physical hall")
assert(string.find(hallClient.Source, "hallFloorTop", 1, true), "Hall camera Y bounds are not derived from the physical floor")
assert(
	not string.find(hallClient.Source, "math.clamp(cameraPosition.Y, 2.0, 10.8)", 1, true),
	"Hall camera still clamps to the old under-map absolute Y range"
)

print(string.format(
	"[SpatialIntegrityAudit] PASS: 5 tasks, 13 stations, %d hidden spots, 6 garage panels, %d swing ropes, clear bounded truck route",
	#Config.HiddenLocations,
	ropeCount
))
return true
