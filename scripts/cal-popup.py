#!/usr/bin/env python3
from themecolors import themed
# Floating calendar (gruvbox)
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk
import subprocess, json, atexit

def _opt(name):
    try:
        return json.loads(subprocess.run(["hyprctl", "getoption", "input:" + name, "-j"],
                                         capture_output=True, text=True).stdout)["int"]
    except Exception:
        return None

def hl_set(fm, fso):
    subprocess.run(["hyprctl", "eval",
                    f"hl.config({{ input = {{ follow_mouse = {fm}, float_switch_override_focus = {fso} }} }})"],
                   capture_output=True)

import os
_otros = [x for x in subprocess.run(["pgrep", "-f", "python3 .*cal-popup.py"],
                                    capture_output=True, text=True).stdout.split() if int(x) != os.getpid()]
if _otros:
    for x in _otros:
        os.kill(int(x), 15)
    raise SystemExit(0)

hl_set(2, 0)
atexit.register(lambda: hl_set(1, 1))

css = b"""
window#calpop { background-color: #1d2021; border-radius: 14px; }
calendar {
  background-color: #1d2021;
  color: #d4be98;
  padding: 6px;
  font-size: 11px;
}
calendar.header {
  background-color: #282828;
  color: #e9b45b;
  border-radius: 8px;
}
calendar.button { background-color: #282828; color: #e9b45b; }
calendar:selected {
  background-color: #d79921;
  color: #1d2021;
  border-radius: 8px;
  font-weight: bold;
}
calendar:indeterminate { color: #665c54; }
calendar.highlight { color: #e9b45b; }
"""
prov = Gtk.CssProvider()
prov.load_from_data(themed(css))
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

win = Gtk.Window(title="Calendar")
win.set_name("calpop")
win.set_decorated(False)
win.set_resizable(False)
win.add(Gtk.Calendar())

from gi.repository import GLib
import time
LOG = open("/tmp/cal.log", "w", buffering=1)
def log(m): LOG.write(time.strftime("%H:%M:%S") + " " + m + "\n")
_seen = {"v": False, "t": 0}

def _check():
    try:
        out = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True).stdout
        title = json.loads(out).get("title", "") if out.strip() else ""
        fm = subprocess.run(["hyprctl", "getoption", "input:follow_mouse"], capture_output=True, text=True).stdout.split("\n")[0]
    except Exception as e:
        log("error " + str(e))
        return True
    _seen["t"] += 1
    log("tick %d activa='%s' %s" % (_seen["t"], title, fm))
    if title == "Calendar":
        _seen["v"] = True
    elif _seen["v"] or _seen["t"] > 15:
        log("CIERRA por polling")
        Gtk.main_quit()
        return False
    return True

win.connect("focus-in-event", lambda *a: log("focus-in"))
win.connect("focus-out-event", lambda *a: log("focus-out"))
win.connect("delete-event", lambda *a: log("delete-event"))
GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, 15, lambda: (log("SIGTERM recibido (alguien lo mato)"), Gtk.main_quit(), False)[2])
GLib.timeout_add(200, _check)
def on_key(w, ev):
    if ev.keyval == Gdk.KEY_Escape:
        Gtk.main_quit()
win.connect("key-press-event", on_key)
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
