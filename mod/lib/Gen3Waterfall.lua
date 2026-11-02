-- A waterfall's drop
local M={}
M.MAPS={EM_ROUTE114=true}
M.FALL=32 -- px: about two blocks (user, 2026-10-18)
M.MAX_BODY=240
local D4={{1,0},{-1,0},{0,1},{0,-1}}
local function key(x,y)return x..':'..y end
local function isFall(c)return c and c.shape and c.shape.kind=='water' and c.floor and c.floor.waterfall end
local function isWater(c)return c and c.shape and c.shape.kind=='water' end

function M.prepare(cells,def)
 if not (def and M.MAPS[def.id or '']) then return end
 for _,c in pairs(cells)do c.fall=nil end
 local done={}
 for _,top in pairs(cells)do
  local up=cells[key(top.cx,top.cy-1)]
  if isFall(top) and not isFall(up) and isWater(up) and not done[top] then
   local run={}
   local c=top
   while isFall(c) do run[#run+1]=c;done[c]=true;c=cells[key(c.cx,c.cy+1)] end
   if isWater(c) and #run>0 then
    local low=c.base or 0
    local body,seen,queue,qi={}, {up=true},{up},1
    seen[up]=true
    while queue[qi] and #body<=M.MAX_BODY do
     local a=queue[qi];qi=qi+1;body[#body+1]=a
     for _,d in ipairs(D4)do
      local n=cells[key(a.cx+d[1],a.cy+d[2])]
      if n and isWater(n) and not isFall(n) and not seen[n] then seen[n]=true;queue[#queue+1]=n end
     end
    end
    if #body<=M.MAX_BODY then
     for _,a in ipairs(body)do a.base=low+M.FALL end
     for _,f in ipairs(run)do f.base=low+M.FALL end
    end
   end
  end
 end
end
return M
