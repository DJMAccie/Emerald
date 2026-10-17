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
