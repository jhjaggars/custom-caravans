-- Custom Caravans: scripts/gui.lua
--
-- A small standalone color-picker panel that opens alongside the entity's own
-- GUI: the vanilla container/storage-tank GUI for outposts, and pyalienlife's
-- custom "caravan_gui" screen frame for caravans.
--
-- NOTE on caravan resolution: pyalienlife's caravan_gui frame carries
-- `tags = {unit_number = ...}` (see scripts/caravan/gui/main_frame.lua:27 in
-- the pyalienlife source), so on_gui_opened can read the caravan's
-- unit_number directly off event.element.tags. player.selected is only used
-- as a defensive fallback in case that ever changes upstream.
--
-- Preset colors are the vanilla `player_colors` palette (same colors used for
-- character/chat color), read directly out of this Factorio installation's
-- core/prototypes/utility-constants.lua (data.raw["utility-constants"].default
-- .player_colors) - the "default" entry is a duplicate of "orange" so it's
-- omitted here.

local Colors = require("__custom-caravans__/scripts/colors")

local PANEL_NAME = "custom_caravans_color_gui"

local PRESETS = {
  {name = "red", color = {r = 0.815, g = 0.024, b = 0.0}},
  {name = "green", color = {r = 0.093, g = 0.768, b = 0.172}},
  {name = "blue", color = {r = 0.155, g = 0.540, b = 0.898}},
  {name = "orange", color = {r = 0.869, g = 0.5, b = 0.130}},
  {name = "yellow", color = {r = 0.835, g = 0.666, b = 0.077}},
  {name = "pink", color = {r = 0.929, g = 0.386, b = 0.514}},
  {name = "purple", color = {r = 0.485, g = 0.111, b = 0.659}},
  {name = "white", color = {r = 0.8, g = 0.8, b = 0.8}},
  {name = "black", color = {r = 0.1, g = 0.1, b = 0.1}},
  {name = "gray", color = {r = 0.4, g = 0.4, b = 0.4}},
  {name = "brown", color = {r = 0.300, g = 0.117, b = 0.0}},
  {name = "cyan", color = {r = 0.275, g = 0.755, b = 0.712}},
  {name = "acid", color = {r = 0.559, g = 0.761, b = 0.157}},
}

local DEFAULT_COLOR = {r = 1, g = 1, b = 1}

local Gui = {}

--------------------------------------------------------------------------------
-- Entity resolution helpers
--------------------------------------------------------------------------------

local function resolve_entity_by_unit_number(unit_number, player)
  if not unit_number then return nil end

  if game.get_entity_by_unit_number then
    local ok, entity = pcall(game.get_entity_by_unit_number, unit_number)
    if ok and entity and entity.valid then
      return entity
    end
  end

  -- Fallback guard: only trust player.selected if it actually is the entity
  -- we're looking for.
  if player and player.selected and player.selected.valid and player.selected.unit_number == unit_number then
    return player.selected
  end

  return nil
end

--------------------------------------------------------------------------------
-- Panel construction
--------------------------------------------------------------------------------

local function build_titlebar(parent)
  local flow = parent.add {type = "flow", name = "ccc_titlebar", direction = "horizontal", style = "frame_header_flow"}
  flow.drag_target = parent
  flow.add {type = "label", style = "frame_title", caption = {"custom-caravans-gui.title"}}
  local drag_handle = flow.add {type = "empty-widget", style = "draggable_space_header"}
  drag_handle.style.horizontally_stretchable = true
  drag_handle.style.height = 24
  drag_handle.drag_target = parent
  flow.add {
    type = "sprite-button",
    name = "ccc_close_button",
    style = "close_button",
    sprite = "utility/close",
    tooltip = {"custom-caravans-gui.close"},
    tags = {ccc_action = "close"},
  }
end

-- Color swatches (both the live preview and the preset buttons) are built
-- from `progressbar` elements at `value = 1` (a full bar), which is the only
-- LuaGuiElement type whose style exposes a settable flat `color` (LuaGuiElement
-- itself has no `tint`/`color` attribute of its own - only LuaProgressBarStyle
-- does). Progressbars still receive on_gui_click like any other element, so
-- they work fine as (plain-looking) clickable preset buttons too.
local function build_preview(parent, color)
  local preview_frame = parent.add {type = "frame", name = "ccc_preview_frame", style = "deep_frame_in_shallow_frame"}
  local preview = preview_frame.add {
    type = "progressbar",
    name = "ccc_preview",
    value = 1,
    tooltip = {"custom-caravans-gui.preview"},
  }
  preview.style.size = {48, 24}
  preview.style.bar_width = 24  -- fill the whole element, not just a thin bar
  preview.style.color = color
  return preview_frame
end

local function build_presets(parent, unit_number)
  local table_el = parent.add {type = "table", name = "ccc_presets", column_count = 6}
  table_el.style.horizontal_spacing = 4
  table_el.style.vertical_spacing = 4

  for _, preset in ipairs(PRESETS) do
    local button = table_el.add {
      type = "progressbar",
      name = "ccc_preset_" .. preset.name,
      value = 1,
      tooltip = {"custom-caravans-color." .. preset.name},
      tags = {ccc_action = "preset", unit_number = unit_number, r = preset.color.r, g = preset.color.g, b = preset.color.b},
    }
    button.style.size = 24
    button.style.bar_width = 24  -- solid swatch
    button.style.color = preset.color
  end
end

local function build_slider_row(parent, row_name, caption, unit_number, initial_value)
  local flow = parent.add {type = "flow", name = row_name .. "_flow", direction = "horizontal"}
  flow.style.vertical_align = "center"

  local label = flow.add {type = "label", caption = caption}
  label.style.width = 16

  local slider = flow.add {
    type = "slider",
    name = row_name,
    minimum_value = 0,
    maximum_value = 255,
    value = initial_value,
    tags = {ccc_action = "slider", unit_number = unit_number},
  }
  slider.style.width = 120

  local value_label = flow.add {type = "label", name = row_name .. "_value", caption = tostring(math.floor(initial_value))}
  value_label.style.width = 30

  return flow
end

local function build_sliders(parent, unit_number, color)
  local flow = parent.add {type = "flow", name = "ccc_sliders", direction = "vertical"}
  build_slider_row(flow, "ccc_slider_r", "R", unit_number, math.floor((color.r or 1) * 255 + 0.5))
  build_slider_row(flow, "ccc_slider_g", "G", unit_number, math.floor((color.g or 1) * 255 + 0.5))
  build_slider_row(flow, "ccc_slider_b", "B", unit_number, math.floor((color.b or 1) * 255 + 0.5))
end

local function build_reset_button(parent, unit_number)
  parent.add {
    type = "button",
    name = "ccc_reset_button",
    caption = {"custom-caravans-gui.reset"},
    tooltip = {"custom-caravans-gui.reset-tooltip"},
    tags = {ccc_action = "reset", unit_number = unit_number},
  }
end

--- Opens (or refreshes, if already open for the same entity) the color panel
--- for `entity`, which must be one of the 9 supported prototypes.
function Gui.open_for_entity(player, entity)
  if not (entity and entity.valid) then return end
  local unit_number = entity.unit_number
  if not unit_number then return end

  local existing = player.gui.screen[PANEL_NAME]
  if existing and existing.valid then
    if existing.tags and existing.tags.unit_number == unit_number then
      -- Already open for this exact entity - nothing to do.
      return
    end
    existing.destroy()
  end

  local color = Colors.get_color(unit_number) or DEFAULT_COLOR

  -- Building is wrapped in pcall: this panel is a "nice to have" alongside
  -- the entity's real GUI, and a bad style/sprite name (unverifiable without
  -- a running Factorio instance) should not be able to break the rest of the
  -- mod's event handling.
  local ok, err = pcall(function()
    local frame = player.gui.screen.add {
      type = "frame",
      name = PANEL_NAME,
      direction = "vertical",
      tags = {unit_number = unit_number},
    }
    frame.location = {x = 20, y = 200}

    build_titlebar(frame)

    local content = frame.add {type = "frame", name = "ccc_content", direction = "vertical", style = "inside_shallow_frame_with_padding"}

    build_preview(content, color)
    build_presets(content, unit_number)
    build_sliders(content, unit_number, color)
    build_reset_button(content, unit_number)
  end)

  if not ok then
    log("[custom-caravans] failed to build color panel: " .. tostring(err))
    local leftover = player.gui.screen[PANEL_NAME]
    if leftover and leftover.valid then leftover.destroy() end
  end
end

function Gui.close(player)
  local existing = player.gui.screen[PANEL_NAME]
  if existing and existing.valid then
    existing.destroy()
  end
end

--------------------------------------------------------------------------------
-- Live-update helpers
--------------------------------------------------------------------------------

local function refresh_panel_from_color(player, color)
  local frame = player.gui.screen[PANEL_NAME]
  if not (frame and frame.valid) then return end

  local content = frame.ccc_content
  if not (content and content.valid) then return end

  if content.ccc_preview_frame and content.ccc_preview_frame.valid then
    content.ccc_preview_frame.ccc_preview.style.color = color
  end

  local sliders = content.ccc_sliders
  if sliders and sliders.valid then
    local r = math.floor((color.r or 1) * 255 + 0.5)
    local g = math.floor((color.g or 1) * 255 + 0.5)
    local b = math.floor((color.b or 1) * 255 + 0.5)

    sliders.ccc_slider_r_flow.ccc_slider_r.slider_value = r
    sliders.ccc_slider_r_flow.ccc_slider_r_value.caption = tostring(r)
    sliders.ccc_slider_g_flow.ccc_slider_g.slider_value = g
    sliders.ccc_slider_g_flow.ccc_slider_g_value.caption = tostring(g)
    sliders.ccc_slider_b_flow.ccc_slider_b.slider_value = b
    sliders.ccc_slider_b_flow.ccc_slider_b_value.caption = tostring(b)
  end
end

local function current_slider_color(player)
  local frame = player.gui.screen[PANEL_NAME]
  if not (frame and frame.valid) then return nil end
  local sliders = frame.ccc_content and frame.ccc_content.ccc_sliders
  if not (sliders and sliders.valid) then return nil end

  local r = sliders.ccc_slider_r_flow.ccc_slider_r.slider_value
  local g = sliders.ccc_slider_g_flow.ccc_slider_g.slider_value
  local b = sliders.ccc_slider_b_flow.ccc_slider_b.slider_value

  return {r = r / 255, g = g / 255, b = b / 255, a = 1}
end

--------------------------------------------------------------------------------
-- Event handlers
--------------------------------------------------------------------------------

script.on_event(defines.events.on_gui_opened, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  if event.gui_type == defines.gui_type.entity and event.entity and event.entity.valid then
    if Colors.OUTPOSTS[event.entity.name] then
      Gui.open_for_entity(player, event.entity)
    end
    return
  end

  if event.gui_type == defines.gui_type.custom and event.element and event.element.valid and event.element.name == "caravan_gui" then
    local unit_number = event.element.tags and event.element.tags.unit_number
    local entity = resolve_entity_by_unit_number(unit_number, player)
    if entity and Colors.CARAVANS[entity.name] then
      Gui.open_for_entity(player, entity)
    end
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  if event.gui_type == defines.gui_type.entity and event.entity and event.entity.valid then
    if Colors.OUTPOSTS[event.entity.name] then
      Gui.close(player)
    end
    return
  end

  if event.gui_type == defines.gui_type.custom and event.element and event.element.valid then
    if event.element.name == "caravan_gui" then
      Gui.close(player)
    elseif event.element.name == PANEL_NAME then
      -- Our own panel was closed directly (e.g. Escape while it was the
      -- top-most opened gui) - nothing else to clean up.
    end
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid and element.tags) then return end
  local action = element.tags.ccc_action
  if not action then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  if action == "close" then
    Gui.close(player)
    return
  end

  local unit_number = element.tags.unit_number
  local entity = resolve_entity_by_unit_number(unit_number, player)
  if not (entity and entity.valid) then
    Gui.close(player)
    return
  end

  if action == "preset" then
    local color = {r = element.tags.r, g = element.tags.g, b = element.tags.b, a = 1}
    Colors.set_color(entity, color)
    refresh_panel_from_color(player, color)
  elseif action == "reset" then
    Colors.reset_color(entity)
    refresh_panel_from_color(player, Colors.get_color(unit_number) or DEFAULT_COLOR)
  end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags) then return end
  if element.tags.ccc_action ~= "slider" then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local unit_number = element.tags.unit_number
  local entity = resolve_entity_by_unit_number(unit_number, player)
  if not (entity and entity.valid) then
    Gui.close(player)
    return
  end

  -- Update this slider's own value label immediately.
  local value_label = element.parent[element.name .. "_value"]
  if value_label and value_label.valid then
    value_label.caption = tostring(math.floor(element.slider_value))
  end

  local color = current_slider_color(player)
  if not color then return end

  Colors.set_color(entity, color)

  local frame = player.gui.screen[PANEL_NAME]
  if frame and frame.valid then
    local preview_frame = frame.ccc_content and frame.ccc_content.ccc_preview_frame
    if preview_frame and preview_frame.valid then
      preview_frame.ccc_preview.style.color = color
    end
  end
end)

return Gui
