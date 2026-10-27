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
- `^ up` = an arrow the user drew (stairs / ramp going up).

## How the pins are used (planned)
Per-map anchor tables that override the counted relief (Gen3Relief / Gen3Hills / Gen3Rock heights) at the pinned
areas, with the pinned cells' flood regions taking the pin and the gates comparing the built heights against the pins
cell by cell. Not built yet; see PLAN.md.
