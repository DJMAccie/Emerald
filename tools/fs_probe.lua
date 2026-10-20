-- Filesystem probe: what can the sandboxed game process actually touch?
-- EMERALD_ROOT overrides the default (~/Documents/Emerald).
return function(game)
 local ROOT = os.getenv('EMERALD_ROOT') or ((os.getenv('HOME') or '') .. '/Documents/Emerald')
 local function try(label,fn)
  local ok,res=pcall(fn)
  print(('[FS] %-34s ok=%s %s'):format(label,tostring(ok),tostring(res)))
 end
 print('[FS] save dir',love.filesystem.getSaveDirectory())
 print('[FS] source dir',love.filesystem.getSource())
 try('io.open workspace READ',function()
  local f=io.open(ROOT .. '/docs/SPRITE-TO-VOXEL-PLAN.md','r')
  if not f then return 'NIL' end
  local line=f:read('*l');f:close();return #(line or ''),line
 end)
 try('io.open /tmp WRITE',function()
  local f=io.open('/tmp/dsh_fs_probe.txt','w');if not f then return 'NIL' end
  f:write('hello\n');f:close();return 'wrote'
 end)
 try('io.open workspace WRITE',function()
  local f=io.open(ROOT .. '/logs/fs_probe_from_game.txt','w')
  if not f then return 'NIL' end
  f:write('hello from love\n');f:close();return 'wrote'
 end)
 try('io.open QA identity WRITE',function()
  local f=io.open(love.filesystem.getSaveDirectory()..'/fs_probe.txt','w')
  if not f then return 'NIL' end
  f:write('hello\n');f:close();return 'wrote'
 end)
 try('love.filesystem.read abs path',function()
  return love.filesystem.read(ROOT .. '/docs/SPRITE-TO-VOXEL-PLAN.md')
 end)
 try('love.filesystem.getInfo workspace',function()
  local i=love.filesystem.getInfo(ROOT .. '/docs')
  return i and i.type or 'nil'
 end)
 print('[FS] done')
 love.event.quit()
end
