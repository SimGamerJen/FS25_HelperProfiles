# FS25 HelperProfiles

**FS25 HelperProfiles** is a single-player helper-management mod for Farming Simulator 25. It adds an autosizing helper overlay, deterministic helper-selection controls, helper hiring modes, console and diagnostic tools, and optional integration with **FS25_AvatarSwitcher** for assigning saved appearances to helper profile slots.

> **Multiplayer is not supported.** Version 2.0.26.0 declares `<multiplayer supported="false"/>`.

**Current stable release:** `2.0.26.0`

---

## Highlights

- Autosizing tabular helper overlay.
- Full A–J helper roster visibility.
- Selected and next-helper indicators.
- `AVAILABLE` and `ACTIVE` status display.
- Configurable `preferSelected` and `firstFree` hiring modes.
- Persistent overlay configuration.
- Optional per-savegame AvatarSwitcher appearance bindings.
- English, German, and French localisation.
- Read-only integration API for compatible mods.
- Single-player packaging prepared for ModHub testing.

---

## What HelperProfiles Does

HelperProfiles gives you more control over which AI helper is selected and clearer visibility of the helper roster.

It can:

- Cycle through selectable helpers.
- Prefer the selected helper when the game hires a worker.
- Fall back safely when the selected helper is already active.
- Keep active helpers visible but greyed out and unavailable for selection.
- Show which helper is selected.
- Show which helper is expected to be hired next.
- Switch between deterministic helper allocation modes.
- Save overlay settings under `modSettings/FS25_HelperProfiles`.
- Optionally bind AvatarSwitcher appearances to helper slots for each savegame.

HelperProfiles does not require AvatarSwitcher for its core helper-selection and overlay features.

---

## Version 2.0.26.0: Autosizing Tabular Overlay

The overlay has been rebuilt as a measured table rather than a single proportional-text roster.

| Column | Purpose |
|---|---|
| `SLOT` | Stable helper slot, normally A–J. |
| `WORKER` | Helper display name. |
| `STATUS` | `AVAILABLE` or `ACTIVE`. |
| `APPEARANCE` | Bound AvatarSwitcher appearance, when relevant. |
| `SEL` | The currently selected available helper. |
| `NEXT` | The helper currently expected to be hired next. |

A summary line above the table shows:

- Current helper hiring mode.
- Number of available helpers.
- Number of active helpers.

### Automatic sizing

With autosizing enabled, the overlay:

- Measures the visible headings and row values.
- Expands to fit the longest displayed content.
- Retains the existing default font size of `0.014`.
- Uses the configured width as a minimum width.
- Hides the `APPEARANCE` column when no displayed helper has an appearance binding.
- Resizes vertically to the number of visible rows.
- Clamps the panel to the visible screen area.
- Maintains stable status-column sizing for `AVAILABLE` and `ACTIVE`.
- Highlights the selected row.
- Greys out active helpers.

Disable autosizing with:

```text
hpOverlay autosize off
```

When autosizing is disabled, `hpOverlay width` controls the fixed panel width.

---

## Screenshots

### HelperProfiles overlay

<img width="2077" height="1115" alt="HelperProfiles overlay" src="https://github.com/user-attachments/assets/f0b58897-cb28-48c3-8fb0-2fc8e832ba93" />

### Appearance binding interface

<img width="2936" height="1483" alt="HelperProfiles appearance binding interface" src="https://github.com/user-attachments/assets/e4c6228a-4b0e-4049-b7a4-deb8b0b62cd6" />

### Multiple active helpers with separate appearances

<img width="2338" height="1608" alt="Multiple workers with separate appearances" src="https://github.com/user-attachments/assets/758b8d47-536b-4c86-ae40-213ea8985dcd" />

> Replace the overlay screenshot when a version 2.0.26.0 capture is available.

---

## Requirements and Compatibility

### Farming Simulator

- Farming Simulator 25.
- Designed for single-player use.
- Multiplayer support is disabled in `modDesc.xml`.

### FS25_AvatarSwitcher

[FS25_AvatarSwitcher](https://github.com/SimGamerJen/FS25_AvatarSwitcher) is optional.

Without AvatarSwitcher, these features still work:

- Helper cycling.
- Helper hiring modes.
- Autosizing helper overlay.
- Overlay configuration.
- Console and diagnostic commands.
- Shared read-only integration API.

AvatarSwitcher is required only for custom helper appearance bindings.

### Other helper mods

Mods that alter AI helper selection, hiring, ordering, names, or worker appearance may conflict with HelperProfiles. Test combinations on a copied savegame.

---

## Installation

1. Download `FS25_HelperProfiles.zip` from the GitHub release.
2. Place the ZIP in:

```text
Documents/My Games/FarmingSimulator2025/mods
```

3. Do not unpack the ZIP.
4. Launch Farming Simulator 25.
5. Enable **Helper Profiles** for the savegame.
6. Enable **FS25_AvatarSwitcher** as well only when appearance bindings are required.

The mod creates its settings folder at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles
```

---

## Updating

Before updating an important savegame:

1. Back up the savegame.
2. Back up:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles
```

3. Replace the existing HelperProfiles ZIP.
4. Load the savegame and check the overlay and helper bindings.
5. Save the overlay configuration after making any adjustments.

Older version 1 overlay configuration is migrated to the version 2 measured-table layout. Migration enables autosizing and adds the new column-gap setting.

---

## Default Controls

Controls can be changed under:

```text
Options → Controls → Helper Profiles
```

| Action | Default binding | Description |
|---|---:|---|
| Cycle helper | `;` | Selects the next available helper. |
| Toggle HelperProfiles mode | `SHIFT + ;` | Switches the helper hiring mode. |
| Open appearance bindings | `RCTRL + ;` | Opens the AvatarSwitcher binding interface. |
| Toggle overlay | `RALT + ;` | Shows or hides the helper overlay. |

Plain `;` cycling is suppressed while Shift, Ctrl, or Alt is held so the modified bindings can operate independently.

Farming Simulator may preserve older local key assignments after an update. Reset or manually reassign the controls when the defaults do not appear.

---

## Helper Hiring Modes

### `preferSelected`

Default mode. HelperProfiles attempts to hire the selected helper when available. If that helper is already active, the mod falls back to the next available helper.

### `firstFree`

Uses the first available helper in list order.

Check or change the mode with:

```text
hpMode status
hpMode preferSelected
hpMode firstFree
```

---

## Overlay Configuration

Default configuration file:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/config.xml
```

Example version 2 configuration:

```xml
<hp version="2">
  <ui
      anchor="TR"
      x="0.985"
      y="0.900"
      scale="1.0"
      width="0.24"
      autoSize="true"
      columnGap="0.010"
      opacity="0.40"
      pad="0.006"
      rowGap="0.006"
      font="0.014"
      maxRows="10"
      bg="true"
      outline="false"
      shadow="false"
      markers="true"
      bindHud="true"
  />
</hp>
```

### Visibility and placement

| Command | Description |
|---|---|
| `hpOverlay on` | Show the overlay. |
| `hpOverlay off` | Hide the overlay. |
| `hpOverlay toggle` | Toggle visibility. |
| `hpOverlay pos <x> <y>` | Set normalized screen coordinates from `0` to `1`. |
| `hpOverlay anchor TL\|TR\|BL\|BR` | Set the anchor corner. |

### Size and layout

| Command | Description |
|---|---|
| `hpOverlay scale <0.5..2.0>` | Set overall overlay scale. |
| `hpOverlay width <0.15..0.90>` | Set minimum autosize width or fixed width. |
| `hpOverlay autosize on\|off` | Enable or disable measured sizing. |
| `hpOverlay font <0.010..0.030>` | Set text size. |
| `hpOverlay rowgap <0.001..0.03>` | Set vertical row spacing. |
| `hpOverlay colgap <0.002..0.04>` | Set spacing between table columns. |
| `hpOverlay maxrows <3..30>` | Set maximum displayed rows. |
| `hpOverlay pad <0..0.05>` | Set internal padding. |

### Appearance and HUD behaviour

| Command | Description |
|---|---|
| `hpOverlay opacity <0..1>` | Set background opacity. |
| `hpOverlay bg on\|off` | Enable or disable the panel background. |
| `hpOverlay outline on\|off` | Enable or disable the panel outline. |
| `hpOverlay markers on\|off` | Show or hide `SEL` and `NEXT`. |
| `hpOverlay bindhud on\|off` | Follow or ignore base HUD visibility. |

### Input behaviour and persistence

| Command | Description |
|---|---|
| `hpOverlay debounce <ms>` | Set helper-cycle debounce. |
| `hpOverlay save [filename]` | Save the current overlay configuration. |
| `hpOverlay load [filename]` | Load an overlay configuration. |
| `hpOverlay reset` | Restore and save defaults. |
| `hpOverlay help` | Print the overlay command list. |

Named configuration files are read from or written to:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles
```

---

## Helper Commands

| Command | Description |
|---|---|
| `hpSelect <index>` | Select a helper by current list index. |
| `hpCycle [delta]` | Cycle selection; negative values cycle backwards. |
| `hpNext` | Print the helper expected to be hired next. |
| `hpDump` | Print the current helper roster and active state. |
| `hpResetOrder` | Restore default helper order when no helpers are active. |
| `hpMode status` | Print the current hiring mode. |
| `hpMode preferSelected` | Prefer the selected available helper. |
| `hpMode firstFree` | Use the first available helper. |

---

## AvatarSwitcher Appearance Bindings

HelperProfiles uses a binding workflow rather than editing basegame helper definitions.

The interface allows you to:

- Select a helper slot.
- Select an AvatarSwitcher category and preset.
- Stage and save a binding.
- Clear one binding or all bindings.
- Refresh active worker appearances.

Open it with:

```text
RCTRL + ;
```

or:

```text
hpAppearance menu
```

### Storage

AvatarSwitcher presets:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

Per-save HelperProfiles bindings:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

### Appearance commands

| Command | Description |
|---|---|
| `hpAppearance menu` | Open the binding interface. |
| `hpAppearance status` | Print bridge and binding diagnostics. |
| `hpAppearance reload` | Reload appearance links. |
| `hpAppearance refresh` | Refresh active worker appearances. |
| `hpAppearance debug` | Toggle appearance debugging. |
| `hpAppearance cycle [delta]` | Cycle the selected helper appearance. |
| `hpAppearance bind <helperIndex> <presetId>` | Bind a preset by ID. |
| `hpAppearance unbind <helperIndex>` | Remove one helper binding. |
| `hpAppearance clear` | Remove all bindings for the current save. |
| `hpAppearance bindLegacy <helperIndex> <category> [presetId]` | Create a legacy category binding. |

The in-game XML interface is recommended for normal use.

---

## Migration from Edited `maps_helpers.xml`

Early custom-helper workflows required editing:

```text
<Farming Simulator 25 installation>/data/maps/maps_helpers.xml
```

That workflow is deprecated.

Current migration process:

1. Back up the edited file for reference.
2. Restore the original basegame file.
3. Use platform file verification if no clean backup exists.
4. Install FS25_AvatarSwitcher.
5. Recreate custom appearances as AvatarSwitcher presets.
6. Bind the presets through HelperProfiles.
7. Save bindings for the current savegame.

HelperProfiles does not automatically import helper definitions from an edited basegame file.

---

## Migration from Global Appearance Bindings

Older builds may have stored bindings at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/appearanceLinks.xml
```

Current builds store them per savegame:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

HelperProfiles includes migration support for the older global file. After loading the savegame, open the binding interface, confirm the bindings, and press **Save**.

---

## Optional Integration API

HelperProfiles publishes a read-only API at:

```lua
g_currentMission.helperProfilesAPI
```

and:

```lua
g_currentMission.fs25HelperProfilesAPI
```

API version: `4`

It exposes helper status, selected slot and display name, stable slot identity, appearance metadata, and the complete A–J slot collection. Consumers should check that the API exists and inspect `apiVersion` before using it.

---

## Localisation

Included languages:

- English
- German
- French

Files:

```text
l10n/l10n_en.xml
l10n/l10n_de.xml
l10n/l10n_fr.xml
```

The mod uses:

```xml
<l10n filenamePrefix="l10n/l10n"/>
```

Translate every required key when adding another language.

---

## Troubleshooting

### Overlay is not visible

```text
hpOverlay bindhud off
hpOverlay on
```

### Overlay is too wide

```text
hpOverlay colgap 0.006
hpOverlay font 0.013
```

Or use a fixed width:

```text
hpOverlay autosize off
hpOverlay width 0.30
```

### Appearance column is missing

The column is intentionally hidden when none of the displayed helpers has an appearance binding.

### Helper selection skips

```text
hpOverlay debounce 220
```

Try `300` if another input or mod causes repeated activation.

### Active helper cannot be selected

This is intentional. Active helpers remain visible but are greyed out and skipped.

### AvatarSwitcher data is missing

Check that AvatarSwitcher is enabled, at least one preset is saved, and `avatarPresets.xml` contains valid IDs, categories, and names.

For support reports, include the HelperProfiles version, AvatarSwitcher version when relevant, savegame number, `log.txt` excerpt, reproduction steps, and screenshots.

---

## Known Limitations

- Multiplayer is not supported.
- Official ModHub TestRunner and in-game testing should still be completed before publication.
- Unusual resolutions, HUD scales, or very long translations may require overlay adjustment.
- Other helper-selection or avatar mods may override the same behaviour.

---

## Release Packaging

Release ZIP:

```text
FS25_HelperProfiles.zip
```

`modDesc.xml` must be at the ZIP root.

Before publishing:

- Confirm version `2.0.26.0`.
- Confirm multiplayer support is `false`.
- Confirm `icon_helperProfiles.dds` is present.
- Confirm English, German, and French localisation.
- Remove logs, backups, and test files.
- Test on a copied savegame.
- Run the official ModHub TestRunner where available.

Recommended GitHub tag:

```text
v2.0.26.0
```

Recommended release title:

```text
FS25_HelperProfiles v2.0.26.0 – Autosizing Tabular Overlay
```

---

## Contributing

Pull requests are welcome. Update this README whenever a contribution changes helper behaviour, overlay configuration, commands, controls, localisation, AvatarSwitcher integration, savegame storage, the integration API, or multiplayer compatibility.

---

## Disclaimer

This is an unofficial Farming Simulator 25 mod and is not affiliated with or endorsed by GIANTS Software.
