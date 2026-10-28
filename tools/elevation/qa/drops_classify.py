#!/usr/bin/env python3
"""drops_classify.py <drops.txt> [--out census.txt] [--sheet MAP x0 y0 x1 y1 out.png] [--sizes pins_gate_dir]

Classifies the bare drops dumped by tools/elevation/qa/em_drops_driver.lua (two plateau floor cells side by side at different
heights, no band / stair / ledge between; R-33: grass, sand and water are never a plateau step by themselves).
Classes (by the 2D layout data, not by the pins):
  A1  one side has layout elevation 0 (= "any level": ridge / ramp / stair / bridge tiles) and the other a real level: a ridge-like
      tile the classifier read as plain floor (kind flat). Safari NE: the brown ridge tiles 1D0-1E2.
  A2  both sides a real level, elevations differ: a real level change in the 2D data drawn only as the plateau's rim line (the
      north face is hidden from the top-down art): rim tiles 002 / 0D3 / 0D4 / 1E8 / 1E9 / 239 / 256 ... at elev 5 over elev 3 -> a
      rock ledge face, not a slope.
  B1  same elevation both sides, a mark of the user's on both sides: the pins disagree across a plain edge.
  B2  same elevation, one side is <=10 cells with no mark of its own: stray cells (flood / support-fill / ramp-relief leftover).
  B3  same elevation, a big side with no mark of its own.
  N   both elevations 0 (maps that carry no elevation, Battle Frontier, sea routes): the 2D data cannot say.
  C   roof / wall / steps kinds (a building or stairs): not a plateau edge.
Edges are directed (u higher -> n lower) as dumped; one lower cell can appear in up to 4 edges.
"""
import sys, collections, json, os

def load(path):
    rows = []
    for l in open(path):
        if not l.startswith('DROP '):
            continue
        p = l.split()
        r = dict(map=p[1], ux=int(p[2]), uy=int(p[3]), nx=int(p[4]), ny=int(p[5]), dir=p[6], hu=float(p[7]), hl=float(p[8]),
                 kU=p[9], kN=p[10], midU=p[11], midN=p[12], elU=p[13], elN=p[14], collU=p[15], collN=p[16],
                 mkU=p[19], mkN=p[20], szU=int(p[21]), szN=int(p[22]),
                 flU=p[23] if len(p) > 23 else '-', flN=p[24] if len(p) > 24 else '-')
        r['cls'] = klass(r)
        rows.append(r)
    return rows

def real(m):
    return m != '-' and not m.startswith('~')

def klass(r):
    if r['kU'] == 'roof' or r['kN'] in ('roof', 'wall') or 'steps' in (r['kU'], r['kN']):
        return 'C'
    if r['elU'] == 'nil' or r['elN'] == 'nil':
        return 'C'
    if r['elU'] == '0' and r['elN'] == '0':
        return 'N'
    if r['elU'] == '0' or r['elN'] == '0':
        return 'A1'
    if r['elU'] != r['elN']:
        return 'A2'
    if real(r['mkU']) and real(r['mkN']):
        return 'B1'
    if (not real(r['mkU']) and r['szU'] <= 10) or (not real(r['mkN']) and r['szN'] <= 10):
        return 'B2'
    return 'B3'

def clusters(rows):
    """connected edges (same class, same map, cells within 1 of each other) -> list of lists"""
    by = collections.defaultdict(list)
    for r in rows:
        by[(r['map'], r['cls'])].append(r)
    out = []
    for key, rs in by.items():
        seen = set()
        for i, r in enumerate(rs):
            if i in seen:
                continue
            comp = [r]; seen.add(i); stack = [r]
            while stack:
                a = stack.pop()
                for j, b in enumerate(rs):
                    if j in seen:
                        continue
                    if abs(a['ux'] - b['ux']) <= 1 and abs(a['uy'] - b['uy']) <= 1:
                        seen.add(j); comp.append(b); stack.append(b)
            out.append((key, comp))
    return out

def describe(key, comp):
    xs = [r['ux'] for r in comp] + [r['nx'] for r in comp]
    ys = [r['uy'] for r in comp] + [r['ny'] for r in comp]
    d = collections.Counter(r['dir'] for r in comp)
    hs = collections.Counter('%g>%g' % (r['hu'], r['hl']) for r in comp)
    mids = collections.Counter('%s>%s' % (r['midU'], r['midN']) for r in comp)
    el = collections.Counter('%s>%s' % (r['elU'], r['elN']) for r in comp)
    fl = collections.Counter(r['flU'] + r['flN'] for r in comp)
    r0 = comp[0]
    return '%-4s %-30s n=%-3d x%d-%d y%d-%d dir=%s h(courses)=%s elev=%s tiles(u>n)=%s marksU=%s marksN=%s sizes=%d/%d flags=%s' % (
        key[1], key[0].replace('EM_', ''), len(comp), min(xs), max(xs), min(ys), max(ys),
        ','.join('%s%d' % kv for kv in d.most_common()), ','.join('%s x%d' % kv for kv in hs.most_common(3)),
        ','.join('%s x%d' % kv for kv in el.most_common(3)), ','.join('%s x%d' % kv for kv in mids.most_common(3)),
        r0['mkU'], r0['mkN'], r0['szU'], r0['szN'], ','.join('%s x%d' % kv for kv in fl.most_common(3)))

def census(rows, out):
    c = collections.Counter(r['cls'] for r in rows)
    out.write('BARE DROP CENSUS: %d edges on %d maps\n' % (len(rows), len(set(r['map'] for r in rows))))
    for k in ('A1', 'A2', 'B1', 'B2', 'B3', 'N', 'C'):
        out.write('  %-3s %4d edges\n' % (k, c[k]))
    cl = clusters(rows)
    for k in ('A1', 'A2', 'B1', 'B2', 'B3', 'N', 'C'):
        out.write('\n== class %s\n' % k)
        for key, comp in sorted([x for x in cl if x[0][1] == k], key=lambda x: (x[0][0], -len(x[1]))):
            out.write(describe(key, comp) + '\n')

def sheet(rows, mapname, box, outpng, sizes):
    from PIL import Image, ImageDraw
    src = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'docs', 'elevation', 'pins', mapname + '_read.png')
    im = Image.open(src).convert('RGB')
    W = None
    for f in os.listdir(sizes):
        if f.startswith('pins_'):
            for l in open(os.path.join(sizes, f)):
                if l.startswith('COUNT %s ' % mapname):
                    W = int(l.split('size=')[1].split('x')[0])
    c = im.size[0] / W
    col = dict(A1=(255, 140, 0), A2=(255, 230, 0), B1=(255, 0, 0), B2=(230, 0, 230), B3=(0, 0, 0), N=(0, 120, 255), C=(120, 120, 120))
    d = ImageDraw.Draw(im)
    for r in rows:
        if r['map'] != mapname:
            continue
        x0, y0 = r['ux'], r['uy']; x1, y1 = r['nx'], r['ny']
        # the shared edge between the two cells
        if x0 != x1:
            ex = max(x0, x1) * c; ey0 = 31 + y0 * c; ey1 = ey0 + c
            d.line([(ex, ey0), (ex, ey1)], fill=col[r['cls']], width=5)
        else:
            ey = 31 + max(y0, y1) * c; ex0 = x0 * c; ex1 = ex0 + c
            d.line([(ex0, ey), (ex1, ey)], fill=col[r['cls']], width=5)
    bx = (int(box[0] * c), int(31 + box[1] * c), int(box[2] * c), int(31 + box[3] * c))
    im.crop(bx).save(outpng)

if __name__ == '__main__':
    a = sys.argv[1:]
    rows = load(a[0])
    if '--sheet' in a:
        i = a.index('--sheet')
        sheet(rows, a[i + 1], [float(v) for v in a[i + 2:i + 6]], a[i + 6], a[a.index('--sizes') + 1])
    else:
        out = open(a[a.index('--out') + 1], 'w') if '--out' in a else sys.stdout
        census(rows, out)
