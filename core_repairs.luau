-- Core, asset-free repairs for the Cooper house.
--
-- Run this file once in Roblox Studio edit mode (for example, through an
-- execute_luau MCP call). It is intentionally idempotent: generated helpers
-- are rebuilt under HouseCoreRepairs, and one-time transforms are derived from
-- stored baseline CFrames instead of accumulating on every run.

local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment, "workspace.CooperHouseEnvironment was not found")

local house = environment:FindFirstChild("CooperHouse")
assert(house and house:IsA("Model"), "workspace.CooperHouseEnvironment.CooperHouse was not found")

local REPAIR_VERSION = "1.0-core-repairs"
local BASELINE_ATTRIBUTE = "HouseCoreRepairsBaselineCFrame"
local IVORY = Color3.fromRGB(232, 229, 218)
local IVORY_DARK = Color3.fromRGB(218, 214, 198)
local DARK_WATER = Color3.fromRGB(88, 126, 137)
local METAL = Color3.fromRGB(118, 122, 117)

local summary = {
	deleted = 0,
	moved = 0,
	seats = 0,
	seatTargets = 0,
	lampProxies = 0,
	books = 0,
	warnings = {},
}

local function noteWarning(message)
	table.insert(summary.warnings, message)
	warn("[HouseCoreRepairs] " .. message)
end

local function descendantsNamed(root, exactName)
	local matches = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == exactName then
			table.insert(matches, descendant)
		end
	end
	return matches
end

local function findNamed(root, exactName)
	return root:FindFirstChild(exactName, true)
end

local function destroyAllNamed(root, exactName)
	local matches = descendantsNamed(root, exactName)
	for _, object in ipairs(matches) do
		object:Destroy()
		summary.deleted += 1
	end
	return #matches
end

local function replaceContainer(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	return object
end

local function getPVCurrentCFrame(object)
	if object:IsA("BasePart") then
		return object.CFrame
	elseif object:IsA("Model") then
		return object:GetPivot()
	end
	return nil
end

local function setPVCFrame(object, targetCFrame)
	if object:IsA("BasePart") then
		object.CFrame = targetCFrame
	elseif object:IsA("Model") then
		object:PivotTo(targetCFrame)
	end
end

local function baselineCFrame(object)
	local stored = object:GetAttribute(BASELINE_ATTRIBUTE)
	if typeof(stored) == "CFrame" then
		return stored
	end

	local current = getPVCurrentCFrame(object)
	if current then
		object:SetAttribute(BASELINE_ATTRIBUTE, current)
	end
	return current
end

local function horizontalUnit(vector, fallback)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < 0.001 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return horizontal.Unit
end

local function findSeatPart(model)
	local candidate = model:FindFirstChild("Seat", true)
	if candidate and candidate:IsA("BasePart") then
		return candidate
	end
	return nil
end

local function translateModelXZ(model, targetXZ)
	local pivot = model:GetPivot()
	local delta = Vector3.new(targetXZ.X - pivot.Position.X, 0, targetXZ.Z - pivot.Position.Z)
	model:PivotTo(pivot + delta)
end

local function aimModelAt(model, targetPosition)
	local facingPart = findSeatPart(model)
	local origin = facingPart and facingPart.Position or model:GetPivot().Position
	local currentLook = horizontalUnit(
		facingPart and facingPart.CFrame.LookVector or model:GetPivot().LookVector,
		Vector3.new(0, 0, -1)
	)
	local desiredLook = horizontalUnit(targetPosition - origin, currentLook)
	local angle = math.atan2(currentLook:Cross(desiredLook).Y, currentLook:Dot(desiredLook))
	if math.abs(angle) < 0.0001 then
		return
	end

	local pivot = model:GetPivot()
	local rotateAroundPivot = CFrame.new(pivot.Position)
		* CFrame.Angles(0, angle, 0)
		* CFrame.new(-pivot.Position)
	model:PivotTo(rotateAroundPivot * pivot)
end

local function makeAnchoredPart(parent, name, size, cframe, color, material, canCollide, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Parent = parent
	return part
end

local recordingId = nil
local recordingStarted = false
do
	local ok, result = pcall(function()
		return ChangeHistoryService:TryBeginRecording(
			"HouseCoreRepairs",
			"Repair Cooper house core geometry and seating"
		)
	end)
	if ok and result then
		recordingId = result
		recordingStarted = true
	else
		pcall(function()
			ChangeHistoryService:SetWaypoint("Before Cooper House Core Repairs")
		end)
	end
end

local ok, failure = xpcall(function()
	-- Reuse the marker itself, but rebuild generated children every run. This
	-- keeps reruns corrective without duplicating Seats or collision proxies.
	local marker = house:FindFirstChild("HouseCoreRepairs")
	if marker and not marker:IsA("Model") then
		marker:Destroy()
		marker = nil
	end
	if not marker then
		marker = Instance.new("Model")
		marker.Name = "HouseCoreRepairs"
		marker.Parent = house
	end
	marker:SetAttribute("Version", REPAIR_VERSION)
	marker:SetAttribute("Purpose", "Idempotent functional helpers for the Cooper house")

	local seatingContainer = replaceContainer(marker, "Model", "FunctionalSeating")
	local lampCollisionContainer = replaceContainer(marker, "Model", "LampCollision")

	-- Remove the two decorative diagonal porch brackets. Removing by exact name
	-- also cleans up a partially duplicated prior build without touching posts.
	local bracketCount = destroyAllNamed(house, "PorchBracket")
	if bracketCount == 0 then
		-- Zero is normal on an idempotent rerun.
	elseif bracketCount ~= 2 then
		noteWarning("Expected two PorchBracket parts, removed " .. tostring(bracketCount))
	end

	-- Turn the glider around in place. The original pivot is stored once, so a
	-- second run resolves to the same target rather than adding another 180°.
	local porchGlider = findNamed(house, "PorchGlider")
	if porchGlider and porchGlider:IsA("Model") then
		local originalPivot = baselineCFrame(porchGlider)
		if originalPivot then
			porchGlider:PivotTo(originalPivot * CFrame.Angles(0, math.pi, 0))
			summary.moved += 1
		end
	else
		noteWarning("PorchGlider model was not found")
	end

	-- Center 5501 on the actual center-wall panel and put it just outside that
	-- panel's near face. The sign keeps its existing rotation and GUI contents.
	local porchCenterWall = findNamed(house, "PorchCenterWall")
	local houseNumber = findNamed(house, "HouseNumber5501")
	if porchCenterWall and porchCenterWall:IsA("BasePart") and houseNumber then
		local numberBoxCFrame
		local numberBoxSize
		if houseNumber:IsA("BasePart") then
			numberBoxCFrame = houseNumber.CFrame
			numberBoxSize = houseNumber.Size
		elseif houseNumber:IsA("Model") then
			numberBoxCFrame, numberBoxSize = houseNumber:GetBoundingBox()
		end

		if numberBoxCFrame and numberBoxSize then
			local currentLocal = porchCenterWall.CFrame:PointToObjectSpace(numberBoxCFrame.Position)
			local side = currentLocal.Z >= 0 and 1 or -1
			if math.abs(currentLocal.Z) < 0.01 then
				side = -1
			end
			local yLimit = math.max(0, (porchCenterWall.Size.Y - numberBoxSize.Y) / 2 - 0.03)
			local targetLocal = Vector3.new(
				0,
				math.clamp(currentLocal.Y, -yLimit, yLimit),
				side * (porchCenterWall.Size.Z / 2 + numberBoxSize.Z / 2 + 0.025)
			)
			local targetCenter = porchCenterWall.CFrame:PointToWorldSpace(targetLocal)
			local delta = targetCenter - numberBoxCFrame.Position
			if houseNumber:IsA("BasePart") then
				houseNumber.CFrame = houseNumber.CFrame + delta
			else
				houseNumber:PivotTo(houseNumber:GetPivot() + delta)
			end
			summary.moved += 1
		else
			noteWarning("HouseNumber5501 is not a movable part or model")
		end
	else
		noteWarning("PorchCenterWall or HouseNumber5501 was not found")
	end

	-- Shift the complete hutch assembly by the requested +2.62 world X. Named
	-- candidates nested inside another named candidate are skipped to prevent a
	-- model and its children from receiving the translation twice.
	local hutchCandidates = {}
	local hutchCandidateSet = {}
	for _, object in ipairs(house:GetDescendants()) do
		local isHutchPiece = object.Name == "DiningChinaHutch"
			or object.Name == "DisplayedChina"
			or string.find(object.Name, "HutchHorizontalShelf", 1, true) == 1
		if isHutchPiece and (object:IsA("BasePart") or object:IsA("Model")) then
			table.insert(hutchCandidates, object)
			hutchCandidateSet[object] = true
		end
	end
	for _, object in ipairs(hutchCandidates) do
		local nestedInCandidate = false
		local ancestor = object.Parent
		while ancestor and ancestor ~= house do
			if hutchCandidateSet[ancestor] then
				nestedInCandidate = true
				break
			end
			ancestor = ancestor.Parent
		end
		if not nestedInCandidate then
			local originalCFrame = baselineCFrame(object)
			if originalCFrame then
				setPVCFrame(object, originalCFrame + Vector3.new(2.62, 0, 0))
				summary.moved += 1
			end
		end
	end
	if #hutchCandidates == 0 then
		noteWarning("Dining hutch assembly was not found")
	end

	-- Remove the loose throw and the five protruding placeholder hall photos.
	destroyAllNamed(house, "DenCrochetThrow")
	for index = 1, 5 do
		destroyAllNamed(house, "HallFamilyPhoto" .. tostring(index))
	end
	-- These two deep wall returns create unnecessary fins in the rear hallway.
	-- Keep the opening header/jamb trim, but clear the walking corridor.
	destroyAllNamed(house, "HallVestibuleLeftReturn")
	destroyAllNamed(house, "HallVestibuleRightReturn")

	-- Put the rust chair opposite the formal sofa, outside the front-door lane,
	-- then rotate its actual Seat direction toward the sofa.
	local rustChair = findNamed(house, "FormalRustButtonChair")
	local formalSofa = findNamed(house, "FormalGreenFloralSofa")
	if rustChair and rustChair:IsA("Model") and formalSofa and formalSofa:IsA("Model") then
		local sofaSeat = findSeatPart(formalSofa)
		if sofaSeat then
			local sofaFront = horizontalUnit(sofaSeat.CFrame.LookVector)
			local sofaRight = horizontalUnit(sofaSeat.CFrame.RightVector, Vector3.new(1, 0, 0))
			local clearEntryPosition = sofaSeat.Position + sofaFront * 11.4 + sofaRight * 1.25
			translateModelXZ(rustChair, clearEntryPosition)
			aimModelAt(rustChair, sofaSeat.Position)
			summary.moved += 1
		else
			noteWarning("FormalGreenFloralSofa has no Seat part to use as a layout reference")
		end
	else
		noteWarning("FormalRustButtonChair or FormalGreenFloralSofa was not found")
	end

	-- Keep George's recliner where it is, but make its seating direction point
	-- directly at the CRT rather than toward the patio/wall.
	local georgeRecliner = findNamed(house, "GeorgeOliveRecliner")
	local television = findNamed(house, "WoodCabinetCRTTelevision")
	if georgeRecliner and georgeRecliner:IsA("Model") and television then
		local televisionPosition
		if television:IsA("Model") then
			local screen = television:FindFirstChild("CurvedGlassScreen", true)
			televisionPosition = screen and screen:IsA("BasePart") and screen.Position or television:GetPivot().Position
		elseif television:IsA("BasePart") then
			televisionPosition = television.Position
		end
		if televisionPosition then
			aimModelAt(georgeRecliner, televisionPosition)
			summary.moved += 1
		end
	else
		noteWarning("GeorgeOliveRecliner or WoodCabinetCRTTelevision was not found")
	end

	-- Rebuild the bathroom toilet from coherent primitive geometry. On its first
	-- run, placement and facing are inferred from the named old bowl/tank; the
	-- resulting base CFrame is stored on the replacement for exact future reruns.
	do
		local oldToilet = findNamed(house, "SideFacingIvoryToilet")
		local toiletParent = oldToilet and oldToilet.Parent or findNamed(house, "FurnitureAndProps") or house
		local baseCFrame = oldToilet and oldToilet:GetAttribute("CoreRepairBaseCFrame") or nil
		local toiletScale = oldToilet and oldToilet:GetAttribute("CoreRepairScale") or nil

		if typeof(baseCFrame) ~= "CFrame" then
			local tank = oldToilet and oldToilet:FindFirstChild("WhiteToiletTank", true) or nil
			local bowl = oldToilet and oldToilet:FindFirstChild("WhiteToiletBowl", true) or nil
			if not (tank and tank:IsA("BasePart")) then
				tank = nil
			end
			if not (bowl and bowl:IsA("BasePart")) then
				bowl = nil
			end

			if bowl then
				toiletScale = math.clamp(bowl.Size.Y / 1.25, 0.80, 1.40)
			elseif tank then
				toiletScale = math.clamp(tank.Size.Y / 2.60, 0.80, 1.40)
			else
				local scaleReference = porchCenterWall and porchCenterWall:IsA("BasePart") and porchCenterWall.Size.X / 3.75 or 1
				toiletScale = math.clamp(scaleReference, 0.80, 1.40)
			end

			local tankPosition = tank and tank.Position or Vector3.new(28.0, 3.15, 23.8) * toiletScale
			local bowlPosition = bowl and bowl.Position or Vector3.new(26.85, 1.95, 23.8) * toiletScale
			local front = horizontalUnit(bowlPosition - tankPosition, Vector3.new(-1, 0, 0))
			local floorY = (bowlPosition.Y - (bowl and bowl.Size.Y / 2 or 0.625 * toiletScale))

			if oldToilet then
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = {oldToilet, marker}
				local startY = math.max(tankPosition.Y, bowlPosition.Y) + 3.5 * toiletScale
				local hit = Workspace:Raycast(
					Vector3.new(bowlPosition.X, startY, bowlPosition.Z),
					Vector3.new(0, -8 * toiletScale, 0),
					raycastParams
				)
				if hit and hit.Position.Y < bowlPosition.Y then
					floorY = hit.Position.Y
				end
			end

			local origin = Vector3.new(bowlPosition.X, floorY, bowlPosition.Z)
			baseCFrame = CFrame.lookAt(origin, origin + front)
		end

		toiletScale = type(toiletScale) == "number" and toiletScale or 1
		if oldToilet then
			oldToilet:Destroy()
			summary.deleted += 1
		end

		local toilet = Instance.new("Model")
		toilet.Name = "SideFacingIvoryToilet"
		toilet:SetAttribute("CoreRepairBaseCFrame", baseCFrame)
		toilet:SetAttribute("CoreRepairScale", toiletScale)
		toilet:SetAttribute("RebuiltBy", REPAIR_VERSION)

		local function toiletPart(name, size, offset, color, canCollide, shape, extraRotation)
			local cframe = baseCFrame * CFrame.new(offset * toiletScale)
			if extraRotation then
				cframe *= extraRotation
			end
			return makeAnchoredPart(
				toilet,
				name,
				size * toiletScale,
				cframe,
				color or IVORY,
				Enum.Material.SmoothPlastic,
				canCollide,
				shape
			)
		end

		toiletPart("PedestalBase", Vector3.new(1.30, 0.22, 1.45), Vector3.new(0, 0.12, 0.16), IVORY_DARK, true)
		toiletPart("IvoryPedestal", Vector3.new(1.10, 1.22, 1.28), Vector3.new(0, 0.70, 0.14), IVORY, true, "Ball")
		toiletPart("WhiteToiletBowl", Vector3.new(1.88, 1.12, 2.18), Vector3.new(0, 1.36, -0.24), IVORY, true, "Ball")
		toiletPart("BowlWater", Vector3.new(0.08, 1.22, 1.42), Vector3.new(0, 1.78, -0.33), DARK_WATER, false, "Cylinder", CFrame.Angles(0, 0, math.pi / 2))

		-- Flat thin U-shaped toilet seat with rounded front tips and an upright lid.
		local seatCenter = Vector3.new(0, 1.95, -0.28)
		local seatRadiusX = 0.76
		local seatRadiusZ = 0.84
		local thickness = 0.10
		local ringWidth = 0.30
		local seatSegments = 32
		local openFrontHalfAngle = math.rad(30)
		local frontAngle = -math.pi / 2
		for index = 0, seatSegments - 1 do
			local angle = (index + 0.5) / seatSegments * math.pi * 2 - math.pi / 2
			local deltaFront = math.abs(((angle - frontAngle + math.pi) % (math.pi * 2)) - math.pi)
			if deltaFront > openFrontHalfAngle then
				local localX = math.cos(angle) * seatRadiusX
				local localZ = math.sin(angle) * seatRadiusZ
				local tangent = math.atan2(seatRadiusZ * math.cos(angle), -seatRadiusX * math.sin(angle))
				local chord = (2 * math.pi * ((seatRadiusX + seatRadiusZ) * 0.5) / seatSegments) * 1.22
				toiletPart(
					"ToiletSeatRing" .. index,
					Vector3.new(chord, thickness, ringWidth),
					seatCenter + Vector3.new(localX, 0, localZ),
					IVORY_DARK,
					false,
					nil,
					CFrame.Angles(0, -tangent, 0)
				)
			end
		end
		for _, sign in ipairs({ -1, 1 }) do
			local tipAngle = frontAngle + sign * (openFrontHalfAngle + math.rad(2))
			local tipPos = seatCenter + Vector3.new(math.cos(tipAngle) * seatRadiusX, 0, math.sin(tipAngle) * seatRadiusZ)
			toiletPart(
				sign < 0 and "ToiletSeatTipLeft" or "ToiletSeatTipRight",
				Vector3.new(thickness, ringWidth * 0.95, ringWidth * 0.95),
				tipPos,
				IVORY_DARK,
				false,
				"Cylinder",
				CFrame.Angles(0, 0, math.rad(90))
			)
		end
		toiletPart("ToiletSeatHingeLeft", Vector3.new(0.12, 0.10, 0.14), Vector3.new(-0.30, 1.98, 0.48), METAL, false)
		toiletPart("ToiletSeatHingeRight", Vector3.new(0.12, 0.10, 0.14), Vector3.new(0.30, 1.98, 0.48), METAL, false)
		toiletPart(
			"ToiletSeatLid",
			Vector3.new(1.55, 1.62, 0.10),
			Vector3.new(0, 2.82, 0.58),
			IVORY,
			false,
			nil,
			CFrame.Angles(math.rad(-12), 0, 0)
		)

		toiletPart("TankConnector", Vector3.new(1.10, 0.72, 0.64), Vector3.new(0, 1.38, 0.72), IVORY, true)
		toiletPart("WhiteToiletTank", Vector3.new(1.78, 2.42, 0.86), Vector3.new(0, 2.19, 1.03), IVORY, true)
		toiletPart("TankLid", Vector3.new(1.94, 0.16, 1.00), Vector3.new(0, 3.43, 1.03), IVORY_DARK, false)
		toiletPart("ChromeFlushHandle", Vector3.new(0.18, 0.24, 0.54), Vector3.new(-0.98, 2.58, 0.85), METAL, false)
		toilet.Parent = toiletParent
	end

	-- Replace the intersecting paperback row with two short, shelf-aligned rows.
	-- Each book is placed in the local coordinate space of its supporting shelf.
	do
		local bookcase = findNamed(house, "WhiteDenBuiltInBookcase")
		if bookcase and bookcase:IsA("Model") then
			for _, oldRow in ipairs(descendantsNamed(bookcase, "PaperbackRow")) do
				oldRow:Destroy()
				summary.deleted += 1
			end
			local oldReplacement = bookcase:FindFirstChild("CoreRepairedBooks")
			if oldReplacement then
				oldReplacement:Destroy()
			end
			for _, object in ipairs(bookcase:GetDescendants()) do
				if object:IsA("BasePart") and string.match(object.Name, "^Book%d+$") then
					object:Destroy()
					summary.deleted += 1
				end
			end

			local shelves = {}
			for _, object in ipairs(bookcase:GetDescendants()) do
				if object:IsA("BasePart") and string.find(object.Name, "HorizontalShelf", 1, true) == 1 then
					table.insert(shelves, object)
				end
			end
			table.sort(shelves, function(a, b)
				return a.Position.Y < b.Position.Y
			end)

			if #shelves >= 2 then
				local repairedBooks = Instance.new("Model")
				repairedBooks.Name = "CoreRepairedBooks"
				repairedBooks:SetAttribute("RebuiltBy", REPAIR_VERSION)
				repairedBooks.Parent = bookcase
				local palette = {
					Color3.fromRGB(155, 53, 43),
					Color3.fromRGB(55, 82, 103),
					Color3.fromRGB(127, 113, 54),
					Color3.fromRGB(151, 116, 77),
				}
				local firstShelfIndex = #shelves >= 4 and 2 or 1
				for row = 1, math.min(2, #shelves - firstShelfIndex + 1) do
					local shelf = shelves[firstShelfIndex + row - 1]
					local count = 4
					local width = math.min(0.32, shelf.Size.X / 9)
					local gap = math.min(0.09, shelf.Size.X / 36)
					local rowWidth = count * width + (count - 1) * gap
					local startX = -math.min(shelf.Size.X * 0.22, math.max(0, (shelf.Size.X - rowWidth) / 2))
					for index = 1, count do
						local height = 0.82 + ((index + row) % 3) * 0.12
						local depth = math.min(0.78, shelf.Size.Z * 0.66)
						local localX = startX + (index - (count + 1) / 2) * (width + gap)
						local localY = shelf.Size.Y / 2 + height / 2 + 0.025
						makeAnchoredPart(
							repairedBooks,
							string.format("Shelf%dBook%d", row, index),
							Vector3.new(width, height, depth),
							shelf.CFrame * CFrame.new(localX, localY, 0),
							palette[((index + row - 2) % #palette) + 1],
							Enum.Material.SmoothPlastic,
							false
						)
						summary.books += 1
					end
				end
			else
				noteWarning("WhiteDenBuiltInBookcase has fewer than two HorizontalShelf parts")
			end
		else
			noteWarning("WhiteDenBuiltInBookcase model was not found")
		end
	end

	-- Make every named chair/recliner/rocker, both sofas, and the porch glider
	-- genuinely usable. Seats are invisible and slightly above the visual seat
	-- surface. Sofas get three places and the glider gets two.
	do
		local seatingTargets = {}
		for _, object in ipairs(house:GetDescendants()) do
			if object:IsA("Model") and not object:IsDescendantOf(marker) then
				local lowerName = string.lower(object.Name)
				local isSeating = string.find(lowerName, "chair", 1, true)
					or string.find(lowerName, "recliner", 1, true)
					or string.find(lowerName, "rocker", 1, true)
					or string.find(lowerName, "sofa", 1, true)
					or string.find(lowerName, "couch", 1, true)
					or object.Name == "PorchGlider"
				if isSeating and findSeatPart(object) then
					table.insert(seatingTargets, object)
				end
			end
		end
		table.sort(seatingTargets, function(a, b)
			return a:GetFullName() < b:GetFullName()
		end)

		for targetIndex, target in ipairs(seatingTargets) do
			local sourceSeat = findSeatPart(target)
			local lowerName = string.lower(target.Name)
			local placeCount = 1
			if string.find(lowerName, "sofa", 1, true) or string.find(lowerName, "couch", 1, true) then
				placeCount = 3
			elseif target.Name == "PorchGlider" then
				placeCount = 2
			end

			-- Dining chairs were originally assembled from non-collidable slats.
			-- Enable their physical structure (and the equivalent structure on all
			-- other seating) while leaving plush/decorative overlays non-collidable.
			for _, part in ipairs(target:GetDescendants()) do
				if part:IsA("BasePart") then
					local lowerPartName = string.lower(part.Name)
					local decorative = string.find(lowerPartName, "plush", 1, true)
						or string.find(lowerPartName, "animal", 1, true)
						or string.find(lowerPartName, "plaidvertical", 1, true)
						or string.find(lowerPartName, "plaidhorizontal", 1, true)
					if not decorative then
						part.CanCollide = true
						part.CanQuery = true
					end
				end
			end

			for placeIndex = 1, placeCount do
				local offsetX = 0
				if placeCount == 3 then
					offsetX = (placeIndex - 2) * sourceSeat.Size.X * 0.30
				elseif placeCount == 2 then
					offsetX = (placeIndex == 1 and -1 or 1) * sourceSeat.Size.X * 0.24
				end

				local functionalSeat = Instance.new("Seat")
				functionalSeat.Name = string.format("FunctionalSeat_%02d_%s_%d", targetIndex, target.Name, placeIndex)
				functionalSeat.Size = Vector3.new(
					math.clamp(sourceSeat.Size.X * (placeCount == 1 and 0.72 or 0.26), 1.15, 2.15),
					0.18,
					math.clamp(sourceSeat.Size.Z * 0.64, 1.10, 1.75)
				)
				local functionalSeatCFrame = sourceSeat.CFrame * CFrame.new(
					offsetX,
					sourceSeat.Size.Y / 2 + functionalSeat.Size.Y / 2 + 0.035,
					-sourceSeat.Size.Z * 0.07
				)
				-- The porch glider's original decorative Seat has a neutral
				-- orientation that points opposite its physical front.
				if target.Name == "PorchGlider" then
					functionalSeatCFrame *= CFrame.Angles(0, math.pi, 0)
				end
				functionalSeat.CFrame = functionalSeatCFrame
				functionalSeat.Anchored = true
				functionalSeat.CanCollide = false
				functionalSeat.CanTouch = true
				functionalSeat.CanQuery = true
				functionalSeat.CastShadow = false
				functionalSeat.Transparency = 1
				functionalSeat.Disabled = false
				functionalSeat:SetAttribute("SourceFurniture", target:GetFullName())
				functionalSeat.Parent = seatingContainer
				summary.seats += 1
			end
			summary.seatTargets += 1
		end

		if #seatingTargets == 0 then
			noteWarning("No chair, recliner, rocker, sofa, couch, or glider models with Seat parts were found")
		end
	end

	-- Build conservative invisible collision columns for lamp models and grouped
	-- standalone *Lamp* parts. The X/Z footprint is capped so a wide shade does
	-- not close a nearby walking lane, while the full lamp height remains solid.
	do
		local function partsInside(object)
			local parts = {}
			for _, descendant in ipairs(object:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Transparency < 1 then
					table.insert(parts, descendant)
				end
			end
			return parts
		end

		local function computeWorldAABB(parts)
			local minX, minY, minZ = math.huge, math.huge, math.huge
			local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
			for _, part in ipairs(parts) do
				local half = part.Size / 2
				for sx = -1, 1, 2 do
					for sy = -1, 1, 2 do
						for sz = -1, 1, 2 do
							local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							minX = math.min(minX, corner.X)
							minY = math.min(minY, corner.Y)
							minZ = math.min(minZ, corner.Z)
							maxX = math.max(maxX, corner.X)
							maxY = math.max(maxY, corner.Y)
							maxZ = math.max(maxZ, corner.Z)
						end
					end
				end
			end
			if minX == math.huge then
				return nil, nil
			end
			return Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2),
				Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
		end

		local function addLampProxy(parts, name)
			local center, rawSize = computeWorldAABB(parts)
			if not center then
				return
			end
			local proxy = makeAnchoredPart(
				lampCollisionContainer,
				name,
				Vector3.new(
					math.clamp(rawSize.X, 0.65, 2.60),
					math.max(rawSize.Y, 0.70),
					math.clamp(rawSize.Z, 0.65, 2.60)
				),
				CFrame.new(center),
				Color3.fromRGB(255, 0, 255),
				Enum.Material.SmoothPlastic,
				true
			)
			proxy.Transparency = 1
			proxy.CastShadow = false
			proxy:SetAttribute("Purpose", "Lamp collision proxy")
			summary.lampProxies += 1
		end

		local lampModels = {}
		local lampModelSet = {}
		for _, object in ipairs(house:GetDescendants()) do
			if object:IsA("Model") and not object:IsDescendantOf(marker)
				and string.find(string.lower(object.Name), "lamp", 1, true) then
				table.insert(lampModels, object)
				lampModelSet[object] = true
			end
		end

		for index, model in ipairs(lampModels) do
			local nestedInLampModel = false
			local ancestor = model.Parent
			while ancestor and ancestor ~= house do
				if lampModelSet[ancestor] then
					nestedInLampModel = true
					break
				end
				ancestor = ancestor.Parent
			end
			if not nestedInLampModel then
				addLampProxy(partsInside(model), string.format("LampModelProxy_%02d_%s", index, model.Name))
			end
		end

		local standaloneGroups = {}
		for _, part in ipairs(house:GetDescendants()) do
			if part:IsA("BasePart") and not part:IsDescendantOf(marker) then
				local lowerName = string.lower(part.Name)
				local _, lampEnd = string.find(lowerName, "lamp", 1, true)
				if lampEnd then
					local insideLampModel = false
					local ancestor = part.Parent
					while ancestor and ancestor ~= house do
						if lampModelSet[ancestor] then
							insideLampModel = true
							break
						end
						ancestor = ancestor.Parent
					end
					if not insideLampModel then
						local prefix = string.sub(part.Name, 1, lampEnd)
						local groupKey = part.Parent:GetFullName() .. "::" .. prefix
						if lowerName == "lamp" then
							groupKey ..= "::" .. part:GetFullName()
						end
						standaloneGroups[groupKey] = standaloneGroups[groupKey] or {name = prefix, parts = {}}
						table.insert(standaloneGroups[groupKey].parts, part)
					end
				end
			end
		end

		local standaloneKeys = {}
		for key in pairs(standaloneGroups) do
			table.insert(standaloneKeys, key)
		end
		table.sort(standaloneKeys)
		for index, key in ipairs(standaloneKeys) do
			local group = standaloneGroups[key]
			local safeName = string.gsub(group.name, "[^%w_]", "")
			addLampProxy(group.parts, string.format("StandaloneLampProxy_%02d_%s", index, safeName))
		end

		if summary.lampProxies == 0 then
			noteWarning("No lamp models or standalone lamp parts were found for collision proxies")
		end
	end

	marker:SetAttribute("SeatCount", summary.seats)
	marker:SetAttribute("LampProxyCount", summary.lampProxies)
	marker:SetAttribute("BookCount", summary.books)
end, function(message)
	return tostring(message) .. "\n" .. debug.traceback()
end)

if recordingStarted then
	pcall(function()
		ChangeHistoryService:FinishRecording(
			recordingId,
			ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
		)
	end)
elseif ok then
	pcall(function()
		ChangeHistoryService:SetWaypoint("Repair Cooper House Core Geometry and Seating")
	end)
end

if not ok then
	error(failure)
end

print(string.format(
	"[HouseCoreRepairs] complete: %d seats across %d targets, %d lamp proxies, %d rebuilt books, %d moved/reoriented objects, %d deletions",
	summary.seats,
	summary.seatTargets,
	summary.lampProxies,
	summary.books,
	summary.moved,
	summary.deleted
))

return {
	success = true,
	version = REPAIR_VERSION,
	house = house:GetFullName(),
	seats = summary.seats,
	seatTargets = summary.seatTargets,
	lampProxies = summary.lampProxies,
	books = summary.books,
	movedOrReoriented = summary.moved,
	deleted = summary.deleted,
	warnings = summary.warnings,
}
