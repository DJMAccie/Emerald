-- DEBUG WALK
local V=...
local M={}

function M.on()
 local mod=V.mod
 local opts=mod and mod.options
 if not opts or not opts.get then return false end
 local ok,value=pcall(opts.get,opts,'tour')
 return ok and value==true
end

return M
