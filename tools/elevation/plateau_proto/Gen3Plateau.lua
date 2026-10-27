-- Rock on a hand-drawn (pinned) map stands per platform (user 2026-10-27: "we NEED to make sure we do everything per
-- platform and not just gung-ho build rocks everywhere"). Every rock mass is emitted through Gen3Mass.append; here its
-- vertices are capped:
--  * a FACE (an unnumbered rock band beside floors of two or more heights) is slightly slanted: its top is the upper
--    floor's level beside it and falls toward the lower floor across the band's width, never above the upper floor;
--  * a numbered MASS (a mark on one of its cells: a rock top) stands at its number, the cap of its cells the nearest mark's;
--  * rock beside floors of ONE height (a sea rock, a lone boulder, a mountain with no plateau above it) is left to its builder.
-- It only ever lowers a vertex (min), so the builders' own detail below the cap stays. Maps without marks: untouched.
local V=...
local M={enabled=true}
local okP,PinData=pcall(V.require,'Gen3PinData')
if not okP then PinData=nil end
M.RADIUS=8      -- cells: how far from a rock cell the floors that bound its face are looked for
M.MAXFALL=0   -- fraction of the height difference a face's cap may fall below the upper floor
M.stats={}      -- mapId -> {cells=,face=,mass=,free=,clamped=}

local function ckey(x,y)return x..':'..y end
local function walk(n)return (n.collision or 0)==0 end
local function floorOf(n)return n.floorHigh or n.base or 0 end

-- cap[cell] = px, or nil (cell left to its builder); built once per mass
local function build(mass,cells,mapId)
 local E=V.require('Gen3Elevation')
 local rows=PinData and PinData.MAPS[mapId]
 local px=E.PIN_PX or 16
 local marks={}
 if rows then for _,r in ipairs(rows)do marks[ckey(r[1],r[2])]=r[3]*px end end
 local inMass={};for _,c in ipairs(mass.members)do inMass[ckey(c.cx,c.cy)]=true end
 local cap={}
 local st=M.stats[mapId] or {cells=0,face=0,mass=0,free=0,clamped=0};M.stats[mapId]=st
 -- numbered cells of this mass
 local srcs={}
 for _,c in ipairs(mass.members)do local m=marks[ckey(c.cx,c.cy)];if m then srcs[#srcs+1]={c.cx,c.cy,m} end end
 local R=M.RADIUS
 for _,c in ipairs(mass.members)do
  st.cells=st.cells+1
  local k=ckey(c.cx,c.cy)
  local best,bd
  for _,s in ipairs(srcs)do
   local d=math.max(math.abs(s[1]-c.cx),math.abs(s[2]-c.cy))
   if d<=2*R and (not bd or d<bd) then best,bd=s[3],d end
  end
  if best then cap[k]=best;st.mass=st.mass+1
  else
   local floors={}
   local hi,lo
   for dy=-R,R do for dx=-R,R do
    local nk=ckey(c.cx+dx,c.cy+dy)
    local n=not inMass[nk] and cells[nk]
    if n and n.base and (walk(n) or (n.shape and n.shape.kind=='water')) then
     local h=floorOf(n);local d=math.max(math.abs(dx),math.abs(dy))
     floors[#floors+1]={h,d}
     if not hi or h>hi then hi=h end
     if not lo or h<lo then lo=h end
    end
   end end
   if hi and hi-lo>=8 then
    local dh,dl=99,99
    for _,f in ipairs(floors)do
     if f[1]>=hi-1 and f[2]<dh then dh=f[2] end
     if f[1]<=lo+1 and f[2]<dl then dl=f[2] end
    end
    cap[k]=hi-(hi-lo)*math.min((dh-1)/(dh+dl-1),M.MAXFALL);st.face=st.face+1   -- (never down to the low floor: the deep inside of a wide rock stays well over the water)
   else st.free=st.free+1 end
  end
 end
 return cap
end

-- emit wrapper: caps every vertex at the highest cap of the rock cells that touch it
function M.wrap(mass,cells,emit)
 local mapId=mass.mapId
 local E=V.require('Gen3Elevation')
 if not (M.enabled and mapId and E.PINS_ON and not E.PIN_SKIP[mapId] and PinData and PinData.MAPS[mapId] and cells and not mass.object) then return emit end
 local cap=mass.plateauCap
 if not cap then cap=build(mass,cells,mapId);mass.plateauCap=cap end
 if next(cap)==nil then return emit end
 local st=M.stats[mapId]
 local function cellsAt(u)
  local f=u/16;local r=math.floor(f+.5)
  if math.abs(f-r)<1e-3 then return r-1,r end
  local c=math.floor(f);return c,c
 end
 return function(v,t,shade)
  local out,changed=v,false
  for i=1,#v do
   local a=v[i]
   local x0,x1=cellsAt(a[1]);local z0,z1=cellsAt(a[3])
   local m=nil
   for cx=x0,x1 do for cz=z0,z1 do
    local q=cap[ckey(cx,cz)]
    if q and (not m or q>m) then m=q end
   end end
   if m and a[2]>m then
    if not changed then out={};for j=1,#v do out[j]=v[j] end;changed=true end
    local b={a[1],m,a[3]};for j=4,#a do b[j]=a[j] end
    out[i]=b;st.clamped=st.clamped+1
   end
  end
  return emit(out,t,shade)
 end
end

return M
