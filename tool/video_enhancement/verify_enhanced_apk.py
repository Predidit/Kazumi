"""Audit the actual APK members, rather than assuming Gradle staged the right libraries."""

import argparse
import hashlib
from pathlib import Path
import struct
from zipfile import ZipFile

_ANDROID_ELF = {"arm64-v8a": (2, 183), "armeabi-v7a": (1, 40), "x86_64": (2, 62)}
MPV_FILTER_MARKERS = (b"kazumi-drba\0", b"KAZUMI_DRBA_INFERENCE_FAILED", b"kr_predict_motion\0", b"start-edge\0")
BRIDGE_MARKERS = (b"kr_predict_motion\0", b"kr_warp_plane\0")
_REQUIRED = {
    "libapp.so": None,
    "libflutter.so": None,
    "libmpv.so": (*MPV_FILTER_MARKERS, b"kazumi-surface-size\0"),
    "libkazumi_rife.so": BRIDGE_MARKERS,
    "libkazumi_gpu.so": b"Java_com_example_kazumi_VideoGpu_enumerateVulkan\0",
    "libmediakitandroidhelper.so": b"Java_com_alexmercerind_mediakitandroidhelper_MediaKitAndroidHelper",
}


def elf_load_segments(data, abi):
    """Read bounded ELF PT_LOAD headers and verify machine, type and alignment."""
    elf_class, machine = _ANDROID_ELF[abi]
    if len(data) < 64 or data[:4] != b"\x7fELF" or data[4:7] != bytes((elf_class, 1, 1)):
        raise ValueError(f"not a little-endian {abi} ELF object")
    if struct.unpack_from("<HH", data, 16) != (3, machine):
        raise ValueError(f"not a {abi} ELF shared library")
    is64 = elf_class == 2
    ph_offset = struct.unpack_from("<Q" if is64 else "<I", data, 32 if is64 else 28)[0]
    entry_size, count = struct.unpack_from("<HH", data, 54 if is64 else 42)
    if entry_size != (56 if is64 else 32) or count == 0 or ph_offset < (64 if is64 else 52):
        raise ValueError("invalid ELF program header table")
    if ph_offset + entry_size * count > len(data):
        raise ValueError("truncated ELF program header table")
    segments = 0
    page = 16384 if is64 else 4096
    for i in range(count):
        offset = ph_offset + entry_size * i
        if is64:
            kind, _, pos, vaddr, _, filesize, memsize, alignment = struct.unpack_from("<IIQQQQQQ", data, offset)
        else:
            kind, pos, vaddr, _, filesize, memsize, _, alignment = struct.unpack_from("<IIIIIIII", data, offset)
        if kind != 1:
            continue
        segments += 1
        if filesize > memsize or pos + filesize > len(data):
            raise ValueError("invalid PT_LOAD size")
        if alignment < page or alignment & (alignment - 1) or (pos - vaddr) % alignment:
            raise ValueError(f"PT_LOAD incompatible with {page // 1024} KiB ELF pages: p_align=0x{alignment:x}")
    if segments == 0:
        raise ValueError("ELF has no PT_LOAD segments")
    return segments


MODEL_ASSETS = {
    'distildrba-v2-lite/flownet.param': (9306, 'e2a2409705f68e1efbf9ac34a016544751a78e0b9e2130ab0c716b5db817eda5'),
    'distildrba-v2-lite/flownet.bin': (10641380, '01e8c2a39791635496328614f7d2e7a35e9858b8bcf943c6e48d19249383e2c9'),
}


def verify_model_asset(name, data):
    size, digest = MODEL_ASSETS[name]
    if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f'Incorrect bundled model asset: {name}')


def verify_enhanced_apk(artifact, abi):
    """Fail on missing, duplicate, wrong-ABI, or inappropriately linked native members."""
    if abi not in _ANDROID_ELF:
        raise ValueError(f"unsupported Android ABI: {abi}")
    prefix = f"lib/{abi}/"
    with ZipFile(artifact) as apk:
        libs = {}
        for info in apk.infolist():
            if not info.filename.startswith("lib/") or not info.filename.endswith(".so"):
                continue
            if not info.filename.startswith(prefix) or "/" in info.filename[len(prefix):]:
                raise ValueError(f"unexpected native entry in {abi} split: {info.filename}")
            name = info.filename[len(prefix):]
            if name in libs:
                raise ValueError(f"duplicate native entry: {info.filename}")
            if info.file_size > 192 * 1024 * 1024:
                raise ValueError(f"unreasonably large native entry: {info.filename}")
            libs[name] = info
        if missing := sorted(_REQUIRED.keys() - libs.keys()):
            raise ValueError(f"missing native entries: {', '.join(missing)}")
        audited = {}
        for name, info in libs.items():
            data = apk.read(info)
            required = _REQUIRED.get(name)
            markers = (required,) if isinstance(required, bytes) else required or ()
            for marker in markers:
                if marker not in data:
                    raise ValueError(f"{name} is missing enhanced runtime marker {marker!r}")
            try:
                audited[name] = elf_load_segments(data, abi)
            except ValueError as e:
                raise ValueError(f"{name}: {e}") from e
        prefix = 'assets/flutter_assets/assets/models/'
        assets = {info.filename[len(prefix):] for info in apk.infolist()
                  if not info.is_dir() and info.filename.startswith(prefix)}
        if assets != MODEL_ASSETS.keys():
            raise ValueError(f'Unexpected bundled models: {sorted(assets ^ MODEL_ASSETS.keys())}')
        for name, (size, _) in MODEL_ASSETS.items():
            entries = [info for info in apk.infolist() if info.filename == prefix + name]
            if len(entries) != 1 or entries[0].file_size != size:
                raise ValueError(f'Missing or invalid bundled model: {name}')
            verify_model_asset(name, apk.read(entries[0]))
    return audited


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("abi", choices=_ANDROID_ELF)
    args = parser.parse_args()
    audited = verify_enhanced_apk(args.apk, args.abi)
    print(f"Verified {args.abi}: {len(audited)} native members and enhanced runtime markers")


if __name__ == "__main__":
    main()
