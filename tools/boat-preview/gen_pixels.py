#!/usr/bin/env python3
"""Dump one cached overworld sprite to a Lua row table, for harness.lua.

The sprite is the game's own extracted cache (never commit it):
  ~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/ow/<gid>.rgba
  (zlib-deflated RGBA, atlas = frame w x (frame h * frames))
Usage: python3 tools/boat-preview/gen_pixels.py 88 > /tmp/pixels.lua
"""
import re
import sys
import zlib
from pathlib import Path

from PIL import Image

CACHE = Path.home() / "Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/ow"


def main() -> int:
    gid = sys.argv[1] if len(sys.argv) > 1 else "88"
    raw = zlib.decompress((CACHE / f"{gid}.rgba").read_bytes())
    manifest = (CACHE / "manifest.lua").read_text(errors="replace")
    m = re.search(r"\[%s\] = \{([^}]*)\}" % gid, manifest)
    if not m:
        print(f"gid {gid} not in the manifest", file=sys.stderr)
        return 1
    meta = dict(re.findall(r"(\w+) = (\d+)", m.group(1)))
    w, h, n = int(meta["width"]), int(meta["height"]), int(meta["frameCount"])
    im = Image.frombytes("RGBA", (w, h * n), raw)
    print("local rows={")
    for y in range(h * n):
        print('"%s",' % "".join("%02x%02x%02x%02x" % im.getpixel((x, y)) for x in range(w)))
    print("}")
    print("return rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
