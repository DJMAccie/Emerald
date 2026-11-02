-- Emerald buildings as pixel voxels
local V=...
local Budget=V.require('BuildBudget')
local M={}

M.enabled=false
M.RISE_EVERY=2 -- roof art rows per voxel of rise

local function key(x,y)return x..':'..y end
local function origin(ts,mid)
 local slot=ts.midToSlot[mid];if not slot then return end
 return slot%ts.cols*16,math.floor(slot/ts.cols)*16
end
local function pixel(ts,x,y)
 local r,g,b,a=ts.imageData:getPixel(x,y)
 if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(x,y)
  if aa>0 then r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),math.max(a,aa) end
 end
 return r,g,b,a
end

local function strip(cells,c,ts,rows,grounds)
 local refs={}
 for _,g in ipairs(grounds)do local gx,gy=origin(ts,g);if gx then refs[#refs+1]={gx,gy}end end
 local out={}
 for i,row in ipairs(rows)do
  local cell=cells[key(c.cx,row)]
  local mid=cell and (cell.roofMid or cell.mid)
  local ox,oy=origin(ts,mid or -1)
  local overOnly=cell and (cell.collision or 0)==0 and ts.overImageData and not cell.roofMid
  if overOnly then
   local n=0
   if ox then for py=0,15,3 do for px=0,15,3 do local _,_,_,a=ts.overImageData:getPixel(ox+px,oy+py);if a>.5 then n=n+1 end end end end
   overOnly=n>=2
  end
  local walkGround=cell and (cell.collision or 0)==0 and not overOnly and not cell.roofMid
  for py=0,15 do
   local line={}
   for px=0,15 do
    local t=false
    if ox then
     local r,g,b,a=pixel(ts,ox+px,oy+py)
     local isGround=a<.5 or walkGround
     if overOnly then local _,_,_,oa=ts.overImageData:getPixel(ox+px,oy+py);isGround=oa<.5 end
     if not isGround and not overOnly then
      for _,ref in ipairs(refs)do
       local R,G,B=pixel(ts,ref[1]+px,ref[2]+py)
       if math.abs(r-R)<.002 and math.abs(g-G)<.002 and math.abs(b-B)<.002 then isGround=true;break end
      end
     end
     if not isGround then t={(ox+px+.5)/(ts.cols*16),(oy+py+.5)/(ts.rows*16)} end
    end
    line[px]=t
   end
   out[(i-1)*16+py]=line
  end
 end
 return out
end

local function greedy(grid,nu,nv,emit)
 for v=0,nv-1 do for u=0,nu-1 do
  local id=grid[v*nu+u]
  if id then
   local w,h=1,1
   while u+w<nu and grid[v*nu+u+w]==id do w=w+1 end
   while v+h<nv do
    local whole=true
    for k=0,w-1 do if grid[(v+h)*nu+u+k]~=id then whole=false;break end end
    if not whole then break end;h=h+1
   end
   for a=0,h-1 do for b=0,w-1 do grid[(v+a)*nu+u+b]=nil end end
   emit(u,v,w,h,id)
  end
 end end
end

function M.append(cells,c,emit)
 local column,ts=c.column,c.ts
 if not (ts and ts.imageData) then return false end
 local first,last=column.first,column.last
 local wallTop=column.wallTop or (first+column.roofs)
 local roofRows,wallRows={}, {}
 for y=first,last do if y<wallTop then roofRows[#roofRows+1]=y else wallRows[#wallRows+1]=y end end
 local grounds={c.shape.ground or 1}
 for dx=-1,1 do
  local n=cells[key(c.cx+dx,last+1)]
  if n and n.ts==ts and (n.collision or 0)==0 and not n.column then grounds[#grounds+1]=n.mid end
 end
 local roof=strip(cells,c,ts,roofRows,grounds)
 local wall=strip(cells,c,ts,wallRows,grounds)
 if #roofRows>=2 then
  local function colour(t)
   local r,g,b=pixel(ts,math.floor(t[1]*ts.cols*16),math.floor(t[2]*ts.rows*16))
   return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
  end
  local palette={}
  for py=16,#roofRows*16-1 do local line=roof[py];for px=0,15 do local t=line and line[px];if t then palette[colour(t)]=true end end end
  for _,dx in ipairs({-1,1})do
   local n=cells[key(c.cx+dx,first+1)]
   if n and n.column and n.ts==ts then
    local ox,oy=origin(ts,n.mid)
    if ox then for py=0,15 do for px=0,15 do
     local r,g,b=pixel(ts,ox+px,oy+py)
     palette[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)]=true
    end end end
   end
  end
  for py=0,15 do local line=roof[py];if line then for px=0,15 do
   local t=line[px];if t and not palette[colour(t)] then line[px]=false end
  end end end
 end
 local R,Hw=#roofRows*16,#wallRows*16
 if Hw==0 then Hw=16 end
 local D=(last-first+1)*16 -- footprint depth, back to front
 local x0,z0=c.cx*16,first*16
 local left=not (cells[key(c.cx-1,first)] and cells[key(c.cx-1,first)].column)
 local right=not (cells[key(c.cx+1,first)] and cells[key(c.cx+1,first)].column)
 local function material(rows,y)
  local row=rows[y];if not row then return nil end
  if row.mode~=nil then return row.mode or nil end
  local n,best,bn={},nil,0
  local any
  for px=0,15 do local t=row[px];if t then
   any=any or t
   local r,g,b=pixel(ts,math.floor(t[1]*ts.cols*16),math.floor(t[2]*ts.rows*16))
   if .3*r+.59*g+.11*b>.28 then -- outlines and window glass are not the material
    local k=t[1]..','..t[2];n[k]=(n[k] or 0)+1;if n[k]>bn then best,bn=t,n[k] end
   end
  end end
  best=best or any
  row.mode=best or false;return best
 end
 local texels,ids={}, {}
 local function id(t)
  if not t then return nil end
  local k=t[1]..','..t[2]
  local n=ids[k];if not n then n=#texels+1;texels[n]=t;ids[k]=n end
  return n
 end
 local function zr(r)return math.floor(r*(D-1)/math.max(R,1))end
 local rise=function(r)return math.floor((R-1-r)/M.RISE_EVERY)end
 local H=Hw+(R>0 and rise(0) or 0)+1
 local occ={}
 local function set(x,y,z,t)if t then occ[(y*D+z)*16+x]=t end end
 for x=0,15 do
  for r=0,R-1 do
   local px=roof[r] and roof[r][x]
   if px then
    local top=Hw+rise(r)
    for z=zr(r),math.max(zr(r),zr(r+1)-1) do
     for y=0,top-1 do
      local fill
      if y<Hw then
       local row=wall[Hw-1-y]
       local sx=x
       if left and x<2 then sx=2 elseif right and x>13 then sx=13 end
       fill=(row and row[sx]) or material(wall,Hw-1-y)
      else fill=material(roof,r) end
      set(x,y,z,id(fill or px))
     end
     set(x,top,z,id(px))
    end
   end
   Budget.tick()
  end
  for ry=0,Hw-1 do
   local row=wall[ry];local px=row and row[x]
   if px then set(x,Hw-1-ry,D-1,id(px)) end
  end
 end
 local function at(x,y,z)
  if x<0 or x>15 or y<0 or z<0 or z>=D then return nil end
  return occ[(y*D+z)*16+x]
 end
 local count=0
 local function quad(p,t,shade)
  local uv=texels[t];local q={{uv[1],uv[2]},{uv[1],uv[2]},{uv[1],uv[2]},{uv[1],uv[2]}}
  emit(p,q,shade);count=count+1
 end
 for y=0,H do
  local grid={}
  for z=0,D-1 do for x=0,15 do local t=at(x,y,z);if t and not at(x,y+1,z) then grid[z*16+x]=t end end end
  greedy(grid,16,D,function(u,v,w,h,t)
   quad({{x0+u,y+1,z0+v},{x0+u+w,y+1,z0+v},{x0+u+w,y+1,z0+v+h},{x0+u,y+1,z0+v+h}},t,1)
  end)
  Budget.tick()
 end
 for z=0,D-1 do
  local grid={}
  for y=0,H do for x=0,15 do local t=at(x,y,z);if t and not at(x,y,z+1) then grid[(H-y)*16+x]=t end end end
  greedy(grid,16,H+1,function(u,v,w,h,t)
   local yt=H-v+1;local yb=yt-h
   quad({{x0+u,yt,z0+z+1},{x0+u+w,yt,z0+z+1},{x0+u+w,yb,z0+z+1},{x0+u,yb,z0+z+1}},t,z==D-1 and .9 or .95)
  end)
  Budget.tick()
 end
 for z=0,D-1 do
  local grid={}
  for y=0,H do for x=0,15 do local t=at(x,y,z);if t and not at(x,y,z-1) then grid[(H-y)*16+x]=t end end end
  greedy(grid,16,H+1,function(u,v,w,h,t)
   local yt=H-v+1;local yb=yt-h
   quad({{x0+u+w,yt,z0+z},{x0+u,yt,z0+z},{x0+u,yb,z0+z},{x0+u+w,yb,z0+z}},t,.7)
  end)
 end
 for x=0,15 do
  for _,dx in ipairs({-1,1})do
   local grid={}
   for y=0,H do for z=0,D-1 do
    local t=at(x,y,z)
    local n=x+dx
    local open=(n<0 or n>15) and ((dx<0 and left) or (dx>0 and right)) or (n>=0 and n<=15 and not at(n,y,z))
    if t and open then grid[(H-y)*D+z]=t end
   end end
   greedy(grid,D,H+1,function(u,v,w,h,t)
    local yt=H-v+1;local yb=yt-h;local sx=x0+x+(dx>0 and 1 or 0)
    if dx<0 then quad({{sx,yt,z0+u},{sx,yt,z0+u+w},{sx,yb,z0+u+w},{sx,yb,z0+u}},t,.78)
    else quad({{sx,yt,z0+u+w},{sx,yt,z0+u},{sx,yb,z0+u},{sx,yb,z0+u+w}},t,.84) end
   end)
  end
  Budget.tick()
 end
 return count
end

return M
