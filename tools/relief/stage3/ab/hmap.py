import sys
f,m=sys.argv[1],sys.argv[2]
x0,y0,x1,y1=map(int,sys.argv[3:7])
cells={}
for l in open(f):
    p=l.split()
    if p[0]!=m: continue
    x,y,mid,coll,lo,hi,gl,gh,mo=int(p[1]),int(p[2]),p[3],p[4],float(p[5]),float(p[6]),p[7],p[8],p[9]
    if gl=='-': c='n'
    else:
        d=hi-float(gl)
        c='F' if d<=6 else ('f' if d<=14 else 'r')
        if hi<float(gl)-6: c='v'   # sunk below the ground beside it
    if mo=='1': c='M'
    cells[(x,y)]=c
print('   '+''.join(str(x%10) for x in range(x0,x1+1)))
for y in range(y0,y1+1):
    print('%3d'%y+''.join(cells.get((x,y),'.') for x in range(x0,x1+1)))
