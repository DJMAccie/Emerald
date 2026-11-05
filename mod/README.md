# Emerald 3D Voxel Mod (mod `emerald_3d_voxel_mod`)

Pokémon Emerald as a 3D voxel world, drawn from the game's own tiles. Emerald only: no code for other games.
One mod, three parts, wired together in `main.lua`:

- `lib/` the world: `Gen3*.lua` builds the scene, buildings, rock, relief, water and interiors; `Gen3Battle*` and `Stadium*` draw the battles.
- `models/` the battle models: reads Stadium 2 and Colosseum models from your own files and serves them to `lib/`.
- `wilds/` the overworld: wild Pokémon, the follower and overworld catching.
- `data/` holds baked tables and per-building models (`data/buildings`), `assets/` images and shaders.
- Tests: `tools/run_tests.sh ../gen1recomp` from this folder (every red test is a failure); `models/tools/run_tests.sh` for the model code.
- QA and install: `tools/qa_tryp.sh` and `tools/install.sh` in the project root (see `../README.md`).
