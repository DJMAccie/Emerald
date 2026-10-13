-- Let a Stadium 2 import finish, then report what landed. Does nothing else.
--   EM_MINUTES  how long to allow (default 12)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,
   start={map='EM_ROUTE101',8,10,x=8,y=10,facing='down'}})
 U.wait(120)
 local ex=game.mods.exports.STADIUM2_IMPORTER
 local minutes=tonumber(os.getenv('EM_MINUTES') or 12)
 local frames=minutes*60*60
 local last=''
 for i=1,frames do
  U.wait(1)
  if i%120==0 then
   local st=ex.status and ex.status() or {}
   local line=string.format('%s %s/%s %s',tostring(st.state),tostring(st.done),
     tostring(st.total),tostring(st.phase))
   if line~=last then last=line; print('[S2W] '..line) end
   if st.state=='ready' or st.state=='failed' then
    print('[S2W] final='..tostring(st.state)..' err='..tostring(st.error or st.message))
    break
   end
  end
 end
 local cat,catErr=ex.battleFxCatalog and ex.battleFxCatalog()
 print('[S2W] battleFxCatalog='..tostring(cat~=nil)..' err='..tostring(catErr))
 local res,resErr=ex.battleFxResources and ex.battleFxResources(85)
 print('[S2W] resources(85)='..tostring(res~=nil)..' err='..tostring(resErr))
 local player,perr=ex.newBattleFxPlayer and ex.newBattleFxPlayer({})
 print('[S2W] newBattleFxPlayer='..tostring(player~=nil)..' err='..tostring(perr))
 local inst,ierr=ex.models.newInstance(25,'normal',{})
 print('[S2W] newInstance(25)='..tostring(inst~=nil)..' err='..tostring(ierr))
 love.event.quit()
end
