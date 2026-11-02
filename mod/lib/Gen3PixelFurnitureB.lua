-- Pixel-voxel furniture recipes, second author
local V=...
local R={}
local BACK_YES={'crate','box','load','bucket','bin','seat','chair','stool','sofa','bench','cushion','cot','bed',
 'stand','pedestal','planter','plant','pot','potbush','basket','statue','bust','grave','table','tablet','stump','log','trunk',
 'pillar','post','pole','cube','capsule','cooler','pylon','backrest','bush','beacon','benche','wide'}
local BACK_NO={'cabinet','counter','desk','pc','tv','shelf','machine','console','kiosk','fridge','sink','board',
 'display','screen','monitor','register','rack','wardrobe','drawer','server','engine','generator','vending','slot',
 'roulette','gate','partition','fence','rail','railflag','flag','umbrella','kitchen','stove','laptop','appliance','case','showcase'}
local function add(...)
 local a={...}
 if a[1]:find('plant') and not a[1]:find('planter') then
  a[9]=a[9] or {};a[9].lift=0
  local pot,leaves
  for _,pt in ipairs(a[4])do if pt[11] then leaves=pt else pot=pt end end
  if pot and leaves then
   local L0,L1=leaves[6],leaves[3]+leaves[4]
   local n=math.floor((L1-L0+1)/2) -- half the rows deep, half tall
   local c=(pot[6]+pot[3])/2+pot[4] -- the pot's middle (depth)
   local F=math.floor(c+.5)
   if a[9].crownCentre then F=math.floor(c+n/2+.5) end
   leaves[3]=L0+n-1;leaves[4]=L1-leaves[3];leaves[11]=math.max(pot[4]+1,F-1-L1)
   local cx=math.floor((pot[1]+pot[2])/2)
   a[4][#a[4]+1]={cx-2,cx+2,L1,leaves[11]-pot[4],true,L1-3,nil,'disc',nil,nil,pot[4]}
  end
 end
 local back=a[9] and a[9].back
 if back==nil then
  local yes,no=false,false
  for tok in a[1]:gsub('^em_gate_','em_'):gmatch('[^_]+')do -- em_gate_*: the Reception Gate's pieces, not gates
   tok=tok:gsub('%d+$',''):gsub('s$','')
   for _,w in ipairs(BACK_NO)do if tok:sub(-#w)==w then no=true end end
   for _,w in ipairs(BACK_YES)do if tok:sub(-#w)==w then yes=true end end
  end
  back=yes and not no
 end
 if back then for _,pt in ipairs(a[4])do
  if pt[5]==true and (not pt[8] or pt[8]==true) and pt[14]==nil then -- plain and round=true parts (not disc/card/ball)
   pt[14]=true
  end
 end end
 R[#R+1]=a
 if a[2]=='facility' then
  local b={};for i=1,9 do b[i]=a[i] end
  b[1]=a[1]..'_g';local o={};for k,v in pairs(a[9] or {})do o[k]=v end;o.primary='general';b[9]=o
  R[#R+1]=b
 end
end

for _,a in ipairs(V.data('gen3_pixel_furniture_b'))do add(unpack(a,1,table.maxn(a)))end

return R
