# Voxel buildings: no stretched pixels (work in progress, 2026-10-05)

The user's direction: **build the world as voxels that look like the original art, never stretch a pixel.**

## Rule
One art pixel = one voxel (16 per cell, the world's own scale). Every visible face shows exactly one
pixel of the drawing.
- Facade rows stand on the front plane, as tall as they are drawn.
- Roof rows become voxel steps rising toward the back. Each art row is one step, so the slope is built
  from the drawing's own pixels instead of a texture stretched over a slab.
- The drawing's ground (grass beside a rounded roof, gaps beside walls) is cut away pixel by pixel
  against the ground tile.
- A walkable roof row (painted over the ground behind the house) uses only its art on the layer above
  the player.
- Body, sides and back use the commonest pixel of each art row (the row's material).

## Where it is
- `battle-art-notquiteog/lib/Gen3VoxelBuildings.lua` (a copy is in `tools/voxel_proto/`).
  - **`M.enabled=false`**, so it is NOT installed and not active in QA.
  - Turn it on to work on it.
- Hook in `Gen3Scene.lua`: the `elseif column and not column.indoor and VoxelBuildings.enabled` branch
  before the old column renderer. Chimneys are skipped while it is on.
  - When `enabled=false` the old path runs unchanged.
- Offline prototype with a game-camera renderer: `tools/voxel_proto/voxproto.py`.
  - It shows the Pokémon Center head-on and turned, next to the original.
  - Iterate shapes there first: it takes seconds, with no game run.
- Faces are greedy-merged per texel and use the scene's usual two-pass atlas drawing.

## State (QA captures, Petalburg and Littleroot, levels 4 and 7)
- **Good:**
  - Head-on, the Pokémon Center, Mart, houses and Gym show their original drawing.
  - The double-perspective Center roof is gone.
- **Still wrong:**
  1. **Mart:** a strip of the fence or tree art behind it sits on top of the roof. The roof's top row is
     adopted from a neighbouring cell (`hasOverArt` / `roofMid` adoption in `Gen3TileShape.layout`);
     cut it against its real ground or drop adopted rows.
  2. **Gym:** tan blocks at the facade base. Probably wall rows below the facade line, or the old
     plinth logic; check `column.wallTop` and `rowStep`.
  3. **Free camera (level 7):** a house back is a dark plain slab. The back and side material comes from
     an outline-dark row. Pick the material per row from the inner columns, excluding near-black
     outline colours, or use the facade's `wallColumn` logic from `Gen3Scene`.
  4. Roofs seen from the side are stair-stepped. That is the voxel style; keep the steps one art row
     each so they stay pixel-clean.
- **After those:** run the 107-building sheets (`EM_INDEXED=1 EM_CASES=cases_buildings.lua`) and compare
  every building head-on with its 2D art (`tools/bld2d.py`). Install only when head-on views match the
  original and turned views have no dark slabs.

## Round 2 (2026-10-05 evening, still OFF)
Fixed:
- **Mart top strip.** The top roof row keeps only pixels in the roof's own palette (from the rows below
  it and its neighbours). Petalburg's Mart roof row `250/251` is drawn merged with the pond fence.
- **Ground cut.** Every walkable tile in front of the building counts as ground, not just the shape's
  ground.
- **Walkable cells.** A walkable roof or wall cell uses only its above-player art when it has some. A
  walkable facade corner with none is ground drawn into the outline and is dropped.
- **Bodies.** The body repeats the facade's own pixels (siding, windows), with outer columns taken just
  inside the outline. Backs and sides now read as the same building.
- **Row material.** It skips dark outline/glass pixels.

Result at level 7 (Petalburg, Rustboro, Lilycove, Mossdeep, yaw 150):
- The Rustboro offices and the Lilycove Department Store read as real voxel buildings, with windows on
  every side.

Still open:
- One Petalburg red house side is a dark flat slab. Its facade column 2 is the dark trim; pick the side
  column with `wallColumn()` logic from `Gen3Scene`.
- Petalburg Gym: tan corner pieces at its front (cells `1C9`/`1CC` at row 8, walkable). The walkGround
  rule did not remove them; check that those cells are in this column (`column.last`) and what their
  over layer holds.
- A brown cone in central Lilycove (not a building; probably a `Gen3Objects` slab or a bank). Investigate.
- The level-4 captures in this run framed the whole town (`EM_YAW` set). Re-capture level 4 without
  `EM_YAW` for head-on judgement.

The DeepSeek agent's parallel attempt (`.qa-stage/landmark/lib/BuildingVoxel.lua`, `tools/buildings/bld*.py`,
`gamecam.py`) builds one mesh per building with a height scale of 1/cos(pitch). Its offline fitter
rendered the Center as a flat garbled sliver, so it is unfinished. `Gen3VoxelBuildings` is the path
that works in game today. Merge the camera-exact `gamecam.py` idea in for offline judging.

## Next, same rule for the rest of the world
- **Cliffs and shorelines:**
  - Faces repeat the face drawing one pixel per voxel down the height, never stretched.
  - Caps are the drawing on top.
  - Coast outlines follow the drawn edge.
- **Ground stays a flat plane;** it is already 1:1.
- **Props and trees:** `Gen3Objects` slabs already follow this rule.
- **Truck and other landmarks:** these are sprites (`OBJ_EVENT_GFX_TRUCK = 94`). The other agent is
  building a sprite-to-voxel tool (`docs/SPRITE-TO-VOXEL-PLAN.md`).

## Coordination
Two agents share the QA identity, and only one game instance can run. Before any capture:
- Wait for `pgrep -f MacOS/love` to be empty.
- Re-check right before launching.
- Never leave experimental modules enabled in QA after your run. One agent's truck run on
  2026-10-05 ~13:35 happened while `Gen3VoxelBuildings` was enabled in QA, so its building
  appearance in those shots is not the shipped look.
