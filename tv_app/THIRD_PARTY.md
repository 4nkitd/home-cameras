# Third-party components

Device-test APKs are distributed through GitHub Releases, not Google Play.

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

## Offline detector

LiteRT 1.4.0 and EfficientDet Lite0, from the Google / TensorFlow
Authors, use the Apache 2.0 license. The license is included in APK assets as
`TENSORFLOW-LICENSE.txt`. The model is unmodified and bundled, not downloaded by
the application.

- Model: https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/object_detection/android/lite-model_efficientdet_lite0_detection_metadata_1.tflite
- SHA-256: `2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b`
- Runtime source: https://github.com/google-ai-edge/LiteRT
- Model family source: https://github.com/google/automl/tree/master/efficientdet

The detector recognizes COCO labels, not arbitrary animal species. Detection
results are fallible and are not a safety-critical alarm.

## Native recorder

The separate `libhome_recorder.so` uses FFmpeg 8.0.1, built with GPL and nonfree
components disabled. It copies H.264/H.265 video packets without re-encoding.
It uses FFmpeg under LGPL 2.1 or later. `native/recorder.cpp` and `native/build.sh`
contain the JNI wrapper and exact build configuration. FFmpeg remains a separate
shared library boundary from the Dart/Android application, although its component
archives are linked into that replaceable recorder library.

The release's native-recorder source bundle must contain the unmodified FFmpeg
source tarball, its license, wrapper, build script, and the matching compiled
libraries. Rebuild with Android NDK r27d, replace the library in an APK, then
re-sign for your device. Reverse engineering for debugging modifications to the
LGPL components is permitted. Changing signers requires a separate installation
or uninstalling the old app, so export recordings first.

## Detection test images

`integration_test/fixtures` comes from the TensorFlow Lite Support test data at
commit `522a02b47444e6016d5a0d4d1388b522bc2529f2`:
https://github.com/tensorflow/tflite-support/tree/522a02b47444e6016d5a0d4d1388b522bc2529f2/tensorflow_lite_support/cc/test/testdata/task/vision

`person.jpg` is the unmodified `segmentation_input_rotation0.jpg`.
These images are used only by the local test server and are not APK assets.
