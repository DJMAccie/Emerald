-- Wraps another QA driver (EM_INNER) and logs every file path the game opens.
local inner=assert(os.getenv('EM_INNER'))
local out=assert(os.getenv('SHOT_DIR'))..'/files.log'
local seen={}
local fh=io.open(out,'w')
local function rec(kind,p)
  if type(p)~='string' then
    if type(p)=='userdata' and p.getFilename then local ok,n=pcall(p.getFilename,p); p=ok and n or nil end
    if type(p)~='string' then return end
  end
  if #p>300 or p:find('\n') then return end
  local k=kind..'\t'..p
  if seen[k] then return end
  seen[k]=true; fh:write(k,'\n'); fh:flush()
end
local function wrap(tbl,name,kind)
  local f=tbl and tbl[name]; if type(f)~='function' then return end
  tbl[name]=function(a,...) rec(kind,a); return f(a,...) end
end
local fs=love.filesystem
for _,n in ipairs({'read','load','lines','newFile','newFileData'}) do wrap(fs,n,'fs.'..n) end
wrap(fs,'getInfo','info'); wrap(fs,'getDirectoryItems','dir')
for _,n in ipairs({'newImage','newArrayImage','newVolumeImage','newCubeImage','newFont','newImageFont'}) do wrap(love.graphics,n,'gfx.'..n) end
wrap(love.image,'newImageData','img.newImageData'); wrap(love.image,'newCompressedData','img.newCompressedData')
wrap(love.audio,'newSource','audio.newSource'); wrap(love.sound,'newSoundData','sound.newSoundData')
-- also io.open (engine side; mods have no io)
local ioOpen=io.open; io.open=function(p,...) rec('io.open',p); return ioOpen(p,...) end
rec('trace','start')
local f=dofile(inner)
local function dumpCache(game)
  local ex=game.mods and game.mods.exports and game.mods.exports.BATTLE_ART_VOXEL_FORK
  local V=ex and ex.lib
  if not V then rec('trace','no V'); return end
  for _,fn in ipairs({{V.require,'lib/'},{V.data,'data/'}}) do
    for i=1,20 do
      local n,v=debug.getupvalue(fn[1],i)
      if not n then break end
      if type(v)=='table' and (n=='modules' or n=='dataFiles') then
        for k in pairs(v) do rec('cache',fn[2]..k..'.lua') end
      end
    end
  end
end
return function(game) rec('trace','driver')
  local ok,err=pcall(f,game)
  if not ok then rec('trace','inner error '..tostring(err):sub(1,200)) end
  dumpCache(game); rec('trace','end')
end
