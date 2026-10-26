-- POKEPORT_DRIVER (QA only): final rock heights of a region of cave cells.
--   EM_MAPS=<file: "MAP x y x0 y0 x1 y1" lines> EM_DUMP=<out.txt>  EM_DUMP_WAIT=<frames, default 200>
-- per cell: x y MID kind coll base H (H = Gen3Rock mass height, '-' when the cell is not in a rock mass)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local C=(ex.gen3 or ex.firered).camera
 local Scene=ex.lib.require('Gen3Scene')
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y,x0,y0,x1,y1=line:match('^(%S+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});C.setLevel(7,game);U.wait(tonumber(os.getenv('EM_DUMP_WAIT') or '') or 200)
   f:write('MAP '..id..'\n')
   for cy=tonumber(y0),tonumber(y1) do for cx=tonumber(x0),tonumber(x1) do
    local r=Scene.debugRaw(cx,cy)
    if r then
     local H=r.mass and r.mass.rock and r.mass.rock.H and r.mass.rock.H[r] 
     f:write(('%d %d %03X %s %s %s %s\n'):format(cx,cy,r.mid or 0,tostring(r.shape and r.shape.kind),tostring(r.collision),tostring(r.base and math.floor(r.base+.5)),H and tostring(math.floor(H+.5)) or '-'))
    end
   end end
  end
  f:flush()
 end
 f:close();love.event.quit()
end
