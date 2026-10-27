-- POKEPORT_DRIVER: shape facts of single cells (kind, canopy, root, coll) and the field's height. EM_CELLS="MAP x y;..." EM_DUMP=<out>
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local E=lib.require('Gen3Elevation');local Levels=lib.require('TerrainLevels')
 local Shapes=lib.require('Gen3TileShape');local Pairs=lib.require('Gen3Tilesets');local Versions=require('src.import.gba.versions')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 local cur
 for spec in os.getenv('EM_CELLS'):gmatch('[^;]+')do
  local id,x,y=spec:match('(%S+)%s+(%-?%d+)%s+(%-?%d+)');x,y=tonumber(x),tonumber(y)
  if id~=cur then Map.load(nil,game,id,{x=5,y=5,facing='down'});U.wait(120);cur=id end
  local def=Map.currentDef();local L=def.midLayout
  local ts=Pairs.resolve(L.pair,Versions.TILESET_PAIRS)
  local n=L:cellAt(x,y);local sh=ts and Shapes.of(ts.primary,ts.secondary,n.mid)
  local c=E.field(def).cells[Levels.key(x,y)]
  f:write(('%s %d %d mid=%03X coll=%s kind=%s canopy=%s root=%s cls=%s h=%s\n'):format(id,x,y,n.mid,tostring(n.coll),tostring(sh and sh.kind),tostring(sh and sh.canopy),tostring(sh and sh.root),tostring(c and c.cls),tostring(c and c.height)))
 end
 f:close();love.event.quit()
end
