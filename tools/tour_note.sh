#!/bin/bash
# Log a fault from a tour screenshot into docs/ledger/faults.json and refresh docs/LEDGER.md.
#   tools/tour_note.sh "<tour label>" <class> "<what is wrong>" [tier=1] [area=Terrain]
# The tour label is the text tour mode draws in the top-right corner, e.g.
#   "EM_ROUTE115  29,67  h16  cam4/0"      (lib/TourMode.lua)
# Classes are free text but reuse the ledger's: ledges, mini-stairs, floating-props, seams, first-person, terrain, rock ...
# Tier 1 blocks a release, tier 2 is polish (docs/DONE.md). Add DRY=1 to print without writing.
# To close a fault later:  tools/tour_note.sh --fix F012
set -eu
cd "$(dirname "$0")/.."
if [ "${1:-}" = "--fix" ]; then
  python3 - "$2" <<'PY'
import json, sys, datetime
p = 'docs/ledger/faults.json'
fl = json.load(open(p))
hit = [f for f in fl if f['id'] == sys.argv[1]]
if not hit: sys.exit('no such fault ' + sys.argv[1])
hit[0]['status'] = 'fixed'; hit[0]['fixed'] = datetime.date.today().isoformat()
json.dump(fl, open(p, 'w'), indent=1, ensure_ascii=False); open(p, 'a').write('\n')
print('fixed', sys.argv[1])
PY
  python3 tools/ledger.py --write
  exit 0
fi
[ $# -ge 3 ] || { sed -n 2,9p "$0"; exit 2; }
python3 - "$@" <<'PY'
import json, re, sys, os, datetime
label, cls, text = sys.argv[1], sys.argv[2], sys.argv[3]
tier = int(sys.argv[4]) if len(sys.argv) > 4 else 1
area = sys.argv[5] if len(sys.argv) > 5 else 'Terrain'
m = re.match(r'\s*(EM_[A-Z0-9_]+)\s+(-?\d+),(-?\d+)', label)
if not m: sys.exit('label must start with MAP_ID x,y as tour mode prints it: ' + label)
mp, x, y = m.group(1), m.group(2), m.group(3)
maps = {r['id'] for r in json.load(open('docs/ledger/maps.json'))}
if mp not in maps: sys.exit('unknown map ' + mp)
p = 'docs/ledger/faults.json'
fl = json.load(open(p))
dup = [f for f in fl if f['map'] == mp and f.get('cell') == '%s,%s' % (x, y) and f['class'] == cls and f['status'] == 'open']
if dup: sys.exit('already logged as ' + dup[0]['id'])
fid = 'F%03d' % (max([int(f['id'][1:]) for f in fl] or [0]) + 1)
fl.append({'id': fid, 'map': mp, 'area': area, 'tier': tier, 'class': cls, 'cell': '%s,%s' % (x, y), 'text': text,
           'status': 'open', 'found': datetime.date.today().isoformat(), 'source': 'tour: ' + label.strip()})
print(fid, mp, x + ',' + y, 'tier', tier, cls, '-', text)
if os.environ.get('DRY'): sys.exit(0)
json.dump(fl, open(p, 'w'), indent=1, ensure_ascii=False); open(p, 'a').write('\n')
PY
[ -n "${DRY:-}" ] || python3 tools/ledger.py --write
