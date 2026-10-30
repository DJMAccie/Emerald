-- Gen3Relief: the counted relief of the General mountain laid on a rock mass (Route 111 / 114).
-- Real Gen3Relief, Gen3Hills (its patch cut and steep bands) and the baked Gen3ReliefData, off disk;
-- the mass is built from the baked cells (the cells that carry relief) with a flat ring of ground.
local V
V={require=function(name) return assert(loadfile('lib/'..name..'.lua'))(V) end}
local R=V.require('Gen3Relief')
local D=V.require('Gen3ReliefData').EM_ROUTE111
assert(D and D.w==40 and D.h==140,'baked Route 111 relief')

local UV={{0,0},{1,0},{1,1},{0,1}}
local TS={}
local function uvFor() return UV end

-- a window of baked cells x 0..11, y 124..135 (80 px of relief) as the mass; every cell outside it that touches it is
-- walkable ground at floor 0
local members,cells,inMass={},{},{}
local function key(x,y) return x..':'..y end
for y=124,135 do for x=0,11 do
 if D.cells[y*D.w+x+1] then
  local c={cx=x,cy=y,mid=0x07c,pair='general__mauville',ts=TS,collision=7,base=0}
  members[#members+1]=c;cells[key(x,y)]=c;inMass[c]=true
 end
end end
assert(#members>=40,'enough baked cells in the window: '..#members)
for _,c in ipairs(members) do
 for dx=-1,1 do for dy=-1,1 do
  local k=key(c.cx+dx,c.cy+dy)
  if not cells[k] then
   -- (the floor the game gives that level of ground: 16 px a level)
   local e=D.cells[(c.cy+dy)*D.w+c.cx+dx+1]
   local f=0
   if e then
    local sum,n=0,0
    for v in e:match('^([^|]*)'):gmatch('%-?%d+') do sum=sum+tonumber(v);n=n+1 end
    f=math.floor(sum/n/16+.5)*16
   end
   cells[k]={cx=c.cx+dx,cy=c.cy+dy,mid=0x001,pair='general__mauville',ts=TS,collision=0,base=f}
  end
 end end
end
local function mass(id,extra)
 local m={members=members,mapId=id,x0=0,y0=124,x1=11,y1=135}
 for k,v in pairs(extra or {}) do m[k]=v end
 return m
end

-- claims: only the listed maps, only real rock masses of General tiles
assert(R.claims(mass('EM_ROUTE111'),cells)==true,'Route 111 General mass is claimed')
assert(R.claims(mass('EM_ROUTE113'),cells)==false,'unlisted map is not claimed')
assert(R.claims(mass('EM_ROUTE111',{seaBoulders=true}),cells)==false,'sea boulders are not claimed')
local few={};for i=1,R.MIN_CELLS-1 do few[i]=members[i] end
assert(R.claims({members=few,mapId='EM_ROUTE111'},cells)==false,'a small group is a stone')
local brown={}
for i,c in ipairs(members) do brown[i]={cx=c.cx,cy=c.cy,mid=0x270,pair='general__fallarbor',ts=TS,collision=7,base=0} end
assert(R.claims({members=brown,mapId='EM_ROUTE111'},cells)==false,'brown terrace tiles are not claimed')

-- append: every cell emits; all numbers finite; uvs stay in the tile; build is deterministic
local function build()
 local m=mass('EM_ROUTE111');assert(R.claims(m,cells))
 local quads,sum,lo,hi=0,0,math.huge,-math.huge
 for _,c in ipairs(members) do
  assert(R.append(m,cells,function(v,uv,shade)
   assert(#v==4 and #uv==4,'quad with 4 corners and 4 uvs')
   assert(type(shade)=='number' and shade>0 and shade<1.2,'shade in range')
   for i=1,4 do
    local p=v[i]
    assert(p[1]==p[1] and p[2]==p[2] and p[3]==p[3] and math.abs(p[2])<1e4,'finite vertex')
    assert(uv[i][1]>=-1e-6 and uv[i][1]<=1+1e-6 and uv[i][2]>=-1e-6 and uv[i][2]<=1+1e-6,'uv inside the tile')
    sum=sum+p[1]*1.31+p[2]*2.17+p[3]*3.07
    lo=math.min(lo,p[2]);hi=math.max(hi,p[2])
   end
   quads=quads+1
  end,uvFor,c))
 end
 return quads,sum,lo,hi
end
local q1,s1,lo,hi=build()
local q2,s2=build()
assert(q1>=#members*16,'a top facet per patch at least: '..q1)
assert(q1==q2 and math.abs(s1-s2)<1e-6,'two builds are identical')
assert(hi>lo+16,'the relief has height: '..lo..'..'..hi)
-- a cell outside the data (the boundary fill a mass runs on into) still emits
local out={cx=-2,cy=124,mid=0x07c,pair='general__mauville',ts=TS,collision=7,base=0}
local m2=mass('EM_ROUTE111');m2.members={out,members[1]};cells[key(-2,124)]=out
local n=0
R.append(m2,cells,function() n=n+1 end,uvFor,out)
assert(n>0,'a cell outside the map emits')
print(string.format('PASS gen3 relief: %d cells, %d quads, heights %.0f..%.0f, deterministic',#members,q1,lo,hi))
