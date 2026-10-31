-- POKEPORT_DRIVER: the R-36 look gate's capture driver — p0_driver's captures
-- with the two things that are NOT the mod's look switched off, so two runs of
-- the same build are pixel-identical and a diff means the mod changed.
--
-- WHY: p0 captures differ run to run by 200-2'100 px with no mod change at all
-- (measured 2026-10-31: the same build captured twice differed in 8 of 9
-- frames, worst 1540 px at Littleroot, in compact 24-32 px blocks = the
-- engine's own wandering actors, plus the animated tileset). A gate that
-- compares those frames reports the actors, not the look.
--   objects.forDraw = {}            no NPC/actor sprites drawn
--   tileset_anim._enabled = false   no animated water/flowers
-- Everything else is p0_driver: EM_CASES, EM_LEVELS, EM_WAIT, SHOT_DIR.
return function(game)
 io.stdout:setvbuf('no')
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 local okObj,Objects=pcall(require,'src.core.game3.objects')
 if okObj and Objects then Objects.forDraw=function() return {} end end
 local okAnim,TilesetAnim=pcall(require,'src.core.game3.tileset_anim')
 if okAnim and TilesetAnim then TilesetAnim._enabled=false end
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(120)
 local exports=game.mods and game.mods.exports or {}
 local ex=exports.EMERALD_3D
 print('[CAP] export:', ex and 'yes' or 'NO')
 local P=ex and ex.gen3 and ex.gen3.probe
 print('[CAP] probe:', P and 'yes' or 'NO')
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {{'EM_LITTLEROOT_TOWN',10,10}}
 local levels=os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4}
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[CAP] load',case[1],ok,err or '')
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   U.wait(tonumber(os.getenv('EM_WAIT')) or 120)
   if P then
    for _=1,600 do if P.active and P.active() then break end;U.wait(1) end
    local w0,w1,w2,w3
    if P.window then w0,w1,w2,w3=P.window() end
    print(('[CAP] %s active=%s builds=%s window=%s,%s,%s,%s'):format(case[1],
      tostring(P.active and P.active()),tostring(P.builds and P.builds()),
      tostring(w0),tostring(w1),tostring(w2),tostring(w3)))
   end
   for _,level in ipairs(levels) do
    U.wait(30)
    -- the player's facing is engine state (Player.facing) that a map script or a
    -- late reset can leave turned: pin it again so the sprite the field draws is
    -- the same in every run (measured: two runs of one build differed only in the
    -- player's pose at Route 111)
    pcall(Player.reset, case[2], case[3], 'down')
    U.wait(2)
    local path=string.format('%s/%s_L%d.png',dir,case[1],level)
    U.shot(game,path)
    print('[CAP] shot',path)
   end
  end
 end
 print('[CAP] done')
 love.event.quit()
end
