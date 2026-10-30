# Gates (G-nn)

The checks that prove a rule holds. Format: `### G-nn Title`, `Checks:`, `Command:`, `Reads:` (the output lines), `Target:`,
`Rules:` (R-ids it proves). `tools/knowledge/run_gates.sh <label>` runs G-01, G-02, G-03 and G-05 in one go and writes a
scorecard row; G-04, G-06 and G-07 are run per change and judged by the session; G-08 is the release sweep.

### G-01 Field gate: every mark exact
Checks: the floor field height of every pinned cell equals the user's mark x 16 px on every pinned map.
Command: `bash tools/elevation/qa/pins_gate.sh <label>` (3 QA copies, ~10 min) -> /tmp/<label>/pins_*.txt; single map: `EM_DRIVER=tools/elevation/qa/em_pins_driver.lua EM_MAPS=<file> EM_DUMP=<out> bash tools/qa_tryp.sh "Gen3Elevation.lua Gen3PinData.lua Gen3Blocks.lua Gen3Scene.lua" <outdir> - 4 0 60`
Reads: `COUNT <map> ok= diff=` per map, `PIN ... DIFF` lines for the misses, `GRID` rows (height in half courses, base 36, saturates at 35).
Target: diff = 0 on every map (1597 marks on 64 maps as of 2026-10-27; the one known DIFF is Mt Pyre's connector cell).
Rules: R-01, R-07, R-10, R-11, R-12, R-13

### G-02 Class table: nothing unclassified, no face above its plateaus, every mass flat
Checks: per pinned map the counts of PLATEAU / FACE / MASS / WATER / DECK / OTHER cells, unclassified rock cells, faces higher than their upper plateau (faceHigh), masses whose top is not flat (massNotFlat), plus the fix-up counts (otherFix, pocketFix, treeFix, rockFar).
Command: `bash tools/elevation/qa/blocks_gate.sh <label>` -> /tmp/<label>/cls_*.txt
Reads: `CLS <map> PLATEAU= FACE= MASS= WATER= DECK= OTHER= rock= unclassified= faceHigh= massNotFlat= ...`, `FACEHIGH`/`MASSDIFF` lines per cell, `CLSGRID` rows.
Target: unclassified = 0 and massNotFlat = 0 on every map; faceHigh falling (269 -> 50 at round 1b) with every remaining one explained.
Rules: R-01, R-02, R-03, R-05

### G-03 Tree gate: trees stand on their plateau
Checks: for every tree cluster on the wooded maps, tree cells whose scene base lies below every rim cell (sunk) or above every rim cell (floating), and cells at a different height than the rim's most common ground.
Command: dump the wooded maps with `tools/em_cells_driver.lua` (EM_MAPS = the list in `tools/knowledge/tree_maps.txt`, EM_DUMP_WAIT=300), then `python3 tools/elevation/learn/tree_gate.py <dumps>`
Reads: one line per map and `ALL tree cells N sunk S floating F other-height O`.
Target: sunk 0; floating only where explained (7,408 tree cells on 9 maps; 158/221 -> 3/7 by 2026-10-27).
Rules: R-15

### G-04 Control diff: unpinned maps and untouched cells unchanged
Checks: cell-by-cell diff of two field dumps (before / after a change); every changed cell must be explained by the change.
Command: `python3 tools/elevation/qa/grid_diff.py /tmp/<labelA> /tmp/<labelB>`; for repeatability of the same code: `tools/heights_compare.py flips`.
Reads: `MAP n_changed (x,y a->b ...)` and a total.
Target: 0 changed cells outside the maps and classes the change names (Route 118 (4,14)/(5,13) always flip, ignore).
Rules: R-21, R-27

### G-05 Fallbacks and Lua errors
Checks: no capture spot fell back to the flat 2D map and no Lua error during a run.
Command: every qa_run.sh / qa_tryp.sh summary; `grep -c fallback run.log`.
Reads: `shots N  fallback M` per QA copy.
Target: fallback 0; a run with unexpected fallbacks in old AND new is void (rerun before judging).
Rules: R-23, R-26, R-27

### G-06 Ortho-45 placement overlay
Checks: the 3D rendered from the 2D's own angle (45 degrees, raw texels) beside the original map art, so WHERE the dark bands and tops sit is visible; diff.py gives a percent of differing pixels per rectangle as a fault finder.
Command: `EM_DRIVER=tools/em_ortho_driver.lua ...` capture, then `python3 tools/ortho45/diff.py <MAP> <x> <y> <shot.png> <outdir> [--rect x0,y0,x1,y1]`
Reads: cmp.png strips (docs/faults/pins/ORTHO_*.png on disk), the summary percent line.
Target: dark bands and tops where the 2D draws them on one map per tileset (Mt Pyre (20,20), Route 112 (20,30), Route 115 (13,32)); the percent is not a target (R-09).
Rules: R-03, R-04, R-09, R-22, R-28

### G-07 Old|new sheets judged against the 2D art
Checks: before/after captures at the play camera (L4, zoom -2) and the low camera (L6), one spot per tileset family, plus one close low-camera shot of a single face, judged by the session against the 2D crop.
Command: `bash tools/elevation/qa/cap_pins.sh <label> ...` + `python3 tools/elevation/qa/ab_sheet2.py ...` (sheets under docs/faults/pins/<label>/, on disk only).
Reads: the sheets; the run summaries for fallbacks (G-05).
Target: the session's written judgement per spot in the PLAN.md Log line; no spot left "unsure" without a probe (R-29).
Rules: R-06, R-08, R-13, R-18, R-19, R-20, R-21, R-22, R-23, R-25, R-29

### G-08 Tier 1 release checks
Checks: fallbacks, magenta holes, stairs audit, ledges, floating props, build time, building defect scan over every outdoor map and cave (docs/DONE.md).
Command: `tools/release_check.sh [--out DIR] [--maps FILE] [--gates ...]`, then `tools/ledger.py --audit-from results.json --write`.
Reads: results.json; docs/LEDGER.md audit table.
Target: the targets in docs/DONE.md Tier 1.
Rules: R-32

### G-09 Knowledge lint
Checks: ids unique and sequential in rules/lessons/gates, every rule names an existing gate or `none yet`, every lesson names existing rules, every gate names existing rules, journal lines dated; warns when PLAN.md Tasks still say "waits for the user" (R-24).
Command: `python3 tools/knowledge/check.py` (run by learn.py and run_gates.sh).
Reads: docs/knowledge/*.md, .claude/handoffs/PLAN.md.
Target: 0 errors; warnings listed.
Rules: R-24, R-30, R-31

### G-10 Base equals ground
Checks: for a few cells of a changed map, the drawn ground (c.base) equals what the actors stand on (Scene.groundAt).
Command: `EM_DRIVER=tools/elevation/qa/em_cell_info.lua` with the cells, or a scratch driver printing both.
Reads: the per-cell lines.
Target: equal on every cell checked.
Rules: R-16, R-17

### G-11 Hidden-ledge census
Checks: every plateau edge over a lower plain cell with no band tile has a wedge (LEDGE cells) or a face-art riser (BARE); no grass riser is left; tall edges counted
Command: QA_SRC=<src> EM_DRIVER=tools/elevation/qa/em_ledge_driver.lua EM_MAPS=<maps_all.txt> EM_DUMP=<out> bash tools/qa_tryp.sh "Gen3Elevation.lua Gen3PinData.lua Gen3Blocks.lua Gen3Scene.lua TerrainLevels.lua" <outdir> - 4 0 60
Reads: LEDGE lines per map, TOTAL line
Target: edges + bare cover every bare drop of the 2026-10-28 census (class A2 111 edges); old|new at Safari North (16,15) yaw 180 shows a rock slope, no green wall
Rules: R-35

### G-12 Rewrite parity with the installed look
Checks: Old mod vs EMERALD_3D at the same spot, same camera: per-cell dump (base, height, class, flags) diff, geometry triangle set diff with each difference explained, and L4/L6/L7 captures side by side. No visible difference.
Command: EM_DRIVER=tools/rewrite/probe/geo_driver.lua ... (QA old vs QA new, clean_try.sh); tools/rewrite/probe/compare.py old new; old|new capture sheets
Reads: .cells/.geo.gz per map, capture PNGs, the old|new sheet
Target: cells diff 0 on the 18 M0 maps; every geometry difference explained; captures indistinguishable except the listed intended differences (Petya's explicit yes per item); fallback 0
Rules: R-36
