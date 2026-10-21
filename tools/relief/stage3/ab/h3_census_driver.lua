-- POKEPORT_DRIVER: H3 census. For every EM_MAPS map ("MAP x y" lines) that Gen3Relief.MAPS opts in: reset Gen3Relief.stats[map], load the
-- map at level 4, wait for the full build and print [EM h3stats] <map> lift clean wall (counts of z-fight lifts / clean-twin tiles / clean
-- wall faces; a rebuild counts again, so read them as "touched or not", not as exact cell counts). QA only.
-- Needs a tree whose Gen3Relief still has M.stats (tools/relief/stage3/probe_h3); the installed file has no counters.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(200)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=ex.lib.require('Gen3Scene');local C=(ex.gen3 or ex.firered).camera
 local Rel=ex.lib.require('Gen3Relief')
 local Map=require('src.core.game3.map')
 for l in io.lines(os.getenv('EM_MAPS'))do
  local m,x,y=l:match('(%S+)%s+(%d+)%s+(%d+)')
  if m and Rel.MAPS[m] then
   x,y=tonumber(x),tonumber(y)
   Rel.stats[m]=nil
   local ok=pcall(Map.load,nil,game,m,{x=x,y=y,facing='down'})
   C.setLevel(4,game)
   local n=0
   repeat U.wait(1);n=n+1 until (C.active and Scene.debugRaw(x,y)) or n>900
   U.wait(tonumber(os.getenv('EM_H3_WAIT') or 240))
   local s=Rel.stats[m] or {lift=0,clean=0,wall=0}
   print(string.format('[EM h3stats]\t%s\t%d\t%d\t%d\t%s',m,s.lift,s.clean,s.wall,tostring(ok)))
  end
 end
 love.event.quit()
end
