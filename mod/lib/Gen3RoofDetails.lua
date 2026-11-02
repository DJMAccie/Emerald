-- Building-specific roof treatment
local M={}
M.LOW_RIDGE={{0,4},{.22,10},{1,0}}
M.TWO_TIER={{0,12},{.125,20},{.71,12},{.855,3},{1,0}}
local baked={}
function M.sideVisible(cells,c,dx)
 local n=cells[(c.cx+dx)..':'..c.cy]
 local a,b=c.column,n and n.column
 if not b or n.pair~=c.pair then return true end
 if a.groupId then
  if a.groupId~=b.groupId then return true end
  return (a.roofs==0)~=(b.roofs==0) or (a.roofs==0 and a.first~=b.first)
 end
 for _,field in ipairs({'height','front','back','roofType','roofInset','roofs'})do
  if a[field]~=b[field] then return true end
 end
 return false
end
M.RIDGE_AT=.2
M.PITCH=.5 -- rise per unit of front-slope run
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
  local ridge,rise=M.ridge(column)
  if z<=ridge then return column.height+rise*math.max(0,(z-column.back)/(ridge-column.back)) end
  return column.height+rise*math.max(0,(column.front-z)/(column.front-ridge))
 end
 if column.roofType=='lowRidge' then
  local knots=M.LOW_RIDGE
  t=math.max(0,math.min(1,t))
  for k=2,#knots do
   local a,b=knots[k-1],knots[k]
   if t<=b[1] then return column.height+a[2]+(b[2]-a[2])*(t-a[1])/(b[1]-a[1]) end
  end
  return column.height
 end
 if column.roofType=='twoTier' then
  local knots=M.TWO_TIER
  t=math.max(0,math.min(1,t))
  for k=2,#knots do
   local a,b=knots[k-1],knots[k]
   if t<=b[1] then return column.height+a[2]+(b[2]-a[2])*(t-a[1])/(b[1]-a[1]) end
  end
  return column.height
 end
 return column.height+13*(1-math.abs(2*t-1))
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
    if mid<0x280 and g>r+.035 and g>b+.02 then a=0 end
    px[y][x]={r,g,b,a}
   end end
   do
    local counts,best,n={},nil,0
    for y=0,15 do for x=0,15 do local q=px[y][x]
     if q[4]>.5 and .3*q[1]+.59*q[2]+.11*q[3]>.3 then
      local k=math.floor(q[1]*255+.5)*65536+math.floor(q[2]*255+.5)*256+math.floor(q[3]*255+.5)
      counts[k]=(counts[k] or 0)+1
      if counts[k]>n then best,n=q,counts[k] end
     end
    end end
    if best then
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
function M.release()
 for _,p in pairs(baked)do p.image:release()end;baked={}
end
return M
