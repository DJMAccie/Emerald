# Buildings by kind of fault (ortho45, second pass)

`tools/ortho45/classify.py`: the shot slid over the original inside the building rectangle. `residual` = pixels still differing at the best offset; `shift` = that offset in screen px (2 per map px; dy < 0 = drawn higher or further north). Only building pixels count (ground and water inside the rectangle are left out). Flowers, trees and signs inside the rectangle count as differences.

## wrong (29)

| name | map | rect | as shot % | residual % | shift dx,dy | sheet |
|---|---|---|---|---|---|---|
| weather | EM_ROUTE119 | 1,26,11,32 | 54.2 | 54.2 | 0,0 | sheets/weather.png |
| ferry_birth_island | EM_BIRTH_ISLAND_EXTERIOR | 12,24,18,28 | 43.9 | 43.9 | 0,0 | sheets/ferry_birth_island.png |
| ferry_navel_rock | EM_NAVEL_ROCK_EXTERIOR | 7,18,13,22 | 43.9 | 43.9 | 0,0 | sheets/ferry_navel_rock.png |
| museum2 | EM_LILYCOVE_CITY | 7,0,16,6 | 58.4 | 43.0 | 0,6 | sheets/museum2.png |
| soot_box | EM_SOOTOPOLIS_CITY | 44,2,46,6 | 42.9 | 42.9 | 0,0 | sheets/soot_box.png |
| trainer_hill_penthouse | EM_TRAINER_HILL_ROOF | 7,0,17,6 | 50.8 | 42.3 | 0,12 | sheets/trainer_hill_penthouse.png |
| soot_cone | EM_SOOTOPOLIS_CITY | 8,2,10,6 | 40.6 | 40.6 | 0,0 | sheets/soot_cone.png |
| devon2 | EM_RUSTBORO_CITY | 7,6,16,15 | 40.1 | 40.1 | 0,0 | sheets/devon2.png |
| soot_box2 | EM_SOOTOPOLIS_CITY | 2,5,4,9 | 31.7 | 31.7 | 0,0 | sheets/soot_box2.png |
| pacifidlog_hut | EM_PACIFIDLOG_TOWN | 15,10,17,13 | 31.3 | 31.3 | 0,0 | sheets/pacifidlog_hut.png |
| birch_lab | EM_LITTLEROOT_TOWN | 3,12,9,16 | 31.0 | 31.0 | 0,0 | sheets/birch_lab.png |
| treehouse | EM_FORTREE_CITY | 8,1,12,3 | 30.8 | 30.8 | 0,0 | sheets/treehouse.png |
| b128_route114_fossilmaniacshouse | EM_ROUTE114 | 28,3,31,5 | 29.5 | 29.5 | 0,0 | sheets/b128_route114_fossilmaniacshouse.png |
| x_trainerhill_tower | EM_ROUTE111 | 29,106,33,110 | 26.9 | 26.9 | 0,0 | sheets/x_trainerhill_tower.png |
| littleroot_house | EM_LITTLEROOT_TOWN | 2,4,6,8 | 25.9 | 25.9 | 0,0 | sheets/littleroot_house.png |
| littleroot_house_may | EM_LITTLEROOT_TOWN | 13,4,17,8 | 25.9 | 25.9 | 0,0 | sheets/littleroot_house_may.png |
| b124_route111_oldladysreststop | EM_ROUTE111 | 25,15,28,18 | 25.6 | 25.6 | 0,0 | sheets/b124_route111_oldladysreststop.png |
| b130_route116_tunnelersresthouse | EM_ROUTE116 | 36,5,40,8 | 25.2 | 25.2 | 0,0 | sheets/b130_route116_tunnelersresthouse.png |
| b129_route114_lanetteshouse | EM_ROUTE114 | 25,33,29,36 | 25.0 | 25.0 | 0,0 | sheets/b129_route114_lanetteshouse.png |
| b002_petalburgcity_wallyshouse | EM_PETALBURG_CITY | 5,2,9,5 | 23.5 | 23.5 | 0,0 | sheets/b002_petalburgcity_wallyshouse.png |
| b131_route117_pokemondaycare | EM_ROUTE117 | 50,2,53,5 | 22.8 | 22.8 | 0,0 | sheets/b131_route117_pokemondaycare.png |
| b138_safarizone_resthouse | EM_SAFARI_ZONE_SOUTHWEST | 28,4,31,7 | 22.7 | 22.7 | 0,0 | sheets/b138_safarizone_resthouse.png |
| b135_route123_berrymastershouse | EM_ROUTE123 | 21,3,24,6 | 22.5 | 22.5 | 0,0 | sheets/b135_route123_berrymastershouse.png |
| x_route124_diverhouse | EM_ROUTE124 | 69,45,72,48 | 22.4 | 22.4 | 0,0 | sheets/x_route124_diverhouse.png |
| b013_slateportcity_nameratershouse | EM_SLATEPORT_CITY | 4,16,7,19 | 22.4 | 22.4 | 0,0 | sheets/b013_slateportcity_nameratershouse.png |
| x_route104_briney | EM_ROUTE104 | 15,47,19,50 | 22.2 | 22.2 | 0,0 | sheets/x_route104_briney.png |
| x_trainerhill_entrance | EM_ROUTE111 | 31,112,31,113 | 20.6 | 20.6 | 0,0 | sheets/x_trainerhill_entrance.png |
| b062_mossdeepcity_stevenshouse | EM_MOSSDEEP_CITY | 18,7,21,10 | 20.5 | 20.5 | 0,0 | sheets/b062_mossdeepcity_stevenshouse.png |
| center2 | EM_PETALBURG_CITY | 19,13,22,16 | 20.3 | 20.3 | 0,0 | sheets/center2.png |

## partly (45)

| name | map | rect | as shot % | residual % | shift dx,dy | sheet |
|---|---|---|---|---|---|---|
| b001_petalburgcity_house1 | EM_PETALBURG_CITY | 9,16,12,19 | 19.4 | 19.4 | 0,0 | sheets/b001_petalburgcity_house1.png |
| b133_route119_house | EM_ROUTE119 | 32,106,35,109 | 19.3 | 19.3 | 0,0 | sheets/b133_route119_house.png |
| b005_petalburgcity_house2 | EM_PETALBURG_CITY | 19,21,22,24 | 19.3 | 19.3 | 0,0 | sheets/b005_petalburgcity_house2.png |
| b016_slateportcity_house | EM_SLATEPORT_CITY | 20,41,29,44 | 19.1 | 19.1 | 0,0 | sheets/b016_slateportcity_house.png |
| b127_route113_glassworkshop | EM_ROUTE113 | 32,2,35,5 | 19.0 | 19.0 | 0,0 | sheets/b127_route113_glassworkshop.png |
| b106_verdanturftown_wandashouse | EM_VERDANTURF_TOWN | 8,11,12,14 | 18.4 | 18.4 | 0,0 | sheets/b106_verdanturftown_wandashouse.png |
| b102_fallarbortown_moverelearnershouse | EM_FALLARBOR_TOWN | 0,3,3,6 | 17.6 | 17.6 | 0,0 | sheets/b102_fallarbortown_moverelearnershouse.png |
| b083_oldaletown_house1 | EM_OLDALE_TOWN | 4,4,7,7 | 17.4 | 17.4 | 0,0 | sheets/b083_oldaletown_house1.png |
| b084_oldaletown_house2 | EM_OLDALE_TOWN | 14,13,17,16 | 17.4 | 17.4 | 0,0 | sheets/b084_oldaletown_house2.png |
| b064_mossdeepcity_spacecenter | EM_MOSSDEEP_CITY | 60,2,68,15 | 16.3 | 16.3 | 0,0 | sheets/b064_mossdeepcity_spacecenter.png |
| x_verdanturf_battletent | EM_VERDANTURF_TOWN | 1,3,5,7 | 16.2 | 16.2 | 0,0 | sheets/x_verdanturf_battletent.png |
| b107_verdanturftown_friendshipratershouse | EM_VERDANTURF_TOWN | 0,11,3,14 | 16.1 | 16.1 | 0,0 | sheets/b107_verdanturftown_friendshipratershouse.png |
| b053_lilycovecity_house3 | EM_LILYCOVE_CITY | 10,19,13,22 | 14.6 | 14.6 | 0,0 | sheets/b053_lilycovecity_house3.png |
| b108_verdanturftown_house | EM_VERDANTURF_TOWN | 16,12,19,15 | 14.6 | 14.6 | 0,0 | sheets/b108_verdanturftown_house.png |
| b147_battlefrontier_lounge7 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 4,17,6,20 | 14.5 | 14.5 | 0,0 | sheets/b147_battlefrontier_lounge7.png |
| b059_mossdeepcity_house2 | EM_MOSSDEEP_CITY | 66,22,69,25 | 14.2 | 14.2 | 0,0 | sheets/b059_mossdeepcity_house2.png |
| b050_lilycovecity_movedeletershouse | EM_LILYCOVE_CITY | 35,3,38,6 | 14.1 | 14.1 | 0,0 | sheets/b050_lilycovecity_movedeletershouse.png |
| b056_mossdeepcity_house1 | EM_MOSSDEEP_CITY | 27,6,30,9 | 14.0 | 14.0 | 0,0 | sheets/b056_mossdeepcity_house1.png |
| b061_mossdeepcity_house3 | EM_MOSSDEEP_CITY | 48,3,51,6 | 13.9 | 13.9 | 0,0 | sheets/b061_mossdeepcity_house3.png |
| x_slateport_shipyard | EM_SLATEPORT_CITY | 24,32,31,38 | 13.4 | 13.4 | 0,0 | sheets/x_slateport_shipyard.png |
| x_lilycove_house4 | EM_LILYCOVE_CITY | 11,11,14,14 | 13.1 | 13.1 | 0,0 | sheets/x_lilycove_house4.png |
| x_slateport_museum | EM_SLATEPORT_CITY | 28,22,33,26 | 13.0 | 13.0 | 0,0 | sheets/x_slateport_museum.png |
| x_route104_flowershop | EM_ROUTE104 | 3,15,8,18 | 12.9 | 12.9 | 0,0 | sheets/x_route104_flowershop.png |
| x_slateport_fanclub | EM_SLATEPORT_CITY | 2,22,6,26 | 12.9 | 12.9 | 0,0 | sheets/x_slateport_fanclub.png |
| b101_fallarbortown_cozmoshouse | EM_FALLARBOR_TOWN | 5,14,8,17 | 12.5 | 12.5 | 0,0 | sheets/b101_fallarbortown_cozmoshouse.png |
| b091_dewfordtown_house2 | EM_DEWFORD_TOWN | 7,5,10,8 | 12.3 | 12.3 | 0,0 | sheets/b091_dewfordtown_house2.png |
| b063_mossdeepcity_house4 | EM_MOSSDEEP_CITY | 17,13,20,16 | 12.3 | 12.3 | 0,0 | sheets/b063_mossdeepcity_house4.png |
| b092_lavaridgetown_herbshop | EM_LAVARIDGE_TOWN | 11,12,14,15 | 12.0 | 12.0 | 0,0 | sheets/b092_lavaridgetown_herbshop.png |
| b096_lavaridgetown_house | EM_LAVARIDGE_TOWN | 15,12,18,15 | 12.0 | 12.0 | 0,0 | sheets/b096_lavaridgetown_house.png |
| b049_lilycovecity_pokemontrainerfanclub | EM_LILYCOVE_CITY | 37,11,41,14 | 11.8 | 11.8 | 0,0 | sheets/b049_lilycovecity_pokemontrainerfanclub.png |
| x_dewford_house1 | EM_DEWFORD_TOWN | 16,11,19,14 | 11.8 | 11.8 | 0,0 | sheets/x_dewford_house1.png |
| x_frontier_pyramid | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 51,5,65,14 | 11.4 | 11.4 | 0,0 | sheets/x_frontier_pyramid.png |
| b139_route121_safarizoneentrance | EM_SAFARI_ZONE_SOUTH | 30,31,39,33 | 11.0 | 11.0 | 0,0 | sheets/b139_route121_safarizoneentrance.png |
| b087_dewfordtown_hall | EM_DEWFORD_TOWN | 1,0,5,3 | 10.9 | 10.9 | 0,0 | sheets/b087_dewfordtown_hall.png |
| b052_lilycovecity_house2 | EM_LILYCOVE_CITY | 54,12,57,15 | 10.0 | 10.0 | 0,0 | sheets/b052_lilycovecity_house2.png |
| b051_lilycovecity_house1 | EM_LILYCOVE_CITY | 41,3,44,6 | 9.5 | 9.5 | 0,0 | sheets/b051_lilycovecity_house1.png |
| mart2 | EM_SLATEPORT_CITY | 12,23,15,26 | 9.4 | 9.4 | 0,0 | sheets/mart2.png |
| x_mauville_eastblock | EM_MAUVILLE_CITY | 36,11,39,14 | 9.2 | 9.2 | 0,0 | sheets/x_mauville_eastblock.png |
| b031_rustborocity_cuttershouse | EM_RUSTBORO_CITY | 7,34,11,38 | 8.3 | 8.3 | 0,0 | sheets/b031_rustborocity_cuttershouse.png |
| x_frontier_dome | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 14,6,25,17 | 8.0 | 8.0 | 0,0 | sheets/x_frontier_dome.png |
| b055_lilycovecity_harbor | EM_LILYCOVE_CITY | 9,30,15,32 | 7.7 | 7.7 | 0,0 | sheets/b055_lilycovecity_harbor.png |
| b154_battlefrontier_rankinghall | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 32,8,38,12 | 7.7 | 7.7 | 0,0 | sheets/b154_battlefrontier_rankinghall.png |
| b045_lilycovecity_covelilymotel | EM_LILYCOVE_CITY | 36,20,41,24 | 7.6 | 7.6 | 0,0 | sheets/b045_lilycovecity_covelilymotel.png |
| abandoned_ship_wreck | EM_ROUTE108 | 27,3,33,5 | 52.2 | 7.3 | 0,2 | sheets/abandoned_ship_wreck.png |
| x_frontier_pike | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 40,19,44,29 | 7.3 | 7.3 | 0,0 | sheets/x_frontier_pike.png |

## near (13)

| name | map | rect | as shot % | residual % | shift dx,dy | sheet |
|---|---|---|---|---|---|---|
| b010_slateportcity_battletentlobby | EM_SLATEPORT_CITY | 8,8,12,12 | 4.8 | 4.8 | 0,0 | sheets/b010_slateportcity_battletentlobby.png |
| b134_route121_safarizoneentrance | EM_ROUTE121 | 35,3,39,5 | 4.4 | 4.4 | 0,0 | sheets/b134_route121_safarizoneentrance.png |
| x_frontier_exchange | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 7,25,13,28 | 4.2 | 4.2 | 0,0 | sheets/x_frontier_exchange.png |
| b118_route110_trickhouseentrance | EM_ROUTE110 | 9,61,13,66 | 3.9 | 3.9 | 0,0 | sheets/b118_route110_trickhouseentrance.png |
| x_frontier_factory | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 4,30,18,38 | 3.8 | 3.8 | 0,0 | sheets/x_frontier_factory.png |
| x_mauville_house1 | EM_MAUVILLE_CITY | 31,11,35,14 | 3.7 | 3.7 | 0,0 | sheets/x_mauville_house1.png |
| b023_mauvillecity_house2 | EM_MAUVILLE_CITY | 18,11,21,14 | 3.5 | 3.5 | 0,0 | sheets/b023_mauvillecity_house2.png |
| b028_rustborocity_pokemonschool | EM_RUSTBORO_CITY | 24,30,30,34 | 3.4 | 3.4 | 0,0 | sheets/b028_rustborocity_pokemonschool.png |
| b099_fallarbortown_battletentlobby | EM_FALLARBOR_TOWN | 6,3,10,7 | 2.9 | 2.9 | 0,0 | sheets/b099_fallarbortown_battletentlobby.png |
| b022_mauvillecity_gamecorner | EM_MAUVILLE_CITY | 5,11,11,13 | 2.8 | 2.8 | 0,0 | sheets/b022_mauvillecity_gamecorner.png |
| b017_mauvillecity_gym | EM_MAUVILLE_CITY | 5,1,10,5 | 2.7 | 2.7 | 0,0 | sheets/b017_mauvillecity_gym.png |
| b024_rustborocity_gym | EM_RUSTBORO_CITY | 24,15,29,19 | 2.3 | 2.3 | 0,0 | sheets/b024_rustborocity_gym.png |
| b089_dewfordtown_gym | EM_DEWFORD_TOWN | 5,13,10,17 | 2.2 | 2.2 | 0,0 | sheets/b089_dewfordtown_gym.png |

## match (35)

| name | map | rect | as shot % | residual % | shift dx,dy | sheet |
|---|---|---|---|---|---|---|
| b159_battlefrontier_lounge3 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 64,28,66,31 | 1.8 | 1.8 | 0,0 | sheets/b159_battlefrontier_lounge3.png |
| b019_mauvillecity_bikeshop | EM_MAUVILLE_CITY | 34,2,38,5 | 1.6 | 1.6 | 0,0 | sheets/b019_mauvillecity_bikeshop.png |
| x_cablecar_mtchimney | EM_MT_CHIMNEY | 14,32,19,36 | 1.6 | 1.6 | 0,0 | sheets/x_cablecar_mtchimney.png |
| b044_lilycovecity_departmentstore | EM_LILYCOVE_CITY | 23,0,31,6 | 1.3 | 1.3 | 0,0 | sheets/b044_lilycovecity_departmentstore.png |
| b158_battlefrontier_lounge6 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 4,6,6,8 | 1.3 | 1.3 | 0,0 | sheets/b158_battlefrontier_lounge6.png |
| x_cablecar_route112 | EM_ROUTE112 | 27,22,32,27 | 1.2 | 1.2 | 0,0 | sheets/x_cablecar_route112.png |
| b032_rustborocity_house2 | EM_RUSTBORO_CITY | 28,24,32,28 | 0.9 | 0.9 | 0,0 | sheets/b032_rustborocity_house2.png |
| b014_slateportcity_harbor | EM_SLATEPORT_CITY | 24,7,31,12 | 0.8 | 0.8 | 0,0 | sheets/b014_slateportcity_harbor.png |
| b057_mossdeepcity_gym | EM_MOSSDEEP_CITY | 35,5,40,9 | 0.8 | 0.8 | 0,0 | sheets/b057_mossdeepcity_gym.png |
| b003_petalburgcity_gym | EM_PETALBURG_CITY | 12,4,17,8 | 0.8 | 0.8 | 0,0 | sheets/b003_petalburgcity_gym.png |
| x_cyclingroad_north | EM_ROUTE110 | 14,12,19,16 | 0.7 | 0.7 | 0,0 | sheets/x_cyclingroad_north.png |
| frontier_gate | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 23,61,29,65 | 0.7 | 0.7 | 0,0 | sheets/frontier_gate.png |
| x_cyclingroad_south | EM_ROUTE110 | 15,84,20,88 | 0.6 | 0.6 | 0,0 | sheets/x_cyclingroad_south.png |
| x_frontier_arena | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 35,23,43,29 | 0.6 | 0.6 | 0,0 | sheets/x_frontier_arena.png |
| b048_lilycovecity_contestlobby | EM_LILYCOVE_CITY | 20,18,26,24 | 0.4 | 0.4 | 0,0 | sheets/b048_lilycovecity_contestlobby.png |
| b093_lavaridgetown_gym | EM_LAVARIDGE_TOWN | 2,11,7,15 | 0.4 | 0.4 | 0,0 | sheets/b093_lavaridgetown_gym.png |
| b152_battlefrontier_battlepalacelobby | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 40,51,50,56 | 0.2 | 0.2 | 0,0 | sheets/b152_battlefrontier_battlepalacelobby.png |
| b078_evergrandecity_pokemonleague | EM_EVER_GRANDE_CITY | 13,0,23,5 | 0.2 | 0.2 | 0,0 | sheets/b078_evergrandecity_pokemonleague.png |
| b157_battlefrontier_lounge5 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 21,48,26,51 | 0.2 | 0.2 | 0,0 | sheets/b157_battlefrontier_lounge5.png |
| b160_battlefrontier_lounge8 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 13,49,15,51 | 0.2 | 0.2 | 0,0 | sheets/b160_battlefrontier_lounge8.png |
| b068_sootopoliscity_gym | EM_SOOTOPOLIS_CITY | 28,29,33,32 | 0.1 | 0.1 | 0,0 | sheets/b068_sootopoliscity_gym.png |
| b145_battlefrontier_scottshouse | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 43,2,45,5 | 0.1 | 0.1 | 0,0 | sheets/b145_battlefrontier_scottshouse.png |
| x_route111_winstrate | EM_ROUTE111 | 11,109,15,113 | 0.1 | 0.1 | 0,0 | sheets/x_route111_winstrate.png |
| b143_battlefrontier_lounge2 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 44,41,49,44 | 0.0 | 0.0 | 0,0 | sheets/b143_battlefrontier_lounge2.png |
| x_route118_pinkhouse | EM_ROUTE118 | 0,14,3,17 | 0.0 | 0.0 | 0,0 | sheets/x_route118_pinkhouse.png |
| b025_rustborocity_flat1 | EM_RUSTBORO_CITY | 9,25,17,30 | 0.0 | 0.0 | 0,0 | sheets/b025_rustborocity_flat1.png |
| b030_rustborocity_house1 | EM_RUSTBORO_CITY | 31,15,35,19 | 0.0 | 0.0 | 0,0 | sheets/b030_rustborocity_house1.png |
| b033_rustborocity_flat2 | EM_RUSTBORO_CITY | 3,43,9,51 | 0.0 | 0.0 | 0,0 | sheets/b033_rustborocity_flat2.png |
| b034_rustborocity_house3 | EM_RUSTBORO_CITY | 24,42,29,46 | 0.0 | 0.0 | 0,0 | sheets/b034_rustborocity_house3.png |
| b037_fortreecity_gym | EM_FORTREE_CITY | 19,7,24,11 | 0.0 | 0.0 | 0,0 | sheets/b037_fortreecity_gym.png |
| b065_mossdeepcity_gamecorner | EM_MOSSDEEP_CITY | 35,21,39,24 | 0.0 | 0.0 | 0,0 | sheets/b065_mossdeepcity_gamecorner.png |
| b117_route109_seashorehouse | EM_ROUTE109 | 10,3,15,5 | 0.0 | 0.0 | 0,0 | sheets/b117_route109_seashorehouse.png |
| b146_battlefrontier_lounge4 | EM_BATTLE_FRONTIER_OUTSIDE_WEST | 52,42,54,44 | 0.0 | 0.0 | 0,0 | sheets/b146_battlefrontier_lounge4.png |
| b155_battlefrontier_lounge1 | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 3,42,5,44 | 0.0 | 0.0 | 0,0 | sheets/b155_battlefrontier_lounge1.png |
| x_frontier_tower | EM_BATTLE_FRONTIER_OUTSIDE_EAST | 11,0,21,14 | 0.0 | 0.0 | 0,0 | sheets/x_frontier_tower.png |

