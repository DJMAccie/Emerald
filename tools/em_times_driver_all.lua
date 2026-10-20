-- POKEPORT_DRIVER: time from Map.load to the player's cell built in 3D, for every map in EM_MAPS
-- ("MAP x y" lines). Prints [EM t] map frames ms. Level from EM_LEVEL (default 4).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(200)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=ex.lib.require('Gen3Scene');local C=(ex.gen3 or ex.firered).camera
 local Map=require('src.core.game3.map')
 local level=tonumber(os.getenv('EM_LEVEL') or '4')
 local maps={}
 for l in io.lines(os.getenv('EM_MAPS'))do local m,x,y=l:match('(%S+)%s+(%d+)%s+(%d+)');if m then maps[#maps+1]={m,tonumber(x),tonumber(y)} end end
 for _,m in ipairs(maps)do
  local t0=love.timer.getTime()
  local ok=pcall(Map.load,nil,game,m[1],{x=m[2],y=m[3],facing='down'})
  C.setLevel(level,game)
  local n=0
  repeat U.wait(1);n=n+1 until (C.active and Scene.debugRaw(m[2],m[3])) or n>900
  local ms=(love.timer.getTime()-t0)*1000
  print(string.format('[EM t]\t%s\t%d\t%.0f\t%s',m[1],n,ms,tostring(ok)))
  U.wait(10)
 end
 love.event.quit()
end
