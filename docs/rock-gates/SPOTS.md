# Rock gates: fixed spots per class (frozen 2026-10-18)

Spots are the vetted A/B spots from `tools/relief/ab.py` CASES (walkable cell 1-2 rows south of
the rock). Each spot is shot at level 4 (player camera) and level 7 (low orbit), `QA_ZOOM=-2`,
daytime, NPCs hidden, ONE spot per qa_run call (several far spots in one run render from the first
spot's scene). A class is CLOSED when the user signs its sheet in `docs/rock-gates/<class>/`.

| Class | Spots (map, x, y) |
|---|---|
| PINK (General mountain) | EM_ROUTE111 32,128 / 7,63 / 22,102 |
| BEIGE (General rock, recoloured) | EM_ROUTE114 7,50 / 26,58 (only two vetted; a third to be added) |
| BROWN (Fallarbor terrace) | EM_ROUTE114 20,10 / 8,13 ; EM_FALLARBOR_TOWN 12,6 |
| RED (Lavaridge rock) | EM_ROUTE112 11,26 / 24,44 ; EM_MT_CHIMNEY 30,29 |

Rules a sheet is judged by (from the user): taller than the original, rugged but smooth ("not a
bouncy castle"), face art repeats rows and is never stretched, no fins/pillars/stripes, no holes.

Stop rule: max 3 fix rounds per class; a closed class reopens only on a regression in its own
shots; no survey of other maps unless the diff touches their code.
