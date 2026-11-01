"""Fortree gold instance analysis (P1c): group the installed look's drawInstanced instances by vertex count,
map each to the window cell under it and print offsets + the tiles they stand on.
usage: python3 tools/trees/fortree_gold_analyse.py [MAP=EM_FORTREE_CITY] [gold=.rewrite/night/p1c/draw_gold_fortree.txt]"""
import re, sys, collections, math
MAP = sys.argv[1] if len(sys.argv) > 1 else 'EM_FORTREE_CITY'
GOLD = sys.argv[2] if len(sys.argv) > 2 else '.rewrite/night/p1c/draw_gold_fortree.txt'
cells = {}
for l in open(f'.rewrite/baseline/w0a/{MAP}.cells'):
    p = l.split()
    if len(p) < 5: continue
    cells[(int(p[1]), int(p[2]))] = (p[3], p[4])
inst = []
for l in open(GOLD):
    if l.startswith('I '):
        p = l.split(); vc = int(p[1]); m = re.search(r'\{([-\d.]+),([-\d.]+),([-\d.]+)\}', l)
        x, y, z = map(float, m.groups())
        inst.append((vc, x, y, z))
print('instances', len(inst))
byvc = collections.defaultdict(list)
for vc, x, y, z in inst: byvc[vc].append((x, y, z))
for vc in sorted(byvc, key=lambda v: -len(byvc[v])):
    L = byvc[vc]
    offs = collections.Counter((int(x) % 16, int(z) % 16) for x, y, z in L)
    ys = collections.Counter(int(y) for x, y, z in L)
    tiles = collections.Counter()
    for x, y, z in L:
        cx, cz = math.floor(x / 16), math.floor(z / 16)
        tiles[cells.get((cx, cz), ('?', '?'))[0]] += 1
    print(f'vc {vc:6d} n {len(L):4d} offs {offs.most_common(4)} y {ys.most_common(3)} tiles {tiles.most_common(6)}')
