-- POKEPORT_DRIVER: which rock-mass cells counted relief (Gen3Relief) claims.
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
        local b=(Rock.handles(m,nil) and 'rock') or 'dome'
        local H=m.rock and m.rock.H and m.rock.H[r]
        f:write(('%s %d %d %03X %s %d %d %s %s %s %s\n'):format(id,cx,cy,r.mid or 0,b,m.relief and 1 or 0,m.seaBoulders and 1 or 0,H and math.floor(H+.5) or '-',tostring(r.base and math.floor(r.base+.5)),tostring(r.shape and r.shape.kind),tostring(r.collision)))
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
