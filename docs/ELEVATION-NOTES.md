# Elevation from the cartridge nibble — session notes (2026-10-05)

Status: **QA only. Not installed to the real game. Not committed.** The last installed build is
the verified thin-band cap (`6c511c2` in the Emerald repo).

## What was changed (`battle-art-notquiteog/lib/Gen3Elevation.lua`)

Three edits, all in `M.field`:

1. **Pin the floor height from the nibble.** A walkable, non-water cell with `elev >= 3` gets
   `pin = min(elev-3, M.MAX_STEP) * M.COURSE` (`M.COURSE=16`, `M.MAX_STEP=4`). Authored terrace
   pins still win.
2. **Exact layer grouping.** `compatible` was
   `a.layer==b.layer or a.layer==0 or b.layer==0 or a.layer==15 or b.layer==15`; it is now
   `a.layer==b.layer`. Without this, a whole town merges into one group and `TerrainLevels`
   assigns that group the **median pin**, flattening every terrace (measured: Mossdeep came out as
   1959 cells at one height instead of 0/16/32/64/96).
3. **`seed = 0`.** The old `(outdoor or cave) and raw.elev==4 and 6` seed was a stand-in for the
   one-step floors the nibble now states outright. Left in, it lifts every e4 floor twice (+6 on
   top of a +16 pin) and a stair flight adds +80 more (measured at Fortree's walkway: 16 -> 96).

## Evidence

- The nibble is at **bits 12-15** (`math.floor(word/4096)%16`), confirmed against the brief:
  Mossdeep e0:917 e1:968 e3:430 e4:33 e5:510 e7:230 e9:112.
- Walkability cross-tab: e0 is the **blocked/transition layer** (Mossdeep 903 of 917 blocked,
  Sootopolis 2079 blocked, 0 walkable), e1 is water, e3 is ground, e4+ are upper terraces.
- Fortree's ASCII elevation map shows three real storeys: an **e4 ridge (row 4)**, an
  **e15 walkway (row 14)** and **e3 ground (rows 6-19)**, with `0` cells as the stairs between
  (`~/Documents/gen1recomp-modwork/` has the scripts; see `tools/` copies in this repo).
- With the three edits, per-group solved heights are exactly the terraces:
  Mossdeep 0/16/32/64/96, Lilycove 0/32, Fortree 0/16/64, Route 114 0/16/32/64.
- 40 captures (5 maps x 4 yaw x levels 4 and 7): zero `scene fallback`, zero errors.

## Open problems before this can ship

1. **Camera height follows the player's cell**, so raising floors moves the camera and changes
   framing between before/after captures (`R.camera` uses `M.groundAt`, `Gen3Scene.lua` ~line 908).
   Comparisons must account for it.
2. **Fortree's e15 walkway** is a "very high" marker (most of its 236 cells are blocked; only 4 are
   walkable), so it is clamped to `M.MAX_STEP`. At 4 it sits at 64 world units - still a tall wall.
   Needs a judgement call, or Fortree wants its own rule.
3. **New retaining faces show the known stretched-texture defect** the brief already lists under
   shorelines (`Gen3Terrain.append` side mapping). The elevation work multiplies how many of those
   faces exist, so that fix should land with or before this.
   - Attempted and **reverted** (2026-10-05): stepping the face art down in 4-texel bands
     (`band = (height-h)/16`) instead of repeating the whole face per row. At level 4 on Route 114
     and Route 104 it read about the same as the current mapping, so it did not clear the
     "nothing worse" bar and is not in the source tree. Captures:
     `shots_faces/cmp_r114_4.png`, `shots_faces/cmp_r104_4.png`.
   - Constraint worth knowing before trying again: `uvFor` addresses a **tile inside a tileset
     atlas**, so U/V must stay inside that tile. Wrapping past the tile edge samples the
     neighbouring tile, and the atlas clamps rather than repeats. Per-quad V wrap is therefore not
     available; a fix has to stay within the tile's own texel range.
4. **Stairs.** Emerald staircases carry no stair behaviour, so `f.flights` is empty; levels change
   as steps in the floor mesh rather than believable flights.

## How to reproduce

```
# offline: heights per map, no game
cd ~/Documents/gen1recomp && luajit /tmp/base_cmp.lua     # EXACT=1 MAXSTEP=4
# captures: 5 terraced maps, levels 4 and 7, 4 yaw angles
EM_CASES=cases_elev.lua EM_LEVELS=levels_47.lua EM_YAW=<0|90|180|270>
```
Case files are committed in this repo: `tools/cases_elev.lua`, `tools/cases_yaw.lua`,
`tools/cases_verify.lua`, `tools/cases_focus.lua`, `tools/cases_noise.lua`, `tools/cases_ft.lua`.
