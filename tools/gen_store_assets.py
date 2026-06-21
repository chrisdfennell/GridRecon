"""Generate Connect IQ Store images for GridRecon, to the store's exact specs.

Outputs (in assets/):
  cover_image.png         500x500   RGB,  < 300 KB   (Web/Mobile cover)
  device_icon_24bit.png   128x128   RGB (24-bit full colour)   device store icon
  device_icon_64color.png 128x128   <= 64 colours              device store icon

Each file is verified against its spec at the end and the script fails loudly if
any constraint (dimensions / colour count / byte size) is not met.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(HERE, "assets")
FONTS = "C:\\Windows\\Fonts"

# Brand palette
BG_TOP   = (14, 26, 20)
BG_BOT   = (6, 11, 9)
TILE     = (16, 30, 23)
GREEN    = (70, 224, 106)
GREEN_DK = (38, 110, 60)
AMBER    = (255, 200, 60)
WHITE    = (236, 244, 238)
GRAY     = (150, 168, 156)
GRID     = (44, 74, 58)        # solid faint grid line (opaque, palette-friendly)

def font(size):
    for cand in ("bahnschrift.ttf", "segoeui.ttf", "arial.ttf"):
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

def draw_reticle(img, cx, cy, rad, lw, gap, tick, dot_off=None, dot_r=0, glow=10):
    """Green ring + crosshair (with a soft glow) and an optional amber dot."""
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=GREEN, width=lw)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        rd.line([(cx + dx * gap, cy + dy * gap),
                 (cx + dx * (rad + tick), cy + dy * (rad + tick))], fill=GREEN, width=lw)
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(glow)))
    img.alpha_composite(ring)
    if dot_off is not None:
        ox, oy = cx + dot_off[0], cy + dot_off[1]
        ImageDraw.Draw(img).ellipse([ox - dot_r, oy - dot_r, ox + dot_r, oy + dot_r], fill=AMBER)

def grid_lines(d, w, h, step, width):
    for x in range(0, w + 1, step):
        d.line([(x, 0), (x, h)], fill=GRID, width=width)
    for y in range(0, h + 1, step):
        d.line([(0, y), (w, y)], fill=GRID, width=width)

# --- Cover: reticle + GRIDRECON wordmark, 500x500 (rendered 2x, downscaled) ----
def make_cover():
    W = 1000  # 2x supersample of the 500x500 target
    img = vgradient(W, W, BG_TOP, BG_BOT).convert("RGBA")
    grid_lines(ImageDraw.Draw(img), W, W, 100, 2)

    draw_reticle(img, cx=500, cy=330, rad=190, lw=22, gap=72, tick=66,
                 dot_off=(96, -84), dot_r=28, glow=14)

    d = ImageDraw.Draw(img)
    title = font(132)
    tw = d.textlength("GRIDRECON", font=title)
    d.text(((W - tw) / 2, 612), "GRIDRECON", font=title, fill=WHITE)
    # green underline accent
    d.rectangle([(W - 300) / 2, 792, (W + 300) / 2, 804], fill=GREEN)
    tag = font(40)
    tt = "Find your way back."
    ttw = d.textlength(tt, font=tag)
    d.text(((W - ttw) / 2, 822), tt, font=tag, fill=GRAY)

    cover = img.convert("RGB").resize((500, 500), Image.LANCZOS)
    out = os.path.join(ASSETS, "cover_image.png")
    cover.save(out, optimize=True)
    # If somehow over 300 KB, fall back to JPG (the form accepts it).
    if os.path.getsize(out) > 300 * 1024:
        out = os.path.join(ASSETS, "cover_image.jpg")
        cover.save(out, quality=90, optimize=True)
    return out

# --- Device store icons: full-bleed reticle tile, 128x128 ----------------------
def render_device(px):
    S = px * 4  # supersample for crisp downscale
    img = Image.new("RGBA", (S, S), TILE + (255,))
    grid_lines(ImageDraw.Draw(img), S, S, S // 4, max(1, S // 256))
    draw_reticle(img, cx=S // 2, cy=S // 2, rad=int(S * 0.30), lw=int(S * 0.045),
                 gap=int(S * 0.11), tick=int(S * 0.11),
                 dot_off=(int(S * 0.17), -int(S * 0.15)), dot_r=int(S * 0.05), glow=6)
    return img.convert("RGB").resize((px, px), Image.LANCZOS)

def make_device_icons():
    base = render_device(128)
    p24 = os.path.join(ASSETS, "device_icon_24bit.png")
    base.save(p24, optimize=True)
    p64 = os.path.join(ASSETS, "device_icon_64color.png")
    base.quantize(colors=64, method=Image.MEDIANCUT).save(p64, optimize=True)
    return p24, p64

# --- Verify everything against the store specs ---------------------------------
def colours(path):
    im = Image.open(path)
    if im.mode == "P":
        return len(im.getpalette()) // 3
    return len(im.convert("RGB").getcolors(maxcolors=1 << 24) or [None] * 99999)

def check(path, w, h, max_kb, max_colors=None):
    im = Image.open(path)
    kb = os.path.getsize(path) / 1024.0
    ok = (im.size == (w, h)) and (kb <= max_kb)
    note = "{}: {}x{}, {:.0f} KB".format(os.path.basename(path), im.size[0], im.size[1], kb)
    if max_colors is not None:
        c = colours(path)
        ok = ok and (c <= max_colors)
        note += ", {} colours (max {})".format(c, max_colors)
    print(("  OK  " if ok else " FAIL ") + note)
    return ok

def main():
    cover = make_cover()
    p24, p64 = make_device_icons()
    print("Verifying against Connect IQ Store specs:")
    allok = True
    allok &= check(cover, 500, 500, 300)
    allok &= check(p24, 128, 128, 300)
    allok &= check(p64, 128, 128, 300, max_colors=64)
    print("ALL IN SPEC" if allok else "OUT OF SPEC — fix needed")

if __name__ == "__main__":
    main()
