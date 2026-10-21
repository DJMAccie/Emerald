# Measuring the original tiles instead of guessing recipe constants

The recipe method (`tools/buildings/hf.py` + `hf_recipes.py`) builds a building as a plan volume whose faces sample a rect of
the ORIGINAL drawing: the wall colour, the facade's repeat, the window recesses, the pilaster columns, the door porch. Those
numbers are currently hand-measured per building (e.g. `_sky_pillar`: `mat=(40,20)`, `repeat=32`, `recess` at x18..30 / 50..62,
`corner=(0,8)`, porch 30..50). A wrong constant is only visible in the rendered comparison, and every new building repeats the
guesswork.

`tools/buildings/measure.py` measures them instead:

```
python3 tools/buildings/measure.py <pair> <map> x0 y0 x1 y1 [--json out.json]
```

It composes the drawing exactly as the baker does (`bldmodel.compose`: under layer, then the over layer) and reports:
- **wall colour** and where to sample it in the drawing (`mat=(x,y)` for the recipe) and its share of the rect;
- **period**: the facade's vertical repeat, searched in whole tiles by correlating the per-row "not wall" mask;
- **window columns** (runs of "not wall" that carry the glass colour) and **trim columns** (the other runs: pilaster edges,
  quoins) - these map onto the recipe's `recess` and its `_proud`/`corner` art;
- **window rows** inside one period, the **glass colour** and its sample position;
- the **paving band** (where the bottom of the drawing stops being wall) and the **door opening** (the only not-wall run in
  the strip just above the paving - the door's colours are usually the palette's own, so it is found by shape, not colour);
- the **mirror cost** of the drawing (0 = perfectly symmetric), which says whether a symmetric plan is honest.

## It refuses drawings that are not a single facade

Most recipe `src` rects are SCENES, not facades: a building over water, foliage or sky, or several walls of different
colours. For those, a single wall colour is a small share of the pixels and facade numbers would be meaningless. The tool
reports `MIXED DRAWING` with the colour composition and stops. Measured on the existing recipes' rects:

| rect | largest colour share | verdict |
|---|---:|---|
| Sky Pillar tower (`general__pacifidlog` EM_SKY_PILLAR_OUTSIDE 12,0..16,5) | **67 %** | a clean facade - fully measured |
| Trainer Hill roof (`building__trainer_hill` 7,0..17,6) | 29 % | mixed |
| Mossdeep tower (`general__mossdeep` 60,2..68,15) | 18 % | mixed |
| Route 119 treehouse (`general__fortree` 1,26..11,32) | 22 % | mixed |
| Route 108 ship (`general__slateport` 27,3..33,5) | 33 % | mixed |

So the next step for those four is a REGION step (find the wall area inside the drawing first), not a better facade
measurement. That is the honest split: measure facades now; segment scenes later.

## Sky Pillar: measured vs the recipe's hand constants

`measure.py general__pacifidlog EM_SKY_PILLAR_OUTSIDE 12 0 16 5` (80 x 96 px, 5 x 6 cells):

| property | measured | `_sky_pillar` recipe | verdict |
|---|---|---|---|
| wall colour | (123, 99, 90), 67 % of the rect, sample at (2,0) | `mat=(40,20)` | both are wall pixels; same colour |
| facade period | **32 px** (correlation 0.68; 16 px scores 0.45) | `repeat=32` | correct |
| window columns | 18..29 and 50..61 | `recess` 18..30 and 50..62 | correct to within the 1-px frame |
| window rows in one period | 1..7 | rows `1+32j .. 8+32j` | correct to within the 1-px frame |
| glass colour | (41, 49, 90), sample at (19,1) | (not encoded) | available now if a glass tint is wanted |
| pilaster / trim columns | 0..2 and 77..79 (the outer edge only) | `corner=(0,8)`, `_proud` at 0..8 / 72..80 | the recipe treats 8 px as proud where only ~3 px carries art; the rest is flat wall |
| door opening | 36..43 (rows 74..83) | porch prism 30..50 rows 72..96 | the opening sits centred in the recipe's porch |
| paving band | bottom 8 rows (from row 88) | not encoded | the bake paints the bottom rows with wall; the drawing has paving there |
| mirror cost | 0.2 (symmetric) | symmetric plan | honest |

Conclusion: the Sky Pillar tower's hand constants are right, and only two small things were worth knowing - the pilasters
carry art for 3 px, not 8, and the bottom 8 rows are paving, not wall. Both are now measured rather than assumed.

## Limits (state them, do not paper over them)
- A facade measurement cannot tell DEPTH, the crown, a porch's projection, or which parts should be proud: those stay a
  design decision (see `_sky_pillar`'s `crown`, `depth`, `_proud`).
- The period search works on a clean facade; on a mixed scene it will happily report a tile-sized "period" that means
  nothing, which is why the facade check runs first.
- Two walls of different colours in one rect read as "mixed", not as two facades.
- The door is found by shape in the strip above the paving; a building whose door is not the only feature there (a sign, a
  step, a planter) will need the strip chosen by hand.
