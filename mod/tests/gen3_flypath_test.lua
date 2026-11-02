-- Gen3FlyPath: the shape of a Fly flight (run from the mod root: luajit tests/gen3_flypath_test.lua).
local V
V={require=function(name) return assert(loadfile('lib/'..name..'.lua'))(V) end}
local P=V.require('Gen3FlyPath')
local function near(a,b,eps,msg)assert(math.abs(a-b)<=(eps or 1e-6),(msg or '')..': '..tostring(a)..' vs '..tostring(b))end

-- durations and heights clamp
near(P.duration(0),P.T_MIN,0,'short flight floor')
near(P.duration(1e6),P.T_MAX,0,'long flight ceiling')
assert(P.duration(2000)>P.duration(500),'longer flights take longer')
near(P.height(0),P.H_MIN,0,'low ceiling floor');near(P.height(1e6),P.H_MAX,0,'height ceiling')

-- progress: 0 -> 1, never backwards, fastest in the middle
for _,T in ipairs({4,7,11})do
 near(P.progress(0,T),0,1e-9,'starts at the start');near(P.progress(T,T),1,1e-9,'ends at the end')
 local last,peak,peakAt=-1,0,0
 for i=0,200 do
  local t=T*i/200;local s=P.progress(t,T);assert(s>=last-1e-12,'progress never goes back');
  if i>0 then local v=s-last;if v>peak then peak,peakAt=v,t end end
  last=s
 end
 assert(math.abs(peakAt/T-.5)<.05,'top speed mid-flight ('..peakAt/T..')')
 -- height: 0 at both ends, the cruise height in the middle, climbing before the speed peaks
 local H=300
 near(P.altitude(0,T,H),0,1e-9,'takes off from the ground');near(P.altitude(T,T,H),0,1e-9,'lands on the ground')
 near(P.altitude(T*.5,T,H),H,1e-9,'cruise height mid-flight')
 assert(P.altitude(T*.2,T,H)>H*.5 and P.progress(T*.2,T)<.15,'climbs early while still slow')
 assert(P.altitude(T*.85,T,H)<H*.6 and P.progress(T*.85,T)>.9,'comes down late while braking')
 -- camera blend: the player's camera at both ends, the flight camera in cruise
 near(P.blend(0,T),0,1e-9,'own camera at take-off');near(P.blend(T,T),0,1e-9,'own camera at landing')
 near(P.blend(T*.5,T),1,1e-9,'flight camera in cruise')
end
-- the clock slows over the descent only while the town is not built
near(P.rate(1,10,false),1,0,'full speed on the way out');near(P.rate(9,10,false),P.WAIT_RATE,0,'waits on the descent')
near(P.rate(9,10,true),1,0,'no wait when built')

-- region map fit: a known linear world, one map held out
local samples={}
local truth=function(rx,ry)return 40*rx+12,30*ry-50 end
for _,r in ipairs({{4.5,11.5},{4.5,9.5},{2.5,14.5},{8.5,11},{21.5,7.5},{27.5,9},{17.5,10.5},{5.5,3.5}})do
 local wx,wy=truth(r[1],r[2]);samples[#samples+1]={r[1],r[2],wx+(#samples%2==0 and 1 or -1),wy}
end
local fit=assert(P.fit(samples),'fit')
local ox,oy=P.place(fit,22.5,12.5,20,20)
local tx,ty=truth(22.5,12.5)
assert(math.abs(ox-(tx-10))<=2 and math.abs(oy-(ty-10))<=2,'held-out map placed near its true cell ('..ox..','..oy..')')
assert(P.fit({{1,1,1,1}})==nil,'one sample is no fit')

-- camera orbit round trip and blend
local eye,focus={10,120,300},{10,0,200}
local o=P.toOrbit(eye,focus);local e2,f2=P.fromOrbit(o)
for i=1,3 do near(e2[i],eye[i],1e-6,'orbit eye '..i);near(f2[i],focus[i],1e-6,'orbit focus '..i)end
near(o.yaw,0,1e-9,'looking north')
local a={f={0,0,0},yaw=math.rad(170),pitch=.5,dist=100}
local b={f={0,0,0},yaw=math.rad(-170),pitch=.5,dist=100}
near(P.blendOrbit(a,b,.5).yaw%(2*math.pi),math.pi,1e-9,'turns the short way round')
local m=P.blendOrbit(a,b,0);near(m.yaw,a.yaw,1e-9,'blend 0 = start')
local fo=P.flightOrbit({0,200,0},1,0,200,true);near(fo.yaw,math.pi/2,1e-9,'chase looks east when flying east')
assert(P.flightOrbit({0,0,0},0,1,400,false).dist>P.flightOrbit({0,0,0},0,1,100,false).dist,'higher = farther back')

-- clouds: same seed, same sky
local c1=P.clouds({0,0,0},{2000,0,0},300,77);local c2=P.clouds({0,0,0},{2000,0,0},300,77)
assert(#c1==#c2 and #c1>=6,'cloud count')
for i=1,#c1 do for k=1,4 do near(c1[i][k],c2[i][k],0,'cloud '..i)end;assert(c1[i][2]>=135 and c1[i][2]<=255,'cloud height')end
-- wing beats: fast on the climb, a held glide at cruise height with a beat now and then, a flare at the end
local T,H=8,300
assert(P.beatRate('fly',T*.2,T,H*.5,H)>P.beatRate('fly',T*.7,T,H*.5,H),'climbs on quicker beats than it descends')
local _,glide=P.beatRate('fly',T*.5,T,H,H);assert(glide,'glides at cruise height')
assert(P.beatRate('fly',T*.95,T,H*.1,H)==P.BEAT.flare,'flares before touchdown')
near(P.frameAt(0,4),0,0,'frame 0 at the start');near(P.frameAt(.5,4),2,0,'half way = frame 2');near(P.frameAt(1.25,4),1,0,'wraps')
near(P.frameAt(.5,4,{8,10,8,10}),2,0,'PMD durations: half the ticks = frame 2')
do
 local st={beat=0};local o={mult=1,glide=true,cycle=.4,frames=4,glideFrame=2}
 local seen={}
 for i=1,600 do seen[#seen+1]=P.beatStep(st,1/60,o)end
 local held=0;for i=60,100 do if seen[i]==2 then held=held+1 end end
 assert(held==41,'holds the glide frame ('..held..')')
 local beat=false;for i=150,300 do if seen[i]~=2 then beat=true end end
 assert(beat,'beats once after GLIDE_EVERY')
 local st2={beat=0};local o2={mult=1.5,glide=false,cycle=.4,frames=4,glideFrame=2};local changes,last=0,nil
 for i=1,60 do local f=P.beatStep(st2,1/60,o2);if f~=last then changes=changes+1;last=f end end
 assert(changes>=14,'keeps beating when not gliding ('..changes..')')
end
-- facing rows, sticky near the 45-degree line
assert(P.rowFor(0)=='up' and P.rowFor(math.pi)=='down' and P.rowFor(1.2)=='right' and P.rowFor(-1.2)=='left','rows')
assert(P.rowFor(math.rad(50),'up')=='up','stays up just past the line')
assert(P.rowFor(math.rad(60),'up')=='right','turns once well past it')
assert(P.rowFor(math.rad(40),'right')=='right','sticky the other way too')
-- size from the Pokedex height
near(P.mountScale(3),.75,0,'small floor');near(P.mountScale(70),1.8,0,'big ceiling');near(P.mountScale(10),1,1e-9,'1 m = 1')
-- pitch eases toward the climb, nose up on the way up
local p=0;for i=1,120 do p=P.pitchStep(p,200,1/60)end;assert(p>.25,'nose up climbing')
p=0;for i=1,120 do p=P.pitchStep(p,-200,1/60)end;assert(p<-.25,'nose down diving')
print('gen3_flypath_test: PASS')
