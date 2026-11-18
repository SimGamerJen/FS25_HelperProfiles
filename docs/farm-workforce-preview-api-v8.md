# HelperProfiles API v8 — optional local portrait style

This document applies only to `design/farm-workforce-integration`, **not** the released HelperProfiles 2.1.2.0 build.

New optional call:

```lua
local style, reason = g_currentMission.helperProfilesAPI:createPreviewPlayerStyle("A")
```

The method normalises an A–T slot, resolves its actual helper and asks the existing `HP_ASBridge:createPlayerStyleForHelper` to construct a temporary PlayerStyle from the assigned AvatarSwitcher preset. It does **not** mutate the helper, change the selected slot, save settings, hire staff or expose live helper userdata.

A missing/invalid preset returns `nil` and a diagnostic reason. The GUI consumer must treat portrait rendering as optional and continue displaying the worker's name and appearance label if style construction or rendering is unavailable.

Existing API v7 methods and consumers remain unchanged. Only the integration branch advertises `apiVersion=8` and `supportsPreviewPlayerStyle=true`. A client must check for the method before calling it. This is a local visual interface and is not an MP/network contract.

Paired integration test: use both HelperProfiles and HelperPayroll `design/farm-workforce-integration` ZIPs, on a copied FS25 save. See HelperPayroll's `docs/farm-workforce-portrait-prototype.md` for the GUI test procedure.
