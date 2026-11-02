# Hand-drawn elevation pins

The rules below are mirrored with ids in `docs/knowledge/rules.md` (R-10..R-14 heights and reading, R-01..R-06 world shape); that file is the index and gets every new correction first (`tools/knowledge/learn.py`).

`draw/<MAP>.png`: gridded 2D sheets (48 px per cell, coordinates every 5 cells) that the user draws heights on, in place
(gitignored images). `pins/<MAP>.txt`: Claude's reading of those marks, `x y height`, one line per mark; `_read.png`
beside it shows the reading for the user's check. Tools: `tools/elevation/draw_pack.py`, `overlay_pins.py`.

## Convention (user, 2026-10-27)
- Heights are in COURSES (1 course = 16 px = one rock step).
- Heights are RELATIVE TO THE MAP: each map's own ground is 0. They are NOT absolute against sea level.
  Stitching connected maps therefore needs ONE OFFSET PER MAP, derived from the border cells where maps connect
  (the two frames must agree on the seam). Maps with sea get their offset from "water = 0".
- Water is always 0 in its map. Exception seen in Ever Grande: the pool above a waterfall carries its own number (8);
  the waterfall's foot is 0.
- One number per flat area or rock top; slopes between two numbers are interpolated; the drawn cliff art between them
  is the slope, however many bands it shows (the 2D art is inconsistent about course counts, the pins win).
- WATERFALLS go straight up, 90 degrees, never on a slant (user 2026-10-27): the fall is a vertical face from the
  upper pool's level to the foot's level, the water tiles of the fall are that vertical sheet, not a ramp.
- ROCK TOPS ARE FLAT (user 2026-10-27): "the tops of all those rocks are flat! so its really built like plateaus stacked on
  top of each other." A numbered rock is a flat-topped block at its number; its sides are faces. No rounded, ridged,
  lathed or spiky rock tops on a pinned map. NOT A CUBE (user 2026-10-27): the faces are slightly slanted, about 5 percent
  off vertical (the top is a little narrower than the foot), and the top edge is slightly rounded (a small fillet where
  the face meets the flat top); the top itself stays flat.
- BRIDGES (user 2026-10-27): a number on a bridge is the DECK's height. The area UNDER a bridge is water and stands at
  the same height as the water around it (0); the deck spans over it, flat from bank to bank, with no dip at either end.
- RIDGES ARE SLOPES (user 2026-10-27, Safari Zone Southeast with yellow arrows): the dark brown band tiles are RIDGES that span
  from one side of the tile to the other in three dimensions: a slope of about 40-45 degrees that climbs across the whole tile from
  the lower plateau to the upper plateau. They never go up at 90 degrees. The arrow on the sheet points up the ridge. This replaces
  "band flat at the lower plateau with a wall at its upper edge": the band IS the ramp between the two plateaus.
  CLARIFIED (user 2026-10-27, Route 114 panel): the band's rows on the sheet are the slope's FOOTPRINT; the slope climbs
  across them toward the upper plateau (northward for a south-facing band, sideways for a vertical band), so the ground moves
  up AND over, "an angle and not a straight upward thing". A multi-row band is one ramp over all its rows; keep the angle near
  40-45 degrees and let the footprint, not the steepness, absorb a bigger rise (knob for the builder, judged on low-cam shots).
  WEDGES STACK (user 2026-10-27, cube-with-diagonal sketch + Safari Zone North arrows): each band tile is a WEDGE, the cube cut by
  its diagonal from the bottom of its lower side to the top of its upper side (one tile = one course of rise at 45 degrees).
  Consecutive band tiles in the climb direction STACK: the next wedge starts where the previous one ends, so N band rows make
  one continuous slant N courses high. Where the pins ask for a different rise than the rows give, keep the continuous diagonal
  and scale it (builder knob, judged on low-cam + ortho).
- NEVER ON GRASS OR SAND (user 2026-10-28): "there are never 45 degree ridges or plateau differences on grass or sand! never.
  only rock ledges or stairs do that." Grass and sand are always flat. A level change between two plateaus happens ONLY through
  a rock ledge (the band tiles = ridges, or a rock face) or a stair run. So: no sloped grass or sand anywhere (no ramp pass on
  plain ground, option A of 2026-10-28 is cancelled), and a "bare drop" in the pins (grass next to lower grass with no band tile)
  is never a grass riser: the step there is a rock ledge (face with the ~5 percent lean and rounded top edge), or the pins are wrong.
  STAIRS TOO (user 2026-10-28: "stairs also adhere to the 45 degree principle"): a stair run is the same wedge as a band
  tile, one course of rise per tile at about 45 degrees, consecutive stair tiles stacking into one continuous slant; never a
  vertical step and never flat with a riser at one end.
- UNNUMBERED ROCK = A FACE, NOT A MASS (user 2026-10-27, Route 119 weather station): a cliff band with no number on it
  is where the rock moves up or down vertically (slightly slanted) between the two numbered plateaus beside it: its top
  is the upper plateau's level, its foot the lower one's. It never stands as its own tall rock above the plateaus.
  Only a rock with a number on it is a mass, and that number is its top.
- Numbers mark the GROUND height, never a tree or prop standing on it (a number under a tree = the ground there).
- A number tagged `top` is the top of a rock / ledge mass, not a walkable plateau (Mt Pyre (21,7): ledge tops one
  course above the 20 path, like the big rocks).
- `^ up` = an arrow the user drew (stairs / ramp going up).
- A comma between two digits is a DECIMAL (`0,5` = 0.5, as for the Pacifidlog platforms); it is one mark, not two numbers.
- A number with a diagonal stroke through it: a 2 struck by a diagonal is a 7. A loop / scribbled circle is always 0.
- A 0.5 platform sits just above the water/ground it stands in (Route 121 (31,16): a hair above the sea, not a half-step of its own surroundings).

## Course height: DECIDED 16 px (user 2026-10-27: "if a tile is 16x16px lets do 16px height as well")
One course = 16 px everywhere (`Gen3Elevation.PIN_PX`, `Gen3Rock.COURSE`).

## How the pins are used
Gen3Elevation floods each pin over its connected flat area (same GBA level, stopped by stairs, ledges and rock);
on a pinned map Gen3Blocks builds the rock between the areas. Gen3Relief (counted relief) is gone since 2026-11-02.
Caves and indoor maps with a drawn height map (`draw/claude_heightmaps`, baked by `tools/heightmaps.py` into
`mod/data/gen3_heightmaps.lua`) skip the flood: every floor cell takes its drawn height, and every ramp tile is a 45-degree wedge
rising toward its arrow (R-48).
