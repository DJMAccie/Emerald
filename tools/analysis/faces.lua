package.path="./?.lua;./?/init.lua;"..package.path
local MOD=os.getenv('HOME')..'/Documents/battle-art-notquiteog'
local GV=require('src.core.GameVersion'); pcall(GV.set,'emerald')
local cache={}
V={mod={options={get=function()end}},data=function(n)return dofile(MOD..'/data/'..n..'.lua')end}
function V.require(n) if cache[n]==nil then cache[n]=assert(loadfile(MOD..'/lib/'..n..'.lua'))(V) or true end return cache[n] end
local Shapes=V.require('Gen3TileShape')
local Levels=V.require('TerrainLevels')
local W=dofile(os.getenv('HOME')..'/Documents/gen1recomp-modwork/world.lua')
local want={} for _,a in ipairs(arg) do want[a]=true end
for _,m in ipairs(W.maps) do if want[m.id] then
 local prim,sec=m.pair:match('^(.-)__(.+)$');local beh=W.behaviors[m.pair] or {}
 local function raw(x,y) local v=m.cells[y*m.w+x+1];return {mid=v%1024,coll=math.floor(v/1024)%4~=0 and 7 or 0,elev=math.floor(v/4096)} end
 local f=Levels.build(m.w,m.h,function(x,y) local r=raw(x,y);local b=beh[r.mid];local step=b==0x2A or b==0x1D0;local jump=b and b>=0x38 and b<=0x3F
  local s=Shapes.of(prim,sec,r.mid,b,r.coll) or {kind='flat'}
  return {floor=r.coll~=7 and not step and not jump,step=step,layer=r.elev,kind=s.kind,solid=(s.kind=='cliff')} end,
  function(a,b) return (a.layer==b.layer or a.layer==0 or b.layer==0 or a.layer==15 or b.layer==15) and (a.kind=='water')==(b.kind=='water') end,6)
 local same,diff,bands=0,0,{}
 for x=0,m.w-1 do local y=0 while y<m.h do
  local c=f.cells[x..':'..y]
  if c.solid then local top=y while y<m.h and f.cells[x..':'..y].solid do y=y+1 end
   local A=f.cells[x..':'..(top-1)];local B=f.cells[x..':'..y]
   if A and B and A.group and B.group then if A.group==B.group then same=same+1 else diff=diff+1 end end
  else y=y+1 end
 end end
 local hs={} for _,g in ipairs(f.groups) do hs[g.height or -1]=(hs[g.height or -1] or 0)+#g.cells end
 local t={} for h,n in pairs(hs) do t[#t+1]=h..':'..n end table.sort(t)
 print(m.id,'groups',#f.groups,'face columns: same-group',same,'different',diff,'heights',table.concat(t,' '))
end end
