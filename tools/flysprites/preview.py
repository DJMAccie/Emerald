# Preview drawn species without baking: python3 preview.py 16 [21 ...] -> drawn_preview.png (4 rows x 4 beats, 4x)
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
import bake_flyers as B
S = 4
blocks = []
for a in sys.argv[1:]:
    nat = int(a)
    n, s, label = B.source_for(nat, 'drawn')
    blocks.append((nat, n['frames']))
fw = max(b[1][0][0].size[0] for b in blocks); fh = max(b[1][0][0].size[1] for b in blocks)
out = Image.new('RGBA', (60 + 4 * (fw * S + 6) + 30 + 4 * (fw * S + 6), len(blocks) * (2 * (fh * S + 6) + 14)), (110, 160, 210, 255))
d = ImageDraw.Draw(out); y = 0
for nat, rows in blocks:
    d.text((4, y + 4), str(nat), fill=(0, 0, 0, 255))
    for r in range(4):
        for c, f in enumerate(rows[r]):
            big = f.resize((f.size[0] * S, f.size[1] * S), Image.NEAREST)
            x = 60 + (r % 2) * (4 * (fw * S + 6) + 30) + c * (fw * S + 6)
            out.paste(big, (x, y + 14 + (r // 2) * (fh * S + 6)), big)
    y += 2 * (fh * S + 6) + 14
out.save('drawn_preview.png'); print(out.size)
