#!/usr/bin/env python3
# draw_pack.py [MAP ...]  -> docs/elevation/draw/<MAP>.png
# One gridded 2D sheet per outdoor map (ROM art, scale 3, grid every cell,
# coordinates every 5 cells) for the user to write heights on by hand.
# Convention printed in the header strip: numbers = 16 px courses above the
# map's ground level (0); sea / shallows = 0; one number per flat area.
import sys, os, subprocess
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'relief'))
from emdata import Layout
HERE = os.path.dirname(os.path.abspath(__file__))
CROP = os.path.join(HERE, '..', '..', 'skills', 'emerald-terrain', 'scripts', 'crop2d.py')
OUT = os.path.join(HERE, '..', '..', 'docs', 'elevation', 'draw')
ALL = ('EM_BATTLE_FRONTIER_OUTSIDE_EAST EM_BATTLE_FRONTIER_OUTSIDE_WEST EM_DEWFORD_TOWN EM_EVER_GRANDE_CITY '
 'EM_FALLARBOR_TOWN EM_FORTREE_CITY EM_JAGGED_PASS EM_LAVARIDGE_TOWN EM_LILYCOVE_CITY EM_MAUVILLE_CITY '
 'EM_MOSSDEEP_CITY EM_MT_CHIMNEY EM_MT_PYRE_EXTERIOR EM_MT_PYRE_SUMMIT EM_PACIFIDLOG_TOWN EM_ROUTE103 '
 'EM_ROUTE104 EM_ROUTE105 EM_ROUTE106 EM_ROUTE107 EM_ROUTE108 EM_ROUTE109 EM_ROUTE110 EM_ROUTE111 '
 'EM_ROUTE112 EM_ROUTE113 EM_ROUTE114 EM_ROUTE115 EM_ROUTE116 EM_ROUTE117 EM_ROUTE118 EM_ROUTE119 '
 'EM_ROUTE120 EM_ROUTE121 EM_ROUTE122 EM_ROUTE123 EM_ROUTE124 EM_ROUTE125 EM_ROUTE126 EM_ROUTE127 '
 'EM_ROUTE128 EM_ROUTE129 EM_ROUTE130 EM_ROUTE131 EM_ROUTE132 EM_ROUTE133 EM_ROUTE134 '
 'EM_SAFARI_ZONE_NORTH EM_SAFARI_ZONE_NORTHEAST EM_SAFARI_ZONE_NORTHWEST EM_SAFARI_ZONE_SOUTH '
 'EM_SAFARI_ZONE_SOUTHEAST EM_SAFARI_ZONE_SOUTHWEST EM_SKY_PILLAR_OUTSIDE EM_SLATEPORT_CITY '
 'EM_SOOTOPOLIS_CITY EM_SOUTHERN_ISLAND_EXTERIOR EM_LITTLEROOT_TOWN EM_OLDALE_TOWN EM_PETALBURG_CITY '
 'EM_RUSTBORO_CITY EM_VERDANTURF_TOWN EM_ROUTE101 EM_ROUTE102 EM_PETALBURG_WOODS').split()
maps = sys.argv[1:] or ALL
os.makedirs(OUT, exist_ok=True)
S = 3
for m in maps:
    try: L = Layout(m)
    except Exception as e: print('skip', m, e); continue
    out = os.path.join(OUT, m + '.png')
    subprocess.run(['python3', CROP, L.slot, L.pair, '0', '0', str(L.w - 1), str(L.h - 1), out, str(S)], check=True)
    # header strip with the convention
    from PIL import Image, ImageDraw
    im = Image.open(out).convert('RGB')
    strip = Image.new('RGB', (im.width, 40), (255, 255, 255))
    d = ImageDraw.Draw(strip)
    d.text((6, 4), '%s  %dx%d cells.  Write the height as COURSES above this map\'s ground (0): 1 course = 16 px = one rock step.' % (m, L.w, L.h), fill=(0, 0, 0))
    d.text((6, 20), 'Sea and shallows = 0. One number per flat area / rock top; slopes are interpolated. Mark anything else with a word.', fill=(0, 0, 0))
    full = Image.new('RGB', (im.width, im.height + 40), (0, 0, 0)); full.paste(strip, (0, 0)); full.paste(im, (0, 40)); full.save(out)
    print(m, L.w, L.h, full.size)
