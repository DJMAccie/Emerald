# Beta notes, 2026-10-20 (draft: nothing installed or tagged by this note)

Engine gen1recomp v0.3.52. Mod: battle-art-voxel-fork patch (HEAD 1b0efaa and earlier). Builds on [BETA-NOTES-2026-10-19.md](BETA-NOTES-2026-10-19.md).

## Checked today
- Sweep: 158 cases (53 outdoor spots from docs/ledger/outdoor_spots.txt + 105 cave maps at their centre cell), level 4, QA_ZOOM=-2, via qa_tryp.sh: 158 shots, 0 fallbacks to 2D. The only error line is the old `requires src.world.Map` one, once per run (same as before).
- Note for QA: the QA copy lacks lib/Gen3Waterfall.lua (the game copy has it), so a plain qa_run.sh sweep falls back everywhere. Use qa_tryp.sh "Gen3Waterfall.lua" until QA is synced.
- Route 112 19,42 and Route 103 24,14 floats: a Gen3Hills skirt change lowered the skirt next to 19,42 from 38.4 to 28.8 but was not visible in shots; reverted at the user's request (source == installed). Both stay open.

## Not done
- Props audit (prop base == ground): no tool exists for trees; only Gen3Rock.audit for rocks, which did not print the known R103 float when driven by hand, so it is not trusted. Not run.
- Frame-time probe, launcher, version tag: skipped to stay lean.

## Known issues
- Floating rocks: Route 112 19,42 (~10 px), Route 103 24,14 (4 px) (ledger F006, F007).
- Route 115 end piece 14,61 sand-coloured and flat (F008); ledges and R115 stair gradient owned by another session.
- Interiors and first-person polish still in progress (docs/LEDGER.md).
- No Desktop launcher; ~/Documents/gen1recomp/Play-Mac.command is the stock Pokémon Red launcher.

## Rollback
Installs back up the previous lib file to ~/Documents/gen1recomp-modwork/backups/; copy it back over the game, source and QA lib, rerun `OWN_LIB_EXTRA="lib/X.lua" tools/props/make_patch.sh`, commit the patch.
