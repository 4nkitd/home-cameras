# Home Cameras 0.2.0+4

Experimental TV and phone NVR release, 2026-09-26.

Boss requested publication and will perform manual device testing. This release
is a test build, not a claim that both device versions have passed end-to-end
recording validation.

- Release: https://github.com/4nkitd/home-cameras/releases/tag/v0.2.0
- TV: `Home-Cameras-TV-0.2.0.apk`, package `in.dagar.home_cameras`.
- Phone: `Home-Cameras-Phone-0.2.0.apk`, package `in.dagar.home_cameras.mobile`.
- Both are release-mode, development-signed universal APKs for Android 7.0+.
- The TV package and existing development signing identity are preserved.
- `SHA256SUMS.txt` accompanies the APKs on the release page.
- `Home-Cameras-Native-Sources-0.2.0.tar.xz` includes the native recorder libraries,
  corresponding FFmpeg source, playback dependency sources, licenses and recipes.

## New functionality

- Phone portrait/touch layout and normal Android launcher support.
- Optional NVR under Settings, disabled initially, with up to two configured cameras.
- Off, manual, continuous and detection-triggered recording modes per camera.
- Independent local person and animal detection using a bundled EfficientDet model.
- H.264/H.265 RTSP video copied into local Matroska clips without re-encoding.
- Rolling internal-storage archive, playback/seek, Android document-picker export,
  and explicit clip deletion.
- Background foreground-service ownership, notification Stop and a master disable switch.

## Verification boundary

- 39 unit/widget tests passed, including settings defaults, codec-map transfer,
  class switches, storage retention/reserve, interrupted metadata recovery,
  notification-stop persistence, RTSPS validation and 360px phone layouts.
- Static analysis passed. Independent `/review` completed; the final targeted
  review reported no release-blocking findings.
- A TV debug APK installed/launched on an Android TV API 36 emulator. The partial
  integration run reached local recording and produced a finalized MKV file.
- **The full emulator integration suite did not complete.** It was stopped when
  Boss took over manual testing and requested publication. Recorded-file playback,
  event-triggered recording, background reliability, final-release installation
  and both physical-device variants still require manual verification.
- No phone-emulator end-to-end pass is claimed. Phone UI checks are widget tests.

## Limits to test first

- Recording supports ordinary RTSP with H.264/H.265, not RTSPS or other codecs.
  Audio is not recorded. Detection needs a 1280×720-or-smaller stream.
- Clips reconnect at segment boundaries and can have gaps. No pre-event buffer.
- Force-stop, reboot, loss of power or manufacturer sleep can stop the NVR.
  Reopen the app after reboot. There is no automatic boot start.
- Detection is fallible and supports only the listed COCO animal classes.
- Footage uses app-private storage and is not separately encrypted by the app.
  Rolling cleanup deletes oldest completed clips. Export important footage.

Follow [RECORDING_GUIDE.md](RECORDING_GUIDE.md). Start with one camera. Check a
short manual recording and playback, then continuous recording, detection,
background behavior and the master Stop switch before relying on the app.

---

# Home Cameras 0.1.2+3

Onboarding, playback-state and focus fixes, 2026-09-15.

- GitHub release: https://github.com/4nkitd/home-cameras/releases/tag/v0.1.2
- APK: https://github.com/4nkitd/home-cameras/releases/download/v0.1.2/Home-Cameras-0.1.2.apk
- Local copy (dev machine only): `../releases/Home-Cameras-0.1.2.apk`

- Up/Down moves between username/password fields; Left/Right still edits text. IME Next/Done actions advance focus.
- White primary buttons use a contrasting blue 3px focus border.
- A late first frame can clear a timed-out preview and unlock setup. Recoverable decoder/audio error-log messages do not fail a usable video feed.
- Once a camera preview has validated, a later interruption does not hide the fields or Save button. Interrupted received images carry a stale-image warning rather than a full-screen cover.
- All 27 unit/widget tests pass; analysis and /review complete. Tests exercise controlled frame futures and an injected preview, not a physical camera.
- Universal release-mode device-test APK, approximately 97 MB, Android 7.0+, version code 3. Same app ID, signer and storage schema as the previous builds.
- Signature verified and the complete HTTPS download matched the build artifact checksum. Target-TV confirmation is pending.

APK SHA-256:

```text
e800f8dad0b2d5f6d10ed26205547f6f024f5787858bfc6ea2bc94c2187bbc8c
```

## Previous 0.1.1+2 build

Remote-control hotfix, 2026-09-15.

Download: https://tambourine-blunder.exe.xyz/Home-Cameras-0.1.1.apk

Local copy: `../releases/Home-Cameras-0.1.1.apk`.

- Restores Flutter's default arrow, Enter/numpad Enter and Tab bindings. Select/controller A remain supported.
- All 17 unit/widget tests pass; static analysis and /review complete.
- Universal release build, approximately 97 MB, Android 7.0+.
- Version code 2. Same application ID and signer as 0.1.0. Install as an update without uninstalling.
- APK signature verified and full HTTPS download checksum matched.
- Physical TV remote behaviour still awaits Boss's confirmation. Playback/discovery/performance verification limits below remain unchanged.

APK SHA-256:

```text
fcde5e4fa8ff5ef053606439201553a4d43d6eef1ad598c941c80d9eae6f8da2
```

## Original 0.1.0+1 build

Date: 2026-09-15.

## Download

https://tambourine-blunder.exe.xyz/Home-Cameras-0.1.0.apk

Local copy: `../releases/Home-Cameras-0.1.0.apk`.

- Approximately 97 MB / 92.4 MiB.
- Universal APK: armeabi-v7a, arm64-v8a and x86_64.
- Application ID: `in.dagar.home_cameras`.
- Packaged minimum API: 24 / Android 7.0.
- Target/compile API: 36.
- Version code: 1.
- Release-mode optimization; signed with an Android development key.

SHA-256:

```text
2667d8b4bdec6d1c298dec6687a3038aae5e47668f7a5586d0df8b28e076c1e7
```

Signer certificate SHA-256:

```text
83738b5af63b78ce38555e33d32977adb33545bf417dde70b66d08aaed8f9eff
```

## Verified

- `flutter analyze`: no issues.
- `flutter test --concurrency=2`: all 15 unit/widget tests pass.
- `flutter build apk --release`: successful universal APK build from the updated source.
- `apksigner verify --print-certs`: signature verification passes.
- `aapt dump badging`: package, ABI, SDK and Leanback launcher declarations inspected.
- Full APK downloaded through the HTTPS link above; SHA-256 matches the server artifact.
- /review code audit completed; URI port-zero handling and compact TV layout fixes are covered by passing tests. The local Gradle minimum SDK line mirrors the Flutter tool's build-time normalization to `flutter.minSdkVersion`.

## Not yet verified

- Installation/launch on Boss's TV.
- Real-camera RTSP authentication, visible video and audio.
- Physical LAN ONVIF discovery or camera/NVR profile interoperability.
- Hardware decoder selection, latency, sustained memory use or multi-camera performance on the TV.

The Android TV emulator integration run did not complete. Its remote test VM became unresponsive during the debug build. After restarting that temporary VM, a universal release APK was rebuilt and recovered. Boss explicitly requested this device-test handoff instead of waiting for emulator testing.

## First TV test

1. Transfer the APK with USB or Send Files to TV and install it through a file manager. Allow installation from that file manager when Android asks.
2. Open Home Cameras from the TV's apps row.
3. Try one camera first. Use discovery or enter its RTSP address and a read-only local account. A lower-resolution H.264 substream is recommended for the grid.
4. Check fullscreen, Back and remote navigation. Then add two and four cameras and check responsiveness.
5. Report the TV model/Android version, camera/NVR model and the exact screen where anything fails. Do not include camera passwords in screenshots or ordinary logs.

The build VM is retained temporarily to serve this download and support the first device-test iteration. Only `/home/exedev/downloads` is exposed over HTTPS; source, build logs and signing keys are not in that directory.
