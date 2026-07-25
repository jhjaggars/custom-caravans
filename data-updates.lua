-- Custom Caravans: data-updates.lua
--
-- Runs after pyalienlife's data stage. Three jobs:
--   1. Make the caravans and outposts settings-pastable onto each other, and
--      findable by unit number.
--   2. Generate the overlay sprite prototypes that scripts/colors.lua renders
--      on top of a colored entity via LuaRendering:
--        * outposts: a livery mask, so their banner/logo repaints crisply.
--        * caravans: a ground ring marker (see below).
--
-- Why caravans get a marker rather than a repaint: a caravan's walk cycle
-- advances about one frame per tick (distance_per_frame 0.13 against
-- movement_speed 0.14) and the engine never exposes an entity's current
-- animation frame, so a tinted copy of the body mask cannot be held in phase
-- with the sprite -- it visibly detaches as soon as the caravan moves. A
-- position-locked sprite has no phase to get wrong. Caravans therefore keep
-- their own stock mask layer untouched, and the player color is shown by the
-- ring instead.

local mod_name = "custom-caravans"

-- The target prototypes, with enough info to look each one up in data.raw
-- regardless of its concrete type (unit / container / storage-tank). The
-- -turd entries are pyalienlife's TURD tech-path variants.
local PROTOTYPE_REFS = {
  {ptype = "unit", name = "caravan"},
  {ptype = "unit", name = "fluidavan"},
  {ptype = "unit", name = "flyavan"},
  {ptype = "unit", name = "fluidflyavan"},
  {ptype = "unit", name = "nukavan"},
  {ptype = "unit", name = "caravan-turd"},
  {ptype = "unit", name = "fluidavan-turd"},
  {ptype = "unit", name = "flyavan-turd"},
  {ptype = "unit", name = "fluidflyavan-turd"},
  {ptype = "unit", name = "nukavan-turd"},
  {ptype = "container", name = "outpost"},
  {ptype = "storage-tank", name = "outpost-fluid"},
  {ptype = "container", name = "outpost-aerial"},
  {ptype = "storage-tank", name = "outpost-aerial-fluid"},
}

local ALL_NAMES = {}
for _, ref in pairs(PROTOTYPE_REFS) do
  ALL_NAMES[#ALL_NAMES + 1] = ref.name
end

--------------------------------------------------------------------------------
-- 1. Prototype patches
--------------------------------------------------------------------------------

-- game.get_entity_by_unit_number only finds entities whose prototype carries
-- the "get-by-unit-number" flag. `unit` sets it by default but container and
-- storage-tank do not, so an outpost could not be looked up from the
-- unit_number its GUI elements carry. Add it to every entity we color.
local function add_flag(proto, flag)
  proto.flags = proto.flags or {}
  for _, existing in pairs(proto.flags) do
    if existing == flag then return end
  end
  proto.flags[#proto.flags + 1] = flag
end

for _, ref in pairs(PROTOTYPE_REFS) do
  local proto = data.raw[ref.ptype] and data.raw[ref.ptype][ref.name]
  if proto then
    add_flag(proto, "get-by-unit-number")

    -- Extend, never overwrite: pyalienlife already lists caravan<->caravan
    -- pairs here, and the engine needs the entry to fire
    -- on_entity_settings_pasted for otherwise-incompatible types.
    proto.additional_pastable_entities = proto.additional_pastable_entities or {}
    local existing = {}
    for _, n in pairs(proto.additional_pastable_entities) do
      existing[n] = true
    end
    for _, other in pairs(ALL_NAMES) do
      if other ~= ref.name and not existing[other] then
        proto.additional_pastable_entities[#proto.additional_pastable_entities + 1] = other
        existing[other] = true
      end
    end
  else
    log("[" .. mod_name .. "] warning: prototype " .. ref.ptype .. "/" .. ref.name .. " not found")
  end
end

--------------------------------------------------------------------------------
-- 2. Caravan marker sprite
--------------------------------------------------------------------------------

data:extend {{
  type = "sprite",
  name = mod_name .. "-marker",
  filename = "__" .. mod_name .. "__/graphics/caravan-marker.png",
  width = 128,
  height = 128,
  scale = 0.6,
}}

--------------------------------------------------------------------------------
-- 3. Outpost livery mask sprites
--------------------------------------------------------------------------------

-- Each outpost gets a hand-generated mask sprite (graphics/<name>-mask.png,
-- built by graphics/make_masks.py from the base sprite: the yellow/blue
-- "livery" accents - banner, pY logo, hazard stripes - isolated by hue as a
-- grayscale paint region, locomotive-mask style). Outposts are stationary
-- single-sprite entities, so unlike the caravans there is no animation phase
-- to keep in sync and the mask can be overlaid directly.
--
-- The mask must match the base sprite's geometry exactly, so
-- width/height/shift/flags are still derived from the base layer at load time;
-- only the filename is ours.
--
-- outpost / outpost-aerial are `type = "container"` with a single `picture`
-- field; outpost-fluid / outpost-aerial-fluid are `type = "storage-tank"`
-- with the picture nested under `pictures.picture` instead.
local OUTPOST_REFS = {
  {ptype = "container", name = "outpost", path = {"picture"}},
  {ptype = "storage-tank", name = "outpost-fluid", path = {"pictures", "picture"}},
  {ptype = "container", name = "outpost-aerial", path = {"picture"}},
  {ptype = "storage-tank", name = "outpost-aerial-fluid", path = {"pictures", "picture"}},
}

for _, ref in pairs(OUTPOST_REFS) do
  local proto = data.raw[ref.ptype] and data.raw[ref.ptype][ref.name]
  if proto then
    local picture = proto
    for _, key in pairs(ref.path) do
      picture = picture and picture[key]
    end

    local layer1 = picture and picture.layers and picture.layers[1]
    if layer1 then
      local sprite = {
        type = "sprite",
        name = mod_name .. "-" .. ref.name .. "-mask",
        filename = "__" .. mod_name .. "__/graphics/" .. ref.name .. "-mask.png",
        width = layer1.width,
        height = layer1.height,
        flags = layer1.flags and table.deepcopy(layer1.flags) or nil,
      }
      if layer1.shift then
        sprite.shift = {layer1.shift[1], layer1.shift[2]}
      end
      data:extend {sprite}
    else
      log("[" .. mod_name .. "] warning: could not find picture layer 1 for " .. ref.name ..
        "; outpost mask overlay disabled")
    end
  end
end
