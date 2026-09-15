# Home Cameras

Local-network IP camera viewer for Android TV. Dark Apple Home–inspired UI, multi-camera grid by default, manual RTSP setup with username/password, and ONVIF discovery on the same LAN.

**Status:** device-test Flutter app at `0.1.2`. UI is approved. Target-TV validation is still in progress. Performance is a primary design constraint.

## What's in this repo

| Path | Purpose |
| --- | --- |
| `tv_app/` | Flutter Android TV application |
| `index.html`, `styles.css`, `app.js` | Clickable HTML design reference (simulated cameras) |
| `DESIGN.md` | Design tokens, flows, and Flutter handoff notes |
| `VERIFICATION.md` | HTML prototype verification record |
| `tests/`, `verification/` | HTML prototype browser checks and screenshots |

APKs are **not** stored in git. Build them from `tv_app/`.

## Flutter app (`tv_app/`)

### Features

- Compact TV home bar, 4- or 6-camera layouts, favourites, paging
- RTSP playback via media_kit (hardware decode when the device supports it)
- Grid uses substreams and mutes audio; fullscreen uses the main stream
- Only visible feeds create players; grid unmounts for fullscreen and setup
- Manual RTSP + separate username/password fields
- ONVIF WS-Discovery, profile/stream selection (including NVR channels)
- Connection preview, naming, edit/reorder/remove
- Camera config encrypted with `flutter_secure_storage`
- D-pad navigation, keep-awake preference, Android TV leanback launcher

### Build

Requires Flutter **3.47+** / Dart **3.13+**, Java 17, Android SDK 36.

```sh
cd tv_app
flutter pub get
flutter analyze
flutter test --concurrency=2
flutter build apk --release
```

ABI splits:

```sh
flutter build apk --release --split-per-abi
```

Package id: `in.dagar.home_cameras` · min SDK 24 · target 36.

See:

- [`tv_app/README.md`](tv_app/README.md) — app overview
- [`tv_app/RELEASE.md`](tv_app/RELEASE.md) — release notes and verification limits
- [`tv_app/PERFORMANCE.md`](tv_app/PERFORMANCE.md) — performance rules and TV acceptance tests
- [`tv_app/THIRD_PARTY.md`](tv_app/THIRD_PARTY.md) — native mpv/FFmpeg and dependency notes
- [`tv_app/CHANGELOG.md`](tv_app/CHANGELOG.md) — version history

### Install on a TV

1. Copy the release APK to the TV (USB, LocalSend, etc.).
2. Install via a file manager; allow “install unknown apps” for that app if prompted.
3. Open **Home Cameras** from the apps row.
4. Start with **one** H.264 camera, then scale to 2–4 grid streams.

Development builds use a debug signing key. Preserve the same keystore for in-place updates, or uninstall before installing a differently signed APK (that wipes local camera data).

## HTML design prototype

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Open http://127.0.0.1:4173

Arrow keys navigate, Enter selects, Escape goes back. **All screens** opens the full screen index. Feeds are sample stills; discovery and connection checks are simulated. Do not enter real camera credentials in the prototype.

```sh
node --check app.js
# with the local server running:
node tests/smoke.mjs
```

## Security notes

- Credentials live only in encrypted app storage on the TV.
- Discovery rejects endpoints that don’t match the responding host (SSRF guard).
- App backup/device-transfer of app data is disabled in the manifest.
- Most local RTSP streams are unencrypted; use a trusted LAN.
- Never commit keystores, `key.properties`, or real camera passwords.

## License

Application source in this repository is provided for private/device-test use unless otherwise stated. Native playback libraries (mpv, FFmpeg and dependencies) have their own licenses — see `tv_app/THIRD_PARTY.md` before public or commercial distribution.
