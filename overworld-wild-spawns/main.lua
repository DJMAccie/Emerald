-- Wilds (id: overworld_wild_spawns): visible wild Pokemon, follower and overworld catching for Emerald (lib/gen3/).
return function(mod)
  mod.exports.version = "0.1.0"
  return assert((loadstring or load)(assert(mod:read("lib/gen3/init.lua")),"@wilds/gen3/init"))()(mod)
end
