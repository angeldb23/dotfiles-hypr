#!/usr/bin/env bash
DEST="$(cd "$(dirname "$0")" && pwd)"
cd "$HOME" || exit 1

PATHS=(
  .config/hypr .config/waybar .config/kitty .config/fuzzel .config/swaync
  .config/fastfetch .config/starship.toml .config/themes
  .config/gtk-3.0/settings.ini .config/gtk-4.0
  .config/fontconfig/conf.d/60-apple-emoji.conf
  .config/autostart/nm-applet.desktop
  scripts .zshrc
)
for p in "${PATHS[@]}"; do
  if [ -e "$p" ]; then cp -a --parents "$p" "$DEST/"; else echo "no existe: $p"; fi
done

mkdir -p "$DEST/system/udev"
cp /etc/udev/rules.d/*.rules "$DEST/system/udev/" 2>/dev/null

pacman -Qqen > "$DEST/packages-pacman.txt"
pacman -Qqem > "$DEST/packages-aur.txt"

find "$DEST" \( -name '*.bak*' -o -name '*before-*' -o -name '__pycache__' \) -not -path '*/.git/*' -prune -exec rm -rf {} +
echo "Listo: $DEST"
