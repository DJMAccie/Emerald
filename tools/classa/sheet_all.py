#!/usr/bin/env python3
# sheet_all.py OUTDIR OLD_LABEL NEW_LABEL   per map one PNG: rows = spots x yaw (0,90), cols old L4/L6/L7 | new L4/L6/L7
import sys, os, subprocess, collections
out, old, new = sys.argv[1:4]
R = os.path.expanduser('~/Documents/Emerald')
os.makedirs(out, exist_ok=True)
spots = collections.OrderedDict()
for d in sorted(os.listdir('%s/.autoloop/runs/%sy0' % (R, old))):
    if os.path.isdir('%s/.autoloop/runs/%sy0/%s' % (R, old, d)):
        m, x, y = d.rsplit('_', 2); spots.setdefault(m, []).append('%s,%s' % (x, y))
for m, ss in spots.items():
    for yaw in (0, 90):
        subprocess.run(['python3', R + '/tools/classc/ab_sheet.py', '%s/%s_y%d.png' % (out, m, yaw), '%sy%d' % (old, yaw), '%sy%d' % (new, yaw), m] + ss, check=True, stdout=subprocess.DEVNULL)
print(len(spots), 'maps ->', out)
