# Brief for Sonnet: Emerald 3D, every NON-building asset as voxels (2026-10-05 night)

Read `HANDOFF.md` (paths, rules) and §0 of `docs/NEXT-AGENT-BRIEF.md` (ground rules) first. This brief covers
only the current work: **every building and asset as pixel-voxels true to the original art**. The status
log is `docs/BUILDINGS-REBUILD.md`.

## The goal, in the user's words
"A 3D vibe for Emerald, with overworld Pokémon, Pokémon following you and a Stadium/Colosseum battle
style." The follower already works.

The user's top priority is that **all buildings are done correctly**, then every other asset (signs,
items, props, terrain issues, interiors). The user is very critical and will look closely.

## Non-negotiable rules from the user
- **One art pixel = one voxel. Never stretch a pixel.** Every visible face shows exactly one drawing
  pixel.
- **Roofs:** the horizontal line across a house roof is the **ridge of a symmetric gable**, with the
  chimney or vent on top of it. Don't build a flat roof with a stuck-on chimney. The Littleroot houses
  (Japanese-style roof) are the reference the user likes.
- **Judge in game at the player's camera** (level 4, zoom 0) at full resolution. Never judge from far-away
  shots or thumbnails. The user called this out angrily twice. Crop and zoom into the building.
- **No regressions:** compare before and after, and install only what is better.
- **The other agent's asset assignment is broken** (user, 2026-10-05). Don't build on it; it will be
  redone later.

## Paths
| What | Where |
|---|---|
| Mod source (edit here) | `~/Documents/battle-art-notquiteog` (`lib/`, `data/buildings/`) |
| QA install | `~/Library/Application Support/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK` |
| Real install | `~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK` |
| Building tools | `~/Documents/Emerald/tools/buildings` (run from there) |
| Patch | `~/Documents/Emerald/patches/battle-art-voxel-fork.patch` |

## How Opus makes buildings (reference: the same technique applies to props)
1. **Find the box.** Run `python3 grid.py /tmp/x.png MAP PAIR x0 y0 x1 y1`.
   - It renders the map's art with a cell grid and labels. Read the building's cells from the image.
   - `inventory.json` lists every building's map, tileset pair and door cell.
   - The pair is NOT always the town's (Route 104 is `general__rustboro`; Route 111 and Verdanturf are
     `general__mauville`).
2. **Add the box** to `BOXES` in `explicit.py`: `name: (MAP, PAIR, [x0,y0,x1,y1], wallTop)`.
   - The box is inclusive map cells.
   - `wallTop` is the first map row of the facade (wall). The rows above it are roof.
   - Exclude trees, bushes and fences at the edges: tighten the box.
3. **Run** `python3 explicit.py /tmp/ex --only name1,name2` and look at `/tmp/ex/explicit.png`. It shows
   the art and three renders (head-on, turned, back).
   - `autorecipe.derive` picks: a ridge row → `gable nf/nb`, no ridge → `flat roof n`, no roof → `block`.
   - Overrides in `explicit.py`:
     - `GABLE = {name: back_rows}` forces a symmetric gable. Used for hip roofs, domes and pyramids.
     - `FLAT = {...}` forces a flat roof. Used for parapet-rimmed roofs that the ridge finder misreads.
     - `STAND = {name: (x,y)}` makes the model stand on that map cell's floor (Trainer Hill on its
       plateau).
     - `KEYS` holds extra ground colours, cut by flooding from outside.
4. **Export:**
   - `python3 explicit.py /tmp/ex --only NAME --export ~/Documents/battle-art-notquiteog/data/buildings`
     writes `x_NAME.lua`. Models are geometry only: no colours, nothing ROM-derived.
   - Then run `python3 reindex.py`, which rebuilds `data/buildings/index.lua`.
5. **QA:**
   - Sync: `rsync -a --delete ~/Documents/battle-art-notquiteog/data/buildings/ "<QA>/data/buildings/"`.
     Also sync `lib/` if you changed Lua.
   - Capture:
     ```bash
     tools/buildings/qa_capture.sh /tmp/shots "{'EM_SLATEPORT_CITY',28,40}"
     ```
     The case is a walkable cell 1–2 rows below the door. Standing on a door cell fails, and you get a
     blank or map-edge shot.
   - A second case on the same map is saved as `MAP_4_<n>.png`.
   - Crop and zoom the building and Read the image.
6. **Install:**
   - Run `pgrep -fl "MacOS/love"` and make sure it prints nothing.
   - Back up `data/buildings` (and `lib`) outside `mods/`.
   - rsync to the real install.
7. **Patch and commit:**
   ```bash
   cd ~/Documents/battle-art-notquiteog && git add -A data/buildings lib && git diff HEAD > ~/Documents/Emerald/patches/battle-art-voxel-fork.patch
   ```
   - Check it with `git apply --check` against a clean extraction of base `03882a9`.
   - Commit in `~/Documents/Emerald`: the patch, the tools and the docs. Never commit ROM-derived files.
     Don't push.

Engine-footprint buildings (`autorecipe.py --nums N --export ...`) use the same recipe code. Family
models (Center, Mart, tree house, Sootopolis, Pacifidlog) are hand recipes in `hf_recipes.py`.

## Gotchas that already cost time
- **Two agents share the QA identity.** If a capture or the tile cache fails (`mids.idx` missing,
  `KeyError: 'u'`), another run is regenerating `emerald/data/generated`. Wait for it to finish. Visiting
  the map once in QA regenerates that tileset's atlas.
- **Ground cut** (`autorecipe.derive`): each walkable tile around the building is flooded from the edge on
  its own. A door drawn like ground survives. If ground still shows (grass corners, rock), add `KEYS`.
- **The QA zoom drifts to −3.** `qa_capture.sh` resets it to 0. Don't remove that.
- **Mod sandbox:** `os.getenv` is hidden inside the mod. Use module flags for debug prints.

## Split of work: Sonnet = everything EXCEPT buildings
**Claude (Opus) is fixing the buildings at the same time.** Sonnet works on the other assets. Never touch
these:
- `data/buildings/*`, `lib/BuildingVoxels.lua`, `lib/BuildingModels.lua`, `lib/LandmarkModels.lua`.
- Everything in `tools/buildings/` (`hf.py`, `hf_recipes.py`, `autorecipe.py`, `explicit.py`, ...). Read them for ideas; don't edit
  them. Put your own tools in `tools/assets/`.
- If `Gen3Scene.lua` needs a hook, keep the edit small and self-contained, and note it in the commit
  message. Opus may edit that file too: re-read it right before editing.

**Sharing rules:**
- **One game instance at a time.** Before every capture or install, run `pgrep -fl "MacOS/love"`.
  - If a game is running, wait; it is probably Opus's QA run. `qa_capture.sh` already waits.
  - Never kill another run.
- **Install only your own changed files** to the real game, never a whole-folder rsync of `lib/`. Back
  them up first, outside `mods/`.
- **The patch:**
  - `battle-art-voxel-fork.patch` is `git diff HEAD` of the whole mod repo, so it also carries Opus's work.
    That's fine.
  - Regenerate it, `git apply --check` it against a clean extraction of base `03882a9`, and commit only
    your own files plus the patch.
  - If a commit fails because of a race, just redo it.
- **Don't build on the old "asset assignment"** from the other agent. The user says it is broken; it will
  be redone.

## Sonnet's work queue (in order)
1. **Signs** (highest visibility):
   - Route, town and house signs render grass-coloured: `Gen3Objects` cuts their pixels as ground.
   - Make one voxel model per sign drawing: a post plus a board, the board's art on the front and back
     faces, one art pixel per voxel. Match each model by metatile id.
   - The building recipe code shows the technique (geometry only, faces sample the drawing pixel), but
     write your own module (e.g. `lib/PropVoxels.lua`).
   - Check in Littleroot, Oldale, Route 101/103, Petalburg and Slateport at the player's camera.
2. **Small props:** item Poké Balls, berry trees, smashable and pushable rocks, fences, flower beds, the
   Slateport market stalls, mailboxes, Pokémon Center and Mart signs that stand apart.
   - Same rules: voxels from their own art, nothing stretched.
3. **Terrain:**
   - The duplicated shoreline. The user saw it in the far top-right corner of a coast view. Find it by
     capturing the coastal routes (104, 105–109, 115, 118, 121–124).
   - Tree-top tiles drawn under the 3D tree canopies: the canopy art is still painted on the ground
     beneath them.
   - Sea rocks: check that the water around them is not lifted.
4. **Interiors.** The user says "indoors is completely fucked".
   - Capture about 10 typical interiors: player's house, Center, Mart, Gym, lab, a cave.
   - Describe what is wrong and propose a plan to the user **before** building anything.
5. **Battle 3D animations:** broken per the user, details unknown. Ask the user what is wrong first.

## Reporting
Keep the user posted in a few lines per batch: what was built, what was checked in game, and what is
still wrong. Never claim something looks right without having looked at it at the player's camera.
