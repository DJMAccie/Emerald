-- POKEPORT_DRIVER: the floor field of every pinned map against the user's marks.
--   EM_MAPS=<file with "MAP x y" lines (any spot on the map)> EM_DUMP=<out.txt>
-- Writes per map: `PIN map x y want got group-cells kind` per mark, `GRID` rows (field height in half-courses, base 36,
-- '.' no floor cell), and a count line. QA identity only. Needs Gen3PinData in the lib (qa_tryp FILES).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local E=lib.require('Gen3Elevation');local Pin=lib.require('Gen3PinData')
 if os.getenv('EM_NOPINS') then E.PINS_ON=false end   -- the field the game had before the pins (rated nibble + stair platforms)
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120)
   local def=Map.currentDef()
   if not (def and def.midLayout) then f:write('SKIP '..id..'\n') else
    local fld=E.field(def);local W,H=def.midLayout.width,def.midLayout.height
    local Levels=lib.require('TerrainLevels')
    local ok,bad=0,0
    for _,p in ipairs(Pin.MAPS[id] or {})do
     local c=fld.cells[Levels.key(p[1],p[2])]
     local got=c and c.height;local want=p[3]*16
     local kind=c and (c.floor and (c.kind or 'floor') or 'blocked') or 'none'
     if got==want then ok=ok+1 else bad=bad+1 end
     f:write(('PIN %s %d %d want=%d got=%s group=%s kind=%s %s\n'):format(id,p[1],p[2],want,tostring(got),tostring(c and c.group and #c.group.cells),kind,got==want and 'ok' or 'DIFF'))
    end
    f:write(('COUNT %s ok=%d diff=%d size=%dx%d\n'):format(id,ok,bad,W,H))
    for y=0,H-1 do
     local row={}
     for x=0,W-1 do local c=fld.cells[Levels.key(x,y)];local h=c and c.height
      row[#row+1]=h and string.sub('0123456789abcdefghijklmnopqrstuvwxyz',math.min(35,math.floor(h/8+.5))+1,math.min(35,math.floor(h/8+.5))+1) or '.' end
     f:write(('GRID %s %02d %s\n'):format(id,y,table.concat(row)))
    end
   end
  end
 end
 f:close();love.event.quit()
end
