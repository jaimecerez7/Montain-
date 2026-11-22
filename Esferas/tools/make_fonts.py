#!/usr/bin/env python3
"""Genera las fuentes BMFont (.fnt + .png) de Jost para cada resolución de pantalla.

Uso: python3 -I tools/make_fonts.py   (desde la carpeta Esferas)

- Glifos blancos con canal alfa (Connect IQ los pinta con el color activo).
- Dígitos tabulares: todos con el mismo avance, para que la hora no "baile".
- Espaciado extra (tracking) opcional por fuente, para las versalitas de la fecha.
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
TTF = ROOT / "tools/fonts/Jost.ttf"
BASE = 390

# (id, tamaño a 390 px, peso, juego de caracteres, tracking a 390 px, dígitos tabulares)
UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZÁÉÍÓÚÑÜ"
FONTS = [
    ("time", 124, 250, "0123456789:", 0, True),
    ("timem", 88, 280, "0123456789:", 0, True),
    ("data", 28, 340, "0123456789:°%.,-+/ kmhKMH" + UPPER, 1, True),
    ("label", 19, 460, "0123456789 ·" + UPPER, 5, False),
    ("small", 21, 380, "0123456789:°%.,-+/ " + UPPER + "abcdefghijklmnopqrstuvwxyzáéíóúñ", 1, True),
    ("timeb", 124, 560, "0123456789:", 0, True),
    ("mini", 13, 520, "0123456789 ·%" + UPPER, 3, False),
]
# Resolución (lado en px) → carpeta de recursos
SIZES = {390: "resources", 260: "resources-round-260x260", 280: "resources-round-280x280",
         416: "resources-round-416x416", 454: "resources-round-454x454"}


def make_font(fid, size, weight, chars, tracking, tabular, out_dir):
    font = ImageFont.truetype(str(TTF), size)
    font.set_variation_by_axes([weight])
    ascent, descent = font.getmetrics()
    line_h = ascent + descent
    glyphs = []
    digit_adv = max(font.getlength(d) for d in "0123456789") if tabular else 0
    for ch in dict.fromkeys(chars):
        bbox = font.getbbox(ch, anchor="ls")   # relativo a la línea base
        w = max(1, bbox[2] - bbox[0])
        h = max(1, bbox[3] - bbox[1])
        img = Image.new("L", (w + 2, h + 2), 0)
        ImageDraw.Draw(img).text((1 - bbox[0], 1 - bbox[1]), ch, font=font, fill=255, anchor="ls")
        adv = font.getlength(ch)
        xoff = bbox[0] - 1
        if tabular and ch.isdigit():
            xoff += round((digit_adv - adv) / 2)
            adv = digit_adv
        glyphs.append((ch, img, xoff, ascent + bbox[1] - 1, round(adv) + tracking))

    # Empaquetado simple por filas.
    width = 512 if size < 60 else 1024
    x = y = row_h = 0
    places = []
    for ch, img, *_ in glyphs:
        if x + img.width > width:
            x, y, row_h = 0, y + row_h + 1, 0
        places.append((x, y))
        x += img.width + 1
        row_h = max(row_h, img.height)
    height = y + row_h + 1
    atlas = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    for (ch, img, *_), (px, py) in zip(glyphs, places):
        white = Image.new("RGBA", img.size, (255, 255, 255, 255))
        white.putalpha(img)
        atlas.paste(white, (px, py))
    png = f"{fid}.png"
    atlas.save(out_dir / png)

    lines = [
        f'info face="Jost" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',
        f"common lineHeight={line_h} base={ascent} scaleW={width} scaleH={height} pages=1 packed=0",
        f'page id=0 file="{png}"',
        f"chars count={len(glyphs)}",
    ]
    for (ch, img, xoff, yoff, adv), (px, py) in zip(glyphs, places):
        lines.append(f"char id={ord(ch)} x={px} y={py} width={img.width} height={img.height} "
                     f"xoffset={xoff} yoffset={yoff} xadvance={adv} page=0 chnl=15")
    (out_dir / f"{fid}.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    for side, folder in SIZES.items():
        out = ROOT / folder / "fonts"
        out.mkdir(parents=True, exist_ok=True)
        scale = side / BASE
        xml = ["<fonts>"]
        for fid, size, weight, chars, tracking, tabular in FONTS:
            make_font(fid, max(8, round(size * scale)), weight, chars, round(tracking * scale), tabular, out)
            name = fid[0].upper() + fid[1:]
            xml.append(f'    <font id="{name}" filename="{fid}.fnt" antialias="true"/>')
        xml.append("</fonts>")
        (out / "fonts.xml").write_text("\n".join(xml) + "\n", encoding="utf-8")
        print(f"{folder}: escala {scale:.2f}")


if __name__ == "__main__":
    main()
