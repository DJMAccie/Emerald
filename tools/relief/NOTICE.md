# Third-party notice: Emerald 3DS relief method

The level counting in this folder (`terraces.py`: the General-tileset tile
tables, the cell kinds, the runs of rock, the union-find vote over terraces,
the levels, the corner/piece settling, `piece_grid`, and the ledge berms) is a
Python port, adapted to this project's map cache, of the terrain ("relief")
method in Emerald 3DS:

- Project: ZallaxDev/pokeemerald-3Ds-dualscreen, commit b98cc23
- Files studied: `3ds_port/scripts/voxel_terraces.py`,
  `3ds_port/scripts/gen_voxel_relief.py`,
  `3ds_port/src/voxel/voxel_mesh_builder.c` (EmitRelief, EmitCliffWalls)

Only that project's own port code is used here, under its MIT licence
(`LICENSE-PORT.md`, which covers `3ds_port/`). None of its code is imported,
built or run; nothing ROM-derived and no pret/pokeemerald lines are copied.
Where this folder departs from the original (our map cache, an alias table
for Fallarbor's brown terrace, single-map solves, tree cards in the renderer,
the "soft tops" variant) the source says so.

## Licence (MIT)

Copyright (c) 2026 Zallax and Emerald 3DS contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Data file check, 2026-10-19 (`relief_fixes.json`)
Read: `LICENSE-PORT.md` and `docs/PROVENANCE.md` of ZallaxDev/emerald-3ds. The MIT licence covers original code, tooling and documentation in `3ds_port/`, `builder/`, `tools/`, `docs/`, "unless a file states otherwise", and excludes Pokémon Emerald content and "data generated from a ROM" (their example is `emerald3ds.pak`). Neither document names `3ds_port/assets/voxel/relief_fixes.json`: by location it sits under `3ds_port/` (their asset-pipeline page calls it hand-authored corrections for cells the generator reads wrong), but no document says whether those per-map levels count as original work or ROM-derived data.
Status (updated the same day, after the user's yes in chat): `relief_fixes.json` (69,661 bytes, main branch) was downloaded to a scratch folder only. It holds one layout, `LAYOUT_RUSTURF_TUNNEL` (771 cells with levels or 5x5 height grids, belt 48); `furniture` and `pieces` are empty. Nothing was copied into this repo and nothing imported. The earlier text below still applies if a larger file appears on their `dev` branch.

Earlier status: file NOT downloaded and nothing imported. If it is used, use it for comparison only (a disagreement list against our solved levels, nothing copied into this repo), and ask the author in an issue if any of it should ship.

## Comparison study, 2026-10-20 (`docs/COMPARE-3DS-v0.4.0.md`)
Read only, to compare methods for five areas; nothing copied, ported, built or run from it. Source: ZallaxDev/emerald-3ds, tag v0.4.0 (commit b98cc23) and its `dev` branch (7a0b250), under the same MIT licence for `3ds_port/`, `docs/` and `tools/` (`LICENSE-PORT.md`).
- Files and parts read: `3ds_port/scripts/voxel_bridge.py` (Cycling Road: docstring and constants); `voxel_building_specs.py` (the Rustboro fountain, Trick House, Route 109 parasol, lounger and mattress, Slateport sailboat, rowboat, bollard and Contest Hall docstring); `voxel_building.py` (module docstring); `gen_voxel_relief.py` (docstring, `ledge_berms`, `ledges_on_ground`, ledge constants); `voxel_terraces.py` (`GROUPS`, `region_ties`); `voxel_relief_fixes.py` (docstring); `assets/voxel/relief_fixes.json` (shape and counts only, summarised as the comparison doc does; no cell values copied); `docs/VOXEL_GUIDE.md`, `VOXEL_MOUNTAINS.md`, `VOXEL_STATUS.md`; `CHANGELOG.md`; the `terrace_debug/README.md`.
- What it informs: methods described in prose in the comparison document (ledge lip shaping, bridge-as-model, turned and sectioned props, a fountain made of plan prisms and a jet card). Any later port is written in Lua or in our offline Python from that description, measured on our own art, and gets its own entry here.
