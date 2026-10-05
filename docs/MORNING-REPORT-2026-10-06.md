# Morning report, 2026-10-06 (work overnight from 5 Oct)

## Read this first
- **Your game now runs the newest version.** Double-click **`Play Emerald 3D (v0.3.52).command`** on your Desktop.
  Your app (`/Applications/gen1recomp.app`, the old 0.1.50 shell) downloads 0.3.52 but fails to hand off to it
  (`setHotkeyHandler` error) and opens its old bundled game. That is why it "kept opening the old version". The
  launcher runs 0.3.52 directly with your normal saves and mods. A fresh app download from the official release
  would also fix it; that's your call.
- **No in-game checks were possible after about 23:00.** With the display off, no game window on this Mac could
  draw a frame. Even a 5-line LÖVE test stalled, so I couldn't screenshot anything. Everything built after that
  is committed but marked UNVERIFIED and NOT installed in your game. The first thing to run this morning is
  `tools/morning_check.sh`: it captures every unverified item at the three cameras (player's camera, turned,
  low) and makes contact sheets in `shots_morning/sheets/`.

## Installed in your game (checked in game before 23:00)
- **Engine:** the test checkout moved to v0.3.52, the version you play. Smoke-tested: towns, interiors and
  furniture all render in 3D with no errors.
- **Furniture:** the extra depth (pieces about 1.6x taller, legs longer, cabinets taller) and the hidden sides
  in the piece's own colour.
  - Brendan's/May's house.
  - The 73 shared houses: tables, chairs, beds, wardrobes, kitchens, bookshelves, drawers.
  - Sootopolis, Pacifidlog and the Rustboro flats.
  - Pokémon Center stools and glass table.
  - Furniture agent: Rustboro school desks, gym statues, the Fortree Gym platform (Winona stands on it) and its
    round tree stumps with bark all round, the gym gates and bushes.
- **The van:** solid across its whole 3D model (you can no longer stand inside it). It is rebuilt 1:1 from its
  sprite, and the trucks were checked at four angles.
- **Shallow water:** standing in it (Mossdeep beach, Route 109) no longer flips the whole view to flat 2D.
- **Route 113:** the false pink dome is gone.
- **Sonnet:** Route 119 river holes closed; signs rebuilt with taller posts and thick boards; bridge decks as
  thin plates.

## Built overnight, UNVERIFIED (in the mod source and patch, not installed)
- **Opus:**
  - **Sootopolis terraces.** The authored terrace heights now apply (they were silently outvoted before). The
    city stands on 8 levels from 0 to 112 px. Offline check: zero walkable seams where you'd climb a wall.
  - **Buildings stand on the floor in front of their door,** not on a higher terrace behind them (a Sootopolis
    house was floating).
  - **Water:** one flat level per water body, split at waterfalls (the Route 119 river staircase).
  - **Stair platforms** (OFF until checked): Battle Frontier East (the Battle Tower plaza and the Arena island)
    and both Safari Zone areas are raised where stairs climb. Generated from the stair cells, 12 px per stair
    row (Battle Tower plaza up to 96 px), zero wall-climbs offline.
  - **Furniture builder features:** `keep`, `liftRow`, `base`, `disc` bark, height caps.
- **Furniture agent:** Pokémon Center desk, PC, bookshelf, plants and 2F counter; Mart shelves, counters and
  tiered racks; house plants, TVs and sink/stove; Mauville Gym posts and stage, plus whatever else it lists in
  `docs/FURNITURE-UNVERIFIED.md`.
- **Sonnet:** the Slateport bush and the rest in `docs/PROPS-UNVERIFIED.md`.

## Tooling fixed tonight (why the night was bumpy)
- **Game runs went through a wait loop that matched itself.** Runs hung or overlapped, and two games started
  together deadlock. Now every run goes through `tools/qa_run.sh`: an atomic lock, a watchdog, and automatic
  removal of hung QA games. Your own game is never touched.
- **An empty patch file was pushed once** and then restored. `make_patch.sh` now refuses a patch that is small,
  shrinking, or doesn't apply.
- **Atlases are baked offline for every tileset,** so pixel tools work without visiting maps.
- **Offline heightmaps** (`tools/elevation/heightmap.py`) run the real level solver without the game.

## Still open
- Run `tools/morning_check.sh` and review the sheets; install what's right, revert what isn't.
- Fortree's authored terraces fail the offline check (27 wall-climbs), so they stay off.
- Battle animations: still waiting for you to say what looks wrong.
