-- Custom Caravans: scripts/colors.lua
--
-- Owns storage.colors and all LuaRendering overlay creation/teardown.
--
-- Neither entity type supports the engine's per-entity LuaEntity.color (that
-- is limited to rolling stock, train stops, cars, spider-vehicles, characters,
-- lamps and simple-entity-with-owner), and apply_runtime_tint on a `unit`
-- draws the *force* color, not a per-entity one. So the color is a script
-- rendering targeted at the entity, which the engine keeps glued to it.
--
--   * outposts: a tinted livery mask laid over the building, so the banner and
--     pY logo repaint crisply. They are stationary single-sprite entities, so
--     the overlay simply lines up.
--   * caravans: a ground ring marker. Their walk cycle advances about a frame
--     per tick and the engine exposes no way to read an entity's current
--     animation frame, so a tinted body mask cannot be held in phase and
--     visibly detaches once they move. A position-locked sprite has no phase
--     to get wrong, and caravans keep their own stock livery untouched.
--
-- storage.colors[unit_number] = {
--   color = {r, g, b, a},   -- the color the player picked
--   scale = number,          -- marker size multiplier (caravans only)
--   entity = LuaEntity,      -- safe to store: storage persists LuaObject refs
--   entity_name = string,    -- cached, since entity may become invalid
--   render = LuaRenderObject,
-- }

local Colors = {}

Colors.CARAVAN_LIST = {
  "caravan", "fluidavan", "flyavan", "fluidflyavan", "nukavan",
  "caravan-turd", "fluidavan-turd", "flyavan-turd", "fluidflyavan-turd", "nukavan-turd",
}
Colors.OUTPOST_LIST = {"outpost", "outpost-fluid", "outpost-aerial", "outpost-aerial-fluid"}

Colors.CARAVANS = {}
Colors.OUTPOSTS = {}
Colors.ALL = {}
Colors.ALL_LIST = {}
for _, name in ipairs(Colors.CARAVAN_LIST) do
  Colors.CARAVANS[name] = true
  Colors.ALL[name] = true
  Colors.ALL_LIST[#Colors.ALL_LIST + 1] = name
end
for _, name in ipairs(Colors.OUTPOST_LIST) do
  Colors.OUTPOSTS[name] = true
  Colors.ALL[name] = true
  Colors.ALL_LIST[#Colors.ALL_LIST + 1] = name
end

local MARKER_SPRITE = "custom-caravans-marker"
-- Multiplies the sprite prototype's own scale. The GUI offers
-- MIN_SCALE..MAX_SCALE; anything outside that is a scripted caller's problem.
Colors.DEFAULT_SCALE = 1.0
Colors.MIN_SCALE = 0.4
Colors.MAX_SCALE = 2.5
-- The marker sits on the ground under the caravan; the outpost mask has to
-- land on top of the building it repaints.
local MARKER_RENDER_LAYER = "ground-patch-higher"
local MASK_RENDER_LAYER = "higher-object-above"

--- The game expects colors in pre-multiplied form (channels already multiplied
--- by alpha). storage keeps the plain color the player picked, so this is
--- applied at draw time; without it a reduced alpha washes the overlay out
--- towards white instead of fading it.
local function tint_for(color)
  local a = color.a or 1
  return {r = (color.r or 0) * a, g = (color.g or 0) * a, b = (color.b or 0) * a, a = a}
end

--- Ensures storage.colors exists. Only ever called from runtime event
--- handlers (never from on_load), so mutating storage here is safe.
local function get_store()
  if not storage.colors then
    storage.colors = {}
  end
  return storage.colors
end

--- Name of the overlay SpritePrototype for an outpost.
function Colors.overlay_sprite_name(entity_name)
  if Colors.OUTPOSTS[entity_name] then
    return "custom-caravans-" .. entity_name .. "-mask"
  end
  return nil
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

--- Marker size multiplier, or nil if this entity has never been colored.
function Colors.get_scale(unit_number)
  local entry = Colors.get_entry(unit_number)
  return entry and entry.scale
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
--- {r,g,b[,a]} table (values 0..1). `scale` sizes the caravan marker and is
--- optional: omitting it keeps whatever size the entity already had.
function Colors.set_color(entity, color, scale)
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
  entry.scale = scale or entry.scale or Colors.DEFAULT_SCALE
  entry.entity = entity
  entry.entity_name = entity.name

  if entry.render and entry.render.valid then
    entry.render.destroy()
    entry.render = nil
  end

  if is_caravan then
    entry.render = rendering.draw_sprite {
      sprite = MARKER_SPRITE,
      target = entity,
      surface = entity.surface,
      tint = tint_for(entry.color),
      render_layer = MARKER_RENDER_LAYER,
      x_scale = entry.scale,
      y_scale = entry.scale,
    }
  else
    local sprite_name = Colors.overlay_sprite_name(entity.name)
    if sprite_name then
      entry.render = rendering.draw_sprite {
        sprite = sprite_name,
        target = entity,
        surface = entity.surface,
        tint = tint_for(entry.color),
        render_layer = MASK_RENDER_LAYER,
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
