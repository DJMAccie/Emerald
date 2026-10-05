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

-- Dump every (pair, metatile) resolved to a small-prop kind, or left blocked-flat
-- (the generic object cutter's input), with counts and one example cell.
--   cd ~/Documents/gen1recomp && luajit <this file> > props.tsv
local PROPS={cliff=1,caveWall=1,sign=1,fence=1,shrub=1,flowers=1,awning=1,ledge=1,grass=1,rock=1,tree=1,ladder=1,steps=1}
local rows={}
for _,m in ipairs(W.maps)do
 local prim,sec=m.pair:match('^(.-)__(.+)$')
 if prim=='general' then
  local beh=B[m.pair] or {}
  for y=0,m.h-1 do for x=0,m.w-1 do
   local v=m.cells[y*m.w+x+1];local mid,blk=v%1024,math.floor(v/1024)%4~=0
   local kind,shape=kindOf(prim,sec,mid,beh[mid],blk)
   local k
   if PROPS[kind] then k=kind elseif blk and kind=='flat' then k='OBJECT' end
   if k then
    local key=m.pair..'\t'..string.format('%03X',mid)..'\t'..k..'\t'..(blk and 'blocked' or 'walk')
    local e=rows[key] or {n=0,map=m.id,x=x,y=y};e.n=e.n+1;rows[key]=e
   end
  end end
 end
end
local keys={};for k in pairs(rows)do keys[#keys+1]=k end;table.sort(keys)
print('pair\tmid\tkind\tcollision\tcount\tmap\tx\ty')
for _,k in ipairs(keys)do local e=rows[k];print(k..'\t'..e.n..'\t'..e.map..'\t'..e.x..'\t'..e.y)end
