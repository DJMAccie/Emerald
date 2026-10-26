-- Hand-authored tile tables for rock classes the 3DS method has no tables for (mirror of
-- tools/relief/rock_tables.py; tests/gen3_relief_test.lua checks they agree).
local M={}
-- the Fallarbor tileset's brown terrace: face / end / band tiles and the light ground tops
M.BROWN={[0x268]='face',[0x269]='face',[0x26A]='end',[0x270]='band',[0x278]='face',[0x27A]='end',[0x271]='top',[0x279]='top'}
M.BROWN_TREES={[0x26B]=true,[0x26C]=true,[0x273]=true,[0x274]=true}
-- the Lavaridge tileset's red rock (Route 112's east ridge, Mt. Chimney): bands, faces, ends, light tops
M.RED_MAPS={EM_ROUTE112=true,EM_MT_CHIMNEY=true,EM_JAGGED_PASS=true}
M.RED={[0x270]='band',[0x272]='band',[0x274]='face',[0x278]='face',[0x279]='end',[0x27A]='end',[0x27B]='end',[0x27C]='end',[0x289]='band',
 [0x269]='top',[0x271]='top',[0x27D]='top',[0x27E]='top',[0x27F]='top'}
return M
