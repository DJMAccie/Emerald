-- zlib through LuaJIT's FFI (macOS ships libz): inflate/deflate for the game's cache blobs
-- (CacheBlob: zlib streams) and gzip for the dump files. Headless tooling only.
local ffi=require('ffi')
pcall(ffi.cdef,[[
typedef struct z_stream_s {
  const uint8_t *next_in; unsigned int avail_in; unsigned long total_in;
  uint8_t *next_out; unsigned int avail_out; unsigned long total_out;
  const char *msg; void *state; void *zalloc; void *zfree; void *opaque;
  int data_type; unsigned long adler; unsigned long reserved;
} z_stream;
const char *zlibVersion(void);
int deflateInit2_(z_stream *strm, int level, int method, int windowBits, int memLevel, int strategy, const char *version, int stream_size);
int deflate(z_stream *strm, int flush);
int deflateEnd(z_stream *strm);
int inflateInit2_(z_stream *strm, int windowBits, const char *version, int stream_size);
int inflate(z_stream *strm, int flush);
int inflateEnd(z_stream *strm);
]])
local Z=ffi.load('z')
local M={}
local CHUNK=1048576
-- windowBits: 15 zlib, 31 gzip, -15 raw deflate, 47 auto (zlib or gzip) for inflate
local function run(init,step,finish,data,flushEnd)
 local s=ffi.new('z_stream')
 assert(init(s)==0,'zlib init failed')
 s.next_in=ffi.cast('const uint8_t*',data);s.avail_in=#data
 local out,parts=ffi.new('uint8_t[?]',CHUNK),{}
 while true do
  s.next_out=out;s.avail_out=CHUNK
  local rc=step(s,flushEnd)
  parts[#parts+1]=ffi.string(out,CHUNK-s.avail_out)
  if rc==1 then break end -- Z_STREAM_END
  if rc~=0 and rc~=-5 then finish(s);error('zlib error '..rc..' '..(s.msg~=nil and ffi.string(s.msg) or '')) end
  if rc==-5 and s.avail_in==0 and s.avail_out~=0 then break end
 end
 finish(s)
 return table.concat(parts)
end
function M.inflate(data,windowBits)
 return run(function(s)return Z.inflateInit2_(s,windowBits or 47,Z.zlibVersion(),ffi.sizeof('z_stream'))end,
  function(s)return Z.inflate(s,0)end,function(s)Z.inflateEnd(s)end,data,0)
end
function M.deflate(data,windowBits,level)
 return run(function(s)return Z.deflateInit2_(s,level or 6,8,windowBits or 15,8,0,Z.zlibVersion(),ffi.sizeof('z_stream'))end,
  function(s)return Z.deflate(s,4)end,function(s)Z.deflateEnd(s)end,data,4) -- Z_FINISH
end
function M.gzip(data,level)return M.deflate(data,31,level)end
return M
