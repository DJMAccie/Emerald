-- FireRed building-specific roof treatment. Native art supplies the materials;
-- grass outside the Pallet roof silhouette stays on the ground, and the lab's
-- chimney is a separate solid object above its flat roof.
local M={}
M.LOW_RIDGE={{0,4},{.22,10},{1,0}}
M.TWO_TIER={{0,12},{.125,20},{.71,12},{.855,3},{1,0}}
local baked={}
function M.sideVisible(cells,c,dx)
 local n=cells[(c.cx+dx)..':'..c.cy]
 local a,b=c.column,n and n.column
 if not b or n.pair~=c.pair then return true end
 -- One Emerald building is one shell: no fins between its own columns,
 -- except where a roofless wing meets a roofed hall.
 if a.groupId then
  if a.groupId~=b.groupId then return true end
  return (a.roofs==0)~=(b.roofs==0) or (a.roofs==0 and a.first~=b.first)
 end
 -- A building is one shell, not a row of boxes. Internal dividers became
 -- visible as fins when transparent source grass exposed the roof's back.
 for _,field in ipairs({'height','front','back','roofType','roofInset','roofs'})do
  if a[field]~=b[field] then return true end
 end
 return false
end
M.RIDGE_AT=.2      -- ridge position, as a fraction of the depth from the back
M.PITCH=.5         -- rise per unit of front-slope run
function M.ridge(column)
 local depth=column.front-column.back
 local ridge=column.back+depth*M.RIDGE_AT
 return ridge,math.min(22,(column.front-ridge)*M.PITCH)
end
function M.height(column,z)
 if column.roofType=='flat' or column.roofs==0 then return column.height end
 local back=column.back+(column.front-column.back)*(column.roofInset or 0)/(column.roofs*16)
 local t=(z-back)/(column.front-back)
 if column.roofType=='front' then
  -- The cartridge draws a roof as seen from the front and above: every roof
  -- row is the FRONT slope. So the drawing goes, undistorted, on one plane
  -- from the eave up to a ridge set toward the back, and a short plain back
  -- slope closes the house. (A symmetric gable put the top art row on a
  -- slope facing away from the camera and stretched the rest.)
  local ridge,rise=M.ridge(column)
  if z<=ridge then return column.height+rise*math.max(0,(z-column.back)/(ridge-column.back)) end
  return column.height+rise*math.max(0,(column.front-z)/(column.front-ridge))
 end
 if column.roofType=='lowRidge' then
  -- A shallow pitched roof whose pale ridge band runs along the back
  -- (Birch's lab): short back slope, long front slope.
  local knots=M.LOW_RIDGE
  t=math.max(0,math.min(1,t))
  for k=2,#knots do
   local a,b=knots[k-1],knots[k]
   if t<=b[1] then return column.height+a[2]+(b[2]-a[2])*(t-a[1])/(b[1]-a[1]) end
  end
  return column.height
 end
 if column.roofType=='twoTier' then
  -- A two-storey house as the cartridge draws it (Littleroot): an upper roof
  -- whose ridge sits near the back, the upper storey's pale wall band standing
  -- nearly upright below it, and a short skirt roof down to the front eave.
  -- Knots are (fraction of roof depth, rise above the wall top), read off the
  -- drawing: the band occupies rows 34-41 of the 48 the roof spans.
  local knots=M.TWO_TIER
  t=math.max(0,math.min(1,t))
  for k=2,#knots do
   local a,b=knots[k-1],knots[k]
   if t<=b[1] then return column.height+a[2]+(b[2]-a[2])*(t-a[1])/(b[1]-a[1]) end
  end
  return column.height
 end
 -- Straight gable faces and vertical gable ends. No automatic barrel curve
 -- or hipped sides: those need a building profile that actually calls for it.
 return column.height+13*(1-math.abs(2*t-1))
end
function M.prepare(cells)
 local chimneys={}
 for _,c in pairs(cells)do
  if c.secondary=='pallet_town' and c.mid==0x2BD then
   local rows={{0x2BD,0x2B5},{0x2B3,0x2B4},{0x2BB,0x2BC}}
   local match=true;local parts={}
   for y,row in ipairs(rows)do for x,mid in ipairs(row)do
    local n=cells[(c.cx+x-1)..':'..(c.cy+y-1)]
    if not n or n.pair~=c.pair or n.mid~=mid or not n.column or n.column.roofType~='flat' then match=false end
    parts[#parts+1]={cell=n,row=y}
   end end
   if match then
    for _,p in ipairs(parts)do p.cell.roofMid=({0x2A9,0x2B1,0x2B9})[p.row] end
    chimneys[#chimneys+1]={cx=c.cx,cy=c.cy,ts=c.ts,pair=c.pair,height=c.column.height}
   end
  end
 end
 return chimneys
end
function M.image(ts,secondary,shapeOf,used)
 local old=baked[ts.pair];local complete=old and old.ts==ts
 if complete then for mid,how in pairs(used or {})do if old.mids[mid]~=how then complete=false;break end end end
 if complete then return old.image end
 local mids={};for mid,how in pairs(old and old.ts==ts and old.mids or {})do mids[mid]=how end
 for mid,how in pairs(used or {})do mids[mid]=how end
 if not ts.imageData then return nil end
 local data=ts.imageData:clone()
 for mid,slot in pairs(ts.midToSlot)do
  if mids[mid] or shapeOf('general',secondary,mid).kind=='roof' then
   local x0,y0=slot%ts.cols*16,math.floor(slot/ts.cols)*16
   local px={}
   -- A roof row painted over walkable ground behind the house keeps its
   -- roof on the layer drawn ABOVE the player; the layer below is whatever
   -- lies behind (grass, a path, a tree, a cliff) and is not roof.
   local overOnly=false
   if mids[mid]=='over' and ts.overImageData then
    local n=0
    for y=0,15 do for x=0,15 do local _,_,_,a=ts.overImageData:getPixel(x0+x,y0+y);if a>.5 then n=n+1 end end end
    overOnly=n>=24
   end
   for y=0,15 do px[y]={};for x=0,15 do
    local r,g,b,a=ts.imageData:getPixel(x0+x,y0+y)
    if overOnly then r,g,b,a=ts.overImageData:getPixel(x0+x,y0+y)
    elseif ts.overImageData then
     local rr,gg,bb,aa=ts.overImageData:getPixel(x0+x,y0+y)
     r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),aa+a*(1-aa)
    end
    -- Pallet's roof art is salmon/grey, its background mint. Scope this to
    -- these reviewed roof cells: a green Viridian roof is never cut away.
    if (secondary=='pallet_town' or mid<0x280) and g>r+.035 and g>b+.02 then a=0 end
    px[y][x]={r,g,b,a}
   end end
   -- A roof is a solid surface. Where the drawing leaves a corner or notch
   -- open (it was painted over grass), carry the roof's own nearest colour
   -- across the gap, row by row, so the box is closed and no patch shows.
   if secondary~='pallet_town' then
    -- the roof's main colour: commonest opaque colour that is not outline
    local counts,best,n={},nil,0
    for y=0,15 do for x=0,15 do local q=px[y][x]
     if q[4]>.5 and .3*q[1]+.59*q[2]+.11*q[3]>.3 then
      local k=math.floor(q[1]*255+.5)*65536+math.floor(q[2]*255+.5)*256+math.floor(q[3]*255+.5)
      counts[k]=(counts[k] or 0)+1
      if counts[k]>n then best,n=q,counts[k] end
     end
    end end
    if best then
     -- A roof row that is only a sliver of art over open air (the cap of a
     -- Mart or Center roof) stays open above its topmost drawn pixel in each
     -- column, so the roof keeps its drawn outline instead of gaining a
     -- solid block behind it; everything below the outline is closed.
     for x=0,15 do
      local first
      for y=0,15 do if px[y][x][4]>.5 then first=y;break end end
      local from=mids[mid]=='over' and (first or 16) or 0
      for y=from,15 do
       if px[y][x][4]<=.5 then px[y][x]={best[1],best[2],best[3],1} end
      end
     end
    end
   end
   for y=0,15 do for x=0,15 do local q=px[y][x];data:setPixel(x0+x,y0+y,q[1],q[2],q[3],q[4]) end end
  end
 end
 local image=love.graphics.newImage(data);image:setFilter('nearest','nearest');data:release()
 if old then old.image:release()end
 baked[ts.pair]={ts=ts,image=image,mids=mids};return image
end
function M.appendChimney(p,emit,uvFor)
 local x,z,y=p.cx*16+3,p.cy*16+22,p.height
 local art=uvFor(p.ts,0x2B3)
 local function sample(uv,px,py)
  local u=uv[1][1]+(uv[2][1]-uv[1][1])*px/16
  local v=uv[1][2]+(uv[3][2]-uv[1][2])*py/16
  return {{u,v},{u,v},{u,v},{u,v}}
 end
 local brick,dark=sample(art,4,7),sample(art,13,7)
 local function box(x0,z0,x1,z1,bottom,top,uv,shade)
  emit({{x0,top,z0},{x1,top,z0},{x1,top,z1},{x0,top,z1}},uv,shade)
  emit({{x0,top,z1},{x1,top,z1},{x1,bottom,z1},{x0,bottom,z1}},uv,shade*.84)
  emit({{x1,top,z0},{x0,top,z0},{x0,bottom,z0},{x1,bottom,z0}},uv,shade*.75)
  emit({{x0,top,z0},{x0,top,z1},{x0,bottom,z1},{x0,bottom,z0}},uv,shade*.78)
  emit({{x1,top,z1},{x1,top,z0},{x1,bottom,z0},{x1,bottom,z1}},uv,shade*.88)
 end
 box(x,z,x+15,z+16,y,y+17,brick,1)
 -- Raised brick courses and a cap around a recessed dark flue.
 for h=4,16,4 do box(x-.15,z-.15,x+15.15,z+16.15,y+h-.45,y+h,brick,.78)end
 box(x-1,z-1,x+16,z+2,y+17,y+20,brick,1)
 box(x-1,z+14,x+16,z+17,y+17,y+20,brick,1)
 box(x-1,z+2,x+2,z+14,y+17,y+20,brick,1)
 box(x+13,z+2,x+16,z+14,y+17,y+20,brick,1)
 emit({{x+2,y+17.1,z+2},{x+13,y+17.1,z+2},{x+13,y+17.1,z+14},{x+2,y+17.1,z+14}},dark,.28)
end
function M.release()
 for _,p in pairs(baked)do p.image:release()end;baked={}
end
return M
