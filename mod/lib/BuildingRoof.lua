local M={}
-- Corrugated house roofs: the upper two art rows are a roof, not another storey.
local profiles={general__mossdeep={
 [0x295]={wall=28,rise=16,rows=32,window=40,span=16},
 [0x361]={wall=28,rise=16,rows=32,window=48,span=16},
 [0x371]={wall=80,window=8,span=48},
}}
function M.build(m)
 local family=profiles[m.pair]
 local p=family and m.tiles and m.tiles[2] and family[m.tiles[2][3]]
 if not p then return m.quads end
 local out,q={},m.quads
 local width=(m.x1-m.x0+1)*16
 local back=0
 for i=1,#q,10 do if q[i]==2 then back=math.min(back,q[i+5]) end end
 local function put(f,x0,x1,h0,h1,z0,z1,px,py,shade)
  for _,v in ipairs({f,x0,x1,h0,h1,z0,z1,px,py,shade or 0})do out[#out+1]=v end
 end
 for i=1,#q,10 do
  local f,x0,x1,h0,h1,z0,z1,px,py,shade=unpack(q,i,i+9)
  if not p.rise or h0<p.wall then
   if p.rise then h1=math.min(h1,p.wall) end
   if f==2 and h1<=p.wall then
    for x=x0,x1-1 do for h=h0,h1-1 do
     put(f,x,x+1,h,h+1,z0,z1,p.window+x%p.span,(m.y1-m.y0+1)*16-1-h)
    end end
   else put(f,x0,x1,h0,h1,z0,z1,px,py,shade) end
  end
 end
 if not p.rise then return out end
 local function height(z)return p.wall+math.floor(p.rise*math.min(-z,z-back)/(-back/2)+.5) end
 for z=back,-1 do
  local h=height(z+.5)
  local py=math.max(0,math.min(p.rows-1,p.rows-1-(h-p.wall)-math.floor(math.min(-z-1,z-back))))
  for x=0,width-1 do put(3,x,x+1,h,h,z,z+1,x,py) end
  for _,f in ipairs({4,5})do
   local x=f==4 and width or 0
   for y=p.wall,h-1 do put(f,x,x,y,y+1,z,z+1,f==4 and width-1 or 0,p.rows-1-(y-p.wall)) end
  end
  for _,d in ipairs({-1,1})do
   local nh=(z+d<back or z+d>=0) and p.wall or height(z+d+.5)
   if h>nh then for x=0,width-1 do
    put(d==1 and 1 or 2,x,x+1,nh,h,d==1 and z+1 or z,d==1 and z+1 or z,x,py)
   end end
  end
 end
 return out
end
return M
