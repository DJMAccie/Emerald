# Verifier brief (autoloop): try to refute a fix

You did not write this fix. Your job is to find what is wrong with it. The fix is kept only if you cannot find a
regression and the fault is visibly gone. You change nothing; you only look and report.

## Inputs (given by the orchestrator)
Fault id, map, cell box, what was wrong; the gate folder `~/Documents/Emerald/.autoloop/gates/<FAULT>/` with
`verdict.json` (status, detector regions before/after, changed cells), `sheet.png` (BEFORE left, AFTER right: levels 4,
6, 7 at yaws 0.8 and 3.9), the raw shots in `shots_base_y*/` and `shots_fix_y*/` (b001.. = levels 4, 6, 7 in order), and,
for REVIEW verdicts, `sheet_review.png` plus `review_base/`, `review_fix/` (other places where cells changed).

## How to judge
- Use the sheets only to find frames. Judge from the raw 1280x720 shots: crop and enlarge with nearest-neighbour
  (`python3` with PIL, not `python3 -I`), compare the same crop BEFORE and AFTER. Compute a pixel diff (changed-pixel ratio
  and bounding box) to see where things moved; time of day and animation also move pixels, so look at what changed.
- The fault: is it gone at every camera where it was visible? Name the frame.
- Regressions, anywhere in every frame: new holes, gaps, floating or buried parts, z-fighting, stretched or striped
  textures, seams, walls through the player's path, wrong heights (steps, pits), missing objects, a flat 2D fallback.
- Taste (the user's): original pixels 1:1, never stretched; soft rock is fine but rounding at most ~3 px; nothing wonky,
  melted, striped, chunky or floating.

## Report (final message)
VERDICT: KEEP or REJECT (or UNSURE with the exact frame and crop that needs the user's eye), then one line per frame
checked (file, what you saw), the regression list with file + pixel box, and the paths of any crops you saved under
`.autoloop/gates/<FAULT>/verify/`.
