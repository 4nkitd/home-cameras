# Home Cameras

Local-network IP camera viewer and optional offline NVR for Android TV and Android phones. Multi-camera live view, RTSP setup, ONVIF discovery, local recordings and bundled person/animal detection.

**Status:** `0.2.0` device-test release. NVR starts disabled. Physical-TV and phone performance depend on the device and camera configuration. See the release verification record before using it for unattended recording.

## What's in this repo

| Path | Purpose |
| --- | --- |
| `tv_app/` | Shared Flutter application with TV and phone flavors |
| `index.html`, `styles.css`, `app.js` | Clickable HTML design reference (simulated cameras) |
| `DESIGN.md` | Design tokens, flows, and Flutter handoff notes |
| `VERIFICATION.md` | HTML prototype verification record |
| `tests/`, `verification/` | HTML prototype browser checks and screenshots |

APKs are **not** stored in git. Download a release build or build from `tv_app/`.

### Latest APK

- [TV APK](https://github.com/4nkitd/home-cameras/releases/download/v0.2.0/Home-Cameras-TV-0.2.0.apk)
- [Phone APK](https://github.com/4nkitd/home-cameras/releases/download/v0.2.0/Home-Cameras-Phone-0.2.0.apk)
- [Release notes, checksums and native sources](https://github.com/4nkitd/home-cameras/releases/tag/v0.2.0)
- Previous viewer-only build: [0.1.2](https://github.com/4nkitd/home-cameras/releases/tag/v0.1.2)

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
- Portrait/touch layout on phones
- Optional foreground NVR, two cameras maximum, manual/continuous/detection-triggered video clips
- Offline person and COCO animal detection, with independent switches
- Local playback, seek, export and delete; rolling storage limit with a free-space reserve

See the [recording guide](tv_app/RECORDING_GUIDE.md) for setup and limits. Recording
supports H.264/H.265 over RTSP, without audio. Detection needs a stream at 720p or
below. Camera access requires the LAN, but neither recording nor detection needs
internet or another server. Power loss, reboot, force-stop and manufacturer sleep
can stop the NVR. Clip boundaries can have gaps; this is not a certified security
recorder.

### Build

Requires Flutter **3.47+** / Dart **3.13+**, Java 17, Android SDK 36. The native
recorder is built on Linux with Android NDK r27d. Alternatively, copy the
`jniLibs/` directory from the matching release's native-source bundle into
`tv_app/android/app/src/main/jniLibs/` after verifying its checksums.

```sh
cd tv_app
ANDROID_NDK_HOME=/path/to/android-ndk-r27d bash native/build.sh
flutter pub get
flutter analyze
flutter test --concurrency=2
flutter build apk --release --flavor tv
flutter build apk --release --flavor mobile
```

ABI splits:

```sh
flutter build apk --release --flavor tv --split-per-abi
```

TV package: `in.dagar.home_cameras`. Phone: `in.dagar.home_cameras.mobile`.
Minimum SDK 24, target 36. Release APKs contain arm64-v8a, armeabi-v7a and x86_64.

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

- Credentials live only in encrypted app storage on the device and in memory while streaming.
- Footage stays in app-private storage. It is not separately encrypted by the app. Exported copies follow the chosen destination's access rules.
- Discovery rejects endpoints that don’t match the responding host (SSRF guard).
- App backup/device-transfer of app data is disabled in the manifest.
- Most local RTSP streams are unencrypted; use a trusted LAN.
- Never commit keystores, `key.properties`, or real camera passwords.

## License

Application source in this repository is provided for private/device-test use unless otherwise stated. Native playback libraries (mpv, FFmpeg and dependencies) have their own licenses — see `tv_app/THIRD_PARTY.md` before public or commercial distribution.
