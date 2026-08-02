# Helper roster manager test notes

This feature is under active Alpha testing.

## Performance gate

- Compare normal gameplay FPS with HelperProfiles 2.0.27.3 beta and the current 2.1.0.0 roster branch under the same savegame, location, camera and overlay state.
- Confirm the current branch no longer causes the severe FPS loss reported in the earlier 2.1.0.0 alpha build.
- Test once with the HelperProfiles overlay visible and once with it hidden.
- Do not continue functional approval testing if the performance regression remains.

## Core checks

- Open the roster manager from the appearance screen.
- Confirm the button bar shows ESC Close, X Appearances, C Toggle ON/OFF, A Disable Others, and Enter Save when all workers are rostered.
- Use Disable Others and confirm the selected worker and any active workers remain ON roster.
- Confirm the A action changes to Enable All after workers have been switched OFF.
- Confirm ON ROSTER and OFF ROSTER render without missing-localisation messages.
- Switch inactive workers OFF, save, and confirm they disappear from the overlay and semicolon cycling.
- Confirm OFF workers remain visible in the roster manager and retain appearance and payroll metadata.
- Confirm an active worker cannot be switched OFF.
- Confirm at least one worker must remain ON.
- Save, reload the savegame, and confirm roster state persists.
- Re-enable a worker and confirm its prior appearance and payroll role are restored.
