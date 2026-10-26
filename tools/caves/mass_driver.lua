-- POKEPORT_DRIVER (QA only): the mass each listed cell belongs to.
--   EM_MAPS=<file: "MAP x y cx cy [cx cy]..."> EM_DUMP=<out.txt>  EM_SETVARS="VAR=n,..."
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 for k,v in (os.getenv('EM_SETVARS') or ''):gmatch('([%w_]+)=(%d+)') do require('src.core.game3.rse.init').setVar(k,tonumber(v)) end
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local C=(ex.gen3 or ex.firered).camera
 local Scene=ex.lib.require('Gen3Scene')
 local Rock=ex.lib.require('Gen3Rock')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local t={};for w in line:gmatch('%S+')do t[#t+1]=w end
  Map.load(nil,game,t[1],{x=tonumber(t[2]),y=tonumber(t[3]),facing='down'});C.setLevel(7,game);U.wait(tonumber(os.getenv('EM_DUMP_WAIT') or '') or 200)
  f:write('MAP '..t[1]..'\n')
  for i=4,#t,2 do
   local cx,cy=tonumber(t[i]),tonumber(t[i+1])
   local r=Scene.debugRaw(cx,cy)
   local m=r and r.mass
   f:write(('%d,%d mid=%03X kind=%s coll=%s mass=%s\n'):format(cx,cy,r and r.mid or 0,tostring(r and r.shape and r.shape.kind),tostring(r and r.collision),
     m and ('n='..#m.members..' box='..m.x0..','..m.y0..'-'..m.x1..','..m.y1..' rock='..tostring(m.rock~=nil)..' handles='..tostring(Rock.handles(m,nil))..' boulder='..tostring(m.boulder)) or 'none'))
   if os.getenv('EM_SHAPE') and r and r.shape then local sub={};for kk,vv in pairs(r.shape)do if type(vv)~='table' then sub[#sub+1]=kk..'='..tostring(vv) end end;table.sort(sub);f:write('   shape: '..table.concat(sub,' ')..'\n') end
  end
  f:flush()
 end
 f:close();love.event.quit()
end
