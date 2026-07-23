# Profile Migration Fixtures

Status date: 2026-07-22  
Current production target schema: `12`  
Historical Milestone 0 transition: schema `10` → `11`  
Current Milestone 1 transition: schema `11` → `12`

## Purpose and scope

The migration fixtures are explicit, human-reviewed input/output pairs for both the historical Milestone 0 schema-10-to-schema-11 boundary and the current schema-11-to-schema-12 operation-journal boundary.

The historical fixtures live in [tests/support/ProfileMigrationFixtures.luau](tests/support/ProfileMigrationFixtures.luau) and are executed by [tests/specs/ProfileMigration.spec.luau](tests/specs/ProfileMigration.spec.luau). The current fixture lives in [tests/support/ProfileSchema12Fixtures.luau](tests/support/ProfileSchema12Fixtures.luau) and is executed by [tests/specs/ProfileSchema12Migration.spec.luau](tests/specs/ProfileSchema12Migration.spec.luau).

The CLI test uses [tests/support/ProfileMigrationOracle.luau](tests/support/ProfileMigrationOracle.luau), a test-only deterministic oracle. Production still owns its sanitizer in `CooperFamilyTaskGame.server.luau`. The oracle is intentionally not imported by production, and the expected fixture outputs are not generated from production code at test time. This makes a production policy change visible as a reviewed fixture change instead of silently teaching the test to accept itself.

The schema-10-to-11 fixtures remain historical and must not be relabeled as the current target. Schema 12 adds `operationJournal = { version = 1, pending = {}, committed = {} }`. The schema-11-to-12 CLI adapter preserves the reviewed profile shell while requiring the actual production [CooperTransactionLedger.module.luau](CooperTransactionLedger.module.luau) for journal sanitization. This directly tests the production journal bounds and deduplication policy without importing Roblox services into the CLI.

## Historical schema-10-to-11 fixture inventory

| Fixture | Input emphasis | Required schema-11 result | Covered preservation risk |
|---|---|---|---|
| `schema10_rich_valid_progress` | Valid cash, Stage 7 machine, pending Stage 8 delivery, task count 17, boombox/autoplay, installed robots, bank success, bunker, chemistry, and candy progress | All valid entitlements and progression retained; cycle derived as index 4/task 3; new horror/discovery/ending fields safely defaulted | Existing paid/progression value must not disappear during M0 migration |
| `schema10_impossible_partial_states_repaired_without_entitlement_loss` | Stage 11 profile with contradictory partial states and an unknown robot | Purchased/placed dependencies repaired upward, invalid pending robot cleared, unknown robot discarded, active candy delivery wins over a ready batch, valid token retained | Recovery must converge to a playable state without stripping earned entitlements |
| `schema10_malformed_values_are_bounded` | Negative, infinite, string, oversized, and obsolete panic values | Numeric values bounded, strict booleans enforced, only approved robot retained, obsolete panic field omitted, future features remain inert | Malformed or retired fields must not reactivate crisis/horror or create free value |

An additional deterministic test covers an active candy state with an invalid token. A token factory is injected, the repaired token is reviewed, and a second migration is a no-op.

## Current schema-11-to-12 fixture inventory

| Fixture/case | Input emphasis | Required schema-12 result | Covered preservation risk |
|---|---|---|---|
| `schema11_complete_progress_adds_empty_operation_journal` | All 34 canonical schema-11 fields populated, including cash, Stage 9/pending Stage 10 machine progress, cycle/reveal/stat fields, all robots, boombox, bunker, chemistry, candy delivery, discoveries, and ending/postgame | Entire explicit profile equals the reviewed schema-12 output; every old field is unchanged; an empty journal v1 is added | Adding exactly-once persistence must not erase any existing entitlement or progress |
| Missing journal | Canonical schema-11 profile has no `operationJournal` | `{ version = 1, pending = {}, committed = {} }` | Legacy profiles enter schema 12 without creating or replaying value operations |
| Malformed and duplicate journal | Wrong journal version; invalid IDs/states/types; duplicate committed/pending IDs; cross-list duplicate; infinite/out-of-range values | Version canonicalized to 1; malformed records dropped; first valid committed identity wins; cross-list replay dropped; numeric/result fields bounded | Corrupt or attacker-shaped saves cannot create duplicate credit or poison persistence |
| Journal capacity | 260 committed and 36 pending valid records | Newest 256 committed and newest 32 pending retained | Profile payload has deterministic bounded history |
| Result capacity | 20 valid result keys | Exactly 16 retained and stable after another sanitize | A record cannot expand the save payload without bound |
| Current-to-current | Complete schema-12 result and sanitized journals run again | Byte-structure-equivalent table values | Normalization is idempotent and does not drift |

## Assertions currently automated

- every fixture declares schema 10 as input and schema 11 as expected output;
- the migrated table equals the entire explicit expected table;
- every fixture is idempotent on a second run;
- the rich fixture checks every declared value-preservation path individually;
- cycle position is derived from the existing five-task `totalTasks` history;
- invalid retired/unknown fields do not survive into the schema-11 result; and
- token repair is deterministic when a factory is required;
- all 34 canonical schema-11 profile fields are individually preserved in schema 12;
- the schema-12 result equals a full explicit human-reviewed output;
- a missing journal gets the empty production default;
- the test requires production ledger version 1, pending capacity 32, and committed capacity 256;
- the actual production sanitizer rejects malformed and duplicate journal records;
- committed, pending, and result payload bounds are exact; and
- every schema-12 journal case is idempotent.

## Traceability and limits

| Test-plan requirement | Current result | Evidence / limitation |
|---|---|---|
| `M0-003` load each legacy fixture and preserve value | **PARTIAL PASS** | Three explicit schema-10 fixtures pass locally. The test does not yet load fixtures through Roblox DataStore/ProfileService integration, and it does not represent every historical schema. |
| `M0-004` run every migration twice | **PASS for represented fixtures** | All historical fixtures, the current schema-12 profile, and journal sanitizer cases are idempotent in the CLI harness. |
| `M0-005` fail before migration commit | **NOT RUN** | Requires a persistence adapter/fault sequence and isolated test DataStore. |
| `M0-006` duplicate save callback | **NOT RUN** | Production journal sanitization/deduplication passes locally, but a duplicated Roblox save callback has not been exercised. |
| `M0-007` obsolete panic/crisis fields remain retired | **PARTIAL PASS** | The malformed fixture proves `obsoletePanicLevel` is omitted by the test oracle. Studio/runtime object absence is covered separately by baseline verifiers, not by this fixture. |
| `MIG-001` every supported old schema migrates | **PARTIAL** | Explicit 10→11 and 11→12 boundaries exist. The repository still lacks fixtures for every earlier schema and a composed persistence load for each supported historical version. |
| `MIG-002` current to current | **PASS locally** | A complete schema-12 profile and every journal sanitizer case are idempotent. |
| `MIG-005` missing fields | **PASS for operation journal** | Missing journal becomes the exact empty v1 default without changing the 34 schema-11 fields. Broader missing-field matrix remains historical/partial. |
| `MIG-006` wrong field types | **PARTIAL PASS** | Production ledger sanitizer drops malformed journal records and bounds values. A complete wrong-type matrix for every profile field remains. |
| `MIG-007` unknown fields | **PARTIAL PASS** | Unknown/invalid journal and retired historical fields are discarded by documented tests; full production diagnostic behavior remains untested. |
| `MIG-008` cash bounds | **PASS in historical fixture only** | Negative historical cash clamps to zero; Roblox persistence integration remains unrun. |
| `MIG-009` machine stages 0–11 | **PARTIAL** | Stages 7, 9, and 11 are represented; the full parameterized range is not yet present. |
| `MIG-011` duplicate operation records | **PASS locally** | Actual production sanitizer deduplicates within and across journal lists and remains idempotent. |
| `MIG-015` payload near size limit | **PARTIAL** | Per-journal capacities pass exactly, but serialized whole-profile size has not been measured near the DataStore limit. |
| `MIG-016` 100 load/save cycles | **NOT RUN** | Local double-sanitize is stable; the required 100 persistence cycles are not a substitute for that assertion. |

These local results do not authorize a live DataStore migration. A release candidate still requires an isolated test universe/namespace, fail-before-save, fail-then-succeed, stale-response, duplicate-callback, two-server session-conflict, shutdown-reconciliation, throttle, whole-payload-size, and 100-cycle tests. The Roblox-dependent production profile sanitizer must also be exercised end to end; only its journal module is directly executable in the CLI.

## Running the fixtures

From the repository root:

```sh
luau tests/run.luau
```

The migration cases are part of the same deterministic suite as the fake clock, random source, eligibility snapshot, operation ledger, deadlines, reason-counted pauses, and hunter registry.
