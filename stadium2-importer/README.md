# Pokemon Stadium 2 Importer (`STADIUM2_IMPORTER`)

Second mod of this repo: imports the 3D Pokemon models from Pokemon Stadium 2 (#1-251, all Unown) and serves them,
plus Colosseum models (#252-386) and Stadium 2 move effects, to `../mod` (BATTLE_ART_VOXEL_FORK), which draws Emerald's battles.
It has no battle scene of its own (the Gen 1/2 arenas, Kenney scenes and test room were removed 2026-11-02; history before that).

- ROM: the game asks once for your own **Pokemon Stadium 2 (USA)** ROM (MD5 `1561c75d11cedf356a8ddb1a4a5f9d5d`) and keeps it in
  the game's `mods/STADIUM2_IMPORTER/baseroms/`. No ROM or disc data ever goes in git.
- Colosseum models: `colosseum/<normal|shiny>/<dex>.dsm` in the game's mod folder (made from your own Colosseum disc;
  `lib/colosseum.lua`), not in git.
- Code: `main.lua`, `lib/` (ROM reading, packs, renderer, battle FX), `workers/`.
- ROM layout facts with sources: `DECOMP_NOTES.md`. Older notes, plans and bug logs: git history before this README
  (`git show 750bea8:stadium2-importer/docs/...`).
- Tests: `tools/run_tests.sh` (engine at `../gen1recomp`, ROM from the game folder); every red test is a failure.

## Credits

The research into Stadium 2's formats, battle effects and UI builds on the decompilation projects
[pret/pokestadiumgs](https://github.com/pret/pokestadiumgs) and [michiiik/pokestadiumgs](https://github.com/michiiik/pokestadiumgs).
