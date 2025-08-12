# FS25 Helper Profiles

**Farming Simulator 25 mod** that lets you cycle between available AI helpers and automatically hire your preferred one when pressing `H`.

![Mod Icon](helper_profiles.png)

---

## ✨ Features

* **Cycle Helpers:** Press `;` (semicolon) to cycle through all available AI helpers, on foot or in a vehicle.
* **Preferred Hiring:** When you hire a worker, the mod picks your currently selected free helper first.
* **Basegame Compatibility:** Reads helper data directly from the game’s **`map_helpers.xml`** file — no custom helper definitions included.
* **HUD Feedback:** Displays the selected helper’s name briefly at the top of the screen when cycling.

---

## 🧑‍🌾 Customising AI Workers

This mod **does not** currently add new helpers itself.
To use custom names, appearances, or more helpers than the basegame provides, you must edit the `maps_helpers.xml` file:

1. Locate the XML file in your FS25 installation, i.e., "C:\Program Files (x86)\Farming Simulator 2025\data\maps".
2. Make a copy of the base maps_helpers.xml
3. Open `maps_helpers.xml` in a text editor.
4. Add or modify `<helper>` entries as desired.
5. Save the file and restart the game.

> ⚠️ **Note:** Always back up the original `map_helpers.xml` before editing. Customisations will apply to all saves using that map.

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

## 🎮 Controls

| Action       | Keybinding (default) | Description                      |
| ------------ | -------------------- | -------------------------------- |
| Cycle Helper | `;`                  | Cycle through available helpers. |

---

## 📖 Usage

1. The Cycle Helper action will only present workers that are currently available (not already hired or busy).
2. If no helpers are free when you cycle, the HUD will show “No helpers available.”
3. When hiring a worker with H, the game will use the currently selected free helper, if one is available; otherwise, it will fall back to the game’s standard selection logic.

---

## ⚙️ Installation

1. Download the latest release `.zip` from the [Releases](../../releases) page.
2. Place the `.zip` file into your `Documents/My Games/FarmingSimulator2025/mods` folder.
3. Enable **Helper Profiles** in the in-game Mod Manager.

---

## 🛠 Compatibility

* Tested with **Farming Simulator 25** base game helpers.
* Designed to be compatible with **AutoDrive** and **Courseplay** (preferred helper logic applies before those mods take over control).
* Works in **single-player** and **multiplayer** sessions.

---

## 📜 Changelog

**v1.0.0**

* Initial release: Helper cycling, preferred helper hire, HUD feedback.

---

## 📄 License

This mod is released under the [MIT License](LICENSE).
You are free to use, modify, and distribute it, but attribution is appreciated.

---

Do you want me to also include a **sample `map_helpers.xml` snippet** in the README so users can see exactly how to add custom workers without breaking the game? That could prevent a lot of support questions.
