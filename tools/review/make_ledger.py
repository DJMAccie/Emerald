#!/usr/bin/env python3
# make_ledger.py  tools/review/verdicts*.txt -> docs/rock-gates/REVIEW-2026-10-26.md  (run from the repo root)
import csv, collections
rank = {'ok': 0, 'ok?': 1, 'suspect': 2, 'left': 3, 'wrong': 3, 'fixed': -1}
def load(p):
    by = collections.OrderedDict()
    for l in open(p):
        q = l.rstrip('\n').split('|', 3)
        if len(q) == 4: by.setdefault(q[0], []).append(q[1:])
    return by
def worst(rs): return max((r[1] for r in rs), key=lambda s: rank.get(s, 2))
def notes(rs): return '; '.join('%s: %s' % (r[0], r[2]) for r in rs if r[1] != 'ok') or rs[0][2]
out = ['# ROCK REVIEW LEDGER (task 30, 2026-10-26/27)', '',
 'One line per rock map, judged on the INSTALLED game (recaptured from the game lib, QA_ZOOM -2, levels 4/6/7) against the 2D art. Sheets: docs/rock-gates/review1/sheets (outdoor: 2D | census-time OLD | NOW), docs/rock-gates/review_caves1/sheets_a and sheets_b (caves: 2D | L4 | L6 | L7). Tools: tools/review (cap_game.sh, sheets.sh, cave_sheet.py, make_ledger.py; verdicts in verdicts.txt / verdicts_caves.txt).',
 'Status: ok = reads as the 2D; ok? = reads right, small blemish named; fixed = changed by this pass; suspect/wrong/left = does not read as the 2D and was not fixed here (reason in the notes, card sheet for the user).', '']
o = load('tools/review/verdicts.txt'); c = load('tools/review/verdicts_caves.txt')
cnt = collections.Counter(worst(r) for r in o.values())
out += ['## Outdoor (%d maps, %d spots)' % (len(o), sum(len(v) for v in o.values())), '',
 'Counts: ' + ', '.join('%s %d' % (k, v) for k, v in sorted(cnt.items())), '', '| map | status | spots | notes |', '|---|---|---|---|']
for m, rs in o.items(): out.append('| %s | %s | %s | %s |' % (m, worst(rs), ', '.join(r[0] for r in rs), notes(rs)))
grp = {r['map']: r['group'] for r in csv.DictReader(open('tools/caves/spots.csv'))}
maps = [l.split('|')[1].strip() for l in open('docs/rock-gates/ALL-ROCKS-CAVES.md') if l.startswith('| EM_') and 'open: round 2' in l]
cc = collections.Counter(); rows = []
for m in maps:
    g = grp.get(m, m); rs = c.get(g)
    if rs is None: rows.append('| %s | NOT JUDGED | %s | no capture |' % (m, g)); cc['notjudged'] += 1; continue
    st = worst(rs); cc[st] += 1
    rows.append('| %s | %s | %s | %s |' % (m, st, ('same grid as ' + g) if g != m else ', '.join(r[0] for r in rs), notes(rs)))
out += ['', '## Caves and interiors that were "open: round 2" (%d maps; a map with an identical grid takes its group representative\'s judgement)' % len(maps), '',
 'Counts: ' + ', '.join('%s %d' % (k, v) for k, v in sorted(cc.items())), '', '| map | status | spots | notes |', '|---|---|---|---|'] + rows
open('docs/rock-gates/REVIEW-2026-10-26.md', 'w').write('\n'.join(out) + '\n')
print(dict(cnt), dict(cc))
