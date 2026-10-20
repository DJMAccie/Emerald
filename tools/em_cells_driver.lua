-- POKEPORT_DRIVER: print every cell's scene classification for given maps.
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>  (QA identity only)
--   EM_DUMP_WAIT=<frames a spot builds, default 300>
-- The scene builds only the view distance round the player (32 cells), so one spot saw half of a long
-- route (Route 111: rows 2-72 of 140) and the audits checked half of it. Each map is dumped from its
-- listed spot and then from further spots, each centred on the first cell not yet dumped, until every
-- cell of the map is in (at most 12 spots); every cell is written once, from the first spot that built it.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Scene=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen3Scene')
 -- Two dumps of one build must be identical (the gate for any height change). Two things in the game itself
 -- change from run to run, so pin them: Route 111's Mirage Tower shows on a coin flip taken when the map
 -- loads (mirage_tower.c SetMirageTowerVisibility: its 18 cells are a different tile and collision each
 -- time), and the tilesets' animated tiles are repainted as the game runs while the scene reads their
 -- pixels to tell rock from ground (Route 118's boulder rim, Lilycove 74,9).
 require('src.core.game3.rng').Random=function()return 0 end   -- an even draw: the tower is hidden
 if os.getenv('EM_ANIM')~='1' then require('src.core.game3.tileset_anim')._enabled=false end   -- EM_ANIM=1: animation runs (the classification must not care)
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 -- Scene's own DECK_FAMILY (local there): fortree's walkway tiles and rope bridge
 local DECK={general__fortree={[0x256]=1}}
 for t=0x210,0x21D do DECK.general__fortree[t]=1 end
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   local wait=tonumber(os.getenv('EM_DUMP_WAIT') or '') or 300
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(wait)
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
    -- (the window reaches 32 cells round the player's 6-cell block: centre it 24 cells past the gap)
    Map.load(nil,game,id,{x=math.min(W-1,mx+24),y=math.min(H-1,my+24),facing='down'});U.wait(wait)
   end
   -- warp cells (doors and exits): the same list collision.lua reads
   local doors={}
   for _,w in ipairs(def.warps or {})do if tonumber(w.x) and tonumber(w.y) then doors[tonumber(w.x)..','..tonumber(w.y)]=1 end end
   for cy=-3,H+2 do for cx=-4,W+3 do
    local c=not written[cx..':'..cy] and Scene.debugCell(cx,cy)
    if c then written[cx..':'..cy]=true
     -- fields appended after the original nine so old column positions hold
     local r=Scene.debugRaw(cx,cy) or {}
     local g=r.stairs;local sk=r.shape and r.shape.kind or ''
     local sdir=(g and g.r) and ((g.r.east and 'E' or 'W')..(g.r.down and '-down' or '-up')) or (sk=='steps' and 'steps') or '-'
     local fam=DECK[r.pair]
     local bridge=(r.shape and r.shape.underWater) or (r.collision==0 and r.floor and (r.floor.layer==15 or (fam and fam[r.mid]))) or sk:match('^deck')
     f:write(('%s %d %d %03X %s coll=%s prop=%s col=%s base=%s stairs=%d sdir=%s ladder=%d ledge=%d rail=%d bridge=%d door=%d elev=%s ldrop=%s\n'):format(id,cx,cy,c.mid or 0,tostring(c.kind),tostring(c.collision),tostring(c.prop),c.col and 'y' or '-',tostring(c.base),
      (g or sk=='steps') and 1 or 0,sdir,sk=='ladder' and 1 or 0,sk=='ledge' and 1 or 0,sk=='rail' and 1 or 0,bridge and 1 or 0,doors[cx..','..cy] or 0,tostring(def.midLayout:elevAt(cx,cy)),
      -- (a jump ledge's direction, from the floor solver's cell: dx,dy of the jump - stairs_audit's ledge check)
      (r.floor and r.floor.drop) and (r.floor.drop[1]..','..r.floor.drop[2]) or '-'))
    end
   end end
   end
   end
  end
  f:flush()   -- a watchdog stop keeps the maps done so far
 end
 f:close();love.event.quit()
end
