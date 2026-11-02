-- House stairs drawn as a doorway in the back wall
local M={}
M.CELLS={
 building__brendans_mays_house={[0x211]='up',[0x214]='down'},
 building__generic_building={[0x20B]='up',[0x219]='down'}, -- Rustboro flats, Cove Lily Motel
 building__facility={[0x393]='up',[0x396]='down'}, -- Devon Corp
 general__facility={[0x393]='up',[0x396]='down',[0x2BC]='up',[0x2CC]='down'},
 building__shop={[0x250]='up',[0x251]='down'}, -- Lilycove Department Store
 building__oceanic_museum={[0x20E]='up',[0x20F]='down'},
 building__lilycove_museum={[0x20E]='up',[0x273]='down'},
 building__lab={[0x285]='up',[0x283]='down'}, -- Weather Institute
 building__mossdeep_game_corner={[0x20B]='up',[0x203]='down'},
 building__trainer_hill={[0x21E]='up',[0x219]='down'},
 building__sootopolis_gym={[0x21C]='up',[0x214]='down'},
}
function M.kind(c)
 local t=M.CELLS[c.pair or '']
 local k=t and t[c.mid]
 if k and (c.collision or 0)~=7 and (c.collision or 0)~=0xFF then return k end
end
local function swatch(uv,x,y)
 local u=uv[1][1]+(uv[2][1]-uv[1][1])*(x+.5)/16
 local v=uv[1][2]+(uv[3][2]-uv[1][2])*(y+.5)/16
 return {{u,v},{u,v},{u,v},{u,v}}
end
function M.append(c,quad,uvFor,frameMid)
 local k=M.kind(c);if not k then return false end
 local uv=uvFor(c.ts,c.mid);if not uv then return false end
 local fuv=frameMid and uvFor(c.ts,frameMid) or uv
 local x,z=c.cx*16,c.cy*16
 local tread=swatch(uv,8,12) -- the light step colour in the doorway art
 local riser=swatch(uv,8,9)
 local cheek=swatch(fuv,1,8) -- the gold frame
 local dark=swatch(uv,8,2)
 local x0,x1=x+2,x+14
 local function box(a,y0,c0,b,y1,c1,t,shade)
  quad({{a,y1,c0},{b,y1,c0},{b,y1,c1},{a,y1,c1}},t,1)
  quad({{a,y1,c1},{b,y1,c1},{b,y0,c1},{a,y0,c1}},t,(shade or 1)*.85)
  quad({{a,y1,c0},{a,y1,c1},{a,y0,c1},{a,y0,c0}},t,(shade or 1)*.72)
  quad({{b,y1,c1},{b,y1,c0},{b,y0,c0},{b,y0,c1}},t,(shade or 1)*.72)
 end
 if k=='up' then
  for i=0,3 do
   local h=(i+1)*4
   local zf=z+16-i*4
   box(x0,0,zf-4,x1,h,zf,tread)
   quad({{x0,h,zf},{x1,h,zf},{x1,h-4,zf},{x0,h-4,zf}},riser,.8)
  end
  box(x,0,z,x0,18,z+16,cheek,.9)
  box(x1,0,z,x+16,18,z+16,cheek,.9)
 else
  quad({{x0,-16,z},{x1,-16,z},{x1,-16,z+16},{x0,-16,z+16}},dark,.5)
  quad({{x0,0,z},{x0,0,z+16},{x0,-16,z+16},{x0,-16,z}},dark,.6)
  quad({{x1,0,z+16},{x1,0,z},{x1,-16,z},{x1,-16,z+16}},dark,.6)
  for i=0,3 do
   local h=-(i+1)*4
   local zf=z+16-i*4
   quad({{x0,h,zf-4},{x1,h,zf-4},{x1,h,zf},{x0,h,zf}},tread,.9-i*.08)
   quad({{x0,h+4,zf},{x1,h+4,zf},{x1,h,zf},{x0,h,zf}},riser,.7-i*.06)
  end
  quad({{x,0,z},{x0,0,z},{x0,0,z+16},{x,0,z+16}},cheek,1)
  quad({{x1,0,z},{x+16,0,z},{x+16,0,z+16},{x1,0,z+16}},cheek,1)
 end
 return true
end
return M
