-- Counted relief for the General mountain (Route 111's pink rock, Route 114's beige): the terrace
-- levels Emerald 3DS counts from the drawing (tools/relief, MIT, NOTICE.md), baked offline into
-- Gen3ReliefData and laid here on the cells of a rock mass.
--
-- The bake gives every rock cell a 5x5 lattice of heights (4 px steps, 16 px a level, level 0 = the
-- map's biggest ground) and the soft shoulders / rolling tops as a change to it. Here:
--  * the counted levels are mapped onto this game's floors: each level of ground beside the mass
--    (a walkable neighbour with a counted level) is an anchor, level -> that floor; between anchors
--    the heights follow them, beyond the highest/lowest one a level is LEVEL px (taller than the
--    cartridge's 16: the user's pick, 2026-10-17);
--  * a patch is a facet of its cell's own drawing laid 1:1 from above, as Gen3Hills does; a steep
--    patch (a face drawn as a slope) is cut into bands that show the drawing's rows repeated, never
--    stretched (Gen3Hills.steep);
--  * where a cell edge stands over its neighbour a wall closes it in the map's face tile, bottom
--    aligned, the tile's rows repeating up it. North edges are walled too: the 3DS never needs
--    them (its camera never sees a terrace's back), first person and the orbit do;
--  * a neighbour that is not rock of this mass is met at its own floor.
-- Opt-in per map (M.MAPS); masses of other tiles (the brown terrace) stay with Gen3Hills / Gen3Rock.
local V=...
local M={enabled=true}
-- left off on purpose (A2/A3 A/B 2026-10-21: the counted levels leave them flat, smoothed or pyramidal beside the old rock, or worse than it): Lilycove, Routes 104, 117, 121 and 124, Southern Island
M.MAPS={EM_ROUTE111=true,EM_ROUTE114=true,EM_ROUTE113=true,EM_ROUTE115=true,EM_FALLARBOR_TOWN=true,EM_MT_CHIMNEY=true,EM_EVER_GRANDE_CITY=true,EM_MT_PYRE_EXTERIOR=true,EM_MT_PYRE_SUMMIT=true,EM_ROUTE116=true,EM_BATTLE_FRONTIER_OUTSIDE_EAST=true,EM_BATTLE_FRONTIER_OUTSIDE_WEST=true,EM_ROUTE119=true,EM_MOSSDEEP_CITY=true,EM_ROUTE118=true,EM_ROUTE120=true,EM_PACIFIDLOG_TOWN=true,EM_SKY_PILLAR_OUTSIDE=true,EM_VERDANTURF_TOWN=true,EM_ROUTE103=true,EM_ROUTE110=true,EM_ROUTE123=true,EM_SAFARI_ZONE_SOUTHWEST=true,EM_SAFARI_ZONE_SOUTH=true,EM_ROUTE106=true,EM_ROUTE105=true,EM_ROUTE107=true,EM_DEWFORD_TOWN=true,EM_ROUTE109=true,EM_ROUTE122=true,EM_ROUTE125=true,EM_ROUTE128=true}
M.V1={EM_ROUTE111=true,EM_ROUTE114=true,EM_ROUTE113=true,EM_ROUTE115=true,EM_FALLARBOR_TOWN=true,EM_ROUTE112=true,EM_MT_CHIMNEY=true}   -- signed on the level->floor anchors; every other map stands per cell on its nearest ground
M.CLAMP_UP_GEN=1e9 -- px: (General rock on the new maps is bounded by M.LIFT over the anchors instead)
M.LIFT=48          -- px: on the new maps the local relief (nearest ground + counted levels) may lift a cell this far over the level->floor anchors, never below them
M.STAND_PX=12      -- px: a cell counts as standing when its top is this far over its nearest walkable ground
M.KEEP={EM_SKY_PILLAR_OUTSIDE={14,9,21,13}}   -- per map: a mass inside this box {x0,y0,x1,y1} skips the stand-share release (its counted heights are real)
-- Tiers: a formation drawn as stacked floors (Sky Pillar's rock in the middle of the island: a light top, a
-- hatched flank each side, a second hatched flank outside it, the brown front with the cave mouth). Counted as
-- one smooth dome it stood as a pointed mound; here each cell of the grid is read from the drawing as a height
-- over the ground (counted level GL): flat, or a ramp west->east between two named heights.
-- Tokens, one per cell from x0,y0 (two letters, west edge then east edge: UU a flat top, LU rising to the east;
-- G ground, L lower floor, U upper floor; -- leaves the cell to the counted relief).
M.TIER_PX={G=0,L=32,U=56}
M.TIERS={EM_SKY_PILLAR_OUTSIDE={x0=14,y0=9,GL=3,rows={
 '-- -- UU UU UU UL --',
 '-- LU UU UU UU UL LG',
 'GL LU UU UU UU UL LG',
 'GL LL LL LL LL LL LG',
 'GL LL LL -- LL LL LG'}}}
-- (the outer flank tiles are drawn with sand in their rounded corners, which lay on the slope as a yellow
-- strip: they wear the inner flank's hatching instead)
M.TIER_TEX={EM_SKY_PILLAR_OUTSIDE={['14:11']='15:11',['19:9']='19:10',['14:12']='15:11',['14:13']='15:11',['20:10']='19:10',['20:11']='19:11',['20:12']='19:11',['20:13']='19:11'}}
local function kept(mass)local B=M.KEEP[mass.mapId or '']return B and mass.x0>=B[1] and mass.y0>=B[2] and mass.x1<=B[3] and mass.y1<=B[4] end
M.STAND_SHARE=.25   -- a new-map mass whose share of cells standing M.STAND_PX over their nearest ground is below this is not claimed (keeps the rule-based heights; 0: off)
M.SPIKE=24         -- px: no cell stands more than this over the tallest of its four neighbours on the new maps
M.SMOOTH=4         -- cells: the offsets of the nearest ground are medianed over this radius, so two grounds that disagree do not make a spire
M.LEVEL=24         -- px a level climbs beyond the ground beside the mass (3DS: 16)
M.RED_SHARE=.3     -- red maps: a big merged mass holds trees, ash and grass too
M.SHARE=.6         -- share of a mass's cells that must be General mountain tiles
M.MIN_CELLS=6      -- smaller groups are stones (Gen3Rock / Gen3Mass)
M.BROWN_ON=true    -- the brown terrace takes the relief (signed 2026-10-18); false leaves it to Gen3Hills / Gen3Rock
M.P=4
M.CLAMP_UP=56      -- px: brown / red cells climb at most this over their nearest ground
-- Mt Chimney (user 2026-10-22: "there are places where the rocks are stacked way too high ... check the height
-- really well on the original sprite map"): its maze walls are drawn as one face tile, not a counted terrace, so
-- the 24 px counted levels stood them 3-4 courses over the path in broken half-course slabs. A map listed here
-- stands in WHOLE 16 px courses over the ground beside it, at most this many px (32 = two courses).
M.CLAMP_UP_MAP={EM_MT_CHIMNEY=32}
M.CLAMP_DOWN=8
M.STEP_RED=true     -- red rock: whole levels like the drawing's terraces, no ramps or soft tops
M.STEP_MAPS={EM_FALLARBOR_TOWN=true}   -- brown here is a few terrace cells between buildings: whole levels, no ramps
M.CLAMP_UP_BROWN=36 -- px: the brown terrace, whose levels are fewer and broader, climbs less
M.EDGE_RUN=3       -- cells a rock at the map edge runs on into the boundary fill (then it drops in a wall)
M.TINY=4           -- px: a wall this low is a sliver
M.SNAP=6          -- px: an edge this close to the ground beside it is flush with it
-- Clean twins (ghost card H3, Route 111): General rock tiles drawn with a grass rim (the ground beyond the cliff's edge), which on
-- a slope or a wall lies as a green stripe. Each has a twin in the tileset, the same drawing with the rim in ROCK colours (mean
-- difference over the other pixels 0 - 5; the twins that match even better, 0x088 / 0x0A8 / 0x092, carry a sand or water rim and
-- paint a yellow or blue stripe instead): a standing cell and its wall faces wear it. A cell flat at its floor keeps the
-- original (its rim lies next to the real grass).
M.CLEAN={[0x070]=0x073,[0x078]=0x09B,[0x07A]=0x09C,[0x08B]=0x09B,[0x08C]=0x09C}
local SHADE={south=.84,north=.62,east=.74,west=.7}
local LX,LY,LZ=-.42,1,-.55   -- light from the north-west, above (as Gen3Hills)
do local l=math.sqrt(LX*LX+LY*LY+LZ*LZ);LX,LY,LZ=LX/l,LY/l,LZ/l end

local function ckey(x,y)return x..':'..y end
local function walk(n)return (n.collision or 0)==0 end
local function floorOf(n)return n.floorHigh or n.base or 0 end
local D8={{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
local DOOR={[0x60]=true,[0x69]=true,[0x6E]=true,[0x6F]=true,[0x8D]=true}

local SNAP_SIDES={
 {0,-1,function(k)return k+1 end},          -- north: the lattice's first row
 {0,1,function(k)return 20+k+1 end},        -- south: the last row
 {-1,0,function(k)return k*5+1 end},        -- west: the first column
 {1,0,function(k)return k*5+5 end}}         -- east: the last column

local DATA
local function data(mapId)
 if DATA==nil then
  local ok,d=pcall(function()return V.require('Gen3ReliefData')end)
  DATA=ok and type(d)=='table' and d or false
 end
 return DATA and DATA[mapId] or nil
end

-- one baked cell: {g={25 px}, d={25 px}, wx, wy} (parsed once per mass)
local function cellOf(D,cache,cx,cy)
 if cx<0 or cy<0 or cx>=D.w or cy>=D.h then return nil end
 local idx=cy*D.w+cx+1
 local e=cache[idx]
 if e~=nil then return e or nil end
 local s=D.cells[idx]
 if not s then cache[idx]=false;return nil end
 local gs,ds,ws=s:match('^([^|]*)|([^|]*)|(.*)$')
 local g,d={}, {}
 for v in gs:gmatch('%-?%d+')do g[#g+1]=tonumber(v) end
 for v in ds:gmatch('%-?%d+')do d[#d+1]=tonumber(v)/4 end
 local wx,wy=ws:match('^(%-?%d+),(%-?%d+)$')
 e={g=g,d=d,wx=wx and tonumber(wx),wy=wy and tonumber(wy)}
 cache[idx]=e
 return e
end

local prepare
function M.claims(mass,cells)
 if mass.relief~=nil then return mass.relief end
 mass.relief=false
 if not (M.enabled and M.MAPS[mass.mapId or ''] and not mass.seaBoulders and #mass.members>=M.MIN_CELLS) then return false end
 local D=data(mass.mapId)
 if not D then return false end
 -- (the General mountain, and the Fallarbor hill tiles that redraw it: Route 114's beige mountain;
 -- not the red rock)
 local Hills=V.require('Gen3Hills')
 local gen,fall=Hills.GENERAL,Hills.TILES
 local RT=V.require('Gen3RockTables')
 local brown=RT.BROWN
 local red=RT.RED_MAPS[mass.mapId or ''] and RT.RED
 local cache={}
 local n,known,nb=0,0,0
 for _,c in ipairs(mass.members)do
  if cellOf(D,cache,c.cx,c.cy) then
   known=known+1
   local t=fall[c.pair]
   if red then
    if red[c.mid] then n=n+1;nb=nb+1 end
   elseif M.BROWN_ON and brown[c.mid] and not (gen[c.mid] or (t and t[c.mid])) then n=n+1;nb=nb+1
   elseif gen[c.mid] or (t and t[c.mid]) or (M.BROWN_ON and brown[c.mid]) then n=n+1 end
  end
 end
 -- (a mass's members outside the map -- the boundary fill -- have no relief and do not count; masses
 -- that grow as the near window grows must not flip back and forth, so the share is of the known cells)
 mass.relief=n>=M.MIN_CELLS and n>=(red and M.RED_SHARE or M.SHARE)*known
 -- (brown / red masses: the game has no floors at the counted levels there, so height comes from the nearest walkable ground)
 mass.reliefBrown=mass.relief and red==nil and nb>=.4*n
 mass.reliefRed=mass.relief and red~=nil
 mass.reliefLocal=mass.relief and (red~=nil or nb>=.4*n or not M.V1[mass.mapId or ''])
 mass.reliefLift=mass.relief and red==nil and nb<.4*n and not M.V1[mass.mapId or '']
 if mass.reliefLift and M.STAND_SHARE>0 and not kept(mass) then
  -- (a mass whose counted levels leave most of it at or below the ground beside it -- the game's floors are all 0 on
  -- a beach or a shoal -- would lie as a decal: it keeps the rule-based heights, which stand it)
  local R=prepare(mass,cells)
  if R.stand<M.STAND_SHARE then mass.relief=false;mass.reliefData=nil end
 end
 return mass.relief
end

-- level -> floor anchors from the walkable ground beside the mass, and the height function
local function anchors(mass,cells,D,cache,inMass)
 local byLevel={}
 for _,c in ipairs(mass.members)do
  for _,d in ipairs(D8)do
   local n=cells[ckey(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] and walk(n) then
    local e=cellOf(D,cache,n.cx,n.cy)
    if e then
     local s=0;for k=1,25 do s=s+e.g[k] end
     local mean=s/25
     local lv=math.floor(mean/16+.5)
     if math.abs(mean-lv*16)<=2 then
      local l=byLevel[lv];if not l then l={};byLevel[lv]=l end
      l[#l+1]=floorOf(n)
     end
    end
   end
  end
 end
 local A={}
 for lv,l in pairs(byLevel)do
  table.sort(l)
  A[#A+1]={lv,l[math.floor((#l+1)/2)]}
 end
 table.sort(A,function(a,b)return a[1]<b[1] end)
 if #A>1 and not M.V1[mass.mapId or ''] then
  -- (the floors of the ground beside a big mass do not rise with its counted levels everywhere: pool the
  -- anchors that run the wrong way, so the heights between them never dip into a pit)
  local blocks={}
  for _,a in ipairs(A)do blocks[#blocks+1]={f=a[2],n=1,l0=a[1],l1=a[1]} end
  local i=1
  while i<#blocks do
   if blocks[i].f>blocks[i+1].f then
    local b1,b2=blocks[i],blocks[i+1]
    blocks[i]={f=(b1.f*b1.n+b2.f*b2.n)/(b1.n+b2.n),n=b1.n+b2.n,l0=b1.l0,l1=b2.l1}
    table.remove(blocks,i+1)
    if i>1 then i=i-1 end
   else i=i+1 end
  end
  local B={}
  for _,b in ipairs(blocks)do
   for _,a in ipairs(A)do if a[1]>=b.l0 and a[1]<=b.l1 then B[#B+1]={a[1],b.f} end end
  end
  A=B
 end
 if #A==0 then
  local f=0;for _,c in ipairs(mass.members)do f=math.min(f,floorOf(c)) end
  A[1]={0,f}
 end
 return A
end

local function heightFn(A)
 local L=M.LEVEL
 local n=#A
 return function(rel)
  local l=rel/16
  if l<=A[1][1] then return A[1][2]+(l-A[1][1])*L end
  if l>=A[n][1] then return A[n][2]+(l-A[n][1])*L end
  for k=1,n-1 do
   local a,b=A[k],A[k+1]
   if l<=b[1] then return a[2]+(b[2]-a[2])*(l-a[1])/(b[1]-a[1]) end
  end
  return A[n][2]
 end
end

-- brown / red: every cell stands at the offset of the nearest walkable ground beside the mass
-- (level lv at floor f -> offset f-lv*LEVEL), carried across the mass cell to cell, nearest first
local function localOffsets(mass,cells,D,cache,inMass,A)
 local seeds={}
 for _,c in ipairs(mass.members)do
  local cand={}
  for _,d in ipairs(D8)do
   local n=cells[ckey(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] and walk(n) then
    local e=cellOf(D,cache,n.cx,n.cy)
    if e then
     local s=0;for k=1,25 do s=s+e.g[k] end
     local mean=s/25
     local lv=math.floor(mean/16+.5)
     if math.abs(mean-lv*16)<=2 then cand[#cand+1]=floorOf(n)-lv*M.LEVEL end
    end
   end
  end
  if #cand>0 then table.sort(cand);seeds[c]=cand[math.floor((#cand+1)/2)] end
 end
 local OFF,queue={}, {}
 local FL={}
 for _,c in ipairs(mass.members)do if seeds[c] then OFF[c]=seeds[c];queue[#queue+1]=c end end
 for _,c in ipairs(queue)do
  local fs={}
  for _,d in ipairs(D8)do
   local n=cells[ckey(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] and walk(n) then fs[#fs+1]=floorOf(n) end
  end
  table.sort(fs);FL[c]=fs[math.floor((#fs+1)/2)] or 0
 end
 local qi=1
 while qi<=#queue do
  local c=queue[qi];qi=qi+1
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[ckey(c.cx+d[1],c.cy+d[2])]
   if n and inMass[n] and OFF[n]==nil then OFF[n]=OFF[c];FL[n]=FL[c];queue[#queue+1]=n end
  end
 end
 local base=A[1] and (A[1][2]-A[1][1]*M.LEVEL) or 0
 for _,c in ipairs(mass.members)do if OFF[c]==nil then OFF[c]=base;FL[c]=base end end
 return OFF,FL,seeds
end

-- the offsets of the nearest ground, medianed over M.SMOOTH cells round each cell (weight 1/(1+distance)):
-- where two grounds beside one mass disagree by levels (the game's floors are coarse, the counted levels
-- are not) the mass drifts between them instead of standing a spire over the seam
local function smoothOffsets(mass,OFF,seeds)
 local S={}
 for _,c in ipairs(mass.members)do if seeds[c]~=nil then S[#S+1]={c.cx,c.cy,seeds[c]} end end
 local out={}
 local R=M.SMOOTH
 for _,c in ipairs(mass.members)do
  local list={}
  for _,s in ipairs(S)do
   local dx,dy=math.abs(s[1]-c.cx),math.abs(s[2]-c.cy)
   if dx<=R and dy<=R then list[#list+1]={s[3],1/(1+math.max(dx,dy))} end
  end
  if #list==0 then out[c]=OFF[c]
  else
   table.sort(list,function(a,b)return a[1]<b[1] end)
   local tot=0;for _,e in ipairs(list)do tot=tot+e[2] end
   local acc,pick=0,list[#list][1]
   for _,e in ipairs(list)do acc=acc+e[2];if acc>=tot/2 then pick=e[1];break end end
   out[c]=pick
  end
 end
 return out
end

-- Mounds: the round 2x2 sand/rock humps drawn standing on the paths (Route 115, also Routes 111, 114, 112).
-- The counted relief reads them as a flat top, at the path's level or a whole level over or under it, so in
-- 3D they lay flat on the path as a painted patch, stood as a square block, or sank as a pit (user: "the
-- rocks on this route havent been done yet"). Each mound is a low dome over the floor round it instead:
-- its footprint is the drawn round foot (centre and radii below, px within the 32x32 block), its top
-- MOUND_H px over that floor, and outside the foot it lies at the floor.
-- (ids: top-left, top-right, bottom-left, bottom-right; the General ones and the Fallarbor/Lavaridge redraw)
M.MOUND_TILES={{0x093,0x094,0x09B,0x09C},{0x253,0x254,0x25B,0x25C}}
M.MOUND_H=16
M.MOUND_C={16,17}
M.MOUND_R={15,16}
M.MOUND_ON=true
function M.mounds(mass,cells,R)
 if not M.MOUND_ON then return end
 for _,c in ipairs(mass.members)do
  for _,ids in ipairs(M.MOUND_TILES)do
   if c.mid==ids[1] then
    local q={c,cells[ckey(c.cx+1,c.cy)],cells[ckey(c.cx,c.cy+1)],cells[ckey(c.cx+1,c.cy+1)]}
    local ok=true
    for k=1,4 do if not (q[k] and q[k].mid==ids[k] and R.inMass[q[k]] and R.H[q[k]]) then ok=false end end
    if ok then
     -- the floor round it: the median walkable floor of the ring of cells round the block
     local fs={}
     for dy=-1,2 do for dx=-1,2 do
      if dx<0 or dx>1 or dy<0 or dy>1 then
       local n=cells[ckey(c.cx+dx,c.cy+dy)]
       if n and not R.inMass[n] and walk(n) then fs[#fs+1]=floorOf(n) end
      end
     end end
     if #fs>0 then
      table.sort(fs)
      local F=fs[math.floor((#fs+1)/2)]
      for k=1,4 do
       local ox,oz=(k==2 or k==4) and 16 or 0,(k>=3) and 16 or 0
       local h={}
       for j=0,4 do for i=0,4 do
        local u,v=(ox+i*4-M.MOUND_C[1])/M.MOUND_R[1],(oz+j*4-M.MOUND_C[2])/M.MOUND_R[2]
        local r2=u*u+v*v
        -- (a bell: a rounded top, a flared foot, no rim)
        h[j*5+i+1]=F+(r2<1 and M.MOUND_H*(math.cos(math.pi*math.sqrt(r2))+1)/2 or 0)
       end end
       R.H[q[k]]=h
       R.mound=R.mound or {};R.mound[q[k]]=true
      end
     end
    end
   end
  end
 end
end

prepare=function(mass,cells)
 if mass.reliefData then return mass.reliefData end
 local D=data(mass.mapId)
 local cache={}
 local inMass={}
 for _,c in ipairs(mass.members)do inMass[c]=true end
 local A=anchors(mass,cells,D,cache,inMass)
 local hf=heightFn(A)
 local OFF,FL
 local SEEDS
 if mass.reliefLocal then OFF,FL,SEEDS=localOffsets(mass,cells,D,cache,inMass,A) end
 local OFFS=mass.reliefLift and OFF and smoothOffsets(mass,OFF,SEEDS)
 local R={D=D,cache=cache,inMass=inMass,H={},E={},A=A}
 for _,c in ipairs(mass.members)do
  local e=cellOf(D,cache,c.cx,c.cy)
  if e and not DOOR[c.behavior or -1] then
   local h={}
   local HA
   local o=OFF and OFF[c]
   local step=o and ((mass.reliefBrown and M.STEP_MAPS[mass.mapId or '']) or (mass.reliefRed and M.STEP_RED))
   for k=1,25 do
    -- (a ramp drawn across a diagonal terrace end stood as a lone wedge: such a cell takes its nearest whole level)
    local g,d=e.g[k],e.d[k]
    if step then g=math.floor(g/16+.5)*16;d=0 end
    if OFFS then
     -- (anchors say where the ground is; the local relief only lifts a cell over them, by at most M.LIFT)
     local ha=hf(g)+d
     HA=HA or {};HA[k]=ha
     h[k]=math.max(ha,math.min(OFFS[c]+g*M.LEVEL/16+d,ha+M.LIFT))
    else
     h[k]=(o and (o+g*M.LEVEL/16) or hf(g))+d
    end
   end
   if o and FL[c] then
    -- (brown / red: a merged mass stands over several floors; no cell climbs more than CLAMP_UP over
    -- its own nearest ground, nor sinks below it)
    local cup=(mass.reliefRed and (M.CLAMP_UP_MAP[mass.mapId or ''] or M.CLAMP_UP)) or (mass.reliefBrown and M.CLAMP_UP_BROWN) or M.CLAMP_UP_GEN
    local lo,hi=FL[c]-M.CLAMP_DOWN,FL[c]+cup
    for k=1,25 do h[k]=math.max(lo,math.min(hi,h[k])) end
    if mass.reliefRed and M.CLAMP_UP_MAP[mass.mapId or ''] then
     -- (a map whose counted levels overshoot its drawing: whole courses over the ground beside it, never a
     -- half-course step and never sunk under the ground -- see CLAMP_UP_MAP)
     local cap=math.floor(cup/16+.5)
     for k=1,25 do
      local d=math.floor((h[k]-FL[c])/16+.5)
      if d<0 then d=0 elseif d>cap then d=cap end
      h[k]=FL[c]+d*16
     end
    end
   end
   R.H[c]=h
   R.E[c]=e
   if HA then R.HA=R.HA or {};R.HA[c]=HA end
  elseif not e then
   -- outside the map (the boundary fill the mass runs on into): the nearest edge of the map's relief,
   -- run out flat, so a rock at the map edge goes on instead of dropping in a wall
   local cx2=math.max(0,math.min(D.w-1,c.cx));local cy2=math.max(0,math.min(D.h-1,c.cy))
   local e2=cellOf(D,cache,cx2,cy2)
   local out=math.max(-c.cx,c.cx-(D.w-1),-c.cy,c.cy-(D.h-1))
   if e2 and out<=M.EDGE_RUN then
    local h={}
    for j=0,4 do for i=0,4 do
     local jj=c.cy<0 and 0 or (c.cy>=D.h and 4 or j)
     local ii=c.cx<0 and 0 or (c.cx>=D.w and 4 or i)
     local k=jj*5+ii+1
     h[j*5+i+1]=hf(e2.g[k])+e2.d[k]
    end end
    R.H[c]=h
    R.E[c]=e2
   end
  end
 end
 -- spikes: a cell may not stand more than M.SPIKE over the tallest of its four neighbours in the mass (never below its anchors)
 if OFFS and R.HA then
  local top={}
  for c,h in pairs(R.H)do local m=-1e9 for k=1,25 do if h[k]>m then m=h[k] end end top[c]=m end
  for c,h in pairs(R.H)do
   local nm=nil
   for _,dd in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=top[cells[ckey(c.cx+dd[1],c.cy+dd[2])]]
    if n and (not nm or n>nm)then nm=n end
   end
   local HA=R.HA[c]
   if nm and HA then for k=1,25 do h[k]=math.max(HA[k],math.min(h[k],nm+M.SPIKE)) end end
  end
 end
 -- tiers: the cells of a stacked formation take their floors from the grid, over the ground's counted level
 local T=M.TIERS[mass.mapId or '']
 if T then
  local g0=hf(T.GL*16)
  for r,line in ipairs(T.rows)do
   local i=0
   for tok in line:gmatch('%S+')do
    local c=cells[ckey(T.x0+i,T.y0+r-1)]
    local h=c and R.H[c]
    if h and tok~='--' then
     local w,e=M.TIER_PX[tok:sub(1,1)],M.TIER_PX[tok:sub(2,2)]
     for j=0,4 do for k=0,4 do h[j*5+k+1]=g0+w+(e-w)*k/4 end end
    end
    i=i+1
   end
  end
 end
 -- cave mouths (Route 115's and Route 114's Meteor Falls doors): the rock cell over a door stands as a
 -- vertical face at its south edge, from the door's floor up -- the door's drawing at the foot when the door
 -- is in the rock, the arch cell's own drawing over it, its top rows repeated above -- and is level on top.
 -- (laid on the counted relief the arch's drawing lay flat on the floor in front of a slope, and the slope
 -- buried the mouth: Gen3Hills' mouth, carried over)
 R.mouth={}
 for _,c in ipairs(mass.members)do
  local s=cells[ckey(c.cx,c.cy+1)]
  local h=R.H[c]
  if h and s and DOOR[s.behavior or -1] and (s.collision or 0)~=7 and not DOOR[c.behavior or -1] then
   local F=floorOf(s)
   local inside=inMass[s] and s or nil
   local top=F+(inside and 32 or 16)
   for k=1,25 do top=math.max(top,h[k]) end
   for k=1,25 do h[k]=top end
   R.mouth[c]={floor=F,door=inside,top=top}
  end
 end
 M.mounds(mass,cells,R)
 -- an edge that meets ground beside the mass within SNAP px of its floor is flush with it (the anchors
 -- are medians: a ground cell a few px off left a slit, rock top below the floor beside it, open to
 -- the void under the mass)
 for _,c in ipairs(mass.members)do
  local h=R.H[c]
  if h then
   for _,sd in ipairs(SNAP_SIDES)do
    local n=cells[ckey(c.cx+sd[1],c.cy+sd[2])]
    if n and not R.H[n] then
     local f=floorOf(n)
     for k=1,3 do
      local idx=sd[3](k)
      if math.abs(h[idx]-f)<=M.SNAP then h[idx]=f end
     end
    end
   end
  end
 end
 R.OFF=OFF;R.FL=FL
 if FL then
  local st,n=0,0
  for _,c in ipairs(mass.members)do
   local h=R.H[c]
   if h and FL[c] and c.cx>=0 and c.cy>=0 and c.cx<D.w and c.cy<D.h then
    n=n+1
    local m=-1e9;for k=1,25 do if h[k]>m then m=h[k] end end
    if m-FL[c]>=M.STAND_PX then st=st+1 end
   end
  end
  R.stand=n>0 and st/n or 1;R.standN=n
 end
 mass.reliefData=R
 return R
end

-- heights of a cell's edge, 5 points west->east (N, S) or north->south (W, E)
local function edgeOf(h,side)
 local o={}
 for k=0,4 do
  if side=='N' then o[k+1]=h[k+1]
  elseif side=='S' then o[k+1]=h[20+k+1]
  elseif side=='W' then o[k+1]=h[k*5+1]
  else o[k+1]=h[k*5+5] end
 end
 return o
end

-- the neighbour's heights along the shared edge: a cell of this mass keeps its own, anything else
-- is met at its floor (nil: nothing built there)
local function neighbourEdge(R,cells,c,side)
 local dx,dy,theirs=0,0,'N'
 if side=='W' then dx=-1;theirs='E' elseif side=='E' then dx=1;theirs='W' elseif side=='S' then dy=1;theirs='N' else dy=-1;theirs='S' end
 local n=cells[ckey(c.cx+dx,c.cy+dy)]
 if not n then return nil end
 local h=R.H[n]
 if h then return edgeOf(h,theirs) end
 local f=floorOf(n)
 return {f,f,f,f,f}
end

-- this cell's share of the relief (absolute heights)
function M.append(mass,cells,emit,uvFor,c)
 if not c then return true end
 local R=prepare(mass,cells)
 local Hills=V.require('Gen3Hills')
 local Rock=V.require('Gen3Rock')
 local sub,steep=Hills.sub,Hills.steep
 local own=uvFor(c.ts,c.mid);if not own then return true end
 local TX=M.TIER_TEX[mass.mapId or '']
 local alt=TX and TX[ckey(c.cx,c.cy)]
 if alt then local n=cells[alt];local u=n and uvFor(n.ts,n.mid);if u then own=u end end
 local h=R.H[c]
 local P=M.P
 local x,z=c.cx*16,c.cy*16
 local F=floorOf(c)
 local twin=M.CLEAN[c.mid]
 local ownC=twin and not alt and uvFor(c.ts,twin) or nil
 local skin=own
 if h and ownC then
  local top=-1e9;for k=1,25 do if h[k]>top then top=h[k] end end
  if top-F>M.TINY then skin=ownC end
 end
 if not h then
  -- a cell the bake has no relief for (a door in the rock): flat at its floor
  -- (a door in the rock: the arch is drawn on the face over it, so the floor wears the ground south of it)
  local f=floorOf(c)+.02
  local s=DOOR[c.behavior or -1] and cells[ckey(c.cx,c.cy+1)]
  local g=s and uvFor(s.ts,s.mid) or own
  emit({{x,f,z},{x+16,f,z},{x+16,f,z+16},{x,f,z+16}},g,1)
  return true
 end
 -- the top: one facet per 4x4 patch
 for j=0,3 do for i=0,3 do
  local a,b,cc,d=h[j*5+i+1],h[j*5+i+2],h[(j+1)*5+i+2],h[(j+1)*5+i+1]
  -- (a patch lying on the floor is coplanar with the scene's own ground there: the two z-fight, the rock showing through as
  -- ragged shards. It rides a hair above, as the door floor below. All FOUR corners must lie at the floor: a slope that only
  -- touches it keeps its fall. One wholly under the floor stays hidden.)
  do local mx,mn=math.max(a,b,cc,d),math.min(a,b,cc,d)
   if mx<=F+.01 and mn>F-1 then a,b,cc,d=F+.02,F+.02,F+.02,F+.02 end end
  local x0,z0=x+i*P,z+j*P
  local dx=((b+cc)-(a+d))/(2*P);local dz=((d+cc)-(a+b))/(2*P)
  local nl=math.sqrt(dx*dx+1+dz*dz)
  local dot=(-dx*LX+LY-dz*LZ)/nl
  local shade=math.max(.6,math.min(1.08,.76+.24*dot/LY))
  -- (a mound's flanks are laid from above too: its drawing is the hump seen from above, and cut into
  -- steep bands it stood as vertical stripes)
  if (R.mound and R.mound[c]) or math.max(math.abs(a-b),math.abs(b-cc),math.abs(cc-d),math.abs(d-a),math.abs(a-cc),math.abs(b-d))<=P*1.05 then
   emit({{x0,a,z0},{x0+P,b,z0},{x0+P,cc,z0+P},{x0,d,z0+P}},sub(skin,i*P,j*P,i*P+P,j*P+P),shade)
  else
   steep(emit,skin,i,j,x0,z0,{{x0,a,z0},{x0+P,b,z0},{x0+P,cc,z0+P},{x0,d,z0+P}},math.abs(dz)>=math.abs(dx),shade)
  end
 end end
 -- walls where an edge stands over what lies beside it
 local e=R.E[c]
 local face=ownC or own
 if e.wx then
  local w=cells[ckey(e.wx,e.wy)]
  -- (a wall beside a cell drawn as foliage takes no art from it: the bush's green ran up the whole face
  -- as long stripes (F040, ghost card G2). The rock cell's own art instead.)
  local wt=w and w.ts and Rock.tileArt(w.ts,w.mid)
  local u=w and not (wt and wt.foliage) and uvFor(w.ts,w.mid)
  if u then face=u end
 end
 -- point on the edge at 4 px step u (0..P), side-specific as Gen3Hills' skirts
 local sides={
  {'S',function(k,u,y)return {x+k*P+u,y,z+16} end,function(k)return k*P end,SHADE.south},
  {'N',function(k,u,y)return {x+16-(k*P+u),y,z} end,function(k)return k*P end,SHADE.north},
  {'E',function(k,u,y)return {x+16,y,z+16-(k*P+u)} end,function(k)return k*P end,SHADE.east},
  {'W',function(k,u,y)return {x,y,z+k*P+u} end,function(k)return k*P end,SHADE.west}}
 local mo=R.mouth and R.mouth[c]
 if mo then
  local function rows(uv,r0,r1)
   local l,t,r,b=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
   return {{l,t+(b-t)*r0/16},{r,t+(b-t)*r0/16},{r,t+(b-t)*r1/16},{l,t+(b-t)*r1/16}}
  end
  local y=mo.floor
  local Z=z+16
  if mo.door then
   local du=uvFor(mo.door.ts,mo.door.mid)
   if du then emit({{x,y+16,Z},{x+16,y+16,Z},{x+16,y,Z},{x,y,Z}},du,SHADE.south) end
   y=y+16
  end
  emit({{x,y+16,Z},{x+16,y+16,Z},{x+16,y,Z},{x,y,Z}},own,SHADE.south)
  y=y+16
  while y<mo.top-.01 do
   local t=math.min(4,mo.top-y)
   emit({{x,y+t,Z},{x+16,y+t,Z},{x+16,y,Z},{x,y,Z}},rows(own,4-t,4),SHADE.south)
   y=y+t
  end
 end
 for _,s in ipairs(sides)do
  if mo and s[1]=='S' then goto nextside end
  local mine=edgeOf(h,s[1])
  local theirs=neighbourEdge(R,cells,c,s[1])
  if theirs then
   -- (S and W run with the lattice index; N and E run against it, so their segment k is 4-k)
   local rev=(s[1]=='N' or s[1]=='E')
   for k=0,3 do
    local i0,i1
    if rev then i0,i1=4-k,3-k else i0,i1=k,k+1 end
    local t0,t1=mine[i0+1],mine[i1+1]
    local o0,o1=theirs[i0+1],theirs[i1+1]
    if t0-o0>.01 or t1-o1>.01 then
     local F=math.min(t0,t1,o0,o1)
     local top=math.max(t0,t1)
     local y=F
     while y<top-.01 do
      local yt=math.min(top,y+16)
      local a0,a1=math.max(y,math.min(yt,t0)),math.max(y,math.min(yt,t1))
      local rows=math.min(16,yt-y)
      if top-F<=M.TINY then
       -- (a sliver: the face's foot row would show as a dotted line; it wears the cell's own top)
       emit({s[2](k,0,a0),s[2](k,P,a1),s[2](k,P,y),s[2](k,0,y)},sub(skin,s[3](k),0,s[3](k)+P,math.min(rows,P)),s[4])
      else
       emit({s[2](k,0,a0),s[2](k,P,a1),s[2](k,P,y),s[2](k,0,y)},sub(face,s[3](k),16-rows,s[3](k)+P,16),s[4])
      end
      y=yt
     end
    end
   end
  end
  ::nextside::
 end
 return true
end

return M
