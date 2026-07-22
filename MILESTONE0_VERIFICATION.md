# Milestone 0 verification report

Verified on **2026-07-22 EDT** against place `100748614383412`, universe
`10480337589`.

## Result

Milestone 0 is ready to be used as the rollbackable pre-horror baseline.

- Profile schema is 11 and retains `CooperFamilyTasks_v2`.
- `Lobby`, `Horror`, `SecretExploration`, `TimeMachineFinale`, `Postgame`, and
  `StudioScenarioTools` are all frozen to `false` and advertise matching false
  runtime attributes.
- The release contract is one player. Creator Dashboard Maximum Visitor Count
  was saved as 1 and read back; the already-open Studio edit model retains its
  old read-only `Players.MaxPlayers = 60` cache.
- The active roster is exactly the four approved PNG cutouts: George, Mary,
  Missy, and Georgie.
- No panic, crisis, progression, old finale, staging, or unlock-all runtime
  object is installed. The last player-visible `PANIC LEVEL` TV joke was changed
  to a neutral household bulletin; the TV animation itself is unchanged.
- Historical installers and generic-game sources are isolated under
  `legacy/retired/` with a do-not-install warning.

## Automated checks

- All 71 local `.luau` files compile with `luau-compile`.
- `git diff --check` passes.
- `verify_milestone0_baseline.luau`:
  - 637 checks pass in Studio edit mode.
  - 599 checks pass in runtime mode.
  - Confirms 25 exact canonical Studio sources, five ordered tasks, eleven
    machine stages, four approved NPCs, six disabled flags, solo release
    contract, normal toy guidance, terminal Credits accessibility, and absence
    of retired runtime systems.
  - Executes the production profile sanitizer against a schema-10 fixture and
    verifies allowance, machine progress, paid parts, boombox/autoplay,
    all five robot entitlements, bank progress, bunker, chemistry, ready candy,
    active buyer delivery, and durable tokens survive migration.
  - Runs a second sanitizer pass as an in-memory leave/rejoin round trip for
    pending machine, boombox, bunker, automation, chemistry, ready-candy, and
    buyer-delivery states.
- Runtime regression suites pass:
  - Foundation: five tasks and eleven paid machine stages.
  - Boombox: 2,436 checks.
  - Task automation and robot delivery: 2,157 checks.
  - Candy buyer delivery: 160 checks.
  - Medford Bank: 1,192 checks.
  - Bunker unlock/construction: 2,068 checks.
  - Bunker chemistry: 797 checks.
  - Four-character PNG/catchphrase/dialogue contract.
  - Task world: 13 stations, seven hidden locations, truck route, and machine.
  - Simple-gameplay rollback contract.
- Edit-mode environment suites pass:
  - Complete installation: 14 prompts, 54 roof descendants, 33 garage-living
    descendants, and six garage panels.
  - Spatial integrity: all five tasks, 13 stations, seven hidden spots, swing,
    garage panels, and bounded truck route.
  - Bunker integrity: 1,281 checks, including 236 anchored parts, 38 shell
    parts, and 13 lights.

## Interactive smoke tests

- Fresh-session onboarding opened correctly and released controls after
  `Start Building`.
- Character movement worked before opening the terminal.
- The terminal opened on its main menu, Credits was reachable after scrolling,
  all six attribution cards rendered, and the first card opened at scroll
  position zero instead of being clipped.
- Back returned to the terminal main menu; the visible Close button closed the
  computer and character movement worked immediately afterward.
- Responsive captures passed on iPhone 13 portrait, iPhone 13 landscape, iPad
  10 landscape, and Average Laptop presets. Buttons remained visible, readable,
  scrollable, and inside their safe areas.
- Final startup produced no project warning or error. Studio reported only the
  external Roblox Studio MCP bridge version mismatch (plugin 2.22.3 versus
  bridge 2.22.0), which is not game code.

## Persistence safety note

Production DataStore keys were deliberately not written during this baseline
audit, and `EnableStudioDataStore` remains off. Persistence coverage therefore
uses the exact production sanitizer, a double-pass leave/rejoin simulation, and
the delivery/automation source-contract suites. A published-server rejoin is a
recommended human playtest before public release, but it is not required to
restore or validate this source baseline.

## Rollback artifacts

- Pre-change Git baseline: `8c16e85`.
- Pre-change and verified `.rbxm` exports: `backups/milestone-0/`.
- Export hashes and restoration procedure: `MILESTONE0_BASELINE.md`.
- Exact local source hashes: `MILESTONE0_CANONICAL_SOURCES.sha256`.
