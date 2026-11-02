-- A camera-relative opening to each complete battler group
local M={}
function M.build(eye,arena,ground,textures)
 if not (eye and arena and arena.player and arena.enemy) then return nil end
 local out={floor=(ground or 0)+.25-eye[2]}
 for i,side in ipairs({'player','enemy'}) do
  local tex=textures and textures[side] or {}
  local k=16/56
  local width=(tex.contentWidth or 56)*k
  local height=(tex.contentHeight or 56)*k
  local p=arena[side]
  out[i]={p[1]-eye[1],(ground or 0)+height*.5-eye[2],p[2]-eye[3],
   math.max(10,width*.5,height*.5)+5}
 end
 return out
end
M.shader=[[
  uniform float battleCutOn;
  uniform float battleCutFloor;
  uniform vec4 battleCutA;
  uniform vec4 battleCutB;
  bool battleBlocked(vec3 ray, vec4 target) {
    float len = dot(target.xyz,target.xyz);
    if (len < 1.0) return false;
    float t = dot(ray,target.xyz)/len;
    if (t <= 0.0 || t >= 1.0) return false;
    float width = 3.0 + target.w*t;
    vec3 delta = ray-target.xyz*t;
    return dot(delta,delta) < width*width;
  }
]]
return M
