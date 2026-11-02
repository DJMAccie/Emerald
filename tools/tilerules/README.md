# Tegelregels

Scripts die Emerald-metatiles indelen op hun eigenschappen (gedrag, kaartvorm, kleur) in plaats van met de hand.
De uitkomst is een gegenereerde Lua-tabel in de mod; pas de regel aan en draai het script opnieuw, nooit de tabel.

| Script | Regel | Schrijft |
|---|---|---|
| `emerald_tables.py` | dak/muur via deur-blobs, klif/rots/struik via kleur, binnenmuren/props; stemmen per tilesetpaar | `mod/data/gen3_emerald_auto.lua` |
| `water_edge.py` | watertegel met oever erin -> gewone watertegel met hetzelfde gedrag | `mod/data/gen3_water_edge.lua` |

Draaien vanuit de repo-root: `python3 tools/tilerules/emerald_tables.py` (en `water_edge.py`). Controle: de uitkomst
hoort getal voor getal gelijk te blijven tenzij je de regel bewust verandert (`git diff mod/`).

Invoer `input/` (107 MB, ROM-afgeleid, staat in .gitignore, nooit committen): `world.json` (alle 518 kaarten: cellen,
tilesetpaar, kaarttype + gedrag per metatile per paar) en `atlases/<paar>/` (meta.json, ids.txt, atlas_u/o.rgba).
Gekopieerd uit de oude werkmap (Prullenmand Emerald-opruimen-2026-11-02/archief/gen1recomp-modwork). Kwijt? Haal die
map uit de Prullenmand of uit een back-up; het oude exportscript is niet bewaard.
