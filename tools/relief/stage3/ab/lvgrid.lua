-- lvgrid.lua MAP x0 y0 x1 y1 : mean counted level (tenths of a level) per cell from the baked data; '.' no data
local D=dofile('/Users/user/Documents/Emerald/tools/relief/stage3/ReliefData_all.lua')
local m=D[arg[1]]
local x0,y0,x1,y1=tonumber(arg[2]),tonumber(arg[3]),tonumber(arg[4]),tonumber(arg[5])
print(arg[1],'w',m.w,'h',m.h)
io.write('     ');for x=x0,x1 do io.write(string.format('%3d',x)) end io.write('\n')
for y=y0,y1 do
 io.write(string.format('%4d ',y))
 for x=x0,x1 do
  local s=m.cells[y*m.w+x+1]
  if not s then io.write('  .') else
   local gs=s:match('^([^|]*)|')
   local sum,n,mx,mn=0,0,-1e9,1e9
   for v in gs:gmatch('%-?%d+')do v=tonumber(v);sum=sum+v;n=n+1;mx=math.max(mx,v);mn=math.min(mn,v) end
   local l=sum/n/16
   io.write(string.format('%3d',math.floor(l*2+.5)))   -- half levels
  end
 end
 io.write('\n')
end
