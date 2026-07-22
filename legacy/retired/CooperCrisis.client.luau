--!nonstrict
-- Responsive client presentation for tornadoes, D.E.S. raids, and chaos events.
-- Install as StarterPlayer.StarterPlayerScripts.CooperCrisisClient.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local root = ReplicatedStorage:WaitForChild("CooperCrisis", 20)
assert(root, "ReplicatedStorage.CooperCrisis was not installed")
local state = root:WaitForChild("State", 20)
local eventRemote = root:WaitForChild("Event", 20)
local requestRemote = root:WaitForChild("Request", 20)
local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
local crisisWorld = environment and environment:WaitForChild("CooperCrisisWorld", 20)
assert(crisisWorld, "CooperHouseEnvironment.CooperCrisisWorld was not installed")

local old = playerGui:FindFirstChild("CooperCrisisHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CooperCrisisHUD"
gui.DisplayOrder = 65
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local weatherOverlay = Instance.new("Frame")
weatherOverlay.Name = "WeatherOverlay"
weatherOverlay.Size = UDim2.fromScale(1, 1)
weatherOverlay.BackgroundColor3 = Color3.fromRGB(34, 47, 58)
weatherOverlay.BackgroundTransparency = 1
weatherOverlay.BorderSizePixel = 0
weatherOverlay.ZIndex = 1
weatherOverlay.Parent = gui

local weatherGradient = Instance.new("UIGradient")
weatherGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 34, 46)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(65, 74, 69)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 16, 22)),
})
weatherGradient.Rotation = 25
weatherGradient.Parent = weatherOverlay

local desOverlay = Instance.new("Frame")
desOverlay.Name = "DESOverlay"
desOverlay.Size = UDim2.fromScale(1, 1)
desOverlay.BackgroundColor3 = Color3.fromRGB(11, 31, 43)
desOverlay.BackgroundTransparency = 1
desOverlay.BorderSizePixel = 0
desOverlay.ZIndex = 2
desOverlay.Parent = gui

local scanLines = Instance.new("UIGradient")
scanLines.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 128, 152)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 28, 39)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(54, 128, 152)),
})
scanLines.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.94),
	NumberSequenceKeypoint.new(0.5, 0.99),
	NumberSequenceKeypoint.new(1, 0.94),
})
scanLines.Rotation = 90
scanLines.Parent = desOverlay

local status = Instance.new("Frame")
status.Name = "StatusCard"
status.AnchorPoint = Vector2.new(1, 0)
status.Position = UDim2.new(1, -18, 0, 96)
status.Size = UDim2.fromOffset(310, 94)
status.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
status.BackgroundTransparency = 0.08
status.BorderSizePixel = 0
status.Visible = false
status.ZIndex = 20
status.Parent = gui

local statusScale = Instance.new("UIScale")
statusScale.Scale = 1
statusScale.Parent = status

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 12)
statusCorner.Parent = status

local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.fromRGB(255, 176, 51)
statusStroke.Thickness = 2
statusStroke.Parent = status

local crisisName = Instance.new("TextLabel")
crisisName.Name = "CrisisName"
crisisName.Position = UDim2.fromOffset(15, 10)
crisisName.Size = UDim2.new(1, -30, 0, 25)
crisisName.BackgroundTransparency = 1
crisisName.Font = Enum.Font.GothamBlack
crisisName.Text = "TORNADO"
crisisName.TextColor3 = Color3.fromRGB(255, 216, 111)
crisisName.TextSize = 20
crisisName.TextXAlignment = Enum.TextXAlignment.Left
crisisName.ZIndex = 21
crisisName.Parent = status

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "Phase"
phaseLabel.Position = UDim2.fromOffset(15, 37)
phaseLabel.Size = UDim2.new(1, -100, 0, 40)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Font = Enum.Font.GothamBold
phaseLabel.Text = "WEATHER WATCH"
phaseLabel.TextColor3 = Color3.fromRGB(238, 242, 247)
phaseLabel.TextSize = 15
phaseLabel.TextWrapped = true
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.TextYAlignment = Enum.TextYAlignment.Top
phaseLabel.ZIndex = 21
phaseLabel.Parent = status

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.AnchorPoint = Vector2.new(1, 1)
timerLabel.Position = UDim2.new(1, -15, 1, -15)
timerLabel.Size = UDim2.fromOffset(72, 36)
timerLabel.BackgroundColor3 = Color3.fromRGB(235, 73, 59)
timerLabel.BorderSizePixel = 0
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.Text = "00:12"
timerLabel.TextColor3 = Color3.new(1, 1, 1)
timerLabel.TextSize = 18
timerLabel.ZIndex = 22
timerLabel.Parent = status
local timerCorner = Instance.new("UICorner")
timerCorner.CornerRadius = UDim.new(0, 8)
timerCorner.Parent = timerLabel

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.28)
banner.Size = UDim2.new(0.8, 0, 0, 130)
banner.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
banner.BackgroundTransparency = 1
banner.BorderSizePixel = 0
banner.Visible = false
banner.ZIndex = 40
banner.Parent = gui

local bannerScale = Instance.new("UIScale")
bannerScale.Scale = 0.9
bannerScale.Parent = banner
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 14)
bannerCorner.Parent = banner

local bannerTitle = Instance.new("TextLabel")
bannerTitle.Position = UDim2.fromOffset(24, 17)
bannerTitle.Size = UDim2.new(1, -48, 0, 57)
bannerTitle.BackgroundTransparency = 1
bannerTitle.Font = Enum.Font.GothamBlack
bannerTitle.Text = "TORNADO WARNING"
bannerTitle.TextColor3 = Color3.fromRGB(255, 218, 99)
bannerTitle.TextScaled = true
bannerTitle.TextWrapped = true
bannerTitle.ZIndex = 41
bannerTitle.Parent = banner
local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MinTextSize = 17
titleConstraint.MaxTextSize = 36
titleConstraint.Parent = bannerTitle

local bannerSubtitle = Instance.new("TextLabel")
bannerSubtitle.Position = UDim2.fromOffset(24, 78)
bannerSubtitle.Size = UDim2.new(1, -48, 0, 34)
bannerSubtitle.BackgroundTransparency = 1
bannerSubtitle.Font = Enum.Font.GothamMedium
bannerSubtitle.Text = "Secure loose equipment and get inside."
bannerSubtitle.TextColor3 = Color3.fromRGB(235, 239, 244)
bannerSubtitle.TextScaled = true
bannerSubtitle.TextWrapped = true
bannerSubtitle.ZIndex = 41
bannerSubtitle.Parent = banner
local subtitleConstraint = Instance.new("UITextSizeConstraint")
subtitleConstraint.MinTextSize = 12
subtitleConstraint.MaxTextSize = 20
subtitleConstraint.Parent = bannerSubtitle

local eventLayer = Instance.new("Frame")
eventLayer.Name = "EventLayer"
eventLayer.Size = UDim2.fromScale(1, 1)
eventLayer.BackgroundTransparency = 1
eventLayer.ZIndex = 30
eventLayer.Parent = gui

local progress = Instance.new("Frame")
progress.Name = "DESProgress"
progress.AnchorPoint = Vector2.new(0.5, 1)
progress.Position = UDim2.new(0.5, 0, 1, -72)
progress.Size = UDim2.fromOffset(440, 54)
progress.BackgroundColor3 = Color3.fromRGB(10, 26, 35)
progress.BackgroundTransparency = 0.08
progress.BorderSizePixel = 0
progress.Visible = false
progress.ZIndex = 24
progress.Parent = gui
local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(0, 10)
progressCorner.Parent = progress
local progressText = Instance.new("TextLabel")
progressText.Position = UDim2.fromOffset(14, 7)
progressText.Size = UDim2.new(1, -28, 1, -14)
progressText.BackgroundTransparency = 1
progressText.Font = Enum.Font.Code
progressText.Text = "D.E.S. INSPECTION  0 / 4   [PERMIT • CONCEAL • DISTRACT]"
progressText.TextColor3 = Color3.fromRGB(142, 224, 237)
progressText.TextScaled = true
progressText.TextWrapped = true
progressText.ZIndex = 25
progressText.Parent = progress
local progressConstraint = Instance.new("UITextSizeConstraint")
progressConstraint.MinTextSize = 11
progressConstraint.MaxTextSize = 17
progressConstraint.Parent = progressText

local windSound = Instance.new("Sound")
windSound.Name = "TornadoWind"
windSound.SoundId = "rbxasset://sounds/action_falling.mp3"
windSound.Volume = 0
windSound.Looped = true
windSound.Parent = SoundService

local alertSound = Instance.new("Sound")
alertSound.Name = "CrisisAlert"
alertSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
alertSound.Volume = 0.55
alertSound.Parent = SoundService

local swooshSound = Instance.new("Sound")
swooshSound.Name = "ChaosStinger"
-- The old swoosh.wav alias is no longer approved for this experience.
swooshSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
swooshSound.Volume = 0.45
swooshSound.Parent = SoundService

local bannerSerial = 0
local activeKind = "None"
local activePhase = "Idle"
local phaseEndsAt = 0
local desScore = 0
local desTarget = 4
local cameraShake = 0
local latestRepairText = nil

local trackedPrompts = {}

local function interactionSpeed()
	return math.clamp(tonumber(player:GetAttribute("CooperInteractionSpeedMultiplier")) or 1, 1, 2)
end

local function applyPromptSpeed(prompt)
	if not prompt:IsA("ProximityPrompt") or prompt:GetAttribute("CooperCrisisInteraction") ~= true then
		return
	end
	local baseDuration = math.max(0, tonumber(prompt:GetAttribute("CooperBaseHoldDuration")) or prompt.HoldDuration)
	prompt.HoldDuration = if baseDuration <= 0 then 0 else math.max(0.05, baseDuration / interactionSpeed())
end

local function trackPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") or trackedPrompts[prompt] then
		return
	end
	trackedPrompts[prompt] = true
	prompt:GetAttributeChangedSignal("CooperCrisisInteraction"):Connect(function()
		applyPromptSpeed(prompt)
	end)
	prompt:GetAttributeChangedSignal("CooperBaseHoldDuration"):Connect(function()
		applyPromptSpeed(prompt)
	end)
	applyPromptSpeed(prompt)
end

for _, descendant in ipairs(crisisWorld:GetDescendants()) do
	trackPrompt(descendant)
end
crisisWorld.DescendantAdded:Connect(function(descendant)
	task.defer(trackPrompt, descendant)
end)
player:GetAttributeChangedSignal("CooperInteractionSpeedMultiplier"):Connect(function()
	for prompt in pairs(trackedPrompts) do
		if prompt.Parent then
			applyPromptSpeed(prompt)
		else
			trackedPrompts[prompt] = nil
		end
	end
end)

local function play(sound)
	sound.TimePosition = 0
	SoundService:PlayLocalSound(sound)
end

local function showBanner(title, subtitle, duration, color)
	bannerSerial += 1
	local serial = bannerSerial
	banner.Visible = true
	banner.BackgroundTransparency = 1
	bannerScale.Scale = 0.86
	bannerTitle.Text = title or "EVENT"
	bannerSubtitle.Text = subtitle or ""
	bannerTitle.TextColor3 = color or Color3.fromRGB(255, 218, 99)
	TweenService:Create(banner, TweenInfo.new(0.22), { BackgroundTransparency = 0.12 }):Play()
	TweenService:Create(bannerScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duration or 3.5, function()
		if bannerSerial ~= serial then
			return
		end
		local tween = TweenService:Create(banner, TweenInfo.new(0.24), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if bannerSerial == serial then
			banner.Visible = false
		end
	end)
end

local function dismissBanner()
	bannerSerial += 1
	banner.Visible = false
	banner.BackgroundTransparency = 1
end

local function clearEventLayer()
	for _, child in ipairs(eventLayer:GetChildren()) do
		child:Destroy()
	end
end

local function spawnCharacterFlood(seed, duration, stareOnly)
	local rng = Random.new(seed or 1)
	local names = { "SHELDON", "GEORGE", "MARY", "MISSY", "GEORGIE", "MEEMAW", "BILLY" }
	local colors = {
		Color3.fromRGB(90, 173, 255), Color3.fromRGB(231, 82, 66), Color3.fromRGB(251, 204, 91),
		Color3.fromRGB(242, 117, 183), Color3.fromRGB(102, 208, 145), Color3.fromRGB(188, 125, 234),
	}
	local count = stareOnly and 8 or 22
	for index = 1, count do
		local card = Instance.new("TextLabel")
		card.Name = "Cutout" .. index
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(rng:NextNumber(0.06, 0.94), stareOnly and rng:NextNumber(0.72, 0.91) or rng:NextNumber(0.12, 0.9))
		card.Size = UDim2.fromOffset(stareOnly and 94 or rng:NextInteger(72, 132), stareOnly and 94 or rng:NextInteger(92, 170))
		card.BackgroundColor3 = colors[rng:NextInteger(1, #colors)]
		card.BackgroundTransparency = 0.12
		card.BorderSizePixel = 0
		card.Font = Enum.Font.GothamBlack
		card.Text = names[rng:NextInteger(1, #names)] .. string.char(10) .. (stareOnly and "•_•" or "▣")
		card.TextColor3 = Color3.fromRGB(255, 255, 255)
		card.TextScaled = true
		card.TextWrapped = true
		card.Rotation = stareOnly and 0 or rng:NextNumber(-12, 12)
		card.ZIndex = 31
		card.Parent = eventLayer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = card
		card.Size = UDim2.fromOffset(1, 1)
		TweenService:Create(card, TweenInfo.new(0.35 + index * 0.018, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(stareOnly and 94 or rng:NextInteger(72, 132), stareOnly and 94 or rng:NextInteger(92, 170)),
		}):Play()
	end
	task.delay(duration, clearEventLayer)
end

local function runVisualEvent(packet)
	clearEventLayer()
	local eventId = packet.eventId
	if eventId == "CharacterFlood" then
		spawnCharacterFlood(packet.seed, packet.duration, false)
	elseif eventId == "EveryoneStares" then
		spawnCharacterFlood(packet.seed, packet.duration, true)
	elseif eventId == "GiantGeorge" then
		local george = Instance.new("TextLabel")
		george.AnchorPoint = Vector2.new(0.5, 1)
		george.Position = UDim2.fromScale(0.5, 1.03)
		george.Size = UDim2.fromScale(0.48, 0.83)
		george.BackgroundColor3 = Color3.fromRGB(118, 41, 35)
		george.BackgroundTransparency = 0.08
		george.BorderSizePixel = 0
		george.Font = Enum.Font.GothamBlack
		george.Text = "GEORGE" .. string.char(10) .. "IS" .. string.char(10) .. "CHECKING"
		george.TextColor3 = Color3.fromRGB(255, 230, 202)
		george.TextScaled = true
		george.TextWrapped = true
		george.ZIndex = 31
		george.Parent = eventLayer
		TweenService:Create(george, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.98) }):Play()
		task.delay(packet.duration, clearEventLayer)
	elseif eventId == "FiveSecondLoop" then
		task.spawn(function()
			for _ = 1, 2 do
				if not gui.Parent then return end
				showBanner(packet.title, packet.subtitle, 2.1, Color3.fromRGB(128, 225, 255))
				task.wait(5)
			end
		end)
	end
	showBanner(packet.title, packet.subtitle, math.min(packet.duration or 8, 4.2), Color3.fromRGB(125, 232, 255))
	play(swooshSound)
end

local function applyModeVisuals()
	local tornado = activeKind == "Tornado"
	local des = activeKind == "DESRaid"
	status.Visible = tornado or des
	progress.Visible = des and activePhase == "Inspection"
	crisisName.Text = tornado and "TORNADO" or "D.E.S. RAID"
	crisisName.TextColor3 = tornado and Color3.fromRGB(255, 216, 111) or Color3.fromRGB(139, 231, 247)
	statusStroke.Color = tornado and Color3.fromRGB(255, 176, 51) or Color3.fromRGB(64, 183, 211)
	weatherOverlay.BackgroundTransparency = tornado and 0.78 or 1
	desOverlay.BackgroundTransparency = des and 0.9 or 1
	local impact = tornado and (activePhase == "ImpactOne" or activePhase == "ImpactTwo")
	cameraShake = impact and (activePhase == "ImpactTwo" and 0.48 or 0.33) or 0
	local targetWind = impact and 0.7 or (tornado and 0.25 or 0)
	if targetWind > 0 and not windSound.IsPlaying then
		windSound:Play()
	end
	TweenService:Create(windSound, TweenInfo.new(0.6), { Volume = targetWind }):Play()
	if not tornado then
		task.delay(0.7, function()
			if activeKind ~= "Tornado" and windSound.IsPlaying then
				windSound:Stop()
			end
		end)
	end
end

local function updateFromState()
	activeKind = tostring(state:GetAttribute("ActiveKind") or "None")
	activePhase = tostring(state:GetAttribute("Phase") or "Idle")
	phaseEndsAt = tonumber(state:GetAttribute("PhaseEndsAt")) or 0
	desScore = tonumber(state:GetAttribute("DESScore")) or 0
	desTarget = tonumber(state:GetAttribute("DESTarget")) or 4
	phaseLabel.Text = string.upper(activePhase:gsub("(%l)(%u)", "%1 %2"))
	progressText.Text = string.format("D.E.S. INSPECTION  %d / %d   [PERMIT • CONCEAL • DISTRACT]", desScore, desTarget)
	applyModeVisuals()
end

for _, attribute in ipairs({ "ActiveKind", "Phase", "PhaseEndsAt", "DESScore", "DESTarget" }) do
	state:GetAttributeChangedSignal(attribute):Connect(updateFromState)
end

eventRemote.OnClientEvent:Connect(function(packet)
	if type(packet) ~= "table" then
		return
	end
	if packet.kind == "Snapshot" and type(packet.data) == "table" then
		activeKind = tostring(packet.data.kind or activeKind)
		activePhase = tostring(packet.data.phase or activePhase)
		phaseEndsAt = tonumber(packet.data.phaseEndsAt) or phaseEndsAt
		desScore = tonumber(packet.data.desScore) or desScore
		updateFromState()
	elseif packet.kind == "Started" then
		if packet.crisis == "Tornado" then
			latestRepairText = nil
		end
		play(alertSound)
		showBanner(
			packet.crisis == "Tornado" and "TORNADO SYSTEM ACTIVE" or "D.E.S. RAID INCOMING",
			packet.reason or "Major crisis",
			4.5,
			packet.crisis == "Tornado" and Color3.fromRGB(255, 210, 82) or Color3.fromRGB(124, 229, 246)
		)
	elseif packet.kind == "Phase" then
		activeKind = tostring(packet.crisis or activeKind)
		activePhase = tostring(packet.phase or activePhase)
		phaseEndsAt = tonumber(packet.phaseEndsAt) or phaseEndsAt
		if activePhase == "Warning" or activePhase == "ImpactOne" or activePhase == "ImpactTwo" or activePhase == "Inspection" then
			play(alertSound)
			showBanner(packet.message or activePhase, packet.crisis == "DESRaid" and "Use the three marked inspection stations." or "Secure equipment and stay inside.", 3.4)
		end
		updateFromState()
	elseif packet.kind == "DESProgress" then
		desScore = tonumber(packet.score) or desScore
		progressText.Text = string.format("D.E.S. INSPECTION  %d / %d   +%d %s", desScore, packet.target or 4, packet.amount or 0, string.upper(packet.route or ""))
		play(alertSound)
	elseif packet.kind == "BrainEvent" then
		runVisualEvent(packet)
	elseif packet.kind == "BrainEventEnded" then
		clearEventLayer()
		dismissBanner()
	elseif packet.kind == "Secured" and packet.playerUserId == player.UserId then
		local slots = ""
		if packet.method == "Locker" and tonumber(packet.lockerUsed) and tonumber(packet.lockerCapacity) then
			slots = string.format(" (%d/%d protected slots)", packet.lockerUsed, packet.lockerCapacity)
		end
		showBanner("STORM ITEM SECURED", tostring(packet.item) .. " is protected by " .. tostring(packet.method) .. slots .. ".", 2.8, Color3.fromRGB(132, 240, 151))
	elseif packet.kind == "Personal" and packet.playerUserId == player.UserId then
		showBanner("NOT YET", packet.message or "That cannot be done right now.", 2.5, Color3.fromRGB(255, 155, 110))
	elseif packet.kind == "Confiscated" then
		local seconds = math.max(0, math.floor((packet.releaseAt or 0) - workspace:GetServerTimeNow()))
		local fineText = (tonumber(packet.totalAllowanceFine) or 0) > 0 and " Personal allowance fines were applied." or ""
		showBanner("D.E.S. CONFISCATED EQUIPMENT", "Recoverable in " .. tostring(seconds) .. " seconds." .. fineText, 4, Color3.fromRGB(255, 116, 104))
	elseif packet.kind == "DESAllowance" and packet.outcome == "Reward" then
		local rewarded = false
		for _, userId in ipairs(type(packet.playerUserIds) == "table" and packet.playerUserIds or {}) do
			if tonumber(userId) == player.UserId then
				rewarded = true
				break
			end
		end
		if rewarded then
			showBanner("D.E.S. INSPECTION PASSED", "+$" .. tostring(tonumber(packet.amount) or 0) .. " personal allowance", 3.2, Color3.fromRGB(137, 244, 160))
		end
	elseif packet.kind == "Recovered" and packet.playerUserId == player.UserId then
		local reward = math.max(0, math.floor(tonumber(packet.allowanceReward) or 0))
		local rewardText = reward > 0 and (" +$" .. tostring(reward) .. " allowance") or ""
		showBanner("EQUIPMENT RECOVERED", tostring(packet.item) .. " returned to the garage." .. rewardText, 3, Color3.fromRGB(137, 244, 160))
	elseif packet.kind == "TornadoRepairs" then
		local personalCharge = nil
		for _, record in ipairs(type(packet.charges) == "table" and packet.charges or {}) do
			if tonumber(record.userId) == player.UserId then
				personalCharge = math.max(0, math.floor(tonumber(record.charged) or 0))
				break
			end
		end
		if personalCharge ~= nil then
			local repairUnits = math.max(0, math.floor(tonumber(packet.repairUnits) or 0))
			local personalCost = math.max(0, math.floor(tonumber(packet.personalCost) or 0))
			local savings = math.max(0, math.floor(tonumber(packet.discountSavings) or 0))
			if repairUnits == 0 then
				latestRepairText = "All loose equipment was recovered, so the repair bill was $0."
			elseif savings > 0 then
				latestRepairText = string.format("Repairs were billed at $%d; $%d was deducted. Repair Discount saved $%d.", personalCost, personalCharge, savings)
			else
				latestRepairText = string.format("Aftermath repairs were billed at $%d; $%d was deducted.", personalCost, personalCharge)
			end
		end
	elseif packet.kind == "Resolved" then
		local success = packet.success ~= false
		local resolutionText = tostring(packet.reason or packet.outcome or "")
		if packet.crisis == "Tornado" and latestRepairText then
			resolutionText ..= " " .. latestRepairText
		end
		showBanner(
			string.upper(tostring(packet.crisis)) .. (success and " RESOLVED" or " ENDED"),
			resolutionText,
			4,
			success and Color3.fromRGB(137, 244, 160) or Color3.fromRGB(255, 116, 104)
		)
		latestRepairText = nil
		activeKind = "None"
		activePhase = "Idle"
		phaseEndsAt = 0
		applyModeVisuals()
	end
end)

RunService:BindToRenderStep("CooperCrisisCamera", Enum.RenderPriority.Camera.Value + 2, function()
	if cameraShake <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		local t = os.clock() * 19
		camera.CFrame *= CFrame.new(math.noise(t, 0, 0) * cameraShake, math.noise(0, t, 0) * cameraShake * 0.6, 0)
	end
end)

RunService.RenderStepped:Connect(function()
	if status.Visible then
		local remaining = math.max(0, phaseEndsAt - workspace:GetServerTimeNow())
		timerLabel.Text = string.format("%02d:%02d", math.floor(remaining / 60), math.ceil(remaining) % 60)
		timerLabel.BackgroundColor3 = remaining <= 5 and Color3.fromRGB(232, 61, 54) or Color3.fromRGB(217, 124, 39)
	end
	weatherGradient.Offset = Vector2.new(math.sin(os.clock() * 0.65) * 0.18, 0)
end)

local viewportConnection = nil
local function applyResponsive()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = viewport.X
	local scale = math.clamp(width / 1100, 0.62, 1)
	statusScale.Scale = scale
	status.Size = UDim2.fromOffset(310, 94)
	status.Position = UDim2.new(1, -12, 0, width < 700 and 64 or 96)
	progress.Size = UDim2.fromOffset(math.min(440, width - 24), 54)
	banner.Size = UDim2.new(width < 700 and 0.94 or 0.8, 0, 0, width < 700 and 112 or 130)
end

local function bindViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsive)
	end
	applyResponsive()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
bindViewport()

updateFromState()
requestRemote:FireServer("RequestSnapshot")
script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep("CooperCrisisCamera")
end)
print("[CooperCrisis] Crisis presentation ready")
