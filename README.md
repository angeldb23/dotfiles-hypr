# dotfiles-hypr

My Hyprland setup on Arch Linux, tuned for a low-end laptop (Intel Celeron N4020, 4 GB RAM, 1366x768).

It is written for **Hyprland 0.56.2 using the Lua config** (`hyprland.lua`), so it will not work as-is with the older `hyprland.conf` format.

## What's inside

| Component | Config |
|---|---|
| Hyprland (window manager) | `.config/hypr/hyprland.lua`, `hypridle.conf` |
| Waybar (top bar) | `.config/waybar/` |
| Kitty (terminal) | `.config/kitty/` |
| Fuzzel (launcher and menus) | `.config/fuzzel/` |
| SwayNC (notifications) | `.config/swaync/` |
| Fastfetch | `.config/fastfetch/` |
| Starship prompt | `.config/starship.toml` (generated, see below) |
| zsh + eza | `.zshrc` |
| Wallpapers (awww) | `scripts/wallpaper-*.sh`, `scripts/wallpaper-grid.py` |
| Helper scripts | `scripts/` |

## Highlights

- **One theme selector for everything.** `Super + T` opens a theme menu. A single palette file (`~/.config/themes/themes.json`) is used to re-color window borders, Waybar, Kitty, SwayNC, Fuzzel, the Starship prompt and the `eza` colors.
- **Show Desktop** (`Super + S`). Windows fade out and back in without any resize or re-layout. Instead of moving windows to a special workspace (which makes dwindle rebuild its layout), the script sets their opacity to 0 and restores it later. This relies on `decoration.blur.ignore_opacity = false`.
- **Persistent wallpaper.** The chosen wallpaper is saved to `~/.cache/current_wallpaper.txt` and restored at login by `wallpaper-init.sh`. Wallpapers are expected in `~/wallpapers` (not included in this repo).
- **Pastel powerline prompt** with Starship, using the active theme's colors.
- **Idle behaviour.** `hypridle` is set to never dim the screen, turn it off or suspend automatically.

## Keybindings (main ones)

| Keys | Action |
|---|---|
| `Super + Q` | Terminal |
| `Super + E` | File manager |
| `Super + R` | App launcher |
| `Super + S` | Show desktop (toggle) |
| `Super + W` | Wallpaper grid |
| `Super + Shift + W` | Random wallpaper |
| `Super + T` | Theme menu |
| `Super + Shift + V` | Clipboard history |
| `Super + L` | Lock screen |
| `Print` / `Shift + Print` / `Ctrl + Print` | Screenshot / area / to clipboard |

The full list is in `.config/hypr/hyprland.lua`.

## Install

The files mirror the layout of `$HOME`, so installing is mostly copying.

```bash
git clone https://github.com/angeldb23/dotfiles-hypr.git ~/dotfiles-hypr
cd ~/dotfiles-hypr

# 1) Packages (review the lists first, they include everything I installed explicitly)
sudo pacman -S --needed - < packages-pacman.txt
yay -S --needed $(cat packages-aur.txt)    # or paru

# 2) Back up your current config, then copy mine
mkdir -p ~/config-backup
cp -a ~/.config ~/.zshrc ~/config-backup/ 2>/dev/null
cp -a .config scripts .zshrc ~/

# 3) Use zsh as the login shell
chsh -s "$(command -v zsh)"

# 4) Put some wallpapers in ~/wallpapers, then log out and back in
```

## Notes

- Wallpapers and icon themes are not included.
- The package lists were generated with `pacman -Qqen` and `pacman -Qqem`.

## Updating this repo

`sync.sh` copies the current config from the system into this folder:

```bash
./sync.sh && git add -A && git commit -m "update" && git push
```
## Warning: built-in laptop keyboard is disabled

`.config/hypr/hyprland.lua` turns off the laptop's internal keyboard, because I use an external USB keyboard:

    hl.device({ name = "at-translated-set-2-keyboard", enabled = false })

If you clone this on another machine, **comment out that line (add `--` at the start) before applying the config**, or you may be left without a working keyboard. The device name may also differ on your hardware; check it with:

    hyprctl devices -j | jq -r '.keyboards[].name'

The config also sets `disable_while_typing = false` inside the `touchpad` block. Without it, the touchpad stopped responding while the internal keyboard was disabled.

If you get locked out, switch to a TTY with `Ctrl+Alt+F3` and edit the file from there.
