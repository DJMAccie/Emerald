# tv.py <pairdir> <out.png> <S> <layer u|o|c> mid,mid,...  : zoomed tiles, a row tick every 4 px
import sys,os,zlib,glob,struct
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import sheet
d,out,S,layer=sys.argv[1],sys.argv[2],int(sys.argv[3]),sys.argv[4]
mids=[int(x,0) for x in sys.argv[5].split(',')]
raw=open(d+'/mids.idx','rb').read(); raw=raw if raw[:4]==b'SVMI' else zlib.decompress(raw)
count,cols,rows=struct.unpack_from('<HHH',raw,6); ids=struct.unpack_from('<%dH'%count,raw,12)
w,h=cols*16,rows*16
def rd(p):
    b=open(p,'rb').read()
    if len(b)!=w*h*4:b=zlib.decompress(b)
    return b
u=rd(glob.glob(d+'/atlas_u_*.rgba')[0]); ov=glob.glob(d+'/atlas_o_*.rgba'); o=rd(ov[0]) if ov else None
slot={m:i for i,m in enumerate(ids)}
G=16*S+14;C=len(mids)
W=C*G;H=G
img=[[(70,70,70,255)]*W for _ in range(H)]
for k,m in enumerate(mids):
    s=slot[m];ox,oy=s%cols*16,s//cols*16;gx=k*G
    for y in range(16):
        for x in range(16):
            i=((oy+y)*w+ox+x)*4
            if layer=='o':
                if o is None or o[i+3]<=127: r,g,b=255,0,255
                else: r,g,b=o[i],o[i+1],o[i+2]
            else:
                r,g,b=u[i],u[i+1],u[i+2]
                if layer=='c' and o is not None and o[i+3]>127:r,g,b=o[i],o[i+1],o[i+2]
            for dy in range(S):
                for dx in range(S): img[7+y*S+dy][gx+7+x*S+dx]=(r,g,b,255)
    for y in range(0,16,4):
        for xx in range(0,5):img[7+y*S][gx+xx]=(255,0,0,255)
rows_=[bytes(c for px in row for c in px) for row in img]
open(out,'wb').write(sheet.png(W,H,rows_)); print('ok',len(mids),[hex(m) for m in mids if m not in slot])
