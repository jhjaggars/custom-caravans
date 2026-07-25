-- Custom Caravans: data-updates.lua
--
-- Runs after pyalienlife's data stage. Two jobs:
--   1. Extend `additional_pastable_entities` on the 5 caravan units + 4 outpost
--      buildings so settings (and therefore our color) can be copy/pasted
--      between any pair of them.
--   2. Generate per-direction overlay AnimationPrototypes (for the caravans)
--      and overlay SpritePrototypes (for the outposts) that scripts/colors.lua
--      renders on top of the real entity via LuaRendering, tinted with the
--      player-chosen color.
--
-- Geometry for the overlays is derived from data.raw at load time (rather
-- than hardcoded numbers) so that pyalienlife graphic updates are less likely
-- to silently desync our overlays from the base sprites.

local mod_name = "custom-caravans"

-- The 9 target prototypes, with enough info to look each one up in data.raw
-- regardless of its concrete type (unit / container / storage-tank).
local PROTOTYPE_REFS = {
  {ptype = "unit", name = "caravan"},
  {ptype = "unit", name = "fluidavan"},
  {ptype = "unit", name = "flyavan"},
  {ptype = "unit", name = "fluidflyavan"},
  {ptype = "unit", name = "nukavan"},
  -- TURD tech-path variants: separate prototypes, but they reuse the exact
  -- same sprite sheets as their base counterparts (verified against the
  -- data.raw dump), so they share the base variants' overlay animations.
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
-- 1. additional_pastable_entities: extend, never overwrite
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
    log("[" .. mod_name .. "] warning: prototype " .. ref.ptype .. "/" .. ref.name ..
      " not found - skipping additional_pastable_entities patch for it")
  end
end

--------------------------------------------------------------------------------
-- 2. Overlay animation prototypes for the 5 caravan units
--------------------------------------------------------------------------------

-- Builds `direction_count` single-direction `type = "animation"` prototypes
-- named "<name_prefix>-0" .. "<name_prefix>-<direction_count-1>" out of a
-- RotatedAnimation-style source layer (the kind used in run_animation), using
-- frame_sequence to slice out each direction's frames.
--
-- `direction_count` is NOT a valid field on a plain `animation` prototype, so
-- we build a fresh table with only the fields a single-direction Animation
-- understands, rather than table.deepcopy-ing the whole source layer.
local function build_direction_animations(name_prefix, source_layer)
  local frame_count = source_layer.frame_count
  local direction_count = source_layer.direction_count or 16

  if not frame_count then
    log("[" .. mod_name .. "] warning: source layer for " .. name_prefix .. " has no frame_count; skipping")
    return
  end

  local total_frames = frame_count * direction_count

  for dir = 0, direction_count - 1 do
    local frame_sequence = {}
    for f = 1, frame_count do
      frame_sequence[f] = dir * frame_count + f
    end

    local anim = {
      type = "animation",
      name = name_prefix .. "-" .. dir,
      filenames = table.deepcopy(source_layer.filenames),
      slice = source_layer.slice,
      lines_per_file = source_layer.lines_per_file,
      line_length = source_layer.line_length,
      width = source_layer.width,
      height = source_layer.height,
      frame_count = total_frames,
      frame_sequence = frame_sequence,
      flags = source_layer.flags and table.deepcopy(source_layer.flags) or nil,
    }

    if source_layer.shift then
      anim.shift = {source_layer.shift[1], source_layer.shift[2]}
    end

    data:extend {anim}
  end
end

-- Finds the mask layer in a RotatedAnimation's layer list: the pyalienlife
-- caravan/fluidavan mask layers are identified by carrying an explicit `tint`
-- field (used upstream to recolor caravan vs. fluidavan). We deliberately do
-- NOT rely on a fixed array index, since layer order is not part of any
-- documented contract.
local function find_mask_layer(layers)
  for _, layer in pairs(layers) do
    if layer.tint then
      return layer
    end
  end
  return nil
end

-- Finds the "body" layer (the main visible sprite, as opposed to the shadow
-- layer) in a RotatedAnimation's layer list. Shadow layers are identified by
-- `draw_as_shadow = true`; mask layers (see above) are excluded via the same
-- `tint` check so this also works for caravan/fluidavan if ever reused.
local function find_body_layer(layers)
  for _, layer in pairs(layers) do
    if not layer.draw_as_shadow and not layer.tint then
      return layer
    end
  end
  return nil
end

-- caravan & fluidavan share the exact same mask spritesheet
-- (__pyalienlifegraphics2__/graphics/entity/caravan/caravan-walk-0X-mask.png),
-- only differing in the `tint` baked into pyalienlife's own prototype (which
-- we ignore - our runtime tint replaces it). So we only need to generate one
-- set of 16 mask overlay animations, shared by both entity types.
do
  local mask_source_units = {"caravan", "fluidavan"}
  local mask_layer
  for _, unit_name in ipairs(mask_source_units) do
    local proto = data.raw.unit[unit_name]
    if proto and proto.run_animation and proto.run_animation.layers then
      mask_layer = find_mask_layer(proto.run_animation.layers)
      if mask_layer then break end
    end
  end

  if mask_layer then
    build_direction_animations(mod_name .. "-caravan-mask", mask_layer)
  else
    log("[" .. mod_name .. "] warning: could not find caravan/fluidavan mask layer; mask overlays disabled")
  end
end

-- flyavan, fluidflyavan and nukavan have no dedicated mask layer, so we use
-- their body layer as a translucent tinted "wash" overlay instead (alpha is
-- reduced at runtime in scripts/colors.lua).
for _, unit_name in ipairs({"flyavan", "fluidflyavan", "nukavan"}) do
  local proto = data.raw.unit[unit_name]
  if proto and proto.run_animation and proto.run_animation.layers then
    local body_layer = find_body_layer(proto.run_animation.layers)
    if body_layer then
      build_direction_animations(mod_name .. "-" .. unit_name .. "-wash", body_layer)
    else
      log("[" .. mod_name .. "] warning: could not find body layer for " .. unit_name .. "; wash overlay disabled")
    end
  else
    log("[" .. mod_name .. "] warning: unit prototype " .. unit_name .. " or its run_animation not found")
  end
end

--------------------------------------------------------------------------------
-- 3. Overlay sprite prototypes for the 4 outposts
--------------------------------------------------------------------------------

-- outpost / outpost-aerial are `type = "container"` with a single `picture`
-- field; outpost-fluid / outpost-aerial-fluid are `type = "storage-tank"`
-- with the picture nested under `pictures.picture` instead.
--
-- Each outpost gets a hand-generated mask sprite (graphics/<name>-mask.png,
-- built by graphics/make_masks.py from the base sprite: the yellow/blue
-- "livery" accents - banner, pY logo, hazard stripes - isolated by hue as a
-- grayscale paint region, locomotive-mask style). The mask must match the base
-- sprite's geometry exactly, so width/height/shift/flags are still derived
-- from the base layer at load time; only the filename is ours.
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
        filename = "__custom-caravans__/graphics/" .. ref.name .. "-mask.png",
        width = layer1.width,
        height = layer1.height,
        flags = layer1.flags and table.deepcopy(layer1.flags) or nil,
      }
      if layer1.shift then
        sprite.shift = {layer1.shift[1], layer1.shift[2]}
      end
      data:extend {sprite}
    else
      log("[" .. mod_name .. "] warning: could not find picture layer 1 for " .. ref.name .. "; outpost mask overlay disabled")
    end
  else
    log("[" .. mod_name .. "] warning: prototype " .. ref.ptype .. "/" .. ref.name .. " not found; outpost mask overlay disabled")
  end
end

--------------------------------------------------------------------------------
-- 4. Strip the baked-in mask layers from the masked caravans
--------------------------------------------------------------------------------

-- The static mask layer (yellow flags on caravan, blue on fluidavan, and the
-- turd variants' recolors) would keep showing through under our tinted overlay
-- whenever the overlay's walk phase drifts from the body's - in-game this
-- reads as doubled flags in two colors. So the baked layer is removed
-- entirely, and the control stage instead keeps a tinted overlay applied to
-- these caravans at ALL times, defaulting each one to its original tint. The
-- captured tints travel to the control stage via a mod-data prototype.
--
-- This must run after section 2, which builds the overlay animations by
-- reading the very layers removed here.

local function normalize_color(tint)
  return {
    r = tint.r or tint[1] or 0,
    g = tint.g or tint[2] or 0,
    b = tint.b or tint[3] or 0,
    a = 1,
  }
end

local function strip_mask_layers(proto)
  local captured
  local anims = {}
  anims[#anims + 1] = proto.run_animation
  if proto.attack_parameters then
    anims[#anims + 1] = proto.attack_parameters.animation
  end
  for _, anim in pairs(anims) do
    if anim and anim.layers then
      for i = #anim.layers, 1, -1 do
        if anim.layers[i].tint then
          captured = captured or anim.layers[i].tint
          table.remove(anim.layers, i)
        end
      end
    end
  end
  return captured
end

local default_colors = {}
for _, name in ipairs({"caravan", "fluidavan", "caravan-turd", "fluidavan-turd"}) do
  local proto = data.raw.unit[name]
  if proto then
    local tint = strip_mask_layers(proto)
    if tint then
      default_colors[name] = normalize_color(tint)
    else
      log("[" .. mod_name .. "] warning: no mask layer found to strip on " .. name)
    end
  end
end

data:extend {{
  type = "mod-data",
  name = "custom-caravans",
  data = {default_colors = default_colors},
}}

