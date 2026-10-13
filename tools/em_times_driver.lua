-- POKEPORT_DRIVER: build time per stage, per shape kind and per standing-object type on map entry.
-- Prints [EM times], [EM kind], [EM obj]. Edit the map list below.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(200)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=ex.lib.require('Gen3Scene');local C=(ex.gen3 or ex.firered).camera
 local Map=require('src.core.game3.map')
 for _,m in ipairs({{'EM_RUSTBORO_CITY',25,39}})do
  local b0=Scene.streaming.buildMs or 0
  Scene.streaming.kinds={};local O=ex.lib.require('Gen3Objects');O.prof={}
  Map.load(nil,game,m[1],{x=m[2],y=m[3],facing='down'});C.setLevel(4,game)
  local n=0
  repeat U.wait(1);n=n+1 until (C.active and Scene.debugRaw(m[2],m[3])) or n>600
  local r=Scene.debugTimes and Scene.debugTimes() or {}
  print('[EM times]',m[1],'frames',n,'start',math.floor(b0),'end',math.floor(Scene.streaming.buildMs or 0),table.concat(r,' | '))
  local t={};for k,e in pairs(Scene.streaming.kinds)do t[#t+1]={k,e[1],e[2]} end;table.sort(t,function(a,b)return a[2]>b[2] end)
  for i=1,math.min(14,#t)do print('[EM kind]',t[i][1],string.format('%.0f ms',t[i][2]*1000),t[i][3]) end
  for k,e in pairs(O.prof)do print('[EM obj]',k,string.format('%.0f ms',e[1]*1000),e[2],e[3]) end
  U.wait(40)
  r=Scene.debugTimes and Scene.debugTimes() or {}
  print('[EM times] full',m[1],'end',math.floor(Scene.streaming.buildMs or 0),table.concat(r,' | '))
 end
 love.event.quit()
end
