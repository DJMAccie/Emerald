-- Scenery options: rocks & plants, textures
local V=...
local M={}
M.props=V.require('ModSetting').new('sceneryProps','ROCKS & PLANTS',
 {'modeled','cards'},{'3D MODELS','2.5D SPRITES'},1)
M.surfaces=V.require('ModSetting').new('surfaceArtwork','SCENERY TEXTURES',
 {'original','detailed'},{'ORIGINAL GAME','DETAILED'},1)
function M.changed(key)
 if key~=M.surfaces.key and key~=M.props.key then return end
 if V.require('Generation').isGen3() then V.require('Gen3Scene').invalidate()
 else V.require('CommunityVisuals').invalidate() end
end
local function wrapSetting(setting)
local row=setting.row
function setting:row()
 local r=row(self);local step=r.step
 r.step=function(game,dir)local result=step(game,dir);M.changed(self.key);return result end
 return r
end
end
wrapSetting(M.surfaces);wrapSetting(M.props)
return M
