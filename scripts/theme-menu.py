#!/usr/bin/env python3
from themecolors import themed
import gi, json, subprocess, pathlib
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk
H = pathlib.Path.home()
T = json.load(open(H / ".config/themes/themes.json"))
try: cur = (H / ".cache/theme.txt").read_text().strip()
except Exception: cur = ""
css = b"""
window#tpicker { background-color: #1d2021; border-radius: 14px; }
button.theme { background: #282828; color: #d4be98; border: none; border-radius: 10px; padding: 10px 16px; }
button.theme:hover { background: #3c3836; }
"""
prov = Gtk.CssProvider(); prov.load_from_data(themed(css))
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
win = Gtk.Window(title="Themes"); win.set_name("tpicker"); win.set_decorated(False); win.set_resizable(False)
box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
box.set_margin_top(14); box.set_margin_bottom(14); box.set_margin_start(14); box.set_margin_end(14)
def pick(_b, name):
    subprocess.Popen(["python3", str(H / "scripts/theme-set.py"), name]); Gtk.main_quit()
for name, p in T.items():
    sw = "".join('<span foreground="%s">██</span>' % p[k] for k in ("bg", "accent", "c1", "c2", "c4"))
    lab = Gtk.Label(); lab.set_markup("%s %s   %s" % ("●" if name == cur else "  ", name, sw)); lab.set_xalign(0)
    b = Gtk.Button(); b.get_style_context().add_class("theme"); b.add(lab)
    b.connect("clicked", pick, name); box.pack_start(b, False, False, 0)
win.add(box); win.set_default_size(300, -1)
win.connect("key-press-event", lambda w, e: Gtk.main_quit() if e.keyval == Gdk.KEY_Escape else None)
win.connect("destroy", Gtk.main_quit); win.show_all(); Gtk.main()
