# Emerald 3D

Pokémon Emerald in gen1recomp met een 3D-voxelwereld, Pokémon in de overworld, een volger en 3D-gevechten
(Stadium 2-modellen). Alle code is van Petya.

## Wat staat waar

| Map | Wat |
|---|---|
| `mod/` | **De mod.** Hoort bij deze repo. Wordt in het spel geïnstalleerd als `BATTLE_ART_VOXEL_FORK`. |
| `stadium2-importer/` | Tweede mod: haalt de 3D-Pokémonmodellen voor gevechten uit de Stadium 2-ROM. Hoort bij deze repo (ROM's nooit in git: `baseroms/` is genegeerd). |
| `gen1recomp/` | De spelengine (alleen naslag; de testscripts starten vanuit deze map). |
| `tools/` | `install.sh` (installeren), `qa_tryp.sh` (testfoto's), `qa_battle.sh` (gevechtstest), `drivers/` (views, battle, fly, ortho), `ortho45/` (rotsen naast de 2D-art), `knowledge/learn.py`, `crop.py`, `sheet.py`. |
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
