-- Native FireRed art in Battle Art's existing depth/shadow renderer.
-- All imported pixels come from the engine's live asset providers; no cache
-- paths, ROM reads, companion-private assets or emulated gameplay live here.
local V=...
local R=V.require('Voxel3D')
local Shadow=V.require('ShadowMap')
local Mat=V.require('Mat4')
local Shapes=V.require('Gen3TileShape')
local Pairs=V.require('Gen3Tilesets')
local Furniture=V.require('Gen3Furniture')
local Stairs=V.require('Gen3Stairs')
local SpriteAnchor=V.require('Gen3SpriteAnchor')
local Roof=V.require('Gen3RoofDetails')
local Buildings=V.require('Gen3Buildings')
local Civic=V.require('Gen3Civic')
local Outdoor=V.require('Gen3Outdoor')
local Terrain=V.require('Gen3Terrain')
local Mass=V.require('Gen3Mass')
local Elevation=V.require('Gen3Elevation')
local BattleClear=V.require('Gen3BattleClear')
local camArm={}
local Distance=V.require('RenderDistance')
local DebugWalk=V.require('DebugWalk')
local Boundary=V.require('Gen3Boundary')
local BoundarySelect=V.require('BoundaryScenery')
local SceneCache=V.require('Gen3SceneCache')
local Budget=V.require('BuildBudget')
local SceneStream=V.require('SceneStream')
local Forest=V.require('Gen3Forest')
local Cladding=V.require('HouseCladding')
local Interior=V.require('InteriorDiorama')
local Trees=V.require('Gen2Trees')
local Leaves=V.require('Gen2DepthTrees')
local TreeStyle=V.require('TreePresentation')
local Standing=V.require('Gen3Objects')
local Landmarks=V.require('LandmarkModels')
local RockSprites=V.require('Gen3RockSprites')
local Canopy=V.require('Gen3Canopy')
local Decks=V.require('Gen3Decks')
local BuildingModels=V.require('BuildingModels')
local VoxelBuildings=V.require('Gen3VoxelBuildings')
local Map=require('src.core.game3.map')
local Tiles=require('src.core.game3.tileset_native')
local Sprites=require('src.core.game3.ow_sprites')
local Player=require('src.core.game3.player')
local Objects=require('src.core.game3.objects')
local Versions=require('src.import.gba.versions')
local M={builds=0}
-- maps whose open sea is flat sea level whatever its rated height
local SEA_LEVEL_MAPS={EM_SLATEPORT_CITY=true}
-- Height of a dense forest canopy mass (two 16-row courses of its art).
local CANOPY_HEIGHT=32
-- FORTREE_V2: Fortree City's plain forest cells stand real one-cell trees on the ground (step 1);
-- false = the old block at platform height for Fortree
local FORTREE_V2=true
local WATER_LAP=.06   -- px a water quad reaches past its edges (see the water meshes)
-- Bridge decks: thickness of the plate of planks, in world units.
local DECK_THICKNESS=6
-- A deck cell: a walkway on elevation 15 (the cartridge's bridge/walkway marker), or a tile that
-- is one of the deck tiles of this scene (a bridge's end cells sit on the ordinary level).
local DECK_FAMILY={general__fortree={[0x210]=1,[0x211]=1,[0x212]=1,[0x213]=1,[0x214]=1,[0x215]=1,[0x216]=1,[0x217]=1,[0x218]=1,[0x219]=1,[0x21A]=1,[0x21B]=1,[0x21C]=1,[0x21D]=1,
 -- the rope bridges between the treehouses and over the path to the Gym (rated
 -- level 4 like the decks, not the e15 marker): planks with open air under them
 [0x256]=1}}
local function isDeck(c)
 -- (a deck over a river: Gen3Scene SHAPE_BY_MAP underWater)
 if c.shape and c.shape.underWater then return true end
 if c.collision~=0 or not c.floor then return false end
 if c.floor.layer==15 then return true end
 local fam=DECK_FAMILY[c.pair];return fam and fam[c.mid] or false
end
function M.context()return Map.currentDef()end
local cache,foliage,bark,spriteMeshes={ },nil,nil,{}
local savedCanvas,saved=false,false
local PROBE={}
local function quad(v,i,p,uv,shade,anchor)
 Budget.tick()
 -- debug (default off): M.probeBox={x0,x1,z0,z1} prints which cell's code emits geometry there
 if M.probeBox and PROBE.cell then
  M.probeCell=PROBE.cell
  local B=M.probeBox
  for _,a in ipairs(p)do if a[1]>B[1] and a[1]<B[2] and a[3]>B[3] and a[3]<B[4] then
   local k=M.probeCell.cx..','..M.probeCell.cy..' y'..math.floor(p[1][2])..'..'..math.floor(p[3][2])..' sh'..tostring(shade)..' x'..math.floor(p[1][1])..' z'..math.floor(p[1][3])..' '..tostring(PROBE.tag)
   M.probeSeen=M.probeSeen or {}
   if not M.probeSeen[k] then M.probeSeen[k]=true;local vs={};for _,a in ipairs(p)do vs[#vs+1]=string.format('(%.0f,%.1f,%.0f)',a[1],a[2],a[3])end;print('[EM box]',k,tostring(PROBE.tag),string.format('%03X',M.probeCell.mid or 0),M.probeCell.shape and M.probeCell.shape.kind,'base',M.probeCell.base,table.concat(vs,' ')) end
   break end end
 end
 if M.probeY and p[1][2]>=M.probeY then
  local k=math.floor(p[1][1]/16)..','..math.floor(p[1][3]/16)
  M.probeHits=M.probeHits or {};M.probeHits[k]=(M.probeHits[k] or 0)+1
 end
 local base=#v
 local s=shade or 1
 for k=1,#p do
  local a,t=p[k],uv[k]
  local vertex={a[1],a[2],a[3],t[1],t[2],s}
  if anchor then vertex[7],vertex[8],vertex[9]=anchor[1],anchor[2],anchor[3]end
  v[base+k]=vertex
 end
 local n=#i
 i[n+1],i[n+2],i[n+3],i[n+4],i[n+5],i[n+6]=base+1,base+2,base+3,base+1,base+3,base+4
end
-- (one uv table per tile and tileset, shared: callers only read it, and building five new tables per
-- quad was a large share of a furnished room's build without the JIT)
local uvMemo=setmetatable({},{__mode='k'})
local function uvFor(ts,mid)
 if mid==nil or ts==nil then return end
 local memo=uvMemo[ts];if not memo then memo={};uvMemo[ts]=memo end
 local hit=memo[mid];if hit~=nil then return hit or nil end
 local slot=ts.midToSlot[mid];if not slot then memo[mid]=false;return end
 local x,y=slot%ts.cols,math.floor(slot/ts.cols)
 local l,r=(x+.005)/ts.cols,(x+.995)/ts.cols
 local t,b=(y+.005)/ts.rows,(y+.995)/ts.rows
 hit={{l,t},{r,t},{r,b},{l,b}};memo[mid]=hit
 return hit
end
local PIER_THICK=3
-- relief floors' sloped tops (c.slope={nw,ne,se,sw}): for a step towards neighbour d, this cell's two
-- corners on that edge (in the band's a,b order) and the neighbour's two corners there
local NO_SLOPE={0,0,0,0}
local SLOPE_EDGE={['-1:0']={1,4,2,3},['1:0']={2,3,1,4},['0:-1']={1,2,4,3},['0:1']={4,3,1,2}}
local function plane(v,i,x,z,uv,h)
 quad(v,i,{{x,h or 0,z},{x+16,h or 0,z},{x+16,h or 0,z+16},{x,h or 0,z+16}},uv)
end
-- Stair flights (Gen3Elevation step cells, e.g. Route 110's 0x2D4 by the north gate): one cell is N
-- treads, not one slab. FLIGHT_TREADS: the tread lines the tile's own art draws in one cell (rows
-- where the light tread and the darker riser alternate; 0x2D4 in general__mauville: 8 pairs in
-- 16 rows, read from the atlas); other flight tiles use FLIGHT_TREADS_DEFAULT.
local FLIGHT_TREADS={general__mauville={[0x2D4]=8},general__mossdeep={[0xAF]=2,[0xCF]=2},general__lilycove={[0xAF]=2,[0xCF]=2},general__sootopolis={[0x244]=2,[0x245]=2}}
local FLIGHT_TREADS_DEFAULT=4
-- the flight this cell climbs: the neighbour on one axis is higher, on the other lower; nil if none
local function flightAxis(c,cells)
 local f=c.floor
 if not(f and f.step) or c.shape.kind~='flat' or c.base==nil then return nil end
 local B=c.base
 for _,ax in ipairs({{{0,-1},{0,1}},{{-1,0},{1,0}}})do
  local a=cells[(c.cx+ax[1][1])..':'..(c.cy+ax[1][2])]
  local b=cells[(c.cx+ax[2][1])..':'..(c.cy+ax[2][2])]
  if a and b then
   local da,db=(a.base or 0)-B,(b.base or 0)-B
   -- (the cell may stand level with either side: a one-row flight too shallow to be stretched stands at its
   -- lower floor's height - Route 119's 5,80 climbs 8 px - and one with no floor below it, only a ledge, at
   -- its upper floor's - Jagged Pass 13,13; both were drawn as flat slabs. flightTreads climbs the whole step.
   -- Only north-south between two open neighbours: rock beside a stair is no floor to climb to)
   if da>.5 and db<-.5 then return {up=ax[1],down=ax[2],rise=da,dhi=a,dlo=b} end
   if db>.5 and da<-.5 then return {up=ax[2],down=ax[1],rise=db,dhi=b,dlo=a} end
   local open=ax[1][1]==0 and a.collision~=7 and b.collision~=7 and not (a.shape and (a.shape.kind=='cliff' or a.shape.kind=='rock'))
    and not (b.shape and (b.shape.kind=='cliff' or b.shape.kind=='rock'))
   if open and da-db>.5 and da>-.5 and db<.5 then return {up=ax[1],down=ax[2],rise=da-db,dhi=a,dlo=b} end
   if open and db-da>.5 and db>-.5 and da<.5 then return {up=ax[2],down=ax[1],rise=db-da,dhi=b,dlo=a} end
  end
 end
 return nil
end
-- the flight cell's treads, risers and closed sides, with absolute heights (after Elevation.lift)
local function flightTreads(c,fl,cells,b,uv)
 local T=(FLIGHT_TREADS[c.pair] and FLIGHT_TREADS[c.pair][c.mid]) or FLIGHT_TREADS_DEFAULT
 local B,R=c.base,fl.rise
 -- (a one-cell flight rated half way between its two floors climbs the whole step, from the lower
 -- floor to the upper: from its own height it was a blank wall below four shallow treads)
 if fl.dlo and fl.dhi and fl.dlo.base and fl.dhi.base and fl.dlo.base<B-.5 and not (fl.dlo.floor and fl.dlo.floor.step) and not (fl.dhi.floor and fl.dhi.floor.step) then
  B=fl.dlo.base;R=fl.dhi.base-B
 end
 local x0,z0=c.cx*16,c.cy*16
 local across=fl.up[1]~=0            -- flight runs east-west: width is z
 -- world point at depth t (0 = lower edge, 16 = upper edge) and width w (0..16)
 local function P(t,w,h)
  local d=t
  if fl.up[1]>0 or fl.up[2]>0 then d=t else d=16-t end
  if across then return x0+d,h,z0+w end
  return x0+w,h,z0+d
 end
 -- art: the tile's top row is the far (upper) edge, so depth t maps to art v = 1 - t/16
 local function vt(f) return uv[1][2]+(uv[3][2]-uv[1][2])*f end
 local function ut(f) return uv[1][1]+(uv[2][1]-uv[1][1])*f end
 local function Q(p,uvs,shade)quad(b.v,b.i,p,uvs,shade)end
 -- the ground under the whole footprint at the lower floor's height, in the lower neighbour's art, and
 -- the face from that floor up to this cell's base down the side that descends: no gap under a tread
 local dlo=fl.dlo
 if dlo and dlo.base and dlo.base<B-.5 then
  plane(b.v,b.i,x0,z0,uvFor(dlo.ts,dlo.mid) or uv,dlo.base)
  local rv0=vt(1-.5/T)
  local dx,dy,dz=P(0,0,dlo.base);local ex,ey,ez=P(0,16,dlo.base);local fx,fy,fz=P(0,16,B);local gx,gy,gz=P(0,0,B)
  Q({{dx,dy,dz},{ex,ey,ez},{fx,fy,fz},{gx,gy,gz}},{{ut(0),rv0},{ut(1),rv0},{ut(1),rv0},{ut(0),rv0}},.78)
 end
 for k=0,T-1 do
  local t0,t1=16*k/T,16*(k+1)/T
  local H=B+(k+1)*R/T
  -- tread k: top at H over depth slice k, showing art rows of that slice 1:1
  local v0,v1=vt(1-t0/16),vt(1-t1/16)
  local ax,ay,az=P(t0,0,H);local bx,by,bz=P(t0,16,H);local cx_,cy,cz=P(t1,16,H);local dx,dy,dz=P(t1,0,H)
  Q({{ax,ay,az},{bx,by,bz},{cx_,cy,cz},{dx,dy,dz}},{{ut(0),v0},{ut(1),v0},{ut(1),v1},{ut(0),v1}},1)
  -- riser k at the slice's lower edge: from the tread below (B+kR/T) to this tread
  local lo=B+k*R/T
  local rv=vt(1-(k+.5)/T)
  local rx,ry,rz=P(t0,0,lo);local sx,sy,sz=P(t0,16,lo)
  Q({{rx,ry,rz},{sx,sy,sz},{sx,H,sz},{rx,H,rz}},{{ut(0),rv},{ut(1),rv},{ut(1),rv},{ut(0),rv}},.78)
  -- sides: the outermost art column, repeated per pixel row, down to a lower neighbour
  for _,side in ipairs({{0,ut(.5/16)},{16,ut(15.5/16)}})do
   local sw=side[1]
   local n=across and cells[(c.cx)..':'..(c.cy+(sw==0 and -1 or 1))] or cells[(c.cx+(sw==0 and -1 or 1))..':'..c.cy]
   local nb=n and n.base or 0
   if n and nb<H-.5 and not (n.shape and n.shape.kind=='cliff') then
    local low=nb
    if low<H then
     local px0,py0,pz0=P(t0,sw,low);local px1,py1,pz1=P(t1,sw,low)
     local px2,py2,pz2=P(t1,sw,H);local px3,py3,pz3=P(t0,sw,H)
     Q({{px0,py0,pz0},{px1,py1,pz1},{px2,py2,pz2},{px3,py3,pz3}},{{side[2],vt(1-t0/16)},{side[2],vt(1-t1/16)},{side[2],vt(1-t1/16)},{side[2],vt(1-t0/16)}},.7)
    end
   end
  end
 end
end
local wallColumn
local function swatch(ts,u,v)
 -- A constant UV exactly BETWEEN texels interpolates to either side by a
 -- rounding ULP across a triangle. At nearest filtering that becomes noisy
 -- siding even with shadows disabled. Always sample the texel centre.
 u=(math.floor(u*ts.cols*16)+.5)/(ts.cols*16)
 v=(math.floor(v*ts.rows*16)+.5)/(ts.rows*16)
 return {{u,v},{u,v},{u,v},{u,v}}
end
-- The facade column that best stands for the wall's material: among the 16
-- pixel columns of a wall tile, the least busy one that is not dark outline
-- (so not a window, a door or the corner trim). Cached per tileset and tile.
local wallColumns=setmetatable({},{__mode='k'})
function wallColumn(ts,mid,fallback)
 if not ts.imageData then return fallback end
 local cache=wallColumns[ts];if not cache then cache={};wallColumns[ts]=cache end
 if cache[mid]~=nil then return cache[mid] or fallback end
 local slot=ts.midToSlot[mid];if not slot then cache[mid]=false;return fallback end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local best,score
 local stat,means={},{}
 for x=1,14 do
  local sum,sq,n=0,0,0
  for y=0,15 do
   local ok,r,g,b,a=pcall(ts.imageData.getPixel,ts.imageData,ox+x,oy+y)
   if ok and (a or 0)>.5 then local l=.3*r+.59*g+.11*b;sum=sum+l;sq=sq+l*l;n=n+1 end
  end
  if n>=12 then local mean=sum/n;stat[x]={mean,sq/n-mean*mean};means[#means+1]=mean end
 end
 table.sort(means)
 local med=means[math.ceil(#means/2)]
 for x=1,14 do local st=stat[x]
  if st then
   -- calm and light wins; dark outline columns are heavily penalised, and so is a column far from the
   -- tile's usual brightness (a calm navy trim column in a grey brick tile made a whole side wall navy)
   local s=st[2]*4+(st[1]<.3 and 1 or 0)+2*math.abs(st[1]-med)+math.abs(x-7.5)*.002
   if not score or s<score then best,score=x+.5,s end
  end
 end
 cache[mid]=best or false
 return best or fallback
end
local function materials()
 if not foliage then
  foliage=V.require('TreeIllustrations').image(V)
  local data=love.image.newImageData(2,2)
  for y=0,1 do for x=0,1 do data:setPixel(x,y,.29+x*.03,.18+y*.03,.10,1) end end
  bark=love.graphics.newImage(data);data:release()
 end
end
-- Landing dust uses the native effect painter on a small world-space card.
-- Unsupported full-screen effects still retain their native presentation.
-- Ambient effects (wading ripples, sand tracks, hot-spring steam) are not drawn in 3D yet; they
-- must not flip the whole view to the flat renderer while the player stands in shallow water.
-- (emote: the '!' / '?' / heart bubble over a character, drawn in the scene
-- by fieldEffects -- as a native-only effect every trainer who spotted the
-- player flipped the whole view to 2D for the bubble's second)
local AMBIENT={dust=true,feet_water=true,ripple=true,splash=true,tracks=true,hot_springs=true,emote=true}
function M.nativeEffects(anims)
 for _,a in ipairs(anims or {})do if type(a)~='table' or not AMBIENT[a.kind] then return true end end
 return false
end
function M.nativeRequired(game)
 -- Door and healing frames are projected into the scene below. Other special
 -- field presentations retain their native renderer.
 Pairs.bind(game and game.data and game.data.maps)
 local def=Map.currentDef()
 if not (def and def.midLayout) then return true end
 local spec=Pairs.resolve(def.midLayout.pair,Versions.TILESET_PAIRS)
 if not Pairs.supports(def,spec) then return true end
 local Heal=require('src.core.game3.pokecenter_heal')
 local Doors=require('src.core.game3.doors')
 local Shop=require('src.ui.game3.shop_menu')
 local Fx=require('src.core.game3.field_effects')
 local Special=require('src.core.game3.special_field_anim')
 local Transition=package.loaded['src.core.game3.battle_transition']
 local Warp=require('src.core.game3.warp')
 local escalator=Warp.isEscalatorActive and Warp.isEscalatorActive()
 return (Transition and Transition.isActive and Transition.isActive())
  or (Special.isActive and Special.isActive() and not (escalator or Special.isEscalatorMoving and Special.isEscalatorMoving())) or M.nativeEffects(Fx._anims)
  or (Shop.isShopCamera and Shop.isShopCamera()) or (def.cave==1 and (game.session.flashLevel or 0)>0)
end
local function releaseGeometry(cache)
 for _,part in ipairs(cache.parts or {})do
  if part.under then part.under:release() end
  if part.over then part.over:release() end
  if part.canopy then part.canopy:release() end
  if part.roof then part.roof:release() end
  if part.plants then part.plants:release() end
  if part.water then part.water:release() end
  for _,water in ipairs(part.waters or {})do water.mesh:release()end
 end
 for _,part in ipairs(cache.civics or {})do
  if part.mesh then part.mesh:release()end;if part.image then part.image:release()end
 end
 for _,bld in ipairs(cache.buildingModels or {})do
  if bld.mesh then bld.mesh:release()end;if bld.image then bld.image:release()end
  if bld.imageData and bld.imageData.release then bld.imageData:release()end
 end
 for _,batch in ipairs(cache.treeInstances or {})do batch:release()end
 for _,name in ipairs({'wood','leaves'})do if cache[name] then cache[name]:release() end end
 V.require('Gen3Lamp').release(cache)
end
-- Three scenes stay in memory: the live one and two for return visits.
-- (DEBUG WALK drops the stream to one whole-map scene in prepare.)
local stream=SceneStream.new(releaseGeometry,3)
stream.keepStale=true
M.streaming=stream.stats
-- Tileset identity for the scene keys. The engine keeps only a few tilesets
-- resident (a fifth load evicts one), so a pair can leave and come back as a
-- fresh decode of the same data; that must not restart a build. The first
-- object each pair of the current regions was seen with stands for it, until
-- the provider table itself is replaced (install/invalidate).
local tileMemo,tileOwner={},nil
local function tileIdentity(regions)
 if tileOwner~=Tiles._pairs then tileMemo,tileOwner={},Tiles._pairs end
 local tiles,memo={},{}
 for _,r in ipairs(regions)do
  local pair=r.def.midLayout.pair
  if pair then
   local ts=tileMemo[pair] or Tiles._pairs[pair]
   tiles[pair],memo[pair]=ts,ts
  end
 end
 tileMemo=memo
 return tiles
end
-- A new scene waits, showing the flat map, until each region's tileset is
-- known. Tilesets are decoded by the worker (prefetch); a tileset still missing
-- after 60 frames is decoded here, one per frame. The wait is capped at TILE_WAIT.
local TILE_WAIT=180
M.TILE_PATIENCE=8   -- frames the worker gets per tileset before it is decoded here (60 held a city flat for two seconds more)
M.TILE_PATIENCE_NEIGHBOUR=2   -- (a connected map's tileset; the current map's own is decoded at once)
local tileWait,frames=0,0
local tilesetWaiting={}
local function tilesetsReady(req)
 local ready,decoded=true,false
 for i,r in ipairs(req.regions)do
  local pair=r.def.midLayout.pair
  -- (only the maps the window reaches: Route 110 waited 180 frames - three seconds of flat map - on
  -- the tilesets of Routes 116 and 119, maps the world list holds two hops out that its first area
  -- never touches; a build that reaches a map decodes its tileset itself)
  local reach=i==1 or not req.x0 or (r.x<=req.x1+1 and r.x+r.w>=req.x0-1 and r.y<=req.z1+1 and r.y+r.h>=req.z0-1)
  if pair and reach and not req.tiles[pair]then
   ready=false
   local since=tilesetWaiting[pair] or frames;tilesetWaiting[pair]=since
   -- (the map being entered decodes its own tileset at once: waiting on the worker held the flat map
   -- eight frames before its build could begin; its neighbours still get the worker's frames)
   local patience=i==1 and 0 or M.TILE_PATIENCE_NEIGHBOUR
   if frames-since>=patience and not decoded then decoded=true;Tiles.get(pair)
   else Tiles.prefetch(pair,0)end
  end
 end
 if ready then tilesetWaiting={}end
 return ready
end
-- Entering a map builds the cells round the player first (M.NEAR, a second or so), shows that, and
-- lets the rest of the view distance stream in behind it: the flat map stood for many seconds while a
-- whole city was built before anything was shown.
M.NEAR=14
local CROWN={edges=.45}   -- share of leaf pixels that makes a blocked tile beside a tree a crown edge (grass under the trees)
M.NEAR_NORTH=8
M.NEAR_STREAM=.014
-- background rebuild while walking (ms a frame): at 2 ms a city's rebuild never finished before the
-- player moved on, and the view ran out into the sky
M.STREAM=.008
-- DEBUG WALK (TOUR, see DebugWalk.lua and the game repo's docs/DEBUG-WALK-DESIGN.md):
-- the user saw the scene end 26 cells out and waited for a rebuild every six cells
-- walked; what they asked for is the whole world standing before they move.
-- The chosen scope is one map entry at a time: the current map and the maps it
-- shares an edge with, built whole once and then kept -- walking inside a map
-- moves no bound, so the request key does not change and nothing is rebuilt.
-- Normal play never enters this path.
M.DEBUG_REACH=32     -- cells of connection frontier: every direct neighbour fits
M.DEBUG_PAD=16       -- boundary-fill ring round the union (the old bounds pad)
M.DEBUG_CELLS=12000  -- union cap with pad; above it, the current map alone
M.DEBUG_COLD=.120    -- held-screen slice while the one whole-map build runs
local function walkGate(cam)
 return DebugWalk.on() and not (cam and (cam.battle or cam.replay))
end
-- Direct neighbours as Map.load described them. (Map.neighbors holds only the
-- first map per direction; a map can be reached by two connections, so keep
-- the whole loaded list too.)
local function directNeighbours()
 local ids={}
 for _,n in ipairs(Map.neighborList or {})do if n.map then ids[n.map]=true end end
 for _,n in pairs(Map.neighbors or {})do if n.map then ids[n.map]=true end end
 return ids
end
-- The region list the debug scene is built from. The bounding RECTANGLE of an
-- L-shaped union is mostly fill: a city plus its three routes is 43k cells at a
-- 16-cell pad (ten seconds of held screen), so above DEBUG_CELLS the user gets
-- the map they stand in, whole, instead of all four and a long wait.
local function debugRegions(def)
 local ids=directNeighbours()
 local world={}
 for _,e in ipairs(Map.world or {})do if ids[e.id]then world[#world+1]=e end end
 local regions=Boundary.regions(def,world)
 local x0,z0,x1,z1=BoundarySelect.bounds(regions,0)
 local pad=M.DEBUG_PAD
 if (x1-x0+pad*2)*(z1-z0+pad*2)>M.DEBUG_CELLS then regions=Boundary.regions(def,{})end
 return regions
end
local function request(game,cam,near)
 local replay=cam and cam.replay
 local def=replay and replay.def or Map.currentDef();if not def or not def.midLayout then return false end
 local px,pz=replay and replay.frame.x or Player.px or 0,replay and replay.frame.y or Player.py or 0
 local bx,bz=math.floor(px/96)*6,math.floor(pz/96)*6
 -- The debug gate owns the radius for this frame. forceFull makes radius() nil,
 -- which is what turns on the whole-region build, the scene-bounds fog and the
 -- no-distance-culling path in one switch; false restores all three.
 local debugWalk=walkGate(cam)
 Distance.forceFull=debugWalk
 local budget=Distance.radius()
 local radius=budget and math.ceil(budget/16)or 64
 -- FULL keeps at least FAR's connected-map frontier, then draws each
 -- loaded rectangle completely rather than shrinking back to two hops.
 if not replay then
  if debugWalk then
   -- A bounded frontier still places every direct neighbour; the FULL reach
   -- (140 cells here) would pull in two-hop maps the filtered build drops.
   Map.refreshWorld(game,M.DEBUG_REACH,M.DEBUG_REACH,Map.current)
  else
   Map.refreshWorld(game,radius*2+12,radius*2+12,Map.current)
  end
 end
 local regions
 if replay then
  regions={{def=def,x=0,y=0,w=def.midLayout.width,h=def.midLayout.height}}
 elseif debugWalk then
  regions=debugRegions(def)
 else
  regions=Boundary.regions(def,Map.world)
 end
 local x0,z0,x1,z1=bx-radius,bz-radius,bx+radius+6,bz+radius+6
 -- (a debug scene spans whole maps, so its bounds are the maps' own and do not
 -- move as the player walks: the constant is what keeps the key stable)
 if not budget then x0,z0,x1,z1=BoundarySelect.bounds(regions,debugWalk and M.DEBUG_PAD or 16)end
 if near and not debugWalk and not replay and near<radius then
  radius=near;budget=near*16
  -- (the fixed cameras look north over the player: the first area reaches M.NEAR_NORTH rows further
  -- that way and as many fewer behind the camera, so the whole first view is built, not an island of it)
  local north=(cam and (cam.level or 0)<6) and M.NEAR_NORTH or 0
  x0,z0,x1,z1=math.max(x0,bx-radius),math.max(z0,bz-radius-north),math.min(x1,bx+radius+6),math.min(z1,bz+radius+6-north)
 end
 local tiles=tileIdentity(regions)
 local context=SceneCache.key(regions,0,0,0,0,tiles,cam)
 local key=SceneCache.key(regions,x0,z0,x1,z1,tiles,cam)
 return {game=game,cam=cam,replay=replay,def=def,regions=regions,key=key,tiles=tiles,
  -- Replays and battle culling need immediate, camera-exact geometry. A
  -- warp, Cut/door edit or provider replacement also bypasses retained art.
  context=not (replay or cam.battle) and context or nil,
  x0=x0,z0=z0,x1=x1,z1=z1,px=px,pz=pz,radius=radius,budget=budget}
end
-- per map: tiles that are the black outside of the room (InteriorDiorama.VOID_BY_MAP)
local VOID_BY_MAP=V.require('InteriorDiorama').VOID_BY_MAP
local CABINS=V.require('InteriorDiorama').CABINS
local RISER_PX={[0]={1,8},[0x263]={2,8},[0x264]={2,8},[0x26F]={2,8},[0x277]={2,8}}
-- per map: black rows over a wall's top row of art (not wall: trimmed off)
local WALL_TRIM={EM_NEW_MAUVILLE_INSIDE={[0x26E]=8}}
-- per map: shapes for tiles whose meaning there differs from the tileset's
-- other maps. Lilycove Department Store's rooftop: the stair house stands as
-- a small building (its doorway column included); the rail along the roof's
-- south edge stands at the edge; the store's own front below it (rows 8-11,
-- seen from above) hangs down from the edge, each row where it is drawn.
local SHAPE_BY_MAP={}
-- a lathe shape of a connected map: the same tile shape, its spec (cells of the map it belongs to) moved to the
-- cells where that map is drawn
local shiftedLathes=setmetatable({},{__mode='k'})
local function shiftedLathe(o,dx,dy)
 local by=shiftedLathes[o];if not by then by={};shiftedLathes[o]=by end
 local k=dx..':'..dy
 if not by[k] then
  local l={};for key,v in pairs(o.lathe)do l[key]=v end
  l.x0,l.x1,l.y0,l.y1=o.lathe.x0+dx,o.lathe.x1+dx,o.lathe.y0+dy,o.lathe.y1+dy
  local sh={};for key,v in pairs(o)do sh[key]=v end
  sh.lathe=l;by[k]=sh
 end
 return by[k]
end
do
 local R={}
 for _,m in ipairs({0x24E,0x24F,0x235,0x256,0x257,0x23D,0x27A,0x25E,0x25F,0x245,0x254})do R[m]={kind='roomWall',ground=0x24A} end
 for _,m in ipairs({0x263,0x246,0x247})do R[m]={kind='hang',rail=true,edge=8,ground=0x25B} end
 for _,m in ipairs({0x2E4,0x2E5,0x2E6,0x2EC,0x2ED,0x2EE,0x2F0,0x2F1,0x2F8,0x2F9})do R[m]={kind='hang',edge=8} end
 SHAPE_BY_MAP.EM_LILYCOVE_CITY_DEPARTMENT_STORE_ROOFTOP=R
end
-- Aqua Hideout: white corridor walls drawn from above stand as partitions,
-- its east-west walls (white top over grey face) and their door frames as wall
do
 local R={}
 for _,m in ipairs({0x20A,0x209,0x210,0x211,0x220})do R[m]={kind='partition',ground=0x228} end
 for _,m in ipairs({0x2E0,0x221,0x2C3,0x2C4,0x2C5,0x2CB,0x2CC,0x2CD,0x2B3,0x2B4,0x2B5,0x2BB,0x2BC,0x2BD,0x2D4,0x2D5,0x223,0x224})do
  R[m]={kind='roomWall',ground=0x228} end
 for _,id in ipairs({'EM_AQUA_HIDEOUT_1F','EM_AQUA_HIDEOUT_B1F','EM_AQUA_HIDEOUT_B2F'})do SHAPE_BY_MAP[id]=R end
end
-- the Battle Frontier: white curbs along the cliff tops and the paths stand
-- 5 px (their light pixels: the rock beside them stays rock); flower planters
-- stand 8 px (every pixel that is not the paving round them)
do
 local W,E={},{}
 local function curb(t,ids,g)for _,m in ipairs(ids)do t[m]={kind='extrude',h=5,light=.7,ground=g} end end
 local function box(t,ids,g)for _,m in ipairs(ids)do t[m]={kind='extrude',h=8,ground=g} end end
 curb(W,{0x05D,0x05F,0x045,0x056,0x066,0x065,0x057,0x067,0x04D,0x04E,0x047,0x055,0x257,0x25F,0x3F5,0x3FD,0x3CD},0x05E)
 box(W,{0x208,0x209,0x20A,0x210,0x211,0x212,0x218,0x219,0x21A},0x05E)
 curb(E,{0x3CA,0x3C8,0x3C1,0x066,0x3D1,0x04E,0x047,0x3B7,0x3F9,0x3BF,0x3CB,0x3FD,0x3CC,0x3C7,0x3CF,0x05D,0x05F,0x3BB,0x3D0,0x04F,0x065,0x3C3,0x3C0,0x3C2,0x3C9,0x3D2,0x3F5,0x3A1,0x3AF,0x3BC},0x05E)
 box(E,{0x2CB,0x2CC,0x2CD,0x2C8,0x2C9,0x2D0,0x2F7,0x2FF,0x307},0x05E)
 -- beside the Battle Tower: the glass rail stands 12 px, the red brick strip
 -- is a low wall 6 px (as rock it rose 40 px as a red ridge)
 for _,m in ipairs({0x2D8,0x2E0,0x2E8})do E[m]={kind='extrude',h=12,ground=0x10A} end
 for _,m in ipairs({0x2E1,0x2E2,0x2E9,0x2EA})do E[m]={kind='extrude',h=6,ground=0x10A} end
 for _,m in ipairs({0x149,0x148,0x13A,0x142,0x140})do W[m]={kind='fence',ground=0x001,reviewedSurface=true} end
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_OUTSIDE_WEST=W
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_OUTSIDE_EAST=E
 -- Slateport: the harbour's white curbs and the white post fences stand
 local SL={}
 curb(SL,{0x245,0x23C,0x2B9,0x24D,0x2FF,0x23F,0x255,0x264,0x27E,0x2B8,0x2BA,0x2BB,0x04E},0x001)
 -- (the stake fences are real fences: Gen3Fence SPECS general__slateport)
 for _,m in ipairs({0x142,0x149,0x148,0x14A,0x141,0x13A,0x133})do SL[m]={kind='fence',ground=0x001,reviewedSurface=true} end
 -- the lighthouse on the south pier, turned (Gen3Lathe)
 local LH={x0=32,y0=51,x1=33,y1=54,ground={0x001,0x34C},tower={cx=16,base=14,sections={
  {r=14,h=34,rows=function(y)return y<6 and 49-y or (y>=31 and 43-(y-31) or 52) end},   -- drum: the door, plain wall, its top rows
  {disc=14,row=40},                                                                        -- gallery ledge
  {r=11,h=11,rows=function(y)return 31-y end},                                             -- lantern room with its window band
  {disc=13,row=22},{r=13,h=2,rows=function()return 22 end},{disc=13,row=21},               -- roof skirt
  {r=9,h=5,rows=function(y)return 19-y end},                                               -- upper lantern
  {disc=11,row=13},{r=11,h=1,rows=function()return 13 end},{r=10,h=1,rows=function()return 12 end},
  {r=9,h=1,rows=function()return 11 end},{r=7,h=1,rows=function()return 10 end},{r=5,h=1,rows=function()return 9 end},
  {r=2,h=1,rows=function()return 8 end},{disc=2,row=8}}}}
 for _,m in ipairs({0x246,0x247,0x24E,0x24F,0x256,0x257,0x25E,0x25F})do SL[m]={kind='lathe',lathe=LH,ground=0x001,reviewedSurface=true} end
 -- the hull on the stocks beside the shipyard (2 rows of 3): its drawing stood up as a low hull -- as an
 -- unnamed blocked group it became a tall striped dome
 for _,m in ipairs({0x220,0x221,0x222,0x228,0x229,0x22A})do SL[m]={kind='extrude',h=9,ground=0x001,sidePx={0x229,8,8},reviewedSurface=true} end
 SHAPE_BY_MAP.EM_SLATEPORT_CITY=SL
 -- Route 117: its grey stake fences (Gen3Fence)
 local R117={}
 for _,m in ipairs({0x149,0x148,0x13A,0x138,0x14A,0x142,0x140})do R117[m]={kind='fence',ground=0x001,reviewedSurface=true} end
 SHAPE_BY_MAP.EM_ROUTE117=R117
end
-- Rustboro's fountain (3x3 from 0x338, blocked): a stone basin. Unnamed, Gen3Objects cut it out as a
-- boulder and Gen3Mass turned it into a lumpy dome; here its own picture stands 10 px up on the plaza.
do
 local R={}
 for _,m in ipairs({0x338,0x339,0x33A,0x340,0x341,0x342,0x348,0x349,0x34A})do R[m]={kind='extrude',h=10,ground=0x2BB,cool=true,reviewedSurface=true} end
 -- the west shore's rock bank (drawn as a diagonal lip between the lawn and the sea): a low rock bank,
 -- not a row of tall slabs standing in the water
 for _,m in ipairs({0x17A,0x175})do R[m]={kind='rock',ground=0x170,height=8} end
 SHAPE_BY_MAP.EM_RUSTBORO_CITY=R
end
-- Route 119: the river banks (General 0x17A-0x184: land's edge drawn on the
-- water; as sea boulders they stood as leaning pillars) and the boardwalk's
-- legs are river, flat in their own art; the log bridge's span and the white
-- boardwalk are decks with the river under them
do
 local R={}
 for _,m in ipairs({0x17A,0x17C,0x17D,0x17E,0x182,0x184,0x0F5,0x0F8,0x0F9,0x0FA,0x0FC,0x2C3})do R[m]={kind='flat',reviewedSurface=true,river=true} end
 for _,m in ipairs({0x210,0x218,0x213,0x21B})do R[m]={kind='flat',reviewedSurface=true,underWater=0x206} end
 -- (the boardwalk's tiles carry the river round the planks: only the light planks are deck)
 for _,m in ipairs({0x0ED,0x0F0,0x0F1,0x0F2,0x0FB,0x0E8,0x0EC,0x0F3,0x0F4,0x0F7,0x0FD})do R[m]={kind='flat',reviewedSurface=true,underWater=0x206,planks=.7} end
 SHAPE_BY_MAP.EM_ROUTE119=R
end
-- Route 104 (south): the two stair tiles down from the grass to the beach
-- (16,54 / 17,54 and 28,70 / 29,70) are a flight down to the sand (Gen3Scene
-- 'steps' branch, down=true); Mr. Briney's bank (0x280/0x281/0x283/0x284 are
-- brown rock in the art, rated flat) stands as rock; the one raised grass cell
-- 15,51 (rated a climb between the e3 and e4 floors) is level with the grass.
do
 local R={[0x0AF]={kind='steps',down=true,reviewedSurface=true},[0x0CF]={kind='steps',down=true,reviewedSurface=true}}
 for _,m in ipairs({0x280,0x281,0x283,0x284})do R[m]={kind='rock',ground=0x001,height=8} end
 R.at=function(cx,cy,mid)if cx==15 and cy==51 and mid==0x001 then return {kind='flat',reviewedSurface=true,level=16} end end
 -- Mr. Briney's jetty: boards on posts over the water (kind 'pier'); its landward end lies on the bank
 for _,m in ipairs({0x33D,0x26E})do R[m]={kind='pier',h=16,reviewedSurface=true} end
 for _,m in ipairs({0x345,0x26D})do R[m]={kind='pier',h=16,post={0x276,10,2},posts={2,10},reviewedSurface=true} end
 for _,m in ipairs({0x32E,0x336})do R[m]={kind='pier',h=16,land=true,reviewedSurface=true} end
 SHAPE_BY_MAP.EM_ROUTE104=R
end
-- Mt Chimney: the lava lake (0x2BD) is not rock. The rock builder stood its cells as courses and
-- stepped the shore into blocky ledges (user 2026-10-23: rogue rocks, "use the new rock formation
-- builder"); the counted relief has no data for lava. It lies flat at its own floor, drawing 1:1.
do
 local R={[0x2BD]={kind='flat',reviewedSurface=true}}
 SHAPE_BY_MAP.EM_MT_CHIMNEY=R
end
-- Rustboro Gym's rock maze: walls drawn as blocks (tan top, grey rock front),
-- built as blocks (Gen3ObliqueWall)
do
 local R={}
 for _,m in ipairs({0x220,0x221,0x222,0x223,0x224,0x225,0x228,0x229,0x22A,0x22B,0x21D,0x231})do R[m]={kind='obwall',ground=0x201} end
 SHAPE_BY_MAP.EM_RUSTBORO_CITY_GYM=R
end
-- the link Contest Hall (and its five ranked copies): the pink back wall
-- stands; the stage's blue rim is a low frame, not room wall
do
 local R={[0x260]={kind='roomWall',ground=0x225}}
 for _,m in ipairs({0x20C,0x20D,0x20E,0x224,0x226,0x214,0x216,0x21C,0x21D,0x21E,0x219})do R[m]={kind='extrude',h=4,ground=0x225} end
 for _,id in ipairs({'EM_CONTEST_HALL','EM_CONTEST_HALL_BEAUTY','EM_CONTEST_HALL_TOUGH','EM_CONTEST_HALL_COOL','EM_CONTEST_HALL_SMART','EM_CONTEST_HALL_CUTE'})do SHAPE_BY_MAP[id]=R end
end
-- Trainer Hill. Floors 1F-4F: the maze laid out at run time (white boulders,
-- blue bars) stands from its own pixels. Entrance: the teal counters are low
-- counters (as room walls they stood as tall slabs). The truck: the black
-- tailgate corner is floor.
do
 -- (blocks drawn as a top with their front under it: Gen3ObliqueWall auto
 -- mode, exact at the player camera; floor colours: both mints, the yellow)
 local FLOOR={{140,222,173},{173,247,197},{255,239,148}}
 local F={}
 local fs={auto=7,hBy={[0x230]=4,[0x232]=4,[0x221]=4},floor=FLOOR,perCell=true,
  palette={mid=0x22B,mids={0x22B,0x22C,0x224,0x2CB,0x2C4,0x2CC,0x263,0x264}}}
 -- (the boulders' sides and backs in their own light grey: the commonest face pixel is the dark one)
 fs.bodyBy={}
 for _,m in ipairs(fs.palette.mids)do fs.bodyBy[m]={0x22B,12,4} end
 for _,m in ipairs({0x22B,0x22C,0x230,0x232,0x221,0x224,0x2CB,0x2C4,0x2CC,0x263,0x264})do F[m]={kind='obwall',ground=0x23B,ob=fs} end
 for _,id in ipairs({'EM_TRAINER_HILL_1F','EM_TRAINER_HILL_2F','EM_TRAINER_HILL_3F','EM_TRAINER_HILL_4F'})do SHAPE_BY_MAP[id]=F end
 -- the lobby: counters 9 px tall (their drawn front), everything on them
 -- lies on their top as drawn; the white pole at the counter's east end is a
 -- post standing on it; the wall cells behind stand full height
 local E={}
 local es={auto=9,floor=FLOOR,patch={{15*16+5,8*16,15*16+10,7*16+51}},posts={{x=15*16+5,w=6,top=7*16+19,foot=7*16+51}}}
 for _,m in ipairs({0x305,0x306,0x34A,0x34B,0x315,0x352,0x318,0x319,0x312,0x313,0x314,0x31A,0x31B,0x31C,0x348,0x349,0x30F,0x317,0x31F,0x334,
  0x308,0x303,0x304,0x30B,0x30C})do E[m]={kind='obwall',ground=0x330,ob=es} end
 for _,m in ipairs({0x31E,0x302})do E[m]={kind='roomWall',ground=0x330} end
 E[0x321]={kind='roomWall',ground=0x330,fullHeight=0x329}
 SHAPE_BY_MAP.EM_TRAINER_HILL_ENTRANCE=E
 SHAPE_BY_MAP.EM_INSIDE_OF_TRUCK={[0x220]={kind='flat',groundMid=0x210,reviewedSurface=true}}
end
-- The island harbours (Birth Island, Navel Rock): an open quay. The harbour
-- building's front (pillars, windows, the doorway) stands as wall, the white
-- balustrades stand (Gen3Fence), the black row behind the building is void.
do
 local R={}
 for _,m in ipairs({0x3A5,0x3AD,0x215,0x21D,0x20C,0x214,0x205,0x206,0x207,0x20D,0x20E,0x20F})do R[m]={kind='roomWall',ground=0x3A1} end
 for _,m in ipairs({0x21F,0x3C1,0x3C5,0x22A,0x22B,0x22E})do R[m]={kind='fence',ground=0x3A0,reviewedSurface=true} end
 for _,m in ipairs({0x3C2,0x3C3})do R[m]={kind='fence',ground=0x170,waterGround=true,reviewedSurface=true} end
 SHAPE_BY_MAP.EM_BIRTH_ISLAND_HARBOR=R;SHAPE_BY_MAP.EM_NAVEL_ROCK_HARBOR=R
end
-- Battle Dome. Corridor: the north wall (four rows of art, walkable in the
-- cartridge's data) stands its full 64 px. Battle room: the grandstand is a
-- stand -- the 'BATTLE FRONTIER' boards are its front wall and the three rows
-- of seats behind rise as three steps (4 px riser, 12 px tread per row), each
-- pixel where the player's camera draws it.
do
 local R={}
 for m=0x241,0x25F do if m%8>=1 then R[m]={kind='roomWall',ground=0x340,tall=true} end end
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_DOME_CORRIDOR=R
 local B={}
 local st={board=3,riser=4,h0=16,ground=0x309}
 for m=0x2D0,0x2DA do B[m]={kind='stand',stand=st,ground=0x309} end
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_DOME_BATTLE_ROOM=B
end
-- Battle Arena corridor: walls three rows of art tall (48 px). The north
-- wall stands as wall; the inner wall (rows 8-11) is drawn with its top
-- (row 8) over its front (rows 9-11): a 16 px thick wall whose top shows
-- (Gen3ObliqueWall, front 48). The black courtyard is void.
do
 local R={}
 local ob={auto=48,floor={}}
 for _,m in ipairs({0x256,0x257,0x25E,0x25F,0x266,0x267,0x26B,0x273,0x27B})do
  R[m]=function(cx,cy)
   if cy>=8 then return {kind='obwall',ground=0x201,ob=ob} end
   return {kind='roomWall',ground=0x201,tall=true}
  end
 end
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_ARENA_CORRIDOR=R
end
-- Battle Tent battle rooms: the two rows of north wall with the doorway are
-- walkable in the data (they lay flat or were left out); the floor's shaded
-- edge tiles along the wall and the west side (blocked) are floor, not slabs.
do
 local function room(ground,flat)
  return {at=function(cx,cy,mid)
   if cy<=1 then return {kind='roomWall',ground=ground} end
   if flat and mid>=0x290 and mid<=0x294 then return {kind='flat',noFurniture=true} end
  end}
 end
 SHAPE_BY_MAP.EM_FALLARBOR_TOWN_BATTLE_TENT_BATTLE_ROOM=room(0x210,true)
 SHAPE_BY_MAP.EM_SLATEPORT_CITY_BATTLE_TENT_BATTLE_ROOM=room(0x210,true)
 SHAPE_BY_MAP.EM_VERDANTURF_TOWN_BATTLE_TENT_BATTLE_ROOM=room(0x001)
end
-- Route 111's Mirage Tower (furniture session with the user: its outline
-- stood off it as loose hoops and wires, its faded top was a separate lighter
-- block): one round body turned from its drawing -- every drawn row a ring as
-- wide as the tower's outline in that row, each pixel on the ring's surface,
-- the faded upper rows the same body in their paler colours.
do
 local T={x0=18,y0=53,x1=20,y1=58,axis=true,ground={0x251,0x259,0x25A,0x121}}
 local M={}
 for m=0x3D8,0x3F2 do if (m%8<=2 and m>=0x3D8) or (m>=0x3DB and m<=0x3DD) or (m>=0x3E3 and m<=0x3E5) then M[m]={kind='lathe',lathe=T,ground=0x251,reviewedSurface=true,noFurniture=true} end end
 SHAPE_BY_MAP.EM_ROUTE111=M
end
-- Safari Zone South's Acro Bike rails (furniture session: "solid boxes
-- textured with grass"): a white plank 5 px deep with its 3 px front edge
-- (drawn at the top of the cell below), carried on two thin posts over the
-- grass. The plank's cell is rated as high as the ledges it joins; only the
-- plank stands up there -- the grass round it is the ground below, and the
-- posts reach down to it. (The rail's ends on the rock, 0x312/0x314/0x320/
-- 0x322, are the ledge itself and stay as they are.)
local RAIL_EDGE={[0x316]=true,[0x31E]=true,[0x321]=true,[0x315]=true,[0x320]=true,[0x322]=true}
local RAIL_POSTS={[0x315]=true,[0x316]=true,[0x31E]=true}
local RAIL_ROCK={[0x312]=true,[0x314]=true}
do
 local top={kind='rail',top=true,noFurniture=true}
 local foot={kind='rail',noFurniture=true}
 SHAPE_BY_MAP.EM_SAFARI_ZONE_SOUTH={[0x313]=top,[0x31D]=top,[0x316]=top,[0x31E]=top,[0x321]=foot,[0x315]=foot}
end
-- Slateport's orange stall awnings (furniture session: "lie flat on the
-- ground with only one pole standing"): a cloth on two poles, walked under,
-- drawn over the player. The cloth lies 23 px up and as far south as it is
-- drawn high, its scalloped valance (7 rows) hangs at its front edge, right
-- over the two poles, which stand their 14 px from their drawing.
do
 -- (user, 2026-10-18: far too low -- the cloth hung at head height; it now rides AWNING_UP higher on taller poles)
 local AWNING_UP=14
 local ob={auto=7,over=true,noGap=true,floor={},floorMids={0x001},hBy={[0x263]=16+AWNING_UP,[0x264]=16+AWNING_UP},
  overOnly={},liftBy={},liftUp={}}
 local cloth={kind='obwall',ground=0x001,ob=ob,walkOk=true,overArt=true}
 local pole={kind='obwall',ground=0x001,ob=ob}
 local S=SHAPE_BY_MAP.EM_SLATEPORT_CITY or {};SHAPE_BY_MAP.EM_SLATEPORT_CITY=S
 for _,m in ipairs({0x270,0x271,0x272,0x278,0x279,0x27A,0x216,0x21E})do S[m]=cloth;ob.overOnly[m]=true;ob.liftBy[m]=16;ob.liftUp[m]=AWNING_UP end
 S[0x263]=pole;S[0x264]=pole
end
-- Battle Palace lobby: the foot of the golden alcove with the PC (the top
-- rows of the walkable cells under it) stands as its plinth, back to the wall
-- (it lay on the floor as a strip).
do
 local ob={auto=8,noGap=true,backToTop=true,floor={},floorMids={0x203,0x201}}
 local foot={kind='obwall',ground=0x203,ob=ob,walkOk=true}
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_PALACE_LOBBY={[0x29B]=foot,[0x29C]=foot,[0x29D]=foot}
end
-- The harbours (Lilycove, Slateport): the hall's far wall with its windows,
-- four rows of art (three of them walkable in the data), stands its 64 px
-- behind the dock (it lay flat). Battle Factory battle room: the back wall
-- with the windows and the doorway (rows 0-1, walkable in the data) stands.
do
 local far={kind='roomWall',ground=0x202,tall=true}
 local H={at=function(cx,cy)if cy<=3 then return far end end}
 SHAPE_BY_MAP.EM_LILYCOVE_CITY_HARBOR=H;SHAPE_BY_MAP.EM_SLATEPORT_CITY_HARBOR=H
 local back={kind='roomWall',ground=0x28A}
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_FACTORY_BATTLE_ROOM={at=function(cx,cy)if cy<=1 then return back end end}
end
-- Dewford Gym (furniture session: "scattered boards rather than a walled
-- maze"): the maze is raised masses drawn as a top -- brown slats inside a
-- cream rim -- over a front of slats, grey and a teal band (24 px). They
-- stand from their drawing as solid blocks; the rim's north edge is drawn on
-- the walkable cells behind each mass and belongs to its top.
do
 local ob={auto=24,over=true,floor={},floorMids={0x209,0x210},body={0x224,8,2},wallArt=true,
  solid={[0x21C]=true,[0x21D]=true,[0x21E]=true,[0x224]=true,[0x225]=true,[0x226]=true}}
 local D={}
 for _,m in ipairs({0x204,0x207,0x208,0x20C,0x20E,0x20F,0x214,0x217,0x21C,0x21D,0x21E,0x224,0x225,0x226,0x221,0x229})do
  D[m]={kind='obwall',ground=0x209,ob=ob} end
 for _,m in ipairs({0x205,0x222,0x212,0x21A,0x215,0x216,0x218,0x21B,0x211,0x213,0x20D,0x223})do
  D[m]={kind='obwall',ground=0x209,ob=ob,walkOk=true} end
 SHAPE_BY_MAP.EM_DEWFORD_TOWN_GYM=D
end
-- Rustboro's flats (Flat 2, 1F-3F): the two partitions are walls drawn as a
-- white top over the wallpapered front -- the one running north-south seen
-- from above with its end face, the one running east-west with its top on
-- the walkable row behind it. They stand from their drawing as solid walls
-- 32 px tall, wallpaper-coloured on their sides and back (plain olive
-- before). The same wall tiles in rows 0-1 are the room's north wall.
do
 local ob={auto=32,over=true,noGap=true,wallArt=true,body={0x340,8,4},
  floor={{66,74,107},{140,140,140},{181,181,165},{214,214,181},{222,214,82},{247,247,165}},
  solid={[0x338]=true,[0x340]=true,[0x29E]=true,[0x29F]=true,[0x2DF]=true,[0x2E7]=true,[0x300]=true,[0x2D7]=true}}
 local wall={kind='obwall',ground=0x32C,ob=ob}
 local top={kind='obwall',ground=0x32C,ob=ob,walkOk=true}
 local F={[0x2D7]=wall,[0x300]=wall,[0x2DF]=wall,[0x2E7]=wall,[0x29E]=wall,[0x29F]=wall,[0x31E]=top,[0x29D]=top,
  [0x338]=function(cx,cy)if cy>=5 then return wall end end,[0x340]=function(cx,cy)if cy>=5 then return wall end end}
 for _,n in ipairs({'1F','2F','3F'})do SHAPE_BY_MAP['EM_RUSTBORO_CITY_FLAT2_'..n]=F end
end
-- Trick House puzzles 1 and 3: the maze's walls, pillars, cabinets and paper
-- doors are drawn as a cream top over a wood front (the top's upper edge and
-- the front's foot line on the walkable tatami cells beside them); they
-- stand from their own drawing (Gen3ObliqueWall), 14 px tall in puzzle 1 and
-- 22 px in puzzle 3 (they stood as thin plain boards and big cards).
do
 local FLOOR={{132,173,74},{140,140,140},{165,206,107},{197,255,173},{107,140,49}}
 local function maze(h,body,blocked,walk)
  local ob={auto=h,over=true,noGap=true,floor=FLOOR,body=body,wallArt=true}
  local N={}
  for _,m in ipairs(blocked)do N[m]={kind='obwall',ground=0x208,ob=ob} end
  for _,m in ipairs(walk)do N[m]={kind='obwall',ground=0x208,ob=ob,walkOk=true} end
  return N
 end
 SHAPE_BY_MAP.EM_ROUTE110_TRICK_HOUSE_PUZZLE1=maze(14,{0x224,8,9},
  {0x223,0x224,0x225,0x22B,0x221,0x222,0x22A,0x22C,0x228,0x230},{0x25A,0x21A,0x21B,0x21C,0x21D})
 SHAPE_BY_MAP.EM_ROUTE110_TRICK_HOUSE_PUZZLE3=maze(22,{0x235,8,4},
  {0x226,0x22D,0x21E,0x235,0x24D,0x23A,0x242,0x22E,0x22F,0x236,0x237,0x240,0x241,0x222},
  {0x271,0x255,0x238,0x239,0x218,0x219})
end
-- Trick House puzzle 5: the navy between the tatami islands is the dark gap
-- between them (it stood as blocks of wall)
SHAPE_BY_MAP.EM_ROUTE110_TRICK_HOUSE_PUZZLE5={[0x268]={kind='flat',noFurniture=true}}
-- Trainer Hill's roof: the posts of its side rails are drawn on the roof
-- tiles (they stood as one squashed wall); flat until they get a post of
-- their own like the front row's.
SHAPE_BY_MAP.EM_TRAINER_HILL_ROOF={[0x3C5]={kind='flat'},[0x3C6]={kind='flat'}}
-- New Mauville: every wall is drawn as a block -- its cream top (5 px) over
-- its khaki face (23 px) -- whichever way it runs: north walls, the walls
-- along a room's south edge (their top and upper face drawn on the walkable
-- floor row above), the side walls and partitions seen from above with their
-- end faces. All of them stand from their own drawing (Gen3ObliqueWall): the
-- last 23 rows of each pixel column are its front, the rows above its top.
-- The pipes lying on the floor stay flat; the black is void.
do
 local ob={auto=23,through=true,over=true,noGap=true,voidGround=0x208,body={0x227,8,3},floor={{132,148,140},{173,189,173},{206,206,206},{214,222,214},{0,0,0}}}
 local N={}
 local black={0x21F,0x25C,0x25D,0x260,0x261,0x268,0x26A,0x270,0x272,0x278,0x27A,0x280,0x282,0x288,0x289,0x28A,0x28B,0x28C,
  0x299,0x29A,0x29F,0x2A7,0x2A8,0x2B6,0x2B7}
 local plain={0x227,0x277,0x290,0x291,0x293,0x294,0x295,0x296,0x298,0x2A0,0x2A5,0x2A6,0x2B1,0x2B4,0x2BE,0x2BF,0x2CE,0x2CF}
 ob.solid={}
 for _,m in ipairs(black)do N[m]={kind='obwall',ground=0x208,ob=ob};ob.solid[m]=true end
 for _,m in ipairs(plain)do N[m]={kind='obwall',ground=0x210,ob=ob};ob.solid[m]=true end
 ob.solid[0x2CE],ob.solid[0x2CF]=nil,nil      -- (floor shows over these two)
 -- (the walkable floor row carrying a south wall's top)
 for _,m in ipairs({0x237,0x279,0x28D,0x28E,0x29D,0x29E,0x287,0x297,0x292,0x26F})do N[m]={kind='obwall',ground=0x210,ob=ob,walkOk=true} end
 N[0x2C6]={kind='flat',noFurniture=true};N[0x2C7]=N[0x2C6]
 SHAPE_BY_MAP.EM_NEW_MAUVILLE_INSIDE=N
end
-- Battle Tower elevator: the back wall's west column (unblocked in the data)
-- is wall like the rest of it.
do
 -- the car's back wall is three rows of art: it stands its full 48 px
 local w={kind='roomWall',ground=0x265,tall=true,trimTop=8}
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_TOWER_ELEVATOR={at=function(cx,cy)if cy<=2 then return w end end}
end
-- Battle Factory pre-battle room: the back wall with its pipes and shutters
-- is four rows of art (64 px; most of it unblocked in the data and it lay on
-- the floor); the five pillars stand 32 px proud of it, their tops (rows 0-1)
-- over their fronts (rows 2-5).
do
 local pillar={kind='obwall',ground=0x201,ob={auto=64,floor={}}}
 local wall={kind='roomWall',ground=0x201,tall=true,sideArt=true}
 -- (the two middle bays' wall comes down to row 5 with a dark doorway at its
 -- foot; the pillars are flush with it, their whole drawing front: 96 px.
 -- The two outer bays are alcoves, their wall four rows.)
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_FACTORY_PRE_BATTLE_ROOM={at=function(cx,cy)
  if cy<=5 and (cx%4==0 or (cx>=5 and cx<=11)) then return wall end
  if cy<=3 then return wall end
 end}
 -- Battle Dome pre-battle room: the back wall (the lights band over the
 -- panels, unblocked in the data) stands; behind the two plants it is whole
 SHAPE_BY_MAP.EM_BATTLE_FRONTIER_BATTLE_DOME_PRE_BATTLE_ROOM={at=function(cx,cy,mid)
  if cy==0 and cx>=7 then return {kind='roomWall',ground=0x346,fullHeight=0x358} end
  if cy<=1 and cx>=2 and cx<=6 and mid~=0x202 and mid~=0x20A then return {kind='roomWall',ground=0x346} end
 end}
end
-- The ships' corridors (S.S. Tidal, Abandoned Ship): the block of cabins in
-- the middle is a block -- its white top (rows of 0x230-0x232) over its
-- front with the cabin doors (two rows, 32 px), read per pixel column.
do
 local R={}
 -- (its sides and back in the cabin fronts' tan; the yellow door 0x233 is
 -- part of the front; an open doorway 0x2AE/0x2B6 is drawn on the front too
 -- and walked into)
 local ob={auto=32,floor={},floorFromWalkable=true,body={0x22B,5,5}}
 for _,m in ipairs({0x230,0x231,0x232,0x225,0x223,0x224,0x222,0x226,0x22D,0x22B,0x27B,0x22A,0x2FB,0x22C,0x22E,0x233})do R[m]={kind='obwall',ground=0x2BA,ob=ob} end
 for _,m in ipairs({0x2AE,0x2B6})do R[m]={kind='obwall',ground=0x2BA,ob=ob,walkOk=true} end
 for _,id in ipairs({'EM_SS_TIDAL_CORRIDOR','EM_ABANDONED_SHIP_CORRIDORS_1F','EM_ABANDONED_SHIP_CORRIDORS_B1F','EM_ABANDONED_SHIP_HIDDEN_FLOOR_CORRIDORS'})do SHAPE_BY_MAP[id]=R end
end
-- rooms under open sky (no room shell, the outdoor background)
-- (the islands reached by ferry are outdoors too: they stood against a black sky)
local OPEN_SKY={EM_LILYCOVE_CITY_DEPARTMENT_STORE_ROOFTOP=true,EM_TRAINER_HILL_ROOF=true,EM_BIRTH_ISLAND_HARBOR=true,EM_NAVEL_ROCK_HARBOR=true,
 EM_BIRTH_ISLAND_EXTERIOR=true,EM_FARAWAY_ISLAND_ENTRANCE=true,EM_FARAWAY_ISLAND_INTERIOR=true,EM_NAVEL_ROCK_EXTERIOR=true}
M.OPEN_SKY=OPEN_SKY
-- true while the first area round the player is built on entering a map (M.NEAR): heavy models
-- may stand in cheap for it (Gen3Objects' round trees), the full build that follows makes them whole
local firstArea=false
function M.firstArea()return firstArea end
local function build(req,cache,previous)
 local cam,replay,def,regions=req.cam,req.replay,req.def,req.regions
 local x0,z0,x1,z1=req.x0,req.z0,req.x1,req.z1
 firstArea=M.NEAR~=nil and req.budget~=nil and req.radius==M.NEAR and not cam.battle and not replay and not req.upgrade
 cache.firstAreaBuilt=firstArea
 V.require('Gen3Objects').newBuild();V.require('Gen3Mass').newBuild();V.require('Gen3Terrain').newBuild();V.require('Gen3Planter').newBuild()
 local M=cache -- Publish geometry and its metadata together, never halfway.
 -- stage times (ms of build work so far, to the slice), for tools: Scene.buildTimes
 local marks={};cache.buildTimes=marks
 local CamClear=V.require('Gen3CamClear');cache.solid=CamClear.new()   -- (solid tops for the camera arm, see Gen3CamClear)
 local function mark(name)marks[#marks+1]=name..' '..math.floor(stream.stats.buildMs or 0)end
 M.sceneDef=def
 M.distance={radius=req.radius,full=not req.budget,regions=#regions,bounds={x0,z0,x1,z1}}
 M.fadeExtent=req.budget or math.max(math.abs(x0*16-req.px),math.abs(x1*16-req.px),math.abs(z0*16-req.pz),math.abs(z1*16-req.pz))
 local cells,groups,signature={}, {}, {replay and replay.scene.map or Map.current,x0,z0,x1,z1}
 M.fillCounts={forest=0,water=0,mountain=0,ground=0}
 for cy=z0,z1 do for cx=x0,x1 do
  Budget.tick()
  local mid,pair,isVoid
  if replay then
   local tile=replay.scene.tiles and replay.scene.tiles[cx..','..cy]
   isVoid=cx<0 or cy<0 or cx>=def.midLayout.width or cy>=def.midLayout.height
   if tile then mid,pair,isVoid=tile[1],tile[2],false
   elseif not isVoid then mid,pair=def.midLayout:midAt(cx,cy),def.midLayout.pair end
  else mid,pair,isVoid=Map.worldMidAt(cx,cy,def)end
  -- black padding drawn inside a room's map, outside its walls: left
  -- unbuilt like the space beyond the map (VOID_BY_MAP)
  if mid and not isVoid and def.id and VOID_BY_MAP[def.id] and VOID_BY_MAP[def.id][mid] then isVoid=true end
  local fillShape,biome
  if isVoid and Pairs.outdoor(def) then
   local m,p,shape,kind=Boundary.resolve(regions,cx,cy)
   if m then mid,pair,fillShape,biome=m,p,shape,kind;M.fillCounts[kind]=M.fillCounts[kind]+1 end
  end
  if mid and pair and not (isVoid and not Pairs.outdoor(def)) then
   local ts=groups[pair]
   if not ts then
    -- get() also rebinds the native animation clock. Reuse the provider's
    -- current objects so connected-map scenery cannot reset water every draw.
    ts=Tiles._pairs[pair] or Tiles.get(pair);groups[pair]=ts
   end
   if ts and ts.midToSlot[mid] then
    local spec=Pairs.resolve(pair,Versions.TILESET_PAIRS)
    local collision
    for _,region in ipairs(regions)do
     local lx,ly=cx-region.x,cy-region.y
     if lx>=0 and ly>=0 and lx<region.w and ly<region.h then collision=region.def.midLayout:collAt(lx,ly);break end
    end
    local c={mid=mid,behavior=(require('src.core.game3.scripting.interaction_scripts').behaviors[pair] or {})[mid],collision=collision,pair=Pairs.canonical(pair),nativePair=pair,cx=cx,cy=cy,ts=ts,primary=spec.primary,secondary=spec.secondary,
     shape=fillShape or Shapes.of(spec.primary,spec.secondary,mid,
      (require('src.core.game3.scripting.interaction_scripts').behaviors[pair] or {})[mid],collision),boundary=biome}
    V.require('GlassMask').door(ts,c.mid,c.behavior)
    -- Mt. Pyre's halls: the black map padding stands as wall in the grey
    -- stone of its own walls (black slabs read as void blocks)
    if c.mid==0x201 and spec.secondary=='facility' and def.id and def.id:find('MT_PYRE') and c.shape and c.shape.kind=='roomWall' then c.mid=0x2F7 end
    -- (per-map shapes are for the map's own cells, not the connected maps drawn round it)
    do local ov=def.id and not isVoid and cx>=0 and cy>=0 and cx<def.midLayout.width and cy<def.midLayout.height and SHAPE_BY_MAP[def.id];local o=ov and ov[mid]
     -- (an entry may depend on where the tile stands; `at` answers for any tile by place)
     if type(o)=='function' then o=o(cx,cy,collision) end
     if not o and ov and ov.at then o=ov.at(cx,cy,mid,collision) end
     if o and not (o.kind=='extrude' and (collision or 0)==0) and not (o.kind=='obwall' and (collision or 0)==0 and not o.walkOk) then c.shape=o end end
    -- (the one exception: a turned landmark of a connected map -- Slateport's lighthouse seen from Route 109 --
    -- stands as it does at home: its spec names cells of its own map, moved by the region's offset)
    if not (def.id and not isVoid and cx>=0 and cy>=0 and cx<def.midLayout.width and cy<def.midLayout.height) then
     for _,region in ipairs(regions)do
      local lx,ly=cx-region.x,cy-region.y
      if region.def~=def and region.def.id and lx>=0 and ly>=0 and lx<region.w and ly<region.h then
       local rs=SHAPE_BY_MAP[region.def.id];local o=rs and rs[mid]
       if type(o)=='table' and o.kind=='lathe' and o.lathe and (region.x~=0 or region.y~=0) then c.shape=shiftedLathe(o,region.x,region.y) end
       break
      end
     end
    end
    -- walls built from their own drawing take no furniture stand-in
    if c.shape and (c.shape.kind=='obwall' or c.shape.kind=='partition' or c.shape.noFurniture) then c.noFurniture=true end
    cells[cx..':'..cy]=c
    signature[#signature+1]=pair..'/'..mid..'/'..tostring(collision)..(biome or '')
   else signature[#signature+1]='?' end
  else signature[#signature+1]='-' end
 end end
 Tiles.get(def.midLayout.pair)
 -- Provider replacement (palette reload) invalidates meshes even if IDs match.
 for pair,ts in pairs(groups)do signature[#signature+1]=pair..tostring(ts) end
 -- ground only, never yaw: see the note in lib/Gen3SceneCache.lua
 if cam and cam.battle then signature[#signature+1]=table.concat({'battle',cam.center[1],cam.center[2]},':')end
 local sig=SceneCache.key(regions,x0,z0,x1,z1,Tiles._pairs,cam) or table.concat(signature,';')
 -- (a first-area build stands trees in cheap and leaves the glass out: the full build is never it again)
 if firstArea then sig=sig..';first' end
 if previous and previous.signature==sig then return previous end
 cache.signature=sig;cache.parts={};cache.cells=cells
 local treeGroups={}
 mark('cells')
 -- A blocked cell whose tile is tree crown (the edge of a crown drawn over the next row: a narrow tree's
 -- top in a fence line, half crowns between two tree rows) stood as a striped green box beside the 3D
 -- trees that already hold that crown. Next to a tree it is grass under the trees.
 if CROWN.edges then
  local leafy={}
  for _,c in pairs(cells)do
   local sh=c.shape
   if sh and (c.collision or 0)~=0 and (sh.kind=='flat' or sh.kind=='wall') and not sh.reviewedSurface and not (c.prop or c.bldModel or c.civic) and c.ts and c.ts.imageData then
    local ts=c.ts;local t=leafy[ts];if not t then t={};leafy[ts]=t end
    local r=t[c.mid]
    if r==nil then
     r=false
     local slot,gs=ts.midToSlot[c.mid],ts.midToSlot[0x001]
     if slot and gs then
      local ground={}
      for y=0,15 do for x=0,15 do local rr,gg,bb=ts.imageData:getPixel(gs%ts.cols*16+x,math.floor(gs/ts.cols)*16+y);ground[math.floor(rr*255)*65536+math.floor(gg*255)*256+math.floor(bb*255)]=true end end
      local n=0
      for y=0,15 do for x=0,15 do
       local px,py=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
       local rr,gg,bb=ts.imageData:getPixel(px,py)
       if ts.overImageData then local r2,g2,b2,a2=ts.overImageData:getPixel(px,py);if a2>.5 then rr,gg,bb=r2,g2,b2 end end
       if gg>rr*1.1 and gg>bb*1.05 and not ground[math.floor(rr*255)*65536+math.floor(gg*255)*256+math.floor(bb*255)] then n=n+1 end
      end end
      r=n>=CROWN.edges*256
     end
     t[c.mid]=r
    end
    if r then
     for dy=-1,1 do for dx=-1,1 do
      local n=cells[(c.cx+dx)..':'..(c.cy+dy)]
      if n and n~=c and n.shape and n.shape.kind=='tree' then c.shape={kind='flat',reviewedSurface=true,groundMid=0x001,crownEdge=true};c.column=nil;goto done end
     end end
     ::done::
    end
   end
  end
 end
 local bldModels=BuildingModels.prepare(cells,def,regions);M.buildingCount=#bldModels
 mark('buildings')
 M.forestTrees=Forest.prepare(cells)
 local gyms=Buildings.prepare(cells);M.gymCount=#gyms
 local civics=Civic.prepare(cells,gyms,V.data("gen3_exteriors"));M.civicCount=#civics
 Elevation.daisPrepare(cells,def)
 Decks.prepare(cells,def)
 -- (a stepped deck stands as far south of its drawing as it is lifted: every lift of this build sets back too)
 local setBack=Decks.MAPS[def.id or ''] and true or false
 M.stairCount=Stairs.prepare(cells)
 local props=Furniture.extract(cells)
 cache.openings={}
 for _,p in ipairs(props)do if p.recipe.noGround and p.recipe.down then
  cache.openings[#cache.openings+1]={p.cx*16,p.cy*16,(p.cx*16)+p.w,(p.cy*16)+p.d}
 end end
 for _,c in pairs(cells)do if c.stairs and c.stairs.owner==c and c.stairs.r.down then
  local s=c.stairs;cache.openings[#cache.openings+1]={s.cx*16,s.cy*16,(s.cx+s.width)*16,(s.cy+#s.r.rows)*16}
 end end
 Shapes.layout(cells)
 Outdoor.groundProps(cells)
 for _,c in pairs(cells)do if c.gym then c.column=Buildings.column(c.gym)end end
 M.bankCount=Standing.bank(cells,Pairs.outdoor(def))
 M.rockJoined=Standing.joinRock(cells,Pairs.outdoor(def))
 mark('prepares')
 M.objectCount=#Standing.prepare(cells,Pairs.outdoor(def))
 V.require('Gen3TreeStamps').claim(cells)
 Elevation.bind(cells,regions)
 -- a cell rated a climb but drawn level (SHAPE_BY_MAP level=) stands at that height for its neighbours too: left at
 -- its rated height it raised a mini staircase of its own (Route 104's 15,51 beside the jetty)
 for _,c in pairs(cells)do if c.shape and c.shape.level and c.base~=c.shape.level then c.base=c.shape.level;c.floorHigh=nil end end
 -- Slateport's east sea carries a rated height (a block of water 16 px up, with walls round it): the sea is one level
 if def and SEA_LEVEL_MAPS[def.id] then
  local w,h=def.midLayout.width,def.midLayout.height
  for _,c in pairs(cells)do
   if c.shape and c.shape.kind=='water' and not c.shape.river and (c.base or 0)~=0 then c.base=0;c.floorHigh=nil end
  end
  -- (and the two sea-edge tiles 0x164/0x16C beside the grove, drawn almost all water, stood up there as a raised blue
  -- slab: they are sea, taken from the water beside them)
  -- (a pass at a time, each deciding from the cells as the last pass left them: a tile beside another one
  -- just turned to sea took that one's tile or the next water's, by pairs() order)
  for _=1,8 do
   local turn={}
   for _,c in pairs(cells)do
    if c.shape and c.shape.kind=='cliff' and (c.mid==0x164 or c.mid==0x16C) and c.cx>=0 and c.cy>=0 and c.cx<w and c.cy<h then
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and n.shape and n.shape.kind=='water' and not n.shape.river then turn[#turn+1]={c,n};break end
     end
    end
   end
   if #turn==0 then break end
   for _,t in ipairs(turn)do local c,n=t[1],t[2];c.shape=n.shape;c.mid=n.mid;c.base=0;c.floorHigh=nil end
  end
 end
 -- a river (shape.river: water you cannot surf, its banks) lies at one level:
 -- the lowest open ground or surfable water touching it (blocked cells took
 -- the nearest deck's height: water floated as boxes with holes between)
 do
  local seen={}
  for _,c0 in pairs(cells)do if c0.shape and c0.shape.river and not seen[c0] then
   local comp,st,low={},{c0},nil;seen[c0]=true
   while #st>0 do
    local c=table.remove(st);comp[#comp+1]=c
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape then
      if n.shape.river then if not seen[n] then seen[n]=true;st[#st+1]=n end
      elseif n.shape.underWater then
      elseif (n.collision or 0)==0 or (n.shape.kind=='water' and not n.shape.river and (n.base or 0)==0) then
       low=math.min(low or 1e9,n.base or 0)
      end
     end
    end
   end
   low=low or 0
   for _,c in ipairs(comp)do c.base=low;c.floorHigh=nil end
   for _,c in ipairs(comp)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.shape and n.shape.underWater then n.riverLevel=low end
   end end
  end end
  -- decks pass the level along (a bridge several cells deep)
  for _=1,4 do for _,c in pairs(cells)do if c.shape and c.shape.underWater and not c.riverLevel then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.riverLevel then c.riverLevel=n.riverLevel;break end end
  end end end
 end
 -- a blocked shore-water cell (rock drawn on the water at a cliff's foot) lies
 -- at the level of the open water beside it, not at the cliff's height
 do
  local fix={}
  for _,c in pairs(cells)do if c.shape and c.shape.kind=='water' and not c.shape.river and (c.collision or 0)~=0 and (c.base or 0)>0 then
   local low
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.shape and n.shape.kind=='water' and (n.collision or 0)==0 then low=math.min(low or 1e9,n.base or 0) end
   end
   if low and low<(c.base or 0) then fix[c]=low end
  end end
  for c,h in pairs(fix)do c.base=h;c.floorHigh=nil end
 end
 -- every rock standing in the sea stands at the water's height round it (the
 -- elevation handed sea boulders by a cliff the cliff's height: Lilycove's
 -- east cliff boulders floated 32 px up as blue blocks)
 do
  local fix={}
  for _,c in pairs(cells)do if c.shape and c.shape.seaRock and (c.base or 0)>0 then
   local low
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.shape and n.shape.kind=='water' then low=math.min(low or 1e9,n.base or 0) end
   end
   if low and low<(c.base or 0) then fix[c]=low end
  end end
  for c,h in pairs(fix)do c.base=h;c.floorHigh=nil end
 end
 -- grass drawn with a cliff's rim line along its north edge (General 0x002)
 -- on top of a real step: the step shows the edge, the drawn line would lie
 -- on the grass as a brown seam (Lilycove's east cliff)
 for _,c in pairs(cells)do
  if c.mid==0x002 and c.primary=='general' and c.shape and c.shape.kind=='flat' and not c.shape.groundMid then
   local n=cells[c.cx..':'..(c.cy-1)]
   if n and (n.base or 0)<(c.base or 0)-4 then
    local sh={};for k,v in pairs(c.shape)do sh[k]=v end;sh.groundMid=0x001;c.shape=sh
   end
  end
 end
 -- Route 110: the sea's 2x2 boulders (0x150/0x151/0x158/0x159) and the shore
 -- ledge 0x173 took the Cycling Road deck's 48 px and floated in the sky:
 -- they stand in the sea
 if def.id=='EM_ROUTE110' then
  local SEA={[0x150]=true,[0x151]=true,[0x158]=true,[0x159]=true,[0x173]=true}
  for _,c in pairs(cells)do if c.pair=='general__mauville' and (SEA[c.mid] or (c.shape and c.shape.kind=='water' and not c.shape.cyclingRoad and c.cx<7)) then c.base=0;c.floorHigh=nil end end
 end
 mark('objects')
 -- A boulder in the sea is one stone at one level: one straddling a step in a river (Route 119) had its
 -- top row rated with the upper water and stood as flat pieces at two heights
 do local low={}
  for _,c in pairs(cells)do local o=c.object or c.objectTop
   if o and c.shape and c.shape.seaRock then low[o]=math.min(low[o] or 1e9,c.base or 0) end end
  for _,c in pairs(cells)do local o=c.object or c.objectTop
   if o and low[o] and c.shape and c.shape.seaRock then c.base=low[o];c.floorHigh=nil end end
 end
 V.require('Gen3CyclingRoad').settle(cells)
 Elevation.daisSettle(cells,def)
 Decks.settle(cells,def)
 -- A blocked water-edge cell (a rock's rim drawn in a lake) takes its height
 -- from the nearest floor, which may be a bridge or a bank above: it is at
 -- the level of the water beside it (Route 120's lake stood in steps). Until nothing moves: three
 -- passes in pairs() order spread it a different distance on each visit (Mt. Pyre Summit's rim water
 -- stood 0, 16 or 32 px up from one visit to the next).
 for _=1,256 do local moved=false
  for _,c in pairs(cells)do
   if c.shape and c.shape.kind=='water' and (c.collision or 0)~=0 and (c.base or 0)>0 then
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and n.shape.kind=='water' and (n.base or 0)<c.base then c.base=n.base or 0;moved=true end
    end
   end
  end
  if not moved then break end
 end
 V.require('Gen3Rock').mapId=def and def.id
 V.require('Gen3Rock').cave(def)
 -- In a cave every blocked cell that is not furniture, water or a built
 -- thing is rock: the tile tables miss many wall tiles (Magma Hideout's
 -- slanted wall tops and corner pieces stood at floor level, which left holes
 -- beside raised floors), and a blocked floor-coloured cell is a ledge's top.
 if V.require('Gen3Rock').CAVES[def.id or ''] then
  for _,c in pairs(cells)do
   local k=c.shape and c.shape.kind
   if (k=='flat' or k=='rock') and c.collision==7 and not (c.prop or c.stairs or c.object or c.objectTop or c.civic or c.bldModel or c.column or c.noFurniture)
     and c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height and c.ts and c.ts.midToSlot[c.mid] then
    -- (in a secret base a blocked floor-coloured cell is its wall of leaves or sand, a tile tall)
    c.shape={kind='caveWall',height=28,ground=c.shape.ground,cap=c.mid,side=c.mid,fromBlocked=tonumber(def.mapType)~=9}
   end
   -- the exit arch drawn under a cave's entrance mat (the three blocked
   -- tiles south of the warp mat, collision code 114: 0x258-0x25A under
   -- 0x23C, 0x338-0x33A under 0x33B...) is the way out, lying on the floor:
   -- as rock it stood in front of the player on the mat
   if c.collision==7 and (k=='caveWall' or k=='cliff' or k=='flat' or k=='rock') and not c.prop then
    for dx=-1,1 do
     local m=cells[(c.cx+dx)..':'..(c.cy-1)]
     if m and m.collision==114 then c.shape={kind='flat',reviewedSurface=true};c.noFurniture=true;k=nil;break end
    end
   end
   -- furniture whose tile the tables also list as rock (Magma Hideout's
   -- containers) stands on plain floor: no rock is built in its cells
   if c.prop and (k=='cliff' or k=='caveWall') and c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height then
    c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};k=nil
   end
   -- ...and a walkable cell is floor, whatever the tile tables call its tile
   -- (Magma Hideout's floor tile 0x308 is listed as cliff: as rock it left
   -- the floor of its raised rooms unbuilt)
   if (k=='cliff' or k=='caveWall') and c.collision~=nil and c.collision~=7 and c.collision~=255 and not (c.prop or c.stairs)
     and c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height then
    c.shape={kind='flat',reviewedSurface=true}
   end
  end
  V.require('Gen3Cave').settle(def,cells)
 end
 -- (a town's wall tiles are masonry (Gen3Masonry): hidden from Mass while it floods, then restored)
 -- (the Battle Frontier's south flower beds are one planter each, Gen3Planter: hidden from Mass the same way)
 mark('settle')
 local bedPlanter=V.require('Gen3Planter').prepare(cells,def)
 local masonry=V.require('Gen3Masonry').prepare(cells,def)
 M.massCount=#Mass.prepare(cells,Pairs.outdoor(def))
 V.require('Gen3Masonry').restore(masonry)
 V.require('Gen3Planter').restore(bedPlanter)
 -- (a stepped deck's blocked cells are deck, never a rock mass)
 if Decks.MAPS[def.id or ''] then for _,c in pairs(cells)do c.mass=nil end end
 cache.floorRegions=regions
 -- A floor the ledge relief lifts (TerrainLevels: Route 115's meadow round its ledges) rises a few px a
 -- cell; as flat blocks it stood as rows of tiny steps whose risers lined the grass. Its cells get sloped
 -- tops instead: a corner where four open floor cells of one floor group meet, one of them lifted, stands
 -- at their mean height, and every other corner stays at its cell's own base (edges towards anything else
 -- keep their faces). c.slope={nw,ne,se,sw} are offsets from c.base; the field cell carries them too, so
 -- actors and the eye stand on the slope (TerrainLevels.at).
 do
  local SLOPE_KIND={flat=true,grass=true,flowers=true,sand=true}
  local function open(c)
   local f=c and c.floor
   return f and (f.group or f.connector) and c.base and SLOPE_KIND[c.shape and c.shape.kind or ''] and (c.collision or 0)==0
    and not (f.step or c.stairs or c.mass or c.bldModel or c.civic or c.column or c.object or c.objectTop or c.boundary) and c
  end
  for _,c in pairs(cells)do c.slope=nil;if c.floor then c.floor.slope=nil end end
  local corner={}
  local function at(i,j)
   local k=i..':'..j;local h=corner[k]
   if h==nil then
    h=false
    local ka,kb,kd,ke=cells[(i-1)..':'..(j-1)],cells[i..':'..(j-1)],cells[(i-1)..':'..j],cells[i..':'..j]
    local a,b,d,e=open(ka),open(kb),open(kd),open(ke)
    if not (a and b and d and e) then
     -- A lifted floor that runs along a jump ledge (Route 111's meadow rows 12 and 14): the ledge cells are not
     -- open, so every corner on the ledge's side kept its cell's own base and the floor stood as rows of 3 px
     -- steps whose risers show the grass art (ghost card H1). Where the cells that are not open are all ledge
     -- cells and at least two open cells of one floor share the corner, they meet at their mean height.
     local n,sum,g,one,relief,ledgeOnly=0,0,nil,true,false,true
     for _,q in ipairs({{a,ka},{b,kb},{d,kd},{e,ke}})do
      if q[1] then
       n=n+1;sum=sum+q[1].base
       local f=q[1].floor
       if f.relief then relief=true end
       if not f.connector then if g==nil then g=f.group elseif f.group~=g then one=false end end
      elseif not (q[2] and q[2].shape and q[2].shape.kind=='ledge') then ledgeOnly=false end
     end
     if n>=2 and n<4 and one and relief and ledgeOnly and ((a and b) or (d and e) or (a and d) or (b and e)) then h=sum/n end
    end
    if a and b and d and e then
     -- (one floor: a connector, TerrainLevels' plain-ground "stair" the relief carried, joins any)
     local g,one=nil,true
     for _,q in ipairs({a,b,d,e})do local f=q.floor
      if not f.connector then if g==nil then g=f.group elseif f.group~=g then one=false end end
     end
     if one and (a.floor.relief or b.floor.relief or d.floor.relief or e.floor.relief) then
      h=(a.base+b.base+d.base+e.base)/4
     end
    end
    corner[k]=h
   end
   return h
  end
  for _,c in pairs(cells)do if open(c) then
   local i,j=c.cx,c.cy
   local nw,ne,se,sw=at(i,j),at(i+1,j),at(i+1,j+1),at(i,j+1)
   if nw or ne or se or sw then
    local s={nw and nw-c.base or 0,ne and ne-c.base or 0,se and se-c.base or 0,sw and sw-c.base or 0}
    if s[1]~=0 or s[2]~=0 or s[3]~=0 or s[4]~=0 then c.slope=s;c.floor.slope=s end
   end
  end end
 end
 -- A ledge's corner and end tiles carry no jump direction, so they stood as a full mound beside the run's
 -- flush lip (a tall stub at every end): they take the drop of a ledge cell of the same floor beside them.
 for _=1,2 do
  for _,c in pairs(cells)do
   if c.shape and c.shape.kind=='ledge' and c.floor and not c.floor.ledgeLow and c.base then
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and n.shape.kind=='ledge' and n.floor and n.floor.ledgeLow and math.abs((n.base or 0)-c.base)<=8 then
      c.base=n.base;c.floor.height=n.base;c.floor.ledgeLow=n.floor.ledgeLow;break
     end
    end
   end
  end
 end
 V.require('Gen3Waterfall').prepare(cells,def)
 mark('mass')
 local chimneys=Roof.prepare(cells)
 M.chimneyCount=#chimneys
 M.propCount=#props
 for _,g in ipairs(civics)do g.stageHidden=BattleClear.hits(cam,g.cx*16,g.cy*16,(g.cx+g.width)*16,(g.cy+g.depth)*16)end
 for _,p in ipairs(props)do p.stageHidden=BattleClear.hits(cam,p.cx*16,p.cy*16,p.cx*16+p.w,p.cy*16+p.d)end
 for _,c in pairs(cells)do
  Budget.tick()
  local col=c.column;local group=col and col.group
  c.stageHidden=BattleClear.hits(cam,c.cx*16,c.cy*16,c.cx*16+(c.shape.kind=='tree' and 32 or 16),c.cy*16+32)
  if col then col.stageHidden=group and BattleClear.hits(cam,group.left,group.back,group.right,group.front)or c.stageHidden end
 end
 M.cliffCount=0
 local batches={};local wood,wi,leaf,li={},{},{},{}
 -- the night quads of the street lamps (Gen3Lamp): each lamp's lantern glass and pool of light
 local lampNight={lamps={},quad=quad}
 local kinds=stream.stats.kinds   -- debug: stats.kinds={} collects build seconds per shape kind
 for _,c in pairs(cells)do
  Budget.tick()
  local kindT0=kinds and os.clock()
  local ts,x,z,shape=c.ts,c.cx*16,c.cy*16,c.shape
  local b=batches[c.pair]
  if not b then b={pair=c.nativePair,secondary=c.secondary,v={},i={},rv={},ri={},pv={},pi={},wv={},wi={},roofMids={},skipOver={},underSkip={},deckV={},cv={},ci={}};batches[c.pair]=b end
  local uv=uvFor(ts,c.mid)
  local column=c.column
  -- a rock mass emits the part of itself that stands in THIS cell (absolute heights: before `starts`, so
  -- the cell's terrace lift never touches it)
  PROBE.cell=c
  if c.mass and not c.stageHidden and Mass.usable(c.mass,cells) then
   PROBE.tag='mass'
   if M.probeBox and c.cx==26 and c.cy==27 then print('[EM massinfo]',tostring(c.mass.relief),tostring(c.mass.hill),tostring(c.mass.rock~=nil),tostring(c.mass.terraceEnd)) end
   Mass.append(c.mass,cells,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor,c)
   PROBE.tag=nil
  end
  local starts={#b.v,#b.rv,#b.pv,#b.wv,#wood,#leaf}
  PROBE.cell=c
  local flight=flightAxis(c,cells)
  if c.bedPlanter then
   -- a flower bed of the Battle Frontier's south beds: one raised planter, its flowers and walls (Gen3Planter)
   if not c.stageHidden then V.require('Gen3Planter').appendBed(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,function(p,t,sh)quad(b.cv,b.ci,p,t,sh)end,uvFor,cells)end
  elseif shape.kind=='deckFace' or shape.kind=='deckBack' or shape.kind=='deckMixed' or shape.kind=='deckFloor' or shape.kind=='deckEdge' or shape.kind=='deckHead' or shape.kind=='deckRamp' then
   -- an upright face under a deck's front edge: wall, door or stairs (Gen3Decks)
   if not c.stageHidden then Decks.append(def,c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,cells) end
  elseif c.stairs or shape.kind=='steps' or shape.kind=='ladder' then
   if shape.kind=='ladder' and not shape.down then plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)end
   if shape.kind=='steps' and shape.down then
    -- a flight down from the floor north of the cell to the floor south of it (SHAPE_BY_MAP down=true): four
    -- treads, each closed down to the south floor. Heights are absolute; the lift below moves them by the base
    local hi,lo=cells[c.cx..':'..(c.cy-1)],cells[c.cx..':'..(c.cy+1)]
    local top,bot=(hi and hi.base) or 16,(lo and lo.base) or 0
    local b0=c.base or 0
    local function px(a,q)return {uv[1][1]+(uv[3][1]-uv[1][1])*a/16,uv[1][2]+(uv[3][2]-uv[1][2])*q/16}end
    local function sub(y0,y1)return {px(0,y0),px(16,y0),px(16,y1),px(0,y1)}end
    for n=0,3 do
     local h=top-(top-bot)*n/4-b0
     local low=bot-b0
     local zz=n*4
     local a,d=z+zz,z+zz+4
     local p=px(8,zz+2);local pu={p,p,p,p}
     quad(b.v,b.i,{{x,h,a},{x+16,h,a},{x+16,h,d},{x,h,d}},sub(zz,zz+4),1)
     quad(b.v,b.i,{{x,low,d},{x+16,low,d},{x+16,h,d},{x,h,d}},pu,.85)
     quad(b.v,b.i,{{x,low,a},{x,low,d},{x,h,d},{x,h,a}},pu,.72)
     quad(b.v,b.i,{{x+16,low,d},{x+16,low,a},{x+16,h,a},{x+16,h,d}},pu,.8)
    end
    -- the bank each side of the flight is drawn narrower than its cell: a core of its own colour stands
    -- behind it (just inside its faces), so no sky or sea shows between the bank and the steps
    for _,dx in ipairs({-1,1})do
     local n=cells[(c.cx+dx)..':'..c.cy]
     local nuv=n and n.collision==7 and not (n.shape and n.shape.kind=='steps') and uvFor(n.ts,n.mid)
     if nuv then
      local q={nuv[1][1]+(nuv[3][1]-nuv[1][1])*.5,nuv[1][2]+(nuv[3][2]-nuv[1][2])*.8};local t={q,q,q,q}
      local x0,x1,y0,y1,z0,z1=x+dx*16+.5,x+dx*16+15.5,bot-b0,top-b0-.5,z+.5,z+15.5
      quad(b.v,b.i,{{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},t,.85)
      quad(b.v,b.i,{{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},t,.95)
      local xe=dx<0 and x1 or x0
      quad(b.v,b.i,{{xe,y1,z0},{xe,y1,z1},{xe,y0,z1},{xe,y0,z0}},t,.75)
     end
    end
   else
   Stairs.append(c,function(p,t,shade)quad(b.v,b.i,p,t,shade)end,uvFor)
   end
  elseif shape.ashPine then
   -- an ash-covered pine (Gen3AshPine), on the ground of the slope
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden and V.require('Gen3AshPine').is(c) then V.require('Gen3AshPine').append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.lamp then
   -- a street lamp's foot (Gen3Lamp): the lawn under it and the lamp stood up from its drawing, rings
   -- as wide as the drawn rows; the glass and the pool of light go to the night mesh
   local Lamp=V.require('Gen3Lamp')
   local on=Lamp.is(c,cells)
   plane(b.v,b.i,x,z,(on and uvFor(ts,shape.ground)) or uv)
   if on and not c.stageHidden then Lamp.append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,cells,lampNight) end
  elseif V.require('Gen3WallStairs').kind(c) then
   -- a house staircase drawn as a doorway in the back wall (Gen3WallStairs)
   local w=cells[(c.cx-1)..':'..c.cy]
   V.require('Gen3WallStairs').append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,w and w.mid)
  elseif shape.kind=='stand' then
   -- a grandstand: board wall at the front, stepped rows of seats behind
   local st=shape.stand
   local function sub(y0,y1)
    local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
    return {{L,T+(B-T)*y0/16},{R,T+(B-T)*y0/16},{R,T+(B-T)*y1/16},{L,T+(B-T)*y1/16}}
   end
   local F=(st.board+1)*16
   if c.cy==st.board then
    quad(b.v,b.i,{{x,st.h0,F},{x+16,st.h0,F},{x+16,0,F},{x,0,F}},uv,.9)
   elseif c.cy<st.board then
    local k=st.board-c.cy
    local tread=16-st.riser
    local hb=st.h0+(k-1)*st.riser
    local zr=F-(k-1)*tread
    quad(b.v,b.i,{{x,hb+st.riser,zr},{x+16,hb+st.riser,zr},{x+16,hb,zr},{x,hb,zr}},sub(tread,16),.84)
    quad(b.v,b.i,{{x,hb+st.riser,zr-tread},{x+16,hb+st.riser,zr-tread},{x+16,hb+st.riser,zr},{x,hb+st.riser,zr}},sub(0,tread),1)
    -- the stand's back, down to the floor, behind its top row
    local up=cells[c.cx..':'..(c.cy-1)]
    if not (up and up.shape and up.shape.kind=='stand') then
     local zb=zr-tread;local top=hb+st.riser
     local sw=swatch(ts,uv[1][1]+(uv[2][1]-uv[1][1])*.5,uv[1][2]+(uv[3][2]-uv[1][2])*.1)
     quad(b.v,b.i,{{x+16,top,zb},{x,top,zb},{x,0,zb},{x+16,0,zb}},sw,.6)
    end
   end
  elseif shape.kind=='rail' then
   -- (heights relative to the cell's own level: the scene lifts them by it)
   local B=c.base or 0
   local function sub(t,l,tp,r,bt)
    local function p(px,py)return {t[1][1]+(t[2][1]-t[1][1])*px/16,t[1][2]+(t[3][2]-t[1][2])*py/16}end
    return {p(l,tp),p(r,tp),p(r,bt),p(l,bt)}
   end
   -- the ground under the rail: grass, at the foot of the ledges
   local low
   for _,d in ipairs({{0,1},{0,-1},{1,0},{-1,0},{0,2},{0,-2}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and n.mid==0x001 and (n.collision or 0)==0 then low=math.min(low or 1e9,n.base or 0) end
   end
   low=(low or 0)-B
   quad(b.v,b.i,{{x,low,z},{x+16,low,z},{x+16,low,z+16},{x,low,z+16}},uvFor(ts,0x001) or uv,1)
   -- the ledges beside it stand over this ground: close their faces down to
   -- it, in their own rock, course by course
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and not (n.shape and n.shape.kind=='rail') then
     local nb=(n.base or 0)-B
     local t=uvFor(n.ts,n.mid)
     if t and nb>low+.5 then
      local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
      local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
      local y=low
      while y<nb do
       local h=math.min(16,nb-y)
       local v0=t[3][2]-(t[3][2]-t[1][2])*h/16
       quad(b.v,b.i,{{ax,y,az},{bx,y,bz},{bx,y+h,bz},{ax,y+h,az}},{{t[1][1],t[3][2]},{t[2][1],t[3][2]},{t[2][1],v0},{t[1][1],v0}},.78)
       y=y+h
      end
     end
    end
   end
   if shape.top and not c.stageHidden then
    local below=cells[c.cx..':'..(c.cy+1)]
    local bt=below and RAIL_EDGE[below.mid] and uvFor(below.ts,below.mid)
    local edge=sub(uv,1,11,15,12)
    quad(b.v,b.i,{{x,0,z+11},{x+16,0,z+11},{x+16,0,z+16},{x,0,z+16}},sub(uv,0,11,16,16),1)
    quad(b.v,b.i,{{x,0,z+16},{x+16,0,z+16},{x+16,-3,z+16},{x,-3,z+16}},bt and sub(bt,0,0,16,3) or edge,.92)
    quad(b.v,b.i,{{x+16,0,z+11},{x,0,z+11},{x,-3,z+11},{x+16,-3,z+11}},edge,.7)
    quad(b.v,b.i,{{x,-3,z+16},{x+16,-3,z+16},{x+16,-3,z+11},{x,-3,z+11}},edge,.55)
    for _,dx in ipairs({-1,1})do
     local n=cells[(c.cx+dx)..':'..c.cy]
     if not (n and ((n.shape and n.shape.kind=='rail' and n.shape.top) or RAIL_ROCK[n.mid])) then
      local sx=dx<0 and x or x+16
      if dx<0 then quad(b.v,b.i,{{sx,0,z+11},{sx,0,z+16},{sx,-3,z+16},{sx,-3,z+11}},edge,.76)
      else quad(b.v,b.i,{{sx,0,z+16},{sx,0,z+11},{sx,-3,z+11},{sx,-3,z+16}},edge,.82) end
     end
    end
    -- the two posts drawn under the plank, down to the grass
    if below and RAIL_POSTS[below.mid] and bt then
     for _,col in ipairs({3,11})do
      local t=sub(bt,col,5,col+1,6)
      local a,e,za,zb=x+col,x+col+2,z+13,z+15
      quad(b.v,b.i,{{a,-3,zb},{e,-3,zb},{e,low,zb},{a,low,zb}},t,.9)
      quad(b.v,b.i,{{e,-3,za},{a,-3,za},{a,low,za},{e,low,za}},t,.62)
      quad(b.v,b.i,{{a,-3,za},{a,-3,zb},{a,low,zb},{a,low,za}},t,.74)
      quad(b.v,b.i,{{e,-3,zb},{e,-3,za},{e,low,za},{e,low,zb}},t,.8)
     end
    end
   end
  elseif shape.kind=='obwall' then
   -- a wall drawn as a block: top and front from its drawing (Gen3ObliqueWall)
   do
    local g=shape.ground
    -- (ob.voidGround: behind a wall with the void or more wall to its north
    -- lies the black, not the room's floor)
    local vg=shape.ob and shape.ob.voidGround
    if vg then local n=cells[c.cx..':'..(c.cy-1)]
     if not n or ((n.collision or 0)~=0 and n.shape.kind=='obwall') then g=vg end end
    -- (overArt: the object is the tile's over-player art; its own lower
    -- layer is the ground under it, and the object is painted by the over pass only)
    if shape.overArt then b.skipOver[#b.skipOver+1]=#b.v;plane(b.v,b.i,x,z,uv)
    else plane(b.v,b.i,x,z,uvFor(ts,g) or uv) end
   end
   if not c.stageHidden then
    local over=shape.overArt
    V.require('Gen3ObliqueWall').append(c,cells,function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);if over then b.underSkip[#b.underSkip+1]=k end end,uvFor)
   end
  elseif shape.kind=='boat' then
   -- a moored sailboat (Gen3Boat): the sea under it, the boat from its drawing
   local Boat=V.require('Gen3Boat')
   -- (the boat floats on the sea whatever height the quay beside it gave its cells: rated with the
   -- quay, the sea under the moored pair stood a course up and drowned their hulls)
   -- the sea's own level: that of the open water touching the boat's cells
   if c.boatSea==nil then
    local group,stack,sea={},{c},nil;local seen={[c]=true}
    while #stack>0 do
     local a=table.remove(stack);group[#group+1]=a
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and n.shape and not seen[n] then
       if n.shape.kind=='boat' then seen[n]=true;stack[#stack+1]=n
       elseif n.shape.kind=='water' then sea=math.min(sea or (n.base or 0),n.base or 0) end
      end
     end
    end
    -- (a lone boat tile cut by the map's edge is left as it was)
    for _,a in ipairs(group)do a.boatSea=sea or 0;if #group>=4 then a.base=a.boatSea;a.floorHigh=nil end end
   end
   local cb=0
   plane(b.wv,b.wi,x,z,uvFor(ts,Boat.SEA) or uv,.05-cb)
   if not c.stageHidden then Boat.append(c,cells,function(p,t,sh)for _,q in ipairs(p)do q[2]=q[2]-cb end;quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.kind=='lathe' then
   -- a round thing drawn from the front, turned (Gen3Lathe); its drawing
   -- (both layers) stands in the model, not on the ground
   local q=#b.v
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   b.skipOver[#b.skipOver+1]=q
   local L=V.require('Gen3Lathe')
   if not c.stageHidden and L.owns(c,shape.lathe) then
    (shape.lathe.tower and L.tower or L.append)(c,cells,shape.lathe,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor)
   end
  elseif shape.kind=='extrude' then
   -- a low structure drawn from above, stood up pixel by pixel (Gen3Fence.extrude)
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   -- (the Battle Frontier's flower planters are one kerbed bed each: Gen3Planter)
   local Planter=V.require('Gen3Planter')
   if not c.stageHidden and Planter.owns(c) then Planter.append(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,function(p,t,sh)quad(b.cv,b.ci,p,t,sh)end,uvFor,cells)
   elseif not c.stageHidden then
    -- (sidePx={mid,x,y}: every upright face takes that pixel -- a hull's planking, not its dark outline)
    local sp=shape.sidePx and uvFor(ts,shape.sidePx[1])
    local st=sp and (function()local u,v=sp[1][1]+(sp[2][1]-sp[1][1])*(shape.sidePx[2]+.5)/16,sp[1][2]+(sp[3][2]-sp[1][2])*(shape.sidePx[3]+.5)/16;return {{u,v},{u,v},{u,v},{u,v}} end)()
    V.require('Gen3Fence').extrude(c,cells,function(p,t,sh)
     if st and not (p[1][2]==p[2][2] and p[2][2]==p[3][2]) then t=st end
     quad(b.v,b.i,p,t,sh)end,uvFor,shape.h or 6,shape.light,shape.cool)
   end
  elseif shape.kind=='posts' then
   -- a fence of logs driven into the ground: each cut end in the drawing is a standing log (Gen3Fence.posts)
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   local overPosts=V.require('Gen3Fence').overInk(c)
   if not c.stageHidden and V.require('Gen3Fence').posts(c,function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);if overPosts then b.underSkip[#b.underSkip+1]=k end end,uvFor)==0 then
    V.require('Gen3Fence').extrude(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,shape.h or 6,shape.light)
   end
  elseif shape.kind=='pier' then
   -- A plank jetty drawn from above (SHAPE_BY_MAP): every plank pixel is a board shape.h up and
   -- PIER_THICK thick, the gaps between the planks are open to the water under them, and a post
   -- stands under each cell of the jetty's seaward row. land=true: the tile is also the bank it meets.
   local H=(shape.h or 16)-(c.base or 0)
   if shape.land then plane(b.v,b.i,x,z,uv,H-.3)
   else plane(b.wv,b.wi,x,z,uvFor(ts,shape.water or 0x170) or uv,.05-(c.base or 0)) end
   local slot=ts.midToSlot[c.mid]
   if slot and ts.imageData and not c.stageHidden then
    local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
    -- one deck: every pixel that is not the sea drawn round the jetty -- the planks AND the dark joints
    -- between them, flush, as drawn (planks standing apart over the water read as a row of yellow
    -- slabs, user: "the chunky pier"); open sides are closed by the plate's edge
    local wood,joint={}, {}
    for py=0,15 do for px=0,15 do
     local r,g,bl=ts.imageData:getPixel(ox+px,oy+py)
     wood[py*16+px]=not (bl>r+.08 and bl>g)
    end end
    -- (the gaps between the planks are drawn as sea; a gap at most 2 px wide with planks either side
    -- is a joint in the deck, a pixel down and dark, not a 16 px drop to the water)
    for py=0,15 do for px=0,15 do
     if not wood[py*16+px] then
      local l,rr
      for k=1,2 do if px-k>=0 and wood[py*16+px-k] then l=px-k;break end end
      for k=1,2 do if px+k<=15 and wood[py*16+px+k] then rr=px+k;break end end
      if l and rr and rr-l<=3 then joint[py*16+px]=l end
     end
    end end
    local function deckCell(dx,dz)
     local n=cells[(c.cx+dx)..':'..(c.cy+dz)]
     return n and n.shape and (n.shape.kind=='pier' or (n.shape.land==true)) or (n and (n.collision or 0)==0 and n.shape and n.shape.kind=='flat' and math.abs((n.base or 0)-(c.base or 0)-H)<2)
    end
    local function on(px,py)
     if px<0 then return deckCell(-1,0) and wood[py*16+15] end
     if px>15 then return deckCell(1,0) and wood[py*16] end
     if py<0 then return deckCell(0,-1) end
     if py>15 then return deckCell(0,1) end
     return wood[py*16+px] or joint[py*16+px]~=nil
    end
    local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
    local function span(a,e,r0,r1)return {{L+(R-L)*a/16,T+(B-T)*r0/16},{L+(R-L)*e/16,T+(B-T)*r0/16},{L+(R-L)*e/16,T+(B-T)*r1/16},{L+(R-L)*a/16,T+(B-T)*r1/16}} end
    local function tex(px,py)local u,v=L+(R-L)*(px+.5)/16,T+(B-T)*(py+.5)/16;return {{u,v},{u,v},{u,v},{u,v}} end
    local y1,y0=H,H-PIER_THICK
    for py=0,15 do for px=0,15 do
     local l=joint[py*16+px]
     if l then
      quad(b.v,b.i,{{x+px,y1-1,z+py},{x+px+1,y1-1,z+py},{x+px+1,y1-1,z+py+1},{x+px,y1-1,z+py+1}},tex(l,py),.42)
      quad(b.v,b.i,{{x+px,y0,z+py+1},{x+px+1,y0,z+py+1},{x+px+1,y0,z+py},{x+px,y0,z+py}},tex(l,py),.5)
     end
    end end
    for py=0,15 do
     local px=0
     while px<16 do
      if wood[py*16+px] then
       local e=px;while e<15 and wood[py*16+e+1] do e=e+1 end
       quad(b.v,b.i,{{x+px,y1,z+py},{x+e+1,y1,z+py},{x+e+1,y1,z+py+1},{x+px,y1,z+py+1}},span(px,e+1,py,py+1),1)
       quad(b.v,b.i,{{x+px,y0,z+py+1},{x+e+1,y0,z+py+1},{x+e+1,y0,z+py},{x+px,y0,z+py}},tex(px,py),.5)
       local jl,jr=px>0 and joint[py*16+px-1],e<15 and joint[py*16+e+1]
       if not on(px-1,py) then quad(b.v,b.i,{{x+px,y1,z+py},{x+px,y1,z+py+1},{x+px,jl and y1-1 or y0,z+py+1},{x+px,jl and y1-1 or y0,z+py}},tex(px,py),.72) end
       if not on(e+1,py) then quad(b.v,b.i,{{x+e+1,y1,z+py+1},{x+e+1,y1,z+py},{x+e+1,jr and y1-1 or y0,z+py},{x+e+1,jr and y1-1 or y0,z+py+1}},tex(e,py),.8) end
       for k=px,e do
        if not on(k,py+1) then quad(b.v,b.i,{{x+k,y1,z+py+1},{x+k+1,y1,z+py+1},{x+k+1,y0,z+py+1},{x+k,y0,z+py+1}},tex(k,py),.85) end
        if not on(k,py-1) then quad(b.v,b.i,{{x+k+1,y1,z+py},{x+k,y1,z+py},{x+k,y0,z+py},{x+k+1,y0,z+py}},tex(k,py),.62) end
       end
       px=e+1
      else px=px+1 end
     end
    end
    if shape.post then
     local puv=uvFor(ts,shape.post[1])
     if puv then
      local u,v=puv[1][1]+(puv[3][1]-puv[1][1])*(shape.post[2]+.5)/16,puv[1][2]+(puv[3][2]-puv[1][2])*(shape.post[3]+.5)/16
      local t={{u,v},{u,v},{u,v},{u,v}}
      local low=-(c.base or 0)
      for _,pxl in ipairs(shape.posts or {9})do
       local x0,x1,z0,z1=x+pxl,x+pxl+3,z+10,z+13
       quad(b.v,b.i,{{x0,y0,z1},{x1,y0,z1},{x1,low,z1},{x0,low,z1}},t,.9)
       quad(b.v,b.i,{{x1,y0,z0},{x0,y0,z0},{x0,low,z0},{x1,low,z0}},t,.6)
       quad(b.v,b.i,{{x0,y0,z0},{x0,y0,z1},{x0,low,z1},{x0,low,z0}},t,.7)
       quad(b.v,b.i,{{x1,y0,z1},{x1,y0,z0},{x1,low,z0},{x1,low,z1}},t,.8)
      end
     end
    end
   end
  elseif shape.kind=='fence' then
   -- a little white fence drawn on the ground, stood up (Gen3Fence)
   if shape.waterGround then plane(b.wv,b.wi,x,z,uvFor(ts,shape.ground) or uv,.05)
   else plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv) end
   if not c.stageHidden then
    -- (a fence drawn in the over-player layer is painted by the over pass only)
    local Fence=V.require('Gen3Fence');local over=Fence.overInk(c)
    Fence.append(c,function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);if over then b.underSkip[#b.underSkip+1]=k end end,uvFor)
   end
  elseif shape.kind=='hang' then
   -- an edge rail standing at a drop, or a facade hanging below it (SHAPE_BY_MAP)
   local ez=shape.edge*16
   if shape.rail then
    plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
    if not c.stageHidden then
     quad(b.v,b.i,{{x,16,ez},{x+16,16,ez},{x+16,0,ez},{x,0,ez}},uv,.9)
     quad(b.v,b.i,{{x+16,16,ez-.6},{x,16,ez-.6},{x,0,ez-.6},{x+16,0,ez-.6}},uv,.7)
    end
   elseif not c.stageHidden then
    local d=c.cy-shape.edge
    quad(b.v,b.i,{{x,-d*16,ez},{x+16,-d*16,ez},{x+16,-(d+1)*16,ez},{x,-(d+1)*16,ez}},uv,.86)
    -- the store's sides and back hang from the deck's other edges, in the
    -- front's edge and wall art, one 16 px course per facade row
    local sd=M.sceneDef
    if c.cx==0 and sd and sd.midLayout then
     local W=sd.midLayout.width*16
     local left,right,mid=uvFor(ts,0x2EC),uvFor(ts,0x2EE),uvFor(ts,0x2ED)
     local y0,y1=-(d+1)*16,-d*16
     for zz=0,ez-16,16 do
      if left then quad(b.v,b.i,{{0,y1,zz},{0,y1,zz+16},{0,y0,zz+16},{0,y0,zz}},left,.72) end
      if right then quad(b.v,b.i,{{W,y1,zz+16},{W,y1,zz},{W,y0,zz},{W,y0,zz+16}},right,.76) end
     end
     if mid then for xx=0,W-16,16 do quad(b.v,b.i,{{xx+16,y1,0},{xx,y1,0},{xx,y0,0},{xx+16,y0,0}},mid,.62) end end
    end
   end
  elseif shape.kind=='partition' then
   -- a north-south partition wall drawn from above (Gen3Partition)
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden then V.require('Gen3Partition').append(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  elseif shape.leagueGate then
   -- Ever Grande's gates (Gen3LeagueGate): the cell's ground, its over-layer
   -- art (the gate drawn flat) skipped; the west foot builds the gate
   local Gate=V.require('Gen3LeagueGate')
   local q=#b.v
   plane(b.v,b.i,x,z,uvFor(ts,Gate.ground(c)) or uv)
   if Gate.overArt(c.mid) then b.skipOver[#b.skipOver+1]=q end
   if not c.stageHidden and Gate.owns(c,cells) then
    Gate.append(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,
     function(p,t,sh)local k=#b.v;quad(b.v,b.i,p,t,sh);b.underSkip[#b.underSkip+1]=k end,uvFor)
   end
  elseif shape.cyclingRoad then
   -- Route 110's Seaside Cycling Road: slab, fascia faces, legs and the sea or
   -- grass under it (Gen3CyclingRoad; points relative to this cell's base)
   local deckFirst,groundFirst=#b.v+1,nil
   V.require('Gen3CyclingRoad').append(c,cells,ts,{
    solid=function(p,t,shade)quad(b.v,b.i,p,t,shade)end,
    ground=function(p,t,shade)groundFirst=groundFirst or #b.v+1;quad(b.v,b.i,p,t,shade)end,
    water=function(p,t,shade)quad(b.wv,b.wi,p,t,shade)end},uvFor)
   -- (the deck's vertices without the ground under it, so the slab over a player walking under it can be cut
   -- away: deckCut)
   if shape.cyclingRoad=='deck' then b.deckV[#b.deckV+1]={c.cx,c.cy,deckFirst,(groundFirst or #b.v+1)-1} end
  elseif c.civic or c.bldModel then
   plane(b.v,b.i,x,z,(c.bldModel and c.bldModel.groundMid and uvFor(ts,c.bldModel.groundMid)) or uvFor(ts,shape.ground) or uvFor(ts,c.civic and c.civic.variant=='saffron' and 0x2E5 or 1) or uv)
  elseif shape.kind=='water' then
   plane(b.wv,b.wi,x,z,uv,.05)
  elseif shape.kind=='interiorFloor' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
  elseif shape.kind=='caveWall' and c.mass and Mass.usable(c.mass,cells) then
   -- the rim of a cave wall stands up from its own drawing (Gen3Mass)
   local g=Mass.ground(c.mass,cells,c) or shape.ground
   plane(b.v,b.i,x,z,uvFor(ts,g) or uvFor(ts,shape.ground) or uv,c.base or 0)
   if c.mass.owner==c and not c.stageHidden then Mass.append(c.mass,cells,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor)end
  elseif shape.kind=='caveWall' and c.caveFlat then
   -- deep inside a thick wall, behind the rim: its own drawing laid flat at wall height
   local top=(c.base or 0)+Mass.FACE
   plane(b.v,b.i,x,z,uv,top)
  elseif shape.kind=='caveWall' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden then V.require('Gen3Cave').wall(cells,c,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor)end
  elseif shape.kind=='rock' then
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if not c.stageHidden then V.require('Gen3Cave').rock(c,function(v,t,shade,anchor)quad(anchor and b.pv or b.v,anchor and b.pi or b.i,v,t,shade,anchor)end,uvFor)end
  elseif shape.kind=='cliff' and c.masonry then
   -- a town's wall: its own top and faces, level with the terrace (Gen3Masonry)
   V.require('Gen3Masonry').append(c,cells,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor)
  elseif shape.kind=='cliff' then
   M.cliffCount=M.cliffCount+1
   -- a bank's drape covers its whole cell down to the foot; a ground plane
   -- under it would only fight it there
   -- (a mass rebuilt from its drawing leaves the ground showing, so it needs the plane)
   if c.mass and Mass.usable(c.mass,cells) then
    local g,wet=Mass.ground(c.mass,cells,c)
    local seaUnder,level=false,false
    g=g or shape.ground
    -- a rock cell with sea beside it and no open ground stands in the sea
    -- (the mass's voted ground can be a beach on its other side: a yellow
    -- sliver under Lilycove's ledge tip)
    if not wet then
     local sea,land
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and n.shape then
       if n.shape.kind=='water' and (n.base or 0)==0 then sea=n
       elseif (n.collision or 0)==0 and (n.base or 0)<8 then land=true end
      end
     end
     if sea and not land then g,wet,seaUnder=sea.mid,true,true end
    end
    -- the ground showing round this cell's rock is the ground beside THIS
    -- cell (the mass's voted ground can be a sand path on its far side: a
    -- yellow strip along Route 120's lake bank and Sootopolis's east shore)
    if not wet then
     local votes,best,bn={},nil,0
     local same=false
     -- (only the ground level with this cell: a cliff cell on the upper terrace beside a beach took the
     -- sand's vote and lay a sand floor at grass height in its carved corners -- Route 104's shore)
     local anyLevel=false
     for dy=-1,1 do for dx=-1,1 do
      local n=(dx~=0 or dy~=0) and cells[(c.cx+dx)..':'..(c.cy+dy)]
      if n and n.shape and (n.shape.kind=='flat' or n.shape.kind=='grass') and (n.collision or 0)==0 and n.ts==ts and not n.boundary
       and math.abs((n.base or 0)-(c.base or 0))<8 then anyLevel=true end
     end end
     for dy=-1,1 do for dx=-1,1 do
      local n=(dx~=0 or dy~=0) and cells[(c.cx+dx)..':'..(c.cy+dy)]
      if n and n.shape and (n.shape.kind=='flat' or n.shape.kind=='grass') and (n.collision or 0)==0 and n.ts==ts and not n.boundary
       and (not anyLevel or math.abs((n.base or 0)-(c.base or 0))<8) then
       if n.mid==g then same=true end
       votes[n.mid]=(votes[n.mid] or 0)+1
       if votes[n.mid]>bn then best,bn=n.mid,votes[n.mid] end
       if math.abs((n.base or 0)-(c.base or 0))<8 then level=true end
      end
     end end
     if best and not same then g=best end
    end
    local gu=uvFor(ts,g) or uvFor(ts,1) or uv
    local cb=c.base or 0
    -- a rock cell standing above all the open ground beside it has no ground
    -- of its own to show: its floor and the steps down from it are rock
    -- (Route 116: a cell of the upper terrace over the grass stood as a green cube)
    if not wet and not level and cb>=8 then gu=uv end
    -- (seaUnder: at sea level whatever the cell's height)
    -- (a rock whose top is level with this floor -- a one-course bank under its terrace's lawn -- lies on
    -- it: the floor goes a hair under it, or the two flickered through each other as stripes)
    local rh=c.mass.rock and c.mass.rock.H and c.mass.rock.H[c]
    local under=(rh and math.abs(rh-cb)<.5) and .3 or 0
    if wet then plane(b.wv,b.wi,x,z,gu,seaUnder and .05-cb or .05) else plane(b.v,b.i,x,z,gu,cb-under) end
    -- the dome used to close the terrace edge beside a rock cell; a mass leaves its
    -- cell flat, so the step to a neighbouring floor gets a wall of its own
    -- (and down to a rock cell beside it whose own ground lies lower: rock
    -- cells take their floor from different terraces, and the open step
    -- between two of them showed the sky all over Sootopolis's upper town)
    if not seaUnder and not wet then
     for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and n.shape and (n.shape.kind=='cliff' or n.shape.kind=='caveWall') and (n.base or 0)<cb-.5 then
       local nb=n.base or 0
       local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
       local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
       quad(b.v,b.i,{{ax,nb,az},{bx,nb,bz},{bx,cb,bz},{ax,cb,az}},gu,.78)
      end
     end
    end
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.mass~=c.mass and n.shape.kind~='cliff' and n.shape.kind~='caveWall' and n.shape.kind~='water' and n.shape.kind~='steps' and not n.stairs then
      local nb=n.base or 0
      if nb~=cb and not seaUnder then
       -- (half a pixel inside the cell: the rock's own face stands at the cell's edge, and a ground
       -- wall in the same plane showed through it in stripes -- Route 119's terraces read as grass walls)
       local ax,az=x+(d[1]>0 and 15.5 or d[1]<0 and .5 or 0),z+(d[2]>0 and 15.5 or d[2]<0 and .5 or 0)
       local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
       if nb<cb then
        -- the drop from this rock cell down to a lower floor beside it is the rock's own face, not its
        -- ground: in courses of the cell's tile, the bottom rows under the rim (a sunk garden's walls,
        -- the rock cheeks of a stair onto a raised meadow showed lawn-green walls)
        local y1=cb
        while y1>nb+.01 do
         local y0=math.max(nb,y1-16);local rows=y1-y0
         local v0=uv[3][2]-(uv[3][2]-uv[1][2])*rows/16;local vb=uv[3][2]
         quad(b.v,b.i,{{ax,y0,az},{bx,y0,bz},{bx,y1,bz},{ax,y1,az}},{{uv[1][1],vb},{uv[2][1],vb},{uv[2][1],v0},{uv[1][1],v0}},.78)
         y1=y0
        end
       else
        quad(b.v,b.i,{{ax,math.min(nb,cb),az},{bx,math.min(nb,cb),bz},{bx,math.max(nb,cb),bz},{ax,math.max(nb,cb),az}},gu,.78)
       end
      end
     end
    end
   elseif not shape.bank then plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv) end
   if shape.seaRock then
    -- water under a sea boulder: its flattened water patches sit on it
    local wmid
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and n.shape.kind=='water' and n.ts==ts then wmid=n.mid;break end end
    if wmid then plane(b.wv,b.wi,x,z,uvFor(ts,wmid) or uv,.05) end
   end
   if c.mass and Mass.usable(c.mass,cells) then
    -- a rock mass stands up from its own drawing (Gen3Mass); its first cell emits all of it
   else
    Terrain.append(cells,c,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,uvFor)
   end
  elseif c.prop then
   if not c.prop.recipe.noGround then
    local r=c.prop.recipe;local floorMid=r.ground
    -- floorFrom='neighbour': the floor under this cell is the nearest
    -- neighbour's, among the recipe's own floor tiles (a chair on the rug in
    -- one house, on wood in another)
    if r.floorFrom=='neighbour' and r.pixelGround then
     local ok={};for _,m in ipairs(r.pixelGround)do ok[m]=true end
     for _,d in ipairs({{0,1},{-1,0},{1,0},{0,-1},{0,2},{-2,0},{2,0},{0,-2}})do
      local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
      if n and not n.prop and ok[n.mid] then floorMid=n.mid;break end
     end
    end
    plane(b.v,b.i,x,z,uvFor(ts,floorMid) or uvFor(ts,1) or uv)
   end
  elseif shape.kind=='tree' and shape.canopy then
   -- Dense forest canopy (0x0C6/0x0C7): a raised mass, not single trees. The
   -- top is the tile's own art; the sides repeat the art in 16-row courses
   -- (no stretching), only where the neighbour is not canopy too.
   -- A connected canopy stands on the lowest walkable ground it touches:
   -- blocked canopy cells otherwise inherit a walkway's height beside them
   -- and the forest swallows the walkway (Fortree).
   -- (Route 110's raised cycling road deck is not ground the forest stands on.)
   -- Fortree's canopy-edge foliage under a deck touches only the deck and
   -- the ladder as walkable cells: it also stands on the bushes beside it
   -- (blocked, not a building), or it would tower a course above the forest.
   -- CANOPY_TREES: one real tree per cell (below) instead of the box; false = the old box for every cell
   local CANOPY_TREES=true
   local CANOPY_LOG=false  -- debug print per canopy cell (tree or box); default off
   if c.canopyBottom==nil then
    local group,seen,queue,head={}, {[c]=true},{c},1
    local low,lowBlocked
    while queue[head]do local a=queue[head];head=head+1;group[#group+1]=a
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and not seen[n] then
       if n.shape and n.shape.canopy then seen[n]=true;queue[#queue+1]=n
       elseif (n.collision or 0)==0 and n.base and not (n.shape and n.shape.cyclingRoad=='deck') then low=math.min(low or n.base,n.base)
       elseif a.shape.fortree and n.base and not n.bldModel then lowBlocked=math.min(lowBlocked or n.base,n.base) end
      end
     end
    end
    if lowBlocked and low then low=math.min(low,lowBlocked) end
    if not low then for _,a in ipairs(group)do low=math.min(low or (a.base or 0),a.base or 0)end end
    -- (outside Fortree: each cell stands on the walkable ground NEAREST to it, not on the lowest the
    -- whole forest touches anywhere -- Route 111's grove runs on into Route 112, whose floor is 56 px
    -- lower, and the whole grove sank into a pit with the sky showing round it)
    -- (Fortree's own wood stands on the lowest floor it touches; a wood of a neighbouring map seen from
    -- Fortree takes the nearest floor like anywhere else: Route 120's forest east of the city took a floor
    -- 24 px below the seam and sank under the world's underlay, a hole at the map edge)
    -- (decided per cell, and in map order: whichever cell of a group was met first used to decide for the
    -- whole group, so a wood straddling Fortree's edge came out differently from visit to visit)
    table.sort(group,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
    local inside=function(a)return a.cx>=0 and a.cy>=0 and def and def.midLayout and a.cx<def.midLayout.width and a.cy<def.midLayout.height end
    local fortreeMap=(def and def.id)=='EM_FORTREE_CITY'
    local function fortreeWood(a)return a.shape.fortree or (fortreeMap and inside(a)) end
    local near,q,qh={}, {},1
    for _,a in ipairs(group)do
     local f
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and not (n.shape and n.shape.canopy) and (n.collision or 0)==0 and n.base and not (n.shape and n.shape.cyclingRoad=='deck') then f=math.min(f or n.base,n.base) end
     end
     if f then near[a]=f;q[#q+1]=a end
    end
    while q[qh]do local a=q[qh];qh=qh+1
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and seen[n] and near[n]==nil then near[n]=near[a];q[#q+1]=n end
     end
    end
    -- Fortree's own wood: the lowest floor its cells inside the city touch (a wood running on into
    -- Route 120 does not stand the city's wood on Route 120's floor, 24 px below the seam)
    local lowIn
    for _,a in ipairs(group)do if fortreeWood(a) and inside(a) then
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
      if n and inside(n) and not (n.shape and n.shape.canopy) and n.base then
       if (n.collision or 0)==0 and not (n.shape and n.shape.cyclingRoad=='deck') then lowIn=math.min(lowIn or n.base,n.base)
       elseif a.shape.fortree and not n.bldModel then lowIn=math.min(lowIn or n.base,n.base) end   -- (as lowBlocked above)
      end
     end
    end end
    for _,a in ipairs(group)do
     if fortreeWood(a) then a.canopyBottom=lowIn or low else a.canopyBottom=near[a] or low end
    end
   end
   -- FORTREE_V2: a Fortree forest cell stands on the lowest walkable floor touching its group (canopyBottom),
   -- so a rim cell at base 32 is not a tree on a deck's height; only a cell that is itself a deck stands on its base
   local fv2=FORTREE_V2 and def and def.id=='EM_FORTREE_CITY'
   local treeY=c.canopyBottom
   if fv2 then treeY=isDeck(c) and (c.base or 0) or c.canopyBottom end
   local lift=treeY-(c.base or 0)   -- vertices are lifted by c.base later
   local H=CANOPY_HEIGHT+lift
   local art=uvFor(ts,shape.topMid or c.mid) or uvFor(ts,c.mid) or uv
   -- ground under the mass, so no gap can ever show the sky
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv,lift)
   -- A real tree per cell: the narrow one-cell tree of this tileset (canopy over trunk; the two
   -- variants alternate by cell parity), instanced at the canopy's foot with a small hashed offset.
   -- Fortree and palm cells, stage-hidden cells and tilesets without the tiles keep the box.
   local card
   -- (Fortree City's whole map keeps the box; Routes 119 and 120 share its tileset and get trees: its walkways and treehouses stand on that mass)
   -- FORTREE_V2: a cell gets ground only (no tree, no box) when it is a border cell outside the
   -- map (Gen3Boundary's pit), a palm crown (Gen3Fortree builds its dome) or a palm trunk (its column)
   local outside=fv2 and (not (c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height)
    or shape.palmCrown or ((c.mid==0x241 or c.mid==0x25C) and (cells[c.cx..':'..(c.cy-1)] or {}).shape and cells[c.cx..':'..(c.cy-1)].shape.palmCrown))
   if CANOPY_TREES and TreeStyle.voxel() and (fv2 or (not shape.fortree and (def and def.id)~='EM_FORTREE_CITY' and not shape.palmCrown)) and not outside and not c.stageHidden then
    local top=(c.cx+c.cy)%2==0 and 0x00E or 0x00F
    -- A forest is the tileset's full-size tree repeated (as the cartridge draws it: two cells wide, a row
    -- of crowns every second row), not a hedge of narrow one-cell trees whose light and dark tiers ran
    -- as bands through the whole wood. bigAt: nil = this cell is under a neighbour's crown.
    local big=not fv2 and ts.midToSlot[0x1CE] and ts.midToSlot[0x1CF] and ts.midToSlot[0x1D4] and ts.midToSlot[0x1D5] and ts.midToSlot[0x1DC] and ts.midToSlot[0x1DD]
    local bigX
    if big then
     local function can(dx,dy)local n=cells[(c.cx+dx)..':'..(c.cy+dy)];return n and n.shape and n.shape.canopy and not n.shape.palmCrown end
     local k=0;while can(-k-1,0) and k<512 do k=k+1 end
     local rowHere=c.cy%2==0 or not can(0,-1)
     if rowHere and k%2==0 then bigX=can(1,0) and 16 or 8 end
     ts.canopyTreeCards=ts.canopyTreeCards or {}
     card=ts.canopyTreeCards.big
     if card==nil then
      card=V.require('NativeTreeArt').gen3({ts=ts,mid=0x1DC,shape={art={{0x1CE,0x1CF},{0x1D4,0x1D5},{0x1DC,0x1DD}},artTipRows=1,ground=shape.ground}})or false
      ts.canopyTreeCards.big=card
     end
     if not card then big=nil end
    end
    if big then
     if bigX then
      local seed=c.cx*73+c.cy*139
      local tx,tz=x+bigX+seed%5-2,z+11+math.floor(seed/7)%5-2
      if not V.require('NativeTreeArt').addInstance(card,treeGroups,tx,treeY,tz) then
       V.require('NativeTreeArt').appendModel(card,leaf,li,0,tx,lift,tz)
      end
     end
     card=nil;outside=true
    elseif ts.midToSlot[top] and ts.midToSlot[top+8] then
     -- FORTREE_V2: its own card, drawn with no ground palette (ground 0 = black, never a grass green): the
     -- floor's greens removed the trunk row's bush, so the crown hung over the sky above a dark tuft
     ts.canopyTreeCards=ts.canopyTreeCards or {}
     local ck=fv2 and 'fv2'..top or top
     card=ts.canopyTreeCards[ck]
     if card==nil then
      card=V.require('NativeTreeArt').gen3({ts=ts,mid=top,shape={art={{top},{top+8}},ground=fv2 and 0 or shape.ground}})or false
      ts.canopyTreeCards[ck]=card
     end
    end
   end
   if card then
    -- instanced positions are absolute (y = canopyBottom); the leaf fallback is lifted by c.base like the rest
    local seed=c.cx*73+c.cy*139
    -- one tree per cell: a second row per cell closed the gaps but read as striped columns, not trees
    local tx,tz=x+8+seed%7-3,z+11+math.floor(seed/7)%5-2
    for _,rz in ipairs({tz})do
     if not V.require('NativeTreeArt').addInstance(card,treeGroups,tx,treeY,rz) then
      V.require('NativeTreeArt').appendModel(card,leaf,li,0,tx,lift,rz)
     end
    end
   elseif not outside then
    quad(b.v,b.i,{{x,H,z},{x+16,H,z},{x+16,H,z+16},{x,H,z+16}},art,1)
   end
   if CANOPY_LOG then print('canopy',c.cx,c.cy,card and 'tree' or 'box') end
   -- (a forest standing on two floors -- each cell on the ground nearest it -- is closed where it steps
   -- down: a bank of its ground's own art, course by course, so no sky shows between the floors)
   if (card or outside) and not fv2 then
    local g=uvFor(ts,shape.ground) or uv
    for _,d in ipairs({{0,1,.82},{0,-1,.62},{-1,0,.7},{1,0,.7}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     local nb=n and n.shape and n.shape.canopy and n.canopyBottom
     -- (and down to open ground or water beside it that lies lower: a wood standing on the higher
     -- floor beside a river stood on a plate with the river's side open under it -- Route 119, the
     -- first-person survey's magenta probe)
     -- (tall grass and a lone tree beside it count too: Route 123's wood stood 8 px over the tall grass
     -- west of it with that side open, the magenta probe under it)
     local nk=n and n.shape and n.shape.kind
     if not nb and n and (nk=='water' or nk=='grass' or nk=='tree' or (nk=='flat' or nk=='flowers' or nk=='sand') and (n.collision or 0)==0) and not (n.mass or n.bldModel or n.civic or n.column) then
      nb=n.base or 0
     end
     if nb and nb<treeY then
      local x0,z0,x1,z1
      if d[2]==1 then x0,z0,x1,z1=x,z+16,x+16,z+16 elseif d[2]==-1 then x0,z0,x1,z1=x+16,z,x,z
      elseif d[1]==-1 then x0,z0,x1,z1=x,z,x,z+16 else x0,z0,x1,z1=x+16,z+16,x+16,z end
      local yb=nb-(c.base or 0)
      while yb<lift-.01 do
       local yt=math.min(lift,yb+16)
       quad(b.v,b.i,{{x0,yt,z0},{x1,yt,z1},{x1,yb,z1},{x0,yb,z0}},g,d[3])
       yb=yt
      end
     end
    end
   end
   -- (and a higher open floor or fill beside a wood standing lower is closed down to it: Fortree's wood
   -- stands on the lowest floor it touches, and the border ground beyond its north edge stood 32 px
   -- over the wood's floor with its side open -- a band of sky under it)
   do
    local g=uvFor(ts,shape.ground) or uv
    for _,d in ipairs({{0,1,.82},{0,-1,.62},{-1,0,.7},{1,0,.7}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     local nk=n and n.shape and n.shape.kind
     if n and not (n.shape and n.shape.canopy) and (nk=='flat' or nk=='grass' or nk=='flowers' or nk=='sand') and not (n.mass or n.bldModel or n.civic or n.column)
       and (n.base or 0)>treeY+.01 then
      local x0,z0,x1,z1
      -- the edge between the two cells, wound to face into this cell
      if d[2]==1 then x0,z0,x1,z1=x+16,z+16,x,z+16 elseif d[2]==-1 then x0,z0,x1,z1=x,z,x+16,z
      elseif d[1]==-1 then x0,z0,x1,z1=x,z+16,x,z else x0,z0,x1,z1=x+16,z,x+16,z+16 end
      local yb,top=lift,(n.base or 0)-(c.base or 0)
      while yb<top-.01 do
       local yt=math.min(top,yb+16)
       quad(b.v,b.i,{{x0,yt,z0},{x1,yt,z1},{x1,yb,z1},{x0,yb,z0}},g,d[3])
       yb=yt
      end
     end
    end
   end
   local function open(dx,dz)
    if card then return false end
    local n=cells[(c.cx+dx)..':'..(c.cy+dz)]
    return not (n and n.shape and n.shape.canopy and n.canopyBottom==c.canopyBottom)
   end
   for y0=lift,(outside and lift-16 or H-16),16 do
    local y1=y0+16
    if open(0,1) then quad(b.v,b.i,{{x,y1,z+16},{x+16,y1,z+16},{x+16,y0,z+16},{x,y0,z+16}},{art[1],art[2],art[3],art[4]},.82) end
    if open(0,-1) then quad(b.v,b.i,{{x+16,y1,z},{x,y1,z},{x,y0,z},{x+16,y0,z}},{art[1],art[2],art[3],art[4]},.62) end
    if open(-1,0) then quad(b.v,b.i,{{x,y1,z},{x,y1,z+16},{x,y0,z+16},{x,y0,z}},{art[1],art[2],art[3],art[4]},.7) end
    if open(1,0) then quad(b.v,b.i,{{x+16,y1,z+16},{x+16,y1,z},{x+16,y0,z},{x+16,y0,z+16}},{art[1],art[2],art[3],art[4]},.7) end
   end
   if shape.palmCrown and not fv2 then
    -- A palm's crown stands one course above the canopy on its trunk: the
    -- drooping fronds (this tile, 16 rows) are the crown's faces, and its top
    -- is the bright frond tips (the bottom 8 rows of the tile behind, laid
    -- twice over the 16-px depth, never stretched).
    local crown=uvFor(ts,c.mid) or uv
    local y0,y1=H+16,H+32
    local function rows(u,r0,r1) local t,bt=u[1][2],u[3][2]
     local a,bb=t+(bt-t)*r0/16,t+(bt-t)*r1/16
     return {{u[1][1],a},{u[2][1],a},{u[3][1],bb},{u[4][1],bb}} end
    local tips=uvFor(ts,c.mid-8)
    tips=tips and rows(tips,8,16) or crown
    for _,zz in ipairs({z,z+8})do
     quad(b.v,b.i,{{x,y1,zz},{x+16,y1,zz},{x+16,y1,zz+8},{x,y1,zz+8}},tips,1)
    end
    quad(b.v,b.i,{{x,y1,z+16},{x+16,y1,z+16},{x+16,y0,z+16},{x,y0,z+16}},crown,.82)
    quad(b.v,b.i,{{x+16,y1,z},{x,y1,z},{x,y0,z},{x+16,y0,z}},crown,.62)
    quad(b.v,b.i,{{x,y0,z+16},{x+16,y0,z+16},{x+16,y0,z},{x,y0,z}},crown,.45)
    local function crownAt(dx) local n=cells[(c.cx+dx)..':'..c.cy]; return n and n.shape and n.shape.palmCrown end
    if not crownAt(-1) then quad(b.v,b.i,{{x,y1,z},{x,y1,z+16},{x,y0,z+16},{x,y0,z}},crown,.7) end
    if not crownAt(1) then quad(b.v,b.i,{{x+16,y1,z+16},{x+16,y1,z},{x+16,y0,z},{x+16,y0,z+16}},crown,.7) end
    -- the trunk: under the crown's middle (its art is the cell below), one
    -- course of the trunk tile from the canopy top up to the crown
    local s=cells[c.cx..':'..(c.cy+1)]
    if crownAt(-1) and crownAt(1) and s and (s.mid==0x241 or s.mid==0x25C) then
     local bark=uvFor(ts,0x241) or crown
     local a,e=x+2,x+14
     local za,ze=z+2,z+14
     quad(b.v,b.i,{{a,y0,ze},{e,y0,ze},{e,H,ze},{a,H,ze}},bark,.82)
     quad(b.v,b.i,{{e,y0,za},{a,y0,za},{a,H,za},{e,H,za}},bark,.62)
     quad(b.v,b.i,{{a,y0,za},{a,y0,ze},{a,H,ze},{a,H,za}},bark,.7)
     quad(b.v,b.i,{{e,y0,ze},{e,y0,za},{e,H,za},{e,H,ze}},bark,.7)
    end
   end
  elseif shape.kind=='tree' then
   -- (planeOwn: the tile's own ground layer -- dirt and shadow -- under it)
   plane(b.v,b.i,x,z,(shape.planeOwn and uv) or uvFor(ts,shape.ground) or uv)
   -- FORTREE_V2: outside the map the ground is the boundary cell's own base (32 and below), so the
   -- tree stands on that base, not on 0 where its crown hung in the sky
   local fv2=FORTREE_V2 and def and def.id=='EM_FORTREE_CITY'
   local fortreeOutside=fv2 and not (c.cx>=0 and c.cy>=0 and c.cx<def.midLayout.width and c.cy<def.midLayout.height)
   if shape.root and not c.stageHidden then
    if TreeStyle.original() then
     local native=V.require('NativeTreeArt')
     local tx,tz=x+(shape.anchorX or 16),z+(shape.anchorZ or 12)
     -- FORTREE_V2: the tree stands on the ground (0), not on its cell's base (see groundY below)
     local gy=fv2 and (fortreeOutside and 0 or -(c.base or 0)) or 0
     if TreeStyle.voxel() then
      -- FORTREE_V2: the card without the floor's palette (see the canopy card): its trunk row keeps its bush
      local card=native.gen3(fv2 and {ts=c.ts,pair=c.pair,mid=c.mid,shape=setmetatable({ground=0},{__index=c.shape})} or c)
      if not native.addInstance(card,treeGroups,tx,(fv2 and not fortreeOutside) and 0 or (c.base or 0),tz)then native.appendModel(card,leaf,li,0,tx,gy,tz)end
     else native.append(native.gen3(c),leaf,li,0,tx,gy,tz,TreeStyle.flat()) end
     if not TreeStyle.voxel() and not TreeStyle.flat() then Trees.appendTrunk(wood,wi,0,tx,gy,tz,4,c.cx*73+c.cy*139) end
    else
    local seed=c.cx*73+c.cy*139
    local append=TreeStyle.flat() and Trees.appendFlatTrunk or Trees.appendTrunk
    local tx,tz=x+(shape.anchorX or 16),z+(shape.anchorZ or 12)
    local ws,ls=#wood,#leaf
    -- FORTREE_V2: a Fortree tree cell stands on the ground, not its own base (a tree on the
    -- deck's height, 32, hung in the sky): the lift by the base is taken back here
    local groundY=fv2 and (fortreeOutside and 0 or -(c.base or 0)) or 0
    append(wood,wi,0,tx,groundY,tz,20,seed)
    Leaves.append(leaf,li,0,tx,groundY,tz,20,seed,Trees.family(seed,20),TreeStyle.flat())
    if shape.treeScale then
     local function resize(vertices,start)
      for j=start+1,#vertices do local v=vertices[j]
       v[1],v[2],v[3]=tx+(v[1]-tx)*shape.treeScale,v[2]*shape.treeScale,tz+(v[3]-tz)*shape.treeScale
       if v[9] then v[9]=v[9]*shape.treeScale end
      end
     end
     resize(wood,ws);resize(leaf,ls)
    end
    end
   end
  elseif column and not column.indoor and VoxelBuildings.enabled then
   -- pixel-voxel building (Gen3VoxelBuildings): the drawing's own pixels
   -- as voxels, nothing stretched; the column's top cell builds the body
   plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   if c.cy==column.first and not column.stageHidden then
    VoxelBuildings.append(cells,c,function(v,t,shade)quad(b.v,b.i,v,t,shade)end)
   end
  elseif column and column.indoor and c.secondary=='lab' and column.first<=1 then
   -- (the lab's north wall is built below, from row 0; an interior wall
   -- further in -- the Weather Institute's divider -- stands as a column)
   plane(b.v,b.i,x,z,uvFor(ts,0x289) or uv)
  elseif column then
   -- (a ship cabin's back wall with the void behind it stands on no floor:
   -- nothing lies behind the wall but the black between the cabins)
   if not (column.indoor and CABINS[def.id or ''] and not cells[c.cx..':'..(column.first-1)]) then
    plane(b.v,b.i,x,z,uvFor(ts,shape.ground) or uv)
   end
   if not column.stageHidden then
   if column.indoor or c.cy>=(column.wallTop or column.first+column.roofs) then
    local row=c.cy-(column.wallTop or column.first+column.roofs)
    local step=column.rowStep or column.height/column.walls
    local top=column.height-row*step
    local low=top-step
    -- trimTop: the top rows of the wall's art are the black above it, not wall
    local trimTop=shape.trimTop or (WALL_TRIM[def.id or ''] and WALL_TRIM[def.id][c.mid])
    if row==0 and trimTop then
     local k=trimTop/16
     top=top-step*k
     local v=uv[1][2]+(uv[4][2]-uv[1][2])*k
     uv={{uv[1][1],v},{uv[2][1],v},uv[3],uv[4]}
    end
    local portal=c.gym and (c.cx==c.gym.cx+3 or c.cx==c.gym.cx+4)
    local front=column.front+(portal and 4 or 0)
    -- an outdoor building's front wall: a tile that may hold window glass (GlassMask)
    if not column.indoor then V.require('GlassMask').facade(ts,c.mid)end
    -- (a Pokemon Center's wall ends, 0x208/0x20F: the side wall drawn slanting
    -- away, with the black outside over it -- only the wall part stands, a
    -- card per pixel column, so no black triangle hangs at the wall's corner)
    local slant=c.secondary=='pokemon_center' and (c.mid==0x208 or c.mid==0x20F)
    if slant then
     for px=0,15 do
      local k=c.mid==0x208 and 15-px or px
      if k<16 then
       local u0=uv[1][1]+(uv[2][1]-uv[1][1])*px/16;local u1=uv[1][1]+(uv[2][1]-uv[1][1])*(px+1)/16
       local v0=uv[1][2]+(uv[4][2]-uv[1][2])*k/16
       local t0=top-(top-low)*k/16
       quad(b.v,b.i,{{x+px,t0,front},{x+px+1,t0,front},{x+px+1,low,front},{x+px,low,front}},{{u0,v0},{u1,v0},{u1,uv[3][2]},{u0,uv[4][2]}})
      end
     end
    else
    quad(b.v,b.i,{{x,top,front},{x+16,top,front},{x+16,low,front},{x,low,front}},uv)
    end
    if portal then
     local u,t=uv[1][1]+(uv[2][1]-uv[1][1])*.12,uv[1][2]+(uv[3][2]-uv[1][2])*.12
     local trim=swatch(ts,u,t)
     if row==0 then quad(b.v,b.i,{{x,top,column.front},{x+16,top,column.front},{x+16,top,front},{x,top,front}},trim,.9)end
     local side=c.cx==c.gym.cx+3 and x or x+16
     quad(b.v,b.i,{{side,top,column.front},{side,top,front},{side,low,front},{side,low,column.front}},trim,.8)
    end
    if not slant then
    do
     -- Every building is a closed box so a rotated camera never looks into
     -- an open shell. Sides and back repeat this row's own wall drawing, one
     -- 16-unit panel at a time, so a deep building keeps its window rhythm
     -- instead of a stretched or plain-coloured slab. Outdoor roofs already
     -- cap the top; interiors cap it with a plain swatch here.
     local u,t=(uv[1][1]+uv[2][1])*.5,uv[1][2]
     local solid=swatch(ts,u,t)
     -- Sides and back are one clean panel per storey row, coloured by a
     -- single column of this row's facade just inside its corner trim: the
     -- wall keeps its base line, siding and top trim as horizontal bands,
     -- without windows or doors smeared or repeated along the depth.
     -- (an indoor wall's sides and back - the back of a room's south wall faces into the room - take the
     -- wall tile's own drawing: one swatch stood as a plain navy slab in first person, Ever Grande's rooms)
     local own=uv
     local function band(px)
      -- (sideArt: a hall wall standing free shows its own courses on its sides and back)
      if column.indoor and not shape.sideArt then return own end
      px=wallColumn(ts,c.mid,px)
      local bu=uv[1][1]+(uv[2][1]-uv[1][1])*px/16
      return {{bu,uv[1][2]},{bu,uv[2][2]},{bu,uv[3][2]},{bu,uv[4][2]}}
     end
     -- (the tile's own drawing is laid a tile's height at a time, from the top down: stretched over a
     -- tall wall it stood as giant pixels)
     local tiled=column.indoor and not shape.sideArt
     local function face(pts,t,sh)
      if not tiled then quad(b.v,b.i,pts(top,low),t,sh);return end
      local y=top
      while y>low+.01 do
       local yb=math.max(low,y-16);local f=(y-yb)/16
       local T,B=t[1][2],t[1][2]+(t[4][2]-t[1][2])*f
       quad(b.v,b.i,pts(y,yb),{{t[1][1],T},{t[2][1],T},{t[3][1],B},{t[4][1],B}},sh);y=yb
      end
     end
     for _,dx in ipairs({-1,1})do
      if Roof.sideVisible(cells,c,dx)then local sx=dx<0 and x or x+16
       face(function(a,bb)return {{sx,a,column.back},{sx,a,column.front},{sx,bb,column.front},{sx,bb,column.back}}end,band(dx<0 and 2.5 or 13.5),.82)
      end
     end
     local wallArt=band(2.5)
     if (column.indoor or column.roofs==0) and c.cy==math.max(column.first,column.wallTop or column.first) then
      -- flat cap of a roofless facade or wing
      local cap=column.indoor and solid or band(8)
      quad(b.v,b.i,{{x,top,column.back},{x+16,top,column.back},{x+16,top,column.front},{x,top,column.front}},cap,.95)
     end
     -- A column whose art stops a row above the building's base stands on
     -- a plain plinth rather than floating.
     if (not column.indoor or column.lowerMid) and c.cy==column.last and low>.01 then
      local base=band(2.5)
      -- (an indoor wall's hidden lower half: the lower wall tile's own art)
      if column.lowerMid then base=uvFor(ts,column.lowerMid) or base end
      quad(b.v,b.i,{{x,low,column.front},{x+16,low,column.front},{x+16,0,column.front},{x,0,column.front}},base,.9)
      for _,ddx in ipairs({-1,1})do if Roof.sideVisible(cells,c,ddx)then local sx=ddx<0 and x or x+16
       quad(b.v,b.i,{{sx,low,column.back},{sx,low,column.front},{sx,0,column.front},{sx,0,column.back}},base,.8)
      end end
      quad(b.v,b.i,{{x+16,low,column.back},{x,low,column.back},{x,0,column.back},{x+16,0,column.back}},base,.7)
     end
     face(function(a,bb)return {{x+16,a,column.back},{x,a,column.back},{x,bb,column.back},{x+16,bb,column.back}}end,wallArt,.7)
    end
    end
   else
    do
     local rm=c.roofMid or c.mid
     -- the top row of a roof is painted over whatever lies behind the house
     local below=cells[c.cx..':'..(c.cy+1)]
     local topRow=c.cy==column.first and column.roofs>=2 and below and below.shape.kind=='roof'
     local walk=((c.collision or 0)==0 or topRow) and not c.roofMid
     if walk and b.roofMids[rm]~=true then b.roofMids[rm]='over' else b.roofMids[rm]=true end
    end
    uv=uvFor(ts,c.roofMid or c.mid)
    local row=c.cy-column.first
    local isFront=column.roofType=='front'
    local artBack=isFront and (Roof.ridge(column)) or column.back
    -- Art rows are counted up from the eave, over the building's own row
    -- count, so every column of one building lays the same map row at the
    -- same place on the slope even when its roof is a row shorter.
    local artRows=math.max(column.artRows or column.roofs,1)
    local up=(column.first+column.roofs-1)-c.cy
    local z1=column.front-(column.front-artBack)*up/artRows
    local z0=column.front-(column.front-artBack)*(up+1)/artRows
    local function roofY(a)return Roof.height(column,a) end
    -- Plain roof colour for backings: a pixel toward the INSIDE of the roof
    -- (away from a corner tile's cut-off, outlined edge).
    local fu=Roof.sideVisible(cells,c,-1) and .78 or Roof.sideVisible(cells,c,1) and .22 or .5
    local fv=row==0 and .8 or row==column.roofs-1 and .3 or .5
    -- a cap row that is mostly open air: take the colour from the row below
    local fillUv=uv
    do local belowRoof=cells[c.cx..':'..(c.cy+1)]
     if b.roofMids[c.roofMid or c.mid]=='over' and belowRoof and belowRoof.shape.kind=='roof' then
      fillUv=uvFor(ts,belowRoof.roofMid or belowRoof.mid) or uv;fv=.5
     end
    end
    local roofFill=swatch(ts,fillUv[1][1]+(fillUv[2][1]-fillUv[1][1])*fu,fillUv[1][2]+(fillUv[3][2]-fillUv[1][2])*fv)
    -- Keep each source cell's own art on the selected flat/gabled profile.
    for j=row==0 and math.floor((column.roofInset or 0)/4) or 0,3 do
     local a,bz=z0+(z1-z0)*j/4,z0+(z1-z0)*(j+1)/4
     local t0,t1=uv[1][2]+(uv[3][2]-uv[1][2])*j/4,uv[1][2]+(uv[3][2]-uv[1][2])*(j+1)/4
     local q={{uv[1][1],t0},{uv[2][1],t0},{uv[3][1],t1},{uv[4][1],t1}}
     quad(b.rv,b.ri,{{x,roofY(a),a},{x+16,roofY(a),a},{x+16,roofY(bz),bz},{x,roofY(bz),bz}},q)
     local function eave(A,B,dx,dz)
      V.require('RoofEaves').edge(A,B,dx,dz,q,function(v,t,shade)quad(b.rv,b.ri,v,t,shade)end)
     end
     if Roof.sideVisible(cells,c,-1)then eave({x,roofY(bz),bz},{x,roofY(a),a},-2,0)end
     if Roof.sideVisible(cells,c,1)then eave({x+16,roofY(a),a},{x+16,roofY(bz),bz},2,0)end
     if not isFront and row==0 and j==math.floor((column.roofInset or 0)/4)then eave({x,roofY(a),a},{x+16,roofY(a),a},0,-2)end
     if isFront and row==0 and j==0 then
      -- The short back slope: the roof's own top strip, mirrored over the ridge.
      local zb=column.back
      local zr=artBack
      -- plain roof from the ridge down the back, and down the front as far
      -- as this column's own art begins
      -- a plain surface (the terrain batch): the roof image batch would
      -- sample a transparent texel wherever the art's corner is cut away
      quad(b.v,b.i,{{x,roofY(zb),zb},{x+16,roofY(zb),zb},{x+16,roofY(zr),zr},{x,roofY(zr),zr}},roofFill,.8)
      if a>zr+.01 then quad(b.v,b.i,{{x,roofY(zr),zr},{x+16,roofY(zr),zr},{x+16,roofY(a),a},{x,roofY(a),a}},roofFill,1) end
      eave({x,roofY(zb),zb},{x+16,roofY(zb),zb},0,-2)
      if Roof.sideVisible(cells,c,-1)then eave({x,roofY(a),a},{x,roofY(zr),zr},-2,0);eave({x,roofY(zr),zr},{x,roofY(zb),zb},-2,0)end
      if Roof.sideVisible(cells,c,1)then eave({x+16,roofY(zr),zr},{x+16,roofY(a),a},2,0);eave({x+16,roofY(zb),zb},{x+16,roofY(zr),zr},2,0)end
     end
     if row==column.roofs-1 and j==3 then eave({x+16,roofY(bz),bz},{x,roofY(bz),bz},0,2)end
     local north=not isFront and row==0 and j==math.floor((column.roofInset or 0)/4)
     local south=row==column.roofs-1 and j==3
     for _,side in ipairs({-1,1})do if Roof.sideVisible(cells,c,side)then
      local xx=side<0 and x or x+16
      for _,endcap in ipairs({{north,a,-2},{south,bz,2}})do if endcap[1]then
       V.require('RoofEaves').corner({xx,roofY(endcap[2]),endcap[2]},side*2,endcap[3],q,
        function(v,t,shade)quad(b.rv,b.ri,v,t,shade)end)
      end end
     end end
     -- Close the exposed shell, including gables, without internal dividers.
     local wallCell=cells[c.cx..':'..column.last]
     local sideMid=wallCell.mid
     if c.secondary=='pallet_town' then sideMid=column.roofType=='flat' and 0x2C2 or 0x2A0 end
     local side=uvFor(ts,sideMid) or uvFor(ts,wallCell.mid)
     -- Sample the facade trim for closed siding rather than stretch the roof
     -- artwork down the building's entire side.
     local u=(side[1][1]+side[2][1])*.5
     local t=side[1][2]+(side[3][2]-side[1][2])*.2
     local solid=swatch(ts,u,t)
     for _,dx in ipairs({-1,1})do
      if Roof.sideVisible(cells,c,dx) then
       local sx=dx<0 and x or x+16
       -- Gable only: the wall rows below own the side of the box (their
       -- tiled facade art), so stop at the wall top instead of the ground.
       local foot=column.indoor and 0 or column.height
       quad(b.v,b.i,{{sx,roofY(a),a},{sx,roofY(bz),bz},{sx,foot,bz},{sx,foot,a}},solid,.82)
       if isFront and row==0 and j==0 then
        local zb,zr=column.back,artBack
        quad(b.v,b.i,{{sx,roofY(zb),zb},{sx,roofY(zr),zr},{sx,foot,zr},{sx,foot,zb}},solid,.82)
        if a>zr+.01 then quad(b.v,b.i,{{sx,roofY(zr),zr},{sx,roofY(a),a},{sx,foot,a},{sx,foot,zr}},solid,.82) end
       end
       if c.secondary=='pallet_town' then
        Cladding.side(sx,a,bz,roofY(a),roofY(bz),dx,solid,function(v,t,shade)quad(b.v,b.i,v,t,shade)end)
       end
      end
     end
     if not isFront and row==0 and j==math.floor((column.roofInset or 0)/4) then
      local foot=column.indoor and 0 or column.height
      quad(b.v,b.i,{{x+16,roofY(a),a},{x,roofY(a),a},{x,foot,a},{x+16,foot,a}},solid,.74)
      if c.secondary=='pallet_town' then Cladding.back(x,x+16,a,roofY(a),solid,function(v,t,shade)quad(b.v,b.i,v,t,shade)end)end
     end
    end
   end
   end
  elseif shape.kind=='sign' or shape.kind=='fence' or shape.kind=='ledge' or shape.kind=='flowers' or shape.kind=='shrub' or shape.kind=='grass' or shape.kind=='awning' then
   -- (a ledge at the top of a drop has its lip flush with this plane: only the ground it leaves bare)
   local gu=uvFor(ts,shape.ground) or uv
   if not (shape.kind=='ledge' and Outdoor.ledgeFloor(c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,gu)) then plane(b.v,b.i,x,z,gu) end
   local plant=shape.kind=='flowers' or shape.kind=='shrub' or shape.kind=='grass'
   if not c.stageHidden then Outdoor.append(c,function(vertices,tex,shade,anchor)quad(plant and b.pv or b.v,plant and b.pi or b.i,vertices,tex,shade,anchor)end,uvFor)end
  elseif c.object or c.objectTop then
   -- generic standing object (Gen3Objects): its neighbours' ground under it
   local o=c.object or c.objectTop
   -- a rock in the sea stands in animated water, like the water around it
   if o.water then plane(b.wv,b.wi,x,z,uvFor(ts,o.ground) or uv,.05) else plane(b.v,b.i,x,z,uvFor(ts,c.objGround or o.ground) or uv) end
   -- (a sea rock merged into its stack is emitted, with the stack, by the stack's owner cell: Gen3Mass)
   if c.objectOwner and not c.stageHidden and not (o.merged and c.mass and Mass.usable(c.mass,cells)) then Standing.append(o,function(v,t,shade)quad(b.v,b.i,v,t,shade)end,function(v,t,shade)quad(leaf,li,v,t,shade,{0,0,0})end) end
  else
   if shape.planks then V.require('Gen3Fence').extrude(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor,1,shape.planks)
   elseif not flight then plane(b.v,b.i,x,z,(shape.groundMid and uvFor(ts,shape.groundMid)) or uv) end
   -- a deck over a river: the river under it, at the river's level
   if shape.underWater then plane(b.wv,b.wi,x,z,uvFor(ts,shape.underWater) or uv,.05+(c.riverLevel or 0)-(c.base or 0)) end
  end
  local base=c.base or 0
  -- Terrain already owns absolute cap/retaining-face heights.
  if shape.kind=='cliff' or shape.kind=='caveWall' then base=0 end
  -- a cell rated a climb but drawn level with its floors (SHAPE_BY_MAP level=, absolute height)
  if shape.level then base=shape.level end
  -- A cell that carries a 3D tree or standing object has its crown/head art built into that model; the
  -- over-player layer must not ALSO be painted flat on the ground under it. Remember this cell's ground
  -- quad (the first four vertices it added, a flat cell-sized square) so the over-layer pass can skip it.
  -- the cable car: its line and pylon heads are drawn in the over layer of
  -- these cells; the 3D line replaces them (Gen3CableCar)
  local Cable=V.require('Gen3CableCar')
  if Cable.skipsOver(c) then for q=starts[1],#b.v-4,4 do b.skipOver[#b.skipOver+1]=q end end
  -- a pine's crown top drawn over the ground: the pine below carries it (Gen3AshPine)
  if shape.ashTop then b.skipOver[#b.skipOver+1]=starts[1] end
  -- a street lamp's head drawn over the lawn: the lamp standing in the cell south carries it (Gen3Lamp)
  if shape.lampTop and V.require('Gen3Lamp').isTop(c,cells) then b.skipOver[#b.skipOver+1]=starts[1] end
  if Cable.owns(M.sceneDef and M.sceneDef.id,c) then Cable.append(M.sceneDef.id,c,function(p,t,s)quad(b.v,b.i,p,t,s)end,uvFor) end
  local walkCanopy=not c.stageHidden and Canopy.applies(c)
  if (c.object or c.objectTop or c.treeOwned or (shape.kind=='tree' and not shape.canopy) or walkCanopy) and #b.v>=starts[1]+4 then
   local v1,v2,v3,v4=b.v[starts[1]+1],b.v[starts[1]+2],b.v[starts[1]+3],b.v[starts[1]+4]
   if v1[2]==v2[2] and v2[2]==v3[2] and v3[2]==v4[2] and math.abs(v3[1]-v1[1])==16 and math.abs(v3[3]-v1[3])==16 then
    b.skipOver[#b.skipOver+1]=starts[1]
   end
  end
  if setBack and shape.kind~='deckFace' and shape.kind~='deckBack' and shape.kind~='deckEdge' and shape.kind~='deckHead' and shape.kind~='deckRamp' and not c.stageHidden then Decks.skirt(def,c,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  -- Fortree City's decks, their posts and ladders (Gen3Fortree): real wood, lifted with the cell
  if FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and not c.stageHidden then V.require('Gen3Fortree').append(c,cells,function(p,t,sh)quad(b.v,b.i,p,t,sh)end,uvFor) end
  -- (a relief floor's sloped top, c.slope: plain vertices follow the slope where they stand; a swaying
  -- card - tall grass, flowers - rises whole by the slope at its anchor, so it is not sheared)
  local sl=c.slope
  if sl and base==c.base then
   local function off(px,pz)
    local u,w=math.max(0,math.min(1,(px-x)/16)),math.max(0,math.min(1,(pz-z)/16))
    return (sl[1]*(1-u)+sl[2]*u)*(1-w)+(sl[4]*(1-u)+sl[3]*u)*w
   end
   for k=starts[1]+1,#b.v do local v=b.v[k];v[2]=v[2]+off(v[1],v[3]) end
   for k=starts[3]+1,#b.pv do local v=b.pv[k]
    if v[7] and v[9] and v[9]~=0 then local o=off(v[7],v[8]);v[2]=v[2]+o;v[9]=v[9]+o
    else v[2]=v[2]+off(v[1],v[3]) end
   end
  end
  Elevation.lift(b.v,starts[1],base,setBack);Elevation.lift(b.rv,starts[2],base,setBack)
  if walkCanopy then local cs=#b.cv;Canopy.append(c,function(v,t,shade)quad(b.cv,b.ci,v,t,shade)end,uvFor,cells);Elevation.lift(b.cv,cs,base,setBack) end
  Elevation.lift(b.pv,starts[3],base,setBack);Elevation.lift(b.wv,starts[4],base,setBack)
  Elevation.lift(wood,starts[5],base,setBack);Elevation.lift(leaf,starts[6],base,setBack)
  if flight then PROBE.tag='flight';flightTreads(c,flight,cells,b,uv);PROBE.tag=nil end
  if shape.kind=='water' and not shape.cyclingRoad then
   -- Water surfaces on different levels (a river following terraces) leave an open gap
   -- between them: close each step with the water tile's own drawing.
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    if n and (n.shape.kind=='water' or n.shape.seaRock) and (n.base or 0)<base then
     local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
     local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
     local lo,hi=(n.base or 0)+.05,base+.05
     -- (a drop of more than a block -- a waterfall -- repeats the drawing block by block, never stretched)
     local y=lo
     while y<hi-.01 do
      local yt=math.min(hi,y+16)
      quad(b.v,b.i,{{ax,y,az},{bx,y,bz},{bx,yt,bz},{ax,yt,az}},uv,.78)
      y=yt
     end
    end
   end
  end
  -- (a jetty -- kind 'pier' -- is boards on posts with its own edges: closed down to the water by its
  -- own art it stood as a solid yellow block, user: "the chunky pier")
  if not setBack and shape.kind~='rail' and shape.kind~='cliff' and shape.kind~='caveWall' and shape.kind~='water' and shape.kind~='pier' and not c.stairs and shape.kind~='steps' and not shape.cyclingRoad and not flight and not (shape.kind=='ledge' and Outdoor.ownsFaces(c)) then
   -- Where a floor stands higher than its neighbour, the step is closed. A bridge deck (a
   -- walkway on elevation 15, or the same tile as one) is a thin plate of logs with an open
   -- underside; any other terrace face is its own tile repeated course by course, 1:1.
   local deck=isDeck(c)
   -- (FORTREE_V2: a Fortree forest cell's ground is its canopy floor, not its rated base: the step from it
   -- down to a path below was open - a slit of sky in the path behind the bushes - and toward another
   -- forest cell there is no step to close)
   local ftree=FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and shape.kind=='tree' and shape.canopy and not deck
   local base=ftree and (c.canopyBottom or base) or base
   -- (a sign or post standing on a deck is closed like the deck, not as a
   -- pillar of its own art down to the sea: Route 110's Cycling Road sign)
   if not deck and (c.collision or 0)~=0 then
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and (n.base or 0)==base and (isDeck(n) or (n.shape and n.shape.cyclingRoad=='deck')) then deck=true;break end
    end
   end
   local lowest,lowN
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
    -- a building standing in a cliff band (Lilycove's Center) leaves no cliff
    -- there: the terrace above closes its own face down to it, in the art of
    -- the nearest cliff cell of that row
    local inBand=n and n.civic and n.shape.kind=='cliff'
    if n and (n.shape.kind~='cliff' or inBand) and n.shape.kind~='caveWall' and n.shape.kind~='steps' and not n.stairs and not (ftree and n.shape.kind=='tree') then
     local low=n.base or 0
     -- (FORTREE_V2: a Fortree tree cell's ground lies on its forest floor (canopyBottom), whatever its rated base - the
     -- huts' floors at 32 beside the bushes closed nothing and floated over a void)
     if FORTREE_V2 and def and def.id=='EM_FORTREE_CITY' and n.shape.kind=='tree' and shape.kind~='tree' and n.cx>=0 and n.cy>=0
      and n.cx<def.midLayout.width and n.cy<def.midLayout.height then low=n.canopyBottom or 0 end
     local uv=uv
     if n.civic then
      -- (any building: a Lilycove house's roof cells are not cliff, and the
      -- grass tile stood as a green slab over it)
      for k=1,8 do for _,sx in ipairs({-k,k})do
       local q=cells[(n.cx+sx)..':'..n.cy]
       if q and q.shape and q.shape.kind=='cliff' and not q.civic then uv=uvFor(q.ts,q.mid) or uv;goto found end
      end end
      ::found::
     end
     if low<base then
      if not lowest or low<lowest then lowest,lowN=low,n end
      local ax,az=x+(d[1]>0 and 16 or 0),z+(d[2]>0 and 16 or 0)
      local bx,bz=ax+(d[1]==0 and 16 or 0),az+(d[2]==0 and 16 or 0)
      local function band(y0,y1,rows)
       -- (a secret base's Slide and Stand: a riser is one plain colour from
       -- the piece's own rim -- its frame, the chute's blue -- not the top art
       -- stretched down the side; furniture session, user: "do the slide and stand sides")
       if c.primary=='secret_base' then
        local px=RISER_PX[c.mid] or RISER_PX[0]
        local u=uv[1][1]+(uv[2][1]-uv[1][1])*(px[1]+.5)/16
        local v=uv[1][2]+(uv[3][2]-uv[1][2])*(px[2]+.5)/16
        quad(b.v,b.i,{{ax,y0,az},{bx,y0,bz},{bx,y1,bz},{ax,y1,az}},{{u,v},{u,v},{u,v},{u,v}},.78)
        return
       end
       -- rows: how many bottom rows of the tile this band shows (its height in pixels)
       local v0=uv[3][2]-(uv[3][2]-uv[1][2])*rows/16
       local vb=uv[3][2]
       quad(b.v,b.i,{{ax,y0,az},{bx,y0,bz},{bx,y1,bz},{ax,y1,az}},{{uv[1][1],vb},{uv[2][1],vb},{uv[2][1],v0},{uv[1][1],v0}},.78)
      end
      -- (relief floors, c.slope: the face between two sloped tops runs from the lower top's edge to the
      -- higher one's; where both meet - a smoothed edge - there is none)
      local cs,ns,e=c.slope or NO_SLOPE,n.slope or NO_SLOPE,SLOPE_EDGE[d[1]..':'..d[2]]
      local sloped=not deck and not ftree and c.primary~='secret_base' and low==(n.base or 0) and base==c.base
       and (cs[e[1]]~=0 or cs[e[2]]~=0 or ns[e[3]]~=0 or ns[e[4]]~=0)
      if deck and shape.planks then
       -- (planks stand on their own: no skirt of the tile's river art)
      elseif deck then
       local t=math.min(DECK_THICKNESS,base-low)
       band(base-t,base,t)
      elseif sloped then
       local ta,tb,ba,bb=base+cs[e[1]],base+cs[e[2]],low+ns[e[3]],low+ns[e[4]]
       if ta-ba>.01 or tb-bb>.01 then
        local vb,span=uv[3][2],uv[3][2]-uv[1][2]
        local va,vbb=vb-span*math.min(16,math.max(0,ta-ba))/16,vb-span*math.min(16,math.max(0,tb-bb))/16
        quad(b.v,b.i,{{ax,ba,az},{bx,bb,bz},{bx,tb,bz},{ax,ta,az}},{{uv[1][1],vb},{uv[2][1],vb},{uv[2][1],vbb},{uv[1][1],va}},.78)
       end
      else
       local y=low
       while y<base do
        local h=math.min(16,base-y)
        band(y,y+h,h);y=y+h
       end
      end
     end
    end
   end
   if deck and lowest then
    -- the underside of the planks, and the ground or water the bridge crosses
    local y=base-math.min(DECK_THICKNESS,base-lowest)
    quad(b.v,b.i,{{x,y,z+16},{x+16,y,z+16},{x+16,y,z},{x,y,z}},uv,.6)
    if lowN.shape.kind=='water' then
     plane(b.wv,b.wi,x,z,uvFor(ts,lowN.mid) or uv,.05)
    else
     plane(b.v,b.i,x,z,uvFor(ts,lowN.mid) or uv,lowest)
    end
   end
  end
  if kinds then
   local k=(shape and shape.kind or '?')..(c.mass and '+mass' or '')..((c.object or c.objectTop) and '+object' or '')..(c.prop and '+prop' or '')..(c.bldModel and '+bld' or '')
   local e=kinds[k] or {0,0};kinds[k]=e;e[1]=e[1]+os.clock()-kindT0;e[2]=e[2]+1
  end
 end
 local labWall={}
 for _,c in pairs(cells)do if c.secondary=='lab' and c.cy==0 and c.mid~=0 then
  local b=batches[c.pair];local uv=uvFor(c.ts,0x69)
  if uv and not labWall[c.cx] then
   labWall[c.cx]=true;local x=c.cx*16
   quad(b.v,b.i,{{x,32,32},{x+16,32,32},{x+16,16,32},{x,16,32}},uv)
   local u,t=(uv[1][1]+uv[2][1])*.5,uv[1][2]+(uv[3][2]-uv[1][2])*.8
   quad(b.v,b.i,{{x,16,32},{x+16,16,32},{x+16,0,32},{x,0,32}},swatch(c.ts,u,t))
  end
 end end
 -- Complete native wallpaper behind claimed furniture. The drawing's
 -- window/poster faces remain just in front; object claims must not leave
 -- rectangular holes in the wall finish.
 for _,c in pairs(cells)do if c.cy==0 and c.mid~=0 and c.mid~=8 then
  local house=c.pair=='player_house' or c.pair=='house'
  local shop=c.pair=='building__rom_082d4bcc'
  if house or shop then
   local b=batches[c.pair];local x=c.cx*16;local f=31.92
   local upper=uvFor(c.ts,house and 0x20 or 0x285)
   local lower=uvFor(c.ts,house and 0x28 or 0x285)
   if upper and lower then
    quad(b.v,b.i,{{x,32,f},{x+16,32,f},{x+16,16,f},{x,16,f}},upper)
    if shop then local u,v=lower[1][1],lower[3][2]-.001;lower=swatch(c.ts,u,v)end
    quad(b.v,b.i,{{x,16,f},{x+16,16,f},{x+16,0,f},{x,0,f}},lower)
   end
  end
 end end
 -- (a pixel-built piece repeated in a room - Fortree gym's 63 bushes and 130 stumps - is built once
 -- and its quads laid again for each copy, moved: the same recipe on the same tileset gives the same
 -- piece when the map cells it read round it (Furniture.sig) read the same for the copy. Without the
 -- JIT the gym's furniture alone held its first view two seconds.)
 local propMemo={}
 local function memoFor(p)
  for _,m in ipairs(propMemo[p.recipe] or {})do if m.ts==p.ts and m.pair==p.pair then
   local same=true
   for k,sig in pairs(m.reads)do
    local tx,ty=k:match('^(-?%d+):(-?%d+)$')
    if Furniture.sig(p,tonumber(tx),tonumber(ty))~=sig then same=false;break end
   end
   if same then return m end
  end end
 end
 for _,p in ipairs(props)do if not p.stageHidden then
  local b=batches[p.pair]
  local start,plantStart=#b.v,#b.pv
  local cutout=p.recipe.cutout
  local tv,ti=cutout and b.pv or b.v,cutout and b.pi or b.i
  local memo=p.recipe.kind=='pixel' and memoFor(p)
  if memo then
   local dx,dz=(p.cx-memo.cx)*16,(p.cy-memo.cy)*16
   -- (the copy's vertices written straight in: quad() would build its corner tables over again)
   local q=memo.quads
   for j=1,#q,4 do
    Budget.tick()
    local base,n=#tv,#ti
    for k=0,3 do local r=q[j+k];tv[base+k+1]={r[1]+dx,r[2],r[3]+dz,r[4],r[5],r[6]} end
    ti[n+1],ti[n+2],ti[n+3],ti[n+4],ti[n+5],ti[n+6]=base+1,base+2,base+3,base+1,base+3,base+4
   end
  else
   local rec=p.recipe.kind=='pixel' and {} or nil
   p.reads=rec and {} or nil
   Furniture.append(p,function(vertices,uv,shade,anchor)
    quad(tv,ti,vertices,uv,shade,anchor)
    if rec and (anchor or #vertices~=4) then rec=nil end   -- (a swaying card is not copied)
    if rec then
     local s=shade or 1
     for k=1,4 do local a,t=vertices[k],uv[k];rec[#rec+1]={a[1],a[2],a[3],t[1],t[2],s} end
    end
   end,uvFor)
   if rec then
    local l=propMemo[p.recipe] or {};propMemo[p.recipe]=l
    if #l<8 then l[#l+1]={ts=p.ts,pair=p.pair,cx=p.cx,cy=p.cy,quads=rec,reads=p.reads} end
    p.reads=nil
   end
  end
  Elevation.lift(b.v,start,p.groundHeight or 0,setBack);Elevation.lift(b.pv,plantStart,p.groundHeight or 0,setBack)
 end end
 cache.civics={}
 for _,g in ipairs(civics)do if not g.stageHidden then
  local vertices,indices={},{}
  Civic.append(g,function(v,t,shade)quad(vertices,indices,v,t,shade)end)
  Elevation.lift(vertices,0,g.groundHeight or 0,setBack)
  local part={};cache.civics[#cache.civics+1]=part
  part.mesh=assert(R.newMesh(vertices,indices));part.image=Civic.material(g)
  -- (the glass shine waits for the full build: finding the panes of every building's picture was a large
  -- share of Rustboro's first view without the JIT, and the full build follows within a second)
  if not firstArea then part.panes=V.require('GlassMask').civic(g,part.image) end
  Budget.check()
 end end
 mark('cellgeo+civic')
 cache.buildingModels={}
 for _,bld in ipairs(bldModels or {})do
  local m=BuildingModels.mesh(bld,cells)
  if m and bld.voxels then CamClear.addModel(cache.solid,bld.voxels.quads,bld.cx*16,bld.groundHeight or 0,(bld.cy+bld.depth)*16,Budget.tick)end
  if m and not firstArea then m.panes=V.require('GlassMask').building(m,cells,bld)end   -- (see the civics above)
  if m then cache.buildingModels[#cache.buildingModels+1]=m end
  Budget.check()
 end
 mark('bldmesh '..#(bldModels or {}))
 for _,p in ipairs(chimneys)do if not VoxelBuildings.enabled and not BattleClear.hits(cam,p.cx*16,p.cy*16,p.cx*16+16,p.cy*16+16)then
  local b=batches[p.pair];local start=#b.rv
  Roof.appendChimney(p,function(vertices,uv,shade)quad(b.rv,b.ri,vertices,uv,shade)end,uvFor)
  local c=cells[p.cx..':'..p.cy];Elevation.lift(b.rv,start,c and c.base or 0,setBack)
 end end
 for _,b in pairs(batches)do
  local part={pair=b.pair,secondary=b.secondary,roofMids=b.roofMids}
  -- A connected tileset can contribute only water, roofs or foliage at the
  -- edge of FAR/FULL range. Empty ground is valid, not a failed GPU upload.
  -- Transfer each successful upload immediately so recovery can release it.
  cache.parts[#cache.parts+1]=part
  local function upload(name,vertices,indices,format)
   if #vertices==0 then return end
   local mesh,err=R.newMesh(vertices,indices,format)
   assert(mesh,('field mesh %s/%s (%d vertices): %s'):format(b.pair,name,#vertices,tostring(err or 'unavailable')))
   part[name]=mesh
   Budget.check()
  end
  CamClear.addQuads(cache.solid,b.v,b.i,b.deckV,Budget.tick)
  -- quads drawn only with the over-player art (Gen3LeagueGate) leave the under pass
  if #b.underSkip>0 then
   local skip={};for _,base in ipairs(b.underSkip)do skip[base]=true end
   local keep={}
   for k=1,#b.i,6 do
    local first=math.min(b.i[k],b.i[k+1],b.i[k+2],b.i[k+3],b.i[k+4],b.i[k+5])-1
    if not skip[first] then for j=0,5 do keep[#keep+1]=b.i[k+j] end end
   end
   upload('under',b.v,keep);part.underIdx=keep
  else upload('under',b.v,b.i);part.underIdx=b.i end
  if #b.deckV>0 then part.deckV=b.deckV end
  upload('roof',b.rv,b.ri)
  upload('canopy',b.cv,b.ci)
  if (#b.skipOver>0 or #b.underSkip>0) and #b.v>0 then
   -- same vertices, indices without the flagged ground quads (a quad's vertices are consecutive and its six
   -- indices are base+1..base+4 in the pattern 1,2,3,1,3,4)
   local skip={}
   for _,base in ipairs(b.skipOver)do skip[base]=true end
   local keep={}
   local n=#b.i
   for k=1,n,6 do
    local first=math.min(b.i[k],b.i[k+1],b.i[k+2],b.i[k+3],b.i[k+4],b.i[k+5])-1
    if not skip[first] then for j=0,5 do keep[#keep+1]=b.i[k+j] end end
   end
   upload('over',b.v,keep);part.overIdx=keep
  end
  upload('plants',b.pv,b.pi,R.TREE_FORMAT)
  part.waters={};local levels={}
  for j=1,#b.wv,4 do
   -- (each water quad reaches a hair past its edges: patches on slightly different levels - shallows
   -- over the deep sea - met edge to edge and left hairline cracks at a low eye, Routes 105-128)
   local q1,q3=b.wv[j],b.wv[j+2]
   local mx,mz=(q1[1]+q3[1])/2,(q1[3]+q3[3])/2
   for k=0,3 do local v=b.wv[j+k]
    v[1]=v[1]+(v[1]>mx and WATER_LAP or v[1]<mx and -WATER_LAP or 0)
    v[3]=v[3]+(v[3]>mz and WATER_LAP or v[3]<mz and -WATER_LAP or 0)
   end
   local h=b.wv[j][2];local group=levels[h]
   if not group then group={v={},i={}};levels[h]=group end
   local base=#group.v
   for k=0,3 do group.v[#group.v+1]=b.wv[j+k]end
   for _,k in ipairs({1,2,3,1,3,4})do group.i[#group.i+1]=base+k end
  end
  for h,g in pairs(levels)do
   local mesh=assert(R.newMesh(g.v,g.i));part.waters[#part.waters+1]={mesh=mesh,height=h};Budget.check()
  end
 end
 mark('geometry')
 cache.treeInstances={}
 V.require('NativeTreeArt').buildInstances(treeGroups,leaf,li,cache.treeInstances)
 cache.wood=R.newMesh(wood,wi);Budget.check();cache.leaves=R.newMesh(leaf,li)
 V.require('Gen3Lamp').finish(cache,lampNight)
 cache.terrainKey=SceneCache.key(regions,x0,z0,x1,z1,Tiles._pairs,cam)
 return cache
end
local SCENE_FIELDS={'sceneDef','distance','fadeExtent','fillCounts','forestTrees','gymCount','civicCount','stairCount','chimneyCount','propCount','cliffCount','objectCount'}
local function prepare(game,vw,vh,cam)
 local req=request(game,cam);if not req then return false end
 -- DEBUG WALK keeps one whole-map scene and nothing else: three of those is
 -- three times the geometry for return visits a debug walk does not need.
 local debugWalk=walkGate(cam)
 stream.capacity=debugWalk and 1 or 3
 -- A cold build is spread over frames: 8 ms a frame, or 30 ms while a fade
 -- covers the screen. Until the scene is ready, prepare returns false and the
 -- caller draws its flat map; an old map's scene is never drawn at this place.
 local same=stream.active~=nil and req.context~=nil and req.context==stream.context
 -- (the debug build is already the whole map: no small first area, and no
 -- upgrade pass behind it)
 local near=not debugWalk and M.NEAR and req.context and not same and not cam.battle
 -- (a scene kept from an earlier visit is shown at once, whole)
 if near then for _,e in ipairs(stream.kept)do if e.key==req.key and e.context==req.context then near=nil;break end end end
 if near then req=request(game,cam,M.NEAR) or req end
 -- (a first area stands trees in cheap and leaves the glass out; the same area is built whole next, in a
 -- few seconds, before the full build - which takes tens of seconds in a city at a stream's budget)
 if same and not near and not debugWalk and stream.active.firstAreaBuilt and not cam.battle then
  local r=request(game,cam,M.NEAR)
  if r then req=r;req.upgrade=true;req.key=req.key..'|whole' end
 end
 frames=frames+1
 local ready=true
 if req.context and not same then ready=tilesetsReady(req)end
 local scene
 if not ready and tileWait<TILE_WAIT then
  tileWait=tileWait+1
 else
  if ready then tileWait=0 end
  local Fade=require('src.ui.game3.fade')
  -- (a cold build holds the flat map on screen until it is done: at 8 ms a frame Rustboro stayed flat
  -- for 13 s; 40 ms keeps the game moving at about 20 fps and finishes in a third of that)
  -- (the first area on entering a map takes .12 s a frame: it is a few frames of a held screen, and at
  -- .04 s the frames' own drawing doubled the wait - Mossdeep's first view took 2.3 s, its build 0.9 s)
  -- (a debug whole-map build takes the held-screen slice too: the user asked
  -- for the preload before moving, so fewer, longer frames beat a longer wait)
  -- (a flight in the air takes a few ms a frame, never a stutter: Gen3FlyOver)
  local cold=M.flySlice or debugWalk and M.DEBUG_COLD or near and .120 or (Fade.active and (Fade.t or 0)>=8) and .060 or .040
  if M.flySlice and same and stream.active then
   -- (a flight in the air: the scene that stands keeps standing; its refinement builds wait for the landing)
   scene=stream.active
  else
   scene=stream:update(req.key,req.context,function(candidate,previous)return build(req,candidate,previous)end,(stream.active and stream.active.nearOnly) and M.NEAR_STREAM or M.STREAM,cold,
    function()
     local tiles=tileIdentity(req.regions)
     return SceneCache.key(req.regions,0,0,0,0,tiles,req.cam),SceneCache.key(req.regions,req.x0,req.z0,req.x1,req.z1,tiles,req.cam)..(req.upgrade and '|whole' or '')
    end)
  end
 end
 -- Native tileset construction binds its animation clock. Restore the live
 -- map after EVERY slice, including suspended scans of connected tilesets.
 -- Only a tileset already resident: Tiles.get would decode it on this frame.
 if Tiles._pairs[req.def.midLayout.pair]then Tiles.get(req.def.midLayout.pair)end
 M.prepares=stream.stats.started;M.builds=stream.stats.completed;M.cacheHits=stream.stats.hits
 if not scene then
  cache={}
  for _,name in ipairs(SCENE_FIELDS)do M[name]=nil end
  return false
 end
 if (near or req.upgrade) and stream.pending==nil and scene.nearOnly==nil then scene.nearOnly=true end
 cache=scene
 for _,name in ipairs(SCENE_FIELDS)do M[name]=cache[name]end
 return true
end
-- The window panes of one of a tileset's OWN atlases (GlassMask, scanned
-- from the atlas the tile was painted into), or nil for any other image.
-- Only atlas-textured meshes may consult the mask (see Voxel3D.glassMaskNow).
local function panesOf(ts,image)
 if not ts then return nil end
 return V.require('GlassMask').panes(ts,image)
end
-- First person: is the eye under something the 2D game draws over the player - a tree top it walks
-- behind? Then the player's cell carries over-layer art (48 px of it or more).
local overInk=setmetatable({},{__mode='k'})
local function ink(ts,mid)
 local t=overInk[ts];if not t then t={};overInk[ts]=t end
 if t[mid]==nil then
  local n=0
  local slot=ts.overImageData and ts.midToSlot and ts.midToSlot[mid]
  if slot then
   local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
   for y=0,15 do for x=0,15 do local _,_,_,a=ts.overImageData:getPixel(ox+x,oy+y);if a>.5 then n=n+1 end end end
  end
  t[mid]=n
 end
 return t[mid]
end
local function eyeUnderCrown()
 local def=M.sceneDef;if not def then return false end
 local Player=require('src.core.game3.player')
 local cx,cy=math.floor(((Player.px or 0)+8)/16),math.floor(((Player.py or 0)+8)/16)
 local ok,mid,pair,isVoid=pcall(Map.worldMidAt,cx,cy,def)
 if not ok or not mid or isVoid then return false end
 local ts=Tiles._pairs[pair]
 return ts~=nil and ink(ts,mid)>=48
end
local function terrain(draw)
 local original=draw
 -- the panes the shader is reading now: false until the first draw sets them
 local lit=false
 local function draw(mesh,image,panes)
  -- every mesh sets its own panes (nil for a non-atlas image), so a sprite
  -- or a sheet drawn after this never inherits a tileset's windows
  if original==R.draw and panes~=lit then R.glassMaskNow(panes);lit=panes end
  local previous=R.surfaceDetail
  R.surfaceDetail=TreeStyle.surfaces:get()=='detailed'
  local ok,err=pcall(original,mesh,image)
  R.surfaceDetail=previous
  if not ok then error(err,0)end
 end
 -- tree crowns in first person open round the eye (Voxel3D's nearCut; never in the shadow pass),
 -- only while the eye stands under one (a hedge walked past stays whole)
 local under=original==R.draw and V.require('Gen3Integration').level==6 and not V.require('CamControl').battleLive() and eyeUnderCrown()
 local function crowns(mesh,image)
  R.nearCut=under and 20 or nil
  local ok,err=pcall(draw,mesh,image)
  R.nearCut=nil
  if not ok then error(err,0)end
 end
 for _,p in ipairs(cache.parts)do
  -- Always bind the current native image: animations and palette updates stay live.
  local ts=Tiles._pairs[p.pair]
  if ts then
   if p.deckV and p.under and p.underIdx then M.deckCut(p) end
   draw(p.under,ts.image,panesOf(ts,ts.image))
   -- A metatile's visible roof/sign artwork may live entirely in BG2.
   -- Apply both native layers to the SAME shaped surface, not just the floor.
   if ts.overImage then draw(p.over or p.under,ts.overImage,panesOf(ts,ts.overImage))end
   -- (canopies, plants and roofs never take panes: only walls and doors do)
   if p.canopy then draw(p.canopy,ts.overImage or ts.image)end
   if p.plants then local img=Outdoor.image(ts,math.floor((require('src.core.game3.tileset_anim').counter or 0)/16)) or ts.image;draw(p.plants,img)end
   if p.roof then
    local material=Roof.image(ts,p.secondary,Shapes.of,p.roofMids)
    draw(p.roof,material or ts.image)
    if not material and ts.overImage then draw(p.roof,ts.overImage)end
   end
  end
 end
 for _,part in ipairs(cache.civics or {})do draw(part.mesh,part.image,part.panes)end
 for _,bld in ipairs(cache.buildingModels or {})do draw(bld.mesh,bld.image,bld.panes)end
 draw(cache.wood,bark);crowns(cache.leaves,TreeStyle.original() and V.require('NativeTreeArt').image() or foliage)
 for _,batch in ipairs(cache.treeInstances or {})do crowns(batch,V.require('NativeTreeArt').image())end
 if original==R.draw and lit then R.glassMaskNow(nil);lit=nil end
end
local function waterMeshes()
 local out={}
 for _,p in ipairs(cache.parts)do
  local ts=Tiles._pairs[p.pair]
  if ts then for _,water in ipairs(p.waters or {})do out[#out+1]={water.mesh,ts.image,nil,water.height}end end
 end
 return out
end
local reflectPlane
local dustMesh,dustImage
local function rideDust(game,cam)
 local exports=game and game.mods and game.mods.exports
 local ride=exports and exports.DRAMATIC_SKY_RIDE
 if not (ride and type(ride.groundParticles)=='function')then return end
 local ok,particles=pcall(ride.groundParticles)
 if not ok or type(particles)~='table' or #particles==0 then return end
 if not dustMesh then
  local v,i={},{}
  quad(v,i,{{-1,2,0},{1,2,0},{1,0,0},{-1,0,0}},{{0,0},{1,0},{1,1},{0,1}})
  dustMesh=R.newMesh(v,i)
  local data=love.image.newImageData(1,1);data:setPixel(0,0,.72,.62,.43,1)
  dustImage=love.graphics.newImage(data)
 end
 if not dustMesh then return end
 for _,p in ipairs(particles)do
  if type(p.x)=='number' and type(p.z)=='number' then
   local t=math.max(0,math.min(1,(tonumber(p.age)or 0)/math.max(.001,tonumber(p.life)or .4)))
   local model=Mat.mul(Mat.translate(p.x,M.groundAt(p.x,p.z)+.3+t*3,p.z),
    Mat.mul(Mat.rotateY(cam.level>=6 and -cam.yaw or 0),Mat.scale(1-t,1-t,1)))
   R.draw(dustMesh,dustImage,model)
  end
 end
end
-- Thickness of overworld figures in world units (0 = flat cards).
M.ACTOR_DEPTH=2
-- Fraction of the camera pitch a figure leans back by (0 = upright cards).
M.ACTOR_LEAN=.55
-- objects the cartridge draws as a mark lying on the ground or water, not a figure standing up
-- (the submarine's dithered shadow under Aqua Hideout's water stood in the air as a dark slab)
M.FLAT_GFX={[141]=true}
local flatMeshes={}
-- A mesh from a vertex table. love.graphics.newMesh(format,table) stalls about 20 ms a call whatever the size (measured
-- in QA, tools/fly/em_meshbench_driver.lua); a mesh made from a count and then filled takes about a millisecond.
function M.fastMesh(verts,map)
 if #verts==0 then return nil end
 local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,#verts,'triangles','static')
 if not ok then return nil end
 if not pcall(mesh.setVertices,mesh,verts) then mesh:release();return nil end
 if map and #map>0 and not pcall(mesh.setVertexMap,mesh,map) then mesh:release();return nil end
 return mesh
end
-- One frame of a drawing as a card with a body (cached per frame); nil where the sheet has no such frame.
local function cardMesh(spr,frame,mirror)
 local q=spr.quads[frame];if not q then return end
 local padding=SpriteAnchor.framePadding(spr,frame)
 local key=tostring(spr)..':'..tostring(spr.image)..':'..frame..':'..tostring(mirror)..':'..padding
 local mesh=spriteMeshes[key]
 if not mesh then
  local qx,qy,qw,qh=q:getViewport();local iw,ih=spr.image:getDimensions()
  local l,r=qx/iw,(qx+qw)/iw;if mirror then l,r=r,l end
  local v,i={},{}
  -- Shift in local card space so lean, free-camera yaw and reflection all
  -- share the same visible baseline. Transparent padding belongs to this displayed frame.
  quad(v,i,{{-qw/2,qh-padding,0},{qw/2,qh-padding,0},{qw/2,-padding,0},{-qw/2,-padding,0}},{{l,qy/ih},{r,qy/ih},{r,(qy+qh)/ih},{l,(qy+qh)/ih}})
  -- Give the figure a body: a back face and a rim of side quads along the
  -- drawing's silhouette, each the colour of its own edge pixel, so a card
  -- seen from an angle reads as a thin carved figure instead of paper.
  local D=M.ACTOR_DEPTH
  if D>0 and spr.imageData then
   quad(v,i,{{qw/2,qh-padding,-D},{-qw/2,qh-padding,-D},{-qw/2,-padding,-D},{qw/2,-padding,-D}},{{r,qy/ih},{l,qy/ih},{l,(qy+qh)/ih},{r,(qy+qh)/ih}},.9)
   local data=spr.imageData
   local function solid(px,py)
    if px<0 or py<0 or px>=qw or py>=qh then return false end
    local ok,_,_,_,a=pcall(data.getPixel,data,qx+px,qy+py)
    return ok and (a or 0)>.5
   end
   for py=0,qh-1 do for px=0,qw-1 do
    if solid(px,py) then
     local sx=mirror and (qw-1-px) or px
     local x0,x1=-qw/2+sx,-qw/2+sx+1
     local y1,y0=qh-padding-py,qh-padding-py-1
     local u,t=(qx+px+.5)/iw,(qy+py+.5)/ih
     local c={{u,t},{u,t},{u,t},{u,t}}
     if not solid(px-1,py) then local ex=mirror and x1 or x0
      quad(v,i,{{ex,y1,0},{ex,y1,-D},{ex,y0,-D},{ex,y0,0}},c,.8) end
     if not solid(px+1,py) then local ex=mirror and x0 or x1
      quad(v,i,{{ex,y1,-D},{ex,y1,0},{ex,y0,0},{ex,y0,-D}},c,.8) end
     if not solid(px,py-1) then quad(v,i,{{x0,y1,0},{x1,y1,0},{x1,y1,-D},{x0,y1,-D}},c,.95) end
     if not solid(px,py+1) then quad(v,i,{{x0,y0,-D},{x1,y0,-D},{x1,y0,0},{x0,y0,0}},c,.7) end
    end
   end end
  end
  mesh=M.fastMesh(v,i);spriteMeshes[key]=mesh
 end
 return mesh
end
M.cardMesh=cardMesh
local function actor(gid,x,z,facing,phase,flip,opts,cam,draw)
 -- Neighbor snapshots may cover much farther than the rendered terrain.
 -- Do not leave those actors floating in the sky beyond its visible edge.
 if not (cache.cells and cache.cells[math.floor((x+8)/16)..':'..math.floor((z+8)/16)]) then return end
 local spr=Sprites.getDraw(gid);if not spr then return end
 if M.FLAT_GFX[tonumber(gid) or -1] then
  if draw==Shadow.draw or reflectPlane then return end
  local frame=Sprites.pose(spr,'down',0,false,opts)
  local q=spr.quads[frame] or spr.quads[0];if not q then return end
  local key=tostring(spr.image)..':'..frame
  local mesh=flatMeshes[key]
  if not mesh then
   local qx,qy,qw,qh=q:getViewport();local iw,ih=spr.image:getDimensions()
   local v,i={},{}
   -- the drawing laid flat, its top row to the north, its bottom row on the object's cell
   quad(v,i,{{-qw/2,0,-qh},{qw/2,0,-qh},{qw/2,0,0},{-qw/2,0,0}},{{qx/iw,qy/ih},{(qx+qw)/iw,qy/ih},{(qx+qw)/iw,(qy+qh)/ih},{qx/iw,(qy+qh)/ih}})
   mesh=R.newMesh(v,i);flatMeshes[key]=mesh
  end
  local floor=M.groundAt(x+8,z+16-.001,opts.elevation)
  local c=cache.cells[math.floor((x+8)/16)..':'..math.floor((z+8)/16)]
  if c and c.shape and c.shape.kind=='water' then floor=c.base or floor end
  draw(mesh,spr.image,Mat.translate(x+8,floor+.15,z+16),0)
  return
 end
 if M.logActors then
  local k=tostring(gid)..':'..math.floor(x/16)..':'..math.floor(z/16)
  if not M.logActors[k] then M.logActors[k]=true;print('[EM actor]',gid,math.floor(x/16),math.floor(z/16),spr.quads and spr.quads[0] and select(3,spr.quads[0]:getViewport()),spr.quads and spr.quads[0] and select(4,spr.quads[0]:getViewport())) end
 end
 -- A landmark whose drawing describes a solid is built as one: it has real
 -- depth, so it never turns to face the camera and never leans back with it.
 local solid=Landmarks.mesh(gid,spr) or RockSprites.mesh(gid,spr)
 local mesh=solid
 if not solid then
  -- View-relative artwork keeps the actor facing its world heading while the
  -- camera turns; this changes the sampled frame, never the entity direction.
  facing=V.require('Gen3Integration').worldDirection(facing,-(cam.level>=6 and cam.yaw or 0))
  local frame,mirror=Sprites.pose(spr,facing,phase,flip,opts)
  mesh=cardMesh(spr,frame,mirror);if not mesh then return end
 end
 local yaw=solid and 0 or (cam.level>=6 and -cam.yaw or 0)
 local floor=M.groundAt(x+8,z+16-.001,opts.elevation)
 -- (on a stepped deck a character stands as far south of its cell as the deck is lifted, Gen3Decks)
 local setBack=(M.sceneDef and Decks.MAPS[M.sceneDef.id or '']) and floor or 0
 local contact=cache.cells[math.floor((x+8)/16)..':'..math.floor((z+8)/16)]
 if contact and contact.prop then floor=contact.prop.groundHeight or floor end
 floor=floor+Furniture.flightHeight(cache.cells,x+8,z+8)
 local height=floor+(opts.lift or 0)
 if draw~=Shadow.draw and not reflectPlane and (opts.depthOffset or 0)==0 then
  V.require("ActorContact").draw(x+8,z+16+setBack-(solid and Landmarks.SCALE[tonumber(gid) or 0] and 8 or 0),floor,height-floor,spr.width*(solid and Landmarks.SCALE[tonumber(gid) or 0] or 1))
 end
 -- HD-2D stance: tip the figure back toward the camera by part of the
 -- pitch, pivoting at the feet, so it stands IN the ground plane instead of
 -- being a vertical cutout the camera looks down on. The shadow is still
 -- cast from the upright pose below.
 local viewAngle=cam.level>=6 and (cam.pitch or 0) or (V.require('VoxelState').angle or 0)
 -- a modelled solid (a landmark) is a real object standing on the ground:
 -- it never leans back like a card does
 local lean=((opts.upright or solid) and 0 or M.ACTOR_LEAN)*viewAngle
 local pose=lean~=0 and Mat.mul(Mat.rotateY(yaw),Mat.rotateX(-lean)) or Mat.rotateY(yaw)
 local base=Mat.mul(Mat.translate(x+8,height,z+16+setBack+(opts.depthOffset or 0)),pose)
 -- (a landmark model may be built larger than its sprite is drawn: the moving van)
 local grow=solid and Landmarks.SCALE[tonumber(gid) or 0]
 if grow then pose=Mat.mul(pose,Mat.scale(grow,grow,grow));base=Mat.mul(base,Mat.scale(grow,grow,grow)) end
 -- Use the shared GB actor contact correction. Terrain retains its full
 -- acne margin; the visible lookup must use the identical snugged caster.
 local caster=Shadow.snug(base)
 if reflectPlane then height=2*reflectPlane-height+V.require('Water').CAST_RAISE end
 local model=reflectPlane and Mat.mul(Mat.translate(x+8,height,z+16+setBack+(opts.depthOffset or 0)),pose) or base
 if reflectPlane then model=Mat.mul(model,Mat.scale(1,-1,1))end
 if draw==Shadow.draw then
  draw(mesh,spr.image,caster)
 else
  -- A leaning card set against a truck, a ridge or a fence would slice into
  -- it; a small camera-ward pull keeps the whole figure in front of what it
  -- stands beside without lifting it over what it stands behind.
  draw(mesh,spr.image,model,solid and 0 or (opts.pull or 7),caster)
 end
end
-- Diagnostics for the building audit (tools/em_views_driver.lua EM_DUMP).
-- QA: the raw scene cell (its tileset, uv slot), for probe drivers
function M.debugTimes()return cache.buildTimes end
function M.debugRaw(cx,cy)return cache.cells and cache.cells[cx..':'..cy] end
function M.debugCell(cx,cy)
 local c=cache.cells and cache.cells[cx..':'..cy];if not c then return nil end
 local col=c.column
 return {mid=c.mid,kind=c.shape and c.shape.kind,collision=c.collision,
  prop=c.prop and (c.prop.recipe and c.prop.recipe.name or 'prop') or nil,stairs=c.stairs and true or nil,
  civic=c.civic and true or nil,gym=c.gym and true or nil,
  col=col and {first=col.first,last=col.last,roofs=col.roofs,walls=col.walls,height=col.height,roofType=col.roofType,group=col.groupId,
   wallTop=col.wallTop,artRows=col.artRows,front=col.front,back=col.back,indoor=col.indoor,
   left=col.group and col.group.left,right=col.group and col.group.right,
   gfront=col.group and col.group.front,gback=col.group and col.group.back,id=col.group and col.group.id} or nil,
  base=c.base}
end
-- The cell box (x0,z0,x1,z1, inclusive) the live scene is built over, or nil while none stands (Gen3FlyOver
-- lays flat ground everywhere else).
function M.builtBounds()return M.distance and M.distance.bounds or nil end
-- Is the scene of map `id` built and showing?
function M.readyFor(id)return M.sceneDef~=nil and M.sceneDef.id==id end
function M.groundAt(x,z,elev)
 for _,r in ipairs(cache.floorRegions or {})do
  local lx,lz=x-r.x*16,z-r.y*16
  if lx>=0 and lz>=0 and lx<r.w*16 and lz<r.h*16 then
   -- (an actor on the ground layer (e3, or the sea's e1) passes UNDER a cell the cartridge rates e15: Route 110's
   -- Cycling Road crossing the land; only an actor on layer 4 stands on the deck. elev=nil: the deck's height)
   if elev==3 or elev==1 then
    local dc=cache.cells and cache.cells[(r.x+math.floor(lx/16))..':'..(r.y+math.floor(lz/16))]
    if dc and dc.shape and dc.shape.cyclingRoad=='deck' then return r.floorOffset or 0 end
   end
   return V.require('TerrainLevels').at(r.floorField,lx,lz)+(r.floorOffset or 0)
  end
 end
 return 0
end
-- A player on the ground layer walking under Route 110's Cycling Road would stand hidden behind the slab from the
-- tilted camera: while one is within a cell of a deck cell, the deck cells within 4 cells of the player are left out
-- of the mesh (its vertex map is rebuilt when the player's cell changes; the full map comes back when they leave).
function M.deckCut(p)
 local e=Player.elevation
 local pcx,pcy=math.floor(((Player.px or 0)+8)/16),math.floor(((Player.py or 0)+8)/16)
 local want
 if e~=4 then
  for _,r in ipairs(p.deckV)do if math.abs(r[1]-pcx)<=1 and math.abs(r[2]-pcy)<=1 then want=pcx..':'..pcy;break end end
 end
 if want==p.cutKey then return end
 p.cutKey=want
 local function apply(mesh,idx,cut)
  if not mesh then return end
  if not cut then mesh:setVertexMap(idx);return end
  local map,n={},0
  for k=1,#idx,6 do
   if not cut[idx[k]] then for j=0,5 do n=n+1;map[n]=idx[k+j] end end
  end
  mesh:setVertexMap(map)
 end
 if not want then apply(p.under,p.underIdx);apply(p.over,p.overIdx);return end
 local cut={}
 for _,r in ipairs(p.deckV)do if math.abs(r[1]-pcx)<=4 and math.abs(r[2]-pcy)<=4 then for v=r[3],r[4]do cut[v]=true end end end
 apply(p.under,p.underIdx,cut);apply(p.over,p.overIdx,cut)
end
local function actors(game,cam,draw)
 if cam.replay then
  local frame=cam.replay.frame
  for _,a in ipairs(frame.actors or {})do
   if a.graphicsId and not (a.id==255 and cam.level==6) then
    local support,offset=Furniture.support(cache.cells,a.graphicsId,a.x,a.y,(a.walkPhase or 0)==0)
    local z=a.id==255 and frame.y or a.y
    actor(a.graphicsId,a.x,z,a.facing,a.walkPhase,a.stepFlip,
     {frame=a.frame,bow=a.bow,fieldMove=a.fieldMove,depthOffset=offset or 0,lift=support+(z-a.y)},cam,draw)
   end
  end
  return
 end
 local space=package.loaded['src.core.game3.scripting.space']
 local Fly=V.require('Gen3FlyOver')
 local flying=Fly.active()
 for _,eo in ipairs(Objects.forDraw())do if not (flying and eo.mon and Fly.hidesFollowers())then
  local gid=eo.graphicsId or (eo.def and (eo.def.graphicsId or eo.def.graphics))
  if space and space.resolveObjectGraphicsId and eo.def then gid=space.resolveObjectGraphicsId(eo.def) or gid end
  local support,depthOffset=Furniture.support(cache.cells,gid,eo.px or eo.cellX*16,eo.py or eo.cellY*16,not eo.moving)
  actor(gid,(eo.px or eo.cellX*16)+(eo.raiseX or 0),eo.py or eo.cellY*16,
   eo.facing or 'down',Objects.walkPhase(eo),eo.stepFlip,
   {bow=(eo.bowFrames or 0)>0 or eo.raiseHand,elevation=eo.elevation,frame=eo.customFrame,upright=tonumber(gid)==92 or tonumber(gid)==94,depthOffset=depthOffset or 0,lift=support-(eo.raiseY or 0)},cam,draw)
 end end
 -- Connected maps use the engine's ghost snapshots; never advance those
 -- actors here (doing that per render would reintroduce fast wandering NPCs).
 local Ghosts=require('src.core.game3.ghosts')
 for _,entry in ipairs(Map.world or {})do
  if entry.id~=Map.current then
   local live=Ghosts.forDraw(entry.id)
   if live then
    for _,eo in ipairs(live)do
     actor(eo.graphicsId or (eo.def and (eo.def.graphicsId or eo.def.graphics)),
      (eo.px or eo.cellX*16)+entry.ox*16,(eo.py or eo.cellY*16)+entry.oy*16,
      eo.facing or 'down',Objects.walkPhase(eo),eo.stepFlip,{},cam,draw)
    end
   else
    local event=space and space.bundle and space.bundle.events and space.bundle.events[entry.id]
    local defs=event and (event.objects or event.objectEvents) or entry.def.objects or {}
    local bounds=Objects.layoutBounds(entry.def)
    for _,obj in ipairs(defs)do
     local x,y=tonumber(obj.x) or 0,tonumber(obj.y) or 0
     local visible=not obj.flag or obj.flag==0 or (space and space.objectVisible and space.objectVisible(obj))
     if visible and (not bounds or (x>=0 and y>=0 and x<bounds.w and y<bounds.h)) then
      actor(obj.graphicsId or obj.graphics,(entry.ox+x)*16,(entry.oy+y)*16,
       tostring(obj.facing or 'down'):lower(),0,false,{},cam,draw)
     end
    end
   end
  end
 end
 if cam.level~=6 and Player.isVisible() and not (flying and Fly.hidesPlayer()) then
  actor(Sprites.playerGraphicsId(game),(Player.px or 0)+(Player.spriteXOffset or 0),Player.py or 0,
   Player.facing,Player.walkPhase(),Player.drawFlip(),
   {fieldMove=(Player.fieldMoveAnim or 0)>0,elevation=Player.elevation,lift=-(Player.spriteYOffset or 0)-(Player.jumpSpriteY and Player.jumpSpriteY()or 0)},cam,draw)
 end
end
-- Project the engine-owned door/healing frames into the existing 3D room.
-- Reading/drawing these effects never advances their timers or script state.
local effectCanvases={}
local function fieldEffects(draw,cam)
 local g=love.graphics
 local function effect(name,w,h,paint,verts,base)
  local c=effectCanvases[name]
  if not c then c=g.newCanvas(w,h);c:setFilter('nearest','nearest');effectCanvases[name]=c end
  g.push('all');g.setCanvas(c);g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setBlendMode('alpha');g.clear(0,0,0,0);g.setColor(1,1,1,1)
  local ok,err=pcall(paint);g.pop();if not ok then error(err,0)end
  local v,i={},{};quad(v,i,verts,{{0,0},{1,0},{1,1},{0,1}})
  Elevation.lift(v,0,base or 0)
  local mesh=R.newMesh(v,i);draw(mesh,c);mesh:release()
 end
 local fx=require('src.core.game3.field_effects')
 for i,a in ipairs(fx._anims or {})do if a.kind=='dust' then
  local x,z=a.cx*16,a.cy*16
  local yaw=cam and cam.level>=6 and cam.yaw or 0
  local dx,dz=8*math.cos(yaw),8*math.sin(yaw)
  effect('landing-dust-'..i,16,8,function()fx.drawFront(x,z+8,nil)end,
   {{x+8-dx,8,z+16-dz},{x+8+dx,8,z+16+dz},{x+8+dx,0,z+16+dz},{x+8-dx,0,z+16-dz}},M.groundAt(x+8,z+16-.001))
 end end
 -- emote bubbles: a small card over the character's head, facing the camera
 for i,a in ipairs(fx._anims or {})do if a.kind=='emote' then
  local sheet=fx._sheets and fx._sheets[a.sheet or 'emoticons']
  local q=sheet and sheet.quads and sheet.quads[a.frame]
  local t=a.targetObj
  if q and t then
   local x=t.px or (t.cellX and t.cellX*16) or (t.x and t.x*16) or 0
   local z=t.py or (t.cellY and t.cellY*16) or (t.y and t.y*16) or 0
   local yaw=cam and cam.level>=6 and cam.yaw or 0
   local dx,dz=8*math.cos(yaw),8*math.sin(yaw)
   local lift=24-(a.yOffset or 0)
   local ground=M.groundAt(x+8,z+16-.001)
   local back=(M.sceneDef and Decks.MAPS[M.sceneDef.id or '']) and ground or 0
   local zz=z+15+back
   effect('emote-'..i,16,16,function()g.draw(sheet.image,q,0,0)end,
    {{x+8-dx,lift+16,zz-dz},{x+8+dx,lift+16,zz+dz},{x+8+dx,lift,zz+dz},{x+8-dx,lift,zz-dz}},ground)
  end
 end end
 local doors=require('src.core.game3.doors');local a=doors._activeAnim
 if a then
  local x,z=a.x*16,a.y*16+16.15
  effect('door',32,48,function()doors.draw(x,a.y*16-32,32,48)end,
   {{x,48,z},{x+32,48,z},{x+32,0,z},{x,0,z}},M.groundAt(x+8,z))
 end
 local heal=require('src.core.game3.pokecenter_heal')
 if heal.isActive()then
  local prop,screen
  for _,c in pairs(cache.cells or {})do if c.prop then
   if c.prop.recipe.name=='center_healer'then prop=c.prop end
   if c.prop.recipe.name=='center_screen'then screen=c.prop end
  end end
  if prop then
   local x,z,h=prop.cx*16,prop.cy*16,prop.recipe.h+.18+(prop.groundHeight or 0)
   effect('heal-balls',32,24,function()g.translate(-80,-28);heal.drawBalls()end,
    {{x+3,h,z+12},{x+29,h,z+12},{x+29,h,z+28},{x+3,h,z+28}})
   if screen then
    local sx,sz=screen.cx*16,screen.cy*16+(screen.recipe.frontOffset or 32.2)+.04
    effect('heal-monitor',32,16,function()g.translate(-112,-16);heal.drawMonitor()end,
     {{sx+2,28,sz},{sx+30,28,sz},{sx+30,12,sz},{sx+2,12,sz}},screen.groundHeight or 0)
   end
  end
 end
end
function M.restore()
 R.battleOcclusion(nil)
 R.fog=nil
 R.interior=nil
 R.tint={1,1,1}
 reflectPlane=nil
 if saved then
  pcall(R.endScene);love.graphics.pop();love.graphics.setCanvas(savedCanvas)
  saved,savedCanvas=false,nil
 end
end
function M.draw(game,vw,vh,cam)
 -- a Fly flight keeps drawing (sky, flat ground, rider, clouds) while the scene under it is not built, and
 -- builds the destination in thin slices (Gen3FlyOver)
 local Fly=V.require('Gen3FlyOver')
 local flying=Fly.active() and not cam.battle and not cam.replay
 M.flySlice=flying and Fly.slice() or nil
 local built=prepare(game,vw,vh,cam)
 if not built and not flying then return false end
 materials()
 -- Script camera panning belongs to the flat renderer. It must not move the
 -- first-person eye or pull the user's orbit away during dialogue/replays.
 local focus=cam.replay and cam.replay.frame or Player
 local cx,cz=(focus.px or focus.x or 0)+8,(focus.py or focus.y or 0)+8
 if cam.battle and cam.center then cx,cz=cam.center[1],cam.center[2]end
 if flying then cx,cz=Fly.focus()end
 -- (a stepped deck: the low and orbit cameras follow the player set back
 -- with it; the player's camera looks at the ground plane, where a point
 -- lifted and set back alike shows where it is drawn)
 local camBack=0
 if cam.level>=6 and not flying and M.sceneDef and Decks.MAPS[M.sceneDef.id or ''] and not cam.battle then camBack=M.groundAt(cx,cz+8-.001);cz=cz+camBack end
 local width,height=love.graphics.getCanvas():getDimensions()
 local Renderer=require('src.render.Renderer')
 local Display=require('src.core.game3.display')
 local override=Renderer.setWorldOverride and Renderer.frameRects and not Display.planesBroken
 if override then
  local rect=Renderer:frameRects()
  width=math.max(1,math.floor(rect.vuw*rect.dpiX+.5))
  height=math.max(1,math.floor(rect.vuh*rect.dpiY+.5))
 end
 M.renderWidth,M.renderHeight=width,height
 local Options=V.require('Gen3SceneOptions')
 local renderWidth,renderHeight=Options.expand(width,height)
 local def=M.sceneDef or Map.currentDef()
 if not def then return false end
 local indoor
 if Pairs.outdoor then indoor=not Pairs.outdoor(def)
 else indoor=def.environment=='INDOOR' or def.mapType==8 or def.mapType==4 end
 if def.id and OPEN_SKY[def.id] then indoor=false end
 local nativeBackground=def.mapType==4 and {.045,.030,.034,1} or Interior.background
 local background=Options.environment(indoor,indoor and nativeBackground or {.60,.79,.82,1})
 local plate=cam.battle and cam.plate
 if plate then background=plate.color end
 local S=V.require('VoxelState')
 S.level=cam.level;S.angle=math.rad(S.ANGLES_DEG[cam.level+1] or 35)
 R.canopyFacing=cam.battle or cam.level>=6
 -- Original-art cards lean with the camera like the characters do; modelled
 -- trees are real volumes and stay upright.
 R.cardLean=(cam.level<6 and not cam.battle and not TreeStyle.voxel()) and M.ACTOR_LEAN*S.angle or 0
 if cam.level>=6 then
  local dist=cam.level==6 and 0 or 75
  local dx,dz=math.sin(cam.yaw),-math.cos(cam.yaw)
  local ground=M.groundAt(cx,cz-camBack+8-.001,Player.elevation)
  local ey=48+ground
  if cam.level==6 then
   ey=ground+SpriteAnchor.eyeHeight(Sprites.getDraw(Sprites.playerGraphicsId(game)))
     -(Player.spriteYOffset or 0)-(Player.jumpSpriteY and Player.jumpSpriteY()or 0)
  end
  local exports=game and game.mods and game.mods.exports
  local ride=exports and exports.DRAMATIC_SKY_RIDE
  if not cam.battle and not cam.replay and ride and type(ride.currentAltitude)=='function' then
   local ok,height=pcall(ride.currentAltitude)
   if ok and type(height)=='number' then ey=ey+math.max(0,math.min(512,height))end
  end
  -- the orbit arm stops short of solid scenery (a station, a plateau): shorter at once, back out slowly
  if dist>0 and not cam.battle and not cam.replay and not flying and cache.solid then
   local Clear=V.require('Gen3CamClear')
   dist=Clear.ease(camArm,Clear.arm(cache.solid,cx,cz,dx,dz,ey,dist),love.timer.getDelta(),90,cache)
  end
  local focusDistance=cam.level==6 and 24 or 70
  R.camera={eye={cx-dx*dist,ey,cz-dz*dist},focus={cx+dx*focusDistance,ey-focusDistance*math.tan(cam.pitch),cz+dz*focusDistance},fov=math.rad(62),curve=cam.level==6 and 0 or nil}
  if cam.battle then
   -- The battle camera: eye `dist` back from the arena centre and `height`
   -- above the ground, looking at a point `look` ahead of the centre at
   -- `lookY` above the ground. `fov` is the vertical lens in degrees. The
   -- defaults are the framing BB1b measured (the feet of both actors clear of
   -- the stat box and the move menu, the foe about 1.5x its old height); a
   -- caller may set cam.dist / cam.height / cam.look / cam.lookY / cam.fov.
   local bc={dist=80,height=24,look=36,lookY=-8,fov=38,pitchUnits=40}
   local dist=cam.dist or bc.dist
   -- the cuts' pitch lifts the eye (cam.pitch is .38 at rest, so rest is unchanged)
   local height=(cam.height or bc.height)+((cam.pitch or .38)-.38)*bc.pitchUnits
   local look,lookY=cam.look or bc.look,cam.lookY or bc.lookY
   R.camera={eye={cx-dx*dist,ground+height,cz-dz*dist},focus={cx+dx*look,ground+lookY,cz+dz*look},fov=math.rad(cam.fov or bc.fov)}
  end
 else
  R.camera=Interior.camera(Interior.forMap(def,3),S.angle,vw/vh)
  if R.camera then cx,cz=R.camera.focus[1],R.camera.focus[3]end
 end
 if flying then R.camera=Fly.camera(R.camera,cx,cz,M.groundAt(cx,cz-camBack+8-.001,Player.elevation),vw,vh,cam)end
 local atmosphere=V.require("NativeAtmosphere")
 local atmosphereMap=atmosphere.gen3(def,Map.current)
 if atmosphere.kind(atmosphereMap)=="forest" then V.require("DayNight").applyRig(false) end
 R.orbitGround=M.groundAt(cx,cz-camBack+8-.001,Player.elevation)
 R.viewProjection(cx,cz,vw,vh)
 R.orbitGround=nil
 savedCanvas=love.graphics.getCanvas();love.graphics.push('all');saved=true
 if not plate and built and Shadow.begin(cx,cz,vw,vh) then
  local room=not cam.battle and Interior.forMap(def,3) or nil
  Shadow.roomClip(room and room.bounds)
  terrain(Shadow.draw)
  for _,d in ipairs(waterMeshes())do Shadow.draw(d[1],d[2])end
  if not cam.battle then
   Shadow.sprites(true);actors(game,cam,Shadow.draw);Shadow.sprites(false)
  end
  Shadow.finish('firered')
 end
 local room=not cam.battle and Interior.forMap(def,3) or nil
 Interior.setOpenings(room,cache.openings)
 Interior.configure(room)
 local bounds=built and M.distance.bounds
 R.fog=not indoor and bounds and Distance.haze(background,M.fadeExtent,{cx,0,cz},
  {bounds[1]*16,bounds[2]*16,(bounds[3]+1)*16,(bounds[4]+1)*16})or nil
 R.fog=atmosphere.fog(atmosphereMap) or R.fog
 if flying then R.fog=Fly.fog(background,R.fog,cx,cz)end
 -- the window lamps: lit after dark in an outdoor scene (DayNight), never in
 -- a room, and no pane glows until terrain() gives a tileset its own mask
 R.glassNight=(not indoor) and V.require('DayNight').windowLight() or 0
 R.glassMask=nil
 if not R.beginScene(renderWidth,renderHeight,cx,cz,vw,vh,background,'firered') then M.restore();return false end
 R.battleOcclusion(nil)
 if plate then
  if plate.image then R.backdrop(plate.image,plate.offset)end
 else
  Options.underlay(indoor,cx,cz,background)
  Interior.draw(room)
  if built then terrain(R.draw)end
  if flying then Fly.drawGround(R.draw)end
 end
 local water=not plate and built and waterMeshes()or {}
 if cam.battle then
  for _,d in ipairs(water)do R.draw(d[1],d[2])end
  -- Optional Stadium 2 models stand on the plate where the native battlers are.
  V.require('Gen3StadiumModels').draw(game,cam,cx,cz,M.groundAt)
 else
  local waterLevels={}
  for _,d in ipairs(water)do local h=d[4];waterLevels[h]=waterLevels[h]or{};local group=waterLevels[h];group[#group+1]=d end
  for h,group in pairs(waterLevels)do
   V.require('WaterSurfacePass').draw(group,function()actors(game,cam,R.draw)end,function()
    reflectPlane=h
    local ok,err=pcall(actors,game,cam,R.draw)
    reflectPlane=nil
    if not ok then error(err,0)end
   end)
  end
  if built then actors(game,cam,R.draw)end
  if not cam.replay and built then rideDust(game,cam);fieldEffects(R.draw,cam)end
  if flying then Fly.drawRider(R.draw,cam)end
  -- after dark the street lamps' lanterns and the pools of light under them (Gen3Lamp)
  if not indoor and built then V.require('Gen3Lamp').draw(cache,R,V.require('DayNight').windowLight()) end
 end
 R.battleOcclusion(nil)
 if not plate and built then atmosphere.draw(atmosphereMap) end
 local canvas=Options.finish(R.endScene(),width,height)
 if flying then Fly.overlay(canvas,width,height,renderWidth,renderHeight)end
 if not plate then
  local weather=V.require('Weather')
  local apply=cam.battle and weather.applyBattle or weather.apply
  apply(canvas,width,height,{id=Map.current,def={outdoor=not indoor}},math.max(1,width/640))
 end
 R.fog=nil
 R.tint={1,1,1}
 love.graphics.pop();love.graphics.setCanvas(savedCanvas);saved=false;savedCanvas=nil
 -- Use the same public world-image handoff as Battle Art's Gen1/2 pipeline.
 -- Otherwise an HD scene is squeezed into Game3's low-resolution field
 -- canvas before being enlarged, throwing away foliage/geometry detail.
 -- UI continues through the native, separate pixel-aligned plane.
 if override then Renderer:setWorldOverride(canvas) end
 love.graphics.push('all');love.graphics.origin();love.graphics.setShader();love.graphics.setColor(1,1,1,1)
 love.graphics.setBlendMode('alpha','premultiplied');love.graphics.draw(canvas,0,0,0,vw/width,vh/height)
 love.graphics.pop()
 return true
end
-- QA: meshes and vertices held by the live scene and the retained ones.
function M.retainedGeometry()
 local meshes,verts=0,0
 local function count(c)
  if not c then return end
  local list={}
  for _,part in ipairs(c.parts or {})do
   for _,m in ipairs({part.under or false,part.over or false,part.canopy or false,part.roof or false,part.plants or false,part.water or false})do list[#list+1]=m end
   for _,w in ipairs(part.waters or {})do list[#list+1]=w.mesh end
  end
  for _,part in ipairs(c.civics or {})do list[#list+1]=part.mesh or false end
  for _,bld in ipairs(c.buildingModels or {})do list[#list+1]=bld.mesh or false end
  list[#list+1]=c.wood or false;list[#list+1]=c.leaves or false
  for _,m in ipairs(list)do if m then meshes=meshes+1;verts=verts+(m:getVertexCount() or 0)end end
 end
 count(stream.active)
 for _,e in ipairs(stream.kept)do count(e.value)end
 return meshes,verts
end
function M.invalidate()Boundary.clear();stream:clear();cache={}end
function M.release()
 -- the debug radius override must not outlive the scene that set it (a later
 -- normal session would otherwise keep the no-culling world)
 Distance.forceFull=false
 if dustMesh then dustMesh:release();dustMesh=nil end
 if dustImage then dustImage:release();dustImage=nil end
 for _,c in pairs(effectCanvases)do c:release()end;effectCanvases={}
 stream:clear();cache={}
 for _,mesh in pairs(spriteMeshes)do if mesh then mesh:release() end end
 spriteMeshes={}
 Landmarks.release()
 if foliage then foliage:release();foliage=nil end
 if bark then bark:release();bark=nil end
 Roof.release();Outdoor.release()
 R.invalidate();Shadow.invalidate();V.require('GlassMask').invalidate();V.require('Gen3Lamp').invalidate()
 V.require('Gen3SceneOptions').release()
end
return M
