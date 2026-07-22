--!strict
-- Calm, low-volume jazz ambience that ducks beneath NPC dialogue.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local TRACK_ID = "rbxassetid://1845341094" -- Chill Jazz, Roblox Creator Store
local NORMAL_VOLUME = 0.11
local DIALOGUE_VOLUME = 0.025
local FADE_IN_SECONDS = 4
local DUCK_SECONDS = 0.45

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldSound = SoundService:FindFirstChild("CooperCalmJazz")
if oldSound then oldSound:Destroy() end

local music = Instance.new("Sound")
music.Name = "CooperCalmJazz"
music.SoundId = TRACK_ID
music.Volume = 0
music.Looped = true
music.PlaybackSpeed = 1
music:SetAttribute("CreatorStoreTrack", "Chill Jazz")
music:SetAttribute("CreatorStoreAssetId", 1845341094)
music.Parent = SoundService

local activeTween: Tween? = nil
local function fadeTo(volume: number, duration: number)
	if activeTween then activeTween:Cancel() end
	activeTween = TweenService:Create(
		music,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = volume }
	)
	activeTween:Play()
end

local loaded = pcall(function()
	ContentProvider:PreloadAsync({ music })
end)
if not loaded or not music.IsLoaded then
	warn("[CooperBackgroundMusic] Chill Jazz could not be loaded")
	return
end

music:Play()
fadeTo(NORMAL_VOLUME, FADE_IN_SECONDS)

local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
local taskWorld = environment and environment:WaitForChild("CooperFamilyTaskWorld", 20)
local boombox = taskWorld and taskWorld:FindFirstChild("CooperIncomeBoombox", true)
local dialogueConnection: RBXScriptConnection? = nil
local activeDialogue: ScreenGui? = nil

local function refreshMix()
	local boomboxPlaying = boombox ~= nil and boombox:GetAttribute("Playing") == true
	local dialoguePlaying = activeDialogue ~= nil and activeDialogue.Enabled
	local targetVolume = if boomboxPlaying then 0 elseif dialoguePlaying then DIALOGUE_VOLUME else NORMAL_VOLUME
	fadeTo(targetVolume, DUCK_SECONDS)
end

local function watchDialogue(gui: Instance)
	if not gui:IsA("ScreenGui") then return end
	if dialogueConnection then dialogueConnection:Disconnect() end
	activeDialogue = gui
	dialogueConnection = gui:GetPropertyChangedSignal("Enabled"):Connect(refreshMix)
	refreshMix()
end

if boombox then
	boombox:GetAttributeChangedSignal("Playing"):Connect(refreshMix)
end
local existingDialogue = playerGui:FindFirstChild("CooperFamilyDialogueUI")
if existingDialogue then watchDialogue(existingDialogue) else refreshMix() end
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "CooperFamilyDialogueUI" then watchDialogue(child) end
end)

print("[CooperBackgroundMusic] Calm jazz ambience ready")
