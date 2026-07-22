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
| `StarterPlayerScripts.CooperBackgroundMusic` | `CooperBackgroundMusic.client.luau` |
| `StarterPlayerScripts.CooperBunkerClient` | `CooperBunker.client.luau` |
| `StarterPlayerScripts.CooperFamilyDialogue` | `CooperFamilyDialogue.client.luau` |
| `StarterPlayerScripts.CooperGame` | `CooperFamilyTaskGame.client.luau` |
| `StarterPlayerScripts.CooperGeorgeProximityVoice` | `CooperGeorgeProximityVoice.client.luau` |
| `StarterPlayerScripts.CooperGeorgieProximityVoice` | `CooperGeorgieProximityVoice.client.luau` |
| `StarterPlayerScripts.CooperHallCameraController` | `CooperHallCameraController.client.luau` |
| `StarterPlayerScripts.CooperInteractions` | `CooperInteractions.client.luau` |
| `StarterPlayerScripts.CooperMaryProximityVoice` | `CooperMaryProximityVoice.client.luau` |
| `StarterPlayerScripts.CooperMissyProximityVoice` | `CooperMissyProximityVoice.client.luau` |
| `StarterPlayerScripts.CooperYardRideables` | `CooperYardRideables.client.luau` |
| `...InteractiveDenPatioDoor.PatioDoorController` | `patio_door_controller.server.luau` |
| `...InteractiveFrontDoor.FrontDoorController` | `front_door_controller.server.luau` |
| `...InteractiveSectionalGarageDoor.GeorgieGarageDoorController` | `georgie_garage_door_controller.server.luau` |

The similarly named retired `CooperGame`, `CooperCrisis`, and
`CooperProgression` sources are **not** active and must never be synchronized
over the instances above.

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
