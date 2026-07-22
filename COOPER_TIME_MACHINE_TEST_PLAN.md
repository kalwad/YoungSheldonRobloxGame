# Cooper Time Machine — Comprehensive Test Plan

**Source:** `PLAN.md` (Cooper Time Machine — Complete Development Roadmap)  
**Prepared for:** Codex-assisted implementation and human QA  
**Baseline date:** 2026-07-22  
**Scope:** Functional, integration, multiplayer, persistence, security, recovery, accessibility, performance, streaming, asset, and release testing for Milestones 0–9.

---

## 1. Purpose

This plan converts the roadmap into a verifiable production process. It is intentionally stricter than “play for a few hours and see whether it works.” A normal playthrough proves the happy path for one player and one sequence of events; this plan targets races, invalid states, interrupted flows, old saves, malicious clients, low-memory devices, mixed party choices, and failures between steps.

The test system must answer five questions for every feature:

1. Does the isolated logic produce the correct result?
2. Does the feature work when connected to the real game state?
3. Does it remain correct with 1–4 players acting at the same time?
4. Does it recover without duplication or progression loss when interrupted?
5. Does it remain playable, secure, understandable, and performant on the supported devices?

This document reviews the requirements in `PLAN.md`; it does not certify the current codebase because the source code was not included.

---

## 2. Test Policy

### 2.1 Mandatory rules

- No milestone advances merely because its main path works once.
- Every production defect receives a regression test before or with the fix whenever the behavior can be automated.
- Critical economy, persistence, party, and story transitions must be idempotent: retrying the same operation cannot duplicate cash, rewards, purchases, progression, ending credit, or statistics.
- Automated tests must assert externally observable behavior and state invariants, not copy the implementation line-for-line.
- Codex must not weaken assertions, delete failing tests, insert arbitrary waits, or change production behavior solely to make a test pass without documenting the underlying defect.
- Random behavior must be testable with an injected deterministic seed or random source.
- Timer behavior must be testable with an injected clock; the suite must not wait through real 90–300 second deadlines.
- Studio scenario controls must be unreachable in any published production server, even if an exploiter manually fires guessed remotes.
- Test DataStores, reserved servers, badges/credits, and teleports must use a private test experience or isolated namespace, never live player data.

### 2.2 Test result states

- **PASS:** Expected state, presentation, persistence, and logs all match.
- **FAIL:** A requirement is violated or an invariant breaks.
- **BLOCKED:** The test cannot run because a required design decision, asset, environment, or API adapter is missing.
- **NOT RUN:** Scheduled but not executed.
- **ACCEPTED RISK:** Only allowed with a written owner, reason, player impact, workaround, and expiration milestone.

### 2.3 Severity

| Severity | Definition | Examples | Release rule |
|---|---|---|---|
| S0 — Data/security critical | Corrupts or duplicates persistent value, permits arbitrary server state changes, exposes production-only controls, or strands an entire party | Cash duplication, profile overwrite, client forces ending, test remote active in production | Zero open |
| S1 — Progression blocker | Prevents completion, traps players, loses progression, breaks host/party lifecycle, or leaves the world unrestored | Stuck in cinematic, host return fails, hunter remains scary after encounter | Zero open |
| S2 — Major | Materially harms fairness, multiplayer consistency, accessibility, performance, or a major feature | Wrong player rewarded, deadline runs during loading, mobile HUD covers prompts | Zero open for milestone gate unless explicitly deferred |
| S3 — Minor | Visible defect with a workaround and no progression/data impact | Small animation pop, noncritical alignment issue | May ship only if tracked |
| S4 — Cosmetic | Presentation-only issue with negligible impact | Minor spacing, subtle effect mismatch | Product decision |

---

## 3. Blocking Design Decisions Before Full Automation

Codex should create tests marked **BLOCKED** until these decisions are resolved. Guessing would encode accidental behavior as a permanent contract.

### DEC-01 — Individual ending choice versus host-owned world

The roadmap says the host’s upgrades control the world, the host’s departure triggers a 60-second shutdown path, and each player makes an individual ending choice. Define what happens when the host chooses **Stay in reality** while one or more guests choose **Return to the simulation**. Recommended rule: each returning player is sent to a new private session based on that player’s own house profile; nobody continues using an absent host’s world.

### DEC-02 — Reward and penalty eligibility

Define “present player” at a single authoritative snapshot point for:

- task rewards;
- survival bonuses;
- capture penalties;
- ending credit;
- players joining mid-task or mid-encounter;
- players disconnected but inside a reconnect grace period;
- dead or respawning players;
- bunker occupants;
- AFK players.

Recommended rule: create an immutable eligibility set when the task or encounter starts, then remove only players who permanently leave; rejoining with the same session membership must not create a second eligibility record.

### DEC-03 — Save checkpoints and resumable state

Define which states persist and which restart safely after server loss. At minimum decide behavior for shutdown during:

- an active task;
- a concurrent robot job;
- the first-reveal cinematic;
- an active hunt;
- a machine purchase/install;
- black-hole launch;
- the studio route;
- credits;
- final-choice submission.

Recommended rule: persist durable checkpoints, not transient presentation state. On rejoin, resume at the nearest safe checkpoint and never in darkness, camera lock, hidden-player mode, or a partially paid transaction.

### DEC-04 — Guest reconnect policy

The roadmap specifies a host grace period but not a guest grace period. Define whether a guest may rejoin the reserved session, whether deadlines pause for guest loss, and whether the guest remains reward-eligible.

### DEC-05 — Host loss in special phases

Define host loss separately for lobby, ordinary tasks, horror, machine ready check, launch cinematic, studio route, final choice, and postgame. A single blanket 60-second pause is unlikely to fit every phase.

### DEC-06 — Finale topology

State whether the Blender studio and future apartment are:

- streamed regions in the house place;
- separate places in the same experience; or
- a hybrid.

This affects streaming, teleport testing, party separation, reconnection, data checkpoints, and mixed ending choices.

### DEC-07 — Performance support floor

“Supported mobile devices” is not measurable. Record a minimum test-device class and budgets for:

- client frame time/FPS;
- server frame time;
- client memory;
- server memory growth;
- loading/streaming wait;
- network receive/send;
- maximum active NPCs, robots, effects, and streamed meshes.

### DEC-08 — Robot fault attribution

Define the difference between a player-caused missed deadline, an ordinary robot failure, and a game-caused navigation failure. This decision controls whether horror triggers and whether the job is requeued. The server must use objective reason codes rather than a vague runtime guess.

### DEC-09 — Hiding occupancy and inspection

Define whether hiding locations hold one or multiple players, what happens when two players enter simultaneously, whether hidden players can voluntarily exit during inspection, and what happens if the hiding asset streams out or is destroyed.

### DEC-10 — Economy intent

Define whether four-player parties intentionally create four times the personal cash for every shared task and survival. Test and balance guest farming through high-stage hosts, repeated ending credit, host rotation, disconnect/rejoin, and robot automation.

### DEC-11 — Stage 11 encounter duration

The roadmap gives durations for stages 0–10 but not an explicit Stage 11 duration. Record the intended duration.

### DEC-12 — Feature-flag dependency rules

Define valid and invalid combinations. Examples:

- `Finale=true` while `Lobby=false`;
- `Postgame=true` while ending state is incomplete;
- `Secrets=true` while bunker or horror is unavailable;
- `Horror=false` for a profile already inside an encounter checkpoint.

Every invalid combination needs a deterministic safe fallback.

---

## 4. Recommended Test Architecture

### 4.1 Suggested project layout

```text
Tests/
  Unit/
    Economy/
    Scheduling/
    Horror/
    Persistence/
    Party/
    Finale/
  Integration/
    Profile/
    TaskFlow/
    EncounterFlow/
    RobotFlow/
    MachineFlow/
    EndingFlow/
  Scenarios/
    M0/
    M1/
    ...
    M9/
  Security/
  Performance/
  Fixtures/
  Fakes/
  Helpers/
  Reports/
```

The exact folders may be adapted to the repository, but unit, integration, scenario, security, and performance tests should remain distinguishable.

### 4.2 Testability interfaces

Production systems should depend on small interfaces that can be replaced in tests:

| Interface | Production implementation | Test implementation |
|---|---|---|
| `Clock` | Monotonic server time | Manually advanced fake clock |
| `RandomSource` | Server RNG | Fixed seed / scripted sequence |
| `ProfileStore` | Real profile/DataStore adapter | In-memory store with injected failures |
| `TeleportAdapter` | TeleportService | Fake success/failure/retry recorder |
| `PathAdapter` | Pathfinding/navigation layer | Scripted success, blocked, timeout, invalid path |
| `AssetRegistry` | Real asset manifest | Fixture registry with missing/wrong mappings |
| `AnalyticsSink` | Production telemetry | In-memory event collector |
| `SessionDirectory` | Reserved-server/session lookup | Fake join/rejoin token service |
| `EffectsDriver` | Real client effects | Recorder that verifies start/cleanup calls |
| `SaveScheduler` | Real retry/backoff logic | Deterministic failure sequences |

Do not wrap every Roblox API unnecessarily. Add seams where determinism, fault injection, or production safety requires them.

### 4.3 State machines to formalize

Codex should document and test legal transitions for:

1. `SessionPhase`: Lobby → Loading → Tasks → Horror → Finale → Ending → Postgame → Closing.
2. `TaskState`: Unassigned → Active → Completed/Failed → RewardCommitted → Closed.
3. `RobotJobState`: Queued → Navigating → Performing → Completed/Requeued/Failed → RewardCommitted.
4. `EncounterState`: Idle → Reveal → Chase → Captured/Survived → Restoring → Idle.
5. `PlayerPresence`: Connected → Loading → Active → Dead/Recovering → DisconnectedGrace → Left.
6. `MachinePurchase`: Offered → Authorized → Charged → Installed → Saved.
7. `FinalChoice`: Unavailable → Offered → Submitted → CreditCommitted → Routed.

Tests must reject illegal transitions and repeated terminal events.

### 4.4 Operation IDs

Use a unique server-generated operation ID for every value-bearing action:

- task completion/reward;
- capture penalty;
- survival bonus;
- purchase/install;
- discovery credit;
- ending credit;
- statistic increment.

The profile layer should retain enough deduplication information to reject retries after callbacks, reconnects, or save retries. Tests must submit the same ID repeatedly and prove exactly-once results.

### 4.5 Scenario runner

Create a Studio-only scenario runner capable of:

- selecting milestone and test ID;
- loading a named fixture profile;
- setting party size and host;
- advancing the fake clock;
- forcing a task, hunter, path failure, capture, survival, death, disconnect, reconnect, machine stage, streaming delay, or ending choice;
- collecting server and client assertions;
- returning a structured result.

The scenario runner must be guarded by both environment checks and build/config exclusion. A guessed remote call in a published server must do nothing except record a security rejection.

### 4.6 Automated test layers

| Layer | Purpose | Typical runtime | Required on |
|---|---|---:|---|
| Static/type/lint | Catch invalid types, dead paths, unsafe globals, obvious API misuse | Seconds | Every change |
| Unit | Pure calculations, mappings, state transitions, eligibility, migrations | Seconds | Every change |
| Integration | Multiple real modules with fake external services | Seconds–minutes | Every change to core systems |
| Studio scenario | Real DataModel, server/client behavior, NPCs, UI, cleanup | Minutes | Pull request / milestone |
| Multi-client scripted | Races, replication, joins/leaves, party state | Minutes | Party/core changes |
| Published private E2E | Real teleport, reserved server, DataStore, asset delivery | Minutes | Milestone and release candidate |
| Hardware/performance | Real phone/tablet/desktop behavior | Longer | Milestone and release candidate |
| Human exploratory/blind | Fun, clarity, fear, surprise, edge behavior | Session-based | Vertical slice and release candidate |

---

## 5. Global Invariants

These are checked after every scenario, not only in the milestone where they were introduced.

- **INV-001:** Cash never becomes negative, NaN, infinite, non-integer if currency is integer-based, or greater than the defined cap.
- **INV-002:** One operation ID changes persistent value at most once.
- **INV-003:** A player never receives the same task reward, survival bonus, purchase, discovery, or ending credit twice from retries.
- **INV-004:** Only the host profile can change host-owned physical construction in that session.
- **INV-005:** Guest-owned cash/stat/discovery changes never overwrite the host profile or another guest profile.
- **INV-006:** `totalTasks` remains a lifetime statistic and is never used as mutable cycle position.
- **INV-007:** No client request directly selects authoritative reward values, task completion, hunter identity, machine stage, ending state, or host permission.
- **INV-008:** A deadline is based on server time and cannot be extended by client UI, frame rate, tab focus, or local clock changes.
- **INV-009:** Pause is reason-counted; ending one pause reason does not resume while another reason remains.
- **INV-010:** At most one active primary task exists per session.
- **INV-011:** Every active robot job has exactly one owner, one deadline, and one terminal outcome.
- **INV-012:** At most one encounter controls a session at a time.
- **INV-013:** One capture produces one encounter termination and one party penalty operation.
- **INV-014:** Encounter cleanup can run zero, one, or many times and always converges to the same normal state.
- **INV-015:** No player remains camera-locked, movement-locked, hidden, invulnerable, vignetted, desaturated, muted, or assigned to an ending UI after the owning phase ends.
- **INV-016:** Normal NPC art/dialogue/behavior is restored outside horror.
- **INV-017:** A bunker player is excluded from hunter targeting, but above-ground players remain targetable.
- **INV-018:** A hatch, door, hiding place, cinematic, or streamed region cannot permanently trap a player.
- **INV-019:** No player spawns or returns into the void, unloaded collision, or a kill plane.
- **INV-020:** Production servers expose no scenario controls or privileged debug UI.
- **INV-021:** Feature flags disabled by default do not mutate profiles or alter the baseline experience.
- **INV-022:** A failed save, teleport, asset load, or path request produces a bounded retry/fallback and never an infinite wait.
- **INV-023:** Client and server logs contain no unexpected errors after a scenario.
- **INV-024:** Disconnecting any one player cannot leave a stale eligibility, target, hidden occupancy, ready-check, or reward record.
- **INV-025:** All profile schema upgrades are forward-idempotent: loading and saving an already migrated profile does not change it again.
- **INV-026:** The final-choice result is committed before routing the player, and routing retries cannot duplicate credit.
- **INV-027:** Guests never inherit host physical upgrades after returning to their own world.
- **INV-028:** Repeat cinematic travel and direct destination travel never grant repeat ending rewards.
- **INV-029:** Asset mappings always pair the intended character with normal, scary, reveal, and audio assets.
- **INV-030:** Every test ends with zero leaked connections, timers, tasks, tags, target references, temporary instances, or reserved pause tokens attributable to the scenario.

---

## 6. Test Data and Fixtures

### 6.1 Canonical profiles

Create immutable input fixtures and expected migrated outputs for at least:

- brand-new player;
- current baseline player with no upgrades;
- each individual permanent purchase owned;
- every machine stage 0–11;
- bunker built/unbuilt;
- each robot combination supported by the existing game;
- chemistry and boombox combinations;
- cash at 0, 1, 24, 25, 499, 500, just below cap, cap;
- cycle positions at start, middle, and end of a five-task cycle;
- first reveal false/true;
- each discovery-flag combination using pairwise coverage, plus all-off and all-on;
- each ending state and postgame lock state;
- missing optional fields;
- unknown future fields that must be preserved if the storage policy supports them;
- corrupt types, out-of-range numbers, nil sub-tables, and obsolete crisis/panic fields;
- an interrupted transaction record;
- a duplicate operation ID record.

### 6.2 Party fixtures

- Solo host.
- Host + one guest.
- Host + three guests.
- Guest joins late.
- Guest disconnects and rejoins.
- Host disconnects and rejoins at 0 s, 59 s, and after grace expiry.
- All players disconnect in different orders.
- Host has stage 11 while guests have stages 0, 5, and 10.
- Mixed accessibility preferences.
- Mixed ending choices for all 16 four-player binary combinations.

### 6.3 Deterministic random sequences

Provide scripted RNG sequences for:

- bank hunter selection with every previous hunter;
- anomaly 20% selection;
- no-back-to-back anomaly enforcement;
- any distraction/search choice;
- path fallback choice where randomness exists.

### 6.4 Fault sequences

Every external adapter should support:

- success;
- immediate failure;
- timeout;
- fail once then succeed;
- succeed but callback delivered twice;
- completion arrives after player disconnect;
- stale response from an earlier session/operation.

---

## 7. Milestone 0 — Safe Production Foundation

### Objective

Prove that the current solo pre-horror build is preserved, migrations are safe, flags are off by default, and test tooling cannot leak into production.

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M0-001 | P0 | Load the preserved rollback build and complete all five existing tasks | Behavior and rewards match the accepted baseline | Manual + regression |
| M0-002 | P0 | Complete a full baseline playthrough on a real supported phone | No progression blocker, stuck control, hidden prompt, or unreadable UI | Hardware |
| M0-003 | P0 | Load each legacy profile fixture | Cash, robots, bunker, chemistry, boombox, and machine stage are preserved | Unit/integration |
| M0-004 | P0 | Run every migration twice | Second run is a no-op | Unit |
| M0-005 | P0 | Inject save failure before migration commit | Original profile remains recoverable; no partial schema | Integration |
| M0-006 | P0 | Inject save callback twice | Profile value changes once | Integration |
| M0-007 | P0 | Load obsolete crisis/panic fields | They do not reactivate abandoned systems; required baseline data remains | Integration |
| M0-008 | P0 | Start with every new feature flag absent | Flags resolve safely to disabled | Unit/integration |
| M0-009 | P0 | Enable each flag individually in staging | Only the intended subsystem changes | Scenario |
| M0-010 | P0 | Try invalid flag dependency combinations | Safe fallback and diagnostic event; no corrupt state | Unit/scenario |
| M0-011 | P0 | Search the published DataModel and network surface for scenario controls | No debug UI, remote, command, bindable path, or privileged module is usable | Security/published |
| M0-012 | P0 | Fire guessed scenario/debug remotes in published test | Request is rejected and logged; no state change | Security |
| M0-013 | P1 | Compare baseline server/client error logs before and after foundation changes | No new unexpected warnings/errors | Regression |
| M0-014 | P1 | Join with slow character/asset loading | Timers and tasks do not begin before player readiness | Scenario/network |
| M0-015 | P1 | Kill/reset during baseline tasks | Existing task loop recovers exactly as accepted baseline | Scenario |
| M0-016 | P1 | Validate rollback procedure from staging to preserved version | Documented rollback restores playable version without live data damage | Release drill |
| M0-017 | P1 | Verify test experience uses isolated DataStore names/universe | No live profile is read or written | Configuration audit |
| M0-018 | P1 | Audit asset manifest and permission-review checklist presence | Every third-party or likeness-bearing asset has owner/status/source fields | Manual audit |

### Gate evidence

- Baseline comparison report.
- Migration fixture report.
- Production debug-surface security report.
- Solo mobile playthrough video/log.
- Rollback drill record.

---

## 8. Milestone 1 — Lobby and Co-op Foundation

### Lobby, party, teleport, and ownership

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-001 | P0 | Solo launch from lobby | Immediate launch to a valid private house session | Published E2E |
| M1-002 | P0 | Two-player invited party create/join/ready/launch | Correct host and membership arrive in one reserved session | Published E2E |
| M1-003 | P0 | Four-player invited party create/join/ready/launch | Exactly four intended players arrive; no outsider joins | Published E2E |
| M1-004 | P0 | Tamper with client-provided host ID or party list | Server ignores it and uses validated membership | Security |
| M1-005 | P0 | Reuse stale teleport data from an earlier party | Rejected or routed safely; cannot impersonate host | Security/E2E |
| M1-006 | P0 | Teleport request fails once, then succeeds | Bounded retry/fallback; no duplicate server/session creation visible to players | Published E2E |
| M1-007 | P0 | One party member fails teleport while others succeed | Defined recovery path keeps state coherent and explains next action | Published E2E |
| M1-008 | P1 | Host leaves lobby before launch | Apply defined host-transfer or party-cancel rule consistently | Multi-client |
| M1-009 | P1 | Guest leaves during ready check | Membership and readiness update; launch cannot include stale guest | Multi-client |
| M1-010 | P1 | Ready button is spammed/reordered | One readiness state per player; no duplicate launch | Multi-client/network |
| M1-011 | P1 | Outsider guesses reserved access/session token | Access denied | Security/E2E |
| M1-012 | P1 | Join with delayed or missing teleport metadata | Safe return to lobby; never assume host/party identity | E2E |

### Shared scheduler and rewards

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-013 | P0 | Two players complete the same active task in the same frame | Task commits once; each eligible player receives one reward | Multi-client |
| M1-014 | P0 | Four clients spam completion request | One authoritative completion; no extra cash/stat increments | Security/multi-client |
| M1-015 | P0 | Guest completes task | Shared task advances for all; each eligible member gets one reward | Multi-client |
| M1-016 | P0 | Host completes task | Same result as guest completion; ownership does not affect task ability | Multi-client |
| M1-017 | P0 | Client requests arbitrary reward amount | Server calculates reward from config and rejects payload value | Security |
| M1-018 | P0 | Player disconnects during reward commit and rejoins | Exactly one reward after reconciliation | Integration/E2E |
| M1-019 | P0 | Save succeeds for some party members and fails for another | Retry only incomplete commits; no one receives duplicate value | Fault injection |
| M1-020 | P1 | Late join is attempted after session launch | Apply explicit join policy; eligibility set remains deterministic | Multi-client |
| M1-021 | P1 | Player dies during task completion | Defined eligibility rule; no double completion on respawn | Multi-client |
| M1-022 | P1 | Complete all five tasks repeatedly with four players | Scheduler never skips, duplicates, or forks task order | Soak |

### Host-only construction

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-023 | P0 | Guest attempts bunker or machine construction via UI | UI denies or hides action; server rejects request | Multi-client/security |
| M1-024 | P0 | Guest manually fires purchase remote | No cash or world change | Security |
| M1-025 | P0 | Host and guest request same purchase simultaneously | One host-authorized transaction only | Multi-client |
| M1-026 | P0 | Host purchase is interrupted between charge and install | Transaction resumes or rolls back without lost cash/duplicate stage | Fault injection |
| M1-027 | P1 | Host purchase replicates to all clients | Everyone sees same physical world state | Multi-client |
| M1-028 | P1 | Guest leaves and starts own session | Guest does not inherit host physical upgrade | Published E2E |

### Host loss and reconnect

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-029 | P0 | Host disconnects during ordinary task | Progression pauses once; 60-second grace begins | Multi-client |
| M1-030 | P0 | Host rejoins at 59 seconds | Same host/session restored; progression resumes once | Published E2E |
| M1-031 | P0 | Host rejoins after grace expiry | Old session does not resume; all profiles remain safe | Published E2E |
| M1-032 | P0 | Host never returns | Everyone saves once and returns to lobby | Published E2E |
| M1-033 | P0 | Host disconnect event fires twice | One grace timer and one closing sequence | Fault injection |
| M1-034 | P1 | Guest disconnects/rejoins | Apply DEC-04 without altering host grace or duplicating eligibility | Published E2E |
| M1-035 | P1 | All players disconnect during grace | Server closes safely; no pending writes are lost or duplicated | E2E |

### Sprint and input

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-036 | P1 | Hold Shift from full stamina | Speed 22 for six seconds, then returns to 16 | Unit + scenario |
| M1-037 | P1 | Release sprint early and regenerate | Stamina regenerates at configured rate; UI hides only when full/idle | Scenario |
| M1-038 | P1 | Spam sprint toggle | No negative stamina, speed stacking, or remote flood | Scenario/security |
| M1-039 | P1 | Reset/die while sprinting | Speed, stamina, and UI reset safely | Scenario |
| M1-040 | P1 | Mobile sprint button on multiple landscape resolutions | Reachable, readable, does not cover prompts or thumb controls | Device automation + hardware |
| M1-041 | P1 | Client locally changes WalkSpeed | Server-authoritative gameplay rules prevent unfair persistent speed | Security |
| M1-042 | P2 | Input changes from touch to keyboard/controller | Prompt and control presentation updates without duplicate bindings | Device/input |

### Gate evidence

- Solo, 2-player, and 4-player published-session recordings.
- Teleport failure/reconnect report.
- Exactly-once reward/purchase logs.
- Mobile sprint UI captures.
- Remote-security rejection report.

---

## 9. Milestone 2 — Task Pressure and Horror Skeleton

### Timing and cycle progression

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M2-001 | P0 | Complete all cycle-1 tasks after advancing past hidden telemetry time | No horror penalty or failure is possible | Fake clock/integration |
| M2-002 | P0 | Cycle-2 task reaches 239.9 s then completes | Completes safely before 240-second deadline | Fake clock |
| M2-003 | P0 | Cycle-2 task reaches 240 s | Natural failure fires exactly once | Fake clock |
| M2-004 | P0 | Cycle-3 boundary at 204 s | Correct one-time failure behavior | Fake clock |
| M2-005 | P0 | No natural timeout through cycle 3 | First task of cycle 4 triggers forced electrical fault | Integration |
| M2-006 | P0 | Forced reveal occurs | No cash deduction; event is labeled story fault, not player failure | Integration/UI |
| M2-007 | P0 | First post-reveal pressure cycle | Deadline is 180 s | Unit/integration |
| M2-008 | P0 | Second/third/fourth+ pressure cycles | Deadlines are 153/126/90 s exactly | Unit |
| M2-009 | P0 | Pause during loading | Remaining time is unchanged | Fake clock |
| M2-010 | P0 | Pause during cinematic | Remaining time is unchanged | Fake clock |
| M2-011 | P0 | Pause during death recovery | Remaining time is unchanged | Fake clock |
| M2-012 | P0 | Pause during active horror | Remaining time is unchanged | Fake clock |
| M2-013 | P0 | Open task terminal/hacking UI | Deadline continues | Fake clock/UI |
| M2-014 | P0 | Loading and cinematic pauses overlap | Timer resumes only after both reasons clear | Fake clock |
| M2-015 | P0 | Duplicate pause/resume signal | Reason counts never underflow; no premature resume | Unit |
| M2-016 | P1 | Server frame stalls while timer runs | Deadline follows monotonic server time, not frame count | Integration |
| M2-017 | P1 | Client changes local clock or frame rate | No effect on deadline | Security |

### Hunter assignment

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M2-018 | P0 | Beer failure | George assigned | Unit |
| M2-019 | P0 | Dishes failure | Mary assigned | Unit |
| M2-020 | P0 | Trash failure | Mary assigned | Unit |
| M2-021 | P0 | Lost toy failure | Missy assigned | Unit |
| M2-022 | P0 | Bank failure with each possible previous hunter | Random choice uses only existing four and avoids previous when possible | Seeded unit |
| M2-023 | P0 | Client requests a specific hunter | Ignored/rejected; server mapping wins | Security |
| M2-024 | P1 | Missing or unknown task type | Safe fallback; no unapproved character spawns | Unit/integration |

### First encounter timeline and presentation

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M2-025 | P0 | Encounter begins | Lights off immediately; authoritative phase is Reveal | Scenario |
| M2-026 | P0 | Timeline checkpoints 0/2/5/8/10 s | Darkness/silence, build, reveal image, step, and chase occur within tolerance and once | Fake clock + client recorder |
| M2-027 | P0 | First hunter speed | Speed 10, below normal walk speed 16 | Integration |
| M2-028 | P0 | Survive exactly 30 s | Survival commits once and restoration starts | Fake clock |
| M2-029 | P0 | Capture before 30 s | Encounter ends once; no later survival callback | Integration |
| M2-030 | P0 | Two players are captured in same frame | One encounter result and one party penalty operation | Multi-client |
| M2-031 | P0 | Guaranteed reveal capture | No money deducted | Multi-client |
| M2-032 | P0 | Natural reveal capture at cycle N | Each eligible player loses `min(current cash, 25 × (cycle − 1), 500)` exactly | Parameterized unit/integration |
| M2-033 | P0 | Penalty with cash below computed loss | Cash becomes zero, never negative | Unit |
| M2-034 | P0 | Penalty at cap boundary and very high cycle | Maximum loss is 500 | Unit |
| M2-035 | P0 | Survive/capture callback is delivered twice | Reward/penalty and stats change once | Fault injection |

### Restoration and interruption

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M2-036 | P0 | Normal survival cleanup | Every modified light, NPC, door, prompt, camera, sound, and movement property matches snapshot | Scenario snapshot diff |
| M2-037 | P0 | Capture cleanup | Same complete restoration | Scenario snapshot diff |
| M2-038 | P0 | Player dies during reveal | Cleanup/recovery leaves no locked camera or duplicate encounter | Scenario |
| M2-039 | P0 | Player resets during chase | Defined encounter rule; no stale target/effect | Scenario |
| M2-040 | P0 | Host disconnects during reveal/chase | Apply DEC-05; world cannot remain permanently dark or active | Multi-client/E2E |
| M2-041 | P0 | Last player disconnects during encounter | Server shutdown path persists only safe checkpoint | E2E |
| M2-042 | P0 | Cleanup is called three times | Final state equals one successful cleanup | Unit/integration |
| M2-043 | P0 | One cleanup sub-operation throws | Remaining cleanup continues; error is captured; retry converges | Fault injection |
| M2-044 | P1 | New task start is requested during encounter | Rejected/queued according to state machine | Integration |
| M2-045 | P1 | Encounter start requested while one is active | No second encounter | Integration |

### Blind-test protocol

- Recruit testers who have not been told the trigger or exact reveal.
- Inform them before play that the build includes moderate-intensity horror, darkness, audio changes, and optional reduced-flash/reduced-motion controls.
- Do not disclose cycle number or failure condition.
- Record whether the reveal is surprising, understandable, recoverable, and fair.
- Stop and document any tester distress; do not optimize solely for maximum fear.

### Gate evidence

- Fake-clock timing suite.
- Hunter mapping suite.
- State-snapshot restoration report.
- Blind-test notes with accessibility feedback.
- Zero S0/S1 defects.

---

## 10. Milestone 3 — Horror Character Art and Presentation

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M3-001 | P0 | Validate manifest completeness for George, Mary, Missy, Georgie | Each has normal, scary, reveal, normal audio, horror audio | Automated asset audit |
| M3-002 | P0 | Swap each NPC into horror and back | Correct character assets; no cross-character mapping | Scenario |
| M3-003 | P0 | End encounter by every exit path | Normal art/audio always returns | Scenario |
| M3-004 | P0 | Compare scary art silhouette to source alpha | No unintended background, fringe, crop, or silhouette expansion beyond tolerance | Image QA |
| M3-005 | P0 | Inspect at actual game scale on phone/tablet/desktop | Identity remains recognizable; no edge artifacts | Manual/hardware |
| M3-006 | P0 | Search assets for blood/wounds/gore/text/background | None present | Manual + metadata audit |
| M3-007 | P0 | Verify normal cutout asset IDs are unchanged | Existing normal presentation preserved | Automated manifest diff |
| M3-008 | P1 | Missing scary asset | Safe fallback does not display wrong character or break encounter | Integration |
| M3-009 | P1 | Missing reveal image/audio | Encounter remains playable; diagnostic logged | Integration |
| M3-010 | P0 | Reduced flashing enabled before first reveal | Flash/darkness transitions use approved reduced variant | Client scenario |
| M3-011 | P0 | Reduced camera motion enabled | No forced high-motion camera effects; gameplay remains understandable | Client scenario |
| M3-012 | P1 | Effect volume at 0/25/100% | Horror effect bus respects setting without muting essential non-effect feedback unexpectedly | Client/audio QA |
| M3-013 | P1 | Settings persist across places/sessions | Personal accessibility choices remain | Published E2E |
| M3-014 | P1 | Settings change during encounter | Applies safely without restarting or corrupting phase | Scenario |
| M3-015 | P1 | Asset version rollback | Previous approved version can be restored without manifest mismatch | Release drill |

---

## 11. Milestone 4 — Survival Toolkit and House Pass

### Hiding

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-001 | P0 | Verify all specified hiding locations | Correct anchors exist and are reachable | World audit |
| M4-002 | P0 | Outside encounter | No hiding prompts visible or triggerable | Scenario/security |
| M4-003 | P0 | Enter each hiding place during encounter | Player becomes hidden and untargetable | Scenario |
| M4-004 | P0 | Client fakes hidden state remotely | Server rejects; hunter targeting unchanged | Security |
| M4-005 | P0 | Two players enter same hiding place simultaneously | DEC-09 occupancy rule applied without overlap/trap | Multi-client |
| M4-006 | P0 | Player dies/resets/disconnects while hidden | Occupancy clears and player state restores | Multi-client |
| M4-007 | P0 | Encounter ends while player hidden | Player exits/restores safely | Scenario |
| M4-008 | P0 | Late-tier hunter inspects hiding place | Inspection behavior follows tier and occupancy rules | Seeded scenario |
| M4-009 | P1 | Hiding location streams out or is removed in test | Emergency unhide/relocation; no void or permanent lock | Fault injection |
| M4-010 | P1 | Player attempts enter/exit spam | No duplicate occupancy, teleport jitter, or stale untargetable state | Scenario |

### Distractions

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-011 | P0 | Use three distractions | Each creates one noise target and decrements shared count | Multi-client |
| M4-012 | P0 | Use fourth distraction | Rejected with clear feedback; count never negative | Multi-client |
| M4-013 | P0 | Two players trigger final distraction simultaneously | One accepted, one rejected; no double target | Multi-client |
| M4-014 | P1 | Hunter already investigating another noise | Defined priority/retarget behavior | Seeded integration |
| M4-015 | P1 | Encounter cleanup | Objects reset and count restores for next encounter | Scenario |

### Light switches and stun

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-016 | P0 | Switch used with hunter in room | Hunter stunned 2.5 s once | Fake clock/integration |
| M4-017 | P0 | Reuse at 9.9 s | Rejected; cooldown remains | Fake clock |
| M4-018 | P0 | Reuse at 10 s | Accepted | Fake clock |
| M4-019 | P0 | Client fires switch from another room/distance | Server distance/context validation rejects | Security |
| M4-020 | P1 | Multiple hunters in room | Apply specified area stun consistently | Multi-hunter scenario |
| M4-021 | P1 | Switch used outside encounter | Normal lighting behavior only; no hidden stun state | Scenario |
| M4-022 | P1 | Encounter cleanup during stun | Hunter and switch return to normal without delayed callback | Fault injection |

### Doors, bunker, and pathing

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-023 | P0 | Front/patio/garage door adapter operations by player, robot, hunter | Consistent authoritative open/close/lock behavior | Integration |
| M4-024 | P0 | Two actors operate same door simultaneously | Deterministic final state; nobody clips or deadlocks | Multi-agent scenario |
| M4-025 | P0 | First reveal | Advanced tools remain unavailable | Scenario |
| M4-026 | P0 | Later encounter | Hiding, distractions, and stuns available | Scenario |
| M4-027 | P0 | Split party: some in bunker, some above ground | Bunker players not targeted; chase continues above | Multi-client |
| M4-028 | P0 | Last above-ground player captured while others bunker | Encounter ends once according to capture rule | Multi-client |
| M4-029 | P0 | Hatch closes with player intersecting doorway | Player is moved to safe side or hatch waits; never trapped/crushed | Physics scenario |
| M4-030 | P0 | Encounter ends with hatch sealed | Hatch restores and occupants can exit | Scenario |
| M4-031 | P0 | Each hunter paths through each supported door | No wall/door phasing or permanent stall | Automated path grid |
| M4-032 | P0 | Path around beds, appliances, truck, robots, machine | No forbidden collision traversal | Automated path grid |
| M4-033 | P1 | Dynamic door closes during path | Repath or wait; bounded recovery | Integration |
| M4-034 | P1 | Hunter gets stuck | Approved non-cheating recovery; no wall teleport visible unless explicitly designed | Fault injection |
| M4-035 | P1 | Four players, robots, and hunter crowd narrow hall | No permanent body-block or explosive physics | Stress scenario |

---

## 12. Milestone 5 — Escalation and Automation Integration

### Encounter tiers

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M5-001 | P0 | Stage boundaries 0, 4 | One hunter, speed 12, 45 s, no doors/inspection | Parameterized integration |
| M5-002 | P0 | Stage boundaries 5, 8 | Up to second hunter halfway, speed 15, 60 s, doors enabled | Parameterized integration |
| M5-003 | P0 | Stage boundaries 9, 10 | Up to three hunters, speed 18, 75 s, inspection enabled | Parameterized integration |
| M5-004 | P0 | Stage 11 | Up to four, speed 19, bunker preference, DEC-11 duration | Integration |
| M5-005 | P0 | Tier changes only between encounters | Active encounter does not mutate unexpectedly after purchase | Integration |
| M5-006 | P0 | Second hunter activation at midpoint | Happens once and only in eligible tier | Fake clock |
| M5-007 | P0 | Client reports false machine stage | Server uses host profile/session stage | Security |
| M5-008 | P0 | Early/mid/late/postgame survival bonus | Correct configured amount once per eligible player | Parameterized unit/integration |
| M5-009 | P0 | Capture and survival race at final instant | Exactly one terminal result wins | Concurrency test |
| M5-010 | P1 | Four hunters target four players | No stale/duplicate target references; bunker exclusions honored | Multi-client |
| M5-011 | P1 | Hunter speed versus sprint/stamina | Playability meets approved survival target, not just numeric config | Human balance test |

### Robot scheduling

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M5-012 | P0 | Assign a robot-owned task | Concurrent job starts and next primary task is assigned | Integration |
| M5-013 | P0 | Robot starts but has not visibly finished | No completion or reward yet | Integration |
| M5-014 | P0 | Robot visibly finishes | Job and reward commit exactly once | Integration |
| M5-015 | P0 | Completion callback duplicated | No duplicate reward/task/stat | Fault injection |
| M5-016 | P0 | Multiple robots finish simultaneously | Each distinct job commits once; scheduler remains valid | Concurrency test |
| M5-017 | P0 | Horror starts during robot navigation | Animation and deadline pause; physical state remains coherent | Fake clock/scenario |
| M5-018 | P0 | Horror ends | Job resumes from valid state with unchanged remaining deadline | Scenario |
| M5-019 | P0 | Robot navigation returns game-fault reason | Job requeues; no horror or player penalty | Fault injection |
| M5-020 | P0 | Robot simply misses deadline under valid path | Apply DEC-08 intended consequence | Integration |
| M5-021 | P0 | Robot path fails repeatedly | Bounded retries and visible fallback; no infinite loop | Fault injection |
| M5-022 | P0 | Robot/door interaction | Uses shared door adapter; no phasing | Integration |
| M5-023 | P0 | Robot encounters furniture/truck/machine/player crowd | Repaths visibly; never disappears or teleports | Stress scenario |
| M5-024 | P0 | Player completes task also owned by robot | Defined exclusivity rule prevents double completion | Multi-client |
| M5-025 | P0 | Host disconnects with robot jobs active | Apply checkpoint/rejoin policy without duplicate job/reward | E2E |
| M5-026 | P1 | Primary deadline plus maximum robot chips on small phone | Readable; prompts remain unobstructed | Device/hardware |
| M5-027 | P1 | Chip updates arrive out of order | UI uses authoritative job version and ignores stale update | Network simulation |
| M5-028 | P1 | Complete 50 fully automated five-task cycles with four players | No duplicate rewards, leaked jobs, invisible robots, or drift | Soak |
| M5-029 | P1 | Memory and connection count before/after 50 cycles | No unbounded growth | Performance/soak |

---

## 13. Milestone 6 — Optional Mystery Route

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M6-001 | P0 | Bunker absent, reveal absent | Panel locked and non-interactive | Integration |
| M6-002 | P0 | Bunker built, reveal absent | Still locked | Integration |
| M6-003 | P0 | Reveal complete, bunker absent | Still locked | Integration |
| M6-004 | P0 | Both conditions met | Panel unlocks quietly | Integration |
| M6-005 | P0 | Search HUD/task arrows/tutorials | No explicit required-progression guidance appears | UI audit |
| M6-006 | P0 | Guest discovers tunnel | Only guest personal discovery flag changes | Multi-client |
| M6-007 | P0 | Host discovers tunnel | Host flag changes; other players unchanged unless they enter | Multi-client |
| M6-008 | P0 | Retry discovery event | Credit/stat increments once | Integration |
| M6-009 | P0 | Approach house before unlock | Distant zones do not visibly stream/pop into normal view | Hardware/streaming |
| M6-010 | P0 | Enter tunnel/backrooms/dome at low network speed | Safe loading barrier/route; no void spawn | Network/streaming |
| M6-011 | P0 | Region fails to stream within timeout | Player returns to safe house point with clear fallback | Fault injection |
| M6-012 | P0 | Disconnect/rejoin inside optional zone | Resume at defined safe checkpoint, not void/unloaded geometry | Published E2E |
| M6-013 | P0 | Return path from every region | Always returns to active house | Scenario |
| M6-014 | P1 | Party separates across house and mystery zone | Tasks/horror behavior follows explicit policy; no remote region trap | Multi-client |
| M6-015 | P1 | Horror starts while player is in optional route | Apply documented eligibility/safety policy | Multi-client |
| M6-016 | P1 | Complete game without entering route | No required progression or major reward missing | Full playthrough |
| M6-017 | P1 | Memory before and after zone visit | Stream-out recovers within budget; no permanent duplicate models | Performance |
| M6-018 | P2 | Production markings/impossible geometry at all quality levels | Foreshadowing remains readable without revealing early | Visual QA |

---

## 14. Milestone 7 — Rebuild the Time Machine

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M7-001 | P0 | Migrate each saved stage 0–11 | Same stage and cost progression preserved | Parameterized migration |
| M7-002 | P0 | Repeat migration for each stage | Idempotent | Unit |
| M7-003 | P0 | Load invalid stage below 0/above 11/non-number | Safe repair or quarantine; no arbitrary free progress | Migration |
| M7-004 | P0 | Inspect each stage assembly | Correct components installed; no future component visible | Automated manifest + visual |
| M7-005 | P0 | Inspect upcoming crate at stages 0–10 | Crate contains exactly next component | Parameterized visual |
| M7-006 | P0 | Purchase stage with exact cash | Charge/install/save once | Integration |
| M7-007 | P0 | Purchase with insufficient cash | No charge or install | Integration |
| M7-008 | P0 | Spam purchase request | One stage maximum per authorized transaction | Security/concurrency |
| M7-009 | P0 | Disconnect between charge and install | Resume/rollback without lost cash or duplicate stage | Fault injection/E2E |
| M7-010 | P0 | Save failure after install | Transaction journal reconciles safely | Fault injection |
| M7-011 | P0 | Guest requests purchase | Server rejects; host state unchanged | Security |
| M7-012 | P0 | Installed pieces at each stage | Align into one coherent silhouette and collision footprint | Visual/physics QA |
| M7-013 | P1 | Player/robot/hunter path around each stage | No new collision trap or invalid navigation | Automated path grid |
| M7-014 | P1 | Late-horror pulse/frost/hum before stage 11 | Reacts without enabling activation prompt | Scenario |
| M7-015 | P0 | Stage 11 reached | Manual activation prompt appears for host under valid conditions | Integration |
| M7-016 | P0 | Guest triggers activation prompt/remotes | Cannot initiate | Security |
| M7-017 | P0 | Host starts ready check with 1–4 players | Correct eligible roster and one response per player | Multi-client |
| M7-018 | P0 | Player confirms twice | Count changes once | Multi-client |
| M7-019 | P0 | Player declines or times out | Countdown does not begin; UI resolves safely | Multi-client |
| M7-020 | P0 | Player disconnects during ready check | Roster recalculates or cancels according to policy | Multi-client |
| M7-021 | P0 | Everyone confirms | One synchronized countdown starts | Multi-client |
| M7-022 | P0 | Horror/task tries to start during countdown | Rejected/suspended according to finale transition | Integration |
| M7-023 | P1 | Countdown under latency/jitter | Clients remain acceptably synchronized; server phase is authoritative | Network simulation |
| M7-024 | P1 | Clock/navigation centerpiece at all quality levels | Unmistakable and readable | Visual QA |
| M7-025 | P1 | Roll back new machine assets | Saved stage remains valid; old/new mapping does not corrupt profile | Release drill |

---

## 15. Milestone 8 — Black-Hole Finale and Blender World

### Launch cinematic

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M8-001 | P0 | Enter launch | Task progression locks and horror suspends once | Integration |
| M8-002 | P0 | Coil sequence and portal timeline | Correct ordered effects; no duplicate activation | Fake clock/client recorder |
| M8-003 | P0 | Verify real house transforms | No destructive movement or permanent mutation of authoritative house | Snapshot diff |
| M8-004 | P0 | Each player avatar warp effect | Applied locally to correct avatar only as designed | Multi-client |
| M8-005 | P0 | Reduced-motion launch | Approved alternate camera/effects path; same progression | Client scenario |
| M8-006 | P0 | Player dies during launch | Shared cleanup path restores controls and routes safely | Scenario |
| M8-007 | P0 | Player resets during launch | No locked camera, duplicate avatar, or stuck phase | Scenario |
| M8-008 | P0 | Guest disconnects during launch | Apply checkpoint/rejoin policy without duplicate credit | E2E |
| M8-009 | P0 | Host disconnects during launch | Apply DEC-05; no party stuck indefinitely | E2E |
| M8-010 | P0 | Asset/streaming preparation is slow | Transition extends safely without exposing void/unloaded destination | Network/streaming |
| M8-011 | P0 | Preparation fails permanently | Fallback returns to safe checkpoint; launch may be retried | Fault injection |
| M8-012 | P0 | Cleanup called after normal completion and interruption | Same final control/effect state | Idempotence test |

### Studio reality and future apartment

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M8-013 | P0 | Enter route on desktop/tablet/phone | Spawn on loaded collision; route completes in intended 2–5 minute band | Hardware/full run |
| M8-014 | P0 | Inspect HUD | No tasks, timers, robots, upgrade prompts, or normal HUD | UI audit |
| M8-015 | P0 | Lowest supported graphics/device | Route remains navigable and evidence remains understandable | Hardware |
| M8-016 | P0 | Collision hull sweep | No invisible barriers, floor holes, snag points, or walk-through set pieces | Automated/manual |
| M8-017 | P0 | Stream cells in unusual order | No early reveal of future areas or missing return/route geometry | Streaming |
| M8-018 | P0 | Player walks backward/off-route/jumps onto props | Cannot escape into void or bypass critical checkpoint | Exploratory |
| M8-019 | P1 | Synthetic people/camera rigs loop for extended time | No script leak, drift, or escalating CPU usage | Soak/performance |
| M8-020 | P1 | Television/evidence assets fail | Route still completes; diagnostic and fallback presentation | Fault injection |
| M8-021 | P1 | Mixed players load destination at different speeds | Fast clients cannot advance shared state in a way that strands slow clients | Multi-client/network |
| M8-022 | P1 | Disconnect/rejoin in studio/future apartment | Safe checkpoint and personal progress restored | Published E2E |

### Individual ending choices

Run all solo choices, all four 2-player combinations, and all 16 four-player binary combinations.

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M8-023 | P0 | Stay in reality | Ending committed once, credits shown, player returned to lobby | Published E2E |
| M8-024 | P0 | Return to simulation | Ending committed once, player routed to valid personal/session house, postgame unlocked | Published E2E |
| M8-025 | P0 | Submit choice twice | First valid committed choice wins; no duplicate credit/reward | Security/concurrency |
| M8-026 | P0 | Disconnect after submit before routing | Rejoin reconciles committed choice and routes correctly | E2E |
| M8-027 | P0 | Routing succeeds but callback retries | No duplicate ending credit | Fault injection |
| M8-028 | P0 | Guest completes ending in host stage-11 world | Guest receives story/postgame credit; guest machine stage remains unchanged | Published E2E |
| M8-029 | P0 | Host stays while guest returns | Must follow DEC-01; no guest remains in abandoned host world | Published E2E |
| M8-030 | P0 | Host returns while guest stays | Host world/postgame remains valid; guest routes independently | Published E2E |
| M8-031 | P0 | All four make mixed choices | Each player receives only personal outcome; party state closes cleanly | Published E2E |
| M8-032 | P0 | Repeat cinematic replay | No repeat ending reward or choice mutation | Integration/E2E |
| M8-033 | P0 | Direct destination travel | Correct unlocked destination, no duplicate rewards | E2E |
| M8-034 | P0 | Guest starts own house after ending | Own physical stage unchanged; postgame availability follows approved rule | E2E |
| M8-035 | P1 | Credits interrupted by reset/disconnect | Ending remains committed and route recovers | E2E |

### Performance acceptance

Use the numeric budgets set by DEC-07. At minimum capture:

- mobile client frame-time traces in ordinary house, four-player multi-hunter encounter, black-hole launch, studio route, and future apartment;
- server frame time with four players, maximum robots, and four hunters;
- client/server memory at entry and after repeated transitions;
- worst frame spikes during streaming and effects;
- loading time to interactive state and maximum safe transition extension;
- network traffic during launch and multi-agent encounters.

Averages alone are insufficient; inspect spikes and long-tail behavior.

---

## 16. Milestone 9 — Postgame Horror and Retention

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M9-001 | P0 | Player without return ending enters house | Postgame remains locked | Integration |
| M9-002 | P0 | Player with return ending enters valid personal session | Postgame maintenance loop active | E2E |
| M9-003 | P0 | Stay-ending player later uses allowed route | Behavior follows explicit unlock policy; no accidental postgame | E2E |
| M9-004 | P0 | Family encounter in postgame | Existing family hunter behavior remains valid | Scenario |
| M9-005 | P0 | Anomaly assets/design not approved | Anomaly cannot spawn; no improvised placeholder | Config/asset audit |
| M9-006 | P0 | Seeded 100 eligible selections | Selection logic approximates configured 20% and exact deterministic expectations | Seeded unit |
| M9-007 | P0 | Previous encounter was anomaly | Next encounter cannot be anomaly | Unit/integration |
| M9-008 | P0 | Family then anomaly then family sequences | No-back-to-back rule does not suppress later eligible anomaly indefinitely | Seeded unit |
| M9-009 | P0 | Encounter survived/caught | Counters increment once | Integration |
| M9-010 | P0 | Survival streak after success | Current and longest streak update correctly | Unit/integration |
| M9-011 | P0 | Survival streak after capture | Current resets; longest preserved | Unit/integration |
| M9-012 | P0 | Faster/slower complete task cycles | Fastest updates only on valid faster completion | Unit |
| M9-013 | P0 | Discovery/ending stats migrate from earlier fields | Values remain accurate | Migration |
| M9-014 | P0 | Duplicate stat event | Increment once | Fault injection |
| M9-015 | P1 | Maintenance task/horror overlap | State machine prevents impossible simultaneous ownership | Integration |
| M9-016 | P1 | 50 postgame cycles | No memory, timer, connection, or economy drift | Soak |
| M9-017 | P1 | Cosmetics/daily/global board flags disabled | No unfinished UI or network calls | Regression |
| M9-018 | P1 | Seasonal variants absent | Base release behavior unaffected | Regression |
| M9-019 | P1 | Personal stats across host/guest sessions | Correct profile receives every update | Multi-client |
| M9-020 | P2 | Retention feedback study | Players understand maintenance loop and perceive meaningful variation | Human test |

---

## 17. Deferred Bunker Activities

No placeholder activity should be implemented merely to satisfy a test count. When a bunker activity is selected, require before implementation:

- a one-page rules specification;
- explicit start, success, failure, abandon, interruption, and resume states;
- reward and automation ownership;
- solo/co-op behavior;
- mobile interaction design;
- unit tests for its rules;
- integration tests with horror pause/resume;
- exploit tests for reward repetition;
- one human prototype session before economy integration.

---

## 18. Cross-Cutting Persistence and Migration Suite

| ID | Priority | Test | Expected result |
|---|---|---|---|
| MIG-001 | P0 | Every known schema version to current | Exact expected output |
| MIG-002 | P0 | Current to current | No changes |
| MIG-003 | P0 | Migration interrupted before commit | Old valid record recoverable |
| MIG-004 | P0 | Migration callback duplicated | One current record |
| MIG-005 | P0 | Missing fields | Defaults added without wiping valid values |
| MIG-006 | P0 | Wrong field types | Repair/quarantine policy; no code crash |
| MIG-007 | P0 | Unknown fields | Preserve or intentionally discard per documented policy |
| MIG-008 | P0 | Cash at bounds/out of bounds | Clamp/reject according to schema |
| MIG-009 | P0 | Machine stages 0–11 | Preserved exactly |
| MIG-010 | P0 | Ending/postgame inconsistent combination | Deterministic repair and diagnostic |
| MIG-011 | P0 | Duplicate operation log entries | Deduplicated safely |
| MIG-012 | P0 | Same profile opens in two servers | Session-lock/conflict policy prevents lost updates/duplication |
| MIG-013 | P0 | Server closes during pending write | Bounded close handling and later reconciliation |
| MIG-014 | P1 | DataStore throttling/timeout | Backoff/fallback; gameplay communicates save state appropriately |
| MIG-015 | P1 | Profile payload near size limit | Save remains within budget or fails safely before corruption |
| MIG-016 | P1 | 100 repeated load/save cycles | No drift in normalized profile |

Migration fixtures should be version-controlled. Never overwrite expected outputs automatically from current production code.

---

## 19. Cross-Cutting Multiplayer and Concurrency Suite

Use server/client simulation for deterministic races, then repeat critical cases in a published private experience.

- Two players trigger the same ProximityPrompt in the same frame.
- Four players request task completion with reordered network delivery.
- Capture and survival conditions occur on the same frame.
- Host purchase and host disconnect occur in either order.
- Host returns exactly as grace expires.
- Robot completion and horror start occur in either order.
- Door open/close requests arrive from player, robot, and hunter simultaneously.
- Hiding enter/exit and hunter inspection overlap.
- Machine ready confirmation and disconnect overlap.
- Final-choice submission and disconnect overlap.
- Ending route and host-session closure overlap.
- Save completion from an old session arrives after a new session starts.

For each race, test both orders and duplicate delivery. The authoritative result must be deterministic or explicitly first-commit-wins.

---

## 20. Security Test Plan

### 20.1 Remote and interaction inventory

Codex should generate and maintain a registry of every:

- `RemoteEvent` and `RemoteFunction`;
- ProximityPrompt, ClickDetector, or DragDetector that affects state;
- client-to-server purchase/task/hiding/sprint/ready/choice request;
- server-to-client effect or UI event;
- Studio/debug/scenario channel.

For every client-triggered action, document:

- allowed phase;
- allowed player role;
- expected argument types and ranges;
- distance/line-of-sight requirement where applicable;
- rate limit;
- replay/idempotency behavior;
- authoritative values computed on server;
- rejection telemetry.

### 20.2 Abuse cases

| ID | Priority | Attack | Required result |
|---|---|---|---|
| SEC-001 | P0 | Award arbitrary cash | Rejected; no profile change |
| SEC-002 | P0 | Complete inactive/wrong task | Rejected |
| SEC-003 | P0 | Complete task from impossible distance | Rejected |
| SEC-004 | P0 | Purchase as guest | Rejected |
| SEC-005 | P0 | Purchase nonexistent stage/item or negative price | Rejected |
| SEC-006 | P0 | Select hunter or start encounter | Rejected |
| SEC-007 | P0 | Force hidden/bunker safety | Rejected |
| SEC-008 | P0 | Trigger switch/distraction from any distance | Rejected |
| SEC-009 | P0 | Confirm ready for another player | Rejected |
| SEC-010 | P0 | Submit ending choice for another player | Rejected |
| SEC-011 | P0 | Replay old operation ID | No duplicate effect |
| SEC-012 | P0 | Send huge strings/tables, NaN, infinity, wrong instances | Rejected before expensive work or save |
| SEC-013 | P0 | Spam valid request at high rate | Rate-limited; server remains responsive |
| SEC-014 | P0 | Reference arbitrary Instance/path for mutation | Rejected |
| SEC-015 | P0 | Invoke disabled scenario/debug function | Rejected and logged |
| SEC-016 | P0 | Tamper teleport host/party data | Server validation fails safely |
| SEC-017 | P1 | Move client-owned unanchored interaction part near player | Server context checks still prevent unauthorized action |
| SEC-018 | P1 | Client changes local WalkSpeed/stamina/UI | No authoritative advantage or persistent state change |
| SEC-019 | P1 | Relay malicious effect payload to other clients | Server validates and emits only configured effect identifiers/parameters |
| SEC-020 | P1 | Flood pathfinding/expensive requests through remote | Request is bounded/rate-limited |

No security test should use a live public server or affect other users.

---

## 21. Performance, Streaming, and Soak Plan

### 21.1 Required scenarios

Measure each on the lowest supported phone/tablet and a representative desktop:

1. Baseline house, solo.
2. House, four players, maximum ordinary activity.
3. Maximum robots plus primary task.
4. One-hunter early encounter.
5. Four-hunter Stage 11 encounter with players split across house/bunker.
6. Optional mystery region entry/exit.
7. Machine Stage 11 with effects.
8. Black-hole launch.
9. Studio reality route.
10. Future apartment and credits.
11. Fifty-cycle automation soak.
12. Repeated house ↔ finale/postgame transitions.

### 21.2 Metrics

- client and server frame time, including worst spikes;
- FPS distribution rather than average only;
- client/server memory and growth slope;
- Lua heap, instance count, connection count, active tasks/timers;
- physics time and moving assembly count;
- pathfinding frequency/failure/retry count;
- network send/receive rate and large payloads;
- streaming wait duration, failed region loads, and stream-out recovery;
- time to first controllable frame;
- asset preload timeout/fallback count.

### 21.3 Soak acceptance

After a soak, compare against the initial stable checkpoint:

- no monotonic memory/instance/connection growth beyond the approved tolerance;
- no accumulating NPCs, prompts, highlights, sounds, effects, path objects, or UI;
- scheduler and cycle number remain correct;
- cash/stat totals equal the independently calculated ledger;
- no warning/error rate growth;
- no gradual timer drift;
- no degradation in median or tail frame time attributable to leaked work.

---

## 22. Accessibility and UX Test Plan

### 22.1 Accessibility requirements

- Reduced flashing must alter every reveal/portal/light effect that could flash, not only the first reveal.
- Reduced camera motion must cover vignette motion, FOV bends, shakes, avatar warping, and finale camera paths.
- Effect volume must operate on the intended audio group and preserve necessary feedback through visual/caption alternatives where needed.
- Critical gameplay information must not rely solely on color, sound, or a brief image.
- Controls and prompts must remain usable on touch and keyboard; add controller coverage if controller support is intended.
- Settings must be personal, persist, and never disclose the secret mechanic before reveal.

### 22.2 UX scenarios

- Small phone landscape, large phone, tablet, desktop at common aspect ratios.
- Maximum HUD density: primary deadline, robot chips, interaction prompt, stamina UI, party/ready UI.
- UI during respawn, loading, horror, and finale transitions.
- Rapid input-method switching.
- Text expansion/pseudolocalization if localization is planned.
- Color/brightness extremes and low graphics quality.
- First-time player with no spoken explanation.
- Player returning after a long gap at each checkpoint.

### 22.3 Human feedback questions

Record separately:

- Did the player understand the current goal?
- Did the hidden reveal feel surprising rather than arbitrary?
- Did a failure feel attributable and fair?
- Could the player locate safe options after the first reveal?
- Did accessibility settings materially reduce the relevant effect?
- Did co-op players understand host ownership and personal rewards?
- Did any player wait with nothing meaningful to do?
- Did the finale choice and consequences read clearly?

---

## 23. Asset and Content QA

Maintain an asset manifest with:

- logical asset key;
- character/location/system;
- normal/horror/reveal variant;
- version;
- Roblox asset ID;
- source file hash;
- alpha/crop dimensions where relevant;
- permission/ownership status;
- approval status;
- maturity-content notes;
- fallback asset.

Automated startup validation should detect missing keys, duplicate IDs where prohibited, wrong character mappings, and unapproved placeholders. Release QA must verify the strongest fear content and update the experience’s maturity information whenever the shipped content changes an answer.

---

## 24. Observability and Test Evidence

### 24.1 Structured event log

Every critical state change should emit a compact structured event containing:

- timestamp and server job/session ID;
- party/session ID;
- operation ID;
- player IDs affected;
- previous and new state;
- reason code;
- config/feature-flag version;
- result (`accepted`, `rejected`, `retried`, `committed`, `rolled_back`);
- error category without sensitive payloads.

Recommended event families:

- `profile_load/migrate/save`;
- `party_create/join/leave/host_lost/host_returned/close`;
- `task_start/complete/fail/reward`;
- `robot_job_*`;
- `encounter_start/reveal/capture/survive/restore`;
- `purchase_authorize/charge/install/commit`;
- `discovery_credit`;
- `finale_start/checkpoint/choice/credit/route`;
- `remote_rejected`;
- `stream_wait/fallback`.

### 24.2 Test report artifacts

Each automated run should output:

- build/commit identifier;
- config and feature-flag version;
- test IDs run;
- pass/fail/blocked counts;
- seed and fixture IDs;
- first failing assertion;
- server/client logs;
- state snapshot diff;
- performance samples where applicable;
- links or paths to screenshots/video for manual cases.

---

## 25. Execution Cadence

### Every code change

- static/type/lint checks;
- unit suite;
- fast integration suite;
- remote registry validation;
- asset/config schema validation.

### Every core-system pull request or Codex batch

- affected milestone scenarios;
- migration fixtures if profile/config changed;
- two-player concurrency smoke test;
- error-log audit;
- regression tests for fixed bugs.

### Nightly or scheduled development run

- full unit/integration suite;
- scripted 1-, 2-, and 4-client scenarios;
- randomized order/seed run;
- 10-cycle soak;
- production-debug-surface scan.

### Milestone candidate

- all milestone cases;
- 1/2/4-player published private E2E;
- real DataStore test namespace;
- relevant real-device pass;
- security suite;
- full error-log audit;
- gate evidence package.

### Release candidate

- all P0/P1 tests across all enabled milestones;
- complete old-save migration matrix;
- real reserved-server/teleport matrix;
- 50-cycle soak;
- lowest-supported-device performance suite;
- blind/new-player test;
- accessibility test;
- content/asset/IP checklist;
- maturity questionnaire review;
- rollback drill.

---

## 26. Milestone Gate Definition

A milestone passes only when:

1. Every P0 test is PASS.
2. Every P1 test is PASS or has a written, time-bounded accepted risk that does not violate the roadmap’s final no-progression-loss gate.
3. No S0 or S1 defect remains open.
4. No unexpected server/client error is present in the gate run.
5. Migration and rollback evidence exists if persistent/config state changed.
6. Relevant 1-, 2-, and 4-player cases pass.
7. Relevant mobile/device/accessibility cases pass.
8. The global invariants pass after every scenario.
9. The test report identifies the exact build, config, assets, and seed.
10. A human reviewer signs off on visual, gameplay, and surprise/fear requirements that automation cannot judge.

“Works on my account” or “I played for hours” is supporting evidence, not a gate by itself.

---

## 27. Codex Implementation Brief

Give Codex the repository plus this file and use the following instruction:

> Read `PLAN.md` and `COOPER_TIME_MACHINE_TEST_PLAN.md` completely before modifying code. First produce a requirement-to-code-to-test inventory. Identify all ModuleScripts, server scripts, LocalScripts, remotes, profile fields, feature flags, timers, random choices, and state machines related to each milestone. Do not implement tests by copying current behavior; derive expected behavior from the roadmap and list any ambiguity as a blocked decision.
>
> Build deterministic test seams for clock, randomness, persistence, teleport, navigation failures, asset lookup, and analytics only where needed. Use TestEZ or the repository’s existing Luau test framework for unit and integration tests. Add a Studio-only scenario runner for real server/client tests, but ensure its controls are excluded from or cryptographically/structurally unreachable in production; a runtime boolean alone is not sufficient protection.
>
> Implement tests in priority order: global invariants, profile migration and exactly-once economy, party/host lifecycle, task scheduling, horror timing/restoration, robot concurrency, machine purchases, finale choices, then presentation/performance helpers. For every critical operation, test success, duplicate delivery, disconnect, timeout, stale response, and fail-then-retry.
>
> Never change a requirement silently. Never delete or weaken a failing test to obtain green status. Never add arbitrary `task.wait()` delays when a fake clock or state signal can be used. Do not rewrite production behavior solely to satisfy a test without reporting the defect and the chosen correction.
>
> Generate these reports after each batch:
> 1. `TEST_TRACEABILITY.md` — requirement → implementation → test IDs.
> 2. `TEST_RESULTS.md` — pass/fail/blocked with first failure and seed.
> 3. `UNRESOLVED_DECISIONS.md` — DEC items and any newly discovered ambiguity.
> 4. `REMOTE_SECURITY_MATRIX.md` — every client-triggered action and its validation/rate limit.
> 5. `MIGRATION_FIXTURES.md` — schema versions and expected outputs.
>
> Stop a batch and report rather than guessing when behavior affects persistent value, host ownership, reconnect eligibility, individual endings, or production debug access.

### First Codex batch deliverables

The first test batch should not attempt all milestones. It should deliver:

1. test runner and folder structure;
2. fake clock and deterministic random source;
3. profile migration fixture harness;
4. operation-ID/idempotency tests for cash and progression;
5. task deadline and penalty unit tests;
6. hunter-mapping tests;
7. encounter cleanup snapshot helper;
8. remote inventory/security matrix generator;
9. one 2-client scripted task-completion race;
10. one production-build check proving scenario controls are unavailable.

This creates leverage for the remaining tests instead of producing hundreds of brittle tests at once.

---

## 28. Final Release Checklist

- [ ] All blocking decisions resolved and versioned.
- [ ] Source baseline and rollback version verified.
- [ ] Feature flags default off and invalid combinations safe.
- [ ] All migrations and every machine stage fixture pass.
- [ ] Exactly-once ledger passes duplicate/retry/disconnect tests.
- [ ] Solo, 2-player, and 4-player party tests pass.
- [ ] Host/guest ownership and reconnect rules pass.
- [ ] Every task can naturally trigger first horror; forced cycle-4 reveal passes.
- [ ] Every hunter asset mapping and cleanup path passes.
- [ ] Hiding, distraction, switch, door, bunker, and pathing tests pass.
- [ ] Fifty automated cycles pass without drift or leaks.
- [ ] Optional regions never appear early or spawn into void.
- [ ] All 11 machine stages migrate, purchase, align, and path correctly.
- [ ] Finale interruption matrix passes.
- [ ] All 16 four-player ending-choice combinations pass.
- [ ] No repeat ending rewards.
- [ ] Postgame anomaly approval gate and no-back-to-back rule pass.
- [ ] Security suite reports no unauthorized state mutation.
- [ ] Lowest-supported-device performance budgets pass.
- [ ] Reduced flash, reduced motion, and effect-volume behavior pass.
- [ ] Server/client logs contain no unexpected errors.
- [ ] Asset permission/IP review is complete for the intended release scope.
- [ ] Content maturity information matches the strongest shipped content.
- [ ] Private release candidate and rollback drill pass.

