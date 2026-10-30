local HB={ {-26.5,.55},{-26,1.5},{-25,2.9},{-24,4.1},{-23,5.2},{-22,6.1},{-21,6.9},{-20,7.6},{-18.5,8.4},{-17,9.0},{-15,9.5},{-12,9.85},{-8,10},{-4,10},{-1,9.8},{.5,9.2},{1.5,8.4}}
local function curve(t,v)
 if v<=t[1][1] then return t[1][2] end
 for n=2,#t do
  local a,b=t[n-1],t[n]
  if v<=b[1] then local f=(v-a[1])/(b[1]-a[1]);f=f*f*(3-2*f);return a[2]+(b[2]-a[2])*f end
 end
 return t[#t][2]
end
for z=-26.5,0.5 do
  local i0=curve(HB,z)+.45-1.5
  local i1=curve(HB,z+1)+.45-1.5
  print(string.format('z %.1f i0 %.2f i1 %.2f  x %d..%d',z,i0,i1,math.ceil(-i0),math.floor(i1)-1))
end
