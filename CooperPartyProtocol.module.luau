--!strict
-- Shared, data-only protocol for Milestone 1 lobby -> house sessions.
-- Install as ReplicatedStorage.CooperPartyProtocol in BOTH places.
--
-- Security boundary:
--   * TeleportData and LaunchData are hints, never authority.
--   * The destination server must validate the opaque IDs against MemoryStore.
--   * Reserved-server access codes are deliberately absent from every shape here.

local HttpService = game:GetService("HttpService")

local Protocol = {}
local INVITE_LAUNCH_KIND = "CooperPartyInvite"
local HOUSE_TELEPORT_KIND = "CooperHouseSession"

Protocol.VERSION = 1
Protocol.MAX_PARTY_SIZE = 4
Protocol.INVITE_LAUNCH_KIND = INVITE_LAUNCH_KIND
Protocol.HOUSE_TELEPORT_KIND = HOUSE_TELEPORT_KIND

Protocol.MemoryStoreNames = table.freeze({
	Parties = "CooperPartyLobbyParties_v1",
	Invites = "CooperPartyInvites_v1",
	Memberships = "CooperPartyMemberships_v1",
	Tickets = "CooperPartyLaunchTickets_v1",
	Sessions = "CooperPartySessions_v1",
	Rejoins = "CooperPartyRejoin_v1",
})

Protocol.PartyStates = table.freeze({
	Open = "Open",
	Launching = "Launching",
	InHouse = "InHouse",
	Closed = "Closed",
})

-- Session records outlive the short lobby launch record and are refreshed by
-- the authoritative house server. Keeping these names in the shared protocol
-- prevents the lobby from accidentally treating a closing session as rejoinable.
Protocol.SessionStates = table.freeze({
	Launching = "Launching",
	InHouse = "InHouse",
	HostGrace = "HostGrace",
	Closing = "Closing",
	Closed = "Closed",
})

export type InviteLaunchData = {
	v: number,
	kind: string,
	ticketId: string,
}

export type HouseTeleportData = {
	v: number,
	kind: string,
	sessionId: string,
	partyId: string,
	ticketId: string,
	hostUserId: number,
	memberUserIds: { number },
	issuedAt: number,
	expiresAt: number,
}

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == math.floor(value :: number)
		and value > 0
		and value < math.huge
end

function Protocol.isOpaqueId(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end
	local length = #value
	if length < 20 or length > 96 then
		return false
	end
	return string.match(value, "^[%w_%-]+$") ~= nil
end

local function sanitizeMemberUserIds(raw: unknown): ({ number }?, string?)
	if type(raw) ~= "table" then
		return nil, "memberUserIds must be an array"
	end

	local result = {}
	local seen: { [number]: boolean } = {}
	for index, value in ipairs(raw :: { unknown }) do
		if index > Protocol.MAX_PARTY_SIZE then
			return nil, "party is larger than four players"
		end
		if not isFiniteInteger(value) then
			return nil, "memberUserIds contains an invalid user id"
		end
		local userId = value :: number
		if seen[userId] then
			return nil, "memberUserIds contains a duplicate"
		end
		seen[userId] = true
		table.insert(result, userId)
	end

	if #result < 1 then
		return nil, "party has no members"
	end
	if #result ~= #(raw :: { unknown }) then
		return nil, "memberUserIds must be a dense array"
	end
	return result, nil
end

function Protocol.memberSet(memberUserIds: { number }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, userId in ipairs(memberUserIds) do
		set[tostring(userId)] = true
	end
	return set
end

function Protocol.containsMember(memberUserIds: { number }, userId: number): boolean
	for _, candidate in ipairs(memberUserIds) do
		if candidate == userId then
			return true
		end
	end
	return false
end

function Protocol.makeInviteLaunchData(ticketId: string): string
	assert(Protocol.isOpaqueId(ticketId), "invalid invite ticket id")
	return HttpService:JSONEncode({
		v = Protocol.VERSION,
		kind = INVITE_LAUNCH_KIND,
		ticketId = ticketId,
	})
end

function Protocol.parseInviteLaunchData(raw: unknown): (InviteLaunchData?, string?)
	if type(raw) ~= "string" or raw == "" then
		return nil, "no party invitation was supplied"
	end
	if #raw > 200 then
		return nil, "party invitation is too large"
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil, "party invitation is malformed"
	end
	if decoded.v ~= Protocol.VERSION or decoded.kind ~= INVITE_LAUNCH_KIND then
		return nil, "party invitation version is unsupported"
	end
	if not Protocol.isOpaqueId(decoded.ticketId) then
		return nil, "party invitation ticket is invalid"
	end

	return {
		v = Protocol.VERSION,
		kind = INVITE_LAUNCH_KIND,
		ticketId = decoded.ticketId,
	}, nil
end

function Protocol.makeHouseTeleportData(
	sessionId: string,
	partyId: string,
	ticketId: string,
	hostUserId: number,
	memberUserIds: { number },
	issuedAt: number,
	expiresAt: number
): HouseTeleportData
	assert(Protocol.isOpaqueId(sessionId), "invalid session id")
	assert(Protocol.isOpaqueId(partyId), "invalid party id")
	assert(Protocol.isOpaqueId(ticketId), "invalid arrival ticket id")
	assert(isFiniteInteger(hostUserId), "invalid host user id")
	assert(isFiniteInteger(issuedAt) and isFiniteInteger(expiresAt), "invalid ticket timestamps")
	assert(expiresAt > issuedAt and expiresAt - issuedAt <= 300, "invalid ticket lifetime")
	local sanitizedMembers, memberError = sanitizeMemberUserIds(memberUserIds)
	assert(sanitizedMembers ~= nil, memberError or "invalid party members")
	assert(Protocol.containsMember(sanitizedMembers, hostUserId), "host is not a party member")

	return {
		v = Protocol.VERSION,
		kind = HOUSE_TELEPORT_KIND,
		sessionId = sessionId,
		partyId = partyId,
		ticketId = ticketId,
		hostUserId = hostUserId,
		memberUserIds = sanitizedMembers,
		issuedAt = issuedAt,
		expiresAt = expiresAt,
	}
end

function Protocol.validateHouseTeleportData(
	raw: unknown,
	arrivingUserId: number,
	nowUnix: number
): (HouseTeleportData?, string?)
	if type(raw) ~= "table" then
		return nil, "missing house session data"
	end
	local value = raw :: { [any]: any }
	if value.v ~= Protocol.VERSION or value.kind ~= HOUSE_TELEPORT_KIND then
		return nil, "house session version is unsupported"
	end
	if not Protocol.isOpaqueId(value.sessionId)
		or not Protocol.isOpaqueId(value.partyId)
		or not Protocol.isOpaqueId(value.ticketId)
	then
		return nil, "house session contains an invalid opaque id"
	end
	if not isFiniteInteger(value.hostUserId)
		or not isFiniteInteger(value.issuedAt)
		or not isFiniteInteger(value.expiresAt)
	then
		return nil, "house session timestamps or host are invalid"
	end
	if value.expiresAt <= nowUnix then
		return nil, "house session ticket expired"
	end
	if value.expiresAt <= value.issuedAt then
		return nil, "house session ticket timestamps are reversed"
	end
	if value.issuedAt > nowUnix + 30 then
		return nil, "house session ticket was issued in the future"
	end
	if value.expiresAt - value.issuedAt > 300 then
		return nil, "house session ticket lifetime is too long"
	end

	local memberUserIds, memberError = sanitizeMemberUserIds(value.memberUserIds)
	if memberUserIds == nil then
		return nil, memberError
	end
	if not Protocol.containsMember(memberUserIds, value.hostUserId) then
		return nil, "house session host is not a member"
	end
	if not Protocol.containsMember(memberUserIds, arrivingUserId) then
		return nil, "player is not a member of this house session"
	end

	return {
		v = Protocol.VERSION,
		kind = HOUSE_TELEPORT_KIND,
		sessionId = value.sessionId,
		partyId = value.partyId,
		ticketId = value.ticketId,
		hostUserId = value.hostUserId,
		memberUserIds = memberUserIds,
		issuedAt = value.issuedAt,
		expiresAt = value.expiresAt,
	}, nil
end

function Protocol.newOpaqueId(prefix: string): string
	-- This helper is server-only in practice. It lives here so both lobby and
	-- house servers use exactly the same identifier format for rejoin tickets.
	assert(string.match(prefix, "^[%a][%w_]*$") ~= nil, "invalid opaque-id prefix")
	return prefix .. "_" .. string.gsub(HttpService:GenerateGUID(false), "%-", "")
end

return table.freeze(Protocol)
