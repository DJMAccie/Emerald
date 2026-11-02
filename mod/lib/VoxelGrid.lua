-- Voxel world mode

local V = ...

local ModSetting = V.require("ModSetting")

local VoxelGrid = {}

VoxelGrid.KEY = "grid"
VoxelGrid.LABEL = "V-GRID"

VoxelGrid.DARK = 0.45

VoxelGrid.WIDTH = 1.0

function VoxelGrid.width()
  return VoxelGrid.WIDTH * V.require("AntiAlias").factor()
end

VoxelGrid.setting = ModSetting.new(VoxelGrid.KEY, VoxelGrid.LABEL,
                                   { false, true }, { "OFF", "ON" })

function VoxelGrid.enabled()
  return VoxelGrid.setting:get() and true or false
end

return VoxelGrid
