-- Where the 3D battle stands. Gen3Battle asks for one arena placement: the
-- default first, then the arena centre moved up to three cells each way, then
-- the whole arena turned about the player's cell in 30-degree steps. The first
-- candidate that passes is taken, and a valid default is always the default.
--
-- A candidate passes when (a) both Pokemon stand on plain ground or grass (not
-- water, a ledge, stairs or a warp) at the player's height, within 8 px, and
-- (b) no tall scenery stands between the resting camera's eye and either
-- Pokemon's body centre or its feet. Read only: the scene, collision and the
-- battle clearing are asked, never changed.
local V=...
local M={}
M.STEP=math.rad(30)  -- one turn of the arena
M.TURNS=6            -- up to 180 degrees each way
M.SHIFT=3            -- cells each way for the centre
M.HEIGHT_TOL=8       -- ground within this of the player's, px
M.SIGHT_TOL=2        -- a sample this far above the sightline blocks it, px
M.SAMPLE=8           -- sightline sample spacing, px
-- Scene kinds that never block a sightline: plain and planted ground, water,
-- ledges, stairs, fences, signs, rails and bridge decks. Every other kind is
-- tall scenery (walls, rooms' walls and furniture, buildings, roofs, trees,
-- cliffs, rocks, cave walls).
local LOW={flat=true,interiorFloor=true,grass=true,flowers=true,shrub=true,plant=true,
 water=true,ledge=true,steps=true,ladder=true,escalator=true,fence=true,sign=true,rail=true,
 pixel=true,deckFloor=true,deckRamp=true,deckEdge=true,deckBack=true,deckFace=true,
 deckHead=true,deckMixed=true}
-- Kinds an actor may stand on.
local STAND={flat=true,grass=true,interiorFloor=true}

-- A cell's tall height above its ground, px; nil for low scenery. The column's
-- own height first, then the shape's, then 32 for trees and 48 for the rest.
local function tallOf(c)
 local k=c.shape and c.shape.kind
 if not k or LOW[k] then return nil end
 local col=c.column
 return (col and tonumber(col.height)) or (c.shape and tonumber(c.shape.height))
  or (k=='tree' and 32) or 48
end

-- Whether BattleClear hides the cell (its own footprint, or its column's group).
local function hidden(BattleClear,cam,c,cx,cy)
 local kind=c.shape and c.shape.kind
 if BattleClear.hits(cam,cx*16,cy*16,cx*16+(kind=='tree' and 32 or 16),cy*16+32) then return true end
 local g=c.column and c.column.group
 return g~=nil and g.left~=nil and g.back~=nil and g.right~=nil and g.front~=nil
  and BattleClear.hits(cam,g.left,g.back,g.right,g.front) or false
end

-- The top of the scene at a world point as the battle draws it: the ground,
-- or the ground plus a tall cell's height unless that cell is hidden.
local function topAt(Scene,BattleClear,cam,x,z)
 local g=Scene.groundAt(x,z)
 local cx,cy=math.floor(x/16),math.floor(z/16)
 local c=Scene.debugRaw(cx,cy)
 if not c then return g end
 local h=tallOf(c)
 if h and not hidden(BattleClear,cam,c,cx,cy) then return g+h end
 return g
end

-- The straight line from e to t, sampled every M.SAMPLE px between its ends.
-- Fails on the first sample whose scene top stands above the line.
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

-- Plain walkable ground an actor may stand on at cell cx,cy; and why not.
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

-- spec:
--   center {x,z}  the default arena centre (world units)
--   yaw           the default arena heading (the rest camera's yaw)
--   anchor {x,z}  the player's cell centre, the point the arena turns about
--   height        the rest camera's height above its ground
--   view(cx,cz,h) a camera table for that centre and heading (scene's own rest rig)
--   actors(cam)   each Pokemon as {x=,z=,H=} (H nil when its height is unknown)
--   fit(cam)      the rest distance the scene will use (Gen3Battle's M.fit)
--   log           print the choice and the default's reason
-- Returns {center=,yaw=,dist=,rot=,dx=,dy=,index=} or {none=true,center=,yaw=}
-- with the default when nothing is valid (or the models are not placed).
function M.choose(spec)
 local Collision=require('src.core.game3.collision')
 local Scene=V.require('Gen3Scene')
 local BattleClear=V.require('Gen3BattleClear')
 local ax,az=spec.anchor[1],spec.anchor[2]
 local playerG=Scene.groundAt(ax,az)
 local function default(none)
  return {none=none,center=spec.center,yaw=spec.yaw}
 end
 -- nothing placed (no model to test against): the default, as before
 if #spec.actors(spec.view(spec.center[1],spec.center[2],spec.yaw))<2 then return default(false) end

 -- Returns true and the rest distance, or false and the reason.
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

 -- The candidates, closest to the default first: the default, the centre
 -- shifted by fewer cells first, then the arena turned by the smallest angle.
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
   -- the whole arena turns about the player's cell: the centre swings round
   -- it and the heading turns by the same angle
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
