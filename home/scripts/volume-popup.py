#!/usr/bin/env python3
import gi, json, re, subprocess
from themecolors import themed
import popupfix
popupfix.single()
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Pango

def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout

def get_vol():
    o = sh("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")
    m = re.search(r"([0-9.]+)", o)
    return (int(round(float(m.group(1)) * 100)) if m else 0), ("MUTED" in o)

def get_sinks():
    try:
        return [(d["name"], d.get("description") or d["name"])
                for d in json.loads(sh("pactl", "--format=json", "list", "sinks"))]
    except Exception:
        return []

css = b"""
window#volpop { background-color: #1d2021; border-radius: 14px; }
label { color: #d4be98; font-size: 12px; }
.title { color: #e9b45b; font-size: 13px; font-weight: bold; }
.pct { color: #e9b45b; font-weight: bold; }
.seccion { color: #e9b45b; font-size: 11px; padding-top: 6px; }
scale trough { background-color: #3c3836; border-radius: 6px; min-height: 10px; }
scale highlight { background-color: #d79921; border-radius: 6px; }
scale slider { background-color: #ebdbb2; min-width: 16px; min-height: 16px; border-radius: 8px; }
button { background-color: #282828; color: #d4be98; border: 1px solid #504945; border-radius: 10px; padding: 6px 12px; }
button:hover { background-color: #3c3836; }
"""
prov = Gtk.CssProvider(); prov.load_from_data(themed(css))
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

win = Gtk.Window(title="Volume"); win.set_name("volpop")
win.set_decorated(False); win.set_resizable(False); win.set_default_size(340, -1)
box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
box.set_margin_top(16); box.set_margin_bottom(16); box.set_margin_start(16); box.set_margin_end(16)

head = Gtk.Box(spacing=8)
t = Gtk.Label(label="Volume"); t.get_style_context().add_class("title"); t.set_xalign(0)
pct = Gtk.Label(label="0%"); pct.get_style_context().add_class("pct")
head.pack_start(t, True, True, 0); head.pack_end(pct, False, False, 0)
box.pack_start(head, False, False, 0)

scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
scale.set_draw_value(False)
box.pack_start(scale, False, False, 0)

mute = Gtk.Button(label="Mute")
box.pack_start(mute, False, False, 0)

sec = Gtk.Label(label="Audio output"); sec.get_style_context().add_class("seccion"); sec.set_xalign(0)
box.pack_start(sec, False, False, 0)
sink_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
box.pack_start(sink_box, False, False, 0)

pending = [None]
def apply_vol():
    subprocess.Popen(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "%d%%" % int(scale.get_value())])
    pending[0] = None
    return False

def on_change(s):
    pct.set_text("%d%%" % int(s.get_value()))
    if pending[0]:
        GLib.source_remove(pending[0])
    pending[0] = GLib.timeout_add(50, apply_vol)
hid = scale.connect("value-changed", on_change)

def refresh():
    v, m = get_vol()
    scale.handler_block(hid); scale.set_value(v); scale.handler_unblock(hid)
    pct.set_text("%d%%" % v)
    mute.set_label("Unmute" if m else "Mute")

def toggle_mute(_b):
    subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); refresh()
mute.connect("clicked", toggle_mute)

def pick(_b, name):
    subprocess.run(["pactl", "set-default-sink", name]); build_sinks(); refresh()

def build_sinks():
    for c in sink_box.get_children():
        sink_box.remove(c)
    cur = sh("pactl", "get-default-sink").strip()
    for name, desc in get_sinks():
        lab = Gtk.Label(label=("●  " if name == cur else "    ") + desc)
        lab.set_xalign(0); lab.set_ellipsize(Pango.EllipsizeMode.END); lab.set_max_width_chars(34)
        b = Gtk.Button(); b.add(lab); b.connect("clicked", pick, name)
        sink_box.pack_start(b, False, False, 0)
    sink_box.show_all()

refresh(); build_sinks()
win.add(box)
win.connect("key-press-event", lambda w, e: Gtk.main_quit() if e.keyval == Gdk.KEY_Escape else None)
win.connect("destroy", Gtk.main_quit)
win.show_all()
popupfix.watch("Volume")
Gtk.main()
