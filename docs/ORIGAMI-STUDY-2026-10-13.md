# What Origami Ascendant does that we don't (2026-10-13)

Roxas2712/origami-ascendant v1.0.0: a Lua mod for the same engine (gen1recomp),
FireRed/LeafGreen/Emerald, paper-diorama look. **Proprietary licence: ideas
only, re-implement, copy no code or assets.** Read from source by two read-only
agents; nothing of theirs was run. Their file references are relative to
`gen3/` in their repo, ours to `battle-art-notquiteog/lib/`.

## 1. Cold-map hitch

Ours: the sliced builder (2 ms, `SceneStream.lua:21-34`) is skipped when there
is no active scene or the context changed (`SceneStream.lua:26,34`), so a warp
runs the whole build in one resume. Shaders compile on first use
(`Voxel3D.lua:721-735,1222-1224`). No neighbour prefetch on the Gen 3 path.
No phase timings are recorded (only `maxSlice`, `SceneStream.lua:38`).

Theirs: every build is one coroutine job resumed with 2 ms per tick, with a
stamp-and-retry when the layout changes mid-build; while pending the renderer
shows the last finished frame under a fold animation and input holds. The
nearest warp/connection destination (within 8 cells) is prepared ahead, one
map per frame. Scene, shadow and fog shaders are compiled at mod load. Their
on-disk geometry cache covers FireRed only; Emerald builds live there too.

Gaps, by payoff:
1. Slice the cold build and hold the last frame (or the 2D view) while it is
   pending: `SceneStream.lua`, `Gen3Scene.lua` prepare (~1845), `Gen3Integration.lua:73-80`.
   About 50-100 lines, plus a stamp-and-retry because build reads live map state.
2. Prebuild the nearest warp/connection destination: a small keyed LRU in
   SceneStream; `request`/`build` assume the current map (`Gen3Scene.lua:266-274`).
3. Warm the Voxel3D shaders at install (10-20 lines; benefit unmeasured).

Not verified: whether walking across a map connection changes our context key
(if so, every route border is a cold build); most of `build` (712-1760) was not
read for unsliced phases. Measure before designing 1.

## 2. Battle placement (Gen 3 path, `Gen3Battle.lua`)

Ours: centre = best of 11x11 cells by walkable count in a 7x7 window
(`:46-59`); heading = best of 4 cardinals (`:35-45`); actors at -18/+26 along
it (`:137`); camera pulled back until model boxes clear left, right and top
(`:126,:216`); always stages, falling back to the player's cell (`:47`).

Theirs: 3 scales x 5 formation angles x 19x19 offsets = 5,415 candidates,
sorted once by distance^2 + 2*|angle| + 50*(1-scale); the first to pass wins:
- feet: every actor (trainers too) sampled at centre +-8 px: in bounds,
  walkable, on the encounter's floor height, scenery at most 2 above the floor;
- sightlines: rays across the full body width from foot to eye fail on any
  scenery above the ray;
- HUD: camera pushed back/recentred until all actor boxes sit inside the free
  part of the screen (not under the stat or text boxes);
- actor screen rectangles must not overlap;
- none fits: shrink actors and retry, then refuse and draw the native battle.

What we lack, most visible first: sightlines (a mon hidden behind a house or
tree; our cut-away is off, `Gen3Scene.lua:2173,2287,2314`), per-actor feet
(only the centre cell is tested, `:50`), a bottom/HUD margin, a refusal path,
actor overlap.

## 3. Tile meaning

Theirs is mostly hand-listed (134 landmark rectangles over 43 maps, coordinate
keyed profiles, 177 Emerald-named modules), buildings are boxes with one folded
front image, and nothing checks the result against the 2D art. Ours is stronger
here. Two rules worth re-implementing:
- door-anchored flood: from each warp, the cell north of the door must be solid
  architecture; scan the facade row for left/right limits, flood through
  same-family solid cells, accept if the bottom row is the door row. It keeps
  touching buildings apart, which our overlap merge (`Gen3TileShape.lua:347-374`) can fuse;
- cave terraces from stair connectivity (theirs gated to 16 maps).
