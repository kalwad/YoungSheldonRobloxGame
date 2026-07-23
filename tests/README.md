# Deterministic contract tests

This directory is a local-only test foundation for the Cooper Time Machine roadmap. It does not install anything into Roblox Studio, publish a place, change a feature flag, or modify production scripts.

The first batch exercises the contracts that later multiplayer and horror code must use:

- monotonic time and manually controlled deadlines;
- reproducible random choices;
- explicit, human-reviewed historical Milestone 0 schema-10-to-11 migration fixtures and idempotency;
- an explicit schema-11-to-12 fixture that uses the real production operation-journal sanitizer;
- immutable party eligibility membership with reconnect grace handling;
- server-issued, at-most-once value operations;
- locked pre-reveal and post-reveal deadline/penalty rules;
- reason-counted overlapping pauses; and
- approved hunter mappings that can never invent an NPC.

Run from the repository root:

```sh
luau tests/run.luau
```

All tests are plain Luau CLI modules. They deliberately avoid Roblox services, wall-clock sleeps, DataStores, and Studio state so failures are fast and reproducible. These are contract fixtures, not parallel production implementations; Milestone 2 runtime work must consume equivalent rules through production-owned modules when that milestone's prerequisites are closed.

The schema-10-to-11 fixtures preserve the accepted Milestone 0 migration boundary. They are not the final Milestone 1 profile target. The schema-11-to-12 suite separately proves that every canonical schema-11 field survives and that the actual production transaction-journal sanitizer supplies the bounded schema-12 journal. Roblox DataStore retry/failure tests remain environment-dependent closure work.
