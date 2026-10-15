#!/usr/bin/env python3
import json, pathlib, re, subprocess
from PIL import Image, ImageOps

H = pathlib.Path.home()
TPL = H / ".config/hypr/hyprlock-style2.tpl"
OUT = H / ".config/hypr/hyprlock.conf"
THEME_COLORS = True   # False = deja los colores originales del Style-2
REF_H = 1080          # alto de pantalla para el que se hizo el estilo

try:
    T = json.load(open(H / ".config/themes/themes.json"))
    p = T.get((H / ".cache/theme.txt").read_text().strip()) or T["Gruvbox"]
except Exception:
    p = {"fg_bright": "#ebdbb2"}

def monitor_size():
    try:
        m = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)[0]
        return int(m["width"]), int(m["height"])
    except Exception:
        return 1366, 768

W, Hh = monitor_size()
k = Hh / REF_H

wall = ""
try:
    w = pathlib.Path(open(H / ".cache/current_wallpaper.txt").read().strip())
    src = H / ".cache/wallfull" / w.name
    src = src if src.exists() else w
    if src.exists():
        cache = H / ".cache/lockbg"; cache.mkdir(parents=True, exist_ok=True)
        dst = cache / (src.stem + "_%dx%d_s2.jpg" % (W, Hh))
        if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
            ImageOps.fit(Image.open(src).convert("RGB"), (W, Hh), Image.LANCZOS).save(dst, quality=90)
        wall = str(dst)
except Exception as e:
    print("warning, no background image:", e)

conf = TPL.read_text()
conf = conf.replace("%I:%M", "%H:%M").replace("$(date", "$(LC_ALL=C date")

# 1) fuera el recorte (Kakashi)
conf = re.sub(r'(?:#[^\n]*Foreground[^\n]*\n)?image\s*\{.*?\n\}\n?', '', conf, flags=re.S)

# 2) escalar a la pantalla actual
conf = re.sub(r'(position\s*=\s*)(-?\d+),\s*(-?\d+)',
              lambda m: "%s%d, %d" % (m.group(1), round(int(m.group(2)) * k), round(int(m.group(3)) * k)), conf)
conf = re.sub(r'(font_size\s*=\s*)(\d+)',
              lambda m: "%s%d" % (m.group(1), max(10, round(int(m.group(2)) * k))), conf)
conf = re.sub(r'(\n\s*size\s*=\s*)(\d+),\s*(\d+)',
              lambda m: "%s%d, %d" % (m.group(1), round(int(m.group(2)) * k), round(int(m.group(3)) * k)), conf)

# 2b) reloj y fecha: tamaño y posición propios (fracción del alto de pantalla)
CLOCK_SIZE = 0.20   # tamaño del reloj (768p -> 154)
CLOCK_Y = 0.17      # altura del reloj sobre el centro (768p -> 131)
DATE_Y = 0.335      # altura de la fecha sobre el centro (768p -> 257)

def tweak(conf, marker, size=None, y=None):
    def fix(m):
        b = m.group(0)
        if marker not in b:
            return b
        if size is not None:
            b = re.sub(r'(font_size\s*=\s*)\d+', lambda n: n.group(1) + str(round(size)), b)
        if y is not None:
            b = re.sub(r'(position\s*=\s*-?\d+,\s*)-?\d+', lambda n: n.group(1) + str(round(y)), b)
        return b
    return re.sub(r'label\s*\{.*?\n\}', fix, conf, flags=re.S)

conf = tweak(conf, "%H:%M", size=Hh * CLOCK_SIZE, y=Hh * CLOCK_Y)
conf = tweak(conf, "%A", y=Hh * DATE_Y)

# 2c) color del reloj segun el wallpaper
DYNAMIC_CLOCK = True

def wall_color(path):
    import colorsys
    im = Image.open(path).convert("RGB").resize((96, 54))
    q = im.quantize(colors=8)
    pal = q.getpalette()
    best, best_score = None, -1
    for count, idx in q.getcolors():
        r, g, b = pal[idx * 3: idx * 3 + 3]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        score = count * (s ** 1.5 + 0.05)
        if score > best_score:
            best, best_score = (h, s), score
    h, s = best
    s = min(max(s, 0.35), 0.85)
    r, g, b = colorsys.hsv_to_rgb(h, s, 0.95)
    return round(r * 255), round(g * 255), round(b * 255)

if DYNAMIC_CLOCK and wall:
    try:
        cr, cg, cb = wall_color(wall)
        def paint(m):
            blk = m.group(0)
            if "%H:%M" not in blk:
                return blk
            return re.sub(r'(color\s*=\s*)[^\n]*',
                          lambda n: "%srgba(%d, %d, %d, 0.9)" % (n.group(1), cr, cg, cb), blk, count=1)
        conf = re.sub(r'label\s*\{.*?\n\}', paint, conf, flags=re.S)
    except Exception as e:
        print("warning, dynamic color:", e)

# 3) fondo = tu wallpaper
if wall:
    conf = re.sub(r'(background\s*\{[^}]*?path\s*=\s*)[^\n]*',
                  lambda m: m.group(1) + wall, conf, count=1)

# 4) colores de tu tema
if THEME_COLORS:
    h = p["fg_bright"].lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    conf = re.sub(r'rgba\(\s*216,\s*222,\s*233,\s*([0-9.]+)\s*\)',
                  lambda m: "rgba(%d, %d, %d, %s)" % (r, g, b, m.group(1)), conf)

OUT.write_text(conf)
print("hyprlock.conf generated | pantalla %dx%d (escala %.2f) | fondo: %s" % (W, Hh, k, wall or "(original del estilo)"))
