import sys
from PIL import Image, ImageDraw
S = 4096  # supersampled, downscaled to 1024
NAVY = (0x12, 0x39, 0x5B); NAVY_LIGHT = (0x1D, 0x50, 0x7A)
G0 = (0xF5, 0xA3, 0x53); G1 = (0xF0, 0x56, 0x6A); WHITE = (255, 255, 255)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# Background: subtle diagonal navy gradient
bg = Image.new("RGB", (S, S))
px = bg.load()
for y in range(S):
    c = lerp(NAVY_LIGHT, NAVY, y / S)
    for x in range(0, S):
        pass
    ImageDraw.Draw(bg).line([(0, y), (S, y)], fill=c)

# Syringe drawn upright on its own layer, then rotated
L = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(L)
cx = S // 2
bw, top, bottom = 760, 1150, 3000          # barrel width, top, bottom
r = 150
# liquid (gradient) in lower part of barrel
liquid_top = 2050
grad = Image.new("RGBA", (bw, bottom - liquid_top))
gd = ImageDraw.Draw(grad)
for i in range(bottom - liquid_top):
    gd.line([(0, i), (bw, i)], fill=lerp(G0, G1, i / (bottom - liquid_top)) + (255,))
mask = Image.new("L", (bw, bottom - liquid_top), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, -r, bw - 1, bottom - liquid_top - 1], r, fill=255)
L.paste(grad, (cx - bw // 2, liquid_top), mask)
# barrel outline
d.rounded_rectangle([cx - bw // 2, top, cx + bw // 2, bottom], r, outline=WHITE, width=120)
# tick marks on the left side
for i, y in enumerate(range(top + 260, bottom - 150, 210)):
    w = 300 if i % 2 == 0 else 190
    d.rounded_rectangle([cx - bw // 2 + 60, y - 30, cx - bw // 2 + 60 + w, y + 30], 30, fill=WHITE)
# rubber stopper (white bar at liquid top)
d.rounded_rectangle([cx - bw // 2 + 60, liquid_top - 90, cx + bw // 2 - 60, liquid_top + 40], 50, fill=WHITE)
# plunger rod and thumb rest
d.rounded_rectangle([cx - 80, 520, cx + 80, top + 40], 60, fill=WHITE)
d.rounded_rectangle([cx - 430, 440, cx + 430, 600], 80, fill=WHITE)
# flange
d.rounded_rectangle([cx - bw // 2 - 230, top - 40, cx + bw // 2 + 230, top + 110], 75, fill=WHITE)
# hub and needle
d.rounded_rectangle([cx - 170, bottom - 40, cx + 170, bottom + 220], 70, fill=WHITE)
d.polygon([(cx - 45, bottom + 200), (cx + 45, bottom + 200), (cx, bottom + 820)], fill=WHITE)

L = L.rotate(-40, resample=Image.BICUBIC, center=(cx, S // 2 + 120))
bg.paste(L, (-170, 20), L)
bg.resize((1024, 1024), Image.LANCZOS).save(sys.argv[1])
