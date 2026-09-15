# Home Cameras for Android TV

First device-test implementation of the approved HTML design in the parent directory.

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

## Build

Flutter 3.47.2 / Dart 3.13.2, Java 17 and Android SDK 36 were used for this build. `pubspec.lock` pins the resolved dependencies.

```sh
flutter pub get
flutter analyze
flutter test --concurrency=2
flutter build apk --release
```

For smaller ABI-specific packages: `flutter build apk --release --split-per-abi`.

The development signing key must be preserved if future test APKs should update the installed app without uninstalling it. Release signing is deliberately not set up yet. Do not put keystores in the public artifact directory.

## Tests

`test/` covers URI validation, credential encoding, encrypted-payload serialization, storage-failure behaviour, write concurrency, ONVIF response parsing, discovery host boundaries, TV layouts and keyboard navigation. All 27 tests passed after the 0.1.2 onboarding fixes. Coverage includes all four arrow keys, Enter/numpad Enter, username/password focus movement and IME actions, contrasting primary-button focus, delayed first frames, interruption/recovery, stale events and retaining onboarding fields/Save. Media health tests use controlled futures/timers; the onboarding widget test injects a preview instead of exercising a physical decoder.

`integration_test/app_test.dart` is an unfinished execution check against a synthetic RTSP source and ONVIF HTTP fixture on an Android TV emulator. The fixture services in `tool/` use deliberately non-secret test credentials. The remote VM became unresponsive during the debug integration build, so that run was interrupted. The emulator/fixture processes were stopped when the VM was restarted. **No passing integration result is claimed.**

Boss requested the APK for physical TV testing. Real camera discovery, playback, hardware decoding and sustained performance remain unverified. Start with one H.264 camera, then two and four substreams.

See [PERFORMANCE.md](PERFORMANCE.md) for performance constraints and acceptance tests; see [THIRD_PARTY.md](THIRD_PARTY.md) before any public/commercial distribution.
