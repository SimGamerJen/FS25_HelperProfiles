# HelperProfiles 2.2.0.0-alpha1 — World Workers test notes

This development branch introduces the first standalone world-worker prototype. It deliberately does **not** create an AI job or a fake networked player.

## Scope

- Persist a world placement per permanent HelperProfiles A–T identity.
- Spawn the worker with GIANTS `HumanGraphicsComponent`.
- Use the worker's bound AvatarSwitcher appearance where available; otherwise clone the helper's native `PlayerStyle`.
- Keep the worker in a static NPC/idle animation state.
- Restore placed workers when the save reloads.
- Temporarily despawn a placed worker while that same helper is active on an AI job, then restore the world representation when the AI job ends. The saved world location is not changed.
- Keep world placement independent from the ON/OFF hiring roster state.

No pathfinding, interactions, schedules, dialogue or GUI controls are included in alpha1.

## Test command

Open the developer console and use:

```text
hpWorld help
hpWorld status
hpWorld place [slot]
hpWorld move [slot]
hpWorld remove [slot]
hpWorld refresh [slot]
```

`slot` accepts A–T, `helper01`–`helper20`, or 1–20. If no slot is given, HelperProfiles uses the currently selected worker.

`place` and `move` position the worker about two metres in front of the local player and turn the worker back toward the player.

## Initial test sequence

1. Load a single-player save with HelperProfiles and no active AI helper tasks.
2. Select a worker with `;`, or choose a slot explicitly.
3. Run `hpWorld place A`.
4. Confirm the worker appears approximately two metres in front of the player, in the correct appearance, and idles rather than entering an AI task.
5. Run `hpWorld status` and confirm A reports `spawned=true`.
6. Save/exit/reload and confirm the worker is restored in the same position.
7. Run `hpWorld move A` from another location and verify the saved placement changes.
8. Hire A for a normal AI task. The static world representation should disappear without deleting the stored placement.
9. End the AI task. The worker should return to the stored world position within roughly half a second.
10. Run `hpWorld remove A`; save/reload and confirm A is no longer placed.

## State file

Per-save placements are stored at:

```text
modSettings/FS25_HelperProfiles/saves/savegameX/worldWorkers.xml
```

The file stores only identity and transform data (`x`, `y`, `z`, `yaw`). Appearance remains owned by the existing HelperProfiles / AvatarSwitcher binding system.

## Expected alpha risks

This is intentionally an engine-lifecycle test build. The areas to validate first are:

- whether `HumanGraphicsComponent` accepts helper/AvatarSwitcher `PlayerStyle` data cleanly on every tested map;
- whether the idle/NPC animation parameters produce a natural standing animation rather than a bind pose;
- whether terrain-aligned placement is correct on slopes and around placeable surfaces;
- whether async style loading cleans up safely during rapid place/remove/reload operations.

Do not merge this branch into the 2.1.0.0 ModHub submission line until these tests pass.
