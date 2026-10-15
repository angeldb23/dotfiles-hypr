#!/usr/bin/env python3
# Lista ~/wallpapers y genera miniaturas redondeadas en ~/.cache/wallthumbs-round/
# Salida: una linea por wallpaper -> ruta_original<TAB>ruta_miniatura
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

H = Path.home()
SRC = H / "wallpapers"
DST = H / ".cache" / "wallthumbs-round"
W, HT, R = 320, 180, 20
EXT = {".jpg", ".jpeg", ".png", ".webp"}
DST.mkdir(parents=True, exist_ok=True)

S = 4
m = Image.new("L", (W * S, HT * S), 0)
ImageDraw.Draw(m).rounded_rectangle((0, 0, W * S - 1, HT * S - 1), radius=R * S, fill=255)
MASK = m.resize((W, HT), Image.LANCZOS)

files = sorted((p for p in SRC.iterdir() if p.is_file() and p.suffix.lower() in EXT),
               key=lambda p: p.name.lower())
for src in files:
    out = DST / (src.stem + ".png")
    try:
        if not out.exists() or out.stat().st_mtime < src.stat().st_mtime:
            im = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
            im = ImageOps.fit(im, (W, HT), Image.LANCZOS)
            im.putalpha(MASK)
            im.save(out)
        print(f"{src}\t{out}")
    except Exception:
        print(f"{src}\t{src}")
