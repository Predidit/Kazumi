"""Fetch only the Android JNI bootstrap from the locked media-kit bundle."""
import argparse
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen
from zipfile import ZipFile

BASE = "https://github.com/Predidit/libmpv-android-video-build/releases/download/v1.3.1/"
SHA256 = {
    "arm64-v8a": "3bbceecd7616d5730e19865342a020834f00bdf77c25900e97c91a6e3e8141f8",
    "armeabi-v7a": "96c37141ef20d1c73da01887f8ad6244aa7fccb44e805457d3eb15d2d71fde20",
    "x86_64": "f01e9f1890091f4dd856cd37247e442d151b7815a86306581a1e9317ec566136",
}


def fetch(abi, output, archive=None):
    if archive:
        data = archive.read_bytes()
    else:
        with urlopen(f"{BASE}default-{abi}.jar", timeout=45) as response:
            data = response.read(32 * 1024 * 1024)
    if sha256(data).hexdigest() != SHA256[abi]:
        raise ValueError("Wrong Android bootstrap archive or SHA-256 mismatch")
    name = "libmediakitandroidhelper.so"
    with ZipFile(BytesIO(data)) as bundle:
        helper = bundle.read(f"lib/{abi}/{name}")
    if not helper.startswith(b"\x7fELF"):
        raise ValueError("JNI bootstrap is not ELF")
    output.mkdir(exist_ok=True, parents=True)
    file = output / name
    file.write_bytes(helper)
    print(file)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("abi", choices=SHA256)
    p.add_argument("output", type=Path)
    p.add_argument("--archive", type=Path, help="Optional copy of the exact upstream JAR")
    args = p.parse_args()
    fetch(args.abi, args.output, args.archive)
