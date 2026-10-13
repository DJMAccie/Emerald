-- In-battle frame-time probe. Stages a wild battle and samples the frame
-- interval once the fight is up, with no menu input and no screenshots.
--   EM_FRAMES  frames to sample (default 240)   EM_SKIP  frames to wait first
--   EM_PHASE   label   EM_STAGE=off  turn 3D-BTL off before the fight
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local skip=tonumber(os.getenv('EM_SKIP') or 240)
 local frames=tonumber(os.getenv('EM_FRAMES') or 240)
 local phase=os.getenv('EM_PHASE') or 'battle'
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,
   start={map='EM_ROUTE101',8,10,x=8,y=10,facing='down'}})
 U.wait(90)
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 if os.getenv('EM_DIRECTOR')=='off' then
  local BS=lib.require('BattleShots')
  BS.setting.index=3
  print('[PERF] BATTLE CAMERA (director) set to '..tostring(BS.setting:get()))
 end
 if os.getenv('EM_STAGE')=='off' then
  local G3=lib.require('Gen3Battle')
  G3.setting.index=2
  print('[PERF] 3D-BTL set to '..tostring(G3.setting:get()))
 end
 local Party=require('src.core.game3.party')
 local Pokemon=require('src.core.game3.pokemon')
 local function internal(nat) return Pokemon.speciesFromNational(tonumber(nat)) or tonumber(nat) end
 Party.giveMonToPlayer(game.session,internal(os.getenv('EM_PLAYER_SPECIES') or 252),12)
 for i=1,120 do
  U.wait(30)
  local st=game.mods.exports.STADIUM2_IMPORTER.status()
  if st and (st.state=='ready' or st.state=='failed') then break end
 end
 local Bridge=require('src.core.game3.battle_bridge')
 pcall(Bridge.startWild,game.mods,game,
      {species=internal(os.getenv('EM_FOE_SPECIES') or 270),level=8},{})
 for _=1,skip do U.wait(1) end
 local sum,max,min,n=0,0,1e9,0
 local marks={}
 for t=1,frames do
  U.wait(1)
  local d=love.timer.getDelta()
  n=n+1;sum=sum+d
  if d>max then max=d end
  if d<min then min=d end
  if t%60==0 then marks[#marks+1]=string.format('%d:%.1f',t,d*1000) end
 end
 print(string.format('[PERF] %s frames=%d mean=%.1fms (%.1f fps) min=%.1f max=%.1f | %s',
   phase,n,sum/n*1000,n/sum,min*1000,max*1000,table.concat(marks,' ')))
 love.event.quit()
end
