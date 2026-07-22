--!strict
-- Edit-mode rollback installer for the original four Cooper PNG characters.
--
-- This installer intentionally restores the preserved, polished dialogue and
-- proximity clients. After it runs, inject CooperCharacters.server.luau into
-- ServerScriptService.CooperFamilyNPCs (the local filename is retained only so
-- the repository's existing install workflow does not lose the source).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Stop the playtest before restoring the Cooper NPCs")

local INSTALL_VERSION = "2026-07-13.simple-four.1"
local environment = assert(Workspace:FindFirstChild("CooperHouseEnvironment"), "CooperHouseEnvironment was not found")
local starterPlayerScripts = assert(StarterPlayer:FindFirstChild("StarterPlayerScripts"), "StarterPlayerScripts was not found")

local expectedImages = {
	George = 114737318979057,
	Georgie = 137011952735257,
	Mary = 109845379583984,
	Missy = 105870837764920,
}

local expectedCatchphrases = {
	George = { "HotDamn", 123587414049600 },
	Mary = { "LordHaveMercy", 85333334351253 },
	Missy = { "IncrediblySmart", 133768516435257 },
	Georgie = { "AnotherDay", 122044176484695 },
}

local function assetId(value: string): number
	return tonumber(string.match(value, "(%d+)$")) or 0
end

local imageBank = assert(ReplicatedStorage:FindFirstChild("CooperFamilyLocalImages"), "CooperFamilyLocalImages was not found")
local audioBank = assert(ReplicatedStorage:FindFirstChild("CooperFamilyLocalAudio"), "CooperFamilyLocalAudio was not found")
assert(imageBank:IsA("Folder"), "CooperFamilyLocalImages must be a Folder")
assert(audioBank:IsA("Folder"), "CooperFamilyLocalAudio must be a Folder")

for characterName, expectedId in pairs(expectedImages) do
	local value = imageBank:FindFirstChild(characterName)
	assert(value and value:IsA("StringValue"), characterName .. " published image is missing")
	assert(assetId(value.Value) == expectedId, characterName .. " published image ID changed")

	local catchphrase = expectedCatchphrases[characterName]
	local characterAudio = audioBank:FindFirstChild(characterName)
	assert(characterAudio and characterAudio:IsA("Folder"), characterName .. " audio Folder is missing")
	local audioValue = characterAudio:FindFirstChild(catchphrase[1] :: string)
	assert(audioValue and audioValue:IsA("StringValue"), characterName .. " proximity catchphrase is missing")
	assert(assetId(audioValue.Value) == (catchphrase[2] :: number), characterName .. " proximity catchphrase ID changed")
end

local npcServer = assert(ServerScriptService:FindFirstChild("CooperFamilyNPCs"), "The preserved CooperFamilyNPCs server script is missing")
local dialogueServer = assert(ServerScriptService:FindFirstChild("CooperFamilyDialogue"), "The preserved CooperFamilyDialogue server script is missing")
assert(npcServer:IsA("Script"), "ServerScriptService.CooperFamilyNPCs must be a Script")
assert(dialogueServer:IsA("Script"), "ServerScriptService.CooperFamilyDialogue must be a Script")

local requiredClients = {
	"CooperFamilyDialogue",
	"CooperGeorgeProximityVoice",
	"CooperMaryProximityVoice",
	"CooperMissyProximityVoice",
	"CooperGeorgieProximityVoice",
}
local clients = {}
for _, name in ipairs(requiredClients) do
	local client = starterPlayerScripts:FindFirstChild(name)
	assert(client and client:IsA("LocalScript"), "The preserved " .. name .. " LocalScript is missing")
	clients[name] = client
end

ChangeHistoryService:SetWaypoint("BeforeRestoreSimpleCooperCharacters")

-- Remove the advanced replacement completely so it cannot spawn cards, extra
-- characters, Panic stations, briskets, random quote toasts, or a Panic HUD.
for _, instance in pairs({
	ServerScriptService:FindFirstChild("CooperCharacters"),
	ServerScriptService:FindFirstChild("CooperCharacterServerEvents"),
	starterPlayerScripts:FindFirstChild("CooperCharacters"),
	ReplicatedStorage:FindFirstChild("CooperCharacters"),
	environment:FindFirstChild("CooperCharacters"),
	environment:FindFirstChild("CooperFamilyNPCs_LegacyAssets"),
	Lighting:FindFirstChild("CooperCharacterPanicColor"),
}) do
	if instance then instance:Destroy() end
end

for _, descendant in ipairs(StarterGui:GetDescendants()) do
	if descendant.Name == "CooperCharactersHUD" or descendant.Name == "PanicOverlay" or descendant.Name == "BrisketControls" then
		descendant:Destroy()
	end
end

-- The restored server recreates its four-character world cleanly every run.
-- Removing an edit-time copy also guarantees there are no stale Mandy, Meemaw,
-- card, state-label, or idle-bubble instances left behind.
local editWorld = environment:FindFirstChild("CooperFamilyNPCs")
if editWorld then editWorld:Destroy() end

local duplicateDialogue = ServerScriptService:FindFirstChild("FamilyDialogue")
if duplicateDialogue and duplicateDialogue ~= dialogueServer and duplicateDialogue:IsA("Script") then
	duplicateDialogue.Enabled = false
	duplicateDialogue:SetAttribute("SupersededBy", "CooperFamilyDialogue@" .. INSTALL_VERSION)
end

npcServer:SetAttribute("InstallVersion", INSTALL_VERSION)
npcServer:SetAttribute("SupersededBy", nil)
npcServer:SetAttribute("SimpleFourCharacterSystem", true)
npcServer:SetAttribute("PanicEnabled", false)
dialogueServer:SetAttribute("InstallVersion", INSTALL_VERSION)
dialogueServer:SetAttribute("SupersededBy", nil)
dialogueServer:SetAttribute("TalkOptionsOnly", true)

-- Source injection follows the installer. Enabling is safe in edit mode, and
-- ensures the exact restored scripts start on the next playtest.
npcServer.Enabled = true
dialogueServer.Enabled = true
for name, client in pairs(clients) do
	client:SetAttribute("InstallVersion", INSTALL_VERSION)
	client:SetAttribute("SupersededBy", nil)
	client:SetAttribute("RestoredOriginalBehavior", true)
	client.Enabled = true
end

ChangeHistoryService:SetWaypoint("RestoreSimpleCooperCharacters")

print(string.format(
	"[CooperCharactersRollback] Restored four PNG NPC scripts and %d original dialogue/proximity clients; inject the quiet CooperFamilyNPCs source next",
	#requiredClients
))
return true
