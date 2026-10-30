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
M.MAPS={EM_ROUTE111=true,EM_ROUTE114=true}
M.LEVEL=24         -- px a level climbs beyond the ground beside the mass (3DS: 16)
M.SHARE=.6         -- share of a mass's cells that must be General mountain tiles
M.MIN_CELLS=6      -- smaller groups are stones (Gen3Rock / Gen3Mass)
M.P=4
M.EDGE_RUN=3       -- cells a rock at the map edge runs on into the boundary fill (then it drops in a wall)
M.TINY=4           -- px: a wall this low is a sliver
M.SNAP=6          -- px: an edge this close to the ground beside it is flush with it
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
 local cache={}
 local n,known=0,0
 for _,c in ipairs(mass.members)do
  if cellOf(D,cache,c.cx,c.cy) then
   known=known+1
   local t=fall[c.pair]
   if gen[c.mid] or (t and t[c.mid]) then n=n+1 end
  end
 end
 -- (a mass's members outside the map -- the boundary fill -- have no relief and do not count; masses
 -- that grow as the near window grows must not flip back and forth, so the share is of the known cells)
 mass.relief=n>=M.MIN_CELLS and n>=M.SHARE*known
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

local function prepare(mass,cells)
 if mass.reliefData then return mass.reliefData end
 local D=data(mass.mapId)
 local cache={}
 local inMass={}
 for _,c in ipairs(mass.members)do inMass[c]=true end
 local A=anchors(mass,cells,D,cache,inMass)
 local hf=heightFn(A)
 local R={D=D,cache=cache,inMass=inMass,H={},E={}}
 for _,c in ipairs(mass.members)do
  local e=cellOf(D,cache,c.cx,c.cy)
  if e and not DOOR[c.behavior or -1] then
   local h={}
   for k=1,25 do h[k]=hf(e.g[k])+e.d[k] end
   R.H[c]=h
   R.E[c]=e
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
 local sub,steep=Hills.sub,Hills.steep
 local own=uvFor(c.ts,c.mid);if not own then return true end
 local h=R.H[c]
 local P=M.P
 local x,z=c.cx*16,c.cy*16
 if not h then
  -- a cell the bake has no relief for (a door in the rock): flat at its floor
  local f=floorOf(c)+.02
  emit({{x,f,z},{x+16,f,z},{x+16,f,z+16},{x,f,z+16}},own,1)
  return true
 end
 -- the top: one facet per 4x4 patch
 for j=0,3 do for i=0,3 do
  local a,b,cc,d=h[j*5+i+1],h[j*5+i+2],h[(j+1)*5+i+2],h[(j+1)*5+i+1]
  local x0,z0=x+i*P,z+j*P
  local dx=((b+cc)-(a+d))/(2*P);local dz=((d+cc)-(a+b))/(2*P)
  local nl=math.sqrt(dx*dx+1+dz*dz)
  local dot=(-dx*LX+LY-dz*LZ)/nl
  local shade=math.max(.6,math.min(1.08,.76+.24*dot/LY))
  if math.max(math.abs(a-b),math.abs(b-cc),math.abs(cc-d),math.abs(d-a),math.abs(a-cc),math.abs(b-d))<=P*1.05 then
   emit({{x0,a,z0},{x0+P,b,z0},{x0+P,cc,z0+P},{x0,d,z0+P}},sub(own,i*P,j*P,i*P+P,j*P+P),shade)
  else
   steep(emit,own,i,j,x0,z0,{{x0,a,z0},{x0+P,b,z0},{x0+P,cc,z0+P},{x0,d,z0+P}},math.abs(dz)>=math.abs(dx),shade)
  end
 end end
 -- walls where an edge stands over what lies beside it
 local e=R.E[c]
 local face=own
 if e.wx then
  local w=cells[ckey(e.wx,e.wy)]
  local u=w and uvFor(w.ts,w.mid)
  if u then face=u end
 end
 -- point on the edge at 4 px step u (0..P), side-specific as Gen3Hills' skirts
 local sides={
  {'S',function(k,u,y)return {x+k*P+u,y,z+16} end,function(k)return k*P end,SHADE.south},
  {'N',function(k,u,y)return {x+16-(k*P+u),y,z} end,function(k)return k*P end,SHADE.north},
  {'E',function(k,u,y)return {x+16,y,z+16-(k*P+u)} end,function(k)return k*P end,SHADE.east},
  {'W',function(k,u,y)return {x,y,z+k*P+u} end,function(k)return k*P end,SHADE.west}}
 for _,s in ipairs(sides)do
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
       emit({s[2](k,0,a0),s[2](k,P,a1),s[2](k,P,y),s[2](k,0,y)},sub(own,s[3](k),0,s[3](k)+P,math.min(rows,P)),s[4])
      else
       emit({s[2](k,0,a0),s[2](k,P,a1),s[2](k,P,y),s[2](k,0,y)},sub(face,s[3](k),16-rows,s[3](k)+P,16),s[4])
      end
      y=yt
     end
    end
   end
  end
 end
 return true
end

return M
