local Parties = {}

function Parties.mixedPresence()
	return {
		{ userId = 101, sessionMember = true, hydrated = true, presence = "Active" },
		{ userId = 102, sessionMember = true, hydrated = true, presence = "AFK" },
		{ userId = 103, sessionMember = true, hydrated = true, presence = "Respawning" },
		{ userId = 104, sessionMember = true, hydrated = true, presence = "Bunker" },
		{ userId = 105, sessionMember = true, hydrated = true, presence = "OptionalRoute" },
		{ userId = 106, sessionMember = true, hydrated = false, presence = "Loading" },
		{ userId = 107, sessionMember = false, hydrated = true, presence = "Active" },
		{ userId = 108, sessionMember = true, hydrated = true, presence = "Disconnected" },
	}
end

return Parties
