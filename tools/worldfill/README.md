# World fill (task 34): Hoenn with no gaps under a Fly flight

User 2026-10-27: "an important thing about flying over is that we dont have gaps in the overworld and that you see
the entire map filled in". The maps the cartridge connects leave large holes between them (black on a stitched world
map). The fill closes them with the game's own metatiles, traced cell by cell from a filled-in region map the user
supplied (darkshadedx's full Emerald map, `~/Downloads/hoenn_pokemon_emerald_full_region_map_by_darkshadedx_dd636ie.png`).

The reference and everything traced from it stay out of git. `ref/` is ignored here, and `assets/worldfill/` is
ignored in the mod.

## Pipeline (offline, Python + numpy/Pillow/scipy)
1. `world.py`: the world layout from the map headers' connections (pret rules), with Littleroot at (0,0). It holds 49
   maps over 800x383 cells and is shared by the other tools.
2. `register.py`: finds where that layout sits in the reference. The reference is 16 px per cell, and the world's
   top-left cell is at reference pixel (128,352), on the grid. It writes `ref/register.json`.
3. `census.py`: classifies every reference cell outside the maps against the quantized looks of all 75 pairs. 98%
   are exact metatiles: sea 0x170, trees in the 0x1D4 block, pink rock from Fallarbor/Lavaridge.
4. `isolated.py`: finds the maps no connection reaches in the reference by exact tiles: Battle Frontier West/East and
   Sky Pillar outside. It writes `ref/isolated.json`.
5. `make_fill.py`: the fill. For each gap cell it picks the (pair, metatile) with the same look:
   - primary tiles get the nearest map's pair;
   - patches the artist pasted off the grid are matched at their own pixel shift;
   - blue blocks that match nothing are sea;
   - the last few take the nearest look.
   It writes `assets/worldfill/fill.bin` and `placements.lua` in the mod (format in its docstring).
6. `render_check.py`: the gate. It rebuilds the world from our maps plus the fill and compares it with the reference:
   - fill: 97.6% pixel-exact, 99.96% the same kind of ground;
   - maps: 92.9%. The misses are the artist's older copies and Mirage Island.
   It writes `ref/check.png`.

## Runtime
`lib/Gen3FlyGround.lua`:
- It lays every outdoor map plus the fill in 64-cell chunks, one mesh per chunk and pair, nearest the rider first. The
  meshes are kept for the session.
- The open sea is a plane textured with the live 0x170 tile.

`lib/Gen3FlyOver.lua` drives it, and keeps its own task 29 carpet as the fallback when the fill is missing.

## QA and install
- `qa_flights.sh <outroot> "long:frontier sea mountain iso"`: private QA flights. Each one gets the straight-down
  overview shot (`EM_FLY_TOPDOWN`), and `long:frontier` adds a second flight over the laid world.
- `flatcheck.py <root>`: the share of flat, textureless blocks per mid-air shot.
- `sheet.py`: the before/after sheet.
- `install_ground.sh`: installs into the game and main QA (refuses while the real game runs).
