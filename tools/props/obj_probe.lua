-- POKEPORT_DRIVER (via EM_DRIVER=...): list every overworld object on the maps in EM_CASES with its
-- graphics id, and dump each distinct sprite to SHOT_DIR/gid<N>.png. Used to find which ids are rocks.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert(love.filesystem.getIdentity()=='pokemon-love2d-rseqa','refusing a non-QA identity')
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local Objects=require('src.core.game3.objects');local S=require('src.core.game3.ow_sprites')
 local cases=dofile(os.getenv('EM_CASES'))
 local seen={}
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[PROBE] map',case[1],ok,err or '')
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   U.wait(40)
   local okL,list=pcall(function() return Objects.forDraw() end)
   for _,eo in ipairs(okL and list or {}) do
    local gid=eo.graphicsId or (eo.def and (eo.def.graphicsId or eo.def.graphics))
    print(('[PROBE] %s gid=%s cell=%s,%s'):format(case[1],tostring(gid),tostring(eo.cellX),tostring(eo.cellY)))
    if gid and not seen[gid] then
     seen[gid]=true
     local okD,d=pcall(S.getDraw,gid)
     if okD and d and d.imageData then
      local qx,qy,qw,qh=0,0,d.width,d.height
      -- raw RGBA of the whole sheet, as text (love's encode writes only inside its save directory)
      local f=io.open(('%s/gid%s.rgba'):format(dir,tostring(gid)),'w')
      if f then
       local iw,ih=d.imageData:getDimensions()
       f:write(('%d %d\n'):format(iw,ih))
       for y=0,ih-1 do local row={} for x=0,iw-1 do local r,g,b,a=d.imageData:getPixel(x,y) row[#row+1]=('%02x%02x%02x%02x'):format(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor(a*255+.5)) end f:write(table.concat(row,' '),'\n') end
       f:close()
      end
      print(('[PROBE] sprite gid=%s %sx%s'):format(tostring(gid),tostring(d.width),tostring(d.height)))
     end
    end
   end
  end
 end
 love.event.quit()
end
