#!/usr/bin/env python3
"""Pinta los fondos y las pinceladas de las esferas (texturas de lienzo, pincel seco, tinta).

Uso: python3 -I tools/paint.py [carpeta_de_vista_previa]   (desde la carpeta Esferas)

Todo se pinta una vez a 908 px (2 × 454) en coordenadas de diseño de 390 px y se reduce
a cada resolución, de modo que la textura es la misma en todos los relojes.
"""
import pathlib
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[1]
N = 908
K = N / 390.0
SIZES = {390: "resources", 260: "resources-round-260x260", 280: "resources-round-280x280",
         416: "resources-round-416x416", 454: "resources-round-454x454"}

yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / K   # coordenadas de diseño (0..390)


# ---------------------------------------------------------------- ruido
def noise(cells_x, cells_y, seed, n=N):
    rng = np.random.default_rng(seed)
    small = (rng.random((cells_y, cells_x)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((n, n), Image.BICUBIC), np.float32) / 255.0


def fbm(cells, seed, octaves=4):
    out = np.zeros((N, N), np.float32)
    amp, total = 1.0, 0.0
    for i in range(octaves):
        c = cells * 2 ** i
        out += amp * noise(c, c, seed + i)
        total += amp
        amp *= 0.5
    return out / total


def streaks(seed, horizontal=True, along=26, across=190):
    """Vetas de pincel: ruido estirado en una dirección."""
    return noise(along, across, seed) if horizontal else noise(across, along, seed)


_marks_cache = {}


def brush_marks(seed, angle=0.0, spread=22.0, count=2400, length=(10, 42), width=(2.0, 7.0)):
    """Campo de tono hecho con miles de toques cortos de pincel (0..1)."""
    key = (seed, angle, spread, count)
    if key in _marks_cache:
        return _marks_cache[key]
    rng = np.random.default_rng(seed)
    m = Image.new("L", (N, N), 128)
    d = ImageDraw.Draw(m)
    for _ in range(count):
        x, y = rng.random() * 430 - 20, rng.random() * 430 - 20
        a = np.radians(angle + (rng.random() - 0.5) * 2 * spread)
        L = rng.uniform(*length)
        w = rng.uniform(*width) * K
        v = int(128 + (rng.random() - 0.5) * 2 * 110)
        d.line([(x * K, y * K), ((x + np.cos(a) * L) * K, (y + np.sin(a) * L) * K)], fill=v, width=int(w))
    out = np.asarray(m.filter(ImageFilter.GaussianBlur(1.2 * K)), np.float32) / 255.0
    _marks_cache[key] = out
    return out


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- pintura
def paint_fill(color, seed, var=0.10, streak=0.07, second=None, horizontal=True, relief=0.05):
    """Campo de color: variación de tono, toques cortos de pincel, veladuras de un segundo
    pigmento y un relieve sutil (luz rasante sobre las vetas)."""
    c = hexrgb(color)
    f = fbm(3, seed)
    s = brush_marks(seed + 50, 0.0 if horizontal else 90.0)
    dab = fbm(14, seed + 60, 2)
    img = c[None, None, :] * (1 + var * (f[..., None] - 0.5) * 2 + streak * (s[..., None] - 0.5) * 2
                              + 0.05 * (dab[..., None] - 0.5) * 2)
    if second is not None:
        mix = smooth(0.52, 0.80, fbm(3, seed + 90) + 0.25 * (s - 0.5))[..., None] * 0.5
        img = img * (1 - mix) + hexrgb(second)[None, None, :] * mix
    if relief:
        gy, gx = np.gradient(s * 255 / K)
        img = img * (1 + relief * np.clip(-(gx + gy) * 0.08, -1, 1))[..., None]
    return img


def over(base, color_img, mask):
    m = np.clip(mask, 0, 1)[..., None]
    return base * (1 - m) + color_img * m


def rect_mask(x0, y0, x1, y1, seed, rough=9.0, soft=2.0, dry=1.0):
    """Rectángulo pintado: bordes desplazados por ruido y deshilachados en dirección del pincel."""
    d = (fbm(4, seed) - 0.5) * 2 * rough
    sh = (brush_marks(seed + 7, 0.0, 15, 1600) - 0.5) * 2 * rough * dry
    sv = (brush_marks(seed + 8, 90.0, 15, 1600) - 0.5) * 2 * rough * dry
    top = smooth(y0 - soft, y0 + soft, yy + d + sh)
    bot = 1 - smooth(y1 - soft, y1 + soft, yy + d - sh)
    left = smooth(x0 - soft, x0 + soft, xx + d + sv)
    right = 1 - smooth(x1 - soft, x1 + soft, xx + d - sv)
    return top * bot * left * right


def spline(pts, closed=True, steps=24):
    out, n = [], len(pts)
    last = n if closed else n - 1
    for i in range(last):
        g = (lambda j: pts[j % n]) if closed else (lambda j: pts[max(0, min(n - 1, j))])
        p0, p1, p2, p3 = g(i - 1), g(i), g(i + 1), g(i + 2)
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * (2 * p1[j] + (p2[j] - p0[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (3 * p1[j] - p0[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    if not closed:
        out.append(tuple(pts[-1]))
    return out


def shape_mask(pts, seed, rough=0.30, blur=3.5):
    """Forma orgánica con borde de pintura roto."""
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon([(x * K, y * K) for x, y in spline(pts)], fill=255)
    m = np.asarray(m.filter(ImageFilter.GaussianBlur(blur * K)), np.float32) / 255.0
    edge = m + rough * (fbm(8, seed) - 0.5) + 0.30 * (brush_marks(seed + 3, 0.0, 40, 1600) - 0.5)
    return smooth(0.44, 0.56, edge)


def ink_line(img, pts, seed, width=1.6, color="#120A0A"):
    """Línea de tinta a mano: grosor variable a lo largo del trazo."""
    rng = np.random.default_rng(seed)
    path = spline(pts, closed=False, steps=60)
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    phase = rng.random() * 6
    for i, (x, y) in enumerate(path):
        w = width * (0.75 + 0.35 * np.sin(i / 23 + phase) + 0.1 * rng.random()) * K
        d.ellipse((x * K - w, y * K - w, x * K + w, y * K + w), fill=255)
    m = np.asarray(m.filter(ImageFilter.GaussianBlur(0.6 * K)), np.float32) / 255.0
    return over(img, hexrgb(color)[None, None, :], m * 0.92)


def canvas(img, strength=0.05, seed=1):
    """Grano de lienzo: trama fina + ruido."""
    weave = np.sin(xx * K * 1.9) * np.sin(yy * K * 1.9)
    grain = noise(N // 2, N // 2, seed) - 0.5
    return img * (1 + strength * (0.6 * weave + 1.2 * grain)[..., None])


def vignette(img, amount=0.18):
    r = np.sqrt((xx - 195) ** 2 + (yy - 195) ** 2) / 195
    return img * (1 - amount * smooth(0.55, 1.05, r))[..., None]


def to_image(img):
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- fondos
def bg_campos():
    img = paint_fill("#B4461F", 10, var=0.12, second="#C8642B")              # imprimación óxido
    img = over(img, paint_fill("#1C2640", 20, var=0.14, second="#24304F"),
               rect_mask(26, -40, 430, 214, 21, rough=8))                      # azul noche
    img = over(img, paint_fill("#1A2238", 25, var=0.10), rect_mask(-40, -40, 34, 226, 26, rough=5) * 0.55)
    img = over(img, paint_fill("#BE4A1E", 30, var=0.12, second="#D0602A"),
               rect_mask(-40, 236, 430, 296, 31, rough=6))                     # banda óxido
    img = over(img, paint_fill("#E8D9BB", 40, var=0.08, streak=0.05, second="#D9C49C"),
               rect_mask(56, 306, 368, 430, 41, rough=7))                      # bloque crema
    img = over(img, paint_fill("#2A1712", 45, var=0.1), rect_mask(-40, 214, 430, 238, 46, rough=4) * 0.35)
    return to_image(vignette(canvas(img, 0.06, 2), 0.22))


def bg_organica():
    img = paint_fill("#5C1825", 50, var=0.12, second="#6B2130")
    img = over(img, paint_fill("#4B111D", 51, var=0.08), rect_mask(60, 70, 332, 252, 52, rough=8) * 0.75)
    for pts, col, sd in [
        ([(-40, -40), (122, -40), (112, 26), (62, 90), (-40, 124)], "#8B8A58", 60),
        ([(-40, 160), (40, 150), (64, 215), (40, 262), (-40, 270)], "#7A5268", 61),
        ([(-40, 278), (70, 266), (176, 286), (196, 350), (160, 430), (-40, 430)], "#222B42", 62),
        ([(346, 96), (430, 70), (430, 262), (372, 250), (338, 180)], "#C2571F", 63),
        ([(210, 280), (300, 264), (430, 286), (430, 430), (196, 430), (192, 338)], "#E5D5B6", 64),
        ([(170, 372), (226, 352), (264, 430), (146, 430)], "#B04A1C", 65),
    ]:
        img = over(img, paint_fill(col, sd, var=0.12, second=None), shape_mask(pts, sd + 1))
    img = ink_line(img, [(104, -10), (78, 64), (30, 150), (46, 230), (22, 300)], 70)
    img = ink_line(img, [(430, 258), (370, 268), (330, 326), (300, 372), (284, 430)], 71)
    return to_image(vignette(canvas(img, 0.06, 3), 0.2))


def bg_trazos():
    img = hexrgb("#EFE7D7")[None, None, :] * (1 + 0.035 * (fbm(5, 80) - 0.5)[..., None] * 2)
    specks = smooth(0.93, 0.99, noise(N // 3, N // 3, 81))
    img = img * (1 - 0.06 * specks[..., None])                                 # fibras del papel
    hill = shape_mask([(200, 300), (262, 262), (338, 246), (430, 258), (430, 430), (212, 430)], 82, rough=0.15, blur=4)
    rim = np.clip(hill - smooth(0.5, 0.95, np.asarray(Image.fromarray((hill * 255).astype(np.uint8))
                  .filter(ImageFilter.GaussianBlur(5 * K)), np.float32) / 255.0), 0, 1)
    img = over(img, paint_fill("#D9CAA9", 83, var=0.10, streak=0.03), hill * 0.9)
    img = img * (1 - 0.10 * rim[..., None])                                    # borde de acuarela
    return to_image(vignette(canvas(img, 0.035, 4), 0.10))


# ---------------------------------------------------------------- pinceladas
def brush_stroke(seed, color, width=19.0, length=134.0, tip=16.0):
    """Pincelada vertical cerda a cerda (pincel seco). Devuelve RGBA a 908 px de escala."""
    rng = np.random.default_rng(seed)
    w = int(width * K) + 8
    h = int(length * K) + 12
    alpha = np.zeros((h, w), np.float32)
    rgb = np.zeros((h, w, 3), np.float32)
    base = hexrgb(color)
    nb = 46
    lean = (rng.random() - 0.5) * 3 * K
    for i in range(nb):
        x0 = 4 + (i + rng.random() * 0.8) / nb * width * K
        thick = (0.9 + rng.random() * 1.1) * K * 0.7
        edge = abs((i + 0.5) / nb - 0.5) * 2                    # 0 en el centro, 1 en el borde
        start = 6 + (edge ** 2) * 0.07 * h + rng.random() * 0.025 * h   # punta redondeada
        end = h - 6 - rng.random() * 0.08 * h                  # base deshilachada
        load = 0.85 + 0.15 * rng.random()
        shade = base * (0.86 + 0.24 * rng.random())
        gaps = noise(1, 40, seed * 100 + i, n=h)[:, 0]
        for y in range(int(start), int(end)):
            t = (y - start) / max(1, end - start)
            a = load * smooth(0.0, 0.04, t) * (1 - 0.5 * smooth(0.75, 1.0, t))
            dry = 0.55 * smooth(0.62, 1.0, t) + 0.25 * (1 - smooth(0.0, 0.07, t)) + 0.12 * edge
            a *= smooth(0.10, 0.30, gaps[y] + 0.35 - dry)       # pincel seco solo en los extremos
            if a <= 0.01:
                continue
            x = x0 + lean * (1 - t)
            xi, xf = int(x), x - int(x)
            for dx in range(int(np.ceil(thick)) + 1):
                cov = min(1, max(0, thick - dx)) * (1 - xf if dx == 0 else 1)
                px = xi + dx
                if 0 <= px < w and cov > 0:
                    na = a * cov
                    alpha[y, px] = alpha[y, px] + na * (1 - alpha[y, px])
                    rgb[y, px] = shade
    img = np.dstack([rgb, alpha])
    return img


def stroke_sprites(variant, color, out_dir, side, preview=None):
    full = brush_stroke(200 + variant, color)
    s = side / N
    h_full = full.shape[0]
    im = Image.fromarray((np.clip(full, 0, 1) * 255).astype(np.uint8), "RGBA")
    W = max(1, round(im.width * s))
    H = max(1, round(h_full * s))
    small = im.resize((W, H), Image.LANCZOS)
    tip_h = max(4, round(22 * K * s))
    small.save(out_dir / f"stroke{variant}.png")
    small.crop((0, 0, W, tip_h)).save(out_dir / f"tip{variant}.png")
    return W, H, tip_h


def main():
    preview = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
    bgs = {"campos": bg_campos(), "organica": bg_organica(), "trazos": bg_trazos()}
    colors = ["#22389E", "#1F3396", "#2742AA", "#20379A", "#6F86D6"]   # 4 variantes + hoy
    meta = None
    for side, folder in SIZES.items():
        d = ROOT / folder / "paint"
        d.mkdir(parents=True, exist_ok=True)
        for name, img in bgs.items():
            img.resize((side, side), Image.LANCZOS).save(d / f"bg_{name}.png")
        for v, c in enumerate(colors):
            meta = stroke_sprites(v, c, d, side)
        xml = ["<drawables>"]
        for name in bgs:
            xml.append(f'    <bitmap id="Bg{name.capitalize()}" filename="bg_{name}.png" packingFormat="jpg"/>')
        for v in range(len(colors)):
            xml.append(f'    <bitmap id="Stroke{v}" filename="stroke{v}.png"/>')
            xml.append(f'    <bitmap id="Tip{v}" filename="tip{v}.png"/>')
        xml.append("</drawables>")
        (d / "paint.xml").write_text("\n".join(xml) + "\n")
        print(folder, "pinceladas", meta)
    if preview:
        preview.mkdir(parents=True, exist_ok=True)
        for name, img in bgs.items():
            img.resize((390, 390), Image.LANCZOS).save(preview / f"bg_{name}.png")


if __name__ == "__main__":
    main()
