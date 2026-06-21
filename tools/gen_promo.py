"""Generate promotional graphics for GridRecon.

Outputs (in assets/):
  promo_banner.png   1280x640  - hero/marketing banner
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = "C:\\Windows\\Fonts"

# Brand palette
BG_TOP   = (14, 26, 20)
BG_BOT   = (6, 11, 9)
GREEN    = (70, 224, 106)
GREEN_DK = (38, 110, 60)
AMBER    = (255, 200, 60)
WHITE    = (236, 244, 238)
GRAY     = (150, 168, 156)
GRIDLINE = (70, 110, 86, 70)

def font(name, size):
    for cand in (name, "bahnschrift.ttf", "segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join(FONTS, cand), size)
        except Exception:
            continue
    return ImageFont.load_default()

def vgradient(w, h, top, bot):
    base = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(base)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return base

def main():
    W, H = 1280, 640
    img = vgradient(W, H, BG_TOP, BG_BOT).convert("RGBA")
    d = ImageDraw.Draw(img)

    # Faint map grid across the whole banner
    step = 64
    for x in range(0, W, step):
        d.line([(x, 0), (x, H)], fill=GRIDLINE, width=1)
    for y in range(0, H, step):
        d.line([(0, y), (W, y)], fill=GRIDLINE, width=1)

    # --- Right side: big reticle motif on a grid intersection ---
    cx, cy = 960, 320
    rad = 165
    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=GREEN, width=10)
    gap, tick, lw = 55, 70, 10
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        rd.line([(cx + dx * gap, cy + dy * gap),
                 (cx + dx * (rad + tick), cy + dy * (rad + tick))], fill=GREEN, width=lw)
    # soft glow
    glow = ring.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(glow)
    img.alpha_composite(ring)
    # amber located dot on a grid intersection inside the reticle
    ox, oy, dr = cx + 70, cy - 60, 18
    d.ellipse([ox - dr, oy - dr, ox + dr, oy + dr], fill=AMBER)

    # --- Left side: wordmark + tagline + MGRS readout + feature chips ---
    title = font("bahnschrift.ttf", 132)
    d.text((70, 120), "GRIDRECON", font=title, fill=WHITE)
    # green underline accent
    d.rectangle([74, 268, 74 + 360, 276], fill=GREEN)

    tag = font("bahnschrift.ttf", 40)
    d.text((74, 300), "Land navigation when GPS goes dark", font=tag, fill=GRAY)

    # MGRS readout in mono, like the watch shows
    mono = font("consola.ttf", 46)
    d.text((74, 372), "YOU ARE AT", font=font("bahnschrift.ttf", 26), fill=GREEN_DK)
    d.text((74, 402), "18T WL 80735 04700", font=mono, fill=GREEN)

    # Feature chips
    chip = font("bahnschrift.ttf", 26)
    chips = ["Target location", "Resection", "Dead reckoning"]
    x = 74
    for c in chips:
        w = d.textlength(c, font=chip)
        d.rounded_rectangle([x, 486, x + w + 36, 532], radius=23, outline=GREEN_DK, width=2)
        d.text((x + 18, 494), c, font=chip, fill=WHITE)
        x += w + 36 + 16

    # Device-family line
    d.text((74, 556), "fenix  ·  tactix  ·  epix  ·  Forerunner  ·  Instinct",
           font=font("bahnschrift.ttf", 24), fill=GRAY)

    # App icon badge, top-right corner
    try:
        icon = Image.open(os.path.join(HERE, "assets", "icon_1024.png")).convert("RGBA").resize((108, 108), Image.LANCZOS)
        img.alpha_composite(icon, (W - 108 - 48, 44))
    except Exception:
        pass

    out = os.path.join(HERE, "assets", "promo_banner.png")
    img.convert("RGB").save(out)
    print("wrote", out)

if __name__ == "__main__":
    main()
