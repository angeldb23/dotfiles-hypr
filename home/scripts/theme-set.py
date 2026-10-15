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

SWAYNC = """* { font-family: "SF Pro Display", "CaskaydiaCove Nerd Font"; font-size: 13px; }
.control-center { background: rgba($bg_rgb, 0.97); border: 1px solid rgba($accent_rgb, 0.35); border-radius: 22px; color: $fg; padding: 14px; }
.control-center-list { background: transparent; }
.widget-title { color: $accent_hi; font-size: 16px; font-weight: bold; padding: 2px 6px 8px 6px; margin: 0; }
.widget-title > button { background: rgba($fg_rgb, 0.10); color: $fg; border: none; border-radius: 12px; padding: 4px 14px; box-shadow: none; }
.widget-title > button:hover { background: rgba($accent_rgb, 0.25); }
.widget-dnd { padding: 4px 6px 10px 6px; margin: 0; }
.widget-dnd > label { color: $fg; }
.widget-dnd > switch { background: rgba($fg_rgb, 0.14); border: none; border-radius: 14px; }
.widget-dnd > switch:checked { background: $accent; }
.widget-dnd > switch slider { background: $fg; border-radius: 14px; }
.notification-row { background: transparent; outline: none; padding: 0; }
.notification-group { background: transparent; }
.notification { background: rgba($fg_rgb, 0.07); border: none; border-radius: 16px; margin: 4px 0; padding: 10px; box-shadow: none; }
.notification:hover { background: rgba($accent_rgb, 0.16); }
.floating-notifications .notification { background: rgba($bg_rgb, 0.97); border: 1px solid rgba($accent_rgb, 0.35); margin: 6px 8px; }
.summary, .notification-label { color: $accent_hi; font-weight: bold; font-size: 14px; }
.body, .notification-body { color: $fg; }
.time { color: rgba($fg_rgb, 0.6); font-size: 11px; }
.close-button { background: rgba($fg_rgb, 0.12); color: $fg; border: none; border-radius: 12px; min-width: 24px; min-height: 24px; margin: 2px; padding: 0; box-shadow: none; }
.close-button:hover { background: $red; }
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
    import os, signal
    pr = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        pr.wait(timeout=15)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(pr.pid, signal.SIGKILL)
        except Exception:
            pr.kill()
        pr.wait()
        class _T:
            stdout = ""
            stderr = "timeout"
        return _T()
    class _R:
        stdout = ""
        stderr = ""
    return _R()

def apply(name):
    global THEMES
    if name == "Dynamic":
        subprocess.run([sys.executable, str(H / "scripts/dynamic-theme.py"), "--no-apply"])
        THEMES = json.load(open(H / ".config/themes/themes.json"))
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
    run("pkill", "-SIGUSR2", "waybar"); run(str(H / "scripts/swaync-mode.sh")); run("pkill", "-USR1", "kitty")
    r = run("hyprctl", "eval", 'hl.config({ general = { col = { active_border = "%s", inactive_border = "%s" } } })' % (act, ina))
    run("python3", str(H / "scripts/gtk-apply.py"), name)
    print("theme applied:", name, "| hyprland:", (r.stdout + r.stderr).strip())

# --- PARCHE-ANTI-DEADLOCK (no tocar) ---
# Redefine run()/run_cap() ANTES de __main__: en Python los nombres globales
# se resuelven al momento de la llamada, asi que apply() usa estas versiones.
# DEVNULL = sin pipes = sin deadlock con hijos en background.
# start_new_session = el hijo no comparte grupo de procesos con nosotros.
def run(*cmd):
    p = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, start_new_session=True)
    p.stdout = ""
    p.stderr = ""
    return p

def run_cap(*cmd):
    return subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True,
                          start_new_session=True, text=True)

if __name__ == "__main__":
    n = sys.argv[1] if len(sys.argv) > 1 else "Gruvbox"
    if n not in THEMES:
        sys.exit("unknown theme: %s (available: %s)" % (n, ", ".join(THEMES)))
    apply(n)
