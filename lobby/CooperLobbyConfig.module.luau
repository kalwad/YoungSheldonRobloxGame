--!strict
-- Install as ReplicatedStorage.CooperLobby.Config in the dedicated lobby place.

local Config = {
	ProtocolVersion = 1,
	UniverseId = 10480337589,
	-- The verified private-party house clone. The public start place remains the
	-- lobby and is the only supported entry point for players.
	HousePlaceId = 98645411943406,
	LobbyPlaceId = 100748614383412,

	MinimumPartySize = 1,
	MaximumPartySize = 4,
	PartyTTLSeconds = 15 * 60,
	InviteTTLSeconds = 5 * 60,
	SessionTTLSeconds = 60 * 60,
	SessionHeartbeatSeconds = 2 * 60,
	ArrivalTicketTTLSeconds = 180,
	GuestAdmissionGraceSeconds = 90,
	RejoinTicketTTLSeconds = 90,
	RequestCooldownSeconds = 0.25,
	StatePollSeconds = 1.5,

	-- Studio cannot exercise TeleportService. The lobby therefore hands a valid
	-- ready party to a local, inert house-preview package. That preview is never
	-- a production session and never grants saved progression or live authority.
	StudioPreview = true,
}

return table.freeze(Config)
