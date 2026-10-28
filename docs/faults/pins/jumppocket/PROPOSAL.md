# Jump-ledge pocket census and rule proposal (task 34 B item 3c, builder 14, 2026-10-28)

Census: `tools/elevation/qa/em_jumppocket_driver.lua` on all 64 pinned maps, installed game lib (read-only).
Raw lines: `census_raw_2026-10-28.txt` (one AREA line per floor area that touches a jump ledge; 21 maps have one).
An area = 4-connected walkable floor of one zone (unmarked = zone 0). IN = a ledge lands in it (the floor you jump
from is across the ledge), OUT = you jump out of it, WALK = walkable contact with another area, STAIR = a flight beside it.

## 1. The candidate rule "pocket = upper minus one course" does not fit the user's own marks
Marked areas you land in by jumping (57), drop from the highest takeoff floor to the drawn height:

| drop (courses) | -1 | -0.5 | 0 | 0.5 | 1 | 1.5 | 2 |
|---|---|---|---|---|---|---|---|
| areas | 2 | 2 | 35 | 8 | 6 | 2 | 2 |

Most jump ledges sit inside one flat plateau (the user drew the same number on both sides). Areas reached ONLY by
jumping (no walk, no stair), where the floors in and out differ:

| pocket | drawn | in / out | upper-1 | midpoint |
|---|---|---|---|---|
| Jagged (16,24) | 2.5 | 3 / 2 | 2 no | 2.5 yes |
| Lilycove (47,18) | 1.5 | 2 / 1 | 1 no | 1.5 yes |
| Jagged (13,15) | 4.5 | 5 (also 6) / 4 | 4 or 5 no | 4.5 yes |
| Jagged (14,10) | 5.5 | 7 / 6 | 6 no | 6.5 no |

## 2. Proposed rule (not built)
For an unmarked floor area whose only ways in and out are jump ledges:
- **R-a, flat plain:** every floor across its ledges stands at one height H -> the area takes H (the ledge is a lip in
  one plateau, like the 35 marked cases). Chains of unmarked areas linked by ledges are solved together.
- **R-b, between two heights:** the area takes the midpoint of the highest floor jumped from and the lowest floor jumped
  to, snapped to a half course (8 px). Fits 3 of the 4 drawn pockets above.

## 3. What it would change (21 unmarked areas)
| map | area at | cells | now (px) | in / out | rule gives | note |
|---|---|---|---|---|---|---|
| Route 123 | (44,1) (67,1) (43,14) | 92, 82, 54 | 8 | 0..16 / 0 | 0 (R-a chain) | plain the user circled 0; now 8 px LEDGE_DROP risers stacking |
| Route 123 | (49,4) (57,14) | 44, 65 | 16 | chain / chain | 0 (R-a chain) | same plain |
| Route 123 | (56,6) | 35 | 24 | 0 / chain | 0 (R-a chain) | same plain, 1.5 courses over 0 today |
| Route 113 | (69,2) | 37 | 8 | 0 / 0 | 0 (R-a) | ash field, everything round it 0 |
| Lilycove | (48,10) | 6 | 32 | 48 / 32 | 40 (R-b) | |
| Safari South | (28,7) | 5 | 0 | 16 / 0 | 8 (R-b) | |
| Route 112 | (11,46) | 14 | 24 | 48 (and 32) / 16 | 32 or 24 | two takeoff heights: keep 24 |
| Jagged | (14,27) | 5 | 32 | 40 / 32 | 36 -> no half course | keep 32 |
| Jagged | (8,23) | 10 | 16..48 mixed | 48 / 16 | 32 | mixed heights inside one area: pin question |
| Jagged | (8,27) | 4 | 16 | 48+16 / 16 | ? | pin question |
| Safari NE | (7,16) (5,16) | 8, 2 | 32..48 mixed | 48 / 32 | 40 | mixed: pin question |
| Route 112 | (16,44) | 9 | 0..16 mixed | 16 / 0 | 8 | mixed: pin question |
| Frontier E (28,7), Route 113 (16,8), Route 116 (17,6), Route 118 (21,0) (76,7) | | 1-3 | already equal | | no change | ledge ends |

Biggest effect: Route 123's north plain (about 370 cells) would drop from 8/16/24 px steps to flat 0. Sheet of the
present state: `SHEET_now_L4_L7.png` (Route 123 (58,8), Route 113 (70,3), Lilycove (49,11), L4 + L7; gitignored).

## 4. Items (a) and (b): no build needed
Route 114 (6,5) and Jagged Pass (19,9) are blocked FACE cells (Route 114 (6,5) height 0 between plateaus 3 and 5;
Jagged (19,9) 96 under the 112 plateau). The L6/L7 camera put there stands where the player never can, under or inside
the ramp, which is the "eye under a slab with sky below". From walkable cells on both sides (Route 114 (7,5) and (4,5) at
yaw 90/270; Jagged (19,10) and (19,8) at yaw 0/180) both bands close with no sky.
