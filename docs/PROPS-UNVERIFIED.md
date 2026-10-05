# Sonnet: changes not yet verified in game (night of 2026-10-05)

In-game QA stopped working after ~23:00 (no LÖVE window can present a frame). Everything below is
syntax-checked only. NOT installed in the real game. Check each at the three cameras
(`tools/props/audit_capture.sh` with `EM_LEVEL=4`, `EM_LEVEL=7 EM_YAW=0.9`, `EM_LEVEL=6 EM_YAW=0.5`;
or `tools/qa_run.sh`).

| Change | File | Check where | Expect |
|---|---|---|---|
| Slateport tile 0x243 (round bush beside the Pokémon Center / Contest hall) becomes a shrub, not a building wall | `lib/Gen3EmeraldShapes.lua` (`PINS.slateport[0x243]='shrub'` + the `pin=='shrub'` line) | `EM_SLATEPORT_CITY` stand at (15,13), look at x=8 and x=14, y=10..12 | round bushes on grass instead of green boxes; level 7 shows no tall green slab |
| `tools/props/audit_capture.sh` now takes the shared lock `/tmp/emerald-qa.lock`, restores the QA engine payload, scales its watchdog | `tools/props/audit_capture.sh` | any run | `shots N fallback 0`, no WATCHDOG |

Everything else of mine in the real game was verified at the player's camera, and since the signs batch
at three cameras (see docs/PROPS-AUDIT.md for what and where).

## Ideas worth doing next (not started: they need eyes)
- Grove banks (`Gen3Objects.prepare` grove -> `bank` cliff shapes) are domes textured with tile art; from
  the side (level 7) they read as striped walls. Candidate: render groves as rows of round trees.
- Sea-boulder chains and shoreline overlap: see `docs/PROPS-AUDIT.md` open list.
