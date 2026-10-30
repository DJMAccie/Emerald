# Method brief: fix a CLASS of faults from evidence, not one fault at a time

Written 2026-10-21 by the Sonnet 5.5 session that did the rock-height rollout (PLAN.md task 10). The user judged its output
("exactly what I was looking for") and asked for the method to be written down so the DeepSeek harness agent can use it.
This file is self-contained: you do not need the chat. Read it top to bottom once, then work through section 3 as a
checklist. It is long on purpose; every step says what to do, why, the exact command, when it is done and when to stop.

## 0. The method in twelve lines
1. Start from the plan files and notes, never re-explore the repo. Work on one task at a time.
2. Turn the user's feeling ("rocks still look wrong") into a CLASS and a NUMBER: how many cells, on which maps, drawn by which code path.
3. Look at two or three full-resolution frames to see what the class looks like, and at one frame the user already signed to see what "right" is.
4. Ask: is there already a signed method that fixes this class on some maps? If yes, the fix is usually DATA plus an opt-in list, not new builder code.
5. Test the idea cheaply and read-only before building: dry-run the solver on the candidate maps, count cells.
6. Write a short plan, get the user's OK, then build only in a scratch copy of the INSTALLED lib (the "probe tree").
7. Measure what actually happens with a purpose-built driver (a census), instead of looking at pictures and guessing.
8. Compare OLD and NEW at fixed spots and fixed camera levels in one sheet next to the original 2D art. Judge at full resolution.
9. When a frame is wrong, find the cause in NUMBERS (per-cell heights, histograms), change one thing, rerun only the affected spots, keep every round as a column in the sheet.
10. Gate with byte-for-byte comparisons: what must not change must be identical, not "looks the same".
11. Install per batch with a backup and a one-line revert; the unit of revert is one map.
12. Write the handoff into PLAN.md and a memory note before the context gets large. No per-fault queue; subagents only when they pay for themselves (section 7).

## 1. Why this beats the per-fault loop (facts from the repo, not opinion)
The autoloop (docs/AUTOLOOP.md) discovers faults with detectors and judge agents, then gives each fault to a fixer agent in its own
worktree, then to a verifier agent. Its own records, 2026-10-21:
- `docs/ledger/faults.json`: 43 faults, **10 fixed, 31 open, 2 parked**. Each gate run takes about 10-15 minutes
  (docs/autoloop/FIXER-BRIEF.md), each fault needs a fixer plus a verifier plus judge passes. The user reports about 52 subagents spent.
- Several fixed faults were closed without a code change ("not reproducible") or were determinism fixes, not visible quality.
- `docs/RELEASE-CANDIDATE-2026-10-24.md` lists the biggest class, "the inside of terraced mountains", as detector false positives, and shows F032
  and F039 rejected on attempt 1. The loop never asked "which tiles are drawn by which code, and how many cells is that".
- The rock-height problem the user kept feeling was never a fault. It was a COVERAGE GAP: the signed counted relief (Gen3Relief) was opt-in for
  7 maps while 48% of rock cells (13,261 of 27,489 in the F025 dump) sat on 30+ other maps drawn by the old rule-based rock. No detector
  can flag "this whole map uses the old method"; a census by tile id and builder can, in one afternoon, with no agents.

What to keep from the loop: the headless builder, `heights_compare.py`-style byte comparisons, detectors as FAULT FINDERS (never as the goal),
the user's taste rules. What to change: the unit of work is the class (cells affected, ranked), discovery is a census, there is one lead agent
with one linear plan (a subagent only where it clearly saves effort or cost, section 7), and the verifier is a numeric gate plus a sheet the user can read in 10 seconds.

## 2. Orientation: where things are (read this before touching anything)
- Repo `~/Documents/Emerald` (tools, docs, patches). Mod source `~/Documents/battle-art-notquiteog/lib` (other sessions edit it: do not write there).
- The INSTALLED game mod: `~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK/lib` = what the user plays. It is the truth.
  The shared QA copy `.../pokemon-love2d-rseqa/...` is STALE (it lacked newer Gen3Cave/Gen3Hills/Gen3Mass). The source tree can hold other
  sessions' unfinished files. So: base every probe on a copy of the INSTALLED lib. Check with
  `diff -rq <installed lib> <qa lib>` and `diff -rq <source lib> <installed lib>` before you trust any capture.
- Rock builders, claim order **Relief > Hills > Rock** (`Gen3Rock.handles`, docs/HEIGHT-PATH.md): `Gen3Relief.lua` (counted terraces, data in
  `Gen3ReliefData.lua`), `Gen3Hills.lua`, `Gen3Rock.lua`, `Gen3Mass.lua` (domes). A change belongs to exactly one of them; find who claimed the mass first.
- Counted relief tool chain (offline python, `tools/relief/`): `terraces.py` (solver, port of Emerald 3DS terrace counting), `bake_lua.py` (writes
  `Gen3ReliefData.lua`), `emdata.py` (map loader), `proof.py`, `render.py`. `Gen3ReliefData.lua` is ROM-derived: it is NOT in git.
- Plans and memory: `.claude/handoffs/PLAN.md` (one linear plan; read `[NOW]` and its Handoff section), memory files under
  `~/.claude/projects/-Users-user-Documents-Emerald/memory/` (index MEMORY.md; `emerald-relief-rollout.md` is this task).
- Game runs: `tools/qa_tryp.sh` (private QA copy, max 4 games machine-wide, `QA_SRC=<tree>` replaces the named lib files). NEVER start the love
  binary yourself, never `pkill -x love`, check `pgrep -fl MacOS/love` first, start jobs 20 s apart, absolute paths only.

## 3. The method, step by step

### Step 1. Orient (5 minutes, no exploring)
Read PLAN.md `[NOW]` + Handoff, the memory notes the Handoff names, nothing else. If the user brings new work, add it to PLAN.md Tasks first.
Done when you can say in two sentences what the task is and what state it is in. Stop and ask if PLAN.md and the user's request disagree.

### Step 2. Turn the feeling into a class and a number (read-only)
Do not ask "which rock?" first. Measure.
(a) Count rock ("cliff") cells per map and per tile id from the baseline cell dump
(`~/Documents/gen1recomp-modwork/baselines/heights-2026-10-20-fix-F025.txt`, one cell per line: `MAP x y TILE KIND coll=.. base=..`):
```python
import collections
GEN=set(range(0x068,0x0C0))-{0x085,0x086,0x087,0x08D,0x08E,0x09F,0x0A1,0x0A7,0x0AF}-set(range(0xB0,0xBE))   # General mountain tiles
relief={'EM_ROUTE111','EM_ROUTE114','EM_ROUTE113','EM_ROUTE115','EM_FALLARBOR_TOWN','EM_ROUTE112','EM_MT_CHIMNEY'}   # maps already on Gen3Relief.M.MAPS
gen=collections.Counter(); tot=collections.Counter()
for l in open(F):
    p=l.split(' ')
    if p[4]!='cliff': continue
    tot[p[0]]+=1
    if p[0] not in relief and int(p[3],16) in GEN: gen[p[0]]+=1
print(sum(gen.values()), 'of', sum(tot.values()))          # 13,261 of 27,489 on 2026-10-21
```
(b) Look at ONE frame of a map that is on the signed method and ONE that is not (`docs/rock-gates/pink/AB_new_EM_ROUTE111_22_102.png`
vs `.autoloop/runs/ab_cand/b003.png`). The difference is the class: rounded rolling slopes and sawtooth walls (old) versus straight terraces (signed).
(c) Name the class in one line with its cell count and the code that draws it. That line goes into the plan.
Done when you have a ranked table (map, cells, handled by which builder). Stop and ask if the numbers contradict the user's description.

### Step 3. Is there a signed method? Extend by data, not by new code
Read the memory notes and `docs/rock-gates/*/` for what the user already signed (classes, spots, rules). If the class is the same tile family,
the fix is: bake the other maps and add them to the opt-in list. Prefer this over writing a new builder. The user signed the look, so you
do not re-ask taste questions for the same class. New tile families (Sootopolis, Battle Frontier) are NOT covered: list them, ask the user.

### Step 4. Feasibility, read-only, before any plan (minutes)
Dry-run the solver on the candidate maps, printing but not writing anything:
```bash
cd ~/Documents/Emerald/tools/relief && python3 -B - <<'EOF'
import sys,time,collections; sys.path.insert(0,'.')
import emdata as E, terraces as T
for n in ['EverGrandeCity','Route116','Route119','MossdeepCity','Route118']:
    L=E.Layout(n); sol=T.solve(L); js=T.to_json(L,sol)
    print(n, collections.Counter(''.join(js['kind'])), sorted(set(sol['level'].values()))[:8], 'runs',len(sol['runs']),'dropped',len(sol['dropped']))
EOF
```
Map ids are the census ids (`E.census()['maps']`: `MtPyre_Exterior`, `BattleFrontier_OutsideEast`, ...), NOT the game ids. Done when every candidate solves
in seconds with sane levels. A map that fails here is dropped from the batch with its reason written down.

### Step 5. Plan, and get the OK
If the harness has plan mode, use it. If not, write the plan to a file under `docs/` and stop until the user says yes. The plan has: context
(the class and the number), approach (reuse), steps, critical files, verification, what is out of scope. Short. Link the evidence files.

### Step 6. Build in a probe tree, never in the installed game
```bash
S=~/Documents/Emerald/tools/relief/stage3 ; mkdir -p $S/probe && rsync -a "$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK/lib" $S/probe/
python3 -B tools/relief/bake_lua.py $S/ReliefData_all.lua Route111 Route114 FallarborTown Route112 MtChimney Route113 Route115 EverGrandeCity MtPyre_Exterior ...
cp $S/ReliefData_all.lua $S/probe/lib/Gen3ReliefData.lua
# edit ONLY $S/probe/lib/Gen3Relief.lua (M.MAPS ...); luajit -bl $S/probe/lib/Gen3Relief.lua >/dev/null
```
Prove the bake does not disturb what is signed: the first 7 maps of the new data file must be BYTE-IDENTICAL to the installed `Gen3ReliefData.lua`
(split the file on lines starting ` EM_`, compare the blocks). They were. Check load time: `luajit -e "local t=os.clock(); dofile('Gen3ReliefData.lua'); print((os.clock()-t)*1000)"`
(39 maps: 32-37 ms, 8.5 MB: no need to split). Every file name you pass to `qa_tryp.sh` must exist under the probe's `lib/`; the list that
works is `"Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"` (the three files where the QA copy is stale + yours).

### Step 7. Measure what really happens: the CLAIM CENSUS
Never assume a builder takes a mass because the data exists. `tools/em_relief_driver.lua` walks each map (multi-spot, orbit camera, same walk as
`em_cells_driver.lua`) and writes one line per rock-mass cell: `MAP x y MID builder relief sea` (builder `rock` = Gen3Rock took it, `dome` = Gen3Mass;
`relief` 1 = Gen3Relief claimed it; `sea` 1 = sea boulder, skipped by design). Run it in 7 batches of at most 6 maps, 3 games at a time:
```bash
tools/relief/stage3/run_census.sh census1 ~/Documents/Emerald/tools/relief/stage3/probe cen     # maps in stage3/cen_a..cen_g
python3 -B tools/relief/stage3/agg_census.py tools/relief/stage3/census1                        # per map: cells, relief, norelief, sea
```
Start it with `run_in_background` and NO trailing `&`; wait with a loop that ends in `true`:
`until [ -f census1/ALLDONE ]; do sleep 10; done; true`. Result on 2026-10-21: 24,629 mass cells, 19,112 claimed (Ever Grande 1718/1751, Mt. Pyre
exterior 1413/1413, summit 1041/1041, Route 116 855/886, ...). Anything at 0 claimed is a finding to explain, not to ignore: Battle Frontier E/W claimed 0
because `Gen3Rock.M.MAPS` omits it on purpose (comment at `Gen3Rock.lua:119`, "pond and garden walls stack into spikes"), so it needs its own A/B.

### Step 8. Look: OLD | NEW sheets at fixed spots
Spots: 2-3 per big map, a walkable cell 1-2 rows south of the rock with many claimed cells in view. `tools/relief/stage3/ab/spots.py MAP ...` picks them from the census
(it reads `census1/dump_*.txt`). Camera levels 4 (player), 6 (low, first person), 7 (orbit), yaw 0, `QA_ZOOM=-2`, one spot per `qa_tryp.sh` call.
```bash
tools/relief/stage3/ab/ab_run.sh A1 EM_MT_PYRE_EXTERIOR,30,36 EM_EVER_GRANDE_CITY,7,38      # OLD = installed lib, NEW = probe; 3 games at a time
VARIANTS=new ROUND=3 tools/relief/stage3/ab/ab_run.sh A1 EM_MT_PYRE_EXTERIOR,30,36          # later rounds re-run only NEW; dirs become new3_...
VARS=old,new3,new4 python3 tools/relief/stage3/ab/ab_sheet.py docs/rock-gates/general-rollout/A1 docs/rock-gates/general-rollout/A1/sheets4 EM_MT_PYRE_EXTERIOR,30,36
```
Output: `AB_<map>_<x>_<y>.png`, column 0 = the original 2D art with a coordinate grid (from `skills/emerald-terrain/scripts/crop2d.py`), then one column per
variant (OLD, NEW3, NEW4), rows = levels 4/6/7. KEEP EVERY ROUND as a column: the user (and you) see what each change did. This is the format the user signed
before (`docs/rock-gates/red/SHEET_red_r4_stepped.png`) and liked here (`docs/rock-gates/general-rollout/A1/sheets4/`).
Judge at FULL resolution: crop and enlarge with nearest-neighbour, never from the contact sheet. Use python3 WITHOUT `-I` (Pillow). Check `grep -c fallback run.log` = 0.

### Step 9. When a frame is wrong: diagnose in numbers, change one thing
Do not tweak by eye. For each wrong frame write the symptom and a measurement:
- `ab/hmap.py DUMP MAP x0 y0 x1 y1` prints a character map of final rock heights relative to the ground beside them (`F` flush, `f` low, `r` raised, `v` sunk, `M` mouth).
- `ab/lvgrid.lua MAP x0 y0 x1 y1` prints the counted level per cell from the baked data (half levels).
- `tools/em_reliefh_driver.lua` dumps final heights per claimed cell and per-mass anchors / offset histograms (`ab/census_h.sh` runs it in batches).
Then ONE change, rerun only the affected spots (`VARIANTS=new ROUND=n`), add a column. Maximum 3 fix rounds per class (project rule); a 4th only for one named,
measured leftover. If a round regresses something else, revert that round, do not tune it. Write each round down (what, measured, result) in PLAN.md.

### Step 10. Gates: what must NOT change must be identical
All three must pass before install; each is a script in `tools/relief/stage3/ab/`, 3 games at a time, background + waiter:
1. `v1_gate.sh <label>`: final relief heights of the 7 already-signed maps, installed lib vs probe, sorted, `cmp`. Must print `V1 GATE: IDENTICAL`
   (7,938 cell lines). This proves the signed look did not move.
2. `dump_gate.sh <label>` then `python3 -I tools/heights_compare.py diff CONTROL PROBE EMPTY_FLIPS`: whole-map cell dumps of the 53 outdoor maps (156,063 cells),
   installed vs probe: 0 cells differ (relief changes geometry, not the cell classification or floors).
3. `float_gate.sh <label>`: `Gen3Rock.audit` floating-rock audit on the 39 maps, installed vs probe: 0 new floats (1 old float on Route 125 stays).
Plus: 0 fallbacks to 2D and 0 Lua errors in every run.log (`grep -c fallback`). Report numbers, not adjectives.

### Step 11. Install (per batch; YOU may install, so you can iterate on the real game)
The user has said (2026-10-21) that the DeepSeek agent installs its own work so it can iterate; this replaces the loop's older "only the user installs" rule.
The conditions are: all three gates of step 10 passed for the batch, the OLD | NEW sheet is saved and you looked at it at full resolution, the backup exists, and
afterwards you tell the user in one short report what was installed, which maps, the sheet path and the revert command. Never install a batch whose gate failed
"to see what it looks like": use the probe tree for that. If the user later vetoes a map, remove it from `M.MAPS` (see revert below) without argument.
Protocol: backup the replaced files to `~/Documents/gen1recomp-modwork/backups/<name>_<date>/`;
copy `Gen3Relief.lua` (and `Gen3RockTables.lua` if changed) and `Gen3ReliefData.lua` to source lib + game + QA `mods/BATTLE_ART_VOXEL_FORK/lib`; `cmp` the three copies;
`OWN_LIB_EXTRA="lib/Gen3Relief.lua" tools/props/make_patch.sh`; commit NAMED files only (never `git add -A`: `tools/relief/stage3/` is 23 MB of ROM-derived data);
push; one smoke capture from the installed tree. Revert per map: delete it from `M.MAPS`. Revert per batch: restore the backup and the patch.

### Step 12. Handoff and memory (before context gets big)
Rewrite the PLAN.md Handoff (state with paths, next steps in order, gotchas; under 300 words), add one Log line (newest last, never rewrite old ones), write or update one
memory file for the lasting fact ("why", "how to apply"), add the line to MEMORY.md. Never start the next session yourself.

## 4. Worked example: the rock rollout (what happened, in order, with the evidence)
| Round | What | Evidence | Verdict |
|---|---|---|---|
| diagnosis | Counted relief on 7 maps only; 48% of rock cells on 30+ maps still old | F025 dump census, one signed vs one old frame | class named |
| feasibility | `terraces.py` solves Ever Grande / 116 / 118 / 119 / Mossdeep in 1-6 s | read-only dry run | go |
| bake | 39 maps in about 1 minute, 8.5 MB, loads in 32-37 ms; first 7 maps byte-identical to installed | block compare | safe |
| census | 24,629 mass cells, 19,112 claimed; Battle Frontier 0 (excluded on purpose) | `em_relief_driver.lua` | scope known |
| NEW (anchors only) | cleaner than the old fins and pits, BUT game floors are coarse (Pyre summit levels -1..1 all floor 0; Ever Grande -10..-2 all 32) so narrow ridges lay flat like painted decals and the Victory Road cave mouth stood as a lone pillar | A1 sheets, `em_reliefh_driver.lua` anchors | rejected |
| NEW2 (per-cell offsets from nearest ground, the red/brown method) | seed offsets span -8..288 px, spires up to 290 px | histogram of offsets | rejected |
| NEW3 (bounded hybrid) | signed 7 maps keep the anchors (`M.V1`); new maps: monotone anchors (pool-adjacent-violators), nearest-ground offsets medianed over radius `M.SMOOTH=4`, lift over anchors at most `M.LIFT=48` px, never below; max rise 69-109 px | sheets3, V1 gate | accepted by me |
| NEW4 | `M.SPIKE=24`: no cell stands more than 24 px over its tallest 4-neighbour (never below anchors) | sheets4 about identical at 6 spots | accepted |
| gates | V1 identical (7,938 lines), dump 0 of 156,063 differ, floats 0 new, 0 fallbacks | scripts above | pass |
Known leftovers, stated honestly: thin spikes at Ever Grande (18,43) L4 far left, one Summit (31,18) sliver, sharp tents on Pyre exterior (8,17) L7 (the 2D draws
rounded tall ridges there). Batch A2 (Routes 116/118/119/120/121, Mossdeep, Lilycove, Pacifidlog, Southern Island, Sky Pillar, Verdanturf, Frontier E/W) and the install
were NOT done when this was written; Jagged Pass (red class) and Sootopolis (needs new tables) are separate decisions for the user.

## 5. The lesson inside the height model (why NEW and NEW2 failed)
The game's walkable floors are coarse and the art's counted levels are fine, and on big maps they disagree. Any rock height model must BOUND that disagreement:
anchors alone flatten ridges (decals), per-cell offsets alone explode into spires. The working model: anchors say where the ground is (made monotone so
they never dip into a pit), the local relief may only LIFT a cell over them (bounded), and a spike cap stops one cell towering over its neighbours. Generalising:
when two data sources disagree, do not pick one; keep the trusted one as the floor, let the other add a bounded amount, and gate the result numerically.

## 6. The user's taste (the rubric a sheet is judged by)
Taller than the original and rugged, but smooth ("not a bouncy castle"); original pixels 1:1, face art repeats rows and is NEVER stretched; no fins, pillars, stripes,
holes, floating or melted parts; rounding at most about 3 px; more depth than the flat original is welcome; judge from behind and from the orbit too, not only the front.
"As close to the original as possible" beats a tidy look. A taste decision that is not covered by a signed class goes to the user as options, not chosen by you.

## 7. Hard rules
- One lead agent, one linear plan. Parallelism comes from scripts running 3 games at a time, not from agents. Subagents are allowed ONLY when they make the job
  more efficient or cheaper; "more agents" is never the goal. Test before spawning, and write the answer to these in one line in the Handoff:
  (1) what does it replace and is that clearly more tokens, time or cost than doing it yourself or with a script? (2) is the question narrow and independent
  (one question, one output)? (3) does a cheaper model suffice (use the cheapest that can do it)? (4) is the result a short summary (under 250 words, with
  file:line or numbers) so you do not have to read the pages it read? If any answer is no, do it yourself. Good uses: a read-only search across many files that
  returns path:line pointers; running a named test suite and reporting pass/fail; one-off conversions of many files that follow one given pattern. Bad uses
  (they are what made the loop expensive): one fixer per fault, a verifier per fix, a judge per frame (you judge frames yourself, at full resolution), an agent
  that must re-learn the whole context, several writers touching the same files. At most 2 subagents at once, never two writers on the same file, never a
  subagent that installs or commits.
- Probe tree for experiments; the installed game, the source tree and the shared QA copy change only through the install protocol of step 11 (backup, gates, cmp).
- Never claim "fixed" or "looks fine" without naming the frame file you looked at, at full resolution. If your model cannot see images, say so; use the numeric tools
  (hmap, lvgrid, histograms, gates) as the evidence and let the sheet be for the user.
- Gates are strict. Never recalibrate a detector or loosen a comparison to make a result pass. Never tune after a regression: revert the round.
- Max 3 fix rounds per class. Then stop, write what you learned, ask.
- If a command fails twice, write the exact command and error into the Handoff and stop; do not improvise around it.
- Never `git add -A` or `git stash` in these trees; commit named files; `tools/relief/stage3/` and every dump are ROM-derived and stay out of git.
- Gotchas that cost time: absolute paths for `qa_tryp.sh` and drivers; one far spot per run; LuaJIT `pairs()` order is random per run (sort before use; dumps are
  repeatable only because F025 was fixed); macOS `sed -i ''`; `python3 -I` hides Pillow (sheets need plain python3); a backgrounded waiter must end with `true`;
  run background scripts with `run_in_background` and no trailing `&`; `timeout` does not exist on this mac; the QA copy is stale (see section 2).

## 8. Applying the method to the next jobs
- **Ghost / discovery (PLAN task 2):** replace "walk every spot, score, judge the worst 20" by a census first. For each map and class compute cells by builder and tile
  (as step 2 and step 7), rank classes by cells affected times how much they differ from the signed look, and only then capture spots INSIDE the top classes. The
  decision sheet should be class cards ("48% of rock cells use the old method: here is OLD | NEW"), not 10 individual spots.
- **Trees (PLAN task 11):** same shape. (1) census: per map, per tree tile id, which builder drew it (Gen3Canopy, Gen3Objects, Gen3Elevation.bind pairing, NativeTreeArt,
  TreePresentation) and how many are mangled (use a driver like `em_relief_driver.lua` that writes one line per tree cell with the builder and height); (2) `git log -p` on those
  files to find why the earlier fix regressed (F025 changed tree-half pairing: trees are paired by tile, left half even mid, ash forest 0x26B-0x276 odd); (3) one rule keyed
  by tile family, not per-map pins; (4) sheets of Dewford, Mt. Chimney, Fallarbor, Fortree at levels 4/6/7 from the front AND behind; (5) gates by byte-compare of everything
  that is not a tree.
- **Other rock classes:** Battle Frontier E/W (own A/B, `Gen3Rock.M.MAPS` excludes it), Jagged Pass (add to `RT.RED_MAPS`, bake `JaggedPass`, same red class as Route 112),
  Sootopolis (secondary tiles 0x2D3-0x2E1: needs hand-authored tables like Stage 2; ask the user first), caves (not dumped, not covered).

## 9. File map for this method (all under ~/Documents/Emerald unless noted)
| What | Where |
|---|---|
| Plan, handoff, log | `.claude/handoffs/PLAN.md`; approved plan `~/.claude/plans/distributed-snacking-candle.md` |
| Memory | `~/.claude/projects/-Users-user-Documents-Emerald/memory/emerald-relief-rollout.md`, `emerald-relief-stage1.md`, `emerald-relief-ab-choice.md` |
| Solver, baker, loader | `tools/relief/{terraces,bake_lua,emdata,proof,render}.py` (`emdata.em_name` was fixed for ids with an underscore) |
| Census drivers | `tools/em_relief_driver.lua` (claims), `tools/em_reliefh_driver.lua` (final heights, anchors), `tools/em_cells_driver.lua` (cell dump), `tools/em_float_driver.lua` (floats) |
| Probe tree and scripts | `tools/relief/stage3/` (`probe/lib`, `ReliefData_all.lua`, `run_census.sh`, `agg_census.py`, `census1/`, `ab/*`) - untracked, ROM-derived |
| Sheets | `docs/rock-gates/general-rollout/A1/sheets4/AB_*.png` (2D | OLD | NEW3 | NEW4); earlier signed sheets `docs/rock-gates/{pink,beige,red,brown}/` |
| Gates | `tools/relief/stage3/ab/{v1_gate,dump_gate,float_gate}.sh`, `tools/heights_compare.py`, `tools/qa_tryp.sh` |
| Install | `tools/props/make_patch.sh`, backups in `~/Documents/gen1recomp-modwork/backups/` |
| Loop documents (context, not the method) | `docs/AUTOLOOP.md`, `docs/autoloop/{FIXER,VERIFIER,GHOST}-BRIEF.md`, `docs/RELEASE-CANDIDATE-2026-10-24.md` |
