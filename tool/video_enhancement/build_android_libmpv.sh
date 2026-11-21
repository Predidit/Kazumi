#!/usr/bin/env bash
# Build the upstream LGPL Android bundle with the in-player neural video filters.
# Requires Linux host, Bash, Python, Git, Meson/Ninja, NDK r30 and native
# bootstrap tools described in native/video_interpolation/README.md.
set -euo pipefail

if (($# != 3)); then
    echo 'Usage: build_android_libmpv.sh <arm64-v8a|armeabi-v7a|x86_64> <NDK directory> <new output directory>' >&2
    exit 64
fi
abi=$1
case "$abi" in
    arm64-v8a) arch=arm64 ;;
    armeabi-v7a) arch=armv7l ;;
    x86_64) arch=x86_64 ;;
    *) printf 'Unsupported Android ABI: %s\n' "$abi" >&2; exit 64 ;;
esac
ndk=$(realpath -e -- "$2")
grep -q 'Pkg.Revision = 30.0.16248370' "$ndk/source.properties"
mkdir -- "$3"
out=$(realpath -e -- "$3")
repo=$(cd -- "$(dirname -- "$0")/../.." && pwd)
work="$out/native-build"
builder_pin=0443048272a511d7a990a2a3d5ca6bbaf55a869a

checkout() {
    local directory=$1 url=$2 pin=$3
    git init -q "$directory"
    git -C "$directory" remote add origin "$url"
    git -C "$directory" fetch --no-tags --depth=1 origin "$pin"
    git -C "$directory" checkout -q --detach FETCH_HEAD
    [[ $(git -C "$directory" rev-parse HEAD) == "$pin" ]]
}
checkout "$work" https://github.com/Predidit/libmpv-android-video-build.git "$builder_pin"
python3 "$repo/tool/video_enhancement/configure_native_builder.py" android "$work"
cd "$work/buildscripts"
mkdir -p sdk/android-sdk-linux/ndk deps
ln -s -- "$ndk" sdk/android-sdk-linux/ndk/30.0.16248370

# Pin all sources with the original builder's commit list, using their GitHub
# mirrors where available. The unused GPL encoder dependencies are not needed.
# shellcheck source=/dev/null
export ENCODERS_GPL=
source include/depinfo.sh
checkout deps/mbedtls https://github.com/Mbed-TLS/mbedtls.git "$sha_mbedtls"
git -C deps/mbedtls submodule update --init --recursive --depth 1
checkout deps/dav1d https://github.com/videolan/dav1d.git "$sha_dav1d"
checkout deps/libxml2 https://github.com/GNOME/libxml2.git "$sha_libxml2"
checkout deps/ffmpeg https://github.com/FFmpeg/FFmpeg.git "$v_ffmpeg"
checkout deps/freetype https://github.com/freetype/freetype.git "$sha_freetype"
checkout deps/fribidi https://github.com/fribidi/fribidi.git "$sha_fribidi"
checkout deps/harfbuzz https://github.com/harfbuzz/harfbuzz.git "$sha_harfbuzz"
checkout deps/libass https://github.com/libass/libass.git "$sha_libass"
checkout deps/lcms2 https://github.com/mm2/Little-CMS.git "$sha_lcms2"
checkout deps/libplacebo https://github.com/haasn/libplacebo.git "$v_libplacebo"
git -C deps/libplacebo submodule update --init --recursive --depth 1
checkout deps/mpv https://github.com/mpv-player/mpv.git "$v_mpv"
mkdir deps/shaderc

for folder in patches/*; do
    [[ -d "$folder" ]] || continue
    dep=$(basename -- "$folder")
    [[ -d "deps/$dep" ]] || continue
    for patch in "$folder"/*.patch; do
        git -C "deps/$dep" apply "$PWD/$patch"
    done
done
cp flavors/default.sh scripts/ffmpeg.sh
# Avoid privilege escalation; all files are in this process's new build dir.
sed -i -e 's/\bsudo chmod/chmod/' build.sh
cores=${KAZUMI_NATIVE_JOBS:-6} ./build.sh --arch "$arch"
install -m 755 -- "prefix/$abi/lib/libmpv.so" "$out/libmpv.so"
printf 'Patched Android %s libmpv: %s/libmpv.so\n' "$abi" "$out"
