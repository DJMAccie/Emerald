# Pokemon Stadium 2 Importer (`STADIUM2_IMPORTER`)

Second mod of this repo: 3D battles with Pokemon Stadium 2 models (#1-251, all Unown) and Colosseum models (#252-386),
plus Stadium arenas, move effects, the free battle camera and the in-battle evolution. The game still runs the battles;
this mod only changes how they look. For Emerald, `../mod` (BATTLE_ART_VOXEL_FORK) uses it as an optional dependency.

- ROM: the game asks once for your own **Pokemon Stadium 2 (USA)** ROM (MD5 `1561c75d11cedf356a8ddb1a4a5f9d5d`) and keeps it in
  the game's `mods/STADIUM2_IMPORTER/baseroms/`. No ROM or disc data ever goes in git.
- Colosseum models: `colosseum/<normal|shiny>/<dex>.dsm` in the game's mod folder (made from your own Colosseum disc;
  `lib/colosseum.lua`), not in git.
- Code: `main.lua`, `lib/` (ROM reading, packs, renderer, arenas, battle FX), `workers/`, `assets/kenney_*` (CC0 scenes,
  made with `tools/build_kenney_*.py`).
- ROM layout facts with sources: `DECOMP_NOTES.md`. Older notes, plans and bug logs: git history before this README
  (`git show 750bea8:stadium2-importer/docs/...`).
- Tests: `tools/run_tests.sh` (engine at `../gen1recomp`, ROM from the game folder); every red test is a failure.

## Credits

The research into Stadium 2's formats, battle effects and UI builds on the decompilation projects
[pret/pokestadiumgs](https://github.com/pret/pokestadiumgs) and [michiiik/pokestadiumgs](https://github.com/michiiik/pokestadiumgs).
The battle UI is the [Stadium 2 UI](https://github.com/Deftones565/Stadium-2-UI) mod.
