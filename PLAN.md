# Cooper Time Machine — Canonical Game Bible and Verification Specification

**Canonical document:** `PLAN.md`

**Integrated sources:** the original development roadmap, `COOPER_TIME_MACHINE_PLAN_REVIEW.md`, `COOPER_TIME_MACHINE_TEST_PLAN.md`, `MILESTONE0_BASELINE.md`, `MILESTONE0_VERIFICATION.md`, `MILESTONE1_IMPLEMENTATION.md`, and `MILESTONE1_TEST_MATRIX.md`

**Baseline date:** 2026-07-22

**Authority:** This file is the product, architecture, implementation, testing, accessibility, performance, and release contract for all future work on the game. The source review and test-plan files remain historical inputs; when they conflict with this file, this file wins.

---

## 1. Vision and Experience Arc

Build the experience as gated, rollbackable production milestones rather than one giant update. Preserve the currently working Cooper house, five ordered tasks, automation systems, bunker, chemistry, boombox, bank game, deliveries, Time Machine progress, and exactly four normal PNG family NPCs: **George, Mary, Missy, and Georgie**.

The complete experience arc is:

1. A warm, funny 1980s household task and upgrade game.
2. A hidden task-pressure system whose first horror reveal is genuinely unexpected.
3. Escalating but moderate, no-gore survival encounters using the four existing family cutouts.
4. Optional bunker tunnel, backrooms-house, and dome mysteries that foreshadow a constructed world.
5. A coherent eleven-stage Time Machine rebuilt through the existing economy.
6. A black-hole launch into an ultra-realistic, Blender-built studio reality streamed inside the house place.
7. A future-apartment payoff and an individual final choice.
8. A personally unlocked postgame horror/maintenance loop.

The cozy game must remain enjoyable on its own. Horror is a reveal and pressure layer, not permission to degrade the normal characters, interactions, humor, accessibility, or household progression.

---

## 2. Current Production Status

### 2.1 Milestone status

| Milestone | Implementation status | Verification status | Release meaning |
|---|---|---|---|
| 0 — Safe pre-horror baseline | Complete | Complete under the approved 2026-07-22 scope lock | Authoritative rollback baseline |
| 1 — Lobby and co-op foundation | Current closure candidate committed and exercised in a local Studio preview; not published or live-reserved-server verified | **Gate open** | Must not be called complete or used to unlock Milestone 2 |
| 2–9 | Not approved for activation | Not started under this bible | Corresponding feature flags remain disabled |

Milestone 0 is backed by commits `8c16e85` and `813f93c`, dated `.rbxm` exports and SHA-256 hashes, 71/71 local source compilation, 637 edit-mode and 599 runtime baseline checks, migration double-pass checks, gameplay regression suites, responsive terminal captures, and a documented restoration procedure.

Milestone 1 implementation is backed by commits `e1d4b29` and `1343005`, 79/79 source compilation, house verification (530 edit / 616 runtime), lobby verification (181 edit / 225 runtime), a controlled four-client Studio task/reward/purchase test, host-grace testing, sprint and movement-lock checks, and simulated responsive lobby captures.

The current Milestone 1 closure candidate is backed by commits `f31c0cd`
(`test: harden milestone 1 persistence and launch gates`) and `14932d7`
(`fix: clear Studio server register startup limit`). Its current evidence is
recorded in section 2.3 and the milestone matrix. These commits supplement,
rather than erase, the historical evidence above.

Milestone 1 is **not release-verified**. Before the newly reported Ready/Start defect and the additional tests in this bible, its authoritative matrix stood at:

| Area | PASS | PARTIAL | NOT RUN |
|---|---:|---:|---:|
| Automated contracts | 7 | 0 | 1 |
| Lobby UI/Studio interactions | 8 | 0 | 1 |
| Live party and teleport | 0 | 0 | 11 |
| Shared tasks and rewards | 0 | 2 | 9 |
| Host authority/persistence | 1 | 1 | 6 |
| Host disconnect state machine | 1 | 2 | 12 |
| Sprint/mobile controls | 2 | 2 | 8 |
| Regression/release | 3 | 1 | 3 |
| **Total** | **22** | **8** | **51** |

The open live gates include real Roblox Player cross-place launches, reserved-server allocation, MemoryStore ticket behavior, real friend invitations, guest/host reconnect boundaries, DataStore lease behavior, physical-device input, and the complete existing-feature/four-player regression.

### 2.2 Immediate P0/S1 release blocker: Ready and Start

The reported lobby failure was reproduced on 2026-07-22: one shared request
cooldown rejected a valid Launch immediately after an acknowledged Ready. The
local source and open Studio edit model now use independent action limits,
authoritative revisions, atomic launch ownership, and explicit launch reasons.
A clean Studio runtime accepted Ready → Launch with server checkpoints 50 ms
apart, and the dedicated launch audit passed 32 checks in edit mode and 32 in
runtime. The repaired build has **not** been published, so the live launch gate
remains a P0 release blocker rather than a completed production fix. Until it
is evidenced in a privately published build:

- Milestone 1 remains open.
- No horror work may be enabled.
- A Studio safe preview must not be presented as proof of a live reserved-server launch.
- Publishing or topology changes require explicit user authorization.

The repair contract is:

- The server owns party membership, each member's ready value, party revision, and `canLaunch` result.
- The client stores a typed ready state from authoritative snapshots; it must never infer readiness by parsing button text or color.
- `SetReady` is idempotent and acknowledges the committed ready value and party revision.
- Ready state survives polling, heartbeat renewal, UI rerenders, duplicate pushes, and ordinary network reordering.
- Ready and Launch use per-action rate limits. A valid Launch immediately after an acknowledged Ready operation cannot be rejected by a shared cooldown.
- Only the host can launch. Every currently locked party member must be ready; solo play launches without unnecessary ready-up friction.
- Disabled Start UI always gives a plain-language reason: host only, member not ready, party changing, storage unavailable, or launch already in progress.
- Start double-clicks produce one locked party snapshot, one session manifest, and one admission ticket per member.
- Studio cannot prove a live reserved-server teleport. After the same authoritative Ready/Start validation, the Studio-only bridge must instead replace the lobby with an inert, verified in-place Cooper House preview, start the normal house UI/controllers, restore camera and PlayerModule controls, and let the tester walk and interact. The bridge, package, synthetic party state, and scenario privileges must be unavailable in production; a successful Studio preview is still not evidence for published teleport, ticket, MemoryStore, or DataStore rows.
- Published launch checkpoints are logged from ready receipt through house admission. A failure returns the lobby to a retryable state without duplicate sessions, tickets, or charges.

**Historical 2026-07-22 Studio launch evidence:** an earlier exact Create Party
→ Ready → Start flow opened the Cooper House in the same playtest, removed the
lobby GUI/world, loaded the normal house systems, and restored movement. That
earlier run remains historical evidence only; the current-candidate results
below supersede its audit counts. No place was created, overwritten, or
published for that repair.

### 2.3 Current candidate evidence addendum — `f31c0cd` + `14932d7`

The exact current Studio flow was:

```text
CreateParty → SetReady true → Launch (zero delay)
READY_COMMITTED → STUDIO_HOUSE_STARTED
```

The first candidate run exposed Roblox's 200-register startup failure in both
`CooperGame` and `CooperBunker`; the resulting missing-event errors in
`CooperTaskWorld` were downstream symptoms. The sources were refactored, the
new compiler-register gate passed the full `27/27` `O0`/`O1`/`O2` ×
`g0`/`g1`/`g2` matrix across all three core servers, and a clean fresh rerun
ended with `RuntimeStartupReadiness` **PASS**.
Ordinary default compilation alone is not accepted as Roblox startup evidence.

Current candidate evidence:

- `120/120` local Luau sources passed default compilation.
- The deterministic suite passed `82/82`.
- The Milestone 1 lobby edit audit passed `316` checks.
- A second fresh `PlaySolo` also returned `STUDIO_HOUSE_STARTED` with
  authoritative `selfReady = true` and `canLaunch = true`; startup readiness
  passed again, with no project startup errors/warnings in either server or
  client logs (excluding the external Studio MCP version-mismatch warning).
- The Studio preview edit audit passed `71` checks and its active-runtime audit
  passed `118`.
- The prompt-security audit passed `124` checks. This is not a substitute for
  published abuse/flood testing.
- The server advertised schema `12`, `FoundationContract = PartyV1`, a loaded
  `Active` host profile, exactly four core RemoteEvents, and ready task-world
  and automation controllers.
- The runtime family roster was exactly George, Georgie, Mary, and Missy.
- `Horror`, `SecretExploration`, `TimeMachineFinale`, `Postgame`, and
  `StudioScenarioTools` all remained `false`.
- A sustained client-side Humanoid movement command covered `24.68` studs at
  `WalkSpeed = 16`; the camera was normal and the character was not in
  `PlatformStand`. Because Studio's window was not renderable to virtual input,
  this is movement-authority evidence, not a current-candidate keyboard/touch
  input pass.
- An idle profiler sample reported a maximum server script share of `1.68%`
  for `CooperYardRideables`; the largest client entry was external/core and
  remained below `0.8%`. This is an idle sample, not a gameplay, mobile,
  four-player, encounter, or soak performance pass.
- The dated local export
  `2026-07-22_23-21-46_EDT_schema12-studio-preview-verified.rbxm` is `668659`
  bytes with SHA-256
  `09dc971d4f534c34c369d82455a7bac026ec6bc7342d0d3ec2cbcf91a5a2fb7a`.

The schema-12 operation journal currently protects shared task payouts and the
six paid order operations documented in the implementation record. Global
exactly-once closure is still incomplete: candy payout, boombox payout ticks,
`AdjustCurrency`, `SpendAllowance`, and physical install transitions remain
outside the operation-ID/reconciliation path.

This addendum does **not** claim screenshot or physical-device/mobile visual
acceptance, a published or reserved-server launch, live MemoryStore or
DataStore behavior, multiplayer completion, or a full existing-feature
regression. Milestone 1 therefore remains **GATE OPEN**, and Milestone 2
production runtime remains **BLOCKED**.

---

## 3. Non-Negotiable Product Rules

- Support solo play and invited private parties of 1–4. Public matchmaking is out of scope.
- The start place is a lightweight 1980s lobby; the Cooper house runs in a reserved house server.
- The host's profile owns the physical house, bunker, installed robots, permanent world purchases, deliveries, and Time Machine stage for that session.
- Guests retain their own personal cash, statistics, discoveries, ending credit, accessibility settings, and postgame entitlement. They never inherit the host's physical upgrades.
- Every eligible party member receives the **full configured personal task reward** and survival bonus once. Four-player play intentionally creates four personal payouts; balance and anti-farming controls must account for this rather than silently dividing rewards.
- Tasks, deadlines, encounters, and capture results are shared. Any eligible player may complete the active task.
- One capture ends an encounter and applies one party penalty operation:
  - `loss = min(current cash, $25 × (cycle − 1), $500)` per eligible member.
  - The guaranteed story reveal never deducts money.
  - Permanent purchases and tasks completed before the current failed task remain intact.
- The bunker protects only players who physically reached it. Hunters continue pursuing eligible players above ground.
- Normal NPC art, catchphrases, dialogue choices, audio, proportions, placement, and behavior remain untouched outside horror.
- Do not add Sheldon, Billy, Mandy, Meemaw, or any other friendly family NPC. Do not revive discarded panic/crisis/progression runtime systems.
- Horror targets moderate fear without blood, wounds, gore, or misleading public maturity information.
- Titles, thumbnails, and description may preserve the surprise, but the Roblox content-maturity questionnaire must accurately disclose the strongest shipped fear content.
- Asset permission and intellectual-property review is a hard public-release blocker, not a post-release cleanup item.
- No milestone advances with progression loss, duplicated value, stuck movement, void spawning, wrong NPC art, exposed debug authority, or incomplete world restoration.

---

## 4. Locked Cross-System Decisions

The twelve formerly blocking decisions are resolved as follows. Implementers must not substitute a different behavior silently.

### DEC-01 — Individual endings and host-owned worlds

Final choices and credits commit per player. **Stay in reality** marks the ending complete and routes that player to the lobby without postgame. **Return to the simulation** marks the ending complete, unlocks postgame personally, and routes that player to the lobby after credits, but does not transfer the host's machine or house. The finale server closes after every connected player is routed. Return takes physical effect on the player's **next owned house session**; nobody remains indefinitely in an absent host's Stage 11 world.

### DEC-02 — Reward and penalty eligibility

At authoritative task/job or encounter start, the server creates an immutable-versioned eligibility snapshot from fully hydrated active party memberships.

- Include active, AFK, respawning, bunker, and optional-route members who were already in the session.
- Exclude players still loading, outsiders, replacement invitees, and anyone arriving after the snapshot.
- A disconnect preserves the same membership identity through the 90-second guest grace; rejoining never creates another reward record.
- If grace expires before the value operation commits, that member may be marked `Forfeited` for that operation with an explicit reason. A committed result is never recalculated afterward.
- Ending credit is personal to every player who reached the finale checkpoint. A disconnected player receives `FinalChoicePending` rather than an inferred choice.

### DEC-03 — Named safe checkpoints

Persist durable progression only at these checkpoints:

1. `CalmTaskStart`
2. `FirstRevealCommitted`
3. `PaidDeliveryPending`
4. `MachineStageInstalled`
5. `FinaleLaunchCommitted`
6. `StudioRealityEntered`
7. `FutureApartmentEntered`
8. `FinalChoiceOpen`
9. `FinalChoiceCommitted`
10. `PostgameUnlocked`

Never resume darkness, an active chase, camera or movement lock, hidden-avatar state, temporary carried tools, an in-progress minigame, or half-applied cinematic presentation. Recovery collapses transient state to the nearest safe checkpoint.

### DEC-04 — Guest reconnect and late join

- A disconnected guest has 90 seconds to rejoin the same reserved session using a user-bound, one-use authenticated ticket.
- Guest loss does not pause shared deadlines or progression.
- Their existing eligibility record remains stable during grace.
- New or replacement invitations are forbidden after launch.
- A failed guest teleport at initial launch may use the same 90-second admission window while the admitted party continues.
- If the host fails initial teleport, the admitted server enters the normal 60-second host grace; it never promotes a guest into ownership.

### DEC-05 — Host loss by phase

| Phase | Required behavior |
|---|---|
| Lobby before launch | Cancel the unlaunched party safely; guests return to the no-party state |
| Loading/profile hydration | Fail closed; never construct a default host profile or begin tasks |
| Ordinary tasks, bank game, robots, deliveries, purchases, or postgame house loop | Enter one reason-counted 60-second `HostGrace`; reject mutation while paused; resume once or close/save/return on timeout |
| Horror reveal or chase | Restore the complete normal-world snapshot first, award no survival bonus or capture penalty, then enter `HostGrace` |
| Machine ready check before launch commit | Cancel the check, restore controls, then enter `HostGrace` |
| Black-hole launch after `FinaleLaunchCommitted` | Continue the checkpointed finale for remaining players; freeze further purchases; allow host rejoin at the latest finale checkpoint |
| Studio reality, future apartment, credits, or final choice | Continue for remaining players; disconnected players keep their personal checkpoint/choice pending |

### DEC-06 — Finale topology

The Blender studio reality and future apartment are distant, isolated, atomic streaming regions in the **same Roblox house place and same server**. The Time Machine finale does not use TeleportService. High-detail finale meshes, textures, sounds, scripts, and effects do not load during ordinary house play. Before moving players, request streaming around a validated checkpoint, verify collision and grounding, and show a stabilization transition. A timeout restores the prior safe checkpoint rather than risking a void spawn.

### DEC-07 — Supported performance floor

- Maintain at least 30 FPS in supported mobile play, including a four-player Stage 11 encounter and finale route.
- Reference coverage: iPhone 11-class hardware, iPad 9th generation, and a physical 4 GB Android device, plus representative desktop hardware.
- Targets: client frame-time p95 ≤ 40 ms; server frame-time p95 ≤ 25 ms.
- Settled client memory target: ≤ 1.3 GB on the reference tablet and ≤ 450 MB above the empty-place baseline attributable to this project.
- Ordinary streamed-region waits: ≤ 5 seconds. Finale preload may take ≤ 15 seconds with visible progress and safe retry/restore.
- After 50 cycles, settled memory growth must remain < 50 MB with no monotonic connection, timer, actor, or instance growth.
- Low-end LOD may reduce geometry, textures, reflections, lights, and particles without changing route composition, evidence, collision, or story.

### DEC-08 — Robot outcome reasons

Robot jobs terminate with server-owned codes, never an informal client/runtime guess:

- `Completed`
- `ValidDeadlineMiss`
- `WorldRegistryInvalid`
- `PathServiceFailure`
- `DynamicObstructionTimeout`
- `TargetRemoved`
- `StreamingUnavailable`
- `HostGraceCancelled`
- `EncounterInterrupted`
- `PlayerInterferenceVerified`
- `InternalError`

Only verified world/path/stream/target/internal faults pause or requeue without horror. A valid deadline miss follows the normal failure rule. Retries are bounded and visible.

### DEC-09 — Hiding occupancy

Each hiding location holds one player. First server-accepted entry wins; rejected entrants receive clear feedback. A hidden player can voluntarily exit except during a brief anti-spam debounce. Death, disconnect, encounter cleanup, anchor destruction, or stream-out releases occupancy and relocates the player to a validated nearby point. One inspection owns the spot at a time; duplicate hunters cannot apply duplicate capture.

### DEC-10 — Co-op economy intent

Full personal payouts are intentional. Balance machine, bunker, robot, boombox, chemistry, and other purchase costs against measured solo and four-player earning rates. Operation deduplication, eligibility snapshots, no repeat ending rewards, no replacement joins, and server-authoritative robot acceptance prevent farming exploits. Economy simulations must report time-to-purchase for solo and parties before balance changes ship.

### DEC-11 — Stage 11 duration

Stage 11 survival lasts **90 seconds**.

### DEC-12 — Feature-flag dependencies

- Production gameplay requires `Lobby=true` after Milestone 1 closes.
- `SecretExploration` requires `Horror=true` and runtime bunker/reveal prerequisites.
- `TimeMachineFinale` requires `Horror=true` and a valid Stage 11 host world.
- `Postgame` requires `TimeMachineFinale=true`, ending credit, and the player's personal Return entitlement.
- `StudioScenarioTools` is structurally absent from production builds, not merely disabled by a replicated boolean.
- An invalid combination disables the dependent feature, restores a safe checkpoint, and emits a structured configuration error. It never repairs a profile by granting progression.

---

## 5. State Ownership, Transactions, and Architecture

### 5.1 Three state domains

**Personal persistent profile**

- Cash and lifetime statistics.
- Personal machine stage/purchases when that player hosts.
- Discoveries, ending credit/choice, postgame entitlement, and accessibility preferences.
- Bounded transaction journal and operation deduplication data.

**Host world profile view**

- Bunker, installed automation, boombox/chemistry, machine stage, deliveries, and permanent objects physically instantiated in the active session.
- Guests may use permitted interactions but cannot write these fields.

**Ephemeral session state**

- Party membership, presence, eligibility snapshots, tasks, deadlines, pause reasons, robot jobs, encounter/hunter state, hiding/distractions/switches, ready checks, finale phase, and temporary presentation snapshots.
- Only named checkpoints cross server loss.

### 5.2 Formal state machines

Use enums and transition functions; never represent phase legality through unrelated booleans.

1. `SessionPhase`: `Lobby → Loading → Tasks ↔ Horror → Finale → Ending → Postgame → Closing`.
2. `TaskState`: `Unassigned → Active → Completed|Failed → RewardCommitted → Closed`.
3. `RobotJobState`: `Queued → Navigating → Performing → Completed|Requeued|Failed → RewardCommitted`.
4. `EncounterState`: `Idle → Reveal → Chase → Captured|Survived|Aborted → Restoring → Idle`.
5. `PlayerPresence`: `Connected → Loading → Active ↔ DeadRecovering → DisconnectedGrace → Left`.
6. `MachinePurchase`: `Offered → Authorized → Charged → Installed → Saved` with reconciliation from every interrupted step.
7. `FinalChoice`: `Unavailable → Offered → Submitted → CreditCommitted → Routed`.

The session coordinator alone authorizes phase transitions. Domain modules may not independently begin incompatible phases.

### 5.3 Exactly-once value operations

Every task reward, survival bonus, capture penalty, purchase, install, discovery, ending credit, and statistic update receives a server-generated operation ID containing no client-selected value. Maintain a pending/committed journal and a bounded ledger of at least the most recent 256 committed operations per profile.

Each record includes operation ID, session ID, type, player/profile, authoritative value, precondition/profile revision, state (`Pending`, `Committed`, `RolledBack`, `NeedsReconciliation`), and final result. Retries with the same ID return the committed result. Stale responses from superseded sessions are rejected even if an old ID has aged out of the bounded ledger.

Purchases follow a paid/pending/installed contract. An interruption resumes one paid delivery/install or rolls back cleanly; it never charges twice, grants twice, or silently loses money.

### 5.4 Time, randomness, and cleanup

- All deadlines use a monotonic server clock.
- Pause is a reason-counted token/set. Ending one reason cannot resume while another remains.
- Random behavior uses an injectable server random source and records the seed in tests.
- One cleanup owner snapshots or registers every reversible lighting, audio, NPC, prompt, door, camera, movement, collision, and UI mutation.
- Cleanup tolerates partial initialization, duplicate calls, missing instances, death, disconnect, and phase replacement, and always converges on normal state.

### 5.5 Domain modules and adapters

Use one source of truth behind focused services such as `PartyService`, `TaskScheduler`, `RobotJobService`, `EncounterService`, `NPCAdapter`, `DoorService`, `WorldRegistry`, `MachineService`, `FinaleService`, `ProfileService`, `TransactionLedger`, and `CleanupOwner`.

Inject small testable interfaces where nondeterminism or production safety requires them:

| Interface | Production | Test |
|---|---|---|
| `Clock` | Monotonic server time | Manually advanced fake clock |
| `RandomSource` | Server RNG | Fixed seed/scripted sequence |
| `ProfileStore` | Profile/DataStore adapter | In-memory store with failures |
| `TeleportAdapter` | Lobby/house TeleportService | Recorder with deterministic success/failure |
| `PathAdapter` | Navigation layer | Scripted paths/fault reason codes |
| `AssetRegistry` | Approved manifest | Complete/missing/mismatched fixtures |
| `AnalyticsSink` | Production telemetry | In-memory event collector |
| `SessionDirectory` | MemoryStore/session tickets | Fake admission/rejoin directory |
| `EffectsDriver` | Client presentation | Start/cleanup recorder |
| `SaveScheduler` | Retry/backoff/close handling | Deterministic failure sequence |

### 5.6 Public interfaces and server authority

Version public types for `SessionPhase`, `TaskState`, `RobotJobState`, `EncounterState`, `PlayerPresence`, `MachinePurchaseState`, `FinalChoiceState`, `PauseReason`, `CheckpointId`, `EligibilitySnapshot`, `OperationRecord`, and `RobotOutcomeReason`.

Clients send intent only. Every remote and state-changing prompt validates phase, role, membership, argument type/range, distance/context, rate limit, replay/operation identity, and authoritative server configuration. Clients cannot award cash, select a hunter, complete an inactive task, buy as host, force hiding/safety, change progression, or submit another player's choice.

### 5.7 Observability

Critical events record timestamp, server job/session/party ID, operation ID, affected players, prior/new state, reason code, build/config/flag version, result, and a sanitized error category. Event families cover profile lifecycle, party lifecycle, Ready/Start launch stages, tasks, robots, encounters, purchases, discoveries, finale checkpoints/choices/routes, remote rejections, and stream waits/fallbacks.

---

## 6. Visual, UI, Mobile, and Accessibility Standard

### 6.1 1980s lobby direction

The lobby is a lightweight **1980s suburban rec room**, not a generic neon sci-fi portal chamber. It must feel adjacent to the Cooper house while remaining clearly separate.

- Warm wood paneling, cream trim, period-patterned low-pile carpet.
- Mustard, rust, avocado, cream, muted teal, and warm charcoal palette.
- CRT television/VCR party display, analog clock, rotary phone, couch, floor lamp, bulletin board, house blueprints, and four clear rug/seating markers.
- A natural doorway/CRT launch presentation replaces oversized portal spectacle.
- Props must be original or cleared period-inspired assets with mobile-friendly collision and render cost.
- Use a scoped, idempotent visual updater after a dated backup. Never rerun the destructive one-time lobby builder on the installed lobby or house.

### 6.2 Shared UI theme

Create one versioned `CooperUITheme` used by lobby and compatible house interfaces:

- Cream primary text; warm charcoal/brown panels; mustard primary actions; avocado/teal success; rust error; unmistakable disabled state.
- Readable Gotham/Roboto Mono-style typography. Period character comes from composition, color, border, and props—not illegible novelty fonts.
- Consistent 8-pixel spacing grid, corner radii, strokes, focus rings, toast hierarchy, button states, and restrained motion.
- Lobby environment remains visible behind a responsive CRT/card panel rather than an opaque full-screen sheet.
- Ready, Start, party state, host-grace, errors, retries, and progress are communicated with text/icon/state, never color alone.
- Minimum 56-pixel touch targets, safe-area handling, scrolling, keyboard/gamepad focus, and no controls behind Roblox Core UI.
- Audit terminal, bunker terminal, notifications, dialogue, task HUD, stamina, robot chips, and modal stacking for consistency without a risky wholesale rewrite.

### 6.3 Visual acceptance

Capture and inspect no-party, host, guest, ready, not-ready, disabled Start, launching, launch failure, rejoin, full-party, host-grace, long-name, error, and success states on:

- desktop laptop;
- 320×480 minimum viewport;
- phone portrait and landscape;
- tablet landscape;
- ultrawide;
- low graphics quality;
- at least one physical phone and one physical tablet/large touch device.

Require body-text contrast ≥ 4.5:1, large text/control contrast ≥ 3:1, no clipping/overlap, correct keyboard/gamepad focus, reliable touch through rotation and input switching, and user sign-off plus two blind playtester reviews for attractiveness, 1980s recognition, goal clarity, and ease of use.

### 6.4 Accessibility

- Reduced flashing changes every reveal, portal, electrical, and light effect that could flash.
- Reduced camera motion covers shakes, FOV bends, vignette motion, avatar warping, and finale paths.
- Effect volume uses an intended audio group; essential information also has visual/caption feedback.
- Critical information never relies only on color, sound, or a brief image.
- Settings are personal, persistent, and named generically before the horror reveal.

---

## 7. Milestone Roadmap and Gates

### Milestone 0 — Safe Production Foundation — COMPLETE

> **Scope lock (2026-07-22):** the approved Milestone 0 implementation is the rollbackable, solo, pre-horror source baseline documented in `MILESTONE0_BASELINE.md`. The private staging-place workflow, production-only scenario tooling, and broad IP review remain follow-up production work; they are not enabled or silently bundled into this baseline. In particular, `StudioScenarioTools` stays `false` until it is separately approved.

Completed foundation:

- Dated rollback exports of environment, runtime, doors, and player scripts with SHA-256 hashes.
- Canonical mapping for the 25 active Studio sources and isolation of obsolete sources under `legacy/retired/`.
- Git baseline and verified commits.
- Schema 10→11 migration preserving money, purchases, deliveries, bunker, chemistry, boombox, automations, bank, candy, and machine data.
- Frozen flags for Lobby, Horror, Secret Exploration, Finale, Postgame, and Studio tools, all initially false in the M0 baseline.
- Exactly five ordered tasks, eleven machine stages, and the four approved family cutouts.
- Buyer-truck fairness, clean toy guidance, and accessible terminal Credits.
- Solo release contract until Milestone 1, baseline compilation/verifiers/regressions, UI smoke tests, and restoration documentation.

Milestone 0 remains complete. New cross-cutting tests in this bible become ongoing regression obligations; they do not erase the recorded rollback baseline.

### Milestone 1 — Lobby, Co-op, Launch Repair, and UI Closure — GATE OPEN

Existing topology:

- Lobby/start place `100748614383412`, universe `10480337589`, target capacity 50.
- Reserved house place `98645411943406`, same universe, capacity exactly four, secure within-universe access.
- Only Lobby may be enabled; Horror, Secrets, Finale, Postgame, and production scenario tooling remain disabled.

Required closure work:

- Repair Ready/Start according to Section 2.2 and pass the dedicated launch regressions in the integrated test program.
- Preserve invited parties, host identity, one shared five-task scheduler, full personal payouts, and host-only physical purchases.
- Replace any “present at completion” ambiguity with the DEC-02 eligibility snapshot contract.
- Add exactly-once operation identity and reconciliation to shared rewards and purchases.
- Implement 90-second guest rejoin/no replacement joins and phase-aware 60-second host loss.
- Validate live reserved-server allocation, user-bound one-use MemoryStore tickets, admission, replay rejection, partial teleport recovery, and safe return.
- Preserve sprint: walk 16, sprint 22, six seconds stamina, gradual regeneration, HUD visible only while used/recovering.
- Complete the 1980s rec-room lobby and shared UI/accessibility polish.
- Run all existing non-horror mechanics with 1, 2, and 4 players, including tasks, robots, deliveries, boombox, bank, bunker, chemistry, candy, doors, truck, rideables, and movement locks.

**Gate:** every P0, required P1, and all 81 rows of the original Milestone 1 verification matrix have evidence; Ready/Start works in Studio truthfully and in a privately published live flow; physical mobile tests pass; no S0/S1 issue remains.

### Milestone 2 — Task Pressure and Horror Skeleton

Build a new server-authoritative horror state machine. Do not adapt the incompatible retired crisis code.

**First-time pressure:**

- Cycle 1: five safe tasks; no horror penalty. A hidden 300-second timer may collect pacing telemetry only.
- Cycle 2: hidden 240-second deadline per task.
- Cycle 3: hidden 204-second deadline per task.
- If no natural timeout occurs, the first task of cycle 4 triggers a story-framed electrical fault.
- The forced fault is not the player's failure and cannot deduct money.
- After reveal, visible deadlines are 180, 153, 126, then 90 seconds for the fourth and later pressure cycles.
- Pause using reason-counted tokens during loading, cinematics, death recovery, host grace, and active horror. Do not pause merely because a terminal or bank UI is open.

**Hunter mapping:**

- Beer → George.
- Dishes or trash → Mary.
- Lost toy → Missy.
- Bank hacking → seeded server choice among the existing four, avoiding the previous hunter when possible.

**First encounter timeline:**

- Second 0: lights snap off; two seconds of near-total darkness and silence.
- A slow drone, vignette, and desaturation build.
- Second 5: character-specific supplied reveal image.
- Second 8: one unnatural step.
- Second 10: approach begins.
- Hunter speed 10, below normal walking speed 16.
- Survival lasts 30 seconds.
- Advanced survival tools are disabled for this guaranteed simple encounter.
- Every exit path uses idempotent complete restoration.

**Gate:** deterministic timing/mapping/penalty tests, complete snapshot restoration, interruption/reconnect coverage, and a responsibly disclosed blind test prove surprise, clarity, fairness, and recoverability.

### Milestone 3 — Horror Character Art and Presentation

- Edit each existing transparent cutout separately; never generate one combined batch.
- Preserve identity, face, pose, clothing, proportions, framing, and silhouette.
- Add only strong desaturation, cold skin grade, deeper facial/eye-socket shadows, faint cold-white eyes, and a subtle unnatural expression.
- No blood, wounds, gore, cards, text, or background.
- Reapply the original alpha silhouette for clean stable edges.
- Use new versioned filenames; never overwrite normal cutouts.
- Present all four variants for approval before Roblox upload.
- Character-specific reveal images are supplied separately by the user.
- Maintain a manifest mapping each character to normal cutout, scary cutout, reveal image, normal dialogue audio, horror audio, fallback, source hash, permission state, and approval state.
- Add generic reduced-flash, reduced-motion, and effect-volume settings without spoiling horror.

**Gate:** side-by-side identity, silhouette, alpha, crop, mapping, missing-asset fallback, desktop/mobile scale, accessibility, and rollback checks all pass.

### Milestone 4 — Survival Toolkit and House Pass

**Hiding:** under Missy's bed, Sheldon's bed, the parents' bed, two purpose-built bedroom/hall closets, and one tested large-furniture location. Prompts exist only during encounters. Occupancy and inspection follow DEC-09.

**Distractions:** three shared resettable plates/lamps or similar objects per encounter. Each produces one authoritative noise target; concurrent use of the final charge accepts once.

**Light switches:** connect proper room switches to existing lights. During eligible encounters, a switch stuns hunters in that room for 2.5 seconds with a 10-second per-switch cooldown and server distance/context checks.

**Doors and bunker:** unify front, patio, and garage doors behind one server adapter used by players, robots, and hunters. Bunker occupants are untargetable; the hatch seals without trapping anyone; reaching safety does not end an encounter while eligible players remain above.

**Gate:** every hunter paths through supported doors and around beds, appliances, furniture, truck, robots, players, bunker, and machine without phasing, permanent stall, body-block deadlock, or void recovery.

### Milestone 5 — Escalation and Automation Integration

| Machine stage | Hunters | Speed | Duration | Abilities |
|---|---:|---:|---:|---|
| 0–4 | 1 | 12 | 45 s | No doors or hiding inspection |
| 5–8 | Up to 2; second halfway | 15 | 60 s | Supported doors |
| 9–10 | Up to 3 | 18 | 75 s | Doors and hiding inspection |
| 11 | Up to all 4 | 19 | **90 s** | Doors, inspection; bunker most reliable |

Survival bonuses paid once to each eligible player: early $25, mid $60, late $120, postgame $180.

Robot-owned tasks become visible concurrent physical jobs while the scheduler assigns the next primary task. Reward/task commit occurs only at the existing authoritative visible completion point. Every job has its own deadline and eligibility/operation record. Horror pauses robot animation and deadline; normal state resumes afterward. Fault handling follows DEC-08 with bounded visible re-routing—no disappearance, teleporting, or furniture phasing. Mobile shows a primary deadline and compact job chips without covering prompts.

**Gate:** repeated four-player fully automated cycles, 50-cycle soak, concurrency, fault injection, navigation, UI density, economy simulation, and leak checks pass without duplicate payout or deadline drift.

### Milestone 6 — Optional Mystery Route

- Unlock a concealed bunker utility panel only after the bunker is built and first reveal completed.
- No task arrow or explicit tutorial exposes it.
- Physical tunnel → backrooms-style duplicate Cooper house → deeper maintenance exit → dome discovery.
- Zones remain distant streamed regions of the house place; they are never arbitrary map-edge discoveries.
- Personal tunnel/backrooms/dome flags commit exactly once.
- Use repeated rooms, production markings, impossible geometry, and constructed-world hints; no required progression or major currency reward.
- Entry requires a unanimous whole-party vote during a calm intermission. A reason-counted pause freezes scheduling, the group moves together, and all return to one validated checkpoint.
- Lock entry during warning/reveal/chase/host grace. A player already inside follows the shared transition policy and cannot use the route as a refuge exploit.

**Gate:** no early streaming/pop-in, void spawn, separation trap, deadline exploit, duplicate discovery, or unsafe reconnect; the entire game remains completable without entering.

### Milestone 7 — Rebuild the Time Machine

Preserve existing `machineStage` progress and centralized configured costs while replacing random stage props with:

1. Reinforced foundation and mounting rails.
2. Power distribution base.
3. Central containment chamber.
4. Left temporal coil.
5. Right temporal coil.
6. Clock-centered navigation console.
7. Lower portal ring.
8. Upper portal ring and field emitters.
9. Stabilizer arms.
10. Integrated conduits, lenses, and cooling.
11. Activation core, controls, and safety lever.

Every crate visibly contains the next component. Pieces align into one intentional collision footprint and science-fiction silhouette with an unmistakable clock/navigation centerpiece. Late horror may make the complete machine hum, frost, and pulse without activating early. Stage 11 exposes a host-only activation prompt and synchronized 1–4 player ready check.

**Gate:** migrate, purchase, interrupt, reconcile, visually inspect, and path around every stage 0–11; all costs come from one server configuration source; ready-check latency/disconnect paths pass.

### Milestone 8 — Black-Hole Finale, Ultra-Realistic World, and Ending

**Launch:** lock tasks, suspend horror, power coils in order, distort audio/camera/FOV, and form a black-hole portal. Use client echoes, trails, meshes, post-processing, and avatar afterimages rather than destructively moving the authoritative house. Provide reduced motion. One cleanup path restores controls/effects after completion, interruption, death, reset, or disconnect.

**Ultra-realistic pipeline:** graybox a 2–5 minute route in Roblox, approve it, then rebuild modular Blender kits with optimized PBR materials, UV atlases, low-complexity collision hulls, streaming, and automatic LOD. The world is uncanny and extremely realistic but bounded: soundstage/backlot, looping synthetic people, camera rigs, television showing the Cooper simulation, “Medford Set” evidence, and discarded scripts. No tasks, normal HUD, robots, timers, or upgrade prompts appear.

**Same-place streaming:** preload the distant atomic finale region during launch. Do not move a player until collision/grounding is validated. Slow clients receive visible stabilization; permanent failure restores `MachineStageInstalled` or `FinaleLaunchCommitted` safely. Scope lighting, audio, camera, and post-processing so house values restore exactly.

**Ending:** black-hole launch → studio reality → future apartment → personal choice. Stay commits ending and routes to lobby. Return commits ending and personal postgame entitlement, completes credits, routes to the lobby, and takes effect in the player's next owned house session. Guests keep their own machine stage. Replay/direct destination travel never repeats rewards or choice credit.

**Gate:** all solo choices, all four two-player combinations, all sixteen four-player binary combinations, checkpoint interruptions, mixed loading speeds, off-route exploration, reduced motion, low graphics, physical mobile, performance, and repeat travel pass.

### Milestone 9 — Postgame Horror and Retention

- Begin with a dedicated design specification for machine maintenance; do not code an undefined loop.
- Return-entitled players activate postgame only in a valid owned session.
- Family hunts remain.
- A separately approved non-family anomaly has a 20% eligible chance and cannot appear back-to-back. It cannot spawn before design, art, audio, and asset approval.
- Persist encounters survived/caught, current/longest streak, fastest full task cycle, discoveries, and ending choices exactly once.
- Add cosmetics, daily challenges, global boards, and seasonal variants only after the core postgame loop is stable.

**Gate:** maintenance ownership/overlap rules, anomaly selection, stats, migrations, multiplayer ownership, 50-cycle soak, retention clarity, accessibility, and security pass.

### Additional bunker activities — Deferred

After the first horror vertical slice, design two or three candidates tied to chemistry, machine research, or postgame maintenance. Every selected activity needs a one-page rules spec covering start, success, failure, abandon, interruption, resume, reward/automation ownership, co-op behavior, mobile design, exploit prevention, and horror integration. Prototype with humans before economy integration. Do not ship “press button and wait” filler.

---

## 8. Delivery Cuts, Release Process, and Risk Register

### 8.1 Delivery order

1. Canonical bible and requirement/test traceability.
2. Ready/Start P0 repair and truthful Studio/live launch diagnostics.
3. Reconfirm Milestone 0 regression and finish deterministic test foundations.
4. Complete all Milestone 1 live, persistence, mobile, UI, and regression gates.
5. Milestones 2–4 as one horror vertical slice.
6. Milestone 5 core systems alpha and 50-cycle/economy validation.
7. Milestone 7 machine beta.
8. Milestone 8 finale beta.
9. Milestone 6 optional mysteries may be authored earlier but cannot delay the first complete ending.
10. Milestone 9 begins with maintenance design, then implementation.

### 8.2 Change and release cadence

- Every change: compile/type/lint, unit, fast integration, remote registry, and asset/config validation.
- Every core batch: affected milestone scenarios, migration fixtures if relevant, two-client race smoke, error-log audit, and bug regressions.
- Scheduled development: full unit/integration, scripted 1/2/4 client scenarios, deterministic alternate seeds/order, 10-cycle soak, and production-debug-surface scan.
- Milestone candidate: all milestone cases, published private 1/2/4 player E2E, isolated persistent data, real devices, security, and evidence package.
- Release candidate: all enabled P0/P1 tests, migrations, real reserved-server/reconnect matrix, 50-cycle soak, lowest-device performance, blind/new-player/accessibility tests, asset/IP and maturity sign-off, and rollback drill.
- Never use live player data for Studio/staging tests. Never label BLOCKED or NOT RUN evidence as PASS.
- Do not create a new place, overwrite a place, change the start place, or publish without explicit authorization and fresh backups.

### 8.3 Risk register

| Risk | Likelihood without controls | Impact | Required mitigation |
|---|---:|---:|---|
| Duplicate/lost cash or upgrades | High | Critical | Operation IDs, journal, session conflicts, fault tests |
| Ready/Start or live admission failure | Present | Critical | P0 repair, launch checkpoints, published E2E |
| Host/guest ending deadlock | High | Critical | DEC-01 personal commit/next-owned-session rule |
| Debug tools exposed | Medium | Critical | Structural exclusion and production scan |
| Old save corruption | Medium | Critical | Versioned fixtures, rollback, idempotent migration |
| Hunter/robot path instability | High | Major | Shared doors, path grid, reason codes, soak |
| Horror cleanup corruption | Medium | Critical | Single snapshot/cleanup owner and fault tests |
| Four-player economy inflation | Medium–high | Major | Intentional full-pay simulation and anti-replay |
| Mobile/finale performance miss | High | Major | Reference devices, graybox budget, LOD profiling |
| Streamed-zone void spawn | Medium | Critical | Validated anchors, load gates, timeout fallback |
| Choice credit lost during routing | Medium | Critical | Commit before route and reconciliation |
| Invalid feature combination | Medium | Major | Dependency validator and config version |
| AI-generated tests give false confidence | High | Major | Requirement assertions, fault/mutation cases, human review |
| Scope outruns polish | High | Major | Vertical slices; mysteries/postgame deferred |
| Asset/IP permission problem | Material | Release-critical | Manifest, permission owner, replacement path, legal/rightsholder review |

---

# Part II — Integrated Verification Program

The following program incorporates every original named test and invariant from `COOPER_TIME_MACHINE_TEST_PLAN.md`: **318 named tests plus 30 global invariants = 348 requirements**, with the twelve `DEC` items resolved above. Additional Ready/Start and UI regressions are listed without renumbering the original suite.

## 9. Test Policy and Result Model

### 9.1 Mandatory rules

- No milestone advances because its happy path worked once.
- Every automatable production defect receives a regression test before or with its fix.
- Economy, persistence, party, and story transitions are idempotent.
- Assert externally observable behavior and invariants, not a copy of implementation structure.
- Never weaken assertions, delete failing tests, insert arbitrary waits, or change a requirement silently to obtain green status.
- Inject clock and randomness; do not wait through real 90–300 second timers or rely on statistical luck.
- Scenario controls are unreachable in published production even if an exploiter guesses names.
- Test DataStores, reserved servers, credits, and teleports use a private experience or isolated namespace, never live data.

### 9.2 Result states and severity

- `PASS`: expected state, presentation, persistence, and logs match.
- `FAIL`: a requirement or invariant is violated.
- `BLOCKED`: required design, asset, environment, permission, or adapter is missing.
- `NOT RUN`: scheduled but not executed.
- `ACCEPTED RISK`: written owner, reason, impact, workaround, and expiration milestone required.

| Severity | Meaning | Release rule |
|---|---|---|
| S0 | Persistent value/security corruption, arbitrary server mutation, exposed debug authority, party-wide stranding | Zero open |
| S1 | Progression blocker, lost progress, broken lifecycle, incomplete restoration | Zero open |
| S2 | Major fairness, multiplayer, accessibility, performance, or feature defect | Zero for gate unless explicitly deferred |
| S3 | Visible defect with workaround and no data/progression impact | Track before shipping |
| S4 | Negligible cosmetic issue | Product decision |

## 10. Test Architecture

```text
Tests/
  Unit/{Economy,Scheduling,Horror,Persistence,Party,Finale}/
  Integration/{Profile,TaskFlow,EncounterFlow,RobotFlow,MachineFlow,EndingFlow}/
  Scenarios/{M0,M1,M2,M3,M4,M5,M6,M7,M8,M9}/
  Security/
  Performance/
  Fixtures/
  Fakes/
  Helpers/
  Reports/
```

Layers: static/type/lint on every change; deterministic unit; integration with fake external services; real DataModel Studio scenarios; scripted multi-client races; privately published teleport/DataStore E2E; physical hardware/performance; and human exploratory/blind testing.

The Studio scenario runner may choose fixture, party size/host, milestone/test ID, clock position, deterministic hunter, path failure, capture/survival, death, disconnect/rejoin, machine stage, streaming delay, or ending choice and must return structured assertions. Its privileged endpoints must be absent from production.

## 11. Global Invariants

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

## 12. Canonical Test Fixtures

### 12.1 Profiles

Version immutable inputs and expected outputs for new player; baseline without upgrades; each permanent purchase; machine stage 0–11; bunker built/unbuilt; supported robot combinations; chemistry/boombox combinations; cash 0, 1, 24, 25, 499, 500, below cap, and cap; every task position; reveal false/true; pairwise discovery flags plus all-off/all-on; every ending/postgame state; missing/unknown/corrupt fields; obsolete crisis data; interrupted transaction; and duplicate operation ID.

### 12.2 Parties, randomness, and faults

- Solo; 2-player; 4-player; late join attempt; guest disconnect/rejoin; host loss/rejoin at 0, 59, and after grace; every disconnect order; host stage 11 with guest stages 0/5/10; mixed accessibility; all 16 four-player choices.
- Script RNG for every previous bank hunter, anomaly selection/no-repeat, distraction/search choice, and random path fallback.
- Every external adapter supports success, immediate failure, timeout, fail-once/succeed, duplicate callback, completion after disconnect, and stale prior-session response.

## 13. Milestone 0 Test Suite

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
| M0-010 | P0 | Try invalid flag dependency combinations | Section 4 dependency fallback and diagnostic event; no corrupt state | Unit/scenario |
| M0-011 | P0 | Search published DataModel/network surface for scenario controls | No debug UI, remote, command, bindable path, or privileged module is usable | Security/published |
| M0-012 | P0 | Fire guessed scenario/debug remotes in published test | Rejected and logged; no state change | Security |
| M0-013 | P1 | Compare baseline server/client logs before/after foundation | No new unexpected warnings/errors | Regression |
| M0-014 | P1 | Join with slow character/asset loading | Timers/tasks do not begin before player readiness | Scenario/network |
| M0-015 | P1 | Kill/reset during baseline tasks | Existing loop recovers exactly as baseline | Scenario |
| M0-016 | P1 | Validate rollback procedure | Documented rollback restores playable version without live data damage | Release drill |
| M0-017 | P1 | Verify isolated test DataStore names/universe | No live profile is read or written | Configuration audit |
| M0-018 | P1 | Audit asset manifest/permission checklist | Every likeness/third-party asset has owner/status/source fields | Manual audit |

**M0 evidence:** baseline comparison, migration fixtures, production debug-surface report, solo physical-mobile run, and rollback record. The recorded 2026-07-22 baseline remains accepted; execute these rows again when current shared foundations change.

## 14. Milestone 1 Test Suite

### 14.1 Lobby, party, teleport, and ownership

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-001 | P0 | Solo launch from lobby | Immediate launch to valid private house session as host | Published E2E |
| M1-002 | P0 | 2-player create/join/ready/launch | Correct host/membership arrive in one reserved session | Published E2E |
| M1-003 | P0 | 4-player create/join/ready/launch | Exactly four intended members; no outsider | Published E2E |
| M1-004 | P0 | Tamper with client host ID/party list | Server ignores it and uses validated membership | Security |
| M1-005 | P0 | Reuse stale teleport data | Rejected/routed safely; cannot impersonate host | Security/E2E |
| M1-006 | P0 | Teleport fails once then succeeds | Bounded retry/fallback; no visible duplicate session | Published E2E |
| M1-007 | P0 | One member fails teleport | Guest gets 90-second rejoin; host failure invokes host grace; manifest remains coherent | Published E2E |
| M1-008 | P1 | Host leaves lobby before launch | Unlaunched party cancels safely | Multi-client |
| M1-009 | P1 | Guest leaves during ready check | Membership/readiness update; stale guest cannot launch | Multi-client |
| M1-010 | P1 | Ready spam/reordered replies | One final authoritative ready value; no duplicate launch | Multi-client/network |
| M1-011 | P1 | Outsider guesses access/session token | Access denied | Security/E2E |
| M1-012 | P1 | Delayed/missing teleport metadata | Fail closed and return safely; never infer identity | E2E |

### 14.2 Shared scheduler and rewards

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-013 | P0 | Two players complete same task in same frame | Task once; each snapshot-eligible player rewarded once | Multi-client |
| M1-014 | P0 | Four clients spam completion | One completion; no extra cash/stat | Security/multi-client |
| M1-015 | P0 | Guest completes task | Shared advance; full reward once to each eligible member | Multi-client |
| M1-016 | P0 | Host completes task | Same result; ownership does not affect ability | Multi-client |
| M1-017 | P0 | Client supplies reward amount | Server config wins; payload value rejected | Security |
| M1-018 | P0 | Disconnect during reward commit/rejoin | Exactly one reward after reconciliation | Integration/E2E |
| M1-019 | P0 | Some saves succeed, one fails | Retry only incomplete commits; no duplicates | Fault injection |
| M1-020 | P1 | Late/replacement join after launch | Rejected by DEC-04; eligibility unchanged | Multi-client |
| M1-021 | P1 | Player dies during completion | Existing snapshot identity; no respawn duplicate | Multi-client |
| M1-022 | P1 | Repeat five tasks with four players | No skip, duplicate, or forked order | Soak |

### 14.3 Host-only construction

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-023 | P0 | Guest attempts bunker/machine via UI | UI denies/hides; server rejects | Multi-client/security |
| M1-024 | P0 | Guest manually fires purchase remote | No cash or world change | Security |
| M1-025 | P0 | Host and guest request same purchase | One host-authorized transaction | Multi-client |
| M1-026 | P0 | Host purchase interrupted charge→install | Resume/rollback without loss/duplicate | Fault injection |
| M1-027 | P1 | Host purchase replication | All clients see same physical state | Multi-client |
| M1-028 | P1 | Guest later starts own session | Does not inherit host upgrade | Published E2E |

### 14.4 Host/guest loss and reconnect

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-029 | P0 | Host disconnects during ordinary task | One pause; 60-second host grace | Multi-client |
| M1-030 | P0 | Host rejoins at 59 seconds | Same owner/session; resumes once | Published E2E |
| M1-031 | P0 | Host returns after expiry | Old session does not resume; profiles safe | Published E2E |
| M1-032 | P0 | Host never returns | Save once and return members to lobby | Published E2E |
| M1-033 | P0 | Host-disconnect signal delivered twice | One timer and one close path | Fault injection |
| M1-034 | P1 | Guest disconnects/rejoins within 90 seconds | No shared pause, duplicate membership, or duplicate eligibility | Published E2E |
| M1-035 | P1 | All players disconnect during grace | Safe close; no pending write lost/duplicated | E2E |

### 14.5 Sprint and input

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1-036 | P1 | Hold Shift from full stamina | Speed 22 for six moving seconds, then 16 | Unit + scenario |
| M1-037 | P1 | Release early/regenerate | Configured regeneration; HUD hides only full/idle | Scenario |
| M1-038 | P1 | Spam sprint toggle | No negative stamina, stacking, or remote flood | Scenario/security |
| M1-039 | P1 | Reset/die while sprinting | Speed/stamina/UI restore safely | Scenario |
| M1-040 | P1 | Mobile sprint on landscape resolutions | Reachable/readable; no prompt/thumb overlap | Device + hardware |
| M1-041 | P1 | Locally alter WalkSpeed | Server prevents persistent unfair speed | Security |
| M1-042 | P2 | Switch touch/keyboard/controller | Correct presentation; no duplicate bindings | Device/input |

### 14.6 Ready/Start regression addendum

These tests are additional to the original 348 requirements.

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M1X-001 | P0 | Host presses Ready once | Server commits true; UI and `canLaunch` update from same revision | Integration/client |
| M1X-002 | P0 | Observe ten polls plus heartbeat after Ready | Ready stays committed | Fake clock/integration |
| M1X-003 | P0 | Press Start immediately after Ready acknowledgment | Launch is not rejected by Ready cooldown | Integration |
| M1X-004 | P0 | Ready/unready requests/replies reorder | Highest accepted revision wins; UI never rolls back to stale state | Network simulation |
| M1X-005 | P0 | All members ready | Host Start enables with accessible state/reason text | Multi-client/UI |
| M1X-006 | P0 | One member unready or missing | Start stays disabled and names the reason | Multi-client/UI |
| M1X-007 | P0 | Guest attempts Start | Rejected; host/party unchanged | Security |
| M1X-008 | P0 | Solo Play | No unnecessary Ready step; one launch | Published E2E |
| M1X-009 | P0 | Double-click Start | One manifest, reservation, ticket per member, and teleport request | Concurrency |
| M1X-010 | P0 | Reservation/ticket/teleport/admission failure | Retryable lobby state; no duplicate session/ticket | Fault injection/E2E |
| M1X-011 | P0 | Studio Start preview | Opens the verified in-place house, removes the lobby, restores camera/controls, loads normal HUD/controllers, and permits movement; explicitly remains non-evidence for live teleport | Studio scenario |
| M1X-012 | P0 | Published solo/2/4-player Start | Every player reaches grounded authorized house; no lobby stall/void | Published E2E |
| M1X-013 | P0 | Phone/tablet taps Ready/Start | One activation per tap; controls do not overlap | Physical hardware |
| M1X-014 | P1 | Long names/full party/errors/host grace | Responsive UI remains legible and operable | Visual/device |
| M1X-015 | P1 | Keyboard/gamepad/touch focus | Focus is visible; input switching does not duplicate activation | Device/input |

**M1 evidence:** solo/2/4-player published recordings, launch-checkpoint logs, MemoryStore/ticket/reconnect report, exactly-once reward/purchase logs, mobile captures and physical-device results, remote-security matrix, full existing-feature regression, and 1980s visual sign-off.

### 14.7 Historical Milestone 1 closure matrix

This preserves the row-level gate as it stood before the current Ready/Start repair. New runs update evidence and status without deleting history.

#### Automated and lobby

| ID | Check | Historical status | Recorded evidence / remaining obligation |
|---|---|---|---|
| A01 | Compile every local Luau source | PASS | 79/79 on 2026-07-22 |
| A02 | `git diff --check` | PASS | Clean on 2026-07-22 |
| A03 | House verifier edit mode | PASS | 530 checks |
| A04 | House verifier one-player runtime | PASS | 616 checks |
| A05 | Lobby verifier edit mode | PASS | 181 checks |
| A06 | Lobby verifier runtime | PASS | 225 checks |
| A07 | Every Milestone 0 gameplay regression | NOT RUN | Run all current suites |
| A08 | Client-authority scan | PASS | 13 active client sources scanned |
| L01 | Play Solo Studio safe preview | PASS | Validation notice shown; not live teleport proof |
| L02 | Create Party | PASS | Host controls updated |
| L03 | Ready and cancel | PASS | Historical interaction passed; reopened by current Ready/Start defect |
| L04 | Host Launch Studio preview | PASS | Historical safe preview only; reopened by current defect |
| L05 | Leave Party | PASS | Returned to no-party state |
| L06 | Simulated responsive layouts | PASS | Desktop, iPhone 14 portrait/landscape, iPad landscape |
| L07 | Lobby movement presentation | PASS | Mobile joystick/jump did not cover UI |
| L08 | Physical phone/tablet | NOT RUN | Real touch, safe area, keyboard, and rotation required |
| L09 | Fresh lobby initialization | PASS | No forced global focus crash; published lobby v308 |

#### Party and teleport

| ID | Check | Historical status | Required evidence |
|---|---|---|---|
| P01 | Solo live launch | NOT RUN | Reserved house; player host |
| P02 | 2-player invite/ready/launch | NOT RUN | Exact two in same session/task |
| P03 | 4-player invite/ready/launch | NOT RUN | Exact four; server cap four |
| P04 | Fifth invite/join | NOT RUN | Reject without party mutation |
| P05 | Launch with unready guest | NOT RUN | Clear rejection |
| P06 | Guest attempts launch | NOT RUN | Reject; state unchanged |
| P07 | Replay consumed ticket | NOT RUN | Fail closed |
| P08 | Missing/expired/altered/nonmember metadata | NOT RUN | Fail closed and safe return |
| P09 | Inspect payload/replication | NOT RUN | No access code exposed |
| P10 | Two simultaneous parties | NOT RUN | Separate reserved servers/manifests |
| P11 | Duplicate active-user connection | NOT RUN | Existing valid player remains authoritative |

#### Shared tasks and rewards

| ID | Check | Historical status | Recorded evidence / remaining obligation |
|---|---|---|---|
| T01 | Guest completes George beer | PARTIAL | 4-client Studio paid all $55 once; 2-player/live remain |
| T02 | Guest completes dishes | NOT RUN | Full $30 once to snapshot roster |
| T03 | Host starts trash; guest delivers | NOT RUN | Full $40 once |
| T04 | Guest returns Missy's toy | NOT RUN | Full $70 once |
| T05 | Guest completes bank game | NOT RUN | Authoritative reward once |
| T06 | Simultaneous final interaction | PARTIAL | Studio duplicate rejected; live contention remains |
| T07 | Join after task began | NOT RUN | Now rejected by no-late-join rule; snapshot unchanged |
| T08 | Guest leaves before completion | NOT RUN | DEC-02 grace/forfeit rule, no absent unsafe write |
| T09 | Full five-task cycle | NOT RUN | One shared cycle/index |
| T10 | Every installed task robot | NOT RUN | Physical job visible; one acceptance/reward |
| T11 | Task while guest profile hydrates | NOT RUN | Loading guest excluded from snapshot; no lost pending award |

#### Host authority and persistence

| ID | Check | Historical status | Recorded evidence / remaining obligation |
|---|---|---|---|
| H01 | Guest buys Time Machine stage | PASS | 4-client Studio rejected without mutation |
| H02 | Guest buys bunker | NOT RUN | Reject; no debit/build |
| H03 | Guest buys boombox/autoplay | NOT RUN | Reject; no debit/delivery |
| H04 | Guest buys robot | NOT RUN | Reject; no debit/delivery |
| H05 | Guest buys chemistry | NOT RUN | Reject; no debit/delivery |
| H06 | Host buys every persistent system | PARTIAL | One machine purchase passed; others remain |
| H07 | Guest later hosts own party | NOT RUN | Personal value retained; host upgrades not inherited |
| H08 | Host rejoin/server shutdown with pending work | NOT RUN | All paid/pending M0 progression survives once |

#### Host loss

| ID | Check | Historical status | Recorded evidence / remaining obligation |
|---|---|---|---|
| D01 | Host disconnect ordinary task | PASS | Studio entered ~60-second `HostGrace` |
| D02 | Guest mutation during grace | PARTIAL | Task/cash rejection passed; deliveries/robot deadlines remain |
| D03 | Host returns ~30 s | NOT RUN | Resume same session once |
| D04 | Host returns ~59 s | NOT RUN | Valid before expiry |
| D05 | Host absent through expiry | PARTIAL | Studio reached Closing; live save/teleport remain |
| D06 | Forged non-host rejoin | NOT RUN | Reject; grace remains |
| D07 | Server closes during grace | NOT RUN | Save loaded profiles/release leases |
| D08 | Host disconnects during hydration | NOT RUN | No default-profile takeover/stuck Loading |
| D09 | Host disconnect after >1 hour | NOT RUN | Fresh grace or documented cap |
| D10 | Last guest leaves during grace | NOT RUN | Save/release/close; no lingering lease |
| D11 | Host returns with paid delivery pending | NOT RUN | Resume once, neither lost nor duplicated |
| D12 | Bank pattern interrupted by grace | NOT RUN | Fair freeze/reset; no unavoidable failure |
| D13 | MemoryStore `UpdateAsync` retry consuming ticket | NOT RUN | Only final returned claim admits |
| D14 | Host profile lease invalidated | NOT RUN | Fail closed into recovery/close |
| D15 | Carried beer/trash/toy and truck callback during grace | NOT RUN | Inert mutation; same task resumes safely |

#### Sprint and mobile

| ID | Check | Historical status | Recorded evidence / remaining obligation |
|---|---|---|---|
| S01 | Shift sprint/release | PASS | Server speed 22 then 16 |
| S02 | Sprint while stationary | NOT RUN | No drain |
| S03 | Six-second exhaustion | PARTIAL | Drain observed; timing/exploit remain |
| S04 | Release/regenerate | NOT RUN | Predictable gradual recovery |
| S05 | Full/idle | NOT RUN | HUD hidden |
| S06 | Drain/recover | NOT RUN | HUD visible then hides at full |
| S07 | Touch button | NOT RUN | Safe/reliable tap state |
| S08 | Terminal/sit movement lock | PARTIAL | Computer exit passed; bunker/seat remain |
| S09 | Carry multiplier | NOT RUN | Composes without exploit |
| S10 | Reset while sprinting | NOT RUN | Full state/input/UI restore |
| S11 | Remote spam/local speed edit | NOT RUN | Rate limit and authoritative correction |
| S12 | Four-player isolation | PASS | Studio per-player isolation passed |

#### Regression and release

| ID | Check | Historical status | Recorded evidence / remaining obligation |
|---|---|---|---|
| R01 | Four normal PNG NPCs | NOT RUN | Exact approved roster/art/dialogue/catchphrases |
| R02 | All baseline features | NOT RUN | Five tasks, robots, deliveries, boombox, bank, bunker, chemistry, candy |
| R03 | Four-player collision/load | NOT RUN | Doors/truck/furniture/robots/players; no deadlock/void |
| R04 | Retired/horror runtime audit | PASS | Only Lobby enabled |
| R05 | Logs through all scenarios | PARTIAL | Lobby clean; full house regression remains |
| R06 | Creator Dashboard topology | PASS | Lobby start/cap 50; secure house cap four |
| R07 | Rollback | PASS | Dated exports, hashes, and Git procedure recorded |

Historical totals: **22 PASS, 8 PARTIAL, 51 NOT RUN**. The Ready/Start report reopened the historical interaction rows; the 2026-07-22 local Studio repair now passes the dedicated regressions, while the published solo/2/4-player launch rows remain open. History stays recorded rather than being rewritten.

## 15. Milestone 2 Test Suite

### 15.1 Timing and cycle progression

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M2-001 | P0 | Complete cycle-1 tasks after telemetry time | No horror penalty/failure possible | Fake clock/integration |
| M2-002 | P0 | Cycle-2 completes at 239.9 s | Safe before 240-second deadline | Fake clock |
| M2-003 | P0 | Cycle-2 reaches 240 s | Natural failure once | Fake clock |
| M2-004 | P0 | Cycle-3 reaches 204 s | Correct one-time failure | Fake clock |
| M2-005 | P0 | No timeout through cycle 3 | Cycle-4 task 1 forced electrical fault | Integration |
| M2-006 | P0 | Forced reveal | No deduction; story fault wording | Integration/UI |
| M2-007 | P0 | First post-reveal pressure cycle | 180 seconds | Unit/integration |
| M2-008 | P0 | Second/third/fourth+ pressure cycles | 153/126/90 seconds exactly | Unit |
| M2-009 | P0 | Loading pause | Remaining time unchanged | Fake clock |
| M2-010 | P0 | Cinematic pause | Remaining time unchanged | Fake clock |
| M2-011 | P0 | Death-recovery pause | Remaining time unchanged | Fake clock |
| M2-012 | P0 | Active-horror pause | Remaining time unchanged | Fake clock |
| M2-013 | P0 | Task terminal/bank UI open | Deadline continues | Fake clock/UI |
| M2-014 | P0 | Loading and cinematic overlap | Resume only after both clear | Fake clock |
| M2-015 | P0 | Duplicate pause/resume | No underflow/premature resume | Unit |
| M2-016 | P1 | Server frame stall | Monotonic time, not frame count | Integration |
| M2-017 | P1 | Client clock/FPS manipulation | No effect | Security |

### 15.2 Hunter assignment

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M2-018 | P0 | Beer failure | George | Unit |
| M2-019 | P0 | Dishes failure | Mary | Unit |
| M2-020 | P0 | Trash failure | Mary | Unit |
| M2-021 | P0 | Lost toy failure | Missy | Unit |
| M2-022 | P0 | Bank failure for each previous hunter | Existing four only; avoid prior when possible | Seeded unit |
| M2-023 | P0 | Client requests hunter | Rejected; server mapping wins | Security |
| M2-024 | P1 | Unknown task type | Safe fallback; no unapproved character | Unit/integration |

### 15.3 First encounter, result, and restoration

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M2-025 | P0 | Encounter begins | Lights off immediately; phase Reveal | Scenario |
| M2-026 | P0 | Check 0/2/5/8/10 seconds | Darkness/silence, build, image, step, chase once within tolerance | Fake clock/client recorder |
| M2-027 | P0 | First hunter speed | 10, below walk 16 | Integration |
| M2-028 | P0 | Survive 30 seconds | One survival and restoration | Fake clock |
| M2-029 | P0 | Capture before 30 seconds | Ends once; later survival callback inert | Integration |
| M2-030 | P0 | Two captures same frame | One result and penalty operation | Multi-client |
| M2-031 | P0 | Guaranteed reveal capture | No money deducted | Multi-client |
| M2-032 | P0 | Natural capture at cycle N | Eligible members lose formula amount exactly | Parameterized unit/integration |
| M2-033 | P0 | Cash below loss | Cash zero, never negative | Unit |
| M2-034 | P0 | High cycle/cap | Maximum loss 500 | Unit |
| M2-035 | P0 | Duplicate result callback | Reward/penalty/stats once | Fault injection |
| M2-036 | P0 | Normal survival cleanup | Exact light/NPC/door/prompt/camera/sound/movement snapshot | Scenario diff |
| M2-037 | P0 | Capture cleanup | Same complete restoration | Scenario diff |
| M2-038 | P0 | Death during reveal | No camera lock/duplicate encounter | Scenario |
| M2-039 | P0 | Reset during chase | No stale target/effect | Scenario |
| M2-040 | P0 | Host loss during reveal/chase | Restore first, no result, then HostGrace | Multi-client/E2E |
| M2-041 | P0 | Last player disconnects | Persist safe checkpoint only | E2E |
| M2-042 | P0 | Cleanup called three times | Same result as once | Unit/integration |
| M2-043 | P0 | Cleanup sub-operation throws | Others continue; retry converges | Fault injection |
| M2-044 | P1 | Task start during encounter | Rejected/queued by state machine | Integration |
| M2-045 | P1 | Encounter start while active | No second encounter | Integration |

Blind tests disclose moderate-intensity horror, darkness, audio changes, and accessibility options without revealing the trigger/cycle. Record surprise, comprehension, fairness, recovery, and distress; do not optimize only for maximum fear.

## 16. Milestone 3 Test Suite

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M3-001 | P0 | Manifest for George/Mary/Missy/Georgie | Normal, scary, reveal, normal audio, horror audio complete | Automated asset audit |
| M3-002 | P0 | Swap each NPC into horror/back | Correct character; no cross-mapping | Scenario |
| M3-003 | P0 | Every encounter exit path | Normal art/audio always returns | Scenario |
| M3-004 | P0 | Compare scary silhouette to source alpha | No background/fringe/crop/expansion beyond tolerance | Image QA |
| M3-005 | P0 | Actual scale on phone/tablet/desktop | Identity recognizable; no edge artifacts | Manual/hardware |
| M3-006 | P0 | Audit blood/wounds/gore/text/background | None | Manual + metadata |
| M3-007 | P0 | Diff normal cutout IDs | Existing normal presentation unchanged | Automated manifest diff |
| M3-008 | P1 | Missing scary asset | Safe fallback; no wrong character/broken encounter | Integration |
| M3-009 | P1 | Missing reveal/audio | Playable encounter; diagnostic logged | Integration |
| M3-010 | P0 | Reduced flashing before first reveal | Approved reduced transition | Client scenario |
| M3-011 | P0 | Reduced camera motion | No forced high-motion effects; understandable | Client scenario |
| M3-012 | P1 | Effect volume 0/25/100% | Correct bus; essential feedback preserved | Client/audio QA |
| M3-013 | P1 | Settings across places/sessions | Personal choices persist | Published E2E |
| M3-014 | P1 | Change settings during encounter | Applies safely without phase corruption | Scenario |
| M3-015 | P1 | Asset version rollback | Prior approved version restores cleanly | Release drill |

## 17. Milestone 4 Test Suite

### 17.1 Hiding

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-001 | P0 | Audit all specified hiding spots | Anchors exist/reachable | World audit |
| M4-002 | P0 | Outside encounter | No prompt or trigger | Scenario/security |
| M4-003 | P0 | Enter each spot in encounter | Hidden and untargetable | Scenario |
| M4-004 | P0 | Client fakes hidden state | Rejected; targeting unchanged | Security |
| M4-005 | P0 | Two players enter simultaneously | First accepted; second rejected without overlap/trap | Multi-client |
| M4-006 | P0 | Death/reset/disconnect while hidden | Occupancy and player state clear | Multi-client |
| M4-007 | P0 | Encounter ends while hidden | Safe exit/restoration | Scenario |
| M4-008 | P0 | Late hunter inspects occupied spot | One authoritative inspection/capture | Seeded scenario |
| M4-009 | P1 | Anchor streams out/removed | Emergency unhide/validated relocation | Fault injection |
| M4-010 | P1 | Enter/exit spam | No duplicate occupancy/jitter/stale untargetability | Scenario |

### 17.2 Distractions

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-011 | P0 | Use three distractions | One target each; shared count decrements | Multi-client |
| M4-012 | P0 | Use fourth | Clear rejection; count nonnegative | Multi-client |
| M4-013 | P0 | Two clients trigger final charge | One accepted, one rejected | Multi-client |
| M4-014 | P1 | Hunter already investigating | Configured priority/retarget | Seeded integration |
| M4-015 | P1 | Encounter cleanup | Objects/count reset next encounter | Scenario |

### 17.3 Light switches and stun

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-016 | P0 | Switch with hunter in room | One 2.5-second stun | Fake clock/integration |
| M4-017 | P0 | Reuse at 9.9 s | Rejected | Fake clock |
| M4-018 | P0 | Reuse at 10 s | Accepted | Fake clock |
| M4-019 | P0 | Remote switch use/distance | Server rejects | Security |
| M4-020 | P1 | Multiple hunters in room | Consistent configured area stun | Multi-hunter |
| M4-021 | P1 | Switch outside encounter | Normal light only; no stun state | Scenario |
| M4-022 | P1 | Cleanup during stun | Hunter/switch normal; delayed callback inert | Fault injection |

### 17.4 Doors, bunker, and pathing

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M4-023 | P0 | Player/robot/hunter use front/patio/garage doors | Consistent authoritative behavior | Integration |
| M4-024 | P0 | Two actors operate one door | Deterministic state; no clipping/deadlock | Multi-agent |
| M4-025 | P0 | First reveal | Advanced tools unavailable | Scenario |
| M4-026 | P0 | Later encounter | Tools available | Scenario |
| M4-027 | P0 | Split bunker/above party | Bunker excluded; chase continues above | Multi-client |
| M4-028 | P0 | Last above player captured | Encounter ends once | Multi-client |
| M4-029 | P0 | Hatch intersects player | Move safe/wait; no trap/crush | Physics |
| M4-030 | P0 | Encounter ends sealed | Hatch restores; occupants exit | Scenario |
| M4-031 | P0 | Each hunter through each door | No phase/stall | Automated path grid |
| M4-032 | P0 | Path around beds/appliances/truck/robots/machine | No forbidden collision traversal | Automated path grid |
| M4-033 | P1 | Door closes during path | Repath/wait with bounded recovery | Integration |
| M4-034 | P1 | Hunter stuck | Approved recovery; no visible wall cheat | Fault injection |
| M4-035 | P1 | Four players/robots/hunter in narrow hall | No permanent body-block/explosive physics | Stress |

## 18. Milestone 5 Test Suite

### 18.1 Encounter tiers

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M5-001 | P0 | Stage 0/4 | One, speed 12, 45 s, no doors/inspection | Parameterized integration |
| M5-002 | P0 | Stage 5/8 | Second halfway, speed 15, 60 s, doors | Parameterized integration |
| M5-003 | P0 | Stage 9/10 | Up to three, speed 18, 75 s, inspection | Parameterized integration |
| M5-004 | P0 | Stage 11 | Up to four, speed 19, bunker preference, **90 s** | Integration |
| M5-005 | P0 | Tier change during encounter | Applies next encounter only | Integration |
| M5-006 | P0 | Second hunter midpoint | Once in eligible tier | Fake clock |
| M5-007 | P0 | Client reports machine stage | Server host stage wins | Security |
| M5-008 | P0 | Early/mid/late/postgame bonus | Configured full payout once per eligible member | Parameterized |
| M5-009 | P0 | Capture/survival same instant | One terminal result | Concurrency |
| M5-010 | P1 | Four hunters/four players | Valid targets; bunker exclusions | Multi-client |
| M5-011 | P1 | Hunter speed vs sprint/stamina | Approved human survivability | Human balance |

### 18.2 Robot scheduling

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M5-012 | P0 | Assign robot-owned task | Concurrent job; next primary assigned | Integration |
| M5-013 | P0 | Robot not visibly finished | No completion/reward | Integration |
| M5-014 | P0 | Robot visibly finishes | One job/reward commit | Integration |
| M5-015 | P0 | Duplicate completion callback | No duplicate value/stat | Fault injection |
| M5-016 | P0 | Robots finish simultaneously | Each distinct job once; scheduler valid | Concurrency |
| M5-017 | P0 | Horror during navigation | Animation/deadline pause coherently | Fake clock/scenario |
| M5-018 | P0 | Horror ends | Resume valid state/remaining time | Scenario |
| M5-019 | P0 | Game-fault reason | Requeue; no horror/penalty | Fault injection |
| M5-020 | P0 | Valid path misses deadline | Normal task consequence | Integration |
| M5-021 | P0 | Repeated path fault | Bounded retries/visible fallback | Fault injection |
| M5-022 | P0 | Robot/door | Shared adapter, no phasing | Integration |
| M5-023 | P0 | Furniture/truck/machine/crowd | Visible repath; no disappear/teleport | Stress |
| M5-024 | P0 | Player completes robot-owned task | Exclusivity prevents double completion | Multi-client |
| M5-025 | P0 | Host loss with jobs active | Checkpoint/rejoin; no duplicate job/reward | E2E |
| M5-026 | P1 | Maximum chips on small phone | Readable; prompts unobstructed | Device/hardware |
| M5-027 | P1 | Out-of-order chip updates | Authoritative version rejects stale | Network |
| M5-028 | P1 | 50 automated cycles/four players | No duplicate, leak, invisibility, or drift | Soak |
| M5-029 | P1 | Memory/connections before/after soak | No unbounded growth | Performance/soak |

## 19. Milestone 6 Test Suite

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M6-001 | P0 | Bunker absent, reveal absent | Panel locked/non-interactive | Integration |
| M6-002 | P0 | Bunker built, reveal absent | Locked | Integration |
| M6-003 | P0 | Reveal complete, bunker absent | Locked | Integration |
| M6-004 | P0 | Both conditions met | Quiet unlock | Integration |
| M6-005 | P0 | Search HUD/arrows/tutorials | No explicit required-progression guidance | UI audit |
| M6-006 | P0 | Guest discovers tunnel | Guest flag only | Multi-client |
| M6-007 | P0 | Host discovers tunnel | Host flag only unless others enter | Multi-client |
| M6-008 | P0 | Retry discovery | One credit/stat | Integration |
| M6-009 | P0 | Normal house view before unlock | No distant stream/pop | Hardware/streaming |
| M6-010 | P0 | Enter regions on slow network | Safe barrier/route; no void | Network/streaming |
| M6-011 | P0 | Stream timeout | Return group to safe house point with feedback | Fault injection |
| M6-012 | P0 | Disconnect/rejoin in zone | Named safe checkpoint | Published E2E |
| M6-013 | P0 | Return from every region | Active house restored | Scenario |
| M6-014 | P1 | Attempt party separation | Whole-party vote/transition prevents split trap | Multi-client |
| M6-015 | P1 | Horror tries to start during route | Route pause/lock policy prevents exploit/impossible state | Multi-client |
| M6-016 | P1 | Complete game without route | No required progression/reward missing | Full playthrough |
| M6-017 | P1 | Memory before/after visit | Stream-out within budget; no duplicates | Performance |
| M6-018 | P2 | Markings/geometry all qualities | Foreshadowing readable; no early reveal | Visual QA |

## 20. Milestone 7 Test Suite

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M7-001 | P0 | Migrate each stage 0–11 | Stage/cost progression preserved | Parameterized migration |
| M7-002 | P0 | Repeat each migration | Idempotent | Unit |
| M7-003 | P0 | Invalid stage | Repair/quarantine; no free progress | Migration |
| M7-004 | P0 | Inspect each assembly | Correct pieces; no future piece | Manifest + visual |
| M7-005 | P0 | Upcoming crate stage 0–10 | Exactly next component | Parameterized visual |
| M7-006 | P0 | Exact-cash purchase | Charge/install/save once | Integration |
| M7-007 | P0 | Insufficient cash | No charge/install | Integration |
| M7-008 | P0 | Purchase spam | Max one authorized stage | Security/concurrency |
| M7-009 | P0 | Disconnect charge→install | Resume/rollback without loss/duplicate | Fault injection/E2E |
| M7-010 | P0 | Save fails after install | Journal reconciles | Fault injection |
| M7-011 | P0 | Guest purchase | Rejected | Security |
| M7-012 | P0 | Stage pieces | Coherent silhouette/collision | Visual/physics |
| M7-013 | P1 | Player/robot/hunter path each stage | No trap/nav invalidation | Path grid |
| M7-014 | P1 | Late-horror effects before stage 11 | React without activation prompt | Scenario |
| M7-015 | P0 | Stage 11 reached | Host prompt under valid conditions | Integration |
| M7-016 | P0 | Guest activation | Rejected | Security |
| M7-017 | P0 | Host ready check, 1–4 | Correct roster/one response each | Multi-client |
| M7-018 | P0 | Confirm twice | Count once | Multi-client |
| M7-019 | P0 | Decline/timeout | No countdown; UI resolves | Multi-client |
| M7-020 | P0 | Disconnect during ready check | Cancel/roster policy safe | Multi-client |
| M7-021 | P0 | Everyone confirms | One synchronized countdown | Multi-client |
| M7-022 | P0 | Horror/task tries during countdown | Rejected/suspended | Integration |
| M7-023 | P1 | Countdown under jitter | Acceptable sync; server authoritative | Network |
| M7-024 | P1 | Clock centerpiece all qualities | Unmistakable/readable | Visual QA |
| M7-025 | P1 | Machine asset rollback | Saved stage remains valid | Release drill |

## 21. Milestone 8 Test Suite

### 21.1 Black-hole launch

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M8-001 | P0 | Enter launch | Tasks lock/horror suspends once | Integration |
| M8-002 | P0 | Coil/portal timeline | Ordered effects; one activation | Fake clock/client recorder |
| M8-003 | P0 | Snapshot authoritative house | No destructive permanent transform | Snapshot diff |
| M8-004 | P0 | Each avatar warp | Correct local avatar/effect | Multi-client |
| M8-005 | P0 | Reduced motion | Alternate effects, same progression | Client scenario |
| M8-006 | P0 | Death during launch | Cleanup/checkpoint/controls safe | Scenario |
| M8-007 | P0 | Reset during launch | No locked camera/duplicate/stuck phase | Scenario |
| M8-008 | P0 | Guest disconnect during launch | Checkpoint/rejoin; no duplicate credit | E2E |
| M8-009 | P0 | Host disconnect after launch commit | Finale continues; checkpointed host rejoin | E2E |
| M8-010 | P0 | Slow stream preparation | Safe extension; no void/unloaded reveal | Network/streaming |
| M8-011 | P0 | Permanent preparation failure | Restore safe checkpoint; retry possible | Fault injection |
| M8-012 | P0 | Cleanup normal/interrupted | Identical final controls/effects | Idempotence |

### 21.2 Studio reality and future apartment

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M8-013 | P0 | Enter route desktop/tablet/phone | Loaded grounded spawn; route 2–5 min | Hardware/full run |
| M8-014 | P0 | Inspect HUD | No normal task/timer/robot/upgrade HUD | UI audit |
| M8-015 | P0 | Lowest device/graphics | Navigable; evidence understandable | Hardware |
| M8-016 | P0 | Collision sweep | No barriers, holes, snags, walk-through set pieces | Automated/manual |
| M8-017 | P0 | Unusual stream-cell order | No early reveal/missing critical geometry | Streaming |
| M8-018 | P0 | Backtrack/off-route/prop climbing | No void escape/checkpoint bypass | Exploratory |
| M8-019 | P1 | Synthetic actors/rigs extended loop | No leak/drift/CPU escalation | Soak/performance |
| M8-020 | P1 | TV/evidence asset fails | Route completes with diagnostic/fallback | Fault injection |
| M8-021 | P1 | Mixed load speeds | Fast clients cannot strand slow clients | Multi-client/network |
| M8-022 | P1 | Disconnect in studio/apartment | Safe personal checkpoint restored | Published E2E |

### 21.3 Individual endings

Run solo choices, all four 2-player combinations, and all 16 four-player binary combinations.

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M8-023 | P0 | Stay | Commit once, credits, lobby, no postgame entitlement | Published E2E |
| M8-024 | P0 | Return | Commit once, postgame entitlement, credits then lobby; takes effect next owned session | Published E2E |
| M8-025 | P0 | Submit twice | First committed valid choice wins; no duplicate credit | Security/concurrency |
| M8-026 | P0 | Disconnect after commit/pre-route | Rejoin reconciles and routes | E2E |
| M8-027 | P0 | Route succeeds/callback retries | No duplicate credit | Fault injection |
| M8-028 | P0 | Guest ends in host Stage 11 world | Guest credit/entitlement; guest machine unchanged | Published E2E |
| M8-029 | P0 | Host Stay, guest Return | Guest entitlement commits; neither remains in abandoned host world | Published E2E |
| M8-030 | P0 | Host Return, guest Stay | Personal outcomes independent; host postgame next owned session | Published E2E |
| M8-031 | P0 | Four mixed choices | Personal results only; finale session closes cleanly | Published E2E |
| M8-032 | P0 | Cinematic replay | No repeat reward/choice mutation | Integration/E2E |
| M8-033 | P0 | Direct destination travel | Valid unlock; no duplicate value | E2E |
| M8-034 | P0 | Guest later starts own house | Own stage unchanged; personal entitlement honored | E2E |
| M8-035 | P1 | Credits interrupted | Ending remains committed; route recovers | E2E |

Capture mobile/desktop client traces for ordinary house, four-player multi-hunter, black-hole launch, studio route, and apartment; server traces with four players/max robots/four hunters; memory before/after repeated transitions; worst stream/effect spikes; time to interaction; and network traffic. Averages alone do not pass.

## 22. Milestone 9 Test Suite

| ID | Priority | Test | Expected result | Mode |
|---|---|---|---|---|
| M9-001 | P0 | No Return entitlement enters house | Postgame locked | Integration |
| M9-002 | P0 | Return-entitled player owns session | Postgame maintenance active | E2E |
| M9-003 | P0 | Stay player later uses allowed travel | No accidental postgame | E2E |
| M9-004 | P0 | Family postgame encounter | Existing family behavior valid | Scenario |
| M9-005 | P0 | Anomaly unapproved | Cannot spawn/placehold | Config/asset audit |
| M9-006 | P0 | Seeded 100 selections | Deterministic configured 20% logic | Seeded unit |
| M9-007 | P0 | Prior encounter anomaly | Next cannot be anomaly | Unit/integration |
| M9-008 | P0 | Family/anomaly/family sequences | No-repeat does not suppress forever | Seeded unit |
| M9-009 | P0 | Survive/caught | Counters once | Integration |
| M9-010 | P0 | Streak success | Current/longest correct | Unit/integration |
| M9-011 | P0 | Streak capture | Current resets; longest stays | Unit/integration |
| M9-012 | P0 | Faster/slower cycles | Fastest only valid faster | Unit |
| M9-013 | P0 | Discovery/ending migration | Values accurate | Migration |
| M9-014 | P0 | Duplicate stat event | Once | Fault injection |
| M9-015 | P1 | Maintenance/horror overlap | No impossible ownership | Integration |
| M9-016 | P1 | 50 postgame cycles | No leak/drift | Soak |
| M9-017 | P1 | Cosmetics/dailies/boards disabled | No unfinished UI/network | Regression |
| M9-018 | P1 | Seasonal variants absent | Base behavior unaffected | Regression |
| M9-019 | P1 | Stats across host/guest sessions | Correct personal profile | Multi-client |
| M9-020 | P2 | Retention study | Maintenance understood; meaningful variation | Human |

## 23. Cross-Cutting Persistence and Migration Suite

| ID | Priority | Test | Expected result |
|---|---|---|---|
| MIG-001 | P0 | Every known schema version to current | Exact expected output |
| MIG-002 | P0 | Current to current | No changes |
| MIG-003 | P0 | Migration interrupted before commit | Old valid record recoverable |
| MIG-004 | P0 | Migration callback duplicated | One current record |
| MIG-005 | P0 | Missing fields | Defaults without wiping valid values |
| MIG-006 | P0 | Wrong field types | Repair/quarantine; no crash |
| MIG-007 | P0 | Unknown fields | Preserve/discard per documented policy |
| MIG-008 | P0 | Cash bounds/out-of-bounds | Clamp/reject per schema |
| MIG-009 | P0 | Machine stages 0–11 | Preserved exactly |
| MIG-010 | P0 | Ending/postgame inconsistency | Deterministic repair and diagnostic |
| MIG-011 | P0 | Duplicate operation records | Deduplicated safely |
| MIG-012 | P0 | Profile opened in two servers | Session conflict prevents loss/duplication |
| MIG-013 | P0 | Server closes during pending write | Bounded close and reconciliation |
| MIG-014 | P1 | DataStore throttle/timeout | Backoff/fallback; save state communicated |
| MIG-015 | P1 | Payload near size limit | Within budget or fail before corruption |
| MIG-016 | P1 | 100 load/save cycles | No normalized-profile drift |

Expected migration outputs are version-controlled and never regenerated automatically from current production code.

## 24. Cross-Cutting Multiplayer and Concurrency Suite

Run deterministic server/client simulation, then repeat critical cases in a privately published experience:

- Two players trigger the same prompt in the same frame.
- Four completion requests arrive reordered and duplicated.
- Capture and survival occur on the same frame.
- Host purchase and host disconnect occur in both orders.
- Host return and grace expiry occur at the same instant.
- Robot completion and horror start occur in both orders.
- Player, robot, and hunter operate one door simultaneously.
- Hiding entry/exit overlaps hunter inspection.
- Machine ready confirmation overlaps disconnect.
- Final choice submission overlaps disconnect.
- Ending route overlaps host-session closure.
- An old-session save completes after a new session begins.
- Ready acknowledgment, Start request, heartbeat, and stale party poll arrive in every meaningful order.

Each race tests both orders and duplicate delivery. Results are deterministic or explicitly first-commit-wins.

## 25. Security Suite

Maintain a registry of every `RemoteEvent`, `RemoteFunction`, state-changing ProximityPrompt/ClickDetector/DragDetector, client request, server effect event, and test/debug channel. For each client action document allowed phase/role, argument schema, distance/context, rate limit, replay behavior, authoritative values, and rejection telemetry.

| ID | Priority | Attack | Required result |
|---|---|---|---|
| SEC-001 | P0 | Award arbitrary cash | Rejected; no profile change |
| SEC-002 | P0 | Complete inactive/wrong task | Rejected |
| SEC-003 | P0 | Complete from impossible distance | Rejected |
| SEC-004 | P0 | Purchase as guest | Rejected |
| SEC-005 | P0 | Nonexistent item/stage/negative price | Rejected |
| SEC-006 | P0 | Select hunter/start encounter | Rejected |
| SEC-007 | P0 | Force hidden/bunker safety | Rejected |
| SEC-008 | P0 | Trigger switch/distraction remotely | Rejected |
| SEC-009 | P0 | Ready another player | Rejected |
| SEC-010 | P0 | Submit another player's ending | Rejected |
| SEC-011 | P0 | Replay old operation ID | No duplicate effect |
| SEC-012 | P0 | Huge data, NaN, infinity, wrong instances | Rejected before costly work/save |
| SEC-013 | P0 | High-rate valid spam | Rate-limited; responsive server |
| SEC-014 | P0 | Arbitrary Instance/path mutation | Rejected |
| SEC-015 | P0 | Invoke scenario/debug channel | Rejected/logged; channel absent in production |
| SEC-016 | P0 | Tamper host/party teleport data | Validation fails safely |
| SEC-017 | P1 | Move client-owned interaction part | Context validation still rejects |
| SEC-018 | P1 | Change local speed/stamina/UI | No authoritative/persistent advantage |
| SEC-019 | P1 | Relay malicious effect payload | Only configured IDs/parameters emitted |
| SEC-020 | P1 | Flood pathfinding/expensive requests | Bounded/rate-limited |

Security testing never runs against a live public server or affects other users.

## 26. Performance, Streaming, and Soak Program

### 26.1 Required profiles

Measure on the reference mobile/tablet devices and representative desktop:

1. Baseline house solo.
2. House with four players and maximum ordinary activity.
3. Maximum robots plus primary task.
4. Early one-hunter encounter.
5. Four-hunter Stage 11 split across house/bunker.
6. Optional mystery entry/exit.
7. Stage 11 machine effects.
8. Black-hole launch.
9. Studio-reality route.
10. Future apartment and credits.
11. Fifty-cycle automation soak.
12. Repeated house/finale/postgame transitions.

### 26.2 Metrics and acceptance

Capture client/server frame time and worst spikes, FPS distribution, memory/growth, Lua heap, instance/connection/task/timer counts, physics and moving assemblies, path frequency/fault/retry, network throughput/payload size, streaming wait/failure/stream-out, time to first controllable frame, and preload fallback count.

After soak:

- No monotonic growth outside Section 4 performance tolerance.
- No accumulating NPC, prompt, highlight, sound, effect, path object, UI, eligibility, ticket, or pause token.
- Scheduler/task/cycle state remains exact.
- Cash/stat totals equal an independent operation ledger.
- Warning/error rate and tail frame time do not worsen.
- Timer drift remains within deterministic tolerance.

## 27. Accessibility and UX Program

Test small phone landscape, large phone, portrait, tablet, desktop, ultrawide, maximum HUD density, loading/respawn/horror/finale transitions, rapid input switching, low graphics, brightness extremes, pseudolocalization when localization begins, first-time users without spoken instruction, and returning players at every checkpoint.

Human sessions record:

- Whether the current goal is clear.
- Whether the reveal is surprising rather than arbitrary.
- Whether failure is attributable and fair.
- Whether safe options can be found after reveal.
- Whether reduced flash/motion/audio materially helps.
- Whether host ownership and full personal rewards are understood.
- Whether anyone waits with nothing meaningful to do.
- Whether finale choice/consequences are clear.
- Whether the lobby is attractive, readable, recognizably 1980s, and easy to launch from.

## 28. Asset, Content, and IP QA

The asset manifest stores logical key, character/location/system, normal/horror/reveal variant, version, Roblox ID, source hash, alpha/crop dimensions, ownership/permission status, approver/status/date, maturity notes, and fallback.

Startup validation finds missing keys, forbidden duplicate IDs, wrong character mappings, and unapproved placeholders. Public release remains blocked until character likenesses, show branding, audio, the future apartment, logos, Blender references, and every third-party asset have an owner, documented permission/status, and replacement path. Obtain qualified rightsholder/legal guidance appropriate to the intended distribution and monetization. Reassess Roblox maturity information whenever the strongest shipped content changes.

## 29. Observability and Evidence

### 29.1 Structured event families

- `profile_load/migrate/save`
- `party_create/join/leave/host_lost/host_returned/close`
- `ready_request/ready_commit/launch_preflight/party_lock/reservation/manifest/ticket/teleport/admission`
- `task_start/complete/fail/reward`
- `robot_job_*`
- `encounter_start/reveal/capture/survive/abort/restore`
- `purchase_authorize/charge/install/commit/reconcile`
- `discovery_credit`
- `finale_start/checkpoint/choice/credit/route`
- `remote_rejected`
- `stream_wait/fallback`

Events include build/config/asset-manifest version but never expose reserved-server access codes or sensitive payloads.

### 29.2 Required reports

Every automated run records build/commit, config/flags, IDs run, pass/fail/blocked counts, seed/fixture, first failure, client/server logs, snapshot diff, performance samples, and screenshot/video evidence paths.

Maintain:

1. `TEST_TRACEABILITY.md` — requirement → implementation → test IDs.
2. `TEST_RESULTS.md` — results, first failure, fixture, seed, and evidence.
3. `UNRESOLVED_DECISIONS.md` — newly discovered ambiguity only; DEC-01–12 are locked here.
4. `REMOTE_SECURITY_MATRIX.md` — every client action and validation/rate limit.
5. `MIGRATION_FIXTURES.md` — schema versions and expected outputs.

## 30. Milestone Gate Definition

A milestone passes only when:

1. Every P0 is PASS.
2. Every P1 is PASS or has a time-bounded accepted risk that cannot violate no-loss/no-duplication rules.
3. No S0/S1 remains.
4. No unexplained client/server error exists.
5. Migration/rollback evidence exists when state/config changed.
6. Relevant solo, 2-player, and 4-player cases pass.
7. Relevant mobile, physical-device, accessibility, and performance cases pass.
8. All global invariants pass after every scenario.
9. Evidence identifies exact build, config, flags, assets, fixture, and seed.
10. Human review signs off on visuals, gameplay, surprise/fear, and clarity that automation cannot judge.

“Works on my account” and long informal playtime are supporting evidence, never a gate by themselves.

## 31. Codex Implementation Brief

For each implementation batch:

> Read this canonical bible completely before modifying code. First produce requirement-to-code-to-test traceability for the batch. Inventory relevant modules, scripts, remotes, profile fields, flags, timers, random choices, and states. Derive expected behavior from this bible rather than copying current implementation. If new ambiguity affects persistent value, ownership, reconnect eligibility, ending routing, or production debug access, stop and record it rather than guessing.
>
> Use deterministic seams for clock, randomness, persistence, teleport, navigation, assets, analytics, and effects only where needed. Use TestEZ or the repository's established Luau harness for deterministic tests. Keep the Studio scenario runner structurally absent from production.
>
> Test success, duplicate delivery, disconnect, timeout, stale response, and fail-then-retry for each critical operation. Never weaken/delete assertions, hide a failure with arbitrary waits, or rewrite a requirement silently. Report the defect and correction.

### First testing batch

1. Runner/folder structure.
2. Fake monotonic clock and deterministic RNG.
3. Versioned migration fixtures.
4. Operation-ID duplicate/retry/stale/disconnect tests.
5. Deadline, pause, penalty, and hunter mapping tests.
6. Encounter snapshot/cleanup verifier.
7. Remote inventory/security-matrix generator.
8. Two-client simultaneous task-completion test.
9. Production-build audit proving scenario controls unavailable.
10. Ready/Start regression suite and truthful Studio preview adapter.

Do not attempt all 348 requirements in one brittle batch. Build deterministic leverage first, then implement tests alongside each milestone.

## 32. Final Release Checklist

- [ ] Canonical bible and traceability match the current build.
- [ ] All DEC-01–12 contracts remain implemented/versioned.
- [ ] M0 source baseline, rollback hashes, and regressions remain valid.
- [ ] Ready/Start works in Studio truthfully and in published solo/2/4-player sessions.
- [ ] All 81 historical M1 matrix rows plus M1X regressions pass.
- [ ] Feature flags default safely and invalid combinations recover.
- [ ] All migrations and machine-stage fixtures pass.
- [ ] Exactly-once journal passes retry/duplicate/disconnect/session-conflict tests.
- [ ] Host/guest ownership, eligibility, grace, rejoin, and no-replacement rules pass.
- [ ] Every task naturally triggers reveal and forced cycle-4 reveal passes.
- [ ] Every hunter mapping, presentation, and cleanup exit path passes.
- [ ] Hiding, distractions, switches, doors, bunker, and pathing pass.
- [ ] Fifty automated cycles pass without drift/leaks.
- [ ] Optional zones never appear early, split the party, or spawn into void.
- [ ] All eleven machine stages migrate, purchase, align, and path correctly.
- [ ] Same-place finale streaming and interruption matrix passes.
- [ ] All 16 four-player ending combinations pass; no repeat rewards.
- [ ] Postgame anomaly approval/no-repeat and maintenance design gates pass.
- [ ] Security suite reports no unauthorized mutation/debug surface.
- [ ] Lowest-supported-device performance and accessibility budgets pass.
- [ ] Server/client logs contain no unexplained errors.
- [ ] Visual review approves all UI and the 1980s lobby.
- [ ] Asset/IP permission review and replacement plan are complete.
- [ ] Content-maturity information matches strongest shipped content.
- [ ] Private release candidate and rollback drill pass.

---

## 33. Document Change Control

- Product, economy, ownership, persistence, reconnect, topology, and ending changes require an explicit update to this bible before implementation.
- Never erase historical evidence. Append dated verification or supersession records.
- Test IDs from the original 348-requirement suite are stable. Add new IDs instead of renumbering old ones.
- A milestone status changes only through its gate evidence, not implementation claims.
- When this canonical workspace copy is approved, mirror it byte-for-byte to the user's requested Downloads copy; do not allow two competing plans to evolve.
