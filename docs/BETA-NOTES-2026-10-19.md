# Beta notes, 2026-10-19 (draft: not yet installed or tagged)

Engine: gen1recomp v0.3.52 (the version the user plays). Mod: battle-art-voxel-fork patch.

## In this beta (since the last walkthrough)
- Trees and small rocks stand on their ground (7d2daf5).
- Route 115: the shore-bluff end pieces (cells 11,62-63 and 14,61) are a low rock edge joined to the bluff, not a pillar (Gen3Rock.lua, Route 115 only).
- Meteor Falls (1F, B1F, 2R maps): a lone cave-wall cell is a normal wall piece, not a dark dome blob (Gen3Rock.lua, Meteor Falls only).

## Checks run on the Gen3Rock.lua change
- Capture sweep: 57 outdoor + cave maps, 0 fallbacks, same single (old) error line with and without.
- Census over 164 maps: only Route 115, Meteor Falls (+ Route 111/119/Lilycove/other caves, deliberately excluded) match the new rules.
- Cave maps outside Meteor Falls (Desert Ruins, Island Cave, Ancient Tomb, Fiery Path, Sky Pillar 4F) render pixel-identical to before.
- Floating-rock audit (Gen3Rock.audit) over 164 maps: no new floats.
- Frame time: 59.8-60 fps with and without the change on Route 115 and Meteor Falls 1F (vsync-bound, offscreen).

## Known issues (not fixed here)
- Floating rock masses (audit, existing before this change): Mossdeep City (45,7; 13 px up), Route 112 (19,42; ~10 px up), Route 103 (24,14; 4 px up).
- Route 115 end piece at 14,61 is sand-coloured, flat (matches the beach beside it, not rock-coloured).
- Ledge geometry and the Route 115 stair gradient belong to the ledge session and are not part of this change.
- The Desktop launcher "Play Emerald 3D (v0.3.52).command" is no longer on the Desktop; ~/Documents/gen1recomp/Play-Mac.command exists.
- The old app shell (0.1.50) still falls back to the bundled game; see memory emerald-game-version.

## Rollback
Install backs up the previous lib file to ~/Documents/gen1recomp-modwork/backups/ before copying. To roll back: copy the backup of Gen3Rock.lua over the game, source and QA lib copies, then tools/props/make_patch.sh (OWN_LIB_EXTRA="lib/Gen3Rock.lua") and commit the patch.
