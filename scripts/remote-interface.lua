-- Custom Caravans: scripts/remote-interface.lua
--
-- Small remote API so other mods (and test harnesses) can drive coloring
-- without simulating GUI input.

local Colors = require("__custom-caravans__/scripts/colors")

remote.add_interface("custom-caravans", {
  -- entity: LuaEntity (one of the supported caravan/outpost prototypes)
  -- color: {r=,g=,b=[,a=]} with 0..1 components
  set_color = function(entity, color)
    Colors.set_color(entity, color)
  end,

  -- Removes the overlay entirely, restoring the entity's stock appearance.
  clear_color = function(entity)
    Colors.clear_color(entity)
  end,

  -- Returns {r,g,b,a} or nil.
  get_color = function(unit_number)
    return Colors.get_color(unit_number)
  end,

  -- Opens the entity's own window, which carries our color section. Only
  -- meaningful for outposts: pyalienlife owns the caravan window and opens it
  -- from its own entity-click handler.
  open_gui = function(player_index, entity)
    local player = game.get_player(player_index)
    if player and entity and entity.valid then
      player.opened = entity
    end
  end,
})
