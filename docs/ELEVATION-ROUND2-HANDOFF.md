# Handoff for the next round — elevation (state at end of round 1)

## Done and installed

Cartridge elevation is **live in the real game** and committed (`c01dd81`, `ad5bbd1`, `af35648`).

`Gen3Elevation.M.field` pins floor heights from the per-cell nibble (bits 12–15):

```lua
local pinned = raw.coll~=7 and not step and not jump and raw.elev>=3 and shape.kind~='water'
pin = (pins and pins[x..':'..y]) or (pinned and math.min(raw.elev-3, M.MAX_STEP) * M.COURSE or nil)
-- grouping: local layer = a.layer==b.layer      (exact!)
-- seed = 0                                       (no e4 +6 lift)
-- M.COURSE=16, M.MAX_STEP=3
```

Two details are load-bearing; both are explained in `HANDOFF.md` under "DONE and installed":

1. **Exact grouping.** `TerrainLevels` assigns a group the **median pin** of its cells. The old
   relaxation (`a.layer==0 or b.layer==0 or a.layer==15 or b.layer==15`) merges a whole town into one
   group: measured, Mossdeep flattened to 1959 cells at a single height.
2. **`seed = 0`.** The e4 seed was a stand-in for floors the nibble states outright; on a pin it
   double-lifted every e4 floor, and a stair flight added +80 (Fortree walkway 96 instead of 16).

Solved heights match the drawn terraces: Mossdeep 0/16/32/64/96, Lilycove 0/32, Fortree 0/16/48,
Route 114 0/16/32/64. Flat maps are unchanged (Rustboro, Mauville, Slateport, Petalburg, Oldale are
single-height either way).

Evidence: **65 captures** — the 5 terraced maps at 4 `EM_YAW` values × levels 4 and 7, plus the
25-view regression — **zero `fallback`, zero errors**, all views `active true` with non-zero
`rendered`. Patch regenerated, `git apply --check`ed on `git archive 03882a9`, and the applied
`Gen3Scene` / `Gen3Elevation` / `Gen3Terrain` / `Gen3Objects` are **byte-identical** to the real
install. Backups: `~/Documents/gen1recomp-modwork/backups/2026-10-05-elevation/`.

## Regression repaired this round (important)

A debug-instrumentation revert earlier in this session put `lib/Gen3Scene.lua` back to `HEAD`, which
**silently dropped the staged `Gen3Objects` hooks** — `Standing.bank/joinRock/prepare`, the
`if not shape.bank then plane(...)` guard, the `elseif c.object or c.objectTop` branch, and
`objectCount`. They existed in **no** git state (not HEAD, not the index, not any commit); only the real
installed file had them, which is why the previous "installed and committed" claim in the brief did not
survive a fresh install. `Gen3Scene.lua` is now restored from the verified real install and the
regenerated patch carries all 15 lines. Keep an eye out for this class of loss: the mod source tree,
the index and the real install can disagree, and only the real install was authoritative here.

## Still open (the objective's remaining clause)

The objective's "treat elev-0 walkable cells as stair flights between the levels they connect" is
**not implemented**. What the data actually shows:

- `e0` is overwhelmingly the **blocked** layer (Mossdeep 903 of 917 blocked, Sootopolis 2079 blocked
  and 0 walkable, Route 112 1790 of 1799). Only a handful of `e0` cells are walkable (Mossdeep 14,
  Lilycove 23, Fortree 18, Route 114 45).
- Emerald's staircases carry **no stair behaviour**, so `TerrainLevels.build` produces `f.flights`
  empty (measured: Fortree `flights=0`). Levels currently change as steps in the floor mesh.
- Genuine stairs in the real game live on `e0` strips, so a future pass should recognise an `e0` run
  with different levels at its two ends and give it a stepped/ramped surface (`Gen3Stairs`,
  `Stairs.append`, `step=true`).

Also open, knowingly shipped:

- Fortree's `e15` is a "very high" sentinel (4 walkable cells of 236); `MAX_STEP` clamps it rather than
  describing it. Fortree's three storeys are 0/16/48.
- New retaining faces inherit the stretched-texture defect from `Gen3Terrain.append`. A band-stepped
  mapping was attempted and reverted (no better at level 4). **Constraint:** `uvFor` addresses a tile
  inside a tileset atlas, so face UVs cannot wrap past the tile edge — the atlas clamps.
- Camera height follows the player's cell, so raising floors moves the eye. Mossdeep 24,19 now bases at
  32 (the player genuinely stands on a terrace), which is correct but changes framing between builds.
- NPC/player grounding on terraces was not checked in the real game with a human playing.

## Useful commands

```bash
# offline: heights per map, no game (EXACT=1 MAXSTEP=3 reproduces the shipped rule)
cd ~/Documents/gen1recomp && luajit /tmp/base_cmp.lua        # /tmp scripts are ephemeral; the
                                                             # committed case sets are in tools/
```
