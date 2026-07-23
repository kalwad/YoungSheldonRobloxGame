# Milestone 1 rollback exports

This directory contains both the dated **pre-Milestone-1** rollback set and the
final verified Studio exports for the separate house and lobby roles. The
pre-Milestone set preserves the last verified single-player Cooper house; the
verified sets preserve the final Studio-tested Milestone 1 builds. Live Roblox
cross-place gates remain tracked separately in `../../MILESTONE1_TEST_MATRIX.md`.

## Topology boundary

- Universe: `10480337589`
- Milestone 1 lobby/start place: `100748614383412`
- Milestone 1 reserved house place: `98645411943406`
- House maximum visitors: exactly `4`
- Lobby maximum visitors: at least `4`; `50` is recommended

The pre-Milestone-1 exports came from place `100748614383412` while it was still
the original single-place house. After the split, that ID became the lobby.
Therefore, do **not** import the pre-Milestone house exports into the published
lobby unless performing a full topology rollback to Milestone 0.

## Export inventory

### Pre-Milestone-1 single-place house — 15:52:41 EDT

| File | Scope | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `2026-07-22_15-52-41_EDT_pre-milestone-1-environment.rbxm` | `CooperHouseEnvironment` | 166657 | `bb89e93bca28a9e7b192eaa21003421dfaaf50a12aad1b03a64e0fae4e467877` |
| `2026-07-22_15-52-41_EDT_pre-milestone-1-runtime.rbxm` | Active house runtime/config sources | 358313 | `54b388cef048ac65886fed400f6c9274e820460f03a9139b0e452f3803671673` |
| `2026-07-22_15-52-41_EDT_pre-milestone-1-doors.rbxm` | Front, patio, and detached-garage doors | 22054 | `20b196ab53fa1e0f9aefa20a342122a25e9021698e97c86e28201059fb593b66` |
| `2026-07-22_15-52-41_EDT_pre-milestone-1-player-scripts.rbxm` | House `StarterPlayerScripts` | 104966 | `df572fb6d33e75a18efe663ca60208882365a4a456863ebef91ec382d62bab0d` |

### Verified Milestone 1 house — 16:52:50 EDT

The house verifier passed 530 edit-mode checks and 616 runtime checks before
this set was retained.

| File | Scope | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `2026-07-22_16-52-50_EDT_milestone-1-house-verified-environment.rbxm` | `CooperHouseEnvironment` | 166490 | `0a7cb6854d449f3679150e9a65dd24f99033ee79d22ef4cbb921fb70a4675dfc` |
| `2026-07-22_16-52-50_EDT_milestone-1-house-verified-runtime.rbxm` | House runtime/config sources | 285396 | `e5f9a5f89f1214026abd5d57fe5c0c01f902a75fa935f40b96fa279235d213e0` |
| `2026-07-22_16-52-50_EDT_milestone-1-house-verified-doors.rbxm` | Front, patio, and detached-garage doors | 22167 | `f397a47b18c8f117316580cac87904f51fbf878487451888639d4eff9017a5b0` |
| `2026-07-22_16-52-50_EDT_milestone-1-house-verified-player-scripts.rbxm` | House `StarterPlayerScripts` | 119277 | `7bc9124e007d248aa4186f67a0f49d2d6ca07080e8454508118daa45b790e592` |

### Verified Milestone 1 lobby — 17:36:51 EDT

The lobby verifier passed 181 edit-mode checks and 225 runtime checks. This set
contains the final crash fix: forced `GuiService.SelectedObject` writes during
client initialization were removed, ordinary `TextButton.Selectable` behavior
was retained, and a fresh runtime remained stable while every lobby button flow
was exercised. This exact final lobby source was published as version 308 at
17:37 EDT.

| File | Scope | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `2026-07-22_17-36-51_EDT_milestone-1-lobby-verified-environment.rbxm` | `CooperPartyLobbyEnvironment` | 15242 | `8b7980c7ce0b549b4c24d50a7defd16409fca5083e905eef71e1d4c5dffc72bb` |
| `2026-07-22_17-36-51_EDT_milestone-1-lobby-verified-runtime.rbxm` | Lobby protocol/config/server sources | 25182 | `fbba830672f2a7b30c5016741bb145519b391e1ff4f833b2dec2b2f597443c66` |
| `2026-07-22_17-36-51_EDT_milestone-1-lobby-verified-player-scripts.rbxm` | Lobby `StarterPlayerScripts` | 8244 | `cf7a96e8fab0cf07184e8de42b4415de4000572ffc4ab039d50744c7cc92368e` |

### Ready/Start and 1980s visual closure — 19:20–19:38 EDT

These combined exports contain the lobby environment, active lobby server and
client, and lobby configuration. The first is the immediate rollback taken
before the local closure repair. The second was exported after the clean
Ready→Start runtime, responsive-device captures, and final edit/runtime audits.
Neither export was published to Roblox.

| File | Scope | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `2026-07-22_19-20-37_EDT_pre-launch-repair-lobby.rbxm` | Pre-repair lobby environment + active lobby sources/config | 44146 | `84dba61ee9b8e4913b60ca35438a2de3fc9413a2eb1ddbcc511d08de6457bad8` |
| `2026-07-22_19-38-16_EDT_milestone-1-launch-repair-verified-lobby.rbxm` | Repaired Ready/Start + scoped 1980s lobby/UI | 58895 | `78bceda4afb4af2b4b61bad0936eb23b1b7520f89a5695b0901d275d20b23d7e` |

### Verified Studio lobby-to-house handoff — 20:39:16 EDT

This local-only export adds the production-guarded, in-place Studio house
preview to the repaired lobby. It contains the inert verified house package,
bridge, lobby runtime/client/protocol, and lobby environment. The exact
Create Party → Ready → Start path opened the normal house runtime; 63 edit and
108 runtime audit checks passed, both previously truncated client sources were
replaced, all required house RemoteEvents were present before controllers
started, and movement was confirmed after the ordinary first-play tutorial.
Nothing in this export was published or used to overwrite another place.

| File | Scope | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `2026-07-22_20-39-16_EDT_studio-house-launch-verified.rbxm` | Studio-only house package + bridge + repaired lobby sources/environment | 627701 | `4743727549aada2b2669b03f8d74ae23c42bab10708f3fc34302e05cb0f24a62` |

All original seven verified hashes and both closure hashes above were re-read from the stored files with
SHA-256. The house was published before the final lobby publication; no house
version number or publication timestamp was supplied for this manifest.

The Git source baseline for the pre-Milestone exports is commit `813f93c`
(`feat: complete milestone 0 pre-horror baseline`). Use a detached worktree or a
fresh clone to inspect it; do not overwrite an uncommitted working tree. The
verified Milestone 1 implementation source is commit `e1d4b29`
(`feat: implement milestone 1 lobby and co-op foundation`).

## Narrow house rollback

Use this when the lobby place is healthy but the new house build must be
withdrawn.

1. Stop playtests and take new dated safety exports from both current places.
2. Open a blank local Studio place and import the desired `.rbxm` files there.
   Confirm names, hierarchy, scripts, and doors before touching a published
   place.
3. Restore the inspected house content only to place `98645411943406`.
4. Keep place `100748614383412` as the lobby, but do not allow production
   launches until the destination passes the Milestone 0 regressions.
5. Set the house maximum visitors to `1` while it contains the single-player
   Milestone 0 runtime.
6. Run `verify_milestone0_baseline.luau`, the established gameplay verifiers,
   and a fresh-profile plus migrated-profile smoke test before republishing.

## Full Milestone 0 topology rollback

Use this only if the entire lobby/co-op release must be removed.

1. Complete steps 1–2 above.
2. Restore the inspected exports to place `100748614383412`.
3. Make `100748614383412` the experience start place and set its maximum
   visitors to `1`.
4. Make house place `98645411943406` non-start/private and disable every route
   that can launch it.
5. Restore source from commit `813f93c` in a separate worktree, synchronize only
   the canonical Milestone 0 source map, and never synchronize `legacy/retired`.
6. Run the complete Milestone 0 verifier/playthrough gate before publishing.

## Forward recovery

If only one Milestone 1 source is damaged, restore that source from commit
`e1d4b29` instead of importing an entire model. For model
recovery, import house-verified exports only into place `98645411943406` and
lobby-verified exports only into place `100748614383412`. Never mix the role
sets. The live-only and full-regression rows in
`../../MILESTONE1_TEST_MATRIX.md` must still be completed before treating the
Studio exports as full release certification.

Always preserve the current DataStore and pending-purchase data. Model imports
do not authorize profile resets, free grants, or destructive DataStore work.
