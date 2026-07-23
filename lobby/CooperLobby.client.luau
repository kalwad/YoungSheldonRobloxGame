--!strict
-- Accessible, mobile-safe invited-party lobby UI.
-- Install as StarterPlayer.StarterPlayerScripts.CooperLobby in the lobby place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local lobbyFolder = ReplicatedStorage:WaitForChild("CooperLobby")
local Config = require(lobbyFolder:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("CooperPartyLobby")
local requestRemote = remotes:WaitForChild("Request") :: RemoteFunction
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local clientCommandRemote = remotes:WaitForChild("ClientCommand") :: RemoteEvent

local function createLegacyThemeFallback()
	-- Compatibility only: an older lobby place may receive this LocalScript
	-- before ReplicatedStorage.CooperUITheme is synchronized. A present but
	-- invalid module must fail loudly instead of being hidden by this fallback.
	return table.freeze({
		VERSION = 1,
		ID = "Cooper1980sRecRoom.v1",
		Colors = table.freeze({
			Scrim = Color3.fromRGB(25, 18, 13),
			ScrimGradientWarm = Color3.fromRGB(42, 29, 18),
			ScrimGradientCool = Color3.fromRGB(15, 20, 16),
			Shadow = Color3.fromRGB(0, 0, 0),
			Cabinet = Color3.fromRGB(104, 55, 31),
			CabinetDark = Color3.fromRGB(61, 35, 25),
			CabinetGradientLight = Color3.fromRGB(129, 72, 39),
			CabinetGradientDeep = Color3.fromRGB(76, 43, 29),
			Screen = Color3.fromRGB(27, 37, 30),
			ScreenRaised = Color3.fromRGB(42, 54, 40),
			ScreenSoft = Color3.fromRGB(53, 62, 45),
			ScreenGradientLight = Color3.fromRGB(35, 48, 38),
			ScreenGradientDark = Color3.fromRGB(20, 28, 24),
			Outline = Color3.fromRGB(181, 153, 91),
			Cream = Color3.fromRGB(255, 244, 207),
			Muted = Color3.fromRGB(220, 213, 181),
			Mustard = Color3.fromRGB(238, 179, 54),
			MustardText = Color3.fromRGB(48, 31, 10),
			Avocado = Color3.fromRGB(174, 207, 90),
			Teal = Color3.fromRGB(133, 208, 197),
			TealText = Color3.fromRGB(16, 35, 31),
			Rust = Color3.fromRGB(255, 151, 112),
			Disabled = Color3.fromRGB(75, 76, 62),
		}),
		Fonts = table.freeze({
			Body = Enum.Font.Gotham,
			Medium = Enum.Font.GothamMedium,
			Strong = Enum.Font.GothamBold,
			Mono = Enum.Font.RobotoMono,
		}),
		Metrics = table.freeze({
			SpacingUnit = 8,
			MinimumTouchTarget = 56,
			ActionHeight = 60,
		}),
		Accessibility = table.freeze({
			BodyTextContrastMinimum = 4.5,
			LargeTextContrastMinimum = 3,
			ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
			ClipToDeviceSafeArea = true,
		}),
	})
end

local function loadCooperUITheme()
	local themeModule = ReplicatedStorage:FindFirstChild("CooperUITheme")
	if themeModule == nil then
		warn("[CooperLobby] ReplicatedStorage.CooperUITheme is missing; using embedded v1 compatibility palette for this stale place")
		return createLegacyThemeFallback()
	end
	assert(themeModule:IsA("ModuleScript"), "ReplicatedStorage.CooperUITheme must be a ModuleScript")
	local theme = require(themeModule)
	assert(type(theme) == "table" and theme.VERSION == 1, "CooperUITheme v1 is required")
	assert(type(theme.Colors) == "table", "CooperUITheme.Colors is missing")
	assert(type(theme.Fonts) == "table", "CooperUITheme.Fonts is missing")
	assert(type(theme.Metrics) == "table", "CooperUITheme.Metrics is missing")
	assert(type(theme.Accessibility) == "table", "CooperUITheme.Accessibility is missing")
	return theme
end

-- The approved late-1980s rec-room palette now comes from the versioned
-- cross-place theme. The alias keeps the presentation code compact.
local UITheme = loadCooperUITheme()
local THEME = UITheme.Colors

local gui = Instance.new("ScreenGui")
gui.Name = "CooperLobbyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = UITheme.Accessibility.ScreenInsets
gui.ClipToDeviceSafeArea = UITheme.Accessibility.ClipToDeviceSafeArea
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
gui.Parent = playerGui

-- A directional translucent scrim keeps the physical rec room visible. On a
-- phone the panel necessarily fills most of the viewport, but it never relies
-- on a completely opaque full-screen background.
local backdrop = Instance.new("Frame")
backdrop.Name = "ReadableScrim"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = THEME.Scrim
backdrop.BackgroundTransparency = 0.44
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local backdropGradient = Instance.new("UIGradient")
backdropGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.ScrimGradientWarm),
	ColorSequenceKeypoint.new(1, THEME.ScrimGradientCool),
})
backdropGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.74),
	NumberSequenceKeypoint.new(0.55, 0.54),
	NumberSequenceKeypoint.new(1, 0.18),
})
backdropGradient.Rotation = 0
backdropGradient.Parent = backdrop

local shadow = Instance.new("Frame")
shadow.Name = "CabinetShadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.BackgroundColor3 = THEME.Shadow
shadow.BackgroundTransparency = 0.46
shadow.BorderSizePixel = 0
shadow.ZIndex = 1
shadow.Parent = backdrop
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 22)
shadowCorner.Parent = shadow

local panel = Instance.new("Frame")
panel.Name = "CRTCabinet"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = THEME.Cabinet
panel.BorderSizePixel = 0
panel.ZIndex = 2
panel.Parent = backdrop

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 22)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = THEME.CabinetDark
panelStroke.Thickness = 3
panelStroke.Parent = panel

local cabinetGradient = Instance.new("UIGradient")
cabinetGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.CabinetGradientLight),
	ColorSequenceKeypoint.new(0.48, THEME.Cabinet),
	ColorSequenceKeypoint.new(1, THEME.CabinetGradientDeep),
})
cabinetGradient.Rotation = 22
cabinetGradient.Parent = panel

local screen = Instance.new("Frame")
screen.Name = "CRTScreen"
screen.Position = UDim2.fromOffset(10, 10)
screen.Size = UDim2.new(1, -20, 1, -20)
screen.BackgroundColor3 = THEME.Screen
screen.BorderSizePixel = 0
screen.ClipsDescendants = true
screen.ZIndex = 3
screen.Parent = panel

local screenCorner = Instance.new("UICorner")
screenCorner.CornerRadius = UDim.new(0, 16)
screenCorner.Parent = screen

local screenStroke = Instance.new("UIStroke")
screenStroke.Color = THEME.Outline
screenStroke.Transparency = 0.22
screenStroke.Thickness = 2
screenStroke.Parent = screen

local screenGradient = Instance.new("UIGradient")
screenGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.ScreenGradientLight),
	ColorSequenceKeypoint.new(1, THEME.ScreenGradientDark),
})
screenGradient.Rotation = 75
screenGradient.Parent = screen

local safePadding = Instance.new("UIPadding")
safePadding.PaddingTop = UDim.new(0, 20)
safePadding.PaddingBottom = UDim.new(0, 18)
safePadding.PaddingLeft = UDim.new(0, 22)
safePadding.PaddingRight = UDim.new(0, 22)
safePadding.Parent = screen

local eyebrow = Instance.new("TextLabel")
eyebrow.Name = "Eyebrow"
eyebrow.Size = UDim2.new(0.63, 0, 0, 20)
eyebrow.BackgroundTransparency = 1
eyebrow.Font = UITheme.Fonts.Mono
eyebrow.Text = "CHANNEL 86  •  MEDFORD, TEXAS"
eyebrow.TextColor3 = THEME.Mustard
eyebrow.TextSize = 13
eyebrow.TextXAlignment = Enum.TextXAlignment.Left
eyebrow.ZIndex = 4
eyebrow.Parent = screen

local modeBadge = Instance.new("TextLabel")
modeBadge.Name = "ModeBadge"
modeBadge.AnchorPoint = Vector2.new(1, 0)
modeBadge.Position = UDim2.new(1, 0, 0, 0)
modeBadge.Size = UDim2.new(0.35, 0, 0, 24)
modeBadge.BackgroundColor3 = THEME.ScreenRaised
modeBadge.BorderSizePixel = 0
modeBadge.Font = UITheme.Fonts.Strong
modeBadge.Text = "PRIVATE LOBBY"
modeBadge.TextColor3 = THEME.Cream
modeBadge.TextSize = 12
modeBadge.TextTruncate = Enum.TextTruncate.AtEnd
modeBadge.ZIndex = 4
modeBadge.Parent = screen
local modeCorner = Instance.new("UICorner")
modeCorner.CornerRadius = UDim.new(0, 7)
modeCorner.Parent = modeBadge

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(0, 25)
title.Size = UDim2.new(1, 0, 0, 39)
title.BackgroundTransparency = 1
title.Font = UITheme.Fonts.Strong
title.Text = "COOPER HOUSE"
title.TextColor3 = THEME.Cream
title.TextSize = 29
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 4
title.Parent = screen

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.fromOffset(0, 65)
subtitle.Size = UDim2.new(1, 0, 0, 42)
subtitle.BackgroundTransparency = 1
subtitle.Font = UITheme.Fonts.Body
subtitle.Text = "Play alone or invite up to three friends to your private Cooper house."
subtitle.TextColor3 = THEME.Muted
subtitle.TextSize = 15
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.ZIndex = 4
subtitle.Parent = screen

local notice = Instance.new("TextLabel")
notice.Name = "Notice"
notice.Position = UDim2.fromOffset(0, 112)
notice.Size = UDim2.new(1, 0, 0, 48)
notice.BackgroundColor3 = THEME.ScreenRaised
notice.BorderSizePixel = 0
notice.Font = UITheme.Fonts.Medium
notice.Text = "Loading your party..."
notice.TextColor3 = THEME.Muted
notice.TextSize = 15
notice.TextWrapped = true
notice.ZIndex = 4
notice.Parent = screen

local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 9)
noticeCorner.Parent = notice
local noticeStroke = Instance.new("UIStroke")
noticeStroke.Color = THEME.Outline
noticeStroke.Transparency = 0.62
noticeStroke.Parent = notice
local noticePadding = Instance.new("UIPadding")
noticePadding.PaddingLeft = UDim.new(0, 12)
noticePadding.PaddingRight = UDim.new(0, 12)
noticePadding.Parent = notice

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(0, 172)
content.Size = UDim2.new(1, 0, 1, -172)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarThickness = 6
content.ScrollBarImageColor3 = THEME.Mustard
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
content.ZIndex = 4
content.Parent = screen

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 10)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local studioBanner = Instance.new("TextLabel")
studioBanner.Name = "StudioBanner"
studioBanner.LayoutOrder = 0
studioBanner.Size = UDim2.new(1, -8, 0, 48)
studioBanner.BackgroundColor3 = THEME.Teal
studioBanner.BorderSizePixel = 0
studioBanner.Font = UITheme.Fonts.Strong
studioBanner.Text = "STUDIO PARTY TEST  •  IN-PLACE HOUSE PREVIEW"
studioBanner.TextColor3 = THEME.TealText
studioBanner.TextSize = 14
studioBanner.TextWrapped = true
studioBanner.Visible = false
studioBanner.ZIndex = 5
studioBanner.Parent = content
local studioCorner = Instance.new("UICorner")
studioCorner.CornerRadius = UDim.new(0, 9)
studioCorner.Parent = studioBanner

local memberHeading = Instance.new("TextLabel")
memberHeading.Name = "MemberHeading"
memberHeading.LayoutOrder = 10
memberHeading.Size = UDim2.new(1, -8, 0, 28)
memberHeading.BackgroundTransparency = 1
memberHeading.Font = UITheme.Fonts.Strong
memberHeading.Text = "WHO'S PLAYING"
memberHeading.TextColor3 = THEME.Cream
memberHeading.TextSize = 17
memberHeading.TextXAlignment = Enum.TextXAlignment.Left
memberHeading.Visible = false
memberHeading.ZIndex = 4
memberHeading.Parent = content

local memberList = Instance.new("Frame")
memberList.Name = "MemberList"
memberList.LayoutOrder = 20
memberList.Size = UDim2.new(1, -8, 0, 0)
memberList.AutomaticSize = Enum.AutomaticSize.Y
memberList.BackgroundTransparency = 1
memberList.Visible = false
memberList.ZIndex = 4
memberList.Parent = content

local memberLayout = Instance.new("UIListLayout")
memberLayout.Padding = UDim.new(0, 7)
memberLayout.SortOrder = Enum.SortOrder.LayoutOrder
memberLayout.Parent = memberList

local actionHeading = Instance.new("TextLabel")
actionHeading.Name = "ActionHeading"
actionHeading.LayoutOrder = 30
actionHeading.Size = UDim2.new(1, -8, 0, 28)
actionHeading.BackgroundTransparency = 1
actionHeading.Font = UITheme.Fonts.Strong
actionHeading.Text = "CHOOSE HOW TO PLAY"
actionHeading.TextColor3 = THEME.Cream
actionHeading.TextSize = 17
actionHeading.TextXAlignment = Enum.TextXAlignment.Left
actionHeading.ZIndex = 4
actionHeading.Parent = content

local actions = Instance.new("Frame")
actions.Name = "Actions"
actions.LayoutOrder = 40
actions.Size = UDim2.new(1, -8, 0, 0)
actions.AutomaticSize = Enum.AutomaticSize.Y
actions.BackgroundTransparency = 1
actions.ZIndex = 4
actions.Parent = content

local actionLayout = Instance.new("UIListLayout")
actionLayout.Padding = UDim.new(0, 9)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actions

local buttons: { [string]: TextButton } = {}
local buttonOrder: { TextButton } = {}

local function makeButton(name: string, text: string, order: number, primary: boolean): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.SelectionOrder = order
	button.Size = UDim2.new(1, 0, 0, UITheme.Metrics.ActionHeight)
	button.AutoButtonColor = false
	button.BackgroundColor3 = if primary then THEME.Mustard else THEME.ScreenRaised
	button.BorderSizePixel = 0
	button.Font = UITheme.Fonts.Strong
	button.Text = text
	button.TextColor3 = if primary then THEME.MustardText else THEME.Cream
	button.TextSize = 17
	button.TextWrapped = true
	button.ZIndex = 5
	button:SetAttribute("Primary", primary)
	button.Parent = actions

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Name = "FocusStroke"
	stroke.Color = if primary then THEME.Mustard else THEME.Outline
	stroke.Transparency = if primary then 0.08 else 0.38
	stroke.Thickness = 2
	stroke.Parent = button

	local accent = Instance.new("Frame")
	accent.Name = "PeriodAccent"
	accent.Position = UDim2.fromOffset(8, 8)
	accent.Size = UDim2.new(0, 5, 1, -16)
	accent.BackgroundColor3 = if primary then THEME.Rust else THEME.Avocado
	accent.BorderSizePixel = 0
	accent.ZIndex = 6
	accent.Parent = button
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(1, 0)
	accentCorner.Parent = accent

	local function setFocus(focused: boolean)
		if not button.Active then
			return
		end
		button.BackgroundTransparency = if focused then 0.08 else 0
		stroke.Transparency = if focused then 0 else (if primary then 0.08 else 0.38)
		stroke.Thickness = if focused then 3 else 2
	end
	button.MouseEnter:Connect(function()
		setFocus(true)
	end)
	button.MouseLeave:Connect(function()
		setFocus(false)
	end)
	button.SelectionGained:Connect(function()
		setFocus(true)
	end)
	button.SelectionLost:Connect(function()
		setFocus(false)
	end)

	buttons[name] = button
	table.insert(buttonOrder, button)
	return button
end

local soloButton = makeButton("PlaySolo", "PLAY SOLO", 10, true)
local createButton = makeButton("CreateParty", "CREATE A PRIVATE PARTY", 20, false)
local rejoinButton = makeButton("Rejoin", "REJOIN HOUSE SESSION", 30, true)
local inviteButton = makeButton("InviteFriends", "INVITE FRIENDS", 40, false)
local readyButton = makeButton("Ready", "I'M READY", 50, false)
local launchButton = makeButton("Launch", "START PRIVATE HOUSE", 60, true)

local launchStatus = Instance.new("TextLabel")
launchStatus.Name = "LaunchStatus"
launchStatus.LayoutOrder = 65
launchStatus.Size = UDim2.new(1, 0, 0, 46)
launchStatus.BackgroundColor3 = THEME.ScreenSoft
launchStatus.BorderSizePixel = 0
launchStatus.Font = UITheme.Fonts.Medium
launchStatus.Text = "Waiting for party information."
launchStatus.TextColor3 = THEME.Muted
launchStatus.TextSize = 14
launchStatus.TextWrapped = true
launchStatus.Visible = false
launchStatus.ZIndex = 5
launchStatus.Parent = actions
local launchStatusCorner = Instance.new("UICorner")
launchStatusCorner.CornerRadius = UDim.new(0, 8)
launchStatusCorner.Parent = launchStatus
local launchStatusPadding = Instance.new("UIPadding")
launchStatusPadding.PaddingLeft = UDim.new(0, 10)
launchStatusPadding.PaddingRight = UDim.new(0, 10)
launchStatusPadding.Parent = launchStatus

local leaveButton = makeButton("LeaveParty", "LEAVE PARTY", 70, false)

local studioNote = Instance.new("TextLabel")
studioNote.Name = "StudioNote"
studioNote.LayoutOrder = 50
studioNote.Size = UDim2.new(1, -8, 0, 54)
studioNote.BackgroundTransparency = 1
studioNote.Font = UITheme.Fonts.Body
studioNote.Text = "Studio opens the verified Cooper House inside this playtest. Published builds still use a secure reserved-house teleport."
studioNote.TextColor3 = THEME.Muted
studioNote.TextSize = 14
studioNote.TextWrapped = true
studioNote.Visible = false
studioNote.ZIndex = 4
studioNote.Parent = content

local currentState: any = nil
local authoritativeSelfReady = false
local currentPartyRevision = -1
local currentPartyId: string? = nil
local busy = false
local stateGeneration = 0
local noticeHoldUntil = 0
local studioValidationPassed = false
local validatedPartyId: string? = nil
local validatedPartyRevision: number? = nil
local studioHouseActive = false

local function setButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.Selectable = enabled
	button.TextTransparency = if enabled then 0 else 0.34
	local primary = button:GetAttribute("Primary") == true
	button.TextColor3 = if not enabled
		then THEME.Muted
		else (if primary then THEME.MustardText else THEME.Cream)
	button.BackgroundColor3 = if enabled
		then (if primary then THEME.Mustard else THEME.ScreenRaised)
		else THEME.Disabled
	local accent = button:FindFirstChild("PeriodAccent")
	if accent and accent:IsA("Frame") then
		accent.BackgroundTransparency = if enabled then 0 else 0.55
	end
end

local function clearMemberRows()
	for _, child in ipairs(memberList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function addMemberRow(member: any, order: number)
	local row = Instance.new("Frame")
	row.Name = "Member_" .. tostring(member.userId)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 58)
	row.BackgroundColor3 = THEME.ScreenRaised
	row.BorderSizePixel = 0
	row.ZIndex = 5
	row.Parent = memberList
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = row

	local marker = Instance.new("Frame")
	marker.Name = "StatusMarker"
	marker.Position = UDim2.fromOffset(10, 12)
	marker.Size = UDim2.fromOffset(7, 34)
	marker.BackgroundColor3 = if member.ready then THEME.Avocado else THEME.Rust
	marker.BorderSizePixel = 0
	marker.ZIndex = 6
	marker.Parent = row
	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(1, 0)
	markerCorner.Parent = marker

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 27, 0, 0)
	nameLabel.Size = UDim2.new(0.61, -27, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = UITheme.Fonts.Medium
	nameLabel.Text = tostring(member.displayName) .. (if member.isHost then "  • HOST" else "")
	nameLabel.TextColor3 = THEME.Cream
	nameLabel.TextSize = 16
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 6
	nameLabel.Parent = row

	local statusLabel = Instance.new("TextLabel")
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -12, 0, 0)
	statusLabel.Size = UDim2.new(0.39, 0, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = UITheme.Fonts.Strong
	statusLabel.Text = if not member.present then "JOINING…" elseif member.ready then "READY  ✓" else "NOT READY"
	statusLabel.TextColor3 = if member.ready then THEME.Avocado else THEME.Muted
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.ZIndex = 6
	statusLabel.Parent = row
end

local function launchReason(state: any): (string, Color3)
	if busy then
		return "Please wait while the last party action finishes.", THEME.Muted
	end
	if state.canLaunch ~= true
		and type(state.launchBlockMessage) == "string"
		and state.launchBlockMessage ~= ""
	then
		return "START LOCKED — " .. state.launchBlockMessage, THEME.Rust
	end
	if state.allPresent ~= true then
		return "START LOCKED — waiting for every party member to arrive in this lobby.", THEME.Rust
	end
	if state.allReady ~= true then
		local waiting: { string } = {}
		if type(state.members) == "table" then
			for _, member in ipairs(state.members) do
				if member.ready ~= true then
					table.insert(waiting, tostring(member.displayName))
				end
			end
		end
		local names = if #waiting > 0 then table.concat(waiting, ", ") else "one or more players"
		return "START LOCKED — waiting for " .. names .. " to press Ready.", THEME.Rust
	end
	if state.canLaunch ~= true then
		return "START LOCKED — the party is syncing with the host's lobby. Please wait.", THEME.Rust
	end
	if state.studioPreview == true then
		return "READY TO START — Studio will open a playable in-place Cooper House.", THEME.Teal
	end
	return "EVERYONE IS READY — the host can start the private house.", THEME.Avocado
end

local function updateGamepadLinks()
	local available: { TextButton } = {}
	for _, button in ipairs(buttonOrder) do
		if button.Visible and button.Active then
			table.insert(available, button)
		end
	end
	for index, button in ipairs(available) do
		button.NextSelectionUp = available[math.max(1, index - 1)]
		button.NextSelectionDown = available[math.min(#available, index + 1)]
	end
end

local function render(state: any)
	if type(state) ~= "table" then
		return
	end
	local hasParty = state.hasParty == true
	local incomingPartyId = if type(state.partyId) == "string" then state.partyId else nil
	local incomingRevision = tonumber(state.partyRevision)
	-- Server revisions are authoritative when available. They add a second layer
	-- of protection beyond request generations so an old refresh response cannot
	-- visually undo a newer Ready commit.
	if hasParty
		and incomingPartyId ~= nil
		and incomingPartyId == currentPartyId
		and incomingRevision ~= nil
		and incomingRevision < currentPartyRevision
	then
		return
	end
	if hasParty and incomingPartyId ~= nil then
		currentPartyId = incomingPartyId
		if incomingRevision ~= nil then
			currentPartyRevision = incomingRevision
		end
	else
		currentPartyId = nil
		currentPartyRevision = -1
	end
	currentState = state
	local isStudio = state.studioPreview == true
	studioNote.Visible = isStudio
	studioBanner.Visible = isStudio
	modeBadge.Text = if isStudio then "STUDIO PARTY TEST" else "PRIVATE LOBBY"
	modeBadge.BackgroundColor3 = if isStudio then THEME.Teal else THEME.ScreenRaised
	modeBadge.TextColor3 = if isStudio then THEME.TealText else THEME.Cream

	authoritativeSelfReady = state.selfReady == true
	clearMemberRows()
	memberHeading.Visible = hasParty
	memberList.Visible = hasParty
	actionHeading.Text = if hasParty then "PARTY CONTROLS" else "CHOOSE HOW TO PLAY"
	if hasParty and type(state.members) == "table" then
		for index, member in ipairs(state.members) do
			addMemberRow(member, index)
			-- Compatibility fallback for an older lobby server that does not yet
			-- expose the explicit top-level selfReady field.
			if member.userId == player.UserId and type(state.selfReady) ~= "boolean" then
				authoritativeSelfReady = member.ready == true
			end
		end
	end
	if not hasParty
		or not authoritativeSelfReady
		or state.canLaunch ~= true
		or validatedPartyId ~= state.partyId
		or (validatedPartyRevision ~= nil
			and incomingRevision ~= nil
			and validatedPartyRevision ~= incomingRevision)
	then
		studioValidationPassed = false
		validatedPartyId = nil
		validatedPartyRevision = nil
	end

	if os.clock() >= noticeHoldUntil then
		local message = state.notice
		if type(message) == "string" and message ~= "" then
			notice.Text = message
		elseif hasParty then
			notice.Text = "Ready up together. When everyone is here, the host can start."
		else
			notice.Text = "Choose solo play or make a private party."
		end
		notice.TextColor3 = THEME.Muted
	end

	soloButton.Visible = not hasParty
	createButton.Visible = not hasParty
	rejoinButton.Visible = state.canRejoin == true and (not hasParty or state.state ~= "Open")
	inviteButton.Visible = hasParty and state.isHost == true and state.state == "Open"
	readyButton.Visible = hasParty and state.state == "Open"
	launchButton.Visible = hasParty and state.isHost == true and state.state == "Open"
	launchStatus.Visible = launchButton.Visible
	leaveButton.Visible = hasParty and state.state == "Open"

	readyButton.Text = if authoritativeSelfReady then "READY  ✓   (PRESS TO CANCEL)" else "I'M READY"
	launchButton.Text = if isStudio then "START COOPER HOUSE" else "START PRIVATE HOUSE"
	local reason, reasonColor = launchReason(state)
	launchStatus.Text = reason
	launchStatus.TextColor3 = reasonColor

	setButtonEnabled(readyButton, not busy and state.state == "Open")
	setButtonEnabled(inviteButton, not busy and state.canInvite == true)
	setButtonEnabled(launchButton, not busy and state.canLaunch == true)
	setButtonEnabled(leaveButton, not busy)
	setButtonEnabled(soloButton, not busy)
	setButtonEnabled(createButton, not busy)
	setButtonEnabled(rejoinButton, not busy)
	updateGamepadLinks()
end

local function request(action: string, payload: any?, quiet: boolean?)
	if busy or studioHouseActive then
		return
	end
	stateGeneration += 1
	local requestGeneration = stateGeneration
	if not quiet then
		busy = true
		noticeHoldUntil = 0
		if currentState then
			render(currentState)
		end
		notice.Text = if action == "Launch" then "Checking the party and starting…" else "Working…"
		notice.TextColor3 = THEME.Mustard
	end

	local ok, response = pcall(function()
		return requestRemote:InvokeServer(action, payload)
	end)
	if studioHouseActive then
		busy = false
		return
	end
	if requestGeneration ~= stateGeneration then
		if not quiet then
			busy = false
			if currentState then
				render(currentState)
			end
		end
		return
	end
	if not quiet then
		busy = false
	end
	if ok and type(response) == "table" then
		local responseState = response.state
		if action == "Launch"
			and response.ok == true
			and type(responseState) == "table"
			and responseState.studioPreview == true
		then
			studioValidationPassed = true
			validatedPartyId = responseState.partyId
			validatedPartyRevision = tonumber(responseState.partyRevision)
		end
		render(responseState)
		if not quiet then
			local responseMessage = type(response.message) == "string" and response.message or ""
			if responseMessage ~= "" then
				notice.Text = responseMessage
				notice.TextColor3 = if response.ok == true then THEME.Avocado else THEME.Rust
				noticeHoldUntil = os.clock() + 5
			else
				notice.TextColor3 = THEME.Muted
			end
		else
			notice.TextColor3 = THEME.Muted
		end
	elseif not quiet then
		if currentState then
			render(currentState)
		end
		notice.Text = "The lobby could not respond. Please try again."
		notice.TextColor3 = THEME.Rust
		noticeHoldUntil = os.clock() + 5
	end
end

soloButton.Activated:Connect(function()
	request("PlaySolo")
end)
createButton.Activated:Connect(function()
	request("CreateParty")
end)
rejoinButton.Activated:Connect(function()
	request("Rejoin")
end)
inviteButton.Activated:Connect(function()
	request("InviteFriends")
end)
readyButton.Activated:Connect(function()
	-- Never infer readiness from presentation text. This value comes only from
	-- the latest server-authored member record rendered above.
	request("SetReady", not authoritativeSelfReady)
end)
launchButton.Activated:Connect(function()
	request("Launch")
end)
leaveButton.Activated:Connect(function()
	request("LeaveParty")
end)

stateRemote.OnClientEvent:Connect(function(state)
	if studioHouseActive then
		return
	end
	stateGeneration += 1
	if type(state) == "table"
		and state.studioPreview == true
		and type(state.notice) == "string"
		and string.find(state.notice, "Studio party validation passed", 1, true)
	then
		studioValidationPassed = true
		validatedPartyId = state.partyId
		validatedPartyRevision = tonumber(state.partyRevision)
	end
	notice.TextColor3 = THEME.Muted
	render(state)
	if type(state) == "table" and type(state.notice) == "string" and state.notice ~= "" then
		notice.Text = state.notice
		notice.TextColor3 = THEME.Avocado
		noticeHoldUntil = os.clock() + 5
	end
end)

local function restoreHouseControlsAndCamera()
	local controlsOk, controls = pcall(function()
		return require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
	end)
	if controlsOk and controls then
		pcall(function()
			controls:Enable()
		end)
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function installStudioHousePlayerScripts(folderName: string): (boolean, string?)
	local templates = ReplicatedStorage:WaitForChild(folderName, 10)
	if not templates or not templates:IsA("Folder") then
		return false, "The verified Studio house player scripts did not arrive."
	end
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	if not playerScripts or not playerScripts:IsA("PlayerScripts") then
		return false, "Your Roblox PlayerScripts container was unavailable."
	end
	for _, template in ipairs(templates:GetChildren()) do
		if template:IsA("LocalScript") and not playerScripts:FindFirstChild(template.Name) then
			local clone = template:Clone()
			clone.Enabled = false
			clone.Parent = playerScripts
			clone.Enabled = true
		end
	end
	return true, nil
end

clientCommandRemote.OnClientEvent:Connect(function(command: unknown, launchData: unknown)
	if command == "StudioHouseTransitionBegin" then
		busy = true
		noticeHoldUntil = math.huge
		notice.Text = if type(launchData) == "table" and type(launchData.text) == "string"
			then launchData.text
			else "Opening the Cooper House…"
		notice.TextColor3 = THEME.Mustard
		if currentState then
			render(currentState)
		end
		return
	elseif command == "StudioHouseTransitionFailed" then
		busy = false
		noticeHoldUntil = os.clock() + 10
		if currentState then
			render(currentState)
		end
		notice.Text = if type(launchData) == "table" and type(launchData.text) == "string"
			then launchData.text
			else "The Studio Cooper House could not open. Check Output and try again."
		notice.TextColor3 = THEME.Rust
		return
	elseif command == "StudioHouseTransitionComplete" then
		local folderName = if type(launchData) == "table" and type(launchData.playerScriptsFolder) == "string"
			then launchData.playerScriptsFolder
			else "CooperStudioPlayerScripts"
		local installed, installError = installStudioHousePlayerScripts(folderName)
		if not installed then
			busy = false
			noticeHoldUntil = math.huge
			notice.Text = installError or "The Studio house player scripts could not start."
			notice.TextColor3 = THEME.Rust
			warn("[CooperLobby] Studio house client activation failed: " .. notice.Text)
			return
		end
		studioHouseActive = true
		busy = false
		stateGeneration += 1
		restoreHouseControlsAndCamera()
		gui:Destroy()
		return
	end
	if command ~= "PromptInvite" or type(launchData) ~= "string" or #launchData > 200 then
		return
	end
	local canPromptOk, canPrompt = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not canPromptOk or not canPrompt then
		notice.Text = "Friend invitations are not available on this device right now."
		notice.TextColor3 = THEME.Rust
		noticeHoldUntil = os.clock() + 5
		return
	end

	local options = Instance.new("ExperienceInviteOptions")
	options.PromptMessage = "Invite friends to your private Cooper House party!"
	options.LaunchData = launchData
	local promptOk = pcall(function()
		SocialService:PromptGameInvite(player, options)
	end)
	if not promptOk then
		notice.Text = "Roblox could not open the friend list. Please try again."
		notice.TextColor3 = THEME.Rust
		noticeHoldUntil = os.clock() + 5
	end
end)

local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- Backdrop.AbsoluteSize reflects CoreUISafeInsets, unlike Camera.ViewportSize.
	-- Use the camera only during the first frame before the safe-area root sizes.
	local viewport = backdrop.AbsoluteSize
	if viewport.X <= 1 or viewport.Y <= 1 then
		viewport = camera.ViewportSize
	end
	local compact = viewport.X < 620 or viewport.Y < 560
	local portrait = viewport.Y > viewport.X
	local shortLandscape = viewport.Y < 420 and not portrait
	local panelWidth: number
	local panelHeight: number
	local position: UDim2
	if compact or portrait then
		panelWidth = math.min(viewport.X, 620, math.max(250, viewport.X - 18))
		panelHeight = math.min(viewport.Y, 760, math.max(if shortLandscape then 240 else 300, viewport.Y - 18))
		position = UDim2.fromScale(0.5, 0.5)
	else
		panelWidth = math.min(570, math.floor(viewport.X * 0.49))
		panelHeight = math.min(760, viewport.Y - 42)
		position = UDim2.new(1, -24 - panelWidth * 0.5, 0.5, 0)
	end
	panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
	panel.Position = position
	shadow.Size = UDim2.fromOffset(panelWidth + 8, panelHeight + 8)
	shadow.Position = position + UDim2.fromOffset(6, 8)

	local padding = if viewport.X < 420 then 13 else 22
	safePadding.PaddingTop = UDim.new(0, if shortLandscape then 9 elseif compact then 14 else 20)
	safePadding.PaddingBottom = UDim.new(0, if shortLandscape then 8 elseif compact then 12 else 18)
	safePadding.PaddingLeft = UDim.new(0, padding)
	safePadding.PaddingRight = UDim.new(0, padding)
	eyebrow.Visible = not shortLandscape
	subtitle.Visible = not shortLandscape
	if shortLandscape then
		title.Position = UDim2.fromOffset(0, 0)
		title.Size = UDim2.new(0.62, 0, 0, 32)
		notice.Position = UDim2.fromOffset(0, 38)
		notice.Size = UDim2.new(1, 0, 0, 44)
		content.Position = UDim2.fromOffset(0, 92)
		content.Size = UDim2.new(1, 0, 1, -92)
	else
		title.Position = UDim2.fromOffset(0, 25)
		title.Size = UDim2.new(1, 0, 0, 39)
		notice.Position = UDim2.fromOffset(0, 112)
		notice.Size = UDim2.new(1, 0, 0, 48)
		content.Position = UDim2.fromOffset(0, 172)
		content.Size = UDim2.new(1, 0, 1, -172)
	end
	title.TextSize = if shortLandscape or viewport.X < 380 then 24 else 29
	subtitle.TextSize = if viewport.X < 380 then 14 else 15
	eyebrow.TextSize = if viewport.X < 380 then 11 else 13
	eyebrow.Text = if viewport.X < 380 then "CHANNEL 86  •  MEDFORD" else "CHANNEL 86  •  MEDFORD, TEXAS"
	modeBadge.TextSize = if viewport.X < 380 then 10 else 12
end

local cameraConnection: RBXScriptConnection? = nil
local function frameRecRoomCamera(camera: Camera)
	if studioHouseActive then
		return
	end
	-- A menu lobby should present the authored rec-room composition consistently
	-- instead of depending on avatar facing or third-person wall collision.
	local focus = Vector3.new(-5, 7.2, -16)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 68
	camera.CFrame = CFrame.lookAt(Vector3.new(1, 9, 24), focus)
	camera.Focus = CFrame.new(focus)
end

local function watchCamera()
	if studioHouseActive then
		return
	end
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		frameRecRoomCamera(camera)
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
	updateResponsiveLayout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveLayout)
watchCamera()

task.spawn(function()
	while gui.Parent and not studioHouseActive do
		request("Refresh", nil, true)
		task.wait(Config.StatePollSeconds)
	end
end)
