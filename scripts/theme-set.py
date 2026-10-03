#!/usr/bin/env python3
import json, sys, subprocess, pathlib
from string import Template
H = pathlib.Path.home()
THEMES = json.load(open(H / ".config/themes/themes.json"))

def rgb(h):
    h = h.lstrip("#")
    return "%d, %d, %d" % tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

WAYBAR = """* { font-family: "CaskaydiaCove Nerd Font"; font-size: 13px; min-height: 0; }
window#waybar { background: transparent; border: none; color: $fg; }
button { border: none; }
tooltip { background: rgba($bg_rgb, 0.95); border: 1px solid rgba($accent_rgb, 0.35); border-radius: 12px; }
tooltip label { color: $fg; }
#workspaces, #tray, #network, #pulseaudio, #backlight, #battery, #clock, #custom-notify, #custom-power { margin: 3px 0; padding: 2px 14px; border-radius: 20px; background: rgba($panel_rgb, 0.8); border: 1px solid rgba($accent_rgb, 0.15); color: $fg; transition: background 0.2s ease; }
#workspaces { padding: 0 4px; }
#workspaces button { margin: 2px 1px; padding: 2px 10px; border-radius: 14px; color: $dim; transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682); }
#workspaces button:hover { background: rgba($accent_rgb, 0.25); color: $fg_bright; }
#workspaces button.active, #workspaces button.focused { background: $accent; color: $on_accent; font-weight: bold; padding: 2px 16px; }
#workspaces button.urgent { background: $red; color: $fg_bright; }
#network:hover, #pulseaudio:hover, #backlight:hover, #battery:hover, #clock:hover, #custom-notify:hover { background: $sel; }
#network.disconnected { color: $red; }
#pulseaudio.muted { color: $red; }
#battery.warning { color: $orange; }
#battery.critical { color: $red; }
#clock { color: $accent_hi; font-weight: bold; }
#custom-notify { color: $accent_hi; }
#custom-power { color: $red; }
#custom-power:hover { background: rgba($red_rgb, 0.35); color: $fg_bright; }
#vol, #luz { margin: 3px 0; padding: 0 14px; border-radius: 20px; background: rgba($panel_rgb, 0.8); border: 1px solid rgba($accent_rgb, 0.15); transition: background 0.2s ease; }
#vol:hover, #luz:hover { background: $sel; }
#vol #pulseaudio, #luz #backlight { margin: 0; padding: 2px 0; background: transparent; border: none; }
#vol #pulseaudio:hover, #luz #backlight:hover { background: transparent; }
#pulseaudio-slider, #backlight-slider { margin: 0 0 0 10px; padding: 0; background: transparent; border: none; }
#pulseaudio-slider slider, #backlight-slider slider { min-width: 0; min-height: 0; opacity: 0; background-image: none; border: none; box-shadow: none; }
#pulseaudio-slider trough, #backlight-slider trough { min-width: 80px; min-height: 6px; border-radius: 6px; background: rgba($accent_rgb, 0.25); }
#pulseaudio-slider highlight, #backlight-slider highlight { min-height: 6px; border-radius: 6px; background: $accent; }
"""

SWAYNC = """* { font-family: "CaskaydiaCove Nerd Font"; font-size: 12px; }
.control-center { background: rgba($bg_rgb, 0.97); border: 1px solid $border; border-radius: 14px; color: $fg; padding: 6px; }
.widget-title { color: $accent_hi; font-size: 13px; font-weight: bold; padding: 4px 8px; }
.widget-dnd label { color: $fg; }
.widget-dnd switch { background: $sel; border-radius: 8px; }
.widget-dnd switch:checked { background: $accent; }
.notification { background: $panel; border: 1px solid $border; border-radius: 10px; margin: 3px 5px; padding: 8px; }
.notification:hover { background: $sel; }
.notification-label { color: $accent_hi; font-weight: bold; }
.notification-body { color: $fg; }
.close-button { background: $red; border-radius: 6px; margin: 4px; }
.blank { min-height: 0; }
"""

FUZZEL = """font=CaskaydiaCove Nerd Font:size=11
lines=8
width=30
horizontal-pad=14
vertical-pad=10
inner-pad=4

[colors]
background=${bg_nh}f5
text=${fg_nh}ff
match=${accent_hi_nh}ff
selection=${sel_nh}ff
selection-text=${fg_bright_nh}ff
selection-match=${accent_hi_nh}ff
border=${accent_nh}ff
"""

KITTY = "foreground $fg_bright\nbackground $bg\nselection_foreground $on_accent\nselection_background $accent\n" \
        "cursor $fg_bright\ncursor_text_color $bg\nurl_color $c12\n" + \
        "".join("color%d $c%d\n" % (i, i) for i in range(16)) + "color16 $ptxt\ncolor17 $pctx\n"

def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

def apply(name):
    p = THEMES[name]
    v = dict(p)
    v.setdefault("ptxt", p["c7"]); v.setdefault("pctx", p["c5"])
    for k, x in p.items():
        v[k + "_rgb"] = rgb(x)
        v[k + "_nh"] = x.lstrip("#")
    files = {".config/waybar/style.css": WAYBAR, ".config/swaync/style.css": SWAYNC,
             ".config/fuzzel/fuzzel.ini": FUZZEL, ".config/kitty/theme.conf": KITTY}
    for path, tpl in files.items():
        (H / path).write_text(Template(tpl).substitute(v))
    act = "rgba(%sff)" % v["accent_nh"]; ina = "rgba(%sff)" % v["sel_nh"]
    (H / ".config/hypr/theme-colors.lua").write_text('return { active = "%s", inactive = "%s" }\n' % (act, ina))
    (H / ".cache").mkdir(exist_ok=True); (H / ".cache/theme.txt").write_text(name)
    run("python3", str(H / "scripts/starship-theme.py"))
    run("python3", str(H / "scripts/eza-theme.py"))
    run("pkill", "-SIGUSR2", "waybar"); run("swaync-client", "-rs"); run("pkill", "-USR1", "kitty")
    r = run("hyprctl", "eval", 'hl.config({ general = { col = { active_border = "%s", inactive_border = "%s" } } })' % (act, ina))
    run("python3", str(H / "scripts/gtk-apply.py"), name)
    print("theme applied:", name, "| hyprland:", (r.stdout + r.stderr).strip())

if __name__ == "__main__":
    n = sys.argv[1] if len(sys.argv) > 1 else "Gruvbox"
    if n not in THEMES:
        sys.exit("unknown theme: %s (available: %s)" % (n, ", ".join(THEMES)))
    apply(n)
