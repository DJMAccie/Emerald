#!/usr/bin/env python3
# make_allrocks_md.py -> docs/rock-gates/ALL-ROCKS.md  (census table game1/table.md + my eyeball verdicts per map)
import re, csv, collections
V = {  # map: (verdict, class, note)   verdict ok / suspect / wrong; set by eye on docs/rock-gates/ALL-ROCKS/maps/<map>.png (2D | L4 | L6 | L7)
 'EM_ROUTE126': ('suspect', 'B', 'faceted dome slab on the big island (43,58 L6); thin fins elsewhere'),
 'EM_ROUTE127': ('suspect', 'B', 'tall thin spires and ridge fins (53,54 L6/L7), 2D is low flat pink'),
 'EM_ROUTE131': ('wrong', 'B', 'huge faceted dome slab (5,10 L6), flat terraced slab (9,31), spikes'),
 'EM_ROUTE133': ('wrong', 'B', 'crater at (36,17) is a streaked triangle fan, not stepped rock; spikes (43,29)'),
 'EM_ROUTE124': ('suspect', 'B', 'islands read as pyramids/spires; 2D is rounded low rock'),
 'EM_ROUTE134': ('not eyeballed', 'B', 'same builder as 131/133'), 'EM_ROUTE132': ('not eyeballed', 'B', 'same builder'),
 'EM_ROUTE130': ('not eyeballed', 'B', 'same builder, almost all sea boulders'), 'EM_ROUTE129': ('not eyeballed', 'B', 'same builder'),
 'EM_ROUTE128': ('not eyeballed', 'B', '36 relief cells, 409 old rock'),
 'EM_BATTLE_FRONTIER_OUTSIDE_EAST': ('wrong', 'C', 'rock tiles are building/hedge art: Tower draws as one dome; sea-edge walls fine'),
 'EM_BATTLE_FRONTIER_OUTSIDE_WEST': ('wrong', 'C', 'striped building (13,38) is a flat dome; walls at sea edge fine'),
 'EM_SOOTOPOLIS_CITY': ('wrong', 'C', 'crater wall is one flat white plane (13,48 L4); needs its own tables'),
 'EM_JAGGED_PASS': ('suspect', 'C', 'old red terraces, plausible; never moved to the red counted method'),
 'EM_SAFARI_ZONE_NORTHEAST': ('ok?', 'D', 'low brown ledges, plausible'), 'EM_SAFARI_ZONE_NORTH': ('ok?', 'D', 'low ledges, plausible'),
 'EM_SAFARI_ZONE_NORTHWEST': ('suspect', 'D', 'lone boulder drawn as a faceted dome (21,15 L6)'),
 'EM_SAFARI_ZONE_SOUTHEAST': ('not eyeballed', 'D', ''), 'EM_SAFARI_ZONE_SOUTH': ('not eyeballed', 'D', ''), 'EM_SAFARI_ZONE_SOUTHWEST': ('not eyeballed', 'D', ''),
 'EM_SOUTHERN_ISLAND_EXTERIOR': ('ok?', 'A', 'terraced island reads like the 2D; left on old rock on purpose, keep unless the user objects'),
 'EM_SKY_PILLAR_OUTSIDE': ('suspect', 'A', 'two floors done; west ridge pillars, L6 looks into a dark wall (camera in rock)'),
 'EM_SKY_PILLAR_TOP': ('ok?', 'D', 'walls of the top floor, plain slab'),
 'EM_MT_PYRE_SUMMIT': ('ok', '-', 'counted relief, ridges read right'),
 'EM_ROUTE112': ('suspect', 'D', 'open cards G3 (30,22) and G6 (19,35); red walls ok'),
 'EM_LILYCOVE_CITY': ('ok?', 'B', 'old rock, ledges plausible, small lump rocks'),
 'EM_ROUTE121': ('ok?', 'B', 'old rock, cliff steps plausible'),
 'EM_LAVARIDGE_TOWN': ('not eyeballed', 'D', 'capped at 32 (task 23)'),
 'EM_ROUTE111': ('suspect', 'D', 'open cards H1 (15,14), H2 (16,38)'),
}
rows = [l for l in open('game1/table.md') if l.startswith('| EM_')]
tot = [l for l in open('game1/table.md') if 'TOTAL' in l][0]
spots = collections.defaultdict(list)
for r in csv.DictReader(open('spots.csv')): spots[r['map']].append('%s,%s' % (r['sx'], r['sy']))
o = ['# ALL-ROCKS: census of every outdoor rock (2026-10-25, task 27)', '',
 'Source: per-cell builder census of the INSTALLED game build (tools/relief/stage3/allrocks, game1/), 59 outdoor maps with rock cells, '
 '110 capture spots (docs/rock-gates/general-rollout/allrocks1). One sheet per map: docs/rock-gates/ALL-ROCKS/maps/<MAP>.png, columns = 2D original | 3D level 4 | level 6 | level 7.',
 'Builders: relief = Gen3Relief counted heights (the new method); rock = Gen3Rock course-built (the OLD rock); dome = Gen3Mass dome (stones, boulders, Frontier/Sootopolis tiles); sea = sea boulders (not part of this pass).',
 'Verdict is MY eye on the sheet, the user decides: ok / ok? / suspect / wrong / not eyeballed. Caves are not in this table (task 28, after the outdoor pass).', '',
 'Classes: A = ridge/course builder shape (pillars, slits); B = old sea/shoal rock still on Gen3Rock (Routes 121-134, Lilycove); C = tilesets with no tables (Battle Frontier, Sootopolis, Jagged Pass); D = open ghost cards / small leftovers (Safari, Route 111/112, Lavaridge, Sky Pillar top).', '',
 '| map | cells | relief | rock | dome | sea | tile classes | verdict | class | note | spots |', '|---|---|---|---|---|---|---|---|---|---|---|']
for l in rows:
    p = [x.strip() for x in l.strip().strip('|').split('|')]
    m = p[0]; v = V.get(m)
    if v is None:
        relief = int(p[2]); cells = int(p[1])
        v = ('ok? (counted relief)' if relief >= .9 * cells else 'not eyeballed', '-', '')
    o.append('| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (m, *p[1:7], *v, ' '.join(spots.get(m, []))))
o.append(tot.strip()); o.append('')
open('/Users/user/Documents/Emerald/docs/rock-gates/ALL-ROCKS.md', 'w').write('\n'.join(o) + '\n')
print(len(rows))
