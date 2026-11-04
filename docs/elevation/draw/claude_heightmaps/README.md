# Emerald height maps (source)

One `NAME.json` per map, 197 in total; `../_same.txt` lists the 14 maps that reuse another map's grid.
`python3 tools/heightmaps.py` bakes them into `mod/data/gen3_heightmaps.lua`; `--check` also validates every grid, coverage, aliases
and `user_marks`, and fails if the Lua is stale. The script converts only, it repairs nothing: fix a height in the JSON itself.

- 165 maps carry `"reviewed": true`: every cave/indoor map and every overworld map with a screenshot in `draw/`, checked tile by tile
  against the screenshot and Petya's ink (2026-11-03, including his correction round, rule R-52).
- 32 maps without a screenshot (Abandoned Ship, Underwater, New Mauville, Southern Island Interior, Sky Pillar Top, Route 125,
  Aqua Hideout Map3, Route 104 Prototype) carry `"generator"`: generated grids, not yet seen by Petya.

## Units
Grid = metatiles (16 GBA px), (0,0) top-left. 1 height unit = 1 tile = 16 GBA px; the view is ~45° oblique, so a cliff face drawn over
N tiles is N units, built as 45° ramps. Caves: floor 0; Magma Hideout, Mirage Tower, Sky Pillar 1F-5F: floor 1. Overworld: ground and
sea 0 unless Petya wrote otherwise (half heights like 0.5 / 1.5 are his).

## Fields
- `type[y][x]`: `flat`, `water`, `object` (prop standing on ground at that height), `ramp`, `stairs`, `waterfall`, `wall`, `void`.
- `height_map[y][x]`: height (ramps: tile centre); null for wall/void.
- `ramp[y][x]`: `[low, high, up]` for ramp/stairs/waterfall, `up` = N/S/E/W or a corner NE/NW/SE/SW; else null.
- `source[y][x]`: how the value was set (`checked`, `mark`, `mark-split`; generated maps also `mark-region`, `ramp-neighbours`, ...).
- `user_marks`: `[x, y, h]` tiles with Petya's own numbers; `--check` fails if one changes.

## Things the 3D builder must know
- North faces are invisible in the GBA view: where a raised area only shows a thin lip on its north side, the grid jumps from low to high.
- Bridges (Victory Road, Shoal Cave, Meteor Falls, Safari South walkways, Mauville cycling road) are flat at deck height; the floor under
  them is not in the grid.
- Jump ledges are flat tiles; Petya usually gave both sides the same height.
- Small rocks are pyramids: corner ramps rising to a peak (usually 1).
- Shoal Cave low tide has heights below the water level; dry maps below 0 are lifted to 0 by the bake.
