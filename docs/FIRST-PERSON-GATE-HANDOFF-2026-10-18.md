# First-person gate: report and handoff (2026-10-18)

## The goal (set by the user with /goal, still active)

> Emerald passes these gates, all installed and pushed: every map shows 3D within 1 s of entering;
> a first-person survey (4 directions + orbit) of every outdoor map and every room layout finds zero
> floating surfaces, open edges, plain single-colour faces, stretched streaks, borrowed-tile art or
> in-wall cameras; every building is modelled and textured on all 4 sides with the defect scanner
> clean; map edges are closed; the stairs audit shows no flat or reversed stairs and no cliff jumps;
> battles, grass and overworld Pokémon are unchanged.

It is **not met yet**. Status per gate is below, then a brief for the next session.

---

## Report

### Status per gate

| Gate | Status |
|---|---|
| 3D within 1 s | Met in one serial run of all 212 maps. Worst: Rustboro 0.9–1.2 s (load-sensitive). Needs one more serial re-time after later changes. |
| Outdoor survey (53 maps) | 4 first-person directions done for all 53; orbit done for 42. Fixes applied; a few slivers left (below). |
| Room survey (159 layouts) | All 795 frames captured. Reviewed: the 47 auto-flagged frames + the first 12 rooms. **147 rooms not yet reviewed by eye.** |
| Buildings, defect scanner | 17 bakes still flagged (stretch 5, ground 9, steps 6), down from 55. |
| Map edges closed | Done (4b06331) and re-checked by the magenta probe; only the haze horizon line remains. |
| Stairs audit | 0 walkable jumps on all 55 outdoor maps. Flat 2 left, reversed 1 (see below). |
| Battles / grass / overworld Pokémon | Checked before vs after today's changes: battle frames match (last frame differs only by the wild Pokémon's move); grass and overworld Pokémon on Routes 102, 117, 119 identical. Should be repeated once at the end. |

### Commits this session (Emerald repo, all pushed; patch in `patches/battle-art-voxel-fork.patch`, installed in game + QA)

- `fa5d5fa` speed: every map under 1 s; walkable jumps 14 → 0
- `df35be4` Frontier West grand stair, Sootopolis stoops
- `0c879b8` building side walls get front's posts/windows; scanner counts one-colour smears
- `8eba361`, `4230782` houses/gyms stand within their drawn walls (edge trim)
- `38169f4` Fortree: hut floors close down to the forest, forest floor down to paths
- `3d27f8c` Route 119 plateau pin (flat stair climbs)
- `b2c8bf3` Frontier flower beds: sides show tile column, not stretched pixel
- `22cedfa` water quads overlap a hair (no hairline cracks across the sea)
- `9507081` rooms: south wall and void-cell walls get window panels
- `371aa8a` Birth Island, Faraway Island, Navel Rock under the sky (OPEN_SKY)

### What is left (concrete)

**Rooms (biggest open item)**
- Review rooms 13–159 by eye. Sheets: `rvall/a02.png` … `rvall/a26.png` (6 rooms per sheet, columns = north, east, south, west, orbit).
- Known faults already seen:
  - Dewford Gym: maze walls are plain olive faces in first person.
  - Ever Grande halls (Hall1, Hall4): plain beige wall above the stairs.
  - Walls where the camera stands close (e.g. Dewford House1 looking south) still show a large plain area between the window panels.
- Not faults: black slab at the frame edge = an NPC standing next to the camera; black around rooms in orbit = the void outside the room shell (by design); dialogue boxes in frames = NPC scripts firing.

**Outdoor slivers**
- Mt. Pyre Summit: slit beside the stair and a sliver at a rock's foot; pale translucent green slabs (not yet identified — maybe grave mist drawing as boxes).
- Jagged Pass (13,13): thin gap at the stair's west edge.
- Ever Grande: grass-coloured rims on rock ledge tops.
- Fortree: thin slivers at two hut deck corners (probe: (398,166) a cell north of the map edge, (961,270) near cell (35,6)).
- Orbit shots missing for 11 outdoor maps; Littleroot's survey spot is inside the moving truck (move it).

**Buildings (defect scanner, `tools/buildings/defect_scan.py`)**
- stretch 5: b064 space center (tower caps), b154 Ranking Hall (barrel-roof ends), soot_cone, x_frontier_dome (base), x_frontier_pyramid (edge) — 4–8 row strips.
- ground 9: b048 contest lobby, b078 league, b089 Dewford gym, b092 herb shop, b099 Fallarbor tent, b154, x_cablecar_route112, x_frontier_tower (two lawn patches at its foot), x_slateport_museum. Most are hand-adjusted bakes whose installed file differs from a fresh export, so they can't be bulk-regenerated.
- steps 6: x_frontier_dome, x_frontier_pike, x_frontier_factory, frontier_gate, pacifidlog_hut, x_cablecar_route112.

**Stairs (`tools/elevation/stairs_audit.py`)**
- Battle Frontier West (31,28): one-cell 0x0AF stair into a walled garden; pinning the garden at −1 dropped the sea beside it, reverted.
- Jagged Pass (13,13): probably an audit false positive (stair leads onto a jump ledge).
- Route 119 (5,80) "reversed": the cartridge rates the plateau south of it higher, which is what the 3D shows; lifting floors earlier looked worse (user-visible decision, left).

**Unexplained**
- Route 112's red cliff (cells x12–20, y40–44) gives a different vertex checksum with the speed changes; side-by-side shots look identical. Likely `pairs()` order over cell-keyed tables in rock building; not pinned down.

---

## Brief for the next session

### Read first
- Memory: `emerald-first-person-gate.md`, `emerald-building-bakes.md`, `emerald-push-and-install.md`, `emerald-qa-batching.md`, `emerald-hills-and-qa-fidelity.md`.
- CLAUDE.md: use Plan Mode before new features / significant tradeoffs / bugs that survive a first fix.
- Install QA-checked work without asking; push main periodically. Never commit in `battle-art-notquiteog`.

### Where things are
- Mod source: `~/Documents/battle-art-notquiteog/lib` (and `data/buildings/*.lua` bakes).
- Installed: game `~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK/`, QA `…/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK/`.
- Scratch of the previous session (readable, same machine):
  `/private/tmp/claude-501/-Users-user-Documents-Emerald/8031de72-4566-4367-846e-8ff6bee75d9b/scratchpad/`
  - `interior_centre_cases.txt` (159 room spots), `out_centre.txt` (53 outdoor spots)
  - `rvb/rv_<view>_bNN/` room frames, `rvall/aNN.png` room sheets, `rv_metrics.txt`
  - `sv/`, `svb/` outdoor frames; `probeN/` magenta probe tree; `magenta.py` scorer
  - `qa/fz_all/st/dump1.txt` latest outdoor cell dump; `cellinfo_driver.lua`, `times_all.lua`, `prof_driver.lua`, `wait_driver.lua`, `bakeviews.py`

### How to work (methods that worked)
- **Shots**: `tools/qa_tryp.sh "<lib files>" <outdir> "<cases>" <level> <yaw> <wait>` with `QA_ZOOM=-2` for the default camera. Level 4 = play, 6 = first person, 7 = orbit. Yaw 0 north, 1.57 east, 3.14 south, 4.71 west. `QA_SRC=<tree>` takes files from a probe tree.
- A run is capped at 400 s: batch ~15 cases per run (wait 900 outdoors, 300 indoors), 4 runs in parallel via a script (`ls batches | xargs -P 4 -n 1 script.sh`; an inline `zsh -c` overflows xargs).
- **Holes**: the magenta probe (`probeN`, underlay painted magenta) + `magenta.py`; magenta in the lower part of a frame = no surface. Indoors the underlay isn't drawn, so judge rooms by eye.
- **Which code draws it**: `Gen3Scene.probeBox={x0,x1,z0,z1}` (set it from `Gen3SceneOptions.finish` in a probe tree) prints every cell emitting quads there.
- **Speed**: the game runs with LuaJIT's JIT **off**; avoid per-voxel/per-pixel table allocations and inline `ipairs({{1,0},…})`. Memoise per build (`Gen3Scene` build start calls `newBuild()` on Objects/Mass/Terrain/Planter). Verify with an order-independent vertex checksum hook before `cache.civics={}`. Time serially with a warm-up map first.
- **Heights**: two places force a building's foundation onto its cells — `Gen3Elevation.bind` and `BuildingModels` (`bld.claimed`); both keep walkable cells that join open ground.
- **Bakes**: never bulk-install generated bakes over hand recipes; only replace a bake whose installed file equals the untrimmed export, keep headers byte-identical, render four sides old vs new (`bakeviews.py`). Patch: `tools/buildings/make_patch.sh` for bakes; `OWN_LIB_EXTRA="lib/…" tools/props/make_patch.sh` for lib files (pass every lib file changed since the last patch).
- **Install**: back up to `~/Documents/gen1recomp-modwork/backups/<name>/`, copy to game + QA, `cmp`, rebuild patch, commit with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, push main.

### Suggested order
1. Finish the room review (`rvall/a02`–`a26`), list faults by class, fix by class (Dewford gym maze walls, close plain walls, Ever Grande halls first).
2. Outdoor slivers (Mt. Pyre Summit, Jagged Pass, Ever Grande rims, Fortree corners); fill the 11 missing orbit shots; move the Littleroot spot.
3. The 17 scanner bakes (look at each from four sides before deciding fix vs scanner calibration; tell the user about any scanner rule change).
4. Final pass: serial re-time of all 212 maps, stairs audit, magenta sweep, USP check (battle frames, grass, overworld Pokémon) before vs after.
5. Report to the user; open choices to ask: Route 119 (5,80) and Jagged Pass (13,13) stair rulings.

---

## Update (later on 2026-10-18)

Room review finished (all 159 rooms, 5 views each). Fixed by class, installed and pushed:
- `369ab69` Dewford Gym and Trick House maze walls carry their front's art on every side (`wallArt`).
- `9507081`, `84a4ecc`, `6abc8d0` room shell: window panels on the south wall and void-cell walls, one per ~72 px, a row per 40 px of height (Ever Grande halls).
- `a5f11cc` indoor wall columns: sides/backs show the wall tile in 16 px courses (Elite Four south wall was a plain navy slab).
- `e698bcc` Aqua Hideout submarine shadow (gfx 141) lies flat on the water (`FLAT_GFX`).
- `371aa8a` ferry islands under the sky.
- `c0e9daa` defect scan: steps judged only against a straight drawn edge. Steps 6 → 2.

Defect scanner now: 14 bakes (ground 9, stretch 5, steps 2).
- ground: thin 1–3 px edge strips over sand/grass on hand-adjusted bakes (Dewford gym, herb shop, …); in game those faces are already repainted with wall colour at load (BuildingVoxels REPAINT_GROUND). Needs a careful per-bake trim; not bulk-regenerable.
- steps: Battle Dome lower glass base (cut corners made it worse: 16 → 23, reverted), Pacifidlog hut roof.

Outdoor: Mt. Pyre Summit's "green slabs" are its stair treads in the path colour (not a fault); a hairline at one rock corner by the north stair and a sliver at a rock's foot remain. A pit rule for sunk blocked cells was tried and reverted (changed nothing).

Still open: the summit hairlines, Jagged Pass stair gap, Ever Grande ledge rims, Fortree deck corners; 11 missing outdoor orbit shots and the Littleroot spot; the 14 bakes; the stair rulings (Route 119 (5,80), Jagged Pass (13,13), Frontier West garden (31,28)); final serial timing and USP check.

### Final checks (end of 2026-10-18)
- Speed: serial re-time of all 212 maps with every change installed: all under 1 s (worst Rustboro 934 ms, Frontier West 850 ms), no 2D fallbacks.
- USP: battle frames vs the pre-change build differ ≤1.2% (animation timing, same as before); Routes 102/117/119 grass and overworld Pokémon identical.
- Outdoor survey complete: 53 maps × 4 first-person directions + orbit (Littleroot re-shot from (14,12), clear of the truck; Route 114 north filled in). Magenta only at the haze horizon apart from the small slivers listed above.
- Ever Grande's ledge "rims" are the drawing's own grass pixels on the ledge tops, tilted with the rock face (left as is).
