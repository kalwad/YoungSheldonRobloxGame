--!strict
-- Two-stage Cooper family dialogue UI with published Roblox audio playback.
-- Installed as StarterPlayer.StarterPlayerScripts.CooperFamilyDialogue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local dialogueRoot = ReplicatedStorage:WaitForChild("CooperFamilyDialogue", 20)
local sessionRemote = dialogueRoot:WaitForChild("Session", 10) :: RemoteEvent
local audioRoot = ReplicatedStorage:WaitForChild("CooperFamilyLocalAudio", 10)

local dialogue = {
	George = {
		displayName = "GEORGE",
		farewell = {
			response = "Sheldon Lee Cooper, you dog!",
			audio = "GeorgeYouDog",
		},
		stages = {
			{
				{
					choice = "Ask him what makes a good dinner.",
					response = "A good brisket takes patience. You can't rush something that important.",
					audio = "AGoodBrisket",
				},
				{
					choice = "Ask why the kitchen feels so cold.",
					response = "Who left the refrigerator open? Cold air ain't free!",
					audio = "WhoLeftRefrigerator",
				},
				{
					choice = "Tell him you found the remote.",
					response = "Put the remote back where you found it and we won't have a problem.",
					audio = "PutRemoteBack",
				},
			},
			{
				{
					choice = "Mention the strange noise in the garage.",
					response = "If something's making noise in the garage... Tell me after half-time.",
					audio = "IfSomethingMakingNoise",
				},
				{
					choice = "Say Sheldon started another experiment.",
					response = "Finish your chores before starting another science experiment.",
					audio = "FinishYourChores",
				},
				{
					choice = "Promise there won't be any more trouble.",
					response = "Now you see, that's the type of hijinks I'm looking to avoid.",
					audio = "NowYouSee",
				},
			},
		},
	},
	Georgie = {
		displayName = "GEORGIE",
		farewell = {
			response = "Sheldon Lee Cooper, you dawg!",
			audio = "GeorgieYouDog",
		},
		stages = {
			{
				{
					choice = "Ask whether he has a new business idea.",
					response = "If there's money in it, I'm already interested.",
					audio = "IfTheresMoney",
				},
				{
					choice = "Ask if school is really that important.",
					response = "School ain't everything. Knowing how to make a deal matters.",
					audio = "SchooAintEverything",
				},
				{
					choice = "Ask what he can do better than Sheldon.",
					response = "I can fix a tire faster than Sheldon can explain one.",
					audio = "FixATire",
				},
			},
			{
				{
					choice = "Ask how he gets away with everything.",
					response = "If Dad asks, I was in the garage the whole time.",
					audio = "IfDadAsks",
				},
				{
					choice = "Ask him for the secret to getting ahead.",
					response = "A little confidence and a clean truck can take you pretty far.",
					audio = "ALittleConfidence",
				},
				{
					choice = "Ask whether he has everything handled.",
					response = "Don't worry, Mama. I got this—probably.",
					audio = "DontWorryMama",
				},
			},
		},
	},
	Mary = {
		displayName = "MARY",
		farewell = {
			response = "Sheldon Lee Cooper, you dog!",
			audio = "MaryYouDawg",
		},
		stages = {
			{
				{
					choice = "Ask how she keeps her patience.",
					response = "Lord, give me patience, because this family is testing every bit of it.",
					audio = "LordGiveMe",
				},
				{
					choice = "Ask whether chores can wait until later.",
					response = "Nobody leaves this house until their chores are finished.",
					audio = "NobodyLeaves",
				},
				{
					choice = "Tell her Sheldon corrected your manners.",
					response = "Sheldon, being the smartest person in the room does not excuse your manners.",
					audio = "SheldonBeingSmartest",
				},
			},
			{
				{
					choice = "Ask when everybody needs to be at the table.",
					response = "Dinner is at six, and I expect everybody washed and sitting down.",
					audio = "DinnerAtSix",
				},
				{
					choice = "Ask whether she has a favorite child.",
					response = "I love all my children equally, even when some make it difficult.",
					audio = "LoveAllMyChildren",
				},
				{
					choice = "Ask for her best advice.",
					response = "A little faith, a little kindness, and a whole lot of common sense.",
					audio = "ALittleFaith",
				},
			},
		},
	},
	Missy = {
		displayName = "MISSY",
		farewell = {
			response = "Sheldon Lee Cooper, you dog!",
			audio = "MissyYouDog",
		},
		stages = {
			{
				{
					choice = "Ask what happened to the broken thing.",
					response = "I didn't break it. I was just nearby when it stopped working.",
					audio = "Didntbreakit",
				},
				{
					choice = "Ask whether Sheldon can tell when she lies.",
					response = "Sheldon may be a genius, but he still can't tell when I'm lying.",
					audio = "maybegenius",
				},
				{
					choice = "Ask what she tells Mom when questioned.",
					response = "If Mom asks, I've been doing homework this entire time.",
					audio = "DoingHomework",
				},
			},
			{
				{
					choice = "Ask how she feels about being grounded.",
					response = "Being grounded is just staying home with extra attitude.",
					audio = "BeingGrounded",
				},
				{
					choice = "Ask who should take the blame this time.",
					response = "Why solve a problem when you can blame Georgie?",
					audio = "BlameGeorgie",
				},
				{
					choice = "Ask what she really thinks of her brothers.",
					response = "I love my brothers, but sometimes I wish they had an off switch.",
					audio = "OffSwitch",
				},
			},
		},
	},
}

local oldGui = playerGui:FindFirstChild("CooperFamilyDialogueUI")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperFamilyDialogueUI"
gui.DisplayOrder = 95
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.Enabled = false
gui.ClipToDeviceSafeArea = true
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end)
gui.Parent = playerGui

local scrim = Instance.new("TextButton")
scrim.Name = "Scrim"
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = Color3.fromRGB(7, 8, 9)
scrim.BackgroundTransparency = 0.62
scrim.BorderSizePixel = 0
scrim.Text = ""
scrim.AutoButtonColor = false
scrim.Selectable = false
scrim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "DialoguePanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(880, 390)
panel.BackgroundColor3 = Color3.fromRGB(23, 26, 28)
panel.BackgroundTransparency = 0.02
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = scrim
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 18)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(72, 201, 120)
panelStroke.Thickness = 3
panelStroke.Transparency = 0.1
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(28, 18)
title.Size = UDim2.new(1, -112, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "TALK TO GEORGE"
title.TextColor3 = Color3.fromRGB(91, 222, 139)
title.TextSize = 27
title.TextWrapped = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 10)
closeButton.Size = UDim2.fromOffset(48, 48)
closeButton.BackgroundColor3 = Color3.fromRGB(92, 39, 39)
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = true
closeButton.Font = Enum.Font.GothamBlack
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(255, 244, 231)
closeButton.TextSize = 27
closeButton.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeButton
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(225, 105, 91)
closeStroke.Thickness = 1.5
closeStroke.Transparency = 0.18
closeStroke.Parent = closeButton

local responseCard = Instance.new("Frame")
responseCard.Name = "ResponseCard"
responseCard.Position = UDim2.fromOffset(26, 68)
responseCard.Size = UDim2.new(1, -52, 0, 88)
responseCard.BackgroundColor3 = Color3.fromRGB(35, 40, 42)
responseCard.BorderSizePixel = 0
responseCard.Parent = panel
local responseCorner = Instance.new("UICorner")
responseCorner.CornerRadius = UDim.new(0, 12)
responseCorner.Parent = responseCard

local response = Instance.new("TextLabel")
response.Name = "Response"
response.Position = UDim2.fromOffset(18, 12)
response.Size = UDim2.new(1, -36, 1, -24)
response.BackgroundTransparency = 1
response.Font = Enum.Font.GothamBold
response.Text = "Choose what you want to say."
response.TextColor3 = Color3.fromRGB(245, 239, 219)
response.TextSize = 19
response.TextWrapped = true
response.TextXAlignment = Enum.TextXAlignment.Left
response.TextYAlignment = Enum.TextYAlignment.Center
response.Parent = responseCard

local choiceHeader = Instance.new("TextLabel")
choiceHeader.Name = "ChoiceHeader"
choiceHeader.Position = UDim2.fromOffset(28, 166)
choiceHeader.Size = UDim2.new(1, -56, 0, 24)
choiceHeader.BackgroundTransparency = 1
choiceHeader.Font = Enum.Font.GothamBold
choiceHeader.Text = "WHAT DO YOU SAY?"
choiceHeader.TextColor3 = Color3.fromRGB(172, 179, 178)
choiceHeader.TextSize = 13
choiceHeader.TextXAlignment = Enum.TextXAlignment.Left
choiceHeader.Parent = panel

local choices = Instance.new("Frame")
choices.Name = "Choices"
choices.Position = UDim2.fromOffset(26, 198)
choices.Size = UDim2.new(1, -52, 0, 174)
choices.BackgroundTransparency = 1
choices.Parent = panel
local choiceLayout = Instance.new("UIListLayout")
choiceLayout.Padding = UDim.new(0, 9)
choiceLayout.FillDirection = Enum.FillDirection.Vertical
choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
choiceLayout.Parent = choices

local choiceRowHeight = 52
local compactLandscape = false
local cameraViewportConnection: RBXScriptConnection? = nil

local function updateResponsiveLayout()
	local camera = workspace.CurrentCamera
	local fallback = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local absolute = scrim.AbsoluteSize
	local usableWidth = if absolute.X > 1 then absolute.X else fallback.X
	local usableHeight = if absolute.Y > 1 then absolute.Y else fallback.Y
	compactLandscape = usableWidth > usableHeight and usableHeight < 500

	if compactLandscape then
		local panelWidth = math.max(320, math.min(880, usableWidth - 20))
		local panelHeight = math.max(220, math.min(320, usableHeight - 16))
		local leftWidth = math.clamp(math.floor(panelWidth * 0.39), 248, 330)
		local rightX = leftWidth + 10
		local rightWidth = panelWidth - rightX - 14
		local choicesTop = 48
		local choicesHeight = math.max(156, panelHeight - choicesTop - 12)
		local rowGap = 7
		choiceRowHeight = math.max(48, math.min(56, math.floor((choicesHeight - rowGap * 2) / 3)))

		panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
		title.Position = UDim2.fromOffset(18, 10)
		title.Size = UDim2.fromOffset(leftWidth - 84, 42)
		title.TextSize = 21
		closeButton.Position = UDim2.fromOffset(leftWidth - 12, 8)
		responseCard.Position = UDim2.fromOffset(14, 60)
		responseCard.Size = UDim2.fromOffset(leftWidth - 28, panelHeight - 74)
		response.Position = UDim2.fromOffset(13, 8)
		response.Size = UDim2.new(1, -26, 1, -16)
		response.TextSize = 16
		choiceHeader.Position = UDim2.fromOffset(rightX, 14)
		choiceHeader.Size = UDim2.fromOffset(rightWidth, 24)
		choiceHeader.TextSize = 12
		choices.Position = UDim2.fromOffset(rightX, choicesTop)
		choices.Size = UDim2.fromOffset(rightWidth, choicesHeight)
		choiceLayout.Padding = UDim.new(0, rowGap)
	else
		local panelWidth = math.max(300, math.min(880, usableWidth - 24))
		local panelHeight = math.max(390, math.min(410, usableHeight - 24))
		choiceRowHeight = 52

		panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
		title.Position = UDim2.fromOffset(28, 18)
		title.Size = UDim2.new(1, -112, 0, 40)
		title.TextSize = if panelWidth < 480 then 22 else 27
		closeButton.Position = UDim2.new(1, -12, 0, 10)
		responseCard.Position = UDim2.fromOffset(26, 68)
		responseCard.Size = UDim2.new(1, -52, 0, 88)
		response.Position = UDim2.fromOffset(18, 12)
		response.Size = UDim2.new(1, -36, 1, -24)
		response.TextSize = if panelWidth < 480 then 16 else 19
		choiceHeader.Position = UDim2.fromOffset(28, 166)
		choiceHeader.Size = UDim2.new(1, -56, 0, 24)
		choiceHeader.TextSize = 13
		choices.Position = UDim2.fromOffset(26, 198)
		choices.Size = UDim2.new(1, -52, 0, 174)
		choiceLayout.Padding = UDim.new(0, 9)
	end

	for _, child in ipairs(choices:GetChildren()) do
		if child:IsA("TextButton") then
			child.Size = UDim2.new(1, 0, 0, choiceRowHeight)
			child.TextSize = if compactLandscape then 14 else 16
		end
	end
end

local function bindCurrentCamera()
	if cameraViewportConnection then
		cameraViewportConnection:Disconnect()
		cameraViewportConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(updateResponsiveLayout)
		end)
	end
	task.defer(updateResponsiveLayout)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCurrentCamera)
scrim:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(updateResponsiveLayout)
end)
bindCurrentCamera()

local audioContainer = Instance.new("Folder")
audioContainer.Name = "CooperDialogueAudio"
audioContainer.Parent = SoundService
local audioPlayer = Instance.new("AudioPlayer")
audioPlayer.Name = "Voice"
audioPlayer.AutoLoad = true
audioPlayer.Volume = 1
audioPlayer.Parent = audioContainer
local deviceOutput = Instance.new("AudioDeviceOutput")
deviceOutput.Name = "Output"
deviceOutput.Parent = audioContainer
local audioWire = Instance.new("Wire")
audioWire.SourceInstance = audioPlayer
audioWire.TargetInstance = deviceOutput
audioWire.Parent = audioContainer

local activeNPC: Model? = nil
local activeCharacter: string? = nil
local currentStage = 1
local responseSerial = 0
local closing = false
local choiceCallbacks: { [number]: () -> () } = {}
local firstChoice: TextButton? = nil

local function clearDialogueSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(scrim) then
		GuiService.SelectedObject = nil
	end
end

local function focusDialogueDefault()
	if gui.Enabled and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = firstChoice or closeButton
	end
end

local function clearChoices()
	clearDialogueSelection()
	firstChoice = nil
	table.clear(choiceCallbacks)
	for _, child in ipairs(choices:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function closeDialogue(notifyServer: boolean)
	if not gui.Enabled then
		return
	end
	responseSerial += 1
	audioPlayer:Stop()
	gui.Enabled = false
	clearDialogueSelection()
	activeNPC = nil
	activeCharacter = nil
	closing = false
	clearChoices()
	if notifyServer then
		sessionRemote:FireServer("Close")
	end
end

local function makeChoice(text: string, layoutOrder: number, callback: () -> ())
	local choiceButton = Instance.new("TextButton")
	choiceButton.Name = "Choice" .. layoutOrder
	choiceButton.LayoutOrder = layoutOrder
	choiceButton.Size = UDim2.new(1, 0, 0, choiceRowHeight)
	choiceButton.BackgroundColor3 = Color3.fromRGB(45, 51, 52)
	choiceButton.AutoButtonColor = true
	choiceButton.BorderSizePixel = 0
	choiceButton.Font = Enum.Font.GothamBold
	choiceButton.Text = tostring(layoutOrder) .. ".  " .. text
	choiceButton.TextColor3 = Color3.fromRGB(242, 241, 232)
	choiceButton.TextSize = if compactLandscape then 14 else 16
	choiceButton.TextWrapped = true
	choiceButton.TextXAlignment = Enum.TextXAlignment.Left
	choiceButton.Selectable = true
	choiceButton.Parent = choices
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = choiceButton
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 15)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = choiceButton
	choiceCallbacks[layoutOrder] = callback
	if not firstChoice then
		firstChoice = choiceButton
	end
	choiceButton.Activated:Connect(callback)
end

local showStage
local playFarewellAndClose

local function playResponse(entry, stageNumber: number)
	responseSerial += 1
	local serial = responseSerial
	clearChoices()
	focusDialogueDefault()
	local characterData = dialogue[activeCharacter or ""]
	local speakerName = characterData and characterData.displayName or "NPC"
	choiceHeader.Text = speakerName .. " IS RESPONDING..."
	response.Text = speakerName .. ":  “" .. entry.response .. "”"

	local characterFolder = audioRoot:FindFirstChild(activeCharacter or "")
	local audioValue = characterFolder and characterFolder:FindFirstChild(entry.audio)
	if not audioValue or not audioValue:IsA("StringValue") then
		response.Text ..= "  [Audio unavailable]"
		task.delay(2.5, function()
			if serial ~= responseSerial then
				return
			end
			if stageNumber < 2 then
				showStage(stageNumber + 1)
			else
				choiceHeader.Text = "CONVERSATION COMPLETE"
				makeChoice("End conversation", 1, function()
					playFarewellAndClose()
				end)
				focusDialogueDefault()
			end
		end)
		return
	end

	audioPlayer:Stop()
	audioPlayer.Asset = audioValue.Value
	audioPlayer.TimePosition = 0
	task.spawn(function()
		local deadline = os.clock() + 6
		while serial == responseSerial and not audioPlayer.IsReady and os.clock() < deadline do
			task.wait(0.05)
		end
		if serial ~= responseSerial then
			return
		end
		audioPlayer:Play()
		local length = audioPlayer.TimeLength
		if length <= 0 then
			length = 4
		end
		task.wait(math.clamp(length + 0.25, 1.5, 10))
		if serial ~= responseSerial or not gui.Enabled then
			return
		end
		if stageNumber < 2 then
			showStage(stageNumber + 1)
		else
			choiceHeader.Text = "CONVERSATION COMPLETE"
			makeChoice("End conversation", 1, function()
				playFarewellAndClose()
			end)
			focusDialogueDefault()
		end
	end)
end

showStage = function(stageNumber: number)
	currentStage = stageNumber
	clearChoices()
	response.Text = if stageNumber == 1
		then (activeCharacter or "The NPC") .. " looks over. What do you want to ask?"
		else "You have time for one more question."
	choiceHeader.Text = if stageNumber == 1 then "CHOOSE YOUR FIRST RESPONSE" else "CHOOSE YOUR FOLLOW-UP"
	local characterData = dialogue[activeCharacter or ""]
	if not characterData then
		response.Text = "This character does not have dialogue yet."
		makeChoice("Leave", 1, function()
			closeDialogue(true)
		end)
		focusDialogueDefault()
		return
	end
	for index, entry in ipairs(characterData.stages[stageNumber]) do
		makeChoice(entry.choice, index, function()
			playResponse(entry, stageNumber)
		end)
	end
	focusDialogueDefault()
end

playFarewellAndClose = function()
	local characterData = dialogue[activeCharacter or ""]
	if not characterData or not characterData.farewell then
		closeDialogue(true)
		return
	end
	responseSerial += 1
	local serial = responseSerial
	clearChoices()
	focusDialogueDefault()
	choiceHeader.Text = characterData.displayName .. "'S LAST WORD..."
	response.Text = characterData.displayName .. ":  “" .. characterData.farewell.response .. "”"
	local characterFolder = audioRoot:FindFirstChild(activeCharacter or "")
	local audioValue = characterFolder and characterFolder:FindFirstChild(characterData.farewell.audio)
	if not audioValue or not audioValue:IsA("StringValue") then
		task.delay(1.5, function()
			if serial == responseSerial then
				closeDialogue(true)
			end
		end)
		return
	end
	audioPlayer:Stop()
	audioPlayer.Asset = audioValue.Value
	audioPlayer.TimePosition = 0
	task.spawn(function()
		local deadline = os.clock() + 6
		while serial == responseSerial and not audioPlayer.IsReady and os.clock() < deadline do
			task.wait(0.05)
		end
		if serial ~= responseSerial then
			return
		end
		audioPlayer:Play()
		local length = audioPlayer.TimeLength
		if length <= 0 then
			length = 3
		end
		task.wait(math.clamp(length + 0.2, 1.2, 8))
		if serial == responseSerial then
			closeDialogue(true)
		end
	end)
end

local function openDialogue(characterName: string)
	local characterData = dialogue[characterName]
	if not characterData then
		sessionRemote:FireServer("Close")
		return
	end
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local world = environment and environment:FindFirstChild("CooperFamilyNPCs")
	local npc = world and world:FindFirstChild(characterName)
	if not npc or not npc:IsA("Model") then
		sessionRemote:FireServer("Close")
		return
	end
	activeNPC = npc
	activeCharacter = characterName
	closing = false
	title.Text = "TALK TO " .. characterData.displayName
	gui.Enabled = true
	updateResponsiveLayout()
	showStage(1)
end

sessionRemote.OnClientEvent:Connect(function(action, characterName)
	if action == "Open" and type(characterName) == "string" then
		openDialogue(characterName)
	elseif action == "Closed" then
		closeDialogue(false)
	end
end)

scrim.Activated:Connect(function()
	if not closing then
		closeDialogue(true)
	end
end)
closeButton.Activated:Connect(function()
	if not closing then
		closeDialogue(true)
	end
end)
panel.InputBegan:Connect(function() end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not gui.Enabled then
		return
	end
	if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
		closeDialogue(true)
		return
	end
	if processed then
		return
	end
	local choiceIndex = if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne
		then 1
		elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.KeypadTwo
		then 2
		elseif input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.KeypadThree
		then 3
		else nil
	local callback = choiceIndex and choiceCallbacks[choiceIndex]
	if callback then
		callback()
	end
end)

RunService.Heartbeat:Connect(function()
	if not gui.Enabled or not activeNPC then
		return
	end
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local npcRoot = activeNPC:FindFirstChild("Root")
	if not playerRoot
		or not playerRoot:IsA("BasePart")
		or not npcRoot
		or not npcRoot:IsA("BasePart")
		or (playerRoot.Position - npcRoot.Position).Magnitude > 16
	then
		closeDialogue(true)
	end
end)

print("[CooperFamilyDialogue] Two-stage family dialogue UI ready (responsive safe-area layout)")
