-- Run in the Studio command bar after the family task world installer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local environment = workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment, "CooperHouseEnvironment is missing")

local configClone = ReplicatedStorage.CooperGame.Config:Clone()
configClone.Name = "__TaskWorldAuditConfig"
configClone.Parent = ReplicatedStorage.CooperGame
local Config = require(configClone)
configClone:Destroy()

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

local world = environment:FindFirstChild(Config.WorldRootName)
assert(world and world:IsA("Model"), Config.WorldRootName .. " is missing")
assert(world:GetAttribute("Ready") == true, "Family task world did not finish installing")

local stations = world:FindFirstChild("Stations")
local hidden = world:FindFirstChild("HiddenLocations")
local delivery = world:FindFirstChild("Delivery")
assert(stations and hidden and delivery, "Task world folders are incomplete")
assert(world:GetAttribute("InstallVersion") == "2026-07-21.hackerbot.1", "Family task world is not on the HackerBot geometry version")
assert(world:GetAttribute("StationCount") == 13, "Family task world does not advertise all thirteen stations")
assert(world:GetAttribute("SupportsIncomeBoombox") == true, "Family task world does not advertise income-boombox support")

local expectedActions = {
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
}
assert(#stations:GetChildren() == 13, "Exactly thirteen retained task/economy/boombox/automation stations must exist")
for name, action in pairs(expectedActions) do
	local anchor = stations:FindFirstChild(name)
	assert(anchor and anchor:IsA("BasePart"), "Missing station " .. name)
	local prompt = anchor:FindFirstChild("TaskPrompt")
	assert(prompt and prompt:IsA("ProximityPrompt"), name .. " has no prompt")
	assert(prompt:GetAttribute("FamilyTaskAction") == action, name .. " has the wrong action")
	assert(prompt.RequiresLineOfSight == false, name .. " must remain easy to use")
end
assert(stations.DishesPromptAnchor.TaskPrompt.Enabled == true, "Dish prompt must remain server-enabled for authoritative hold timing")
assert(stations.BoomboxSetupAnchor.TaskPrompt.Enabled == false, "Boombox setup prompt must stay disabled until its crate is carried")
assert(stations.BoomboxPowerAnchor.TaskPrompt.Enabled == false, "Boombox power prompt must stay disabled until setup finishes")

assert(#hidden:GetChildren() == #Config.HiddenLocations, "Hidden marker count does not match the config")
for _, definition in ipairs(Config.HiddenLocations) do
	local marker = hidden:FindFirstChild(definition.name)
	assert(marker and marker:IsA("BasePart"), "Missing hidden marker " .. definition.name)
	assert(marker.Transparency == 1, "Hidden markers must not reveal task locations")
	assert(marker:GetAttribute("FurnitureAnchor") == definition.anchorName, definition.name .. " lost its furniture anchor")
	assert(marker:GetAttribute("FurnitureLocalOffset") == definition.localOffset, definition.name .. " has the wrong local offset")
end
assert(not hidden:FindFirstChild("MissyBedFoot"), "Missy's lost toy must not be hidden on her own bed")
assert(not hidden:FindFirstChild("BathroomShowerCorner"), "Missy's lost toy must not be assigned a bathroom hiding spot")

local visuals = world:FindFirstChild("TaskVisuals")
assert(visuals, "TaskVisuals is missing")
local dirtyDishes = visuals:FindFirstChild("DirtyDishesInSink")
assert(dirtyDishes and dirtyDishes:IsA("Model"), "Dirty dishes are missing from the kitchen sink")
assert(dirtyDishes:GetAttribute("FamilyTaskVisual") == "MaryDishes", "Dirty dishes are not bound to Mary's dish task")
assert(dirtyDishes:GetAttribute("RuntimeVisibility") == "MaryDishesOnly", "Dirty dish visibility contract is missing")
assert(dirtyDishes.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Dirty dishes must stream as one complete set")
local leftBasin = environment:FindFirstChild("LeftSinkBasin", true)
local rightBasin = environment:FindFirstChild("RightSinkBasin", true)
assert(leftBasin and leftBasin:IsA("BasePart") and rightBasin and rightBasin:IsA("BasePart"), "Kitchen sink basins are missing")
local basins = {
	LeftSinkBasin = leftBasin,
	RightSinkBasin = rightBasin,
}
local dirtyDishPartCount = 0
for _, descendant in ipairs(dirtyDishes:GetDescendants()) do
	if descendant:IsA("BasePart") then
		dirtyDishPartCount += 1
		assert(descendant:GetAttribute("DirtyDishVisual") == true, descendant.Name .. " is not marked as a dirty-dish visual")
		assert(descendant.Anchored, descendant.Name .. " can fall out of the sink")
		assert(not descendant.CanCollide and not descendant.CanTouch and not descendant.CanQuery, descendant.Name .. " can obstruct or trigger the player")
		local visibleTransparency = descendant:GetAttribute("VisibleTransparency")
		assert(type(visibleTransparency) == "number" and visibleTransparency >= 0 and visibleTransparency < 1, descendant.Name .. " has no visible authored state")
		assert(math.abs(descendant.Transparency - visibleTransparency) < 0.001, descendant.Name .. " base transparency no longer matches its visible state")
		local basinName = descendant:GetAttribute("SinkBasin")
		local basin = basins[basinName]
		assert(basin, descendant.Name .. " is not assigned to a real sink basin")
		local localPosition = basin.CFrame:PointToObjectSpace(descendant.Position)
		assert(math.abs(localPosition.X) <= basin.Size.X * 0.5 + 0.08, descendant.Name .. " is outside its basin width")
		assert(math.abs(localPosition.Z) <= basin.Size.Z * 0.5 + 0.08, descendant.Name .. " is outside its basin depth")
		assert(localPosition.Y >= basin.Size.Y * 0.5 - 0.02 and localPosition.Y <= 0.85, descendant.Name .. " is not sitting in the sink")
	end
end
assert(dirtyDishPartCount == 15, string.format("Expected 15 dirty-dish visual parts, found %d", dirtyDishPartCount))
local kitchenCan = visuals:FindFirstChild("KitchenGarbageCan")
local outdoorCan = visuals:FindFirstChild("OutdoorGarbageCan")
local fridge = environment:FindFirstChild("WhiteHotpointRefrigerator", true)
local kitchenFloor = environment:FindFirstChild("KitchenPatternLinoleum", true)
local garage = environment:FindFirstChild("DetachedGarage")
local leftWall = garage and garage:FindFirstChild("GarageLeftWall")
local rightWall = garage and garage:FindFirstChild("GarageRightWall")
assert(kitchenCan and kitchenCan:IsA("Model") and fridge and fridge:IsA("Model"), "Kitchen can or refrigerator is missing")
assert(kitchenFloor and kitchenFloor:IsA("BasePart"), "Kitchen floor is missing")
assert(outdoorCan and outdoorCan:IsA("Model") and leftWall and leftWall:IsA("BasePart") and rightWall and rightWall:IsA("BasePart"), "Outdoor can or garage wall is missing")

local function boxesOverlap(aModel, bModel)
	local aCF, aSize = aModel:GetBoundingBox()
	local bCF, bSize = bModel:GetBoundingBox()
	local delta = aCF.Position - bCF.Position
	return math.abs(delta.X) < (aSize.X + bSize.X) * 0.5
		and math.abs(delta.Y) < (aSize.Y + bSize.Y) * 0.5
		and math.abs(delta.Z) < (aSize.Z + bSize.Z) * 0.5
end

-- Every supper prop is authored as a rotated OBB, so validate all eight
-- corners in table-local space rather than assuming Size.Y is its height.
do
	local diningTable = environment:FindFirstChild("CooperDiningTable", true)
	local diningTableTop = diningTable and diningTable:FindFirstChild("Top")
	assert(diningTable and diningTable:IsA("Model"), "CooperDiningTable is missing")
	assert(diningTableTop and diningTableTop:IsA("BasePart"), "CooperDiningTable.Top is missing")
	assert(diningTable:GetAttribute("TabletopPropsGrounded") == true, "Dining tabletop repair did not complete")
	assert(diningTable:GetAttribute("TabletopRepairVersion") == "2026-07-13.1", "Dining tabletop repair version is stale")

	local function tableLocalBounds(part)
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
					local localCorner = diningTableTop.CFrame:PointToObjectSpace(corner)
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

	local surfaceY = diningTableTop.Size.Y * 0.5
	local halfX = diningTableTop.Size.X * 0.5
	local halfZ = diningTableTop.Size.Z * 0.5
	local contactTolerance = 0.006
	local footprintTolerance = 0.006
	local function groundedTabletopProp(name)
		local part = environment:FindFirstChild(name, true)
		assert(part and part:IsA("BasePart"), "Missing dining tabletop prop " .. name)
		assert(part.Anchored and not part.CanCollide, name .. " has unsafe tabletop physics")
		local minimum, maximum = tableLocalBounds(part)
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
	local greenBeans = environment:FindFirstChild("GreenBeans", true)
	assert(greenBeans and greenBeans:IsA("BasePart"), "GreenBeans dining prop is missing")
	local beansMinimum, beansMaximum = tableLocalBounds(greenBeans)
	assert(math.abs(beansMinimum.Y - bowlMaximum.Y) <= contactTolerance, string.format(
		"GreenBeans do not contact ServingBowl (gap %.4f)",
		beansMinimum.Y - bowlMaximum.Y
	))
	assert(beansMinimum.X >= -halfX - footprintTolerance and beansMaximum.X <= halfX + footprintTolerance, "GreenBeans leave the dining-table width")
	assert(beansMinimum.Z >= -halfZ - footprintTolerance and beansMaximum.Z <= halfZ + footprintTolerance, "GreenBeans leave the dining-table depth")
	local bowlLocal = diningTableTop.CFrame:PointToObjectSpace(servingBowl.Position)
	local beansLocal = diningTableTop.CFrame:PointToObjectSpace(greenBeans.Position)
	assert((Vector2.new(bowlLocal.X, bowlLocal.Z) - Vector2.new(beansLocal.X, beansLocal.Z)).Magnitude <= 0.006, "GreenBeans are not centered in ServingBowl")
end

-- The purchased boombox is authored hidden on the empty formal-sofa end
-- table. Effect pools deliberately widen the complete Model bounds, so the
-- physical footprint is calculated only from non-effect authored parts.
do
	local boombox = visuals:FindFirstChild("CooperIncomeBoombox")
	assert(boombox and boombox:IsA("Model"), "Income boombox visual is missing")
	assert(boombox.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Income boombox must stream atomically")
	assert(boombox:GetAttribute("InstallVersion") == "2026-07-13.4", "Income boombox visual version is stale")
	assert(boombox:GetAttribute("FamilyTaskVisual") == "IncomeBoombox", "Income boombox task binding is missing")
	assert(boombox:GetAttribute("RuntimeVisibility") == "PlacedOnly", "Income boombox placement visibility contract is missing")
	assert(boombox:GetAttribute("PlacementFurniture") == "FormalSofaEndTable.Top", "Income boombox is not furniture-relative")
	assert(boombox:GetAttribute("Placed") == false and boombox:GetAttribute("Playing") == false, "Income boombox must install idle and hidden")
	assert(boombox.PrimaryPart and boombox.PrimaryPart.Name == "CollisionHull", "Income boombox has no stable collision-hull primary part")

	local setupCFrame = boombox:GetAttribute("SetupCFrame")
	local physicalContract = boombox:GetAttribute("PhysicalBoundsSize")
	assert(typeof(setupCFrame) == "CFrame", "Income boombox setup CFrame is missing")
	assert(typeof(physicalContract) == "Vector3", "Income boombox physical-bounds contract is missing")
	assert(physicalContract.X <= 1.95 and physicalContract.Y <= 1.15 and physicalContract.Z <= 0.72, "Income boombox authored size exceeds the end table")

	local endTable = environment:FindFirstChild("FormalSofaEndTable", true)
	local endTableTop = endTable and endTable:FindFirstChild("Top")
	local formalSofa = environment:FindFirstChild("FormalGreenFloralSofa", true)
	local formalCarpet = environment:FindFirstChild("FormalLivingOatmealCarpet", true)
	assert(endTable and endTable:IsA("Model") and endTableTop and endTableTop:IsA("BasePart"), "Formal sofa end table is incomplete")
	assert(formalSofa and formalSofa:IsA("Model"), "Formal sofa is missing")
	assert(formalCarpet and formalCarpet:IsA("BasePart"), "Formal living-room carpet is missing")
	local tableUp = endTableTop.CFrame.UpVector.Unit
	local sofaLook = formalSofa:GetPivot().LookVector
	local planarLook = sofaLook - tableUp * sofaLook:Dot(tableUp)
	assert(planarLook.Magnitude > 0.5, "Formal sofa has no usable horizontal facing direction")
	local expectedSetup = CFrame.lookAt(
		endTableTop.Position + tableUp * (endTableTop.Size.Y * 0.5 + 0.025),
		endTableTop.Position + tableUp * (endTableTop.Size.Y * 0.5 + 0.025) + planarLook.Unit,
		tableUp
	)
	assert((setupCFrame.Position - expectedSetup.Position).Magnitude < 0.01, "Income boombox base is detached from the end-table top")
	assert(setupCFrame.LookVector:Dot(expectedSetup.LookVector) > 0.999, "Income boombox does not face into the formal living room")

	for _, requiredPartName in ipairs({
		"MainBody",
		"FrontFacePlate",
		"LeftSpeakerOuterRing",
		"RightSpeakerOuterRing",
		"CassetteDoor",
		"CassetteWindow",
		"EqualizerDisplay",
		"PowerButton",
		"CarryHandle",
		"Antenna",
	}) do
		assert(boombox:FindFirstChild(requiredPartName, true), "Income boombox is missing " .. requiredPartName)
	end

	local minimumX, minimumY, minimumZ = math.huge, math.huge, math.huge
	local maximumX, maximumY, maximumZ = -math.huge, -math.huge, -math.huge
	local authoredPartCount = 0
	local collisionContractCount = 0
	local spotLightCount = 0
	local pointLightCount = 0
	for _, descendant in ipairs(boombox:GetDescendants()) do
		if descendant:IsA("BasePart") then
			authoredPartCount += 1
			assert(descendant.Anchored, descendant.Name .. " is not anchored in its authored living-room pose")
			assert(not descendant.CanCollide and not descendant.CanTouch and not descendant.CanQuery, descendant.Name .. " is active before boombox placement")
			assert(descendant.Transparency == 1, descendant.Name .. " is visible before boombox placement")
			assert(descendant:GetAttribute("BoomboxVisual") == true, descendant.Name .. " is outside the boombox visibility contract")
			local visibleTransparency = descendant:GetAttribute("VisibleTransparency")
			assert(type(visibleTransparency) == "number" and visibleTransparency >= 0 and visibleTransparency <= 1, descendant.Name .. " has no visible-transparency contract")
			assert(type(descendant:GetAttribute("PlacedCanCollide")) == "boolean", descendant.Name .. " has no placed-collision contract")
			if descendant:GetAttribute("PlacedCanCollide") == true then
				collisionContractCount += 1
				assert(descendant.Name == "CollisionHull" and visibleTransparency == 1, "Only the invisible collision hull may become solid")
			end
			if descendant:GetAttribute("BoomboxEffectPart") ~= true then
				for xSign = -1, 1, 2 do
					for ySign = -1, 1, 2 do
						for zSign = -1, 1, 2 do
							local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(
								xSign * descendant.Size.X * 0.5,
								ySign * descendant.Size.Y * 0.5,
								zSign * descendant.Size.Z * 0.5
							))
							local setupLocal = setupCFrame:PointToObjectSpace(corner)
							minimumX = math.min(minimumX, setupLocal.X)
							minimumY = math.min(minimumY, setupLocal.Y)
							minimumZ = math.min(minimumZ, setupLocal.Z)
							maximumX = math.max(maximumX, setupLocal.X)
							maximumY = math.max(maximumY, setupLocal.Y)
							maximumZ = math.max(maximumZ, setupLocal.Z)
							local tableLocal = endTableTop.CFrame:PointToObjectSpace(corner)
							assert(math.abs(tableLocal.X) <= endTableTop.Size.X * 0.5 + 0.01, descendant.Name .. " overhangs the end-table width")
							assert(math.abs(tableLocal.Z) <= endTableTop.Size.Z * 0.5 + 0.01, descendant.Name .. " overhangs the end-table depth")
							local carpetLocal = formalCarpet.CFrame:PointToObjectSpace(corner)
							assert(math.abs(carpetLocal.X) <= formalCarpet.Size.X * 0.5 + 0.02, descendant.Name .. " is outside the formal living room")
							assert(math.abs(carpetLocal.Z) <= formalCarpet.Size.Z * 0.5 + 0.02, descendant.Name .. " is outside the formal living room")
						end
					end
				end
			end
		elseif descendant:IsA("SpotLight") then
			spotLightCount += 1
			assert(not descendant.Enabled, descendant.Name .. " is enabled before playback")
			assert(math.abs(descendant.Brightness - 5.75) < 0.001, descendant.Name .. " has the wrong pronounced brightness")
			assert(math.abs(descendant.Range - 31) < 0.001, descendant.Name .. " has the wrong pronounced range")
			assert(math.abs(descendant.Angle - 74) < 0.001, descendant.Name .. " has the wrong pronounced cone")
			assert(not descendant.Shadows, descendant.Name .. " should not create noisy disco shadows")
		elseif descendant:IsA("PointLight") then
			pointLightCount += 1
			assert(not descendant.Enabled, descendant.Name .. " is enabled before playback")
			assert(descendant.Name == "PartyWash", "Income boombox center wash is incomplete")
			assert(math.abs(descendant.Brightness - 2.35) < 0.001 and math.abs(descendant.Range - 24) < 0.001, "Income boombox center wash has the wrong pronounced-light contract")
			assert(not descendant.Shadows, "Income boombox center wash should not cast noisy shadows")
		end
	end
	assert(authoredPartCount == 50, string.format("Expected 50 authored boombox parts, found %d", authoredPartCount))
	assert(collisionContractCount == 1, "Income boombox must have exactly one placed collision hull")
	assert(spotLightCount == 4 and pointLightCount == 1, "Income boombox must have four spots and one center wash")
	local physicalSize = Vector3.new(maximumX - minimumX, maximumY - minimumY, maximumZ - minimumZ)
	assert(physicalSize.X <= 1.95 and physicalSize.Y <= 1.15 and physicalSize.Z <= 0.72, "Income boombox physical geometry exceeds its compact contract")
	assert(math.abs(physicalSize.X - physicalContract.X) < 0.02 and math.abs(physicalSize.Y - physicalContract.Y) < 0.02 and math.abs(physicalSize.Z - physicalContract.Z) < 0.02, "Income boombox physical-bounds attribute disagrees with its parts")
	assert(minimumY >= -0.01 and minimumY <= 0.04, "Income boombox feet are not resting on the table")

	local sound = boombox:FindFirstChild("BoomboxSound", true)
	assert(sound and sound:IsA("Sound"), "Income boombox sound is missing")
	assert(sound.SoundId == "rbxassetid://86759598635831", "Income boombox uses the wrong audio asset")
	assert(not sound.Looped and not sound.Playing, "Income boombox audio must install stopped and nonlooping")
	assert(math.abs(sound.Volume - 0.7) < 0.001 and math.abs(sound.PlaybackSpeed - 1) < 0.001, "Income boombox audio mix changed")
	assert(sound.RollOffMode == Enum.RollOffMode.InverseTapered and sound.RollOffMinDistance == 7 and sound.RollOffMaxDistance == 68, "Income boombox 3D rolloff changed")
	assert(sound.EmitterSize == 7 and math.abs((sound:GetAttribute("ExpectedDuration") or 0) - 22.465306) < 0.001, "Income boombox audio duration/emitter contract changed")

	local lightRig = boombox:FindFirstChild("DiscoLightRig")
	local floorPools = boombox:FindFirstChild("FloorLightPools")
	assert(lightRig and lightRig:IsA("Folder"), "Income boombox disco rig is missing")
	assert(floorPools and floorPools:IsA("Folder") and #floorPools:GetChildren() == 3, "Income boombox floor-pool rig is incomplete")
	for poolIndex = 1, 3 do
		local pool = floorPools:FindFirstChild("FloorLightPool" .. poolIndex)
		assert(pool and pool:IsA("BasePart"), "Missing boombox floor pool " .. poolIndex)
		assert(pool:GetAttribute("BoomboxFloorPool") == true and pool:GetAttribute("BoomboxEffectPart") == true, pool.Name .. " lost its effect contract")
		assert(pool:GetAttribute("VisibleTransparency") == 1 and pool.Transparency == 1, pool.Name .. " is visible while idle")
		assert(math.abs((pool:GetAttribute("PlayingTransparency") or 0) - 0.56) < 0.001, pool.Name .. " has the wrong pronounced playing transparency")
		for xSign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local corner = pool.CFrame:PointToWorldSpace(Vector3.new(
					0,
					xSign * pool.Size.Y * 0.5,
					zSign * pool.Size.Z * 0.5
				))
				local carpetLocal = formalCarpet.CFrame:PointToObjectSpace(corner)
				assert(math.abs(carpetLocal.X) <= formalCarpet.Size.X * 0.5 + 0.03, pool.Name .. " leaves the formal living-room floor")
				assert(math.abs(carpetLocal.Z) <= formalCarpet.Size.Z * 0.5 + 0.03, pool.Name .. " leaves the formal living-room floor")
			end
		end
	end
	local brandGui = boombox:FindFirstChild("BrandGui", true)
	assert(brandGui and brandGui:IsA("SurfaceGui") and not brandGui.Enabled and brandGui:GetAttribute("EnabledWhenPlaced") == true, "Income boombox badge is not placement-gated")

	local setupAnchor = stations:FindFirstChild("BoomboxSetupAnchor")
	local powerAnchor = stations:FindFirstChild("BoomboxPowerAnchor")
	assert(setupAnchor and setupAnchor:IsA("BasePart") and powerAnchor and powerAnchor:IsA("BasePart"), "Income boombox stations are missing")
	assert(setupAnchor:GetAttribute("FurnitureAnchor") == "FormalSofaEndTable.Top", "Boombox setup is detached from the end table")
	assert(setupAnchor:GetAttribute("AutoSetupRadius") == 5.5, "Boombox automatic setup radius is missing")
	assert(setupAnchor:GetAttribute("GuidanceColor") == "Purple", "Boombox setup guidance is not color-coded purple")
	assert(powerAnchor:GetAttribute("FurnitureAnchor") == "FormalSofaEndTable.Top", "Boombox power control is detached from the end table")
	assert((setupAnchor.Position - (setupCFrame * CFrame.new(0, 0.42, 0)).Position).Magnitude < 0.01, "Boombox setup prompt is misplaced")
	assert((powerAnchor.Position - (setupCFrame * CFrame.new(-0.82, 0.68, -0.39)).Position).Magnitude < 0.01, "Boombox power prompt is misplaced")

	local physicalCenter = Vector3.new(
		(minimumX + maximumX) * 0.5,
		(minimumY + maximumY) * 0.5,
		(minimumZ + maximumZ) * 0.5
	)
	local physicalCFrame = setupCFrame * CFrame.new(physicalCenter)
	local function worldAABB(cframe, size)
		local half = size * 0.5
		local right, up, look = cframe.RightVector, cframe.UpVector, cframe.LookVector
		return cframe.Position, Vector3.new(
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
		local furnishing = environment:FindFirstChild(furnitureName, true)
		assert(furnishing and furnishing:IsA("Model"), "Missing overlap-check furnishing " .. furnitureName)
		local furnishingCF, furnishingSize = furnishing:GetBoundingBox()
		local furnishingCenter, furnishingHalf = worldAABB(furnishingCF, furnishingSize)
		local delta = boomboxCenter - furnishingCenter
		local overlap = math.abs(delta.X) < boomboxHalf.X + furnishingHalf.X
			and math.abs(delta.Y) < boomboxHalf.Y + furnishingHalf.Y
			and math.abs(delta.Z) < boomboxHalf.Z + furnishingHalf.Z
		assert(not overlap, "Income boombox overlaps " .. furnitureName)
	end
end

assert(not boxesOverlap(kitchenCan, fridge), "Kitchen garbage can still intersects the refrigerator")
assert(kitchenCan:FindFirstChild("Can") and kitchenCan.Can.CanCollide, "Kitchen garbage can is walk-through")
local kitchenCanCF, kitchenCanSize = kitchenCan:GetBoundingBox()
local canOnFloor = kitchenFloor.CFrame:PointToObjectSpace(kitchenCanCF.Position)
assert(
	math.abs(canOnFloor.X) + kitchenCanSize.X * 0.5 < kitchenFloor.Size.X * 0.5
		and math.abs(canOnFloor.Z) + kitchenCanSize.Z * 0.5 < kitchenFloor.Size.Z * 0.5,
	"Kitchen garbage can is outside the kitchen floor"
)
local kitchenPickup = stations:FindFirstChild("TrashPickupAnchor")
assert(kitchenPickup and (kitchenPickup.Position - kitchenCanCF.Position).Magnitude < 0.6, "Kitchen trash pickup is not aligned with the indoor can")
local outdoorCF, outdoorSize = outdoorCan:GetBoundingBox()
local garageWestFace = leftWall.Position.X - leftWall.Size.X * 0.5
local garageEastFace = rightWall.Position.X + rightWall.Size.X * 0.5
local canIsWest = outdoorCF.Position.X + outdoorSize.X * 0.5 < garageWestFace - 0.2
local canIsEast = outdoorCF.Position.X - outdoorSize.X * 0.5 > garageEastFace + 0.2
assert(canIsWest or canIsEast, "Outdoor garbage can is not beside the garage exterior")
assert(outdoorCan:FindFirstChild("Can") and outdoorCan.Can.CanCollide, "Outdoor garbage can is walk-through")
local outdoorAnchor = stations:FindFirstChild("OutdoorTrashAnchor")
assert(outdoorAnchor and (outdoorAnchor.Position - outdoorCF.Position).Magnitude < 0.6, "Trash arrow target is not aligned with the outdoor can")

local route = delivery:FindFirstChild("Route")
local truck = delivery:FindFirstChild("CooperDeliveryTruck")
local dropZone = delivery:FindFirstChild("DeliveryDropZone")
assert(route and truck and truck:IsA("Model") and truck.PrimaryPart, "Delivery truck is incomplete")
assert(dropZone and dropZone:IsA("BasePart"), "Delivery drop zone is missing")
for _, name in ipairs({ "TruckSpawn", "TruckApproach", "TruckStop", "TruckExit" }) do
	assert(route:FindFirstChild(name), "Delivery route is missing " .. name)
end
assert(truck:GetAttribute("Hidden") == true, "Idle delivery truck is not marked hidden")
for _, descendant in ipairs(truck:GetDescendants()) do
	if descendant:IsA("BasePart") then
		assert(descendant.Transparency == 1, descendant.Name .. " leaks into the world while the truck is idle")
		assert(not descendant.CanCollide and not descendant.CanTouch and not descendant.CanQuery, descendant.Name .. " blocks the player while the truck is idle")
	elseif descendant:IsA("SurfaceGui") then
		assert(not descendant.Enabled, descendant.Name .. " floats in the world while the truck is hidden")
	end
end

local machine = environment:FindFirstChild("CooperTimeMachine", true)
assert(machine and machine:IsA("Model"), "Cooper Time Machine is missing")
local stages = machine:FindFirstChild("Stages")
assert(stages and #stages:GetChildren() == 11, "All 11 machine stage folders are required")
local screen = machine:FindFirstChild("FamilyTaskProgress", true)
assert(screen and screen:IsA("SurfaceGui"), "Personal machine percentage display is missing")

local teddy = environment:FindFirstChild("MissyDetailedTeddyBear", true)
local rabbit = environment:FindFirstChild("MissyDetailedRabbit", true)
local missyBed = environment:FindFirstChild("MissyWalnutTwinBed", true)
local mattress = missyBed and missyBed:FindFirstChild("Mattress")
assert(teddy and teddy:GetAttribute("FamilyTaskHome") == true, "Missy's teddy is not on its home state")
assert(rabbit and rabbit:GetAttribute("FamilyTaskHome") == true, "Missy's rabbit is not on its home state")
assert(mattress and mattress:IsA("BasePart"), "Missy's actual mattress is missing")
for _, toy in ipairs({ teddy, rabbit }) do
	local localHome = toy:GetAttribute("FamilyTaskHomeLocalCFrame")
	assert(typeof(localHome) == "CFrame", toy.Name .. " has no durable mattress-relative home transform")
	local resolvedHome = mattress.CFrame * localHome
	local compatibilityHome = toy:GetAttribute("FamilyTaskHomeCFrame")
	assert(typeof(compatibilityHome) == "CFrame", toy.Name .. " has no current absolute home mirror")
	assert(cframeClose(compatibilityHome, resolvedHome, 0.05, 1), toy.Name .. " has a stale absolute backyard home")
	assert(cframeClose(toy:GetPivot(), resolvedHome, 0.05, 1), toy.Name .. " is not at its mattress-relative return pose")
	local localPosition = localHome.Position
	assert(math.abs(localPosition.X) < mattress.Size.X * 0.5, toy.Name .. " is outside the mattress width")
	assert(math.abs(localPosition.Z) < mattress.Size.Z * 0.5, toy.Name .. " is outside the mattress length")
	assert(localPosition.Y > mattress.Size.Y * 0.5, toy.Name .. " is not sitting above the mattress")
end
local missyReturn = stations:FindFirstChild("MissyPlushReturnAnchor")
assert(missyReturn:GetAttribute("FurnitureAnchor") == "MissyWalnutTwinBed.Mattress", "Plush return is not attached to Missy's bed")
assert((missyReturn.Position - mattress.Position).Magnitude < 3, "Plush return prompt is not on Missy's actual bed")

local controller = ServerScriptService:FindFirstChild("CooperTaskWorld")
assert(controller and controller:IsA("Script") and controller.Enabled, "CooperTaskWorld controller is unavailable")
for _, marker in ipairs({
	"PromptButtonHoldBegan",
	"PromptButtonHoldEnded",
	"DISH_HOLD_TOLERANCE",
	"serverNow() - session.startedAt",
}) do
	assert(string.find(controller.Source, marker, 1, true), "Dish wash is missing server hold validation marker " .. marker)
end
for _, marker in ipairs({
	"OwnerUserId",
	"DeliveryId",
	"DeliveryCrate_",
	"deliveryRecordsByKey",
	"deliveryRecordsById",
	"DeliveryGuidanceTarget",
	"requestIsStillValid",
	"pendingMachineRecoveries",
	"recoverFamilyTaskCarry",
	"BeerCarryLost",
	"TrashCarryLost",
	"MissyPlushCarryLost",
	"TruckApproach",
	"scheduleMachineRecovery",
	"CharacterRemoving",
	"CharacterAdded",
	"DeliveryPickup",
	"MachineDeliverySpawned",
	"MachinePartInstalled",
	"BeerDelivered",
	"TrashDelivered",
	"FamilyMissyPlush",
	"FamilyTaskHomeCFrame",
	"FamilyTaskHomeLocalCFrame",
	"local function missyToyHomeCFrame(toy)",
	"local homeCFrame = missyToyHomeCFrame(sourceToy) or sourceToy:GetPivot()",
	"local homeCFrame = missyToyHomeCFrame(homeToy)",
	"MissyPlushReturned",
	"PlayerRemoving",
	"allocateDeliverySpawnOffset",
	"DeliverySlotLane",
	"Per-item finalizer",
	"Worker finalizer covers even failures",
	"deliveryInFlightKeys[entry.key] = nil",
	"deliveryRunning = false",
	"Delivery_Boombox_",
	"COOPER SOUND",
	"BoomboxDeliverySpawned",
	"BoomboxCratePicked",
	"BoomboxCarryLost",
	"scheduleBoomboxRecovery",
	"tryBoomboxRecovery",
	"BoomboxSetup",
	"insideBoomboxAutoSetupArea",
	"tryPlaceBoombox(candidate, true)",
	"invokeFamily(\"ReportAction\", player, \"BoomboxPlaced\", {})",
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
	assert(string.find(controller.Source, marker, 1, true), "Task controller is missing " .. marker)
end

-- A paid Time Machine crate must survive a rejected or unavailable profile
-- transition. Commit and verify the authoritative stage before consuming the
-- carried Tool, just like the other permanent delivery purchases.
local machineInstallStart = string.find(controller.Source, 'elseif action == "MachineInstall" then', 1, true)
local machineInstallEnd = machineInstallStart
	and string.find(controller.Source, 'elseif action == "BoomboxSetup" then', machineInstallStart, true)
assert(machineInstallStart and machineInstallEnd, "Machine-install handler is missing")
local machineInstallSource = string.sub(controller.Source, machineInstallStart, machineInstallEnd - 1)
local machineCommitAt = string.find(machineInstallSource, "local installed = invokeFamily(", 1, true)
local machineAcceptedAt = string.find(machineInstallSource, "if installed ~= true", 1, true)
local machineConsumeAt = string.find(machineInstallSource, "clearDeliveryRecord(deliveryRecord, false)", 1, true)
assert(
	machineCommitAt and machineAcceptedAt and machineConsumeAt
		and machineCommitAt < machineAcceptedAt and machineAcceptedAt < machineConsumeAt,
	"Paid machine crate is consumed before the authoritative stage transition is accepted"
)

-- Delivery IDs remain authoritative attributes, while every Backpack slot uses
-- a player-facing Tool.Name. Manual beer delivery must reuse the exact visible
-- six-pack authored for BeerBot instead of exposing the generic wooden crate.
for _, marker in ipairs({
	"tool.Name = displayName",
	"tool.ToolTip = displayName",
	"tool:SetAttribute(\"InternalDeliveryName\", name)",
	"displayName = \"Lone Star Six-Pack\"",
	"local function applyBeerSixPackVisual(tool)",
	"local template = beerBot and beerBot:FindFirstChild(\"BeerCaseVisual\")",
	"local visual = template:Clone()",
	"visual.Name = \"LoneStarSixPackVisual\"",
	"descendant:GetAttribute(\"AutomationActiveTransparency\")",
	"weldToHandle(handle, descendant)",
	"local hasBeerVisual = kind == \"Beer\" and applyBeerSixPackVisual(tool)",
	"if not hasBeerVisual then",
	"tool.Name = \"Kitchen Garbage Bag\"",
	"child:GetAttribute(\"FamilyTrashBag\") == true",
}) do
	assert(string.find(controller.Source, marker, 1, true), "Task controller is missing friendly carry/six-pack behavior: " .. marker)
end
assert(not string.find(controller.Source, "tool.Name = \"FamilyTrashBag\"", 1, true), "Trash bag still exposes its internal identifier in the Backpack")

local automationVisuals = visuals:FindFirstChild("AutomationModels") or visuals
local beerBot = automationVisuals:FindFirstChild("BeerBot")
assert(beerBot and beerBot:IsA("Model"), "BeerBot's authored six-pack source is missing")
local beerCase = beerBot:FindFirstChild("BeerCaseVisual")
assert(beerCase and beerCase:IsA("Model"), "BeerBot has no reusable BeerCaseVisual")
assert(beerCase:GetAttribute("AutomationBeerCaseVisual") == true, "BeerCaseVisual is not marked as the automation beer case")
assert(beerCase:GetAttribute("CaseCanCount") == 6, "BeerCaseVisual must advertise exactly six cans")
assert(beerCase.PrimaryPart == beerCase:FindFirstChild("CaseBody"), "BeerCaseVisual no longer pivots from CaseBody")
for index = 1, 6 do
	local canBody = beerCase:FindFirstChild(string.format("CaseCanBody%02d", index))
	local canTop = beerCase:FindFirstChild(string.format("CaseCanTop%02d", index))
	assert(canBody and canBody:IsA("BasePart"), string.format("BeerCaseVisual is missing can body %02d", index))
	assert(canTop and canTop:IsA("BasePart"), string.format("BeerCaseVisual is missing can top %02d", index))
	assert(type(canBody:GetAttribute("AutomationActiveTransparency")) == "number", canBody.Name .. " has no visible clone transparency")
	assert(type(canTop:GetAttribute("AutomationActiveTransparency")) == "number", canTop.Name .. " has no visible clone transparency")
end
local beerCaseLabel = beerCase:FindFirstChild("TextLabel", true)
assert(beerCaseLabel and beerCaseLabel:IsA("TextLabel") and beerCaseLabel.Text == "LONE STAR\nBEER", "BeerCaseVisual lost its Lone Star label")
local gameClient = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("CooperGame")
assert(gameClient and gameClient:IsA("LocalScript"), "CooperGame client is missing")
for _, marker in ipairs({
	"DirtyDishesInSink",
	"updateDirtyDishesVisibility(snapshot)",
	"LocalTransparencyModifier",
	"workspace.DescendantAdded",
	"FamilyTaskVisual",
	"FamilyTaskAction",
	"updateWorldPrompts(currentSnapshot)",
}) do
	assert(string.find(gameClient.Source, marker, 1, true), "Task client is missing dirty-dish behavior: " .. marker)
end
assert(not string.find(controller.Source, "removeExistingDelivery", 1, true), "A new delivery can still delete the player's other crate")
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
	assert(string.find(controller.Source, laneMarker, 1, true), "Swept-safe delivery allocator is missing " .. laneMarker)
end
assert(string.find(controller.Source, "record.status ~= \"Carried\"", 1, true), "Only a carried paid crate may enter recovery")
assert(string.find(controller.Source, "current.delivery.status ~= \"Install\"", 1, true), "Paid crate recovery is not locked to the install step")
for _, retiredMarker in ipairs({ "CooperProgression", "CooperCrisis", "PanicActive" }) do
	assert(not string.find(controller.Source, retiredMarker, 1, true), "Task world still depends on " .. retiredMarker)
end
for _, removedTask in ipairs({ "MaryLaundry", "MaryShower", "MaryToilet", "GeorgieTire", "TireAdvanced" }) do
	assert(not string.find(controller.Source, removedTask, 1, true), "Task controller still contains removed task " .. removedTask)
end

local gameServer = ServerScriptService:FindFirstChild("CooperGame")
assert(gameServer and gameServer.Source:find("targetHint = record.markerName", 1, true), "Missy's search arrow does not track the selected hiding marker")
assert(gameServer.Source:find("hidden somewhere inside the house", 1, true), "Missy's task text reveals a room instead of keeping the clue generic")
assert(gameServer.Source:find("tool.Name = plushKind == \"Rabbit\" and \"Missy's Lost Rabbit\" or \"Missy's Lost Teddy Bear\"", 1, true), "Missy's carried toys still expose internal Tool names")
assert(gameClient and gameClient.Source:find("or not arrowModel", 1, true), "Task arrow does not recover when its target streams in late")

print(string.format(
	"[CooperTaskWorldAudit] PASS: %d stations, %d hidden locations, truck and 11-stage machine ready",
	13,
	#Config.HiddenLocations
))
return true
