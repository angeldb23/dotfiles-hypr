#!/usr/bin/env python3
from themecolors import themed
# Screenshot popup: save / copy / delete
import sys, os, shutil, subprocess
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gtk, Gdk, GdkPixbuf

tmp = sys.argv[1]
ts  = os.path.basename(tmp)[5:-4]
DIR = os.path.join(os.popen("xdg-user-dir PICTURES").read().strip() or os.path.expanduser("~/Pictures"), "Screenshots")
os.makedirs(DIR, exist_ok=True)

css = b"""
window#shotpop { background-color: #1d2021; border-radius: 14px; }
.inner { padding: 12px; }
.title { color: #e9b45b; font-size: 13px; font-weight: bold; padding-bottom: 8px; }
.preview { border: 1px solid #504945; border-radius: 10px; }
button {
  background-color: #282828; color: #d4be98;
  border: 1px solid #504945; border-radius: 10px;
  padding: 8px 14px; margin: 4px; font-size: 13px;
}
button:hover { background-color: #3c3836; }
button.save:hover { background-color: #76946a; color: #1d2021; border-color: #76946a; }
button.copy:hover { background-color: #458588; color: #1d2021; border-color: #458588; }
button.del:hover  { background-color: #c34043; color: #1d2021; border-color: #c34043; }
"""
prov = Gtk.CssProvider()
prov.load_from_data(themed(css))
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

def notify(msg):
    subprocess.Popen(["notify-send", "Screenshot", msg])

def do_save(*_):
    os.makedirs(DIR, exist_ok=True)
    shutil.move(tmp, os.path.join(DIR, f"captura_{ts}.png"))
    notify("Saved to Pictures/Screenshots")
    Gtk.main_quit()

def do_copy(*_):
    with open(tmp, "rb") as f:
        subprocess.run(["wl-copy", "--type", "image/png"], stdin=f)
    os.remove(tmp)
    notify("Copied to clipboard")
    Gtk.main_quit()

def do_del(*_):
    if os.path.exists(tmp):
        os.remove(tmp)
    Gtk.main_quit()

win = Gtk.Window(title="Screenshot")
win.set_name("shotpop")
win.set_decorated(False)
win.set_resizable(False)
win.set_position(Gtk.WindowPosition.CENTER)

box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
box.get_style_context().add_class("inner")

lab = Gtk.Label(label="Screenshot ready")
lab.get_style_context().add_class("title")
box.add(lab)

try:
    pb = GdkPixbuf.Pixbuf.new_from_file_at_size(tmp, 380, 214)
    img = Gtk.Image.new_from_pixbuf(pb)
    img.get_style_context().add_class("preview")
    box.add(img)
except Exception:
    pass

btns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
b_save = Gtk.Button(label="\uf0c7  Save")
b_copy = Gtk.Button(label="\uf0c5  Copy")
b_del  = Gtk.Button(label="\uf1f8  Delete")
b_save.get_style_context().add_class("save")
b_copy.get_style_context().add_class("copy")
b_del.get_style_context().add_class("del")
b_save.connect("clicked", do_save)
b_copy.connect("clicked", do_copy)
b_del.connect("clicked", do_del)
btns.add(b_save); btns.add(b_copy); btns.add(b_del)
box.add(btns)

win.add(box)
def on_key(w, ev):
    if ev.keyval == Gdk.KEY_Escape:
        Gtk.main_quit()
win.connect("key-press-event", on_key)
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
