# Current Verification Results

Run date: 2026-07-22  
Repository root: `/Users/tanishkalwad/Documents/Roblox_Dev/code/FirstGame`  
Current candidate source commits: `f31c0cd` + `14932d7`

Evidence documents were updated in the shared working tree after those commits.

## Executive result

- Milestone 0 has recorded acceptance evidence for its original safe-baseline scope, but the later comprehensive test plan adds published, physical-device, persistence-fault, and broader migration checks that are not all complete.
- Milestone 1 is **not closed**. Its source foundation and local repairs are substantial, but the canonical plan labels its gate open and the required published reserved-server, reconnect, persistence, security, full regression, and physical-mobile evidence is missing.
- Milestone 2 runtime has **not been implemented or enabled**. Only deterministic, local contract primitives have been added. This is intentional because Milestone 1 is still open and seven Milestone 2 decisions remain unresolved.

## Local deterministic suite

Command:

```sh
luau tests/run.luau
```

Result: **PASS — 82 passed, 0 failed, 82 total**

Covered locally:

- fake monotonic clock;
- deterministic random source;
- three explicit historical Milestone 0 schema-10-to-11 migration fixtures plus deterministic token repair;
- historical schema-11 idempotency for every represented fixture;
- one complete explicit schema-11-to-12 profile fixture preserving all 34 old fields;
- missing, malformed, duplicate, cross-list replay, capacity, result-bound, and idempotency tests against the actual production operation-journal sanitizer;
- immutable party eligibility snapshot behavior;
- durable calm-task start checkpoints, exact recovered-member grace boundaries,
  loading/detached follow-up sweeps, and host-last checkpoint clearing;
- serialized profile-save revision behavior proving a yielded older write cannot
  clear or overwrite a newer allowance/checkpoint mutation;
- terminal value-operation retry ordering, including authorization, identity,
  stale-session, and reconciliation-block behavior;
- the shared task host-last payout barrier;
- test-double at-most-once transaction behavior;
- thirteen direct production-ledger lifecycle checks covering commit, retained
  duplicate rejection, separate 256-result and rollback-tombstone capacities,
  legacy co-mingled rollback migration, replay rejection after committed or
  rollback eviction, pending/reconciliation issuance reservations, persistent
  replay watermarks, fail-closed sequence exhaustion, and out-of-order
  commit/rollback trimming;
- pre/post-reveal deadline and cash-penalty arithmetic;
- reason-counted overlapping pauses; and
- exact four-character hunter mappings and safe unknown-task rejection.

These are local CLI contract tests. They do not prove Roblox DataStore writes/retries, Studio object state, UI appearance, network replication, asset permissions, or published-server behavior. The production ledger sanitizer and its bounded replay/rollback lifecycle are directly exercised, but the Roblox-dependent outer profile sanitizer and save lifecycle still require isolated integration/fault tests.

## Static local checks

The expected commands for this batch are:

```sh
luau-analyze tests/run.luau tests/support/*.luau tests/specs/*.luau \
  CooperTransactionLedger.module.luau
while IFS= read -r file; do luau-compile "$file" >/dev/null; done \
  < <(rg --files -g '*.luau')
bash verify_runtime_register_budget.sh
git diff --check -- tests TEST_TRACEABILITY.md TEST_RESULTS.md \
  UNRESOLVED_DECISIONS.md REMOTE_SECURITY_MATRIX.md MIGRATION_FIXTURES.md
```

Result: **PASS**. The test analyzer emitted no diagnostics, all 120 local Luau
sources compiled, all 27 core-server register-profile checks passed (the full
`O0`/`O1`/`O2` × `g0`/`g1`/`g2` matrix for `CooperGame`, `CooperBunker`, and
`CooperTaskWorld`), and `git diff --check` reported no whitespace errors.

The register matrix is a required pre-Studio guard because ordinary `O1/g1`
compilation previously missed Roblox's 200-register startup failure.

## Current candidate Studio evidence

The first Studio candidate run exposed the 200-register startup failure in
`CooperGame` and `CooperBunker`; missing core-event reports from
`CooperTaskWorld` were downstream symptoms. After the source repair and 27/27
register preflight, a clean fresh rerun of
`verify_runtime_startup_readiness.luau` reported
`RuntimeStartupReadiness PASS`.

The exact same-session Studio flow was:

```text
CreateParty → SetReady true → Launch (zero delay)
READY_COMMITTED → STUDIO_HOUSE_STARTED
```

A second fresh `PlaySolo` run again returned `STUDIO_HOUSE_STARTED` with
authoritative `selfReady = true` and `canLaunch = true`; startup readiness
passed again. The corresponding server/client startup logs contained no
project errors or warnings, apart from the external Studio MCP
version-mismatch warning.

Additional current-candidate observations:

- the Milestone 1 lobby edit audit passed 316 checks;
- the Studio house preview passed 71 edit checks and 118 active-runtime checks;
- the physical-prompt guard audit passed 124 checks;
- the running server reported schema 12, `FoundationContract = PartyV1`, a
  loaded `Active` host profile, four core RemoteEvents, and ready task-world and
  automation controllers;
- the runtime roster was exactly George, Georgie, Mary, and Missy;
- `Horror`, `SecretExploration`, `TimeMachineFinale`, `Postgame`, and
  `StudioScenarioTools` all remained false;
- a sustained client-side Humanoid movement command covered 24.68 studs at
  `WalkSpeed = 16`, with a normal camera and `PlatformStand = false`; this did
  not exercise current-candidate keyboard/touch input; and
- an idle profiler sample measured a maximum server script share of 1.68% for
  `CooperYardRideables`; the largest client entry was external/core and below
  0.8%.

That profiler observation is idle-only. It is not a mobile, multiplayer,
active-feature, or soak performance pass.

Rollback export:

- `backups/milestone-1/2026-07-22_23-21-46_EDT_schema12-studio-preview-verified.rbxm`
- 668659 bytes
- SHA-256
  `09dc971d4f534c34c369d82455a7bac026ec6bc7342d0d3ec2cbcf91a5a2fb7a`

The schema-12 journal now covers the documented shared-task payouts and six
paid-order operations. Global exactly-once coverage is still incomplete:
candy payout, boombox payout ticks, `AdjustCurrency`, `SpendAllowance`, and
physical install transitions remain outside the complete
operation-ID/reconciliation path.

## Milestone gate table

| Gate | Current result | Evidence | Blocking evidence still required |
|---|---|---|---|
| Milestone 0 original baseline | PASS (recorded scope) | `MILESTONE0_VERIFICATION.md`, manifest/restore files, baseline verifier | Re-certify current clean candidate; physical supported phone; published debug audit; isolated persistence fault tests; complete legacy fixture catalog |
| Milestone 1 local/source foundation | PARTIAL | Candidate commits `f31c0cd` + `14932d7`; 120/120 default compile; 27/27 register preflight; 82/82 deterministic tests; clean `RuntimeStartupReadiness PASS`; 316 lobby edit, 71 preview edit, 118 preview runtime, and 124 prompt-guard checks | Published solo/2-player/4-player launch, real reserved-server routing, MemoryStore/tickets, host/guest reconnect, global fault-injected exactly-once persistence, runtime security abuse, full regression, and UI/device acceptance |
| Milestone 1 release gate | FAIL / OPEN | Canonical `PLAN.md` says `GATE OPEN`; matrix contains `NOT RUN`/`PARTIAL` rows | Every P0 gate row must have reproducible PASS evidence |
| Milestone 2 deterministic rule foundation | PARTIAL | 82-test local suite | Production architecture/adapters, unresolved decisions, encounter cleanup verifier, runtime tests |
| Milestone 2 runtime/visual gate | BLOCKED / NOT STARTED | Horror feature remains disabled | Milestone 1 closure; seven open decisions; approved assets; implementation and full M2 suite |

## Environment-dependent tests not claimed

The following remain **NOT RUN**, **BLOCKED**, or deliberately unclaimed for
this candidate:

- Studio or published multiplayer completion;
- any write to DataStore or MemoryStore;
- any TeleportService reserved-server or cross-place flow;
- any publish, overwrite, new-place creation, or live configuration mutation;
- any physical mobile/tablet/controller playtest;
- any real-device MicroProfiler capture or soak run;
- screenshot-based desktop/mobile visual acceptance and the complete existing
  feature regression;
- any per-character scary art/audio permission or moderation check; and
- any horror encounter, chase, UI, NPC transformation, or cleanup scenario.

## Open decisions

The seven Milestone 2 blockers are recorded verbatim in `UNRESOLVED_DECISIONS.md`: timeout task cursor, survival-clock anchor, first natural reveal penalty, survival payout, post-reveal cycle anchor, active-system interruption rules, and reveal asset readiness.

## Safe next gate

Before production Milestone 2 work, close Milestone 1 with a clean candidate and reproducible published/private evidence. In parallel, the safe local work is to finish the non-runtime test infrastructure: production-adapter tests for eligibility and transaction IDs, a snapshot/cleanup verifier design, migration fault fixtures, and a scripted two-client simultaneous-completion scenario. None of that requires turning on horror.
