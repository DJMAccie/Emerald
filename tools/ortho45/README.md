# ortho45 tools

Compare an ortho45 screenshot with the original 2D map art, per map cell.

    python3 ref.py <MAP_ID> <x> <y> <out.png> [--scale 2] [--size 1280x720]
    python3 diff.py <MAP_ID> <x> <y> <shot.png> <outdir> [--scale 2] [--tol 12] [--shift auto]
                    [--rect x0,y0,x1,y1] [--mask none|building]

- ref.py: renders the plain art (u, m, o layers) for the window centred on cell (x, y).
- diff.py: writes `<outdir>/<MAP>_<x>_<y>_cmp.png` and `_diff.json`, prints a summary line.
  `--shift auto` searches offsets -4..4 and prints the chosen one.
- ref.building_mask(map_id, rect): BUILDING pixels of a rectangle from the original art only (ring of
  cells 2 around it gives the ground metatiles: walkable ones, plus blocked ones seen 4+ times; a candidate
  ground pixel equals one of those tiles' pixels; only candidates 4-connected to the rectangle border through
  candidates are ground, so the rest is the silhouette). diff.py --mask building (with --rect) counts only
  those pixels; the unmasked numbers stay as rect_percent_all. classify.py slides the shot with the same mask.
- Map id is resolved from the QA cache (`--cache`, `--slot`, `--pair`, `--world` override).
- diff.py --rect x0,y0,x1,y1 (map cells, inclusive): adds rect_differ / rect_of / rect_percent
  (pixels inside the rectangle) and above_differ / above_of (the 3 cell rows directly above it,
  same columns) to the JSON and the summary line; cmp.png is cropped to the rectangle plus 3 cells
  of margin on every side, at full resolution.
- sweep.py: `plan` reads data/buildings/*.lua with a regex (index.lua skipped), picks a walkable
  player cell (below the rectangle's bottom row, middle column; outward search), and writes
  plan.json and batch_NN/cases.txt (batch k = the k-th building of each map, one load per map per QA process); `run` calls qa_tryp.sh (3 at a time, 150 frames per case);
  `score` checks each run.log (load, active, view line, fallback, blank capture), runs diff.py
  --rect --shift auto, copies the strips to docs/ortho45/sheets, writes BUILDINGS.md and buildings.json.
  Scratch dir is set by SWEEP inside the script.
