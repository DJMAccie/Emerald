# Emerald 3D (mod `BATTLE_ART_VOXEL_FORK`)

Pokémon Emerald as a 3D voxel world, drawn from the game's own tiles. Emerald only: no code for other games.

- `main.lua` hands the engine's Gen 3 field pass to `lib/Gen3Integration.lua`; everything else is in `lib/`.
- `lib/Gen3*.lua` is the world (scene, buildings, rock, relief, water, interiors); `lib/Gen3Battle*.lua` and `lib/Stadium*` the battles.
- `data/` holds baked tables and per-building models (`data/buildings`), `assets/` images and shaders.
- Tests: `tools/run_tests.sh ../gen1recomp` from this folder (every red test is a failure).
- QA and install: `tools/qa_tryp.sh` and `tools/install.sh` in the project root (see `../README.md`).
