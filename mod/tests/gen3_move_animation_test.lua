-- The Gen 3 move animation handoff.
--
-- The bug this pins: StadiumModels plays a model's move clip on the rising
-- edge of `battle.animPlaying`, which is how the Gen 1/2 battle states
-- announce a move animation. The Gen 3 battle has no such field -- it
-- launches effects through `Anim.launchMove` -- so the edge never rose and
-- every move in every Emerald fight played the generic `attack` context. The
-- animations were imported and wired, and nothing ever asked for them.
--
-- Also pinned: the move NUMBER. StadiumModels reads
-- `battle.data.moves[battle.animName].index`, and the Gen 3 adapter left
-- `data.moves` empty, so even a correctly-fired trigger would have found no
-- move to play.
--
-- Exercised through the real adapter with a stubbed importer and a stubbed
-- StadiumModels, so this is about the handoff rather than about the data
-- behind it.

local cache = {}

-- The provider, stubbed at the few methods the adapter calls.
local Stadium = {
  -- Deliberately left raised: the handoff must lower it, or a second move in
  -- the very next frame would be swallowed.
  animWasPlaying = true,
  calls = {},
  active = function() return true end,
  installed = function() return true end,
  release = function() end,
  placements = function() return {} end,
  status = function() return { active = true, sides = {} } end,
}
function Stadium.update(battle, dt)
  local playing = battle and battle.animPlaying and true or false
  if playing and not Stadium.animWasPlaying then
    local row = battle.data and battle.data.moves[battle.animName]
    Stadium.calls[#Stadium.calls + 1] = {
      name = battle.animName,
      index = row and row.index,
      attackerIsPlayer = battle.animAttackerIsPlayer,
    }
  end
  Stadium.animWasPlaying = playing
  return true
end

-- One Kanto move and one Hoenn-era move, so the direct and the proxied paths
-- are both covered.
local MOVES = { TACKLE = 33, ABSORB = 71, THUNDERBOLT = 85 }

-- Engine modules are stubbed rather than booted: this test says nothing about
-- the engine's own move table.
package.loaded["src.core.game3.battle"] = {
  _st = { player = {}, enemy = {} },
  isActive = function() return true end,
}
package.loaded["src.core.game3.battle.state"] = {
  battler = function(_, id)
    return { species = 25, mon = { species = 25 }, id = id, fainted = false }
  end,
}
package.loaded["src.core.game3.pokemon"] = {
  national = function(species) return species end,
}
package.loaded["src.core.game3.battle.moves"] = {
  numForName = function(name) return MOVES[name] end,
}
package.loaded["src.core.game3.battle.anim"] = {
  present = function() return { visible = true, scale = 1 } end,
  launchMove = function() return true end,
  faintMon = function() return true end,
}

local V = { mod = { options = { get = function() return nil end } } }
function V.require(name)
  if cache[name] then return cache[name] end
  local value
  if name == "StadiumModels" then
    value = Stadium
  elseif name == "BattleArt" then
    value = {
      speciesFor = function() return "PIKACHU" end,
      isShiny = function() return false end,
    }
  elseif name == "FlyMotion" then
    value = { update = function() end, pose = function() return nil end }
  elseif name == "Mat4" then
    value = {
      translate = function() return {} end, rotateY = function() return {} end,
      scale = function() return {} end, mul = function() return {} end,
    }
  elseif name == "Voxel3D" then
    value = { vp = {}, eye = { 0, 0, 0 }, focus = { 0, 0, 1 }, tint = { 1, 1, 1 } }
  else
    -- pcall: the adapter reaches for modules this test does not stub, and a
    -- load that fails there must not take the fixture with it. The move-row
    -- tests below need the real module, not an empty stand-in.
    local ok, loaded = pcall(function()
      return assert(loadfile("lib/" .. name .. ".lua"))(V)
    end)
    value = (ok and type(loaded) == "table") and loaded or {}
  end
  cache[name] = value
  return value
end

local Gen3 = V.require("Gen3StadiumModels")

-- Both sides owned, so the trigger's ownership gate passes.
Gen3.owned = { player = true, enemy = true }

local function freshBattle()
  return {
    data = { moves = {}, pokemon = {} },
    player = { species = 25, mon = { species = 25 } },
    enemy = { species = 25, mon = { species = 25 } },
    animPlaying = nil,
    animName = nil,
    animAttackerIsPlayer = nil,
  }
end

local function ok(value, message)
  if not value then error(message or "assertion failed", 2) end
end

-- ------- the handoff itself

Stadium.calls = {}
local battle = freshBattle()
Gen3.pendingMove = { move = 85, player = true }        -- Thunderbolt
ok(Gen3.performPendingMove(battle), "a pending move is performed")
ok(#Stadium.calls == 1, "exactly one move animation per launch")
ok(Stadium.calls[1].index == 85, "the move number reaches StadiumModels")
ok(Stadium.calls[1].attackerIsPlayer == true, "the attacker's side is carried")
ok(Gen3.pendingMove == nil, "the latch is cleared, so it cannot fire twice")
ok(battle.animPlaying == nil, "the battle's own fields are left as they were")
ok(battle.animName == nil, "including animName")

-- Two moves in consecutive frames must both play: the provider only fires on
-- a rising edge, so the handoff has to lower it every time.
Stadium.calls = {}
for _ = 1, 2 do
  Gen3.pendingMove = { move = 33, player = false }
  Gen3.performPendingMove(battle)
end
ok(#Stadium.calls == 2, "two launches in a row both play")
ok(Stadium.calls[2].attackerIsPlayer == false, "the enemy side is carried too")

-- Nothing pending is not an error, and plays nothing.
Stadium.calls = {}
Gen3.pendingMove = nil
ok(Gen3.performPendingMove(battle) == false, "no pending move performs nothing")
ok(#Stadium.calls == 0, "and plays nothing")

-- ------- the move NUMBER the provider reads

local adapter = Gen3.battle()
ok(type(adapter) == "table", "the adapter publishes a battle-like view")
ok(type(adapter.data) == "table" and type(adapter.data.moves) == "table",
   "data.moves exists, so the provider's lookup has something to find")

local row = adapter.data.moves["TACKLE"]
ok(type(row) == "table", "an engine animation name resolves to a move row")
ok(row.index == MOVES.TACKLE, "and the row carries the move number")

local absorb = adapter.data.moves["ABSORB"]
ok(type(absorb) == "table" and absorb.index == MOVES.ABSORB,
   "a Hoenn-era move resolves too")

ok(adapter.data.moves["NOT_A_MOVE"] == nil,
   "an unknown name resolves to nil rather than to a wrong move")
ok(adapter.data.moves["NOT_A_MOVE"] == nil,
   "and the miss is not cached as a hit")

-- ------- the proxy for moves past Stadium 2's #251

ok(Gen3.moveSelector(MOVES.TACKLE) == MOVES.TACKLE,
   "a move inside Stadium's table is passed through")
local proxied = Gen3.moveSelector(400)
ok(type(proxied) == "number" and proxied >= 1 and proxied <= 251,
   "a move past #251 proxies into the Stadium range")

print("PASS gen3 move animation: the engine's launch reaches the model, "
  .. "move numbers resolve, and unknown names stay unknown")
