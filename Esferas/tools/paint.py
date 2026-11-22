#!/usr/bin/env python3
"""Pinta las obras de las esferas: Cinta (verde y ámbar), Bloques, Retícula y Collage.

Uso: python3 -I tools/paint.py [carpeta_de_vista_previa]   (desde la carpeta Esferas)

Todo se pinta a 908 px (2 × 454) en coordenadas de diseño de 390 px y se reduce a cada
resolución de reloj: la obra es la misma en todos los modelos.
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
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / K


# ------------------------------------------------------------------ utilidades
def noise(cx, cy, seed, n=N):
    rng = np.random.default_rng(seed)
    small = (rng.random((cy, cx)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((n, n), Image.BICUBIC), np.float32) / 255.0


def fbm(cells, seed, octaves=4):
    out, amp, tot = np.zeros((N, N), np.float32), 1.0, 0.0
    for i in range(octaves):
        out += amp * noise(cells * 2 ** i, cells * 2 ** i, seed + i)
        tot += amp
        amp *= 0.5
    return out / tot


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def over(base, color, mask):
    m = np.clip(mask, 0, 1)[..., None]
    return base * (1 - m) + color * m


def solid(color):
    return np.broadcast_to(hexrgb(color), (N, N, 3)).copy()


def linen(img, strength=0.10, seed=1):
    """Lino: hilos horizontales y verticales irregulares + nudos (slubs)."""
    th = noise(N // 9, N // 2, seed)        # hilos horizontales (variación a lo largo de y)
    tv = noise(N // 2, N // 9, seed + 1)    # hilos verticales
    weave = 0.5 * (th + tv) + 0.25 * np.sin(xx * K * 1.6) * np.sin(yy * K * 1.6)
    slub = smooth(0.82, 0.97, noise(N // 14, N // 3, seed + 2)) * 0.6
    return img * (1 + strength * (weave - 0.5 + slub * 0.5)[..., None])


def mottle(img, amount=0.05, seed=3, cells=4):
    return img * (1 + amount * (fbm(cells, seed) - 0.5)[..., None] * 2)


def rect_mask(x0, y0, x1, y1, seed, rough=2.5, soft=1.2):
    d = (fbm(10, seed, 3) - 0.5) * 2 * rough
    return (smooth(x0 - soft, x0 + soft, xx + d) * (1 - smooth(x1 - soft, x1 + soft, xx - d))
            * smooth(y0 - soft, y0 + soft, yy + d) * (1 - smooth(y1 - soft, y1 + soft, yy - d)))


def spline(pts, closed=False, steps=24):
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


def poly_mask(pts, blur=0.6):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon([(x * K, y * K) for x, y in pts], fill=255)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur * K))
    return np.asarray(m, np.float32) / 255.0


def to_image(img):
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")


def vignette(img, amount=0.12):
    r = np.sqrt((xx - 195) ** 2 + (yy - 195) ** 2) / 195
    return img * (1 - amount * smooth(0.6, 1.05, r))[..., None]


# ------------------------------------------------------------------ CINTA
def ribbon(img, ctrl, colors, seed, width=46.0, twists=2.2):
    """Cinta escultórica de pincelada, renderizada como nube densa de puntos en el espacio
    de la cinta (a lo largo × a lo ancho): cada cerda conserva su tono a lo largo de todo el
    recorrido, la luz gira con la cinta y los tramos posteriores tapan a los anteriores."""
    rng = np.random.default_rng(seed)
    path = np.array(spline(ctrl, steps=120), np.float32)
    seg = np.hypot(*np.diff(path, axis=0).T)
    s_len = np.concatenate([[0], np.cumsum(seg)])
    step = 0.42 / K
    s_new = np.arange(0, s_len[-1], step)
    P = np.stack([np.interp(s_new, s_len, path[:, 0]), np.interp(s_new, s_len, path[:, 1])], 1)
    t = s_new / s_len[-1]
    tang = np.gradient(P, axis=0)
    tang /= np.linalg.norm(tang, axis=1, keepdims=True) + 1e-9
    nrm = np.stack([-tang[:, 1], tang[:, 0]], 1)
    # giro lento y continuo (sin cambios bruscos de cara) + curvatura del trazo
    phi = 2 * np.pi * twists * t + 0.4 + 0.6 * np.sin(2 * np.pi * 0.7 * t)
    taper = 0.30 + 0.70 * np.sin(np.pi * np.clip(t * 1.02, 0, 1)) ** 0.5
    half = width * (0.12 + 0.88 * np.abs(np.cos(phi)) ** 0.8) * taper     # cinta plana que se pliega
    nk = 520
    k = np.linspace(-1, 1, nk, dtype=np.float32)
    # textura de cerdas: tono por cerda (constante a lo largo) + surcos + carga de pintura
    bristle = 0.80 + 0.34 * rng.random(nk)
    bristle[rng.random(nk) > 0.84] *= 0.55
    bristle = np.convolve(bristle, [0.25, 0.5, 0.25], mode="same")
    load = 0.94 + 0.12 * np.interp(t, np.linspace(0, 1, 60), rng.random(60))
    # luz continua: la superficie es un cilindro que rota; la cara trasera se oscurece
    # de forma gradual (no por salto) según el coseno del giro.
    # cinta plana: la luz depende sobre todo de hacia dónde mira la cara (giro), con un leve
    # abombado a lo ancho y oscurecimiento junto a los pliegues
    face = np.cos(phi)[:, None]
    shade = 0.5 + 0.38 * np.sin(phi[:, None] + 0.55 * k[None, :]) + 0.12 * face
    shade = shade * (0.55 + 0.45 * np.abs(face) ** 0.5)
    shade = np.clip(shade, 0, 1)
    dark, mid, light = (hexrgb(c) for c in colors)
    lo = dark + (mid - dark) * np.clip(shade * 2, 0, 1)[..., None]
    hi = mid + (light - mid) * np.clip(shade * 2 - 1, 0, 1)[..., None]
    col = np.where((shade < 0.5)[..., None], lo, hi)
    col = col * (bristle[None, :, None] * load[:, None, None]) * (1 - 0.22 * k[None, :, None] ** 6)
    X = P[:, None, 0] + nrm[:, None, 0] * half[:, None] * k[None, :]
    Y = P[:, None, 1] + nrm[:, None, 1] * half[:, None] * k[None, :]
    ix = np.clip((X * K).astype(np.int32), 0, N - 1).ravel()
    iy = np.clip((Y * K).astype(np.int32), 0, N - 1).ravel()
    inside = ((X > -5) & (X < 395) & (Y > -5) & (Y < 395)).ravel()
    buf = np.zeros((N, N, 3), np.float32)
    alpha = np.zeros((N, N), np.float32)
    tail = np.minimum(t / 0.08, (1 - t) / 0.10)                         # 0 en las puntas
    keep = (rng.random((len(t), nk)) < np.clip(tail, 0, 1)[:, None] ** 0.7 + 0.05).ravel() & inside
    buf[iy[keep], ix[keep]] = np.clip(col.reshape(-1, 3)[keep], 0, 1)   # el último tramo gana
    alpha[iy[keep], ix[keep]] = 1.0
    rgba = Image.fromarray((np.dstack([buf, alpha]) * 255).astype(np.uint8), "RGBA")
    arr = np.asarray(rgba.filter(ImageFilter.GaussianBlur(0.35 * K)), np.float32) / 255.0
    # sombra suave proyectada sobre el lino
    sh = np.asarray(rgba.split()[3].filter(ImageFilter.GaussianBlur(6 * K)), np.float32) / 255.0
    dy, dx = int(4 * K), int(3 * K)
    sh = np.pad(sh, ((dy, 0), (dx, 0)))[:N, :N]
    img = img * (1 - 0.25 * sh)[..., None]
    a = np.clip(arr[..., 3] * 1.15, 0, 1)
    rgb = arr[..., :3] / np.maximum(arr[..., 3:4], 1e-3)
    return over(img, np.clip(rgb, 0, 1), a)


def splatter(img, color, seed, region, count=70):
    """Salpicaduras y latigazos finos de tinta."""
    rng = np.random.default_rng(seed)
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = region
    for _ in range(count):
        x, y = rng.uniform(x0, x1) * K, rng.uniform(y0, y1) * K
        r = rng.choice([0.6, 0.9, 1.4, 2.2], p=[0.45, 0.3, 0.17, 0.08]) * K
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    for _ in range(6):
        x, y = rng.uniform(x0, x1) * K, rng.uniform(y0, y1) * K
        a = rng.uniform(0, np.pi)
        L = rng.uniform(14, 40) * K
        d.line([(x, y), (x + np.cos(a) * L, y + np.sin(a) * L)], fill=200, width=max(1, int(0.5 * K)))
    mk = np.asarray(m.filter(ImageFilter.GaussianBlur(0.4 * K)), np.float32) / 255.0
    return over(img, hexrgb(color), mk)


def bg_cinta(ground, colors, ink, seed):
    img = mottle(linen(solid(ground), 0.09, seed), 0.05, seed + 1)
    # gesto caligráfico: entra por la izquierda, hace dos bucles que se pisan y sale por arriba a la derecha
    # gesto: entra abajo a la izquierda, sube por detrás de la base de la hora, cruza y se enrosca a la derecha
    ctrl = [(-60, 330), (24, 272), (110, 246), (196, 262), (262, 300), (246, 362), (184, 352), (206, 294),
            (290, 256), (356, 276), (380, 340), (340, 392), (300, 430)]
    img = ribbon(img, ctrl, colors, seed + 2, width=46.0, twists=1.75)
    img = splatter(img, ink, seed + 3, (30, 214, 370, 385))
    return to_image(vignette(img, 0.10))


# ------------------------------------------------------------------ BLOQUES
BLOCKS = [  # x0, y0, x1, y1, color
    (-40, -40, 118, 150, "#C68570"), (118, -40, 268, 150, "#7A2C2E"), (268, -40, 430, 150, "#4A161A"),
    (-40, 150, 118, 296, "#D7A283"), (118, 150, 430, 296, "#2D2F2D"),
    (-40, 296, 118, 322, "#161615"), (118, 296, 430, 322, "#A3461C"), (-40, 322, 430, 430, "#5B1F23"),
]


def bg_bloques():
    img = linen(solid("#C6B79F"), 0.12, 20)                           # lino crudo entre bloques
    for i, (x0, y0, x1, y1, c) in enumerate(BLOCKS):
        fill = linen(mottle(solid(c), 0.10, 30 + i, 3), 0.16, 40 + i)
        img = over(img, fill, rect_mask(x0 + 1.2, y0 + 1.2, x1 - 1.2, y1 - 1.2, 50 + i))
    return to_image(vignette(img, 0.10))


# ------------------------------------------------------------------ RETÍCULA
GRID = dict(x0=105, y0=160, pitch=18, n=10, size=12.5)


def stamp_mask(seed, cells):
    """Cuadrados estampados en seco: borde irregular y tinta que no llega a todas partes."""
    rng = np.random.default_rng(seed)
    m = np.zeros((N, N), np.float32)
    dry = fbm(40, seed + 1, 3)
    for (cx, cy) in cells:
        s = GRID["size"] * (0.9 + 0.2 * rng.random())
        x0, y0 = cx - s / 2 + rng.normal(0, 0.6), cy - s / 2 + rng.normal(0, 0.6)
        sx, sy = slice(int((y0 - 3) * K), int((y0 + s + 3) * K)), slice(int((x0 - 3) * K), int((x0 + s + 3) * K))
        yy_, xx_ = yy[sx, sy], xx[sx, sy]
        d = (dry[sx, sy] - 0.5) * 2.2
        sq = (smooth(x0 - 0.6, x0 + 0.6, xx_ + d) * (1 - smooth(x0 + s - 0.6, x0 + s + 0.6, xx_ - d))
              * smooth(y0 - 0.6, y0 + 0.6, yy_ + d) * (1 - smooth(y0 + s - 0.6, y0 + s + 0.6, yy_ - d)))
        sq *= smooth(0.22, 0.45, dry[sx, sy] + 0.25 * rng.random())   # tinta seca
        m[sx, sy] = np.maximum(m[sx, sy], sq)
    return m


def grid_cells():
    g = GRID
    return [(g["x0"] + (c + 0.5) * g["pitch"], g["y0"] + (r + 0.5) * g["pitch"])
            for r in range(g["n"]) for c in range(g["n"])]


def bg_reticula():
    img = mottle(linen(solid("#EDE9E1"), 0.05, 60), 0.04, 61, 3)
    r = np.sqrt((xx - 195) ** 2 + (yy - 195) ** 2)
    edge = smooth(188.5, 190.5, r + 2.2 * (fbm(14, 62, 3) - 0.5) * 2)  # borde pintado del lienzo
    img = over(img, solid("#4A3424") * (0.8 + 0.4 * fbm(8, 63, 2))[..., None], edge * 0.85)
    ghost = stamp_mask(64, grid_cells())
    img = over(img, solid("#1C1A17"), ghost * 0.10)                    # casillas aún por estampar
    return to_image(img)


def grid_sprite(side):
    """Retícula completa estampada (solo la zona de la retícula, con transparencia)."""
    m = stamp_mask(64, grid_cells())
    rgba = np.dstack([solid("#1B1916") * (0.9 + 0.2 * fbm(30, 65, 2))[..., None], m])
    im = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").resize((side, side), Image.LANCZOS)
    s = side / 390
    g = GRID
    box = (int(g["x0"] * s), int(g["y0"] * s), int(np.ceil((g["x0"] + g["n"] * g["pitch"]) * s)),
           int(np.ceil((g["y0"] + g["n"] * g["pitch"]) * s)))
    return im.crop(box)


# ------------------------------------------------------------------ COLLAGE
PALETTE = ["#D7372A", "#1E8A4B", "#EFA2A6", "#D8A126", "#5A8FD0", "#151413", "#F3EEE4", "#2A7E78",
           "#E1631E", "#B9C6CB", "#8C2B2B"]
LABEL = (56, 88, 334, 294)


def bg_collage():
    rng = np.random.default_rng(90)
    img = linen(solid("#EFE5CF"), 0.06, 91)
    for i in range(150):
        c = PALETTE[rng.integers(len(PALETTE))]
        x, y = rng.uniform(-30, 420), rng.uniform(-30, 420)
        kind = rng.choice(["rect", "blob", "leaf", "circle", "bar"], p=[0.30, 0.34, 0.1, 0.1, 0.16])
        sz = rng.uniform(30, 110) * (1.0 if i < 110 else 0.5)
        a = rng.uniform(0, np.pi)
        if kind == "rect":
            w, h = sz, sz * rng.uniform(0.4, 1.2)
            pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        elif kind == "bar":
            w, h = sz * 1.6, sz * 0.22
            pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        elif kind == "circle":
            pts = [(np.cos(q) * sz / 2, np.sin(q) * sz / 2) for q in np.linspace(0, 2 * np.pi, 28)]
        elif kind == "leaf":
            pts = [(np.cos(q) * sz * 0.7, np.sin(q) * sz * 0.28 * np.sin(q) ** 0) for q in np.linspace(0, 2 * np.pi, 28)]
            pts = [(px, py * abs(np.sin(np.arctan2(py, px)))) for px, py in pts]
        else:
            ctrl = [(np.cos(q) * sz / 2 * rng.uniform(0.6, 1.2), np.sin(q) * sz / 2 * rng.uniform(0.6, 1.2))
                    for q in np.linspace(0, 2 * np.pi, 7)[:-1]]
            pts = spline(ctrl, closed=True, steps=8)
        rot = [(x + px * np.cos(a) - py * np.sin(a), y + px * np.sin(a) + py * np.cos(a)) for px, py in pts]
        fill = mottle(linen(solid(c), 0.10, 100 + i), 0.12, 500 + i, 5)
        img = over(img, fill, poly_mask(rot, 0.5) * rng.uniform(0.85, 1.0))
        if kind == "leaf" and rng.random() < 0.8:                       # nervio de la hoja
            img = ink_lines(img, [[rot[0], (x, y), rot[14]]], "#141312", 0.8, 200 + i)
    # garabatos de tinta y trazos blancos
    for i in range(26):
        pts = [(rng.uniform(-10, 400), rng.uniform(-10, 400))]
        for _ in range(rng.integers(3, 7)):
            pts.append((pts[-1][0] + rng.normal(0, 45), pts[-1][1] + rng.normal(0, 45)))
        black = i % 3 != 0
        img = ink_lines(img, [spline(pts, steps=12)], "#141312" if black else "#F6F2EA",
                        rng.uniform(3.0, 7.0) if (black and i % 4 == 1) else rng.uniform(0.9, 2.0), 300 + i)
    # puntos
    for i in range(6):
        cx, cy = rng.uniform(20, 370), rng.uniform(20, 370)
        c = PALETTE[rng.integers(len(PALETTE))]
        m = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(m)
        for _ in range(14):
            px, py = cx + rng.normal(0, 16), cy + rng.normal(0, 16)
            r = rng.uniform(2.5, 5) * K
            d.ellipse((px * K - r, py * K - r, px * K + r, py * K + r), fill=255)
        img = over(img, solid(c), np.asarray(m.filter(ImageFilter.GaussianBlur(0.5 * K)), np.float32) / 255)
    # tira de papel para los datos (con sombra) y trozo de cinta adhesiva para la fecha
    for (x0, y0, x1, y1), seed, col, sh in [((74, 252, 316, 300), 400, "#F4EEE2", 0.35), ((122, 58, 268, 86), 410, "#EFE6CC", 0.18)]:
        shadow = rect_mask(x0 + 2, y0 + 3, x1 + 2, y1 + 3, seed, rough=2.5, soft=3)
        img = img * (1 - sh * shadow)[..., None]
        paper = mottle(linen(solid(col), 0.04, seed + 1), 0.04, seed + 2, 3)
        img = over(img, paper, rect_mask(x0, y0, x1, y1, seed + 3, rough=3.0, soft=0.8) * (0.96 if seed == 400 else 0.88))
    return to_image(vignette(img, 0.08))


def ink_lines(img, paths, color, width, seed):
    rng = np.random.default_rng(seed)
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    for path in paths:
        ph = rng.random() * 6
        for i, (x, y) in enumerate(path):
            w = width * (0.7 + 0.4 * np.sin(i / 9 + ph)) * K / 2
            d.ellipse((x * K - w, y * K - w, x * K + w, y * K + w), fill=255)
    mk = np.asarray(m.filter(ImageFilter.GaussianBlur(0.4 * K)), np.float32) / 255.0
    return over(img, hexrgb(color), mk)


# ------------------------------------------------------------------ salida
ART = {
    "cinta_verde": lambda: bg_cinta("#D4CFC3", ("#0F2A1E", "#2C5A40", "#7FA88A"), "#16211B", 70),
    "cinta_ambar": lambda: bg_cinta("#EEEAE3", ("#9C3A06", "#E7801A", "#FFD15A"), "#5A2A08", 80),
    "bloques": bg_bloques,
    "reticula": bg_reticula,
    "collage": bg_collage,
}


def main():
    preview = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else list(ART)
    arts = {name: ART[name]() for name in only}
    for side, folder in SIZES.items():
        d = ROOT / folder / "paint"
        d.mkdir(parents=True, exist_ok=True)
        for name, img in arts.items():
            img.resize((side, side), Image.LANCZOS).save(d / f"bg_{name}.png")
        grid_sprite(side).save(d / "grid.png")
        xml = ["<drawables>"]
        for name in ART:
            rid = "Bg" + "".join(p.capitalize() for p in name.split("_"))
            xml.append(f'    <bitmap id="{rid}" filename="bg_{name}.png" packingFormat="jpg"/>')
        xml.append('    <bitmap id="Grid" filename="grid.png"/>')
        xml.append("</drawables>")
        (d / "paint.xml").write_text("\n".join(xml) + "\n")
    if preview:
        preview.mkdir(parents=True, exist_ok=True)
        for name, img in arts.items():
            img.resize((390, 390), Image.LANCZOS).save(preview / f"bg_{name}.png")


if __name__ == "__main__":
    main()
