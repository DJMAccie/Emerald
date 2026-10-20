-- Where the headless builder finds its inputs. Every path can be overridden from the environment.
local HOME=os.getenv('HOME')
local AS=HOME..'/Library/Application Support'
local P={}
local function env(k,d)local v=os.getenv(k);if v and v~='' then return v end return d end
-- the mod's release-candidate tree (read only): <rc>/lib/*.lua, <rc>/data/*.lua
P.RC=env('EM_RC',HOME..'/Documents/Emerald/.autoloop/rc')
-- the engine payload the game actually runs (extracted from updates/gen1recomp-*.love by engine/geo.sh)
P.CACHE=env('EM_ENGINE_CACHE',HOME..'/Documents/Emerald/.autoloop/engine-cache')
P.PAYLOAD=env('EM_PAYLOAD',P.CACHE..'/payload')
-- the ROM-derived data cache of the QA identity (read only)
P.GBA=env('EM_GBA_CACHE',AS..'/pokemon-love2d-rseqa/emerald/data/generated/gba')
-- the QA identity's options (read only): the mod options the in-game dumps were made with
P.OPTIONS=env('EM_OPTIONS',AS..'/pokemon-love2d-rseqa/options.lua')
-- what the in-game loader calls the mod root: chunk names are "@<MOD_PATH>/lib/<name>.lua" (only the
-- basename reaches the dump's TAG lines, through debug.getinfo().short_src)
P.MOD_PATH=env('EM_MOD_PATH',P.RC)
return P
