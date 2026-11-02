-- Where the 3D battle stands
local V=...
local M={}
M.STEP=math.rad(30) -- one turn of the arena
M.TURNS=6 -- up to 180 degrees each way
M.SHIFT=3 -- cells each way for the centre
M.HEIGHT_TOL=8 -- ground within this of the player's, px
M.SIGHT_TOL=2
M.SAMPLE=8 -- sightline sample spacing, px
local LOW={flat=true,interiorFloor=true,grass=true,flowers=true,shrub=true,plant=true,
 water=true,ledge=true,steps=true,ladder=true,escalator=true,fence=true,sign=true,rail=true,
 pixel=true,deckFloor=true,deckRamp=true,deckEdge=true,deckBack=true,deckFace=true,
 deckHead=true,deckMixed=true}
local STAND={flat=true,grass=true,interiorFloor=true}

local function tallOf(c)
 local k=c.shape and c.shape.kind
 if not k or LOW[k] then return nil end
 local col=c.column
 return (col and tonumber(col.height)) or (c.shape and tonumber(c.shape.height))
  or (k=='tree' and 32) or 48
end

local function hidden(BattleClear,cam,c,cx,cy)
 local kind=c.shape and c.shape.kind
 if BattleClear.hits(cam,cx*16,cy*16,cx*16+(kind=='tree' and 32 or 16),cy*16+32) then return true end
 local g=c.column and c.column.group
 return g~=nil and g.left~=nil and g.back~=nil and g.right~=nil and g.front~=nil
  and BattleClear.hits(cam,g.left,g.back,g.right,g.front) or false
end

local function topAt(Scene,BattleClear,cam,x,z)
 local g=Scene.groundAt(x,z)
 local cx,cy=math.floor(x/16),math.floor(z/16)
 local c=Scene.debugRaw(cx,cy)
 if not c then return g end
 local h=tallOf(c)
 if h and not hidden(BattleClear,cam,c,cx,cy) then return g+h end
 return g
end

local function clearLine(Scene,BattleClear,cam,e,t)
 local dx,dy,dz=t[1]-e[1],t[2]-e[2],t[3]-e[3]
 local L=math.sqrt(dx*dx+dy*dy+dz*dz)
 local s=M.SAMPLE
 while s<L-M.SAMPLE do
  local f=s/L
  local x,y,z=e[1]+dx*f,e[2]+dy*f,e[3]+dz*f
  if topAt(Scene,BattleClear,cam,x,z)>y+M.SIGHT_TOL then return false end
  s=s+M.SAMPLE
 end
 return true
end

local function standable(Collision,Scene,cx,cy)
 local where=cx..','..cy
 if not Collision.isWalkable(cx,cy) then
  local c=Scene.debugRaw(cx,cy)
  return false,where..' blocked (coll '..string.format('%02x',Collision.cell(cx,cy) or 0)..' kind '..tostring(c and c.shape and c.shape.kind)..')'
 end
 if Collision.isWater(cx,cy) then return false,where..' water' end
 local beh=Collision.behavior(cx,cy)
 if Collision.isStairWarpBehavior(beh) or Collision.isWarpMetatileBehavior(beh) then return false,where..' warp' end
 local c=Scene.debugRaw(cx,cy)
 if not c then return false,where..' unbuilt' end
 if c.stairs or c.prop then return false,where..' stairs/prop' end
 local k=c.shape and c.shape.kind or '?'
 if not STAND[k] then return false,where..' kind '..k end
 return true
end

function M.choose(spec)
 local Collision=require('src.core.game3.collision')
 local Scene=V.require('Gen3Scene')
 local BattleClear=V.require('Gen3BattleClear')
 local ax,az=spec.anchor[1],spec.anchor[2]
 local playerG=Scene.groundAt(ax,az)
 local function default(none)
  return {none=none,center=spec.center,yaw=spec.yaw}
 end
 if #spec.actors(spec.view(spec.center[1],spec.center[2],spec.yaw))<2 then return default(false) end

 local function test(cx,cz,h)
  local cam=spec.view(cx,cz,h)
  local acts=spec.actors(cam)
  if #acts<2 then return false,'no models' end
  for _,a in ipairs(acts) do
   local okS,whyS=standable(Collision,Scene,math.floor(a.x/16),math.floor(a.z/16))
   if not okS then return false,'ground '..whyS end
   local gh=Scene.groundAt(a.x,a.z)
   if math.abs(gh-playerG)>M.HEIGHT_TOL then return false,string.format('height %.0f vs %.0f',gh,playerG) end
  end
  local dist=spec.fit(cam)
  local dx,dz=math.sin(h),-math.cos(h)
  local eye={cx-dx*dist,Scene.groundAt(cx,cz)+spec.height,cz-dz*dist}
  for _,a in ipairs(acts) do
   local g=Scene.groundAt(a.x,a.z)
   if not clearLine(Scene,BattleClear,cam,eye,{a.x,g+(a.H and a.H/2 or 16),a.z}) then return false,'sight body' end
   if not clearLine(Scene,BattleClear,cam,eye,{a.x,g,a.z}) then return false,'sight feet' end
  end
  return true,dist
 end

 local cands={{}}
 local shifts={}
 local S=M.SHIFT
 for dy=-S,S do for dx=-S,S do
  if dx~=0 or dy~=0 then shifts[#shifts+1]={dx=dx,dy=dy} end
 end end
 table.sort(shifts,function(a,b)
  local da,db=a.dx*a.dx+a.dy*a.dy,b.dx*b.dx+b.dy*b.dy
  if da~=db then return da<db end
  if a.dy~=b.dy then return a.dy<b.dy end
  return a.dx<b.dx
 end)
 for _,s in ipairs(shifts) do cands[#cands+1]=s end
 for k=1,M.TURNS do
  for _,sign in ipairs({1,-1})do
   if not (k==M.TURNS and sign<0) then cands[#cands+1]={rot=sign*k*M.STEP} end
  end
 end

 local cx0,cz0=spec.center[1],spec.center[2]
 for i,c in ipairs(cands)do
  local cx,cz,h=cx0,cz0,spec.yaw
  if c.rot then
   local vx,vz=cx0-ax,cz0-az
   local co,si=math.cos(c.rot),math.sin(c.rot)
   cx,cz=ax+vx*co-vz*si,az+vx*si+vz*co
   h=spec.yaw+c.rot
  elseif c.dx then
   cx,cz=cx0+c.dx*16,cz0+c.dy*16
  end
  local ok,info=test(cx,cz,h)
  if ok then
   if spec.log then
    print(string.format('[Battle Art] stage candidate %d of %d: rot %d deg, shift %d,%d cells, centre %.0f,%.0f, dist %.0f',
     i,#cands,math.floor(math.deg(c.rot or 0)+.5),c.dx or 0,c.dy or 0,cx,cz,info))
   end
   return {center={cx,cz},yaw=h,dist=info,rot=c.rot or 0,dx=c.dx or 0,dy=c.dy or 0,index=i}
  end
  if spec.log then
   print(string.format('[Battle Art] stage candidate %d rejected: rot %d deg, shift %d,%d: %s',
    i,math.floor(math.deg(c.rot or 0)+.5),c.dx or 0,c.dy or 0,tostring(info)))
  end
 end
 return default(true)
end

return M
