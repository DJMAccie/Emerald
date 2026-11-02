-- Native actors stay on the UI plane
local V=...
local M={}
local images
function M.tag(entry)
 if images and entry and entry.image then images[entry.image]=true end
 return entry
end
function M.scope(draw,...)
 local oldImages=images;images={}
 local G=love.graphics;local old=G.draw
 local stage=V.require('Gen3Battle')
 local UI=V.require('UiBackplates')
 G.draw=function(image,...)
  if images[image] and stage.active and not UI.spritesUnlit()then
   local Map=require('src.core.game3.map')
   local tint=V.require('DayNight').tint(V.require('Gen3Tilesets').outdoor(Map.currentDef()))
   local r,g,b,a=G.getColor();G.setColor(r*tint[1],g*tint[2],b*tint[3],a)
   local result={pcall(old,image,...)};G.setColor(r,g,b,a)
   if not result[1]then error(result[2],0)end
   return unpack(result,2)
  end
  return old(image,...)
 end
 local result={pcall(draw,...)}
 G.draw=old;images=oldImages
 if not result[1]then error(result[2],0)end
 return unpack(result,2)
end
-- Tag the native battler pictures while the battle UI draws, so scope can tint them.
function M.install()
 local P=require('src.core.game3.pokemon');local UI=require('src.core.game3.battle.ui')
 local draw,front,back=UI.draw,P.frontPic,P.backPic
 UI.draw=function(...)return M.scope(draw,...)end
 P.frontPic=function(...)return M.tag(front(...))end
 P.backPic=function(...)return M.tag(back(...))end
 return function()UI.draw,P.frontPic,P.backPic=draw,front,back end
end
return M
