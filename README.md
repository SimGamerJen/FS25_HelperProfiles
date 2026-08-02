# FS25 HelperProfiles

**FS25 HelperProfiles** is a single-player helper-management mod for Farming Simulator 25. It expands the standard helper roster to 20 permanent worker identities, provides deterministic helper selection, adds per-save ON/OFF roster management, displays an autosizing helper overlay, and supports save-specific AvatarSwitcher appearance bindings.

> **Current version:** `2.1.0.0`  
> **Game:** Farming Simulator 25  
> **Multiplayer:** Not supported

## Highlights in 2.1.0.0

- Expands the managed helper identity pool from **A–J** to **A–T**.
- Adds stable canonical identities `helper01` through `helper20`.
- Adds a per-save **ON/OFF Helper Roster** manager.
- Replaces the old cross-navigation buttons with a clean two-tab **Helper Management** screen:
  - **Appearances**
  - **Helper Roster**
- Excludes OFF-roster workers from cycling, overlay selection, Next calculations and hiring.
- Prevents active workers from being removed from the roster.
- Ensures at least one worker always remains ON roster.
- Preserves AvatarSwitcher bindings, HelperPayroll roles, compensation overrides and ledger identities when workers are disabled and later restored.
- Keeps HelperPayroll roles visible when the operational roster is filtered.
- Adds guarded **Disable Others** and **Enable All** actions.
- Adds automatic A–J/K–T overlay paging.
- Adds Hired Helper Tool and external-roster incompatibility protection.
- Includes performance fixes validated in game with no recurrence of the earlier FPS collapse.

## Main Features

- Twenty permanent helper identities: **A–T**.
- Configurable `preferSelected` and `firstFree` hiring modes.
- Autosizing tabular overlay showing selected, next, available and active workers.
- Optional AvatarSwitcher appearance bindings stored per savegame.
- Optional read-only HelperPayroll role information.
- Per-save roster availability stored independently from appearance and payroll data.
- Console commands for selection, diagnostics, roster management and overlay configuration.

## Screenshots

### Helper roster overlay

<img width="1920" height="1080" alt="HelperProfiles helper overlay" src="https://github.com/user-attachments/assets/40897fad-807a-483d-8049-f513b6f44c54" />

### Mode options

<img width="1920" height="1080" alt="First available mode" src="https://github.com/user-attachments/assets/4ff0ecf5-9c4f-472a-a16a-966fe67d9599" />

<img width="1920" height="1080" alt="Prefer selected mode" src="https://github.com/user-attachments/assets/0dc6ad7e-8a3a-4199-94d0-a4b4ceb65807" />

### Appearance bindings

<img width="1920" height="1080" alt="Helper appearance bindings" src="https://github.com/user-attachments/assets/ea6def70-4c20-41b3-a371-88a62b3fe318" />

## Installation

1. Download `FS25_HelperProfiles.zip` from the GitHub release.
2. Place the ZIP directly in the Farming Simulator 25 mods folder. Do not unpack it.

```text
Documents/My Games/FarmingSimulator2025/mods
```

3. Enable **Helper Profiles** for the intended savegame.
4. Enable optional companion mods only when their features are required:
   - [FS25_AvatarSwitcher](https://github.com/SimGamerJen/FS25_AvatarSwitcher) for custom appearances.
   - [FS25_HelperPayroll](https://github.com/SimGamerJen/FS25_HelperPayroll) for payroll management and role display.

Back up important savegames and `modSettings/FS25_HelperProfiles` before installing a major update.

## Important Compatibility Notice

### Hired Helper Tool

**HelperProfiles is not compatible with Hired Helper Tool (`FS25_HiredHelperTool`).**

Both mods own and expand the available helper roster. When HelperProfiles detects Hired Helper Tool or an externally owned roster above its 20-slot target, HelperProfiles disables itself for that session rather than adopting or replacing the external roster.

When blocked:

- the HelperProfiles overlay is hidden;
- HelperProfiles selection and mode controls are disabled;
- Helper Management cannot be opened through HelperProfiles;
- the shared HelperProfiles API is withdrawn;
- the external mod retains ownership of its roster.

Use **HelperProfiles or Hired Helper Tool, not both**.

## Default Controls

Keybinds can be reassigned under:

```text
Options → Controls → Helper Profiles
```

| Action | Default binding | Description |
|---|---:|---|
| Cycle workers | `;` | Cycles through selectable ON-roster helpers. |
| Toggle hiring mode | `SHIFT + ;` | Switches between `preferSelected` and `firstFree`. |
| Open Helper Management | `RCTRL + ;` | Opens the Appearances and Helper Roster tabs. |
| Toggle overlay | `RALT + ;` | Shows or hides the HelperProfiles overlay. |

Plain `;` cycling is suppressed while Shift, Ctrl or Alt is held so the modifier bindings remain independent.

## Twenty-Slot Identity Pool

HelperProfiles manages permanent slots **A–T**.

- A–J remain the original helper slots.
- K–T are added only when the standard A–J roster is intact.
- Canonical identities are `helper01` through `helper20`.
- Existing A–J appearance and payroll mappings remain compatible.
- The extra workers initially reuse valid base helper styles from A–J.
- AvatarSwitcher can assign each slot an independent saved appearance.

Run the following console command to inspect roster ownership and expansion status:

```text
hpRoster
```

A normal startup should report 20 helpers and an `expanded-to-20` result.

## Helper Roster Availability

Open **Helper Management** with `RCTRL + ;`, then select the **Helper Roster** tab.

The roster table shows all A–T identities with:

- slot;
- worker display name;
- AvatarSwitcher appearance;
- read-only HelperPayroll role;
- current work state;
- ON/OFF roster state.

### ON roster

An ON-roster worker can appear in the overlay, be selected with `;`, be calculated as Next and be allocated to a new AI job.

### OFF roster

An OFF-roster worker remains a permanent stored identity but is excluded from normal operation. Turning a worker OFF does **not** delete:

- their AvatarSwitcher appearance binding;
- their HelperPayroll role;
- worker-specific compensation overrides;
- existing ledger identity or history.

### Roster safeguards

- An active worker cannot be switched OFF.
- At least one worker must remain ON roster.
- Save revalidates active state in case a worker started a job while the screen was open.
- **Disable Others** keeps the selected worker and all active workers ON.
- **Enable All** restores every A–T identity to the operational roster.
- When every ON-roster worker is busy, the engine fallback is blocked from silently hiring an OFF-roster worker.

Roster state is stored at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/roster.xml
```

Existing saves without this file default all twenty workers to ON.

## Helper Management Tabs

`RCTRL + ;` opens the **Appearances** tab by default.

### Appearances

When AvatarSwitcher is installed and contains saved presets, this tab can:

- select an ON-roster helper slot;
- filter saved appearances by category;
- stage a binding;
- clear one inactive binding;
- clear all inactive bindings while preserving active slots;
- save appearance changes for the active savegame.

Active worker slots are displayed as **ACTIVE / READ-ONLY**. Release the worker before changing their appearance binding.

Appearance bindings are stored at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

### Helper Roster

The Helper Roster tab manages which permanent A–T identities are operationally available. Appearance and roster drafts remain staged when switching between the two tabs. Closing without saving discards those drafts.

The console command below opens directly on the roster tab:

```text
hpRosterManage
```

## Helper Selection and Hiring Modes

### Selected

The selected helper is the worker HelperProfiles will prefer for the next AI job when the active mode permits it.

### Next

The Next worker is the helper the current hiring logic expects to allocate. In `preferSelected` mode, Selected and Next can legitimately show the same worker when that worker is available.

### `preferSelected`

- Uses the selected worker when available.
- Falls back to the next available ON-roster worker when necessary.

### `firstFree`

- Uses the first available ON-roster worker in roster order.
- The selected preference does not override that ordering.

Active workers remain visible in the overlay but cannot be selected again until released.

## Overlay

The overlay can display:

- helper slot and display name;
- selected and next markers;
- `AVAILABLE` or `ACTIVE` status;
- bound AvatarSwitcher appearance;
- HelperPayroll role when the companion API is available;
- current HelperProfiles hiring mode.

The compact default view displays ten rows. Selecting a worker in K–T shows the K–T page; selecting A–J returns to the first page. OFF-roster workers are not shown.

Overlay configuration is stored under:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/config.xml
```

## Optional Companion Mods

### AvatarSwitcher

AvatarSwitcher is optional. Without it, HelperProfiles still provides roster expansion, ON/OFF roster management, cycling, hiring modes, the overlay and diagnostics.

### HelperPayroll

HelperPayroll is optional. With HelperPayroll `0.4.2.0` or a compatible later version:

- HelperProfiles supplies stable A–T slot identities and display names;
- HelperPayroll manages roles, rates, overrides, settlement and ledger persistence;
- the HelperProfiles overlay and roster tab display read-only payroll roles;
- roles remain assigned while workers are OFF roster.

Payroll roles are edited in the HelperPayroll management screen, not HelperProfiles.

## Save Data and Migration

Current per-save files:

```text
modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
modSettings/FS25_HelperProfiles/saves/savegameX/roster.xml
```

Older builds may have used a global appearance file:

```text
modSettings/FS25_HelperProfiles/appearanceLinks.xml
```

HelperProfiles includes migration support for the older global appearance file.

Editing the basegame `maps_helpers.xml` file is deprecated and is not required. Restore the original basegame file and recreate custom appearances as AvatarSwitcher presets.

## Console Commands

### Roster and diagnostics

| Command | Description |
|---|---|
| `hpRoster` | Prints roster expansion, ownership and helper-count status. |
| `hpRosterManage` | Opens Helper Management directly on the Helper Roster tab. |
| `hpDump` | Prints helper state for diagnostics. |
| `hpVersion` | Prints mod and script version information. |

### Selection and mode

| Command | Description |
|---|---|
| `hpSelect <index>` | Selects an operational helper by index. |
| `hpCycle [delta]` | Cycles selection; negative values cycle backwards. |
| `hpNext` | Selects the next available worker. |
| `hpMode status` | Prints the current hiring mode. |
| `hpMode preferSelected` | Prefers the selected available worker. |
| `hpMode firstFree` | Uses the first available worker in roster order. |

### Appearance management

| Command | Description |
|---|---|
| `hpAppearance menu` | Opens Helper Management on the Appearances tab. |
| `hpAppearance status` | Prints appearance-binding status. |
| `hpAppearance refresh` | Refreshes active worker appearances. |

### Overlay

| Command | Description |
|---|---|
| `hpOverlay on` | Shows the overlay. |
| `hpOverlay off` | Hides the overlay. |
| `hpOverlay toggle` | Toggles overlay visibility. |
| `hpOverlay status` | Prints overlay status and configuration. |
| `hpOverlay reset` | Restores and saves default overlay settings. |

Additional `hpOverlay` commands support position, anchor, scale, width, font size, row spacing, maximum rows, padding, opacity, background, outline, markers, HUD binding and debounce configuration.

## Troubleshooting

### Only ten workers appear

Run `hpRoster`. HelperProfiles adds K–T only when it detects the untouched standard A–J roster.

### HelperProfiles disables itself

Check `log.txt` for `[FS25_HelperProfiles/Compatibility]`. Disable Hired Helper Tool or the conflicting external roster mod, then fully restart the game.

### An OFF worker is still visible elsewhere

HelperProfiles filters its own overlay, selection and hiring systems. A companion mod may still display the permanent identity pool for configuration or historical purposes.

### A worker cannot be switched OFF

Active workers are protected. Release the worker before removing them from the operational roster. The final ON-roster worker is also protected.

### A binding cannot be changed

Active appearance bindings are read-only. Release the worker, reopen Helper Management and make the change again.

### HelperPayroll roles are missing

Confirm HelperPayroll `0.4.2.0` or later is enabled for the same savegame and that only one copy of each mod ZIP exists.

## Version History

### Version 2.1.0.0

- Expanded the helper identity pool to A–T.
- Added per-save ON/OFF roster management.
- Added the two-tab Helper Management screen.
- Added operational filtering and guarded hiring fallback.
- Added active-worker and minimum-roster safeguards.
- Preserved appearance and payroll identities across disable/re-enable.
- Added automatic A–J/K–T overlay paging.
- Added external-roster and Hired Helper Tool protection.
- Corrected filtered-roster HelperPayroll role display.
- Resolved the FPS regression discovered during alpha testing.

### Version 2.0.27.3 Beta

- Corrected duplicate button-bar shortcuts in the appearance screen.
- Added distinct keyboard actions for Close, Bind, Clear, Clear All and Save.

## Development Status

Version `2.1.0.0` is the validated release of the A–T identity pool, per-save roster availability manager and tabbed Helper Management interface.

A future HelperPayroll update may optionally filter or mark OFF-roster workers in its Workers tab while preserving payroll history and assignments.

## Permissions

Copyright © 2026 SimGamerJen. All rights reserved.

You may download and use this mod for personal use. Redistribution, re-uploading, repackaging or publishing modified builds requires permission from SimGamerJen.
