# Home Cameras: design reference 01

Status: HTML design approved by Boss, including the compact home header. Flutter implementation is in `tv_app/`; its first device-test APK is available. This HTML reference still uses simulations and does not access cameras or store real credentials.

## Approved direction

Dark Apple Home / Apple TV-inspired interface for a 55-inch Android TV, four equal cameras by default, compact top navigation, live viewing and camera management only. Home Cameras is the working name. Design approval precedes Flutter implementation.

## Tokens and layout plan

- Background: charcoal green `#191d1c`.
- Raised surfaces: eucalyptus charcoal `#282e2b`.
- Primary text and focus: chalk `#f5f6f2`.
- Secondary text: fog `#b4bdb7`.
- Connected state: sage `#a7c4ae`.
- Warning state: amber `#e9bc7a`.
- Typography: the platform system sans stack, with Helvetica Neue fallback. 40px page headings, 24px camera names, 18px controls at a desktop reference width. No Apple font or icon assets are distributed.
- Home uses a single 104px topbar: brand and connection count, primary navigation, camera-view selector, Layout, Add camera and clock. The separate page title and filter row are removed. A four-tile grid occupies the remaining space. Other screens retain their original headers. Setup is a right-hand sheet over the grid, with generous form controls and an explicit Back action.

```
Home Cameras      Live view | Cameras | Settings     All cameras ▾   Layout   Add camera   Clock
4 of 4 connected

┌─────────────────────────┐  ┌─────────────────────────┐
│                         │  │                         │
│ Front door              │  │ Driveway                │
└─────────────────────────┘  └─────────────────────────┘
┌─────────────────────────┐  ┌─────────────────────────┐
│                         │  │                         │
│ Garden                  │  │ Living room             │
└─────────────────────────┘  └─────────────────────────┘

Remote hints                              Local network, sample footage
------------------- separate prototype review toolbar ----------------
```

## Brief review

This is an appliance interface, not a SaaS dashboard. Omit analytics cards, activity charts, marketing headlines, a persistent sidebar and features not requested. Rounded tiles are justified by the Apple Home brief. Footage, not decorative gradients, is the distinguishing visual. Only setup/review sheets blur their backdrop. Use real sample photographs downloaded locally, explicitly labelled as stills. White focus rings must stay visible independently of color and network status.

## Screen map

1. Live view: four-camera grid, six-slot alternative, favourites filter, empty home, offline camera, lost network, reconnecting.
2. Fullscreen: selected camera, mute/audio concept, quality menu, offline/retry, restore focused tile on return.
3. Add camera: choose automatic/manual, network permission explanation, scanning, device results, no results, credentials, manual URL, connection test, wrong credentials, unreachable camera, preview/name/room, success.
4. Manage cameras: list, edit metadata/connection fields, reorder with buttons usable by a remote, removal confirmation, empty list.
5. Settings: layout, stream preference, keep-awake preference, grid muted, local-only explanation.
6. Review index: direct links to each screen and failure state, fresh demo reset, first-launch walkthrough, explicit simulation outcome controls.

## Interaction and simulation

Arrow keys move spatial focus. Enter activates controls or submits a form. Escape returns one step or closes a sheet. Tab remains available. Text input retains left/right caret control. Dialogs trap focus; background controls are inert. Focus returns to the selected tile after fullscreen or to the invoking control after a modal.

The compact home uses a native All cameras / Favourites selector with native browser keyboard behaviour. At narrower tablet widths, Layout/Add labels collapse to accessible icon buttons. Phone review widths wrap the home controls; standard TV widths keep them on a single row. At 1920×1080 the grid starts at 104px instead of approximately 340px, giving roughly 40% more tile area with unchanged horizontal spacing.

The review toolbar and simulated outcome selector are prototype-only, not Android TV UI. Scanning and connection checks are scripted timers with no network calls. No camera usernames or passwords are persisted. Non-secret demo names, layout and preferences may be stored in this browser. Never enter real credentials. "Audio on" and quality selection only demonstrate UI state; sample images are not streams. All imagery is local so the prototype works without a camera or image CDN after download.

## Handoff boundaries

The eventual Flutter implementation must separately validate actual TV decoder capacity, RTSP and ONVIF compatibility, Android local-network permissions, secure credential storage, wake/sleep recovery and D-pad/IME behaviour on hardware. HTML behaviour does not prove those capabilities. App launch opens the saved grid; TV boot auto-launch and stock launcher integration are not included.

## Run

From this directory: `python3 -m http.server 4173 --bind 127.0.0.1`, then open `http://127.0.0.1:4173`. The page also works as a local file, but browser storage behaviour may vary.

See `assets/SOURCES.md` for photo sources. See `VERIFICATION.md` for tests performed before handoff.
