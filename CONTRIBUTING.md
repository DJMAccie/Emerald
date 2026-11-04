# Contributing to Emerald 3D

Thanks for wanting to add to this. The mod is Lua code for gen1recomp, so most changes are small and easy to check by eye.

## What you need

- gen1recomp, and your own legally owned **Pokémon Emerald** ROM imported into it.
- For battle work: your own **Stadium 2** ROM and/or **Colosseum** disc.
- LuaJIT, Python 3 and `rsync`. The scripts in `tools/` are written for macOS; on other systems you will need to adapt the paths in `tools/install.sh` and `tools/qa_tryp.sh`.

Never commit ROMs, ROM-derived files (atlases, `.rgba`, caches) or screenshots of the game. `.gitignore` already blocks `*.png`, `*.jpg`, `*.gba`, `*.z64`, `*.iso` and `*.love`.

## How a change goes

1. **Pick one thing that looks wrong** (a cliff, a roof, a cave door) and fix just that in `mod/`.
2. **Test it:** `cd mod && tools/run_tests.sh <path-to-gen1recomp>` must pass.
3. **Show before and after.** Capture the map in a private copy with `tools/qa_tryp.sh` and compare the shots. The last line of `run.log` must say `fallback 0`. Put the comparison in the pull request (as an attachment, not in the repo).
4. **Install and look:** `tools/install.sh` copies the mod into your game.

## Where things live

- `mod/lib/Gen3*.lua` build the world: `Gen3Blocks` (terrain and rock), `Gen3Scene` (streaming and ground), `BuildingVoxels` (buildings), `Gen3Objects` (props), `VoxelHull` (round trees and rocks).
- `mod/data/` holds generated tables. Do not edit them by hand: regenerate them with the tool named at the top of each file (for example `tools/heightmaps.py`, `tools/tilerules/`).
- `docs/knowledge/rules.md` is the list of look rules (heights, stairs, rock, trees). Read it before changing how terrain is built.
- `docs/elevation/` has the hand-drawn height maps the terrain heights come from.

## Style

- Keep code small: delete what the game never calls, and prefer one-line comments.
- One change per commit, with a message that says what changed and why.
- Match the original art: the 3D must be built from the game's own tiles, not from invented colours.

## Licence

No licence has been chosen yet. Until one is added, please open an issue before sending a large change.
