# Deterministic contract tests

This directory is a local-only test foundation for the Cooper Time Machine roadmap. It does not install anything into Roblox Studio, publish a place, change a feature flag, or modify production scripts.

The first batch exercises the contracts that later multiplayer and horror code must use:

- monotonic time and manually controlled deadlines;
- reproducible random choices;
- explicit, human-reviewed historical Milestone 0 schema-10-to-11 migration fixtures and idempotency;
- an explicit schema-11-to-12 fixture that uses the real production operation-journal sanitizer;
- immutable party eligibility membership with reconnect grace handling;
- server-issued, at-most-once value operations;
- stable candy, indexed boombox-payout, exact completed-playback boombox
  settlement, and paid-install operation identities;
- revisioned Ready state, action-specific Ready/Start throttles, launch
  idempotency, and deterministic synchronous/asynchronous
  `TeleportInitFailed` reservation/teleport retries;
- user-bound, one-use admission tickets with stale membership, exact-expiry, and retry handling;
- one reason-counted 60-second host grace path with exact reconnect boundaries;
- the locked server-authoritative sprint/stamina constants and recovery rules;
- a two-client same-task contention scenario with fail-before-write and ambiguous fail-after-write reconciliation;
- locked pre-reveal and post-reveal deadline/penalty rules;
- reason-counted overlapping pauses; and
- approved hunter mappings that can never invent an NPC.

Run from the repository root:

```sh
luau tests/run.luau
```

The current suite contains 130 named deterministic checks. For the complete
repeatable Milestone 1 local gate, run:

```sh
bash tools/verify_milestone1_local.sh
```

That wrapper compiles every tracked/untracked candidate Luau source, analyzes
and runs this suite, exercises all 27 core compiler-register profiles, rejects
whitespace damage, locks schema/cap/place/feature contracts, checks the named
value-operation closure, scans active clients for forbidden authority, and
confirms retired/future runtime surfaces remain disabled.

All tests are plain Luau CLI modules. They deliberately avoid Roblox services, wall-clock sleeps, DataStores, and Studio state so failures are fast and reproducible. The fake profile store, session directory, teleport adapter, clock, and failure sequences exercise bounded contracts and failure ordering; they do **not** claim to prove live MemoryStore, TeleportService, DataStore, reserved-server, device, or published-build behavior. Those rows remain published/private or hardware closure work.

These are contract fixtures, not parallel production implementations. A passing local run is necessary evidence for deterministic Milestone 1 rules, but it cannot close the published E2E, multi-client Studio, visual, accessibility, or physical-device gates. Runtime services must consume equivalent production-owned rules, and their integration must be checked separately.

The schema-10-to-11 fixtures preserve the accepted Milestone 0 migration boundary. They are not the final Milestone 1 profile target. The schema-11-to-12 suite separately proves that every canonical schema-11 field survives and that the actual production transaction-journal sanitizer supplies the bounded schema-12 journal. Roblox DataStore retry/failure tests remain environment-dependent closure work.
