"""Add the Kazumi mpv filter to a pinned Predidit native builder checkout."""
import argparse
from pathlib import Path
import shlex
import subprocess

PATCH = Path(__file__).resolve().parents[2] / "native/video_interpolation/patch_mpv.py"
PINS = {
    "android": "0443048272a511d7a990a2a3d5ca6bbaf55a869a",
    "windows": "b5bb494f49f0cea9d46c613cdea81a696eaa2939",
}


def install(target, root):
    head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if head != PINS[target]:
        raise RuntimeError(f"Expected {PINS[target]}, got {head}")
    marker = "# Kazumi RIFE filter integration"
    if target == "android":
        script = root / "buildscripts" / "scripts" / "mpv.sh"
        text = script.read_text(encoding="utf-8")
        anchor = "meson setup $build --cross-file"
        if marker not in text:
            if text.count(anchor) != 1:
                raise RuntimeError("Unexpected Android mpv builder layout")
            text = text.replace(anchor, f"{marker}\npython3 {shlex.quote(str(PATCH))} .\n\n{anchor}")
    else:
        if "]==]" in str(PATCH):
            raise ValueError("Unsupported patch checkout path")
        script = root / "packages" / "mpv.cmake"
        text = script.read_text(encoding="utf-8")
        if marker not in text:
            text += f'''

{marker}
ExternalProject_Add_Step(mpv kazumi-rife
    COMMAND python3 [==[{PATCH.as_posix()}]==] <SOURCE_DIR>
    DEPENDEES patch
    DEPENDERS configure
    WORKING_DIRECTORY <SOURCE_DIR>
)
'''
    script.write_text(text, encoding="utf-8", newline="\n")
    print(f"Filter patch configured in {script}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=PINS.keys())
    parser.add_argument("builder", type=Path)
    args = parser.parse_args()
    install(args.target, args.builder.resolve())
