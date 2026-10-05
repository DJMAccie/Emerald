-- POKEPORT_DRIVER: print every cell's scene classification for given maps.
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>  (QA identity only)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity()=='pokemon-love2d-rseqa','refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Scene=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen3Scene')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120)
   local def=Map.currentDef();local W,H=def.midLayout.width,def.midLayout.height
   for cy=-3,H+2 do for cx=-4,W+3 do
    local c=Scene.debugCell(cx,cy)
    if c then f:write(('%s %d %d %03X %s coll=%s prop=%s col=%s base=%s\n'):format(id,cx,cy,c.mid or 0,tostring(c.kind),tostring(c.collision),tostring(c.prop),c.col and 'y' or '-',tostring(c.base)))end
   end end
  end
 end
 f:close();love.event.quit()
end
