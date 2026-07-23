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

## Ready/Start and visual closure evidence — 2026-07-22

- Root cause reproduced: one shared request timestamp rejected a valid Launch
  immediately after Ready as `Please wait a moment`.
- The lobby now uses per-action gaps plus a five-token/two-per-second burst
  budget. A clean runtime accepted Create Party → Ready → Launch with the Ready
  commit and Launch preflight 50 ms apart.
- Server responses now expose typed `selfReady`, `partyRevision`, and explicit
  launch-block reason text. The client does not parse captions to infer state.
- Launch is atomically locked, diagnostics are allowlisted and secret-safe, and
  stale rollback can only alter its own session/reconnect records.
- `verify_lobby_launch_repair.luau` passed 32/32 checks in edit mode and 32/32
  in runtime. `verify_milestone1_foundation.luau` passed 237 edit-mode and 281
  runtime lobby checks after the final scoped visual update.
- The responsive CRT UI was inspected at desktop, iPhone 7 portrait/landscape,
  iPhone 13 portrait, Galaxy A16 landscape, and iPad 6 landscape. All layouts
  remained legible and scrollable; keyboard/gamepad focus activated Ready and
  Start successfully. This remains simulator evidence, not physical hardware.
- The lobby environment is now a warm 1980s suburban rec room. Its updater is
  scoped and idempotent and cannot clear Workspace, Terrain, replicated data,
  StarterGui, or runtime scripts.
- No new version was published. Studio now opens an inert, verified Cooper House
  package inside the same playtest after authoritative party validation. The
  published reserved-server rows remain open because this path never exercises
  TeleportService, MemoryStore, live tickets, or production DataStores.
- The final Create Party → Ready → Start run removed the lobby world/UI, loaded
  the normal house HUD and all twelve verified LocalScripts, and passed 63 edit
  plus 108 active-runtime preview checks. After the normal first-play `START
  BUILDING` tutorial was dismissed, held-W input moved the character about 26
  studs. Project logs had no errors or warnings; the only warning came from an
  external Studio MCP plugin/server version mismatch.

## Automated contract checks

| ID | Check | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| A01 | Compile every local `.luau` source | No compile errors | PASS | 2026-07-22 Studio handoff closure: `luau-compile` passed 82/82 local sources; all 66 non-retired sources also passed |
| A02 | `git diff --check` | No whitespace errors | PASS | 2026-07-22: exited 0 with no findings |
| A03 | Run `verify_milestone1_foundation.luau` in house edit mode | PASS | PASS | 2026-07-22 final house: 530 read-only checks passed |
| A04 | Run verifier in a one-player house runtime | PASS | PASS | 2026-07-22 final house runtime: 616 checks passed |
| A05 | Run verifier in lobby edit mode | PASS | PASS | 2026-07-22 launch/UI closure: 237 foundation checks plus 32 launch-repair checks passed |
| A06 | Run verifier in a lobby runtime | PASS | PASS | 2026-07-22 clean runtime: 281 foundation checks plus 32 launch-repair checks passed |
| A07 | Run every Milestone 0 gameplay regression suite | No regressions except intentional M1 source/cap contracts | NOT RUN | |
| A08 | Client-authority scan | No client cash awards, task completion, host selection, or story forcing | PASS | 2026-07-22: all 13 active local client sources scanned; no forbidden authority pattern |
| A09 | Studio in-place house verifier | Preview package and safety guards pass before launch; normal house/remotes/scripts/profile pass after launch | PASS | 63/63 edit checks and 108/108 active-runtime checks |

## Lobby UI and Studio interaction checks

These rows verify the lobby itself. They do not prove a real reserved-server
handoff, Roblox friend invitation, or physical-device touch behavior.

| ID | Check | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| L01 | Play Solo in Studio | Validated party opens a playable in-place house without production teleport or saved authority | PASS | Exact keyboard-activated Create Party → Ready → Start flow replaced lobby with verified house runtime |
| L02 | Create Party | Host party is created and controls update | PASS | Final lobby interaction test |
| L03 | Ready and cancel ready | Text/state toggles correctly in both directions | PASS | Reproduced and repaired; typed server state remained stable through rerenders, Ready/cancel worked, and zero-delay regression passed |
| L04 | Host Launch in Studio | In-place house handoff only; no reserved server, MemoryStore, live ticket, or production DataStore authority | PASS | Runtime returned `STUDIO_HOUSE_STARTED`; lobby GUI/world disappeared and normal house systems loaded |
| L05 | Leave Party | Party UI returns to the no-party state | PASS | Final lobby interaction test |
| L06 | Responsive simulated layouts | Desktop, small phone portrait/landscape, modern phone, Android landscape, and tablet fit and scroll | PASS | Final captures: iPhone 7 portrait/landscape, iPhone 13 portrait, Galaxy A16 landscape, iPad 6 landscape, and desktop |
| L07 | Lobby movement presentation | Scriptable movement prevents mobile joystick/jump controls covering UI | PASS | Confirmed in simulated mobile layouts |
| L08 | Physical phone/tablet interaction | Touch, safe areas, keyboard opening, and rotation work on real hardware | NOT RUN | Simulator evidence is not a physical-device test |
| L09 | Fresh lobby client initialization | Runtime stays stable without forcing global GUI selection; ordinary selectable buttons still work | PASS | Removed automatic `GuiService.SelectedObject` writes that crashed current Studio; fresh runtime stayed stable and every button flow passed; exported/published in v308 |
| L10 | Movement after Studio handoff | First-play tutorial owns its intentional modal lock; closing it restores normal camera and movement | PASS | `START BUILDING` closed, PlayerModule controller enabled, WalkSpeed remained 16, and held-W moved about 26 studs |

## Party and teleport tests

TeleportService cannot exercise a real cross-place reserved-server launch in a
Studio playtest. Rows marked **live** must run from a privately published test
version in the Roblox client; do not substitute a Studio-only mock.

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
| T06 | Two clients submit the final interaction simultaneously | Idempotency token accepts one completion only | PARTIAL | Controlled 4-client Studio test: duplicate completion returned false with no second reward; live contention remains |
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
| S02 | Hold sprint while stationary | Stamina does not drain without movement | NOT RUN | |
| S03 | Sprint continuously | Approximately six seconds to exhaustion; cannot bypass server limit | PARTIAL | Stamina drain verified in solo runtime; exact six-second exhaustion and exploit attempt remain open |
| S04 | Release and recover | Gradual regeneration; sprint becomes available predictably | NOT RUN | |
| S05 | Full and idle | Stamina UI is not visible | NOT RUN | |
| S06 | Drain/recover | UI appears while used or recovering, then hides at full | NOT RUN | |
| S07 | Touch button | Button is reachable inside safe area and its tap-on/tap-off state is clear and reliable | NOT RUN | |
| S08 | Open computer/bunker terminal or sit | Sprint is denied and movement lock/seat state wins | PARTIAL | Computer exit cleared its movement lock and `W` moved about 8 studs at speed 16; bunker and seat variants remain open |
| S09 | Carry an item | Existing carry multiplier composes with server movement; no speed exploit | NOT RUN | |
| S10 | Respawn/reset while sprinting | State, humanoid speed, attributes, input, and UI restore cleanly | NOT RUN | |
| S11 | Spam intent remote / locally alter WalkSpeed | Server rate limit and authoritative loop restore valid state | NOT RUN | |
| S12 | Four-player sprint isolation | One player's sprint/stamina state cannot alter another player's state | PASS | Controlled 4-client Studio house verified per-player isolation |

## Regression and release checks

| ID | Check | Expected | Status | Evidence |
| --- | --- | --- | --- | --- |
| R01 | Four normal PNG NPCs | Only George, Mary, Missy, Georgie; original art/dialogue/catchphrases | NOT RUN | |
| R02 | Five tasks, robots, deliveries, boombox, bank, bunker, chemistry, candy | Existing mechanics complete without errors | NOT RUN | |
| R03 | Doors, truck, furniture, robots and players under four-player load | No phasing, blocking deadlocks, or void spawn | NOT RUN | |
| R04 | Horror/runtime object audit | No panic/crisis/progression/horror UI or behavior | PASS | Final house edit/runtime and lobby edit/runtime verifiers passed with all future features except Lobby disabled |
| R05 | Client/server logs through all scenarios | No project warnings or errors | PARTIAL | Final lobby runtime had no project warnings/errors; only external Studio MCP `2.22.3/2.22.0` mismatch warning. Full house regression logs remain open |
| R06 | Creator Dashboard | Lobby `100748614383412` is the start place with capacity at least 4 (50 recommended); house `98645411943406` is non-start and capped exactly at 4 | PASS | Dashboard verified: lobby start/cap 50; house cap 4 and `Secure` within-universe access only |
| R07 | Rollback | Dated exports and Git restore instructions recover Milestone 0 | PASS | Pre-M1 and verified house/lobby `.rbxm` sets, SHA-256 hashes, and restoration procedures are recorded |

## Sign-off

Milestone 1 passes only when every required row is `PASS`, evidence is attached,
and no progression loss, duplicated money, stuck movement, void spawning,
incorrect NPC art, or restoration error remains. Milestone 2 must stay disabled
until this gate is complete.
