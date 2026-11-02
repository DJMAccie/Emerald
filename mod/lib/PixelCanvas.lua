
local PixelCanvas = {}

function PixelCanvas.new(w, h, options)
  local opts = {}
  for key, value in pairs(options or {}) do opts[key] = value end
  opts.dpiscale = 1
  return pcall(love.graphics.newCanvas, w, h, opts)
end

return PixelCanvas
