#!/usr/bin/env python3
"""Pinta las cifras de la hora (0-9 y ':') con la técnica de cada obra.

Uso: python3 -I tools/glyphs.py [carpeta_de_vista_previa]   (desde la carpeta Esferas)

- Cinta: a pincel, con las cerdas y el pigmento de la cinta y bordes de pincel seco.
- Bloques: pintura crema sobre lino.
- Retícula: matriz de cuadrados estampados en seco (la hora forma parte de la retícula).
- Collage: papel de color recortado con borde blanco y sombra.

Cada cifra se guarda con PAD px de diseño de margen a cada lado; el reloj las encadena.
"""
import pathlib
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
TTF = ROOT / "tools/fonts/Jost.ttf"
K = 908 / 390.0
PAD = 6
CHARS = "0123456789:"
SIZES = {390: "resources", 260: "resources-round-260x260", 280: "resources-round-280x280",
         416: "resources-round-416x416", 454: "resources-round-454x454"}


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def noise(h, w, cy, cx, seed):
    rng = np.random.default_rng(seed)
    small = (rng.random((max(1, cy), max(1, cx))) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC), np.float32) / 255.0


def blur(a, r):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def font_mask(ch, size, weight, top_pad=PAD, bottom_pad=PAD):
    """Máscara de la cifra en una caja de altura fija (de la altura de mayúscula a la línea base)."""
    f = ImageFont.truetype(str(TTF), int(size * K))
    f.set_variation_by_axes([weight])
    cap = f.getbbox("0", anchor="ls")[1]          # negativo: altura de las cifras
    bb = f.getbbox(ch, anchor="ls")
    pad = int(PAD * K)
    w = bb[2] - bb[0] + 2 * pad
    h = -cap + int(top_pad * K) + int(bottom_pad * K)
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).text((pad - bb[0], int(top_pad * K) - cap), ch, font=f, fill=255, anchor="ls")
    return np.asarray(im, np.float32) / 255.0


def rgba(rgb, a):
    return np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])


# ------------------------------------------------------------------ estilos
def painted(ch, seed, dark, mid, light):
    """A pincel: cerdas horizontales, carga de pintura irregular y bordes secos."""
    m = font_mask(ch, 132, 400)
    h, w = m.shape
    streak = noise(h, w, h // 2, max(2, w // 70), seed)              # cerdas (varían en vertical)
    load = noise(h, w, 4, 6, seed + 1)
    t = np.clip(0.65 * streak + 0.35 * load, 0, 1)
    rgb = (hexrgb(dark) * (1 - t)[..., None] + hexrgb(mid) * t[..., None])
    rgb = rgb + (hexrgb(light) - rgb) * smooth(0.78, 0.95, streak)[..., None] * 0.6
    edge = blur(m, 1.2 * K) + 0.30 * (noise(h, w, h // 3, max(2, w // 25), seed + 2) - 0.5)
    a = smooth(0.42, 0.58, edge)
    a *= smooth(0.08, 0.30, streak + 0.25)                         # huecos del pincel seco
    return rgba(rgb, a)


def cream_paint(ch, seed):
    m = font_mask(ch, 96, 330)
    h, w = m.shape
    weave = 0.5 * (noise(h, w, h // 2, w // 9, seed) + noise(h, w, h // 9, w // 2, seed + 1))
    rgb = hexrgb("#F2EADF")[None, None, :] * (0.93 + 0.12 * weave)[..., None]
    a = smooth(0.40, 0.60, blur(m, 0.7 * K) + 0.18 * (noise(h, w, h // 4, w // 4, seed + 2) - 0.5))
    return rgba(rgb, a * 0.97)


DOTS = {  # matriz 5 × 7
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    ":": ["0", "0", "1", "0", "1", "0", "0"],
}
DOT_PITCH = 10.0
DOT_SIZE = 8.6


def stamped(ch, seed):
    """La cifra como cuadrados estampados en seco, igual que la retícula de pasos."""
    rows = DOTS[ch]
    cols = len(rows[0])
    rng = np.random.default_rng(seed)
    w = int((cols * DOT_PITCH + 2 * PAD) * K)
    h = int((7 * DOT_PITCH + 2 * PAD) * K)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) / K
    dry = noise(h, w, h // 6, w // 6, seed)
    m = np.zeros((h, w), np.float32)
    for r, line in enumerate(rows):
        for c, v in enumerate(line):
            if v != "1":
                continue
            s = DOT_SIZE * (0.97 + 0.06 * rng.random())
            x0 = PAD + c * DOT_PITCH + (DOT_PITCH - s) / 2 + rng.normal(0, 0.12)
            y0 = PAD + r * DOT_PITCH + (DOT_PITCH - s) / 2 + rng.normal(0, 0.12)
            d = (dry - 0.5) * 0.9
            sq = (smooth(x0 - 0.5, x0 + 0.5, xx + d) * (1 - smooth(x0 + s - 0.5, x0 + s + 0.5, xx - d))
                  * smooth(y0 - 0.5, y0 + 0.5, yy + d) * (1 - smooth(y0 + s - 0.5, y0 + s + 0.5, yy - d)))
            m = np.maximum(m, sq * (0.80 + 0.20 * smooth(0.1, 0.5, dry)))
    rgb = hexrgb("#1B1916")[None, None, :] * (0.9 + 0.2 * dry)[..., None]
    return rgba(np.broadcast_to(rgb, (h, w, 3)), m)


PAPERS = ["#D7372A", "#1E8A4B", "#3E7CC8", "#D8A126", "#E98FA0", "#2A7E78", "#E1631E", "#151413",
          "#8C2B2B", "#5A8FD0", "#151413"]


def cutout(ch, seed):
    """Papel recortado: relleno de color, borde de papel blanco irregular y sombra."""
    m = font_mask(ch, 112, 700, top_pad=PAD + 2, bottom_pad=PAD + 4)
    h, w = m.shape
    rough = 0.25 * (noise(h, w, h // 8, w // 8, seed) - 0.5)
    fill = smooth(0.45, 0.55, blur(m, 0.5 * K) + rough * 0.5)
    border_m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(int(5.5 * K) | 1)),
                          np.float32) / 255.0
    border = smooth(0.40, 0.60, blur(border_m, 0.8 * K) + rough)
    shadow = blur(border, 2.2 * K)
    dy, dx = int(2.5 * K), int(1.5 * K)
    shadow = np.pad(shadow, ((dy, 0), (dx, 0)))[:h, :w]
    color = hexrgb(PAPERS[CHARS.index(ch)])
    paper = noise(h, w, h // 3, w // 3, seed + 1)
    rgb = np.broadcast_to(hexrgb("#FAF7F0"), (h, w, 3)).copy()
    rgb = rgb * (1 - fill[..., None]) + (color * (0.92 + 0.12 * paper)[..., None]) * fill[..., None]
    a = np.maximum(border, shadow * 0.45)
    rgb = rgb * (border[..., None]) + np.zeros(3) * (1 - border[..., None])   # la sombra es negra
    return rgba(rgb, a)


STYLES = {
    "Cv": lambda ch, i: painted(ch, 700 + i, "#123222", "#2F6247", "#8DB89A"),
    "Ca": lambda ch, i: painted(ch, 800 + i, "#7A2E06", "#D4701A", "#FFD36B"),
    "Bl": lambda ch, i: cream_paint(ch, 900 + i),
    "Re": lambda ch, i: stamped(ch, 1000 + i),
    "Co": lambda ch, i: cutout(ch, 1100 + i),
}


def main():
    preview = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
    renders = {sid: [fn(ch, i) for i, ch in enumerate(CHARS)] for sid, fn in STYLES.items()}
    for side, folder in SIZES.items():
        out = ROOT / folder / "glyphs"
        out.mkdir(parents=True, exist_ok=True)
        s = side / 908
        xml = ["<drawables>"]
        for sid, imgs in renders.items():
            for i, arr in enumerate(imgs):
                im = Image.fromarray((arr * 255).astype(np.uint8), "RGBA")
                im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
                name = f"g{sid.lower()}{i}.png"
                im.save(out / name)
                xml.append(f'    <bitmap id="Glyph{sid}{i}" filename="{name}"/>')
        xml.append("</drawables>")
        (out / "glyphs.xml").write_text("\n".join(xml) + "\n")
    if preview:
        preview.mkdir(parents=True, exist_ok=True)
        for sid, imgs in renders.items():
            parts = [Image.fromarray((a * 255).astype(np.uint8), "RGBA") for a in imgs]
            W = sum(p.width for p in parts)
            H = max(p.height for p in parts)
            sheet = Image.new("RGBA", (W, H), (210, 205, 195, 255))
            x = 0
            for p in parts:
                sheet.alpha_composite(p, (x, 0))
                x += p.width
            sheet.resize((W // 3, H // 3), Image.LANCZOS).save(preview / f"glyphs_{sid}.png")


if __name__ == "__main__":
    main()
