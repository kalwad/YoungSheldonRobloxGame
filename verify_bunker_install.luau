--!nonstrict
-- High-signal edit/runtime audit for the Cooper backyard bunker.
-- Safe to run repeatedly from Studio's command bar or an MCP edit/runtime target.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local EXPECTED_VERSION = "2.0.0"
local checks = 0

local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local function need(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	check(item ~= nil, string.format(
		"Missing %s.%s",
		parent and parent:GetFullName() or "nil",
		name
	))
	if className then
		check(item:IsA(className), item:GetFullName() .. " must be a " .. className)
	end
	return item
end

local function needDescendant(parent, name, className)
	local item = parent and parent:FindFirstChild(name, true)
	check(item ~= nil, string.format(
		"Missing descendant %s under %s",
		name,
		parent and parent:GetFullName() or "nil"
	))
	if className then
		check(item:IsA(className), item:GetFullName() .. " must be a " .. className)
	end
	return item
end

local function liveScript(parent, name, className, minimumSourceLength)
	local scriptObject = need(parent, name, className)
	check(not scriptObject.Disabled, scriptObject:GetFullName() .. " is disabled")
	check(
		#scriptObject.Source >= minimumSourceLength,
		scriptObject:GetFullName() .. " has placeholder or incomplete source"
	)
	check(
		not string.find(scriptObject.Source, "Source is installed from", 1, true),
		scriptObject:GetFullName() .. " still has placeholder source"
	)
	return scriptObject
end

local function contains(source, token, label)
	check(
		string.find(source, token, 1, true) ~= nil,
		string.format("%s source is missing %q", label, token)
	)
end

local function containsAny(source, tokens, label)
	for _, token in ipairs(tokens) do
		if string.find(source, token, 1, true) then
			checks += 1
			return
		end
	end
	check(false, string.format(
		"%s source is missing every accepted safety token: %s",
		label,
		table.concat(tokens, ", ")
	))
end

local function forbids(source, token, label)
	check(
		string.find(source, token, 1, true) == nil,
		string.format("%s source still contains obsolete transport token %q", label, token)
	)
end

local function cframeClose(a, b, positionTolerance, angleToleranceDegrees)
	if typeof(a) ~= "CFrame" or typeof(b) ~= "CFrame" then
		return false
	end
	if (a.Position - b.Position).Magnitude > (positionTolerance or 0.05) then
		return false
	end
	local _, angle = a:ToObjectSpace(b):ToAxisAngle()
	return math.abs(angle) <= math.rad(angleToleranceDegrees or 1)
end

local function posesDistinct(a, b, minimumTranslation, minimumAngleDegrees)
	if typeof(a) ~= "CFrame" or typeof(b) ~= "CFrame" then
		return false
	end
	if (a.Position - b.Position).Magnitude >= (minimumTranslation or 0.25) then
		return true
	end
	local _, angle = a:ToObjectSpace(b):ToAxisAngle()
	return math.abs(angle) >= math.rad(minimumAngleDegrees or 10)
end

local function bounds(item)
	if item:IsA("Model") then
		return item:GetBoundingBox()
	end
	check(item:IsA("BasePart"), item:GetFullName() .. " has no physical bounds")
	return item.CFrame, item.Size
end

local function worldAABB(item)
	local cframe, size = bounds(item)
	local half = size * 0.5
	local right = cframe.RightVector
	local up = cframe.UpVector
	local look = cframe.LookVector
	local extent = Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	)
	return cframe.Position - extent, cframe.Position + extent
end

local function localAABB(referencePart, item)
	local cframe, size = bounds(item)
	local half = size * 0.5
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, xSign in ipairs({ -1, 1 }) do
		for _, ySign in ipairs({ -1, 1 }) do
			for _, zSign in ipairs({ -1, 1 }) do
				local worldCorner = cframe:PointToWorldSpace(Vector3.new(
					half.X * xSign,
					half.Y * ySign,
					half.Z * zSign
				))
				local point = referencePart.CFrame:PointToObjectSpace(worldCorner)
				minimum = Vector3.new(
					math.min(minimum.X, point.X),
					math.min(minimum.Y, point.Y),
					math.min(minimum.Z, point.Z)
				)
				maximum = Vector3.new(
					math.max(maximum.X, point.X),
					math.max(maximum.Y, point.Y),
					math.max(maximum.Z, point.Z)
				)
			end
		end
	end
	return minimum, maximum
end

local function footprintsSeparated(a, b, clearance)
	local aMin, aMax = worldAABB(a)
	local bMin, bMax = worldAABB(b)
	clearance = clearance or 0
	return aMax.X + clearance <= bMin.X
		or bMax.X + clearance <= aMin.X
		or aMax.Z + clearance <= bMin.Z
		or bMax.Z + clearance <= aMin.Z
end

local function volumesSeparated(a, b, tolerance)
	local aMin, aMax = worldAABB(a)
	local bMin, bMax = worldAABB(b)
	tolerance = tolerance or 0.01
	return aMax.X <= bMin.X + tolerance
		or bMax.X <= aMin.X + tolerance
		or aMax.Y <= bMin.Y + tolerance
		or bMax.Y <= aMin.Y + tolerance
		or aMax.Z <= bMin.Z + tolerance
		or bMax.Z <= aMin.Z + tolerance
end

local function ringOpening(west, east, front, rear, label)
	local function innerGap(first, second, axis)
		local firstMin, firstMax = worldAABB(first)
		local secondMin, secondMax = worldAABB(second)
		local function component(vector)
			return axis == "X" and vector.X or vector.Z
		end
		if component(first.Position) <= component(second.Position) then
			return component(firstMax), component(secondMin)
		end
		return component(secondMax), component(firstMin)
	end

	-- The complete house is rotated in the current place. West/east therefore
	-- separate on world Z and front/rear on world X. Select axes from the actual
	-- panel-center separation so this verifier remains valid before or after a
	-- whole-environment rotation without weakening the physical opening check.
	local westEastUsesX = math.abs(west.Position.X - east.Position.X)
		>= math.abs(west.Position.Z - east.Position.Z)
	local minimumX, maximumX
	local minimumZ, maximumZ
	if westEastUsesX then
		minimumX, maximumX = innerGap(west, east, "X")
		minimumZ, maximumZ = innerGap(front, rear, "Z")
	else
		minimumZ, maximumZ = innerGap(west, east, "Z")
		minimumX, maximumX = innerGap(front, rear, "X")
	end
	local minimum = Vector3.new(minimumX, 0, minimumZ)
	local maximum = Vector3.new(maximumX, 0, maximumZ)
	check(maximum.X > minimum.X, label .. " west/east pieces overlap or are reversed")
	check(maximum.Z > minimum.Z, label .. " front/rear pieces overlap or are reversed")
	return minimum, maximum
end

local function faceCanvasStuds(part, face)
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		return Vector2.new(part.Size.X, part.Size.Y)
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return Vector2.new(part.Size.Z, part.Size.Y)
	end
	return Vector2.new(part.Size.X, part.Size.Z)
end

local function assertReadableSurfaceGui(gui)
	check(gui:IsA("SurfaceGui"), gui:GetFullName() .. " must remain a SurfaceGui")
	local part = gui.Parent
	check(part and part:IsA("BasePart"), gui:GetFullName() .. " must be parented to its sign part")
	local label = gui:FindFirstChildWhichIsA("TextLabel")
	check(label ~= nil, gui:GetFullName() .. " has no TextLabel")
	check(not label.TextWrapped, label:GetFullName() .. " must not wrap words into vertical lettering")
	check(gui.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud, gui:GetFullName() .. " must use PixelsPerStud")
	check(gui.PixelsPerStud >= 30, gui:GetFullName() .. " has insufficient pixel density")

	local canvasStuds = faceCanvasStuds(part, gui.Face)
	local canvasPixels = canvasStuds * gui.PixelsPerStud
	local measurementSize = label.TextSize
	if label.TextScaled then
		local constraint = label:FindFirstChildWhichIsA("UITextSizeConstraint")
		check(constraint ~= nil, label:GetFullName() .. " scaled text needs a UITextSizeConstraint")
		check(constraint.MinTextSize >= 9, label:GetFullName() .. " may scale below readable size")
		check(constraint.MaxTextSize >= 12, label:GetFullName() .. " has an unusably small text ceiling")
		measurementSize = math.max(9, constraint.MinTextSize)
	else
		check(label.TextSize >= 12, label:GetFullName() .. " text is too small to read")
	end
	local lineCount = 0
	local longestWidth = 0
	local totalHeight = 0
	for line in string.gmatch(label.Text .. "\n", "(.-)\n") do
		lineCount += 1
		local bounds = TextService:GetTextSize(
			line == "" and " " or line,
			measurementSize,
			label.Font,
			Vector2.new(10000, 10000)
		)
		longestWidth = math.max(longestWidth, bounds.X)
		totalHeight += bounds.Y
	end
	check(lineCount >= 1, label:GetFullName() .. " has no renderable text line")
	check(
		longestWidth <= canvasPixels.X - 8,
		string.format(
			"%s canvas is too narrow (%.0f px for %.0f px text) and would stack or clip lettering",
			label:GetFullName(),
			canvasPixels.X,
			longestWidth
		)
	)
	check(
		totalHeight <= canvasPixels.Y - 4,
		string.format(
			"%s canvas is too short (%.0f px for %.0f px text)",
			label:GetFullName(),
			canvasPixels.Y,
			totalHeight
		)
	)
end

local function hasHumanoidAncestor(part)
	local current = part.Parent
	while current do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function insidePartXZ(container, item, margin)
	local itemCF, itemSize = bounds(item)
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

local function insideBoundsXZ(container, item)
	local containerMin, containerMax = worldAABB(container)
	local itemMin, itemMax = worldAABB(item)
	return itemMin.X >= containerMin.X
		and itemMax.X <= containerMax.X
		and itemMin.Z >= containerMin.Z
		and itemMax.Z <= containerMax.Z
end

local function assertAnchorSafety(anchor, label)
	check(anchor.Anchored, label .. " must be anchored")
	check(not anchor.CanCollide, label .. " must not collide with the player")
	check(not anchor.CanTouch, label .. " must not produce stray touch events")
	check(anchor.Transparency == 1, label .. " must remain invisible")
end

local function assertControlSafety(control, label, shouldBeVisible)
	check(control.Anchored, label .. " must be anchored")
	if shouldBeVisible == false then
		check(
			not control.CanCollide
				and control:GetAttribute("BunkerConstructionOriginalCanCollide") == true,
			label .. " must preserve its authored solid state while safely concealed"
		)
	else
		check(control.CanCollide, label .. " must remain a solid physical control")
	end
	check(not control.CanTouch, label .. " must not produce stray touch events")
	if shouldBeVisible == false then
		check(control.Transparency >= 0.95, label .. " must remain concealed before unlock")
	else
		check(control.Transparency < 1, label .. " must remain visible")
	end
end

local function assertPrompt(prompt, label, shouldBeEnabled)
	check(
		prompt.Enabled == shouldBeEnabled,
		string.format(
			"%s enabled state does not match the bunker unlock state (expected %s)",
			label,
			tostring(shouldBeEnabled)
		)
	)
	check(prompt.ActionText ~= "", label .. " has empty ActionText")
	check(prompt.ObjectText ~= "", label .. " has empty ObjectText")
	check(
		prompt.MaxActivationDistance >= 5 and prompt.MaxActivationDistance <= 16,
		label .. " has an unsafe activation distance"
	)
	check(
		prompt.HoldDuration >= 0 and prompt.HoldDuration <= 2,
		label .. " has an unreasonable hold duration"
	)
end

local function assertPlayerClearance(anchor, label)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { anchor }
	local blockers = {}
	for _, part in ipairs(Workspace:GetPartBoundsInBox(
		anchor.CFrame,
		Vector3.new(3.2, 4.5, 3.2),
		overlapParams
	)) do
		if part.CanCollide and not hasHumanoidAncestor(part) then
			table.insert(blockers, part:GetFullName())
		end
	end
	check(
		#blockers == 0,
		string.format("%s is obstructed by: %s", label, table.concat(blockers, ", "))
	)
end

local environment = need(Workspace, "CooperHouseEnvironment", "Model")
local house = need(environment, "CooperHouse", "Model")
local garage = need(environment, "DetachedGarage", "Model")
local site = need(environment, "SiteAndStreet", "Model")
local lot = need(site, "CooperLot", "BasePart")
local neighborhoodGround = need(site, "NeighborhoodGround", "BasePart")
check(
	lot:GetAttribute("BunkerShaftCutVersion") == EXPECTED_VERSION,
	"CooperLot is missing the v2 physical bunker shaft cut"
)
check(
	neighborhoodGround:GetAttribute("BunkerShaftCutVersion") == EXPECTED_VERSION,
	"NeighborhoodGround is missing the v2 physical bunker shaft cut"
)
for _, groundLocator in ipairs({ lot, neighborhoodGround }) do
	check(
		groundLocator:GetAttribute("BunkerShaftCutMode") == "FourPanelFrame",
		groundLocator:GetFullName() .. " does not use a real four-panel opening"
	)
	check(
		not groundLocator.CanCollide and not groundLocator.CanTouch and not groundLocator.CanQuery,
		groundLocator:GetFullName() .. " full-size locator still blocks the physical shaft"
	)
	check(groundLocator.Transparency == 1, groundLocator:GetFullName() .. " locator must remain invisible")
	local panels = need(
		groundLocator.Parent,
		groundLocator.Name .. "BunkerCutPanels",
		"Model"
	)
	check(
		panels:GetAttribute("BunkerShaftCutVersion") == EXPECTED_VERSION,
		panels:GetFullName() .. " is stale"
	)
	local west = need(panels, "West", "BasePart")
	local east = need(panels, "East", "BasePart")
	local front = need(panels, "Front", "BasePart")
	local rear = need(panels, "Rear", "BasePart")
	for _, panel in ipairs({ west, east, front, rear }) do
		check(panel.Anchored and panel.CanCollide, panel:GetFullName() .. " must be solid ground")
		check(panel:GetAttribute("TrikeGroundSurface") == true, panel:GetFullName() .. " breaks trike ground")
	end
	local groundHoleMin, groundHoleMax = ringOpening(
		west,
		east,
		front,
		rear,
		groundLocator.Name .. "BunkerCutPanels"
	)
	local groundHoleCenter = Vector2.new(
		(groundHoleMin.X + groundHoleMax.X) * 0.5,
		(groundHoleMin.Z + groundHoleMax.Z) * 0.5
	)
	local expectedCenter = groundLocator:GetAttribute("BunkerShaftCenter")
	check(typeof(expectedCenter) == "CFrame", groundLocator:GetFullName() .. " lacks BunkerShaftCenter")
	check(
		(groundHoleCenter - Vector2.new(expectedCenter.Position.X, expectedCenter.Position.Z)).Magnitude <= 0.15,
		groundLocator:GetFullName() .. " panels are not centered on its shaft metadata"
	)
end

local baseplateLocator = Workspace:FindFirstChild("Baseplate")
if baseplateLocator and baseplateLocator:IsA("BasePart") then
	local candidateBunker = environment:FindFirstChild("BackyardBunker")
	local undergroundOrigin = candidateBunker and candidateBunker:GetAttribute("UndergroundOrigin")
	local roomSize = candidateBunker and candidateBunker:GetAttribute("RoomSize")
	local shaftFloorTop = typeof(undergroundOrigin) == "CFrame"
		and typeof(roomSize) == "Vector3"
		and undergroundOrigin.Position.Y - roomSize.Y * 0.5 + 0.5
		or -math.huge
	local shaftSurfaceTop = lot.Position.Y + lot.Size.Y * 0.5
	local baseplateBottom = baseplateLocator.Position.Y - baseplateLocator.Size.Y * 0.5
	local baseplateTop = baseplateLocator.Position.Y + baseplateLocator.Size.Y * 0.5
	local crossesShaftVertically = baseplateTop > shaftFloorTop
		and baseplateBottom < shaftSurfaceTop
	if crossesShaftVertically then
		check(
			baseplateLocator:GetAttribute("BunkerShaftCutVersion") == EXPECTED_VERSION,
			"Baseplate crosses the shaft but is missing the v2 physical cut"
		)
		check(
			not baseplateLocator.CanCollide and not baseplateLocator.CanTouch and not baseplateLocator.CanQuery,
			"Full-size Baseplate locator still blocks the physical shaft"
		)
		local baseplatePanels = need(Workspace, "BaseplateBunkerCutPanels", "Model")
		local baseWest = need(baseplatePanels, "West", "BasePart")
		local baseEast = need(baseplatePanels, "East", "BasePart")
		local baseFront = need(baseplatePanels, "Front", "BasePart")
		local baseRear = need(baseplatePanels, "Rear", "BasePart")
		for _, panel in ipairs({ baseWest, baseEast, baseFront, baseRear }) do
			check(panel.Anchored and panel.CanCollide, panel:GetFullName() .. " must retain surrounding ground")
			check(panel:GetAttribute("TrikeGroundSurface") == true, panel:GetFullName() .. " breaks trike ground")
		end
		local baseHoleMin, baseHoleMax = ringOpening(
			baseWest,
			baseEast,
			baseFront,
			baseRear,
			"BaseplateBunkerCutPanels"
		)
		local baseHoleCenter = Vector2.new(
			(baseHoleMin.X + baseHoleMax.X) * 0.5,
			(baseHoleMin.Z + baseHoleMax.Z) * 0.5
		)
		local baseShaftCenter = baseplateLocator:GetAttribute("BunkerShaftCenter")
		check(typeof(baseShaftCenter) == "CFrame", "Baseplate lacks BunkerShaftCenter")
		check(
			(baseHoleCenter - Vector2.new(
				baseShaftCenter.Position.X,
				baseShaftCenter.Position.Z
			)).Magnitude <= 0.15,
			"Baseplate panels are not centered on the shaft"
		)
	end
end

local bunker = need(environment, "BackyardBunker", "Model")
check(
	bunker:GetAttribute("InstallVersion") == EXPECTED_VERSION,
	"BackyardBunker InstallVersion must be " .. EXPECTED_VERSION
)
check(
	bunker.ModelStreamingMode == Enum.ModelStreamingMode.Persistent,
	"BackyardBunker must stream persistently throughout the continuous physical descent"
)

local hatchOpen = bunker:GetAttribute("HatchOpen")
local blastDoorOpen = bunker:GetAttribute("BlastDoorOpen")
local mainLightsOn = bunker:GetAttribute("MainLightsOn")
local unlockState = tostring(bunker:GetAttribute("UnlockState") or "Locked")
check(type(hatchOpen) == "boolean", "BackyardBunker.HatchOpen must be a boolean")
check(type(blastDoorOpen) == "boolean", "BackyardBunker.BlastDoorOpen must be a boolean")
check(type(mainLightsOn) == "boolean", "BackyardBunker.MainLightsOn must be a boolean")
check(
	unlockState == "Locked" or unlockState == "Constructing" or unlockState == "Unlocked",
	"BackyardBunker.UnlockState is invalid"
)
check(bunker:GetAttribute("PhysicalAccess") == true, "BackyardBunker must declare physical access")
check(bunker:GetAttribute("UsesTeleport") == false, "BackyardBunker must explicitly reject normal teleports")
check(typeof(bunker:GetAttribute("ShaftCenter")) == "CFrame", "BackyardBunker.ShaftCenter is missing")

-- Surface entrance: grounded, compact, and placed in the clear rear-right yard.
local surfaceEntrance = need(bunker, "SurfaceEntrance", "Model")
local foundationSlab = need(surfaceEntrance, "FoundationSlab", "Model")
local foundationWest = need(foundationSlab, "FoundationWest", "BasePart")
local foundationEast = need(foundationSlab, "FoundationEast", "BasePart")
local foundationFront = need(foundationSlab, "FoundationFront", "BasePart")
local foundationRear = need(foundationSlab, "FoundationRear", "BasePart")
for _, segment in ipairs({
	foundationWest,
	foundationEast,
	foundationFront,
	foundationRear,
}) do
	local authoredSolid = segment.CanCollide
		or segment:GetAttribute("BunkerConstructionOriginalCanCollide") == true
	check(segment.Anchored and authoredSolid, segment:GetFullName() .. " must be authored solid and anchored")
	if unlockState ~= "Unlocked" then
		check(not segment.CanCollide, segment:GetFullName() .. " should be replaced by the locked grass support")
	end
end
local foundationHoleMin, foundationHoleMax = ringOpening(
	foundationWest,
	foundationEast,
	foundationFront,
	foundationRear,
	"FoundationSlab"
)
local foundationHoleCenter = Vector3.new(
	(foundationHoleMin.X + foundationHoleMax.X) * 0.5,
	0,
	(foundationHoleMin.Z + foundationHoleMax.Z) * 0.5
)
local foundationHoleSize = Vector2.new(
	foundationHoleMax.X - foundationHoleMin.X,
	foundationHoleMax.Z - foundationHoleMin.Z
)
local authoredShaftCenter = bunker:GetAttribute("ShaftCenter")
check(
	(Vector2.new(
		foundationHoleCenter.X - authoredShaftCenter.Position.X,
		foundationHoleCenter.Z - authoredShaftCenter.Position.Z
	)).Magnitude <= 0.2,
	"Foundation opening is not centered on BackyardBunker.ShaftCenter"
)
check(
	foundationHoleSize.X >= 3.2 and foundationHoleSize.Y >= 3.2,
	"FoundationSlab opening is not large enough for a player-sized physical shaft"
)

local shaftOpening = need(surfaceEntrance, "ShaftOpening", "BasePart")
assertAnchorSafety(shaftOpening, "ShaftOpening")
check(not shaftOpening.CanQuery, "ShaftOpening marker must not intercept camera or interaction raycasts")
local expectedSurfaceOrigin = shaftOpening.CFrame * CFrame.new(0, -0.04, 0.15)
check(
	cframeClose(bunker:GetAttribute("SurfaceOrigin"), expectedSurfaceOrigin, 0.08, 1.5),
	"BackyardBunker.SurfaceOrigin does not track the physical ShaftOpening"
)
check(
	math.abs(shaftOpening.Position.X - foundationHoleCenter.X) <= 0.2
		and math.abs(shaftOpening.Position.Z - foundationHoleCenter.Z) <= 0.2,
	"ShaftOpening marker is not centered on the real foundation opening"
)
check(
	(select(2, worldAABB(shaftOpening)) - select(1, worldAABB(shaftOpening))).X <= foundationHoleSize.X + 0.15
		and (select(2, worldAABB(shaftOpening)) - select(1, worldAABB(shaftOpening))).Z <= foundationHoleSize.Y + 0.15,
	"ShaftOpening marker leaves the physical foundation opening"
)

local hatchDoor = need(surfaceEntrance, "HatchDoor", "Model")
local hingeRoot = need(hatchDoor, "HingeRoot", "BasePart")
local hatchPanel = need(hatchDoor, "Panel", "BasePart")
local closedPivot = hatchDoor:GetAttribute("ClosedPivot")
local openPivot = hatchDoor:GetAttribute("OpenPivot")
check(typeof(closedPivot) == "CFrame", "HatchDoor.ClosedPivot is missing")
check(typeof(openPivot) == "CFrame", "HatchDoor.OpenPivot is missing")
check(
	posesDistinct(closedPivot, openPivot, 0.2, 20),
	"HatchDoor open and closed pivots are not visibly distinct"
)
check(
	cframeClose(hatchDoor:GetPivot(), hatchOpen and openPivot or closedPivot, 0.08, 1.5),
	"HatchDoor physical pose does not match BackyardBunker.HatchOpen"
)
check(
	hatchDoor.PrimaryPart == hingeRoot,
	"HatchDoor.PrimaryPart must be HingeRoot for deterministic pivot animation"
)
check(hingeRoot.Anchored and hatchPanel.Anchored, "Hatch door parts must be anchored")
check(not hingeRoot.CanCollide, "Invisible hatch hinge must not block the player")
check(
	hatchPanel.CanCollide
		or hatchPanel:GetAttribute("BunkerConstructionOriginalCanCollide") == true,
	"Hatch panel must preserve its authored physical collision"
)
if unlockState ~= "Unlocked" then
	check(not hatchPanel.CanCollide, "Concealed hatch panel should not fight the locked grass support")
end

local hatchControl = need(surfaceEntrance, "HatchControl", "BasePart")
local hatchPrompt = need(hatchControl, "HatchPrompt", "ProximityPrompt")
assertControlSafety(hatchControl, "HatchControl", unlockState == "Unlocked")
assertPrompt(hatchPrompt, "HatchPrompt", unlockState == "Unlocked")
check(
	string.find(string.lower(hatchPrompt.ActionText), hatchOpen and "close" or "open", 1, true) ~= nil,
	"HatchPrompt.ActionText does not match the current hatch state"
)

check(
	surfaceEntrance:FindFirstChild("DescendAnchor") == nil,
	"SurfaceEntrance still contains the obsolete teleport DescendAnchor"
)
check(
	surfaceEntrance:FindFirstChild("SurfaceArrivalAnchor") == nil,
	"SurfaceEntrance still contains the obsolete teleport SurfaceArrivalAnchor"
)
check(
	surfaceEntrance:FindFirstChild("DescendPrompt", true) == nil,
	"SurfaceEntrance still contains the obsolete DescendPrompt"
)

local physicalAccess = need(surfaceEntrance, "PhysicalAccess", "Model")
local shaftLeftWall = need(physicalAccess, "ShaftLeftWall", "BasePart")
local shaftRightWall = need(physicalAccess, "ShaftRightWall", "BasePart")
local shaftFrontWall = need(physicalAccess, "ShaftFrontWall", "BasePart")
local shaftUpperRearWall = need(physicalAccess, "ShaftUpperRearWall", "BasePart")
local shaftLadder = need(physicalAccess, "ShaftLadder", "TrussPart")
local bottomLanding = need(physicalAccess, "BottomLanding", "BasePart")
local landingStripe = need(physicalAccess, "LandingStripe", "BasePart")
local ladderGuardLeft = need(physicalAccess, "LadderGuardLeft", "BasePart")
local ladderGuardRight = need(physicalAccess, "LadderGuardRight", "BasePart")
local shaftLightUpper = need(physicalAccess, "ShaftLightUpper", "BasePart")
local shaftLightLower = need(physicalAccess, "ShaftLightLower", "BasePart")
for _, wall in ipairs({
	shaftLeftWall,
	shaftRightWall,
	shaftFrontWall,
	shaftUpperRearWall,
}) do
	check(wall.Anchored and wall.CanCollide, wall:GetFullName() .. " must be a solid anchored shaft wall")
end
check(
	shaftLadder.Anchored and shaftLadder.CanCollide,
	"ShaftLadder must be an anchored, physically climbable TrussPart"
)
check(bottomLanding.Anchored and bottomLanding.CanCollide, "BottomLanding must be a solid anchored floor")
check(landingStripe.Anchored and not landingStripe.CanCollide, "LandingStripe must be anchored decoration")
for _, guard in ipairs({ ladderGuardLeft, ladderGuardRight }) do
	check(
		guard.Anchored and not guard.CanCollide and not guard.CanTouch,
		guard:GetFullName() .. " must remain a nonblocking decorative handhold"
	)
end
for _, fixture in ipairs({ shaftLightUpper, shaftLightLower }) do
	check(fixture.Anchored and not fixture.CanCollide, fixture:GetFullName() .. " must not obstruct the climb")
	local light = fixture:FindFirstChildWhichIsA("Light")
	check(light ~= nil and light.Enabled, fixture:GetFullName() .. " needs an enabled shaft light")
end

local foundationCF, foundationSize = foundationSlab:GetBoundingBox()
check(
	foundationSize.X >= 6.5 and foundationSize.X <= 12
		and foundationSize.Z >= 5.5 and foundationSize.Z <= 11,
	"Surface foundation footprint is not the planned compact bunker entrance"
)
local lotTop = lot.Position.Y + lot.Size.Y * 0.5
local foundationBottom = foundationCF.Position.Y - foundationSize.Y * 0.5
check(
	math.abs(foundationBottom - lotTop) <= 0.35,
	"FoundationSlab is floating above or buried below CooperLot"
)
check(insidePartXZ(lot, surfaceEntrance, 2), "SurfaceEntrance leaves the Cooper lot")

local foundationLocal = lot.CFrame:PointToObjectSpace(foundationCF.Position)
check(
	foundationLocal.X >= 18 and foundationLocal.X <= 24,
	"SurfaceEntrance is not in the planned rear-right-yard X corridor"
)
check(
	foundationLocal.Z >= 34 and foundationLocal.Z <= 42,
	"SurfaceEntrance is not in the planned rear-right-yard Z corridor"
)

local houseMin, houseMax = localAABB(lot, house)
local surfaceMin, surfaceMax = localAABB(lot, surfaceEntrance)
check(
	surfaceMin.Z >= houseMax.Z + 1.5,
	"SurfaceEntrance is too close to the back of the house"
)
check(
	footprintsSeparated(surfaceEntrance, garage, 1),
	"SurfaceEntrance footprint conflicts with the detached garage"
)

local landscaping = need(environment, "Landscaping", "Model")
local rearFence = need(landscaping, "RearPrivacyFence", "BasePart")
local rightFence = need(landscaping, "RightPicketFence", "Model")
local rearFenceMin = select(1, localAABB(lot, rearFence))
local rightFenceMin = select(1, localAABB(lot, rightFence))
check(surfaceMax.Z <= rearFenceMin.Z - 4, "SurfaceEntrance crowds the rear privacy fence")
check(surfaceMax.X <= rightFenceMin.X - 4, "SurfaceEntrance crowds the right picket fence")

local concreteCollar = need(surfaceEntrance, "ConcreteCollar", "Model")
for _, possibleConflict in ipairs({
	foundationWest,
	foundationEast,
	foundationFront,
	foundationRear,
}) do
	check(
		volumesSeparated(hatchControl, possibleConflict),
		"HatchControl is fused into " .. possibleConflict:GetFullName()
	)
end
for _, possibleConflict in ipairs(concreteCollar:GetDescendants()) do
	if possibleConflict:IsA("BasePart") then
		check(
			volumesSeparated(hatchControl, possibleConflict),
			"HatchControl is fused into " .. possibleConflict:GetFullName()
		)
	end
end

local plaque = need(surfaceEntrance, "CooperShelterPlaque", "BasePart")
local targetOverlap = OverlapParams.new()
targetOverlap.FilterType = Enum.RaycastFilterType.Include
targetOverlap.FilterDescendantsInstances = { hatchControl, plaque }
local currentHatchPivot = hatchDoor:GetPivot()
for _, movingPart in ipairs(hatchDoor:GetDescendants()) do
	if movingPart:IsA("BasePart") and movingPart ~= hingeRoot then
		local relative = currentHatchPivot:ToObjectSpace(movingPart.CFrame)
		for sample = 0, 10 do
			local sampledPivot = closedPivot:Lerp(openPivot, sample / 10)
			local hits = Workspace:GetPartBoundsInBox(
				sampledPivot * relative,
				Vector3.new(
					math.max(0.02, movingPart.Size.X - 0.06),
					math.max(0.02, movingPart.Size.Y - 0.06),
					math.max(0.02, movingPart.Size.Z - 0.06)
				),
				targetOverlap
			)
			check(
				#hits == 0,
				string.format(
					"Hatch sweep intersects control/plaque at sample %d through %s",
					sample,
					movingPart:GetFullName()
				)
			)
		end
	end
end

-- Underground structure stays below the yard while its ceiling and both
-- ground layers retain a real, aligned player opening.
local underground = need(bunker, "Underground", "Model")
local shell = need(underground, "Shell", "Model")
local entryAirlock = need(underground, "EntryAirlock", "Model")
local undergroundCF, undergroundSize = shell:GetBoundingBox()
local undergroundMin, undergroundMax = worldAABB(shell)
local neighborhoodBottom = neighborhoodGround.Position.Y - neighborhoodGround.Size.Y * 0.5
check(
	undergroundMax.Y <= neighborhoodBottom - 1,
	"Underground ceiling intersects or crowds the cut NeighborhoodGround"
)
check(
	undergroundSize.X >= 32 and undergroundSize.X <= 38
		and undergroundSize.Y >= 10 and undergroundSize.Y <= 14
		and undergroundSize.Z >= 26 and undergroundSize.Z <= 32,
	"Underground shell is outside the planned 34 x 12 x 28-stud scale"
)
check(insidePartXZ(lot, shell, 2), "Underground footprint leaves the Cooper lot")
check(
	foundationCF.Position.X >= undergroundMin.X
		and foundationCF.Position.X <= undergroundMax.X
		and foundationCF.Position.Z >= undergroundMin.Z
		and foundationCF.Position.Z <= undergroundMax.Z,
	"SurfaceEntrance is not horizontally connected to the underground footprint"
)

local undergroundLocal = lot.CFrame:PointToObjectSpace(undergroundCF.Position)
check(
	undergroundLocal.X >= 11 and undergroundLocal.X <= 17,
	"Underground chamber is outside the planned rear-right-yard X corridor"
)
check(
	undergroundLocal.Z >= 42 and undergroundLocal.Z <= 49,
	"Underground chamber is outside the planned rear-right-yard Z corridor"
)
check(
	lotTop - undergroundCF.Position.Y >= 22
		and lotTop - undergroundCF.Position.Y <= 27,
	"Underground chamber is at an unsafe lot-relative depth"
)

local shellPartCount = 0
local shellCollisionCount = 0
for _, item in ipairs(shell:GetDescendants()) do
	if item:IsA("BasePart") then
		shellPartCount += 1
		check(item.Anchored, item:GetFullName() .. " must be anchored")
		if item.CanCollide then
			shellCollisionCount += 1
		end
	end
end
check(shellPartCount >= 6, "Underground shell is missing floor, ceiling, or walls")
check(shellCollisionCount >= 6, "Underground shell does not provide complete collision")

local foundationFloor = need(shell, "FoundationFloor", "BasePart")
local floorTop = foundationFloor.Position.Y + foundationFloor.Size.Y * 0.5
local roomSize = bunker:GetAttribute("RoomSize")
check(typeof(roomSize) == "Vector3", "BackyardBunker.RoomSize is missing")
local expectedUndergroundOrigin = foundationFloor.CFrame * CFrame.new(0, roomSize.Y * 0.5, 0)
check(
	cframeClose(bunker:GetAttribute("UndergroundOrigin"), expectedUndergroundOrigin, 0.08, 1.5),
	"BackyardBunker.UndergroundOrigin does not track the physical FoundationFloor"
)
local ceilingSegments = need(shell, "CeilingSegments", "Model")
local ceilingWest = need(ceilingSegments, "CeilingWest", "BasePart")
local ceilingEast = need(ceilingSegments, "CeilingEast", "BasePart")
local ceilingFront = need(ceilingSegments, "CeilingFront", "BasePart")
local ceilingRear = need(ceilingSegments, "CeilingRear", "BasePart")
for _, segment in ipairs({
	ceilingWest,
	ceilingEast,
	ceilingFront,
	ceilingRear,
}) do
	check(segment.Anchored and segment.CanCollide, segment:GetFullName() .. " must be solid and anchored")
end
check(shell:FindFirstChild("Ceiling") == nil, "Shell still contains a solid legacy Ceiling across the shaft")
local ceilingHoleMin, ceilingHoleMax = ringOpening(
	ceilingWest,
	ceilingEast,
	ceilingFront,
	ceilingRear,
	"CeilingSegments"
)
local ceilingHoleCenter = Vector3.new(
	(ceilingHoleMin.X + ceilingHoleMax.X) * 0.5,
	0,
	(ceilingHoleMin.Z + ceilingHoleMax.Z) * 0.5
)
local ceilingHoleSize = Vector2.new(
	ceilingHoleMax.X - ceilingHoleMin.X,
	ceilingHoleMax.Z - ceilingHoleMin.Z
)
check(
	ceilingHoleSize.X >= 3.2 and ceilingHoleSize.Y >= 3.2,
	"CeilingSegments opening is not large enough for the physical shaft"
)
check(
	(Vector2.new(
		foundationHoleCenter.X - ceilingHoleCenter.X,
		foundationHoleCenter.Z - ceilingHoleCenter.Z
	)).Magnitude <= 0.25,
	"Surface and bunker ceiling openings are not vertically aligned"
)
check(
	math.abs(foundationHoleSize.X - ceilingHoleSize.X) <= 0.35
		and math.abs(foundationHoleSize.Y - ceilingHoleSize.Y) <= 0.35,
	"Surface and bunker ceiling openings have inconsistent clearance"
)

local _, foundationMax = worldAABB(foundationSlab)
local ceilingSegmentsMin = select(1, worldAABB(ceilingSegments))
local ladderMin, ladderMax = worldAABB(shaftLadder)
local leftWallMin, leftWallMax = worldAABB(shaftLeftWall)
local rightWallMin, rightWallMax = worldAABB(shaftRightWall)
local frontWallMin, frontWallMax = worldAABB(shaftFrontWall)
local upperRearMin, upperRearMax = worldAABB(shaftUpperRearWall)
for _, span in ipairs({
	{ name = "ShaftLeftWall", minimum = leftWallMin, maximum = leftWallMax },
	{ name = "ShaftRightWall", minimum = rightWallMin, maximum = rightWallMax },
	{ name = "ShaftFrontWall", minimum = frontWallMin, maximum = frontWallMax },
}) do
	check(
		span.minimum.Y <= ceilingSegmentsMin.Y + 0.35,
		span.name .. " does not reach the bunker ceiling"
	)
	check(
		span.minimum.Y >= ceilingSegmentsMin.Y - 0.75,
		span.name .. " incorrectly closes the open airlock below the bunker ceiling"
	)
	check(
		span.maximum.Y >= foundationMax.Y - 0.6,
		span.name .. " does not reach the surface entrance"
	)
end
check(ladderMin.Y <= floorTop + 1.0, "ShaftLadder stops too far above the bottom landing")
check(ladderMax.Y >= foundationMax.Y - 1.0, "ShaftLadder does not reach the surface opening")
check(
	ladderMax.Y - ladderMin.Y >= foundationMax.Y - floorTop - 1.8,
	"ShaftLadder leaves a vertical gap in the physical descent"
)
check(
	shaftLadder.CFrame.UpVector:Dot(Vector3.yAxis) >= 0.98,
	"ShaftLadder must remain vertical"
)
check(
	shaftLadder.Position.X >= foundationHoleMin.X - 0.4
		and shaftLadder.Position.X <= foundationHoleMax.X + 0.4
		and shaftLadder.Position.Z >= foundationHoleMin.Z - 0.4
		and shaftLadder.Position.Z <= foundationHoleMax.Z + 0.4,
	"ShaftLadder is not aligned with the surface opening"
)
check(
	upperRearMax.Y >= foundationMax.Y - 0.6,
	"ShaftUpperRearWall does not reach the surface"
)
check(
	upperRearMin.Y >= ceilingSegmentsMin.Y - 0.75,
	"ShaftUpperRearWall blocks the lower walk-out from the ladder"
)
local landingMin, landingMax = worldAABB(bottomLanding)
check(
	math.abs(landingMax.Y - floorTop) <= 0.45,
	"BottomLanding is floating above or buried below the bunker floor"
)
local landingShaftMin, landingShaftMax = localAABB(shaftOpening, bottomLanding)
check(
	landingShaftMin.X <= 0 and landingShaftMax.X >= 0,
	"BottomLanding does not meet the shaft centerline"
)

-- Sample the entire vertical player column. The closed hatch and climbable
-- truss are intentional; every other collidable hit is a disconnected-world
-- regression (uncut ground, solid ceiling, or intrusive shaft geometry).
local clearanceWidth = math.min(2.4, foundationHoleSize.X - 0.7, ceilingHoleSize.X - 0.7)
local clearanceDepth = math.min(2.4, foundationHoleSize.Y - 0.7, ceilingHoleSize.Y - 0.7)
check(
	clearanceWidth >= 2.0 and clearanceDepth >= 2.0,
	"Physical shaft does not retain a two-stud player clearance column"
)
local clearanceParams = OverlapParams.new()
clearanceParams.FilterType = Enum.RaycastFilterType.Exclude
clearanceParams.MaxParts = 100
local clearanceBottom = floorTop + 2.1
local clearanceTop = foundationMax.Y - 0.45
local clearanceStep = 0.6
local clearanceSamples = math.max(1, math.ceil((clearanceTop - clearanceBottom) / clearanceStep))
local clearanceProbe = Instance.new("Part")
clearanceProbe.Name = "BunkerAuditClearanceProbe"
clearanceProbe.Anchored = true
clearanceProbe.CanCollide = false
clearanceProbe.CanTouch = false
clearanceProbe.CanQuery = true
clearanceProbe.Transparency = 1
clearanceProbe.Size = Vector3.new(clearanceWidth, 0.55, clearanceDepth)
clearanceProbe.Parent = Workspace
local clearanceExclusions = { hatchDoor, clearanceProbe }
for _, intentionalGateName in ipairs({ "BunkerGrassCover", "BunkerAccessGate" }) do
	local intentionalGate = bunker:FindFirstChild(intentionalGateName, true)
	if intentionalGate then
		table.insert(clearanceExclusions, intentionalGate)
	end
end
clearanceParams.FilterDescendantsInstances = clearanceExclusions
local shaftBlockers = {}
for sample = 0, clearanceSamples do
	local alpha = sample / clearanceSamples
	local y = clearanceBottom + (clearanceTop - clearanceBottom) * alpha
	clearanceProbe.CFrame = CFrame.new(foundationHoleCenter.X, y, foundationHoleCenter.Z)
	for _, hit in ipairs(Workspace:GetPartsInPart(clearanceProbe, clearanceParams)) do
		if hit.CanCollide and hit ~= shaftLadder and not hasHumanoidAncestor(hit) then
			table.insert(shaftBlockers, string.format("y=%.2f: %s", y, hit:GetFullName()))
		end
	end
end
clearanceProbe:Destroy()
check(
	#shaftBlockers == 0,
	"Physical shaft clearance is blocked: " .. table.concat(shaftBlockers, "; ")
)

local airlockCollisionCount = 0
for _, item in ipairs(entryAirlock:GetDescendants()) do
	if item:IsA("BasePart") then
		check(item.Anchored, item:GetFullName() .. " must be anchored")
		if item.CanCollide then
			airlockCollisionCount += 1
		end
	end
end
check(airlockCollisionCount >= 3, "EntryAirlock lacks a physical floor/wall enclosure")

-- Blast door has deterministic paired closed/open poses and a usable control.
local blastDoor = need(underground, "BlastDoor", "Model")
local leftPanel = need(blastDoor, "LeftPanel", "BasePart")
local rightPanel = need(blastDoor, "RightPanel", "BasePart")
for _, panel in ipairs({ leftPanel, rightPanel }) do
	local panelClosed = panel:GetAttribute("ClosedCFrame")
	local panelOpen = panel:GetAttribute("OpenCFrame")
	check(typeof(panelClosed) == "CFrame", panel:GetFullName() .. ".ClosedCFrame is missing")
	check(typeof(panelOpen) == "CFrame", panel:GetFullName() .. ".OpenCFrame is missing")
	check(
		posesDistinct(panelClosed, panelOpen, 1, 1),
		panel:GetFullName() .. " does not slide far enough to clear the doorway"
	)
	check(
		cframeClose(panel.CFrame, blastDoorOpen and panelOpen or panelClosed, 0.08, 1),
		panel:GetFullName() .. " physical pose does not match BackyardBunker.BlastDoorOpen"
	)
	check(panel.Anchored, panel:GetFullName() .. " must remain anchored")
	check(
		panel.CanCollide == not blastDoorOpen,
		panel:GetFullName() .. " collision does not match the blast-door state"
	)
end

local blastDoorControl = need(underground, "BlastDoorControl", "BasePart")
local blastDoorPrompt = need(blastDoorControl, "BlastDoorPrompt", "ProximityPrompt")
assertControlSafety(blastDoorControl, "BlastDoorControl")
assertPrompt(blastDoorPrompt, "BlastDoorPrompt", unlockState == "Unlocked")
check(
	string.find(
		string.lower(blastDoorPrompt.ActionText),
		blastDoorOpen and "close" or "open",
		1,
		true
	) ~= nil,
	"BlastDoorPrompt.ActionText does not match the current blast-door state"
)

-- Lighting remains useful in either normal or emergency mode.
local lightControl = need(underground, "LightControl", "BasePart")
local lightPrompt = need(lightControl, "LightPrompt", "ProximityPrompt")
assertControlSafety(lightControl, "LightControl")
assertPrompt(lightPrompt, "LightPrompt", unlockState == "Unlocked")

local mainLights = need(underground, "MainLights")
local emergencyLights = need(underground, "EmergencyLights")
local mainLightCount = 0
local emergencyLightCount = 0
local enabledLightCount = 0
for _, item in ipairs(mainLights:GetDescendants()) do
	if item:IsA("Light") then
		mainLightCount += 1
		if item.Enabled then
			enabledLightCount += 1
		end
		check(
			item.Enabled == mainLightsOn,
			item:GetFullName() .. " does not match BackyardBunker.MainLightsOn"
		)
	end
end
for _, item in ipairs(emergencyLights:GetDescendants()) do
	if item:IsA("Light") then
		emergencyLightCount += 1
		if item.Enabled then
			enabledLightCount += 1
		end
	end
end
check(mainLightCount >= 4, "MainLights needs at least four fixtures")
check(emergencyLightCount >= 2, "EmergencyLights needs at least two fixtures")
check(enabledLightCount >= 2, "Bunker may never become completely dark")

-- Normal entry/egress is entirely physical. The only repositioning anchor is
-- an emergency recovery target below the bunker.
check(underground:FindFirstChild("ArrivalAnchor") == nil, "Underground still contains teleport ArrivalAnchor")
check(underground:FindFirstChild("ExitAnchor") == nil, "Underground still contains teleport ExitAnchor")
check(underground:FindFirstChild("ExitPrompt", true) == nil, "Underground still contains teleport ExitPrompt")
local recoveryZone = need(underground, "RecoveryZone", "BasePart")
local recoveryAnchor = need(underground, "RecoveryAnchor", "BasePart")
assertAnchorSafety(recoveryAnchor, "RecoveryAnchor")
check(not recoveryAnchor.CanQuery, "RecoveryAnchor must not intercept queries")
assertPlayerClearance(recoveryAnchor, "RecoveryAnchor")
check(recoveryZone.Anchored, "RecoveryZone must be anchored")
check(not recoveryZone.CanCollide, "RecoveryZone must not create an invisible floor")
check(recoveryZone.CanTouch, "RecoveryZone must detect falling players")
check(recoveryZone.Transparency == 1, "RecoveryZone must remain invisible")
check(
	recoveryZone.Position.Y < undergroundMin.Y,
	"RecoveryZone must sit below the bunker floor"
)
check(
	recoveryZone.Size.X >= undergroundSize.X * 0.7
		and recoveryZone.Size.Z >= undergroundSize.Z * 0.7,
	"RecoveryZone does not protect enough of the bunker footprint"
)
check(
	recoveryAnchor.Position.Y >= floorTop + 2.0,
	"RecoveryAnchor must return a fallen player safely above the bunker floor"
)
check(
	recoveryAnchor.Position.X >= undergroundMin.X and recoveryAnchor.Position.X <= undergroundMax.X
		and recoveryAnchor.Position.Z >= undergroundMin.Z and recoveryAnchor.Position.Z <= undergroundMax.Z,
	"RecoveryAnchor leaves the bunker shell"
)

-- Reserve a safe runtime installation bay for the bunker chemistry feature.
local chemistryBay = need(underground, "FutureChemistryBay", "Model")
local chemistryAnchor = need(chemistryBay, "ChemistrySetAnchor", "BasePart")
check(bunker:GetAttribute("ChemistryGameplayEnabled") == true, "Bunker chemistry gameplay must be enabled")
check(chemistryBay:GetAttribute("GameplayEnabled") == true, "FutureChemistryBay gameplay must be enabled")
check(chemistryAnchor:GetAttribute("GameplayEnabled") == true, "ChemistrySetAnchor gameplay must be enabled")
check(chemistryAnchor.Anchored, "ChemistrySetAnchor must be anchored")
check(not chemistryAnchor.CanCollide, "ChemistrySetAnchor must not collide")
check(not chemistryAnchor.CanTouch, "ChemistrySetAnchor must not fire touch events")
check(not chemistryAnchor.CanQuery, "ChemistrySetAnchor must not affect raycasts or overlap queries")
check(chemistryAnchor.Transparency == 1, "ChemistrySetAnchor must remain invisible")
check(
	not chemistryAnchor:FindFirstChildWhichIsA("ProximityPrompt", true),
	"The invisible install anchor itself must not expose a shared prompt"
)
check(
	not chemistryAnchor:FindFirstChildWhichIsA("ClickDetector", true),
	"ChemistrySetAnchor must not expose unfinished click gameplay"
)
check(insideBoundsXZ(chemistryBay, chemistryAnchor), "ChemistrySetAnchor leaves FutureChemistryBay")
check(
	chemistryAnchor.Position.X >= undergroundMin.X
		and chemistryAnchor.Position.X <= undergroundMax.X
		and chemistryAnchor.Position.Z >= undergroundMin.Z
		and chemistryAnchor.Position.Z <= undergroundMax.Z,
	"ChemistrySetAnchor leaves the underground footprint"
)

-- Every authored sign must fit complete horizontal words on its selected face.
-- This catches a wide panel accidentally labeled on its 0.65-stud side.
local surfaceGuiCount = 0
for _, item in ipairs(bunker:GetDescendants()) do
	if item:IsA("SurfaceGui") and item.Name == "BunkerSignGui" then
		surfaceGuiCount += 1
		assertReadableSurfaceGui(item)
	end
end
check(surfaceGuiCount >= 8, "BackyardBunker is missing its authored signs and control labels")

local utilityRoom = need(underground, "UtilityRoom", "Model")
need(utilityRoom, "BreakerPanel", "BasePart")
local breakerHeader = need(utilityRoom, "BreakerHeader", "BasePart")
local statusConsole = need(underground, "StatusConsole", "BasePart")
for _, wallPanel in ipairs({ lightControl, breakerHeader, statusConsole }) do
	local gui = need(wallPanel, "BunkerSignGui", "SurfaceGui")
	local canvasStuds = faceCanvasStuds(wallPanel, gui.Face)
	local normalDepth
	if gui.Face == Enum.NormalId.Left or gui.Face == Enum.NormalId.Right then
		normalDepth = wallPanel.Size.X
	elseif gui.Face == Enum.NormalId.Front or gui.Face == Enum.NormalId.Back then
		normalDepth = wallPanel.Size.Z
	else
		normalDepth = wallPanel.Size.Y
	end
	check(normalDepth <= 1.0, wallPanel:GetFullName() .. " protrudes too far from its wall")
	check(canvasStuds.X >= 1.7, wallPanel:GetFullName() .. " sign face is vertically pinched")
end

-- Fan geometry must rotate around a neutral, invisible pivot and remain a
-- shallow wall fixture. Solid translucent cylinders were the source of the
-- giant spinning disks that crossed the room in v1.
local ventilation = need(underground, "Ventilation", "Model")
local fanHousing = need(ventilation, "FanHousing", "BasePart")
local fanBlades = need(ventilation, "FanBlades", "Model")
local fanPivotRoot = need(fanBlades, "FanPivotRoot", "BasePart")
check(fanBlades.PrimaryPart == fanPivotRoot, "FanBlades.PrimaryPart must be FanPivotRoot")
check(fanPivotRoot.Transparency == 1, "FanPivotRoot must remain invisible")
check(
	not fanPivotRoot.CanCollide and not fanPivotRoot.CanTouch and not fanPivotRoot.CanQuery,
	"FanPivotRoot must be physically and query neutral"
)
check(
	fanPivotRoot.Size.X <= 0.4 and fanPivotRoot.Size.Y <= 0.4 and fanPivotRoot.Size.Z <= 0.4,
	"FanPivotRoot is too large to be a neutral animation pivot"
)
local fanBasePivot = fanBlades:GetAttribute("BasePivot")
check(typeof(fanBasePivot) == "CFrame", "FanBlades.BasePivot is missing")
check(
	cframeClose(fanBlades:GetPivot(), fanBasePivot, 0.05, 1),
	"FanBlades.BasePivot must match its authored idle pose"
)
local fanBoundsCF, fanBoundsSize = fanBlades:GetBoundingBox()
check(
	fanBoundsSize.X <= fanHousing.Size.X + 0.8
		and fanBoundsSize.Y <= fanHousing.Size.Y + 0.8
		and fanBoundsSize.Z <= 1.5,
	"Fan blades leave the fan housing or project into the room"
)
for _, item in ipairs(fanBlades:GetDescendants()) do
	if item:IsA("BasePart") then
		check(item.Anchored, item:GetFullName() .. " must remain anchored for deterministic fan motion")
		check(
			not item.CanCollide and not item.CanTouch and not item.CanQuery,
			item:GetFullName() .. " must not obstruct players, cameras, or raycasts"
		)
	end
end

local guardPartCount = 0
local housingLocalHalf = fanHousing.Size * 0.5
for _, item in ipairs(ventilation:GetDescendants()) do
	if item:IsA("BasePart") and string.find(string.lower(item.Name), "guard", 1, true) then
		guardPartCount += 1
		check(
			not item.CanCollide and not item.CanTouch and not item.CanQuery,
			item:GetFullName() .. " must not obstruct players, cameras, or raycasts"
		)
		check(
			not (
				item:IsA("Part")
				and item.Shape == Enum.PartType.Cylinder
				and item.Transparency > 0.05
			),
			item:GetFullName() .. " recreates the solid translucent cylinder fan bug"
		)
		local itemCF, itemSize = bounds(item)
		for xSign = -1, 1, 2 do
			for ySign = -1, 1, 2 do
				for zSign = -1, 1, 2 do
					local corner = itemCF:PointToWorldSpace(Vector3.new(
						xSign * itemSize.X * 0.5,
						ySign * itemSize.Y * 0.5,
						zSign * itemSize.Z * 0.5
					))
					local localCorner = fanHousing.CFrame:PointToObjectSpace(corner)
					check(
						math.abs(localCorner.X) <= housingLocalHalf.X + 0.75
							and math.abs(localCorner.Y) <= housingLocalHalf.Y + 0.75
							and math.abs(localCorner.Z) <= 1.2,
						item:GetFullName() .. " leaves the shallow fan housing envelope"
					)
				end
			end
		end
	end
end
check(guardPartCount >= 4, "Ventilation fan needs a real multi-piece safety guard")
local fanCenterLocal = fanHousing.CFrame:PointToObjectSpace(fanBoundsCF.Position)
check(math.abs(fanCenterLocal.Z) <= 1.2, "Fan blades project too far in front of or behind the housing")

-- Every bunker part is static; only deterministic CFrame tweens move doors.
local bunkerPartCount = 0
for _, item in ipairs(bunker:GetDescendants()) do
	if item:IsA("BasePart") then
		bunkerPartCount += 1
		check(item.Anchored, item:GetFullName() .. " is an unanchored bunker part")
	end
end
check(bunkerPartCount >= 45, "BackyardBunker visual assembly is unexpectedly sparse")

-- The surface footprint must not consume garage, trash, or task interaction space.
local taskWorld = need(environment, "CooperFamilyTaskWorld", "Model")
local stations = need(taskWorld, "Stations", "Folder")
local outdoorTrash = needDescendant(taskWorld, "OutdoorGarbageCan", "Model")
check(
	footprintsSeparated(surfaceEntrance, outdoorTrash, 2),
	"SurfaceEntrance conflicts with the outdoor garbage can"
)
for _, station in ipairs(stations:GetChildren()) do
	if station:IsA("BasePart") or station:IsA("Model") then
		check(
			footprintsSeparated(surfaceEntrance, station, 1),
			"SurfaceEntrance conflicts with task station " .. station:GetFullName()
		)
	end
end

-- Remote and controllers: all world mutation stays server-authoritative.
local remotes = need(ReplicatedStorage, "CooperBunkerRemotes", "Folder")
need(remotes, "BunkerEvent", "RemoteEvent")
local serverController = liveScript(
	ServerScriptService,
	"CooperBunker",
	"Script",
	1200
)
local starterPlayerScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
check(
	StarterPlayer.DevCameraOcclusionMode == Enum.DevCameraOcclusionMode.Zoom,
	"Default camera must zoom around the physical shaft instead of clipping through its walls"
)
check(
	StarterPlayer.CameraMinZoomDistance <= 1
		and StarterPlayer.CameraMaxZoomDistance >= 6
		and StarterPlayer.CameraMaxZoomDistance <= 16,
	"StarterPlayer camera zoom limits are unsuitable for the shaft and bunker"
)
local clientController = liveScript(
	starterPlayerScripts,
	"CooperBunkerClient",
	"LocalScript",
	500
)

local serverSource = serverController.Source
contains(serverSource, "HatchOpen", "CooperBunker")
contains(serverSource, "BlastDoorOpen", "CooperBunker")
contains(serverSource, "MainLightsOn", "CooperBunker")
contains(serverSource, "HatchPrompt", "CooperBunker")
contains(serverSource, "candyPresentation.sweepVolumeOccupied", "CooperBunker complete-character door safety")
contains(serverSource, "workspace:GetPartBoundsInBox", "CooperBunker complete-character door safety")
contains(serverSource, "Enum.RaycastFilterType.Include", "CooperBunker complete-character door safety")
contains(serverSource, "Enum.RaycastFilterType.Exclude", "CooperBunker loose-object door safety")
contains(serverSource, "part:FindFirstAncestorWhichIsA(\"Tool\")", "CooperBunker held/dropped Tool door safety")
contains(serverSource, "PivotTo", "CooperBunker")
contains(serverSource, "AssemblyLinearVelocity", "CooperBunker")
contains(serverSource, "AssemblyAngularVelocity", "CooperBunker")
contains(serverSource, "SeatPart", "CooperBunker")
contains(serverSource, "BunkerEvent", "CooperBunker")
contains(serverSource, "RecoveryZone", "CooperBunker")
contains(serverSource, "RecoveryAnchor", "CooperBunker")
contains(serverSource, "hatchDoor:GetPivot() * reference:Inverse()", "CooperBunker relocation repair")
contains(serverSource, "panel.CFrame * reference:Inverse()", "CooperBunker relocation repair")
contains(serverSource, "fanBlades:SetAttribute(\"BasePivot\", fanBlades:GetPivot())", "CooperBunker relocation repair")
for _, obsoleteToken in ipairs({
	"safeTeleport",
	"TransitionOut",
	"TransitionIn",
	"DescendPrompt",
	"ExitPrompt",
	"SurfaceArrivalAnchor",
	"ArrivalAnchor",
	"ExitAnchor",
	"RequestStreamAroundAsync",
}) do
	forbids(serverSource, obsoleteToken, "CooperBunker")
end
check(
	not string.find(serverSource, "OnServerEvent", 1, true),
	"CooperBunker must not accept client-authored world state through BunkerEvent"
)

local clientSource = clientController.Source
contains(clientSource, "BunkerEvent", "CooperBunkerClient")
contains(clientSource, "OnClientEvent", "CooperBunkerClient")
contains(clientSource, "TweenService", "CooperBunkerClient")
containsAny(clientSource, { "ScreenGui", "Notice" }, "CooperBunkerClient")
for _, obsoleteToken in ipairs({
	"safeTeleport",
	"TransitionOut",
	"TransitionIn",
	"DescendPrompt",
	"ExitPrompt",
	"SurfaceArrivalAnchor",
	"ArrivalAnchor",
	"ExitAnchor",
	"RequestStreamAroundAsync",
}) do
	forbids(clientSource, obsoleteToken, "CooperBunkerClient")
end
contains(clientSource, "requestEvent:FireServer(\"RequestSnapshot\")", "CooperBunkerClient snapshot refresh")
contains(clientSource, "requestEvent:FireServer(\"OrderChemistrySetup\")", "CooperBunkerClient chemistry purchase request")
contains(clientSource, "requestEvent:FireServer(\"CloseBunkerComputer\")", "CooperBunkerClient terminal close request")
for _, forbiddenRequest in ipairs({
	"AdjustCurrency",
	"ChemistrySetupPlaced",
	"ChemistryDeliverySpawned",
	"ChemistryCratePicked",
}) do
	forbids(clientSource, "FireServer(\"" .. forbiddenRequest, "CooperBunkerClient authority boundary")
end
check(
	not string.find(clientSource, "CameraType = Enum.CameraType.Scriptable", 1, true),
	"CooperBunkerClient must not replace the normal playable camera"
)
check(
	not string.find(clientSource, "CurrentCamera.CFrame =", 1, true),
	"CooperBunkerClient must not teleport the camera into a disconnected view"
)

local function auditCharacterRepositions(source, label)
	for line in string.gmatch(source, "[^\r\n]+") do
		local lower = string.lower(line)
		local rootAssignment = string.match(lower, "[%w_]+root[%w_]*%.cframe%s*=") ~= nil
			or (
				string.find(lower, "humanoidrootpart", 1, true) ~= nil
				and string.match(lower, "%.cframe%s*=") ~= nil
			)
		local characterPivot = string.find(lower, ":pivotto(", 1, true) ~= nil
			and string.find(lower, "character", 1, true) ~= nil
		if rootAssignment or characterPivot then
			local authorizedRecovery = string.find(lower, "recoveryanchor", 1, true) ~= nil
			local accessDeniedRecovery = string.find(
				lower,
				"currentcharacter:pivotto(destination)",
				1,
				true
			) ~= nil
				and string.find(string.lower(source), "bunkeraccessgate", 1, true) ~= nil
				and string.find(
					string.lower(source),
					"if not playerhasbunkeraccess(player) then",
					1,
					true
				) ~= nil
			check(
				authorizedRecovery or accessDeniedRecovery,
				label .. " contains a non-recovery character CFrame transport: " .. line
			)
		end
	end
end
auditCharacterRepositions(serverSource, "CooperBunker")
auditCharacterRepositions(clientSource, "CooperBunkerClient")

print(string.format(
	"[CooperBunkerAudit] PASS: %d checks, %d anchored bunker parts, %d shell parts, %d lights",
	checks,
	bunkerPartCount,
	shellPartCount,
	mainLightCount + emergencyLightCount
))
