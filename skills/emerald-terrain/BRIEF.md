# Brief: continue the Emerald 3D terrain pass

You are taking over terrain and rock work on the Pokémon Emerald 3D voxel mod.
**First read `skills/emerald-terrain/SKILL.md` in full.** It has the code map, test commands, install
steps and the user's taste. This brief says what to do next and how to report.

## Rules

- Work one problem at a time: reproduce, find the cause, fix it for every place with the same cause.
- Never commit in `~/Documents/battle-art-notquiteog`. Commit only in `~/Documents/Emerald`
  (the regenerated patch plus any tools), then push `main`.
- Never edit the real game's files except to install a finished, checked change (backup first).
- Check each change at the player (4), low (6) and orbit (7) cameras, then run a before/after sweep
  on many maps and look at every image. If anything else got worse, undo the change.
- Don't "fix" by removing depth or detail. More 3D than the flat original is wanted.
- If unsure what the user wants, ask. Don't guess at big style changes.

## Tasks, in order

1. **Floating ground past Route 112's west edge.** From the orbit camera at `{'EM_ROUTE112',27,29}`
   (level 7, yaw 2.2) flat plates float west of the map. They are fill cells outside the map
   (tile 0x308, `boundary=ground` in a `dump=`) at heights 48 and 32 with nothing under them.
   Find where boundary fill cells get their height (`Gen3Boundary.lua`, the nearest-floor pass in
   `TerrainLevels.lua`) and either close the step under them or keep them on the ground.
   Check Routes 111, 112, 113, 114 and Mt. Chimney edges afterwards.
2. **Rustboro's lamp posts.** Look at them at `{'EM_RUSTBORO_CITY',21,20}` and `{'EM_RUSTBORO_CITY',15,57}`
   from all cameras, compare with the original art (`crop2d.py 0_3 general__rustboro ...`), fix if they
   read wrong (flat cards, leaning, wrong height).
3. **Mt. Pyre's rock** (`EM_MT_PYRE_EXTERIOR`, `EM_MT_PYRE_SUMMIT`) still uses square blocks
   (`Gen3Rock.SMOOTH_SKIP`). Try a version that keeps the graveyard walls crisp but softens the outer
   mountain. Show the user before/after and let them choose.
4. **Route 104 pier planks** read slightly as separate slats up close (`Gen3Scene.lua`, `shape.kind=='pier'`).
   Low priority; an earlier attempt to fill the gaps looked worse.
5. Then ask the user for their next walk-through screenshots. Those are the real work queue.

## When you finish each task

- Install (backup, copy to real game and QA, `diff -rq` all three equal).
- Regenerate the patch with the `make_patch.sh` command in SKILL.md, grep it for your change, commit
  with a plain-language message (what it looked like, why, what it is now), push.
- Make a before/after image in `~/Documents/Emerald/docs/shots/` and send it to the user.
- Tell the user, in plain words, what changed, how you checked it, what is still open, and to
  restart their game.
- Add anything new you learned to the "Lessons" or "Open items" sections of SKILL.md.
