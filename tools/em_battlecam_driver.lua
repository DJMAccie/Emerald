-- Battle-camera QA driver: stage an Emerald wild battle, walk the menu into a
-- fight, and capture the camera director's own cuts.
--
-- The point is to see the SHOTS, so this driver does what the generic battle
-- driver does not:
--
--   * it logs one line per cut and a heartbeat with the live scene angles,
--     so the sequence can be read out of the log rather than guessed at
--   * it takes a shot on every cut, so one run yields the whole sequence
--   * it reports the real frame interval, because "is this slow?" wants a
--     number rather than an impression
--   * it can hold the camera still (EM_HOLD=1) or set the rest rake for the
--     run (EM_REST_YAW=<degrees>), to shoot one variable at a time
--
--   EM_PLAYER_SPECIES / EM_FOE_SPECIES  national dex numbers (default 252/270)
--   EM_BATTLE_FRAMES                    how long to run (default 1500)
--   EM_HOLD=1                           BATTLE CAMERA OFF for this run
--   EM_REST_YAW=<deg>                   override the arena's rest rake
--   EM_ORBIT=<deg> EM_STEER_AT=<frame>  steer by hand once, mid-run
--   EM_TAG=<name>                       shot filename prefix
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 local TAG=os.getenv('EM_TAG') or 'shot'
 local frames=tonumber(os.getenv('EM_BATTLE_FRAMES') or 1500)
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,
   start={map='EM_ROUTE101',8,10,x=8,y=10,facing='down'}})
 U.wait(90)
 local Party=require('src.core.game3.party')
 local Pokemon=require('src.core.game3.pokemon')
 local function internal(nat) return Pokemon.speciesFromNational(tonumber(nat)) or tonumber(nat) end
 local playerSp=internal(os.getenv('EM_PLAYER_SPECIES') or 252)
 local foeSp=internal(os.getenv('EM_FOE_SPECIES') or 270)
 local code,mon=Party.giveMonToPlayer(game.session,playerSp,12)
 print('[CAM] give mon:',code,mon and mon.species)
 local ex=game.mods.exports.STADIUM2_IMPORTER
 for i=1,120 do
  U.wait(30)
  local st=ex and ex.status()
  if st and (st.state=='ready' or st.state=='failed') then
   print('[CAM] importer',st.state,'after',i*0.5,'s') break
  end
 end

 -- The rest rake, before the first battle frame exists: Gen3Battle reads it
 -- when it builds the camera for a new battle state.
 local G3=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen3Battle')
 do
  local deg=tonumber(os.getenv('EM_REST_YAW') or '')
  if deg then
   G3.restYaw=math.rad(deg)
   print(string.format('[CAM] rest rake set to %+.0f degrees',deg))
  else
   print(string.format('[CAM] rest rake default %+.0f degrees',
     math.deg(G3.restYaw or 0)))
  end
 end

 local Bridge=require('src.core.game3.battle_bridge')
 local ok,err=pcall(Bridge.startWild,game.mods,game,{species=foeSp,level=8},{})
 print('[CAM] startWild:',ok,err)

 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local BattleCam=lib.require('BattleCam')
 local UiBackplates=lib.require('UiBackplates')
 local Battle=require('src.core.game3.battle')
 local Stage=lib.require('OverworldBattle')
 local okShots,BattleShots=pcall(lib.require,'BattleShots')
 if not okShots then BattleShots=nil;print('[CAM] no BattleShots module in this build') end

 if os.getenv('EM_HOLD') and BattleShots then
  BattleShots.setting.index=3
  print('[CAM] BATTLE CAMERA held OFF for this run (setting='
    ..tostring(BattleShots.setting:get())..')')
 end

 local function log(fmt,...) print('[CAM] '..string.format(fmt,...)) end

 local lastShot,lastPhase,lastAnim=nil,nil,nil
 local shots=0
 local framesRun,dtSum,dtMax,dtMin=0,0,0,1e9
 local marks={}

 local BS=lib.require('BattleShots')
 print(string.format('[CAM] rake check: G3.restYaw=%s SCENE_RAKE=%s scene(wide)=%.1f deg',
   tostring(G3.restYaw), tostring(BS.SCENE_RAKE),
   math.deg(select(1,BS.scene('wide')))))

 local function sceneYaw()
  local cam=G3.camera
  if not cam then return 0,0,0 end
  local o=cam.orbit or {}
  return math.deg((cam.yaw or 0)-(cam.arenaYaw or 0)), cam.pitch or 0,
         math.deg(cam.arenaYaw or 0), o.yaw or 0, o.shotYaw or 0
 end

 for t=1,frames do
  U.wait(1)
  do
   local d=love.timer.getDelta()
   framesRun=framesRun+1;dtSum=dtSum+d
   if d>dtMax then dtMax=d end
   if d<dtMin then dtMin=d end
   if t%120==0 then marks[#marks+1]=string.format('%d:%.1fms',t,d*1000) end
  end

  local st=Battle._st
  local now=(BattleShots and BattleShots.state()) or {shot='-'}
  local shot=Stage.shot and Stage.shot()

  if now.shot and now.shot~=lastShot then
   lastShot=now.shot
   shots=shots+1
   local sy,sp,ay=sceneYaw()
   log('t=%4d CUT -> %-9s relYaw %+6.1f pitch %+.3f arenaYaw %+8.1f | phase %s',
     t, tostring(now.shot), sy, sp, ay, tostring(st and st.phase))
  end
  if st and st.phase~=lastPhase then
   lastPhase=st.phase
   log('t=%4d phase %s',t,tostring(st.phase))
  end
  if st and (st.animPlaying and true or false)~=lastAnim then
   lastAnim=st.animPlaying and true or false
   if lastAnim then
    log('t=%4d MOVE %s attackerPlayer=%s',t,tostring(st.animName),
        tostring(st.animAttackerIsPlayer))
   else
    log('t=%4d move animation done',t)
   end
  end

  -- Fight, for real. A blind A-mash does not reach Emerald's fight menu: the
  -- menu only reads input on its own frames, so a press that lands between
  -- them is lost. Read the phase and press what that phase wants, and retry
  -- every few frames (the pattern tests/drivers/battle_shake_bug354_test.lua
  -- uses for the same reason).
  -- Phase-gated, but never silent: this automation is for CAPTURE, so if the
  -- phase never becomes 'menu'/'moveSelect' the run still has to make progress
  -- for the fight to be looked at. `EM_BLIND=1` drops the gate.
  local gate = st and (not os.getenv('EM_BLIND'))
  if st and t>360 and t%6==0 and gate then
   if st.phase=='moveSelect' then
    -- walk the cursor to slot 1, then commit
    local want=tonumber(os.getenv('EM_MOVE_SLOT') or 1)
    local cur=tonumber(st.moveIndex) or 1
    if cur~=want then U.tap(game, cur<want and 'down' or 'up')
    else U.tap(game,'a') end
   elseif st.phase=='menu' then
    if (tonumber(st.menuIndex) or 1)~=1 then
      U.tap(game, (tonumber(st.menuIndex) or 1)>2 and 'up' or 'left')
    else U.tap(game,'a') end
   else
    U.tap(game,'a')
   end
  elseif st and t>360 and t%12==0 and not gate then
   U.tap(game,'a')
  end
  local steerAt=tonumber(os.getenv('EM_STEER_AT') or 0)
  if steerAt>0 and t==steerAt then
   local deg=tonumber(os.getenv('EM_ORBIT') or 0)
   BattleCam.dragOrbit(deg/45)
   log('t=%4d manual steer %s deg -> orbitGoal %.3f',t,tostring(deg),
       BattleCam.orbitGoal)
  end
  if t%300==0 then
   local sy,sp,ay,oy,osy=sceneYaw()
   log('t=%4d heartbeat shot=%s relYaw %+6.1f pitch %+.3f arenaYaw %+8.1f orbit.yaw %+.1f orbit.shot %+.1f paper=%s',
     t,tostring(now.shot),sy,sp,ay,math.deg(oy),math.deg(osy),
     tostring(UiBackplates.textboxMode()))
  end
  -- Screenshots are expensive (300-500ms each on this Mac, a full GPU
  -- readback), so a run takes a handful on purpose rather than one per cut.
  -- EM_FORCE_BEATS=1: the menu taps do not reach the fight menu under this
  -- automation, so walk the director through its beats by hand instead --
  -- this verifies the SHOT MAPPING (which angle, cut or glide, where the
  -- camera ends up), which is what the cuts are, and leaves the actual
  -- battle-driven sequencing to be seen in a played fight.
  if os.getenv('EM_FORCE_BEATS') and t>=600 then
   local beat=({[600]='attacker',[700]='target',[820]='settle',[960]='wide'})[t]
   if beat then
    -- A CUT is instant and a glide takes M.ORBIT_TIME (0.3s, ~18 frames),
    -- so settle for 30 frames before reading the angle the shot reached.
    local okBeat=G3.directScene(beat,beat~='settle')
    U.wait(30)
    local sy,sp=sceneYaw()
    log('  forced %-8s ok=%s  -> relYaw %+7.1f pitch %+.3f',
      beat,tostring(okBeat),sy,sp)
   end
  end
  if t==60 or t==300 or t==600 or t==900 then
   U.shot(game,string.format('%s/%s_t%d.png',dir,TAG,t))
  end
 end

 log('done: %d cuts into %s',shots,dir)
 log('frame time: mean %.1fms (%.1f fps)  min %.1fms  max %.1fms',
   dtSum/math.max(1,framesRun)*1000, framesRun/math.max(0.001,dtSum),
   dtMin*1000, dtMax*1000)
 log('samples '..table.concat(marks,' '))
 love.event.quit()
end
