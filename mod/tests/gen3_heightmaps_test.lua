local real=dofile('data/gen3_heightmaps.lua')
local function loader(data)
 local loaded={};local V={}
 function V.data(name)assert(name=='gen3_heightmaps');return data end
 function V.require(name)
  if not loaded[name] then loaded[name]=assert(loadfile('lib/'..name..'.lua'))(V) end
  return loaded[name]
 end
 return V,V.require('Gen3PinData')
end
local V,P=loader(real)
local count=0
for id,src in pairs(real)do
 local p=assert(P.MAPS[id],id);assert(p.cells and p.w==src[1] and p.h==src[2],id..' kept sparse pins')
 local i=0
 for token in src[3]:gmatch('%S+')do
  local k=(i%p.w)..':'..math.floor(i/p.w);i=i+1
  local height=tonumber(token)or tonumber(token:match('^o(.*)$'))
  if height then assert(p.cells[k]and math.abs(p[p.cells[k]][3]-height)<.00001,id..' floor changed');if token:sub(1,1)=='o'then assert(p.objects[k],id..' object lost')end
  elseif token:sub(1,1)=='w'then assert(p.waterfalls[k]and not p.arrows[k],id..' sloping waterfall')
  elseif token~='.'then assert(p.arrows[k],id..' missing arrow')end
 end
 assert(i==p.w*p.h,id..' size');count=count+1
end
local fixture={EM_ROUTE101={3,2,'5 o5 sE5:6\nwN0:8 NEo5:6 .'}}
local V2,P2=loader(fixture)
assert(P2.MAPS.EM_ROUTE101.cells['0:0'],'complete map lost to sparse pins')
assert(P2.MAPS.EM_ROUTE101.objects['1:0'],'prop ground became terrain')
assert(P2.MAPS.EM_ROUTE101.arrows['2:0'].stairs,'stairs lost their type')
assert(P2.MAPS.EM_ROUTE101.waterfalls['0:1'].hi==8)
assert(P2.MAPS.EM_ROUTE102==nil,'missing drawing should use generic terrain')
local badV,badP=loader({BAD={2,1,'0'}})
assert(not pcall(function()return badP.MAPS.BAD end),'truncated map accepted')
local badV2,badP2=loader({BAD={1,1,'garbage'}})
assert(not pcall(function()return badP2.MAPS.BAD end),'unknown token accepted')
package.loaded['src.core.game3.scripting.interaction_scripts']={behaviors={fixture={}}}
package.loaded['src.import.gba.versions']={TILESET_PAIRS={fixture={primary='general',secondary='test'}}}
local shapes={of=function()return{kind='flat'}end}
local E=assert(loadfile('lib/Gen3Elevation.lua'))({
 require=function(n)
  if n=='Gen3PinData'then return P2 end
  if n=='Gen3TileShape'then return shapes end
  if n=='BuildBudget'then return{tick=function()end}end
  return V2.require(n)
 end,
 data=V2.data,
})
local l={width=3,height=2,pair='fixture',cells={}}
function l:cellAt(x,y)if x>=0 and y>=0 and x<self.width and y<self.height then return{mid=1,elev=x==1 and 9 or 3,coll=0}end end
local def={id='EM_ROUTE101',midLayout=l,mapType=3}
local f=E.field(def)
assert(f.cells['0:0'].height==80 and f.cells['1:0'].height==80,'cartridge levels overwrote flat height')
assert(f.cells['0:1'].height==128 and f.cells['0:1'].waterfall,'waterfall not at upper pool')
assert(f.cells['2:0'].step and f.cells['2:0'].stairUp[1]==1,'stair direction lost')
assert(E.at(def,2*16+1,1)==84 and E.at(def,2*16+15,1)==96,'actor does not follow eastward stairs')
assert(not f.cells['2:1'].floor,'void became floor')
local B=assert(loadfile('lib/Gen3Blocks.lua'))({require=function(n)if n=='Gen3Elevation'then return E elseif n=='Gen3PinData'then return P2 else return V2.require(n)end end})
local prop={cx=1,cy=0,mid=1,shape={kind='cliff'},collision=7,base=80,floor=f.cells['1:0'],ts={midToSlot={[1]=0}}}
B.prepare({['1:0']=prop},{{x=0,y=0,w=3,h=2,def=def}},def)
assert(not prop.blocks,'prop was flattened into a terrain block')
prop.base=0;B.restoreHeights({prop});assert(prop.base==80,'legacy settling overrode source height')
l.width=5
assert(not pcall(E.field,def),'wrong map dimensions accepted')
print('PASS '..count..' full height maps, sparse priority, typed stairs/waterfalls, actor sampling and malformed-source guards')
