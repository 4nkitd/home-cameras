# Home Cameras for Android TV and phones

Shared Flutter code for the TV and phone APKs, with optional local recording and detection.

## Current build

See [RELEASE.md](RELEASE.md) for the APK, checksum, signing identity and verification limits. This is a release-mode test APK, not a production-certified camera viewer.

## Features implemented

- Compact TV home bar, four/six camera layouts, favourites and paging.
- Native-backed RTSP playback using media_kit, muted substreams in the grid, main-stream fullscreen and optional fullscreen audio.
- Only visible feeds create players. Grid feeds unmount for fullscreen and are suspended during connection setup.
- Manual main/substream RTSP addresses with separate username/password fields.
- ONVIF WS-Discovery over local IPv4 interfaces, account authentication, stream-profile selection and NVR channel selection.
- Connection preview, camera naming/areas, editing, reordering and removal.
- Whole-camera configuration encrypted via flutter_secure_storage. Credentials are not stored in ordinary preferences, exports or app logs. Backups/device transfers of application data are disabled.
- Bounded retries, lifecycle release/reconnect, keep-awake preference and D-pad navigation.
- Android TV launcher icon/banner, landscape orientation and no touchscreen requirement.
- Phone portrait layout, touch controls and normal launcher support.
- Optional offline NVR, bundled person/animal detection, rolling clip storage,
  playback and export. See [RECORDING_GUIDE.md](RECORDING_GUIDE.md).

## Build

Flutter 3.47.2 / Dart 3.13.2, Java 17 and Android SDK 36 were used for this build. `pubspec.lock` pins the resolved dependencies.

```sh
ANDROID_NDK_HOME=/path/to/android-ndk-r27d bash native/build.sh
flutter pub get
flutter analyze
flutter test --concurrency=2
flutter build apk --release --flavor tv
flutter build apk --release --flavor mobile
```

The native build runs on Linux. The matching release's native-source bundle also
contains `jniLibs/`, which can be copied into `android/app/src/main/jniLibs/`.
For ABI-specific packages, add `--split-per-abi` to the flavored Flutter build.

The development signing key must be preserved if future test APKs should update the installed app without uninstalling it. Release signing is deliberately not set up yet. Do not put keystores in the public artifact directory.

## Tests

`test/` covers URI validation, credential encoding, encrypted-payload serialization, storage-failure behaviour, write concurrency, ONVIF response parsing, discovery host boundaries, TV layouts and keyboard navigation. All 27 tests passed after the 0.1.2 onboarding fixes. Coverage includes all four arrow keys, Enter/numpad Enter, username/password focus movement and IME actions, contrasting primary-button focus, delayed first frames, interruption/recovery, stale events and retaining onboarding fields/Save. Media health tests use controlled futures/timers; the onboarding widget test injects a preview instead of exercising a physical decoder.

`integration_test/app_test.dart` covers the older viewer/ONVIF fixture flow.
`integration_test/nvr_test.dart` exercises local RTSP, inference, recording and
playback. The fixture services use deliberately non-secret test credentials.
The NVR emulator run was interrupted at Boss's request for manual testing and
publication. No complete end-to-end pass is claimed. See [RELEASE.md](RELEASE.md)
for the current verification record.

Boss requested the APK for physical TV testing. Real camera discovery, playback, hardware decoding and sustained performance remain unverified. Start with one H.264 camera, then two and four substreams.

See [PERFORMANCE.md](PERFORMANCE.md) for performance constraints and acceptance tests; see [THIRD_PARTY.md](THIRD_PARTY.md) before any public/commercial distribution.
