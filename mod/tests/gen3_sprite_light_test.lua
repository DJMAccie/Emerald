local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local U={}
local V={}
local modules={UiBackplates=U,Gen3Battle={active=true},
 DayNight={tint=function(outdoor)return outdoor and {.5,.6,.7}or {1,1,1}end},
 Gen3Tilesets={outdoor=function(d)return d and d.mapType==1 end}}
V.require=function(k)return assert(modules[k],k)end
local draws={};local color={1,1,1,1}
local G={setColor=function(r,g,b,a)color={r,g,b,a}end,getColor=function()return unpack(color)end,
 draw=function(image,...)draws[#draws+1]={image=image,args={...},color=color}end}
love={graphics=G}
local unlit=false;U.spritesUnlit=function()return unlit end
package.loaded['src.core.game3.map']={currentDef=function()return {mapType=1}end}
local Light=assert(loadfile('lib/Gen3SpriteLight.lua'))(V);local originalDraw=G.draw
local mon,other,hud={},{},{};G.setColor(.8,.6,.4,.3)
Light.scope(function()Light.tag({image=mon});G.draw(mon,1,2);G.draw(other,3,4)end)
check(draws[1].color[1]==.4 and draws[1].color[4]==.3,'native flash/fade multiplied by world tint')
check(draws[2].color[1]==.8 and G.draw==originalDraw,'HUD colors and draw owner restored')
unlit=true;Light.scope(function()Light.tag({image=mon});G.draw(mon)end)
check(draws[3].color[1]==.8,'UNLIT restores native brightness')
check(not pcall(function()Light.scope(function()error('native error')end)end) and G.draw==originalDraw,'native error restores draw scope')
unlit=false;local P={frontPic=function()return {image=mon}end,backPic=function()return {image=other}end}
local nativeFront,nativeBack=P.frontPic,P.backPic
local UI={draw=function()G.draw(P.frontPic().image);G.draw(P.backPic().image);G.draw(hud)end}
local nativeUI=UI.draw
package.loaded['src.core.game3.pokemon']=P;package.loaded['src.core.game3.battle.ui']=UI
local undo=Light.install();draws={};UI.draw()
check(draws[1].color[1]==.4 and draws[2].color[1]==.4 and draws[3].color[1]==.8,'install tints native battler pictures only')
draws={};G.draw(P.frontPic().image);check(draws[1].color[1]==.8,'pictures outside the battle UI keep native color')
undo();check(P.frontPic==nativeFront and P.backPic==nativeBack and UI.draw==nativeUI,'uninstall restores native owners')
print('PASS '..n..' sprite-light checks')
