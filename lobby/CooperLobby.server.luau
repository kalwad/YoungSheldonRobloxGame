--!strict
-- Dedicated Milestone 1 lobby authority.
-- Install as ServerScriptService.CooperLobby in the lobby place.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local lobbyFolder = ReplicatedStorage:WaitForChild("CooperLobby")
local Config = require(lobbyFolder:WaitForChild("Config"))
local Protocol = require(ReplicatedStorage:WaitForChild("CooperPartyProtocol"))

assert(Config.ProtocolVersion == Protocol.VERSION, "Lobby config and party protocol versions differ")
assert(Config.MaximumPartySize == Protocol.MAX_PARTY_SIZE, "Lobby and protocol party-size caps differ")
assert(Config.MinimumPartySize == 1, "Milestone 1 requires solo-party support")
assert(Config.ArrivalTicketTTLSeconds > 0 and Config.ArrivalTicketTTLSeconds <= 300, "Invalid arrival-ticket lifetime")
assert(Config.RejoinTicketTTLSeconds > 0 and Config.RejoinTicketTTLSeconds <= 300, "Invalid rejoin-ticket lifetime")

local isStudio = RunService:IsStudio()
local STALLED_LAUNCH_RECOVERY_SECONDS = 60
local productionConfigured = Config.LobbyPlaceId > 0
	and Config.HousePlaceId > 0
	and Config.LobbyPlaceId ~= Config.HousePlaceId
	and game.GameId == Config.UniverseId
	and game.PlaceId == Config.LobbyPlaceId

if not isStudio and not productionConfigured then
	error("CooperLobby is fail-closed: set the published LobbyPlaceId and verify universe/place IDs")
end

local remotesValue = ReplicatedStorage:FindFirstChild("CooperPartyLobby")
if remotesValue then
	assert(remotesValue:IsA("Folder"), "ReplicatedStorage.CooperPartyLobby must be a Folder")
else
	remotesValue = Instance.new("Folder")
	remotesValue.Name = "CooperPartyLobby"
	remotesValue.Parent = ReplicatedStorage
end
local remotes = remotesValue :: Folder

local requestValue = remotes:FindFirstChild("Request")
if requestValue then
	assert(requestValue:IsA("RemoteFunction"), "CooperPartyLobby.Request must be a RemoteFunction")
else
	requestValue = Instance.new("RemoteFunction")
	requestValue.Name = "Request"
	requestValue.Parent = remotes
end
local requestRemote = requestValue :: RemoteFunction

local stateValue = remotes:FindFirstChild("State")
if stateValue then
	assert(stateValue:IsA("RemoteEvent"), "CooperPartyLobby.State must be a RemoteEvent")
else
	stateValue = Instance.new("RemoteEvent")
	stateValue.Name = "State"
	stateValue.Parent = remotes
end
local stateRemote = stateValue :: RemoteEvent

local commandValue = remotes:FindFirstChild("ClientCommand")
if commandValue then
	assert(commandValue:IsA("RemoteEvent"), "CooperPartyLobby.ClientCommand must be a RemoteEvent")
else
	commandValue = Instance.new("RemoteEvent")
	commandValue.Name = "ClientCommand"
	commandValue.Parent = remotes
end
local clientCommandRemote = commandValue :: RemoteEvent

local maps = {
	Parties = MemoryStoreService:GetHashMap(Protocol.MemoryStoreNames.Parties),
	Invites = MemoryStoreService:GetHashMap(Protocol.MemoryStoreNames.Invites),
	Memberships = MemoryStoreService:GetHashMap(Protocol.MemoryStoreNames.Memberships),
	Tickets = MemoryStoreService:GetHashMap(Protocol.MemoryStoreNames.Tickets),
	Sessions = MemoryStoreService:GetHashMap(Protocol.MemoryStoreNames.Sessions),
	Rejoins = MemoryStoreService:GetHashMap(Protocol.MemoryStoreNames.Rejoins),
}

type StudioEntry = { value: any, expiresAt: number }
local studioMaps: { [string]: { [string]: StudioEntry } } = {}
for name in pairs(maps) do
	studioMaps[name] = {}
end

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local clone = {}
	for key, child in pairs(value) do
		clone[deepClone(key)] = deepClone(child)
	end
	return clone
end

local function mapGet(mapName: string, key: string): (any?, string?)
	if isStudio then
		local entry = studioMaps[mapName][key]
		if not entry then
			return nil, nil
		end
		if entry.expiresAt <= os.time() then
			studioMaps[mapName][key] = nil
			return nil, nil
		end
		return deepClone(entry.value), nil
	end

	local ok, result = pcall(function()
		return maps[mapName]:GetAsync(key)
	end)
	if not ok then
		return nil, "Lobby storage is temporarily unavailable. Please try again."
	end
	return result, nil
end

local function mapSet(mapName: string, key: string, value: any, ttl: number): (boolean, string?)
	if isStudio then
		studioMaps[mapName][key] = { value = deepClone(value), expiresAt = os.time() + ttl }
		return true, nil
	end
	local ok, result = pcall(function()
		return maps[mapName]:SetAsync(key, value, ttl)
	end)
	if not ok or result ~= true then
		return false, "Lobby storage is temporarily unavailable. Please try again."
	end
	return true, nil
end

local function mapRemove(mapName: string, key: string)
	if isStudio then
		studioMaps[mapName][key] = nil
		return
	end
	pcall(function()
		maps[mapName]:RemoveAsync(key)
	end)
end

local function mapUpdate(
	mapName: string,
	key: string,
	ttl: number,
	transform: (any?) -> any?
): (any?, string?)
	if isStudio then
		local current, getError = mapGet(mapName, key)
		if getError then
			return nil, getError
		end
		local updated = transform(current)
		if updated == nil then
			return current, nil
		end
		studioMaps[mapName][key] = { value = deepClone(updated), expiresAt = os.time() + ttl }
		return deepClone(updated), nil
	end

	local ok, result = pcall(function()
		return maps[mapName]:UpdateAsync(key, transform, ttl)
	end)
	if not ok then
		return nil, "Lobby storage is temporarily unavailable. Please try again."
	end
	return result, nil
end

local function memberKey(userId: number): string
	return "member_" .. tostring(userId)
end

local function rejoinKey(userId: number): string
	return "rejoin:" .. tostring(userId)
end

local function localLobbyJobId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

-- A player leaving the lobby while one of our teleport attempts is active must
-- not be mistaken for an ordinary disconnect that dissolves their party.
-- Opaque attempt tokens prevent an older timeout from clearing a newer retry.
local teleporting: { [number]: string } = {}
local teleportFailureMessages: { [number]: string } = {}

local function hasMember(memberUserIds: { number }, userId: number): boolean
	return Protocol.containsMember(memberUserIds, userId)
end

local function removeMember(memberUserIds: { number }, userId: number): { number }
	local result = {}
	for _, candidate in ipairs(memberUserIds) do
		if candidate ~= userId then
			table.insert(result, candidate)
		end
	end
	return result
end

local function validUserId(value: any): boolean
	return type(value) == "number"
		and value == math.floor(value)
		and value > 0
		and value < math.huge
end

local function normalizedMembers(raw: any): ({ number }?, { [number]: boolean }?)
	if type(raw) ~= "table" then
		return nil, nil
	end
	local members = {}
	local set: { [number]: boolean } = {}
	local count = 0
	for key, value in pairs(raw) do
		if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or not validUserId(value) then
			return nil, nil
		end
		local userId = value :: number
		count += 1
		if count > Config.MaximumPartySize or set[userId] then
			return nil, nil
		end
		set[userId] = true
	end
	if count < Config.MinimumPartySize then
		return nil, nil
	end
	for index = 1, count do
		local userId = raw[index]
		if not validUserId(userId) then
			return nil, nil
		end
		table.insert(members, userId)
	end
	return members, set
end

local function sameMembers(left: any, right: any): boolean
	local leftMembers, leftSet = normalizedMembers(left)
	local rightMembers, rightSet = normalizedMembers(right)
	if not leftMembers or not leftSet or not rightMembers or not rightSet or #leftMembers ~= #rightMembers then
		return false
	end
	for userId in pairs(leftSet) do
		if not rightSet[userId] then
			return false
		end
	end
	return true
end

local function validPartyRecord(party: any, expectedPartyId: string?): boolean
	if type(party) ~= "table"
		or party.version ~= Protocol.VERSION
		or not Protocol.isOpaqueId(party.partyId)
		or (expectedPartyId ~= nil and party.partyId ~= expectedPartyId)
		or not validUserId(party.hostUserId)
		or type(party.readyByUserId) ~= "table"
		or type(party.lobbyJobId) ~= "string"
		or party.lobbyJobId == ""
	then
		return false
	end
	local _, memberSet = normalizedMembers(party.memberUserIds)
	return memberSet ~= nil and memberSet[party.hostUserId] == true
end

local function removeMembershipForParty(userId: number, partyId: string, claimId: string?)
	local key = memberKey(userId)
	local function releasedRecord(): any
		return {
			version = Protocol.VERSION,
			partyId = false,
			status = "Released",
			releasedAt = os.time(),
		}
	end
	if isStudio then
		local entry = studioMaps.Memberships[key]
		local current = entry and entry.value or nil
		if type(current) == "table"
			and current.partyId == partyId
			and (claimId == nil or current.claimId == claimId)
		then
			studioMaps.Memberships[key] = {
				value = releasedRecord(),
				expiresAt = os.time() + Config.PartyTTLSeconds,
			}
		end
		return
	end
	pcall(function()
		maps.Memberships:UpdateAsync(key, function(current)
			if type(current) == "table"
				and current.partyId == partyId
				and (claimId == nil or current.claimId == claimId)
			then
				return releasedRecord()
			end
			return current
		end, Config.PartyTTLSeconds)
	end)
end

local function claimMembership(userId: number, partyId: string, role: string): (string?, string?)
	local claimId = Protocol.newOpaqueId("membership")
	local now = os.time()
	local result, updateError = mapUpdate("Memberships", memberKey(userId), Config.PartyTTLSeconds, function(current)
		if type(current) == "table" and Protocol.isOpaqueId(current.partyId) then
			return current
		end
		return {
			version = Protocol.VERSION,
			partyId = partyId,
			role = role,
			claimId = claimId,
			status = "Pending",
			updatedAt = now,
		}
	end)
	if updateError then
		return nil, updateError
	end
	if type(result) ~= "table" or result.partyId ~= partyId or result.claimId ~= claimId then
		return nil, "You are already joining or playing with another party."
	end
	return claimId, nil
end

local function finalizeMembership(userId: number, partyId: string, claimId: string): (boolean, string?)
	local result, updateError = mapUpdate("Memberships", memberKey(userId), Config.PartyTTLSeconds, function(current)
		if type(current) == "table" and current.partyId == partyId and current.claimId == claimId then
			current.status = "Active"
			current.updatedAt = os.time()
		end
		return current
	end)
	if updateError then
		return false, updateError
	end
	return type(result) == "table"
		and result.partyId == partyId
		and result.claimId == claimId
		and result.status == "Active", nil
end

local function currentPartyForUser(userId: number): (any?, string?)
	local membership, membershipError = mapGet("Memberships", memberKey(userId))
	if membershipError then
		return nil, membershipError
	end
	if type(membership) ~= "table" or not Protocol.isOpaqueId(membership.partyId) then
		return nil, nil
	end
	if membership.version ~= Protocol.VERSION then
		removeMembershipForParty(userId, membership.partyId, membership.claimId)
		return nil, nil
	end
	if membership.status == "Pending" then
		local updatedAt = tonumber(membership.updatedAt) or 0
		if updatedAt > os.time() - 30 then
			return nil, "Your party request is still finishing. Please try again in a moment."
		end
		removeMembershipForParty(userId, membership.partyId, membership.claimId)
		return nil, nil
	end
	local party, partyError = mapGet("Parties", membership.partyId)
	if partyError then
		return nil, partyError
	end
	if not validPartyRecord(party, membership.partyId)
		or (party.state ~= Protocol.PartyStates.Open
			and party.state ~= Protocol.PartyStates.Launching
			and party.state ~= Protocol.PartyStates.InHouse)
	then
		removeMembershipForParty(userId, membership.partyId, membership.claimId)
		return nil, nil
	end
	if not hasMember(party.memberUserIds, userId) then
		removeMembershipForParty(userId, membership.partyId, membership.claimId)
		return nil, nil
	end
	-- A process can die after atomically marking a party Launching but before it
	-- creates the server-only reconnect route. Without recovery that party would
	-- be unusable until its 15-minute TTL elapsed. A real launch always writes the
	-- host route before attempting any teleport, so the absence of that route and
	-- of a live house job after a full minute is an unambiguous abandoned launch.
	if party.state == Protocol.PartyStates.Launching
		and (tonumber(party.updatedAt) or 0) <= os.time() - STALLED_LAUNCH_RECOVERY_SECONDS
	then
		local launchSessionId = party.launchSessionId
		local launchSession: any? = nil
		if Protocol.isOpaqueId(launchSessionId) then
			local sessionError: string? = nil
			launchSession, sessionError = mapGet("Sessions", "session:" .. launchSessionId)
			if sessionError then
				return nil, sessionError
			end
		end
		local hostRoute: any? = nil
		if type(launchSession) == "table"
			and launchSession.state == Protocol.SessionStates.Launching
			and (type(launchSession.houseJobId) ~= "string" or launchSession.houseJobId == "")
		then
			local routeError: string? = nil
			hostRoute, routeError = mapGet("Rejoins", rejoinKey(party.hostUserId))
			if routeError then
				return nil, routeError
			end
		end
		local sessionIsMissing = type(launchSession) ~= "table"
		local launchNeverBecameReachable = type(launchSession) == "table"
			and launchSession.state == Protocol.SessionStates.Launching
			and (type(launchSession.houseJobId) ~= "string" or launchSession.houseJobId == "")
			and (type(hostRoute) ~= "table"
				or hostRoute.v ~= Protocol.VERSION
				or hostRoute.sessionId ~= launchSessionId
				or hostRoute.partyId ~= party.partyId
				or hostRoute.hostUserId ~= party.hostUserId
				or hostRoute.housePlaceId ~= Config.HousePlaceId
				or hostRoute.lobbyPlaceId ~= Config.LobbyPlaceId
				or type(hostRoute.expiresAt) ~= "number"
				or hostRoute.expiresAt <= os.time()
				or type(hostRoute.accessCode) ~= "string"
				or hostRoute.accessCode == "")
		if sessionIsMissing or launchNeverBecameReachable then
			local staleSessionId = launchSessionId
			local recovered, recoverError = mapUpdate(
				"Parties",
				party.partyId,
				Config.PartyTTLSeconds,
				function(current)
					if validPartyRecord(current, party.partyId)
						and current.state == Protocol.PartyStates.Launching
						and current.launchSessionId == staleSessionId
						and (tonumber(current.updatedAt) or 0)
							<= os.time() - STALLED_LAUNCH_RECOVERY_SECONDS
					then
						current.state = Protocol.PartyStates.Open
						current.launchSessionId = nil
						current.updatedAt = os.time()
					end
					return current
				end
			)
			if recoverError then
				return nil, recoverError
			end
			if type(recovered) == "table" and recovered.state == Protocol.PartyStates.Open then
				party = recovered
				if Protocol.isOpaqueId(staleSessionId) then
					mapRemove("Sessions", "session:" .. staleSessionId)
				end
			end
		end
	end
	if party.state == Protocol.PartyStates.InHouse and Protocol.isOpaqueId(party.launchSessionId) then
		local session, sessionError = mapGet("Sessions", "session:" .. party.launchSessionId)
		if sessionError then
			return nil, sessionError
		end
		local sessionEnded = type(session) ~= "table"
			or (session.state ~= Protocol.SessionStates.Launching
				and session.state ~= Protocol.SessionStates.InHouse
				and session.state ~= Protocol.SessionStates.HostGrace)
			or type(session.expiresAt) ~= "number"
			or session.expiresAt <= os.time()
		if sessionEnded then
			mapRemove("Parties", party.partyId)
			for _, memberUserId in ipairs(party.memberUserIds) do
				removeMembershipForParty(memberUserId, party.partyId, nil)
			end
			return nil, nil
		end
	end
	return party, nil
end

local nameCache: { [number]: { name: string, displayName: string } } = {}
local function playerNames(userId: number): (string, string)
	local live = Players:GetPlayerByUserId(userId)
	if live then
		return live.Name, live.DisplayName
	end
	local cached = nameCache[userId]
	if cached then
		return cached.name, cached.displayName
	end
	local name = "Player " .. tostring(userId)
	local ok, resolved = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(resolved) == "string" then
		name = resolved
	end
	nameCache[userId] = { name = name, displayName = name }
	return name, name
end

local function rejoinSessionForUser(userId: number): (any?, any?, string?)
	if isStudio then
		return nil, nil, nil
	end
	local rejoin, rejoinError = mapGet("Rejoins", rejoinKey(userId))
	if rejoinError then
		return nil, nil, rejoinError
	end
	if type(rejoin) ~= "table" or not Protocol.isOpaqueId(rejoin.sessionId) then
		return nil, nil, nil
	end
	local session, sessionError = mapGet("Sessions", "session:" .. rejoin.sessionId)
	if sessionError then
		return nil, nil, sessionError
	end
	local now = os.time()
	local sessionStateAllowed = type(session) == "table"
		and (session.state == Protocol.SessionStates.Launching
			or session.state == Protocol.SessionStates.InHouse
			or session.state == Protocol.SessionStates.HostGrace)
	local sessionMemberSet: { [number]: boolean }? = nil
	if type(session) == "table" then
		local _
		_, sessionMemberSet = normalizedMembers(session.members)
	end
	local valid = type(session) == "table"
		and sessionStateAllowed
		and session.v == Protocol.VERSION
		and session.sessionId == rejoin.sessionId
		and session.housePlaceId == Config.HousePlaceId
		and session.lobbyPlaceId == Config.LobbyPlaceId
		and Protocol.isOpaqueId(session.sessionId)
		and Protocol.isOpaqueId(session.partyId)
		and validUserId(session.hostUserId)
		and type(session.expiresAt) == "number"
		and session.expiresAt > now
		and type(session.reservedServerPrivateId) == "string"
		and session.reservedServerPrivateId ~= ""
		and sessionMemberSet ~= nil
		and sessionMemberSet[userId] == true
		and sessionMemberSet[session.hostUserId] == true
		and rejoin.v == Protocol.VERSION
		and rejoin.housePlaceId == session.housePlaceId
		and rejoin.lobbyPlaceId == session.lobbyPlaceId
		and rejoin.partyId == session.partyId
		and rejoin.hostUserId == session.hostUserId
		and sameMembers(rejoin.members, session.members)
		and type(rejoin.accessCode) == "string"
		and rejoin.accessCode ~= ""
		and #rejoin.accessCode <= 1024
		and type(rejoin.expiresAt) == "number"
		and rejoin.expiresAt > now
		and (session.state ~= Protocol.SessionStates.HostGrace
			or (type(session.hostGraceExpiresAt) == "number"
				and session.hostGraceExpiresAt > now))
	if not valid then
		mapRemove("Rejoins", rejoinKey(userId))
		return nil, nil, nil
	end
	return rejoin, session, nil

end


local function canRejoinState(userId: number): (boolean, string?)
	local rejoin, _, rejoinError = rejoinSessionForUser(userId)
	if rejoinError then
		return false, rejoinError
	end
	return rejoin ~= nil, if rejoin ~= nil then "Your private house session is still active." else nil
end

local function publicState(player: Player, notice: string?): any
	local party, partyError = currentPartyForUser(player.UserId)
	local canRejoin = false
	local rejoinMessage: string? = nil
	if not party or party.state ~= Protocol.PartyStates.Open then
		canRejoin, rejoinMessage = canRejoinState(player.UserId)
	end
	if not party then
		return {
			version = Protocol.VERSION,
			hasParty = false,
			canRejoin = canRejoin,
			studioPreview = isStudio,
			notice = notice or partyError or rejoinMessage,
		}
	end

	local members = {}
	local allReady = #party.memberUserIds >= 1
	local allPresent = true
	local ownsPartyLobby = party.lobbyJobId == localLobbyJobId()
	for _, userId in ipairs(party.memberUserIds) do
		local name, displayName = playerNames(userId)
		local ready = party.readyByUserId[tostring(userId)] == true
		local present = Players:GetPlayerByUserId(userId) ~= nil
		allReady = allReady and ready
		allPresent = allPresent and present
		table.insert(members, {
			userId = userId,
			name = name,
			displayName = displayName,
			ready = ready,
			present = present,
			isHost = userId == party.hostUserId,
		})
	end

	return {
		version = Protocol.VERSION,
		hasParty = true,
		partyId = party.partyId,
		hostUserId = party.hostUserId,
		isHost = party.hostUserId == player.UserId,
		state = party.state,
		members = members,
		allReady = allReady,
		allPresent = allPresent,
		canLaunch = party.hostUserId == player.UserId
			and party.state == Protocol.PartyStates.Open
			and ownsPartyLobby
			and allReady
			and allPresent,
		canInvite = party.hostUserId == player.UserId
			and party.state == Protocol.PartyStates.Open
			and ownsPartyLobby
			and #party.memberUserIds < Config.MaximumPartySize,
		canRejoin = canRejoin,
		studioPreview = isStudio,
		notice = notice or partyError or rejoinMessage,
	}
end

local function pushState(player: Player, notice: string?)
	if player.Parent == Players then
		stateRemote:FireClient(player, publicState(player, notice))
	end
end

local function pushParty(party: any, notice: string?)
	if type(party) ~= "table" or type(party.memberUserIds) ~= "table" then
		return
	end
	for _, userId in ipairs(party.memberUserIds) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			pushState(player, notice)
		end
	end
end

local function beginTeleportAttempt(player: Player, failureMessage: string?): string
	local token = Protocol.newOpaqueId("teleport")
	teleporting[player.UserId] = token
	teleportFailureMessages[player.UserId] = failureMessage
		or "Roblox could not move you yet. You can use Rejoin House Session."
	task.delay(30, function()
		if teleporting[player.UserId] == token and player.Parent == Players then
			teleporting[player.UserId] = nil
			local message = teleportFailureMessages[player.UserId]
			teleportFailureMessages[player.UserId] = nil
			pushState(player, message or "Roblox did not move you. Please try again.")
		end
	end)
	return token
end

local function routePartyMemberToHostLobby(player: Player, party: any): (boolean, string?)
	if isStudio or party.lobbyJobId == localLobbyJobId() then
		return true, nil
	end
	if teleporting[player.UserId] then
		return true, "Already moving you into the host's lobby..."
	end
	if not validPartyRecord(party, party.partyId) then
		return false, "The host's lobby is no longer available."
	end
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = party.lobbyJobId
	options:SetTeleportData({
		v = Protocol.VERSION,
		kind = "CooperLobbyPartyRoute",
		partyId = party.partyId,
	})
	local token = beginTeleportAttempt(
		player,
		"Roblox could not move you into the host's lobby. Leave the party and ask for a new invite."
	)
	local ok = pcall(function()
		TeleportService:TeleportAsync(Config.LobbyPlaceId, { player }, options)
	end)
	if not ok then
		if teleporting[player.UserId] == token then
			teleporting[player.UserId] = nil
			teleportFailureMessages[player.UserId] = nil
		end
		return false, "Roblox could not move you into the host's lobby. Leave the party and ask for a new invite."
	end
	return true, "Joined the party. Moving you into the host's lobby..."
end

local function createParty(player: Player, ready: boolean): (any?, string?)
	local current, currentError = currentPartyForUser(player.UserId)
	if currentError then
		return nil, currentError
	end
	if current then
		if current.state == Protocol.PartyStates.Open then
			return current, nil
		end
		return nil, "Your party already started. Use Rejoin House Session."
	end
	local canRejoin, rejoinError = canRejoinState(player.UserId)
	if rejoinError then
		return nil, rejoinError
	end
	if canRejoin then
		return nil, "Rejoin your active house session before starting another party."
	end

	local now = os.time()
	local partyId = Protocol.newOpaqueId("party")
	local claimId, claimError = claimMembership(player.UserId, partyId, "Host")
	if not claimId then
		return nil, claimError
	end
	local party = {
		version = Protocol.VERSION,
		partyId = partyId,
		hostUserId = player.UserId,
		memberUserIds = { player.UserId },
		readyByUserId = { [tostring(player.UserId)] = ready },
		lobbyJobId = localLobbyJobId(),
		state = Protocol.PartyStates.Open,
		createdAt = now,
		updatedAt = now,
	}

	local stored, storeError = mapSet("Parties", partyId, party, Config.PartyTTLSeconds)
	if not stored then
		removeMembershipForParty(player.UserId, partyId, claimId)
		return nil, storeError
	end
	local linked, linkError = finalizeMembership(player.UserId, partyId, claimId)
	if not linked then
		mapRemove("Parties", partyId)
		removeMembershipForParty(player.UserId, partyId, claimId)
		return nil, linkError
	end
	return party, nil
end

local function leaveParty(player: Player, suppressNotice: boolean?): (boolean, string?)
	local party, partyError = currentPartyForUser(player.UserId)
	if partyError then
		return false, partyError
	end
	if not party then
		return true, nil
	end
	if party.state ~= Protocol.PartyStates.Open then
		return false, "This party has already started. Use Rejoin House Session if you were left behind."
	end

	if party.hostUserId == player.UserId then
		local closedParty, closeError = mapUpdate("Parties", party.partyId, Config.PartyTTLSeconds, function(current)
			if validPartyRecord(current, party.partyId)
				and current.hostUserId == player.UserId
				and current.state == Protocol.PartyStates.Open
			then
				current.state = Protocol.PartyStates.Closed
				current.updatedAt = os.time()
			end
			return current
		end)
		if closeError then
			return false, closeError
		end
		if type(closedParty) ~= "table" or closedParty.state ~= Protocol.PartyStates.Closed then
			return false, "This party has already started."
		end
		local closeNotice = if suppressNotice then nil else "The host closed the party."
		pushParty(closedParty, closeNotice)
		mapRemove("Parties", party.partyId)
		for _, userId in ipairs(closedParty.memberUserIds) do
			removeMembershipForParty(userId, party.partyId, nil)
		end
		return true, nil
	end

	local updated, updateError = mapUpdate("Parties", party.partyId, Config.PartyTTLSeconds, function(current)
		if type(current) ~= "table" or current.state ~= Protocol.PartyStates.Open then
			return current
		end
		current.memberUserIds = removeMember(current.memberUserIds, player.UserId)
		current.readyByUserId[tostring(player.UserId)] = nil
		current.updatedAt = os.time()
		return current
	end)
	if updateError then
		return false, updateError
	end
	if type(updated) ~= "table" or hasMember(updated.memberUserIds, player.UserId) then
		return false, "This party has already started."
	end
	removeMembershipForParty(player.UserId, party.partyId, nil)
	local leftNotice = if suppressNotice then nil else player.DisplayName .. " left the party."
	pushParty(updated, leftNotice)
	return true, nil
end

local function joinFromInvite(player: Player, ticketId: string, referredByUserId: unknown): (boolean, string?)
	local invite, inviteError = mapGet("Invites", ticketId)
	if inviteError then
		return false, inviteError
	end
	if type(invite) ~= "table"
		or invite.version ~= Protocol.VERSION
		or invite.ticketId ~= ticketId
		or type(invite.expiresAt) ~= "number"
		or invite.expiresAt <= os.time()
		or not Protocol.isOpaqueId(invite.partyId)
		or not validUserId(invite.hostUserId)
	then
		return false, "That party invitation expired. Ask your friend to invite you again."
	end
	if invite.hostUserId == player.UserId then
		return false, "You are already the host of that party."
	end

	local current, currentError = currentPartyForUser(player.UserId)
	if currentError then
		return false, currentError
	end
	if current then
		if current.partyId == invite.partyId then
			if current.state == Protocol.PartyStates.Open then
				return routePartyMemberToHostLobby(player, current)
			end
			return false, "That party already started. Use Rejoin House Session."
		end
		return false, "Leave your current party before joining another one."
	end
	local canRejoin, rejoinError = canRejoinState(player.UserId)
	if rejoinError then
		return false, rejoinError
	end
	if canRejoin then
		return false, "Rejoin your active house session before joining another party."
	end
	if tonumber(referredByUserId) ~= invite.hostUserId then
		return false, "That invitation was not issued by this party's host."
	end

	local friendOk, isFriend = pcall(function()
		return player:IsFriendsWithAsync(invite.hostUserId)
	end)
	if not friendOk or not isFriend then
		return false, "This private invitation is only valid for the host's friends."
	end
	local invitedParty, invitedPartyError = mapGet("Parties", invite.partyId)
	if invitedPartyError then
		return false, invitedPartyError
	end
	if not validPartyRecord(invitedParty, invite.partyId)
		or invitedParty.hostUserId ~= invite.hostUserId
		or invitedParty.state ~= Protocol.PartyStates.Open
		or #invitedParty.memberUserIds >= Config.MaximumPartySize
	then
		return false, "That party is already full or has started playing."
	end

	local claimId, claimError = claimMembership(player.UserId, invite.partyId, "Guest")
	if not claimId then
		return false, claimError
	end

	local updated, updateError = mapUpdate("Parties", invite.partyId, Config.PartyTTLSeconds, function(party)
		if not validPartyRecord(party, invite.partyId)
			or party.hostUserId ~= invite.hostUserId
			or party.state ~= Protocol.PartyStates.Open
		then
			return party
		end
		if hasMember(party.memberUserIds, player.UserId) then
			return party
		end
		if #party.memberUserIds >= Config.MaximumPartySize then
			return party
		end
		table.insert(party.memberUserIds, player.UserId)
		party.readyByUserId[tostring(player.UserId)] = false
		party.updatedAt = os.time()
		return party
	end)
	if updateError then
		removeMembershipForParty(player.UserId, invite.partyId, claimId)
		return false, updateError
	end
	if type(updated) ~= "table" or not hasMember(updated.memberUserIds, player.UserId) then
		removeMembershipForParty(player.UserId, invite.partyId, claimId)
		return false, "That party is already full or has started playing."
	end

	local linked, linkError = finalizeMembership(player.UserId, invite.partyId, claimId)
	if not linked then
		mapUpdate("Parties", invite.partyId, Config.PartyTTLSeconds, function(party)
			if type(party) == "table" and party.state == Protocol.PartyStates.Open then
				party.memberUserIds = removeMember(party.memberUserIds, player.UserId)
				party.readyByUserId[tostring(player.UserId)] = nil
			end
			return party
		end)
		removeMembershipForParty(player.UserId, invite.partyId, claimId)
		return false, linkError
	end

	mapUpdate("Invites", ticketId, Config.InviteTTLSeconds, function(record)
		if type(record) == "table" then
			record.acceptedUserIds = record.acceptedUserIds or {}
			record.acceptedUserIds[tostring(player.UserId)] = os.time()
		end
		return record
	end)
	pushParty(updated, player.DisplayName .. " joined the party.")
	return routePartyMemberToHostLobby(player, updated)
end

local function setReady(player: Player, ready: boolean): (boolean, string?)
	local party, partyError = currentPartyForUser(player.UserId)
	if partyError then
		return false, partyError
	end
	if not party then
		return false, "Create or join a party first."
	end
	if party.state ~= Protocol.PartyStates.Open then
		return false, "This party is already launching."
	end

	local updated, updateError = mapUpdate("Parties", party.partyId, Config.PartyTTLSeconds, function(current)
		if type(current) == "table"
			and current.state == Protocol.PartyStates.Open
			and hasMember(current.memberUserIds, player.UserId)
		then
			current.readyByUserId[tostring(player.UserId)] = ready
			current.updatedAt = os.time()
		end
		return current
	end)
	if updateError then
		return false, updateError
	end
	if type(updated) ~= "table"
		or not hasMember(updated.memberUserIds, player.UserId)
		or updated.readyByUserId[tostring(player.UserId)] ~= ready
	then
		return false, "Your party changed before that ready choice could be saved."
	end
	pushParty(updated, nil)
	return true, nil
end

local function issueInvite(player: Player): (boolean, string?)
	local party, partyError = currentPartyForUser(player.UserId)
	if partyError then
		return false, partyError
	end
	if not party or party.hostUserId ~= player.UserId then
		return false, "Only the party host can invite friends."
	end
	if party.lobbyJobId ~= localLobbyJobId() then
		return false, "Wait until Roblox finishes moving you back into your party's lobby."
	end
	if party.state ~= Protocol.PartyStates.Open or #party.memberUserIds >= Config.MaximumPartySize then
		return false, "This party cannot accept more players."
	end

	local now = os.time()
	local ticketId = Protocol.newOpaqueId("invite")
	local stored, storeError = mapSet("Invites", ticketId, {
		version = Protocol.VERSION,
		ticketId = ticketId,
		partyId = party.partyId,
		hostUserId = player.UserId,
		acceptedUserIds = {},
		issuedAt = now,
		expiresAt = now + Config.InviteTTLSeconds,
	}, Config.InviteTTLSeconds)
	if not stored then
		return false, storeError
	end

	clientCommandRemote:FireClient(player, "PromptInvite", Protocol.makeInviteLaunchData(ticketId))
	return true, nil
end

local function rollbackLaunch(
	partyId: string,
	sessionId: string?,
	memberUserIds: { number },
	ticketIdsByUserId: { [string]: string }?
)
	if sessionId then
		mapRemove("Sessions", "session:" .. sessionId)
	end
	for _, ticketId in pairs(ticketIdsByUserId or {}) do
		mapRemove("Tickets", "ticket:" .. ticketId)
	end
	for _, userId in ipairs(memberUserIds) do
		teleporting[userId] = nil
		teleportFailureMessages[userId] = nil
		mapRemove("Rejoins", rejoinKey(userId))
	end
	mapUpdate("Parties", partyId, Config.PartyTTLSeconds, function(party)
		if type(party) == "table" and party.state == Protocol.PartyStates.Launching then
			party.state = Protocol.PartyStates.Open
			party.launchSessionId = nil
			party.updatedAt = os.time()
		end
		return party
	end)
end

local function launchParty(player: Player): (boolean, string?)
	local party, partyError = currentPartyForUser(player.UserId)
	if partyError then
		return false, partyError
	end
	if not party or party.hostUserId ~= player.UserId then
		return false, "Only the party host can start the house session."
	end
	if party.state ~= Protocol.PartyStates.Open then
		return false, "This party is already launching."
	end
	if party.lobbyJobId ~= localLobbyJobId() then
		return false, "Wait until every member is together in the host's lobby."
	end
	if #party.memberUserIds < Config.MinimumPartySize or #party.memberUserIds > Config.MaximumPartySize then
		return false, "Party size must be between one and four players."
	end

	local livePlayersByUserId: { [number]: Player } = {}
	for _, userId in ipairs(party.memberUserIds) do
		if party.readyByUserId[tostring(userId)] ~= true then
			return false, "Everyone must be ready before the host can start."
		end
		local member = Players:GetPlayerByUserId(userId)
		if not member then
			return false, "Wait for every party member to arrive in this lobby."
		end
		livePlayersByUserId[userId] = member
	end

	if isStudio then
		pushParty(party, "Studio party validation passed. Teleports and house authority stay disabled in Studio preview.")
		return true, "Studio preview passed; launch was safely skipped."
	end

	local sessionId = Protocol.newOpaqueId("session")
	local now = os.time()
	local marked, markError = mapUpdate("Parties", party.partyId, Config.PartyTTLSeconds, function(current)
		local snapshotMatches = validPartyRecord(current, party.partyId)
			and current.hostUserId == player.UserId
			and current.lobbyJobId == party.lobbyJobId
			and current.state == Protocol.PartyStates.Open
			and sameMembers(current.memberUserIds, party.memberUserIds)
		if snapshotMatches then
			for _, userId in ipairs(current.memberUserIds) do
				if current.readyByUserId[tostring(userId)] ~= true
					or Players:GetPlayerByUserId(userId) == nil
				then
					snapshotMatches = false
					break
				end
			end
		end
		if snapshotMatches then
			current.state = Protocol.PartyStates.Launching
			current.launchSessionId = sessionId
			current.updatedAt = now
		end
		return current
	end)
	if markError then
		return false, markError
	end
	if type(marked) ~= "table" or marked.launchSessionId ~= sessionId then
		return false, "Another launch request already started."
	end
	-- From this point onward use only the atomically marked manifest. The
	-- preflight snapshot is deliberately discarded so a concurrent invite,
	-- leave, or unready operation can never be omitted from the house ticket.
	party = marked
	livePlayersByUserId = {}
	for _, userId in ipairs(party.memberUserIds) do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			livePlayersByUserId[userId] = member
		end
	end

	local reserveOk, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServerAsync(Config.HousePlaceId)
	end)
	if not reserveOk
		or type(accessCode) ~= "string"
		or accessCode == ""
		or type(privateServerId) ~= "string"
		or privateServerId == ""
	then
		rollbackLaunch(party.partyId, nil, party.memberUserIds, nil)
		return false, "Roblox could not reserve the house server. Please try again."
	end

	local manifest = {
		v = Protocol.VERSION,
		sessionId = sessionId,
		partyId = party.partyId,
		lobbyPlaceId = Config.LobbyPlaceId,
		housePlaceId = Config.HousePlaceId,
		hostUserId = party.hostUserId,
		members = table.clone(party.memberUserIds),
		reservedServerPrivateId = privateServerId,
		state = Protocol.SessionStates.Launching,
		issuedAt = now,
		expiresAt = now + Config.SessionTTLSeconds,
		hostGraceExpiresAt = 0,
	}
	local sessionStored = mapSet("Sessions", "session:" .. sessionId, manifest, Config.SessionTTLSeconds)
	if not sessionStored then
		rollbackLaunch(party.partyId, sessionId, party.memberUserIds, nil)
		return false, "The private session could not be secured. Please try again."
	end

	local ticketIdsByUserId: { [string]: string } = {}
	for _, userId in ipairs(party.memberUserIds) do
		local ticketId = Protocol.newOpaqueId("arrival")
		ticketIdsByUserId[tostring(userId)] = ticketId
		local ticketStored = mapSet("Tickets", "ticket:" .. ticketId, {
			v = Protocol.VERSION,
			sessionId = sessionId,
			userId = userId,
			hostUserId = party.hostUserId,
			members = table.clone(party.memberUserIds),
			issuedAt = now,
			expiresAt = now + Config.ArrivalTicketTTLSeconds,
		}, Config.ArrivalTicketTTLSeconds)
		local rejoinStored = mapSet("Rejoins", rejoinKey(userId), {
			v = Protocol.VERSION,
			sessionId = sessionId,
			partyId = party.partyId,
			lobbyPlaceId = Config.LobbyPlaceId,
			housePlaceId = Config.HousePlaceId,
			hostUserId = party.hostUserId,
			members = table.clone(party.memberUserIds),
			accessCode = accessCode,
			expiresAt = now + Config.SessionTTLSeconds,
		}, Config.SessionTTLSeconds)
		if not ticketStored or not rejoinStored then
			rollbackLaunch(party.partyId, sessionId, party.memberUserIds, ticketIdsByUserId)
			return false, "The secure launch route could not be created. Please try again."
		end
	end

	-- TeleportData belongs to the whole TeleportAsync call. Use one call per
	-- member so every arrival receives a distinct, user-bound, one-use ticket;
	-- every call still targets the same reserved-server access code.
	local launchedCount = 0
	local failedCount = 0
	for _, userId in ipairs(party.memberUserIds) do
		local member = livePlayersByUserId[userId]
		if not member or member.Parent ~= Players then
			failedCount += 1
			continue
		end
		local ticketId = ticketIdsByUserId[tostring(userId)]
		local teleportData = Protocol.makeHouseTeleportData(
			sessionId,
			party.partyId,
			ticketId,
			party.hostUserId,
			party.memberUserIds,
			now,
			now + Config.ArrivalTicketTTLSeconds
		)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		options:SetTeleportData(teleportData)
		local teleportToken = beginTeleportAttempt(member)
		local teleportOk = pcall(function()
			TeleportService:TeleportAsync(Config.HousePlaceId, { member }, options)
		end)
		if teleportOk then
			launchedCount += 1
		else
			failedCount += 1
			if teleporting[userId] == teleportToken then
				teleporting[userId] = nil
				teleportFailureMessages[userId] = nil
			end
			pushState(member, "Roblox could not move you yet. Use Rejoin House Session to catch up with your party.")
		end
	end
	if launchedCount == 0 then
		rollbackLaunch(party.partyId, sessionId, party.memberUserIds, ticketIdsByUserId)
		return false, "The house launch failed. Your party is still together; please try again."
	end

	mapUpdate("Parties", party.partyId, Config.PartyTTLSeconds, function(current)
		if type(current) == "table" and current.launchSessionId == sessionId then
			current.state = Protocol.PartyStates.InHouse
			current.updatedAt = os.time()
		end
		return current
	end)
	if failedCount > 0 then
		return true, "The private house started. Anyone left here can use Rejoin House Session."
	end
	return true, "Launching your private house server..."
end

local function rejoinHouse(player: Player): (boolean, string?)
	if isStudio then
		return false, "Rejoining a reserved server is unavailable in Studio preview."
	end
	if teleporting[player.UserId] then
		return true, "Your private-house teleport is already in progress..."
	end
	local rejoin, session, rejoinError = rejoinSessionForUser(player.UserId)
	if rejoinError then
		return false, rejoinError
	end
	if type(rejoin) ~= "table" or type(session) ~= "table" then
		return false, "There is no active private house session to rejoin."
	end

	local now = os.time()
	local ticketId = Protocol.newOpaqueId("rejoin")
	local ticketStored, ticketError = mapSet("Tickets", "ticket:" .. ticketId, {
		v = Protocol.VERSION,
		sessionId = session.sessionId,
		userId = player.UserId,
		hostUserId = session.hostUserId,
		members = table.clone(session.members),
		issuedAt = now,
		expiresAt = now + Config.RejoinTicketTTLSeconds,
	}, Config.RejoinTicketTTLSeconds)
	if not ticketStored then
		return false, ticketError or "A secure reconnect ticket could not be issued."
	end

	local teleportData = Protocol.makeHouseTeleportData(
		session.sessionId,
		session.partyId,
		ticketId,
		session.hostUserId,
		session.members,
		now,
		now + Config.RejoinTicketTTLSeconds
	)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = rejoin.accessCode
	options:SetTeleportData(teleportData)
	local teleportToken = beginTeleportAttempt(player)
	local ok = pcall(function()
		TeleportService:TeleportAsync(Config.HousePlaceId, { player }, options)
	end)
	if not ok then
		if teleporting[player.UserId] == teleportToken then
			teleporting[player.UserId] = nil
			teleportFailureMessages[player.UserId] = nil
		end
		mapRemove("Tickets", "ticket:" .. ticketId)
		return false, "Roblox could not reconnect you. Please try again."
	end
	return true, "Rejoining your private house session..."
end

local lastRequestAt: { [number]: number } = {}
local lastRefreshAt: { [number]: number } = {}
local allowedRequests: { [string]: boolean } = table.freeze({
	CreateParty = true,
	PlaySolo = true,
	SetReady = true,
	InviteFriends = true,
	Launch = true,
	LeaveParty = true,
	Rejoin = true,
	Refresh = true,
})

requestRemote.OnServerInvoke = function(player: Player, action: unknown, payload: unknown)
	if type(action) ~= "string" or allowedRequests[action] ~= true then
		-- Malformed remote traffic is never entitled to a MemoryStore-backed state
		-- snapshot. The regular client refresh remains the only recovery path.
		return { ok = false, message = "Invalid lobby request.", state = nil }
	end
	local nowClock = os.clock()
	if action == "Refresh" then
		local minimumRefreshGap = math.max(0.75, Config.StatePollSeconds * 0.6)
		if nowClock - (lastRefreshAt[player.UserId] or 0) < minimumRefreshGap then
			-- Do not perform MemoryStore reads for a client-spammed refresh. The
			-- ordinary UI already retains its last server-authoritative state.
			return { ok = true, message = nil, state = nil }
		end
		lastRefreshAt[player.UserId] = nowClock
	else
		if nowClock - (lastRequestAt[player.UserId] or 0) < Config.RequestCooldownSeconds then
			-- Do not let a malicious client turn rejected button spam into uncapped
			-- MemoryStore reads through publicState(). The client keeps its last
			-- server-authored state and the ordinary poll will refresh it shortly.
			return { ok = false, message = "Please wait a moment.", state = nil }
		end
		lastRequestAt[player.UserId] = nowClock
	end

	local ok = false
	local message: string? = nil
	if action == "CreateParty" then
		local party, createError = createParty(player, false)
		ok = party ~= nil
		message = createError or (ok and "Party created. Invite up to three friends." or nil)
		if party then
			pushParty(party, message)
		end
	elseif action == "PlaySolo" then
		local party, createError = createParty(player, true)
		if not party then
			ok, message = false, createError
		elseif #party.memberUserIds ~= 1 then
			ok, message = false, "Leave your group before starting a solo session."
		else
			if party.readyByUserId[tostring(player.UserId)] ~= true then
				setReady(player, true)
			end
			ok, message = launchParty(player)
		end
	elseif action == "SetReady" then
		ok, message = setReady(player, payload == true)
	elseif action == "InviteFriends" then
		ok, message = issueInvite(player)
	elseif action == "Launch" then
		ok, message = launchParty(player)
	elseif action == "LeaveParty" then
		ok, message = leaveParty(player, false)
	elseif action == "Rejoin" then
		ok, message = rejoinHouse(player)
	elseif action == "Refresh" then
		ok = true
	else
		message = "Unknown lobby request."
	end

	return { ok = ok, message = message, state = publicState(player, message) }
end

TeleportService.TeleportInitFailed:Connect(function(player: Player, _result, errorMessage: string)
	if teleporting[player.UserId] then
		teleporting[player.UserId] = nil
		local fallback = teleportFailureMessages[player.UserId]
		teleportFailureMessages[player.UserId] = nil
		pushState(player, (fallback or "Roblox could not move you yet. Please try again.") .. " (" .. errorMessage .. ")")
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		pushState(player, nil)
		local existingParty = currentPartyForUser(player.UserId)
		if existingParty then
			if existingParty.state == Protocol.PartyStates.Open then
				local _, routeMessage = routePartyMemberToHostLobby(player, existingParty)
				if routeMessage then
					pushState(player, routeMessage)
				end
			end
			return
		end
		-- Roblox may populate invite LaunchData a few seconds after PlayerAdded.
		-- Poll briefly without blocking the base lobby UI, as recommended by the
		-- Creator Hub invite-prompt contract.
		for attempt = 1, 10 do
			if player.Parent ~= Players then
				return
			end
			local joinData = player:GetJoinData()
			local launchData = if type(joinData) == "table" then joinData.LaunchData else nil
			if type(launchData) == "string" and launchData ~= "" then
				local invite, parseError = Protocol.parseInviteLaunchData(launchData)
				if invite then
					local joined, joinError = joinFromInvite(player, invite.ticketId, joinData.ReferredByPlayerId)
					pushState(player, if joined then (joinError or "Joined your friend's private party.") else joinError)
				else
					pushState(player, parseError)
				end
				return
			end
			if attempt < 10 then
				task.wait(1)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player.UserId] = nil
	lastRefreshAt[player.UserId] = nil
	if teleporting[player.UserId] then
		teleporting[player.UserId] = nil
		teleportFailureMessages[player.UserId] = nil
		return
	end
	task.spawn(function()
		leaveParty(player, true)
	end)
end)

-- An open party can legitimately wait while friends accept invitations. Hash
-- map TTLs do not renew on reads, so keep both the host's party and its active
-- membership links alive while that host is still present in this lobby job.
-- House sessions use their separate house-driven heartbeat instead.
task.spawn(function()
	local heartbeatSeconds = math.max(15, math.min(60, Config.PartyTTLSeconds / 3))
	while true do
		task.wait(heartbeatSeconds)
		local renewedPartyIds: { [string]: boolean } = {}
		for _, host in ipairs(Players:GetPlayers()) do
			local party = currentPartyForUser(host.UserId)
			if party
				and party.hostUserId == host.UserId
				and party.lobbyJobId == localLobbyJobId()
				and party.state == Protocol.PartyStates.Open
				and not renewedPartyIds[party.partyId]
			then
				renewedPartyIds[party.partyId] = true
				local renewed = mapUpdate("Parties", party.partyId, Config.PartyTTLSeconds, function(current)
					if validPartyRecord(current, party.partyId)
						and current.hostUserId == host.UserId
						and current.state == Protocol.PartyStates.Open
					then
						current.heartbeatAt = os.time()
					end
					return current
				end)
				if type(renewed) == "table" and renewed.state == Protocol.PartyStates.Open then
					local staleGuests: { number } = {}
					for _, userId in ipairs(renewed.memberUserIds) do
						local membership, membershipError = mapUpdate(
							"Memberships",
							memberKey(userId),
							Config.PartyTTLSeconds,
							function(membership)
								if type(membership) == "table"
									and membership.partyId == renewed.partyId
									and membership.status == "Active"
								then
									membership.heartbeatAt = os.time()
								end
								return membership
							end
						)
						local pendingIsFresh = type(membership) == "table"
							and membership.partyId == renewed.partyId
							and membership.status == "Pending"
							and (tonumber(membership.updatedAt) or 0) > os.time() - 30
						local membershipIsActive = type(membership) == "table"
							and membership.partyId == renewed.partyId
							and membership.status == "Active"
						if userId ~= renewed.hostUserId
							and not membershipError
							and not membershipIsActive
							and not pendingIsFresh
						then
							table.insert(staleGuests, userId)
						end
					end
					if #staleGuests > 0 then
						local cleaned = mapUpdate("Parties", renewed.partyId, Config.PartyTTLSeconds, function(current)
							if validPartyRecord(current, renewed.partyId)
								and current.state == Protocol.PartyStates.Open
							then
								for _, staleUserId in ipairs(staleGuests) do
									current.memberUserIds = removeMember(current.memberUserIds, staleUserId)
									current.readyByUserId[tostring(staleUserId)] = nil
								end
								current.updatedAt = os.time()
							end
							return current
						end)
						pushParty(cleaned, "A stale party slot was cleared.")
					end
				end
			end
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		pushState(player, nil)
	end)
end
