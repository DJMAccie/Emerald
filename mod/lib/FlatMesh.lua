-- FlatMesh
local V=...
local R=V.require('Voxel3D')
local Budget=V.require('BuildBudget')
local M={}

local CHUNK=1200 -- numbers per pack call (50 quads)
local FMT=string.rep('f',CHUNK)
-- Shared index map, 0-based uint32 (1,2,3,1,3,4 per quad).
local mapData,mapQuads=nil,0
local function vertexMap(quads)
 if quads>mapQuads then
  local n=math.max(quads,mapQuads*2,4096)
  local parts,vals={},{}
  for q=0,n-1,50 do
   local k=0
   for j=q,math.min(n-1,q+49)do local b=j*4
    vals[k+1],vals[k+2],vals[k+3],vals[k+4],vals[k+5],vals[k+6]=b,b+1,b+2,b,b+2,b+3;k=k+6
   end
   parts[#parts+1]=love.data.pack('string',string.rep('I4',k),unpack(vals,1,k))
  end
  if mapData then mapData:release() end
  mapData=love.data.newByteData(table.concat(parts));mapQuads=n
 end
 return love.data.newDataView(mapData,0,quads*24)
end

local function tables(f,n)
 local verts,idx={},{}
 for q=0,n/24-1 do local o=q*24;local b=q*4
  for k=0,3 do local p=o+k*6;verts[b+k+1]={f[p+1],f[p+2],f[p+3],f[p+4],f[p+5],f[p+6]} end
  local m=#idx;idx[m+1],idx[m+2],idx[m+3],idx[m+4],idx[m+5],idx[m+6]=b+1,b+2,b+3,b+1,b+3,b+4
 end
 return R.newMesh(verts,idx)
end

function M.mesh(f,n)
 if n==0 then return nil end
 if R.probe then return tables(f,n) end
 Budget.check()
 local parts={}
 for s=1,n,CHUNK do
  local e=math.min(n,s+CHUNK-1)
  parts[#parts+1]=love.data.pack('string',e-s+1==CHUNK and FMT or string.rep('f',e-s+1),unpack(f,s,e))
 end
 local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,n/6,'triangles','static')
 if not ok then return nil,tostring(mesh) end
 local data=love.data.newByteData(table.concat(parts))
 local view=vertexMap(n/24)
 local ok2,err=pcall(function()mesh:setVertices(data,1);mesh:setVertexMap(view,'uint32')end)
 data:release();view:release()
 if not ok2 then mesh:release();return nil,tostring(err) end
 return mesh
end

return M
