-- Gen3CamClear
local M={}
M.CELL=8 -- grid size, world units
M.MIN_TOP=8
M.CLEAR=2 -- the eye keeps this far over a top
M.BACK=8
M.STEP=4 -- sampling step along the arm
local CELL,OFF,STRIDE=M.CELL,4096,8192
local floor,ceil=math.floor,math.ceil
local function key(i,j)return (i+OFF)*STRIDE+(j+OFF)end
function M.new()return {top={},n=0}end
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
     if x1-x0>.01 and z1-z0>.01 then mark(g,x0,x1,z0,z1,y) end
    end
   end
  end
  if tick and k%3000==1 then tick()end
 end
end
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
-- Shorter arm applies at once (never inside a wall); longer grows back at `rate`.
function M.ease(state,want,dt,rate,key)
 if state.key~=key or not state.arm then state.key=key;state.arm=want;return want end
 if want<state.arm then state.arm=want else state.arm=math.min(want,state.arm+(rate or 90)*(dt or 0))end
 return state.arm
end
return M
