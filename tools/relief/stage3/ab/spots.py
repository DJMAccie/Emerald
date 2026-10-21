import sys, glob, collections
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
S = '/Users/user/Documents/Emerald/tools/relief/stage3'
rel = collections.defaultdict(set)
for f in glob.glob(S + '/census1/dump_*.txt'):
    for l in open(f):
        p = l.split()
        if len(p) == 7 and p[5] == '1' and p[6] == '0':
            rel[p[0]].add((int(p[1]), int(p[2])))
maps = sys.argv[1:]
for m in maps:
    cells = rel[m]
    L = emdata.Layout(m)
    cand = []
    for y in range(L.h):
        for x in range(L.w):
            if L.blocked(x, y) or (x, y) in cells: continue
            if (x, y - 1) not in cells and (x, y - 2) not in cells: continue
            # relief cells in the window x-5..x+5, y-8..y-1
            n = sum(1 for dx in range(-5, 6) for dy in range(-8, 0) if (x + dx, y + dy) in cells)
            cand.append((n, x, y))
    cand.sort(reverse=True)
    picked = []
    for n, x, y in cand:
        if all(abs(x - px) + abs(y - py) > 14 for _, px, py in picked):
            picked.append((n, x, y))
        if len(picked) == 3: break
    print(m, len(cells), 'cells;', ' | '.join('%d,%d (n=%d)' % (x, y, n) for n, x, y in picked))
