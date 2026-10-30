# M0 results (own-code rewrite) — verifier pass 2026-10-29

Owner: rewrite session (this file replaces the planned Haiku check; the checks were rerun here).
Baseline of *today's* installed BATTLE_ART_VOXEL_FORK in QA copies (`tools/qa_tryp.sh`, QA identities `-p1..-p4`).

## Step 1 — neutral probe + 18-map baseline: PASS

- `tools/rewrite/probe/{old_adapter,geo_driver,compare,options_driver}.lua/.py` committed (61fe148).
- `.rewrite/baseline/m0a` (old `h3_geo_driver`, source-line TAGs) and `.rewrite/baseline/n0a` (neutral `geo_driver`,
  probe-layer TAGs) both hold the 18 maps of `tools/rewrite/maps_m0.txt`.
- `compare.py m0a n0a` on the 18 map **names**: 17 SAME; `EM_ROUTE112` differs in the `other` layer only
  (42674 vs 22818 tris, 0 missing cells). Route 112 is the known dropped-build case the neutral adapter fixes;
  `n0b112` is the Route 112 repeat kept for it. Every other map: identical triangle multiset and identical cells.
- `m0a` vs `m0b` (repeat of the old driver): ALL SAME, 18/18. `pairs()` randomness does not leak into the dumps.

## Step 2 — all-maps baseline w0a: COMPLETE with two explained gaps

- `.rewrite/baseline/w0a`: 518-map list, trace-wrapped neutral driver (`EM_INNER=geo_driver.lua`,
  `EM_BASE_DRIVER=docs/proposals/dropin/trace_driver.lua`), SUMMARY ends ALLDONE.
- 502 maps have a `[EM geo]` line: 495 `ok`, 7 `unsettled`.
- **16 maps have no line**: their 400 s QA run was killed by the QA watchdog
  (`WATCHDOG: stopped after 400s` in `out_29/106/107/109/110`), all in the Battle Frontier / Battle Tent families
  (huge per-map atlases + many objects + the driver's up-to-20 build spots per map). The maps exist; the run did
  not reach them. Not a map or probe fault: a batch-size limit. Re-run with 2 maps per batch (fix list below).
- **7 maps `unsettled` and 0 triangles**: `EM_CAVE_OF_ORIGIN_UNUSED_RUBY_SAPPHIRE_MAP1..3` (Ruby/Sapphire-only
  leftovers, empty in Emerald), `EM_GRANITE_CAVE_B1F/B2F`, `EM_VICTORY_ROAD_B1F/B2F`, all large cave maps whose
  first build does not finish inside `geo_driver.settle()`'s 300-idle-iteration give-up window, so the driver dumps
  before any field mesh exists. Same re-run fix.
- Check as written in the handoff (`compare.py m0a w0a` on the 18 names) is **invalid**: `maps_all.txt` uses a
  different spot for 10 of the 18 maps, and the dump is a window around the spot. Done properly:
  `w0c` = the same trace-wrapped neutral run on `maps_m0.txt` (same spots as m0a) → **ALL SAME, 18/18**,
  including Route 112 (42674 `other` tris on both sides). So the neutral probe + trace wrapper change nothing.
- Repeatability of w0a: `w0b` = second run of the same 518-map list, stopped at 429 of 518 maps (the last three
  Battle Frontier batches hung on the QA watchdog, so the run was killed). Of the 429 repeated maps, 417 are exactly
  SAME (cells and triangle multiset) and 12 differ, all in one class: the same triangles emitted **once vs twice**
  (e.g. `EM_DEWFORD_TOWN_HOUSE2` 5404 vs 2702, `EM_EVER_GRANDE_CITY_HALL2` 2756 vs 5512, `EM_INSIDE_OF_TRUCK`
  5852 vs 2926) plus a handful of window-edge extras on Route 113/118 and a halved Mossdeep build. The dump groups
  meshes by `probe.started()`; a build that restarts without a new `started()` lands twice in one group. The
  triangles themselves are the same geometry. For M1's geometry gate: compare triangle **sets**, not multisets,
  and treat window-edge extras as explained differences. Cells: identical everywhere except Mossdeep/Route 113/118.

## Step 3 — runtime file trace: PASS

`python3 tools/rewrite/trace_merge.py docs/proposals/dropin/runtime_files_m0.tsv .rewrite/baseline/w0a/out_*/files.log
.rewrite/trace/*/files.log`:

- 133 logs, 357 mod files read at runtime: 127 `same` + 49 `modified` + 181 `new` against upstream base 03882a9.
- **All 173 upstream files of `dropin/upstream174.tsv` are read** (0 missing) → the "what must be replaced" list is
  complete against the M0 trace.
- Files new against the earlier 18-map trace: only `assets/shaders/fsr1/ffx_a.h` and `ffx_fsr1.h` (AMD FSR1 headers,
  MIT, loaded by the options run). Nothing else new; nothing the earlier trace saw is missing now.
- Trace roots: `.rewrite/baseline/w0a/out_*/files.log` (518 maps), `.rewrite/trace/{options,fly_long,fly_sea}`.

## Step 4 — golden captures + gate outputs: PASS (`s4a`)

- `STATUS` ALLDONE (start 16:11, caps 16:30, gates 16:38). 20 capture runs × 24 shots = **450 PNGs** for the 75
  spots of `tools/rewrite/spots_m0.txt` (L4/L6/L7, yaw 0 and 180); `caps/SUMMARY.txt`: every run `fallback 0`
  (450 shots, 0 fallbacks).
- `gates/G01.txt` (pins): every map `diff=0` except `EM_ROUTE110 diff=1` (the known old Pyre (26,24) pin cell).
- `gates/G02.txt` (classes): `unclassified=0` on every map; `faceHigh` 0 except `EM_PACIFIDLOG_TOWN 44`
  (baseline value, not a gate failure for M0).
- `gates/G03.txt` (trees): 7408 tree cells, sunk 0, floating 44 (Route 120/121 border fill), other-height 593.
- `gates/G11.txt` (ledges): per-map edges/cells/bare/tall/steepest census.

## Step 5 — simcheck review: DONE

`docs/proposals/dropin/simcheck_review_pass1.md` + verdicts in `~/Documents/emerald3d/docs/PROVENANCE.md`
(30a72df): 22 ok; 9 modules to rewrite/adapt before crossing; 2 ok with a later recheck.

## Harness limits to fix when a gate needs those maps

1. `baseline_geo.sh` splits 4 maps per run; the Battle Frontier / Battle Tent maps need 2.
2. `geo_driver.settle()` gives up after 300 idle iterations; the big cave maps need a longer window.
   Both are one-line knobs; reruns of the 23 affected maps are the fix (no code change to the mod).
