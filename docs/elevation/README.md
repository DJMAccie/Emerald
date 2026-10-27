# Hand-drawn elevation pins

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
One course = 16 px everywhere; no A/B needed. Gen3Relief.LEVEL=24 must come down to 16 so the counted-relief maps match.

### Background (why it was asked)
The user suspects heights are exaggerated: a course drawn 16 px tall built 16 px high on 16 px tiles gives cubes.
Today the builders disagree: `Gen3Rock.COURSE=16`, `Gen3Elevation.COURSE=16`, but `Gen3Relief.LEVEL=24` (its own
comment says the 3DS port uses 16), so counted-relief maps already stand 1.5x taller than the rest. The pin builder
takes ONE constant `COURSE_PX` for the whole world; phase 1 shows the user an A/B at 12 / 16 / 24 px per course on a
pinned map (Jagged Pass or Mt Pyre, play camera + low camera, player sprite in frame for scale) and the user picks.

## How the pins are used (planned)
Per-map anchor tables that override the counted relief (Gen3Relief / Gen3Hills / Gen3Rock heights) at the pinned
areas, with the pinned cells' flood regions taking the pin and the gates comparing the built heights against the pins
cell by cell. Not built yet; see PLAN.md.
