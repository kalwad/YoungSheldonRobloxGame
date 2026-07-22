--!nonstrict
-- Read-only Studio edit/runtime audit for Milestone 1: Lobby and Co-op.
--
-- Run this file in BOTH the house place and the dedicated lobby place. It does
-- not create, destroy, reparent, rename, save, teleport, invoke a Remote, or
-- write MemoryStore/DataStore data. Cross-place and disconnect behavior still
-- requires the human scenarios in MILESTONE1_TEST_MATRIX.md.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local running = RunService:IsRunning()
local failures = {}
local advisories = {}
local checkCount = 0

local EXPECTED_UNIVERSE_ID = 10480337589
local EXPECTED_LOBBY_PLACE_ID = 100748614383412
local EXPECTED_HOUSE_PLACE_ID = 98645411943406
local MINIMUM_LOBBY_CAPACITY = 4
local RECOMMENDED_LOBBY_CAPACITY = 50

local function check(condition, message)
	checkCount += 1
	if not condition then
		table.insert(failures, message)
	end
	return condition
end

local function advise(condition, message)
	if not condition then
		table.insert(advisories, message)
	end
end

local function contains(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local function lacks(source, marker, label)
	check(not contains(source, marker), (label or "Source") .. " unexpectedly contains " .. marker)
end

local function markers(source, label, expected)
	for _, marker in ipairs(expected) do
		check(contains(source, marker), label .. " is missing source contract marker: " .. marker)
	end
end

local function functionSection(source, functionName)
	local startMarker = "local function " .. functionName .. "("
	local startAt = type(source) == "string" and string.find(source, startMarker, 1, true) or nil
	if not startAt then
		return nil
	end
	local endAt = string.find(source, "\nlocal function ", startAt + #startMarker, true)
		or string.find(source, "\nreturn ", startAt + #startMarker, true)
		or (#source + 1)
	return string.sub(source, startAt, endAt - 1)
end

local function sourceOf(instance, label)
	check(instance ~= nil, label .. " is missing")
	if not instance then
		return nil
	end
	check(instance:IsA("LuaSourceContainer"), label .. " must contain Luau source")
	if not instance:IsA("LuaSourceContainer") then
		return nil
	end
	if instance:IsA("BaseScript") then
		check(instance.Enabled == true, label .. " is disabled")
	end
	local ok, source = pcall(function()
		return instance.Source
	end)
	check(ok and type(source) == "string", label .. ".Source is unreadable from this context")
	if not ok or type(source) ~= "string" then
		return nil
	end
	check(#source > 100, label .. " has empty or placeholder source")
	return source
end

local function loadDataModule(module, label)
	local source = sourceOf(module, label)
	if not source then
		return nil, source
	end
	local ok, result
	if not running and type(loadstring) == "function" then
		local compileOk, chunkOrError = pcall(loadstring, source, label .. "Audit")
		if compileOk and type(chunkOrError) == "function" then
			ok, result = pcall(chunkOrError)
		else
			ok, result = false, chunkOrError
		end
	else
		ok, result = pcall(require, module)
	end
	check(ok and type(result) == "table", label .. " did not return a table: " .. tostring(result))
	return ok and type(result) == "table" and result or nil, source
end

local function directChild(parent, name, className, label)
	local child = parent and parent:FindFirstChild(name) or nil
	check(child ~= nil, label or ((parent and parent:GetFullName() or "<missing>") .. " is missing " .. name))
	if child and className then
		check(child:IsA(className), child:GetFullName() .. " must be a " .. className)
	end
	return child
end

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
check(starterScripts and starterScripts:IsA("StarterPlayerScripts"), "StarterPlayerScripts is missing")

local houseRoot = ReplicatedStorage:FindFirstChild("CooperGame")
local lobbyRoot = ReplicatedStorage:FindFirstChild("CooperLobby")
local isHouse = houseRoot and houseRoot:IsA("Folder")
local isLobby = lobbyRoot and lobbyRoot:IsA("Folder")
check(isHouse ~= isLobby, "Install exactly one Milestone 1 place role: house OR lobby")
local placeRole = isHouse and "house" or (isLobby and "lobby" or "unknown")

-- Shared, server-validated teleport protocol -------------------------------

local protocolModule = directChild(ReplicatedStorage, "CooperPartyProtocol", "ModuleScript")
local Protocol, protocolSource = loadDataModule(protocolModule, "ReplicatedStorage.CooperPartyProtocol")
if Protocol then
	check(table.isfrozen(Protocol), "CooperPartyProtocol must be frozen")
	check(Protocol.VERSION == 1, "CooperPartyProtocol.VERSION must be 1")
	check(Protocol.MAX_PARTY_SIZE == 4, "CooperPartyProtocol.MAX_PARTY_SIZE must be 4")
	check(Protocol.HOUSE_TELEPORT_KIND == "CooperHouseSession", "House teleport kind changed")
	check(Protocol.INVITE_LAUNCH_KIND == "CooperPartyInvite", "Invite launch kind changed")
	check(type(Protocol.validateHouseTeleportData) == "function", "Protocol lacks destination validation")
	check(type(Protocol.makeHouseTeleportData) == "function", "Protocol lacks house teleport-data construction")
	check(type(Protocol.parseInviteLaunchData) == "function", "Protocol lacks invitation validation")
	check(type(Protocol.containsMember) == "function", "Protocol lacks membership validation")

	local memoryStoreNames = Protocol.MemoryStoreNames
	check(type(memoryStoreNames) == "table" and table.isfrozen(memoryStoreNames), "Protocol.MemoryStoreNames must be frozen")
	local uniqueMapNames = {}
	local mapCount = 0
	if type(memoryStoreNames) == "table" then
		for _, mapName in pairs(memoryStoreNames) do
			mapCount += 1
			check(type(mapName) == "string" and mapName ~= "", "MemoryStore map name must be nonempty")
			check(uniqueMapNames[mapName] == nil, "MemoryStore map names must be unique: " .. tostring(mapName))
			uniqueMapNames[mapName] = true
		end
	end
	check(mapCount == 6, "Protocol must declare six distinct MemoryStore maps")
	check(memoryStoreNames and memoryStoreNames.Parties == "CooperPartyLobbyParties_v1", "Canonical party map name changed")
	check(memoryStoreNames and memoryStoreNames.Invites == "CooperPartyInvites_v1", "Canonical invite map name changed")
	check(memoryStoreNames and memoryStoreNames.Memberships == "CooperPartyMemberships_v1", "Canonical membership map name changed")
	check(memoryStoreNames and memoryStoreNames.Tickets == "CooperPartyLaunchTickets_v1", "Canonical ticket map name changed")
	check(memoryStoreNames and memoryStoreNames.Sessions == "CooperPartySessions_v1", "Canonical session map name changed")
	check(memoryStoreNames and memoryStoreNames.Rejoins == "CooperPartyRejoin_v1", "Canonical rejoin map name changed")

	-- Execute the pure payload validator. This proves party size, membership,
	-- duplicate-ID, and expiry checks rather than merely finding their names.
	local nowUnix = 2_000_000_000
	local ids = {
		sessionId = "session_0123456789abcdef0123456789abcdef",
		partyId = "party_0123456789abcdef0123456789abcdef",
		ticketId = "ticket_0123456789abcdef0123456789abcdef",
	}
	local madeOk, validPayload = pcall(
		Protocol.makeHouseTeleportData,
		ids.sessionId,
		ids.partyId,
		ids.ticketId,
		101,
		{ 101, 202, 303, 404 },
		nowUnix - 1,
		nowUnix + 120
	)
	check(madeOk and type(validPayload) == "table", "Protocol could not construct a four-player payload")
	if madeOk and type(validPayload) == "table" then
		local validated, validationError = Protocol.validateHouseTeleportData(validPayload, 404, nowUnix)
		check(validated ~= nil and validationError == nil, "Valid member payload was rejected: " .. tostring(validationError))
		local nonmember = Protocol.validateHouseTeleportData(validPayload, 505, nowUnix)
		check(nonmember == nil, "Nonmember teleport data was accepted")

		local expired = table.clone(validPayload)
		expired.expiresAt = nowUnix
		check(Protocol.validateHouseTeleportData(expired, 101, nowUnix) == nil, "Expired teleport data was accepted")
		local duplicates = table.clone(validPayload)
		duplicates.memberUserIds = { 101, 202, 202 }
		check(Protocol.validateHouseTeleportData(duplicates, 101, nowUnix) == nil, "Duplicate party membership was accepted")
		local oversized = table.clone(validPayload)
		oversized.memberUserIds = { 101, 202, 303, 404, 505 }
		check(Protocol.validateHouseTeleportData(oversized, 101, nowUnix) == nil, "A five-player party was accepted")

		for key in pairs(validPayload) do
			local normalized = string.lower(tostring(key))
			check(not string.find(normalized, "accesscode", 1, true), "TeleportData exposed an access-code field")
			check(not string.find(normalized, "reservedserver", 1, true), "TeleportData exposed a reserved-server field")
		end
	end
end
if protocolSource then
	markers(protocolSource, "CooperPartyProtocol", {
		"TeleportData and LaunchData are hints, never authority.",
		"Reserved-server access codes are deliberately absent",
		"function Protocol.validateHouseTeleportData(",
		"if not Protocol.containsMember(memberUserIds, arrivingUserId) then",
		"if value.expiresAt <= nowUnix then",
	})
end

-- No client is permitted to become a reward, task, party-authority, or
-- movement-authority source. These exact request names are deliberately more
-- specific than UI words such as "TaskComplete" in feedback listeners.
for _, root in ipairs({ starterScripts, StarterGui }) do
	if root then
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("LocalScript") then
				local clientSource = sourceOf(descendant, descendant:GetFullName())
				if clientSource then
					for _, forbidden in ipairs({
						':FireServer("CompleteTask"',
						':InvokeServer("CompleteTask"',
						':FireServer("AwardAllowance"',
						':InvokeServer("AwardAllowance"',
						':FireServer("SetAllowance"',
						':InvokeServer("SetAllowance"',
						':FireServer("AdjustAllowance"',
						':InvokeServer("AdjustAllowance"',
						'leaderstats.Allowance.Value =',
						'SetAttribute("PartyHostUserId"',
						'SetAttribute("CooperStamina"',
						'GetService("MemoryStoreService")',
						':TeleportAsync(',
					}) do
						lacks(clientSource, forbidden, descendant:GetFullName())
					end
				end
			end
		end
	end
end

-- Retired panic/crisis/progression content stays absent in both places.
for _, specification in ipairs({
	{ ReplicatedStorage, "CooperProgression" },
	{ ReplicatedStorage, "CooperCrisis" },
	{ ServerScriptService, "CooperProgression" },
	{ ServerScriptService, "CooperProgressionServerEvents" },
	{ ServerScriptService, "CooperCrisis" },
	{ ServerScriptService, "CooperCrisisServerEvents" },
	{ starterScripts, "CooperProgression" },
	{ starterScripts, "CooperCrisisClient" },
	{ StarterGui, "CooperProgressionHUD" },
	{ StarterGui, "CooperCrisisHUD" },
	{ Workspace, "CooperFutureApartment" },
	{ Lighting, "CooperCharacterPanicColor" },
	{ SoundService, "CrisisAlert" },
	{ SoundService, "PanicWarningAudio" },
}) do
	local parent, name = specification[1], specification[2]
	check(not parent or parent:FindFirstChild(name) == nil, "Retired runtime object remains: " .. name)
end

if isHouse then
	-- House config and unchanged pre-horror content -------------------------
	local configModule = directChild(houseRoot, "Config", "ModuleScript")
	local state = directChild(houseRoot, "State", "Folder")
	local Config, configSource = loadDataModule(configModule, "ReplicatedStorage.CooperGame.Config")
	if Config then
		check(Config.SchemaVersion == 11, "Milestone 1 must preserve profile schema 11")
		check(Config.DataStoreName == "CooperFamilyTasks_v2", "Milestone 1 must retain the production DataStore")
		check(Config.ReleasePlayerCap == 4, "House release cap must be four")

		local expectedFeatures = {
			Lobby = true,
			Horror = false,
			SecretExploration = false,
			TimeMachineFinale = false,
			Postgame = false,
			StudioScenarioTools = false,
		}
		local featureCount = 0
		check(type(Config.Features) == "table" and table.isfrozen(Config.Features), "Config.Features must be frozen")
		if type(Config.Features) == "table" then
			for featureName, value in pairs(Config.Features) do
				featureCount += 1
				check(expectedFeatures[featureName] ~= nil, "Unexpected feature flag: " .. tostring(featureName))
				check(value == expectedFeatures[featureName], "Incorrect Milestone 1 feature value: " .. tostring(featureName))
			end
		end
		check(featureCount == 6, "Config.Features must contain exactly six flags")

		local expectedTaskOrder = { "GeorgeBeer", "MaryDishes", "MaryTrash", "MissyPlush", "MedfordBankHack" }
		check(type(Config.Tasks) == "table" and #Config.Tasks == 5, "House must retain exactly five tasks")
		check(type(Config.TaskOrder) == "table" and #Config.TaskOrder == 5, "TaskOrder must retain exactly five tasks")
		for index, taskId in ipairs(expectedTaskOrder) do
			check(Config.Tasks[index] and Config.Tasks[index].id == taskId, "Task definition order changed at " .. index)
			check(Config.TaskOrder[index] == taskId, "TaskOrder changed at " .. index)
		end
		check(type(Config.MachineStages) == "table" and #Config.MachineStages == 11, "House must retain eleven machine stages")
		for stage = 1, 11 do
			check(Config.MachineStages[stage] and Config.MachineStages[stage].stage == stage, "Machine stage is missing/out of order: " .. stage)
		end

		check(type(Config.Party) == "table" and table.isfrozen(Config.Party), "Config.Party must be frozen")
		check(Config.Party and Config.Party.ProtocolVersion == 1, "Party protocol version must be 1")
		check(Config.Party and Config.Party.MaxMembers == 4, "Party max must be four")
		check(Config.Party and Config.Party.HostReconnectGraceSeconds == 60, "Host grace must be exactly 60 seconds")
		check(Config.Party and Config.Party.HostOnlyPersistentPurchases == true, "Persistent world purchases must be host-only")
		check(Config.Party and Config.Party.LobbyPlaceId == EXPECTED_LOBBY_PLACE_ID, "House config must route back to the published lobby place")
		check(Config.Party and Config.Party.HousePlaceId == EXPECTED_HOUSE_PLACE_ID, "House place ID changed")
		check(Config.Party and Config.Party.LobbyPlaceId ~= Config.Party.HousePlaceId, "Lobby and house must be different places")
		check(Config.Party and Protocol and Config.Party.TicketMapName == Protocol.MemoryStoreNames.Tickets, "House ticket map must match CooperPartyProtocol")
		check(Config.Party and Protocol and Config.Party.SessionMapName == Protocol.MemoryStoreNames.Sessions, "House session map must match CooperPartyProtocol")
		check(Config.Party and Protocol and Config.Party.RejoinMapName == Protocol.MemoryStoreNames.Rejoins, "House rejoin map must match CooperPartyProtocol")

		check(type(Config.Movement) == "table" and table.isfrozen(Config.Movement), "Config.Movement must be frozen")
		check(Config.Movement and Config.Movement.WalkSpeed == 16, "Walk speed must be 16")
		check(Config.Movement and Config.Movement.SprintSpeed == 22, "Sprint speed must be 22")
		check(Config.Movement and Config.Movement.SprintStaminaSeconds == 6, "Sprint stamina must be six seconds")
	end

	if game.PlaceId > 0 then
		check(game.PlaceId == EXPECTED_HOUSE_PLACE_ID, "House content is installed in the wrong place: " .. tostring(game.PlaceId))
	end
	if game.GameId > 0 then
		check(game.GameId == EXPECTED_UNIVERSE_ID, "House is outside the configured universe")
	end
	if RunService:IsStudio() then
		-- An already-open edit DataModel can retain a stale, read-only MaxPlayers
		-- cache. The frozen config is testable here; the Dashboard value remains a
		-- mandatory evidence row in MILESTONE1_TEST_MATRIX.md.
		check(Config and Config.ReleasePlayerCap == 4, "House release contract must remain exactly four")
		advise(Players.MaxPlayers == 4, "Studio reports house MaxPlayers=" .. tostring(Players.MaxPlayers)
			.. "; confirm the Creator Dashboard maximum visitor count is exactly 4")
	else
		check(Players.MaxPlayers == 4, "Published house capacity must be exactly four; current MaxPlayers is " .. tostring(Players.MaxPlayers))
	end

	local gameServer = directChild(ServerScriptService, "CooperGame", "Script")
	local gameServerSource = sourceOf(gameServer, "ServerScriptService.CooperGame")
	if gameServerSource then
		markers(gameServerSource, "CooperGame", {
			"M1_SHARED_TASK_SESSION_CONTRACT",
			"M1_HOST_ONLY_PURCHASE_GUARD",
			"M1_HOST_RECONNECT_GRACE_CONTRACT",
			"FoundationContract\", \"PartyV1",
			"PartySessionId",
			"PartyHostUserId",
			"PartyState",
			"PartyMemberCount",
			"HostGraceDeadline",
			"GetJoinData()",
			"Protocol.validateHouseTeleportData",
			"Protocol.MemoryStoreNames.Tickets",
			"Protocol.MemoryStoreNames.Sessions",
			"MemoryStoreService",
			"HostReconnectGraceSeconds",
			"partySession.state = \"HostGrace\"",
			"partySession.hostGraceDeadline = partySession.pausedAt + partyConfig.HostReconnectGraceSeconds",
			"task.delay(partyConfig.HostReconnectGraceSeconds, function()",
			"syncSessionManifest(\"HostGrace\", partySession.hostGraceUnixExpiresAt)",
			"syncSessionManifest(\"InHouse\", 0)",
			"syncSessionManifest(\"Closed\", 0)",
			"returnSavedPartyToLobby(savedPlayers)",
			"retained.detached ~= true",
			"tonumber(ticket.userId) ~= player.UserId",
			"if ticket.consumedByJobId ~= nil or ticket.consumedAt ~= nil then",
			"local claimNonce = Protocol.newOpaqueId(\"claim\")",
			"result.consumedClaimNonce ~= claimNonce",
			"manifest.expiresAt = renewedExpiresAt",
			"for userId, player in pairs(partySession.activePlayers) do",
			"local occupiedSlot = partySession.activePlayers[player.UserId]",
			"retained.loaded ~= true",
			"recoverHostWorldState(retained, player)",
			"closePartyAndReturn(",
			"reconnectRemaining",
			"cycleIndex",
			"rewardedUserIds = {}",
			"record.status = \"Completing\"",
			"local recipients = presentProfiles()",
			"if record.rewardedUserIds[userId] ~= true then",
			"setAllowance(recipient, recipient.data.allowance + reward)",
			"partySession.completedTasks += 1",
			"math.floor(partySession.completedTasks / #Config.TaskOrder) + 1",
			"partySession.task = nil",
			"local worldProfile = hostProfile()",
			"delivery = deliverySnapshot(worldProfile, profile)",
			"boombox = boomboxSnapshot(worldProfile, profile)",
			"secretBunker = secretBunkerSnapshot(worldProfile, profile)",
			"chemistrySetup = chemistrySetupSnapshot(worldProfile, profile)",
			"automation = automationSnapshot(worldProfile, profile)",
		})

		-- A profile-local task can silently split the party scheduler or duplicate
		-- rewards. Persistent delivery fields named taskUpgrade remain valid.
		for _, retiredPersonalTaskMarker in ipairs({
			"local record = profile.task",
			"local activeTask = profile.task",
			"not profile.task and",
			"profile.task ~= bankSession.record",
			"profile.taskCursor =",
			"profile.nextTaskAt",
		}) do
			lacks(gameServerSource, retiredPersonalTaskMarker, "CooperGame shared scheduler")
		end

		local purchaseFunctions = {
			"orderMachinePart",
			"orderBoombox",
			"upgradeBoomboxAutoplay",
			"orderTaskUpgrade",
			"orderSecretBunker",
			"orderChemistrySetup",
		}
		for _, purchaseFunction in ipairs(purchaseFunctions) do
			local section = functionSection(gameServerSource, purchaseFunction)
			check(section ~= nil, "Host-gated purchase function is missing: " .. purchaseFunction)
			if section then
				check(
					contains(section, "hostMutationAllowed(profile)"),
					purchaseFunction .. " must invoke the shared host/progression guard before mutation"
				)
				local guardAt = string.find(section, "hostMutationAllowed(profile)", 1, true)
				local debitAt = string.find(section, "setAllowance(profile, profile.data.allowance -", 1, true)
				check(
					guardAt ~= nil and (debitAt == nil or guardAt < debitAt),
					purchaseFunction .. " must authorize the host before any allowance debit"
				)
			end
		end
		lacks(gameServerSource, "FeatureHorrorEnabled\", true", "CooperGame")
	end

	local movementServer = directChild(ServerScriptService, "CooperMovement", "Script")
	local movementSource = sourceOf(movementServer, "ServerScriptService.CooperMovement")
	if movementSource then
		markers(movementSource, "CooperMovement", {
			"local WALK_SPEED = 16",
			"local SPRINT_SPEED = 22",
			"local MAX_STAMINA = 6",
			"local REMOTES_NAME = \"CooperMovementRemotes\"",
			"local INTENT_EVENT_NAME = \"SprintIntent\"",
			"local API_NAME = \"CooperMovementAPI\"",
			"RunService.Heartbeat",
			"humanoid.MoveDirection",
			"humanoid.SeatPart",
			"INTENT_BUCKET_CAPACITY",
			"CooperMovementLocked",
			"CooperCarrySpeedMultiplier",
			"CooperComputerSessionUntil",
			"CooperBunkerComputerSessionUntil",
		})
		lacks(movementSource, "OnServerEvent:Connect(function(player, stamina", "CooperMovement")
	end
	for _, consumerName in ipairs({ "CooperTaskWorld", "CooperInteractions" }) do
		local consumer = directChild(ServerScriptService, consumerName, "Script")
		local consumerSource = sourceOf(consumer, "ServerScriptService." .. consumerName)
		if consumerSource then
			lacks(consumerSource, "humanoid.WalkSpeed =", "ServerScriptService." .. consumerName)
			check(
				contains(consumerSource, "CooperMovementAPI"),
				"ServerScriptService." .. consumerName .. " must compose movement through CooperMovementAPI"
			)
			if consumerName == "CooperTaskWorld" then
				local activeTaskSource = functionSection(consumerSource, "activeTask")
				check(activeTaskSource ~= nil, "CooperTaskWorld.activeTask is missing")
				if activeTaskSource then
					check(
						contains(activeTaskSource, 'current.party.state ~= "Active"'),
						"CooperTaskWorld must reject task prompts while host-grace pauses the party"
					)
				end
				markers(consumerSource, "CooperTaskWorld host-grace commits", {
					'if invokeFamily("ReportAction", player, "TrashDelivered", {}) == true then',
					'if fridge and invokeFamily("ReportAction", player, "BeerDelivered", {}) == true then',
					"The party may have paused between validation and commit.",
				})
			end
		end
	end

	local sprintClient = directChild(starterScripts, "CooperSprint", "LocalScript")
	local sprintSource = sourceOf(sprintClient, "StarterPlayer.StarterPlayerScripts.CooperSprint")
	if sprintSource then
		markers(sprintSource, "CooperSprint", {
			"ContextActionService",
			"Enum.KeyCode.LeftShift",
			"Enum.KeyCode.RightShift",
			"Enum.ScreenInsets.CoreUISafeInsets",
			"CooperStamina",
			"CooperStaminaMax",
			"CooperSprinting",
			"TOUCH_BUTTON_SIZE = 64",
			"ContextActionService:BindActionAtPriority(",
			"staminaCard.Visible = not blockedByWorld and (sprinting or stamina < staminaMax - 0.01)",
		})
		lacks(sprintSource, "humanoid.WalkSpeed =", "CooperSprint client")
	end

	if running then
		local partyDeadline = os.clock() + 15
		while os.clock() < partyDeadline
			and (state:GetAttribute("FoundationContract") ~= "PartyV1"
				or (tonumber(state:GetAttribute("PartyMemberCount")) or 0) < 1)
		do
			task.wait(0.1)
		end
		check(state:GetAttribute("FoundationContract") == "PartyV1", "Runtime foundation contract must be PartyV1")
		check(state:GetAttribute("FeatureLobbyEnabled") == true, "Runtime lobby feature must be enabled")
		for _, attributeName in ipairs({
			"FeatureHorrorEnabled",
			"FeatureSecretExplorationEnabled",
			"FeatureTimeMachineFinaleEnabled",
			"FeaturePostgameEnabled",
			"FeatureStudioScenarioToolsEnabled",
		}) do
			check(state:GetAttribute(attributeName) == false, attributeName .. " must remain false")
		end
		check(state:GetAttribute("ReleasePlayerCap") == 4, "Runtime release cap attribute must be four")
		check(type(state:GetAttribute("PartySessionId")) == "string" and state:GetAttribute("PartySessionId") ~= "", "Runtime party session ID is missing")
		check(type(state:GetAttribute("PartyHostUserId")) == "number" and state:GetAttribute("PartyHostUserId") > 0, "Runtime party host is missing")
		check(type(state:GetAttribute("PartyState")) == "string", "Runtime party state is missing")
		check(type(state:GetAttribute("PartyMemberCount")) == "number" and state:GetAttribute("PartyMemberCount") >= 1 and state:GetAttribute("PartyMemberCount") <= 4, "Runtime party member count is invalid")
		check(type(state:GetAttribute("HostGraceDeadline")) == "number", "Runtime host grace deadline attribute is missing")

		local movementRemotes = directChild(ReplicatedStorage, "CooperMovementRemotes", "Folder")
		directChild(movementRemotes, "SprintIntent", "RemoteEvent")
		check(movementRemotes:GetAttribute("WalkSpeed") == 16, "Movement remotes must advertise walk speed 16")
		check(movementRemotes:GetAttribute("SprintSpeed") == 22, "Movement remotes must advertise sprint speed 22")
		check(movementRemotes:GetAttribute("SprintStaminaSeconds") == 6, "Movement remotes must advertise six-second stamina")
		check(movementRemotes:GetAttribute("ServerAuthoritative") == true, "Movement remotes must advertise server authority")
		local movementAPI = directChild(ServerScriptService, "CooperMovementAPI", "Folder")
		check(movementAPI:GetAttribute("ContractVersion") == 1, "Movement server API contract must be v1")
		directChild(movementAPI, "SetLock", "BindableFunction")
		directChild(movementAPI, "SetSpeedMultiplier", "BindableFunction")
		directChild(movementAPI, "ReleaseSource", "BindableEvent")
		directChild(movementAPI, "StateChanged", "BindableEvent")
		for _, player in ipairs(Players:GetPlayers()) do
			local movementDeadline = os.clock() + 10
			while player.Parent == Players
				and player:GetAttribute("CooperMovementReady") ~= true
				and os.clock() < movementDeadline
			do
				task.wait(0.1)
			end
			check(player:GetAttribute("CooperMovementReady") == true, player.Name .. " movement is not ready")
			check(type(player:GetAttribute("CooperStamina")) == "number", player.Name .. " has no server stamina")
			check(player:GetAttribute("CooperStaminaMax") == 6, player.Name .. " stamina max must be six")
			check(type(player:GetAttribute("CooperSprinting")) == "boolean", player.Name .. " sprint state is missing")
		end
	end

	-- Exactly four approved normal cutout family NPCs. M1 does not introduce
	-- Sheldon, Billy, Mandy, Meemaw, cards, or horror art.
	local approved = { George = true, Mary = true, Missy = true, Georgie = true }
	local approvedOrder = { "George", "Mary", "Missy", "Georgie" }
	local npcServer = directChild(ServerScriptService, "CooperFamilyNPCs", "Script")
	local npcSource = sourceOf(npcServer, "ServerScriptService.CooperFamilyNPCs")
	if npcSource then
		local definitionsAt = string.find(npcSource, "local definitions = {", 1, true)
		local definitionsEnd = definitionsAt and string.find(npcSource, "local randomizer = Random.new()", definitionsAt, true) or nil
		check(definitionsAt ~= nil and definitionsEnd ~= nil, "Family NPC definition boundaries are missing")
		if definitionsAt and definitionsEnd then
			local section = string.sub(npcSource, definitionsAt, definitionsEnd - 1)
			local foundNames = {}
			for characterName in string.gmatch(section, 'name%s*=%s*"([^"]+)"') do
				table.insert(foundNames, characterName)
			end
			check(#foundNames == 4, "CooperFamilyNPCs must define exactly four NPCs")
			for index, characterName in ipairs(approvedOrder) do
				check(foundNames[index] == characterName, "Family NPC order changed at position " .. index)
			end
		end
		lacks(npcSource, "HorrorMode", "CooperFamilyNPCs")
	end
	local imageFolder = ReplicatedStorage:FindFirstChild("CooperFamilyLocalImages")
	check(imageFolder and imageFolder:IsA("Folder"), "CooperFamilyLocalImages is missing")
	if imageFolder then
		local count = 0
		for _, child in ipairs(imageFolder:GetChildren()) do
			count += 1
			check(child:IsA("StringValue") and approved[child.Name] == true, "Unapproved family image entry: " .. child.Name)
		end
		check(count == 4, "There must be exactly four normal family image entries")
	end
	local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
	check(environment and environment:IsA("Model"), "CooperHouseEnvironment is missing")
	local npcWorld = environment and environment:FindFirstChild("CooperFamilyNPCs")
	if running and not npcWorld then
		local deadline = os.clock() + 12
		while not npcWorld and os.clock() < deadline do
			task.wait(0.1)
			npcWorld = environment and environment:FindFirstChild("CooperFamilyNPCs")
		end
	end
	if running then
		check(npcWorld and npcWorld:IsA("Folder"), "Runtime family NPC folder did not start")
	end
	if npcWorld then
		local count = 0
		for _, child in ipairs(npcWorld:GetChildren()) do
			if child:IsA("Model") then
				count += 1
				check(approved[child.Name] == true, "Unapproved runtime NPC: " .. child.Name)
				check(child:GetAttribute("Cooper2DCharacter") == true, child.Name .. " is not a 2D cutout")
				check(not child:FindFirstChildWhichIsA("TextLabel", true), child.Name .. " has a forbidden text card")
			end
		end
		check(count == 4, "Runtime must contain exactly four family NPC models")
	end
elseif isLobby then
	-- Dedicated lobby place --------------------------------------------------
	local lobbyEnvironment = directChild(Workspace, "CooperPartyLobbyEnvironment", "Model")
	check(Workspace:FindFirstChild("CooperHouseEnvironment") == nil, "Lobby must not retain the Cooper house environment")
	check(Workspace.StreamingEnabled == false, "Lightweight lobby should not enable workspace streaming")
	if lobbyEnvironment then
		check(lobbyEnvironment:GetAttribute("Milestone") == 1, "Lobby environment milestone marker must be 1")
		check(lobbyEnvironment:GetAttribute("EnvironmentVersion") == "1.0.0", "Lobby environment version changed")
		check(lobbyEnvironment:GetAttribute("Purpose") == "PrivatePartyLobby", "Lobby environment purpose marker changed")
		directChild(lobbyEnvironment, "LobbySpawn", "SpawnLocation")
		directChild(lobbyEnvironment, "Architecture", "Folder")
		local decor = directChild(lobbyEnvironment, "Decor", "Folder")
		if decor then
			directChild(decor, "PrivateHousePortal", "Model")
			local partyPads = directChild(decor, "PartyPads", "Folder")
			if partyPads then
				local padCount = 0
				for _, child in ipairs(partyPads:GetChildren()) do
					if child:IsA("BasePart") then
						padCount += 1
					end
				end
				check(padCount == 4, "Lobby must retain exactly four visible party pads")
			end
		end
	end
	check(StarterPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable, "Lobby computer movement must stay UI-only")
	check(StarterPlayer.DevTouchMovementMode == Enum.DevTouchMovementMode.Scriptable, "Lobby touch movement must stay UI-only")
	check(StarterPlayer.AutoJumpEnabled == false, "Lobby auto-jump must remain disabled")

	local configModule = directChild(lobbyRoot, "Config", "ModuleScript")
	local LobbyConfig = loadDataModule(configModule, "ReplicatedStorage.CooperLobby.Config")
	if LobbyConfig then
		check(table.isfrozen(LobbyConfig), "Lobby config must be frozen")
		check(LobbyConfig.ProtocolVersion == 1, "Lobby protocol version must be 1")
		check(LobbyConfig.UniverseId == EXPECTED_UNIVERSE_ID, "Lobby universe ID changed")
		check(LobbyConfig.HousePlaceId == EXPECTED_HOUSE_PLACE_ID, "Lobby house place ID changed")
		check(LobbyConfig.LobbyPlaceId == EXPECTED_LOBBY_PLACE_ID, "LobbyPlaceId must identify the published start place")
		check(LobbyConfig.LobbyPlaceId ~= LobbyConfig.HousePlaceId, "Lobby and house must be different places")
		check(LobbyConfig.MinimumPartySize == 1 and LobbyConfig.MaximumPartySize == 4, "Lobby party bounds must be 1–4")
		check(Protocol and LobbyConfig.MaximumPartySize == Protocol.MAX_PARTY_SIZE, "Lobby and protocol party caps differ")
		check(LobbyConfig.StudioPreview == true, "Studio preview adapter must remain explicitly configured")
		if game.PlaceId > 0 then
			check(game.PlaceId == LobbyConfig.LobbyPlaceId, "This place does not match Config.LobbyPlaceId")
		end
		if game.GameId > 0 then
			check(game.GameId == LobbyConfig.UniverseId, "Lobby is not in the configured universe")
		end
	end
	check(
		Players.MaxPlayers >= MINIMUM_LOBBY_CAPACITY,
		"Lobby capacity must be at least four; current MaxPlayers is " .. tostring(Players.MaxPlayers)
	)
	advise(
		Players.MaxPlayers >= RECOMMENDED_LOBBY_CAPACITY,
		"Lobby MaxPlayers=" .. tostring(Players.MaxPlayers)
			.. "; 50 is recommended so multiple private parties can form concurrently"
	)

	local lobbyServer = directChild(ServerScriptService, "CooperLobby", "Script")
	local lobbyServerSource = sourceOf(lobbyServer, "ServerScriptService.CooperLobby")
	if lobbyServerSource then
		markers(lobbyServerSource, "CooperLobby server", {
			"MemoryStoreService",
			"TeleportService",
			"ReserveServerAsync",
			"ReservedServerAccessCode",
			"makeHouseTeleportData",
			"Protocol.MemoryStoreNames.Tickets",
			"Protocol.MemoryStoreNames.Sessions",
			"Protocol.MemoryStoreNames.Rejoins",
			"lobbyPlaceId = Config.LobbyPlaceId",
			"housePlaceId = Config.HousePlaceId",
			"local ticketIdsByUserId",
			'local ticketId = Protocol.newOpaqueId("arrival")',
			"userId = userId",
			"TeleportService:TeleportAsync(Config.HousePlaceId, { member }, options)",
			'if action == "CreateParty" then',
			'elseif action == "PlaySolo" then',
			'elseif action == "SetReady" then',
			'elseif action == "InviteFriends" then',
			'elseif action == "Launch" then',
			"Only the party host can start the house session.",
			"Everyone must be ready before the host can start.",
		})
		lacks(lobbyServerSource, 'GetService("MatchmakingService")', "CooperLobby server")
	end

	local lobbyClient = directChild(starterScripts, "CooperLobby", "LocalScript")
	local lobbyClientSource = sourceOf(lobbyClient, "StarterPlayer.StarterPlayerScripts.CooperLobby")
	if lobbyClientSource then
		markers(lobbyClientSource, "CooperLobby client", {
			"PLAY SOLO",
			"CREATE A PRIVATE PARTY",
			"INVITE FRIENDS",
			"I'M READY",
			"START PRIVATE HOUSE",
			"Enum.ScreenInsets.CoreUISafeInsets",
		})
	end

	if running then
		local remotes = directChild(ReplicatedStorage, "CooperPartyLobby", "Folder")
		directChild(remotes, "Request", "RemoteFunction")
		directChild(remotes, "State", "RemoteEvent")
		directChild(remotes, "ClientCommand", "RemoteEvent")
	end
end

for _, advisory in ipairs(advisories) do
	warn("[Milestone1FoundationAudit] ADVISORY: " .. advisory)
end

if #failures > 0 then
	error(string.format(
		"[Milestone1FoundationAudit] FAIL (%d of %d checks, %s %s mode):\n - %s",
		#failures,
		checkCount,
		placeRole,
		running and "runtime" or "edit",
		table.concat(failures, "\n - ")
	), 0)
end

print(string.format(
	"[Milestone1FoundationAudit] PASS: %d read-only checks in %s %s mode; party v1, 1–4 players, shared tasks, host authority, 60-second grace, sprint 16/22/6, and pre-horror lock verified",
	checkCount,
	placeRole,
	running and "runtime" or "edit"
))
return true
