# Open issues raised by the user (2026-10-05, after the elevation work)

## 1. The Littleroot truck is a huge block — **RESOLVED** (2026-10-05, later the same day)

The truck is **gid 94**, a 48x48 inanimate sprite drawn at (2,10) and (11,10);
it is now a real voxel model built out of its own artwork, not a card. The
whole story — how the sprite's oblique projection was read back into a solid,
the tool, and the before/after evidence — is in
[SPRITE-TO-VOXEL-PLAN.md](SPRITE-TO-VOXEL-PLAN.md), "DONE — the tool exists".
Installed in the mod source and in QA; **not yet installed in the real game**.

The original diagnosis below is kept because the *correction* in it is the
useful part: the truck was never map tiles, and the pillar was never gid 240.

## 1b. The original report (kept for the record)

**Symptom (from the user):** the truck reads as a big block. Visible in
`shots_truck2/strip.png` and `shots_truck2/zoom_truck.png`: a dark box with a blue
slab on top, sitting over a building.

**CORRECTION — my first diagnosis was wrong, and this is the important part.**
I initially reported that the truck occupies cells x=3–8, y=13–16 and is extruded by
the generic building path. That is false. The blocked-cell map of Littleroot shows
x=3–9, y=13–16 is a **second 7x4 house** with the same roof signature as the one at
x=2–6, y=5–8 (`214 24A 24B 215 215 215 216` / `214 ... 216` / `21E 20F 20F 22C 241 22D 21F` /
`226 217 217 234 249 235 227`). Rendering that footprint from the atlas art produces
house art, which is what `truck_footprint.png` shows — that image is the disproof of my
own earlier claim.

**What is actually true:** the truck is **not tiles in the map grid at all** — every
candidate cell in Littleroot is accounted for by the two houses and the border. The truck
must therefore be a separate overworld object (an NPC sprite or an object event) *standing on*
those cells, drawn over the ground. In the capture it is the dark box with the blue cab slab
that appears overlapping the buildings' left side. That is consistent with the brief's note
that the truck is "a flat leaning CARD (billboard)": a card would be drawn as a sprite, not built
from the tile grid, which is exactly why no tile-based investigation finds it.

**Next step, and the thing to do first:** find the truck's **object event / sprite**, not its
tiles. Look for the object event on Littleroot in the extracted map events
(`game.data` events, `src/import/gba/extract_map_events.lua`) and the graphics id it names
(`inside_of_truck` is a separate map id, `Gen3EmeraldAuto.lua:72`, which is the interior, not
the exterior sprite). The exterior truck sprite's art is then the texture to build the box from.

**Direction (unchanged, still right):** a closed box with cab, cargo body and wheels reading the
truck's own sprite. The mod already has the machinery — `Voxel3D.newMesh(verts, indices)` with
`Voxel3D.FORMAT` (x,y,z,u,v,shade), used by `Backdrop`, `BattleBillboard`, `CaveAtmosphere3D`.
Authored shapes today are analytic (`NativeTreeModels.part(family,x,y,z)` returns a part name per
voxel), so a truck authored as a voxel grid follows that pattern. MagicaVoxel `.vox` would need a
loader; authoring as a Lua voxel table avoids that and matches the existing style.

**Why it is not done:** the session ran out of budget. Nothing is half-changed — no code was
written for the truck.

## 2. "The blur doesn't work yet" — root cause found, fix written, NOT YET VERIFIED IN GAME

T-SHIFT is stored **twice**, and the two disagreed:

| Where | Key | Value |
|---|---|---|
| the mod's own row | `options.modOptions.BATTLE_ART_VOXEL_FORK.tiltshift` | 2 |
| the engine's pipeline bucket | `options.pipelines.tiltshift` | 0 |

The engine's `src/render/Pipelines.lua` owns the level: `applyOptions` restores it from
`opts.pipelines`, and `Pipelines.update` pushes it into the mod's `TiltShift.update(dt, level)`
**every frame**. The mod's own row wrote only its `ModSetting`, and `Gen3SceneOptions.update` then
called `TiltShift.setLevel(...)` directly — which the next frame overwrote. Net effect: the option
says 2, the engine says 0, and no blur is drawn. (`TiltShift.apply` returns the canvas untouched at
level 0, so this fails silently.)

**The fix** (in `Gen3SceneOptions.M.update`): drive the engine's level from the mod's row instead of
the module, and mirror it into the bucket the engine restores from — the same pattern `main.lua`
already uses in its FULL preset. It is **change-driven** (only pushes when the row itself moves), so
the engine's own T-SHIFT row and hotkey keep working rather than being overwritten every frame:

```lua
local level=M.tilt:get()
if level~=M.tiltPushed then
 local ok,Pipelines=pcall(require,"src.render.Pipelines")
 if ok and Pipelines.get and Pipelines.get("tiltshift") then
  Pipelines.setLevel("tiltshift",level); M.tiltPushed=level
  local Game=package.loaded["src.core.Game"]
  local opts=Game and Game.save and Game.save.options
  if opts and Pipelines.syncOptions then Pipelines.syncOptions(opts) end
 end
end
```

**Verification status: NOT VERIFIED.** The code is in the source tree and in QA, and a 25-view
regression on it is clean (zero `fallback`, zero errors), but the capture harness does not exercise
this path: `Gen3SceneOptions.update` is reached through the mod's `core.update` hook
(`Gen3Integration.lua:125`), and a temporary canary print inside `update` never fired in any
driver run. So neither the old nor the new behaviour can be observed from a capture.

**What to do next:** run the real game and look. If the blur appears at T-SHIFT 2, it is fixed; if it
does not, the next suspect is whether `Pipelines.get("tiltshift")` is non-nil in a normal boot (the
probe could not confirm it in-driver, because `Pipelines.install` rebinds the module's dataset at
boot and a driver run leaves that dataset without the mod's registrations). Also note the engine's
own T-SHIFT row and hotkey 6 remain, and can turn the blur on independently for the session.

## 2b. RESOLVED — T-SHIFT blur, and the duplicate row is gone

The user confirmed **the blur works**. The bridge in `Gen3SceneOptions.update` (drive the engine's
pipeline level from the row, then mirror it into `save.options.pipelines`) was the fix; the earlier
root cause stands: T-SHIFT was stored twice and the engine's per-frame push of the stale 0 beat the
mod's row.

**Duplicate control removed.** `Gen3SceneOptions` no longer creates a mod-owned `T-SHIFT`
`ModSetting`, so the row list now has a single T-SHIFT control: the engine's `render_pipelines` row
(which brings the ladder, hotkey 6 and persistence in `save.options.pipelines`). Two rows for one
effect could only ever disagree, and did.

**Default-on kept, without a second row.** The engine schema has no `default` field for a pipeline
level, so `M.tiltAdopt()` writes level `M.tiltDefault` (2) **once**, for a save whose
`options.pipelines.tiltshift` is not a number. After that one write the engine's row and hotkey own
the value, so turning T-SHIFT OFF sticks across sessions.

**Deployment status:** committed in the Emerald repo patch, and synced to **QA**. **The real game
still runs the previous build** (its `Gen3SceneOptions` lacks both this and the bridge) — the user
was mid-game when this landed, so the live install was deliberately left alone. Install it when the
game is closed (rule: `pgrep -fl "MacOS/love"` must be empty first).
