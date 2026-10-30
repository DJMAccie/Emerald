-- Rock masses rebuilt from their own drawing, one art pixel = one voxel.
--
-- Emerald draws a mountain as one oblique picture: the top of the rock is seen
-- from above, its front face head-on, and a point at depth z and height h
-- lands on picture row y = z - h (one pixel per world unit on both axes). That
-- projection can be undone column by column:
--   * the rock rows at the bottom of a column (FACE at most: one tile of face
--     art) are the vertical face: a wall, one voxel per pixel, never stretched;
--   * every other rock pixel of the column is top surface, laid flat at the
--     wall's height, each pixel shifted south by it (z = y + h).
-- The old dome textured two FireRed tiles over a smooth mound; this uses the
-- map's own tiles, so what you see is the original art standing up. Where
-- neighbouring columns differ in height the gap is closed with wall colour.
--
-- Small low things (a boulder in the sea, a planter, a bench) are drawn in the
-- same oblique view but are not a tile tall: their wall is the lower half of
-- the column (M.appendObject), so a boulder is as high as it is deep.
local V=...
local Objects=V.require('Gen3Objects')
local M={}

M.FACE=16            -- height of the wall, in voxels (one tile of face art)
M.SHEER=.72          -- share of dark pixels that makes a tile pure face
M.TALL=96            -- tallest sheer wall, in voxels (six tiles of face art)
M.MINTALL=24         -- tall wall columns (pixels wide) a wall-dominated mass needs to be rebuilt
M.CAP=12             -- thickness of a tall wall (flat top and back face), in voxels
M.WALLY=.35          -- a mass this much sheer wall is a cliff face, not a hill: left to the old dome
M.enabled=true
M.GROVES=false       -- packed groves (bank + grove) are masses too: trunk face below, canopy seen from above
M.THIN_WIDTH=3       -- a sea-rock piece this narrow, or this empty (an arc), is an outline
M.THIN_FILL=.3
M.LEAN=.55          -- share of the view-line lean kept by a tall rock
M.LEAN_BIG=.3        -- a big rock (two tiles) keeps less still: it would stand as a leaning fin
M.BIG_FROM=24
M.LEAN_FROM=12       -- rock height (rows) from which it applies
M.PILLAR_MIN=60     -- pixels a piece needs to count as the pillar (the rest is specks)
M.PILLAR_W=40       -- widest free-standing rock pillar (pixels)
M.PILLAR_H=80
M.SEAM=24           -- column steps up to this many pixels deep are closed with a side face (bigger ones are other terraces)
M.LIDMAX=48         -- deepest a tall wall's lid is made when it runs back to a terrace
M.APRON=64          -- tallest gap between a cliff's lid and the terrace behind it that is closed with a face
M.JOIN=2            -- sea boulder pieces this close (pixels) are one stone
M.DOME=true          -- round low things (boulders, sea rocks) become bodies of revolution, not walls
M.BULGE=.9           -- body depth as a share of a row's half-width
M.SOLID_STONES=true -- see solidSet
M.LONE_SEA_ROCK={[0x150]=true,[0x151]=true,[0x158]=true,[0x159]=true,[0x152]=true,[0x153]=true,[0x15A]=true,[0x15B]=true,[0x175]=true,[0x176]=true,[0x17D]=true,[0x17E]=true}
M.STONE_LEAN=0
M.TIP=.4   -- narrowest a stone's drawn row may be, as a share of its widest (solidSet)
M.SEA_DEPTH=1.3     -- the same for a boulder in the sea
M.DEPTH=.6          -- deepest a body may be, as a share of its own height (half depth each side)
M.FOOT=3             -- rows above the ground over which a dome grows from its foot line
local E=.03         -- strips overlap this much so no hairline shows between them

local function key(x,y)return x..':'..y end
-- near-white or grey with no warmth: the foam round a sea rock, never the rock (rock pixels are warm)
function M.isFoam(r,g,b)
 local mx,mn=math.max(r,g,b)*255,math.min(r,g,b)*255
 return (mx-mn)<40 and (r*255)<=(b*255)+10 and (r+g+b)/3*255>150
end
local function lum(r,g,b)return .299*r+.587*g+.114*b end

local function pixel(ts,x,y)
 local r,g,b,a=ts.imageData:getPixel(x,y)
 if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(x,y)
  if aa>0 then r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),math.max(a,aa) end
 end
 return r,g,b,a
end
local function origin(ts,mid)
 local slot=ts.midToSlot[mid];if not slot then return end
 return slot%ts.cols*16,math.floor(slot/ts.cols)*16
end
-- every colour the ground tile uses (animated water never matches pixel for pixel)
-- (one set per tile and tileset within a build, so Gen3Objects.cut can know it again: see its memo)
local colourMemo=setmetatable({},{__mode='k'})
function M.newBuild()colourMemo=setmetatable({},{__mode='k'})end
local coloursRaw
local function colours(ts,mid)
 local byTs=colourMemo[ts];if not byTs then byTs={};colourMemo[ts]=byTs end
 local e=byTs[mid]
 if not e then e={coloursRaw(ts,mid)};byTs[mid]=e end
 return e[1],e[2]
end
coloursRaw=function(ts,mid)
 local ox,oy=origin(ts,mid);if not ox then return end
 local set,blue,n={},0,0
 for y=0,15 do for x=0,15 do
  local r,g,b=pixel(ts,ox+x,oy+y)
  set[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)]=true
  n=n+1;if b>r*1.3 and b>=g then blue=blue+1 end
 end end
 return set,blue/n>.6
end

local function solidKind(c)
 local k=c and c.shape and c.shape.kind
 return k=='cliff' or k=='caveWall'
end
M.caves=false    -- cave interiors do not follow the outdoor oblique layout (tried: stripes); they keep Gen3Terrain
M.RIM=3          -- cave wall cells deeper than this inside the rock stay a flat top
M.WATER_EDGE={[0x164]=true,[0x16C]=true}   -- sea-edge tiles drawn almost all water: stood as a raised blue slab
local function mine(c)
 local s=c.shape
 if not (s and c.ts and c.ts.imageData and c.ts.midToSlot[c.mid]) then return false end
 -- (in a cave a furniture cell is never rock, whatever its tile is listed as)
 if M.caves and c.prop then return false end
 if s.kind=='caveWall' then return M.caves and (M.caveAll or c.rim==true) end
 if M.WATER_EDGE[c.mid] and (V.require('Gen3Rock').mapId or '')=='EM_SLATEPORT_CITY' then return false end
 return s.kind=='cliff' and (M.outdoor or M.caves) and not s.seaRock and (M.GROVES or not s.grove)
end
-- Cave walls: only the rim (within M.RIM cells of open ground) is rebuilt; the
-- deep interior of a thick wall is hidden behind it and gets a flat top.
local function markRim(cells)
 for _,c in pairs(cells)do
  if c.shape and c.shape.kind=='caveWall' then
   local near=false
   for dy=-M.RIM,M.RIM do for dx=-M.RIM,M.RIM do
    local n=cells[key(c.cx+dx,c.cy+dy)]
    if n and not solidKind(n) and not n.boundary then near=true;break end
   end if near then break end end
   c.rim=near;c.caveFlat=M.caves and not M.caveAll and not near
  end
 end
end

-- Group the scene's rock cells into masses and give every member c.mass.
-- Two rock cells belong to one mass when they touch and are the same sort of rock. A sea stack is
-- drawn with three kinds of tile (sea-rock tiles, real cliff tiles, a walkable rock top); each used
-- to be built by its own path, so the stack came out in pieces with arches between them.
local function sameMass(a,b)
 if (a.shape.kind=='caveWall')~=(b.shape.kind=='caveWall') then return false end
 if a.shape.sea or b.shape.sea then return true end
 return (a.shape.bank or false)==(b.shape.bank or false)
end
-- a rock standing in the sea that Gen3Objects built as an object (its tiles are 'flat' to the scene)
local function seaObject(c)
 local o=c.object or c.objectTop
 return o and o.water and c.ts and c.ts.imageData and c.ts.midToSlot[c.mid] and true or false
end
M.SPLIT_GENERAL={EM_ROUTE112=true}
-- per map: cells inside the box {x0,y0,x1,y1} and cells outside it are separate masses (Sky Pillar's dome, which has counted heights, apart from the ridges, which stand level with the ground)
M.SPLIT_BOX={EM_SKY_PILLAR_OUTSIDE={14,9,21,13}}
local function inBox(c,B)return c.cx>=B[1] and c.cx<=B[3] and c.cy>=B[2] and c.cy<=B[4] end
M.STACK=40      -- most cells a sea stack may have; a bigger group is a plateau and is never merged across tile kinds
-- Flood from `c`. merge=true also joins touching sea rocks (objects, banks) and cliff tiles into one mass.
local function flood(cells,c,seen,merge)
 local visited,members,stack={[c]=true},{}, {c}
 local bank,sea,cross=false,false,false
 while #stack>0 do
  local p=table.remove(stack);members[#members+1]=p
  if p.shape.bank then bank=true end
  if p.shape.sea then sea=true end
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[key(p.cx+d[1],p.cy+d[2])]
   if n and not visited[n] and not seen[n] and n.pair==c.pair then
    local take=false
    -- (per map: the General primary's pink mountain and the secondary tileset's rock are separate masses
    -- -- Route 112's pink ridge beside Mt. Chimney's red cliffs is a hill (Gen3Hills), the red is rock)
    local split=M.SPLIT_GENERAL[V.require('Gen3Rock').mapId or ''] and ((p.mid>=0x068 and p.mid<=0x0BF)~=(n.mid>=0x068 and n.mid<=0x0BF))
    local B=M.SPLIT_BOX[V.require('Gen3Rock').mapId or '']
    if B and inBox(p,B)~=inBox(n,B) then split=true end
    if split then
    elseif mine(n) then
     if merge then take=(not mine(p)) or sameMass(p,n)
      -- (a 2x2 sea boulder and a land rock are never one mass, even with a sea-rock tile between them:
      -- Route 118's river stones joined the bank rock and the lot stood as one sand-coloured dome)
      if take and M.LONE_SEA_ROCK[n.mid] and not M.LONE_SEA_ROCK[c.mid] and not (c.shape.sea or c.shape.bank) then take=false end
      if take and M.LONE_SEA_ROCK[c.mid] and not M.LONE_SEA_ROCK[n.mid] and not (n.shape.sea or n.shape.bank) then take=false end
     else take=mine(p) and (n.shape.kind=='caveWall')==(c.shape.kind=='caveWall') and (n.shape.bank or false)==(c.shape.bank or false) and (n.shape.sea or false)==(c.shape.sea or false) end
     if take and merge and ((n.shape.sea or false)~=(p.shape.sea or false) or (n.shape.bank or false)~=(p.shape.bank or false)) then cross=true end
    -- (a 2x2 sea boulder beside a cliff is its own stone: taken into the cliff it was built by course into
    -- an open lattice of slats -- Route 104)
    elseif merge and seaObject(n) and not (M.LONE_SEA_ROCK[n.mid] and n.shape.kind~='cliff') then take=true;sea=true;cross=true end
    if take then visited[n]=true;stack[#stack+1]=n end
   end
  end
 end
 return members,bank,sea,cross
end
function M.prepare(cells,outdoor)
 local list={}
 if not M.enabled then return list end
 M.outdoor=outdoor
 -- (caves on Gen3Rock.CAVES: every wall cell is rock, built by Gen3Rock)
 do local Rock=V.require('Gen3Rock');M.caves=Rock.CAVES[Rock.mapId or ''] and true or false;M.caveAll=M.caves end
 markRim(cells)
 local seen={}
 -- (in map order, north-west first: pairs() order changes from load to load, and which cell a flood
 -- starts from decides whether the river stones beside a bank rock join it -- Route 118 came out as
 -- a sand-coloured dome one time and a red rock with stones the next)
 -- (biggest plain rock group first, so a cliff that reaches a small rock through the sea rocks between
 -- them claims its own cells before the small rock can take the sea rocks for itself)
 local order={}
 for _,c in pairs(cells)do if mine(c) then order[#order+1]=c end end
 table.sort(order,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
 do
  local size,done={}, {}
  for _,c in ipairs(order)do if not done[c] then
   local members=flood(cells,c,done,false)
   for _,m in ipairs(members)do done[m]=true;size[m]=#members end
  end end
  for i,c in ipairs(order)do c.massOrder=i end
  table.sort(order,function(a,b)
   local sa,sb=size[a] or 0,size[b] or 0
   if sa~=sb then return sa>sb end
   return a.massOrder<b.massOrder end)
 end
 for _,c in ipairs(order)do
  if not seen[c] then
   local members,bank,sea,cross=flood(cells,c,seen,true)
   if cross and #members>M.STACK then members,bank,sea=flood(cells,c,seen,false) end
   for _,m in ipairs(members)do seen[m]=true end
   -- the walkable top of a stack (plain ground tiles with rock on every side) is part of the rock
   if sea and cross then
    local inside={}
    for _,m in ipairs(members)do inside[m]=true end
    for _=1,3 do
     local add={}
     for _,m in ipairs(members)do
      for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
       local n=cells[key(m.cx+d[1],m.cy+d[2])]
       if n and not inside[n] and n.pair==c.pair and n.shape and n.shape.kind=='flat' and n.ts and n.ts.midToSlot[n.mid] then
        local around=0
        for _,e in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if inside[cells[key(n.cx+e[1],n.cy+e[2])] or false] then around=around+1 end end
        if around>=3 then add[n]=true end
       end
      end
     end
     local any=false
     for n in pairs(add)do inside[n]=true;members[#members+1]=n;any=true end
     if not any then break end
    end
   end
   local x0,y0,x1,y1=c.cx,c.cy,c.cx,c.cy
   for _,m in ipairs(members)do x0=math.min(x0,m.cx);y0=math.min(y0,m.cy);x1=math.max(x1,m.cx);y1=math.max(y1,m.cy) end
   local mass={members=members,x0=x0,y0=y0,x1=x1,y1=y1,ts=c.ts,owner=c,bank=bank,seaBoulders=sea,mapId=V.require('Gen3Rock').mapId}
   for _,m in ipairs(members)do
    m.mass=mass
    local o=m.object or m.objectTop
    if o and o.water and seaObject(m) then o.merged=true end
   end
   list[#list+1]=mass
  end
 end
 return list
end

-- Picture of the mass: pixel -> {r,g,b,cell,lx,ly} for rock pixels (ground cut away).
-- The water next to a mass (a chain of sea boulders too long for an object): its
-- tile is the ground the boulders were drawn on.
local function seaGround(mass,cells)
 if mass.sea~=nil then return mass.sea end
 mass.sea=false
 if not cells then return false end
 for _,c in ipairs(mass.members)do
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and n.mass~=mass and n.shape and n.shape.kind=='water' and n.ts==c.ts then mass.sea=n.mid;return n.mid end
  end
 end
 return false
end
local function picture(mass,cells)
 local W,H=(mass.x1-mass.x0+1)*16,(mass.y1-mass.y0+1)*16
 local pic={}
 local lums={}
 for _,c in ipairs(mass.members)do
  local mask=mass.masks and mass.masks[c]
  if not mask and not mass.masks then
   local g=c.shape.ground or 1
   local sea=mass.seaBoulders and seaGround(mass,cells)
   if sea then g=sea end
   local grounds={g};if g~=1 then grounds[#grounds+1]=1 end
   -- (a lone stone: the ground it is drawn on is the one round it, first -- a tileset's default ground is
   -- grass, and a boulder drawn on Fallarbor's dirt kept the dirt round it as part of the stone)
   if cells and not sea and mass.boulder then
    if not mass.groundTiles then
     mass.groundTiles={}
     for _,m in ipairs(mass.members)do for _,dd in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}})do
      local n=cells[key(m.cx+dd[1],m.cy+dd[2])]
      if n and n.mass~=mass and n.ts==m.ts and (n.collision or 0)==0 and n.shape and n.shape.kind=='flat' then mass.groundTiles[n.mid]=true end
     end end
    end
    local voted=M.ground(mass,cells)
    if voted and voted~=g then table.insert(grounds,1,voted) end
   end
   local byColour
   local set,water=colours(c.ts,g)
   if water then byColour=set end
   mask=Objects.cut(c.ts,c.mid,grounds,nil,byColour)
  end
  local ox,oy=origin(c.ts,c.mid)
  if mask then
   for ly=0,15 do for lx=0,15 do
    if mask[ly*16+lx] then
     local r,g,b,a=pixel(c.ts,ox+lx,oy+ly)
     if a>.5 then
      local X,Y=(c.cx-mass.x0)*16+lx,(c.cy-mass.y0)*16+ly
      -- foam (white, grey, no red in it) is a splash on the water, not stone: a flat decal, never a body
      if mass.seaBoulders and M.isFoam(r,g,b) then
       mass.foam=mass.foam or {}
       mass.foam[#mass.foam+1]={X,Y,c,lx,ly}
      else
       pic[Y*W+X]={r,g,b,c,lx,ly}
       lums[#lums+1]=lum(r,g,b)
      end
     end
    end
   end end
  end
 end
 mass.W,mass.H,mass.pic=W,H,pic
 local n=#lums
 if n==0 then return false end
 if mass.object or mass.seaBoulders then return true end
 -- Otsu split of the rock's luminance: dark = face, light = top
 table.sort(lums)
 local best,cut=-1,lums[math.floor(n/2)+1]
 local total=0;for _,v in ipairs(lums)do total=total+v end
 local sumB,wB=0,0
 for i=1,n-1 do
  sumB=sumB+lums[i];wB=i
  if lums[i+1]>lums[i] then
   local wF=n-wB;local mB=sumB/wB;local mF=(total-sumB)/wF
   local between=wB*wF*(mB-mF)^2
   if between>best then best=between;cut=(lums[i]+lums[i+1])/2 end
  end
 end
 local dark,all={}, {}
 for _,p in pairs(pic)do
  local c=p[4];all[c]=(all[c] or 0)+1
  if lum(p[1],p[2],p[3])<cut then dark[c]=(dark[c] or 0)+1 end
 end
 -- a mass that is mostly sheer face tiles is a wall of rock, not a hill
 local sheer,cellsN=0,0
 mass.sheer={}
 for c,k in pairs(all)do
  cellsN=cellsN+1
  if k>=160 and (dark[c] or 0)/k>=M.SHEER then sheer=sheer+1;mass.sheer[c]=true end
 end
 mass.wally=cellsN>0 and sheer/cellsN>=M.WALLY
 return true
end

-- Foot of the mass: the lowest floor around it.
local function foot(mass,cells)
 local low=math.huge
 for _,c in ipairs(mass.members)do
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and n.mass~=mass and n.shape and n.shape.kind~='water' then low=math.min(low,n.floorHigh or n.base or 0) end
  end
 end
 return low==math.huge and 0 or low
end

-- Atlas sub-rectangle of a tile, 1:1 (never a stretch): pixels l..r, t..b.
local function sub(uv,l,t,r,b)
 local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end
 return {p(l,t),p(r,t),p(r,b),p(l,b)}
end

-- ROUND LOW THINGS. A boulder drawn as a dome is not a wall with a lid: every pixel is placed on a
-- rounded body along the view direction (NativeTreeArt.lathe does the same for trees). Row k of the
-- picture is the line z - height = k; a point with depth d at height up is at z = foot + d, height up + d
-- on the front shell, z = foot - d, up - d on the rear shell: both project onto the pixel's own row, so
-- from the player's camera it is the drawing pixel for pixel, from elsewhere a bulging solid.
local D4={{1,0},{-1,0},{0,1},{0,-1}}
local function components(pic,W,H,gap)
 gap=gap or 1
 local seen,comps={}, {}
 for k in pairs(pic)do
  if not seen[k] then
   local list,stack={}, {k};seen[k]=true
   while #stack>0 do
    local q=table.remove(stack);list[#list+1]=q
    local x,y=q%W,math.floor(q/W)
    if gap<=1 then
     for i=1,4 do local d=D4[i]   -- (D4 made once: a new list per pixel was most of this flood)
      local nx,ny=x+d[1],y+d[2]
      if nx>=0 and ny>=0 and nx<W and ny<H then
       local nk=ny*W+nx
       if pic[nk] and not seen[nk] then seen[nk]=true;stack[#stack+1]=nk end
      end
     end
    else
     -- pieces of one body separated by a thin gap (a dark crescent and its light face with a foam line between)
     for dy=-gap,gap do for dx=-gap,gap do
      local nx,ny=x+dx,y+dy
      if (dx~=0 or dy~=0) and nx>=0 and ny>=0 and nx<W and ny<H then
       local nk=ny*W+nx
       if pic[nk] and not seen[nk] then seen[nk]=true;stack[#stack+1]=nk end
      end
     end end
    end
   end
   comps[#comps+1]=list
  end
 end
 return comps
end
-- A component is round when it fills about a circle's share of its box and narrows toward the top
local function roundish(list,W,loose)
 local x0,x1,y0,y1=1e9,-1,1e9,-1
 local rowW={}
 for _,k in ipairs(list)do
  local x,y=k%W,math.floor(k/W)
  if x<x0 then x0=x end;if x>x1 then x1=x end;if y<y0 then y0=y end;if y>y1 then y1=y end
  rowW[y]=(rowW[y] or 0)+1
 end
 local w,h=x1-x0+1,y1-y0+1
 if w<6 or h<5 then return false end
 local fill=#list/(w*h)
 if fill<(loose and .5 or .55) or fill>(loose and .95 or .9) then return false end
 if w/h>2.8 or h/w>2.2 then return false end
 local top=rowW[y0] or 0
 local widest=0;for _,v in pairs(rowW)do if v>widest then widest=v end end
 return top<=.75*widest
end
local function extractDomes(mass,cells)
 mass.domes={}
 if not M.DOME then return end
 local W,H,pic=mass.W,mass.H,mass.pic
 local comps=components(pic,W,H,mass.seaBoulders and M.JOIN or 1)
 -- a free-standing pillar of rock (Jagged Pass's 2 x 4 cell column): one small component that is not a cliff
 -- face is a stone with a rounded top, not a wall
 local pillar=false
 local big,main=0,nil
 for _,l in ipairs(comps)do if #l>=M.PILLAR_MIN then big=big+1;main=l end end
 if not (mass.object or mass.seaBoulders) and mass.wally==false and big==1 then
  local lx,hx,ly,hy=1e9,-1,1e9,-1
  for _,k in ipairs(main)do local x,y=k%W,math.floor(k/W);if x<lx then lx=x end;if x>hx then hx=x end;if y<ly then ly=y end;if y>hy then hy=y end end
  pillar=(hx-lx+1)<=M.PILLAR_W and (hy-ly+1)<=M.PILLAR_H
 end
 -- (a lone boulder on land: a mass of one or two cells -- Route 118's beach rocks -- is a stone, not a
 -- wall with its drawing on the front, which from behind was a flat square card)
 if not (mass.object or mass.seaBoulders) and mass.members and #mass.members<=2 then
  local x0,y0,x1,y1=1e9,1e9,-1e9,-1e9
  for _,m in ipairs(mass.members)do x0,y0,x1,y1=math.min(x0,m.cx),math.min(y0,m.cy),math.max(x1,m.cx),math.max(y1,m.cy) end
  if x1-x0<=1 and y1-y0<=1 then mass.boulder=true end
 end
 if not (mass.object or mass.seaBoulders or pillar or mass.boulder) then return end
 -- a sea clump drawn three or more rows tall is several boulders one behind
 -- another (the drawing climbs north): cut it into 32-row bands, each its own boulder standing on the water at its own depth
 -- (as one body it stood 160 px up, a rock hanging in the sky: Route 127)
 if mass.seaBoulders then
  local out={}
  for _,list in ipairs(comps)do
   local lx,hx,ly,hy=1e9,-1,1e9,-1
   for _,k in ipairs(list)do local x,y=k%W,math.floor(k/W);if x<lx then lx=x end;if x>hx then hx=x end;if y<ly then ly=y end;if y>hy then hy=y end end
   local bw,bh=hx-lx+1,hy-ly+1
   if #list>=10 and bh>=48 then
    local band=32
    local parts={}
    for _,k in ipairs(list)do local y=math.floor(k/W);local i=math.floor((hy-y)/band);parts[i]=parts[i] or {};table.insert(parts[i],k) end
    for _,pl in pairs(parts)do pl.band=true;out[#out+1]=pl end
   else out[#out+1]=list end
  end
  comps=out
 end
 for _,list in ipairs(comps)do
  -- every blob of a boulder chain in the sea is a rock and gets a body; on land only the round ones do
  -- (a planter or a bench stays a box)
  local bw,bh
  do local lx,hx,ly,hy=1e9,-1,1e9,-1
   for _,k in ipairs(list)do local x,y=k%W,math.floor(k/W);if x<lx then lx=x end;if x>hx then hx=x end;if y<ly then ly=y end;if y>hy then hy=y end end
   bw,bh=hx-lx+1,hy-ly+1 end
  -- a boulder is no taller than about twice its width: a tall strip (a rock face along a shore) is a wall
  local stoneShaped=bh<=2*bw or list.band
  local thin=false
  if mass.seaBoulders and #list>=10 and not list.band then
   -- the grey outline round a rock island's foot (a 1-2 px wide strip hugging the tile edge): a line on the water,
   -- never a body (as a dome each strip stood up as a thin post with a curved foot)
   thin=math.min(bw,bh)<=M.THIN_WIDTH or #list/(bw*bh)<M.THIN_FILL
  end
  if mass.seaBoulders and thin then
   mass.foam=mass.foam or {}
   for _,k in ipairs(list)do local p=pic[k];mass.foam[#mass.foam+1]={k%W,math.floor(k/W),p[4],p[5],p[6]};pic[k]=nil end
  elseif mass.seaBoulders and #list<10 then
   -- specks of rock-coloured foam/shading: not a stone. (As wall columns they were thin grey slabs.)
   for _,k in ipairs(list)do pic[k]=nil end
  elseif (mass.seaBoulders and stoneShaped) or (mass.boulder and #list>=10) or roundish(list,W,mass.seaBoulders or pillar) then
   local set,x0,x1,y0,y1={}, 1e9,-1,1e9,-1
   local lo,hi={}, {}
   for _,k in ipairs(list)do
    set[k]=pic[k];pic[k]=nil
    local x,y=k%W,math.floor(k/W)
    if x<x0 then x0=x end;if x>x1 then x1=x end;if y<y0 then y0=y end;if y>y1 then y1=y end
    if not lo[y] or x<lo[y] then lo[y]=x end
    if not hi[y] or x>hi[y] then hi[y]=x end
   end
   -- foam between a row's first and last stone pixel is the stone's own pale face, not a splash outside it
   if mass.seaBoulders and mass.foam then
    local keep={}
    for _,f in ipairs(mass.foam)do
     local X,Y=f[1],f[2]
     if lo[Y] and X>lo[Y] and X<hi[Y] and not set[Y*W+X] then
      set[Y*W+X]={0,0,0,f[3],f[4],f[5]}
     else keep[#keep+1]=f end
    end
    mass.foam=keep
   end
   mass.domes[#mass.domes+1]={set=set,x0=x0,x1=x1,y0=y0,y1=y1}
  end
 end
end

-- A stone is one solid body: each row of its drawing becomes one run from its first to its last stone pixel
-- (lo/hi eased with the rows above and below), every pixel of the run painted with the nearest stone pixel
-- of its row that is not foam or water. Rows with gaps (a rock in a ring of foam) were drawn as separate
-- thin slivers, see-through between them, with foam-white and water-blue on their faces.
local function solidSet(d,W,reject)
 local stone
 stone=function(p)
  if not p then return false end
  local r,g,b=p[1],p[2],p[3]
  if r==0 and g==0 and b==0 then return false end            -- foam taken into the face
  -- (a colour of the ground round a lone stone is that ground, wherever it is drawn: the sand round a
  -- desert spire's tip stood on it as a sandy cap)
  if reject and reject[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)] then return false end
  local mx,mn=math.max(r,g,b),math.min(r,g,b)
  if (r+g+b)/3>.8 and mx-mn<.16 then return false end         -- foam white
  if b>r+.18 and b>g+.06 then return false end                 -- water blue
  return true
 end
 -- (a brown rock's drawn water-shadow, a neutral grey-blue strip down one side, is not rock: on a mostly warm
 -- stone it stood as a grey panel down the side)
 local warm,all=0,0
 for k,p in pairs(d.set)do if stone(p) then all=all+1;if p[1]>p[3]+.08 then warm=warm+1 end end end
 if all>0 and warm>all*.5 then
  local base=stone
  stone=function(p)return base(p) and p[1]>p[3]-.02 end
 end
 local lo,hi={}, {}
 for y=d.y0,d.y1 do for x=d.x0,d.x1 do
  if d.set[y*W+x] then lo[y]=lo[y] and math.min(lo[y],x) or x;hi[y]=hi[y] and math.max(hi[y],x) or x end
 end end
 local slo,shi={}, {}
 for y=d.y0,d.y1 do if lo[y] then
  local a,b,n=0,0,0
  for yy=y-1,y+1 do if lo[yy] then a=a+lo[yy];b=b+hi[yy];n=n+1 end end
  slo[y]=math.floor(math.min(lo[y],a/n)+.5);shi[y]=math.floor(math.max(hi[y],b/n)+.5)
 end end
 -- (the drawing's pointed tip, a run of one or two pixels, turned as a body into a thin chimney: the top
 -- rows are at least M.TIP of the stone's widest row, so the stone ends in a rounded point)
 local widest=0
 for y=d.y0,d.y1 do if slo[y] then widest=math.max(widest,shi[y]-slo[y]+1) end end
 local minW=math.floor(widest*M.TIP+.5)
 for y=d.y0,d.y1 do if slo[y] and shi[y]-slo[y]+1<minW then
  local c=(slo[y]+shi[y])/2
  slo[y]=math.floor(c-minW/2+.5);shi[y]=slo[y]+minW-1
 end end
 local out,any={},false
 for y=d.y0,d.y1 do if slo[y] then
  local row={}
  for x=lo[y],hi[y] do local p=d.set[y*W+x];if stone(p) then row[#row+1]={x,p} end end
  if #row==0 then
   for dy=1,4 do for _,yy in ipairs({y-dy,y+dy})do
    if #row==0 and lo[yy] then for x=lo[yy],hi[yy] do local p=d.set[yy*W+x];if stone(p) then row[#row+1]={x,p} end end end
   end end
  end
  for x=slo[y],shi[y] do
   local best,bd
   for _,q in ipairs(row)do local dd=math.abs(q[1]-x);if not bd or dd<bd then best,bd=q[2],dd end end
   if best then out[y*W+x]=best;any=true end
  end
 end end
 return any and out or nil
end
local function emitDome(mass,d,emit,uvOf,base)
 local W=mass.W
 if M.SOLID_STONES and (mass.seaBoulders or mass.boulder) and not d.solid then
  local reject=mass.boulder and mass.groundMid and not mass.groundWater and colours(mass.ts,mass.groundMid) or nil
  -- (every walkable ground tile touching the stone, not only the voted one: desert sand comes in variants)
  if reject and mass.groundTiles then
   local own={};for k in pairs(reject)do own[k]=true end;reject=own   -- (colours() is shared: add to a copy)
   for mid in pairs(mass.groundTiles)do for k in pairs(colours(mass.ts,mid) or {})do reject[k]=true end end
  end
  local s=solidSet(d,W,reject)
  if s then d.set=s;d.solid=true
   for k in pairs(s)do local x,y=k%W,math.floor(k/W);d.x0,d.x1,d.y0,d.y1=math.min(d.x0,x),math.max(d.x1,x),math.min(d.y0,y),math.max(d.y1,y) end
  end
 end
 -- a sea stone's drawing often carries a small knob on its lit top (a narrow rim row or two above the body): standing as a
 -- neck and lip it read as a jar. Rows much narrower than the row two below are dropped, the crown rounds the new top.
 if mass.seaBoulders and d.solid then
  local function width(y)local n=0;for x=d.x0,d.x1 do if d.set[y*W+x] then n=n+1 end end;return n end
  while d.y1-d.y0>=5 and width(d.y0)<.7*width(d.y0+2) do
   for x=d.x0,d.x1 do d.set[d.y0*W+x]=nil end
   d.y0=d.y0+1
  end
 end
 local rows={}
 for y=d.y0,d.y1 do
  local runs,x={}, d.x0
  while x<=d.x1 do
   if d.set[y*W+x] then
    local l=x
    while x<=d.x1 and d.set[y*W+x] do x=x+1 end
    runs[#runs+1]={l=l,r=x-1}
   else x=x+1 end
  end
  rows[y]=runs
 end
 local function rowDepth(y,px)
  for _,r in ipairs(rows[y] or {})do
   if px>=r.l and px<=r.r+1 then
    local rad=(r.r-r.l+1)/2
    local t=(px-(r.l+r.r+1)/2)/rad
    -- a rock is no deeper than it is tall: a wide formation is a long low mound, not a sail
    -- (a boulder in the sea is a round stone: a long low drawing capped at .6 lay as a flat lens on the water)
    local cap=(d.y1-d.y0+1)*(mass.seaBoulders and M.SEA_DEPTH or M.DEPTH)
    -- (a solid stone is as deep as it is wide: the cap cut it into a drum with a flat lid)
    if d.solid then cap=1e9 end
    local prof=rad*M.BULGE*math.sqrt(math.max(0,1-t*t))
    -- ease into the cap so the ends stay round
    return prof<cap and prof or cap,true
   end
  end
  return 0,false
 end
 local cache={}
 local function depth(k,px)
  local key2=k*4096+px
  local v=cache[key2];if v then return v end
  local a=rowDepth(k-1,px);local b=rowDepth(k,px)
  -- (a sea stone: rows blended over a few neighbours, so ragged art rows do not stack as stair steps)
  if mass.seaBoulders and d.solid then a=(rowDepth(k-2,px)+a*2+b)/4;b=(a*0+rowDepth(k+1,px)+b*2+rowDepth(k-1,px))/4 end
  local up=d.y1+1-k
  v=(a+b)/2*math.min(1,up/M.FOOT)
  cache[key2]=v;return v
 end
 local ox,oz=mass.x0*16,mass.y0*16
 local zc=oz+d.y1+1
 local tall=d.y1-d.y0+1
 -- a stone in the sea stands in the water: half its height below the surface
 if mass.seaBoulders and d.solid then base=base-tall/2 end
 local lean=tall>=M.BIG_FROM and M.LEAN_BIG or tall>=M.LEAN_FROM and M.LEAN or 1
 -- (a solid stone stands upright: with the full view-line lean it tipped forward like an egg from the side)
 if d.solid then lean=math.min(lean,M.STONE_LEAN) end
 -- a sea stone's flat crown (the drawing's lit top row) is rounded off: the top rows narrow and thin like a dome
 local round=mass.seaBoulders and d.solid
 local cx=(d.x0+d.x1+1)/2
 local function crown(k)
  local t=(k-d.y0)/math.max(1,tall*.35)
  if t>=1 then return 1 end
  return math.max(.3,math.sqrt(1-(1-t)*(1-t)))
 end
 local function point(px,k,sign)
  local dd=depth(k,px)
  local up=d.y1+1-k
  if round then local c=crown(k);dd=dd*c;px=cx+(px-cx)*math.max(.55,c) end
  -- a tall rock leans along the view line (the price of landing every pixel on its own row); only part of it
  -- is taken, so from the side it stands up as a rounded rock, not a leaning fin
  local y=base+up+sign*dd*lean
  if y<base then y=base end
  return ox+px,y,zc+sign*dd
 end
 for y=d.y0,d.y1 do
  for _,r in ipairs(rows[y])do
   local px=r.l
   while px<=r.r do
    local p=d.set[y*W+px]
    local cell,lx,ly=p[4],p[5],p[6]
    local pe=px+1
    while pe<=r.r and pe-px<4 do
     local q=d.set[y*W+pe]
     if q and q[4]==cell and q[5]==lx+(pe-px) and q[6]==ly then pe=pe+1 else break end
    end
    local uv=sub(uvOf(cell),lx,ly,lx+(pe-px),ly+1)
    for _,sign in ipairs({1,-1})do
     local ax,ay,az=point(px,y,sign);local bx,by,bz=point(pe,y,sign)
     local cx,cy,cz=point(pe,y+1,sign);local dx,dy,dz=point(px,y+1,sign)
     emit({{ax-E*0,ay,az},{bx,by,bz},{cx,cy,cz},{dx,dy,dz}},uv,sign>0 and 1 or .68)
    end
    -- nothing above this strip: close the top between the two shells with the pixel's own colour
    local open=true
    for q=px,pe-1 do if d.set[(y-1)*W+q] then open=false;break end end
    if open then
     local ax,ay,az=point(px,y,1);local bx,by,bz=point(pe,y,1)
     local cx,cy,cz=point(pe,y,-1);local dx,dy,dz=point(px,y,-1)
     emit({{ax,ay,az},{bx,by,bz},{cx,cy,cz},{dx,dy,dz}},uv,1)
    end
    if round then
     -- a sea stone is closed all round: end caps at each run's ends, and the top between the shells over every
     -- pixel with nothing above it (the open-strip test above only closes a strip with nothing above ANY of it)
     local function cap(x,sh)
      local ax,ay,az=point(x,y,1);local bx,by,bz=point(x,y+1,1)
      local cx2,cy2,cz2=point(x,y+1,-1);local dx,dy,dz=point(x,y,-1)
      emit({{ax,ay,az},{bx,by,bz},{cx2,cy2,cz2},{dx,dy,dz}},uv,sh)
     end
     if px==r.l then cap(px,.8) end
     if pe==r.r+1 then cap(pe,.8) end
     if not open then
      for q=px,pe-1 do if not d.set[(y-1)*W+q] then
       local ax,ay,az=point(q,y,1);local bx,by,bz=point(q+1,y,1)
       local cx2,cy2,cz2=point(q+1,y,-1);local dx,dy,dz=point(q,y,-1)
       emit({{ax,ay,az},{bx,by,bz},{cx2,cy2,cz2},{dx,dy,dz}},uv,1)
      end end
     end
    end
    px=pe
   end
  end
 end
end

local function build(mass,cells)
 if mass.columns~=nil then return mass.columns end
 mass.columns=false
 if not picture(mass,cells) then return false end
 local W,H,pic=mass.W,mass.H,mass.pic
 extractDomes(mass,cells)
 local cols={}
 -- boulders standing in the sea are low stones, never a wall a tile tall
 local low=mass.object or (mass.seaBoulders and mass.sea)
 local function floorFor(X,yb)
  local base=mass.foot or 0
  if cells and not mass.object then
   -- the floor this column stands on: the first non-mass cell south of its front
   -- (a mass spanning terraces has a different foot on each)
   local cx=mass.x0+math.floor(X/16)
   local cy=mass.y0+math.floor(yb/16)
   for k=0,6 do
    local n=cells[key(cx,cy+k)]
    if n and n.mass~=mass and n.shape and n.shape.kind~='water' and n.shape.kind~='cliff' then base=n.floorHigh or n.base or base;break end
    if not n then break end
   end
   -- (never above the ground under the rock's own cell: a rock over a sunken cell stood on the floor beyond it, a course up)
   local own=cells[key(cx,cy)]
   if own and own.mass==mass and own.base and own.base<base then base=own.base end
  end
  return base
 end
 mass.floorAt=function(d)return floorFor(math.floor((d.x0+d.x1)/2),d.y1) end
 -- A column holds one segment per run of rock rows: a mass has one (rows with
 -- gaps are still one hill), a chain of sea boulders one per boulder.
 for X=0,W-1 do
  local runs={}
  local y=0
  while y<H do
   if pic[y*W+X] then
    local y0=y
    while y<H and pic[y*W+X] do y=y+1 end
    runs[#runs+1]={y0,y-1}
   else y=y+1 end
  end
  if #runs>0 then
   local list={}
   if not low then runs={{runs[1][1],runs[#runs][2]}} end
   for _,r in ipairs(runs)do
    local ymin,yb=r[1],r[2]
    local Y=yb
    if low then
     -- low thing: as high as it is deep, so the wall is the lower half
     local want=math.min(M.FACE,math.max(1,math.floor((yb-ymin+1)/2)))
     while Y>=ymin and (yb-Y)<want and pic[Y*W+X] do Y=Y-1 end
    elseif mass.wally and cells then
     -- A rock wall: a sheer face at least three tiles wide stands as tall as its drawing
     -- (stacked sheer tiles, head-on, 1:1). One-tile cliff-edge stripes beside a plateau are
     -- not walls: they keep the one-course face, or they would shoot up as pillars.
     while Y>=ymin and (yb-Y)<M.FACE and pic[Y*W+X] do Y=Y-1 end
     local function wide(c)
      if not mass.sheer[c] then return false end
      local l,r=cells[key(c.cx-1,c.cy)],cells[key(c.cx+1,c.cy)]
      if not (l and r and l.mass==mass and r.mass==mass and mass.sheer[l] and mass.sheer[r]) then return false end
      -- a face repeats its tile along the wall; a diagonal ridge changes tile every cell and is a slope, not a wall
      if not (l.mid==c.mid and r.mid==c.mid) then return false end
      local ll,rr=cells[key(c.cx-2,c.cy)],cells[key(c.cx+2,c.cy)]
      return (ll and ll.mass==mass and mass.sheer[ll]) or (rr and rr.mass==mass and mass.sheer[rr]) or false
     end
     -- Only a stack that runs to the very top of its rock is a wall: with a lighter top
     -- surface above it, the face is one course of a hill and keeps its one-tile height.
     -- The General primary face tiles (below 0x100) are the ones built to stack.
     local Y2=Y
     while Y2>=ymin and (yb-Y2)<M.TALL do
      local p=pic[Y2*W+X]
      if p and p[4].mid<0x100 and wide(p[4]) then Y2=Y2-1 else break end
     end
     if Y2<ymin then Y=Y2 end
    else
     -- A face is one tile of art tall everywhere (a rounded foot makes the rows
     -- shift, not shrink): the contiguous rock rows from the bottom, FACE at most.
     while Y>=ymin and (yb-Y)<M.FACE and pic[Y*W+X] do Y=Y-1 end
    end
    local h=yb-Y
    local top={}
    for yy=ymin,Y do if pic[yy*W+X] then top[#top+1]=yy end end
    -- a tall wall with nothing behind it in the drawing gets a flat top
    -- thickness of the body behind a wall with nothing behind it in the drawing: a tall wall gets
    -- M.CAP, a low stone (boulder, planter) as deep as it is high, at least 3 and at most 8 voxels
    local cap=nil
    if #top==0 and h>0 then
     if h>M.FACE then cap=M.CAP elseif low then cap=math.max(3,math.min(8,h)) end
    end
    local entry={yb=yb,h=h,ymin=ymin,wallTop=h>0 and Y+1 or nil,top=top,base=floorFor(X,yb),cap=cap,
     back=#top>0 and (top[1]+h) or (cap and (yb+1-cap)) or (yb+1)}
    -- the terrace the cliff bounds can stand higher than the cliff's own top (a band between two terraces):
    -- remember the floor north of its back edge so the gap above the lid is closed (emitMass, apron)
    if cells and not mass.object and h>0 then
     local cx=mass.x0+math.floor(X/16)
     local r=math.floor(((cap and ymin or entry.back)-1)/16)
     for k=0,6 do
      local n=cells[key(cx,mass.y0+r-k)]
      if not n then break end
      if n.mass~=mass then
       local nb=n.floorHigh or n.base
       if nb and nb>entry.base+h and nb-(entry.base+h)<=M.APRON then entry.north=nb end
       -- a tall wall (thin lid) whose terrace behind is level with it: the lid runs back to that terrace
       if cap and nb and nb>=entry.base+h and (yb+1-ymin)<=M.LIDMAX then entry.cap=yb+1-ymin;entry.back=ymin;entry.lidToFloor=true end
       break
      end
     end
    end
    list[#list+1]=entry
   end
   cols[X]=list
  end
 end
 mass.columns=cols
 mass.tall=0
 for _,list in pairs(cols)do for _,c in ipairs(list)do if c.h>M.FACE then mass.tall=mass.tall+1 end end end
 if cells then mass.foot=mass.foot or foot(mass,cells) end
 return cols
end


-- The floor under a mass: the walkable ground most of its neighbours share
-- (a rock tile with transparent pixels needs something under it).
function M.ground(mass,cells,cell)
 -- Boulders standing in the sea: each cell stands on the water around IT. One ground for a
 -- whole chain picked up the beach at its far end (salmon squares under the rocks).
 if mass.seaBoulders and cell then
  mass.cellGround=mass.cellGround or {}
  local g=mass.cellGround[cell]
  if g==nil then
   local wet={}
   for dy=-1,1 do for dx=-1,1 do
    local n=(dx~=0 or dy~=0) and cells[key(cell.cx+dx,cell.cy+dy)]
    if n and n.mass~=mass and n.pair==cell.pair and n.shape and n.shape.kind=='water' and n.ts.midToSlot[n.mid] then
     local w=(dx==0 or dy==0) and 2 or 1
     wet[n.mid]=(wet[n.mid] or 0)+w
    end
   end end
   local best,top
   for mid,v in pairs(wet)do if not top or v>top or (v==top and mid<best) then best,top=mid,v end end
   g=best or false
   mass.cellGround[cell]=g
  end
  if g then return g,true end
  if mass.seaBoulders then
   local m=seaGround(mass,cells)
   if m then return m,true end
  end
 end
 if mass.groundMid~=nil then return mass.groundMid or nil,mass.groundWater end
 local votes,wet={}, {}
 for _,c in ipairs(mass.members)do
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and n.mass~=mass and n.pair==c.pair and n.shape and not n.boundary and n.ts.midToSlot[n.mid] then
    -- (in a cave walkable floor carries codes other than 0; only 7 is blocked)
    if (n.shape.kind=='flat' or n.shape.kind=='grass') and (n.collision==0 or (M.caves and n.collision~=nil and n.collision~=7 and n.collision~=255)) then votes[n.mid]=(votes[n.mid] or 0)+1
    elseif n.shape.kind=='water' then wet[n.mid]=(wet[n.mid] or 0)+1 end
   end
  end
 end
 local function pick(t)local best,top;for mid,v in pairs(t)do if not top or v>top or (v==top and mid<best) then best,top=mid,v end end;return best end
 local land,sea=pick(votes),pick(wet)
 mass.groundMid=land or sea or false
 mass.groundWater=(not land and sea) and true or false
 return mass.groundMid or nil,mass.groundWater
end

-- False when the mass cannot be rebuilt from its drawing (no pixels, or a sheer wall).
function M.usable(mass,cells)
 -- terrain rock is built as real rock by Gen3Rock (sea boulders, banks and
 -- objects keep this builder)
 if V.require('Gen3Rock').handles(mass,cells) then return true end
 local cols=build(mass,cells)
 -- a wall-dominated mass is rebuilt only when it holds a real tall wall; other
 -- wall-dominated masses (diagonal slopes, stripes) keep the dome they always had
 return cols and (not mass.wally or mass.tall>=M.MINTALL) and true or false
end

local function emitMass(mass,emit,uvOf,cell)
 local cols=mass.columns
 local W,H,pic=mass.W,mass.H,mass.pic
 local ox,oz=mass.x0*16,mass.y0*16
 local function owns(X,Y)
  -- the cell this picture pixel stands in emits it, so a mass never depends on one far-away owner
  return not cell or (mass.x0+math.floor(X/16)==cell.cx and mass.y0+math.floor(Y/16)==cell.cy)
 end
 for X=0,W-1 do
  for _,col in ipairs(cols[X] or {})do
   if owns(X,col.yb) then
   local x=ox+X
   local h=col.h
   local zf=oz+col.yb+1
   local base=col.base or 0
   -- wall: runs of face rows, one run per tile the column crosses
   if h>0 then
    local Y=col.wallTop
    while Y<=col.yb do
     local p=pic[Y*W+X]
     local Y2=Y
     while Y2<col.yb do
      local n=pic[(Y2+1)*W+X]
      if p and n and n[4]==p[4] and n[6]==pic[Y2*W+X][6]+1 then Y2=Y2+1 else break end
     end
     if p then
      local c,lx=p[4],p[5]
      local lower,upper=base+(col.yb-Y2),base+(col.yb+1-Y)
      local t=sub(uvOf(c),lx,p[6],lx+1,pic[Y2*W+X][6]+1)
      emit({{x-E,upper,zf},{x+1+E,upper,zf},{x+1+E,lower,zf},{x-E,lower,zf}},t,.92)
      -- a tall wall is a body, not a plate: the same pixels again on its back face
      if col.cap then
       local zb=zf-col.cap
       emit({{x+1+E,upper,zb},{x-E,upper,zb},{x-E,lower,zb},{x+1+E,lower,zb}},t,.68)
      end
     end
     Y=Y2+1
    end
   end
   -- seam: the rounded foot puts neighbouring columns at different depths; seen from the side (or low) the
   -- walls were separate slats with the world showing between them. Close the step with the wall's own pixel.
   if h>0 then
    for _,n in ipairs(cols[X+1] or {})do
     if n.h>0 and n.yb~=col.yb and math.abs(n.yb-col.yb)<=M.SEAM and n.ymin<=col.yb and n.yb>=col.ymin then
      local zn=oz+n.yb+1
      local hi=base+math.min(h,n.h)
      local wp=pic[col.yb*W+X] or pic[col.wallTop*W+X]
      if wp and hi>base then
       local u=sub(uvOf(wp[4]),wp[5],wp[6],wp[5]+1,wp[6]+1)
       local za,zb2=math.min(zf,zn),math.max(zf,zn)
       emit({{x+1,hi,za},{x+1,hi,zb2},{x+1,base,zb2},{x+1,base,za}},u,.8)
       emit({{x+1,hi,zb2},{x+1,hi,za},{x+1,base,za},{x+1,base,zb2}},u,.8)
      end
     end
    end
   end
   -- the same at the back of the body: its depth follows the rock's outline column by column, so from behind
   -- the back faces were slats with gaps (the world showing through)
   if h>0 and #col.top>0 and not col.cap then
    for _,n in ipairs(cols[X+1] or {})do
     if n.h>0 and #n.top>0 and not n.cap and n.back~=col.back and math.abs(n.back-col.back)<=M.SEAM and n.ymin<=col.yb and n.yb>=col.ymin then
      local hi=base+math.min(h,n.h)
      local bp=pic[col.wallTop*W+X]
      if bp and hi>base then
       local u=sub(uvOf(bp[4]),bp[5],bp[6],bp[5]+1,bp[6]+1)
       local za,zb2=oz+math.min(col.back,n.back),oz+math.max(col.back,n.back)
       emit({{x+1,hi,za},{x+1,hi,zb2},{x+1,base,zb2},{x+1,base,za}},u,.7)
       emit({{x+1,hi,zb2},{x+1,hi,za},{x+1,base,za},{x+1,base,zb2}},u,.7)
      end
     end
    end
   end
   -- top: runs of rock rows above the wall, shifted south by the wall height
   local top=col.top
   local i=1
   while i<=#top do
    local Y=top[i]
    local p=pic[Y*W+X]
    local j=i
    while top[j+1]==top[j]+1 do
     local n=pic[top[j+1]*W+X]
     if n and p and n[4]==p[4] and n[6]==pic[top[j]*W+X][6]+1 then j=j+1 else break end
    end
    local Y2=top[j]
    if p then
     local c,lx=p[4],p[5]
     local z0,z1=oz+Y+h,oz+Y2+1+h
     local y=base+h
     emit({{x-E,y,z0},{x+1+E,y,z0},{x+1+E,y,z1},{x-E,y,z1}},sub(uvOf(c),lx,p[6],lx+1,pic[Y2*W+X][6]+1),1)
    end
    i=j+1
   end
   -- flat top of a tall wall: the drawing's top rim pixel, M.CAP deep
   if col.cap then
    local tp=pic[col.wallTop*W+X]
    if tp then
     local t=sub(uvOf(tp[4]),tp[5],tp[6],tp[5]+1,tp[6]+1)
     local y=base+h
     emit({{x-E,y,zf-col.cap},{x+1+E,y,zf-col.cap},{x+1+E,y,zf},{x-E,y,zf}},t,1)
    end
   end
   -- apron: the floor behind the cliff stands higher than its lid; its face runs from the lid up to that floor
   if col.north and col.wallTop then
    local bp=pic[col.wallTop*W+X]
    if bp then
     local u=sub(uvOf(bp[4]),bp[5],bp[6],bp[5]+1,bp[6]+1)
     -- the lid is the rock's top rows shifted south by the wall's height, so the terrace behind ends at the
     -- first top row's own line: its face stands there, and the lid's flat strip joins it to the lid's edge
     local z0=oz+(col.top[1] or col.ymin)
     local zb=oz+col.back
     emit({{x+1+E,col.north,z0},{x-E,col.north,z0},{x-E,base+h,z0},{x+1+E,base+h,z0}},u,.8)
     emit({{x-E,col.north,z0},{x+1+E,col.north,z0},{x+1+E,base+h,z0},{x-E,base+h,z0}},u,.8)
     if zb>z0 then emit({{x-E,base+h,z0},{x+1+E,base+h,z0},{x+1+E,base+h,zb},{x-E,base+h,zb}},u,1) end
    end
   end
   -- back of the body: without it a rock seen from behind is an empty shell under its lid
   if h>0 and #top>0 and not col.cap then
    local bp=pic[col.wallTop*W+X]
    if bp then
     local u=sub(uvOf(bp[4]),bp[5],bp[6],bp[5]+1,bp[6]+1)
     local zb=oz+col.back
     emit({{x+1+E,base+h,zb},{x-E,base+h,zb},{x-E,base,zb},{x+1+E,base,zb}},u,.6)
    end
   end
   -- sides: where a neighbouring column is lower, close the gap with wall colour
   if h>0 and (#top>0 or col.cap) then
    local wp=pic[col.wallTop*W+X]
    if wp then
     local u=sub(uvOf(wp[4]),wp[5],wp[6],wp[5]+1,wp[6]+1)
     for _,s in ipairs({-1,1}) do
      local nh=0
      for _,n in ipairs(cols[X+s] or {})do
       if n.ymin<=col.yb and n.yb>=col.ymin then nh=math.max(nh,n.h) end
      end
      if nh<h then
       local xs=s<0 and x or x+1
       local zb,zfront=oz+col.back,zf
       local lo,hi=base+nh,base+h
       if s<0 then emit({{xs,hi,zb},{xs,hi,zfront},{xs,lo,zfront},{xs,lo,zb}},u,.78)
       else emit({{xs,hi,zfront},{xs,hi,zb},{xs,lo,zb},{xs,lo,zfront}},u,.84) end
      end
     end
    end
   end
   end
  end
 end
 -- foam: flat on the water, the pixels laid in plan like a decal, 1:1
 if mass.foam then
  local rows={}
  for _,f in ipairs(mass.foam)do if owns(f[1],f[2]) then local r=rows[f[2]] or {};rows[f[2]]=r;r[#r+1]=f end end
  for Y,list in pairs(rows)do
   table.sort(list,function(a,b)return a[1]<b[1] end)
   local i=1
   while i<=#list do
    local f=list[i];local j=i
    while list[j+1] and list[j+1][1]==list[j][1]+1 and list[j+1][3]==f[3] and list[j+1][4]==list[j][4]+1 do j=j+1 end
    local x0=ox+f[1];local x1=ox+list[j][1]+1
    local z0,z1=oz+Y,oz+Y+1
    local y=(mass.foot or 0)+.12
    emit({{x0,y,z0},{x1,y,z0},{x1,y,z1},{x0,y,z1}},sub(uvOf(f[3]),f[4],f[5],list[j][4]+1,f[5]+1),1)
    i=j+1
   end
  end
 end
 for _,d in ipairs(mass.domes or {})do
  if owns(math.floor((d.x0+d.x1)/2),d.y1) then
  local base=mass.foot or 0
  if mass.floorAt then base=mass.floorAt(d) end
  emitDome(mass,d,emit,uvOf,base)
  end
 end
 return true
end
-- Emit the whole mass (called once, by its owner cell).
function M.append(mass,cells,emit,uvFor,cell)
 local Rock=V.require('Gen3Rock')
 -- (audit: Gen3Rock.audit, default off)
 if Rock.audit and not mass.audited then
  Rock.checkFloat(mass,cells,Rock.handles(mass,cells) and 'Gen3Rock.append' or 'Gen3Mass.emitMass',function(c,e)return M.append(mass,cells,e,uvFor,c)end)
 end
 if Rock.handles(mass,cells) then return Rock.append(mass,cells,emit,uvFor,cell) end
 if not build(mass,cells) then return false end
 mass.uvs=mass.uvs or {}
 local uvs=mass.uvs
 return emitMass(mass,emit,function(c)
  local u=uvs[c];if not u then u=uvFor(c.ts,c.mid);uvs[c]=u end
  return u
 end,cell)
end

-- A low object built by Gen3Objects (o.cells/o.tops with o.masks): same
-- inversion, wall = lower half of each column. Returns the quad count or nil.
function M.appendObject(o,emit)
 if not (M.enabled and o.ts and o.ts.imageData) then return nil end
 if not o.mass then
  local members={};for _,c in ipairs(o.cells)do members[#members+1]=c end
  for _,c in ipairs(o.tops)do members[#members+1]=c end
  o.mass={members=members,x0=o.x0,y0=o.top,x1=o.x1,y1=o.y1,ts=o.ts,object=true,masks=o.masks,foot=0,seaBoulders=o.water and true or nil}
 end
 local mass=o.mass
 if not build(mass,nil) then return nil end
 local ts=o.ts
 local uvs={}
 local n=0
 local function uvOf(c)
  local u=uvs[c]
  if not u then
   local ox,oy=origin(ts,c.mid)
   local w,h=ts.cols*16,ts.rows*16
   u={{ox/w,oy/h},{(ox+16)/w,oy/h},{(ox+16)/w,(oy+16)/h},{ox/w,(oy+16)/h}}
   uvs[c]=u
  end
  return u
 end
 -- (audit: an object stands on the floor of each column it has, from build)
 local Rock=V.require('Gen3Rock')
 if Rock.audit and not mass.audited then
  Rock.checkFloat(mass,nil,'Gen3Mass.appendObject',function(_,e)emitMass(mass,e,uvOf,nil)end,function()
   local g=math.huge
   for _,list in pairs(mass.columns or {})do for _,col in ipairs(list)do g=math.min(g,col.base or 0) end end
   return g==math.huge and 0 or g
  end)
 end
 emitMass(mass,function(v,t,shade)n=n+1;emit(v,t,shade)end,uvOf)
 return n
end

return M
