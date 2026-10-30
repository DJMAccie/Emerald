#!/usr/bin/env python3
"""cls_diff.py <dirA> <dirB>: compare the CLS lines of two field dumps by map.
Compares the gate fields by name (counts, rock, unclassified, faceHigh). massNotFlat and the fixup
diagnostics (treeFix/rockFar/otherFix/pocketFix) are not comparable through the neutral probe."""
import sys, glob, os

KEYS = ['PLATEAU', 'FACE', 'MASS', 'WATER', 'DECK', 'OTHER', 'rock', 'unclassified', 'faceHigh']

def load(d):
    out = {}
    for f in glob.glob(os.path.join(d, 'cls_*.txt')):
        for line in open(f):
            p = line.split()
            if p and p[0] == 'CLS':
                kv = {}
                for x in p[2:]:
                    if '=' in x:
                        k, v = x.split('=', 1)
                        kv[k] = v
                out[p[1]] = kv
    return out

a, b = load(sys.argv[1]), load(sys.argv[2])
bad = 0
for m in sorted(set(a) | set(b)):
    if m not in a or m not in b:
        print(m, 'MISSING in', 'A' if m not in a else 'B'); bad += 1; continue
    diff = [f'{k} {a[m].get(k)}->{b[m].get(k)}' for k in KEYS if a[m].get(k) != b[m].get(k)]
    if diff:
        bad += 1
        print(m, ' '.join(diff))
print('MAPS differing:', bad, 'of', len(set(a) | set(b)))
