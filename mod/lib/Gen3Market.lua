-- Slateport's merchandise: round baskets, with the original rim and contents on top.
local V=...
local M={}
M.pots={[0x20C]=true,[0x21B]=true,[0x21C]=true,[0x22B]=true,[0x223]=true,[0x28E]=true}
M.goods={[0x20B]=6,[0x28D]=6,[0x213]=4,[0x214]=4,[0x344]=5}
function M.shape(x,y,mid)
 if x<2 or x>13 or y<33 or y>56 then return end
 if mid==0x366 then return {kind='marketSign',ground=0x211,reviewedSurface=true,noFurniture=true} end
 if M.pots[mid] then return {kind='marketPot',ground=0x211,reviewedSurface=true,noFurniture=true} end
 if M.goods[mid] then return {kind='extrude',h=M.goods[mid],ground=0x211,maskGround=0x211,reviewedSurface=true,noFurniture=true} end
end
function M.append(c,quad,uvFor)
 local t=uvFor(c.ts,c.mid);if not t then return end
 local function uv(x,y)
  return {t[1][1]+(t[2][1]-t[1][1])*x/16,t[1][2]+(t[3][2]-t[1][2])*y/16}
 end
 local body=uvFor(c.ts,0x20C) or t
 local function pixel(x,y)
  local p={body[1][1]+(body[2][1]-body[1][1])*(x+.5)/16,
   body[1][2]+(body[3][2]-body[1][2])*(y+.5)/16}
  return {p,p,p,p}
 end
 local X,Z=c.cx*16+8,c.cy*16+8
 local N=24
 -- Broad shoulder and narrow foot, not an extrusion of the entire floor tile.
 local profile={{0,4.5},{2,5.5},{7,6.5},{9,6},{10,6.5},{11,6.5}}
 for j=1,#profile-1 do
  local a,b=profile[j],profile[j+1]
  for k=0,N-1 do
   local p,q=k*2*math.pi/N,(k+1)*2*math.pi/N
   local row=math.max(10,13-math.floor(a[1]*.3))
   quad({{X+a[2]*math.sin(p),a[1],Z+a[2]*math.cos(p)},
    {X+a[2]*math.sin(q),a[1],Z+a[2]*math.cos(q)},
    {X+b[2]*math.sin(q),b[1],Z+b[2]*math.cos(q)},
    {X+b[2]*math.sin(p),b[1],Z+b[2]*math.cos(p)}},
    pixel(math.max(3,math.min(12,math.floor(8+4*math.sin((p+q)/2)))),row),.82+.12*math.cos((p+q)/2))
  end
 end
 -- Unstretch the source ellipse into a circular mouth. The dark interior of
 -- empty pots and the distinct green/orange/red goods come from the same art.
 local contents=(c.mid==0x20C or c.mid==0x28E) and 8 or 10.7
 for k=0,N-1 do
  local a,b=k*2*math.pi/N,(k+1)*2*math.pi/N
  local sa,ca,sb,cb=math.sin(a),math.cos(a),math.sin(b),math.cos(b)
  quad({{X,contents,Z},{X+6.5*sa,11,Z+6.5*ca},{X+6.5*sb,11,Z+6.5*cb},{X,contents,Z}},
   {uv(7.5,4),uv(7.5+4.5*sa,4+3.5*ca),uv(7.5+4.5*sb,4+3.5*cb),uv(7.5,4)},1)
 end
end
function M.sign(c,cells,quad,uvFor)
 V.require('Gen3Fence').extrude(c,cells,function(p,t,s)
  for _,v in ipairs(p)do local y,z=v[2],v[3]-c.cy*16;v[2]=16-z;v[3]=c.cy*16+8+y end
  quad(p,t,s)
 end,uvFor,2,nil,nil,0x211)
end
return M
