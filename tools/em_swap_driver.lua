-- POKEPORT_DRIVER: do the game's runtime tile swaps (setmetatile / MapGridSetMetatileIdAt) reach the 3D scene?
--   EM_SWAP_OUT=<dir>   (QA identity only; run it through tools/qa_run.sh with EM_DRIVER=this file, cases "-")
-- Each case loads a map, dumps a window of cells (mid, shape kind, collision, prop, resolved ground height at
-- the cell centre for layer 3 and layer 4), applies swaps through Field.setMetatile exactly as the game's
-- scripts do, waits until the scene shows the new tile (or gives up), and dumps the window again.
-- Output: <dir>/<case>.<step>.txt (step 0 = as loaded) in the dump-line format of tools/heights_compare.py,
-- and <dir>/swap_summary.txt (tile read-back from the engine, frames until the scene rebuilt, or NO REBUILD).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Scene=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen3Scene')
 -- same pins as em_cells_driver.lua: Mirage Tower coin flip off, animated tiles frozen
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local Map=require('src.core.game3.map')
 local Field=require('src.core.game3.field')
 local FieldMoves=require('src.core.game3.field_moves')
 local OUT=assert(os.getenv('EM_SWAP_OUT'))
 local log=assert(io.open(OUT..'/swap_summary.txt','w'))
 local function say(...)local s=table.concat({...},' ');log:write(s,'\n');log:flush();print('[swap] '..s)end
 local WAIT=tonumber(os.getenv('EM_DUMP_WAIT') or '') or 300

 local function snapshot(path,id,x0,y0,x1,y1)
  local f=assert(io.open(path,'w'));local n=0
  for cy=y0,y1 do for cx=x0,x1 do
   local c=Scene.debugCell(cx,cy)
   if c then
    n=n+1
    f:write(('%s %d %d %03X %s coll=%s prop=%s col=%s h3=%s h4=%s\n'):format(id,cx,cy,c.mid or 0,tostring(c.kind),tostring(c.collision),
     tostring(c.prop),c.col and 'y' or '-',tostring(Scene.groundAt(cx*16+8,cy*16+8,3)),tostring(Scene.groundAt(cx*16+8,cy*16+8,4))))
   end
  end end
  f:close();return n
 end

 -- case = {name, map, start={x,y}, window={x0,y0,x1,y1}, steps={{label, {{x,y,mid,impassable},...}},...}}
 -- (steps may be a function of the loaded map def, for cases that choose their cells from the map)
 local cases={
  -- Route 120: Route120_EventScript_SetBridgeClearMetatiles (pokeemerald data/maps/Route120/scripts.inc:45)
  {name='route120_bridge',map='EM_ROUTE120',start={13,21},window={7,10,19,22},steps={
   {'bridge clear',{{13,15,0x297,false},{12,16,0x29F,false},{12,17,0x0A1,false},{13,17,0x0A1,false}}}}},
  -- control: a swap that changes nothing (the tile it sets is the tile already there) must change nothing in the scene
  {name='route120_noop',map='EM_ROUTE120',start={13,21},window={7,10,19,22},steps={
   {'no-op swap',{{12,16,0x29F,false},{12,17,0x0A1,false}}}}},
  -- Route 105: Route105_CloseRegiEntrance (scripts.inc:13), then the cartridge's own tiles again (the entrance open)
  {name='route105_rockwall',map='EM_ROUTE105',start={9,25},window={3,14,15,26},steps={
   {'regi entrance closed (rock wall)',{{9,19,0x07C,true},{9,20,0x091,true}}},
   {'regi entrance open (ROM tiles)',{{9,19,0x064,false},{9,20,0x0A7,false}}}}},
  -- cut grass (fldeff_cut.c SetCutGrassMetatiles): the first cells of long/tall grass on Route 102 become short grass
  {name='route102_cutgrass',map='EM_ROUTE102',window=nil,pick=function(def)
    local L=def.midLayout;local cells={}
    for cy=0,L.height-1 do for cx=0,L.width-1 do
     local mid=L:midAt(cx,cy);local to=mid and FieldMoves.cutGrassMetatile(mid)
     if to and #cells<8 and (not cells[1] or (math.abs(cx-cells[1][1])<=3 and math.abs(cy-cells[1][2])<=3)) then cells[#cells+1]={cx,cy,to,false} end
    end end
    if #cells==0 then return nil end
    local x,y=cells[1][1],cells[1][2]
    return {start={x,y+3},window={x-6,y-6,x+6,y+6},steps={{'cut grass',cells}}}
   end},
 }

 for _,k in ipairs(cases) do
  local c=k
  if c.pick then
   Map.load(nil,game,c.map,{x=10,y=10,facing='down'});U.wait(60)
   local picked=c.pick(Map.currentDef())
   if not picked then say(c.name,'SKIP: no cut-grass cells found');c=nil else c={name=k.name,map=k.map,start=picked.start,window=picked.window,steps=picked.steps} end
  end
  if c then
   local W=c.window
   Map.load(nil,game,c.map,{x=c.start[1],y=c.start[2],facing='down'});U.wait(WAIT)
   local def=Map.currentDef();local L=def and def.midLayout
   if not L then say(c.name,'SKIP: no midLayout')
   else
    say(c.name,'session map =',tostring(Field._session and Field._session.map),'(must equal',c.map..')')
    say(c.name,'step 0 (as loaded):',snapshot(('%s/%s.0.txt'):format(OUT,c.name),c.map,W[1],W[2],W[3],W[4]),'cells')
    for i,step in ipairs(c.steps) do
     local label,swaps=step[1],step[2]
     local before={}
     for j,s in ipairs(swaps)do before[j]=L:midAt(s[1],s[2])end
     for _,s in ipairs(swaps)do Field.setMetatile(s[1],s[2],s[3],s[4])end
     -- the engine's own read-back, then wait for the scene to show the last swapped tile
     local eng={}
     for j,s in ipairs(swaps)do eng[#eng+1]=('(%d,%d) %03X->%03X'):format(s[1],s[2],before[j] or 0,L:midAt(s[1],s[2]) or 0)end
     local last=swaps[#swaps];local frames
     for t=0,900,10 do
      local r=Scene.debugRaw(last[1],last[2])
      if r and r.mid==last[3] then frames=t;break end
      U.wait(10)
     end
     U.wait(120)   -- let the rest of the region settle (background rebuild)
     local n=snapshot(('%s/%s.%d.txt'):format(OUT,c.name,i),c.map,W[1],W[2],W[3],W[4])
     say(c.name,'step',i,label,'| engine:',table.concat(eng,' '),'| scene shows new tile after',frames and (frames..' frames') or 'NO REBUILD (900 frames)','|',n,'cells')
    end
    -- the same map loaded again from scratch: does the game re-apply the swaps, and does a fresh build give the
    -- same cells and heights as the incremental rebuild did? (the last step's file is the incremental answer)
    Map.load(nil,game,c.map,{x=c.start[1],y=c.start[2],facing='down'});U.wait(WAIT)
    local d2=Map.currentDef();local L2=d2 and d2.midLayout
    local lastSwap=c.steps[#c.steps][2];local rb={}
    for _,s in ipairs(lastSwap)do rb[#rb+1]=('(%d,%d) %03X'):format(s[1],s[2],L2 and L2:midAt(s[1],s[2]) or 0)end
    local n2=snapshot(('%s/%s.fresh.txt'):format(OUT,c.name),c.map,W[1],W[2],W[3],W[4])
    say(c.name,'fresh reload read-back:',table.concat(rb,' '),'|',n2,'cells')
   end
  end
 end
 log:close();love.event.quit()
end
