local V=dofile('tests/modload.lua').namespace()
local released={}
local S=V.require('SceneStream').new(function(v)released[#released+1]=v end,4)
local function builder(tag)return function(v)v.tag=tag;coroutine.yield('budget');return v end end
local hooks={enter=function()end,leave=function()end}
local function settle(key,ctx,tag)local r;for _=1,10 do r=S:update(key,ctx,builder(tag),1,1);if r then return r end end end
settle('a1','A','A')
assert(S.active and S.active.tag=='A')
-- a map warmed ahead takes slices only while nothing else builds, then waits among the retained scenes
local steps=0
repeat S:warm('b1','B',builder('B'),1,hooks);steps=steps+1 until S:has('B') or steps>10
assert(S:has('B') and not S.warming,'warm scene never finished')
-- crossing: the same map in another window shows the warm scene at once instead of nothing
local scene=S:update('b9','B',builder('B2'),1,1)
assert(scene and scene.tag=='B','warm scene not used after crossing')
assert(S.context=='B' and S:has('A'),'old scene not retained for the way back')
for _=1,10 do S:update('b9','B',builder('B2'),1,1)end;assert(not S.pending)
-- a build in flight for the next window waits for a warm scene instead of cancelling it
S:warm('c1','C',builder('C'),1,hooks);assert(S.warming)
assert(S:update('b10','B',builder('B3'),1,1).tag=='B2' and S.warming,'window build cancelled the warm scene')
-- a cold build for another map drops a warm scene of a third map
S:warm('e1','E',builder('E'),1,hooks);assert(S.warming)
settle('d1','D','D')
assert(not S.warming and #released>=1,'stale warm scene kept')
print('PASS warm-ahead scenes: built when idle, used at the crossing, never cancelled by a window build')
