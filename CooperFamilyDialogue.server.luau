--!strict
-- Server-side proximity and session ownership for Cooper family dialogue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local oldRoot = ReplicatedStorage:FindFirstChild("CooperFamilyDialogue")
if oldRoot then oldRoot:Destroy() end

local root = Instance.new("Folder")
root.Name = "CooperFamilyDialogue"
root.Parent = ReplicatedStorage

local sessionRemote = Instance.new("RemoteEvent")
sessionRemote.Name = "Session"
sessionRemote.Parent = root

local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
assert(environment, "CooperHouseEnvironment was not found")
local npcWorld = environment:WaitForChild("CooperFamilyNPCs", 20)
assert(npcWorld, "CooperFamilyNPCs was not started")

local activeByPlayer: { [Player]: Model } = {}
local activePlayerByNPC: { [Model]: Player } = {}
local promptByNPC: { [Model]: ProximityPrompt } = {}
local sessionSerial: { [Player]: number } = {}

local function endSession(player: Player)
	local npc = activeByPlayer[player]
	if not npc then return end
	activeByPlayer[player] = nil
	if activePlayerByNPC[npc] == player then
		activePlayerByNPC[npc] = nil
		npc:SetAttribute("InConversation", false)
		local prompt = promptByNPC[npc]
		if prompt and prompt.Parent then
			prompt.Enabled = npc:GetAttribute("BoomboxDancing") ~= true
				and prompt:GetAttribute("CooperComputerPrioritySuppressed") ~= true
		end
	end
end

local function beginSession(player: Player, npc: Model)
	if activeByPlayer[player] or activePlayerByNPC[npc] or npc:GetAttribute("BoomboxDancing") == true then return end
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local npcRoot = npc:FindFirstChild("Root")
	if not playerRoot or not playerRoot:IsA("BasePart") or not npcRoot or not npcRoot:IsA("BasePart") then return end
	if (playerRoot.Position - npcRoot.Position).Magnitude > 12 then return end

	activeByPlayer[player] = npc
	activePlayerByNPC[npc] = player
	npc:SetAttribute("InConversation", true)
	local prompt = promptByNPC[npc]
	if prompt then prompt.Enabled = false end

	local serial = (sessionSerial[player] or 0) + 1
	sessionSerial[player] = serial
	sessionRemote:FireClient(player, "Open", npc.Name)

	task.delay(90, function()
		if sessionSerial[player] == serial then
			endSession(player)
			sessionRemote:FireClient(player, "Closed", npc.Name)
		end
	end)
end

local function installPrompt(npcName: string)
	local npc = npcWorld:WaitForChild(npcName, 20)
	assert(npc and npc:IsA("Model"), npcName .. " NPC was not found")
	local npcRoot = npc:WaitForChild("Root", 10)
	assert(npcRoot and npcRoot:IsA("BasePart"), npcName .. " root was not found")
	local oldPrompt = npcRoot:FindFirstChild("TalkPrompt")
	if oldPrompt then oldPrompt:Destroy() end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = npcName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = npcRoot
	promptByNPC[npc] = prompt
	npc:GetAttributeChangedSignal("BoomboxDancing"):Connect(function()
		if npc:GetAttribute("BoomboxDancing") == true then
			local activePlayer = activePlayerByNPC[npc]
			if activePlayer then
				sessionSerial[activePlayer] = (sessionSerial[activePlayer] or 0) + 1
				endSession(activePlayer)
				sessionRemote:FireClient(activePlayer, "Closed", npc.Name)
			end
			prompt.Enabled = false
		elseif npc:GetAttribute("InConversation") ~= true
			and prompt:GetAttribute("CooperComputerPrioritySuppressed") ~= true
		then
			prompt.Enabled = true
		end
	end)
	prompt.Triggered:Connect(function(player)
		beginSession(player, npc)
	end)
end

installPrompt("George")
installPrompt("Georgie")
installPrompt("Mary")
installPrompt("Missy")

sessionRemote.OnServerEvent:Connect(function(player, action)
	if action == "Close" then
		sessionSerial[player] = (sessionSerial[player] or 0) + 1
		endSession(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessionSerial[player] = (sessionSerial[player] or 0) + 1
	endSession(player)
	sessionSerial[player] = nil
end)

print("[CooperFamilyDialogue] Family conversation prompts ready")
