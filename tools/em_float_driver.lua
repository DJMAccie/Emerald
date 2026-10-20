-- POKEPORT_DRIVER: floating-prop audit. Sets Gen3Rock.audit=true, enters each EM_MAPS map ("MAP x y" lines),
-- builds it at level 4 and prints [RK1 float] lines (from Gen3Rock.checkFloat) plus one [EM float] count line
-- per map: masses audited and floats found. QA only. Used by tools/release_check.sh (gate "floats").
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(200)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=ex.lib.require('Gen3Scene');local C=(ex.gen3 or ex.firered).camera
 local Rock=ex.lib.require('Gen3Rock')
 local Map=require('src.core.game3.map')
 Rock.audit=true
 local maps={}
 for l in io.lines(os.getenv('EM_MAPS'))do local m,x,y=l:match('(%S+)%s+(%d+)%s+(%d+)');if m then maps[#maps+1]={m,tonumber(x),tonumber(y)} end end
 for _,m in ipairs(maps)do
  local n0=Rock.auditN or 0
  local ok=pcall(Map.load,nil,game,m[1],{x=m[2],y=m[3],facing='down'})
  C.setLevel(4,game)
  local n=0
  repeat U.wait(1);n=n+1 until (C.active and Scene.debugRaw(m[2],m[3])) or n>900
  U.wait(tonumber(os.getenv('EM_FLOAT_WAIT') or 120))   -- the full build follows the near one
  print(string.format('[EM float]\t%s\t%d\t%s',m[1],(Rock.auditN or 0)-n0,tostring(ok)))
 end
 love.event.quit()
end
