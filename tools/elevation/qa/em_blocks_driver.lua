-- POKEPORT_DRIVER: the PLATEAU RULE class table of every pinned map (Gen3Elevation.field classifier) and its gates.
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>   (QA identity only; field only, no scene build)
-- Per map: `CLS map PLATEAU= FACE= MASS= WATER= DECK= OTHER= rock= unclassified= faceHigh= massNotFlat= treeFix= rockFar=`,
-- `FACEHIGH map x y h max` for a FACE standing above every non-rock cell within 4 cells, `MASSDIFF map x y h pin` for a
-- numbered rock's cell not at its number, and `GRID` rows (height in half courses, base 36; '.' no cell).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local E=lib.require('Gen3Elevation');local Pin=lib.require('Gen3PinData');local Levels=lib.require('TerrainLevels')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120)
   local def=Map.currentDef()
   if not (def and def.midLayout) then f:write('SKIP '..id..'\n') else
    local fld=E.field(def);local W,H=def.midLayout.width,def.midLayout.height
    local cnt=fld.classes or {}
    local rock,uncl,faceHigh,massDiff=0,0,0,0
    local marks={}
    for _,p in ipairs(Pin.MAPS[id] or {})do marks[p[1]..':'..p[2]]=p[3]*16 end
    for yy=0,H-1 do for xx=0,W-1 do
     local c=fld.cells[Levels.key(xx,yy)]
     if c.cls=='FACE' or c.cls=='MASS' then
      rock=rock+1
      if c.cls=='FACE' then
       local mx
       for dy=-4,4 do for dx=-4,4 do local n=fld.cells[Levels.key(xx+dx,yy+dy)]
        if n and n.cls~='FACE' and n.cls~='MASS' and n.cls~='OTHER' and n.height then mx=math.max(mx or n.height,n.height) end end end
       if mx and c.height>mx+.01 then faceHigh=faceHigh+1;f:write(('FACEHIGH %s %d %d h=%s max=%s\n'):format(id,xx,yy,tostring(c.height),tostring(mx))) end
      else
       local want=c.srcPin and marks[c.srcPin]
       if want and c.height~=want then massDiff=massDiff+1;f:write(('MASSDIFF %s %d %d h=%s pin=%s src=%s\n'):format(id,xx,yy,tostring(c.height),tostring(want),c.srcPin)) end
      end
     elseif c.cls==nil then
      local raw=def.midLayout:cellAt(xx,yy)
      if raw and raw.coll==7 then uncl=uncl+1 end
     end
    end end
    f:write(('CLS %s PLATEAU=%d FACE=%d MASS=%d WATER=%d DECK=%d OTHER=%d rock=%d unclassified=%d faceHigh=%d massNotFlat=%d treeFix=%d rockFar=%d size=%dx%d\n'):format(id,cnt.PLATEAU or -1,cnt.FACE or -1,cnt.MASS or -1,cnt.WATER or -1,cnt.DECK or -1,cnt.OTHER or -1,rock,uncl,faceHigh,massDiff,cnt.TREE_FIX or -1,cnt.ROCK_FAR or -1,W,H))
    for yy=0,H-1 do
     local row={}
     for xx=0,W-1 do local c=fld.cells[Levels.key(xx,yy)];local h=c and c.height
      row[#row+1]=h and string.sub('0123456789abcdefghijklmnopqrstuvwxyz',math.min(35,math.floor(h/8+.5))+1,math.min(35,math.floor(h/8+.5))+1) or '.' end
     f:write(('GRID %s %02d %s\n'):format(id,yy,table.concat(row)))
    end
    for yy=0,H-1 do
     local row={}
     for xx=0,W-1 do local c=fld.cells[Levels.key(xx,yy)];local k=c and c.cls
      row[#row+1]=k=='PLATEAU' and 'p' or k=='FACE' and 'F' or k=='MASS' and 'M' or k=='WATER' and '~' or k=='DECK' and 'd' or k=='OTHER' and 'o' or '?' end
     f:write(('CLSGRID %s %02d %s\n'):format(id,yy,table.concat(row)))
    end
   end
  end
 end
 f:close();love.event.quit()
end
