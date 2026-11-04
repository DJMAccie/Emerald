local Roof=dofile('lib/BuildingRoof.lua')
for _,name in ipairs({'b056_mossdeepcity_house1','b059_mossdeepcity_house2','b061_mossdeepcity_house3',
 'b062_mossdeepcity_stevenshouse','b063_mossdeepcity_house4','b065_mossdeepcity_gamecorner','b064_mossdeepcity_spacecenter'})do
 local m=dofile('data/buildings/'..name..'.lua')
 local q=Roof.build(m)
 local w,h=(m.x1-m.x0+1)*16,(m.y1-m.y0+1)*16
 local top,backs=0,0
 assert(#q%10==0)
 for i=1,#q,10 do
  assert(q[i+7]>=0 and q[i+7]<w and q[i+8]>=0 and q[i+8]<h,'surface sampled outside original art')
  assert(q[i+4]>=q[i+3],'inverted face')
  top=math.max(top,q[i+4])
  if q[i]==2 and q[i+4]<=28 then backs=backs+1;assert(q[i+7]>=8,'rear reused the front entrance') end
 end
 assert(backs>0,'missing rear wall')
 if name=='b064_mossdeepcity_spacecenter' then assert(top==176,'roof equipment lost')
 else assert(top==44,'roof became an extra storey') end
end
local other=dofile('data/buildings/pokemon_center.lua')
assert(Roof.build(other)==other.quads,'unrelated roof changed')
print('PASS house roof bounds, rear walls, source pixels and Space Center equipment')
