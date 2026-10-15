#!/usr/bin/env python3
from themecolors import themed
# Floating brightness slider
import subprocess
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

def current():
    try:
        g = int(subprocess.check_output(["brightnessctl", "get"]))
        m = int(subprocess.check_output(["brightnessctl", "max"]))
        return max(1, round(g * 100 / m))
    except Exception:
        return 50

def setb(v):
    subprocess.run(["brightnessctl", "set", f"{int(v)}%"])

css = b"""
window { background-color: #282828; border-radius: 12px; }
scale { padding: 8px; }
scale trough { background-color: #3c3836; border-radius: 6px; min-height: 10px; }
scale highlight { background-color: #d79921; border-radius: 6px; }
scale slider { background-color: #ebdbb2; min-width: 16px; min-height: 16px;
               border-radius: 8px; margin: -4px; }
"""
prov = Gtk.CssProvider()
prov.load_from_data(themed(css))
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

win = Gtk.Window(title="Brightness")
win.set_decorated(False)
win.set_resizable(False)
win.set_default_size(340, 60)
win.set_position(Gtk.WindowPosition.CENTER)

adj = Gtk.Adjustment(value=current(), lower=1, upper=100,
                     step_increment=1, page_increment=10)
sc = Gtk.Scale.new(Gtk.Orientation.HORIZONTAL, adj)
sc.set_draw_value(True)
sc.set_value_pos(Gtk.PositionType.RIGHT)
sc.connect("value-changed", lambda s: setb(s.get_value()))
sc.set_margin_top(10); sc.set_margin_bottom(10)
sc.set_margin_start(14); sc.set_margin_end(14)
win.add(sc)

win.connect("focus-out-event", lambda *a: Gtk.main_quit())
def on_key(w, ev):
    if ev.keyval == Gdk.KEY_Escape:
        Gtk.main_quit()
win.connect("key-press-event", on_key)
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
