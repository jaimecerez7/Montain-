"""Hoja de presentación: todas las esferas en un bisel de reloj."""
import sys
from PIL import Image, ImageDraw, ImageFont
names = [("cinta_verde", "Cinta verde"), ("cinta_ambar", "Cinta ámbar"), ("bloques", "Bloques"),
         ("reticula", "Retícula"), ("collage", "Collage")]
font = ImageFont.truetype("../tools/fonts/Jost.ttf", 34)
font.set_variation_by_axes([480])
W, H, pad, cols = 470, 560, 30, 3
rows = (len(names) + cols - 1) // cols
out = Image.new("RGB", (pad + cols * (W + pad), rows * H), (232, 224, 212))
d = ImageDraw.Draw(out)
m = Image.new("L", (1560, 1560), 0)
ImageDraw.Draw(m).ellipse((0, 0, 1559, 1559), fill=255)
mask = m.resize((390, 390), Image.LANCZOS)
for i, (f, label) in enumerate(names):
    x = pad + (i % cols) * (W + pad); y0 = (i // cols) * H
    cx, cy = x + W // 2, y0 + 250
    d.ellipse((cx - 226, cy - 226, cx + 226, cy + 226), fill=(30, 30, 32))
    d.ellipse((cx - 205, cy - 205, cx + 205, cy + 205), fill=(6, 6, 6))
    out.paste(Image.open(f"esfera-{f}.png").convert("RGB").resize((390, 390)), (cx - 195, cy - 195), mask)
    tw = d.textlength(label, font=font)
    d.text((cx - tw / 2, y0 + 500), label, font=font, fill=(58, 42, 32))
out.save(sys.argv[1] if len(sys.argv) > 1 else "esferas-todas.png")
