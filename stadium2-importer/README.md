# Pokemon Stadium 2 Importer (`STADIUM2_IMPORTER`)

Second mod of this repo: imports the 3D Pokemon models from Pokemon Stadium 2 (#1-251, all Unown) and serves them,
plus Colosseum models (#252-386), to `../mod` (BATTLE_ART_VOXEL_FORK), which draws Emerald's battles.
It has no battle scene of its own (the Gen 1/2 arenas, Kenney scenes, test room and move effects were removed 2026-11-02; history before that).

- ROM: the game asks once for your own **Pokemon Stadium 2 (USA)** ROM (MD5 `1561c75d11cedf356a8ddb1a4a5f9d5d`) and keeps it in
  the game's `mods/STADIUM2_IMPORTER/baseroms/`. No ROM or disc data ever goes in git.
- Colosseum models: `colosseum/<normal|shiny>/<dex>.dsm` in the game's mod folder (made from your own Colosseum disc;
  `lib/colosseum.lua`), not in git. Players make them with `hoenn/make_hoenn_models.py` (see its docstring and the top README);
  `hoenn/addon/` is a trimmed GPL-3 add-on it reads the disc with (licence and notice inside).
- Code: `main.lua`, `lib/` (ROM reading, packs, renderer), `workers/`.
- Tests: `tools/run_tests.sh` (engine at `../gen1recomp`, ROM from the game folder); every red test is a failure.

## Credits

The research into Stadium 2's formats builds on the decompilation project
[pret/pokestadiumgs](https://github.com/pret/pokestadiumgs).
