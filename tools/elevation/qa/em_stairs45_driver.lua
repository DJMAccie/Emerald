-- POKEPORT_DRIVER: stair flights against the 45 degree rule (R-34): one line per vertical run of step cells
--   FLIGHT map x top n northH southH cellLowHigh(...)  heights in px; EM_MAPS=<file "MAP x y"> EM_DUMP=<out.txt>
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local E=lib.require('Gen3Elevation');local Levels=lib.require('TerrainLevels')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id=line:match('^(%S+)')
  if id then
   Map.load(nil,game,id,{x=5,y=5,facing='down'});U.wait(120)
   local def=Map.currentDef()
   if def and def.midLayout then
    local l=def.midLayout;local W,H=l.width,l.height
    local fld=E.field(def)
    local function C(x,y)return fld.cells[Levels.key(x,y)] end
    local n=0
    for x=0,W-1 do for y=0,H-1 do
     local c=C(x,y)
     if c and c.step and not (C(x,y-1) and C(x,y-1).step) then
      local cells={};local yy=y
      while C(x,yy) and C(x,yy).step do local q=C(x,yy);cells[#cells+1]=string.format('%s/%s/%03X',tostring(q.low),tostring(q.high),l:cellAt(x,yy).mid or 0);yy=yy+1 end
      local nn,ss=C(x,y-1),C(x,yy)
      f:write(('FLIGHT %s %d %d %d north=%s south=%s ncls=%s scls=%s cells=%s\n'):format(id,x,y,#cells,tostring(nn and nn.height),tostring(ss and ss.height),tostring(nn and nn.cls),tostring(ss and ss.cls),table.concat(cells,',')))
      n=n+1
     end
    end end
    f:write(('COUNT %s %d\n'):format(id,n));f:flush()
   end
  end
 end
 f:close();love.event.quit()
end
