# Props and natural materials audit (2026-10-05)

Scope: everything that is not a building: signs, fences, flowers, shrubs, awnings, boardwalks,
rocks, cliffs, sea boulders, generic objects. Buildings are Opus's (`docs/BUILDINGS-REBUILD.md`).

## Method (repeatable)
```
cd ~/Documents/gen1recomp && luajit ~/Documents/Emerald/tools/props/catalogue_props.lua | tail -n +3 > ~/Documents/Emerald/tools/props/props.tsv
python3 tools/props/audit.py plan sign,fence,shrub,flowers,awning OUT [TOP_N]   # kinds: sign fence shrub flowers awning ledge grass cliff caveWall tree ladder steps OBJECT
EM_WAIT=60 tools/props/audit_capture.sh OUT      # QA identity, player camera; waits for a real game to exit
python3 tools/props/audit.py sheet OUT           # OUT/sheet_NN.png: source art (cell outlined) | game
```
- `catalogue_props.lua` lists every (tileset pair, metatile) that the mod turns into a prop kind, with
  counts and an example cell. `OBJECT` = blocked, unclassified: input of the generic cutter (`Gen3Objects`).
- Long maps (Route 119) need `EM_WAIT=100+` or the shot is blank sky.
- `pgrep -f "MacOS/love"` matches any shell whose command line contains the text, so two waiting
  scripts can block each other forever. Use `pgrep -f "[M]acOS/love \."`.

## Fixed and installed (real game, backups in gen1recomp-modwork/backups/2026-10-05-*)
| Defect | Cause | Fix |
|---|---|---|
| Signs on paving stood on a green grass patch (Rustboro, ...) | sign ground defaulted to grass | `Gen3Outdoor.groundProps`: sign/awning take the ground of the walkable cells around them |
| Plain grass (metatile 0x002) drew grass-coloured sign boxes (Birth Island, Route 114, Fortree, Lilycove ...) | `Gen3TileShape.of` returned a sign for `mid==2` on every cart; only FRLG numbering has that | gated to `firlg` |
| Route 119 / Safari Zone white boardwalks drew brown stakes | RAIL behaviours were treated as fences and sampled unrelated fence art (0xE6/0xE7) | RAIL cells now keep their own drawing (`flat`) |
| Slateport flower beds sat on tan plates | flowers/shrub used the tileset floor as ground | ground is plain grass (the tile is drawn on grass) |
| Mountains were smooth domes textured with two FireRed tiles (`G.cliffCap=0xDC`, `G.cliffSide=0xE1`: unrelated art in Emerald) | `Gen3Terrain` dome | **`Gen3Mass.lua`**: a rock mass is rebuilt from its own tiles. The cliff picture is an oblique view (row y = depth - height), so each pixel column is split into a wall (contiguous rock rows from the bottom, 16 at most = one tile of face art) and a top surface (every other rock pixel, flat at the wall's height, shifted south by it). One pixel = one voxel; nothing is stretched. Strips overlap 0.03 to hide hairlines. |
| Petalburg hedges rendered as separate round bushes | hedge tiles used the lone-shrub 'bush' hull | hedge = bounded row hull (front face = the drawing's pixels) |

| Sea stacks / bank rocks stretched and domed, sea boulders flattened to dark chevrons | dome + hue-cut | `Gen3Mass` also builds bank masses and (via `appendObject`) low objects standing in water: wall = lower half of the column, ground/skirt/water plane under them, per-column terrace foot |
| Cave walls 28 units tall from 16-row art | `caveWall` height 28 | `Gen3Terrain.CAVE_FACE=16`: 1:1. A mass rebuild of cave interiors was tried (`Gen3Mass.caves`) and gave stripes: caves do not use the outdoor oblique layout |
| Route 119 bridge: water walls beside the deck | water-art banks | gone with the mass rebuild |

## Open, in priority order
1. Cave walls are 1:1 now but still a dome profile (horizontal run 8). Outdoor cliffs are done (Gen3Mass). Tall sheer walls (stacked pure-face tiles, e.g. Mt. Chimney's inner walls) are
   built only 16 high; extending them through stacked sheer tiles made spikes at hill shoulders
   (see git history of this file / `M.WALLY`, `M.SHEER` in Gen3Mass). `Gen3Mass.enabled=false` restores the dome.
   Banks (`shape.bank`: rocks drawn as repeated texture, sea stacks) still use the dome.
2. **Route 119 (14,34 area): a diagonal hole in the river** (sky shows through water cells beside the rock
   column). Present with Gen3Mass disabled too, so it predates this work.
3. Land boulders/planters/benches (`Gen3Objects.append` scale .5) are still the old hull; only objects in water use Gen3Mass.appendObject.
4. **Slateport market stalls (awning 205, 20D ...):** hip awning drawn as a flat tan board.
5. **Round 'bush'/'rock'/'tree' hulls in `VoxelHull.build(... organic ...)` colour blobs with random palette
   picks.** Not pixel-true; rocks and bushes should use the row-hull path (front = the drawing).
6. Unchecked: ledges (69 kinds), tall grass (22), trees (150), ladders, steps, the rest of the OBJECT list
   (lamp posts look like dark blobs in Rustboro), Route 110 cycling-road barrier colour, Lilycove sign (3 at 34,6).
7. The warm evening grade tints whites pink in captures; compare shapes, not hues, against `grid.py`.
