-- Custom Caravans: scripts/colors.lua
--
-- Owns storage.colors and all LuaRendering overlay creation/teardown.
--
-- storage.colors[unit_number] = {
--   color = {r, g, b, a},       -- the color the player picked (a is always 1;
--                                  wash-type alpha reduction happens at render time)
--   entity = LuaEntity,          -- safe to store: storage tables persist LuaObject
--                                  references correctly across save/load
--   entity_name = string,        -- cached prototype name (entity may become invalid)
--   render = LuaRenderObject,
--   dir = int,                   -- last-seen direction index (0-15), caravans only
--   last_position = {x=, y=},    -- used by tracker.lua to detect idle caravans
-- }

local Colors = {}

Colors.CARAVANS = {
  caravan = true,
  fluidavan = true,
  flyavan = true,
  fluidflyavan = true,
  nukavan = true,
  -- TURD tech-path variants: separate prototypes sharing the base variants'
  -- sprite sheets, so they also share their overlay animations (see
  -- Colors.base_name below).
  ["caravan-turd"] = true,
  ["fluidavan-turd"] = true,
  ["flyavan-turd"] = true,
  ["fluidflyavan-turd"] = true,
  ["nukavan-turd"] = true,
}

--- Maps a turd variant to the base prototype name whose overlay assets it
--- shares; base names pass through unchanged. The MASK/WASH/AIR lookup tables
--- below are keyed by base name only.
function Colors.base_name(entity_name)
  return (entity_name:gsub("%-turd$", ""))
end

-- caravan/fluidavan have a real mask layer -> full-alpha tinted overlay.
Colors.MASK_TYPES = {
  caravan = true,
  fluidavan = true,
}

-- flyavan/fluidflyavan/nukavan have no mask -> translucent "wash" overlay
-- built from their body sprite.
Colors.WASH_CARAVAN_TYPES = {
  flyavan = true,
  fluidflyavan = true,
  nukavan = true,
}

Colors.OUTPOSTS = {
  outpost = true,
  ["outpost-fluid"] = true,
  ["outpost-aerial"] = true,
  ["outpost-aerial-fluid"] = true,
}

Colors.CARAVAN_LIST = {
  "caravan", "fluidavan", "flyavan", "fluidflyavan", "nukavan",
  "caravan-turd", "fluidavan-turd", "flyavan-turd", "fluidflyavan-turd", "nukavan-turd",
}
Colors.OUTPOST_LIST = {"outpost", "outpost-fluid", "outpost-aerial", "outpost-aerial-fluid"}

Colors.ALL = {}
Colors.ALL_LIST = {}
for _, n in ipairs(Colors.CARAVAN_LIST) do
  Colors.ALL[n] = true
  Colors.ALL_LIST[#Colors.ALL_LIST + 1] = n
end
for _, n in ipairs(Colors.OUTPOST_LIST) do
  Colors.ALL[n] = true
  Colors.ALL_LIST[#Colors.ALL_LIST + 1] = n
end

-- flyavan/fluidflyavan themselves render at render_layer "air-object" (160)
-- (see prototypes/creatures/flying-caravan.lua: render_layer = "air-object"),
-- which is well above the "higher-object-above" (127) layer used for the
-- ground-based entities. If we used "higher-object-above" for their overlay
-- too, it would be drawn *behind* the flying body and never be visible.
-- "air-entity-info-icon" (161) is the next named layer above "air-object"
-- (160), guaranteeing the wash always draws on top of the flying body.
local GROUND_RENDER_LAYER = "higher-object-above"
local AIR_RENDER_LAYER = "air-entity-info-icon"
local AIR_ENTITY_TYPES = {
  flyavan = true,
  fluidflyavan = true,
}

local WASH_ALPHA_MULTIPLIER = 0.5

local function render_layer_for(entity_name)
  if AIR_ENTITY_TYPES[Colors.base_name(entity_name)] then
    return AIR_RENDER_LAYER
  end
  return GROUND_RENDER_LAYER
end

--- Ensures storage.colors exists. Only ever called from runtime event
--- handlers (never from on_load), so mutating storage here is safe.
local function get_store()
  if not storage.colors then
    storage.colors = {}
  end
  return storage.colors
end

--- Converts a LuaEntity orientation (0..1) into one of 16 direction indices.
function Colors.direction_to_index(orientation)
  orientation = orientation or 0
  local dir = math.floor(orientation * 16 + 0.5) % 16
  return dir
end

--- Name of the direction-specific overlay AnimationPrototype for a caravan.
function Colors.overlay_animation_name(entity_name, dir_index)
  local base = Colors.base_name(entity_name)
  if Colors.MASK_TYPES[base] then
    return "custom-caravans-caravan-mask-" .. dir_index
  elseif Colors.WASH_CARAVAN_TYPES[base] then
    return "custom-caravans-" .. base .. "-wash-" .. dir_index
  end
  return nil
end

--- Name of the (direction-less) overlay SpritePrototype for an outpost.
function Colors.overlay_sprite_name(entity_name)
  if Colors.OUTPOSTS[entity_name] then
    return "custom-caravans-" .. entity_name .. "-mask"
  end
  return nil
end

--- Wash overlays (flying/nuka caravans, which have no mask art) are multiplied
--- down to ~50% alpha so they read as a tint rather than solid repaint; mask
--- overlays (caravan/fluidavan, and all outposts via this mod's generated
--- graphics/*-mask.png) use full alpha since the mask fully replaces the
--- livery region.
function Colors.effective_tint(entity_name, color)
  local a = color.a or 1
  if Colors.WASH_CARAVAN_TYPES[Colors.base_name(entity_name)] then
    a = a * WASH_ALPHA_MULTIPLIER
  end
  return {r = color.r, g = color.g, b = color.b, a = a}
end

-- The data stage strips the baked-in mask layer from these caravans (see
-- data-updates.lua section 4) and records each one's original tint here, so
-- every masked caravan must ALWAYS carry an overlay - "no custom color" means
-- "overlay in the original default tint", not "no overlay".
local default_colors
function Colors.get_default_color(entity_name)
  if not default_colors then
    local md = prototypes.mod_data["custom-caravans"]
    default_colors = (md and md.data and md.data.default_colors) or {}
  end
  return default_colors[entity_name]
end

--- Applies the prototype's original tint if the entity has no color yet.
--- No-op for entity types without a registered default (wash caravans,
--- outposts), which are allowed to be overlay-free.
function Colors.ensure_default(entity)
  if not (entity and entity.valid and entity.unit_number) then return end
  if Colors.get_entry(entity.unit_number) then return end
  local default = Colors.get_default_color(entity.name)
  if default then
    Colors.set_color(entity, default)
  end
end

--- "Reset" semantics for GUI/paste: masked caravans revert to their default
--- tint, everything else just loses its overlay.
function Colors.reset_color(entity)
  if not (entity and entity.valid) then return end
  local default = Colors.get_default_color(entity.name)
  if default then
    Colors.set_color(entity, default)
  else
    Colors.clear_color(entity)
  end
end

--- Sweeps all surfaces and gives every masked caravan that lacks a color its
--- default overlay. Used on init/configuration-changed so caravans built
--- before this mod was added (whose baked mask layer is now stripped) don't
--- lose their flags.
function Colors.apply_defaults_everywhere()
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered {name = Colors.CARAVAN_LIST}) do
      Colors.ensure_default(entity)
    end
  end
end

function Colors.get_color(unit_number)
  if not unit_number then return nil end
  local entry = storage.colors and storage.colors[unit_number]
  return entry and entry.color
end

function Colors.get_entry(unit_number)
  if not unit_number then return nil end
  return storage.colors and storage.colors[unit_number]
end

--- Destroys the render object (if any) and removes the storage entry.
function Colors.clear_color(entity_or_unit_number)
  local unit_number
  if type(entity_or_unit_number) == "number" then
    unit_number = entity_or_unit_number
  elseif entity_or_unit_number and entity_or_unit_number.valid then
    unit_number = entity_or_unit_number.unit_number
  end
  if not unit_number then return end

  local store = get_store()
  local entry = store[unit_number]
  if entry then
    if entry.render and entry.render.valid then
      entry.render.destroy()
    end
    store[unit_number] = nil
  end
end

--- Creates or updates the tinted overlay for `entity`. `color` is a plain
--- {r,g,b[,a]} table (values 0..1).
function Colors.set_color(entity, color)
  if not (entity and entity.valid) then return end
  local unit_number = entity.unit_number
  if not unit_number then return end

  local is_caravan = Colors.CARAVANS[entity.name]
  local is_outpost = Colors.OUTPOSTS[entity.name]
  if not (is_caravan or is_outpost) then return end

  local store = get_store()
  local entry = store[unit_number] or {}
  store[unit_number] = entry

  entry.color = {r = color.r, g = color.g, b = color.b, a = color.a or 1}
  entry.entity = entity
  entry.entity_name = entity.name

  if entry.render and entry.render.valid then
    entry.render.destroy()
    entry.render = nil
  end

  local tint = Colors.effective_tint(entity.name, entry.color)

  if is_caravan then
    local dir_index = Colors.direction_to_index(entity.orientation)
    entry.dir = dir_index
    entry.last_position = {x = entity.position.x, y = entity.position.y}

    local anim_name = Colors.overlay_animation_name(entity.name, dir_index)
    if anim_name then
      entry.render = rendering.draw_animation {
        animation = anim_name,
        target = entity,
        surface = entity.surface,
        tint = tint,
        render_layer = render_layer_for(entity.name),
        animation_speed = 0,
      }
    end
  else
    local sprite_name = Colors.overlay_sprite_name(entity.name)
    if sprite_name then
      entry.render = rendering.draw_sprite {
        sprite = sprite_name,
        target = entity,
        surface = entity.surface,
        tint = tint,
        render_layer = render_layer_for(entity.name),
      }
    end
  end

  -- Ensures storage.colors[unit_number] gets cleaned up once the entity dies,
  -- however that happens (mined, killed, cloned away, etc). Registering the
  -- same entity more than once is harmless.
  script.register_on_object_destroyed(entity)
end

script.on_event(defines.events.on_object_destroyed, function(event)
  local unit_number = event.useful_id
  if not unit_number then return end
  Colors.clear_color(unit_number)
end)

return Colors
