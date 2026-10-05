-- Offline classifier: load the mod's Emerald shape tables under luajit (no
-- game) and report what every cell of every outdoor map resolves to.
--   cd ~/Documents/gen1recomp && luajit ~/Documents/gen1recomp-modwork/tools/shape_audit.lua
package.path="./?.lua;./?/init.lua;"..package.path
local MOD=os.getenv('HOME')..'/Documents/battle-art-notquiteog'
local WORK=os.getenv('HOME')..'/Documents/gen1recomp-modwork'
local GV=require('src.core.GameVersion')
if GV.set then pcall(GV.set,'emerald') end
local cache={}
local V={mod={options={get=function()return nil end}},data=function(n)return dofile(MOD..'/data/'..n..'.lua')end}
function V.require(name)
 if cache[name]==nil then
  local f=assert(loadfile(MOD..'/lib/'..name..'.lua'))
  cache[name]=f(V) or true
 end
 return cache[name]
end
local ok,Shapes=pcall(V.require,'Gen3TileShape')
if not ok then print('LOAD FAILED: '..tostring(Shapes)) os.exit(1) end
print('version',GV.get and GV.get(),'gen3?',V.require('Generation').isGen3())
local probe=Shapes.of('general','petalburg',0x1DC,nil,7)
print('probe tree root ->',probe and probe.kind)
_G.SHAPES=Shapes
local W=dofile(WORK..'/world.lua')
local B=W.behaviors
local SURF={}
local function kindOf(prim,sec,mid,beh,blk) local s=Shapes.of(prim,sec,mid,beh,blk and 7 or 0);return s and s.kind or 'flat',s end
local flatBlocked,propWater,totals={}, {}, {}
local only=arg[1]
for _,m in ipairs(W.maps)do
 local prim,sec=m.pair:match('^(.-)__(.+)$')
 if prim=='general' and (not only or m.id==only) then
  local beh=B[m.pair] or {}
  local function at(x,y) if x<0 or y<0 or x>=m.w or y>=m.h then return nil end local v=m.cells[y*m.w+x+1];return v%1024,math.floor(v/1024)%4~=0 end
  for y=0,m.h-1 do for x=0,m.w-1 do
   local mid,blk=at(x,y)
   local kind,shape=kindOf(prim,sec,mid,beh[mid],blk)
   totals[kind]=(totals[kind] or 0)+1
   if blk and kind=='flat' then
    local k=sec..string.format(':%03X',mid)
    local e=flatBlocked[k] or {n=0,map=m.id,x=x,y=y};e.n=e.n+1;flatBlocked[k]=e
   end
   if shape and shape.ground and kind~='water' and kind~='roof' and kind~='wall' then
    local gk=kindOf(prim,sec,shape.ground,beh[shape.ground],false)
    if gk=='water' then
     local k=sec..':'..kind..string.format(':%03X ground %03X',mid,shape.ground)
     local e=propWater[k] or {n=0,map=m.id,x=x,y=y};e.n=e.n+1;propWater[k]=e
    end
   end
  end end
 end
end
local function dump(title,t,limit)
 local keys={};for k in pairs(t)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return t[a].n>t[b].n end)
 local total=0;for _,k in ipairs(keys)do total=total+t[k].n end
 print(('== %s: %d kinds, %d cells'):format(title,#keys,total))
 for i=1,math.min(limit,#keys)do local e=t[keys[i]];print(('  %-34s x%-5d e.g. %s %d,%d'):format(keys[i],e.n,e.map,e.x,e.y))end
end
local ks={};for k,v in pairs(totals)do ks[#ks+1]=k..'='..v end;table.sort(ks);print(table.concat(ks,' '))
dump('props whose ground tile is WATER',propWater,25)
dump('blocked cells left FLAT (unknown objects)',flatBlocked,40)
-- Outdoor maps after Gen3Objects: blocked cells still lying flat, split into
-- reviewed (mountain tops etc., flat on purpose) and unknown.
do
 local Objects=V.require('Gen3Objects')
 local rest,claimed,groups,reviewed={},0,0,0
 for _,m in ipairs(W.maps)do
  local prim,sec=m.pair:match('^(.-)__(.+)$')
  local outdoor=m.type==1 or m.type==2 or m.type==3 or m.type==6
  if prim=='general' and outdoor and (not only or m.id==only) then
   local beh=B[m.pair] or {}
   local cells={}
   for y=0,m.h-1 do for x=0,m.w-1 do
    local v=m.cells[y*m.w+x+1];local mid=v%1024;local coll=math.floor(v/1024)%4
    local s=Shapes.of(prim,sec,mid,beh[mid],coll~=0 and 7 or 0) or {kind='flat'}
    cells[x..':'..y]={cx=x,cy=y,mid=mid,collision=coll~=0 and 7 or 0,shape=s,pair=m.pair}
   end end
   groups=groups+#Objects.prepare(cells,true)
   for _,c in pairs(cells)do
    if c.object then claimed=claimed+1
    elseif c.collision~=0 and c.shape.kind=='flat' then
     if c.shape.reviewedSurface then reviewed=reviewed+1 else
      local k=sec..string.format(':%03X',c.mid)
      local e=rest[k] or {n=0,map=m.id,x=c.cx,y=c.cy};e.n=e.n+1;rest[k]=e
     end
    end
   end
  end
 end
 print(('== OUTDOOR: %d objects claim %d cells; %d blocked cells flat on purpose (reviewed)'):format(groups,claimed,reviewed))
 dump('OUTDOOR blocked cells still FLAT (unknown)',rest,30)
end
