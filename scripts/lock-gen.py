#!/usr/bin/env python3
import json, os, pathlib, subprocess
from PIL import Image, ImageFilter, ImageEnhance, ImageOps
H = pathlib.Path.home()
try:
    T = json.load(open(H / ".config/themes/themes.json"))
    p = T.get((H / ".cache/theme.txt").read_text().strip()) or T["Gruvbox"]
except Exception:
    p = {"bg": "#1d2021", "fg": "#d4be98", "fg_bright": "#ebdbb2", "accent": "#d79921", "accent_hi": "#e9b45b", "red": "#c34043"}

def monitor_size():
    try:
        m = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)[0]
        return int(m["width"]), int(m["height"])
    except Exception:
        return 1366, 768

wall = ""
try:
    w = pathlib.Path(open("/tmp/current_wallpaper.txt").read().strip())
    src = H / ".cache/wallfull" / w.name
    src = src if src.exists() else w
    if src.exists():
        W, Hh = monitor_size()
        cache = H / ".cache/lockbg"; cache.mkdir(parents=True, exist_ok=True)
        dst = cache / (src.stem + "_%dx%d.jpg" % (W, Hh))
        if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
            im = ImageOps.fit(Image.open(src).convert("RGB"), (W, Hh), Image.LANCZOS)
            small = im.resize((W // 4, Hh // 4), Image.BILINEAR).filter(ImageFilter.GaussianBlur(3))
            im = ImageEnhance.Brightness(small.resize((W, Hh), Image.BICUBIC)).enhance(0.6)
            im.save(dst, quality=85)
        wall = str(dst)
except Exception as e:
    print("warning, no background image:", e)

def c(k): return "rgba(%sff)" % p[k].lstrip("#")
FONT = "CaskaydiaCove Nerd Font"
conf = """general {
    hide_cursor = true
}

animations {
    enabled = true
    bezier = linear, 1, 1, 0, 0
    animation = fadeIn, 0, 1, linear
    animation = fadeOut, 0, 1, linear
    animation = inputFieldFade, 0, 1, linear
    animation = inputFieldColors, 0, 1, linear
    animation = inputFieldWidth, 0, 1, linear
    animation = inputFieldDots, 1, 2, linear
}

background {
    monitor =
@PATH@    color = @BG@
    blur_passes = 0
}

label {
    monitor =
    text = cmd[update:5000] echo "<b>$(date +%H)</b>"
    color = @FGB@
    font_size = 96
    font_family = @FONT@
    position = 0, 190
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:5000] echo "<b>$(date +%M)</b>"
    color = @FGB@
    font_size = 96
    font_family = @FONT@
    position = 0, 70
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:600000] echo "<b>$(date +%A)</b>"
    color = @ACCH@
    font_size = 18
    font_family = @FONT@
    position = 0, -20
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:600000] echo "<b>$(date '+%d %b')</b>"
    color = @FG@
    font_size = 14
    font_family = @FONT@
    position = 0, -48
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 250, 50
    outline_thickness = 3
    dots_size = 0.26
    dots_spacing = 0.64
    dots_center = true
    rounding = 22
    outer_color = @ACC@
    inner_color = rgba(255, 255, 255, 0.1)
    font_color = @FG@
    check_color = @ACC@
    fail_color = @RED@
    fade_on_empty = false
    placeholder_text = <i>Password...</i>
    position = 0, 120
    halign = center
    valign = bottom
}
"""
rep = {"@PATH@": ("    path = %s\n" % wall) if wall else "", "@BG@": c("bg"), "@FGB@": c("fg_bright"),
       "@FG@": c("fg"), "@ACC@": c("accent"), "@ACCH@": c("accent_hi"), "@RED@": c("red"), "@FONT@": FONT}
for k, v in rep.items():
    conf = conf.replace(k, v)
(H / ".config/hypr/hyprlock.conf").write_text(conf)
print("hyprlock.conf generated | background:", wall or "(solid color)")
