-- Sootopolis' stone railings (bars along the ledges, posts beside the stairs) stand up as low walls
-- instead of lying on the block's lid. The art rows give the sizes: 4 rows of top, 8 rows of face.
local M={}
M.SECONDARY='sootopolis'
M.GROUND=0x2D9 -- the floor under a railing
M.ROCK=0x2E1 -- the floor beside a stair's post: the rock top of the cells around it
M.H=8 -- face rows 6-13 of the bar art
M.Z0,M.Z1=2,6 -- the bar's depth in the cell: the art's top rows 2-5; its face (8 rows) is the height
M.TOP0,M.TOP1,M.FACE0,M.FACE1=2,6,6,14 -- art rows of the bar's top and face
M.SIDE=0x241 -- art for the walls' ends and sides
M.PINK=0x71 -- the pink floor of the steps in front of the gate
-- bars {x0,x1}: along the cell; posts {x0,x1,z0,z1,art column from,to}: running north-south, the end face is at z1
M.SPEC={
 [0x240]={bars={{0,16}},capL=true},
 [0x241]={bars={{0,16}}},
 [0x242]={bars={{0,16}},capR=true},
 [0x243]={bars={{0,16}},capL=true,capR=true},
 [0x246]={bars={{0,10}},posts={{10,15,2,16,10,15}}},
 [0x247]={bars={{6,16}},posts={{1,6,2,16,1,6}}},
 [0x262]={posts={{9,15,0,5,9,15}},endFace=true,lid=M.ROCK},
 [0x263]={posts={{1,7,0,5,1,7}},endFace=true,lid=M.ROCK},
 -- the gate frame round the cave door: a level ring of stone beams hanging round the entrance (see gate)
 [0x251]={gate=true},[0x252]={gate=true},[0x253]={gate=true},[0x25B]={gate=true,door=true},
 [0x220]={gate=true,lid=M.ROCK},[0x222]={gate=true,lid=M.ROCK},
 [0x228]={gate=true,lid=M.PINK},[0x22A]={gate=true,lid=M.PINK},[0x230]={gate=true,lid=M.PINK},[0x232]={gate=true,lid=M.PINK},
}
M.GH=5 -- the gate's beams: 5 deep (the art's 5 top rows) and 5 high (its 4-5 face rows)
-- members per tile, cell-local px: bar {x0,x1} along the back beam (z 1-6); side {x0,x1,z0,z1} beam running north-south;
-- front {x0,x1} the front beam (z 1-6) over the walkable cells; leg {x0,x1} a post from the floor up to the ring
M.GATE={
 [0x251]={bar={15,16},side={10,15,1,16}},
 [0x252]={bar={0,16}},
 [0x25B]={bar={0,16}},
 [0x253]={bar={0,1},side={1,6,1,16}},
 [0x220]={side={10,15,0,16}},
 [0x222]={side={1,6,0,16}},
 [0x228]={side={10,15,0,6},front={15,65},leg={10,15,0x230}},
 [0x22A]={side={1,6,0,6},leg={1,6,0x232}},
}

function M.is(c)
 local s=c and c.shape
 if not (s and s.kind=='cliff' and c.blocks and c.secondary==M.SECONDARY) then return nil end
 return M.SPEC[c.mid]
end

local function tex(uv,px,py)
 return {uv[1][1]+(uv[2][1]-uv[1][1])*px/16,uv[1][2]+(uv[3][2]-uv[1][2])*py/16}
end
local function up(uv,px0,py0,px1,py1)
 return {tex(uv,px0,py0),tex(uv,px1,py0),tex(uv,px1,py1),tex(uv,px0,py1)}
end
local SH={east=.78,west=.78,south=.84,north=.72}

local function box(emit,x0,x1,z0,z1,y0,y1,top,south,north,west,east,bottom)
 if top then emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},top,1) end
 if bottom then emit({{x0,y0,z0},{x0,y0,z1},{x1,y0,z1},{x1,y0,z0}},bottom,.6) end
 if south then emit({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},south,SH.south) end
 if north then emit({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},north,SH.north) end
 if west then emit({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},west,SH.west) end
 if east then emit({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},east,SH.east) end
end

-- the floor tile the block's lid shows under the railing
-- the walls of the block under a railing are the ridge's rock face, not the railing art
function M.face(c,uvFor)return uvFor(c.ts,M.ROCK)end
function M.lid(c,uvFor)
 local uv=uvFor(c.ts,M.SPEC[c.mid].lid or M.GROUND)
 if c.ramp and uv then -- on the slope the lid is 1.41 longer: take that many fewer art rows so a pixel stays a pixel
  local v0,v1=uv[1][2],uv[3][2];v1=v0+(v1-v0)*.7071
  return {{uv[1][1],v0},{uv[2][1],v0},{uv[3][1],v1},{uv[4][1],v1}}
 end
 return uv
end

-- A post beside a stair flight (0x262 west of it, 0x263 east of it): its shoulder slopes down with the flight, from the
-- plateau at the north edge to the flight's foot at the south edge, and the post follows it (Gen3Blocks.appendRamp).
local STEP_SIDE={[0x262]=1,[0x263]=-1}
function M.shoulders(cells)
 for _,c in pairs(cells)do
  local s=M.is(c)
  local d=s and s.endFace and STEP_SIDE[c.mid]
  local f=d and cells[(c.cx+d)..':'..c.cy]
  if f and f.shape and f.shape.kind=='steps' and f.base and c.base and f.base<c.base-.25 then
   c.ramp={c.base,c.base,f.base,f.base,comp={c}}
  end
 end
end

-- the gate's ring hangs at the height of the back row's lid (the beams stand on it); the side and front beams float over the terraces
local BACK={[0x251]=true,[0x252]=true,[0x253]=true,[0x25B]=true}
local function ringLevel(c,cells)
 for d=0,3 do local n=cells[c.cx..':'..(c.cy-d)];if n and BACK[n.mid] and n.secondary==M.SECONDARY then return n.base or 0 end end
 return (c.base or 0)+32
end
local function gate(c,cells,emit,uvFor,T)
 local g=M.GATE[c.mid];if not g then return end
 local ts=c.ts
 local a,f=uvFor(ts,0x252),uvFor(ts,0x229);if not(a and f) then return end
 local own=uvFor(ts,c.mid) or a
 local X,Z=c.cx*16,c.cy*16
 local y0=ringLevel(c,cells);local y1=y0+M.GH
 local face,faceN=up(a,0,6,16,9),up(a,16,6,0,9)
 if g.bar then
  local xa,xb=g.bar[1],g.bar[2]
  box(emit,X+xa,X+xb,Z+1,Z+6,y0,y1,up(a,0,1,16,6),face,faceN,nil,nil,face)
 end
 if c.mid==0x25B then
  -- the cave entrance is two tiles: the hole (0x221) one course high in the wall's south face, the arch (0x25B's stone band) above it
  local s=cells[c.cx..':'..(c.cy+1)];local fl=s and s.base
  local h=uvFor(ts,0x221)
  if fl and fl<T-16 and h then
   local zz=Z+16.3
   emit({{X,fl+16,zz},{X+16,fl+16,zz},{X+16,fl,zz},{X,fl,zz}},up(h,0,0,16,16),SH.south)
   emit({{X,T,zz},{X+16,T,zz},{X+16,fl+16,zz},{X,fl+16,zz}},up(a,0,0,16,9),SH.south)
  end
 end
 if g.side then
  local xa,xb,za,zb=g.side[1],g.side[2],g.side[3],g.side[4]
  box(emit,X+xa,X+xb,Z+za,Z+zb,y0,y1,up(own,xa,za,xb,zb),
   zb==6 and up(f,xa-xa,7,xb-xa,12) or nil,za==1 and faceN or nil,face,face,face)
 end
 if g.front then
  local xa,xb=g.front[1],g.front[2]
  box(emit,X+xa,X+xb,Z+1,Z+6,y0,y1,up(f,0,1,16,7),up(f,0,7,16,12),up(f,16,7,0,12),nil,nil,up(f,0,7,16,12))
 end
 if g.leg then
  local xa,xb=g.leg[1],g.leg[2]
  local l=uvFor(ts,g.leg[3]);if not l then return end
  local lu=up(l,xa,0,xb,12)
  box(emit,X+xa,X+xb,Z+1,Z+6,T,y0,nil,lu,lu,lu,lu)
 end
end

-- the pink floor under the gate's front beam (the art's beam lies on it)
function M.floorUV(c,uvFor)
 if c.secondary~=M.SECONDARY then return nil end
 if c.mid==0x229 then return uvFor(c.ts,M.PINK) end
 if c.mid==0x221 then return uvFor(c.ts,M.ROCK) end -- the hole is the wall's now: the floor in front of it is rock
end
-- the arch cell stays at the plateau's height: the hole is cut into its south face (Gen3Blocks.lowerArches would sink it into an alcove)
function M.keepsHeight(c)return c.mid==0x25B and c.secondary==M.SECONDARY and true or false end

-- the post on a sloped shoulder: a wall of constant height H on the slope, as wide as the post it continues from the north,
-- its end face at the flight's foot
local function sloped(c,cells,emit,uvFor,spec,uv,side)
 local X,Z=c.cx*16,c.cy*16
 local r=c.ramp;local hN,hS=r[1],r[4]
 local p=spec.posts[1];local xa,xb=p[1],p[2]
 local north=cells[c.cx..':'..(c.cy-1)]
 local ns=north and M.is(north) and M.SPEC[north.mid]
 local np=ns and ns.posts and ns.posts[1]
 local top
 if np then xa,xb=np[1],np[2];local nuv=uvFor(north.ts,north.mid);top=nuv and up(nuv,np[5],3,np[6],13) end
 top=top or up(uv,p[5],0,p[6],4)
 local x0,x1,y,z1=X+xa,X+xb,M.H,Z+16
 local sideUV=up(side,0,M.FACE0,16,M.FACE1)
 emit({{x0,hN+y,Z},{x1,hN+y,Z},{x1,hS+y,z1},{x0,hS+y,z1}},top,1)
 emit({{x0,hN+y,Z},{x0,hS+y,z1},{x0,hS,z1},{x0,hN,Z}},sideUV,SH.west)
 emit({{x1,hS+y,z1},{x1,hN+y,Z},{x1,hN,Z},{x1,hS,z1}},sideUV,SH.east)
 emit({{x0,hS+y,z1},{x1,hS+y,z1},{x1,hS,z1},{x0,hS,z1}},up(uv,p[5],M.FACE0,p[6],M.FACE1),SH.south)
end

-- c: the railing cell, T: its base height; emit as in Gen3Blocks
function M.append(c,cells,emit,uvFor,T)
 local spec=M.SPEC[c.mid];if not spec then return end
 if spec.gate then return gate(c,cells,emit,uvFor,T) end
 local uv=uvFor(c.ts,c.mid);if not uv then return end
 local side=uvFor(c.ts,M.SIDE) or uv
 if c.ramp and spec.endFace then return sloped(c,cells,emit,uvFor,spec,uv,side) end
 local X,Z=c.cx*16,c.cy*16
 local y0,y1=T,T+M.H
 for _,b in ipairs(spec.bars or {})do
  local xa,xb=b[1],b[2]
  local z0,z1=M.Z0,M.Z1
  local west=spec.capL and xa==0 and up(side,2,M.FACE0,2+(z1-z0),M.FACE1) or nil
  local east=spec.capR and xb==16 and up(side,2,M.FACE0,2+(z1-z0),M.FACE1) or nil
  box(emit,X+xa,X+xb,Z+z0,Z+z1,y0,y1,
   up(uv,xa,M.TOP0,xb,M.TOP1),
   up(uv,xa,M.FACE0,xb,M.FACE1),
   up(uv,xb,M.FACE0,xa,M.FACE1),
   west,east)
 end
 local function post(n)local sp=n and M.is(n) and M.SPEC[n.mid];return sp and sp.posts and true or false end
 local north=cells[c.cx..':'..(c.cy-1)]
 local south=cells[c.cx..':'..(c.cy+1)]
 for _,p in ipairs(spec.posts or {})do
  local xa,xb,za,zb,ua,ub=p[1],p[2],p[3],p[4],p[5],p[6]
  local len=math.min(zb-za,12)
  local sideUV=up(side,2,M.FACE0,2+len,M.FACE1)
  local endUV=up(side,2,M.FACE0,2+(xb-xa),M.FACE1)
  local top=spec.endFace and up(uv,ua,0,ub,4) or up(uv,ua,3,ub,13)
  local front=spec.endFace and up(uv,ua,M.FACE0,ub,M.FACE1) or (not post(south) and endUV or nil)
  local back=(za>0 or not post(north)) and endUV or nil
  box(emit,X+xa,X+xb,Z+za,Z+zb,y0,y1,top,front,back,sideUV,sideUV)
 end
end

return M
