-- luajit tools/lua_deepcmp.lua A.lua B.lua : load two Lua files that `return` a table and compare them deeply.
-- Prints IDENTICAL, or DIFFERENT with the path of the first difference (and a count of differing top-level keys).
local function load_(p) return assert(loadfile(p))() end
local function eq(a, b, path, out)
  if type(a) ~= type(b) then out[#out+1] = path; return false end
  if type(a) ~= 'table' then if a ~= b then out[#out+1] = path; return false end return true end
  local ok = true
  for k, v in pairs(a) do if not eq(v, b[k], path .. '.' .. tostring(k), out) then ok = false end end
  for k in pairs(b) do if a[k] == nil then out[#out+1] = path .. '.' .. tostring(k); ok = false end end
  return ok
end
local out = {}
local ok = eq(load_(arg[1]), load_(arg[2]), '', out)
if ok then print('IDENTICAL') os.exit(0) end
local top = {}
for _, p in ipairs(out) do top[p:match('^%.[^.]*') or p] = true end
local n = 0; for _ in pairs(top) do n = n + 1 end
table.sort(out)
print('DIFFERENT: ' .. #out .. ' differing leaves under ' .. n .. ' top-level keys; first: ' .. out[1])
local list = {}; for k in pairs(top) do list[#list+1] = k end; table.sort(list)
print('top-level keys: ' .. table.concat(list, ' '):sub(1, 600))
os.exit(1)
