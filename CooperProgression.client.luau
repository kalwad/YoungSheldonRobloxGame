--!nonstrict
-- Responsive presentation/input client for the advanced Cooper progression
-- layer. The server remains authoritative for allowance, upgrades, reactor
-- operation, calibration, the finale, and apartment travel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local ROOT_TIMEOUT = 20
local NL = string.char(10)
local player = Players.LocalPlayer
if not player then
	warn("[CooperProgressionClient] LocalPlayer is unavailable")
	return
end

local playerGui = player:WaitForChild("PlayerGui", ROOT_TIMEOUT)
local progressionRoot = ReplicatedStorage:WaitForChild("CooperProgression", ROOT_TIMEOUT)
if not playerGui or not progressionRoot or not progressionRoot:IsA("Folder") then
	warn("[CooperProgressionClient] Progression hierarchy is unavailable; client disabled safely")
	return
end

local configModule = progressionRoot:WaitForChild("Config", ROOT_TIMEOUT)
local remotes = progressionRoot:WaitForChild("Remotes", ROOT_TIMEOUT)
if not configModule or not configModule:IsA("ModuleScript") or not remotes or not remotes:IsA("Folder") then
	warn("[CooperProgressionClient] Config or Remotes is missing; client disabled safely")
	return
end

local configOK, Config = pcall(require, configModule)
if not configOK or type(Config) ~= "table" or type(Config.Upgrades) ~= "table" then
	warn("[CooperProgressionClient] Config failed to load: " .. tostring(Config))
	return
end

local snapshotEvent = remotes:WaitForChild("Snapshot", ROOT_TIMEOUT)
local feedbackEvent = remotes:WaitForChild("Feedback", ROOT_TIMEOUT)
local requestEvent = remotes:WaitForChild("Request", ROOT_TIMEOUT)
local finaleEvent = remotes:WaitForChild("Finale", ROOT_TIMEOUT)
for name, remote in pairs({
	Snapshot = snapshotEvent,
	Feedback = feedbackEvent,
	Request = requestEvent,
	Finale = finaleEvent,
}) do
	if not remote or not remote:IsA("RemoteEvent") then
		warn("[CooperProgressionClient] Invalid remote " .. name .. "; client disabled safely")
		return
	end
end

local previousGui = playerGui:FindFirstChild("CooperProgressionHUD")
if previousGui then
	previousGui:Destroy()
end

local COLORS = {
	ink = Color3.fromRGB(10, 14, 20),
	panel = Color3.fromRGB(20, 27, 36),
	panelLight = Color3.fromRGB(32, 42, 54),
	panelSoft = Color3.fromRGB(26, 34, 44),
	cream = Color3.fromRGB(239, 232, 207),
	muted = Color3.fromRGB(163, 176, 190),
	white = Color3.fromRGB(250, 251, 252),
	blue = Color3.fromRGB(82, 184, 236),
	green = Color3.fromRGB(72, 210, 139),
	yellow = Color3.fromRGB(247, 199, 78),
	orange = Color3.fromRGB(242, 143, 63),
	red = Color3.fromRGB(239, 79, 88),
	purple = Color3.fromRGB(190, 123, 247),
	cyan = Color3.fromRGB(81, 225, 225),
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 10)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color or COLORS.muted
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0
	item.Parent = parent
	return item
end

local function label(parent, name, text, size, position, font, textSize, color, alignment)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Text = text or ""
	item.TextColor3 = color or COLORS.white
	item.Font = font or Enum.Font.GothamMedium
	item.TextSize = textSize or 14
	item.TextWrapped = true
	item.TextXAlignment = alignment or Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.Parent = parent
	return item
end

local function button(parent, name, text, size, position, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color or COLORS.panelLight
	item.BorderSizePixel = 0
	item.Text = text or ""
	item.TextColor3 = COLORS.white
	item.Font = Enum.Font.GothamBold
	item.TextSize = 13
	item.TextWrapped = true
	item.AutoButtonColor = true
	item.Active = true
	item.Selectable = true
	item.Parent = parent
	corner(item, 8)
	stroke(item, COLORS.cream, 1, 0.72)
	return item
end

local function setButtonEnabled(item, enabled, color)
	item.Active = enabled
	item.Selectable = enabled
	item.AutoButtonColor = enabled
	item.BackgroundColor3 = enabled and (color or COLORS.panelLight) or Color3.fromRGB(47, 51, 57)
	item.TextColor3 = enabled and COLORS.white or Color3.fromRGB(128, 135, 143)
	item.BackgroundTransparency = enabled and 0 or 0.18
end

local function finite(value, fallback, minimum, maximum)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return fallback
	end
	return math.clamp(number, minimum, maximum)
end

local function integer(value, fallback, minimum, maximum)
	return math.floor(finite(value, fallback, minimum, maximum) + 0.5)
end

local function cleanText(value, fallback, maximumLength)
	local result = type(value) == "string" and value or fallback
	result = tostring(result or "")
	if #result > (maximumLength or 240) then
		result = string.sub(result, 1, maximumLength or 240)
	end
	return result
end

local function money(value)
	local amount = integer(value, 0, 0, 2_000_000_000)
	local formatted = tostring(amount)
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return "$" .. formatted
end

local function percent(value, maximum)
	local denominator = math.max(0.001, finite(maximum, 100, 0.001, 1_000_000))
	return math.clamp(finite(value, 0, 0, denominator) / denominator, 0, 1)
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperProgressionHUD"
gui.DisplayOrder = 42
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Compact machine/reactor state HUD -----------------------------------------

local status = Instance.new("Frame")
status.Name = "ProgressionStatus"
status.AnchorPoint = Vector2.new(1, 1)
status.Position = UDim2.new(1, -16, 1, -16)
status.Size = UDim2.fromOffset(310, 176)
status.BackgroundColor3 = COLORS.panel
status.BackgroundTransparency = 0.045
status.BorderSizePixel = 0
status.ZIndex = 10
status.Parent = gui
corner(status, 13)
local statusStroke = stroke(status, COLORS.blue, 2, 0.25)

local statusTitle = label(status, "Title", "TIME MACHINE", UDim2.new(1, -80, 0, 24), UDim2.fromOffset(14, 9), Enum.Font.GothamBlack, 15, COLORS.blue)
statusTitle.ZIndex = 11
local collapseButton = button(status, "Collapse", "–", UDim2.fromOffset(34, 28), UDim2.new(1, -44, 0, 7), COLORS.panelLight)
collapseButton.TextSize = 18
collapseButton.ZIndex = 12
local chapterLabel = label(status, "Chapter", "CHAPTER 0 • THE BLUEPRINT", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 34), Enum.Font.GothamBold, 10, COLORS.muted)
chapterLabel.ZIndex = 11
local machineLabel = label(status, "Machine", "STAGE 0 / 11 • 0%", UDim2.new(1, -28, 0, 23), UDim2.fromOffset(14, 55), Enum.Font.GothamBlack, 14, COLORS.cream)
machineLabel.ZIndex = 11

local machineTrack = Instance.new("Frame")
machineTrack.Name = "MachineTrack"
machineTrack.Position = UDim2.fromOffset(14, 82)
machineTrack.Size = UDim2.new(1, -28, 0, 9)
machineTrack.BackgroundColor3 = Color3.fromRGB(8, 11, 15)
machineTrack.BorderSizePixel = 0
machineTrack.ZIndex = 11
machineTrack.Parent = status
corner(machineTrack, 5)
local machineFill = Instance.new("Frame")
machineFill.Name = "Fill"
machineFill.Size = UDim2.fromScale(0, 1)
machineFill.BackgroundColor3 = COLORS.blue
machineFill.BorderSizePixel = 0
machineFill.ZIndex = 12
machineFill.Parent = machineTrack
corner(machineFill, 5)

local nextStageLabel = label(status, "NextStage", "NEXT COMPONENT: SYNCING…", UDim2.new(1, -28, 0, 39), UDim2.fromOffset(14, 98), Enum.Font.GothamMedium, 11, COLORS.muted)
nextStageLabel.TextYAlignment = Enum.TextYAlignment.Top
nextStageLabel.ZIndex = 11
local persistenceLabel = label(status, "Persistence", "ADVANCED PROFILE: SYNCING", UDim2.new(1, -134, 0, 18), UDim2.fromOffset(14, 147), Enum.Font.GothamBold, 9, COLORS.muted)
persistenceLabel.ZIndex = 11
local catalogButton = button(status, "Catalog", "CATALOG", UDim2.fromOffset(104, 25), UDim2.new(1, -118, 0, 141), COLORS.blue)
catalogButton.TextSize = 9
catalogButton.ZIndex = 12

local reactorSection = Instance.new("Frame")
reactorSection.Name = "ReactorSection"
reactorSection.Position = UDim2.fromOffset(10, 168)
reactorSection.Size = UDim2.new(1, -20, 0, 182)
reactorSection.BackgroundColor3 = COLORS.ink
reactorSection.BackgroundTransparency = 0.25
reactorSection.BorderSizePixel = 0
reactorSection.Visible = false
reactorSection.ZIndex = 11
reactorSection.Parent = status
corner(reactorSection, 10)

local reactorTitle = label(reactorSection, "Title", "GARAGE REACTOR • SAFE", UDim2.new(1, -18, 0, 20), UDim2.fromOffset(9, 6), Enum.Font.GothamBlack, 11, COLORS.green)
reactorTitle.ZIndex = 12
local chargeLabel = label(reactorSection, "Charge", "COMMISSION 0 / 20", UDim2.new(1, -18, 0, 18), UDim2.fromOffset(9, 26), Enum.Font.GothamBold, 10, COLORS.cream)
chargeLabel.ZIndex = 12

local meterRows = {}
local function makeMeter(parent, id, rowY, color)
	local title = label(parent, id .. "Label", string.upper(id), UDim2.fromOffset(72, 16), UDim2.fromOffset(9, rowY), Enum.Font.GothamBold, 9, COLORS.muted)
	title.ZIndex = 12
	local track = Instance.new("Frame")
	track.Name = id .. "Track"
	track.Position = UDim2.fromOffset(78, rowY + 3)
	track.Size = UDim2.new(1, -126, 0, 9)
	track.BackgroundColor3 = Color3.fromRGB(12, 16, 21)
	track.BorderSizePixel = 0
	track.ZIndex = 12
	track.Parent = parent
	corner(track, 5)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.ZIndex = 13
	fill.Parent = track
	corner(fill, 5)
	local value = label(parent, id .. "Value", "0", UDim2.fromOffset(41, 16), UDim2.new(1, -47, 0, rowY), Enum.Font.GothamBold, 9, COLORS.cream, Enum.TextXAlignment.Right)
	value.ZIndex = 12
	meterRows[id] = { fill = fill, value = value }
end

makeMeter(reactorSection, "Coolant", 48, COLORS.blue)
makeMeter(reactorSection, "Heat", 69, COLORS.orange)
makeMeter(reactorSection, "Suspicion", 90, COLORS.red)

local calibrationLabel = label(reactorSection, "Calibration", "CALIBRATION: LOCKED", UDim2.new(1, -18, 0, 18), UDim2.fromOffset(9, 110), Enum.Font.GothamBold, 9, COLORS.yellow)
calibrationLabel.ZIndex = 12
local reactorHint = label(reactorSection, "Hint", "Use controls while standing at the matching garage console.", UDim2.new(1, -18, 0, 27), UDim2.fromOffset(9, 130), Enum.Font.GothamMedium, 8, COLORS.muted)
reactorHint.ZIndex = 12

local modeButton = button(reactorSection, "Mode", "MODE", UDim2.new(0.25, -7, 0, 27), UDim2.new(0, 8, 1, -34), COLORS.orange)
local toggleButton = button(reactorSection, "Toggle", "START", UDim2.new(0.25, -7, 0, 27), UDim2.new(0.25, 3, 1, -34), COLORS.green)
local refillButton = button(reactorSection, "Refill", "REFILL", UDim2.new(0.25, -7, 0, 27), UDim2.new(0.5, 2, 1, -34), COLORS.blue)
local launchButton = button(reactorSection, "Launch", "LAUNCH", UDim2.new(0.25, -7, 0, 27), UDim2.new(0.75, 1, 1, -34), COLORS.yellow)
for _, item in ipairs({ modeButton, toggleButton, refillButton, launchButton }) do
	item.TextSize = 9
	item.ZIndex = 13
end

local statusCollapsed = false
local statusExpandedHeight = 360
local statusBaseHeight = 176

-- Toasts --------------------------------------------------------------------

local toast = Instance.new("Frame")
toast.Name = "FeedbackToast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 102)
toast.Size = UDim2.fromOffset(560, 70)
toast.BackgroundColor3 = COLORS.panel
toast.BackgroundTransparency = 0.02
toast.BorderSizePixel = 0
toast.Visible = false
toast.ZIndex = 90
toast.Parent = gui
corner(toast, 12)
local toastStroke = stroke(toast, COLORS.green, 2, 0.12)
local toastTitle = label(toast, "Title", "", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), Enum.Font.GothamBlack, 14, COLORS.green, Enum.TextXAlignment.Center)
toastTitle.ZIndex = 91
local toastBody = label(toast, "Body", "", UDim2.new(1, -24, 0, 29), UDim2.fromOffset(12, 33), Enum.Font.GothamMedium, 12, COLORS.white, Enum.TextXAlignment.Center)
toastBody.ZIndex = 91
local toastToken = 0

local function showToast(titleText, bodyText, color, duration)
	toastToken += 1
	local token = toastToken
	local accent = color or COLORS.green
	toastTitle.Text = cleanText(titleText, "COOPER PROJECT", 80)
	toastBody.Text = cleanText(bodyText, "", 260)
	toastTitle.TextColor3 = accent
	toastStroke.Color = accent
	toast.Position = UDim2.new(0.5, 0, 0, 92)
	toast.BackgroundTransparency = 1
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 102),
		BackgroundTransparency = 0.02,
	}):Play()
	task.delay(duration or 3.6, function()
		if token ~= toastToken or not toast.Parent then
			return
		end
		local tween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, 92),
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		if token == toastToken and toast.Parent then
			toast.Visible = false
		end
	end)
end

-- Upgrade shop --------------------------------------------------------------

local shopScrim = Instance.new("Frame")
shopScrim.Name = "UpgradeShopScrim"
shopScrim.Size = UDim2.fromScale(1, 1)
shopScrim.BackgroundColor3 = Color3.new(0, 0, 0)
shopScrim.BackgroundTransparency = 0.33
shopScrim.BorderSizePixel = 0
shopScrim.Visible = false
shopScrim.Active = true
shopScrim.ZIndex = 100
shopScrim.Parent = gui

local shop = Instance.new("Frame")
shop.Name = "UpgradeShop"
shop.AnchorPoint = Vector2.new(0.5, 0.5)
shop.Position = UDim2.fromScale(0.5, 0.5)
shop.Size = UDim2.fromOffset(900, 620)
shop.BackgroundColor3 = COLORS.panel
shop.BorderSizePixel = 0
shop.ZIndex = 101
shop.Parent = shopScrim
corner(shop, 16)
stroke(shop, COLORS.purple, 3, 0.08)

local shopTitle = label(shop, "Title", "COOPER GARAGE UPGRADES", UDim2.new(1, -215, 0, 32), UDim2.fromOffset(20, 13), Enum.Font.GothamBlack, 20, COLORS.purple)
shopTitle.ZIndex = 102
local shopSubtitle = label(shop, "Subtitle", "Permanent upgrades paid from your Family allowance", UDim2.new(1, -215, 0, 20), UDim2.fromOffset(20, 44), Enum.Font.GothamMedium, 11, COLORS.muted)
shopSubtitle.ZIndex = 102
local shopAllowance = label(shop, "Allowance", "$0", UDim2.fromOffset(120, 32), UDim2.new(1, -178, 0, 12), Enum.Font.GothamBlack, 20, COLORS.yellow, Enum.TextXAlignment.Right)
shopAllowance.ZIndex = 102
local shopClose = button(shop, "Close", "×", UDim2.fromOffset(38, 38), UDim2.new(1, -50, 0, 10), Color3.fromRGB(112, 45, 54))
shopClose.TextSize = 22
shopClose.ZIndex = 103

local tabBar = Instance.new("ScrollingFrame")
tabBar.Name = "CategoryTabs"
tabBar.Position = UDim2.fromOffset(16, 74)
tabBar.Size = UDim2.new(1, -32, 0, 40)
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.CanvasSize = UDim2.fromOffset(0, 0)
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.ScrollBarThickness = 3
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.ZIndex = 102
tabBar.Parent = shop
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 7)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local upgradeList = Instance.new("ScrollingFrame")
upgradeList.Name = "UpgradeList"
upgradeList.Position = UDim2.fromOffset(16, 120)
upgradeList.Size = UDim2.new(1, -32, 1, -168)
upgradeList.BackgroundColor3 = COLORS.ink
upgradeList.BackgroundTransparency = 0.3
upgradeList.BorderSizePixel = 0
upgradeList.ScrollBarThickness = 7
upgradeList.ScrollBarImageColor3 = COLORS.purple
upgradeList.CanvasSize = UDim2.fromOffset(0, 0)
upgradeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
upgradeList.ZIndex = 102
upgradeList.Parent = shop
corner(upgradeList, 10)
local upgradePadding = Instance.new("UIPadding")
upgradePadding.PaddingTop = UDim.new(0, 8)
upgradePadding.PaddingBottom = UDim.new(0, 8)
upgradePadding.PaddingLeft = UDim.new(0, 8)
upgradePadding.PaddingRight = UDim.new(0, 8)
upgradePadding.Parent = upgradeList
local upgradeLayout = Instance.new("UIListLayout")
upgradeLayout.Padding = UDim.new(0, 8)
upgradeLayout.SortOrder = Enum.SortOrder.LayoutOrder
upgradeLayout.Parent = upgradeList

local shopFooter = label(shop, "Footer", "Purchases only work while you are standing at the Garage Upgrade Console.", UDim2.new(1, -32, 0, 28), UDim2.new(0, 16, 1, -39), Enum.Font.GothamBold, 10, COLORS.muted, Enum.TextXAlignment.Center)
shopFooter.ZIndex = 102

local currentCategory = "All"
local categoryButtons = {}
local shopOpen = false
local pendingUpgradeId = nil
local currentSnapshot = nil
local lastRevision = -1

local configuredCategories = { "All" }
for _, category in ipairs(type(Config.UpgradeCategoryOrder) == "table" and Config.UpgradeCategoryOrder or {}) do
	if type(category) == "string" and not table.find(configuredCategories, category) then
		table.insert(configuredCategories, category)
	end
end
for _, definition in ipairs(Config.Upgrades) do
	if type(definition) == "table" and type(definition.category) == "string" and not table.find(configuredCategories, definition.category) then
		table.insert(configuredCategories, definition.category)
	end
end

local rebuildShop
local function selectCategory(category)
	currentCategory = category
	for name, item in pairs(categoryButtons) do
		item.BackgroundColor3 = name == category and COLORS.purple or COLORS.panelLight
		item.TextColor3 = name == category and COLORS.white or COLORS.muted
	end
	upgradeList.CanvasPosition = Vector2.zero
	if rebuildShop then
		rebuildShop()
	end
end

for index, category in ipairs(configuredCategories) do
	local tab = button(tabBar, "Category_" .. string.gsub(category, "%W", ""), string.upper(category), UDim2.fromOffset(math.clamp(#category * 8 + 34, 76, 190), 32), UDim2.fromOffset(0, 0), COLORS.panelLight)
	tab.LayoutOrder = index
	tab.TextSize = 10
	tab.ZIndex = 103
	categoryButtons[category] = tab
	tab.Activated:Connect(function()
		selectCategory(category)
	end)
end

local requestNextAt = 0
local function sendRequest(action, payload)
	if type(action) ~= "string" or os.clock() < requestNextAt then
		return false
	end
	requestNextAt = os.clock() + 0.22
	local ok, message = pcall(function()
		requestEvent:FireServer(action, payload)
	end)
	if not ok then
		showToast("CONNECTION ERROR", tostring(message), COLORS.red, 4)
	end
	return ok
end

rebuildShop = function()
	for _, child in ipairs(upgradeList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local snapshot = currentSnapshot or {}
	local levels = type(snapshot.upgrades) == "table" and snapshot.upgrades or {}
	local allowance = integer(snapshot.allowance, 0, 0, 2_000_000_000)
	local loaded = snapshot.profileLoaded == true and snapshot.foundationReady == true
	local finaleRunning = type(snapshot.finale) == "table" and snapshot.finale.running == true
	local compactCards = shop.AbsoluteSize.X > 0 and shop.AbsoluteSize.X < 520
	local shown = 0
	for _, definition in ipairs(Config.Upgrades) do
		if type(definition) == "table" and (currentCategory == "All" or definition.category == currentCategory) then
			shown += 1
			local upgradeId = cleanText(definition.id, "Unknown", 64)
			local maximum = integer(definition.maxLevel, 1, 1, 99)
			local level = integer(levels[upgradeId], 0, 0, maximum)
			local costs = type(definition.costs) == "table" and definition.costs or {}
			local nextCostRecord = costs[level + 1]
			local nextCost = type(nextCostRecord) == "table" and integer(nextCostRecord.allowance, 0, 0, 2_000_000_000) or 0
			local maxed = level >= maximum
			local affordable = not maxed and nextCost > 0 and allowance >= nextCost

			local card = Instance.new("Frame")
			card.Name = "Upgrade_" .. string.gsub(upgradeId, "%W", "")
			card.Size = UDim2.new(1, -2, 0, compactCards and 150 or 116)
			card.BackgroundColor3 = COLORS.panelSoft
			card.BorderSizePixel = 0
			card.LayoutOrder = shown
			card.ZIndex = 103
			card.Parent = upgradeList
			corner(card, 9)
			stroke(card, maxed and COLORS.green or COLORS.purple, 1, maxed and 0.45 or 0.68)

			local nameLabel = label(card, "Name", cleanText(definition.name, upgradeId, 80), compactCards and UDim2.new(1, -24, 0, 24) or UDim2.new(1, -150, 0, 24), UDim2.fromOffset(12, 8), Enum.Font.GothamBlack, 13, maxed and COLORS.green or COLORS.cream)
			nameLabel.ZIndex = 104
			local categoryLabel = label(card, "Category", string.upper(cleanText(definition.category, "UPGRADE", 48)), compactCards and UDim2.new(1, -24, 0, 16) or UDim2.new(1, -150, 0, 16), UDim2.fromOffset(12, 31), Enum.Font.GothamBold, 8, COLORS.purple)
			categoryLabel.ZIndex = 104
			local description = label(card, "Description", cleanText(definition.description, "", 180), compactCards and UDim2.new(1, -24, 0, 55) or UDim2.new(1, -154, 0, 54), UDim2.fromOffset(12, 50), Enum.Font.GothamMedium, 10, COLORS.muted)
			description.TextYAlignment = Enum.TextYAlignment.Top
			description.ZIndex = 104

			local levelLabel = label(card, "Level", string.format("LEVEL %d / %d", level, maximum), UDim2.fromOffset(122, 19), compactCards and UDim2.fromOffset(8, 118) or UDim2.new(1, -134, 0, 10), Enum.Font.GothamBlack, 9, maxed and COLORS.green or COLORS.yellow, Enum.TextXAlignment.Center)
			levelLabel.ZIndex = 104
			local buyText
			if maxed then
				buyText = "MAX LEVEL"
			elseif pendingUpgradeId == upgradeId then
				buyText = "PURCHASING…"
			elseif nextCost <= 0 then
				buyText = "UNAVAILABLE"
			else
				buyText = money(nextCost) .. NL .. "BUY LEVEL " .. tostring(level + 1)
			end
			local buy = button(card, "Buy", buyText, UDim2.fromOffset(122, compactCards and 38 or 62), compactCards and UDim2.new(1, -134, 0, 106) or UDim2.new(1, -134, 0, 39), affordable and COLORS.purple or COLORS.panelLight)
			buy.TextSize = 10
			buy.ZIndex = 104
			local canBuy = loaded and affordable and not finaleRunning and pendingUpgradeId == nil
			setButtonEnabled(buy, canBuy, COLORS.purple)
			buy.Activated:Connect(function()
				if not canBuy then
					return
				end
				pendingUpgradeId = upgradeId
				rebuildShop()
				if not sendRequest("BuyUpgrade", upgradeId) then
					pendingUpgradeId = nil
					rebuildShop()
					return
				end
				task.delay(3, function()
					if pendingUpgradeId == upgradeId then
						pendingUpgradeId = nil
						if shopOpen then
							rebuildShop()
						end
					end
				end)
			end)
		end
	end
	if shown == 0 then
		local empty = label(upgradeList, "Empty", "No upgrades are available in this category.", UDim2.new(1, -16, 0, 80), UDim2.fromOffset(8, 8), Enum.Font.GothamBold, 13, COLORS.muted, Enum.TextXAlignment.Center)
		empty.LayoutOrder = 1
		empty.ZIndex = 103
	end
	shopAllowance.Text = money(allowance)
	shopFooter.Text = loaded
		and "Purchases only work while you are standing at the Garage Upgrade Console."
		or "Waiting for the Family allowance and advanced profile to finish syncing…"
end

local function setShopOpen(open)
	shopOpen = open == true
	shopScrim.Visible = shopOpen
	if shopOpen then
		selectCategory(currentCategory)
		shop.Size = UDim2.fromOffset(math.max(280, shop.AbsoluteSize.X), math.max(400, shop.AbsoluteSize.Y))
		shop.BackgroundTransparency = 1
		TweenService:Create(shop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0,
		}):Play()
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = categoryButtons[currentCategory] or shopClose
		end
	else
		pendingUpgradeId = nil
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(shop) then
			GuiService.SelectedObject = nil
		end
	end
end

shopClose.Activated:Connect(function()
	setShopOpen(false)
end)

-- Finale, time-travel, and future presentation ------------------------------

local finaleCard = Instance.new("Frame")
finaleCard.Name = "FinaleObjective"
finaleCard.AnchorPoint = Vector2.new(0.5, 0)
finaleCard.Position = UDim2.new(0.5, 0, 0, 102)
finaleCard.Size = UDim2.fromOffset(680, 126)
finaleCard.BackgroundColor3 = COLORS.panel
finaleCard.BackgroundTransparency = 0.02
finaleCard.BorderSizePixel = 0
finaleCard.Visible = false
finaleCard.ZIndex = 70
finaleCard.Parent = gui
corner(finaleCard, 13)
local finaleStroke = stroke(finaleCard, COLORS.red, 3, 0.05)
local finaleTitle = label(finaleCard, "Title", "FINAL LAUNCH", UDim2.new(1, -130, 0, 28), UDim2.fromOffset(15, 10), Enum.Font.GothamBlack, 18, COLORS.red)
finaleTitle.ZIndex = 71
local finaleTimer = label(finaleCard, "Timer", "--", UDim2.fromOffset(100, 35), UDim2.new(1, -115, 0, 7), Enum.Font.GothamBlack, 23, COLORS.yellow, Enum.TextXAlignment.Right)
finaleTimer.ZIndex = 71
local finaleObjective = label(finaleCard, "Objective", "", UDim2.new(1, -30, 0, 45), UDim2.fromOffset(15, 43), Enum.Font.GothamMedium, 13, COLORS.cream, Enum.TextXAlignment.Center)
finaleObjective.ZIndex = 71
local finaleSwitch = label(finaleCard, "Switch", "", UDim2.new(1, -30, 0, 22), UDim2.fromOffset(15, 92), Enum.Font.GothamBlack, 12, COLORS.cyan, Enum.TextXAlignment.Center)
finaleSwitch.ZIndex = 71

local futureChip = Instance.new("Frame")
futureChip.Name = "FutureChip"
futureChip.AnchorPoint = Vector2.new(0.5, 0)
futureChip.Position = UDim2.new(0.5, 0, 0, 102)
futureChip.Size = UDim2.fromOffset(430, 54)
futureChip.BackgroundColor3 = COLORS.panel
futureChip.BorderSizePixel = 0
futureChip.Visible = false
futureChip.ZIndex = 60
futureChip.Parent = gui
corner(futureChip, 12)
stroke(futureChip, COLORS.cyan, 2, 0.12)
local futureChipLabel = label(futureChip, "Text", "THE FUTURE • USE THE PORTAL TO RETURN TO THE GARAGE", UDim2.new(1, -24, 1, -12), UDim2.fromOffset(12, 6), Enum.Font.GothamBlack, 11, COLORS.cyan, Enum.TextXAlignment.Center)
futureChipLabel.ZIndex = 61

local transition = Instance.new("Frame")
transition.Name = "TemporalTransition"
transition.Size = UDim2.fromScale(1, 1)
transition.BackgroundColor3 = Color3.fromRGB(2, 10, 18)
transition.BackgroundTransparency = 1
transition.BorderSizePixel = 0
transition.Visible = false
transition.ZIndex = 200
transition.Parent = gui
local transitionRing = label(transition, "Ring", "◉", UDim2.fromOffset(260, 260), UDim2.new(0.5, -130, 0.5, -155), Enum.Font.GothamBlack, 180, COLORS.cyan, Enum.TextXAlignment.Center)
transitionRing.ZIndex = 201
transitionRing.TextTransparency = 1
local transitionTitle = label(transition, "Title", "TEMPORAL JUMP", UDim2.new(1, -40, 0, 48), UDim2.new(0, 20, 0.5, 80), Enum.Font.GothamBlack, 27, COLORS.white, Enum.TextXAlignment.Center)
transitionTitle.ZIndex = 201
transitionTitle.TextTransparency = 1
local transitionSub = label(transition, "Subtitle", "LOCKING ONTO THE FUTURE…", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0.5, 125), Enum.Font.GothamBold, 12, COLORS.cyan, Enum.TextXAlignment.Center)
transitionSub.ZIndex = 201
transitionSub.TextTransparency = 1
local transitionToken = 0

local victoryScrim = Instance.new("Frame")
victoryScrim.Name = "VictoryScrim"
victoryScrim.Size = UDim2.fromScale(1, 1)
victoryScrim.BackgroundColor3 = Color3.new(0, 0, 0)
victoryScrim.BackgroundTransparency = 0.28
victoryScrim.BorderSizePixel = 0
victoryScrim.Visible = false
victoryScrim.Active = true
victoryScrim.ZIndex = 170
victoryScrim.Parent = gui
local victoryCard = Instance.new("Frame")
victoryCard.AnchorPoint = Vector2.new(0.5, 0.5)
victoryCard.Position = UDim2.fromScale(0.5, 0.5)
victoryCard.Size = UDim2.fromOffset(620, 310)
victoryCard.BackgroundColor3 = COLORS.panel
victoryCard.BorderSizePixel = 0
victoryCard.ZIndex = 171
victoryCard.Parent = victoryScrim
corner(victoryCard, 18)
stroke(victoryCard, COLORS.cyan, 3, 0)
local victoryKicker = label(victoryCard, "Kicker", "TIME MACHINE COMPLETE", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 28), Enum.Font.GothamBold, 13, COLORS.yellow, Enum.TextXAlignment.Center)
victoryKicker.ZIndex = 172
local victoryTitle = label(victoryCard, "Title", "WELCOME TO THE FUTURE", UDim2.new(1, -40, 0, 56), UDim2.fromOffset(20, 64), Enum.Font.GothamBlack, 29, COLORS.cyan, Enum.TextXAlignment.Center)
victoryTitle.ZIndex = 172
local victoryBody = label(victoryCard, "Body", "You finished the Cooper Time Machine and reached the apartment. Explore, then use the temporal portal whenever you want to return to the garage.", UDim2.new(1, -70, 0, 92), UDim2.fromOffset(35, 128), Enum.Font.GothamMedium, 15, COLORS.cream, Enum.TextXAlignment.Center)
victoryBody.ZIndex = 172
local victoryClose = button(victoryCard, "Continue", "EXPLORE THE FUTURE", UDim2.fromOffset(240, 48), UDim2.new(0.5, -120, 1, -70), COLORS.cyan)
victoryClose.TextColor3 = COLORS.ink
victoryClose.ZIndex = 173

local function showVictory(titleText, bodyText)
	setShopOpen(false)
	victoryTitle.Text = cleanText(titleText, "WELCOME TO THE FUTURE", 80)
	victoryBody.Text = cleanText(bodyText, "The Time Machine worked. Explore the apartment, then use the portal to return to the garage.", 300)
	victoryScrim.Visible = true
	futureChip.Visible = true
	victoryCard.BackgroundTransparency = 1
	TweenService:Create(victoryCard, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0,
	}):Play()
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = victoryClose
	end
end

victoryClose.Activated:Connect(function()
	victoryScrim.Visible = false
	if GuiService.SelectedObject == victoryClose then
		GuiService.SelectedObject = nil
	end
end)

local function playTemporalTransition(duration)
	transitionToken += 1
	local token = transitionToken
	duration = finite(duration, 7, 1, 15)
	transition.Visible = true
	transition.BackgroundTransparency = 1
	transitionRing.TextTransparency = 1
	transitionTitle.TextTransparency = 1
	transitionSub.TextTransparency = 1
	transitionRing.Rotation = 0
	TweenService:Create(transition, TweenInfo.new(math.min(1.2, duration * 0.25)), { BackgroundTransparency = 0.06 }):Play()
	TweenService:Create(transitionRing, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Rotation = 720, TextTransparency = 0.05 }):Play()
	TweenService:Create(transitionTitle, TweenInfo.new(0.45), { TextTransparency = 0 }):Play()
	TweenService:Create(transitionSub, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	task.delay(math.max(0.8, duration - 0.7), function()
		if token ~= transitionToken or not transition.Parent then
			return
		end
		local fade = TweenService:Create(transition, TweenInfo.new(0.65), { BackgroundTransparency = 1 })
		TweenService:Create(transitionRing, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(transitionTitle, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(transitionSub, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		fade:Play()
		fade.Completed:Wait()
		if token == transitionToken and transition.Parent then
			transition.Visible = false
		end
	end)
end

-- Rendering -----------------------------------------------------------------

local function setMeter(record, value, maximum)
	local ratio = percent(value, maximum)
	record.fill.Size = UDim2.fromScale(ratio, 1)
	record.value.Text = string.format("%d", integer(value, 0, 0, 1_000_000))
end

local function renderStatus()
	local snapshot = currentSnapshot or {}
	local stageCount = math.max(1, #Config.MachineStages)
	local stage = integer(snapshot.machineStage, 0, 0, stageCount)
	local progress = finite(snapshot.machineProgress, 0, 0, 100)
	local chapter = integer(snapshot.chapter, 0, 0, 999)
	local chapterName = cleanText(snapshot.chapterName, "The Blueprint", 64)
	local nextStage = type(snapshot.nextStage) == "table" and snapshot.nextStage or nil
	local reactor = type(snapshot.reactor) == "table" and snapshot.reactor or {}
	local calibration = type(snapshot.calibration) == "table" and snapshot.calibration or {}
	local finale = type(snapshot.finale) == "table" and snapshot.finale or {}

	statusTitle.Text = snapshot.victory == true and "TIME MACHINE • COMPLETE" or "TIME MACHINE"
	statusTitle.TextColor3 = snapshot.victory == true and COLORS.cyan or COLORS.blue
	statusStroke.Color = snapshot.victory == true and COLORS.cyan or (finale.running == true and COLORS.red or COLORS.blue)
	chapterLabel.Text = string.format("CHAPTER %d • %s", chapter, string.upper(chapterName))
	machineLabel.Text = string.format("STAGE %d / %d • %d%%", stage, stageCount, integer(progress, 0, 0, 100))
	machineFill.Size = UDim2.fromScale(progress / 100, 1)
	if nextStage then
		local name = cleanText(nextStage.name, "Unknown component", 60)
		local cost = money(nextStage.cost or nextStage.allowance)
		if nextStage.ready == false then
			nextStageLabel.Text = "NEXT: " .. string.upper(name) .. " • " .. cost .. NL .. "LOCKED: " .. cleanText(nextStage.blockedReason, "Complete its prerequisite first.", 100)
			nextStageLabel.TextColor3 = COLORS.orange
		else
			nextStageLabel.Text = "NEXT: " .. string.upper(name) .. " • " .. cost .. NL .. "Order components from Sheldon's computer."
			nextStageLabel.TextColor3 = COLORS.muted
		end
	else
		nextStageLabel.Text = stage >= stageCount and ("ALL COMPONENTS INSTALLED" .. NL .. "Finish calibration and prepare for launch.") or "NEXT COMPONENT: SYNCING…"
		nextStageLabel.TextColor3 = stage >= stageCount and COLORS.green or COLORS.muted
	end
	local persistence = cleanText(snapshot.persistenceStatus, "Unknown", 30)
	persistenceLabel.Text = snapshot.profileLoaded == true
		and "ADVANCED PROFILE: " .. string.upper(persistence)
		or "ADVANCED PROFILE: SYNCING"
	persistenceLabel.TextColor3 = snapshot.profileLoaded == true and COLORS.green or COLORS.yellow

	local reactorVisible = stage >= 7 or reactor.commissioned == true or finale.running == true
	reactorSection.Visible = reactorVisible and not statusCollapsed
	statusExpandedHeight = reactorVisible and 360 or statusBaseHeight
	status.Size = statusCollapsed and UDim2.fromOffset(status.AbsoluteSize.X > 0 and status.AbsoluteSize.X or 310, 44)
		or UDim2.fromOffset(status.AbsoluteSize.X > 0 and status.AbsoluteSize.X or 310, statusExpandedHeight)
	chapterLabel.Visible = not statusCollapsed
	machineLabel.Visible = not statusCollapsed
	machineTrack.Visible = not statusCollapsed
	nextStageLabel.Visible = not statusCollapsed
	persistenceLabel.Visible = not statusCollapsed
	catalogButton.Visible = not statusCollapsed
	collapseButton.Text = statusCollapsed and "+" or "–"
	setButtonEnabled(catalogButton, nextStage ~= nil and snapshot.foundationReady == true and finale.running ~= true, COLORS.blue)
	if not reactorVisible then
		return
	end

	local mode = cleanText(reactor.mode, "Safe", 24)
	local running = reactor.running == true
	reactorTitle.Text = "GARAGE REACTOR • " .. string.upper(mode) .. (running and " • RUNNING" or " • IDLE")
	reactorTitle.TextColor3 = running and COLORS.green or COLORS.muted
	setMeter(meterRows.Coolant, reactor.coolant, reactor.coolantCapacity or Config.Reactor.BaseCoolantCapacity)
	setMeter(meterRows.Heat, reactor.heat, Config.Reactor.MaximumHeat)
	setMeter(meterRows.Suspicion, reactor.suspicion, Config.Reactor.MaximumSuspicion)
	if stage == 7 and reactor.commissioned ~= true then
		chargeLabel.Text = string.format("COMMISSION CHARGE %d / %d", integer(reactor.commissionCharge, 0, 0, Config.Reactor.CommissionCharge), Config.Reactor.CommissionCharge)
	elseif stage >= 8 then
		chargeLabel.Text = string.format("CHRONO-CORE CHARGE %d%%", integer(reactor.chronoCoreCharge, 0, 0, Config.Reactor.MaximumCharge))
	else
		chargeLabel.Text = "REACTOR COMMISSIONED"
	end
	if stage >= stageCount then
		local expected = cleanText(calibration.expected, "Complete", 24)
		calibrationLabel.Text = expected == "Complete" and "CALIBRATION: COMPLETE" or "NEXT CALIBRATION: " .. string.upper(expected)
		calibrationLabel.TextColor3 = expected == "Complete" and COLORS.green or COLORS.yellow
	else
		calibrationLabel.Text = "FINAL CALIBRATION UNLOCKS AT STAGE " .. tostring(stageCount)
		calibrationLabel.TextColor3 = COLORS.muted
	end

	modeButton.Text = "MODE" .. NL .. string.upper(mode)
	toggleButton.Text = running and "STOP" or "START"
	refillButton.Text = "REFILL" .. NL .. money(Config.Reactor.CoolantRefillCash)
	launchButton.Text = "LAUNCH"
	local finaleRunning = finale.running == true
	local cooldown = finite(reactor.cooldownUntil, 0, 0, 9e12) > Workspace:GetServerTimeNow()
	local reactorHasTarget = (stage == 7 and reactor.commissioned ~= true)
		or (stage >= 8 and finite(reactor.chronoCoreCharge, 0, 0, Config.Reactor.MaximumCharge) < Config.Reactor.MaximumCharge)
	local calibrationComplete = cleanText(calibration.expected, "", 24) == "Complete"
	setButtonEnabled(modeButton, not running and not finaleRunning and stage >= 7, COLORS.orange)
	setButtonEnabled(toggleButton, not finaleRunning and not cooldown and stage >= 7 and (running or reactorHasTarget), running and COLORS.red or COLORS.green)
	setButtonEnabled(refillButton, not finaleRunning and stage >= 7 and finite(reactor.coolant, 0, 0, 1e6) < finite(reactor.coolantCapacity, 100, 1, 1e6) - 0.01, COLORS.blue)
	setButtonEnabled(launchButton, not finaleRunning and stage >= stageCount and calibrationComplete and finite(reactor.chronoCoreCharge, 0, 0, Config.Reactor.MaximumCharge) >= Config.Reactor.MaximumCharge, COLORS.yellow)
end

local function renderFinale()
	local snapshot = currentSnapshot or {}
	local finale = type(snapshot.finale) == "table" and snapshot.finale or {}
	local running = finale.running == true
	finaleCard.Visible = running
	if running then
		finaleTitle.Text = string.upper(cleanText(finale.phaseTitle, finale.phase or "FINAL LAUNCH", 80))
		finaleObjective.Text = cleanText(finale.objective, "Protect the Time Machine.", 240)
		local expected = cleanText(finale.expectedSwitch, "", 30)
		finaleSwitch.Text = expected ~= "" and "NEXT OVERLOAD SWITCH: " .. string.upper(expected) or ""
		finaleStroke.Color = finale.phase == "Departure" and COLORS.cyan or COLORS.red
		finaleTitle.TextColor3 = finale.phase == "Departure" and COLORS.cyan or COLORS.red
		setShopOpen(false)
	end
	futureChip.Visible = snapshot.victory == true and not victoryScrim.Visible
end

local function applySnapshot(payload)
	if type(payload) ~= "table" then
		return
	end
	local revision = integer(payload.revision, lastRevision + 1, -1, 2_000_000_000)
	if revision < lastRevision then
		return
	end
	lastRevision = revision
	currentSnapshot = payload
	pendingUpgradeId = nil
	renderStatus()
	renderFinale()
	if shopOpen then
		rebuildShop()
	end
end

-- Remote feedback -----------------------------------------------------------

local FEEDBACK_STYLE = {
	Error = { "REQUEST DENIED", COLORS.red, 4.2 },
	UpgradePurchased = { "UPGRADE INSTALLED", COLORS.purple, 4 },
	UseComputerShop = { "ORDER FROM SHELDON'S COMPUTER", COLORS.blue, 4.5 },
	ReactorMode = { "REACTOR MODE CHANGED", COLORS.orange, 3 },
	Reactor = { "REACTOR STATUS", COLORS.green, 3.5 },
	ReactorLocked = { "REACTOR SAFETY LOCK", COLORS.orange, 4 },
	CoolantRefilled = { "COOLANT REFILLED", COLORS.blue, 3.5 },
	ReactorAccident = { "REACTOR SCRAM", COLORS.red, 5 },
	EmergencyFuse = { "EMERGENCY FUSE SAVED THE CORE", COLORS.yellow, 4.5 },
	DESAlert = { "D.E.S. ALERT", COLORS.red, 5 },
	CalibrationReset = { "CALIBRATION RESET", COLORS.orange, 4 },
	CalibrationStep = { "CALIBRATION ACCEPTED", COLORS.cyan, 3.5 },
	FinalCalibrationComplete = { "FINAL CALIBRATION COMPLETE", COLORS.yellow, 5 },
	ReactorCommissioned = { "GARAGE REACTOR COMMISSIONED", COLORS.green, 5 },
	ChronoCoreCharged = { "CHRONO-CORE CHARGED", COLORS.purple, 5 },
	FinaleFailed = { "LAUNCH ABORTED", COLORS.red, 5 },
	OverloadSwitch = { "OVERLOAD SWITCH LOCKED", COLORS.cyan, 3.5 },
	Victory = { "TIME MACHINE COMPLETE", COLORS.cyan, 6 },
}

local function feedbackBody(kind, payload)
	if type(payload.text) == "string" and payload.text ~= "" then
		return payload.text
	elseif kind == "UpgradePurchased" then
		return string.format("%s is now level %d.", cleanText(payload.name, "Upgrade", 70), integer(payload.level, 1, 1, 99))
	elseif kind == "ReactorMode" then
		return "Reactor governor set to " .. cleanText(payload.mode, "Safe", 20) .. "."
	elseif kind == "CoolantRefilled" then
		return string.format("Coolant restored to %d.", integer(payload.coolant, 0, 0, 10000))
	elseif kind == "ReactorLocked" then
		return cleanText(payload.reason, "The reactor is locked for external safety control.", 180)
	elseif kind == "CalibrationStep" then
		return string.format("%s locked %s (%d/%d).", cleanText(payload.playerName, "A player", 40), cleanText(payload.control, "control", 30), integer(payload.step, 0, 0, 20), integer(payload.total, 0, 0, 20))
	elseif kind == "OverloadSwitch" then
		return string.format("%s stabilized %s (%d/%d).", cleanText(payload.playerName, "A player", 40), cleanText(payload.control, "control", 30), integer(payload.step, 0, 0, 20), integer(payload.total, 0, 0, 20))
	end
	return cleanText(kind, "PROGRESSION UPDATED", 100)
end

local function onFeedback(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local kind = payload.kind
	if kind == "OpenShop" then
		setShopOpen(true)
		return
	end
	if kind == "UpgradePurchased" or kind == "Error" then
		pendingUpgradeId = nil
		if shopOpen then
			rebuildShop()
		end
	end
	local style = FEEDBACK_STYLE[kind] or { string.upper(kind), COLORS.blue, 3.5 }
	showToast(style[1], feedbackBody(kind, payload), style[2], style[3])
	if kind == "Victory" then
		showVictory("WELCOME TO THE FUTURE", payload.text)
	end
end

local function onFinale(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local kind = payload.kind
	if kind == "Start" then
		setShopOpen(false)
		showToast("FINAL LAUNCH STARTED", cleanText(payload.startedBy, "A player", 50) .. " armed the Time Machine.", COLORS.red, 4)
	elseif kind == "Phase" then
		finaleCard.Visible = true
		finaleTitle.Text = string.upper(cleanText(payload.title, payload.phase or "FINAL LAUNCH", 80))
		finaleObjective.Text = cleanText(payload.objective, "Protect the Time Machine.", 240)
		finaleStroke.Color = payload.phase == "Departure" and COLORS.cyan or COLORS.red
		finaleTitle.TextColor3 = payload.phase == "Departure" and COLORS.cyan or COLORS.red
		finaleTimer:SetAttribute("RemoteDeadline", finite(payload.deadline, 0, 0, 9e12))
	elseif kind == "TimeTravel" then
		playTemporalTransition(payload.duration)
	elseif kind == "Failed" then
		finaleCard.Visible = false
		showToast("LAUNCH ABORTED", cleanText(payload.text, "The Time Machine shut down safely.", 240), COLORS.red, 5)
	elseif kind == "Victory" then
		finaleCard.Visible = false
		showVictory(cleanText(payload.title, "WELCOME TO THE FUTURE", 80), payload.text)
	end
	-- Finale cues are intentionally followed by a fresh authoritative snapshot.
	task.delay(0.1, function()
		sendRequest("RequestSnapshot")
	end)
end

snapshotEvent.OnClientEvent:Connect(function(payload)
	local ok, message = pcall(applySnapshot, payload)
	if not ok then
		warn("[CooperProgressionClient] Snapshot render failed: " .. tostring(message))
	end
end)

feedbackEvent.OnClientEvent:Connect(function(payload)
	local ok, message = pcall(onFeedback, payload)
	if not ok then
		warn("[CooperProgressionClient] Feedback render failed: " .. tostring(message))
	end
end)

finaleEvent.OnClientEvent:Connect(function(payload)
	local ok, message = pcall(onFinale, payload)
	if not ok then
		warn("[CooperProgressionClient] Finale render failed: " .. tostring(message))
	end
end)

-- Input and responsive layout ----------------------------------------------

collapseButton.Activated:Connect(function()
	statusCollapsed = not statusCollapsed
	renderStatus()
end)

modeButton.Activated:Connect(function()
	sendRequest("CycleReactorMode")
end)
catalogButton.Activated:Connect(function()
	sendRequest("BuyNextStage")
end)
toggleButton.Activated:Connect(function()
	sendRequest("ToggleReactor")
end)
refillButton.Activated:Connect(function()
	sendRequest("RefillCoolant")
end)
launchButton.Activated:Connect(function()
	sendRequest("BeginFinale")
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if shopOpen then
			setShopOpen(false)
		elseif victoryScrim.Visible then
			victoryScrim.Visible = false
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(victoryScrim) then
				GuiService.SelectedObject = nil
			end
		end
	elseif processed then
		return
	end
end)

local cameraConnection = nil
local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = math.max(280, viewport.X)
	local height = math.max(360, viewport.Y)
	shop.Size = UDim2.fromOffset(math.clamp(width - 32, 280, 940), math.clamp(height - 58, 400, 630))
	victoryCard.Size = UDim2.fromOffset(math.clamp(width - 34, 286, 620), math.clamp(height * 0.46, 280, 330))
	finaleCard.Size = UDim2.fromOffset(math.clamp(width - 34, 286, 680), 126)
	toast.Size = UDim2.fromOffset(math.clamp(width - 34, 286, 560), 70)
	futureChip.Size = UDim2.fromOffset(math.clamp(width - 34, 286, 430), 54)
	local statusWidth = math.clamp(width - 24, 276, 310)
	status.Size = UDim2.fromOffset(statusWidth, statusCollapsed and 44 or statusExpandedHeight)
	if width < 700 then
		status.Position = UDim2.new(1, -8, 1, -8)
		status.BackgroundTransparency = 0.08
	else
		status.Position = UDim2.new(1, -16, 1, -16)
		status.BackgroundTransparency = 0.045
	end
	if shopOpen then
		rebuildShop()
	end
end

local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
	updateResponsiveLayout()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

local lastClockUpdate = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastClockUpdate < 0.1 then
		return
	end
	lastClockUpdate = now
	if finaleCard.Visible then
		local finale = currentSnapshot and type(currentSnapshot.finale) == "table" and currentSnapshot.finale or nil
		local deadline = finale and finite(finale.deadline, 0, 0, 9e12) or finite(finaleTimer:GetAttribute("RemoteDeadline"), 0, 0, 9e12)
		local remaining = math.max(0, deadline - Workspace:GetServerTimeNow())
		finaleTimer.Text = deadline > 0 and string.format("%02d:%02d", math.floor(remaining / 60), math.floor(remaining % 60)) or "--"
		finaleTimer.TextColor3 = remaining > 10 and COLORS.yellow or COLORS.red
	end
end)

selectCategory("All")
updateResponsiveLayout()
renderStatus()
sendRequest("RequestSnapshot")
task.delay(2, function()
	if not currentSnapshot then
		sendRequest("RequestSnapshot")
	end
end)

print("[CooperProgressionClient] Responsive upgrades, reactor, finale, and future HUD ready")
