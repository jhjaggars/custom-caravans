-- Custom Caravans: control.lua
--
-- Wires up storage initialization and requires the event-registering
-- submodules. All actual event handling lives in scripts/*.lua; each of
-- those files registers its own script.on_event/on_nth_tick handlers when
-- required, so requiring them here (in a fixed order, every load) is enough.

local Colors = require("__custom-caravans__/scripts/colors")
require("__custom-caravans__/scripts/tracker")
require("__custom-caravans__/scripts/gui")
require("__custom-caravans__/scripts/copy-paste")
require("__custom-caravans__/scripts/remote-interface")

-- The sweep matters beyond first install: the data stage strips the baked
-- mask layer from caravan/fluidavan (+turds), so any of them existing without
-- our overlay would have no flags at all.
local function init()
  storage.colors = storage.colors or {}
  Colors.apply_defaults_everywhere()
end

script.on_init(init)
script.on_configuration_changed(init)
