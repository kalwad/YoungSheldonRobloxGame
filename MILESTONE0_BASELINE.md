# Milestone 0 baseline manifest

Captured before pre-horror changes on **2026-07-22 13:02:40 EDT**.

## Place identity

- Place ID: `100748614383412`
- Universe ID: `10480337589`
- Place name: `Help Young Sheldon Build a TIME MACHINE!!`
- `Workspace.StreamingEnabled`: `true`
- Pre-migration profile schema: `10`
- Pre-milestone Studio player capacity: `60` (not safe for release until
  Milestone 1; the release configuration must temporarily be set to `1`)
- Milestone 0 Creator Dashboard maximum visitor count: `1` (saved and
  re-read from the place Access page on 2026-07-22)

Studio's already-open edit DataModel continues to report its cached
`Players.MaxPlayers` value of `60`; that property is read-only. The release
setting above is the authoritative published-server cap. The frozen local
contract and runtime state both expose `ReleasePlayerCap = 1` so a later
multiplayer change cannot happen accidentally or silently.

## Environment markers

- `BuildVersion`: `3.0-expanded-early-series-set`
- `RelocationStateRepairVersion`: `2026-07-13.1`
- `SimpleGameplayCleanupVersion`: `2026-07-13.simple.1`
- Interior reference: soundstage set with formal parlor, dining room, kitchen,
  den, and the early shared twins bedroom
- Exterior reference: 1949 Valley Village ranch used as fictional Medford,
  Texas home

## Pre-change rollback exports

- `backups/milestone-0/2026-07-22_13-02-40_EDT_pre-horror_environment.rbxm`
  - SHA-256: `97a9e8ad99699da361a534e92712710c718732c0aafa5bae5ebbddffc66685a3`
- `backups/milestone-0/2026-07-22_13-02-40_EDT_pre-horror_runtime.rbxm`
  - SHA-256: `e59956d35988a62ecfc31675b83e840c2c6814676dee6075ddbf6ec1cb2e68c9`
  - Contains the 25 active runtime/config scripts listed below.
- `backups/milestone-0/2026-07-22_13-14-26_EDT_pre-horror_doors.rbxm`
  - SHA-256: `0c268ba72aac21ac8318d6f4392cbd404dbae168ebdc4b7cd49dff84fc86476f`
  - Contains the front, den-patio, and detached-garage interactive door models.
- `backups/milestone-0/2026-07-22_13-14-26_EDT_pre-horror_player-scripts.rbxm`
  - SHA-256: `0662a300957ed8e75a19bd920620a71914f47999589e39827b3aab4706a7402d`
  - Contains all 11 active `StarterPlayerScripts` sources.

## Verified post-change rollback exports

Captured after source synchronization and the final desktop/mobile/runtime pass
on **2026-07-22 14:07:51 EDT**. The verified environment advertises
`RelocationStateRepairVersion = 2026-07-22.milestone0`.

- `backups/milestone-0/2026-07-22_14-07-51_EDT_milestone-0-verified_environment.rbxm`
  - SHA-256: `109a94f085935fc99f133d0ba37f7705d0a866a0d1f2b456df7a996b84f588f9`
- `backups/milestone-0/2026-07-22_14-07-51_EDT_milestone-0-verified_runtime.rbxm`
  - SHA-256: `9c8ae372c5948faa235aee5ca0c427424609bf66bd5b987943591a43559d9316`
  - Contains the 25 synchronized runtime/config sources below.
- `backups/milestone-0/2026-07-22_14-07-51_EDT_milestone-0-verified_doors.rbxm`
  - SHA-256: `8ca68452d4e51aa5a69c2f8be6703cbace56284d50ff4ea2d022fa518f0b0df6`
- `backups/milestone-0/2026-07-22_14-07-51_EDT_milestone-0-verified_player-scripts.rbxm`
  - SHA-256: `f20094b414791f38aac4ba7b37494bb3948e59b4d0306b711b9d795417bb66bc`

## Canonical active source map

| Studio instance | Local source |
| --- | --- |
| `ReplicatedStorage.CooperGame.Config` | `CooperFamilyTaskConfig.module.luau` |
| `ServerScriptService.CooperBunkerConstruction` | `CooperBunkerConstruction.server.luau` |
| `ServerScriptService.CooperBunker` | `CooperBunker.server.luau` |
| `ServerScriptService.CooperFamilyDialogue` | `CooperFamilyDialogue.server.luau` |
| `ServerScriptService.CooperFamilyNPCs` | `CooperCharacters.server.luau` |
| `ServerScriptService.CooperGame` | `CooperFamilyTaskGame.server.luau` |
| `ServerScriptService.CooperHouseTVAnimator` | `tv_animator.server.luau` |
| `ServerScriptService.CooperInteractions` | `CooperInteractions.server.luau` |
| `ServerScriptService.CooperSpawnSafety` | `CooperSpawnSafety.server.luau` |
| `ServerScriptService.CooperTaskWorld` | `CooperFamilyTaskWorld.server.luau` |
| `ServerScriptService.CooperYardRideables` | `CooperYardRideables.server.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperBackgroundMusic` | `CooperBackgroundMusic.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperBunkerClient` | `CooperBunker.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperFamilyDialogue` | `CooperFamilyDialogue.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperGame` | `CooperFamilyTaskGame.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperGeorgeProximityVoice` | `CooperGeorgeProximityVoice.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperGeorgieProximityVoice` | `CooperGeorgieProximityVoice.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperHallCameraController` | `CooperHallCameraController.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperInteractions` | `CooperInteractions.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperMaryProximityVoice` | `CooperMaryProximityVoice.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperMissyProximityVoice` | `CooperMissyProximityVoice.client.luau` |
| `StarterPlayer.StarterPlayerScripts.CooperYardRideables` | `CooperYardRideables.client.luau` |
| `...InteractiveDenPatioDoor.PatioDoorController` | `patio_door_controller.server.luau` |
| `...InteractiveFrontDoor.FrontDoorController` | `front_door_controller.server.luau` |
| `...InteractiveSectionalGarageDoor.GeorgieGarageDoorController` | `georgie_garage_door_controller.server.luau` |

The similarly named retired `CooperGame`, `CooperCrisis`, and
`CooperProgression` sources are **not** active and must never be synchronized
over the instances above.

Cryptographic hashes for every canonical local mirror are recorded in
`MILESTONE0_CANONICAL_SOURCES.sha256`. The pre-change Git baseline is commit
`8c16e85`; the verified state is the later commit containing this manifest and
`MILESTONE0_VERIFICATION.md`.

## Restoration procedure

1. Stop every playtest and make a new safety export of the current place.
2. Open a blank local Studio place, import the desired dated `.rbxm`, and verify
   its hierarchy before touching the published place.
3. Restore individual scripts from the canonical source map whenever possible.
4. Restore the environment export only when object-level recovery is required.
5. Run `verify_milestone0_baseline.luau` and all existing verifiers before
   publishing the restored build.
6. Confirm the release player capacity is `1` until Milestone 1 is complete.

The Creator Dashboard version-history API could not be recorded automatically
because this environment has no Roblox Open Cloud API key; the local exports and
Git commits are therefore the programmatically verified rollback artifacts.
