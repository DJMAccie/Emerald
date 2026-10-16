-- POKEPORT_DRIVER: print every built cell of one map's window as a height grid, so the fill cells
-- OUTSIDE the map (Gen3Boundary's donors) can be told from the map's own cells.
--   EM_MAP=EM_ROUTE112 EM_CX=27 EM_CY=29 EM_LEVEL=7 EM_YAW=2.2 EM_DUMP=<out.txt>  (QA identity only)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local export=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=export.lib.require('Gen3Scene')
 local ns=export.gen3 or export.firered
 local C=ns and ns.camera
 local Map=require('src.core.game3.map')
 local id=os.getenv('EM_MAP') or 'EM_ROUTE112'
 local cx,cy=tonumber(os.getenv('EM_CX') or 27),tonumber(os.getenv('EM_CY') or 29)
 if C then C.setLevel(tonumber(os.getenv('EM_LEVEL') or 7),game);C.yaw=tonumber(os.getenv('EM_YAW') or 2.2) end
 -- NOTE: os.getenv is stubbed out inside the mod sandbox, so the game's own code must never be
 -- gated on an environment variable; this driver runs outside that sandbox and may use it freely.
 Map.load(nil,game,id,{x=cx,y=cy,facing='down'})
 U.wait(tonumber(os.getenv('EM_WAIT') or 400))
 for _=1,900 do if not C or C.active then break end;U.wait(1) end
 -- wait until the streaming build has really finished (a partial window missed the far cells)
 do local last,stable=-1,0
  for _=1,900 do
   local n=Scene.builds or 0
   if n==last then stable=stable+1 else stable=0 end
   last=n
   if stable>=10 and (Scene.cacheHits or 0)>(Scene.builds or 0) then break end
   U.wait(10)
  end
  print('[EM fill] builds',Scene.builds,'hits',Scene.cacheHits)
 end
 U.wait(40)
 local def=Map.currentDef()
 local W,H=def.midLayout.width,def.midLayout.height
 local out=assert(io.open(os.getenv('EM_DUMP') or '/tmp/fill.txt','w'))
 out:write(('MAP %s window origin %d,%d map %dx%d\n'):format(id,cx,cy,W,H))
 local x0,x1,y0,y1=1e9,-1e9,1e9,-1e9
 local cells={}
 for y=-40,120 do for x=-40,120 do
  local c=Scene.debugCell(x,y)
  if c then
   local r=Scene.debugRaw(x,y) or {}
   cells[x..':'..y]={x=x,y=y,kind=c.kind,base=c.base,mid=c.mid,coll=c.collision,boundary=r.boundary,shape=r.shape and r.shape.kind,fkind=r.floor and r.floor.kind}
   if x<x0 then x0=x end;if x>x1 then x1=x end;if y<y0 then y0=y end;if y>y1 then y1=y end
  end
 end end
 out:write(('BUILT x %d..%d y %d..%d grid %dx%d\n'):format(x0,x1,y0,y1,x1-x0+1,y1-y0+1))
 -- the coarsest grid: every cell, its base height as a hex digit, outside cells marked with *
 out:write('GRID (in-map: base/8 as one hex digit, . = 0; outside the map: * + the same digit)\n')
 for y=y0,y1 do
  local row={}
  for x=x0,x1 do
   local c=cells[x..':'..y]
   local outside=(x<0 or y<0 or x>=W or y>=H)
   if not c then row[#row+1]=outside and '  .' or ' ??'
   else
    local d=math.floor((c.base or 0)/8+0.5)
    row[#row+1]=(outside and '*' or ' ')..string.format('%X',d%16)
   end
  end
  out:write(('y%3d %s\n'):format(y,table.concat(row)))
 end
 -- every outside cell that is NOT at ground level and has no cell under it: the floating plates
 out:write('FLOATING (outside cell with base>0 and a lower/absent neighbour below-south or below):\n')
 local n=0
 for y=y0,y1 do for x=x0,x1 do
  local c=cells[x..':'..y]
  local outside=(x<0 or y<0 or x>=W or y>=H)
  if c and outside and (c.base or 0)>0 then
   local under=cells[x..':'..(y+1)] -- south neighbour is nearer the camera in Emerald's rows
   out:write(('  %d,%d base=%d mid=%03X kind=%s shape=%s boundary=%s coll=%s under=%s\n'):format(x,y,c.base,c.mid or 0,tostring(c.kind),tostring(c.shape),tostring(c.boundary),tostring(c.coll),
    under and (under.base..'/'..tostring(under.kind)) or 'NONE'))
   n=n+1
  end
 end end
 out:write(('floating outside cells: %d\n'):format(n))
 -- every cell whose base stands above 40, wherever it is (fill or map), with what shape it is
 out:write('HIGH CELLS (base>40):\n')
 local hn=0
 for y=y0,y1 do for x=x0,x1 do
  local c=cells[x..':'..y]
  if c and (c.base or 0)>40 then
   out:write(('  %d,%d base=%s mid=%03X kind=%s shape=%s boundary=%s inside=%s\n'):format(x,y,tostring(c.base),c.mid or 0,
    tostring(c.kind),tostring(c.shape),tostring(c.boundary),tostring(x>=0 and y>=0 and x<W and y<H)))
   hn=hn+1
  end
 end end
 out:write(('high cells: %d\n'):format(hn))
 out:close()
 print('[EM fill] wrote',os.getenv('EM_DUMP'),'built',x0,x1,y0,y1)
 love.event.quit()
end

