# Dead-code tools (5b step 1g, 2026-11-02)

- `dead.py <mod> <engine>`: static fixpoint of functions nobody references (engine, `tools/` and the Fly driver count as users). ~5 s.
- `deadq.py <mod>`: like dead.py, but `function M.f` only counts uses through an alias of M (`local A=V.require('M')` ... `A.f`);
  modules passed around as values fall back to name counting. Catches `install`/`update` that dead.py thinks are used. Output `/tmp/deadscan/deadq.json`
  (feed `[[file,name,line]]` to remove.py).
- `remove.py <mod> spec.json`: deletes whole function statements by token span (`[[file,name,line],...]`), compile-checks each file.
- `unused_locals.py <mod>`: locals never used (often a `V.require` that loads a module for nothing).
- `instrument.py <mod> <out>`: probe copy where every function/then/else prints `[COV] id` once (same line numbers); `covmap.json` maps ids.
- `sweep.sh` (40 QA spots, camera levels 0-7, 2 battles, 2 Fly flights) and `allmaps.sh` (all 518 maps, 18 batches of 30, centre cell).
- `report.py covmap.json run.log...`: never-run spans per file.

Gotchas: run sweeps with `nohup` (Bash background tasks die after ~2 min); more than ~4 waiting `qa_tryp.sh` runs drop out
silently, use `xargs -P3`; `tools/run_tests.sh` needs a `timeout` command (macOS has none: put a shim on PATH).

Coverage data of mod 72a4125: `/tmp/deadscan/probe/covmap.json`, logs `/tmp/deadscan/cov/*/run.log` and `/tmp/deadscan/covmaps/*/run.log`
(all done except allmaps batches b08 b09 b10 b13 b15 and Fly "land").

Found dead (never loaded in any run, and only reachable from dead code):
SkyLayer, Backdrop, ForestDressing, TileShape (+ data/voxel_heights.lua) = only loaded by `CommunityVisuals.invalidate()` to reset them,
or by InteriorDiorama's `gen~=3` branch; FirstPerson, ThirdPerson, SpriteBillboards (Gen 1/2 camera; Emerald's 1ST/3RD camera is in
Gen3Scene; `BattleCam.seedFromFreeCamera` uses plain `require`, which never finds them in the sandbox); MapCompat (only Backdrop/SkyLayer);
Gen3TowerExterior (named nowhere). `astra_*` tests need a Pokemon Yellow dataset (Gen 1).
