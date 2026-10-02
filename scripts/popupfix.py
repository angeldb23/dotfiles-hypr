import gi
gi.require_version("Gtk", "3.0")
import os, sys, json, signal, atexit, subprocess
from gi.repository import Gtk, GLib

def _hl(fm, fso):
    subprocess.run(["hyprctl", "eval",
        "hl.config({ input = { follow_mouse = %d, float_switch_override_focus = %d } })" % (fm, fso)],
        capture_output=True)

def single():
    me = os.getpid()
    name = os.path.basename(sys.argv[0])
    out = subprocess.run(["pgrep", "-f", "python3 .*" + name], capture_output=True, text=True).stdout.split()
    otros = [int(x) for x in out if int(x) != me]
    if otros:
        for x in otros:
            try: os.kill(x, signal.SIGTERM)
            except Exception: pass
        _hl(1, 1)
        raise SystemExit(0)

def watch(title):
    st = {"seen": False, "t": 0}
    _hl(2, 0)
    atexit.register(lambda: _hl(1, 1))
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: (Gtk.main_quit(), False)[1])
    def check():
        try:
            o = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True).stdout
            t = json.loads(o).get("title", "") if o.strip() else ""
        except Exception:
            return True
        st["t"] += 1
        if t == title:
            st["seen"] = True
        elif st["seen"] or st["t"] > 10:
            Gtk.main_quit(); return False
        return True
    GLib.timeout_add(300, check)
