-- Custom Caravans: control.lua
--
-- Wires up storage initialization and requires the event-registering
-- submodules. All actual event handling lives in scripts/*.lua; each of
-- those files registers its own script.on_event handlers when required, so
-- requiring them here (in a fixed order, every load) is enough.

local Colors = require("__custom-caravans__/scripts/colors")
require("__custom-caravans__/scripts/gui")
require("__custom-caravans__/scripts/copy-paste")
require("__custom-caravans__/scripts/remote-interface")

script.on_init(function()
  storage.colors = storage.colors or {}
  storage.picker = storage.picker or {}
end)

script.on_configuration_changed(function()
  storage.colors = storage.colors or {}
  storage.picker = storage.picker or {}

  -- Rebuild every overlay so a changed overlay form takes effect on existing
  -- saves. Caravan entries are dropped rather than converted: an earlier
  -- version applied each caravan's stock livery tint automatically, and
  -- turning those into ring markers would litter the map with markers the
  -- player never asked for. Deliberately colored caravans need re-coloring
  -- once; outposts keep their color.
  for unit_number, entry in pairs(storage.colors) do
    if entry.render and entry.render.valid then
      entry.render.destroy()
    end
    entry.render = nil

    local entity = entry.entity
    if entity and entity.valid and entry.color and Colors.OUTPOSTS[entity.name] then
      Colors.set_color(entity, entry.color)
    else
      storage.colors[unit_number] = nil
    end
  end
end)
