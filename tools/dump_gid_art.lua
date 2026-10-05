-- Dump overworld sprite art for landmark gids to stdout as hex rows.
-- The game runs sandboxed, so no filesystem write: Python rebuilds the PNG.
-- Run: POKEPORT_DRIVER=<this> POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald \
--      /Applications/gen1recomp.app/Contents/MacOS/love .   (from ~/Documents/gen1recomp)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(130)
 local S=require('src.core.game3.ow_sprites')
 local gids={94,240,6,9,17,64,215}
 for _,gid in ipairs(gids) do
  local ok,d=pcall(S.getDraw,gid)
  if not (ok and d) then
   print(('[ART] gid=%d draw=NO'):format(gid))
  else
   local iw,ih=0,0
   if d.imageData then iw,ih=d.imageData:getDimensions() end
   local nq=0 for _ in pairs(d.quads or {}) do nq=nq+1 end
   local vx,vy,vw,vh
   local q=(d.quads or {})[1]
   if q and q.getViewport then local ok2,x,y,w2,h2=pcall(function() return q:getViewport() end); if ok2 then vx,vy,vw,vh=x,y,w2,h2 end end
   if not (vw and vh) then vx,vy,vw,vh=0,0,d.width or iw,d.height or ih end
   print(('[ART] gid=%d draw=yes w=%s h=%s frames=%s quads=%s quad1=%s,%s %sx%s atlas=%sx%s inanimate=%s paletteTag=%s'):format(
    gid,tostring(d.width),tostring(d.height),tostring(d.frameCount),tostring(nq),
    tostring(vx),tostring(vy),tostring(vw),tostring(vh),tostring(iw),tostring(ih),
    tostring(d.inanimate),tostring(d.paletteTag)))
   -- dump the first frame only, hex RGB + A
   if d.imageData and vw and vh and vw*vh<=64*64 then
    print(('[ART] begin gid=%d frame=1 %dx%d'):format(gid,vw,vh))
    for y=vy,vy+vh-1 do
     local row={}
     for x=vx,vx+vw-1 do
      local r,g,b,a=d.imageData:getPixel(x,y)
      row[#row+1]=('%02X%02X%02X%02X'):format(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor(a*255+.5))
     end
     print(('[ART] px gid=%d y=%03d %s'):format(gid,y-vy,table.concat(row)))
    end
    print(('[ART] end gid=%d'):format(gid))
   end
  end
 end
 -- how the engine reports the two gid-94 events on this map
 local Objects=require('src.core.game3.objects')
 for _,eo in ipairs(Objects.forDraw()) do
  local def=eo.def
  local gid=eo.graphicsId or (def and (def.graphicsId or def.graphics))
  if tonumber(gid) and tonumber(gid)<1000 then
   print(('[ART] obj gid=%s cell=(%s,%s) px=(%s,%s) def=(%s,%s) flag=%s'):format(
    tostring(gid),tostring(eo.cellX),tostring(eo.cellY),tostring(eo.px),tostring(eo.py),
    tostring(def and def.x),tostring(def and def.y),tostring(def and def.flag)))
  end
 end
 print('[ART] done')
 love.event.quit()
end
