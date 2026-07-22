--!nonstrict
-- Shared-party task HUD, personal allowance/objectives, button-driven computer,
-- hidden clues, ground guidance, and per-player Time Machine presentation.
-- Installed as StarterPlayer.StarterPlayerScripts.CooperGame.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local root = game:GetService("ReplicatedStorage"):WaitForChild("CooperGame", 30)
if not root then
	return
end
local Config = require(root:WaitForChild("Config", 10))
local remotes = root:WaitForChild("Remotes", 10)
local snapshotEvent = remotes:WaitForChild("Snapshot", 10)
local feedbackEvent = remotes:WaitForChild("Feedback", 10)
local requestEvent = remotes:WaitForChild("Request", 10)
local bankHackEvent = remotes:WaitForChild("BankHack", 10)
if not snapshotEvent or not feedbackEvent or not requestEvent or not bankHackEvent then
	return
end

local old = playerGui:FindFirstChild("CooperGameHUD")
if old then
	old:Destroy()
end

local COLORS = {
	panel = Color3.fromRGB(31, 36, 40),
	panelLight = Color3.fromRGB(49, 57, 62),
	cream = Color3.fromRGB(249, 239, 207),
	white = Color3.fromRGB(248, 248, 242),
	muted = Color3.fromRGB(185, 192, 190),
	green = Color3.fromRGB(86, 205, 123),
	yellow = Color3.fromRGB(246, 195, 66),
	blue = Color3.fromRGB(74, 151, 222),
	orange = Color3.fromRGB(235, 119, 61),
	purple = Color3.fromRGB(170, 105, 220),
	red = Color3.fromRGB(218, 63, 59),
	terminal = Color3.fromRGB(91, 255, 137),
}

local requesterColors = {
	George = COLORS.orange,
	Mary = COLORS.green,
	Missy = COLORS.purple,
	Georgie = COLORS.yellow,
	Terminal = COLORS.terminal,
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 8)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color or COLORS.cream
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0
	item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	item.Parent = parent
	return item
end

local function label(parent, name, text, size, position, font, textSize, color, alignment)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Size = size
	item.Position = position or UDim2.fromScale(0, 0)
	item.Text = text or ""
	item.TextColor3 = color or COLORS.white
	item.Font = font or Enum.Font.GothamMedium
	item.TextSize = textSize or 16
	item.TextWrapped = true
	item.TextXAlignment = alignment or Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local function button(parent, name, text, size, position, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color or COLORS.panelLight
	item.Text = text
	item.TextColor3 = COLORS.white
	item.Font = Enum.Font.GothamBold
	item.TextSize = 16
	item.TextWrapped = true
	item.TextStrokeTransparency = 1
	item.AutoButtonColor = true
	item.Parent = parent
	corner(item, 9)
	local border = stroke(item, COLORS.cream, 1, 0.55)
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperGameHUD"
gui.DisplayOrder = 35
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ClipToDeviceSafeArea = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local scaleRoot = Instance.new("Frame")
scaleRoot.Name = "ScaledRoot"
scaleRoot.AnchorPoint = Vector2.new(0.5, 0)
scaleRoot.Position = UDim2.fromScale(0.5, 0)
scaleRoot.Size = UDim2.fromOffset(1280, 720)
scaleRoot.BackgroundTransparency = 1
scaleRoot.Parent = gui
local uiScale = Instance.new("UIScale")
uiScale.Parent = scaleRoot

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.fromOffset(920, 78)
topBar.BackgroundColor3 = COLORS.panel
topBar.BackgroundTransparency = 0.04
topBar.Parent = scaleRoot
corner(topBar, 12)
stroke(topBar, COLORS.cream, 2, 0.25)

local allowanceTitle = label(topBar, "AllowanceTitle", "MY ALLOWANCE", UDim2.fromOffset(190, 20), UDim2.fromOffset(20, 10), Enum.Font.GothamBold, 13, COLORS.cream)
local allowanceValue = label(topBar, "AllowanceValue", "$0", UDim2.fromOffset(190, 36), UDim2.fromOffset(20, 31), Enum.Font.GothamBlack, 28, COLORS.yellow)
local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(225, 12)
divider.Size = UDim2.fromOffset(2, 54)
divider.BackgroundColor3 = COLORS.cream
divider.BackgroundTransparency = 0.7
divider.Parent = topBar
local machineTitle = label(topBar, "MachineTitle", "SHARED TIME MACHINE • 0%", UDim2.fromOffset(650, 24), UDim2.fromOffset(250, 8), Enum.Font.GothamBlack, 17, COLORS.cream)
local machineStage = label(topBar, "MachineStage", "Blueprint Pending", UDim2.fromOffset(650, 22), UDim2.fromOffset(250, 31), Enum.Font.GothamMedium, 14, COLORS.blue)
local machineTrack = Instance.new("Frame")
machineTrack.Position = UDim2.fromOffset(250, 58)
machineTrack.Size = UDim2.fromOffset(650, 10)
machineTrack.BackgroundColor3 = Color3.fromRGB(15, 18, 20)
machineTrack.Parent = topBar
corner(machineTrack, 5)
local machineFill = Instance.new("Frame")
machineFill.Size = UDim2.fromScale(0, 1)
machineFill.BackgroundColor3 = COLORS.blue
machineFill.Parent = machineTrack
corner(machineFill, 5)
local taskPanel = Instance.new("Frame")
taskPanel.Name = "CurrentTask"
taskPanel.Position = UDim2.fromOffset(18, 112)
taskPanel.Size = UDim2.fromOffset(390, 245)
taskPanel.BackgroundColor3 = COLORS.panel
taskPanel.BackgroundTransparency = 0.05
taskPanel.Parent = scaleRoot
corner(taskPanel, 12)
local taskStroke = stroke(taskPanel, COLORS.green, 2, 0.15)
local taskRequester = label(taskPanel, "Requester", "SHARED FAMILY TASK", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 12), Enum.Font.GothamBold, 13, COLORS.green)
local taskTitle = label(taskPanel, "Title", "WAITING FOR A REQUEST", UDim2.new(1, -28, 0, 50), UDim2.fromOffset(14, 39), Enum.Font.GothamBlack, 20, COLORS.white)
local taskDescription = label(taskPanel, "Description", "Explore the Cooper house. Someone will need help soon.", UDim2.new(1, -28, 0, 88), UDim2.fromOffset(14, 91), Enum.Font.GothamMedium, 15, COLORS.muted)
taskDescription.TextYAlignment = Enum.TextYAlignment.Top
local taskReward = label(taskPanel, "Reward", "", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 204), Enum.Font.GothamBold, 14, COLORS.yellow)

-- Chemistry sales belong to one player, while the five family tasks are
-- shared by the whole party. Give the personal sale its own compact card so it
-- can never replace or hide the authoritative shared-task card.
do
local personalObjectiveUi = {}
personalObjectiveUi.frame = Instance.new("Frame")
personalObjectiveUi.frame.Name = "PersonalObjectiveChip"
personalObjectiveUi.frame.Position = UDim2.fromOffset(18, 369)
personalObjectiveUi.frame.Size = UDim2.fromOffset(390, 94)
personalObjectiveUi.frame.BackgroundColor3 = Color3.fromRGB(43, 36, 12)
personalObjectiveUi.frame.BackgroundTransparency = 0.04
personalObjectiveUi.frame.Visible = false
personalObjectiveUi.frame.Parent = scaleRoot
corner(personalObjectiveUi.frame, 10)
personalObjectiveUi.stroke = stroke(personalObjectiveUi.frame, COLORS.yellow, 2, 0.12)
personalObjectiveUi.title = label(
	personalObjectiveUi.frame,
	"Title",
	"MY OBJECTIVE • LOS POLLOS PICKUP",
	UDim2.new(1, -24, 0, 24),
	UDim2.fromOffset(12, 8),
	Enum.Font.GothamBlack,
	14,
	COLORS.yellow
)
personalObjectiveUi.text = label(
	personalObjectiveUi.frame,
	"Text",
	"",
	UDim2.new(1, -24, 0, 54),
	UDim2.fromOffset(12, 34),
	Enum.Font.GothamMedium,
	13,
	COLORS.cream
)
end

local deliveryChip = Instance.new("Frame")
deliveryChip.Name = "DeliveryChip"
deliveryChip.Position = UDim2.fromOffset(18, 369)
deliveryChip.Size = UDim2.fromOffset(390, 94)
deliveryChip.BackgroundColor3 = COLORS.panel
deliveryChip.BackgroundTransparency = 0.05
deliveryChip.Visible = false
deliveryChip.Parent = scaleRoot
corner(deliveryChip, 10)
local deliveryStroke = stroke(deliveryChip, COLORS.blue, 2, 0.2)
local deliveryTitle = label(deliveryChip, "Title", "COMPONENT DELIVERY", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), Enum.Font.GothamBlack, 14, COLORS.blue)
local deliveryText = label(deliveryChip, "Text", "", UDim2.new(1, -24, 0, 54), UDim2.fromOffset(12, 34), Enum.Font.GothamMedium, 13, COLORS.cream)

local toast = Instance.new("Frame")
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -22)
toast.Size = UDim2.fromOffset(570, 76)
toast.BackgroundColor3 = COLORS.panel
toast.Visible = false
toast.Parent = scaleRoot
corner(toast, 12)
local toastStroke = stroke(toast, COLORS.green, 2, 0.15)
local toastTitle = label(toast, "Title", "", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 8), Enum.Font.GothamBlack, 17, COLORS.green, Enum.TextXAlignment.Center)
local toastText = label(toast, "Text", "", UDim2.new(1, -28, 0, 29), UDim2.fromOffset(14, 38), Enum.Font.GothamMedium, 14, COLORS.white, Enum.TextXAlignment.Center)
local toastToken = 0

-- If the host disconnects, the server freezes every shared mutation for a
-- short reconnect window. This card remains visible for that whole window and
-- counts down locally between snapshots, so guests never mistake a paused
-- prompt or purchase for a broken one.
do
local partyPauseUi = {}
partyPauseUi.frame = Instance.new("Frame")
partyPauseUi.frame.Name = "PartyReconnectPause"
partyPauseUi.frame.AnchorPoint = Vector2.new(0.5, 0)
partyPauseUi.frame.Position = UDim2.new(0.5, 0, 0, 100)
partyPauseUi.frame.Size = UDim2.fromOffset(520, 88)
partyPauseUi.frame.BackgroundColor3 = Color3.fromRGB(39, 22, 12)
partyPauseUi.frame.BackgroundTransparency = 0.02
partyPauseUi.frame.BorderSizePixel = 0
partyPauseUi.frame.Visible = false
partyPauseUi.frame.ZIndex = 90
partyPauseUi.frame.Parent = scaleRoot
corner(partyPauseUi.frame, 12)
partyPauseUi.stroke = stroke(partyPauseUi.frame, COLORS.orange, 3, 0)
partyPauseUi.title = label(
	partyPauseUi.frame,
	"Title",
	"GAME PAUSED • HOST RECONNECTING",
	UDim2.new(1, -28, 0, 29),
	UDim2.fromOffset(14, 9),
	Enum.Font.GothamBlack,
	18,
	COLORS.orange,
	Enum.TextXAlignment.Center
)
partyPauseUi.title.ZIndex = 91
partyPauseUi.text = label(
	partyPauseUi.frame,
	"Text",
	"Shared tasks and purchases are safely paused.",
	UDim2.new(1, -28, 0, 38),
	UDim2.fromOffset(14, 42),
	Enum.Font.GothamBold,
	13,
	COLORS.white,
	Enum.TextXAlignment.Center
)
partyPauseUi.text.ZIndex = 91
end

local function showToast(titleText, detailText, color, duration)
	toastToken += 1
	local token = toastToken
	local accent = color or COLORS.green
	toastTitle.Text = tostring(titleText or "COOPER HOUSE")
	toastText.Text = tostring(detailText or "")
	toastTitle.TextColor3 = accent
	toastStroke.Color = accent
	toast.Visible = true
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 0.03 }):Play()
	task.delay(duration or 3.2, function()
		if token ~= toastToken then
			return
		end
		local tween = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

-- Goal introduction ----------------------------------------------------------

local introScrim = Instance.new("Frame")
introScrim.Size = UDim2.fromScale(1, 1)
introScrim.BackgroundColor3 = Color3.new(0, 0, 0)
introScrim.BackgroundTransparency = 0.35
introScrim.Visible = false
introScrim.ZIndex = 80
introScrim.Parent = gui
local introCard = Instance.new("Frame")
introCard.AnchorPoint = Vector2.new(0.5, 0.5)
introCard.Position = UDim2.fromScale(0.5, 0.5)
introCard.Size = UDim2.fromOffset(650, 360)
introCard.BackgroundColor3 = COLORS.panel
introCard.ZIndex = 81
introCard.Parent = introScrim
corner(introCard, 16)
stroke(introCard, COLORS.blue, 3, 0)
local introTitle = label(introCard, "Title", "YOUR GOAL: BUILD THE TIME MACHINE", UDim2.new(1, -50, 0, 62), UDim2.fromOffset(25, 22), Enum.Font.GothamBlack, 25, COLORS.blue, Enum.TextXAlignment.Center)
introTitle.ZIndex = 82
local introBody = label(
	introCard,
	"Body",
	"Work together on George, Mary, and Missy's shared requests. Every present player earns the reward as personal allowance." .. string.char(10) .. string.char(10) .. "The party host uses Sheldon's computer to buy shared upgrades and Time Machine components. Everyone can help with tasks." .. string.char(10) .. string.char(10) .. "Reach 100% construction to finish the shared machine.",
	UDim2.new(1, -70, 0, 205),
	UDim2.fromOffset(35, 90),
	Enum.Font.GothamMedium,
	17,
	COLORS.cream,
	Enum.TextXAlignment.Center
)
introBody.ZIndex = 82
local introButton = button(introCard, "Start", "START BUILDING", UDim2.fromOffset(230, 50), UDim2.new(0.5, -115, 1, -70), COLORS.blue)
introButton.ZIndex = 82

-- Upgrade affordability has its own high-Z banner instead of borrowing the
-- single-slot activity toast. Task-complete and bank-transfer messages can then
-- remain visible while this independent notice tells the player what their new
-- allowance can buy.
local upgradeNoticeUi = {
	token = 0,
	entries = {},
	announced = {},
}
upgradeNoticeUi.playerControls = nil
upgradeNoticeUi.controlsLocked = false
upgradeNoticeUi.compactLayout = false
upgradeNoticeUi.terminalVisible = false
function upgradeNoticeUi.setControlsLocked(locked)
	locked = locked == true
	if upgradeNoticeUi.controlsLocked == locked then
		return
	end
	if locked and not upgradeNoticeUi.playerControls then
		local success, controls = pcall(function()
			return require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
		end)
		if success then
			upgradeNoticeUi.playerControls = controls
		end
	end
	if upgradeNoticeUi.playerControls then
		if locked then
			if player.Character then
				upgradeNoticeUi.playerControls:Disable()
			end
			-- Keep the modal lock authoritative across a reset. PlayerModule can
			-- recreate its character controls while the tutorial/computer is still
			-- open, so every new character must inherit the same disabled state.
			if not upgradeNoticeUi.characterLockConnection then
				upgradeNoticeUi.characterLockConnection = player.CharacterAdded:Connect(function()
					task.defer(function()
						if upgradeNoticeUi.controlsLocked and upgradeNoticeUi.playerControls then
							upgradeNoticeUi.playerControls:Disable()
						end
					end)
				end)
			end
		else
			if upgradeNoticeUi.characterLockConnection then
				upgradeNoticeUi.characterLockConnection:Disconnect()
				upgradeNoticeUi.characterLockConnection = nil
			end
			upgradeNoticeUi.playerControls:Enable()
		end
	end
	upgradeNoticeUi.controlsLocked = locked
end
introButton.Activated:Connect(function()
	introScrim.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(introScrim) then
		GuiService.SelectedObject = nil
	end
	gui.DisplayOrder = upgradeNoticeUi.terminalVisible and 65 or 35
	upgradeNoticeUi.setControlsLocked(upgradeNoticeUi.terminalVisible)
	requestEvent:FireServer("TutorialSeen")
end)
upgradeNoticeUi.frame = Instance.new("Frame")
upgradeNoticeUi.frame.Name = "UpgradeAffordableNotice"
upgradeNoticeUi.frame.AnchorPoint = Vector2.new(1, 0)
upgradeNoticeUi.frame.Position = UDim2.new(1, 40, 0, 108)
upgradeNoticeUi.frame.Size = UDim2.fromOffset(580, 184)
upgradeNoticeUi.frame.BackgroundColor3 = Color3.fromRGB(34, 29, 13)
upgradeNoticeUi.frame.BackgroundTransparency = 0.03
upgradeNoticeUi.frame.BorderSizePixel = 0
upgradeNoticeUi.frame.Visible = false
-- Persistent HUD notices stay above the ordinary task card but below the
-- computer's ZIndex 60 modal. This prevents a ten-second affordability card
-- from covering terminal choices or the compact phone BANKLINK keyboard.
upgradeNoticeUi.frame.ZIndex = 50
upgradeNoticeUi.frame.Parent = scaleRoot
corner(upgradeNoticeUi.frame, 12)
stroke(upgradeNoticeUi.frame, COLORS.yellow, 3, 0)
upgradeNoticeUi.title = label(
	upgradeNoticeUi.frame,
	"Title",
	"PURCHASE NOW AFFORDABLE!",
	UDim2.new(1, -28, 0, 27),
	UDim2.fromOffset(14, 10),
	Enum.Font.GothamBlack,
	20,
	COLORS.yellow
)
upgradeNoticeUi.title.ZIndex = 51
upgradeNoticeUi.text = label(
	upgradeNoticeUi.frame,
	"Text",
	"",
	UDim2.new(1, -28, 0, 94),
	UDim2.fromOffset(14, 39),
	Enum.Font.GothamBold,
	15,
	COLORS.white
)
upgradeNoticeUi.text.TextYAlignment = Enum.TextYAlignment.Top
upgradeNoticeUi.text.ZIndex = 51
upgradeNoticeUi.hint = label(
	upgradeNoticeUi.frame,
	"Hint",
	"Use Sheldon's computer to buy it.",
	UDim2.new(1, -28, 0, 38),
	UDim2.fromOffset(14, 140),
	Enum.Font.GothamMedium,
	13,
	COLORS.cream
)
upgradeNoticeUi.hint.ZIndex = 51

function upgradeNoticeUi.show(entries)
	for _, entry in ipairs(entries) do
		if type(entry) == "table" and type(entry.key) == "string" then
			upgradeNoticeUi.entries[entry.key] = entry
		end
	end
	local ordered = {}
	for _, entry in pairs(upgradeNoticeUi.entries) do
		table.insert(ordered, entry)
	end
	table.sort(ordered, function(left, right)
		local leftPrice = tonumber(left.price) or 0
		local rightPrice = tonumber(right.price) or 0
		return leftPrice == rightPrice
			and tostring(left.name) < tostring(right.name)
			or leftPrice < rightPrice
	end)
	if #ordered == 0 then
		return
	end

	upgradeNoticeUi.title.Text = #ordered == 1
		and "PURCHASE NOW AFFORDABLE!"
		or string.format("%d PURCHASES NOW AFFORDABLE!", #ordered)
	if #ordered == 1 then
		local entry = ordered[1]
		upgradeNoticeUi.text.Text = string.format("YOU CAN NOW AFFORD:  %s  •  $%d", tostring(entry.name), tonumber(entry.price) or 0)
	else
		local lines = {}
		for index = 1, #ordered, 2 do
			local line = {}
			for itemIndex = index, math.min(index + 1, #ordered) do
				local entry = ordered[itemIndex]
				table.insert(line, string.format("%s ($%d)", tostring(entry.name), tonumber(entry.price) or 0))
			end
			table.insert(lines, table.concat(line, "   •   "))
		end
		upgradeNoticeUi.text.Text = table.concat(lines, string.char(10))
	end
	local includesChemistry = false
	for _, entry in ipairs(ordered) do
		if entry.key == "ChemistrySetup" then
			includesChemistry = true
			break
		end
	end
	upgradeNoticeUi.hint.Text = if #ordered == 1 and includesChemistry
		then "YOU HAVE ENOUGH ALLOWANCE — use the high-tech research computer inside your bunker."
		elseif includesChemistry
		then "HOUSE UPGRADES USE SHELDON'S COMPUTER • CHEMISTRY USES THE BUNKER RESEARCH COMPUTER."
		else "YOU HAVE ENOUGH ALLOWANCE — choose what you want to buy on Sheldon's computer."

	upgradeNoticeUi.token += 1
	local token = upgradeNoticeUi.token
	upgradeNoticeUi.frame.Visible = true
	upgradeNoticeUi.frame.Position = UDim2.new(1, 40, 0, 108)
	upgradeNoticeUi.frame.BackgroundTransparency = 0.22
	TweenService:Create(
		upgradeNoticeUi.frame,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -18, 0, 108), BackgroundTransparency = 0.03 }
	):Play()
	task.delay(10, function()
		if token ~= upgradeNoticeUi.token then
			return
		end
		local tween = TweenService:Create(
			upgradeNoticeUi.frame,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 40, 0, 108), BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		if token == upgradeNoticeUi.token then
			upgradeNoticeUi.frame.Visible = false
			table.clear(upgradeNoticeUi.entries)
		end
	end)
end

-- Cooldown readiness has a dedicated slot so an immediate autoplay-start or
-- task-completion toast cannot erase the message the player is waiting for.
upgradeNoticeUi.readyToken = 0
upgradeNoticeUi.readyFrame = Instance.new("Frame")
upgradeNoticeUi.readyFrame.Name = "BoomboxReadyNotice"
upgradeNoticeUi.readyFrame.AnchorPoint = Vector2.new(0.5, 1)
upgradeNoticeUi.readyFrame.Position = UDim2.new(0.5, 0, 1, 35)
upgradeNoticeUi.readyFrame.Size = UDim2.fromOffset(560, 100)
upgradeNoticeUi.readyFrame.BackgroundColor3 = Color3.fromRGB(36, 19, 48)
upgradeNoticeUi.readyFrame.BackgroundTransparency = 0.02
upgradeNoticeUi.readyFrame.BorderSizePixel = 0
upgradeNoticeUi.readyFrame.Visible = false
upgradeNoticeUi.readyFrame.ZIndex = 52
upgradeNoticeUi.readyFrame.Parent = scaleRoot
corner(upgradeNoticeUi.readyFrame, 14)
stroke(upgradeNoticeUi.readyFrame, COLORS.purple, 3, 0)
upgradeNoticeUi.readyTitle = label(
	upgradeNoticeUi.readyFrame,
	"Title",
	"BOOMBOX READY TO PLAY!",
	UDim2.new(1, -28, 0, 32),
	UDim2.fromOffset(14, 10),
	Enum.Font.GothamBlack,
	21,
	COLORS.purple,
	Enum.TextXAlignment.Center
)
upgradeNoticeUi.readyTitle.ZIndex = 53
upgradeNoticeUi.readyText = label(
	upgradeNoticeUi.readyFrame,
	"Text",
	"Use the living-room power button to start the next party.",
	UDim2.new(1, -28, 0, 35),
	UDim2.fromOffset(14, 48),
	Enum.Font.GothamBold,
	14,
	COLORS.white,
	Enum.TextXAlignment.Center
)
upgradeNoticeUi.readyText.ZIndex = 53

function upgradeNoticeUi.showBoomboxReady(automatic, detailText)
	upgradeNoticeUi.readyToken += 1
	local token = upgradeNoticeUi.readyToken
	local bunkerCard = scaleRoot:FindFirstChild("SecretBunkerPhaseBanner")
	if bunkerCard and bunkerCard:IsA("GuiObject") and bunkerCard.Visible then
		TweenService:Create(
			bunkerCard,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 1, -224) }
		):Play()
	end
	upgradeNoticeUi.readyTitle.Text = "BOOMBOX READY TO PLAY!"
	upgradeNoticeUi.readyText.Text = tostring(detailText or (automatic == true
		and "Autoplay is starting the full music, lights, dancing, and allowance session."
		or "Use the living-room power button to start the next party."))
	upgradeNoticeUi.readyFrame.Visible = true
	upgradeNoticeUi.readyFrame.Position = UDim2.new(0.5, 0, 1, 35)
	upgradeNoticeUi.readyFrame.BackgroundTransparency = 0.20
	TweenService:Create(
		upgradeNoticeUi.readyFrame,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 1, -112), BackgroundTransparency = 0.02 }
	):Play()
	task.delay(7, function()
		if token ~= upgradeNoticeUi.readyToken then
			return
		end
		local tween = TweenService:Create(
			upgradeNoticeUi.readyFrame,
			TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 1, 35), BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		if token == upgradeNoticeUi.readyToken then
			upgradeNoticeUi.readyFrame.Visible = false
			local activeBunkerCard = scaleRoot:FindFirstChild("SecretBunkerPhaseBanner")
			if activeBunkerCard and activeBunkerCard:IsA("GuiObject") and activeBunkerCard.Visible then
				TweenService:Create(
					activeBunkerCard,
					TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = UDim2.new(0.5, 0, 1, -112) }
				):Play()
			end
		end
	end)
end

-- Bunker construction uses the same prominent bottom-center notification-card
-- language as the boombox-ready message, with an added progress strip.
local bunkerPhaseUi = {
	token = 0,
	watchingConstruction = false,
}
bunkerPhaseUi.frame = Instance.new("Frame")
bunkerPhaseUi.frame.Name = "SecretBunkerPhaseBanner"
bunkerPhaseUi.frame.AnchorPoint = Vector2.new(0.5, 1)
bunkerPhaseUi.frame.Position = UDim2.new(0.5, 0, 1, 35)
bunkerPhaseUi.frame.Size = UDim2.fromOffset(560, 100)
bunkerPhaseUi.frame.BackgroundColor3 = Color3.fromRGB(48, 29, 13)
bunkerPhaseUi.frame.BackgroundTransparency = 1
bunkerPhaseUi.frame.BorderSizePixel = 0
bunkerPhaseUi.frame.Visible = false
bunkerPhaseUi.frame.ZIndex = 54
bunkerPhaseUi.frame.Parent = scaleRoot
corner(bunkerPhaseUi.frame, 14)
bunkerPhaseUi.stroke = stroke(bunkerPhaseUi.frame, Color3.fromRGB(255, 157, 55), 3, 0)
bunkerPhaseUi.title = label(
	bunkerPhaseUi.frame,
	"Title",
	"BUNKER CONSTRUCTION",
	UDim2.new(1, -28, 0, 30),
	UDim2.fromOffset(14, 8),
	Enum.Font.GothamBlack,
	21,
	Color3.fromRGB(255, 173, 69),
	Enum.TextXAlignment.Center
)
bunkerPhaseUi.title.ZIndex = 55
bunkerPhaseUi.stage = label(
	bunkerPhaseUi.frame,
	"Stage",
	"CONSTRUCTION CREW ARRIVING",
	UDim2.new(1, -28, 0, 30),
	UDim2.fromOffset(14, 41),
	Enum.Font.GothamBold,
	14,
	COLORS.white,
	Enum.TextXAlignment.Center
)
bunkerPhaseUi.stage.ZIndex = 55
bunkerPhaseUi.progressBack = Instance.new("Frame")
bunkerPhaseUi.progressBack.Name = "ProgressBack"
bunkerPhaseUi.progressBack.Position = UDim2.fromOffset(18, 82)
bunkerPhaseUi.progressBack.Size = UDim2.new(1, -36, 0, 8)
bunkerPhaseUi.progressBack.BackgroundColor3 = Color3.fromRGB(9, 12, 12)
bunkerPhaseUi.progressBack.BorderSizePixel = 0
bunkerPhaseUi.progressBack.ZIndex = 55
bunkerPhaseUi.progressBack.Parent = bunkerPhaseUi.frame
corner(bunkerPhaseUi.progressBack, 5)
bunkerPhaseUi.progressFill = Instance.new("Frame")
bunkerPhaseUi.progressFill.Name = "ProgressFill"
bunkerPhaseUi.progressFill.Size = UDim2.fromScale(0, 1)
bunkerPhaseUi.progressFill.BackgroundColor3 = Color3.fromRGB(255, 149, 44)
bunkerPhaseUi.progressFill.BorderSizePixel = 0
bunkerPhaseUi.progressFill.ZIndex = 56
bunkerPhaseUi.progressFill.Parent = bunkerPhaseUi.progressBack
corner(bunkerPhaseUi.progressFill, 5)

function bunkerPhaseUi.showConstruction(stageText, progress)
	bunkerPhaseUi.watchingConstruction = true
	bunkerPhaseUi.token += 1
	bunkerPhaseUi.frame.Visible = true
	bunkerPhaseUi.title.Text = "BUNKER CONSTRUCTION"
	bunkerPhaseUi.title.TextColor3 = Color3.fromRGB(255, 173, 69)
	bunkerPhaseUi.stroke.Color = Color3.fromRGB(255, 157, 55)
	bunkerPhaseUi.stage.Text = string.upper(tostring(stageText or "CONSTRUCTION ACTIVE"))
	bunkerPhaseUi.progressFill.BackgroundColor3 = Color3.fromRGB(255, 149, 44)
	local ratio = math.clamp(tonumber(progress) or 0, 0, 1)
	TweenService:Create(
		bunkerPhaseUi.progressFill,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(ratio, 1) }
	):Play()
	local readyCard = scaleRoot:FindFirstChild("BoomboxReadyNotice")
	local targetPosition = if readyCard and readyCard:IsA("GuiObject") and readyCard.Visible
		then UDim2.new(0.5, 0, 1, -224)
		else UDim2.new(0.5, 0, 1, -112)
	if bunkerPhaseUi.frame.BackgroundTransparency >= 0.99 then
		bunkerPhaseUi.frame.Position = UDim2.new(0.5, 0, 1, 35)
		TweenService:Create(
			bunkerPhaseUi.frame,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = targetPosition, BackgroundTransparency = 0.02 }
		):Play()
	elseif bunkerPhaseUi.frame.Position ~= targetPosition then
		TweenService:Create(
			bunkerPhaseUi.frame,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = targetPosition }
		):Play()
	end
end

function bunkerPhaseUi.complete()
	if not bunkerPhaseUi.watchingConstruction and bunkerPhaseUi.frame.Visible then
		return
	end
	local wasPresented = bunkerPhaseUi.frame.Visible and bunkerPhaseUi.frame.BackgroundTransparency < 0.99
	bunkerPhaseUi.watchingConstruction = false
	bunkerPhaseUi.token += 1
	local token = bunkerPhaseUi.token
	bunkerPhaseUi.frame.Visible = true
	bunkerPhaseUi.title.Text = "BUNKER READY!"
	bunkerPhaseUi.title.TextColor3 = Color3.fromRGB(94, 238, 168)
	bunkerPhaseUi.stroke.Color = Color3.fromRGB(74, 222, 142)
	bunkerPhaseUi.stage.Text = "THE SECRET UNDERGROUND BUNKER IS READY TO ENTER."
	bunkerPhaseUi.progressFill.Size = UDim2.fromScale(1, 1)
	bunkerPhaseUi.progressFill.BackgroundColor3 = Color3.fromRGB(74, 222, 142)
	local readyCard = scaleRoot:FindFirstChild("BoomboxReadyNotice")
	local targetPosition = if readyCard and readyCard:IsA("GuiObject") and readyCard.Visible
		then UDim2.new(0.5, 0, 1, -224)
		else UDim2.new(0.5, 0, 1, -112)
	if wasPresented then
		bunkerPhaseUi.frame.BackgroundTransparency = 0.02
		TweenService:Create(
			bunkerPhaseUi.frame,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = targetPosition }
		):Play()
	else
		bunkerPhaseUi.frame.Position = UDim2.new(0.5, 0, 1, 35)
		bunkerPhaseUi.frame.BackgroundTransparency = 0.20
		TweenService:Create(
			bunkerPhaseUi.frame,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = targetPosition, BackgroundTransparency = 0.02 }
		):Play()
	end
	task.delay(7, function()
		if token ~= bunkerPhaseUi.token then
			return
		end
		local tween = TweenService:Create(
			bunkerPhaseUi.frame,
			TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 1, 35), BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		if token == bunkerPhaseUi.token then
			bunkerPhaseUi.frame.Visible = false
		end
	end)
end

task.spawn(function()
	local environment = workspace:WaitForChild("CooperHouseEnvironment", 30)
	local bunker = environment and environment:WaitForChild("BackyardBunker", 30)
	if not bunker or not bunker:IsA("Model") then
		return
	end
	local function playerIsWatchingOwnConstruction()
		return player:GetAttribute("CooperSecretBunkerPurchased") == true
			and player:GetAttribute("CooperSecretBunkerUnlocked") ~= true
			and tostring(player:GetAttribute("CooperSecretBunkerStatus") or "") == "Construction"
	end
	local function syncWorldConstruction()
		local stateName = tostring(bunker:GetAttribute("UnlockState") or "Locked")
		if stateName == "Constructing" and playerIsWatchingOwnConstruction() then
			bunkerPhaseUi.showConstruction(
				bunker:GetAttribute("ConstructionStage") or "HEAVY CONSTRUCTION ACTIVE",
				bunker:GetAttribute("ConstructionProgress") or 0
			)
		elseif (player:GetAttribute("CooperSecretBunkerUnlocked") == true or stateName == "Unlocked")
			and bunkerPhaseUi.watchingConstruction
		then
			bunkerPhaseUi.complete()
		elseif bunkerPhaseUi.watchingConstruction
			and (stateName ~= "Constructing" or not playerIsWatchingOwnConstruction())
		then
			bunkerPhaseUi.watchingConstruction = false
			bunkerPhaseUi.token += 1
			bunkerPhaseUi.frame.Visible = false
		end
	end
	bunker:GetAttributeChangedSignal("UnlockState"):Connect(syncWorldConstruction)
	bunker:GetAttributeChangedSignal("ConstructionStage"):Connect(syncWorldConstruction)
	bunker:GetAttributeChangedSignal("ConstructionProgress"):Connect(syncWorldConstruction)
	player:GetAttributeChangedSignal("CooperSecretBunkerPurchased"):Connect(syncWorldConstruction)
	player:GetAttributeChangedSignal("CooperSecretBunkerUnlocked"):Connect(syncWorldConstruction)
	player:GetAttributeChangedSignal("CooperSecretBunkerStatus"):Connect(syncWorldConstruction)
	syncWorldConstruction()
end)

-- Button-driven Cooper computer ---------------------------------------------

local terminal = Instance.new("Frame")
terminal.Name = "CooperComputer"
terminal.AnchorPoint = Vector2.new(0.5, 0.5)
terminal.Position = UDim2.fromScale(0.5, 0.5)
terminal.Size = UDim2.fromOffset(900, 620)
terminal.BackgroundColor3 = Color3.fromRGB(4, 12, 8)
terminal.Visible = false
terminal.Active = true
terminal.ZIndex = 60
-- Full-screen workspaces must not inherit the gameplay HUD's global scale.
-- Parenting the terminal directly to the safe-area ScreenGui keeps every
-- phone touch target readable while the non-interactive HUD can scale down.
terminal.Parent = gui
corner(terminal, 6)
stroke(terminal, COLORS.terminal, 2, 0.05)

local terminalMenuBar = label(
	terminal,
	"MenuBar",
	"COOPER TERMINAL   •   STATUS: ONLINE",
	UDim2.new(1, -20, 0, 22),
	UDim2.fromOffset(10, 6),
	Enum.Font.RobotoMono,
	14,
	Color3.fromRGB(70, 130, 85)
)
terminalMenuBar.ZIndex = 61

local terminalTitle = label(
	terminal,
	"Title",
	"COOPER TERMINAL // MAIN MENU",
	UDim2.new(1, -150, 0, 28),
	UDim2.fromOffset(14, 30),
	Enum.Font.RobotoMono,
	20,
	COLORS.terminal
)
terminalTitle.ZIndex = 61

local terminalClose = button(terminal, "Close", "Close", UDim2.fromOffset(108, 36), UDim2.new(1, -120, 0, 8), Color3.fromRGB(104, 39, 39))
terminalClose.ZIndex = 70
terminalClose.Font = Enum.Font.GothamBold
terminalClose.TextSize = 15
local terminalBack = button(terminal, "Back", "←  Back to Menu", UDim2.fromOffset(170, 38), UDim2.fromOffset(14, 56), Color3.fromRGB(8, 54, 27))
terminalBack.ZIndex = 70
terminalBack.Font = Enum.Font.GothamBold
terminalBack.TextSize = 15

local terminalBody = label(
	terminal,
	"Body",
	"",
	UDim2.new(0.42, -24, 1, -112),
	UDim2.fromOffset(14, 98),
	Enum.Font.RobotoMono,
	15,
	COLORS.terminal,
	Enum.TextXAlignment.Left
)
terminalBody.TextYAlignment = Enum.TextYAlignment.Top
terminalBody.ZIndex = 61

local terminalTreePanel = Instance.new("Frame")
terminalTreePanel.Name = "TreePanel"
terminalTreePanel.Position = UDim2.new(0.42, 0, 0, 58)
terminalTreePanel.Size = UDim2.new(0.58, -14, 1, -72)
terminalTreePanel.BackgroundColor3 = Color3.fromRGB(3, 10, 6)
terminalTreePanel.BorderSizePixel = 0
terminalTreePanel.ZIndex = 61
terminalTreePanel.Parent = terminal
corner(terminalTreePanel, 4)
stroke(terminalTreePanel, Color3.fromRGB(34, 78, 52), 1, 0.35)

local terminalTreeHeader = label(
	terminalTreePanel,
	"TreeHeader",
	"CHOOSE AN ACTION",
	UDim2.new(1, -16, 0, 24),
	UDim2.fromOffset(8, 6),
	Enum.Font.RobotoMono,
	13,
	Color3.fromRGB(70, 130, 85)
)
terminalTreeHeader.ZIndex = 62

local terminalButtons = Instance.new("ScrollingFrame")
terminalButtons.Name = "TreeList"
terminalButtons.Position = UDim2.fromOffset(8, 32)
terminalButtons.Size = UDim2.new(1, -16, 1, -40)
terminalButtons.BackgroundTransparency = 1
terminalButtons.BorderSizePixel = 0
terminalButtons.ScrollBarThickness = 8
terminalButtons.CanvasSize = UDim2.fromOffset(0, 0)
terminalButtons.AutomaticCanvasSize = Enum.AutomaticSize.Y
terminalButtons.ZIndex = 62
terminalButtons.Parent = terminalTreePanel

local terminalList = Instance.new("UIListLayout")
terminalList.Padding = UDim.new(0, 7)
terminalList.SortOrder = Enum.SortOrder.LayoutOrder
terminalList.Parent = terminalButtons

-- BANKLINK owns a persistent full-width workspace. Keeping it out of the file
-- tree is important: normal profile snapshots rebuild that tree, but must never
-- erase a sequence while the player is memorizing it.
local bankPanel = Instance.new("Frame")
bankPanel.Name = "MedfordBankLink"
bankPanel.Position = UDim2.fromOffset(14, 98)
bankPanel.Size = UDim2.new(1, -28, 1, -112)
bankPanel.BackgroundColor3 = Color3.fromRGB(2, 9, 7)
bankPanel.BorderSizePixel = 0
bankPanel.ClipsDescendants = true
bankPanel.Visible = false
bankPanel.ZIndex = 64
bankPanel.Parent = terminal
corner(bankPanel, 5)
stroke(bankPanel, Color3.fromRGB(33, 255, 132), 2, 0.12)

local bankBackdrop = Instance.new("Frame")
bankBackdrop.Name = "GridGlow"
bankBackdrop.Size = UDim2.fromScale(1, 1)
bankBackdrop.BackgroundColor3 = Color3.fromRGB(3, 23, 16)
bankBackdrop.BackgroundTransparency = 0.42
bankBackdrop.BorderSizePixel = 0
bankBackdrop.ZIndex = 64
bankBackdrop.Parent = bankPanel

for lineIndex = 1, 25 do
	local scanline = Instance.new("Frame")
	scanline.Name = "Scanline"
	scanline.Position = UDim2.new(0, 0, (lineIndex - 1) / 25, 0)
	scanline.Size = UDim2.new(1, 0, 0, 1)
	scanline.BackgroundColor3 = Color3.fromRGB(80, 255, 151)
	scanline.BackgroundTransparency = 0.945
	scanline.BorderSizePixel = 0
	scanline.ZIndex = 65
	scanline.Parent = bankPanel
end

local bankSweep = Instance.new("Frame")
bankSweep.Name = "SignalSweep"
bankSweep.Position = UDim2.new(0, 0, 0, -12)
bankSweep.Size = UDim2.new(1, 0, 0, 12)
bankSweep.BackgroundColor3 = Color3.fromRGB(61, 255, 143)
bankSweep.BackgroundTransparency = 0.91
bankSweep.BorderSizePixel = 0
bankSweep.ZIndex = 66
bankSweep.Parent = bankPanel
TweenService:Create(
	bankSweep,
	TweenInfo.new(3.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
	{ Position = UDim2.new(0, 0, 1, 0) }
):Play()

local bankHeader = Instance.new("Frame")
bankHeader.Name = "Header"
bankHeader.Position = UDim2.fromOffset(10, 8)
bankHeader.Size = UDim2.new(1, -20, 0, 48)
bankHeader.BackgroundColor3 = Color3.fromRGB(4, 27, 18)
bankHeader.BackgroundTransparency = 0.08
bankHeader.BorderSizePixel = 0
bankHeader.ZIndex = 67
bankHeader.Parent = bankPanel
corner(bankHeader, 4)
stroke(bankHeader, Color3.fromRGB(44, 203, 111), 1, 0.3)

local bankHeaderTitle = label(
	bankHeader,
	"Title",
	"MEDFORD NATIONAL BANK // SECURE DIAL-UP",
	UDim2.new(1, -190, 0, 24),
	UDim2.fromOffset(12, 4),
	Enum.Font.RobotoMono,
	18,
	Color3.fromRGB(117, 255, 167)
)
bankHeaderTitle.ZIndex = 68
local bankHeaderSubtitle = label(
	bankHeader,
	"Subtitle",
	"BANKLINK 2.7  •  ENCRYPTED MODEM CHANNEL  •  MEDFORD, TX",
	UDim2.new(1, -190, 0, 16),
	UDim2.fromOffset(12, 28),
	Enum.Font.RobotoMono,
	11,
	Color3.fromRGB(69, 157, 102)
)
bankHeaderSubtitle.ZIndex = 68
local bankSignal = label(
	bankHeader,
	"Signal",
	"● LINK STANDBY",
	UDim2.fromOffset(172, 32),
	UDim2.new(1, -184, 0, 8),
	Enum.Font.RobotoMono,
	13,
	Color3.fromRGB(246, 195, 66),
	Enum.TextXAlignment.Right
)
bankSignal.ZIndex = 68

local bankMode = label(
	bankPanel,
	"Mode",
	"READY // WAITING FOR AN AUTHORIZED TASK CYCLE",
	UDim2.new(1, -20, 0, 38),
	UDim2.fromOffset(10, 62),
	Enum.Font.RobotoMono,
	20,
	Color3.fromRGB(91, 255, 137),
	Enum.TextXAlignment.Center
)
bankMode.BackgroundColor3 = Color3.fromRGB(4, 18, 13)
bankMode.BackgroundTransparency = 0.08
bankMode.ZIndex = 67
corner(bankMode, 4)
local bankModeStroke = stroke(bankMode, Color3.fromRGB(45, 177, 96), 1, 0.28)

local bankReadoutNames = { "Cycle", "Reward", "Speed", "Round" }
local bankReadoutTitles = { "SECURITY CYCLE", "SUCCESS PAYOUT", "LINK SPEED", "ROUND STATUS" }
local bankReadoutValues = { "01", "$90", "0.78 SEC", "0 / 4" }
local bankReadouts = {}
for index, name in ipairs(bankReadoutNames) do
	local readout = Instance.new("Frame")
	readout.Name = name
	readout.Position = UDim2.new((index - 1) * 0.25, index == 1 and 10 or 5, 0, 108)
	readout.Size = UDim2.new(0.25, -15, 0, 58)
	readout.BackgroundColor3 = Color3.fromRGB(3, 20, 14)
	readout.BackgroundTransparency = 0.08
	readout.BorderSizePixel = 0
	readout.ZIndex = 67
	readout.Parent = bankPanel
	corner(readout, 4)
	stroke(readout, Color3.fromRGB(35, 127, 76), 1, 0.28)
	local titleLabel = label(
		readout,
		"Title",
		bankReadoutTitles[index],
		UDim2.new(1, -12, 0, 17),
		UDim2.fromOffset(6, 5),
		Enum.Font.RobotoMono,
		10,
		Color3.fromRGB(68, 148, 96),
		Enum.TextXAlignment.Center
	)
	titleLabel.ZIndex = 68
	local valueLabel = label(
		readout,
		"Value",
		bankReadoutValues[index],
		UDim2.new(1, -12, 0, 27),
		UDim2.fromOffset(6, 24),
		Enum.Font.RobotoMono,
		18,
		Color3.fromRGB(125, 255, 174),
		Enum.TextXAlignment.Center
	)
	valueLabel.ZIndex = 68
	bankReadouts[name] = valueLabel
end

local bankRoundStrip = Instance.new("Frame")
bankRoundStrip.Name = "RoundStrip"
bankRoundStrip.Position = UDim2.fromOffset(10, 173)
bankRoundStrip.Size = UDim2.new(1, -20, 0, 25)
bankRoundStrip.BackgroundTransparency = 1
bankRoundStrip.ZIndex = 67
bankRoundStrip.Parent = bankPanel
local bankRoundLabel = label(
	bankRoundStrip,
	"Label",
	"SECURITY NODES",
	UDim2.fromOffset(150, 25),
	UDim2.fromOffset(0, 0),
	Enum.Font.RobotoMono,
	11,
	Color3.fromRGB(69, 157, 102)
)
bankRoundLabel.ZIndex = 68
local bankRoundLeds = {}
for index = 1, 8 do
	local led = Instance.new("Frame")
	led.Name = "Node" .. tostring(index)
	led.Position = UDim2.fromOffset(155 + (index - 1) * 34, 4)
	led.Size = UDim2.fromOffset(24, 14)
	led.BackgroundColor3 = Color3.fromRGB(10, 46, 29)
	led.BorderSizePixel = 0
	led.Visible = index <= 4
	led.ZIndex = 68
	led.Parent = bankRoundStrip
	corner(led, 7)
	bankRoundLeds[index] = led
end
local bankInputProgress = label(
	bankRoundStrip,
	"InputProgress",
	"INPUT 0 / 0",
	UDim2.fromOffset(220, 25),
	UDim2.new(1, -220, 0, 0),
	Enum.Font.RobotoMono,
	12,
	Color3.fromRGB(69, 157, 102),
	Enum.TextXAlignment.Right
)
bankInputProgress.ZIndex = 68

local bankKeyboardLabel = label(
	bankPanel,
	"KeyboardLabel",
	"REMOTE KEY MATRIX // WATCH THE LIGHTS, THEN REPEAT THE PATTERN",
	UDim2.new(1, -20, 0, 20),
	UDim2.fromOffset(10, 203),
	Enum.Font.RobotoMono,
	11,
	Color3.fromRGB(69, 157, 102),
	Enum.TextXAlignment.Center
)
bankKeyboardLabel.ZIndex = 67

local bankKeyRows = {
	{ "Q", "W", "E", "R" },
	{ "A", "S", "D", "F" },
	{ "Z", "X", "C", "V" },
}
local bankKeyVisuals = {}
local submitBankKey
for rowIndex, row in ipairs(bankKeyRows) do
	local rowFrame = Instance.new("Frame")
	rowFrame.Name = "KeyRow" .. tostring(rowIndex)
	rowFrame.AnchorPoint = Vector2.new(0.5, 0)
	rowFrame.Position = UDim2.new(0.5, 0, 0, 228 + (rowIndex - 1) * 71)
	rowFrame.Size = UDim2.fromOffset(620, 62)
	rowFrame.BackgroundTransparency = 1
	rowFrame.ZIndex = 67
	rowFrame.Parent = bankPanel
	for columnIndex, keyName in ipairs(row) do
		local keyButton = Instance.new("TextButton")
		keyButton.Name = "Key_" .. keyName
		keyButton.Position = UDim2.fromOffset((columnIndex - 1) * 158, 0)
		keyButton.Size = UDim2.fromOffset(146, 62)
		keyButton.BackgroundColor3 = Color3.fromRGB(5, 29, 19)
		keyButton.BorderSizePixel = 0
		keyButton.AutoButtonColor = false
		keyButton.Selectable = true
		keyButton.Text = keyName
		keyButton.TextColor3 = Color3.fromRGB(102, 211, 140)
		keyButton.Font = Enum.Font.RobotoMono
		keyButton.TextSize = 27
		keyButton.ZIndex = 68
		keyButton.Parent = rowFrame
		corner(keyButton, 5)
		local keyStroke = stroke(keyButton, Color3.fromRGB(38, 124, 75), 2, 0.22)
		local keyScale = Instance.new("UIScale")
		keyScale.Scale = 1
		keyScale.Parent = keyButton
		bankKeyVisuals[keyName] = {
			button = keyButton,
			stroke = keyStroke,
			scale = keyScale,
		}
		keyButton.Activated:Connect(function()
			if submitBankKey then
				submitBankKey(keyName)
			end
		end)
	end
end

local bankStartButton = button(
	bankPanel,
	"StartBankLink",
	"HACK BANK",
	UDim2.fromOffset(252, 40),
	UDim2.new(0, 10, 1, -48),
	Color3.fromRGB(10, 76, 42)
)
bankStartButton.ZIndex = 69
bankStartButton.Font = Enum.Font.RobotoMono
bankStartButton.TextSize = 14
local bankFooter = label(
	bankPanel,
	"Footer",
	"A successful link deposits allowance. Every completed cycle runs faster and pays more.",
	UDim2.new(1, -286, 0, 40),
	UDim2.new(0, 276, 1, -48),
	Enum.Font.RobotoMono,
	11,
	Color3.fromRGB(74, 165, 105),
	Enum.TextXAlignment.Left
)
bankFooter.ZIndex = 67

local terminalPage = "Home"
local currentSnapshot = nil
local currentSnapshotReceivedAt = 0
local dosInput = nil
local automationSelectedId = nil

local partyUx = {}

function partyUx.data(snapshot)
	local party = type(snapshot) == "table" and snapshot.party or nil
	return type(party) == "table" and party or {}
end

function partyUx.isActive(snapshot)
	local party = partyUx.data(snapshot)
	-- Preserve compatibility with the pre-party snapshot shape. A Milestone 1
	-- snapshot always has a state, and only its explicit Active state may mutate
	-- the shared house.
	return party.state == nil or tostring(party.state) == "Active"
end

function partyUx.isHost(snapshot)
	return partyUx.data(snapshot).isHost == true
end

function partyUx.pauseLabel(snapshot)
	local state = tostring(partyUx.data(snapshot).state or "Active")
	if state == "HostGrace" then
		return "SHARED GAME PAUSED • WAITING FOR HOST RECONNECT"
	elseif state == "Hydrating" then
		return "SHARED HOUSE LOADING • WAITING FOR PARTY MEMBERS"
	elseif state == "Closing" or state == "Closed" then
		return "PARTY SESSION ENDING • RETURNING TO LOBBY"
	end
	return "SHARED GAME TEMPORARILY PAUSED"
end

function partyUx.pauseDetail(snapshot)
	local state = tostring(partyUx.data(snapshot).state or "Active")
	if state == "HostGrace" then
		return "Shared progress is frozen safely until the host reconnects or the party returns to the lobby."
	elseif state == "Hydrating" then
		return "Shared progress will begin as soon as every teleported party member finishes loading."
	elseif state == "Closing" or state == "Closed" then
		return "Purchases and tasks are closed while profiles save and the party returns to the lobby."
	end
	return "Shared progress is temporarily paused by the server."
end

function partyUx.memberName(userId, fallback)
	local numericId = tonumber(userId)
	if numericId then
		local member = game:GetService("Players"):GetPlayerByUserId(numericId)
		if member then
			return member.DisplayName
		end
	end
	return tostring(fallback or "a teammate")
end

function partyUx.ownsCarrier(taskData)
	local carrierUserId = type(taskData) == "table" and tonumber(taskData.carrierUserId) or nil
	return carrierUserId == nil or carrierUserId == player.UserId
end

function partyUx.reconnectRemaining(snapshot)
	local party = partyUx.data(snapshot)
	local elapsed = math.max(0, os.clock() - currentSnapshotReceivedAt)
	return math.max(0, math.ceil((tonumber(party.reconnectRemaining) or 0) - elapsed))
end

function partyUx.updatePause(snapshot)
	local frame = scaleRoot:FindFirstChild("PartyReconnectPause")
	if not frame or not frame:IsA("Frame") then
		return
	end
	local party = partyUx.data(snapshot)
	local state = tostring(party.state or "Active")
	if state ~= "HostGrace" then
		frame.Visible = false
		return
	end
	local remaining = partyUx.reconnectRemaining(snapshot)
	local minutes = math.floor(remaining / 60)
	local seconds = remaining % 60
	frame.Visible = true
	local title = frame:FindFirstChild("Title")
	local detail = frame:FindFirstChild("Text")
	if title and title:IsA("TextLabel") then
		title.Text = "GAME PAUSED • HOST RECONNECTING"
	end
	if detail and detail:IsA("TextLabel") then
		detail.Text = string.format(
		"Shared tasks and purchases are safely paused. Returning to the lobby in %d:%02d if the host does not return.",
		minutes,
		seconds
		)
	end
end

local bankPhase = "Idle"
local bankSessionId = nil
local bankAnimationToken = 0
local bankInputPending = false
local bankInputIndex = 0
local bankPatternLength = 0
local bankCurrentRound = 0
local bankRoundCount = math.clamp(math.floor(tonumber(Config.BankHack and Config.BankHack.RoundCount) or 4), 1, 8)
local bankReward = math.max(0, math.floor(tonumber(Config.BankHack and Config.BankHack.BaseReward) or 90))
local bankCycle = 1
local bankStepSeconds = math.max(0.1, tonumber(Config.BankHack and Config.BankHack.BasePreviewStepSeconds) or 0.78)
local bankSnapshotCanStart = false
local bankInputBound = false

local taskDefinitionById = {}
for _, definition in ipairs(type(Config.Tasks) == "table" and Config.Tasks or {}) do
	if type(definition) == "table" and type(definition.id) == "string" then
		taskDefinitionById[definition.id] = definition
	end
end

local automationTaskColors = {
	GeorgeBeer = COLORS.orange,
	MaryDishes = COLORS.green,
	MaryTrash = COLORS.blue,
	MissyPlush = COLORS.purple,
	MedfordBankHack = Color3.fromRGB(64, 231, 255),
}

local automationTaskColorNames = {
	GeorgeBeer = "orange",
	MaryDishes = "green",
	MaryTrash = "blue",
	MissyPlush = "purple",
	MedfordBankHack = "cyan",
}

local function automationData(snapshot)
	local value = type(snapshot) == "table" and snapshot.automation or nil
	return type(value) == "table" and value or {}
end

local function automationCatalog(snapshot)
	local catalog = automationData(snapshot).catalog
	return type(catalog) == "table" and catalog or {}
end

function upgradeNoticeUi.automationRun(snapshot, taskId)
	local runs = automationData(snapshot).activeRuns
	if type(runs) ~= "table" then
		return nil
	end
	for _, run in ipairs(runs) do
		if type(run) == "table" and tostring(run.taskId or "") == tostring(taskId or "") then
			return run
		end
	end
	return nil
end

local function automationEntry(snapshot, upgradeId)
	for _, entry in ipairs(automationCatalog(snapshot)) do
		if type(entry) == "table" and tostring(entry.id or "") == tostring(upgradeId or "") then
			return entry
		end
	end
	return nil
end

local function automationEntryPending(snapshot, entry)
	if type(entry) ~= "table" then
		return false
	end
	local automation = automationData(snapshot)
	return entry.pending == true
		or tostring(automation.pendingId or "") == tostring(entry.id or "")
	end

-- Remember each affordability episode independently. Temporary delivery
-- blockers never clear an announcement, while spending below an item's price
-- arms it again for the next genuine threshold crossing.
function upgradeNoticeUi.update(snapshot)
	if type(snapshot) ~= "table" or snapshot.introNeeded == true or introScrim.Visible then
		return
	end
	local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
	local newlyAffordable = {}
	local function consider(key, name, priceValue, retired, canBuyNow)
		local price = math.max(1, math.floor(tonumber(priceValue) or 0))
		if retired == true then
			upgradeNoticeUi.announced[key] = nil
			return
		end
		if allowance < price then
			upgradeNoticeUi.announced[key] = nil
			return
		end
		if canBuyNow == true and upgradeNoticeUi.announced[key] ~= true then
			upgradeNoticeUi.announced[key] = true
			table.insert(newlyAffordable, {
				key = key,
				name = tostring(name),
				price = price,
			})
		end
	end

	local nextPart = type(snapshot.nextMachinePart) == "table" and snapshot.nextMachinePart or nil
	if nextPart then
		local stage = math.max(1, math.floor(tonumber(nextPart.stage) or 0))
		local delivery = type(snapshot.delivery) == "table" and snapshot.delivery or nil
		local pendingThisStage = delivery ~= nil
			and tostring(delivery.kind or "") == "MachinePart"
			and math.floor(tonumber(delivery.stage) or 0) == stage
		consider(
			"MachinePart:" .. tostring(stage),
			"Time Machine — " .. tostring(nextPart.name or "Component"),
			nextPart.cost,
			pendingThisStage or math.floor(tonumber(snapshot.machineStage) or 0) >= stage,
			nextPart.canOrder == true
		)
	end

	for _, entry in ipairs(automationCatalog(snapshot)) do
		if type(entry) == "table" then
			local id = tostring(entry.id or "")
			if id ~= "" then
				local pending = automationEntryPending(snapshot, entry)
				consider(
					"TaskUpgrade:" .. id,
					entry.name or "Task Robot",
					entry.price,
					entry.installed == true or pending,
					entry.canOrder == true
				)
			end
		end
	end

	local boombox = type(snapshot.boombox) == "table" and snapshot.boombox or {}
	consider(
		"Boombox",
		"Cooper Party Boombox",
		boombox.price,
		boombox.purchased == true,
		boombox.canOrder == true
	)
	consider(
		"BoomboxAutoplay",
		"Boombox Autoplay",
		boombox.autoplayPrice,
		boombox.autoplayPurchased == true,
		boombox.purchased == true
			and boombox.placed == true
			and boombox.canUpgradeAutoplay == true
	)
	local secretBunker = type(snapshot.secretBunker) == "table" and snapshot.secretBunker or {}
	consider(
		"SecretBunker",
		secretBunker.name or "Secret Underground Bunker",
		secretBunker.price,
		secretBunker.purchased == true,
		secretBunker.canOrder == true
	)
	local chemistrySetup = type(snapshot.chemistrySetup) == "table" and snapshot.chemistrySetup or {}
	consider(
		"ChemistrySetup",
		chemistrySetup.name or "Advanced Chemistry Setup",
		chemistrySetup.price,
		chemistrySetup.purchased == true,
		chemistrySetup.canOrder == true
	)

	if #newlyAffordable > 0 then
		upgradeNoticeUi.show(newlyAffordable)
	end
end

local function taskIsAutomated(taskData)
	return type(taskData) == "table" and taskData.automated == true
end

local function taskRole(taskId)
	local definition = taskDefinitionById[tostring(taskId or "")]
	if not definition then
		return "FAMILY TASK", 0, "Family"
	end
	return tostring(definition.title or definition.id or "FAMILY TASK"),
		math.max(0, math.floor(tonumber(definition.reward) or 0)),
		tostring(definition.requester or "Family")
end

local function roundedNonnegative(value)
	local numeric = tonumber(value)
	if not numeric or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
		return 0
	end
	return math.max(0, math.floor(numeric + 0.999))
end

local function formatCountdown(seconds)
	local remaining = roundedNonnegative(seconds)
	local minutes = math.floor(remaining / 60)
	local remainder = remaining % 60
	return string.format("%d:%02d", minutes, remainder)
end

local function boomboxIsPlaying(boombox)
	return type(boombox) == "table"
		and (boombox.playing == true or boombox.active == true or tostring(boombox.status or "") == "Playing")
end

-- Prefer the persisted epoch deadline because it keeps counting down between
-- snapshots. The relative field remains a fail-soft fallback for old servers
-- or a clock that has not synchronized yet.
local function boomboxCooldownRemaining(snapshot)
	local boombox = type(snapshot) == "table" and snapshot.boombox or nil
	if type(boombox) ~= "table" or boomboxIsPlaying(boombox) then
		return 0
	end
	local nextPlayAt = tonumber(boombox.nextPlayAt)
	if nextPlayAt and nextPlayAt > 0 then
		local elapsed = math.max(0, os.clock() - currentSnapshotReceivedAt)
		local serverUnixTime = tonumber(snapshot.serverUnixTime)
		local currentUnixTime = serverUnixTime and (serverUnixTime + elapsed) or os.time()
		return roundedNonnegative(nextPlayAt - currentUnixTime)
	end
	local elapsed = math.max(0, os.clock() - currentSnapshotReceivedAt)
	return roundedNonnegative((tonumber(boombox.cooldownRemaining) or 0) - elapsed)
end

-- The bunker is also deadline-driven. Derive the displayed countdown locally
-- from the server epoch so the terminal keeps moving between snapshots.
local function secretBunkerConstructionRemaining(snapshot)
	local secretBunker = type(snapshot) == "table" and snapshot.secretBunker or nil
	if type(secretBunker) ~= "table"
		or secretBunker.purchased ~= true
		or secretBunker.unlocked == true
	then
		return 0
	end
	local readyAt = tonumber(secretBunker.readyAt)
	if readyAt and readyAt > 0 then
		local elapsed = math.max(0, os.clock() - currentSnapshotReceivedAt)
		local serverUnixTime = tonumber(snapshot.serverUnixTime)
		local currentUnixTime = serverUnixTime and (serverUnixTime + elapsed) or os.time()
		return roundedNonnegative(readyAt - currentUnixTime)
	end
	local elapsed = math.max(0, os.clock() - currentSnapshotReceivedAt)
	return roundedNonnegative((tonumber(secretBunker.remaining) or 0) - elapsed)
end

local function boomboxStatus(snapshot)
	local boombox = type(snapshot) == "table" and snapshot.boombox or nil
	if type(boombox) ~= "table" or boombox.purchased ~= true then
		return "Unowned"
	end
	-- A different owner's song must never overwrite this player's outstanding
	-- delivery/setup instructions. Resolve the personal delivery first, then
	-- distinguish the earning owner from players waiting on the shared setpiece.
	if boombox.placed ~= true then
		local delivery = type(snapshot.delivery) == "table" and snapshot.delivery or nil
		if delivery and tostring(delivery.kind or "") == "Boombox" then
			local deliveryStatus = tostring(delivery.status or boombox.status or "WaitingDelivery")
			return deliveryStatus == "Install" and "Setup" or deliveryStatus
		end
		local status = tostring(boombox.status or "WaitingDelivery")
		return status == "Install" and "Setup" or status
	elseif boombox.ownsPlayback == true then
		return "Playing"
	elseif boombox.occupiedByOther == true then
		return "Busy"
	elseif boomboxIsPlaying(boombox) then
		-- Backward-compatible fallback for a pre-occupancy server snapshot.
		return "Playing"
	end
	return boomboxCooldownRemaining(snapshot) > 0 and "Cooldown" or "Ready"
end

-- Medford Bank memory link ---------------------------------------------------

local BANK_INPUT_ACTION = "CooperBankLinkKeyboard"
local BANK_INPUT_PRIORITY = Enum.ContextActionPriority.High.Value + 200
local bankKeyByCode = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.A] = "A",
	[Enum.KeyCode.S] = "S",
	[Enum.KeyCode.D] = "D",
	[Enum.KeyCode.F] = "F",
	[Enum.KeyCode.Z] = "Z",
	[Enum.KeyCode.X] = "X",
	[Enum.KeyCode.C] = "C",
	[Enum.KeyCode.V] = "V",
}
local bankLastInputKey = nil

local bankKeyStyles = {
	Idle = {
		background = Color3.fromRGB(5, 29, 19),
		text = Color3.fromRGB(102, 211, 140),
		stroke = Color3.fromRGB(38, 124, 75),
		scale = 1,
	},
	Ready = {
		background = Color3.fromRGB(5, 40, 25),
		text = Color3.fromRGB(133, 255, 177),
		stroke = Color3.fromRGB(46, 186, 99),
		scale = 1,
	},
	Cue = {
		background = Color3.fromRGB(233, 184, 54),
		text = Color3.fromRGB(12, 28, 17),
		stroke = Color3.fromRGB(255, 244, 169),
		scale = 1.075,
	},
	Pressed = {
		background = Color3.fromRGB(33, 142, 184),
		text = Color3.fromRGB(224, 255, 255),
		stroke = Color3.fromRGB(124, 239, 255),
		scale = 1.045,
	},
	Correct = {
		background = Color3.fromRGB(32, 174, 93),
		text = Color3.fromRGB(231, 255, 239),
		stroke = Color3.fromRGB(141, 255, 183),
		scale = 1.055,
	},
	Failure = {
		background = Color3.fromRGB(156, 31, 38),
		text = Color3.fromRGB(255, 223, 223),
		stroke = Color3.fromRGB(255, 101, 105),
		scale = 1.025,
	},
}

local function bankAttemptActive()
	return bankSessionId ~= nil
		or bankPhase == "Connecting"
		or bankPhase == "Playback"
		or bankPhase == "AwaitInput"
		or bankPhase == "WaitingServer"
		or bankPhase == "WaitingRound"
end

local function setBankKeyStyle(keyName, styleName, instant)
	local visual = bankKeyVisuals[keyName]
	local style = bankKeyStyles[styleName] or bankKeyStyles.Idle
	if not visual then
		return
	end
	local tweenInfo = TweenInfo.new(instant and 0 or 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(visual.button, tweenInfo, {
		BackgroundColor3 = style.background,
		TextColor3 = style.text,
	}):Play()
	TweenService:Create(visual.stroke, tweenInfo, { Color = style.stroke }):Play()
	TweenService:Create(visual.scale, tweenInfo, { Scale = style.scale }):Play()
end

local function pulseBankKey(keyName, styleName, duration, returnStyle)
	local visual = bankKeyVisuals[keyName]
	if not visual then
		return
	end
	visual.pulseSerial = (visual.pulseSerial or 0) + 1
	local pulseSerial = visual.pulseSerial
	setBankKeyStyle(keyName, styleName)
	task.delay(duration or 0.16, function()
		if visual.pulseSerial == pulseSerial and visual.button.Parent then
			setBankKeyStyle(keyName, returnStyle or "Ready")
		end
	end)
end

local function setAllBankKeys(styleName, instant)
	for keyName, visual in pairs(bankKeyVisuals) do
		visual.pulseSerial = (visual.pulseSerial or 0) + 1
		setBankKeyStyle(keyName, styleName, instant)
	end
end

local function setBankMode(text, color)
	local accent = color or COLORS.terminal
	bankMode.Text = tostring(text or "")
	bankMode.TextColor3 = accent
	bankModeStroke.Color = accent
end

local function setBankRoundDisplay(roundNumber, completedThrough)
	bankCurrentRound = math.clamp(math.floor(tonumber(roundNumber) or 0), 0, bankRoundCount)
	local completed = math.clamp(math.floor(tonumber(completedThrough) or math.max(0, bankCurrentRound - 1)), 0, bankRoundCount)
	bankReadouts.Round.Text = string.format("%d / %d", bankCurrentRound, bankRoundCount)
	for index, led in ipairs(bankRoundLeds) do
		led.Visible = index <= bankRoundCount
		if index <= completed then
			led.BackgroundColor3 = Color3.fromRGB(48, 226, 117)
		elseif index == bankCurrentRound and bankCurrentRound > 0 then
			led.BackgroundColor3 = Color3.fromRGB(246, 195, 66)
		else
			led.BackgroundColor3 = Color3.fromRGB(10, 46, 29)
		end
	end
end

local function updateBankInputProgress()
	bankInputProgress.Text = string.format("INPUT %d / %d", bankInputIndex, bankPatternLength)
	bankInputProgress.TextColor3 = bankPhase == "AwaitInput"
		and Color3.fromRGB(125, 255, 174)
		or Color3.fromRGB(69, 157, 102)
end

local function refreshBankStartButton()
	local attemptActive = bankAttemptActive()
	local enabled = bankSnapshotCanStart and not attemptActive
	bankStartButton.Active = enabled
	bankStartButton.Selectable = enabled
	bankStartButton.AutoButtonColor = enabled
	if attemptActive then
		bankStartButton.Text = "SECURE LINK ACTIVE"
	elseif enabled then
		bankStartButton.Text = "HACK BANK"
	elseif partyUx.bankOccupiedByOther then
		bankStartButton.Text = "BANKLINK IN USE BY TEAMMATE"
	elseif bankPhase == "Failed" then
		bankStartButton.Text = "RETRY LINK UNAVAILABLE"
	elseif bankPhase == "Succeeded" then
		bankStartButton.Text = "TRANSFER COMPLETE"
	else
		bankStartButton.Text = "NO BANK TASK AVAILABLE"
	end
	bankStartButton.BackgroundColor3 = enabled
		and Color3.fromRGB(10, 92, 48)
		or Color3.fromRGB(18, 45, 31)
	bankStartButton.TextColor3 = enabled
		and Color3.fromRGB(225, 255, 235)
		or Color3.fromRGB(79, 126, 94)
end

local function bankSnapshotData(snapshot)
	local data = type(snapshot) == "table" and snapshot.bankHack or nil
	return type(data) == "table" and data or {}
end

local function updateBankSnapshot(snapshot)
	local data = bankSnapshotData(snapshot)
	local cycleValue = tonumber(data.cycle)
	if not cycleValue then
		cycleValue = (tonumber(data.successes) or 0) + 1
	end
	bankCycle = math.max(1, math.floor(cycleValue))
	bankReward = math.max(0, math.floor(tonumber(data.reward) or bankReward))
	bankStepSeconds = math.max(0.1, tonumber(data.previewStepSeconds) or bankStepSeconds)
	bankRoundCount = math.clamp(math.floor(tonumber(data.roundCount) or bankRoundCount), 1, #bankRoundLeds)
	bankSnapshotCanStart = data.canStart == true
	partyUx.bankOccupiedByOther = data.occupiedByOther == true
	partyUx.bankActorDisplayName = partyUx.memberName(data.actorUserId, "a teammate")
	if not bankAttemptActive() and (partyUx.bankOccupiedByOther or not partyUx.isActive(snapshot)) then
		bankPhase = "Idle"
	end
	if bankPhase == "Failed" and bankSnapshotCanStart then
		bankPhase = "Idle"
	end

	bankReadouts.Cycle.Text = string.format("%02d", bankCycle)
	bankReadouts.Reward.Text = "$" .. tostring(bankReward)
	bankReadouts.Speed.Text = string.format("%.2f SEC", bankStepSeconds)
	local startingLength = math.max(1, math.floor(tonumber(data.startingLength) or 2))
	local endingLength = startingLength + math.max(0, bankRoundCount - 1)
	bankFooter.Text = string.format(
		"Cycle %d uses %d–%d key patterns at %.2f-second cues. Every win gets faster; every second win starts one key longer.",
		bankCycle,
		startingLength,
		endingLength,
		bankStepSeconds
	)
	-- Failure and success packets own their short, high-impact presentation.
	-- Snapshots arrive immediately after those packets; resetting the LEDs and
	-- key colors here would erase the red/green result before the player sees it.
	if not bankAttemptActive() and bankPhase ~= "Failed" and bankPhase ~= "Succeeded" then
		setBankRoundDisplay(tonumber(data.round) or 0, 0)
		bankInputIndex = 0
		bankPatternLength = 0
		updateBankInputProgress()
		setAllBankKeys("Idle")
		if bankPhase == "Idle" then
			local retryRemaining = math.max(0, tonumber(data.retryRemaining) or 0)
			if not partyUx.isActive(snapshot) then
				setBankMode(string.upper(partyUx.pauseLabel(snapshot)), COLORS.orange)
				bankSignal.Text = "● SHARED GAME PAUSED"
				bankSignal.TextColor3 = COLORS.orange
			elseif partyUx.bankOccupiedByOther then
				setBankMode(string.upper(partyUx.bankActorDisplayName) .. " IS USING BANKLINK // WATCH OR WAIT", COLORS.yellow)
				bankSignal.Text = "● TEAMMATE LINK ACTIVE"
				bankSignal.TextColor3 = COLORS.yellow
			elseif retryRemaining > 0 then
				setBankMode(string.format("MODEM COOLING DOWN // RETRY IN %.1f SEC", retryRemaining), COLORS.yellow)
			elseif bankSnapshotCanStart then
				setBankMode("READY // DIAL THE BANK SECURITY NODE", COLORS.terminal)
			elseif data.taskActive == true then
				setBankMode(tostring(data.status or "BANK LINK TEMPORARILY UNAVAILABLE"), COLORS.yellow)
			else
				setBankMode("STANDBY // WAITING FOR THE BANK TASK CYCLE", Color3.fromRGB(89, 157, 109))
			end
		end
	end
	if bankAttemptActive() then
		bankSignal.Text = "● LINK ACTIVE"
		bankSignal.TextColor3 = COLORS.terminal
	elseif bankPhase == "Idle" and not partyUx.isActive(snapshot) then
		bankSignal.Text = "● SHARED GAME PAUSED"
		bankSignal.TextColor3 = COLORS.orange
	elseif bankPhase == "Idle" and partyUx.bankOccupiedByOther then
		bankSignal.Text = "● TEAMMATE LINK ACTIVE"
		bankSignal.TextColor3 = COLORS.yellow
	elseif bankPhase == "Idle" then
		bankSignal.Text = "● LINK STANDBY"
		bankSignal.TextColor3 = COLORS.yellow
	end
	refreshBankStartButton()
end

local function waitForBankServerTime(token, targetTime)
	while bankAnimationToken == token and bankPanel.Parent and workspace:GetServerTimeNow() < targetTime do
		game:GetService("RunService").Heartbeat:Wait()
	end
	return bankAnimationToken == token and bankPanel.Parent ~= nil
end

local function bindBankInputs()
	if bankInputBound then
		return
	end
	bankInputBound = true
	game:GetService("ContextActionService"):BindActionAtPriority(
		BANK_INPUT_ACTION,
		function(_, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				local keyName = bankKeyByCode[inputObject.KeyCode]
				if keyName and submitBankKey then
					submitBankKey(keyName)
				end
			end
			-- All twelve BANKLINK keys include WASD. Always sink them while this
			-- page is visible so answering the puzzle cannot walk the avatar away
			-- from Sheldon's keyboard and terminate the trusted terminal session.
			return Enum.ContextActionResult.Sink
		end,
		false,
		BANK_INPUT_PRIORITY,
		Enum.KeyCode.Q,
		Enum.KeyCode.W,
		Enum.KeyCode.E,
		Enum.KeyCode.R,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.F,
		Enum.KeyCode.Z,
		Enum.KeyCode.X,
		Enum.KeyCode.C,
		Enum.KeyCode.V
	)
end

local function unbindBankInputs()
	if bankInputBound then
		game:GetService("ContextActionService"):UnbindAction(BANK_INPUT_ACTION)
		bankInputBound = false
	end
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(bankPanel) then
		GuiService.SelectedObject = nil
	end
end

bankKeyStyles.pendingCancels = {}
function bankKeyStyles.requestCancellation(sessionId)
	if type(sessionId) ~= "string" or sessionId == "" then
		return
	end
	bankKeyStyles.pendingCancels[sessionId] = true
	bankHackEvent:FireServer("Cancel", { sessionId = sessionId })
	-- Start and Cancel share the server's short request debounce. A player can
	-- press Back during the dial animation, so retry once after that window if
	-- no cancellation acknowledgement arrived. The session id prevents this
	-- retry from ever cancelling a newer connection.
	task.delay(math.max(0.22, (tonumber(Config.RequestCooldown) or 0.18) + 0.05), function()
		if bankKeyStyles.pendingCancels[sessionId] == true and bankSessionId ~= sessionId then
			bankHackEvent:FireServer("Cancel", { sessionId = sessionId })
		end
		task.delay(0.5, function()
			bankKeyStyles.pendingCancels[sessionId] = nil
		end)
	end)
end

local function resetBankAttempt(notifyServer)
	local sessionId = bankSessionId
	bankAnimationToken += 1
	bankSessionId = nil
	bankPhase = "Idle"
	bankInputPending = false
	bankLastInputKey = nil
	bankInputIndex = 0
	bankPatternLength = 0
	setBankRoundDisplay(0, 0)
	updateBankInputProgress()
	setAllBankKeys("Idle", true)
	if notifyServer == true and sessionId ~= nil then
		bankKeyStyles.requestCancellation(sessionId)
	end
	updateBankSnapshot(currentSnapshot or {})
end

local function beginBankPattern(packet)
	local rawPattern = type(packet.pattern) == "table" and packet.pattern
		or (type(packet.sequence) == "table" and packet.sequence or {})
	local pattern = {}
	for _, rawKey in ipairs(rawPattern) do
		local keyName = string.upper(tostring(rawKey or ""))
		if bankKeyVisuals[keyName] then
			table.insert(pattern, keyName)
		end
	end
	if #pattern == 0 or bankSessionId == nil then
		bankPhase = "Failed"
		bankInputPending = false
		setBankMode("LINK ERROR // INVALID SECURITY PATTERN", COLORS.red)
		refreshBankStartButton()
		return
	end

	bankAnimationToken += 1
	local token = bankAnimationToken
	bankPhase = "Playback"
	bankInputPending = false
	bankInputIndex = 0
	bankPatternLength = #pattern
	bankCurrentRound = math.max(1, math.floor(tonumber(packet.round) or bankCurrentRound or 1))
	bankRoundCount = math.clamp(math.floor(tonumber(packet.roundCount) or bankRoundCount), 1, #bankRoundLeds)
	bankStepSeconds = math.max(0.1, tonumber(packet.previewStepSeconds or packet.stepSeconds) or bankStepSeconds)
	local cueSeconds = math.clamp(
		tonumber(packet.cueSeconds or packet.cueLightSeconds)
			or bankStepSeconds * (tonumber(Config.BankHack and Config.BankHack.CueLightRatio) or 0.62),
		0.08,
		bankStepSeconds
	)
	local startsAt = tonumber(packet.displayStartsAt or packet.previewStartsAt or packet.startsAt or packet.startTime)
		or (workspace:GetServerTimeNow() + math.max(0.1, tonumber(packet.leadInSeconds) or 0.45))
	local inputOpensAt = tonumber(packet.inputOpensAt) or (startsAt + #pattern * bankStepSeconds)

	bankReadouts.Speed.Text = string.format("%.2f SEC", bankStepSeconds)
	setBankRoundDisplay(bankCurrentRound, bankCurrentRound - 1)
	updateBankInputProgress()
	setAllBankKeys("Idle")
	setBankMode("MEMORIZE // SECURITY PATTERN INCOMING", COLORS.yellow)
	bankSignal.Text = "● RECEIVING"
	bankSignal.TextColor3 = COLORS.yellow
	refreshBankStartButton()

	task.spawn(function()
		if not waitForBankServerTime(token, startsAt) then
			return
		end
		for index, keyName in ipairs(pattern) do
			local cueStart = startsAt + (index - 1) * bankStepSeconds
			local cueEnd = cueStart + cueSeconds
			if not waitForBankServerTime(token, cueStart) then
				return
			end
			if workspace:GetServerTimeNow() < cueEnd then
				setBankKeyStyle(keyName, "Cue")
				if not waitForBankServerTime(token, cueEnd) then
					return
				end
				setBankKeyStyle(keyName, "Idle")
			end
		end
		if not waitForBankServerTime(token, inputOpensAt) then
			return
		end
		bankPhase = "AwaitInput"
		setAllBankKeys("Ready")
		setBankMode("YOUR TURN // REPEAT THE PATTERN", Color3.fromRGB(111, 238, 255))
		bankSignal.Text = "● TRANSMIT READY"
		bankSignal.TextColor3 = Color3.fromRGB(111, 238, 255)
		updateBankInputProgress()
		refreshBankStartButton()
		if UserInputService.GamepadEnabled and bankKeyVisuals.Q then
			GuiService.SelectedObject = bankKeyVisuals.Q.button
		end
	end)
end

submitBankKey = function(keyName)
	if terminalPage ~= "Bank"
		or not bankPanel.Visible
		or bankPhase ~= "AwaitInput"
		or bankInputPending
		or bankSessionId == nil
		or not bankKeyVisuals[keyName]
	then
		return
	end
	bankInputPending = true
	bankLastInputKey = keyName
	local visual = bankKeyVisuals[keyName]
	visual.pulseSerial = (visual.pulseSerial or 0) + 1
	setBankKeyStyle(keyName, "Pressed")
	bankSignal.Text = "● VERIFYING " .. keyName
	bankSignal.TextColor3 = Color3.fromRGB(111, 238, 255)
	bankHackEvent:FireServer("Input", {
		sessionId = bankSessionId,
		key = keyName,
	})
end

local function closeComputer(notifyServer)
	resetBankAttempt(notifyServer ~= false)
	unbindBankInputs()
	if dosInput and dosInput.Parent and dosInput:IsFocused() then
		dosInput:ReleaseFocus(false)
	end
	bankPanel.Visible = false
	terminal.Visible = false
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(terminal) then
		GuiService.SelectedObject = nil
	end
	upgradeNoticeUi.terminalVisible = false
	gui.DisplayOrder = introScrim.Visible and 65 or 35
	upgradeNoticeUi.setControlsLocked(introScrim.Visible)
	if notifyServer ~= false then
		requestEvent:FireServer("CloseComputer")
	end
end

function upgradeNoticeUi.clearTerminalSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(terminal) then
		GuiService.SelectedObject = nil
	end
end

function upgradeNoticeUi.focusTerminalDefault()
	if not terminal.Visible or not UserInputService.GamepadEnabled then
		return
	end
	if terminalPage == "Bank" then
		GuiService.SelectedObject = if bankStartButton.Active and bankStartButton.Selectable
			then bankStartButton
			else terminalBack
		return
	end
	GuiService.SelectedObject = upgradeNoticeUi.terminalFirstSelectable
		or (terminalBack.Visible and terminalBack)
		or terminalClose
end

local function clearTerminalControls()
	upgradeNoticeUi.clearTerminalSelection()
	upgradeNoticeUi.terminalFirstSelectable = nil
	for _, child in ipairs(terminalButtons:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local renderTerminal
local function treeLine(text, selectable, callback)
	local row = Instance.new("TextButton")
	row.Name = "TreeLine"
	row.Size = UDim2.new(1, 0, 0, selectable and (upgradeNoticeUi.compactLayout and 52 or 46) or (upgradeNoticeUi.compactLayout and 30 or 26))
	row.BackgroundColor3 = selectable and Color3.fromRGB(8, 42, 22) or Color3.fromRGB(3, 10, 6)
	row.BackgroundTransparency = selectable and 0.05 or 1
	row.AutoButtonColor = false
	row.Active = selectable
	row.Selectable = selectable
	row.Text = text
	row.Font = Enum.Font.RobotoMono
	row.TextSize = selectable and 17 or 14
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextYAlignment = Enum.TextYAlignment.Center
	row.TextWrapped = true
	row.TextColor3 = selectable and Color3.fromRGB(190, 255, 210) or Color3.fromRGB(79, 150, 99)
	row.TextStrokeTransparency = 1
	row.ZIndex = 63
	row.Parent = terminalButtons
	if selectable and callback then
		if not upgradeNoticeUi.terminalFirstSelectable then
			upgradeNoticeUi.terminalFirstSelectable = row
		end
		corner(row, 8)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 18)
		padding.PaddingRight = UDim.new(0, 14)
		padding.Parent = row
		local accent = Instance.new("Frame")
		accent.Name = "TerminalAccent"
		-- UIPadding also offsets child controls, so compensate here to keep the
		-- accent in the left gutter instead of covering the first letter.
		accent.Position = UDim2.fromOffset(-12, 7)
		accent.Size = UDim2.new(0, 4, 1, -14)
		accent.BackgroundColor3 = Color3.fromRGB(77, 218, 120)
		accent.BackgroundTransparency = 0.16
		accent.BorderSizePixel = 0
		accent.ZIndex = 64
		accent.Parent = row
		corner(accent, 2)
		local outline = stroke(row, Color3.fromRGB(46, 157, 82), 1.5, 0.12)
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		row.MouseEnter:Connect(function()
			row.BackgroundTransparency = 0
			row.BackgroundColor3 = Color3.fromRGB(10, 61, 30)
			accent.BackgroundColor3 = Color3.fromRGB(142, 255, 174)
			accent.BackgroundTransparency = 0
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundTransparency = 0.05
			row.BackgroundColor3 = Color3.fromRGB(8, 42, 22)
			accent.BackgroundColor3 = Color3.fromRGB(77, 218, 120)
			accent.BackgroundTransparency = 0.16
		end)
		row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				row.BackgroundTransparency = 0
				row.BackgroundColor3 = Color3.fromRGB(17, 83, 43)
				accent.BackgroundColor3 = Color3.fromRGB(205, 255, 219)
				accent.BackgroundTransparency = 0
			end
		end)
		row.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				row.BackgroundTransparency = 0.05
				row.BackgroundColor3 = Color3.fromRGB(8, 42, 22)
				accent.BackgroundColor3 = Color3.fromRGB(77, 218, 120)
				accent.BackgroundTransparency = 0.16
			end
		end)
		row.SelectionGained:Connect(function()
			outline.Color = Color3.fromRGB(154, 255, 184)
			outline.Thickness = 2
		end)
		row.SelectionLost:Connect(function()
			outline.Color = Color3.fromRGB(46, 157, 82)
			outline.Thickness = 1.5
		end)
		row.Activated:Connect(callback)
	end
	return row
end

local function treeFolder(prefix, name)
	treeLine(prefix .. name .. string.char(92), false)
end

local function treeFile(prefix, branch, fileName, callback)
	return treeLine(fileName, true, callback)
end

function upgradeNoticeUi.creditCard(text)
	-- Selectable no-op cards let keyboard/gamepad focus auto-scroll long credits
	-- without introducing a remote action or an external-link interaction.
	local row = treeLine(text, true, function() end)
	row.Name = "CreditCard"
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 0)
	row.TextYAlignment = Enum.TextYAlignment.Top
	row.TextSize = upgradeNoticeUi.compactLayout and 14 or 15
	local padding = row:FindFirstChildOfClass("UIPadding")
	if padding then
		padding.PaddingTop = UDim.new(0, 12)
		padding.PaddingBottom = UDim.new(0, 12)
	end
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(0, upgradeNoticeUi.compactLayout and 76 or 68)
	minimum.Parent = row
	return row
end

local function showPage(page)
	if terminalPage == "Bank" and page ~= "Bank" then
		resetBankAttempt(true)
		unbindBankInputs()
	end
	terminalPage = page
	if page == "Bank" then
		bindBankInputs()
	end
	-- Each terminal page owns its own reading position. In particular, the
	-- Credits entry sits near the bottom of the Home list on phones; carrying
	-- that scroll offset into Credits would open with the first card clipped.
	terminalButtons.CanvasPosition = Vector2.zero
	upgradeNoticeUi.updateScale()
	renderTerminal()
end

function partyUx.purchaseBlock(snapshot)
	if not partyUx.isActive(snapshot) then
		return partyUx.pauseLabel(snapshot)
	end
	if not partyUx.isHost(snapshot) then
		return "HOST ONLY • THE PARTY HOST MANAGES SHARED PURCHASES"
	end
	if partyUx.data(snapshot).canManageHouse == false then
		return "SHARED HOUSE CONTROLS TEMPORARILY UNAVAILABLE"
	end
	return nil
end

function partyUx.purchaseExplanation(snapshot)
	if not partyUx.isActive(snapshot) then
		return partyUx.pauseDetail(snapshot)
	end
	local party = partyUx.data(snapshot)
	if party.isHost == true and party.canManageHouse == false then
		return "The server is protecting shared progress while a party profile finishes loading or saving. Please wait a moment."
	end
	local hostName = partyUx.memberName(party.hostUserId, "the party host")
	return string.format(
		"%s manages shared house purchases. Your $%d personal allowance stays on your profile.",
		hostName,
		math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
	)
end

function renderTerminal()
	clearTerminalControls()
	terminalBack.Visible = terminalPage ~= "Home"
	terminalTreeHeader.Text = terminalPage == "Home" and "CHOOSE AN ACTION" or "PAGE OPTIONS"
	dosInput = nil
	local snapshot = currentSnapshot or {}
	local taskData = snapshot.task
	local showingBank = terminalPage == "Bank"
	terminalBody.Visible = not showingBank
	terminalTreePanel.Visible = not showingBank
	bankPanel.Visible = showingBank
	if showingBank then
		terminalTitle.Text = "COOPER TERMINAL // HACK MEDFORD BANK"
		updateBankSnapshot(snapshot)
		upgradeNoticeUi.focusTerminalDefault()
		return
	elseif terminalPage == "Home" then
		terminalTitle.Text = "COOPER TERMINAL // MAIN MENU"
		terminalBody.Text = "COOPER-DOS 3.11" .. string.char(10) .. "MEDFORD, TEXAS" .. string.char(10) .. string.char(10)
			.. "Choose an action on the right." .. string.char(10) .. string.char(10)
			.. "Each button says exactly what it does."
		treeFile("", true, "Order Beer", function()
			showPage("Beer")
		end)
		treeFile("", true, "Buy Time Machine Parts (Host)", function()
			showPage("Machine")
		end)
		treeFile("", true, "Buy Task Robots (Host)", function()
			showPage("Automation")
		end)
		treeFile("", true, "Buy / Upgrade Party Boombox (Host)", function()
			showPage("Boombox")
		end)
		treeFile("", true, "Secret Underground Bunker (Host)", function()
			showPage("SecretBunker")
		end)
		treeFile("", true, "Hack Medford Bank", function()
			showPage("Bank")
		end)
		treeFile("", true, "Type Commands (Optional)", function()
			showPage("DOS")
		end)
		treeFile("", true, "Credits", function()
			showPage("Credits")
		end)
		treeFile("", false, "Exit Computer", function()
			closeComputer(true)
		end)
	elseif terminalPage == "Beer" then
		terminalTitle.Text = "COOPER TERMINAL // ORDER BEER"
		treeLine("BEER DELIVERY", false)
		if not partyUx.isActive(snapshot) then
			terminalBody.Text = partyUx.pauseLabel(snapshot) .. string.char(10)
				.. partyUx.pauseDetail(snapshot)
			treeLine(partyUx.pauseLabel(snapshot), false).TextColor3 = COLORS.orange
		elseif taskData and taskData.id == "GeorgeBeer" and not partyUx.ownsCarrier(taskData) then
			local carrierName = partyUx.memberName(taskData.carrierUserId, "A teammate")
			terminalBody.Text = carrierName .. " is carrying George's beer for the shared task."
			treeLine("TEAMMATE HANDLING DELIVERY", false).TextColor3 = COLORS.yellow
		elseif taskData and taskData.id == "GeorgeBeer" and taskData.step == "Order" and not taskIsAutomated(taskData) then
			terminalBody.Text = "LONE STAR BEER CASE" .. string.char(10) .. "George's tab covers delivery." .. string.char(10) .. "Truck drops the crate in the driveway."
			treeFile("", true, "Order Beer Delivery", function()
				requestEvent:FireServer("OrderBeer")
			end)
		elseif taskData and taskData.id == "GeorgeBeer" then
			terminalBody.Text = tostring(taskData.description or "Delivery in progress.")
			treeLine("DELIVERY ALREADY IN PROGRESS", false).TextColor3 = COLORS.yellow
		else
			terminalBody.Text = "NO ACTIVE BEER REQUEST" .. string.char(10) .. "George has not asked for a delivery."
			treeLine("NO BEER DELIVERY NEEDED YET", false)
		end
	elseif terminalPage == "Machine" then
		terminalTitle.Text = "COOPER TERMINAL // TIME MACHINE PARTS"
		treeLine("TIME MACHINE PARTS", false)
		local nextPart = snapshot.nextMachinePart
		if not nextPart then
			terminalBody.Text = "CONSTRUCTION COMPLETE" .. string.char(10) .. "The Time Machine is at 100%."
		elseif snapshot.delivery then
			local pendingKind = tostring(snapshot.delivery.kind or "MachinePart")
			local pendingName = tostring(snapshot.delivery.name or (pendingKind == "Boombox" and "Party Boombox" or "component"))
			terminalBody.Text = "PENDING DELIVERY:" .. string.char(10) .. pendingName
				.. string.char(10) .. string.char(10)
				.. (partyUx.isHost(snapshot)
					and "Finish the current delivery before ordering another crate."
					or "The party host is handling this shared delivery.")
		else
			terminalBody.Text = string.format(
				"NEXT: %s" .. string.char(10) .. "PROGRESS: %d%%" .. string.char(10) .. "COST: $%d" .. string.char(10) .. "MY ALLOWANCE: $%d",
				tostring(nextPart.name),
				tonumber(nextPart.progress) or 0,
				tonumber(nextPart.cost) or 0,
				tonumber(snapshot.allowance) or 0
			)
			local partCost = math.max(0, math.floor(tonumber(nextPart.cost) or 0))
			local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
			local authorityBlock = partyUx.purchaseBlock(snapshot)
			if authorityBlock then
				terminalBody.Text ..= string.char(10) .. string.char(10) .. partyUx.purchaseExplanation(snapshot)
				treeLine(authorityBlock, false).TextColor3 = partyUx.isActive(snapshot) and COLORS.yellow or COLORS.orange
			elseif nextPart.canOrder == true and allowance >= partCost then
				treeFile("", false, "Buy " .. tostring(nextPart.name) .. " — $" .. tostring(partCost), function()
					requestEvent:FireServer("OrderMachinePart")
				end)
			elseif allowance < partCost then
				treeLine("NEED $" .. tostring(partCost - allowance) .. " MORE", false).TextColor3 = COLORS.red
			else
				treeLine("ORDERING TEMPORARILY BLOCKED", false).TextColor3 = COLORS.red
			end
		end
	elseif terminalPage == "Automation" then
		terminalTitle.Text = "COOPER TERMINAL // TASK ROBOTS"
		local automation = automationData(snapshot)
		local catalog = automationCatalog(snapshot)
		local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
		local installedCount = math.max(0, math.floor(tonumber(automation.installedCount) or 0))
		local totalCount = math.max(#catalog, math.floor(tonumber(automation.totalCount) or #catalog))
		local authorityBlock = partyUx.purchaseBlock(snapshot)

		treeLine("TASK ROBOTS", false)
		if #catalog == 0 then
			automationSelectedId = nil
			terminalBody.Text = "TASK AUTOMATION" .. string.char(10)
				.. "Catalog is waiting for the Cooper server." .. string.char(10) .. string.char(10)
				.. "Five task robots will appear here when the profile snapshot arrives."
			treeLine("ROBOT CATALOG LOADING...", false)
		else
			local selected = automationEntry(snapshot, automationSelectedId)
			if not selected then
				selected = catalog[1]
				automationSelectedId = tostring(selected.id or "")
			end

			local selectedTitle, selectedReward, selectedRequester = taskRole(selected.taskId)
			selectedReward = math.max(0, math.floor(tonumber(selected.reward) or selectedReward))
			local selectedPrice = math.max(0, math.floor(tonumber(selected.price) or 0))
			local selectedPending = automationEntryPending(snapshot, selected)
			local selectedState = if selected.installed == true
				then "INSTALLED / RUNS AUTOMATICALLY"
				elseif selectedPending
				then (partyUx.isHost(snapshot) and "DELIVERY / SETUP IN PROGRESS" or "HOST DELIVERY IN PROGRESS")
				elseif authorityBlock
				then authorityBlock
				elseif allowance < selectedPrice
				then "NEED $" .. tostring(selectedPrice - allowance) .. " MORE"
				elseif selected.canOrder == false
				then (snapshot.delivery and "FINISH CURRENT DELIVERY" or "ORDERING TEMPORARILY BLOCKED")
				else "AVAILABLE TO ORDER"
			local selectedDuration = math.max(0, math.floor(tonumber(selected.duration) or 0))
			local durationLine = selectedDuration > 0
				and (string.char(10) .. "ROBOT WORK TIME: " .. tostring(selectedDuration) .. " SECONDS")
				or ""
			terminalBody.Text = string.format(
				"TASK AUTOMATION" .. string.char(10)
					.. "INSTALLED: %d/%d" .. string.char(10)
					.. "MY ALLOWANCE: $%d" .. string.char(10) .. string.char(10)
					.. "%s" .. string.char(10)
					.. "%s" .. string.char(10) .. string.char(10)
					.. "TASK: %s FOR %s" .. string.char(10)
					.. "AUTOMATIC REWARD: +$%d" .. string.char(10)
					.. "PRICE: $%d%s" .. string.char(10)
					.. "STATUS: %s" .. string.char(10) .. string.char(10)
					.. "Order a robot, collect its truck crate, then follow its colored arrow. Entering the marked setup area installs it automatically.",
				installedCount,
				totalCount,
				allowance,
				tostring(selected.name or "Task Robot"),
				tostring(selected.description or "Automatically completes this family task whenever it comes up."),
				selectedTitle,
				string.upper(selectedRequester),
				selectedReward,
				selectedPrice,
				durationLine,
				selectedState
			)

			treeLine("CHOOSE A ROBOT TO SEE ITS DETAILS", false)
			for index, entry in ipairs(catalog) do
				if type(entry) == "table" then
					local entryId = tostring(entry.id or ("Upgrade" .. tostring(index)))
					local entryName = tostring(entry.name or "Task Robot")
					local price = math.max(0, math.floor(tonumber(entry.price) or 0))
					local pending = automationEntryPending(snapshot, entry)
					local stateLabel = "$" .. tostring(price)
					local stateColor = COLORS.terminal
					if entry.installed == true then
						stateLabel = "INSTALLED"
						stateColor = COLORS.green
					elseif pending then
						local delivery = type(snapshot.delivery) == "table" and snapshot.delivery or {}
						local deliveryStatus = tostring(delivery.status or "WaitingDelivery")
						stateLabel = if not partyUx.isHost(snapshot)
							then "HOST DELIVERY"
							elseif deliveryStatus == "Collect"
							then "PICK UP CRATE"
							elseif deliveryStatus == "Install"
							then "SET IT UP"
							else "TRUCK EN ROUTE"
						stateColor = COLORS.yellow
					elseif authorityBlock then
						stateLabel = partyUx.isHost(snapshot) and "PAUSED" or "HOST ONLY"
						stateColor = partyUx.isActive(snapshot) and COLORS.yellow or COLORS.orange
					elseif allowance < price then
						stateLabel = "NEED $" .. tostring(price - allowance)
						stateColor = COLORS.red
					elseif entry.canOrder == false then
						stateLabel = snapshot.delivery and "FINISH DELIVERY" or "UNAVAILABLE"
						stateColor = COLORS.red
					end

					local row = treeLine((entryId == automationSelectedId and "●  " or "") .. entryName, true, function()
						automationSelectedId = entryId
						renderTerminal()
					end)
					local rowPadding = row:FindFirstChildOfClass("UIPadding")
					if rowPadding then
						rowPadding.PaddingRight = UDim.new(0, 202)
					end
					local statusBadge = label(
						row,
						"StatusBadge",
						stateLabel,
						UDim2.fromOffset(176, 28),
						UDim2.new(1, -188, 0.5, -14),
						Enum.Font.RobotoMono,
						13,
						stateColor,
						Enum.TextXAlignment.Center
					)
					statusBadge.BackgroundColor3 = Color3.fromRGB(3, 18, 10)
					statusBadge.BackgroundTransparency = 0.08
					statusBadge.TextWrapped = false
					statusBadge.TextStrokeTransparency = 1
					statusBadge.ZIndex = 64
					corner(statusBadge, 5)
					stroke(statusBadge, stateColor, 1, 0.35)
				end
			end

			treeLine("SELECTED ROBOT", false)
			if selected.installed == true then
				treeLine("INSTALLED — THIS TASK NOW RUNS AUTOMATICALLY", false).TextColor3 = COLORS.green
			elseif selectedPending then
				treeLine(
					partyUx.isHost(snapshot)
						and "FINISH THE DELIVERY AND FOLLOW ITS SETUP ARROW"
						or "THE PARTY HOST IS HANDLING THIS DELIVERY",
					false
				).TextColor3 = COLORS.yellow
			elseif authorityBlock then
				treeLine(authorityBlock, false).TextColor3 = partyUx.isActive(snapshot) and COLORS.yellow or COLORS.orange
				treeLine(partyUx.purchaseExplanation(snapshot), false)
			elseif allowance < selectedPrice then
				treeLine("NEED $" .. tostring(selectedPrice - allowance) .. " MORE", false).TextColor3 = COLORS.red
			elseif selected.canOrder == false then
				local blockedText = snapshot.delivery and "FINISH YOUR CURRENT DELIVERY FIRST" or "ROBOT TEMPORARILY UNAVAILABLE"
				treeLine(blockedText, false).TextColor3 = COLORS.red
			else
				treeFile("", false, "Buy " .. tostring(selected.name or "Task Robot") .. " — $" .. tostring(selectedPrice), function()
					requestEvent:FireServer("OrderTaskUpgrade", {
						upgradeId = tostring(selected.id or automationSelectedId or ""),
					})
				end)
			end
		end

		local boombox = type(snapshot.boombox) == "table" and snapshot.boombox or {}
		local autoplayPrice = math.max(1, math.floor(tonumber(boombox.autoplayPrice) or 1250))
		local autoplayState
		local autoplayColor = COLORS.terminal
		if boombox.autoplayPurchased == true then
			autoplayState = "INSTALLED / ARMED"
			autoplayColor = COLORS.green
		elseif authorityBlock then
			autoplayState = partyUx.isHost(snapshot) and "PAUSED" or "HOST ONLY"
			autoplayColor = partyUx.isActive(snapshot) and COLORS.yellow or COLORS.orange
		elseif boombox.purchased ~= true then
			autoplayState = "BUY BOOMBOX FIRST"
			autoplayColor = COLORS.red
		elseif boombox.placed ~= true then
			autoplayState = "SET UP BOOMBOX FIRST"
			autoplayColor = COLORS.yellow
		elseif allowance < autoplayPrice then
			autoplayState = "NEED $" .. tostring(autoplayPrice - allowance)
			autoplayColor = COLORS.red
		elseif boombox.canUpgradeAutoplay ~= true then
			autoplayState = "TEMPORARILY UNAVAILABLE"
			autoplayColor = COLORS.red
		else
			autoplayState = "AVAILABLE"
		end
		treeLine("BOOMBOX AUTOPLAY — " .. autoplayState, false).TextColor3 = autoplayColor
		if boombox.autoplayPurchased ~= true
			and boombox.purchased == true
			and boombox.placed == true
			and not authorityBlock
			and boombox.canUpgradeAutoplay == true
			and allowance >= autoplayPrice
		then
			treeFile("", false, "Buy Boombox Autoplay — $" .. tostring(autoplayPrice), function()
				requestEvent:FireServer("UpgradeBoomboxAutoplay")
			end)
		end
	elseif terminalPage == "Boombox" then
		terminalTitle.Text = "COOPER TERMINAL // PARTY BOOMBOX"
		treeLine("PARTY BOOMBOX", false)
		local boombox = type(snapshot.boombox) == "table" and snapshot.boombox or {}
		local price = math.max(1, math.floor(tonumber(boombox.price) or 350))
		local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
		local status = boomboxStatus(snapshot)
		local authorityBlock = partyUx.purchaseBlock(snapshot)
		if status == "Unowned" then
			local maximumPayout = math.max(0, math.floor(tonumber(boombox.maximumPayout) or 0))
			local earningsLine = maximumPayout > 0
				and ("Earn up to $" .. tostring(maximumPayout) .. " during each full song.")
				or "Earn automatic allowance during each full song."
			terminalBody.Text = string.format(
				"COOPER PARTY BOOMBOX" .. string.char(10)
					.. "PRICE: $%d" .. string.char(10)
					.. "MY ALLOWANCE: $%d" .. string.char(10) .. string.char(10)
					.. "Delivered by truck. Set it up in the living room. " .. earningsLine,
				price,
				allowance
			)
			if authorityBlock then
				terminalBody.Text ..= string.char(10) .. string.char(10) .. partyUx.purchaseExplanation(snapshot)
				treeLine(authorityBlock, false).TextColor3 = partyUx.isActive(snapshot) and COLORS.yellow or COLORS.orange
			elseif snapshot.delivery or boombox.canOrder == false then
				treeLine("FINISH YOUR CURRENT DELIVERY FIRST", false)
			elseif allowance < price then
				treeLine("NEED $" .. tostring(price - allowance) .. " MORE", false).TextColor3 = COLORS.red
			else
				treeFile("", false, "Buy Party Boombox — $" .. tostring(price), function()
					requestEvent:FireServer("OrderBoombox")
				end)
			end
		elseif status == "WaitingDelivery" or status == "Ordered" then
			terminalBody.Text = "BOOMBOX PURCHASED" .. string.char(10)
				.. "STATUS: DELIVERY TRUCK EN ROUTE" .. string.char(10) .. string.char(10)
				.. (partyUx.isHost(snapshot)
					and "Meet the truck at the driveway when it arrives."
					or "The party host will collect this shared delivery.")
			treeLine("DELIVERY PENDING", false)
		elseif status == "Collect" then
			terminalBody.Text = "BOOMBOX DELIVERED" .. string.char(10)
				.. "STATUS: WAITING IN DRIVEWAY" .. string.char(10) .. string.char(10)
				.. (partyUx.isHost(snapshot)
					and "Pick up the boombox crate from the driveway."
					or "The crate is reserved for the party host.")
			treeLine(partyUx.isHost(snapshot) and "PICK UP THE BOOMBOX" or "HOST WILL PICK UP BOOMBOX", false)
		elseif status == "Setup" or status == "Carried" then
			terminalBody.Text = "BOOMBOX IN HAND" .. string.char(10)
				.. "STATUS: SETUP REQUIRED" .. string.char(10) .. string.char(10)
				.. (partyUx.isHost(snapshot)
					and "Follow the purple arrow into the living room. It sets itself up automatically when you enter the marked area."
					or "The party host is carrying and setting up this shared item.")
			treeLine(partyUx.isHost(snapshot) and "FOLLOW THE PURPLE SETUP ARROW" or "HOST IS SETTING UP BOOMBOX", false)
		elseif status == "Playing" then
			terminalBody.Text = "BOOMBOX INSTALLED" .. string.char(10)
				.. "STATUS: NOW PLAYING" .. string.char(10) .. string.char(10)
				.. "Disco lights are running. Allowance is earned automatically while the song plays."
			treeLine("PARTY IN PROGRESS", false)
		elseif status == "Busy" then
			terminalBody.Text = "BOOMBOX INSTALLED" .. string.char(10)
				.. "STATUS: IN USE" .. string.char(10) .. string.char(10)
				.. "Someone else is using the shared living-room boombox. Their song is playing; your allowance is not earning during their session."
			treeLine("WAIT FOR THE CURRENT SONG", false)
		elseif status == "Cooldown" then
			local remaining = boomboxCooldownRemaining(snapshot)
			terminalBody.Text = "BOOMBOX INSTALLED" .. string.char(10)
				.. "STATUS: COOLING DOWN" .. string.char(10)
				.. "READY IN: " .. formatCountdown(remaining) .. string.char(10) .. string.char(10)
				.. (partyUx.isHost(snapshot)
					and "Come back to the living-room boombox when the timer reaches zero."
					or "The party host can start the next shared session when this reaches zero.")
			treeLine("READY AGAIN IN " .. formatCountdown(remaining), false)
		else
			terminalBody.Text = "BOOMBOX INSTALLED" .. string.char(10)
				.. "STATUS: READY" .. string.char(10) .. string.char(10)
				.. (partyUx.isHost(snapshot)
					and "Use the power button in the living room to start the music, disco lights, and automatic allowance."
					or "The shared boombox is ready. The party host controls its power button.")
			treeLine(partyUx.isHost(snapshot) and "USE THE LIVING-ROOM POWER BUTTON" or "WAITING FOR PARTY HOST", false)
		end
		if boombox.placed == true then
			local autoplayPrice = math.max(1, math.floor(tonumber(boombox.autoplayPrice) or 1250))
			if boombox.autoplayPurchased == true then
				terminalBody.Text ..= string.char(10) .. string.char(10)
					.. "AUTOPLAY: INSTALLED / ARMED" .. string.char(10)
					.. "The boombox will start automatically whenever your cooldown reaches zero while you are online."
				treeLine("AUTOPLAY INSTALLED / ARMED", false)
			else
				terminalBody.Text ..= string.char(10) .. string.char(10)
					.. string.format("AUTOPLAY UPGRADE: $%d", autoplayPrice) .. string.char(10)
					.. "Automatically starts the same full music, dance, lights, and allowance session whenever your cooldown finishes while you are online."
				if authorityBlock then
					treeLine(authorityBlock, false).TextColor3 = partyUx.isActive(snapshot) and COLORS.yellow or COLORS.orange
				elseif boombox.canUpgradeAutoplay == true and allowance >= autoplayPrice then
					treeFile("", false, string.format("Buy Boombox Autoplay — $%d", autoplayPrice), function()
						requestEvent:FireServer("UpgradeBoomboxAutoplay")
					end)
				elseif allowance < autoplayPrice then
					treeLine("NEED $" .. tostring(autoplayPrice - allowance) .. " MORE", false).TextColor3 = COLORS.red
				else
					treeLine("UPGRADE TEMPORARILY UNAVAILABLE", false).TextColor3 = COLORS.red
				end
			end
		end
	elseif terminalPage == "SecretBunker" then
		terminalTitle.Text = "COOPER TERMINAL // SECRET UNDERGROUND BUNKER"
		treeLine("SECRET UNDERGROUND BUNKER", false)
		local secretBunker = type(snapshot.secretBunker) == "table" and snapshot.secretBunker or {}
		local price = math.max(1, math.floor(tonumber(secretBunker.price) or 2500))
		local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
		local status = tostring(secretBunker.status or "Loading")
		local authorityBlock = partyUx.purchaseBlock(snapshot)
		if secretBunker.unlocked == true or status == "Unlocked" then
			terminalBody.Text = "SECRET UNDERGROUND BUNKER" .. string.char(10)
				.. "STATUS: ONLINE / ACCESS GRANTED" .. string.char(10) .. string.char(10)
				.. "The backyard bunker is complete. This opens the next major phase of the game and a future underground money-making operation."
			treeLine("BUNKER READY", false).TextColor3 = COLORS.green
		elseif secretBunker.purchased == true or status == "Construction" then
			local remaining = secretBunkerConstructionRemaining(snapshot)
			terminalBody.Text = "SECRET UNDERGROUND BUNKER" .. string.char(10)
				.. "STATUS: HEAVY CONSTRUCTION ACTIVE" .. string.char(10)
				.. "ESTIMATED COMPLETION: " .. formatCountdown(remaining) .. string.char(10) .. string.char(10)
				.. "Construction vehicles, excavation equipment, and a mobile crane are working in the backyard. The work zone will clear automatically when the bunker is ready."
			treeLine("CONSTRUCTION — " .. formatCountdown(remaining) .. " REMAINING", false).TextColor3 = COLORS.yellow
		else
			terminalBody.Text = string.format(
				"SECRET UNDERGROUND BUNKER" .. string.char(10)
					.. "PRICE: $%d" .. string.char(10)
					.. "MY ALLOWANCE: $%d" .. string.char(10) .. string.char(10)
					.. "Buy a full backyard excavation, reinforced underground shelter, and future chemistry workspace. A professional construction convoy will build it on site.",
				price,
				allowance
			)
			if authorityBlock then
				terminalBody.Text ..= string.char(10) .. string.char(10) .. partyUx.purchaseExplanation(snapshot)
				treeLine(authorityBlock, false).TextColor3 = partyUx.isActive(snapshot) and COLORS.yellow or COLORS.orange
			elseif allowance < price then
				treeLine("NEED $" .. tostring(price - allowance) .. " MORE", false).TextColor3 = COLORS.red
			elseif secretBunker.canOrder == true then
				treeFile("", false, "Buy Secret Underground Bunker — $" .. tostring(price), function()
					requestEvent:FireServer("OrderSecretBunker")
				end)
			else
				treeLine("PURCHASE TEMPORARILY UNAVAILABLE", false).TextColor3 = COLORS.red
			end
		end
	elseif terminalPage == "Credits" then
		terminalTitle.Text = "COOPER TERMINAL // CREDITS"
		terminalBody.Text = "Unofficial parody; not endorsed by the actors, CBS, or the rights holders."
			.. string.char(10) .. string.char(10)
			.. "Photos are cropped by Roblox UI; parody captions are added separately." .. string.char(10) .. string.char(10)
			.. "Select each card to scroll. Full source and license links are recorded with the project."
		terminalTreeHeader.Text = "PHOTO ATTRIBUTIONS"
		local newline = string.char(10)
		upgradeNoticeUi.creditCard("SHELDON / IAIN ARMITAGE" .. newline .. "Iain Armitage (2019).png" .. newline
			.. "White Pony Express • CC BY 3.0" .. newline .. "Source: Wikimedia Commons")
		upgradeNoticeUi.creditCard("GEORGE / LANCE BARBER" .. newline .. "Lance Barber at Fan Expo Denver 2026.jpg" .. newline
			.. "SpiritedMichelle • CC BY-SA 4.0" .. newline .. "Source: Wikimedia Commons")
		upgradeNoticeUi.creditCard("MISSY / RAEGAN REVORD" .. newline .. "Raegan Revord - LATFOB 2026-01.jpg" .. newline
			.. "Kevin Paul (PaulLim11) • CC BY 4.0" .. newline .. "Source: Wikimedia Commons")
		upgradeNoticeUi.creditCard("GEORGIE / MONTANA JORDAN" .. newline .. "Montana Jordan - Los Angeles Comic Con 2025.jpg" .. newline
			.. "Kevin Paul (PaulLim11) • CC BY 4.0" .. newline .. "Source: Wikimedia Commons")
		upgradeNoticeUi.creditCard("MARY / ZOE PERRY" .. newline .. "Zoe Perry at Fan Expo Denver 2026.jpg" .. newline
			.. "SpiritedMichelle • CC BY-SA 4.0" .. newline .. "Source: Wikimedia Commons")
		upgradeNoticeUi.creditCard("MEEMAW / ANNIE POTTS" .. newline .. "Annie Potts (53705697262).jpg" .. newline
			.. "Louise Palanker • CC BY-SA 2.0" .. newline .. "Source: Wikimedia Commons")
	elseif terminalPage == "DOS" then
		terminalTitle.Text = "COOPER TERMINAL // OPTIONAL COMMANDS"
		treeLine("OPTIONAL COMMAND MODE", false)
		terminalBody.Text = "This page is optional." .. string.char(10) .. string.char(10)
			.. "Type HELP, DIR, VER, or TIME." .. string.char(10)
			.. "You can use every important feature with the simple buttons on the main menu."
		dosInput = Instance.new("TextBox")
		dosInput.Name = "DOSInput"
		dosInput.Size = UDim2.new(1, -8, 0, UserInputService.TouchEnabled and 46 or 34)
		dosInput.BackgroundColor3 = Color3.fromRGB(8, 24, 14)
		dosInput.TextColor3 = COLORS.terminal
		dosInput.PlaceholderText = "C:" .. string.char(92) .. ">"
		dosInput.Font = Enum.Font.RobotoMono
		dosInput.TextSize = 18
		dosInput.Text = ""
		dosInput.ZIndex = 63
		dosInput.Parent = terminalButtons
		corner(dosInput, 4)
		stroke(dosInput, Color3.fromRGB(34, 78, 52), 1, 0.2)
		treeFile("", false, "Run Command", function()
			if dosInput then
				requestEvent:FireServer("LegacyCommand", dosInput.Text)
				dosInput.Text = ""
			end
		end)
		dosInput.FocusLost:Connect(function(enter)
			if enter and dosInput then
				requestEvent:FireServer("LegacyCommand", dosInput.Text)
				dosInput.Text = ""
			end
		end)
	end
	upgradeNoticeUi.focusTerminalDefault()
end

bankStartButton.Activated:Connect(function()
	if terminalPage ~= "Bank" or bankAttemptActive() or not bankSnapshotCanStart then
		return
	end
	bankAnimationToken += 1
	bankSessionId = nil
	bankPhase = "Connecting"
	bankInputPending = false
	bankInputIndex = 0
	bankPatternLength = 0
	setBankRoundDisplay(0, 0)
	updateBankInputProgress()
	setAllBankKeys("Idle")
	setBankMode("DIALING MEDFORD BANK // NEGOTIATING CIPHER", COLORS.yellow)
	bankSignal.Text = "● DIALING..."
	bankSignal.TextColor3 = COLORS.yellow
	refreshBankStartButton()
	bankHackEvent:FireServer("Start")
end)

terminalBack.Activated:Connect(function()
	showPage("Home")
end)
terminalClose.Activated:Connect(function()
	closeComputer(true)
end)

-- Hidden plushes and bank notes ---------------------------------------------

local hiddenVisual = nil
local hiddenPrompt = nil
local hiddenSignature = ""
local homeToyPromptStates = setmetatable({}, { __mode = "k" })

local function homeToy(name)
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local item = environment and environment:FindFirstChild(name, true)
	return item and item:IsA("Model") and item or nil
end

local function setHomeToyHidden(plushKind, hidden)
	local name = plushKind == "Rabbit" and "MissyDetailedRabbit" or "MissyDetailedTeddyBear"
	local toy = homeToy(name)
	if not toy then
		return
	end
	for _, descendant in ipairs(toy:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = hidden and 1 or 0
		elseif descendant:IsA("ProximityPrompt") and descendant.Name == "CooperPickupPrompt" then
			if hidden then
				if homeToyPromptStates[descendant] == nil then
					homeToyPromptStates[descendant] = descendant.Enabled
				end
				descendant.Enabled = false
			else
				local previous = homeToyPromptStates[descendant]
				if previous ~= nil then
					descendant.Enabled = previous
					homeToyPromptStates[descendant] = nil
				end
			end
		end
	end
end

local function clearHiddenVisual()
	if hiddenPrompt then
		hiddenPrompt:Destroy()
		hiddenPrompt = nil
	end
	if hiddenVisual then
		hiddenVisual:Destroy()
		hiddenVisual = nil
	end
end

local function createPrompt(parent, actionText, objectText, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CooperSupportedInteraction", true)
	prompt.Parent = parent
	prompt.Triggered:Connect(callback)
	return prompt
end

local function buildHiddenVisual(hiddenData)
	clearHiddenVisual()
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local marker = environment and environment:FindFirstChild(tostring(hiddenData.markerName or ""), true)
	if not marker or not marker:IsA("BasePart") then
		return
	end
	if hiddenData.kind == "Plush" then
		local sourceName = hiddenData.plushKind == "Rabbit" and "MissyDetailedRabbit" or "MissyDetailedTeddyBear"
		local source = homeToy(sourceName)
		if not source then
			return
		end
		local clone = source:Clone()
		clone.Name = "LocalHiddenPlush"
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = true
				descendant.LocalTransparencyModifier = 0
			elseif descendant:IsA("ProximityPrompt") then
				descendant:Destroy()
			end
		end
		clone.Parent = workspace
		clone:PivotTo(marker.CFrame)
		if clone.ScaleTo then
			pcall(function()
				clone:ScaleTo(0.82)
			end)
		end
		hiddenPrompt = createPrompt(marker, "Pick Up", "Missy's lost " .. tostring(hiddenData.plushKind), function()
			requestEvent:FireServer("HiddenSeen", { markerName = hiddenData.markerName })
		end)
		hiddenVisual = clone
	end
end

local function updateHidden(snapshot)
	local taskData = snapshot.task
	local automated = taskIsAutomated(taskData)
	local hiddenData = not automated and snapshot.hidden or nil
	local signature = hiddenData and table.concat({
		tostring(hiddenData.kind),
		tostring(hiddenData.markerName),
		tostring(hiddenData.plushKind),
	}, ":") or ""
	-- The robot suppresses the manual hidden clone/prompt, but the selected toy
	-- must still leave Missy's bed until Toy Finder returns it at completion.
	local activeToyRun = upgradeNoticeUi.automationRun(snapshot, "MissyPlush")
	local missingKind = taskData and taskData.id == "MissyPlush" and taskData.plushKind
		or (activeToyRun and activeToyRun.plushKind or nil)
	-- Only the selected stuffed animal leaves the bed. It stays absent while
	-- being carried, then reappears at its exact home transform after return.
	setHomeToyHidden("Rabbit", missingKind == "Rabbit")
	setHomeToyHidden("Teddy Bear", missingKind == "Teddy Bear")
	if signature == hiddenSignature then
		return
	end
	hiddenSignature = signature
	if hiddenData then
		buildHiddenVisual(hiddenData)
	else
		clearHiddenVisual()
	end
end

-- Ground-level guidance ------------------------------------------------------

local arrowModel = nil
local arrowTarget = nil
local arrowTargetHint = ""
local arrowTitle = ""
local arrowColor = COLORS.yellow
local arrowParts = nil
local arrowResolveScheduled = false

local function clearArrow()
	if arrowModel then
		arrowModel:Destroy()
	end
	arrowModel = nil
	arrowTarget = nil
	arrowTargetHint = ""
	arrowTitle = ""
	arrowParts = nil
end

local function partFor(instance)
	if not instance then
		return nil
	elseif instance:IsA("ProximityPrompt") then
		return instance.Parent and (instance.Parent:IsA("BasePart") and instance.Parent or instance.Parent:FindFirstChildWhichIsA("BasePart", true))
	elseif instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	elseif instance:IsA("Tool") then
		return instance:FindFirstChild("Handle")
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function resolveTarget(hint)
	if not hint or hint == "" then
		return nil
	end
	local found = workspace:FindFirstChild(hint, true)
	return partFor(found)
end

local function makeGuidePart(parent, name, size, color)
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.CastShadow = false
	item.Material = Enum.Material.Neon
	item.Color = color
	item.Transparency = 0.22
	item.Size = size
	item.Parent = parent
	return item
end

local function createArrow(hint, title, color)
	clearArrow()
	arrowTargetHint = hint
	arrowTarget = resolveTarget(hint)
	if not arrowTarget then
		return
	end
	arrowColor = color
	arrowTitle = tostring(title or "TASK")
	arrowModel = Instance.new("Model")
	arrowModel.Name = "LocalTaskGuidance"
	arrowModel.Parent = workspace
	local center = makeGuidePart(arrowModel, "Destination", Vector3.new(0.55, 0.06, 0.55), color)
	center.Shape = Enum.PartType.Cylinder
	local ring = {}
	for index = 1, 10 do
		table.insert(ring, makeGuidePart(arrowModel, "Ring" .. index, Vector3.new(0.45, 0.06, 0.13), color))
	end
	local chevrons = {}
	for index = 1, 3 do
		table.insert(chevrons, {
			left = makeGuidePart(arrowModel, "ChevronL" .. index, Vector3.new(0.18, 0.07, 1), color),
			right = makeGuidePart(arrowModel, "ChevronR" .. index, Vector3.new(0.18, 0.07, 1), color),
			index = index,
		})
	end
	local anchor = makeGuidePart(arrowModel, "CaptionAnchor", Vector3.new(0.2, 0.2, 0.2), color)
	anchor.Transparency = 1
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 38)
	billboard.StudsOffset = Vector3.new(0, 0.55, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 52
	billboard.Adornee = anchor
	billboard.Parent = anchor
	local caption = label(billboard, "Caption", string.upper(arrowTitle), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Enum.Font.GothamBold, 14, color, Enum.TextXAlignment.Center)
	caption.BackgroundColor3 = COLORS.panel
	caption.BackgroundTransparency = 0.28
	corner(caption, 6)
	arrowParts = {
		center = center,
		ring = ring,
		chevrons = chevrons,
		anchor = anchor,
	}
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function isFloorSurface(result)
	if result.Normal.Y < 0.72 then
		return false
	end
	local hit = result.Instance
	if not hit or not hit:IsA("BasePart") then
		return false
	end
	local lowered = string.lower(hit.Name)
	if string.find(lowered, "floor", 1, true)
		or string.find(lowered, "carpet", 1, true)
		or string.find(lowered, "linoleum", 1, true)
		or string.find(lowered, "foundation", 1, true)
		or string.find(lowered, "driveway", 1, true)
		or string.find(lowered, "street", 1, true)
		or string.find(lowered, "deck", 1, true)
		or string.find(lowered, "ground", 1, true)
	then
		return true
	end
	return hit.Size.X >= 8 and hit.Size.Z >= 8 and hit.Size.Y <= 2
end

local function groundPoint(position)
	local excluded = { player.Character, arrowModel, hiddenVisual }
	local origin = position + Vector3.new(0, 7, 0)
	for _ = 1, 10 do
		rayParams.FilterDescendantsInstances = excluded
		local hit = workspace:Raycast(origin, Vector3.new(0, -25, 0), rayParams)
		if not hit then
			break
		end
		if isFloorSurface(hit) then
			return hit.Position + Vector3.new(0, 0.09, 0)
		end
		table.insert(excluded, hit.Instance)
	end
	return Vector3.new(position.X, position.Y - 2.7, position.Z)
end

local function automationDeliveryStyle(snapshot, delivery)
	local entry = automationEntry(snapshot, type(delivery) == "table" and delivery.upgradeId or nil)
	local taskId = tostring((entry and entry.taskId) or (type(delivery) == "table" and delivery.taskId) or "")
	return automationTaskColors[taskId] or COLORS.terminal,
		automationTaskColorNames[taskId] or "green"
end

local function automationDeliveryTarget(snapshot, delivery)
	local entry = automationEntry(snapshot, type(delivery) == "table" and delivery.upgradeId or nil)
	local deliveryHint = type(delivery) == "table" and delivery.targetHint or nil
	return deliveryHint or (entry and entry.installTarget) or nil
end

local function deliveryPresentation(delivery, snapshot)
	local kind = type(delivery) == "table" and tostring(delivery.kind or "MachinePart") or "MachinePart"
	if kind == "Boombox" then
		return "BOOMBOX DELIVERY", COLORS.purple
	elseif kind == "Beer" then
		return "LONE STAR DELIVERY", COLORS.orange
	elseif kind == "TaskUpgrade" then
		local color = automationDeliveryStyle(snapshot, delivery)
		return "TASK ROBOT DELIVERY", color
	elseif kind == "ChemistrySetup" then
		return "BUNKER CHEMISTRY DELIVERY", Color3.fromRGB(64, 231, 255)
	end
	return "TIME MACHINE DELIVERY", COLORS.blue
end

local function deliveryStatusText(delivery, snapshot)
	local kind = type(delivery) == "table" and tostring(delivery.kind or "MachinePart") or "MachinePart"
	local status = type(delivery) == "table" and tostring(delivery.status or "WaitingDelivery") or "WaitingDelivery"
	local deliveryName = tostring(type(delivery) == "table" and delivery.name or "crate")
	if type(delivery) == "table" and delivery.hostOnly == true and not partyUx.isHost(snapshot) then
		local ownerName = partyUx.memberName(delivery.ownerUserId, "The party host")
		if status == "WaitingDelivery" or status == "Ordered" then
			return ownerName .. " ordered this shared item. Its truck is headed to the driveway."
		elseif status == "Collect" then
			return ownerName .. " can collect this host-reserved crate from the driveway."
		elseif status == "Install" or status == "Carried" or status == "Setup" then
			return ownerName .. " is carrying and installing this shared item. You do not need to move it."
		end
		return ownerName .. " is handling this shared house delivery."
	end
	if status == "WaitingDelivery" then
		return kind == "TaskUpgrade"
			and (deliveryName .. " is on the delivery truck headed to the driveway.")
			or "Truck is on the way to the driveway."
	elseif status == "Collect" then
		if kind == "Boombox" then
			return "Pick up your boombox crate from the driveway."
		elseif kind == "TaskUpgrade" then
			return "Pick up the " .. deliveryName .. " crate from the driveway."
		elseif kind == "ChemistrySetup" then
			return "Pick up the reinforced chemistry research case from the driveway."
		end
		return "Pick up the crate from the driveway."
	elseif kind == "Boombox" and (status == "Setup" or status == "Install" or status == "Carried") then
		return "Follow the purple arrow into the living room. The boombox sets itself up when you enter the marked area."
	elseif kind == "TaskUpgrade" and (status == "Install" or status == "Carried" or status == "Setup") then
		local _, colorName = automationDeliveryStyle(snapshot, delivery)
		return "Follow the " .. colorName .. " setup arrow while carrying " .. deliveryName
			.. ". It installs automatically when you enter the marked area."
	elseif kind == "ChemistrySetup" and (status == "Install" or status == "Carried" or status == "Setup") then
		return "Carry the research case through the backyard hatch to the cyan-and-violet chemistry bay. The lab assembles automatically on the pad."
	elseif kind == "MachinePart" and status == "Install" then
		return "Carry the component crate to the garage installation bay."
	end
	return tostring(delivery and delivery.description or "Finish setting up this delivery.")
end

local function guideForSnapshot(snapshot)
	if not partyUx.isActive(snapshot) then
		return nil
	end
	local taskData = snapshot.task
	local delivery = snapshot.delivery
	local candyDelivery = type(snapshot.candyDelivery) == "table" and snapshot.candyDelivery or {}
	local taskUpgradeTarget = type(delivery) == "table" and automationDeliveryTarget(snapshot, delivery) or nil
	if candyDelivery.active == true and candyDelivery.targetHint then
		return candyDelivery.targetHint, "DELIVER BLUE ROCK CANDY TO LOS POLLOS TRUCK", COLORS.yellow
	end
	-- Paid bunker equipment gets an unmistakable cyan guide from truck arrival
	-- through final installation, even while a family chore is active.
	if type(delivery) == "table"
		and tostring(delivery.kind or "") == "ChemistrySetup"
		and (tostring(delivery.status or "") == "WaitingDelivery"
			or tostring(delivery.status or "") == "Collect")
		and delivery.targetHint
	then
		local title = if tostring(delivery.status or "") == "Collect"
			then "PICK UP CHEMISTRY RESEARCH CASE"
			else "CHEMISTRY DELIVERY ARRIVING HERE"
		return delivery.targetHint, title, Color3.fromRGB(64, 231, 255)
	end
	if type(delivery) == "table"
		and tostring(delivery.kind or "") == "ChemistrySetup"
		and (tostring(delivery.status or "") == "Install"
			or tostring(delivery.status or "") == "Carried"
			or tostring(delivery.status or "") == "Setup")
		and delivery.targetHint
	then
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local chemistryAnchor = resolveTarget("ChemistrySetAnchor")
		local playerIsUnderground = playerRoot and chemistryAnchor
			and playerRoot.Position.Y <= chemistryAnchor.Position.Y + 12
		if not playerIsUnderground then
			return "HatchControl", "TAKE CHEMISTRY CASE THROUGH BUNKER HATCH", Color3.fromRGB(64, 231, 255)
		end
		return delivery.targetHint, "INSTALL ADVANCED CHEMISTRY LAB HERE", Color3.fromRGB(64, 231, 255)
	end
	-- A carried task robot is always the top navigation priority. The player
	-- paid for this delivery and entering its colored target installs it without
	-- another prompt, so a current family request must never mask the setup bay.
	if type(delivery) == "table"
		and tostring(delivery.kind or "") == "TaskUpgrade"
		and (tostring(delivery.status or "") == "Install"
			or tostring(delivery.status or "") == "Carried"
			or tostring(delivery.status or "") == "Setup")
		and taskUpgradeTarget
	then
		local color = automationDeliveryStyle(snapshot, delivery)
		return taskUpgradeTarget, "INSTALL " .. string.upper(tostring(delivery.name or "TASK ROBOT")) .. " HERE", color
	end
	-- A carried boombox must take priority over every chore (including the
	-- opening George beer task), otherwise that task masks the living-room
	-- destination and leaves the player with no usable setup guidance.
	if type(delivery) == "table"
		and tostring(delivery.kind or "") == "Boombox"
		and (tostring(delivery.status or "") == "Setup" or tostring(delivery.status or "") == "Install")
		and delivery.targetHint
	then
		return delivery.targetHint, "PLACE BOOMBOX HERE", COLORS.purple
	end
	local secretBunker = type(snapshot.secretBunker) == "table" and snapshot.secretBunker or {}
	if secretBunker.purchased == true and secretBunker.unlocked ~= true
		and tostring(secretBunker.status or "") == "Construction"
	then
		return "BunkerConstructionViewingAnchor", "WATCH THE BUNKER CONSTRUCTION", COLORS.orange
	end
	if taskData and partyUx.ownsCarrier(taskData) and not taskIsAutomated(taskData)
		and taskData.id == "GeorgeBeer" and taskData.guidance and taskData.targetHint
	then
		return taskData.targetHint, taskData.title, requesterColors[taskData.requester] or COLORS.orange
	end
	if taskData and partyUx.ownsCarrier(taskData)
		and not taskIsAutomated(taskData) and taskData.guidance and taskData.targetHint
	then
		return taskData.targetHint, taskData.title, requesterColors[taskData.requester] or COLORS.yellow
	end
	if delivery and delivery.targetHint then
		local title, color = deliveryPresentation(delivery, snapshot)
		return delivery.targetHint, title, color
	end
	return nil
end

local function updateArrow(snapshot)
	local hint, title, color = guideForSnapshot(snapshot)
	if not hint then
		clearArrow()
	elseif hint ~= arrowTargetHint
		or tostring(title or "TASK") ~= arrowTitle
		or color ~= arrowColor
		or not arrowModel
		or not arrowTarget
		or not arrowTarget.Parent
	then
		createArrow(hint, title, color)
	end
end

-- Interior anchors may stream in after the server snapshot that selected
-- them. Coalesce descendant arrivals and retry the unresolved hint so a paid
-- robot crate never loses its setup arrow merely because the destination room
-- was outside the streaming radius at pickup time.
workspace.DescendantAdded:Connect(function()
	if arrowModel or arrowTargetHint == "" or arrowResolveScheduled then
		return
	end
	arrowResolveScheduled = true
	task.delay(0.1, function()
		arrowResolveScheduled = false
		local snapshot = currentSnapshot
		local hint = arrowTargetHint
		if snapshot and hint ~= "" and not arrowModel and resolveTarget(hint) then
			updateArrow(snapshot)
		end
	end)
end)

game:GetService("RunService").RenderStepped:Connect(function()
	if not arrowModel or not arrowParts then
		return
	end
	local resolved = resolveTarget(arrowTargetHint)
	if resolved then
		arrowTarget = resolved
	end
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not arrowTarget or not arrowTarget.Parent or not playerRoot then
		return
	end
	local now = os.clock()
	local destination = groundPoint(arrowTarget.Position - Vector3.new(0, arrowTarget.Size.Y * 0.35, 0))
	local playerGround = groundPoint(playerRoot.Position)
	arrowParts.center.CFrame = CFrame.new(destination) * CFrame.Angles(0, 0, math.rad(90))
	arrowParts.center.Transparency = 0.35 - (math.sin(now * 3) + 1) * 0.08
	arrowParts.anchor.CFrame = CFrame.new(destination)
	for index, segment in ipairs(arrowParts.ring) do
		local angle = ((index - 1) / #arrowParts.ring) * math.pi * 2
		segment.CFrame = CFrame.new(destination) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.05, -1.05)
		segment.Transparency = 0.38 - (math.sin(now * 3 - index * 0.22) + 1) * 0.09
	end
	local flat = Vector3.new(destination.X - playerGround.X, 0, destination.Z - playerGround.Z)
	if flat.Magnitude < 1 then
		return
	end
	local direction = flat.Unit
	local right = Vector3.new(-direction.Z, 0, direction.X)
	for _, chevron in ipairs(arrowParts.chevrons) do
		local offset = 2.8 + (chevron.index - 1) * 2.35
		local visible = flat.Magnitude > offset + 0.6
		if not visible then
			chevron.left.Transparency = 1
			chevron.right.Transparency = 1
		else
			local point = groundPoint(playerGround + direction * offset) + Vector3.new(0, 0.12, 0)
			local apex = point + direction * 0.65
			local leftTail = point - direction * 0.2 - right * 0.5
			local rightTail = point - direction * 0.2 + right * 0.5
			local leftCenter = leftTail:Lerp(apex, 0.5)
			local rightCenter = rightTail:Lerp(apex, 0.5)
			chevron.left.Size = Vector3.new(0.18, 0.07, (apex - leftTail).Magnitude)
			chevron.right.Size = Vector3.new(0.18, 0.07, (apex - rightTail).Magnitude)
			chevron.left.CFrame = CFrame.lookAt(leftCenter, apex, Vector3.yAxis)
			chevron.right.CFrame = CFrame.lookAt(rightCenter, apex, Vector3.yAxis)
			local pulse = (math.sin(now * 4.5 - chevron.index * 0.8) + 1) * 0.5
			chevron.left.Transparency = 0.32 - pulse * 0.2
			chevron.right.Transparency = 0.32 - pulse * 0.2
		end
	end
end)

-- Snapshot rendering ---------------------------------------------------------

local function updateMachinePresentation(snapshot)
	local stage = math.max(0, math.floor(tonumber(snapshot.machineStage) or 0))
	local progress = math.clamp(tonumber(snapshot.machineProgress) or 0, 0, 100)
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local machine = environment and environment:FindFirstChild("CooperTimeMachine", true)
	local stages = machine and machine:FindFirstChild("Stages")
	if stages then
		for _, folder in ipairs(stages:GetChildren()) do
			local stageNumber = tonumber(string.match(folder.Name, "^Stage(%d+)"))
			if stageNumber then
				for _, descendant in ipairs(folder:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.LocalTransparencyModifier = stageNumber <= stage and 0 or 1
					end
				end
			end
		end
	end
	local display = machine and machine:FindFirstChild("FamilyTaskProgress", true)
	if display and display:IsA("SurfaceGui") then
		display.AlwaysOnTop = false
	end
	local progressLabel = display and display:FindFirstChild("Progress", true)
	if progressLabel and progressLabel:IsA("TextLabel") then
		progressLabel.Text = string.format("TIME MACHINE" .. string.char(10) .. "%d%% COMPLETE", math.floor(progress + 0.5))
	end
end

-- The family task is personal to each player, so the dirty sink must be a
-- client-side presentation as well. Base transparency contains the authored
-- plate/stain appearance; LocalTransparencyModifier makes the whole set fully
-- invisible for everyone who is not currently doing Mary's dish task.
local function dirtyDishesModel()
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local taskWorld = environment and environment:FindFirstChild("CooperFamilyTaskWorld")
	local visuals = taskWorld and taskWorld:FindFirstChild("TaskVisuals")
	local dishes = visuals and visuals:FindFirstChild("DirtyDishesInSink")
	return if dishes and dishes:IsA("Model") then dishes else nil
end

local function setDirtyDishPartVisible(part, visible)
	if part:IsA("BasePart") and part:GetAttribute("DirtyDishVisual") == true then
		part.LocalTransparencyModifier = visible and 0 or 1
	end
end

local function updateDirtyDishesVisibility(snapshot)
	local dishes = dirtyDishesModel()
	if not dishes then
		return
	end
	local taskData = type(snapshot) == "table" and snapshot.task or nil
	local visible = taskData ~= nil and taskData.id == "MaryDishes"
		or upgradeNoticeUi.automationRun(snapshot, "MaryDishes") ~= nil
	for _, descendant in ipairs(dishes:GetDescendants()) do
		setDirtyDishPartVisible(descendant, visible)
	end
end

upgradeNoticeUi.taskPadNames = {
	DishesPad = true,
	TrashPickupPad = true,
	OutdoorTrashPad = true,
	GeorgeBeerPad = true,
	MachineInstallPad = true,
	MissyReturnPad = true,
}

function upgradeNoticeUi.setTaskPadVisible(visuals, padName, visible)
	local pad = visuals and visuals:FindFirstChild(padName)
	if pad and pad:IsA("BasePart") then
		-- Task state is personal. Keep these translucent floor hints local so one
		-- player's chore never leaves permanent neon patches in everyone else's
		-- otherwise natural-looking house.
		pad.LocalTransparencyModifier = visible == true and 0 or 1
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if not descendant:IsA("BasePart") then
		return
	end
	task.defer(function()
		if not descendant.Parent or descendant:GetAttribute("DirtyDishVisual") ~= true then
			return
		end
		local dishes = descendant:FindFirstAncestor("DirtyDishesInSink")
		if not dishes or dishes:GetAttribute("FamilyTaskVisual") ~= "MaryDishes" then
			return
		end
		local taskData = currentSnapshot and currentSnapshot.task
		setDirtyDishPartVisible(
			descendant,
			taskData ~= nil and taskData.id == "MaryDishes"
				or upgradeNoticeUi.automationRun(currentSnapshot, "MaryDishes") ~= nil
		)
	end)
end)

local function updateWorldPrompts(snapshot)
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local taskWorld = environment and environment:FindFirstChild("CooperFamilyTaskWorld")
	local stations = taskWorld and taskWorld:FindFirstChild("Stations")
	if not stations then
		return
	end
	local taskData = snapshot.task
	local activeParty = partyUx.isActive(snapshot)
	local manualTask = activeParty and partyUx.ownsCarrier(taskData) and not taskIsAutomated(taskData) and taskData or nil
	local function configure(anchorName, enabled, actionText)
		local anchor = stations:FindFirstChild(anchorName)
		local prompt = anchor and anchor:FindFirstChild("TaskPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enabled == true
			if actionText then
				prompt.ActionText = actionText
			end
		end
	end
	configure("DishesPromptAnchor", manualTask and manualTask.id == "MaryDishes")
	configure("TrashPickupAnchor", manualTask and manualTask.id == "MaryTrash" and manualTask.step == "Pickup")
	configure("OutdoorTrashAnchor", manualTask and manualTask.id == "MaryTrash" and manualTask.step == "Deliver")
	configure("MissyPlushReturnAnchor", manualTask and manualTask.id == "MissyPlush" and manualTask.step == "Return")
	configure("GeorgeBeerDropAnchor", manualTask and manualTask.id == "GeorgeBeer" and manualTask.step == "Deliver", "Stock Beer In Fridge")
	local visuals = taskWorld:FindFirstChild("TaskVisuals")
	local showKitchenBag = manualTask and manualTask.id == "MaryTrash" and manualTask.step == "Pickup"
	for _, bagName in ipairs({ "KitchenTrashBag", "KitchenTrashBagTie" }) do
		local bagPart = visuals and visuals:FindFirstChild(bagName)
		if bagPart and bagPart:IsA("BasePart") then
			bagPart.LocalTransparencyModifier = showKitchenBag and 0 or 1
		end
	end
	local kitchenCan = visuals and visuals:FindFirstChild("KitchenGarbageCan")
	if kitchenCan and kitchenCan:IsA("Model") then
		for _, descendant in ipairs(kitchenCan:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 0
			end
		end
	end
	local delivery = type(snapshot.delivery) == "table" and snapshot.delivery or nil
	local machineInstallVisible = activeParty and partyUx.isHost(snapshot) and delivery ~= nil
		and tostring(delivery.kind or "MachinePart") == "MachinePart"
		and delivery.status == "Install"
	configure(
		"MachineInstallBay",
		machineInstallVisible,
		"Install " .. tostring(delivery and delivery.name or "Component")
	)
	upgradeNoticeUi.setTaskPadVisible(visuals, "DishesPad", manualTask and manualTask.id == "MaryDishes")
	upgradeNoticeUi.setTaskPadVisible(visuals, "TrashPickupPad", manualTask and manualTask.id == "MaryTrash" and manualTask.step == "Pickup")
	upgradeNoticeUi.setTaskPadVisible(visuals, "OutdoorTrashPad", manualTask and manualTask.id == "MaryTrash" and manualTask.step == "Deliver")
	upgradeNoticeUi.setTaskPadVisible(visuals, "MissyReturnPad", manualTask and manualTask.id == "MissyPlush" and manualTask.step == "Return")
	upgradeNoticeUi.setTaskPadVisible(visuals, "GeorgeBeerPad", manualTask and manualTask.id == "GeorgeBeer" and manualTask.step == "Deliver")
	upgradeNoticeUi.setTaskPadVisible(visuals, "MachineInstallPad", machineInstallVisible)
	local boombox = type(snapshot.boombox) == "table" and snapshot.boombox or {}
	local boomboxSetup = activeParty and partyUx.isHost(snapshot) and delivery ~= nil
		and tostring(delivery.kind or "") == "Boombox"
		and (tostring(delivery.status or "") == "Setup" or tostring(delivery.status or "") == "Install")
	configure("BoomboxSetupAnchor", boomboxSetup, "Set Up Boombox")

	local cooldown = boomboxCooldownRemaining(snapshot)
	local boomboxApproachable = activeParty and partyUx.isHost(snapshot) and boombox.purchased == true
		and boombox.placed == true
		and not boomboxIsPlaying(boombox)
	local powerText = if boombox.occupiedByOther == true
		then "In Use"
		elseif boomboxIsPlaying(boombox)
			then "Now Playing"
		elseif cooldown > 0
			then "Cooldown - Ready in " .. formatCountdown(cooldown)
			else "Turn On Boombox"
	configure("BoomboxPowerAnchor", boomboxApproachable, powerText)
end

-- Task stations can stream in after the snapshot that selected their task.
-- Reapply the current per-player prompt state when that happens so the sink's
-- four-second wash interaction (and the other retained task prompts) is usable
-- immediately on arrival.
workspace.DescendantAdded:Connect(function(descendant)
	if not descendant:IsA("ProximityPrompt")
		or type(descendant:GetAttribute("FamilyTaskAction")) ~= "string"
	then
		return
	end
	task.defer(function()
		if descendant.Parent and currentSnapshot then
			updateWorldPrompts(currentSnapshot)
		elseif descendant.Parent then
			descendant.Enabled = false
		end
	end)
end)

-- A streamed pad can arrive after its task snapshot. Reapply all six local
-- visibility states immediately rather than flashing a stale marker.
workspace.DescendantAdded:Connect(function(descendant)
	if not descendant:IsA("BasePart") or not upgradeNoticeUi.taskPadNames[descendant.Name] then
		return
	end
	descendant.LocalTransparencyModifier = 1
	task.defer(function()
		if descendant.Parent and currentSnapshot then
			updateWorldPrompts(currentSnapshot)
		end
	end)
end)

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" or snapshot.loaded == false then
		return
	end
	currentSnapshot = snapshot
	currentSnapshotReceivedAt = os.clock()
	local allowance = math.max(0, math.floor(tonumber(snapshot.allowance) or 0))
	local progress = math.clamp(tonumber(snapshot.machineProgress) or 0, 0, 100)
	allowanceValue.Text = "$" .. tostring(allowance)
	upgradeNoticeUi.update(snapshot)
	machineTitle.Text = string.format("SHARED TIME MACHINE • %d%%", math.floor(progress + 0.5))
	machineStage.Text = tostring(snapshot.machineStageName or "Blueprint Pending")
	TweenService:Create(machineFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(progress / 100, 1),
	}):Play()

	local taskData = snapshot.task
	local candyDelivery = type(snapshot.candyDelivery) == "table" and snapshot.candyDelivery or nil
	if taskData then
		local accent = requesterColors[taskData.requester] or COLORS.green
		local automated = taskIsAutomated(taskData)
		taskRequester.Text = automated
			and ("SHARED TASK • AUTOMATION • " .. string.upper(tostring(taskData.requester)))
			or ("SHARED FAMILY TASK • " .. string.upper(tostring(taskData.requester)))
		taskRequester.TextColor3 = accent
		taskStroke.Color = accent
		taskTitle.Text = automated
			and ("ROBOT WORKING • " .. tostring(taskData.title))
			or tostring(taskData.title)
		-- The server owns the exact automation phase and wording. Do not
		-- substitute the old manual instructions while a robot is active.
		local description = tostring(taskData.description)
		if tonumber(taskData.carrierUserId) and not partyUx.ownsCarrier(taskData) then
			description = partyUx.memberName(taskData.carrierUserId, "A teammate")
				.. " is carrying the shared task item. Follow along or explore while they finish it."
		elseif tonumber(taskData.actorUserId) and tonumber(taskData.actorUserId) ~= player.UserId then
			description = partyUx.memberName(taskData.actorUserId, "A teammate")
				.. " is using BANKLINK for this shared task. You can watch, but only their keyboard input counts."
		end
		taskDescription.Text = description
		taskReward.Text = automated
			and string.format("SHARED AUTO REWARD: EACH PLAYER +$%d", tonumber(taskData.reward) or 0)
			or string.format("SHARED REWARD: EACH PLAYER +$%d", tonumber(taskData.reward) or 0)
	else
		taskRequester.Text = "SHARED FAMILY TASK"
		taskRequester.TextColor3 = COLORS.green
		taskStroke.Color = COLORS.green
		taskTitle.Text = "WAITING FOR A REQUEST"
		taskDescription.Text = "Explore the Cooper house. Someone will need help soon."
		taskReward.Text = ""
	end

	local personalObjectiveActive = candyDelivery ~= nil and candyDelivery.active == true
	local personalObjectiveFrame = scaleRoot:FindFirstChild("PersonalObjectiveChip")
	if personalObjectiveFrame and personalObjectiveFrame:IsA("Frame") then
		personalObjectiveFrame.Visible = personalObjectiveActive
		if personalObjectiveActive then
			local personalTitle = personalObjectiveFrame:FindFirstChild("Title")
			local personalText = personalObjectiveFrame:FindFirstChild("Text")
			if personalTitle and personalTitle:IsA("TextLabel") then
				personalTitle.Text = "MY OBJECTIVE • LOS POLLOS PICKUP"
			end
			if personalText and personalText:IsA("TextLabel") then
				personalText.Text = string.format(
					"Take the Blue Rock Candy pan to the yellow buyer truck. MY PAYOUT: +$%d",
					math.max(0, math.floor(tonumber(candyDelivery.payout) or 0))
				)
			end
		end
	end
	deliveryChip.Position = personalObjectiveActive and UDim2.fromOffset(18, 475) or UDim2.fromOffset(18, 369)

	local delivery = snapshot.delivery
	deliveryChip.Visible = delivery ~= nil
	if delivery then
		local deliveryLabel, deliveryColor = deliveryPresentation(delivery, snapshot)
		local kind = tostring(delivery.kind or "MachinePart")
		local hostPrefix = delivery.hostOnly == true and not partyUx.isHost(snapshot) and "HOST DELIVERY • " or ""
		if kind == "Boombox" then
			deliveryTitle.Text = hostPrefix .. deliveryLabel
		elseif kind == "TaskUpgrade" then
			deliveryTitle.Text = hostPrefix .. deliveryLabel .. " • " .. string.upper(tostring(delivery.name or "TASK ROBOT"))
		else
			deliveryTitle.Text = hostPrefix .. string.upper(tostring(delivery.name or deliveryLabel))
		end
		deliveryTitle.TextColor3 = deliveryColor
		deliveryStroke.Color = deliveryColor
		deliveryText.Text = deliveryStatusText(delivery, snapshot)
	end
	partyUx.updatePause(snapshot)

	if snapshot.introNeeded then
		introScrim.Visible = true
		gui.DisplayOrder = 65
		upgradeNoticeUi.setControlsLocked(true)
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = introButton
		end
	end
	updateHidden(snapshot)
	updateArrow(snapshot)
	updateMachinePresentation(snapshot)
	updateDirtyDishesVisibility(snapshot)
	updateWorldPrompts(snapshot)
	if terminal.Visible and terminalPage == "Bank" and bankAttemptActive() then
		-- BankHack packets, not general economy/task snapshots, own the live
		-- sequence presentation. Leave the animation token and input index intact.
		refreshBankStartButton()
	elseif terminal.Visible
		and terminalPage ~= "Credits"
		and (terminalPage ~= "DOS" or not dosInput or not dosInput:IsFocused())
	then
		renderTerminal()
	end
end

snapshotEvent.OnClientEvent:Connect(applySnapshot)

-- Cooldown deadlines continue locally between snapshots. Refreshing only when
-- the displayed second changes keeps the terminal countdown accurate and
-- enables the living-room power prompt as soon as it reaches zero.
task.spawn(function()
	local previousRemaining = nil
	local previousBunkerRemaining = nil
	while gui.Parent do
		task.wait(1)
		local snapshot = currentSnapshot
		if type(snapshot) == "table" then
			partyUx.updatePause(snapshot)
		end
		local boombox = type(snapshot) == "table" and snapshot.boombox or nil
		if type(boombox) == "table" and boombox.purchased == true and boombox.placed == true then
			local remaining = boomboxCooldownRemaining(snapshot)
			if remaining ~= previousRemaining then
				previousRemaining = remaining
				updateWorldPrompts(snapshot)
				if terminal.Visible and terminalPage == "Boombox" then
					renderTerminal()
				end
			end
		else
			previousRemaining = nil
		end
		local secretBunker = type(snapshot) == "table" and snapshot.secretBunker or nil
		if type(secretBunker) == "table"
			and secretBunker.purchased == true
			and secretBunker.unlocked ~= true
		then
			local remaining = secretBunkerConstructionRemaining(snapshot)
			if remaining ~= previousBunkerRemaining then
				previousBunkerRemaining = remaining
				if terminal.Visible and terminalPage == "SecretBunker" then
					renderTerminal()
				end
			end
		else
			previousBunkerRemaining = nil
		end
	end
end)

-- The server owns formation and restoration; each client animates the four
-- original PNG cutouts from the exact Sound.TimePosition for smooth, drift-free
-- beat matching. George/Missy and Mary/Georgie alternate one 130-BPM jump at a
-- time while their grounded shadows and interaction roots stay planted.
local danceRoster = { "George", "Mary", "Missy", "Georgie" }
local danceVisualState = {}
local danceBpm = math.max(1, tonumber(Config.Boombox and Config.Boombox.DanceBPM) or 130)
local danceBeatPeriod = 60 / danceBpm
local danceBeatOffset = tonumber(Config.Boombox and Config.Boombox.DanceBeatOffsetSeconds) or 0.16
local danceJumpHeight = math.max(0, tonumber(Config.Boombox and Config.Boombox.DanceJumpHeight) or 1.05)

local function restoreDanceVisual(model)
	local saved = danceVisualState[model]
	if not saved then
		return
	end
	if saved.billboard and saved.billboard.Parent then
		saved.billboard.StudsOffsetWorldSpace = saved.offset
	end
	if saved.image and saved.image.Parent then
		saved.image.Rotation = saved.rotation
	end
	saved.active = false
end

game:GetService("RunService").RenderStepped:Connect(function()
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local npcWorld = environment and environment:FindFirstChild("CooperFamilyNPCs")
	local taskWorld = environment and environment:FindFirstChild("CooperFamilyTaskWorld")
	local boombox = taskWorld and taskWorld:FindFirstChild("CooperIncomeBoombox", true)
	local sound = boombox and boombox:FindFirstChild("BoomboxSound", true)
	local playing = boombox ~= nil
		and boombox:GetAttribute("Playing") == true
		and sound ~= nil
		and sound:IsA("Sound")
		and sound.Playing
	local audioTime = playing and math.max(0, sound.TimePosition) or 0
	local beatPosition = math.max(0, audioTime - danceBeatOffset) / danceBeatPeriod
	local beatIndex = math.floor(beatPosition)
	local beatPhase = beatPosition - beatIndex

	for rosterIndex, name in ipairs(danceRoster) do
		local model = npcWorld and npcWorld:FindFirstChild(name)
		local rootPart = model and model:FindFirstChild("Root")
		local billboard = rootPart and rootPart:FindFirstChild("Cutout")
		local image = billboard and billboard:FindFirstChild("CharacterImage")
		if model and billboard and billboard:IsA("BillboardGui") and image and image:IsA("ImageLabel") then
			local saved = danceVisualState[model]
			if not saved or saved.billboard ~= billboard or saved.image ~= image then
				saved = {
					billboard = billboard,
					image = image,
					offset = billboard.StudsOffsetWorldSpace,
					rotation = image.Rotation,
					active = false,
				}
				danceVisualState[model] = saved
			end
			if playing and model:GetAttribute("BoomboxDancing") == true then
				local firstPair = name == "George" or name == "Missy"
				local pairJumps = (beatIndex % 2 == 0) == firstPair
				local jump = pairJumps and math.sin(math.pi * beatPhase) * danceJumpHeight or 0
				local swayDirection = rosterIndex % 2 == 0 and -1 or 1
				billboard.StudsOffsetWorldSpace = saved.offset + Vector3.new(0, jump, 0)
				image.Rotation = saved.rotation
					+ (pairJumps and math.sin(math.pi * 2 * beatPhase) * 4 * swayDirection or 0)
				saved.active = true
			elseif saved.active then
				restoreDanceVisual(model)
			end
		elseif model and danceVisualState[model] then
			restoreDanceVisual(model)
		end
	end

	for model in pairs(danceVisualState) do
		if not model.Parent then
			danceVisualState[model] = nil
		end
	end
end)

local pendingBoomboxIncome = 0
local boomboxIncomeToken = 0

local function feedbackIncome(packet)
	for _, field in ipairs({ "earned", "amount", "allowance", "reward", "delta" }) do
		local amount = tonumber(packet[field])
		if amount and amount > 0 then
			return math.floor(amount + 0.5)
		end
	end
	return 0
end

-- A compatible server may optionally send individual income events. Combine
-- them after the stream goes quiet instead of replacing the toast ten times.
local function queueBoomboxIncome(packet)
	local amount = feedbackIncome(packet)
	if amount <= 0 then
		return
	end
	pendingBoomboxIncome += amount
	boomboxIncomeToken += 1
	local token = boomboxIncomeToken
	task.delay(3.25, function()
		if token ~= boomboxIncomeToken or pendingBoomboxIncome <= 0 then
			return
		end
		local earned = pendingBoomboxIncome
		pendingBoomboxIncome = 0
		showToast("BOOMBOX  +$" .. tostring(earned), "Automatic allowance collected from the song.", COLORS.yellow, 3.5)
	end)
end

local function finishBoomboxIncome(packet)
	boomboxIncomeToken += 1
	local reported = feedbackIncome(packet)
	local earned = math.max(reported, pendingBoomboxIncome)
	pendingBoomboxIncome = 0
	local cooldown = roundedNonnegative(packet.cooldown)
	local detail = tostring(packet.text or "The song finished and the disco lights shut down.")
	if cooldown > 0 then
		detail ..= " Ready again in " .. formatCountdown(cooldown) .. "."
	end
	showToast(
		earned > 0 and ("BOOMBOX FINISHED  +$" .. tostring(earned)) or "BOOMBOX FINISHED",
		detail,
		COLORS.yellow,
		4.5
	)
end

local function applyBankPacketMetadata(packet)
	if tonumber(packet.cycle) then
		bankCycle = math.max(1, math.floor(tonumber(packet.cycle)))
	end
	if tonumber(packet.reward) then
		bankReward = math.max(0, math.floor(tonumber(packet.reward)))
	end
	if tonumber(packet.previewStepSeconds) then
		bankStepSeconds = math.max(0.1, tonumber(packet.previewStepSeconds))
	end
	if tonumber(packet.roundCount) then
		bankRoundCount = math.clamp(math.floor(tonumber(packet.roundCount)), 1, #bankRoundLeds)
	end
	bankReadouts.Cycle.Text = string.format("%02d", bankCycle)
	bankReadouts.Reward.Text = "$" .. tostring(bankReward)
	bankReadouts.Speed.Text = string.format("%.2f SEC", bankStepSeconds)
end

bankHackEvent.OnClientEvent:Connect(function(packet)
	if type(packet) ~= "table" then
		return
	end
	local kind = tostring(packet.kind or "")
	local packetSessionId = type(packet.sessionId) == "string" and packet.sessionId or nil
	if kind == "BankHackStarted" then
		if not terminal.Visible or terminalPage ~= "Bank" or not bankPanel.Visible or not packetSessionId then
			if packetSessionId then
				bankKeyStyles.requestCancellation(packetSessionId)
			end
			return
		end
		bankAnimationToken += 1
		bankSessionId = packetSessionId
		bankPhase = "WaitingRound"
		bankInputPending = false
		bankInputIndex = 0
		bankPatternLength = 0
		bankSnapshotCanStart = false
		applyBankPacketMetadata(packet)
		setBankRoundDisplay(0, 0)
		updateBankInputProgress()
		setAllBankKeys("Idle")
		setBankMode("SECURE LINK ESTABLISHED // LOADING SECURITY NODES", COLORS.terminal)
		bankSignal.Text = "● LINK ACTIVE"
		bankSignal.TextColor3 = COLORS.terminal
		refreshBankStartButton()
	elseif kind == "BankHackRound" then
		if not packetSessionId or packetSessionId ~= bankSessionId then
			return
		end
		applyBankPacketMetadata(packet)
		beginBankPattern(packet)
	elseif kind == "BankHackInputAccepted" then
		if not packetSessionId or packetSessionId ~= bankSessionId then
			return
		end
		bankInputPending = false
		bankInputIndex = math.clamp(
			math.floor(tonumber(packet.index) or (bankInputIndex + 1)),
			0,
			math.max(0, bankPatternLength)
		)
		local acceptedKey = string.upper(tostring(packet.key or bankLastInputKey or ""))
		if bankKeyVisuals[acceptedKey] then
			pulseBankKey(acceptedKey, "Correct", 0.15, "Ready")
		end
		bankLastInputKey = nil
		updateBankInputProgress()
		if bankInputIndex < bankPatternLength then
			bankPhase = "AwaitInput"
			setBankMode("YOUR TURN // KEY ACCEPTED // CONTINUE", Color3.fromRGB(111, 238, 255))
			bankSignal.Text = "● TRANSMIT READY"
			bankSignal.TextColor3 = Color3.fromRGB(111, 238, 255)
		else
			bankPhase = "WaitingRound"
			setBankMode("PATTERN VERIFIED // CLEARING SECURITY NODE", COLORS.green)
			bankSignal.Text = "● VERIFIED"
			bankSignal.TextColor3 = COLORS.green
		end
		refreshBankStartButton()
	elseif kind == "BankHackRoundComplete" then
		if not packetSessionId or packetSessionId ~= bankSessionId then
			return
		end
		bankPhase = "WaitingRound"
		bankInputPending = false
		local completedRound = math.max(1, math.floor(tonumber(packet.round) or bankCurrentRound))
		setBankRoundDisplay(completedRound, completedRound)
		setAllBankKeys("Correct")
		setBankMode(tostring(packet.text or "ACCESS LAYER CLEARED // PREPARING NEXT NODE"), COLORS.green)
		bankSignal.Text = "● NODE CLEARED"
		bankSignal.TextColor3 = COLORS.green
		refreshBankStartButton()
		local token = bankAnimationToken
		task.delay(0.24, function()
			if token == bankAnimationToken and bankPhase == "WaitingRound" then
				setAllBankKeys("Idle")
			end
		end)
	elseif kind == "BankHackFailed" then
		if bankSessionId and packetSessionId and packetSessionId ~= bankSessionId then
			return
		end
		bankAnimationToken += 1
		local token = bankAnimationToken
		bankSessionId = nil
		bankPhase = "Failed"
		bankInputPending = false
		bankLastInputKey = nil
		bankSnapshotCanStart = false
		applyBankPacketMetadata(packet)
		setAllBankKeys("Failure")
		setBankMode(tostring(packet.text or packet.reason or "ACCESS DENIED // BANK TRACE COMPLETE"), COLORS.red)
		bankSignal.Text = "● ACCESS DENIED"
		bankSignal.TextColor3 = COLORS.red
		refreshBankStartButton()
		task.delay(0.62, function()
			if token == bankAnimationToken and bankPhase == "Failed" then
				setAllBankKeys("Idle")
			end
		end)
	elseif kind == "BankHackSucceeded" then
		if bankSessionId and packetSessionId and packetSessionId ~= bankSessionId then
			return
		end
		bankAnimationToken += 1
		bankSessionId = nil
		bankPhase = "Succeeded"
		bankInputPending = false
		bankLastInputKey = nil
		bankSnapshotCanStart = false
		applyBankPacketMetadata(packet)
		setBankRoundDisplay(bankRoundCount, bankRoundCount)
		bankInputIndex = bankPatternLength
		updateBankInputProgress()
		setAllBankKeys("Correct")
		setBankMode(tostring(packet.text or "ACCESS GRANTED // TRANSFER COMPLETE"), COLORS.green)
		bankSignal.Text = "● TRANSFER COMPLETE"
		bankSignal.TextColor3 = COLORS.green
		refreshBankStartButton()
		showToast(
			"MEDFORD BANK HACK  +$" .. tostring(math.max(0, math.floor(tonumber(packet.reward) or bankReward))),
			string.format(
				"Next cycle: %.2f-second cues, starting at %d keys. It will be faster%s.",
				math.max(0.1, tonumber(packet.nextPreviewStepSeconds) or bankStepSeconds),
				math.max(1, math.floor(tonumber(packet.nextStartingLength) or 2)),
				tonumber(packet.nextStartingLength) and " and the pattern length keeps climbing" or ""
			),
			COLORS.yellow,
			4.5
		)
	elseif kind == "BankHackCancelled" then
		if packetSessionId then
			bankKeyStyles.pendingCancels[packetSessionId] = nil
		end
		if bankSessionId and packetSessionId and packetSessionId ~= bankSessionId then
			return
		end
		resetBankAttempt(false)
		if terminal.Visible and terminalPage == "Bank" then
			setBankMode(tostring(packet.text or "BANK CONNECTION CANCELLED"), Color3.fromRGB(89, 157, 109))
			bankSignal.Text = "● LINK STANDBY"
			bankSignal.TextColor3 = COLORS.yellow
		end
	elseif kind == "BankHackError" then
		if bankPhase == "Failed" then
			-- A wrong key emits the authoritative Failed packet followed by the
			-- rejected-input explanation. Keep the stronger failure presentation.
			return
		end
		bankInputPending = false
		if bankLastInputKey and bankKeyVisuals[bankLastInputKey] then
			setBankKeyStyle(bankLastInputKey, bankSessionId and "Ready" or "Idle")
		end
		bankLastInputKey = nil
		if bankSessionId then
			bankPhase = "AwaitInput"
		else
			bankPhase = "Idle"
		end
		setBankMode(tostring(packet.text or packet.reason or "BANKLINK COMMAND REJECTED"), COLORS.red)
		bankSignal.Text = bankSessionId and "● TRANSMIT READY" or "● LINK STANDBY"
		bankSignal.TextColor3 = bankSessionId and Color3.fromRGB(111, 238, 255) or COLORS.yellow
		refreshBankStartButton()
	end
end)

feedbackEvent.OnClientEvent:Connect(function(packet)
	if type(packet) ~= "table" then
		return
	end
	local kind = tostring(packet.kind or "")
	if kind == "TerminalOpen" then
		resetBankAttempt(false)
		unbindBankInputs()
		terminalPage = "Home"
		terminalButtons.CanvasPosition = Vector2.zero
		terminal.Visible = true
		upgradeNoticeUi.terminalVisible = true
		gui.DisplayOrder = 65
		upgradeNoticeUi.setControlsLocked(true)
		upgradeNoticeUi.updateScale()
		renderTerminal()
	elseif kind == "TerminalClose" then
		closeComputer(false)
	elseif kind == "TerminalLine" then
		terminalPage = "DOS"
		renderTerminal()
		local command = tostring(packet.command or "")
		local response = tostring(packet.text or "")
		terminalBody.Text = string.format("C:" .. string.char(92) .. "> %s" .. string.char(10) .. "%s", command, response)
	elseif kind == "TaskStarted" then
		showToast(tostring(packet.requester or "FAMILY") .. " REQUEST", packet.text or packet.title, requesterColors[packet.requester] or COLORS.green, 4)
	elseif kind == "TaskComplete" then
		-- BANKLINK already presents its purpose-built transfer toast and success
		-- screen. Keep the generic completion event for compatibility without
		-- racing it onto the same single-toast HUD.
		if tostring(packet.taskId or "") ~= "MedfordBankHack" or packet.automated == true then
			showToast(
				packet.automated == true and ("ROBOT TASK COMPLETE  +$" .. tostring(packet.reward or 0))
					or ("TASK COMPLETE  +$" .. tostring(packet.reward or 0)),
				packet.text or packet.title,
				COLORS.yellow,
				4
			)
		end
	elseif kind == "CandyDeliveryStarted" then
		showToast(
			packet.title or "LOS POLLOS PICKUP",
			packet.text or "Equip the candy pan and take it to the yellow buyer truck.",
			COLORS.yellow,
			6
		)
	elseif kind == "CandyBatchReady" then
		showToast(
			packet.title or "CHEMISTRY BATCH READY",
			packet.text or "Your finished Blue Rock Candy is safe in the bunker output tray.",
			Color3.fromRGB(64, 201, 255),
			6
		)
	elseif kind == "CandyDeliveryComplete" then
		showToast(
			(packet.title or "BATCH SOLD") .. "  +$" .. tostring(packet.payout or 0),
			packet.text or "The Blue Rock Candy batch was delivered.",
			COLORS.green,
			6
		)
	elseif kind == "MachineStage" then
		showToast(packet.title or "COMPONENT INSTALLED", packet.text or "", COLORS.blue, 4.5)
	elseif kind == "TaskUpgradeOrdered" then
		showToast(
			string.upper(tostring(packet.name or "TASK ROBOT")) .. " ORDERED",
			packet.text or "The delivery truck is bringing your automation upgrade.",
			COLORS.terminal,
			4
		)
	elseif kind == "TaskUpgradeInstalled" then
		showToast(
			string.upper(tostring(packet.name or "TASK ROBOT")) .. " INSTALLED",
			packet.text or "This family task will now be completed automatically.",
			COLORS.green,
			4.5
		)
	elseif kind == "TaskAutomationStarted" then
		showToast(
			"ROBOT WORKING",
			packet.text or "Your installed task robot is handling this request automatically.",
			automationTaskColors[tostring(packet.taskId or "")] or COLORS.terminal,
			3.5
		)
	elseif kind == "TaskAutomationFinished" then
		showToast(
			string.upper(tostring(packet.title or "TASK ROBOT")) .. " FINISHED",
			packet.text or "The robot finished its physical route and returned home.",
			automationTaskColors[tostring(packet.taskId or "")] or COLORS.green,
			3.5
		)
	elseif kind == "SecretBunkerPurchased" then
		bunkerPhaseUi.showConstruction("PROJECT AUTHORIZED — CONVOY DISPATCHED", 0)
	elseif kind == "SecretBunkerConstructionStarted" then
		bunkerPhaseUi.showConstruction(packet.stage or "CONSTRUCTION CONVOY APPROACHING", packet.progress or 0)
	elseif kind == "SecretBunkerConstructionComplete" then
		bunkerPhaseUi.complete()
	elseif kind == "SecretBunkerError" then
		showToast("BUNKER PROJECT BLOCKED", packet.text or "The bunker project could not start.", COLORS.red, 4)
	elseif kind == "ChemistrySetupPurchased" then
		showToast("CHEMISTRY LAB ORDERED", packet.text or "The research-equipment truck is headed to the driveway.", Color3.fromRGB(64, 231, 255), 4.5)
	elseif kind == "ChemistryDeliveryArrived" then
		showToast("RESEARCH EQUIPMENT ARRIVED", packet.text or "Pick up the chemistry case in the driveway.", COLORS.yellow, 4.5)
	elseif kind == "ChemistryDeliveryPicked" then
		showToast("CARRY IT TO THE BUNKER", packet.text or "Follow the cyan-and-violet arrow to the chemistry bay.", COLORS.purple, 5)
	elseif kind == "ChemistrySetupPlaced" then
		showToast("ADVANCED CHEMISTRY LAB ONLINE", packet.text or "The bunker reactor and fluid network are ready.", COLORS.green, 5)
	elseif kind == "ChemistrySetupError" then
		showToast("CHEMISTRY ORDER BLOCKED", packet.text or packet.message or "The chemistry setup could not do that yet.", COLORS.red, 4)
	elseif kind == "BoomboxPurchased" then
		showToast("BOOMBOX ORDERED", packet.text or "The delivery truck is bringing your boombox.", COLORS.purple, 4)
	elseif kind == "BoomboxPlaced" then
		upgradeNoticeUi.showBoomboxReady(false, packet.text or "It is set up in the living room. Use its power button when you want to start the party.")
	elseif kind == "BoomboxAutoplayPurchased" then
		showToast("BOOMBOX AUTOPLAY INSTALLED", packet.text or "Autoplay is armed and will start each time your cooldown finishes while you are online.", COLORS.purple, 4.5)
	elseif kind == "BoomboxReady" then
		upgradeNoticeUi.showBoomboxReady(packet.automatic == true, packet.text)
	elseif kind == "BoomboxStarted" then
		if tostring(packet.source or "") == "Autoplay" then
			upgradeNoticeUi.showBoomboxReady(true, "The boombox is ready, and autoplay is starting the next party now.")
		end
		showToast("BOOMBOX PARTY STARTED", packet.text or "Music, disco lights, and automatic allowance are running.", COLORS.purple, 3.5)
	elseif kind == "BoomboxFinished" then
		finishBoomboxIncome(packet)
	elseif kind == "BoomboxIncome" or kind == "BoomboxTick" then
		queueBoomboxIncome(packet)
	elseif kind == "BoomboxError" then
		showToast("BOOMBOX ERROR", packet.message or packet.text or "The boombox could not do that yet.", COLORS.red, 4)
	elseif kind == "Currency"
		and string.find(string.lower(tostring(packet.reason or packet.text or "")), "boombox", 1, true)
	then
		queueBoomboxIncome(packet)
	elseif kind == "Error" then
		showToast("CAN'T DO THAT", packet.text or "", COLORS.red, 3.5)
	elseif kind ~= "ProfileLoaded" then
		showToast(string.upper(kind:gsub("(%l)(%u)", "%1 %2")), packet.text or packet.title or "", COLORS.green, 3.2)
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if not terminal.Visible then
		return
	end
	if input.KeyCode == Enum.KeyCode.ButtonB then
		if terminalPage == "Home" then
			closeComputer(true)
		else
			showPage("Home")
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		closeComputer(true)
	end
end)

UserInputService:GetPropertyChangedSignal("GamepadEnabled"):Connect(function()
	if UserInputService.GamepadEnabled then
		if introScrim.Visible then
			GuiService.SelectedObject = introButton
		elseif terminal.Visible then
			upgradeNoticeUi.focusTerminalDefault()
		end
		return
	end
	local selected = GuiService.SelectedObject
	if selected and (selected:IsDescendantOf(introScrim) or selected:IsDescendantOf(terminal)) then
		GuiService.SelectedObject = nil
	end
end)

-- A live script refresh or PlayerGui teardown must never strand PlayerModule
-- controls in the disabled state or leave selection on an invisible modal.
function upgradeNoticeUi.releaseOwnedModalState()
	unbindBankInputs()
	if dosInput and dosInput.Parent and dosInput:IsFocused() then
		dosInput:ReleaseFocus(false)
	end
	if GuiService.SelectedObject
		and (GuiService.SelectedObject:IsDescendantOf(introScrim)
			or GuiService.SelectedObject:IsDescendantOf(terminal))
	then
		GuiService.SelectedObject = nil
	end
	upgradeNoticeUi.setControlsLocked(false)
end
gui.Destroying:Connect(upgradeNoticeUi.releaseOwnedModalState)
script.Destroying:Connect(upgradeNoticeUi.releaseOwnedModalState)

upgradeNoticeUi.cameraConnection = nil
function upgradeNoticeUi.updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local safeSize = introScrim.AbsoluteSize
	local safeWidth = safeSize.X > 1 and safeSize.X or viewport.X
	local safeHeight = safeSize.Y > 1 and safeSize.Y or viewport.Y
	local previousCompact = upgradeNoticeUi.compactLayout
	local narrowPortrait = safeWidth <= 560 and safeHeight > safeWidth
	upgradeNoticeUi.compactLayout = safeHeight < 600 or narrowPortrait

	-- Portrait phones use a narrower authored canvas instead of shrinking the
	-- 1280-wide desktop HUD into illegible text. The task and machine panels are
	-- reflowed to the full safe width while preserving room to see and steer the
	-- character underneath them.
	if narrowPortrait then
		uiScale.Scale = math.max(0.62, math.min(0.72, safeWidth / 640))
		scaleRoot.Size = UDim2.fromOffset(640, math.max(900, math.floor(safeHeight / uiScale.Scale)))
		topBar.Position = UDim2.new(0.5, 0, 0, 12)
		topBar.Size = UDim2.fromOffset(616, 88)
		allowanceTitle.Position = UDim2.fromOffset(16, 10)
		allowanceTitle.Size = UDim2.fromOffset(136, 20)
		allowanceValue.Position = UDim2.fromOffset(16, 34)
		allowanceValue.Size = UDim2.fromOffset(136, 38)
		divider.Position = UDim2.fromOffset(158, 13)
		divider.Size = UDim2.fromOffset(2, 60)
		machineTitle.Position = UDim2.fromOffset(178, 9)
		machineTitle.Size = UDim2.fromOffset(420, 26)
		machineStage.Position = UDim2.fromOffset(178, 36)
		machineStage.Size = UDim2.fromOffset(420, 22)
		machineTrack.Position = UDim2.fromOffset(178, 65)
		machineTrack.Size = UDim2.fromOffset(420, 10)
		taskPanel.Position = UDim2.fromOffset(12, 116)
		taskPanel.Size = UDim2.fromOffset(616, 245)
		deliveryChip.Position = UDim2.fromOffset(12, 373)
		deliveryChip.Size = UDim2.fromOffset(616, 94)
		toast.Size = UDim2.fromOffset(600, 82)
	elseif upgradeNoticeUi.compactLayout then
		-- On a short landscape phone, keep readable text at roughly the original
		-- camera-fit scale and shorten the authored root itself. Width, rather
		-- than height, owns the scale.
		uiScale.Scale = math.max(0.45, math.min(0.625, safeWidth / 1280))
		scaleRoot.Size = UDim2.fromOffset(1280, math.max(480, math.floor(safeHeight / uiScale.Scale)))
	else
		scaleRoot.Size = UDim2.fromOffset(1280, 720)
		uiScale.Scale = math.max(0.25, math.min(1, safeWidth / 1280, safeHeight / 720))
	end
	if not narrowPortrait then
		topBar.Position = UDim2.new(0.5, 0, 0, 12)
		topBar.Size = UDim2.fromOffset(920, 78)
		allowanceTitle.Position = UDim2.fromOffset(20, 10)
		allowanceTitle.Size = UDim2.fromOffset(190, 20)
		allowanceValue.Position = UDim2.fromOffset(20, 31)
		allowanceValue.Size = UDim2.fromOffset(190, 36)
		divider.Position = UDim2.fromOffset(225, 12)
		divider.Size = UDim2.fromOffset(2, 54)
		machineTitle.Position = UDim2.fromOffset(250, 8)
		machineTitle.Size = UDim2.fromOffset(650, 24)
		machineStage.Position = UDim2.fromOffset(250, 31)
		machineStage.Size = UDim2.fromOffset(650, 22)
		machineTrack.Position = UDim2.fromOffset(250, 58)
		machineTrack.Size = UDim2.fromOffset(650, 10)
		taskPanel.Position = UDim2.fromOffset(18, 112)
		taskPanel.Size = UDim2.fromOffset(390, 245)
		deliveryChip.Position = UDim2.fromOffset(18, 369)
		deliveryChip.Size = UDim2.fromOffset(390, 94)
		toast.Size = UDim2.fromOffset(570, 76)
	end

	if upgradeNoticeUi.compactLayout then
		-- These informational HUD labels inherit UIScale. Slightly larger authored
		-- sizes keep the active task readable at 800x360 without making its panel
		-- cover the play area.
		allowanceTitle.TextSize = 15
		machineTitle.TextSize = 18
		machineStage.TextSize = 15
		taskRequester.TextSize = 16
		taskTitle.TextSize = 22
		taskDescription.TextSize = 16
		taskReward.TextSize = 16
		deliveryTitle.TextSize = 16
		deliveryText.TextSize = 15
		toastTitle.TextSize = 18
		toastText.TextSize = 15
		upgradeNoticeUi.title.TextSize = 22
		upgradeNoticeUi.text.TextSize = 17
		upgradeNoticeUi.hint.TextSize = 15
		upgradeNoticeUi.readyTitle.TextSize = 22
		upgradeNoticeUi.readyText.TextSize = 15
		bunkerPhaseUi.title.TextSize = 22
		bunkerPhaseUi.stage.TextSize = 15
		introCard.Size = UDim2.new(1, -24, 1, -12)
		introTitle.Position = UDim2.fromOffset(16, 8)
		introTitle.Size = UDim2.new(1, -32, 0, 42)
		introTitle.TextSize = 20
		introBody.Position = UDim2.fromOffset(16, 54)
		introBody.Size = UDim2.new(1, -32, 1, -118)
		introBody.TextSize = 14
		introButton.Size = UDim2.fromOffset(250, 48)
		introButton.Position = UDim2.new(0.5, -125, 1, -56)
		introButton.TextSize = 16

		-- Use the complete safe-area height on short landscape phones.  Leaving
		-- the old 12-pixel bottom gap made the third bank-key row fall below the
		-- clipped bank panel on 360-pixel-tall Android devices.
		terminal.Size = UDim2.new(1, -20, 1, 0)
		terminalMenuBar.Visible = false
		terminalTitle.Position = narrowPortrait
			and UDim2.fromOffset(10, 4)
			or UDim2.fromOffset(terminalPage == "Home" and 12 or 184, 6)
		terminalTitle.Size = narrowPortrait
			and UDim2.new(1, -142, 0, 44)
			or UDim2.new(1, terminalPage == "Home" and -154 or -320, 0, 44)
		terminalTitle.TextSize = 15
		terminalClose.Size = UDim2.fromOffset(120, 44)
		terminalClose.Position = UDim2.new(1, -126, 0, 4)
		terminalClose.TextSize = 16
		terminalBack.Size = UDim2.fromOffset(160, 44)
		terminalBack.Position = narrowPortrait and UDim2.fromOffset(8, 52) or UDim2.fromOffset(6, 4)
		terminalBack.TextSize = 15
		terminalBody.Position = narrowPortrait
			and UDim2.fromOffset(12, terminalPage == "Home" and 56 or 102)
			or UDim2.fromOffset(12, 56)
		terminalBody.Size = narrowPortrait
			and UDim2.new(1, -24, 0, terminalPage == "Home" and 94 or 100)
			or UDim2.new(0.4, -18, 1, -64)
		terminalBody.TextSize = 13
		terminalTreePanel.Position = narrowPortrait
			and UDim2.fromOffset(12, terminalPage == "Home" and 158 or 210)
			or UDim2.new(0.4, 0, 0, 54)
		terminalTreePanel.Size = narrowPortrait
			and UDim2.new(1, -24, 1, terminalPage == "Home" and -170 or -222)
			or UDim2.new(0.6, -8, 1, -62)
		terminalTreeHeader.Position = UDim2.fromOffset(8, 3)
		terminalTreeHeader.Size = UDim2.new(1, -16, 0, 20)
		terminalTreeHeader.TextSize = 12
		terminalButtons.Position = UDim2.fromOffset(8, 25)
		terminalButtons.Size = UDim2.new(1, -16, 1, -31)
		terminalButtons.ScrollBarThickness = 10

		bankPanel.Position = UDim2.fromOffset(10, 54)
		bankPanel.Size = UDim2.new(1, -20, 1, -56)
		bankHeader.Position = UDim2.fromOffset(6, 4)
		bankHeader.Size = UDim2.new(1, -12, 0, 26)
		bankHeaderTitle.Text = "MEDFORD BANK // SECURE LINK"
		bankHeaderTitle.Position = UDim2.fromOffset(8, 1)
		bankHeaderTitle.Size = UDim2.new(1, -180, 0, 24)
		bankHeaderTitle.TextSize = 12
		bankHeaderSubtitle.Visible = false
		bankSignal.Position = UDim2.new(1, -170, 0, 0)
		bankSignal.Size = UDim2.fromOffset(162, 26)
		bankSignal.TextSize = 10
		bankMode.Position = UDim2.fromOffset(6, 30)
		bankMode.Size = UDim2.new(1, -192, 0, 44)
		bankMode.TextSize = 12
		bankRoundStrip.Position = UDim2.fromOffset(10, 76)
		bankRoundStrip.Size = UDim2.new(1, -20, 0, 12)
		bankRoundLabel.Size = UDim2.fromOffset(114, 12)
		bankRoundLabel.TextSize = 9
		bankInputProgress.Size = UDim2.fromOffset(170, 12)
		bankInputProgress.Position = UDim2.new(1, -170, 0, 0)
		bankInputProgress.TextSize = 9
		bankKeyboardLabel.Visible = false
		bankStartButton.Position = UDim2.new(1, -180, 0, 30)
		bankStartButton.Size = UDim2.fromOffset(174, 44)
		bankStartButton.TextSize = 13
		bankFooter.Visible = false
		for index, led in ipairs(bankRoundLeds) do
			led.Position = UDim2.fromOffset(120 + (index - 1) * 26, 1)
			led.Size = UDim2.fromOffset(20, 10)
		end
		for _, valueLabel in pairs(bankReadouts) do
			valueLabel.Parent.Visible = false
		end
		for _, visual in pairs(bankKeyVisuals) do
			local keyButton = visual.button
			local column = string.find("QWER", keyButton.Text, 1, true)
				or string.find("ASDF", keyButton.Text, 1, true)
				or string.find("ZXCV", keyButton.Text, 1, true)
				or 1
			local rowFrame = keyButton.Parent
			local rowNumber = tonumber(string.match(rowFrame.Name, "%d+")) or 1
			-- Preserve a full 44-pixel touch target for every key while fitting all
			-- three rows inside the smallest supported landscape-phone safe area.
			rowFrame.Position = UDim2.new(0.5, 0, 0, 88 + (rowNumber - 1) * 45)
			rowFrame.Size = UDim2.new(1, -12, 0, 44)
			keyButton.Position = UDim2.new((column - 1) * 0.25, column == 1 and 0 or 3, 0, 0)
			keyButton.Size = UDim2.new(0.25, -5, 1, 0)
			keyButton.TextSize = 22
		end
	else
		allowanceTitle.TextSize = 13
		machineTitle.TextSize = 17
		machineStage.TextSize = 14
		taskRequester.TextSize = 13
		taskTitle.TextSize = 20
		taskDescription.TextSize = 15
		taskReward.TextSize = 14
		deliveryTitle.TextSize = 14
		deliveryText.TextSize = 13
		toastTitle.TextSize = 17
		toastText.TextSize = 14
		upgradeNoticeUi.title.TextSize = 20
		upgradeNoticeUi.text.TextSize = 15
		upgradeNoticeUi.hint.TextSize = 13
		upgradeNoticeUi.readyTitle.TextSize = 21
		upgradeNoticeUi.readyText.TextSize = 14
		bunkerPhaseUi.title.TextSize = 21
		bunkerPhaseUi.stage.TextSize = 14
		introCard.Size = UDim2.fromOffset(650, 360)
		introTitle.Position = UDim2.fromOffset(25, 22)
		introTitle.Size = UDim2.new(1, -50, 0, 62)
		introTitle.TextSize = 25
		introBody.Position = UDim2.fromOffset(35, 90)
		introBody.Size = UDim2.new(1, -70, 0, 205)
		introBody.TextSize = 17
		introButton.Size = UDim2.fromOffset(230, 50)
		introButton.Position = UDim2.new(0.5, -115, 1, -70)
		introButton.TextSize = 16

		terminal.Size = UDim2.fromOffset(math.min(900, math.max(560, safeWidth - 48)), math.min(620, math.max(500, safeHeight - 8)))
		terminalMenuBar.Visible = true
		terminalTitle.Position = UDim2.fromOffset(14, 30)
		terminalTitle.Size = UDim2.new(1, -150, 0, 28)
		terminalTitle.TextSize = 20
		terminalClose.Size = UDim2.fromOffset(108, UserInputService.TouchEnabled and 44 or 36)
		terminalClose.Position = UDim2.new(1, -120, 0, 8)
		terminalClose.TextSize = 15
		terminalBack.Size = UDim2.fromOffset(170, UserInputService.TouchEnabled and 44 or 38)
		terminalBack.Position = UDim2.fromOffset(14, UserInputService.TouchEnabled and 54 or 56)
		terminalBack.TextSize = 15
		terminalBody.Position = UDim2.fromOffset(14, 98)
		terminalBody.Size = UDim2.new(0.42, -24, 1, -112)
		terminalBody.TextSize = 15
		terminalTreePanel.Position = UDim2.new(0.42, 0, 0, 58)
		terminalTreePanel.Size = UDim2.new(0.58, -14, 1, -72)
		terminalTreeHeader.Position = UDim2.fromOffset(8, 6)
		terminalTreeHeader.Size = UDim2.new(1, -16, 0, 24)
		terminalTreeHeader.TextSize = 13
		terminalButtons.Position = UDim2.fromOffset(8, 32)
		terminalButtons.Size = UDim2.new(1, -16, 1, -40)
		terminalButtons.ScrollBarThickness = 8

		bankPanel.Position = UDim2.fromOffset(14, 98)
		bankPanel.Size = UDim2.new(1, -28, 1, -112)
		bankHeader.Position = UDim2.fromOffset(10, 8)
		bankHeader.Size = UDim2.new(1, -20, 0, 48)
		bankHeaderTitle.Text = "MEDFORD NATIONAL BANK // SECURE DIAL-UP"
		bankHeaderTitle.Position = UDim2.fromOffset(12, 4)
		bankHeaderTitle.Size = UDim2.new(1, -190, 0, 24)
		bankHeaderTitle.TextSize = 18
		bankHeaderSubtitle.Visible = true
		bankSignal.Position = UDim2.new(1, -184, 0, 8)
		bankSignal.Size = UDim2.fromOffset(172, 32)
		bankSignal.TextSize = 13
		bankMode.Position = UDim2.fromOffset(10, 62)
		bankMode.Size = UDim2.new(1, -20, 0, 38)
		bankMode.TextSize = 20
		bankRoundStrip.Position = UDim2.fromOffset(10, 173)
		bankRoundStrip.Size = UDim2.new(1, -20, 0, 25)
		bankRoundLabel.Size = UDim2.fromOffset(150, 25)
		bankRoundLabel.TextSize = 11
		bankInputProgress.Size = UDim2.fromOffset(220, 25)
		bankInputProgress.Position = UDim2.new(1, -220, 0, 0)
		bankInputProgress.TextSize = 12
		bankKeyboardLabel.Visible = true
		bankStartButton.Position = UDim2.new(0, 10, 1, -48)
		bankStartButton.Size = UDim2.fromOffset(252, UserInputService.TouchEnabled and 44 or 40)
		bankStartButton.TextSize = 14
		bankFooter.Visible = true
		for index, led in ipairs(bankRoundLeds) do
			led.Position = UDim2.fromOffset(155 + (index - 1) * 34, 4)
			led.Size = UDim2.fromOffset(24, 14)
		end
		for _, valueLabel in pairs(bankReadouts) do
			valueLabel.Parent.Visible = true
		end
		for _, visual in pairs(bankKeyVisuals) do
			local keyButton = visual.button
			local column = string.find("QWER", keyButton.Text, 1, true)
				or string.find("ASDF", keyButton.Text, 1, true)
				or string.find("ZXCV", keyButton.Text, 1, true)
				or 1
			local rowFrame = keyButton.Parent
			local rowNumber = tonumber(string.match(rowFrame.Name, "%d+")) or 1
			rowFrame.Position = UDim2.new(0.5, 0, 0, 228 + (rowNumber - 1) * 71)
			rowFrame.Size = UDim2.fromOffset(620, 62)
			keyButton.Position = UDim2.fromOffset((column - 1) * 158, 0)
			keyButton.Size = UDim2.fromOffset(146, 62)
			keyButton.TextSize = 27
		end
	end
	local personalFrame = scaleRoot:FindFirstChild("PersonalObjectiveChip")
	if personalFrame and personalFrame:IsA("Frame") then
		personalFrame.Position = narrowPortrait and UDim2.fromOffset(12, 373) or UDim2.fromOffset(18, 369)
		personalFrame.Size = narrowPortrait and UDim2.fromOffset(616, 94) or UDim2.fromOffset(390, 94)
		local personalTitle = personalFrame:FindFirstChild("Title")
		local personalText = personalFrame:FindFirstChild("Text")
		if personalTitle and personalTitle:IsA("TextLabel") then
			personalTitle.TextSize = upgradeNoticeUi.compactLayout and 16 or 14
		end
		if personalText and personalText:IsA("TextLabel") then
			personalText.TextSize = upgradeNoticeUi.compactLayout and 15 or 13
		end
	end
	local pauseFrame = scaleRoot:FindFirstChild("PartyReconnectPause")
	if pauseFrame and pauseFrame:IsA("Frame") then
		pauseFrame.Size = narrowPortrait
			and UDim2.fromOffset(600, 104)
			or upgradeNoticeUi.compactLayout
			and UDim2.fromOffset(920, 98)
			or UDim2.fromOffset(520, 88)
		local pauseTitle = pauseFrame:FindFirstChild("Title")
		local pauseText = pauseFrame:FindFirstChild("Text")
		if pauseTitle and pauseTitle:IsA("TextLabel") then
			pauseTitle.TextSize = upgradeNoticeUi.compactLayout and 22 or 18
		end
		if pauseText and pauseText:IsA("TextLabel") then
			pauseText.TextSize = upgradeNoticeUi.compactLayout and 17 or 13
		end
	end
	if previousCompact ~= upgradeNoticeUi.compactLayout and terminal.Visible then
		renderTerminal()
	end
end
function upgradeNoticeUi.bindCamera()
	if upgradeNoticeUi.cameraConnection then
		upgradeNoticeUi.cameraConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		upgradeNoticeUi.cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(upgradeNoticeUi.updateScale)
	end
	upgradeNoticeUi.updateScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(upgradeNoticeUi.bindCamera)
upgradeNoticeUi.safeAreaConnection = introScrim:GetPropertyChangedSignal("AbsoluteSize"):Connect(upgradeNoticeUi.updateScale)
upgradeNoticeUi.bindCamera()

-- Hide authored task-only props before the first profile snapshot arrives.
updateDirtyDishesVisibility(nil)
requestEvent:FireServer("RequestSnapshot")
print("[CooperGame] Personal family task HUD, computer shop, hidden clues, and machine presentation ready")
