# Can pret/pokeemerald or Porymap give us terrain height? (mined 2026-10-20)

Method: shallow clone of `pret/pokeemerald` (outside the repo, scratchpad) read against the engine's own
`world.json` (515 maps, ROM-exact cells and per-tileset behaviours) and the mod's `lib/`. Counts only;
nothing ROM-derived is stored here. Companion to `POKEEMERALD-DECOMP-NOTES.md`.

## Verdict
The decomp and Porymap show the same 16-bit cell word the engine already decodes (10 bits metatile,
2 bits collision, 4 bits elevation) and the same per-metatile behaviour bytes. **Neither stores a cliff
or terrace height**; the artists drew relief as pixels. So they can name and cross-check what we have;
they cannot replace `Gen3Relief` / `Gen3Hills` / terrace tables.

## Numbers (outdoor-type maps, 111,487 cells)
- **Elevation nibble**: 0 = 54,342 | 1 (water) = 18,669 | 3 (ground) = 33,974 | 4 = 1,010 | 5 = 2,273 |
  7 = 845 | 9 = 112 | 15 (sentinel) = 261. Only ~4,500 cells sit above ground level 3 in the whole
  outdoor world, so the cartridge says "one level" almost everywhere. This is why relief is authored.
- **Behaviours**: 64 distinct on outdoor maps. `MB_NORMAL` is 71,332 cells, of which 44,836 are blocked.
  A rock wall or cliff face is "normal behaviour + blocked", so behaviours cannot classify cliff faces.
  The one rock-like behaviour, `MB_MOUNTAIN_TOP` (0x0C), is 9,827 cells (7,199 blocked); the mod
  already treats it as rock (see emerald-tile-shape-findings).
- **Already used by the mod**: jump/ledge 0x38-0x3B, mountain top, water family, doors/escalators,
  ladders, stairs (via `Gen3Elevation` behaviours). pret's header gives the names for these ids.
- **Object/warp/bg elevations in pret map JSON**: 3305 at 3, 1505 at 0, 204 at 4, 105 at 1, 55 at 5, a
  handful at 6-8. Same information as the nibble, as sparse samples.

## What pret adds that is real
1. **Names** for behaviours (`include/constants/metatile_behaviors.h`, 240 entries) and ~695 metatile
   labels. `METATILE_General_RockWall_GrassBase/RockBase/SandBase` = 0x079 / 0x07C / 0x091 are the
   three named rock-wall bases; they sit inside our hand-listed `G_CLIFF` spans in
   `tools/gen_emerald_tables.py`, which is a confirmation, not new data.
2. **Runtime metatile swaps**: `setmetatile` appears 46 times in 38 script files (Fortree drawbridge,
   Sootopolis, Mt. Pyre, Trick House, Sky Pillar and others). These change walkability and, for
   bridges, level after the map loads. NOT yet checked whether the mod follows them. This is the one
   concrete lead.
3. **Metatile layer type** (normal / covered / split: whether a tile draws over the player) lives in the
   tileset attributes. No use found in `lib/` (grep); could tell overhead tiles (tree tops, roofs,
   bridges) from ground. Not measured.

## Porymap
Same data, an editor and viewer. Useful to eyeball an elevation overlay or find which metatile is at a
spot; it cannot add height. Our pipeline reads the ROM cells directly, so a Porymap project would be
an extra export step for no new information.

## Leads, in order of expected value
1. List the `setmetatile` swaps and check which ones the mod reproduces (or ignores).
2. Check whether layer type separates overhead tiles from ground where props float or sink.
3. Keep relief from drawing + 3DS port; no data source replaces it.

## Follow-up: do the runtime tile swaps reach the 3D scene? (static read, 2026-10-20)
Read only; no game run yet.
- **Engine side: yes.** `Field.setMetatile` (gen1recomp `field.lua:2189`, the `setmetatile` opcode 0xA2 and the C-side swaps) stores an
  override in the map's `LayoutNative` (`applyOverride`, `layout_native.lua:124`), bumps `_revision`, patches collision and keeps the
  cell's old elevation nibble (`layout:elevAt`). Cell reads consult the overrides (`layout_native.lua:55,73,113`).
- **Scene side: should rebuild.** `Gen3Scene` builds from `def.midLayout` and its cache signature includes each cell's
  `pair/mid/collision` (`Gen3Scene.lua:888,897-900`), so a changed tile gives a new signature and a rebuild of that region.
  Not proven by a run.
- **Scale in pret:** 46 `setmetatile` uses in 38 map scripts (+ `elite_four`, `abnormal_weather` 224, `cable_club` includes) and ~140
  `MapGridSetMetatileIdAt` calls in C (`field_specials` 54, `fldeff_cut` 41, `braille_puzzles` 18, `fldeff_misc` 12, `field_tasks` 12 ...).
- **Outdoor swaps that touch the rock/cliff and bridge classes (most likely to matter for height):**
  Route 105, 111 (x2), 120: `General_RockWall_RockBase/SandBase` (0x07C/0x091) become cave entrances when the Regi braille is solved;
  Route 120: Fortree wood-bridge tiles + reflective water; Route 111: Mirage Tower (18 cells, already pinned in the dump drivers);
  Route 103 and Jagged Pass and Meteor Falls: cave-entrance tiles; Sky Pillar door; Lilycove Wailmer boat/water frames;
  Sootopolis City (34 swaps, weather event); cut trees (`fldeff_cut`).
- **Open risk** (needs a run): per-map position tables (`Gen3EmeraldTerraces` rows, `SHAPE_BY_MAP`) and the height pass assume the
  tile that was there at first build; and the kept elevation nibble means a swapped tile keeps the old layer value (the original does
  the same).
- **Suggested check:** a small driver per swap (Route 120 bridge, Route 105 rock wall, one cut tree): build, apply the override through
  `Field.setMetatile`, rebuild, diff the resolved heights with `tools/heights_compare.py`. One batched `qa_run.sh` call.

## Result of the swap run (tools/em_swap_driver.lua, 2026-10-20; two runs of one qa_run.sh call each, same answers)
Driver: `EM_DRIVER=tools/em_swap_driver.lua EM_SWAP_OUT=<dir> tools/qa_run.sh <dir> - 4 0 60`. Window of 13x13 cells per case, tile + shape kind +
collision + resolved ground height (`Scene.groundAt`, px) before and after `Field.setMetatile`; compared with `heights_compare.py diff`.
| Case | Engine | Scene rebuilt | Cells changed | Heights |
|---|---|---|---|---|
| Route 120 bridge clear (4 swaps, 2 change a tile) | applied | within 10 frames | 49 | **48 water cells 0 -> 8 px** (tiles unchanged; rest of the lake joins the 8 px water on its west side) |
| Route 105 rock wall -> ROM cave entrance | already closed at load by the map script; reopening applied | within 10 frames | 2 (cliff -> flat/door) | none (0 -> 0) |
| Route 102 cut grass (8 cells) | applied | within 10 frames | 8 (grass -> flat) | none |
| Controls | no-op swap: 0 cells changed; fresh reload: back to the ROM state, identical to step 0 | | | |
- So **swaps do reach the scene** (rebuild in under 10 frames, tiles and shapes follow).
- **New finding:** on Route 120, applying the bridge swap lifts 48 water cells from sea level to 8 px, though no water tile changed. Probably the
  region/median pin in `TerrainLevels`/`Gen3Elevation` merging two water groups. Players are in this state after the Steven scene, and the
  height baselines (`heights-2026-10-20-fix-F025.txt`) only cover the new-game state.
- Cut trees are NOT tile swaps in Emerald (they are object events); cut GRASS is, and was tested.
- Not compared: the incremental rebuild against a fresh build of the swapped state (the game re-applies swaps only through its own flags).

## Route 120 lake 0 -> 8 px: traced (tools/em_water_driver.lua, 2026-10-20)
Driver dumps the floor solver's own cell record (kind, floor, pin, height, group) for a 13x13 window; run like the swap driver.
- **Not a rebuild artifact:** incremental rebuild and `Scene.invalidate()` + fresh build give identical cells.
- **One tile does it:** swapping only (13,17) (`0x2F4` bridge post -> `0x0A1` reflective water) lifts the whole south lake (x 10-19, y 17-22) to 8;
  swapping only (13,15) changes nothing in the lake.
- **Mechanism (experiment + `TerrainLevels.lua:391-410`):** water cells have no pin of their own (`Gen3Elevation.lua:357,369` skip `kind=='water'`);
  they take the height of their nearest floor, and each connected water body is then set to its lowest cell. As loaded, the post at 13,17
  is a walkable e1 non-water cell pinned 0 (`Gen3Elevation.lua:367-369`), so it is the lake's only 0 anchor. Once it becomes water, the lowest
  bank is the west shore at 8, and the lake follows it. The lake's level hangs on one prop-like cell.
- **Reach in the 53-map baseline (`heights-2026-10-20-fix-F025.txt`):** 588 water cells whose cartridge nibble is 1 (sea level) stand at a
  nonzero height: Route 123 (204: 164 at 48, 40 at 8), Ever Grande (119 at 32), Route 119 (90 at 16), Route 120 (66 at 64), Safari SW (63 at 32),
  Route 114 (46 at 32). Some are probably real raised pools above falls; the nibble cannot tell them apart.
- **Options:** (1) leave it; (2) anchor a water body that touches a bridge deck at the lowest height of its own cells, ignoring the banks;
  (3) pin every e1 water cell to 0 (the header comment's rule) - moves up to 588 cells, needs a look at each raised pool and the heights gate.

## Sea at 0: two probes against the 53-map gate (2026-10-20; NOTHING INSTALLED, mod source untouched)
Probe trees and dumps: `.../scratchpad/sea/` (probe = pin inside the solver, probe2 = set after it); runner `run_dump.sh` (8 batches, em_cells_driver,
`QA_SRC`), compare `heights_compare.py diff CONTROL PROBE`. Control (unmodified code today) differs from the F025 baseline in 101 cells in 13 maps
(other changes since), so the gate compares against the control.
Behaviour census of the F025 baseline: 1,546 ocean-water (MB_OCEAN_WATER 0x15) cells stand off 0 (Ever Grande 413, Frontier West 341, Frontier East 305,
Route 123 253; Routes 122/128/110 stand BELOW 0 at -48/-32/-16).
| | cells moved | ocean -> 0 | ocean elsewhere | land / other water moved | ocean still off 0 |
|---|---|---|---|---|---|
| probe: `(sea and 0)` pin in `Gen3Elevation` reader | 3,586 in 21 maps | 1,490 | 16 (-16, +16) | 1,926 + 52 | 68 (Route 114 pond 34, Route 110 30, Mossdeep 4) |
| probe2: `c.height=0` for sea cells after `Levels.build` | 1,813 in 13 maps | 1,192 | 99 (16/32/-16) | 470 + 52 | 366 |
- Probe 1 fails the plan's pass criterion: land that had taken the sea's height follows it down (Slateport trees/fences 16 -> 0, Southern Island cliffs
  16-48 -> 0, Frontier East cliffs/flat 8-32 -> 0, Ever Grande). Shots (10 spots, levels 4 and 7): Route 123 improves (a white void patch in the sea is
  gone); Battle Frontier East regresses (ground under a raised slab drops, the slab stays); the rest look the same.
- Probe 2 fails too: later passes (not `Gen3Elevation`; likely `Gen3Scene` region alignment/relief and the support fill) change sea cells again, and
  neighbours still move. The sea height is not decided in one place.
- Not done: finding the downstream writer of water height, the Route 120 swap rerun against either probe, the level 4/6 shots of probe 2.
