# Buildings vs the original 2D art (ortho45)

One picture per building: the 3D scene from the ortho45 camera (1280x720, 2 px per map px), centred on the rectangle centre cell, player on the walkable cell below the rectangle. Scored by `tools/ortho45/diff.py --rect <rect> --shift auto` (tol 12). `rect_percent` = differing pixels inside the rectangle (plus valid pixels). `above_differ` = differing pixels in the 3 cell rows directly above the rectangle, same columns. Sheets are the cropped cmp strips: reference | shot | reference dimmed with differing pixels in magenta.

Sorted worst first. Sheet paths are relative to docs/ortho45/. The data folder holds 122 building files plus index.lua (the list, not a building); the 122 are all here.

| # | name | map | rect | rect_percent | above_differ | shift | sheet |
|---|---|---|---|---|---|---|---|
| 1 | trainer_hill_penthouse | EM_TRAINER_HILL_ROOF | 7,0,17,6 | 58.599 | 0 | 0,0 | sheets/trainer_hill_penthouse.png |
| 2 | museum2 | EM_LILYCOVE_CITY | 7,0,16,6 | 57.472 | 0 | 0,0 | sheets/museum2.png |
| 3 | weather | EM_ROUTE119 | 1,26,11,32 | 56.652 | 21678 | 0,0 | sheets/weather.png |
| 4 | abandoned_ship_wreck | EM_ROUTE108 | 27,3,33,5 | 51.804 | 11353 | 0,0 | sheets/abandoned_ship_wreck.png |
| 5 | soot_cone | EM_SOOTOPOLIS_CITY | 8,2,10,6 | 51.276 | 6144 | 0,0 | sheets/soot_cone.png |
| 6 | treehouse | EM_FORTREE_CITY | 8,1,12,3 | 50.117 | 4936 | 0,0 | sheets/treehouse.png |
| 7 | ferry_birth_island | EM_BIRTH_ISLAND_EXTERIOR | 12,24,18,28 | 49.986 | 7969 | 0,0 | sheets/ferry_birth_island.png |
| 8 | ferry_navel_rock | EM_NAVEL_ROCK_EXTERIOR | 7,18,13,22 | 49.986 | 7757 | 0,0 | sheets/ferry_navel_rock.png |
| 9 | pacifidlog_hut | EM_PACIFIDLOG_TOWN | 15,10,17,13 | 47.461 | 5312 | 0,0 | sheets/pacifidlog_hut.png |
| 10 | devon2 | EM_RUSTBORO_CITY | 7,6,16,15 | 42.707 | 16781 | 0,0 | sheets/devon2.png |
| 11 | soot_box | EM_SOOTOPOLIS_CITY | 44,2,46,6 | 35.286 | 2748 | 0,0 | sheets/soot_box.png |
| 12 | soot_box2 | EM_SOOTOPOLIS_CITY | 2,5,4,9 | 33.594 | 0 | 0,0 | sheets/soot_box2.png |
| 13 | birch_lab | EM_LITTLEROOT_TOWN | 3,12,9,16 | 32.227 | 1430 | 0,0 | sheets/birch_lab.png |
| 14 | b128_route114_fossilmaniacshouse | EM_ROUTE114 | 28,3,31,5 | 30.697 | 8412 | 0,0 | sheets/b128_route114_fossilmaniacshouse.png |
| 15 | littleroot_house | EM_LITTLEROOT_TOWN | 2,4,6,8 | 30.406 | 5504 | 0,0 | sheets/littleroot_house.png |
| 16 | littleroot_house_may | EM_LITTLEROOT_TOWN | 13,4,17,8 | 30.266 | 5476 | 0,0 | sheets/littleroot_house_may.png |
| 17 | x_trainerhill_tower | EM_ROUTE111 | 29,106,33,110 | 29.203 | 9196 | 0,0 | sheets/x_trainerhill_tower.png |
| 18 | b092_lavaridgetown_herbshop | EM_LAVARIDGE_TOWN | 11,12,14,15 | 27.344 | 0 | 0,0 | sheets/b092_lavaridgetown_herbshop.png |
| 19 | b096_lavaridgetown_house | EM_LAVARIDGE_TOWN | 15,12,18,15 | 27.124 | 0 | 0,0 | sheets/b096_lavaridgetown_house.png |
| 20 | b124_route111_oldladysreststop | EM_ROUTE111 | 25,15,28,18 | 27.002 | 4648 | 0,0 | sheets/b124_route111_oldladysreststop.png |
| 21 | b130_route116_tunnelersresthouse | EM_ROUTE116 | 36,5,40,8 | 26.270 | 11620 | 0,0 | sheets/b130_route116_tunnelersresthouse.png |
| 22 | b129_route114_lanetteshouse | EM_ROUTE114 | 25,33,29,36 | 26.016 | 7560 | 0,0 | sheets/b129_route114_lanetteshouse.png |
| 23 | b154_battlefrontier_rankinghall | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 32,8,38,12 | 25.458 | 19215 | 0,0 | sheets/b154_battlefrontier_rankinghall.png |
| 24 | center2 | EM_PETALBURG_CITY | 19,13,22,16 | 25.220 | 1024 | 0,0 | sheets/center2.png |
| 25 | b064_mossdeepcity_spacecenter | EM_MOSSDEEP_CITY | 60,2,68,15 | 25.108 | 14253 | 0,0 | sheets/b064_mossdeepcity_spacecenter.png |
| 26 | b002_petalburgcity_wallyshouse | EM_PETALBURG_CITY | 5,2,9,5 | 24.272 | 6280 | 0,0 | sheets/b002_petalburgcity_wallyshouse.png |
| 27 | b131_route117_pokemondaycare | EM_ROUTE117 | 50,2,53,5 | 24.170 | 983 | 0,0 | sheets/b131_route117_pokemondaycare.png |
| 28 | b013_slateportcity_nameratershouse | EM_SLATEPORT_CITY | 4,16,7,19 | 24.121 | 1140 | 0,0 | sheets/b013_slateportcity_nameratershouse.png |
| 29 | b138_safarizone_resthouse | EM_SAFARI_ZONE_SOUTHWEST | 28,4,31,7 | 24.121 | 8504 | 0,0 | sheets/b138_safarizone_resthouse.png |
| 30 | b135_route123_berrymastershouse | EM_ROUTE123 | 21,3,24,6 | 24.072 | 8532 | 0,0 | sheets/b135_route123_berrymastershouse.png |
| 31 | x_route124_diverhouse | EM_ROUTE124 | 69,45,72,48 | 23.926 | 5920 | 0,0 | sheets/x_route124_diverhouse.png |
| 32 | x_verdanturf_battletent | EM_VERDANTURF_TOWN | 1,3,5,7 | 23.609 | 5080 | 0,0 | sheets/x_verdanturf_battletent.png |
| 33 | x_route104_briney | EM_ROUTE104 | 15,47,19,50 | 22.617 | 1609 | 0,0 | sheets/x_route104_briney.png |
| 34 | x_trainerhill_entrance | EM_ROUTE111 | 31,112,31,113 | 22.266 | 1592 | 0,0 | sheets/x_trainerhill_entrance.png |
| 35 | mart2 | EM_SLATEPORT_CITY | 12,23,15,26 | 21.484 | 0 | 0,0 | sheets/mart2.png |
| 36 | b062_mossdeepcity_stevenshouse | EM_MOSSDEEP_CITY | 18,7,21,10 | 21.313 | 11944 | 0,0 | sheets/b062_mossdeepcity_stevenshouse.png |
| 37 | x_frontier_pike | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 40,19,44,29 | 21.072 | 4866 | 0,0 | sheets/x_frontier_pike.png |
| 38 | b001_petalburgcity_house1 | EM_PETALBURG_CITY | 9,16,12,19 | 20.801 | 248 | 0,0 | sheets/b001_petalburgcity_house1.png |
| 39 | b133_route119_house | EM_ROUTE119 | 32,106,35,109 | 20.776 | 9272 | 0,0 | sheets/b133_route119_house.png |
| 40 | b005_petalburgcity_house2 | EM_PETALBURG_CITY | 19,21,22,24 | 20.752 | 3944 | 0,0 | sheets/b005_petalburgcity_house2.png |
| 41 | b106_verdanturftown_wandashouse | EM_VERDANTURF_TOWN | 8,11,12,14 | 20.586 | 384 | 0,0 | sheets/b106_verdanturftown_wandashouse.png |
| 42 | b127_route113_glassworkshop | EM_ROUTE113 | 32,2,35,5 | 19.873 | 5520 | 0,0 | sheets/b127_route113_glassworkshop.png |
| 43 | b016_slateportcity_house | EM_SLATEPORT_CITY | 20,41,29,44 | 19.336 | 1672 | 0,0 | sheets/b016_slateportcity_house.png |
| 44 | b083_oldaletown_house1 | EM_OLDALE_TOWN | 4,4,7,7 | 19.165 | 3384 | 0,0 | sheets/b083_oldaletown_house1.png |
| 45 | b084_oldaletown_house2 | EM_OLDALE_TOWN | 14,13,17,16 | 19.165 | 124 | 0,0 | sheets/b084_oldaletown_house2.png |
| 46 | b102_fallarbortown_moverelearnershouse | EM_FALLARBOR_TOWN | 0,3,3,6 | 18.994 | 7468 | 0,0 | sheets/b102_fallarbortown_moverelearnershouse.png |
| 47 | x_frontier_factory | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 4,30,18,38 | 18.919 | 33951 | 0,0 | sheets/x_frontier_factory.png |
| 48 | b107_verdanturftown_friendshipratershouse | EM_VERDANTURF_TOWN | 0,11,3,14 | 18.530 | 1128 | 0,0 | sheets/b107_verdanturftown_friendshipratershouse.png |
| 49 | b087_dewfordtown_hall | EM_DEWFORD_TOWN | 1,0,5,3 | 17.422 | 0 | 0,0 | sheets/b087_dewfordtown_hall.png |
| 50 | x_frontier_dome | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 14,6,25,17 | 16.933 | 25086 | 0,0 | sheets/x_frontier_dome.png |
| 51 | b108_verdanturftown_house | EM_VERDANTURF_TOWN | 16,12,19,15 | 16.772 | 184 | 0,0 | sheets/b108_verdanturftown_house.png |
| 52 | b050_lilycovecity_movedeletershouse | EM_LILYCOVE_CITY | 35,3,38,6 | 16.699 | 6840 | 0,0 | sheets/b050_lilycovecity_movedeletershouse.png |
| 53 | b053_lilycovecity_house3 | EM_LILYCOVE_CITY | 10,19,13,22 | 16.553 | 128 | 0,0 | sheets/b053_lilycovecity_house3.png |
| 54 | b010_slateportcity_battletentlobby | EM_SLATEPORT_CITY | 8,8,12,12 | 15.328 | 11892 | 0,0 | sheets/b010_slateportcity_battletentlobby.png |
| 55 | b147_battlefrontier_lounge7 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 4,17,6,20 | 15.299 | 7296 | 0,0 | sheets/b147_battlefrontier_lounge7.png |
| 56 | x_slateport_museum | EM_SLATEPORT_CITY | 28,22,33,26 | 15.273 | 10608 | 0,0 | sheets/x_slateport_museum.png |
| 57 | x_lilycove_house4 | EM_LILYCOVE_CITY | 11,11,14,14 | 15.039 | 12040 | 0,0 | sheets/x_lilycove_house4.png |
| 58 | b099_fallarbortown_battletentlobby | EM_FALLARBOR_TOWN | 6,3,10,7 | 15.000 | 9326 | 0,0 | sheets/b099_fallarbortown_battletentlobby.png |
| 59 | b056_mossdeepcity_house1 | EM_MOSSDEEP_CITY | 27,6,30,9 | 14.990 | 11364 | 0,0 | sheets/b056_mossdeepcity_house1.png |
| 60 | b059_mossdeepcity_house2 | EM_MOSSDEEP_CITY | 66,22,69,25 | 14.990 | 12200 | 0,0 | sheets/b059_mossdeepcity_house2.png |
| 61 | b061_mossdeepcity_house3 | EM_MOSSDEEP_CITY | 48,3,51,6 | 14.893 | 11386 | 0,0 | sheets/b061_mossdeepcity_house3.png |
| 62 | b049_lilycovecity_pokemontrainerfanclub | EM_LILYCOVE_CITY | 37,11,41,14 | 14.824 | 7354 | 0,0 | sheets/b049_lilycovecity_pokemontrainerfanclub.png |
| 63 | x_slateport_shipyard | EM_SLATEPORT_CITY | 24,32,31,38 | 14.251 | 16378 | 0,0 | sheets/x_slateport_shipyard.png |
| 64 | b045_lilycovecity_covelilymotel | EM_LILYCOVE_CITY | 36,20,41,24 | 14.193 | 0 | 0,0 | sheets/b045_lilycovecity_covelilymotel.png |
| 65 | x_slateport_fanclub | EM_SLATEPORT_CITY | 2,22,6,26 | 13.719 | 1892 | 0,0 | sheets/x_slateport_fanclub.png |
| 66 | b101_fallarbortown_cozmoshouse | EM_FALLARBOR_TOWN | 5,14,8,17 | 13.574 | 136 | 0,0 | sheets/b101_fallarbortown_cozmoshouse.png |
| 67 | b063_mossdeepcity_house4 | EM_MOSSDEEP_CITY | 17,13,20,16 | 13.330 | 11092 | 0,0 | sheets/b063_mossdeepcity_house4.png |
| 68 | b091_dewfordtown_house2 | EM_DEWFORD_TOWN | 7,5,10,8 | 13.159 | 1360 | 0,0 | sheets/b091_dewfordtown_house2.png |
| 69 | b052_lilycovecity_house2 | EM_LILYCOVE_CITY | 54,12,57,15 | 13.110 | 5304 | 0,0 | sheets/b052_lilycovecity_house2.png |
| 70 | x_route104_flowershop | EM_ROUTE104 | 3,15,8,18 | 13.086 | 11611 | 0,0 | sheets/x_route104_flowershop.png |
| 71 | x_dewford_house1 | EM_DEWFORD_TOWN | 16,11,19,14 | 12.958 | 5520 | 0,0 | sheets/x_dewford_house1.png |
| 72 | x_cablecar_route112 | EM_ROUTE112 | 27,22,32,27 | 12.684 | 13820 | 0,0 | sheets/x_cablecar_route112.png |
| 73 | b051_lilycovecity_house1 | EM_LILYCOVE_CITY | 41,3,44,6 | 12.085 | 5000 | 0,0 | sheets/b051_lilycovecity_house1.png |
| 74 | x_frontier_pyramid | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 51,5,65,14 | 11.421 | 23080 | 0,0 | sheets/x_frontier_pyramid.png |
| 75 | b118_route110_trickhouseentrance | EM_ROUTE110 | 9,61,13,66 | 11.042 | 15360 | 0,0 | sheets/b118_route110_trickhouseentrance.png |
| 76 | b024_rustborocity_gym | EM_RUSTBORO_CITY | 24,15,29,19 | 10.417 | 4544 | 0,0 | sheets/b024_rustborocity_gym.png |
| 77 | b017_mauvillecity_gym | EM_MAUVILLE_CITY | 5,1,10,5 | 10.404 | 2676 | 0,0 | sheets/b017_mauvillecity_gym.png |
| 78 | b068_sootopoliscity_gym | EM_SOOTOPOLIS_CITY | 28,29,33,32 | 10.286 | 5736 | 0,0 | sheets/b068_sootopoliscity_gym.png |
| 79 | b152_battlefrontier_battlepalacelobby | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 40,51,50,56 | 10.257 | 17879 | 0,0 | sheets/b152_battlefrontier_battlepalacelobby.png |
| 80 | x_mauville_eastblock | EM_MAUVILLE_CITY | 36,11,39,14 | 10.254 | 0 | 0,0 | sheets/x_mauville_eastblock.png |
| 81 | b139_route121_safarizoneentrance | EM_SAFARI_ZONE_SOUTH | 30,31,39,33 | 10.169 | 19292 | 0,0 | sheets/b139_route121_safarizoneentrance.png |
| 82 | b089_dewfordtown_gym | EM_DEWFORD_TOWN | 5,13,10,17 | 9.883 | 892 | 0,0 | sheets/b089_dewfordtown_gym.png |
| 83 | b057_mossdeepcity_gym | EM_MOSSDEEP_CITY | 35,5,40,9 | 9.512 | 12192 | 0,0 | sheets/b057_mossdeepcity_gym.png |
| 84 | b055_lilycovecity_harbor | EM_LILYCOVE_CITY | 9,30,15,32 | 9.505 | 9940 | 0,0 | sheets/b055_lilycovecity_harbor.png |
| 85 | b003_petalburgcity_gym | EM_PETALBURG_CITY | 12,4,17,8 | 9.310 | 10560 | 0,0 | sheets/b003_petalburgcity_gym.png |
| 86 | b037_fortreecity_gym | EM_FORTREE_CITY | 19,7,24,11 | 9.310 | 10376 | 0,0 | sheets/b037_fortreecity_gym.png |
| 87 | x_frontier_tower | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 11,0,21,14 | 8.428 | 0 | 0,0 | sheets/x_frontier_tower.png |
| 88 | b031_rustborocity_cuttershouse | EM_RUSTBORO_CITY | 7,34,11,38 | 8.250 | 0 | 0,0 | sheets/b031_rustborocity_cuttershouse.png |
| 89 | b022_mauvillecity_gamecorner | EM_MAUVILLE_CITY | 5,11,11,13 | 8.203 | 0 | 0,0 | sheets/b022_mauvillecity_gamecorner.png |
| 90 | b048_lilycovecity_contestlobby | EM_LILYCOVE_CITY | 20,18,26,24 | 7.812 | 0 | 0,0 | sheets/b048_lilycovecity_contestlobby.png |
| 91 | b093_lavaridgetown_gym | EM_LAVARIDGE_TOWN | 2,11,7,15 | 7.161 | 4856 | 0,0 | sheets/b093_lavaridgetown_gym.png |
| 92 | b014_slateportcity_harbor | EM_SLATEPORT_CITY | 24,7,31,12 | 6.722 | 18016 | 0,0 | sheets/b014_slateportcity_harbor.png |
| 93 | b117_route109_seashorehouse | EM_ROUTE109 | 10,3,15,5 | 6.662 | 6244 | 0,0 | sheets/b117_route109_seashorehouse.png |
| 94 | x_frontier_arena | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 35,23,43,29 | 6.287 | 3312 | 0,0 | sheets/x_frontier_arena.png |
| 95 | x_mauville_house1 | EM_MAUVILLE_CITY | 31,11,35,14 | 5.918 | 0 | 0,0 | sheets/x_mauville_house1.png |
| 96 | x_frontier_exchange | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 7,25,13,28 | 5.455 | 7288 | 0,0 | sheets/x_frontier_exchange.png |
| 97 | b078_evergrandecity_pokemonleague | EM_EVER_GRANDE_CITY | 13,0,23,5 | 5.057 | 0 | 0,0 | sheets/b078_evergrandecity_pokemonleague.png |
| 98 | frontier_gate | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 23,61,29,65 | 4.955 | 6688 | 0,0 | sheets/frontier_gate.png |
| 99 | x_cablecar_mtchimney | EM_MT_CHIMNEY | 14,32,19,36 | 4.596 | 6428 | 0,0 | sheets/x_cablecar_mtchimney.png |
| 100 | b134_route121_safarizoneentrance | EM_ROUTE121 | 35,3,39,5 | 4.479 | 5616 | 0,0 | sheets/b134_route121_safarizoneentrance.png |
| 101 | b023_mauvillecity_house2 | EM_MAUVILLE_CITY | 18,11,21,14 | 4.199 | 0 | 0,0 | sheets/b023_mauvillecity_house2.png |
| 102 | b032_rustborocity_house2 | EM_RUSTBORO_CITY | 28,24,32,28 | 3.875 | 0 | 0,0 | sheets/b032_rustborocity_house2.png |
| 103 | b159_battlefrontier_lounge3 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 64,28,66,31 | 3.613 | 6880 | 0,0 | sheets/b159_battlefrontier_lounge3.png |
| 104 | b028_rustborocity_pokemonschool | EM_RUSTBORO_CITY | 24,30,30,34 | 3.432 | 8452 | 0,0 | sheets/b028_rustborocity_pokemonschool.png |
| 105 | b145_battlefrontier_scottshouse | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 43,2,45,5 | 3.190 | 3024 | 0,0 | sheets/b145_battlefrontier_scottshouse.png |
| 106 | b158_battlefrontier_lounge6 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 4,6,6,8 | 2.517 | 4320 | 0,0 | sheets/b158_battlefrontier_lounge6.png |
| 107 | b019_mauvillecity_bikeshop | EM_MAUVILLE_CITY | 34,2,38,5 | 2.188 | 7644 | 0,0 | sheets/b019_mauvillecity_bikeshop.png |
| 108 | x_cyclingroad_south | EM_ROUTE110 | 15,84,20,88 | 2.148 | 15312 | 0,0 | sheets/x_cyclingroad_south.png |
| 109 | x_route111_winstrate | EM_ROUTE111 | 11,109,15,113 | 1.594 | 10756 | 0,0 | sheets/x_route111_winstrate.png |
| 110 | b143_battlefrontier_lounge2 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 44,41,49,44 | 1.514 | 5400 | 0,0 | sheets/b143_battlefrontier_lounge2.png |
| 111 | b044_lilycovecity_departmentstore | EM_LILYCOVE_CITY | 23,0,31,6 | 1.383 | 0 | 0,0 | sheets/b044_lilycovecity_departmentstore.png |
| 112 | b157_battlefrontier_lounge5 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 21,48,26,51 | 1.335 | 4704 | 0,0 | sheets/b157_battlefrontier_lounge5.png |
| 113 | b146_battlefrontier_lounge4 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 52,42,54,44 | 1.128 | 912 | 0,0 | sheets/b146_battlefrontier_lounge4.png |
| 114 | b155_battlefrontier_lounge1 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 3,42,5,44 | 1.128 | 912 | 0,0 | sheets/b155_battlefrontier_lounge1.png |
| 115 | b160_battlefrontier_lounge8 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 13,49,15,51 | 0.825 | 0 | 0,0 | sheets/b160_battlefrontier_lounge8.png |
| 116 | x_cyclingroad_north | EM_ROUTE110 | 14,12,19,16 | 0.729 | 6124 | 0,0 | sheets/x_cyclingroad_north.png |
| 117 | b065_mossdeepcity_gamecorner | EM_MOSSDEEP_CITY | 35,21,39,24 | 0.723 | 624 | 0,0 | sheets/b065_mossdeepcity_gamecorner.png |
| 118 | x_route118_pinkhouse | EM_ROUTE118 | 0,14,3,17 | 0.317 | 8632 | 0,0 | sheets/x_route118_pinkhouse.png |
| 119 | b033_rustborocity_flat2 | EM_RUSTBORO_CITY | 3,43,9,51 | 0.310 | 456 | 0,0 | sheets/b033_rustborocity_flat2.png |
| 120 | b025_rustborocity_flat1 | EM_RUSTBORO_CITY | 9,25,17,30 | 0.022 | 7268 | 0,0 | sheets/b025_rustborocity_flat1.png |
| 121 | b030_rustborocity_house1 | EM_RUSTBORO_CITY | 31,15,35,19 | 0.000 | 3890 | 0,0 | sheets/b030_rustborocity_house1.png |
| 122 | b034_rustborocity_house3 | EM_RUSTBORO_CITY | 24,42,29,46 | 0.000 | 3322 | 0,0 | sheets/b034_rustborocity_house3.png |

## Counts (rect_percent)

| bucket | buildings |
|---|---|
| under 2% | 14 |
| 2-10% | 27 |
| 10-30% | 65 |
| over 30% | 16 |
| failed | 0 |
| total | 122 |

Buckets: under 2% is < 2; 2-10% is 2 to < 10; 10-30% is 10 to 30; over 30% is > 30.

