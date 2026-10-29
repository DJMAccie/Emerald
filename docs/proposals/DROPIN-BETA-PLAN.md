# Emerald 3D drop-in public beta: findings and plan

Status: PROPOSAL, read-only investigation 2026-10-29. Nothing built, installed, committed or pushed.
Needs Petya's go (and one decision, section 6) before any build step starts.

## TL;DR

- **Installing is easy.** The launcher takes a `.zip` dropped on its window (or from "Import mod .zip", a mod index, or a GitHub release). The zip needs `manifest.json` at its root or in one top folder. It must not contain `baseroms/`.
- **The engine patch is not needed any more.** The game Petya and QA run today (v0.3.52 checkout, auto-updated to the v0.3.95 payload) runs Emerald with the patch not applied. The patch no longer applies cleanly to either version.
- **Stadium 2 already reads the player's ROM inside the game**, in Lua (`required_imports`). **Colosseum can too:** the engine allows ranged reads of an imported file up to 2 GiB, and the Colosseum ISO is 1.46 GB. That means a Lua port of `colo2dsm.py` plus its helpers, with a licence catch (section 4).
- **The blocker is the code, not the launcher.** A runtime trace of 18 maps plus a battle shows Emerald play loading **125 unmodified upstream files (~52k lines)** and **all 49 upstream files we modified** (their ~31k base lines plus our +8.5k). It also loads 50 of our own new modules and the building data. The core Gen 3 renderer (Gen3Scene, Gen3Elevation, Gen3Cave, Voxel3D, Water, Sky, ChunkMesher …) is upstream code that upstream wrote for FireRed, and our Emerald work is layered on it. Upstream (notquiteog/DramaticShapeVoxelMod) **still has no licence** (checked on GitHub today; it is at v1.58.3 and our base is 03882a9).
- **Recommendation:** ask notquiteog for a permissive licence first (cheapest path by far). In parallel, prepare the asset clean-up, which is needed on every path. Only if they refuse or don't answer, choose between an add-on on top of upstream (fragile) and a clean-room rewrite (6-12 weeks).

---

## 1. How the gen1recomp launcher installs mods

Source: `~/Documents/gen1recomp` (tag v0.3.52) `src/mods/LauncherMods.lua`, `src/import/RomImporter.lua`, `src/mods/Loader.lua`, `src/mods/Sandbox.lua`, `src/mods/RequiredImports.lua`, `src/mods/ImportAccess.lua`, `CONTRIBUTING-mods.md`. I checked the same files in the v0.3.95 payload (`~/Library/Application Support/pokemon-love2d/updates/gen1recomp-0.3.95.love`).

**Ways in**
- **Drag and drop.** `RomImporter:filedropped` (RomImporter.lua:2498): a dropped `*.zip` on any tab except SKINS goes to `LauncherMods.installZip`.
- The "Import mod .zip" picker, the `imports/mods/` inbox rescan, mod-index feeds (`ModIndex.lua`) and GitHub releases (`installFromRelease`, which uses manifest `github`) all go through the same `installZip`.
- Only `.zip` is accepted. A `.love` file or a bare folder is not. A folder copied by hand into the mods directory also works, and `adoptStrays` picks up folders placed next to the executable.

**Zip rules** (`installZip`, LauncherMods.lua:1023)
- It must hold `manifest.json` at the root or inside exactly one top folder.
- A non-empty `baseroms/` is refused.
- It installs to `mods/<manifest.id>/` in the save dir, or in the game folder on portable installs.
- A same-id mod is refused unless it is an update (`opts.replace`).

**Manifest fields that matter here** (see the installed `BATTLE_ART_VOXEL_FORK/manifest.json`)
- `id`, `name`, `version`, `api: 2`, `entry`, `profile`, `category`, `priority`.
- `games`: `"gen3"`, `"rse"` (Hoenn family) or `"emerald"`.
- `game_version` (semver range), `permissions`: `engine_internals` (manager shows "PATCHES ENGINE CODE"), `network`, `background`/`compute`.
- `required_imports` / `optional_imports` (ROM/disc files the player gives the launcher).
- `required_assets` (engine importer packs).

**Can one mod require or override another?**
- `dependencies` (hard, with semver `range` and per-`games`) and `optional_dependencies`.
- `conflicts`: a listed mod that is enabled blocks the load.
- `dependency_sources`: `{ID = "owner/repo"}`. The manager shows a missing dependency with its GitHub repo, so the player can fetch it from its own author (`resolveDependencyRepo`, LauncherMods.lua:115/190).
- Load order = `priority` plus the player's own ordering.
- There is **no file override**: a mod cannot replace another mod's files. Mods talk through `mod.exports` / `mod.find(id).exports`. Upstream Battle Art exports its private module loader as `exports.lib = V` (main.lua:2359, Gen3Integration.lua:257), so another mod can reach and patch its modules after they load.

**Sandbox limits**
- Every mod chunk runs sandboxed: no `io`/`os`/`ffi`/`debug`/`love.thread`, and no bytecode. Files are read through `mod:read`; storage goes through `mod.storage`.
- Imported ROM/disc bytes are read through `mod.imports:read(id, offset, length)`, at most 8 MiB per read.
- Generated data goes to `mod_cache/<id>/`, at most 64 MiB per write (ImportAccess.lua).
- Our mod already lives with this. It logs compat warnings for `os.getenv`, `loadfile` and `love.mouse*` assignments, which a public build should migrate.

## 2. What Emerald play loads from the installed mod

**Method**
- The Gen 3 branch is clean: mod `main.lua` lines 1-84 set up `V.require`/`V.data`, and line 82 calls `Gen3Integration.install()` and returns. All lib loading goes through `V.require('Name')` / `V.data('Name')`.
- I built the require graph from there (`docs/proposals/dropin/graph.py`; there are only 3 dynamic requires, all resolved). I classified every installed file against base 03882a9 by git blob hash (`classify.py`).
- **Runtime trace (done 2026-10-29):** `docs/proposals/dropin/trace_driver.lua` wraps a QA driver, logs every file the game opens, and at the end reads the mod's own module cache (the `V.require`/`V.data` upvalues), which also catches modules loaded before the driver started. It ran through `tools/qa_tryp.sh` (private QA copies -p1/-p2) on 18 maps (towns, routes, caves, gyms, interiors, sea, Safari, Abandoned Ship) plus one wild battle (`em_battle_driver.lua`). Result: `docs/proposals/dropin/runtime_files.tsv`.
- **Caveat:** images the engine loads for the mod through its own helpers may not all show up. Fly was not exercised; its files are ours.
- **QA environment note:** plain `tools/qa_run.sh` on the main QA identity (`pokemon-love2d-rseqa`) hangs today with no frames, even for one map; the private copies work. Not investigated further.

**Installed mod: 11,258 files**
- 10,950 identical to upstream: assets/crystal 9,168, bw-battle 779, bw-front-animated 773, lib 201, data 23, main.lua, manifest, mod.card.
- 51 upstream files modified: 49 in lib, 1 in data, plus THIRD_PARTY_NOTICES.
- 257 ours: data/buildings 124, assets/flyers 77, lib 53, worldfill 2, data 1.
- Note: the mod source checkout `~/Documents/battle-art-notquiteog` has HEAD = 03882a9 with all our work uncommitted (236 changes). The canonical copy of our work is `patches/battle-art-voxel-fork.patch` in this repo.

**Runtime set (what Emerald play actually loaded): 351 files.** 125 unmodified upstream files (51.9k lines), all 49 modified upstream files (39.1k lines now), 176 ours (modules + building data).
- Upstream assets actually loaded: `assets/crystal/depth-crowns-v2.png` (tree crowns), and the data tables `animated_battle_sprites_gen2..5*`, `animated_battle_backs_gen3`, `bundled_bw_fronts`, `crystal_full_body` and `animated_player_trainers` (these name Nintendo sprite files). Also `assets/battle/back-animated/gen1player.png` was looked up but not shipped.

**Static reachable set (upper bound): 282 files** (list: `docs/proposals/dropin/gen3_reach.tsv`)
- **182 unmodified upstream (~62.9k lines).**
  - Renderer core: Voxel3D-adjacent ChunkMesher (4.7k), VoxelMeshDisk, TerrainAtlas, TileShape, Water, Sky, ShadowMap, Mat4, BuildBudget, ModSetting, CommunityVisuals, Buildings, InteriorFurniture, FirstPerson/ThirdPerson.
  - About 40 Gen2* helpers (Gen2Trees, Gen2Rocks, Gen2Ledges, …).
  - Battle presentation (BattleArt UI pieces, Pokeball, ModernBattleUI).
  - data/voxel_heights.lua (8.3k), the animated-sprite tables (data/animated_battle_sprites_gen2..5*.lua) and data/bundled_bw_fronts.lua.
- **49 upstream files we modified** (their base 30,953 lines; our diff +8,496/-398): Gen3Scene (851 → 3,481 lines), Gen3Elevation (86 → 1,418), Gen3Integration, Gen3Cave, Gen3Tilesets, Gen3Terrain, Gen3Stairs, Gen3Furniture, Gen3Battle, Voxel3D, VoxelHull, VoxelScene, Water-adjacent, NativeTreeArt, TreePresentation, StadiumModels, data/gen3_stairs.lua, …
  - Upstream already had a FireRed Gen 3 renderer; our Emerald work is layered on it.
- **51 ours** (50 lib modules, 77.7k lines including large data tables: Gen3Relief*, Gen3Blocks, Gen3Hills, Gen3FlyOver/FlyPath, Gen3CamClear, …) plus data/buildings (25 MB, geometry only: tile ids and quads, no pixels).

**Upstream (Nintendo-derived) assets the Gen 3 path can load**
- `assets/bw-battle` (lib/BattleArt.lua): bundled BW battle backs, used when the Battle Art sprite setting is ANIMATED.
- `assets/bw-front-animated` (lib/AnimatedBattleArt.lua).
- `assets/crystal` (BattleArt, AnimatedBattleArt, Buildings, CommunityVisuals, CaveAtmosphere3D, gen2 tables).
- `assets/battle/...` (4,510 paths named in the animated-sprite data tables; that folder is empty in our install, so it is an external atlas pack).
- None of these can ship. Emerald's own art comes from the player's ROM through the engine, so Emerald needs none of them except as an optional style.

**Our assets that also cannot ship as they are**
- `assets/flyers`: 23 sheets baked from the follower mod's followsprites, plus Charizard and Murkrow from PMD walk sprites. These are Nintendo/Spike Chunsoft-derived.
- The 13 hand-drawn flyers are Petya's pixels but are still Pokémon designs. That is a fan-art grey area; Petya decides.
- `assets/worldfill/fill.bin`: metatile ids traced from darkshadedx's fan region map. Ids are facts and the game draws them from the ROM tiles, so the risk is low. Credit darkshadedx, or re-derive from ROM border data.

## 3. Is the engine patch still needed?

**No: not on the current launcher, and Emerald play does not need it.**

**Evidence**
- `patches/gen1recomp-engine-rse.patch` applies **neither forward nor in reverse** to the v0.3.52 checkout.
- The checkout has `Gen3Compat.FAMILIES = { frlg = true }` and no `wrapPictures`, so the patch is not active.
- QA logs from these runs (e.g. `.autoloop/runs/b14jp/.../run.log`) play Emerald fine and print `BATTLE_ART_VOXEL_FORK: requires src.world.Map … no compat layer has no adapter`. So the Gen 1 compat facade is not running on Emerald, and nothing breaks.
- In v0.3.95 (the payload the launcher now hands off to) the map-prefix part of the patch is upstream: `Gen3Compat` reads `enginePrefix` from the session profile. `FAMILIES` is still FRLG-only, and `wrapPictures` is absent.

**The patch's remaining two parts**
- (a) The Gen 1 compat facade on RSE: we don't use it.
- (b) `wrapPictures`: it fixes a Kanto in Motion recursion, not ours.

**Package fix needed:** guard the mod's Gen 1-only requires (`src.world.Map` etc.) behind the generation check. Otherwise the launcher lists that error line on the player's boot error feed.

## 4. Stadium 2 and Colosseum models

**Stadium 2: in-game import is already done.**
- `STADIUM2_IMPORTER` declares `required_imports: stadium2_rom` (N64, md5-checked). The engine copies the player's ROM into the mod's `baseroms/`, and the importer extracts models in Lua (`lib/importer.lua`, `workers/`).
- Our changes to it (`patches/stadium2-importer.patch`) touch battle_router, gen3_battle, importer, layout, pack, rom, main.lua and manifest, and add `lib/colosseum.lua`. That code is Deftones565's, and the repo has no licence (`gh` says NONE). It is at v0.25.0 upstream; we run 0.21.0 + patch.
- For the beta: offer the changes upstream as a PR, or move them into our mod as runtime patches through the importer's exports, and keep the importer an optional dependency with `dependency_sources`.

**Colosseum: an in-game Lua import is possible.**
- Today `tools/colo2dsm.py` (365 lines) + `fsys.py` (54, LZSS) + `gciso.py` + `pkx_to_ir.py` turn `~/Documents/colosseum-work/colosseum.iso` into 450 DSM packs (129 MB). The packs live inside STADIUM2_IMPORTER/colosseum/, and `lib/colosseum.lua` reads them with `mod:read`.
- An `optional_imports` entry for the disc works:
  - The ISO is 1,459,978,240 bytes, under the 2 GiB `RequiredImports.MAX_BYTES`.
  - Ranged 8 MiB reads cover the GCM file table, FSYS and LZSS.
  - Conversion can run in `mod.job` (background permission), writing packs to `mod_cache/` in pieces of 64 MiB or less.
- **Catches:**
  - The launcher MD5s an import by reading it whole into one Lua string (RequiredImports.lua:38-41). That is ~1.5 GB of RAM at import: fine on a Mac, risky on handhelds and phones. A `max_size` spec without `md5` still reads it whole; a later engine RFC could add streaming MD5 (StreamMD5.lua exists).
  - **Licence:** the PKX/HSD parsing comes from StarsMmd's Blender-Addon-Gamecube-Models, which is **GPLv3** (~72k lines of Python; we use its extract/route/parse/describe phases). A Lua port is a derivative, so that module would have to be GPLv3. That is compatible with the GPLv3 engine, but it breaks the "own code + MIT only" rule unless Petya accepts one GPLv3 module (or we clean-room it from format notes, which is much slower).
- **Fallback:** ship `colo2dsm` as an external tool. That means much more friction, and players need Python. Or ship the beta without Colosseum: Hoenn species then use ROM sprites.

## 5. Plan for a standalone drop-in package (own code only)

"Standalone" here means one zip that needs no other mod installed. Stadium 2 and Colosseum stay optional extras, and the zip contains no ROM-derived bytes.

| # | Step | Effort | Risk |
|---|---|---|---|
| 0 | **Licence ask.** Petya writes to notquiteog asking for MIT (or written permission to redistribute a fork without assets), and to Deftones565 for the importer. | 1 h, then waiting | They refuse or stay silent → steps 3B/3C. |
| 1 | **Runtime trace.** DONE for 18 maps + a battle (125 upstream + 49 modified). Optional: add Fly and the remaining maps. | 0.5 day | — |
| 2 | **Asset clean-up (needed on every path).** Drop assets/crystal, bw-*, the animated-sprite tables and bundled_bw_fronts from the Gen 3 path; default Battle Art to ROM art. Replace the 25 borrowed flyer sheets with sheets made at first run from the ROM's own sprites, or ship only Petya's 13 drawn ones if Petya accepts that. Credit or re-derive worldfill. Guard the Gen 1 requires. | 2-4 days | Fly looks worse for species without a drawn sheet. |
| 3A | **If upstream grants MIT:** package our fork tree minus assets, with upstream's notice + ours. New id `EMERALD_3D`, `games: ["emerald"]`, `conflicts` with upstream ids, `game_version ">=0.3.52 <0.4.0"`. Build script copies from the installed tree and runs `tools/modkit.py validate/lint/pack`. | 2-3 days | Low. |
| 3B | **If no licence: add-on on upstream.** Hard-depend on DRAMATIC_SHAPE (upstream's id) via `dependency_sources`, so the player gets it from notquiteog. Ship only our 50 modules + data. Turn our 49 in-place edits into runtime patches through `exports.lib` (V). Rebase all of it from base 1.28.x to upstream 1.58.x first. | 2-4 weeks, plus breakage on every upstream release | High: upstream's own Gen 3 code moved 30 versions. V's module cache is private, so whole-file replacements (Gen3Scene grew 4x) are awkward. |
| 3C | **If no licence: clean-room.** Rewrite the 125 + 49 upstream modules the trace lists (~91k lines) (renderer core, mesher, atlas, water, sky, battle stage) against the engine API, by behaviour spec. Our 50 modules stay. | 6-12 weeks | Proving "clean room" is hard after months of reading their code; feature regressions. |
| 4 | **Stadium 2 hookup.** Upstream PR, or runtime patches for our importer changes; `optional_dependencies` + `dependency_sources: Deftones565/...`. | 2-4 days | Depends on Deftones565. |
| 5 | **Colosseum in game.** `optional_imports` for the disc; Lua port of gciso + fsys/LZSS + PKX/HSD parse + colo2dsm in `mod.job`; packs to `mod_cache/`. Needs the GPLv3 decision. | 2-4 weeks | RAM at import; GPLv3. |
| 6 | **Beta packaging + docs.** README, mod.card (`differences.known` honest), CHANGELOG, licence file (Petya chooses, e.g. MIT), THIRD_PARTY_NOTICES (FSR1 MIT, Voxel Ascendant weather MIT), a `modkit` test, and a GitHub release on DJMAccie/Emerald-voxel-mod (Petya's go before any push). | 1-2 days | — |
| 7 | **Gates.** Install the zip into a clean QA identity (empty mods dir); run the gates + before/after sheets vs the current install; check that the boot error feed is empty. | 1 day | — |

**Totals**
- Path A (licence granted): ~1.5-2 weeks to a beta, or ~4-6 weeks with in-game Colosseum.
- Path B: ~4-6 weeks plus ongoing upkeep.
- Path C: ~2-3 months.

## 6. Decisions for Petya

1. Ask notquiteog (and Deftones565) for a licence now? (Recommended: yes, first.)
2. If they refuse: add-on on upstream (3B) or clean-room (3C)?
3. Colosseum: accept one GPLv3 module for an in-game import, keep it an external tool, or leave it out of the beta?
4. Hand-drawn flyer sheets (Pokémon designs, Petya's pixels): ship them or not?
5. Licence for our own code (MIT suggested).

## Files

- `docs/proposals/dropin/trace_driver.lua`: runtime file-open tracer. Usage: `EM_INNER=<driver> EM_DRIVER=docs/proposals/dropin/trace_driver.lua tools/qa_run.sh <out> "<cases>"`, writes `<out>/files.log`.
- `docs/proposals/dropin/graph.py`, `classify.py`: static Gen 3 graph and the upstream/ours classifier.
- `docs/proposals/dropin/gen3_reach.tsv`, `classes.tsv`: outputs (class, file, first requirer).
