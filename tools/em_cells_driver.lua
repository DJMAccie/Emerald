-- POKEPORT_DRIVER: print every cell's scene classification for given maps.
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>  (QA identity only)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Scene=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen3Scene')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 -- Scene's own DECK_FAMILY (local there): fortree's walkway tiles and rope bridge
 local DECK={general__fortree={[0x256]=1}}
 for t=0x210,0x21D do DECK.general__fortree[t]=1 end
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120)
   local def=Map.currentDef()
   if not (def and def.midLayout) then f:write(('SKIP %s no midLayout\n'):format(id))
   else
   local W,H=def.midLayout.width,def.midLayout.height
   -- warp cells (doors and exits): the same list collision.lua reads
   local doors={}
   for _,w in ipairs(def.warps or {})do if tonumber(w.x) and tonumber(w.y) then doors[tonumber(w.x)..','..tonumber(w.y)]=1 end end
   for cy=-3,H+2 do for cx=-4,W+3 do
    local c=Scene.debugCell(cx,cy)
    if c then
     -- fields appended after the original nine so old column positions hold
     local r=Scene.debugRaw(cx,cy) or {}
     local g=r.stairs;local sk=r.shape and r.shape.kind or ''
     local sdir=(g and g.r) and ((g.r.east and 'E' or 'W')..(g.r.down and '-down' or '-up')) or (sk=='steps' and 'steps') or '-'
     local fam=DECK[r.pair]
     local bridge=(r.shape and r.shape.underWater) or (r.collision==0 and r.floor and (r.floor.layer==15 or (fam and fam[r.mid]))) or sk:match('^deck')
     f:write(('%s %d %d %03X %s coll=%s prop=%s col=%s base=%s stairs=%d sdir=%s ladder=%d ledge=%d rail=%d bridge=%d door=%d elev=%s\n'):format(id,cx,cy,c.mid or 0,tostring(c.kind),tostring(c.collision),tostring(c.prop),c.col and 'y' or '-',tostring(c.base),
      (g or sk=='steps') and 1 or 0,sdir,sk=='ladder' and 1 or 0,sk=='ledge' and 1 or 0,sk=='rail' and 1 or 0,bridge and 1 or 0,doors[cx..','..cy] or 0,tostring(def.midLayout:elevAt(cx,cy))))
    end
   end end
   end
  end
 end
 f:close();love.event.quit()
end
