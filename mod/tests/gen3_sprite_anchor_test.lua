local A=dofile('lib/Gen3SpriteAnchor.lua')
local pixels=0
local function quad(y)return {getViewport=function()return 0,y,16,16 end}end
local spr={quads={[0]=quad(0),[1]=quad(16),[2]=quad(32)},frameCount=3,imageData={}}
function spr.imageData:getPixel(x,y)
 pixels=pixels+1
 -- Standing bottom row13, walking row14, then an entirely blank frame.
 return 0,0,0,(x>=3 and x<=12 and(y>=5 and y<=13 or y>=21 and y<=30))and 1 or 0
end
assert(A.framePadding(spr,0)==2 and A.framePadding(spr,1)==1 and A.framePadding(spr,2)==1,'per-frame feet or blank-frame fallback wrong')
local reads=pixels;assert(A.framePadding(spr,1)==1 and pixels==reads,'sprite anchor was not cached')
assert(16-1-13-A.framePadding(spr,0)==0,'standing foot does not touch baseline')
assert(16-1-14-A.framePadding(spr,1)==0,'walking foot does not touch baseline')
assert(A.framePadding({},0)==0,'provider without CPU pixels lost native anchor')
local readsCanvas,releases=0,0
local canvas={newImageData=function()
 readsCanvas=readsCanvas+1
 return {getPixel=function(_,x,y)return 0,0,0,y==11 and 1 or 0 end,release=function()releases=releases+1 end}
end}
local provider={image=canvas,quads={[0]=quad(0)},frameCount=1}
assert(A.framePadding(provider,0)==4 and readsCanvas==1 and releases==1,'Canvas pixel snapshot missing or retained')
assert(A.framePadding(provider,0)==4 and readsCanvas==1,'Canvas snapshot repeated per draw')
provider.groundPadding=0;assert(A.framePadding(provider,0)==0,'authored zero baseline was ignored')
provider.groundPadding=2;assert(A.framePadding(provider,0)==2,'masked provider did not retain original baseline')
provider.groundPadding=nil;provider.image={}
assert(A.framePadding(provider,0)==0,'replacement provider image reused stale alpha bounds')
local blank={quads={[0]=quad(0)},imageData={getPixel=function()return 0,0,0,0 end}}
assert(A.framePadding(blank,0)==0,'empty art must retain its native anchor')
-- Geometry only subtracts padding in local card space. Explicit world-space
-- jump/fly/support heights therefore survive, instead of being clamped to0.
local Mat=dofile('lib/Mat4.lua');local pad=A.framePadding(spr,1)
for _,lift in ipairs({0,4,9.12,36,96})do
 local m=Mat.mul(Mat.translate(20,lift,30),Mat.rotateX(-.4))
 local visibleY=16-1-14-pad -- lowest opaque edge of the walking frame
 local height=m[6]*visibleY+m[8]
 assert(math.abs(height-lift)<.00001,'authored jump/ride/support height changed')
end
print('PASS per-frame anchors, Canvas snapshot/cache/release, authored baselines and explicit height offsets')
