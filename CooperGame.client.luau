--!nonstrict
-- Responsive campaign HUD for the Cooper house game.
-- Install as StarterPlayer.StarterPlayerScripts.CooperGame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameRoot = ReplicatedStorage:WaitForChild("CooperGame", 20)
if not gameRoot then
	warn("[CooperGame] ReplicatedStorage.CooperGame was not installed")
	return
end

local stateFolder = gameRoot:WaitForChild("State", 10)
local remotes = gameRoot:WaitForChild("Remotes", 10)
if not stateFolder or not remotes then
	warn("[CooperGame] State or Remotes folder is missing")
	return
end

local snapshotEvent = remotes:WaitForChild("Snapshot", 10)
local feedbackEvent = remotes:WaitForChild("Feedback", 10)
local requestEvent = remotes:WaitForChild("Request", 10)
if not snapshotEvent or not feedbackEvent or not requestEvent then
	warn("[CooperGame] Required remotes are missing")
	return
end

local previous = playerGui:FindFirstChild("CooperGameHUD")
if previous then
	previous:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperGameHUD"
gui.DisplayOrder = 25
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local COLORS = {
	cream = Color3.fromRGB(249, 239, 207),
	brown = Color3.fromRGB(59, 43, 34),
	panel = Color3.fromRGB(34, 38, 43),
	panelLight = Color3.fromRGB(54, 61, 66),
	green = Color3.fromRGB(89, 199, 118),
	yellow = Color3.fromRGB(244, 195, 71),
	orange = Color3.fromRGB(235, 118, 61),
	red = Color3.fromRGB(218, 55, 57),
	blue = Color3.fromRGB(79, 151, 218),
	purple = Color3.fromRGB(153, 102, 201),
	white = Color3.fromRGB(248, 248, 242),
	muted = Color3.fromRGB(190, 194, 190),
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 8)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0
	item.Parent = parent
	return item
end

local function label(parent, name, text, size, position, font, textSize, color, alignment)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Size = size
	item.Position = position or UDim2.fromScale(0, 0)
	item.Font = font or Enum.Font.GothamMedium
	item.Text = text or ""
	item.TextColor3 = color or COLORS.white
	item.TextSize = textSize or 16
	item.TextWrapped = true
	item.TextXAlignment = alignment or Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local hudRoot = Instance.new("Frame")
hudRoot.Name = "ScaledHUDRoot"
hudRoot.AnchorPoint = Vector2.new(0.5, 0)
hudRoot.Position = UDim2.fromScale(0.5, 0)
hudRoot.Size = UDim2.fromOffset(1280, 720)
hudRoot.BackgroundTransparency = 1
hudRoot.BorderSizePixel = 0
hudRoot.Parent = gui

local rootScale = Instance.new("UIScale")
rootScale.Name = "ResponsiveScale"
rootScale.Parent = hudRoot

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.fromOffset(860, 86)
topBar.BackgroundColor3 = COLORS.panel
topBar.BackgroundTransparency = 0.05
topBar.Parent = hudRoot
corner(topBar, 12)
stroke(topBar, COLORS.cream, 2, 0.2)

local stabilityTitle = label(
	topBar,
	"StabilityTitle",
	"HOUSE STABILITY",
	UDim2.fromOffset(245, 22),
	UDim2.fromOffset(18, 10),
	Enum.Font.GothamBold,
	14,
	COLORS.cream
)
local stabilityValue = label(
	topBar,
	"StabilityValue",
	"100",
	UDim2.fromOffset(62, 32),
	UDim2.fromOffset(190, 2),
	Enum.Font.GothamBlack,
	26,
	COLORS.green,
	Enum.TextXAlignment.Right
)

local stabilityTrack = Instance.new("Frame")
stabilityTrack.Name = "StabilityTrack"
stabilityTrack.Position = UDim2.fromOffset(18, 42)
stabilityTrack.Size = UDim2.fromOffset(234, 20)
stabilityTrack.BackgroundColor3 = Color3.fromRGB(21, 23, 26)
stabilityTrack.Parent = topBar
corner(stabilityTrack, 8)
local stabilityFill = Instance.new("Frame")
stabilityFill.Name = "Fill"
stabilityFill.Size = UDim2.fromScale(1, 1)
stabilityFill.BackgroundColor3 = COLORS.green
stabilityFill.Parent = stabilityTrack
corner(stabilityFill, 8)

local divider1 = Instance.new("Frame")
divider1.Position = UDim2.fromOffset(273, 12)
divider1.Size = UDim2.fromOffset(2, 60)
divider1.BackgroundColor3 = COLORS.cream
divider1.BackgroundTransparency = 0.68
divider1.Parent = topBar

local machineTitle = label(
	topBar,
	"MachineTitle",
	"TIME MACHINE • 0%",
	UDim2.fromOffset(330, 22),
	UDim2.fromOffset(294, 10),
	Enum.Font.GothamBold,
	14,
	COLORS.cream
)
local machineStage = label(
	topBar,
	"MachineStage",
	"Blueprint Pending",
	UDim2.fromOffset(330, 24),
	UDim2.fromOffset(294, 31),
	Enum.Font.GothamMedium,
	15,
	COLORS.blue
)
local machineTrack = Instance.new("Frame")
machineTrack.Position = UDim2.fromOffset(294, 58)
machineTrack.Size = UDim2.fromOffset(330, 10)
machineTrack.BackgroundColor3 = Color3.fromRGB(21, 23, 26)
machineTrack.Parent = topBar
corner(machineTrack, 5)
local machineFill = Instance.new("Frame")
machineFill.Name = "Fill"
machineFill.Size = UDim2.fromScale(0, 1)
machineFill.BackgroundColor3 = COLORS.blue
machineFill.Parent = machineTrack
corner(machineFill, 5)

local divider2 = divider1:Clone()
divider2.Position = UDim2.fromOffset(645, 12)
divider2.Parent = topBar

local cashLabel = label(
	topBar,
	"Cash",
	"$0",
	UDim2.fromOffset(180, 26),
	UDim2.fromOffset(665, 10),
	Enum.Font.GothamBlack,
	20,
	COLORS.yellow,
	Enum.TextXAlignment.Right
)
local chrononLabel = label(
	topBar,
	"Chronons",
	"0 CHRONONS",
	UDim2.fromOffset(180, 22),
	UDim2.fromOffset(665, 39),
	Enum.Font.GothamBold,
	14,
	COLORS.purple,
	Enum.TextXAlignment.Right
)
local modeChip = label(
	topBar,
	"Mode",
	"NORMAL",
	UDim2.fromOffset(118, 20),
	UDim2.fromOffset(727, 62),
	Enum.Font.GothamBlack,
	12,
	COLORS.green,
	Enum.TextXAlignment.Right
)

local tasksPanel = Instance.new("Frame")
tasksPanel.Name = "Tasks"
tasksPanel.Position = UDim2.fromOffset(18, 116)
tasksPanel.Size = UDim2.fromOffset(380, 510)
tasksPanel.BackgroundTransparency = 1
tasksPanel.Parent = hudRoot

local taskHeader = label(
	tasksPanel,
	"Header",
	"COOPER REQUESTS",
	UDim2.new(1, 0, 0, 32),
	UDim2.fromOffset(0, 0),
	Enum.Font.GothamBlack,
	22,
	COLORS.cream
)
local chapterLabel = label(
	tasksPanel,
	"Chapter",
	"CHAPTER 0 • THE BLUEPRINT",
	UDim2.new(1, 0, 0, 22),
	UDim2.fromOffset(0, 31),
	Enum.Font.GothamBold,
	12,
	COLORS.muted
)

local taskList = Instance.new("Frame")
taskList.Name = "TaskList"
taskList.Position = UDim2.fromOffset(0, 62)
taskList.Size = UDim2.new(1, 0, 1, -62)
taskList.BackgroundTransparency = 1
taskList.Parent = tasksPanel
local taskLayout = Instance.new("UIListLayout")
taskLayout.Padding = UDim.new(0, 10)
taskLayout.SortOrder = Enum.SortOrder.LayoutOrder
taskLayout.Parent = taskList

local emptyLabel = label(
	taskList,
	"Empty",
	"Listen up—the family will need something any second.",
	UDim2.new(1, 0, 0, 68),
	UDim2.fromOffset(0, 0),
	Enum.Font.GothamMedium,
	15,
	COLORS.muted
)
emptyLabel.TextYAlignment = Enum.TextYAlignment.Top

local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -24)
toast.Size = UDim2.fromOffset(540, 72)
toast.BackgroundColor3 = COLORS.panel
toast.BackgroundTransparency = 0.02
toast.Visible = false
toast.Parent = hudRoot
corner(toast, 12)
local toastStroke = stroke(toast, COLORS.cream, 2, 0.15)
local toastTitle = label(
	toast,
	"Title",
	"",
	UDim2.new(1, -30, 0, 30),
	UDim2.fromOffset(15, 8),
	Enum.Font.GothamBlack,
	18,
	COLORS.cream,
	Enum.TextXAlignment.Center
)
local toastDetail = label(
	toast,
	"Detail",
	"",
	UDim2.new(1, -30, 0, 23),
	UDim2.fromOffset(15, 39),
	Enum.Font.GothamMedium,
	14,
	COLORS.white,
	Enum.TextXAlignment.Center
)

local guidedBar = Instance.new("Frame")
guidedBar.Name = "GuidedStartBar"
guidedBar.AnchorPoint = Vector2.new(0.5, 0)
guidedBar.Position = UDim2.new(0.5, 0, 0, 104)
guidedBar.Size = UDim2.fromOffset(480, 34)
guidedBar.BackgroundColor3 = COLORS.panel
guidedBar.BackgroundTransparency = 0.05
guidedBar.Visible = false
guidedBar.Parent = hudRoot
corner(guidedBar, 9)
stroke(guidedBar, COLORS.green, 2, 0.1)
local guidedText = label(
	guidedBar,
	"GuidedText",
	"GUIDED START • 0/3 CHORES • NO FAILURE PENALTY • FOLLOW THE COLORED ARROW",
	UDim2.new(1, -20, 1, 0),
	UDim2.fromOffset(10, 0),
	Enum.Font.GothamBold,
	12,
	COLORS.green,
	Enum.TextXAlignment.Center
)

local tutorialScrim = Instance.new("Frame")
tutorialScrim.Name = "TutorialScrim"
tutorialScrim.Size = UDim2.fromScale(1, 1)
tutorialScrim.BackgroundColor3 = Color3.new(0, 0, 0)
tutorialScrim.BackgroundTransparency = 0.42
tutorialScrim.BorderSizePixel = 0
tutorialScrim.Visible = false
tutorialScrim.ZIndex = 80
tutorialScrim.Parent = gui

local tutorialCard = Instance.new("Frame")
tutorialCard.Name = "TutorialCard"
tutorialCard.AnchorPoint = Vector2.new(0.5, 0.5)
tutorialCard.Position = UDim2.fromScale(0.5, 0.5)
tutorialCard.Size = UDim2.fromOffset(620, 285)
tutorialCard.BackgroundColor3 = COLORS.panel
tutorialCard.ZIndex = 81
tutorialCard.Parent = tutorialScrim
corner(tutorialCard, 16)
local tutorialStroke = stroke(tutorialCard, COLORS.green, 3, 0)

local tutorialTitle = label(
	tutorialCard,
	"TutorialTitle",
	"WELCOME TO THE COOPER HOUSE",
	UDim2.new(1, -48, 0, 52),
	UDim2.fromOffset(24, 22),
	Enum.Font.GothamBlack,
	25,
	COLORS.green,
	Enum.TextXAlignment.Center
)
tutorialTitle.ZIndex = 82
local tutorialBody = label(
	tutorialCard,
	"TutorialBody",
	"",
	UDim2.new(1, -64, 0, 128),
	UDim2.fromOffset(32, 78),
	Enum.Font.GothamMedium,
	17,
	COLORS.cream,
	Enum.TextXAlignment.Center
)
tutorialBody.TextYAlignment = Enum.TextYAlignment.Top
tutorialBody.ZIndex = 82
local tutorialContinue = Instance.new("TextButton")
tutorialContinue.Name = "Continue"
tutorialContinue.AnchorPoint = Vector2.new(0.5, 1)
tutorialContinue.Position = UDim2.new(0.5, 0, 1, -20)
tutorialContinue.Size = UDim2.fromOffset(210, 48)
tutorialContinue.BackgroundColor3 = COLORS.green
tutorialContinue.Text = "LET'S GO"
tutorialContinue.TextColor3 = COLORS.panel
tutorialContinue.Font = Enum.Font.GothamBlack
tutorialContinue.TextSize = 17
tutorialContinue.ZIndex = 82
tutorialContinue.Parent = tutorialCard
corner(tutorialContinue, 10)

local initialTutorialShown = false
local function showTutorialCard(titleText, bodyText, buttonText, accentColor)
	local color = accentColor or COLORS.green
	tutorialTitle.Text = tostring(titleText or "COOPER HOUSE")
	tutorialBody.Text = tostring(bodyText or "")
	tutorialContinue.Text = tostring(buttonText or "GOT IT")
	tutorialTitle.TextColor3 = color
	tutorialContinue.BackgroundColor3 = color
	tutorialStroke.Color = color
	tutorialScrim.Visible = true
end
tutorialContinue.Activated:Connect(function()
	tutorialScrim.Visible = false
end)

local panicShade = Instance.new("Frame")
panicShade.Name = "PanicShade"
panicShade.Size = UDim2.fromScale(1, 1)
panicShade.BackgroundColor3 = Color3.fromRGB(35, 0, 0)
panicShade.BackgroundTransparency = 0.82
panicShade.BorderSizePixel = 0
panicShade.Visible = false
panicShade.ZIndex = 2
panicShade.Parent = gui

local panicWarning = label(
	panicShade,
	"Warning",
	"GEORGE IS COMING",
	UDim2.new(1, -40, 0, 90),
	UDim2.new(0, 20, 0.5, -45),
	Enum.Font.GothamBlack,
	46,
	COLORS.red,
	Enum.TextXAlignment.Center
)
panicWarning.ZIndex = 3
panicWarning.TextStrokeColor3 = Color3.new(0, 0, 0)
panicWarning.TextStrokeTransparency = 0.1
panicWarning.TextScaled = true
local panicTextConstraint = Instance.new("UITextSizeConstraint")
panicTextConstraint.MinTextSize = 20
panicTextConstraint.MaxTextSize = 46
panicTextConstraint.Parent = panicWarning

local panicIntro = Instance.new("Frame")
panicIntro.Name = "PanicIntro"
panicIntro.Size = UDim2.fromScale(1, 1)
panicIntro.BackgroundColor3 = Color3.new(0, 0, 0)
panicIntro.BackgroundTransparency = 1
panicIntro.BorderSizePixel = 0
panicIntro.Visible = false
panicIntro.ZIndex = 50
panicIntro.Parent = gui

local panicIntroTitle = label(
	panicIntro,
	"IntroTitle",
	"YOU SHOULDN'T HAVE DONE THAT",
	UDim2.new(1, -48, 0, 80),
	UDim2.new(0, 24, 0.42, 0),
	Enum.Font.GothamBlack,
	42,
	COLORS.red,
	Enum.TextXAlignment.Center
)
panicIntroTitle.ZIndex = 51
panicIntroTitle.TextStrokeTransparency = 0
panicIntroTitle.TextScaled = true

local panicIntroSub = label(
	panicIntro,
	"IntroSub",
	"GEORGE IS COMING",
	UDim2.new(1, -48, 0, 40),
	UDim2.new(0, 24, 0.55, 0),
	Enum.Font.GothamBold,
	24,
	COLORS.cream,
	Enum.TextXAlignment.Center
)
panicIntroSub.ZIndex = 51

local panicGeorgeFace = Instance.new("ImageLabel")
panicGeorgeFace.Name = "GeorgeFace"
panicGeorgeFace.AnchorPoint = Vector2.new(0.5, 0.5)
panicGeorgeFace.Position = UDim2.fromScale(0.5, 0.28)
panicGeorgeFace.Size = UDim2.fromOffset(180, 180)
panicGeorgeFace.BackgroundTransparency = 1
panicGeorgeFace.Image = "" -- filled from ReplicatedStorage attribute if present
panicGeorgeFace.ScaleType = Enum.ScaleType.Fit
panicGeorgeFace.ZIndex = 51
panicGeorgeFace.Visible = false
panicGeorgeFace.Parent = panicIntro

local panicIntroPlaying = false
local lastPanicIntroAt = 0

local function playPanicIntro()
	if panicIntroPlaying then
		return
	end
	local nowClock = os.clock()
	if nowClock - lastPanicIntroAt < 8 then
		return
	end
	lastPanicIntroAt = nowClock
	panicIntroPlaying = true
	local faceId = tonumber(gameRoot:GetAttribute("GeorgePanicImageId"))
		or tonumber(ReplicatedStorage:FindFirstChild("CooperCharacters") and ReplicatedStorage.CooperCharacters:GetAttribute("GeorgePanicImageId"))
	if faceId and faceId > 0 then
		panicGeorgeFace.Image = "rbxassetid://" .. tostring(faceId)
		panicGeorgeFace.Visible = true
	else
		panicGeorgeFace.Visible = false
	end
	panicIntro.Visible = true
	panicIntro.BackgroundTransparency = 1
	panicIntroTitle.TextTransparency = 1
	panicIntroSub.TextTransparency = 1
	TweenService:Create(panicIntro, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	task.delay(0.35, function()
		if not panicIntro.Parent then
			return
		end
		TweenService:Create(panicIntroTitle, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		TweenService:Create(panicIntroSub, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end)
	task.delay(2.4, function()
		if not panicIntro.Parent then
			return
		end
		TweenService:Create(panicIntro, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(panicIntroTitle, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(panicIntroSub, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		panicIntro.Visible = false
		panicIntroPlaying = false
	end)
end

local taskCards = {}
local currentSnapshot = nil
local currentMode = "Normal"
local toastSerial = 0
local toastEntryTween = nil
local toastExitTween = nil

local requesterColors = {
	George = COLORS.orange,
	Sheldon = COLORS.blue,
	Mary = COLORS.green,
	Missy = COLORS.purple,
	Georgie = COLORS.yellow,
	Meemaw = Color3.fromRGB(221, 96, 153),
}

local function stabilityColor(value)
	if value <= 25 then
		return COLORS.red
	elseif value <= 50 then
		return COLORS.orange
	elseif value < 75 then
		return COLORS.yellow
	end
	return COLORS.green
end

local function createTaskCard(taskData, order)
	local card = Instance.new("Frame")
	card.Name = "Task_" .. tostring(taskData.instanceId)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, 126)
	card.BackgroundColor3 = COLORS.panel
	card.BackgroundTransparency = 0.05
	card.Parent = taskList
	corner(card, 10)
	local accentColor = requesterColors[taskData.requester] or COLORS.cream
	stroke(card, accentColor, taskData.critical and 3 or 2, 0.12)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.fromOffset(7, 126)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel = 0
	accent.Parent = card
	corner(accent, 4)

	local requester = label(
		card,
		"Requester",
		string.upper(tostring(taskData.requester)) .. (taskData.critical and " • CRITICAL" or ""),
		UDim2.new(1, -110, 0, 20),
		UDim2.fromOffset(18, 8),
		Enum.Font.GothamBold,
		12,
		accentColor
	)
	local timer = label(
		card,
		"Timer",
		"0:00",
		UDim2.fromOffset(75, 26),
		UDim2.new(1, -88, 0, 7),
		Enum.Font.RobotoMono,
		19,
		COLORS.white,
		Enum.TextXAlignment.Right
	)
	local title = label(
		card,
		"Title",
		tostring(taskData.title),
		UDim2.new(1, -36, 0, 28),
		UDim2.fromOffset(18, 31),
		Enum.Font.GothamBlack,
		16,
		COLORS.white
	)
	local description = label(
		card,
		"Description",
		tostring(taskData.description),
		UDim2.new(1, -36, 0, 38),
		UDim2.fromOffset(18, 59),
		Enum.Font.GothamMedium,
		13,
		COLORS.muted
	)
	local reward = label(
		card,
		"Reward",
		string.format("$%d%s", tonumber(taskData.cash) or 0, (tonumber(taskData.chronons) or 0) > 0 and ("  +" .. tostring(taskData.chronons) .. " CHRONON") or ""),
		UDim2.new(1, -36, 0, 18),
		UDim2.fromOffset(18, 101),
		Enum.Font.GothamBold,
		12,
		COLORS.yellow
	)
	local timerTrack = Instance.new("Frame")
	timerTrack.Name = "TimerTrack"
	timerTrack.AnchorPoint = Vector2.new(1, 1)
	timerTrack.Position = UDim2.new(1, -14, 1, -10)
	timerTrack.Size = UDim2.fromOffset(128, 7)
	timerTrack.BackgroundColor3 = Color3.fromRGB(17, 19, 22)
	timerTrack.Parent = card
	corner(timerTrack, 4)
	local timerFill = Instance.new("Frame")
	timerFill.Name = "Fill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = accentColor
	timerFill.Parent = timerTrack
	corner(timerFill, 4)

	taskCards[taskData.instanceId] = {
		frame = card,
		data = taskData,
		timer = timer,
		fill = timerFill,
	}
	return card
end

local function rebuildTasks(tasks)
	for _, item in pairs(taskCards) do
		item.frame:Destroy()
	end
	table.clear(taskCards)
	emptyLabel.Visible = #tasks == 0
	for index, taskData in ipairs(tasks) do
		if type(taskData) == "table" and tonumber(taskData.instanceId) then
			createTaskCard(taskData, index)
		end
	end
	rebuildTaskArrows(tasks)
end

local arrowFolder = Instance.new("Folder")
arrowFolder.Name = "CooperTaskArrows"
arrowFolder.Parent = gui

local activeArrows = {}

local TASK_TARGET_HINTS = {
	BringGeorgeDrink = { "CooperFridgeBeerPrompt", "FridgeDoorPanel", "WhiteHotpointRefrigerator" },
	FindTVRemote = { "TVRemote", "Remote", "DenTV", "CooperTV" },
	SetFootballChannel = { "DenTV", "CooperTV", "TVScreen" },
	StopShower = { "CooperShowerTogglePrompt", "ChromeShowerHandle", "ShowerPipe", "BathroomShower" },
	WashHands = { "CooperSinkWashPrompt", "CreamSinkBasin", "OxbloodTileBathroomVanity" },
	BrushTeeth = { "CooperBrushTeethPrompt", "Toothbrush1", "CreamSinkBasin" },
	FlushToilet = { "CooperToiletFlushPrompt", "ChromeFlushHandle", "WhiteToiletBowl" },
	RunTerminalCommand = { "Sheldon1980sComputerDesk", "Keyboard" },
	CompleteCubeMove = { "PuzzleCube", "RubiksCube", "Cube" },
	CarryMachineCrate = { "MachineCrate", "CrateBay", "MachineCratePad" },
	CloseGarageDoor = { "InteractiveSectionalGarageDoor", "PromptMount" },
	FixGarageObstruction = { "GarageObstruction", "Obstruction" },
	RetrievePorchDelivery = { "PorchDelivery", "DeliveryPackage" },
	SecureStormItem = { "StormLocker", "StormStrapStation", "LooseStormItem" },
}

local function findNamedDescendant(root, name)
	if not root then
		return nil
	end
	local direct = root:FindFirstChild(name, true)
	if direct then
		return direct
	end
	return nil
end

local function partForInstance(found)
	if not found then
		return nil
	end
	if found:IsA("ProximityPrompt") then
		return found.Parent and (found.Parent:IsA("BasePart") and found.Parent or found.Parent:FindFirstChildWhichIsA("BasePart", true))
	elseif found:IsA("BasePart") then
		return found
	elseif found:IsA("Model") then
		return found.PrimaryPart or found:FindFirstChildWhichIsA("BasePart", true)
	end
	return found:FindFirstChildWhichIsA("BasePart", true)
end

local function playerHasLoneStar()
	for _, parent in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if parent then
			for _, child in ipairs(parent:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("CooperLoneStarBeer") == true then
					return true
				end
			end
		end
	end
	return false
end

local function resolveTaskTarget(taskData)
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	if tostring(taskData.id or taskData.targetHint or "") == "BringGeorgeDrink" and playerHasLoneStar() then
		local characters = environment and environment:FindFirstChild("CooperCharacters")
		local george = characters and characters:FindFirstChild("George", true)
		local georgePart = partForInstance(george)
		if georgePart then
			return georgePart
		end
	end
	local hints = TASK_TARGET_HINTS[tostring(taskData.id or taskData.targetHint or "")] or {}
	for _, name in ipairs(hints) do
		local found = findNamedDescendant(environment, name) or findNamedDescendant(workspace, name)
		local targetPart = partForInstance(found)
		if targetPart then
			return targetPart
		end
	end
	-- Fallback: requester NPC cutout
	local characters = environment and environment:FindFirstChild("CooperCharacters")
	local requester = tostring(taskData.requester or "")
	if characters and requester ~= "" then
		local npc = characters:FindFirstChild(requester, true)
		if npc then
			return partForInstance(npc)
		end
	end
	return nil
end

local function destroyArrows()
	for _, arrow in pairs(activeArrows) do
		if arrow.model then
			arrow.model:Destroy()
		end
	end
	table.clear(activeArrows)
end

local function createWorldArrow(taskData, targetPart)
	local labelsEnabled = player:GetAttribute("TaskLabelsEnabled") == 1
		or player:GetAttribute("TaskLabelsEnabled") == true
	local accentColor = requesterColors[taskData.requester]
		or (taskData.critical and COLORS.red)
		or COLORS.yellow
	local model = Instance.new("Model")
	model.Name = "TaskArrow_" .. tostring(taskData.instanceId)
	model.Parent = workspace.CurrentCamera or workspace

	local function guidePart(name, size, transparency)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = accentColor
		part.Transparency = transparency
		part.Size = size
		part.Parent = model
		return part
	end

	-- A small center glow surrounded by separated segments reads as a proper
	-- destination ring without becoming a large neon plate.
	local destination = Instance.new("Part")
	destination.Name = "GroundDestination"
	destination.Anchored = true
	destination.CanCollide = false
	destination.CanQuery = false
	destination.CanTouch = false
	destination.CastShadow = false
	destination.Material = Enum.Material.Neon
	destination.Color = accentColor
	destination.Transparency = 0.3
	destination.Size = Vector3.new(0.55, 0.06, 0.55)
	destination.Shape = Enum.PartType.Cylinder
	destination.CFrame = CFrame.new(targetPart.Position) * CFrame.Angles(0, 0, math.rad(90))
	destination.Parent = model

	local destinationRing = {}
	for index = 1, 12 do
		local segment = guidePart("DestinationRing" .. index, Vector3.new(0.48, 0.06, 0.14), 0.28)
		table.insert(destinationRing, segment)
	end

	-- Three two-piece chevrons form a clean animated breadcrumb trail.
	local chevrons = {}
	for index = 1, 3 do
		local left = guidePart("Chevron" .. index .. "Left", Vector3.new(0.2, 0.08, 1.15), 0.18)
		local right = guidePart("Chevron" .. index .. "Right", Vector3.new(0.2, 0.08, 1.15), 0.18)
		local stem = guidePart("Chevron" .. index .. "Stem", Vector3.new(0.2, 0.08, 0.62), 0.18)
		table.insert(chevrons, {
			left = left,
			right = right,
			stem = stem,
			index = index,
		})
	end

	local captionAnchor = Instance.new("Part")
	captionAnchor.Name = "GroundCaptionAnchor"
	captionAnchor.Anchored = true
	captionAnchor.CanCollide = false
	captionAnchor.CanQuery = false
	captionAnchor.CanTouch = false
	captionAnchor.CastShadow = false
	captionAnchor.Transparency = 1
	captionAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	captionAnchor.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GroundCaption"
	billboard.Size = UDim2.fromOffset(132, 30)
	billboard.StudsOffset = Vector3.new(0, 0.42, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 42
	billboard.Adornee = captionAnchor
	billboard.Parent = captionAnchor

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundColor3 = COLORS.panel
	caption.BackgroundTransparency = labelsEnabled and 0.22 or 0.42
	caption.Size = UDim2.fromScale(1, 1)
	caption.Font = Enum.Font.GothamBold
	caption.Text = string.upper(tostring(taskData.title or taskData.requester or "TASK"))
	caption.TextColor3 = accentColor
	caption.TextScaled = true
	caption.TextWrapped = true
	caption.Parent = billboard
	corner(caption, 5)

	local beamSource = Instance.new("Part")
	beamSource.Name = "GroundBeamSource"
	beamSource.Anchored = true
	beamSource.CanCollide = false
	beamSource.CanQuery = false
	beamSource.CanTouch = false
	beamSource.CastShadow = false
	beamSource.Transparency = 1
	beamSource.Size = Vector3.new(0.2, 0.2, 0.2)
	beamSource.Parent = model

	local a0 = Instance.new("Attachment")
	a0.Name = "TrailStart"
	a0.Parent = beamSource
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailEnd"
	a1.Parent = captionAnchor
	local beam = Instance.new("Beam")
	beam.Name = "GroundTrail"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Width0 = 0.28
	beam.Width1 = 0.12
	beam.Color = ColorSequence.new(accentColor)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.48),
		NumberSequenceKeypoint.new(1, 0.72),
	})
	beam.LightEmission = 0.35
	beam.LightInfluence = 0
	beam.Segments = 20
	beam.Parent = beamSource

	local highlight = Instance.new("Highlight")
	highlight.Name = "TaskTargetHighlight"
	highlight.Adornee = targetPart
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = accentColor
	highlight.FillTransparency = 0.93
	highlight.OutlineColor = accentColor
	highlight.OutlineTransparency = 0.52
	highlight.Parent = model

	return {
		model = model,
		destination = destination,
		destinationRing = destinationRing,
		chevrons = chevrons,
		captionAnchor = captionAnchor,
		beamSource = beamSource,
		beam = beam,
		target = targetPart,
		taskData = taskData,
		highlight = highlight,
	}
end

function rebuildTaskArrows(tasks)
	destroyArrows()
	if currentMode == "Panic" then
		return
	end
	local remoteTracker = player:GetAttribute("RemoteTrackerEnabled") == 1
		or player:GetAttribute("RemoteTrackerEnabled") == true
	for index, taskData in ipairs(tasks) do
		if type(taskData) == "table" then
			local isRemoteTask = taskData.id == "FindTVRemote" or taskData.id == "SetFootballChannel"
			local target = resolveTaskTarget(taskData)
			if isRemoteTask and remoteTracker then
				local remotePart = findNamedDescendant(workspace, "TVRemote") or findNamedDescendant(workspace, "Remote")
				if remotePart and remotePart:IsA("BasePart") then
					target = remotePart
				end
			end
			if target then
				activeArrows[taskData.instanceId] = createWorldArrow(taskData, target)
			end
		end
	end
end

local arrowFloorParams = RaycastParams.new()
arrowFloorParams.FilterType = Enum.RaycastFilterType.Exclude
arrowFloorParams.IgnoreWater = true

local function isFloorLike(part, normalY)
	if normalY < 0.7 or not part:IsA("BasePart") then
		return false
	end
	local name = string.lower(part.Name)
	if string.find(name, "floor", 1, true)
		or string.find(name, "carpet", 1, true)
		or string.find(name, "subfloor", 1, true)
		or string.find(name, "rug", 1, true)
		or string.find(name, "tile", 1, true)
		or string.find(name, "mosaic", 1, true)
	then
		return true
	end
	-- Large thin slabs only — skip handles, lids, and countertops.
	local size = part.Size
	return size.Y <= 0.35 and size.X >= 4 and size.Z >= 4
end

local function groundPointNear(position, excludeInstances)
	arrowFloorParams.FilterDescendantsInstances = excludeInstances or {}
	-- Walk a short downward probe and accept only floor-like upward hits.
	local cursor = position + Vector3.new(0, 4, 0)
	local budget = 14
	for _ = 1, 10 do
		local hit = workspace:Raycast(cursor, Vector3.new(0, -budget, 0), arrowFloorParams)
		if not hit then
			break
		end
		if isFloorLike(hit.Instance, hit.Normal.Y) then
			return hit.Position + Vector3.new(0, 0.08, 0)
		end
		cursor = hit.Position - Vector3.new(0, 0.08, 0)
		budget = math.max(1, cursor.Y - (position.Y - 10))
	end
	return Vector3.new(position.X, position.Y - 2.8, position.Z)
end

local nextArrowRetargetAt = 0
-- Keep ground pads/chevrons tracking targets. Retargeting also switches the
-- beer task from the fridge to George as soon as the player takes a Lone Star.
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nowClock = os.clock()
	local shouldRetarget = nowClock >= nextArrowRetargetAt
	if shouldRetarget then
		nextArrowRetargetAt = nowClock + 0.25
	end
	local exclude = { character }
	for _, arrow in pairs(activeArrows) do
		if arrow.model then
			table.insert(exclude, arrow.model)
		end
	end
	for _, arrow in pairs(activeArrows) do
		if shouldRetarget then
			local desiredTarget = resolveTaskTarget(arrow.taskData)
			if desiredTarget and desiredTarget ~= arrow.target then
				arrow.target = desiredTarget
				if arrow.highlight then
					arrow.highlight.Adornee = desiredTarget
				end
			end
		end
		local target = arrow.target
		if target and target.Parent then
			-- Prefer a point near the base of the target, not its center mass.
			local targetProbe = target.Position - Vector3.new(0, target.Size.Y * 0.45, 0)
			local destPos = groundPointNear(targetProbe, exclude)
			local destCf = CFrame.new(destPos) * CFrame.Angles(0, 0, math.rad(90))
			if arrow.destination then
				arrow.destination.CFrame = destCf
			end
			if arrow.destinationRing then
				local ringPulse = (math.sin(nowClock * 2.8) + 1) * 0.5
				for index, segment in ipairs(arrow.destinationRing) do
					local angle = ((index - 1) / #arrow.destinationRing) * math.pi * 2
					segment.CFrame = CFrame.new(destPos)
						* CFrame.Angles(0, angle, 0)
						* CFrame.new(0, 0.08, -1.05)
					segment.Transparency = 0.38 - ringPulse * 0.16
				end
			end
			if arrow.captionAnchor then
				arrow.captionAnchor.CFrame = CFrame.new(destPos)
			end
			if arrow.destination then
				arrow.destination.Transparency = 0.38 - (math.sin(nowClock * 2.8) + 1) * 0.07
			end
			if root and arrow.beamSource and arrow.chevrons then
				local playerGround = groundPointNear(root.Position, exclude)
				local toTarget = Vector3.new(destPos.X - playerGround.X, 0, destPos.Z - playerGround.Z)
				local distance = toTarget.Magnitude
				if distance > 0.2 then
					local direction = toTarget.Unit
					for _, chevron in ipairs(arrow.chevrons) do
						local offset = 2.8 + (chevron.index - 1) * 2.25
						local visible = distance > offset + 0.8
						if visible then
							local probe = playerGround + direction * offset
							local markerPos = groundPointNear(
								Vector3.new(probe.X, playerGround.Y, probe.Z),
								exclude
							)
							local wave = (math.sin(nowClock * 4.2 - chevron.index * 0.85) + 1) * 0.5
							local transparency = 0.3 - wave * 0.2
							chevron.left.Transparency = transparency
							chevron.right.Transparency = transparency
							chevron.stem.Transparency = transparency

							local rightVector = Vector3.new(-direction.Z, 0, direction.X)
							local lift = Vector3.new(0, 0.12, 0)
							local apex = markerPos + direction * 0.62 + lift
							local leftTail = markerPos - direction * 0.18 - rightVector * 0.48 + lift
							local rightTail = markerPos - direction * 0.18 + rightVector * 0.48 + lift
							local leftCenter = leftTail:Lerp(apex, 0.5)
							local rightCenter = rightTail:Lerp(apex, 0.5)
							chevron.left.Size = Vector3.new(0.2, 0.08, (apex - leftTail).Magnitude)
							chevron.right.Size = Vector3.new(0.2, 0.08, (apex - rightTail).Magnitude)
							chevron.left.CFrame = CFrame.lookAt(leftCenter, apex, Vector3.yAxis)
							chevron.right.CFrame = CFrame.lookAt(rightCenter, apex, Vector3.yAxis)
							local stemCenter = markerPos - direction * 0.48 + lift
							chevron.stem.CFrame = CFrame.lookAt(
								stemCenter,
								stemCenter + direction,
								Vector3.yAxis
							)
						else
							chevron.left.Transparency = 1
							chevron.right.Transparency = 1
							chevron.stem.Transparency = 1
						end
					end
					local trailProbe = playerGround + direction * 1.5
					local trailStart = groundPointNear(
						Vector3.new(trailProbe.X, playerGround.Y, trailProbe.Z),
						exclude
					)
					arrow.beamSource.CFrame = CFrame.new(trailStart + Vector3.new(0, 0.18, 0))
				else
					for _, chevron in ipairs(arrow.chevrons) do
						chevron.left.Transparency = 1
						chevron.right.Transparency = 1
						chevron.stem.Transparency = 1
					end
					arrow.beamSource.CFrame = CFrame.new(playerGround + Vector3.new(0, 0.18, 0))
				end
				if arrow.beam then
					arrow.beam.Enabled = distance > 3
				end
			end
		end
	end
end)

local function setMode(mode)
	local previous = currentMode
	currentMode = tostring(mode or "Normal")
	modeChip.Text = string.upper(currentMode)
	local isPanic = currentMode == "Panic"
	panicShade.Visible = isPanic
	modeChip.TextColor3 = isPanic and COLORS.red or COLORS.green
	cashLabel.Visible = not isPanic
	chrononLabel.Visible = not isPanic
	if isPanic then
		panicWarning.Text = "GEORGE IS COMING"
		if previous ~= "Panic" then
			playPanicIntro()
		end
	end
end

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	if currentSnapshot and tonumber(snapshot.revision) and tonumber(currentSnapshot.revision)
		and snapshot.revision < currentSnapshot.revision
	then
		return
	end
	currentSnapshot = snapshot
	local value = math.clamp(tonumber(snapshot.stability) or 0, 0, 100)
	local color = stabilityColor(value)
	stabilityValue.Text = tostring(math.floor(value + 0.5))
	stabilityValue.TextColor3 = color
	TweenService:Create(stabilityFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(value / 100, 1),
		BackgroundColor3 = color,
	}):Play()
	local progress = math.clamp(tonumber(snapshot.machineProgress) or 0, 0, 100)
	machineTitle.Text = string.format("TIME MACHINE • %d%%", math.floor(progress + 0.5))
	machineStage.Text = tostring(snapshot.machineStageName or "Blueprint Pending")
	TweenService:Create(machineFill, TweenInfo.new(0.45, Enum.EasingStyle.Quart), {
		Size = UDim2.fromScale(progress / 100, 1),
	}):Play()
	cashLabel.Text = "$" .. tostring(math.max(0, math.floor(tonumber(snapshot.cash) or 0)))
	chrononLabel.Text = tostring(math.max(0, math.floor(tonumber(snapshot.chronons) or 0))) .. " CHRONONS"
	chapterLabel.Text = string.format(
		"CHAPTER %s • %s",
		tostring(snapshot.chapter or 0),
		string.upper(tostring(snapshot.chapterName or "The Blueprint"))
	)
	setMode(snapshot.mode)
	local onboardingActive = snapshot.onboardingActive == true
	local onboardingCompleted = math.max(0, math.floor(tonumber(snapshot.onboardingCompletions) or 0))
	local onboardingRequired = math.max(1, math.floor(tonumber(snapshot.onboardingRequired) or 3))
	guidedBar.Visible = onboardingActive
	if onboardingActive then
		guidedText.Text = string.format(
			"GUIDED START • %d/%d CHORES • NO FAILURE PENALTY • FOLLOW THE COLORED ARROW",
			onboardingCompleted,
			onboardingRequired
		)
		modeChip.Text = "GUIDED"
		modeChip.TextColor3 = COLORS.green
		if not initialTutorialShown then
			initialTutorialShown = true
			showTutorialCard(
				"WELCOME TO THE COOPER HOUSE",
				"Explore at your own pace. Follow the task's colored arrow and beam, then use the interaction key shown near the object. Complete three simple chores to learn the house. Nothing bad happens if a guided chore times out.",
				"START EXPLORING",
				COLORS.green
			)
		end
	end
	rebuildTasks(type(snapshot.tasks) == "table" and snapshot.tasks or {})
	gui:SetAttribute("StateReady", true)
end

local function showToast(titleText, detailText, color, duration)
	toastSerial += 1
	local serial = toastSerial
	if toastEntryTween then
		toastEntryTween:Cancel()
		toastEntryTween = nil
	end
	if toastExitTween then
		toastExitTween:Cancel()
		toastExitTween = nil
	end
	toastTitle.Text = tostring(titleText or "")
	toastDetail.Text = tostring(detailText or "")
	toastStroke.Color = color or COLORS.cream
	toast.Position = UDim2.new(0.5, 0, 1, 80)
	toast.Visible = true
	toastEntryTween = TweenService:Create(toast, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -24),
	})
	toastEntryTween:Play()
	task.delay(duration or 2.8, function()
		if serial ~= toastSerial or not toast.Parent then
			return
		end
		toastExitTween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 80),
		})
		toastExitTween:Play()
		toastExitTween.Completed:Wait()
		if serial == toastSerial then
			toast.Visible = false
			toastExitTween = nil
		end
	end)
end

feedbackEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "TaskStarted" then
		local taskColor = requesterColors[payload.requester] or (payload.critical and COLORS.red or COLORS.yellow)
		showToast(tostring(payload.requester or "THE FAMILY") .. " NEEDS YOU", tostring(payload.title or "NEW REQUEST"), taskColor, 2.4)
	elseif kind == "TaskComplete" then
		showToast("TASK COMPLETE", string.format("+$%d  •  COMBO x%d", tonumber(payload.cash) or 0, tonumber(payload.combo) or 1), COLORS.green, 2.8)
	elseif kind == "TaskFailed" then
		if payload.guided then
			showToast("NO PENALTY — TRY THE NEXT ONE", tostring(payload.title or "GUIDED CHORE"), COLORS.yellow, 3.2)
		else
			showToast(payload.critical and "CRITICAL TASK FAILED" or "TOO LATE", tostring(payload.title or "REQUEST FAILED"), COLORS.red, 3.2)
		end
	elseif kind == "Stability" then
		local delta = tonumber(payload.delta) or 0
		showToast(delta >= 0 and "HOUSE CALMING DOWN" or "HOUSE STABILITY LOST", string.format("%+d • %s", delta, tostring(payload.reason or "")), delta >= 0 and COLORS.green or COLORS.orange, 2.1)
	elseif kind == "Mode" then
		setMode(payload.mode)
		if payload.mode == "Panic" then
			showToast("YOU FORGOT SOMETHING IMPORTANT", "THE HOUSE IS NO LONGER SAFE", COLORS.red, 4)
		end
	elseif kind == "MachineStage" then
		showToast("TIME MACHINE UPGRADED", tostring(payload.name or "NEW COMPONENT") .. " • " .. tostring(payload.progress or 0) .. "%", COLORS.blue, 4)
	elseif kind == "OnboardingStarted" then
		if not initialTutorialShown then
			initialTutorialShown = true
			showTutorialCard(
				tostring(payload.title or "WELCOME TO THE COOPER HOUSE"),
				tostring(payload.text or ""),
				"START EXPLORING",
				COLORS.green
			)
		end
	elseif kind == "OnboardingProgress" then
		showToast("GUIDED CHORE COMPLETE", tostring(payload.text or ""), COLORS.green, 3.4)
	elseif kind == "OnboardingComplete" then
		guidedBar.Visible = false
		showTutorialCard(
			tostring(payload.title or "GEORGE IS ON HIS WAY"),
			tostring(payload.text or "Timed requests are active now."),
			"I UNDERSTAND",
			COLORS.orange
		)
	elseif kind == "Toast" then
		showToast("COOPER HOUSE", tostring(payload.text or ""), COLORS.cream, 3.2)
	end
end)

snapshotEvent.OnClientEvent:Connect(applySnapshot)

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, card in pairs(taskCards) do
		local data = card.data
		local duration = math.max(0.01, tonumber(data.deadline) or ((tonumber(data.expiresAt) or now) - (tonumber(data.startedAt) or now)))
		local remaining = math.max(0, (tonumber(data.expiresAt) or now) - now)
		local remainingSeconds = math.ceil(remaining)
		local ratio = math.clamp(remaining / duration, 0, 1)
		card.timer.Text = string.format("%d:%02d", math.floor(remainingSeconds / 60), remainingSeconds % 60)
		card.fill.Size = UDim2.fromScale(ratio, 1)
		local color = ratio <= 0.2 and COLORS.red or (ratio <= 0.45 and COLORS.orange or (requesterColors[data.requester] or COLORS.cream))
		card.fill.BackgroundColor3 = color
		card.timer.TextColor3 = color
	end
end)

local cameraConnection
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	if viewport.X < 900 then
		hudRoot.Size = UDim2.fromOffset(380, 720)
		rootScale.Scale = math.clamp(math.min((viewport.X - 12) / 380, viewport.Y / 720), 0.45, 1)
		topBar.Position = UDim2.new(0.5, 0, 0, 8)
		topBar.Size = UDim2.fromOffset(380, 112)
		stabilityTitle.Position = UDim2.fromOffset(12, 7)
		stabilityTitle.Size = UDim2.fromOffset(150, 20)
		stabilityValue.Position = UDim2.fromOffset(108, 1)
		stabilityValue.Size = UDim2.fromOffset(52, 30)
		stabilityTrack.Position = UDim2.fromOffset(12, 36)
		stabilityTrack.Size = UDim2.fromOffset(148, 16)
		divider1.Position = UDim2.fromOffset(173, 8)
		divider1.Size = UDim2.fromOffset(2, 52)
		divider1.Visible = true
		machineTitle.Position = UDim2.fromOffset(186, 7)
		machineTitle.Size = UDim2.fromOffset(182, 20)
		machineStage.Position = UDim2.fromOffset(186, 28)
		machineStage.Size = UDim2.fromOffset(182, 20)
		machineTrack.Position = UDim2.fromOffset(186, 52)
		machineTrack.Size = UDim2.fromOffset(182, 8)
		divider2.Visible = false
		cashLabel.Position = UDim2.fromOffset(12, 72)
		cashLabel.Size = UDim2.fromOffset(108, 26)
		chrononLabel.Position = UDim2.fromOffset(124, 75)
		chrononLabel.Size = UDim2.fromOffset(140, 22)
		modeChip.Position = UDim2.fromOffset(270, 75)
		modeChip.Size = UDim2.fromOffset(98, 20)
		tasksPanel.Position = UDim2.fromOffset(12, 170)
		tasksPanel.Size = UDim2.fromOffset(356, 484)
		toast.Size = UDim2.fromOffset(356, 72)
		guidedBar.Position = UDim2.new(0.5, 0, 0, 126)
		guidedBar.Size = UDim2.fromOffset(356, 36)
		tutorialCard.Size = UDim2.fromOffset(math.max(300, math.min(620, viewport.X - 32)), 330)
		tutorialTitle.Size = UDim2.new(1, -36, 0, 60)
		tutorialTitle.Position = UDim2.fromOffset(18, 18)
		tutorialTitle.TextSize = 21
		tutorialBody.Size = UDim2.new(1, -44, 0, 170)
		tutorialBody.Position = UDim2.fromOffset(22, 82)
		tutorialBody.TextSize = 15
	else
		hudRoot.Size = UDim2.fromOffset(1280, 720)
		rootScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.62, 1.08)
		topBar.Position = UDim2.new(0.5, 0, 0, 12)
		topBar.Size = UDim2.fromOffset(860, 86)
		stabilityTitle.Position = UDim2.fromOffset(18, 10)
		stabilityTitle.Size = UDim2.fromOffset(245, 22)
		stabilityValue.Position = UDim2.fromOffset(190, 2)
		stabilityValue.Size = UDim2.fromOffset(62, 32)
		stabilityTrack.Position = UDim2.fromOffset(18, 42)
		stabilityTrack.Size = UDim2.fromOffset(234, 20)
		divider1.Position = UDim2.fromOffset(273, 12)
		divider1.Size = UDim2.fromOffset(2, 60)
		divider1.Visible = true
		machineTitle.Position = UDim2.fromOffset(294, 10)
		machineTitle.Size = UDim2.fromOffset(330, 22)
		machineStage.Position = UDim2.fromOffset(294, 31)
		machineStage.Size = UDim2.fromOffset(330, 24)
		machineTrack.Position = UDim2.fromOffset(294, 58)
		machineTrack.Size = UDim2.fromOffset(330, 10)
		divider2.Position = UDim2.fromOffset(645, 12)
		divider2.Size = UDim2.fromOffset(2, 60)
		divider2.Visible = true
		cashLabel.Position = UDim2.fromOffset(665, 10)
		cashLabel.Size = UDim2.fromOffset(180, 26)
		chrononLabel.Position = UDim2.fromOffset(665, 39)
		chrononLabel.Size = UDim2.fromOffset(180, 22)
		modeChip.Position = UDim2.fromOffset(727, 62)
		modeChip.Size = UDim2.fromOffset(118, 20)
		tasksPanel.Position = UDim2.fromOffset(18, 116)
		tasksPanel.Size = UDim2.fromOffset(380, 510)
		toast.Size = UDim2.fromOffset(540, 72)
		guidedBar.Position = UDim2.new(0.5, 0, 0, 104)
		guidedBar.Size = UDim2.fromOffset(480, 34)
		tutorialCard.Size = UDim2.fromOffset(620, 285)
		tutorialTitle.Size = UDim2.new(1, -48, 0, 52)
		tutorialTitle.Position = UDim2.fromOffset(24, 22)
		tutorialTitle.TextSize = 25
		tutorialBody.Size = UDim2.new(1, -64, 0, 128)
		tutorialBody.Position = UDim2.fromOffset(32, 78)
		tutorialBody.TextSize = 17
	end
end

local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

task.delay(0.5, function()
	requestEvent:FireServer("RequestSnapshot")
end)

showToast("WELCOME TO THE COOPER HOUSE", "DO CHORES • KEEP GEORGE CALM • BUILD THE TIME MACHINE", COLORS.cream, 4.5)
print("[CooperGame] Campaign HUD ready")
