--!strict
-- Accessible, mobile-safe invited-party lobby UI.
-- Install as StarterPlayer.StarterPlayerScripts.CooperLobby in the lobby place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local lobbyFolder = ReplicatedStorage:WaitForChild("CooperLobby")
local Config = require(lobbyFolder:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("CooperPartyLobby")
local requestRemote = remotes:WaitForChild("Request") :: RemoteFunction
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local clientCommandRemote = remotes:WaitForChild("ClientCommand") :: RemoteEvent

local COLORS = {
	Backdrop = Color3.fromRGB(8, 13, 18),
	Panel = Color3.fromRGB(17, 29, 35),
	PanelRaised = Color3.fromRGB(24, 42, 49),
	Outline = Color3.fromRGB(87, 155, 160),
	Text = Color3.fromRGB(245, 247, 238),
	Muted = Color3.fromRGB(182, 202, 199),
	Accent = Color3.fromRGB(255, 190, 68),
	AccentText = Color3.fromRGB(35, 24, 7),
	Good = Color3.fromRGB(104, 224, 151),
	Bad = Color3.fromRGB(255, 128, 116),
	Disabled = Color3.fromRGB(73, 87, 91),
}

local gui = Instance.new("ScreenGui")
gui.Name = "CooperLobbyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ClipToDeviceSafeArea = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = COLORS.Backdrop
backdrop.BackgroundTransparency = 0.14
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local backdropGradient = Instance.new("UIGradient")
backdropGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 19, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 30, 30)),
})
backdropGradient.Rotation = 25
backdropGradient.Parent = backdrop

local panel = Instance.new("Frame")
panel.Name = "PartyPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.9, 0)
panel.BackgroundColor3 = COLORS.Panel
panel.BorderSizePixel = 0
panel.Parent = backdrop

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(280, 280)
panelConstraint.MaxSize = Vector2.new(720, 760)
panelConstraint.Parent = panel

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 20)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.Outline
panelStroke.Transparency = 0.28
panelStroke.Thickness = 2
panelStroke.Parent = panel

local safePadding = Instance.new("UIPadding")
safePadding.PaddingTop = UDim.new(0, 22)
safePadding.PaddingBottom = UDim.new(0, 18)
safePadding.PaddingLeft = UDim.new(0, 22)
safePadding.PaddingRight = UDim.new(0, 22)
safePadding.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 42)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "COOPER HOUSE"
title.TextColor3 = COLORS.Text
title.TextSize = 30
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.new(0, 0, 0, 43)
subtitle.Size = UDim2.new(1, 0, 0, 46)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Play alone or invite up to three friends. Your party gets a private house."
subtitle.TextColor3 = COLORS.Muted
subtitle.TextSize = 16
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.Parent = panel

local notice = Instance.new("TextLabel")
notice.Name = "Notice"
notice.Position = UDim2.new(0, 0, 0, 96)
notice.Size = UDim2.new(1, 0, 0, 42)
notice.BackgroundColor3 = COLORS.PanelRaised
notice.BackgroundTransparency = 0.05
notice.BorderSizePixel = 0
notice.Font = Enum.Font.GothamMedium
notice.Text = "Loading your party..."
notice.TextColor3 = COLORS.Muted
notice.TextSize = 15
notice.TextWrapped = true
notice.Parent = panel

local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 10)
noticeCorner.Parent = notice

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.new(0, 0, 0, 150)
content.Size = UDim2.new(1, 0, 1, -150)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarThickness = 5
content.ScrollBarImageColor3 = COLORS.Outline
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 10)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local memberHeading = Instance.new("TextLabel")
memberHeading.Name = "MemberHeading"
memberHeading.LayoutOrder = 1
memberHeading.Size = UDim2.new(1, -6, 0, 30)
memberHeading.BackgroundTransparency = 1
memberHeading.Font = Enum.Font.GothamBold
memberHeading.Text = "PARTY"
memberHeading.TextColor3 = COLORS.Text
memberHeading.TextSize = 18
memberHeading.TextXAlignment = Enum.TextXAlignment.Left
memberHeading.Visible = false
memberHeading.Parent = content

local memberList = Instance.new("Frame")
memberList.Name = "MemberList"
memberList.LayoutOrder = 2
memberList.Size = UDim2.new(1, -6, 0, 0)
memberList.AutomaticSize = Enum.AutomaticSize.Y
memberList.BackgroundTransparency = 1
memberList.Visible = false
memberList.Parent = content

local memberLayout = Instance.new("UIListLayout")
memberLayout.Padding = UDim.new(0, 7)
memberLayout.SortOrder = Enum.SortOrder.LayoutOrder
memberLayout.Parent = memberList

local actionHeading = Instance.new("TextLabel")
actionHeading.Name = "ActionHeading"
actionHeading.LayoutOrder = 3
actionHeading.Size = UDim2.new(1, -6, 0, 30)
actionHeading.BackgroundTransparency = 1
actionHeading.Font = Enum.Font.GothamBold
actionHeading.Text = "CHOOSE HOW TO PLAY"
actionHeading.TextColor3 = COLORS.Text
actionHeading.TextSize = 18
actionHeading.TextXAlignment = Enum.TextXAlignment.Left
actionHeading.Parent = content

local actions = Instance.new("Frame")
actions.Name = "Actions"
actions.LayoutOrder = 4
actions.Size = UDim2.new(1, -6, 0, 0)
actions.AutomaticSize = Enum.AutomaticSize.Y
actions.BackgroundTransparency = 1
actions.Parent = content

local actionLayout = Instance.new("UIListLayout")
actionLayout.Padding = UDim.new(0, 9)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actions

local buttons: { [string]: TextButton } = {}

local function makeButton(name: string, text: string, order: number, primary: boolean): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 56)
	button.AutoButtonColor = false
	button.BackgroundColor3 = if primary then COLORS.Accent else COLORS.PanelRaised
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = if primary then COLORS.AccentText else COLORS.Text
	button.TextSize = 18
	button.TextWrapped = true
	button.Parent = actions

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = if primary then COLORS.Accent else COLORS.Outline
	stroke.Transparency = if primary then 0.1 else 0.45
	stroke.Parent = button

	button.MouseEnter:Connect(function()
		if button.Active then
			button.BackgroundTransparency = 0.12
		end
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 0
	end)
	buttons[name] = button
	return button
end

local soloButton = makeButton("PlaySolo", "PLAY SOLO", 1, true)
local createButton = makeButton("CreateParty", "CREATE A PRIVATE PARTY", 2, false)
local rejoinButton = makeButton("Rejoin", "REJOIN HOUSE SESSION", 3, true)
local inviteButton = makeButton("InviteFriends", "INVITE FRIENDS", 4, false)
local readyButton = makeButton("Ready", "I'M READY", 5, false)
local launchButton = makeButton("Launch", "START PRIVATE HOUSE", 6, true)
local leaveButton = makeButton("LeaveParty", "LEAVE PARTY", 7, false)

local studioNote = Instance.new("TextLabel")
studioNote.Name = "StudioNote"
studioNote.LayoutOrder = 5
studioNote.Size = UDim2.new(1, -6, 0, 48)
studioNote.BackgroundTransparency = 1
studioNote.Font = Enum.Font.Gotham
studioNote.Text = "Studio preview checks party rules but never teleports or grants house authority."
studioNote.TextColor3 = COLORS.Muted
studioNote.TextSize = 14
studioNote.TextWrapped = true
studioNote.Visible = false
studioNote.Parent = content

local currentState: any = nil
local busy = false
local stateGeneration = 0
local noticeHoldUntil = 0

local function setButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.Selectable = enabled
	button.TextTransparency = if enabled then 0 else 0.45
	button.BackgroundColor3 = if enabled
		then (if button == soloButton or button == launchButton or button == rejoinButton then COLORS.Accent else COLORS.PanelRaised)
		else COLORS.Disabled
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
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = COLORS.PanelRaised
	row.BorderSizePixel = 0
	row.Parent = memberList
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 14, 0, 0)
	nameLabel.Size = UDim2.new(0.62, -14, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.Text = tostring(member.displayName) .. (if member.isHost then "  • HOST" else "")
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 16
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local statusLabel = Instance.new("TextLabel")
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -14, 0, 0)
	statusLabel.Size = UDim2.new(0.38, 0, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = if not member.present then "JOINING..." elseif member.ready then "READY ✓" else "NOT READY"
	statusLabel.TextColor3 = if member.ready then COLORS.Good else COLORS.Muted
	statusLabel.TextSize = 14
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Parent = row
end

local function render(state: any)
	if type(state) ~= "table" then
		return
	end
	currentState = state
	studioNote.Visible = state.studioPreview == true
	if os.clock() >= noticeHoldUntil then
		local message = state.notice
		if type(message) == "string" and message ~= "" then
			notice.Text = message
		elseif state.hasParty then
			notice.Text = "Ready up together, then the host can start."
		else
			notice.Text = "Choose solo play or make a private party."
		end
	end

	local hasParty = state.hasParty == true

	clearMemberRows()
	memberHeading.Visible = hasParty
	memberList.Visible = hasParty
	actionHeading.Text = if hasParty then "PARTY CONTROLS" else "CHOOSE HOW TO PLAY"
	if hasParty and type(state.members) == "table" then
		for index, member in ipairs(state.members) do
			addMemberRow(member, index)
		end
	end

	soloButton.Visible = not hasParty
	createButton.Visible = not hasParty
	rejoinButton.Visible = state.canRejoin == true and (not hasParty or state.state ~= "Open")
	inviteButton.Visible = hasParty and state.isHost == true and state.state == "Open"
	readyButton.Visible = hasParty and state.state == "Open"
	launchButton.Visible = hasParty and state.isHost == true and state.state == "Open"
	leaveButton.Visible = hasParty and state.state == "Open"

	local selfReady = false
	if hasParty and type(state.members) == "table" then
		for _, member in ipairs(state.members) do
			if member.userId == player.UserId then
				selfReady = member.ready == true
				break
			end
		end
	end
	readyButton.Text = if selfReady then "READY ✓  (TAP TO CANCEL)" else "I'M READY"
	setButtonEnabled(readyButton, not busy and state.state == "Open")
	setButtonEnabled(inviteButton, not busy and state.canInvite == true)
	setButtonEnabled(launchButton, not busy and state.canLaunch == true)
	setButtonEnabled(leaveButton, not busy)
	setButtonEnabled(soloButton, not busy)
	setButtonEnabled(createButton, not busy)
	setButtonEnabled(rejoinButton, not busy)

end

local function request(action: string, payload: any?, quiet: boolean?)
	if busy then
		return
	end
	-- Every request, including background refreshes, owns a generation. A later
	-- refresh or server push therefore invalidates any slower reply instead of
	-- allowing out-of-order polling responses to repaint stale membership.
	stateGeneration += 1
	local requestGeneration = stateGeneration
	if not quiet then
		busy = true
		noticeHoldUntil = 0
		if currentState then
			render(currentState)
		end
		notice.Text = "Working..."
	end

	local ok, response = pcall(function()
		return requestRemote:InvokeServer(action, payload)
	end)
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
		render(response.state)
		-- Render first, then apply the direct response. Previously render replaced
		-- every success/error message with the generic party hint, which made a
		-- rejected action look as if the button did nothing.
		if not quiet then
			local responseMessage = type(response.message) == "string" and response.message or ""
			if responseMessage ~= "" then
				notice.Text = responseMessage
				notice.TextColor3 = if response.ok == true then COLORS.Good else COLORS.Bad
				noticeHoldUntil = os.clock() + 4
			else
				notice.TextColor3 = COLORS.Muted
			end
		else
			notice.TextColor3 = COLORS.Muted
		end
	elseif not quiet then
		if currentState then
			render(currentState)
		end
		notice.Text = "The lobby could not respond. Please try again."
		notice.TextColor3 = COLORS.Bad
		noticeHoldUntil = os.clock() + 4
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
	local selfReady = string.find(readyButton.Text, "CANCEL", 1, true) ~= nil
	request("SetReady", not selfReady)
end)
launchButton.Activated:Connect(function()
	request("Launch")
end)
leaveButton.Activated:Connect(function()
	request("LeaveParty")
end)

stateRemote.OnClientEvent:Connect(function(state)
	-- Server pushes are authoritative and may overtake an in-flight refresh or
	-- button request. Advancing the generation prevents its older reply from
	-- painting stale party membership back over this state.
	stateGeneration += 1
	notice.TextColor3 = COLORS.Muted
	render(state)
	if type(state) == "table" and type(state.notice) == "string" and state.notice ~= "" then
		notice.Text = state.notice
		notice.TextColor3 = COLORS.Good
		noticeHoldUntil = os.clock() + 4
	end
end)

clientCommandRemote.OnClientEvent:Connect(function(command: unknown, launchData: unknown)
	if command ~= "PromptInvite" or type(launchData) ~= "string" or #launchData > 200 then
		return
	end
	local canPromptOk, canPrompt = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not canPromptOk or not canPrompt then
		notice.Text = "Friend invitations are not available on this device right now."
		notice.TextColor3 = COLORS.Bad
		noticeHoldUntil = os.clock() + 4
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
		notice.TextColor3 = COLORS.Bad
		noticeHoldUntil = os.clock() + 4
	end
end)

task.spawn(function()
	while gui.Parent do
		request("Refresh", nil, true)
		task.wait(Config.StatePollSeconds)
	end
end)
