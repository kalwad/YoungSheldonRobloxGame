--!strict
-- Shift/gamepad sprint input, 64px mobile toggle, and transient stamina HUD.
-- Install as StarterPlayer.StarterPlayerScripts.CooperSprint.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local cooperGame = ReplicatedStorage:WaitForChild("CooperGame", 15)
assert(cooperGame and cooperGame:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
local configModule = cooperGame:WaitForChild("Config", 15)
assert(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config is missing")
local Config = require(configModule)
local movementConfig = Config.Movement
assert(type(movementConfig) == "table", "Config.Movement is missing")

local WALK_SPEED = 16
local SPRINT_SPEED = 22
local MAX_STAMINA = 6
assert(movementConfig.WalkSpeed == WALK_SPEED, "Config.Movement.WalkSpeed must remain 16")
assert(movementConfig.SprintSpeed == SPRINT_SPEED, "Config.Movement.SprintSpeed must remain 22")
assert(movementConfig.SprintStaminaSeconds == MAX_STAMINA, "Config.Movement.SprintStaminaSeconds must remain 6")

local REMOTES_NAME = "CooperMovementRemotes"
local INTENT_EVENT_NAME = "SprintIntent"
local ACTION_NAME = "CooperSprintIntent"
local TOUCH_BUTTON_SIZE = 64
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 40
local PRESENTATION_INTERVAL = 0.08

local remotes = ReplicatedStorage:WaitForChild(REMOTES_NAME, 20)
if not remotes or not remotes:IsA("Folder") then
	warn("[CooperSprint] CooperMovementRemotes was not installed")
	return
end
local sprintIntentValue = remotes:WaitForChild(INTENT_EVENT_NAME, 10)
if not sprintIntentValue or not sprintIntentValue:IsA("RemoteEvent") then
	warn("[CooperSprint] SprintIntent RemoteEvent was not installed")
	return
end
local sprintIntent = sprintIntentValue :: RemoteEvent

local touchDevice = UserInputService.TouchEnabled
local character: Model? = nil
local humanoid: Humanoid? = nil
local seatConnection: RBXScriptConnection? = nil
local diedConnection: RBXScriptConnection? = nil
local desiredIntent = false
local lastSentIntent: boolean? = nil
local lastPresentationAt = 0
local fillTween: Tween? = nil
local touchLayoutRetries = 0
local connections: { RBXScriptConnection } = {}
local destroyed = false

local oldGui = playerGui:FindFirstChild("CooperSprintHUD")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperSprintHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ClipToDeviceSafeArea = true
gui.DisplayOrder = 26
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local staminaCard = Instance.new("Frame")
staminaCard.Name = "StaminaCard"
staminaCard.AnchorPoint = Vector2.new(0.5, 1)
staminaCard.Position = UDim2.new(0.5, 0, 1, -18)
staminaCard.Size = UDim2.fromOffset(250, 54)
staminaCard.BackgroundColor3 = Color3.fromRGB(24, 29, 27)
staminaCard.BackgroundTransparency = 0.08
staminaCard.BorderSizePixel = 0
staminaCard.Visible = false
staminaCard.ZIndex = 3
staminaCard.Parent = gui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent = staminaCard
local cardStroke = Instance.new("UIStroke")
cardStroke.Name = "Outline"
cardStroke.Color = Color3.fromRGB(114, 231, 154)
cardStroke.Thickness = 2
cardStroke.Transparency = 0.12
cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
cardStroke.Parent = staminaCard

local staminaLabel = Instance.new("TextLabel")
staminaLabel.Name = "Status"
staminaLabel.Position = UDim2.fromOffset(12, 5)
staminaLabel.Size = UDim2.new(1, -24, 0, 21)
staminaLabel.BackgroundTransparency = 1
staminaLabel.Font = Enum.Font.GothamBold
staminaLabel.Text = "SPRINT"
staminaLabel.TextColor3 = Color3.fromRGB(239, 249, 235)
staminaLabel.TextSize = 14
staminaLabel.TextXAlignment = Enum.TextXAlignment.Left
staminaLabel.ZIndex = 4
staminaLabel.Parent = staminaCard

local track = Instance.new("Frame")
track.Name = "Track"
track.Position = UDim2.fromOffset(12, 31)
track.Size = UDim2.new(1, -24, 0, 12)
track.BackgroundColor3 = Color3.fromRGB(62, 69, 64)
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.ZIndex = 4
track.Parent = staminaCard
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.fromRGB(92, 225, 139)
fill.BorderSizePixel = 0
fill.ZIndex = 5
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function futureSessionAttribute(attributeName: string): boolean
	local value = player:GetAttribute(attributeName)
	return type(value) == "number" and value == value and value > serverNow()
end

local function visibleGuiObject(parent: Instance?, name: string): boolean
	local object = parent and parent:FindFirstChild(name, true)
	return object ~= nil and object:IsA("GuiObject") and object.Visible
end

local function externalModalVisible(): boolean
	if futureSessionAttribute("CooperComputerSessionUntil")
		or futureSessionAttribute("CooperBunkerComputerSessionUntil")
	then
		return true
	end

	local familyHud = playerGui:FindFirstChild("CooperGameHUD")
	if visibleGuiObject(familyHud, "CooperComputer") then
		return true
	end
	-- The first-play tutorial scrim predates named modal roots. It is the only
	-- full-screen, high-Z direct frame besides the explicitly named terminal.
	if familyHud and familyHud:IsA("ScreenGui") and familyHud.Enabled then
		for _, child in ipairs(familyHud:GetChildren()) do
			if child:IsA("GuiObject")
				and child.Name ~= "ScaledRoot"
				and child.Name ~= "CooperComputer"
				and child.Visible
				and child.ZIndex >= 75
				and child.Size.X.Scale >= 0.95
				and child.Size.Y.Scale >= 0.95
			then
				return true
			end
		end
	end

	local interactionsGui = playerGui:FindFirstChild("CooperInteractionsGui")
	if visibleGuiObject(interactionsGui, "Terminal") or visibleGuiObject(interactionsGui, "PuzzleCube") then
		return true
	end
	local bunkerGui = playerGui:FindFirstChild("CooperBunkerNoticeGui")
	if visibleGuiObject(bunkerGui, "ResearchTerminalShade") then
		return true
	end
	local dialogueGui = playerGui:FindFirstChild("CooperFamilyDialogueUI")
	return dialogueGui ~= nil and dialogueGui:IsA("ScreenGui") and dialogueGui.Enabled
end

local function isSeated(): boolean
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

local function canAttemptSprint(): boolean
	return player:GetAttribute("CooperMovementReady") == true
		and player:GetAttribute("CooperMovementLocked") ~= true
		and player:GetAttribute("CooperSprintExhausted") ~= true
		and humanoid ~= nil
		and humanoid.Health > 0
		and not isSeated()
		and UserInputService:GetFocusedTextBox() == nil
		and not externalModalVisible()
end

local function sendIntent(intent: boolean, force: boolean?)
	if not force and lastSentIntent == intent then
		return
	end
	lastSentIntent = intent
	sprintIntent:FireServer(intent)
end

local function setDesiredIntent(intent: boolean)
	if intent and not canAttemptSprint() then
		intent = false
	end
	if desiredIntent == intent and lastSentIntent == intent then
		return
	end
	desiredIntent = intent
	sendIntent(intent)
end

local function sprintAction(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	local isTouchButton = inputObject.UserInputType == Enum.UserInputType.Touch
	if isTouchButton then
		if inputState == Enum.UserInputState.Begin then
			setDesiredIntent(not desiredIntent)
		end
		return Enum.ContextActionResult.Sink
	end
	if UserInputService:GetFocusedTextBox() ~= nil or externalModalVisible() then
		-- Shift is ordinary typing/navigation input inside both terminals and
		-- dialogue. Release sprint without stealing the key from the owning UI.
		setDesiredIntent(false)
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		setDesiredIntent(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setDesiredIntent(false)
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	ACTION_NAME,
	sprintAction,
	touchDevice,
	ACTION_PRIORITY,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.ButtonL3
)
ContextActionService:SetTitle(ACTION_NAME, "SPRINT")
pcall(function()
	ContextActionService:SetImage(ACTION_NAME, "")
end)

local function touchButton(): ImageButton?
	local button = ContextActionService:GetButton(ACTION_NAME)
	return if button and button:IsA("ImageButton") then button else nil
end

local function updateTouchButtonLayout()
	if destroyed or not touchDevice then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local portrait = viewport.Y > viewport.X
	-- The native jump button owns the lower-right corner. Sprint sits one large
	-- target to its left and slightly above, with edge padding for phone notches.
	local position = if portrait
		then UDim2.new(1, -196, 1, -164)
		else UDim2.new(1, -204, 1, -104)
	ContextActionService:SetPosition(ACTION_NAME, position)

	local button = touchButton()
	if not button then
		if touchLayoutRetries < 20 then
			touchLayoutRetries += 1
			task.delay(0.1, updateTouchButtonLayout)
		end
		return
	end
	touchLayoutRetries = 0
	button.Size = UDim2.fromOffset(TOUCH_BUTTON_SIZE, TOUCH_BUTTON_SIZE)
	button.SelectionOrder = 5
	button.ZIndex = 14
	button.ImageTransparency = 0.04
	local outline = button:FindFirstChild("CooperSprintOutline")
	if not outline then
		outline = Instance.new("UIStroke")
		outline.Name = "CooperSprintOutline"
		outline.Thickness = 2
		outline.Transparency = 0.08
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Parent = button
	end
	local title = button:FindFirstChild("ActionTitle")
	if title and title:IsA("TextLabel") then
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = Color3.fromRGB(250, 248, 232)
		title.TextStrokeColor3 = Color3.fromRGB(17, 24, 20)
		title.TextStrokeTransparency = 0.25
		title.TextSize = 11
		title.TextWrapped = true
		title.ZIndex = 15
	end
end

local function updateResponsiveHud()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local shortLandscape = viewport.X > viewport.Y and viewport.Y < 520
	if shortLandscape then
		staminaCard.Size = UDim2.fromOffset(204, 46)
		staminaCard.Position = UDim2.new(0.5, 0, 1, -10)
		staminaLabel.Size = UDim2.new(1, -20, 0, 18)
		staminaLabel.Position = UDim2.fromOffset(10, 3)
		staminaLabel.TextSize = 12
		track.Position = UDim2.fromOffset(10, 27)
		track.Size = UDim2.new(1, -20, 0, 10)
	else
		staminaCard.Size = UDim2.fromOffset(250, 54)
		staminaCard.Position = UDim2.new(0.5, 0, 1, -18)
		staminaLabel.Size = UDim2.new(1, -24, 0, 21)
		staminaLabel.Position = UDim2.fromOffset(12, 5)
		staminaLabel.TextSize = 14
		track.Position = UDim2.fromOffset(12, 31)
		track.Size = UDim2.new(1, -24, 0, 12)
	end
	updateTouchButtonLayout()
end

local function updateTouchButtonStyle(available: boolean, exhausted: boolean)
	local button = touchButton()
	if not button then
		return
	end
	button.Visible = touchDevice and available
	local color = if exhausted
		then Color3.fromRGB(135, 54, 46)
		elseif desiredIntent
			then Color3.fromRGB(38, 139, 82)
			else Color3.fromRGB(40, 50, 45)
	button.ImageColor3 = color
	local outline = button:FindFirstChild("CooperSprintOutline")
	if outline and outline:IsA("UIStroke") then
		outline.Color = if desiredIntent then Color3.fromRGB(132, 255, 173) else Color3.fromRGB(213, 229, 215)
	end
	local title = button:FindFirstChild("ActionTitle")
	if title and title:IsA("TextLabel") then
		title.Text = if desiredIntent then "SPRINT\nON" else "SPRINT"
	end
end

local function updatePresentation()
	local staminaValue = tonumber(player:GetAttribute("CooperStamina")) or MAX_STAMINA
	local staminaMax = math.max(0.01, tonumber(player:GetAttribute("CooperStaminaMax")) or MAX_STAMINA)
	local stamina = math.clamp(staminaValue, 0, staminaMax)
	local ratio = math.clamp(stamina / staminaMax, 0, 1)
	local sprinting = player:GetAttribute("CooperSprinting") == true
	local exhausted = player:GetAttribute("CooperSprintExhausted") == true
	local blockedByWorld = player:GetAttribute("CooperMovementReady") ~= true
		or player:GetAttribute("CooperMovementLocked") == true
		or humanoid == nil
		or humanoid.Health <= 0
		or isSeated()
		or externalModalVisible()
	local available = not blockedByWorld

	updateTouchButtonStyle(available, exhausted)
	staminaCard.Visible = not blockedByWorld and (sprinting or stamina < staminaMax - 0.01)
	if not staminaCard.Visible then
		return
	end

	local accent = if ratio <= 0.25
		then Color3.fromRGB(239, 91, 75)
		elseif ratio <= 0.55
			then Color3.fromRGB(242, 189, 67)
			else Color3.fromRGB(92, 225, 139)
	cardStroke.Color = accent
	if fillTween then
		fillTween:Cancel()
	end
	fillTween = TweenService:Create(fill, TweenInfo.new(0.09, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = accent,
	})
	fillTween:Play()
	local secondsText = string.format("%.1fs / %.0fs", stamina, staminaMax)
	if exhausted then
		staminaLabel.Text = "SPRINT EXHAUSTED  •  " .. secondsText
	elseif sprinting then
		staminaLabel.Text = "SPRINTING  •  " .. secondsText
	else
		staminaLabel.Text = "SPRINT RECOVERING  •  " .. secondsText
	end
end

local function clearCharacterConnections()
	if seatConnection then
		seatConnection:Disconnect()
		seatConnection = nil
	end
	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end
end

local function attachCharacter(newCharacter: Model)
	clearCharacterConnections()
	character = newCharacter
	humanoid = nil
	desiredIntent = false
	lastSentIntent = nil
	sendIntent(false, true)
	task.spawn(function()
		local humanoidValue = newCharacter:WaitForChild("Humanoid", 10)
		if character ~= newCharacter or not humanoidValue or not humanoidValue:IsA("Humanoid") then
			return
		end
		humanoid = humanoidValue :: Humanoid
		seatConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			if humanoid and humanoid.SeatPart ~= nil then
				setDesiredIntent(false)
			end
			updatePresentation()
		end)
		diedConnection = humanoid.Died:Connect(function()
			setDesiredIntent(false)
			updatePresentation()
		end)
		updatePresentation()
	end)
end

table.insert(connections, player.CharacterAdded:Connect(attachCharacter))
table.insert(connections, player.CharacterRemoving:Connect(function(removingCharacter)
	if character == removingCharacter then
		setDesiredIntent(false)
		clearCharacterConnections()
		character = nil
		humanoid = nil
		updatePresentation()
	end
end))
if player.Character then
	attachCharacter(player.Character)
end

table.insert(connections, sprintIntent.OnClientEvent:Connect(function(acceptedIntent: any)
	if type(acceptedIntent) ~= "boolean" then
		return
	end
	lastSentIntent = acceptedIntent
	if not acceptedIntent then
		desiredIntent = false
	end
	updatePresentation()
end))

for _, attributeName in ipairs({
	"CooperMovementReady",
	"CooperStamina",
	"CooperStaminaMax",
	"CooperSprinting",
	"CooperSprintExhausted",
	"CooperSprintIntent",
	"CooperMovementLocked",
	"CooperComputerSessionUntil",
	"CooperBunkerComputerSessionUntil",
}) do
	table.insert(connections, player:GetAttributeChangedSignal(attributeName):Connect(function()
		if (attributeName == "CooperMovementLocked"
			or attributeName == "CooperComputerSessionUntil"
			or attributeName == "CooperBunkerComputerSessionUntil")
			and desiredIntent
			and not canAttemptSprint()
		then
			setDesiredIntent(false)
		end
		if attributeName == "CooperSprintExhausted" and player:GetAttribute(attributeName) == true then
			setDesiredIntent(false)
		end
		if attributeName == "CooperSprintIntent"
			and player:GetAttribute(attributeName) == false
			and desiredIntent
		then
			desiredIntent = false
			lastSentIntent = false
		end
		updatePresentation()
	end))
end

local viewportConnection: RBXScriptConnection? = nil
local function bindViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveHud)
	end
	updateResponsiveHud()
end
table.insert(connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport))
bindViewport()

-- Modal roots are owned by separate UI scripts, so perform one inexpensive
-- presentation/gating pass at 12.5 Hz. This catches a newly opened dialogue or
-- puzzle even when its legacy UI does not expose a player attribute.
table.insert(connections, RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastPresentationAt < PRESENTATION_INTERVAL then
		return
	end
	lastPresentationAt = now
	if desiredIntent and not canAttemptSprint() then
		setDesiredIntent(false)
	end
	updatePresentation()
end))

script.Destroying:Connect(function()
	destroyed = true
	desiredIntent = false
	pcall(function()
		sprintIntent:FireServer(false)
	end)
	ContextActionService:UnbindAction(ACTION_NAME)
	clearCharacterConnections()
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	if fillTween then
		fillTween:Cancel()
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if gui then
		gui:Destroy()
	end
end)

task.defer(updateTouchButtonLayout)
updatePresentation()
print(string.format(
	"[CooperSprint] Shift/mobile sprint ready (walk %d, sprint %d, stamina %ds, touch target %dpx)",
	WALK_SPEED,
	SPRINT_SPEED,
	MAX_STAMINA,
	TOUCH_BUTTON_SIZE
))
