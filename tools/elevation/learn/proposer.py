#!/usr/bin/env python3
"""proposer.py: heights of flat areas from the 2D art (stairs, ledges, cliff faces, shores), scored on the hand-drawn pins.
Graph: nodes = 4-connected components of walkable 'floor' cells (+ one node per water body); edges =
  stair run (north end higher by its rows) | jump ledge (1 course down along the jump) | vertical cliff run of g cliff/shelf cells (dH = f(sig|g), learned)
  | obstacle gap (tree/fence/sign/house, <=3 cells: dH 0) | water shore (dH 0).
Truth for learning/scoring = the PIN lines only (a node's pin cells; nodes whose pins disagree by >0.5 are skipped)."""
import sys, os, glob, collections, heapq, statistics
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
PD = '/Users/user/Documents/Emerald/docs/elevation/pins/'
CLIFF = ('cliff', 'shelf'); OBST = ('tree', 'fence', 'signpost', 'wall')
def read_pins(m):
    out = []
    if not os.path.exists(PD + m + '.txt'): return out
    for l in open(PD + m + '.txt'):
        t = l.split('#')[0].split()
        if len(t) >= 3:
            try: out.append((int(t[0]), int(t[1]), float(t[2]), len(t) > 3 and t[3] == 'top'))
            except ValueError: pass
    return out
class G:
    def __init__(self, m):
        self.m = m; L = self.L = emdata.Layout(m); self.node = {}; self.nodes = []; self.edges = []
        role = lambda x, y: None if L.off_map(x, y) else L.role_at(x, y)
        self.role = role
        # nodes
        for y in range(L.h):
            for x in range(L.w):
                r = role(x, y)
                if r in ('floor', 'water') and (x, y) not in self.node:
                    k = len(self.nodes); self.nodes.append(dict(kind=r, cells=[])); st = [(x, y)]; self.node[(x, y)] = k
                    while st:
                        a, b = st.pop(); self.nodes[k]['cells'].append((a, b))
                        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            n = (a + d[0], b + d[1])
                            if n not in self.node and role(*n) == r: self.node[n] = k; st.append(n)
        add = self.edges.append
        # vertical runs: stairs, cliffs, obstacle gaps; horizontal obstacle gaps; ledges
        for x in range(L.w):
            y = 0
            while y < L.h:
                r = role(x, y)
                if r == 'stair':
                    y0 = y
                    while y < L.h and role(x, y) == 'stair': y += 1
                    a, b = self.node.get((x, y0 - 1)), self.node.get((x, y))   # north end a, south end b
                    if a is not None and b is not None and a != b: add(dict(t='stair', hi=a, lo=b, d=y - y0, w=1, sig=None))
                elif r in CLIFF:
                    y0 = y; sig = []
                    while y < L.h and role(x, y) in CLIFF: sig.append(L.metatile(x, y)); y += 1
                    a, b = self.node.get((x, y0 - 1)), self.node.get((x, y))
                    if a is not None and b is not None and a != b: add(dict(t='cliff', hi=a, lo=b, d=y - y0, w=3 if y - y0 <= 5 else 7, sig=tuple(sig)))
                elif r in OBST:
                    y0 = y
                    while y < L.h and role(x, y) in OBST: y += 1
                    a, b = self.node.get((x, y0 - 1)), self.node.get((x, y))
                    if a is not None and b is not None and a != b and y - y0 <= 3: add(dict(t='gap', hi=a, lo=b, d=0, w=8, sig=None))
                else: y += 1
        for y in range(L.h):
            x = 0
            while x < L.w:
                if role(x, y) in OBST:
                    x0 = x
                    while x < L.w and role(x, y) in OBST: x += 1
                    a, b = self.node.get((x0 - 1, y)), self.node.get((x, y))
                    if a is not None and b is not None and a != b and x - x0 <= 3: add(dict(t='gap', hi=a, lo=b, d=0, w=8, sig=None))
                else: x += 1
        for (x, y), dirs in emdata.ledge_cells(L, junctions=False).items():
            for dx, dy in dirs:
                a, b = self.node.get((x - dx, y - dy)), self.node.get((x + dx, y + dy))
                if a is not None and b is not None and a != b: add(dict(t='ledge', hi=a, lo=b, d=0, w=1, sig=None))
        # shore: floor next to water
        seen = set()
        for (x, y), k in self.node.items():
            if self.nodes[k]['kind'] != 'floor': continue
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = self.node.get((x + d[0], y + d[1]))
                if n is not None and self.nodes[n]['kind'] == 'water' and (k, n) not in seen:
                    seen.add((k, n)); add(dict(t='shore', hi=k, lo=n, d=0, w=1, sig=None))
        # truth per node from the pins
        pv = collections.defaultdict(list)
        for x, y, h, top in read_pins(m):
            k = self.node.get((x, y))
            if k is not None and not top: pv[k].append(h)
        self.truth = {k: statistics.median(v) for k, v in pv.items() if max(v) - min(v) <= .5}
        self.rockpins = [(x, y, h) for x, y, h, top in read_pins(m) if role(x, y) in CLIFF]
def fit(graphs):
    bysig = collections.defaultdict(list); byg = collections.defaultdict(list)
    for g in graphs:
        for e in g.edges:
            if e['t'] == 'cliff' and e['hi'] in g.truth and e['lo'] in g.truth:
                dh = g.truth[e['hi']] - g.truth[e['lo']]
                bysig[e['sig']].append(dh); byg[e['d']].append(dh)
    return dict(sig={k: statistics.median(v) for k, v in bysig.items() if len(v) >= 3}, g={k: statistics.median(v) for k, v in byg.items() if len(v) >= 3})
def dh(e, tab):
    if e['t'] != 'cliff': return float(e['d'])
    if e['sig'] in tab['sig']: return tab['sig'][e['sig']]
    if e['d'] in tab['g']: return tab['g'][e['d']]
    return float(min(e['d'] - 1, 4)) if e['d'] >= 3 else float(e['d'])
def propagate(g, tab, root, h0):
    """Dijkstra over the edge graph from root (height h0): returns {node: height}, loop disagreements."""
    adj = collections.defaultdict(list)
    for e in g.edges:
        v = dh(e, tab); adj[e['hi']].append((e['lo'], -v, e['w'], e)); adj[e['lo']].append((e['hi'], v, e['w'], e))
    H = {root: h0}; cost = {root: 0}; pq = [(0, root)]; unsure = set()
    while pq:
        c, a = heapq.heappop(pq)
        if c > cost[a]: continue
        for b, d, w, e in adj[a]:
            if b not in cost or c + w < cost[b]: cost[b] = c + w; H[b] = H[a] + d; heapq.heappush(pq, (c + w, b))
    for e in g.edges:   # loop check: disagreeing edge
        if e['hi'] in H and e['lo'] in H and abs((H[e['hi']] - H[e['lo']]) - dh(e, tab)) > .5: unsure.add(e['hi']); unsure.add(e['lo'])
    return H, unsure
def pinned_maps():
    return [os.path.basename(f)[:-4] for f in sorted(glob.glob(PD + 'EM_*.txt')) if not f.endswith('_proposed.txt') and not f.endswith('_read.txt')]
if __name__ == '__main__':
    maps = [m for m in pinned_maps() if 'FRONTIER' not in m]; graphs = {}
    for m in maps:
        try: graphs[m] = G(m)
        except Exception as ex: print('skip', m, ex)
    tot = collections.Counter()
    for m, g in graphs.items():
        tab = fit([x for k, x in graphs.items() if k != m])
        if len(g.truth) < 2: print('%-30s nodes %3d pinned nodes %d (too few)' % (m, len(g.nodes), len(g.truth))); continue
        # root = pinned node with the most cells; others scored against truth
        root = max(g.truth, key=lambda k: len(g.nodes[k]['cells'])); H, unsure = propagate(g, tab, root, g.truth[root])
        sc = [(H[k] - t) for k, t in g.truth.items() if k in H and k != root]; un = len([k for k in g.truth if k not in H and k != root])
        if not sc: print('%-30s nodes %3d pinned %d: others unreached (%d)' % (m, len(g.nodes), len(g.truth), un)); continue
        ex = sum(abs(x) <= .5 for x in sc); mae = sum(map(abs, sc)) / len(sc)
        print('%-30s nodes %3d pinned %3d scored %3d unreached %2d  exact(<=.5) %.2f  mean|err| %.2f  max|err| %.1f' % (m, len(g.nodes), len(g.truth), len(sc), un, ex / len(sc), mae, max(map(abs, sc))))
        tot['n'] += len(sc); tot['ex'] += ex; tot['abs'] += sum(map(abs, sc)); tot['un'] += un
    print('ALL scored %d  exact %.2f  mean|err| %.2f  unreached %d' % (tot['n'], tot['ex'] / max(tot['n'], 1), tot['abs'] / max(tot['n'], 1), tot['un']))
