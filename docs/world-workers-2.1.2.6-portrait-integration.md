# World Workers 2.1.2.6 + Farm Workforce portrait integration

This is the **corrected paired-test branch**. It branches from `agent/world-workers-alpha6-pedestrian-research` (HelperProfiles **2.1.2.6**), not from ModHub 2.1.2.0.

## Verified source changes
- Only `scripts/HP_IntegrationAPI.lua` differs from the 2.1.2.6 parent branch.
- Local shared API bumped from v7 to v8 to add optional `createPreviewPlayerStyle(slot)`.
- The API produces a temporary `PlayerStyle` using the existing `HP_ASBridge:createPlayerStyleForHelper`, without changing helper selection, appearance binding or saved data.
- World Workers placement, world-worker menu, movement and navigation modules remain identical to the 2.1.2.6 source branch.
- **Nothing was merged from the older 2.1.2.0 design branch.** The release branch and main remain untouched.

## Test pairing
Use this HelperProfiles branch together with HelperPayroll `design/farm-workforce-integration` (Farm Workforce portrait UI), on a copied save. Do not use the older HelperProfiles `design/farm-workforce-integration` branch for this combined test.

Test worker placement/tab and its save behaviour first, then the Team 3D portrait, and confirm switching between the two interfaces works. A GUI regression or a Lua error should be investigated before merging either branch.

The two experimental branches remain separate and independently reversible.
