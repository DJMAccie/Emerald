-- List Emerald species that can learn HM02 Fly, with their national number and sprite coverage.
local E=os.getenv('HOME')..'/Library/Application Support/pokemon-love2d/emerald/data/generated/gba/pokemon/'
local W=os.getenv('HOME')..'/Library/Application Support/pokemon-love2d/mods/overworld_wild_spawns/assets/'
local function L(n)return dofile(E..n..'.lua')end
local tm,names,nat=L('tmhm'),L('names'),L('national')
local function natOf(s)return (nat.toNational and nat.toNational[s]) or (type(nat)=='table' and nat[s]) or s end
local function exists(p)local f=io.open(p,'rb');if f then f:close();return true end end
local pmd=dofile(W..'pmdcollab/sprite_table.lua')
local idx=51 -- HM02
for s=1,412 do
 local row=tm.learnsets[s]
 if row then
  local hi=tonumber(row.hi)or 0
  if math.floor(hi/2^(idx-32))%2==1 then
   local n=natOf(s)
   local nm=type(names)=='table' and (names[s] or (names.names and names.names[s])) or '?'
   print(string.format('%3d nat%3d %-12s hgss=%s pmd=%s follower=%s',s,n,tostring(nm),
    exists(W..('hgss/%d-normal-9.png'):format(n)) and 'y' or '-',
    pmd[n] and 'y' or '-',
    exists(W..('enhanced_overworld/poke_followers/follower_%03d_normal.png'):format(n)) and 'y' or '-'))
  end
 end
end
