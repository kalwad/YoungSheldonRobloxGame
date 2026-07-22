-- Idempotent garage expansion + unfuse layout for Georgie's living + storm gear.
-- Expands DetachedGarage footprint and places living/storm props in separate bays.
-- Run in Studio edit mode (MCP execute_luau or Command Bar).

local INSTALL_VERSION = "2026-07-11.garage-expand.1"

local environment = workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment, "CooperHouseEnvironment missing")
local garage = environment:FindFirstChild("DetachedGarage")
assert(garage and garage:IsA("Model"), "DetachedGarage missing")
local crisisWorld = environment:FindFirstChild("CooperCrisisWorld")

local foundation = garage:FindFirstChild("GarageFoundation")
local leftWall = garage:FindFirstChild("GarageLeftWall")
local rightWall = garage:FindFirstChild("GarageRightWall")
local backWall = garage:FindFirstChild("GarageBackWall")
local frontLeft = garage:FindFirstChild("GarageFrontLeft")
local frontRight = garage:FindFirstChild("GarageFrontRight")
local header = garage:FindFirstChild("GarageDoorHeader")
local roofFront = garage:FindFirstChild("GarageRoofFront")
local roofBack = garage:FindFirstChild("GarageRoofBack")
assert(foundation and leftWall and rightWall and backWall and header, "Garage shell parts missing")

-- Expand footprint: +4 studs each side in X, +4 studs toward back in Z.
local EXPAND_X = 4
local EXPAND_BACK = 5
local alreadyExpanded = garage:GetAttribute("GarageExpandVersion") ~= nil
local centerX = foundation.Position.X
local frontZ = foundation.Position.Z - foundation.Size.Z * 0.5
local newWidth = foundation.Size.X + (alreadyExpanded and 0 or EXPAND_X * 2)
local newDepth = foundation.Size.Z + (alreadyExpanded and 0 or EXPAND_BACK)
local newCenterZ = frontZ + newDepth * 0.5
local floorY = foundation.Position.Y + foundation.Size.Y * 0.5
local wallY = leftWall.Position.Y
local wallHeight = leftWall.Size.Y

foundation.Size = Vector3.new(newWidth, foundation.Size.Y, newDepth)
foundation.Position = Vector3.new(centerX, foundation.Position.Y, newCenterZ)

leftWall.Size = Vector3.new(leftWall.Size.X, wallHeight, newDepth)
leftWall.Position = Vector3.new(centerX - newWidth * 0.5 + leftWall.Size.X * 0.5, wallY, newCenterZ)
rightWall.Size = Vector3.new(rightWall.Size.X, wallHeight, newDepth)
rightWall.Position = Vector3.new(centerX + newWidth * 0.5 - rightWall.Size.X * 0.5, wallY, newCenterZ)
backWall.Size = Vector3.new(newWidth, wallHeight, backWall.Size.Z)
backWall.Position = Vector3.new(centerX, wallY, newCenterZ + newDepth * 0.5 - backWall.Size.Z * 0.5)

if frontLeft and frontLeft:IsA("BasePart") then
	frontLeft.Position = Vector3.new(centerX - newWidth * 0.5 + frontLeft.Size.X * 0.5 + 0.5, frontLeft.Position.Y, frontZ + frontLeft.Size.Z * 0.5)
end
if frontRight and frontRight:IsA("BasePart") then
	frontRight.Position = Vector3.new(centerX + newWidth * 0.5 - frontRight.Size.X * 0.5 - 0.5, frontRight.Position.Y, frontZ + frontRight.Size.Z * 0.5)
end
header.Size = Vector3.new(math.max(8, header.Size.X), header.Size.Y, header.Size.Z)
header.Position = Vector3.new(centerX, header.Position.Y, frontZ + header.Size.Z * 0.5)

if roofFront and roofFront:IsA("BasePart") then
	roofFront.Size = Vector3.new(newWidth + 1.5, roofFront.Size.Y, roofFront.Size.Z)
	roofFront.Position = Vector3.new(centerX, roofFront.Position.Y, roofFront.Position.Z)
end
if roofBack and roofBack:IsA("BasePart") then
	roofBack.Size = Vector3.new(newWidth + 1.5, roofBack.Size.Y, roofBack.Size.Z)
	roofBack.Position = Vector3.new(centerX, roofBack.Position.Y, newCenterZ + newDepth * 0.15)
end

local innerLeftX = centerX - newWidth * 0.5 + 0.6
local innerRightX = centerX + newWidth * 0.5 - 0.6
local innerFrontZ = frontZ + 1.0
local innerBackZ = newCenterZ + newDepth * 0.5 - 0.8

local function makePart(parent, name, size, cframe, color, material, options)
	options = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = options.CanCollide ~= false
	part.Transparency = options.Transparency or 0
	part.Parent = parent
	return part
end

-- Replace living upgrade with spaced layout.
local oldLiving = garage:FindFirstChild("GeorgieMandyLivingUpgrade_V1")
if oldLiving then
	oldLiving:Destroy()
end
local living = Instance.new("Model")
living.Name = "GeorgieMandyLivingUpgrade_V1"
living:SetAttribute("Residents", "Georgie, Mandy, and baby CeeCee")
living:SetAttribute("InstallVersion", INSTALL_VERSION)
living.Parent = garage

-- Alias expected by panic installers.
living.Name = "GeorgieMandyLivingUpgrade_V1"
local alias = garage:FindFirstChild("GarageLivingArea")
if alias and alias ~= living then
	alias:Destroy()
end
-- ObjectValue alias so FindFirstChild("GarageLivingArea") works via folder wrapper
local livingAlias = Instance.new("ObjectValue")
livingAlias.Name = "GarageLivingAreaRef"
livingAlias.Value = living
livingAlias.Parent = garage
-- Also tag living for dual lookup
living:SetAttribute("GarageLivingArea", true)

local innerWidth = innerRightX - innerLeftX
local innerDepth = innerBackZ - innerFrontZ
local drywallHeight = wallHeight - 0.4
local drywallCenterY = floorY + drywallHeight * 0.5
local garageWallTop = floorY + drywallHeight

makePart(living, "SealedConcreteFloor", Vector3.new(innerWidth, 0.10, innerDepth), CFrame.new(centerX, floorY + 0.05, newCenterZ), Color3.fromRGB(130, 121, 106), Enum.Material.Concrete)
makePart(living, "LeftInteriorDrywall", Vector3.new(0.12, drywallHeight, innerDepth), CFrame.new(innerLeftX, drywallCenterY, newCenterZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "RightInteriorDrywall", Vector3.new(0.12, drywallHeight, innerDepth), CFrame.new(innerRightX, drywallCenterY, newCenterZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "BackInteriorDrywall", Vector3.new(innerWidth, drywallHeight, 0.12), CFrame.new(centerX, drywallCenterY, innerBackZ), Color3.fromRGB(224, 215, 195), Enum.Material.SmoothPlastic)
makePart(living, "FinishedCeiling", Vector3.new(innerWidth, 0.16, innerDepth), CFrame.new(centerX, garageWallTop - 0.08, newCenterZ), Color3.fromRGB(236, 231, 218), Enum.Material.SmoothPlastic)

-- LEFT bay: storm equipment (clear of furniture)
local stormBay = Instance.new("Model")
stormBay.Name = "StormEquipmentBay"
stormBay.Parent = living
local stormX = innerLeftX + 2.4
local stormZ = innerBackZ - 4.5
makePart(stormBay, "StormBayFloorMark", Vector3.new(5.5, 0.06, 8.5), CFrame.new(stormX, floorY + 0.12, stormZ), Color3.fromRGB(72, 90, 78), Enum.Material.Concrete, { CanCollide = false })

-- RIGHT-BACK: bed nook (away from storm bay)
local bed = Instance.new("Model")
bed.Name = "GeorgieMandyBedNook"
bed.Parent = living
local bedX = innerRightX - 3.6
local bedZ = innerBackZ - 3.4
makePart(bed, "BedFrame", Vector3.new(5.8, 0.52, 5.6), CFrame.new(bedX, floorY + 0.52, bedZ), Color3.fromRGB(94, 63, 43), Enum.Material.Wood)
makePart(bed, "Mattress", Vector3.new(5.5, 0.62, 5.3), CFrame.new(bedX, floorY + 1.02, bedZ), Color3.fromRGB(223, 214, 192), Enum.Material.Fabric)
makePart(bed, "Quilt", Vector3.new(5.4, 0.16, 3.2), CFrame.new(bedX, floorY + 1.42, bedZ - 0.7), Color3.fromRGB(91, 113, 130), Enum.Material.Fabric, { CanCollide = false })
makePart(bed, "Headboard", Vector3.new(5.9, 2.6, 0.28), CFrame.new(bedX, floorY + 2.0, innerBackZ - 0.35), Color3.fromRGB(103, 69, 46), Enum.Material.Wood)

-- CeeCee's bassinet stays beside the bed without blocking the aisle.
local bassinet = Instance.new("Model")
bassinet.Name = "CeeCeeBassinet"
bassinet.Parent = living
local bassinetX = bedX - 3.2
local bassinetZ = bedZ - 2.7
makePart(bassinet, "Basket", Vector3.new(3.0, 1.05, 1.65), CFrame.new(bassinetX, floorY + 1.55, bassinetZ), Color3.fromRGB(238, 226, 202), Enum.Material.Wood)
makePart(bassinet, "Mattress", Vector3.new(2.68, 0.22, 1.35), CFrame.new(bassinetX, floorY + 2.06, bassinetZ), Color3.fromRGB(250, 244, 224), Enum.Material.Fabric, { CanCollide = false })
makePart(bassinet, "PinkBlanket", Vector3.new(1.45, 0.10, 1.24), CFrame.new(bassinetX + 0.55, floorY + 2.20, bassinetZ), Color3.fromRGB(235, 169, 190), Enum.Material.Fabric, { CanCollide = false })
for sideIndex, xOffset in ipairs({ -1.15, 1.15 }) do
	makePart(bassinet, "RockingRail" .. sideIndex, Vector3.new(0.22, 0.22, 2.05), CFrame.new(bassinetX + xOffset, floorY + 0.48, bassinetZ), Color3.fromRGB(146, 105, 70), Enum.Material.Wood)
	makePart(bassinet, "Support" .. sideIndex, Vector3.new(0.18, 1.55, 0.18), CFrame.new(bassinetX + xOffset, floorY + 1.0, bassinetZ), Color3.fromRGB(146, 105, 70), Enum.Material.Wood)
end
bassinet.PrimaryPart = bassinet.Basket

-- Nightstand beside bed (separate model, not fused)
local nightstand = Instance.new("Model")
nightstand.Name = "BedsideNightstand"
nightstand.Parent = living
local nsX = bedX - 3.6
local nsZ = bedZ + 0.4
makePart(nightstand, "Cabinet", Vector3.new(1.6, 1.7, 1.6), CFrame.new(nsX, floorY + 0.95, nsZ), Color3.fromRGB(188, 170, 140), Enum.Material.Wood)
makePart(nightstand, "PinkTop", Vector3.new(1.7, 0.12, 1.7), CFrame.new(nsX, floorY + 1.85, nsZ), Color3.fromRGB(232, 170, 190), Enum.Material.SmoothPlastic)
makePart(nightstand, "Lamp", Vector3.new(0.35, 1.4, 0.35), CFrame.new(nsX, floorY + 2.6, nsZ), Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic, { CanCollide = false })

-- LEFT-FRONT: kitchenette with microwave (separate from bed/storm)
local kitchenette = Instance.new("Model")
kitchenette.Name = "CompactKitchenette"
kitchenette.Parent = living
local counterX = innerLeftX + 1.1
local counterZ = innerFrontZ + 6.5
makePart(kitchenette, "BaseCabinet", Vector3.new(1.55, 2.55, 5.2), CFrame.new(counterX, floorY + 1.28, counterZ), Color3.fromRGB(132, 100, 69), Enum.Material.WoodPlanks)
makePart(kitchenette, "LaminateCounter", Vector3.new(1.78, 0.18, 5.4), CFrame.new(counterX + 0.06, floorY + 2.64, counterZ), Color3.fromRGB(217, 198, 157), Enum.Material.SmoothPlastic)
makePart(kitchenette, "Microwave", Vector3.new(1.15, 1.15, 1.85), CFrame.new(counterX + 0.15, floorY + 3.32, counterZ - 0.2), Color3.fromRGB(68, 62, 54), Enum.Material.SmoothPlastic)
makePart(kitchenette, "MicrowaveWindow", Vector3.new(0.08, 0.72, 1.18), CFrame.new(counterX + 0.76, floorY + 3.34, counterZ - 0.3), Color3.fromRGB(35, 39, 38), Enum.Material.Glass, { CanCollide = false })
makePart(kitchenette, "Remote", Vector3.new(0.55, 0.12, 1.1), CFrame.new(counterX + 0.55, floorY + 2.82, counterZ + 1.5), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, { CanCollide = false })

-- RIGHT-FRONT: couch facing inward
local couch = Instance.new("Model")
couch.Name = "PlaidSleeperCouch"
couch.Parent = living
local couchX = innerRightX - 1.4
local couchZ = innerFrontZ + 5.5
makePart(couch, "CouchBack", Vector3.new(0.72, 2.65, 5.5), CFrame.new(innerRightX - 0.45, floorY + 1.78, couchZ), Color3.fromRGB(126, 83, 66), Enum.Material.Fabric)
makePart(couch, "CouchBase", Vector3.new(2.15, 0.55, 5.3), CFrame.new(couchX, floorY + 0.60, couchZ), Color3.fromRGB(94, 61, 50), Enum.Material.Wood)
for seatIndex, zOffset in ipairs({ -1.3, 1.3 }) do
	local seat = Instance.new("Seat")
	seat.Name = "CouchSeat" .. seatIndex
	seat.Size = Vector3.new(2.5, 0.44, 1.9)
	seat.CFrame = CFrame.new(couchX - 0.12, floorY + 1.05, couchZ + zOffset) * CFrame.Angles(0, math.rad(90), 0)
	seat.Color = Color3.fromRGB(126, 83, 66)
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.Parent = couch
end

-- CENTER aisle rug (walk path between zones)
makePart(living, "LivingAreaRug", Vector3.new(6.5, 0.08, 8.0), CFrame.new(centerX + 1.5, floorY + 0.11, newCenterZ - 1.0), Color3.fromRGB(105, 94, 65), Enum.Material.Fabric, { CanCollide = false })

-- Dual-name alias model for microwave rescue lookups
local garageLivingArea = Instance.new("Model")
garageLivingArea.Name = "GarageLivingArea"
garageLivingArea.Parent = garage
-- Keep microwave discoverable under both names via ObjectValue
local mwLink = Instance.new("ObjectValue")
mwLink.Name = "LivingUpgrade"
mwLink.Value = living
mwLink.Parent = garageLivingArea
-- Mirror a lightweight microwave marker at the real microwave position
local mw = kitchenette:FindFirstChild("Microwave")
if mw then
	local marker = mw:Clone()
	marker.Name = "Microwave"
	marker.Transparency = 1
	marker.CanCollide = false
	marker.Parent = garageLivingArea
end

-- Reposition crisis storm stations into storm bay (not fused into bed)
if crisisWorld then
	local locker = crisisWorld:FindFirstChild("StormLocker")
	local straps = crisisWorld:FindFirstChild("StormStrapStation")
	local cabinet = crisisWorld:FindFirstChild("DESFalseCabinet")
	local toolbox = crisisWorld:FindFirstChild("LooseCrisisEquipment") and crisisWorld.LooseCrisisEquipment:FindFirstChild("CrisisToolbox")
	local coolant = crisisWorld:FindFirstChild("LooseCrisisEquipment") and crisisWorld.LooseCrisisEquipment:FindFirstChild("CoolantTank")
	local antenna = crisisWorld:FindFirstChild("LooseCrisisEquipment") and crisisWorld.LooseCrisisEquipment:FindFirstChild("StormAntenna")

	local function moveModel(model, targetCF)
		if not model then
			return
		end
		if model:IsA("Model") then
			model:PivotTo(targetCF)
		elseif model:IsA("BasePart") then
			model.CFrame = targetCF
		end
	end

	-- Storm locker against left-back wall
	moveModel(locker, CFrame.new(stormX - 0.3, floorY + 2.9, stormZ - 2.2))
	-- Straps station forward of locker with gap
	moveModel(straps, CFrame.new(stormX - 0.2, floorY + 2.2, stormZ + 2.6))
	-- False cabinet along left wall mid
	moveModel(cabinet, CFrame.new(innerLeftX + 1.2, floorY + 2.8, newCenterZ + 1.0) * CFrame.Angles(0, math.rad(90), 0))

	if toolbox then
		moveModel(toolbox, CFrame.new(stormX + 1.8, floorY + 0.8, stormZ + 0.5))
	end
	if coolant then
		moveModel(coolant, CFrame.new(stormX + 1.5, floorY + 1.4, stormZ - 0.8) * CFrame.Angles(0, 0, math.rad(90)))
	end
	if antenna then
		moveModel(antenna, CFrame.new(stormX + 2.2, floorY + 2.5, stormZ + 1.8))
	end
end

-- Nudge door model to match expanded header if present
local door = garage:FindFirstChild("InteractiveSectionalGarageDoor")
if door and door:IsA("Model") then
	door:SetAttribute("DoorCenterX", centerX)
	door:SetAttribute("InstallVersion", INSTALL_VERSION)
end

garage:SetAttribute("GarageExpandVersion", INSTALL_VERSION)
garage:SetAttribute("GarageInnerWidth", innerWidth)
garage:SetAttribute("GarageInnerDepth", innerDepth)

return {
	version = INSTALL_VERSION,
	foundationSize = { foundation.Size.X, foundation.Size.Y, foundation.Size.Z },
	foundationPos = { foundation.Position.X, foundation.Position.Y, foundation.Position.Z },
	stormBay = { stormX, stormZ },
	bed = { bedX, bedZ },
	kitchenette = { counterX, counterZ },
	hasGarageLivingArea = garage:FindFirstChild("GarageLivingArea") ~= nil,
}
