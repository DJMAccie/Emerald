# Sprite-to-voxel landmark tool — plan and reconnaissance (2026-10-05)

Chosen route (user's pick): build a reusable **sprite-to-voxel tool**, starting with the
Littleroot truck. References the user supplied:
- ss1shadow's Aseprite -> Blender -> engine workflow (model it by hand from the sprite).
- Oroshibu's **Easymetric** Aseprite plug-in (geometry inside the pixel-art tool, `.obj` export).
Rejected as the primary route: MagicaVoxel `.vox` (needs a loader, adds nothing over the two above).

## Why this is needed

Landmarks drawn as tiles (truck, boats, Space Center rocket, Mt. Pyre) currently go through the
generic building extrusion, which is what produces the "huge block". The fix is a real voxel model
per landmark.

## The rendering path — VERIFIED, do not re-derive

- `Voxel3D.newMesh(verts, indices)` builds a mesh. Used by `Backdrop`, `BattleBillboard`,
  `CaveAtmosphere3D`, `NativeTreeArt`.
- `Voxel3D.FORMAT` = VertexPosition(3) + **VertexTexCoord(2)** + **VertexShade(1)**.
  **There is no arbitrary vertex-colour attribute.** `Voxel3D.TREE_FORMAT`'s extra `VertexCanopy(3)`
  is a wind/lean offset (`Voxel3D.lua:122-132`, `205`), NOT RGB.
- Therefore a model face gets its colour one of two ways:
  1. a UV into the **tileset atlas** (as terrain and buildings do via `uvFor`), or
  2. the existing `swatch(ts,u,v)` trick in `Gen3Scene.lua` — a single texel sampled as a flat colour.
  Option 2 is the one for flat-coloured model faces and is already proven in the codebase.
- `Voxel3D.FACE_SHADE` gives the six directional face shades; bake those so a model reads solid.

**Consequence:** ss1shadow's Blender half does not transfer (no mesh importer, no normal mapping).
The "author the shape as voxels" half does.

## How landmarks are drawn today — VERIFIED

Object events are drawn as billboard cards through one function:

```
Gen3Scene.lua:782-789   for _,eo in ipairs(Objects.forDraw()) do
                          local gid=eo.graphicsId or (eo.def and (eo.def.graphicsId or eo.def.graphics))
                          ... actor(gid, px, py, facing, ...)
```
`actor` resolves `Sprites.getDraw(gid)` (`Gen3Scene.lua:674`) and draws a card. **This is the hook
point**: a landmark gid should route to a voxel model instead of a card.

`Gen3Scene.lua:745` already notes: "A leaning card set against a truck, a ridge or a fence would
slice into ..." — so trucks were known to be cards.

## The truck: what is and is not established

- **NOT map tiles.** Corrected earlier: x=3-9, y=13-16 of Littleroot is a second 7x4 **house**.
  Every blocked cell in Littleroot is accounted for by the two houses and the border, so the truck
  is an object event drawn over the ground.
- Event data lives at
  `~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/map_tree/maps/<slot>/events.json`,
  census at `.../map_tree/census.json` (ids are bare like `LittlerootTown`, slot `0_9`).
  Objects carry `{x, y, graphicsId, graphics, sprite?, flag}`.
- Littleroot's 8 object events and their graphics ids:
  `(16,10) gid 6` · `(12,13) gid 17` · `(14,17) gid 9` · `(5,8) gid 215` · `(2,10) gid 94` ·
  `(11,10) gid 94` · `(13,10) gid 240` · `(14,10) gid 64`.
- At runtime `Objects.forDraw()` reports the same, plus ~42 generated props (`gid 7400xx`, negative
  cells — those are the scenery props, not the truck).
- **Sprites that resolve:** gid 6, 9, 17, 64, 94, 215 all return a drawable. **gid 240 does not** —
  worth understanding.
- **Best candidate for the truck: gid 215 at cell (5,8)**, near the houses and north of the player's
  spot. Its `flag` is 752 (non-zero), so it is conditional — if that flag is unset the mod may be
  drawing something else there, which could itself be the bug. **This is the open question.**

## Next steps, in order

1. **Confirm the truck's graphics id** (prime suspect gid 215): dump the sprite art for gids
   6/17/215/240 and compare against the capture, and check whether flag 752 gates it.
2. Write the tool: read a landmark's sprite pixels (the sprite atlas, or the tileset atlas) and emit
   a voxel model — position + per-face art-sampled colour + baked `FACE_SHADE`.
3. Render it through `Voxel3D.newMesh`, routed from the `actor(gid, ...)` call site for that gid.
4. Capture before/after at levels 4 and 7 with several `EM_YAW`, judged with nearest-neighbour crops.
5. Then repeat for the other tile-drawn landmarks (boats, rocket, Mt. Pyre).

## Also still open (unrelated, from the same session)

The **T-SHIFT blur** fix is in the source and QA but **unverified** — the capture harness never
executes `Gen3SceneOptions.update` (it runs via the mod's `core.update` hook). Needs a look in the
real game. Details in `docs/OPEN-ISSUES-2026-10-05.md`.

## The huge pillar, and what the sprite probe found (2026-10-05, second pass)

The user's screenshot shows a tall untextured **green column** rising from the ground past the
player's head, where the truck should be. So the truck is not merely a wrong-shaped box — it is a
sprite drawn at a wrong size or with a missing image (the column is flat green, no art).

Sprite probe (QA, `EM_LITTLEROOT_TOWN`, `Objects.forDraw` + `ow_sprites.getDraw`):

| gid | width x height | frames | image | inanimate |
|---|---|---|---|---|
| 6, 9, 17, 64, 215 | **16 x 32** | 9 | 16x288 | false |
| **94** | **48 x 48** | 1 | 48x48 | **true** |
| 240 | — | — | — | **does not resolve at all** |

- The draw object is `{width, height, image, imageData, quads, frameCount, palette, paletteTag,
  reflectionPaletteTag, inanimate}`. `width`/`height` are the frame size; `quads[n]:getViewport()`
  gives the atlas rect. **This is everything a model builder needs** — no separate atlas tooling.
- **gid 215 is a 16x32 NPC sprite**, not a truck. My earlier "prime suspect" was wrong.
- **gid 94 is a 48x48 inanimate sprite** (the only inanimate one in the map) and the event table has
  **two** of them at (2,10) and (11,10). That is the best truck candidate — and note the capture
  showed what looked like *two* truck-like objects, which matches two gid-94 events.
- **gid 240 resolves to nothing** (`getDraw` returns nil). An object the mod cannot find a sprite for
  is a strong candidate for the untracked column.

**Next step, precisely:** decide between gid 94 and gid 240 as the truck by drawing each at a known
cell and looking, then check the flag gating (`flag` 794 for the gid-240 event, and 752 for gid 215)
— a flag-gated event that the engine hides but the mod draws, or vice versa, may be the real defect.
`draw.width`/`draw.height` then give the model's source art directly.

## The bigger direction the user chose: voxel up most tiles

"build most of the tiles up as a voxel" for realism. Important distinction from the landmark work:

- **Landmarks** (truck, boats, rocket, Mt. Pyre) are **sprites** — object events, `graphicsId`,
  `Sprites.getDraw(gid)`, 16x32..48x48 frames. Model from `draw.image` + `draw.quads`.
- **Most tiles** are **tileset art** — metatiles in the `u`/`m`/`o` atlases, addressed by `mid` via
  `uvFor(ts,mid)` → `ts.midToSlot`. `Gen3Objects` already does per-pixel cut-and-stand for *some* of
  these; the ask is to raise far more of them.

So the two halves want different sources, and the tile half is the larger job. Before building it,
worth reading how `Gen3Objects` cuts art (`VoxelHull`, the ground-pixel test) and how
`Gen3Terrain.append` maps faces, because that is the existing machinery the tile voxelisation would
extend — plus the known face-texture constraint: `uvFor` addresses a tile **inside an atlas**, so
face UVs cannot wrap past the tile edge (the atlas clamps).


## Pillar identified — and one candidate eliminated (third pass)

The mod draws exactly four Littleroot objects, and they match the event table one for one:

| gid | cell | flag | draw | size | inanimate |
|---|---|---|---|---|---|
| 6 | (7,2) | 0 | yes | 16x32 | false (NPC) |
| 9 | (13,17) | 0 | yes | 16x32 | false (NPC) |
| **94** | **(2,10)** | 761 | yes | **48x48** | **true** |
| **94** | **(11,10)** | 762 | yes | **48x48** | **true** |

**gid 240 is NOT drawn** and `getDraw(240)` returns nothing at all. Its event (13,10) carries flag 794,
which is unset, so the engine hides it and the mod agrees. So gid 240 is **not** the pillar — my
earlier hypothesis is eliminated.

**The pillar is therefore gid 94**, the only 48x48 inanimate sprite, drawn at **two** cells —
matching the two tall objects seen in the captures. Whether the column is the sprite's own art or a
card drawn at the wrong size is the remaining question, and it is answerable from `gid94.png`.

**Dumping the art failed for a mundane reason:** the game runs in a sandbox, so
`imageData:encode('png', '/Users/...')` cannot open that path ("Could not open file ... not found").
Next attempt must respect the sandbox:

- encode to a **relative** path and read it from the LÖVE save directory
  (`love.filesystem.getSaveDirectory()`, i.e. the QA identity's `saves/` area), or
- write the pixels to **stdout** (hex rows) and rebuild the PNG in Python — no filesystem access at
  all. This is the safer of the two.

`tools/dump_gid.lua` is committed and ready; it just needs that path change.

## Landmark model pipeline — what is now settled

- Source art: `Sprites.getDraw(gid)` -> `{width, height, imageData, image, quads, palette, inanimate}`.
  `quads[n]:getViewport()` gives the atlas rect per frame. **No atlas tooling needed.**
- Render: `Voxel3D.newMesh(verts, indices)` with `Voxel3D.FORMAT` (position, texcoord, shade);
  no vertex colour, so faces use atlas UVs or the existing `swatch()` texel trick.
  Bake `Voxel3D.FACE_SHADE` per face.
- Hook point: `Gen3Scene.lua:782-789`, the `Objects.forDraw()` loop - route a landmark gid to a model
  instead of `actor(gid, ...)`.

## DONE — the tool exists, and the truck is a model (2026-10-05, fourth pass)

Steps 1-4 of "Next steps" are complete. Step 5 is now one recipe per landmark.
Installed in the mod source and in QA; no engine change.

**The truck is gid 94** (confirmed, not inferred): the only 48x48 inanimate
sprite in Littleroot, drawn twice — (2,10) and (11,10). Its art came out of the
sandbox by printing hex rows to stdout (`tools/dump_gid_art.lua` →
`tools/art_from_log.py` → `shots_art/gid94.png`): a moving van, cab west, box
east, 48x40 px of drawing. gid 240 still resolves to nothing at all.

**How a sprite becomes a solid.** Gen 3 draws objects in the same oblique
projection as its map tiles, so an object drawing already carries a front
elevation *and* a plan view. Measured off gid 94 (sprite rows; ground at 47):

| band | rows | what it is | model meaning |
|---|---|---|---|
| 8..23 | box roof, blue with ribs | the box's top, 1:1 | depth 16 (one tile) |
| 24..41 | box wall, purple with the logo | the box's south wall, 1:1 | height 18 |
| 12..27 | cab roof, light grey | the cab's top, 1:1 | 4 px lower than the box |
| 28..41 | cab wall with the window | the cab's south wall, 1:1 | height 14 |
| 42..47 | wheels | wheel discs | 6 px under the body |

So the truck is **48 long x 16 deep x 24 tall** — three tiles by one, not the
48x48 card. Every face samples those bands, so the roof ribs, the logo, the cab
window and the wheel hubs all land on the plane they were drawn for, with
`Voxel3D.FACE_SHADE` baked per face.

**Files** (mod source `~/Documents/battle-art-notquiteog/lib/`):

- `SpriteVoxel.lua` — the tool and its recipe format. A recipe is a list of
  axis-aligned boxes in sprite pixels; each face is painted by a rect of the
  drawing (a 1x1 rect paints one flat colour — the swatch trick, off the
  sprite). Boxes rasterise into a voxel volume, only boundary faces are
  emitted, coplanar faces of one paint merge: the truck is **46 quads**.
- `LandmarkModels.lua` — gid → recipe; gid 94 is the only entry so far.
- `Gen3Scene.lua` — the hook. `actor()` asks for a modelled solid first; when
  there is one it is drawn world-aligned (no camera yaw, no card lean, no
  camera-ward pull, which would lift it off its own footprint) through the same
  draw and shadow calls the card used, and `release()` frees its meshes.

**Evidence.** 16 views before (card) and 16 after (model) at two player
positions x levels 4/7 x four yaws, plus 16 close views. Zero `scene fallback`,
zero render errors (only the sandbox's `options.lua` write refusal, which the QA
identity always logs). The before/after pixel diff is confined to the two vans:
2141 changed pixels, bounding box x 558..812, y 183..412, both clusters on the
trucks. Before, the card stands the roof band on end and leans it across the
house; after, the van sits on the ground with its cab, box, wheels and logo
reading from every angle.
Captures, for whoever picks this up next: `shots_truck_before/` (card),
`shots_truck_after/` (model, staged overlay; `landmark_before_after.png` is the
side-by-side at 6x), `shots_truck_near/` (close views), `shots_truck_installed3/`
(the installed path, logged `[LANDMARK] gid=94 quads=46`),
`shots_art/gid94.png` (the drawing itself), `shots_model/` (offline previews).
The offline audit is unchanged by this round: 19,641 blocked cells flat, 9,011
outdoor, 469 objects.

**Tooling added this round** (all in `tools/`):

- `dump_gid_art.lua` + `art_from_log.py` — sprite pixels out of the sandboxed
  game as hex rows, rebuilt as PNGs.
- `model_preview.py` — builds a recipe with the mod's own Lua under luajit
  (stubbing only `newMesh`/`Budget`) and rasterises it offline, so geometry and
  face registration are judged in seconds instead of capture round trips. It
  extracts `FACE_CORNERS`/`FACE_SHADE` from the installed `Voxel3D.lua`, so it
  cannot disagree with the engine about winding or shading.
- `em_truck_driver.lua` — capture sweep (cases x levels x yaws). `EM_STAGED=<dir>`
  overlays worktree modules onto the live mod, so a change can be captured
  *before* anything is installed anywhere.
- `stage_landmark.py`, `install_landmark.sh`, `landmark_patch.py`.

**Next landmark**: write one recipe. Boats, the Space Center rocket and Mt. Pyre
are the same shape of problem; each needs its gid (`dump_gid_art.lua`), its
bands read off the drawing, and a box list. The tile half of the plan ("voxel up
most tiles") is untouched by this round and remains the larger job.

**Concurrency note.** `patches/battle-art-voxel-fork.landmark.patch` holds this
round's three files only. Another session was editing the same mod working tree
(`lib/Gen3VoxelBuildings.lua`, "pixel-voxel buildings") while this landed, so
the wholesale `patches/battle-art-voxel-fork.patch` was deliberately *not*
regenerated — it would have snapshotted that session's unfinished work.
