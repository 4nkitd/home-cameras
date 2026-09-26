#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=${NVR_NATIVE_WORK:-"$root/build/native-recorder"}
mkdir -p "$work"
cd "$work"
if [[ ! -f ffmpeg-8.0.1.tar.xz ]]; then
  curl -fL --retry 3 https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz -o ffmpeg-8.0.1.tar.xz
fi
echo '05ee0b03119b45c0bdb4df654b96802e909e0a752f72e4fe3794f487229e5a41  ffmpeg-8.0.1.tar.xz' | sha256sum -c -
if [[ ! -d ffmpeg-8.0.1 ]]; then tar xf ffmpeg-8.0.1.tar.xz; fi
toolchain="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
for abi in ${NVR_ABIS:-x86_64 arm64-v8a armeabi-v7a}; do
  case "$abi" in
    x86_64) target=x86_64-linux-android; arch=x86_64 ;;
    arm64-v8a) target=aarch64-linux-android; arch=aarch64 ;;
    armeabi-v7a) target=armv7a-linux-androideabi; arch=arm ;;
    *) exit 2 ;;
  esac
  mkdir -p "$work/$abi" "$root/android/app/src/main/jniLibs/$abi"
  cd "$work/$abi"
  "$work/ffmpeg-8.0.1/configure" --prefix="$PWD/install" \
    --target-os=android --arch="$arch" --enable-cross-compile \
    --cc="$toolchain/${target}24-clang" --cxx="$toolchain/${target}24-clang++" \
    --ar="$toolchain/llvm-ar" --ranlib="$toolchain/llvm-ranlib" --strip="$toolchain/llvm-strip" \
    --enable-pic --enable-static --disable-shared --disable-programs --disable-doc \
    --disable-debug --disable-autodetect --disable-everything --disable-avdevice \
    --disable-avfilter --disable-swscale --disable-swresample --disable-asm \
    --enable-network --enable-demuxer=rtsp --enable-muxer=matroska \
    --enable-protocol=file,tcp,udp,rtp --enable-parser=h264,hevc \
    --enable-decoder=h264,hevc \
    --enable-bsf=extract_extradata --disable-gpl --disable-nonfree
  make -j2
  make install
  "$toolchain/${target}24-clang++" -shared -fPIC -O2 -std=c++17 -static-libstdc++ \
    -I "$PWD/install/include" "$root/native/recorder.cpp" \
    -Wl,--start-group "$PWD/install/lib/libavformat.a" "$PWD/install/lib/libavcodec.a" "$PWD/install/lib/libavutil.a" \
    -Wl,--end-group -Wl,--exclude-libs,ALL -Wl,-z,max-page-size=16384 -llog -lz -lm \
    -o "$root/android/app/src/main/jniLibs/$abi/libhome_recorder.so"
  "$toolchain/llvm-strip" --strip-unneeded "$root/android/app/src/main/jniLibs/$abi/libhome_recorder.so"
done
