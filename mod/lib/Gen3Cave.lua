-- Cave masses and boulders use their native palette and silhouette
local V=...
local M={}
local function boulderMask(mask)
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
 local minX,minY,maxX,maxY=16,16,-1,-1
 for y=0,15 do for x=0,15 do
  if mask[y*16+x]then
   if x<minX then minX=x end;if x+1>maxX then maxX=x+1 end
   if y<minY then minY=y end;if y+1>maxY then maxY=y+1 end
  end
 end end
 if maxX<minX or maxY<minY then return end
 local hw,hh=maxX-minX,maxY-minY
 local bottom=15-maxY
 local H=V.require('VoxelHull')
 local sample=function(x,y)
  local sx,sy=minX+x,minY+y
  local r,g,b,a=c.ts.imageData:getPixel(px+sx,py+sy)
  local uvx,uvy=unpack(tex(sx+.5,sy+.5))
  return r,g,b,mask[sy*16+sx]and a or 0,uvx,uvy
 end
 local card=V.require('TreePresentation').props:get()=='cards'
 local hull=card and H.card(hw,hh,sample,bottom,c.shape.height or 16)
  or H.build(hw,hh,sample,1,bottom,nil,'rock')
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
M.UNDERWATER_FILL={[0x213]=true}
local function underwater(def)
 return tonumber(def and def.mapType)==5 and tostring(def.id or ''):find('^EM_UNDERWATER') and true or false
end
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
M.PIT={general__pacifidlog={[0x238]=1,[0x239]=1,[0x23A]=1,[0x240]=1,[0x241]=1,[0x242]=1,[0x248]=1,[0x249]=1,[0x24A]=1,[0x24B]=1,[0x24D]=1}}
M.BOULDER={general__pacifidlog={[0x207]=1,[0x20F]=1,[0x217]=1,[0x21F]=1}}
M.CAP={general__pacifidlog={[0x23C]=1}}
M.BOULDER_FLOOR={general__pacifidlog={[0x207]=0x235,[0x20F]=0x234,[0x217]=0x234,[0x21F]=0x234}}
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
 for _,c in pairs(cells)do
  local cap=M.CAP[c.pair]
  if cap and cap[c.mid] and c.shape and c.shape.kind=='caveWall' and c.collision==7 and not (c.prop or c.stairs or c.object or c.objectTop) then
   c.shape={kind='cliff',cap=c.mid,side=c.mid,ground=1,height=32}
  end
 end
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
  if (k=='caveWall' or k=='cliff' or k=='flat') and c.collision==7 and not (c.prop or c.stairs or c.object or c.objectTop) then
   local pit,boulder=M.PIT[c.pair],M.BOULDER[c.pair]
   if pit and pit[c.mid] then c.shape={kind='flat',ground=c.shape.ground,reviewedSurface=true};c.noFurniture=true
   elseif boulder and boulder[c.mid] then c.shape={kind='rock',ground=M.BOULDER_FLOOR[c.pair][c.mid],floorTile=M.BOULDER_FLOOR[c.pair][c.mid],height=14};c.noFurniture=true
    c.collision=43 end
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
