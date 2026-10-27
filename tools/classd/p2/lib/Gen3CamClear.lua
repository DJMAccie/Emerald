-- Gen3CamClear: keeps the low and orbit cameras out of solid scenery (task 20: the orbit eye sat inside the
-- Route 112 cable-car station, the low eye under a raised plate).
-- A scene is summed up as a height field of solid tops on an 8-unit grid (the top faces of its ground and rock
-- meshes and of its building models); the orbit arm (the eye `dist` back from the player at a fixed height) is
-- shortened to the first sample whose top reaches the eye. Pure Lua: tests/gen3_camclear_test.lua.
local M={}
M.CELL=8        -- grid size, world units
M.MIN_TOP=8     -- a top lower than this is level ground: it stays out of the field (a missing cell reads 0)
M.CLEAR=2       -- the eye keeps this far over a top
M.BACK=8        -- an arm that hits stops this far short of the first solid sample
M.STEP=4        -- sampling step along the arm
local CELL,OFF,STRIDE=M.CELL,4096,8192
local floor,ceil=math.floor,math.ceil
local function key(i,j)return (i+OFF)*STRIDE+(j+OFF)end
function M.new()return {top={},n=0}end
-- the cells a box [x0,x1]x[z0,z1] covers (touching an edge does not count), raised to y
local function mark(g,x0,x1,z0,z1,y)
 local i0,i1,j0,j1=floor(x0/CELL),ceil(x1/CELL)-1,floor(z0/CELL),ceil(z1/CELL)-1
 if i1<i0 then i1=i0 end
 if j1<j0 then j1=j0 end
 local top=g.top
 for i=i0,i1 do for j=j0,j1 do
  local k=key(i,j);local t=top[k]
  if not t then g.n=g.n+1;top[k]=y elseif y>t then top[k]=y end
 end end
end
M.mark=mark
-- the quads of a mesh's vertex/index lists ({x,y,z,u,v,s} vertices; a quad is vertices base+1..base+4, indices
-- 1,2,3,1,3,4): the ones that are not upright and stand at least MIN_TOP high. `skip` (optional) lists vertex
-- ranges {_,_,first,last} to leave out (Route 110's Cycling Road deck, which the player walks under).
function M.addQuads(g,v,idx,skip,tick)
 local skipAt
 if skip and #skip>0 then
  skipAt={};for _,r in ipairs(skip)do for n=r[3],r[4]do skipAt[n]=true end end
 end
 for k=1,#idx,6 do
  local ia,ib,ic,id=idx[k],idx[k+1],idx[k+2],idx[k+5]
  if not (skipAt and skipAt[ia]) then
   local a,b,c,d=v[ia],v[ib],v[ic],v[id]
   if a and b and c and d then
    local y=(a[2]+b[2]+c[2]+d[2])*.25
    if y>=M.MIN_TOP or a[2]>=M.MIN_TOP or b[2]>=M.MIN_TOP or c[2]>=M.MIN_TOP or d[2]>=M.MIN_TOP then
     local x0=math.min(a[1],b[1],c[1],d[1]);local x1=math.max(a[1],b[1],c[1],d[1])
     local z0=math.min(a[3],b[3],c[3],d[3]);local z1=math.max(a[3],b[3],c[3],d[3])
     -- upright (a wall or a riser) when it has no extent over the ground in one direction
     if x1-x0>.01 and z1-z0>.01 then mark(g,x0,x1,z0,z1,y) end
    end
   end
  end
  if tick and k%3000==1 then tick()end
 end
end
-- a building model (BuildingVoxels: faces 1 south, 2 north, 3 top, 4 east, 5 west; x0,x1,h0,h1,z0,z1 in drawing
-- pixels from its origin ox,oy,oz): its top faces
function M.addModel(g,quads,ox,oy,oz,tick)
 if type(quads)~='table' then return end
 for i=1,#quads,10 do
  if quads[i]==3 then
   local y=oy+quads[i+3]
   if y>=M.MIN_TOP then mark(g,ox+quads[i+1],ox+quads[i+2],oz+quads[i+5],oz+quads[i+6],y)end
  end
  if tick and i%3000==1 then tick()end
 end
end
function M.topAt(g,x,z)
 return g.top[key(floor(x/CELL),floor(z/CELL))] or 0
end
-- how far back from (cx,cz) an eye at height `ey` can stand along the heading (dx,dz) (unit length) before it is
-- inside a solid top: `dist` if the whole arm is clear, otherwise 0..dist
function M.arm(g,cx,cz,dx,dz,ey,dist)
 if not g or g.n==0 or dist<=0 then return dist end
 local need=ey-M.CLEAR
 local t=0
 while t<=dist do
  if M.topAt(g,cx-dx*t,cz-dz*t)>need then
   return math.max(0,t-M.BACK)
  end
  t=t+M.STEP
 end
 if M.topAt(g,cx-dx*dist,cz-dz*dist)>need then return math.max(0,dist-M.BACK)end
 return dist
end
-- eases a camera arm: a shorter arm takes effect at once (never inside the wall), a longer one grows back at
-- `rate` units per second. `state` is a table kept by the caller ({arm,key}); `key` changes (a new scene, a
-- teleport) reset it.
function M.ease(state,want,dt,rate,key)
 if state.key~=key or not state.arm then state.key=key;state.arm=want;return want end
 if want<state.arm then state.arm=want else state.arm=math.min(want,state.arm+(rate or 90)*(dt or 0))end
 return state.arm
end
return M
