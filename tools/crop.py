#!/usr/bin/env python3
"""crop.py <in.png> <out.png> x0 y0 x1 y1 [scale] — crop and enlarge a capture (pure Python)."""
import zlib, struct, sys
def load(p):
    d=open(p,'rb').read(); pos=8; idat=b''
    while pos<len(d):
        n=struct.unpack('>I',d[pos:pos+4])[0]; t=d[pos+4:pos+8]; c=d[pos+8:pos+8+n]
        if t==b'IHDR': w,h=struct.unpack('>II',c[:8]); bpp=4 if c[9]==6 else 3
        if t==b'IDAT': idat+=c
        pos+=12+n
    raw=zlib.decompress(idat); stride=w*bpp+1; rows=[]; prev=bytearray(w*bpp)
    for y in range(h):
        f=raw[y*stride]; line=bytearray(raw[y*stride+1:(y+1)*stride])
        for i in range(len(line)):
            a=line[i-bpp] if i>=bpp else 0; b=prev[i]; c=prev[i-bpp] if i>=bpp else 0
            if f==1: line[i]=(line[i]+a)&255
            elif f==2: line[i]=(line[i]+b)&255
            elif f==3: line[i]=(line[i]+(a+b)//2)&255
            elif f==4:
                pp=a+b-c; pa,pb,pc=abs(pp-a),abs(pp-b),abs(pp-c)
                line[i]=(line[i]+(a if pa<=pb and pa<=pc else b if pb<=pc else c))&255
        rows.append(bytes(line)); prev=line
    return w,h,bpp,rows
def save(p,w,h,rows):
    raw=b''.join(b'\x00'+r for r in rows)
    def chunk(t,c): return struct.pack('>I',len(c))+t+c+struct.pack('>I',zlib.crc32(t+c)&0xffffffff)
    open(p,'wb').write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
src,dst=sys.argv[1],sys.argv[2]; x0,y0,x1,y1=map(int,sys.argv[3:7]); S=int(sys.argv[7]) if len(sys.argv)>7 else 3
w,h,bpp,rows=load(src); out=[]
for y in range(y0,y1):
    line=bytearray()
    for x in range(x0,x1): line+=rows[y][x*bpp:x*bpp+3]*S
    for _ in range(S): out.append(bytes(line))
save(dst,(x1-x0)*S,(y1-y0)*S,out)
