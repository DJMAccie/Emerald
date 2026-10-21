#!/usr/bin/env python3
"""Ghost, step 2 (cheap senses on the walk frames). Run WITHOUT -I (needs PIL, numpy, scipy).

  ghost_senses.py <ghost dir> [--map EM_ROUTE112]   reads <dir>/frames/<yaw>_b<n>/bNNN.png (tools/autoloop/shots.sh output,
                                                    index = case*3 + level + 1 (1-based), levels 4 6 7) and <dir>/cases_<n>.txt
                                                    writes <dir>/senses.csv, one row per frame

Senses (no model):
  stretch   share of pixels (below the top 20% of the frame) lying in a run of one colour that is >= 4x longer along one
            axis than across it and >= 24 px long: art pixels drawn as streaks instead of squares (stretched texture,
            striped walls). Foreshortened ground gives a floor of this number, so compare frames of the same level.
  void      share of magenta / fill-coloured pixels (a hole showing the clear colour).
  dialog    share of the text box's cyan frame colour (an NPC dialogue covers the frame: the frame is not judged).
            Batches b3/b4 are reruns of the dialogue spots with trainer sight off (em_ghost_driver.lua); they replace the old frames.
  skyfloor  share of sky-coloured pixels in the lower half of a level-4/6 frame (ground missing under the camera's view).
The detector sense (detect.py air) is read from <dir>/air.json by the caller: it is empty for Route 112 on the real install.
"""
import sys, os, re, glob, csv
import numpy as np
from PIL import Image
from scipy import ndimage

LEVELS = (4, 6, 7)


def runs(same, axis):
    """Length of the run of True (plus one) that each pixel of `same` (n-1 comparisons) belongs to, along `axis`."""
    st = np.zeros((3, 3), int)
    if axis == 0:
        st[:, 1] = 1
    else:
        st[1, :] = 1
    lab, n = ndimage.label(same, structure=st)
    size = np.bincount(lab.ravel())
    size[0] = 0
    return size[lab] + 1


def metrics(path, level):
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.int16)
    h, w, _ = a.shape
    # one-colour runs along y and x
    sv = np.abs(a[1:] - a[:-1]).max(axis=2) <= 2
    sh = np.abs(a[:, 1:] - a[:, :-1]).max(axis=2) <= 2
    rv = np.ones((h, w), int); rv[:-1] = runs(sv, 0)
    rh = np.ones((h, w), int); rh[:, :-1] = runs(sh, 1)
    top = int(h * .2)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dialog = float(((r < 40) & (g > 190) & (b > 150) & (b < 230)).mean())   # the text box's cyan frame: an NPC is talking
    keep = np.ones((h, w), bool)
    if dialog > .003:
        keep[int(h * .68):int(h * .94), int(w * .12):int(w * .88)] = False   # the box itself is not the world
    vert = (rv >= 24) & (rv >= 4 * rh)
    horz = (rh >= 24) & (rh >= 4 * rv)
    stretch = float(((vert | horz) & keep)[top:].sum() / keep[top:].sum())
    void = float(((r > 200) & (g < 60) & (b > 200)).mean())
    sky = (b > 200) & (b > r + 40) & (g > 150) & (r > 120)       # light blue, not water
    skyfloor = float((sky & keep)[h // 2:].sum() / keep[h // 2:].sum()) if level in (4, 6) else 0.0
    return stretch, void, skyfloor, dialog


def main():
    G = sys.argv[1]
    mp = sys.argv[sys.argv.index('--map') + 1] if '--map' in sys.argv else 'EM_ROUTE112'
    rows = []
    for d in sorted(glob.glob(os.path.join(G, 'frames', 'y*_b*'))):
        m = re.search(r'(y\d+)_b(\d+)$', d)
        tag, b = m.group(1), int(m.group(2))
        cases = re.findall(r"'%s',(-?\d+),(-?\d+)" % mp, open(os.path.join(G, 'cases_%d.txt' % b)).read())
        for i, (x, y) in enumerate(cases):
            for j, lv in enumerate(LEVELS):
                f = os.path.join(d, 'b%03d.png' % (i * len(LEVELS) + j + 1))
                if not os.path.exists(f):
                    continue
                s, v, k, dlg = metrics(f, lv)
                rows.append(dict(map=mp, x=int(x), y=int(y), yaw=tag, level=lv, stretch=round(s, 4), void=round(v, 4),
                                 skyfloor=round(k, 4), dialog=round(dlg, 4), frame=os.path.relpath(f, G)))
    # batches >= 3 are reruns of the spots whose first frames carried an NPC dialogue box (tools/em_ghost_driver.lua, trainer
    # sight off): a rerun frame replaces the first-walk frame of the same spot, level and yaw when that one had a dialogue
    new = {(r['x'], r['y'], r['yaw'], r['level']) for r in rows if int(re.search(r'_b(\d+)', r['frame']).group(1)) >= 3}
    rows = [r for r in rows if not (int(re.search(r'_b(\d+)', r['frame']).group(1)) < 3 and r['dialog'] > .003
                                    and (r['x'], r['y'], r['yaw'], r['level']) in new)]
    with open(os.path.join(G, 'senses.csv'), 'w', newline='') as fh:
        wr = csv.DictWriter(fh, fieldnames=list(rows[0]))
        wr.writeheader(); wr.writerows(rows)
    print(len(rows), 'frames')


if __name__ == '__main__':
    main()
