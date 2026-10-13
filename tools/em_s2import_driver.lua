-- Force a fresh Stadium 2 import in the QA identity and report whether the
-- battle-FX specials land in the cache. QA only: it overwrites QA's Stadium 2
-- cache and never touches the real identity.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local ex=assert(game.mods.exports.STADIUM2_IMPORTER,'no STADIUM2_IMPORTER export')
 print('[S2] available='..tostring(ex.available and ex.available()))
 print('[S2] status='..tostring(ex.status and (ex.status().state or '?')))
 print('[S2] forcing reimport')
 local ok,err=pcall(ex.reimport)
 print('[S2] reimport call: '..tostring(ok)..' '..tostring(err))
 local last=''
 for i=1,2400 do   -- up to ~20 minutes of engine frames
  U.wait(30)
  local st=ex.status and ex.status() or {}
  local line=string.format('%s done=%s/%s phase=%s',tostring(st.state),
    tostring(st.done),tostring(st.total),tostring(st.phase))
  if line~=last then last=line; print('[S2] '..line) end
  if st.state=='ready' or st.state=='failed' then
   print('[S2] FINAL state='..tostring(st.state)..' error='..tostring(st.error or st.message))
   break
  end
 end
 local cat,catErr=ex.battleFxCatalog and ex.battleFxCatalog()
 print('[S2] battleFxCatalog='..tostring(cat~=nil)..' err='..tostring(catErr))
 if cat and cat.moves then
  local n=0; for _ in pairs(cat.moves) do n=n+1 end
  print('[S2] catalog moves='..n)
 end
 local res,resErr=ex.battleFxResources and ex.battleFxResources(85)
 print('[S2] resources(85)='..tostring(res~=nil)..' err='..tostring(resErr))
 local player,perr=ex.newBattleFxPlayer and ex.newBattleFxPlayer({})
 print('[S2] newBattleFxPlayer='..tostring(player~=nil)..' err='..tostring(perr))
 love.event.quit()
end
