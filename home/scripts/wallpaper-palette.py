#!/usr/bin/env python3
"""Paleta desde un wallpaper usando matugen, con las mismas claves que themes.json.
Uso: wallpaper-palette.py [imagen] [--json] [--type TIPO] [--prefer CRITERIO]
Sin imagen usa la de ~/.cache/current_wallpaper.txt.
matugen corre con --dry-run: no genera plantillas, no recarga apps ni toca tu config.
Solo guarda un cache en ~/.cache/wallpalettes/"""
import colorsys, json, pathlib, shutil, subprocess, sys

H = pathlib.Path.home()
CACHE = H / ".cache/wallpalettes"
KEYS = ["bg", "panel", "sel", "border", "fg", "fg_bright", "dim", "accent", "accent_hi",
        "on_accent", "red", "orange"] + ["c%d" % i for i in range(16)]
# clave de themes.json <- rol de matugen (modo dark)
ROLES = {"bg": "surface", "panel": "surface_container", "sel": "surface_container_high",
         "border": "outline_variant", "fg": "on_surface_variant", "fg_bright": "on_surface",
         "dim": "outline", "accent": "primary", "accent_hi": "primary_fixed",
         "on_accent": "on_primary", "red": "error"}


def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360, max(0, min(1, l)), max(0, min(1, s)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def rgb(x):
    x = x.lstrip("#")
    return tuple(int(x[i:i + 2], 16) for i in (0, 2, 4))


def lum(x):
    def f(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (f(c) for c in rgb(x))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def fit(h, s, l, bg, ratio):
    while l < 0.97 and contrast(hsl(h, s, l), bg) < ratio:
        l += 0.02
    return min(l, 0.97)


def run_matugen(path, stype, prefer):
    exe = shutil.which("matugen")
    if not exe:
        sys.exit("matugen no esta instalado: sudo pacman -S matugen")
    # varias formas de elegir el color sin el selector interactivo (segun la version)
    picks = [["--prefer", prefer], ["--source-color-index", "0"], []]
    for pick in picks:
        cmd = [exe, "image", str(path), "--dry-run", "--json", "hex", "-m", "dark", "-t", stype] + pick
        try:
            r = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)
            data = json.loads(r.stdout)
            if "colors" in data:
                return data["colors"]
        except (ValueError, subprocess.TimeoutExpired):
            continue
    sys.exit("matugen no devolvio un JSON valido. Prueba a mano:\n  matugen image '%s' --dry-run --json hex --prefer saturation" % path)


def quant_accent(path):
    """Acento real del wallpaper: cluster dominante ponderado por area x saturacion.
    Devuelve (accent, accent_hi, on_accent) o None si no hay color vibrante."""
    try:
        from PIL import Image
        im = Image.open(path).convert("RGB")
        im.thumbnail((160, 160))
        q = im.quantize(colors=10, method=Image.MEDIANCUT)
        pal = q.getpalette()
        counts = q.getcolors(160 * 160)
        best = None
        for cnt, idx in counts:
            r, g, b = pal[idx * 3:idx * 3 + 3]
            h, l, sat = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            if sat < 0.30 or l < 0.15 or l > 0.90:
                continue
            score = cnt * (sat ** 1.5)
            if best is None or score > best[0]:
                best = (score, h * 360, sat, l)
        if best is None:
            return None
        _, h, sat, l = best
        sat = min(sat, 0.85)
        acc = hsl(h, sat, min(max(l, 0.45), 0.70))
        hi = hsl(h, sat, min(l + 0.14, 0.88))
        on = "#101010" if lum(acc) > 0.35 else "#f5f5f5"
        return acc, hi, on
    except Exception:
        return None

def role(colors, name, mode="dark"):
    e = colors.get(name)
    if e is None and isinstance(colors.get(mode), dict):
        e = colors[mode].get(name)
    if isinstance(e, dict) and mode in e:
        e = e[mode]
    if isinstance(e, dict):
        e = e.get("color") or e.get("hex") or next(iter(e.values()), None)
    return e if isinstance(e, str) and e.startswith("#") else None


def build(path, stype, prefer):
    colors = run_matugen(path, stype, prefer)
    p, missing = {}, []
    for k, r in ROLES.items():
        v = role(colors, r)
        if v is None:
            missing.append(r)
        p[k] = v
    if missing:
        sys.exit("Faltan roles en el JSON de matugen: %s\nRoles disponibles: %s" % (missing, sorted(colors)))
    bg = p["bg"]
    qa = quant_accent(path)
    if qa:
        p["accent"], p["accent_hi"], p["on_accent"] = qa
    p["orange"] = hsl(25, 0.70, fit(25, 0.70, 0.50, bg, 4.5))
    p["c0"] = p["panel"]
    hues = [2, 100, 42, 205, 315, 170]  # rojo verde amarillo azul magenta cian (fijos para que la terminal se lea)
    for i, hh in enumerate(hues, 1):
        l = fit(hh, 0.50, 0.50, bg, 4.5)
        p["c%d" % i] = hsl(hh, 0.50, l)
        p["c%d" % (i + 8)] = hsl(hh, 0.60, min(l + 0.10, 0.88))
    p["c7"], p["c8"], p["c15"] = p["fg"], p["dim"], p["fg_bright"]
    return {k: p[k] for k in KEYS}


def get_palette(path, stype, prefer):
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / ("%s_%d_%s_%s_v2.json" % (path.stem, int(path.stat().st_mtime), stype, prefer))
    if f.exists():
        return json.loads(f.read_text())
    p = build(path, stype, prefer)
    f.write_text(json.dumps(p, indent=1))
    return p


def preview(p):
    for k, v in p.items():
        r, g, b = rgb(v)
        print("\x1b[48;2;%d;%d;%dm      \x1b[0m %-10s %s" % (r, g, b, k, v))


def opt(name, default):
    a = sys.argv
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else default


if __name__ == "__main__":
    stype, prefer = opt("--type", "scheme-tonal-spot"), opt("--prefer", "saturation")
    skip = {"--type", "--prefer"}
    args, i = [], 1
    while i < len(sys.argv):
        a = sys.argv[i]
        if a in skip:
            i += 2
        elif a.startswith("--"):
            i += 1
        else:
            args.append(a)
            i += 1
    path = pathlib.Path(args[0]).expanduser() if args else pathlib.Path((H / ".cache/current_wallpaper.txt").read_text().strip())
    pal = get_palette(path, stype, prefer)
    if "--json" in sys.argv:
        print(json.dumps(pal, indent=1))
    else:
        print("Wallpaper:", path, "|", stype, "|", prefer)
        preview(pal)
