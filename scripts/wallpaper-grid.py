#!/usr/bin/env python3
from themecolors import themed
# Menu flotante de wallpapers: grilla chica, redondeada, foto + nombre
import os, glob, subprocess
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, Pango

WALL_DIR  = os.path.expanduser("~/wallpapers")
THUMB_DIR = os.path.expanduser("~/.cache/wallthumbs")
STATE     = os.path.expanduser("~/.cache/current_wallpaper.txt")
os.makedirs(THUMB_DIR, exist_ok=True)

exts = ("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG")
imgs  = sorted({f for e in exts for f in glob.glob(os.path.join(WALL_DIR, e))})
names = [os.path.basename(p) for p in imgs]

css = b"""
window#wpicker { background-color: #1d2021; border-radius: 14px; }
.scrolled      { background-color: #1d2021; }
.tile          { background-color: #282828; border-radius: 10px;
                 padding: 6px; margin: 4px; }
.tile:hover    { background-color: #3c3836; }
flowboxchild:selected { background-color: #504945; border-radius: 10px; }
.tile label    { color: #d4be98; font-size: 11px; padding-top: 4px; }
"""
prov = Gtk.CssProvider()
prov.load_from_data(themed(css))
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

def ensure_thumb(path):
    name  = os.path.basename(path)
    thumb = os.path.join(THUMB_DIR, os.path.splitext(name)[0] + ".png")
    if os.path.exists(thumb):
        return thumb
    try:
        subprocess.run(["gdk-pixbuf-thumbnailer", "-s", "240", path, thumb],
                       check=True, stderr=subprocess.DEVNULL)
        return thumb
    except Exception:
        return path

def ensure_daemon():
    if subprocess.run(["pgrep", "-x", "awww-daemon"], capture_output=True).returncode != 0:
        subprocess.Popen(["setsid", "awww-daemon"], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        import time; time.sleep(1)

def pick(name):
    path = os.path.join(WALL_DIR, name)
    with open(STATE, "w") as f:
        f.write(path)
    ensure_daemon()
    if subprocess.run(["pgrep", "-x", "awww-daemon"],
                      capture_output=True).returncode == 0:
        subprocess.Popen(["awww", "img", path, "--transition-type", "any",
                          "--transition-fps", "60", "--transition-step", "12"])
    else:
        subprocess.run(["pkill", "-x", "swaybg"])
        subprocess.Popen(["swaybg", "-i", path, "-m", "fill"],
                         start_new_session=True)
    Gtk.main_quit()

win = Gtk.Window(title="Wallpapers")
win.set_name("wpicker")
win.set_decorated(False)
win.set_resizable(False)
win.set_default_size(690, 430)
win.set_position(Gtk.WindowPosition.CENTER)

flow = Gtk.FlowBox()
flow.set_min_children_per_line(3)
flow.set_max_children_per_line(3)
flow.set_row_spacing(6)
flow.set_column_spacing(6)
flow.set_margin_top(12)
flow.set_margin_bottom(12)
flow.set_margin_start(12)
flow.set_margin_end(12)
flow.set_selection_mode(Gtk.SelectionMode.SINGLE)
flow.set_activate_on_single_click(True)

for path, name in zip(imgs, names):
    try:
        pb = GdkPixbuf.Pixbuf.new_from_file_at_size(ensure_thumb(path), 200, 112)
    except Exception:
        continue
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.get_style_context().add_class("tile")
    box.add(Gtk.Image.new_from_pixbuf(pb))
    lab = Gtk.Label(label=name)
    lab.set_ellipsize(Pango.EllipsizeMode.END)
    box.add(lab)
    flow.add(box)

flow.connect("child-activated", lambda f, child: pick(names[child.get_index()]))

sw = Gtk.ScrolledWindow()
sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
sw.get_style_context().add_class("scrolled")
sw.add(flow)
win.add(sw)

def on_key(w, ev):
    if ev.keyval == Gdk.KEY_Escape:
        Gtk.main_quit()
win.connect("key-press-event", on_key)
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
