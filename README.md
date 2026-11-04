# Emerald 3D

Pokémon Emerald, rebuilt as a 3D voxel world. A mod for gen1recomp (the Gen 1-3 native recompilation engine).
You walk the same Hoenn, but the maps stand up in three dimensions, with a camera you can turn.

**Status: alpha 0.1.0.** Nearly the whole of Hoenn is voxelized, 3D battles work, and a few small things are left.
Project page: <https://petyabouianov.com/emerald-voxel>

## What it does

- **Voxel overworld.** Routes, towns, buildings, caves and interiors are built from Emerald's own tiles, block by block. Heights come
  from height maps checked tile by tile (165 maps), so cliffs, stairs and caves are drawn from the art, not guessed.
- **Free camera.** Several camera levels, from the classic overview to a close orbit and first person.
- **Pokémon in the overworld.** Wild Pokémon walk the routes (`overworld_wild_spawns`), and your lead Pokémon follows you.
- **Day and night.** The sky follows your computer's clock: sun, moon, and street lamps that come on after dark.
- **Cinematic Fly.** HM Fly lifts into an aerial camera over the whole region.
- **No border flash.** Neighbouring maps are built before you reach the edge.
- **3D battles.** Pokémon #1-251 use Pokémon Stadium 2 models and #252-386 use Pokémon Colosseum models, both made from your own game files.

## What is in the download

`Emerald 3D.zip` holds three mods, one folder each:

| Folder | What it is |
|---|---|
| `BATTLE_ART_VOXEL_FORK` | The 3D voxel world (this repo's `mod/`). |
| `STADIUM2_IMPORTER` | Builds the 3D battle models from your own Stadium 2 ROM or Colosseum disc. |
| `overworld_wild_spawns` | Wild Pokémon walking around the overworld. |

## Install

1. Install gen1recomp and import your own legally owned **Pokémon Emerald** ROM.
2. Unzip `Emerald 3D.zip` and copy the three folders into the game's `mods` folder
   (macOS: `~/Library/Application Support/pokemon-love2d/mods/`).
3. Start the game. Turn the mod on in the launcher's mods tab if it is not on already.

### 3D battle models (optional, your own files)

Battles work out of the box with 2D sprites. For 3D models:

1. **Pokémon #1-251:** when the game asks, give it your own **Pokémon Stadium 2 (USA)** ROM.
2. **Pokémon #252-386 (Hoenn):** make them from your own **Pokémon Colosseum (USA)** disc image
   (`.iso`, `.gcm` or Dolphin `.ciso`; for `.rvz`/`.nkit` use Dolphin's *Convert File* to an ISO first).
   Run `mods/STADIUM2_IMPORTER/hoenn/Make Hoenn models.command` (needs Python 3), or
   `python3 make_hoenn_models.py "<disc image>"` in that folder. It takes about two minutes and needs no extra downloads.
   Start the game again afterwards.

**No ROMs, game data or Nintendo models are included or ever will be.** The models and maps come from files you supply.
This is an independent fan project, not affiliated with Nintendo, Game Freak or The Pokémon Company.

## Known rough edges (alpha)

- Not every map has been looked at from every angle; expect odd edges on some cliffs, coasts and caves.
- A few Pokémon models have small faults (for example Pineco's eye).
- The first visit to a new region can stutter for a moment while layouts load.
- Tested on macOS only so far.

## Credits and licence

Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC (https://github.com/bryanthaboi/gen1recomp).

The code in this repository is released under the [MIT licence](LICENSE). The overworld sprite art in `overworld-wild-spawns/assets/`
is third-party art and stays under its own terms. Other third-party notes are in `mod/THIRD_PARTY_NOTICES.md`,
`overworld-wild-spawns/THIRD_PARTY_NOTICES.md` and `stadium2-importer/hoenn/addon/`.

## Repository layout

| Folder | What |
|---|---|
| `mod/` | The voxel mod, installed in the game as `BATTLE_ART_VOXEL_FORK` (`lib/` Lua code, `data/` generated tables, `tests/`). |
| `stadium2-importer/` | Builds the 3D battle models from your own Stadium 2 ROM. ROMs are never stored in git (`baseroms/` is ignored). |
| `overworld-wild-spawns/` | Wild Pokémon walking the overworld. |
| `tools/` | Install script, QA capture scripts and drivers, height-map and tile-rule generators. |
| `docs/` | Design rules and lessons (`docs/knowledge/`), and the hand-drawn height maps (`docs/elevation/`). |

## Working on the mod

You need a gen1recomp checkout next to the repo (or a path to one) and your own ROMs; see [CONTRIBUTING.md](CONTRIBUTING.md).

1. Edit `mod/lib/*.lua`.
2. Run the tests: `cd mod && tools/run_tests.sh <path-to-gen1recomp>`.
3. Look at the result in a private copy of the game, without touching your real install:
   `tools/qa_tryp.sh "Gen3Blocks.lua" /tmp/shots "{'EM_RUSTBORO_CITY',20,30}" 4`.
   The last line of `/tmp/shots/run.log` must say `fallback 0` (no map fell back to 2D).
4. Install into your game with `tools/install.sh` (close the game first; `--check` only compares).
