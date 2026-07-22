# Milestone 1 deployment manifest

This document maps the local lobby/co-op implementation to the two Roblox
places and records the final Studio deployment evidence. It is not a claim that
the remaining live Roblox-client gates passed. The authoritative row-by-row
record is `MILESTONE1_TEST_MATRIX.md`.

## Fixed topology

| Role | Place ID | Capacity | Start place |
| --- | ---: | ---: | --- |
| Lightweight party lobby | `100748614383412` | 50 | Yes (verified in Creator Dashboard) |
| Reserved Cooper house | `98645411943406` | Exactly 4 | No (`Secure`, within-universe access) |

Both places belong to universe `10480337589`. The lobby must reserve and
teleport parties to the house; the house must return rejected/finished parties
to the lobby. The two IDs must never be equal or reversed.

## Recorded deployment evidence — 2026-07-22

- Local static gate: all `79/79` Luau sources compile; all 13 active client
  sources pass the client-authority scan.
- House verifier: `530` checks passed in edit mode and `616` checks passed in a
  one-player runtime.
- Lobby verifier after the final UI fix: `181` checks passed in edit mode and
  `225` checks passed in runtime.
- Controlled four-client Studio house test: all clients shared one synthetic
  party/host/state; a guest completed George's beer and all four received `$55`
  exactly once; a duplicate completion was rejected; a guest machine purchase
  caused no debit or mutation; the host Blueprint Bench purchase charged only
  the host and created one replicated delivery; sprint state stayed isolated.
- Controlled host-loss test: host removal entered approximately 60 seconds of
  `HostGrace`; guest progress was rejected without cash/task mutation; timeout
  reached `Closing` and requested return to the lobby.
- Solo house checks: sprint changed server speed from 16 to 22 and back;
  stamina drained; exiting the computer cleared the movement lock and forward
  input moved about eight studs at speed 16.
- Lobby interactions passed for Play Solo safe-preview, Create Party,
  ready/cancel, host Launch safe-preview, and Leave Party. Success notices
  remained visible. Desktop, iPhone 14 portrait/landscape, and iPad landscape
  screenshots fit and scroll; Scriptable lobby movement removed the mobile
  joystick overlay.
- Final lobby crash fix: forced `GuiService.SelectedObject` assignments during
  client initialization caused current Studio to crash. Those automatic global
  focus writes were removed while normal `TextButton.Selectable` behavior was
  retained. A fresh runtime remained stable and all button flows were rerun;
  this is the source captured in the verified lobby export and version 308.
- Final lobby runtime produced no project warning or error. The observed
  Studio MCP `2.22.3/2.22.0` mismatch warning is external tooling, not game
  runtime output.
- Creator Dashboard: lobby `100748614383412` is the start place with capacity
  50; house `98645411943406` has capacity four and `Secure` within-universe
  access only.
- The house had already been published; the final lobby was published as
  version `308` on 2026-07-22 at 17:37 EDT.

These results establish the local and Studio baseline. They do not replace a
real Roblox Player cross-place launch. Browser testing could not hand off to the
installed Player, so live solo, friend invitation, reserved-server,
MemoryStore, physical-device, and complete regression rows remain open.

## House source map

| Studio instance | Canonical local source |
| --- | --- |
| `ReplicatedStorage.CooperPartyProtocol` | `CooperPartyProtocol.module.luau` |
| `ReplicatedStorage.CooperGame.Config` | `CooperFamilyTaskConfig.module.luau` |
| `ServerScriptService.CooperGame` | `CooperFamilyTaskGame.server.luau` |
| `ServerScriptService.CooperTaskWorld` | `CooperFamilyTaskWorld.server.luau` |
| `ServerScriptService.CooperInteractions` | `CooperInteractions.server.luau` |
| `ServerScriptService.CooperMovement` | `CooperMovement.server.luau` |
| `ServerScriptService.CooperBunker` | `CooperBunker.server.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperGame` | `CooperFamilyTaskGame.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperSprint` | `CooperSprint.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperBunkerClient` | `CooperBunker.client.luau` |

All other unchanged house sources continue to use the canonical Milestone 0 map
in `MILESTONE0_BASELINE.md`. Retired installers under `legacy/retired` are never
deployment inputs.

Required house contracts:

- `Config.ReleasePlayerCap = 4` and the Creator Dashboard house cap is exactly
  four.
- `Config.Party.LobbyPlaceId = 100748614383412`.
- `Config.Party.HousePlaceId = 98645411943406`.
- Only `Config.Features.Lobby` is `true`; Horror, SecretExploration,
  TimeMachineFinale, Postgame, and StudioScenarioTools remain `false`.
- The house admits production players only through server-validated, user-bound,
  one-use MemoryStore tickets into a reserved server.

## Lobby source map

| Studio instance | Canonical local source |
| --- | --- |
| `ReplicatedStorage.CooperPartyProtocol` | `CooperPartyProtocol.module.luau` |
| `ReplicatedStorage.CooperLobby.Config` | `lobby/CooperLobbyConfig.module.luau` |
| `ServerScriptService.CooperLobby` | `lobby/CooperLobby.server.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperLobby` | `lobby/CooperLobby.client.luau` |

`lobby/build_lobby_environment.luau` is a destructive, one-time Studio edit-mode
builder, not a runtime source. It clears the house DataModel, builds the
lightweight lobby shell, and creates empty source slots. Run it only on the
backed-up lobby/start-place copy, then synchronize the four canonical sources
above. Never run it in the reserved house place or after production sources
have been installed.

The protocol module must be byte-for-byte equivalent in both places. Required
lobby configuration is `LobbyPlaceId = 100748614383412`, `HousePlaceId =
98645411943406`, and `UniverseId = 10480337589`. The lobby contains no Cooper
house task authority, no public matchmaking, and no reserved-server access code
in replicated state or TeleportData.

## Safe redeployment order

For a clean rebuild or rollback-forward, use this order. The recorded evidence
above confirms that the current Creator Dashboard topology and publication
steps are already complete; publication does not close the remaining live test
gates.

1. Preserve new dated exports of both places. Retain the pre-Milestone rollback
   set documented in `backups/milestone-1/README.md`.
2. Build place `98645411943406` from an inspected copy of the verified Cooper
   house and install the house source map there.
3. On the backed-up copy of place `100748614383412`, run the one-time lobby
   environment builder in edit mode, inspect the generated shell, and then
   install only the lobby source map there.
4. Set the house cap to exactly four and the lobby cap to 50. During a rebuild,
   keep the last known-good start place active until both edit/runtime
   verification passes.
5. Run `verify_milestone1_foundation.luau` in edit and runtime mode in both
   places. Capture the output as evidence.
6. Publish to a private test version and run solo, two-player, and four-player
   cross-place sessions. Studio mocks cannot pass the TeleportService,
   MemoryStore, host-rejoin, or reserved-server gates.
7. Complete every required row in `MILESTONE1_TEST_MATRIX.md`, including
   disconnects during hydration, carried-task host grace, pending deliveries,
   duplicate tickets, and mobile sprint.
8. If rebuilding from a rollback, make `100748614383412` the start place only
   after the pre-publication matrix gates pass, then run one final fresh-profile
   and migrated-profile production smoke test.
9. Export a dated `milestone-1-verified` rollback set and record the verified Git
   commit. The dated house/lobby exports now exist; the matrix remains open
   until its genuine live and full-regression rows are evidenced.

## Remaining gates not proven by local or Studio evidence

- Real friend invites and `LaunchData` referral behavior.
- Reserved-server allocation and per-user TeleportData.
- MemoryStore ticket contention/replay behavior.
- Host reconnect at the 30-second and 59-second boundaries.
- DataStore lease behavior under disconnect, shutdown, and slow hydration.
- Real Roblox Player solo and cross-place handoff.
- Physical-phone/tablet touch behavior.
- Full existing-feature and four-player collision/delivery playthroughs.

Local compilation or a one-client Studio run must never be presented as proof
that these live gates passed.
