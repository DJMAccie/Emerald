# Battle models (mod/models/)

Reads the 3D Pokemon models out of your own game files and serves them to the world in `lib/`, which draws
Emerald's battles: Pokemon Stadium 2 for #1-251 (all Unown) and Colosseum for #252-386. Nothing of its own is
rendered here; there is no separate battle scene.

- ROM: the game asks once for your own **Pokemon Stadium 2 (USA)** ROM (MD5 `1561c75d11cedf356a8ddb1a4a5f9d5d`) and keeps it in
  the game's `mods/emerald_3d_voxel_mod/baseroms/`. No ROM or disc data ever goes in git.
- Colosseum models: `colosseum/<normal|shiny>/<dex>.dsm` in the game's mod folder (made from your own Colosseum disc;
  `lib/colosseum.lua`), not in git. Players make them with `hoenn/make_hoenn_models.py` (see its docstring and the top README);
  `hoenn/addon/` is a trimmed GPL-3 add-on it reads the disc with (licence and notice inside).
- Code: `main.lua`, `lib/` (ROM reading, packs, renderer), `workers/`.
- Tests: `tools/run_tests.sh` (engine at `../../../gen1recomp`, ROM from the game folder); every red test is a failure.

## Credits

The research into Stadium 2's formats builds on the decompilation project
[pret/pokestadiumgs](https://github.com/pret/pokestadiumgs).
