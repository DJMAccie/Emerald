-- Species name and shininess of a battler, for the Stadium models
local V=...
local M={}
local NAMES=V.data('battle_species_dex_386')
-- Battler species as a national-dex name ("TREECKO"), or the raw value when unknown.
function M.speciesFor(battler)
 local species=battler and battler.mon and battler.mon.species
 if type(species)=='number' then
  local ok,P=pcall(require,'src.core.game3.pokemon')
  if ok and type(P)=='table' and type(P.national)=='function' then
   local okN,n=pcall(P.national,species);if okN and tonumber(n) then species=tonumber(n) end
  end
 end
 local n=type(species)=='number' and species or type(species)=='string' and tonumber(species:match('^#?0*(%d+)$'))
 if n and n%1==0 then return NAMES[n] or species end
 return species
end
function M.isShiny(battler)
 local mon=battler and (battler.mon or battler)
 if mon and (mon.personality~=nil or mon.isShiny~=nil) then
  return require('src.core.game3.summary_data').isShiny(mon)
 end
 return false
end
return M
