--!strict
-- Plays Georgie's nearby reaction once per approach, with hysteresis and cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ENTER_DISTANCE = 10
local EXIT_DISTANCE = 14
local COOLDOWN_SECONDS = 18

local player = Players.LocalPlayer
local audioValue = ReplicatedStorage:WaitForChild("CooperFamilyLocalAudio", 15)
	:WaitForChild("Georgie", 10)
	:WaitForChild("AnotherDay", 10)
assert(audioValue:IsA("StringValue"), "Georgie AnotherDay local audio was not imported")

local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
local npcWorld = environment:WaitForChild("CooperFamilyNPCs", 20)
local georgie = npcWorld:WaitForChild("Georgie", 15)
local georgieRoot = georgie:WaitForChild("Root", 10)
assert(georgie:IsA("Model") and georgieRoot:IsA("BasePart"), "Georgie NPC is malformed")

local oldSound = georgieRoot:FindFirstChild("AnotherDayProximity")
if oldSound then oldSound:Destroy() end
local sound = Instance.new("Sound")
sound.Name = "AnotherDayProximity"
sound.SoundId = audioValue.Value
sound.Volume = 0.92
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMinDistance = 4
sound.RollOffMaxDistance = 30
sound.Parent = georgieRoot

local inside = false
local lastPlayedAt = -math.huge
local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.12 then return end
	accumulator = 0

	if georgie:GetAttribute("BoomboxDancing") == true then
		inside = false
		if sound.Playing then sound:Stop() end
		return
	end

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot or not playerRoot:IsA("BasePart") or not georgieRoot.Parent then return end
	local distance = (playerRoot.Position - georgieRoot.Position).Magnitude

	if distance > EXIT_DISTANCE then
		inside = false
		return
	end
	if distance <= ENTER_DISTANCE and not inside then
		inside = true
		local now = os.clock()
		if now - lastPlayedAt >= COOLDOWN_SECONDS and georgie:GetAttribute("InConversation") ~= true then
			lastPlayedAt = now
			sound.TimePosition = 0
			sound:Play()
		end
	end
end)

print("[CooperGeorgieProximityVoice] Another Day proximity reaction ready")
