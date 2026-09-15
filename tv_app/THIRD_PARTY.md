# Third-party components

This is a private device-test build. The application is not published to Google Play or offered as a public release.

## Direct components

- Flutter SDK 3.47.2: https://github.com/flutter/flutter/tree/3.47.2
- media_kit 1.2.6 and media_kit_video 2.0.1: https://github.com/media-kit/media-kit
- media_kit_libs_video 1.0.7, resolving Android video libraries 1.3.8 through the committed pubspec.lock.
- easy_onvif 3.1.5: https://github.com/faithoflifedev/easy_onvif_workspace
- flutter_secure_storage 11.1.1: https://github.com/juliansteenbakker/flutter_secure_storage
- shared_preferences 2.5.5: https://github.com/flutter/packages/tree/main/packages/shared_preferences
- dio, loggy and xml: versions and dependency graph are recorded in pubspec.lock.

Flutter's generated license registry is accessible through Settings → About & open-source licenses.

## Native playback

The Android plugin downloads the `default` flavor of the following native artifacts:

https://github.com/media-kit/libmpv-android-video-build/releases/tag/v1.1.7

The build recipes and patches are in:

https://github.com/media-kit/libmpv-android-video-build/tree/v1.1.7

These libraries include mpv and FFmpeg plus their enabled dependencies. The Dart wrapper's MIT license is not a blanket license for every native component. The build repository distinguishes default/full and encoders-gpl flavors. This application does not add FFmpegKit, libVLC or GPL encoder packages.

Before public or commercial distribution, audit the exact native build flags, component licenses, corresponding source/relinking obligations and codec patent requirements. Preserve the native source version and checksums along with the APK. Do not infer that the complete APK is MIT-licensed from the Flutter package alone.

## Test-only tools

MediaMTX and the host FFmpeg executable generate local synthetic test streams. `tool/onvif_fixture.py` serves a local ONVIF response fixture. They run only in the disposable build/test environment; they are not bundled into the APK. Test usernames/passwords in those fixtures are deliberately non-secret and must never be used for real cameras.

The HTML prototype's Unsplash photographs are not bundled into the Android app.
