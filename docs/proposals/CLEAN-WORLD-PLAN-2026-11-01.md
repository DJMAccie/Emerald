# Clean-world plan (2026-11-01, Fable, proposal for Petya)

## Where we stand (facts, not feelings)
- Two versions exist. OLD = ~/Documents/battle-art-notquiteog (the installed look, more complete, no licence: it is the
  GOLD reference only, never read from rewrite work). NEW = ~/Documents/emerald3d, GitHub repo DJMAccie/Emerald-voxel-mod. main = 111678e. Unmerged work that is DONE and only needs landing:
  audit/overworld (3 ahead: hedges as bars, bush 0x007 flat, bat double fix), fix/ledges (1 ahead: R-35 wedge face art),
  fix/flyer-real-only (1 ahead), slice/battles (2 ahead, M4, separate track).
- 23 worktrees / 20 branches; 15 of them are 0 ahead of main (stale). This sprawl, plus 2-3 parallel desktop sessions and
  overnight chains, is what burned last week's limit and what makes the path feel unclear. The work itself is on track.
- The "45-degree breakthrough" = BlockBuilder §4a (ridge runs are one slope) + R-35 wedges. It is a RULE, so it already
  applies to every map. What is NOT finished is the rock LOOK on top of those slopes: the overworld audit (76 maps) lists
  12 worst maps (112, 116, 118, 114, 115, Chimney, Safari NE, Southern/Faraway Island, Lavaridge, Fallarbor, Jagged Pass)
  as "flat, pale, cardboard" vs the installed look. Spec request: emerald3d-audit docs/specs/RockRelief-request.md.
- Trees regressed by measurement: card mask 551 px vs installed 781 (the crown's upper band is cut by the ground flood),
  models 750-1850 quads vs ~3000 (boxy), Littleroot tree ROWS flat vs round, Fortree recipe + canopy unwired.
- Bushes/shrubs: hedges fixed (bars), bush 0x007 flat; the wider green-art rule (~1100 cells: Trainer Hill roof, ship
  deck, Safari hedges, secret-base shrubs) has no single class yet, so they look different map to map.
- Overnight sweep: 531 shots taken, 8 findings judged, 169 spots unjudged (RANK.md/MORNING.md not found where PLAN.md says).

## The answer to "per route or whole world?"
Fix by CLASS, verify by ROUTE. The rewrite is rule-driven: one tree rule draws every tree on 177 maps. A per-map pass
would be 177 maps x N classes and would regress the moment a rule changes (that is exactly what happened to trees before).
So: one class per session, applied to the whole world, gated by the existing 177-spot sweep (installed vs rewrite, L4/L6)
where ONLY the intended class may change. Then walk the world in PLAY ORDER (Littleroot -> 101 -> Oldale -> 103 -> 102 ->
Petalburg -> 104 -> Woods -> Rustboro -> ...) to judge, because the first hour of play is what everyone sees. Each
screenshot from the walk becomes a class fix, never a spot fix (tools/tour_note.sh).

## Phases (serial, one branch audit/overworld, one builder session at a time)
P0 Land + prune (1 Sonnet session, ~half a day of budget)
   - Petya pushes: audit/overworld, fix/ledges, fix/flyer-real-only into main (fast-forward via emerald3d-clouds).
   - Remove the 15 stale worktrees. Keep: clouds (play), audit (overworld look), battles, ledges until merged.
   - Re-run the 177-spot sweep once on the merged main = the new baseline ("gold2"). Judge the 169 open spots into RANK.md.
   Done = main plays, one baseline sheet set, RANK.md complete, worst-first.
P1 Trees (the most visible regression; 1 spec pass by Fable + 1-2 Sonnet builder sessions)
   - Card: find the flood rule between 551 and 908 px that lands on 781 (data in .rewrite/trees).
   - Model: round crowns at ~3000 quads (installed) not 750-1850; Littleroot rows round; Fortree recipe; canopy wired.
   Gate: single-drawing quad-for-quad compare + sweep diff limited to the tree layer. Walk: Littleroot, 101-104, Woods,
   Fortree, Dewford, Chimney, Fallarbor (Petya's four pain points from task 11).
P2 Green art class table (1 Sonnet session)
   - One table tile -> shape: flat bush, hedge bar, shrub model, planter, roof green. Covers the ~1100 cells.
   Gate: sweep diff limited to those tiles. Walk: Petalburg, Mauville, Lilycove, Safari, Trainer Hill, ship deck.
P3 Rock relief = finishing the 45-degree work (1 Fable spec session reading the installed look, then 2-3 Sonnet slices)
   P3a FIRST, geometry only: R-38 NO vertical rock wall anywhere in the game (Petya 2026-11-01: 'its always a 45 degree
   slope'): every rock drop of N courses is a slope N cells deep over the face rows (+ R-35 wedges where rows are fewer).
   Every band is a 45-degree slope (R-ridge-slope everywhere, Petya 2026-11-01 on the Route 112 red
   wall 'that wall should also be ridges of 45 degrees': stacked red walls, brown/beige terraces, cave + underwater bands;
   R-04 flat band retired; intended difference from the installed look). Includes cave wall bands (R-37, Petya 2026-11-01 screenshot
   docs/faults/caves/user_2026-11-01_cave_band_is_ridge.png, 'they are everywhere in caves'): the dark diamond-pattern band
   tiles edging every cave floor and the underwater maps go through BlockBuilder's ridge-slope rule, uphill side from the
   band's art orientation. Gate: sweep diff limited to cave/underwater band cells; L6 at the screenshot spot shows a slant.
   - Face courses from the tile art, top/face darkening factor, irregular lip, dome hills on sand/ash (114/115), notches.
   - Pinned field untouched (gate 64/64). Walk: the 12 worst maps.
P4 Play-order walkthrough with Petya (their screenshots -> class fixes), then the open-for-Petya list (pocket heights,
   Route 120 strip, PLATEAU walls, mist default).
P5 Battles M4, then packaging (release target mid-late Jan 2027 stands).

## Method correction (Petya 2026-11-01: "why do we need to do this by eye? we already have all the recipes and code
## from the previous version that we built ourselves")
PORT, do not re-derive. REWRITE-PLAN.md section 2 already allows lifting our OWN modules (51 new files, 218 upstream-identical
lines in 69,667) into the clean tree after tools/rewrite/simcheck.py. From P3 on: a dirty-side lift session copies our own rock
builders (Gen3Rock, Gen3Relief, Gen3Hills, Gen3Blocks, Gen3Mass, Gen3Cave; 4,471 lines) and, where P1c left gaps, the tree
recipes (Gen3Canopy, Gen3TreeStamps, NativeTreeArt), swaps their calls into upstream internals for our own interfaces, rebakes
the relief data locally (never committed), passes simcheck, and wires them; THEN R-38/R-37 slopes go on top. The specs
(RockRelief.md) and the gold|new sheets are acceptance gates, not design input. Gold is the floor, not the target: the old
version was not perfect either; where gold and rewrite differ, R-38/R-37 and the ortho-45 check against the 2D art decide.
Sessions: Sonnet 5.5 at medium effort only (Petya 2026-11-01), coordinators included.

## Roles (Petya 2026-11-01: 'stay as the coordinator')
Fable = coordinator: plans, specs, briefs, reviews sheets, records rules; never the builder. Sonnet sessions build, one at a time.

## Budget rules (weekly limit)
- Today: weekly all-models 19% used, Fable 0%, resets 2026-11-07. Last week went over because of parallel sessions +
  long contexts (every turn re-sends the whole conversation) + overnight chains.
- One builder session at a time (Sonnet 5.5), plus one coordinator/spec chat (Fable) that only plans, specs and reviews.
- Hand off at 180k context for builders (not 250k): the cost per turn grows with context; a fresh session is cheaper.
- Overnight chains: at most one, max 6 sessions, only for sweeps and gated class fixes with a written brief.
- Check get_usage at each handoff; start no new session above 70% weekly; keep 20% for Petya's own play and chats.
- Expected this week within those rules: P0 + P1 + P2 and the P3 spec. P3 implementation lands next week.
