-- Slateport's dry-dock boat: the 3x2 metatiles beside the shipyard stood up as a hull on two props
local M={}
M.TEMPLATE={{0x220,0x221,0x222},{0x228,0x229,0x22A}}
M.GROUND=0x001
M.RIM=10 -- gunwale height: the near hull side is the art's rows 19-28
M.LEDGE=3 -- rim top rows (outline, highlight, outline)
M.FLOOR=1 -- the keel board the open hull's floor rests on
M.HULL_BOTTOM=28 -- the last hull row; the right prop's feet reach row 30
M.MIN=8 -- columns of the prow tip shorter than this are loose stubs, left out
M.BODY={20,19} -- one olive plank pixel for the unseen sides
-- props: x0..x1-1 columns, y0..y1-1 body rows, pz front plane (art row), they stand pz-2..pz
M.POSTS={{x0=7,x1=10,y0=18,y1=28,pz=29},{x0=35,x1=38,y0=21,y1=31,pz=31}}
local W,H=48,32

local function key(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end

-- the art as the 2D map shows it (bottom layer, top layer over it): which pixels are hull, and each pixel's texel
local function template(ts,uvFor)
 if ts.dryDock~=nil then return ts.dryDock or nil end
 ts.dryDock=false
 if not ts.imageData then return end
 local gs=ts.midToSlot[M.GROUND];if not gs then return end
 local ground={}
 for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(gs%ts.cols*16+x,math.floor(gs/ts.cols)*16+y);ground[key(r,g,b)]=true end end
 local col,uv={}, {}
 for py=0,H-1 do for px=0,W-1 do
  local mid=M.TEMPLATE[math.floor(py/16)+1][math.floor(px/16)+1]
  local sl=ts.midToSlot[mid];local t=sl and uvFor(ts,mid)
  if not t then return end
  local X,Y=sl%ts.cols*16+px%16,math.floor(sl/ts.cols)*16+py%16
  local r,g,b=ts.imageData:getPixel(X,Y)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(X,Y);if aa>.5 then r,g,b=rr,gg,bb end end
  local u=t[1][1]+(t[2][1]-t[1][1])*(px%16+.5)/16
  local v=t[1][2]+(t[3][2]-t[1][2])*(py%16+.5)/16
  col[py*W+px]=key(r,g,b);uv[py*W+px]={{u,v},{u,v},{u,v},{u,v}}
 end end
 -- the outside is the ground colours reachable from the border; whatever the outline closes in is hull
 local out,st={}, {}
 local function push(x,y)
  if x<0 or x>=W or y<0 or y>=H then return end
  local k=y*W+x
  if not out[k] and ground[col[k]] then out[k]=true;st[#st+1]=k end
 end
 for x=0,W-1 do push(x,0);push(x,H-1) end
 for y=0,H-1 do push(0,y);push(W-1,y) end
 while #st>0 do local k=table.remove(st);local x,y=k%W,math.floor(k/W);push(x+1,y);push(x-1,y);push(x,y+1);push(x,y-1) end
 local hull,first,last={}, {}, {}
 for px=0,W-1 do for py=0,H-1 do
  local k=py*W+px
  if not out[k] then hull[k]=true;first[px]=first[px] or py;last[px]=py end
 end end
 for _,p in ipairs(M.POSTS)do for px=p.x0,p.x1 do if last[px] then last[px]=math.min(last[px],M.HULL_BOTTOM) end end end
 for px=0,W-1 do if first[px] and last[px]-first[px]+1<M.MIN then first[px],last[px]=nil,nil end end
 local T={uv=uv,hull=hull,first=first,last=last,body=uv[M.BODY[2]*W+M.BODY[1]]}
 ts.dryDock=T
 return T
end

local function hAt(p,z)
 for _,s in ipairs(p)do if z>=s[1] and z<s[2] then return s[3] end end
 return 0
end

function M.append(c,cells,quad,uvFor)
 if c.mid~=M.TEMPLATE[1][1] then return end
 for r=1,2 do for q=1,3 do local n=cells[(c.cx+q-1)..':'..(c.cy+r-1)];if not (n and n.mid==M.TEMPLATE[r][q]) then return end end end
 local T=template(c.ts,uvFor);if not T then return end
 local X0,Z0=c.cx*16,c.cy*16
 local function px_(px,py)return T.hull[py*W+px] and T.uv[py*W+px] or T.body end
 local function top(x,y,z0,z1,t)quad({{x,y,z0},{x+1,y,z0},{x+1,y,z1},{x,y,z1}},t,1)end
 local function south(x,y0,y1,z,t)quad({{x,y1,z},{x+1,y1,z},{x+1,y0,z},{x,y0,z}},t,.88)end
 local function north(x,y0,y1,z,t)quad({{x+1,y1,z},{x,y1,z},{x,y0,z},{x+1,y0,z}},t,.66)end
 local prof={}
 for px=0,W-1 do
  local a,b=T.first[px],T.last[px]
  if a then
   local x=X0+px
   local n=b-a+1
   local Hx=math.min(M.RIM,n);local rem=n-Hx
   local ntn=math.min(M.LEDGE,rem);rem=rem-ntn
   local ntf=math.min(M.LEDGE,rem);rem=rem-ntf
   local nin=math.max(0,math.min(Hx-M.FLOOR,rem));local nflo=rem-nin
   local hf=Hx-nin
   local zb=Z0+b+1
   local zni=zb-ntn
   local zfo=Z0+a+Hx;local zin=zfo+ntf
   -- the near side: the art's own rows stacked up from the keel
   for i=0,Hx-1 do south(x,i,i+1,zb,px_(px,b-i)) end
   if ntn==0 then top(x,Hx,zb-1,zb,px_(px,b-Hx+1)) end
   for py=b-Hx-ntn+1,b-Hx do top(x,Hx,Z0+py+Hx,Z0+py+Hx+1,px_(px,py)) end
   if ntf>0 then
    for py=a,a+ntf-1 do top(x,Hx,Z0+py+Hx,Z0+py+Hx+1,px_(px,py)) end
    for i=0,Hx-1 do north(x,i,i+1,zfo,px_(px,b-i)) end
    for j=0,nin-1 do south(x,Hx-j-1,Hx-j,zin,px_(px,a+ntf+j)) end
    for py=a+ntf+nin,a+ntf+nin+nflo-1 do top(x,hf,Z0+py+hf,Z0+py+hf+1,px_(px,py)) end
    local zfv=zin+nflo
    if zni>zfv then top(x,hf,zfv,zni,px_(px,a+ntf+nin+nflo-1)) end
    if hf<Hx then north(x,hf,Hx,zni,T.body) end
   end
   local p={}
   if ntf>0 then p[#p+1]={zfo,zin,Hx} end
   if zni>zin and ntf>0 then p[#p+1]={zin,zni,hf} end
   p[#p+1]=ntn>0 and {zni,zb,Hx} or {zb-1,zb,Hx}
   prof[px]=p
  end
 end
 -- the open ends of every step between neighbouring columns
 for px=0,W-1 do
  local p=prof[px]
  if p then
   for _,d in ipairs({-1,1})do
    local q=prof[px+d] or {}
    local zs={}
    for _,s in ipairs(p)do zs[#zs+1]=s[1];zs[#zs+1]=s[2] end
    for _,s in ipairs(q)do zs[#zs+1]=s[1];zs[#zs+1]=s[2] end
    table.sort(zs)
    local x=d<0 and X0+px or X0+px+1
    for i=1,#zs-1 do
     local z0,z1=zs[i],zs[i+1]
     if z1>z0 then
      local zm=(z0+z1)/2;local hA,hN=hAt(p,zm),hAt(q,zm)
      if hA>hN then
       if d<0 then quad({{x,hA,z0},{x,hA,z1},{x,hN,z1},{x,hN,z0}},T.body,.74)
       else quad({{x,hA,z1},{x,hA,z0},{x,hN,z0},{x,hN,z1}},T.body,.8) end
      end
     end
    end
   end
  end
 end
 -- the props: a box on the grass, the art's own pixel rows on the front
 for _,p in ipairs(M.POSTS)do
  local h=p.y1-p.y0
  local z0,z1=Z0+p.pz-2,Z0+p.pz
  local xa,xb=X0+p.x0,X0+p.x1
  for px=p.x0,p.x1-1 do for i=0,h-1 do south(X0+px,i,i+1,z1,T.uv[(p.y1-1-i)*W+px]) end end
  local edge=T.uv[(p.y0+4)*W+p.x0]
  local core=T.uv[p.y0*W+p.x0+1]
  for px=p.x0,p.x1-1 do top(X0+px,h,z0,z1,core) end
  quad({{xa,h,z0},{xa,h,z1},{xa,0,z1},{xa,0,z0}},edge,.74)
  quad({{xb,h,z1},{xb,h,z0},{xb,0,z0},{xb,0,z1}},T.uv[(p.y0+4)*W+p.x1-1],.8)
  for px=p.x0,p.x1-1 do north(X0+px,0,h,z0,edge) end
 end
end
return M
