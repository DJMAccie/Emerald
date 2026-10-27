return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local E=lib.require('Gen3Elevation');local Levels=lib.require('TerrainLevels')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 Map.load(nil,game,'EM_ROUTE121',{x=5,y=5,facing='down'});U.wait(120)
 local def=Map.currentDef();local fld=E.field(def);local l=def.midLayout
 for y=0,6 do for x=0,7 do
  local c=fld.cells[Levels.key(x,y)];local n=l:cellAt(x,y)
  f:write(('%d %d mid=%03X coll=%s floor=%s cls=%s h=%s pin=%s loose=%s srcMax=%s\n'):format(x,y,n.mid,tostring(n.coll),tostring(c.floor),tostring(c.cls),tostring(c.height),tostring(c.pin),tostring(c.treeLoose),tostring(c.srcMax)))
 end end
 f:close();love.event.quit()
end
