# Milestone 1 invited-party lobby

This directory is the source package for the separate, lightweight lobby place.
It does not add public matchmaking. A server-authoritative party contains one
host and 0–3 invited friends, and launches one reserved Cooper House server.

## Studio mapping

Install the files with these exact names:

| Local source | Lobby-place destination |
| --- | --- |
| `../CooperPartyProtocol.module.luau` | `ReplicatedStorage.CooperPartyProtocol` |
| `../CooperUITheme.module.luau` | `ReplicatedStorage.CooperUITheme` |
| `CooperLobbyConfig.module.luau` | `ReplicatedStorage.CooperLobby.Config` |
| `CooperLobby.server.luau` | `ServerScriptService.CooperLobby` |
| `CooperLobby.client.luau` | `StarterPlayer.StarterPlayerScripts.CooperLobby` |

`build_lobby_environment.luau` is a destructive, one-time Studio edit-mode
builder, not a sixth runtime source. It clears the current house DataModel,
builds the lightweight lobby shell, and creates placeholder source slots. Run
it only after backups exist and only on the start-place copy being converted to
the lobby. Synchronize the five canonical sources above immediately afterward.
Never run it in the reserved Cooper house place or over an installed lobby.

The `ReplicatedStorage.CooperLobby` folder must contain the `Config` ModuleScript.
The server creates `ReplicatedStorage.CooperPartyLobby` and its three remotes:
`Request`, `State`, and `ClientCommand`.

`CooperUITheme.module.luau` is the versioned source of the approved late-1980s
palette, Gotham/Roboto Mono typography, 60-pixel action height, contrast floors,
and Core UI safe-area contract. Install the same source as
`ReplicatedStorage.CooperUITheme` in the lobby and reserved house. The current
house UI is intentionally unchanged by this Milestone 1 consolidation. During
the in-place Studio house preview, the lobby's replicated theme remains resident
through the handoff; `StudioHousePreviewPackage` must not contain a second copy
that could shadow or drift from it. The lobby client has an exact v1 compatibility
palette only for a stale place where the module is completely absent. A present
but malformed or wrong-version module fails loudly.

Before publishing, verify the fixed topology in both configs. Roblox always
sends ordinary experience joins to the start place, and an added
place cannot simply be marked as the new start place. The safe deployment is:

1. Export and verify the current house rollback.
2. Publish a verified copy of the house as the new additional place.
3. Publish this lightweight lobby over the existing start place only after the
   house copy is proven playable.
4. Set `LobbyPlaceId = 100748614383412` and `HousePlaceId = 98645411943406` in
   both configs.

The scripts intentionally fail closed outside Studio while either final ID is
missing, identical, or outside universe `10480337589`.

## Security contract

- LaunchData contains only a short, opaque invitation ticket. The lobby server
  validates its TTL in MemoryStore, verifies the joining account is the host's
  Roblox friend, cross-checks `ReferredByPlayerId`, checks party capacity/state,
  and records accepted user IDs.
- A friend who lands in a different public lobby instance is routed into the
  host's lobby instance before ready-up. Global membership is atomically claimed
  first, so racing invitations cannot put one account into two parties.
- House TeleportData contains an opaque session ID and short-lived arrival
  ticket plus a claimed host/member snapshot. The house server must validate all
  of it against the `CooperPartySessions_v1` MemoryStore hash map before granting
  party or host authority.
- The reserved-server access code exists only in each user's server-side
  `CooperPartyRejoin_v1` record. It is never returned through a remote,
  LaunchData, TeleportData, an attribute, or public party state.
- Each initial arrival and rejoin gets a distinct ticket in
  `CooperPartyLaunchTickets_v1`, scoped to exactly one user. The house consumes
  it atomically and cross-checks it against `CooperPartySessions_v1`. Rejoin
  tickets expire after 90 seconds; expired/replayed tickets fail closed.
- `CooperPartyRejoin_v1` is readable only by servers. The lobby uses its access
  code to mint a fresh single-user ticket and sends only that opaque ticket ID.
- MemoryStore is coordination authority, not persistent player progression.
  Existing DataStore profiles remain owned and saved by the house server.

The house implementation must keep the session manifest alive, set its state to
`InHouse` (or `HostGrace` while paused), consume arrival/rejoin tickets atomically, set/clear
`hostGraceExpiresAt`, and finally set `state = "Closed"` when returning a party.

## Studio behavior

TeleportService cannot launch reserved servers in Studio. The lobby therefore
uses a process-local in-memory adapter in Studio. Party creation, size limits,
solo ready/host checks, state replication, and adaptive UI can be inspected
without touching production MemoryStore. Pressing Start opens the verified
in-place Cooper House package in that same Studio playtest, but does **not**
reserve a server, write a session manifest, teleport anyone, or grant saved
production authority. Real invitation membership,
cross-instance routing, 2/4-player launches, and rejoin routing require the
privately published Roblox-client tests in the matrix; Studio does not forge
friends or production invitation tickets.

## Release tests

1. Verify lobby `100748614383412`, house `98645411943406`, and universe
   `10480337589`; then confirm ordinary experience joins open the lobby start
   place. Keep the house place accessible only through the intended flow.
2. Confirm solo Play launches immediately into a reserved house server.
3. Invite one and then three friends. Confirm every member must be present and
   ready, only the host sees an enabled Start button, and capacity stays at four.
4. Attempt forged, expired, malformed, non-friend, full-party, and replayed
   invitation tickets. None may join a party.
5. Inspect every client-visible response and teleport payload. No reserved
   access code may appear.
6. Disconnect a member and use Rejoin Session. Disconnect the host during a
   house session and confirm rejoin works only inside the house server's
   60-second grace period.
7. Exercise phone/tablet portrait and landscape, keyboard, gamepad, and screen
   sizes down to 320×480. All buttons remain at least 56 pixels tall, text wraps,
   the member list scrolls, and READY state is communicated by words and a check
   mark rather than color alone.
