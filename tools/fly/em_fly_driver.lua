-- QA driver: one Fly flight in the 3D scene (Gen3FlyOver), captured at the beats of the flight.
--   EM_FLIGHT=<name> EM_DRIVER=<this file> tools/qa_tryp.sh "Gen3FlyPath.lua Gen3FlyOver.lua Gen3Scene.lua Gen3Integration.lua" <abs out> "-" 4 0 200
-- Flights (start town's Pokemon Center door -> destination's): short, land, sea, mountain, iso (Lilycove ->
-- Sootopolis), isofrom (Sootopolis -> Mauville), home (Littleroot: its fly spot is a bedroom, so the original Fly).
-- EM_FLIGHT_OFF=1: 3D off, the original Fly must still end on the destination. EM_FLIGHT_OVERHEAD=1: north-up camera.
-- EM_FLIGHT_B=1: press B in the air (skip to the landing).
-- Prints [fly dbg] lines (phase, progress, altitude, frame ms) and grep-able [FlyOver] lines from the module.
-- Level 4 = the overview camera, 7 = orbit, 6 = first person (qa_tryp's 4th argument).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 local FLIGHTS={
  short={'LITTLEROOT','MAPSEC_OLDALE_TOWN',{'EM_LITTLEROOT_TOWN',10,10}},
  land={'MAPSEC_PETALBURG_CITY','MAPSEC_MAUVILLE_CITY'},
  sea={'MAPSEC_SLATEPORT_CITY','MAPSEC_MOSSDEEP_CITY'},
  mountain={'MAPSEC_FALLARBOR_TOWN','MAPSEC_LAVARIDGE_TOWN'},
  iso={'MAPSEC_LILYCOVE_CITY','MAPSEC_SOOTOPOLIS_CITY'},
  isofrom={'MAPSEC_SOOTOPOLIS_CITY','MAPSEC_MAUVILLE_CITY'},
  home={'MAPSEC_RUSTBORO_CITY','MAPSEC_LITTLEROOT_TOWN'},
 }
 local name=os.getenv('EM_FLIGHT') or 'short'
 local spec=assert(FLIGHTS[name],'unknown flight '..name)
 local Field=require('src.core.game3.field')
 local Pokemon=require('src.core.game3.pokemon')
 local Party=require('src.core.game3.party')
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local from=spec[3]
 local destSec=spec[2]
 if not from then
  local d=assert(Field.flyDestination(spec[1]),'no fly spot for '..spec[1])
  from={d.map,d.x,d.y}
 end
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map=from[1],x=from[2],y=from[3],facing='down'}})
 U.wait(90)
 local export=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local ns=export and (export.gen3 or export.firered)
 local C=ns and ns.camera
 local lib=export and export.lib
 local Fly=lib and lib.require('Gen3FlyOver')
 assert(Fly,'Gen3FlyOver is not in this mod copy')
 local level=os.getenv('EM_FLIGHT_OFF') and 0 or (tonumber(((dofile(os.getenv('EM_LEVELS')) or {})[1])) or 4)
 if C then C.setLevel(level,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0 end
 if os.getenv('EM_FLIGHT_OVERHEAD') then Fly.YAW_FOLLOW=false end
 local sp=Pokemon.speciesFromNational(tonumber(os.getenv('EM_FLY_SPECIES') or 276)) or 276   -- Swellow
 local code,mon=Party.giveMonToPlayer(game.session,sp,30)
 print('[fly dbg] flight',name,'from',from[1],from[2],from[3],'to',destSec,'level',level,'mon',code,mon and mon.species)
 U.wait(120)   -- the start town builds
 local scene=lib.require('Gen3Scene')
 local ex=game.mods.exports.overworld_wild_spawns
 print('[fly dbg] follower mod export',ex and 'yes' or 'NO','resolveGen3Sprite',ex and type(ex.resolveGen3Sprite) or '-')
 if ex and ex.resolveGen3Sprite then
  local okR,gid=pcall(ex.resolveGen3Sprite,mon and mon.species,nil,false)
  print('[fly dbg] rider sprite',okR,tostring(gid))
 end
 U.shot(game,dir..'/'..name..'_00_before.png')
 local dest=assert(Field.flyDestination(destSec),'no destination '..destSec)
 print('[fly dbg] destination',dest.map,dest.x,dest.y)
 local t0=love.timer.getTime()
 Field.flyTo(destSec,mon,{dest=dest})
 -- the cut-in and the fade-in come first (the engine's own); then the flight starts
 local shots={{'mount',.55,'01_mount'},{'fly',.04,'02_liftoff'},{'fly',.30,'03_30'},{'fly',.50,'04_50'},{'fly',.70,'05_70'},{'fly',.90,'06_90'},{'dismount',.45,'07_landing'}}
 local took={}
 local started,frames,last=false,0,love.timer.getTime()
 local worst,worstAt=0,''
 local prevMs=16
 local pressedB=false
 local drawMs=0
 do   -- CPU time of the scene's draw call per frame (a frame much longer than this is the GPU or the present)
  local orig=scene.draw
  scene.draw=function(...)
   local t0=love.timer.getTime()
   local a,b,c=orig(...)
   drawMs=drawMs+(love.timer.getTime()-t0)*1000
   return a,b,c
  end
 end
 local hist={}   -- frame ms per phase (the frames that took a screenshot are left out)
 local pendingB=false
 for i=1,9000 do
  if pendingB then game.input.pressed.b=true;pendingB=false end   -- (set after the shot's frames, so Fly.update sees it)
  -- the QA loop steps the game without the mod's core.update hook, so the flight is stepped here, as that hook does
  if Fly.active() then
   local ok,err=pcall(Fly.update,math.max(.001,prevMs/1000),game)
   if not ok then Fly.abort(err) end
   game.input.pressed.b=nil   -- EM_FLIGHT_B sets it for this one update (U.tap would set and clear it inside the next frame)
  end
  U.wait(1)
  local now=love.timer.getTime()
  local ms=(now-last)*1000;last=now;prevMs=ms
  local s=Fly.state()
  if s then
   if not started then print('[fly dbg] flight started at frame',i,string.format('%.1f s',love.timer.getTime()-t0)) end
   started=true;frames=frames+1
   if not s.swapping then local h=hist[s.phase] or {};hist[s.phase]=h;h[#h+1]=ms end
   if ms>worst then worst,worstAt=ms,s.phase end
   if ms>40 then
    local st=love.graphics.getStats()
    print(string.format('[fly slow] %.0f ms in %s t=%.2f/%.2f h=%.0f swapped=%s | scene.draw cpu %.0f ms, draw calls %d, canvas switches %d, tex mem %.0f MB',ms,s.phase,s.t,s.T,s.h or 0,tostring(s.swapped),drawMs,st.drawcalls or -1,st.canvasswitches or -1,(st.texturememory or 0)/1048576))
   end
   drawMs=0
   if frames%45==1 then
    print(string.format('[fly dbg] %s t=%.2f/%.2f sp=%.2f h=%.0f ready=%s swapped=%s map=%s ms=%.0f active=%s',s.phase,s.t,s.phase=='fly' and s.T or 1,s.sp or 0,s.h or 0,tostring(s.ready),tostring(s.swapped),tostring(Map.current),ms,tostring(C and C.active)))
   end
   if os.getenv('EM_FLIGHT_B') and s.phase=='fly' and not pressedB and s.t>s.T*.3 then pressedB=true;pendingB=true end
   local Path=lib.require('Gen3FlyPath');local total={mount=Path.MOUNT,fly=s.T,dismount=Path.DISMOUNT}
   for k,m in ipairs(shots) do
    if not took[k] and s.phase==m[1] and s.t>=m[2]*total[m[1]] then
     took[k]=true
     if hist[s.phase] then hist[s.phase][#hist[s.phase]]=nil end
     U.shot(game,dir..'/'..name..'_'..m[3]..'.png')
     print('[fly dbg] shot',m[3],'t',string.format('%.2f',s.t),'h',string.format('%.0f',s.h or 0),'map',Map.current)
     last=love.timer.getTime()
    end
   end
  elseif started then
   break
  elseif i>900 and not started then
   print('[fly dbg] no flight after',i,'frames; map',Map.current,'locked',tostring(Field.locked))
   if Field.locked==false then break end
  end
 end
 for _,ph in ipairs({'mount','fly','dismount'})do
  local h=hist[ph]
  if h and #h>0 then
   table.sort(h)
   local over=0;for _,v in ipairs(h)do if v>40 then over=over+1 end end
   print(string.format('[fly dbg] frames %-8s n=%3d  p50 %.0f  p90 %.0f  p99 %.0f  max %.0f ms  over 40 ms: %d',ph,#h,h[math.ceil(#h*.5)],h[math.ceil(#h*.9)],h[math.ceil(#h*.99)],h[#h],over))
  end
 end
 U.wait(45)
 print('[fly dbg] landed: map',Map.current,'cell',Player.cellX,Player.cellY,'facing',Player.facing,'locked',tostring(Field.locked),'visible',tostring(Player.isVisible()),
  'wanted',dest.map,dest.x,dest.y,'flight wall',string.format('%.1f s',love.timer.getTime()-t0),'worst frame',string.format('%.0f ms (%s)',worst,worstAt),'scene ready',tostring(scene.readyFor(dest.map)))
 U.shot(game,dir..'/'..name..'_08_landed.png')
 U.wait(90)
 U.shot(game,dir..'/'..name..'_09_after.png')
 print('[fly dbg] done')
 love.event.quit()
end
