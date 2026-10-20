# Draws the drag-handle icon designs (green = unlocked, red = locked) as 32x32 TGAs,
# plus one comparison sheet per design set. See README.md in this folder.
# Usage: python make_icons.py <outdir>   (needs numpy and Pillow)
import sys, os, struct
import numpy as np
from PIL import Image, ImageDraw, ImageFont

N, SS = 32, 8
M = N * SS
c = (np.arange(M) + 0.5) / SS
X, Y = np.meshgrid(c, c)          # pixel units, y grows downwards
DX, DY = X - N / 2, Y - N / 2
R = np.hypot(DX, DY)

PAL = {  # dark, mid, light
    "green": (np.array([10, 70, 25]), np.array([40, 175, 60]), np.array([170, 255, 160])),
    "red":   (np.array([85, 10, 12]), np.array([200, 35, 35]), np.array([255, 165, 145])),
}
GOLD = (np.array([110, 70, 25]), np.array([245, 205, 110]))
STEEL = (np.array([70, 75, 85]), np.array([225, 230, 240]))
OUTLINE = np.array([22, 16, 10])

def blank():
    return np.zeros((M, M, 4))

def paint(img, mask, rgb, alpha=1.0):
    """Composite rgb (array HxWx3 or 3) over img where mask (bool or 0..1)."""
    a = (mask.astype(float) * alpha)[..., None]
    rgb = np.broadcast_to(np.asarray(rgb, float), img[..., :3].shape)
    img[..., :3] = rgb * a + img[..., :3] * (1 - a)
    img[..., 3:] = a + img[..., 3:] * (1 - a)

def lerp(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a + (b - a) * t

def lit(t_from_topleft_radius):
    return np.clip(0.5 + (-DX - DY) / (2 * t_from_topleft_radius) * 0.9, 0, 1)

def dome(img, pal, rg):
    dark, mid, light = pal
    inside = R <= rg
    nz = np.sqrt(np.clip(1 - (R / rg) ** 2, 0, 1))
    diff = np.clip((DX / rg) * -0.5 + (DY / rg) * -0.6 + nz * 0.62, 0, 1)
    col = np.where((diff < 0.75)[..., None], lerp(dark, mid, diff / 0.75), lerp(mid, light, (diff - 0.75) / 0.25))
    glow = np.clip(1 - np.hypot(DX - rg * 0.22, DY - rg * 0.4) / (rg * 0.62), 0, 1) * 0.45
    col = lerp(col, light, glow)
    hl = np.clip(1 - np.hypot((DX + rg * 0.37) / (rg * 0.32), (DY + rg * 0.41) / (rg * 0.21)), 0, 1) ** 1.5
    col = lerp(col, np.array([255, 255, 255]), hl * 0.95)
    paint(img, inside, col)

def ring(img, r_out, r_in, metal):
    paint(img, (R <= r_out) & (R > r_in), lerp(metal[0], metal[1], lit(r_out)))
    paint(img, (R > r_in) & (R <= r_in + 0.7), np.array([40, 25, 10]), 0.7)

def outline(img, r):
    paint(img, R <= r, OUTLINE)

# ---------------------------------------------------------------- variants
def v_domed_gold(p):
    img = blank(); outline(img, 15.2); ring(img, 14.0, 11.2, GOLD); dome(img, p, 11.2); return img

def v_domed_steel(p):
    img = blank(); outline(img, 15.2); ring(img, 14.0, 11.2, STEEL); dome(img, p, 11.2); return img

def v_domed_thin_ring(p):
    img = blank(); outline(img, 15.2); ring(img, 14.2, 12.6, GOLD); dome(img, p, 12.6); return img

def v_domed_no_ring(p):
    img = blank(); outline(img, 15.0); dome(img, p, 13.8); return img

def v_glossy(p):
    # vertical gradient button with a glassy highlight on the top half
    dark, mid, light = p
    img = blank(); outline(img, 15.0)
    t = (Y - 2) / 28
    paint(img, R <= 13.8, lerp(light * 0.55 + mid * 0.45, dark, t * 1.1))
    gloss = (np.hypot(DX / 11.0, (DY + 5.0) / 7.0) <= 1) & (R <= 13.0)
    paint(img, gloss, lerp(np.array([255, 255, 255]), mid, (Y - 3) / 9), 0.55)
    return img

def v_semiflat(p):
    # flat colour, darker lower half, small white highlight
    dark, mid, light = p
    img = blank(); outline(img, 15.0)
    paint(img, R <= 13.8, mid)
    paint(img, (R <= 13.8) & (DY > 0) & (np.hypot(DX, DY + 6) > 15.5), dark * 0.6 + mid * 0.4, 0.55)
    paint(img, np.hypot(DX + 5, DY + 5) <= 2.6, np.array([255, 255, 255]), 0.85)
    return img

def v_led(p):
    # dark metal socket with a glowing light
    dark, mid, light = p
    img = blank(); outline(img, 15.2)
    paint(img, R <= 14.0, lerp(np.array([45, 45, 50]), np.array([150, 150, 160]), 1 - lit(14.0)))
    paint(img, R <= 11.5, np.array([25, 25, 28]))
    core = np.clip(R / 10.5, 0, 1)
    paint(img, R <= 10.5, lerp(lerp(light, mid, core * 1.6), dark, (core - 0.6) * 2.5))
    paint(img, np.hypot(DX + 3.5, DY + 4) <= 2.2, np.array([255, 255, 255]), 0.6)
    return img

def v_faceted(p):
    # brilliant-cut look: table in the middle, alternating facets around it
    dark, mid, light = p
    img = blank(); outline(img, 15.2); ring(img, 14.0, 11.2, GOLD)
    ang = np.arctan2(DY, DX)
    k = np.floor((ang + np.pi) / (2 * np.pi / 8)).astype(int)
    base = np.where((k % 2 == 0)[..., None], mid, dark * 0.5 + mid * 0.5)
    light_dir = np.clip(np.cos(ang - (-2.4)) * 0.5 + 0.5, 0, 1)
    col = lerp(base, light, light_dir * 0.5)
    paint(img, R <= 11.2, col)
    oct_r = 6.2 / np.cos((ang % (np.pi / 4)) - np.pi / 8)
    paint(img, R <= oct_r, lerp(mid, light, 0.35))
    paint(img, np.hypot(DX + 2.5, DY + 2.8) <= 1.6, np.array([255, 255, 255]), 0.9)
    return img

def v_padlock(p, locked):
    # padlock: coloured body, silver shackle; open (raised, swung) when unlocked
    dark, mid, light = p
    img = blank()
    body = (np.abs(DX) <= 9.5) & (Y >= 14) & (Y <= 29.5)
    lift = 0 if locked else 4.5
    cx, cy = N / 2, 14 - lift
    sr = np.hypot(X - cx, Y - cy)
    arc = (sr <= 7.8) & (sr >= 4.2) & (Y <= cy)
    leg_l = (np.abs(X - (cx - 6)) <= 1.8) & (Y > cy) & (Y <= 15)
    leg_r = (np.abs(X - (cx + 6)) <= 1.8) & (Y > cy) & (Y <= (15 if locked else cy + 2.5))
    shackle = arc | leg_l | leg_r
    grow = lambda m, d: np.maximum.reduce([np.roll(np.roll(m, i, 0), j, 1) for i in (-d, 0, d) for j in (-d, 0, d)])
    paint(img, grow(shackle | body, 10), OUTLINE)
    paint(img, shackle, lerp(STEEL[0], STEEL[1], 1 - (X - cx + 8) / 16))
    paint(img, body, lerp(light * 0.4 + mid * 0.6, dark, (Y - 14) / 16))
    key = (np.hypot(DX, Y - 20) <= 2.2) | ((np.abs(DX) <= 0.9) & (Y >= 20) & (Y <= 25.5))
    paint(img, key, OUTLINE)
    return img

# ---- semi-flat fills inside a ring (set 2): less dome than A-C, more depth than flat
def soft_gradient(img, p, rg):
    # straight top-to-bottom gradient, no sphere shading, small highlight
    dark, mid, light = p
    t = (DY + rg) / (2 * rg)
    paint(img, R <= rg, lerp(light * 0.35 + mid * 0.65, dark * 0.45 + mid * 0.55, t))
    paint(img, np.hypot(DX + rg * 0.38, DY + rg * 0.42) <= rg * 0.17, np.array([255, 255, 255]), 0.8)

def two_tone(img, p, rg):
    # flat fill with a darker lower crescent and a highlight dot
    dark, mid, light = p
    paint(img, R <= rg, mid)
    paint(img, (R <= rg) & (np.hypot(DX, DY + rg * 0.45) > rg * 1.12), dark * 0.6 + mid * 0.4, 0.6)
    paint(img, np.hypot(DX + rg * 0.38, DY + rg * 0.4) <= rg * 0.2, np.array([255, 255, 255]), 0.85)

def recessed(img, p, rg):
    # flat fill with an inner shadow along the top edge, as if set into the ring
    dark, mid, light = p
    paint(img, R <= rg, lerp(mid, light, 0.1))
    # soft inner shadow, strongest along the top edge
    d = np.hypot(DX, DY - rg * 0.35)
    shadow = np.clip((d - rg * 0.75) / (rg * 0.45), 0, 1) * (R <= rg) * (DY < rg * 0.3)
    paint(img, shadow, dark * 0.5, 0.85)
    paint(img, (R <= rg) & (np.hypot(DX, DY + rg * 0.3) > rg * 1.1) & (DY > 0), lerp(mid, light, 0.7), 0.6)
    paint(img, np.hypot(DX + rg * 0.3, DY + rg * 0.25) <= rg * 0.15, np.array([255, 255, 255]), 0.7)

def glass_band(img, p, rg):
    # soft fill with a toned-down glass band over the top half
    dark, mid, light = p
    paint(img, R <= rg, lerp(mid, dark * 0.5 + mid * 0.5, (DY + rg) / (2 * rg)))
    band = (np.hypot(DX / (rg * 0.78), (DY + rg * 0.38) / (rg * 0.5)) <= 1)
    paint(img, band & (R <= rg), lerp(np.array([255, 255, 255]), mid, (DY + rg) / rg), 0.4)

def socket(img):
    paint(img, R <= 14.0, lerp(np.array([45, 45, 50]), np.array([150, 150, 160]), 1 - lit(14.0)))
    paint(img, R <= 11.5, np.array([25, 25, 28]))

def v_soft_gold(p):
    img = blank(); outline(img, 15.2); ring(img, 14.0, 11.2, GOLD); soft_gradient(img, p, 11.2); return img

def v_soft_steel(p):
    img = blank(); outline(img, 15.2); ring(img, 14.0, 11.2, STEEL); soft_gradient(img, p, 11.2); return img

def v_twotone_gold(p):
    img = blank(); outline(img, 15.2); ring(img, 14.2, 12.6, GOLD); two_tone(img, p, 12.6); return img

def v_recessed_steel(p):
    img = blank(); outline(img, 15.2); ring(img, 14.0, 11.2, STEEL); recessed(img, p, 11.2); return img

def v_glass_socket(p):
    img = blank(); outline(img, 15.2); socket(img); glass_band(img, p, 10.5); return img

# Two rounds of designs. Set 2 kept A, B, C and G from set 1 and replaced the rest.
SETS = {
    "set1": [
        ("A", "Domed, gold ring", v_domed_gold),
        ("B", "Domed, steel ring", v_domed_steel),
        ("C", "Domed, thin gold ring", v_domed_thin_ring),
        ("D", "Domed, no ring", v_domed_no_ring),
        ("E", "Glossy button", v_glossy),
        ("F", "Semi-flat with highlight", v_semiflat),
        ("G", "LED in metal socket", v_led),
        ("H", "Faceted, gold ring", v_faceted),
        ("I", "Padlock (open / closed)", v_padlock),
    ],
    "set2": [
        ("A", "Domed, gold ring", v_domed_gold),
        ("B", "Domed, steel ring", v_domed_steel),
        ("C", "Domed, thin gold ring", v_domed_thin_ring),
        ("D", "Soft gradient, gold ring", v_soft_gold),
        ("E", "Soft gradient, steel ring", v_soft_steel),
        ("F", "Two-tone, thin gold ring", v_twotone_gold),
        ("G", "LED in metal socket", v_led),
        ("H", "Recessed, steel ring", v_recessed_steel),
        ("I", "Glass band, metal socket (in use)", v_glass_socket),
    ],
}

# ---------------------------------------------------------------- output
def downsample(img):
    a = img[..., 3:]
    pre = np.concatenate([img[..., :3] * a, a], -1)
    pre = pre.reshape(N, SS, N, SS, 4).mean((1, 3))
    rgb = np.where(pre[..., 3:] > 0, pre[..., :3] / np.maximum(pre[..., 3:], 1e-9), 0)
    return np.concatenate([rgb, pre[..., 3:] * 255], -1).round().clip(0, 255).astype(np.uint8)

def write_tga(px, path):
    hdr = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 8)
    bgra = px[::-1][..., [2, 1, 0, 3]]           # bottom-left origin, BGRA
    with open(path, 'wb') as f:
        f.write(hdr + bgra.tobytes())

def render_set(outdir, variants):
    rows = []
    for key, label, fn in variants:
        d = os.path.join(outdir, key)
        os.makedirs(d, exist_ok=True)
        imgs = {}
        for name, colour, locked in (("draghandle", "green", False), ("draghandle-checked", "red", True)):
            raw = fn(PAL[colour], locked) if fn is v_padlock else fn(PAL[colour])
            px = downsample(raw)
            write_tga(px, os.path.join(d, name + ".tga"))
            imgs[colour] = Image.fromarray(px, "RGBA")
        rows.append((key, label, imgs))

    # sheet: per row, label + [16px, 24px, 32px, 128px] for green and red, on two backgrounds
    font = ImageFont.load_default(size=16) if hasattr(ImageFont, "load_default") else None
    sizes = [16, 24, 32, 128]
    rowh, labelw, pad = 140, 300, 14
    cellw = sum(sizes) + pad * (len(sizes) + 1)
    W = labelw + cellw * 2 * 2 + pad
    sheet = Image.new("RGB", (W, rowh * len(rows) + 50), (235, 235, 235))
    dr = ImageDraw.Draw(sheet)
    x0 = labelw
    for bi, bg in enumerate([(24, 24, 26), (95, 110, 85)]):
        for ci, colour in enumerate(("green", "red")):
            dr.text((x0 + pad, 14), f"{'dark' if bi == 0 else 'world'} bg - {colour}", fill=(30, 30, 30), font=font)
            x0 += cellw
    for i, (key, label, imgs) in enumerate(rows):
        y = 50 + i * rowh
        dr.text((pad, y + rowh // 2 - 10), f"{key}  {label}", fill=(20, 20, 20), font=font)
        x = labelw
        for bg in [(24, 24, 26), (95, 110, 85)]:
            for colour in ("green", "red"):
                dr.rectangle([x, y + 4, x + cellw - 4, y + rowh - 6], fill=bg)
                cx = x + pad
                for s in sizes:
                    im = imgs[colour].resize((s, s), Image.NEAREST if s > 32 else Image.LANCZOS)
                    sheet.paste(im, (cx, y + (rowh - s) // 2), im)
                    cx += s + pad
                x += cellw
    sheet.save(os.path.join(outdir, "sheet.png"))
    print("wrote", os.path.join(outdir, "sheet.png"))

for name, variants in SETS.items():
    render_set(os.path.join(sys.argv[1], name), variants)
