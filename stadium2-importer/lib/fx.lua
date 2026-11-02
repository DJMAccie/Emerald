local Fx = {}
local modRef

function Fx.bind(mod)
  modRef=mod
  return Fx
end

local floor = math.floor
local byte = string.byte
local sub = string.sub

local function u32be(data, offset)
  local a, b, c, d = byte(data, offset + 1, offset + 4)
  if not d then return nil end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function bxor(a, b)
  local result, place = 0, 1
  a = a % 0x100000000
  b = b % 0x100000000
  for _ = 1, 32 do
    local aa = a % 2
    local bb = b % 2
    if aa ~= bb then result = result + place end
    a = floor(a / 2)
    b = floor(b / 2)
    place = place * 2
  end
  return result
end

local function crc32(data)
  local crc = 0xFFFFFFFF
  for i = 1, #data do
    crc = bxor(crc, byte(data, i))
    for _ = 1, 8 do
      if crc % 2 == 1 then
        crc = bxor(floor(crc / 2), 0xEDB88320)
      else
        crc = floor(crc / 2)
      end
    end
  end
  return bxor(crc, 0xFFFFFFFF) % 0x100000000
end

local function hexBytes(data, limit)
  local out = {}
  local n = math.min(#data, limit or #data)
  for i = 1, n do out[#out + 1] = ("%02X"):format(byte(data, i)) end
  return table.concat(out)
end

local function wordList(data, limit)
  local out = {}
  local count = math.min(floor(#data / 4), limit or floor(#data / 4))
  for i = 0, count - 1 do
    local word = u32be(data, i * 4)
    if word == nil then break end
    out[#out + 1] = ("%08X"):format(word)
  end
  return table.concat(out, " ")
end

function Fx.classify(callback, sourceBase, fragmentSize)
  callback = tonumber(callback)
  sourceBase = tonumber(sourceBase)
  fragmentSize = tonumber(fragmentSize)
  if callback == nil then return "invalid", nil end
  if callback == 0 then return "null", nil end
  if sourceBase and fragmentSize then
    local offset = callback - sourceBase
    if offset >= 0 and offset < fragmentSize then return "fragment", offset end
  end
  if callback >= 0x80000000 and callback <= 0xBFFFFFFF then return "runtime", nil end
  return "other", nil
end

function Fx.probe(data, callback, sourceBase, maxBytes)
  if type(data) ~= "string" then return nil, "fragment data is required" end
  local origin, offset = Fx.classify(callback, sourceBase, #data)
  local result = {
    origin = origin,
    callback = callback,
    offset = offset,
  }
  if origin ~= "fragment" then return result end
  if offset % 4 ~= 0 then
    result.reason = "unaligned"
    result.length = 0
    return result
  end
  local cap = math.max(4, tonumber(maxBytes) or 0x100)
  local finish = math.min(#data, offset + cap)
  local cursor = offset
  local reason = "cap"
  while cursor + 4 <= finish do
    local word = u32be(data, cursor)
    cursor = cursor + 4
    if word == 0x03E00008 then
      if cursor + 4 <= finish then cursor = cursor + 4 end
      reason = "jr_ra"
      break
    end
  end
  if cursor <= offset then cursor = math.min(#data, offset + 4) end
  local code = sub(data, offset + 1, cursor)
  result.reason = reason
  result.length = #code
  result.code = code
  result.crc32 = crc32(code)
  result.fingerprint = ("%08X:%X"):format(result.crc32, #code)
  result.head = hexBytes(code, 32)
  result.words = wordList(code, 32)
  return result
end

function Fx.parseSymbolMap(text)
  if type(text) ~= "string" then return nil, "symbol map text is required" end
  local symbols, byAddress = {}, {}
  for line in text:gmatch("[^\r\n]+") do
    local name, address = line:match("^%s*([%w_.$]+)%s*=%s*0x([0-9A-Fa-f]+)%s*;")
    if name and address then
      local value = tonumber(address, 16)
      if value then
        local row = { name = name, address = value }
        symbols[#symbols + 1] = row
        if byAddress[value] == nil then byAddress[value] = row end
      end
    end
  end
  table.sort(symbols, function(a, b)
    if a.address == b.address then return a.name < b.name end
    return a.address < b.address
  end)
  return { symbols = symbols, byAddress = byAddress }
end

function Fx.loadSymbolMap(path)
  if type(path) ~= "string" or path == "" then return nil, "symbol map path is required" end
  if not (modRef and type(modRef.read)=="function") then
    return nil,"mod-owned symbol map reader is unavailable"
  end
  local ok,text=pcall(modRef.read,modRef,path)
  if not ok or type(text)~="string" then
    return nil,ok and "could not read symbol map" or tostring(text)
  end
  local parsed, parseErr = Fx.parseSymbolMap(text)
  if not parsed then return nil, parseErr end
  parsed.path = path
  return parsed
end

function Fx.resolveSymbol(map, address)
  if type(map) ~= "table" or type(map.symbols) ~= "table" then return nil end
  address = tonumber(address)
  if address == nil then return nil end
  local exact = map.byAddress and map.byAddress[address]
  if exact then return { name = exact.name, address = exact.address, delta = 0, exact = true } end
  local symbols = map.symbols
  local lo, hi = 1, #symbols
  local best = nil
  while lo <= hi do
    local mid = floor((lo + hi) / 2)
    local row = symbols[mid]
    if row.address <= address then
      best = row
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  if not best then return nil end
  return {
    name = best.name,
    address = best.address,
    delta = address - best.address,
    exact = false,
  }
end

function Fx.identity(probe, callback)
  if probe and probe.origin == "fragment" then
    return "fragment:" .. tostring(probe.fingerprint or "unknown")
  end
  return tostring(probe and probe.origin or "unknown") .. ":" .. ("%08X"):format((tonumber(callback) or 0) % 0x100000000)
end

Fx.u32be = u32be
Fx.crc32 = crc32
Fx.hexBytes = hexBytes
Fx.wordList = wordList

return Fx
