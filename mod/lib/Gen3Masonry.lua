-- Masonry
local M={}
M.enabled=true
M.MAPS={
 EM_SOOTOPOLIS_CITY={
  top={[0x220]=true,[0x222]=true,[0x239]=true,[0x23B]=true,
       [0x240]=true,[0x241]=true,[0x242]=true,[0x246]=true,[0x247]=true,[0x251]=true,[0x252]=true,[0x253]=true,
       [0x25C]=true,[0x25D]=true,[0x25E]=true,[0x262]=true,[0x263]=true,[0x26E]=true,[0x26F]=true},
  face={[0x2CD]=true,[0x2D3]=true,[0x2D4]=true,[0x2D8]=true,[0x2DA]=true,[0x2E0]=true,[0x2E1]=true,[0x2E2]=true,
        [0x2F3]=true,[0x2FB]=true,[0x2FD]=true},
  faceDefault=0x2E1,
 },
}
M.SCAN=12
M.KERB=4
local DIRS={{1,0},{-1,0},{0,1},{0,-1}}
local function key(x,y)return x..':'..y end
local function walk(n)return n and (n.collision or 0)==0 and n.base~=nil end

local function terrace(cells,c,dy)
 for k=1,M.SCAN do
  local n=cells[key(c.cx,c.cy+dy*k)]
  if not n then break end
  if walk(n) then return n.base end
 end
 return nil
end

local function surface(n)
 if not n then return 0 end
 if n.masonry=='top' then return n.mU end
 if n.masonry=='face' then return n.mL end
 return n.base or 0
end

function M.prepare(cells,def)
 local map=M.enabled and def and M.MAPS[def.id or '']
 if not map then return nil end
 local saved,list={},{}
 for _,c in pairs(cells)do
  local s=c.shape
  if s and s.kind=='cliff' and (c.collision or 0)~=0 and c.mid and c.ts and c.ts.midToSlot[c.mid] then
   local kind=map.top[c.mid] and 'top' or (map.face[c.mid] and 'face') or nil
   if kind then
    c.masonry=kind;list[#list+1]=c
    saved[#saved+1]={c=c,shape=s};c.shape={kind='masonry'}
   end
  end
 end
 for _,c in ipairs(list)do
  local own=c.base or 0
  local up,down=terrace(cells,c,-1),terrace(cells,c,1)
  c.mU=up and math.max(up,own) or own -- the upper terrace
  c.mL=down and math.min(down,own) or own -- the lower terrace
  c.map=map
 end
 return saved
end

function M.restore(saved)
 for _,s in ipairs(saved or {})do s.c.shape=s.shape end
end

local function course(emit,a,b,lo,hi,uv)
 local l,r=uv[1][1],uv[2][1]
 local t0,t1=uv[1][2],uv[3][2]
 local f=(hi-lo)/16
 local vb=t0+(t1-t0)*f
 emit({{a[1],lo,a[2]},{b[1],lo,b[2]},{b[1],hi,b[2]},{a[1],hi,a[2]}},{{l,vb},{r,vb},{r,t0},{l,t0}},M.SHADE)
 emit({{a[1],hi,a[2]},{b[1],hi,b[2]},{b[1],lo,b[2]},{a[1],lo,a[2]}},{{l,t0},{r,t0},{r,vb},{l,vb}},M.SHADE)
end
M.SHADE=.78

local function faceColumn(cells,start)
 local n=start
 while true do local u=cells[key(n.cx,n.cy-1)]; if u and u.masonry=='face' then n=u else break end end
 local rows={}
 while n and n.masonry=='face' do rows[#rows+1]=n; n=cells[key(n.cx,n.cy+1)] end
 local out={}
 for i=#rows,1,-1 do out[#out+1]=rows[i].mid end
 return out
end

-- 16-unit courses from the bottom; the top course is cropped, never stretched.
local function face(emit,ts,uvFor,a,b,lo,hi,mids,fallback)
 if #mids==0 then mids={fallback} end
 local t,i=lo,0
 while t<hi-.01 do
  local h=math.min(16,hi-t)
  i=i+1
  local uv=uvFor(ts,mids[(i-1)%#mids+1]) or uvFor(ts,fallback)
  if uv then course(emit,a,b,t,t+h,uv) end
  t=t+h
 end
end

local function kerbSide(emit,a,b,lo,hi,uv)
 local l,r=uv[1][1],uv[2][1]
 local t0,t1=uv[1][2],uv[3][2]
 local vt=t1-(t1-t0)*(hi-lo)/16
 emit({{a[1],lo,a[2]},{b[1],lo,b[2]},{b[1],hi,b[2]},{a[1],hi,a[2]}},{{l,t1},{r,t1},{r,vt},{l,vt}},M.SHADE)
 emit({{a[1],hi,a[2]},{b[1],hi,b[2]},{b[1],lo,b[2]},{a[1],lo,a[2]}},{{l,vt},{r,vt},{r,t1},{l,t1}},M.SHADE)
end

local function edge(d,x,z)
 if d[1]==1 then return {x+16,z},{x+16,z+16}
 elseif d[1]==-1 then return {x,z+16},{x,z}
 elseif d[2]==1 then return {x+16,z+16},{x,z+16}
 else return {x,z},{x+16,z} end
end

function M.append(c,cells,emit,uvFor)
 local ts,map=c.ts,c.map
 local x,z=c.cx*16,c.cy*16
 local sc=c.masonry=='top' and c.mU or c.mL
 local kerb=false
 if c.masonry=='top' then
  local uv=uvFor(ts,c.mid)
  kerb=uv~=nil
  local other=false
  for _,d in ipairs(DIRS)do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if not n or surface(n)~=sc then kerb=false;break end
   if not n.masonry then other=true end
  end
  kerb=kerb and other
  if kerb then
   local h=sc+M.KERB
   emit({{x,h,z},{x+16,h,z},{x+16,h,z+16},{x,h,z+16}},uv)
   for _,d in ipairs(DIRS)do
    local a,b=edge(d,x,z)
    kerbSide(emit,a,b,sc,h,uv)
   end
   return
  end
 end
 if c.masonry=='top' then
  local uv=uvFor(ts,c.mid)
  if uv then emit({{x,sc,z},{x+16,sc,z},{x+16,sc,z+16},{x,sc,z+16}},uv) end
 else
  local mid=c.mid
  for _,d in ipairs(DIRS)do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and not n.masonry and n.base==sc and (n.collision or 0)==0 and n.mid and n.ts==ts then mid=n.mid;break end
  end
  local uv=uvFor(ts,mid) or uvFor(ts,c.mid)
  if uv then emit({{x,sc,z},{x+16,sc,z},{x+16,sc,z+16},{x,sc,z+16}},uv) end
 end
 for _,d in ipairs(DIRS)do
  local n=cells[key(c.cx+d[1],c.cy+d[2])]
  local sn=surface(n)
  if sn~=sc and not (n and n.masonry and sc<sn) then
   local lo,hi=math.min(sc,sn),math.max(sc,sn)
   local a,b=edge(d,x,z)
   local col
   if n and n.masonry=='face' then col=faceColumn(cells,n) elseif c.masonry=='face' then col=faceColumn(cells,c) else col={} end
   face(emit,ts,uvFor,a,b,lo,hi,col,map.faceDefault)
  end
 end
end

return M
