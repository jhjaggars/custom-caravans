# Mod portal copy

Paste-ready text for https://mods.factorio.com/mod/custom-caravans. Keep this
in sync with README.md and info.json's "description" field when features change.

## Summary (portal "Summary" field, also info.json description)

Paint every pyalienlife caravan and caravan outpost its own color, the way you
color locomotives and train stops. Includes copy/paste between any of them.

## Long description (portal "Description" field)

Every caravan of a given type in pyalienlife looks exactly like every other one.
Once you are running a dozen routes, telling them apart at a glance is guesswork.

**Custom Caravans** gives each caravan and each caravan outpost its own color,
the same way you color a locomotive or a train stop. Color your ore route red and
your fluid route blue, or match each caravan to the outpost it serves.

### What you can color

All ten caravan variants — caravan, fluidavan, flyavan, fluidflyavan and nukavan,
plus their five TURD tech-path versions — and all four outposts, including the
fluid and aerial ones.

### How it works

Open a caravan or an outpost and the color picker is right there in its window.
Drag the red, green and blue sliders and the color updates live on the entity, so
you can see what you are picking before you commit. An alpha slider controls how
strongly the color reads: turn it down and an outpost becomes a tint over its
normal livery instead of a full repaint. Caravans get a size slider for their
marker. A reset button restores the stock appearance.

**Copy and paste works exactly like building settings.** Shift-right-click a
colored caravan or outpost to copy its color, then shift-left-click another one to
paste it — in any combination, including caravan to outpost and back. Pasting from
an uncolored entity clears the target, so paste is a true copy rather than a
one-way "add color". Outpost colors also survive blueprints, ghosts and cloning.

### A note on how caravans are colored

Outposts are repainted directly: their banner, pY logo and hazard stripes take
your color crisply, just like a locomotive.

Caravans instead get a colored ring on the ground beneath them and keep their own
livery. This is deliberate. A caravan's walk cycle advances roughly one frame per
tick, and Factorio never exposes an entity's current animation frame to a mod, so
a tinted copy of the body can't be held in sync with the sprite — it visibly slides
out of phase the moment the caravan starts moving. A ring has no animation phase to
get wrong, stays readable at any zoom level, and tells you at a glance whether a
caravan is parked at an outpost or out on a route.

### Requirements

Needs pyalienlife 3.0.66 or newer. Nothing else. No pyalienlife files are replaced
and there are no per-tick scripts, so it is safe to add to an existing save — and
safe to remove, since taking it out just leaves your caravans their normal color.

Source and issue tracker: https://github.com/jhjaggars/custom-caravans
