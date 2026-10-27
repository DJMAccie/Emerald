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

 -- copy of Gen3Scene.flightAxis (local there), reading cells through debugRaw
 local cellsT=setmetatable({},{__index=function(_,k)local x,y=k:match('^(-?%d+):(-?%d+)$');return Scene.debugRaw(tonumber(x),tonumber(y))end})
 local function flightAxis(c,cells)
  local f=c.floor
  if not(f and f.step) or c.shape.kind~='flat' or c.base==nil then return nil end
  local B=c.base
  for _,ax in ipairs({{{0,-1},{0,1}},{{-1,0},{1,0}}})do
   local a=cells[(c.cx+ax[1][1])..':'..(c.cy+ax[1][2])]
   local b=cells[(c.cx+ax[2][1])..':'..(c.cy+ax[2][2])]
   if a and b then
    local da,db=(a.base or 0)-B,(b.base or 0)-B
    if da>.5 and db<-.5 then return {up=ax[1],down=ax[2],rise=da,dhi=a,dlo=b} end
    if db>.5 and da<-.5 then return {up=ax[2],down=ax[1],rise=db,dhi=b,dlo=a} end
    local open=ax[1][1]==0 and a.collision~=7 and b.collision~=7 and not (a.shape and (a.shape.kind=='cliff' or a.shape.kind=='rock'))
     and not (b.shape and (b.shape.kind=='cliff' or b.shape.kind=='rock'))
    if open and da-db>.5 and da>-.5 and db<.5 then return {up=ax[1],down=ax[2],rise=da-db,dhi=a,dlo=b} end
    if open and db-da>.5 and db>-.5 and da<.5 then return {up=ax[2],down=ax[1],rise=db-da,dhi=b,dlo=a} end
   end
  end
  return nil
 end
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
     local r=Scene.debugRaw(cx,cy)
     if r then
      local g=r.stairs;local sk=r.shape and r.shape.kind or ''
      local fl=flightAxis(r,cellsT)
      local isStep=r.floor and r.floor.step
      if g or sk=='steps' or sk=='ladder' or isStep or fl then
       local bld=(g and ('recipe:'..tostring(g.r.pair)..(g.owner==r and '*' or ''))) or (fl and 'generic') or (sk=='steps' and 'steps') or (sk=='ladder' and 'ladder') or 'stepcell-noflight'
       f:write(('%s %d %d %03X pair=%s kind=%s coll=%s base=%s builder=%s step=%s up=%s rise=%s\n'):format(id,cx,cy,r.mid or 0,tostring(r.pair),sk,tostring(r.collision),tostring(r.base),bld,isStep and 1 or 0,
        fl and (fl.up[1]..','..fl.up[2]) or '-',fl and tostring(fl.rise) or '-'))
      end
     end
    end
   end end
   end
   end
  end
  f:write('#DONE '..tostring(id)..'\n')
  f:flush()   -- a watchdog stop keeps the maps done so far
 end
 f:close();love.event.quit()
end
