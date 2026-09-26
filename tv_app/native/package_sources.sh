#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out=${1:?Pass a new bundle directory}
mkdir -p "$out/sources" "$out/recorder" "$out/jniLibs"
cp "$root/native/recorder.cpp" "$root/native/build.sh" "$out/recorder/"
cp -R "$root/android/app/src/main/jniLibs/." "$out/jniLibs/"
cp "$root/android/app/src/main/assets/FFMPEG-LICENSE.txt" "$out/recorder/"
download() {
  if [[ ! -s "$out/sources/$1" ]]; then curl -fL --retry 3 "$2" -o "$out/sources/$1"; fi
}
download ffmpeg-8.0.1.tar.xz https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz
download playback-build-v1.1.7.tar.gz https://codeload.github.com/media-kit/libmpv-android-video-build/tar.gz/refs/tags/v1.1.7
download mpv-78d43740.tar.gz https://codeload.github.com/mpv-player/mpv/tar.gz/78d43740f52db817d98bcf24fb30a76ab6fa13ff
download ffmpeg-6.0.tar.gz https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/refs/tags/n6.0
download mbedtls-3.4.0.tar.gz https://codeload.github.com/Mbed-TLS/mbedtls/tar.gz/refs/tags/v3.4.0
download dav1d-1.2.0.tar.gz https://codeload.github.com/videolan/dav1d/tar.gz/refs/tags/1.2.0
download libxml2-2.10.3.tar.gz https://codeload.github.com/GNOME/libxml2/tar.gz/refs/tags/v2.10.3
download freetype-2.13.0.tar.gz https://codeload.github.com/freetype/freetype/tar.gz/refs/tags/VER-2-13-0
download fribidi-1.0.12.tar.gz https://codeload.github.com/fribidi/fribidi/tar.gz/refs/tags/v1.0.12
download harfbuzz-7.2.0.tar.gz https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/refs/tags/7.2.0
download libass-0.17.1.tar.gz https://codeload.github.com/libass/libass/tar.gz/refs/tags/0.17.1
download android-helper-42054e5d.tar.gz https://codeload.github.com/media-kit/media-kit-android-helper/tar.gz/42054e5d479f39ccbb0ae604862e2bcaf59b74c2
cp "$root/THIRD_PARTY.md" "$out/README.md"
(cd "$out" && find sources jniLibs recorder -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar -C "$(dirname "$out")" -cJf "$out.tar.xz" "$(basename "$out")"
