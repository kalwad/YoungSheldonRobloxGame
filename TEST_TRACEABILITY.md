# Test Traceability Ledger

Status date: 2026-07-22

This ledger maps currently implemented foundations and Milestone 2 contracts to source evidence and executable tests. A green local contract test is not evidence that its production adapter, Studio DataModel, published place, TeleportService path, DataStore path, real device UI, or asset permission has passed.

Result vocabulary follows `PLAN.md`: **PASS**, **FAIL**, **BLOCKED**, **NOT RUN**, and **PARTIAL**.

## Deterministic test foundation

| Contract / requirement | Production or plan authority | Executable evidence | Status | What remains |
|---|---|---|---|---|
| Fake monotonic time | `PLAN.md` sections 5.4, 10 and `M2-016` | `tests/support/FakeClock.luau`, `tests/specs/FakeClock.spec.luau` | PASS (contract) | Inject a clock into production session/deadline modules; Studio stall test |
| Deterministic random selection | `PLAN.md` sections 5.4, 10, 12.2 | `tests/support/DeterministicRandom.luau`, `tests/specs/DeterministicRandom.spec.luau` | PASS (contract) | Production RNG adapter and recorded-seed replay |
| Immutable eligibility at operation start | DEC-02; `M1-013` through `M1-021` | `tests/support/EligibilitySnapshot.luau`, `tests/specs/EligibilitySnapshot.spec.luau` | PASS (contract) | Shared task scheduler must capture and persist this set; 2/4-client scenarios |
| Server-issued at-most-once operation behavior | `PLAN.md` section 5.3; `M0-006`, `M1-018`, `M1-019`, `M2-035` | `tests/support/TransactionLedger.luau`, `tests/specs/TransactionLedger.spec.luau` | PASS (test double) | Wire a production ledger to every value-bearing operation and test save retry/stale callbacks/concurrent servers |
| Reason-counted pauses | `PLAN.md` section 5.4; `M2-009` through `M2-015` | `tests/support/PauseSet.luau`, `tests/support/PausableDeadline.luau`, `tests/specs/PauseSet.spec.luau` | PASS (mechanism) | Lock the approved pause reasons and production adapters; terminal/bank UI must continue per `M2-013` |
| Locked deadline math | `M2-001` through `M2-008`, `M2-033`, `M2-034` | `tests/support/DeadlineRules.luau`, `tests/specs/DeadlineRules.spec.luau` | PASS (rule oracle) | Production task/session state machine, exact timeout commit, UI, forced reveal, and open decisions in `UNRESOLVED_DECISIONS.md` |
| Approved hunter mapping | `M2-018` through `M2-024` | `tests/support/HunterRules.luau`, `tests/specs/HunterRules.spec.luau` | PASS (rule oracle) | Production registry/state transition; bank seed integration; client hunter requests must remain impossible |
| Historical schema 10 to 11 preservation and idempotency | `M0-003`, `M0-004`, `MIG-001`, `MIG-002` | `tests/support/ProfileMigrationFixtures.luau`, `tests/support/ProfileMigrationOracle.luau`, `tests/specs/ProfileMigration.spec.luau` | PARTIAL | Historical represented fixtures pass; every earlier supported schema and isolated persistence remain missing |
| Current schema 11 to 12 journal migration | `MIG-001`, `MIG-002`, `MIG-005`–`MIG-007`, `MIG-011`, `MIG-015` | `tests/support/ProfileSchema12Fixtures.luau`, `tests/support/ProfileSchema12MigrationOracle.luau`, `tests/specs/ProfileSchema12Migration.spec.luau`, production `CooperTransactionLedger.module.luau` | PASS locally / overall PARTIAL | All 34 old fields, default, malformed, duplicate, capacity, and idempotency assertions pass against the real journal sanitizer; Roblox persistence/fault/size cycles remain |

## Milestone 0 evidence

| Requirement area | Existing evidence | Status under the comprehensive plan | Notes |
|---|---|---|---|
| Dated baseline, rollback, canonical sources, retired systems | `MILESTONE0_VERIFICATION.md`, `BASELINE_MANIFEST.md`, `RESTORE.md`, baseline verifier | PASS for recorded M0 scope | Preserve the accepted baseline and Git history; do not broadly sync retired installers |
| Five ordered tasks, eleven machine stages, four approved cutout NPCs | `verify_milestone0_baseline.luau`, `verify_game_foundation.luau` | PASS for source/runtime audit | The four are George, Mary, Missy, and Georgie; no Sheldon/Billy/Mandy/Meemaw additions are approved |
| Future features safely disabled at M0 | config/runtime verification | PASS historically | Current source intentionally enables `Lobby` for M1; `Horror`, `SecretExploration`, `TimeMachineFinale`, `Postgame`, and `StudioScenarioTools` remain false |
| Profile schema migration foundation | schema-12 production sanitizer, journal module, and schema attributes | PARTIAL under expanded test plan | Historical 10→11 and current 11→12 fixtures pass locally. Save-failure, duplicate-callback, two-server, payload-size, 100-cycle, and every-old-schema tests remain. |
| Full baseline playthrough and rejoin paths | `MILESTONE0_VERIFICATION.md` | PASS for the recorded build, not re-certified for every current dirty edit | Must be rerun on a clean candidate after M1 closes |
| Physical supported-phone pass | no physical-device artifact found | NOT RUN | Simulator evidence does not satisfy `M0-002` |
| Published debug/scenario surface audit | local verifier exists; no published artifact found | BLOCKED / NOT RUN | Must inspect an actual published candidate and try guessed controls |
| Isolated test DataStore/universe and migration fault injection | no completed evidence found | NOT RUN | Must never use live profile stores for this test |

## Milestone 1 evidence

| Requirement area | Source / existing artifact | Status | Required closure evidence |
|---|---|---|---|
| 1980s lobby and responsive client UI | `lobby/CooperLobby.client.luau`, `CooperUITheme.module.luau`, M1 docs | PARTIAL | Visual screenshots at required desktop/mobile sizes, text scaling/contrast/touch checks, physical phone pass |
| Core compile/register/startup readiness | candidate `f31c0cd` + `14932d7`; compile, register, and startup verifiers | PASS for local source and current Studio preview | 120/120 default compilation, full 27/27 `O0`/`O1`/`O2` × `g0`/`g1`/`g2` register matrix, and clean fresh `RuntimeStartupReadiness PASS`; published startup remains open |
| Ready then Start / solo launch repair | per-action lobby rate limiting and launch diagnostics in `lobby/CooperLobby.server.luau`; `verify_lobby_launch_repair.luau`; current Studio run | PARTIAL | Exact CreateParty → `SetReady true` → zero-delay Launch returned `READY_COMMITTED` then `STUDIO_HOUSE_STARTED`; a second fresh PlaySolo did the same with authoritative `selfReady`/`canLaunch = true`. Published solo and invited-party reserved-server launch must still pass |
| Server-owned party manifest, host, readiness, tickets | lobby server/config, `verify_milestone1_foundation.luau`, current preview runtime | PARTIAL | Current runtime reported schema 12 / `PartyV1`, loaded `Active` host, and four core remotes; real MemoryStore/TeleportService replay, outsider, expiration, and partial-failure tests remain |
| Shared task scheduler and host-world authority | `CooperFamilyTaskGame.server.luau`, config, foundation verifier, 82/82 deterministic suite | PARTIAL | Immutable eligibility and schema-12 transaction-journal source are present; still need two-client same-frame completion, four-client spam/soak, and fault-injected exactly-once persistence |
| Host-only purchases and value-operation identity | family server validation, terminal session checks, schema-12 journal | PARTIAL | The documented shared-task payouts and six paid orders are journaled. Candy payout, boombox payout ticks, `AdjustCurrency`, `SpendAllowance`, and physical install transitions still need operation IDs/reconciliation, plus guest/concurrent/interruption tests |
| Host/guest reconnect policy | lobby/house session source and M1 matrix | PARTIAL | Published 59-second/expired host rejoin, 90-second guest rejoin, duplicated disconnect callback, all-disconnect close |
| Sprint authority and mobile input | `CooperMovement.server.luau`, `CooperSprint.client.luau`, verifier, current movement observation | PARTIAL | A sustained client-side Humanoid command moved 24.68 studs at WalkSpeed 16 with normal camera and no PlatformStand; current keyboard/touch input, scenario/security suite, controller/input switching, and physical phone resolutions remain |
| Runtime roster and disabled future features | current preview runtime | PASS for current local Studio preview | Exactly George, Georgie, Mary, and Missy; world/automation ready; Horror/SecretExploration/TimeMachineFinale/Postgame/StudioScenarioTools false. Original NPC art/dialogue/catchphrases and complete gameplay regression remain separate open rows |
| Physical-prompt guards | `verify_prompt_security_guards.luau` | PARTIAL | 124 source/runtime guard checks passed; published abuse, flood, moved-part proximity, and multiplayer contention remain |
| Idle performance sample | current Studio preview profiler | PARTIAL | Server max 1.68% (`CooperYardRideables`), client external/core max below 0.8%; active gameplay, four-player, mobile, and soak captures remain |
| Rollback candidate | `backups/milestone-1/2026-07-22_23-21-46_EDT_schema12-studio-preview-verified.rbxm` | PASS for local artifact | 668659 bytes; SHA-256 `09dc971d4f534c34c369d82455a7bac026ec6bc7342d0d3ec2cbcf91a5a2fb7a`; this is not a published release certificate |
| Production debug isolation | `verify_production_build_surface.luau` | PARTIAL / BLOCKED | Run against the published candidate; prove no scenario control is usable |

The canonical `PLAN.md` correctly labels Milestone 1 **GATE OPEN**. Milestone 2 runtime activation is therefore not permitted.

## Milestone 2 pre-implementation traceability

| M2 IDs | Contract state | Evidence | Status |
|---|---|---|---|
| `M2-001`–`M2-008` | pre/post-reveal budget and penalty arithmetic modeled | Deadline rule spec | PASS as isolated rules; runtime NOT IMPLEMENTED |
| `M2-009`–`M2-015` | overlapping pause accounting modeled | pause/deadline specs | PASS as mechanism; allowed reason policy/runtime NOT IMPLEMENTED |
| `M2-016`–`M2-017` | server monotonic/client-independent time | fake clock only | PARTIAL; production/security scenarios NOT RUN |
| `M2-018`–`M2-024` | exact four-NPC hunter registry modeled | hunter spec | PASS as isolated mapping; runtime/security NOT IMPLEMENTED |
| `M2-025`–`M2-045` | encounter state, visuals, pathing, result, restoration | no production horror runtime | BLOCKED / NOT RUN |
| Encounter snapshot/cleanup verifier | required first test batch artifact | not yet present as a production DataModel snapshot/diff verifier | NOT RUN |
| Scary/reveal asset acceptance | user-provided asset plan, `OPEN-M2-07` | no approved manifest/mappings | BLOCKED |

## Security traceability

The current network and prompt inventory is maintained in `REMOTE_SECURITY_MATRIX.md`. It records source-proven validation separately from untested runtime behavior. The highest-priority open checks are:

- published debug/scenario surface rejection (`M0-011`, `M0-012`, `SEC-015`);
- cross-place party/ticket/teleport tampering (`M1-004`, `M1-005`, `M1-011`, `M1-012`, `SEC-016`);
- operation replay and duplicate value prevention (`SEC-011`);
- arbitrary instance/path and moved-part proximity attacks (`SEC-014`, `SEC-017`);
- runtime abuse coverage for the newly source-verified door and bunker prompt distance/rate guards; and
- all future horror, hiding, hunter, light-switch, and ending remotes, which do not exist and therefore cannot be marked passed.

## Evidence update rule

Every result change must include the exact command or scenario, build/commit identifier, test universe/place, device where applicable, logs/screenshots/profiler artifact, and an owner/date. A claim based only on source inspection stays **PARTIAL**. A test that requires Studio, a published private server, DataStore, MemoryStore, TeleportService, physical mobile hardware, or moderated assets remains **NOT RUN** or **BLOCKED** until that environment is actually exercised.
