-- POKEPORT_DRIVER: for every map in EM_MAPS ("MAP x y" lines), print the layout pair and the primary/secondary tileset
-- names the installed look resolves it to, plus map type. QA identity only. EM_DUMP=<out>.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local Pairs=lib.require('Gen3Tilesets')
 local Versions=require('src.import.gba.versions')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 f:write('# map\tmapType\tpair\tprimary\tsecondary\n')
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   local ok=pcall(function() assert(Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'})) end)
   local def=ok and Map.currentDef()
   if def and tonumber(def.mapType)==8 then
    local pair=def.midLayout and def.midLayout.pair
    local ok2,spec=pcall(Pairs.resolve,pair,Versions.TILESET_PAIRS)
    spec=ok2 and spec or {}
    f:write(('%s\t%s\t%s\t%s\t%s\n'):format(id,tostring(def.mapType),tostring(pair),tostring(spec.primary),tostring(spec.secondary)))
   end
   U.wait(3)
  end
 end
 f:close();love.event.quit()
end
