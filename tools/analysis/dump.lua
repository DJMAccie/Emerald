-- dump per outdoor map: list of unknown blocked cells "x,y" -> json
package.path="./?.lua;./?/init.lua;"..package.path
local MOD=os.getenv('HOME')..'/Documents/battle-art-notquiteog'
local WORK=os.getenv('HOME')..'/Documents/gen1recomp-modwork'
local GV=require('src.core.GameVersion'); if GV.set then pcall(GV.set,'emerald') end
local cache={}
local V={mod={options={get=function()return nil end}},data=function(n)return dofile(MOD..'/data/'..n..'.lua')end}
function V.require(name) if cache[name]==nil then cache[name]=assert(loadfile(MOD..'/lib/'..name..'.lua'))(V) or true end return cache[name] end
local Shapes=V.require('Gen3TileShape')
local W=dofile(WORK..'/world.lua')
local out={}
for _,m in ipairs(W.maps)do
 local prim,sec=m.pair:match('^(.-)__(.+)$')
 if prim=='general' and (m.type==1 or m.type==2 or m.type==3 or m.type==6) then
  local beh=W.behaviors[m.pair] or {}
  local list={}
  for y=0,m.h-1 do for x=0,m.w-1 do
   local v=m.cells[y*m.w+x+1];local mid=v%1024;local blk=math.floor(v/1024)%4~=0
   local s=Shapes.of(prim,sec,mid,beh[mid],blk and 7 or 0)
   local k=s and s.kind or 'flat'
   local tag
   if blk and k=='flat' then tag=(s and s.reviewedSurface) and 'r' or 'u' end
   if k~='flat' then tag=k:sub(1,2) end
   if tag then list[#list+1]=string.format('[%d,%d,"%s"]',x,y,tag) end
  end end
  out[#out+1]=string.format('"%s":{"pair":"%s","w":%d,"h":%d,"cells":[%s]}',m.id,m.pair,m.w,m.h,table.concat(list,','))
 end
end
io.write('{'..table.concat(out,',')..'}')
