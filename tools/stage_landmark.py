#!/usr/bin/env python3
"""Stage the mod's Gen3Scene.lua with the landmark hook, for capture testing.

The hook is small and lives in exactly two places: `actor()` gains a branch
that draws a modelled solid in place of the billboard card, and `release()`
releases the landmark meshes with the other geometry. Both are applied here
as anchored edits so the staged file cannot drift from the installed source,
and any edit that no longer matches fails loudly instead of silently doing
nothing.

Usage: python3 tools/stage_landmark.py [--src DIR] [--out DIR]
"""
import argparse
import shutil
import sys
from pathlib import Path

SPR_ANCHOR = " local spr=Sprites.getDraw(gid);if not spr then return end\n"
YAW_ANCHOR = " local yaw=cam.level>=6 and -cam.yaw or 0\n"
RELEASE_ANCHOR = " spriteMeshes={}\n"

SOLID_LINES = """ -- A landmark whose drawing describes a solid is built as one: it has real
 -- depth, so it never turns to face the camera and never leans back with it.
 local solid=Landmarks.mesh(gid,spr)
 local mesh=solid
 if not solid then
"""

RELEASE_ADD = " Landmarks.release()\n"


def patch_scene(text: str) -> str:
    if "Landmarks.mesh(gid,spr)" in text:
        raise SystemExit("Gen3Scene already carries the landmark hook")
    if "local Standing=V.require('Gen3Objects')\n" not in text:
        raise SystemExit("require anchor missing: Standing")
    text = text.replace(
        "local Standing=V.require('Gen3Objects')\n",
        "local Standing=V.require('Gen3Objects')\nlocal Landmarks=V.require('LandmarkModels')\n",
        1,
    )
    start = text.index(SPR_ANCHOR) + len(SPR_ANCHOR)
    end = text.index(YAW_ANCHOR, start)
    card_block = text[start:end]
    if "spriteMeshes[key]" not in card_block or "Sprites.pose" not in card_block:
        raise SystemExit("card block anchor does not look like the card path")
    indented = "".join((" " + line if line.strip() else line) for line in card_block.splitlines(True))
    # The card path's mesh is the one `mesh` the whole function goes on to
    # draw: it must assign, not shadow.
    indented = indented.replace(" local mesh=spriteMeshes[key]", " mesh=spriteMeshes[key]", 1)
    text = (
        text[:start]
        + SOLID_LINES
        + indented
        + " end\n"
        + " local yaw=solid and 0 or (cam.level>=6 and -cam.yaw or 0)\n"
        + text[end + len(YAW_ANCHOR):]
    )
    if RELEASE_ANCHOR not in text:
        raise SystemExit("release anchor missing")
    text = text.replace(RELEASE_ANCHOR, RELEASE_ANCHOR + RELEASE_ADD, 1)
    if "solid and 0 or (opts.pull or 7)" not in text:
        old = "draw(mesh,spr.image,model,opts.pull or 7,caster)"
        if old not in text:
            raise SystemExit("draw anchor missing")
        # A card is pulled toward the camera so it cannot slice into what it
        # leans on; solid geometry stands exactly where it is put.
        text = text.replace(
            old,
            "draw(mesh,spr.image,model,solid and 0 or (opts.pull or 7),caster)",
            1,
        )
    return text


def main() -> int:
    here = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=str(Path.home() / "Documents/battle-art-notquiteog/lib"))
    ap.add_argument("--out", default=str(here / ".qa-stage/landmark/lib"))
    args = ap.parse_args()
    src, out = Path(args.src), Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for name in ("SpriteVoxel.lua", "LandmarkModels.lua"):
        if not (out / name).exists():
            raise SystemExit(f"staged {name} missing -- author it before staging the scene")
    patched = patch_scene((src / "Gen3Scene.lua").read_text())
    (out / "Gen3Scene.lua").write_text(patched)
    print(f"staged {out/'Gen3Scene.lua'} ({len(patched.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
