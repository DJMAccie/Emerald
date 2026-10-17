# tools/relief - Emerald 3DS's relief method as an offline A/B prototype

Stage 2 of the terrain plan: try Emerald 3DS's way of building rock on our
maps, offline, so the user can choose per rock class before anything goes
into the mod. Nothing here touches the mod or the game. See `NOTICE.md` for
the MIT licence of the ported method.

## Files

| File | What it does |
|---|---|
| `emdata.py` | Reads a map from the QA cache (grid, collision, behaviours, events, tile art through `tools/analysis/layers.py`), the roles 3DS reads (water, ledge, stair, floor, signpost, wall, tree, fence, cliff, shelf) and the alias reading of Fallarbor/Lavaridge tiles as the General rock they redraw. |
| `terraces.py` | The port: tile tables, pixel classes, cell kinds, runs of rock, union-find terraces and the level vote, rock levels, settling, pieces (`blocks`, `piece_grid`), staircases, level bands, unstand, behind-trees, ledge berms. Writes `<Map>.json` with a 5x5 lattice of heights (px) per cell. |
| `render.py` | Renders a JSON at the game's camera (level 4 and 7, perspective, 1280x720): each texel at (u, h, v + h), cliff walls in the face tile, our soft-tops variant. |
| `proof.py` | The counted pieces (kind + level) written over the map drawing - the first thing to look at when a render looks wrong. |
| `ab.py` | Renders every A/B case and composes one sheet per map group beside our in-game captures. |

## Run

```bash
cd ~/Documents/Emerald/tools/relief
python3 terraces.py Route111 Route114 Route112 MtChimney FallarborTown --out OUT/relief
python3 render.py OUT/relief/Route111.json 32 128 4 r111.png --variant soft
python3 proof.py OUT/relief/Route111.json 20 110 39 139 proof.png 3
QA_ZOOM=-2 ../furniture/shot.sh OUT/ours "<cases from ab.py CASES>" "4,7" 0 60
python3 ab.py OUT/relief OUT/ours OUT/ab
```

## What the prototype covers

- The level counting for the General mountain as 3DS does it (Route 111 is
  their reference case), and the same counting on recoloured General rock read
  through the alias (Route 114's beige mountain, the red Lavaridge rock of
  Route 112 and Mt. Chimney).
- Pieces F / S / W / E / W2 / E2 / corner pieces, the lattice, crease splits,
  cliff walls, ledge berms, waterfalls as faces.
- A "soft" variant: theirs with 3 px rounded shoulders and rock tops rolling up
  to 4 px (any height keeps the 45-degree drawing).
- A "tall" mock-up (`--variant tall`): the counted relief 1.5x taller with soft,
  rolling tops - the hybrid the user chose on 2026-10-17 for the pink General
  and beige mountains (ours kept for the brown terrace and the red rock). The
  mock-up stretches faces; a real build must repeat their rows.

## What it does not cover (differences from 3DS, all deliberate for a prototype)

- One map at a time. 3DS solves maps drawn across a seam on one canvas and
  lifts each block to its world solve (seam anchors, `reference`); here each
  block's biggest ground is level 0, so heights across a seam are not matched.
- No cut tiles (3DS cuts the ground a rock tile draws round its rock out of
  the lifted texture) and no `records` flags; terrace backs are closed with
  the ground behind's own last row instead of 3DS's fill records.
- No props (voxel_props) and no tree/house models: trees stand as flat cards
  of their top layer, houses lie flat. Signposts come from sign events only.
- Walls repeat the face tile a level at a time (3DS stretches a taller wall)
  and each cell takes the nearest drawn face (3DS: one face per map).
- Fallarbor's brown terrace (0x268-0x27A) is not in 3DS's tables at all; it is
  read here as General faces/ends/bands (`OWN_TWINS`, ours) so it is counted.
- 3DS itself does not run this counting on Route 112's red mountain (its
  comment: "not yet") and solves Mt. Chimney with an older region method; the
  red-rock renders are the counting forced onto them.
- Outside the map is a grey table, not the game's boundary fill.
