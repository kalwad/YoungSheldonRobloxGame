--!nonstrict
-- Client UI/input companion for the server-authoritative Cooper house interactions.
-- Installed into StarterPlayerScripts as "CooperInteractions".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local touchDevice = UserInputService.TouchEnabled
local touchOnly = touchDevice and not UserInputService.KeyboardEnabled
local remotes = ReplicatedStorage:WaitForChild("CooperInteractionsRemotes", 20)
if not remotes then
	warn("[CooperInteractions] Client remotes were not installed")
	return
end
local requestEvent = remotes:WaitForChild("Request", 8)
local clientEvent = remotes:WaitForChild("Client", 8)
if not requestEvent
	or not requestEvent:IsA("RemoteEvent")
	or not clientEvent
	or not clientEvent:IsA("RemoteEvent")
then
	warn("[CooperInteractions] Client RemoteEvents are incomplete")
	return
end

local oldGui = playerGui:FindFirstChild("CooperInteractionsGui")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperInteractionsGui"
gui.ResetOnSpawn = false
-- Phone modals must live below the Roblox top bar and inside notched-screen
-- safe areas. Preserve the original desktop canvas while opting touch devices
-- into the stronger Core UI inset.
gui.IgnoreGuiInset = not touchDevice
gui.ScreenInsets = touchDevice and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.DeviceSafeInsets
gui.ClipToDeviceSafeArea = true
-- Cube/terminal interaction windows are true modals and must render above the
-- always-on family task HUD (DisplayOrder 35).
gui.DisplayOrder = 55
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- A transparent probe gives responsive code the exact drawable ScreenGui
-- dimensions after Core UI and device-safe insets have been applied.
local safeAreaProbe = Instance.new("Frame")
safeAreaProbe.Name = "SafeAreaProbe"
safeAreaProbe.Size = UDim2.fromScale(1, 1)
safeAreaProbe.BackgroundTransparency = 1
safeAreaProbe.BorderSizePixel = 0
safeAreaProbe.Active = false
safeAreaProbe.Selectable = false
safeAreaProbe.Parent = gui

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.new(1, 1, 1)
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function makeButton(parent, name, text, size, position)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(54, 59, 63)
	button.AutoButtonColor = true
	button.TextColor3 = Color3.fromRGB(245, 245, 235)
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.Parent = parent
	addCorner(button, 7)
	addStroke(button, Color3.fromRGB(118, 126, 132), 1, 0.35)
	return button
end

-- Toasts --------------------------------------------------------------------

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 38)
toast.Size = UDim2.new(0, 520, 0, 54)
toast.BackgroundColor3 = Color3.fromRGB(24, 25, 26)
toast.BackgroundTransparency = 1
toast.TextColor3 = Color3.fromRGB(255, 249, 224)
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamSemibold
toast.TextSize = 20
toast.TextWrapped = true
toast.Visible = false
toast.Parent = gui
addCorner(toast, 10)
addStroke(toast, Color3.fromRGB(217, 184, 102), 2, 0.25)

local toastToken = 0
local function showToast(message, duration)
	toastToken = toastToken + 1
	local token = toastToken
	toast.Text = tostring(message)
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.12,
		TextTransparency = 0,
	}):Play()
	task.delay(duration or 2.5, function()
		if token ~= toastToken then
			return
		end
		local tween = TweenService:Create(toast, TweenInfo.new(0.25), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

-- Timed-action progress ------------------------------------------------------

local progressPanel = Instance.new("Frame")
progressPanel.Name = "ProgressPanel"
progressPanel.AnchorPoint = Vector2.new(0.5, 1)
progressPanel.Position = UDim2.new(0.5, 0, 1, -92)
progressPanel.Size = UDim2.new(0, 420, 0, 70)
progressPanel.BackgroundColor3 = Color3.fromRGB(27, 28, 29)
progressPanel.BackgroundTransparency = 0.08
progressPanel.Visible = false
progressPanel.Parent = gui
addCorner(progressPanel, 10)
addStroke(progressPanel, Color3.fromRGB(220, 215, 186), 1, 0.25)

local progressText = Instance.new("TextLabel")
progressText.Size = UDim2.new(1, -24, 0, 34)
progressText.Position = UDim2.fromOffset(12, 6)
progressText.BackgroundTransparency = 1
progressText.TextColor3 = Color3.fromRGB(245, 241, 218)
progressText.Font = Enum.Font.GothamSemibold
progressText.TextSize = 18
progressText.TextXAlignment = Enum.TextXAlignment.Left
progressText.Parent = progressPanel

local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.new(1, -24, 0, 12)
progressTrack.Position = UDim2.fromOffset(12, 46)
progressTrack.BackgroundColor3 = Color3.fromRGB(64, 67, 67)
progressTrack.Parent = progressPanel
addCorner(progressTrack, 6)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Color3.fromRGB(78, 171, 198)
progressFill.Parent = progressTrack
addCorner(progressFill, 6)

local progressToken = 0
local progressTween = nil
local function showProgress(text, duration)
	progressToken = progressToken + 1
	local token = progressToken
	if progressTween then
		progressTween:Cancel()
	end
	progressText.Text = text
	progressFill.Size = UDim2.fromScale(0, 1)
	progressPanel.Visible = true
	progressTween = TweenService:Create(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 1),
	})
	progressTween:Play()
	task.delay(duration, function()
		if token == progressToken then
			progressPanel.Visible = false
			progressTween = nil
		end
	end)
end

local function endProgress()
	progressToken = progressToken + 1
	if progressTween then
		progressTween:Cancel()
		progressTween = nil
	end
	progressPanel.Visible = false
end

-- Held-object controls -------------------------------------------------------

local heldPanel = Instance.new("Frame")
heldPanel.Name = "HeldPanel"
heldPanel.AnchorPoint = Vector2.new(1, 1)
heldPanel.Position = UDim2.new(1, -28, 1, -28)
heldPanel.Size = UDim2.fromOffset(330, 118)
heldPanel.BackgroundColor3 = Color3.fromRGB(27, 28, 30)
heldPanel.BackgroundTransparency = 0.08
heldPanel.Visible = false
heldPanel.Parent = gui
addCorner(heldPanel, 10)
addStroke(heldPanel, Color3.fromRGB(205, 188, 137), 1, 0.2)
local heldScale = Instance.new("UIScale")
heldScale.Parent = heldPanel

local heldTitle = Instance.new("TextLabel")
heldTitle.Size = UDim2.new(1, -20, 0, 34)
heldTitle.Position = UDim2.fromOffset(10, 6)
heldTitle.BackgroundTransparency = 1
heldTitle.TextColor3 = Color3.fromRGB(252, 244, 215)
heldTitle.Font = Enum.Font.GothamBold
heldTitle.TextSize = 18
heldTitle.TextXAlignment = Enum.TextXAlignment.Left
heldTitle.Parent = heldPanel

local throwButton = makeButton(heldPanel, "Throw", "THROW  [T]", UDim2.fromOffset(144, 54), UDim2.fromOffset(12, 50))
throwButton.BackgroundColor3 = Color3.fromRGB(150, 61, 44)
local dropButton = makeButton(heldPanel, "Drop", "DROP  [G]", UDim2.fromOffset(144, 54), UDim2.fromOffset(174, 50))
local solveHeldButton = makeButton(heldPanel, "Solve", "SOLVE CUBE  [C]", UDim2.fromOffset(306, 48), UDim2.fromOffset(12, 112))
solveHeldButton.BackgroundColor3 = Color3.fromRGB(54, 106, 133)
solveHeldButton.Visible = false

local function updateHeldInputHints()
	if UserInputService.GamepadEnabled then
		throwButton.Text = "THROW  [T / X]"
		dropButton.Text = "DROP  [G / B]"
		solveHeldButton.Text = "SOLVE CUBE  [C / Y]"
	elseif touchOnly then
		throwButton.Text = "THROW"
		dropButton.Text = "DROP"
		solveHeldButton.Text = "SOLVE CUBE"
	else
		throwButton.Text = "THROW  [T]"
		dropButton.Text = "DROP  [G]"
		solveHeldButton.Text = "SOLVE CUBE  [C]"
	end
end

updateHeldInputHints()
UserInputService:GetPropertyChangedSignal("GamepadEnabled"):Connect(updateHeldInputHints)

local isHolding = false
local holdingCube = false

throwButton.Activated:Connect(function()
	if isHolding then
		requestEvent:FireServer("HeldAction", "Throw")
	end
end)
dropButton.Activated:Connect(function()
	if isHolding then
		requestEvent:FireServer("HeldAction", "Drop")
	end
end)
solveHeldButton.Activated:Connect(function()
	if isHolding and holdingCube then
		requestEvent:FireServer("HeldAction", "Solve")
	end
end)

-- Cooper-DOS terminal --------------------------------------------------------

local terminal = Instance.new("Frame")
terminal.Name = "Terminal"
terminal.AnchorPoint = Vector2.new(0.5, 0.5)
terminal.Position = UDim2.fromScale(0.5, 0.5)
terminal.Size = UDim2.new(0.9, 0, 0.84, 0)
terminal.BackgroundColor3 = Color3.fromRGB(6, 17, 10)
terminal.Visible = false
terminal.Active = true
terminal.Parent = gui
addCorner(terminal, 8)
addStroke(terminal, Color3.fromRGB(96, 255, 143), 2, 0.08)

local terminalSize = Instance.new("UISizeConstraint")
terminalSize.MinSize = Vector2.new(300, 260)
terminalSize.MaxSize = Vector2.new(900, 640)
terminalSize.Parent = terminal

local terminalTitle = Instance.new("TextLabel")
terminalTitle.Size = UDim2.new(1, -56, 0, 44)
terminalTitle.Position = UDim2.fromOffset(16, 4)
terminalTitle.BackgroundTransparency = 1
terminalTitle.Text = "COOPER-DOS 3.11  //  SHELDON'S TERMINAL"
terminalTitle.TextColor3 = Color3.fromRGB(99, 255, 141)
terminalTitle.Font = Enum.Font.RobotoMono
terminalTitle.TextSize = 19
terminalTitle.TextXAlignment = Enum.TextXAlignment.Left
terminalTitle.Parent = terminal

local terminalClose = makeButton(terminal, "Close", "X", UDim2.fromOffset(38, 34), UDim2.new(1, -45, 0, 8))
terminalClose.BackgroundColor3 = Color3.fromRGB(88, 33, 33)
if touchDevice then
	terminalClose.Size = UDim2.fromOffset(48, 44)
	terminalClose.Position = UDim2.new(1, -56, 0, 4)
	terminalTitle.Size = UDim2.new(1, -76, 0, 44)
end

local terminalOutput = Instance.new("ScrollingFrame")
terminalOutput.Name = "Output"
terminalOutput.Position = UDim2.fromOffset(15, 50)
terminalOutput.Size = UDim2.new(1, -30, 1, -116)
terminalOutput.BackgroundColor3 = Color3.fromRGB(3, 9, 5)
terminalOutput.BorderSizePixel = 0
terminalOutput.ScrollBarThickness = 6
terminalOutput.ScrollBarImageColor3 = Color3.fromRGB(78, 174, 105)
terminalOutput.CanvasSize = UDim2.fromOffset(0, 0)
terminalOutput.AutomaticCanvasSize = Enum.AutomaticSize.Y
terminalOutput.Parent = terminal
addCorner(terminalOutput, 4)

local terminalList = Instance.new("UIListLayout")
terminalList.Padding = UDim.new(0, 3)
terminalList.SortOrder = Enum.SortOrder.LayoutOrder
terminalList.Parent = terminalOutput
local terminalPadding = Instance.new("UIPadding")
terminalPadding.PaddingLeft = UDim.new(0, 10)
terminalPadding.PaddingRight = UDim.new(0, 10)
terminalPadding.PaddingTop = UDim.new(0, 8)
terminalPadding.PaddingBottom = UDim.new(0, 8)
terminalPadding.Parent = terminalOutput

local dosPrompt = "C:" .. string.char(92) .. ">"
local terminalInput = Instance.new("TextBox")
terminalInput.Name = "CommandInput"
terminalInput.Position = UDim2.new(0, 15, 1, -54)
terminalInput.Size = UDim2.new(1, -30, 0, 40)
terminalInput.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
terminalInput.TextColor3 = Color3.fromRGB(112, 255, 150)
terminalInput.PlaceholderColor3 = Color3.fromRGB(75, 135, 91)
terminalInput.PlaceholderText = dosPrompt .. " type a command and press Enter"
terminalInput.ClearTextOnFocus = false
terminalInput.Font = Enum.Font.RobotoMono
terminalInput.TextSize = 18
terminalInput.TextXAlignment = Enum.TextXAlignment.Left
terminalInput.Text = ""
terminalInput.Parent = terminal
addCorner(terminalInput, 4)
local inputPadding = Instance.new("UIPadding")
inputPadding.PaddingLeft = UDim.new(0, 10)
inputPadding.PaddingRight = UDim.new(0, 10)
inputPadding.Parent = terminalInput

local terminalSendButton = makeButton(
	terminal,
	"SendCommand",
	"SEND",
	UDim2.fromOffset(96, 48),
	UDim2.new(1, -111, 1, -62)
)
terminalSendButton.BackgroundColor3 = Color3.fromRGB(24, 92, 48)
terminalSendButton.Visible = touchOnly
if touchDevice then
	-- A tablet can report both touch and keyboard support. Keep its text field
	-- and close control finger-sized even when the optional SEND button is not
	-- needed because a physical keyboard is connected.
	terminalInput.Position = UDim2.new(0, 15, 1, -58)
	terminalInput.Size = UDim2.new(1, -30, 0, 44)
	terminalOutput.Size = UDim2.new(1, -30, 1, -120)
end
if touchOnly then
	terminalInput.Position = UDim2.new(0, 15, 1, -62)
	terminalInput.Size = UDim2.new(1, -142, 0, 48)
	terminalInput.PlaceholderText = dosPrompt .. " type a command"
	terminalOutput.Size = UDim2.new(1, -30, 1, -124)
end

local MAX_TERMINAL_LINES = 160
local terminalLineCount = 0
local terminalLines = {}
local function addTerminalLine(text, color)
	terminalLineCount = terminalLineCount + 1
	local line = Instance.new("TextLabel")
	line.Name = string.format("Line%03d", terminalLineCount)
	line.Size = UDim2.new(1, -4, 0, 22)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.BackgroundTransparency = 1
	line.TextColor3 = color or Color3.fromRGB(100, 238, 137)
	line.Text = text
	line.TextWrapped = true
	line.Font = Enum.Font.RobotoMono
	line.TextSize = 16
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.Parent = terminalOutput
	table.insert(terminalLines, line)
	while #terminalLines > MAX_TERMINAL_LINES do
		local oldest = table.remove(terminalLines, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.defer(function()
		terminalOutput.CanvasPosition = Vector2.new(0, math.max(0, terminalList.AbsoluteContentSize.Y))
	end)
end

local function clearTerminal()
	for _, child in ipairs(terminalOutput:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	terminalLineCount = 0
	table.clear(terminalLines)
end

local function closeTerminal(notifyServer)
	local wasVisible = terminal.Visible
	terminal.Visible = false
	terminalInput:ReleaseFocus()
	if wasVisible and notifyServer ~= false then
		requestEvent:FireServer("TerminalClose")
	end
end

terminalClose.Activated:Connect(closeTerminal)
local function submitTerminalCommand()
	if not terminal.Visible then
		return
	end
	local command = string.sub(terminalInput.Text, 1, 80)
	terminalInput.Text = ""
	if command ~= "" then
		requestEvent:FireServer("TerminalCommand", command)
	end
	if not touchOnly then
		task.defer(function()
			if terminal.Visible then
				terminalInput:CaptureFocus()
			end
		end)
	end
end

terminalSendButton.Activated:Connect(submitTerminalCommand)
terminalInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submitTerminalCommand()
	end
end)

-- Fully legal 3x3 cube state and move UI ------------------------------------

local cubeWindow = Instance.new("Frame")
cubeWindow.Name = "PuzzleCube"
cubeWindow.AnchorPoint = Vector2.new(0.5, 0.5)
cubeWindow.Position = UDim2.fromScale(0.5, 0.5)
cubeWindow.Size = UDim2.fromOffset(790, 620)
cubeWindow.BackgroundColor3 = Color3.fromRGB(28, 29, 31)
cubeWindow.Visible = false
cubeWindow.Active = true
cubeWindow.Parent = gui
addCorner(cubeWindow, 10)
addStroke(cubeWindow, Color3.fromRGB(226, 221, 198), 2, 0.15)
local cubeScale = Instance.new("UIScale")
cubeScale.Parent = cubeWindow
local cubeSize = Instance.new("UISizeConstraint")
cubeSize.MinSize = Vector2.new(690, 560)
cubeSize.MaxSize = Vector2.new(790, 620)
cubeSize.Parent = cubeWindow

local cubeTitle
local cubeClose
local cubeStatus
local reshuffle
local giveUpThrowButton
local facePanels = {}
local faceGrids = {}
local cubeMoveButtons = {}
local cubeLayoutReady = false

local cameraViewportConnection = nil
local function updateResponsiveLayout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local safeSize = safeAreaProbe.AbsoluteSize
	if safeSize.X <= 1 or safeSize.Y <= 1 then
		safeSize = viewport
	end
	local availableWidth = math.max(1, (touchDevice and safeSize.X or viewport.X) - 24)
	local availableHeight = math.max(1, (touchDevice and safeSize.Y or viewport.Y) - 24)
	local landscapePhone = touchDevice
		and viewport.X > viewport.Y
		and math.min(viewport.X, viewport.Y) <= 600

	heldScale.Scale = math.max(0.55, math.min(1, availableWidth / 330))
	-- Leave the lower-right Roblox jump/control zone clear on touch devices.
	if touchDevice then
		local heldHeight = math.max(1, heldPanel.Size.Y.Offset * heldScale.Scale)
		local controlClearance = math.max(104, math.min(150, safeSize.Y - heldHeight - 12))
		heldPanel.Position = UDim2.new(1, -18, 1, -controlClearance)
	else
		heldPanel.Position = UDim2.new(1, -12, 1, -12)
	end
	toast.Size = UDim2.fromOffset(math.min(520, availableWidth), 54)
	progressPanel.Size = UDim2.fromOffset(math.min(420, availableWidth), 70)

	if not cubeLayoutReady then
		cubeScale.Scale = math.max(0.1, math.min(1, availableWidth / 790, availableHeight / 620))
		return
	end

	local desktopFacePositions = {
		U = Vector2.new(269, 82),
		L = Vector2.new(137, 214),
		F = Vector2.new(269, 214),
		R = Vector2.new(401, 214),
		B = Vector2.new(533, 214),
		D = Vector2.new(269, 346),
	}
	local moveFaceOrder = { "U", "D", "L", "R", "F", "B" }

	if not landscapePhone then
		-- Preserve every original desktop/tablet dimension and position.
		cubeWindow.Size = UDim2.fromOffset(790, 620)
		cubeSize.MinSize = Vector2.new(690, 560)
		cubeSize.MaxSize = Vector2.new(790, 620)
		cubeScale.Scale = math.max(0.1, math.min(1, availableWidth / 790, availableHeight / 620))
		cubeTitle.Position = UDim2.fromOffset(18, 8)
		cubeTitle.Size = UDim2.new(1, -76, 0, 38)
		cubeTitle.TextSize = 22
		cubeClose.Position = if touchDevice then UDim2.new(1, -56, 0, 4) else UDim2.new(1, -50, 0, 9)
		cubeClose.Size = if touchDevice then UDim2.fromOffset(48, 44) else UDim2.fromOffset(40, 34)
		cubeClose.TextSize = 17
		cubeStatus.Position = UDim2.fromOffset(18, 49)
		cubeStatus.Size = UDim2.new(1, -36, 0, 29)
		cubeStatus.TextSize = 15
		cubeStatus.TextWrapped = false
		for faceName, panel in pairs(facePanels) do
			panel.Position = UDim2.fromOffset(desktopFacePositions[faceName].X, desktopFacePositions[faceName].Y)
			panel.Size = UDim2.fromOffset(120, 120)
			faceGrids[faceName].CellSize = UDim2.fromOffset(36, 36)
			faceGrids[faceName].CellPadding = UDim2.fromOffset(3, 3)
		end
		for index, faceName in ipairs(moveFaceOrder) do
			local x = 42 + (index - 1) * 121
			local pair = cubeMoveButtons[faceName]
			pair.clockwise.Position = UDim2.fromOffset(x, 490)
			pair.clockwise.Size = UDim2.fromOffset(52, 48)
			pair.clockwise.TextSize = 17
			pair.inverse.Position = UDim2.fromOffset(x + 57, 490)
			pair.inverse.Size = UDim2.fromOffset(52, 48)
			pair.inverse.TextSize = 17
		end
		reshuffle.Position = UDim2.fromOffset(170, 555)
		reshuffle.Size = UDim2.fromOffset(190, 46)
		reshuffle.TextSize = 17
		giveUpThrowButton.Position = UDim2.fromOffset(390, 555)
		giveUpThrowButton.Size = UDim2.fromOffset(250, 46)
		giveUpThrowButton.TextSize = 17
		return
	end

	-- Dedicated phone-landscape layout. It uses the safe canvas directly instead
	-- of shrinking the 790x620 desktop window into unreadable, 20px controls.
	cubeScale.Scale = 1
	cubeSize.MinSize = Vector2.zero
	cubeSize.MaxSize = Vector2.new(10000, 10000)
	cubeWindow.Size = UDim2.new(1, -16, 1, -16)
	local cubeWidth = math.max(520, safeSize.X - 16)
	local cubeHeight = math.max(260, safeSize.Y - 16)

	cubeTitle.Position = UDim2.fromOffset(16, 4)
	cubeTitle.Size = UDim2.new(1, -82, 0, 38)
	cubeTitle.TextSize = 18
	cubeClose.Position = UDim2.new(1, -56, 0, 2)
	cubeClose.Size = UDim2.fromOffset(48, 44)
	cubeClose.TextSize = 18

	local requiredControlsWidth = 6 * 44 + 5 * 4
	local maximumNetWidth = math.max(180, cubeWidth - requiredControlsWidth - 38)
	local faceSize = math.clamp(math.floor((maximumNetWidth - 12) / 4), 42, 62)
	local faceGap = 4
	local faceStep = faceSize + faceGap
	local netLeft = 12
	local netTop = 48
	local mobileFacePositions = {
		U = Vector2.new(netLeft + faceStep, netTop),
		L = Vector2.new(netLeft, netTop + faceStep),
		F = Vector2.new(netLeft + faceStep, netTop + faceStep),
		R = Vector2.new(netLeft + faceStep * 2, netTop + faceStep),
		B = Vector2.new(netLeft + faceStep * 3, netTop + faceStep),
		D = Vector2.new(netLeft + faceStep, netTop + faceStep * 2),
	}
	local stickerGap = 2
	local stickerSize = math.max(11, math.floor((faceSize - stickerGap * 2) / 3))
	for faceName, panel in pairs(facePanels) do
		panel.Position = UDim2.fromOffset(mobileFacePositions[faceName].X, mobileFacePositions[faceName].Y)
		panel.Size = UDim2.fromOffset(faceSize, faceSize)
		faceGrids[faceName].CellSize = UDim2.fromOffset(stickerSize, stickerSize)
		faceGrids[faceName].CellPadding = UDim2.fromOffset(stickerGap, stickerGap)
	end

	local netWidth = faceSize * 4 + faceGap * 3
	local controlsLeft = netLeft + netWidth + 14
	local controlsWidth = math.max(requiredControlsWidth, cubeWidth - controlsLeft - 12)
	local moveGap = 4
	local moveWidth = math.max(44, math.floor((controlsWidth - moveGap * 5) / 6))
	local moveHeight = 48
	local moveTop = 72
	cubeStatus.Position = UDim2.fromOffset(controlsLeft, 36)
	cubeStatus.Size = UDim2.fromOffset(controlsWidth, 33)
	cubeStatus.TextSize = 13
	cubeStatus.TextWrapped = true
	for index, faceName in ipairs(moveFaceOrder) do
		local x = controlsLeft + (index - 1) * (moveWidth + moveGap)
		local pair = cubeMoveButtons[faceName]
		pair.clockwise.Position = UDim2.fromOffset(x, moveTop)
		pair.clockwise.Size = UDim2.fromOffset(moveWidth, moveHeight)
		pair.clockwise.TextSize = 18
		pair.inverse.Position = UDim2.fromOffset(x, moveTop + moveHeight + 6)
		pair.inverse.Size = UDim2.fromOffset(moveWidth, moveHeight)
		pair.inverse.TextSize = 18
	end

	local actionTop = math.min(cubeHeight - 54, moveTop + moveHeight * 2 + 20)
	local actionGap = 8
	local actionWidth = math.floor((controlsWidth - actionGap) * 0.5)
	reshuffle.Position = UDim2.fromOffset(controlsLeft, actionTop)
	reshuffle.Size = UDim2.fromOffset(actionWidth, 46)
	reshuffle.TextSize = 14
	giveUpThrowButton.Position = UDim2.fromOffset(controlsLeft + actionWidth + actionGap, actionTop)
	giveUpThrowButton.Size = UDim2.fromOffset(actionWidth, 46)
	giveUpThrowButton.TextSize = 14
end

local function bindCurrentCamera()
	if cameraViewportConnection then
		cameraViewportConnection:Disconnect()
		cameraViewportConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
	updateResponsiveLayout()
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCurrentCamera)
safeAreaProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveLayout)
bindCurrentCamera()

cubeTitle = Instance.new("TextLabel")
cubeTitle.Position = UDim2.fromOffset(18, 8)
cubeTitle.Size = UDim2.new(1, -76, 0, 38)
cubeTitle.BackgroundTransparency = 1
cubeTitle.Text = "SHELDON'S PUZZLE CUBE"
cubeTitle.TextColor3 = Color3.fromRGB(245, 241, 220)
cubeTitle.Font = Enum.Font.GothamBold
cubeTitle.TextSize = 22
cubeTitle.TextXAlignment = Enum.TextXAlignment.Left
cubeTitle.Parent = cubeWindow

cubeClose = makeButton(cubeWindow, "Close", "X", UDim2.fromOffset(40, 34), UDim2.new(1, -50, 0, 9))
cubeClose.BackgroundColor3 = Color3.fromRGB(88, 38, 38)

cubeStatus = Instance.new("TextLabel")
cubeStatus.Position = UDim2.fromOffset(18, 49)
cubeStatus.Size = UDim2.new(1, -36, 0, 29)
cubeStatus.BackgroundTransparency = 1
cubeStatus.Text = "Make every face one color. Use a prime move to turn the other way."
cubeStatus.TextColor3 = Color3.fromRGB(191, 194, 187)
cubeStatus.Font = Enum.Font.Gotham
cubeStatus.TextSize = 15
cubeStatus.TextXAlignment = Enum.TextXAlignment.Left
cubeStatus.Parent = cubeWindow

local faceColors = {
	U = Color3.fromRGB(238, 238, 225),
	D = Color3.fromRGB(242, 211, 54),
	F = Color3.fromRGB(36, 155, 83),
	B = Color3.fromRGB(41, 92, 181),
	R = Color3.fromRGB(204, 50, 47),
	L = Color3.fromRGB(238, 120, 35),
}
local facePositions = {
	U = Vector2.new(269, 82),
	L = Vector2.new(137, 214),
	F = Vector2.new(269, 214),
	R = Vector2.new(401, 214),
	B = Vector2.new(533, 214),
	D = Vector2.new(269, 346),
}
local faceCells = {}

for _, faceName in ipairs({ "U", "L", "F", "R", "B", "D" }) do
	local panel = Instance.new("Frame")
	panel.Name = faceName
	panel.Position = UDim2.fromOffset(facePositions[faceName].X, facePositions[faceName].Y)
	panel.Size = UDim2.fromOffset(120, 120)
	panel.BackgroundColor3 = Color3.fromRGB(12, 12, 13)
	panel.Parent = cubeWindow
	addCorner(panel, 4)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(36, 36)
	grid.CellPadding = UDim2.fromOffset(3, 3)
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = panel
		facePanels[faceName] = panel
		faceGrids[faceName] = grid
		faceCells[faceName] = {}
	for index = 1, 9 do
		local cell = Instance.new("Frame")
		cell.Name = "Sticker" .. index
		cell.LayoutOrder = index
		cell.BackgroundColor3 = faceColors[faceName]
		cell.Parent = panel
		addCorner(cell, 3)
		addStroke(cell, Color3.fromRGB(15, 15, 15), 1, 0)
		faceCells[faceName][index] = cell
	end
end

local stickers = {}
local cubeScrambled = false
local cubeMoveCount = 0
local cubeSessionId = nil
local cubeSolved = false

local function addSticker(px, py, pz, nx, ny, nz, colorName)
	table.insert(stickers, {
		p = { px, py, pz },
		n = { nx, ny, nz },
		color = colorName,
	})
end

local function resetCubeState()
	table.clear(stickers)
	for a = -1, 1 do
		for b = -1, 1 do
			addSticker(a, 1, b, 0, 1, 0, "U")
			addSticker(a, -1, b, 0, -1, 0, "D")
			addSticker(a, b, -1, 0, 0, -1, "F")
			addSticker(a, b, 1, 0, 0, 1, "B")
			addSticker(1, b, a, 1, 0, 0, "R")
			addSticker(-1, b, a, -1, 0, 0, "L")
		end
	end
	cubeScrambled = false
	cubeMoveCount = 0
end

local axisIndex = { x = 1, y = 2, z = 3 }
local moves = {
	U = { axis = "y", layer = 1, quarter = 1 },
	D = { axis = "y", layer = -1, quarter = -1 },
	R = { axis = "x", layer = 1, quarter = 1 },
	L = { axis = "x", layer = -1, quarter = -1 },
	F = { axis = "z", layer = -1, quarter = -1 },
	B = { axis = "z", layer = 1, quarter = 1 },
}

local function rotatePositive(vector, axis)
	local x, y, z = vector[1], vector[2], vector[3]
	if axis == "x" then
		return { x, -z, y }
	elseif axis == "y" then
		return { z, y, -x }
	end
	return { -y, x, z }
end

local function rotateVector(vector, axis, quarter)
	local result = vector
	local count = quarter == 1 and 1 or 3
	for _ = 1, count do
		result = rotatePositive(result, axis)
	end
	return result
end

local function applyCubeMove(faceName, inverse)
	local move = moves[faceName]
	if not move then
		return
	end
	local quarter = move.quarter * (inverse and -1 or 1)
	local index = axisIndex[move.axis]
	for _, sticker in ipairs(stickers) do
		if sticker.p[index] == move.layer then
			sticker.p = rotateVector(sticker.p, move.axis, quarter)
			sticker.n = rotateVector(sticker.n, move.axis, quarter)
		end
	end
end

local function faceAndIndex(sticker)
	local p, n = sticker.p, sticker.n
	local face, row, column
	if n[2] == 1 then
		face, row, column = "U", p[3] + 2, p[1] + 2
	elseif n[2] == -1 then
		face, row, column = "D", -p[3] + 2, p[1] + 2
	elseif n[3] == -1 then
		face, row, column = "F", -p[2] + 2, p[1] + 2
	elseif n[3] == 1 then
		face, row, column = "B", -p[2] + 2, -p[1] + 2
	elseif n[1] == 1 then
		face, row, column = "R", -p[2] + 2, p[3] + 2
	else
		face, row, column = "L", -p[2] + 2, -p[3] + 2
	end
	return face, (row - 1) * 3 + column
end

local function renderCube()
	for _, sticker in ipairs(stickers) do
		local face, index = faceAndIndex(sticker)
		faceCells[face][index].BackgroundColor3 = faceColors[sticker.color]
	end
end

local function cubeIsSolved()
	for faceName, cells in pairs(faceCells) do
		local expected = cells[5].BackgroundColor3
		for index = 1, 9 do
			if cells[index].BackgroundColor3 ~= expected then
				return false
			end
		end
	end
	return true
end

local function loadCubeSession(payload)
	resetCubeState()
	cubeSessionId = payload.sessionId
	cubeSolved = false
	for _, move in ipairs(type(payload.scramble) == "table" and payload.scramble or {}) do
		if type(move) == "table" and moves[move.face] then
			applyCubeMove(move.face, move.inverse == true)
		end
	end
	cubeScrambled = true
	cubeMoveCount = 0
	cubeStatus.Text = "Scrambled. Make every face one color."
	cubeStatus.TextColor3 = Color3.fromRGB(231, 207, 125)
	renderCube()
end

local function doPlayerMove(faceName, inverse)
	if not cubeSessionId or not cubeScrambled or cubeSolved then
		return
	end
	requestEvent:FireServer("CubeMove", {
		sessionId = cubeSessionId,
		face = faceName,
		inverse = inverse == true,
	})
end

local function applyConfirmedCubeMove(payload)
	if payload.sessionId ~= cubeSessionId or not moves[payload.face] or cubeSolved then
		return
	end
	applyCubeMove(payload.face, payload.inverse == true)
	cubeMoveCount = math.max(cubeMoveCount + 1, math.floor(tonumber(payload.moveCount) or 0))
	renderCube()
	if cubeIsSolved() then
		cubeStatus.Text = "Solution found. Verifying with Sheldon..."
		cubeStatus.TextColor3 = Color3.fromRGB(231, 207, 125)
	else
		cubeStatus.Text = string.format("Moves: %d  •  Make every face one color.", cubeMoveCount)
		cubeStatus.TextColor3 = Color3.fromRGB(191, 194, 187)
	end
end

local function requestCubeShuffle()
	if not cubeSessionId then
		return
	end
	cubeStatus.Text = "Requesting a new scramble..."
	cubeStatus.TextColor3 = Color3.fromRGB(231, 207, 125)
	requestEvent:FireServer("CubeReshuffle", {
		sessionId = cubeSessionId,
	})
end

local buttonStartX = 42
local cubeButtons = {}
for index, faceName in ipairs({ "U", "D", "L", "R", "F", "B" }) do
	local x = buttonStartX + (index - 1) * 121
	local clockwise = makeButton(cubeWindow, faceName, faceName, UDim2.fromOffset(52, 48), UDim2.fromOffset(x, 490))
	local inverse = makeButton(cubeWindow, faceName .. "Prime", faceName .. "'", UDim2.fromOffset(52, 48), UDim2.fromOffset(x + 57, 490))
	table.insert(cubeButtons, clockwise)
	table.insert(cubeButtons, inverse)
	cubeMoveButtons[faceName] = {
		clockwise = clockwise,
		inverse = inverse,
	}
	clockwise.Activated:Connect(function()
		doPlayerMove(faceName, false)
	end)
	inverse.Activated:Connect(function()
		doPlayerMove(faceName, true)
	end)
end

reshuffle = makeButton(cubeWindow, "Shuffle", "NEW SCRAMBLE", UDim2.fromOffset(190, 46), UDim2.fromOffset(170, 555))
reshuffle.BackgroundColor3 = Color3.fromRGB(72, 105, 130)
reshuffle.Activated:Connect(requestCubeShuffle)
table.insert(cubeButtons, reshuffle)

giveUpThrowButton = makeButton(
	cubeWindow,
	"GiveUpThrow",
	"GIVE UP",
	UDim2.fromOffset(250, 46),
	UDim2.fromOffset(390, 555)
)
giveUpThrowButton.BackgroundColor3 = Color3.fromRGB(151, 61, 43)
table.insert(cubeButtons, giveUpThrowButton)
cubeLayoutReady = true
updateResponsiveLayout()

local function requestCubeGiveUpThrow()
	if not cubeSessionId then
		return
	end
	giveUpThrowButton.Active = false
	cubeStatus.Text = "Giving up..."
	cubeStatus.TextColor3 = Color3.fromRGB(231, 155, 125)
	requestEvent:FireServer("CubeGiveUpThrow", {
		sessionId = cubeSessionId,
	})
	task.delay(0.75, function()
		if giveUpThrowButton.Parent then
			giveUpThrowButton.Active = true
		end
	end)
end

giveUpThrowButton.Activated:Connect(requestCubeGiveUpThrow)

local function closeCube(notifyServer)
	local sessionId = cubeSessionId
	cubeWindow.Visible = false
	cubeSessionId = nil
	cubeSolved = false
	cubeScrambled = false
	giveUpThrowButton.Active = true
	local selectedObject = GuiService.SelectedObject
	if selectedObject and selectedObject:IsDescendantOf(cubeWindow) then
		GuiService.SelectedObject = nil
	end
	if notifyServer ~= false and sessionId then
		requestEvent:FireServer("CubeClose", {
			sessionId = sessionId,
		})
	end
end
cubeClose.Activated:Connect(closeCube)
resetCubeState()
renderCube()

-- Input and server messages --------------------------------------------------

local function externalModalVisible()
	local familyGui = playerGui:FindFirstChild("CooperGameHUD")
	local familyTerminal = familyGui and familyGui:FindFirstChild("CooperComputer", true)
	if familyTerminal and familyTerminal:IsA("GuiObject") and familyTerminal.Visible then
		return true
	end
	local dialogueGui = playerGui:FindFirstChild("CooperFamilyDialogueUI")
	if dialogueGui and dialogueGui:IsA("ScreenGui") and dialogueGui.Enabled then
		return true
	end
	local bunkerGui = playerGui:FindFirstChild("CooperBunkerNoticeGui")
	local bunkerShade = bunkerGui and bunkerGui:FindFirstChild("ResearchTerminalShade", true)
	return bunkerShade ~= nil and bunkerShade:IsA("GuiObject") and bunkerShade.Visible
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if terminal.Visible then
			closeTerminal()
		elseif cubeWindow.Visible then
			closeCube()
		elseif input.KeyCode == Enum.KeyCode.ButtonB
			and not gameProcessed
			and not externalModalVisible()
			and isHolding
		then
			requestEvent:FireServer("HeldAction", "Drop")
		end
		return
	end
	if gameProcessed then
		return
	end
	if externalModalVisible() then
		return
	end
	if cubeWindow.Visible and input.KeyCode == Enum.KeyCode.Q then
		requestCubeGiveUpThrow()
	elseif isHolding and (input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.ButtonX) then
		requestEvent:FireServer("HeldAction", "Throw")
	elseif isHolding and input.KeyCode == Enum.KeyCode.G then
		requestEvent:FireServer("HeldAction", "Drop")
	elseif isHolding
		and holdingCube
		and (input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonY)
	then
		requestEvent:FireServer("HeldAction", "Solve")
	end
end)

clientEvent.OnClientEvent:Connect(function(action, payload)
	payload = type(payload) == "table" and payload or {}
	if action == "Toast" then
		showToast(payload.text or "", payload.duration)
	elseif action == "TimedAction" then
		showProgress(payload.text or "Working...", tonumber(payload.duration) or 2)
	elseif action == "TimedActionEnd" then
		endProgress()
	elseif action == "HeldItem" then
		local wasHoldingCube = holdingCube
		isHolding = payload.held == true
		holdingCube = isHolding and payload.isCube == true
		heldPanel.Visible = isHolding
		if isHolding then
			heldTitle.Text = "Holding: " .. tostring(payload.name or "item")
			solveHeldButton.Visible = holdingCube
			dropButton.Visible = true
			heldPanel.Size = UDim2.fromOffset(330, holdingCube and 172 or 118)
		else
			holdingCube = false
			solveHeldButton.Visible = false
			dropButton.Visible = true
			heldPanel.Size = UDim2.fromOffset(330, 118)
			if wasHoldingCube and cubeWindow.Visible then
				closeCube()
			end
		end
		updateResponsiveLayout()
	elseif action == "TerminalOpen" then
		closeCube(false)
		terminal.Visible = true
		clearTerminal()
		addTerminalLine("COOPER-DOS 3.11", Color3.fromRGB(150, 255, 174))
		addTerminalLine("MEDFORD SCIENCE LAB TERMINAL // 640K RAM OK")
		addTerminalLine("Type HELP for commands.")
		addTerminalLine("")
		-- Opening a terminal must not immediately cover a phone with the
		-- software keyboard. Touch players can tap the field when ready.
		if not touchOnly then
			task.defer(function()
				terminalInput:CaptureFocus()
			end)
		end
	elseif action == "TerminalLine" and terminal.Visible then
		addTerminalLine(dosPrompt .. " " .. tostring(payload.command or ""), Color3.fromRGB(184, 255, 199))
		addTerminalLine(tostring(payload.text or ""))
	elseif action == "TerminalClear" and terminal.Visible then
		clearTerminal()
	elseif action == "TerminalClose" then
		closeTerminal(false)
	elseif action == "CubeOpen" then
		if type(payload.sessionId) ~= "number" then
			closeCube(false)
			return
		end
		closeTerminal(false)
		loadCubeSession(payload)
		cubeWindow.Visible = true
		if UserInputService.GamepadEnabled and cubeButtons[1] then
			GuiService.SelectedObject = cubeButtons[1]
		end
	elseif action == "CubeMove" then
		applyConfirmedCubeMove(payload)
	elseif action == "CubeSolved" and payload.sessionId == cubeSessionId then
		cubeSolved = true
		cubeScrambled = false
		cubeMoveCount = math.floor(tonumber(payload.moveCount) or cubeMoveCount)
		cubeStatus.Text = string.format("SOLVED IN %d MOVES! Sheldon approves.", cubeMoveCount)
		cubeStatus.TextColor3 = Color3.fromRGB(106, 235, 139)
	elseif action == "CubeClose" then
		if not payload.sessionId or payload.sessionId == cubeSessionId then
			closeCube(false)
		end
	end
end)

print("[CooperInteractions] Client interaction UI ready")
