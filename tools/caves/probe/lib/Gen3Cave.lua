-- Cave masses and boulders use their native palette and silhouette. Geometry
-- is presentation-only; a wall recipe also needs the cell's solid collision.
local V=...
local M={}
local function boulderMask(mask)
 -- One metatile contains one boulder. Its source drawing may also include
 -- disconnected floor stripes or grit whose colours differ from the ground
 -- swatch; those are not extra rings of the rock's silhouette.
 local visited,best={},{}
 for start=0,255 do if mask[start] and not visited[start] then
  local component,queue={}, {start};visited[start]=true
  local at=1
  while queue[at] do
   local k=queue[at];at=at+1;component[#component+1]=k
   local x,y=k%16,math.floor(k/16)
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local nx,ny=x+d[1],y+d[2];local nextKey=ny*16+nx
    if nx>=0 and nx<16 and ny>=0 and ny<16 and mask[nextKey] and not visited[nextKey] then
     visited[nextKey]=true;queue[#queue+1]=nextKey
    end
   end
  end
  if #component>#best then best=component end
 end end
 local out={};for _,k in ipairs(best)do out[k]=true end
 return out
end
function M.wall(cells,c,emit,uvFor)
 return V.require('Gen3Terrain').append(cells,c,emit,uvFor)
end
-- (a boulder's hull depends only on its tile, its ground and the props setting: made once per tileset and
-- shared - each rock cell built its own, a sixth of Rustboro's first view without the JIT)
-- A boulder drawn on a floor whose own colours it shares (Sky Pillar's pale stones on pale floor): the colour test of
-- Gen3Outdoor.mask leaves almost nothing, so the rock is what differs from the floor tile pixel by pixel.
function M.positionMask(ts,mid,floor)
 local a,b=ts.midToSlot[mid],ts.midToSlot[floor]
 if not (a and b and ts.imageData) then return end
 local function px(slot,x,y)
  local X,Y=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
  local r,g,bl,al=ts.imageData:getPixel(X,Y)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(X,Y);r,g,bl,al=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+bl*(1-aa),aa+al*(1-aa) end
  return math.floor(r*255+.5),math.floor(g*255+.5),math.floor(bl*255+.5),al
 end
 local mask,n={},0
 for y=0,15 do for x=0,15 do
  local r,g,bl,al=px(a,x,y)
  local fr,fg,fb=px(b,x,y)
  if al>0 and (r~=fr or g~=fg or bl~=fb) then mask[y*16+x]=true;n=n+1 end
 end end
 if n>0 then return mask end
end
local rockMemo=setmetatable({},{__mode='k'})
local function rockHull(c,uvFor)
 local mask=c.shape.floorTile and M.positionMask(c.ts,c.mid,c.shape.floorTile) or V.require('Gen3Outdoor').mask(c.ts,c.mid,c.shape.ground)
 if not mask then return end
 mask=boulderMask(mask)
 local uv=assert(uvFor(c.ts,c.mid))
 local function tex(x,y)
  return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,
   uv[1][2]+(uv[3][2]-uv[1][2])*y/16}
 end
 local slot=c.ts.midToSlot[c.mid]
 local px,py=slot%c.ts.cols*16,math.floor(slot/c.ts.cols)*16
 -- Carve over the mask's OWN bounding box, not the whole 16x16 tile. A
 -- metatile draws its boulder in the middle with a wall behind it, so hulling
 -- the full tile makes the block as wide as the artwork and the floor stripe
 -- and the loose dirt speckle the test is about come along with it. The older
 -- ring builder trimmed each row to its own extent for the same reason, and
 -- this is the same guarantee expressed as a hull: the boulder's silhouette
 -- decides its size, and the art around it is not sampled as part of it.
 local minX,minY,maxX,maxY=16,16,-1,-1
 for y=0,15 do for x=0,15 do
  if mask[y*16+x]then
   if x<minX then minX=x end;if x+1>maxX then maxX=x+1 end
   if y<minY then minY=y end;if y+1>maxY then maxY=y+1 end
  end
 end end
 if maxX<minX or maxY<minY then return end
 local hw,hh=maxX-minX,maxY-minY
 -- `bottom` is how many of the carving box's rows sit BELOW the shape, which
 -- VoxelHull turns into height = h - bottom. It is not the height itself:
 -- passing the full height would zero the height and emit no faces at all.
 -- The metatile's own bottom padding, if any, is what belongs here.
 local bottom=15-maxY
 local H=V.require('VoxelHull')
 -- The hull is built over the BLOCK, which is hw x hh and centred on itself,
 -- so the block-local coordinate maps back to the metatile as minX + x.
 local sample=function(x,y)
  local sx,sy=minX+x,minY+y
  local r,g,b,a=c.ts.imageData:getPixel(px+sx,py+sy)
  -- Merged source colour only selects coplanar merges; draw uses the live
  -- native atlas (including its native BG2 pass) through the sampled UV.
  local uvx,uvy=unpack(tex(sx+.5,sy+.5))
  return r,g,b,mask[sy*16+sx]and a or 0,uvx,uvy
 end
 local card=V.require('TreePresentation').props:get()=='cards'
 local hull=card and H.card(hw,hh,sample,bottom,c.shape.height or 16)
  or H.build(hw,hh,sample,1,bottom,nil,'rock')
 -- VoxelHull emits a block spanning [-w/2, w/2] about the origin, so the
 -- block's centre in metatile space is (minX+minY)/2 + size/2. Offsetting by
 -- the centre -- not the minimum -- lands the silhouette back exactly where the
 -- drawing put it, so a boulder drawn left of centre stays left of centre.
 return {hull=hull,ox=minX+hw/2,oz=minY+hh/2,card=card}
end
function M.rock(c,emit,uvFor)
 local card=V.require('TreePresentation').props:get()=='cards'
 local memo=rockMemo[c.ts];if not memo or memo.n>256 then memo={n=0};rockMemo[c.ts]=memo end
 local key=tostring(c.mid)..':'..tostring(c.shape.ground)..':'..tostring(c.shape.floorTile)..':'..tostring(card)..':'..tostring(c.shape.height)..':'..tostring(uvFor)
 local r=memo[key]
 if r==nil then r=rockHull(c,uvFor) or false;memo[key]=r;memo.n=memo.n+1 end
 if not r then return end
 local hull,ox,oz=r.hull,r.ox,r.oz
 for _,q in ipairs(hull)do
  local points={};local t={q.u,q.v}
  for _,p in ipairs(q)do
   points[#points+1]={c.cx*16+ox+p[1],
    p[2]*(card and 1 or (c.shape.height or 16)/16),
    c.cy*16+oz+p[3]}
  end
  emit(points,{t,t,t,t},q.shade,card and {c.cx*16+8,c.cy*16+8,.001} or nil)
 end
end
-- Cave classes (task 28): per-map-family corrections to what the shared tables make of a cave cell.
-- settle() runs from Gen3Scene right before the rock masses are flooded (after the cave tile-shape pass).
-- Class U (underwater): the plain sea floor beyond the dive lanes is collision-blocked, so the generic
-- cave rule made it rock and stood it up as a stepped maze of terraces; in the drawing it is one flat
-- plain with the lanes sunk in it and a thin ridge along each lane.
M.UNDERWATER_FILL={[0x213]=true}
local function underwater(def)
 return tonumber(def and def.mapType)==5 and tostring(def.id or ''):find('^EM_UNDERWATER') and true or false
end
-- Class L (lava): a lava lake is blocked, so it was made rock too and stood as a stepped slab 16-40 px over the
-- floor (Terra Cave End, Magma Hideout), with its drawn shore pieces at floor level. Lava lies flat: the same
-- colour test Gen3Rock uses for its lava tiles (a tile mostly red with almost no green).
local lavaMemo=setmetatable({},{__mode='k'})
local function isLava(c)
 local ts=c.ts
 if not (ts and ts.imageData and ts.midToSlot and ts.midToSlot[c.mid]) then return false end
 local m=lavaMemo[ts];if not m then m={};lavaMemo[ts]=m end
 local v=m[c.mid]
 if v==nil then
  local slot=ts.midToSlot[c.mid]
  local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
  local rs,gs=0,0
  for y=0,15 do for x=0,15 do local r,g=ts.imageData:getPixel(ox+x,oy+y);rs=rs+r;gs=gs+g end end
  v=rs/256>.7 and gs/256<.32;m[c.mid]=v
 end
 return v
end
-- Class S (Sky Pillar floors): the dark square in the floor is a pit, blocked and drawn dark with a lighter lip along its
-- north edge; the generic rule made it a mass and stood it 12-40 px over the floor as a navy block. The grey boulders
-- (one tile each, also in a row of eight) were cliff cells of a mass with no height at all: invisible. Pit tiles lie flat
-- (their dark drawing is the pit); boulder tiles are boulders on the floor, like the round rocks of Granite Cave.
M.PIT={general__pacifidlog={[0x238]=1,[0x239]=1,[0x23A]=1,[0x240]=1,[0x241]=1,[0x242]=1,[0x248]=1,[0x249]=1,[0x24A]=1,[0x24B]=1,[0x24D]=1}}
M.BOULDER={general__pacifidlog={[0x207]=1,[0x20F]=1,[0x217]=1,[0x21F]=1}}
M.BOULDER_FLOOR={general__pacifidlog={[0x207]=0x235,[0x20F]=0x234,[0x217]=0x234,[0x21F]=0x234}}
-- (the ridge along a dive lane is a thin lip, not a wall: it stands UNDERWATER_MAXH over the lane floor)
M.UNDERWATER_MAXH=16
local baseMaxh
function M.settle(def,cells)
 local Rock=V.require('Gen3Rock')
 baseMaxh=baseMaxh or Rock.CAVE_MAXH
 Rock.CAVE_MAXH=underwater(def) and M.UNDERWATER_MAXH or baseMaxh
 for _,c in pairs(cells)do
  local k=c.shape and c.shape.kind
  if (k=='caveWall' or k=='cliff') and c.collision==7 and isLava(c) and not (c.prop or c.stairs or c.object or c.objectTop) then
   c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};c.noFurniture=true;c.caveLava=true
  end
 end
 -- (one lake, one level: the floor solver rated each lava cell from its own neighbours, so a lake lay at 0 on one side
 -- and 32 on the other; it takes the lowest level of the lake)
 local done={}
 for _,c in pairs(cells)do
  if c.caveLava and not done[c] then
   local group,q={c},{c};done[c]=true
   local low=c.base or 0
   local i=1
   while q[i]do
    local a=q[i];i=i+1
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(a.cx+d[1])..':'..(a.cy+d[2])]
     if n and n.caveLava and not done[n] then done[n]=true;group[#group+1]=n;q[#q+1]=n;low=math.min(low,n.base or 0) end
    end
   end
   for _,g in ipairs(group)do g.base=low end
  end
 end
 for _,c in pairs(cells)do
  local k=c.shape and c.shape.kind
  if (k=='caveWall' or k=='cliff') and c.collision==7 and not (c.prop or c.stairs or c.object or c.objectTop) then
   local pit,boulder=M.PIT[c.pair],M.BOULDER[c.pair]
   if pit and pit[c.mid] then c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};c.noFurniture=true
   elseif boulder and boulder[c.mid] then c.shape={kind='rock',ground=M.BOULDER_FLOOR[c.pair][c.mid],floorTile=M.BOULDER_FLOOR[c.pair][c.mid],height=14};c.noFurniture=true end
  end
 end
 if underwater(def) then
  for _,c in pairs(cells)do
   local k=c.shape and c.shape.kind
   if k=='caveWall' and M.UNDERWATER_FILL[c.mid] and not (c.prop or c.stairs or c.object or c.objectTop) then
    c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};c.noFurniture=true
   end
  end
 end
end
return M
