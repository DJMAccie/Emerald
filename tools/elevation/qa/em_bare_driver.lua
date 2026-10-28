-- POKEPORT_DRIVER: bare-drop wedge gate (task 34 B, option A). For each "MAP x y" line of EM_MAPS (spots are walked until every
-- cell of the map has been built, as em_cells_driver) writes, per scene cell whose field floor carries rampC (Gen3Elevation
-- bare-drop corner heights), one line, and checks:
--   ANGLE   adjacent corner heights of a tilted cell differ by more than 16.01 px (steeper than 45 degrees)
--   NOSLOPE a field rampC cell the scene did not tilt (an object / prop / door on it): fine, but counted
--   BADKIND a tilted cell that is a door, stair, step, tree, prop or column (must stay flat)
--   LIFT    a tilted corner below the cell's own height (monotonic rise violated)
-- Out: EM_DUMP lines "CELL ..." / "BAD ..." / "SUMMARY map cells tilted noslope angle badkind lift". EM_DUMP_WAIT frames per spot (300).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Scene=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen3Scene')
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   local wait=tonumber(os.getenv('EM_DUMP_WAIT') or '') or 300
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(wait)
   local def=Map.currentDef()
   if def and def.midLayout then
    local W,H=def.midLayout.width,def.midLayout.height
    local written,tried={},{}
    local doors={}
    for _,w in ipairs(def.warps or {})do if tonumber(w.x) and tonumber(w.y) then doors[tonumber(w.x)..','..tonumber(w.y)]=1 end end
    local n,tilted,noslope,angle,badkind,lift=0,0,0,0,0,0
    for spot=1,12 do
     if spot>1 then
      local mx,my
      for cy=0,H-1 do for cx=0,W-1 do if not mx and not written[cx..':'..cy] and not tried[cx..':'..cy] then mx,my=cx,cy end end end
      if not mx then break end
      tried[mx..':'..my]=true
      Map.load(nil,game,id,{x=math.min(W-1,mx+24),y=math.min(H-1,my+24),facing='down'});U.wait(wait)
     end
     for cy=0,H-1 do for cx=0,W-1 do
      if not written[cx..':'..cy] then
       local r=Scene.debugRaw(cx,cy)
       if r then
        written[cx..':'..cy]=true
        local fl=r.floor
        if type(fl)=='table' and fl.rampC then
         n=n+1
         local rc=fl.rampC;local sl=r.slope
         local why={}
         if sl then tilted=tilted+1 else noslope=noslope+1 end
         local h0=fl.height or 0
         for _,w in ipairs({{1,2},{4,3},{1,4},{2,3}})do
          if math.abs(rc[w[1]]-rc[w[2]])>16.01 then angle=angle+1;why[#why+1]='ANGLE';break end
         end
         for w=1,4 do if rc[w]<h0-.01 then lift=lift+1;why[#why+1]='LIFT';break end end
         local sk=r.shape and r.shape.kind or ''
         if sl and (r.stairs or sk=='steps' or sk=='tree' or r.prop or r.column or r.object or doors[cx..','..cy] or (r.collision or 0)~=0) then badkind=badkind+1;why[#why+1]='BADKIND' end
         f:write(('CELL %s %d %d kind=%s h=%s rampC=%s,%s,%s,%s slope=%s %s\n'):format(id,cx,cy,sk,tostring(h0),tostring(rc[1]),tostring(rc[2]),tostring(rc[3]),tostring(rc[4]),
          sl and (sl[1]..','..sl[2]..','..sl[3]..','..sl[4]) or 'nil',table.concat(why,'+')))
        end
       end
      end
     end end
    end
    f:write(('SUMMARY %s cells=%d tilted=%d noslope=%d angle=%d badkind=%d lift=%d\n'):format(id,n,tilted,noslope,angle,badkind,lift))
    f:flush()
   end
  end
 end
 f:close();love.event.quit()
end
