Here’s a GitHub-ready migration document you can add as something like:

```text
docs/MIGRATION.md
```

# Migration Guide

This document explains how to move from older HelperProfiles workflows to the current `FS25_HelperProfiles` beta builds that use per-savegame bindings and optional `FS25_AvatarSwitcher` integration.

## Summary

Older versions of HelperProfiles, and some early custom worker workflows, required direct editing or replacement of basegame helper XML files.

Current versions no longer require basegame XML edits.

The current workflow is:

1. Create or manage appearances in `FS25_AvatarSwitcher`.
2. Open the HelperProfiles appearance binding interface.
3. Bind a helper slot to an AvatarSwitcher preset.
4. Save the bindings per savegame.

HelperProfiles remains usable without AvatarSwitcher for worker cycling, helper mode switching, and overlay features. AvatarSwitcher is only required for custom worker appearance presets.

---

## Current Storage Locations

### HelperProfiles bindings

Current per-savegame appearance bindings are stored under:

```text
modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

Where `savegameX` matches the active Farming Simulator save slot.

Example:

```text
modSettings/FS25_HelperProfiles/saves/savegame1/appearanceLinks.xml
```

### AvatarSwitcher presets

AvatarSwitcher presets are stored under:

```text
modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

HelperProfiles reads these presets and allows them to be bound to helper slots.

---

## Migration Scenarios

## 1. New User

No migration is required.

Install:

```text
FS25_HelperProfiles.zip
```

Optional, for custom worker appearances:

```text
FS25_AvatarSwitcher.zip
```

Then use the in-game controls:

```text
;           Cycle workers
SHIFT + ;   Toggle HelperProfiles mode
RCTRL + ;   Open appearance binding interface
RALT + ;    Toggle overlay
```

If your local controls have already been customized in Farming Simulator, you may need to reset or reassign the HelperProfiles bindings in the game controls menu.

---

## 2. Existing HelperProfiles User Using Older modSettings Bindings

Some earlier HelperProfiles builds stored appearance bindings globally at:

```text
modSettings/FS25_HelperProfiles/appearanceLinks.xml
```

Current beta builds use per-savegame storage instead:

```text
modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

The mod includes migration support for this older HelperProfiles binding file.

When the savegame loads, HelperProfiles should detect the old global binding file and migrate it into the active savegame-specific folder.

### Recommended steps

1. Back up your existing `modSettings/FS25_HelperProfiles` folder.
2. Install the current HelperProfiles beta.
3. Load your savegame.
4. Open the appearance binding interface with:

```text
RCTRL + ;
```

or console command:

```text
hpAppearance menu
```

5. Confirm your bindings are present.
6. Press **Save** in the binding interface.

After confirming everything works, the new active file should be:

```text
modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

---

## 3. User of the Original Basegame XML Editing Workflow

Early custom worker workflows may have required direct editing or replacement of basegame helper profile XML files.

For example, users may have edited files inside the game install directory or unpacked game data in order to change helper appearances directly.

This workflow is now deprecated.

The current HelperProfiles beta does **not** automatically import custom helper definitions from edited basegame XML files.

### Important

Before using the current HelperProfiles + AvatarSwitcher workflow, restore the original basegame helper XML files.

Do not continue using edited basegame helper XML files alongside the current binding system.

### Recommended migration path

1. Back up any edited helper XML files you previously used.
2. Restore the original basegame helper XML files.
3. Install `FS25_AvatarSwitcher`.
4. Recreate your custom worker appearances as AvatarSwitcher presets.
5. Install the current `FS25_HelperProfiles` beta.
6. Open the HelperProfiles appearance binding interface.
7. Bind each helper slot to the appropriate AvatarSwitcher preset.
8. Save the bindings.

This avoids modifying basegame files and allows bindings to be managed safely per savegame.

---

## Why Basegame XML Editing Is No Longer Recommended

Direct basegame XML editing has several disadvantages:

* It can be overwritten by game updates.
* It may affect every savegame.
* It can conflict with other mods.
* It makes troubleshooting difficult.
* It can produce inconsistent results if the game has already built its internal helper profile data.
* It is not portable for normal mod distribution.

The current system avoids these issues by using:

```text
modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

for appearance presets, and:

```text
modSettings/FS25_HelperProfiles/saves/savegameX/appearanceLinks.xml
```

for per-savegame helper bindings.

---

## Manual Migration from Edited Basegame XML

Automatic import from old edited basegame XML files is not currently supported.

If you have custom helper appearances from an older setup, migrate them manually as follows:

1. Open your old edited helper XML file.
2. Identify each custom helper appearance you want to keep.
3. Recreate that appearance in AvatarSwitcher.
4. Save it with a clear category and description.

Suggested category names:

```text
legacy
legacy_helpers
my_farm
savegame1
```

Suggested preset descriptions:

```text
Legacy Helper - Anna
Legacy Helper - Farmhand 01
Witcombe Park - Rhys
Judith Plains - Riley
```

Then open HelperProfiles and bind those presets to helper slots.

---

## Recommended Backup Before Migrating

Before migrating, back up:

```text
modSettings/FS25_HelperProfiles
modSettings/FS25_AvatarSwitcher
```

If you previously edited basegame XML files, also back up those edited files before restoring the originals.

Suggested backup folder:

```text
FS25_HelperProfiles_Migration_Backup
```

---

## Troubleshooting

### The appearance binding interface opens but shows no appearances

Check that AvatarSwitcher is installed and has saved presets.

Expected file:

```text
modSettings/FS25_AvatarSwitcher/avatarPresets.xml
```

If this file does not exist, create and save at least one AvatarSwitcher preset first.

---

### HelperProfiles works, but custom worker appearances do not

HelperProfiles can run without AvatarSwitcher, but custom appearance binding requires AvatarSwitcher presets.

Install AvatarSwitcher, create presets, then bind them through HelperProfiles.

---

### The old worker names still appear after unbinding

Open the appearance binding interface, select the affected slot, press **Clear**, then press **Save**.

The slot should return to an unbound state.

---

### Keybinds do not match the defaults

Farming Simulator may preserve local keybind overrides from earlier mod versions.

Default bindings are:

```text
;           Cycle workers
SHIFT + ;   Toggle HelperProfiles mode
RCTRL + ;   Open appearance binding interface
RALT + ;    Toggle overlay
```

If these do not work, reset or manually reassign the HelperProfiles controls in the Farming Simulator controls menu.

---

## Current Limitation

The current beta does not automatically convert edited basegame helper XML entries into AvatarSwitcher presets.

Users coming from the original basegame XML-editing workflow should recreate their custom appearances in AvatarSwitcher and then bind them using HelperProfiles.

A future migration/import helper may be added if a safe and consistent import path is identified.

---

## Recommended Release Note

For users upgrading from very early versions:

> If you previously edited or replaced basegame helper XML files, restore the original game files before using this version. Custom worker appearances should now be recreated as AvatarSwitcher presets and bound through the HelperProfiles appearance binding interface. Direct basegame XML editing is no longer required or recommended.

I’d link this from the README under a short **Migration** section, especially because the old basegame XML workflow is exactly the kind of thing that can trip people up silently.
