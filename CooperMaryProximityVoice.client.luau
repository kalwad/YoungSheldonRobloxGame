--!strict
-- Plays Mary's nearby reaction once per approach, with hysteresis and cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ENTER_DISTANCE = 10
local EXIT_DISTANCE = 14
local COOLDOWN_SECONDS = 18

local player = Players.LocalPlayer
local audioValue = ReplicatedStorage:WaitForChild("CooperFamilyLocalAudio", 15)
	:WaitForChild("Mary", 10)
	:WaitForChild("LordHaveMercy", 10)
assert(audioValue:IsA("StringValue"), "Mary LordHaveMercy audio is missing")

local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
local npcWorld = environment:WaitForChild("CooperFamilyNPCs", 20)
local mary = npcWorld:WaitForChild("Mary", 15)
local maryRoot = mary:WaitForChild("Root", 10)
assert(mary:IsA("Model") and maryRoot:IsA("BasePart"), "Mary NPC is malformed")

local oldSound = maryRoot:FindFirstChild("LordHaveMercyProximity")
if oldSound then oldSound:Destroy() end
local sound = Instance.new("Sound")
sound.Name = "LordHaveMercyProximity"
sound.SoundId = audioValue.Value
sound.Volume = 0.92
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMinDistance = 4
sound.RollOffMaxDistance = 30
sound.Parent = maryRoot

local inside = false
local lastPlayedAt = -math.huge
local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.12 then return end
	accumulator = 0

	if mary:GetAttribute("BoomboxDancing") == true then
		inside = false
		if sound.Playing then sound:Stop() end
		return
	end

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot or not playerRoot:IsA("BasePart") or not maryRoot.Parent then return end
	local distance = (playerRoot.Position - maryRoot.Position).Magnitude

	if distance > EXIT_DISTANCE then
		inside = false
		return
	end
	if distance <= ENTER_DISTANCE and not inside then
		inside = true
		local now = os.clock()
		if now - lastPlayedAt >= COOLDOWN_SECONDS and mary:GetAttribute("InConversation") ~= true then
			lastPlayedAt = now
			sound.TimePosition = 0
			sound:Play()
		end
	end
end)

print("[CooperMaryProximityVoice] Lord Have Mercy proximity reaction ready")
