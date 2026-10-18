#!/usr/bin/env python3
"""Run the automatic building recipe on hand-picked boxes (buildings with no
engine footprint, or whose door sits apart from the building).
python3 explicit.py <outdir> [--export DIR] [--only name,...]"""
import sys, os, argparse
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import hf, autorecipe

# name: (map, pair, [x0,y0,x1,y1], wallTop)
BOXES = {
    'cablecar_route112': ('EM_ROUTE112', 'general__lavaridge', [27, 22, 32, 27], 26),
    'cablecar_mtchimney': ('EM_MT_CHIMNEY', 'general__lavaridge', [14, 32, 19, 36], 35),
    'slateport_shipyard': ('EM_SLATEPORT_CITY', 'general__slateport', [24, 32, 31, 38], 36),
    'slateport_fanclub': ('EM_SLATEPORT_CITY', 'general__slateport', [2, 22, 6, 26], 25),
    'slateport_museum': ('EM_SLATEPORT_CITY', 'general__slateport', [28, 22, 33, 26], 25),
    'mauville_house1': ('EM_MAUVILLE_CITY', 'general__mauville', [31, 11, 35, 14], 13),
    'lilycove_house4': ('EM_LILYCOVE_CITY', 'general__lilycove', [11, 11, 14, 14], 13),
    'verdanturf_battletent': ('EM_VERDANTURF_TOWN', 'general__mauville', [1, 3, 5, 7], 6),
    'route104_briney': ('EM_ROUTE104', 'general__rustboro', [15, 47, 19, 50], 50),
    'cyclingroad_north': ('EM_ROUTE110', 'general__mauville', [14, 12, 19, 16], 14),
    'cyclingroad_south': ('EM_ROUTE110', 'general__mauville', [15, 84, 20, 88], 86),
    'route111_winstrate': ('EM_ROUTE111', 'general__mauville', [11, 109, 15, 113], 111),
    'frontier_pike': ('EM_BATTLE_FRONTIER_OUTSIDE_WEST', 'general__battle_frontier_outside_west', [40, 19, 44, 29], 25),
    'frontier_dome': ('EM_BATTLE_FRONTIER_OUTSIDE_WEST', 'general__battle_frontier_outside_west', [14, 6, 25, 17], 14),
    'frontier_factory': ('EM_BATTLE_FRONTIER_OUTSIDE_WEST', 'general__battle_frontier_outside_west', [4, 30, 18, 38], 33),
    'frontier_tower': ('EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'general__battle_frontier_outside_east', [11, 0, 21, 14], 0),
    'frontier_arena': ('EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'general__battle_frontier_outside_east', [35, 23, 43, 29], 27),
    'frontier_pyramid': ('EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'general__battle_frontier_outside_east', [51, 5, 65, 14], 12),
    'dewford_house1': ('EM_DEWFORD_TOWN', 'general__dewford', [16, 11, 19, 14], 13),
    'route104_flowershop': ('EM_ROUTE104', 'general__rustboro', [3, 15, 8, 18], 18),
    'route124_diverhouse': ('EM_ROUTE124', 'general__mossdeep', [69, 45, 72, 48], 47),
    'frontier_exchange': ('EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'general__battle_frontier_outside_east', [7, 25, 13, 28], 28),
    'mauville_eastblock': ('EM_MAUVILLE_CITY', 'general__mauville', [36, 11, 39, 14], 13),
    'route118_pinkhouse': ('EM_ROUTE118', 'general__mauville', [0, 14, 3, 17], 16),
    'trainerhill_tower': ('EM_ROUTE111', 'general__mauville', [29, 106, 33, 110], 109),
    'trainerhill_entrance': ('EM_ROUTE111', 'general__mauville', [31, 112, 31, 113], 113),
    'mauville_gamecorner': ('EM_MAUVILLE_CITY', 'general__mauville', [5, 10, 11, 13], 12),   # row 10 is its roof's back (walkable, over-layer)
    'slateport_harbor': ('EM_SLATEPORT_CITY', 'general__slateport', [24, 7, 31, 12], 11),
    'lilycove_harbor': ('EM_LILYCOVE_CITY', 'general__lilycove', [9, 30, 15, 32], 31),
    'route109_seashorehouse': ('EM_ROUTE109', 'general__slateport', [10, 3, 15, 5], 4),
    'frontier_battlepalace_lobby': ('EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'general__battle_frontier_outside_east', [40, 51, 50, 56], 53),
    'frontier_rankinghall': ('EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'general__battle_frontier_outside_east', [32, 8, 38, 12], 10),
}
# exported under the name its existing bake already has (the game matches on it)
NAMES = {'mauville_gamecorner': 'b022_mauvillecity_gamecorner',
         'slateport_harbor': 'b014_slateportcity_harbor', 'lilycove_harbor': 'b055_lilycovecity_harbor',
         'route109_seashorehouse': 'b117_route109_seashorehouse', 'frontier_battlepalace_lobby': 'b152_battlefrontier_battlepalacelobby',
         'frontier_rankinghall': 'b154_battlefrontier_rankinghall'}
# extra ground colours cut from the outside in (cliff rock around a building)
# roof override: the hip-roofed Fan Club reads as a steep symmetric gable
# whose ridge is the roof's top edge (nb rows of back slope)
GABLE = {'slateport_fanclub': 8, 'verdanturf_battletent': 18, 'frontier_dome': 50, 'frontier_pyramid': 30, 'route104_flowershop': 10}
# parapet-rimmed gravel roofs the ridge finder reads as a gable
FLAT = {'mauville_eastblock', 'cyclingroad_north', 'cyclingroad_south', 'route111_winstrate'}
# art columns beside the footprint that are not building (sign, fence, bush, sand, water):
# made ground, so they take the map's own cells instead of standing up as boxes
NOT_BUILDING = {'route109_seashorehouse': [(80, 96)], 'slateport_harbor': [(0, 16)], 'lilycove_harbor': [(111, 112)]}
# (wall-top row, top band row): low roofs stop at their own drawn top edge, not the tallest part's
# (the Ranking Hall's wings beside its vault, with the cliff drawn behind them)
ROWCAP = {'frontier_rankinghall': (31, 8)}
# stand on this map cell's floor instead of the footprint's own
STAND = {'trainerhill_tower': (34, 108)}
# the door cells (map x, y) where the side-wall picker must not take its strip
DOORS = {'lilycove_house4': [(12, 14)]}
# the facade columns repeated along the hidden walls, where the automatic picker takes a plain strip
# (the cable-car stations' bare stucco; the Ranking Hall's awning stripe, its grey windows not read as glass):
# a wall with its post, a pillar with its window panel
SIDES = {'cablecar_route112': (2, 15), 'cablecar_mtchimney': (81, 93), 'frontier_rankinghall': (8, 24), 'frontier_arena': (8, 24)}
KEYS = {'trainerhill_tower': [(99, 66, 82), (132, 90, 90), (156, 115, 115), (189, 148, 140), (222, 181, 165)],
        # the grass, bushes and trees round the harbour's roof (cut in from the edges)
        'slateport_harbor': [(115, 197, 165), (58, 140, 49), (132, 197, 99), (181, 255, 132), (58, 82, 0)],
        # the sand round the seashore house's sign and its right-hand corner
        'route109_seashorehouse': [(222, 206, 132)]}



def main():
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--export'); ap.add_argument('--only')
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    rows = []
    for name, (mp, pair, box, wt) in BOXES.items():
        if a.only and name not in a.only.split(','): continue
        g = {'map': mp, 'pair': pair, 'box': box, 'wallTop': wt}
        rec, img, kind = autorecipe.derive(g, {'doors': DOORS[name]} if name in DOORS else None)
        if name in NOT_BUILDING and rec.get('bgmask') is not None:
            for x0, x1 in NOT_BUILDING[name]: rec['bgmask'][:, x0:x1] = True
        if name in GABLE:
            segs = rec['pieces'][0]['segs']
            n = sum(sg[1] for sg in segs if sg[0] in ('flat', 'flatx'))   # flatx: a flat roof carried back
            segs[:] = [sg for sg in segs if sg[0] == 'wall'] + [('gable', n - GABLE[name], GABLE[name])]
            kind = 'gable %d/%d' % (n - GABLE[name], GABLE[name])
        if name in FLAT:
            segs = rec['pieces'][0]['segs']
            n = sum(sg[1] + (sg[2] if sg[0] == 'gable' else 0) for sg in segs if sg[0] != 'wall')
            segs[:] = [sg for sg in segs if sg[0] == 'wall'] + [('flat', n)]
            kind = 'flat roof %d' % n
        if name in SIDES:
            for p_ in rec['pieces']: p_['side'] = p_['fill'] = SIDES[name]; p_.pop('gside', None)
        if name in ROWCAP:
            # each column's roof stops at its drawn top: the topmost row of the unbroken building
            # run up from the wall top (the vault, drawn up to the top band, keeps its full roof)
            r0, rmin = ROWCAP[name]; bg = rec['bgmask']; cap = {}
            for x in range(img.shape[1]):
                r = r0
                while r - 1 >= rmin and not bg[r - 1, x] and img[r - 1, x, 3] >= 128: r -= 1
                if r > rmin: cap[x] = r
            for p_ in rec['pieces']: p_['rowcap'] = cap
        if name in STAND: rec['standOn'] = STAND[name]
        if name in KEYS: rec['keys'] = KEYS[name]; rec['flood'] = True
        v = hf.build(img, rec); q = hf.mesh(v)
        views = [hf.crop_to_content(hf.render(q, v, level=4, yaw=y)).convert('RGB') for y in (0, 35, 215)]
        if a.export:
            nm = NAMES.get(name, 'x_' + name)
            hf.export(nm, rec, img, q, v, os.path.join(a.export, nm + '.lua'))
        ims = [Image.fromarray(img).convert('RGB')] + views
        ims = [i.resize((i.width * 2, i.height * 2), Image.NEAREST) for i in ims]
        pane = Image.new('RGB', (sum(i.width for i in ims) + 40, max(i.height for i in ims) + 14), (20, 20, 24)); x = 0
        for i in ims: pane.paste(i, (x, 14)); x += i.width + 10
        ImageDraw.Draw(pane).text((2, 1), '%s [%s]' % (name, kind), fill=(255, 230, 0)); rows.append(pane)
        print(name, kind)
    if rows:
        s = Image.new('RGB', (max(r.width for r in rows), sum(r.height for r in rows)))
        y = 0
        for r in rows: s.paste(r, (0, y)); y += r.height
        s.save(os.path.join(a.out, 'explicit.png'))


if __name__ == '__main__':
    main()
