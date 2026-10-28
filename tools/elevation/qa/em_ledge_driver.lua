-- POKEPORT_DRIVER: hidden-ledge census of every pinned map (Gen3Elevation.field HIDDEN LEDGES pass).
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>   (QA identity only; field only, no scene build)
-- Per map: `LEDGE map edges= cells= bare= tall= steepest=` (edges = upper/lower pairs that seeded a wedge, cells = lower
-- cells carrying a wedge, bare = edges whose lower cell could not take a wedge (riser in face art), tall = edges capped at
-- LEDGE_MAX rows, steepest = the largest corner-to-corner offset of one wedge cell in px), then `LCELL map x y hl nw ne se sw`
-- per wedge cell and `BARE map x y` per bare-drop upper cell, then a `LGRID` (w = wedge cell, b = bare-drop rim, . other).
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
 local tot={edges=0,cells=0,bare=0,tall=0}
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120)
   local def=Map.currentDef()
   if not (def and def.midLayout) then f:write('SKIP '..id..'\n') else
    local fld=E.field(def);local W,H=def.midLayout.width,def.midLayout.height
    local cnt=fld.classes or {}
    local steep,cells,bare=0,0,0
    local grid={}
    for yy=0,H-1 do
     local row={}
     for xx=0,W-1 do
      local c=fld.cells[Levels.key(xx,yy)]
      local ch='.'
      if c and c.ledge then
       cells=cells+1;ch='w'
       local o=c.ledge
       local mx=math.max(o[1],o[2],o[3],o[4]);local mn=math.min(o[1],o[2],o[3],o[4])
       if mx-mn>steep then steep=mx-mn end
       f:write(('LCELL %s %d %d hl=%s nw=%.1f ne=%.1f se=%.1f sw=%.1f\n'):format(id,xx,yy,tostring(c.height),o[1],o[2],o[3],o[4]))
      elseif c and c.bareDrop then bare=bare+1;ch='b';f:write(('BARE %s %d %d h=%s\n'):format(id,xx,yy,tostring(c.height)))
      end
      row[#row+1]=ch
     end
     grid[#grid+1]=('LGRID %s %02d %s\n'):format(id,yy,table.concat(row))
    end
    f:write(('LEDGE %s edges=%d cells=%d bare=%d tall=%d steepest=%.1f\n'):format(id,cnt.LEDGE_EDGES or -1,cells,cnt.LEDGE_BARE or -1,cnt.LEDGE_TALL or -1,steep))
    for _,g in ipairs(grid)do f:write(g) end
    tot.edges=tot.edges+(cnt.LEDGE_EDGES or 0);tot.cells=tot.cells+cells;tot.bare=tot.bare+(cnt.LEDGE_BARE or 0);tot.tall=tot.tall+(cnt.LEDGE_TALL or 0)
   end
   f:flush()
  end
 end
 f:write(('TOTAL edges=%d cells=%d bare=%d tall=%d\n'):format(tot.edges,tot.cells,tot.bare,tot.tall))
 f:close();love.event.quit()
end
