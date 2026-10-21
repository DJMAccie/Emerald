-- POKEPORT_DRIVER: final relief heights of the rock-mass cells Gen3Relief claims (a copy of em_relief_driver.lua).
-- One line per claimed cell: MAP x y MID coll hmin hmax groundMin groundMax mouth massId nearestFloor   (ground: walkable non-mass 8-neighbours' floors, '-' none)
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>  (QA identity only)
--   EM_DUMP_WAIT=<frames a spot builds, default 300>
-- One line per cell that belongs to a rock mass, written once from the first spot that built it (the same
-- spot walk as em_cells_driver.lua, at the orbit camera):
--   MAP x y MID builder relief sea
-- builder: rock = Gen3Rock.handles takes the mass, dome = Gen3Mass draws it; relief: 1 when Gen3Relief claimed it;
-- sea: 1 for sea boulders (Relief skips them by design).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local C=(ex.gen3 or ex.firered).camera
 local Scene=ex.lib.require('Gen3Scene')
 local Rock=ex.lib.require('Gen3Rock')
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 local seen={}
 local nseen=0
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   local wait=tonumber(os.getenv('EM_DUMP_WAIT') or '') or 300
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});C.setLevel(7,game);U.wait(wait)
   local def=Map.currentDef()
   if not (def and def.midLayout) then f:write(('SKIP %s no midLayout\n'):format(id))
   else
    local W,H=def.midLayout.width,def.midLayout.height
    local written,tried={}, {}
    for spot=1,12 do
     if spot>1 then
      local mx,my
      for cy=0,H-1 do for cx=0,W-1 do if not mx and not written[cx..':'..cy] and not tried[cx..':'..cy] then mx,my=cx,cy end end end
      if not mx then break end
      tried[mx..':'..my]=true
      Map.load(nil,game,id,{x=math.min(W-1,mx+24),y=math.min(H-1,my+24),facing='down'});C.setLevel(7,game);U.wait(wait)
     end
     for cy=-3,H+2 do for cx=-4,W+3 do
      if not written[cx..':'..cy] and Scene.debugCell(cx,cy) then
       written[cx..':'..cy]=true
       local r=Scene.debugRaw(cx,cy)
       local m=r and r.mass
       if m then
        local R=m.reliefData
        if R and not seen[m] then
         nseen=nseen+1;seen[m]=nseen
         local a={}
         for _,e in ipairs(R.A or {}) do a[#a+1]=('%s:%.0f'):format(tostring(e[1]),e[2]) end
         f:write(('MASS#%d %s n=%d local=%s stand=%s A=%s\n'):format(nseen,id,#m.members,tostring(m.reliefLocal),R.stand and ('%.2f'):format(R.stand) or '-',table.concat(a,',')))
         if R.OFF then
          local hist,keys={}, {}
          for _,c in ipairs(m.members) do local o=R.OFF[c];if o then local k=math.floor(o/8+.5)*8;if not hist[k] then hist[k]=0;keys[#keys+1]=k end;hist[k]=hist[k]+1 end end
          table.sort(keys)
          local t={}
          for _,k in ipairs(keys) do t[#t+1]=('%d:%d'):format(k,hist[k]) end
          f:write(('OFFHIST#%d %s %s\n'):format(nseen,id,table.concat(t,' ')))
         end
        end
        local h=R and R.H and R.H[r]
        if h then
         local lo,hi=1e9,-1e9
         for k=1,25 do lo=math.min(lo,h[k]);hi=math.max(hi,h[k]) end
         local gl,gh=1e9,-1e9
         for dx=-1,1 do for dy=-1,1 do
          local n=(dx~=0 or dy~=0) and Scene.debugRaw(cx+dx,cy+dy)
          if n and n.mass~=m and (n.collision or 0)==0 then local fl=n.floorHigh or n.base or 0;gl=math.min(gl,fl);gh=math.max(gh,fl) end
         end end
         f:write(('%s %d %d %03X %s %.1f %.1f %s %s %d %d %s\n'):format(id,cx,cy,r.mid or 0,tostring(r.collision),lo,hi,gl<1e9 and ('%.1f'):format(gl) or '-',gh>-1e9 and ('%.1f'):format(gh) or '-',(R.mouth and R.mouth[r]) and 1 or 0,seen[m] or 0,(R.FL and R.FL[r]) and ('%.1f'):format(R.FL[r]) or '-'))
        end
       end
      end
     end end
    end
   end
  end
  f:flush()
 end
 f:close();love.event.quit()
end
