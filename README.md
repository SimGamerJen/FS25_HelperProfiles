# Helper Profiles (FS25\_HelperProfiles)

**Version:** `1.0.0.1` · **Game:** Farming Simulator 25 · **Multiplayer:** Supported

A lightweight, safe-hook helper selector for FS25. It lets you **cycle which AI helper will be hired next** and gently overrides the base game so that when you hire a helper, the game **prefers your selected free helper**.

> This build focuses on the *safe, minimal* workflow: cycle → hire. Persistent names/appearances and deeper profile features are planned but not enabled yet.

---

## ✨ What it does (today)

* Adds a **Cycle Helper** action (default: **semicolon `;`**) that cycles through available AI helpers.
* When you hire (**H** by default), the mod tries to assign **your selected free helper**. If they’re busy, it falls back to the **next free** one; if none are free, it lets the game pick.
* Works **on foot and in vehicles**; registers the action in both contexts.
* Shows a small HUD toast (top area) like `Helper: Alex (3/12)` while cycling.
* Writes helpful log lines (see below) so you can verify it’s hooked correctly.

> **Safety-first:** No edits to base XMLs, no hard overrides to helper tables, no appearance changes. Hooks are stored and original functions are called as fallbacks.

---

## 🕹️ Controls

| Action       | Default         | Rebind In-Game                                                  |
| ------------ | --------------- | --------------------------------------------------------------- |
| Cycle Helper | `semicolon (;)` | *Options → Controls* (look for **Cycle Helper** under this mod) |

The underlying input is `OPEN_HELPER_MENU`; the on-screen label is **Cycle Helper**.

---

## 🔧 Installation

1. Drop `FS25_HelperProfiles.zip` into your FS25 `mods` folder.
2. Enable **Helper Profiles** on your savegame.
3. Load your map. You should see a brief toast: *“Press ; to cycle helper”*.
4. Press `;` to cycle; press `H` to hire. Watch the log to confirm the hook (optional).

**Folder layout inside the ZIP:**

```
helperprofiles.dds
helper_profiles.dds
modDesc.xml
Overview.txt
Profile_Settings.md
maps_helpers.xml
scripts/
scripts/HelperProfiles.lua
scripts/RegisterPlayerActionEvents.lua
```

---

## 🧠 How it works (under the hood)

On first load, the mod safely wraps several `HelperManager` methods and remembers the originals:

* `getNextHelper` → prefers your selected free helper
* `getFreeHelper`
* `getRandomHelper`
* `hireHelper` → logs which helper the vehicle received

If your selected helper is busy, it checks the rest of the list for the next free one. If none are free, it defers to the original function.

The cycle key is registered in both player and vehicle contexts so the control always works.

---

## 🧾 Expected log lines (for troubleshooting)

You’ll see lines like these in `log.txt` when the mod hooks correctly:

```
[FS25_HelperProfiles] ✅ Registered OPEN_HELPER_MENU in context _playerActionEventId
[FS25_HelperProfiles] ✅ Registered OPEN_HELPER_MENU in context _vehicleActionEventId
[FS25_HelperProfiles] Hooked HelperManager.getNextHelper
[FS25_HelperProfiles] Hooked HelperManager.getFreeHelper
[FS25_HelperProfiles] Hooked HelperManager.getRandomHelper
[FS25_HelperProfiles] Hooked HelperManager.hireHelper
[FS25_HelperProfiles] Selected helper: Alex
[FS25_HelperProfiles] getNextHelper -> 'Alex' (selected)
[FS25_HelperProfiles] hireHelper -> vehicle got 'Alex' (idx 5)
```

If you don’t see the “Hooked …” lines, ensure the mod is enabled, that you don’t have duplicate ZIPs/folders, and check for conflicts (see below).

---

## Example

        <helper name="Riley" color="1 0 0">
            <playerStyle filename="dataS/character/playerM/playerM.xml">
				<bottom color="5" name="jeans"/>
				<face color="1" name="head01"/>
				<top color="5" name="denimJacket"/>
				<footwear color="1" name="workBoots2"/>
				<hairStyle color="6" name="hair12"/>
				<beard color="5" name="stubble_head01"/>
            </playerStyle>
        </helper>
        <helper name="Jed" color="1 0 0">
            <playerStyle filename="dataS/character/playerM/playerM.xml">
            <bottom color="5" name="jeans"/>
            <face color="1" name="head02"/>
            <top color="3" name="leather"/>
            <headgear color="5" name="cowboy"/>
            <footwear color="1" name="riding"/>
            <hairStyle color="23" name="hair09"/>
            <beard color="23" name="stubble_head02"/>
            </playerStyle>
        </helper>
        <helper name="Rick" color="0 1 0">
            <playerStyle filename="dataS/character/playerM/playerM.xml">
            <bottom color="8" name="cargo"/>
            <face color="1" name="head02"/>
            <top color="24" name="topPlaidShirt"/>
            <glasses color="1" name="classic"/>
            <footwear color="1" name="workBoots2"/>
            <hairStyle color="24" name="hair12"/>
            <beard color="24" name="fullBeard_head02"/>
            </playerStyle>
        </helper>

---

## 🔄 Compatibility notes

* Designed to be **non-destructive** and play nicely with other mods.
* If another mod *directly replaces* `HelperManager` methods, the **last mod to hook** usually wins. In that case, helper preference logic may not run.
* Should be fine alongside Courseplay/AutoDrive; there are no hard dependencies and this mod only biases which helper is chosen.

---

## 🛣️ Roadmap

* **Persistent Profiles**: names, avatars/appearances, and per-helper preferences.
* **Config file** under `modSettings/FS25_HelperProfiles` (e.g., `helpers.xml`).
* Optional integration points for **Courseplay** and **AutoDrive**.
* Small in-game **picker UI** for faster selection.

See `Profile_Settings.md` in this repository for the appearance options draft (not active in this build).

---

## ❓FAQ

**Q: Can I change the hotkey?**
Yes — *Options → Controls* and search for **Cycle Helper**.

**Q: Does this change helper wages or behaviour?**
No. It only influences **which** helper is chosen at hire time.

**Q: Does it edit my savegame or the base game?**
No. It’s runtime-only hooks and toasts; remove the mod and the behaviour reverts.

---

## 🧩 Contributing

Issues and PRs welcome! If you’re reporting a bug, please include:

* FS25 version, mod version (`1.0.0.1`)
* A copy/paste of the relevant `log.txt` section (look for `[FS25_HelperProfiles]` lines)
* A list of other helper/AI mods you’re using

---

## 📜 License & Credits

* **Author:** SimGamerJen (HelperProfiles project)
* **License:** See repository `LICENSE` (TBD). If omitted, assume all rights reserved.
* Thanks to the FS modding community for input and testing.

---

## 🧱 Repository layout

```
/FS25_HelperProfiles
├── modDesc.xml
├── scripts/
│   ├── HelperProfiles.lua
│   └── RegisterPlayerActionEvents.lua
├── helperprofiles.dds
├── helper_profiles.dds
├── Profile_Settings.md         ← appearance legend (draft; not yet active)
|── Overview.txt                ← planning notes
└── maps_helpers.xml			← example custom maps_helpers.xml file
```

---
