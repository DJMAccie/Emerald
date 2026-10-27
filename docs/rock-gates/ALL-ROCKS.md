# ALL-ROCKS: census of every outdoor rock (2026-10-25, task 27)
> REVIEWED 2026-10-27 (task 30): the per-map verdicts below are the pre-fix census; the signed, current ledger is docs/rock-gates/REVIEW-2026-10-26.md.

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


## Class B round 3 (2026-10-26): INSTALLED (Gen3Rock + Gen3Mass + Gen3Hills from tools/searock/p6a; backup ~/Documents/gen1recomp-modwork/backups/sea-rock-r3-20261026)
User 2026-10-25/26: "the rocks still look scattered and not a cohesive unit like in the original pixel art, edges/corners too sharp, slightly rounded". Cause: Gen3Rock builds one flat-topped block per cell (rounding 3 px). Fix: the sea-route rock (Routes 124/127/128/131-134, masses of 6+ cells and thin sea islands) is built by Gen3Hills, the continuous rolling-surface builder (params ALL, HMAX 32, RISE .5, LIP 4, SEA: sea masses too, MASK: patches the rock silhouette calls ground/sea stay at the floor); lone boulders stay domes. Rejected: p6b (same blocks, 10 px rounding): too little change.
Gates: census 59 maps vs game1: 6 cells differ, all Route 131 (a sea island dome->rock flag); geometry gate (Routes 111-114 control vs probe, two control runs for noise): 111 identical, 112/114/113 within control-vs-control noise (26 / ~250 flat triangles, 2 Route 113 ledge wall triangles); float gate 39 maps: 1 float = 1 float (Route 124 [EM float] count 169 -> 171, noise class); 37-spot sheets at yaw 0/90 earlier (classB_round3), 0 fallbacks; installed-game smoke equals probe (<=0.16% px).
Known: Route 131 (36,7) cave mouth stands as a dark post (door face); Route 124 thin islands read low (RISE .5). Rounds used 3 of 3 for class B: next = class C (Plan Mode first).


## Class C (2026-10-26): INSTALLED for Jagged Pass + Sootopolis; Frontier left as is (tools/classc, probes pj1/pj2/pf1-3/ps1/ps2/pc1; sheets docs/rock-gates/classC/)
- **Jagged Pass** (597 old-rock cells): moved onto the counted red method: `Gen3RockTables.RED_MAPS` + `Gen3Relief.MAPS` + `Gen3Relief.CLAMP_UP_MAP=16` (one course; 32 stood tall spiky wall stacks, rejected), relief baked with tools/relief/bake_lua.py and spliced into Gen3ReliefData.lua (data file, not in git). Census: only the 598 Jagged cells change builder (rock -> relief), every other map identical; 0 fallbacks, L4/L6/L7 x yaw 0/90 at 3-6 spots; behind-view cleaner (no crumpled spire at (14,22)).
- **Sootopolis**: the white rim is a blocked decor ground (elevation 0, no game height), so it stays a flat plane; the real defect was the pink rim edges standing as tall fins/spires (13,48), (6,52). `Gen3Rock.MAXH_MAP[EM_SOOTOPOLIS_CITY]=32` (two courses); the class-B flank rules added nothing. One number to retune.
- **Battle Frontier E/W**: the sea walls and hedges already read like the 2D. Tried (A) Gen3Rock course builder with MAXH 32 + FLANKRUN + RIDGE (walls turn into comb teeth, worse) and (B) Gen3Mass.TALL cap 32/16 (East walls lower, West blocks become zigzag fins, spire at East (63,53) stays): NOT installed. Open: East (63,53) two spires on a thin strip (needs a Gen3Mass look at why a thin ridge climbs), West striped Battle Factory building (13,38)/(28,33) = BUILDING streaks, not rock (bake task). Rounds used 2 of 3.
- Installed 2026-10-26 via tools/classc/install_c1.sh (backup ~/Documents/gen1recomp-modwork/backups/classc-jagged-20261026; source = game = QA).

## Class C: Sootopolis (2026-10-26, session "Sootopolis only"; Jagged Pass and Battle Frontier E/W are the other class C session's)
Finding: the white crater ground south-west/south-east of the lake (cells 0,40..44,59: 246 cells, tiles 0x2D9 floor + hatch strokes 0x2D1/2D2/2DA/2DC/2D0) is ONE bank mass (Gen3Objects.bank: "crater walls painted with a few repeated tiles"), built by Gen3Mass's column dome builder: a flat 16 px slab, hatch strokes read as grey sunken pits and little posts. Gen3Rock.handles refuses every `mass.bank`, so Gen3Hills never saw it. The north terraces (0x2E1/2DA/2D8... 'mass=false' cliff cells, brick walls) are NOT banks and stay as they are.
Fix (probe tools/classc/ps1, 2 files): `Gen3Hills.bankOk` + `PARAMS.EM_SOOTOPOLIS_CITY={ALL,HMAX=36,RISE=.5,LIP=4,BANK=true}` + MAPS entry; ONE hunk in Gen3Rock.handles (`mass.bank` allowed where Hills.bankOk). The crater rim becomes one rolling hill (hatch strokes = folds), the pink shore cliffs ride the same builder. Other maps cannot change: both switches need the Sootopolis PARAMS.
Gates: geometry dump (tools/classc/geo_gate.sh s1; control + probe + probe2): Route 111 0/408,016 ground triangles differ, Route 124 0, Route 112 24 flat (probe vs probe2 noise 32), Sootopolis probe == probe2 (0), only Sootopolis changes (30,774 out / 50,089 in). Float gate (tools/classc/float_gate.sh): control = probe on Sootopolis 55, Route 112 69, Route 124 171. Captures 0 fallbacks, yaw 0/90/180 at (10,44) (50,44) (13,48) plus (6,54) (50,54) (30,30) (10,25) (50,20) (45,45).
Sheets: .autoloop/runs/soot_n0/sh.png, soot_n90/sh.png, soot_n180/sh.png (old | new), full 2D map soot_n0/map2d.png. Sent to the user.
Known: a few small standing posts remain on the slope (hatch cells that are separate 'cliff' cells); round 2 would level those. Install: tools/classc/install_c2.sh (REFUSES while a game runs; applies the Gen3Rock hunk to the CURRENT file, backup ~/Documents/gen1recomp-modwork/backups/classc-sootopolis-20261026); INSTALLED 2026-10-26 (user: game closed, install; source = game = QA, patch 204 files, smoke from the game lib at (10,44) (50,44) (30,30): 0 fallbacks, equals the probe frames). Rounds used 1 of 3.
