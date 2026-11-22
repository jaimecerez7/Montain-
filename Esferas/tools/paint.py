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
BLOCKS = [  # x0, y0, x1, y1, color — cada bloque aloja un dato
    (-40, -40, 118, 140, "#C98371"),   # salmón: fecha
    (118, -40, 262, 140, "#7B2A2C"),   # burdeos: tiempo
    (262, -40, 430, 140, "#4B1417"),   # sangre de buey: luna
    (-40, 140, 118, 292, "#DDA584"),   # melocotón: pasos
    (118, 140, 430, 292, "#2B2C2A"),   # grafito: hora
    (-40, 292, 118, 320, "#151513"),   # negro: batería
    (118, 292, 430, 320, "#A9471B"),   # óxido: amanecer y atardecer
]


def burlap(img, strength, seed):
    """Lino grueso: hilos visibles en dos direcciones, con nudos y variación de grosor."""
    tx = np.sin(xx * K * 1.25 + 2.0 * noise(4, 300, seed)) * 0.5 + 0.5
    ty = np.sin(yy * K * 1.25 + 2.0 * noise(300, 4, seed + 1)) * 0.5 + 0.5
    weave = 0.55 * tx * ty + 0.45 * (noise(N // 6, N // 2, seed + 2) * 0.5 + noise(N // 2, N // 6, seed + 3) * 0.5)
    return img * (1 + strength * (weave - 0.5)[..., None])


def bg_bloques():
    img = burlap(mottle(solid("#CDBFA8"), 0.06, 19, 4), 0.22, 20)       # lino crudo sin pintar
    for i, (x0, y0, x1, y1, c) in enumerate(BLOCKS):
        fill = burlap(mottle(solid(c), 0.12, 30 + i, 3), 0.20, 40 + i)
        fill = fill * (1 + 0.05 * (fbm(2, 60 + i, 2) - 0.5)[..., None] * 2)   # capas de pintura
        img = over(img, fill, rect_mask(x0 + 1.6, y0 + 1.6, x1 - 1.6, y1 - 1.6, 50 + i, rough=2.0, soft=0.9))
    # firma discreta en el lino crudo
    return to_image(vignette(img, 0.12))


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
PALETTE = ["#D23A22", "#13894C", "#2550A0", "#5D93BC", "#C8664B", "#C8932B", "#E8B227", "#E0631B",
           "#151413", "#F3EEE4", "#0E5A3A", "#17807A"]   # bermellón, esmeralda, cobalto, cerúleo, terracota, ocre, azafrán, naranja quemado, negro, hueso, verde hondo, turquesa
LABEL = (56, 88, 334, 294)


COLLAGE_HOLDERS = {   # piezas de papel para los datos (diseño a 390): tipo, geometría, color, giro
    "temp": ("circle", 98, 266, 40, "#E2AE2E", 0),
    "moon": ("circle", 292, 266, 40, "#1C2B4A", 0),
    "steps": ("rect", 148, 236, 242, 298, "#EADCC0", -3.0),
    "sun": ("rect", 114, 312, 276, 338, "#1E1B18", 1.5),
    "date": ("rect", 90, 56, 300, 84, "#E6D9BC", -1.0),
}


def paper_piece(img, kind, geom, color, seed, shadow=0.32, angle=0.0):
    if kind == "rect" and angle:
        x0, y0, x1, y1 = geom
        cx, cy, a = (x0 + x1) / 2, (y0 + y1) / 2, np.radians(angle)
        corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        pts = [(cx + (x - cx) * np.cos(a) - (y - cy) * np.sin(a), cy + (x - cx) * np.sin(a) + (y - cy) * np.cos(a))
               for x, y in corners]
        sh = poly_mask([(x + 1.5, y + 2) for x, y in pts], blur=3)
        m = poly_mask(pts, blur=0.6)
        m = smooth(0.35, 0.65, m + 0.25 * (fbm(14, seed + 5, 3) - 0.5))          # borde pintado irregular
        img = img * (1 - shadow * 0.5 * sh)[..., None]
        return over(img, painted_fill(color, seed + 2), m)
    if kind == "circle":
        cx, cy, r = geom
        pts = [(cx + np.cos(q) * r * (1 + 0.035 * np.sin(q * 5 + seed) + 0.02 * np.sin(q * 11)), cy + np.sin(q) * r * (1 + 0.03 * np.cos(q * 4 + seed)))
               for q in np.linspace(0, 2 * np.pi, 72)[:-1]]
        sh = poly_mask([(x + 2, y + 3) for x, y in pts], blur=3)
        m = poly_mask(pts, blur=0.5)
    else:
        x0, y0, x1, y1 = geom
        sh = rect_mask(x0 + 2, y0 + 3, x1 + 2, y1 + 3, seed, rough=2.5, soft=3)
        m = rect_mask(x0, y0, x1, y1, seed + 1, rough=2.2, soft=0.7)
    m = smooth(0.35, 0.65, m + 0.25 * (fbm(14, seed + 5, 3) - 0.5))
    img = img * (1 - shadow * 0.5 * sh)[..., None]
    return over(img, painted_fill(color, seed + 2), m)


def leaf(img, x, y, size, angle, color, seed):
    pts = []
    for q in np.linspace(0, np.pi, 18):
        pts.append((np.cos(q) * size, -np.sin(q) * size * 0.42))
    for q in np.linspace(np.pi, 2 * np.pi, 18)[1:-1]:
        pts.append((np.cos(q) * size, -np.sin(q) * size * 0.42))
    rot = [(x + px * np.cos(angle) - py * np.sin(angle), y + px * np.sin(angle) + py * np.cos(angle)) for px, py in pts]
    img = over(img, mottle(linen(solid(color), 0.08, seed), 0.12, seed + 1, 5), poly_mask(rot, 0.5))
    vein = [(x - np.cos(angle) * size * 0.9, y - np.sin(angle) * size * 0.9), (x + np.cos(angle) * size * 0.9, y + np.sin(angle) * size * 0.9)]
    return ink_lines(img, [spline(vein, steps=20)], "#F3EEE4" if color != "#F3EEE4" else "#141312", 1.0, seed + 2)


def painted_fill(color, seed):
    """Relleno pintado a pincel: tono irregular y trazos cortos en una dirección al azar."""
    rng = np.random.default_rng(seed)
    horiz = rng.random() < 0.5
    strokes = noise(14, 70, seed) if horiz else noise(70, 14, seed)
    img = solid(color) * (1 + 0.10 * (fbm(4, seed + 1, 3) - 0.5)[..., None] * 2 + 0.07 * (strokes - 0.5)[..., None] * 2)
    return linen(img, 0.06, seed + 2)


def outline(img, pts, color, width, seed):
    closed = list(pts) + [pts[0]]
    return ink_lines(img, [closed[::2] if len(closed) > 60 else closed], color, width, seed)


def dot_pattern(img, x0, y0, color, seed, cols=4, rows=3, step=9, r=2.4):
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    rng = np.random.default_rng(seed)
    for a in range(rows):
        for b in range(cols):
            x, y = x0 + b * step + rng.normal(0, 0.6), y0 + a * step + rng.normal(0, 0.6)
            rr = r * K * (0.85 + 0.3 * rng.random())
            d.ellipse((x * K - rr, y * K - rr, x * K + rr, y * K + rr), fill=255)
    return over(img, hexrgb(color), np.asarray(m.filter(ImageFilter.GaussianBlur(0.5 * K)), np.float32) / 255)


def bg_collage(seed=91):
    rng = np.random.default_rng(seed)
    img = mottle(linen(solid("#E9D8B8"), 0.07, seed), 0.06, seed + 1, 4)
    big = PALETTE[:8] + ["#0E5A3A", "#17807A"]
    # 1) grandes formas pintadas (dominan la composición)
    for i in range(34):
        c = big[rng.integers(len(big))]
        x, y = rng.uniform(-40, 430), rng.uniform(-40, 430)
        w, h = rng.uniform(70, 150), rng.uniform(50, 120)
        a = rng.uniform(-0.7, 0.7)
        ctrl = [(-w / 2, -h / 2), (w / 2 * rng.uniform(0.6, 1.1), -h / 2), (w / 2, h / 2 * rng.uniform(0.5, 1.0)),
                (-w / 2 * rng.uniform(0.5, 1.1), h / 2)]
        pts = spline(ctrl, closed=True, steps=10) if rng.random() < 0.6 else ctrl
        rot = [(x + px * np.cos(a) - py * np.sin(a), y + px * np.sin(a) + py * np.cos(a)) for px, py in pts]
        img = over(img, painted_fill(c, 1000 * seed + i), poly_mask(rot, 0.6))
        r = rng.random()
        if r < 0.35:
            img = outline(img, rot, "#151413", rng.uniform(2.5, 4.5), 2000 + i)        # contorno negro grueso
        elif r < 0.55:
            img = outline(img, rot, "#F6F2EA", rng.uniform(1.0, 1.6), 3000 + i)        # contorno de tiza blanca
    # 2) formas medianas negras y blancas (contrapunto gráfico)
    for i in range(10):
        c = "#151413" if i % 2 == 0 else "#F6F2EA"
        x, y, rr = rng.uniform(0, 390), rng.uniform(0, 390), rng.uniform(14, 30)
        ctrl = [(x + np.cos(q) * rr * rng.uniform(0.7, 1.2), y + np.sin(q) * rr * rng.uniform(0.7, 1.2))
                for q in np.linspace(0, 2 * np.pi, 7)[:-1]]
        img = over(img, painted_fill(c, 4000 + i), poly_mask(spline(ctrl, closed=True, steps=8), 0.5))
    # 3) hojas con nervio, ojos y puntos
    for i in range(7):
        img = leaf(img, rng.uniform(0, 390), rng.uniform(0, 390), rng.uniform(26, 44), rng.uniform(0, np.pi),
                   ["#13894C", "#0E5A3A", "#151413", "#17807A"][i % 4], 600 + i)
    for i in range(5):
        cx, cy, r = rng.uniform(20, 370), rng.uniform(20, 370), rng.uniform(12, 20)
        ring = [(cx + np.cos(q) * r, cy + np.sin(q) * r) for q in np.linspace(0, 2 * np.pi, 40)[:-1]]
        img = over(img, solid(["#F3EEE4", "#E8B227", "#C8664B"][i % 3]), poly_mask(ring, 0.5))
        img = outline(img, ring, "#151413", 2.0, 5000 + i)
        pupil = [(cx + np.cos(q) * r * 0.42, cy + np.sin(q) * r * 0.42) for q in np.linspace(0, 2 * np.pi, 30)[:-1]]
        img = over(img, solid("#151413"), poly_mask(pupil, 0.5))
    for i in range(6):
        img = dot_pattern(img, rng.uniform(10, 340), rng.uniform(10, 350), ["#F3EEE4", "#151413", "#13894C"][i % 3],
                          6000 + i, cols=rng.integers(3, 6), rows=rng.integers(2, 4))
    for i in range(4):
        x0, y0 = rng.uniform(0, 340), rng.uniform(0, 360)
        for j in range(5):
            bar = [(x0 + j * 9, y0), (x0 + j * 9 + 4, y0), (x0 + j * 9 + 4, y0 + 34), (x0 + j * 9, y0 + 34)]
            img = over(img, solid("#151413" if i % 2 else "#F6F2EA"), poly_mask(bar, 0.4))
    # 4) dibujo libre: tinta negra gruesa y garabatos de tiza blanca
    for i in range(18):
        pts = [(rng.uniform(-10, 400), rng.uniform(-10, 400))]
        for _ in range(rng.integers(3, 6)):
            pts.append((pts[-1][0] + rng.normal(0, 45), pts[-1][1] + rng.normal(0, 45)))
        white = i % 2 == 0
        img = ink_lines(img, [spline(pts, steps=12)], "#F6F2EA" if white else "#151413",
                        rng.uniform(1.0, 1.8) if white else rng.uniform(2.5, 5.5), 300 + i)
    # 5) soportes de papel para los datos (encima de todo, con sombra)
    for i, (name, spec) in enumerate(COLLAGE_HOLDERS.items()):
        kind = spec[0]
        geom = spec[1:4] if kind == "circle" else spec[1:5]
        img = paper_piece(img, kind, geom, spec[-2], 700 + i * 10, 0.30 if name != "date" else 0.15, spec[-1])
    return to_image(vignette(img, 0.06))


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

# ------------------------------------------------------------------ CIELO PINTADO
# Cinco cielos según la altura real del sol; montañas en tres capas con perspectiva aérea.
SKIES = {
    #          cielo arriba, cielo horizonte, nubes, montaña lejana, media, cercana
    "noche":  ("#0A1430", "#22325C", None,      "#202B4A", "#151D35", "#0C1224"),
    "alba":   ("#4E6E9E", "#F0B9A0", "#F6CDB8", "#8D7F9C", "#5E5577", "#383350"),
    "dia":    ("#3F82C2", "#C4DDEB", "#F3F6F6", "#7F99AA", "#4C697A", "#2C4351"),
    "dorada": ("#5D79A3", "#F4BA62", "#FBD9A0", "#A3735C", "#6C4A45", "#3B2A30"),
    "ocaso":  ("#24295A", "#E0876A", "#B9708E", "#4C3B5E", "#33284A", "#1C172E"),
}
RIDGES = [  # (alturas de control de izquierda a derecha, semilla): cumbres, collados y laderas
    ([236, 228, 214, 196, 218, 226, 204, 182, 200, 222, 230, 212, 224, 236], 1),
    ([262, 250, 238, 248, 256, 236, 224, 240, 252, 246, 232, 244, 258, 262], 2),
    ([290, 282, 276, 284, 272, 280, 288, 278, 270, 276, 286, 280, 274, 290], 3),
]


def ridge_mask(heights, seed):
    xs = np.linspace(-20, 410, len(heights))
    pts = [(-40, 430)] + [(x, h) for x, h in zip(xs, heights)] + [(430, 430)]
    rng = np.random.default_rng(seed)
    line = spline(list(zip(xs, heights)), steps=24)
    detail = np.cumsum(rng.normal(0, 0.9, len(line)))
    detail = detail - np.convolve(detail, np.ones(25) / 25, mode="same")      # rugosidad de cresta
    line = [(x, y + d) for (x, y), d in zip(line, detail)]
    m = poly_mask([(-40, 430)] + line + [(430, 430)], blur=0.4)
    return m * (1 - 0.0 * pts[0][0])


def bg_cielo(state):
    top, hor, cloud, c1, c2, c3 = SKIES[state]
    g = smooth(0, 1, (yy - 0) / 250)[..., None]
    img = hexrgb(top) * (1 - g) + hexrgb(hor) * g
    rng = np.random.default_rng(len(state))
    # pinceladas horizontales en el cielo (cielo pintado, no degradado digital)
    marks = 0.5 * noise(40, 150, 120 + len(state)) + 0.5 * fbm(5, 122, 3)
    img = img * (1 + 0.035 * (marks - 0.5)[..., None] * 2)
    if cloud:
        for i in range(6):
            cx, cy = rng.uniform(0, 390), rng.uniform(160, 228)
            w, h = rng.uniform(70, 160), rng.uniform(5, 10)
            pts = [(cx + np.cos(q) * w / 2, cy + np.sin(q) * h / 2 * (1.25 if np.sin(q) < 0 else 0.7))
                   for q in np.linspace(0, 2 * np.pi, 24)[:-1]]
            m = poly_mask(pts, blur=2.5) * (0.7 + 0.3 * noise(20, 60, 140 + i))
            img = over(img, hexrgb(cloud), m * 0.6)
    if state == "noche":
        stars = smooth(0.985, 0.999, noise(N // 2, N // 2, 150)) * smooth(250, 60, yy)
        img = over(img, hexrgb("#F4EEDC"), stars)
    for (hs, sd), col, haze in zip(RIDGES, (c1, c2, c3), (0.25, 0.12, 0.0)):
        m = ridge_mask(hs, sd)
        fill = mottle(solid(col), 0.08, 160 + sd, 5)
        fill = fill * (1 + 0.05 * (noise(160, 12, 170 + sd) - 0.5)[..., None] * 2)   # pincel seco vertical
        fill = fill * (1 - haze) + hexrgb(hor) * haze                                 # perspectiva aérea
        img = over(img, fill, m)
    return to_image(vignette(linen(img, 0.05, 180), 0.14))


def sun_sprite(side):
    """Sol pintado: disco cálido con borde de pincel."""
    r = 13.0
    size = int(np.ceil((2 * r + 4) * K))
    yy_, xx_ = np.mgrid[0:size, 0:size].astype(np.float32) / K
    d = np.hypot(xx_ - (r + 2), yy_ - (r + 2))
    rough = (noise(size // 6, size // 6, 190, n=size) - 0.5) * 1.6
    a = 1 - smooth(r - 0.6, r + 0.6, d + rough)
    core = hexrgb("#FFF4D6") * (1 - smooth(0, r, d))[..., None] + hexrgb("#F7C46A") * smooth(0, r, d)[..., None]
    im = Image.fromarray((np.dstack([np.clip(core, 0, 1), a]) * 255).astype(np.uint8), "RGBA")
    s = side / 908
    return im.resize((max(1, round(size * s)), max(1, round(size * s))), Image.LANCZOS)


def moon_sprite(side, phase):
    """Luna pintada en una de 8 fases (0 = nueva, 4 = llena); la sombra deja ver el disco."""
    r = 12.0
    size = int(np.ceil((2 * r + 4) * K))
    yy_, xx_ = np.mgrid[0:size, 0:size].astype(np.float32) / K
    x, y = xx_ - (r + 2), yy_ - (r + 2)
    d = np.hypot(x, y)
    disc = 1 - smooth(r - 0.5, r + 0.5, d)
    frac = phase / 8.0                                   # 0..1 a lo largo del ciclo
    illum = (1 - np.cos(2 * np.pi * frac)) / 2
    k = 1 - 2 * illum                                     # posición del terminador
    yy2 = np.sqrt(np.clip(r * r - y * y, 0, None))
    waxing = frac <= 0.5
    side_x = x if waxing else -x
    lit = (side_x >= 0) & (side_x >= k * yy2) | (side_x < 0) & (-side_x <= -k * yy2)
    lit = lit.astype(np.float32) if illum > 0.02 else np.zeros_like(x)
    maria = 0.88 + 0.12 * noise(size // 5, size // 5, 200, n=size)  # mares lunares
    rgb = hexrgb("#F3ECDC") * maria[..., None] * lit[..., None] + hexrgb("#3A4258") * (1 - lit)[..., None]
    im = Image.fromarray((np.dstack([np.clip(rgb, 0, 1), disc]) * 255).astype(np.uint8), "RGBA")
    s = side / 908
    return im.resize((max(1, round(size * s)), max(1, round(size * s))), Image.LANCZOS)


# ------------------------------------------------------------------ GEOMETRÍA (baldosas al gouache)
BAU = {"mostaza": "#E3A72F", "terracota": "#C8553D", "marino": "#1F3A5F", "verde": "#2E7D5B",
       "ceruleo": "#5D93BC", "negro": "#1C1A17", "crema": "#EFE4CF", "ladrillo": "#9E3B2C"}
BAU_DATA = {  # baldosas de datos (x0, y0, color de fondo)
    "sun": (39, 234, "terracota"), "temp": (117, 234, "mostaza"), "steps": (195, 234, "marino"), "moon": (273, 234, "negro"),
}
TIME_BAND = (-20, 104, 410, 214)
DATE_STRIP = (104, 60, 286, 90)


def gouache(color, seed):
    """Gouache: color plano con leve variación, marcas de pincel y grano de papel."""
    img = solid(color) * (1 + 0.06 * (fbm(5, seed, 3) - 0.5)[..., None] * 2)
    img = img * (1 + 0.035 * (noise(60, 12, seed + 1) - 0.5)[..., None] * 2)
    return linen(img, 0.05, seed + 2)


def circle_pts(cx, cy, r, a0=0, a1=2 * np.pi, n=48, center=False):
    pts = [(cx + np.cos(a) * r, cy + np.sin(a) * r) for a in np.linspace(a0, a1, n)]
    return pts + [(cx, cy)] if center else pts


def tile_motif(img, x, y, s, motif, c1, c2, seed):
    """Pinta una baldosa: fondo c1 y figura c2 (bordes ligeramente pintados)."""
    img = over(img, gouache(BAU[c1], seed), rect_mask(x + 0.8, y + 0.8, x + s - 0.8, y + s - 0.8, seed, rough=0.8, soft=0.6))
    g = gouache(BAU[c2], seed + 7)
    h = s / 2
    if motif == "quarter":
        corner = [(x, y), (x + s, y), (x + s, y + s), (x, y + s)][seed % 4]
        a0 = [0, np.pi / 2, np.pi, 1.5 * np.pi][seed % 4]
        pts = circle_pts(corner[0], corner[1], s * 0.98, a0, a0 + np.pi / 2, center=True)
    elif motif == "half":
        side = seed % 4
        cx, cy = [(x + h, y + s), (x, y + h), (x + h, y), (x + s, y + h)][side]
        a0 = [np.pi, 1.5 * np.pi, 0, 0.5 * np.pi][side]
        pts = circle_pts(cx, cy, h * 0.98, a0, a0 + np.pi, center=True)
    elif motif == "circle":
        pts = circle_pts(x + h, y + h, h * 0.72)
    elif motif == "dot":
        img = over(img, g, poly_mask(circle_pts(x + h, y + h, h * 0.72), 0.5))
        g = gouache(BAU[c1], seed + 9)
        pts = circle_pts(x + h, y + h, h * 0.28)
    elif motif == "triangle":
        pts = [(x, y + s), (x + s, y + s), (x + (s if seed % 2 else 0), y)]
    elif motif == "stripes":
        for k in range(3):
            bx = x + s * (0.18 + k * 0.26)
            img = over(img, g, rect_mask(bx, y + s * 0.12, bx + s * 0.12, y + s * 0.88, seed + k, rough=0.6, soft=0.5))
        return img
    elif motif == "twin":
        img = over(img, g, poly_mask(circle_pts(x + h, y + h / 2, h / 2 * 0.96), 0.5))
        pts = circle_pts(x + h, y + h * 1.5, h / 2 * 0.96)
    else:
        return img
    return over(img, g, poly_mask(pts, 0.5))


def bg_geometria(seed=31):
    rng = np.random.default_rng(seed)
    img = linen(solid("#E6DAC2"), 0.06, seed)
    motifs = ["quarter", "half", "circle", "dot", "triangle", "stripes", "twin", "quarter", "half"]
    colors = ["mostaza", "terracota", "marino", "verde", "ceruleo", "negro", "crema", "ladrillo"]
    s = 78.0
    data_cells = {(v[0], v[1]) for v in BAU_DATA.values()}
    prev_row = {}
    for r in range(-1, 6):
        for c in range(-1, 6):
            x, y = -39 + c * s, r * s
            if (x, y) in data_cells:
                continue
            c1 = colors[rng.integers(len(colors))]
            while c1 == prev_row.get(c) or c1 == prev_row.get(c - 0.5):
                c1 = colors[rng.integers(len(colors))]
            c2 = colors[rng.integers(len(colors))]
            while c2 == c1:
                c2 = colors[rng.integers(len(colors))]
            img = tile_motif(img, x, y, s, motifs[rng.integers(len(motifs))], c1, c2, int(rng.integers(1, 10_000)))
            prev_row[c] = c1
    # baldosas de datos: fondo y figura fija que acompaña al dato
    for name, (x, y, c) in BAU_DATA.items():
        img = over(img, gouache(BAU[c], 900 + x), rect_mask(x + 0.8, y + 0.8, x + s - 0.8, y + s - 0.8, 901 + x, rough=0.8, soft=0.6))
        if name == "sun":    # medio sol que asoma por abajo
            img = over(img, gouache(BAU["mostaza"], 910), poly_mask(circle_pts(x + 39, y + 78, 22, np.pi, 2 * np.pi, center=True), 0.5))
        if name == "temp":   # cuarto de círculo terracota en una esquina
            img = over(img, gouache(BAU["crema"], 911), poly_mask(circle_pts(x + 78, y + 78, 26, np.pi, 1.5 * np.pi, center=True), 0.5))
        if name == "moon":   # estrellita: punto crema
            img = over(img, solid("#EFE4CF"), poly_mask(circle_pts(x + 62, y + 14, 2.2), 0.4))
    # franja de la hora (azul marino) y tira de la fecha (negra), con sombra suave
    x0, y0, x1, y1 = TIME_BAND
    img = img * (1 - 0.25 * rect_mask(x0, y0 + 3, x1, y1 + 4, 920, rough=1.5, soft=3))[..., None]
    img = over(img, gouache("#1F3A5F", 921), rect_mask(x0, y0, x1, y1, 922, rough=1.2, soft=0.7))
    x0, y0, x1, y1 = DATE_STRIP
    img = over(img, gouache("#1C1A17", 923), rect_mask(x0, y0, x1, y1, 924, rough=1.0, soft=0.6))
    return to_image(vignette(img, 0.08))

ART = {
    "cinta_verde": lambda: bg_cinta("#D4CFC3", ("#0F2A1E", "#2C5A40", "#7FA88A"), "#16211B", 70),
    "cinta_ambar": lambda: bg_cinta("#EEEAE3", ("#9C3A06", "#E7801A", "#FFD15A"), "#5A2A08", 80),
    "bloques": bg_bloques,
    "reticula": bg_reticula,
    "collage": lambda: bg_collage(91),
    "collage2": lambda: bg_collage(191),
    "collage3": lambda: bg_collage(291),
    "geometria": bg_geometria,
    "cielo_noche": lambda: bg_cielo("noche"),
    "cielo_alba": lambda: bg_cielo("alba"),
    "cielo_dia": lambda: bg_cielo("dia"),
    "cielo_dorada": lambda: bg_cielo("dorada"),
    "cielo_ocaso": lambda: bg_cielo("ocaso"),
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
        sun_sprite(side).save(d / "sun.png")
        for ph in range(8):
            moon_sprite(side, ph).save(d / f"moon{ph}.png")
        xml = ["<drawables>"]
        for name in ART:
            rid = "Bg" + "".join(p.capitalize() for p in name.split("_"))
            xml.append(f'    <bitmap id="{rid}" filename="bg_{name}.png" packingFormat="jpg"/>')
        xml.append('    <bitmap id="Grid" filename="grid.png"/>')
        xml.append('    <bitmap id="Sun" filename="sun.png"/>')
        for ph in range(8):
            xml.append(f'    <bitmap id="Moon{ph}" filename="moon{ph}.png"/>')
        xml.append("</drawables>")
        (d / "paint.xml").write_text("\n".join(xml) + "\n")
    if preview:
        preview.mkdir(parents=True, exist_ok=True)
        for name, img in arts.items():
            img.resize((390, 390), Image.LANCZOS).save(preview / f"bg_{name}.png")


if __name__ == "__main__":
    main()
