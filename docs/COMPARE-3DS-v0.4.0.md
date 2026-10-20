# Emerald 3D vs Emerald 3DS v0.4.0: five areas, method by method

Written 2026-10-20 by a read-only study session (no mod source edited, nothing installed, no subagents). Upstream: ZallaxDev/emerald-3ds, release v0.4.0 (tag, commit b98cc23, 2026-10-16), plus its `dev` branch (7a0b250, 2026-10-20) for the guides that the tag does not carry (`docs/VOXEL_GUIDE.md`, `VOXEL_MOUNTAINS.md`, `VOXEL_STATUS.md`). Licence and attribution: [tools/relief/NOTICE.md](../tools/relief/NOTICE.md). Faults found here are logged in [ledger/faults.json](ledger/faults.json) (F026-F028 and notes on F001, F002, F004), see [LEDGER.md](LEDGER.md).

Sizes: **XS** under half a day, **S** about a day, **M** two to three days, **L** a week or more. A port here always means the method rewritten in Lua (or in our Python offline tools); nothing of theirs is copied, and nothing ROM-derived goes into git.

## 1. What is different at the root

| | Emerald 3DS | Emerald 3D (ours) |
|---|---|---|
| When geometry is made | Offline, on the host: Python generators read the decomp's maps and tilesets and write `romfs/voxel/*.bin` (relief, buildings, trees). The console only draws them. | At runtime in the mod, in Lua (`Gen3Scene` and friends), from the maps and tile art the engine has loaded. Offline Python exists only to bake tables (`Gen3ReliefData`) and audits. |
| Terrain heights | **Counted** from the drawing's pieces (one piece = one 16 px level), whole map at once (`voxel_terraces.py`). Ground has no slopes except where a band or face is drawn. | Cartridge elevation nibble plus pins and quantised stair terraces (`Gen3Elevation`, `Gen3StairTerraces`), rock by `Gen3Rock`/`Gen3Hills`; counted relief only on 6 maps (`Gen3Relief`: Routes 111-114, Fallarbor, Mt. Chimney). |
| Buildings | A declarative spec per building (`voxel_building_specs.py`, about 5,700 lines): parts such as Prism, GableRoof, Cylinder, ProjHull, each proved against its drawing at 45 degrees pixel for pixel. | Generated bakes (`data/buildings/*.lua`, 123 files) from `autorecipe.py`/`explicit.py`/`hf_recipes.py`: per-column walls, flats, slopes, gables; plus tile-driven shapes in `Gen3Scene` and per-tile "pixel furniture" for props. The 45 degree checker is a fault finder (`tools/buildings/bake_check.py`). |
| Rule on hand fixes | "General rules, not exceptions": a place no rule fixes gets a correction **as data** (`relief_fixes.json`), never code for one map. | Per-map pins and shape tables are normal (`PINS`, `SHAPE_BY_MAP`, `height_overrides.json`). |
| Their own status | `VOXEL_STATUS.md` (dev): 22.3 % progress, 2.4 % complete, 16 items at checkmark. Their score counts an area never modelled as 0; ours counts generic 3D as built-unreviewed (0.6), so the two percentages are not comparable. | LEDGER.md: 55.5 % / 0.0 %. |

The shared premise is the same: Emerald draws obliquely, a point (X, Y, Z) lands at u = X, v = Z - Y, so any height field lifted as (u, h, v + h) reproduces the drawing at 45 degrees. Both projects rely on it.

Their release notes say Slateport is "finished", but their own `VOXEL_STATUS.md` marks Slateport's exterior, Rustboro's exterior and Route 110's exterior as having known faults ("Faults still to fix"); Route 109 is built-unreviewed; the exteriors marked reviewed in that file are few (Littleroot, Oldale, Dewford and Rusturf Tunnel among them). Read their "done" as "released", not "reviewed".

## 2. Summary

| Area | Their approach in one line | Ours in one line | Open fault of ours solved? | Recommended port | Size |
|---|---|---|---|---|---|
| Slateport | Counted terraces group + about 54 hand specs (buildings, stalls, curbs, sailboat with an oval hull, lantern, bollard, bush) | Same buildings baked (museum, shipyard, fan club, tent lobby, harbour, houses, centre, mart); tile pins for awnings/fences; flat-deck boat; lathe only for the lighthouse | none logged (all 🟨) | Boat hull plan with sheer, lathe items (bollard, lantern, bush); hold the rest | S + S |
| Route 110 / Cycling Road / Trick House | Bridge as a **model**: deck on piers read off its drawing, ramp slots, rails, corner rules; decks table lifts the walker. Trick House as a two-storey gabled model | Cycling Road already a real raised deck (48 px slab + legs, walker lifted); Trick House exterior is a per-column bake | none logged | Review list for gate ramps, rails, shadow; check Trick House from the side; no deck-height change | XS check, S-M if faults |
| Rusturf Tunnel | Cave map hand-solved as terraces: 771 of 864 cells carry a level (1-3) or a 5x5 height grid; border "belt" 3 levels high | Generic cave massif: rim up to 32 px, +8 px per cell of depth (max +24), perimeter ridge beyond the map | none logged | Do not take the table; side-by-side check first, then decide on cave-tileset counting | XS, then L |
| Route 109 beach | Terraces group + parasol (cone canopy, turned pole), sun lounger (hinged back at 40 degrees), air mattress (tube section) | Pixel-furniture: disc canopy on a pole, two-box chair, 3 px slab mat | none logged | Cone canopy, hinged lounger, tube mat | S |
| Rustboro fountain | Octagon basin prism, rim, pool 3 px lower, dish on a stem, jet card with the game's 2-frame animation | One `extrude` slab 10 px high on the 3x3 cells | none logged (new F026) | Fountain model, jet as a standing card | S-M |
| (beyond the five) ledges and ground levels | Ledge lip from the drawing's colours, 6 px high, tapering at ends; ground one level unless a band/face is drawn | Ledge faces from tile profiles in `Gen3Outdoor`; ground from elevation pins and quantised slopes | **likely F001, F002, F004** (details in 4) | Lip shaping offline into data; level audit | M, S |

## 3. Per area

### 3.1 Slateport

**What they do.**
- Terrain: `LAYOUT_SLATEPORT_CITY` is in `voxel_terraces.GROUPS` ("2026-10-09: Slateport and the routes round it") together with Routes 103 and 109 and Dewford. Slateport has almost no rock, so in practice this places the town and sea consistently with its neighbours through the group's region ties.
- Sea: a "belt of water" for Slateport's sea (`voxel_mesh_builder.c`, comment), i.e. the water outside the map is laid by the engine's border rule, not by hand.
- Specs in `voxel_building_specs.py`: Stern's Shipyard, Fan Club, Oceanic Museum (a 112 x 96 block; see the footnote), the south-centre block they call Contest Hall, Battle Tent outline, kit houses in Slateport purple, the awning over the road to Route 110, the stall roofs lifted 12 px, white harbour curbs, round bush (a dome), stone lantern, bollard (turned profile, plan half as deep as wide), the market's baskets and urns (domes off their own pixels), crates.
- Sailboat: `ProjHull` on a long oval plan, deck 8 px high, sheer 6 px at the ends, keel a pixel under the water; the sails and mast are **flat cards in the keel's plane** with the drawing projected on them (an earlier height-field version stood the sails in spikes). The rowboat on stands by the shipyard is an open hull with a thwart.

*Footnote on names.* Their docstrings call the 96 x 96 block at cells 28..33 x 22..27 "Contest Hall" and the block at 25..31 x 7..12 "Oceanic Museum". Our door table (`tools/buildings/inventory.json`) has the Oceanic Museum doors at 30,26 and 31,26 and the harbour at 28,12, so the names look swapped in their docstrings; the geometry is the same buildings.

**What we do.** Every enterable building has a bake (`x_slateport_museum`, `x_slateport_shipyard`, `x_slateport_fanclub`, `b010` tent lobby, `b013`, `b014` harbour, `b016`, centre, mart). Awnings, fences, shrubs and boats are pinned by metatile (`Gen3EmeraldShapes` `PINS.slateport`). The sailboat (`Gen3Boat.lua`): hull side as a face 7 px tall, deck lying flat at that height, sail a thin upright card on the deck's middle; no oval plan, no sheer. Only the lighthouse is turned (`Gen3Lathe`). Slateport's town stands at base 16 over a sea at 0 (`SEA_LEVEL_MAPS`, pin rise 16), 1,028 walkable cells at 16 and 187 at 0 in the 2026-10-20 dump; their method has no raised town, so this is our design choice, not something their approach corrects.

**Open faults of ours solved by their approach.** None logged for Slateport. Our offline port of their counting (`tools/relief/terraces.py SlateportCity`) finds levels `[0]`, no runs: Slateport has no counted relief to import.

**Recommended ports.**
1. Boat hull: measure the hull's outline from our own art, build the deck as a rounded oval plan with 6 px sheer, sails as flat cards in the keel's plane. Size **S** (`Gen3Boat.lua`; the card part already exists). Tier 2. Logged as F027.
2. Lathe items: the Slateport lantern (square, stepped), harbour bollards (turned profile), round bush as a low dome. We have `Gen3Lathe` and `Gen3Mass` domes; each is a new spec. Size **S**. Not logged separately (part of F027's area, fix together).
3. Do not copy the spec-per-building route: our bakes cover the same buildings, and the finish-line plan puts building work in the re-bake loop.

### 3.2 Route 110: Cycling Road and the Trick House

**What they do** (`voxel_bridge.py`, a 2,368-line generator with a long docstring).
- The cartridge says the road is a bridge: deck at elevation 4 over land at 3 and sea at 1, cells walked over and under at 15. A height field cannot hold two heights in one cell, so the road is a **model** with open space under it and a *deck table* the console reads to lift whoever is up on it.
- Every pixel is placed by u = X, v = Z - Y: road at the deck height, south rail + girder + piers on one upright face, north rail on another, side rails as strips, ramps where the road comes down at the gatehouses.
- Deck height is a compromise: the drawing's piers imply 42 px, but the drawn ramps are three cells long and would fall 42 px in 6; the deck stands at **40 px** (`DECK`), rails 13, girder 18, slab 4, a ramp runs 56 px south while it falls (`RAMP_RUN`), cut as a slot in the deck's south edge with 16 px side walls.
- Corners: the drawing's pixel staircase would become a staircase of walls, so outer south corners are chamfers at 45 degrees and the north and inner ones are built square (`_corner`, `_north_corner`, `_inner_north_corner`).
- Whatever else the bridge's cells draw (a shore edge, tree leaves over the rail, long grass, the shadowed water) is laid on the plain ground as a ground patch, so the deck's real shadow falls across it. Curbs that continue under a span are a separate component. Houses beside the road are excluded by rectangle (`apart`). A `bridge_check` holds every model to the drawing pixel for pixel.
- Trick House (`trick_house()`, 80 x 96 art): full-width gabled lower roof (flatter pitch so its ridge stays inside the upper storey), upper storey set one tile in from the lower eaves, front and back, with its own gabled roof; gables and walls in the facade's stone; five collision rows of real depth. Gatehouses are flat blocks with parapets.

**What we do.** `Gen3CyclingRoad.lua` already makes it a real raised road: deck at **48 px** (the 32-row fascia on 16-row legs, from `Gen3Elevation` e4/e15), slab with fascia faces, legs under the nearest deck edge, sea or grass under it, `RAIL_H=10`, the dark road-shadow tile 0x171 turned into sea, one stair flight at 0x2D4 by the north gate, actors on layer 4 stand on the deck and the camera hides under-deck walkers. The 2026-10-20 dump agrees (472 walkable cells at 48, four stair cells at 10/19/29/38). The gatehouses are bakes (`x_cyclingroad_north/south`, `b119-b122`). The Trick House exterior is `b118_route110_trickhouseentrance` (a 325 KB per-column bake; ortho-45 sheet `docs/ortho45/sheets/b118_*.png` shows a close silhouette match).

**Open faults of ours solved.** None logged for Route 110. The map has no counted-relief entry in either project's rock method that would apply (our port finds levels 0/16/32 over 39 rock cells).

**Where they are ahead, not yet seen as faults** (checks for the next tour, not logged as faults because nothing has been seen in game):
- Gate ramps: the cartridge draws the road coming down to land; we have a single stair tile and the baked gatehouse. Look at both ends from the side at level 7.
- Rail height (13 px in the drawing against our 10) and rail geometry on the strips.
- Deck shadow cast onto the ground patches (they relight the ground patch; check whether our sun shadow covers it).
- Corner treatment: chamfer versus staircase of walls at outer south corners.
- Trick House: whether our per-column bake shows the upper storey set back with its own gabled roof from the side and the back. A single column path can make a pyramid where theirs has two roofs.
Their deck is 8 px lower on purpose; keep 48 (ours follows the cartridge's fascia and legs; their number is a ramp compromise).

**Recommended.** Run the review list above (**XS**, one QA sheet of both gates and the Trick House at levels 4, 6, 7, four yaws). Only if a fault shows: ramps as slot geometry with side walls (**S-M**), Trick House as a two-roof recipe in `hf_recipes.py` (**M**).

### 3.3 Rusturf Tunnel

**What they do.** Not a rule: `relief_fixes.json` holds `LAYOUT_RUSTURF_TUNNEL` as **data**: `drawn: true`, `belt: 48` (the border metatiles stand 3 levels high, "a cave carved out of the rock, its edges this high all round", `VoxelRelief_Belt`), and 771 of the map's 864 cells hand-set: 349 whole levels (1, 2 or 3) and 422 5 x 5 height grids (the slopes of bands, 4 px per column down a cell, and faces). Reading the table as a picture: the walkable floor is level 0, the rock round it is a terraced massif of levels 1-3 with drawn south faces (rows of faces between levels) and bands at the sides. Our offline port of their counting classifies none of the cave tileset's tiles as rock (`terraces.py RusturfTunnel`: kinds `?` 512, `G` 352, one level), so the data is the only source of those levels: it is hand work, not a general method. The status file marks it reviewed ("Carved out of the rock").

**What we do.** No special case: `Gen3Rock.cave` treats the rock between passages as a massif. Rim at `CAVE_MAXH` 32 px, then `CAVE_RISE` 8 px per cell of depth from the passages, capped at `CAVE_EXTRA` 24; faces come from the tile art; `CavePerimeter.lua` adds an uneven ridge beyond the engine's three-block border. This is smooth by distance; the drawing's internal terraces (levels 1, 2, 3 with faces between) are not counted.

**Open faults solved.** None logged for Rusturf (🟨, never reviewed). The difference is a fidelity question: does the cave read as the stepped terraces the artist drew?

**Recommended.**
1. **XS**: a side-by-side. Dump our Rusturf cells (not in the 53-map baseline: caves were not dumped) and compare, per cell, our resolved rock height to their level band. Comparison only, per NOTICE.md; the table stays in scratch.
2. If ours reads as a blob where theirs reads as terraces: extend `tools/relief/terraces.py` with the cave tileset's face/band/top tiles and bake a Rusturf row into `Gen3ReliefData` for caves that share the tileset (**L**; it is the same job as the General mountain, with a new tile table). Do not take their table: its licence status is unconfirmed and it covers one map.

### 3.4 Route 109 beach

**What they do.** `LAYOUT_ROUTE109` is in the terraces group (our port: levels 0 and 16, 199 rock cells). The beach is six specs: three parasols (red, blue, green; found by their own pixels), a sun lounger, an air mattress. Parasol: a shallow round cone canopy (`ProjCanopy`, rim lifted 3.5 px at the front so it is exact at 45 degrees) over a thin turned pole (`ProjLathe`), closed underneath; the drawn shadow is treated as ground colour so the console casts the real one. Lounger: seat 5 px high, back raised 40 degrees from a hinge, four legs and two struts under the back. Mattress: a tube section, 2 px thick, pillow a tube 2.5 px round. Everything is a smooth part with the drawing projected on it; their notes say the earlier height-field version "stood the canopy in fins".

**What we do.** `Gen3PixelFurnitureB.lua` (Route 109 / Slateport beach block): umbrella = a disc canopy (3-row rim) on a 24 px pole, chair = two boxes, mat = a 3 px slab with a slightly higher pillow. Shade on the sand stays ground. The cells are all 🟨.

**Open faults solved.** None logged. The Route 109 beach dump is clean (695 walkable cells at 0, 5 at 8, 5 at 16).

**Recommended.** Cone canopy plus turned pole, hinged lounger back, tube mat: **S**, tier 2, in the same furniture file; judge from behind as well as the front (our standing rule). Logged as F028.

### 3.5 Rustboro fountain

**What they do.** `rustboro_fountain` spec, 48 x 48 art at cells 27,38 (3 x 3). Plan outline of 8 points; basin wall 5 px; rim at that height, in to the pool edge; pool water 3 px high (2 px under the rim); dish (an ellipse 9 x 6) 8 px high on a stem it hides, 2 px edge; the grey under the dish is its shadow on the water; the jet is a **card standing across the dish**, the only part that moves. Their texture is the art with the jet cut out (pool and dish as they lie behind it) plus the jet's pixels on a separate band. The jet animates by reading the game's two tile frames (Rustboro secondary tiles 448-451, redrawn every 8 frames) into those texels.

**What we do.** `Gen3Scene.lua` (about line 491): the nine fountain tiles are `extrude` with `h=10`: "its own picture stands 10 px up on the plaza". No dish above the water, no pool inset, no jet. A grep of `lib/` for tileset animation finds only the Crystal atlas animation (`Gen2AtlasAnimation`); the Emerald jet therefore shows its first frame, unverified whether the engine animates it elsewhere.

**Open faults solved.** New: F026 (suspected from code, tier 2).

**Recommended.** **S-M**: octagon basin and pool from the art's outline, dish as a lathe disc on a stem, jet as a standing card textured from the art. Animation only if the engine exposes the tile frames (check first; static is acceptable). Judge from behind.

## 4. Beyond the five: where their method meets our Tier 1 faults

I ran our offline port of their counting (`tools/relief/terraces.py`, unchanged) on Routes 103, 104, 109, 110, 115, 116, Slateport and Rusturf into scratch, and compared its levels with our resolved heights in `~/Documents/gen1recomp-modwork/baselines/heights-2026-10-20-fix-F025.txt` (read only; outside git).

**Ground that is one level for them is a staircase for us (F002 and class).** On Route 115, cells 16..33 x 60..77 are all one counted level (`F1G`: top piece, ground). Our base on the same cells reads 0, 2, 3, 5, 6, 8, 10, 13, 16 in steps down the sand slope (for example column 22, rows 70-72: 0, 7, 4). Across Route 115, their level 1 covers 532 of our walkable ground cells with 14 distinct bases (16: 271, 8: 67, 0: 62, 18: 21, 5: 21, ...); their levels 0, 2, 3, 5 each map to one or two of our bases. In their method a slope exists only where a band or face is drawn, so the quantised ramp that the user calls "mini stairs" does not arise. The same pattern, smaller, on Route 103 (36 of 388 ground cells at 2/5/8) and Route 116 (42 of 427). Caveat: our ledges must drop (DONE.md tier 1), and their count gives no drop at a ledge, so this cannot be applied wholesale. As a **first audit number** (not yet a gate): 1,729 of 31,998 flat walkable cells (not stairs, ledge or bridge) in 25 of the 53 baseline maps have a base that is not a multiple of 8; the largest are Mt. Chimney 258, Battle Frontier East 254, Jagged Pass 206, Sootopolis 192, Route 119 165, Route 111 114, Route 115 113 (many on the first four are real slopes).

**Ledges (F001, F004).** Their ledge is a low berm, lifted off the drawing: the lip is the pixels of the ledge cell whose colour is not in the ground round it; its height is the distance from the lip's foot along the jump direction, 0 to **6 px** over **8 px** (a lip drawn half a cell deep); the ground behind rises to the top edge over 8 px; a corner cell takes the nearer foot so an outer corner rounds like the drawing; where a run ends at a cell that is no ledge the lip comes down to the ground at its own slope (an inversion of the (u, h, v + h) projection once opened a hole in their ground); junction pieces where a ledge steps are ledge cells too; before the berm every ledge cell is laid back on the plane of its four corners so a solved relief cannot leave a trench. They never touch ledges in the terrace pass and check this with `ledgecheck.py` (zero differences). That is close to the ask in F001 ("straight lips, closed rounded ends, no teeth"). Our port already computes the berms offline (`terraces.py`, 64 on Route 115, 14 on Route 104, 25 on Route 103). Their lip does not drop; our drop comes from elevation and stays our rule.

**Maps in their terrace group where we have open faults.** Their `GROUPS` holds Routes 103, 104, 105, 106, 109, 114, 115, 116, 117, 123, Slateport, Dewford, Pacifidlog, 133, 134, Safari North, Route 111 (two layouts), Lavaridge. Our open faults on those maps: F001, F002 (R115), F003 (R104 mini stairs, cell unidentified), F007 (R103 floating rock), F008 (R115 end piece colour), F013 (R116 seams). Only F001 and F002 are evidenced as in-class above; the others are listed so the next owner can run the same two commands on them.

## 5. Recommended order

1. **XS** review sheets for Cycling Road gates, Trick House and Rusturf (3.2, 3.3), the only way to turn "they are ahead here" into logged faults.
2. **S** audit: base-not-a-multiple-of-8 count per map as a report (not a scanner change; DONE.md rule 3), with the R115 table above as its first case.
3. **M** ledge lip shaping (F001/F004), coordinated with whoever owns `Gen3Outdoor.lua`: bake lips offline from the existing berm code, apply as data. Do after the current ledge session ends.
4. **S-M** Rustboro fountain (F026), **S** boat hull and lathe items (F027), **S** beach furniture (F028). All tier 2.
5. Hold: deck height, spec-per-building, Rusturf's table, the `GROUPS` mechanism itself.

## 6. How this was checked, and what was not

- Cloned `ZallaxDev/emerald-3ds` (`--depth 1`, plus tag v0.4.0 and branch dev) into an empty scratch folder; read their Python and docs with Python run with `-I` where it was run at all (only to summarise the JSON). Nothing of theirs was executed as code or built.
- v0.4.0 holds the five areas' code (`voxel_bridge.py`, the fountain, Trick House, parasol and sailboat specs, Rusturf in `relief_fixes.json`); `dev` adds only Lavaridge and Routes 111-113 hand data, `VOXEL_GUIDE/MOUNTAINS/STATUS` and `terrace_debug/`.
- Our side: `lib/` read, no edits; `tools/relief/terraces.py` run into scratch; baseline dump read.
- Not done: no in-game capture of any of the five areas by this session (the sheet `docs/ortho45/sheets/b118_route110_trickhouseentrance.png` is the only image seen); no run of their generators (they need a bootstrapped decomp tree); no test whether our engine can animate the Emerald fountain; Rusturf not dumped. Everything marked "check" above is a hypothesis from reading code.
- Their guides worth reading again before the ledge and cave work: `docs/VOXEL_MOUNTAINS.md` (rules, "tried and rejected" list, the fault-by-fault loop) and the docstring of `gen_voxel_relief.py` (ledges).
