--!strict
-- Plays George's nearby reaction once per approach, with hysteresis and cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ENTER_DISTANCE = 10
local EXIT_DISTANCE = 14
local COOLDOWN_SECONDS = 18

local player = Players.LocalPlayer
local audioValue = ReplicatedStorage:WaitForChild("CooperFamilyLocalAudio", 15)
	:WaitForChild("George", 10)
	:WaitForChild("HotDamn", 10)
assert(audioValue:IsA("StringValue"), "George HotDamn local audio was not imported")

local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
local npcWorld = environment:WaitForChild("CooperFamilyNPCs", 20)
local george = npcWorld:WaitForChild("George", 15)
local georgeRoot = george:WaitForChild("Root", 10)
assert(george:IsA("Model") and georgeRoot:IsA("BasePart"), "George NPC is malformed")

local oldSound = georgeRoot:FindFirstChild("HotDamnProximity")
if oldSound then oldSound:Destroy() end
local sound = Instance.new("Sound")
sound.Name = "HotDamnProximity"
sound.SoundId = audioValue.Value
sound.Volume = 0.92
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMinDistance = 4
sound.RollOffMaxDistance = 30
sound.Parent = georgeRoot

local inside = false
local lastPlayedAt = -math.huge
local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.12 then return end
	accumulator = 0

	if george:GetAttribute("BoomboxDancing") == true then
		inside = false
		if sound.Playing then sound:Stop() end
		return
	end

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot or not playerRoot:IsA("BasePart") or not georgeRoot.Parent then return end
	local distance = (playerRoot.Position - georgeRoot.Position).Magnitude

	if distance > EXIT_DISTANCE then
		inside = false
		return
	end
	if distance <= ENTER_DISTANCE and not inside then
		inside = true
		local now = os.clock()
		if now - lastPlayedAt >= COOLDOWN_SECONDS and george:GetAttribute("InConversation") ~= true then
			lastPlayedAt = now
			sound.TimePosition = 0
			sound:Play()
		end
	end
end)

print("[CooperGeorgeProximityVoice] Hot Damn proximity reaction ready")
