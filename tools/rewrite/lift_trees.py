#!/usr/bin/env python3
"""lift_trees.py - lift our own tree code out of the dirty-side repo, same method as lift_field.py.

Three kinds of file:
  * ours entirely (upstream never had it: Gen3Canopy, Gen3Fortree, Gen3AshPine):
    copied verbatim, no holes;
  * ours on top of an upstream file (VoxelHull, NativeTreeArt, TreePresentation):
    every region that still matches the upstream base becomes one `--@HOLE <id>` line,
    everything else is our code, verbatim and in order.

Hole ids are positional (`upstream-1`, `upstream-2`, ...) and the description is filled in
from the spec after the lifted file is read; the lifted file is the implementer's contract.

Usage: python3 tools/rewrite/lift_trees.py [--out DIR]
"""
import argparse
import difflib
import os
import subprocess
import sys

OLD = os.path.expanduser("~/Documents/battle-art-notquiteog")
BASE = "03882a9"

# file -> True when the whole file is ours (no upstream base to compare with)
FILES = {
    "lib/Gen3Canopy.lua": True,
    "lib/Gen3Fortree.lua": True,
    "lib/Gen3AshPine.lua": True,
    "lib/VoxelHull.lua": False,
    "lib/NativeTreeArt.lua": False,
    "lib/TreePresentation.lua": False,
}


def lines_of(text):
    return text.splitlines()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "own", "trees"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    index = []
    for rel, all_ours in FILES.items():
        cur = open(os.path.join(OLD, rel), encoding="utf-8").read()
        cur_l = lines_of(cur)
        header = [
            f"-- LIFTED OWN CODE from {rel} ({OLD}, base {BASE})",
            "-- Our added blocks, verbatim and in order; every --@HOLE line is an upstream-",
            "-- derived region the implementer writes from docs/specs/Trees.md.",
            "",
        ]
        out, rows = [], []
        if all_ours:
            out = cur_l
            stats = dict(own=len(cur_l), upstream=0, holes=0)
        else:
            base = subprocess.run(["git", "-C", OLD, "show", f"{BASE}:{rel}"],
                                  capture_output=True, text=True, check=True).stdout
            base_l = lines_of(base)
            sm = difflib.SequenceMatcher(None, base_l, cur_l, autojunk=False)
            stats = dict(own=0, upstream=0, holes=0)
            for tag, i1, i2, j1, j2 in sm.get_opcodes():
                if tag == "equal":
                    hid = f"upstream-{len(rows) + 1}"
                    out.append(f"--@HOLE {hid}: (describe from the spec) [Trees.md §]")
                    rows.append((j1 + 1, j2, hid, i2 - i1, ""))
                    stats["upstream"] += i2 - i1
                    stats["holes"] += 1
                elif tag in ("replace", "insert"):
                    out.extend(cur_l[j1:j2])
                    stats["own"] += j2 - j1
                elif tag == "delete":
                    pass
        name = os.path.basename(rel)
        path = os.path.join(args.out, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(header + out) + "\n")
        index.append((rel, name, stats, rows))
        print(f"{rel}: {stats['own']} own lines, {stats['upstream']} upstream lines in "
              f"{stats['holes']} holes -> {path}")

    with open(os.path.join(args.out, "HOLES.md"), "w", encoding="utf-8") as fh:
        fh.write("# Holes in the lifted tree modules\n\n")
        for rel, name, stats, rows in index:
            fh.write(f"## {rel} -> {name}\n\n{stats['own']} own lines, {stats['upstream']} "
                     f"upstream lines in {stats['holes']} holes.\n\n")
            for start, end, hid, n, what in rows:
                fh.write(f"- `{hid}` at lifted line {start}: {n} upstream lines\n")
            fh.write("\n")
    print("index ->", os.path.join(args.out, "HOLES.md"))


if __name__ == "__main__":
    main()
