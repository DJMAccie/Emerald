# Overnight goal, 2026-10-05: finish the detail work on the tiles

**The user's words:** "finish all the detail work on the tiles tonight". Also: "go after the feel, vibe and
aesthetic of the OG but in 3D", "we must introduce more depth since we are making it 3D, the OG was super flat",
"make me proud when I see your work tomorrow".

Opus (session "Handoff.md review") leads. Furniture (session "Furniture brief") and Sonnet (session "Sonnet
brief") report to Opus with SendMessage. Everyone works until their queue is empty, then asks Opus for more.

## Rules for everyone (no exceptions)
1. **Pixels:** every model is built from the original tile's own pixels, one pixel per voxel. Nothing stretched,
   no invented colours. Hidden sides, backs and legs copy the object's own pixels.
2. **More depth:**
   - Heights read off the flat art are a MINIMUM.
   - Furniture already gets about 1.6x height (Gen3PixelFurniture.LIFT).
   - Props, rocks, cliffs, fences and ledges should also stand taller and deeper than the drawing.
3. **Three cameras for every change before installing:**
   - Player's camera: `tools/buildings/qa_capture.sh`, level 4, zoom 0. Must still look like the OG.
   - Turned orbit: level 7 with `EM_YAW`.
   - LOW near-ground camera: level 6 with `EM_YAW`.

   Zoom into the thing you changed. Install only what is better than before.
4. **Engine:** `~/Documents/gen1recomp` is at **v0.3.52**, the version the user plays.
   - Tile atlases are built only when a map is VISITED in QA, and are zlib-compressed.
   - `tools/analysis/layers.py` reads them. Visit a map once (one `qa_capture.sh` case) before running
     `pxmap.py` or `midgrid.py` on its tileset.
5. **One game instance: start EVERY game run through `tools/qa_run.sh <out> "<cases>" [level] [yaw] [wait]`**
   (level 4 = player's camera, 7 = orbit, 6 = low). It takes an atomic lock (`/tmp/emerald-qa.lock`) and has a
   watchdog, because two instances started together deadlock (it happened twice tonight). If you must launch
   by hand, take the same lock with `mkdir`. Otherwise wait with `pgrep -x love`, never `pgrep -f "MacOS/love"`. The `-f` pattern matches
   your own waiting shell, which makes runs hang and overlap. If a log says "payload handoff failed", the run
   overlapped with another instance, so rerun it. Never kill a game you didn't start.
6. **Own files only:**
   - Install only your own changed files to the real game, backed up first outside `mods/`.
   - Commit the patch with `tools/buildings/make_patch.sh` (Opus) or your own scheme. Pull before you push.
   - No ROM-derived files in commits.
7. **Report:** after each batch, send Opus 2-3 lines: what changed, where, and the commit hash.

## Furniture: every interior piece in 3D
Read `docs/FURNITURE-BRIEF.md` (how the builder works) and `lib/Gen3PixelFurniture.lua`. Your file is
`lib/Gen3PixelFurnitureB.lua`.

**New tonight:** you now own ALL remaining interior furniture, including the rooms Opus had. Opus has moved to
stairs, terraces and buildings. Leave the pieces already in `Gen3PixelFurniture.lua` as they are; add new pieces
in your B file.

**Builder features you can use:**
- `wall` (8th add() arg)
- `opts` (9th): `{dais=true}`
- Part fields:
  - `firstRow` (6, may be negative: reads the cell above)
  - `backZ` (7)
  - `round` (8): `true` follows the outline, `'disc'` is an ellipse.

**Queue, in order (biggest player-facing value first):**
1. **Pokémon Center 1F, all 34:**
   - The front desk as a counter you can't see through.
   - The PC terminal on the right, the plants (`'disc'` pots plus leaves), the corner bench.
   - Keep Nurse Joy's cell and the counter interaction cell walkable as they are; only the drawn furniture
     becomes 3D.
2. **Poké Mart, all 23:**
   - The tiered display racks: shelves at several heights from the art, not one slab.
   - The counter, the magazine rack, the plants.
3. **The shared house tileset (`generic_building`, 73 houses) leftovers:** TV sets, plants, PC desks, the
   kitchen sink and stove variants, bookshelves not done yet, dressers, flower vases.
   - Use `tools/buildings/midgrid.py` on Dewford, Fortree, Lilycove and Mossdeep houses to find their own pieces.
4. **Gyms (all 8):** continue as you were.
5. **Battle Frontier and Battle Tents, Lilycove Department Store (all floors), Contest Hall, museums, Devon,
   Weather Institute, Trick House, Game Corners, Elite Four, school, flower shop, Day Care, Seashore House,
   cable car stations.**
6. **Disc bark (Opus will add):** you asked for cylinder sides that repeat the face columns round the curve.
   Opus will message you when it's in.

## Sonnet: every outdoor prop and terrain tile in 3D, with depth
Read `docs/SONNET-BRIEF.md`. You own Gen3Terrain, CliffMasonry, Gen3Objects, Gen3Mass, the props tools and the
skirt block in Gen3Scene. Opus owns Gen3Elevation, Gen3Stairs, Gen3EmeraldTerraces, buildings and the furniture
builder.

**Queue, in order:**
1. **Signs and props, every town and route:**
   - Signs, mailboxes, fences, flower beds, the Slateport market stalls, item balls, berry trees, smashable and
     strength rocks, lamp posts, benches, statues, fountains.
   - Each one as pixel voxels with MORE depth than the art: posts taller, fences thicker, rocks rounder.
   - Check Littleroot to Ever Grande.
2. **Ledges and cliffs with real height:**
   - One-way ledges should drop visibly.
   - Cliff faces must meet the floors Opus sets (Opus will message you when terrace levels change).
3. **Shorelines:**
   - The duplicated shoreline (far corners of coast views).
   - Sand/water edges.
   - Sea rocks: the water around them must stay flat.
4. **Tree tops:**
   - Canopy art still painted on the ground under 3D trees.
   - Bushes and hedges with volume.
5. **Water and bridges:** Routes 110, 119 and 120 bridges (you started this); the Pacifidlog boardwalks.

## Opus: stairs, terraces, buildings, coordination
1. **Raised platforms wherever stairs climb.**
   - Gen3EmeraldTerraces holds the authored Sootopolis, Fortree and Route 112 levels.
   - Found tonight: they never applied (the cartridge's flat nibble outvoted every anchor in its group's
     median), and enabling them for Sootopolis hangs the scene build. Debug that, then turn the maps on one at
     a time.
   - Stair-cut platform finder: `tools/elevation/stair_platforms.py`.
2. **Disc bark for Furniture.** More depth on buildings: steps at doors, porches.
3. Keep the other two unblocked: answer feature requests fast.
4. Make sure the user's real game starts the newest version (see "Engine" in the morning report).

## Morning report (Opus writes it)
- What changed overnight, per agent, with commits.
- One before/after image per area: interiors, props, terraces.
- Anything still open.
