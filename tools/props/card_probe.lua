-- driver (EM_DRIVER): visit the maps in EM_CASES, then write every tree card the mod built to SHOT_DIR/cards.txt
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert(love.filesystem.getIdentity()=='pokemon-love2d-rseqa','refusing a non-QA identity')
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=dofile(os.getenv('EM_CASES'))
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[CARDS] map',case[1],ok,err or '')
  if ok then pcall(Player.reset,case[2],case[3],'down');U.wait(tonumber(os.getenv('EM_WAIT')) or 60) end
 end
 local export=game.mods and game.mods.exports and game.mods.exports.BATTLE_ART_VOXEL_FORK
 local N=export and export.lib and export.lib.require('NativeTreeArt')
 local f=io.open(dir..'/cards.txt','w')
 if N and N.debugCards and f then
  for _,c in ipairs(N.debugCards())do
   f:write('CARD ',table.concat(c.labels,' | '),'\n',c.w,' ',c.h,'\n')
   for _,r in ipairs(c.rows)do f:write(r,'\n')end
  end
  f:close()
 end
 print('[CARDS] done')
 love.event.quit()
end
