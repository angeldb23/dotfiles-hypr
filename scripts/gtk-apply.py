#!/usr/bin/env python3
import json, sys, pathlib
from string import Template
H = pathlib.Path.home()
T = json.load(open(H / ".config/themes/themes.json"))
name = sys.argv[1] if len(sys.argv) > 1 else (H / ".cache/theme.txt").read_text().strip()
v = T.get(name) or T["Gruvbox"]

GTK3 = """@define-color theme_bg_color $panel;
@define-color theme_fg_color $fg;
@define-color theme_base_color $bg;
@define-color theme_text_color $fg;
@define-color theme_selected_bg_color $accent;
@define-color theme_selected_fg_color $on_accent;
@define-color theme_unfocused_bg_color $panel;
@define-color theme_unfocused_fg_color $fg;
@define-color theme_unfocused_base_color $bg;
@define-color theme_unfocused_text_color $fg;
@define-color theme_unfocused_selected_bg_color $accent;
@define-color theme_unfocused_selected_fg_color $on_accent;
@define-color borders $border;
@define-color unfocused_borders $border;
@define-color insensitive_bg_color $panel;
@define-color insensitive_fg_color $dim;
@define-color content_view_bg $bg;
@define-color accent_color $accent;
@define-color accent_bg_color $accent;
@define-color accent_fg_color $on_accent;

window, .background { background-color: $panel; color: $fg; }
headerbar, .titlebar { background-image: none; background-color: $bg; color: $fg; border-color: $border; box-shadow: none; }
headerbar label, .titlebar label { color: $fg; }
.view, treeview.view, iconview, textview text, list, listview { background-color: $bg; color: $fg; }
.view:selected, treeview.view:selected, iconview:selected, row:selected, .view:selected:focus, flowboxchild:selected, list row:selected {
  background-color: $accent; color: $on_accent; }
entry, spinbutton, combobox button.combo { background-image: none; background-color: $bg; color: $fg; border-color: $border; }
entry:focus, spinbutton:focus { border-color: $accent; }
button { background-image: none; background-color: $sel; color: $fg; border-color: $border; box-shadow: none; text-shadow: none; }
button:hover { background-color: $border; }
button:checked, button:active, button.suggested-action { background-color: $accent; color: $on_accent; }
button.destructive-action { background-color: $red; color: $fg_bright; }
button:disabled { color: $dim; }
menu, .menu, .popup, popover, popover.background, .csd.popup { background-color: $panel; color: $fg; border-color: $border; }
menuitem:hover, menu menuitem:hover, modelbutton:hover { background-color: $accent; color: $on_accent; }
menuitem:hover label, menuitem:hover image { color: $on_accent; }
toolbar, .toolbar, statusbar, actionbar, .inline-toolbar { background-color: $panel; color: $fg; border-color: $border; }
.sidebar, placessidebar, placessidebar list, placessidebar row { background-color: $bg; color: $fg; }
placessidebar row:selected { background-color: $accent; color: $on_accent; }
notebook > header { background-color: $panel; border-color: $border; }
notebook > header tab:checked { background-color: $bg; color: $accent_hi; }
paned > separator { background-color: $border; }
separator { background-color: $border; }
scrollbar slider { background-color: $border; border-color: transparent; }
scrollbar slider:hover { background-color: $dim; }
scrollbar trough { background-color: transparent; }
progressbar progress, scale highlight { background-color: $accent; }
scale trough, progressbar trough { background-color: $sel; }
tooltip, tooltip.background { background-color: $bg; color: $fg; border: 1px solid $border; }
tooltip label { color: $fg; }
switch:checked { background-color: $accent; }
checkbutton check:checked, radiobutton radio:checked { background-color: $accent; color: $on_accent; }
"""

GTK4 = """@define-color accent_color $accent;
@define-color accent_bg_color $accent;
@define-color accent_fg_color $on_accent;
@define-color window_bg_color $panel;
@define-color window_fg_color $fg;
@define-color view_bg_color $bg;
@define-color view_fg_color $fg;
@define-color headerbar_bg_color $bg;
@define-color headerbar_fg_color $fg;
@define-color headerbar_border_color $border;
@define-color card_bg_color $sel;
@define-color card_fg_color $fg;
@define-color popover_bg_color $panel;
@define-color popover_fg_color $fg;
@define-color dialog_bg_color $panel;
@define-color dialog_fg_color $fg;
@define-color sidebar_bg_color $bg;
@define-color sidebar_fg_color $fg;
@define-color destructive_bg_color $red;
"""

for rel, tpl in ((".config/gtk-3.0/gtk.css", GTK3), (".config/gtk-4.0/gtk.css", GTK4)):
    f = H / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(Template(tpl).substitute(v))
print("gtk aplicado:", name)
