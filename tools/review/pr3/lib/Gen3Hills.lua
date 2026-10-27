-- Sand hills (Routes 114 and 115): the blocked scenery hills between the
-- walkable corridors, built as one continuous rolling surface.
--
-- The rock builder (Gen3Rock) reads a drawing as tiers: a dark tile is the
-- front of a course, a light one its top. These hills are not drawn that way.
-- Their tops are the corridors' own sand tile, so the carving that cuts ground
-- out of a rock removed every light patch and left the dark shadow bands
-- standing on their own: rows of thin fins and pillars with olive caps.
--
-- Here a hill is a height field over 4x4 px patches:
--  * it rises from the walkable ground round it: LIP px at the edge, then RISE
--    px per px in from the nearest walkable edge, up to HMAX over that ground;
--  * where it lies between floors on different levels its base is a smooth
--    blend of them (relaxed from the floor of the nearest edge), so it ramps
--    from one corridor up to the other instead of breaking into steps;
--  * the drawing's dark bands sit FOLD px lower than its light tops (folds);
--  * k cells south of walkable ground it stands at most NORTHSLOPE*k over it,
--    so from the player's camera it never covers the corridor behind it.
-- Each patch is a facet of its cell's own drawing laid 1:1 from above (the
-- original picture reads unchanged from the play camera), shaded by its
-- slope. Where it stands over lower ground its edge is closed by a skirt.
-- Patches drawn as grass (a hill tile's green corner) are ground, not hill.
local V=...
local M={enabled=true}
M.MAPS={EM_ROUTE114=true,EM_ROUTE115=true,EM_ROUTE111=true,EM_ROUTE113=true,EM_ROUTE112=true,EM_MT_CHIMNEY=true,EM_SOOTOPOLIS_CITY=true}
-- the hill tiles of the Fallarbor tileset (not the black, the bush, the ash
-- piles, the cave mouth and its arch)
M.TILES={general__fallarbor=(function()
 local t={}
 for m=0x230,0x267 do t[m]=true end
 for _,m in ipairs({0x231,0x235,0x236,0x237,0x259,0x261})do t[m]=nil end
 return t end)()}
-- the General primary's mountain tiles (every pair): Route 111's pink hills are drawn in the same
-- way -- light tops, scalloped rims, dark north-south shadow bands -- and stood as the same fins and
-- stubs. Not the ledges, the cave mouth, the water, waterfall and stair tiles in that range.
M.GENERAL=(function()
 local t={}
 for m=0x068,0x0BF do t[m]=true end
 for _,m in ipairs({0x085,0x086,0x087,0x08D,0x08E,0x09F,0x0A1,0x0A7,0x0AF})do t[m]=nil end
 for m=0x0B0,0x0BD do t[m]=nil end
 return t end)()
M.GENERAL_MAPS={EM_ROUTE111=true,EM_ROUTE113=true,EM_ROUTE112=true}
-- Route 113's ash-rimmed rims, sides and corners round its mesas (Fallarbor tileset)
for _,m in ipairs({0x201,0x202,0x203,0x209,0x20B,0x211,0x213})do M.TILES.general__fallarbor[m]=true end
-- per map: mesas rather than rolling hills (Route 113's outcrops: steep sides, flat tops)
-- (class B round 3) the sea routes' rock as one rolling body: sea masses too (SEA), patches drawn as sea are ground (MASK)
for _,id in ipairs({'EM_ROUTE124','EM_ROUTE127','EM_ROUTE128','EM_ROUTE131','EM_ROUTE132','EM_ROUTE133','EM_ROUTE134'})do M.MAPS[id]=true end
M.PARAMS={EM_ROUTE124={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true},EM_ROUTE127={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true},EM_ROUTE128={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true},EM_ROUTE131={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true},EM_ROUTE132={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true},EM_ROUTE133={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true},EM_ROUTE134={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true},EM_ROUTE113={RISE=2.4,HMAX=24,LIP=8,FOLD=1},EM_ROUTE115={TIERS=true},EM_ROUTE112={ALL=true},EM_MT_CHIMNEY={ALL=true,HMAX=18,RISE=.5,LIP=4},EM_SOOTOPOLIS_CITY={ALL=true,HMAX=36,RISE=.5,LIP=4,BANK=true}}
-- (class A) rock the 2D draws as one ridge / island body, on the same rolling body as the sea routes above
M.CLASS_A={'EM_ROUTE126','EM_MOSSDEEP_CITY','EM_SKY_PILLAR_OUTSIDE','EM_ROUTE121','EM_ROUTE129','EM_ROUTE130'}
for _,id in ipairs(M.CLASS_A)do M.MAPS[id]=true;M.PARAMS[id]={ALL=true,HMAX=32,RISE=.5,LIP=4,SEA=true,MASK=true} end
M.PARAMS.EM_SKY_PILLAR_OUTSIDE.HMAX=48
-- review: sea routes whose domes stood too low (RISE .5 -> 2, HMAX 32 -> 48); 124 and 126 keep the old values
for _,id in ipairs({'EM_ROUTE127','EM_ROUTE128','EM_ROUTE129','EM_ROUTE130','EM_ROUTE131','EM_ROUTE132','EM_ROUTE133','EM_ROUTE134'})do if M.PARAMS[id] then M.PARAMS[id].RISE=2.0;M.PARAMS[id].HMAX=48 end end
M.TIER_DARK=.45  -- a patch this much shadow is band or stripe, not top
M.TIER_SCALE=2   -- a band patch lifts the hill this many times its drawn 4 px
M.TIER_SMOOTH=2  -- 3x3 median passes over the tier heights
M.MIN_CELLS=6       -- smaller rock groups are stones and mounds (Gen3Rock / Gen3Mass)
M.SHARE=.6          -- share of a group's cells that must be hill tiles
M.P=4               -- patch size, px
M.LIP=4             -- height of the hill's edge over the ground it stands beside
M.RISE=.85          -- rise per px in from the nearest walkable edge
M.HMAX=36           -- highest a hill stands over its base
M.FOLD=3            -- how much lower a dark (shaded) patch lies than a light one
M.DARK=.42          -- luminance under which a pixel is drawn shadow
M.NORTHSLOPE=12     -- see above (Gen3Rock.NORTHSLOPE)
M.BLEND=24          -- relaxation sweeps of the base between floors
local SHADE={south=.84,north=.62,east=.74,west=.7}
local LX,LY,LZ=-.42,1,-.55   -- light from the north-west, above
do local l=math.sqrt(LX*LX+LY*LY+LZ*LZ);LX,LY,LZ=LX/l,LY/l,LZ/l end

local function ckey(x,y)return x..':'..y end
local function pk(x,z)return (x+4096)*16384+(z+4096) end
local function walk(n)return (n.collision or 0)==0 end
-- (neighbour lists made once: written inline, each loop step built five new tables, and without the
-- JIT the hill preparation was most of Route 111's first view)
local D4={{1,0},{-1,0},{0,1},{0,-1}}
local D4S={{0,1},{0,-1},{1,0},{-1,0}}
local DC={{-1,-1},{0,-1},{-1,0},{0,0}}
local function floorOf(n)return n.floorHigh or n.base or 0 end

-- a rock-drawn bank (Gen3Objects.bank: crater walls painted with a few repeated tiles) is a hill where its map says so
function M.bankOk(mass)
 local Q=M.PARAMS[mass.mapId or '']
 return (M.enabled and Q and Q.BANK) and true or false
end
function M.claims(mass,cells)
 if mass.hill~=nil then return mass.hill end
 mass.hill=false
 local Qs=M.PARAMS[mass.mapId or '']
 if mass.seaBoulders and Qs and Qs.SEA and M.enabled then
  local Rk=V.require('Gen3Rock')
  local chain=true
  for _,m in ipairs(mass.members)do if not Rk.BOULDER[m.mid] then chain=false;break end end
  if chain or #mass.members<Rk.SEA_ISLAND_MIN then return false end
  mass.hill=true;return true
 end
 if not (M.enabled and M.MAPS[mass.mapId or ''] and not mass.seaBoulders and #mass.members>=M.MIN_CELLS) then return false end
 local n=0
 -- (PARAMS.ALL: every rock mass of the map is a hill -- Route 112's red terraces are drawn like the sand
 -- hills, their tops the path's own colour)
 local Q=M.PARAMS[mass.mapId or '']
 if Q and Q.ALL then mass.hill=true;return true end
 local gen=M.GENERAL_MAPS[mass.mapId or '']
 for _,c in ipairs(mass.members)do local t=M.TILES[c.pair];if (t and t[c.mid]) or (gen and M.GENERAL[c.mid]) then n=n+1 end end
 mass.hill=n>=M.SHARE*#mass.members
 return mass.hill
end

-- per tile: for each 4x4 patch its share of shadow pixels and of grass pixels
local function tileInfo(ts,mid)
 ts.hillTiles=ts.hillTiles or {}
 local t=ts.hillTiles[mid]
 if t~=nil then return t or nil end
 local slot=ts.midToSlot[mid]
 if not (slot and ts.imageData) then ts.hillTiles[mid]=false;return nil end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local P,N=M.P,16/M.P
 t={dark={},green={}}
 do local rs,gs=0,0
  for y=0,15 do for x=0,15 do local r,g=ts.imageData:getPixel(ox+x,oy+y);rs=rs+r;gs=gs+g end end
  t.lava=rs/256>.7 and gs/256<.32 end
 for j=0,N-1 do for i=0,N-1 do
  local d,g=0,0
  for yy=0,P-1 do for xx=0,P-1 do
   local r,gg,b=ts.imageData:getPixel(ox+i*P+xx,oy+j*P+yy)
   if ts.overImageData then local rr,g2,bb,aa=ts.overImageData:getPixel(ox+i*P+xx,oy+j*P+yy)
    if aa>.5 then r,gg,b=rr,g2,bb end end
   if .299*r+.587*gg+.114*b<M.DARK then d=d+1 end
   if gg>r*1.1 and gg>b*1.05 then g=g+1 end
  end end
  t.dark[j*N+i]=d/(P*P);t.green[j*N+i]=g/(P*P)
 end end
 ts.hillTiles[mid]=t
 return t
end

-- TIERS (per map): the hill as the drawing stacks it -- rounded mesas whose fronts are dark bands as tall as
-- the tier rises and whose sides are thin dark stripes (Route 115; user: "the mountain on 115 looks like it
-- melted ... i like the approach of like soft rocks but this looks a bit wonky", then "the terrace looks
-- super flat now"). The oblique drawing is read back column by column: walking north from the ground, every
-- band patch crossed lifts the hill (TIER_SCALE times its drawn 4 px: the drawing is flatter than 3D
-- wants), a light patch keeps the height, a stripe patch (a side flank) keeps it too and is later sloped
-- between its neighbours east and west; a top that a path runs onto is level with that path (the paths
-- are the tops). Fills h, returns true.
local D4={{1,0},{-1,0},{0,1},{0,-1}}
local steep
function M.tiers(list,D,dark,outside,base,Q,P,h,walkAt)
 local isDark,band={}, {}
 local x0,x1,z0,z1=math.huge,-math.huge,math.huge,-math.huge
 for _,p in ipairs(list)do
  isDark[p[3]]=(dark[p[3]] or 0)>=Q.TIER_DARK
  x0,x1,z0,z1=math.min(x0,p[1]),math.max(x1,p[1]),math.min(z0,p[2]),math.max(z1,p[2])
 end
 -- band or stripe: a dark patch in a run at least as wide as it is tall is a front band
 for _,p in ipairs(list)do local gx,gz,k=p[1],p[2],p[3]
  if isDark[k] then
   local w=1;local x=gx-1;while isDark[pk(x,gz)] do w=w+1;x=x-1 end;x=gx+1;while isDark[pk(x,gz)] do w=w+1;x=x+1 end
   local v=1;local z=gz-1;while isDark[pk(gx,z)] do v=v+1;z=z-1 end;z=gz+1;while isDark[pk(gx,z)] do v=v+1;z=z+1 end
   band[k]=w>=3 or w>=v
  end
 end
 local stripe={}
 for gx=x0,x1 do
  V.require('BuildBudget').tick()
  local cur
  for gz=z1,z0,-1 do
   local k=pk(gx,gz)
   if D[k] then
    if cur==nil then
     local o=outside(gx,gz+1);cur=o or base[k] or 0
    end
    -- a top beside a path is level with it
    if not isDark[k] then
     local a
     for _,d in ipairs(D4)do local f=not D[pk(gx+d[1],gz+d[2])] and walkAt(gx+d[1],gz+d[2]);if f then a=math.max(a or f,f) end end
     if a then cur=a end
    elseif band[k] then cur=cur+P*Q.TIER_SCALE
    else stripe[k]=true end
    h[k]=cur
   else cur=nil end
  end
 end
 -- each light top is one flat plateau at its columns' median height (columns crossing a mesa's rounded
 -- front cut its diagonal shading stripes at different rows and stood as a row of teeth)
 local reg,regs={}, {}
 for _,p in ipairs(list)do local k=p[3]
  if not isDark[k] and not reg[k] then
   local R={};regs[#regs+1]=R;reg[k]=R
   local st={p}
   while #st>0 do local q=table.remove(st);R[#R+1]=q
    for _,d in ipairs(D4)do local nx,nz=q[1]+d[1],q[2]+d[2];local nk=pk(nx,nz)
     if D[nk] and not isDark[nk] and not reg[nk] then reg[nk]=R;st[#st+1]={nx,nz,nk} end
    end
   end
  end
 end
 for _,R in ipairs(regs)do
  local v={};for _,q in ipairs(R)do v[#v+1]=h[q[3]] end
  table.sort(v);local m=v[math.ceil(#v/2)]
  for _,q in ipairs(R)do h[q[3]]=m end
 end
 -- the dark fronts and flanks: the slope between the tops (or the ground) either side, along the shorter
 -- way across
 local function probe(gx,gz,dx,dz)
  for s=1,16 do
   local x,z=gx+dx*s,gz+dz*s;local k=pk(x,z)
   if D[k] then if not isDark[k] then return s,h[k] end
   else local o=outside(x,z);if o then return s,o end;return nil end
  end
 end
 local out={}
 for _,p in ipairs(list)do local gx,gz,k=p[1],p[2],p[3]
  if isDark[k] then
   local sN,hN=probe(gx,gz,0,-1);local sS,hS=probe(gx,gz,0,1)
   local sE,hE=probe(gx,gz,1,0);local sW,hW=probe(gx,gz,-1,0)
   local v
   if sN and sS and not (sE and sW and sE+sW<sN+sS) then v=hS+(hN-hS)*sS/(sN+sS)
   elseif sE and sW then v=hW+(hE-hW)*sW/(sE+sW)
   else v=h[k] end
   out[k]=v
  end
 end
 for k,v in pairs(out)do h[k]=v end
 -- a light smoothing of the slopes only (the plateaus stay flat)
 for _=1,Q.TIER_SMOOTH do
  V.require('BuildBudget').tick()
  local o2={}
  for _,p in ipairs(list)do local gx,gz,k=p[1],p[2],p[3]
   if isDark[k] then
    local vals={}
    for dz=-1,1 do for dx=-1,1 do local q=pk(gx+dx,gz+dz);if D[q] and h[q] then vals[#vals+1]=h[q] end end end
    table.sort(vals);o2[k]=vals[math.ceil(#vals/2)]
   end
  end
  for k,v in pairs(o2)do h[k]=v end
 end
 return true
end

local function prepare(mass,cells)
 if mass.hillData then return mass.hillData end
 local P,N=M.P,16/M.P
 local Q=setmetatable(M.PARAMS[mass.mapId or ''] or {},{__index=M})
 local inMass={}
 for _,c in ipairs(mass.members)do inMass[c]=true end
 local D,G,dark={}, {}, {}      -- hill patches; ground patches (their floor); shadow share
 local list={}
 local gx0,gz0,gx1,gz1=math.huge,math.huge,-math.huge,-math.huge
 -- doors in the hill (Meteor Falls' entrance): walkable warp cells, ground at their floor
 local DOOR={[0x60]=true,[0x69]=true,[0x6E]=true,[0x6F]=true,[0x8D]=true}
 local door={}
 for _,c in ipairs(mass.members)do if DOOR[c.behavior or -1] and (c.collision or 0)~=7 then door[c]=true end end
 -- a patch drawn as grass is the ground beside its cell (the walkable floor next to it); with none beside it
 -- (tree crowns drawn over the rock's top) it is hill like the rest -- laid at the cell's rated floor it
 -- floated in the air over a lower hill (Route 112)
 local gf={}
 local function greenFloor(c)
  local v=gf[c];if v~=nil then return v or nil end
  v=false
  for _,d in ipairs(D4S)do
   local n=cells[ckey(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] and walk(n) then v=floorOf(n);break end
  end
  gf[c]=v;return v or nil
 end
 for _,c in ipairs(mass.members)do
  local t=tileInfo(c.ts,c.mid)
  for j=0,N-1 do for i=0,N-1 do
   local gx,gz=c.cx*N+i,c.cy*N+j
   local k=pk(gx,gz)
   if door[c] or (t and t.lava) then G[k]=floorOf(c)   -- (lava lies flat in its crater)
   elseif Q.MASK and not V.require('Gen3Rock').occupancy(mass,cells,c)[j*N+i] then G[k]=c.base or 0
   elseif t and t.green[j*N+i]>.5 and greenFloor(c) then G[k]=greenFloor(c)
   else D[k]=true;dark[k]=t and t.dark[j*N+i] or 0;list[#list+1]={gx,gz,k}
    gx0,gz0,gx1,gz1=math.min(gx0,gx),math.min(gz0,gz),math.max(gx1,gx),math.max(gz1,gz) end
  end end
 end
 -- the floor beside a patch that is not hill (nil: none known -- a tree, a
 -- building, the edge of the built window)
 local function outside(gx,gz)
  local k=pk(gx,gz)
  if G[k] then return G[k] end
  local n=cells[ckey(math.floor(gx/N),math.floor(gz/N))]
  if n and not inMass[n] and walk(n) then return floorOf(n) end
  -- (trees, water, ledges, small rocks beside a hill are ground it rises from too: counting only walkable
  -- cells left a hill against a forest standing there as a sheer 36 px slab -- Route 114's east side.
  -- Buildings and the fill outside the map are not)
  if n and not inMass[n] and not n.boundary and not (n.bldModel or n.civic or n.column or n.gym) and n.shape
   and n.shape.kind~='wall' and n.shape.kind~='roof' then return n.base or 0 end
  return nil
 end
 -- distance to the nearest walkable edge (chamfer, in patches) and that edge's floor
 local W,Hh=gx1-gx0+1,gz1-gz0+1
 local dist,lev,fixed={}, {}, {}
 local INF=1e9
 local any=false
 for _,p in ipairs(list)do
  local gx,gz,k=p[1],p[2],p[3]
  local f
  for _,d in ipairs(D4)do
   if not D[pk(gx+d[1],gz+d[2])] then local o=outside(gx+d[1],gz+d[2]);if o then f=math.max(f or o,o) end end
  end
  if f then dist[k]=.5;lev[k]=f;fixed[k]=true;any=true else dist[k]=INF end
 end
 if not any then
  -- (no walkable ground beside it at all: one mound over its lowest neighbour)
  local foot
  for _,c in ipairs(mass.members)do for _,d in ipairs(D4)do
   local n=cells[ckey(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] then local f=floorOf(n);foot=math.min(foot or f,f) end
  end end
  foot=foot or 0
  for _,p in ipairs(list)do dist[p[3]]=6;lev[p[3]]=foot end
 else
  local SQ=1.4142
  -- (each neighbour as its key offset: pk(gx+dx,gz+dz)=pk(gx,gz)+dx*16384+dz; the same sweeps in the same
  -- order, without a function call and an ipairs step per neighbour - most of Route 112's hills)
  local fwd={-16384,1,-1,1,-16385,SQ,16383,SQ}
  local bwd={16384,1,1,1,16385,SQ,-16383,SQ}
  local Tick=V.require('BuildBudget').tick
  for pass=1,2 do
   for sw=1,2 do
    local sweep=sw==1 and fwd or bwd
    local z0,z1,zs=gz0,gz1,1
    local x0,x1,xs=gx0,gx1,1
    if sw==2 then z0,z1,zs,x0,x1,xs=gz1,gz0,-1,gx1,gx0,-1 end
    local o1,c1,o2,c2,o3,c3,o4,c4=sweep[1],sweep[2],sweep[3],sweep[4],sweep[5],sweep[6],sweep[7],sweep[8]
    for gz=z0,z1,zs do
     Tick()
     for gx=x0,x1,xs do
      local k=(gx+4096)*16384+(gz+4096)
      if D[k] then
       local q=k+o1;local dq=dist[q]
       if dq and dq+c1<dist[k] then dist[k]=dq+c1;lev[k]=lev[q] end
       q=k+o2;dq=dist[q]
       if dq and dq+c2<dist[k] then dist[k]=dq+c2;lev[k]=lev[q] end
       q=k+o3;dq=dist[q]
       if dq and dq+c3<dist[k] then dist[k]=dq+c3;lev[k]=lev[q] end
       q=k+o4;dq=dist[q]
       if dq and dq+c4<dist[k] then dist[k]=dq+c4;lev[k]=lev[q] end
      end
     end
    end
   end
  end
 end
 -- the base: the nearest edge's floor, relaxed between edges on different floors
 local base={}
 for _,p in ipairs(list)do base[p[3]]=lev[p[3]] or 0 end
 -- (each free patch's neighbour keys found once, in the same order, then relaxed BLEND times)
 local free={}
 for _,p in ipairs(list)do
  local gx,gz,k=p[1],p[2],p[3]
  if not fixed[k] then free[#free+1]={k,pk(gx+1,gz),pk(gx-1,gz),pk(gx,gz+1),pk(gx,gz-1)} end
 end
 for _=1,M.BLEND do
  V.require('BuildBudget').tick()
  for _,f in ipairs(free)do
   local s,n=0,0
   local b=base[f[2]];if b then s=s+b;n=n+1 end
   b=base[f[3]];if b then s=s+b;n=n+1 end
   b=base[f[4]];if b then s=s+b;n=n+1 end
   b=base[f[5]];if b then s=s+b;n=n+1 end
   if n>0 then base[f[1]]=s/n end
  end
 end
 -- heights
 local h={}
 -- (a walkable cell beside a hill patch: its floor)
 local function walkAt(gx,gz)
  local n=cells[ckey(math.floor(gx/N),math.floor(gz/N))]
  if n and not inMass[n] and walk(n) and n.shape and n.shape.kind~='water' and not n.boundary then return floorOf(n) end
 end
 local tiered=Q.TIERS and M.tiers(list,D,dark,outside,base,Q,P,h,walkAt)
 for _,p in ipairs(list)do
  local gx,gz,k=p[1],p[2],p[3]
  local up=math.min(Q.HMAX,Q.LIP+Q.RISE*(dist[k] or 0)*P)
  local v=tiered and h[k] or base[k]+up-Q.FOLD*math.min(1,(dark[k] or 0)*1.5)
  -- (k cells south of walkable ground: at most NORTHSLOPE*k over it)
  for s=1,32 do
   local q=k-s   -- pk(gx,gz-s)
   if not D[q] then
    local o=outside(gx,gz-s)
    if o then v=math.min(v,o+M.NORTHSLOPE*(s*P)/16) end
    break
   end
  end
  h[k]=math.max(v,(lev[k] or base[k])+1)
 end
 -- shared corner heights: the mean of the hill patches round each corner
 local VH={}
 local function corner(vx,vz)
  local q=pk(vx,vz)
  local r=VH[q];if r then return r end
  local s,n=0,0
  for _,d in ipairs(DC)do
   local v=h[pk(vx+d[1],vz+d[2])];if v then s=s+v;n=n+1 end
  end
  r=n>0 and s/n or 0;VH[q]=r
  return r
 end
 -- cave mouths: a hill cell over a door (Meteor Falls' arch over its entrance) stands as a vertical face
 -- at its south edge, from the door's floor up to the hill behind it, its own drawing 1:1 at the foot
 local mouth={}
 for _,c in ipairs(mass.members)do
  local s=cells[ckey(c.cx,c.cy+1)]
  local b=s and s.behavior
  if s and (door[s] or (not inMass[s] and DOOR[b or -1])) and not door[c] then
   local top=0
   for i=0,N-1 do local v=h[pk(c.cx*N+i,(c.cy-1)*N+N-1)];if v then top=math.max(top,v) end end
   -- (the door's own tile is the arch's lower half when it is in the hill: the face carries both)
   mouth[c]={floor=floorOf(s),door=door[s] and s or nil}
   mouth[c].top=math.max(top,mouth[c].floor+(mouth[c].door and 32 or 16))
   for j=0,N-1 do for i=0,N-1 do local k=pk(c.cx*N+i,c.cy*N+j);if h[k] then h[k]=mouth[c].top end end end
  end
 end
 mass.hillData={D=D,G=G,h=h,corner=corner,outside=outside,inMass=inMass,mouth=mouth,door=door}
 return mass.hillData
end

local function sub(uv,x0,y0,x1,y1)
 local l,t,r,b=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
 local u0,u1=l+(r-l)*x0/16,l+(r-l)*x1/16
 local v0,v1=t+(b-t)*y0/16,t+(b-t)*y1/16
 return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
end

-- clip triangle (p,q,r) to y in [y0,y1]: the polygon's points
-- (keep y>=cut when above, else y<=cut; two closures per call were garbage on every steep facet)
local function clip(poly,above,cut)
 local out={}
 local n=#poly
 for i=1,n do
  local A,B=poly[i],poly[i%n+1]
  local ka,kb
  if above then ka,kb=A[2]>=cut,B[2]>=cut else ka,kb=A[2]<=cut,B[2]<=cut end
  if ka then out[#out+1]=A end
  if ka~=kb then local t=(cut-A[2])/(B[2]-A[2]);out[#out+1]={A[1]+(B[1]-A[1])*t,cut,A[3]+(B[3]-A[3])*t} end
 end
 return out
end
local function clipY(tri,y0,y1)
 local p=clip(tri,true,y0)
 if #p<3 then return p end
 return clip(p,false,y1)
end
M.STEEP_ROWS=4
steep=function(emit,own,i,j,x0,z0,Q4,southward,shade)
 local P=M.P
 local lo,hi=math.huge,-math.huge
 for _,v in ipairs(Q4)do lo,hi=math.min(lo,v[2]),math.max(hi,v[2]) end
 local L,T,R,B=own[1][1],own[1][2],own[3][1],own[3][2]
 local function uv(v,y,band)
  -- along the face: x for a face falling south or north, z for one falling east or west
  local along=southward and (v[1]-x0) or (v[3]-z0)
  local px=i*P+math.max(0,math.min(P,along))
  if not southward then px=i*P+math.max(0,math.min(P,(v[3]-z0))) end
  local row=j*P+math.max(0,math.min(M.STEEP_ROWS,band+M.STEEP_ROWS-y))*P/M.STEEP_ROWS
  return {L+(R-L)*px/16,T+(B-T)*row/16}
 end
 local S=M.STEEP_ROWS
 for _,tri in ipairs({{Q4[1],Q4[2],Q4[3]},{Q4[1],Q4[3],Q4[4]}})do
  local b=math.floor(lo/S)*S
  while b<hi do
   local poly=clipY(tri,b,b+S)
   if #poly>=3 then
    for t=2,#poly-1 do
     local A,Bv,C=poly[1],poly[t],poly[t+1]
     emit({A,Bv,C,C},{uv(A,A[2],b),uv(Bv,Bv[2],b),uv(C,C[2],b),uv(C,C[2],b)},shade)
    end
   end
   b=b+S
  end
 end
end
-- a hill patch's skirt sides: south, north, east, west (neighbour step and shade)
local SIDES={{0,1,'south'},{0,-1,'north'},{1,0,'east'},{-1,0,'west'}}
local function sidePoint(si,x0,z0,P,u,y)
 if si==1 then return {x0+u,y,z0+P} elseif si==2 then return {x0+P-u,y,z0}
 elseif si==3 then return {x0+P,y,z0+P-u} end
 return {x0,y,z0+u}
end
-- this cell's share of the hill (absolute heights)
function M.append(mass,cells,emit,uvFor,c)
 if not c then return true end
 local H=prepare(mass,cells)
 local P,N=M.P,16/M.P
 local own=uvFor(c.ts,c.mid);if not own then return true end
 if H.door[c] then
  local x,z=c.cx*16,c.cy*16
  local f=floorOf(c)
  local s=cells[ckey(c.cx,c.cy+1)]
  local g=s and uvFor(s.ts,s.mid) or own
  emit({{x,f+.02,z},{x+16,f+.02,z},{x+16,f+.02,z+16},{x,f+.02,z+16}},g,1)
  return true
 end
 local mo=H.mouth[c]
 if mo then
  local x,z=c.cx*16,c.cy*16
  local L,T,R,B=own[1][1],own[1][2],own[3][1],own[3][2]
  local function rows(r0,r1)return {{L,T+(B-T)*r0/16},{R,T+(B-T)*r0/16},{R,T+(B-T)*r1/16},{L,T+(B-T)*r1/16}} end
  -- the face: the door's drawing at the foot (when the door is in the hill), the arch's 16 rows over it,
  -- the arch's top 4 rows repeated above up to the hill
  local y=mo.floor
  if mo.door then
   local du=uvFor(mo.door.ts,mo.door.mid)
   if du then emit({{x,y+16,z+16},{x+16,y+16,z+16},{x+16,y,z+16},{x,y,z+16}},du,.86) end
   y=y+16
  end
  emit({{x,y+16,z+16},{x+16,y+16,z+16},{x+16,y,z+16},{x,y,z+16}},rows(0,16),.86)
  y=y+16
  while y<mo.top-.01 do
   local t=math.min(4,mo.top-y)
   emit({{x,y+t,z+16},{x+16,y+t,z+16},{x+16,y,z+16},{x,y,z+16}},rows(4-t,4),.86)
   y=y+t
  end
  -- its top, level with the hill behind, in its own top rows
  for j=0,N-1 do emit({{x,mo.top,z+j*P},{x+16,mo.top,z+j*P},{x+16,mo.top,z+j*P+P},{x,mo.top,z+j*P+P}},rows(0,4),1) end
  -- its sides, down to the floor, where the hill beside it is lower
  for _,sd in ipairs({{-1,x},{1,x+16}})do
   local nh=H.h[pk(c.cx*N+(sd[1]<0 and -1 or N),c.cy*N+N-1)]
   if not nh or nh<mo.top-.5 then
    local lo=nh and math.max(nh,mo.floor) or mo.floor
    local X=sd[2]
    if sd[1]<0 then emit({{X,mo.top,z},{X,mo.top,z+16},{X,lo,z+16},{X,lo,z}},rows(0,4),.7)
    else emit({{X,mo.top,z+16},{X,mo.top,z},{X,lo,z},{X,lo,z+16}},rows(0,4),.74) end
   end
  end
  return true
 end
 for j=0,N-1 do for i=0,N-1 do
  local gx,gz=c.cx*N+i,c.cy*N+j
  local k=pk(gx,gz)
  local x0,z0=gx*P,gz*P
  if H.D[k] then
   local a,b,cc,d=H.corner(gx,gz),H.corner(gx+1,gz),H.corner(gx+1,gz+1),H.corner(gx,gz+1)
   -- slope shading: the facet's normal against the light
   local dx=((b+cc)-(a+d))/(2*P);local dz=((d+cc)-(a+b))/(2*P)
   local nl=math.sqrt(dx*dx+1+dz*dz)
   local dot=(-dx*LX+LY-dz*LZ)/nl
   local shade=math.max(.6,math.min(1.08,.76+.24*dot/LY))
   if math.max(math.abs(a-b),math.abs(b-cc),math.abs(cc-d),math.abs(d-a),math.abs(a-cc),math.abs(b-d))<=P*1.05 then
    emit({{x0,a,z0},{x0+P,b,z0},{x0+P,cc,z0+P},{x0,d,z0+P}},sub(own,i*P,j*P,i*P+P,j*P+P),shade)
   else
    -- a steep facet (a tier's front): laid from above its 4 drawn rows stretched up the whole face. It is
    -- cut into bands of STEEP_ROWS px of world height, each showing the patch's own rows 1:1 (repeated up
    -- the face, never stretched); u runs along the face, across the slope's fall
    steep(emit,own,i,j,x0,z0,{{x0,a,z0},{x0+P,b,z0},{x0+P,cc,z0+P},{x0,d,z0+P}},math.abs(dz)>=math.abs(dx),shade)
   end
   -- skirts down to lower ground beside the hill
   -- (the four sides south, north, east, west from one fixed table: built per patch, with a closure
   -- each, they were a large share of a hill's garbage without the JIT)
   for si=1,4 do
    local sd=SIDES[si]
    local sx,sz=sd[1],sd[2]
    local q=k+sx*16384+sz   -- pk(gx+sx,gz+sz)
    if not H.D[q] then
     local F=H.outside(gx+sx,gz+sz)
     if F==nil then
      -- (beside a tree, a building or water: down to that cell's own floor)
      local n=cells[ckey(math.floor((gx+sx)/N),math.floor((gz+sz)/N))]
      F=n and (n.base or 0) or nil
     end
     local t0,t1,u7
     if si==1 then t0,t1,u7=d,cc,i*P elseif si==2 then t0,t1,u7=b,a,16-(i+1)*P
     elseif si==3 then t0,t1,u7=cc,b,16-(j+1)*P else t0,t1,u7=a,d,j*P end
     if F and math.max(t0,t1)>F+.01 then
      local y=F
      while y<math.max(t0,t1)-.01 do
       local yt=math.min(math.max(t0,t1),y+16)
       local a0,a1=math.max(y,math.min(yt,t0)),math.max(y,math.min(yt,t1))
       local rows=math.min(16,yt-y)
       local uvs=sub(own,u7,16-rows,u7+P,16)
       emit({sidePoint(si,x0,z0,P,0,a0),sidePoint(si,x0,z0,P,P,a1),sidePoint(si,x0,z0,P,P,y),sidePoint(si,x0,z0,P,0,y)},uvs,SHADE[sd[3]])
       y=yt
      end
     end
    end
   end
  elseif H.G[k] then
   -- a patch drawn as grass: ground, at its floor
   local f=H.G[k]+.02
   emit({{x0,f,z0},{x0+P,f,z0},{x0+P,f,z0+P},{x0,f,z0+P}},sub(own,i*P,j*P,i*P+P,j*P+P),1)
   -- and closed up to a higher floor beside it outside the hill, facing into the patch (Route 115's
   -- nook: a grass patch of the cliff's corner lay open under the raised fence row south of it)
   for _,s in ipairs({{0,1,function(u,y)return {x0+P-u,y,z0+P}end,SHADE.north},{0,-1,function(u,y)return {x0+u,y,z0}end,SHADE.south},
                      {1,0,function(u,y)return {x0+P,y,z0+u}end,SHADE.west},{-1,0,function(u,y)return {x0,y,z0+P-u}end,SHADE.east}})do
    local q=pk(gx+s[1],gz+s[2])
    local n=cells[ckey(math.floor((gx+s[1])/N),math.floor((gz+s[2])/N))]
    if not H.D[q] and not H.G[q] and n and n~=c and not n.boundary and not (n.bldModel or n.civic or n.column or n.gym) then
     if not H.inSet then H.inSet={};for _,m in ipairs(mass.members)do H.inSet[m]=true end end
     local F2=not H.inSet[n] and floorOf(n)
     if F2 and F2>H.G[k]+.01 then
      local y=H.G[k]
      while y<F2-.01 do
       local yt=math.min(F2,y+16)
       emit({s[3](0,yt),s[3](P,yt),s[3](P,y),s[3](0,y)},sub(own,i*P,16-(yt-y),i*P+P,16),s[4])
       y=yt
      end
     end
    end
   end
  end
 end end
 return true
end

-- (for Gen3Relief: the same patch cut and steep bands)
M.sub=sub
M.steep=steep

return M
