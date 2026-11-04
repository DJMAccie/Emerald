local V=dofile('tests/modload.lua').namespace()
local S=V.require('Gen3EmeraldShapes')
for _,mid in ipairs({0x31A,0x31B,0x31C,0x31D,0x31E,0x31F,0x322,0x323,0x324,0x325,0x326,0x327,0x355,0x356})do
 local s=S.of('general','mossdeep',mid,0,7)
 assert(s.kind=='tree','tree fragment became rock or a shrub')
 assert(#s.art==2 and #s.art[1]==2,'overlapping crown did not get a complete tree')
end
local count=0
for _,mid in ipairs({0x31A,0x31B,0x31A,0x31B,0x355,0x356})do
 local s=S.of('general','mossdeep',mid,0,7)
 if s.root then count=count+1;assert(s.anchorX==16 and s.anchorZ==31) end
end
assert(count==3,'overlapping crowns were merged or emitted twice')
print('PASS coastal tree classification and overlapping crown placement')
