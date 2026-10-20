# Autoloop: finish the 3D world by Saturday 2026-10-24

Started 2026-10-20 at the user's request: "I want it working now, and the entire map done by the weekend."
This file is the operating manual. Every automatic round of the goal re-reads it before acting. Status lives
in `.autoloop/state.json` and the queue in `docs/ledger/faults.json`.

## Scope and finish line
- **Scope:** every outdoor map (`docs/ledger/outdoor_spots.txt`, 53) and every cave (`cave_spots.txt`, 105).
  Interiors only if the outdoor queue is empty (they are Tier 2 in practice).
- **Done** = the Tier 1 bar of [DONE.md](DONE.md) over the whole scope, measured on the release-candidate tree:
  0 fallbacks / 0 Lua errors, 0 magenta, stairs and ledge audits 0, every detector below at 0 or each hit
  listed with a reason, every Tier 1 fault fixed or parked with evidence, and a release-candidate report.
  The user's yes is the last gate; only the user sets ✅ and only the user installs into the real game.

## Where things are
| What | Path |
|---|---|
| Release-candidate tree (git repo, the ONLY place the loop edits Lua) | `.autoloop/rc/lib` (in this repo's folder, git-ignored) |
| Loop work data (ROM-derived: dumps, shots; never in git) | `.autoloop/{geo,runs,shots}` (git-ignored) |
| Loop scripts (in this repo) | `tools/autoloop/` |
| Fault queue | `docs/ledger/faults.json` (`tools/tour_note.sh` format; loop rows have `source: autoloop`) |

The rc tree starts as a copy of the **real installed lib** (the only authoritative state). Branch `upstream`
mirrors the real install; `main` = upstream + accepted fixes, one commit per fix. `tools/autoloop/rc.sh sync`
pulls newer installs (other sessions keep installing) into `upstream` and merges them into `main`.
QA runs use the rc tree through `QA_SRC` and name **every** file that differs from the main QA copy
(`tools/autoloop/rc.sh files`), because the main QA copy is stale (9 files differ from the real game).

## Hard rules
1. Never edit `~/Documents/battle-art-notquiteog` (other sessions work there) or the real game folder.
   Never `git stash` in the mod tree. Never touch the main QA copy; private copies through `qa_tryp.sh` only.
2. Gates decide, not the fixer's opinion. A fix is kept only if `tools/autoloop/gate.sh` passes AND an
   independent verifier (a fresh subagent shown full-resolution crops, asked to find a regression) does not refute it.
3. If a fix regresses elsewhere, revert it; do not tune it. At most 2 attempts per fault, then park it with evidence.
4. Scanners stay strict: never recalibrate a detector to make a fault disappear.
5. The user's taste (skill `emerald-terrain` section 1): original pixels 1:1, never stretch; more depth is welcome;
   soft rock but rounding at most ~3 px; no "wonky, melted, striped, chunky, floating, double ledge".
   Taste calls (shape style, restyles) are not decided by the loop: make an A/B sheet and park as `needs-user`.
6. Check heights before changing a builder: most floating/pit/double-ledge faults are heights.
7. One fault class per fix commit. The commit message says what was seen, why, and what it is now.

## Detectors (`tools/autoloop/detect.py`, offline on geometry dumps)
Geometry comes from `tools/autoloop/em_geo_driver.lua`: one boot per batch of maps, waits for the full build,
writes every terrain triangle (world space, px) and the cell dump. A detector is trusted only after it flags the
known positives and stays quiet on the known negatives listed with it.
- **D1 float:** a connected piece of geometry whose underside sits above the surface beneath it with air between.
  Known positives: Route 112 19,42; Route 103 24,14. Known fixed: Mossdeep 45,7 (commit 1b0efaa).
- **D2 hanging plate:** an upward surface edge with a drop beneath it and no side face closing it (sky seen through).
  Known positive: Route 112 west margin, cells 0..17 x 31..45.
- **D3 mini-stairs:** walkable ground stepping by a small height again and again in one direction where the art
  draws no stair. Known positives: Route 115 22,71-73 (F002); Route 104 north of Rustboro (F003).
- **D4 ledge lip:** a jump ledge whose lip height varies along its run, or whose ends are open. Known: F001, F004.
Plus the existing gates: fallbacks, magenta probe, stairs audit, ledge-drop check (`tools/release_check.sh`).

## One round of the loop
1. **Preflight.** Stop (and say why in state.json) if: disk < 5 GB, 3 QA batches failed in a row, the round budget is spent.
   A game the user is playing is fine; the QA slot cap (4) is enforced by `qa_tryp.sh`.
2. **Sync.** `tools/autoloop/rc.sh sync`. A merge conflict parks the loop's conflicting fix, it does not edit upstream.
3. **Discover** if the last world sweep is older than the rc tree's last fix: geo sweep + detectors, write new
   candidate faults (dedupe by map, class, cell box).
4. **Pick** the top open fault: Tier 1 first, then detector-backed, then fewest attempts.
5. **Diagnose** (map, cell, original art via `crop2d.py`, heights via `dump=`), decide the class, fix in a branch of rc.
6. **Gate:** `tools/autoloop/gate.sh <fault>`: the fault's detector hit is gone; no new detector hits on the regression
   set; cell dumps identical outside the fault's box (`heights_compare.py`); 0 fallbacks; build not slower;
   before/after captures at levels 4, 6, 7 (two yaws).
7. **Verify:** a fresh subagent gets the before/after crops (nearest-neighbour, full resolution) and the rubric; it must
   name any regression it sees. Refuted = revert.
8. **Keep or revert.** Keep: merge to rc `main`, save the sheet, mark the fault `fixed` with evidence. Revert: delete
   the branch, `attempts += 1`; at 2, `parked` with the evidence.
9. **Record:** ledger (`tools/ledger.py --write`), commit docs/tools in this repo, push main.

## Engine track (runs beside the loop; user, 2026-10-20: "why not both?")
Goal: our own voxelization engine, reached in steps that each pay off on their own and meet the loop at one
contract: **the geometry dump format** (`.geo.gz` + `.cells`, see `em_geo_driver.lua`) and the detectors.
- **E1 headless builder** (worktree `~/Documents/Emerald-engine`, branch `engine-headless`, folder `engine/`):
  the mod's real builder (rc tree, read-only) runs under LuaJIT outside the game with stand-ins for meshes,
  tile pixels, map loading and options. Accepted when its dumps equal the in-game dumps (same triangles) on
  Route 103, Oldale and Rustboro. Then the loop switches its discovery and gates to headless dumps
  (no game boot, 8 at once, JIT on); in-game captures stay for the final look.
- **E2 own engine pieces** (after E1): a whole-world height solve across connected maps first (most floating,
  pit and double-ledge faults are heights), then mesh generation, each piece written to the same dump format and
  accepted only when the detectors and a capture comparison say it matches or beats the rc builder on every map.
  Players' copies must generate the world themselves (the output derives from ROM art), so engine code stays
  pure Lua that can also run inside the mod and cache its result.
- **Combine:** the loop's fixes in rc are the reference the engine must match; engine pieces enter rc one at a
  time through the same gate as any fix.
The engine track is worked by a background subagent; it never edits rc, the mod source or any game folder.

## Schedule
- Tue 20 evening: rc tree, geometry driver, D1/D2 calibrated; loop starts on the floating rocks.
- Wed 21: world geometry sweep and candidates; D3/D4; screenshot discovery (waypoints, `shot_filter.py`, vision triage
  of flagged frames only) as a workflow.
- Wed-Fri: fix loop through the queue.
- Fri 23 night: full `release_check.sh` on rc; `docs/RELEASE-CANDIDATE-2026-10-24.md` (gate table, every fix with sheet
  and one-line revert, parked faults, what needs the user's eyes); `tools/autoloop/install_rc.sh` (backup + rollback).
- Sat 24: the user reviews and decides what to install.

## Status log (newest last; each round appends one line or a short block)
- 2026-10-20 18:10 Set up: main fast-forwarded (Gemini tools in, 4 test suites pass); rc tree `.autoloop/rc` = real install
  (main QA copy is stale in 9-11 files, so every QA run names `rc.sh files`); geometry driver works (Route 103 22 s,
  Route 112 28 s, Mossdeep 26 s, Route 115 21 s, Oldale 14 s, Rustboro 14 s; dumps in `.autoloop/geo`). Engine E1 subagent
  started in worktree `~/Documents/Emerald-engine`.
- D1 air, first calibration (kinds under+civic+water, gap >= 3 px, area >= 8 px2), NOT trusted yet:
  hits Route 112 west margin (9,39 tile 0x203 gap 59; 13,33 and 17,31 tile 0x271/0x21A) and the 19,42 float region
  (box 12..29 x 40..43); misses Route 103 24,14 (cells 24,13-14 tiles 0x164/0x16C 'cliff' beside water: check whether a
  lone-stone mesh drawn outside the 'under' batch, e.g. Gen3RockSprites, carries it); flags near Mossdeep 45,7 (box 45..48 x
  3..6, gap 110) although commit 1b0efaa fixed 45,7: look at it. False-positive families to remove: plates at y <= 0 over a
  surface 7 px below (underground skirts reached through holes; 28 on Route 112), and large hill/forest regions
  (Route 112 1,7 area 33780; Route 103 40,1). Next: orbit captures (level 7, 2 yaws) of the top regions per map, classify
  true/false by eye at full resolution, refine the rule (not the thresholds), repeat until known positives hit and false
  positives are rare; then the world sweep.
- 2026-10-20 19:00 Round 1. D1 refined: kinds under+civic+water; surfaces at or below their cell's floor dropped
  (underground skirts); analysis 6 cells past the map edge (the boundary fill is seen from the map). Visually confirmed
  true positives: Route 103 46..61 x 0..6 (rock face with a hollow you see into, inside faces showing: "melted"),
  Route 112 -6..-3 x 42 (boundary fill draws a house roof, tiles 0x030-0x033, its plates at 58-68 px over ground dropped to
  0: the striped plate floating in the sky west of Route 112), Route 112 11..26 x 21..26 (thin green plates hanging beside
  the red rock walls; the back wall also shows grass texture striped down vertical rock: separate class). Not judgeable:
  Route 115 30,38 level 7 (orbit camera inside the hill). F007 Route 103 24,14: geometry rock from y=0 on ground 0 and the
  level-4 shot shows a pillar standing on the grass: looks fixed already, waiting for the yaw 3.9 shot before closing.
  D3 mini-stairs (`detect.py steps`): small floor steps between walkable cells that have a vertical face on the cell edge
  (a ramp drawn as a slope is not counted: Oldale 8,22-25 is sloped). Top hit on Route 115 = F002 box 19..24 x 70..73.
  Tools: `region_cases.py` (detector regions -> capture cases), `shots.sh` (indexed captures on rc).
  Next: yaw 3.9 shots (cal1/shotsA_y39, shotsB_y39) for F005/F007 and the rest; then gate.sh; then world sweep.
- 2026-10-20 18:20 Gate built (`gate.sh` + `gate_eval.py`; self-test on an unchanged tree says "not fixed", 0 new, 0 cells).
  Fixers are subagents, one fault each, own worktree `.autoloop/wt/<F>` (brief: `docs/autoloop/FIXER-BRIEF.md`).
  Running: F030 (Route 112 roof plate in the west boundary) and F031 (Route 103 hollow rock), both pinned to base 01aee72.
  Closed with evidence: F005 (Mossdeep 45,7, fixed by 1b0efaa), F007 (Route 103 24,14, not reproducible; the 4 px came
  from the untrusted Gen3Rock audit). New: F030-F032 tier 1, F033 tier 2 (translucent green panels, Mossdeep, like F009).
  rc synced to the real install (e6a02ab: other sessions installed the Route 104 ridge and Route 115 terraces). World
  geometry sweep of e6a02ab started (`sweep.sh`, 158 maps, 2 games at a time). Ledge/R115 stair faults F001/F002/F004:
  other sessions are active on Gen3Outdoor and Route 115 today; take them only after checking their handoffs.
- 2026-10-20 18:30 F006 diagnosed from the cells: the rock cells flanking the Route 112 stair flight at x 20-21 (19,42-43 and
  22,42-43) took the treads' floors (28.8, 19.2) while their neighbours are at 0/48, so they float; fixer F006 started (base
  e6a02ab). `install_rc.sh` written (dry run / --yes / --rollback; installs only rc's loop commits into game, QA and mod
  source with backup; refuses on stale rc, running game, or a file someone else changed). D4 (ledges) deferred while another
  session works on Gen3Outdoor. Next round: collect fixer reports (F030, F031, F006) -> verifier subagent on each PASS ->
  rebase onto rc main and re-gate -> merge; triage the world sweep (top regions per map -> captures -> vision check).
- 2026-10-20 18:55 Tool corrections from fixer/engine findings: (1) driver pins rng + tileset animation BEFORE the boot
  (dumps depended on boot timing); (2) the boot map (Littleroot) is re-entered via another map (dumped empty before);
  (3) each spot owns only cells 6+ inside its build window (spot seams dropped closing walls: the big Route 103 46..61 and
  Route 112 0..24 regions were dump artifacts; F031's VISIBLE teeth/streaks are real and being fixed); (4) dump-edge
  regions tagged 'edge', ignored by the gate. Old caches moved to .autoloop/old/. F030 fixer: the striped plate in b022 is a
  CANOPY mesh (new fault F035); its box is Lavaridge's Poke Mart roof row whose ground plane sits at 0 under a cell at 32
  (fixing: building-claimed cliff cells take their ground at the cell's base). Engine E1: headless == in-game on Oldale,
  Rustboro, Route 103 (1.5-4 s CPU/map). Sweep restarted (sweep2.log).
- 2026-10-20 19:15 Round 2: gate gets a REVIEW verdict (class fixes change cells elsewhere on purpose: those areas get
  before/after captures for the verifier instead of failing); `docs/autoloop/VERIFIER-BRIEF.md`; D1b `detect.py void`
  (canopy over no surface; does not catch F035, whose crowns stand 27 px over ground like normal walk-under crowns: needs
  a trunk check); F036 logged (Route 112 22,10 door flips cliff/flat between identical builds). F006 fixer: flank heights
  come from TerrainLevels' support BFS using flight cells as donors; fix in TerrainLevels + flightTreads closes sides,
  gate running. Sweep of e6a02ab running slowly (QA slots shared with three fixers' gates).
- 2026-10-20 20:00 Round 3/4 (after the three fixers died mid-work; their branches kept). The headless builder replaced the
  in-game dump everywhere: whole scope (158 maps) in 9m47s wall at 6 jobs, and the gate now builds base and fix TWICE each
  headless and ignores builder noise (`gate_eval --base2/--fix2`: a region counts only if both fix builds have it and no
  base build; a cell change only if both fix builds differ from both base builds). Three fixes were gated:
  * F006 (Route 112 stair flanks): base 9 air regions at the box (max 1308 px2, gap 47) -> 3 slivers of 8-12 px2; cells
    changed on Mossdeep 8 / Route 111 4 / Route 115 19 (class effect, REVIEW), 1 new 48 px2 region on Route 115; 0
    fallbacks. Verifier running on sheet.png + sheet_review.png.
  * F030 (Route 112 west boundary): the 66 px plate is gone; a 3320 px2 region at gap 34 remains in [-6,40,-1,42]; new
    fixer F030b started on top of fix/F030.
  * F031 (Route 103 teeth/streaks in Gen3Rock): gate running. Reminder from its work: the earlier big Route 103 "hollow"
    region was a dump seam (fixed in the driver), the visible fault is art streaking + zigzag course cuts.
  Calibration of the world sweep: D1 air does NOT apply to caves (Gen3 draws no cave ceiling, so the sky flood reaches
  every cave interior: 9101 cave regions vs 3059 outdoor). The outdoor queue at the user's taste bound (gap >= 4 px, area
  >= 200 px2; rounding up to 3 px is wanted) is 369 regions -> 147 clusters (`tools/autoloop/triage.py`, ranked by
  area x gap). Top clusters are the hollow-cliff class (Route 115 21..42 x 26..60 area 69916 gap 83; Route 114;
  Southern Island; Battle Frontier East/West; Mt Pyre summit; Route 119): the same class F031 is fixing, so re-sweep after
  F031 lands and expect the queue to shrink. F003 (Route 104 mini-stairs) cannot be located: D3 finds no mini-stairs
  anywhere on Route 104 at any step limit; it needs the user's screenshot.
- 2026-10-20 21:10 TWO FIXES MERGED INTO rc main:
  * e3011de F006 Route 112 stair flanks (verifier KEEP: the two enclosed-sky holes of 120 and 270 px2 in the orbit frame
    are gone, no regression in 10 review frames; air at the box 2716 -> 28 px2).
  * 1d04b0e F031 soft-rock E/W art 1:1 + straight course cuts (gate PASS, zero cell changes; verifier KEEP: crest teeth and
    the smeared bands gone, no new sky pixel, silhouette unchanged).
  Detector lessons: (1) a dump's mesh tags are file:line numbers, so they must be resolved against the source of the tree
  that produced the dump (`detect.py --lib <that tree>/lib`) - with rc main's newer source the tags resolved to nothing
  (0 triangles); sweep.sh and gate.sh pass the right lib, ad-hoc runs must too. (2) Both "aperture" tests (erode the open
  air to demand a >4 px opening; require lower open ground beside the plate) were tried and rejected: they removed the
  verified real holes as well, because a visible hole is often a slit a few px wide behind a lip. The air rule stays a
  HINT that ranks candidates; judging needs captures (next: capture-triage of the top clusters).
  Fixer F030b (Route 112 west boundary remainder) and F032 (green plates beside the red rock) are running; rc re-sweep on
  the fixed tree started to measure the class effect.
- 2026-10-20 20:50 After the two fixes, rc main re-swept headless in 106 s (158 maps, 0 unsettled). Detector before/after:
  outdoor air regions 3059 -> 2201 (gap>=4 & area>=200: 269 -> 251), total flagged area 1.10M -> 0.98M px2; steps unchanged
  (121). The two fixes cure their own classes; the bulk of the remaining air regions is the terraced-mountain inside (cliff,
  158 regions, 0.83M px2) which the captures showed to be correct in game. Queue ranking changed accordingly: object-like
  cells (flat/awning/roof/tree/ledge/sign/water) first, big cliff masses last (triage.py). New pipeline: discover.sh
  (captures the top N clusters at levels 4 and 7 + index.json) and discover judges (a subagent that opens the full frames
  and decides REAL / FALSE / UNCLEAR with a pixel box; brief in the prompt, taste from the terrain skill).
  First discovery batch: 9 object-like cases (Mt Chimney flat x30, Battle Frontier roof, Route 109 flat, Slateport awnings,
  Fortree trees, Rustboro roof, Route 123/ Ever Grande water, Safari wall) - 0 fallbacks (my earlier "2 fallbacks" was
  discover.sh grepping its own summary line; fixed). F030b and F032 fixers still running.
- 2026-10-21 00:10 Discovery judging by workflow (22 cases, one agent per case, each cropping full-size frames): 1 REAL, 5 FALSE,
  8 UNCLEAR. The UNCLEARs were my bug: shots.sh numbers frames b001.. INSIDE each batch dir, and my index assumed one global
  numbering, so 8 judges were sent to frames that do not exist (they found the right frames from run.log and reported it -
  good). discover.sh now indexes per batch; disc-main/index.json reindexed.
  REAL: F039 - the margin water plate north of Route 123 (cells 104..114 x -3..-1, base 48) hangs over open air with a
  40-60 px sky band between its lip and the lake (judge's pixel box 640,70,990,190 in batch02/b001.png).
  FALSE (recorded so the queue does not chase them again): Route 109's beach top layer (no visible underside), Slateport's
  market awnings (cloth on four posts - the detector does not skip 'awning' cells), Fortree's big-tree crowns (trunk
  visible under each), Rustboro's glass tower roof (enclosed shell, roof mesh excluded by design), Route 110's cycling road
  deck (designed bridge clearance with legs in the water). Lesson for the detector: skip awning/bridge cells and tree
  crowns as sources; the remaining false positives are enclosed shells, which need the captures to judge.
- 2026-10-21 22:30 FIRST FULL TIER 1 RUN on the candidate (rc main, 158 maps, all gates, 50 min):
  sweep PASS (632 shots, 0 fallbacks, 0 Lua errors, 0 watchdogs); stairs+ledges PASS (113 stairs ok, 0 flat, 0 reversed,
  0 cliff jumps, 0 of 401 ledges bad); defects PASS (122 bakes, 0 flagged); floats PASS (4471 masses, 0 floats);
  magenta FAIL by count (207 of 632 level-7 frames have magenta in the lower 45%, 15 with a lot) - the gate had never been
  run on the whole world before, so this may be pre-existing: a baseline run of the same gate on the installed tree
  (upstream e6a02ab) is going now (.autoloop/runs/baseline-magenta.log) to compare; repeat FAIL (1 unstable cell between two
  runs = the builder pairs() noise F037; 100 cells differ from the F025 baseline, drift from other sessions' installs plus
  F006's intended cell changes); load FAIL but on a polluted machine (load_avg 23.6, median 434 ms, 9 timeouts -> rerun
  quiet).
  Faults: 8 open tier 1 (F001, F002, F004 ledges/stairs; F003 unlocatable; F032 green plates; F035 canopy plate; F038 roof
  row at base 0; F039 Route 123 margin water plate), 1 parked (F030), 6 fixed (F005, F006, F007, F025, F029, F031).
  Next: F039 fixer started; F032/F035/F038 are the same plate family; ledges need a dedicated fixer or the other session's
  work; magenta needs the baseline answer before anyone chases it.
