# Remote, Prompt, and Server-Boundary Security Matrix

Audit date: 2026-07-23
Method: static inventory of active local Luau sources. The eight-phase local
gate and deterministic contracts passed; no current-candidate Studio,
published server, MemoryStore, DataStore, or exploit-client execution is
claimed.

## Status meaning

- **SOURCE VERIFIED**: the named validation is visibly enforced on the server in the current local source.
- **PARTIAL**: useful validation exists, but a required check or adversarial runtime test is missing.
- **GAP**: a concrete server-side validation/control is absent or relies only on client/engine presentation.
- **BLOCKED / NOT RUN**: the path requires Studio/published infrastructure or does not exist yet.

Server-to-client-only remotes are listed so the inventory is complete. Bindables are server-only in Roblox and cannot be fired directly by an ordinary client; they still require typed, allowlisted contracts because a compromised or incorrect server script can invoke them.

## Current automated inventory status

- `bash tools/verify_milestone1_local.sh` passed its client-authority scan across
  all 13 active client sources and confirmed that retired/future runtime
  surfaces remain disabled. The same run compiled `140/140` Luau sources,
  passed `130/130` deterministic checks, and passed the `27/27` compiler-register
  matrix.
- `verify_milestone1_remote_inventory.luau` is a new read-only Studio audit. It
  checks literal client action/call-site drift, server allowlists and guards,
  server-to-client ownership, physical prompt registries, door and bunker
  guards, server-only bindables, and privileged debug/scenario surfaces. It
  compiles but is **NOT RUN** against the current Studio or published
  candidate.
- Passing that static verifier will not convert any published malformed
  payload, replay, flood, ticket, proximity, or multiplayer row to PASS.

## Client-to-server network surface

| Surface | Accepted client actions | Source-verified server controls | Status and open work |
|---|---|---|---|
| `ReplicatedStorage.CooperGame.Remotes.Request` → `CooperFamilyTaskGame.server.luau` | `TutorialSeen`, `CloseComputer`, `CloseBunkerComputer`, `OrderBeer`, `OrderMachinePart`, `OrderBoombox`, `OrderTaskUpgrade`, `UpgradeBoomboxAutoplay`, `OrderSecretBunker`, `OrderChemistrySetup`, `HiddenSeen`, `LegacyCommand`, `RequestSnapshot` | String action check; loaded/non-releasing profile; party membership; party active state for progression; general 0.18-second request cooldown and separate snapshot cooldown; house terminal session plus live keyboard distance for house orders/commands; bunker terminal session plus live distance/access for chemistry; host-only world mutation; authoritative catalog/stage/price/funds/pending state; active task/step and delivery conflicts; hidden marker exact match and 14-stud distance | **PARTIAL.** Strong authority/context checks. `TutorialSeen` is a benign profile bit but has no explicit phase/distance and no operation ID. Unknown actions are silently inert rather than consistently rejected/logged. One broad request cooldown is not an observability or replay defense. Published fuzz/rate/replay tests remain NOT RUN. |
| `ReplicatedStorage.CooperGame.Remotes.BankHack` → family server | `Start`, `Input`, `Cancel` | Loaded/member/active party; general start cooldown; valid terminal session and distance; active bank task/step; one server session/actor; server session ID; input type, key length and key allowlist; 0.04-second input cooldown; server timing/phase and expected pattern; mismatch rejection; idempotent late cancel; unknown-action error; reward is server calculated | **SOURCE VERIFIED / runtime PARTIAL.** Static validation is strong. Needs malicious payload, replay, clock manipulation, disconnect/rejoin, duplicate-result, and progressive-speed published/scenario tests. |
| `ReplicatedStorage.CooperInteractionsRemotes.Request` → `CooperInteractions.server.luau` | `HeldAction` (`Throw`, `Drop`, `Solve`), `TerminalCommand`, `TerminalClose`, `CubeMove`, `CubeReshuffle`, `CubeGiveUpThrow`, `CubeClose` | Action/payload types; per-action cooldowns; held-object ownership; cube session ID and ownership; approved cube face; live cube/computer distance; active terminal session; command nonblank/truncated/control-stripped before reporting; give-up throw validates held/near loose cube | **SOURCE VERIFIED / runtime PARTIAL.** Needs moved-part/instance spoof, oversized table/string, NaN, flood, reset, simultaneous pickup, and network-lag tests. `TerminalClose` intentionally only clears caller state. |
| `ReplicatedStorage.CooperYardRideablesRemotes.RideablesEvent` → `CooperYardRideables.server.luau` | `SwingPump`, `ResetSwing`, `TrikeControl`, `ResetTrike` | Player must occupy the correct seat; per-action rate bounds; finite numeric checks; input clamps; prompt use checks living humanoid/not seated and 11/12-stud distance; server owns assembly updates | **SOURCE VERIFIED / runtime PARTIAL.** Needs NaN/infinity/flood, ownership churn, death/reset, streaming, mobile/controller, and collision/path tests. |
| `ReplicatedStorage.CooperMovementRemotes.SprintIntent` → `CooperMovement.server.luau` | Boolean sprint intent | Strict boolean; stop intent accepted safely; token bucket for starts; living, healthy, unseated humanoid; stamina/exhaustion; named/modal movement locks; server computes stamina and rewrites authoritative speed | **SOURCE VERIFIED / runtime PARTIAL.** Needs local WalkSpeed tamper, flood, death/reset, overlapping lock, latency, mobile/controller, and four-player tests. |
| `ReplicatedStorage.CooperPartyLobby.Remotes.Request` `RemoteFunction` → `lobby/CooperLobby.server.luau` | `CreateParty`, `PlaySolo`, `SetReady`, `InviteFriends`, `Launch`, `LeaveParty`, `Rejoin`, `Refresh` | Strict action allowlist; typed ready payload; per-action minimum gaps plus token bucket; separately throttled refresh; server-owned party/host/readiness; host-only invite/launch; party lifecycle/size/readiness/presence checks; MemoryStore compare/update revisions; opaque expiring one-use house admission tickets; safe failure reason codes; one shared bounded retry budget for synchronous `TeleportAsync` failure or asynchronous `TeleportInitFailed`, reusing the original reservation, session manifest, tickets, `TeleportOptions`, and launch token and rejecting stale/duplicate callbacks | **SOURCE VERIFIED / published BLOCKED.** Deterministic ordering, idempotency, ticket, grace, and synchronous/asynchronous bounded-retry contracts pass. Real reserved-server launch, stale/replayed ticket, outsider, partial teleport, MemoryStore contention, host/guest reconnect, and Ready/Start behavior are not proven by static or fake services. This is the critical M1 gate. |
| `ReplicatedStorage.CooperFamilyDialogue.Session` → `CooperFamilyDialogue.server.luau` | `Close` | Only `Close` mutates state; it releases the caller's own active session; prompt opens session only within 12 studs and honors NPC exclusivity/dance guard | **PARTIAL.** Close creates no value and needs no expensive work, but it has no explicit rate/log. Test spam, reset, two-player contention, and spoofed action. |

## Server-to-client-only remotes

| Surface | Purpose | Client authority | Status |
|---|---|---|---|
| `CooperGame.Remotes.Snapshot` | server-authored game/profile/task snapshot | None; no server listener | **SOURCE VERIFIED** |
| `CooperGame.Remotes.Feedback` | server-authored notifications, terminal/UI events | None; no server listener | **SOURCE VERIFIED** |
| `CooperInteractionsRemotes.Client` | held/cube/terminal interaction presentation | None; no server listener | **SOURCE VERIFIED** |
| `CooperPartyLobby.Remotes.State` | server-authored party state | None; no server listener | **SOURCE VERIFIED** |
| `CooperPartyLobby.Remotes.ClientCommand` | server-authored lobby UI/launch commands | None; no server listener | **SOURCE VERIFIED** |
| `CooperBunkerRemotes.BunkerEvent` | bunker presentation/state feedback | None; no server listener | **SOURCE VERIFIED** |
| `CooperFamilyDialogue.Session` server messages | open/close dialogue UI | Client can only send the separate `Close` action described above | **SOURCE VERIFIED** |

## ProximityPrompt and physical interaction surface

ProximityPrompt configuration is not a security boundary by itself. The server must re-check the acting player, exact prompt/action, context, and distance.

| Source/registry | Client-triggered actions | Source-verified checks | Status and gap |
|---|---|---|---|
| `CooperInteractions.server.luau` `CooperAction` registry | `Pickup`, `CubePuzzle`, `ToiletSit`, `ToiletFlush`, `ShowerToggle`, `ShowerUse`, `SinkWash`, `BrushTeeth`, `Computer`, `FridgeToggle`, `FridgeBeer` | Prompt must be a registered descendant; server action allowlist; player/humanoid; explicit distance (`MaxActivationDistance + 4`, minimum 12); 0.25-second cooldown; action-specific ownership/occupancy/state; timed actions use server movement lock | **SOURCE VERIFIED / runtime PARTIAL.** Needs spoofed/moved prompt, simultaneous users, streaming, reset, obstruction, and mobile prompt tests. |
| `CooperFamilyTaskWorld.server.luau` task prompt registry | `Dishes`, `TrashPickup`, `TrashDrop`, `MissyReturn`, `DeliveryPickup`, `BeerDrop`, `MachineInstall`, `BoomboxSetup`, `BoomboxPower`, `TaskUpgradeInstall`; candy buyer prompt | Prompt registry/descendant and action allowlist; per-player/action 0.45-second cooldown; distance `Max + 3`; active party/task/step; held-tool owner/kind/token; authoritative delivery snapshot/stage; install catalog and host snapshot; server hold-duration proof for dishes; buyer session/player/batch token/distance | **SOURCE VERIFIED / runtime PARTIAL.** Needs simultaneous completion, replayed delivery tokens, client-owned moved tool/part, interrupted commit, robot/buyer concurrency, and four-client soak. |
| `CooperBunker.server.luau` prompt registry | research computer, chemistry, collect candy, hatch, blast door, main lights | Bunker access; party active for chemistry; setup/placed/visible/state/token; explicit distance (`Max + 3/4`); door moving/occupancy safety; server-owned cooldown/product state; independent per-player Hatch/BlastDoor/MainLights rate buckets execute before access snapshots and sweep queries | **SOURCE VERIFIED / runtime PARTIAL.** Static rate and safety guards are present. Multi-client flooding, simultaneous close attempts, occupancy timing, reset/death, and moved-prompt tests remain NOT RUN. |
| `front_door_controller.server.luau` | front door toggle prompt | Connected hydrated party member; `Active`/`HostGrace` phase; living workspace character/root; enabled registered prompt; hard-capped live distance; per-player action rate; idle/synchronized door state; existing obstruction and automation-hold checks | **SOURCE VERIFIED / runtime PARTIAL.** Needs forged trigger, far-distance, death/reset, simultaneous users, obstruction timing, and automation-hold scenarios. |
| `patio_door_controller.server.luau` | patio door toggle prompt | Same membership, phase, living-root, enabled-prompt, hard-capped distance, per-player rate, synchronized-state, obstruction, and automation-hold checks as the front door | **SOURCE VERIFIED / runtime PARTIAL.** Same adversarial/runtime scenarios remain NOT RUN. |
| `georgie_garage_door_controller.server.luau` | garage door toggle prompt | Connected hydrated party member; allowed phase; living root; enabled prompt; hard-capped distance; per-player rate; idle `IsOpen`/`DoorState` agreement; doorway obstruction and collision blocker remain authoritative | **SOURCE VERIFIED / runtime PARTIAL.** Needs simultaneous clients, obstruction timing, streaming, automation interaction, and reset/death scenarios. |

## Server-only Bindable surface

| Surface | Callers / purpose | Current validation | Status |
|---|---|---|---|
| `ServerScriptService.CooperGameServerEvents.ReportAction` | interaction/world scripts report authoritative task actions and paid physical acknowledgements | Family server validates player/profile/party, action/task context and payload fields before progression; enumerated task rewards and paid install acknowledgements use named persistent operations | **PARTIAL.** Server-only boundary and local operation identities are correct; caller fault, duplicate/out-of-order callback, disconnect, and isolated persistence execution remain. |
| `RegisterAction` | registers server action/catalog metadata | Server-only typed/action registration | **PARTIAL.** Audit every registrant and reject duplicate/unknown definitions with diagnostics. |
| `RequestDelivery` | family server asks task world for an ordinary paid/task delivery | Request key/snapshot/catalog/session checks in world; retry exists because bindables do not retain startup messages | **PARTIAL.** Needs duplicate, stale, starvation/fairness, leave/rejoin, and interrupted-delivery tests. |
| `RequestBunkerConstruction` | family server starts bunker construction | Bunker construction server validates authoritative payload/state | **PARTIAL.** Needs duplicate/stale operation and cleanup/streaming tests. |
| `RunTaskAutomation` | family server starts a configured robot job | World checks catalog/snapshot/owner and task context | **PARTIAL.** Needs server-owned robot outcome reason codes, path/fault tests, and exactly-once completion. |
| `CandyDeliveryChanged` | task world reports candy buyer/delivery state | Family side validates owner/session/batch identity; candy production, collection, and sale have stable server-owned persistent operation kinds | **PARTIAL.** Deterministic identity tests pass; runtime duplicate/out-of-order/fail-then-succeed, distance, disconnect, and save-fault tests remain. |
| `CooperGameServerEvents.API` `BindableFunction` | bunker/world queries and host-authoritative operations | Action-specific validation is implemented server-side; candy lifecycle, indexed boombox ticks, exact `$300` completed-playback settlement, and paid installs use named persistent operations; broad `AdjustCurrency` and `SpendAllowance` operations fail closed as deprecated | **PARTIAL.** Deterministic boombox missing-tick/save/retry/end-race cases settle to exactly `$300` without overpayment. The value-operation verifier and complete inventory compile but are NOT RUN in Studio; no caller provenance exists beyond server-only scope, and runtime type/replay/fault tests remain. |
| `CooperMovementAPI.SetLock`, `SetSpeedMultiplier`, `ReleaseSource`, `StateChanged` | server scripts coordinate movement locks/multipliers | Player/source type, trimmed source length, boolean/range/finite validation; named ownership prevents accidental unlock | **SOURCE VERIFIED / runtime PARTIAL.** Server scripts are trusted; test overlapping sources, teardown, throws, death, and nil releases. |
| Door/refrigerator `AutomationDoorCommand` functions | robots hold/release doors | Command/action/hold-count validation | **PARTIAL.** Server-only, but no caller identity; ensure all calls are catalog-owned and teardown cannot strand a hold. Garage is not yet unified. |
| `lobby.CooperLobbyStudioBridge.Launch` | Studio-only local house preview launch | Created by the Studio preview path and called only after lobby server validation | **BLOCKED for production proof.** `verify_production_build_surface.luau` must prove the bridge and scenario controls are absent/inaccessible in a published candidate. |

## Future surfaces that do not exist yet

There is no active client-to-server horror, hunter-selection, hiding, distraction, horror light-switch, secret exploration, finale, ending-choice, or postgame remote in the audited source. Corresponding security cases (`SEC-006`, `SEC-007`, `SEC-008`, `SEC-010`, and related M2+ cases) are **NOT RUN**, not passed. The feature flags for `Horror`, `SecretExploration`, `TimeMachineFinale`, `Postgame`, and `StudioScenarioTools` remain false.

Any future state-changing path must validate on the server, at minimum:

- exact action allowlist and payload type/size/finite-number constraints;
- authenticated player and immutable party/eligibility identity;
- party role and authoritative phase/state transition;
- registered object identity plus live server distance/line-of-context where physical;
- server-configured price/reward/result rather than client values;
- server-generated operation ID and replay rejection for every value-bearing change;
- per-action rate/expense budget;
- feature-flag dependency and production-debug isolation; and
- structured rejection reason without leaking secrets.

## Priority remediation and execution order

1. Close the published lobby launch/ticket/reconnect gate; static source is not enough.
2. Execute isolated persistence, retry, reconnect, concurrent-server, and full
   regression tests for the now-journaled Milestone 1 value paths. Require
   operation IDs for every future penalty, survival, discovery, statistic, and
   ending operation before those features activate.
3. Execute the new front/patio/garage/bunker prompt guards under multi-client flood, distance spoof, reset/death, obstruction, and automation timing; source validation is complete but runtime evidence is not.
4. Build automated malformed-payload, NaN/infinity, large-string/table, arbitrary-instance, replay, and flood tests for every client-to-server row.
5. Run `verify_production_build_surface.luau` against a published private candidate and actively probe guessed debug/scenario names.
6. Do not add Milestone 2 remotes until Milestone 1 is closed and every new action has a row in this matrix before implementation.
