-- Boot Emerald in the QA identity and watch the Stadium 2 importer extract.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(120)
 local ex=game.mods and game.mods.exports and game.mods.exports.STADIUM2_IMPORTER
 print('[S2] importer exports:',ex and 'yes' or 'NO')
 if not ex then love.event.quit() return end
 print('[S2] models api:',ex.models and ex.models.apiVersion, 'US_MD5',ex.US_MD5)
 local last
 for i=1,tonumber(os.getenv('S2_FRAMES') or 6000) do
  U.wait(60)
  local ok,st=pcall(ex.status); local okc,cs=pcall(ex.cacheStatus)
  local line=string.format('[S2] t=%ds status=%s stage=%s progress=%s cache=%s/%s err=%s',i,ok and tostring(st and st.state) or 'ERR', ok and tostring(st and (st.stage or st.phase)) or '', ok and tostring(st and (st.progress or st.percent or st.count)) or '', okc and tostring(cs and cs.state) or 'ERR', okc and tostring(cs and cs.code) or '', ok and tostring(st and (st.error or st.message)) or tostring(st))
  if line~=last then print(line);last=line end
  if ok and st and (st.state=='ready' or st.state=='failed') then break end
 end
 local okA,avail=pcall(ex.available); print('[S2] available:',okA and tostring(avail) or avail)
 local okI,inst=pcall(function() return ex.models.newInstance(25,nil,{}) end)
 print('[S2] newInstance(25):',okI, okI and (inst and 'instance' or 'nil') or tostring(inst))
 love.event.quit()
end
