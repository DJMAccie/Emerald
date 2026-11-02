-- Which tiles draw a tree and how each is stood up
local M={}
M.FAMILIES={dewford=true,lavaridge=true}

M.NARROW={
 dewford={crown=0x243,foot=0x23A,over={0x239,0x219}},
}

M.GENERAL={
 lavaridge={top=0x210,base={[0x210]=true,[0x211]=true,[0x218]=true,[0x21A]=true,[0x203]=true,[0x3B8]=true},over={0x210,0x211}},
}

M.PINE={
 lavaridge={foot={0x2C5,0x2C6,0x2C7,0x2CC,0x2CD},tip=0x2C4,crown=0x2CD,base=0x2CC,ground=0x271},
}

function M.of(secondary,mid,collision,behavior,ground,surf)
 if not M.FAMILIES[secondary] then return nil end
 local p=M.PINE[secondary]
 if p then
  if mid==p.tip then return {kind='flat',groundMid=p.ground,ashTop=true,reviewedSurface=true} end
  for _,f in ipairs(p.foot)do
   if mid==f then return {kind='flat',ground=p.ground,ashPine=true,reviewedSurface=true} end
  end
 end
 local n=M.NARROW[secondary]
 if n and (mid==n.crown or mid==n.foot) and (collision or 0)~=0 then
  return {kind='tree',root=true,narrow=true,ground=ground,anchorX=8,anchorZ=12,art={{n.crown},{n.foot}},artTipRows=1}
 end
 local g=M.GENERAL[secondary]
 if g and (collision or 0)~=0 and g.base[mid] then
  return {kind='tree',root=true,general=true,ground=ground,anchorX=8,anchorZ=12,art={{g.top},{mid}},artTipRows=1}
 end
end

function M.claim(cells)
 for _,c in pairs(cells)do
  local n=M.FAMILIES[c.secondary] and M.NARROW[c.secondary]
  if n then
   for _,o in ipairs(n.over)do
    if c.mid==o then
     local south=cells[c.cx..':'..(c.cy+1)]
     if south and south.shape and south.shape.narrow then c.treeOwned=true end
    end
   end
  end
  local g=M.FAMILIES[c.secondary] and M.GENERAL[c.secondary]
  if g then
   if c.shape and c.shape.general then
    local north=cells[c.cx..':'..(c.cy-1)]
    if north and (north.collision or 0)==0 and north.mid==g.top then
     c.shape.art={{north.mid},{c.mid}};c.shape.crownFloor=true
    end
   end
   for _,o in ipairs(g.over)do
    if c.mid==o then
     local south=cells[c.cx..':'..(c.cy+1)]
     if south and south.shape and south.shape.general then c.treeOwned=true end
    end
   end
  end
 end
end
return M
