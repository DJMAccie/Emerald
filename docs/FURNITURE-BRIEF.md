# Brief: pixel-voxel furniture for Emerald's interiors (second agent)

Read `HANDOFF.md` (paths and rules) and §0 of `docs/NEXT-AGENT-BRIEF.md` first. Two other agents are working at the
same time:
- **Opus** (session "Handoff.md review"): buildings and furniture in the common rooms.
- **Sonnet** (session "Sonnet brief"): signs, props and terrain.

Your job is more furniture, in the rooms Opus is not doing.

## The goal (user's words)
"Go after the feel, vibe and aesthetic of the OG, but in 3D." From the game camera a room must look exactly like
Emerald. Turned, every object is a whole 3D thing (a table has a top, legs and open space under it), made from its
own art's pixels. "Add pixels if needed to create a fully formed 3D model": hidden sides, backs and legs are
copied from the object's own pixels. Never stretch a pixel, and never invent colours.

## How it works (already built; read `lib/Gen3PixelFurniture.lua`, it is short)
Gen 3 draws rooms obliquely: a point at height `y` and depth `z` appears on drawing row `z - y`. So a furniture
drawing is described as **parts**, each a run of columns:

`{x0, x1, front, h, solid, firstRow}`
- `x0..x1-1` are the part's columns, in local pixels of the recipe (0 = left edge of its first tile).
- `front` is the last drawing row of its **top surface**. Rows `firstRow..front` lie flat on top at height `h`.
- `h` is its height in pixels. The rows `front+1 .. front+h` are its **front face**. So the bottom of the object in
  the drawing (where it meets the floor) is row `front + h`.
- `solid` = true for boxes (cabinets, backrests, poufs, wardrobes). Leave it out for hollow pieces (tables, seats,
  beds): those keep open space underneath. Narrow front-face runs that reach the floor row become legs, repeated at
  the back.
- `firstRow` (optional) is where the part's top starts. Use it when parts are stacked in one column, like a
  headboard behind a mattress.

The recipe also takes:
- `groundMids`: floor tile ids. Colours from the inside of these tiles are not part of the object.
- `shadowPoints`: local pixels whose colour is floor shadow, also not object.
- `height`: what items stand on.

## Your file: `lib/Gen3PixelFurnitureB.lua` (yours alone)
It returns a list. Each entry is the argument list of `add()`:
```lua
return {
 {'em_dome_bench', 'battle_dome', {{0x2A0,0x2A1}}, {{1,31,9,6}}, {0x201}, {{2,14}}, 6},
}
```
- `name` must be unique and start with `em_`.
- `secondary` is the room tileset key, the pret name after `building__` (or `general__` for the Bike Shop and
  Space Center). The tilesets are listed in `~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/`.
- `rows` are the metatile ids, row by row: `{{top-left, top-right},{bottom-left, bottom-right}}`.

Pixel recipes always outrank the older flat reliefs, so you never need to edit `Gen3EmeraldInteriors.lua`.

**Do not edit** `Gen3PixelFurniture.lua`, `Gen3Furniture.lua`, `Gen3EmeraldInteriors.lua`, `BuildingVoxels.lua` or
anything in `data/buildings`. If you need a builder feature (for example a raised object standing on a table, a
round top, or a part that starts above the floor), send a message to session "Handoff.md review" saying what and
why.

## Tools (run from `~/Documents/Emerald/tools/buildings`)
- `python3 midgrid.py out.png MAP PAIR`: the room's art with every cell's metatile id. `#` = blocked.
- `python3 pxmap.py MAP PAIR x0 y0 x1 y1 GROUNDMID[,…]`: a piece's pixels as letters, with `.` = floor. Read
  `front` (last top row), `h` (face rows down to the floor row), the leg columns and the shadow colours off it.
  Count rows from the crop's top: the crop starts at `y0`, so local row = printed row − 16·(tile offset).
- `qa_capture.sh <outdir> "{'MAP',x,y},…"`: in-game shots at the player's camera on the QA identity. It waits for
  any running game. Stand 1–2 cells below the furniture on a walkable cell, never on a door.
- For a turned view, copy the commands from `qa_capture.sh` and set `EM_LEVELS` to a file with `return {7}` plus
  `EM_YAW=-0.7` (radians).
- Every Emerald indoor map, captured at the player's camera: ask Opus for the contact sheets, or run the
  `c_allint` case list. Map ids are `EM_` + the pret name in upper snake case.

## Worked examples (in `Gen3PixelFurniture.lua`)
- **House dining table**: `{{2,30,22,9}}`. Top to row 22, 9 tall, hollow, gold legs found automatically.
- **Chair**: backrest `{10,15,7,8,true}` plus seat `{1,10,10,5}`.
- **Bed**: headboard `{4,28,4,12,true,0}` plus mattress `{4,28,24,6,false,11}`.
- **Wardrobe**: `{{1,31,1,30,true}}`.
- **Center stool**: `{{1,15,9,5,true}}` with a shadow point.
- **Against the north wall**: kitchen `{{0,32,18,20,true,12}}` with `wall=32`, the 8th add() argument. The wall
  art above the piece is drawn on the wall plane, so the wall stays intact.
- **Drawer unit below the wall**: `{{0,32,1,22,true,0,16}}`. The 7th part field (`backZ`) is how far back the
  solid box reaches; 16 = the wall plane when the recipe starts one row below the wall top.
- **The room wall plane** is 2 tiles below the room's top row (z = 32 from the top). A cabinet's floor row
  `front + h` sits just in front of it.

## Your rooms (Opus does houses, Brendan's and May's house, Centers, Marts and Birch's lab)
1. **Gyms**: Rustboro, Dewford, Mauville, Lavaridge, Petalburg, Fortree, Mossdeep, Sootopolis. Statues, benches,
   and the maze pieces that are furniture rather than walls.
2. **Battle Frontier and the Battle Tents**: lobby seats, counters, lounge furniture, Pike curtains and chairs,
   Factory machines, Arena benches.
3. **Lilycove Department Store** (all floors), Contest Hall and lobby, Lilycove Museum.
4. **Special rooms**:
   - Rustboro Pokémon School (desks: a good first piece), Devon Corp, Oceanic Museum, Weather Institute.
   - Pretty Petal flower shop, Day Care, Fan Club, Game Corners, Trick House, Elite Four rooms, cable car stations,
     Seashore House, glass workshop.

## Workflow per batch
1. Pick a room, run `midgrid` and `pxmap`, and write recipes in your file.
2. Check the syntax: `luajit -e "assert(loadfile('lib/Gen3PixelFurnitureB.lua'))"`.
3. Copy only your file to QA: `cp lib/Gen3PixelFurnitureB.lua "<QA>/mods/BATTLE_ART_VOXEL_FORK/lib/"`.
4. Capture at the player's camera and **zoom in on the furniture**.
   - Head-on it must match the original.
   - Turned it must be a whole object: no floating floor patches, no black squares, nothing stretched.
   - Black under a piece means its `groundMids[1]` floor is wrong.
   - A flat smear means `front` or `h` is off; check the bottom row = `front + h`.
5. Install only your file to the real game: run `pgrep -fl "MacOS/love"` first, back up outside `mods/`, then
   copy.
6. Commit:
   ```bash
   cd ~/Documents/Emerald && tools/buildings/make_patch.sh
   ```
   Commit `patches/battle-art-voxel-fork.patch` with a clear message. The user wants pushes now and then:
   `git push origin main`. Check that no ROM-derived files are in the diff.
7. Tell the user in a few lines what you did and show one zoomed before/after.

## Rules
- One game instance at a time. `qa_capture.sh` waits; never kill another run.
- Never commit ROM-derived files: atlases, `.rgba`, captures, `world.json`, ROMs.
- Judge only at the player's camera at full resolution. The user is very critical and will look closely.
- Never install anything that looks worse than before.
