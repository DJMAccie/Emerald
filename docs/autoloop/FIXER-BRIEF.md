# Fixer brief (autoloop, one fault per fixer)

You fix ONE fault of the Emerald 3D voxel mod (Pokémon Emerald in the LÖVE2D engine gen1recomp, world built in Lua from
the original pixel art). An orchestrator gave you the fault id, map, cell box and evidence. You work in your own git
worktree of the release-candidate tree, prove the fix with the gate script, and report. You never install anything.

## Read first
- `~/Documents/Emerald/docs/AUTOLOOP.md` (rules, detectors, gate) and `~/Documents/Emerald/.dsh/skills/emerald-terrain/SKILL.md`
  (where the terrain code is, the user's taste, lessons that cost hours). Mod module map: `~/Documents/Emerald/HANDOFF.md`.

## Your tree
- Create it: `git -C ~/Documents/Emerald/.autoloop/rc worktree add ~/Documents/Emerald/.autoloop/wt/<FAULT> -b fix/<FAULT> main`
  (if it exists, reuse it). Edit ONLY `~/Documents/Emerald/.autoloop/wt/<FAULT>/lib/*.lua`. Commit there on `fix/<FAULT>`.
- Read-only references: `~/Documents/battle-art-notquiteog` (mod source, other sessions edit it: never write there),
  `~/Documents/gen1recomp` (engine). Never touch `~/Library/Application Support/pokemon-love2d*` except through the
  scripts below, never `git stash`, never edit `.autoloop/rc` itself or another fixer's worktree.

## Tools (run from `~/Documents/Emerald`; game runs go through private QA copies, max 4 games machine-wide, the
scripts wait for a slot; run at most 2 of yours at once and start them 20 s apart; check `pgrep -fl "MacOS/love"` first)
- Geometry + cells of maps from your tree: `AUTOLOOP_RC=<your tree> tools/autoloop/geo_batch.sh <maps.txt> <outdir> <geo_dir>`
  (`maps.txt` = "MAP x y" lines; spots in `docs/ledger/outdoor_spots.txt`). `.cells` lines give per cell: tile, kind,
  coll, base (floor px), stairs, ledge, mass ... `detect.py tags|air|steps <geo.gz>` lists mesh origins / floating
  surfaces / mini-stairs. Base dumps of rc main: `.autoloop/geo-cache/<main short hash>/`.
- Captures from your tree: `AUTOLOOP_RC=<your tree> tools/autoloop/shots.sh <outdir> "{'MAP',x,y},..." 4,6,7 <yaw> 150`
  (levels 4 player, 6 low, 7 orbit; indexed b001.png... per case and level). Judge at full resolution: crop and enlarge
  with nearest-neighbour (python3 with PIL, not `-I`); never judge from a thumbnail.
- Original art: `python3 ~/Documents/Emerald/.dsh/skills/emerald-terrain/scripts/crop2d.py <slot> <pair> x0 y0 x1 y1 out.png 6`
  and `grid.py` there (see the skill for slots and pairs).
- Syntax check: `luajit -bl <file> >/dev/null`.
- **Gate (decides):** `FIX_TREE=<your tree> tools/autoloop/gate.sh <FAULT> <MAP> <x0,y0,x1,y1> <air|steps|none> "<x,y walkable spot>"`
  Exit 0 = the fault's detector region is gone, no new detector regions on 8 regression maps, cells identical outside the
  box, 0 fallbacks; it also writes `.autoloop/gates/<FAULT>/sheet.png` (before/after at levels 4/6/7, two yaws) and
  `verdict.json`. Takes ~10-15 min.

## Method
1. Reproduce: look at the evidence shot, capture the spot from your tree, read the `.cells` heights and `detect.py air`
   region. Find which code draws the wrong geometry (blank a suspected branch once in your tree and look, or print from
   inside the mod to stdout and grep the run.log: `os.getenv` does not work inside the mod).
2. Decide the CLASS (what else has the same cause) and fix the class, with a comment saying what it looked like and why.
   Heights first: most floating / pit / double-ledge faults are heights, not the drawing.
3. Taste: original pixels 1:1, never stretch, more depth is fine, rounding at most ~3 px, nothing wonky, melted, striped,
   chunky, floating. If the fix needs a style choice, stop and report options instead of choosing.
4. Gate it. If the gate fails because of a regression elsewhere, revert that approach rather than tuning it. At most 2
   approaches; then stop and report what you learned (that is a useful result).
5. Keep the change small; never add per-cell quads in a way that slows the build (Route 112 fell back to flat 2D once).

## Report (your final message)
FAULT, verdict (PASS / FAIL / NEEDS-USER), the class and cause in two sentences, files and line ranges changed, the commit
on `fix/<FAULT>` in your worktree, gate numbers (fault regions before/after, new regions, cells changed, fallbacks),
the sheet path, and anything you could not verify. Do not merge, do not install.
