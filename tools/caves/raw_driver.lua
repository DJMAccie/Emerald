-- POKEPORT_DRIVER (QA only): every field of the raw cell record at given cells.
--   EM_MAPS=<file: "MAP x y cx cy [cx cy]..."> EM_DUMP=<out.txt>
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 -- (QA only: EM_SETVARS="VAR_SKY_PILLAR_STATE=2,..." story variables set before the first map load)
 for k,v in (os.getenv('EM_SETVARS') or ''):gmatch('([%w_]+)=(%d+)') do require('src.core.game3.rse.init').setVar(k,tonumber(v)) end
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local C=(ex.gen3 or ex.firered).camera
 local Scene=ex.lib.require('Gen3Scene')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local t={};for w in line:gmatch('%S+')do t[#t+1]=w end
  local id=t[1]
  Map.load(nil,game,id,{x=tonumber(t[2]),y=tonumber(t[3]),facing='down'});C.setLevel(7,game);U.wait(tonumber(os.getenv('EM_DUMP_WAIT') or '') or 200)
  local def=Map.currentDef()
  local n=0;for _ in pairs(def.midLayout.overrides or {})do n=n+1 end
  f:write('state='..tostring(require('src.core.game3.rse.init').var('VAR_SKY_PILLAR_STATE'))..' overrides='..n..'\n')
  f:write('MAP '..id..' layout '..tostring(def and def.midLayout and (def.midLayout.width..'x'..def.midLayout.height))..'\n')
  for i=4,#t,2 do
   local cx,cy=tonumber(t[i]),tonumber(t[i+1])
   local r=Scene.debugRaw(cx,cy)
   f:write(('cell %d %d layoutmid=%s\n'):format(cx,cy,tostring(def.midLayout:midAt(cx,cy))))
   r=nil
   if r then
    local keys={};for k in pairs(r)do keys[#keys+1]=tostring(k)end;table.sort(keys)
    for _,k in ipairs(keys)do
     local v=r[k]
     local s
     if type(v)=='table' then
      local sub={};for kk,vv in pairs(v)do if type(vv)~='table' and type(vv)~='function' then sub[#sub+1]=tostring(kk)..'='..tostring(vv) end end;table.sort(sub);s='{'..table.concat(sub,',')..'}'
     else s=tostring(v) end
     f:write(('  %s = %s\n'):format(k,s))
    end
   else f:write('  nil\n') end
  end
  f:flush()
 end
 f:close();love.event.quit()
end
