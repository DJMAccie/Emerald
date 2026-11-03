local V=...
local M={}
-- A map with a drawn height map: one pin per flat area, every floor cell set (cells), ramp arrows per cell (arrows).
local HM
local function heightmap(id)
 HM=HM or V.data('gen3_heightmaps')
 local src=HM[id];if not src then return nil end
 local W,hgt,order,arrows,falls,objects=src[1],{},{},{},{},{}
 local i=0
 for tok in src[3]:gmatch('%S+')do
  local k=(i%W)..':'..math.floor(i/W);i=i+1
  local object=tok:match('^o(%-?[%d.]+)$')
  local n=tonumber(object or tok)
  if object then objects[k]=true end
  if n then hgt[k]=n;order[#order+1]=k
  elseif tok~='.' then
   local tag,dir,kind,lo,hi=tok:match('^([sw]?)([NSEW][EW]?)([io]?)(%-?[%d.]+):(%-?[%d.]+)$')
   assert(dir,'Invalid height-map token in '..id..': '..tok)
   local a={dir=dir,inner=kind=='i',lo=tonumber(lo),hi=tonumber(hi),stairs=tag=='s'}
   assert(a.lo and a.hi and a.lo<=a.hi,'Invalid height-map edges in '..id..': '..tok)
   if tag=='w' then falls[k]=a;hgt[k]=a.hi;order[#order+1]=k else arrows[k]=a end
  end
 end
 assert(i==W*src[2],'Height-map size mismatch in '..id)
 local pins,cells={},{}
 for _,k in ipairs(order)do
  if not cells[k] then
   local h=hgt[k];local x,y=k:match('^(%d+):(%d+)$');x,y=tonumber(x),tonumber(y)
   pins[#pins+1]={x,y,h};local zi=#pins;cells[k]=zi
   local stack={{x,y}}
   while #stack>0 do
    local q=table.remove(stack)
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=q[1]+d[1],q[2]+d[2];local nk=nx..':'..ny
     if hgt[nk]==h and not cells[nk] then cells[nk]=zi;stack[#stack+1]={nx,ny} end
    end
   end
  end
 end
 pins.cells,pins.arrows,pins.waterfalls,pins.objects,pins.w,pins.h=cells,arrows,falls,objects,W,src[2]
 return pins
end
M.MAPS=setmetatable({},{__index=function(t,id)local p=heightmap(id);if p then rawset(t,id,p) end;return p end})
return M
