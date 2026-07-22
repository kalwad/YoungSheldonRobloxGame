--!nonstrict
-- Edit/runtime audit for the restored original four-character PNG system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local failures = {}
local function check(condition, message)
	if not condition then table.insert(failures, message) end
	return condition
end

local function assetId(value)
	return tonumber(string.match(tostring(value or ""), "(%d+)$")) or 0
end

local expected = {
	George = {
		image = 114737318979057,
		catchphrase = "HotDamn",
		catchphraseId = 123587414049600,
		proximityScript = "CooperGeorgeProximityVoice",
	},
	Mary = {
		image = 109845379583984,
		catchphrase = "LordHaveMercy",
		catchphraseId = 85333334351253,
		proximityScript = "CooperMaryProximityVoice",
	},
	Missy = {
		image = 105870837764920,
		catchphrase = "IncrediblySmart",
		catchphraseId = 133768516435257,
		proximityScript = "CooperMissyProximityVoice",
	},
	Georgie = {
		image = 137011952735257,
		catchphrase = "AnotherDay",
		catchphraseId = 122044176484695,
		proximityScript = "CooperGeorgieProximityVoice",
	},
}

local imageBank = ReplicatedStorage:FindFirstChild("CooperFamilyLocalImages")
local audioBank = ReplicatedStorage:FindFirstChild("CooperFamilyLocalAudio")
check(imageBank and imageBank:IsA("Folder"), "CooperFamilyLocalImages Folder is missing")
check(audioBank and audioBank:IsA("Folder"), "CooperFamilyLocalAudio Folder is missing")
for characterName, definition in pairs(expected) do
	local imageValue = imageBank and imageBank:FindFirstChild(characterName)
	check(imageValue and imageValue:IsA("StringValue"), characterName .. " image StringValue is missing")
	check(imageValue and assetId(imageValue.Value) == definition.image, characterName .. " image ID is wrong")
	local characterAudio = audioBank and audioBank:FindFirstChild(characterName)
	local catchphrase = characterAudio and characterAudio:FindFirstChild(definition.catchphrase)
	check(characterAudio and characterAudio:IsA("Folder"), characterName .. " audio Folder is missing")
	check(catchphrase and catchphrase:IsA("StringValue"), characterName .. " exact proximity catchphrase is missing")
	check(catchphrase and assetId(catchphrase.Value) == definition.catchphraseId, characterName .. " catchphrase ID is wrong")
end

local npcServer = ServerScriptService:FindFirstChild("CooperFamilyNPCs")
local dialogueServer = ServerScriptService:FindFirstChild("CooperFamilyDialogue")
check(npcServer and npcServer:IsA("Script"), "ServerScriptService.CooperFamilyNPCs is missing")
check(dialogueServer and dialogueServer:IsA("Script"), "ServerScriptService.CooperFamilyDialogue is missing")
check(npcServer and npcServer.Enabled, "CooperFamilyNPCs is disabled")
check(dialogueServer and dialogueServer.Enabled, "CooperFamilyDialogue is disabled")
if npcServer and npcServer:IsA("Script") then
	local source = npcServer.Source
	check(not string.find(source, "IdleBubble", 1, true), "CooperFamilyNPCs still creates random IdleBubble text")
	check(not string.find(source, "Panic", 1, true) or string.find(source, "PanicEnabled\", false", 1, true), "CooperFamilyNPCs contains Panic gameplay")
	check(not string.find(source, "PanicEnabled\", true", 1, true), "CooperFamilyNPCs enables Panic gameplay")
	check(string.find(source, "world.Name = \"CooperFamilyNPCs\"", 1, true) ~= nil, "CooperFamilyNPCs source does not own the original world")

	-- The party controller extends the original cutouts; it must not replace the
	-- roster, images, catchphrases, or dialogue system. These source contracts
	-- pin the exact collision-free row and require reversible state ownership.
	check(string.find(source, "local DANCE_ORDER = { \"George\", \"Mary\", \"Missy\", \"Georgie\" }", 1, true) ~= nil, "Boombox dance roster/order changed")
	check(string.find(source, "local DANCE_LINE_LOCAL_X = { 4.6, 8.6, 12.6, 16.6 }", 1, true) ~= nil, "Boombox dance does not use the exact four living-room formation slots")
	check(string.find(source, "local DANCE_LINE_LOCAL_Z = 3.0", 1, true) ~= nil, "Boombox dance row is not at the audited living-room depth")
	check(string.find(source, "floorY = formalFloor.Size.Y * 0.5 + 0.12", 1, true) ~= nil, "Boombox dance roots are not grounded from the formal carpet")
	check(string.find(source, "BoomboxDancing", 1, true) ~= nil, "CooperFamilyNPCs does not expose its dance movement lock")
	check(string.find(source, "GetAttributeChangedSignal(\"Playing\")", 1, true) ~= nil, "CooperFamilyNPCs does not observe the authoritative boombox Playing lifecycle")
	check(string.find(source, "boombox:GetAttribute(\"Playing\") == true", 1, true) ~= nil, "CooperFamilyNPCs does not start formation from boombox Playing")
	check(string.find(source, "rootCFrame = npc.root.CFrame", 1, true) ~= nil, "CooperFamilyNPCs does not snapshot pre-dance root state")
	check(string.find(source, "npc.root.CFrame = snapshot.rootCFrame", 1, true) ~= nil, "CooperFamilyNPCs does not restore the exact pre-dance root state")
	check(string.find(source, "npc.shadow.CFrame = snapshot.shadowCFrame", 1, true) ~= nil, "CooperFamilyNPCs does not restore the exact pre-dance shadow state")
	check(string.find(source, "npc.billboard.StudsOffsetWorldSpace = snapshot.billboardOffset", 1, true) ~= nil, "CooperFamilyNPCs does not restore the exact pre-dance PNG offset")
	check(string.find(source, "restoreTalkPrompt", 1, true) ~= nil, "CooperFamilyNPCs does not restore Talk prompts after dancing")
	check(string.find(source, "local function safeDancePath", 1, true) ~= nil, "Boombox gathering does not use a collision-safe route helper")
	check(string.find(source, "local points = pathTo(npc.root.Position, destination)", 1, true) ~= nil, "Boombox gathering does not use the roaming navigation mesh")
	check(string.find(source, "local function danceGridPath", 1, true) ~= nil, "Boombox gathering has no floor-level furniture detour search")
	check(string.find(source, "DANCE_GRID_MAX_EXPANSIONS", 1, true) ~= nil, "Boombox floor detour search is not bounded")
	check(string.find(source, "DANCE_RUNTIME_REPLANS", 1, true) ~= nil, "Boombox gathering cannot recover from a moving route obstruction")
	check(string.find(source, "dancePathIsClear(npc.root.Position, points :: any)", 1, true) ~= nil, "Boombox gathering trusts navigation-mesh routes without collision validation")
	check(string.find(source, "result.Normal.Y >= 0.6", 1, true) ~= nil, "Boombox floor detours do not require a walkable ground surface")
	check(string.find(source, "surfaceY <= maximumFloorY", 1, true) ~= nil, "Boombox floor detours can still climb onto furniture")
	check(string.find(source, "workspace:Blockcast", 1, true) ~= nil, "Boombox gathering has no collision-tested direct fallback")
	check(string.find(source, "danceCorridorClear(npc.root.Position, nextPosition - npc.root.Position)", 1, true) ~= nil, "Boombox gathering does not recheck moving obstacles on each step")
	check(string.find(source, "local function gatherAlongSafePath", 1, true) ~= nil, "Boombox gathering does not visibly follow its safe path")
	check(string.find(source, "DANCE_GATHER_SPEED", 1, true) ~= nil, "Boombox gathering has no bounded movement speed")
	check(not string.find(source, "snapshot.rootCFrame:Lerp", 1, true), "Boombox gathering can still lerp cutouts directly through walls")
	check(string.find(source, "endpoint.Position.Y - destination.Y", 1, true) ~= nil, "Roaming paths can still terminate on top of furniture")
	check(string.find(source, "targetDestination", 1, true) ~= nil, "Roaming NPCs do not reserve destinations and can stack their PNG cutouts")
	check(string.find(source, "other.targetDestination == routeName", 1, true) ~= nil, "Roaming destination reservations are not enforced across NPCs")
end

if dialogueServer and dialogueServer:IsA("Script") then
	check(string.find(dialogueServer.Source, "BoomboxDancing", 1, true) ~= nil, "Family dialogue does not block Talk sessions while an NPC is dancing")
end

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local dialogueClient = starterScripts and starterScripts:FindFirstChild("CooperFamilyDialogue")
check(dialogueClient and dialogueClient:IsA("LocalScript"), "Original CooperFamilyDialogue client is missing")
check(dialogueClient and dialogueClient.Enabled, "Original CooperFamilyDialogue client is disabled")
if dialogueClient and dialogueClient:IsA("LocalScript") then
	check(string.find(dialogueClient.Source, "Two-stage family dialogue UI ready", 1, true) ~= nil, "The polished two-stage dialogue client was replaced")
	check(string.find(dialogueClient.Source, "audioPlayer:Play()", 1, true) ~= nil, "Dialogue choice response audio is missing")
	check(string.find(dialogueClient.Source, "focusDialogueDefault", 1, true) ~= nil, "Dialogue does not establish an initial controller selection")
	check(string.find(dialogueClient.Source, "GuiService.SelectedObject", 1, true) ~= nil, "Dialogue does not clear and restore controller focus")
	check(string.find(dialogueClient.Source, "Enum.KeyCode.ButtonB", 1, true) ~= nil, "Dialogue cannot be closed with controller B")
end

for characterName, definition in pairs(expected) do
	local client = starterScripts and starterScripts:FindFirstChild(definition.proximityScript)
	check(client and client:IsA("LocalScript"), definition.proximityScript .. " is missing")
	check(client and client.Enabled, definition.proximityScript .. " is disabled")
	if client and client:IsA("LocalScript") then
		check(string.find(client.Source, definition.catchphrase, 1, true) ~= nil, definition.proximityScript .. " does not use the exact catchphrase")
		check(string.find(client.Source, "ENTER_DISTANCE = 10", 1, true) ~= nil, definition.proximityScript .. " enter distance changed")
		check(string.find(client.Source, "EXIT_DISTANCE = 14", 1, true) ~= nil, definition.proximityScript .. " exit distance changed")
		check(string.find(client.Source, "COOLDOWN_SECONDS = 18", 1, true) ~= nil, definition.proximityScript .. " cooldown changed")
		check(string.find(client.Source, "InConversation", 1, true) ~= nil, definition.proximityScript .. " does not suppress catchphrases during Talk")
		check(string.find(client.Source, "BoomboxDancing", 1, true) ~= nil, definition.proximityScript .. " does not suppress its catchphrase during the boombox dance")
		check(string.find(client.Source, "CooperFamilyLocalAudio", 1, true) ~= nil, definition.proximityScript .. " no longer reads the preserved catchphrase audio bank")
	end
end

local familyClient = starterScripts and starterScripts:FindFirstChild("CooperGame")
check(familyClient and familyClient:IsA("LocalScript"), "StarterPlayerScripts.CooperGame boombox/dance client is missing")
check(familyClient and familyClient.Enabled, "StarterPlayerScripts.CooperGame is disabled")
if familyClient and familyClient:IsA("LocalScript") then
	local source = familyClient.Source
	check(string.find(source, "local danceRoster = { \"George\", \"Mary\", \"Missy\", \"Georgie\" }", 1, true) ~= nil, "Client dance roster is not the exact four original PNG characters")
	check(string.find(source, "sound.TimePosition", 1, true) ~= nil, "Client dance is not synchronized to the playing Sound.TimePosition")
	check(string.find(source, "Config.Boombox.DanceBPM", 1, true) ~= nil and string.find(source, "or 130", 1, true) ~= nil, "Client dance does not retain the 130-BPM beat contract")
	check(string.find(source, "name == \"George\" or name == \"Missy\"", 1, true) ~= nil, "Client dance first alternating pair is not George and Missy")
	check(string.find(source, "beatIndex % 2", 1, true) ~= nil, "Client dance does not alternate its two jump pairs by beat")
	check(string.find(source, "math.sin(math.pi * beatPhase)", 1, true) ~= nil, "Client dance no longer uses a smooth beat-locked jump arc")
	check(string.find(source, "BoomboxDancing", 1, true) ~= nil, "Client dance ignores the server-owned NPC dance lock")
end

local interactionServer = ServerScriptService:FindFirstChild("CooperInteractions")
check(interactionServer and interactionServer:IsA("Script"), "ServerScriptService.CooperInteractions is missing")
if interactionServer and interactionServer:IsA("Script") then
	local source = interactionServer.Source
	local promptBlockStart = string.find(source, "descendant:IsA(\"ProximityPrompt\") and descendant.Name == \"TalkPrompt\"", 1, true)
	check(promptBlockStart ~= nil, "CooperInteractions computer-priority TalkPrompt block is missing")
	if promptBlockStart then
		local promptBlock = string.sub(source, promptBlockStart, math.min(#source, promptBlockStart + 2200))
		local danceGate = string.find(promptBlock, "BoomboxDancing", 1, true)
		local reenabling = string.find(promptBlock, "descendant.Enabled = true", 1, true)
		check(danceGate ~= nil and reenabling ~= nil and danceGate < reenabling, "CooperInteractions can re-enable a TalkPrompt while its NPC is dancing")
	end
end

-- The advanced replacement must be completely absent, not merely disabled.
local environment = workspace:FindFirstChild("CooperHouseEnvironment")
check(not ServerScriptService:FindFirstChild("CooperCharacters"), "Advanced CooperCharacters server still exists")
check(not ServerScriptService:FindFirstChild("CooperCharacterServerEvents"), "Panic/brisket server events still exist")
check(not ReplicatedStorage:FindFirstChild("CooperCharacters"), "Advanced CooperCharacters replicated root still exists")
check(not (starterScripts and starterScripts:FindFirstChild("CooperCharacters")), "Advanced CooperCharacters HUD client still exists")
check(not (environment and environment:FindFirstChild("CooperCharacters")), "Advanced CooperCharacters card/Panic world still exists")

local world = environment and environment:FindFirstChild("CooperFamilyNPCs")
if RunService:IsRunning() then
	local deadline = os.clock() + 12
	while not world and os.clock() < deadline do
		task.wait(0.1)
		world = environment and environment:FindFirstChild("CooperFamilyNPCs")
	end
	check(world and world:IsA("Folder"), "Runtime CooperFamilyNPCs world did not start")
	if world then
		local modelCount = 0
		for _, child in ipairs(world:GetChildren()) do
			if child:IsA("Model") then modelCount += 1 end
		end
		check(modelCount == 4, "Runtime roster is not exactly four characters")
		check(world:GetAttribute("PanicEnabled") == false, "Runtime NPC world has Panic enabled")
	end
end

if world then
	for characterName, definition in pairs(expected) do
		local model = world:FindFirstChild(characterName)
		check(model and model:IsA("Model"), characterName .. " PNG model is missing")
		if model then
			local rootPart = model:FindFirstChild("Root")
			local shadow = model:FindFirstChild("GroundShadow")
			local cutout = rootPart and rootPart:FindFirstChild("Cutout")
			local image = cutout and cutout:FindFirstChild("CharacterImage")
			check(rootPart and rootPart:IsA("BasePart") and rootPart.Transparency == 1, characterName .. " invisible root is malformed")
			check(shadow and shadow:IsA("BasePart"), characterName .. " ground shadow is missing")
			check(cutout and cutout:IsA("BillboardGui"), characterName .. " pure BillboardGui cutout is missing")
			check(image and image:IsA("ImageLabel"), characterName .. " CharacterImage is missing")
			check(image and image.BackgroundTransparency == 1 and image.ScaleType == Enum.ScaleType.Fit, characterName .. " image is not a transparent Fit cutout")
			check(image and assetId(image.Image) == definition.image, characterName .. " runtime image ID is wrong")
			check(type(model:GetAttribute("BoomboxDancing")) == "boolean", characterName .. " runtime dance lock is missing")
			check(not model:FindFirstChildWhichIsA("TextLabel", true), characterName .. " still has a card/nameplate/idle text label")
			check(not model:FindFirstChild("IdleBubble", true), characterName .. " still has IdleBubble")
		end
	end
	for _, child in ipairs(world:GetChildren()) do
		if child:IsA("Model") then
			check(expected[child.Name] ~= nil, "Unwanted extra NPC exists: " .. child.Name)
		end
	end
end

if RunService:IsRunning() then
	local dialogueRoot = ReplicatedStorage:FindFirstChild("CooperFamilyDialogue")
	check(dialogueRoot and dialogueRoot:FindFirstChild("Session") and dialogueRoot.Session:IsA("RemoteEvent"), "Dialogue Session remote did not start")
	for _, player in ipairs(Players:GetPlayers()) do
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		check(not playerGui or not playerGui:FindFirstChild("CooperCharactersHUD"), "A player still has the advanced Panic/quote HUD")
	end
end

if #failures > 0 then
	error("[CooperCharactersRollbackAudit] FAIL\n - " .. table.concat(failures, "\n - "), 0)
end

print(string.format(
	"[CooperCharactersRollbackAudit] PASS: exact four PNG roster/catchphrases/dialogue plus reversible 130-BPM boombox dance, runtime=%s",
	tostring(RunService:IsRunning())
))
return true
