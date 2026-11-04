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

local function box(emit,x0,x1,z0,z1,y0,y1,top,south,north,west,east)
 emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},top,1)
 if south then emit({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},south,SH.south) end
 if north then emit({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},north,SH.north) end
 if west then emit({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},west,SH.west) end
 if east then emit({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},east,SH.east) end
end

-- the floor tile the block's lid shows under the railing
-- the walls of the block under a railing are the ridge's rock face, not the railing art
function M.face(c,uvFor)return uvFor(c.ts,M.ROCK)end
function M.lid(c,uvFor)return uvFor(c.ts,M.SPEC[c.mid].lid or M.GROUND)end

-- c: the railing cell, T: its base height; emit as in Gen3Blocks
function M.append(c,cells,emit,uvFor,T)
 local spec=M.SPEC[c.mid];if not spec then return end
 local uv=uvFor(c.ts,c.mid);if not uv then return end
 local side=uvFor(c.ts,M.SIDE) or uv
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
