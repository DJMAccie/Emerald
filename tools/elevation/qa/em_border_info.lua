-- POKEPORT_DRIVER: a map's border block (borderMids + shape kinds) and the kind/class of its edge cells. EM_MAPS=<file "MAP x y"> EM_DUMP=<out>
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
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120)
   local def=Map.currentDef();local L=def.midLayout
   local spec=Pairs.resolve(L.pair,Versions.TILESET_PAIRS)
   f:write(('MAP %s pair=%s primary=%s secondary=%s size=%dx%d\n'):format(id,tostring(L.pair),tostring(spec and spec.primary),tostring(spec and spec.secondary),L.width,L.height))
   for i,mid in ipairs(L.borderMids or {})do
    local sh=spec and Shapes.of(spec.primary,spec.secondary,mid)
    f:write(('BORDER %s %d mid=%03X kind=%s\n'):format(id,i,mid,tostring(sh and sh.kind)))
   end
   local fld=E.field(def)
   for _,edge in ipairs({{'W',0},{'E',L.width-1}})do
    for yy=0,L.height-1 do local xx=edge[2];local n=L:cellAt(xx,yy);local c=fld.cells[Levels.key(xx,yy)]
     local sh=spec and Shapes.of(spec.primary,spec.secondary,n.mid)
     f:write(('EDGE %s %s %d %d mid=%03X coll=%s kind=%s cls=%s h=%s\n'):format(id,edge[1],xx,yy,n.mid,tostring(n.coll),tostring(sh and sh.kind),tostring(c and c.cls),tostring(c and c.height)))
    end
   end
  end
 end
 f:close();love.event.quit()
end
