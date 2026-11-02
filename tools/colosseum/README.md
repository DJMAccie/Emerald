# Colosseum models (#252-386)

Makes the Hoenn battle models from the user's own Pokemon Colosseum disc: `tools/colo2dsm.py` turns each PKX model
(read with the Blender DAT addon's Blender-free phases, `tools/pkx_to_ir.py`) into a Stadium 2 importer DSM5 pack.
The game reads them from `mods/STADIUM2_IMPORTER/colosseum/<normal|shiny>/<dex>.dsm` (`stadium2-importer/lib/colosseum.lua`).

- In git: the scripts in `tools/`, `moves.csv`, `types.csv`, `name_to_dex.json`, `pkx_index.json`, the species CSVs.
- Local only (`.gitignore`): `addon/` (GPL-3 Blender addon), `fs/` (unpacked disc files), `dsm_all/` and `out/` (made models).
- Run: `python3 tools/colo2dsm.py dsm_all` from this folder; `tools/calibrate.py` sets the Colosseum -> Stadium size factor.
- Check 2026-11-02: a plain run rebuilds `dsm_all/achamo.dsm` byte for byte; the game's `normal/255.dsm` differs only in the
  16-byte header scale (the calibrated size factor), so set the calibration before replacing game models.
