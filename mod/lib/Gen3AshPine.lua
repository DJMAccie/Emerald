-- Mt
local V=...
local M={}
local P=V.require('Gen3TreeStamps').PINE.lavaridge
M.FOOT={};for _,mid in ipairs(P.foot)do M.FOOT[mid]=true end
M.TOP=P.tip -- the crown's top drawn over bare ground
M.CROWN=P.crown -- full crown art
M.BASE=P.base -- crown bottom and shadow
M.GROUND=P.ground
M.FOOT_ROW=12 -- the shadow's centre in the foot cell
M.CROWN_ROWS=6 -- the crown's last row in the foot cell (rows 0..6)
M.DEPTH=.8 -- ring depth as a share of its width
M.RISE=2
M.TRUNK=10
M.TIP=.5

local function composite(ts,slot,x,y)
 local X,Y=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
 local r,g,b=ts.imageData:getPixel(X,Y)
 if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(X,Y)
  if aa>0 then r,g,b=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa) end end
 return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
end
local function outline(ts)
 if ts.ashOutline2 then return ts.ashOutline2 end
 local out={}
 local top,base,gr=ts.midToSlot[M.TOP],ts.midToSlot[M.BASE],ts.midToSlot[M.GROUND]
 if top and base and gr then
  local ground={}
  for y=0,15 do for x=0,15 do ground[composite(ts,gr,x,y)]=true end end
  local function span(slot,y)
   local l,r
   for x=0,15 do if not ground[composite(ts,slot,x,y)] then l=l or x;r=x end end
   return l and {l,r} or false
  end
  for y=1,15 do out[#out+1]={slot=M.CROWN,row=y,span=span(top,y)} end
  for y=0,M.CROWN_ROWS do out[#out+1]={slot=M.BASE,row=y,span=span(base,y)} end
 end
 ts.ashOutline2=out
 return out
end

function M.is(c)
 return c and c.pair=='general__lavaridge' and M.FOOT[c.mid] and (c.collision or 0)~=0 or false
end

function M.append(c,quad,uvFor)
 local rows=outline(c.ts)
 if #rows==0 then return end
 local x0=c.cx*16
 local zf=c.cy*16+M.FOOT_ROW -- the crown's front depth
 local function rowUv(mid,y,l,r)
  local t=uvFor(c.ts,mid);if not t then return end
  local L,T,R,B=t[1][1],t[1][2],t[3][1],t[3][2]
  local u0,u1=L+(R-L)*l/16,L+(R-L)*(r+1)/16
  local v0,v1=T+(B-T)*y/16,T+(B-T)*(y+1)/16
  return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
 end
 local maxW=0
 for _,q in ipairs(rows)do if q.span then maxW=math.max(maxW,q.span[2]-q.span[1]+1) end end
 local zc=zf-maxW*M.DEPTH/2 -- the crown's axis
 local N=#rows
 local prev
 for k,q in ipairs(rows)do
  local s=q.span
  if s then
   local h1=M.TRUNK+(N-k+1)*M.RISE;local h0=h1-M.RISE
   local l,r=s[1],s[2]
   local w=r-l+1
   local f=1
   local top=N*.55
   if k<top then f=math.sqrt(math.max(.12,1-((top-k)/top)^2)) end
   if k>N-4 then f=math.min(f,.7+.3*(N-k)/4) end
   local wt=w*(M.TIP+(1-M.TIP)*(k-1)/math.max(1,N-1))
   local d=math.max(1,wt*M.DEPTH/2*f)
   local xc=x0+(l+r+1)/2
   local xa,xb=xc-wt/2,xc+wt/2
   local za,zb=zc-d,zc+d
   local cut=math.min(wt,2*d)*.29 -- an octagon, not a box
   local t=rowUv(q.slot,q.row,l,r)
   if t then
    local function U(x)return t[1][1]+(t[2][1]-t[1][1])*(x-xa)/wt end
    local v0,v1=t[1][2],t[3][2]
    local function band(xL,zL,xR,zR,uL,uR,shade)
     quad({{xL,h1,zL},{xR,h1,zR},{xR,h0,zR},{xL,h0,zL}},{{uL,v0},{uR,v0},{uR,v1},{uL,v1}},shade)
    end
    band(xa,zb-cut,xa+cut,zb,U(xa),U(xa+cut),.8)
    band(xa+cut,zb,xb-cut,zb,U(xa+cut),U(xb-cut),.9)
    band(xb-cut,zb,xb,zb-cut,U(xb-cut),U(xb),.84)
    band(xb,zb-cut,xb,za+cut,U(xb-.5),U(xb-.5),.76)
    band(xb,za+cut,xb-cut,za,U(xb),U(xb-cut),.7)
    band(xb-cut,za,xa+cut,za,U(xb-cut),U(xa+cut),.64)
    band(xa+cut,za,xa,za+cut,U(xa+cut),U(xa),.68)
    band(xa,za+cut,xa,zb-cut,U(xa+.5),U(xa+.5),.72)
    local function cap(pts)
     local uv={}
     for i,p in ipairs(pts)do uv[i]={U(math.max(xa,math.min(xb,p[1]))),(v0+v1)/2} end
     quad(pts,uv,1)
    end
    cap({{xa+cut,h1,za},{xb-cut,h1,za},{xb-cut,h1,zb},{xa+cut,h1,zb}})
    cap({{xa,h1,za+cut},{xa+cut,h1,za},{xa+cut,h1,zb},{xa,h1,zb-cut}})
    cap({{xb-cut,h1,za},{xb,h1,za+cut},{xb,h1,zb-cut},{xb-cut,h1,zb}})
   end
   prev={l,r,d,h0}
  end
 end
 if prev then
  local bottom=prev[4]
  local m=math.floor((prev[1]+prev[2])/2)
  local t=rowUv(M.BASE,M.CROWN_ROWS,m,m)
  if t then
   local pxa,pxb,pza,pzb=x0+prev[1],x0+prev[2]+1,zc-prev[3],zc+prev[3]
   quad({{pxa,bottom,pzb},{pxb,bottom,pzb},{pxb,bottom,pza},{pxa,bottom,pza}},t,.5)
  end
  local tr=rowUv(M.BASE,10,7,8)
  if tr and bottom>0 then
   local a,b=x0+6.5,x0+9.5
   local c0,c1=zc-1.5,zc+1.5
   quad({{a,bottom,c1},{b,bottom,c1},{b,0,c1},{a,0,c1}},tr,.8)
   quad({{b,bottom,c0},{a,bottom,c0},{a,0,c0},{b,0,c0}},tr,.6)
   quad({{a,bottom,c0},{a,bottom,c1},{a,0,c1},{a,0,c0}},tr,.7)
   quad({{b,bottom,c1},{b,bottom,c0},{b,0,c0},{b,0,c1}},tr,.7)
  end
 end
end
return M
