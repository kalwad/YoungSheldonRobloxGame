# Current Verification Results

Run date: 2026-07-23
Repository root: `/Users/tanishkalwad/Documents/Roblox_Dev/code/FirstGame`  
Current local candidate: working tree based on Git commit `f823103`

The closure changes and this evidence update are not yet represented by a
frozen candidate commit or published Roblox version.

## Executive result

- Milestone 0 has recorded acceptance evidence for its original safe-baseline scope, but the later comprehensive test plan adds published, physical-device, persistence-fault, and broader migration checks that are not all complete.
- Milestone 1 is **not closed**. Its source foundation and local repairs are substantial, but the canonical plan labels its gate open and the required published reserved-server, reconnect, persistence, security, full regression, and physical-mobile evidence is missing.
- Milestone 2 runtime has **not been implemented or enabled**. Only deterministic, local contract primitives have been added. This is intentional because Milestone 1 is still open and seven Milestone 2 decisions remain unresolved.

## Local deterministic suite

Command:

```sh
luau tests/run.luau
```

Result: **PASS — 130 passed, 0 failed, 130 total**

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
- stable Milestone 1 operation identities for candy production/collection/sale,
  ten indexed boombox ticks, a completed-playback settlement that reaches
  exactly `$300` under missing ticks, retry/save failure, duplicate callbacks,
  and tick/end races, paid physical install transitions, and bounded
  operation-key input;
- revisioned Ready state, independent Ready/Start throttles, launch ownership,
  double-Start idempotency, reservation failure, and one shared bounded retry
  budget for synchronous request failure or asynchronous
  `TeleportInitFailed`, reusing the original reservation, session manifest,
  admission tickets, `TeleportOptions`, and launch token;
- user-bound one-use admission tickets, exact 90-second expiry, stale
  membership rejection, and retryable directory failure;
- one reason-counted host-grace transition, duplicate disconnect handling,
  valid rejoin immediately before 60 seconds, exact-boundary close, and forged
  non-host rejection;
- server-authoritative sprint exhaustion, idle behavior, recovery, movement
  locks/carry composition, tamper correction, reset, and toggle spam;
- same-frame two-client task completion, outsider rejection, and
  fail-before-write/fail-after-write reward reconciliation;
- pre/post-reveal deadline and cash-penalty arithmetic;
- reason-counted overlapping pauses; and
- exact four-character hunter mappings and safe unknown-task rejection.

These are local CLI contract tests. They do not prove Roblox DataStore writes/retries, Studio object state, UI appearance, network replication, asset permissions, or published-server behavior. The production ledger sanitizer and its bounded replay/rollback lifecycle are directly exercised, but the Roblox-dependent outer profile sanitizer and save lifecycle still require isolated integration/fault tests.

## Static local checks

The repeatable current command is:

```sh
bash tools/verify_milestone1_local.sh
```

Result: **PASS**. All eight phases completed: the test analyzer emitted no
diagnostics, all 140 local Luau sources compiled, all 130 deterministic
contracts passed, all 27 core-server register-profile checks passed (the full
`O0`/`O1`/`O2` × `g0`/`g1`/`g2` matrix for `CooperGame`, `CooperBunker`, and
`CooperTaskWorld`), and `git diff --check` reported no whitespace errors. The
frozen schema/cap/place/feature contracts passed, expected journaled
value-operation markers were present, all 13 active clients passed the
authority scan, and retired/future runtime surfaces remained disabled.

The register matrix is a required pre-Studio guard because ordinary `O1/g1`
compilation previously missed Roblox's 200-register startup failure.

## Carried-forward Studio evidence

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

Additional carried-forward observations:

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

These Studio observations predate the current working-tree closure changes.
They must not be treated as execution evidence for the asynchronous bounded
teleport retry, candy/boombox/install operation paths, exact `$300` boombox
settlement, or new read-only verifiers.
`verify_milestone1_value_operations.luau`,
`verify_milestone1_remote_inventory.luau`, and
`verify_ui_accessibility_static.luau` compile, but they remain **NOT RUN** in
current-candidate Studio edit/client-runtime and published-client contexts.

Rollback export:

- `backups/milestone-1/2026-07-22_23-21-46_EDT_schema12-studio-preview-verified.rbxm`
- 668659 bytes
- SHA-256
  `09dc971d4f534c34c369d82455a7bac026ec6bc7342d0d3ec2cbcf91a5a2fb7a`

This export is a valid carried-forward rollback artifact, but it predates the
current local closure changes and is not the final current-candidate export.

The schema-12 journal now covers the documented shared-task payouts, all six
paid-order operations, candy production/collection/sale, indexed boombox payout
ticks, a stable completed-playback boombox settlement, and paid
task-upgrade/chemistry/boombox/machine-stage install acknowledgements. The
settlement reaches exactly `$300` without overpaying in the deterministic
missing-tick/save/retry/race cases. Broad `AdjustCurrency` and
`SpendAllowance` routes fail closed as deprecated. This is source and
deterministic evidence, not global exactly-once release proof; isolated
DataStore failures, concurrent servers, disconnect/rejoin, and published
multiplayer still require execution.

## Milestone gate table

| Gate | Current result | Evidence | Blocking evidence still required |
|---|---|---|---|
| Milestone 0 original baseline | PASS (recorded scope) | `MILESTONE0_VERIFICATION.md`, manifest/restore files, baseline verifier | Re-certify current clean candidate; physical supported phone; published debug audit; isolated persistence fault tests; complete legacy fixture catalog |
| Milestone 1 local/source foundation | PARTIAL | Working tree based on `f823103`; eight-phase local gate PASS with 140/140 compile, 130/130 deterministic tests, 27/27 register preflight, 13 active client authority scans, and clean config/value/disabled-surface checks; carried-forward Studio evidence includes clean `RuntimeStartupReadiness PASS`, 316 lobby edit, 71 preview edit, 118 preview runtime, and 124 prompt-guard checks | Current-candidate Studio verifier runs; published solo/2-player/4-player launch; real reserved-server routing; MemoryStore/tickets; host/guest reconnect; fault-injected exactly-once persistence; runtime security abuse; full regression; human UI/device acceptance |
| Milestone 1 release gate | FAIL / OPEN | Canonical `PLAN.md` says `GATE OPEN`; matrix contains `NOT RUN`/`PARTIAL` rows | Every P0 gate row must have reproducible PASS evidence |
| Milestone 2 deterministic rule foundation | PARTIAL | Deadline, pause, and hunter-rule cases within the 130-test local suite | Production architecture/adapters, unresolved decisions, encounter cleanup verifier, runtime tests |
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

Before production Milestone 2 work, freeze a clean Milestone 1 candidate, sync
only its canonical source map into the already connected backed-up Studio
places, run the new value-operation/remote-inventory/UI audits plus the complete
M0/M1 regression, and then collect reproducible privately published
solo/two/four-player and physical-device evidence. No horror feature flag or
runtime should be enabled while those rows remain open.
