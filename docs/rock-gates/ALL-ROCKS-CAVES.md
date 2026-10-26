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

## Round 2 plan
tools/caves/flat_audit.py base2: 1,385 invisible rock cells (Aqua Hideout unused maps, Shoal Cave 219/2AC, Meteor Falls 1F 244, Seafloor Cavern 6/7 278, Magma 306/274): view each, fix by class; then wall height (Granite, Victory Road, Seafloor L6/L7 vs 2D), dark-cave recapture, Mirage Tower black outside, Navel Rock.

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
| EM_METEOR_FALLS_1F_1R | 4 | meteor_falls | 30x42 | 599 | open: round 2 |
| EM_METEOR_FALLS_1F_2R | 4 | meteor_falls | 30x32 | 564 | open: round 2 |
| EM_METEOR_FALLS_B1F_1R | 4 | meteor_falls | 29x38 | 623 | open: round 2 |
| EM_METEOR_FALLS_B1F_2R | 4 | meteor_falls | 11x18 | 130 | open: round 2 |
| EM_RUSTURF_TUNNEL | 4 | rusturf_tunnel | 36x24 | 643 | open: round 2 |
| EM_UNDERWATER_SOOTOPOLIS_CITY | 5 | underwater | 20x10 | 167 | round 1 INSTALLED 2026-10-26 (U underwater floor flat) |
| EM_DESERT_RUINS | 4 | cave | 17x33 | 264 | open: round 2 |
| EM_GRANITE_CAVE_1F | 4 | cave | 42x15 | 411 | open: round 2 |
| EM_GRANITE_CAVE_B1F | 4 | cave | 32x26 | 347 | open: round 2 |
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
| EM_SEAFLOOR_CAVERN_ROOM1 | 4 | cave | 20x21 | 215 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM2 | 4 | cave | 18x12 | 158 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM3 | 4 | cave | 16x17 | 162 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM4 | 4 | cave | 18x19 | 218 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM5 | 4 | cave | 20x20 | 256 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM6 | 4 | pacifidlog | 24x23 | 203 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM7 | 4 | pacifidlog | 23x25 | 177 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM8 | 4 | cave | 11x14 | 100 | open: round 2 |
| EM_SEAFLOOR_CAVERN_ROOM9 | 4 | cave | 27x46 | 930 | open: round 2 |
| EM_CAVE_OF_ORIGIN_ENTRANCE | 4 | cave | 19x26 | 415 | open: round 2 |
| EM_CAVE_OF_ORIGIN_1F | 4 | cave | 23x23 | 436 | open: round 2 |
| EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP1 | 4 | cave | 23x23 | 415 | open: round 2 |
| EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP2 | 4 | cave | 21x21 | 396 | open: round 2 |
| EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP3 | 4 | cave | 19x21 | 396 | open: round 2 |
| EM_CAVE_OF_ORIGIN_B1F | 4 | cave | 19x19 | 275 | open: round 2 |
| EM_VICTORY_ROAD_1F | 4 | cave | 46x45 | 1364 | open: round 2 |
| EM_VICTORY_ROAD_B1F | 4 | cave | 46x31 | 1055 | open: round 2 |
| EM_VICTORY_ROAD_B2F | 4 | cave | 46x31 | 1055 | open: round 2 |
| EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM | 4 | cave | 35x35 | 794 | open: round 2 |
| EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | 4 | cave | 46x38 | 952 | open: round 2 |
| EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | 4 | cave | 21x15 | 255 | open: round 2 |
| EM_SHOAL_CAVE_LOW_TIDE_LOWER_ROOM | 4 | cave | 31x14 | 323 | open: round 2 |
| EM_SHOAL_CAVE_HIGH_TIDE_ENTRANCE_ROOM | 4 | cave | 35x35 | 569 | open: round 2 |
| EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | 4 | cave | 46x38 | 759 | open: round 2 |
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
| EM_SKY_PILLAR_1F | 4 | pacifidlog | 14x14 | 63 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders) |
| EM_SKY_PILLAR_2F | 4 | pacifidlog | 14x14 | 62 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders) |
| EM_SKY_PILLAR_3F | 4 | pacifidlog | 14x14 | 65 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders) |
| EM_SKY_PILLAR_4F | 4 | pacifidlog | 14x14 | 72 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders) |
| EM_SHOAL_CAVE_LOW_TIDE_ICE_ROOM | 4 | cave | 20x30 | 284 | open: round 2 |
| EM_SKY_PILLAR_5F | 4 | pacifidlog | 14x14 | 91 | round 1 INSTALLED 2026-10-26 (S pit flat + boulders) |
| EM_MAGMA_HIDEOUT_1F | 4 | lavaridge | 37x38 | 1007 | open: round 2 |
| EM_MAGMA_HIDEOUT_2F_1R | 4 | lavaridge | 33x39 | 888 | open: round 2 |
| EM_MAGMA_HIDEOUT_2F_2R | 4 | lavaridge | 49x28 | 1090 | round 1 INSTALLED 2026-10-26 (L lava flat) |
| EM_MAGMA_HIDEOUT_3F_1R | 4 | lavaridge | 28x24 | 484 | round 1 INSTALLED 2026-10-26 (L lava flat) |
| EM_MAGMA_HIDEOUT_3F_2R | 4 | lavaridge | 24x17 | 183 | open: round 2 |
| EM_MAGMA_HIDEOUT_4F | 4 | lavaridge | 59x28 | 1243 | round 1 INSTALLED 2026-10-26 (L lava flat) |
| EM_MAGMA_HIDEOUT_3F_3R | 4 | lavaridge | 33x24 | 691 | round 1 INSTALLED 2026-10-26 (L lava flat) |
| EM_MAGMA_HIDEOUT_2F_3R | 4 | lavaridge | 60x19 | 1011 | open: round 2 |
| EM_MIRAGE_TOWER_1F | 4 | mirage_tower | 21x17 | 202 | open: round 2 |
| EM_MIRAGE_TOWER_2F | 4 | mirage_tower | 21x17 | 206 | open: round 2 |
| EM_MIRAGE_TOWER_3F | 4 | mirage_tower | 21x17 | 202 | open: round 2 |
| EM_MIRAGE_TOWER_4F | 4 | mirage_tower | 13x10 | 63 | open: round 2 |
| EM_DESERT_UNDERPASS | 4 | cave | 139x23 | 2517 | open: round 2 |
| EM_ARTISAN_CAVE_B1F | 4 | cave | 46x54 | 1674 | open: round 2 |
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
