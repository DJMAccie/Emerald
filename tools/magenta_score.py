# Score probe frames (underlay painted magenta in a QA-only build): share of magenta pixels per
# frame, and where (lower part = a hole near the ground; a thin band at the horizon = the far edge
# of the built world). Usage: magenta_score.py DIR... ; prints sorted rows.
# (moved from a session scratch dir into git for tools/release_check.sh; logic unchanged, wrapped in score())
import sys, glob, os
import numpy as np
from PIL import Image


def score(dirs):
    """-> [(total, low, band, dirname, filename)] over every png in the given folders"""
    rows = []
    for d in dirs:
        for p in glob.glob(os.path.join(d, '*.png')):
            a = np.asarray(Image.open(p).convert('RGB')).astype(int)
            m = (a[..., 0] > 190) & (a[..., 1] < 80) & (a[..., 2] > 190)
            H = a.shape[0]
            low = m[int(H * .55):].mean(); band = m[int(H * .35):int(H * .55)].mean(); tot = m.mean()
            rows.append((tot, low, band, os.path.basename(d), os.path.basename(p)))
    return rows


if __name__ == '__main__':
    rows = score(sys.argv[1:])
    for tot, low, band, d, f in sorted(rows, reverse=True):
        if tot > 0.0005: print('%.4f low %.4f band %.4f  %s/%s' % (tot, low, band, d, f))
    print('frames', len(rows), 'with magenta', sum(1 for r in rows if r[0] > 0.0005))
