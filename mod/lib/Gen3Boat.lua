-- Slateport's little sailboats moored in the harbour
local M={}
M.FACE=8
M.TEMPLATE={{0x338,0x339,0x33A},{0x340,0x341,0x342},{0x348,0x349,0x34A}}
M.PAIR={0x346,0x347,0x368,0x34E,0x34F,0x370,0x356,0x357,0x378,0x35E,0x35F,0x380}
M.MIDS,M.FAMILY={},{}
-- M.AT[mid] = {column, row} of the tile inside its boat's drawing
M.AT={}
for r,row in ipairs(M.TEMPLATE)do for q,m in ipairs(row)do M.MIDS[m]=true;M.FAMILY[m]=1;M.AT[m]={q-1,r-1} end end
for i,m in ipairs(M.PAIR)do M.MIDS[m]=true;M.FAMILY[m]=2;M.AT[m]={(i-1)%3,math.floor((i-1)/3)} end
M.SEA=0x170

local function key(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end

local function group(c,cells)
 if c.boat then return c.boat end
 local fam=M.FAMILY[c.mid]
 local g={x0=c.cx,y0=c.cy,x1=c.cx,y1=c.cy,family=fam,ox=c.cx-M.AT[c.mid][1],oy=c.cy-M.AT[c.mid][2]}
 local st,seen={c},{[c]=true}
 while #st>0 do
  local n=table.remove(st);n.boat=g;g.n=(g.n or 0)+1
  g.x0,g.y0,g.x1,g.y1=math.min(g.x0,n.cx),math.min(g.y0,n.cy),math.max(g.x1,n.cx),math.max(g.y1,n.cy)
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local m=cells[(n.cx+d[1])..':'..(n.cy+d[2])]
   if m and not seen[m] and M.FAMILY[m.mid]==fam and m.pair==c.pair then seen[m]=true;st[#st+1]=m end
  end
 end
 return g
end

M.SEEDS={{20,14},{23,10},{35,14},{35,18},{29,10},{30,10}}
M.MAST_FOOT=26 -- the drawing row where the mast meets the deck
M.MAST_X0,M.MAST_X1=27,31 -- the drawing columns of the mast's pole
M.BELL=4 -- how far the cloth bellies out to leeward (px)
local function template(ts,uvFor)
 if ts.boatTemplate~=nil then return ts.boatTemplate or nil end
 ts.boatTemplate=false
 if not ts.imageData then return end
 local sea={}
 local s=ts.midToSlot[M.SEA]
 if s then local ox,oy=s%ts.cols*16,math.floor(s/ts.cols)*16
  for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(ox+x,oy+y);sea[key(r,g,b)]=true end end end
 local col,uv={}, {}
 for py=0,47 do for px=0,47 do
  local mid=M.TEMPLATE[math.floor(py/16)+1][math.floor(px/16)+1]
  local sl=ts.midToSlot[mid]
  if sl then
   local r,g,b=ts.imageData:getPixel(sl%ts.cols*16+px%16,math.floor(sl/ts.cols)*16+py%16)
   if not (sea[key(r,g,b)] or (b>r+.25 and b>g+.15)) then
    local t=uvFor(ts,mid)
    if t then
     local u=t[1][1]+(t[2][1]-t[1][1])*(px%16+.5)/16
     local v=t[1][2]+(t[3][2]-t[1][2])*(py%16+.5)/16
     col[py*48+px]={r,g,b};uv[py*48+px]={{u,v},{u,v},{u,v},{u,v}}
    end
   end
  end
 end end
 local function dark(k)local c=col[k];return c and (.299*c[1]+.587*c[2]+.114*c[3])<.42 end
 local sail={}
 local st={}
 for _,sd in ipairs(M.SEEDS)do local k=sd[2]*48+sd[1];if col[k] and not dark(k) then sail[k]=true;st[#st+1]=k end end
 while #st>0 do
  local k=table.remove(st);local x,y=k%48,math.floor(k/48)
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local nx,ny=x+d[1],y+d[2]
   if nx>=0 and nx<48 and ny>=0 and ny<=M.MAST_FOOT then
    local n=ny*48+nx
    if col[n] and not sail[n] and not dark(n) then sail[n]=true;st[#st+1]=n end
   end
  end
 end
 local edge={}
 for k in pairs(sail)do local x,y=k%48,math.floor(k/48)
  for dy=-1,1 do for dx=-1,1 do
   local nx,ny=x+dx,y+dy
   if nx>=0 and nx<48 and ny>=0 and ny<=M.MAST_FOOT then local n=ny*48+nx;if col[n] and dark(n) then edge[n]=true end end
  end end
 end
 for k in pairs(edge)do sail[k]=true end
 local hull={}
 local votes,best,bn={},nil,0
 for k,c in pairs(col)do
  if not sail[k] and not (c[2]>c[1]+.06 and c[2]>c[3]+.04) then
   hull[k]=true
   if not dark(k) then local q=key(c[1],c[2],c[3]);votes[q]=(votes[q] or 0)+1;if votes[q]>bn then bn,best=votes[q],k end end
  end
 end
 if not best then return end
 local T={uv=uv,sail=sail,hull=hull,body=uv[best]}
 ts.boatTemplate=T
 return T
end

function M.append(c,cells,quad,uvFor)
 local g=group(c,cells);if not (g.x0==c.cx and g.y0==c.cy) then return end
 if (g.n or 0)<4 then return end
 local T=template(c.ts,uvFor);if not T then return end
 local X0,Y0=g.ox*16,g.oy*16
 local rows=(g.y1-g.oy+1)*16
 local F=M.FACE
 local function box(a,y0,za,b,y1,zb,t)
  quad({{a,y1,za},{b,y1,za},{b,y1,zb},{a,y1,zb}},t,1)
  quad({{a,y1,zb},{b,y1,zb},{b,y0,zb},{a,y0,zb}},t,.88)
  quad({{b,y1,za},{a,y1,za},{a,y0,za},{b,y0,za}},t,.66)
  quad({{a,y1,za},{a,y1,zb},{a,y0,zb},{a,y0,za}},t,.74)
  quad({{b,y1,zb},{b,y1,za},{b,y0,za},{b,y0,zb}},t,.8)
 end
 local function boat(dy)
  local limit=rows-1-dy
  local Z0=Y0+dy
  local function hull(px,py)return py>=0 and py<=limit and px>=0 and px<48 and T.hull[py*48+px] end
  local first,last={},{}
  for px=0,47 do for py=0,math.min(47,limit) do if hull(px,py) then first[px]=first[px] or py;last[px]=py end end end
  for px=0,47 do local a,b=first[px],last[px]
   if a then
    local fz=Z0+b+1
    local deckH=math.min(F,b-a+1)
    for py=math.max(a,b-F+1),b do
     local t=hull(px,py) and T.uv[py*48+px] or T.body
     local h=b-py;quad({{X0+px,h+1,fz},{X0+px+1,h+1,fz},{X0+px+1,h,fz},{X0+px,h,fz}},t,.88)
    end
    local backZ=fz-1
    for py=b-F,a,-1 do
     local t=hull(px,py) and T.uv[py*48+px] or T.body
     local z=Z0+py+deckH
     quad({{X0+px,deckH,z},{X0+px+1,deckH,z},{X0+px+1,deckH,z+1},{X0+px,deckH,z+1}},t,1)
     backZ=z
    end
    quad({{X0+px+1,deckH,backZ},{X0+px,deckH,backZ},{X0+px,0,backZ},{X0+px+1,0,backZ}},T.body,.62)
    for _,d in ipairs({-1,1})do
     local na,nb=first[px+d],last[px+d]
     local nfz=nb and Z0+nb+1 or nil
     local nback=na and (Z0+math.min(nb-F+1, na)+math.min(F,nb-na+1)) or nil
     local x=d<0 and X0+px or X0+px+1
     local function side(z0,z1)if z1>z0 then
      if d<0 then quad({{x,deckH,z0},{x,deckH,z1},{x,0,z1},{x,0,z0}},T.body,.74)
      else quad({{x,deckH,z1},{x,deckH,z0},{x,0,z0},{x,0,z1}},T.body,.8) end end end
     if not na then side(backZ,fz)
     else
      if nfz<fz then side(nfz,fz) end
      if nback>backZ then side(backZ,math.min(nback,fz)) end
     end
    end
   end
  end
  local zm=Z0+M.MAST_FOOT+F
  for py=6,M.MAST_FOOT do
   local h=F+M.MAST_FOOT-py
   if py<=limit then
    for px=M.MAST_X0,M.MAST_X1-1 do
     local k=py*48+px
     if T.sail[k] or T.hull[k] then box(X0+px,h,zm-.9,X0+px+1,h+1,zm+.9,T.uv[k] or T.body) end
    end
   end
  end
  local function belly(px)
   local u=math.max(0,math.min(1,(px-2)/44))
   return M.BELL*math.sin(math.pi*u)
  end
  for k in pairs(T.sail)do
   local px,py=k%48,math.floor(k/48)
   if py<=limit and not (px>=M.MAST_X0 and px<M.MAST_X1 and py>=6) then
    local h=F+M.MAST_FOOT-py
    local z0,z1=zm+belly(px),zm+belly(px+1)
    quad({{X0+px,h,z0},{X0+px+1,h,z1},{X0+px+1,h+1,z1},{X0+px,h+1,z0}},T.uv[k],1)
   end
  end
 end
 if g.family==2 then boat(8);boat(24) else boat(0) end
end
return M
