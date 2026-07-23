# Unresolved Decisions Register

Status date: 2026-07-22

This register contains only decisions that remain open after reconciling the canonical [PLAN.md](PLAN.md), the roadmap review, the comprehensive test plan, and the current source. The twelve cross-system decisions in `PLAN.md` section 4 are already locked; they are not reopened here.

No runtime implementation may silently choose an answer to an item below. A decision is closed only when its answer is added to the canonical plan, its affected tests are updated without weakening their assertions, and the decision is recorded in the change log.

## OPEN-M2-01 — Task cursor after a timed-out task

Status: **OPEN — blocks the Milestone 2 task-state integration**

The plan does not say whether a timed-out task returns to the same task at a safe starting step or advances to the next ordered task after the encounter. Retrying the same task is the safer product rule, but current task state advances its cursor when a task starts, so this cannot be assumed without an explicit migration and state-transition contract.

Required decision:

- choose `RetrySameTaskFromSafeStart` or `AdvanceToNextTask`;
- define the persisted safe checkpoint and the treatment of any carried item, delivery, robot job, and partial interaction; and
- add boundary, reconnect, and duplicate-timeout tests for the chosen transition.

## OPEN-M2-02 — First encounter survival clock anchor

Status: **OPEN — blocks encounter timing assertions**

The reveal timeline reaches the chase at approximately encounter second 10, while the plan also specifies a 30-second first survival. It is not explicit whether survival ends at encounter second 30 or after 30 seconds of chase at encounter second 40.

Required decision:

- choose `30SecondsFromEncounterStart` or `30SecondsFromChaseStart`; and
- make `M2-026`, `M2-028`, the client presentation recorder, and the server result deadline use the same anchor.

## OPEN-M2-03 — Penalty exemption for the first natural reveal

Status: **OPEN — blocks capture settlement**

`M2-031` exempts the guaranteed story reveal from a money deduction, while `M2-032` applies the cycle formula to a natural capture. The plan does not explicitly settle whether the first-ever natural timeout/reveal is also a story reveal and therefore penalty-free.

Required decision:

- choose whether every player's first reveal is penalty-free regardless of natural/forced cause, or only the forced cycle-4 electrical fault is exempt; and
- express the result as a server-owned encounter reason code rather than inferring it from the UI sequence.

## OPEN-M2-04 — Milestone 2 survival payout

Status: **OPEN — blocks survival value operation**

Milestone 2 specifies survival and restoration but does not lock a payout. Milestone 5 later proposes a `$25` bravery bonus. Applying that amount early would be a design guess and would change the economy.

Required decision:

- choose `NoPayoutUntilMilestone5` or a specific Milestone 2 payout; and
- define its operation ID, eligibility snapshot, retry behavior, and economy telemetry.

## OPEN-M2-05 — Post-reveal cycle anchor and persistence

Status: **OPEN — blocks deadline progression persistence**

If the first natural reveal occurs in the middle of cycle 2 or 3, the relationship among `cycleIndex`, `cycleTaskIndex`, and `postRevealCyclesCompleted` is ambiguous. It is not clear whether the partially completed cycle becomes pressure cycle 1, resets to task 1 as pressure cycle 1, or finishes under its pre-reveal budget.

Required decision:

- define the exact transition tuple for natural and forced reveals;
- define what is saved at the safe checkpoint; and
- add schema/current-profile and reconnect fixtures for reveal at every task position in cycles 2 and 3.

## OPEN-M2-06 — Timeout interruption policy for active systems

Status: **OPEN — blocks safe encounter entry and cleanup**

The current game can have a boombox session, robot route, bank-hack session, buyer or delivery route, held/carry item, chemistry state, and terminal UI active when a task deadline expires. The plan does not yet specify which systems pause, abort, finish in the background, or resume after restoration.

Required decision:

- define explicit server-owned `Pause`, `AbortToSafeCheckpoint`, `Continue`, and `Resume` rules for boombox, every robot type, bank hacking, ordinary delivery, buyer delivery, chemistry, carried tools, cube sessions, and both terminals;
- define cancellation/recovery reason codes; and
- require encounter snapshot/cleanup tests for every simultaneous-system combination included in the supported matrix.

## OPEN-M2-07 — Reveal image and audio asset readiness

Status: **OPEN — blocks the Milestone 2 visual acceptance gate**

Per-character reveal images, scary cutouts, audio mappings, ownership/permission status, and content review are not present as an approved manifest. Milestone 2 can define a presentation interface, but it cannot pass the intended visual/audio gate with guessed or unavailable assets.

Required decision:

- provide or approve one reveal image, scary cutout, and allowed audio mapping for George, Mary, Missy, and Georgie;
- record asset ID, source, owner, permission status, fallback, and moderation status in the asset manifest; and
- confirm legibility and presentation on desktop and physical supported phones.

## Closure rule

All seven entries are currently **OPEN**. They must remain visible as blockers in `TEST_RESULTS.md` and the Milestone 2 gate until the canonical plan contains explicit answers. Deterministic test-support modules may model already locked rules, but no production horror handler, remote, UI, asset, feature-flag activation, or Studio installation is authorized by this register.
