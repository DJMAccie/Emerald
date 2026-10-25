# ALL-ROCKS: census of every outdoor rock (2026-10-25, task 27)

Source: per-cell builder census of the INSTALLED game build (tools/relief/stage3/allrocks, game1/), 59 outdoor maps with rock cells, 110 capture spots (docs/rock-gates/general-rollout/allrocks1). One sheet per map: docs/rock-gates/ALL-ROCKS/maps/<MAP>.png, columns = 2D original | 3D level 4 | level 6 | level 7.
Builders: relief = Gen3Relief counted heights (the new method); rock = Gen3Rock course-built (the OLD rock); dome = Gen3Mass dome (stones, boulders, Frontier/Sootopolis tiles); sea = sea boulders (not part of this pass).
Verdict is MY eye on the sheet, the user decides: ok / ok? / suspect / wrong / not eyeballed. Caves are not in this table (task 28, after the outdoor pass).

Classes: A = ridge/course builder shape (pillars, slits); B = old sea/shoal rock still on Gen3Rock (Routes 121-134, Lilycove); C = tilesets with no tables (Battle Frontier, Sootopolis, Jagged Pass); D = open ghost cards / small leftovers (Safari, Route 111/112, Lavaridge, Sky Pillar top).

| map | cells | relief | rock | dome | sea | tile classes | verdict | class | note | spots |
|---|---|---|---|---|---|---|---|---|---|---|
| EM_ROUTE126 | 1704 | 0 | 503 | 1119 | 82 | S:f7f4:1121 GEN:488 GENo:95 | suspect | B | faceted dome slab on the big island (43,58 L6); thin fins elsewhere | 43,58 5,54 12,14 |
| EM_ROUTE127 | 1400 | 0 | 902 | 47 | 451 | GEN:982 GENo:378 S:f7f4:40 | suspect | B | tall thin spires and ridge fins (53,54 L6/L7), 2D is low flat pink | 52,25 53,54 7,73 |
| EM_BATTLE_FRONTIER_OUTSIDE_EAST | 983 | 0 | 0 | 863 | 120 | GEN:829 GENo:152 S:f86c:2 | wrong | C | rock tiles are building/hedge art: Tower draws as one dome; sea-edge walls fine | 38,40 16,60 63,53 |
| EM_ROUTE124 | 842 | 0 | 528 | 33 | 281 | GEN:569 GENo:240 S:f7f4:33 | suspect | B | islands read as pyramids/spires; 2D is rounded low rock | 72,44 50,21 50,16 |
| EM_SOOTOPOLIS_CITY | 751 | 0 | 234 | 517 | 0 | S:f83c:564 GEN:184 GENo:3 | wrong | C | crater wall is one flat white plane (13,48 L4); needs its own tables | 13,48 |
| EM_BATTLE_FRONTIER_OUTSIDE_WEST | 648 | 0 | 0 | 648 | 0 | GEN:646 GENo:2 | wrong | C | striped building (13,38) is a flat dome; walls at sea edge fine | 11,63 13,38 28,33 |
| EM_JAGGED_PASS | 601 | 0 | 597 | 4 | 0 | RED:601 | suspect | C | old red terraces, plausible; never moved to the red counted method | 14,38 |
| EM_ROUTE133 | 554 | 0 | 215 | 4 | 335 | GENo:478 GEN:76 | wrong | B | crater at (36,17) is a streaked triangle fan, not stepped rock; spikes (43,29) | 12,12 36,17 43,29 |
| EM_ROUTE128 | 555 | 36 | 409 | 20 | 90 | GEN:348 GENo:199 S:f7f4:8 | not eyeballed | B | 36 relief cells, 409 old rock | 55,3 64,34 25,9 |
| EM_SAFARI_ZONE_NORTHEAST | 491 | 0 | 419 | 2 | 70 | GEN:447 GENo:42 S:f7dc:2 | ok? | D | low brown ledges, plausible | 19,34 |
| EM_ROUTE131 | 480 | 0 | 309 | 11 | 160 | GEN:348 GENo:132 | wrong | B | huge faceted dome slab (5,10 L6), flat terraced slab (9,31), spikes | 5,10 36,7 9,31 |
| EM_ROUTE105 | 439 | 0 | 40 | 27 | 372 | GENo:361 GEN:76 S:f74c:2 | not eyeballed | - |  | 32,44 32,45 33,24 |
| EM_ROUTE112 | 1277 | 842 | 427 | 8 | 0 | RED:878 GEN:380 GENo:19 | suspect | D | open cards G3 (30,22) and G6 (19,35); red walls ok | 35,45 24,52 18,44 |
| EM_LILYCOVE_CITY | 432 | 0 | 393 | 7 | 32 | GEN:346 GENo:45 S:f7dc:41 | ok? | B | old rock, ledges plausible, small lump rocks | 42,37 66,3 45,33 |
| EM_ROUTE132 | 414 | 0 | 192 | 28 | 194 | GENo:228 GEN:186 | not eyeballed | B | same builder | 72,10 9,16 45,32 |
| EM_SAFARI_ZONE_NORTH | 412 | 0 | 387 | 25 | 0 | GEN:384 GENo:25 S:f7dc:3 | ok? | D | low ledges, plausible | 16,36 |
| EM_ROUTE134 | 406 | 0 | 96 | 18 | 292 | GENo:369 GEN:37 | not eyeballed | B | same builder as 131/133 | 62,16 67,8 30,14 |
| EM_MOSSDEEP_CITY | 758 | 390 | 292 | 18 | 58 | GEN:662 GENo:91 S:f7f4:5 | not eyeballed | - |  | 18,26 15,37 |
| EM_ROUTE130 | 318 | 0 | 5 | 6 | 307 | GENo:165 GEN:153 | not eyeballed | B | same builder, almost all sea boulders | 68,13 |
| EM_ROUTE121 | 304 | 0 | 260 | 0 | 44 | GEN:228 GENo:61 S:f7dc:15 | ok? | B | old rock, cliff steps plausible | 18,14 51,14 43,12 |
| EM_ROUTE119 | 843 | 544 | 244 | 55 | 0 | GEN:762 S:f7c4:45 GENo:36 | not eyeballed | - |  | 32,95 33,91 30,98 |
| EM_SAFARI_ZONE_NORTHWEST | 288 | 0 | 272 | 16 | 0 | GEN:239 GENo:44 S:f7dc:5 | suspect | D | lone boulder drawn as a faceted dome (21,15 L6) | 21,15 13,37 |
| EM_ROUTE129 | 274 | 0 | 101 | 23 | 150 | GEN:164 GENo:106 S:f7f4:4 | not eyeballed | B | same builder | 57,11 33,29 |
| EM_ROUTE111 | 2702 | 2447 | 208 | 47 | 0 | GEN:2467 GENo:139 S:f77c:96 | suspect | D | open cards H1 (15,14), H2 (16,38) | 29,96 18,97 |
| EM_SOUTHERN_ISLAND_EXTERIOR | 246 | 0 | 246 | 0 | 0 | GEN:246 | ok? | A | terraced island reads like the 2D; left on old rock on purpose, keep unless the user objects | 15,20 21,16 |
| EM_ROUTE122 | 789 | 551 | 0 | 4 | 234 | GEN:503 GENo:286 | not eyeballed | - |  | 22,31 |
| EM_SKY_PILLAR_OUTSIDE | 269 | 33 | 225 | 5 | 6 | GEN:201 S:f824:48 GENo:20 | suspect | A | two floors done; west ridge pillars, L6 looks into a dark wall (camera in rock) | 15,21 |
| EM_ROUTE120 | 444 | 220 | 194 | 30 | 0 | GEN:342 S:f7c4:93 GENo:9 | not eyeballed | - |  | 13,15 24,15 7,56 |
| EM_SKY_PILLAR_TOP | 220 | 0 | 0 | 220 | 0 | S:f824:220 | ok? | D | walls of the top floor, plain slab | 8,17 21,15 |
| EM_ROUTE118 | 416 | 225 | 149 | 6 | 36 | GEN:372 GENo:44 | not eyeballed | - |  | 31,7 |
| EM_SAFARI_ZONE_SOUTHEAST | 184 | 0 | 167 | 0 | 17 | GEN:106 S:f7dc:55 GENo:23 | not eyeballed | D |  | 6,31 12,32 30,19 |
| EM_MT_PYRE_SUMMIT | 1041 | 874 | 167 | 0 | 0 | GEN:1041 | ok | - | counted relief, ridges read right | 37,35 20,34 |
| EM_ROUTE125 | 648 | 482 | 27 | 24 | 115 | GEN:491 GENo:152 S:f7f4:5 | not eyeballed | - |  | 8,20 |
| EM_ROUTE108 | 132 | 0 | 52 | 8 | 72 | GENo:132 | not eyeballed | - |  | 26,5 3,2 10,3 |
| EM_ROUTE106 | 264 | 139 | 0 | 1 | 124 | GEN:139 GENo:124 S:f74c:1 | not eyeballed | - |  | 57,18 |
| EM_ROUTE109 | 120 | 0 | 0 | 3 | 117 | GENo:105 GEN:15 | not eyeballed | - |  | 37,25 |
| EM_ROUTE110 | 148 | 36 | 42 | 0 | 70 | GENo:75 GEN:73 | not eyeballed | - |  | 3,67 |
| EM_LAVARIDGE_TOWN | 111 | 0 | 110 | 1 | 0 | RED:111 | not eyeballed | D | capped at 32 (task 23) | 8,18 |
| EM_SAFARI_ZONE_SOUTH | 111 | 0 | 102 | 9 | 0 | GEN:53 S:f7dc:45 GENo:13 | not eyeballed | D |  | 21,7 10,10 31,11 |
| EM_ROUTE104 | 89 | 0 | 53 | 3 | 33 | GEN:66 GENo:21 S:f734:2 | not eyeballed | - |  | 5,55 22,71 |
| EM_ROUTE115 | 1207 | 1120 | 20 | 2 | 65 | BROWN:1053 GEN:88 GENo:66 | ok? (counted relief) | - |  | 25,49 26,16 21,19 |
| EM_ROUTE123 | 128 | 53 | 36 | 19 | 20 | GEN:86 GENo:42 | not eyeballed | - |  | 79,2 |
| EM_ROUTE113 | 660 | 586 | 62 | 12 | 0 | GEN:417 BROWN:217 GENo:26 | not eyeballed | - |  | 12,6 |
| EM_VERDANTURF_TOWN | 104 | 30 | 72 | 2 | 0 | GEN:98 GENo:5 S:f77c:1 | not eyeballed | - |  | 19,2 |
| EM_ROUTE107 | 69 | 0 | 4 | 3 | 62 | GENo:39 GEN:30 | not eyeballed | - |  | 31,16 |
| EM_EVER_GRANDE_CITY | 1751 | 1709 | 12 | 2 | 28 | GEN:1684 GENo:66 S:f80c:1 | ok? (counted relief) | - |  | 18,55 24,54 |
| EM_PACIFIDLOG_TOWN | 474 | 433 | 0 | 0 | 41 | GEN:425 GENo:49 | ok? (counted relief) | - |  | 11,14 |
| EM_SAFARI_ZONE_SOUTHWEST | 114 | 74 | 33 | 7 | 0 | GEN:95 GENo:15 S:f7dc:4 | not eyeballed | D |  | 0,5 9,4 |
| EM_MT_CHIMNEY | 1170 | 1138 | 16 | 16 | 0 | RED:1170 | ok? (counted relief) | - |  | 16,42 16,37 |
| EM_ROUTE103 | 240 | 209 | 19 | 6 | 6 | GEN:222 GENo:18 | not eyeballed | - |  | 21,8 |
| EM_ROUTE116 | 886 | 855 | 29 | 2 | 0 | GEN:844 GENo:39 S:f734:3 | ok? (counted relief) | - |  | 52,16 |
| EM_ROUTE117 | 30 | 0 | 28 | 2 | 0 | GEN:29 S:f77c:1 | not eyeballed | - |  | 34,6 |
| EM_DEWFORD_TOWN | 25 | 0 | 0 | 3 | 22 | GENo:15 GEN:10 | not eyeballed | - |  | 18,16 |
| EM_FORTREE_CITY | 24 | 0 | 0 | 24 | 0 | S:f7c4:24 | not eyeballed | - |  | 31,3 |
| EM_ROUTE114 | 1639 | 1616 | 12 | 11 | 0 | BROWN:1639 | ok? (counted relief) | - |  | 13,67 13,44 19,16 |
| EM_FALLARBOR_TOWN | 98 | 80 | 14 | 4 | 0 | BROWN:98 | not eyeballed | - |  | 16,1 |
| EM_MAUVILLE_CITY | 5 | 0 | 5 | 0 | 0 | GEN:4 S:f77c:1 | not eyeballed | - |  |  |
| EM_SLATEPORT_CITY | 2 | 0 | 0 | 0 | 2 | GENo:2 | not eyeballed | - |  |  |
| EM_MT_PYRE_EXTERIOR | 1413 | 1413 | 0 | 0 | 0 | GEN:1404 GENo:8 S:f9bc:1 | ok? (counted relief) | - |  | 13,45 |
| TOTAL | 33147 | 16135 | 8929 | 3975 | 4108 | |


## Class B round 1 (2026-10-25): INSTALLED (patch regenerated; backup ~/Documents/gen1recomp-modwork/backups/sea-rock-20261025)
Files: lib/Gen3Rock.lua (M.FLANKRUN: on Routes 105/109/121/124/126-134 and Lilycove a lone face cell is a diagonal flank, not a tier front: no +1 course, so the lone spires and cube rows are gone), lib/Gen3Mass.lua (a sea blob one row tall and >=3 cells wide is the drawn rim of a rock, not a boulder: no dome; this removed the big streaked discs on Route 133 (36,17)/(43,29), and the same bogus discs on Sky Pillar Outside and Mossdeep).
Gates: census of all 59 rock maps on the probe: builder/relief/sea flag of 33,147 cells identical to the installed game; rim rule fired on Routes 124/126/127/130/131/132/133, Sky Pillar Outside, Mossdeep, Pacifidlog; installed-game smoke equals the probe (only the NPC pose differs). tests/gen3_relief_test.lua is ALREADY broken in the source tree (Gen3Rock.tileArt reads ts.midToSlot of a stub tileset, same error with the control files): not caused by this change.
Sheets (OLD | NEW, L4 and L7): docs/rock-gates/ALL-ROCKS/classB_p3/<MAP>.png.
Still open in class B: tall 4-5 course stacks (Route 124 (55,8..14) column of 0x167 faces reaches 80 px; Route 127 north spire; Route 128 (55,3)/(64,34), Route 134 pillars), the thin curved plank left where the rim row was, gable tops on the Route 131 plateau, brown ribbon lines on the water (Route 131), Route 126's big-island dome, Pacifidlog's huge flat slab (counted relief, south).


## Class B round 2 (2026-10-25): PROBE tools/searock/p5 (Gen3Rock + Gen3Mass), NOT YET INSTALLED (the user's game was running; run tools/searock/install_b2.sh with the game closed)
Findings: (1) Route 131 "ribbon lines" were NOT walls: Gen3Mass.ground gave the whole sea mass the shore tile 0x393 (rim line) as its water, and Gen3Rock's silhouette treated that tile's brown rim pixels as "ground", so rim cells were carved to nothing and their floor drew the rim line on the sea. Fix: on class-B maps the sea under a mass is the plainest open water of the scene (Gen3Mass.ground); the plateau now keeps its brown pixels and reads as terraces. (2) gables = single-cell lid towers one course over both lid neighbours: levelled (Gen3Rock.prepare). (3) tall stacks: face cell on the same face tile no longer climbs (M.FLANKSTACK), M.MAXH_MAP 48 on 124/126/127/128/131-134, and thin sea ridges (members/maxdim < 4) stand ONE body, a course per cell in from the rim up to M.RIDGE_H=32 (Route 127 spine is 16, Route 124 island no longer 80). User 2026-10-25: Route 127 (7,73)/(53,54) had "rogue rock heights, not like the original": this is the fix; check from several yaws.
Gates: census of all 59 maps vs game1: 0 flag diffs (p4e1, the rules since then change heights only); 37 spots x yaw 0 and 90, L4/L6/L7, 0 fallbacks; sheets classB_p5 (yaw 0) and classB_p5_yaw90. Still open: Route 127 capsule sea masses are straight 32 px slabs (2D = rounded humps), Route 126 dome, Pacifidlog slab. Rounds used 2 of 3.
