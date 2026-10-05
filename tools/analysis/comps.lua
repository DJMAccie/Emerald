-- dump ALL components (any size) of blocked unknown cells on outdoor maps, after current shape rules
package.path="./?.lua;./?/init.lua;"..package.path
local MOD=os.getenv('HOME')..'/Documents/battle-art-notquiteog'
local GV=require('src.core.GameVersion'); pcall(GV.set,'emerald')
local cache={}
V={mod={options={get=function()end}},data=function(n)return dofile(MOD..'/data/'..n..'.lua')end}
function V.require(n) if cache[n]==nil then cache[n]=assert(loadfile(MOD..'/lib/'..n..'.lua'))(V) or true end return cache[n] end
local Shapes=V.require('Gen3TileShape')
local W=dofile(os.getenv('HOME')..'/Documents/gen1recomp-modwork/world.lua')
local out={}
for _,m in ipairs(W.maps)do local prim,sec=m.pair:match('^(.-)__(.+)$')
 if prim=='general' and (m.type==1 or m.type==2 or m.type==3 or m.type==6) then
  local beh=W.behaviors[m.pair] or {}
  local U={}
  local K={}
  for y=0,m.h-1 do for x=0,m.w-1 do local v=m.cells[y*m.w+x+1];local mid=v%1024;local b=math.floor(v/1024)%4~=0
   local s=Shapes.of(prim,sec,mid,beh[mid],b and 7 or 0); K[y*m.w+x]=s and s.kind or 'flat'
   if b and (not s or (s.kind=='flat' and not s.reviewedSurface)) then U[y*m.w+x]=mid end end end
  local seen={}
  for k in pairs(U)do if not seen[k] then local st,l={k},{};seen[k]=true
   local cliffAdj=false;local building=false
   while #st>0 do local c=table.remove(st);l[#l+1]=c;local x,y=c%m.w,math.floor(c/m.w)
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=x+d[1],y+d[2]
     if nx>=0 and ny>=0 and nx<m.w and ny<m.h then local n=ny*m.w+nx
      if U[n] and not seen[n] then seen[n]=true;st[#st+1]=n end
      if K[n]=='cliff' then cliffAdj=true end
      local bb=beh[m.cells[n+1]%1024] if bb==0x69 or bb==0x60 then building=true end end end
    if beh[U[c]]==0x69 or beh[U[c]]==0x60 then building=true end end
   local cl={} for _,c in ipairs(l)do cl[#cl+1]=string.format('[%d,%d,%d]',c%m.w,math.floor(c/m.w),U[c])end
   out[#out+1]=string.format('{"map":"%s","pair":"%s","cliff":%s,"building":%s,"cells":[%s]}',m.id,m.pair,tostring(cliffAdj),tostring(building),table.concat(cl,','))
  end end
 end end
io.write('['..table.concat(out,',\n')..']')
