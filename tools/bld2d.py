#!/usr/bin/env python3
"""bld2d.py <idx> [...] — crop the original 2D art (labelled with metatile ids)
around buildings from buildings.json into sheets_bld/2d/NNN.png."""
import json,os,subprocess,sys
C=os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba')
w=json.load(open('world.json')); slot={m['id']:(m['slot'],m['pair'],m['w'],m['h']) for m in w['maps']}
b=json.load(open('buildings.json')); os.makedirs('sheets_bld/2d',exist_ok=True); os.makedirs('sheets_bld/maps',exist_ok=True)
S=4; cell=16*S+1
for i in map(int,sys.argv[1:]):
    x=b[i-1]; sl,pair,W,H=slot[x['map']]
    sheet=f"sheets_bld/maps/{x['map']}.png"
    if not os.path.exists(sheet):
        subprocess.run(['python3','tools/mapsheet.py',C,sl,pair,sheet,'--scale',str(S)],check=True,capture_output=True)
    x0,y0,x1,y1=x['box']; x0=max(0,x0-1); y0=max(0,y0-2); x1=min(W-1,x1+1); y1=min(H-1,y1+1)
    cw,ch=(x1-x0+1)*cell,(y1-y0+1)*cell
    lab=f"{i} {x['map'][3:]} door {x['door'][0]},{x['door'][1]} box {x['box']}".replace(',',' ').replace('[','').replace(']','')
    subprocess.run(['ffmpeg','-v','error','-y','-i',sheet,'-vf',
      f"crop={cw}:{ch}:{x0*cell}:{y0*cell},scale=w=900:h=600:force_original_aspect_ratio=decrease:flags=neighbor,pad=900:640:(ow-iw)/2:40:black,drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='{lab}':x=6:y=6:fontsize=22:fontcolor=white",
      f'sheets_bld/2d/{i:03d}.png'],check=True)
print('ok')
