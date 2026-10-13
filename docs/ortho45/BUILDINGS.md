# Buildings vs the original 2D art (ortho45)

One picture per building: the 3D scene from the ortho45 camera (1280x720, 2 px per map px), centred on the rectangle centre cell, player on the walkable cell below the rectangle. Scored by `tools/ortho45/diff.py --rect <rect> --shift auto --mask building` (tol 12). MASK: only BUILDING pixels count. `ref.building_mask` takes the original art only: the ring of cells 2 cells around the rectangle gives the ground metatiles (walkable ring cells, plus blocked ones seen 4+ times); a rectangle pixel equal to the same in-cell pixel of one of them is a ground candidate; only candidates 4-connected to the rectangle border through candidates are ground (water, paving, terrain); everything else is building (the silhouette). `masked %` = differing building pixels / building pixels in the rectangle (the scored number, sorted by it). `all px %` = the same over every pixel of the rectangle, as before the mask. `mask px` = building map px / rectangle map px. `above_differ` = differing pixels in the 3 cell rows directly above the rectangle, same columns (unmasked). Sheets are the cropped cmp strips: reference (cyan = mask border) | shot | reference dimmed with differing building pixels in magenta.

Sorted worst first. Sheet paths are relative to docs/ortho45/. The data folder holds 122 building files plus index.lua (the list, not a building); the 122 are all here.

| # | name | map | rect | masked % | all px % | mask px | above_differ | shift | sheet |
|---|---|---|---|---|---|---|---|---|---|
| 1 | abandoned_ship_wreck | EM_ROUTE108 | 27,3,33,5 | 75.940 | 69.420 | 54.4% | 15144 | -4,4 | sheets/abandoned_ship_wreck.png |
| 2 | museum2 | EM_LILYCOVE_CITY | 7,0,16,6 | 58.399 | 57.472 | 83.7% | 0 | 0,0 | sheets/museum2.png |
| 3 | weather | EM_ROUTE119 | 1,26,11,32 | 54.176 | 55.678 | 78.6% | 21686 | 0,0 | sheets/weather.png |
| 4 | trainer_hill_penthouse | EM_TRAINER_HILL_ROOF | 7,0,17,6 | 50.809 | 58.599 | 75.2% | 0 | 0,0 | sheets/trainer_hill_penthouse.png |
| 5 | ferry_birth_island | EM_BIRTH_ISLAND_EXTERIOR | 12,24,18,28 | 43.957 | 50.572 | 82.2% | 8336 | 0,0 | sheets/ferry_birth_island.png |
| 6 | ferry_navel_rock | EM_NAVEL_ROCK_EXTERIOR | 7,18,13,22 | 43.957 | 50.572 | 82.2% | 8128 | 0,0 | sheets/ferry_navel_rock.png |
| 7 | soot_box | EM_SOOTOPOLIS_CITY | 44,2,46,6 | 42.920 | 35.286 | 77.2% | 6144 | 0,0 | sheets/soot_box.png |
| 8 | soot_cone | EM_SOOTOPOLIS_CITY | 8,2,10,6 | 40.552 | 51.276 | 76.5% | 6144 | 0,0 | sheets/soot_cone.png |
| 9 | devon2 | EM_RUSTBORO_CITY | 7,6,16,15 | 40.116 | 42.707 | 86.4% | 17293 | 0,0 | sheets/devon2.png |
| 10 | soot_box2 | EM_SOOTOPOLIS_CITY | 2,5,4,9 | 36.198 | 37.174 | 75.8% | 0 | 0,0 | sheets/soot_box2.png |
| 11 | b128_route114_fossilmaniacshouse | EM_ROUTE114 | 28,3,31,5 | 27.053 | 28.288 | 98.3% | 7700 | 0,0 | sheets/b128_route114_fossilmaniacshouse.png |
| 12 | x_trainerhill_tower | EM_ROUTE111 | 29,106,33,110 | 26.969 | 29.266 | 96.8% | 9196 | 0,0 | sheets/x_trainerhill_tower.png |
| 13 | pacifidlog_hut | EM_PACIFIDLOG_TOWN | 15,10,17,13 | 26.483 | 44.010 | 68.6% | 5540 | 0,0 | sheets/pacifidlog_hut.png |
| 14 | treehouse | EM_FORTREE_CITY | 8,1,12,3 | 25.762 | 47.318 | 55.5% | 4928 | 0,0 | sheets/treehouse.png |
| 15 | x_trainerhill_entrance | EM_ROUTE111 | 31,112,31,113 | 20.559 | 22.266 | 97.9% | 1592 | 0,0 | sheets/x_trainerhill_entrance.png |
| 16 | birch_lab | EM_LITTLEROOT_TOWN | 3,12,9,16 | 16.375 | 17.009 | 98.1% | 1424 | 0,0 | sheets/birch_lab.png |
| 17 | b064_mossdeepcity_spacecenter | EM_MOSSDEEP_CITY | 60,2,68,15 | 16.262 | 24.059 | 73.5% | 13615 | 0,0 | sheets/b064_mossdeepcity_spacecenter.png |
| 18 | center2 | EM_PETALBURG_CITY | 19,13,22,16 | 15.450 | 21.069 | 89.6% | 1024 | 0,0 | sheets/center2.png |
| 19 | b147_battlefrontier_lounge7 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 4,17,6,20 | 13.933 | 14.714 | 98.8% | 7296 | 0,0 | sheets/b147_battlefrontier_lounge7.png |
| 20 | x_slateport_museum | EM_SLATEPORT_CITY | 28,22,33,26 | 13.018 | 15.273 | 97.3% | 11128 | 0,0 | sheets/x_slateport_museum.png |
| 21 | b139_route121_safarizoneentrance | EM_SAFARI_ZONE_SOUTH | 30,31,39,33 | 10.970 | 10.169 | 88.1% | 19292 | 0,0 | sheets/b139_route121_safarizoneentrance.png |
| 22 | x_mauville_eastblock | EM_MAUVILLE_CITY | 36,11,39,14 | 7.905 | 9.033 | 96.0% | 0 | 0,0 | sheets/x_mauville_eastblock.png |
| 23 | b055_lilycovecity_harbor | EM_LILYCOVE_CITY | 9,30,15,32 | 7.725 | 9.505 | 90.5% | 9940 | 0,0 | sheets/b055_lilycovecity_harbor.png |
| 24 | b154_battlefrontier_rankinghall | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 32,8,38,12 | 7.659 | 25.458 | 79.9% | 19215 | 0,0 | sheets/b154_battlefrontier_rankinghall.png |
| 25 | x_frontier_pike | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 40,19,44,29 | 7.263 | 22.067 | 58.0% | 4866 | 0,0 | sheets/x_frontier_pike.png |
| 26 | littleroot_house | EM_LITTLEROOT_TOWN | 2,4,6,8 | 7.070 | 12.766 | 93.5% | 5256 | 0,0 | sheets/littleroot_house.png |
| 27 | littleroot_house_may | EM_LITTLEROOT_TOWN | 13,4,17,8 | 7.070 | 12.625 | 93.5% | 5228 | 0,0 | sheets/littleroot_house_may.png |
| 28 | b124_route111_oldladysreststop | EM_ROUTE111 | 25,15,28,18 | 6.844 | 8.569 | 98.1% | 4648 | 0,0 | sheets/b124_route111_oldladysreststop.png |
| 29 | b053_lilycovecity_house3 | EM_LILYCOVE_CITY | 10,19,13,22 | 6.602 | 7.153 | 97.6% | 0 | 0,0 | sheets/b053_lilycovecity_house3.png |
| 30 | mart2 | EM_SLATEPORT_CITY | 12,23,15,26 | 6.368 | 19.873 | 85.1% | 192 | 0,0 | sheets/mart2.png |
| 31 | b092_lavaridgetown_herbshop | EM_LAVARIDGE_TOWN | 11,12,14,15 | 6.316 | 8.765 | 73.8% | 0 | 0,0 | sheets/b092_lavaridgetown_herbshop.png |
| 32 | b096_lavaridgetown_house | EM_LAVARIDGE_TOWN | 15,12,18,15 | 6.013 | 8.545 | 73.9% | 0 | 0,0 | sheets/b096_lavaridgetown_house.png |
| 33 | x_frontier_pyramid | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 51,5,65,14 | 5.948 | 6.803 | 70.4% | 23860 | 0,0 | sheets/x_frontier_pyramid.png |
| 34 | b102_fallarbortown_moverelearnershouse | EM_FALLARBOR_TOWN | 0,3,3,6 | 5.847 | 7.544 | 97.7% | 7468 | 0,0 | sheets/b102_fallarbortown_moverelearnershouse.png |
| 35 | b129_route114_lanetteshouse | EM_ROUTE114 | 25,33,29,36 | 5.615 | 6.914 | 98.4% | 8040 | 0,0 | sheets/b129_route114_lanetteshouse.png |
| 36 | b130_route116_tunnelersresthouse | EM_ROUTE116 | 36,5,40,8 | 5.611 | 6.992 | 98.5% | 11620 | 0,0 | sheets/b130_route116_tunnelersresthouse.png |
| 37 | x_verdanturf_battletent | EM_VERDANTURF_TOWN | 1,3,5,7 | 5.513 | 13.344 | 87.6% | 5080 | 0,0 | sheets/x_verdanturf_battletent.png |
| 38 | x_lilycove_house4 | EM_LILYCOVE_CITY | 11,11,14,14 | 5.228 | 7.568 | 95.3% | 12040 | 0,0 | sheets/x_lilycove_house4.png |
| 39 | b087_dewfordtown_hall | EM_DEWFORD_TOWN | 1,0,5,3 | 5.118 | 5.625 | 77.1% | 0 | 0,0 | sheets/b087_dewfordtown_hall.png |
| 40 | b134_route121_safarizoneentrance | EM_ROUTE121 | 35,3,39,5 | 4.380 | 4.479 | 90.4% | 5616 | 0,0 | sheets/b134_route121_safarizoneentrance.png |
| 41 | b002_petalburgcity_wallyshouse | EM_PETALBURG_CITY | 5,2,9,5 | 4.151 | 5.195 | 98.8% | 6096 | 0,0 | sheets/b002_petalburgcity_wallyshouse.png |
| 42 | x_frontier_exchange | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 7,25,13,28 | 3.983 | 5.539 | 98.1% | 7288 | 0,0 | sheets/x_frontier_exchange.png |
| 43 | b010_slateportcity_battletentlobby | EM_SLATEPORT_CITY | 8,8,12,12 | 3.907 | 15.875 | 86.4% | 11902 | 0,0 | sheets/b010_slateportcity_battletentlobby.png |
| 44 | x_route104_briney | EM_ROUTE104 | 15,47,19,50 | 3.839 | 4.434 | 99.2% | 1517 | 0,0 | sheets/x_route104_briney.png |
| 45 | x_route124_diverhouse | EM_ROUTE124 | 69,45,72,48 | 3.834 | 5.640 | 98.1% | 6432 | 0,0 | sheets/x_route124_diverhouse.png |
| 46 | b131_route117_pokemondaycare | EM_ROUTE117 | 50,2,53,5 | 3.833 | 5.566 | 98.1% | 854 | 0,0 | sheets/b131_route117_pokemondaycare.png |
| 47 | b138_safarizone_resthouse | EM_SAFARI_ZONE_SOUTHWEST | 28,4,31,7 | 3.786 | 5.542 | 98.0% | 8504 | 0,0 | sheets/b138_safarizone_resthouse.png |
| 48 | x_frontier_dome | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 14,6,25,17 | 3.679 | 13.379 | 46.7% | 25086 | 0,0 | sheets/x_frontier_dome.png |
| 49 | x_mauville_house1 | EM_MAUVILLE_CITY | 31,11,35,14 | 3.679 | 5.918 | 97.7% | 0 | 0,0 | sheets/x_mauville_house1.png |
| 50 | b028_rustborocity_pokemonschool | EM_RUSTBORO_CITY | 24,30,30,34 | 3.433 | 3.432 | 100.0% | 8396 | 0,0 | sheets/b028_rustborocity_pokemonschool.png |
| 51 | x_frontier_factory | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 4,30,18,38 | 3.394 | 14.559 | 83.6% | 34267 | 0,0 | sheets/x_frontier_factory.png |
| 52 | b135_route123_berrymastershouse | EM_ROUTE123 | 21,3,24,6 | 3.254 | 5.493 | 97.5% | 8536 | 0,0 | sheets/b135_route123_berrymastershouse.png |
| 53 | b022_mauvillecity_gamecorner | EM_MAUVILLE_CITY | 5,11,11,13 | 2.750 | 8.203 | 73.7% | 0 | 0,0 | sheets/b022_mauvillecity_gamecorner.png |
| 54 | b031_rustborocity_cuttershouse | EM_RUSTBORO_CITY | 7,34,11,38 | 2.704 | 2.703 | 100.0% | 0 | 0,0 | sheets/b031_rustborocity_cuttershouse.png |
| 55 | b023_mauvillecity_house2 | EM_MAUVILLE_CITY | 18,11,21,14 | 2.656 | 3.345 | 99.3% | 0 | 0,0 | sheets/b023_mauvillecity_house2.png |
| 56 | b050_lilycovecity_movedeletershouse | EM_LILYCOVE_CITY | 35,3,38,6 | 2.600 | 3.516 | 95.8% | 6732 | 0,0 | sheets/b050_lilycovecity_movedeletershouse.png |
| 57 | b118_route110_trickhouseentrance | EM_ROUTE110 | 9,61,13,66 | 2.531 | 5.951 | 92.6% | 15360 | 0,0 | sheets/b118_route110_trickhouseentrance.png |
| 58 | b127_route113_glassworkshop | EM_ROUTE113 | 32,2,35,5 | 2.346 | 3.394 | 98.9% | 5520 | 0,0 | sheets/b127_route113_glassworkshop.png |
| 59 | b099_fallarbortown_battletentlobby | EM_FALLARBOR_TOWN | 6,3,10,7 | 2.221 | 13.516 | 83.7% | 9322 | 0,0 | sheets/b099_fallarbortown_battletentlobby.png |
| 60 | b059_mossdeepcity_house2 | EM_MOSSDEEP_CITY | 66,22,69,25 | 1.885 | 2.881 | 98.4% | 9264 | 0,0 | sheets/b059_mossdeepcity_house2.png |
| 61 | b159_battlefrontier_lounge3 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 64,28,66,31 | 1.770 | 3.581 | 95.6% | 6880 | 0,0 | sheets/b159_battlefrontier_lounge3.png |
| 62 | b089_dewfordtown_gym | EM_DEWFORD_TOWN | 5,13,10,17 | 1.765 | 8.633 | 90.7% | 892 | 0,0 | sheets/b089_dewfordtown_gym.png |
| 63 | b013_slateportcity_nameratershouse | EM_SLATEPORT_CITY | 4,16,7,19 | 1.729 | 4.175 | 97.4% | 892 | 0,0 | sheets/b013_slateportcity_nameratershouse.png |
| 64 | b061_mossdeepcity_house3 | EM_MOSSDEEP_CITY | 48,3,51,6 | 1.717 | 2.869 | 98.8% | 7153 | 0,0 | sheets/b061_mossdeepcity_house3.png |
| 65 | b056_mossdeepcity_house1 | EM_MOSSDEEP_CITY | 27,6,30,9 | 1.680 | 2.588 | 98.8% | 8952 | 0,0 | sheets/b056_mossdeepcity_house1.png |
| 66 | b091_dewfordtown_house2 | EM_DEWFORD_TOWN | 7,5,10,8 | 1.680 | 2.393 | 97.4% | 1264 | 0,0 | sheets/b091_dewfordtown_house2.png |
| 67 | x_slateport_shipyard | EM_SLATEPORT_CITY | 24,32,31,38 | 1.599 | 2.518 | 99.0% | 16406 | 0,0 | sheets/x_slateport_shipyard.png |
| 68 | b019_mauvillecity_bikeshop | EM_MAUVILLE_CITY | 34,2,38,5 | 1.532 | 2.109 | 99.4% | 7632 | 0,0 | sheets/b019_mauvillecity_bikeshop.png |
| 69 | x_cablecar_mtchimney | EM_MT_CHIMNEY | 14,32,19,36 | 1.412 | 3.984 | 81.6% | 6428 | 0,0 | sheets/x_cablecar_mtchimney.png |
| 70 | b107_verdanturftown_friendshipratershouse | EM_VERDANTURF_TOWN | 0,11,3,14 | 1.391 | 3.589 | 96.5% | 1096 | 0,0 | sheets/b107_verdanturftown_friendshipratershouse.png |
| 71 | x_route104_flowershop | EM_ROUTE104 | 3,15,8,18 | 1.290 | 1.497 | 99.7% | 11606 | 0,0 | sheets/x_route104_flowershop.png |
| 72 | b106_verdanturftown_wandashouse | EM_VERDANTURF_TOWN | 8,11,12,14 | 1.169 | 3.203 | 96.9% | 152 | 0,0 | sheets/b106_verdanturftown_wandashouse.png |
| 73 | x_dewford_house1 | EM_DEWFORD_TOWN | 16,11,19,14 | 1.098 | 1.819 | 96.7% | 5968 | 0,0 | sheets/x_dewford_house1.png |
| 74 | b049_lilycovecity_pokemontrainerfanclub | EM_LILYCOVE_CITY | 37,11,41,14 | 1.053 | 4.238 | 96.4% | 7354 | 0,0 | sheets/b049_lilycovecity_pokemontrainerfanclub.png |
| 75 | b044_lilycovecity_departmentstore | EM_LILYCOVE_CITY | 23,0,31,6 | 1.049 | 1.110 | 99.9% | 0 | 0,0 | sheets/b044_lilycovecity_departmentstore.png |
| 76 | b014_slateportcity_harbor | EM_SLATEPORT_CITY | 24,7,31,12 | 0.846 | 6.722 | 88.5% | 18028 | 0,0 | sheets/b014_slateportcity_harbor.png |
| 77 | x_cyclingroad_north | EM_ROUTE110 | 14,12,19,16 | 0.717 | 0.729 | 98.0% | 6124 | 0,0 | sheets/x_cyclingroad_north.png |
| 78 | frontier_gate | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 23,61,29,65 | 0.668 | 4.955 | 75.2% | 6688 | 0,0 | sheets/frontier_gate.png |
| 79 | x_cyclingroad_south | EM_ROUTE110 | 15,84,20,88 | 0.600 | 2.148 | 96.6% | 15600 | 0,0 | sheets/x_cyclingroad_south.png |
| 80 | b032_rustborocity_house2 | EM_RUSTBORO_CITY | 28,24,32,28 | 0.597 | 3.578 | 96.9% | 0 | 0,0 | sheets/b032_rustborocity_house2.png |
| 81 | x_frontier_arena | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 35,23,43,29 | 0.582 | 6.572 | 83.1% | 4104 | 0,0 | sheets/x_frontier_arena.png |
| 82 | b052_lilycovecity_house2 | EM_LILYCOVE_CITY | 54,12,57,15 | 0.563 | 3.003 | 95.4% | 5224 | 0,0 | sheets/b052_lilycovecity_house2.png |
| 83 | x_cablecar_route112 | EM_ROUTE112 | 27,22,32,27 | 0.562 | 12.033 | 69.5% | 13816 | 0,0 | sheets/x_cablecar_route112.png |
| 84 | x_slateport_fanclub | EM_SLATEPORT_CITY | 2,22,6,26 | 0.514 | 2.375 | 85.2% | 1812 | 0,0 | sheets/x_slateport_fanclub.png |
| 85 | b108_verdanturftown_house | EM_VERDANTURF_TOWN | 16,12,19,15 | 0.506 | 1.953 | 96.5% | 0 | 0,0 | sheets/b108_verdanturftown_house.png |
| 86 | b024_rustborocity_gym | EM_RUSTBORO_CITY | 24,15,29,19 | 0.440 | 8.372 | 88.7% | 4544 | 0,0 | sheets/b024_rustborocity_gym.png |
| 87 | b048_lilycovecity_contestlobby | EM_LILYCOVE_CITY | 20,18,26,24 | 0.385 | 7.741 | 91.1% | 0 | 0,0 | sheets/b048_lilycovecity_contestlobby.png |
| 88 | b093_lavaridgetown_gym | EM_LAVARIDGE_TOWN | 2,11,7,15 | 0.354 | 7.161 | 91.9% | 4856 | 0,0 | sheets/b093_lavaridgetown_gym.png |
| 89 | b003_petalburgcity_gym | EM_PETALBURG_CITY | 12,4,17,8 | 0.345 | 8.919 | 90.7% | 10560 | 0,0 | sheets/b003_petalburgcity_gym.png |
| 90 | b017_mauvillecity_gym | EM_MAUVILLE_CITY | 5,1,10,5 | 0.345 | 8.294 | 90.7% | 2676 | 0,0 | sheets/b017_mauvillecity_gym.png |
| 91 | b057_mossdeepcity_gym | EM_MOSSDEEP_CITY | 35,5,40,9 | 0.345 | 9.076 | 90.7% | 12192 | 0,0 | sheets/b057_mossdeepcity_gym.png |
| 92 | b051_lilycovecity_house1 | EM_LILYCOVE_CITY | 41,3,44,6 | 0.306 | 1.001 | 95.8% | 5120 | 0,0 | sheets/b051_lilycovecity_house1.png |
| 93 | b045_lilycovecity_covelilymotel | EM_LILYCOVE_CITY | 36,20,41,24 | 0.257 | 3.099 | 91.1% | 0 | 0,0 | sheets/b045_lilycovecity_covelilymotel.png |
| 94 | b152_battlefrontier_battlepalacelobby | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 40,51,50,56 | 0.245 | 10.233 | 57.9% | 18815 | 0,0 | sheets/b152_battlefrontier_battlepalacelobby.png |
| 95 | b157_battlefrontier_lounge5 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 21,48,26,51 | 0.181 | 1.335 | 98.8% | 4704 | 0,0 | sheets/b157_battlefrontier_lounge5.png |
| 96 | b160_battlefrontier_lounge8 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 13,49,15,51 | 0.175 | 0.825 | 99.0% | 0 | 0,0 | sheets/b160_battlefrontier_lounge8.png |
| 97 | b068_sootopoliscity_gym | EM_SOOTOPOLIS_CITY | 28,29,33,32 | 0.142 | 10.286 | 57.4% | 5736 | 0,0 | sheets/b068_sootopoliscity_gym.png |
| 98 | b145_battlefrontier_scottshouse | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 43,2,45,5 | 0.134 | 3.190 | 96.9% | 2640 | 0,0 | sheets/b145_battlefrontier_scottshouse.png |
| 99 | b078_evergrandecity_pokemonleague | EM_EVER_GRANDE_CITY | 13,0,23,5 | 0.125 | 2.998 | 94.7% | 0 | 0,0 | sheets/b078_evergrandecity_pokemonleague.png |
| 100 | b001_petalburgcity_house1 | EM_PETALBURG_CITY | 9,16,12,19 | 0.099 | 1.880 | 98.2% | 0 | 0,0 | sheets/b001_petalburgcity_house1.png |
| 101 | b158_battlefrontier_lounge6 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 4,6,6,8 | 0.090 | 1.215 | 97.0% | 4320 | 0,0 | sheets/b158_battlefrontier_lounge6.png |
| 102 | x_route111_winstrate | EM_ROUTE111 | 11,109,15,113 | 0.080 | 1.594 | 97.5% | 10756 | 0,0 | sheets/x_route111_winstrate.png |
| 103 | b143_battlefrontier_lounge2 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 44,41,49,44 | 0.033 | 1.514 | 98.5% | 5548 | 0,0 | sheets/b143_battlefrontier_lounge2.png |
| 104 | b133_route119_house | EM_ROUTE119 | 32,106,35,109 | 0.025 | 1.855 | 98.1% | 9264 | 0,0 | sheets/b133_route119_house.png |
| 105 | x_route118_pinkhouse | EM_ROUTE118 | 0,14,3,17 | 0.025 | 0.317 | 99.5% | 8632 | 0,0 | sheets/x_route118_pinkhouse.png |
| 106 | b005_petalburgcity_house2 | EM_PETALBURG_CITY | 19,21,22,24 | 0.000 | 1.831 | 98.1% | 3696 | 0,0 | sheets/b005_petalburgcity_house2.png |
| 107 | b016_slateportcity_house | EM_SLATEPORT_CITY | 20,41,29,44 | 0.000 | 0.234 | 99.8% | 1040 | 0,0 | sheets/b016_slateportcity_house.png |
| 108 | b025_rustborocity_flat1 | EM_RUSTBORO_CITY | 9,25,17,30 | 0.000 | 0.022 | 99.7% | 7268 | 0,0 | sheets/b025_rustborocity_flat1.png |
| 109 | b030_rustborocity_house1 | EM_RUSTBORO_CITY | 31,15,35,19 | 0.000 | 0.000 | 97.2% | 3890 | 0,0 | sheets/b030_rustborocity_house1.png |
| 110 | b033_rustborocity_flat2 | EM_RUSTBORO_CITY | 3,43,9,51 | 0.000 | 0.310 | 99.7% | 456 | 0,0 | sheets/b033_rustborocity_flat2.png |
| 111 | b034_rustborocity_house3 | EM_RUSTBORO_CITY | 24,42,29,46 | 0.000 | 0.000 | 98.8% | 3322 | 0,0 | sheets/b034_rustborocity_house3.png |
| 112 | b037_fortreecity_gym | EM_FORTREE_CITY | 19,7,24,11 | 0.000 | 9.310 | 90.7% | 10378 | 0,0 | sheets/b037_fortreecity_gym.png |
| 113 | b062_mossdeepcity_stevenshouse | EM_MOSSDEEP_CITY | 18,7,21,10 | 0.000 | 0.977 | 99.0% | 9964 | 0,0 | sheets/b062_mossdeepcity_stevenshouse.png |
| 114 | b063_mossdeepcity_house4 | EM_MOSSDEEP_CITY | 17,13,20,16 | 0.000 | 0.928 | 98.8% | 968 | 0,0 | sheets/b063_mossdeepcity_house4.png |
| 115 | b065_mossdeepcity_gamecorner | EM_MOSSDEEP_CITY | 35,21,39,24 | 0.000 | 0.723 | 98.9% | 624 | 0,0 | sheets/b065_mossdeepcity_gamecorner.png |
| 116 | b083_oldaletown_house1 | EM_OLDALE_TOWN | 4,4,7,7 | 0.000 | 1.343 | 97.9% | 3260 | 0,0 | sheets/b083_oldaletown_house1.png |
| 117 | b084_oldaletown_house2 | EM_OLDALE_TOWN | 14,13,17,16 | 0.000 | 1.343 | 97.9% | 0 | 0,0 | sheets/b084_oldaletown_house2.png |
| 118 | b101_fallarbortown_cozmoshouse | EM_FALLARBOR_TOWN | 5,14,8,17 | 0.000 | 1.270 | 97.3% | 0 | 0,0 | sheets/b101_fallarbortown_cozmoshouse.png |
| 119 | b117_route109_seashorehouse | EM_ROUTE109 | 10,3,15,5 | 0.000 | 6.662 | 83.8% | 6244 | 0,0 | sheets/b117_route109_seashorehouse.png |
| 120 | b146_battlefrontier_lounge4 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 52,42,54,44 | 0.000 | 1.128 | 98.7% | 912 | 0,0 | sheets/b146_battlefrontier_lounge4.png |
| 121 | b155_battlefrontier_lounge1 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 3,42,5,44 | 0.000 | 1.128 | 98.7% | 912 | 0,0 | sheets/b155_battlefrontier_lounge1.png |
| 122 | x_frontier_tower | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 11,0,21,14 | 0.000 | 8.016 | 81.6% | 0 | 0,0 | sheets/x_frontier_tower.png |

## Counts (rect_percent)

| bucket | buildings |
|---|---|
| under 2% | 63 |
| 2-10% | 38 |
| 10-30% | 11 |
| over 30% | 10 |
| failed | 0 |
| total | 122 |

Buckets (masked %): under 2% is < 2; 2-10% is 2 to < 10; 10-30% is 10 to 30; over 30% is > 30.

