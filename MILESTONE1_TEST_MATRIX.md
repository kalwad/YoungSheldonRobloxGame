# Milestone 1 verification matrix

This is the release gate for the **Lobby and Co-op Foundation** in `PLAN.md`.
It is intentionally a checklist, not a claim that live tests have passed. Add a
dated evidence link, capture, or log beside every row before changing its
status to `PASS`. `PARTIAL` means the recorded Studio evidence covers only part
of the row and does not satisfy its remaining live or topology requirement.

## Fixed contracts

- Party size: 1–4 invited players; no public matchmaking.
- Lobby/start place: `100748614383412`.
- Reserved Cooper house place: `98645411943406`.
- Both places remain in universe `10480337589`; the house capacity is exactly
  four, while the lobby supports at least four players and should target 50.
- One shared five-task sequence. Any eligible member can advance the active
  task. Reward eligibility is an immutable server-owned snapshot captured when
  the task begins, and every eligible member earns the reward exactly once.
- The host owns the physical house state and is the only player allowed to buy
  persistent world upgrades.
- Host loss pauses progression for 60 seconds. A valid host rejoin resumes the
  same session; timeout saves everyone and returns remaining members to lobby.
- Walk/sprint/stamina: `16 / 22 / 6 seconds`. The stamina HUD is hidden while
  full and idle.
- Only `Lobby` is enabled. Horror, secrets, finale, postgame, and production
  scenario tools remain disabled.

## Carried-forward Studio evidence — 2026-07-22

Candidate commits: `f31c0cd` + `14932d7`.

- Root cause reproduced: one shared request timestamp rejected a valid Launch
  immediately after Ready as `Please wait a moment`.
- The lobby now uses per-action gaps plus a five-token/two-per-second burst
  budget. A clean runtime accepted Create Party → Ready → Launch with the Ready
  commit and Launch preflight 50 ms apart.
- Server responses now expose typed `selfReady`, `partyRevision`, and explicit
  launch-block reason text. The client does not parse captions to infer state.
- Launch is atomically locked, diagnostics are allowlisted and secret-safe, and
  stale rollback can only alter its own session/reconnect records.
- That Milestone 1 lobby edit audit passed `316` checks. No
  current-working-tree screenshot or physical-device/mobile visual acceptance
  is claimed.
- The lobby environment is now a warm 1980s suburban rec room. Its updater is
  scoped and idempotent and cannot clear Workspace, Terrain, replicated data,
  StarterGui, or runtime scripts.
- No new version was published. Studio now opens an inert, verified Cooper House
  package inside the same playtest after authoritative party validation. The
  published reserved-server rows remain open because this path never exercises
  TeleportService, MemoryStore, live tickets, or production DataStores.
- The exact final flow was Create Party → `SetReady true` → zero-delay Launch.
  The authoritative responses arrived in order as `READY_COMMITTED` and then
  `STUDIO_HOUSE_STARTED`.
- The first run exposed 200-register startup failures in `CooperGame` and
  `CooperBunker`; the missing core events reported by `CooperTaskWorld` were a
  downstream cascade. After repair, the full compiler-register matrix passed
  `27/27` (`O0`/`O1`/`O2` × `g0`/`g1`/`g2` across all three core servers), and
  a clean fresh run reported `RuntimeStartupReadiness PASS`.
- A second fresh `PlaySolo` run again returned `STUDIO_HOUSE_STARTED` with
  authoritative `selfReady = true` and `canLaunch = true`; startup readiness
  passed again. Server and client startup logs contained no project
  errors/warnings (only the external Studio MCP version-mismatch warning).
- That carried-forward preview passed `71` edit checks and `118`
  active-runtime checks.
  Runtime state was schema `12` / `PartyV1`, with a loaded `Active` host, all
  four core remotes, ready world and automation controllers, exactly George,
  Georgie, Mary, and Missy, and every future feature flag still false.
- A sustained client-side Humanoid movement command covered `24.68` studs at
  `WalkSpeed = 16`, with a normal camera and no `PlatformStand`. This does not
  replace a current-candidate keyboard/touch input test.
- The prompt-security verifier passed `124` checks. Published prompt abuse,
  flooding, proximity manipulation, and multiplayer contention remain unrun.
- An idle profiler sample measured a maximum server script share of `1.68%`
  (`CooperYardRideables`); the largest client entry was external/core and below
  `0.8%`. This is not mobile, multiplayer, active-feature, or soak evidence.

## Current local candidate evidence — 2026-07-23

The working tree is based on `f823103` and is not published. Its local
deterministic/static evidence passed, but its new source changes must not inherit
the Studio, screenshot, or live evidence above until those scenarios are rerun.

- `bash tools/verify_milestone1_local.sh` passed all eight phases: `140` sources
  compiled, static analysis passed, deterministic contracts passed `130/130`,
  compiler-register profiles passed `27/27`, `git diff --check` passed, frozen
  configuration and value-operation markers matched, 13 active clients passed
  the authority scan, and disabled/retired runtime surfaces stayed absent.
- New deterministic scenarios cover one-use tickets, Ready/Start ordering,
  double-Start, synchronous and asynchronous bounded same-reservation teleport
  retries, exact host-grace boundaries, sprint, same-frame two-client
  completion, reward retry reconciliation, and boombox missed-tick/save/race
  settlement. These fakes are not published service or multi-client proof.
- Candy lifecycle, indexed boombox payout ticks, exact completed-playback
  boombox settlement, and paid physical install transitions now have stable
  server-owned persistent operation identities. A completed playback settles
  to exactly `$300` without duplicate overpayment. Broad `AdjustCurrency` and
  `SpendAllowance` routes are retired.
- Three read-only current-candidate Studio audits now compile:
  `verify_milestone1_value_operations.luau`,
  `verify_milestone1_remote_inventory.luau`, and
  `verify_ui_accessibility_static.luau`. They remain **NOT RUN** in Studio and a
  published client for this candidate.

## Automated contract checks

| ID | Check | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| A01 | Compile every local `.luau` source | No compile errors | PASS | 2026-07-23 local gate: default `luau-compile` passed 140/140 sources |
| A02 | `git diff --check` | No whitespace errors | PASS | 2026-07-23 local gate: exited 0 with no findings |
| A03 | Run `verify_milestone1_foundation.luau` in house edit mode | PASS | NOT RUN | Historical 2026-07-22 house evidence passed 530 checks, but the current schema-12 candidate was not installed into or rerun in the separate house place |
| A04 | Run verifier in a one-player house runtime | PASS | NOT RUN | Historical 2026-07-22 house evidence passed 616 checks and the carried-forward candidate used the explicitly non-production Studio preview adapter; the latest working tree has not run in Studio |
| A05 | Run verifier in lobby edit mode | PASS | NOT RUN | Carried-forward candidate passed 316 checks; rerun after installing the current local source map |
| A06 | Run verifier in a lobby runtime | PASS | NOT RUN | Carried-forward zero-delay Ready/Launch and startup-readiness evidence exists; the current local candidate has not run the complete lobby-runtime verifier |
| A07 | Run every Milestone 0 gameplay regression suite | No regressions except intentional M1 source/cap contracts | NOT RUN | |
| A08 | Client-authority scan | No client cash awards, task completion, host selection, or story forcing | PASS | 2026-07-23 local gate: all 13 active client sources scanned; no forbidden authority pattern |
| A09 | Studio in-place house verifier | Preview package and safety guards pass before launch; normal house/remotes/scripts/profile pass after launch | NOT RUN | Carried-forward candidate passed 71/71 edit and 118/118 active-runtime checks; rerun after current source sync |
| A10 | Core compiler register preflight and fresh startup readiness | Default plus register-pressure profiles compile; core authorities reach fresh runtime markers | PARTIAL | Current local `verify_runtime_register_budget.sh` passed 27/27; the two clean `RuntimeStartupReadiness PASS` runs belong to the carried-forward Studio candidate and must be rerun |
| A11 | Deterministic contract suite | Every local contract test passes | PASS | 2026-07-23: `luau tests/run.luau` passed 130/130 |
| A12 | Physical-prompt source/runtime guard audit | Every required prompt guard is present | PARTIAL | Carried-forward `verify_prompt_security_guards.luau` passed 124 checks; current-candidate Studio and published adversarial abuse remain open |
| A13 | Current value-operation audit in Studio edit/runtime | Candy, boombox ticks and exact `$300` settlement, paid installs, and retired broad APIs match the journal contract | NOT RUN | `verify_milestone1_value_operations.luau` compiles; its corresponding deterministic identities and settlement fault/race cases pass locally, but no current Studio result is recorded |
| A14 | Complete remote/prompt/server-boundary inventory in Studio and published candidate | Inventory matches allowlists; production debug surfaces are absent | NOT RUN | `verify_milestone1_remote_inventory.luau` compiles; published malformed-payload/replay/flood probes remain separate required evidence |
| A15 | UI accessibility audit in edit and client runtime | Safe-area, touch-target, contrast, scrolling, close/back, selection, and status contracts pass | NOT RUN | `verify_ui_accessibility_static.luau` compiles; it makes no aesthetic, physical-hardware, localization, or published-client claim |
| A16 | Repeatable local Milestone 1 gate | All eight CLI/static phases pass | PASS | `bash tools/verify_milestone1_local.sh`: 140 compile, analyzer clean, 130/130 deterministic, 27/27 register, 13 active client authority scans, clean diff/config/value/disabled-surface phases |

## Lobby UI and Studio interaction checks

These rows verify the lobby itself. They do not prove a real reserved-server
handoff, Roblox friend invitation, or physical-device touch behavior.

| ID | Check | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| L01 | Play Solo in Studio | Validated party opens a playable in-place house without production teleport or saved authority | NOT RUN | Carried-forward candidate passed; current server source has not been rerun |
| L02 | Create Party | Host party is created and controls update | NOT RUN | Carried-forward candidate passed; current server source has not been rerun |
| L03 | Ready and cancel ready | Text/state toggles correctly in both directions | PARTIAL | Typed/revisioned state and zero-delay ordering pass deterministically; carried-forward Studio passed, but current server source has not been rerun |
| L04 | Host Launch in Studio | In-place house handoff only; no reserved server, MemoryStore, live ticket, or production DataStore authority | NOT RUN | Carried-forward runtime returned `STUDIO_HOUSE_STARTED`; current server source has not been rerun |
| L05 | Leave Party | Party UI returns to the no-party state | NOT RUN | Carried-forward candidate passed; current server source has not been rerun |
| L06 | Responsive simulated layouts | Desktop, small phone portrait/landscape, modern phone, Android landscape, and tablet fit and scroll | PASS | Final captures: iPhone 7 portrait/landscape, iPhone 13 portrait, Galaxy A16 landscape, iPad 6 landscape, and desktop |
| L07 | Lobby movement presentation | Scriptable movement prevents mobile joystick/jump controls covering UI | PASS | Confirmed in simulated mobile layouts |
| L08 | Physical phone/tablet interaction | Touch, safe areas, keyboard opening, and rotation work on real hardware | NOT RUN | Simulator evidence is not a physical-device test |
| L09 | Fresh lobby client initialization | Runtime stays stable without forcing global GUI selection; ordinary selectable buttons still work | PASS | Removed automatic `GuiService.SelectedObject` writes that crashed current Studio; fresh runtime stayed stable and every button flow passed; exported/published in v308 |
| L10 | Movement after Studio handoff | First-play tutorial owns its intentional modal lock; closing it restores normal camera and movement | NOT RUN | Carried-forward candidate moved normally after handoff; current source map and handoff must be rerun |

## Party and teleport tests

TeleportService cannot exercise a real cross-place reserved-server launch in a
Studio playtest. Rows marked **live** must run from a privately published test
version in the Roblox client; do not substitute a Studio-only mock.

The deterministic coordinator proves that either one synchronous
teleport-request failure or one asynchronous `TeleportInitFailed` callback can
consume the same single retry budget using the original reservation, manifest,
tickets, options, and launch token. Duplicate or stale callbacks cannot create
a third request. Every row below remains live-only.

| ID | Topology | Procedure | Expected | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| P01 | Solo, live | Launch without creating a party | Immediate reserved house launch; player is host | NOT RUN | Browser could not hand off to the installed Roblox Player; Studio safe-preview is not a substitute |
| P02 | 2 players, live | Host invites friend; friend accepts and readies; host launches | Exactly two admitted members; both see the same session/task | NOT RUN | |
| P03 | 4 players, live | Invite and ready three friends | Exactly four admitted members; server never exceeds four | NOT RUN | |
| P04 | 4 players, live | Attempt a fifth invite/join | Server rejects it without changing the party | NOT RUN | |
| P05 | 2 players, live | Launch while guest is not ready | Launch is rejected with clear feedback | NOT RUN | |
| P06 | 2 players, live | Guest attempts to launch | Request is rejected; host/party state unchanged | NOT RUN | |
| P07 | Live | Replay an already consumed admission ticket | Admission fails closed; no duplicate party member | NOT RUN | |
| P08 | Live | Join house with missing, expired, altered, or nonmember teleport data | Admission fails closed and safely returns/rejects player | NOT RUN | |
| P09 | Source/network inspection | Inspect client teleport payload and replicated state | Reserved-server access code is never exposed | NOT RUN | |
| P10 | Live | Two parties launch at the same time | Different reserved servers and isolated manifests | NOT RUN | |
| P11 | Live | A duplicate/concurrent connection reaches the house for an already-active user | The valid active player stays authoritative; the rejected arrival cannot replace their session entry | NOT RUN | |

## Shared task and reward tests

Run T01–T11 at both two-player and four-player topology. Start from controlled
fresh balances and record every player’s before/after allowance and lifetime
task count.

| ID | Procedure | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| T01 | Guest completes George beer | One shared advance; every present member gets `$55` once | PARTIAL | Controlled 4-client Studio house: guest completed it and all four received exactly `$55`; 2-player and live coverage remain |
| T02 | Different guest completes dishes | One shared advance; every present member gets `$30` once | NOT RUN | |
| T03 | Host starts trash; guest delivers it | One shared advance; every present member gets `$40` once | NOT RUN | |
| T04 | Guest finds/returns Missy’s toy | One shared advance; every present member gets `$70` once | NOT RUN | |
| T05 | Guest completes bank memory game | One shared advance; every present member gets the authoritative cycle reward once | NOT RUN | |
| T06 | Two clients submit the final interaction simultaneously | Idempotency token accepts one completion only | PARTIAL | Controlled 4-client Studio duplicate was rejected; the deterministic two-client same-frame scenario also advances once, pays each eligible member once, and deduplicates fail-after-write retry. Published contention remains |
| T07 | An original expected guest finishes initial admission after a task began | The immutable snapshot does not change; that guest becomes eligible only for later tasks | NOT RUN | |
| T08 | Snapshot-eligible guest disconnects before completion | The retained identity is paid once if commit occurs inside the 90-second grace; otherwise it is explicitly forfeited at the exact boundary | NOT RUN | |
| T09 | Complete a full five-task cycle | Shared cycle/index advances once and remains identical on all snapshots | NOT RUN | |
| T10 | Repeat with every installed task robot | The existing authoritative acceptance point advances the shared task once; the physical run stays visible and party rewards never duplicate | NOT RUN | |
| T11 | Complete a task while one expected guest profile is still hydrating | The loading guest is excluded by DEC-02, the frozen roster never changes, and the UI does not imply an unavailable reward | NOT RUN | |

## Host authority and persistence tests

For every rejected guest request, verify allowance, entitlement, pending
delivery, physical model, and DataStore revision remain unchanged.

| ID | Guest attempts | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| H01 | Buy next Time Machine stage | Rejected; no debit or delivery | PASS | Controlled 4-client Studio test: guest request rejected with no allowance or world-state change |
| H02 | Buy secret bunker | Rejected; no debit or construction | NOT RUN | |
| H03 | Buy boombox or autoplay | Rejected; no debit or delivery | NOT RUN | |
| H04 | Buy any task robot | Rejected; no debit or delivery | NOT RUN | |
| H05 | Buy chemistry setup | Rejected; no debit or delivery | NOT RUN | |
| H06 | Host performs H01–H05 with sufficient cash | Each purchase follows its existing paid/delivery contract once | PARTIAL | Host Blueprint Bench purchase charged only host and replicated one delivery; boombox, robots, bunker, and chemistry remain untested here |
| H07 | Guest leaves/rejoins later as host of a new party | Guest retained personal cash/stats but did not inherit old host upgrades | NOT RUN | |
| H08 | Host leave/rejoin and server shutdown | All paid pending deliveries and existing M0 progression survive | NOT RUN | |

## Host disconnect state machine

| ID | Procedure | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| D01 | Host disconnects with guests present | Shared task/purchases pause immediately; 60-second deadline is advertised | PASS | Controlled 4-client Studio test entered `HostGrace` with approximately 60 seconds remaining |
| D02 | Guest interacts during grace | No task advance, reward, purchase, delivery mutation, or robot deadline loss | PARTIAL | Guest action was rejected with no cash or task mutation; in-flight delivery and robot-deadline variants remain open |
| D03 | Host rejoins at approximately 30 seconds | Same host/session resumes once; no reward replay | NOT RUN | |
| D04 | Host rejoins at approximately 59 seconds | Valid ticket resumes before expiry | NOT RUN | |
| D05 | Host does not rejoin | At expiry, profiles save and remaining members return to lobby | PARTIAL | Studio timeout reached `Closing` and set return-request state; real DataStore save and lobby teleport remain live-only |
| D06 | Forged/non-host rejoin ticket during grace | Rejected; grace remains active | NOT RUN | |
| D07 | Server closes during grace | Shutdown path saves every loaded profile and releases leases | NOT RUN | |
| D08 | Host disconnects while their profile is still hydrating | No default-profile takeover or stuck `Loading`; durable data remains authoritative | NOT RUN | |
| D09 | Host disconnects after a session has run longer than one hour | A fresh 60-second rejoin route still works, or a documented session cap ends the party beforehand | NOT RUN | |
| D10 | Last guest leaves while the host is disconnected | Retained host data saves, its lease releases, the manifest closes, and no empty-server lease lingers | NOT RUN | |
| D11 | Host reconnects with a paid delivery already pending | Same paid item resumes/replays once; it is neither lost nor duplicated | NOT RUN | |
| D12 | A guest is in a bank pattern when host grace starts | Pattern/deadline freezes or resets fairly; rejected input during grace cannot cause an unavoidable failure | NOT RUN | |
| D13 | Force a MemoryStore `UpdateAsync` callback retry while consuming a ticket | Only the final returned claim can admit; stale closure state never validates a replay | NOT RUN | |
| D14 | Invalidate the host profile lease while guests remain | Shared completion and purchases fail closed; party enters a safe save/close or recovery state | NOT RUN | |
| D15 | Guest carries beer, trash, or Missy's toy when the host disconnects; attempt the drop/return and allow an in-flight beer truck callback during grace | Task prompts and delivery acknowledgements are inert while paused; no tool, crate, refrigerator, toy, or shared-task mutation occurs; the same task resumes after host rejoin | NOT RUN | |

## Sprint and mobile controls

Run desktop rows with keyboard and gamepad where applicable. Run mobile rows on
phone portrait, phone landscape, and tablet landscape safe-area presets, plus
at least one physical touch device.

| ID | Procedure | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| S01 | Hold left/right Shift while moving | Server speed is 22; release returns to 16 | PASS | Solo house runtime verified server speed `22` while sprinting and `16` after release |
| S02 | Hold sprint while stationary | Stamina does not drain without movement | PARTIAL | Deterministic server-rule test passes; current-candidate runtime/input test remains open |
| S03 | Sprint continuously | Approximately six seconds to exhaustion; cannot bypass server limit | PARTIAL | Historical solo runtime observed drain; deterministic server-rule test reaches exhaustion at six moving seconds. Published exploit/input testing remains open |
| S04 | Release and recover | Gradual regeneration; sprint becomes available predictably | PARTIAL | Deterministic server-rule test proves the 0.8-second delay and 1.5-per-second recovery; runtime/UI behavior remains open |
| S05 | Full and idle | Stamina UI is not visible | NOT RUN | |
| S06 | Drain/recover | UI appears while used or recovering, then hides at full | NOT RUN | |
| S07 | Touch button | Button is reachable inside safe area and its tap-on/tap-off state is clear and reliable | NOT RUN | |
| S08 | Open computer/bunker terminal or sit | Sprint is denied and movement lock/seat state wins | PARTIAL | Computer exit cleared its movement lock and `W` moved about 8 studs at speed 16; bunker and seat variants remain open |
| S09 | Carry an item | Existing carry multiplier composes with server movement; no speed exploit | NOT RUN | |
| S10 | Respawn/reset while sprinting | State, humanoid speed, attributes, input, and UI restore cleanly | PARTIAL | Deterministic server-rule test restores full isolated character state; Roblox respawn/UI/input integration remains open |
| S11 | Spam intent remote / locally alter WalkSpeed | Server rate limit and authoritative loop restore valid state | PARTIAL | Deterministic server-rule tests correct local speed edits and prevent negative/stacked state under toggle spam; published remote abuse remains open |
| S12 | Four-player sprint isolation | One player's sprint/stamina state cannot alter another player's state | PASS | Controlled 4-client Studio house verified per-player isolation |

## Regression and release checks

| ID | Check | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| R01 | Four normal PNG NPCs | Only George, Mary, Missy, Georgie; original art/dialogue/catchphrases | PARTIAL | Carried-forward preview runtime roster was exactly George, Georgie, Mary, and Missy; the latest working tree plus original PNG appearance, dialogue, and catchphrases were not re-certified |
| R02 | Five tasks, robots, deliveries, boombox, bank, bunker, chemistry, candy | Existing mechanics complete without errors | NOT RUN | |
| R03 | Doors, truck, furniture, robots and players under four-player load | No phasing, blocking deadlocks, or void spawn | NOT RUN | |
| R04 | Horror/runtime object audit | No panic/crisis/progression/horror UI or behavior | PARTIAL | Current local gate keeps Horror, SecretExploration, TimeMachineFinale, Postgame, and StudioScenarioTools false and excludes retired surfaces; current-candidate runtime object audit remains open |
| R05 | Client/server logs through all scenarios | No project warnings or errors | PARTIAL | Two fresh carried-forward Studio startup runs had no project warnings/errors; only the external Studio MCP version-mismatch warning remained. The latest working tree has not run in Studio, and full feature/multiplayer logs remain open |
| R06 | Creator Dashboard | Lobby `100748614383412` is the start place with capacity at least 4 (50 recommended); house `98645411943406` is non-start and capped exactly at 4 | PASS | Dashboard verified: lobby start/cap 50; house cap 4 and `Secure` within-universe access only |
| R07 | Rollback | Dated exports and Git restore instructions recover Milestone 0 | PARTIAL | Historical rollback sets remain documented; the 668659-byte export with SHA-256 `09dc971d4f534c34c369d82455a7bac026ec6bc7342d0d3ec2cbcf91a5a2fb7a` predates the current local closure and is not its final verified export |
| R08 | Runtime performance | Ordinary and stress scenarios stay inside approved budgets | PARTIAL | Idle Studio sample: server max 1.68% (`CooperYardRideables`), client external/core max below 0.8%; active gameplay, mobile, four-player, and soak profiling remain open |

The current source and deterministic suite now assign stable server-owned
operation identities to every enumerated Milestone 1 reward, payout, purchase,
and paid physical install transition, while broad legacy currency routes fail
closed. Global exactly-once **release assurance remains open** until isolated
DataStore fail-before/fail-after-write, concurrent-server, disconnect/rejoin,
published multiplayer, and every full-regression value path pass.

## Sign-off

Milestone 1 passes only when every required row is `PASS`, evidence is attached,
and no progression loss, duplicated money, stuck movement, void spawning,
incorrect NPC art, or restoration error remains. Milestone 2 must stay disabled
until this gate is complete.
