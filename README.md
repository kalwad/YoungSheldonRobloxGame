# Cooper Time Machine — Master Development Bible (Current Working Set)

Last updated: 2026-07-23

## 0) Purpose

This file is the single, practical roadmap reference for the current repository state.

It combines:
- The canonical baseline plan in [PLAN.md](PLAN.md)
- The roadmap review in [COOPER_TIME_MACHINE_PLAN_REVIEW.md](COOPER_TIME_MACHINE_PLAN_REVIEW.md)
- The test matrix in [COOPER_TIME_MACHINE_TEST_PLAN.md](COOPER_TIME_MACHINE_TEST_PLAN.md)
- Milestone-specific completion records ([MILESTONE0_BASELINE](MILESTONE0_BASELINE.md), [MILESTONE0_VERIFICATION](MILESTONE0_VERIFICATION.md), [MILESTONE1_IMPLEMENTATION](MILESTONE1_IMPLEMENTATION.md), [MILESTONE1_TEST_MATRIX](MILESTONE1_TEST_MATRIX.md))

The canonical planning authority remains [PLAN.md](PLAN.md).

## 1) Review summary: what is currently working vs not

### Milestone status (ground truth now)

| Milestone | State | Current evidence | Next requirement |
|---|---|---|---|
| 0 — Safe pre-horror baseline | **Complete** | Rollback exports, profile migration checks, and full verifier pass in baseline scope are recorded in [MILESTONE0_VERIFICATION.md](MILESTONE0_VERIFICATION.md). | Keep preserved and untouched. |
| 1 — Lobby + co-op foundation | **Partially complete / gate open** | Newer source is in repo but not fully re-synced through Studio/published gates yet. Deterministic static suite and verifier suites now pass locally on the latest source tree. | Finish candidate freeze, re-run all pending Studio audits, then run private published solo/2-player/4-player end-to-end launch/reconnect gates before any Milestone 2 implementation. |
| 2–9 | **Not started for gameplay in production** | Flags are frozen false for all future systems. No active Horror/SecretExploration/Finale/Postgame runtime. | Only begin after Milestone 1 is closed via the gate matrix. |

### What is done right now in the working build

- Baseline family game systems, task sequence, world object contracts, and regression scaffolding are intact from Milestones 0/1 source.
- Five ordered tasks are still present and wired through config:
  1. George beer
  2. wash dishes
  3. take out trash
  4. find Missy’s lost toy
  5. hack Medford bank
- Host/guest co-op architecture exists in source, including:
  - party protocol and server state
  - revisioned ready states
  - host-gated purchases
  - one-use launch tickets
  - explicit host grace windows
  - session manifests and admission flow scaffolding
- Money and progression are moving toward exactly-once semantics via operation IDs.
- Transaction ledger has dedicated sanitizer/replay behavior and bounded rollback handling.
- M1 rollback and source-canonical map files are in place in source and docs.
- Lobby UI and terminal UX closure is implemented in source and previous Studio evidence is positive for several paths.
- A local deterministic test suite exists and currently reports full pass for the deterministic contract set.

### What is explicitly not yet proven in production runtime

- Real cross-place launch in published Roblox Player client.
- Real MemoryStore + TeleportService + guest/host reconnect behavior under network fault conditions.
- Four-player live gameplay proof.
- Full physical-device mobile testing for the in-game UI.
- Remote abuse/flood/replay mitigation in published runtime.
- Persisted concurrency fault tests for connected real servers (save retries, duplicate packets, concurrent sessions).
- Visual polish audit for final M1 candidate in active in-game client (the newer local changes are not yet run through the full Studio verification stack).

## 2) Source-of-truth status and where to read it

The following files form the current production contract:

- [PLAN.md](PLAN.md) — master contract and current implementation intent
- [UNRESOLVED_DECISIONS.md](UNRESOLVED_DECISIONS.md) — open Milestone 2 blockers that must remain visible
- [TEST_RESULTS.md](TEST_RESULTS.md) — current gate status and what remains open
- [MILESTONE1_IMPLEMENTATION.md](MILESTONE1_IMPLEMENTATION.md) and [MILESTONE1_TEST_MATRIX.md](MILESTONE1_TEST_MATRIX.md)
- [CooperFamilyTaskConfig.module.luau](CooperFamilyTaskConfig.module.luau)
- [verify_milestone1_local.sh](tools/verify_milestone1_local.sh)
- Runtime/GUI source files in root and lobby folders listed in the current test manifests.

## 3) Current implementation scope details (what “features complete” means)

### Milestone 1 core systems currently present in source

1. **Single source map and canonical wiring**
   - `CooperFamilyTaskGame`, `CooperFamilyTaskWorld`, `CooperTaskGame.client`, `CooperBunker`, `lobby/CooperLobby`, `CooperPartyProtocol`, `CooperTransactionLedger`, and allied modules are mapped in the manifests.
2. **Lobby + private party flow**
   - Private invited parties only (1–4 members), host-only launch rights, party revision and readiness snapshots.
3. **Economy migration + operation ledger**
   - Operation IDs now cover payouts, task completion barriers, paid install transitions, candy/boombox/robot operations, and related reconciliation paths.
4. **Host/guest permission boundaries**
   - Host-only persistence writes remain enforced in local source (guests cannot complete world purchases).
5. **Ready/Start repair logic in source**
   - Independent action throttles and explicit launch reasons are present in source and deterministic coverage exists.

### Config-visible systems that are already authored but may be runtime-gated

From [CooperFamilyTaskConfig.module.luau](CooperFamilyTaskConfig.module.luau):

- Feature flags remain at Milestone-1 level (`Lobby=true`, others false).
- Five tasks and five automation upgrades are defined.
- Bunker, boombox, bank, and machine stage progression are still configured.
- Release player cap for host world is already 4.

### Evidence snapshot to trust (and what it does not prove)

- **Trust:** deterministic local contracts and static verifiers currently show no compile/runtime-safety regressions in this workspace.
- **Do not infer:** live cross-place launch behavior from Studio in-place handoff evidence; those checks are explicitly partial and still require published-client execution.

## 4) Milestone 2 blocker register (must remain open)

See [UNRESOLVED_DECISIONS.md](UNRESOLVED_DECISIONS.md). In brief:

- `OPEN-M2-01` task cursor after task timeout
- `OPEN-M2-02` survival anchor timing
- `OPEN-M2-03` first natural reveal penalty logic
- `OPEN-M2-04` Milestone 2 survival payout
- `OPEN-M2-05` post-reveal cycle anchoring and persistence
- `OPEN-M2-06` timeout interruption semantics for active systems
- `OPEN-M2-07` reveal media readiness and approvals

None of these can be skipped or approximated later by guesswork, because Milestone 2 introduces persistence, progression, and encounter logic contracts that must be decided before release-safe implementation.

## 5) What to do next: milestone closure path (recommended sequence)

### Phase A — Finish Milestone 1 closure

1. **Freeze current source into a candidate baseline** in the existing branch.
2. **Synchronize only the canonical source map** into the correct backed-up Studio instances.
3. **Run full local+Studio verifier passes** for: 
   - [verify_milestone1_foundation.luau](verify_milestone1_foundation.luau)
   - [verify_milestone1_value_operations.luau](verify_milestone1_value_operations.luau)
   - [verify_milestone1_remote_inventory.luau](verify_milestone1_remote_inventory.luau)
   - [verify_ui_accessibility_static.luau](verify_ui_accessibility_static.luau)
4. **Complete pending live M1 gates** from [MILESTONE1_TEST_MATRIX.md](MILESTONE1_TEST_MATRIX.md):
   - solo/2-player/4-player launch paths
   - invite/ready/launch rejections
   - host and guest reconnect behavior
   - ticket/session replay safety
   - movement input, sprint, and mobile accessibility checks
5. **Capture publish candidate evidence** in private test versions before changing gates or enabling future features.

### Phase B — Start Milestone 2 only after M1 fully closed

Use the locked decisions in PLAN plus the test plan sections for Horror/Task Pressure:

1. Resolve all open decisions in [UNRESOLVED_DECISIONS.md](UNRESOLVED_DECISIONS.md) and record answers in PLAN.
2. Implement encounter/cycle timing and failure reason architecture with exact-one state transitions.
3. Deliver reveal pipeline only after reveal media + audio manifest + moderation status is approved (`OPEN-M2-07`).
4. Add M2 smoke + integration + multiplayer cases from the review/test-plan and keep gates strict.

## 6) Milestones 3–9 high-level future implementation order

Once Milestone 2 is green-lit and closed, continue in this order:

1. **Milestone 3** — character reveal art/audio integration and horror presentation.
2. **Milestone 4** — encounter depth, hunt pacing, hiding and obstacle systems with occupancy controls.
3. **Milestone 5** — escalation/automation balancing and progression economics.
4. **Milestone 6** — optional route content (tunnel/backrooms/dome stream regions).
5. **Milestone 7** — Stage 11 machine integration and pre-finale reveal timing.
6. **Milestone 8** — black-hole launch, high-detail finale streaming region, and future apartment transition in-house.
7. **Milestone 9** — final choice routing and personal postgame loop.

## 7) Required “done” definition for any future milestone

For any milestone to be marked complete:

- All required tests in the master matrix must have evidence rows marked PASS.
- Open decisions must be closed and documented in [PLAN.md](PLAN.md).
- A rollback-safe candidate artifact exists in `/backups`.
- A published private test evidence trail proves no duplicate value, no stuck states, and no silent progression loss.
- Visual/accessibility acceptance for desktop + representative mobile presets is captured and attached.

## 8) Current progress number (quick tracker)

From existing verification matrix counts:

- Local deterministic and static M1 closure checks: PASS state in progress.
- Live/toplevel runtime M1 gates: many are still `NOT RUN` or `PARTIAL`.

Practical interpretation: the project is **around Milestone 1 baseline closure**, but **not yet a release-safe milestone** because launch/reconnect/published runtime safety evidence is incomplete.

## 9) Working reference checklist for you and future contributors

Before coding any M2+ feature:

- Read [PLAN.md](PLAN.md) first.
- Check [TEST_RESULTS.md](TEST_RESULTS.md) for currently blocking rows.
- Check [UNRESOLVED_DECISIONS.md](UNRESOLVED_DECISIONS.md) for blockers.
- Use [MILESTONE1_TEST_MATRIX.md](MILESTONE1_TEST_MATRIX.md) as the row-level gate.
- Do not enable Horror or finale flags before Milestone 1 is actually closed.
