import sys
from PIL import Image, ImageDraw
OUT = sys.argv[1]
S = 4096
INK2, INK = (0x17, 0x1E, 0x28), (0x0A, 0x0E, 0x13)
M0, M1 = (0x6B, 0xF5, 0xC8), (0x1C, 0xB5, 0x8C)
WHITE = (0xF4, 0xF6, 0xF8)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def bg():
    im = Image.new("RGB", (S, S)); d = ImageDraw.Draw(im)
    for y in range(S): d.line([(0, y), (S, y)], fill=lerp(INK2, INK, y / S))
    return im.convert("RGBA")

def fill(mask, c0, c1, y0=900, y1=3300):
    g = Image.new("RGB", (S, S)); d = ImageDraw.Draw(g)
    for y in range(S): d.line([(0, y), (S, y)], fill=lerp(c0, c1, min(max((y - y0) / (y1 - y0), 0), 1)))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0)); layer.paste(g, (0, 0), mask); return layer

def solid(mask, color):
    layer = Image.new("RGBA", (S, S), color + (0,)); layer.putalpha(mask); return layer

# Geometry: the stem of the P is a solid vial (cap, neck, body) as thick as
# the bowl's stroke; the bowl starts at the vial's right edge.
SX0, SX1 = 1304, 1804            # vial body x (500 wide)
TOP, BOT = 1300, 3260            # vial body y
CAP = (1254, 860, 1854, 1100)    # crimp cap, a bit wider than the body
NECK = (1374, 1100, 1734, 1300)  # neck
R_OUT, R_IN = 740, 300           # bowl radii: stroke 440 ~ vial width
CY = TOP + R_OUT - 160           # bowl centre y (bowl top a little above body top)
BX = SX1 + 300                   # bowl centre x

def bowl_mask():
    m = Image.new("L", (S, S), 0); d = ImageDraw.Draw(m)
    d.rectangle([SX1 - 60, CY - R_OUT, BX, CY + R_OUT], fill=255)
    d.ellipse([BX - R_OUT, CY - R_OUT, BX + R_OUT, CY + R_OUT], fill=255)
    d.rectangle([SX1 - 60, CY - R_IN, BX, CY + R_IN], fill=0)
    d.ellipse([BX - R_IN, CY - R_IN, BX + R_IN, CY + R_IN], fill=0)
    d.rectangle([0, 0, SX1 - 60, S], fill=0)   # nothing left of the vial edge
    return m

def vial(im, color, liquid, level=0.5, tick=INK):
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(CAP, 80, fill=color)
    d.rectangle(NECK, fill=color)
    d.rounded_rectangle([SX0, TOP, SX1, BOT], 170, fill=color)
    # dark line between cap and neck (the crimp)
    d.rectangle([NECK[0], CAP[3] - 6, NECK[2], CAP[3] + 34], fill=INK)
    ly = int(TOP + (BOT - TOP) * level)
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([SX0 + 90, ly, SX1 - 90, BOT - 90], 110, fill=255)
    if liquid:
        im.alpha_composite(liquid(m))
    for i, y in enumerate(range(TOP + 260, BOT - 200, 220)):
        w = 200 if i % 2 == 0 else 120
        d.rounded_rectangle([SX0 + 130, y - 24, SX0 + 130 + w, y + 24], 24, fill=tick)

def variant_a():  # white vial + mint liquid, mint bowl
    im = bg()
    im.alpha_composite(fill(bowl_mask(), M0, M1))
    vial(im, WHITE, lambda m: fill(m, M0, M1))
    return im

def variant_b():  # all mint, ink ticks
    im = bg()
    im.alpha_composite(fill(bowl_mask(), M0, M1))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    vial(layer, M0, None)
    mask = layer.split()[3]
    im.alpha_composite(fill(mask, M0, M1))
    vial_ticks = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(vial_ticks)
    d.rectangle([NECK[0], CAP[3] - 6, NECK[2], CAP[3] + 34], fill=INK)
    for i, y in enumerate(range(TOP + 260, BOT - 200, 220)):
        w = 200 if i % 2 == 0 else 120
        d.rounded_rectangle([SX0 + 130, y - 24, SX0 + 130 + w, y + 24], 24, fill=INK)
    im.alpha_composite(vial_ticks)
    return im

def variant_c():  # white P, mint only in the liquid (accent = the dose)
    im = bg()
    im.alpha_composite(solid(bowl_mask(), WHITE))
    vial(im, WHITE, lambda m: fill(m, M0, M1))
    return im

variants = [("A · flacon blanc, boucle menthe", variant_a()),
            ("B · tout menthe", variant_b()),
            ("C · blanc, menthe = la dose", variant_c())]

def rounded(im, size):
    t = im.convert("RGB").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], int(size * 0.225), fill=255)
    return t, mask

W, H = 3 * 460 + 60, 720
sheet = Image.new("RGB", (W, H), (242, 242, 247)); d = ImageDraw.Draw(sheet)
# home-screen strip on a dark wallpaper
strip = Image.new("RGB", (W, 180), (40, 44, 52))
for n, (name, im) in enumerate(variants):
    x = 40 + n * 460
    big, m = rounded(im, 400); sheet.paste(big, (x, 30), m)
    d.text((x, 445), name, fill=(25, 25, 25))
    for k, size in enumerate((120, 60, 40)):
        t, mk = rounded(im, size); strip.paste(t, (x + k * 150, 90 - size // 2), mk)
    im.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(OUT.replace(".png", f"_{'abc'[n]}.png"))
sheet.paste(strip, (0, 500))
d.text((40, 690), "En bas : taille ecran d'accueil (120 / 60 / 40 px) sur fond sombre", fill=(25, 25, 25))
sheet.save(OUT); print("ok")
