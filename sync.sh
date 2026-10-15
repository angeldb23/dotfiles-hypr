#!/usr/bin/env bash
set -e
DEST="$HOME/dotfiles"

# Rutas a respaldar (relativas a $HOME). Agregá acá lo nuevo.
PATHS=(
  .config/hypr
  .config/waybar
  .config/swaync
  .config/fuzzel
  .config/kitty
  .config/quickshell
  .config/systemd/user
  .config/autostart
  .config/fastfetch
  .config/starship.toml
  .config/nvim
  .config/fontconfig
  scripts
  .zshrc
)

EXCLUDES=(
  --exclude='*.bak*' --exclude='*.old' --exclude='__pycache__'
  --exclude='node_modules' --exclude='.git' --exclude='*.pyc'
)

for p in "${PATHS[@]}"; do
  src="$HOME/$p"
  [ -e "$src" ] || { echo "SALTEADO (no existe): $p"; continue; }
  mkdir -p "$DEST/home/$(dirname "$p")"
  rsync -a --delete "${EXCLUDES[@]}" "$src" "$DEST/home/$(dirname "$p")/"
  echo "OK: $p"
done

# Temas de SDDM (viven fuera de $HOME)
mkdir -p "$DEST/system/sddm"
[ -d /usr/share/sddm/themes ] && rsync -a /usr/share/sddm/themes/ "$DEST/system/sddm/themes/" && echo "OK: sddm themes"
[ -d /etc/sddm.conf.d ] && rsync -a /etc/sddm.conf.d/ "$DEST/system/sddm/conf.d/" && echo "OK: sddm conf.d"
[ -f /etc/sddm.conf ] && cp /etc/sddm.conf "$DEST/system/sddm/" && echo "OK: sddm.conf"

echo "Listo."
