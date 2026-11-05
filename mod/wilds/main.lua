-- Wild Pokemon in the overworld, a follower and overworld catching (code in wilds/lib/gen3/).
return function(mod)
  mod.exports.version = "0.1.0"
  return assert((loadstring or load)(assert(mod:read("wilds/lib/gen3/init.lua")),"@wilds/gen3/init"))()(mod)
end
