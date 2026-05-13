# FS25 HelperProfiles

**FS25 HelperProfiles** is a Farming Simulator 25 helper-management mod that adds a game-styled helper overlay, configurable helper selection behaviour, console/debug tools, and an optional **AvatarSwitcher binding interface** for assigning saved appearances to helper profile slots on a per-savegame basis.

This release is intended as a **beta pre-release**.

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
   Show the selected helper, next helper, helper status, and current mode.

2. **Helper binding interface**  
   Show the binding slot selector, category selector, and appearance selector.

3. **Category dropdown open**  
   Useful for demonstrating the fixed dropdown opacity and click-capture behaviour.

4. **Appearance dropdown filtered by category**  
   Show that selecting a category filters available AvatarSwitcher appearances.

5. **Two active helpers with different appearances**  
   Best headline screenshot for the new beta.

Example Markdown placeholders:

```markdown
![HelperProfiles overlay](docs/screenshots/helperprofiles-overlay.png)
![Binding interface](docs/screenshots/helperprofiles-binding-ui.png)
![Category dropdown](docs/screenshots/helperprofiles-category-dropdown.png)
![Filtered appearances](docs/screenshots/helperprofiles-appearance-filter.png)
![Two helpers with different appearances](docs/screenshots/helperprofiles-two-workers.png)
```

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

Savegame-specific binding data is stored under the HelperProfiles modSettings structure.

---

## Compatibility

### Farming Simulator

- Built for Farming Simulator 25.
- Tested in normal gameplay with multiple active helpers.

### AvatarSwitcher

The helper appearance binding interface requires **FS25_AvatarSwitcher** and its `avatarPresets.xml` data.

HelperProfiles reads AvatarSwitcher preset data so the UI can display readable categories and appearance descriptions while using preset IDs internally.

### Savegames

Bindings are intended to be savegame-specific. Always test beta builds on a copied savegame before using them in an important save.

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
- Save the binding.
- Clear the selected binding.
- Clear all bindings.
- Confirm changes with OK.

The UI displays readable preset names/descriptions. The underlying preset ID is used internally when applying the appearance.

### Binding Workflow

1. Open the HelperProfiles binding interface in-game.
2. Select the helper binding slot you want to configure.
3. Choose an AvatarSwitcher category.
4. Choose an appearance from the filtered appearance dropdown.
5. Click **Save**.
6. Click **OK** when finished.

### Clearing Bindings

Use:

- **Clear Binding** to remove the selected slot binding.
- **Clear All Bindings** to remove every binding for the current savegame.

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

Recommended examples:

| Action | Suggested Binding | Description |
|---|---:|---|
| HP: Toggle overlay | `CTRL + ;` | Shows or hides the HelperProfiles overlay. |
| HP: Toggle mode | `SHIFT + ;` | Switches between helper hiring modes. |

Helper selection cycling still hooks the game action used by the base helper menu and includes internal debounce handling.

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

- FS25_AvatarSwitcher is installed and enabled.
- AvatarSwitcher has generated or loaded `avatarPresets.xml`.
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
v0.2.0-beta
```

### Release Title

```text
FS25_HelperProfiles v0.2.0-beta – AvatarSwitcher Binding GUI
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

