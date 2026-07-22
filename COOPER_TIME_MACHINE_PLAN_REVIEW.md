# Cooper Time Machine — Roadmap Review

**Reviewed file:** `PLAN.md`  
**Review date:** 2026-07-22  
**Review scope:** Product structure, implementation readiness, multiplayer ownership, persistence, testing, security, performance, accessibility, release risk, and scope sequencing.  
**Not reviewed:** The actual Luau source, `MILESTONE0_BASELINE.md`, art files, place files, profile schemas, asset permissions, or current gameplay balance because they were not attached.

---

## 1. Overall Verdict

The roadmap is unusually strong as a creative and milestone document. It has a coherent escalation from cozy tasks to hidden horror to science-fiction finale, protects the existing working game, states several non-negotiable design rules, and repeatedly demands rollback safety, mobile testing, server authority, idempotent restoration, and milestone gates.

It is **not yet fully implementation-ready** for the most dangerous parts of the project: shared rewards, host-owned worlds, disconnect/rejoin behavior, exact save boundaries, concurrent robot jobs, and individual endings. Those areas contain undefined ownership and transaction rules that Codex could resolve differently in different modules. The resulting code might appear to work in ordinary play while still duplicating cash, losing progress, or routing mixed-choice parties into impossible states.

The plan should remain the product roadmap, but it needs a short companion specification covering:

1. state ownership;
2. legal state transitions;
3. eligibility snapshots;
4. exactly-once transactions;
5. reconnect/checkpoint rules;
6. finale routing;
7. measurable performance budgets;
8. observability and release procedure.

The accompanying `COOPER_TIME_MACHINE_TEST_PLAN.md` is designed to force those decisions before Codex silently guesses.

---

## 2. What the Plan Does Very Well

### 2.1 It protects the existing game

The plan begins by preserving the working house, five tasks, automation systems, bunker, and the four existing normal NPCs. Milestone 0 requires rollback, disabled-by-default flags, schema migration, and a complete non-horror solo/mobile gate before horror work. This is exactly the right instinct for a fast-moving codebase.

### 2.2 It uses staged escalation instead of one giant rewrite

The progression from foundation, to co-op, to horror skeleton, to survival tools, to automation integration, to optional mysteries, to machine rebuild, to finale, and then postgame creates natural validation points. That is far safer than integrating lobby, horror, Blender streaming, and endings at the same time.

### 2.3 It has a clear creative spine

The experience has a readable arc:

- familiar task loop;
- hidden pressure;
- first reveal;
- increasingly capable hunters;
- optional evidence that the world is constructed;
- machine completion;
- reality reveal;
- personal ending choice;
- changed postgame loop.

The optional mystery route foreshadows the finale without making discovery mandatory. That is a good narrative structure.

### 2.4 It preserves the normal NPC presentation

The rule that normal cutouts, catchphrases, dialogue, proportions, and behavior remain untouched outside horror prevents the secret system from contaminating the cozy baseline. The separate asset manifest and versioned scary assets are also good production controls.

### 2.5 It correctly favors server authority

The roadmap explicitly calls for a server-authoritative horror state machine and one authoritative session state. It also says clients cannot award cash, choose hunters, complete tasks authoritatively, purchase host upgrades, or force story state. This is essential for a game with persistent money and shared progression.

### 2.6 It recognizes restoration as a first-class requirement

The requirement to restore lights, NPCs, doors, prompts, cameras, sounds, and movement idempotently is one of the strongest parts of the plan. Horror systems often fail not during the chase, but when an interrupted chase leaves the ordinary game in a corrupted presentation state.

### 2.7 It includes accessibility before the finale

Reduced flashing, reduced camera motion, and effect-volume controls appear before the largest effects are built. The finale also calls for a reduced-motion version. That is much better than trying to retrofit accessibility after all cinematics are locked.

### 2.8 It refuses filler content

The bunker activities remain deferred until their gameplay has been selected, and cosmetics/dailies/global boards remain deferred until postgame is stable. Those are disciplined scope decisions.

### 2.9 It already contains meaningful gates

The existing gates cover blind reveal testing, pathing around real furniture, repeated automation cycles, stream safety, all eleven machine stages, mixed ending choices, mobile performance, and final no-loss/no-duplication criteria. The roadmap understands that “implemented” is not the same as “ready.”

---

## 3. Critical Issues to Resolve Before Codex Builds Further

### CRITICAL-01 — Individual endings conflict with host-owned worlds

The roadmap establishes that the host’s house, bunker, purchases, and machine stage control the world. It also says that if the host disconnects for more than 60 seconds, the party saves and returns to the lobby. Later, each player chooses individually whether to stay in reality or return to the simulation.

The undefined case is:

- Host chooses **Stay in reality** and is returned to the lobby.
- One or more guests choose **Return to the simulation**.

Those guests cannot safely remain in the host’s world because the host is gone and the host-disconnect rule would close it. They also cannot inherit the host’s Stage 11 construction because the roadmap explicitly forbids that.

**Recommended resolution:** After the final choice, every player routes independently. A player who returns to the simulation enters a newly created private session based on that player’s own persistent house profile, with postgame unlocked but physical upgrades unchanged. The original finale party session closes after all choices are committed and routed.

This should be written into Locked Design Rules and Milestone 8 before implementation continues.

### CRITICAL-02 — “Present player” is not defined

The roadmap grants rewards to each present member and applies capture penalties to every party member. “Present” must be defined for players who:

- join after a task starts;
- disconnect before completion;
- remain in a reconnect grace period;
- die or respawn;
- are loading;
- are in the bunker;
- are inside the optional mystery route;
- are in the finale but on a different streamed checkpoint.

Without one rule, different systems will calculate different party sets.

**Recommended resolution:** The server creates an immutable eligibility set at the authoritative start of each task/encounter. Rejoining restores the same membership record rather than creating a new one. Explicitly state which conditions remove a player from the set.

### CRITICAL-03 — Persistent transactions are underspecified

The roadmap says rewards occur once and migrations preserve data, but it does not define transaction boundaries. The dangerous flows include:

- task completed, reward applied, save fails;
- purchase charged, install fails;
- install succeeds, save callback arrives twice;
- ending credit commits, teleport fails;
- player disconnects while a robot completion callback is in flight;
- an old server writes after the same player has joined a new server.

**Recommended resolution:** Every value-bearing action gets a server-generated operation ID and a commit record. Profiles need a bounded deduplication/journal strategy, and the game needs a session-lock/conflict policy. Each transaction must define whether it resumes, rolls back, or reconciles after interruption.

### CRITICAL-04 — Safe checkpoints are not specified

The roadmap describes many transient states but not what persists after a crash or full server loss. A player should never rejoin into a black screen, hidden state, camera lock, half-installed machine, or active chase without the required world.

**Recommended resolution:** Persist durable progress only at named checkpoints. Transient presentation state should collapse to a safe checkpoint on rejoin. Define checkpoints for ordinary tasks, post-reveal state, machine purchases, launch start, studio entry, apartment entry, final-choice commit, and postgame unlock.

### CRITICAL-05 — Guest reconnect behavior is missing

Only host reconnect receives an explicit grace period. Guest reconnect affects reward eligibility, target assignment, ending choices, and party closure.

**Recommended resolution:** Add guest reconnect rules to Milestone 1 and phase-specific reconnect rules to Milestone 8. Decide whether guest loss pauses anything, how access to the reserved session is authenticated, and how long the guest remains eligible.

### CRITICAL-06 — Host disconnect cannot use one rule in every phase

Pausing ordinary tasks for 60 seconds is reasonable. The same behavior may be wrong during:

- active horror;
- machine ready check;
- black-hole cinematic;
- studio route;
- individual ending choice;
- credits.

For example, freezing an active hunt for all guests because the host briefly disconnects may be exploitable or visually broken. Closing the finale because the host left after already submitting a choice may also be wrong.

**Recommended resolution:** Add a host-loss policy table by `SessionPhase` rather than one global rule.

### CRITICAL-07 — Finale world topology is ambiguous

Milestone 6 explicitly keeps mystery regions as distant streamed zones in the gameplay place. Milestone 8 says to preload “the destination,” but does not state whether the realistic studio and future apartment are in the same place or separate places.

That decision changes:

- streaming and memory budgets;
- teleport/reconnect behavior;
- party separation;
- server ownership after individual choices;
- whether the ordinary house must remain loaded;
- how controls/HUD are suppressed;
- how the route is replayed.

**Recommended resolution:** Choose the topology before building the Blender pipeline. A separate finale place can isolate memory and presentation, but it adds teleport/checkpoint complexity. A streamed same-place finale avoids a teleport but creates higher memory and ownership complexity. Either can work; leaving it implicit cannot.

### CRITICAL-08 — Debug/scenario tooling needs structural isolation

Milestone 0 says Studio-only scenario controls must never appear in production, while the scope-lock note says `StudioScenarioTools` stays false until approved. A disabled runtime boolean is not enough protection if a privileged remote or module is still replicated or invokable.

**Recommended resolution:** The production build should exclude privileged scenario endpoints or place them behind Studio/plugin-only services that do nothing in published servers. Add a build audit that enumerates remotes and proves debug controls are absent/unreachable.

### CRITICAL-09 — Economy behavior may create unintended farming

Every present player receives shared task rewards and survival bonuses. Guests retain personal cash while using the host’s world and can receive ending credit without matching machine progress. This may be intended, but it creates several farming paths:

- repeatedly joining a Stage 11 host for late bonuses;
- rotating hosts to multiply shared economy;
- disconnect/rejoin around reward snapshots;
- replaying the finale or direct travel;
- using robots to generate concurrent rewarded work.

**Recommended resolution:** Simulate the economy for solo and four-player play. Explicitly decide whether party play should increase total currency creation fourfold, and add per-operation deduplication and replay rules.

### CRITICAL-10 — IP/asset review must remain a release blocker

The plan correctly calls for a review covering likenesses, show branding, audio, the future apartment, and logos. Because the project is visibly based on recognizable television characters and setting, this review should not become an optional administrative task after public discovery or monetization begins.

**Recommended resolution:** Keep creative prototyping separate from public release authorization. Track each asset’s source, permission status, and replacement path in the asset manifest. Obtain qualified legal/rightsholder guidance for the intended distribution and monetization model.

---

## 4. Major Specification Gaps

### MAJOR-01 — State machines are named but not defined

“One server-authoritative session state” is good direction, but it could turn into a giant mutable table with unrelated booleans. The plan needs legal states and transitions for session phase, task, robot job, encounter, machine purchase, player presence, and final choice.

Use enums and transition functions rather than combinations such as:

```text
isHorror = true
isCinematic = true
isTaskPaused = false
isEnding = true
```

that may represent impossible states.

### MAJOR-02 — Timer pausing needs reason-counted semantics

Deadlines pause during loading, cinematics, death recovery, and active horror. These reasons can overlap. A single `paused=true/false` or “pause then resume” call will resume early when one reason ends while another remains.

Use pause tokens or a reason set and compute elapsed time from a monotonic server clock.

### MAJOR-03 — Stage 11 duration is missing

Stages 0–4, 5–8, and 9–10 have explicit survival durations. Stage 11 specifies hunter count and speed but not duration. Codex should not infer 75 seconds without a written decision.

### MAJOR-04 — Robot navigation failure classification is vague

“Navigation failures caused by the game” requeue without horror. The server needs objective failure codes. Otherwise the same stuck robot might sometimes punish players and sometimes be excused depending on implementation details.

Define categories such as:

- invalid world/nav registry;
- path service failure;
- dynamic obstruction timeout;
- target removed;
- player-caused interference, if that concept is actually enforceable;
- task deadline reached after valid execution.

### MAJOR-05 — Optional-route behavior during horror is undefined

A player may be in the tunnel/backrooms/dome while the party task times out. Decide whether:

- that player is targetable there;
- horror waits until return;
- the region is a refuge;
- the player is teleported back;
- the player receives a capture penalty if someone else is caught;
- task deadlines continue while the party explores.

The route is optional, so it should not accidentally become the safest exploit or a party trap.

### MAJOR-06 — Hiding capacity and inspection behavior are missing

The plan needs rules for simultaneous entry, occupancy, manual exit, inspection interruption, death/reset, streamed-out anchors, and whether multiple hunters can inspect the same location.

### MAJOR-07 — Joining after launch is not specified

The lobby creates an invited party and launches a reserved server, but it is unclear whether a disconnected guest can rejoin and whether a new invited friend can join after launch. These must be separate policies.

### MAJOR-08 — Performance target is too vague

“Stable 30 FPS on supported mobile devices” is a useful direction but not a pass/fail gate. Select a minimum hardware class and record actual budgets. Performance should also cover the four-hunter house, not only the Blender finale.

### MAJOR-09 — No observability contract

The roadmap asks for log audits but not structured state-transition, operation, save, teleport, or rejection logs. With 30,000+ lines and rapid Codex implementation, debugging distributed state without operation IDs and structured events will be difficult.

Add a compact event schema and a session/operation correlation ID.

### MAJOR-10 — Feature-flag dependencies are missing

Flags for lobby, horror, secrets, finale, and postgame can create invalid combinations. Define dependency and fallback rules, and version the configuration used by each server/test report.

### MAJOR-11 — Future apartment is only a label

The future apartment is a major narrative payoff but has no route length, interaction, checkpoint, co-op behavior, performance budget, or failure behavior. Milestone 8 cannot be fully estimated or tested until this is specified.

### MAJOR-12 — Postgame maintenance is not designed yet

Milestone 9 says the loop becomes “horror with task/machine maintenance,” but the maintenance rules are not described. The anomaly and statistics are specifiable; the core loop is not. Treat Milestone 9 as a design milestone before a coding milestone.

### MAJOR-13 — Machine costs are preserved but not centralized in the roadmap

The plan says existing costs remain, but it does not name their source of truth. Codex should not duplicate costs in tests, UI, server purchase code, and migration logic. Keep one server configuration table and test all consumers against it.

### MAJOR-14 — Accessibility criteria are qualitative

Reduced flash and motion need concrete variant definitions and full effect coverage. Otherwise one system may respect the setting while room lights, reveal images, portal effects, or camera FOV changes do not.

### MAJOR-15 — The maturity update is a release task, not only a checklist item

The plan appropriately mentions accurate maturity information. Add an explicit release owner and sign-off artifact whenever horror or finale content changes the strongest content players can encounter.

---

## 5. Architecture Recommendation

### 5.1 Separate three kinds of state

#### Personal persistent profile

Owned by each player:

- cash;
- personal statistics;
- discoveries;
- ending credit/choice;
- postgame unlock;
- personal machine stage and purchases when the player hosts;
- accessibility preferences if stored by the game.

#### Host world profile

A view of the host’s persistent construction state for the active session:

- bunker built;
- robots/upgrades that physically affect the house;
- machine stage;
- world-specific permanent purchases.

Guests may observe and use permitted systems but never write these fields.

#### Ephemeral session state

Owned by the active server:

- party membership and eligibility sets;
- current five-task cycle and task;
- deadlines and pause reasons;
- concurrent robot jobs;
- horror phase and hunters;
- hiding/distraction/switch occupancy;
- finale phase and per-player choices;
- temporary effect/restoration snapshots.

Persist only named checkpoints from this layer.

### 5.2 Avoid a monolithic session module

“One server-authoritative session state” should mean one source of truth, not one giant script. Use domain modules behind a session coordinator:

- `PartyService`;
- `TaskScheduler`;
- `RobotJobService`;
- `EncounterService`;
- `NPCAdapter`;
- `DoorService`;
- `WorldRegistry`;
- `MachineService`;
- `FinaleService`;
- `ProfileService`;
- `TransactionLedger`.

The coordinator controls phase transitions; modules cannot independently begin incompatible phases.

### 5.3 Make time and randomness injectable

The roadmap contains many exact timings and random choices. A fake clock and deterministic random source will make tests fast and reproducible. Do not build automated tests that literally wait 300 seconds or depend on random statistical luck.

### 5.4 Use one cleanup ownership model

Every phase that changes presentation should register reversible changes or snapshot the exact controlled properties. Cleanup must tolerate:

- partial initialization;
- duplicate calls;
- missing instances;
- changed assets;
- player death/disconnect;
- phase replacement.

Do not let each effect script independently “guess” how to restore the world.

### 5.5 Use a ledger for persistent value

Each operation should have:

- operation ID;
- type;
- affected player/profile;
- amount/value;
- precondition/version;
- committed result;
- reconciliation state.

This does not require full event sourcing. It requires enough durable identity to make retries safe.

---

## 6. Scope and Sequencing Review

The roadmap contains several projects that could each consume a substantial development cycle:

- cross-place private-party lobby;
- reconnectable host-owned co-op sessions;
- server-authoritative task and economy conversion;
- horror state machine and four NPC hunters;
- pathing through a furnished house;
- hiding/distraction/stun systems;
- concurrent physical robot jobs;
- streamed optional backrooms/dome regions;
- eleven-stage machine art and migration;
- synchronized cinematic;
- optimized Blender environment for mobile;
- individual branching endings;
- postgame horror/maintenance and retention systems.

Thirty thousand lines working in two weeks is impressive, but line count cannot show whether the difficult cross-system contracts are complete. The remaining work is likely dominated by integration, assets, pathing, save safety, device performance, and interruption handling rather than typing speed.

### Recommended delivery cuts

#### Internal Foundation Build

- Milestone 0 only.
- No public horror.
- Migration, rollback, flags, logs, test harness.

#### Horror Vertical Slice

- Milestones 1–4.
- One complete co-op task cycle into first reveal and one later encounter.
- All restoration, reconnect, mobile, and accessibility gates.

This is the most important proof point. Do not proceed based only on separate feature demos.

#### Core Systems Alpha

- Milestone 5.
- Full encounter tiers and robot integration.
- Fifty-cycle soak and economy validation.

#### Machine/Finale Beta

- Milestone 7, then Milestone 8.
- Treat the finale as its own production with an explicit topology decision and hardware budgets.

#### Optional/Retention Content

- Milestone 6 can be authored earlier for narrative reasons but should not delay core stability.
- Milestone 9 should begin with a design specification for maintenance, then implementation.

This order moves the optional mystery route out of the critical path if schedule or stability becomes a problem.

---

## 7. Specific Recommended Edits to `PLAN.md`

### Add under Locked Design Rules

```markdown
- Each value-bearing action uses a server-generated operation ID and commits at most once.
- “Present player” is determined by a server-owned eligibility snapshot created at task/encounter start; reconnecting does not create a second eligibility record.
- Personal profiles, the host-owned physical world, and ephemeral session state are separate data domains.
- Transient horror/cinematic state is never resumed directly after a server loss; players resume from a named safe checkpoint.
- Individual ending routing does not depend on the original host remaining online. A returning player enters a session based on that player’s own persistent house state.
- Feature-flag dependencies and invalid combinations have explicit safe fallbacks.
```

### Add to Milestone 0

```markdown
- Create structured state-transition and transaction logs with session and operation IDs.
- Add a production-build audit proving Studio scenario controls and privileged remotes are absent or unreachable.
- Define test DataStore namespaces and prevent Studio/staging from reading or writing live profiles.
```

### Add to Milestone 1

```markdown
- Define guest reconnect, late-join, and post-launch invite policy.
- Define reward eligibility for loading, dead, disconnected-grace, and late-joining players.
- Use phase-specific host-loss behavior rather than one blanket rule where necessary.
```

### Add to Milestone 2

```markdown
- Implement deadlines using a monotonic server clock and reason-counted pause tokens.
- Persist only a safe pre-encounter or post-encounter checkpoint; never persist active visual/control mutations.
```

### Add to Milestone 4

```markdown
- Define hiding capacity, simultaneous entry, inspection, voluntary exit, reset/death, and streamed-anchor failure behavior.
- Define optional-route and bunker eligibility/penalty behavior during shared encounters.
```

### Add to Milestone 5

```markdown
- Assign objective robot outcome reason codes that distinguish game navigation faults from ordinary task failure.
- Define the Stage 11 encounter duration.
- Validate the solo-versus-party economy and high-stage guest farming risk.
```

### Add to Milestone 8

```markdown
- Lock the finale topology (same place, separate place, or hybrid) before Blender production.
- Define named checkpoints for launch, studio entry, future apartment, choice commit, and routing.
- Define all mixed host/guest ending outcomes, especially host-stays/guest-returns.
- Commit ending choice and credit before routing; routing retries must be idempotent.
```

### Add a Performance Budget section

```markdown
- Name the lowest supported phone/tablet class.
- Set client/server frame-time, memory, streaming-wait, and network budgets.
- Measure both average and worst-frame behavior in maximum house encounter and finale scenarios.
```

### Add a Release Process section

```markdown
- Use private staging and isolated persistent data.
- Run canary/private release candidates before wider publication.
- Record exact build, config, feature flags, asset manifest, and migration version.
- Require rollback drill, asset/IP sign-off, maturity review, and zero S0/S1 defects.
```

---

## 8. Risk Register

| Risk | Likelihood | Impact | Primary mitigation |
|---|---:|---:|---|
| Duplicate/lost cash or upgrades | High without ledger | Critical | Operation IDs, transaction tests, session locks |
| Host/guest ending deadlock | High unless specified | Critical | Independent routing rule and all choice combinations |
| Debug tools exposed in production | Medium | Critical | Structural build exclusion and security scan |
| Old save corruption | Medium | Critical | Versioned migration fixtures and rollback |
| Hunter/robot pathing instability | High in furnished house | Major | Door adapter, path grid, stuck reason codes, soak |
| Horror cleanup leaves world broken | Medium | Critical | Snapshot/cleanup owner, idempotence fault tests |
| Four-player economy inflation | Medium–high | Major | Economy simulation and eligibility rules |
| Mobile finale performance miss | High | Major | Device floor, graybox budget, profile before final art |
| Streamed optional/finale void spawn | Medium | Critical | Safe anchors, load gates, timeout fallback |
| Mixed choices lose credit on teleport | Medium | Critical | Commit-before-route and reconciliation |
| Feature-flag invalid state | Medium | Major | Dependency matrix and config versioning |
| AI-generated test suite gives false confidence | High | Major | Requirement-based assertions, mutation/fault cases, human review |
| Scope prevents adequate polish | High | Major | Vertical slices, optional-route/postgame deferral |
| Asset/IP permission problem | Material | Critical to release | Formal permission review and replaceable manifest |

---

## 9. Final Assessment

### Green — Ready direction

- Narrative progression and milestone concept.
- Preserving the baseline.
- Four-NPC constraint.
- First-reveal pacing.
- Server authority direction.
- Idempotent restoration requirement.
- Accessibility intent.
- Optional-content and filler restraint.
- Machine-stage migration gate.

### Amber — Needs written contract before implementation hardens

- Party eligibility.
- Guest reconnect.
- timer pause semantics;
- robot failure classification;
- hiding occupancy;
- optional-route behavior during horror;
- feature-flag dependencies;
- performance budgets;
- observability;
- future-apartment specification;
- postgame maintenance design.

### Red — Must resolve before release-capable code

- Individual endings versus host-owned world.
- Exactly-once persistent transactions and concurrent-server conflict.
- Safe checkpoints after interruption/server loss.
- production isolation of scenario controls.
- finale topology and routing.
- asset/IP permission status for public release.

The roadmap is worth keeping. Its creative direction is coherent and its milestone discipline is better than most early game plans. The correct next move is not to add more features or more raw lines of code; it is to lock the state/transaction contracts and make Codex prove each milestone through the attached test plan.

