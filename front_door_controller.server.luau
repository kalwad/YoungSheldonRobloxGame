--!strict
-- Relocation- and obstruction-safe controller for the Cooper front door.

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local door = script.Parent
assert(door and door:IsA("Model"), "FrontDoorController must be parented to the front-door Model")
local prompt = door.Parent:WaitForChild("FrontDoorPromptAnchor"):WaitForChild("DoorPrompt") :: ProximityPrompt
assert(prompt:IsA("ProximityPrompt"), "Front DoorPrompt must be a ProximityPrompt")

-- SECURITY: ProximityPrompt client presentation is not an authority boundary.
-- Revalidate the exact live player/root and a hard-capped server distance, then
-- consume this door action's own rate budget before touching physical state.
local PROMPT_RATE_SECONDS = 0.65
local PROMPT_DISTANCE_SLACK = 3
local PROMPT_DISTANCE_HARD_CAP = 16
local nextPromptAtByPlayer: { [Player]: number } = {}

local function livePlayerRoot(player: Player): BasePart?
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return nil
	end
	local partyState = player:GetAttribute("CooperPartyState")
	if player:GetAttribute("CooperPartyMember") ~= true
		or player:GetAttribute("CooperGameProfileLoaded") ~= true
		or (partyState ~= "Active" and partyState ~= "HostGrace")
	then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(Workspace)
		or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") or not root:IsDescendantOf(character)
	then
		return nil
	end
	return root
end

local function promptWorldPosition(): Vector3?
	local anchor = prompt.Parent
	if anchor and anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor and anchor:IsA("BasePart") then
		return anchor.Position
	end
	return nil
end

local function playerCanReachPrompt(player: Player): boolean
	local root = livePlayerRoot(player)
	local position = promptWorldPosition()
	if not root or not position or not prompt.Enabled or not prompt:IsDescendantOf(Workspace) then
		return false
	end
	local maximumDistance = math.clamp(
		prompt.MaxActivationDistance + PROMPT_DISTANCE_SLACK,
		4,
		PROMPT_DISTANCE_HARD_CAP
	)
	return (root.Position - position).Magnitude <= maximumDistance
end

local function consumePromptRate(player: Player): boolean
	local now = Workspace:GetServerTimeNow()
	if now < (nextPromptAtByPlayer[player] or 0) then
		return false
	end
	nextPromptAtByPlayer[player] = now + PROMPT_RATE_SECONDS
	return true
end

local closedPivot = door:GetAttribute("ClosedPivot")
local openPivot = door:GetAttribute("OpenPivot")
local isOpen = door:GetAttribute("IsOpen") == true
local currentPivot = door:GetPivot()
local expectedPivot = if isOpen then openPivot else closedPivot
local swing = math.rad(tonumber(door:GetAttribute("SwingDegrees")) or -102)

if typeof(closedPivot) ~= "CFrame" or typeof(openPivot) ~= "CFrame" then
	if isOpen then
		openPivot = currentPivot
		closedPivot = currentPivot * CFrame.Angles(0, -swing, 0)
	else
		closedPivot = currentPivot
		openPivot = currentPivot * CFrame.Angles(0, swing, 0)
	end
elseif typeof(expectedPivot) ~= "CFrame" or (expectedPivot.Position - currentPivot.Position).Magnitude > 2 then
	local closedToOpen = closedPivot:ToObjectSpace(openPivot)
	local openToClosed = openPivot:ToObjectSpace(closedPivot)
	if isOpen then
		openPivot = currentPivot
		closedPivot = currentPivot * openToClosed
	else
		closedPivot = currentPivot
		openPivot = currentPivot * closedToOpen
	end
end

door:SetAttribute("ClosedPivot", closedPivot)
door:SetAttribute("OpenPivot", openPivot)
door:SetAttribute("IsOpen", isOpen)
door:SetAttribute("AutomationHoldOpen", false)
door:SetAttribute("AutomationOriginalOpen", nil)

local function updatePromptText()
	if door:GetAttribute("AutomationHoldOpen") == true and isOpen then
		prompt.ActionText = "Door held open"
	else
		prompt.ActionText = if isOpen then "Close Door" else "Open Door"
	end
end

updatePromptText()

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.FilterDescendantsInstances = { door }
local environment = door:FindFirstAncestor("CooperHouseEnvironment")
local house = environment and environment:FindFirstChild("CooperHouse")
local structure = house and house:FindFirstChild("Structure")
local rooms = house and house:FindFirstChild("InteriorRooms")
local exterior = door.Parent
local colliders = {}
for _, descendant in ipairs(door:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant.CanCollide then
		table.insert(colliders, descendant)
	end
end

local function isDoorObstruction(part: BasePart): boolean
	local ancestor: Instance? = part
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
	if not part.CanCollide then
		return false
	end
	return not ((structure and part:IsDescendantOf(structure))
		or (rooms and part:IsDescendantOf(rooms))
		or (exterior and part:IsDescendantOf(exterior)))
end

local function swingPathObstructed(): boolean
	for _, collider in ipairs(colliders) do
		local querySize = Vector3.new(
			math.max(0.05, collider.Size.X - 0.08),
			math.max(0.05, collider.Size.Y - 0.08),
			math.max(0.05, collider.Size.Z - 0.08)
		)
		for _, hit in ipairs(Workspace:GetPartBoundsInBox(collider.CFrame, querySize, overlapParams)) do
			if isDoorObstruction(hit) then
				return true
			end
		end
	end
	return false
end

local busy = false
local function setDoor(open: boolean): boolean
	if busy then
		return false
	end
	if isOpen == open then
		updatePromptText()
		return true
	end
	busy = true
	local driver = Instance.new("CFrameValue")
	driver.Value = door:GetPivot()
	local startingPivot = door:GetPivot()
	local obstructed = false
	local tween
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		door:PivotTo(driver.Value)
		if not obstructed and swingPathObstructed() then
			obstructed = true
			if tween then
				tween:Cancel()
			end
		end
	end)
	local target = if open then openPivot else closedPivot
	tween = TweenService:Create(
		driver,
		TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Value = target }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	if obstructed then
		door:PivotTo(startingPivot)
		driver:Destroy()
		prompt.ActionText = "Door blocked"
		task.delay(0.9, function()
			if door.Parent and not busy then
				updatePromptText()
			end
		end)
		busy = false
		return false
	end
	door:PivotTo(target)
	driver:Destroy()
	isOpen = open
	door:SetAttribute("IsOpen", open)
	busy = false
	updatePromptText()
	return true
end

prompt.Triggered:Connect(function(player: Player)
	if not playerCanReachPrompt(player) or not consumePromptRate(player)
		or busy or door.Parent == nil or door:GetAttribute("IsOpen") ~= isOpen
	then
		return
	end
	if door:GetAttribute("AutomationHoldOpen") == true and isOpen then
		updatePromptText()
		return
	end
	setDoor(not isOpen)
end)

Players.PlayerRemoving:Connect(function(player)
	nextPromptAtByPlayer[player] = nil
end)

local automationCommandInstance = door:FindFirstChild("AutomationDoorCommand")
if automationCommandInstance and not automationCommandInstance:IsA("BindableFunction") then
	automationCommandInstance:Destroy()
	automationCommandInstance = nil
end
if not automationCommandInstance then
	automationCommandInstance = Instance.new("BindableFunction")
	automationCommandInstance.Name = "AutomationDoorCommand"
	automationCommandInstance.Parent = door
end
local automationDoorCommand = automationCommandInstance :: BindableFunction
local automationHoldCount = 0
local automationOriginalOpen: boolean? = nil

local function acquireAutomationHold(): (boolean, boolean, boolean, boolean?)
	local firstHolder = automationHoldCount == 0
	if firstHolder then
		automationOriginalOpen = isOpen
		door:SetAttribute("AutomationOriginalOpen", isOpen)
	end
	automationHoldCount += 1
	door:SetAttribute("AutomationHoldOpen", true)
	updatePromptText()
	local success = setDoor(true)
	if not success then
		automationHoldCount -= 1
		if automationHoldCount == 0 then
			door:SetAttribute("AutomationHoldOpen", false)
			door:SetAttribute("AutomationOriginalOpen", nil)
			automationOriginalOpen = nil
		end
		updatePromptText()
	end
	return success, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
end

local function releaseAutomationHold(restoreOverride: any): (boolean, boolean, boolean, boolean?)
	if automationHoldCount <= 0 then
		return false, isOpen, door:GetAttribute("AutomationHoldOpen") == true, nil
	end
	if automationHoldCount > 1 then
		automationHoldCount -= 1
		return true, isOpen, true, automationOriginalOpen
	end
	local restoreOpen = if typeof(restoreOverride) == "boolean"
		then restoreOverride
		else automationOriginalOpen == true
	door:SetAttribute("AutomationHoldOpen", false)
	updatePromptText()
	local success = setDoor(restoreOpen)
	if success then
		automationHoldCount = 0
		automationOriginalOpen = nil
		door:SetAttribute("AutomationOriginalOpen", nil)
	else
		-- A blocked close must remain held open so another player cannot defeat the
		-- automation corridor while its owner retries the release.
		automationHoldCount = 1
		door:SetAttribute("AutomationHoldOpen", true)
	end
	updatePromptText()
	return success, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
end

automationDoorCommand.OnInvoke = function(action: any, value: any)
	if typeof(action) == "boolean" then
		if action == false and door:GetAttribute("AutomationHoldOpen") == true then
			return false, isOpen, true, automationOriginalOpen
		end
		local success = setDoor(action)
		return success, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
	end
	if typeof(action) ~= "string" then
		return false, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
	end
	local command = string.lower(action)
	if command == "getstate" then
		return true, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
	elseif command == "open" then
		local success = setDoor(true)
		return success, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
	elseif command == "close" then
		if door:GetAttribute("AutomationHoldOpen") == true then
			return false, isOpen, true, automationOriginalOpen
		end
		local success = setDoor(false)
		return success, isOpen, false, automationOriginalOpen
	elseif command == "setopen" and typeof(value) == "boolean" then
		if value == false and door:GetAttribute("AutomationHoldOpen") == true then
			return false, isOpen, true, automationOriginalOpen
		end
		local success = setDoor(value)
		return success, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
	elseif command == "acquireholdopen" or command == "holdopen" then
		return acquireAutomationHold()
	elseif command == "releaseholdopen" or command == "restore" then
		return releaseAutomationHold(value)
	end
	return false, isOpen, door:GetAttribute("AutomationHoldOpen") == true, automationOriginalOpen
end
