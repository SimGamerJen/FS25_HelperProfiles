# FS25 HelperProfiles

**FS25 HelperProfiles** is a Farming Simulator 25 helper-management mod that adds a game-styled helper overlay, configurable helper selection behaviour, console/debug tools, and an optional **AvatarSwitcher binding interface** for assigning saved appearances to helper profile slots on a per-savegame basis.

This release is intended as a **beta pre-release**. **FS25_AvatarSwitcher** is optional for the core HelperProfiles overlay, worker cycling, and helper mode features. Install and enable [FS25_AvatarSwitcher](https://github.com/SimGamerJen/FS25_AvatarSwitcher) if you want to use custom appearance bindings.

---

## What It Does

HelperProfiles gives you more control and visibility over AI workers in FS25.

It can:

- Show an in-game overlay listing activated helpers.
- Display the currently selected helper.
- Display the next helper the game is expected to hire.
- Switch between helper hiring modes.
- Provide console commands for debugging, selection, overlay control, and version checks.
- Store overlay configuration in `modSettings/FS25_HelperProfiles`.
- Optionally integrate with **FS25_AvatarSwitcher** to bind saved appearances to helper slots.

The AvatarSwitcher binding system is designed to avoid direct runtime AI avatar injection. Previous experiments with direct AI worker avatar/playerStyle injection caused ghosted workers in vehicles, so this mod uses safer binding logic instead.

---

## Screenshots

Suggested screenshots to add here:

1. **Main HelperProfiles overlay**  

<img width="2077" height="1115" alt="hp_hud" src="https://github.com/user-attachments/assets/f0b58897-cb28-48c3-8fb0-2fc8e832ba93" />

2. **Helper binding interface**  

<img width="2936" height="1483" alt="hp_binding_interface" src="https://github.com/user-attachments/assets/e4c6228a-4b0e-4049-b7a4-deb8b0b62cd6" />

3. **Two active helpers with different appearances**  

<img width="2338" height="1608" alt="multiple_workers_support" src="https://github.com/user-attachments/assets/758b8d47-536b-4c86-ae40-213ea8985dcd" />

---

## Installation

1. Download `FS25_HelperProfiles.zip` from the GitHub release.
2. Place the ZIP into your FS25 mods folder. Do not unpack it.

```text
Documents/My Games/FarmingSimulator2025/mods
```

3. Launch Farming Simulator 25.
4. Enable **FS25 HelperProfiles** for your savegame.
5. If using appearance bindings, also enable **FS25_AvatarSwitcher**.

The mod will create its settings folder here:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles
```

The overlay config is stored at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/config.xml
```

Savegame-specific binding data is stored under the HelperProfiles modSettings structure:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

---

## Compatibility

### Farming Simulator

- Built for Farming Simulator 25.
- Tested in normal gameplay with multiple active helpers.

### AvatarSwitcher

AvatarSwitcher is not a hard dependency for the core HelperProfiles features.

These features work without AvatarSwitcher:

- Worker cycling.
- HelperProfiles mode switching.
- Overlay toggle and overlay configuration.
- Console/debug tools.

The helper appearance binding interface requires **FS25_AvatarSwitcher** and its `avatarPresets.xml` data.

HelperProfiles reads AvatarSwitcher preset data so the UI can display readable categories and appearance descriptions while using preset IDs internally.

### Savegames

Bindings are intended to be savegame-specific. Always test beta builds on a copied savegame before using them in an important save.

---

## Migration Notes

### Important: legacy `maps_helpers.xml` edits

Very early HelperProfiles/custom-helper workflows required editing the basegame `maps_helpers.xml` file in the Farming Simulator 25 install directory.

That workflow is now deprecated.

The current HelperProfiles + AvatarSwitcher workflow does **not** use edited basegame helper XML files. Custom helper appearances should now be created as AvatarSwitcher presets and then bound to HelperProfiles slots through the in-game binding interface.

If you previously edited the basegame file, restore the original version before using this release.

Common legacy file location:

```text
<Farming Simulator 25 install folder>/data/maps/maps_helpers.xml
```

Depending on where the game is installed, this may be under a Steam, GIANTS/eShop, Epic, or custom install path.

### Migrating from the old `maps_helpers.xml` workflow

HelperProfiles does **not** currently auto-import helper definitions from an edited `maps_helpers.xml` file.

Recommended migration path:

1. Back up your edited `maps_helpers.xml` file somewhere safe.
2. Restore the original basegame `maps_helpers.xml` file.
   - If you kept a clean backup, copy that back into the game install folder.
   - If you do not have a clean backup, use your game launcher’s file verification/repair option to restore the original game files.
3. Install and enable `FS25_AvatarSwitcher`.
4. Recreate your custom helper appearances as AvatarSwitcher presets.
5. Install and enable `FS25_HelperProfiles`.
6. Open the HelperProfiles appearance binding interface with:

```text
RCTRL + ;
```

or with the console command:

```text
hpAppearance menu
```

7. Bind each HelperProfiles slot to the appropriate AvatarSwitcher preset.
8. Press **Bind** to stage the slot binding.
9. Press **Save** to persist the bindings for the active savegame.

The new per-savegame binding file is stored at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

AvatarSwitcher presets are stored at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

### Upgrading from older HelperProfiles beta builds

Some earlier HelperProfiles beta builds may have stored appearance bindings globally at:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/appearanceLinks.xml
```

Current beta builds store bindings per savegame:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

HelperProfiles includes migration support for the older global `appearanceLinks.xml` file. When a savegame is loaded, the mod should migrate the old binding file into the active savegame-specific folder.

Recommended steps:

1. Back up your existing `modSettings/FS25_HelperProfiles` folder.
2. Install the current HelperProfiles beta.
3. Load your savegame.
4. Open the appearance binding interface with `RCTRL + ;` or:

```text
hpAppearance menu
```

5. Confirm your bindings are present.
6. Press **Save** in the binding interface.

### AvatarSwitcher dependency

HelperProfiles does not have a hard dependency on AvatarSwitcher for its core features.

These features work without AvatarSwitcher:

- Worker cycling.
- HelperProfiles mode switching.
- Overlay toggle.
- Console/debug tools.

AvatarSwitcher is required for custom appearance bindings, because HelperProfiles reads AvatarSwitcher presets from:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

and stores per-savegame bindings in:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

### Default keybinds

```text
;           Cycle workers
SHIFT + ;   Toggle HelperProfiles mode
RCTRL + ;   Open appearance binding interface
RALT + ;    Toggle overlay
```

If the defaults do not appear after upgrading, Farming Simulator may be preserving older local keybind overrides. Reset or manually reassign the HelperProfiles controls in the game controls menu.

---

## Main Features

### Helper Overlay

The overlay can show:

- Activated helpers.
- Current selected helper.
- Next helper that will be hired.
- `FREE` / `IN USE` worker status.
- Current helper hiring mode.

The overlay supports configurable:

- Position.
- Anchor.
- Scale.
- Width.
- Font size.
- Row spacing.
- Padding.
- Opacity.
- Background visibility.
- Marker visibility.
- Base HUD binding.

### Helper Hiring Modes

HelperProfiles supports two runtime hiring modes:

#### `preferSelected`

Default mode.

The mod attempts to hire the currently selected helper if that helper is free. If the selected helper is unavailable, it falls back to the next available helper.

#### `firstFree`

The mod always hires the first available helper in list order.

This behaves closer to a simple deterministic helper allocation mode.

---

## AvatarSwitcher Binding Interface

The new binding interface allows you to assign AvatarSwitcher appearances to HelperProfiles binding slots without relying on console commands.

From the interface, you can:

- Select a binding slot.
- Select an AvatarSwitcher category.
- Select an appearance from that category.
- Bind the selected appearance to the selected slot.
- Save the binding.
- Clear the selected binding.
- Clear all bindings.
- Close the interface when finished.

The UI displays readable preset names/descriptions. The underlying preset ID is used internally when applying the appearance.

### Binding Workflow

1. Open the HelperProfiles binding interface in-game.
2. Select the helper binding slot you want to configure.
3. Choose an AvatarSwitcher category.
4. Choose an appearance from the filtered appearance dropdown.
5. Click **Bind** to stage the binding.
6. Confirm the slot shows as `[BOUND]`.
7. Click **Save** to persist the binding for the current savegame.

### Clearing Bindings

Use:

- **Clear** to remove the selected slot binding.
- **Clear All** to remove every binding for the current savegame.

After clearing, click **Save** to persist the unbound state for the current savegame.

### Tested Binding Behaviour

The following behaviour has been tested successfully:

- Two separate workers running in parallel with different appearances.
- Switching into the cab of active workers while maintaining the correct helper appearance.
- Mouse-driven category and appearance selection.
- Category filtering.
- Saving bindings to the active savegame.
- Clearing individual bindings.
- Clearing all bindings.
- Dropdowns no longer allowing click-through to controls behind them.
- Modal dialogs no longer allowing mouse clicks to pass through.
- HelperProfiles UI text input no longer affecting the wardrobe screen behind it.

---

## Keybinds

Keybinds can be assigned under:

```text
Options → Controls → Helper Profiles
```

Default bindings:

| Action | Default Binding | Description |
|---|---:|---|
| HP: Cycle workers | `;` | Cycles the selected HelperProfiles worker slot. |
| HP: Toggle mode | `SHIFT + ;` | Switches between helper hiring modes. |
| HP: Open appearance bindings | `RCTRL + ;` | Opens the binding interface to bind AvatarSwitcher appearances to AI worker slots. |
| HP: Toggle overlay | `RALT + ;` | Shows or hides the HelperProfiles overlay. |

Helper selection cycling hooks the game action used by the base helper menu and includes internal debounce handling. Plain `;` cycling is suppressed when Shift, Ctrl, or Alt is held so the modifier bindings can work separately.

If another mod already uses the same keybind, assign a different key in the FS25 controls menu.

---

## Console Commands

Open the in-game console and use the commands below.

Arguments in `<angle brackets>` are required. Arguments in `[square brackets]` are optional.

---

### Overlay Visibility and Placement

| Command | Description |
|---|---|
| `hpOverlay on` | Show the overlay. |
| `hpOverlay off` | Hide the overlay. |
| `hpOverlay toggle` | Toggle overlay visibility. |
| `hpOverlay pos <x 0..1> <y 0..1>` | Set overlay position using normalized screen coordinates. |
| `hpOverlay anchor TL\|TR\|BL\|BR` | Set the overlay anchor corner. |

---

### Overlay Sizing and Style

| Command | Description |
|---|---|
| `hpOverlay scale <0.5..2.0>` | Set overlay scale. |
| `hpOverlay width <0.15..0.90>` | Set overlay width. |
| `hpOverlay font <0.010..0.030>` | Set font size. |
| `hpOverlay rowgap <0.001..0.03>` | Set row spacing. |
| `hpOverlay maxrows <3..30>` | Set maximum visible rows. |
| `hpOverlay pad <0..0.05>` | Set overlay padding. |
| `hpOverlay opacity <0..1>` | Set background opacity. |
| `hpOverlay bg on\|off` | Toggle overlay background. |
| `hpOverlay outline on\|off` | Toggle overlay outline. |
| `hpOverlay markers on\|off` | Toggle selected/next helper markers. |
| `hpOverlay bindhud on\|off` | Make overlay follow base HUD visibility. |

---

### Input Behaviour

| Command | Description |
|---|---|
| `hpOverlay debounce <ms>` | Adjust helper cycling debounce time. Increase this if selection double-advances. |

---

### Config Commands

Config is stored in:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/config.xml
```

| Command | Description |
|---|---|
| `hpOverlay save [filename]` | Save overlay config to `config.xml` or a named XML file. |
| `hpOverlay load [filename]` | Load overlay config from `config.xml` or a named XML file. |
| `hpOverlay reset` | Reset overlay config to defaults and save. |

---

### Helper Selection Commands

| Command | Description |
|---|---|
| `hpSelect <index>` | Select helper by index. |
| `hpCycle [delta]` | Cycle helper selection. Defaults to `1`. Use a negative value to cycle backwards. |
| `hpNext` | Select the next helper. |
| `hpDump` | Dump helper state to the log/console for debugging. |

---

### Helper Hiring Mode Commands

| Command | Description |
|---|---|
| `hpMode status` | Show current helper hiring mode. |
| `hpMode firstFree` | Always hire the first available helper in list order. |
| `hpMode preferSelected` | Prefer the selected helper if free, otherwise use the next free helper. |

Default mode is:

```text
preferSelected
```

---

### Appearance Binding Commands

| Command | Description |
|---|---|
| `hpAppearance menu` | Open the appearance binding interface. |
| `hpAppearance status` | Print appearance binding status to the log/console. |
| `hpAppearance refresh` | Refresh active worker appearances from saved bindings. |

---

### Version Command

| Command | Description |
|---|---|
| `hpVersion` | Print mod/script version details to the log/console. Useful for support reports. |

---

## Config File Example

Default path:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/config.xml
```

Example:

```xml
<hp version="1">
  <ui anchor="TR" x="0.985" y="0.900" scale="1.0" width="0.19"
      opacity="0.85" pad="0.006" rowGap="0.006" font="0.014" maxRows="10"
      bg="true" outline="false" shadow="false" markers="true" bindHud="true" />
</hp>
```

You can edit this file by hand or use the `hpOverlay save`, `hpOverlay load`, and `hpOverlay reset` console commands.

---

## Troubleshooting

### Overlay is not visible

If `bindhud` is enabled, the overlay only appears when the base game HUD is visible.

Try:

```text
hpOverlay bindhud off
hpOverlay on
```

### Keybind is not firing

Check that the keybind is assigned under:

```text
Options → Controls → Helper Profiles
```

Also check for conflicts with other mods using the same key.

### Helper selection skips or double-advances

Increase the debounce value:

```text
hpOverlay debounce 220
```

If needed, try a higher value such as:

```text
hpOverlay debounce 300
```

### AvatarSwitcher categories or appearances are missing

Check that:

- FS25_AvatarSwitcher is installed and enabled for the savegame.
- AvatarSwitcher has generated or loaded `avatarPresets.xml`.
- At least one AvatarSwitcher preset has been saved.
- The preset entries have valid IDs, categories, and descriptions/names.
- The savegame has both mods enabled.

### Appearance binding does not apply as expected

Check:

- The helper slot has a saved binding.
- The selected AvatarSwitcher preset ID still exists.
- The helper is being hired through normal helper flow.
- No other helper/avatar mod is overriding the same behaviour.

For support, include:

- FS25 log excerpt.
- HelperProfiles version.
- AvatarSwitcher version.
- Savegame number.
- Steps to reproduce.
- Screenshots of the binding UI if relevant.

---

## Beta Notes

This release should be treated as a beta.

Known risk areas:

- UI scaling across different resolutions and aspect ratios.
- Mod conflicts with other UI or helper-related mods.
- AvatarSwitcher preset collections with unusual or missing category/name data.
- Savegame-specific edge cases.

Recommended practice:

- Test on copied savegames first.
- Keep a backup of important saves.
- Report errors with the FS25 log attached.

---

## Packaging Checklist

Before publishing a release ZIP:

- Confirm `modDesc.xml` version is updated.
- Confirm script header version/build tag is updated.
- Confirm the ZIP is named `FS25_HelperProfiles.zip` or another valid FS25 mod name.
- Confirm the internal mod folder/file structure is not nested incorrectly.
- Confirm there are no temporary logs, backups, or test files in the ZIP.
- Confirm `icon.dds` is present and referenced correctly in `modDesc.xml`.
- Confirm screenshots are added to the GitHub release or README.
- Mark the GitHub release as **Pre-release** for beta builds.

---

## Suggested GitHub Release Details

### Tag

```text
v2.0.19-beta
```

### Release Title

```text
FS25_HelperProfiles v2.0.19-beta – AvatarSwitcher Binding GUI
```

### Short Release Summary

```text
This beta adds the new HelperProfiles binding interface for assigning AvatarSwitcher appearances to helper slots, along with the existing helper overlay, hiring mode controls, and console/debug tools.
```

---

## Contributing

Pull requests are welcome.

When contributing, please update this README if you add or change:

- Console commands.
- Config keys.
- Keybinds.
- UI behaviour.
- AvatarSwitcher integration behaviour.
- Savegame binding behaviour.

---

## Disclaimer

This is an unofficial Farming Simulator 25 mod and is not affiliated with or endorsed by GIANTS Software.

