# Brief for any coding agent (Gemini, Codex, another Claude) joining Emerald 3D

You are helping finish a 3D voxel mod for Pokemon Emerald (Lua on LÖVE, game folder `~/Documents/battle-art-notquiteog`, tools and docs in `~/Documents/Emerald`, a git repo, branch main, remote origin). The goal is a releasable version, reached by an automated loop that discovers faults, fixes one class at a time, and proves each fix with scripted gates. Read these first, in order: `HANDOFF.md`, `docs/DONE.md`, `docs/LEDGER.md`, `docs/HEIGHT-PATH.md`, `docs/BAKE-SPIKE.md`, `docs/COMPARE-3DS-v0.4.0.md`, and the plan section "8. Automated release loop" in `/Users/user/.claude/plans/clever-soaring-coral.md` (if you cannot read that path, ask the user to paste it).

## Rules that apply to you
- Never edit or install files in `~/Documents/battle-art-notquiteog/lib` or the user's game folder (`~/Library/Application Support/pokemon-love2d`). Mod changes are made by the Claude sessions the user runs.
- Never run `git stash` in battle-art-notquiteog. In `~/Documents/Emerald` work on your own branch (`git switch -c <agent>-<task>`), commit only files you created or changed for your task, and do not push to main; the user merges.
- No ROM-derived files in git (atlases, world.json, captures, cell dumps). They live in `~/Documents/gen1recomp-modwork`.
- QA games: before any run `pgrep -fl "MacOS/love"`; use `tools/qa_tryp.sh "<lib files> Gen3Waterfall.lua" <outdir> "<cases>" <level> <yaw> <wait>`; at most 2 QA runs at once from you (the machine allows 4 in total and Claude sessions use them); stagger starts 20 s; a run is capped at 400 s.
- The scanners and audits stay strict. Do not change a calibration to hide a fault. Only the user marks a ledger row done.
- Report facts with numbers. If a check fails, say so.

## Tasks you can take (independent of the mod source; pick one, state which)
1. **Incremental gate runs.** Extend `tools/release_check.sh` so a run re-checks only maps whose inputs changed since the last good run (hash of the map's data, the lib files that feed geometry, the tileset art) and reuses the stored results otherwise. Done = a second run with no change finishes in under 5 minutes and prints "0 maps re-checked"; a changed lib file re-checks only the affected maps.
2. **Automated walkthrough waypoints.** Write `tools/waypoints.py`: from a cell dump (format in `tools/heights_compare.py`) and `docs/ledger/outdoor_spots.txt`, produce a `cases` file for `qa_tryp.sh` with a waypoint every ~8 walkable cells plus every door, stair, ledge and building front, so every walkable cell is within ~12 cells of a waypoint. Done = report waypoint count and coverage per outdoor map.
3. **Shot filters.** Write `tools/shot_filter.py` (run with `python3 -I`, Pillow and numpy): for a folder of captures compute the magenta-hole score (lower 45% of the frame), flat single-colour area share, and an edge-streak score, and write `filter.json` plus a contact sheet of the worst 30 tiles. Test it on `docs/shots/*.png`.
4. **Tests.** Add `tests/` style checks for `tools/ledger.py`, `tools/heights_compare.py`, `tools/tour_note.sh` (dry run) and `tools/elevation/height_overrides.py`, runnable with one command.

## When done
Commit on your branch, then report: branch name, files, how to run, one example of its output, anything you could not verify. Do not start other work.
