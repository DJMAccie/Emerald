# Emerald 3D

Pokémon Emerald, rebuilt as a 3D voxel world. A mod for gen1recomp (the Gen 1-3 native recompilation engine).
You walk the same Hoenn, but the maps stand up in three dimensions, with a camera you can turn.

**Status: alpha 0.1.0.** The overworld is the finished part. Battles with 3D Stadium 2 models are still being built.
Project page: <https://petyabouianov.com/emerald-voxel>

## What it does

- **Voxel overworld.** Routes, towns, buildings, caves and interiors are built from Emerald's own tiles, block by block. Heights come
  from height maps checked tile by tile (165 maps), so cliffs, stairs and caves are drawn from the art, not guessed.
- **Free camera.** Several camera levels, from the classic overview to a close orbit and first person.
- **Pokémon in the overworld.** Wild Pokémon walk the routes (`overworld_wild_spawns`), and your lead Pokémon follows you.
- **Day and night.** The sky follows your computer's clock: sun, moon, and street lamps that come on after dark.
- **Cinematic Fly.** HM Fly lifts into an aerial camera over the whole region.
- **No border flash.** Neighbouring maps are built before you reach the edge.
- **3D battles (unfinished).** Stadium 2 models for #1-251 are imported from your own ROM; the Colosseum set (#252-386) is in progress.

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

For 3D battles you also need your own **Stadium 2** ROM and/or **Pokémon Colosseum** disc.

**No ROMs, game data or Nintendo models are included or ever will be.** Everything the mod shows comes from files you supply.
This is an independent fan project, not affiliated with Nintendo, Game Freak or The Pokémon Company.

## Known rough edges (alpha)

- Not every map has been looked at from every angle; expect odd edges on some cliffs, coasts and caves.
- 3D battles are unfinished, so the 2D Emerald battle still runs for anything without a model.
- The first visit to a new region can stutter for a moment while layouts load.
- Tested on macOS only so far.

## Credits

Built on the Pokémon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC. See `mod/THIRD_PARTY_NOTICES.md` and
`overworld-wild-spawns/THIRD_PARTY_ASSETS.md` for everything else. Licence: not chosen yet.

---

## Development notes (Dutch)

Pokémon Emerald in gen1recomp met een 3D-voxelwereld, Pokémon in de overworld, een volger en 3D-gevechten
(Stadium 2-modellen). Alle code is van Petya.

## Wat staat waar

| Map | Wat |
|---|---|
| `mod/` | **De mod.** Hoort bij deze repo. Wordt in het spel geïnstalleerd als `BATTLE_ART_VOXEL_FORK`. |
| `stadium2-importer/` | Tweede mod: haalt de 3D-Pokémonmodellen voor gevechten uit de Stadium 2-ROM. Hoort bij deze repo (ROM's nooit in git: `baseroms/` is genegeerd). |
| `gen1recomp/` | De spelengine (alleen naslag; de testscripts starten vanuit deze map). |
| `tools/` | `install.sh` (installeren), `qa_tryp.sh` (testfoto's), `qa_battle.sh` (gevechtstest), `drivers/` (views, battle, fly, ortho), `ortho45/` (rotsen naast de 2D-art), `knowledge/learn.py`, `crop.py`, `sheet.py`, `colosseum/` (Colosseum-modellen #252-386 maken, zie de README daar), `tilerules/` (tegelregels die de tegeltabellen van de mod genereren). |
| `docs/knowledge/` | Regels, lessen en het dagboek. |
| `archief/` | Alleen de oude losse git-geschiedenis van mod/ en stadium2-importer (oude hashes in PLAN.md: `git --git-dir=archief/mod-git-2026-11-02 show <hash>`). Alleen lokaal. Al het andere oude werk staat sinds 2026-11-02 in de Prullenmand (Emerald-opruimen-2026-11-02). |

## Het spel

- Echte spelmap: `~/Library/Application Support/pokemon-love2d` (niets aanraken terwijl het spel draait).
- Testkopie: `~/Library/Application Support/pokemon-love2d-rseqa`.
- Mods die aan staan voor Emerald: `BATTLE_ART_VOXEL_FORK` (deze mod), `STADIUM2_IMPORTER`, `overworld_wild_spawns`
  (Pokémon in de overworld, geen gras-encounters), `wild_skies` (vogels), `animated_menu_pokemon`.

## Werken aan de mod

1. Pas `mod/lib/*.lua` aan.
2. Test zonder het echte spel te raken (eigen testkopie, draait op de achtergrond):
   `tools/qa_tryp.sh "Bestand1.lua Bestand2.lua" /tmp/test "{'EM_RUSTBORO_CITY',20,30},{'EM_ROUTE116',30,10}" 4`
   Kijk in `/tmp/test/run.log`: de laatste regel moet `fallback 0` zeggen.
3. Leg vast (`git commit` in deze repo), sluit het spel en installeer: `tools/install.sh`. Push `main` naar `origin` (DJMAccie/Emerald, privé).
   `tools/install.sh --check` laat zien of spel en testkopie gelijk zijn aan de bron.

Gevechten testen: `tools/qa_battle.sh /tmp/gevecht 252 270` (speler- en tegenstander-nummer uit de Pokédex).
