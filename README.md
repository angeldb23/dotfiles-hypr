# Hyprland rice

Hyprland setup with a live theme switcher, floating GTK popups, a Waybar in "islands" style and a Mac-style lock screen.
Built and tuned on a low-end laptop (Intel Celeron, 4 GB RAM, 1366x768), so everything is kept light.

<!-- add your screenshots here -->

## What is in here

- **Theme switcher** (`Super+T`): 10 themes (Catppuccin, Kanagawa, Gruvbox, Tokyo Night, Rose Pine, Nord, Dracula, Everforest, One Dark, Solarized Dark). One command recolors Waybar, SwayNC, fuzzel, kitty, GTK apps (Thunar), the lock screen, the popups and the window borders. Palettes live in `.config/themes/themes.json`.
- **Waybar "islands"**: every module is its own floating pill; volume and brightness have hover sliders.
- **Floating popups** (GTK3 + Python): volume with output selector, brightness, calendar, power menu, screenshot actions, wallpaper picker, WiFi menu.
- **Lock screen** (hyprlock + hypridle): Mac-style clock, pre-blurred wallpaper so it opens instantly, follows the active theme.
- **Clipboard history** with cliphist + fuzzel.

## Install

    git clone <this repo> && cd <this repo>
    ./install.sh
    ~/scripts/theme-set.py Kanagawa

`install.sh` backs up your existing `~/.config/{hypr,waybar,...}` and `~/scripts` first.
Wallpapers are not included: check `scripts/wallpaper-grid.py` for the folder it reads.

## Dependencies (check the scripts if something is missing)

hyprland (Lua config), waybar, kitty, fuzzel, swaync, hyprlock, hypridle, cliphist, wl-clipboard, python3-gi (GTK3), NetworkManager (nmcli), pavucontrol, wireplumber (wpctl), CaskaydiaCove Nerd Font.

## Keybinds

| Keys | Action |
|---|---|
| `Super + Q` | `hl.dsp.exec_cmd` |
| `Super + C` | `hl.dsp.window.close` |
| `Super + M` | `hl.dsp.exit` |
| `Super + E` | `hl.dsp.exec_cmd` |
| `Super + V` | `hl.dsp.window.float` |
| `Super + R` | `hl.dsp.exec_cmd` |
| `Super + P` | `hl.dsp.window.pseudo` |
| `Super + J` | `hl.dsp.layout` |
| `Super + left` | `hl.dsp.focus` |
| `Super + right` | `hl.dsp.focus` |
| `Super + up` | `hl.dsp.focus` |
| `Super + down` | `hl.dsp.focus` |
| `Super + mouse_down` | `hl.dsp.focus` |
| `Super + mouse_up` | `hl.dsp.focus` |
| `Super + mouse:272` | `hl.dsp.window.drag` |
| `Super + mouse:273` | `hl.dsp.window.resize` |
| `XF86AudioRaiseVolume` | `hl.dsp.exec_cmd` |
| `XF86AudioLowerVolume` | `hl.dsp.exec_cmd` |
| `XF86AudioMute` | `hl.dsp.exec_cmd` |
| `XF86AudioMicMute` | `hl.dsp.exec_cmd` |
| `XF86MonBrightnessUp` | `hl.dsp.exec_cmd` |
| `XF86MonBrightnessDown` | `hl.dsp.exec_cmd` |
| `XF86AudioNext` | `hl.dsp.exec_cmd` |
| `XF86AudioPause` | `hl.dsp.exec_cmd` |
| `XF86AudioPlay` | `hl.dsp.exec_cmd` |
| `XF86AudioPrev` | `hl.dsp.exec_cmd` |
| `Super + W` | `wallpaper-grid.py` |
| `Super + SHIFT + W` | `change-wallpaper.sh` |
| `Super + S` | `show-desktop.sh` |
| `PRINT` | `screenshot.sh` |
| `SHIFT + PRINT` | `screenshot.sh` |
| `CTRL + PRINT` | `screenshot.sh` |
| `Super + SHIFT + S` | `screenshot.sh` |
| `Super + TAB` | `hl.dsp.focus` |
| `Super + SHIFT + TAB` | `hl.dsp.focus` |
| `Super + F` | `hl.dsp.window.fullscreen` |
| `Super + SHIFT + F` | `hl.dsp.window.fullscreen` |
| `Super + SHIFT + left` | `hl.dsp.window.move` |
| `Super + SHIFT + right` | `hl.dsp.window.move` |
| `Super + SHIFT + up` | `hl.dsp.window.move` |
| `Super + SHIFT + down` | `hl.dsp.window.move` |
| `Super + T` | `theme-menu.py` |
| `Super + SHIFT + V` | `clip-menu.sh` |
| `Super + L` | `lock.sh` |

Some binds (like the workspace ones) are generated in loops: see `hyprland.lua`.

## Credits

Waybar islands style inspired by [binnewbs/arch-hyprland](https://github.com/binnewbs/arch-hyprland) (itself based on JaKooLit's dotfiles).
