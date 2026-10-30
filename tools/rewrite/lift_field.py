#!/usr/bin/env python3
"""lift_field.py - lift our own code out of the two height-field modules for the clean repo.

The dirty-side repo (~/Documents/battle-art-notquiteog) is upstream base 03882a9 with our
changes as an uncommitted diff.  REWRITE-PLAN.md section 2: our added blocks cross to the
clean repo as our own code; the upstream lines they sit in are rewritten from the spec.

This tool writes, for each file, a complete lifted file in which every region that still
matches the upstream base is replaced by ONE marker line

    --@HOLE <id>: <what the implementer writes here, from the spec>

Everything else is our code, verbatim and in the original order, so the implementer pastes
the file once and fills the holes.

Usage: python3 tools/rewrite/lift_field.py [--out DIR]
"""
import argparse
import difflib
import os
import subprocess
import sys

OLD = os.path.expanduser("~/Documents/battle-art-notquiteog")
BASE = "03882a9"

# start line (1-based) of each upstream-equal region -> (hole id, spec pointer)
HOLES = {
    "lib/Gen3Elevation.lua": {
        1: ("file-header", "MIT header + module job in one line", "6.1"),
        16: ("requires", "V, TerrainLevels, Gen3Tilesets, the weak field cache, M", "6.2"),
        137: ("field-prologue", "layout/cache signature, behaviours, tileset spec, shapes, drop table, outdoor/cave/deck flags", "6.3"),
        548: ("build-open", "Levels.build(w, h, read, compatible, 6, tick) - the read callback head", "6.4"),
        558: ("read-shape", "the cell's shape kind (water test) inside the read callback", "6.4"),
        574: ("compat-open", "the compatible callback head", "6.5"),
        579: ("compat-close", "the compatible callback body + the build call tail", "6.5"),
        1176: ("field-epilogue", "cache store, M.cell, M.at", "6.6"),
        1233: ("bind-open", "M.bind(cells, regions) signature", "6.7"),
        1246: ("bind-floor", "per region, the cell's floor/base/floorHigh lookup", "6.7"),
        1293: ("bind-donor", "the nearest-region donor fallback for c.base", "6.7"),
        1305: ("bind-props-open", "the props' groundHeight settle, head", "6.7"),
        1317: ("bind-props-close", "the props' groundHeight settle, tail", "6.7"),
        1403: ("bind-close", "end of the props loop / M.bind", "6.7"),
        1405: ("lift-guard", "M.lift: return when height is 0", "6.8"),
        1407: ("lift-loop", "M.lift: the vertex loop head", "6.8"),
        1415: ("lift-return", "M.lift tail, M.invalidate, return M", "6.8"),
    },
    "lib/TerrainLevels.lua": {
        1: ("file-header", "the module's header comment", "5.1"),
        16: ("directions", "the four neighbour offsets (E, W, S, N) and M.directions", "5.2"),
        18: ("build-skeleton", "key(); M.build head; read; group flood; flights; jump-strip edges; height solve", "5.2"),
        300: ("flight-bounds", "per flight: low/high from the group heights", "5.3"),
        330: ("flight-close", "the step-cell loop tail of the flight interpolation", "5.3"),
        338: ("support-seed", "the nearest-support queue seed", "5.4"),
        340: ("support-loop", "the nearest-support BFS", "5.4"),
        417: ("build-return", "return f; end", "5.2"),
        424: ("align-core", "M.align head + the seam difference() sampler", "5.5"),
        448: ("align-loop", "the region-offset propagation loop, M.align tail and M.at head", "5.5"),
        474: ("at-flight", "M.at: the plain flight formula when no treads are set", "5.6"),
        482: ("at-return", "M.at tail", "5.6"),
    },
}


def lines_of(text):
    out = text.splitlines()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "own"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    index = []
    for rel, holes in HOLES.items():
        base = subprocess.run(["git", "-C", OLD, "show", f"{BASE}:{rel}"],
                              capture_output=True, text=True, check=True).stdout
        cur = open(os.path.join(OLD, rel), encoding="utf-8").read()
        base_l, cur_l = lines_of(base), lines_of(cur)
        sm = difflib.SequenceMatcher(None, base_l, cur_l, autojunk=False)

        out = []
        hole_rows = []
        stats = dict(own=0, upstream=0, holes=0)
        # every equal region becomes a marker; the rest is our code, verbatim
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag == "equal":
                start = j1 + 1
                if start not in holes:
                    sys.exit(f"{rel}: no hole name for base region at line {start}-{j2}")
                hid, what, sec = holes[start]
                out.append(f"--@HOLE {hid}: {what} [spec HeightField §{sec}]")
                hole_rows.append((start, j2, hid, i2 - i1, what))
                stats["upstream"] += i2 - i1
                stats["holes"] += 1
            elif tag in ("replace", "insert"):
                out.extend(cur_l[j1:j2])
                stats["own"] += j2 - j1
            elif tag == "delete":
                pass
            else:
                raise SystemExit(tag)

        header = [
            f"-- LIFTED OWN CODE from {rel} ({OLD}, base {BASE})",
            "-- Our added blocks, verbatim and in order; every --@HOLE line is an upstream-",
            "-- derived region the implementer writes from docs/specs/HeightField.md.",
            "-- Do not move code across holes: hole ids and order are the contract.",
            "",
        ]
        name = os.path.basename(rel)
        path = os.path.join(args.out, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(header + out) + "\n")
        index.append((rel, name, stats, hole_rows))
        print(f"{rel}: {stats['own']} own lines, {stats['upstream']} upstream lines in "
              f"{stats['holes']} holes -> {path}")

    # the hole index the spec refers to
    with open(os.path.join(args.out, "HOLES.md"), "w", encoding="utf-8") as fh:
        fh.write("# Holes in the lifted field modules\n\n")
        fh.write("Each `--@HOLE <id>` line in the lifted file is one upstream-derived region; write the\n"
                 "behaviour the spec gives for that id, in place, and leave the rest verbatim.\n\n")
        for rel, name, stats, rows in index:
            fh.write(f"## {rel} -> {name}\n\n")
            fh.write(f"{stats['own']} our lines, {stats['upstream']} upstream lines replaced by "
                     f"{stats['holes']} holes.\n\n")
            fh.write("| lifted line | hole id | upstream lines | what belongs there |\n|---|---|---|---|\n")
            for start, end, hid, n, what in rows:
                fh.write(f"| {start} | `{hid}` | {n} | {what} |\n")
            fh.write("\n")
    print("index ->", os.path.join(args.out, "HOLES.md"))


if __name__ == "__main__":
    main()
