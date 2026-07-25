-- Custom Caravans: scripts/gui.lua
--
-- The color picker is attached INSIDE the entity's own window rather than
-- being a free-floating frame in player.gui.screen. That placement is load
-- bearing, not cosmetic: clicking a screen frame that is not part of
-- `player.opened` makes the engine close the opened GUI, so a free-floating
-- panel took pyalienlife's whole caravan window down with it on first click.
--
--   * Caravans: pyalienlife opens a custom screen frame named "caravan_gui"
--     (scripts/caravan/gui.lua) carrying tags.unit_number. We add our section
--     as a child of that frame, so clicks land inside player.opened. Their
--     periodic update_gui only touches its own named sub-elements
--     (status_flow, tabbed_pane), so our child survives updates, and it is
--     destroyed together with their frame when the window closes.
--   * Outposts: vanilla container/storage-tank GUI, so we use the
--     engine-supported player.gui.relative anchor. Relative GUIs anchor by
--     GUI *type*, so it must be created on open and destroyed on close --
--     otherwise it would show up on every container in the game.
--
-- Only sliders are offered: non-interactive widgets (progressbar, sprite,
-- label) never raise on_gui_click, and tinting a swatch button would need a
-- generated sprite prototype per color, which is not worth it when the
-- sliders cover the whole space.

local Colors = require("__custom-caravans__/scripts/colors")

local SECTION_NAME = "custom_caravans_color_section"
local CHANNELS = {"r", "g", "b"}

local RELATIVE_GUI_TYPES = {
  ["outpost"] = defines.relative_gui_type.container_gui,
  ["outpost-aerial"] = defines.relative_gui_type.container_gui,
  ["outpost-fluid"] = defines.relative_gui_type.storage_tank_gui,
  ["outpost-aerial-fluid"] = defines.relative_gui_type.storage_tank_gui,
}

local DEFAULT_COLOR = {r = 1, g = 1, b = 1}

local Gui = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Prefer our own storage, which already holds a validated LuaEntity for
--- anything that has been colored, and fall back to the unit_number lookup for
--- entities that have never been colored yet.
local function resolve_entity(unit_number)
  if not unit_number then return nil end
  local entry = Colors.get_entry(unit_number)
  if entry and entry.entity and entry.entity.valid then return entry.entity end
  local entity = game.get_entity_by_unit_number(unit_number)
  if entity and entity.valid then return entity end
  return nil
end

--- Walks up from a clicked element to our section frame, so handlers don't
--- depend on where the section is anchored (inside caravan_gui vs relative).
local function find_section(element)
  local e = element
  while e and e.valid do
    if e.name == SECTION_NAME then return e end
    e = e.parent
  end
  return nil
end

local function to_255(component)
  return math.floor((component or 1) * 255 + 0.5)
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

local function build_preview(parent, color)
  local flow = parent.add {type = "flow", name = "ccc_preview_flow", direction = "horizontal"}
  flow.style.vertical_align = "center"
  flow.add {type = "label", caption = {"custom-caravans-gui.preview"}}

  local preview_frame = flow.add {type = "frame", name = "ccc_preview_frame", style = "deep_frame_in_shallow_frame"}
  -- A progressbar is the only widget whose style exposes a settable flat
  -- color; it is display-only here, so its lack of click events is fine.
  local preview = preview_frame.add {type = "progressbar", name = "ccc_preview", value = 1}
  preview.style.size = {56, 20}
  preview.style.bar_width = 20 -- fill the element instead of drawing a thin bar
  preview.style.color = color
end

local function build_slider_row(parent, channel, caption, unit_number, value)
  local flow = parent.add {type = "flow", name = "ccc_slider_" .. channel .. "_flow", direction = "horizontal"}
  flow.style.vertical_align = "center"

  local label = flow.add {type = "label", caption = caption}
  label.style.width = 14

  local slider = flow.add {
    type = "slider",
    name = "ccc_slider_" .. channel,
    minimum_value = 0,
    maximum_value = 255,
    value = value,
    tags = {ccc_action = "slider", unit_number = unit_number},
  }
  slider.style.horizontally_stretchable = true

  local value_label = flow.add {
    type = "label",
    name = "ccc_slider_" .. channel .. "_value",
    caption = tostring(value),
  }
  value_label.style.width = 30
end

--- Builds the color section into `parent`. `anchor` is only passed for the
--- relative-GUI (outpost) case.
function Gui.open(player, entity, parent, anchor)
  local unit_number = entity.unit_number
  if not unit_number then return end

  local existing = parent[SECTION_NAME]
  if existing and existing.valid then existing.destroy() end

  local color = Colors.get_color(unit_number) or DEFAULT_COLOR

  local frame = parent.add {
    type = "frame",
    name = SECTION_NAME,
    direction = "vertical",
    caption = {"custom-caravans-gui.title"},
    anchor = anchor,
    tags = {unit_number = unit_number},
  }

  local content = frame.add {
    type = "frame",
    name = "ccc_content",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
  }

  build_preview(content, color)

  local sliders = content.add {type = "flow", name = "ccc_sliders", direction = "vertical"}
  build_slider_row(sliders, "r", "R", unit_number, to_255(color.r))
  build_slider_row(sliders, "g", "G", unit_number, to_255(color.g))
  build_slider_row(sliders, "b", "B", unit_number, to_255(color.b))

  content.add {
    type = "button",
    name = "ccc_reset_button",
    caption = {"custom-caravans-gui.reset"},
    tooltip = {"custom-caravans-gui.reset-tooltip"},
    tags = {ccc_action = "reset", unit_number = unit_number},
  }

  log("[custom-caravans] opened picker for " .. entity.name .. " #" .. unit_number ..
    " stored_color=" .. (Colors.get_color(unit_number) and "yes" or "none"))
end

--------------------------------------------------------------------------------
-- Live updates
--------------------------------------------------------------------------------

local function refresh(section, color)
  if not (section and section.valid) then return end
  local content = section.ccc_content
  if not (content and content.valid) then return end

  local preview_flow = content.ccc_preview_flow
  if preview_flow and preview_flow.valid then
    preview_flow.ccc_preview_frame.ccc_preview.style.color = color
  end

  local sliders = content.ccc_sliders
  if not (sliders and sliders.valid) then return end
  for _, channel in ipairs(CHANNELS) do
    local flow = sliders["ccc_slider_" .. channel .. "_flow"]
    if flow and flow.valid then
      local value = to_255(color[channel])
      flow["ccc_slider_" .. channel].slider_value = value
      flow["ccc_slider_" .. channel .. "_value"].caption = tostring(value)
    end
  end
end

local function color_from_sliders(section)
  local sliders = section.ccc_content and section.ccc_content.ccc_sliders
  if not (sliders and sliders.valid) then return nil end
  local out = {a = 1}
  for _, channel in ipairs(CHANNELS) do
    local flow = sliders["ccc_slider_" .. channel .. "_flow"]
    if not (flow and flow.valid) then return nil end
    out[channel] = flow["ccc_slider_" .. channel].slider_value / 255
  end
  return out
end

--- Applies a color and reports what actually happened, so a silent failure
--- leaves evidence in factorio-current.log instead of looking like a no-op.
local function apply(entity, unit_number, color, section, what)
  Colors.set_color(entity, color)
  refresh(section, color)

  local entry = Colors.get_entry(unit_number)
  log(string.format(
    "[custom-caravans] %s %s #%s -> r=%.3f g=%.3f b=%.3f | stored=%s render=%s",
    what, entity.name, tostring(unit_number), color.r, color.g, color.b,
    entry and entry.color and "yes" or "NO",
    entry and entry.render and entry.render.valid and "valid" or "MISSING"))
end

--------------------------------------------------------------------------------
-- Event handlers
--------------------------------------------------------------------------------

script.on_event(defines.events.on_gui_opened, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  -- Outposts: anchored relative GUI beside the vanilla entity window.
  if event.gui_type == defines.gui_type.entity and event.entity and event.entity.valid then
    local relative_type = RELATIVE_GUI_TYPES[event.entity.name]
    if relative_type then
      Gui.open(player, event.entity, player.gui.relative, {
        gui = relative_type,
        position = defines.relative_gui_position.right,
      })
    end
    return
  end

  -- Caravans: injected into pyalienlife's own screen frame.
  if event.gui_type == defines.gui_type.custom and event.element and event.element.valid
      and event.element.name == "caravan_gui" then
    local unit_number = event.element.tags and event.element.tags.unit_number
    local entity = resolve_entity(unit_number)
    if entity and Colors.CARAVANS[entity.name] then
      Gui.open(player, entity, event.element, nil)
    else
      log("[custom-caravans] caravan_gui opened but entity unresolved: unit_number=" ..
        tostring(unit_number) .. " entity=" .. tostring(entity and entity.name))
    end
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  -- Only the relative (outpost) section needs explicit teardown; the caravan
  -- section is a child of pyalienlife's frame and dies with it.
  local existing = player.gui.relative[SECTION_NAME]
  if existing and existing.valid then existing.destroy() end
end)

--- Our elements are identified by tag, with the element name as a fallback:
--- tags are the intended mechanism, but recognising our own names as well
--- means a lost/empty tags table can't silently disable the whole picker.
local function is_ours(element, action, name_pattern)
  local tags = element.tags
  if tags and tags.ccc_action == action then return true end
  return element.name:match(name_pattern) ~= nil
end

--- unit_number lives on every interactive element, but the section frame
--- carries it too, so a child with no tags can still be traced back.
local function unit_number_for(element, section)
  local tags = element.tags
  if tags and tags.unit_number then return tags.unit_number end
  if section and section.valid and section.tags then return section.tags.unit_number end
  return nil
end

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then return end
  if not is_ours(element, "reset", "^ccc_reset_button$") then return end

  local section = find_section(element)
  local unit_number = unit_number_for(element, section)
  local entity = resolve_entity(unit_number)
  if not entity then
    log("[custom-caravans] reset clicked but entity unresolved: unit_number=" .. tostring(unit_number))
    return
  end

  Colors.reset_color(entity)
  local color = Colors.get_color(unit_number) or DEFAULT_COLOR
  refresh(section, color)
  log("[custom-caravans] reset " .. entity.name .. " #" .. tostring(unit_number))
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
  local element = event.element
  if not (element and element.valid) then return end
  if not is_ours(element, "slider", "^ccc_slider_[rgb]$") then return end

  local section = find_section(element)
  if not section then
    log("[custom-caravans] slider moved but section not found from element " .. element.name)
    return
  end

  local unit_number = unit_number_for(element, section)
  local entity = resolve_entity(unit_number)
  if not entity then
    log("[custom-caravans] slider moved but entity unresolved: unit_number=" .. tostring(unit_number))
    return
  end

  local color = color_from_sliders(section)
  if not color then
    log("[custom-caravans] slider moved but slider values unreadable")
    return
  end

  apply(entity, unit_number, color, section, "slider")
end)

return Gui
