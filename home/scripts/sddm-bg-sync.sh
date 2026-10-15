#!/usr/bin/env bash
python3 - <<'PYEOF'
import pathlib
from PIL import Image, ImageOps
H = pathlib.Path.home()
DST = "/usr/share/sddm/themes/pixie/assets/background.jpg"
SIZE = (1366, 768)   # resolucion de tu pantalla
w = pathlib.Path((H / ".cache/current_wallpaper.txt").read_text().strip())
src = H / ".cache/wallfull" / w.name
src = src if src.exists() else w
ImageOps.fit(Image.open(src).convert("RGB"), SIZE, Image.LANCZOS).save(DST, quality=90)
print("sddm background updated from", src)
PYEOF
