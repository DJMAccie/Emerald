-- a box per door for buildings the engine has no group for: flood the
-- blocked, non-tree, non-water cells above the door
package.path="./?.lua;./?/init.lua;"..package.path
local MOD=os.getenv('HOME')..'/Documents/battle-art-notquiteog'
local GV=require('src.core.GameVersion'); pcall(GV.set,'emerald')
local cache={}
V={mod={options={get=function()end}},data=function(n)return dofile(MOD..'/data/'..n..'.lua')end}
function V.require(n) if cache[n]==nil then cache[n]=assert(loadfile(MOD..'/lib/'..n..'.lua'))(V) or true end return cache[n] end
local Shapes=V.require('Gen3TileShape')
local W=dofile(os.getenv('HOME')..'/Documents/gen1recomp-modwork/world.lua')
local maps={} for _,m in ipairs(W.maps) do maps[m.id]=m end
local out={}
for line in io.lines(arg[1]) do
 local n,map,dx,dy,hw,up,fac=line:match('(%d+) (%S+) (%d+) (%d+) (%d+) (%d+) (%d+)')
 local m=maps[map]
 if m then dx,dy=tonumber(dx),tonumber(dy)
  local prim,sec=m.pair:match('^(.-)__(.+)$');local beh=W.behaviors[m.pair] or {}
  local function ok(x,y) if x<0 or y<0 or x>=m.w or y>=m.h or y>dy or math.abs(x-dx)>tonumber(hw) or dy-y>tonumber(up) then return false end
   local v=m.cells[y*m.w+x+1];local mid=v%1024;local b=math.floor(v/1024)%4~=0
   if not b and not (x==dx and y==dy) then return false end
   local s=Shapes.of(prim,sec,mid,beh[mid],b and 7 or 0);local k=s and s.kind or 'flat'
   return k~='tree' and k~='water' and k~='ledge' and k~='fence' and k~='cliff' end
  local seen,st={},{{dx,dy}} local x0,y0,x1,y1=dx,dy,dx,dy local n_=0
  while #st>0 and n_<400 do local p=table.remove(st) local k=p[1]..':'..p[2]
   if not seen[k] and ok(p[1],p[2]) then seen[k]=true n_=n_+1
    x0,y0,x1,y1=math.min(x0,p[1]),math.min(y0,p[2]),math.max(x1,p[1]),math.max(y1,p[2])
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do st[#st+1]={p[1]+d[1],p[2]+d[2]} end end end
  out[#out+1]=string.format('{"map":"%s","pair":"%s","box":[%d,%d,%d,%d],"wallTop":%d,"n":%s,"cells":%d}',map,m.pair,x0,y0,x1,y1,y1-tonumber(fac)+1,n,n_)
 end end
io.write('['..table.concat(out,',\n')..']')
