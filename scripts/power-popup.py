#!/usr/bin/env python3
import gi, os, subprocess
from themecolors import themed
import popupfix
popupfix.single()
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib
H = os.path.expanduser("~")
css = b"""
window#power { background-color: #1d2021; border-radius: 14px; }
button { background-color: #282828; border: 1px solid #504945; border-radius: 12px; padding: 14px 10px; }
button label { color: #d4be98; }
button:hover { background-color: #3c3836; }
button.lock:hover { background-color: #76946a; }
button.susp:hover { background-color: #d79921; }
button.reb:hover { background-color: #458588; }
button.off:hover { background-color: #c34043; }
button.lock:hover label, button.susp:hover label, button.reb:hover label, button.off:hover label { color: #1d2021; }
"""
prov = Gtk.CssProvider(); prov.load_from_data(themed(css))
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

def run(cmd):
    subprocess.Popen(cmd, start_new_session=True)
    GLib.timeout_add(150, Gtk.main_quit)

ACCIONES = [
    ("\uf023", "Lock",      "lock", [H + "/scripts/lock.sh"]),
    ("\uf186", "Suspend",     "susp", ["systemctl", "suspend"]),
    ("\uf021", "Restart",     "reb",  ["systemctl", "reboot"]),
    ("\uf011", "Shut down",        "off",  ["systemctl", "poweroff"]),
    ("\uf2f5", "Log out", "out",  ["hyprctl", "dispatch", "hl.dsp.exit()"]),
]

win = Gtk.Window(title="Power"); win.set_name("power")
win.set_decorated(False); win.set_resizable(False)
box = Gtk.Box(spacing=10)
box.set_margin_top(16); box.set_margin_bottom(16); box.set_margin_start(16); box.set_margin_end(16)
for icon, text, cls, cmd in ACCIONES:
    v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    i = Gtk.Label(); i.set_markup('<span size="24000">%s</span>' % icon)
    t = Gtk.Label(label=text)
    v.pack_start(i, False, False, 0); v.pack_start(t, False, False, 0)
    b = Gtk.Button(); b.add(v); b.set_size_request(92, -1)
    b.get_style_context().add_class(cls)
    b.connect("clicked", lambda _b, c=cmd: run(c))
    box.pack_start(b, False, False, 0)
win.add(box)
win.connect("key-press-event", lambda w, e: Gtk.main_quit() if e.keyval == Gdk.KEY_Escape else None)
win.connect("destroy", Gtk.main_quit)
win.show_all()
popupfix.watch("Power")
Gtk.main()
