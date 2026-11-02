local Roof=assert(loadfile('lib/Gen3RoofDetails.lua'))()
local c={roofType='flat',height=32,back=0,front=80,roofs=3,roofInset=12}
for z=20,80 do assert(Roof.height(c,z)==32,'lab roof acquired a pitch')end
c.roofType='gable';c.roofInset=0
assert(Roof.height(c,0)==32 and Roof.height(c,40)==45 and Roof.height(c,80)==32)
assert(Roof.height(c,20)==38.5,'gable was rounded into a barrel')
local col={height=32,front=80,back=0,roofType='flat',roofInset=12,roofs=3}
local shell={['0:0']={cx=0,cy=0,pair='pallet',column=col},['1:0']={cx=1,cy=0,pair='pallet',column=col}}
assert(not Roof.sideVisible(shell,shell['0:0'],1),'internal wall fin survives')
assert(Roof.sideVisible(shell,shell['0:0'],-1),'outer wall disappeared')
shell['1:0'].column={height=48}
assert(Roof.sideVisible(shell,shell['0:0'],1),'stepped building side left open')
print('PASS flat lab, straight gables')
