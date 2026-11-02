-- Gen3CamClear: the orbit arm stops short of solid tops (run from the mod root: luajit tests/gen3_camclear_test.lua).
local V
V={require=function(name) return assert(loadfile('lib/'..name..'.lua'))(V) end}
local C=V.require('Gen3CamClear')
local function eq(a,b,msg)assert(a==b,(msg or '')..': '..tostring(a)..' vs '..tostring(b))end

-- empty field: the arm is whole
local g=C.new()
eq(C.arm(g,100,100,0,1,48,75),75,'nothing solid')
-- a quad list the way Gen3Scene builds it: one 16x16 floor quad at y=48 over x 160..176, z 0..16, plus a riser
local v,i={},{}
local function quad(p)local b=#v;for k=1,4 do v[b+k]={p[k][1],p[k][2],p[k][3],0,0,1}end;local n=#i;i[n+1],i[n+2],i[n+3],i[n+4],i[n+5],i[n+6]=b+1,b+2,b+3,b+1,b+3,b+4 end
quad({{160,48,0},{176,48,0},{176,48,16},{160,48,16}})
quad({{160,0,16},{176,0,16},{176,48,16},{160,48,16}})   -- upright: no extent over the ground in z
quad({{0,2,0},{16,2,0},{16,2,16},{0,2,16}})             -- ground-level top: left out
quad({{64,0,0},{72,0,0},{72,40,8},{64,40,8}})            -- a ramp whose far corner is at 40: its fourth vertex counts
C.addQuads(g,v,i)
eq(g.n,5,'a 16x16 top covers four 8-unit cells, the ramp one (the riser and the ground quad add none)')
eq(C.topAt(g,68,4),20,'the ramp reads its mean height')
eq(C.topAt(g,168,8),48,'top over the plate');eq(C.topAt(g,8,8),0,'level ground reads 0');eq(C.topAt(g,200,8),0,'beside the plate')
-- an eye at 48 walking north->south: arm along +z from z=100 back (dz=-1 puts the eye at z+?) ; here the eye goes -x from x=260 towards the plate
local arm=C.arm(g,260,8,-1,0,48,120)   -- eye x = 260 - dx*t = 260+t: away from the plate
eq(arm,120,'arm away from the plate is clear')
arm=C.arm(g,260,8,1,0,48,120)          -- eye x = 260 - t: reaches x=176 at t=84 (the plate edge)
assert(arm<84 and arm>=84-C.BACK-C.STEP,'the arm stops before the plate: '..arm)
-- an eye high over the plate is clear
eq(C.arm(g,260,8,1,0,96,120),120,'eye over the plate')
-- a plate the player already stands on (the start cell) with the eye 48 over it is clear
eq(C.arm(g,168,8,1,0,48+48,75),75,'standing on the plate')
-- a building model: top faces only
local g2=C.new()
C.addModel(g2,{3,0,32,40,40,-32,0,1,1,100, 1,0,32,0,40,0,0,1,1,90},100,0,200)   -- a top at height 40 over x 100..132, z 168..200; a south wall
eq(C.topAt(g2,116,184),40,'model top');eq(C.topAt(g2,116,150),0,'outside');eq(g2.n,20,'5x4 cells')
-- deck vertex ranges are left out
local g3=C.new();C.addQuads(g3,v,i,{{0,0,1,4}});eq(C.topAt(g3,168,8),0,'a skipped range adds nothing')
-- ease: shorter at once, longer slowly, a new key resets
local st={}
eq(C.ease(st,75,.016,90,'a'),75,'first value')
eq(C.ease(st,20,.016,90,'a'),20,'shorter at once')
assert(math.abs(C.ease(st,75,.1,90,'a')-29)<1e-9,'grows 9 units in .1 s')
eq(C.ease(st,60,.016,90,'b'),60,'a new scene starts at the wanted arm')
print('gen3_camclear_test ok')
