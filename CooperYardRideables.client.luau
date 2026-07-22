-- Player input and compact ride instructions for Cooper yard rideables.
-- Install as StarterPlayer.StarterPlayerScripts.CooperYardRideables.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("CooperYardRideablesRemotes", 15)
assert(remotes, "CooperYardRideablesRemotes was not installed")
local rideablesEvent = remotes:WaitForChild("RideablesEvent", 15)
assert(rideablesEvent and rideablesEvent:IsA("RemoteEvent"), "RideablesEvent was not installed")

local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 80
local TOUCH_BUTTON_SIZE = 56
local ACTIONS = {
	SwingForward = "CooperSwingForward",
	SwingBack = "CooperSwingBack",
	TrikeForward = "CooperTrikeForward",
	TrikeBack = "CooperTrikeBack",
	TrikeLeft = "CooperTrikeLeft",
	TrikeRight = "CooperTrikeRight",
	Reset = "CooperRideableReset",
}

local activeRideType = nil
local activeSeat = nil
local humanoid = nil
local seatConnection = nil
local characterConnection = nil
local swingForward = 0
local swingBack = 0
local trikeForward = 0
local trikeBack = 0
local trikeLeft = 0
local trikeRight = 0
local lastSwingSend = 0
local lastTrikeSend = 0
local lastThrottle = 0
local lastSteer = 0
local touchDevice = UserInputService.TouchEnabled
local configuredButtonPositions = {}
local viewportConnection = nil
local currentCameraConnection = nil

local existingGui = playerGui:FindFirstChild("CooperRideableHints")
if existingGui then
	existingGui:Destroy()
end
local hintGui = Instance.new("ScreenGui")
hintGui.Name = "CooperRideableHints"
hintGui.ResetOnSpawn = false
hintGui.IgnoreGuiInset = false
hintGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
hintGui.ClipToDeviceSafeArea = true
hintGui.DisplayOrder = 24
hintGui.Parent = playerGui

local hint = Instance.new("TextLabel")
hint.Name = "RideHint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -16)
hint.Size = UDim2.new(1, -24, 0, 48)
hint.BackgroundColor3 = Color3.fromRGB(31, 25, 20)
hint.BackgroundTransparency = 0.16
hint.BorderSizePixel = 0
hint.Font = Enum.Font.GothamSemibold
hint.TextColor3 = Color3.fromRGB(255, 239, 196)
hint.TextSize = 18
hint.TextWrapped = true
hint.Visible = false
hint.Parent = hintGui
local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 10)
hintCorner.Parent = hint
local hintStroke = Instance.new("UIStroke")
hintStroke.Color = Color3.fromRGB(194, 126, 50)
hintStroke.Thickness = 2
hintStroke.Transparency = 0.2
hintStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
hintStroke.Parent = hint
local hintSizeConstraint = Instance.new("UISizeConstraint")
hintSizeConstraint.MaxSize = Vector2.new(500, 72)
hintSizeConstraint.Parent = hint

local function inputAmount(inputState, inputObject)
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		return 0
	end
	if inputState ~= Enum.UserInputState.Begin and inputState ~= Enum.UserInputState.Change then
		return 0
	end
	if inputObject.KeyCode == Enum.KeyCode.ButtonR2 or inputObject.KeyCode == Enum.KeyCode.ButtonL2 then
		return math.clamp(inputObject.Position.Z, 0, 1)
	end
	return 1
end

local function setSwingForward(_, inputState, inputObject)
	swingForward = inputAmount(inputState, inputObject)
	return Enum.ContextActionResult.Sink
end

local function setSwingBack(_, inputState, inputObject)
	swingBack = inputAmount(inputState, inputObject)
	return Enum.ContextActionResult.Sink
end

local function setTrikeForward(_, inputState, inputObject)
	trikeForward = inputAmount(inputState, inputObject)
	return Enum.ContextActionResult.Sink
end

local function setTrikeBack(_, inputState, inputObject)
	trikeBack = inputAmount(inputState, inputObject)
	return Enum.ContextActionResult.Sink
end

local function setTrikeLeft(_, inputState, inputObject)
	trikeLeft = inputAmount(inputState, inputObject)
	return Enum.ContextActionResult.Sink
end

local function setTrikeRight(_, inputState, inputObject)
	trikeRight = inputAmount(inputState, inputObject)
	return Enum.ContextActionResult.Sink
end

local function requestReset(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if activeRideType == "Swing" then
		rideablesEvent:FireServer("ResetSwing")
	elseif activeRideType == "Trike" then
		rideablesEvent:FireServer("ResetTrike")
	end
	return Enum.ContextActionResult.Sink
end

local function unbindAll()
	for _, actionName in pairs(ACTIONS) do
		ContextActionService:UnbindAction(actionName)
	end
	table.clear(configuredButtonPositions)
	swingForward = 0
	swingBack = 0
	trikeForward = 0
	trikeBack = 0
	trikeLeft = 0
	trikeRight = 0
	lastThrottle = 0
	lastSteer = 0
end

local function viewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function touchPosition(actionName, viewport)
	local portrait = viewport.Y >= viewport.X
	if portrait then
		local positions = {
			[ACTIONS.SwingForward] = UDim2.new(0.5, 0, 1, -280),
			[ACTIONS.SwingBack] = UDim2.new(0.5, 0, 1, -140),
			[ACTIONS.TrikeForward] = UDim2.new(0.5, 0, 1, -280),
			[ACTIONS.TrikeBack] = UDim2.new(0.5, 0, 1, -140),
			[ACTIONS.TrikeLeft] = UDim2.new(0.5, -70, 1, -210),
			[ACTIONS.TrikeRight] = UDim2.new(0.5, 70, 1, -210),
			[ACTIONS.Reset] = UDim2.new(1, -70, 1, -300),
		}
		return positions[actionName]
	end

	local positions = {
		[ACTIONS.SwingForward] = UDim2.new(1, -160, 0.5, -62),
		[ACTIONS.SwingBack] = UDim2.new(1, -160, 0.5, 62),
		[ACTIONS.TrikeForward] = UDim2.new(1, -160, 0.5, -72),
		[ACTIONS.TrikeBack] = UDim2.new(1, -160, 0.5, 64),
		[ACTIONS.TrikeLeft] = UDim2.new(1, -230, 0.5, 0),
		[ACTIONS.TrikeRight] = UDim2.new(1, -90, 0.5, 0),
		[ACTIONS.Reset] = UDim2.new(1, -70, 0, 110),
	}
	return positions[actionName]
end

local function updateHintLayout(viewport)
	viewport = viewport or viewportSize()
	if touchDevice then
		-- Keep ride instructions below the family top bar, between the left task
		-- card and the right-side ride controls. The former top-right placement sat
		-- directly underneath PUMP/GO and RESET on an 800x360 phone.
		local hudClearance = math.floor(math.clamp(viewport.Y * 0.16, 56, 104))
		if viewport.Y >= viewport.X then
			hint.AnchorPoint = Vector2.new(0.5, 0)
			hint.Position = UDim2.new(0.5, 0, 0, hudClearance)
			hint.Size = UDim2.new(1, -24, 0, 72)
		else
			local hintLeft = math.floor(math.clamp(viewport.X * 0.31, 200, 240))
			local hintWidth = math.floor(math.max(180, math.min(300, viewport.X - 238 - hintLeft)))
			hint.AnchorPoint = Vector2.new(0, 0)
			hint.Position = UDim2.fromOffset(hintLeft, hudClearance)
			hint.Size = UDim2.fromOffset(hintWidth, 72)
		end
		hint.TextSize = 13
	else
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.new(0.5, 0, 1, -16)
		hint.Size = UDim2.new(1, -24, 0, 48)
		hint.TextSize = 18
	end
end

local function applyControlLayout()
	local viewport = viewportSize()
	for actionName, desktopPosition in pairs(configuredButtonPositions) do
		local position = touchDevice and touchPosition(actionName, viewport) or desktopPosition
		if position then
			ContextActionService:SetPosition(actionName, position)
		end
	end
	updateHintLayout(viewport)
end

local function bindViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyControlLayout)
	end
	applyControlLayout()
end

local function styleTouchButton(actionName, title)
	if not touchDevice then
		return
	end
	local button = ContextActionService:GetButton(actionName)
	if not button then
		return
	end
	-- Roblox's default 35px ContextAction button is below the recommended
	-- mobile touch target. Keep the native action wiring, but make every ride
	-- control large, high-contrast, and readable without covering the task HUD.
	button.Size = UDim2.fromOffset(TOUCH_BUTTON_SIZE, TOUCH_BUTTON_SIZE)
	button.ImageColor3 = Color3.fromRGB(41, 34, 27)
	button.ImageTransparency = 0.06
	button.ZIndex = 12
	local actionTitle = button:FindFirstChild("ActionTitle")
	if actionTitle and actionTitle:IsA("TextLabel") then
		actionTitle.TextColor3 = Color3.fromRGB(255, 238, 188)
		actionTitle.TextStrokeColor3 = Color3.fromRGB(38, 24, 12)
		actionTitle.TextStrokeTransparency = 0.2
		actionTitle.TextSize = if #title <= 2 or title == "◀" or title == "▶" then 18 else 12
		actionTitle.TextWrapped = true
		actionTitle.ZIndex = 13
	end
end

local function configureButton(actionName, title, position)
	ContextActionService:SetTitle(actionName, title)
	configuredButtonPositions[actionName] = position
	pcall(function()
		ContextActionService:SetImage(actionName, "")
	end)
	applyControlLayout()
	styleTouchButton(actionName, title)
end

local function bindSwing()
	ContextActionService:BindActionAtPriority(
		ACTIONS.SwingForward,
		setSwingForward,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.W,
		Enum.KeyCode.Up,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindActionAtPriority(
		ACTIONS.SwingBack,
		setSwingBack,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.S,
		Enum.KeyCode.Down,
		Enum.KeyCode.ButtonL2
	)
	ContextActionService:BindActionAtPriority(
		ACTIONS.Reset,
		requestReset,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonY
	)
	configureButton(ACTIONS.SwingForward, "PUMP +", UDim2.new(1, -160, 1, -185))
	configureButton(ACTIONS.SwingBack, "PUMP -", UDim2.new(1, -270, 1, -120))
	configureButton(ACTIONS.Reset, "RESET", UDim2.new(1, -160, 1, -295))
	hint.Text = if touchDevice
		then "TIRE SWING  •  Tap PUMP + or PUMP -" .. string.char(10) .. "RESET if stuck  •  Jump to hop off"
		else "TIRE SWING  •  W/S, ↑/↓, or triggers to pump  •  R/Y recover  •  Space to hop off"
end

local function bindTrike()
	ContextActionService:BindActionAtPriority(
		ACTIONS.TrikeForward,
		setTrikeForward,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.W,
		Enum.KeyCode.Up,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindActionAtPriority(
		ACTIONS.TrikeBack,
		setTrikeBack,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.S,
		Enum.KeyCode.Down,
		Enum.KeyCode.ButtonL2
	)
	ContextActionService:BindActionAtPriority(
		ACTIONS.TrikeLeft,
		setTrikeLeft,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.A,
		Enum.KeyCode.Left,
		Enum.KeyCode.DPadLeft
	)
	ContextActionService:BindActionAtPriority(
		ACTIONS.TrikeRight,
		setTrikeRight,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.DPadRight
	)
	ContextActionService:BindActionAtPriority(
		ACTIONS.Reset,
		requestReset,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonY
	)
	configureButton(ACTIONS.TrikeForward, "GO", UDim2.new(1, -160, 1, -185))
	configureButton(ACTIONS.TrikeBack, "BACK", UDim2.new(1, -270, 1, -120))
	configureButton(ACTIONS.TrikeLeft, "◀", UDim2.new(0, 135, 1, -155))
	configureButton(ACTIONS.TrikeRight, "▶", UDim2.new(0, 245, 1, -155))
	configureButton(ACTIONS.Reset, "RESET", UDim2.new(1, -160, 1, -295))
	hint.Text = if touchDevice
		then "TRIKE  •  GO/BACK to drive  •  ◀/▶ to steer" .. string.char(10) .. "RESET if stuck  •  Jump to hop off"
		else "TRIKE  •  W/S or triggers drive  •  A/D or D-pad steer  •  R/Y recover  •  Space to hop off"
end

local function refreshRide()
	local newSeat = humanoid and humanoid.SeatPart or nil
	local newRideType = nil
	if newSeat and newSeat:IsA("BasePart") then
		newRideType = newSeat:GetAttribute("RideableType")
	end
	if newRideType ~= "Swing" and newRideType ~= "Trike" then
		newRideType = nil
	end
	if activeSeat == newSeat and activeRideType == newRideType then
		return
	end

	if activeRideType == "Trike" then
		rideablesEvent:FireServer("TrikeControl", 0, 0)
	end
	unbindAll()
	activeSeat = newSeat
	activeRideType = newRideType
	hint.Visible = activeRideType ~= nil
	if activeRideType == "Swing" then
		bindSwing()
	elseif activeRideType == "Trike" then
		bindTrike()
	end
end

local function attachCharacter(character)
	if seatConnection then
		seatConnection:Disconnect()
		seatConnection = nil
	end
	activeSeat = nil
	activeRideType = nil
	unbindAll()
	hint.Visible = false
	humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		activeSeat = nil
		activeRideType = nil
		unbindAll()
		hint.Visible = false
		return
	end
	seatConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		task.defer(refreshRide)
	end)
	task.defer(refreshRide)
end

characterConnection = player.CharacterAdded:Connect(attachCharacter)
if player.Character then
	task.spawn(attachCharacter, player.Character)
end

currentCameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
bindViewport()

RunService.RenderStepped:Connect(function()
	if not activeRideType or not activeSeat or not activeSeat.Parent then
		return
	end
	local now = os.clock()
	if activeRideType == "Swing" then
		local pump = math.clamp(swingForward - swingBack, -1, 1)
		if pump ~= 0 and now - lastSwingSend >= 0.1 then
			lastSwingSend = now
			rideablesEvent:FireServer("SwingPump", pump)
		end
	elseif activeRideType == "Trike" then
		local throttle = math.clamp(trikeForward - trikeBack, -1, 1)
		local steer = math.clamp(trikeRight - trikeLeft, -1, 1)
		local changed = throttle ~= lastThrottle or steer ~= lastSteer
		if changed or now - lastTrikeSend >= 0.1 then
			lastTrikeSend = now
			lastThrottle = throttle
			lastSteer = steer
			rideablesEvent:FireServer("TrikeControl", throttle, steer)
		end
	end
end)

script.Destroying:Connect(function()
	unbindAll()
	if seatConnection then
		seatConnection:Disconnect()
	end
	if characterConnection then
		characterConnection:Disconnect()
	end
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	if currentCameraConnection then
		currentCameraConnection:Disconnect()
	end
	if hintGui then
		hintGui:Destroy()
	end
end)

print("[CooperYardRideables] Client controls ready")
