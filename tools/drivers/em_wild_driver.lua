-- QA driver: walk back and forth in Route 102's grass and report overworld wild spawns (overworld_wild_spawns).
--   EM_DRIVER=<this file> tools/qa_tryp.sh "Gen3Scene.lua" <abs out> "-" 4 0 200
-- Prints [wild] lines: the spawn snapshot after every 8 steps, then one shot.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local C=(function()local e=game.mods.exports.BATTLE_ART_VOXEL_FORK;local n=e and (e.gen3 or e.firered);return n and n.camera end)()
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 do local Party=require('src.core.game3.party');local Pk=require('src.core.game3.pokemon');local c=Party.giveMonToPlayer(game.session,Pk.speciesFromNational(276) or 276,30);print('[wild] gave party mon',c) end
 assert(Map.load(nil,game,'EM_ROUTE102',{x=20,y=10,facing='down'}))
 pcall(Player.reset,20,10,'down')
 if C then C.setLevel(4,game) end
 U.wait(150)
 local names={} for k in pairs(game.mods.exports) do names[#names+1]=k end table.sort(names) print('[wild] mods',table.concat(names,','))
 local ex=game.mods.exports.overworld_wild_spawns
 print('[wild] export',ex and 'yes' or 'NO')
 local function snap(tag)
  local ok,s=pcall(ex.spawnSystemState)
  local n=0
  if ok and type(s)=='table' then
   local list=s.spawns or s.list or s.active or s
   for _ in pairs(list) do n=n+1 end
   print('[wild]',tag,'entries',n,'keys',(function()local k={} for key in pairs(s) do k[#k+1]=tostring(key) end return table.concat(k,',')end)())
  else print('[wild]',tag,'snapshot failed',tostring(s)) end
 end
 if not ex then print('[EM QA] done') love.event.quit() return end
 local S=ex.gen3
 local function count()local n=0 for _ in pairs(S and S.spawns or {}) do n=n+1 end return n end
 print('[wild] spawns',count(),'phase',game.phase)
 local dirs={'up','down'};local lost=0
 for i=1,96 do
  U.hold(game,dirs[math.floor(i/8)%2+1],16);U.wait(2)
  if game.phase~='field' then lost=lost+1;print('[wild] PHASE LEFT FIELD at step',i,game.phase);break end
 end
 print('[wild] grass walk done: steps 96, left field',lost>0,'spawns',count(),'phase',game.phase)
 if lost==0 then
  local row;for _,r in pairs(S.spawns) do if r.visible and not r.ambient then row=r;break end end
  if not row then print('[wild] no visible wild to touch') else
   print('[wild] touching',row.species,'at',row.cellX,row.cellY)
   pcall(Player.reset,row.cellX,row.cellY,'down')
   print('[wild] player cell',Player.cellX,Player.cellY,'row',row.cellX,row.cellY,'visible',row.visible,'catching',row.catching)
   for _=1,12 do U.wait(10) if game.phase~='field' then break end end
   print('[wild] player cell after',Player.cellX,Player.cellY,'row',row.cellX,row.cellY)
   print('[wild] after touch phase',game.phase)
   print('[wild] row still present',S.spawns[row.id]==row)
   local ok,a,b=pcall(S.encounter,row);print('[wild] direct encounter',ok,a,b)
   for _=1,20 do U.wait(15) if game.phase~='field' then break end end
   print('[wild] later phase',game.phase,'present',S.spawns[row.id]==row)
  end
 end
 U.shot(game,dir..'/wild_end.png')
 print('[EM QA] done')
 love.event.quit()
end
