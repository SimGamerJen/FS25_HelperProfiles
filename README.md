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

<img width="1920" height="1080" alt="HelperProfiles_UI_1920" src="https://github.com/user-attachments/assets/40897fad-807a-483d-8049-f513b6f44c54" />

## Mode options

<img width="1920" height="1080" alt="HelperProfiles_mode_toggle_First_available_1920" src="https://github.com/user-attachments/assets/4ff0ecf5-9c4f-472a-a16a-966fe67d9599" />

<img width="1920" height="1080" alt="HelperProfiles_mode_toggle_prefer_selected_1920" src="https://github.com/user-attachments/assets/0dc6ad7e-8a3a-4199-94d0-a4b4ceb65807" />

### Profiles and appearance bindings

<img width="1920" height="1080" alt="HelperProfiles_appearance_binding_1920" src="https://github.com/user-attachments/assets/ea6def70-4c20-41b3-a371-88a62b3fe318" />

### Activated workers

<img width="1920" height="1080" alt="HelperProfiles_active_worker_with_mod_XML_defined_appearance_1920" src="https://github.com/user-attachments/assets/741ce686-83a7-4e24-aac2-80372275d858" />

<img width="1920" height="1080" alt="HelperProfiles_active_worker_with_native_worker_appearance_but_selected_1920" src="https://github.com/user-attachments/assets/9757c4b3-f08a-4543-8ae1-e10a57f74162" />

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

This is the default mode.

- The selected helper is used when free.
- If the selected helper is unavailable, HelperProfiles falls back to the next free helper.

### `firstFree`

- The first free helper in roster order is used.
- The selected preference does not override that ordering.

The full A–J roster remains visible. Workers already active on jobs are shown as in use and cannot be selected until released.

## Overlay

The overlay can display:

- Helper slot and display name.
- Selected and next markers.
- `FREE` or `IN USE` status.
- Bound AvatarSwitcher appearance.
- HelperPayroll role.
- Current HelperProfiles hiring mode.

The appearance column is hidden when no appearance information is available. The role column appears only when HelperPayroll is detected; it can temporarily show `WAITING` while HelperPayroll publishes its API.

### Overlay configuration

The default configuration file is:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/config.xml
```

Configurable properties include:

- Position and anchor.
- Scale and width.
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

HelperProfiles does not automatically import custom definitions from an edited basegame file.

## Console Commands

Open the in-game console and use the following commands.

### Overlay

| Command | Description |
|---|---|
| `hpOverlay on` | Shows the overlay. |
| `hpOverlay off` | Hides the overlay. |
| `hpOverlay toggle` | Toggles overlay visibility. |
| `hpOverlay status` | Prints overlay status and configuration. |
| `hpOverlay pos <x> <y>` | Sets normalized screen position. |
| `hpOverlay anchor TL\|TR\|BL\|BR` | Sets the anchor corner. |
| `hpOverlay scale <0.5..2.0>` | Sets overlay scale. |
| `hpOverlay width <0.15..0.90>` | Sets overlay width. |
| `hpOverlay font <0.010..0.030>` | Sets font size. |
| `hpOverlay rowgap <0.001..0.03>` | Sets row spacing. |
| `hpOverlay maxrows <3..30>` | Sets maximum visible rows. |
| `hpOverlay pad <0..0.05>` | Sets padding. |
| `hpOverlay opacity <0..1>` | Sets background opacity. |
| `hpOverlay bg on\|off` | Controls the background. |
| `hpOverlay outline on\|off` | Controls the outline. |
| `hpOverlay markers on\|off` | Controls selected/next markers. |
| `hpOverlay bindhud on\|off` | Follows or ignores base-HUD visibility. |
| `hpOverlay debounce <ms>` | Sets the worker-cycle debounce interval. |
| `hpOverlay save [filename]` | Saves the current overlay configuration. |
| `hpOverlay load [filename]` | Loads an overlay configuration. |
| `hpOverlay reset` | Restores and saves the defaults. |

### Selection and mode

| Command | Description |
|---|---|
| `hpSelect <index>` | Selects a helper by index. |
| `hpCycle [delta]` | Cycles selection; negative values cycle backwards. |
| `hpNext` | Selects the next helper. |
| `hpMode status` | Prints the current hiring mode. |
| `hpMode preferSelected` | Prefers the selected free helper. |
| `hpMode firstFree` | Uses the first free helper in roster order. |
| `hpDump` | Prints helper state for diagnostics. |

### Profiles and version

| Command | Description |
|---|---|
| `hpAppearance menu` | Opens the Profiles screen. |
| `hpAppearance status` | Prints appearance-binding status. |
| `hpAppearance refresh` | Refreshes active worker appearances. |
| `hpVersion` | Prints mod and script version information. |

## Troubleshooting

### Overlay is not visible

When `bindhud` is enabled, the overlay follows the base game HUD.

```text
hpOverlay bindhud off
hpOverlay on
```

### Selection skips or advances twice

Increase the debounce value:

```text
hpOverlay debounce 300
```

### Appearance categories are missing

Confirm that AvatarSwitcher is installed and enabled, at least one preset has been saved, `avatarPresets.xml` exists, and preset IDs, categories, and descriptions are valid.

### Payroll role controls are missing

Confirm that:

- HelperPayroll is installed and enabled for the same savegame.
- HelperPayroll is version `0.4.1.1` or a compatible later build.
- Only one copy of each mod ZIP exists in the mods folder.
- The game was fully restarted after replacing either mod.
- `log.txt` contains the HelperPayroll API publication message.

If HelperPayroll is detected before its API is ready, the screen and overlay should show a waiting state and retry automatically.

### Requesting support

Include the HelperProfiles version, companion-mod versions, relevant `log.txt` excerpt, savegame number, screenshots, and exact reproduction steps.

## Version 2.0.27.2

- Added optional HelperPayroll role selection to the Profiles screen.
- Added staged per-helper role editing with save-specific persistence through HelperPayroll.
- Added load-order-safe global and mission API discovery.
- Added automatic retry and visible waiting states.
- Added a live HelperPayroll **ROLE** column to the main overlay.
- Compacted repeated appearance text so the additional column fits cleanly.
- Retained operation when HelperPayroll or AvatarSwitcher is absent.

## Development Status

This is a beta integration build. The next planned HelperProfiles development phase is an expanded helper roster beyond the vanilla A–J limit, followed by available/unavailable roster management.

## Permissions

Copyright © 2026 SimGamerJen. All rights reserved.

You may download and use this mod for personal use. You may not modify, redistribute, re-upload, or publish this mod, in whole or in part, or publish a derivative version without prior written permission from SimGamerJen.

## Disclaimer

FS25 HelperProfiles is an unofficial Farming Simulator 25 mod and is not affiliated with or endorsed by GIANTS Software.
