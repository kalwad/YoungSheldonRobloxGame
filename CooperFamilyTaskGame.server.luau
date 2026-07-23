--!nonstrict
-- Personal, persistent family tasks and Time Machine economy.
-- Installed as ServerScriptService.CooperGame.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local ROOT_TIMEOUT = 30
local root = ReplicatedStorage:WaitForChild("CooperGame", ROOT_TIMEOUT)
assert(root and root:IsA("Folder"), "ReplicatedStorage.CooperGame is missing")
local configModule = root:WaitForChild("Config", ROOT_TIMEOUT)
assert(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config is missing")
local Config = require(configModule)
local TransactionLedger = require(root:WaitForChild("TransactionLedger", ROOT_TIMEOUT))
assert(TransactionLedger.VERSION == 1, "CooperGame.TransactionLedger v1 is required")
assert(
	tonumber(TransactionLedger.MAX_COMMITTED) and TransactionLedger.MAX_COMMITTED >= 256,
	"CooperGame.TransactionLedger must retain at least 256 committed operation records"
)
local partyProtocolModule = ReplicatedStorage:WaitForChild("CooperPartyProtocol", ROOT_TIMEOUT)
assert(partyProtocolModule and partyProtocolModule:IsA("ModuleScript"), "CooperPartyProtocol is missing")
local Protocol = require(partyProtocolModule)

local state = root:FindFirstChild("State") or Instance.new("Folder")
state.Name = "State"
state.Parent = root
for attributeName in pairs(state:GetAttributes()) do
	state:SetAttribute(attributeName, nil)
end
local remotes = root:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = root

local function ensureRemote(name)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local snapshotEvent = ensureRemote("Snapshot")
local feedbackEvent = ensureRemote("Feedback")
local requestEvent = ensureRemote("Request")
local bankHackEvent = ensureRemote("BankHack")

local serverEvents = ServerScriptService:FindFirstChild(Config.ServerEventsName)
if not serverEvents then
	serverEvents = Instance.new("Folder")
	serverEvents.Name = Config.ServerEventsName
	serverEvents.Parent = ServerScriptService
end

local function ensureServerEvent(className, name)
	local item = serverEvents:FindFirstChild(name)
	if item and item.ClassName ~= className then
		item:Destroy()
		item = nil
	end
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Parent = serverEvents
	end
	return item
end

local reportAction = ensureServerEvent("BindableEvent", "ReportAction")
local registerAction = ensureServerEvent("BindableEvent", "RegisterAction")
local requestDelivery = ensureServerEvent("BindableEvent", "RequestDelivery")
local requestBunkerConstruction = ensureServerEvent("BindableEvent", "RequestBunkerConstruction")
local runTaskAutomation = ensureServerEvent("BindableEvent", "RunTaskAutomation")
local candyDeliveryChanged = ensureServerEvent("BindableEvent", "CandyDeliveryChanged")
local serverAPI = ensureServerEvent("BindableFunction", "API")

local environment = workspace:WaitForChild("CooperHouseEnvironment", ROOT_TIMEOUT)
assert(environment, "CooperHouseEnvironment is missing")
local taskWorld = environment:WaitForChild(Config.WorldRootName, ROOT_TIMEOUT)
assert(taskWorld, Config.WorldRootName .. " is missing")
local house = environment:WaitForChild("CooperHouse", ROOT_TIMEOUT)
local furniture = house and house:WaitForChild("FurnitureAndProps", ROOT_TIMEOUT)
local bedroomDetails = furniture and furniture:WaitForChild("YoungSheldonBedroomDetails_V2", ROOT_TIMEOUT)
local sharedBedroom = bedroomDetails and bedroomDetails:WaitForChild("SheldonAndMissyRoom", ROOT_TIMEOUT)
local sheldonDesk = sharedBedroom and sharedBedroom:WaitForChild("Sheldon1980sComputerDesk", ROOT_TIMEOUT)
local computerAnchor = sheldonDesk and sheldonDesk:WaitForChild("Keyboard", ROOT_TIMEOUT)
assert(computerAnchor and computerAnchor:IsA("BasePart"), "Sheldon's exact computer keyboard is missing")

local taskById = {}
for _, definition in ipairs(Config.Tasks) do
	taskById[definition.id] = definition
end

local automationById = {}
local automationByTaskId = {}
for _, definition in ipairs(Config.TaskAutomationUpgrades) do
	automationById[definition.id] = definition
	automationByTaskId[definition.taskId] = definition
end

local BANK_TASK_ID = "MedfordBankHack"
local bankHackConfig = Config.BankHack
local secretBunkerConfig = Config.SecretBunker
local chemistrySetupConfig = Config.ChemistrySetup
local candyDeliveryConfig = Config.CandyDelivery
local partyConfig = Config.Party
assert(type(bankHackConfig) == "table", "CooperGame.Config.BankHack is missing")
assert(type(secretBunkerConfig) == "table", "CooperGame.Config.SecretBunker is missing")
assert(type(chemistrySetupConfig) == "table", "CooperGame.Config.ChemistrySetup is missing")
assert(type(candyDeliveryConfig) == "table", "CooperGame.Config.CandyDelivery is missing")
assert(type(partyConfig) == "table", "CooperGame.Config.Party is missing")
assert(tonumber(partyConfig.MaxMembers) == 4, "Milestone 1 parties must support exactly 1-4 players")
assert(tonumber(partyConfig.HostReconnectGraceSeconds) == 60, "Host reconnect grace must remain 60 seconds")
assert(tonumber(partyConfig.GuestReconnectGraceSeconds) == 90, "Guest reconnect grace must remain 90 seconds")
assert(partyConfig.ProtocolVersion == Protocol.VERSION, "House config and party protocol versions differ")
assert(partyConfig.MaxMembers == Protocol.MAX_PARTY_SIZE, "House and party protocol size caps differ")
assert(
	partyConfig.TicketMapName == Protocol.MemoryStoreNames.Tickets
		and partyConfig.SessionMapName == Protocol.MemoryStoreNames.Sessions
		and partyConfig.RejoinMapName == Protocol.MemoryStoreNames.Rejoins,
	"House config and party protocol MemoryStore names differ"
)
assert(secretBunkerConfig.Id == "secretbunker.underground", "Secret bunker terminal id changed")
assert(secretBunkerConfig.Name == "Secret Underground Bunker", "Secret bunker name changed")
assert(tonumber(secretBunkerConfig.Price) == 2500, "Secret bunker price changed")
assert(tonumber(secretBunkerConfig.ConstructionSeconds) == 45, "Secret bunker construction duration changed")
assert(chemistrySetupConfig.Id == "chemistry.setup", "Chemistry setup terminal id changed")
assert(chemistrySetupConfig.Name == "Advanced Chemistry Setup", "Chemistry setup name changed")
assert(tonumber(chemistrySetupConfig.Price) == 1800, "Chemistry setup price changed")
assert(chemistrySetupConfig.InstallTarget == "ChemistrySetAnchor", "Chemistry setup install target changed")
assert(candyDeliveryConfig.Id == "blue_rock_candy.delivery", "Candy delivery id changed")
assert(tonumber(candyDeliveryConfig.Payout) == 3000, "Candy delivery payout changed")
assert(candyDeliveryConfig.LogoCatalogAssetId == "rbxassetid://74538933380880", "Los Pollos catalog decal changed")
assert(candyDeliveryConfig.LogoAssetId == "rbxassetid://115114653936657", "Los Pollos resolved image changed")
assert(taskById[BANK_TASK_ID], "Config.Tasks is missing MedfordBankHack")
assert(
	tonumber(taskById[BANK_TASK_ID].reward) == tonumber(bankHackConfig.BaseReward),
	"MedfordBankHack task reward must match Config.BankHack.BaseReward"
)
assert(type(bankHackConfig.Keys) == "table", "Config.BankHack.Keys is missing")
local bankKeySet = {}
local bankKeys = {}
for _, rawKey in ipairs(bankHackConfig.Keys) do
	local key = type(rawKey) == "string" and string.upper(rawKey) or ""
	assert(#key == 1 and not bankKeySet[key], "Config.BankHack.Keys must contain unique one-character keys")
	bankKeySet[key] = true
	table.insert(bankKeys, key)
end
assert(#bankKeys >= 2, "Config.BankHack.Keys needs at least two keys")

local dataStoreEnabled = not RunService:IsStudio() or script:GetAttribute("EnableStudioDataStore") == true
local dataStore = dataStoreEnabled and DataStoreService:GetDataStore(Config.DataStoreName) or nil
local randomizer = Random.new()

local profiles = {}
local profilesByUserId = {}
local hydratingProfiles = {}
local requestNextAt = {}
local snapshotNextAt = {}
local bankInputNextAt = {}
local shuttingDown = false
local globalRevision = 0
local DATA_LOAD_ATTEMPTS = 4
local DELIVERY_RETRY_INTERVAL_SECONDS = 2
local RELEASE_SAVE_ATTEMPTS = 4
local SNAPSHOT_REQUEST_COOLDOWN = 0.75
-- The profile data uses schema v12. This reserved, temporary storage field
-- exists only while a live server owns the key and is removed on clean release.
-- A lease spans more than two autosave intervals so a single throttled renewal
-- cannot let another server take ownership from a healthy session.
local PROFILE_LEASE_FIELD = "_sessionLease"
local PROFILE_LEASE_SECONDS = 180
local PROFILE_LEASE_RENEW_WINDOW = 120
local SERVER_PROFILE_SESSION_ID = string.format(
	"%s:%s:%s",
	tostring(game.PlaceId),
	game.JobId ~= "" and game.JobId or "studio",
	HttpService:GenerateGUID(false)
)
local boomboxPlaybackOwner = nil
local boomboxSessionSerial = 0
local bankHackSessionSerial = 0
local BOOMBOX_TICK_EARLY_TOLERANCE = 0.15
local BOOMBOX_FINAL_TICK_TOLERANCE = 0.35
local BOOMBOX_END_WATCHDOG_GRACE = 2

-- M1_SHARED_TASK_SESSION_CONTRACT
-- There is exactly one authoritative party/session in a reserved house server,
-- including the synthetic one-member session used by solo play. Persistent
-- player profiles retain personal currency and statistics; the active task,
-- physical house state, and task reward token live here once per server.
local partySession = {
	id = "",
	hostUserId = 0,
	expectedMembers = {},
	activePlayers = {},
	state = "Loading",
	taskCursor = 0,
	completedTasks = 0,
	taskSerial = 0,
	task = nil,
	nextTaskAt = math.huge,
	lastHiddenMarker = nil,
	nextPlushKind = "Teddy",
	hostGraceSerial = 0,
	hostGraceDeadline = 0,
	hostGraceUnixExpiresAt = 0,
	pausedAt = 0,
	validated = false,
	studioSynthetic = false,
	loadingWatchStarted = false,
	closingStarted = false,
	closeSerial = 0,
}

local ticketMap = MemoryStoreService:GetHashMap(tostring(partyConfig.TicketMapName))
local sessionMap = MemoryStoreService:GetHashMap(tostring(partyConfig.SessionMapName))
local rejoinMap = MemoryStoreService:GetHashMap(tostring(partyConfig.RejoinMapName))

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function unixNow()
	return os.time()
end

local function normalizePartyMembers(rawMembers)
	if type(rawMembers) ~= "table" then
		return nil
	end
	local set = {}
	local ordered = {}
	for _, rawUserId in ipairs(rawMembers) do
		local userId = tonumber(rawUserId)
		if not userId or userId % 1 ~= 0 or userId <= 0 or set[userId] then
			return nil
		end
		set[userId] = true
		table.insert(ordered, userId)
	end
	if #ordered < 1 or #ordered > partyConfig.MaxMembers then
		return nil
	end
	table.sort(ordered)
	return ordered, set
end

local function sameMemberSet(left, right)
	for userId in pairs(left or {}) do
		if not (right and right[userId]) then
			return false
		end
	end
	for userId in pairs(right or {}) do
		if not (left and left[userId]) then
			return false
		end
	end
	return true
end

local function updateMemberRejoinRoute(userId, expiresAt, expectedDetachedProfile, expectedGraceSerial)
	if RunService:IsStudio() or partySession.studioSynthetic
		or not partySession.validated or not Protocol.isOpaqueId(partySession.id)
	then
		return true
	end
	local now = unixNow()
	local boundedExpiresAt = math.floor(tonumber(expiresAt) or 0)
	if boundedExpiresAt <= now then
		-- The route already carries the same authoritative expiry and will be
		-- rejected by the lobby even if MemoryStore's physical eviction lags.
		return true
	end
	local lifetime = math.max(1, math.min(
		partyConfig.SessionLifetimeSeconds,
		boundedExpiresAt - now
	))
	if expectedDetachedProfile and (
		profilesByUserId[userId] ~= expectedDetachedProfile
		or expectedDetachedProfile.detached ~= true
		or expectedDetachedProfile.guestGraceSerial ~= expectedGraceSerial
	) then
		return true
	end
	local guardCancelled = false
	local ok, result = pcall(function()
		return rejoinMap:UpdateAsync("rejoin:" .. tostring(userId), function(route)
			if expectedDetachedProfile and (
				profilesByUserId[userId] ~= expectedDetachedProfile
				or expectedDetachedProfile.detached ~= true
				or expectedDetachedProfile.guestGraceSerial ~= expectedGraceSerial
			) then
				guardCancelled = true
				return nil
			end
			if type(route) ~= "table" or route.sessionId ~= partySession.id
				or type(route.accessCode) ~= "string" or route.accessCode == ""
			then
				return nil
			end
			route.expiresAt = boundedExpiresAt
			route.updatedAt = now
			return route
		end, lifetime)
	end)
	local updated = ok and type(result) == "table" and result.sessionId == partySession.id
	if not updated and not guardCancelled then
		warn("[CooperGame] Could not update rejoin route for " .. tostring(userId)
			.. ": " .. tostring(result))
	end
	return updated or guardCancelled
end

local function rejoinRouteExpiration(userId, sessionState, renewedExpiresAt, hostGraceExpiresAt)
	local activePlayer = partySession.activePlayers[userId]
	local activeProfile = profilesByUserId[userId]
	if activePlayer and activePlayer.Parent == Players
		and activeProfile and activeProfile.player == activePlayer
		and activeProfile.loaded and not activeProfile.releasing
		and not activeProfile.leaseLost and activeProfile.detached ~= true
		and (dataStore == nil or activeProfile.leaseOwned == true)
	then
		return renewedExpiresAt
	end
	if userId == partySession.hostUserId and sessionState == "HostGrace" then
		local expiry = math.floor(tonumber(hostGraceExpiresAt) or 0)
		return expiry > unixNow() and expiry or nil
	end
	-- Detached guest routes are written once, with a serial guard, by the
	-- disconnect handler. Heartbeats deliberately leave them untouched so an
	-- in-flight reconnect cannot be shortened back to an old grace deadline.
	-- An expected guest who has not yet arrived keeps the lobby-issued 90-second
	-- admission deadline. Merely heartbeating the house must never renew it.
	return nil
end

local function syncSessionManifest(sessionState, hostGraceExpiresAt)
	if RunService:IsStudio() or partySession.studioSynthetic then
		return true
	end
	if not partySession.validated or not Protocol.isOpaqueId(partySession.id) then
		return false
	end
	local updated = nil
	local lastFailure = nil
	local renewedExpiresAt = unixNow() + partyConfig.SessionLifetimeSeconds
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return sessionMap:UpdateAsync("session:" .. partySession.id, function(manifest)
				if type(manifest) ~= "table"
					or manifest.sessionId ~= partySession.id
					or tonumber(manifest.hostUserId) ~= partySession.hostUserId
				then
					return nil
				end
				manifest.state = sessionState
				manifest.hostGraceExpiresAt = math.max(0, math.floor(tonumber(hostGraceExpiresAt) or 0))
				manifest.houseJobId = game.JobId
				manifest.updatedAt = unixNow()
				manifest.expiresAt = renewedExpiresAt
				return manifest
			end, partyConfig.SessionLifetimeSeconds)
		end)
		if ok and type(result) == "table" then
			updated = result
			break
		end
		lastFailure = result
		if attempt < 3 then
			task.wait(0.2 * attempt)
		end
	end
	if not updated then
		warn(string.format(
			"[CooperGame] Could not synchronize party session state %s: %s",
			tostring(sessionState),
			tostring(lastFailure)
		))
		return false
	end
	-- The lobby alone knows the reserved access code. The house renews each
	-- existing server-only route without ever reading or replicating that code.
	-- Closed sessions remove their routes immediately.
	for userId in pairs(partySession.expectedMembers) do
		local key = "rejoin:" .. tostring(userId)
		if sessionState == "Closed" then
			pcall(rejoinMap.RemoveAsync, rejoinMap, key)
		else
			local routeExpiresAt = rejoinRouteExpiration(
				userId,
				sessionState,
				renewedExpiresAt,
				hostGraceExpiresAt
			)
			if routeExpiresAt then
				updateMemberRejoinRoute(userId, routeExpiresAt)
			end
		end
	end
	return true
end

local function setPartyPlayerAttributes(player)
	local isMember = partySession.expectedMembers[player.UserId] == true
	player:SetAttribute("CooperPartyMember", isMember)
	player:SetAttribute("CooperPartySessionId", isMember and partySession.id or nil)
	player:SetAttribute("CooperPartyHostUserId", isMember and partySession.hostUserId or nil)
	player:SetAttribute("CooperPartyIsHost", isMember and player.UserId == partySession.hostUserId)
	player:SetAttribute("CooperPartyState", isMember and partySession.state or nil)
end

local function createSyntheticParty(player)
	if partySession.validated then
		if RunService:IsStudio()
			and partySession.studioSynthetic
			and not partySession.expectedMembers[player.UserId]
			and #Players:GetPlayers() <= partyConfig.MaxMembers
		then
			partySession.expectedMembers[player.UserId] = true
		end
		return partySession.expectedMembers[player.UserId] == true
	end
	partySession.id = string.format(
		"%s:%s:%s",
		RunService:IsStudio() and "studio" or "solo",
		tostring(game.JobId ~= "" and game.JobId or "local"),
		HttpService:GenerateGUID(false)
	)
	partySession.hostUserId = player.UserId
	partySession.expectedMembers = { [player.UserId] = true }
	partySession.state = "Loading"
	partySession.validated = true
	partySession.studioSynthetic = RunService:IsStudio()
	return true
end

local function validateLaunchTicket(player)
	-- Studio cannot exercise TeleportService. Multiplayer Studio tests use one
	-- synthetic party while production always fails closed on missing tickets.
	if RunService:IsStudio() then
		return createSyntheticParty(player)
	end
	if Config.Features.Lobby ~= true then
		return createSyntheticParty(player)
	end
	local lobbyPlaceId = tonumber(partyConfig.LobbyPlaceId) or 0
	if lobbyPlaceId <= 0 or game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return false, "This house only accepts private parties launched by the lobby."
	end
	local joinData = player:GetJoinData()
	local teleportData = type(joinData) == "table" and joinData.TeleportData or nil
	if tonumber(joinData and joinData.SourcePlaceId) ~= lobbyPlaceId or type(teleportData) ~= "table" then
		return false, "The private-party handoff was missing. Return to the lobby and try again."
	end
	-- TeleportData is client-visible and therefore only a structured hint. The
	-- protocol parser bounds every field before the opaque ids are cross-checked
	-- against the server-only ticket and session manifest below.
	local parsedTeleport, teleportError = Protocol.validateHouseTeleportData(
		teleportData,
		player.UserId,
		unixNow()
	)
	if not parsedTeleport then
		return false, teleportError or "That party launch ticket is invalid or out of date."
	end
	local sessionId = parsedTeleport.sessionId
	local ticketId = parsedTeleport.ticketId
	-- Validate the server-only session before consuming the one-use arrival
	-- ticket. A transient manifest read failure must not burn a good ticket.
	local manifestOk, manifest = pcall(sessionMap.GetAsync, sessionMap, "session:" .. sessionId)
	local manifestHostUserId = type(manifest) == "table" and tonumber(manifest.hostUserId) or nil
	local manifestExpiresAt = type(manifest) == "table" and tonumber(manifest.expiresAt) or nil
	local manifestSet = nil
	if type(manifest) == "table" then
		local _
		_, manifestSet = normalizePartyMembers(manifest.members)
	end
	local _, teleportMemberSet = normalizePartyMembers(parsedTeleport.memberUserIds)
	if not manifestOk or type(manifest) ~= "table"
		or tonumber(manifest.v) ~= partyConfig.ProtocolVersion
		or manifest.sessionId ~= sessionId
		or manifest.partyId ~= parsedTeleport.partyId
		or manifestHostUserId ~= parsedTeleport.hostUserId
		or not manifestExpiresAt or manifestExpiresAt < unixNow()
		or (manifest.state ~= "Launching" and manifest.state ~= "InHouse" and manifest.state ~= "HostGrace")
		or type(manifest.reservedServerPrivateId) ~= "string"
		or manifest.reservedServerPrivateId == ""
		or manifest.reservedServerPrivateId ~= game.PrivateServerId
		or not manifestSet or not teleportMemberSet
		or not sameMemberSet(manifestSet, teleportMemberSet)
	then
		return false, "The party session expired. Return to the lobby to launch again."
	end
	if player.UserId == manifestHostUserId
		and type(manifest.hostGraceExpiresAt) == "number"
		and manifest.hostGraceExpiresAt > 0
		and manifest.hostGraceExpiresAt <= unixNow()
	then
		return false, "The host reconnect window has ended."
	end
	local rejection = "That party launch ticket is no longer valid."
	local claimNonce = Protocol.newOpaqueId("claim")
	local ok, result = pcall(function()
		return ticketMap:UpdateAsync("ticket:" .. ticketId, function(ticket)
			local ticketExpiresAt = type(ticket) == "table" and tonumber(ticket.expiresAt) or nil
			if type(ticket) ~= "table"
				or tonumber(ticket.v) ~= partyConfig.ProtocolVersion
				or ticket.sessionId ~= sessionId
				or tonumber(ticket.userId) ~= player.UserId
				or tonumber(ticket.hostUserId) ~= parsedTeleport.hostUserId
				or not ticketExpiresAt or ticketExpiresAt < unixNow()
			then
				return nil
			end
			local members, memberSet = normalizePartyMembers(ticket.members)
			local hostUserId = tonumber(ticket.hostUserId)
			if not members
				or not sameMemberSet(memberSet, teleportMemberSet)
				or not memberSet[player.UserId] or not memberSet[hostUserId]
			then
				return nil
			end
			-- Every per-player launch ticket is one-use, including within the same
			-- reserved job. Rejoins are issued a fresh ticket by the lobby instead of
			-- replaying the original handoff.
			if ticket.consumedByJobId ~= nil or ticket.consumedAt ~= nil then
				rejection = "That party launch ticket was already used."
				return nil
			end
			ticket.consumedByJobId = game.JobId
			ticket.consumedAt = unixNow()
			ticket.consumedClaimNonce = claimNonce
			return ticket
		end, partyConfig.LaunchTicketLifetimeSeconds)
	end)
	if not ok or type(result) ~= "table"
		or result.consumedClaimNonce ~= claimNonce
		or result.consumedByJobId ~= game.JobId
		or tonumber(result.userId) ~= player.UserId
		or result.sessionId ~= sessionId
	then
		return false, rejection
	end
	local acceptedMembers, acceptedMemberSet = normalizePartyMembers(result.members)
	local acceptedHostUserId = tonumber(result.hostUserId)
	if not acceptedMembers or not acceptedMemberSet
		or acceptedHostUserId ~= manifestHostUserId
		or not sameMemberSet(manifestSet, acceptedMemberSet)
	then
		return false, "The party manifest did not match the launch ticket."
	end
	if partySession.validated then
		if partySession.state == "Closing" then
			return false, "That private party is already closing."
		end
		if partySession.id ~= sessionId
			or partySession.hostUserId ~= acceptedHostUserId
			or not sameMemberSet(partySession.expectedMembers, acceptedMemberSet)
		then
			return false, "That ticket belongs to a different private party."
		end
	else
		partySession.id = sessionId
		partySession.hostUserId = acceptedHostUserId
		partySession.expectedMembers = acceptedMemberSet
		partySession.state = "Loading"
		partySession.validated = true
	end
	return true
end

local function partyIsMember(player)
	return player ~= nil
		and player.Parent == Players
		and partySession.expectedMembers[player.UserId] == true
		and partySession.activePlayers[player.UserId] == player
end

local function partyIsHost(player)
	return partyIsMember(player) and player.UserId == partySession.hostUserId
end

local function partyCanProgress()
	if not partySession.validated or partySession.state ~= "Active" then
		return false
	end
	local activeHost = partySession.activePlayers[partySession.hostUserId]
	local activeHostProfile = profilesByUserId[partySession.hostUserId]
	if not activeHost or activeHost.Parent ~= Players
		or not activeHostProfile or activeHostProfile.player ~= activeHost
		or not activeHostProfile.loaded or activeHostProfile.releasing
		or activeHostProfile.leaseLost
		or (dataStore ~= nil and activeHostProfile.leaseOwned ~= true)
	then
		return false
	end
	-- A player already standing in the server is "present" for the shared
	-- reward contract. Briefly pause progression while any admitted member is
	-- still hydrating so nobody can miss a task payout because DataStore was
	-- slower for them than for the host. Iterate the actual Players service, not
	-- only activePlayers: PlayerAdded can run a task callback in the tiny window
	-- before validateLaunchTicket has published that player's active slot.
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		local profile = profilesByUserId[userId]
		if partySession.expectedMembers[userId] ~= true
			or partySession.activePlayers[userId] ~= player
			or player.Parent ~= Players or not profile or profile.player ~= player
			or not profile.loaded or profile.releasing or profile.leaseLost
		then
			return false
		end
	end
	return true
end

local function hostProfile()
	local profile = profilesByUserId[partySession.hostUserId]
	return profile and profile.loaded and not profile.releasing and not profile.leaseLost
		and (dataStore == nil or profile.leaseOwned == true) and profile or nil
end

local function presentProfiles()
	local result = {}
	for userId, player in pairs(partySession.activePlayers) do
		local profile = profilesByUserId[userId]
		if player.Parent == Players and profile and profile.player == player
			and profile.loaded and not profile.releasing
		then
			table.insert(result, profile)
		end
	end
	table.sort(result, function(left, right)
		return left.player.UserId < right.player.UserId
	end)
	return result
end

local function formatCountdown(seconds)
	local total = math.max(0, math.ceil(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

local function finiteInteger(value, default, minimum, maximum)
	local numeric = tonumber(value)
	if not numeric or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
		return default
	end
	return math.clamp(math.floor(numeric + 0.5), minimum, maximum)
end

local function bankHackSuccessCount(profile)
	return finiteInteger(profile and profile.data.bankHackSuccesses, 0, 0, 1_000_000)
end

local function bankHackPreviewStepForSuccesses(successes)
	successes = finiteInteger(successes, 0, 0, 1_000_000)
	local base = tonumber(bankHackConfig.BasePreviewStepSeconds) or 0.78
	local speedup = math.max(0, tonumber(bankHackConfig.SpeedupPerSuccess) or 0.06)
	local minimum = math.max(0.05, tonumber(bankHackConfig.MinimumPreviewStepSeconds) or 0.32)
	return math.max(minimum, base - successes * speedup)
end

local function bankHackPreviewStep(profile)
	return bankHackPreviewStepForSuccesses(bankHackSuccessCount(profile))
end

local function bankHackStartingLengthForSuccesses(successes)
	successes = finiteInteger(successes, 0, 0, 1_000_000)
	local base = finiteInteger(bankHackConfig.StartingLength, 2, 1, 100)
	local every = finiteInteger(bankHackConfig.StartingLengthIncreaseEverySuccesses, 2, 1, 1_000_000)
	local maximum = finiteInteger(bankHackConfig.MaximumStartingLength, 4, base, 100)
	return math.min(maximum, base + math.floor(successes / every))
end

local function bankHackStartingLength(profile)
	return bankHackStartingLengthForSuccesses(bankHackSuccessCount(profile))
end

local function bankHackReward(profile)
	local successes = bankHackSuccessCount(profile)
	local base = finiteInteger(bankHackConfig.BaseReward, 90, 0, 2_000_000_000)
	local increase = finiteInteger(bankHackConfig.RewardPerSuccess, 20, 0, 2_000_000_000)
	local maximum = finiteInteger(bankHackConfig.MaximumReward, 300, base, 2_000_000_000)
	return math.min(maximum, base + successes * increase)
end

-- Compare only values owned by the profile sanitizer. The saved timestamp is
-- intentionally ignored here because saveProfile refreshes it on every write.
-- Nested tables are compared in both directions so unknown automation ids,
-- non-boolean values, and missing installed ids all trigger a canonical rewrite.
local function canonicalProfileValueMatches(rawValue, canonicalValue)
	if type(rawValue) ~= type(canonicalValue) then
		return false
	end
	if type(canonicalValue) ~= "table" then
		return rawValue == canonicalValue
	end
	for key, value in pairs(canonicalValue) do
		if not canonicalProfileValueMatches(rawValue[key], value) then
			return false
		end
	end
	for key in pairs(rawValue) do
		if canonicalValue[key] == nil then
			return false
		end
	end
	return true
end

local function profileDataNeedsCanonicalRewrite(rawData, sanitizedData)
	-- nil is the normal never-played profile and does not need an eager write.
	if rawData == nil then
		return false
	end
	if type(rawData) ~= "table" then
		return true
	end
	for fieldName, canonicalValue in pairs(sanitizedData) do
		if not canonicalProfileValueMatches(rawData[fieldName], canonicalValue) then
			return true
		end
	end
	for fieldName in pairs(rawData) do
		if fieldName ~= "updatedAt"
			and fieldName ~= PROFILE_LEASE_FIELD
			and sanitizedData[fieldName] == nil
		then
			return true
		end
	end
	return false
end

local function sanitizeCalmTaskCheckpoint(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local taskId = type(raw.taskId) == "string" and raw.taskId or ""
	local logicalId = type(raw.logicalId) == "string" and raw.logicalId or ""
	local hostUserId = finiteInteger(raw.hostUserId, 0, 1, 9_007_199_254_740_991)
	local hostOrdinal = finiteInteger(raw.hostOrdinal, 0, 1, 10_000_001)
	if finiteInteger(raw.version, 0, 0, 100) ~= 1
		or not taskById[taskId]
		or #logicalId < 8 or #logicalId > 96
		or hostUserId <= 0 or hostOrdinal <= 0
	then
		return nil
	end
	local rawEligible = type(raw.eligibleUserIds) == "table" and raw.eligibleUserIds or {}
	local eligibleUserIds = {}
	local seen = {}
	for _, rawUserId in ipairs(rawEligible) do
		local userId = finiteInteger(rawUserId, 0, 1, 9_007_199_254_740_991)
		if userId > 0 and not seen[userId] and #eligibleUserIds < partyConfig.MaxMembers then
			seen[userId] = true
			table.insert(eligibleUserIds, userId)
		end
	end
	table.sort(eligibleUserIds)
	if #eligibleUserIds == 0 or not seen[hostUserId] then
		return nil
	end
	local markerName = type(raw.markerName) == "string" and string.sub(raw.markerName, 1, 64) or ""
	local plushKind = raw.plushKind == "Rabbit" and "Rabbit" or "Teddy Bear"
	local bankPreviewStepSeconds = tonumber(raw.bankPreviewStepSeconds)
	if not bankPreviewStepSeconds or bankPreviewStepSeconds ~= bankPreviewStepSeconds
		or bankPreviewStepSeconds == math.huge or bankPreviewStepSeconds == -math.huge
	then
		bankPreviewStepSeconds = 0.78
	end
	return {
		version = 1,
		logicalId = logicalId,
		taskId = taskId,
		hostUserId = hostUserId,
		hostOrdinal = hostOrdinal,
		eligibleUserIds = eligibleUserIds,
		startedAtUnix = finiteInteger(raw.startedAtUnix, 0, 0, 4_102_444_800),
		recoveryGraceExpiresAt = finiteInteger(raw.recoveryGraceExpiresAt, 0, 0, 4_102_444_800),
		markerName = markerName,
		plushKind = plushKind,
		bankCycle = finiteInteger(raw.bankCycle, 1, 1, 1_000_001),
		bankReward = finiteInteger(raw.bankReward, 0, 0, 2_000_000_000),
		bankPreviewStepSeconds = math.clamp(bankPreviewStepSeconds, 0.05, 10),
		bankStartingLength = finiteInteger(raw.bankStartingLength, 2, 1, 100),
	}
end

local function sanitizeData(raw)
	local originalRaw = raw
	raw = type(raw) == "table" and raw or {}
	-- Schema 12 stores the exactly-once record beside the value it protects.
	-- TransactionLedger applies strict bounds and drops malformed/duplicate
	-- records before this profile can be written back to production storage.
	local operationJournal = TransactionLedger.sanitize(raw.operationJournal)
	local calmTaskCheckpoint = sanitizeCalmTaskCheckpoint(raw.calmTaskCheckpoint)
	-- A placed unit necessarily includes its purchase entitlement. This repairs
	-- an impossible partial save without taking an already-installed item away.
	local boomboxPlaced = raw.boomboxPlaced == true
	local boomboxPurchased = raw.boomboxPurchased == true or boomboxPlaced
	local installedRaw = type(raw.taskAutomationInstalled) == "table" and raw.taskAutomationInstalled or {}
	local taskAutomationInstalled = {}
	for _, definition in ipairs(Config.TaskAutomationUpgrades) do
		if installedRaw[definition.id] == true then
			taskAutomationInstalled[definition.id] = true
		end
	end
	-- The pending id is the durable proof that an upgrade was already paid for.
	-- Preserve every recognized, uninstalled pending purchase across schema
	-- migrations and reconnects; only invalid or already-installed ids are cleared.
	local pendingTaskUpgradeId = type(raw.pendingTaskUpgradeId) == "string"
		and raw.pendingTaskUpgradeId
		or ""
	if not automationById[pendingTaskUpgradeId] or taskAutomationInstalled[pendingTaskUpgradeId] then
		pendingTaskUpgradeId = ""
	end
	local secretBunkerPurchased = raw.secretBunkerPurchased == true
	-- A paid entitlement without its timestamp is an impossible partial save.
	-- Repair it to an already-finished deadline rather than taking the purchase
	-- away or making the player pay a second time.
	local secretBunkerReadyAt = secretBunkerPurchased
		and finiteInteger(raw.secretBunkerReadyAt, 1, 1, 4_102_444_800)
		or 0
	-- An installed lab necessarily includes its purchase entitlement. Preserve
	-- paid-but-uninstalled setups as the durable delivery marker on reconnect.
	local chemistrySetupPlaced = raw.chemistrySetupPlaced == true
	local chemistrySetupPurchased = raw.chemistrySetupPurchased == true or chemistrySetupPlaced
	-- Milestone 1 lets a guest use the host's installed chemistry lab while the
	-- resulting batch remains the guest's personal product. Do not erase a valid
	-- batch merely because that guest does not own a lab in their own house.
	local candyDeliveryActive = raw.candyDeliveryActive == true
	local candyDeliveryToken = candyDeliveryActive
		and type(raw.candyDeliveryToken) == "string"
		and #raw.candyDeliveryToken >= 8
		and #raw.candyDeliveryToken <= 96
		and raw.candyDeliveryToken
		or (candyDeliveryActive and HttpService:GenerateGUID(false) or "")
	-- Reaction completion and physical collection are distinct durable states.
	-- If a legacy/corrupt profile contains both, the later delivery contract wins;
	-- otherwise a ready batch retains (or repairs) its one-time collection token.
	local candyBatchReady = not candyDeliveryActive
		and raw.candyBatchReady == true
	local candyBatchToken = candyBatchReady
		and type(raw.candyBatchToken) == "string"
		and #raw.candyBatchToken >= 8
		and #raw.candyBatchToken <= 96
		and raw.candyBatchToken
		or (candyBatchReady and HttpService:GenerateGUID(false) or "")
	local totalTasks = finiteInteger(raw.totalTasks, 0, 0, 10_000_000)
	-- The current simple game has a strict five-task rotation. Keep the new
	-- cycle fields canonical by deriving them from its existing lifetime count;
	-- this makes every schema-10 profile migrate without changing its next task.
	local cycleIndex = math.floor(totalTasks / #Config.TaskOrder) + 1
	local cycleTaskIndex = (totalTasks % #Config.TaskOrder) + 1
	local endingChoice = (raw.endingChoice == "Stay" or raw.endingChoice == "Return")
		and raw.endingChoice
		or ""
	local sanitized = {
		schemaVersion = Config.SchemaVersion,
		operationJournal = operationJournal,
		allowance = finiteInteger(raw.allowance, 0, 0, 2_000_000_000),
		machineStage = finiteInteger(raw.machineStage, 0, 0, #Config.MachineStages),
		pendingPartStage = finiteInteger(raw.pendingPartStage, 0, 0, #Config.MachineStages),
		tutorialSeen = raw.tutorialSeen == true,
		totalTasks = totalTasks,
		cycleIndex = cycleIndex,
		cycleTaskIndex = cycleTaskIndex,
		postRevealCyclesCompleted = finiteInteger(raw.postRevealCyclesCompleted, 0, 0, 10_000_000),
		firstHorrorRevealed = raw.firstHorrorRevealed == true,
		horrorEncountersSurvived = finiteInteger(raw.horrorEncountersSurvived, 0, 0, 10_000_000),
		horrorEncountersCaught = finiteInteger(raw.horrorEncountersCaught, 0, 0, 10_000_000),
		horrorCurrentStreak = finiteInteger(raw.horrorCurrentStreak, 0, 0, 10_000_000),
		horrorLongestStreak = finiteInteger(raw.horrorLongestStreak, 0, 0, 10_000_000),
		backroomsDiscovered = raw.backroomsDiscovered == true,
		domeDiscovered = raw.domeDiscovered == true,
		endingCompleted = raw.endingCompleted == true,
		endingChoice = endingChoice,
		postgameUnlocked = raw.postgameUnlocked == true,
		boomboxPurchased = boomboxPurchased,
		boomboxPlaced = boomboxPlaced,
		boomboxNextPlayAt = finiteInteger(raw.boomboxNextPlayAt, 0, 0, 4_102_444_800),
		-- Autoplay is a paid extension of an owned boombox. Legacy profiles do
		-- not contain this field and safely migrate to false; impossible partial
		-- saves cannot retain the upgrade without the underlying entitlement.
		boomboxAutoplayPurchased = boomboxPurchased and raw.boomboxAutoplayPurchased == true,
		taskAutomationInstalled = taskAutomationInstalled,
		pendingTaskUpgradeId = pendingTaskUpgradeId,
		bankHackSuccesses = finiteInteger(raw.bankHackSuccesses, 0, 0, 1_000_000),
		secretBunkerPurchased = secretBunkerPurchased,
		secretBunkerReadyAt = secretBunkerReadyAt,
		chemistrySetupPurchased = chemistrySetupPurchased,
		chemistrySetupPlaced = chemistrySetupPlaced,
		-- A finished reaction remains claimable even before the player creates a
		-- Tool or buyer-truck contract. This closes the leave/restart loss window.
		candyBatchReady = candyBatchReady,
		candyBatchToken = candyBatchToken,
		-- A collected batch is a durable delivery contract. If the character dies
		-- or the server closes, the physical pan and buyer truck are reconstructed
		-- from this flag instead of deleting a finished chemistry run.
		candyDeliveryActive = candyDeliveryActive,
		candyDeliveryToken = candyDeliveryToken,
		candyBatchesSold = finiteInteger(raw.candyBatchesSold, 0, 0, 10_000_000),
	}
	if calmTaskCheckpoint then
		sanitized.calmTaskCheckpoint = calmTaskCheckpoint
	end
	return sanitized, profileDataNeedsCanonicalRewrite(originalRaw, sanitized)
end

local function profileKey(player)
	return Config.DataStoreKeyPrefix .. tostring(player.UserId)
end

local function copyStoredProfileRecord(raw)
	local copy = {}
	if type(raw) == "table" then
		for key, value in pairs(raw) do
			copy[key] = value
		end
	end
	return copy
end

local function storedProfileLease(raw)
	local lease = type(raw) == "table" and raw[PROFILE_LEASE_FIELD] or nil
	if type(lease) ~= "table" or type(lease.owner) ~= "string" or lease.owner == "" then
		return nil, 0
	end
	local expiresAt = tonumber(lease.expiresAt)
	if not expiresAt or expiresAt ~= expiresAt or expiresAt == math.huge or expiresAt == -math.huge then
		return nil, 0
	end
	return lease.owner, math.max(0, math.floor(expiresAt))
end

local function acquireProfileLease(profile)
	local player = profile.player
	local lastFailure = "Profile lease could not be acquired."
	local sawLiveConflict = false
	for attempt = 1, DATA_LOAD_ATTEMPTS do
		local callbackClaimed = false
		local conflictExpiresAt = 0
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(profileKey(player), function(current)
				-- UpdateAsync can rerun this callback after a concurrent write. Keep
				-- these flags representative of the final callback invocation only.
				callbackClaimed = false
				conflictExpiresAt = 0
				local now = os.time()
				local owner, expiresAt = storedProfileLease(current)
				if owner and owner ~= profile.leaseToken and expiresAt > now then
					conflictExpiresAt = expiresAt
					return nil
				end
				local claimedRecord = copyStoredProfileRecord(current)
				claimedRecord[PROFILE_LEASE_FIELD] = {
					owner = profile.leaseToken,
					server = SERVER_PROFILE_SESSION_ID,
					expiresAt = now + PROFILE_LEASE_SECONDS,
				}
				callbackClaimed = true
				return claimedRecord
			end)
		end)
		if ok and callbackClaimed then
			local owner, expiresAt = storedProfileLease(result)
			if owner == profile.leaseToken and expiresAt > os.time() then
				return true, result, expiresAt, nil, false
			end
			lastFailure = "Profile lease commit could not be verified."
		elseif ok and conflictExpiresAt > os.time() then
			sawLiveConflict = true
			lastFailure = "Profile is still active in another server."
		else
			lastFailure = tostring(result)
		end
		if attempt < DATA_LOAD_ATTEMPTS then
			task.wait(math.min(2 ^ (attempt - 1), 4))
		end
	end
	return false, nil, 0, lastFailure, sawLiveConflict
end

local function releaseProfileLease(profile, maximumAttempts)
	if not dataStore or not profile.leaseOwned then
		return true
	end
	local lastFailure = "Profile lease release did not complete."
	for attempt = 1, maximumAttempts do
		local callbackReleased = false
		local callbackAlreadyMissing = false
		local callbackRejected = false
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(profileKey(profile.player), function(current)
				callbackReleased = false
				callbackAlreadyMissing = false
				callbackRejected = false
				local owner = storedProfileLease(current)
				if owner == nil then
					callbackAlreadyMissing = true
					return nil
				end
				if owner ~= profile.leaseToken then
					callbackRejected = true
					return nil
				end
				local releasedRecord = copyStoredProfileRecord(current)
				releasedRecord[PROFILE_LEASE_FIELD] = nil
				callbackReleased = true
				return releasedRecord
			end)
		end)
		if ok and (callbackReleased or callbackAlreadyMissing) then
			profile.leaseOwned = false
			profile.leaseExpiresAt = 0
			return true
		end
		if ok and callbackRejected then
			profile.leaseOwned = false
			profile.leaseLost = true
			return false, "Profile lease belongs to another server."
		end
		lastFailure = tostring(result)
		if attempt < maximumAttempts then
			task.wait(math.min(0.5 * attempt, 1.5))
		end
	end
	return false, lastFailure
end

local function invalidateLostProfileLease(profile, reason)
	if profile.leaseLost then
		return
	end
	profile.leaseLost = true
	profile.leaseOwned = false
	profile.leaseExpiresAt = 0
	profile.loaded = false
	profile.releasing = true
	local player = profile.player
	if player then
		player:SetAttribute("CooperGameProfileLoaded", false)
	end
	warn("[CooperGame] Profile lease lost for " .. tostring(player and player.Name) .. ": " .. tostring(reason))
	task.defer(function()
		if profiles[player] == profile and player.Parent == Players then
			player:Kick("Your saved game opened in another server, so this session was stopped to protect your progress. Please rejoin.")
		end
	end)
end

local function findPlayerRoot(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end
	return rootPart
end

local function playerNear(player, instance, maximumDistance)
	local rootPart = findPlayerRoot(player)
	if not rootPart or not instance then
		return false
	end
	local position
	if instance:IsA("BasePart") then
		position = instance.Position
	elseif instance:IsA("Attachment") then
		position = instance.WorldPosition
	elseif instance:IsA("Model") then
		position = instance:GetPivot().Position
	else
		local part = instance:FindFirstAncestorWhichIsA("BasePart")
		position = part and part.Position or nil
	end
	return position ~= nil and (rootPart.Position - position).Magnitude <= maximumDistance
end

local function taskLocation(name)
	return taskWorld:FindFirstChild(name, true)
end

local function validComputerSession(player)
	local expiresAt = player and player:GetAttribute("CooperComputerSessionUntil")
	return type(expiresAt) == "number"
		and expiresAt > serverNow()
		and playerNear(player, computerAnchor, 14)
end

local function bunkerComputerAnchor()
	local bunker = environment:FindFirstChild("BackyardBunker")
	local underground = bunker and bunker:FindFirstChild("Underground")
	local terminal = underground and underground:FindFirstChild("BunkerResearchTerminal")
	local anchor = terminal and terminal:FindFirstChild("BunkerTerminalInputAnchor", true)
	return anchor and anchor:IsA("BasePart") and anchor or nil
end

local function validBunkerComputerSession(player)
	local expiresAt = player and player:GetAttribute("CooperBunkerComputerSessionUntil")
	local anchor = bunkerComputerAnchor()
	return type(expiresAt) == "number"
		and expiresAt > serverNow()
		and player:GetAttribute("CooperSecretBunkerUnlocked") == true
		and anchor ~= nil
		and playerNear(player, anchor, 14)
end

local function destroyExistingMissyCarry(player)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("FamilyMissyPlush") == true then
					child:Destroy()
				end
			end
		end
	end
end

local function destroyManualCarryForAutomation(player, taskId)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool")
					and ((taskId == "MaryTrash" and child:GetAttribute("FamilyTrashBag") == true)
						or (taskId == "MissyPlush" and child:GetAttribute("FamilyMissyPlush") == true))
				then
					child:Destroy()
				end
			end
		end
	end
end

-- The hidden prop is rendered locally because its location is private to one
-- player. Once collected, replace it with an authoritative Tool so returning
-- the toy requires visibly carrying the same stuffed animal to Missy's bed.
local function createMissyCarryTool(player, plushKind)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local sourceName = plushKind == "Rabbit" and "MissyDetailedRabbit" or "MissyDetailedTeddyBear"
	local source = environment:FindFirstChild(sourceName, true)
	if not source or not source:IsA("Model") then
		return nil
	end

	destroyExistingMissyCarry(player)
	local tool = Instance.new("Tool")
	tool.Name = plushKind == "Rabbit" and "Missy's Lost Rabbit" or "Missy's Lost Teddy Bear"
	tool.ToolTip = "Return this stuffed animal to Missy's bed"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("FamilyMissyPlush", true)
	tool:SetAttribute("PlushKind", plushKind)
	tool:SetAttribute("OwnerUserId", player.UserId)
	tool.Grip = CFrame.new(0, -0.35, -0.5) * CFrame.Angles(0, math.rad(8), 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 0.35)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local visual = source:Clone()
	visual.Name = "StuffedAnimalVisual"
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif descendant:IsA("WeldConstraint") or descendant:IsA("Weld") then
			descendant:Destroy()
		end
	end
	visual.Parent = tool
	visual:PivotTo(handle.CFrame)
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Name = "MissyCarryWeld"
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end

	tool.Parent = backpack
	humanoid:EquipTool(tool)
	if tool.Parent == character or tool.Parent == backpack then
		return tool
	end
	tool:Destroy()
	return nil
end

local function machineProgress(stage)
	if stage <= 0 then
		return 0
	end
	local definition = Config.MachineStages[stage]
	return definition and definition.progress or 0
end

local function nextMachinePart(profile)
	local stage = profile.data.machineStage + 1
	return Config.MachineStages[stage]
end

local function markDirty(profile)
	profile.revision = (profile.revision or 0) + 1
	profile.dirty = true
end

local function setAllowance(profile, amount, shouldMarkDirty)
	local nextAllowance = math.max(0, math.floor(amount))
	local changed = profile.data.allowance ~= nextAllowance
	profile.data.allowance = nextAllowance
	if changed and shouldMarkDirty ~= false then
		markDirty(profile)
	end
	local allowance = profile.allowanceValue
	if allowance then
		allowance.Value = profile.data.allowance
	end
end

local function syncBoomboxPlacedAttribute(_profile)
	local worldProfile = hostProfile()
	local placed = worldProfile ~= nil and worldProfile.data.boomboxPlaced == true
	for _, player in ipairs(Players:GetPlayers()) do
		if partyIsMember(player) then
			player:SetAttribute("CooperBoomboxPlaced", placed)
		end
	end
end

local function secretBunkerSnapshot(profile, viewerProfile)
	viewerProfile = viewerProfile or profile
	local purchased = profile ~= nil and profile.data.secretBunkerPurchased == true
	local readyAt = purchased
		and finiteInteger(profile.data.secretBunkerReadyAt, 1, 1, 4_102_444_800)
		or 0
	local remaining = purchased and math.max(0, readyAt - unixNow()) or 0
	local unlocked = purchased and remaining <= 0
	local status = if not purchased
		then "Available"
		elseif unlocked
			then "Unlocked"
			else "Construction"
	return {
		id = secretBunkerConfig.Id,
		name = secretBunkerConfig.Name,
		price = finiteInteger(secretBunkerConfig.Price, 2500, 1, 2_000_000_000),
		constructionSeconds = finiteInteger(secretBunkerConfig.ConstructionSeconds, 45, 1, 86_400),
		purchased = purchased,
		readyAt = readyAt,
		remaining = remaining,
		unlocked = unlocked,
		status = status,
		canOrder = profile ~= nil and profile.loaded == true and not profile.releasing
			and viewerProfile ~= nil and partyIsHost(viewerProfile.player)
			and partyCanProgress() and not purchased,
	}
end

local function syncSecretBunkerAttributes(_profile)
	local bunkerState = secretBunkerSnapshot(hostProfile())
	for _, player in ipairs(Players:GetPlayers()) do
		if partyIsMember(player) then
			player:SetAttribute("CooperSecretBunkerId", bunkerState.id)
			player:SetAttribute("CooperSecretBunkerPurchased", bunkerState.purchased)
			player:SetAttribute("CooperSecretBunkerReadyAt", bunkerState.readyAt)
			player:SetAttribute("CooperSecretBunkerUnlocked", bunkerState.unlocked)
			player:SetAttribute("CooperSecretBunkerStatus", bunkerState.status)
		end
	end
end

local function chemistrySetupSnapshot(profile, viewerProfile)
	viewerProfile = viewerProfile or profile
	local purchased = profile ~= nil and profile.data.chemistrySetupPurchased == true
	local placed = profile ~= nil and profile.data.chemistrySetupPlaced == true
	local deliveryStatus = purchased and not placed
		and (profile.chemistryDeliveryStep or "WaitingDelivery")
		or nil
	local status = if not purchased
		then "Available"
		elseif placed
		then "Installed"
		else deliveryStatus or "WaitingDelivery"
	local bunkerState = secretBunkerSnapshot(profile, viewerProfile)
	local hasOtherDelivery = profile ~= nil and (
		profile.data.pendingPartStage > 0
		or (profile.data.boomboxPurchased and not profile.data.boomboxPlaced)
		or profile.data.pendingTaskUpgradeId ~= ""
		or (partySession.task ~= nil
			and partySession.task.id == "GeorgeBeer"
			and (partySession.task.step == "WaitingDelivery"
				or partySession.task.step == "Collect"
				or partySession.task.step == "Deliver"))
	)
	return {
		id = chemistrySetupConfig.Id,
		name = chemistrySetupConfig.Name,
		price = finiteInteger(chemistrySetupConfig.Price, 1800, 1, 2_000_000_000),
		modelName = chemistrySetupConfig.ModelName,
		installTarget = chemistrySetupConfig.InstallTarget,
		description = chemistrySetupConfig.Description,
		purchased = purchased,
		placed = placed,
		installed = placed,
		status = status,
		deliveryStatus = deliveryStatus,
		bunkerUnlocked = bunkerState.unlocked == true,
		canOrder = profile ~= nil
			and profile.loaded == true
			and not profile.releasing
			and viewerProfile ~= nil
			and partyIsHost(viewerProfile.player)
			and partyCanProgress()
			and bunkerState.unlocked == true
			and not purchased
			and not hasOtherDelivery,
	}
end

local function syncChemistrySetupAttributes(_profile)
	local chemistryState = chemistrySetupSnapshot(hostProfile())
	for _, player in ipairs(Players:GetPlayers()) do
		if partyIsMember(player) then
			player:SetAttribute("CooperChemistrySetupPurchased", chemistryState.purchased)
			player:SetAttribute("CooperChemistrySetupPlaced", chemistryState.placed)
			player:SetAttribute("CooperChemistrySetupStatus", chemistryState.status)
		end
	end
end

local function candyDeliverySnapshot(profile)
	local active = profile ~= nil
		and profile.data.candyDeliveryActive == true
	local batchReady = profile ~= nil
		and not active
		and profile.data.candyBatchReady == true
	return {
		id = candyDeliveryConfig.Id,
		name = candyDeliveryConfig.Name,
		productToolName = candyDeliveryConfig.ProductToolName,
		payout = finiteInteger(candyDeliveryConfig.Payout, 3000, 1, 2_000_000_000),
		logoName = candyDeliveryConfig.LogoName,
		logoAssetId = candyDeliveryConfig.LogoAssetId,
		batchReady = batchReady,
		readyBatchToken = batchReady and profile.data.candyBatchToken or nil,
		active = active,
		status = active and "Deliver" or (batchReady and "CollectFromLab" or "Inactive"),
		targetHint = active and ("CandyDeliveryDropoff_" .. tostring(profile.player.UserId)) or nil,
		batchToken = active and profile.data.candyDeliveryToken or nil,
		batchesSold = profile and finiteInteger(profile.data.candyBatchesSold, 0, 0, 10_000_000) or 0,
	}
end

local function syncCandyDeliveryAttributes(profile)
	local player = profile and profile.player
	if not player or player.Parent ~= Players then
		return
	end
	local deliveryState = candyDeliverySnapshot(profile)
	player:SetAttribute("CooperCandyBatchReady", deliveryState.batchReady)
	player:SetAttribute("CooperCandyDeliveryActive", deliveryState.active)
	player:SetAttribute("CooperCandyDeliveryPayout", deliveryState.payout)
	player:SetAttribute("CooperCandyBatchesSold", deliveryState.batchesSold)
end

-- The attributes above are the durable replay surface for a construction
-- controller that starts after this script. These bounded duplicate events make
-- the normal startup path immediate as well; consumers must de-duplicate by
-- requestKey because BindableEvents do not retain messages.
local function requestSecretBunkerPresentation(profile, reason)
	if not profile or not profile.loaded or profile.releasing
		or profile.data.secretBunkerPurchased ~= true
	then
		return false
	end
	local player = profile.player
	local expectedReadyAt = finiteInteger(profile.data.secretBunkerReadyAt, 1, 1, 4_102_444_800)
	local requestKey = string.format("%d:%d", player.UserId, expectedReadyAt)
	local function emit()
		if profiles[player] ~= profile or player.Parent ~= Players or not profile.loaded or profile.releasing
			or profile.data.secretBunkerPurchased ~= true
			or profile.data.secretBunkerReadyAt ~= expectedReadyAt
		then
			return
		end
		local bunkerState = secretBunkerSnapshot(profile)
		requestBunkerConstruction:Fire(player, {
			requestKey = requestKey,
			id = bunkerState.id,
			name = bunkerState.name,
			price = bunkerState.price,
			constructionSeconds = bunkerState.constructionSeconds,
			readyAt = bunkerState.readyAt,
			remaining = bunkerState.remaining,
			status = bunkerState.status,
			unlocked = bunkerState.unlocked,
			instant = bunkerState.unlocked,
			resumed = reason == "ProfileLoadedResume",
			reason = tostring(reason or "StateReplay"),
			serverUnixTime = unixNow(),
		})
	end
	emit()
	task.delay(1.5, emit)
	task.delay(4.5, emit)
	return true
end

local function taskDescription(profile)
	local record = partySession.task
	if not record then
		return nil
	end
	local definition = taskById[record.id]
	if not definition then
		return nil
	end
	local description = definition.startDescription
	local targetHint = definition.startTarget
	local guidance = definition.guidance
	local automationDefinition = record.automated and automationById[record.automationUpgradeId] or nil

	if automationDefinition then
		description = string.format("%s is handling this task automatically.", automationDefinition.name)
		targetHint = nil
		guidance = false
	elseif record.id == "GeorgeBeer" then
		if record.step == "WaitingDelivery" then
			description = "The delivery truck is on its way. Wait near the driveway."
			targetHint = "DeliveryDropZone"
		elseif record.step == "Collect" then
			description = "Pick up George's beer crate from the driveway."
			targetHint = "Delivery_" .. tostring(record.carrierUserId or partySession.hostUserId)
		elseif record.step == "Deliver" then
			description = "Carry the beer crate to the kitchen refrigerator."
			targetHint = "GeorgeBeerDropAnchor"
		end
	elseif record.id == "MaryTrash" then
		if record.step == "Deliver" then
			description = "Carry the trash bag to the garage-side garbage can outside."
			targetHint = "OutdoorTrashAnchor"
		end
	elseif record.id == "MissyPlush" then
		if record.step == "Search" then
			guidance = true
			targetHint = record.markerName
			description = string.format(
				"Missy's %s is hidden somewhere inside the house. Follow the glowing arrow.",
				string.lower(tostring(record.plushKind or "toy"))
			)
		else
			guidance = true
			description = "Return Missy's stuffed animal to the toy spot on her bed."
			targetHint = "MissyPlushReturnAnchor"
		end
	elseif record.id == BANK_TASK_ID then
		if record.step == "Preview" then
			description = "BANKLINK is transmitting an access pattern. Watch the keyboard carefully."
			targetHint = "Keyboard"
		elseif record.step == "Input" then
			description = "Repeat the illuminated keyboard pattern before the trace timer expires."
			targetHint = "Keyboard"
		elseif record.step == "RoundPause" then
			description = "Access layer cleared. Stand by for the next, longer pattern."
			targetHint = "Keyboard"
		elseif record.step == "RetryCooldown" then
			description = "The bank trace caught that attempt. BANKLINK is resetting for another try."
			targetHint = "Keyboard"
		else
			description = "Use Sheldon's computer and choose HACK MEDFORD BANK to begin the memory game."
			targetHint = "Keyboard"
		end
	end

	local viewerUserId = profile and profile.player and profile.player.UserId or 0
	local carrierUserId = tonumber(record.carrierUserId)
	local carrierOwnsCurrentStep = carrierUserId ~= nil
		and carrierUserId ~= viewerUserId
		and ((record.id == "MaryTrash" and record.step == "Deliver")
			or (record.id == "MissyPlush" and record.step == "Return")
			or (record.id == "GeorgeBeer" and (record.step == "Collect" or record.step == "Deliver")))
	if carrierOwnsCurrentStep then
		description = "A teammate is carrying the task item. Help clear the way while they finish this step."
		targetHint = nil
		guidance = false
	elseif record.id == BANK_TASK_ID
		and record.bankActorUserId ~= nil
		and tonumber(record.bankActorUserId) ~= viewerUserId
	then
		description = "A teammate is using BANKLINK. Their memory-game result will advance the shared task for everyone."
		targetHint = nil
		guidance = false
	end

	return {
		id = definition.id,
		title = definition.title,
		requester = definition.requester,
		reward = record.id == BANK_TASK_ID
			and finiteInteger(record.bankReward, bankHackReward(hostProfile() or profile), 0, 2_000_000_000)
			or definition.reward,
		description = description,
		guidance = guidance,
		targetHint = targetHint,
		step = record.step,
		stepIndex = record.stepIndex,
		plushKind = record.plushKind,
		automated = record.automated == true,
		automationUpgradeId = record.automationUpgradeId,
		automationCompletesAt = record.automationCompletesAt,
		carrierUserId = record.carrierUserId,
		actorUserId = record.bankActorUserId,
		token = record.token,
	}
end

local function bankHackSnapshot(profile)
	local record = partySession.task
	local active = record ~= nil and record.id == BANK_TASK_ID
	local session = profile.bankHackSession
	local actorUserId = active and tonumber(record.bankActorUserId) or nil
	local occupiedByOther = actorUserId ~= nil and actorUserId ~= profile.player.UserId
	local currentTime = serverNow()
	local retryReadyAt = active and tonumber(record.bankRetryReadyAt) or nil
	local retryRemaining = retryReadyAt and math.max(0, retryReadyAt - currentTime) or 0
	local ready = active and (record.step == "Ready"
		or (record.step == "RetryCooldown" and retryRemaining <= 0))
	local status = "Unavailable"
	if active then
		if session then
			status = tostring(session.phase or "Active")
		elseif retryRemaining > 0 then
			status = "RetryCooldown"
		elseif ready then
			status = "Ready"
		else
			status = tostring(record.step or "Unavailable")
		end
	end
	return {
		taskActive = active,
		canStart = ready and session == nil and not occupiedByOther and partyCanProgress(),
		activeSession = session ~= nil,
		status = occupiedByOther and "InUse" or status,
		actorUserId = actorUserId,
		occupiedByOther = occupiedByOther,
		cycle = active
			and finiteInteger(record.bankCycle, bankHackSuccessCount(profile) + 1, 1, 1_000_001)
			or bankHackSuccessCount(profile) + 1,
		successes = bankHackSuccessCount(profile),
		reward = active
			and finiteInteger(record.bankReward, bankHackReward(profile), 0, 2_000_000_000)
			or bankHackReward(profile),
		round = session and finiteInteger(session.round, 0, 0, bankHackConfig.RoundCount) or 0,
		roundCount = finiteInteger(bankHackConfig.RoundCount, 4, 1, 20),
		startingLength = active
			and finiteInteger(record.bankStartingLength, bankHackStartingLength(profile), 1, 100)
			or bankHackStartingLength(profile),
		previewStepSeconds = active
			and math.max(0.05, tonumber(record.bankPreviewStepSeconds) or bankHackPreviewStep(profile))
			or bankHackPreviewStep(profile),
		retryReadyAt = retryReadyAt,
		retryRemaining = retryRemaining,
	}
end

local function hiddenSnapshot(profile)
	local record = partySession.task
	if not record then
		return nil
	end
	if not record.automated and record.id == "MissyPlush" and record.step == "Search" then
		return {
			kind = "Plush",
			markerName = record.markerName,
			plushKind = record.plushKind,
		}
	end
	return nil
end

local function boomboxSnapshot(profile, viewerProfile)
	viewerProfile = viewerProfile or profile
	local purchased = profile.data.boomboxPurchased == true
	local placed = profile.data.boomboxPlaced == true
	local autoplayPurchased = purchased and profile.data.boomboxAutoplayPurchased == true
	local playback = viewerProfile and viewerProfile.boomboxPlayback or nil
	local globalPlaybackProfile = boomboxPlaybackOwner and profiles[boomboxPlaybackOwner] or nil
	local globalPlayback = globalPlaybackProfile and globalPlaybackProfile.boomboxPlayback or nil
	local globallyPlaying = globalPlayback ~= nil
	local occupiedByOther = globallyPlaying
		and (not viewerProfile or boomboxPlaybackOwner ~= viewerProfile.player)
	local remaining = math.max(0, profile.data.boomboxNextPlayAt - unixNow())
	local deliveryStatus = purchased and not placed
		and (profile.boomboxDeliveryStep or "WaitingDelivery")
		or nil
	local status
	local targetHint
	if not purchased then
		status = "Available"
	elseif not placed then
		status = deliveryStatus
		if viewerProfile and partyIsHost(viewerProfile.player) then
			targetHint = if deliveryStatus == "Install"
				then "BoomboxSetupAnchor"
				elseif deliveryStatus == "Collect"
					then "Delivery_Boombox_" .. tostring(profile.player.UserId)
					else "DeliveryDropZone"
		end
	elseif globallyPlaying then
		status = "Playing"
	elseif remaining > 0 then
		status = "Cooldown"
	else
		status = "Ready"
	end
	return {
		price = Config.Boombox.Price,
		autoplayPrice = Config.Boombox.AutoplayUpgradePrice,
		autoplayPurchased = autoplayPurchased,
		audioId = Config.Boombox.AudioId,
		trackDuration = Config.Boombox.TrackDuration,
		payoutPerTick = Config.Boombox.PayoutPerTick,
		maximumPaidTicks = Config.Boombox.MaximumPaidTicks,
		payoutInterval = Config.Boombox.PayoutInterval,
		maximumPayout = Config.Boombox.PayoutPerTick * Config.Boombox.MaximumPaidTicks,
		cooldownSeconds = Config.Boombox.CooldownSeconds,
		purchased = purchased,
		placed = placed,
		active = globallyPlaying,
		playing = globallyPlaying,
		playbackOwnerUserId = globallyPlaying and boomboxPlaybackOwner.UserId or nil,
		occupiedByOther = occupiedByOther,
		ownsPlayback = playback ~= nil,
		status = status,
		deliveryStatus = deliveryStatus,
		targetHint = targetHint,
		nextPlayAt = profile.data.boomboxNextPlayAt,
		cooldownRemaining = remaining,
		canOrder = viewerProfile ~= nil and partyIsHost(viewerProfile.player)
			and partyCanProgress() and not purchased
			and profile.data.pendingPartStage == 0
			and profile.data.pendingTaskUpgradeId == ""
			and (not profile.data.chemistrySetupPurchased or profile.data.chemistrySetupPlaced),
		canUpgradeAutoplay = viewerProfile ~= nil and partyIsHost(viewerProfile.player)
			and partyCanProgress()
			and purchased and placed and not autoplayPurchased,
		canPlay = viewerProfile ~= nil and partyIsHost(viewerProfile.player)
			and partyCanProgress()
			and placed and not globallyPlaying and remaining <= 0,
	}
end

local function automationSnapshot(profile, viewerProfile)
	viewerProfile = viewerProfile or profile
	local installed = profile and profile.data.taskAutomationInstalled or {}
	local pendingId = profile and profile.data.pendingTaskUpgradeId or ""
	local activeRecord = partySession.task
	local activeRuns = {}
	for runId, record in pairs(profile and profile.automationRuns or {}) do
		local definition = record and automationById[record.automationUpgradeId] or nil
		if definition then
			table.insert(activeRuns, {
				runId = runId,
				taskId = record.id,
				upgradeId = definition.id,
				name = definition.name,
				plushKind = record.plushKind,
				startedAt = record.automationStartedAt,
				completesAt = record.automationCompletesAt,
			})
		end
	end
	table.sort(activeRuns, function(left, right)
		local leftStarted = tonumber(left.startedAt) or 0
		local rightStarted = tonumber(right.startedAt) or 0
		return leftStarted == rightStarted
			and tostring(left.runId) < tostring(right.runId)
			or leftStarted < rightStarted
	end)
	local beerDeliveryInProgress = activeRecord ~= nil
		and activeRecord.id == "GeorgeBeer"
		and (activeRecord.step == "WaitingDelivery"
			or activeRecord.step == "Collect"
			or activeRecord.step == "Deliver")
	local catalog = {}
	for _, definition in ipairs(Config.TaskAutomationUpgrades) do
		local isInstalled = installed[definition.id] == true
		local isPending = pendingId == definition.id
		table.insert(catalog, {
			id = definition.id,
			taskId = definition.taskId,
			name = definition.name,
			price = definition.price,
			duration = definition.duration,
			installTarget = definition.installTarget,
			modelName = definition.modelName,
			description = definition.description,
			reward = definition.taskId == BANK_TASK_ID
				and bankHackReward(profile)
				or (taskById[definition.taskId] and taskById[definition.taskId].reward or 0),
			installed = isInstalled,
			pending = isPending,
			canOrder = profile ~= nil
				and viewerProfile ~= nil
				and partyIsHost(viewerProfile.player)
				and partyCanProgress()
				and not isInstalled
					and pendingId == ""
					and profile.data.pendingPartStage == 0
					and (not profile.data.boomboxPurchased or profile.data.boomboxPlaced)
					and (not profile.data.chemistrySetupPurchased or profile.data.chemistrySetupPlaced)
					and not beerDeliveryInProgress,
		})
	end
	local installedCount = 0
	for _, definition in ipairs(Config.TaskAutomationUpgrades) do
		if installed[definition.id] == true then
			installedCount += 1
		end
	end
	return {
		catalog = catalog,
		installedCount = installedCount,
		totalCount = #Config.TaskAutomationUpgrades,
		pendingId = pendingId ~= "" and pendingId or nil,
		activeRuns = activeRuns,
		activeTaskId = activeRuns[1] and activeRuns[1].taskId
			or (activeRecord and activeRecord.automated and activeRecord.id or nil),
		activeUpgradeId = activeRuns[1] and activeRuns[1].upgradeId
			or (activeRecord and activeRecord.automated and activeRecord.automationUpgradeId or nil),
	}
end

local function deliverySnapshot(profile, viewerProfile)
	viewerProfile = viewerProfile or profile
	local viewerIsHost = viewerProfile ~= nil and partyIsHost(viewerProfile.player)
	local ownerUserId = profile.player and profile.player.UserId or partySession.hostUserId
	if profile.data.pendingPartStage > 0 then
		local definition = Config.MachineStages[profile.data.pendingPartStage]
		return {
			kind = "MachinePart",
			stage = profile.data.pendingPartStage,
			name = definition and definition.name or "Time Machine Component",
			status = profile.partDeliveryStep or "WaitingDelivery",
			targetHint = viewerIsHost and (if profile.partDeliveryStep == "Install"
				then "MachineInstallBay"
				else (profile.partDeliveryStep == "Collect"
					and ("Delivery_" .. tostring(profile.player.UserId))
					or "DeliveryDropZone")) or nil,
			hostOnly = true,
			ownerUserId = ownerUserId,
		}
	elseif profile.data.boomboxPurchased and not profile.data.boomboxPlaced then
		local deliveryStatus = profile.boomboxDeliveryStep or "WaitingDelivery"
		return {
			kind = "Boombox",
			stage = 0,
			name = "Cooper Party Boombox",
			status = deliveryStatus,
			targetHint = viewerIsHost and (if deliveryStatus == "Install"
				then "BoomboxSetupAnchor"
				elseif deliveryStatus == "Collect"
					then "Delivery_Boombox_" .. tostring(profile.player.UserId)
					else "DeliveryDropZone") or nil,
			hostOnly = true,
			ownerUserId = ownerUserId,
		}
	elseif profile.data.pendingTaskUpgradeId ~= "" then
		local upgradeId = profile.data.pendingTaskUpgradeId
		local definition = automationById[upgradeId]
		local deliveryStatus = profile.taskUpgradeDeliveryStep or "WaitingDelivery"
		return {
			kind = "TaskUpgrade",
			upgradeId = upgradeId,
			name = definition and definition.name or "Task Automation Upgrade",
			status = deliveryStatus,
			targetHint = viewerIsHost and (if deliveryStatus == "Install"
				then (definition and definition.installTarget or nil)
				elseif deliveryStatus == "Collect"
					then "Delivery_TaskUpgrade_" .. tostring(profile.player.UserId)
					else "DeliveryDropZone") or nil,
			hostOnly = true,
			ownerUserId = ownerUserId,
		}
	elseif profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced then
		local deliveryStatus = profile.chemistryDeliveryStep or "WaitingDelivery"
		return {
			kind = "ChemistrySetup",
			stage = 0,
			name = chemistrySetupConfig.Name,
			status = deliveryStatus,
			targetHint = viewerIsHost and (if deliveryStatus == "Install"
				then "Delivery_ChemistrySetup_" .. tostring(profile.player.UserId)
				elseif deliveryStatus == "Collect"
					then "Delivery_ChemistrySetup_" .. tostring(profile.player.UserId)
					else "DeliveryDropZone") or nil,
			hostOnly = true,
			ownerUserId = ownerUserId,
		}
	end
	return nil
end

local function snapshotFor(player)
	local profile = profiles[player]
	local worldProfile = hostProfile()
	if not profile or not profile.loaded or not worldProfile then
		return {
			revision = globalRevision,
			loaded = player == nil,
			allowance = 0,
			machineStage = 0,
			machineProgress = 0,
			tasks = {},
				boombox = {
					price = Config.Boombox.Price,
					purchased = false,
					placed = false,
					active = false,
					playing = false,
					status = "Loading",
				},
				secretBunker = {
					id = secretBunkerConfig.Id,
					name = secretBunkerConfig.Name,
					price = secretBunkerConfig.Price,
					constructionSeconds = secretBunkerConfig.ConstructionSeconds,
					purchased = false,
					readyAt = 0,
					remaining = 0,
					unlocked = false,
					status = "Loading",
					canOrder = false,
				},
				chemistrySetup = {
					id = chemistrySetupConfig.Id,
					name = chemistrySetupConfig.Name,
					price = chemistrySetupConfig.Price,
					purchased = false,
					placed = false,
					installed = false,
					status = "Loading",
					canOrder = false,
				},
				candyDelivery = {
					id = candyDeliveryConfig.Id,
					name = candyDeliveryConfig.Name,
					productToolName = candyDeliveryConfig.ProductToolName,
					payout = candyDeliveryConfig.Payout,
					logoName = candyDeliveryConfig.LogoName,
					logoAssetId = candyDeliveryConfig.LogoAssetId,
					batchReady = false,
					active = false,
					status = "Loading",
					batchesSold = 0,
				},
				automation = automationSnapshot(nil),
			bankHack = {
				taskActive = false,
				canStart = false,
				activeSession = false,
				status = "Loading",
				cycle = 1,
				successes = 0,
				reward = finiteInteger(bankHackConfig.BaseReward, 90, 0, 2_000_000_000),
				round = 0,
				roundCount = finiteInteger(bankHackConfig.RoundCount, 4, 1, 20),
				startingLength = finiteInteger(bankHackConfig.StartingLength, 2, 1, 100),
				previewStepSeconds = tonumber(bankHackConfig.BasePreviewStepSeconds) or 0.78,
			},
			party = {
				sessionId = partySession.id,
				hostUserId = partySession.hostUserId,
				isHost = player ~= nil and player.UserId == partySession.hostUserId,
				canManageHouse = false,
				personalAllowance = true,
				memberCount = #Players:GetPlayers(),
				state = partySession.state,
				reconnectRemaining = math.max(0, partySession.hostGraceDeadline - serverNow()),
				cycleIndex = math.floor(partySession.completedTasks / #Config.TaskOrder) + 1,
			},
		}
	end
	syncBoomboxPlacedAttribute(worldProfile)
	syncSecretBunkerAttributes(worldProfile)
	syncChemistrySetupAttributes(worldProfile)
	syncCandyDeliveryAttributes(profile)
	local currentTask = taskDescription(profile)
	local nextPart = nextMachinePart(worldProfile)
	return {
		revision = globalRevision,
		serverTime = serverNow(),
		serverUnixTime = unixNow(),
		loaded = true,
		allowance = profile.data.allowance,
		machineStage = worldProfile.data.machineStage,
		machineProgress = machineProgress(worldProfile.data.machineStage),
		machineStageName = worldProfile.data.machineStage > 0
			and Config.MachineStages[worldProfile.data.machineStage].name
			or "Blueprint Pending",
		nextMachinePart = nextPart and {
			stage = nextPart.stage,
			name = nextPart.name,
			progress = nextPart.progress,
			cost = nextPart.cost,
			canOrder = partyIsHost(player) and partyCanProgress()
				and worldProfile.data.pendingPartStage == 0
				and (not worldProfile.data.boomboxPurchased or worldProfile.data.boomboxPlaced)
				and worldProfile.data.pendingTaskUpgradeId == ""
				and (not worldProfile.data.chemistrySetupPurchased or worldProfile.data.chemistrySetupPlaced),
		} or nil,
		tasks = currentTask and { currentTask } or {},
		task = currentTask,
		hidden = hiddenSnapshot(profile),
		delivery = deliverySnapshot(worldProfile, profile),
		boombox = boomboxSnapshot(worldProfile, profile),
		secretBunker = secretBunkerSnapshot(worldProfile, profile),
		chemistrySetup = chemistrySetupSnapshot(worldProfile, profile),
		candyDelivery = candyDeliverySnapshot(profile),
		automation = automationSnapshot(worldProfile, profile),
		bankHack = bankHackSnapshot(profile),
		introNeeded = not profile.data.tutorialSeen,
		totalTasks = profile.data.totalTasks,
		party = {
			sessionId = partySession.id,
			hostUserId = partySession.hostUserId,
			isHost = partyIsHost(player),
			canManageHouse = partyIsHost(player) and partyCanProgress(),
			personalAllowance = true,
			memberCount = #presentProfiles(),
			state = partySession.state,
			reconnectRemaining = math.max(0, partySession.hostGraceDeadline - serverNow()),
			cycleIndex = math.floor(partySession.completedTasks / #Config.TaskOrder) + 1,
		},
	}
end

local function sendSnapshot(player)
	if player.Parent == Players then
		snapshotEvent:FireClient(player, snapshotFor(player))
	end
end

local function broadcastState()
	globalRevision += 1
	local worldProfile = hostProfile()
	local hostStage = worldProfile and worldProfile.data.machineStage or 0
	state:SetAttribute("SchemaVersion", Config.SchemaVersion)
	state:SetAttribute("ServerTime", serverNow())
	-- This is an additive snapshot extension, so retain the established V4
	-- foundation contract while advertising task automation explicitly below.
	state:SetAttribute("FoundationContract", "PartyV1")
	state:SetAttribute("SupportsPaidPartOrdering", true)
	state:SetAttribute("SupportsBoombox", true)
	state:SetAttribute("SupportsIncomeBoombox", true)
	state:SetAttribute("SupportsBoomboxAutoplay", true)
	state:SetAttribute("SupportsTaskAutomation", true)
	state:SetAttribute("SupportsMedfordBankHack", true)
	state:SetAttribute("SupportsSecretBunkerUnlock", true)
	state:SetAttribute("SupportsBunkerChemistrySetup", true)
	state:SetAttribute("SupportsCandyDelivery", true)
	state:SetAttribute("FeatureLobbyEnabled", Config.Features.Lobby == true)
	state:SetAttribute("FeatureHorrorEnabled", Config.Features.Horror == true)
	state:SetAttribute("FeatureSecretExplorationEnabled", Config.Features.SecretExploration == true)
	state:SetAttribute("FeatureTimeMachineFinaleEnabled", Config.Features.TimeMachineFinale == true)
	state:SetAttribute("FeaturePostgameEnabled", Config.Features.Postgame == true)
	state:SetAttribute("FeatureStudioScenarioToolsEnabled", Config.Features.StudioScenarioTools == true)
	state:SetAttribute("ReleasePlayerCap", Config.ReleasePlayerCap)
	state:SetAttribute("PartySessionId", partySession.id)
	state:SetAttribute("PartyHostUserId", partySession.hostUserId)
	state:SetAttribute("PartyState", partySession.state)
	state:SetAttribute("PartyMemberCount", #presentProfiles())
	state:SetAttribute("HostGraceDeadline", partySession.hostGraceDeadline)
	state:SetAttribute("MachineStage", hostStage)
	state:SetAttribute("MachineProgress", machineProgress(hostStage))
	state:SetAttribute("TaskRevision", globalRevision)
	for _, player in ipairs(Players:GetPlayers()) do
		setPartyPlayerAttributes(player)
		player:SetAttribute("MachineStage", hostStage)
		sendSnapshot(player)
	end
end

local function feedback(player, kind, payload)
	payload = type(payload) == "table" and payload or { text = tostring(payload) }
	payload.kind = kind
	if player and player.Parent == Players then
		feedbackEvent:FireClient(player, payload)
	elseif player == nil then
		feedbackEvent:FireAllClients(payload)
	end
end

local function saveProfile(player, releasing)
	local profile = profiles[player]
	if not profile then
		return true
	end
	if not profile.loaded then
		return profile.leaseLost ~= true
	end
	if releasing then
		profile.releasing = true
	end
	if profile.saving then
		-- Never report a transaction durable merely because an older writer is
		-- active. Wait for that writer to verify its captured revision; if this
		-- profile changed while UpdateAsync yielded, its dirty revision is then
		-- serialized through the same lease before this caller can return true.
		repeat
			task.wait(0.05)
		until not profile.saving
		if profile.player and profiles[profile.player] == profile then
			-- A guest may have reattached to a replacement Player instance while
			-- the writer was yielding. Continue against the same retained profile.
			player = profile.player
		elseif profiles[player] ~= profile then
			return not profile.dirty and profile.leaseLost ~= true
		end
	end
	local leaseRenewalDue = dataStore ~= nil
		and profile.leaseOwned == true
		and (profile.leaseExpiresAt or 0) <= unixNow() + PROFILE_LEASE_RENEW_WINDOW
	if not profile.dirty and not releasing and not leaseRenewalDue then
		return true
	end
	if not dataStore then
		profile.dirty = false
		return true
	end
	if not profile.leaseOwned then
		invalidateLostProfileLease(profile, "The profile no longer has a writable session lease.")
		return false
	end
	profile.saving = true
	local maximumAttempts = releasing and RELEASE_SAVE_ATTEMPTS or 3
	local attempt = 0
	local ok = true
	local failure
	local writeComplete = false
	local leaseRejected = false
	repeat
		attempt += 1
		writeComplete = false
		leaseRejected = false
		local savedRevision = profile.revision or 0
		local payload = sanitizeData(profile.data)
		payload.updatedAt = os.time()
		ok, failure = pcall(function()
			local callbackAccepted = false
			local result = dataStore:UpdateAsync(profileKey(player), function(current)
				-- A stale server may never overwrite a key once a newer session has
				-- claimed it. UpdateAsync retries this ownership check atomically if
				-- another writer changes the record during the transaction.
				callbackAccepted = false
				leaseRejected = false
				local owner = storedProfileLease(current)
				if owner ~= profile.leaseToken then
					leaseRejected = true
					return nil
				end
				payload[PROFILE_LEASE_FIELD] = {
					owner = profile.leaseToken,
					server = SERVER_PROFILE_SESSION_ID,
					expiresAt = os.time() + PROFILE_LEASE_SECONDS,
				}
				callbackAccepted = true
				return payload
			end)
			if leaseRejected or not callbackAccepted then
				error("Profile session lease is no longer owned by this server.")
			end
			local resultOwner, resultExpiresAt = storedProfileLease(result)
			if resultOwner ~= profile.leaseToken or resultExpiresAt <= os.time() then
				error("Profile session lease renewal could not be verified.")
			end
			profile.leaseExpiresAt = resultExpiresAt
			writeComplete = true
		end)
		if ok then
			-- Only clear dirty when the exact revision we captured was saved.
			-- A mutation during UpdateAsync remains dirty and is immediately
			-- followed by another serialized write.
			if (profile.revision or 0) == savedRevision then
				profile.dirty = false
			end
		elseif not leaseRejected then
			warn("[CooperGame] Profile save failed for " .. player.Name .. ": " .. tostring(failure))
			-- Immediate economy saves deserve the same bounded transient-failure
			-- recovery as release saves. Keep the profile dirty until a write
			-- succeeds, and never start a second writer while this lock is held.
			if attempt < maximumAttempts then
				task.wait(math.min(0.5 * attempt, 1.5))
			end
		end
	until leaseRejected or (writeComplete and not profile.dirty) or attempt >= maximumAttempts
	profile.saving = false
	if leaseRejected then
		if releasing then
			profile.leaseOwned = false
			profile.leaseLost = true
		else
			invalidateLostProfileLease(profile, failure)
		end
		return false
	end
	if releasing and writeComplete and not profile.dirty then
		local released, releaseFailure = releaseProfileLease(profile, RELEASE_SAVE_ATTEMPTS)
		if not released then
			warn("[CooperGame] Profile data saved but lease release failed for "
				.. player.Name .. ": " .. tostring(releaseFailure))
		end
		return released
	end
	if profile.dirty and ok and not releasing and profiles[player] == profile then
		-- Extremely rapid mutations can outrun the bounded loop. Hand the
		-- remaining revision to a fresh writer after releasing the save lock.
		task.defer(saveProfile, player, false)
	end
	return writeComplete and not profile.dirty
end

-- M1_SERVER_TRANSACTION_JOURNAL_CONTRACT
-- Operation ids are born here, never in a RemoteEvent payload. Every protected
-- value mutation and its committed record enter the same schema-12 profile
-- payload before saveProfile performs its lease-checked UpdateAsync write.
local TransactionRuntime = {}

function TransactionRuntime.activeSessionId()
	local sessionId = partySession.id
	if type(sessionId) ~= "string" or sessionId == "" or #sessionId > 160 then
		return nil
	end
	return sessionId
end

function TransactionRuntime.operationJournalFor(profile)
	local journal = profile and profile.data and profile.data.operationJournal or nil
	if type(journal) ~= "table"
		or type(journal.pending) ~= "table"
		or type(journal.committed) ~= "table"
	then
		journal = TransactionLedger.sanitize(journal)
		profile.data.operationJournal = journal
		markDirty(profile)
	end
	return journal
end

function TransactionRuntime.findLogicalOperation(profile, operationKind)
	local journal = TransactionRuntime.operationJournalFor(profile)
	for index = #journal.pending, 1, -1 do
		local record = journal.pending[index]
		if record.kind == operationKind and record.userId == profile.player.UserId then
			return record
		end
	end
	for index = #journal.committed, 1, -1 do
		local record = journal.committed[index]
		if record.kind == operationKind and record.userId == profile.player.UserId then
			return record
		end
	end
	return nil
end

function TransactionRuntime.hasBlockingReconciliation(profile)
	local journal = profile and profile.data and profile.data.operationJournal or nil
	if type(journal) ~= "table" or type(journal.pending) ~= "table" then
		return false
	end
	for _, record in ipairs(journal.pending) do
		if type(record) == "table" and record.state == "NeedsReconciliation" then
			return true
		end
	end
	return false
end

function TransactionRuntime.deepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for key, child in pairs(value) do
		copy[TransactionRuntime.deepCopy(key, seen)] = TransactionRuntime.deepCopy(child, seen)
	end
	return copy
end

function TransactionRuntime.safeSave(profile)
	local currentPlayer = profile and profile.player or nil
	if not currentPlayer or profiles[currentPlayer] ~= profile then
		return false, "ProfileDetachedFromRegistry"
	end
	local ok, savedOrFailure = pcall(saveProfile, currentPlayer, false)
	if not ok then
		return false, tostring(savedOrFailure)
	end
	if savedOrFailure == true then
		return true, nil
	end
	return false, "SaveUnconfirmed"
end

function TransactionRuntime.afterReconciliation(profile)
	profile.transactionReconciliationBlocked = TransactionRuntime.hasBlockingReconciliation(profile)
	local currentPlayer = profile.player
	if currentPlayer and profiles[currentPlayer] == profile and currentPlayer.Parent == Players then
		if TransactionRuntime.recoverWorld and partyIsHost(currentPlayer) then
			TransactionRuntime.recoverWorld(profile, currentPlayer)
		end
		broadcastState()
	end
end

function TransactionRuntime.deferReconciliationSave(profile, operationId, retryNumber, ownsSchedule)
	profile.reconciliationScheduled = profile.reconciliationScheduled or {}
	if ownsSchedule ~= true then
		if profile.reconciliationScheduled[operationId] ~= nil then
			return
		end
		profile.reconciliationScheduled[operationId] = true
	end
	retryNumber = finiteInteger(retryNumber, 0, 0, 20)
	local delaySeconds = retryNumber == 0 and 0 or math.min(2 ^ (retryNumber - 1), 30)
	task.delay(delaySeconds, function()
		while profile and profile.transactionInFlight do
			task.wait(0.05)
		end
		local currentPlayer = profile and profile.player or nil
		if not currentPlayer or profiles[currentPlayer] ~= profile
			or not profile.loaded or profile.releasing or profile.leaseLost
		then
			profile.reconciliationScheduled[operationId] = nil
			return
		end
		local journal = TransactionRuntime.operationJournalFor(profile)
		local record = TransactionLedger.lookup(journal, operationId)
		if not record or record.state == "Committed" or record.state == "RolledBack" then
			profile.reconciliationScheduled[operationId] = nil
			TransactionRuntime.afterReconciliation(profile)
			return
		end
		local result = record.result
		if record.state ~= "NeedsReconciliation"
			or type(result) ~= "table" or result.reconciliationCode ~= "SAVE_UNCONFIRMED"
		then
			profile.transactionReconciliationBlocked = true
			profile.reconciliationScheduled[operationId] = "Manual"
			warn("[CooperGame] Manual reconciliation required for operation " .. tostring(operationId))
			return
		end

		profile.transactionInFlight = true
		local saved, saveFailure = TransactionRuntime.safeSave(profile)
		if not saved then
			profile.transactionInFlight = false
			warn(string.format(
				"[CooperGame] Operation %s remains marked NeedsReconciliation after a failed follow-up save: %s",
				tostring(operationId),
				tostring(saveFailure)
			))
			TransactionRuntime.deferReconciliationSave(profile, operationId, retryNumber + 1, true)
			return
		end

		-- Once the value and SAVE_UNCONFIRMED marker have been verified in one
		-- payload, finalizing the same record requires no second value mutation.
		-- A failure of this metadata-only write returns it to reconciliation.
		journal = TransactionRuntime.operationJournalFor(profile)
		record = TransactionLedger.lookup(journal, operationId)
		result = record and record.result or nil
		if record and record.state == "NeedsReconciliation"
			and type(result) == "table" and result.reconciliationCode == "SAVE_UNCONFIRMED"
		then
			local committed = TransactionLedger.commit(journal, operationId, result, unixNow())
			if committed then
				markDirty(profile)
				local metadataSaved = TransactionRuntime.safeSave(profile)
				if not metadataSaved then
					TransactionLedger.markNeedsReconciliation(
						journal,
						operationId,
						"Reconciliation metadata save could not be verified",
						"SAVE_UNCONFIRMED"
					)
					markDirty(profile)
					profile.transactionInFlight = false
					TransactionRuntime.deferReconciliationSave(profile, operationId, retryNumber + 1, true)
					return
				end
			end
		end
		profile.transactionInFlight = false
		profile.reconciliationScheduled[operationId] = nil
		TransactionRuntime.afterReconciliation(profile)
	end)
end

function TransactionRuntime.resumePersistedReconciliations(profile)
	local journal = TransactionRuntime.operationJournalFor(profile)
	local pendingSnapshot = table.clone(journal.pending)
	local retiredAbandonedReservation = false
	for _, record in ipairs(pendingSnapshot) do
		if record.state == "NeedsReconciliation" then
			TransactionRuntime.deferReconciliationSave(profile, record.id, 0)
		elseif record.state == "Pending" then
			-- Authoritative code never yields between reservation and mutation. A
			-- raw Pending record recovered from storage therefore represents an
			-- abandoned pre-mutation reservation, not an applied value.
			TransactionLedger.rollback(journal, record.id, "AbandonedReservationOnLoad", unixNow())
			retiredAbandonedReservation = true
		end
	end
	if retiredAbandonedReservation then
		markDirty(profile)
	end
end

-- Reserve the immutable identity before any save can yield. The caller may
-- publish a `Committing` eligibility state immediately, preventing a grace
-- expiry callback from forfeiting an operation that is already in progress.
function TransactionRuntime.reserveProfileValueOperation(profile, kind, value, expectedSessionId)
	if not profile or not profile.loaded or profile.releasing or profile.leaseLost
		or profile.transactionReconciliationBlocked == true
	then
		return nil, "ProfileNotWritable"
	end
	local activeSessionId = TransactionRuntime.activeSessionId()
	if not activeSessionId or activeSessionId ~= expectedSessionId then
		return nil, "StaleSession"
	end
	if profile.transactionInFlight then
		return nil, "TransactionBusy"
	end
	local journal = TransactionRuntime.operationJournalFor(profile)
	local issuedOk, operationRecord = pcall(
		TransactionLedger.issue,
		journal,
		activeSessionId,
		kind,
		profile.player.UserId,
		finiteInteger(value, 0, -2_000_000_000, 2_000_000_000),
		finiteInteger(profile.revision, 0, 0, 2_000_000_000),
		unixNow(),
		HttpService:GenerateGUID(false)
	)
	if not issuedOk then
		warn("[CooperGame] Could not issue an authoritative operation: " .. tostring(operationRecord))
		return nil, "OperationIssueFailed"
	end
	local beganOk, began, existing = pcall(TransactionLedger.begin, journal, operationRecord)
	if not beganOk then
		warn("[CooperGame] Transaction journal rejected a new operation: " .. tostring(began))
		return nil, "JournalCapacity"
	end
	if not began then
		return existing, "DuplicateOperation"
	end
	markDirty(profile)
	return operationRecord, "Reserved"
end

-- Returns accepted, durable, appliedNow, operationRecord, statusCode.
-- accepted means the authoritative mutation is represented in this live
-- profile. durable means a lease-owned write containing both the value and
-- committed record was verified. A save failure never invokes mutate again;
-- the same record moves to NeedsReconciliation and a value-only retry is
-- forbidden.
function TransactionRuntime.commitProfileValueOperation(
	profile,
	kind,
	value,
	operationId,
	expectedSessionId,
	mutate,
	authorize
)
	if not profile or not profile.loaded or profile.releasing or profile.leaseLost then
		return false, false, false, nil, "ProfileNotWritable"
	end
	local activeSessionId = TransactionRuntime.activeSessionId()
	if not activeSessionId or expectedSessionId ~= activeSessionId then
		return false, false, false, nil, "StaleSession"
	end
	if type(kind) ~= "string" or type(mutate) ~= "function" then
		return false, false, false, nil, "InvalidServerOperation"
	end
	while profile.transactionInFlight do
		task.wait(0.05)
		if not profile.loaded or profile.releasing or profile.leaseLost
			or TransactionRuntime.activeSessionId() ~= expectedSessionId
		then
			return false, false, false, nil, "StaleOrClosedWhileQueued"
		end
	end
	local journal = TransactionRuntime.operationJournalFor(profile)
	local existing = type(operationId) == "string" and TransactionLedger.lookup(journal, operationId) or nil
	if existing then
		if not TransactionLedger.sessionMatches(existing, activeSessionId) then
			return false, false, false, existing, "StaleSession"
		end
		if existing.kind ~= kind or existing.userId ~= profile.player.UserId
			or existing.value ~= finiteInteger(value, 0, -2_000_000_000, 2_000_000_000)
		then
			return false, false, false, existing, "OperationIdentityMismatch"
		end
		-- A retry is answered from the terminal server-issued record before current
		-- purchase preconditions are evaluated. Entitlement state normally changes
		-- because the first attempt succeeded; that must not turn an exactly-once
		-- committed retry into AuthorityRevoked.
		if existing.state == "Committed" then
			return true, true, false, existing, "AlreadyCommitted"
		elseif existing.state == "RolledBack" then
			return false, true, false, existing, "RolledBack"
		elseif existing.state == "NeedsReconciliation" then
			TransactionRuntime.deferReconciliationSave(profile, operationId, 0)
			return true, false, false, existing, "NeedsReconciliation"
		elseif existing.state ~= "Pending" then
			return false, false, false, existing, "InvalidOperationState"
		end
	elseif operationId ~= nil then
		return false, false, false, nil, "UnknownServerOperation"
	end
	if profile.transactionReconciliationBlocked == true then
		-- A profile-wide ambiguous save blocks every new/Pending value mutation,
		-- but it must not hide an authoritative terminal answer above (including
		-- the exact NeedsReconciliation record responsible for this flag).
		return false, false, false, existing, "ProfileNotWritable"
	end

	-- Authorization protects only a mutation that has not happened yet. Terminal
	-- retries above return their saved result without running mutable world-state
	-- preconditions a second time.
	if authorize ~= nil then
		local authorizeOk, authorized, denial = pcall(authorize)
		if not authorizeOk or authorized ~= true then
			return false, false, false, existing, authorizeOk and tostring(denial or "AuthorityRevoked") or "AuthorityCheckFailed"
		end
	end

	if operationId == nil then
		local reserveStatus
		existing, reserveStatus = TransactionRuntime.reserveProfileValueOperation(
			profile,
			kind,
			value,
			expectedSessionId
		)
		if not existing then
			return false, false, false, nil, reserveStatus
		end
		operationId = existing.id
	end
	if not existing then
		return false, false, false, nil, "UnknownServerOperation"
	end

	local operationRecord = existing
	local beforeData = TransactionRuntime.deepCopy(profile.data)
	local beforeRevision = profile.revision
	local beforeDirty = profile.dirty
	profile.transactionInFlight = true
	local mutationOk, mutationResult = pcall(mutate, operationRecord)
	if not mutationOk then
		-- Restore the exact pre-mutation snapshot, then retire the operation id.
		-- A callback that changed allowance before throwing cannot leak a debit or
		-- reward, and the rolled-back id can never be replayed after journal trim.
		profile.data = beforeData
		profile.revision = beforeRevision
		profile.dirty = beforeDirty
		setAllowance(profile, profile.data.allowance, false)
		journal = TransactionRuntime.operationJournalFor(profile)
		TransactionLedger.rollback(journal, operationId, tostring(mutationResult), unixNow())
		markDirty(profile)
		TransactionRuntime.safeSave(profile)
		profile.transactionInFlight = false
		warn("[CooperGame] Authoritative value mutation failed closed: " .. tostring(mutationResult))
		return false, false, false, operationRecord, "MutationFailed"
	end

	local result = type(mutationResult) == "table" and mutationResult or {}
	local commitOk, committed = pcall(TransactionLedger.commit, journal, operationId, result, unixNow())
	if not commitOk or not committed then
		profile.data = beforeData
		profile.revision = beforeRevision
		profile.dirty = beforeDirty
		setAllowance(profile, profile.data.allowance, false)
		journal = TransactionRuntime.operationJournalFor(profile)
		TransactionLedger.rollback(journal, operationId, "CommitFailed", unixNow())
		markDirty(profile)
		TransactionRuntime.safeSave(profile)
		profile.transactionInFlight = false
		return false, false, false, operationRecord, "CommitFailed"
	end

	markDirty(profile)
	local durable, saveFailure = TransactionRuntime.safeSave(profile)
	profile.transactionInFlight = false
	if not durable then
		TransactionLedger.markNeedsReconciliation(
			journal,
			operationId,
			"Lease-owned profile save could not be verified: " .. tostring(saveFailure),
			"SAVE_UNCONFIRMED"
		)
		markDirty(profile)
		profile.transactionReconciliationBlocked = true
		TransactionRuntime.deferReconciliationSave(profile, operationId, 0)
		return true, false, true, committed, "NeedsReconciliation"
	end
	profile.transactionReconciliationBlocked = false
	return true, true, true, committed, "Committed"
end

local function pickHiddenLocation(profile)
	local previous = partySession.lastHiddenMarker
	local choices = {}
	for _, definition in ipairs(Config.HiddenLocations) do
		if definition.name ~= previous and taskLocation(definition.name) then
			table.insert(choices, definition)
		end
	end
	if #choices == 0 then
		choices = Config.HiddenLocations
	end
	local chosen = choices[randomizer:NextInteger(1, #choices)]
	partySession.lastHiddenMarker = chosen.name
	return chosen
end

local function taskCanStart(id)
	return taskById[id] ~= nil
end

local completeTask
local stockAutomatedBeer
local cancelBankHackSession
local returnSavedPartyToLobby
local closePartyAndReturn
local recoverHostWorldState
local automationRunSerial = 0

function TransactionRuntime.retryTaskCompletion(record, fallbackProfile)
	if not record or partySession.task ~= record or record.status ~= "Completing"
		or record.completionRetryScheduled == true
	then
		return
	end
	record.completionRetryScheduled = true
	task.delay(0.5, function()
		record.completionRetryScheduled = false
		if partySession.task ~= record or record.status ~= "Completing" then
			return
		end
		local retryProfile = hostProfile() or fallbackProfile
		if retryProfile and partyCanProgress() then
			completeTask(retryProfile, record)
		else
			TransactionRuntime.retryTaskCompletion(record, fallbackProfile)
		end
	end)
end

local function armTaskAutomation(record, definition)
	if not record or not definition or record.automated == true then
		return false
	end
	record.automationPreviousStep = record.step
	record.automated = true
	record.automationUpgradeId = definition.id
	record.automationStartedAt = serverNow()
	record.automationCompletesAt = record.automationStartedAt + definition.duration
	record.step = "Automated"
	return true
end

local function launchTaskAutomation(profile, record, definition)
	if not profile or partySession.task ~= record or not definition
		or record.automated ~= true or record.automationUpgradeId ~= definition.id
	then
		return false
	end
	automationRunSerial += 1
	local runId = string.format(
		"automation:%d:%s:%d:%s",
		profile.player.UserId,
		definition.id,
		automationRunSerial,
		HttpService:GenerateGUID(false)
	)
	record.automationRunId = runId
	if record.id == BANK_TASK_ID then
		-- HackerBot uses a server-only proof bound to this exact installed robot
		-- run. It never fakes client key input and cannot share the manual-memory
		-- challenge's validation bit with a stale or cancelled session.
		if definition.id ~= "HackerBot"
			or profile.data.taskAutomationInstalled.HackerBot ~= true
		then
			return false
		end
		if profile.bankHackSession and cancelBankHackSession then
			cancelBankHackSession(profile, "HackerBot took over the active bank task.", true)
		end
		record.bankAutomationRunId = runId
	end
	profile.automationRuns = type(profile.automationRuns) == "table" and profile.automationRuns or {}
	profile.automationRuns[runId] = record
	local metadata = {
		runId = runId,
		taskId = record.id,
		markerName = record.markerName,
		plushKind = record.plushKind,
		duration = definition.duration,
		installTarget = definition.installTarget,
		modelName = definition.modelName,
		previousStep = record.automationPreviousStep,
		startedAt = record.automationStartedAt,
		completesAt = record.automationCompletesAt,
		bankCycle = record.bankCycle,
		bankReward = record.bankReward,
	}
	feedback(profile.player, "TaskAutomationStarted", {
		title = definition.name,
		upgradeId = definition.id,
		taskId = record.id,
		duration = definition.duration,
		text = string.format("%s started working automatically.", definition.name),
	})
	runTaskAutomation:Fire(profile.player, definition.id, metadata)
	-- The robot has authoritatively accepted this chore, so reward it once and
	-- free the foreground slot immediately. Its visual run remains in activeRuns
	-- until the physical animation finishes, allowing the next request to arrive
	-- without turning the robot into a teleporting background effect.
	if not completeTask(profile, record) then
		profile.automationRuns[runId] = nil
		return false
	end
	record.automationVisualRemaining = definition.duration
	record.automationVisualLastTick = serverNow()
	task.spawn(function()
		while profile.loaded and not profile.releasing
			and profiles[profile.player] == profile
			and profile.automationRuns[runId] == record
		do
			task.wait(0.15)
			local now = serverNow()
			local lastTick = tonumber(record.automationVisualLastTick)
			if not lastTick or lastTick ~= lastTick or lastTick == math.huge or lastTick == -math.huge then
				lastTick = now
			end
			local elapsed = math.max(0, now - lastTick)
			record.automationVisualLastTick = now
			if partyCanProgress() and hostProfile() == profile then
				record.automationVisualRemaining = math.max(
					0,
					(tonumber(record.automationVisualRemaining) or 0) - elapsed
				)
			end
			record.automationCompletesAt = now + (tonumber(record.automationVisualRemaining) or 0)
			if (tonumber(record.automationVisualRemaining) or 0) <= 0 then
				profile.automationRuns[runId] = nil
				if definition.id == "BeerBot" then
					stockAutomatedBeer()
				end
				feedback(profile.player, "TaskAutomationFinished", {
					title = definition.name,
					upgradeId = definition.id,
					taskId = record.id,
					text = string.format("%s finished its physical task and returned home.", definition.name),
				})
				broadcastState()
				return
			end
		end
	end)
	return true
end

local function automationRunIsActive(profile, upgradeId)
	for _, record in pairs(profile.automationRuns or {}) do
		if record and record.automationUpgradeId == upgradeId then
			return true
		end
	end
	return false
end

-- M1_TASK_ELIGIBILITY_CONTRACT
-- A task's earners are captured exactly once at the authoritative start. The
-- frozen identity set is never recomputed from whoever happens to be connected
-- when the final prompt fires. Resolution is tracked separately so retries and
-- reconnects cannot manufacture a second identity or a duplicate payout.
local function captureTaskEligibility(version)
	local userIds = {}
	local memberSet = {}
	for userId, player in pairs(partySession.activePlayers) do
		local profile = profilesByUserId[userId]
		if partySession.expectedMembers[userId] == true
			and player.Parent == Players and profile and profile.player == player
			and profile.loaded and not profile.releasing and not profile.leaseLost
			and profile.detached ~= true
			and (dataStore == nil or profile.leaseOwned == true)
		then
			memberSet[userId] = true
			table.insert(userIds, userId)
		end
	end
	table.sort(userIds)
	return table.freeze({
		version = version,
		capturedAt = serverNow(),
		userIds = table.freeze(userIds),
		memberSet = table.freeze(memberSet),
	})
end

local function forfeitTaskEligibility(record, userId, reason)
	if not record or type(record.eligibility) ~= "table"
		or record.eligibility.memberSet[userId] ~= true
		or record.eligibilityResolutionByUserId[userId] ~= nil
	then
		return false
	end
	record.eligibilityResolutionByUserId[userId] = table.freeze({
		status = "Forfeited",
		reason = tostring(reason or "EligibilityUnavailable"),
		resolvedAt = serverNow(),
	})
	return true
end

local function eligibleProfileForTask(record, userId)
	if not record or type(record.eligibility) ~= "table"
		or record.eligibility.memberSet[userId] ~= true
	then
		return nil, "NotEligibleAtTaskStart"
	end
	local profile = profilesByUserId[userId]
	local activePlayer = partySession.activePlayers[userId]
	local admittedHydration = activePlayer and activePlayer.Parent == Players
		and profile and profile.player == activePlayer
		and hydratingProfiles[profile] == true
		and not profile.releasing and not profile.leaseLost
	if admittedHydration then
		if record.recoveredFromCalmTaskStart == true
			and unixNow() >= (tonumber(profile.hydrationGraceExpiresAtUnix) or 0)
		then
			return nil, "RecoveredTaskGraceExpired"
		end
		-- An admitted identity loading its exact profile is neither absent nor yet
		-- writable. Preserve it until the bounded admission deadline; completion
		-- retries after hydration instead of forfeiting at the recovery boundary.
		return nil, "ProfileLoading"
	end
	if not profile or not profile.loaded or profile.releasing or profile.leaseLost
		or (dataStore ~= nil and profile.leaseOwned ~= true)
	then
		if record.recoveredFromCalmTaskStart == true
			and unixNow() >= (tonumber(record.recoveryGraceExpiresAt) or math.huge)
		then
			return nil, "RecoveredTaskGraceExpired"
		end
		return nil, "ProfileNotWritable"
	end
	if activePlayer and activePlayer.Parent == Players and profile.player == activePlayer
		and profile.detached ~= true
	then
		return profile, nil
	end
	if userId ~= partySession.hostUserId and profile.detached == true then
		if serverNow() < (tonumber(profile.guestGraceDeadline) or 0) then
			-- The same retained profile and user id earn the already-captured task;
			-- a later reconnect merely reattaches this identity.
			return profile, nil
		end
		return nil, "GuestReconnectGraceExpired"
	end
	if userId ~= partySession.hostUserId and record.recoveredFromCalmTaskStart == true
		and unixNow() >= (tonumber(record.recoveryGraceExpiresAt) or math.huge)
	then
		return nil, "RecoveredTaskGraceExpired"
	end
	return nil, "EligibleMemberUnavailable"
end

function TransactionRuntime.checkpointValidation(profile, checkpoint)
	if type(checkpoint) ~= "table" or checkpoint.version ~= 1 then
		return false, "MissingCheckpoint"
	end
	local expectedOrdinal = finiteInteger(profile.data.totalTasks, 0, 0, 10_000_000) + 1
	if checkpoint.hostUserId ~= partySession.hostUserId
		or checkpoint.hostUserId ~= profile.player.UserId
	then
		return false, "WrongCheckpointHost"
	end
	if checkpoint.hostOrdinal < expectedOrdinal then
		return false, "StaleCheckpoint"
	elseif checkpoint.hostOrdinal > expectedOrdinal then
		return false, "FutureCheckpoint"
	end
	local expectedTaskId = Config.TaskOrder[((expectedOrdinal - 1) % #Config.TaskOrder) + 1]
	local expectedLogicalId = string.format(
		"%d:%d:%s",
		checkpoint.hostUserId,
		expectedOrdinal,
		expectedTaskId
	)
	if checkpoint.taskId ~= expectedTaskId or checkpoint.logicalId ~= expectedLogicalId then
		return false, "CheckpointIdentityMismatch"
	end
	return true, nil
end

function TransactionRuntime.eligibilityFromCheckpoint(checkpoint)
	local userIds = {}
	local memberSet = {}
	for _, userId in ipairs(checkpoint.eligibleUserIds) do
		memberSet[userId] = true
		table.insert(userIds, userId)
	end
	return table.freeze({
		version = checkpoint.hostOrdinal,
		capturedAt = serverNow(),
		capturedAtUnix = checkpoint.startedAtUnix,
		userIds = table.freeze(userIds),
		memberSet = table.freeze(memberSet),
	})
end

function TransactionRuntime.armRecoveredEligibilityGrace(profile, record, checkpoint)
	local expiresAt = finiteInteger(checkpoint.recoveryGraceExpiresAt, 0, 0, 4_102_444_800)
	if expiresAt <= 0 then
		return
	end
	task.spawn(function()
		local nextBoundaryUnix = expiresAt
		while partySession.task == record and record.status ~= "Completed" and not shuttingDown do
			while partySession.task == record and record.status ~= "Completed"
				and not shuttingDown and unixNow() < nextBoundaryUnix
			do
				task.wait(math.min(1, math.max(0.05, nextBoundaryUnix - unixNow())))
			end
			if partySession.task ~= record or record.status == "Completed" or shuttingDown then
				return
			end

			local nowUnix = unixNow()
			local laterBoundaryUnix: number? = nil
			local resolutionChanged = false
			for _, userId in ipairs(record.eligibility.userIds) do
				if userId ~= partySession.hostUserId
					and record.eligibilityResolutionByUserId[userId] == nil
				then
					local activePlayer = partySession.activePlayers[userId]
					local eligibleProfile = profilesByUserId[userId]
					local admitted = activePlayer and activePlayer.Parent == Players
						and eligibleProfile and eligibleProfile.player == activePlayer
					local active = admitted
						and eligibleProfile.loaded and not eligibleProfile.releasing
						and not eligibleProfile.leaseLost and eligibleProfile.detached ~= true
						and (dataStore == nil or eligibleProfile.leaseOwned == true)
					local loading = admitted and hydratingProfiles[eligibleProfile] == true
						and not eligibleProfile.releasing and not eligibleProfile.leaseLost
					local retainedInGuestGrace = eligibleProfile
						and eligibleProfile.detached == true
						and eligibleProfile.loaded and not eligibleProfile.releasing
						and not eligibleProfile.leaseLost
						and nowUnix < (tonumber(eligibleProfile.guestGraceUnixExpiresAt) or 0)
						and (dataStore == nil or eligibleProfile.leaseOwned == true)
					local retainedWhileLoading = loading
						and nowUnix < (tonumber(eligibleProfile.hydrationGraceExpiresAtUnix) or 0)

					if retainedInGuestGrace then
						local boundary = tonumber(eligibleProfile.guestGraceUnixExpiresAt) or nowUnix
						if laterBoundaryUnix == nil or boundary < laterBoundaryUnix then
							laterBoundaryUnix = boundary
						end
					elseif retainedWhileLoading then
						local boundary = tonumber(eligibleProfile.hydrationGraceExpiresAtUnix) or nowUnix
						if laterBoundaryUnix == nil or boundary < laterBoundaryUnix then
							laterBoundaryUnix = boundary
						end
					elseif not active then
						resolutionChanged = forfeitTaskEligibility(
							record,
							userId,
							"RecoveredTaskGraceExpired"
						) or resolutionChanged
					end
				end
			end
			if record.status == "Completing" then
				TransactionRuntime.retryTaskCompletion(record, profile)
			end
			if resolutionChanged then
				broadcastState()
			end
			if not laterBoundaryUnix then
				return
			end
			nextBoundaryUnix = laterBoundaryUnix
		end
	end)
end

function TransactionRuntime.exposeCalmTaskCheckpoint(profile, checkpoint, recovered)
	if partySession.task or not partyCanProgress() or hostProfile() ~= profile then
		return false
	end
	local valid, invalidReason = TransactionRuntime.checkpointValidation(profile, checkpoint)
	if not valid then
		if invalidReason == "StaleCheckpoint" then
			profile.data.calmTaskCheckpoint = nil
			profile.calmTaskCheckpointDurable = false
			markDirty(profile)
			TransactionRuntime.safeSave(profile)
		else
			warn("[CooperGame] CalmTaskStart checkpoint failed closed: " .. tostring(invalidReason))
		end
		return false
	end
	local id = checkpoint.taskId
	if not taskCanStart(id) then
		return false
	end
	-- Validate every task-specific dependency before changing the live scheduler.
	-- A missing marker or an already-running robot must leave the cursor, serial,
	-- plush rotation, and visible task untouched so the same durable checkpoint
	-- can be retried without skipping or duplicating work.
	if id == "MissyPlush"
		and (checkpoint.markerName == "" or not taskLocation(checkpoint.markerName))
	then
		warn("[CooperGame] Recovered Missy task checkpoint has no valid hidden marker")
		return false
	end
	local automationDefinition = automationByTaskId[id]
	if automationDefinition
		and profile.data.taskAutomationInstalled[automationDefinition.id] == true
		and automationRunIsActive(profile, automationDefinition.id)
	then
		partySession.nextTaskAt = serverNow() + 1
		return false
	end
	local nextCursor = ((checkpoint.hostOrdinal - 1) % #Config.TaskOrder) + 1
	local nextSerial = partySession.taskSerial + 1
	local record = {
		token = string.format("%s:%d", partySession.id, nextSerial),
		logicalId = checkpoint.logicalId,
		sessionId = partySession.id,
		id = id,
		step = "Start",
		startedAt = serverNow(),
		status = "Active",
		eligibility = TransactionRuntime.eligibilityFromCheckpoint(checkpoint),
		eligibilityResolutionByUserId = {},
		rewardOperationIdsByUserId = {},
		recoveredFromCalmTaskStart = recovered == true,
		recoveryGraceExpiresAt = recovered == true and checkpoint.recoveryGraceExpiresAt or 0,
	}
	if not recovered then
		for _, userId in ipairs(record.eligibility.userIds) do
			if userId ~= partySession.hostUserId and profilesByUserId[userId] == nil then
				-- This member was active when the durable snapshot was captured but
				-- exhausted guest grace while the checkpoint save was retrying.
				forfeitTaskEligibility(record, userId, "GuestGraceExpiredBeforeTaskExposure")
			end
		end
	end
	if id == "GeorgeBeer" then
		record.step = "Order"
	elseif id == "MaryTrash" then
		record.step = "Pickup"
	elseif id == "MissyPlush" then
		record.step = "Search"
		record.markerName = checkpoint.markerName
		record.plushKind = checkpoint.plushKind
	elseif id == BANK_TASK_ID then
		record.step = "Ready"
		record.bankCycle = checkpoint.bankCycle
		record.bankReward = checkpoint.bankReward
		record.bankPreviewStepSeconds = checkpoint.bankPreviewStepSeconds
		record.bankStartingLength = checkpoint.bankStartingLength
	end
	if automationDefinition
		and profile.data.taskAutomationInstalled[automationDefinition.id] == true
	then
		armTaskAutomation(record, automationDefinition)
	end
	-- CALM_TASK_START_EXPOSURE_AFTER_DURABLE_SAVE
	partySession.taskCursor = nextCursor
	partySession.taskSerial = nextSerial
	if id == "MissyPlush" then
		partySession.nextPlushKind = record.plushKind == "Rabbit" and "Teddy" or "Rabbit"
	end
	partySession.task = record
	profile.calmTaskCheckpointRecovered = false
	feedback(nil, "TaskStarted", {
		title = taskById[id].title,
		requester = taskById[id].requester,
		text = taskDescription(profile).description,
		recovered = recovered == true,
	})
	if recovered then
		TransactionRuntime.armRecoveredEligibilityGrace(profile, record, checkpoint)
	end
	if record.automated then
		launchTaskAutomation(profile, record, automationDefinition)
	end
	broadcastState()
	return true
end

function TransactionRuntime.commitCalmTaskStart(profile, recovered)
	local checkpoint = profile.data.calmTaskCheckpoint
	if not checkpoint or profile.calmTaskCheckpointWriteInFlight
		or profile.transactionInFlight or profile.transactionReconciliationBlocked
		or serverNow() < (tonumber(profile.calmTaskCheckpointRetryAt) or 0)
	then
		return false
	end
	local valid, _invalidReason = TransactionRuntime.checkpointValidation(profile, checkpoint)
	if not valid then
		return TransactionRuntime.exposeCalmTaskCheckpoint(profile, checkpoint, recovered)
	end
	if recovered and checkpoint.recoveryGraceExpiresAt <= 0 then
		checkpoint.recoveryGraceExpiresAt = unixNow() + partyConfig.GuestReconnectGraceSeconds
		profile.calmTaskCheckpointDurable = false
		markDirty(profile)
	end
	profile.calmTaskCheckpointWriteInFlight = true
	local durable = profile.calmTaskCheckpointDurable == true
	if not durable then
		durable = TransactionRuntime.safeSave(profile)
		profile.calmTaskCheckpointDurable = durable == true
	end
	profile.calmTaskCheckpointWriteInFlight = false
	if not durable then
		profile.calmTaskCheckpointRetryCount = math.min(
			(tonumber(profile.calmTaskCheckpointRetryCount) or 0) + 1,
			6
		)
		profile.calmTaskCheckpointRetryAt = serverNow()
			+ math.min(2 ^ (profile.calmTaskCheckpointRetryCount - 1), 30)
		warn("[CooperGame] CalmTaskStart checkpoint save was not verified; task exposure remains blocked")
		return false
	end
	profile.calmTaskCheckpointRetryCount = 0
	profile.calmTaskCheckpointRetryAt = 0
	return TransactionRuntime.exposeCalmTaskCheckpoint(profile, checkpoint, recovered)
end

local function startNextTask(profile)
	if not profile or not profile.loaded or not partyIsHost(profile.player)
		or not partyCanProgress() or partySession.task
	then
		return
	end
	if profile.data.calmTaskCheckpoint then
		TransactionRuntime.commitCalmTaskStart(
			profile,
			profile.calmTaskCheckpointRecovered == true
		)
		return
	end
	local order = Config.TaskOrder
	local nextCursor = (partySession.taskCursor % #order) + 1
	local id = order[nextCursor]
	if not id or not taskById[id] or not taskCanStart(id) then
		return
	end
	local automationDefinition = automationByTaskId[id]
	if automationDefinition
		and profile.data.taskAutomationInstalled[automationDefinition.id] == true
		and automationRunIsActive(profile, automationDefinition.id)
	then
		partySession.nextTaskAt = serverNow() + 1
		return
	end
	local eligibility = captureTaskEligibility(profile.data.totalTasks + 1)
	if eligibility.memberSet[profile.player.UserId] ~= true then
		return
	end
	local markerName = ""
	local plushKind = partySession.nextPlushKind == "Rabbit" and "Rabbit" or "Teddy Bear"
	if id == "MissyPlush" then
		markerName = pickHiddenLocation(profile).name
	end
	local hostOrdinal = finiteInteger(profile.data.totalTasks, 0, 0, 10_000_000) + 1
	profile.data.calmTaskCheckpoint = {
		version = 1,
		logicalId = string.format("%d:%d:%s", profile.player.UserId, hostOrdinal, id),
		taskId = id,
		hostUserId = profile.player.UserId,
		hostOrdinal = hostOrdinal,
		eligibleUserIds = table.clone(eligibility.userIds),
		startedAtUnix = unixNow(),
		recoveryGraceExpiresAt = 0,
		markerName = markerName,
		plushKind = plushKind,
		bankCycle = id == BANK_TASK_ID and (bankHackSuccessCount(profile) + 1) or 1,
		bankReward = id == BANK_TASK_ID and bankHackReward(profile) or 0,
		bankPreviewStepSeconds = id == BANK_TASK_ID and bankHackPreviewStep(profile) or 0.78,
		bankStartingLength = id == BANK_TASK_ID and bankHackStartingLength(profile) or 2,
	}
	profile.calmTaskCheckpointDurable = false
	profile.calmTaskCheckpointRecovered = false
	markDirty(profile)
	TransactionRuntime.commitCalmTaskStart(profile, false)
end

local function scheduleNextTask(profile)
	partySession.nextTaskAt = serverNow() + randomizer:NextNumber(
		Config.TaskDirector.MinimumDelay,
		Config.TaskDirector.MaximumDelay
	)
end

stockAutomatedBeer = function()
	local refrigerator = environment:FindFirstChild("WhiteHotpointRefrigerator", true)
	if not refrigerator then
		warn("[CooperGame] BeerBot completed, but the kitchen refrigerator is missing")
		return
	end
	local capacity = 12
	local current = math.max(0, math.floor(tonumber(refrigerator:GetAttribute("CooperBeerCount")) or 0))
	refrigerator:SetAttribute("CooperBeerCapacity", capacity)
	refrigerator:SetAttribute("CooperBeerCount", math.min(capacity, current + 6))
end

completeTask = function(profile, expectedRecord)
	local record = expectedRecord or partySession.task
	if not profile or not partyCanProgress() or not record
		or partySession.task ~= record
		or (record.status ~= "Active" and record.status ~= "Completing")
	then
		return false
	end
	if record.completionWorkerActive == true then
		-- One coroutine owns recipient reservation, persistence, and finalization.
		-- Same-frame prompt/robot callbacks observe the in-flight claim and cannot
		-- advance the shared cursor a second time after the first save yields.
		return true
	end
	local definition = record and taskById[record.id] or nil
	if not definition then
		return false
	end
	local reward = finiteInteger(definition.reward, 0, 0, 2_000_000_000)
	if record.id == BANK_TASK_ID then
		-- Keep the checkpointed scaled payout stable across save/reconciliation
		-- retries. Re-entering completeTask while status is Completing must not fall
		-- back to the task definition's base reward.
		reward = finiteInteger(record.bankReward, bankHackReward(profile), 0, 2_000_000_000)
		if record.status == "Active" then
			-- Manual play needs the exact final-key validation bit. Automated play has
			-- a different proof: an installed HackerBot and the exact authoritative run
			-- id created by launchTaskAutomation. Neither path can impersonate the other.
			local automationProfile = hostProfile()
			local automatedBankProof = automationProfile ~= nil and record.automated == true
				and record.automationUpgradeId == "HackerBot"
				and automationProfile.data.taskAutomationInstalled.HackerBot == true
				and type(record.bankAutomationRunId) == "string"
				and record.bankAutomationRunId == record.automationRunId
				and automationProfile.automationRuns[record.automationRunId] == record
			local manualBankProof = record.automated ~= true and record.bankHackValidated == true
			if (not automatedBankProof and not manualBankProof) or record.bankSuccessCounted == true then
				return false
			end
			record.bankSuccessCounted = true
		end
	end
	-- Consume the shared token synchronously before any deferred save, robot
	-- callback, or duplicate world prompt can observe it as payable.
	record.status = "Completing"
	record.completionWorkerActive = true
	record.rewardFeedbackByUserId = record.rewardFeedbackByUserId or {}
	local recipients = {}
	local payoutUserIds = {}
	for _, userId in ipairs(record.eligibility.userIds) do
		if userId ~= partySession.hostUserId then
			table.insert(payoutUserIds, userId)
		end
	end
	if record.eligibility.memberSet[partySession.hostUserId] == true then
		table.insert(payoutUserIds, partySession.hostUserId)
	end
	for _, userId in ipairs(payoutUserIds) do
		if userId == partySession.hostUserId then
			local everyGuestTerminal = true
			for _, eligibleUserId in ipairs(record.eligibility.userIds) do
				if eligibleUserId ~= partySession.hostUserId then
					local guestResolution = record.eligibilityResolutionByUserId[eligibleUserId]
					if not guestResolution
						or (guestResolution.status ~= "Committed" and guestResolution.status ~= "Forfeited")
					then
						everyGuestTerminal = false
						break
					end
				end
			end
			if not everyGuestTerminal then
				-- The host's totalTasks value is the durable logical-task checkpoint.
				-- Never advance it while an eligible guest is still reconciling; a
				-- crash must restart the same host ordinal and recover that guest.
				break
			end
		end
		local resolution = record.eligibilityResolutionByUserId[userId]
		if resolution == nil then
			local recipient, unavailableReason = eligibleProfileForTask(record, userId)
			if recipient then
				local operationKind = "TaskReward:" .. tostring(record.logicalId)
				local operationRecord = TransactionRuntime.findLogicalOperation(recipient, operationKind)
				local reserveStatus = operationRecord and "ExistingLogicalOperation" or nil
				if not operationRecord or operationRecord.state == "RolledBack" then
					operationRecord, reserveStatus = TransactionRuntime.reserveProfileValueOperation(
						recipient,
						operationKind,
						reward,
						record.sessionId
					)
				end
				if operationRecord and operationRecord.state == "Pending" then
					record.rewardOperationIdsByUserId[userId] = operationRecord.id
					resolution = {
						status = "Committing",
						operationId = operationRecord.id,
						reservedAt = serverNow(),
					}
					record.eligibilityResolutionByUserId[userId] = resolution
				elseif operationRecord and operationRecord.state == "NeedsReconciliation" then
					record.rewardOperationIdsByUserId[userId] = operationRecord.id
					resolution = {
						status = "Committing",
						operationId = operationRecord.id,
						reservedAt = serverNow(),
					}
					record.eligibilityResolutionByUserId[userId] = resolution
					TransactionRuntime.deferReconciliationSave(recipient, operationRecord.id, 0)
				elseif operationRecord and operationRecord.state == "Committed" then
					record.eligibilityResolutionByUserId[userId] = table.freeze({
						status = "Committed",
						operationId = operationRecord.id,
						operationState = "Committed",
						recovered = true,
						resolvedAt = serverNow(),
					})
					record.rewardFeedbackByUserId[userId] = true
				elseif reserveStatus == "TransactionBusy" then
					-- Another exactly-once operation owns this profile. Retry without
					-- changing the immutable eligibility decision.
				else
					warn(string.format(
						"[CooperGame] Could not reserve task reward for %d: %s",
						userId,
						tostring(reserveStatus)
					))
				end
			elseif unavailableReason == "GuestReconnectGraceExpired"
				or unavailableReason == "RecoveredTaskGraceExpired"
			then
				-- Exact expiry is the only rule that can forfeit a captured member.
				-- Loading, respawn, host pause, and transient save states all retry.
				forfeitTaskEligibility(record, userId, unavailableReason)
			end
			resolution = record.eligibilityResolutionByUserId[userId]
		end

		if resolution and resolution.status == "Committing" then
			-- Once reserved, this exact retained profile remains the operation owner
			-- even if its guest reconnect grace expires. Re-running the initial
			-- presence rule here could orphan a durable reward and stall the party.
			local recipient = profilesByUserId[userId]
			if recipient and (not recipient.loaded or recipient.releasing or recipient.leaseLost
				or (dataStore ~= nil and recipient.leaseOwned ~= true))
			then
				recipient = nil
			end
			local operationId = resolution.operationId
			if recipient and type(operationId) == "string" then
				local operationKind = "TaskReward:" .. tostring(record.logicalId)
				local currentOperation = TransactionLedger.lookup(
					TransactionRuntime.operationJournalFor(recipient),
					operationId
				)
				if currentOperation and currentOperation.state == "Committed"
					and currentOperation.kind == operationKind
				then
					record.eligibilityResolutionByUserId[userId] = table.freeze({
						status = "Committed",
						operationId = operationId,
						operationState = "Committed",
						resolvedAt = serverNow(),
					})
					if record.rewardFeedbackByUserId[userId] ~= true then
						record.rewardFeedbackByUserId[userId] = true
						table.insert(recipients, recipient)
					end
				elseif currentOperation and currentOperation.state == "NeedsReconciliation" then
					TransactionRuntime.deferReconciliationSave(recipient, operationId, 0)
				elseif currentOperation and currentOperation.state == "RolledBack" then
					record.eligibilityResolutionByUserId[userId] = nil
					record.rewardOperationIdsByUserId[userId] = nil
				else
					local accepted, durable, _, operationRecord, operationStatus = TransactionRuntime.commitProfileValueOperation(
						recipient,
						operationKind,
						reward,
						operationId,
						record.sessionId,
						function()
							if userId == partySession.hostUserId then
								local checkpoint = recipient.data.calmTaskCheckpoint
								assert(
									type(checkpoint) == "table"
										and checkpoint.logicalId == record.logicalId
										and checkpoint.hostOrdinal == recipient.data.totalTasks + 1,
									"Host CalmTaskStart checkpoint changed before reward commit"
								)
							end
							setAllowance(recipient, recipient.data.allowance + reward)
							recipient.data.totalTasks += 1
							recipient.data.cycleIndex = math.floor(recipient.data.totalTasks / #Config.TaskOrder) + 1
							recipient.data.cycleTaskIndex = (recipient.data.totalTasks % #Config.TaskOrder) + 1
							if record.id == BANK_TASK_ID then
								recipient.data.bankHackSuccesses = bankHackSuccessCount(recipient) + 1
							end
							if userId == partySession.hostUserId then
								-- Same profile transaction as host reward/ordinal: a crash can
								-- observe the old checkpoint or the advanced ordinal, never both.
								recipient.data.calmTaskCheckpoint = nil
								recipient.calmTaskCheckpointDurable = false
							end
							return {
								allowance = recipient.data.allowance,
								totalTasks = recipient.data.totalTasks,
								taskId = record.id,
								taskToken = record.token,
							}
						end
					)
					if accepted and durable then
						record.eligibilityResolutionByUserId[userId] = table.freeze({
							status = "Committed",
							operationId = operationId,
							operationState = operationRecord and operationRecord.state or operationStatus,
							resolvedAt = serverNow(),
						})
						if record.rewardFeedbackByUserId[userId] ~= true then
							record.rewardFeedbackByUserId[userId] = true
							table.insert(recipients, recipient)
						end
					elseif not accepted and operationStatus == "RolledBack" then
						warn("[CooperGame] Rolled-back task reward requires operator review: " .. tostring(operationId))
					end
				end
			end
		end
	end

	local allResolved = true
	for _, userId in ipairs(record.eligibility.userIds) do
		local resolution = record.eligibilityResolutionByUserId[userId]
		if not resolution or (resolution.status ~= "Committed" and resolution.status ~= "Forfeited") then
			allResolved = false
			break
		end
	end
	if not allResolved then
		record.completionWorkerActive = false
		TransactionRuntime.retryTaskCompletion(record, profile)
		broadcastState()
		return true
	end
	-- Finalizer CAS: no other callback may have replaced or closed this shared
	-- record while a recipient save yielded.
	if partySession.task ~= record or record.status ~= "Completing" then
		record.completionWorkerActive = false
		return true
	end
	record.status = "Completed"
	partySession.completedTasks += 1
	partySession.task = nil
	record.completionWorkerActive = false
	if record.automated == true then
		partySession.nextTaskAt = serverNow() + math.max(
			0.5,
			tonumber(Config.TaskDirector.AutomatedNextDelay) or 3
		)
	else
		scheduleNextTask(profile)
	end
	for _, recipient in ipairs(recipients) do
		feedback(recipient.player, "TaskComplete", {
			taskId = definition.id,
			taskToken = record.token,
			title = definition.title,
			reward = reward,
			automated = record.automated == true,
			automationUpgradeId = record.automationUpgradeId,
			text = record.automated == true
				and string.format("%s accepted the shared chore. Everyone eligible at task start earned $%d.", tostring(record.automationUpgradeId or "Robot"), reward)
				or string.format("Shared task complete! You earned $%d allowance.", reward),
		})
	end
	broadcastState()
	-- Every recipient was synchronously passed through the schema-12 ledger.
	-- Deferred work may retry a failed save, but it never reapplies the reward.
	return true
end

local function bankRoundCount()
	return finiteInteger(bankHackConfig.RoundCount, 4, 1, 20)
end

local function bankPacket(player, kind, payload)
	payload = type(payload) == "table" and payload or {}
	payload.kind = kind
	if player and player.Parent == Players then
		bankHackEvent:FireClient(player, payload)
	end
end

local function bankSessionIsCurrent(profile, session)
	return profile ~= nil
		and session ~= nil
		and profiles[profile.player] == profile
		and profile.loaded
		and not profile.releasing
		and profile.bankHackSession == session
		and partySession.task == session.record
		and session.record.bankActorUserId == profile.player.UserId
		and session.record.id == BANK_TASK_ID
end

cancelBankHackSession = function(profile, reason, notifyPlayer)
	local session = profile and profile.bankHackSession or nil
	if not session then
		return false
	end
	profile.bankHackSession = nil
	bankInputNextAt[profile.player] = nil
	if partySession.task == session.record and session.record.id == BANK_TASK_ID then
		session.record.step = "Ready"
		session.record.bankRetryReadyAt = nil
		session.record.bankActorUserId = nil
	end
	if notifyPlayer ~= false then
		bankPacket(profile.player, "BankHackCancelled", {
			sessionId = session.id,
			reason = tostring(reason or "Connection closed."),
			text = tostring(reason or "Bank connection closed."),
			serverTime = serverNow(),
		})
	end
	if notifyPlayer ~= false and profile.player.Parent == Players then
		sendSnapshot(profile.player)
	end
	return true
end

local function failBankHackSession(profile, session, reason)
	if not bankSessionIsCurrent(profile, session) then
		return false
	end
	profile.bankHackSession = nil
	bankInputNextAt[profile.player] = nil
	session.record.bankActorUserId = nil
	local retrySeconds = math.max(0, tonumber(bankHackConfig.RetryCooldownSeconds) or 1.25)
	local retryReadyAt = serverNow() + retrySeconds
	session.record.step = "RetryCooldown"
	session.record.bankRetryReadyAt = retryReadyAt
	bankPacket(profile.player, "BankHackFailed", {
		sessionId = session.id,
		round = session.round,
		roundCount = bankRoundCount(),
		cycle = session.cycle,
		reward = session.reward,
		reason = tostring(reason or "The bank trace detected the connection."),
		text = tostring(reason or "The bank trace detected the connection."),
		retryReadyAt = retryReadyAt,
		retryCooldownSeconds = retrySeconds,
		serverTime = serverNow(),
	})
	sendSnapshot(profile.player)
	task.delay(retrySeconds, function()
		if profiles[profile.player] == profile
			and profile.loaded
			and not profile.releasing
			and partySession.task == session.record
			and profile.bankHackSession == nil
			and session.record.step == "RetryCooldown"
			and tonumber(session.record.bankRetryReadyAt) == retryReadyAt
		then
			session.record.step = "Ready"
			session.record.bankRetryReadyAt = nil
			sendSnapshot(profile.player)
		end
	end)
	return true
end

local beginBankHackRound

local function succeedBankHackSession(profile, session)
	if not bankSessionIsCurrent(profile, session) then
		return false
	end
	-- Invalidate the only live claim before touching allowance. Replayed keys,
	-- delayed deadlines, and duplicate callbacks all fail the identity check.
	profile.bankHackSession = nil
	bankInputNextAt[profile.player] = nil
	session.record.bankActorUserId = nil
	session.phase = "Succeeded"
	session.record.bankHackValidated = true
	session.record.step = "Complete"
	local nextSuccessCount = bankHackSuccessCount(profile) + 1
	bankPacket(profile.player, "BankHackSucceeded", {
		sessionId = session.id,
		cycle = session.cycle,
		reward = session.reward,
		successes = nextSuccessCount,
		nextPreviewStepSeconds = bankHackPreviewStepForSuccesses(nextSuccessCount),
		nextStartingLength = bankHackStartingLengthForSuccesses(nextSuccessCount),
		text = string.format("MEDFORD BANK ACCESS GRANTED — $%d transferred to allowance.", session.reward),
		serverTime = serverNow(),
	})
	return completeTask(profile)
end

beginBankHackRound = function(profile, session, roundNumber)
	if not bankSessionIsCurrent(profile, session) then
		return false
	end
	if not validComputerSession(profile.player) then
		cancelBankHackSession(profile, "The bank connection was lost when you left the computer.", true)
		return false
	end

	local roundCount = bankRoundCount()
	local round = finiteInteger(roundNumber, 1, 1, roundCount)
	local patternLength = finiteInteger(session.startingLength, 2, 1, 100) + round - 1
	local pattern = table.create(patternLength)
	for index = 1, patternLength do
		pattern[index] = session.sequence[index]
	end

	local now = serverNow()
	local previewStep = session.previewStepSeconds
	local leadIn = math.max(0, tonumber(bankHackConfig.LeadInSeconds) or 0.65)
	local displayStartsAt = now + leadIn
	local inputOpensAt = displayStartsAt + patternLength * previewStep
	local inputWindow = math.max(0.5, tonumber(bankHackConfig.InputWindowBaseSeconds) or 3.5)
		+ patternLength * math.max(0.05, tonumber(bankHackConfig.InputWindowPerKeySeconds) or 0.9)
	local inputDeadline = inputOpensAt + inputWindow

	session.round = round
	session.phase = "Preview"
	session.expectedIndex = 1
	session.patternLength = patternLength
	session.displayStartsAt = displayStartsAt
	session.inputOpensAt = inputOpensAt
	session.inputDeadline = inputDeadline
	session.record.step = "Preview"

	bankPacket(profile.player, "BankHackRound", {
		sessionId = session.id,
		pattern = pattern,
		round = round,
		roundCount = roundCount,
		patternLength = patternLength,
		cycle = session.cycle,
		reward = session.reward,
		previewStepSeconds = previewStep,
		cueLightRatio = math.clamp(tonumber(bankHackConfig.CueLightRatio) or 0.62, 0.05, 1),
		cueLightSeconds = previewStep * math.clamp(tonumber(bankHackConfig.CueLightRatio) or 0.62, 0.05, 1),
		displayStartsAt = displayStartsAt,
		inputOpensAt = inputOpensAt,
		inputDeadline = inputDeadline,
		serverTime = now,
	})

	task.delay(math.max(0, inputOpensAt - now), function()
		if bankSessionIsCurrent(profile, session)
			and session.round == round
			and session.phase == "Preview"
		then
			if validComputerSession(profile.player) then
				session.phase = "Input"
				session.record.step = "Input"
			else
				cancelBankHackSession(profile, "The bank connection was lost when you left the computer.", true)
			end
		end
	end)
	task.delay(math.max(0, inputDeadline - now) + 0.05, function()
		if bankSessionIsCurrent(profile, session)
			and session.round == round
			and (session.phase == "Preview" or session.phase == "Input")
			and serverNow() > session.inputDeadline
		then
			failBankHackSession(profile, session, "TRACE COMPLETE — the response timer expired.")
		end
	end)
	return true
end

local function startBankHack(profile)
	if not profile or not profile.loaded or profile.releasing or not partyCanProgress() then
		return false, "Your profile is not ready."
	end
	if not validComputerSession(profile.player) then
		return false, "Use Sheldon's computer before starting HACK MEDFORD BANK."
	end
	local record = partySession.task
	if not record or record.id ~= BANK_TASK_ID then
		return false, "The Medford Bank hack is not the active task right now."
	end
	if profile.bankHackSession then
		return false, "A Medford Bank connection is already active."
	end
	if record.bankActorUserId ~= nil and record.bankActorUserId ~= profile.player.UserId then
		return false, "Another party member is using BANKLINK right now."
	end
	local now = serverNow()
	local retryReadyAt = tonumber(record.bankRetryReadyAt) or 0
	if retryReadyAt > now then
		return false, string.format("BANKLINK is resetting. Try again in %.1f seconds.", retryReadyAt - now), retryReadyAt
	end
	if record.step == "RetryCooldown" then
		record.step = "Ready"
		record.bankRetryReadyAt = nil
	elseif record.step ~= "Ready" then
		return false, "BANKLINK is not ready to start another connection."
	end

	local startingLength = finiteInteger(
		record.bankStartingLength,
		bankHackStartingLength(profile),
		1,
		100
	)
	local sequenceLength = startingLength + bankRoundCount() - 1
	local sequence = table.create(sequenceLength)
	local previousKey = nil
	for index = 1, sequenceLength do
		local key
		repeat
			key = bankKeys[randomizer:NextInteger(1, #bankKeys)]
		until key ~= previousKey
		sequence[index] = key
		previousKey = key
	end

	bankHackSessionSerial += 1
	local session = {
		id = string.format(
			"bank:%d:%d:%s",
			profile.player.UserId,
			bankHackSessionSerial,
			HttpService:GenerateGUID(false)
		),
		record = record,
		sequence = sequence,
		round = 0,
		phase = "Starting",
		expectedIndex = 0,
		patternLength = 0,
		startingLength = startingLength,
		cycle = finiteInteger(record.bankCycle, bankHackSuccessCount(profile) + 1, 1, 1_000_001),
		reward = finiteInteger(record.bankReward, bankHackReward(profile), 0, 2_000_000_000),
		previewStepSeconds = math.max(
			math.max(0.05, tonumber(bankHackConfig.MinimumPreviewStepSeconds) or 0.32),
			tonumber(record.bankPreviewStepSeconds) or bankHackPreviewStep(profile)
		),
	}
	record.bankHackValidated = nil
	record.bankSuccessCounted = nil
	record.bankRetryReadyAt = nil
	record.step = "Starting"
	record.bankActorUserId = profile.player.UserId
	profile.bankHackSession = session
	bankInputNextAt[profile.player] = nil
	bankPacket(profile.player, "BankHackStarted", {
		sessionId = session.id,
		allowedKeys = table.clone(bankKeys),
		cycle = session.cycle,
		reward = session.reward,
		roundCount = bankRoundCount(),
		startingLength = session.startingLength,
		previewStepSeconds = session.previewStepSeconds,
		text = "MEDFORD BANK LINK ESTABLISHED — memorize each illuminated key sequence.",
		serverTime = now,
	})
	return beginBankHackRound(profile, session, 1)
end

local function passBankInputCooldown(player)
	local nowClock = os.clock()
	if (bankInputNextAt[player] or 0) > nowClock then
		return false
	end
	bankInputNextAt[player] = nowClock
		+ math.max(0.01, tonumber(bankHackConfig.InputRateLimitSeconds) or 0.04)
	return true
end

local function submitBankHackInput(profile, payload)
	if type(payload) ~= "table" then
		return false, "BANKLINK rejected an invalid input packet."
	end
	local session = profile and profile.bankHackSession or nil
	local sessionId = type(payload.sessionId) == "string" and payload.sessionId or ""
	if not session or sessionId == "" or #sessionId > 128 or session.id ~= sessionId then
		return false, "That Medford Bank session is no longer active."
	end
	if not bankSessionIsCurrent(profile, session) then
		cancelBankHackSession(profile, "The active bank task changed, so the connection was closed.", true)
		return false
	end
	if not validComputerSession(profile.player) then
		cancelBankHackSession(profile, "The bank connection was lost when you left the computer.", true)
		return false
	end
	if not passBankInputCooldown(profile.player) then
		return false, "BANKLINK input was too fast. Wait for each key acknowledgement."
	end

	local rawKey = payload.key
	if type(rawKey) ~= "string" or #rawKey ~= 1 then
		return false, "That key is not part of the BANKLINK keypad."
	end
	local key = string.upper(rawKey)
	if not bankKeySet[key] then
		return false, "That key is not part of the BANKLINK keypad."
	end
	local now = serverNow()
	if session.phase == "Preview" and now >= session.inputOpensAt then
		session.phase = "Input"
		session.record.step = "Input"
	end
	if session.phase ~= "Input" then
		return false, "Watch the full pattern before entering any keys."
	end
	if now < session.inputOpensAt then
		return false, "The pattern is still being transmitted."
	end
	if now > session.inputDeadline then
		failBankHackSession(profile, session, "TRACE COMPLETE — the response timer expired.")
		return false
	end

	local expectedIndex = finiteInteger(session.expectedIndex, 1, 1, session.patternLength)
	local expectedKey = session.sequence[expectedIndex]
	if key ~= expectedKey then
		failBankHackSession(profile, session, "ACCESS DENIED — the key sequence did not match.")
		return false
	end

	session.expectedIndex = expectedIndex + 1
	bankPacket(profile.player, "BankHackInputAccepted", {
		sessionId = session.id,
		round = session.round,
		index = expectedIndex,
		patternLength = session.patternLength,
		remaining = session.patternLength - expectedIndex,
		key = key,
		serverTime = now,
	})
	if session.expectedIndex <= session.patternLength then
		return true
	end

	session.phase = "RoundPause"
	session.record.step = "RoundPause"
	bankPacket(profile.player, "BankHackRoundComplete", {
		sessionId = session.id,
		round = session.round,
		roundCount = bankRoundCount(),
		finalRound = session.round >= bankRoundCount(),
		text = session.round >= bankRoundCount()
			and "FINAL ACCESS LAYER CLEARED"
			or "ACCESS LAYER CLEARED — preparing a longer pattern.",
		serverTime = serverNow(),
	})
	if session.round >= bankRoundCount() then
		return succeedBankHackSession(profile, session)
	end

	local completedRound = session.round
	task.delay(math.max(0, tonumber(bankHackConfig.RoundPauseSeconds) or 0.75), function()
		if bankSessionIsCurrent(profile, session)
			and session.phase == "RoundPause"
			and session.round == completedRound
		then
			beginBankHackRound(profile, session, completedRound + 1)
		end
	end)
	return true
end

local function queueDelivery(profile, kind, stage, upgradeId)
	profile.deliveryQueued = type(profile.deliveryQueued) == "table" and profile.deliveryQueued or {}
	if profile.deliveryQueued[kind] then
		return
	end
	profile.deliveryQueued[kind] = true
	local request = {
		kind = kind,
		stage = stage or 0,
		upgradeId = upgradeId,
	}
	requestDelivery:Fire(profile.player, request)
	-- BindableEvents do not retain messages if TaskWorld is still starting. Retry
	-- until its Spawned acknowledgement clears the flag; TaskWorld de-duplicates
	-- these requests by owner/kind/stage. Do not abandon the request after a fixed
	-- startup window: a host-grace pause or slow streamed environment can validly
	-- last longer than thirty seconds, while the durable purchase/task still needs
	-- a physical delivery afterward.
	task.spawn(function()
		while profiles[profile.player] == profile and profile.deliveryQueued[kind] do
			task.wait(DELIVERY_RETRY_INTERVAL_SECONDS)
			if profiles[profile.player] == profile and profile.deliveryQueued[kind] then
				requestDelivery:Fire(profile.player, request)
			end
		end
	end)
end

-- The only server path that creates a component order.  Cost validation,
-- allowance debit, pending-stage mutation, and delivery queueing happen as one
-- trusted operation so no client can install free parts.
-- M1_HOST_ONLY_PURCHASE_GUARD
local function hostMutationAllowed(profile)
	if not profile or not profile.loaded or profile.releasing then
		return false, "Profile is not loaded"
	end
	if not partyCanProgress() then
		return false, "Party progression is paused while the host reconnects."
	end
	if profile.transactionReconciliationBlocked == true then
		return false, "This profile has an unresolved value operation and is locked against another charge."
	end
	if not partyIsHost(profile.player) or hostProfile() ~= profile then
		return false, "Only the party host can change this house's permanent upgrades."
	end
	return true
end

function TransactionRuntime.purchaseStillAuthorized(profile, operationKind, price)
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return false, denial
	end
	if profile.data.allowance < price then
		return false, "Allowance changed while the purchase was queued."
	end
	local partPending = profile.data.pendingPartStage > 0
	local boomboxPending = profile.data.boomboxPurchased and not profile.data.boomboxPlaced
	local automationPending = profile.data.pendingTaskUpgradeId ~= ""
	local chemistryPending = profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced
	if operationKind == "PurchaseMachinePart" then
		return not partPending and not boomboxPending and not automationPending and not chemistryPending,
			"Another delivery became active while this component order was queued."
	elseif operationKind == "PurchaseBoombox" then
		return profile.data.boomboxPurchased ~= true and not partPending
			and not automationPending and not chemistryPending,
			"The boombox is owned already or another delivery became active."
	elseif operationKind == "PurchaseBoomboxAutoplay" then
		return profile.data.boomboxPurchased == true and profile.data.boomboxPlaced == true
			and profile.data.boomboxAutoplayPurchased ~= true,
			"The boombox autoplay entitlement changed while this purchase was queued."
	elseif string.sub(operationKind, 1, 20) == "PurchaseTaskUpgrade:" then
		local upgradeId = string.sub(operationKind, 21)
		return automationById[upgradeId] ~= nil
			and profile.data.taskAutomationInstalled[upgradeId] ~= true
			and not automationPending and not partPending and not boomboxPending and not chemistryPending,
			"That robot is owned already or another delivery became active."
	elseif operationKind == "PurchaseSecretBunker" then
		return profile.data.secretBunkerPurchased ~= true,
			"The secret bunker entitlement changed while this purchase was queued."
	elseif operationKind == "PurchaseChemistrySetup" then
		return secretBunkerSnapshot(profile).unlocked == true
			and profile.data.chemistrySetupPurchased ~= true
			and not partPending and not boomboxPending and not automationPending,
			"The chemistry entitlement changed or another delivery became active."
	end
	return false, "Unknown purchase operation."
end

function TransactionRuntime.commitHostPurchase(profile, operationKind, price, mutate)
	local operationSessionId = TransactionRuntime.activeSessionId()
	if not operationSessionId then
		return false, false, "StaleSession"
	end
	local accepted, durable, _, _, status = TransactionRuntime.commitProfileValueOperation(
		profile,
		operationKind,
		-price,
		nil,
		operationSessionId,
		mutate,
		function()
			return TransactionRuntime.purchaseStillAuthorized(profile, operationKind, price)
		end
	)
	if accepted and not durable then
		feedback(profile.player, "TransactionReconciliation", {
			title = "SAVING PURCHASE",
			operation = operationKind,
			text = "Your purchase is recorded and will not be charged twice while its save is reconciled.",
		})
		-- Presentation is reconstructed only after the reconciliation worker has
		-- verified the debit and entitlement in durable storage. Never dispatch a
		-- truck, construction sequence, or success toast from an ambiguous save.
		return false, false, "SavePending"
	end
	return accepted and durable, durable, status
end

local function orderMachinePart(profile, expectedStage)
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return false, denial
	end
	if profile.data.pendingPartStage > 0 then
		return false, "You already have a component delivery in progress."
	end
	if profile.data.boomboxPurchased and not profile.data.boomboxPlaced then
		return false, "Finish setting up your boombox delivery first."
	end
	if profile.data.pendingTaskUpgradeId ~= "" then
		return false, "Finish installing your task automation upgrade first."
	end
	if profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced then
		return false, "Finish installing your advanced chemistry setup first."
	end
	local definition = nextMachinePart(profile)
	if not definition then
		return false, "The Time Machine is already 100% complete."
	end
	if expectedStage ~= nil and finiteInteger(expectedStage, -1, -1, #Config.MachineStages) ~= definition.stage then
		return false, "That component is not the next stage."
	end
	local cost = finiteInteger(definition.cost, 0, 0, 2_000_000_000)
	if cost <= 0 then
		warn("[CooperGame] Rejected non-positive machine component cost for stage " .. tostring(definition.stage))
		return false, "That component has an invalid price."
	end
	if profile.data.allowance < cost then
		return false, string.format("You need $%d more allowance.", cost - profile.data.allowance)
	end
	local purchased, _, transactionStatus = TransactionRuntime.commitHostPurchase(
		profile,
		"PurchaseMachinePart",
		cost,
		function()
			setAllowance(profile, profile.data.allowance - cost)
			profile.data.pendingPartStage = definition.stage
			return {
				allowance = profile.data.allowance,
				pendingPartStage = definition.stage,
				item = definition.name,
			}
		end
	)
	if not purchased then
		return false, "The component purchase could not be committed safely (" .. tostring(transactionStatus) .. ")."
	end
	profile.partDeliveryStep = "WaitingDelivery"
	queueDelivery(profile, "MachinePart", definition.stage)
	broadcastState()
	return true, definition.name, definition.stage, cost
end

-- One permanent purchase per profile. The debit and persistent pending marker
-- are committed without yielding before the delivery request is emitted, so a
-- repeated client click can never create a free or duplicate order.
local function orderBoombox(profile)
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return false, denial
	end
	if profile.data.boomboxPurchased then
		return false, profile.data.boomboxPlaced
			and "You already own the living-room boombox."
			or "Your boombox delivery is already in progress."
	end
	if profile.data.pendingPartStage > 0 then
		return false, "Finish installing your Time Machine component first."
	end
	if profile.data.pendingTaskUpgradeId ~= "" then
		return false, "Finish installing your task automation upgrade first."
	end
	if profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced then
		return false, "Finish installing your advanced chemistry setup first."
	end
	local price = finiteInteger(Config.Boombox.Price, 0, 0, 2_000_000_000)
	if price <= 0 then
		warn("[CooperGame] Rejected non-positive boombox price")
		return false, "The boombox has an invalid price."
	end
	if profile.data.allowance < price then
		return false, string.format("You need $%d more allowance.", price - profile.data.allowance)
	end

	local purchased, _, transactionStatus = TransactionRuntime.commitHostPurchase(
		profile,
		"PurchaseBoombox",
		price,
		function()
			setAllowance(profile, profile.data.allowance - price)
			profile.data.boomboxPurchased = true
			profile.data.boomboxPlaced = false
			profile.data.boomboxNextPlayAt = 0
			return {
				allowance = profile.data.allowance,
				boomboxPurchased = true,
			}
		end
	)
	if not purchased then
		return false, "The boombox purchase could not be committed safely (" .. tostring(transactionStatus) .. ")."
	end
	profile.boomboxDeliveryStep = "WaitingDelivery"
	syncBoomboxPlacedAttribute(profile)
	queueDelivery(profile, "Boombox", 0)
	feedback(profile.player, "BoomboxPurchased", {
		price = price,
		text = string.format("Boombox ordered for $%d. Watch for the delivery truck.", price),
	})
	broadcastState()
	return true, "Cooper Party Boombox", price
end

-- Permanent software upgrade for the installed boombox. The canonical price,
-- ownership checks, debit, and entitlement mutation are all server-side and
-- occur without yielding, so repeated or forged client requests cannot create
-- a free upgrade or charge the same profile twice.
local function upgradeBoomboxAutoplay(profile)
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return false, denial
	end
	if not profile.data.boomboxPurchased or not profile.data.boomboxPlaced then
		return false, "Buy, deliver, and set up the boombox before upgrading it."
	end
	if profile.data.boomboxAutoplayPurchased then
		return false, "The boombox autoplay upgrade is already installed."
	end

	local price = finiteInteger(Config.Boombox.AutoplayUpgradePrice, 0, 0, 2_000_000_000)
	if price <= 0 then
		warn("[CooperGame] Rejected non-positive boombox autoplay upgrade price")
		return false, "The boombox autoplay upgrade has an invalid price."
	end
	if profile.data.allowance < price then
		return false, string.format("You need $%d more allowance.", price - profile.data.allowance)
	end

	local purchased, _, transactionStatus = TransactionRuntime.commitHostPurchase(
		profile,
		"PurchaseBoomboxAutoplay",
		price,
		function()
			setAllowance(profile, profile.data.allowance - price)
			profile.data.boomboxAutoplayPurchased = true
			return {
				allowance = profile.data.allowance,
				boomboxAutoplayPurchased = true,
			}
		end
	)
	if not purchased then
		return false, "The autoplay purchase could not be committed safely (" .. tostring(transactionStatus) .. ")."
	end
	feedback(profile.player, "BoomboxAutoplayPurchased", {
		price = price,
		text = string.format(
			"Autoplay installed for $%d. The boombox will restart automatically whenever its cooldown ends while you are online.",
			price
		),
	})
	broadcastState()
	return true, "Boombox Autoplay", price
end

-- A paid automation order is a durable entitlement immediately, even before
-- its physical robot is installed. The pending id is persisted with the debit
-- and requeued after reconnects, so a lost crate or shutdown cannot lose the
-- player's purchase.
local function orderTaskUpgrade(profile, requestedUpgradeId)
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return false, denial
	end
	local upgradeId = type(requestedUpgradeId) == "string" and requestedUpgradeId or ""
	local definition = automationById[upgradeId]
	if not definition then
		return false, "That task automation upgrade does not exist."
	end
	if profile.data.taskAutomationInstalled[upgradeId] == true then
		return false, definition.name .. " is already installed."
	end
	if profile.data.pendingTaskUpgradeId ~= "" then
		return false, profile.data.pendingTaskUpgradeId == upgradeId
			and (definition.name .. " is already being delivered.")
			or "Finish installing your current task automation upgrade first."
	end
	if profile.data.pendingPartStage > 0 then
		return false, "Finish installing your Time Machine component first."
	end
	if profile.data.boomboxPurchased and not profile.data.boomboxPlaced then
		return false, "Finish setting up your boombox delivery first."
	end
	if profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced then
		return false, "Finish installing your advanced chemistry setup first."
	end
	local activeTask = partySession.task
	if activeTask and activeTask.id == "GeorgeBeer"
		and (activeTask.step == "WaitingDelivery" or activeTask.step == "Collect" or activeTask.step == "Deliver")
	then
		return false, "Finish George's current beer delivery before ordering another truck delivery."
	end

	local price = finiteInteger(definition.price, 0, 0, 2_000_000_000)
	if price <= 0 then
		warn("[CooperGame] Rejected non-positive task automation price for " .. upgradeId)
		return false, "That task automation upgrade has an invalid price."
	end
	if profile.data.allowance < price then
		return false, string.format("You need $%d more allowance.", price - profile.data.allowance)
	end

	local purchased, _, transactionStatus = TransactionRuntime.commitHostPurchase(
		profile,
		"PurchaseTaskUpgrade:" .. upgradeId,
		price,
		function()
			setAllowance(profile, profile.data.allowance - price)
			profile.data.pendingTaskUpgradeId = upgradeId
			return {
				allowance = profile.data.allowance,
				pendingTaskUpgradeId = upgradeId,
				item = definition.name,
			}
		end
	)
	if not purchased then
		return false, "The automation purchase could not be committed safely (" .. tostring(transactionStatus) .. ")."
	end
	profile.taskUpgradeDeliveryStep = "WaitingDelivery"
	queueDelivery(profile, "TaskUpgrade", 0, upgradeId)
	feedback(profile.player, "TaskUpgradeOrdered", {
		upgradeId = upgradeId,
		taskId = definition.taskId,
		name = definition.name,
		price = price,
		text = string.format("%s ordered for $%d. Watch for the delivery truck.", definition.name, price),
	})
	broadcastState()
	return true, definition.name, price
end

-- A bunker order is a permanent phase entitlement, not a delivery prop. The
-- debit, entitlement, and construction deadline are committed together without
-- yielding; the construction controller receives presentation work only after
-- that authoritative transaction is complete.
local function orderSecretBunker(profile)
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return false, denial
	end
	if profile.data.secretBunkerPurchased == true then
		local bunkerState = secretBunkerSnapshot(profile)
		return false, bunkerState.unlocked
			and "The secret underground bunker is already unlocked."
			or ("Your bunker is already under construction. Ready in " .. formatCountdown(bunkerState.remaining) .. ".")
	end

	local price = finiteInteger(secretBunkerConfig.Price, 0, 0, 2_000_000_000)
	local constructionSeconds = finiteInteger(secretBunkerConfig.ConstructionSeconds, 0, 0, 86_400)
	if price <= 0 or constructionSeconds <= 0 then
		warn("[CooperGame] Rejected invalid secret bunker price or construction duration")
		return false, "The secret bunker has invalid order data."
	end
	if profile.data.allowance < price then
		return false, string.format("You need $%d more allowance.", price - profile.data.allowance)
	end

	local readyAt = finiteInteger(
		unixNow() + constructionSeconds,
		unixNow() + constructionSeconds,
		1,
		4_102_444_800
	)
	local purchased, _, transactionStatus = TransactionRuntime.commitHostPurchase(
		profile,
		"PurchaseSecretBunker",
		price,
		function()
			setAllowance(profile, profile.data.allowance - price)
			profile.data.secretBunkerPurchased = true
			profile.data.secretBunkerReadyAt = readyAt
			return {
				allowance = profile.data.allowance,
				secretBunkerPurchased = true,
				secretBunkerReadyAt = readyAt,
			}
		end
	)
	if not purchased then
		return false, "The bunker purchase could not be committed safely (" .. tostring(transactionStatus) .. ")."
	end
	profile.secretBunkerCompletionAnnounced = false

	syncSecretBunkerAttributes(profile)
	feedback(profile.player, "SecretBunkerPurchased", {
		id = secretBunkerConfig.Id,
		name = secretBunkerConfig.Name,
		price = price,
		readyAt = readyAt,
		constructionSeconds = constructionSeconds,
		text = string.format(
			"%s authorized for $%d. Heavy construction is moving into the backyard now.",
			secretBunkerConfig.Name,
			price
		),
	})
	broadcastState()
	requestSecretBunkerPresentation(profile, "Purchased")
	return true, secretBunkerConfig.Name, price, readyAt
end

-- The first bunker-only purchase uses the same durable paid-delivery contract
-- as every house upgrade. Only the research terminal may request it, but all
-- entitlement, allowance, and delivery state remains authoritative here.
local function orderChemistrySetup(profile)
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return false, denial
	end
	local bunkerState = secretBunkerSnapshot(profile)
	if bunkerState.unlocked ~= true then
		return false, "Unlock and enter your secret underground bunker first."
	end
	if profile.data.chemistrySetupPurchased then
		return false, profile.data.chemistrySetupPlaced
			and "Your advanced chemistry setup is already installed."
			or "Your chemistry setup delivery is already in progress."
	end
	if profile.data.pendingPartStage > 0 then
		return false, "Finish installing your Time Machine component first."
	end
	if profile.data.boomboxPurchased and not profile.data.boomboxPlaced then
		return false, "Finish setting up your boombox delivery first."
	end
	if profile.data.pendingTaskUpgradeId ~= "" then
		return false, "Finish installing your task automation upgrade first."
	end
	local activeTask = partySession.task
	if activeTask and activeTask.id == "GeorgeBeer"
		and (activeTask.step == "WaitingDelivery" or activeTask.step == "Collect" or activeTask.step == "Deliver")
	then
		return false, "Finish George's current beer delivery before ordering laboratory equipment."
	end

	local price = finiteInteger(chemistrySetupConfig.Price, 0, 0, 2_000_000_000)
	if price <= 0 then
		warn("[CooperGame] Rejected non-positive chemistry setup price")
		return false, "The chemistry setup has an invalid price."
	end
	if profile.data.allowance < price then
		return false, string.format("You need $%d more allowance.", price - profile.data.allowance)
	end

	local purchased, _, transactionStatus = TransactionRuntime.commitHostPurchase(
		profile,
		"PurchaseChemistrySetup",
		price,
		function()
			setAllowance(profile, profile.data.allowance - price)
			profile.data.chemistrySetupPurchased = true
			profile.data.chemistrySetupPlaced = false
			return {
				allowance = profile.data.allowance,
				chemistrySetupPurchased = true,
			}
		end
	)
	if not purchased then
		return false, "The chemistry purchase could not be committed safely (" .. tostring(transactionStatus) .. ")."
	end
	profile.chemistryDeliveryStep = "WaitingDelivery"
	syncChemistrySetupAttributes(profile)
	queueDelivery(profile, "ChemistrySetup", 0)
	feedback(profile.player, "ChemistrySetupPurchased", {
		id = chemistrySetupConfig.Id,
		name = chemistrySetupConfig.Name,
		price = price,
		text = string.format(
			"%s ordered for $%d. The research-equipment truck is headed to the driveway.",
			chemistrySetupConfig.Name,
			price
		),
	})
	broadcastState()
	return true, chemistrySetupConfig.Name, price
end

local function completeSecretBunkerIfReady(profile)
	if not profile or not profile.loaded or profile.releasing
		or profile.data.secretBunkerPurchased ~= true
		or profile.secretBunkerCompletionAnnounced == true
	then
		return false
	end
	local bunkerState = secretBunkerSnapshot(profile)
	if not bunkerState.unlocked then
		return false
	end
	profile.secretBunkerCompletionAnnounced = true
	syncSecretBunkerAttributes(profile)
	feedback(profile.player, "SecretBunkerConstructionComplete", {
		id = bunkerState.id,
		name = bunkerState.name,
		price = bunkerState.price,
		readyAt = bunkerState.readyAt,
		text = "Construction complete. Your secret underground bunker is now unlocked.",
	})
	broadcastState()
	requestSecretBunkerPresentation(profile, "ConstructionComplete")
	return true
end

local function createCandyBatch(profile, metadata)
	local worldProfile = hostProfile()
	if not profile or not profile.loaded or profile.releasing
		or not partyCanProgress()
		or not worldProfile or worldProfile.data.chemistrySetupPlaced ~= true
	then
		return false
	end
	if type(metadata) ~= "table" or metadata.productKind ~= "BlueRockCandy"
		or profile.data.candyDeliveryActive == true
	then
		return false
	end
	if profile.data.candyBatchReady == true then
		-- Completion callbacks are idempotent. A retry reconstructs the same
		-- finished batch instead of minting another token or stacking inventory.
		syncCandyDeliveryAttributes(profile)
		return true, profile.data.candyBatchToken
	end
	profile.data.candyBatchReady = true
	profile.data.candyBatchToken = HttpService:GenerateGUID(false)
	markDirty(profile)
	syncCandyDeliveryAttributes(profile)
	local batchState = candyDeliverySnapshot(profile)
	feedback(profile.player, "CandyBatchReady", {
		title = "CHEMISTRY BATCH READY",
		text = "Your finished Blue Rock Candy is secured. Return to the bunker output tray to collect it.",
	})
	broadcastState()
	-- Persist reaction completion before the physical tray is treated as the
	-- source of truth. The bounded save retries close the leave/server-shutdown
	-- loss window; a dirty revision remains queued if Roblox storage is transient.
	if not saveProfile(profile.player, false) then
		warn("[CooperGame] Finished candy batch remains dirty after immediate save retries for " .. profile.player.Name)
	end
	return true, batchState.readyBatchToken
end

local function beginCandyDelivery(profile, metadata)
	local worldProfile = hostProfile()
	if not profile or not profile.loaded or profile.releasing
		or not partyCanProgress()
		or not worldProfile or worldProfile.data.chemistrySetupPlaced ~= true
	then
		return false
	end
	local reportedToken = type(metadata) == "table" and tostring(metadata.batchToken or "") or ""
	if profile.data.candyDeliveryActive == true then
		-- A duplicated collection callback may only recover the exact contract;
		-- it never emits a second Start transition or creates a fresh token.
		if reportedToken == "" or reportedToken ~= profile.data.candyDeliveryToken then
			return false
		end
		syncCandyDeliveryAttributes(profile)
		candyDeliveryChanged:Fire(profile.player, "Recover", candyDeliverySnapshot(profile))
		return true, profile.data.candyDeliveryToken
	end
	if profile.data.candyBatchReady ~= true
		or reportedToken == ""
		or reportedToken ~= profile.data.candyBatchToken
	then
		return false
	end
	-- Atomically consume the durable output token and reuse it for the buyer
	-- contract. There is no gap where neither state owns the finished batch.
	profile.data.candyBatchReady = false
	profile.data.candyBatchToken = ""
	profile.data.candyDeliveryActive = true
	profile.data.candyDeliveryToken = reportedToken
	markDirty(profile)
	syncCandyDeliveryAttributes(profile)
	local deliveryState = candyDeliverySnapshot(profile)
	feedback(profile.player, "CandyDeliveryStarted", {
		title = "LOS POLLOS PICKUP",
		payout = deliveryState.payout,
		text = string.format(
			"New bunker task: equip the Blue Rock Candy Pan and deliver it to the yellow Los Pollos Hermanos truck for $%d.",
			deliveryState.payout
		),
	})
	candyDeliveryChanged:Fire(profile.player, "Start", deliveryState)
	broadcastState()
	task.defer(saveProfile, profile.player, false)
	return true, profile.data.candyDeliveryToken
end

local function completeCandyDelivery(profile, metadata)
	if not profile or not profile.loaded or profile.releasing
		or not partyCanProgress()
		or profile.data.candyDeliveryActive ~= true
	then
		return false
	end
	local reportedToken = type(metadata) == "table" and tostring(metadata.batchToken or "") or ""
	if reportedToken == "" or reportedToken ~= profile.data.candyDeliveryToken then
		return false
	end
	local payout = finiteInteger(candyDeliveryConfig.Payout, 3000, 1, 2_000_000_000)
	-- Consume the durable contract before crediting money. A duplicate prompt,
	-- stale callback, or replayed Bindable invocation therefore cannot pay twice.
	profile.data.candyDeliveryActive = false
	profile.data.candyDeliveryToken = ""
	profile.data.candyBatchReady = false
	profile.data.candyBatchToken = ""
	profile.data.candyBatchesSold = finiteInteger(profile.data.candyBatchesSold, 0, 0, 10_000_000) + 1
	setAllowance(profile, profile.data.allowance + payout)
	markDirty(profile)
	syncCandyDeliveryAttributes(profile)
	local deliveryState = candyDeliverySnapshot(profile)
	feedback(profile.player, "CandyDeliveryComplete", {
		title = "BATCH SOLD",
		payout = payout,
		text = string.format("Los Pollos Hermanos accepted the batch. You earned a huge $%d payout!", payout),
	})
	candyDeliveryChanged:Fire(profile.player, "Complete", deliveryState)
	broadcastState()
	task.defer(saveProfile, profile.player, false)
	return true, payout
end

local hostWorldActionEvents = {
	TaskUpgradeDeliverySpawned = true,
	TaskUpgradeCratePicked = true,
	TaskUpgradeInstalled = true,
	TaskUpgradeCarryLost = true,
	ChemistryDeliverySpawned = true,
	ChemistryCratePicked = true,
	ChemistrySetupPlaced = true,
	ChemistryCarryLost = true,
	BoomboxPlaybackFailed = true,
	BoomboxDeliverySpawned = true,
	BoomboxCratePicked = true,
	BoomboxPlaced = true,
	BoomboxCarryLost = true,
	MachineDeliverySpawned = true,
	MachineCratePicked = true,
	MachinePartInstalled = true,
}

local sharedCarryRollbackEvents = {
	BeerCarryLost = true,
	TrashCarryLost = true,
	MissyPlushCarryLost = true,
}

local function reportPlayerAction(eventKey, player, metadata)
	local profile = profiles[player]
	local graceRollbackAllowed = type(eventKey) == "string"
		and sharedCarryRollbackEvents[eventKey] == true
		and partySession.state == "HostGrace"
	if not profile or not profile.loaded or profile.releasing or type(eventKey) ~= "string"
		or not partyIsMember(player) or (not partyCanProgress() and not graceRollbackAllowed)
	then
		return false
	end
	if hostWorldActionEvents[eventKey] and not partyIsHost(player) then
		return false
	end
	metadata = type(metadata) == "table" and metadata or {}
	local record = partySession.task
	local reportedUpgradeId = type(metadata.upgradeId) == "string" and metadata.upgradeId or ""
	local pendingUpgradeId = profile.data.pendingTaskUpgradeId
	local pendingUpgrade = automationById[pendingUpgradeId]

	if eventKey == "CandyBatchProduced" then
		return createCandyBatch(profile, metadata)
	elseif eventKey == "CandyBatchCollected" then
		return beginCandyDelivery(profile, metadata)
	elseif eventKey == "CandyBatchDelivered" then
		return completeCandyDelivery(profile, metadata)
	end

	if eventKey == "TaskUpgradeDeliverySpawned"
		and pendingUpgrade
		and reportedUpgradeId == pendingUpgradeId
	then
		if profile.taskUpgradeDeliveryStep ~= "WaitingDelivery" then
			return profile.taskUpgradeDeliveryStep == "Collect" or profile.taskUpgradeDeliveryStep == "Install"
		end
		profile.deliveryQueued.TaskUpgrade = false
		profile.taskUpgradeDeliveryStep = "Collect"
		feedback(player, "DeliveryArrived", {
			upgradeId = pendingUpgradeId,
			text = pendingUpgrade.name .. " has arrived in the driveway.",
		})
		broadcastState()
		return true
	elseif eventKey == "TaskUpgradeCratePicked"
		and pendingUpgrade
		and reportedUpgradeId == pendingUpgradeId
	then
		if profile.taskUpgradeDeliveryStep ~= "Collect" then
			return profile.taskUpgradeDeliveryStep == "Install"
		end
		profile.taskUpgradeDeliveryStep = "Install"
		feedback(player, "DeliveryPicked", {
			upgradeId = pendingUpgradeId,
			targetHint = pendingUpgrade.installTarget,
			text = string.format("Carry %s to its marked installation spot.", pendingUpgrade.name),
		})
		broadcastState()
		return true
	elseif eventKey == "TaskUpgradeInstalled"
		and pendingUpgrade
		and reportedUpgradeId == pendingUpgradeId
		and profile.taskUpgradeDeliveryStep == "Install"
	then
		profile.data.taskAutomationInstalled[pendingUpgradeId] = true
		profile.data.pendingTaskUpgradeId = ""
		profile.taskUpgradeDeliveryStep = nil
		profile.deliveryQueued.TaskUpgrade = false
		markDirty(profile)
		feedback(player, "TaskUpgradeInstalled", {
			upgradeId = pendingUpgradeId,
			taskId = pendingUpgrade.taskId,
			name = pendingUpgrade.name,
			text = pendingUpgrade.name .. " installed! Its matching task will now run automatically.",
		})
		local activeRecord = partySession.task
		if activeRecord and activeRecord.id == pendingUpgrade.taskId and activeRecord.automated ~= true then
			destroyManualCarryForAutomation(player, activeRecord.id)
			if armTaskAutomation(activeRecord, pendingUpgrade) then
				launchTaskAutomation(profile, activeRecord, pendingUpgrade)
			end
		end
		broadcastState()
		task.defer(saveProfile, player, false)
		if profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced then
			profile.chemistryDeliveryStep = "WaitingDelivery"
			queueDelivery(profile, "ChemistrySetup", 0)
		end
		return true
	elseif eventKey == "TaskUpgradeCarryLost"
		and pendingUpgrade
		and reportedUpgradeId == pendingUpgradeId
		and profile.taskUpgradeDeliveryStep == "Install"
	then
		profile.deliveryQueued.TaskUpgrade = false
		profile.taskUpgradeDeliveryStep = "WaitingDelivery"
		queueDelivery(profile, "TaskUpgrade", 0, pendingUpgradeId)
		feedback(player, "Error", {
			upgradeId = pendingUpgradeId,
			text = "The lost " .. pendingUpgrade.name .. " is being redelivered. Watch for the truck.",
		})
		broadcastState()
		return true
	elseif eventKey == "ChemistryDeliverySpawned"
		and profile.data.chemistrySetupPurchased
		and not profile.data.chemistrySetupPlaced
	then
		if profile.chemistryDeliveryStep ~= "WaitingDelivery" then
			return profile.chemistryDeliveryStep == "Collect" or profile.chemistryDeliveryStep == "Install"
		end
		profile.deliveryQueued.ChemistrySetup = false
		profile.chemistryDeliveryStep = "Collect"
		feedback(player, "ChemistryDeliveryArrived", {
			text = "Your advanced chemistry equipment has arrived in the driveway.",
		})
		broadcastState()
		return true
	elseif eventKey == "ChemistryCratePicked"
		and profile.data.chemistrySetupPurchased
		and not profile.data.chemistrySetupPlaced
	then
		if profile.chemistryDeliveryStep ~= "Collect" then
			return profile.chemistryDeliveryStep == "Install"
		end
		profile.chemistryDeliveryStep = "Install"
		feedback(player, "ChemistryDeliveryPicked", {
			targetHint = chemistrySetupConfig.InstallTarget,
			text = "Carry the research case through the backyard hatch to the glowing chemistry bay in your bunker.",
		})
		broadcastState()
		return true
	elseif eventKey == "ChemistrySetupPlaced"
		and profile.data.chemistrySetupPurchased
		and not profile.data.chemistrySetupPlaced
		and profile.chemistryDeliveryStep == "Install"
	then
		profile.data.chemistrySetupPlaced = true
		profile.chemistryDeliveryStep = nil
		profile.deliveryQueued.ChemistrySetup = false
		markDirty(profile)
		syncChemistrySetupAttributes(profile)
		feedback(player, "ChemistrySetupPlaced", {
			name = chemistrySetupConfig.Name,
			text = "Advanced chemistry lab online! The reactor, pumps, and fluid network are ready in the bunker.",
		})
		broadcastState()
		task.defer(saveProfile, player, false)
		return true
	elseif eventKey == "ChemistryCarryLost"
		and profile.data.chemistrySetupPurchased
		and not profile.data.chemistrySetupPlaced
		and profile.chemistryDeliveryStep == "Install"
	then
		profile.deliveryQueued.ChemistrySetup = false
		profile.chemistryDeliveryStep = "WaitingDelivery"
		queueDelivery(profile, "ChemistrySetup", 0)
		feedback(player, "ChemistrySetupError", {
			text = "The lost research case is being redelivered. Watch for the truck.",
		})
		broadcastState()
		return true
	elseif eventKey == "BoomboxPlaybackFailed" then
		local message = string.sub(tostring(metadata.message or "The boombox audio could not be played."), 1, 240)
		message = string.gsub(message, "[%c]", " ")
		feedback(player, "BoomboxError", {
			message = message,
			text = message,
		})
		return true
	elseif eventKey == "BoomboxDeliverySpawned"
		and profile.data.boomboxPurchased and not profile.data.boomboxPlaced
	then
		if profile.boomboxDeliveryStep ~= "WaitingDelivery" then
			return profile.boomboxDeliveryStep == "Collect" or profile.boomboxDeliveryStep == "Install"
		end
		profile.deliveryQueued.Boombox = false
		profile.boomboxDeliveryStep = "Collect"
		feedback(player, "DeliveryArrived", { text = "Your boombox has arrived in the driveway." })
		broadcastState()
		return true
	elseif eventKey == "BoomboxCratePicked"
		and profile.data.boomboxPurchased and not profile.data.boomboxPlaced
	then
		if profile.boomboxDeliveryStep ~= "Collect" then
			return profile.boomboxDeliveryStep == "Install"
		end
		profile.boomboxDeliveryStep = "Install"
		feedback(player, "DeliveryPicked", {
			text = "Follow the purple arrow into the living room. The boombox will set itself up in the marked area.",
		})
		broadcastState()
		return true
	elseif eventKey == "BoomboxPlaced"
		and profile.data.boomboxPurchased and not profile.data.boomboxPlaced
		and profile.boomboxDeliveryStep == "Install"
	then
		profile.data.boomboxPlaced = true
		profile.boomboxDeliveryStep = nil
		profile.deliveryQueued.Boombox = false
		markDirty(profile)
		syncBoomboxPlacedAttribute(profile)
		feedback(player, "BoomboxPlaced", {
			text = "Boombox set up! Turn it on to start earning while the song plays.",
		})
		broadcastState()
		task.defer(saveProfile, player, false)
		if profile.data.pendingPartStage == 0 and profile.data.pendingTaskUpgradeId ~= "" then
			profile.taskUpgradeDeliveryStep = "WaitingDelivery"
			queueDelivery(profile, "TaskUpgrade", 0, profile.data.pendingTaskUpgradeId)
		elseif profile.data.pendingPartStage == 0
			and profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced
		then
			profile.chemistryDeliveryStep = "WaitingDelivery"
			queueDelivery(profile, "ChemistrySetup", 0)
		end
		return true
	elseif eventKey == "BoomboxCarryLost"
		and profile.data.boomboxPurchased and not profile.data.boomboxPlaced
		and profile.boomboxDeliveryStep == "Install"
	then
		profile.deliveryQueued.Boombox = false
		profile.boomboxDeliveryStep = "WaitingDelivery"
		queueDelivery(profile, "Boombox", 0)
		feedback(player, "BoomboxError", {
			message = "The lost boombox is being redelivered. Watch for the truck.",
			text = "The lost boombox is being redelivered. Watch for the truck.",
		})
		broadcastState()
		return true
	elseif eventKey == "MachineDeliverySpawned" and profile.data.pendingPartStage > 0 then
		local reportedStage = finiteInteger(metadata.stage, 0, 0, #Config.MachineStages)
		if reportedStage ~= profile.data.pendingPartStage then
			return false
		end
		if profile.partDeliveryStep ~= "WaitingDelivery" then
			return profile.partDeliveryStep == "Collect" or profile.partDeliveryStep == "Install"
		end
		profile.deliveryQueued.MachinePart = false
		profile.partDeliveryStep = "Collect"
		feedback(player, "DeliveryArrived", { text = "Your Time Machine component has arrived in the driveway." })
		broadcastState()
		return true
	elseif eventKey == "MachineCratePicked" and profile.data.pendingPartStage > 0 then
		local reportedStage = finiteInteger(metadata.stage, 0, 0, #Config.MachineStages)
		if reportedStage ~= profile.data.pendingPartStage then
			return false
		end
		if profile.partDeliveryStep ~= "Collect" then
			return profile.partDeliveryStep == "Install"
		end
		profile.partDeliveryStep = "Install"
		feedback(player, "DeliveryPicked", { text = "Carry the component crate to the garage installation bay." })
		broadcastState()
		return true
	elseif eventKey == "MachinePartInstalled" and profile.data.pendingPartStage > 0
		and profile.partDeliveryStep == "Install"
	then
		local requestedStage = finiteInteger(metadata.stage, 0, 0, #Config.MachineStages)
		if requestedStage ~= profile.data.pendingPartStage or requestedStage ~= profile.data.machineStage + 1 then
			return false
		end
		profile.data.machineStage = requestedStage
		profile.data.pendingPartStage = 0
		profile.partDeliveryStep = nil
		profile.deliveryQueued.MachinePart = false
		markDirty(profile)
		player:SetAttribute("MachineStage", requestedStage)
		local definition = Config.MachineStages[requestedStage]
		feedback(player, "MachineStage", {
			title = definition.name .. " installed",
			text = string.format("Time Machine construction is now %d%% complete.", definition.progress),
			progress = definition.progress,
		})
		broadcastState()
		task.defer(saveProfile, player, false)
		if profile.data.boomboxPurchased and not profile.data.boomboxPlaced then
			profile.boomboxDeliveryStep = "WaitingDelivery"
			queueDelivery(profile, "Boombox", 0)
		elseif profile.data.pendingTaskUpgradeId ~= "" then
			profile.taskUpgradeDeliveryStep = "WaitingDelivery"
			queueDelivery(profile, "TaskUpgrade", 0, profile.data.pendingTaskUpgradeId)
		elseif profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced then
			profile.chemistryDeliveryStep = "WaitingDelivery"
			queueDelivery(profile, "ChemistrySetup", 0)
		end
		return true
	end

	if not record then
		return false
	end
	if record.automated then
		-- Installed robots are completed only by the server timer created with
		-- this exact record. Ignore every manual world/client completion path.
		return false
	end
	if eventKey == "DishesCompleted" and record.id == "MaryDishes" then
		return completeTask(profile)
	elseif eventKey == "TrashPicked" and record.id == "MaryTrash" and record.step == "Pickup" then
		if record.carrierUserId ~= nil and record.carrierUserId ~= player.UserId then
			return false
		end
		record.carrierUserId = player.UserId
		record.step = "Deliver"
		feedback(player, "TaskProgress", { text = "Now follow the arrow to the garage-side garbage can outside." })
		broadcastState()
		return true
	elseif eventKey == "TrashDelivered" and record.id == "MaryTrash" and record.step == "Deliver"
		and record.carrierUserId == player.UserId
	then
		return completeTask(profile)
	elseif eventKey == "MissyPlushCollected" and record.id == "MissyPlush" and record.step == "Search" then
		if record.carrierUserId ~= nil and record.carrierUserId ~= player.UserId then
			return false
		end
		record.carrierUserId = player.UserId
		record.step = "Return"
		feedback(player, "TaskProgress", { text = "You found it! Return the stuffed animal to Missy's bed." })
		broadcastState()
		return true
	elseif eventKey == "MissyPlushReturned" and record.id == "MissyPlush" and record.step == "Return"
		and record.carrierUserId == player.UserId
	then
		return completeTask(profile)
	elseif eventKey == "BeerDeliverySpawned" and record.id == "GeorgeBeer" and record.step == "WaitingDelivery"
		and record.carrierUserId == player.UserId
	then
		profile.deliveryQueued.Beer = false
		record.step = "Collect"
		feedback(player, "DeliveryArrived", { text = "George's beer delivery has arrived in the driveway." })
		broadcastState()
		return true
	elseif eventKey == "BeerCratePicked" and record.id == "GeorgeBeer" and record.step == "Collect"
		and record.carrierUserId == player.UserId
	then
		record.step = "Deliver"
		feedback(player, "TaskProgress", { text = "Carry the beer crate to the kitchen refrigerator." })
		broadcastState()
		return true
	elseif eventKey == "BeerDelivered" and record.id == "GeorgeBeer" and record.step == "Deliver"
		and record.carrierUserId == player.UserId
	then
		return completeTask(profile)
	elseif eventKey == "BeerCarryLost" and record.id == "GeorgeBeer" and record.step == "Deliver"
		and record.carrierUserId == player.UserId
	then
		profile.deliveryQueued.Beer = false
		if partySession.state == "HostGrace" then
			-- Delivery workers correctly refuse to run during host grace. Returning to
			-- Order avoids retaining a delivery owned by the destroyed character and
			-- lets any present member place a fresh order as soon as the host returns.
			record.carrierUserId = nil
			record.step = "Order"
			feedback(player, "TaskProgress", {
				text = "The beer crate was lost. Order a replacement after the party host reconnects.",
			})
		else
			record.step = "WaitingDelivery"
			queueDelivery(profile, "Beer", 0)
			feedback(player, "TaskProgress", { text = "The lost beer crate is being redelivered. Watch for the truck." })
		end
		broadcastState()
		return true
	elseif eventKey == "TrashCarryLost" and record.id == "MaryTrash" and record.step == "Deliver"
		and record.carrierUserId == player.UserId
	then
		record.carrierUserId = nil
		record.step = "Pickup"
		feedback(player, "TaskProgress", { text = "Pick up a replacement bag from the kitchen garbage can." })
		broadcastState()
		return true
	elseif eventKey == "MissyPlushCarryLost" and record.id == "MissyPlush" and record.step == "Return"
		and record.carrierUserId == player.UserId
	then
		record.carrierUserId = nil
		record.step = "Search"
		feedback(player, "TaskProgress", { text = "Missy's toy slipped away. Follow the glowing arrow to find it again." })
		broadcastState()
		return true
	end
	return false
end

reportAction.Event:Connect(reportPlayerAction)
registerAction.Event:Connect(function() end)

local function adjustAllowance(subject, rawDelta, reason)
	local delta = tonumber(rawDelta)
	if not delta or delta ~= delta or delta == math.huge or delta == -math.huge or math.abs(delta) > 2_000_000_000 then
		return false, "Invalid allowance adjustment"
	end
	delta = if delta >= 0 then math.floor(delta + 0.5) else math.ceil(delta - 0.5)
	local recipients = {}
	if typeof(subject) == "Instance" and subject:IsA("Player") then
		local profile = profiles[subject]
		if not profile or not profile.loaded or profile.releasing then
			return false, "Profile is not loaded"
		end
		table.insert(recipients, profile)
	elseif subject == nil then
		recipients = presentProfiles()
	else
		return false, "Invalid allowance recipient"
	end
	if #recipients == 0 then
		return false, "No loaded player profiles"
	end
	for _, profile in ipairs(recipients) do
		if profile.data.allowance + delta < 0 then
			return false, "Insufficient allowance"
		end
	end
	for _, profile in ipairs(recipients) do
		setAllowance(profile, profile.data.allowance + delta)
		feedback(profile.player, "Currency", {
			allowance = delta,
			reason = tostring(reason or "Allowance adjustment"),
		})
		task.defer(saveProfile, profile.player, false)
	end
	broadcastState()
	if #recipients == 1 then
		return true, recipients[1].data.allowance
	end
	return true, #recipients
end

local function boomboxFailure(message, remaining, retryAfter)
	return {
		ok = false,
		message = tostring(message or "The boombox is unavailable."),
		remaining = math.max(0, tonumber(remaining) or 0),
		retryAfter = math.max(0, tonumber(retryAfter) or 0),
	}
end

local function announceBoomboxReady(profile, automatic)
	if not profile or not profile.loaded or profile.releasing
		or not partyIsHost(profile.player)
		or not profile.data.boomboxPurchased or not profile.data.boomboxPlaced
		or profile.boomboxPlayback
	then
		return false
	end
	local readyAt = finiteInteger(profile.data.boomboxNextPlayAt, 0, 0, 4_102_444_800)
	if readyAt <= 0 or unixNow() < readyAt or profile.boomboxReadyNoticeKey == readyAt then
		return false
	end
	profile.boomboxReadyNoticeKey = readyAt
	feedback(profile.player, "BoomboxReady", {
		automatic = automatic == true,
		source = automatic == true and "Autoplay" or "Manual",
		text = automatic == true
			and "The boombox cooldown finished. It is ready, and autoplay is starting the next party."
			or "The boombox cooldown finished. It is ready to play in the living room.",
	})
	return true
end

local function beginBoomboxPlayback(player, requestedSource)
	-- Older world scripts omit the source and retain manual behavior. Autoplay
	-- must be named explicitly and is re-authorized against the saved purchase;
	-- a world snapshot is presentation, never the entitlement boundary.
	local playbackSource = requestedSource == "Autoplay" and "Autoplay" or "Manual"
	local automatic = playbackSource == "Autoplay"
	local profile = typeof(player) == "Instance" and player:IsA("Player") and profiles[player] or nil
	if not profile or not profile.loaded or profile.releasing then
		return boomboxFailure("Profile is not loaded.")
	end
	local allowed, denial = hostMutationAllowed(profile)
	if not allowed then
		return boomboxFailure(denial)
	end
	if automatic and profile.data.boomboxAutoplayPurchased ~= true then
		return boomboxFailure("The boombox autoplay upgrade is not installed.")
	end
	if not profile.data.boomboxPurchased or not profile.data.boomboxPlaced then
		local message = "Buy, deliver, and set up the boombox first."
		if not automatic then
			feedback(player, "BoomboxError", { message = message, text = message })
		end
		return boomboxFailure(message)
	end
	if profile.boomboxPlayback then
		return boomboxFailure("Your boombox song is already playing.")
	end
	if boomboxPlaybackOwner and boomboxPlaybackOwner ~= player then
		local activeProfile = profiles[boomboxPlaybackOwner]
		if activeProfile and activeProfile.boomboxPlayback then
			local message = "Someone else is already using the living-room boombox."
			if not automatic then
				feedback(player, "BoomboxError", { message = message, text = message })
			end
			return boomboxFailure(message)
		end
		boomboxPlaybackOwner = nil
	end
	local remaining = math.max(0, profile.data.boomboxNextPlayAt - unixNow())
	if remaining > 0 then
		local message = "The boombox is cooling down. Ready in " .. formatCountdown(remaining) .. "."
		if not automatic then
			feedback(player, "BoomboxError", { message = message, text = message, remaining = remaining })
		end
		return boomboxFailure(message, remaining)
	end
	-- This is also the fail-safe for autoplay winning the half-second polling
	-- race before the regular server loop can announce the exact ready instant.
	announceBoomboxReady(profile, automatic)

	boomboxSessionSerial += 1
	local startedAt = serverNow()
	local sessionId = string.format("boombox:%d:%d:%d", player.UserId, boomboxSessionSerial, math.floor(startedAt * 1000))
	local nextPlayAt = unixNow() + math.ceil(Config.Boombox.TrackDuration + Config.Boombox.CooldownSeconds)
	profile.data.boomboxNextPlayAt = nextPlayAt
	profile.boomboxReadyNoticeKey = nil
	profile.boomboxPlayback = {
		sessionId = sessionId,
		startedAt = startedAt,
		source = playbackSource,
		paidTicks = 0,
		totalPaid = 0,
	}
	boomboxPlaybackOwner = player
	markDirty(profile)
	feedback(player, "BoomboxStarted", {
		text = automatic
			and "Autoplay started the boombox. Allowance will arrive with the beat."
			or "The boombox is playing. Allowance will arrive with the beat.",
		earned = 0,
		cooldown = Config.Boombox.CooldownSeconds,
		duration = Config.Boombox.TrackDuration,
		source = playbackSource,
	})
	broadcastState()
	task.defer(saveProfile, player, false)
	task.delay(Config.Boombox.TrackDuration + Config.Boombox.CooldownSeconds + 0.25, function()
		if profiles[player] == profile and profile.loaded and not profile.releasing then
			-- Refresh canPlay/status even if the player has left a family task active
			-- long enough that no other snapshot happened at cooldown expiry.
			broadcastState()
		end
	end)
	return {
		ok = true,
		sessionId = sessionId,
		duration = Config.Boombox.TrackDuration,
		interval = Config.Boombox.PayoutInterval,
		maxTicks = Config.Boombox.MaximumPaidTicks,
		payoutPerTick = Config.Boombox.PayoutPerTick,
		nextPlayAt = nextPlayAt,
		source = playbackSource,
	}
end

local function creditBoomboxTick(profile, playback)
	playback.paidTicks += 1
	playback.totalPaid += Config.Boombox.PayoutPerTick
	setAllowance(profile, profile.data.allowance + Config.Boombox.PayoutPerTick)
	return Config.Boombox.PayoutPerTick
end

local function boomboxPayoutTick(player, sessionId)
	local profile = typeof(player) == "Instance" and player:IsA("Player") and profiles[player] or nil
	if not profile or not profile.loaded or profile.releasing then
		return boomboxFailure("Profile is not loaded.")
	end
	if not partyCanProgress() or not partyIsHost(player) or hostProfile() ~= profile then
		return boomboxFailure("Boombox payouts pause until the party host is active.")
	end
	local playback = profile.boomboxPlayback
	if type(sessionId) ~= "string" or not playback or playback.sessionId ~= sessionId
		or boomboxPlaybackOwner ~= player
	then
		return boomboxFailure("That boombox playback session is no longer active.")
	end
	if not profile.data.boomboxPurchased or not profile.data.boomboxPlaced then
		return boomboxFailure("The boombox is not set up.")
	end
	if playback.paidTicks >= Config.Boombox.MaximumPaidTicks then
		return boomboxFailure("Every payout for this song has already been awarded.")
	end

	local currentTime = serverNow()
	local elapsed = currentTime - playback.startedAt
	local dueAt = playback.startedAt + (playback.paidTicks + 1) * Config.Boombox.PayoutInterval
	if currentTime + BOOMBOX_TICK_EARLY_TOLERANCE < dueAt then
		local retryAfter = dueAt - currentTime
		return boomboxFailure("That payout tick is too early.", 0, retryAfter)
	end
	if elapsed > Config.Boombox.TrackDuration + BOOMBOX_FINAL_TICK_TOLERANCE then
		return boomboxFailure("The payout window for this song has ended.")
	end

	local awarded = creditBoomboxTick(profile, playback)
	broadcastState()
	return {
		ok = true,
		awarded = awarded,
		paidTicks = playback.paidTicks,
		remainingTicks = Config.Boombox.MaximumPaidTicks - playback.paidTicks,
		allowance = profile.data.allowance,
	}
end

local function endBoomboxPlayback(profile, sessionId, reason, suppressFeedback)
	if not profile or not profile.loaded then
		return boomboxFailure("Profile is not loaded.")
	end
	local playback = profile.boomboxPlayback
	if type(sessionId) ~= "string" or not playback or playback.sessionId ~= sessionId then
		return boomboxFailure("That boombox playback session is no longer active.")
	end
	local endedReason = string.sub(tostring(reason or "Stopped"), 1, 48)
	local elapsed = serverNow() - playback.startedAt
	-- Sound.Ended and the tenth scheduled tick occur at the same instant. If the
	-- complete track won that race, award only that one final due tick. Early
	-- stops never enter this branch, and the hard tick cap remains unchanged.
	if endedReason == "Completed"
		and playback.paidTicks == Config.Boombox.MaximumPaidTicks - 1
		and elapsed >= Config.Boombox.TrackDuration - BOOMBOX_FINAL_TICK_TOLERANCE
		and elapsed <= Config.Boombox.TrackDuration + BOOMBOX_FINAL_TICK_TOLERANCE
	then
		creditBoomboxTick(profile, playback)
	end

	profile.boomboxPlayback = nil
	if boomboxPlaybackOwner == profile.player then
		boomboxPlaybackOwner = nil
	end
	local earned = playback.totalPaid
	local paidTicks = playback.paidTicks
	local remaining = math.max(0, profile.data.boomboxNextPlayAt - unixNow())
	if not suppressFeedback then
		feedback(profile.player, "BoomboxFinished", {
			text = string.format("The song finished and earned $%d allowance.", earned),
			earned = earned,
			cooldown = remaining,
			reason = endedReason,
		})
	end
	broadcastState()
	if not profile.releasing and not suppressFeedback then
		task.defer(saveProfile, profile.player, false)
	end
	return {
		ok = true,
		earned = earned,
		paidTicks = paidTicks,
		cooldown = remaining,
		nextPlayAt = profile.data.boomboxNextPlayAt,
	}
end

local function endBoomboxPlaybackForPlayer(player, sessionId, reason)
	local profile = typeof(player) == "Instance" and player:IsA("Player") and profiles[player] or nil
	return endBoomboxPlayback(profile, sessionId, reason, false)
end

serverAPI.OnInvoke = function(operation, arg1, arg2, arg3, arg4)
	if operation == "GetSnapshot" then
		return snapshotFor(typeof(arg1) == "Instance" and arg1:IsA("Player") and arg1 or nil)
	elseif operation == "ReportAction" and typeof(arg1) == "Instance" and arg1:IsA("Player") then
		return reportPlayerAction(tostring(arg2), arg1, arg3)
	elseif operation == "AdjustCurrency" then
		return adjustAllowance(arg1, arg2, arg4 or arg3)
	elseif operation == "SpendAllowance" then
		local amount = tonumber(arg2)
		if not amount or amount <= 0 then
			return false, "Allowance cost must be positive"
		end
		return adjustAllowance(arg1, -amount, arg3)
	elseif operation == "OrderMachinePart" then
		local player = typeof(arg1) == "Instance" and arg1:IsA("Player") and arg1 or nil
		return orderMachinePart(player and profiles[player], arg2)
	elseif operation == "OrderTaskUpgrade" then
		local player = typeof(arg1) == "Instance" and arg1:IsA("Player") and arg1 or nil
		if not player or not validComputerSession(player) then
			return false, "Use Sheldon's computer before ordering a task automation upgrade."
		end
		local requestedUpgradeId = if type(arg2) == "table" then arg2.upgradeId else arg2
		return orderTaskUpgrade(profiles[player], requestedUpgradeId)
	elseif operation == "OrderSecretBunker" then
		local player = typeof(arg1) == "Instance" and arg1:IsA("Player") and arg1 or nil
		if not player or not validComputerSession(player) then
			return false, "Use Sheldon's computer before ordering the secret underground bunker."
		end
		return orderSecretBunker(profiles[player])
	elseif operation == "OrderChemistrySetup" then
		local player = typeof(arg1) == "Instance" and arg1:IsA("Player") and arg1 or nil
		if not player or not validBunkerComputerSession(player) then
			return false, "Use the research computer inside your bunker before ordering chemistry equipment."
		end
		return orderChemistrySetup(profiles[player])
	elseif operation == "BeginBoomboxPlayback" then
		return beginBoomboxPlayback(arg1, arg2)
	elseif operation == "BoomboxPayoutTick" then
		return boomboxPayoutTick(arg1, arg2)
	elseif operation == "EndBoomboxPlayback" then
		return endBoomboxPlaybackForPlayer(arg1, arg2, arg3)
	elseif operation == "InstallMachineStage" and typeof(arg2) == "Instance" and arg2:IsA("Player") then
		return reportPlayerAction("MachinePartInstalled", arg2, { stage = arg1 })
	elseif operation == "PurchaseMachineStage" then
		return false, "Order paid components through Sheldon's computer and install the delivered crate."
	end
	return nil
end

local function passRequestCooldown(player)
	local nowClock = os.clock()
	if (requestNextAt[player] or 0) > nowClock then
		return false
	end
	requestNextAt[player] = nowClock + Config.RequestCooldown
	return true
end

local function passSnapshotCooldown(player)
	local nowClock = os.clock()
	if (snapshotNextAt[player] or 0) > nowClock then
		return false
	end
	snapshotNextAt[player] = nowClock + SNAPSHOT_REQUEST_COOLDOWN
	return true
end

bankHackEvent.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" then
		return
	end
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.releasing or not partyIsMember(player) then
		return
	end
	if action ~= "Cancel" and not partyCanProgress() then
		bankPacket(player, "BankHackError", {
			text = "BANKLINK is paused while the party host reconnects.",
			reason = "Party paused",
			serverTime = serverNow(),
		})
		return
	end
	if action == "Start" then
		if not passRequestCooldown(player) then
			-- Never drop a start request silently: the client enters its Connecting
			-- state before sending this packet, so it needs a response to become
			-- interactive again if another terminal request just used the debounce.
			bankPacket(player, "BankHackError", {
				text = "BANKLINK modem is busy. Dial again in a moment.",
				reason = "Start rate limited",
				serverTime = serverNow(),
			})
			return
		end
		local started, reason, retryReadyAt = startBankHack(profile)
		if not started and reason then
			bankPacket(player, "BankHackError", {
				text = tostring(reason),
				reason = tostring(reason),
				retryReadyAt = retryReadyAt,
				serverTime = serverNow(),
			})
		end
	elseif action == "Input" then
		local accepted, reason = submitBankHackInput(profile, payload)
		if not accepted and reason then
			bankPacket(player, "BankHackError", {
				sessionId = profile.bankHackSession and profile.bankHackSession.id or nil,
				text = tostring(reason),
				reason = tostring(reason),
				serverTime = serverNow(),
			})
		end
	elseif action == "Cancel" then
		local session = profile.bankHackSession
		local reportedId = type(payload) == "table" and payload.sessionId or nil
		if session and reportedId ~= nil and reportedId ~= session.id then
			bankPacket(player, "BankHackError", {
				text = "That Medford Bank session is no longer active.",
				reason = "Session mismatch",
				serverTime = serverNow(),
			})
			return
		end
		-- Treat a late duplicate cancel as idempotent. This commonly arrives when
		-- the UI closes just after a success/failure packet and must not overwrite it.
		cancelBankHackSession(profile, "Bank connection cancelled.", true)
	else
		bankPacket(player, "BankHackError", {
			text = "BANKLINK rejected an unknown command.",
			reason = "Unknown action",
			serverTime = serverNow(),
		})
	end
end)

requestEvent.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" then
		return
	end
	if action == "RequestSnapshot" then
		if not passSnapshotCooldown(player) then
			return
		end
	elseif action ~= "CloseComputer"
		and action ~= "CloseBunkerComputer"
		and not passRequestCooldown(player)
	then
		return
	end
	if action == "OrderChemistrySetup" and not validBunkerComputerSession(player) then
		player:SetAttribute("CooperBunkerComputerSessionUntil", nil)
		feedback(player, "BunkerTerminalClose", {
			text = "Use the research computer inside your bunker to order chemistry equipment.",
		})
		feedback(player, "ChemistrySetupError", {
			text = "The bunker research terminal session is no longer active.",
		})
		return
	end
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.releasing or not partyIsMember(player) then
		return
	end
	if (action == "OrderBeer"
		or action == "OrderMachinePart"
		or action == "OrderBoombox"
		or action == "UpgradeBoomboxAutoplay"
		or action == "OrderTaskUpgrade"
		or action == "OrderSecretBunker"
		or action == "LegacyCommand")
		and not validComputerSession(player)
	then
		player:SetAttribute("CooperComputerSessionUntil", nil)
		feedback(player, "TerminalClose", { text = "Use Sheldon's computer to access the terminal." })
		feedback(player, "Error", { text = "Use Sheldon's computer before ordering or running terminal commands." })
		return
	end
	if action == "RequestSnapshot" then
		sendSnapshot(player)
	elseif action == "TutorialSeen" then
		profile.data.tutorialSeen = true
		markDirty(profile)
		sendSnapshot(player)
	elseif action == "CloseComputer" then
		cancelBankHackSession(profile, "Computer terminal closed.", true)
		player:SetAttribute("CooperComputerSessionUntil", nil)
		feedback(player, "TerminalClose", { text = "Terminal closed" })
	elseif action == "CloseBunkerComputer" then
		player:SetAttribute("CooperBunkerComputerSessionUntil", nil)
		feedback(player, "BunkerTerminalClose", { text = "Research terminal closed" })
	elseif action == "OrderBeer" then
		if not partyCanProgress() then
			feedback(player, "Error", { text = "Tasks are paused while the party host reconnects." })
			return
		end
		local record = partySession.task
		local worldProfile = hostProfile()
		if record and record.automated then
			feedback(player, "Error", { text = "BeerBot is already handling George's beer automatically." })
			return
		end
		if not record or record.id ~= "GeorgeBeer" or record.step ~= "Order" then
			feedback(player, "Error", { text = "George has not asked for a beer order right now." })
			return
		end
		if not worldProfile
			or worldProfile.data.pendingPartStage > 0
			or (worldProfile.data.boomboxPurchased and not worldProfile.data.boomboxPlaced)
			or worldProfile.data.pendingTaskUpgradeId ~= ""
			or (worldProfile.data.chemistrySetupPurchased and not worldProfile.data.chemistrySetupPlaced)
		then
			feedback(player, "Error", { text = "Finish the current truck delivery before ordering George's beer." })
			return
		end
		record.carrierUserId = player.UserId
		record.step = "WaitingDelivery"
		queueDelivery(profile, "Beer", 0)
		feedback(player, "OrderPlaced", { text = "Beer order placed. The delivery truck is on its way." })
		broadcastState()
	elseif action == "OrderMachinePart" then
		local definition = nextMachinePart(hostProfile() or profile)
		local ordered, reason = orderMachinePart(profile, definition and definition.stage or nil)
		if not ordered then
			feedback(player, "Error", { text = tostring(reason or "That component could not be ordered.") })
			return
		end
		feedback(player, "OrderPlaced", {
			text = definition.name .. " ordered. Watch for the delivery truck.",
		})
	elseif action == "OrderBoombox" then
		local ordered, reason = orderBoombox(profile)
		if not ordered then
			local message = tostring(reason or "The boombox could not be ordered.")
			feedback(player, "BoomboxError", {
				message = message,
				text = message,
			})
		end
	elseif action == "OrderTaskUpgrade" then
		local requestedUpgradeId = if type(payload) == "table"
			then payload.upgradeId
			else payload
		local ordered, reason = orderTaskUpgrade(profile, requestedUpgradeId)
		if not ordered then
			feedback(player, "Error", {
				text = tostring(reason or "That task automation upgrade could not be ordered."),
			})
		end
	elseif action == "UpgradeBoomboxAutoplay" then
		local upgraded, reason = upgradeBoomboxAutoplay(profile)
		if not upgraded then
			local message = tostring(reason or "The boombox autoplay upgrade could not be installed.")
			feedback(player, "BoomboxError", {
				message = message,
				text = message,
			})
		end
	elseif action == "OrderSecretBunker" then
		local ordered, reason = orderSecretBunker(profile)
		if not ordered then
			local message = tostring(reason or "The secret underground bunker could not be ordered.")
			feedback(player, "SecretBunkerError", {
				message = message,
				text = message,
			})
		end
	elseif action == "OrderChemistrySetup" then
		local ordered, reason = orderChemistrySetup(profile)
		if not ordered then
			local message = tostring(reason or "The advanced chemistry setup could not be ordered.")
			feedback(player, "ChemistrySetupError", {
				message = message,
				text = message,
			})
		end
	elseif action == "HiddenSeen" then
		if not partyCanProgress() then
			return
		end
		local record = partySession.task
		local markerName = type(payload) == "table" and tostring(payload.markerName or "") or ""
		local marker = taskLocation(markerName)
		if not record or record.step ~= "Search" or record.markerName ~= markerName
			or not marker or not playerNear(player, marker, 14)
		then
			return
		end
		if record.id == "MissyPlush" then
			local plush = createMissyCarryTool(player, record.plushKind)
			if plush then
				local accepted = reportPlayerAction("MissyPlushCollected", player, { markerName = markerName })
				if accepted ~= true and plush.Parent then
					plush:Destroy()
				end
			else
				feedback(player, "Error", { text = "The stuffed animal could not be picked up. Try again." })
			end
		end
	elseif action == "LegacyCommand" then
		local command = string.upper(string.sub(tostring(payload or ""), 1, 80))
		if command == "EXIT" then
			cancelBankHackSession(profile, "Computer terminal closed.", true)
			player:SetAttribute("CooperComputerSessionUntil", nil)
			feedback(player, "TerminalClose", { text = "Terminal closed" })
			return
		end
		local text = if command == "HELP"
			then "Commands: HELP, DIR, VER, TIME, EXIT"
			elseif command == "DIR"
					then "AVAILABLE ACTIONS: ORDER BEER, BUY PARTS, BUY ROBOTS, PARTY BOOMBOX, SECRET BUNKER, HACK BANK"
			elseif command == "VER"
				then "COOPER-DOS 3.11"
			elseif command == "TIME"
				then os.date("%I:%M %p")
			else "Command not recognized. Type HELP to see the command list."
		feedback(player, "TerminalLine", { command = command, text = text })
	end
end)

local function setupLeaderstats(player, profile)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local function value(name)
		local item = leaderstats:FindFirstChild(name)
		if not item then
			item = Instance.new("IntValue")
			item.Name = name
			item.Parent = leaderstats
		end
		assert(item:IsA("IntValue"), "leaderstats." .. name .. " must be an IntValue")
		return item
	end
	profile.allowanceValue = value("Allowance")
	for _, child in ipairs(leaderstats:GetChildren()) do
		if child ~= profile.allowanceValue then
			child:Destroy()
		end
	end
	setAllowance(profile, profile.data.allowance, false)
end

local function attachCharacterWatch(player, profile)
	if profile.characterAddedConnection then
		profile.characterAddedConnection:Disconnect()
	end
	local function watchCharacterDeath(character)
		task.defer(function()
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				or (character and character:WaitForChild("Humanoid", 10))
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					if profiles[player] == profile and profile.bankHackSession then
						cancelBankHackSession(profile, "The bank connection ended when your character was knocked out.", true)
					end
				end)
			end
		end)
	end
	profile.characterAddedConnection = player.CharacterAdded:Connect(watchCharacterDeath)
	if player.Character then
		watchCharacterDeath(player.Character)
	end
end

closePartyAndReturn = function(reason)
	if partySession.closingStarted then
		return false
	end
	partySession.closingStarted = true
	partySession.closeSerial += 1
	local closeSerial = partySession.closeSerial
	partySession.hostGraceSerial += 1
	partySession.state = "Closing"
	partySession.hostGraceDeadline = 0
	partySession.hostGraceUnixExpiresAt = 0
	for profile in pairs(hydratingProfiles) do
		profile.closeRequested = true
	end
	for _, profile in ipairs(presentProfiles()) do
		if profile.bankHackSession then
			cancelBankHackSession(profile, "The private house session is closing.", true)
		end
	end
	syncSessionManifest("Closed", 0)
	feedback(nil, "PartyClosing", {
		title = "RETURNING TO LOBBY",
		text = tostring(reason or "The private house session ended. Progress is being saved."),
	})
	broadcastState()
	task.spawn(function()
		-- Let in-flight atomic profile claims finish so each one can either be
		-- released by its loader or included in the final save set below.
		local hydrateDeadline = os.clock() + 20
		while next(hydratingProfiles) ~= nil and os.clock() < hydrateDeadline do
			for profile in pairs(hydratingProfiles) do
				profile.closeRequested = true
			end
			task.wait(0.1)
		end
		if partySession.closeSerial ~= closeSerial then
			return
		end

		local savedPlayers = {}
		local entries = {}
		for key, candidate in pairs(profiles) do
			table.insert(entries, { key = key, profile = candidate })
		end
		for _, entry in ipairs(entries) do
			local key = entry.key
			local candidate = entry.profile
			local saved = false
			if candidate.loaded then
				saved = saveProfile(key, true)
			elseif candidate.leaseOwned then
				saved = releaseProfileLease(candidate, RELEASE_SAVE_ATTEMPTS)
			else
				saved = true
			end
			if saved then
				local livePlayer = candidate.player
				if livePlayer and livePlayer.Parent == Players then
					table.insert(savedPlayers, livePlayer)
				end
				if profiles[key] == candidate then
					profiles[key] = nil
				end
				local userId = candidate.player and candidate.player.UserId or 0
				if profilesByUserId[userId] == candidate then
					profilesByUserId[userId] = nil
				end
			else
				warn("[CooperGame] Refusing to teleport an unsaved profile while closing the party")
				local livePlayer = candidate.player
				if livePlayer and livePlayer.Parent == Players then
					livePlayer:Kick("Your save could not be confirmed. Please rejoin after a moment so your progress stays safe.")
				end
			end
		end
		if returnSavedPartyToLobby then
			returnSavedPartyToLobby(savedPlayers)
		end
	end)
	return true
end

recoverHostWorldState = function(profile, player)
	if not profile or profiles[player] ~= profile or not partyIsHost(player)
		or not profile.loaded or profile.releasing or profile.leaseLost
	then
		return false
	end
	-- The world controller removes owner-bound crates/queues when a Player
	-- leaves. Rebuild every still-paid pending route from durable host data, and
	-- forget only the ephemeral dedupe flags tied to the old Player instance.
	profile.deliveryQueued = {}
	local bunkerState = secretBunkerSnapshot(profile)
	profile.secretBunkerCompletionAnnounced = bunkerState.unlocked
	if bunkerState.purchased then
		task.delay(0.75, function()
			if profiles[player] == profile and player.Parent == Players and profile.loaded
				and not profile.releasing and partySession.state ~= "Closing"
			then
				requestSecretBunkerPresentation(
					profile,
					bunkerState.unlocked and "ProfileLoadedUnlocked" or "ProfileLoadedResume"
				)
			end
		end)
	end

	local function queueWhenPartyReady(kind, stage, extra)
		task.spawn(function()
			task.wait(3)
			local deadline = os.clock() + partyConfig.HostReconnectGraceSeconds
			repeat
				if profiles[player] ~= profile or player.Parent ~= Players
					or not profile.loaded or profile.releasing or partySession.state == "Closing"
				then
					return
				end
				if partyCanProgress() then
					queueDelivery(profile, kind, stage, extra)
					return
				end
				task.wait(0.35)
			until os.clock() >= deadline
			warn("[CooperGame] Paid " .. tostring(kind) .. " delivery remained paused waiting for party hydration")
		end)
	end

	if profile.data.pendingPartStage == profile.data.machineStage + 1
		and profile.data.pendingPartStage <= #Config.MachineStages
	then
		profile.partDeliveryStep = "WaitingDelivery"
		queueWhenPartyReady("MachinePart", profile.data.pendingPartStage)
	elseif profile.data.pendingPartStage ~= 0 then
		profile.data.pendingPartStage = 0
		markDirty(profile)
	end
	if profile.data.boomboxPurchased and not profile.data.boomboxPlaced then
		profile.boomboxDeliveryStep = "WaitingDelivery"
		if profile.data.pendingPartStage == 0 then
			queueWhenPartyReady("Boombox", 0)
		end
	end
	if profile.data.pendingTaskUpgradeId ~= "" then
		profile.taskUpgradeDeliveryStep = "WaitingDelivery"
		if profile.data.pendingPartStage == 0
			and (not profile.data.boomboxPurchased or profile.data.boomboxPlaced)
		then
			queueWhenPartyReady("TaskUpgrade", 0, profile.data.pendingTaskUpgradeId)
		end
	end
	if profile.data.chemistrySetupPurchased and not profile.data.chemistrySetupPlaced then
		profile.chemistryDeliveryStep = "WaitingDelivery"
		if profile.data.pendingPartStage == 0
			and (not profile.data.boomboxPurchased or profile.data.boomboxPlaced)
			and profile.data.pendingTaskUpgradeId == ""
		then
			queueWhenPartyReady("ChemistrySetup", 0)
		end
	end
	for runId, record in pairs(profile.automationRuns or {}) do
		local definition = record and automationById[record.automationUpgradeId] or nil
		local remaining = record and tonumber(record.automationVisualRemaining) or 0
		if definition and type(runId) == "string" and remaining and remaining > 0 then
			task.spawn(function()
				local deadline = os.clock() + partyConfig.HostReconnectGraceSeconds
				repeat
					if profiles[player] ~= profile or profile.automationRuns[runId] ~= record
						or player.Parent ~= Players or profile.releasing or partySession.state == "Closing"
					then
						return
					end
					if partyCanProgress() then
						local now = serverNow()
						record.automationVisualLastTick = now
						record.automationCompletesAt = now + remaining
						runTaskAutomation:Fire(player, definition.id, {
							runId = runId,
							taskId = record.id,
							markerName = record.markerName,
							plushKind = record.plushKind,
							duration = remaining,
							installTarget = definition.installTarget,
							modelName = definition.modelName,
							previousStep = record.automationPreviousStep,
							startedAt = now,
							completesAt = now + remaining,
							bankCycle = record.bankCycle,
							bankReward = record.bankReward,
						})
						return
					end
					task.wait(0.25)
				until os.clock() >= deadline
				warn("[CooperGame] Paused " .. definition.id .. " visual could not resume before party hydration timed out")
			end)
		end
	end
	return true
end

-- Reconciliation workers are defined before the world-recovery function to
-- keep transaction logic adjacent to saveProfile. Bind the callback only after
-- the complete delivery/construction recovery implementation exists.
TransactionRuntime.recoverWorld = recoverHostWorldState

local function rejectHouseAdmission(player, reason)
	local message = tostring(reason or "That private party could not be verified.")
	local lobbyPlaceId = tonumber(partyConfig.LobbyPlaceId) or 0
	if not RunService:IsStudio() and lobbyPlaceId > 0 then
		local ok = pcall(function()
			TeleportService:TeleportAsync(lobbyPlaceId, { player })
		end)
		if ok then
			-- TeleportAsync accepting the request is not proof that the client reached
			-- the lobby. Do not let a failed transfer leave an unadmitted Player in the
			-- reserved house indefinitely (which would also pause the present-member
			-- reward barrier). A successful transfer removes the Player before this fires.
			task.delay(10, function()
				if player.Parent == Players and partySession.activePlayers[player.UserId] ~= player then
					player:Kick(message)
				end
			end)
			return
		end
	end
	if player.Parent == Players then
		player:Kick(message)
	end
end

local function loadPlayer(player)
	if shuttingDown then
		return
	end
	local admitted, admissionReason = validateLaunchTicket(player)
	if not admitted then
		rejectHouseAdmission(player, admissionReason)
		return
	end
	if partySession.state == "Closing" then
		rejectHouseAdmission(player, "That private party is already closing.")
		return
	end
	local occupiedSlot = partySession.activePlayers[player.UserId]
	if occupiedSlot and occupiedSlot ~= player and occupiedSlot.Parent == Players then
		rejectHouseAdmission(player, "That party member is already connected to this house.")
		return
	end
	local retained = profilesByUserId[player.UserId]
	if retained then
		local retainedIsHost = player.UserId == partySession.hostUserId
		local hostReconnectAllowed = retainedIsHost
			and partySession.state == "HostGrace"
			and serverNow() <= partySession.hostGraceDeadline
		local guestReconnectAllowed = not retainedIsHost
			and partySession.expectedMembers[player.UserId] == true
			and partySession.state ~= "Closing"
			and serverNow() < (tonumber(retained.guestGraceDeadline) or 0)
		if retained.detached ~= true
			or retained.loaded ~= true
			or retained.releasing == true
			or retained.leaseLost == true
			or (dataStore ~= nil and retained.leaseOwned ~= true)
			or (not hostReconnectAllowed and not guestReconnectAllowed)
		then
			rejectHouseAdmission(player, "That profile is already active in this party server.")
			return
		end
		partySession.activePlayers[player.UserId] = player
		setPartyPlayerAttributes(player)
		player:SetAttribute("CooperGameProfileLoaded", false)
		local previousPlayer = retained.player
		if previousPlayer then
			profiles[previousPlayer] = nil
			bankInputNextAt[previousPlayer] = nil
			requestNextAt[previousPlayer] = nil
			snapshotNextAt[previousPlayer] = nil
		end
		retained.player = player
		retained.detached = false
		retained.releasing = false
		if not retainedIsHost then
			-- Invalidate the exact delayed guest-expiry worker associated with the
			-- previous Player instance before publishing the replacement slot.
			retained.guestGraceSerial = (retained.guestGraceSerial or 0) + 1
			retained.guestGraceDeadline = 0
			retained.guestGraceUnixExpiresAt = 0
		end
		retained.allowanceValue = nil
		profiles[player] = retained
		profilesByUserId[player.UserId] = retained
		setupLeaderstats(player, retained)
		attachCharacterWatch(player, retained)
		if retainedIsHost then
			local pausedFor = math.max(0, serverNow() - partySession.pausedAt)
			if partySession.nextTaskAt < math.huge then
				partySession.nextTaskAt += pausedFor
			end
			partySession.state = "Active"
			partySession.hostGraceDeadline = 0
			partySession.hostGraceUnixExpiresAt = 0
			partySession.pausedAt = 0
			syncSessionManifest("InHouse", 0)
		else
			-- A connected admitted guest may keep a server-only route for the live
			-- session. A later disconnect replaces it with a fresh 90-second cap.
			updateMemberRejoinRoute(
				player.UserId,
				unixNow() + partyConfig.SessionLifetimeSeconds
			)
		end
		player:SetAttribute("CooperGameSchemaVersion", Config.SchemaVersion)
		player:SetAttribute("CooperGameProfileLoaded", true)
		setPartyPlayerAttributes(player)
		syncBoomboxPlacedAttribute(retained)
		syncSecretBunkerAttributes(retained)
		syncChemistrySetupAttributes(retained)
		syncCandyDeliveryAttributes(retained)
		if retainedIsHost then
			recoverHostWorldState(retained, player)
			feedback(nil, "HostReconnected", {
				title = "HOST RECONNECTED",
				text = "The host is back. Shared tasks and house progression have resumed.",
			})
		else
			feedback(nil, "GuestReconnected", {
				title = "PARTY MEMBER RECONNECTED",
				text = player.DisplayName .. " rejoined within the 90-second grace period.",
			})
		end
		broadcastState()
		return
	end
	partySession.activePlayers[player.UserId] = player
	setPartyPlayerAttributes(player)
	-- Bunker presentation uses this explicit hydration boundary to distinguish a
	-- restored owned lab from a brand-new delivery/install transition.
	player:SetAttribute("CooperGameProfileLoaded", false)
	if not partySession.loadingWatchStarted then
		partySession.loadingWatchStarted = true
		task.delay(partyConfig.HostReconnectGraceSeconds, function()
			if not shuttingDown and partySession.state == "Loading" and not hostProfile() then
				closePartyAndReturn("The party host did not finish joining the house. Returning safely to the lobby.")
			end
		end)
	end
	local profile = {
		player = player,
		data = sanitizeData(nil),
		loaded = false,
		dirty = false,
		saving = false,
		releasing = false,
		leaseToken = HttpService:GenerateGUID(false),
		leaseOwned = false,
		leaseLost = false,
		leaseExpiresAt = 0,
		revision = 0,
		transactionInFlight = false,
		transactionReconciliationBlocked = false,
		reconciliationScheduled = {},
		calmTaskCheckpointDurable = false,
		calmTaskCheckpointRecovered = false,
		calmTaskCheckpointWriteInFlight = false,
		calmTaskCheckpointRetryAt = 0,
		calmTaskCheckpointRetryCount = 0,
		-- A recovered eligibility snapshot may include this admitted player even
		-- while its exact DataStore lease is still hydrating. Keep that identity
		-- eligible only through this bounded wall-clock deadline.
		hydrationGraceExpiresAtUnix = unixNow() + partyConfig.GuestReconnectGraceSeconds,
		partDeliveryStep = nil,
		boomboxDeliveryStep = nil,
		taskUpgradeDeliveryStep = nil,
		chemistryDeliveryStep = nil,
		boomboxPlayback = nil,
		boomboxReadyNoticeKey = nil,
		bankHackSession = nil,
		secretBunkerCompletionAnnounced = false,
		automationRuns = {},
		deliveryQueued = {},
		detached = false,
		guestGraceSerial = 0,
		guestGraceDeadline = 0,
		guestGraceUnixExpiresAt = 0,
		closeRequested = false,
	}
	profiles[player] = profile
	profilesByUserId[player.UserId] = profile
	hydratingProfiles[profile] = true
	if dataStore then
		-- Loading and claiming are one atomic UpdateAsync transaction. GetAsync
		-- followed by a later write would leave a window where two live servers
		-- both believe they own the same progression record.
		local acquired, result, leaseExpiresAt, lastFailure, liveConflict = acquireProfileLease(profile)
		if not acquired then
			hydratingProfiles[profile] = nil
			warn("[CooperGame] Profile load failed closed for " .. player.Name .. ": " .. tostring(lastFailure))
			if profiles[player] == profile then
				profiles[player] = nil
			end
			if profilesByUserId[player.UserId] == profile then
				profilesByUserId[player.UserId] = nil
			end
			if partySession.activePlayers[player.UserId] == player then
				partySession.activePlayers[player.UserId] = nil
			end
			if player.UserId == partySession.hostUserId then
				closePartyAndReturn("The host's saved profile could not be loaded. Returning the party safely to the lobby.")
			end
			if player.Parent == Players then
				player:Kick(liveConflict
					and "Your saved game is still closing in another server. Please wait a moment, then rejoin."
					or "Your saved game data could not be loaded. Please rejoin so your progress stays safe.")
			end
			return
		end
		profile.leaseOwned = true
		profile.leaseExpiresAt = leaseExpiresAt
		if profiles[player] ~= profile or player.Parent ~= Players or shuttingDown
			or profile.closeRequested or partySession.state == "Closing"
		then
			-- PlayerRemoving can run while UpdateAsync is yielding. Do not strand a
			-- freshly claimed lease for its full crash-recovery duration.
			releaseProfileLease(profile, RELEASE_SAVE_ATTEMPTS)
			hydratingProfiles[profile] = nil
			return
		end
		local sanitizedData, didNormalize = sanitizeData(result)
		profile.data = sanitizedData
		profile.calmTaskCheckpointDurable = sanitizedData.calmTaskCheckpoint ~= nil
		profile.calmTaskCheckpointRecovered = sanitizedData.calmTaskCheckpoint ~= nil
		profile.transactionReconciliationBlocked = TransactionRuntime.hasBlockingReconciliation(profile)
		if didNormalize then
			-- Rewrite every sanitizer repair, including malformed current-schema
			-- entitlements, pending ids, and candy tokens. Version-only detection
			-- left those repairs transient until another economy mutation occurred.
			profile.dirty = true
		end
	end
	hydratingProfiles[profile] = nil
	if player.Parent ~= Players or profile.closeRequested or partySession.state == "Closing" then
		if profile.leaseOwned then
			releaseProfileLease(profile, RELEASE_SAVE_ATTEMPTS)
		end
		profiles[player] = nil
		if profilesByUserId[player.UserId] == profile then
			profilesByUserId[player.UserId] = nil
		end
		if partySession.activePlayers[player.UserId] == player then
			partySession.activePlayers[player.UserId] = nil
		end
		if player.Parent == Players then
			rejectHouseAdmission(player, "The private house session closed while your profile was loading.")
		end
		return
	end
	profile.hydrationGraceExpiresAtUnix = 0
	profile.loaded = true
	-- A server can stop after persisting the value plus SAVE_UNCONFIRMED marker
	-- but before persisting the metadata-only Committed transition. Resume that
	-- exact record on load; never invoke its debit/reward callback again.
	TransactionRuntime.resumePersistedReconciliations(profile)
	updateMemberRejoinRoute(
		player.UserId,
		unixNow() + partyConfig.SessionLifetimeSeconds
	)
	attachCharacterWatch(player, profile)
	if partyIsHost(player) then
		partySession.taskCursor = profile.data.totalTasks % #Config.TaskOrder
		partySession.completedTasks = profile.data.totalTasks
		partySession.nextTaskAt = serverNow() + Config.TaskDirector.InitialDelay
		partySession.state = "Active"
		partySession.hostGraceDeadline = 0
		partySession.hostGraceUnixExpiresAt = 0
		syncSessionManifest("InHouse", 0)
	end
	setupLeaderstats(player, profile)
	player:SetAttribute("CooperGameSchemaVersion", Config.SchemaVersion)
	local loadedWorldProfile = hostProfile()
	player:SetAttribute("MachineStage", loadedWorldProfile and loadedWorldProfile.data.machineStage or 0)
	syncBoomboxPlacedAttribute(profile)
	local loadedBunkerState = secretBunkerSnapshot(loadedWorldProfile)
	profile.secretBunkerCompletionAnnounced = partyIsHost(player) and loadedBunkerState.unlocked or false
	syncSecretBunkerAttributes(profile)
	syncChemistrySetupAttributes(profile)
	syncCandyDeliveryAttributes(profile)
	if partyIsHost(player) then
		if profile.data.calmTaskCheckpoint then
			-- Recover the named safe checkpoint before the ordinary scheduler can
			-- select or expose a different task.
			startNextTask(profile)
		end
		recoverHostWorldState(profile, player)
	end
	if profile.data.candyDeliveryActive then
		task.delay(2, function()
			if profiles[player] == profile and player.Parent == Players
				and profile.loaded and not profile.releasing
				and profile.data.candyDeliveryActive
			then
				candyDeliveryChanged:Fire(player, "Recover", candyDeliverySnapshot(profile))
			end
		end)
	elseif profile.data.candyBatchReady then
		task.delay(2, function()
			if profiles[player] == profile and player.Parent == Players
				and profile.loaded and not profile.releasing
				and profile.data.candyBatchReady
			then
				feedback(player, "CandyBatchReady", {
					title = "CHEMISTRY BATCH RESTORED",
					text = "Your finished Blue Rock Candy is safe. Return to the bunker lab and collect its metal pan.",
				})
			end
		end)
	end
	player:SetAttribute("CooperGameProfileLoaded", true)
	feedback(player, "ProfileLoaded", {
		text = partyIsHost(player)
			and "Your allowance and host-owned Cooper house progress loaded."
			or "Your allowance and personal statistics loaded. This party uses the host's Cooper house.",
	})
	broadcastState()
	if profile.dirty then
		-- Canonical migrations and current-schema repairs should not wait for the
		-- autosave interval or a graceful leave before reaching durable storage.
		task.defer(saveProfile, player, false)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

local function resetSharedActorForDeparture(userId)
	local record = partySession.task
	if not record or tonumber(record.carrierUserId) ~= userId then
		return
	end
	record.carrierUserId = nil
	if record.id == "GeorgeBeer" then
		record.step = "Order"
	elseif record.id == "MaryTrash" then
		record.step = "Pickup"
	elseif record.id == "MissyPlush" then
		record.step = "Search"
	end
	feedback(nil, "TaskProgress", {
		text = "The task item was safely reset so another party member can continue.",
	})
end

local function clearLeavingPlayerAttributes(player)
	for _, attributeName in ipairs({
		"CooperBoomboxPlaced",
		"CooperSecretBunkerId",
		"CooperSecretBunkerPurchased",
		"CooperSecretBunkerReadyAt",
		"CooperSecretBunkerUnlocked",
		"CooperSecretBunkerStatus",
		"CooperChemistrySetupPurchased",
		"CooperChemistrySetupPlaced",
		"CooperChemistrySetupStatus",
		"CooperGameProfileLoaded",
		"CooperPartyMember",
		"CooperPartySessionId",
		"CooperPartyHostUserId",
		"CooperPartyIsHost",
		"CooperPartyState",
	}) do
		player:SetAttribute(attributeName, nil)
	end
end

returnSavedPartyToLobby = function(playersToReturn)
	if #playersToReturn == 0 then
		return
	end
	if RunService:IsStudio() then
		for _, player in ipairs(playersToReturn) do
			if player.Parent == Players then
				player:SetAttribute("CooperReturnToLobbyRequested", true)
			end
		end
		return
	end
	local lobbyPlaceId = tonumber(partyConfig.LobbyPlaceId) or 0
	if lobbyPlaceId <= 0 then
		for _, player in ipairs(playersToReturn) do
			if player.Parent == Players then
				player:Kick("The party host did not reconnect. Please rejoin through the lobby.")
			end
		end
		return
	end
	local ok, failure = pcall(function()
		TeleportService:TeleportAsync(lobbyPlaceId, playersToReturn)
	end)
	if not ok then
		warn("[CooperGame] Party return teleport failed: " .. tostring(failure))
		for _, player in ipairs(playersToReturn) do
			if player.Parent == Players then
				player:Kick("Your progress was saved, but the lobby transfer failed. Please rejoin.")
			end
		end
	end
end

-- M1_HOST_RECONNECT_GRACE_CONTRACT
local function beginHostReconnectGrace(profile, leavingPlayer)
	partySession.state = "HostGrace"
	partySession.hostGraceSerial += 1
	local graceSerial = partySession.hostGraceSerial
	partySession.pausedAt = serverNow()
	partySession.hostGraceDeadline = partySession.pausedAt + partyConfig.HostReconnectGraceSeconds
	partySession.hostGraceUnixExpiresAt = unixNow() + partyConfig.HostReconnectGraceSeconds
	profile.detached = true
	profile.allowanceValue = nil
	for _, activeProfile in ipairs(presentProfiles()) do
		if activeProfile.bankHackSession then
			cancelBankHackSession(
				activeProfile,
				"The bank connection paused because the party host disconnected.",
				true
			)
		end
	end
	saveProfile(leavingPlayer, false)
	syncSessionManifest("HostGrace", partySession.hostGraceUnixExpiresAt)
	feedback(nil, "HostReconnectGrace", {
		title = "WAITING FOR HOST",
		seconds = partyConfig.HostReconnectGraceSeconds,
		deadline = partySession.hostGraceDeadline,
		text = "Shared progression is paused for 60 seconds while the host reconnects.",
	})
	broadcastState()
	task.spawn(function()
		-- Poll the authoritative deadline rather than trusting one delayed callback.
		-- This remains correct across an early scheduler wake, a long server stall, or
		-- a host rejoin that invalidates this grace serial at the exact boundary.
		while not shuttingDown and partySession.state == "HostGrace"
			and partySession.hostGraceSerial == graceSerial
		do
			local remaining = partySession.hostGraceDeadline - serverNow()
			if remaining <= 0 then
				break
			end
			task.wait(math.min(1, remaining))
		end
		if shuttingDown or partySession.state ~= "HostGrace"
			or partySession.hostGraceSerial ~= graceSerial
			or serverNow() < partySession.hostGraceDeadline
		then
			return
		end
		closePartyAndReturn("The host did not reconnect within 60 seconds. Your progress was saved.")
	end)
end

local function retainFailedProfileRelease(player, profile)
	-- A transient DataStore failure during PlayerRemoving must not orphan a dirty
	-- profile and its still-owned lease. Keep the old Player instance as a private
	-- save key and retry until the write/release succeeds or another server proves
	-- it owns the lease. profilesByUserId is cleared by the caller, so a genuine
	-- rejoin may wait on (then acquire) the lease without being mistaken for a
	-- duplicate live party member.
	task.spawn(function()
		local retryNumber = 0
		while profiles[player] == profile and profile.leaseLost ~= true do
			retryNumber += 1
			task.wait(math.min(2 + retryNumber, 10))
			if profiles[player] ~= profile then
				return
			end
			if saveProfile(player, true) then
				if profiles[player] == profile then
					profiles[player] = nil
				end
				return
			end
			if dataStore ~= nil and profile.leaseOwned ~= true then
				break
			end
		end
		if profiles[player] == profile then
			profiles[player] = nil
		end
		warn("[CooperGame] Stopped retrying a departed profile after its writable lease was lost for "
			.. tostring(player.Name))
	end)
end

-- M1_GUEST_RECONNECT_GRACE_CONTRACT
-- Unlike host loss, guest loss never pauses shared progression. The exact
-- already-loaded profile stays leased in this server for 90 seconds so any task
-- eligibility captured before departure can resolve against the same identity.
local function beginGuestReconnectGrace(profile, leavingPlayer)
	profile.detached = true
	profile.allowanceValue = nil
	profile.guestGraceSerial = (profile.guestGraceSerial or 0) + 1
	local graceSerial = profile.guestGraceSerial
	profile.guestGraceDeadline = serverNow() + partyConfig.GuestReconnectGraceSeconds
	profile.guestGraceUnixExpiresAt = unixNow() + partyConfig.GuestReconnectGraceSeconds
	-- Do not yield this PlayerRemoving path before the grace identity and serial
	-- are fully published. Both deferred operations re-check that exact serial,
	-- so a very fast rejoin cannot have its renewed route shortened afterward.
	task.defer(function()
		if profilesByUserId[leavingPlayer.UserId] == profile
			and profile.detached == true and profile.guestGraceSerial == graceSerial
		then
			saveProfile(leavingPlayer, false)
		end
	end)
	task.spawn(function()
		updateMemberRejoinRoute(
			leavingPlayer.UserId,
			profile.guestGraceUnixExpiresAt,
			profile,
			graceSerial
		)
	end)
	feedback(nil, "GuestReconnectGrace", {
		title = "PARTY MEMBER DISCONNECTED",
		seconds = partyConfig.GuestReconnectGraceSeconds,
		deadline = profile.guestGraceDeadline,
		text = leavingPlayer.DisplayName .. " has 90 seconds to reconnect. Shared tasks continue.",
	})
	broadcastState()
	task.spawn(function()
		while not shuttingDown and partySession.state ~= "Closing"
			and profile.detached == true and profile.guestGraceSerial == graceSerial
		do
			local remaining = profile.guestGraceDeadline - serverNow()
			if remaining <= 0 then
				break
			end
			task.wait(math.min(1, remaining))
		end
		if shuttingDown or partySession.state == "Closing"
			or profile.detached ~= true or profile.guestGraceSerial ~= graceSerial
			or profile.player ~= leavingPlayer
			or serverNow() < profile.guestGraceDeadline
		then
			return
		end
		local activeRecord = partySession.task
		if activeRecord then
			forfeitTaskEligibility(
				activeRecord,
				leavingPlayer.UserId,
				"GuestReconnectGraceExpired"
			)
			local resolution = activeRecord.eligibilityResolutionByUserId
				and activeRecord.eligibilityResolutionByUserId[leavingPlayer.UserId]
			-- A reservation made before expiry owns this retained profile until its
			-- value+record save is confirmed. Releasing the lease here would make the
			-- shared task wait forever for an identity that can no longer reattach.
			while resolution and resolution.status == "Committing"
				and not shuttingDown and partySession.state ~= "Closing"
				and profilesByUserId[leavingPlayer.UserId] == profile
				and profile.loaded and not profile.releasing and not profile.leaseLost
			do
				local completionProfile = hostProfile()
				if completionProfile and partyCanProgress() then
					completeTask(completionProfile, activeRecord)
				end
				task.wait(0.25)
				resolution = activeRecord.eligibilityResolutionByUserId
					and activeRecord.eligibilityResolutionByUserId[leavingPlayer.UserId]
			end
		end
		local saved = saveProfile(leavingPlayer, true)
		if profilesByUserId[leavingPlayer.UserId] == profile then
			profilesByUserId[leavingPlayer.UserId] = nil
		end
		if saved then
			if profiles[leavingPlayer] == profile then
				profiles[leavingPlayer] = nil
			end
		elseif profiles[leavingPlayer] == profile then
			warn("[CooperGame] Guest grace expired before release persistence succeeded for "
				.. leavingPlayer.Name .. "; continuing bounded background release retries")
			retainFailedProfileRelease(leavingPlayer, profile)
		end
		if not shuttingDown then
			broadcastState()
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	local wasActivePartyPlayer = partySession.activePlayers[player.UserId] == player
	local wasHost = player.UserId == partySession.hostUserId
	if wasActivePartyPlayer then
		partySession.activePlayers[player.UserId] = nil
	end
	-- A rejected duplicate/forged join shares a UserId with the real member but
	-- never owned this slot or profile. Its teardown must not disturb the party.
	if not profile and not wasActivePartyPlayer then
		clearLeavingPlayerAttributes(player)
		requestNextAt[player] = nil
		snapshotNextAt[player] = nil
		bankInputNextAt[player] = nil
		return
	end
	if profile and profile.characterAddedConnection then
		profile.characterAddedConnection:Disconnect()
		profile.characterAddedConnection = nil
	end
	if profile and profile.bankHackSession then
		cancelBankHackSession(profile, "Player left the server.", false)
	end
	if profile and profile.boomboxPlayback then
		endBoomboxPlayback(profile, profile.boomboxPlayback.sessionId, "PlayerLeaving", true)
	elseif boomboxPlaybackOwner == player then
		boomboxPlaybackOwner = nil
	end
	resetSharedActorForDeparture(player.UserId)
	clearLeavingPlayerAttributes(player)
	local hasRemainingPartyMember = next(partySession.activePlayers) ~= nil
	local healthyRetainedProfile = profile and profile.loaded and not profile.releasing
		and not profile.leaseLost and (dataStore == nil or profile.leaseOwned == true)
	if healthyRetainedProfile and wasHost and hasRemainingPartyMember and not shuttingDown then
		beginHostReconnectGrace(profile, player)
		requestNextAt[player] = nil
		snapshotNextAt[player] = nil
		bankInputNextAt[player] = nil
		return
	end
	if healthyRetainedProfile and not wasHost and not shuttingDown
		and partySession.state ~= "Closing"
		and (hasRemainingPartyMember or partySession.state == "Loading")
	then
		beginGuestReconnectGrace(profile, player)
		requestNextAt[player] = nil
		snapshotNextAt[player] = nil
		bankInputNextAt[player] = nil
		return
	end
	if wasHost and hasRemainingPartyMember and not shuttingDown then
		closePartyAndReturn("The host disconnected before their save profile was ready. Returning safely to the lobby.")
	end
	if wasHost and not hasRemainingPartyMember and not shuttingDown then
		partySession.state = "Closing"
		partySession.hostGraceDeadline = 0
		partySession.hostGraceUnixExpiresAt = 0
		syncSessionManifest("Closed", 0)
	elseif not hasRemainingPartyMember and partySession.state == "HostGrace" and not shuttingDown then
		closePartyAndReturn("Nobody remains in the house party. Closing the saved session.")
	end
	if not wasHost and profile and partySession.task then
		forfeitTaskEligibility(partySession.task, player.UserId, "ProfileCouldNotEnterGuestGrace")
	end
	local saved = saveProfile(player, true)
	if not saved and profiles[player] then
		warn("[CooperGame] Exhausted release persistence attempts for " .. player.Name
			.. "; retaining the dirty profile for background save/release retries")
	end
	if profile and profilesByUserId[player.UserId] == profile then
		profilesByUserId[player.UserId] = nil
	end
	if saved then
		profiles[player] = nil
	elseif profile and profiles[player] == profile then
		retainFailedProfileRelease(player, profile)
	end
	requestNextAt[player] = nil
	snapshotNextAt[player] = nil
	bankInputNextAt[player] = nil
	if not shuttingDown then
		broadcastState()
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

game:BindToClose(function()
	shuttingDown = true
	if partySession.validated and not partySession.studioSynthetic then
		partySession.state = "Closing"
		partySession.hostGraceDeadline = 0
		partySession.hostGraceUnixExpiresAt = 0
		syncSessionManifest("Closed", 0)
	end
	local pendingSaves = 0
	for player, profile in pairs(profiles) do
		if profile.loaded or profile.leaseOwned then
			if profile.boomboxPlayback then
				endBoomboxPlayback(profile, profile.boomboxPlayback.sessionId, "Shutdown", true)
			end
			local targetPlayer = player
			local targetProfile = profile
			pendingSaves += 1
			task.spawn(function()
				if targetProfile.loaded then
					saveProfile(targetPlayer, true)
				else
					releaseProfileLease(targetProfile, RELEASE_SAVE_ATTEMPTS)
				end
				pendingSaves -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while (pendingSaves > 0 or next(hydratingProfiles) ~= nil) and os.clock() < deadline do
		task.wait(0.1)
	end
	if pendingSaves > 0 or next(hydratingProfiles) ~= nil then
		warn("[CooperGame] Shutdown save deadline reached with "
			.. tostring(pendingSaves) .. " profile save(s) and "
			.. tostring(next(hydratingProfiles) ~= nil and "an active" or "no active")
			.. " profile hydration still pending")
	end
end)

task.spawn(function()
	local nextAutoSave = os.clock() + Config.AutoSaveSeconds
	while script.Parent and not shuttingDown do
		local currentTime = serverNow()
		local sharedHostProfile = hostProfile()
		if partyCanProgress() and sharedHostProfile then
			if not partySession.task and currentTime >= partySession.nextTaskAt then
				startNextTask(sharedHostProfile)
			end
			completeSecretBunkerIfReady(sharedHostProfile)
			if not sharedHostProfile.boomboxPlayback
				and sharedHostProfile.data.boomboxPurchased
				and sharedHostProfile.data.boomboxPlaced
				and sharedHostProfile.data.boomboxNextPlayAt > 0
				and unixNow() >= sharedHostProfile.data.boomboxNextPlayAt
			then
				announceBoomboxReady(
					sharedHostProfile,
					sharedHostProfile.data.boomboxAutoplayPurchased == true
				)
			end
		end
		for _, profile in ipairs(presentProfiles()) do
			local bankSession = profile.bankHackSession
			if bankSession and (partySession.task ~= bankSession.record or not validComputerSession(profile.player)) then
				cancelBankHackSession(
					profile,
					partySession.task ~= bankSession.record
						and "The active task changed, so the bank connection was closed."
						or "The bank connection was lost when you left the computer.",
					true
				)
			end
			local playback = profile.boomboxPlayback
			if playback
				and currentTime - playback.startedAt > Config.Boombox.TrackDuration + BOOMBOX_END_WATCHDOG_GRACE
			then
				endBoomboxPlayback(profile, playback.sessionId, "Watchdog", false)
			end
			local player = profile.player
			local session = player:GetAttribute("CooperComputerSessionUntil")
			if type(session) == "number" and (session <= currentTime or not playerNear(player, computerAnchor, 22)) then
				cancelBankHackSession(profile, "The computer terminal session expired.", true)
				player:SetAttribute("CooperComputerSessionUntil", nil)
				feedback(player, "TerminalClose", { text = "You moved away from the computer." })
			end
			local bunkerSession = player:GetAttribute("CooperBunkerComputerSessionUntil")
			local bunkerAnchor = bunkerComputerAnchor()
			if type(bunkerSession) == "number"
				and (bunkerSession <= currentTime
					or bunkerAnchor == nil
					or player:GetAttribute("CooperSecretBunkerUnlocked") ~= true
					or not playerNear(player, bunkerAnchor, 18))
			then
				player:SetAttribute("CooperBunkerComputerSessionUntil", nil)
				feedback(player, "BunkerTerminalClose", {
					text = "You moved away from the bunker research computer.",
				})
			end
		end
		if os.clock() >= nextAutoSave then
			nextAutoSave = os.clock() + Config.AutoSaveSeconds
			for player in pairs(profiles) do
				task.spawn(saveProfile, player, false)
			end
		end
		task.wait(0.35)
	end
end)

task.spawn(function()
	local heartbeatSeconds = math.clamp(
		tonumber(partyConfig.SessionHeartbeatSeconds) or 120,
		30,
		math.max(30, math.floor(partyConfig.SessionLifetimeSeconds / 2))
	)
	while script.Parent and not shuttingDown do
		task.wait(heartbeatSeconds)
		if partySession.validated and not partySession.studioSynthetic
			and (partySession.state == "Active" or partySession.state == "HostGrace")
		then
			syncSessionManifest(
				partySession.state == "HostGrace" and "HostGrace" or "InHouse",
				partySession.state == "HostGrace" and partySession.hostGraceUnixExpiresAt or 0
			)
		end
	end
end)

broadcastState()
print("[CooperGame] Personal family tasks, allowance, and paid Time Machine construction ready")
