#!/usr/bin/env python3
"""Rebuild PNGs from a dump_gid_art.lua log (sprite art dumped as hex rows).

The game runs sandboxed and cannot write outside its identity, so the driver
prints pixels to stdout and this rebuilds them. Usage:
    python3 tools/art_from_log.py logs/dump_gid_art2.log shots_art
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

PX = re.compile(r"^\[ART\] px gid=(\d+) y=(\d+) ((?:[0-9A-F]{8})+)$")


def main(log_path: str, out_dir: str) -> int:
    rows: dict[int, dict[int, list[tuple[int, int, int, int]]]] = defaultdict(dict)
    for line in Path(log_path).read_text(errors="replace").splitlines():
        m = PX.match(line.strip())
        if not m:
            continue
        gid, y, hexrow = int(m.group(1)), int(m.group(2)), m.group(3)
        px = [tuple(int(hexrow[i + j : i + j + 2], 16) for j in (0, 2, 4, 6))
              for i in range(0, len(hexrow), 8)]
        rows[gid][y] = px
    if not rows:
        print("no pixel rows found", file=sys.stderr)
        return 1
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for gid, by_y in sorted(rows.items()):
        h = max(by_y) + 1
        w = len(by_y[0])
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for y, px in by_y.items():
            if len(px) != w:
                print(f"gid {gid}: ragged row {y}", file=sys.stderr)
            for x, rgba in enumerate(px):
                im.putpixel((x, y), rgba)
        path = out / f"gid{gid}.png"
        im.save(path)
        # a 8x nearest-neighbour view for eyeballing
        im.resize((w * 8, h * 8), Image.NEAREST).save(out / f"gid{gid}_x8.png")
        print(f"{path} {w}x{h}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1], sys.argv[2]))
