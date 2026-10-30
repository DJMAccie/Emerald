-- Fortree City's treetop walks, built as real wood (the decks, their posts and
-- the ladders). The cartridge draws the decks and ladders as flat tiles on the
-- forest; here each deck is a slab 3 px thick under its own plank art, each
-- platform and every fourth bridge cell stands on posts to the ground, and each
-- ladder is rebuilt from the ladder tiles' own pixels, rising from the foot
-- (base 0) to the deck (32).
--
-- Gen3Scene calls append(c,cells,emit,uvFor) for every cell of Fortree City and
-- emit(points,uv,shade) adds one quad (points TL,TR,BR,BL). Deck heights are
-- relative to the cell's own base (the scene lifts them by it); ladder cells
-- have base 0, so their heights are absolute.
local M={}

M.DECK={[0x256]=true,[0x24E]=true,[0x23B]=true,[0x23C]=true,[0x23D]=true,[0x23E]=true,[0x23F]=true}
M.BRIDGE={[0x256]=true,[0x24E]=true}
M.RUNG,M.RAIL_TOP,M.RAIL_FOOT=0x24D,0x245,0x261
M.SLAB=3       -- deck thickness (px)
M.POST=4       -- post size (px)
M.WALL=0x235   -- the hut's wall art: the posts' brown
M.HUT_MID=0x235 -- the hut's middle wall cell (its door): the trunk stands under the deck south of it
M.TRUNK=0x241  -- the palm trunk's bark: the hut trunks and the palm trunks
M.PALM_TOP=40  -- the palm crown's rim (absolute), and its dome 12 px higher in the middle
M.DOME_UP=12

local function tex(uv,px,py)
 return {uv[1][1]+(uv[2][1]-uv[1][1])*px/16,uv[1][2]+(uv[3][2]-uv[1][2])*py/16}
end
-- the tile's own pixels px0..px1 x py0..py1 (of 16), in quad order TL,TR,BR,BL
local function up(uv,px0,py0,px1,py1)
 return {tex(uv,px0,py0),tex(uv,px1,py0),tex(uv,px1,py1),tex(uv,px0,py1)}
end

local function isDeck(n)return n and n.base==32 and (n.collision or 0)==0 and M.DECK[n.mid] or false end
local function isBridge(n)return n and n.base==32 and (n.collision or 0)==0 and M.BRIDGE[n.mid] or false end

-- the deck's edge: a 3 px slab under each open side (its own plank art, bottom rows),
-- and the underside (the whole tile, darker)
local function slab(c,cells,emit,uvFor)
 local uv=uvFor(c.ts,c.mid);if not uv then return end
 local X,Z=c.cx*16,c.cy*16
 local S=M.SLAB
 local edge=up(uv,0,16-S,16,16)
 local function open(dx,dz)return not isDeck(cells[(c.cx+dx)..':'..(c.cy+dz)])end
 if open(0,-1)then emit({{X+16,0,Z},{X,0,Z},{X,-S,Z},{X+16,-S,Z}},edge,.62)end
 if open(0,1)then emit({{X,0,Z+16},{X+16,0,Z+16},{X+16,-S,Z+16},{X,-S,Z+16}},edge,.82)end
 if open(-1,0)then emit({{X,0,Z},{X,0,Z+16},{X,-S,Z+16},{X,-S,Z}},edge,.7)end
 if open(1,0)then emit({{X+16,0,Z+16},{X+16,0,Z},{X+16,-S,Z},{X+16,-S,Z+16}},edge,.7)end
 emit({{X,-S,Z},{X+16,-S,Z},{X+16,-S,Z+16},{X,-S,Z+16}},up(uv,0,0,16,16),.45)
end

-- a w px square column from ya up to yb (heights relative to the base), in 16-row courses of its art
local function column(emit,uv,x0,z0,ya,yb,w)
 w=w or M.POST
 local x1,z1=x0+w,z0+w
 local y=ya
 while y<yb do
  local y1=math.min(y+16,yb);local h=y1-y
  emit({{x0,y1,z1},{x1,y1,z1},{x1,y,z1},{x0,y,z1}},up(uv,4,0,4+w,h),.82)
  emit({{x1,y1,z0},{x0,y1,z0},{x0,y,z0},{x1,y,z0}},up(uv,4,0,4+w,h),.62)
  emit({{x0,y1,z0},{x0,y1,z1},{x0,y,z1},{x0,y,z0}},up(uv,4,0,4+w,h),.7)
  emit({{x1,y1,z1},{x1,y1,z0},{x1,y,z0},{x1,y,z1}},up(uv,4,0,4+w,h),.7)
  y=y1
 end
 emit({{x0,yb,z0},{x1,yb,z0},{x1,yb,z1},{x0,yb,z1}},up(uv,4,0,4+w,w),1)
end

-- posts: the platform's corners (a deck cell missing a neighbour on both axes),
-- and every fourth cell of a bridge run; each stands from the ground to the slab
local function posts(c,cells,emit,uvFor)
 local uv=uvFor(c.ts,M.WALL);if not uv then return end
 local X,Z=c.cx*16,c.cy*16
 local S,P=M.SLAB,M.POST
 local function missing(dx,dz)return not isDeck(cells[(c.cx+dx)..':'..(c.cy+dz)])end
 local mw,me,mn,ms=missing(-1,0),missing(1,0),missing(0,-1),missing(0,1)
 -- a hut stands on this deck (its door cell is the hut's wall to the north): a 12 px trunk
 -- from the ground to the slab, centred under the hut, in the palm trunk's bark
 local hn=cells[c.cx..':'..(c.cy-1)]
 if hn and hn.mid==M.HUT_MID and hn.base==32 then
  local ut=uvFor(c.ts,M.TRUNK);if ut then column(emit,ut,X+2,Z+2,-32,-S,12)end
 end
 local bridge=isBridge(c)
 if bridge then
  local along=(isBridge(cells[(c.cx-1)..':'..c.cy])or isBridge(cells[(c.cx+1)..':'..c.cy]))
  local across=(isBridge(cells[c.cx..':'..(c.cy-1)])or isBridge(cells[c.cx..':'..(c.cy+1)]))
  if along and not across and c.cx%4==0 then column(emit,uv,X+6,Z+6,-32,-S)end
  if across and not along and c.cy%4==0 then column(emit,uv,X+6,Z+6,-32,-S)end
  return
 end
 if (mw or me)and(mn or ms)then
  local xs={};if mw then xs[#xs+1]=2 end;if me then xs[#xs+1]=12 end
  local zs={};if mn then zs[#zs+1]=2 end;if ms then zs[#zs+1]=12 end
  for _,ox in ipairs(xs)do for _,oz in ipairs(zs)do column(emit,uv,X+ox,Z+oz,-32,-S)end end
 end
end

-- a ladder: the foot cell (base 0) with its rungs one and two cells north, the
-- top cell (21.33) and then the deck (32). Rails lean from the foot to the deck's
-- south edge; the rungs are the ladder tile's own rows.
local function ladder(c,cells,emit,uvFor)
 local ts=c.ts
 local uvRung=uvFor(ts,M.RUNG);local uvRail=uvFor(ts,M.RAIL_TOP)
 if not(uvRung and uvRail)then return end
 local X=c.cx*16
 local zf=(c.cy+1)*16-3          -- the rails' foot, in front of the foot cell
 local zt=(c.cy-2)*16+3         -- the rails' top, on the deck's south edge
 local function zAt(y)return zf+(zt-zf)*y/32 end
 for _,xr in ipairs({X+3,X+11})do
  for k=0,7 do
   local y0,y1=4*k,4*k+4
   local za,zb=zAt(y0),zAt(y1)
   local r=(4*k)%16
   local uvR=up(uvRail,2,r,4,r+4)   -- 2 px wide, 4 rows: the rail's own pixels
   -- front (toward the foot, +z) and back, both sloped with the rail
   emit({{xr,y1,zb+1},{xr+2,y1,zb+1},{xr+2,y0,za+1},{xr,y0,za+1}},uvR,.82)
   emit({{xr+2,y1,zb-1},{xr,y1,zb-1},{xr,y0,za-1},{xr+2,y0,za-1}},uvR,.62)
  end
 end
 for k=0,7 do
  local y0=4*k+2
  local zc=zAt(y0+1)
  local x0,x1=X+4,X+12
  local z0,z1=zc-1,zc+1
  local yb,yt=y0,y0+2
  local uvB=up(uvRung,4,6,12,8)  -- 8 px by 2: the rung's own row
  local uvS=up(uvRung,4,6,6,8)  -- the rung's end, 2 px by 2
  emit({{x0,yt,z1},{x1,yt,z1},{x1,yb,z1},{x0,yb,z1}},uvB,.82)
  emit({{x1,yt,z0},{x0,yt,z0},{x0,yb,z0},{x1,yb,z0}},uvB,.62)
  emit({{x0,yt,z0},{x1,yt,z0},{x1,yt,z1},{x0,yt,z1}},uvB,1)
  emit({{x0,yb,z1},{x1,yb,z1},{x1,yb,z0},{x0,yb,z0}},uvB,.45)
  emit({{x0,yt,z0},{x0,yt,z1},{x0,yb,z1},{x0,yb,z0}},uvS,.7)
  emit({{x1,yt,z1},{x1,yt,z0},{x1,yb,z0},{x1,yb,z1}},uvS,.7)
 end
end

-- a palm: the trunk cell (bark, 8 px) under the crown's middle cell, from the ground to the rim
local function palmTrunk(c,emit,uvFor)
 local uv=uvFor(c.ts,M.TRUNK);if not uv then return end
 local b=c.base or 0
 local X,Z=c.cx*16,c.cy*16
 column(emit,uv,X+4,Z+4,-b,M.PALM_TOP-b,8)
end

-- a palm's crown: a dome over the three crown cells (48 px across, 32 deep), its rim at
-- PALM_TOP and its middle DOME_UP higher; the top is the crown tiles' own art 1:1 (8 px
-- patches, each from the cell it lies in), the underside a closed flat face
local function palmDome(c,cells,emit,uvFor)
 local b=c.base or 0
 local Xc,Zc=c.cx*16+8,c.cy*16+8
 local RX,RZ=24,16
 local function h(x,z)
  local u,v=(x-Xc)/RX,(z-Zc)/RZ
  local r2=u*u+v*v
  if r2>=1 then return M.PALM_TOP-b end
  return M.PALM_TOP+M.DOME_UP*math.sqrt(1-r2)-b
 end
 local uvC=uvFor(c.ts,c.mid);if not uvC then return end
 for xa=Xc-RX,Xc+RX-8,8 do for za=Zc-RZ,Zc+RZ-8,8 do
  local ci,cj=math.floor(xa/16),math.floor(za/16)
  local n=cells[ci..':'..cj]
  local uv=(n and n.ts and uvFor(n.ts,n.mid))or uvC
  local px,py=xa-ci*16,za-cj*16
  local art=up(uv,px,py,px+8,py+8)
  emit({{xa,h(xa,za),za},{xa+8,h(xa+8,za),za},{xa+8,h(xa+8,za+8),za+8},{xa,h(xa,za+8),za+8}},art,1)
 end end
 -- the underside: closed, flat at the rim, the crown tile's own art (darker by shade)
 for xa=Xc-RX,Xc+RX-8,8 do for za=Zc-RZ,Zc+RZ-8,8 do
  local under=up(uvC,4,4,12,12)
  local y=M.PALM_TOP-b
  emit({{xa,y,za},{xa+8,y,za},{xa+8,y,za+8},{xa,y,za+8}},under,.45)
 end end
end

-- Gen3Scene calls this for each cell of Fortree City
function M.append(c,cells,emit,uvFor)
 if not c.ts then return end
 if isDeck(c)then
  slab(c,cells,emit,uvFor)
  posts(c,cells,emit,uvFor)
  return
 end
 local sh=c.shape
 if sh and sh.palmCrown then
  local l,r=cells[(c.cx-1)..':'..c.cy],cells[(c.cx+1)..':'..c.cy]
  if l and r and l.shape and r.shape and l.shape.palmCrown and r.shape.palmCrown then palmDome(c,cells,emit,uvFor)end
  return
 end
 if (c.mid==M.TRUNK or c.mid==0x25C) then
  local n=cells[c.cx..':'..(c.cy-1)]
  if n and n.shape and n.shape.palmCrown then palmTrunk(c,emit,uvFor)end
  return
 end
 if c.mid==M.RAIL_FOOT and (c.base or 0)==0 then
  local n1=cells[c.cx..':'..(c.cy-1)];local n2=cells[c.cx..':'..(c.cy-2)]
  if n1 and n1.mid==M.RUNG and n2 and n2.mid==M.RAIL_TOP then ladder(c,cells,emit,uvFor)end
 end
end

return M
