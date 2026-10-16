-- POKEPORT_DRIVER: attribution harness. The driver can write files, the game cannot, so this asks
-- Gen3Scene for the per-cell geometry statistics of the probe box cells and writes them out, then
-- draws a magenta outline on the ground of every one of those cells so the shot can be matched to
-- world coordinates.
--   EM_MAP EM_CX EM_CY EM_LEVEL EM_YAW EM_BOX="x0,x1,z0,z1" EM_DUMP=<out.txt> EM_SHOT=<dir>
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
 local cx,cy=tonumber(os.getenv('EM_CX') or 6),tonumber(os.getenv('EM_CY') or 45)
 if C then C.setLevel(tonumber(os.getenv('EM_LEVEL') or 7),game);C.yaw=tonumber(os.getenv('EM_YAW') or 1.6) end
 Map.load(nil,game,id,{x=cx,y=cy,facing='down'})
 U.wait(tonumber(os.getenv('EM_WAIT') or 400))
 for _=1,900 do if not C or C.active then break end;U.wait(1) end
 do local last,stable=-1,0
  for _=1,900 do
   local n=Scene.builds or 0
   if n==last then stable=stable+1 else stable=0 end
   last=n
   if stable>=10 and (Scene.cacheHits or 0)>(Scene.builds or 0) then break end
   U.wait(10)
  end
 end
 local out=assert(io.open(os.getenv('EM_DUMP') or '/tmp/attrib.txt','w'))
 local box={}
 for n in tostring(os.getenv('EM_BOX') or '-40,40,0,90'):gmatch('[^,]+')do box[#box+1]=tonumber(n)end
 local x0,x1,z0,z1=box[1],box[2],box[3],box[4]
 out:write(('MAP %s probe box world x %d..%d z %d..%d (cells %d..%d, %d..%d)\n'):format(id,x0,x1,z0,z1,
  math.floor(x0/16),math.ceil(x1/16)-1,math.floor(z0/16),math.ceil(z1/16)-1))
 -- NOTE: the per-cell geometry statistics printed below need the temporary stdout logger described in
 -- skills/emerald-terrain/SKILL.md (Lessons: the game process cannot write outside its save dir).
 -- the map's own cell (0,0) in world cells: the scene's cells and stats are keyed world-absolute
 local wox,woy=0,0
 do local reg=Scene.debugRegions and Scene.debugRegions() or nil
    if reg and reg[1] then wox,woy=reg[1].x or 0,reg[1].y or 0 end end
 print('[EM attrib] region origin',wox,woy)
 local n=0
 for cy2=math.floor(z0/16),math.ceil(z1/16)-1 do
  for cx2=math.floor(x0/16),math.ceil(x1/16)-1 do
   local c=Scene.debugRaw(cx2,cy2)
   if c then
    local s=nil
    out:write(('CELL %d %d mid=%03X kind=%s base=%s bnd=%s floorH=%s ground=%s wood=%s leaf=%s\n'):format(
      cx2,cy2,c.mid or 0,tostring(c.shape and c.shape.kind),tostring(c.base),tostring(c.boundary),
      tostring(c.floor and c.floor.height),
      s and ('%s..%s/%s'):format(s.glo,s.ghi,s.gn) or '-',
      s and ('%s..%s/%s'):format(s.wlo,s.whi,s.wn) or '-',
      s and ('%s..%s/%s'):format(s.flo,s.fhi,s.fn) or '-'))
    n=n+1
   end
  end
 end
 out:write(('cells in box: %d\n'):format(n))
 out:close()
 print('[EM attrib] wrote',os.getenv('EM_DUMP'),'cells',n)
 local path=(os.getenv('EM_SHOT') or '/tmp')..'/'..id..'_attrib.png'
 U.wait(20)
 U.shot(game,path)
 print('[EM attrib] shot',path)
 love.event.quit()
end
