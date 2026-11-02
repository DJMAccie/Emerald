-- Interior walls drawn obliquely as blocks
local M={}
M.MAXFACE=12

local cache=setmetatable({},{__mode='k'})
local function key(x,y)return x..':'..y end

local function build(cells)
 local W={cells=cells,cols={}}
 cache[cells]=W
 local CC={}
 local function cellAt(cx,cy)
  local k=(cx+4096)*8192+cy+4096
  local c=CC[k];if c==nil then c=cells[key(cx,cy)] or false;CC[k]=c end
  return c or nil
 end
 W.cellAt=cellAt
 local function px(X,Y)
  local c=cellAt(math.floor(X/16),math.floor(Y/16))
  if not (c and c.shape and c.shape.kind=='obwall') then return nil end
  local ts=c.ts;local s=ts.midToSlot[c.mid];if not s or not ts.imageData then return nil end
  local ax,ay=s%ts.cols*16+X%16,math.floor(s/ts.cols)*16+Y%16
  local r,g,b=ts.imageData:getPixel(ax,ay)
  if W.over and ts.overImageData then
   local rr,gg,bb,aa=ts.overImageData:getPixel(ax,ay)
   if aa>0 then r,g,b=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa) end
  end
  return r,g,b
 end
 W.px=px
 local function class(X,Y)
  local r,g,b=px(X,Y);if not r then return 0 end
  local l=.299*r+.587*g+.114*b
  if b>r+.08 and l<.45 then return 3 end
  if r<=g+.02 and l<.75 then return 2 end
  return 1
 end
 W.class=class
 local x0,y0,x1,y1=1e9,1e9,-1e9,-1e9
 for _,c in pairs(cells)do if c.shape and c.shape.kind=='obwall' then
  x0,y0,x1,y1=math.min(x0,c.cx),math.min(y0,c.cy),math.max(x1,c.cx),math.max(y1,c.cy) end end
 if x1<x0 then return W end
 local spec
 for _,c in pairs(cells)do if c.shape and c.shape.kind=='obwall' and c.shape.ob then spec=c.shape.ob;break end end
 W.spec=spec
 W.over=spec and spec.over or nil
 if spec then
  local floor={}
  for _,f in ipairs(spec.floor or {})do floor[f[1]*65536+f[2]*256+f[3]]=true end
  if spec.floorFromWalkable then
   local count,ts={},nil
   for _,c in pairs(cells)do if (c.collision or 0)==0 and c.shape and c.shape.kind=='flat' and c.ts and c.ts.imageData then
    count[c.mid]=(count[c.mid] or 0)+1;ts=ts or c.ts end end
   local order={}
   for m,n in pairs(count)do order[#order+1]={m,n} end
   table.sort(order,function(a,b)return a[2]>b[2] end)
   for i=1,math.min(2,#order)do
    local s=ts.midToSlot[order[i][1]]
    if s then local ox,oy=s%ts.cols*16,math.floor(s/ts.cols)*16
     for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
      if .299*r+.587*g+.114*b<.93 then floor[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)]=true end
     end end
    end
   end
  end
  local pal,palMids
  if spec.palette then
   local anyc;for _,c in pairs(cells)do if c.ts and c.ts.imageData then anyc=c;break end end
   local ts=anyc and anyc.ts;local s=ts and ts.midToSlot[spec.palette.mid]
   if s then
    pal,palMids={},{}
    local ox,oy=s%ts.cols*16,math.floor(s/ts.cols)*16
    for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
     local k=math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
     if not floor[k] then pal[k]=true end
    end end
    for _,m in ipairs(spec.palette.mids)do palMids[m]=true end
   end
  end
  local function patched(X,Y)
   for _,q in ipairs(spec.patch or {})do if X>=q[1] and X<=q[3] and Y>=q[2] and Y<=q[4] then return q end end
  end
  W.patched=patched
  for _,m in ipairs(spec.floorMids or {})do
   local anyc;for _,c in pairs(cells)do if c.ts and c.ts.imageData and c.ts.midToSlot[m] then anyc=c;break end end
   if anyc then local ts=anyc.ts;local sl=ts.midToSlot[m];local ox,oy=sl%ts.cols*16,math.floor(sl/ts.cols)*16
    for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
     floor[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)]=true end end
   end
  end
  local function wall(X,Y)
   local r,g,b=px(X,Y);if not r then return false end
   if patched(X,Y) then return true end
   if spec.overOnly then
    local c=cells[key(math.floor(X/16),math.floor(Y/16))]
    if c and spec.overOnly[c.mid] then
     local ts=c.ts;local sl=ts.midToSlot[c.mid]
     if not (sl and ts.overImageData) then return false end
     local _,_,_,aa=ts.overImageData:getPixel(sl%ts.cols*16+X%16,math.floor(sl/ts.cols)*16+Y%16)
     return aa>.5
    end
   end
   if spec.solid then
    local c=cells[key(math.floor(X/16),math.floor(Y/16))]
    if c and spec.solid[c.mid] then return r+g+b>.02 end
   end
   if pal then
    local c=cells[key(math.floor(X/16),math.floor(Y/16))]
    if c and palMids[c.mid] then return pal[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)] or false end
   end
   return not floor[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)]
  end
  for X=x0*16,x1*16+15 do
   local list={}
   local col={}
   for Y=y0*16,y1*16+15 do col[Y]=wall(X,Y) end
   local Y=y0*16
   while Y<=y1*16+15 do
    if not spec.perCell and not spec.noGap and not col[Y] and col[Y-1] and px(X,Y) then
     local e=Y;while e<=y1*16+15 and not col[e] and px(X,e) do e=e+1 end
     if col[e] and e-Y<=6 then for k=Y,e-1 do col[k]=true end end
     Y=e
    else Y=Y+1 end
   end
   Y=y0*16
   while Y<=y1*16+15 do
    if col[Y] then
     local a=Y;while col[Y] do Y=Y+1 end
     if spec.perCell then local e=math.floor(a/16)*16+16;if Y>e then Y=e end end
     local b=Y-1
     local n=cells[key(math.floor(X/16),math.floor(b/16))]
     local h=(spec.hBy and n and spec.hBy[n.mid]) or spec.auto
     local ext=0
     if spec.through and (b+1)%16==0 then
      local below=cells[key(math.floor(X/16),math.floor(b/16)+1)]
      if below and (below.collision or 0)~=0 and below.shape and below.shape.kind~='obwall' and below.shape.kind~='flat' then ext=16 end
     end
     list[#list+1]={ta=a,fa=math.max(a+1,b+ext-h+1),fb=b,ext=ext>0 and ext or nil}
    else Y=Y+1 end
   end
   W.cols[X]=list
  end
  return W
 end
 for X=x0*16,x1*16+15 do
  local list={}
  local Y=y0*16
  local stop=y1*16+15
  while Y<=stop do
   if class(X,Y)==0 then Y=Y+1
   else
    local a=Y;while Y<=stop and class(X,Y)~=0 do Y=Y+1 end
    local b=Y-1
    local t=a;local r=a
    while r<=b do
     local k=class(X,r)
     if k>=2 then
      local s=r;local rock=0
      while r<=b and class(X,r)>=2 do if class(X,r)==2 then rock=rock+1 end;r=r+1 end
      local e=r-1
      if rock>=3 and e-s+1<=M.MAXFACE then list[#list+1]={ta=t,fa=s,fb=e};t=e+1 end
     else r=r+1 end
    end
    if t<=b then list[#list+1]={ta=t,fb=b,open=true} end -- no face under it yet
   end
  end
  W.cols[X]=list
 end
 do
  local votes,best,bn={},nil,0
  for _,list in pairs(W.cols)do for _,p in ipairs(list)do if not p.open then
   local L=p.fb-p.fa+1;votes[L]=(votes[L] or 0)+1
   if votes[L]>bn then best,bn=L,votes[L] end
  end end end
  if best then
   for _,list in pairs(W.cols)do for _,p in ipairs(list)do if not p.open then
    local L=p.fb-p.fa+1
    if math.abs(L-best)<=3 and p.fb-best+1>=p.ta then p.fa=p.fb-best+1 end
   end end end
  end
 end
 for X,list in pairs(W.cols)do
  for _,p in ipairs(list)do if p.open then
   local dark,n=0,0
   for r=p.ta,p.fb do n=n+1;if class(X,r)==3 then dark=dark+1 end end
   if dark>=n*.7 then
    p.adopt={}
    for _,dx in ipairs({1,-1,2,-2})do
     for _,q in ipairs(W.cols[X+dx] or {})do
      if not q.open and q.fb>=p.ta and q.ta<=p.fb then p.adopt[#p.adopt+1]={ta=math.max(q.ta,p.ta),fa=q.fa,fb=math.min(q.fb,p.fb)} end
     end
     if #p.adopt>0 then break end
    end
   end
  end end
 end
 for X,list in pairs(W.cols)do
  local out={}
  for _,p in ipairs(list)do
   if not p.open then out[#out+1]=p
   elseif p.adopt then for _,q in ipairs(p.adopt)do if q.fa<=q.fb then out[#out+1]=q end end end
  end
  W.cols[X]=out
 end
 return W
end

local function pieceAt(W,X,Y)
 for _,p in ipairs(W.cols[X] or {})do if Y>=p.ta and Y<=p.fb then return p end end
end

function M.append(c,cells,quad,uvFor)
 local W=cache[cells] or build(cells)
 local uv=uvFor(c.ts,c.mid);if not uv then return end
 local X0,Y0=c.cx*16,c.cy*16
 W.uvc=W.uvc or {}
 local UVC,cellAt=W.uvc,W.cellAt
 local function swAbs(X,Y)
  local k=(X+32768)*65536+Y+32768
  local hit=UVC[k];if hit~=nil then return hit or nil end
  local n=cellAt and cellAt(math.floor(X/16),math.floor(Y/16)) or cells[key(math.floor(X/16),math.floor(Y/16))]
  local t=n and uvFor(n.ts,n.mid)
  if not t then UVC[k]=false;return nil end
  local u=t[1][1]+(t[2][1]-t[1][1])*(X%16+.5)/16
  local v=t[1][2]+(t[3][2]-t[1][2])*(Y%16+.5)/16
  hit={{u,v},{u,v},{u,v},{u,v}};UVC[k]=hit
  return hit
 end
 local function sw(x,y)return swAbs(X0+x,Y0+y)end
 if W.patched then
  local raw=swAbs
  W.swp=W.swp or {}
  local SWP=W.swp
  sw=function(x,y)
   local X,Y=X0+x,Y0+y
   local k=(X+32768)*65536+Y+32768
   local hit=SWP[k];if hit~=nil then return hit or nil end
   local q=W.patched(X,Y)
   if q then hit=raw(q[1]-1,Y) or raw(X,Y) else hit=raw(X,Y) end
   SWP[k]=hit or false
   return hit
  end
 end
 for _,q in ipairs(W.spec and W.spec.posts or {})do
  if math.floor(q.x/16)==c.cx and math.floor(q.foot/16)==c.cy then
   local h0=q.h0 or W.spec.auto
   local zf=q.foot+1+h0
   local xa,xb=q.x,q.x+q.w
   for r=q.top,q.foot do
    local y0=h0+(q.foot-r);local y1=y0+1
    for X=xa,xb-1 do
     local t=swAbs(X,r)
     if t then
      quad({{X,y1,zf},{X+1,y1,zf},{X+1,y0,zf},{X,y0,zf}},t,.9)
      quad({{X+1,y1,zf-q.w},{X,y1,zf-q.w},{X,y0,zf-q.w},{X+1,y0,zf-q.w}},t,.64)
     end
    end
    local tl,tr=swAbs(xa,r),swAbs(xb-1,r)
    if tl then quad({{xa,y1,zf-q.w},{xa,y1,zf},{xa,y0,zf},{xa,y0,zf-q.w}},tl,.74) end
    if tr then quad({{xb,y1,zf},{xb,y1,zf-q.w},{xb,y0,zf-q.w},{xb,y0,zf}},tr,.8) end
   end
   local cap=swAbs(xa+math.floor(q.w/2),q.top)
   local yt=h0+(q.foot-q.top)+1
   if cap then quad({{xa,yt,zf-q.w},{xb,yt,zf-q.w},{xb,yt,zf},{xa,yt,zf}},cap,1) end
  end
 end
 W.body=W.body or {}
 local function bodyAt(X,p)
  local by=W.spec and W.spec.bodyBy
  local foot=by and cells[key(math.floor(X/16),math.floor(p.fb/16))]
  local q=(foot and by[foot.mid]) or (W.spec and W.spec.body)
  if q then
   local t=uvFor(c.ts,q[1])
   if t then
    local u=t[1][1]+(t[2][1]-t[1][1])*(q[2]+.5)/16
    local v=t[1][2]+(t[3][2]-t[1][2])*(q[3]+.5)/16
    return {{u,v},{u,v},{u,v},{u,v}}
   end
  end
  local cxk,cyk=math.floor(X/16),math.floor(p.fb/16)
  local ck=cxk..':'..cyk
  local hit=W.body[ck]
  if hit==nil then
   local votes,best,bn,bx={},nil,0,nil
   for XX=cxk*16,cxk*16+15 do for _,q in ipairs(W.cols[XX] or {})do
    if math.floor(q.fb/16)==cyk then
     for Y=q.fa,q.fb do
      local r,g,b=W.px(XX,Y)
      if r and .299*r+.587*g+.114*b>.42 then
       local k=math.floor(r*255)*65536+math.floor(g*255)*256+math.floor(b*255)
       votes[k]=(votes[k] or 0)+1
       if votes[k]>bn then bn,best,bx=votes[k],Y,XX end
      end
     end
    end
   end end
   hit=best and {bx,best} or false
   W.body[ck]=hit
  end
  if hit then return swAbs(hit[1],hit[2]) end
  return swAbs(X,p.fa+math.floor((p.fb-p.fa)/2))
 end
 for x=0,15 do
  local X=X0+x
  for _,p in ipairs(W.cols[X] or {})do
   local E=p.ext or 0
   local L=p.fb+E-p.fa+1
   local zf=p.fb+E+1
   local quad=quad
   local lf=W.spec and W.spec.liftBy
   if lf then local fc=cells[key(math.floor(X/16),math.floor(p.fb/16))];lf=fc and lf[fc.mid] end
   if lf then
    local raw=quad
    quad=function(pts,t,sh)for _,v in ipairs(pts)do v[2]=v[2]+lf;v[3]=v[3]+lf end;raw(pts,t,sh) end
    for Y=math.max(p.ta,Y0),math.min(p.fa-1,Y0+15) do
     local z=Y+L
     quad({{X,0,z+1},{X+1,0,z+1},{X+1,0,z},{X,0,z}},bodyAt(X,p) or sw(x,Y-Y0),.55)
    end
   end
   if E>0 and math.floor(p.fb/16)==c.cy then
    quad({{X,E,zf},{X+1,E,zf},{X+1,0,zf},{X,0,zf}},bodyAt(X,p) or sw(x,p.fb-Y0),.86)
   end
   for Y=math.max(p.ta,Y0),math.min(p.fb,Y0+15) do
    local t=sw(x,Y-Y0)
    if Y>=p.fa then
     local h=p.fb+E-Y
     quad({{X,h+1,zf},{X+1,h+1,zf},{X+1,h,zf},{X,h,zf}},t,.86)
     for _,d in ipairs({-1,1})do
      local q=pieceAt(W,X+d,Y)
      if not q then
       local sx=d<0 and X or X+1
       if d<0 then quad({{sx,h+1,zf-1},{sx,h+1,zf},{sx,h,zf},{sx,h,zf-1}},t,.72)
       else quad({{sx,h+1,zf},{sx,h+1,zf-1},{sx,h,zf-1},{sx,h,zf}},t,.78) end
      end
     end
    else
     local z=Y+L
     quad({{X,L,z},{X+1,L,z},{X+1,L,z+1},{X,L,z+1}},t,1)
     for _,d in ipairs({-1,1})do
      local q=pieceAt(W,X+d,Y)
      if not (q and Y<q.fa) then
       local sx=d<0 and X or X+1
       local body=bodyAt(X,p) or t
       local art=W.spec and W.spec.wallArt
       local Xi=X-d*3
       local pi=art and pieceAt(W,Xi,p.fb)
       if pi and pi.fb==p.fb then
        local Xs=X-d*(3+(z%6))
        local ps=pieceAt(W,Xs,p.fb)
        if ps and ps.fb==p.fb then Xi=Xs end
        for r=p.fa,p.fb do
         local tt=swAbs(Xi,r) or body;local h=p.fb+E-r
         if d<0 then quad({{sx,h+1,z},{sx,h+1,z+1},{sx,h,z+1},{sx,h,z}},tt,.8)
         else quad({{sx,h+1,z+1},{sx,h+1,z},{sx,h,z},{sx,h,z+1}},tt,.86) end
        end
       elseif d<0 then quad({{sx,L,z},{sx,L,z+1},{sx,0,z+1},{sx,0,z}},body,.72)
       else quad({{sx,L,z+1},{sx,L,z},{sx,0,z},{sx,0,z+1}},body,.78) end
      end
     end
     if Y==p.ta and W.spec and W.spec.backToTop then
      local zb=math.floor(p.ta/16)*16
      if zb<z then
       quad({{X,L,zb},{X+1,L,zb},{X+1,L,z},{X,L,z}},t,1)
       for _,d in ipairs({-1,1})do
        if not (pieceAt(W,X+d,p.ta) or pieceAt(W,X+d,p.fb)) then
         local sx=d<0 and X or X+1;local body=bodyAt(X,p) or t
         quad({{sx,L,zb},{sx,L,z},{sx,0,z},{sx,0,zb}},body,d<0 and .72 or .78)
        end
       end
      end
     end
     if Y==p.ta then
      if W.spec and W.spec.wallArt then
       for r=p.fa,p.fb do
        local h=p.fb+E-r
        quad({{X+1,h+1,z},{X,h+1,z},{X,h,z},{X+1,h,z}},swAbs(X,r) or t,.74)
       end
      else quad({{X+1,L,z},{X,L,z},{X,0,z},{X+1,0,z}},bodyAt(X,p) or t,.62) end
     end
    end
   end
  end
 end
end
return M
