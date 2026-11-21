"""Build a Kazumi package with locally built, same-architecture enhancement binaries.

The script only accepts existing native build outputs. It never downloads or
runs a third-party installer. Run it on the OS supported by Flutter's target.
"""
import argparse
import json
import os
import platform
from pathlib import Path
import shlex
import shutil
import struct
import subprocess
import tempfile

from verify_enhanced_apk import BRIDGE_MARKERS, MODEL_ASSETS, MPV_FILTER_MARKERS, verify_model_asset, verify_enhanced_apk

ROOT = Path(__file__).resolve().parents[2]
NDK_ABIS = {"arm64": "arm64-v8a", "arm": "armeabi-v7a", "x64": "x86_64"}


def binary(path, expected, android, arch, *, contains=None):
    if path.name != expected or not path.is_file():
        raise ValueError(f"Expected {expected}: {path}")
    with path.open("rb") as f:
        header = f.read(64)
        if len(header) != 64:
            raise ValueError(f"Truncated header: {path}")
        if android and header.startswith(b"\x7fELF") and header[5] == 1:
            machine, = struct.unpack_from("<H", header, 18)
            elf_class = {"arm": 1, "arm64": 2, "x64": 2}[arch]
            valid = header[4] == elf_class and machine == {"arm": 40, "arm64": 183, "x64": 62}[arch]
        elif not android and header.startswith(b"MZ"):
            f.seek(struct.unpack_from("<I", header, 60)[0])
            pe = f.read(6)
            valid = len(pe) == 6 and pe[:4] == b"PE\x00\x00" and \
                struct.unpack_from("<H", pe, 4)[0] == {"arm64": 0xAA64, "x64": 0x8664}[arch]
        else:
            valid = False
        if not valid:
            raise ValueError(f"Invalid {arch} binary format: {path}")
        if contains is not None:
            f.seek(0)
            # This only proves the intended build was supplied, not playback.
            data = f.read(192 * 1024 * 1024)
            markers = (contains,) if isinstance(contains, bytes) else contains
            if any(marker not in data for marker in markers):
                raise ValueError(f"Required native enhancement marker not present: {path}")
    return path.resolve()


def package(target, arch, mpv, bridge, helper, flutter, windows_deps=(), entrypoint=None, defines=()):
    android = target == "android"
    if android and arch not in NDK_ABIS:
        raise ValueError("Use arm, arm64 or x64 on Android")
    if not android:
        host = {"AMD64": "x64", "ARM64": "arm64"}.get(platform.machine().upper())
        if os.name != "nt" or arch != host:
            raise ValueError(f"Flutter 3.50 Windows builds require their host architecture ({host})")
    mpv = binary(
        mpv,
        "libmpv.so" if android else "libmpv-2.dll",
        android,
        arch,
        contains=MPV_FILTER_MARKERS,
    )
    bridge = binary(bridge, "libkazumi_rife.so" if android else "kazumi_rife.dll", android, arch,
                    contains=BRIDGE_MARKERS)
    dependencies = []
    if windows_deps:
        if android:
            raise ValueError("Windows dependencies are only valid for Windows")
        reserved = {mpv.name.casefold(), bridge.name.casefold(), "flutter_windows.dll", "ech_http.dll",
                    "media_kit_event_loop.dll"}
        for library in windows_deps:
            name = library.name.casefold()
            if not name.endswith(".dll") or name in reserved or name.endswith("_plugin.dll"):
                raise ValueError(f"Invalid or duplicate runtime dependency: {library}")
            dependencies.append(binary(library, library.name, False, arch))
            reserved.add(name)
    if any(value.partition("=")[0] == "KAZUMI_RIFE" for value in defines):
        raise ValueError("The build wrapper sets KAZUMI_RIFE itself")
    if android:
        if helper is None:
            raise ValueError("Android also requires its matching upstream libmediakitandroidhelper.so")
        helper = binary(helper, "libmediakitandroidhelper.so", True, arch)

    # media_kit only reads this user-define from the consuming pubspec. Restore
    # it byte-for-byte on every exit; the source dependency revision is unchanged.
    spec = ROOT / "pubspec.yaml"
    original = spec.read_bytes()
    if any(line.startswith(b"hooks:") for line in original.splitlines()):
        raise ValueError("The checkout already has build hook settings; merge the local media_kit config manually")
    with tempfile.TemporaryDirectory(prefix="kazumi-enhanced-") as tmp:
        work = Path(tmp)
        native = work / "mpv"
        native.mkdir()
        shutil.copy2(mpv, native)
        for library in dependencies:
            shutil.copy2(library, native)
        env = dict(os.environ)
        if android:
            shutil.copy2(helper, native)
            jni = work / "jni" / NDK_ABIS[arch]
            jni.mkdir(parents=True)
            shutil.copy2(bridge, jni)
            env["KAZUMI_RIFE_JNI_DIR"] = str(jni.parent)
        else:
            env["KAZUMI_RIFE_DLL"] = str(bridge)
        define = ('\nhooks:\n  user_defines:\n    media_kit:\n'
                  '      source: local\n      library-directory: ' + json.dumps(native.as_posix(), ensure_ascii=False) + '\n')
        args = [flutter, "build", "apk" if android else "windows", "--release", "--dart-define=KAZUMI_RIFE=true"]
        if entrypoint is not None:
            args.extend(["--target", str(entrypoint)])
        args.extend(f"--dart-define={value}" for value in defines)
        if android:
            args += ["--target-platform", f"android-{arch}", "--split-per-abi"]
        try:
            spec.write_bytes(original.rstrip() + b"\n" + define.encode("utf-8"))
            print(shlex.join(args), flush=True)
            subprocess.run(args, cwd=ROOT, env=env, check=True)
            if android:
                artifact = ROOT / "build/app/outputs/flutter-apk" / f"app-{NDK_ABIS[arch]}-release.apk"
                native_members = verify_enhanced_apk(artifact, NDK_ABIS[arch])
                print(f"Verified {len(native_members)} native libraries in {artifact.name}", flush=True)
            else:
                artifact = ROOT / "build/windows" / arch / "runner/Release"
                folder = artifact / 'data/flutter_assets/assets/models'
                files = {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
                if files != MODEL_ASSETS.keys():
                    raise ValueError(f'Unexpected bundled models: {sorted(files ^ MODEL_ASSETS.keys())}')
                for name in MODEL_ASSETS:
                    verify_model_asset(name, (folder / name).read_bytes())
                for name in (mpv.name, bridge.name, *(lib.name for lib in dependencies)):
                    if not (artifact / name).is_file():
                        raise RuntimeError(f"{artifact} does not contain {name}")
            print(f"Enhanced package: {artifact}", flush=True)
        finally:
            spec.write_bytes(original)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=["windows", "android"])
    parser.add_argument("arch", choices=["arm", "arm64", "x64"])
    parser.add_argument("--mpv", type=Path, required=True)
    parser.add_argument("--bridge", type=Path, required=True)
    parser.add_argument("--android-helper", type=Path)
    parser.add_argument("--flutter", default=shutil.which("flutter") or "flutter")
    parser.add_argument("--windows-dependency", type=Path, action="append", default=[],
                        help="Additional import DLL from a custom mpv build; repeat as needed")
    parser.add_argument("--target", dest="target_entrypoint", type=Path, help="Alternate Flutter entrypoint for smoke testing")
    parser.add_argument("--dart-define", action="append", default=[])
    args = parser.parse_args()
    package(args.target, args.arch, args.mpv, args.bridge, args.android_helper, args.flutter,
            args.windows_dependency, args.target_entrypoint, args.dart_define)


if __name__ == "__main__":
    main()
