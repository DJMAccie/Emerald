local M={}
local function finite(n,lo,hi)return type(n)=='number' and n==n and n>=lo and n<=hi end
local function vec(v)
 if type(v)~='table' then return nil end
 local r={};for i=1,3 do if not finite(v[i],-1048576,1048576)then return nil end;r[i]=v[i]end
 return r
end
local function normal(v)
 local l=math.sqrt(v[1]^2+v[2]^2+v[3]^2);if l<1e-8 then return nil end
 return {v[1]/l,v[2]/l,v[3]/l}
end
local function cross(a,b)return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
function M.build(eye,focus,up,near,far,fov,mode)
 eye,focus,up=vec(eye),vec(focus),vec(up)
 if not eye or not focus or not up or not finite(near,.001,1048576)or not finite(far,near+.001,1048576)or not finite(fov,.001,math.pi-.001)then return nil end
 if mode~='first_person' and mode~='third_person' and mode~='diorama'then return nil end
 local forward=normal({focus[1]-eye[1],focus[2]-eye[2],focus[3]-eye[3]});if not forward then return nil end
 local right=normal(cross(forward,up));if not right then return nil end
 local vertical=normal(cross(right,forward));if not vertical then return nil end
 return {eye=eye,focus=focus,forward=forward,right=right,up=vertical,near=near,far=far,fov=fov,mode=mode,overhead=mode~='diorama'}
end
return M
