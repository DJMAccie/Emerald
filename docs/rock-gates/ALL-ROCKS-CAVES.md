# ALL ROCKS: caves and interiors (task 28)

Per-map ledger. Counts: tools/caves/census_table.md (143 maps, census 2026-10-26, game lib, QA copy). Done = the user has looked at the sheet.
Type 8 maps (Mt Pyre, Aqua Hideout and other building interiors) mostly have 0 rock cells: no rock to fix.

## Classes
- **U** underwater floor (EM_UNDERWATER_*): the blocked sea floor beyond the dive lanes was made rock and stood as a terrace maze; in the 2D it is one flat plain with the lanes sunk in it and a thin ridge along each lane. Fix: Gen3Cave.settle flattens tile 0x213 and caps the lane ridge (UNDERWATER_MAXH 16).
- **L** lava lake (Terra Cave End, Magma Hideout): blocked lava was rock, a slab 16-40 px over the floor. Fix: lava lies flat, one lake one level.
- **S** Sky Pillar floors: the dark square is a pit (flat), the grey boulders were invisible cliff cells (now boulders on the floor, height 14).

## Round 1: INSTALLED 2026-10-26
Gen3Cave.lua (settle, isLava, positionMask) + one line in Gen3Scene.lua (`Gen3Cave.settle(def,cells)` after the cave shape pass). Gates: census diff r1 vs base2 changes only 22 maps (12 underwater, Terra Cave End, Magma 2F_2R/3F_1R/3F_3R/4F, Sky Pillar 1-5F); capture batch f1 (21 spots x levels 4/6/7) 0 fallbacks; installed game tree = probe (L4 diff <0.05% px, smoke batch); determinism: L4 0.04% / 0.003%, underwater L6/L7 identical, Magma 3F_1R L6/L7 differ because the player wandered in one run (camera log player 7,17 vs 9,16), not geometry. Boards: docs/rock-gates/caves/boards_f1_{uw,lv,sp} (png, gitignored). Backup ~/Documents/gen1recomp-modwork/backups/caves-20261026. Revert: copy the two backup files over source, game and QA lib, regenerate the patch (tools/caves/install_c1.sh pattern).
Known after round 1: Sky Pillar 1F/5F L4 show few of the 2D's scattered boulders (the 4F row of rubble shows); find which tiles they are in round 2.

## Round 2a: Sky Pillar boulders (INSTALLED 2026-10-26)
Finding: the boulders are not missing, they are a STORY STATE. SkyPillar_1F's OnTransition runs `setmaplayoutindex` (alt layout 433, the boulder-free floor) while VAR_SKY_PILLAR_STATE < 2, so a fresh game has a clean 1F; the 2D crop and emdata grid.bin show the base layout, which is what the player sees at state 2 (after Rayquaza). Round 1's boulder work was therefore verified at the wrong state. Check Sky Pillar at `EM_SETVARS="VAR_SKY_PILLAR_STATE=2"` (tools/caves/em_views_vars_driver.lua, raw_driver / heights_driver / audit_driver / mass_driver take it too).
Faults found at state 2 and fixed in Gen3Cave.settle:
- a boulder cell kept collision 7, so Gen3Rock's cave depth rule counted it as solid rock and raised the wall row behind every boulder one CAVE_RISE (H 24 over 16, brown blocks sticking out of the north wall); boulders now carry collision 43 in the scene cell (the engine's own collision is untouched);
- the arch cap over each stair alcove (0x23C, caveWall) cut the wall into separate masses and the 2x2 end piece beyond the last alcove was too small for the course builder, so it stood as a tall dome (3F); M.CAP makes the cap a cliff like the wall beside it, so the wall row is one mass (11 cells+);
- 0x217 boulders against the wall (kind flat, collision 7) were not boulders: M.BOULDER now also converts flat cells.
Gates: census diff g3 (game lib) vs p3 (probe) at state 2 on all 143 maps: only the five Sky Pillar floors change; 5 floors x 2 states captured, 0 fallbacks (docs/rock-gates/caves/s2, s2b, s2c, s0c).

## Round 2 plan
tools/caves/flat_audit.py base2: 1,385 invisible rock cells (Aqua Hideout unused maps, Shoal Cave 219/2AC, Meteor Falls 1F 244, Seafloor Cavern 6/7 278, Magma 306/274): view each, fix by class; then wall height (Granite, Victory Road, Seafloor L6/L7 vs 2D), dark-cave recapture, Mirage Tower black outside, Navel Rock.

## Round 2b: invisible-rock audit, viewed (2026-10-26)
tools/caves/flat_audit.py base2 lists 1,385 rock cells with H <= base+2. Viewed 18 spots (2D crop | L4 | L6 | L7, docs/rock-gates/caves/boards_r2) over every cluster of the reachable maps (Shoal Cave high/low tide, Seafloor Cavern 1/6/7, Magma Hideout 1F/2F/3F/4F, Meteor Falls 1F/B1F, Artisan Cave B1F): the flagged cells are wall rims whose floor solver base equals their own top (H = base on a raised rim), not holes; every spot reads as the 2D layout in terraces. The metric is a false-positive generator; do not chase it further. Aqua Hideout unused maps (364/206/157 cells) are not reachable in the game.
Open judgement for the user (not a measurable fault): Magma Hideout's rock reads as tall streaked columns (the 2D hatching stretched down the faces) where the 2D is thin dark ridges on a pink floor; Gen3Rock's face builder, task 27's file.

## Maps
| map | type | family | size | rock cells | status |
|---|---|---|---|---|---|
| EM_UNDERWATER_ROUTE124 | 5 | underwater | 80x80 | 5731 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_UNDERWATER_ROUTE126 | 5 | underwater | 80x80 | 5504 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_UNDERWATER_ROUTE127 | 5 | underwater | 80x80 | 5770 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_UNDERWATER_ROUTE128 | 5 | underwater | 120x40 | 4536 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_UNDERWATER_ROUTE129 | 5 | underwater | 80x40 | 3035 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_UNDERWATER_ROUTE105 | 5 | underwater | 40x80 | 2979 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_UNDERWATER_ROUTE125 | 5 | underwater | 80x40 | 2488 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_ROUTE114_FOSSIL_MANIACS_HOUSE | 8 | generic_building | 10x8 | 0 | no rock cells (nothing to fix) |
| EM_ROUTE114_FOSSIL_MANIACS_TUNNEL | 8 | fallarbor | 13x26 | 0 | no rock cells (nothing to fix) |
| EM_METEOR_FALLS_1F_1R | 4 | meteor_falls | 30x42 | 599 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_METEOR_FALLS_1F_2R | 4 | meteor_falls | 30x32 | 564 | open: round 2 |
| EM_METEOR_FALLS_B1F_1R | 4 | meteor_falls | 29x38 | 623 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_METEOR_FALLS_B1F_2R | 4 | meteor_falls | 11x18 | 130 | open: round 2 |
| EM_RUSTURF_TUNNEL | 4 | rusturf_tunnel | 36x24 | 643 | open: round 2 |
| EM_UNDERWATER_SOOTOPOLIS_CITY | 5 | underwater | 20x10 | 167 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_DESERT_RUINS | 4 | cave | 17x33 | 264 | open: round 2 |
| EM_GRANITE_CAVE_1F | 4 | cave | 42x15 | 411 | open: round 2 |
| EM_GRANITE_CAVE_B1F | 4 | cave | 32x26 | 347 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_GRANITE_CAVE_B2F | 4 | cave | 32x26 | 347 | open: round 2 |
| EM_GRANITE_CAVE_STEVENS_ROOM | 4 | cave | 15x14 | 175 | open: round 2 |
| EM_FIERY_PATH | 4 | lavaridge | 35x38 | 1053 | open: round 2 |
| EM_MT_PYRE_1F | 8 | facility | 22x19 | 0 | no rock cells (nothing to fix) |
| EM_MT_PYRE_2F | 8 | facility | 13x13 | 0 | no rock cells (nothing to fix) |
| EM_MT_PYRE_3F | 8 | facility | 13x13 | 0 | no rock cells (nothing to fix) |
| EM_MT_PYRE_4F | 8 | facility | 13x13 | 0 | no rock cells (nothing to fix) |
| EM_MT_PYRE_5F | 8 | facility | 13x13 | 0 | no rock cells (nothing to fix) |
| EM_MT_PYRE_6F | 8 | facility | 13x13 | 0 | no rock cells (nothing to fix) |
| EM_AQUA_HIDEOUT_1F | 8 | facility | 28x30 | 0 | no rock cells (nothing to fix) |
| EM_AQUA_HIDEOUT_B1F | 8 | facility | 51x24 | 0 | no rock cells (nothing to fix) |
| EM_AQUA_HIDEOUT_B2F | 8 | facility | 34x24 | 0 | no rock cells (nothing to fix) |
| EM_UNDERWATER_SEAFLOOR_CAVERN | 5 | underwater | 14x9 | 103 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_SEAFLOOR_CAVERN_ENTRANCE | 4 | cave | 20x20 | 190 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM1 | 4 | cave | 20x21 | 215 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_SEAFLOOR_CAVERN_ROOM2 | 4 | cave | 18x12 | 158 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM3 | 4 | cave | 16x17 | 162 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM4 | 4 | cave | 18x19 | 218 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM5 | 4 | cave | 20x20 | 256 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM6 | 4 | pacifidlog | 24x23 | 203 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_SEAFLOOR_CAVERN_ROOM7 | 4 | pacifidlog | 23x25 | 177 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_SEAFLOOR_CAVERN_ROOM8 | 4 | cave | 11x14 | 100 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM9 | 4 | cave | 27x46 | 930 | open: round 2 |
| EM_CAVE_OF_ORIGIN_ENTRANCE | 4 | cave | 19x26 | 415 | open: round 2 |
| EM_CAVE_OF_ORIGIN_1F | 4 | cave | 23x23 | 436 | open: round 2 |
| EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP1 | 4 | cave | 23x23 | 415 | open: round 2 |
| EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP2 | 4 | cave | 21x21 | 396 | open: round 2 |
| EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP3 | 4 | cave | 19x21 | 396 | open: round 2 |
| EM_CAVE_OF_ORIGIN_B1F | 4 | cave | 19x19 | 275 | open: round 2 |
| EM_VICTORY_ROAD_1F | 4 | cave | 46x45 | 1364 | open: round 2 |
| EM_VICTORY_ROAD_B1F | 4 | cave | 46x31 | 1055 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_VICTORY_ROAD_B2F | 4 | cave | 46x31 | 1055 | open: round 2 |
| EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM | 4 | cave | 35x35 | 794 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | 4 | cave | 46x38 | 952 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | 4 | cave | 21x15 | 255 | open: round 2 |
| EM_SHOAL_CAVE_LOW_TIDE_LOWER_ROOM | 4 | cave | 31x14 | 323 | open: round 2 |
| EM_SHOAL_CAVE_HIGH_TIDE_ENTRANCE_ROOM | 4 | cave | 35x35 | 569 | open: round 2 |
| EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | 4 | cave | 46x38 | 759 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_ISLAND_CAVE | 4 | cave | 17x33 | 264 | open: round 2 |
| EM_ANCIENT_TOMB | 4 | cave | 17x33 | 264 | open: round 2 |
| EM_UNDERWATER_ROUTE134 | 5 | underwater | 18x10 | 158 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_UNDERWATER_SEALED_CHAMBER | 5 | underwater | 22x48 | 740 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_SEALED_CHAMBER_OUTER_ROOM | 4 | cave | 21x23 | 320 | open: round 2 |
| EM_SEALED_CHAMBER_INNER_ROOM | 4 | cave | 21x23 | 297 | open: round 2 |
| EM_SCORCHED_SLAB | 4 | cave | 15x20 | 189 | open: round 2 |
| EM_AQUA_HIDEOUT_UNUSED_RUBY_MAP1 | 4 | facility | 28x30 | 299 | open: round 2 |
| EM_AQUA_HIDEOUT_UNUSED_RUBY_MAP2 | 4 | facility | 62x24 | 420 | open: round 2 |
| EM_AQUA_HIDEOUT_UNUSED_RUBY_MAP3 | 4 | facility | 34x24 | 214 | open: round 2 |
| EM_SKY_PILLAR_ENTRANCE | 4 | cave | 18x18 | 247 | open: round 2 |
| EM_SKY_PILLAR_1F | 4 | pacifidlog | 14x14 | 63 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders); round 2 INSTALLED 2026-10-26 (checked at VAR_SKY_PILLAR_STATE=2, the only state with boulders: boulders no longer raise the wall behind them, arch caps join the wall mass, 0x217 boulders) |
| EM_SKY_PILLAR_2F | 4 | pacifidlog | 14x14 | 62 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders); round 2 INSTALLED 2026-10-26 (checked at VAR_SKY_PILLAR_STATE=2, the only state with boulders: boulders no longer raise the wall behind them, arch caps join the wall mass, 0x217 boulders) |
| EM_SKY_PILLAR_3F | 4 | pacifidlog | 14x14 | 65 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders); round 2 INSTALLED 2026-10-26 (checked at VAR_SKY_PILLAR_STATE=2, the only state with boulders: boulders no longer raise the wall behind them, arch caps join the wall mass, 0x217 boulders) |
| EM_SKY_PILLAR_4F | 4 | pacifidlog | 14x14 | 72 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders); round 2 INSTALLED 2026-10-26 (checked at VAR_SKY_PILLAR_STATE=2, the only state with boulders: boulders no longer raise the wall behind them, arch caps join the wall mass, 0x217 boulders) |
| EM_SHOAL_CAVE_LOW_TIDE_ICE_ROOM | 4 | cave | 20x30 | 284 | open: round 2 |
| EM_SKY_PILLAR_5F | 4 | pacifidlog | 14x14 | 91 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders); round 2 INSTALLED 2026-10-26 (checked at VAR_SKY_PILLAR_STATE=2, the only state with boulders: boulders no longer raise the wall behind them, arch caps join the wall mass, 0x217 boulders) |
| EM_MAGMA_HIDEOUT_1F | 4 | lavaridge | 37x38 | 1007 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_MAGMA_HIDEOUT_2F_1R | 4 | lavaridge | 33x39 | 888 | open: round 2 |
| EM_MAGMA_HIDEOUT_2F_2R | 4 | lavaridge | 49x28 | 1090 | round 1 INSTALLED 2026-10-26 (L lava flat) |
| EM_MAGMA_HIDEOUT_3F_1R | 4 | lavaridge | 28x24 | 484 | round 1 INSTALLED 2026-10-26 (L lava flat) |
| EM_MAGMA_HIDEOUT_3F_2R | 4 | lavaridge | 24x17 | 183 | open: round 2 |
| EM_MAGMA_HIDEOUT_4F | 4 | lavaridge | 59x28 | 1243 | round 1 INSTALLED 2026-10-26 (L lava flat); viewed round 2 (2D vs L4/L6/L7, boards_r2): no hole, no fix |
| EM_MAGMA_HIDEOUT_3F_3R | 4 | lavaridge | 33x24 | 691 | round 1 INSTALLED 2026-10-26 (L lava flat); viewed round 2 (2D vs L4/L6/L7, boards_r2): no hole, no fix |
| EM_MAGMA_HIDEOUT_2F_3R | 4 | lavaridge | 60x19 | 1011 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_MIRAGE_TOWER_1F | 4 | mirage_tower | 21x17 | 202 | open: round 2 |
| EM_MIRAGE_TOWER_2F | 4 | mirage_tower | 21x17 | 206 | open: round 2 |
| EM_MIRAGE_TOWER_3F | 4 | mirage_tower | 21x17 | 202 | open: round 2 |
| EM_MIRAGE_TOWER_4F | 4 | mirage_tower | 13x10 | 63 | open: round 2 |
| EM_DESERT_UNDERPASS | 4 | cave | 139x23 | 2517 | open: round 2 |
| EM_ARTISAN_CAVE_B1F | 4 | cave | 46x54 | 1674 | viewed round 2 (2D vs L4/L6/L7, boards_r2): matches the 2D layout, no fix; Magma = see round 2b note |
| EM_ARTISAN_CAVE_1F | 4 | cave | 21x22 | 416 | open: round 2 |
| EM_UNDERWATER_MARINE_CAVE | 5 | underwater | 20x10 | 191 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_MARINE_CAVE_ENTRANCE | 4 | cave | 20x20 | 224 | open: round 2 |
| EM_MARINE_CAVE_END | 4 | cave | 27x30 | 520 | open: round 2 |
| EM_TERRA_CAVE_ENTRANCE | 4 | cave | 20x20 | 276 | open: round 2 |
| EM_TERRA_CAVE_END | 4 | cave | 27x30 | 625 | round 1 INSTALLED 2026-10-26 (L lava flat) |
| EM_ALTERING_CAVE | 4 | cave | 32x24 | 492 | open: round 2 |
| EM_METEOR_FALLS_STEVENS_CAVE | 4 | meteor_falls | 30x32 | 806 | open: round 2 |
| EM_SECRET_BASE_RED_CAVE1 | 9 | secret_base_red_cave | 11x9 | 43 | open: round 2 |
| EM_SECRET_BASE_BROWN_CAVE1 | 9 | secret_base_brown_cave | 11x9 | 41 | open: round 2 |
| EM_SECRET_BASE_BLUE_CAVE1 | 9 | secret_base_blue_cave | 11x9 | 45 | open: round 2 |
| EM_SECRET_BASE_YELLOW_CAVE1 | 9 | secret_base_yellow_cave | 11x9 | 38 | open: round 2 |
| EM_SECRET_BASE_TREE1 | 9 | secret_base_tree | 11x9 | 39 | open: round 2 |
| EM_SECRET_BASE_SHRUB1 | 9 | secret_base_shrub | 11x9 | 42 | open: round 2 |
| EM_SECRET_BASE_RED_CAVE2 | 9 | secret_base_red_cave | 7x16 | 65 | open: round 2 |
| EM_SECRET_BASE_BROWN_CAVE2 | 9 | secret_base_brown_cave | 14x9 | 66 | open: round 2 |
| EM_SECRET_BASE_BLUE_CAVE2 | 9 | secret_base_blue_cave | 15x7 | 44 | open: round 2 |
| EM_SECRET_BASE_YELLOW_CAVE2 | 9 | secret_base_yellow_cave | 14x9 | 65 | open: round 2 |
| EM_SECRET_BASE_TREE2 | 9 | secret_base_tree | 7x16 | 60 | open: round 2 |
| EM_SECRET_BASE_SHRUB2 | 9 | secret_base_shrub | 15x7 | 44 | open: round 2 |
| EM_SECRET_BASE_RED_CAVE3 | 9 | secret_base_red_cave | 15x8 | 66 | open: round 2 |
| EM_SECRET_BASE_BROWN_CAVE3 | 9 | secret_base_brown_cave | 15x11 | 92 | open: round 2 |
| EM_SECRET_BASE_BLUE_CAVE3 | 9 | secret_base_blue_cave | 10x17 | 110 | open: round 2 |
| EM_SECRET_BASE_YELLOW_CAVE3 | 9 | secret_base_yellow_cave | 12x11 | 65 | open: round 2 |
| EM_SECRET_BASE_TREE3 | 9 | secret_base_tree | 17x8 | 69 | open: round 2 |
| EM_SECRET_BASE_SHRUB3 | 9 | secret_base_shrub | 13x11 | 74 | open: round 2 |
| EM_SECRET_BASE_RED_CAVE4 | 9 | secret_base_red_cave | 9x15 | 74 | open: round 2 |
| EM_SECRET_BASE_BROWN_CAVE4 | 9 | secret_base_brown_cave | 14x12 | 93 | open: round 2 |
| EM_SECRET_BASE_BLUE_CAVE4 | 9 | secret_base_blue_cave | 9x17 | 90 | open: round 2 |
| EM_SECRET_BASE_YELLOW_CAVE4 | 9 | secret_base_yellow_cave | 13x14 | 98 | open: round 2 |
| EM_SECRET_BASE_TREE4 | 9 | secret_base_tree | 14x14 | 113 | open: round 2 |
| EM_SECRET_BASE_SHRUB4 | 9 | secret_base_shrub | 14x11 | 79 | open: round 2 |
| EM_FARAWAY_ISLAND_ENTRANCE | 8 | rustboro | 34x46 | 0 | no rock cells (nothing to fix) |
| EM_FARAWAY_ISLAND_INTERIOR | 8 | fortree | 29x26 | 0 | no rock cells (nothing to fix) |
| EM_NAVEL_ROCK_EXTERIOR | 8 | dewford | 21x24 | 0 | no rock cells (nothing to fix) |
| EM_NAVEL_ROCK_HARBOR | 8 | island_harbor | 17x13 | 0 | no rock cells (nothing to fix) |
| EM_NAVEL_ROCK_ENTRANCE | 4 | navel_rock | 21x32 | 168 | open: round 2 |
| EM_NAVEL_ROCK_B1F | 4 | navel_rock | 23x11 | 88 | open: round 2 |
| EM_NAVEL_ROCK_FORK | 4 | navel_rock | 27x86 | 667 | open: round 2 |
| EM_NAVEL_ROCK_UP1 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_UP2 | 4 | navel_rock | 9x8 | 38 | open: round 2 |
| EM_NAVEL_ROCK_UP3 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_UP4 | 4 | navel_rock | 9x8 | 38 | open: round 2 |
| EM_NAVEL_ROCK_TOP | 4 | navel_rock | 25x28 | 663 | open: round 2 |
| EM_NAVEL_ROCK_DOWN01 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_DOWN02 | 4 | navel_rock | 9x8 | 38 | open: round 2 |
| EM_NAVEL_ROCK_DOWN03 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_DOWN04 | 4 | navel_rock | 9x8 | 38 | open: round 2 |
| EM_NAVEL_ROCK_DOWN05 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_DOWN06 | 4 | navel_rock | 9x8 | 38 | open: round 2 |
| EM_NAVEL_ROCK_DOWN07 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_DOWN08 | 4 | navel_rock | 9x8 | 38 | open: round 2 |
| EM_NAVEL_ROCK_DOWN09 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_DOWN10 | 4 | navel_rock | 9x8 | 38 | open: round 2 |
| EM_NAVEL_ROCK_DOWN11 | 4 | navel_rock | 9x8 | 36 | open: round 2 |
| EM_NAVEL_ROCK_BOTTOM | 4 | navel_rock | 22x22 | 417 | open: round 2 |
