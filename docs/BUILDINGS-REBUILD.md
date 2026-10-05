# Rebuild every building as voxels (plan, 2026-10-05)

The user wants every outdoor building investigated one by one and rebuilt in voxel style, built from its
own art with **no stretched pixels**. Complex unique buildings that still have no proper 3D version are
the priority.

## THE CHECKLIST: `tools/buildings/inventory.py` (use this, not the old catalogue)
`python3 tools/buildings/inventory.py <outdir>` → `inventory.json` + `inventory_01..06.png`.
- **162 buildings**, found from the cartridge's own doors: every outdoor warp into an interior.
- Each is labelled with the game's own name for it (e.g. `LilycoveCity_LilycoveMuseum_1F`), and each
  pane shows the original drawing around its door.
- The user's named examples:
  - **#29 RustboroCity_DevonCorp_1F** (the north-west Rustboro building).
  - **#44 LilycoveCity_DepartmentStore_1F**.
  - **#47 LilycoveCity_LilycoveMuseum_1F** (next to the store).
  - **#132 Route119_WeatherInstitute_1F**.
- Also listed:
  - Contest Lobby #48, Oceanic Museum #12, Stern's Shipyard, Game Corner.
  - All the Fortree tree houses, Cable Car stations, Day Care, flower shop, Trainer Hill.
  - Every Battle Frontier building.
- Numbers are stable as long as the cache doesn't change. Panes near a map's top edge are clipped.
  A pane centres on the door, so check the label against the building above the door.

## The old catalogue (INCOMPLETE — kept only for the shots_bld/bNNN numbering)
`tools/buildings/catalogue.py <outdir>` writes `catalogue_01..05.png` and `catalogue.json` from the local
QA cache (nothing ROM-derived is committed).
- Each pane shows one building's original 2D drawing, numbered like `cases_buildings.lua` and
  `shots_bld/bNNN.png`, with its map, footprint in cells, and simple/large.
- `buildings.json` has only 107 entries and misses about 55 buildings (museum, Devon Corp, every Fortree house, many Marts/Centers, all route buildings). Earlier this doc called b025 "Devon Corp"; that was WRONG (b025 is another Rustboro office). There are 107 buildings, 80 of them larger than 5×4. Work through them in this order and record a
  status per number in a table at the end of this file: `template:<family>`, `recipe`, `generic-ok`
  or `todo`.

Watch out: some inventory boxes join two buildings (b001 is 15×2 = two Petalburg houses; b010 Slateport
is two houses). Split those first. The inventory comes from
`~/Documents/gen1recomp-modwork/buildings.json`, made by `gen_emerald_tables.py` (door-anchored).

## The method: one pipeline for sprites and buildings
The other agent's landmark tool is the right engine for buildings too:
- `lib/SpriteVoxel.lua`: a recipe is a list of boxes, and each face is painted by a rectangle of the
  drawing. Faces are emitted only on the boundary, and coplanar faces of one paint merge.
- `lib/LandmarkModels.lua`: gid → recipe. The truck (gid 94) is the worked example.
- `tools/model_preview.py`: previews a recipe offline in seconds. Iterate there, not in game captures.

Gen 3 map art uses the same oblique projection as the sprites: a pixel's screen row = height + depth.
So a building drawing contains its south facade 1:1 and its roof or plan view 1:1 above it, exactly
like the truck. Read the bands off the drawing and write boxes.

**What is new for buildings: a tile drawing as the source image.**
1. `BuildingModels.lua` (new): at scene build, compose the building's metatiles (its box, plus the
   walk-behind roof rows above it, plus the layer above the player) into one ImageData. This is the
   same compositing as `voxproto.art()` / `Gen3Objects` `pixel()`. Then hand it to SpriteVoxel as the
   recipe's image.
2. **Recipe key: the building's top-left metatile ids**, e.g. the Center's `0x048..0x063`, plus the
   tileset pair. Every Pokémon Center in every town then shares ONE recipe; recolours come free
   because the pixels come from that town's tiles.
3. Cells covered by a recipe are claimed, like `c.civic` / `c.prop`, so the generic column renderer and
   `Gen3VoxelBuildings` skip them. Draw the model through the scene batches (`quad` into `b.v`) or as a
   mesh like the truck, and lift it with `Elevation.lift(..., groundHeight)` so it sits on its terrace.
4. Unrecognised buildings keep a generic fallback. Use `Gen3VoxelBuildings` (pixel-voxel columns, docs/VOXEL-BUILDINGS.md;
   three known defects to fix first) instead of the old stretched columns.

## Families (one recipe each, reused everywhere)
These come from catalogue sheets 1–2; finish the list from sheets 3–5.
- **Pokémon Center:** b004, b009, b012, b022, b039, … Curved roof with the ball logo; drum front. Recipe:
  the body box, a stepped roof volume (2–3 boxes following the curve), and the entrance porch.
- **Poké Mart:** b003, b014 (right half), b023, … Same build as the Center, blue.
- **Gym:** b002, b011, b016, b026, b035, … Flat roof, side wings, the entrance block that juts out, and the
  sign post (sign = `Gen3Objects` slab).
- **Town house types**, one recipe per town style:
  - Petalburg red tile roof: b005, b006.
  - Slateport purple: b008, b010.
  - Mauville pink/yellow: b013, b015.
  - Rustboro grey flat-roof office: b017, b018, b019, b020, b021, b024. These are all the same
    building in different widths, so a parametric recipe (width in cells) covers them.
  - Lilycove blue: b028, b029, b030.
  - Mossdeep red balcony: b033, b034, b036, b038, b040, b041.
  - Sootopolis cube house and dome house: b043–b048.

## Unique buildings (one hand recipe each, highest care)
- **#29 Devon Corporation** (north-west Rustboro, doors 11–12,15):
  - A tall grey office block: three window storeys and a flat roof with a parapet.
  - Recipe: the main block (height = facade rows), a roof slab inset by the parapet, the entrance
    portico, and the corner columns as separate thin boxes so they stand proud.
- **#44 Lilycove Department Store**:
  - A tall pale-blue tower with a Poké Ball logo and many window rows; the rooftop is visible.
  - Recipe: the tower box, the ground-floor entrance band (awnings as thin boxes sticking out), the
    roof parapet, and the rooftop details.
- **#47 Lilycove Museum**: white building with a flat roof and side wings, next to the store.
- **#132 Route 119 Weather Institute.**
- **#12 Slateport Oceanic Museum**, Stern's Shipyard, the Mauville Game Corner.
- **#48** Lilycove Contest Hall: a large dome/blue roof over a red front.
- **b037** Mossdeep Space Center: a domed centre, side wings and the launch towers.
- **b007** Slateport Contest Hall: a round orange dome.
- **b032** Lilycove Cove Lily Motel / striped building.
- **Fortree tree houses.**
- **Battle Frontier buildings:** Pyramid, Palace, Tower, Dome, Arena, Factory, Pike.
- **Mauville bike shop and game corner.**
- The rocket and boats are sprites, handled by `LandmarkModels`.

## Order of work
1. Implement the tile-drawing source in `BuildingModels.lua`. Prove it with the Pokémon Center: one
   recipe used in Petalburg, Slateport, Mauville, Rustboro and Mossdeep at once.
2. The user's named examples: Devon Corp #29, Department Store #44, Lilycove Museum #47, Weather Institute #132.
3. Mart, Gym, then the house families.
4. The remaining unique buildings.
5. The generic fallback (`Gen3VoxelBuildings`, after its three fixes) for anything left.

## Definition of done per building
- Head-on (level 4): the model's screen image matches the 2D drawing. Do a pixel diff of a crop
  against `bld2d.py` output, and check that nothing is stretched (one art pixel = one world pixel).
- Turned (level 7, yaw 0/90/180/270): closed volume, no dark slabs, no floating parts, sitting on its
  elevation.
- Both views reviewed at full resolution with nearest-neighbour crops, never thumbnails (the user's rule).
- QA first, then a backup, then install. Wait for `pgrep -f MacOS/love` to be empty before every run;
  two agents share QA.

## Status table
| # | map | family / recipe | status |
|---|---|---|---|
| #29 | Rustboro | Devon Corp (unique) | todo |
| #44 | Lilycove | Department Store (unique) | todo |
| #47 | Lilycove | Museum (unique) | todo |
| #132 | Route 119 | Weather Institute (unique) | todo |

(Numbers here are inventory.py numbers.)


## User's notes, 2026-10-05 evening (do these)
- **Roofs are symmetric gables.** The horizontal line across a house roof is the RIDGE: below it the
  front slope, above it the back slope seen foreshortened. Chimneys and vents sit on the ridge.
  - Use `('gable', nf, nb)` in `hf.py`; the pitch is `(nf-nb)/(nf+nb)`, with equal depths both sides.
  - Birch's lab is redone this way: `('gable', 36, 14)`, with the vent low on the ridge. It's exported but NOT yet
    QA-checked in game. The Littleroot houses' style (the user likes them, "Japanese roof") stays.
  - The Center and Mart are domes, not gables.
- **Route 101/103 screenshot issues**, for a terrain/props pass:
  1. **Signs take the grass colour.** The sign slab is cut against the ground and loses its own
     pixels, or is painted from the wrong tile.
  2. **Sea boulders (banks) lift the water drawn in their tiles:** a blue mound around each rock.
     A bank must only raise pixels that are rock, and keep water pixels at water level
     (cut against the water tile, like Gen3Objects cuts against ground).
  3. **Shoreline duplicated** in the far top-right corner, and a raised grass square sticks out at a
     shore corner (Route 103 near the player).
  4. **Tree canopies:** the flat ground tile under a 3D tree still shows the drawn tree top, which is
     confusing under the voxel tree. Replace it with that tile's plain ground.
- **Mods** (2026-10-05):
  - The Stadium importer was OFF for Emerald (`modsByVersion.emerald`), which is why there were no 3D
    battle models. Set to true.
  - `better_buildings` (runs on every game) is now off for Emerald.
  - Ground spawns are set to Low.
  - Wild Skies has a new VERY LOW level (cap 1, cooldown 20 s; patched in both identities, backups in
    `gen1recomp-modwork/backups/2026-10-05-wildskies/`), selected for the user.


## Status 2026-10-05 late: 81 of ~130 recognised buildings are pixel-voxel models (installed)
- **Hand-built:** both Littleroot houses, Birch's lab (gable), the Pokémon Center family, the Poké Mart family.
- **Automatic: 74 buildings** from `tools/buildings/autorecipe.py`.
  - Pipeline: `groups_engine.lua` gives the engine's own building boxes and facade line
    (`luajit groups_engine.lua > egroups.json`, run from ~/Documents/gen1recomp).
  - Ground is cut positionally against the walkable tiles around each building, flooded from outside.
  - The ridge is the topmost dark full-width roof row → symmetric `gable`; no ridge → flat roof.
  - Output goes to `data/buildings/bNNN_*.lua` plus `index.lua`.
- **Still old renderer, need hand recipes** (`SKIP` in autorecipe.py):
  - Mauville House1 (#21, merged with a neighbour).
  - Sootopolis drums and dome houses (#69-77).
  - Lavaridge red houses (#92, #96: the roof is cut away).
  - Verdanturf Battle Tent (#103).
  - Pacifidlog huts (#110-114).
  - Cycling Road gates (#119-123).
  - Battle Frontier Dome, Factory, Tower and Arena (#141, 142, 150, 151).
  - Every building without an engine footprint (~30: the Fortree tree houses, Devon Corp, the museums,
    the Weather Institute, the harbors, the Battle Pyramid and Palace...).
  - Also redo the Mossdeep balcony houses (#56, 59, 61-63), which read as striped cages in game.


## Beyond buildings: every asset in voxels (user, 2026-10-05)
The goal covers ALL assets, not just buildings. Work order after the remaining buildings:
1. **Signs** (route signs, town signs, house mailboxes): currently grass-coloured (`Gen3Objects` cuts
   their pixels away). Make one hand model per sign drawing: post + board, with the board's art on its
   front face. These are few, repeated everywhere, and high visibility.
2. **Overworld items and small props:** Poké Ball items, berry trees, rocks you can smash or push
   (Strength boulders), cut trees, flower pots, mailboxes, lamp posts, benches, boats.
   - The ones that are object-event sprites go through `LandmarkModels`/`SpriteVoxel` (like the truck),
     by graphics id from pokeemerald's `include/constants/event_objects.h`.
   - Tile props go through `Gen3Objects`.
3. **Terrain issues from the user's screenshots:**
   - Sea-rock banks lift the water around them.
   - A duplicated shoreline.
   - Flat treetop tiles under the 3D trees.
4. **Interiors:** never reviewed. Do it the same way: catalogue every interior type (houses, Center, Mart,
   gyms, lab, Devon, museum…), check each at the player's camera, and model furniture as voxels
   (`Gen3Furniture`, `Gen3EmeraldInteriors`).
5. **Note:** github.com/GazPrash/2d-to-3d-voxelizer (MIT) was considered and is not useful here. It
   extrudes one sprite or combines 4–6 side views; Gen 3 only has one oblique view, which our pipeline
   already reads.
