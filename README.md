# FS25 HelperProfiles

**FS25 HelperProfiles** is a single-player helper-management mod for Farming Simulator 25. It expands the standard helper roster to 20 workers, provides deterministic helper selection, displays an autosizing roster overlay, and supports save-specific AvatarSwitcher appearance bindings.

> **Current version:** `2.1.0.0` Alpha 2  
> **Game:** Farming Simulator 25  
> **Multiplayer:** Not supported

## Main Features

- Expands the standard A–J helper roster to **A–T**, for 20 managed helper slots.
- Adds K–T only when the game still has the untouched standard ten-helper roster.
- Preserves existing A–J identities and accepts canonical identities `helper01` through `helper20`.
- Displays the complete managed roster in an autosizing table.
- Automatically pages the compact overlay between A–J and K–T according to the selected worker.
- Shows selected, next, available, and active worker state.
- Keeps active workers visible but unavailable for selection.
- Supports `preferSelected` and `firstFree` hiring modes.
- Stores overlay configuration under `modSettings/FS25_HelperProfiles`.
- Binds AvatarSwitcher appearances to helper slots per savegame.
- Makes active appearance bindings read-only until the worker is released.
- Displays a read-only HelperPayroll **ROLE** column when the companion API is available.
- Provides console commands for roster status, configuration, diagnostics, selection, and integration support.

## Screenshots

### Helper roster overlay

<img width="1920" height="1080" alt="HelperProfiles_UI_1920" src="https://github.com/user-attachments/assets/40897fad-807a-483d-8049-f513b6f44c54" />

### Mode options

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
4. Enable optional companion mods only when their features are required:
   - [FS25_AvatarSwitcher](https://github.com/SimGamerJen/FS25_AvatarSwitcher) for custom appearance bindings.
   - [FS25_HelperPayroll](https://github.com/SimGamerJen/FS25_HelperPayroll) for payroll management and the read-only overlay role column.

Alpha builds should be tested on a copied savegame before being used in an important playthrough.

## Important Compatibility Notice

### Hired Helper Tool

**HelperProfiles is not compatible with Hired Helper Tool (`FS25_HiredHelperTool`).**

Both mods own and expand the available helper roster. When HelperProfiles detects Hired Helper Tool or an externally owned roster above its 20-slot target, HelperProfiles disables itself for that session rather than adopting or replacing the external roster.

When blocked:

- The HelperProfiles overlay is hidden.
- HelperProfiles selection and mode controls are disabled.
- The appearance-binding screen cannot be opened through HelperProfiles.
- The HelperProfiles shared roster API is withdrawn.
- Hired Helper Tool retains ownership of its own roster.

Use **HelperProfiles or Hired Helper Tool, not both**.

## Default Controls

Keybinds can be reassigned under:

```text
Options → Controls → Helper Profiles
```

| Action | Default binding | Description |
|---|---:|---|
| Cycle workers | `;` | Cycles through selectable available helpers. |
| Toggle HelperProfiles mode | `SHIFT + ;` | Switches between `preferSelected` and `firstFree`. |
| Open Profiles screen | `RCTRL + ;` | Opens AvatarSwitcher appearance bindings. |
| Toggle overlay | `RALT + ;` | Shows or hides the HelperProfiles overlay. |

Plain `;` cycling is suppressed while Shift, Ctrl, or Alt is held so the modifier bindings remain independent.

Farming Simulator may retain older local key assignments after an update. Reset or manually reassign the controls if the defaults do not appear.

## Twenty-Slot Roster

HelperProfiles manages slots **A–T**.

- A–J remain the original helper slots.
- K–T are added only when the standard A–J roster is intact.
- Canonical identities are `helper01` through `helper20`.
- Existing A–J save mappings remain accepted.
- The extra workers initially reuse valid base styles from A–J; AvatarSwitcher bindings can then give each slot an independent appearance.

Run the following console command to inspect roster ownership and expansion status:

```text
hpRoster
```

A normal HelperProfiles startup should report 20 helpers and an `expanded-to-20` result.

## Helper Selection and Hiring Modes

### Selected

The selected helper is the worker HelperProfiles will prefer for the next AI job when the current mode allows it.

### Next

The next helper is the worker the current hiring logic expects to allocate. In `preferSelected` mode, **Selected** and **Next** can legitimately show the same worker when the selected worker is available.

### `preferSelected`

This is the default mode.

- The selected helper is used when available.
- If the selected helper is unavailable, HelperProfiles falls back to the next available helper.

### `firstFree`

- The first available helper in roster order is used.
- The selected preference does not override that ordering.

Active workers remain visible but cannot be selected again until released.

## Overlay

The overlay can display:

- Helper slot and display name.
- Selected and next markers.
- `AVAILABLE` or `ACTIVE` status.
- Bound AvatarSwitcher appearance.
- HelperPayroll role when the companion API is available.
- Current HelperProfiles hiring mode.

The compact default view displays ten rows. When a worker in K–T is selected, the overlay automatically shows the K–T page; selecting A–J returns it to the first page.

The appearance column is hidden when no appearance information is available. The role column appears only when HelperPayroll is detected and is read-only in HelperProfiles.

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

The Profiles screen is exclusively for **AvatarSwitcher appearance bindings**. Payroll roles, rates, overrides, and worker compensation are managed from the HelperPayroll UI.

When AvatarSwitcher is installed and has saved presets, the screen can:

- Select any helper slot from A–T.
- Filter presets by category.
- Select a saved appearance.
- Stage a binding.
- Clear one inactive binding.
- Clear all inactive bindings while preserving active slots.
- Save staged changes for the active savegame.

### Active-slot protection

An active worker slot is displayed as **ACTIVE / READ-ONLY**.

- Bind and Clear are refused while the worker is active.
- Clear All leaves active bindings unchanged.
- If a slot becomes active while the screen is open, Save preserves its original binding.
- Release the worker before changing its appearance binding.

AvatarSwitcher presets are read from:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

HelperProfiles stores appearance bindings at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

HelperProfiles uses preset IDs internally while displaying readable categories and descriptions in the UI.

## Optional Companion Mods

### AvatarSwitcher

AvatarSwitcher is not a hard dependency. Without it, HelperProfiles still provides roster expansion, worker cycling, hiring-mode control, the overlay, helper status, console tools, and diagnostics.

Only custom appearance binding requires AvatarSwitcher.

### HelperPayroll

HelperPayroll is not a hard dependency. Without it, HelperProfiles still provides all non-payroll features.

With HelperPayroll `0.4.2.0` or a compatible later build:

- HelperProfiles supplies stable A–T slot identities and display names.
- HelperPayroll manages role assignment, rates, worker overrides, settlement, and ledger persistence.
- The HelperProfiles overlay gains a read-only **ROLE** column.
- Payroll roles are edited from the HelperPayroll management screen, not the HelperProfiles binding screen.

Changing a role while a job is active does not alter the payroll terms already captured when that job started.

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

### Existing A–J data

Existing A–J bindings and identity mappings remain supported. K–T use the same save-specific binding system and canonical identity model as the original slots.

### Legacy `maps_helpers.xml` workflow

Editing the basegame `maps_helpers.xml` file is deprecated and is not required by the current HelperProfiles workflow.

Restore the original basegame file, recreate custom appearances as AvatarSwitcher presets, and bind those presets through the Profiles screen.

Common legacy location:

```text
<Farming Simulator 25 install folder>/data/maps/maps_helpers.xml
```

HelperProfiles does not automatically import custom definitions from an edited basegame file.

## Console Commands

### Roster and diagnostics

| Command | Description |
|---|---|
| `hpRoster` | Prints roster expansion, ownership, target, and helper-count status. |
| `hpDump` | Prints helper state for diagnostics. |
| `hpVersion` | Prints mod and script version information. |

### Selection and mode

| Command | Description |
|---|---|
| `hpSelect <index>` | Selects a helper by index. |
| `hpCycle [delta]` | Cycles selection; negative values cycle backwards. |
| `hpNext` | Selects the next helper. |
| `hpMode status` | Prints the current hiring mode. |
| `hpMode preferSelected` | Prefers the selected available helper. |
| `hpMode firstFree` | Uses the first available helper in roster order. |

### Profiles

| Command | Description |
|---|---|
| `hpAppearance menu` | Opens the appearance-binding screen. |
| `hpAppearance status` | Prints appearance-binding status. |
| `hpAppearance refresh` | Refreshes active worker appearances. |

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

## Troubleshooting

### Only ten workers appear

Run:

```text
hpRoster
```

HelperProfiles adds K–T only when it detects the untouched standard A–J roster. Another map or mod that owns the helper roster can prevent expansion.

### HelperProfiles disables itself

Check `log.txt` for a message from:

```text
[FS25_HelperProfiles/Compatibility]
```

Disable Hired Helper Tool or the conflicting external helper-roster mod, then fully restart the game and reload the save.

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

### A binding cannot be changed

Active slots are intentionally read-only. Release the worker, reopen or refresh the Profiles screen, then change the binding.

### HelperPayroll role column is missing

Confirm that HelperPayroll `0.4.2.0` or a compatible later build is enabled for the same savegame and that only one copy of each mod ZIP exists. Role management remains in the HelperPayroll UI.

### Requesting support

Include the HelperProfiles version, companion-mod versions, relevant `log.txt` excerpt, savegame number, screenshots, and exact reproduction steps.

## Version History

### Version 2.1.0.0 Alpha 2

- Expanded the managed helper roster from A–J to A–T.
- Added canonical identities `helper01` through `helper20`.
- Added K–T by cloning valid base helper styles when the standard roster is intact.
- Added automatic A–J/K–T overlay paging.
- Extended AvatarSwitcher bindings and HelperPayroll identity integration to 20 slots.
- Made active appearance bindings read-only.
- Added Clear All protection for active slots.
- Kept payroll editing exclusively in the HelperPayroll UI.
- Added Hired Helper Tool incompatibility detection and session blocking.
- Added the `hpRoster` diagnostic command.
- Removed unsupported decorative log characters and corrected missing overlay localisation.

### Version 2.0.27.3 Beta

- Corrected duplicate button-bar shortcuts in the Profiles screen.
- Added distinct keyboard actions: **ESC** Close, **X** Bind, **C** Clear, **A** Clear All, and **Enter** Save.
- Added dialog-specific registration and cleanup for the Clear All action.

## Development Status

This is an alpha integration build. The next planned HelperProfiles phase is available/unavailable roster management, followed by further worker-state and in-world helper exploration.

## Permissions

Copyright © 2026 SimGamerJen. All rights reserved.

You may download and use this mod for personal use. You may not modify, redistribute, re-upload, or publish this mod, in whole or in part, or publish a derivative version without prior written permission from SimGamerJen.

## Disclaimer

FS25 HelperProfiles is an unofficial Farming Simulator 25 mod and is not affiliated with or endorsed by GIANTS Software.
