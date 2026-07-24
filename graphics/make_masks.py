#!/usr/bin/env python3
"""Generate tint-mask PNGs for pyalienlife outpost sprites.

Selects the yellow "livery" accents (pY logo, hazard stripes, pads, crates)
by hue and emits a grayscale-shaded, alpha-masked image: white-ish where the
paint goes (carrying the original shading), transparent elsewhere. Tinting the
result with a color reproduces the vanilla locomotive/train-stop mask look.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage  # may not exist; fall back below

def rgb_to_hsv(arr):
    # arr float 0..1, shape (h,w,3) -> h,s,v each (h,w)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    maxc = arr.max(-1)
    minc = arr.min(-1)
    v = maxc
    delta = maxc - minc
    s = np.where(maxc > 0, delta / np.maximum(maxc, 1e-9), 0)
    # hue
    hue = np.zeros_like(maxc)
    mask = delta > 1e-9
    rc = np.where(mask, (maxc - r) / np.maximum(delta, 1e-9), 0)
    gc = np.where(mask, (maxc - g) / np.maximum(delta, 1e-9), 0)
    bc = np.where(mask, (maxc - b) / np.maximum(delta, 1e-9), 0)
    hue = np.where((maxc == r) & mask, bc - gc, hue)
    hue = np.where((maxc == g) & mask, 2.0 + rc - bc, hue)
    hue = np.where((maxc == b) & mask, 4.0 + gc - rc, hue)
    hue = (hue / 6.0) % 1.0
    return hue * 360.0, s, v

def make_mask(src_path, dst_path, hue_lo=32, hue_hi=72, sat_min=0.30, val_min=0.18,
              min_region=6, feather=True, exclude_boxes=()):
    img = Image.open(src_path).convert("RGBA")
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    h, s, v = rgb_to_hsv(rgb)

    sel = (h >= hue_lo) & (h <= hue_hi) & (s >= sat_min) & (v >= val_min) & (alpha > 0.5)

    # drop tiny speckles so stray yellowish pixels don't become paint dots,
    # and drop whole regions whose centroid falls in an exclusion box
    # (e.g. stored barrels that share the livery hue)
    try:
        lab, n = ndimage.label(sel)
        sizes = ndimage.sum(sel, lab, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes >= min_region
        if exclude_boxes and n:
            centroids = ndimage.center_of_mass(sel, lab, range(1, n + 1))
            for i, (cy, cx) in enumerate(centroids):
                for (x0, y0, x1, y1) in exclude_boxes:
                    if x0 <= cx <= x1 and y0 <= cy <= y1:
                        keep[i + 1] = False
        sel = keep[lab]
    except Exception:
        pass

    # mask brightness carries the original shading; lift it so full-white areas
    # take the tint at full strength (like vanilla masks, which are near-white)
    shade = np.clip(v / max(np.percentile(v[sel], 92), 1e-6), 0, 1) if sel.any() else v
    gray = (shade * 255).astype(np.uint8)

    out = np.zeros((*sel.shape, 4), np.uint8)
    out[..., 0] = gray
    out[..., 1] = gray
    out[..., 2] = gray
    out[..., 3] = np.where(sel, 255, 0).astype(np.uint8)

    res = Image.fromarray(out, "RGBA")
    if feather:
        # soften the alpha edge by 1px to avoid jaggies over the base sprite
        from PIL import ImageFilter
        alpha_img = res.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
        res.putalpha(alpha_img)
    res.save(dst_path)
    picked = int(sel.sum())
    total = int((alpha > 0.5).sum())
    print(f"{dst_path}: {picked}/{total} px selected ({100.0*picked/max(total,1):.1f}% of sprite)")

if __name__ == "__main__":
    # src dst [hue_lo hue_hi sat_min val_min min_region] [x0,y0,x1,y1 ...]
    args = sys.argv[1:]
    nums, boxes = [], []
    for a in args[2:]:
        if "," in a:
            boxes.append(tuple(float(v) for v in a.split(",")))
        else:
            nums.append(float(a))
    kw = dict(zip(["hue_lo", "hue_hi", "sat_min", "val_min", "min_region"], nums))
    if "min_region" in kw:
        kw["min_region"] = int(kw["min_region"])
    if boxes:
        kw["exclude_boxes"] = boxes
    make_mask(args[0], args[1], **kw)
