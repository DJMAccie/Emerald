# Stage 1 (not installed): Gen3Relief for the pink and beige mountains

Probe-tree copies of the files the mod needs; the mod source is untouched until the user signs the
pink/beige sheets (docs/rock-gates). Rebuild the data: `python3 tools/relief/bake_lua.py lib/Gen3ReliefData.lua Route111 Route114`.

- lib/Gen3Relief.lua      new: claims a General/beige mass, lays the baked relief (probe: M.MAPS = Route 111, 114)
- lib/Gen3ReliefData.lua  generated (bake_lua.py)
- lib/Gen3Hills.lua       one change: exports M.sub, M.steep at the end
- lib/Gen3Rock.lua        two lines: handles() and append() ask Gen3Relief before Gen3Hills
- tests/gen3_relief_test.lua   run from the mod root: `luajit tests/gen3_relief_test.lua`

Install (after sign-off): back up, copy the four lib files + test into battle-art-notquiteog (the game's mod folder is a
symlink to it), `OWN_LIB_EXTRA="lib/Gen3Relief.lua lib/Gen3ReliefData.lua lib/Gen3Hills.lua lib/Gen3Rock.lua" tools/props/make_patch.sh`.
