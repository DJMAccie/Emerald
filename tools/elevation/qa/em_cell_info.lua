-- POKEPORT_DRIVER: layout + field facts of single cells. EM_CELLS="MAP x y;MAP x y;..." EM_DUMP=<out.txt>  (QA identity only)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local E=lib.require('Gen3Elevation');local Levels=lib.require('TerrainLevels')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 local cur
 for spec in os.getenv('EM_CELLS'):gmatch('[^;]+')do
  local id,x,y=spec:match('(%S+)%s+(%-?%d+)%s+(%-?%d+)');x,y=tonumber(x),tonumber(y)
  if id~=cur then Map.load(nil,game,id,{x=5,y=5,facing='down'});U.wait(120);cur=id end
  local def=Map.currentDef();local l=def.midLayout
  local fld=E.field(def)
  local n=l:cellAt(x,y);local c=fld.cells[Levels.key(x,y)]
  f:write(string.format('%s %d %d mid=%03X coll=%s elev=%s | floor=%s step=%s kind=%s height=%s high=%s low=%s connector=%s zone=%s pin=%s cls=%s ledge=%s bare=%s ext=%s\n',id,x,y,n and n.mid or 0,tostring(n and n.coll),tostring(n and n.elev),
   tostring(c and c.floor),tostring(c and c.step),tostring(c and c.kind),tostring(c and c.height),tostring(c and c.high),tostring(c and c.low),tostring(c and c.connector),tostring(c and c.zone),tostring(c and c.pin),tostring(c and c.cls),tostring(c and c.ledge~=nil),tostring(c and c.bareDrop),tostring(c and c.stepExt)))
 end
 f:close();love.event.quit()
end
