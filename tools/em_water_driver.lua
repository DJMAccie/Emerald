-- POKEPORT_DRIVER: why does Route 120's lake rise from 0 to 8 px when the bridge swap runs?
--   EM_SWAP_OUT=<dir>   (QA identity only; tools/qa_run.sh with EM_DRIVER=this file, cases "-")
-- Dumps the floor solver's own cell record (kind, floor, pin, height, group, waterfall) for a window, in these states:
--   a  as loaded            b  all four bridge swaps, incremental rebuild      c  b + Scene.invalidate() (a fresh build)
--   d  only (13,17) -> water   e  only (13,15) -> bridge top   (each from a freshly loaded map)
-- plus a whole-map tally of water-cell heights as loaded. Files: <dir>/<state>.txt, <dir>/water_summary.txt.
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
 local Field=require('src.core.game3.field')
 local OUT=assert(os.getenv('EM_SWAP_OUT'))
 local WAIT=tonumber(os.getenv('EM_DUMP_WAIT') or '') or 300
 local log=assert(io.open(OUT..'/water_summary.txt','w'))
 local function say(...)local s=table.concat({...},' ');log:write(s,'\n');log:flush();print('[water] '..s)end
 -- the scene's private cache, through the upvalue of a function that reads it
 -- (Scene.invalidate() rebinds `cache`, so it is fetched afresh every time)
 local function theCache()
  for i=1,40 do local n,v=debug.getupvalue(Scene.groundAt,i);if not n then break end;if n=='cache' then return v end end
  error('no cache upvalue')
 end
 local function regionAt(cx,cy)
  for _,r in ipairs(theCache().floorRegions or {})do if cx>=r.x and cy>=r.y and cx<r.x+r.w and cy<r.y+r.h then return r end end
 end
 local gid,gn={},0
 local function snap(name,x0,y0,x1,y1)
  local f=assert(io.open(OUT..'/'..name..'.txt','w'))
  for cy=y0,y1 do for cx=x0,x1 do
   local r=regionAt(cx,cy);local c=r and r.floorField and r.floorField.cells[(cx-r.x)..':'..(cy-r.y)]
   if c then
    local g=c.group;if g and not gid[g] then gn=gn+1;gid[g]=gn end
    f:write(('EM_ROUTE120 %d %d %s kind=%s floor=%s pin=%s h=%s grp=%s wf=%s step=%s\n'):format(cx,cy,
     string.format('%03X',(Scene.debugCell(cx,cy) or {}).mid or 0),tostring(c.kind),tostring(c.floor and true or false),tostring(c.pin),
     tostring(c.height),tostring(g and gid[g]),tostring(c.waterfall and true or false),tostring(c.step and true or false)))
   end
  end end
  f:close()
 end
 local W={7,10,19,22}
 local function load()Map.load(nil,game,'EM_ROUTE120',{x=13,y=21,facing='down'});U.wait(WAIT)end
 local function swap(list)for _,s in ipairs(list)do Field.setMetatile(s[1],s[2],s[3],false)end;U.wait(200)end
 local BRIDGE={{13,15,0x297},{12,16,0x29F},{12,17,0x0A1},{13,17,0x0A1}}

 load()
 for i,r in ipairs(theCache().floorRegions or {})do
  local n=0;for _ in pairs(r.floorField and r.floorField.cells or {})do n=n+1 end
  say('region',i,'x',r.x,'y',r.y,'w',r.w,'h',r.h,'cells',n,'id',tostring(r.def and r.def.id),'offset',tostring(r.floorOffset))
 end
 snap('a_loaded',unpack(W))
 -- whole-map tally of water-cell heights (every floor region built round this spot)
 local tally={}
 for _,r in ipairs(theCache().floorRegions or {})do for _,c in pairs(r.floorField and r.floorField.cells or {})do
  if c.kind=='water' then local k=tostring(c.height);tally[k]=(tally[k] or 0)+1 end end end
 local t={};for k,n in pairs(tally)do t[#t+1]=k..'px x'..n end;table.sort(t)
 say('as loaded, water cells by height in the built regions:',table.concat(t,'  '))

 swap(BRIDGE);snap('b_incremental',unpack(W))
 Scene.invalidate();U.wait(WAIT);snap('c_fresh_build',unpack(W))
 say('after invalidate: tiles read',(Map.currentDef().midLayout:midAt(13,15)),(Map.currentDef().midLayout:midAt(13,17)))
 load();swap({{13,17,0x0A1}});snap('d_only_13_17',unpack(W))
 load();swap({{13,15,0x297}});snap('e_only_13_15',unpack(W))
 log:close();love.event.quit()
end
