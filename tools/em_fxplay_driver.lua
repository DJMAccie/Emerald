-- What does the Stadium 2 effect runtime actually produce once it can decode?
-- Trigger a move's EFFECT and report the packets a renderer would have to draw.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,
   start={map='EM_ROUTE101',8,10,x=8,y=10,facing='down'}})
 U.wait(120)
 local ex=assert(game.mods.exports.STADIUM2_IMPORTER)
 print('[FX] modelsEnabled='..tostring(ex.modelsEnabled())
   ..' battleEnabled='..tostring(ex.battleEnabled())
   ..' betaBattleFxEnabled='..tostring(ex.betaBattleFxEnabled()))
 local cat,catErr=ex.battleFxCatalog()
 print('[FX] catalog='..tostring(cat~=nil)..' err='..tostring(catErr))
 local Runtime=require('mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_runtime')
 local Cat=cat or (function()
   local Cache=require('mods.STADIUM2_IMPORTER.lib.cache')
   local FxRom=require('mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom')
   return FxRom.catalog(Cache.readSpecial('battle_fx_rom'), Cache.readSpecial('battle_fx_trig'))
 end)()
 print('[FX] catalog via cache='..tostring(Cat~=nil))
 if not Cat then love.event.quit() return end
 for _,moveId in ipairs({85, 1, 57}) do
  local ok, rt = pcall(Runtime.new, {catalog=Cat, rng=function() return 0.5 end})
  if not ok then print('[FX] runtime for move '..moveId..' failed: '..tostring(rt)) else
   local okT, res, err = pcall(rt.trigger, rt, {moveId=moveId, alternate=false,
     sourceSide='player', targetSide='enemy'})
   print(('[FX] move %d trigger=%s err=%s'):format(moveId, tostring(res), tostring(err)))
   local drawable, packets, kinds = 0, 0, {}
   for tick=1,40 do
    pcall(rt.step, rt, 1)
    local okS, snap = pcall(rt.snapshot, rt, {shared=true})
    if okS and type(snap)=='table' then
     for _,p in ipairs(snap.particles or {}) do
      packets = packets + 1
      local k = p.kind or (p.event and p.event.kind) or '?'
      kinds[k] = (kinds[k] or 0) + 1
     end
    end
   end
   local list={}
   for k,v in pairs(kinds) do list[#list+1]=k..'='..v end
   table.sort(list)
   print(('[FX]   move %d: snapshots=%d kinds: %s'):format(moveId, packets, table.concat(list,' ')))
  end
 end
 love.event.quit()
end
