-- High-tech bunker notices and research-terminal interface. Purchase requests
-- still go through CooperGame's server-authoritative economy; this client owns
-- only presentation, responsive layout, and ordinary input routing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local CLIENT_VERSION = "3.2.1"
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("CooperBunkerRemotes")
local bunkerEvent = remotes:WaitForChild("BunkerEvent")
local gameRoot = ReplicatedStorage:WaitForChild("CooperGame", 30)
local gameRemotes = gameRoot:WaitForChild("Remotes", 10)
local snapshotEvent = gameRemotes:WaitForChild("Snapshot", 10)
local feedbackEvent = gameRemotes:WaitForChild("Feedback", 10)
local requestEvent = gameRemotes:WaitForChild("Request", 10)
if not snapshotEvent or not feedbackEvent or not requestEvent then
	return
end

local oldGui = playerGui:FindFirstChild("CooperBunkerNoticeGui")
if oldGui then
	oldGui:Destroy()
end

local COLORS = {
	void = Color3.fromRGB(1, 6, 12),
	panel = Color3.fromRGB(5, 17, 26),
	panelBright = Color3.fromRGB(9, 31, 43),
	cyan = Color3.fromRGB(64, 231, 255),
	cyanSoft = Color3.fromRGB(159, 245, 255),
	violet = Color3.fromRGB(183, 95, 255),
	green = Color3.fromRGB(70, 242, 173),
	amber = Color3.fromRGB(255, 193, 72),
	red = Color3.fromRGB(255, 89, 104),
	white = Color3.fromRGB(235, 250, 255),
	muted = Color3.fromRGB(114, 171, 187),
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 8)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	item.Color = color or COLORS.cyan
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0
	item.Parent = parent
	return item
end

local function label(parent, name, text, size, position, font, textSize, color, alignment)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position or UDim2.fromScale(0, 0)
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Text = text or ""
	item.TextColor3 = color or COLORS.white
	item.Font = font or Enum.Font.GothamMedium
	item.TextSize = textSize or 16
	item.TextWrapped = true
	item.TextXAlignment = alignment or Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local function button(parent, name, text, size, position, accent)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Size = size
	item.Position = position or UDim2.fromScale(0, 0)
	item.BackgroundColor3 = Color3.fromRGB(8, 35, 48)
	item.BackgroundTransparency = 0.02
	item.BorderSizePixel = 0
	item.AutoButtonColor = true
	item.Active = true
	item.Selectable = true
	item.Text = text
	item.TextColor3 = COLORS.white
	item.Font = Enum.Font.GothamBold
	item.TextSize = 17
	item.TextWrapped = true
	item.Parent = parent
	corner(item, 9)
	stroke(item, accent or COLORS.cyan, 2, 0.16)
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperBunkerNoticeGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ClipToDeviceSafeArea = true
gui.DisplayOrder = 960
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Shared top notice ---------------------------------------------------------
local notice = Instance.new("TextLabel")
notice.Name = "Notice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 18)
notice.Size = UDim2.new(0.72, 0, 0, 58)
notice.BackgroundColor3 = Color3.fromRGB(10, 22, 29)
notice.BackgroundTransparency = 1
notice.BorderSizePixel = 0
notice.TextColor3 = COLORS.amber
notice.TextTransparency = 1
notice.Font = Enum.Font.GothamBold
notice.TextScaled = true
notice.TextWrapped = true
notice.Visible = false
notice.ZIndex = 220
notice.Parent = gui
corner(notice, 10)
local noticeTextConstraint = Instance.new("UITextSizeConstraint")
noticeTextConstraint.MaxTextSize = 18
noticeTextConstraint.MinTextSize = 12
noticeTextConstraint.Parent = notice
local noticeSizeConstraint = Instance.new("UISizeConstraint")
noticeSizeConstraint.MaxSize = Vector2.new(560, 58)
noticeSizeConstraint.MinSize = Vector2.new(260, 58)
noticeSizeConstraint.Parent = notice
local noticePadding = Instance.new("UIPadding")
noticePadding.PaddingLeft = UDim.new(0, 15)
noticePadding.PaddingRight = UDim.new(0, 15)
noticePadding.PaddingTop = UDim.new(0, 8)
noticePadding.PaddingBottom = UDim.new(0, 8)
noticePadding.Parent = notice
local noticeStroke = stroke(notice, COLORS.amber, 2, 1)
local noticeGeneration = 0

local function showNotice(text, color, duration)
	if type(text) ~= "string" or text == "" then
		return
	end
	noticeGeneration += 1
	local generation = noticeGeneration
	local accent = color or COLORS.amber
	notice.Text = text
	notice.TextColor3 = accent
	noticeStroke.Color = accent
	notice.Visible = true
	notice.BackgroundTransparency = 1
	notice.TextTransparency = 1
	noticeStroke.Transparency = 1
	TweenService:Create(notice, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.08,
		TextTransparency = 0,
	}):Play()
	TweenService:Create(noticeStroke, TweenInfo.new(0.18), { Transparency = 0.08 }):Play()
	task.delay(duration or 4, function()
		if generation ~= noticeGeneration then
			return
		end
		local fade = TweenService:Create(notice, TweenInfo.new(0.25), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		fade:Play()
		TweenService:Create(noticeStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		fade.Completed:Once(function()
			if generation == noticeGeneration then
				notice.Visible = false
			end
		end)
	end)
end

-- Full-screen bunker terminal ---------------------------------------------
local shade = Instance.new("Frame")
shade.Name = "ResearchTerminalShade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(0, 3, 8)
shade.BackgroundTransparency = 0.08
shade.BorderSizePixel = 0
shade.Active = true
shade.Visible = false
shade.ZIndex = 100
shade.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "ResearchTerminal"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(1000, 650)
panel.BackgroundColor3 = COLORS.void
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.ZIndex = 101
panel.Parent = shade
corner(panel, 10)
stroke(panel, COLORS.cyan, 2, 0.02)

local grid = Instance.new("Frame")
grid.Name = "CircuitGrid"
grid.Size = UDim2.fromScale(1, 1)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ZIndex = 102
grid.Parent = panel
for index = 1, 19 do
	local vertical = Instance.new("Frame")
	vertical.Name = "GridV"
	vertical.Position = UDim2.new((index - 1) / 18, 0, 0, 0)
	vertical.Size = UDim2.new(0, 1, 1, 0)
	vertical.BackgroundColor3 = index % 4 == 1 and COLORS.violet or COLORS.cyan
	vertical.BackgroundTransparency = index % 4 == 1 and 0.91 or 0.95
	vertical.BorderSizePixel = 0
	vertical.ZIndex = 102
	vertical.Parent = grid
end
for index = 1, 14 do
	local horizontal = Instance.new("Frame")
	horizontal.Name = "GridH"
	horizontal.Position = UDim2.new(0, 0, (index - 1) / 13, 0)
	horizontal.Size = UDim2.new(1, 0, 0, 1)
	horizontal.BackgroundColor3 = COLORS.cyan
	horizontal.BackgroundTransparency = 0.95
	horizontal.BorderSizePixel = 0
	horizontal.ZIndex = 102
	horizontal.Parent = grid
end

local scanSweep = Instance.new("Frame")
scanSweep.Name = "ScanSweep"
scanSweep.Position = UDim2.new(0, 0, 0, -18)
scanSweep.Size = UDim2.new(1, 0, 0, 18)
scanSweep.BackgroundColor3 = COLORS.cyan
scanSweep.BackgroundTransparency = 0.91
scanSweep.BorderSizePixel = 0
scanSweep.ZIndex = 103
scanSweep.Parent = panel
TweenService:Create(
	scanSweep,
	TweenInfo.new(3.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
	{ Position = UDim2.new(0, 0, 1, 0) }
):Play()

local header = Instance.new("Frame")
header.Name = "Header"
header.Position = UDim2.fromOffset(12, 10)
header.Size = UDim2.new(1, -24, 0, 64)
header.BackgroundColor3 = Color3.fromRGB(5, 25, 35)
header.BackgroundTransparency = 0.03
header.BorderSizePixel = 0
header.ZIndex = 110
header.Parent = panel
corner(header, 7)
stroke(header, COLORS.cyan, 1, 0.28)

local title = label(
	header,
	"Title",
	"COOPER RESEARCH CORE // LABNET",
	UDim2.new(1, -166, 0, 30),
	UDim2.fromOffset(16, 7),
	Enum.Font.RobotoMono,
	20,
	COLORS.cyan
)
title.ZIndex = 111
local subtitle = label(
	header,
	"Subtitle",
	"UNDERGROUND PROCUREMENT CHANNEL  •  ENCRYPTED  •  ONLINE",
	UDim2.new(1, -166, 0, 18),
	UDim2.fromOffset(16, 38),
	Enum.Font.RobotoMono,
	11,
	COLORS.muted
)
subtitle.ZIndex = 111
local closeButton = button(
	header,
	"Close",
	"Exit",
	UDim2.fromOffset(124, 46),
	UDim2.new(1, -138, 0, 9),
	COLORS.red
)
closeButton.ZIndex = 112

local statusPanel = Instance.new("Frame")
statusPanel.Name = "SystemStatus"
statusPanel.Position = UDim2.fromOffset(12, 84)
statusPanel.Size = UDim2.fromOffset(298, 552)
statusPanel.BackgroundColor3 = Color3.fromRGB(4, 20, 29)
statusPanel.BackgroundTransparency = 0.04
statusPanel.BorderSizePixel = 0
statusPanel.ZIndex = 108
statusPanel.Parent = panel
corner(statusPanel, 8)
stroke(statusPanel, COLORS.violet, 2, 0.24)

local statusHeader = label(
	statusPanel,
	"StatusHeader",
	"SYSTEM STATUS",
	UDim2.new(1, -28, 0, 28),
	UDim2.fromOffset(14, 13),
	Enum.Font.RobotoMono,
	16,
	COLORS.violet
)
statusHeader.ZIndex = 109
local allowanceTitle = label(statusPanel, "AllowanceTitle", "AVAILABLE ALLOWANCE", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 58), Enum.Font.RobotoMono, 11, COLORS.muted)
allowanceTitle.ZIndex = 109
local allowanceValue = label(statusPanel, "AllowanceValue", "$0", UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 77), Enum.Font.GothamBlack, 32, COLORS.amber)
allowanceValue.ZIndex = 109
local bunkerStatus = label(statusPanel, "BunkerStatus", "● BUNKER LINK ONLINE", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 136), Enum.Font.RobotoMono, 13, COLORS.green)
bunkerStatus.ZIndex = 109
local labStatusTitle = label(statusPanel, "LabStatusTitle", "CHEMISTRY LAB", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 188), Enum.Font.RobotoMono, 11, COLORS.muted)
labStatusTitle.ZIndex = 109
local labStatusValue = label(statusPanel, "LabStatusValue", "AVAILABLE", UDim2.new(1, -28, 0, 56), UDim2.fromOffset(14, 211), Enum.Font.GothamBold, 22, COLORS.cyan)
labStatusValue.TextYAlignment = Enum.TextYAlignment.Top
labStatusValue.ZIndex = 109
local labPrice = label(statusPanel, "LabPrice", "PRICE: $1800", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 276), Enum.Font.RobotoMono, 14, COLORS.amber)
labPrice.ZIndex = 109

local diagnostic = label(
	statusPanel,
	"Diagnostic",
	[[CORE TEMP     36.4 C
POWER BUS     STABLE
AIR HANDLING  NOMINAL
DATA LINK     SECURE
CHEM BUS      STANDBY]],
	UDim2.new(1, -28, 0, 138),
	UDim2.fromOffset(14, 332),
	Enum.Font.RobotoMono,
	13,
	COLORS.cyanSoft
)
diagnostic.TextYAlignment = Enum.TextYAlignment.Top
diagnostic.ZIndex = 109
local statusHint = label(
	statusPanel,
	"Hint",
	"Choose an action on the right. Every button says exactly what it does.",
	UDim2.new(1, -28, 0, 62),
	UDim2.fromOffset(14, 476),
	Enum.Font.GothamMedium,
	13,
	COLORS.muted
)
statusHint.TextYAlignment = Enum.TextYAlignment.Bottom
statusHint.ZIndex = 109

local contentPanel = Instance.new("Frame")
contentPanel.Name = "Content"
contentPanel.Position = UDim2.fromOffset(322, 84)
contentPanel.Size = UDim2.new(1, -334, 1, -98)
contentPanel.BackgroundColor3 = Color3.fromRGB(3, 15, 23)
contentPanel.BackgroundTransparency = 0.03
contentPanel.BorderSizePixel = 0
contentPanel.ZIndex = 108
contentPanel.Parent = panel
corner(contentPanel, 8)
stroke(contentPanel, COLORS.cyan, 1, 0.35)

local pageTitle = label(
	contentPanel,
	"PageTitle",
	"RESEARCH PROCUREMENT",
	UDim2.new(1, -184, 0, 34),
	UDim2.fromOffset(18, 14),
	Enum.Font.RobotoMono,
	19,
	COLORS.cyan
)
pageTitle.ZIndex = 109
local backButton = button(
	contentPanel,
	"Back",
	"← Back",
	UDim2.fromOffset(142, 44),
	UDim2.new(1, -156, 0, 10),
	COLORS.violet
)
backButton.ZIndex = 112
backButton.Visible = false

local pageDescription = label(
	contentPanel,
	"Description",
	"Select a bunker system below.",
	UDim2.new(1, -36, 0, 82),
	UDim2.fromOffset(18, 58),
	Enum.Font.GothamMedium,
	15,
	COLORS.cyanSoft
)
pageDescription.TextYAlignment = Enum.TextYAlignment.Top
pageDescription.ZIndex = 109

local actionList = Instance.new("ScrollingFrame")
actionList.Name = "Actions"
actionList.Position = UDim2.fromOffset(18, 146)
actionList.Size = UDim2.new(1, -36, 1, -164)
actionList.BackgroundTransparency = 1
actionList.BorderSizePixel = 0
actionList.ScrollBarThickness = 8
actionList.ScrollBarImageColor3 = COLORS.cyan
actionList.CanvasSize = UDim2.fromOffset(0, 0)
actionList.AutomaticCanvasSize = Enum.AutomaticSize.Y
actionList.ZIndex = 109
actionList.Parent = contentPanel
local actionLayout = Instance.new("UIListLayout")
actionLayout.Padding = UDim.new(0, 12)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actionList

local terminalOpen = false
local currentPage = "Home"
local currentSnapshot = nil
local firstSelectable = nil
local compactLayout = false
local narrowPortrait = false
local TERMINAL_MOVEMENT_ACTION = "CooperBunkerTerminalMovement"
local TERMINAL_MOVEMENT_PRIORITY = Enum.ContextActionPriority.High.Value + 200
local terminalMovementBound = false

local function bindTerminalMovementSink()
	if terminalMovementBound then
		return
	end
	terminalMovementBound = true
	ContextActionService:BindActionAtPriority(
		TERMINAL_MOVEMENT_ACTION,
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		TERMINAL_MOVEMENT_PRIORITY,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
end

local function unbindTerminalMovementSink()
	if terminalMovementBound then
		ContextActionService:UnbindAction(TERMINAL_MOVEMENT_ACTION)
		terminalMovementBound = false
	end
end

local function clearActions()
	firstSelectable = nil
	for _, child in ipairs(actionList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function actionButton(titleText, detailText, accent, callback, enabled)
	local rowHeight = if narrowPortrait then 142 elseif compactLayout then 108 else 104
	local titleHeight = if narrowPortrait then 42 elseif compactLayout then 34 else 32
	local detailY = if narrowPortrait then 56 elseif compactLayout then 49 else 48
	local row = button(actionList, "Action", "", UDim2.new(1, -4, 0, rowHeight), UDim2.fromScale(0, 0), accent)
	row.AutoButtonColor = enabled ~= false
	row.Active = enabled ~= false
	row.Selectable = enabled ~= false
	row.BackgroundColor3 = enabled == false and Color3.fromRGB(12, 23, 29) or Color3.fromRGB(7, 35, 47)
	row.BackgroundTransparency = enabled == false and 0.25 or 0.02
	row.ZIndex = 110
	local rowTitle = label(row, "Title", titleText, UDim2.new(1, -30, 0, titleHeight), UDim2.fromOffset(15, 9), Enum.Font.GothamBold, compactLayout and 16 or 19, enabled == false and COLORS.muted or COLORS.white)
	rowTitle.TextYAlignment = Enum.TextYAlignment.Top
	rowTitle.ZIndex = 111
	local rowDetail = label(row, "Detail", detailText, UDim2.new(1, -30, 0, rowHeight - detailY - 9), UDim2.fromOffset(15, detailY), Enum.Font.GothamMedium, compactLayout and 12 or 14, enabled == false and Color3.fromRGB(83, 117, 127) or accent)
	rowDetail.TextYAlignment = Enum.TextYAlignment.Top
	rowDetail.ZIndex = 111
	if enabled ~= false and callback then
		row.Activated:Connect(callback)
		if not firstSelectable then
			firstSelectable = row
		end
	end
	return row
end

local render
local closeTerminal
local function chemistrySnapshot()
	local chemistry = currentSnapshot and currentSnapshot.chemistrySetup
	return type(chemistry) == "table" and chemistry or {}
end

local function chemistryStatusText(chemistry)
	local status = tostring(chemistry.status or "Loading")
	if chemistry.placed == true or chemistry.installed == true or status == "Installed" then
		return "INSTALLED / ONLINE", COLORS.green
	elseif status == "WaitingDelivery" then
		return "TRUCK EN ROUTE", COLORS.amber
	elseif status == "Collect" then
		return "PICK UP IN DRIVEWAY", COLORS.amber
	elseif status == "Install" or status == "Carried" then
		return "CARRY TO BUNKER BAY", COLORS.violet
	elseif chemistry.bunkerUnlocked ~= true then
		return "BUNKER REQUIRED", COLORS.red
	end
	return "AVAILABLE TO BUY", COLORS.cyan
end

render = function()
	clearActions()
	local snapshot = currentSnapshot or {}
	local chemistry = chemistrySnapshot()
	local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
	local price = math.max(1, math.floor(tonumber(chemistry.price) or 1800))
	local statusText, statusColor = chemistryStatusText(chemistry)
	allowanceValue.Text = "$" .. tostring(allowance)
	labStatusValue.Text = statusText
	labStatusValue.TextColor3 = statusColor
	labPrice.Text = "PRICE: $" .. tostring(price)
	bunkerStatus.Text = chemistry.bunkerUnlocked == false and "● BUNKER ACCESS REQUIRED" or "● BUNKER LINK ONLINE"
	bunkerStatus.TextColor3 = chemistry.bunkerUnlocked == false and COLORS.red or COLORS.green
	diagnostic.Text = chemistry.placed == true
		and [[CORE TEMP     36.4 C
POWER BUS     STABLE
AIR HANDLING  NOMINAL
DATA LINK     SECURE
CHEM BUS      FLOWING]]
		or [[CORE TEMP     34.8 C
POWER BUS     STABLE
AIR HANDLING  NOMINAL
DATA LINK     SECURE
CHEM BUS      STANDBY]]

	backButton.Visible = currentPage ~= "Home"
	if currentPage == "Home" then
		pageTitle.Text = "RESEARCH PROCUREMENT"
		pageDescription.Text = "Choose a bunker system. The advanced chemistry setup is the first piece of the underground research operation."
		actionButton(
			"Advanced Chemistry Setup",
			statusText .. "  •  $" .. tostring(price),
			statusColor,
			function()
				currentPage = "Chemistry"
				render()
			end,
			true
		)
	else
		pageTitle.Text = "ADVANCED CHEMISTRY SETUP"
		pageDescription.Text = "A complete bunker laboratory with real glassware, connected pipes and tubes, pressure pumps, illuminated controls, and a reactor that crystallizes collectible Blue Rock Candy."
		if chemistry.placed == true or chemistry.installed == true then
			actionButton(
				"Chemistry Lab Installed",
				"The laboratory is online. Choose Do Chemistry, watch the reaction, then collect and equip the Blue Rock Candy from its output drawer.",
				COLORS.green,
				nil,
				false
			)
		elseif chemistry.purchased == true then
			local deliveryStatus = tostring(chemistry.status or "WaitingDelivery")
			local detail = if deliveryStatus == "Collect"
				then "Your reinforced research case is waiting in the driveway. Pick it up and carry it through the bunker hatch."
				elseif deliveryStatus == "Install" or deliveryStatus == "Carried"
					then "Follow the cyan-and-violet arrow to the chemistry bay. The lab assembles automatically when you enter the marked pad."
					else "The equipment truck is bringing your research case to the driveway now."
			actionButton("Chemistry Setup Ordered", detail, COLORS.amber, nil, false)
		elseif chemistry.bunkerUnlocked ~= true then
			actionButton(
				"Unlock the Secret Bunker First",
				"The chemistry lab can only be ordered from a completed personal bunker.",
				COLORS.red,
				nil,
				false
			)
		elseif chemistry.canOrder == true and allowance >= price then
			actionButton(
				"Buy Advanced Chemistry Setup — $" .. tostring(price),
				"Pay once, then meet the delivery truck in the driveway and carry the compact research case to the bunker lab bay.",
				COLORS.cyan,
				function()
					requestEvent:FireServer("OrderChemistrySetup")
				end,
				true
			)
		elseif allowance < price then
			actionButton(
				"Need $" .. tostring(price - allowance) .. " More",
				"Complete family tasks, bank hacks, or boombox sessions, then return to this bunker computer.",
				COLORS.red,
				nil,
				false
			)
		else
			actionButton(
				"Finish the Current Delivery",
				"Only one owner-locked truck delivery is handled at a time. Finish setting up the item already in progress.",
				COLORS.amber,
				nil,
				false
			)
		end
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = firstSelectable
			or (backButton.Visible and backButton)
			or closeButton
	end
end

closeTerminal = function(notifyServer)
	local wasOpen = terminalOpen
	terminalOpen = false
	unbindTerminalMovementSink()
	shade.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(shade) then
		GuiService.SelectedObject = nil
	end
	if notifyServer ~= false and wasOpen then
		requestEvent:FireServer("CloseBunkerComputer")
	end
end

local function openTerminal()
	currentPage = "Home"
	terminalOpen = true
	shade.Visible = true
	bindTerminalMovementSink()
	render()
	requestEvent:FireServer("RequestSnapshot")
end

closeButton.Activated:Connect(function()
	closeTerminal(true)
end)
backButton.Activated:Connect(function()
	currentPage = "Home"
	render()
end)
UserInputService.InputBegan:Connect(function(input)
	if not terminalOpen then
		return
	end
	if input.KeyCode == Enum.KeyCode.ButtonB then
		if currentPage == "Home" then
			closeTerminal(true)
		else
			currentPage = "Home"
			render()
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		closeTerminal(true)
	end
end)

player.CharacterRemoving:Connect(function()
	closeTerminal(false)
end)

gui.Destroying:Connect(function()
	terminalOpen = false
	unbindTerminalMovementSink()
end)

script.Destroying:Connect(unbindTerminalMovementSink)

local function updateLayout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local safeSize = shade.AbsoluteSize
	local safeWidth = safeSize.X > 1 and safeSize.X or viewport.X
	local safeHeight = safeSize.Y > 1 and safeSize.Y or viewport.Y
	compactLayout = safeHeight < 680 or safeWidth < 900
	narrowPortrait = safeWidth < 620 and safeHeight > safeWidth
	if compactLayout then
		panel.Size = UDim2.new(1, -16, 1, -12)
		header.Position = UDim2.fromOffset(8, 6)
		header.Size = UDim2.new(1, -16, 0, 54)
		title.Position = UDim2.fromOffset(10, 5)
		title.Size = UDim2.new(1, -132, 0, 27)
		title.Text = "COOPER LABNET"
		title.TextSize = 16
		subtitle.Position = UDim2.fromOffset(10, 30)
		subtitle.Size = UDim2.new(1, -132, 0, 17)
		subtitle.Text = "BUNKER RESEARCH CORE • ONLINE"
		subtitle.TextSize = 9
		closeButton.Size = UDim2.fromOffset(108, 44)
		closeButton.Position = UDim2.new(1, -116, 0, 5)
		if narrowPortrait then
			statusPanel.Position = UDim2.fromOffset(8, 66)
			statusPanel.Size = UDim2.new(1, -16, 0, 126)
			statusHeader.Position = UDim2.fromOffset(12, 7)
			statusHeader.Size = UDim2.new(0.43, -12, 0, 20)
			statusHeader.TextSize = 12
			allowanceTitle.Position = UDim2.fromOffset(12, 34)
			allowanceTitle.Size = UDim2.new(0.43, -12, 0, 15)
			allowanceTitle.TextSize = 9
			allowanceValue.Position = UDim2.fromOffset(12, 50)
			allowanceValue.Size = UDim2.new(0.43, -12, 0, 36)
			allowanceValue.TextSize = 25
			bunkerStatus.Position = UDim2.new(0.45, 0, 0, 8)
			bunkerStatus.Size = UDim2.new(0.55, -12, 0, 24)
			bunkerStatus.TextSize = 10
			labStatusTitle.Position = UDim2.new(0.45, 0, 0, 37)
			labStatusTitle.Size = UDim2.new(0.55, -12, 0, 16)
			labStatusTitle.TextSize = 9
			labStatusValue.Position = UDim2.new(0.45, 0, 0, 54)
			labStatusValue.Size = UDim2.new(0.55, -12, 0, 38)
			labStatusValue.TextSize = 15
			labPrice.Position = UDim2.fromOffset(12, 96)
			labPrice.Size = UDim2.new(1, -24, 0, 18)
			labPrice.TextSize = 11
			diagnostic.Visible = false
			statusHint.Visible = false
			contentPanel.Position = UDim2.fromOffset(8, 200)
			contentPanel.Size = UDim2.new(1, -16, 1, -208)
			pageTitle.Position = UDim2.fromOffset(14, 9)
			pageTitle.Size = UDim2.new(1, -146, 0, 40)
			pageTitle.TextSize = 15
			pageDescription.Position = UDim2.fromOffset(14, 52)
			pageDescription.Size = UDim2.new(1, -28, 0, 64)
			pageDescription.TextSize = 12
			actionList.Position = UDim2.fromOffset(14, 122)
			actionList.Size = UDim2.new(1, -28, 1, -134)
		else
			statusPanel.Position = UDim2.fromOffset(8, 66)
			statusPanel.Size = UDim2.new(0, 210, 1, -74)
			statusHeader.Position = UDim2.fromOffset(12, 7)
			statusHeader.Size = UDim2.new(1, -24, 0, 18)
			statusHeader.TextSize = 12
			allowanceTitle.Position = UDim2.fromOffset(12, 29)
			allowanceTitle.Size = UDim2.new(1, -24, 0, 12)
			allowanceTitle.TextSize = 9
			allowanceValue.Position = UDim2.fromOffset(12, 41)
			allowanceValue.Size = UDim2.new(1, -24, 0, 28)
			allowanceValue.TextSize = 22
			bunkerStatus.Position = UDim2.fromOffset(12, 74)
			bunkerStatus.Size = UDim2.new(1, -24, 0, 30)
			bunkerStatus.TextSize = 9
			labStatusTitle.Position = UDim2.fromOffset(12, 108)
			labStatusTitle.Size = UDim2.new(1, -24, 0, 13)
			labStatusTitle.TextSize = 9
			labStatusValue.Position = UDim2.fromOffset(12, 122)
			labStatusValue.Size = UDim2.new(1, -24, 0, 38)
			labStatusValue.TextSize = 15
			labPrice.Position = UDim2.fromOffset(12, 168)
			labPrice.Size = UDim2.new(1, -24, 0, 18)
			labPrice.TextSize = 11
			diagnostic.Visible = false
			statusHint.Visible = false
			contentPanel.Position = UDim2.fromOffset(226, 66)
			contentPanel.Size = UDim2.new(1, -234, 1, -74)
			pageTitle.Position = UDim2.fromOffset(14, 8)
			pageTitle.Size = UDim2.new(1, -142, 0, 34)
			pageTitle.TextSize = 15
			pageDescription.Position = UDim2.fromOffset(14, 45)
			pageDescription.Size = UDim2.new(1, -28, 0, 48)
			pageDescription.TextSize = 11
			actionList.Position = UDim2.fromOffset(14, 99)
			actionList.Size = UDim2.new(1, -28, 1, -111)
		end
		backButton.Size = UDim2.fromOffset(narrowPortrait and 108 or 112, 44)
		backButton.Position = UDim2.new(1, narrowPortrait and -120 or -124, 0, 6)
	else
		panel.Size = UDim2.fromOffset(math.min(1000, safeWidth - 40), math.min(650, safeHeight - 24))
		header.Position = UDim2.fromOffset(12, 10)
		header.Size = UDim2.new(1, -24, 0, 64)
		title.Position = UDim2.fromOffset(16, 7)
		title.Size = UDim2.new(1, -166, 0, 30)
		title.Text = "COOPER RESEARCH CORE // LABNET"
		title.TextSize = 20
		subtitle.Position = UDim2.fromOffset(16, 38)
		subtitle.Size = UDim2.new(1, -166, 0, 18)
		subtitle.Text = "UNDERGROUND PROCUREMENT CHANNEL  •  ENCRYPTED  •  ONLINE"
		subtitle.TextSize = 11
		closeButton.Size = UDim2.fromOffset(124, 46)
		closeButton.Position = UDim2.new(1, -138, 0, 9)
		statusPanel.Position = UDim2.fromOffset(12, 84)
		statusPanel.Size = UDim2.new(0, 298, 1, -96)
		statusHeader.Position = UDim2.fromOffset(14, 13)
		statusHeader.Size = UDim2.new(1, -28, 0, 28)
		statusHeader.TextSize = 16
		allowanceTitle.Position = UDim2.fromOffset(14, 58)
		allowanceTitle.Size = UDim2.new(1, -28, 0, 20)
		allowanceTitle.TextSize = 11
		allowanceValue.Position = UDim2.fromOffset(14, 77)
		allowanceValue.Size = UDim2.new(1, -28, 0, 44)
		allowanceValue.TextSize = 32
		bunkerStatus.Position = UDim2.fromOffset(14, 136)
		bunkerStatus.Size = UDim2.new(1, -28, 0, 28)
		bunkerStatus.TextSize = 13
		labStatusTitle.Position = UDim2.fromOffset(14, 188)
		labStatusTitle.Size = UDim2.new(1, -28, 0, 20)
		labStatusTitle.TextSize = 11
		labStatusValue.Position = UDim2.fromOffset(14, 211)
		labStatusValue.Size = UDim2.new(1, -28, 0, 56)
		labStatusValue.TextSize = 22
		labPrice.Position = UDim2.fromOffset(14, 276)
		labPrice.Size = UDim2.new(1, -28, 0, 28)
		labPrice.TextSize = 14
		diagnostic.Visible = true
		diagnostic.Position = UDim2.fromOffset(14, 322)
		diagnostic.Size = UDim2.new(1, -28, 0, 126)
		diagnostic.TextSize = 13
		statusHint.Visible = true
		statusHint.Position = UDim2.new(0, 14, 1, -76)
		statusHint.Size = UDim2.new(1, -28, 0, 62)
		contentPanel.Position = UDim2.fromOffset(322, 84)
		contentPanel.Size = UDim2.new(1, -334, 1, -98)
		pageTitle.Position = UDim2.fromOffset(18, 14)
		pageTitle.Size = UDim2.new(1, -184, 0, 34)
		pageTitle.TextSize = 19
		pageDescription.Position = UDim2.fromOffset(18, 58)
		pageDescription.Size = UDim2.new(1, -36, 0, 82)
		pageDescription.TextSize = 15
		actionList.Position = UDim2.fromOffset(18, 146)
		actionList.Size = UDim2.new(1, -36, 1, -164)
		backButton.Size = UDim2.fromOffset(142, 44)
		backButton.Position = UDim2.new(1, -156, 0, 10)
	end
	if terminalOpen then
		render()
	end
end

local cameraConnection = nil
local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
	end
	updateLayout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
bindCamera()

snapshotEvent.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" or snapshot.loaded == false then
		return
	end
	currentSnapshot = snapshot
	if terminalOpen then
		render()
	end
end)

feedbackEvent.OnClientEvent:Connect(function(packet)
	if type(packet) ~= "table" then
		return
	end
	local kind = tostring(packet.kind or "")
	if kind == "BunkerTerminalClose" then
		closeTerminal(false)
	end
end)

bunkerEvent.OnClientEvent:Connect(function(action, value)
	if action == "Notice" then
		showNotice(value, COLORS.amber, 4)
	elseif action == "TerminalOpen" then
		openTerminal()
	elseif action == "TerminalClose" then
		closeTerminal(false)
	end
end)

requestEvent:FireServer("RequestSnapshot")
print("[CooperBunker] High-tech research terminal and responsive chemistry UI ready v" .. CLIENT_VERSION)
