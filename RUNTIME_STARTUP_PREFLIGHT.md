# Runtime Startup Preflight

## Why this gate exists

The July 22 Studio run exposed a compiler/runtime failure that the ordinary
local command did not detect:

```text
CompileError: Out of local registers ... exceeded limit 200
```

`CooperGame` and `CooperBunker` did not execute, so their runtime state and
server events were absent. `CooperTaskWorld` then reported missing core events.
Those TaskWorld messages were downstream symptoms, not proof that TaskWorld was
the original fault.

The Luau register allocator is sensitive to optimization and debug settings.
`luau-compile` defaults to `-O1 -g1`, which passed the affected sources even
when Studio rejected them. Syntax/default compilation is therefore necessary
but **not sufficient** evidence that a Roblox Script can start.

## Gate A — compiler register matrix

Run from the repository root before any Studio synchronization:

```sh
bash verify_runtime_register_budget.sh
```

The verifier compiles the three core server sources under every supported
combination of `-O0/-O1/-O2` and `-g0/-g1/-g2` (27 checks total). These three
rows explain the historically important profiles:

| Profile | Purpose |
| --- | --- |
| `-O1 -g1` | Ordinary local baseline; retained to expose the historical false pass |
| `-O0 -g0` | Unoptimized register-pressure guard |
| `-O1 -g2` | Debug-information register-pressure guard that reproduced Studio failure |

Every matrix row must pass. Any compiler error, especially `Out of local registers`,
blocks Studio handoff, playtesting, publication, and downstream feature
verification. Do not weaken the matrix or treat the `-O1 -g1` row as sufficient.
The repair belongs in the failing source architecture—reduce simultaneously
live top-level locals, split cohesive subsystems into modules, or narrow lexical
lifetimes—rather than hiding the diagnostic.

The script accepts an alternate compiler path through `LUAU_COMPILE`:

```sh
LUAU_COMPILE=/absolute/path/to/luau-compile \
  bash verify_runtime_register_budget.sh
```

## Gate B — fresh Studio runtime readiness

Only after Gate A passes:

1. Synchronize into a backed-up, unpublished Studio test copy.
2. start a **fresh** Play session;
3. select the **Server** Command Bar;
4. run the contents of `verify_runtime_startup_readiness.luau`.

The verifier waits at most 45 seconds and then requires fresh runtime evidence:

- enabled `CooperGame`, `CooperBunker`, and `CooperTaskWorld` server Scripts;
- `CooperGame.State` advertising `FoundationContract = PartyV1` and a schema;
- all four core client RemoteEvents;
- the complete typed `CooperGameServerEvents` authority surface;
- `CooperTaskWorld` end-of-startup readiness attributes;
- `CooperBunker` runtime controller version;
- all three end-of-startup Output markers; and
- no register-exhaustion or missing-core-event fatal diagnostics in LogService
  history.

An enabled Script object or an edit-time folder is not startup proof. The
end-of-startup markers distinguish a fresh successful execution from stale
instances saved in the place.

If `CooperGameServerEvents` is absent, diagnose `CooperGame` first.
`CooperTaskWorld` deliberately depends on those bindables and can only become
ready after the core authority exists.

## Required evidence

Record both outputs with the candidate commit:

- complete `verify_runtime_register_budget.sh` PASS output;
- fresh Play-session `RuntimeStartupReadiness` PASS output;
- Studio Output showing no core startup error or warning.

CLI-only evidence cannot close this gate. This preflight does not authorize
publishing, overwriting a place, enabling horror, or skipping the existing
multi-client, DataStore, MemoryStore, mobile, and regression gates.
