# Cooper Time Machine — Complete Development Roadmap

## Summary

Build the game as a staged production rather than one giant update. Preserve the currently working house, five tasks, automation systems, bunker, and exactly four normal PNG NPCs: George, Mary, Missy, and Georgie. Do not revive the discarded panic/crisis scripts or introduce extra family characters.

The long-term experience becomes:

1. Cozy task and upgrade progression.
2. Hidden horror reveal and escalating survival.
3. Optional bunker tunnel, backrooms house, and dome mysteries.
4. A rebuilt 11-stage science-fiction Time Machine.
5. A black-hole launch into an ultra-realistic Blender-built studio reality.
6. The future apartment and an individual final choice.
7. An unlockable postgame horror/maintenance loop.

## Locked Design Rules

- Support solo or private parties of 1–4 players.
- A separate lobby creates invited parties and launches reserved house servers.
- The host’s house, bunker, purchases, and machine stage control the world.
- Guests retain their own cash, task/horror stats, discoveries, and ending credit, but do not inherit the host’s physical upgrades.
- Tasks, deadlines, encounters, and capture consequences are shared.
- One capture ends the encounter, resets only the failed task, and penalizes every party member:
  - `loss = min(current cash, $25 × (cycle − 1), $500)`
  - The guaranteed story reveal never deducts money.
  - Permanent purchases and completed earlier tasks remain intact.
- The bunker protects only players who reached it; hunters continue pursuing everyone above ground.
- Horror targets moderate fear with no gore.
- Titles, thumbnails, and descriptions can avoid spoilers, but the Roblox maturity questionnaire must accurately disclose the strongest fear content. Roblox explicitly requires accurate answers based on the most extreme content players can encounter. [Roblox Creator Hub](https://create.roblox.com/docs/production/promotion/content-maturity)
- Normal NPC cutouts, catchphrases, dialogue, proportions, and behavior remain untouched outside horror.

## Milestone 0 — Safe Production Foundation

> Scope lock (2026-07-22): the approved Milestone 0 implementation is the
> rollbackable, solo, pre-horror source baseline documented in
> `MILESTONE0_BASELINE.md`. The private staging-place workflow, production-only
> scenario tooling, and broad IP review below remain follow-up production work;
> they are not enabled or silently bundled into this baseline. In particular,
> `StudioScenarioTools` stays `false` until it is separately approved.

- Preserve the current playable build as a rollback place/version and perform all major systems in a private staging place.
- Add disabled-by-default feature flags for lobby, horror, secrets, finale, and postgame.
- Replace verification tied to the abandoned crisis/panic system with checks for the current five-task game.
- Migrate the profile schema without destroying existing cash, robots, bunker, chemistry, boombox, or machine progression.
- Add Studio-only scenario controls for forcing cycles, hunters, captures, survival, machine stages, ending regions, and party states. These controls must never appear in production.
- Complete an intellectual-property and asset-permission review before a wide public release, covering character likenesses, show branding, audio, the future apartment, and third-party logos.

Gate: the current non-horror game must still pass a complete solo/mobile playthrough before horror work begins.

## Milestone 1 — Lobby and Co-op Foundation

- Add a lightweight lobby place within the same Roblox experience.
- Allow creating an invited party, joining friends, readying up, and launching a reserved server. Public matchmaking remains out of scope initially.
- Solo players can launch immediately.
- Transmit party membership and host identity through server-validated teleport data.
- Use one shared five-task scheduler; any party member may complete the active task, and each present member receives the task reward once.
- Only the host may purchase persistent world construction such as machine stages or the bunker.
- If the host disconnects, pause progression for a 60-second reconnection grace period; if they do not return, safely save everyone and return the party to the lobby.
- Add Shift sprint and a mobile sprint button:
  - Walk speed: 16.
  - Sprint speed: 22.
  - Six seconds of stamina with gradual regeneration.
  - Sprint UI appears only while stamina is being used or recovering.

Gate: test solo, two-player, and four-player sessions, including host disconnects, guest rewards, purchases, and mobile controls.

## Milestone 2 — Task Pressure and Horror Skeleton

Replace the incompatible old crisis code with a new server-authoritative horror state machine.

### First-time sequence

- Cycle 1: five safe tasks, no possible horror penalty. A hidden 300-second telemetry timer may run only to evaluate pacing.
- Cycle 2: hidden 240-second deadline per task.
- Cycle 3: hidden 204-second deadline per task.
- If no natural timeout occurs, trigger a story-framed electrical fault during the first task of cycle 4.
- The forced fault is not described as the player’s failure and cannot cost money.
- After the reveal, use visible per-task deadlines:
  - First pressure cycle: 180 seconds.
  - Second: 153 seconds.
  - Third: 126 seconds.
  - Fourth and later: 90 seconds.
- Pause deadlines during loading, cinematics, death recovery, and active horror. Do not pause them merely because a task-related terminal or hacking UI is open.

### Hunter assignment

- Beer failure → George.
- Dishes or trash failure → Mary.
- Lost toy failure → Missy.
- Bank hacking failure → random choice among the existing four, avoiding the previous hunter when possible.
- No Sheldon, Billy, Mandy, Meemaw, or new friendly NPCs.

### First encounter

- Lights snap off immediately.
- Two seconds of near-total darkness and silence.
- A slow drone, vignette, and desaturation build.
- At second 5, show the supplied hunter-specific reveal image briefly.
- At second 8, the hunter takes one unnatural step.
- At second 10, the hunter begins approaching.
- The first hunter moves at speed 10, slower than normal player walking.
- Survival lasts 30 seconds.
- On survival or capture, restore every modified light, NPC, door, prompt, camera, sound, and movement state idempotently.

Gate: blind testers must experience the first reveal without knowing its trigger while still being informed that the test contains moderate-intensity content.

## Milestone 3 — Horror Character Art and Presentation

Yes, the scary PNGs can be created directly with AI-assisted image editing while preserving their identities.

- Use each existing transparent cutout as its own edit target.
- Generate four separate high-fidelity variants, never one combined batch image.
- Preserve face identity, pose, clothes, proportions, framing, and silhouette.
- Change only the horror treatment:
  - Strong desaturation.
  - Pale, cold skin grading.
  - Deeper facial and eye-socket shadows.
  - Faint cold-white glowing eyes.
  - Subtle unnatural expression.
  - No blood, wounds, gore, cards, text, or background.
- Reapply the original alpha silhouette to the edited result so the final deliverable remains a clean transparent PNG with stable edges.
- Save the outputs under new versioned filenames; never overwrite the normal cutouts.
- Present all four for approval before uploading them to Roblox.
- You will provide the four character-specific reveal-flash images separately.
- Maintain an asset manifest mapping each character to:
  - Normal cutout.
  - Scary hunter cutout.
  - Reveal-flash image.
  - Normal dialogue audio.
  - Horror audio.

Add generic accessibility settings for reduced flashing, reduced camera motion, and effect volume without explaining the secret mechanic.

Gate: compare every variant side-by-side with its source at game scale and reject any version that changes identity or introduces a background fringe.

## Milestone 4 — Survival Toolkit and House Pass

- Add deliberate hiding infrastructure:
  - Under Missy’s bed.
  - Under Sheldon’s bed.
  - Under the parents’ bed.
  - Two purpose-built bedroom/hall closets.
  - One carefully tested large-furniture hiding location.
- Hiding prompts appear only during encounters.
- Hidden players become untargetable, but late-game hunters may inspect nearby hiding places.
- Add three shared distractions per encounter using resettable plates, lamps, or similar objects. A distraction sends hunters to its noise location.
- Add proper room light switches connected to the existing room lights.
- A switch stuns hunters in that room for 2.5 seconds with a 10-second per-switch cooldown.
- The first reveal disables advanced tools so it remains simple and easy to survive; hiding, distractions, and stuns become available afterward.
- Unify front, patio, and garage doors behind a server-side door adapter so hunters and robots interact with doors consistently.
- Bunker occupants are hidden from hunter targeting. The hatch seals during horror but never traps a player permanently.
- Do not end an encounter merely because one player reached safety.

Gate: every hunter must path through doors and around furniture without walking through walls, beds, appliances, the truck, robots, or the machine.

## Milestone 5 — Escalation and Automation Integration

### Encounter tiers

- Machine stages 0–4:
  - One hunter.
  - Hunter speed 12.
  - 45-second later encounters.
  - No door opening or hiding-place inspection.
- Stages 5–8:
  - A second hunter may activate halfway through.
  - Speed 15.
  - 60-second survival.
  - Hunters can operate supported doors.
- Stages 9–10:
  - Up to three hunters.
  - Speed 18.
  - 75-second survival.
  - Hunters inspect nearby hiding places.
- Stage 11:
  - Up to all four existing family hunters.
  - Speed 19, still slower than sprinting.
  - Bunker becomes the most reliable refuge.
- Survival bonuses for each present player:
  - Early: $25.
  - Mid: $60.
  - Late: $120.
  - Postgame: $180.

### Robot scheduling

- A robot-owned task becomes a concurrent physical job, and the next task is assigned immediately.
- Reward and task completion occur only when the robot visibly finishes the job.
- Each robot job retains its own deadline.
- Robot animations and deadlines pause during horror and resume afterward.
- Navigation failures caused by the game requeue the task without triggering horror or penalizing players.
- Robots reroute visibly and must never disappear, teleport through the house, or phase through furniture.
- The mobile HUD shows the primary deadline plus compact robot-job status chips without covering interaction prompts.

Gate: complete repeated fully automated cycles with four players and verify that rewards are never duplicated, deadlines remain fair, and robots remain visible.

## Milestone 6 — Optional Mystery Route

- After the bunker is built and the first horror reveal has occurred, quietly unlock a concealed utility panel in a bunker wall.
- No task arrow or explicit tutorial reveals it.
- The panel opens into a physical tunnel leading to a backrooms-style duplicate Cooper house.
- A deeper maintenance exit leads to the optional dome discovery.
- These regions remain in the gameplay place as distant streamed zones; they do not become arbitrary map-edge discoveries.
- Save personal discovery flags for the tunnel, backrooms, and dome.
- Use the areas for foreshadowing: repeated rooms, production markings, impossible geometry, and hints that the normal world is constructed.
- Do not place required progression or major monetary rewards there.

Gate: the regions cannot stream into view early, cannot drop players into a void, and always return them safely to the active house.

## Milestone 7 — Rebuild the Time Machine

Replace all random stage props while preserving existing `machineStage` progress and costs.

The eleven delivered assemblies become:

1. Reinforced foundation and mounting rails.
2. Power distribution base.
3. Central containment chamber.
4. Left temporal coil.
5. Right temporal coil.
6. Clock-centered navigation console.
7. Lower portal ring.
8. Upper portal ring and field emitters.
9. Stabilizer arms.
10. Integrated conduits, lenses, and cooling system.
11. Activation core, controls, and safety lever.

- Every delivery crate visibly contains the correct upcoming component.
- Installed components align into one coherent machine rather than remaining separate decorations.
- The completed machine has an unmistakable clock/navigation centerpiece and intentional science-fiction silhouette.
- Late-game horror makes it hum, frost nearby surfaces, pulse, and react without activating early.
- Stage 11 exposes a manual activation prompt.
- In co-op, the host initiates a ready check; the synchronized countdown starts only after everyone confirms.

Gate: migrate and visually inspect saves at all 11 stages, not merely stage 0 and stage 11.

## Milestone 8 — Black-Hole Finale and Blender World

### Launch cinematic

- Lock task progression and safely suspend horror.
- Power the coils in sequence, distort audio, bend the camera/FOV, and form a black-hole portal.
- Create the impression that the house, avatars, and sky are stretching into it using client-side environment echoes, trails, portal meshes, camera animation, lighting, and post-processing—not destructive movement of the real house.
- Show each player’s avatar warping through afterimages.
- Provide a reduced-motion version.
- Restore controls through one shared cleanup path on completion, interruption, death, or disconnect.

### Ultra-realistic world pipeline

- Graybox the complete 2–5 minute route in Roblox first.
- Rebuild the approved route as modular Blender environment kits.
- Use optimized PBR materials, UV atlases, low-complexity collision hulls, mesh streaming, and automatic render fidelity.
- Target stable 30 FPS on supported mobile devices; desktop receives richer lighting and detail tiers.
- Keep the experience uncanny rather than enormous:
  - Ultra-realistic soundstage and backlot.
  - Scripted synthetic people looping, staring, or glitching.
  - Camera rigs and production equipment.
  - A television displaying the Cooper simulation.
  - “Medford Set” evidence and discarded scripts.
- No tasks, timers, robots, upgrade prompts, or normal HUD appear here.
- Preload the destination during the black-hole sequence and extend the transition safely if streaming is incomplete.

### Ending flow

1. Black-hole launch.
2. Ultra-realistic studio reality.
3. Future apartment payoff.
4. Final choice presented individually to each player:
   - Stay in reality → mark ending complete, show credits, return that player to the lobby.
   - Return to the simulation → return to the Cooper house and unlock postgame.
5. Guests receive story/postgame credit, but their personal house machine remains at its existing stage.
6. After completion, the machine offers:
   - Direct destination travel.
   - Separate cinematic replay.
   - No repeat ending rewards.

Gate: test the full sequence under slow streaming, low graphics, reduced motion, mobile controls, player separation, and mixed party ending choices.

## Milestone 9 — Postgame Horror and Retention

- Returning to the simulation changes the loop to horror with task/machine maintenance.
- Family hunts remain.
- A new non-family anomaly has a 20% encounter chance with no back-to-back appearances.
- The anomaly must receive its own design/art/audio approval milestone before implementation; do not improvise its appearance.
- Add persisted statistics:
  - Encounters survived and caught.
  - Current and longest survival streak.
  - Fastest complete task cycle.
  - Tunnel/dome discoveries.
  - Ending choices.
- Add cosmetics, daily challenges, and global boards only after the postgame loop is stable.
- Keep seasonal horror variants as later content rather than mixing them into the first release.

## Additional Bunker Tasks

Additional bunker tasks remain intentionally deferred because their gameplay has not been selected yet.

After the first horror vertical slice is validated:

- Run a focused design pass for two or three bunker activities tied to chemistry, machine research, or postgame maintenance.
- Prototype one activity before adding its economy or automation upgrade.
- Do not ship placeholder “press button and wait” bunker tasks merely to fill space.

## Technical Interfaces

- Extend configuration with task-pressure timings, encounter tiers, rewards, hunter mappings, party settings, accessibility values, and feature flags.
- Add profile fields for cycle position, first reveal, horror statistics, discovery flags, ending state, and postgame unlock; migrate existing profiles forward.
- Keep `totalTasks` as a lifetime statistic instead of overloading it as cycle state.
- Use one server-authoritative session state for party task progress, concurrent robot jobs, horror phase, active hunters, and ending phase.
- Expose controlled NPC operations for snapshot, roam pause, hunter assignment, scary-art swap, path/search, dance interruption, and exact restoration.
- Add registries for room lights, switches, hiding anchors, distractions, supported doors, bunker boundaries, and streamed destinations.
- Reject client requests that attempt to award cash, choose hunters, complete tasks, purchase host upgrades, or force story state.

## Release and Test Matrix

- Profile migration from every existing progression combination.
- Solo, two-player, and four-player sessions.
- Every task as the natural first-horror trigger.
- Guaranteed cycle-4 reveal.
- Every hunter’s normal/scary/reveal asset mapping.
- Capture, survival, split-party bunker use, host loss, rejoin, death, and reset.
- Manual and fully automated task cycles.
- Desktop, tablet, and phone landscape UI.
- Keyboard, touch, reduced-motion, and reduced-flash controls.
- Door, furniture, robot, hunter, truck, bunker, and machine collision checks.
- Server/client error log audit after every milestone.
- Mobile MicroProfiler and streaming checks for the Blender finale.
- Blind surprise testing followed by explicit retention, clarity, fear, and accessibility feedback.
- Update the maturity questionnaire before publishing horror because Roblox requires it whenever new content changes questionnaire answers. [Roblox Creator Hub](https://create.roblox.com/docs/production/promotion/content-maturity)

No milestone advances until its gate passes without progression loss, stuck movement, void spawning, incorrect NPC art, duplicated money, or restoration errors.
