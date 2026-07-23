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

- Local static gate at initial deployment: all `79/79` Luau sources compiled; all 13 active client
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

## Local launch/UI closure after version 308 — not published

The following repair exists in the canonical local sources and the currently
open Studio edit model. It was deliberately **not published**, so version 308
must not be described as containing it.

- Reproduced the Ready→Start failure: a shared request cooldown rejected an
  immediate Launch after an acknowledged Ready operation.
- Replaced it with per-action limits plus a bounded cross-action token bucket.
  A clean Studio runtime accepted Create Party → Ready → Launch with Ready and
  Launch server checkpoints 50 ms apart.
- Added authoritative `selfReady`, party revisions, explicit launch-block
  reasons, atomic launch ownership, secret-safe diagnostics, and session-scoped
  rollback/reconnect invalidation.
- Rebuilt the lobby presentation as a warm 1980s suburban rec room with a
  responsive CRT interface, readable status language, 60-pixel controls,
  scrolling, Core UI safe-area handling, short-landscape layout, and explicit
  keyboard/gamepad focus.
- Final local compilation passed `80/80` `.luau` files. The final lobby passed
  237 foundation + 32 launch-repair checks in edit mode and 281 foundation +
  32 launch-repair checks in runtime.
- Simulator captures passed on iPhone 7 portrait/landscape, iPhone 13 portrait,
  Galaxy A16 landscape, iPad 6 landscape, and desktop. Physical touch remains
  a required live gate.
- Rollback exports and SHA-256 hashes are recorded in
  `backups/milestone-1/README.md`.

These results establish the local and Studio baseline. They do not replace a
real Roblox Player cross-place launch. Browser testing could not hand off to the
installed Player, so live solo, friend invitation, reserved-server,
MemoryStore, physical-device, and complete regression rows remain open.

## Current local closure candidate — 2026-07-23, not published

The current working tree is based on Git commit `f823103`. Its new closure
changes are not represented by version 308, the historical Studio screenshots,
or the dated Studio export above. Record the final candidate commit only after
the working tree and Studio source map are frozen.

- `bash tools/verify_milestone1_local.sh` passed all eight local phases:
  `140` Luau sources compiled, the analyzer was clean, deterministic contracts
  passed `130/130`, the compiler-register matrix passed `27/27`,
  `git diff --check` was clean, all frozen schema/place/feature contracts
  matched, all 13 active clients passed the authority scan, and retired/future
  runtime surfaces remained disabled.
- The deterministic additions cover revisioned Ready state, independent
  Ready/Start throttles, double-Start idempotency, synchronous and asynchronous
  bounded teleport failure paths, one-use admission tickets, exact host-grace
  boundaries, sprint rules, same-frame two-client task completion,
  fail-before-write/fail-after-write reward reconciliation, and completed
  boombox payout settlement under missed ticks, duplicate callbacks, save
  failures, and end/tick races.
- The lobby permits at most two `TeleportAsync` requests for one launch
  attempt. A synchronous request failure or asynchronous
  `TeleportInitFailed` callback can consume the single remaining attempt. The
  retry reuses the original reserved server, session manifest, admission
  tickets, `TeleportOptions`, and launch token; duplicate or stale callbacks
  cannot create another launch. This is locally source- and contract-verified,
  not live TeleportService evidence.
- Candy production/collection/sale, indexed boombox payout ticks, exact
  completed-playback boombox settlement, and paid
  task-upgrade/chemistry/boombox/machine-stage install acknowledgements now use
  named, server-issued persistent operations. A completed boombox playback
  reconciles to exactly `$300` without overpaying when ticks are missed or a
  save/result callback races the end of playback. The legacy broad
  `AdjustCurrency` and `SpendAllowance` API routes fail closed as deprecated.
- `verify_milestone1_value_operations.luau`,
  `verify_milestone1_remote_inventory.luau`, and
  `verify_ui_accessibility_static.luau` compile and are ready for the
  current-candidate Studio audit. They are read-only verifiers; they were not
  run in Studio or a published client as part of this local evidence.

This closes the repeatable CLI/static batch only. It does **not** close
Milestone 1: the current working tree has not been synchronized into or
executed in Studio, and privately published
solo/two/four-player sessions, real MemoryStore/DataStore/TeleportService fault
paths, adversarial runtime security, full feature regression, human visual
acceptance, and physical-device input remain required.

## House source map

| Studio instance | Canonical local source |
| --- | --- |
| `ReplicatedStorage.CooperPartyProtocol` | `CooperPartyProtocol.module.luau` |
| `ReplicatedStorage.CooperUITheme` | `CooperUITheme.module.luau` |
| `ReplicatedStorage.CooperGame.Config` | `CooperFamilyTaskConfig.module.luau` |
| `ReplicatedStorage.CooperGame.TransactionLedger` | `CooperTransactionLedger.module.luau` |
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

- `Config.SchemaVersion = 12`; every shared task reward and current paid house
  purchase stores its server-issued operation record in the same profile payload
  as the allowance/entitlement mutation. `TransactionLedger.MAX_COMMITTED` is at
  least 256, rollback tombstones have a separate bounded history, and stale
  party-session records fail closed. A persisted monotonic issuance watermark
  prevents bounded or out-of-order history from reviving an old operation.
  Purchase presentation starts only after a durable debit+entitlement write;
  ambiguous saves reconcile without replaying the mutation.
- The Milestone 1 journal protects shared task payouts, the six paid order
  operations (machine part, boombox, autoplay, task robot, bunker, and
  chemistry setup), candy production/collection/sale, every indexed boombox
  payout tick, one stable completed-playback settlement, and paid physical
  install acknowledgement for task upgrades, chemistry, boombox, and machine
  stages. The settlement reconciles any missed tick/save/end race to exactly
  `$300` without duplicate overpayment in the deterministic fault suite. Broad
  legacy currency operations are retired. This is source and deterministic
  evidence; isolated DataStore failure/retry, concurrent-server, rejoin, and
  published runtime tests are still required before calling the whole economy
  globally exactly-once.
- Before a task becomes visible, the host durably stores the versioned
  `CalmTaskStart` checkpoint: logical task identity, host ordinal, immutable
  eligible user IDs, safe task-start details, and recovery timing. A recovered
  server exposes that same task and gives absent eligible guests one fixed
  90-second recovery window. Connected players remain eligible; detached guests
  and admitted profiles still hydrating use their own bounded exact deadlines,
  with one rescheduled sweep at each later boundary. Failed checkpoint saves use
  a per-profile single-writer exponential backoff and cannot expose or advance
  the task. The host-last reward transaction clears the checkpoint in the same
  payload that advances `totalTasks`.
- Serialized saves rebuild the sanitized payload for the exact revision on every
  retry after a yielded write. Existing terminal operation IDs return their saved
  result before mutable purchase authorization is checked; Pending/new mutations
  still revalidate current authority, and a profile-wide reconciliation block
  cannot hide its own terminal or `NeedsReconciliation` record.
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
| `ReplicatedStorage.CooperUITheme` | `CooperUITheme.module.luau` |
| `ReplicatedStorage.CooperLobby.Config` | `lobby/CooperLobbyConfig.module.luau` |
| `ServerScriptService.CooperLobby` | `lobby/CooperLobby.server.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperLobby` | `lobby/CooperLobby.client.luau` |

`lobby/build_lobby_environment.luau` is a scoped, idempotent Studio edit-mode
visual updater, not a runtime source. It replaces only
`Workspace.CooperPartyLobbyEnvironment` and the lobby's named Lighting effects.
It never clears Workspace, Terrain, ReplicatedStorage, StarterGui, or runtime
scripts, and it does not overwrite existing synchronized source slots. It is
still role-specific: run it only on the backed-up lobby/start-place copy, never
on the reserved house place.

The protocol and UI-theme modules must be byte-for-byte equivalent in both
places. During the Studio in-place handoff, `ReplicatedStorage.CooperUITheme`
remains the lobby-owned shared copy; the inert preview package must not clone a
second theme module. This source-map addition does not redesign or migrate the
existing house UI. Required lobby configuration is `LobbyPlaceId =
100748614383412`, `HousePlaceId = 98645411943406`, and `UniverseId =
10480337589`. The lobby contains no Cooper
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
3. On the backed-up copy of place `100748614383412`, run the scoped lobby visual
   updater in edit mode, inspect the generated rec room, and then install only
   the lobby source map there.
4. Set the house cap to exactly four and the lobby cap to 50. During a rebuild,
   keep the last known-good start place active until both edit/runtime
   verification passes.
5. Run `verify_milestone1_foundation.luau`,
   `verify_milestone1_value_operations.luau`,
   `verify_milestone1_remote_inventory.luau`, and
   `verify_ui_accessibility_static.luau` in their documented edit/client-runtime
   contexts in both places. Capture every output as evidence.
6. Publish to a private test version and run solo, two-player, and four-player
   cross-place sessions. Studio mocks cannot pass the TeleportService,
   MemoryStore, host-rejoin, or reserved-server gates.
7. Complete every required row in `MILESTONE1_TEST_MATRIX.md`, including
   disconnects during hydration, carried-task host grace, pending deliveries,
   duplicate tickets, and mobile sprint.
8. If rebuilding from a rollback, make `100748614383412` the start place only
   after the pre-publication matrix gates pass, then run one final fresh-profile
   and migrated-profile production smoke test.
9. Export a dated `milestone-1-verified` rollback set and record the exact
   verified Git implementation commit. Historical commit `e1d4b29` and the
   2026-07-22 exports remain rollback evidence; they do not contain the current
   local closure changes. The matrix remains open until genuine live and
   full-regression rows are evidenced.

## Remaining gates not proven by local or Studio evidence

- Real friend invites and `LaunchData` referral behavior.
- Reserved-server allocation and per-user TeleportData.
- MemoryStore ticket contention/replay behavior.
- Host reconnect at the 30-second and 59-second boundaries.
- DataStore lease behavior under disconnect, shutdown, and slow hydration.
- Real Roblox Player solo and cross-place handoff.
- Physical-phone/tablet touch behavior.
- Full existing-feature and four-player collision/delivery playthroughs.
- Current-candidate Studio execution of the value-operation, complete remote
  inventory, and static/runtime UI accessibility verifiers.

Local compilation or a one-client Studio run must never be presented as proof
that these live gates passed.
