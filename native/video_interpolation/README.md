# DistilDRBA frame interpolation

The Windows and Android enhanced packages add the `kazumi-drba` mpv filter. It estimates motion on decoded frames before CuNNy renders them. The filter and its ncnn inference library use ABI 4. The library retains its `kazumi_rife` filename for platform packaging.

`assets/models/distildrba-v2-lite` contains the ncnn export of `v2_lite.pkl`. To reproduce it, run `python native/video_interpolation/export_distildrba.py PATH/TO/v2_lite.pkl assets/models/distildrba-v2-lite`. The player verifies the bundled files against their SHA-256 digests before use. `warp/` contains the warp operator and shader generator adapted for ncnn 20261020. The license notices are in `licenses/rife`. [DistilDRBA checkpoint](https://github.com/routineLife1/DistilDRBA/tree/db51bdeb452685cba9aee227c6dba42e67753b55) · [Warp operator](https://github.com/nihui/rife-ncnn-vulkan/tree/a7532fc3f9f8f008cd6eecd6f2ffe2a9698e0cf7/src)

## 1. Build the bridge

Use the Vulkan-enabled ncnn SDK for the target architecture. The Android workflow pins its archive digest. On Windows x64 the SHA-256 of `ncnn-20261020-windows-vs2022.zip` is `ef9fe4463e5db0f41484ad25e91686e709b91e400858639aed631c280dfa91d4`.

```powershell
cmake -S native/video_interpolation -B build/neural-win -A x64 `
  -DKAZUMI_BUILD_NEURAL=ON -Dncnn_DIR=C:/work/ncnn-20261020-windows-vs2022/x64/lib/cmake/ncnn
cmake --build build/neural-win --config Release
```

```sh
cmake -S native/video_interpolation -B build/neural-android -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DKAZUMI_BUILD_NEURAL=ON \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_STL=c++_static \
  -Dncnn_DIR=/work/ncnn-20261020-android-vulkan/arm64-v8a/lib/cmake/ncnn
cmake --build build/neural-android --target kazumi_rife --parallel 4
```

## 2. Build matching libmpv with the filter

For a manually configured source build, run
`python native/video_interpolation/patch_mpv.py /absolute/work/mpv` before
Meson setup. To reproduce the upstream binary configuration without reverting
Kazumi's native render support, apply the equivalent patch to its builder:

| Platform | Pinned builder | mpv source |
| --- | --- | --- |
| Windows | `Predidit/libmpv-win32-video-cmake@b5bb494f49f0cea9d46c613cdea81a696eaa2939` | `bcde6b93cca4d128d84e1a60d1a6db2cd81c889e` (includes upstream D3D11 render API) |
| Android | `Predidit/libmpv-android-video-build@0443048272a511d7a990a2a3d5ca6bbaf55a869a` | `c3ac7f39514c7f45bc38a18e66887240539ee33c` |

1. Checkout the appropriate pinned builder in a separate clean build directory.
2. Run `python tool/video_enhancement/configure_native_builder.py windows /path/to/builder` (or `android`). The Windows step runs after upstream mpv patches, before Meson configure. The Android step runs from the upstream mpv checkout before Meson setup.
3. Follow the pinned builder's `.github/workflows/mpv_clang.yml` (Windows) or `.github/workflows/build.yaml` (Android) toolchain and build steps in a compatible environment. Use the default Android (LGPL) flavor. Collect `mpv-dev/libmpv-2.dll` on Windows, or `libmpv.so` and `libmediakitandroidhelper.so` for the desired Android ABI from the builder. An already published stock libmpv will **not** recognize `kazumi-drba`.

For Android, `tool/video_enhancement/build_android_libmpv.sh` automates the
source-build steps for one ABI, without requiring a full SDK or running the
upstream packaging script as root. On Ubuntu, install `build-essential`,
`git`, `python3`, `python3-jinja2`, `python3-jsonschema`, `cmake`, `meson`,
`ninja-build`, `pkg-config`, `autoconf`, `automake`, `libtool`, `gettext`,
`texinfo`, `gperf`, `nasm` and `unzip`. The output directory must not exist.

```sh
bash tool/video_enhancement/build_android_libmpv.sh arm64-v8a \
  "$ANDROID_NDK_HOME" /absolute/work/mpv-arm64
```

For the helper, use the matching ABI `libmediakitandroidhelper.so` from the
same upstream Android v1.3.1 JAR identified in media-kit's locked
`hook/native_bundles.json` (verify its SHA-256), or reproduce that helper
from the pinned upstream builder. Do not reuse its stock `libmpv.so`.
The matching archive can also be verified/extracted by
`python tool/video_enhancement/fetch_android_helper.py arm64-v8a /work/arm64-v8a`.
The workflow `.github/workflows/video-enhancement.yaml` automates the Android
source build and the packaging steps on `workflow_dispatch`; it is separate
from upstream releases.

## 3. Package the enhanced app

Use JDK 21 to run Android Gradle and release lint. Android bytecode still targets Java 17.

```powershell
python tool/video_enhancement/build_enhanced_flutter.py windows x64 `
  --mpv C:/work/mpv-dev/libmpv-2.dll --bridge build/neural-win/Release/kazumi_rife.dll
```

```sh
python tool/video_enhancement/build_enhanced_flutter.py android arm64 \
  --mpv /work/arm64-v8a/libmpv.so --android-helper /work/arm64-v8a/libmediakitandroidhelper.so \
  --bridge build/neural-android/libkazumi_rife.so
```

The wrapper uses media-kit's documented `source: local` build-hook settings
and `--dart-define=KAZUMI_RIFE=true`, then checks that the installed runner or
APK actually contains the libraries. It restores `pubspec.yaml` after the
build. Run on a clean build checkout; do not run two wrapper processes in the
same checkout.

## Verify playback

With the enhanced player, open a progressive SDR clip, select an interpolation tier and toggle CuNNy separately. Disabling interpolation restores the configured decoder. The packaged weights and the runtime markers can also be checked directly on Android:

```sh
python tool/video_enhancement/verify_enhanced_apk.py app-arm64-v8a-release.apk arm64-v8a
```
