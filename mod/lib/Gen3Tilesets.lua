-- The importer adds generated pairs to Versions only while importing a ROM
local M={}
function M.resolve(pair,known)
 local spec=known and known[pair]
 if spec then return spec end
 if type(pair)=='string' then
  local primary,secondary=pair:match('^([%w_]+)__(.+)$')
  if primary and secondary then return {primary=primary,secondary=secondary} end
 end
 return {}
end
local emeraldCaves={cave=true,meteor_falls=true,rusturf_tunnel=true,mirage_tower=true,navel_rock=true,underwater=true}
function M.cave(spec)return spec and spec.primary=='general' and emeraldCaves[spec.secondary] or false end
function M.outdoor(def)
 local kind=tonumber(def and def.mapType)
 if kind and kind>0 then return kind==1 or kind==2 or kind==3 or kind==6 end
 return def and (def.environment=='TOWN' or def.environment=='ROUTE') or false
end
function M.supports(def,spec)
 if not (def and def.midLayout) then return false end
 if M.cave(spec) or spec.primary=='building' then return true end
 if spec.primary=='general' then return true end
 if spec.primary=='secret_base' then return true end
 return false
end
return M
