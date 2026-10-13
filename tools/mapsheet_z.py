# mapsheet.py with zlib-wrapped cache files decompressed on read
import sys,zlib,struct
sys.path.insert(0,'/Users/user/Documents/Emerald/tools')
import sheet
def _raw(p):
    b=open(p,'rb').read()
    try: return zlib.decompress(b)
    except Exception: return b
def read_idx(path):
    b=_raw(path); assert b[:4]==b'SVMI'
    count,cols,rows=struct.unpack_from('<HHH',b,6); ids=struct.unpack_from('<%dH'%count,b,12)
    return count,cols,rows,ids
def read_rgba(path,w,h):
    b=_raw(path); assert len(b)==w*h*4,(len(b),w*h*4); return b
sheet.read_idx=read_idx; sheet.read_rgba=read_rgba
import mapsheet
sys.argv=['mapsheet.py']+sys.argv[1:]
mapsheet.main()
