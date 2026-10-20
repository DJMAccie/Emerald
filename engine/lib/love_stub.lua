-- Headless stand-in for the LOVE 11.5 API the voxel mod's scene builder touches.
-- Only what changes geometry is real:
--   * ImageData holds real pixels (FFI byte buffer) and getPixel returns LOVE's float32 values (byte/255f),
--     so every pixel test the builder makes (tree crowns, glass, rock faces) sees what the game sees;
--   * Mesh keeps the vertex list and vertex map it was made from (the dump reads the Lua tables, as the
--     in-game driver does);
--   * love.timer.getTime is a frozen clock while a build runs, so BuildBudget never yields (a build is one
--     resume) - see engine/README.md.
-- Everything else (shaders, canvases, drawing state) is an inert object; every name reached through the
-- catch-all is counted in M.unknown so a run can list what it stood in for.
local ffi=require('ffi')
local M={unknown={}}
local function note(name)M.unknown[name]=(M.unknown[name] or 0)+1 end

-- float32 view of byte/255, exactly as LOVE's Colorf (float) hands it to Lua
local F32={}
do local f=ffi.new('float[1]')
 for b=0,255 do f[0]=b/255;F32[b]=tonumber(f[0]) end
end
M.F32=F32
local fbuf=ffi.new('float[1]')
local function tof(x)fbuf[0]=x;return tonumber(fbuf[0])end
-- LOVE 11.5 setPixelRGBA8: (uint8)(clamp01(c)*255.0f+0.5f), all in float
local function tobyte(c)
 c=tof(tonumber(c) or 0)
 if c<0 then c=0 elseif c>1 then c=1 end
 return math.floor(tof(tof(c*255)+0.5))
end

-- ------------------------------------------------------------------ inert objects
local Inert={}
Inert.__index=function(t,k)
 note('object:'..tostring(k))
 return function(self,...)return nil end
end
local function inert(kind,fields)
 local o=fields or {}
 o._kind=kind
 return setmetatable(o,Inert)
end
M.inert=inert

-- ------------------------------------------------------------------ ImageData
local ImageData={}
ImageData.__index=ImageData
local function newImageData(w,h,format,data)
 w,h=math.floor(w),math.floor(h)
 local self=setmetatable({w=w,h=h,format=format or 'rgba8'},ImageData)
 self.n=w*h*4
 self.p=ffi.new('uint8_t[?]',math.max(1,self.n))
 if type(data)=='string' then
  ffi.copy(self.p,data,math.min(#data,self.n))
 elseif type(data)=='table' and data.getString then
  local s=data:getString();ffi.copy(self.p,s,math.min(#s,self.n))
 end
 return self
end
M.newImageData=newImageData
function ImageData:getWidth()return self.w end
function ImageData:getHeight()return self.h end
function ImageData:getDimensions()return self.w,self.h end
function ImageData:getFormat()return self.format end
function ImageData:getSize()return self.n end
function ImageData:release()return true end
function ImageData:type()return 'ImageData' end
function ImageData:typeOf(t)return t=='ImageData' or t=='Data' or t=='Object' end
function ImageData:getString()return ffi.string(self.p,self.n)end
function ImageData:getPointer()return self.p end
function ImageData:getFFIPointer()return self.p end
function ImageData:getPixel(x,y)
 x,y=math.floor(x),math.floor(y)
 if x<0 or y<0 or x>=self.w or y>=self.h then error('Attempt to get out-of-range pixel!',2) end
 local i=(y*self.w+x)*4;local p=self.p
 return F32[p[i]],F32[p[i+1]],F32[p[i+2]],F32[p[i+3]]
end
function ImageData:setPixel(x,y,r,g,b,a)
 x,y=math.floor(x),math.floor(y)
 if x<0 or y<0 or x>=self.w or y>=self.h then error('Attempt to set out-of-range pixel!',2) end
 if type(r)=='table' then r,g,b,a=r[1],r[2],r[3],r[4] end
 local i=(y*self.w+x)*4;local p=self.p
 p[i],p[i+1],p[i+2],p[i+3]=tobyte(r),tobyte(g),tobyte(b),tobyte(a==nil and 1 or a)
end
function ImageData:paste(src,dx,dy,sx,sy,sw,sh)
 sx,sy=sx or 0,sy or 0;sw,sh=sw or src.w,sh or src.h
 dx,dy=math.floor(dx or 0),math.floor(dy or 0)
 -- LOVE clips the rectangle to both images
 if sx<0 then sw=sw+sx;dx=dx-sx;sx=0 end
 if sy<0 then sh=sh+sy;dy=dy-sy;sy=0 end
 if dx<0 then sw=sw+dx;sx=sx-dx;dx=0 end
 if dy<0 then sh=sh+dy;sy=sy-dy;dy=0 end
 sw=math.min(sw,src.w-sx,self.w-dx);sh=math.min(sh,src.h-sy,self.h-dy)
 if sw<=0 or sh<=0 then return end
 for y=0,sh-1 do
  ffi.copy(self.p+((dy+y)*self.w+dx)*4,src.p+((sy+y)*src.w+sx)*4,sw*4)
 end
end
function ImageData:mapPixel(fn,x0,y0,w,h)
 x0,y0=x0 or 0,y0 or 0;w,h=w or self.w,h or self.h
 for y=y0,y0+h-1 do for x=x0,x0+w-1 do
  local r,g,b,a=fn(x,y,self:getPixel(x,y))
  self:setPixel(x,y,r,g,b,a)
 end end
end
function ImageData:clone()
 local o=newImageData(self.w,self.h,self.format);ffi.copy(o.p,self.p,self.n);return o
end
function ImageData:encode()note('ImageData:encode');return nil end
M.ImageData=ImageData

-- ------------------------------------------------------------------ Image (texture)
local Image={}
local IMAGE_FIELDS={w=1,h=1,data=1,released=1,_type=1}
Image.__index=function(t,k)
 local v=rawget(Image,k);if v~=nil then return v end
 if IMAGE_FIELDS[k] then return nil end
 note('Image:'..tostring(k));return function()end
end
function Image:getDimensions()return self.w,self.h end
function Image:getWidth()return self.w end
function Image:getHeight()return self.h end
function Image:getPixelDimensions()return self.w,self.h end
function Image:getPixelWidth()return self.w end
function Image:getPixelHeight()return self.h end
function Image:setFilter()end
function Image:getFilter()return 'nearest','nearest'end
function Image:setWrap()end
function Image:getWrap()return 'clamp','clamp'end
function Image:setMipmapFilter()end
function Image:release()self.released=true;return true end
function Image:replacePixels(data)if self.data and data then self.data=data end end
function Image:type()return self._type or 'Image' end
function Image:typeOf(t)return t==(self._type or 'Image') or t=='Texture' or t=='Drawable' or t=='Object' end
function Image:getFormat()return 'rgba8' end
function Image:getTextureType()return '2d' end
function Image:getDPIScale()return 1 end
function Image:getMipmapCount()return 1 end
function Image:isReadable()return true end
local function newImage(src,settings)
 local w,h,data=1,1,nil
 if type(src)=='table' and getmetatable(src)==ImageData then w,h,data=src.w,src.h,src
 elseif type(src)=='table' and src.w then w,h=src.w,src.h
 else note('newImage('..type(src)..')') end
 return setmetatable({w=w,h=h,data=data},Image)
end
local function newCanvas(w,h)
 return setmetatable({w=math.floor(w or 1),h=math.floor(h or 1),_type='Canvas',renderTo=function(self,f)end,
  newImageData=function(self)return newImageData(self.w,self.h)end},Image)
end

-- ------------------------------------------------------------------ Mesh
local Mesh={}
-- fields the stand-in keeps (edits, map, range...) must read as nil when unset: only method names fall back
local MESH_FIELDS={verts=1,map=1,edits=1,count=1,format=1,texture=1,range=1,mode=1,released=1,raw=1}
Mesh.__index=function(t,k)
 local v=rawget(Mesh,k);if v~=nil then return v end
 if MESH_FIELDS[k] then return nil end
 note('Mesh:'..tostring(k));return function()end
end
function Mesh:setVertexMap(map,...)
 if type(map)=='table' then self.map=map elseif map~=nil then self.map={map,...} else self.map=nil end
end
function Mesh:getVertexMap()return self.map end
function Mesh:getVertexCount()return self.count end
function Mesh:getVertex(i)
 local v=self.edits and self.edits[i] or self.verts[i]
 if type(v)=='table' then return unpack(v) end
end
-- GPU-side edit: kept apart so the Lua vertex table the dump reads stays as the builder left it
function Mesh:setVertex(i,...)self.edits=self.edits or {};local a={...};if type(a[1])=='table' then a=a[1] end;self.edits[i]=a end
function Mesh:setVertices(list,start)
 if type(list)~='table' or getmetatable(list) then self.raw=list;return end
 self.edits=self.edits or {};for k,v in ipairs(list)do self.edits[(start or 1)+k-1]=v end
end
function Mesh:setTexture(t)self.texture=t end
function Mesh:getTexture()return self.texture end
function Mesh:setDrawRange(a,b)self.range={a,b}end
function Mesh:getDrawRange()if self.range then return self.range[1],self.range[2]end end
function Mesh:setDrawMode(m)self.mode=m end
function Mesh:getDrawMode()return self.mode or 'triangles' end
function Mesh:attachAttribute()end
function Mesh:detachAttribute()end
function Mesh:setAttributeEnabled()end
function Mesh:getVertexFormat()return self.format end
function Mesh:release()self.released=true;return true end
function Mesh:type()return 'Mesh' end
function Mesh:typeOf(t)return t=='Mesh' or t=='Drawable' or t=='Object' end
local function newMesh(a,b,c,d)
 -- newMesh(format, vertices, mode, usage) | newMesh(vertices, mode, usage) | newMesh(count, ...)
 local format,verts=nil,nil
 if type(a)=='table' and type(b)=='table' then format,verts=a,b
 elseif type(a)=='table' then verts=a
 elseif type(b)=='number' then format=a;verts={};for i=1,b do verts[i]={} end
 elseif type(a)=='number' then verts={};for i=1,a do verts[i]={} end end
 return setmetatable({format=format,verts=verts,count=verts and #verts or 0},Mesh)
end
M.Mesh=Mesh

-- ------------------------------------------------------------------ Shader
local Shader={}
Shader.__index=function(t,k)
 local v=rawget(Shader,k);if v~=nil then return v end
 return function()end
end
function Shader:hasUniform()return true end
function Shader:send()end
function Shader:sendColor()end
function Shader:getWarnings()return '' end
function Shader:release()return true end
function Shader:type()return 'Shader' end

-- ------------------------------------------------------------------ the love table
local clock={t=1000,frozen=true}
M.clock=clock
-- only love.graphics answers unknown names (drawing state the build never reads back); the other modules
-- are plain tables, so feature tests (`if love.data.hash then`) see what is really there
local function lib(name,t,catchAll)
 if not catchAll then return t end
 return setmetatable(t,{__index=function(_,k)
  note('love.'..name..'.'..tostring(k))
  return function()return nil end
 end})
end
local canvasStack,curCanvas={},nil
local love={}
love.graphics=lib('graphics',{
 newImage=newImage,newCanvas=newCanvas,newMesh=newMesh,
 newArrayImage=function()return newImage({w=1,h=1})end,
 newShader=function()return setmetatable({},Shader)end,
 newQuad=function(x,y,w,h,sw,sh)return inert('Quad',{x=x,y=y,w=w,h=h,sw=sw,sh=sh,getViewport=function(q)return q.x,q.y,q.w,q.h end})end,
 newSpriteBatch=function(tex)return inert('SpriteBatch',{texture=tex})end,
 newFont=function()return inert('Font',{getHeight=function()return 8 end,getWidth=function()return 8 end})end,
 newImageFont=function()return inert('Font',{getHeight=function()return 8 end,getWidth=function()return 8 end})end,
 getCanvas=function()return curCanvas end,
 setCanvas=function(c)curCanvas=type(c)=='table' and (c[1] or c) or c end,
 getDimensions=function()return 1280,720 end,getWidth=function()return 1280 end,getHeight=function()return 720 end,
 getPixelDimensions=function()return 1280,720 end,getDPIScale=function()return 1 end,
 getSupported=function()return setmetatable({},{__index=function()return true end})end,
 getSystemLimits=function()return setmetatable({texturesize=16384},{__index=function()return 16384 end})end,
 getRendererInfo=function()return 'OpenGL','4.1','headless','headless'end,
 getStats=function()return {drawcalls=0,canvasswitches=0,texturememory=0,images=0,canvases=0,fonts=0,shaderswitches=0,drawcallsbatched=0}end,
 getTextureTypes=function()return setmetatable({},{__index=function()return true end})end,
 getCanvasFormats=function()return setmetatable({},{__index=function()return true end})end,
 getImageFormats=function()return setmetatable({},{__index=function()return true end})end,
 getColor=function()return 1,1,1,1 end,getBlendMode=function()return 'alpha','alphamultiply'end,
 getShader=function()return nil end,getDepthMode=function()return 'always',false end,
 getMeshCullMode=function()return 'none'end,getDefaultFilter=function()return 'nearest','nearest',1 end,
 isActive=function()return true end,isGammaCorrect=function()return false end,
 isCreated=function()return true end,validateShader=function()return true end,
 push=function()end,pop=function()end,origin=function()end,translate=function()end,scale=function()end,rotate=function()end,
 setColor=function()end,setBlendMode=function()end,setShader=function()end,setDepthMode=function()end,setMeshCullMode=function()end,
 setScissor=function()end,setDefaultFilter=function()end,setFrontFaceWinding=function()end,setColorMask=function()end,setStencilTest=function()end,
 setLineWidth=function()end,setPointSize=function()end,setFont=function()end,setWireframe=function()end,
 clear=function()end,draw=function()end,drawInstanced=function()end,rectangle=function()end,line=function()end,print=function()end,
 flushBatch=function()end,reset=function()end,discard=function()end,stencil=function()end,
},true)
love.image=lib('image',{newImageData=function(w,h,format,data)
  if type(w)=='number' then return newImageData(w,h,format,data) end
  note('love.image.newImageData('..type(w)..')');return newImageData(1,1)
 end,
 isCompressed=function()return false end})
love.timer=lib('timer',{
 getTime=function()if clock.frozen then return clock.t end return os.clock()end,
 getDelta=function()return 1/60 end,getFPS=function()return 60 end,step=function()return 1/60 end,sleep=function()end,
 getAverageDelta=function()return 1/60 end})
local Z=require('zlib')
love.data=lib('data',{
 compress=function(container,format,data,level)
  local raw=type(data)=='table' and data:getString() or data
  local out=format=='gzip' and Z.deflate(raw,31,level and level>=0 and level or nil) or format=='deflate' and Z.deflate(raw,-15,level and level>=0 and level or nil) or Z.deflate(raw,15,level and level>=0 and level or nil)
  return out
 end,
 decompress=function(container,format,data)
  local raw=type(data)=='table' and data:getString() or data
  return Z.inflate(raw,format=='deflate' and -15 or 47)
 end,
 newByteData=function(s)local str=type(s)=='string' and s or string.rep('\0',tonumber(s) or 0)
  return inert('ByteData',{getString=function()return str end,getSize=function()return #str end,release=function()return true end})end,
 -- little-endian subset of Lua 5.3 string.pack used by the mod (f, d, I4/i4, I2/i2, B/b, <)
 pack=function(container,fmt,...)
  local codes={}
  local i=1
  while i<=#fmt do
   local c=fmt:sub(i,i);i=i+1
   if c=='<' or c=='=' or c==' ' then
   elseif c=='f' or c=='d' or c=='B' or c=='b' then codes[#codes+1]=c
   elseif c=='I' or c=='i' then
    local n=fmt:match('^%d*',i);i=i+#n;codes[#codes+1]=c..(n~='' and n or '4')
   else error('love.data.pack stub: unsupported format '..c) end
  end
  local size={f=4,d=8,B=1,b=1,I4=4,i4=4,I2=2,i2=2,I1=1,i1=1}
  local total=0;for _,c in ipairs(codes)do total=total+assert(size[c],c) end
  local buf=ffi.new('uint8_t[?]',math.max(1,total));local off=0
  local args={...}
  for k,c in ipairs(codes)do local v=args[k] or 0
   if c=='f' then ffi.cast('float*',buf+off)[0]=v
   elseif c=='d' then ffi.cast('double*',buf+off)[0]=v
   elseif c=='I4' then ffi.cast('uint32_t*',buf+off)[0]=v
   elseif c=='i4' then ffi.cast('int32_t*',buf+off)[0]=v
   elseif c=='I2' then ffi.cast('uint16_t*',buf+off)[0]=v
   elseif c=='i2' then ffi.cast('int16_t*',buf+off)[0]=v
   else buf[off]=v%256 end
   off=off+size[c]
  end
  return ffi.string(buf,total)
 end,
 newDataView=function(data,offset,size)
  local s=data:getString():sub((offset or 0)+1,(offset or 0)+(size or 0))
  return inert('DataView',{getString=function()return s end,getSize=function()return #s end,release=function()return true end})
 end,
})
love.filesystem=lib('filesystem',{
 getIdentity=function()return 'pokemon-love2d-rseqa' end,
 getInfo=function()return nil end,read=function()return nil end,write=function()return false end,
 getSaveDirectory=function()return '/nonexistent' end,getSourceBaseDirectory=function()return '/nonexistent' end,
 isFused=function()return true end,getDirectoryItems=function()return {} end,createDirectory=function()return false end,
 newFileData=function(s,name)return inert('FileData',{getString=function()return s end,getFilename=function()return name end,getSize=function()return #(s or '')end})end,
})
love.math=lib('math',{newTransform=function()return inert('Transform')end})
love.window=lib('window',{hasFocus=function()return false end,getMode=function()return 1280,720,{}end,setMode=function()return true end,
 getDPIScale=function()return 1 end,isOpen=function()return true end,getDesktopDimensions=function()return 1920,1080 end})
love.mouse=lib('mouse',{getRelativeMode=function()return false end,setRelativeMode=function()end,getPosition=function()return 0,0 end,isDown=function()return false end})
love.keyboard=lib('keyboard',{isDown=function()return false end})
love.joystick=lib('joystick',{getJoysticks=function()return {} end})
love.system=lib('system',{getOS=function()return 'OS X' end,getProcessorCount=function()return 8 end})
love.audio=lib('audio',{newSource=function()return inert('Source')end})
love.event=lib('event',{quit=function()end,push=function()end,pump=function()end})
-- no worker threads: the engine's asset stream then decodes tilesets synchronously (Stream:get)
love.thread={}
love.getVersion=function()return 11,5,0,'Mysterious Mysteries' end
M.love=love
return M
