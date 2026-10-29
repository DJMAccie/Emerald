# Earlier review of the similarity report (pass 1)

For each of the 33 flagged modules I took every code line of our file (trimmed, longer than 24 characters, not a comment), compared it with every line of the 235 upstream base files in `.rewrite/simreview/up/` ignoring all whitespace, and named the shared lines by line number in both files; "share" is the checker's own figure from `reports/<name>.md`.

## Table

| file | verdict | shared lines | share | reason |
|---|---|---|---|---|
| Gen3CyclingRoad.lua | needs a look | 3 | 13.3% | only quad-uv returns and `for _,c in pairs(cells)do` (own:60,119,199), but the checker's share is 13.3%, so its token windows need reading in pass 2 |
| Gen3WallStairs.lua | common idiom | 2 | 7.1% | quad uv `return {{u,v},{u,v},{u,v},{u,v}}` (own:34 / Gen3Furniture.lua:173), `local x,z=c.cx*16,c.cy*16` (own:41 / Gen3Outdoor.lua:37) |
| Gen3Boat.lua | common idiom | 5 | 6.8% | colour key (own:27), four-neighbour loop ×2 (own:39,86), nil guard (own:58), 3×3 scan (own:97) |
| Gen3Fence.lua | common idiom | 8 | 6.2% | 16×16 loops ×2, four-neighbour loop, colour key, midToSlot guard, 3×3 scan, quad uv ×2 |
| SpriteVoxel.lua | needs a look | 6 | 5.5% | requires plus grid scan loops (own:191,210 / VoxelHull.lua:135,144) and the rect-merge erase `grid[(v+dv)*nw+u+du]=nil` (own:221 / VoxelHull.lua:154); the merge block around it reads like upstream's |
| Gen3VoxelBuildings.lua | needs a look | 8 | 5.4% | three consecutive shared lines of the tileset pixel reader (own:29-31 / Gen3Outdoor.lua:13-15), plus key, midToSlot guard, requires |
| Gen3Canopy.lua | common idiom | 7 | 4.9% | midToSlot guard, 16×16 loop, uv interpolator + quad return twice (own:114-115,176-177 / Gen3Outdoor.lua:10-11), `local x0,z0=c.cx*16,c.cy*16` |
| Gen3Partition.lua | common idiom | 2 | 4.8% | quad uv (own:49 / ChunkMesher.lua:1732), `local x,z=c.cx*16,c.cy*16` (own:57) |
| Gen3Decks.lua | needs a look | 7 | 4.8% | exact `local g=c.column and c.column.group or c.civic or c.prop` (own:214 / Gen3Elevation.lua:67) is cell-model specific; the rest are loops, quad uv, x,z |
| Gen3Planter.lua | needs a look | 9 | 4.0% | the uv sub-rect helper as three consecutive lines, twice (own:112-114 and 269-271 / Gen3Outdoor.lua:9-11) |
| Gen3Masonry.lua | common idiom | 4 | 3.8% | key(x,y), nil guard, `for _,c in pairs(cells)do`, x,z (own:30,56,58,143) |
| Gen3StadiumModels.lua | needs a look | 14 | 3.4% | mostly requires; also `StadiumModels.animWasPlaying=false` (own:184 / StadiumModels.lua:89) and the contact-shadow recipe (own:227,229,230,248 / ActorContact.lua:8,11,12,21) |
| Gen3FlyPath.lua | common idiom | 2 | 3.0% | eye→focus delta and horizontal distance (own:80-81 / Voxel3D.lua:836,897) |
| BuildingVoxels.lua | common idiom | 5 | 3.0% | requires ×2, `for _,c in pairs(cells)do`, getDimensions, colour key (own:15,16,128,145,157) |
| Gen3EmeraldInteriors.lua | needs a look | 1 | 2.9% | `for _,id in ipairs(walls)do p.walls[id]=true end` (own:17 / Gen3InteriorProfiles.lua:7); the whole `profile(key,floor,walls,props,...)` helper is near the same shape |
| BuildingModels.lua | needs a look | 6 | 2.8% | four-neighbour loop + exact neighbour key lookup (own:850-851 / Gen3Scene.lua:382-383); rest are requires, loops, release guard |
| Gen3Objects.lua | needs a look | 27 | 2.7% | 20 lines are loops/guards/quad uv, but `local t={q.u,q.v};emit(p,{t,t,t,t},q.shade)` appears twice (own:968,996 / Gen3Outdoor.lua:48) with its `for _,q in ipairs(faces)do` (own:966,994) |
| Gen3Mass.lua | needs a look | 22 | 2.4% | pixel reader as three consecutive lines (own:62-64 / Gen3Outdoor.lua:13-15) and uv sub-rect as three consecutive lines (own:358-360 / Gen3Outdoor.lua:9-11); 15 further lines are loops and guards |
| Gen3ObliqueWall.lua | common idiom | 6 | 2.2% | weak-cache setmetatable, key(x,y), `build(cells)`, colour key, `for _,p in ipairs(list)do`, quad uv |
| Gen3Waterfall.lua | common idiom | 1 | 2.1% | key(x,y) (own:9 / TerrainLevels.lua:5) |
| Gen3Lamp.lua | common idiom | 5 | 2.0% | midToSlot guard, getPixel, Voxel3D require, `newImageData(n,n)`, `R.withEffect('alpha',…` — no shared numbers or names |
| Gen3EmeraldShapes.lua | needs a look | 12 | 1.8% | `function M.of(primary,secondary,mid,behavior,collision)` (own:387 / Gen3TileShape.lua:125), `if primary=='general' then` (own:512 / :161) and `return {kind='flat',reviewedSurface=true}` ten times (own:487…571 / :149); both are the shape contract its callers pass, so pass 2 should confirm and not just count |
| BattleShots.lua | common idiom | 4 | 1.7% | two requires, `if not battle then return false end`, `dt=math.max(0,tonumber(dt) or 0)` |
| Gen3Rock.lua | common idiom | 26 | 1.6% | key(x,y), 16×16 loops, 21 four-neighbour loops, `if not n then return nil end`, quad uv, x,z — all loop/guard spelling |
| Gen3Hills.lua | common idiom | 10 | 1.4% | `for _,p in ipairs(list)do` ×7, quad uv, `local x,z=c.cx*16,c.cy*16` ×2 |
| Gen3FlyOver.lua | common idiom | 11 | 1.1% | requires (own:22-24 are a require-only run, not counted as a copy run), nil guards, `pcall(function()`, mid-point maths |
| Gen3BattleStage.lua | common idiom | 5 | 1.0% | requires (own:106-108, interface lines only), world→cell `math.floor(x/16)`, sign loop |
| Gen3RockSprites.lua | common idiom | 6 | 1.0% | Voxel3D require, quad triangle index `{1,2,3,1,3,4}` ×3 (own:112,313,389 / Gen3Scene.lua:50), hit guard, sign loop |
| Gen3TreeStamps.lua | common idiom | 1 | 0.8% | only `for _,c in pairs(cells)do` (own:63) |
| TourMode.lua | common idiom | 6 | 0.8% | `if not ok then error(…)` ×2, canvas save/restore, `setShader()`, `setColor(1,1,1,1)` |
| Gen3Blocks.lua | common idiom | 7 | 0.7% | key(x,y), `for _,c in pairs(cells)do` ×3, `for _,r in ipairs(regions)do`, `if best then return best end`, x,z |
| Gen3Relief.lua | common idiom | 4 | 0.6% | four-neighbour loop, nil guard, x,z, `for j=0,3 do for i=0,3 do` |
| Gen3FlyGround.lua | common idiom | 12 | 0.4% | requires, pcall wrappers ×4, graphics state resets, `local ts=Tiles._pairs[p.pair]` |

## Needs a look

**Gen3CyclingRoad.lua** — no specific line, but 13.3% share.
- own:60 / ChunkMesher.lua:1732 — `return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}`
- own:119 / Gen3Furniture.lua:173 — `return {{u,v},{u,v},{u,v},{u,v}}`
- own:199 / Gen3Elevation.lua:44 — `for _,c in pairs(cells)do`

**SpriteVoxel.lua**
- own:191 / VoxelHull.lua:135 — `for v=0,nh-1 do for u=0,nw-1 do`
- own:210 / VoxelHull.lua:144 — `for v=0,nh-1 do for u=0,nw-1 do`
- own:221 / VoxelHull.lua:154 — `for dv=0,hh-1 do for du=0,ww-1 do grid[(v+dv)*nw+u+du]=nil end end`

**Gen3VoxelBuildings.lua**
- own:29 / Gen3Outdoor.lua:13 — `local function pixel(ts,x,y)`
- own:30 / Gen3Outdoor.lua:14 — `local r,g,b,a=ts.imageData:getPixel(x,y)`
- own:31 / Gen3Outdoor.lua:15 — `if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(x,y)`
- own:24 / TerrainLevels.lua:5 — `local function key(x,y)return x..':'..y end`
- own:26 / Gen3Scene.lua:53 — `local slot=ts.midToSlot[mid];if not slot then return end`

**Gen3Decks.lua**
- own:214 / Gen3Elevation.lua:67 — `local g=c.column and c.column.group or c.civic or c.prop`
- own:317 / ChunkMesher.lua:1732 — `return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}`
- own:384,394 / CommunityFlora.lua:4028 — `local x0,z0=c.cx*16,c.cy*16`

**Gen3Planter.lua**
- own:112-114 and own:269-271 / Gen3Outdoor.lua:9-11 —
  `local function sub(uv,l,t,r,b)` / `local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end` / `return {p(l,t),p(r,t),p(r,b),p(l,b)}`

**Gen3StadiumModels.lua**
- own:184 / StadiumModels.lua:89 — `StadiumModels.animWasPlaying=false`
- own:227 / ActorContact.lua:8 — `if not V.require('Shadows').enabled() then return end`
- own:229 / ActorContact.lua:11 — `local data=love.image.newImageData(16,16)`
- own:230 / ActorContact.lua:12 — `for y=0,15 do for x=0,15 do`
- own:248 / ActorContact.lua:21 — `R.withEffect('alpha',function()`

**Gen3EmeraldInteriors.lua**
- own:17 / Gen3InteriorProfiles.lua:7 — `for _,id in ipairs(walls)do p.walls[id]=true end`

**BuildingModels.lua**
- own:850 / CommunityFlora.lua:3855 — `for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do`
- own:851 / Gen3Scene.lua:383 — `local n = cells[(c.cx + d[1]) .. ':' .. (c.cy + d[2])]`

**Gen3Objects.lua**
- own:966,994 / Gen3Outdoor.lua:46 — `for _,q in ipairs(faces)do`
- own:968,996 / Gen3Outdoor.lua:48 — `local t={q.u,q.v};emit(p,{t,t,t,t},q.shade)`
- own:93,44,45 / Gen3Outdoor.lua:13-15 — the `pixel(ts,x,y)` reader (same three lines as above)

**Gen3Mass.lua**
- own:62-64 / Gen3Outdoor.lua:13-15 — `local function pixel(ts,x,y)` / `local r,g,b,a=ts.imageData:getPixel(x,y)` / `if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(x,y)`
- own:358-360 / Gen3Outdoor.lua:9-11 — the `sub(uv,l,t,r,b)` / `p(x,y)` / `return {p(l,t),…}` triple
- own:54 / TerrainLevels.lua:5 — `local function key(x,y)return x..':'..y end`

**Gen3EmeraldShapes.lua**
- own:387 / Gen3TileShape.lua:125 — `function M.of(primary,secondary,mid,behavior,collision)`
- own:512 / Gen3TileShape.lua:161 — `if primary=='general' then`
- own:487,494,508,520,531,546,556,563,567,571 / Gen3TileShape.lua:149 — `return {kind='flat',reviewedSurface=true}`

## Notes and decisions

- "Stripped of whitespace" was read as: length measured on the trimmed line, comparison ignores all whitespace, so `for _,c in pairs(cells)do` matches the spaced spelling too.
- Shared-line counts here can be higher than the checker's "exact" column (e.g. Gen3Objects 27 vs 23, Gen3StadiumModels 14 vs 4). The checker also drops lines that occur in the engine's own sources (module requires, `love.graphics.setColor(1,1,1,1)`), and it compares against data files as well; this pass compares only against `up/*.lua` and reports what is there.
- A run of three shared lines that is only module-require lines is not treated as a copy run (Gen3FlyOver.lua:22-24, Gen3BattleStage.lua:106-108); those are interface facts and the checker excludes them too.
- `Shapes.of(primary,secondary,mid,behavior,collision)` and `reviewedSurface` are the shape contract the engine calls with (Gen3Scene.lua:179, Gen3Elevation.lua:27, Gen3Boundary.lua:45-48), so Gen3EmeraldShapes' shared lines are contract literals, not copied logic — worth confirming in pass 2, not by line count.
- Gen3StadiumModels.lua:184 sets a public field of the engine's own `StadiumModels` module; the shadow block there follows the engine's contact-shadow recipe (ActorContact.lua).
