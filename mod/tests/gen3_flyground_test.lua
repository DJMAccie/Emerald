-- Gen3FlyGround: the world fill's cell lookup (run from the mod root: luajit tests/gen3_flyground_test.lua).
local V
V={require=function(name)
 if name=='Voxel3D' or name=='Mat4' then return {} end
 return assert(loadfile('lib/'..name..'.lua'))(V)
end}
local G=V.require('Gen3FlyGround')
-- a 3x2 fill at (-1,5): codes are (pair index + 1) << 10 | metatile, 0 = open sea or a map
local codes={0,(1*1024)+0x1D4,(2*1024)+0x208, 0,0,(1*1024)+0x1DD}
local bytes={}
for i,c in ipairs(codes)do bytes[#bytes+1]=string.char(c%256,math.floor(c/256))end
local F={ox=-1,oy=5,W=3,H=2,pairs={'general__petalburg','general__lavaridge'},cells=table.concat(bytes),place={}}
local function eq(a,b,msg)assert(a==b,msg..': '..tostring(a)..' vs '..tostring(b))end
eq(G.fillAt(F,-1,5),nil,'sea is nil')
local p,m=G.fillAt(F,0,5);eq(p,'general__petalburg','pair');eq(m,0x1D4,'tree')
p,m=G.fillAt(F,1,5);eq(p,'general__lavaridge','second pair');eq(m,0x208,'rock')
p,m=G.fillAt(F,1,6);eq(m,0x1DD,'second row')
eq(G.fillAt(F,2,5),nil,'east of the grid');eq(G.fillAt(F,0,4),nil,'north of the grid');eq(G.fillAt(F,-2,6),nil,'west of the grid')
print('gen3_flyground_test: PASS')
