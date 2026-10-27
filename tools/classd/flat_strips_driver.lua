-- tools/classd (task 21): relief cells that stand no higher than the walkable ground beside them (the counted level = the floor).
-- EM_SPOTS="MAP,x,y;MAP,x,y" EM_TOL=<px, default 3>. Prints [FS] map cx cy mid minH maxH ground wmids(neighbour flat-run).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=ex.lib.require('Gen3Scene')
 local Map=require('src.core.game3.map')
 local tol=tonumber(os.getenv('EM_TOL') or 3)
 local seen={}
 for spec in (os.getenv('EM_SPOTS') or ''):gmatch('[^;]+')do
  local id,x,y=spec:match('([^,]+),(%d+),(%d+)')
  Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(300)
  local def=Map.currentDef();local W,H=def.midLayout.width,def.midLayout.height
  for cy=0,H-1 do for cx=0,W-1 do
   local k=id..':'..cx..':'..cy
   local c=not seen[k] and Scene.debugRaw(cx,cy)
   local R=c and c.mass and c.mass.reliefData;local h=R and R.H[c]
   if h then
    seen[k]=true
    local mn,mx=1e9,-1e9;for i=1,25 do mn=math.min(mn,h[i]);mx=math.max(mx,h[i])end
    local g={}
    for dx=-1,1 do for dy=-1,1 do local n=Scene.debugRaw(cx+dx,cy+dy)
     if n and (dx~=0 or dy~=0) and (n.collision or 0)==0 and not (n.mass and n.mass.reliefData and n.mass.reliefData.H[n]) then g[#g+1]=Scene.groundAt((cx+dx)*16+8,(cy+dy)*16+8)end end end
    table.sort(g)
    local ground=g[1] and g[math.floor((#g+1)/2)]
    if ground and mx<=ground+tol and mn>=ground-8 then
     print(string.format('[FS] %s %d %d %03X %.0f %.0f %.0f',id,cx,cy,c.mid or 0,mn,mx,ground))
    end
   end
  end end
 end
 love.event.quit()
end
