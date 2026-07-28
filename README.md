# FS25 HelperProfiles

**FS25 HelperProfiles** is a single-player helper-management mod for Farming Simulator 25. It provides a clean, autosizing helper roster, deterministic helper selection controls, save-specific appearance bindings through AvatarSwitcher, and optional payroll-role integration with HelperPayroll.

> **Current version:** `2.0.27.2` beta  
> **Game:** Farming Simulator 25  
> **Multiplayer:** Not supported

## Main Features

- Displays the complete vanilla A–J helper roster in an autosizing table.
- Shows each helper's selected, next, free, and in-use state.
- Keeps active workers visible but greyed and unavailable for selection.
- Cycles the preferred helper before starting a new AI job.
- Supports `preferSelected` and `firstFree` hiring modes.
- Stores overlay configuration under `modSettings/FS25_HelperProfiles`.
- Optionally binds AvatarSwitcher appearances to helper profiles per savegame.
- Optionally assigns HelperPayroll roles to helper profiles per savegame.
- Displays a live HelperPayroll **ROLE** column when the companion API is available.
- Provides console commands for configuration, diagnostics, selection, and integration support.

## Screenshots

### Helper roster overlay

<img width="2077" height="1115" alt="HelperProfiles roster overlay" src="https://github.com/user-attachments/assets/f0b58897-cb28-48c3-8fb0-2fc8e832ba93" />

### Profiles and appearance bindings

<img width="2936" height="1483" alt="HelperProfiles profile-management screen" src="https://github.com/user-attachments/assets/e4c6228a-4b0e-4049-b7a4-deb8b0b62cd6" />

### Multiple active workers

<img width="2338" height="1608" alt="Multiple active helpers with different appearances" src="https://github.com/user-attachments/assets/758b8d47-536b-4c86-ae40-213ea8985dcd" />

## Installation

1. Download `FS25_HelperProfiles.zip`.
2. Place the ZIP directly in the Farming Simulator 25 mods folder. Do not unpack it.

```text
Documents/My Games/FarmingSimulator2025/mods
```

3. Enable **Helper Profiles** for the intended savegame.
4. Enable the optional companion mods only when their features are required:
   - [FS25_AvatarSwitcher](https://github.com/SimGamerJen/FS25_AvatarSwitcher) for custom appearance bindings.
   - [FS25_HelperPayroll](https://github.com/SimGamerJen/FS25_HelperPayroll) for payroll-role assignment and the overlay role column.

Test beta builds on a copied savegame before using them in an important playthrough.

## Default Controls

Keybinds can be reassigned under:

```text
Options → Controls → Helper Profiles
```

| Action | Default binding | Description |
|---|---:|---|
| Cycle workers | `;` | Cycles through selectable free helpers. |
| Toggle HelperProfiles mode | `SHIFT + ;` | Switches between `preferSelected` and `firstFree`. |
| Open Profiles screen | `RCTRL + ;` | Opens appearance bindings and optional HelperPayroll role controls. |
| Toggle overlay | `RALT + ;` | Shows or hides the HelperProfiles overlay. |

Plain `;` cycling is suppressed while Shift, Ctrl, or Alt is held so the modifier bindings remain independent.

Farming Simulator may retain older local key assignments after an update. Reset or manually reassign the controls if the defaults do not appear.

## Helper Selection and Hiring Modes

### Selected

The selected helper is the worker HelperProfiles will prefer for the next AI job when the current mode allows it.

### Next

The next helper is the worker the current hiring logic expects to allocate. In `preferSelected` mode, **Selected** and **Next** can legitimately show the same worker when the selected worker is free.

### `preferSelected`

- Tries the currently selected helper first.
- Falls back to another free helper if the selected worker is already active.

### `firstFree`

- Uses the first available worker from the current helper ordering.
- The selected row remains visible but does not force assignment.

## Main Overlay

The overlay is an autosizing roster table rather than a fixed text block. It can display:

- Slot.
- Worker name.
- Selection marker.
- Expected next worker.
- Availability or active state.
- Bound appearance.
- HelperPayroll role.

The appearance column is hidden when no appearance data is available. The role column is hidden when HelperPayroll is absent.

Overlay settings include:

- Screen anchor and position.
- Font size and row spacing.
- Padding and maximum rows.
- Background opacity and visibility.
- Outline and marker visibility.
- Base-HUD visibility binding.
- Input debounce.

## Profiles Screen

Open the Profiles screen with:

```text
RCTRL + ;
```

or:

```text
hpAppearance menu
```

The screen combines helper-profile management with optional companion-mod controls.

### AvatarSwitcher appearance bindings

When AvatarSwitcher is installed and has saved presets, the screen can:

- Select a helper profile.
- Filter presets by category.
- Select a saved appearance.
- Stage a binding.
- Clear one binding or all bindings.
- Save the staged changes for the active savegame.

AvatarSwitcher presets are read from:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

HelperProfiles stores appearance bindings at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

HelperProfiles uses preset IDs internally while displaying readable categories and descriptions in the UI.

### HelperPayroll role assignment

When HelperPayroll `0.4.1.1` or a compatible later build is active, the Profiles screen also displays the selected helper's payroll role.

- Role definitions are supplied by HelperPayroll.
- Role changes are staged in the HelperProfiles screen.
- **Save** writes the assignment through the HelperPayroll API.
- Set HelperPayroll's payroll mode to `helperSlot` for individual worker assignments to control payroll calculations; `roleType` continues to use one globally selected role.
- HelperPayroll owns the compensation rules and persistence.
- HelperProfiles owns helper identity and presentation.
- Assignments are save-specific.
- The controls remain hidden when HelperPayroll is not installed.
- A visible waiting state is used if HelperPayroll is loaded but its API is not ready yet.

Changing a worker's role does not alter the payroll terms already captured by an active job.

## Optional Companion Mods

### AvatarSwitcher

AvatarSwitcher is not a hard dependency. Without it, HelperProfiles still provides worker cycling, hiring-mode control, the roster overlay, helper status, console tools, diagnostics, and HelperPayroll integration.

Only custom appearance binding requires AvatarSwitcher.

### HelperPayroll

HelperPayroll is not a hard dependency. Without it, HelperProfiles still provides all non-payroll features.

With a compatible HelperPayroll build:

- The overlay gains a **ROLE** column.
- Roles can be assigned from the Profiles screen.
- Stable helper identities are supplied to HelperPayroll.
- HelperPayroll stores the mapping and calculates compensation.

## Save Data and Migration

### Appearance bindings

Current per-save location:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

Older builds may have used:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/appearanceLinks.xml
```

HelperProfiles includes migration support for the older global file. Back up the existing `modSettings/FS25_HelperProfiles` folder before upgrading.

### Legacy `maps_helpers.xml` workflow

Editing the basegame `maps_helpers.xml` file is deprecated and is not required by the current HelperProfiles workflow.

Restore the original basegame file, recreate custom appearances as AvatarSwitcher presets, and bind those presets through the Profiles screen.

Common legacy location:

```text
<Farming Simulator 25 install folder>/data/maps/maps_helpers.xml
```

## Console Commands

Run a command with `help` to see its available options.

| Command | Purpose |
|---|---|
| `hpOverlay` | Configures the roster overlay. |
| `hpPickMode` | Reads or changes the hiring mode. |
| `hpSelect` | Selects a helper by name, index, or slot. |
| `hpResetOrder` | Restores the cached default helper order when safe. |
| `hpAppearance` | Opens, inspects, reloads, or manages appearance bindings. |
| `hpPayroll` | Reports HelperPayroll integration status. |
| `hpDiag` | Displays diagnostic information. |
| `hpDiagLog` | Writes detailed diagnostic output to the log. |

## Troubleshooting

### The default keybind does not appear

Farming Simulator can retain previous control assignments in the user's input-binding file. Reassign the action manually or reset the relevant controls.

### An active helper cannot be selected

This is intentional. Active helpers remain visible but are excluded from the selectable free-helper cycle.

### Appearance controls show no presets

Confirm that AvatarSwitcher has at least one saved preset in `avatarPresets.xml`, then reload the Profiles screen.

### Payroll-role controls are missing

Confirm that HelperPayroll `0.4.1.1` or a compatible later build is enabled. Use:

```text
hpPayroll status
```

If HelperPayroll is detected but still starting, the screen displays a waiting state and retries automatically.

### Assigned roles do not affect payroll

Set HelperPayroll's payroll mode to:

```text
helperSlot
```

In `roleType` mode, HelperPayroll intentionally uses the single globally selected role instead of individual helper assignments.

## Development Status

This is a beta build intended for continued testing.

Planned development includes:

- Expanding the usable helper roster beyond the vanilla A–J limit.
- Stable internal identities for a larger helper pool.
- Compatibility handling for other helper-limit mods.
- Available and unavailable roster status.
- Further profile-management and companion-mod integration improvements.

## Licence

Copyright © SimGamerJen. All rights reserved unless otherwise stated in the repository licence.
