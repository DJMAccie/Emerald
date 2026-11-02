local B=assert(loadfile('lib/BattleOcclusion.lua'))()
local eye={0,24,0}
local arena={player={0,48},enemy={32,80}}
local cut=B.build(eye,arena,0,{player={contentWidth=56,contentHeight=56},
  enemy={contentWidth=112,contentHeight=56}})
assert(cut and cut.floor==-23.75)
assert(#cut==2 and cut[1][4] and cut[2][4],'both battler groups get a cut volume')
-- The draw shader's height gate preserves the supporting terrain plane.
assert(0-eye[2]<=cut.floor)
assert(B.build(eye,nil,0)==nil,'leaving battle retains a cut volume')
print('Battle occlusion: both groups and floor PASS')
