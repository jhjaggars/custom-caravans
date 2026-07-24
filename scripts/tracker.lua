-- Custom Caravans: scripts/tracker.lua
--
-- Every 10 ticks, re-snaps each colored caravan's overlay to match its
-- current facing direction (16-way) and toggles the overlay's animation
-- speed off while the caravan is stationary, so a parked caravan's overlay
-- doesn't keep crawling through its walk cycle.
--
-- Known limitation (see plan): the overlay's walk-cycle frame is not phase
-- locked to the real unit's own animation frame (the engine doesn't expose
-- that), so on a moving caravan the overlay may drift slightly out of sync
-- with the body sprite. The mask/wash mostly covers the cargo/tent area, so
-- this is expected to be tolerable - verify visually in-game.

local Colors = require("__custom-caravans__/scripts/colors")

local NTH_TICK = 10
local MOVE_EPSILON_SQUARED = 0.0001 -- ~0.01 tile of movement between checks

script.on_nth_tick(NTH_TICK, function(_)
  local store = storage.colors
  if not store then return end

  for unit_number, entry in pairs(store) do
    local entity = entry.entity
    if entity and entity.valid and Colors.CARAVANS[entry.entity_name] then
      local render = entry.render

      -- Direction sync.
      local dir_index = Colors.direction_to_index(entity.orientation)
      if dir_index ~= entry.dir then
        entry.dir = dir_index
        if render and render.valid then
          local anim_name = Colors.overlay_animation_name(entry.entity_name, dir_index)
          if anim_name then
            render.animation = anim_name
          end
        end
      end

      -- Idle/moving detection via position delta (works uniformly across
      -- unit/character/vehicle-like entities without depending on a
      -- particular `speed` field being present on every entity type).
      local position = entity.position
      local last_position = entry.last_position
      local moving = false
      if last_position then
        local dx = position.x - last_position.x
        local dy = position.y - last_position.y
        moving = (dx * dx + dy * dy) > MOVE_EPSILON_SQUARED
      end
      entry.last_position = {x = position.x, y = position.y}

      if render and render.valid then
        render.animation_speed = moving and 1 or 0
      end
    else
      -- Entity gone but somehow not cleaned up yet (should be rare given
      -- on_object_destroyed handling in colors.lua) - clean up defensively.
      if not (entity and entity.valid) then
        Colors.clear_color(unit_number)
      end
    end
  end
end)
