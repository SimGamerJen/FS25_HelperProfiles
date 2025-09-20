# FS25 HelperProfiles — Overlay & Debug

An FS25-styled on-screen overlay for HelperProfiles that shows **activated workers**, your **current selection**, and the **next helper** the game will hire. Includes a robust **console/debug** layer, a **keybind** for toggling, optional **HUD binding** (hides with base HUD / HideHUD mods), and a persistent **config.xml** in `modSettings/FS25_HelperProfiles`.

![new_overlay1](https://github.com/user-attachments/assets/6d1c2285-44e2-4e3f-bc2e-218013ad2109)
![new_overlay2](https://github.com/user-attachments/assets/11fa87b0-c210-47f1-92b3-1927a2c17e6c)


---

## Installation

1. Download `FS25_HelperProfiles.zip`.
2. Drop it into your FS25 mods folder (no unpacking):

```
Documents/My Games/FarmingSimulator2025/mods
```

3. Launch the game → **ModHub → Installed** → enable **FS25 HelperProfiles**.

That’s it. The mod will auto-create:

```
Documents/My Games/FarmingSimulator2025/modSettings/FS25_HelperProfiles/config.xml
```

…after first run (when you use `save` or on initial defaults).

---

## Features

* FS25-style overlay panel (position/size/spacing/opacity configurable).
* Shows:

  * **Selected** helper (`» sel`)
  * **Next** helper the system would hire (`← next`)
  * `FREE / IN USE` status per worker
* Debounced cycling so selection advances cleanly.
* Toggle overlay via **console** or **keybind**.
* **Bind to base HUD** (optional) so it hides with HUD/HideHUD.
* **External config** in `modSettings/FS25_HelperProfiles/config.xml` with `save`, `load`, and `reset`.

---

## Keybinds

* **HP: Toggle overlay** → bind under **Options → Controls → MISC** (e.g., `CTRL+;`).
  Works with modifiers; handler supports analog action values.

> Helper selection cycling still hooks game action **OPEN\_HELPER\_MENU** (same behavior as base), with internal debounce.

---

## Console / Debug Commands

Open the in-game console and use:

> All commands start with `hpOverlay`. Args in `<>` are required; `[]` optional.

### Visibility & Placement

* `hpOverlay on` / `off` / `toggle`
* `hpOverlay pos <x 0..1> <y 0..1>`
* `hpOverlay anchor TL|TR|BL|BR`

### Sizing & Style

* `hpOverlay scale <0.5..2.0>`
* `hpOverlay width <0.15..0.90>`
* `hpOverlay font <0.010..0.030>`
* `hpOverlay rowgap <0.001..0.03>`
* `hpOverlay maxrows <3..30>`
* `hpOverlay pad <0..0.05>`
* `hpOverlay opacity <0..1>`
* `hpOverlay bg on|off`
* `hpOverlay outline on|off`
* `hpOverlay markers on|off`
* `hpOverlay bindhud on|off`  *(follow base HUD visibility)*

### Input Behavior

* `hpOverlay debounce <ms>`  *(raise if you ever see double-advance)*

### Config (stored in `modSettings/FS25_HelperProfiles`)

* `hpOverlay save [filename]`  → saves to `config.xml` (or `filename.xml`)
* `hpOverlay load [filename]`  → loads `config.xml` (or `filename.xml`)
* `hpOverlay reset`            → resets to defaults and saves

### Helper Selection Shortcuts

* `hpSelect <index>`
* `hpCycle [delta]`      *(default 1; negative to go backwards)*
* `hpNext`
* `hpDump`

---

## Config File

Default path:

```
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

You can edit by hand or use the `save`, `load`, and `reset` commands.

---

## Tips & Troubleshooting

* **Overlay not visible?**
  If `bindhud` is **on**, the overlay only shows when the base HUD is visible; toggle the HUD back on, or run `hpOverlay bindhud off`.
* **Keybind not firing?**
  Make sure **HP: Toggle overlay** is bound under **MISC**. The handler works with modifiers like CTRL/SHIFT.
* **Skip on cycle?**
  Increase debounce: `hpOverlay debounce 220`.

---

## Contributing

* PRs welcome—if you add or change commands/config keys, please update the README accordingly.
