--!strict
-- Plays Missy's nearby roast once per approach, with hysteresis and cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ENTER_DISTANCE = 10
local EXIT_DISTANCE = 14
local COOLDOWN_SECONDS = 18

local player = Players.LocalPlayer
local audioValue = ReplicatedStorage:WaitForChild("CooperFamilyLocalAudio", 15)
	:WaitForChild("Missy", 10)
	:WaitForChild("IncrediblySmart", 10)
assert(audioValue:IsA("StringValue"), "Missy IncrediblySmart audio is missing")

local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
local npcWorld = environment:WaitForChild("CooperFamilyNPCs", 20)
local missy = npcWorld:WaitForChild("Missy", 15)
local missyRoot = missy:WaitForChild("Root", 10)
assert(missy:IsA("Model") and missyRoot:IsA("BasePart"), "Missy NPC is malformed")

local oldSound = missyRoot:FindFirstChild("IncrediblySmartProximity")
if oldSound then oldSound:Destroy() end
local sound = Instance.new("Sound")
sound.Name = "IncrediblySmartProximity"
sound.SoundId = audioValue.Value
sound.Volume = 0.92
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMinDistance = 4
sound.RollOffMaxDistance = 30
sound.Parent = missyRoot

local inside = false
local lastPlayedAt = -math.huge
local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.12 then return end
	accumulator = 0

	if missy:GetAttribute("BoomboxDancing") == true then
		inside = false
		if sound.Playing then sound:Stop() end
		return
	end

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot or not playerRoot:IsA("BasePart") or not missyRoot.Parent then return end
	local distance = (playerRoot.Position - missyRoot.Position).Magnitude

	if distance > EXIT_DISTANCE then
		inside = false
		return
	end
	if distance <= ENTER_DISTANCE and not inside then
		inside = true
		local now = os.clock()
		if now - lastPlayedAt >= COOLDOWN_SECONDS and missy:GetAttribute("InConversation") ~= true then
			lastPlayedAt = now
			sound.TimePosition = 0
			sound:Play()
		end
	end
end)

print("[CooperMissyProximityVoice] Incredibly Smart proximity roast ready")
