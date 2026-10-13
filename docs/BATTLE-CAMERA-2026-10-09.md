# Battle scene: the rake, the cuts, and the 3 fps bug — 2026-10-09

Round requested: "the camera needs to turn about 15 degrees clockwise", "cut to
different angles like Colosseum and Stadium", "get rid of the big white block",
"import the attack moves from Stadium and Colosseum". Plus, mid-round from the
user: "it's super slow".

Everything below is installed in the real game and in QA, and every number is
from a capture, not from reading code.

## 1. The engine moved under the mod (read this first)

The user's fight at 16:55 was engine **0.3.69**. The app downloaded **0.3.70**
at 16:40 and `notes_cache` was written at 17:01 — the running session stayed on
0.3.69, so **the first restart changes which renderer draws an Emerald battle**.

On 0.3.69 the mod's `Generation.isGen3()` read false at load time, `main.lua`
fell through its Gen 3 gate, and the whole Gen 1/2 facade installed: the staged
`OverworldBattle` arena with `BattleCam`. On 0.3.70 the same call reads true, the
gate returns early into `Gen3Integration`, and Emerald is drawn by
`Gen3Battle`/`Gen3Scene` — a different camera, a different HUD, and a different
textbox path.

This is why the round's work had to be done against 0.3.70, and it is why the
camera work landed in `lib/Gen3Battle.lua` rather than `lib/BattleCam.lua`: on
Emerald the staged rig is not the one on screen. `BattleCam` keeps the director
too, for the generations that do stage through it.

QA was rebuilt for this: the 0.3.54 cache was stale, the headless importer
rebuilds it, `tools/qa_battle.sh` now drives the battle capture and
`tools/em_battlecam_driver.lua` reports cuts and frame time.

## 2. The 3 fps bug (`lib/Gen3SceneCache.lua`)

**Symptom.** A battle ran at 3.4 fps (mean 290 ms/frame). The overworld on the
same map ran at 60.0. Turning `3D-BTL` off restored 60.0, so it was the battle
scene and not the driver.

**Cause.** The scene cache key included the battle camera's **yaw**:

    parts[#parts+1] = 'battle:' .. center[1] .. ':' .. center[2] .. ':' .. cam.yaw

Geometry is world-space — nothing `build()` produces changes when the eye swings
around it — so this keyed a *rebuild* on a value that had not changed anything.
Battle Art's camera moves constantly by design (the drift, the player's orbit,
and now every cut in `BattleShots`), so the whole cell range was rebuilt every
frame of every fight.

**Fix.** Ground, not yaw: `battle:centerX:centerZ`. The arena still owns the cull
(a different patch of ground still rebuilds); the swing no longer does.

**Measured.** 3.4 fps → **59.8 fps** (mean 290.6 ms → 16.7 ms), which is the
overworld's own frame time. A regression guard is in
`tests/gen3_scene_cache_test.lua`: a camera swing must not change the key, the
rested rake must not either, and a different patch of ground must.

The same key is built a second time in `lib/Gen3Scene.lua` and was fixed there
too.

## 3. The rake: 15 degrees, clockwise

`BattleShots.SCENE_RAKE` is the arena's rest heading, added to `camera.arenaYaw`
once when a fight opens. `camera.arenaYaw` is the line the two actors stand on,
so raking it separates them across the frame instead of stacking one behind the
other.

**The sign is the finding.** The first value tried (+15) turned the picture
counter-clockwise and the user rejected it; the constant is therefore negative
and the comment says so. Do not flip it without a captured frame to point at.

Two bugs found while getting there, both worth remembering:

* the offset was **re-applied every frame**. `M.orbit` rebuilds `camera.yaw` from
  `camera.arenaYaw`, so a rake written in the orbit walks 15 degrees a frame and
  the fight opens looking backwards. It belongs in `arenaYaw`, applied once.
* `SCENE_RAKE` was in **degrees** and was being added to a radians heading. One
  constant, one unit.

**Evidence.** `shots_bt/yaw15` vs `shots_bt/yaw-15` (same frame, same fight): at
−15 the trainer takes one third of the frame and the Lotad sits off-centre with
its own ground; at +15 the two overlap on the centre line.

## 4. The cuts (`lib/BattleShots.lua`, `lib/Gen3Battle.lua`)

`BattleShots` is a small sequencer with the fight's own events for a clock. It
wraps nothing and patches nothing: it reads the live battle state the engine
already maintains and asks for a shot on each beat.

    move announced     hold the wide shot (the attacker is composing)
    animation starts   CUT to the attacker's side, low and hard off-axis
    impact             CUT to the target's quarter, raised
    everything settles GLIDE back out to the wide shot

Five angles, each a change from the rest pose: `wide`, `attacker`, `reverse`,
`target`, `settle`. The staged camera (`BattleCam`) and the scene camera
(`Gen3Battle`) each have their own table, so the beats read as the same sequence
on both paths even though the numbers differ.

**Ownership.** The player outranks the director. A steer moves a goal off the
shot and releases the director for the rest of the battle
(`BattleCam.setAxis` → `releaseShot`); the sequence stops re-aiming rather than
fighting the stick.

**Row.** `BATTLE CAMERA` — ON / CINEMATIC / OFF, default ON, in the mod manager
and the OPTIONS menu. CINEMATIC pushes the angles further off the axis.

**Verified.** With the menu automation unable to reach Emerald's FIGHT menu, the
beats were forced through `G3.directScene` (a public seam for QA) with a settle
window, and the camera reached each shot:

    attacker  CUT  → relYaw  +48.7  pitch +0.223
    target    CUT  → relYaw  -1.3   pitch +0.764
    settle    GLIDE→ relYaw  +17.4  pitch +0.594
    wide      GLIDE→ relYaw  +14.7  pitch +0.395

What is *not* yet verified end to end is the battle-driven sequencing — cuts
firing off a real move — because the automation cannot open the FIGHT menu. That
needs one played fight.

Two bugs found here: the ease `x = target + x*(1-dt*5)` converges to
`target/(dt*5)`, i.e. **five seconds' worth of the target** — at 60hz it settled
fifteen times too far, which is the "camera swings the whole way round during the
send-out" behaviour. Replaced with an exponential ease on a time constant
(`M.ORBIT_TIME = 0.30`). And `take(name, cut, scene)` closed over two locals
declared *below* it, so the scene path silently declined every shot.

## 5. The white block

`TEXTBOX FILL` is now **OFF by default** (the ladder is unchanged, so a stored
choice still means what it meant). That is the whole change on this path: the
Emerald textbox handler already had a paperless branch — it skips the paper
rectangle and draws the glyphs in white with a dark shadow.

**Evidence.** `shots_bt/final/*.png`: "Wild LOTAD appeared!" as white text with a
shadow directly over the grass, no slab. It is the look in the reference
screenshots.

On the staged path (Gen 1/2) the same setting feeds `TextboxStyle.withFill`,
which drops the opaque-white paper and keeps borders and ink.

`ARENA FILL: WHITE` still forces paper, because a solid white field needs a
black-ink box on it.

## 6. Move animations: what is already there, and what is not

Answering "can we import the attack moves with their animations from Stadium and
Colosseum" — **partly, and the model half is already wired.**

**Model animations: already imported.** `Gen3StadiumModels` wraps
`Anim.launchMove`, and when a move launches it calls the importer's
`instance:playMove(moveId)`. The importer's Stadium 2 pipeline carries the
per-species dispatch table (`lib/animation_dispatch.lua`) that maps all 251
Stadium 2 moves onto that species' pose clips, with
`lib/animation_semantics.lua` naming the roles. So a Gen 1/2 species throwing a
move already plays *that move's* body clip, not a generic swing. Moves past #251
proxy by category (`physical/special/status` → Tackle/Ember/Growl), which is the
honest limit of a GameCube-era source.

**Move EFFECTS (the particles, beams and screens): not imported, and it is a
project.** Stadium 2's effects are a separate CPU-driven system in the importer
(`lib/stadium2_battle_fx_*`, ~20 modules: emission markers, lifecycles, ribbons,
wave grids, beams), with its own audit in
`stadium2-importer/docs/battle_fx_missing_implementation_audit.md`. Wiring it to
Emerald means driving that runtime from the engine's own move timeline and
drawing it through `Gen3Scene`'s camera. That is a self-contained feature with
its own performance risk, and it should be its own round.

**Colosseum effects** are not a like-for-like source at all: `colosseum-work`
holds the model conversion path (PKX → DSM), not an effect pipeline, and the
Stadium 2 FX runtime does not read Colosseum data.

## 7. Files

| File | Change |
|---|---|
| `lib/Gen3SceneCache.lua` | battle key is ground, not yaw (the 3 fps fix) |
| `lib/Gen3Scene.lua` | same key built a second time; routes `src.world.Map` through `MapCompat` |
| `lib/Gen3Battle.lua` | rest rake, shot sink, `directScene` seam, exponential ease |
| `lib/BattleShots.lua` | new: the director (beats, per-path angle tables, sink) |
| `lib/BattleCam.lua` | shot API (`direct`/`releaseShot`/`shotHeld`), signed orbit, `OPEN_*` pose |
| `lib/UiBackplates.lua` | `TEXTBOX FILL` defaults to OFF |
| `lib/MapCompat.lua` | new: one denied Gen 1 module must not take the 3D game with it |
| 9 modules | `src.world.Map` require routed through `MapCompat` |
| `lib/SettingsCatalog.lua`, `lib/OptionSupport.lua` | `BATTLE CAMERA` row and per-generation support |
| `tests/gen3_scene_cache_test.lua` | regression guard for the cache key |

Backups of the replaced install: `backups/2026-10-09-battlecam/`.
New tools in this repo: `tools/qa_battle.sh`, `tools/em_battlecam_driver.lua`,
`tools/em_battleperf_driver.lua`, `tools/em_perf_driver.lua`.

## 8. Open

1. **The battle-driven cuts need one played fight.** The mapping is verified;
   the cues are not.
2. **`src.world.Map` on an Emerald boot.** Engine 0.3.70's loader reports
   `BATTLE_ART_VOXEL_FORK: requires src.world.Map, which a Gen 3 game never runs`
   once per boot. `Gen3Compat.serves('src.world.Map')` is true (its adapter
   exists) but `appliesTo('emerald')` is false, because `Gen3Compat.FAMILIES` is
   `{ frlg = true }` — the adapter is FRLG-shaped and Emerald is `rse`. The
   report is honest; the fix here only stops one denied module from taking
   `VoxelScene` (and so `Gen3Scene`) down with it. Worth raising upstream: a RSE
   boot now reaches that guard through every Gen 3 mod that also ships Gen 1
   paths.
3. `hudScale`, `HUD COLOR` and the modern status cards are untested by me on
   Emerald.

---

# Round 2 — move effects: findings, 2026-10-09

Goal: import Stadium 2's move effects (not just the body animations), and
answer whether XD: Gale of Darkness is a usable extra source.

## Stadium 2 effects: the data is there, the decoder disagrees with the extractor

Both halves of the pipeline exist and are complete on their own:

* `lib/stadium2_battle_fx_*` — 11,572 lines, ~20 modules: catalog, ROM decode,
  effect programs, emission markers, lifecycles, beams, ribbons, wave grids,
  particles, and a `battle_fx_battle_adapter` that already drives all of it from
  live battle state (its `playMove`/`playVariant`/`playCharge` know about
  two-turn moves).
* `Importer.newBattleFxPlayer` is a public export with working defaults.

A clean reimport (QA Stadium 2 cache deleted, fresh import, 251/251 species)
does write the three FX specials. Read back through the importer's own cache
reader:

    battle_fx_rom        695,280 bytes
    battle_fx_trig        20,480 bytes
    battle_fx_resources 1,507,328 bytes

So **nothing needs 3D work to get the effects** — it needs one offset bug fixed.

`BattleFxRom.catalog()` then refuses:

    program 0: effect program pointer is outside fragment 79

The cause is a base disagreement, and it is measurable. `PROGRAM_TABLE` is
`0x84182154`; through `romOffset` that lands at slice offset `0x82154`, whose
first six entries are **all zero**. Scanning the same slice for a run of
plausible VRAM pointers finds one 520 entries long at slice offset `0x89370`
(`0x84114018, 0x84114054, 0x84114090, ...`) — a real pointer table, **0x721C
bytes further in** than where the decoder looks. The extractor slices
`0x36F890..0x419480` and the decoder resolves against `ROM_BASE = 0x36F890`,
and the two do not describe the same fragment 79 layout in this ROM.

Both files are byte-identical to upstream's `origin/main` (v0.25.0), so this is
not a stale local copy.

**What fixing it needs.** Either the VRAM layout constants for this ROM
revision (`ROM_BASE`, `PROGRAM_TABLE` and friends — ten minutes with the scan
above if one of them is simply wrong), or a re-derivation of the extraction
window (the reverse-engineering the module's own comments document in detail).
Worth doing: the decoder, the player and the adapter are already written and
tested upstream, so this unblocks all 251 moves' effects at once.

## Model move animations: wired, but the lookup fails on Emerald

`StadiumModels.update` fires on the rising edge of a move animation and calls
`instance:playMove(move)`. It gets `move` from:

    local def = battle.data.moves[battle.animName]
    local move = def and tonumber(def.index or def.number)

That is the Gen 1/2 `battle.data` shape. On Emerald there is no matching row, so
`move` is nil, the `playMove` call is skipped, and every move falls back to
`playContext(actor, "attack")` — the generic swing. Easy fix, but the correct
Gen 3 move-number source has to be identified first, and the fallback has been
silently hiding it.

`instance:moveSelector(move)` returning nil for every move is not evidence
either way: `Pack.moveSelector` reads `model.moveAnim`, which the public
instance API does not expose. The failure above is the leading explanation.

## Ready to try

`Importer.reimport()` on a current cache returns `true, "ready"` and does not
rebuild if the version matches, so the QA cache was cleared to force a real
import. A reimport is also the only way to pick up a fixed decoder, since the FX
specials are cache data rather than shipped assets.

---

# Round 3 — the move animations were never being asked for, 2026-10-09

Objective item: "a move plays its real Stadium 2 visual (not a proxy)".

## What was actually wrong

Two independent breaks, either of which alone would have produced the generic
swing. Both are now fixed and installed.

**1. The trigger never fired.** `StadiumModels.update` plays a model's move clip
on the rising edge of `battle.animPlaying` — that is how the Gen 1/2 battle
states announce a move animation. **The Gen 3 battle has no such field.** It
launches effects through `Anim.launchMove`, which `Gen3StadiumModels.install`
already wraps — and the hook only set a `pendingMove` latch that nothing ever
consumed. So on Emerald the edge never rose, the `playMove` branch was never
reached, and every move fell through to `playContext(actor, "attack")`: a
generic swing with no relation to the move.

**2. The move number was never found.** Even with the trigger firing,
`StadiumModels` resolves the move through
`battle.data.moves[battle.animName].index`. On Gen 1/2 that table is the
battle's own move list. On Gen 3 the adapter published
`data = { moves = {}, pokemon = {} }` — an empty table — so the lookup found
nothing. The engine does have the mapping, by the same names:
`Moves.numForName("TACKLE")` answers the cart's move number.

## The fix

`lib/Gen3StadiumModels.lua`:

* `data.moves` is a table with an `__index` that resolves an animation name to
  `{index = <move number>}` through `Moves.numForName`, caching hits and misses.
  A warm list of the ~33 names a battle is likely to use is resolved at adapter
  build so no frame pays for the move-table build mid-animation. Unknown names
  still resolve on demand — it is a cache, not a whitelist.
* `performPendingMove` consumes the `launchMove` latch: it translates the move
  through the same `M.selectorFor` proxy the provider's table uses, publishes it
  to a battle view in the shape `StadiumModels` reads, lowers the provider's own
  rising-edge latch (two moves in consecutive frames must both play), runs the
  trigger, and restores the battle's fields. Called at the top of `M.update`, so
  the model starts its move on the frame the engine starts its effect.
* `M.status()` and `battle.detail` now report `context`, `lastMove` and
  `lastMoveOk`, so "did the model play the move or swing?" is answerable from a
  log instead of by eye.

## Evidence

A staged Emerald fight, engine 0.3.70, player Treecko (Pound, #1) against a wild
Lotad (Absorb #71, Tackle #33). The `move:<n>` key in these lines is one only
the new handoff creates — the engine never names an animation that way:

    t= 513  move trigger: name= move:1   side=player move=1  ok=true
    t= 603  move trigger: name= move:71  side=enemy  move=71 ok=true
    t=1067  move trigger: name= move:1   side=player move=1  ok=true
    t=1160  move trigger: name= move:33  side=enemy  move=33 ok=true
    t=1295  move trigger: name= move:1   side=player move=1  ok=true

`ok=true` is the provider accepting the move, which means it reached the
importer's `playMove` rather than the attack-context fallback. Captures from the
same run: `shots_bt/real/`.

Deterministic coverage: `tests/gen3_move_animation_test.lua` (passes) pins the
handoff — one animation per launch, the attacker's side carried, the latch
cleared, the provider's edge lowered so consecutive moves both play, known names
resolving to their numbers, unknown names staying nil, and moves past Stadium's
#251 still proxying.

## What is still open on this objective

* **Effects.** The Stadium 2 effect data caches correctly (695,280 / 20,480 /
  1,507,328 bytes) and the runtime is complete, but `BattleFxRom.catalog()`
  rejects the data: it resolves its program table through `ROM_BASE` and reads
  **all zeros** where the constant says the table is. The extractor's slice
  (`0x36F890..0x419480`) is right — the trig table at `0x88A50` reads as real
  data — so `PROGRAM_TABLE` (and the layout constants around it) are stale for
  this ROM revision by an amount the scan can measure (a 520-entry pointer table
  sits `0x721C` bytes further in). Finding the tables by brute force does not
  close it: candidate pairs either decode `op0`-only stubs (false positives) or
  fail on the first unknown opcode, so the opcode definitions need re-deriving
  too. That is a reverse-engineering task against `pret/pokestadiumgs`, not a
  tuning task. Tools left in `tools/fx/` (`scan_table.lua`, `probe_table.lua`,
  `search_pair.lua`, `search_base.lua`) do the measuring.
* **The importer's own MOVE EFFECTS (BETA) row is off by default**, so even a
  working catalog would not be used until it is enabled.
* **XD: Gale of Darkness** is a viable extra source for **models and body
  animations** (same PKX lineage as Colosseum), and it is **not** a practical
  source for move effects: those are GameCube display lists inside compiled
  code, and unlike Stadium 2 they are not already decoded into Lua. Format
  needed: a raw GameCube disc image (`.iso`/`.gcm`), full disc, US revision if
  available.

  Checked the toolchain rather than assuming. `tools/colosseum-work/tools/`:

  | Piece | XD readiness |
  |---|---|
  | `gciso.py` | game-agnostic: reads a plain GameCube `.iso`/`.gcm` filesystem table. No Colosseum constants. |
  | `fsys.py` | **already written for both games** — its docstring says "Genius Sonority FSYS archive (Pokemon Colosseum/XD)". |
  | `pkx_to_ir.py` | the PKX reader; identical model lineage, but the header/version fields need checking against an XD file. |
  | `colo2dsm.py` | the only genuinely Colosseum-specific stage, and it is small and isolated: a `name_to_dex.json` filename map, a joint `move_categories()` table, `GC_PER_METER` (the scale factor, calibrated), and `FPS_SRC`. |

  So the XD work is **bounded**, and it is three concrete jobs, not a port:
  1. extract the XD disc and confirm its `pkx_*.fsys` member names and the PKX
     header the reader expects (file archaeology, one pass);
  2. build `name_to_dex_xd.json` from XD's own filenames — XD's roster differs
     (it has its own shadow forms and a few additions), so this cannot be
     reused;
  3. re-calibrate `GC_PER_METER` and `FPS_SRC` against an XD model. The repo
     already has `tools/calibrate.py` with a `--calibrate` mode for exactly
     this, so it is a run rather than a derivation.

  Worth having: XD's models and animations are the highest-fidelity GameCube
  source available, and the converters are already structured so that only the
  per-game constants change.

---

# Round 4 — the effects blocker is a ROM revision, 2026-10-09

**The Stadium 2 ROM in this install is the Europe revision (NP3P), and the
effect decoder only supports the USA disc.**

## How it was pinned

`lib/layout.lua` accepts two revisions:

    Layout.US_MD5 = "1561c75d11cedf356a8ddb1a4a5f9d5d"   -- USA
    Layout.EU_MD5 = "b1271db50d6ef8f6b53cc640c3743e4f"   -- Europe (NP3P)

`baseroms/stadium2.z64` hashes to **`b1271db50d6ef8f6b53cc640c3743e4f`** — the
Europe revision. `Rom.validate` accepts it, and `Layout` documents that the EU
disc "keeps every asset table at the USA offsets", verified for arenas, models,
poses, animation dispatch, move names and species meta. Models, poses and
animation dispatch therefore work: all 251 species import and the move
animations now play. **The battle-effect overlay is not one of the tables that
matches**, and `lib/stadium2_battle_fx_rom.lua` carries only the USA addresses
(`ROM_BASE = 0x36F890`, `PROGRAM_TABLE = 0x84182154`, the opcode table,
sequences, variants, lifecycles).

The decisive test is the importer's **own** suite, run against this ROM with
`STADIUM2_REQUIRE_ROM=1`:

    stadium2_battle_fx_birth_update_test.lua:30:
      program 0: effect program pointer is outside fragment 79

31 of the 64 `*fx*` suites fail against this disc, all inside the decoder.

## Ruled out, with measurements

* **Not the extraction window.** The importer's slice is right: the trigger
  table at ROM `0x88A50` reads as real data, and the cached specials measure
  695,280 / 20,480 / 1,507,328 bytes. Lengthening the slice to 0x50000/0x60000/
  0x70000 changes nothing.
* **Not a stale local copy.** `lib/stadium2_battle_fx_rom.lua` and `lib/extract.lua`
  are byte-identical to upstream `origin/main` (v0.25.0).
* **Not a wrong opcode table.** I found the real one by matching the record
  lengths the upstream audit pins (`4,4,4,4,8,8,8,8,8,4,4,4,16,8,8,8,4,4`): it
  sits at `0x8416A598`, exactly `0x380` below the constant. Correcting it makes
  the dictionary complete (17 opcodes) — and the program table still reads
  garbage, because on this revision it is somewhere else.
* **Not findable by search.** With the corrected dictionary, a scan of every
  4-byte position in the whole ROM finds **no** place where even 250 of 395
  entries start a record with a defined opcode; the same scan for a run of
  pointers landing in one window finds **nothing** at any base. The USA layout
  does not merely shift on this disc.

## Can the EU layout be derived instead?

Tried, and the answer is no by search. The opcode table's record lengths are
pinned by the importer's own audit (`4,4,4,4,8,8,8,8,8,4,4,4,16,8,8,8,4,4`), so
it is a strong fingerprint: 18 records of `{handler, length}`. Scanning **every
4-byte position in the whole EU ROM** for that exact length signature, with the
handlers required to be a contiguous cluster of code addresses, returns
**zero** candidates. The EU disc does not merely move these tables — their
content differs, so a search keyed on the USA structure cannot find them.
Deriving them means reading the EU overlay's own code, which is disassembly
work against `pret/pokestadiumgs`, not a scan.

Measurement tools are in `tools/fx/` (`eu_solve.lua` is the signature search;
`find_programs.lua`, `find_by_opcode.lua` and `solve_tables.lua` are the earlier
program-table hunts).

## What closes it

**Supply the USA Stadium 2 disc (NPGE, MD5 `1561c75d11cedf356a8ddb1a4a5f9d5d`).**
Everything else is already in place: the runtime, the player, the battle
adapter, and the cache path. This is a one-file change on your side, and it is
the only way to get effects without deriving a second address table set for the
EU overlay, which the searches above show is not a shift.

## Shipped this round

`lib/StadiumModels.lua`: `reportEffectAvailability()` decides once per session
whether the effect runtime can come up, and logs the reason when it cannot —
naming the USA revision and its MD5, and saying explicitly that Pokemon art and
move animations are unaffected. `lib/Gen3StadiumModels.lua` calls it at the top
of `update`. Before this, a revision mismatch was completely silent: the effects
simply did not happen, with nothing in any log.

Also this round: `lib/StadiumModels.lua` no longer leaves the importer's own
move selectors unused (`moveSelector`/`selectorFor` are checked before falling
back to a raw number), so a caller holding the importer directly gets its proxy
too.

Verified installed in the real game and QA; `tests/gen3_move_animation_test.lua`
still passes.


---

# Round 5 — the USA disc arrives, and the effects decode, 2026-10-09

The user supplied `Pokemon Stadium 2 (USA).n64` and the `pret/pokestadiumgs`
decompilation. The blocker is gone.

## The ROM, and one extra trap

`Pokemon Stadium 2 (USA).n64` is **byteswapped (v64)**: first bytes `37 80 40 12`
and a title that reads `OPEKOM NTSDAUI M 2`. Swapping each 16-bit pair gives

    md5   1561c75d11cedf356a8ddb1a4a5f9d5d   <- Layout.US_MD5, exact
    title POKEMON STADIUM 2
    magic 80371240 (z64)

`Rom.normalise` handles v64, so the *model* import works from the `.n64` as
downloaded. **The effect decoder does not**: it opens the ROM file directly, so
a v64 file decodes garbage even when the disc is the right one. It has to be
written out as z64.

I checked the file order rather than copying it in and hoping: a v64 USA disc
would have looked like a third, unexplained failure.

## Verified against the importer's own suite

With the swapped file as `STADIUM2_ROM`, `STADIUM2_REQUIRE_ROM=1`:

    FX suites:  pass=64  fail=0  skip=0      (was 31 fail on the EU disc)

and the pinned audit:

    stadium2 battle FX ROM audit: 251 moves, 395 native programs, 18 opcodes, 30 lifecycle families

## The runtime works

A clean reimport from the USA disc, then asked through the mod's own driver:

    battleFxCatalog      = true
    resources(85)        = true
    newBattleFxPlayer    = true
    models.newInstance   = true

and an effect actually produces geometry — Thunderbolt, 40 ticks:

    move 85 trigger=1   snapshots=488 particles
    move  1 trigger=1   snapshots=0
    move 57 trigger=1   snapshots=0

So the decoder, the catalog and the effect runtime are all live. (Moves 1 and 57
yield nothing through `snapshot{shared=true}`; that is a packet/visibility
question for the renderer stage, not a decode failure — the audit covers all 251
moves.)

## Shipped

`tools/install_stadium2_rom.py` — takes any Stadium 2 ROM, identifies its byte
order and revision, refuses the Europe disc with an explanation instead of
importing a broken cache, writes a **z64** copy into the identity's own
`mods/STADIUM2_IMPORTER/baseroms/` (never into this repo), keeps the previous
disc as a backup, and clears the stale import cache so the next boot rebuilds
it. Installed into both the real game and QA.

## What remains

The effect **packets still need a renderer in Gen 3**. `Gen3Scene` draws through
`Voxel3D` with its own camera; the importer's `stadium2_battle_fx_battle_adapter`
is written against the Gen 1/2 staged stage and carries its own placement
callbacks (camera ray, world units, common anchors, markers). Wiring it means
either satisfying that contract from the Gen 3 camera or drawing the runtime's
packets directly. This is the last piece of "ship the effects path, verified
with captures", and it is integration work with a clear seam — not blocked.
