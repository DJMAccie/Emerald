# ALL STAIRS ledger (task 31, 2026-10-27)

Census: tools/stairs/census (game lib, 505 of 518 maps dumped; 13 Battle Frontier / Slateport interior maps never finished the dump: not censused). 407 flights = connected groups of stair cells. Representative spots per class: 94, captured at L4/L6/L7 from the installed game (docs/stairs/sheets, images untracked).

## Result

- One real fault found and FIXED (commit 48d3348, `tools/stairs/install_s1.sh`, Gen3Rock.append): a cliff-face cell flush with a walkable neighbour took that neighbour's tile as its lid; beside a flight the neighbour is the stair tile, so the rock top turned stair-grey at tread height (grey wing plates beside the flight: Route 120 (20,11), Lilycove (31,11)/(55,20), Route 119, Faraway Island). Stair cells are no longer lid candidates. Texture only, geometry unchanged, 94 spots 0 fallbacks.
- Judged OK from the sheets: generic outdoor flights (Route 111 (21,123), Route 112 (20,43), Routes 114/115/119/120, Mt Pyre, Ever Grande, Slateport, Lilycove, Mossdeep, Faraway, Frontier), Pokemon Center recipe stairs, house/shop door stairs (alcove model), cave flights and ladders, Sootopolis, contest hall, Abandoned Ship deck.
- Ghost cards G5 (grey untextured stairs) and H2 pale slabs: the grey IS the drawn stair art (2 light/dark bands per tile); treads match.
- Left (design, not changed): (1) the first riser at a flight's foot is a plain wall (0 up to the lowest cell's base) because the walking field (TerrainLevels.at) is tied to flightTreads; visible on low cameras at Lilycove. (2) Route 119 (27,28): the two flank cells beside the flight (tile 0x091, a rock-foot tile) stand flush as relief boxes with the tile's grey-blue foot rim on top: a rock-class item (Gen3Relief top art), not the stairs. (3) 13 interior maps not censused.

## Classes

| tileset pair | builder | flights | verdict |
|---|---|---|---|
| building__battle_pyramid | stepcell-noflight | 2 | n/a: pyramid floor tile, not a flight |
| building__contest | steps | 3 | ok: contest stage steps |
| building__elite_four | steps | 5 | ok: flat striped carpet runway, no rise in the 2D either |
| building__pokemon_center | recipe:building__pokemon_center | 34 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8) |
| building__sootopolis_gym | ladder | 2 | ok: ladder model on the wall, reads as the 2D ladder |
| general__battle_frontier_outside_east | generic | 3 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__battle_frontier_outside_west | generic | 2 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__cave | generic | 34 | ok: cave flight, treads from the cave stair art |
| general__cave | ladder | 30 | ok: ladder model on the wall, reads as the 2D ladder |
| general__cave | stepcell-noflight | 1 | n/a: step-flagged cave floor cell, not a flight |
| general__ever_grande | generic | 3 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__facility | generic | 15 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__facility | stepcell-noflight | 3 | ok: Abandoned Ship deck stair tile, drawn by its neighbouring flight (sheet ST_EM_ABANDONED_SHIP_DECK_10_10) |
| general__facility | steps | 1 | ok: steps cell drawn from the stair art |
| general__fallarbor | generic | 15 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__fallarbor | steps | 1 | ok: steps cell drawn from the stair art |
| general__fortree | generic | 33 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__fortree | stepcell-noflight | 9 | n/a: grass meadow step cells (ledge relief, task 15), not a flight |
| general__lavaridge | generic | 39 | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself |
| general__lavaridge | stepcell-noflight | 4 | n/a: sand-pit step cells / part of the Route 112 flight beside its rows |
| general__lilycove | generic | 18 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__lilycove | stepcell-noflight | 1 | n/a: step-flagged grass cell, not a flight |
| general__lilycove | steps | 2 | ok: steps cell drawn from the stair art |
| general__mauville | generic | 4 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__mauville | steps | 2 | ok: steps cell drawn from the stair art |
| general__meteor_falls | generic | 14 | ok: cave flight, treads from the cave stair art |
| general__meteor_falls | ladder | 8 | ok: ladder model on the wall, reads as the 2D ladder |
| general__mirage_tower | ladder | 6 | ok: ladder model on the wall, reads as the 2D ladder |
| general__mossdeep | generic | 6 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__navel_rock | generic | 1 | ok: cave flight, treads from the cave stair art |
| general__navel_rock | ladder | 38 | ok: ladder model on the wall, reads as the 2D ladder |
| general__navel_rock | stepcell-noflight | 1 | n/a: step-flagged cave floor cell, not a flight |
| general__rustboro | generic | 12 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__rustboro | stepcell-noflight | 1 | n/a: step-flagged grass cell, not a flight |
| general__rustboro | steps | 2 | ok: steps cell drawn from the stair art |
| general__slateport | generic | 2 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design) |
| general__slateport | stepcell-noflight | 28 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight |
| general__sootopolis | steps | 22 | ok: Gen3Stairs 4 treads per cell from the stair art |

## Flights (map, cells, x0,y0..x1,y1, tiles, verdict)

- EM_BATTLE_FRONTIER_BATTLE_PYRAMID_LOBBY | b:battle_pyramid | 5 cells (7,8)-(7,12) | 224 | n/a: pyramid floor tile, not a flight
- EM_BATTLE_PYRAMID_SQUARE08 | b:battle_pyramid | 1 cells (6,7)-(6,7) | 28D | n/a: pyramid floor tile, not a flight
- EM_LILYCOVE_CITY_CONTEST_HALL | b:contest | 6 cells (24,15)-(26,16) | 283,284,285 | ok: contest stage steps (ST_EM_LILYCOVE_CITY_CONTEST_HALL_24_17)
- EM_LILYCOVE_CITY_CONTEST_HALL | b:contest | 6 cells (12,27)-(14,28) | 293,294,295 | ok: contest stage steps (ST_EM_LILYCOVE_CITY_CONTEST_HALL_24_17)
- EM_LILYCOVE_CITY_CONTEST_HALL | b:contest | 6 cells (36,27)-(38,28) | 2B3,2B4,2B5 | ok: contest stage steps (ST_EM_LILYCOVE_CITY_CONTEST_HALL_24_17)
- EM_EVER_GRANDE_CITY_HALL1 | b:elite_four | 24 cells (4,5)-(6,12) | 2D9,2DA,2E1,2E2 | ok: flat striped carpet runway, no rise in the 2D either (ST_EM_EVER_GRANDE_CITY_HALL4_4_34)
- EM_EVER_GRANDE_CITY_HALL2 | b:elite_four | 24 cells (4,5)-(6,12) | 2D9,2DA,2E1,2E2 | ok: flat striped carpet runway, no rise in the 2D either (ST_EM_EVER_GRANDE_CITY_HALL4_4_34)
- EM_EVER_GRANDE_CITY_HALL3 | b:elite_four | 24 cells (4,5)-(6,12) | 2D9,2DA,2E1,2E2 | ok: flat striped carpet runway, no rise in the 2D either (ST_EM_EVER_GRANDE_CITY_HALL4_4_34)
- EM_EVER_GRANDE_CITY_HALL4 | b:elite_four | 87 cells (4,5)-(6,33) | 2D9,2DA,2E1,2E2 | ok: flat striped carpet runway, no rise in the 2D either (ST_EM_EVER_GRANDE_CITY_HALL4_4_34)
- EM_EVER_GRANDE_CITY_HALL5 | b:elite_four | 24 cells (4,5)-(6,12) | 2D9,2DA,2E1,2E2 | ok: flat striped carpet runway, no rise in the 2D either (ST_EM_EVER_GRANDE_CITY_HALL4_4_34)
- EM_BATTLE_FRONTIER_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_BATTLE_FRONTIER_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_DEWFORD_TOWN_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_DEWFORD_TOWN_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_EVER_GRANDE_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_EVER_GRANDE_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_EVER_GRANDE_CITY_POKEMON_LEAGUE_1F | b:pokemon_center | 6 cells (0,6)-(1,8) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_EVER_GRANDE_CITY_POKEMON_LEAGUE_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_FALLARBOR_TOWN_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_FALLARBOR_TOWN_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_FORTREE_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_FORTREE_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_LAVARIDGE_TOWN_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_LAVARIDGE_TOWN_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_LILYCOVE_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_LILYCOVE_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_MAUVILLE_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_MAUVILLE_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_MOSSDEEP_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_MOSSDEEP_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_OLDALE_TOWN_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_OLDALE_TOWN_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_PACIFIDLOG_TOWN_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_PACIFIDLOG_TOWN_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_PETALBURG_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_PETALBURG_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_RUSTBORO_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_RUSTBORO_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_SLATEPORT_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_SLATEPORT_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_SOOTOPOLIS_CITY_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_SOOTOPOLIS_CITY_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_VERDANTURF_TOWN_POKEMON_CENTER_1F | b:pokemon_center | 6 cells (0,5)-(1,7) | 280,281,288,289,290,291 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_VERDANTURF_TOWN_POKEMON_CENTER_2F | b:pokemon_center | 6 cells (0,5)-(1,7) | 298,299,2A0,2A1,2A8,2A9 | ok: recipe stair model, matches the 2D flight (Pokemon Center, sheet ST_EM_BATTLE_FRONTIER_POKEMON_CENTER_1F_0_8)
- EM_SOOTOPOLIS_CITY_GYM_1F | b:sootopolis_gym | 1 cells (11,22)-(11,22) | 21C | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SOOTOPOLIS_CITY_GYM_B1F | b:sootopolis_gym | 1 cells (11,22)-(11,22) | 214 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_BATTLE_FRONTIER_OUTSIDE_EAST | g:battle_frontier_outside_east | 4 cells (41,8)-(44,8) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_BATTLE_FRONTIER_OUTSIDE_EAST | g:battle_frontier_outside_east | 12 cells (14,23)-(19,24) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_BATTLE_FRONTIER_OUTSIDE_EAST | g:battle_frontier_outside_east | 8 cells (54,27)-(61,27) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_BATTLE_FRONTIER_OUTSIDE_WEST | g:battle_frontier_outside_west | 20 cells (17,23)-(26,24) | 0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_BATTLE_FRONTIER_OUTSIDE_WEST | g:battle_frontier_outside_west | 1 cells (31,28)-(31,28) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ARTISAN_CAVE_B1F | g:cave | 3 cells (32,12)-(32,14) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (11,22)-(11,22) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (10,24)-(10,24) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 2 cells (32,26)-(32,27) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (21,35)-(21,35) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (32,35)-(32,35) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (18,37)-(18,37) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (16,39)-(16,39) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_MARINE_CAVE_END | g:cave | 1 cells (14,9)-(14,9) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SEAFLOOR_CAVERN_ROOM1 | g:cave | 1 cells (10,4)-(10,4) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SEAFLOOR_CAVERN_ROOM9 | g:cave | 1 cells (12,7)-(12,7) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SEAFLOOR_CAVERN_ROOM9 | g:cave | 1 cells (12,11)-(12,11) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SEAFLOOR_CAVERN_ROOM9 | g:cave | 1 cells (12,16)-(12,16) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SEAFLOOR_CAVERN_ROOM9 | g:cave | 1 cells (12,21)-(12,21) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | g:cave | 1 cells (42,6)-(42,6) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | g:cave | 1 cells (16,17)-(16,17) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | g:cave | 1 cells (22,23)-(22,23) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | g:cave | 1 cells (36,23)-(36,23) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | g:cave | 1 cells (8,27)-(8,27) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM | g:cave | 1 cells (12,12)-(12,12) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM | g:cave | 2 cells (18,17)-(18,18) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 1 cells (42,6)-(42,6) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 2 cells (34,13)-(34,14) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 1 cells (11,18)-(11,18) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 1 cells (22,23)-(22,23) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 2 cells (32,24)-(32,25) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 1 cells (8,27)-(8,27) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | g:cave | 1 cells (11,5)-(11,5) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | g:cave | 1 cells (7,7)-(7,7) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | g:cave | 1 cells (4,9)-(4,9) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | g:cave | 1 cells (7,11)-(7,11) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SKY_PILLAR_ENTRANCE | g:cave | 1 cells (6,6)-(6,6) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_SKY_PILLAR_ENTRANCE | g:cave | 1 cells (6,11)-(6,11) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_TERRA_CAVE_END | g:cave | 1 cells (9,9)-(9,9) | 204 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_ARTISAN_CAVE_1F | g:cave | 1 cells (6,5)-(6,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (38,5)-(38,5) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_CAVE_OF_ORIGIN_1F | g:cave | 1 cells (14,5)-(14,5) | 33D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_CAVE_OF_ORIGIN_B1F | g:cave | 1 cells (9,3)-(9,3) | 341 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP1 | g:cave | 1 cells (14,5)-(14,5) | 33D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP2 | g:cave | 1 cells (14,5)-(14,5) | 33D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP3 | g:cave | 1 cells (14,5)-(14,5) | 33D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_GRANITE_CAVE_1F | g:cave | 1 cells (35,3)-(35,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_GRANITE_CAVE_1F | g:cave | 1 cells (17,11)-(17,11) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_GRANITE_CAVE_B1F | g:cave | 1 cells (35,3)-(35,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_GRANITE_CAVE_B1F | g:cave | 1 cells (17,11)-(17,11) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_GRANITE_CAVE_B2F | g:cave | 1 cells (35,3)-(35,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_GRANITE_CAVE_B2F | g:cave | 1 cells (17,11)-(17,11) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | g:cave | 1 cells (42,4)-(42,4) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM | g:cave | 1 cells (19,14)-(19,14) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_ICE_ROOM | g:cave | 1 cells (17,10)-(17,10) | 37F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 1 cells (42,4)-(42,4) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 1 cells (19,14)-(19,14) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM | g:cave | 1 cells (38,15)-(38,15) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_LOWER_ROOM | g:cave | 1 cells (7,2)-(7,2) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_LOWER_ROOM | g:cave | 1 cells (28,11)-(28,11) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | g:cave | 1 cells (7,4)-(7,4) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_SHOAL_CAVE_LOW_TIDE_STAIRS_ROOM | g:cave | 1 cells (3,12)-(3,12) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_VICTORY_ROAD_1F | g:cave | 1 cells (9,14)-(9,14) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_VICTORY_ROAD_1F | g:cave | 1 cells (21,32)-(21,32) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_VICTORY_ROAD_1F | g:cave | 1 cells (42,38)-(42,38) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_VICTORY_ROAD_B1F | g:cave | 1 cells (9,14)-(9,14) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_VICTORY_ROAD_B1F | g:cave | 1 cells (21,32)-(21,32) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_VICTORY_ROAD_B2F | g:cave | 1 cells (9,14)-(9,14) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_VICTORY_ROAD_B2F | g:cave | 1 cells (21,32)-(21,32) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_ARTISAN_CAVE_B1F | g:cave | 1 cells (32,36)-(32,36) | 204 | n/a: step-flagged cave floor cell, not a flight
- EM_EVER_GRANDE_CITY | g:ever_grande | 3 cells (25,26)-(27,26) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_EVER_GRANDE_CITY | g:ever_grande | 2 cells (19,51)-(20,51) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_EVER_GRANDE_CITY | g:ever_grande | 2 cells (19,54)-(20,54) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_AQUA_HIDEOUT_1F | g:facility | 2 cells (5,17)-(5,18) | 228,22A | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_AQUA_HIDEOUT_1F | g:facility | 2 cells (22,17)-(22,18) | 228,22A | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_AQUA_HIDEOUT_1F | g:facility | 2 cells (5,25)-(5,26) | 228,22A | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_AQUA_HIDEOUT_1F | g:facility | 2 cells (22,25)-(22,26) | 228,22A | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_AQUA_HIDEOUT_UNUSED_RUBY_MAP2 | g:facility | 1 cells (31,10)-(31,10) | 3E5 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_AQUA_HIDEOUT_UNUSED_RUBY_MAP2 | g:facility | 1 cells (32,11)-(32,11) | 3FA | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_EXTERIOR | g:facility | 4 cells (19,15)-(20,16) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_EXTERIOR | g:facility | 2 cells (26,18)-(27,18) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_EXTERIOR | g:facility | 9 cells (24,21)-(26,23) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_EXTERIOR | g:facility | 10 cells (9,29)-(10,33) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_EXTERIOR | g:facility | 2 cells (14,38)-(15,38) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_EXTERIOR | g:facility | 12 cells (27,38)-(29,41) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_SUMMIT | g:facility | 3 cells (22,10)-(24,10) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_SUMMIT | g:facility | 3 cells (22,14)-(24,14) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MT_PYRE_SUMMIT | g:facility | 3 cells (22,17)-(24,17) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ABANDONED_SHIP_DECK | g:facility | 4 cells (10,8)-(11,9) | 0AF,0CF | ok: Abandoned Ship deck stair tile, drawn by its neighbouring flight (sheet ST_EM_ABANDONED_SHIP_DECK_10_10)
- EM_ABANDONED_SHIP_DECK | g:facility | 4 cells (13,13)-(14,14) | 0AF,0CF | ok: Abandoned Ship deck stair tile, drawn by its neighbouring flight (sheet ST_EM_ABANDONED_SHIP_DECK_10_10)
- EM_AQUA_HIDEOUT_UNUSED_RUBY_MAP2 | g:facility | 1 cells (32,9)-(32,9) | 3F5 | ok: Abandoned Ship deck stair tile, drawn by its neighbouring flight (sheet ST_EM_ABANDONED_SHIP_DECK_10_10)
- EM_MT_PYRE_SUMMIT | g:facility | 3 cells (22,31)-(24,31) | 330,331 | ok: steps cell drawn from the stair art
- EM_ROUTE114 | g:fallarbor | 1 cells (6,49)-(6,49) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE114 | g:fallarbor | 2 cells (25,57)-(26,57) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE114 | g:fallarbor | 2 cells (13,67)-(14,67) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE114 | g:fallarbor | 2 cells (13,69)-(14,69) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE114 | g:fallarbor | 2 cells (24,69)-(25,69) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE114 | g:fallarbor | 2 cells (24,71)-(25,71) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 4 cells (18,12)-(19,13) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 2 cells (27,12)-(28,12) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 2 cells (11,33)-(12,33) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 2 cells (24,42)-(25,42) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 2 cells (16,46)-(17,46) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 2 cells (26,48)-(27,48) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 2 cells (10,70)-(11,70) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 1 cells (21,70)-(21,70) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 1 cells (20,71)-(20,71) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE115 | g:fallarbor | 2 cells (28,8)-(28,9) | 0E8 | ok: steps cell drawn from the stair art
- EM_FORTREE_CITY | g:fortree | 2 cells (10,5)-(10,6) | 245,24D | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FORTREE_CITY | g:fortree | 2 cells (25,5)-(25,6) | 245,24D | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FORTREE_CITY | g:fortree | 2 cells (32,5)-(32,6) | 245,24D | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FORTREE_CITY | g:fortree | 2 cells (12,15)-(12,16) | 245,24D | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FORTREE_CITY | g:fortree | 2 cells (37,15)-(37,16) | 245,24D | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 1 cells (7,4)-(7,4) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 1 cells (9,16)-(9,16) | 002 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (13,22)-(14,22) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 4 cells (27,26)-(28,27) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (25,31)-(26,31) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 1 cells (5,33)-(5,33) | 2D1 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 1 cells (7,33)-(7,33) | 2D0 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (24,36)-(25,36) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 1 cells (25,41)-(25,41) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (21,48)-(22,48) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 1 cells (24,49)-(24,49) | 071 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (19,53)-(20,53) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (6,54)-(6,55) | 0E8 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (5,80)-(6,80) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (35,89)-(36,89) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (30,97)-(31,97) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (11,103)-(12,103) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 2 cells (30,103)-(31,103) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 2 cells (20,11)-(20,12) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 1 cells (-3,15)-(-3,15) | 245 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 2 cells (7,15)-(7,16) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 2 cells (12,65)-(12,66) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 2 cells (21,67)-(21,68) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 2 cells (34,67)-(34,68) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 1 cells (22,69)-(22,69) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 1 cells (33,69)-(33,69) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 1 cells (22,77)-(22,77) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE120 | g:fortree | 1 cells (12,87)-(12,87) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE119 | g:fortree | 1 cells (14,18)-(14,18) | 001 | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE119 | g:fortree | 2 cells (23,33)-(23,34) | 001 | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE119 | g:fortree | 1 cells (6,34)-(6,34) | 119 | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE119 | g:fortree | 4 cells (5,52)-(8,52) | 001 | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE119 | g:fortree | 1 cells (17,91)-(17,91) | 001 | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE119 | g:fortree | 1 cells (25,94)-(25,94) | 001 | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE120 | g:fortree | 2 cells (28,15)-(28,16) | 001 | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE120 | g:fortree | 1 cells (-3,16)-(-3,16) | 24D | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_ROUTE120 | g:fortree | 1 cells (12,86)-(12,86) | 0AF | n/a: grass meadow step cells (ledge relief, task 15), not a flight
- EM_JAGGED_PASS | g:lavaridge | 2 cells (13,7)-(14,7) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_JAGGED_PASS | g:lavaridge | 1 cells (21,14)-(21,14) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_JAGGED_PASS | g:lavaridge | 2 cells (13,18)-(14,18) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_JAGGED_PASS | g:lavaridge | 2 cells (21,21)-(22,21) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_JAGGED_PASS | g:lavaridge | 2 cells (14,37)-(15,37) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_LAVARIDGE_TOWN | g:lavaridge | 1 cells (3,10)-(3,10) | 291 | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_LAVARIDGE_TOWN | g:lavaridge | 1 cells (5,10)-(5,10) | 291 | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_1F | g:lavaridge | 2 cells (23,27)-(24,27) | 0AF,0CF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_1R | g:lavaridge | 2 cells (22,7)-(23,7) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_1R | g:lavaridge | 4 cells (9,12)-(10,13) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_1R | g:lavaridge | 4 cells (20,21)-(21,22) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_1R | g:lavaridge | 1 cells (17,25)-(17,25) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_1R | g:lavaridge | 2 cells (12,28)-(12,29) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_2R | g:lavaridge | 1 cells (40,7)-(40,7) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_2R | g:lavaridge | 1 cells (40,10)-(40,10) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_2R | g:lavaridge | 1 cells (40,13)-(40,13) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_2R | g:lavaridge | 1 cells (8,14)-(8,14) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_2R | g:lavaridge | 1 cells (27,15)-(27,15) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_3R | g:lavaridge | 1 cells (49,2)-(49,2) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_3R | g:lavaridge | 1 cells (16,3)-(16,3) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_3R | g:lavaridge | 6 cells (49,4)-(49,9) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_2F_3R | g:lavaridge | 6 cells (16,5)-(16,10) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_1R | g:lavaridge | 2 cells (7,8)-(7,9) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_1R | g:lavaridge | 2 cells (20,12)-(20,13) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_3R | g:lavaridge | 1 cells (16,3)-(16,3) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_3R | g:lavaridge | 1 cells (16,5)-(16,5) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_3R | g:lavaridge | 1 cells (16,7)-(16,7) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_3R | g:lavaridge | 1 cells (16,9)-(16,9) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_3R | g:lavaridge | 1 cells (16,11)-(16,11) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_3R | g:lavaridge | 1 cells (16,13)-(16,13) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_3F_3R | g:lavaridge | 1 cells (16,15)-(16,15) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MAGMA_HIDEOUT_4F | g:lavaridge | 8 cells (45,11)-(46,14) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MT_CHIMNEY | g:lavaridge | 1 cells (25,22)-(25,22) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MT_CHIMNEY | g:lavaridge | 1 cells (20,24)-(20,24) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MT_CHIMNEY | g:lavaridge | 1 cells (26,27)-(26,27) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MT_CHIMNEY | g:lavaridge | 1 cells (26,29)-(26,29) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_MT_CHIMNEY | g:lavaridge | 1 cells (26,32)-(26,32) | 2AF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_ROUTE112 | g:lavaridge | 2 cells (20,41)-(21,41) | 0AF,0CF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_ROUTE112 | g:lavaridge | 2 cells (20,43)-(21,43) | 0AF,0CF | ok: generic treads (task 25 made the flank flush); G5 grey stairs = the stair art itself (ST_EM_ROUTE112_20_43)
- EM_LAVARIDGE_TOWN | g:lavaridge | 1 cells (2,9)-(2,9) | 2A8 | n/a: sand-pit step cells / part of the Route 112 flight beside its rows
- EM_LAVARIDGE_TOWN | g:lavaridge | 1 cells (4,9)-(4,9) | 2A8 | n/a: sand-pit step cells / part of the Route 112 flight beside its rows
- EM_LAVARIDGE_TOWN | g:lavaridge | 1 cells (6,9)-(6,9) | 28A | n/a: sand-pit step cells / part of the Route 112 flight beside its rows
- EM_ROUTE112 | g:lavaridge | 2 cells (20,42)-(21,42) | 0AF,0CF | n/a: sand-pit step cells / part of the Route 112 flight beside its rows
- EM_LILYCOVE_CITY | g:lilycove | 4 cells (31,11)-(32,12) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_LILYCOVE_CITY | g:lilycove | 4 cells (55,20)-(56,21) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE121 | g:lilycove | 2 cells (37,8)-(38,8) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE121 | g:lilycove | 4 cells (30,10)-(31,11) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE121 | g:lilycove | 2 cells (42,11)-(43,11) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE121 | g:lilycove | 2 cells (30,13)-(31,13) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTH | g:lilycove | 1 cells (22,23)-(22,23) | 323 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTH | g:lilycove | 2 cells (9,24)-(10,24) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTHEAST | g:lilycove | 2 cells (30,9)-(31,9) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTHEAST | g:lilycove | 2 cells (26,13)-(27,13) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTHEAST | g:lilycove | 3 cells (20,22)-(22,22) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTHWEST | g:lilycove | 2 cells (13,14)-(14,14) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTHWEST | g:lilycove | 2 cells (13,31)-(14,31) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_NORTHWEST | g:lilycove | 2 cells (21,35)-(22,35) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_SOUTH | g:lilycove | 2 cells (13,9)-(14,9) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_SOUTHEAST | g:lilycove | 2 cells (18,17)-(19,17) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_SOUTHWEST | g:lilycove | 3 cells (7,6)-(9,6) | 001 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SAFARI_ZONE_SOUTHWEST | g:lilycove | 4 cells (19,22)-(20,23) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_LILYCOVE_CITY | g:lilycove | 4 cells (30,32)-(33,32) | 001 | n/a: step-flagged grass cell, not a flight
- EM_SAFARI_ZONE_NORTHWEST | g:lilycove | 1 cells (8,42)-(8,42) | 0E8 | ok: steps cell drawn from the stair art
- EM_SAFARI_ZONE_SOUTHWEST | g:lilycove | 2 cells (8,2)-(8,3) | 0E8 | ok: steps cell drawn from the stair art
- EM_ROUTE110 | g:mauville | 6 cells (21,11)-(22,13) | 2D4 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE110 | g:mauville | 6 cells (28,89)-(29,91) | 2D4 | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE111 | g:mauville | 3 cells (21,122)-(23,122) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE111 | g:mauville | 3 cells (21,125)-(23,125) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE111 | g:mauville | 2 cells (29,6)-(29,7) | 0E8 | ok: steps cell drawn from the stair art
- EM_ROUTE111 | g:mauville | 2 cells (17,36)-(17,37) | 0E8 | ok: steps cell drawn from the stair art
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 3 cells (27,10)-(27,12) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (2,16)-(2,16) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (27,16)-(27,16) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (2,18)-(2,18) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (14,19)-(14,19) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 2 cells (6,23)-(6,24) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (13,29)-(13,29) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (13,31)-(13,31) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (13,33)-(13,33) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (13,37)-(13,37) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_2R | g:meteor_falls | 1 cells (9,5)-(9,5) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_2R | g:meteor_falls | 1 cells (9,7)-(9,7) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_2R | g:meteor_falls | 1 cells (9,9)-(9,9) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_2R | g:meteor_falls | 1 cells (9,11)-(9,11) | 202 | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_METEOR_FALLS_1F_1R | g:meteor_falls | 1 cells (5,4)-(5,4) | 20D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_METEOR_FALLS_1F_2R | g:meteor_falls | 1 cells (4,14)-(4,14) | 20D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_METEOR_FALLS_1F_2R | g:meteor_falls | 1 cells (7,20)-(7,20) | 20D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_METEOR_FALLS_1F_2R | g:meteor_falls | 1 cells (21,23)-(21,23) | 20D | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_METEOR_FALLS_B1F_1R | g:meteor_falls | 1 cells (5,6)-(5,6) | 20C | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_METEOR_FALLS_B1F_1R | g:meteor_falls | 1 cells (7,11)-(7,11) | 20C | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_METEOR_FALLS_B1F_1R | g:meteor_falls | 1 cells (18,15)-(18,15) | 20C | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_METEOR_FALLS_B1F_1R | g:meteor_falls | 1 cells (3,23)-(3,23) | 20C | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_MIRAGE_TOWER_1F | g:mirage_tower | 1 cells (15,2)-(15,2) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_MIRAGE_TOWER_2F | g:mirage_tower | 1 cells (15,2)-(15,2) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_MIRAGE_TOWER_2F | g:mirage_tower | 1 cells (18,12)-(18,12) | 216 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_MIRAGE_TOWER_3F | g:mirage_tower | 1 cells (2,4)-(2,4) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_MIRAGE_TOWER_3F | g:mirage_tower | 1 cells (18,12)-(18,12) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_MIRAGE_TOWER_4F | g:mirage_tower | 1 cells (1,4)-(1,4) | 205 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_MOSSDEEP_CITY | g:mossdeep | 6 cells (63,18)-(65,19) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MOSSDEEP_CITY | g:mossdeep | 6 cells (63,21)-(65,22) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MOSSDEEP_CITY | g:mossdeep | 2 cells (25,25)-(26,25) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MOSSDEEP_CITY | g:mossdeep | 4 cells (32,27)-(33,28) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MOSSDEEP_CITY | g:mossdeep | 2 cells (57,27)-(58,27) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_MOSSDEEP_CITY | g:mossdeep | 2 cells (46,31)-(47,31) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_NAVEL_ROCK_BOTTOM | g:navel_rock | 1 cells (11,15)-(11,15) | 37B | ok: cave flight, treads from the cave stair art (ST_EM_ARTISAN_CAVE_B1F_32_15, ST_EM_METEOR_FALLS_1F_1R_27_13)
- EM_NAVEL_ROCK_B1F | g:navel_rock | 1 cells (4,3)-(4,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_B1F | g:navel_rock | 1 cells (18,9)-(18,9) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_BOTTOM | g:navel_rock | 1 cells (14,19)-(14,19) | 38B | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN01 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN01 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN02 | g:navel_rock | 1 cells (3,3)-(3,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN02 | g:navel_rock | 1 cells (5,5)-(5,5) | 366 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN03 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN03 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN04 | g:navel_rock | 1 cells (3,3)-(3,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN04 | g:navel_rock | 1 cells (5,5)-(5,5) | 366 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN05 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN05 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN06 | g:navel_rock | 1 cells (3,3)-(3,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN06 | g:navel_rock | 1 cells (5,5)-(5,5) | 366 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN07 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN07 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN08 | g:navel_rock | 1 cells (3,3)-(3,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN08 | g:navel_rock | 1 cells (5,5)-(5,5) | 366 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN09 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN09 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN10 | g:navel_rock | 1 cells (3,3)-(3,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN10 | g:navel_rock | 1 cells (5,5)-(5,5) | 366 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN11 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_DOWN11 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_ENTRANCE | g:navel_rock | 1 cells (10,5)-(10,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_FORK | g:navel_rock | 1 cells (4,6)-(4,6) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_FORK | g:navel_rock | 1 cells (22,6)-(22,6) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_FORK | g:navel_rock | 1 cells (11,79)-(11,79) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_TOP | g:navel_rock | 1 cells (13,20)-(13,20) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP1 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP1 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP2 | g:navel_rock | 1 cells (3,3)-(3,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP2 | g:navel_rock | 1 cells (5,5)-(5,5) | 366 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP3 | g:navel_rock | 1 cells (3,3)-(3,3) | 217 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP3 | g:navel_rock | 1 cells (5,5)-(5,5) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP4 | g:navel_rock | 1 cells (3,3)-(3,3) | 23F | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_UP4 | g:navel_rock | 1 cells (5,5)-(5,5) | 366 | ok: ladder model on the wall, reads as the 2D ladder (ST_EM_METEOR_FALLS_B1F_1R_5_7, ST_EM_MIRAGE_TOWER_3F_18_13)
- EM_NAVEL_ROCK_FORK | g:navel_rock | 1 cells (13,10)-(13,10) | 204 | n/a: step-flagged cave floor cell, not a flight
- EM_FARAWAY_ISLAND_ENTRANCE | g:rustboro | 1 cells (9,17)-(9,17) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FARAWAY_ISLAND_ENTRANCE | g:rustboro | 1 cells (17,21)-(17,21) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FARAWAY_ISLAND_ENTRANCE | g:rustboro | 1 cells (3,23)-(3,23) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FARAWAY_ISLAND_ENTRANCE | g:rustboro | 1 cells (11,28)-(11,28) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_FARAWAY_ISLAND_ENTRANCE | g:rustboro | 2 cells (15,34)-(16,34) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE116 | g:rustboro | 1 cells (53,8)-(53,8) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE116 | g:rustboro | 1 cells (72,8)-(72,8) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE116 | g:rustboro | 1 cells (52,11)-(52,11) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE116 | g:rustboro | 1 cells (72,11)-(72,11) | 0AF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SOUTHERN_ISLAND_EXTERIOR | g:rustboro | 2 cells (24,11)-(25,11) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SOUTHERN_ISLAND_EXTERIOR | g:rustboro | 2 cells (24,13)-(25,13) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SOUTHERN_ISLAND_EXTERIOR | g:rustboro | 2 cells (15,18)-(16,18) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE104 | g:rustboro | 2 cells (15,51)-(15,52) | 001 | n/a: step-flagged grass cell, not a flight
- EM_ROUTE104 | g:rustboro | 2 cells (16,54)-(17,54) | 0AF,0CF | ok: steps cell drawn from the stair art
- EM_ROUTE104 | g:rustboro | 2 cells (28,70)-(29,70) | 0AF,0CF | ok: steps cell drawn from the stair art
- EM_SLATEPORT_CITY | g:slateport | 3 cells (17,58)-(19,58) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_SLATEPORT_CITY | g:slateport | 2 cells (32,58)-(33,58) | 0AF,0CF | fixed 48d3348: generic treads match the 2D; a rock-flanked flight no longer grows stair-grey wing plates (Gen3Rock lid). Foot riser = plain wall (left, design)
- EM_ROUTE109 | g:slateport | 3 cells (17,-2)-(19,-2) | 0AF,0CF | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (32,-2)-(33,-2) | 0AF,0CF | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 1 cells (16,9)-(16,9) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (18,9)-(18,10) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (22,9)-(22,10) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (25,9)-(25,10) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 6 cells (13,10)-(15,13) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (16,11)-(17,11) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (23,11)-(24,11) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (11,12)-(11,13) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 1 cells (12,14)-(12,14) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 1 cells (19,14)-(19,14) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (24,14)-(24,15) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (17,15)-(17,16) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 5 cells (19,16)-(23,16) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (13,17)-(13,18) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 3 cells (18,17)-(18,19) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (15,18)-(15,19) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (22,18)-(22,19) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (24,18)-(24,19) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (16,20)-(17,20) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 1 cells (23,20)-(23,20) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (17,53)-(17,54) | 2E8,2F0 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (19,53)-(19,54) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 1 cells (18,55)-(18,55) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (19,56)-(19,57) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 2 cells (21,56)-(21,57) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_ROUTE109 | g:slateport | 1 cells (20,58)-(20,58) | 124 | n/a: step-flagged beach sand (0x124) / plaza tiles, not a flight
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (19,6)-(20,6) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 1 cells (45,7)-(45,7) | 244 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (9,8)-(9,9) | 244 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (29,8)-(30,8) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (45,9)-(45,10) | 244 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 6 cells (34,10)-(35,12) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (15,11)-(16,11) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (15,13)-(16,13) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (25,15)-(26,15) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 4 cells (16,16)-(17,17) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 4 cells (49,18)-(50,19) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (25,19)-(26,19) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (20,20)-(20,21) | 244 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (12,21)-(13,21) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (44,22)-(45,22) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (12,23)-(13,23) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (21,24)-(22,24) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 1 cells (53,29)-(53,29) | 244 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (48,31)-(49,31) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (17,32)-(18,32) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 2 cells (19,35)-(20,35) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
- EM_SOOTOPOLIS_CITY | g:sootopolis | 4 cells (43,35)-(44,36) | 244,245 | ok: Gen3Stairs 4 treads per cell from the stair art (ST_EM_SOOTOPOLIS_CITY_34_13)
