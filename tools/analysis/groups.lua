-- small components of unknown blocked cells on outdoor maps, with neighbour ground and walk-behind tops
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
  local function info(x,y) if x<0 or y<0 or x>=m.w or y>=m.h then return end
   local v=m.cells[y*m.w+x+1];local mid=v%1024;local blk=math.floor(v/1024)%4~=0
   local s=Shapes.of(prim,sec,mid,beh[mid],blk and 7 or 0)
   return mid,blk,s and s.kind or 'flat',s and s.reviewedSurface end
  local U={}
  for y=0,m.h-1 do for x=0,m.w-1 do local mid,blk,k,rev=info(x,y) if blk and k=='flat' and not rev then U[y*m.w+x]=mid end end end
  local seen={}
  for k in pairs(U)do if not seen[k] then
   local stack,list={k},{};seen[k]=true
   local x0,y0,x1,y1=1e9,1e9,-1,-1
   while #stack>0 do local c=table.remove(stack);list[#list+1]=c
    local x,y=c%m.w,math.floor(c/m.w)
    x0,y0,x1,y1=math.min(x0,x),math.min(y0,y),math.max(x1,x),math.max(y1,y)
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=x+d[1],y+d[2]
     if nx>=0 and ny>=0 and nx<m.w and ny<m.h then local n=ny*m.w+nx
      if U[n] and not seen[n] then seen[n]=true;stack[#stack+1]=n end end end
   end
   if #list<=12 and x1-x0<4 and y1-y0<4 then
    -- neighbour ground: most common walkable flat neighbour mid
    local votes={}
    for _,c in ipairs(list)do local x,y=c%m.w,math.floor(c/m.w)
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local mid,blk,kk=info(x+d[1],y+d[2])
      if mid and not blk and (kk=='flat' or kk=='grass') then votes[mid]=(votes[mid] or 0)+1 end end end
    local g,best=nil,0 for mid,n in pairs(votes)do if n>best then g,best=mid,n end end
    local cl={} for _,c in ipairs(list)do cl[#cl+1]=string.format('[%d,%d,%d]',c%m.w,math.floor(c/m.w),U[c])end
    -- walk-behind row above
    local tops={}
    for x=x0,x1 do local mid,blk=info(x,y0-1) if mid and not blk and U[y0*m.w+x] then tops[#tops+1]=string.format('[%d,%d,%d]',x,y0-1,mid) end end
    out[#out+1]=string.format('{"map":"%s","pair":"%s","ground":%s,"cells":[%s],"tops":[%s],"key":"%s"}',m.id,m.pair,tostring(g or 'null'),table.concat(cl,','),table.concat(tops,','),
     (function()local ids={} for _,c in ipairs(list)do ids[#ids+1]=string.format('%03X',U[c])end table.sort(ids) return sec..':'..table.concat(ids,'+') end)())
   end
  end end
 end
end
io.write('['..table.concat(out,',\n')..']')
