-- POKEPORT_DRIVER: P0 skeleton check for the clean rewrite mod (EMERALD_3D).
-- Boots Emerald in a private QA identity, loads the case maps, waits for the mod's probe to report that its 3D field
-- draw is active, prints the probe answers and captures one frame per level.
--   EM_CASES=<cases.lua> EM_LEVELS=<levels.lua> EM_WAIT=<frames> SHOT_DIR=<dir>
-- Reads ONLY the mod's public exports (mod.exports.gen3.probe); no mod internals.
return function(game)
 io.stdout:setvbuf('no')
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(120)
 local exports=game.mods and game.mods.exports or {}
 local ex=exports.EMERALD_3D
 print('[P0] export:', ex and 'yes' or 'NO')
 local P=ex and ex.gen3 and ex.gen3.probe
 print('[P0] probe:', P and 'yes' or 'NO')
 local FV=require('src.core.game3.field_view'); local origDraw=FV.draw; local drawN=0
 FV.draw=function(...) drawN=drawN+1; return origDraw(...) end
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {{'EM_LITTLEROOT_TOWN',10,10}}
 local levels=os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4}
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[P0] load',case[1],ok,err or '')
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   U.wait(tonumber(os.getenv('EM_WAIT')) or 120)
   if P then
    for _=1,600 do if P.active and P.active() then break end;U.wait(1) end
    local w0,w1,w2,w3
    if P.window then w0,w1,w2,w3=P.window() end
    local H=ex and ex.gen3hook
    if H then
      local okE,FV=pcall(require,'src.core.game3.field_view')
      print('[P0] fieldview engine=',tostring(FV),'mod=',tostring(H.fieldView),'same=',tostring(FV==H.fieldView))
      print(('[P0] hook calls=%s sceneOk=%s sceneFalse=%s err=%s'):format(
      tostring(H.calls),tostring(H.sceneOk),tostring(H.sceneFalse),tostring(H.lastError)))
    end
    print('[P0] engine-side fieldview.draw calls', drawN, 'orig=', tostring(origDraw))
    print(('[P0] probe %s active=%s builds=%s started=%s pending=%s window=%s'):format(
      case[1],tostring(P.active and P.active()),tostring(P.builds and P.builds()),
      tostring(P.started and P.started()),tostring(P.pending and P.pending()),
      tostring(w0)..','..tostring(w1)..','..tostring(w2)..','..tostring(w3)))
   end
   for _,level in ipairs(levels) do
    U.wait(30)
    local path=string.format('%s/%s_L%d.png',dir,case[1],level)
    U.shot(game,path)
    print('[P0] shot',path)
   end
  end
 end
 print('[P0] done')
 love.event.quit()
end
