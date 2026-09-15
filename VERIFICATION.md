# Verification

Date: 2026-09-15. HTML design reference 01.

## Executed checks

- `node --check app.js`: passed.
- `node tests/smoke.mjs`: 14 test groups passed on the latest compact-header run. Raw results: `verification/results.json`.
- Home controls remain on one row without overlap at widths 1920, 1440, 1280, 1024 and 768. The camera grid starts within 112px of the top at the tested TV viewports. The All cameras / Favourites selector filters and preserves focus.
- Four-camera home fully fits 1440×900, 1920×1080 and 1280×720 viewports without horizontal or vertical overflow.
- All 28 screen-index destinations render at both 1440px and 390px widths without horizontal overflow, including inside dialog content.
- D-pad-style arrows move from front door to driveway to living room; Enter opens the selected camera and Escape restores the same camera's focus.
- Automatic discovery walkthrough: permission explanation, simulated scan, device selection, missing-credential validation, sample login, preview/name/area, favourite, save and persistent camera metadata.
- Manual entry rejects non-RTSP URLs and credentials embedded in URLs; accepts a valid anonymous RTSP URL.
- Wrong-password and unreachable-camera outcomes render and recover through edited simulation outcomes.
- Cancelling scanning prevents its delayed result from replacing the next screen.
- Edit preserves typed names across favourite toggles; reorder, removal cancellation and removal work.
- Six-slot layout, empty slots, display preference persistence, quality selection and audio-state feedback work.
- Network-loss and camera-offline fixtures recover through their simulated retry actions.
- Dialog Tab trapping, text-field caret navigation, modal focus visibility and focus return from empty camera slots work.
- No JavaScript errors or HTTP resource failures were observed in the test browser. No external network requests were made by the prototype.
- Persisted metadata excludes username, password, stream address and sample password values.

## Visual inspection

Opened the app with agent-browser and inspected captured screenshots of the home grid, add-camera sheet, preview form, settings and mobile manual setup. Adjusted the grid to fit the viewport instead of allowing its second row to fall below the fold. Compacted preview fields and made modal focus scroll into view.

Screenshots in `verification/` include home at three desktop sizes, fullscreen, discovery, preview, wrong password, management, settings, screen index and mobile views.

## /review workflow

An independent code review covered the new HTML, CSS, application JavaScript, design notes and browser tests. Fixed:

- Missing fullscreen-camera guard before template rendering.
- Focus return to the exact empty grid slot that opened setup.
- Focused form controls becoming offscreen after rerendering a long modal.

Follow-up review reported no actionable findings. Authenticated discovery fixtures are intentional; anonymous streams are demonstrated through manual RTSP setup.

The compact-home-header revision received another /review pass with no actionable findings. Other screen designs remain unchanged as requested by Boss.

## Not verified or implemented

- Actual camera connectivity, discovery or credential authentication.
- RTSP decoding, stream count capacity, video latency or audio playback.
- Android TV D-pad, native text input, permissions or wake/sleep behaviour on hardware.
- Secure credential storage in the future Android app.
- Flutter implementation, APK packaging or TV installation.

Those checks belong to implementation after Boss approves the UI. Browser tests verify the reference interaction, not the planned Android functionality.
