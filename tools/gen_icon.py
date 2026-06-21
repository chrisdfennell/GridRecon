"""Generate the GridRecon launcher icon at multiple sizes.

Design: a targeting reticle centered on a faint map grid, on a dark tactical-green
rounded tile - "find a point on the grid". Drawn 8x oversampled then downscaled
(LANCZOS) for crisp antialiasing. High contrast so it survives the 1-bit
monochrome thresholding on Instinct displays.

Outputs:
  resources/drawables/launcher_icon.png   (72px, referenced by the manifest)
  assets/icon_1024.png                     (hi-res, for the store / promo)
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Palette
TILE      = (18, 33, 26, 255)      # dark slate-green
TILE_EDGE = (60, 92, 74, 255)
GRID      = (120, 180, 140, 110)   # faint grid lines
RETICLE   = (70, 224, 106, 255)    # bright tactical green
DOT       = (255, 200, 60, 255)    # amber "located" marker

def render(px):
    S = px * 8                      # supersample
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Rounded tile
    pad = int(S * 0.06)
    r = int(S * 0.20)
    d.rounded_rectangle([pad, pad, S - pad, S - pad], radius=r, fill=TILE,
                        outline=TILE_EDGE, width=max(2, int(S * 0.012)))

    # Map grid (3x3) inside the tile
    gpad = int(S * 0.20)
    g0, g1 = gpad, S - gpad
    gw = max(1, int(S * 0.010))
    for i in (1, 2):
        x = g0 + (g1 - g0) * i / 3
        d.line([(x, g0), (x, g1)], fill=GRID, width=gw)
        y = g0 + (g1 - g0) * i / 3
        d.line([(g0, y), (g1, y)], fill=GRID, width=gw)

    # Reticle: ring + crosshair with a center gap
    cx, cy = S / 2, S / 2
    rad = int(S * 0.255)
    lw = max(2, int(S * 0.030))
    d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=RETICLE, width=lw)
    gap = int(S * 0.085)
    tick = int(S * 0.085)            # how far ticks extend past the ring
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        x0 = cx + dx * gap
        y0 = cy + dy * gap
        x1 = cx + dx * (rad + tick)
        y1 = cy + dy * (rad + tick)
        d.line([(x0, y0), (x1, y1)], fill=RETICLE, width=lw)

    # Amber "located target" dot, offset onto a grid intersection
    ox = g0 + (g1 - g0) * 2 / 3
    oy = g0 + (g1 - g0) * 1 / 3
    dr = int(S * 0.052)
    d.ellipse([ox - dr, oy - dr, ox + dr, oy + dr], fill=DOT)

    return img.resize((px, px), Image.LANCZOS)

def main():
    out_icon = os.path.join(HERE, "resources", "drawables", "launcher_icon.png")
    out_hi = os.path.join(HERE, "assets", "icon_1024.png")
    os.makedirs(os.path.dirname(out_hi), exist_ok=True)
    # 40px = exact launcher size for the Fenix 8 Solar 51mm and most fenix/epix;
    # other devices (26-65px) scale this with a harmless build warning.
    render(40).save(out_icon)
    render(1024).save(out_hi)
    # A couple of reference sizes for inspection
    for s in (40, 30):
        render(s).save(os.path.join(HERE, "assets", f"icon_{s}.png"))
    print("wrote", out_icon, "and", out_hi)

if __name__ == "__main__":
    main()
