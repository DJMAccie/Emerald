-- POKEPORT_DRIVER: walk the in-game OPTIONS once (for the runtime file trace, M0 step 3).
-- Opens Emerald's option screen on Littleroot (shot), then builds the same rows the screen shows through the engine's
-- row builder (src.ui.game3.option_rows) and steps every row of the old mod one notch forward and back, so each
-- option's change handler runs and the value is restored; then a shot of the scene after.
-- Use under docs/proposals/dropin/trace_driver.lua: EM_INNER=<this file>. QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 local dir=assert(os.getenv('SHOT_DIR'))
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(240)
 local Screens=require('src.ui.game3.screens')
 local OM=Screens.get('option',game.session)
 local okShow,eShow=pcall(OM.show,{session=game.session,game=game})
 U.wait(20);U.shot(game,dir..'/options_top.png')
 pcall(OM.close);U.wait(10)
 local Options=require('src.core.game3.options')
 local Rows=require('src.ui.game3.option_rows')
 local engine=Options.engine(game.session) or game.options or {}
 local ctx={session=game.session,game=game,options=engine}
 local MOD='BATTLE_ART_VOXEL_FORK:'
 local stepped,failed=0,0
 local ok,err=pcall(function()
  for _,row in ipairs(Rows.build(ctx))do
   if row.step and type(row.id)=='string' and row.id:sub(1,#MOD)==MOD then
    local v0=row.value and select(2,pcall(row.value,ctx))
    local ok1=pcall(row.step,ctx,1);U.wait(20)
    local ok2=pcall(row.step,ctx,-1);U.wait(20)
    local v1=row.value and select(2,pcall(row.value,ctx))
    stepped=stepped+1;if not (ok1 and ok2) then failed=failed+1 end
    print(('[EM opt]\t%s\t%s\t%s\t%s'):format(row.id,tostring(ok1 and ok2),tostring(v0),v0==v1 and 'restored' or ('NOW '..tostring(v1))))
   end
  end
 end)
 print(('[EM opt] show=%s %s stepped=%d failed=%d ok=%s %s'):format(tostring(okShow),tostring(eShow or ''),stepped,failed,tostring(ok),tostring(err or '')))
 U.wait(120)
 U.shot(game,dir..'/after.png')
 love.event.quit()
end
