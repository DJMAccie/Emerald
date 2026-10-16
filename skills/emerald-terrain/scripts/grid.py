#!/usr/bin/env python3
# grid.py SLOT X0 Y0 X1 Y1 [mode=e|m]  text grid: e = collision/elevation ('#'=blocked, else elev hex), m = metatile ids
import sys, os, struct, json
C = os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba')
slot = sys.argv[1]; x0, y0, x1, y1 = map(int, sys.argv[2:6]); mode = sys.argv[6] if len(sys.argv) > 6 else 'e'
mdir = os.path.join(C, 'map_tree', 'maps', slot)
h = json.load(open(os.path.join(mdir, 'header.json'))); W, H = h['width'], h['height']
cells = struct.unpack('<%dH' % (W * H), open(os.path.join(mdir, 'grid.bin'), 'rb').read())
print('    ' + ''.join(('%-4d' % x if mode == 'm' else ('%d' % (x % 10))) for x in range(x0, x1 + 1)))
for y in range(y0, min(y1, H - 1) + 1):
    row = []
    for x in range(x0, min(x1, W - 1) + 1):
        v = cells[y * W + x]; mid = v & 0x3FF; col = (v >> 10) & 3; el = (v >> 12) & 15
        if mode == 'm': row.append('%03X ' % mid)
        else: row.append('#' if col else '%X' % el)
    print('%3d ' % y + ''.join(row))
