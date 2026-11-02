-- Gen3FlyPath
local M={}

M.MOUNT=.9 -- s: the Pokemon swoops in and the player hops on
M.DISMOUNT=1.1 -- s: the player hops off and the Pokemon leaves
M.T_BASE,M.T_PER,M.T_MIN,M.T_MAX=3,700,4,11
M.H_BASE,M.H_PER,M.H_MIN,M.H_MAX=96,.12,140,420
M.RISE=.30 -- share of the flight spent climbing
M.FALL=.34 -- share spent coming down
M.SWAP=.42
M.WAIT_RATE=.15

local function clamp(x,a,b)if x<a then return a elseif x>b then return b end return x end
M.clamp=clamp
function M.smooth(x)x=clamp(x,0,1);return x*x*(3-2*x)end

function M.duration(L)return clamp(M.T_BASE+(L or 0)/M.T_PER,M.T_MIN,M.T_MAX)end
function M.height(L)return clamp(M.H_BASE+M.H_PER*(L or 0),M.H_MIN,M.H_MAX)end

function M.progress(t,T)return M.smooth(t/T)end
function M.altitude(t,T,H)
 local u=clamp(t/T,0,1)
 return H*M.smooth(u/M.RISE)*M.smooth((1-u)/M.FALL)
end
function M.blend(t,T)
 local u=clamp(t/T,0,1)
 return M.smooth(u/(M.RISE*.8))*M.smooth((1-u)/(M.FALL*.9))
end
function M.rate(t,T,ready)
 if ready or t<T*(1-M.FALL) then return 1 end
 return M.WAIT_RATE
end

function M.at(a,b,s,h)
 return {a[1]+(b[1]-a[1])*s,a[2]+(b[2]-a[2])*s+h,a[3]+(b[3]-a[3])*s}
end

function M.fit(samples)
 local function axis(i,j)
  local n,sx,sy,sxx,sxy=0,0,0,0,0
  for _,s in ipairs(samples)do local x,y=s[i],s[j];n=n+1;sx=sx+x;sy=sy+y;sxx=sxx+x*x;sxy=sxy+x*y end
  if n<2 then return nil end
  local d=n*sxx-sx*sx
  if math.abs(d)<1e-9 then return nil end
  local a=(n*sxy-sx*sy)/d
  return a,(sy-a*sx)/n
 end
 local ax,bx=axis(1,3);local ay,by=axis(2,4)
 if not (ax and ay) then return nil end
 return {ax=ax,bx=bx,ay=ay,by=by,n=#samples}
end
function M.place(fit,rx,ry,w,h)
 return math.floor(fit.ax*rx+fit.bx-w/2+.5),math.floor(fit.ay*ry+fit.by-h/2+.5)
end

function M.toOrbit(eye,focus)
 local dx,dy,dz=focus[1]-eye[1],focus[2]-eye[2],focus[3]-eye[3]
 local flat=math.sqrt(dx*dx+dz*dz)
 local dist=math.sqrt(dx*dx+dy*dy+dz*dz)
 local yaw=flat>1e-6 and math.atan2(dx,-dz) or 0
 return {f={focus[1],focus[2],focus[3]},yaw=yaw,pitch=math.atan2(-dy,math.max(flat,1e-6)),dist=dist}
end
function M.fromOrbit(o)
 local p=clamp(o.pitch,-1.5,1.5)
 local c=math.cos(p)
 local vx,vy,vz=math.sin(o.yaw)*c,-math.sin(p),-math.cos(o.yaw)*c
 return {o.f[1]-vx*o.dist,o.f[2]-vy*o.dist,o.f[3]-vz*o.dist},{o.f[1],o.f[2],o.f[3]}
end
local function lerp(a,b,w)return a+(b-a)*w end
function M.blendOrbit(a,b,w)
 local dy=(b.yaw-a.yaw+math.pi)%(2*math.pi)-math.pi
 return {f={lerp(a.f[1],b.f[1],w),lerp(a.f[2],b.f[2],w),lerp(a.f[3],b.f[3],w)},
  yaw=a.yaw+dy*w,pitch=lerp(a.pitch,b.pitch,w),dist=lerp(a.dist,b.dist,w)}
end

M.CHASE={pitch=math.rad(48),dist=150,distPerH=.75,lead=48}
M.OVERHEAD={pitch=math.rad(72),dist=170,distPerH=.9,lead=0}
function M.flightOrbit(r,dx,dz,h,follow)
 local c=follow and M.CHASE or M.OVERHEAD
 local yaw=follow and math.atan2(dx,-dz) or 0
 local lead=c.lead
 return {f={r[1]+dx*lead,r[2]-h*.15,r[3]+dz*lead},yaw=yaw,pitch=c.pitch,dist=c.dist+c.distPerH*(h or 0)}
end

function M.clouds(a,b,H,seed)
 local s=math.floor(math.abs(seed or 1))%2147483647;if s==0 then s=1 end
 local function rnd()s=(s*16807)%2147483647;return s/2147483647 end
 local dx,dz=b[1]-a[1],b[3]-a[3]
 local L=math.sqrt(dx*dx+dz*dz)
 local ux,uz=L>0 and dx/L or 0,L>0 and dz/L or -1
 local out={}
 local n=math.max(6,math.floor((L+800)/260))
 for i=1,n do
  local along=-300+rnd()*(L+600)
  local side=(rnd()*2-1)*(380+H)
  out[#out+1]={a[1]+ux*along-uz*side,H*(.45+.4*rnd()),a[3]+uz*along+ux*side,1.8+rnd()*1.6}
 end
 return out
end

M.BEAT={mount=1.4,climb=1.5,cruise=1,descent=.8,flare=1.9,hover=1.1,away=1.5}
M.GLIDE_EVERY=2.4
M.FLARE=.12 -- the last share of the flight spent flaring
function M.beatRate(phase,t,T,h,H)
 if phase=='mount' then return M.BEAT.mount,false end
 if phase=='dismount' then return (t<(T or M.DISMOUNT)*.4) and M.BEAT.hover or M.BEAT.away,false end
 local u=clamp(t/T,0,1)
 if u>1-M.FLARE then return M.BEAT.flare,false end
 if (h or 0)>=.92*(H or 1) then return M.BEAT.cruise,true end
 if u<.5 then return M.BEAT.climb,false end
 return M.BEAT.descent,false
end
-- Frame index is 0-based.
function M.frameAt(b,frames,durations)
 local u=b%1
 if not durations or #durations==0 then return math.floor(u*frames)%frames end
 local total=0;for i=1,#durations do total=total+durations[i] end
 local tick=u*total
 for i=1,#durations do tick=tick-durations[i];if tick<0 then return (i-1)%frames end end
 return frames-1
end
function M.beatStep(st,dt,o)
 local f=M.frameAt(st.beat or 0,o.frames,o.durations)
 if o.glide and (st.free or 0)<=0 and f==(o.glideFrame or 0) then
  st.held=(st.held or 0)+dt
  if st.held>=M.GLIDE_EVERY then st.held=0;st.free=1 end
  return f
 end
 if not o.glide then st.held=0 end
 local adv=dt*o.mult/math.max(.05,o.cycle)
 st.beat=(st.beat or 0)+adv
 if (st.free or 0)>0 then st.free=st.free-adv end
 return M.frameAt(st.beat,o.frames,o.durations)
end
M.SLACK=math.rad(10)
local ROW_ANGLE={up=0,right=math.pi/2,down=math.pi,left=-math.pi/2}
local function wrap(a)return (a+math.pi)%(2*math.pi)-math.pi end
function M.rowFor(rel,prev)
 rel=wrap(rel)
 if prev and ROW_ANGLE[prev] and math.abs(wrap(rel-ROW_ANGLE[prev]))<=math.pi/4+M.SLACK then return prev end
 if math.abs(rel)<math.pi/4 then return 'up' elseif math.abs(rel)>3*math.pi/4 then return 'down' elseif rel>0 then return 'right' end
 return 'left'
end
function M.mountScale(height)return clamp(math.sqrt((tonumber(height) or 10)/10),.75,1.8)end
M.PITCH_MAX,M.PITCH_PER=.28,.0035
function M.pitchStep(prev,climb,dt)
 local target=clamp((climb or 0)*M.PITCH_PER,-M.PITCH_MAX,M.PITCH_MAX)
 return (prev or 0)+(target-(prev or 0))*math.min(1,(dt or 0)*4)
end

return M
