-- Custom Caravans: scripts/copy-paste.lua
--
-- Settings copy/paste (shift-right-click / shift-left-click) between any two
-- of the 9 target prototypes - enabled by the additional_pastable_entities
-- patch in data-updates.lua, which makes the game fire
-- on_entity_settings_pasted for otherwise-incompatible pairs (e.g. a caravan
-- pasted onto an outpost).
--
-- Also restores outpost colors through blueprinting (tags) and through
-- entity cloning (on_entity_cloned).
--
-- Caravans are not blueprintable (they're placed via item-with-tags / mining,
-- not ghosts), so blueprint tag persistence only applies to the 4 outposts.

local Colors = require("__custom-caravans__/scripts/colors")

local BLUEPRINT_TAG_KEY = "custom_caravans_color"

--------------------------------------------------------------------------------
-- Settings paste (works for caravan<->caravan, outpost<->outpost, and
-- caravan<->outpost thanks to the data-stage additional_pastable_entities patch)
--------------------------------------------------------------------------------

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local source, destination = event.source, event.destination
  if not (source and source.valid and destination and destination.valid) then return end
  if not (Colors.ALL[source.name] and Colors.ALL[destination.name]) then return end

  local source_color = Colors.get_color(source.unit_number)
  if source_color then
    Colors.set_color(destination, source_color)
  else
    Colors.reset_color(destination)
  end
end)

--------------------------------------------------------------------------------
-- Blueprint tag write: called when the player opens a blueprint for editing
-- (covers blueprints made from selection, and editing existing blueprints).
--------------------------------------------------------------------------------

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local stack = event.stack
  if not (stack and stack.valid_for_read) then
    stack = player.blueprint_to_setup
  end
  if not (stack and stack.valid_for_read and stack.is_blueprint) then return end

  local mapping = event.mapping and event.mapping.get()
  if not mapping then return end

  for bp_index, entity in pairs(mapping) do
    if entity and entity.valid and Colors.OUTPOSTS[entity.name] then
      local color = Colors.get_color(entity.unit_number)
      if color then
        stack.set_blueprint_entity_tag(bp_index, BLUEPRINT_TAG_KEY, color)
      end
    end
  end
end)

--------------------------------------------------------------------------------
-- Blueprint tag read: reapply color when an outpost is built from a blueprint
-- (by a player, a construction robot, or a space platform).
--------------------------------------------------------------------------------

local function all_name_filters()
  local filters = {}
  for i, name in ipairs(Colors.ALL_LIST) do
    filters[i] = {filter = "name", name = name}
    if i > 1 then filters[i].mode = "or" end
  end
  return filters
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  if Colors.OUTPOSTS[entity.name] then
    local tags = event.tags
    local color = tags and tags[BLUEPRINT_TAG_KEY]
    if color then
      Colors.set_color(entity, color)
    end
  elseif Colors.CARAVANS[entity.name] then
    -- Masked caravans must always carry an overlay (their baked mask layer is
    -- stripped at data stage); freshly placed ones get their default tint.
    Colors.ensure_default(entity)
  end
end

script.on_event(defines.events.on_built_entity, on_built, all_name_filters())
script.on_event(defines.events.on_robot_built_entity, on_built, all_name_filters())
script.on_event(defines.events.script_raised_built, on_built, all_name_filters())
script.on_event(defines.events.script_raised_revive, on_built, all_name_filters())

if defines.events.on_space_platform_built_entity then
  script.on_event(defines.events.on_space_platform_built_entity, on_built, all_name_filters())
end

--------------------------------------------------------------------------------
-- Entity cloning (editor "clone area", script-driven cloning, etc.)
--------------------------------------------------------------------------------

script.on_event(defines.events.on_entity_cloned, function(event)
  local source, destination = event.source, event.destination
  if not (source and source.valid and destination and destination.valid) then return end
  if not Colors.ALL[source.name] then return end

  local color = Colors.get_color(source.unit_number)
  if color then
    Colors.set_color(destination, color)
  else
    Colors.ensure_default(destination)
  end
end, all_name_filters())
