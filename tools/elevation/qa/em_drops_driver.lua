-- POKEPORT_DRIVER: bare drops = two PLATEAU floor cells side by side at different heights with no band, stair or ledge between.
--   EM_MAPS=<file "MAP x y" lines> EM_DUMP=<out.txt>  (QA identity only)
-- One line per edge: DROP map ux uy nx ny dir hu hl kindU kindN midU midN elevU elevN collU collN zoneU zoneN marksU marksN sizeU sizeN flagU flagN (X = ground lifted by RAMP_EXT, r = other relief)
--   (u = the higher cell, n = the lower; dir = direction from u to n; marks = the user's marks inside the cell's same-height
--   plateau region, "x,y=h" up to 3, else the nearest mark by Manhattan distance prefixed ~)
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
 local dirs={{1,0,'E'},{-1,0,'W'},{0,1,'S'},{0,-1,'N'}}
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id=line:match('^(%S+)')
  if id then
   Map.load(nil,game,id,{x=5,y=5,facing='down'});U.wait(120)
   local def=Map.currentDef()
   if def and def.midLayout then
    local l=def.midLayout;local W,H=l.width,l.height
    local fld=E.field(def)
    local marks=Pin.MAPS[id] or {}
    local function C(x,y)return fld.cells[Levels.key(x,y)] end
    local function plateau(c)return c and c.cls=='PLATEAU' and c.floor and not c.step and c.kind~='water' and c.height end
    local function regionMarks(x,y)
     local h=C(x,y).height;local seen={[x..':'..y]=true};local q={{x,y}};local head=1;local out={}
     local byCell={}
     for _,m in ipairs(marks)do byCell[m[1]..':'..m[2]]=m end
     while head<=#q and head<=600 do
      local p=q[head];head=head+1
      local m=byCell[p[1]..':'..p[2]];if m and m[3]*16==h then out[#out+1]=m[1]..','..m[2]..'='..m[3] end
      for _,d in ipairs(dirs)do
       local nx,ny=p[1]+d[1],p[2]+d[2];local k=nx..':'..ny
       if not seen[k] then local c=C(nx,ny)
        if c and plateau(c) and c.height==h then seen[k]=true;q[#q+1]={nx,ny} end end
      end
     end
     if #out==0 then
      local best,bd
      for _,m in ipairs(marks)do local d=math.abs(m[1]-x)+math.abs(m[2]-y);if m[3]*16==h and (not bd or d<bd)then best,bd=m,d end end
      return best and ('~'..best[1]..','..best[2]..'='..best[3]) or '-'
     end
     return table.concat(out,'|',1,math.min(3,#out))
    end
    local szc={}
    local function size(x,y)
     local k=x..':'..y;if szc[k] then return szc[k] end
     local h=C(x,y).height;local seen={[k]=true};local q={{x,y}};local head=1
     while head<=#q and head<=4000 do
      local p=q[head];head=head+1
      for _,d in ipairs(dirs)do
       local nx,ny=p[1]+d[1],p[2]+d[2];local kk=nx..':'..ny
       if not seen[kk] then local c=C(nx,ny);if c and plateau(c) and c.height==h then seen[kk]=true;q[#q+1]={nx,ny} end end
      end
     end
     for kk in pairs(seen)do szc[kk]=#q end
     return #q
    end
    local cache={}
    local function rm(x,y)local k=x..':'..y;if not cache[k] then cache[k]=regionMarks(x,y) end;return cache[k] end
    local n=0
    for y=0,H-1 do for x=0,W-1 do
     local u=C(x,y)
     if plateau(u) then
      for _,d in ipairs(dirs)do
       local nx,ny=x+d[1],y+d[2]
       local v=C(nx,ny)
       if plateau(v) and u.height-v.height>=8 then
        local a,b=l:cellAt(x,y),l:cellAt(nx,ny)
        f:write(('DROP %s %d %d %d %d %s %s %s %s %s %03X %03X %s %s %s %s %s %s %s %s %d %d %s %s\n'):format(id,x,y,nx,ny,d[3],string.format('%g',u.height/16),string.format('%g',v.height/16),tostring(u.kind),tostring(v.kind),
         a and a.mid or 0,b and b.mid or 0,tostring(a and a.elev),tostring(b and b.elev),tostring(a and a.coll),tostring(b and b.coll),tostring(u.zone),tostring(v.zone),rm(x,y),rm(nx,ny),size(x,y),size(nx,ny),(u.rampExt and 'X' or (u.relief and 'r' or '-')),(v.rampExt and 'X' or (v.relief and 'r' or '-'))))
        n=n+1
       end
      end
     end
    end end
    f:write(('COUNT %s %d\n'):format(id,n));f:flush()
   end
  end
 end
 f:close();love.event.quit()
end
