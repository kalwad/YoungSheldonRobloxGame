-- Server-authoritative controller for the sectional door created by
-- roof_garage_build.luau. The installer copies this source into the live place.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local doorModel = script.Parent
local panelsFolder = doorModel:WaitForChild("Panels")
local collisionBlocker = doorModel:WaitForChild("CollisionBlocker")
local promptMount = doorModel:WaitForChild("PromptMount")
local prompt = promptMount:WaitForChild("ProximityPrompt")

local MOVE_TIME = 1.55

local function requireNumberAttribute(name)
	local value = doorModel:GetAttribute(name)
	assert(type(value) == "number", doorModel:GetFullName() .. " is missing numeric attribute " .. name)
	return value
end

local doorCenterX = requireNumberAttribute("DoorCenterX")
local doorPlaneZ = requireNumberAttribute("DoorPlaneZ")
local doorTravelZSign = requireNumberAttribute("DoorTravelZSign")
local openingBottomY = requireNumberAttribute("OpeningBottomY")
local overheadY = requireNumberAttribute("OverheadY")
local panelHeight = requireNumberAttribute("PanelHeight")
local trackRadius = requireNumberAttribute("TrackRadius")
local frontRun = requireNumberAttribute("FrontRun")
local travelDistance = requireNumberAttribute("TravelDistance")

-- CFrameValue poses and numeric coordinates do not follow when an ancestor
-- garage Model is translated in Studio. The physical blocker does, so it is a
-- reliable reference for repairing every stored track coordinate before the
-- first panel pose is applied.
local expectedBlockerPosition = Vector3.new(
	doorCenterX,
	openingBottomY + collisionBlocker.Size.Y * 0.5,
	doorPlaneZ + doorTravelZSign * 0.08
)
local relocationOffset = collisionBlocker.Position - expectedBlockerPosition
if relocationOffset.Magnitude > 0.01 then
	doorCenterX += relocationOffset.X
	doorPlaneZ += relocationOffset.Z
	openingBottomY += relocationOffset.Y
	overheadY += relocationOffset.Y
	doorModel:SetAttribute("DoorCenterX", doorCenterX)
	doorModel:SetAttribute("DoorPlaneZ", doorPlaneZ)
	doorModel:SetAttribute("OpeningBottomY", openingBottomY)
	doorModel:SetAttribute("OpeningTopY", requireNumberAttribute("OpeningTopY") + relocationOffset.Y)
	doorModel:SetAttribute("OverheadY", overheadY)
end

assert(
	panelHeight > 0
		and trackRadius > 0
		and frontRun >= 0
		and travelDistance > 0
		and math.abs(math.abs(doorTravelZSign) - 1) < 0.001,
	"Garage-door track geometry is invalid"
)

local panels = {}
for _, child in ipairs(panelsFolder:GetChildren()) do
	if child:IsA("BasePart") then
		local index = child:GetAttribute("PanelIndex")
		local closedPose = child:FindFirstChild("ClosedPose")
		local openPose = child:FindFirstChild("OpenPose")
		assert(type(index) == "number", child:GetFullName() .. " is missing PanelIndex")
		assert(closedPose and closedPose:IsA("CFrameValue"), child:GetFullName() .. " is missing ClosedPose")
		assert(openPose and openPose:IsA("CFrameValue"), child:GetFullName() .. " is missing OpenPose")
		local repairedClosedPose = closedPose.Value + relocationOffset
		local repairedOpenPose = openPose.Value + relocationOffset
		closedPose.Value = repairedClosedPose
		openPose.Value = repairedOpenPose
		table.insert(panels, {
			part = child,
			index = index,
			closedPose = repairedClosedPose,
			openPose = repairedOpenPose,
		})
	end
end

table.sort(panels, function(a, b)
	return a.index < b.index
end)
assert(#panels > 0, "InteractiveSectionalGarageDoor has no door panels")
for expectedIndex, panelData in ipairs(panels) do
	assert(panelData.index == expectedIndex, "Garage-door PanelIndex values must be consecutive starting at 1")
end

local verticalDistance = overheadY - trackRadius - openingBottomY
local curveDistance = trackRadius * math.pi * 0.5
assert(verticalDistance >= (panelHeight * (#panels - 0.5)) - 0.02, "Garage-door curve begins below a closed panel")

local busy = false
local isOpen = doorModel:GetAttribute("IsOpen") == true
local currentAlpha = isOpen and 1 or 0

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.FilterDescendantsInstances = { doorModel }

local ignoredDoorwayStructure = {}
for _, name in ipairs({
	"GarageFoundation",
	"GarageDoorHeader",
	"GarageFrontLeft",
	"GarageFrontRight",
	"FrontLeftInteriorReturn",
	"FrontRightInteriorReturn",
}) do
	local part = doorModel.Parent:FindFirstChild(name, true)
	if part and part:IsA("BasePart") then
		ignoredDoorwayStructure[part] = true
	end
end
local living = doorModel.Parent:FindFirstChild("GeorgieMandyLivingUpgrade_V1")
local sealedFloor = living and living:FindFirstChild("SealedConcreteFloor")
if sealedFloor and sealedFloor:IsA("BasePart") then
	ignoredDoorwayStructure[sealedFloor] = true
end

local function isMovableDoorwayObstruction(part)
	local ancestor = part
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Tool")
			or ancestor.Name == "CooperRedYellowTrike"
			or ancestor:GetAttribute("CooperPickable") == true
		then
			return true
		end
		if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
			return true
		end
		ancestor = ancestor.Parent
	end
	return part.CanCollide and not ignoredDoorwayStructure[part]
end

local function isDoorwayObstructed()
	local querySize = collisionBlocker.Size + Vector3.new(0.60, 0.30, 1.50)
	for _, part in ipairs(Workspace:GetPartBoundsInBox(collisionBlocker.CFrame, querySize, overlapParams)) do
		if isMovableDoorwayObstruction(part) then
			return true
		end
	end
	return false
end

local function trackPose(panelData, alpha)
	if alpha <= 0 then
		return panelData.closedPose
	elseif alpha >= 1 then
		return panelData.openPose
	end

	local distanceAlongTrack = ((panelData.index - 0.5) * panelHeight) + (travelDistance * alpha)
	if distanceAlongTrack <= verticalDistance then
		return CFrame.new(
			doorCenterX,
			openingBottomY + distanceAlongTrack,
			doorPlaneZ
		)
	elseif distanceAlongTrack < verticalDistance + curveDistance then
		local angle = (distanceAlongTrack - verticalDistance) / trackRadius
		local y = overheadY - trackRadius + (trackRadius * math.sin(angle))
		local z = doorPlaneZ + (doorTravelZSign * (trackRadius - (trackRadius * math.cos(angle))))
		return CFrame.new(doorCenterX, y, z) * CFrame.Angles(doorTravelZSign * angle, 0, 0)
	else
		local horizontalDistance = distanceAlongTrack - verticalDistance - curveDistance
		return CFrame.new(
			doorCenterX,
			overheadY,
			doorPlaneZ + (doorTravelZSign * (trackRadius + horizontalDistance))
		) * CFrame.Angles(doorTravelZSign * math.rad(90), 0, 0)
	end
end

local function applyAlpha(alpha)
	currentAlpha = math.clamp(alpha, 0, 1)
	for _, panelData in ipairs(panels) do
		if panelData.part.Parent then
			panelData.part.CFrame = trackPose(panelData, currentAlpha)
			-- The single blocker owns collision. Moving sectional panels never trap or fling characters.
			panelData.part.CanCollide = false
		end
	end
end

local function refreshPrompt()
	prompt.ActionText = isOpen and "Close garage" or "Open garage"
	prompt.ObjectText = "Georgie & Mandy's garage"
	doorModel:SetAttribute("DoorState", isOpen and "Open" or "Closed")
	doorModel:SetAttribute("IsOpen", isOpen)
	doorModel:SetAttribute("TravelAlpha", isOpen and 1 or 0)
end

local function animateTo(targetAlpha, monitorObstructions)
	targetAlpha = math.clamp(targetAlpha, 0, 1)
	if math.abs(targetAlpha - currentAlpha) < 0.001 then
		applyAlpha(targetAlpha)
		return true, false
	end

	local driver = Instance.new("NumberValue")
	driver.Name = "GarageDoorTravelDriver"
	driver.Value = currentAlpha
	local connection
	local tween
	local obstructed = false
	local checkingObstruction = false

	local success, completedOrError = xpcall(function()
		local duration = math.max(0.18, MOVE_TIME * math.abs(targetAlpha - currentAlpha))
		tween = TweenService:Create(
			driver,
			TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
			{ Value = targetAlpha }
		)
		connection = driver.Changed:Connect(function(value)
			applyAlpha(value)
			if monitorObstructions and not obstructed and not checkingObstruction then
				checkingObstruction = true
				local querySucceeded, blocked = pcall(isDoorwayObstructed)
				checkingObstruction = false
				if querySucceeded and blocked then
					obstructed = true
					tween:Cancel()
				end
			end
		end)
		tween:Play()
		local playbackState = tween.Completed:Wait()
		return playbackState == Enum.PlaybackState.Completed
	end, function(message)
		return debug.traceback(tostring(message), 2)
	end)

	if connection then
		connection:Disconnect()
	end
	if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
		tween:Cancel()
	end
	driver:Destroy()

	if not success then
		error(completedOrError, 0)
	end
	return completedOrError, obstructed
end

local function moveDoor(open)
	if busy or open == isOpen then
		return
	end

	if not open and isDoorwayObstructed() then
		doorModel:SetAttribute("DoorState", "Blocked")
		prompt.ActionText = "Doorway blocked"
		task.delay(0.9, function()
			if doorModel.Parent and not busy then
				refreshPrompt()
			end
		end)
		return
	end

	busy = true
	prompt.Enabled = false
	collisionBlocker.CanCollide = false
	doorModel:SetAttribute("DoorState", open and "Opening" or "Closing")

	local finalOpen = isOpen
	local success, transitionError = xpcall(function()
		local completed, obstructed = animateTo(open and 1 or 0, not open)
		if not open and (obstructed or isDoorwayObstructed()) then
			doorModel:SetAttribute("DoorState", "Blocked")
			doorModel:SetAttribute("LastDoorIssue", "Obstruction detected; reopened safely")
			local recovered = animateTo(1, false)
			assert(recovered, "Garage door could not finish its safety reopen")
			finalOpen = true
			return
		end
		assert(completed, "Garage-door tween was cancelled before completion")
		applyAlpha(open and 1 or 0)
		finalOpen = open
	end, function(message)
		return debug.traceback(tostring(message), 2)
	end)

	if not success then
		warn("Georgie garage door recovered from a transition error: " .. transitionError)
		doorModel:SetAttribute("LastDoorIssue", transitionError)
		-- A failed transition always fails open so nobody can be trapped.
		finalOpen = true
		local recovered, recoveryError = pcall(applyAlpha, 1)
		if not recovered then
			warn("Garage-door fail-open pose also failed: " .. tostring(recoveryError))
		end
	end

	isOpen = finalOpen
	for _, panelData in ipairs(panels) do
		if panelData.part.Parent then
			panelData.part.CanCollide = false
		end
	end
	collisionBlocker.CanCollide = not isOpen
	refreshPrompt()
	prompt.Enabled = true
	busy = false
end

applyAlpha(currentAlpha)
collisionBlocker.CanCollide = not isOpen
refreshPrompt()

prompt.Triggered:Connect(function()
	moveDoor(not isOpen)
end)
