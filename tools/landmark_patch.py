#!/usr/bin/env python3
"""Write a landmark-only patch of the mod source.

The repo's patches/battle-art-voxel-fork.patch is the whole mod-vs-upstream
diff, and another session may be editing that same working tree. This tool
writes the part of the diff that belongs to the sprite-to-voxel round and
nothing else:

  lib/SpriteVoxel.lua      new
  lib/LandmarkModels.lua   new
  lib/Gen3Scene.lua        the landmark hook only

Gen3Scene's contribution is isolated by reverting exactly the anchored edits
tools/stage_landmark.py applies and diffing that against the file on disk, so
a concurrent change to the same file cannot leak into this patch.

Usage: python3 tools/landmark_patch.py [--mod DIR] [--out FILE]
"""
import argparse
import difflib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from stage_landmark import SOLID_LINES, RELEASE_ADD  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
NEW_FILES = ("lib/SpriteVoxel.lua", "lib/LandmarkModels.lua")
HOOK_FILE = "lib/Gen3Scene.lua"


def revert_scene(text: str) -> str:
    """Undo the landmark hook, leaving any other change in place."""
    if SOLID_LINES not in text:
        raise SystemExit("Gen3Scene does not carry the landmark hook")
    start = text.index(SOLID_LINES) + len(SOLID_LINES)
    # The wrapped card block runs to the closing `end` this tool added,
    # immediately before the yaw line it rewrote.
    yaw = " local yaw=solid and 0 or (cam.level>=6 and -cam.yaw or 0)\n"
    if yaw not in text:
        raise SystemExit("rewritten yaw line missing")
    end = text.index(yaw, start)
    block = text[start:end]
    if not block.endswith(" end\n"):
        raise SystemExit("landmark block does not end where expected")
    block = block[: -len(" end\n")]
    reverted = "".join(line[1:] if line.startswith(" ") else line for line in block.splitlines(True))
    reverted = reverted.replace(" mesh=spriteMeshes[key]", " local mesh=spriteMeshes[key]", 1)
    text = text[: text.index(SOLID_LINES)] + reverted + " local yaw=cam.level>=6 and -cam.yaw or 0\n" + text[end + len(yaw):]
    text = text.replace("local Landmarks=V.require('LandmarkModels')\n", "", 1)
    text = text.replace(" Landmarks.release()\n", "", 1)
    old = "draw(mesh,spr.image,model,solid and 0 or (opts.pull or 7),caster)"
    if old not in text:
        raise SystemExit("patched draw call missing")
    return text.replace(old, "draw(mesh,spr.image,model,opts.pull or 7,caster)", 1)


def hunks(path: str, before, after) -> str:
    a = before.splitlines(True)
    b = after.splitlines(True)
    if a == b:
        return ""
    header = [f"diff --git a/{path} b/{path}\n"]
    if not before:
        header.append("new file mode 100644\n")
    header.append(f"--- {'/dev/null' if not before else 'a/' + path}\n")
    header.append(f"+++ b/{path}\n")
    body = list(difflib.unified_diff(a, b, n=3, lineterm="\n"))
    if not body:
        return ""
    # difflib already emits ---/+++ lines; drop them in favour of ours.
    body = [line for line in body if not (line.startswith("--- ") or line.startswith("+++ "))]
    return "".join(header) + "".join(body)


def verify(patch_text: str, mod: Path) -> int:
    """Apply the patch to a temporary pre-change tree and compare the result."""
    import subprocess
    import tempfile

    work = Path(tempfile.mkdtemp(prefix="landmark-patch-"))
    (work / "lib").mkdir(parents=True)
    (work / HOOK_FILE).write_text(revert_scene((mod / HOOK_FILE).read_text()))
    (work / "landmark.patch").write_text(patch_text)
    # -R would be needed for an already-applied tree; here the tree is the
    # reverted one, so the patch must apply exactly once.
    proc = subprocess.run(["git", "apply", "landmark.patch"], cwd=work, capture_output=True, text=True)
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        return 1
    bad = 0
    for rel in NEW_FILES + (HOOK_FILE,):
        applied = (work / rel).read_text()
        if applied != (mod / rel).read_text():
            print(f"  MISMATCH {rel}", file=sys.stderr)
            bad += 1
        else:
            print(f"  {rel}: applies cleanly, byte-identical")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mod", default=str(Path.home() / "Documents/battle-art-notquiteog"))
    ap.add_argument("--out", default=str(ROOT / "patches/battle-art-voxel-fork.landmark.patch"))
    ap.add_argument("--verify", action="store_true", help="apply the patch to a pre-change tree and compare")
    args = ap.parse_args()
    mod = Path(args.mod)
    parts = []
    for rel in NEW_FILES:
        text = (mod / rel).read_text()
        parts.append(hunks(rel, "", text))
    scene = (mod / HOOK_FILE).read_text()
    parts.append(hunks(HOOK_FILE, revert_scene(scene), scene))
    patch = "".join(p for p in parts if p)
    if not patch:
        raise SystemExit("nothing to write: the mod source has no landmark change")
    if args.verify:
        print("verifying against a pre-change tree:")
        rc = verify(patch, mod)
        if rc:
            return rc
    Path(args.out).write_text(patch)
    print(f"wrote {args.out} ({len(patch.splitlines())} lines)")
    for rel in NEW_FILES + (HOOK_FILE,):
        print(f"  {rel}: {'in patch' if rel in patch else 'unchanged'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
