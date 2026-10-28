-- POKEPORT_DRIVER: stair flights against the 45 degree rule (R-34): one line per run of step cells (columns and rows)
--   FLIGHT map axis x y n lo hi climbs cls cells(low/high/mid/ext, lower end first)  heights in px; EM_MAPS=<file "MAP x y"> EM_DUMP=<out.txt>
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
    local function step(c)return c and c.step and not c.connector end
    local function ok(c)return c and c.floor and (not c.step or c.connector) and c.kind~='water' and c.height~=nil end
    local done={}
    -- every maximal run of step cells, on the axis its profile climbs (c.stairUp), else the axis whose two end floors differ
    -- (vertical first); one line per run: ends and cells ordered from the LOWER end (cell = low/high/mid/ext)
    for y=0,H-1 do for x=0,W-1 do
     local c=C(x,y)
     if step(c) and not done[c] then
      local y0=y;while step(C(x,y0-1))do y0=y0-1 end
      local y1=y;while step(C(x,y1+1))do y1=y1+1 end
      local x0=x;while step(C(x0-1,y))do x0=x0-1 end
      local x1=x;while step(C(x1+1,y))do x1=x1+1 end
      local vA,vB,hA,hB=C(x,y0-1),C(x,y1+1),C(x0-1,y),C(x1+1,y)
      local vOk=ok(vA) and ok(vB);local hOk=ok(hA) and ok(hB)
      local vR=vOk and math.abs(vA.height-vB.height) or -1;local hR=hOk and math.abs(hA.height-hB.height) or -1
      local axis
      if c.stairUp then axis=(c.stairUp[2]~=0) and 'v' or 'h'
      elseif vOk and hOk then axis=((hR>=.25)==(vR>=.25) and (x1-x0)<(y1-y0)) and 'h' or ((hR>=.25 and vR<.25) and 'h' or 'v')
      elseif hOk then axis='h' else axis='v' end
      local cells,A,B={},nil,nil
      if axis=='v' then for yy=y0,y1 do cells[#cells+1]=C(x,yy) end;A,B=vA,vB
      else for xx=x0,x1 do cells[#cells+1]=C(xx,y) end;A,B=hA,hB end
      for _,q in ipairs(cells)do done[q]=true end
      local lowIsA=not (ok(A) and ok(B)) or A.height<=B.height
      local lo,hi=A and A.height,B and B.height
      if not lowIsA then local r={};for i=#cells,1,-1 do r[#r+1]=cells[i] end;cells=r;lo,hi=hi,lo end
      local out={}
      for _,q in ipairs(cells)do out[#out+1]=string.format('%s/%s/%03X/%s',tostring(q.low),tostring(q.high),l:cellAt(q.x,q.y).mid or 0,q.stepExt and 'e' or '-') end
      f:write(('FLIGHT %s %s %d %d %d lo=%s hi=%s climbs=%s cls=%s cells=%s\n'):format(id,axis,cells[1].x,cells[1].y,#cells,tostring(lo),tostring(hi),tostring(c.stairUp~=nil),tostring(A and A.cls),table.concat(out,',')))
      n=n+1
     end
    end end
    for _,t in ipairs(fld.stairSteep or {})do f:write('STEEPWHY '..t..'\n') end
    f:write(('COUNT %s %d\n'):format(id,n));f:flush()
   end
  end
 end
 f:close();love.event.quit()
end
