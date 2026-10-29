# Emerald 3D own-code rewrite plan

Status: APPROVED by Petya 2026-10-29 ("lets make it happen"; licence MIT; release waits, work towards it now). M0 started.

**Decisions (2026-10-29, all seven confirmed FINAL by Petya, no exceptions):**
1. ~~Public beta after M1 (overworld + interiors in 3D, the engine's 2D battles)~~ superseded 2026-10-29: the first public build waits for 3D battles (see below).
2. A separate session checks every spec for copied code; Petya spot-checks.
3. ~~Colosseum is left out of the beta (M5 later)~~ superseded 2026-10-29: Colosseum comes before the release, via our own MIT reader from public format docs (the GPLv3 add-on is off limits).
4. Petya's 13 hand-drawn fly sheets ship; all other species get ROM-generated sheets.
5. World fill is rebuilt from ROM data (no traced ids).
6. MIT licence, copyright Petya Bouianov; new local repo `~/Documents/emerald3d` (no GitHub repo, no push until Petya says).
7. The old mod gets bug fixes only during M1 (each fix also becomes a spec delta).

**Petya 2026-10-29 (14:45):** "to be clear i want the 3d battles with fx and animations in the release!" So M4 (3D battles: stage, camera, HUD, backdrops, pokeballs, hit effects, animations) is part of the release (M6), never dropped. **Order changed (Petya's answer, relayed by the coordinator 2026-10-29 14:46):** no public build with 2D battles; the first public build waits for 3D battles with effects and animations. New order: **M0 -> M1 -> M4 (3D battles + Stadium 2) -> M5 Colosseum -> M6 release.** Colosseum is now needed, because Stadium 2 covers only #1-251 and Hoenn's #252-386 come from Colosseum/XD. M2 (caves, furniture, cameras, Fly) and M3 (lighting) run after, or in parallel only where they do not delay the release. This supersedes decision 1 (beta after M1) and decision 3 (Colosseum left out).
**DECIDED (Petya, relayed by the coordinator 2026-10-29 14:48):** Colosseum loads through our own MIT model reader written from public format documentation, reading the player's own disc in the game. The GPLv3 Blender add-on (StarsMmd's) is treated like upstream under the clean-room rules: never ported, never consulted.

Petya's decision (2026-10-29, relayed by the coordinator): do not ask notquiteog or Deftones565 for a licence. Instead, rewrite every upstream-derived part that Emerald play needs, so the drop-in mod contains only Petya's own code (plus MIT third-party code with its notices).

Background: [DROPIN-BETA-PLAN.md](DROPIN-BETA-PLAN.md).

Data used here:
- `dropin/upstream174.tsv`: the 173 upstream Lua files Emerald loaded in the runtime trace, plus 1 texture. Columns: class (same/modified), file, lines, own modules that require it.
- `dropin/runtime_files.tsv`: every mod file the trace saw.

The trace covered 18 maps plus one wild battle. It did not cover Fly or every map; milestone 0 widens it.

**QA note (2026-10-29):** `tools/qa_run.sh` (main QA identity `pokemon-love2d-rseqa`) hangs today with no frames, even for a one-map run. `tools/qa_tryp.sh` (private copies -p1..p4) works; every run for this plan used it. Fix or retire `qa_run.sh` before milestone 0, because many gate scripts call it.

## TL;DR

- **What has to be replaced:**
  - 174 upstream items: 173 Lua files (86.3k lines) plus the tree-crown texture.
  - About 13.6k of those lines are battle-sprite tables that point at Nintendo sprite files. They are dropped, not rewritten.
  - About 72k lines of behaviour need new code. Most of it is in the world scene (32k), the voxel engine (14k), battle presentation without its tables (12.6k) and lighting/sky/water (8.2k).
- **Our own code is close to clean:**
  - Our 51 new modules: only 218 of 69,667 code lines match any upstream line exactly. That is boilerplate to check, not copied code.
  - In the 49 modified files we added 8,496 lines. 6,219 of them sit in blocks of 30 or more lines, mostly whole functions we wrote. 2,277 are small edits inside upstream functions. 203 added lines are exact upstream lines (moved code).
- **Method:**
  - The spec writer may read upstream and the running game, and writes behaviour specs: inputs, outputs, numbers, measured dumps, no code.
  - A separate implementer, who never sees upstream, writes the new module.
  - The output must pass the existing gates against a golden baseline captured from today's game.
  - A similarity check against upstream must come back clean.
- **Milestones:**
  - M0: harness + baseline.
  - M1: smallest playable drop-in, i.e. Emerald overworld and interiors in 3D at the player camera, with the engine's own 2D battles.
  - M2: caves, furniture and all cameras, Fly.
  - M3: lighting, sky and water polish.
  - M4: 3D battles + Stadium 2.
  - M5: Colosseum import (optional).
  - M6: release.
- **Effort:** about **17-25 weeks** of focused work in total. **M1 alone takes about 7-9 weeks** (M0 included). This is more than the earlier "6-12 weeks" guess in DROPIN-BETA-PLAN.md, because it now counts the spec and verification overhead the clean-room method needs.

## 1. The 174 upstream items, grouped by job

The lines are those of the installed files. For modified files, they include our own lines.

"Own dependents" are our new modules that call `V.require` on a file in the group. Our modified files also depend on these groups, and those lines move with the rewrite.

| # | Group | Files | Lines | Modified by us (lines) | Own dependents (direct) |
|---|---|---|---|---|---|
| 1 | World scene: Gen 3 map to 3D (terrain, elevation, rock, caves, stairs, buildings, furniture, trees, props) | 59 | 32,394 | 23 (23,403) | Gen3Blocks, Gen3Objects, Gen3FlyOver, Gen3BattleStage, TourMode |
| 2 | Voxel engine, meshing, atlas, streaming, budgets | 18 | 14,006 | 7 (4,922) | BuildingModels, BuildingVoxels, FlatMesh, Gen3FlyGround, Gen3FlyOver, Gen3Hills, Gen3Lamp, Gen3Objects, Gen3RockSprites, Gen3StadiumModels, Gen3VoxelBuildings, SpriteVoxel |
| 3 | Camera and field hook-up (FieldView/Display wrap, 1st/3rd/orbit, tilt-shift) | 11 | 2,539 | 2 (465) | Gen3FlyOver, TourMode |
| 4 | Lighting, day/night, sky, water, shadows, weather, AA/upscale | 16 | 8,177 | 4 (2,392) | Gen3StadiumModels |
| 5 | Sprites and characters in 3D (billboards, anchors, trainer art) | 6 | 625 | 0 | (through group 1) |
| 6 | Battle presentation and battle art | 50 | 26,231 (12.6k code + 13.6k sprite tables) | 9 (7,333) | BattleShots, Gen3BattleStage, Gen3StadiumModels |
| 7 | UI and options | 9 | 1,760 | 4 (536) | BattleShots |
| 8 | Utilities (Generation, LoadTimings, CacheTrace, RenderRecovery) | 4 | 537 | 0 | (everything) |
| — | Texture `assets/crystal/depth-crowns-v2.png` | 1 | — | — | tree crowns (NativeTreeArt) |

**File lists** (* = modified by us)

1. **World scene:** Gen3Scene\*, Gen3Elevation\*, Gen3Cave\*, Gen3Terrain\*, Gen3TileShape\*, Gen3Tilesets\*, Gen3Stairs\*, Gen3Outdoor\*, Gen3Boundary\*, Gen3Civic\*, Gen3RoofDetails\*, Gen3SceneCache\*, Gen3Furniture\*, Gen3InteriorProfiles\*, Gen3Buildings, Gen3Forest, Gen3AdditionalFurniture, Gen3AdditionalInteriors, Gen3CenterFurniture, Gen3DesignedFurniture, Gen3InstitutionFurniture, TerrainLevels\*, TileShape, Structures\* (5.1k), Buildings, InteriorFurniture, InteriorDiorama\*, CommunityFlora\* (7.9k), CommunityVisuals, ForestDressing, SafariFoliage, SafariStatues, GranitePillars, HouseCladding, RoofEaves, LegendaryTowerExterior, LegendaryTreeCache, TowerLobbyDetails, CavePerimeter, CaveSconces, BoundaryScenery, WorldFillProps, WorldUnderlay\*, ShipHull, Gen2Rocks, Gen2Trees, Gen2FruitTrees, Gen2DepthTrees, NativeTreeArt\*, NativeTreeModels, TreePresentation\*, TreeIllustrations, CanopyBillboard, VoxelVisualObjects, GlassMask\*, ItemPokeballs, data/gen3_stairs\*, data/gen3_exteriors, data/world_fill_biomes.
2. **Voxel engine:** Voxel3D\*, VoxelHull\*, VoxelScene\*, StaticGeometry\*, ModelInstances\*, SceneStream\*, RenderDistance\*, ChunkMesher (4.7k), VoxelMeshDisk, TerrainAtlas, VoxelState, VoxelGrid, BuildBudget, Mat4, DrawUniforms, PixelCanvas, SceneryMask, WorldCurve.
3. **Camera:** Gen3Integration\*, TiltShift\*, CamControl, CameraEye, CameraSettings, FirstPerson, ThirdPerson, AtmosphereCamera, ActorContact, FlyMotion, Gen3Recap.
4. **Lighting:** DayNight\*, SkyLayer\*, NativeAtmosphere\*, TowerGraveMist\*, Sky, Water, WaterSurfacePass, ShadowMap, Shadows, CaveAtmosphere3D, ForestAtmos, Weather, TowerFogSettings, AntiAlias, SpatialUpscale, Gen3SpriteLight.
5. **Sprites:** CharacterRenderers, SpriteBillboards, SpriteHeadBounds, Gen3SpriteAnchor, Gen3TrainerArt, data/animated_player_trainers.
6. **Battle:**
   - Code: BattleScene\*, BattleArt\*, BattleCam\*, Backdrop\*, Gen3Battle\*, Gen3BattleHud\*, Gen6Backdrop\*, OverworldBattle\* (2.1k), StadiumModels\*, BattleArena, BattleBillboard, BattleDOF, BattleHud, BattleOcclusion, BattlePics, BattlePresentation, BattleTheme, BackdropImage, BossBackdrop, Gen3BattleBackdrop, Gen3BattleClear, Gen3BattleOptions, NativeBattleArt, AnimatedBattleArt, Pokeball, PokeballSettings, SuccessStars, q57/{Adapter, Ballistics, Breakout, Material, Plasma, Release}, q58/SuccessStars, EmberLegacyAudio, ModernBattleUI.
   - Data: animated_battle_sprites_gen2..5(+shiny), animated_battle_backs_gen3, bundled_bw_fronts, crystal_full_body, battle_species_dex_386, boss_battle_backgrounds, gen6_battle_backgrounds.
7. **UI:** Gen3SceneOptions\*, OptionSupport\*, SettingsCatalog\*, UiBackplates\*, InGameOptions, InterfaceSprites, ModSetting, NativeInterfaceArt, TextboxStyle.
8. **Utilities:** Generation, CacheTrace, LoadTimings, RenderRecovery.

**Third-party code that can be used directly:**
- **FSR1 headers** (`assets/shaders/fsr1/*.h`, AMD, MIT): keep them, with the notice. Only SpatialUpscale's Lua glue needs rewriting.
- **Weather:** our Weather.lua is upstream's adaptation of Voxel Ascendant's MIT Weather.lua. Start again from the original MIT file (Roxas2712/voxel-ascendant, rev 22c2bb5…), with its notice, and add our own Gen 3 hook-up. Do not start from upstream's adapted copy.

## 2. Clean-room rules for this project

**Roles**

| Role | May read | Writes | Never |
|---|---|---|---|
| Spec writer (one session per group) | Upstream source, the running game, our gates/dumps, the 2D art, Petya's rules | `docs/rewrite/specs/<Module>.md` | Code, pseudo-code that mirrors upstream structure, upstream identifiers other than the public interface our own modules call, upstream comments, copied constants tables |
| Spec reviewer (Petya or a third session) | The spec | A pass/fail note | Pass a spec that contains code or line-by-line algorithm transcription |
| Implementer (fresh session, never given upstream) | Specs, the gen1recomp engine source (GPLv3, public API), our own modules, golden dumps/captures | New module in the clean tree | Open `~/Documents/battle-art-notquiteog`, the installed mod folder, `patches/battle-art-voxel-fork.patch`, or any upstream copy |
| Verifier | Both trees | Gate results, similarity report | Fix code (it reports back to the implementer) |

**Separation in practice**

1. The implementer works in a **new clean tree**: a new repo `~/Documents/emerald3d` that becomes the content of DJMAccie/Emerald-voxel-mod. It contains only our own files, the specs and the golden data. The upstream fork, the installed mod and the fork patch are not reachable from it.
2. The implementer's sessions run with Claude Code **permission deny rules** for Read/Bash on those three paths (set in the clean repo's `.claude/settings.json`). Petya can see the rule in the repo.
3. Every implementer session starts fresh (no fork of a session that read upstream) and is told its role. Subagents are not used for implementing (global rule).
4. The handoff is only the spec file plus golden data. Nothing else travels from the dirty side.
5. **Honest limit:** every session runs the same model, and the model and Petya have both read upstream for months. The process controls (separate trees, deny rules, specs reviewed for leakage) and the similarity check are the evidence. They are good evidence, not a guarantee. Record each spec's author session and each implementer session id in `docs/rewrite/PROVENANCE.md`.

**What a spec contains**

- **Purpose:** what the player sees, tied to Petya's rules (R-ids) and the 2D art.
- **Interface:** the functions our own modules and the engine call, with argument and return meaning. This is the one place names may match, because our own modules already use them (`Scene.groundAt`, `debugCell`, `Voxel3D.newMesh` …). Interface names are facts of our own code.
- **Behaviour as observable rules:** inputs to outputs, cases, numbers that are measured or are Petya's (16 px course, LEAN .05, …).
- **Measured references:** the golden geometry dump, cell dump and capture IDs that the new module must reproduce, with the tolerance.
- **Out of scope:** Gen 1/2 paths, FRLG-only features.

Algorithms are described at the level of "what" plus measured results, never "how upstream does it". Where only one sensible method exists (greedy meshing, painter's sort), name the standard technique from public literature, not upstream's version.

**Proving the new code is ours**

- `tools/rewrite/simcheck.py` (to write in M0) runs three checks of the clean tree against upstream base 03882a9 and upstream's latest release:
  - (a) exact-line hits: code lines longer than 24 characters, comments excluded;
  - (b) token-level winnowing fingerprints (MOSS-style k-grams over Lua tokens with identifiers normalised);
  - (c) a per-function structure match (call sequence and control-flow shape).
- Targets: no exact-line hits outside an allow-list of trivial lines (`local V=...`, `return M`, …), and token similarity under 5% per file. Every flagged pair is reviewed and either explained or rewritten.
- The report is kept in `docs/rewrite/SIMCHECK.md` per milestone.
- Optionally also run JPlag (open source) as an independent second opinion.

**Our own lines in the 49 modified files**

1. Make the diff of each modified file against base 03882a9 (`git diff --no-index` from `git show 03882a9:<file>` to the installed copy).
2. **Remove moved upstream lines.** Exact-match each added line against the base file. 203 added lines are upstream lines that were moved or copied (git counts them as added). They are not ours.
3. **Blocks of 30 or more added lines (6,219 lines)** are mostly whole functions we wrote: the pin field, blocks, ledge wedges, scene hooks, Fly hooks.
   - The dirty-side session lifts each block into `docs/rewrite/own/<file>/<n>.lua`.
   - It strips any upstream identifiers that the block reaches into (a private upvalue or local helper of the upstream file), replacing each with a named interface call.
   - It runs simcheck on the block against the base file before the block crosses to the clean tree.
4. **Small edits inside upstream functions (2,277 lines)** cannot be lifted, because they only make sense inside upstream code. Each becomes a "delta" line in that module's spec, for example: "cells within 2 of a stair tile take the flight's base". The implementer builds it in from the spec.
5. Tuned constants and knobs are our values and our measurements. They go into the specs as numbers.
6. Our 51 new modules also get the same simcheck. Today they have 218 exact upstream lines, most in Gen3Rock, Gen3Objects, Gen3Mass, Gen3EmeraldShapes, Gen3StadiumModels and Gen3FlyGround (10-24 each). Review those and rewrite any that are not trivial.
7. **Mind the interfaces.** Our own modules call into upstream modules (table above). The specs must capture exactly those calls, so our modules work unchanged on the new implementations.

## 3. Order of work, milestones, effort, verification

**The baseline problem:** today's gates hook into our current module internals:
- the geometry driver wraps `Voxel3D.newMesh`;
- the cell driver calls `Gen3Scene.debugCell` / `groundAt`.

So M0 adds **mod-neutral** probes. These hook the engine (`love.graphics.newMesh`, `Mesh:setVertices`, the draw calls) plus a small debug interface that both the old and new mod expose (`exports.gen3.debug.cell(x,y)`, `groundAt`). The same driver can then measure today's game and the rewrite.

| Milestone | Contents | Effort | Verified by |
|---|---|---|---|
| **M0 Harness and baseline** | Widen the runtime trace (all outdoor maps, caves, interiors, Fly, battle, options menu). Build a mod-neutral mesh/cell probe. Capture the **golden baseline** from today's installed game: geometry dumps (setsum/seqsum per map, `tools/em_meshprobe_driver.lua` idea), cell dumps (`tools/em_cells_driver.lua`), the G-01/G-02/G-03/G-11 outputs, L4/L6/L7 captures of ~80 fixed spots (one per tileset family + every gym, PC, mart, cave family, sea, Safari, Sky Pillar, Abandoned Ship, Battle Frontier), and the G-08 release-check results. Set up the clean repo and deny rules. Write simcheck. | 1.5-2 wk | Baseline reruns twice and agrees with itself (pairs() randomness: memory "dump gate repeatable") |
| **M1 Smallest playable drop-in** | Emerald overworld + interiors in 3D at the play camera (L4), with the engine's own 2D battles. Groups 8, 2 (engine, meshing, atlas, streaming), 1 core (terrain/elevation with our pin field, blocks, rock, water surface, trees from ROM art, buildings from our baked data, basic furniture, stairs), 5 (billboards), 3 (FieldView hook, L4 + orbit), 4 minimum (one light and a fog/sky colour), 7 minimum (one options page). New mod id `EMERALD_3D`. | 6-7 wk (M0 + M1 ≈ 7-9 wk) | G-01 diff 0 and G-02 counts equal to baseline on all pinned maps. G-03 sunk 0. G-04 grid_diff vs baseline: 0 changed cells. G-05 fallback 0. G-10 base = ground. G-11 counts equal. Geometry: per-map triangle-set diff (`tools/relief/stage3/ab/geo_diff.py`, `zfight.py` on the neutral dumps) with every difference explained. G-07 old\|new sheets at L4 on the ~80 spots. Simcheck clean. |
| **M2 Caves, furniture, cameras, Fly** | Caves (Gen3Cave behaviour, cave perimeter, sconces, cave atmosphere), all furniture families, interior dioramas, glass, Safari/Tower/Ship/Legendary special scenes, cameras 1st/low L6/rotating 3rd + camera collision, Fly (our Gen3FlyOver on the new engine), world fill. | 4-5 wk | Same gates on cave and interior maps. G-08 Tier 1 (`tools/release_check.sh`) equal to baseline. L6/L7 sheets. Fly frame captures vs baseline. |
| **M3 Lighting and atmosphere** | Day/night, sky layers, water (both passes), shadow map, weather (from the VASC MIT original), tower mist, AA, FSR glue, tilt-shift. | 2-3 wk | Captures at 3 times of day on the ~80 spots vs baseline (pixel diff as fault finder, judged by eye). Frame-time probe (`em_perf_driver.lua`) within 10% of baseline. |
| **M4 3D battles** | Battle stage, cam, HUD, backdrops, pokeballs, hit effects (q57 family), trainer art. Battle sprites only from the ROM (engine species pack). Stadium 2 models via the importer as an optional dependency (runtime hook through its exports, no patched importer files). | 4-6 wk | `em_battle_driver.lua` / `em_battlecam_driver.lua` / `em_stadium_driver.lua` captures vs baseline. No Lua errors across 20 scripted battles. |
| **M5 Colosseum import (optional)** | `optional_imports` for the disc; our own Lua reader for GCM, FSYS and LZSS from format documentation; PKX/HSD parse (see decision 3); DSM writer in `mod.job`; packs to `mod_cache/`. | 2-4 wk | The pack checksums or the render of 10 species match today's colo2dsm output. |
| **M6 Release** | Packaging (section 5), README, mod.card, CHANGELOG, licence, notices, modkit validate/lint, a clean-identity install test, and a GitHub release on Petya's go. | 1 wk | Install from the zip into an empty identity; G-05 and the boot error feed empty; final simcheck. |

The first public beta can ship after M1 (overworld 3D + 2D battles), as Petya chooses. Later milestones ship as updates.

## 4. Replacing Nintendo-derived art and borrowed sheets

| Item | Loaded by | Replacement |
|---|---|---|
| `assets/crystal/depth-crowns-v2.png` (Crystal tree-crown art) | NativeTreeArt (tree crowns) | Build crowns at runtime from the player's Emerald ROM tree metatiles: the engine already decodes them. Alternatively Petya draws an original crown texture. Never ship a ROM-derived PNG. |
| `data/animated_battle_sprites_gen2..5*`, `animated_battle_backs_gen3`, `bundled_bw_fronts`, `crystal_full_body`, `animated_player_trainers` (tables naming Nintendo sprite files) | BattleArt, AnimatedBattleArt, CharacterRenderers | Drop them. Battle and trainer sprites come only from the ROM through the engine (species pack, trainer pics). An optional "animated sprites" style can come later from a separate pack the player installs, never inside our zip. |
| `assets/flyers`: 23 sheets from the follower mod's followsprites, plus Charizard and Murkrow from PMD | Gen3FlyOver | Generate a flight sheet at first run from the ROM's own sprites (front/overworld frames, our flap/bank model in code), cached in `mod_cache/`. Petya's 13 hand-drawn sheets ship only if Petya decides so (decision 4). |
| `assets/worldfill/fill.bin` (metatile ids traced from darkshadedx's fan map) | Gen3FlyGround/WorldFillProps | Re-derive from ROM data (map borders + our own placement table) or keep it with credit (decision 5). It holds ids only, no pixels. |
| `assets/battle/back-animated/gen1player.png` (looked up, not present) | BattleArt | Remove the lookup. |

## 5. Manifest and packaging

**Zip layout** (`emerald3d-<version>.zip`):

```text
EMERALD_3D/
  manifest.json  main.lua  mod.card  README.md  CHANGELOG.md  LICENSE  THIRD_PARTY_NOTICES.md
  lib/…  data/…  assets/shaders/…  (no baseroms/, no PNGs derived from ROMs)
```

**manifest.json:**

```json
{
  "id": "EMERALD_3D", "name": "Emerald 3D", "version": "0.1.0-beta", "api": 2,
  "entry": "main.lua", "profile": "overhaul", "category": "GRAPHICS",
  "games": ["emerald"],
  "game_version": ">=0.3.52 <0.4.0",
  "priority": 100,
  "dependencies": [],
  "optional_dependencies": ["STADIUM2_IMPORTER"],
  "dependency_sources": { "STADIUM2_IMPORTER": "Deftones565/gen1recomp-mod-stadium2-importer" },
  "conflicts": ["BATTLE_ART_VOXEL_FORK", "DRAMATIC_SHAPE", "DRAMALESS_SHAPE", "potato_voxel", "VOXEL_ASCENDANT"],
  "permissions": ["engine_internals", "background"],
  "github": "DJMAccie/Emerald-voxel-mod",
  "optional_imports": []
}
```

- `games: ["emerald"]` keeps it off Ruby/Sapphire/FRLG until tested there.
- `background` is only needed if Fly sheet generation or a Colosseum import runs in `mod.job`.
- M5 adds the Colosseum disc to `optional_imports`.

**Gen 1 require fix:**
- Today the boot error feed shows `requires src.world.Map … no adapter`. It comes from the Gen 1/2 half of the old mod (`main.lua:1891`, and `lib/MapCompat.lua` probing it).
- The new mod is Emerald-only and never requires `src.world.*`, `src.core.Game`, `src.battle.BattleState` or other Gen 1 modules.
- Enforce it with a lint step in the package build (grep for those names, fail the build) and with `python3 tools/modkit.py lint` in the gen1recomp checkout.

**Sandbox hygiene:**
- No `os.getenv`, `loadfile`, or `love.mouse*` assignments (use `mod.hooks`/`mod.events`).
- Read files only through `mod:read`.
- The current mod logs warnings for all of these; the new one must boot with zero warnings.

**Build script:**
- `tools/package.sh` in the clean repo: copy the allow-listed paths, run lint + simcheck + `modkit validate/pack`, and write the zip and its SHA-256.
- Installing for tests goes into a clean QA identity only.
- Publishing to GitHub only on Petya's go.

## 6. Risks and decisions

**Risks**

1. **Size.** About 72k lines of behaviour to re-create, 17-25 weeks overall. Group 1 has two very large files: CommunityFlora at 7.9k lines and Structures at 5.1k. Their specs alone are big jobs. Mitigation: per-family specs, each with its own golden spots.
2. **Clean-room strength.** The same model and the same person have read upstream (section 2, honest limit). Mitigation: separation, deny rules, reviewed specs, simcheck, provenance log.
3. **Exact visual parity is unlikely.** The gates prove heights, classes and placement exactly. Textures and lighting will differ slightly. Mitigation: R-24 judging against the 2D art, not against the old 3D; differences listed per spot.
4. **Gate drivers depend on old internals.** M0's neutral probes are the fix. Until then the baseline can only be taken with today's drivers.
5. **The engine keeps moving** (0.3.52 → 0.3.95 already). Mitigation: target the engine's public mod API, and pin `game_version`.
6. **Work on today's game continues in parallel** (task 34 etc.). Every change to the old mod during the rewrite also needs a spec delta. Mitigation: freeze new features in the old mod while M1 runs, or log each change as a spec delta the same day.
7. **QA environment.** `qa_run.sh` hangs today (see top). M0 depends on reliable QA runs.

**Decisions for Petya**

1. Is a beta after M1 (overworld 3D + 2D battles) acceptable as the first public drop-in?
2. Who reviews specs for code leakage: Petya, or a separate reviewer session (and is a session acceptable)?
3. Colosseum PKX/HSD parsing: write it from format documentation (slow), allow one GPLv3 module derived from StarsMmd's addon, or leave Colosseum out of the beta?
4. Ship the 13 hand-drawn fly sheets (your pixels, Pokémon designs), or use ROM-generated sheets for all species?
5. World fill: keep the traced ids with credit to darkshadedx, or re-derive from ROM border data?
6. Licence for the new code (MIT suggested), and the repo: build in a new `~/Documents/emerald3d` that pushes to DJMAccie/Emerald-voxel-mod?
7. Feature freeze on the old mod during M1: yes, or keep working with same-day spec deltas?
