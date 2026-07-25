#!/usr/bin/env python3
"""Generate the caravan colour marker sprite.

A caravan's walk cycle advances about one frame per tick and the engine never
exposes an entity's current animation frame, so a tinted overlay of the body
mask can't be kept in phase with the sprite -- it looks detached the moment the
caravan moves. Instead each coloured caravan gets this position-locked ring
drawn on the ground beneath it, which follows the entity and never desyncs.

White with a soft edge, so a runtime tint gives a clean solid colour. Flattened
vertically so it reads as lying on the ground in Factorio's projection.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

SIZE = 128           # px, before scale is applied by the sprite prototype
SUPERSAMPLE = 4      # draw large, downsample for antialiasing
FLATTEN = 0.62       # y radius as a fraction of x radius (ground perspective)
OUTER = 0.86         # outer radius as a fraction of half-width
THICKNESS = 0.20     # ring thickness as a fraction of the outer radius


def make_marker(path):
    s = SIZE * SUPERSAMPLE
    img = Image.new("L", (s, s), 0)
    draw = ImageDraw.Draw(img)

    cx = cy = s / 2
    rx = (s / 2) * OUTER
    ry = rx * FLATTEN
    inner_rx = rx * (1 - THICKNESS)
    inner_ry = ry * (1 - THICKNESS)

    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    draw.ellipse([cx - inner_rx, cy - inner_ry, cx + inner_rx, cy + inner_ry], fill=0)

    # LANCZOS already antialiases; a touch of blur just softens the edge.
    alpha = img.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.3))

    # White RGB everywhere so the runtime tint is the only colour source.
    out = Image.merge("RGBA", (
        Image.new("L", (SIZE, SIZE), 255),
        Image.new("L", (SIZE, SIZE), 255),
        Image.new("L", (SIZE, SIZE), 255),
        alpha,
    ))
    out.save(path)
    print(f"{path}: {SIZE}x{SIZE}, opaque px={sum(1 for p in alpha.getdata() if p > 8)}")


if __name__ == "__main__":
    make_marker(sys.argv[1] if len(sys.argv) > 1 else "caravan-marker.png")
