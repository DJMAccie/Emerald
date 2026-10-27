-- tools/classd: camera collision diagnosis. EM_MAP EM_CX EM_CY EM_LEVEL EM_YAW EM_R (cell radius): prints the camera eye + a grid of
-- cells (base, groundAt, shape kind, collision, flags) around the player. Run: EM_DRIVER=tools/classd/cam_diag_driver.lua tools/qa_tryp.sh "Gen3Scene.lua" <out> "-" 4
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local lib=ex.lib
 local Scene=lib.require('Gen3Scene');local R=lib.require('Voxel3D')
 local ns=ex.gen3 or ex.firered;local C=ns.camera
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cx,cy=tonumber(os.getenv('EM_CX')),tonumber(os.getenv('EM_CY'))
 Map.load(nil,game,os.getenv('EM_MAP'),{x=cx,y=cy,facing='down'})
 pcall(Player.reset,cx,cy,'down')
 for _,lv in ipairs({tonumber(os.getenv('EM_LEVEL') or 6),7}) do
  C.setLevel(lv,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0
  U.wait(200);for _=1,900 do if C.active then break end;U.wait(1) end;U.wait(40)
  local e=R.camera and R.camera.eye;local f=R.camera and R.camera.focus
  print('[CD cam]','level',lv,'yaw',C.yaw,'eye',e and string.format('%.1f %.1f %.1f',e[1],e[2],e[3]),'focus',f and string.format('%.1f %.1f %.1f',f[1],f[2],f[3]),'eyecell',e and math.floor(e[1]/16),e and math.floor(e[3]/16))
 end
 local raws={};for k in (os.getenv('EM_RAW') or '33:22,30:22,30:26,35:27'):gmatch('[^,]+')do raws[#raws+1]=k end
 for _,k in ipairs(raws)do local c=Scene.debugRaw(tonumber(k:match('(%d+)')),tonumber(k:match(':(%d+)')))
  if c then local t={};for kk,v in pairs(c)do t[#t+1]=kk..'='..(type(v)=='table' and 'T' or tostring(v)):sub(1,12)end;table.sort(t);print('[CD raw]',k,table.concat(t,' '))
   if c.mass then local t3={};for kk,v in pairs(c.mass)do t3[#t3+1]=kk..'='..(type(v)=='table' and ('T#'..#v) or tostring(v)):sub(1,12)end;table.sort(t3);print('[CD mass]',k,table.concat(t3,' '))end
   if c.floor then local t2={};for kk,v in pairs(c.floor)do t2[#t2+1]=kk..'='..(type(v)=='table' and 'T' or tostring(v)):sub(1,10)end;table.sort(t2);print('[CD floor]',k,table.concat(t2,' '))end end end
 local r=tonumber(os.getenv('EM_R') or 6)
 for y=cy-r,cy+r do
  local row={}
  for x=cx-r,cx+r do
   local c=Scene.debugRaw(x,y)
   if not c then row[#row+1]='  ----  '
   else row[#row+1]=string.format('%s%03X b%02d g%02d%s',c.shape and (c.shape.kind or '?'):sub(1,1) or '.',c.mid or 0,math.floor((c.base or 0)+.5),math.floor(Scene.groundAt(x*16+8,y*16+8)+.5),(c.collision or 0)~=0 and '#' or ' ')
    if c.bldModel then row[#row]=row[#row]..'B' end
    if c.column then row[#row]=row[#row]..'C' end
    if c.civic then row[#row]=row[#row]..'v' end
   end
  end
  print(string.format('[CD %3d] %s',y,table.concat(row,' | ')))
 end
 if os.getenv('EM_HGRID') then
  for y=cy-r,cy+r do
   local row={}
   for x=cx-r,cx+r do
    local c=Scene.debugRaw(x,y);local R=c and c.mass and c.mass.reliefData;local h=R and R.H[c]
    if h then local mx,mn=-1e9,1e9;for k=1,25 do mx=math.max(mx,h[k]);mn=math.min(mn,h[k])end;row[#row+1]=string.format('%3d/%3d%s',mn,mx,c.mid and string.format('(%02X)',c.mid) or '')
    else row[#row+1]='   .      ' end
   end
   print(string.format('[CD H %3d] %s',y,table.concat(row,' ')))
  end
 end
 love.event.quit()
end
