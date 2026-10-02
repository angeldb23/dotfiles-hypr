#!/usr/bin/env bash
# Copies the configs to ~/.config and the scripts to ~/scripts, backing up whatever was there.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
BK="$HOME/dotfiles-backup-$(date +%F-%H%M)"; mkdir -p "$BK"
for d in hypr waybar swaync fuzzel kitty themes gtk-3.0 gtk-4.0; do
  if [ -d "$SRC/.config/$d" ]; then
    if [ -e "$HOME/.config/$d" ]; then cp -a "$HOME/.config/$d" "$BK/"; fi
    mkdir -p "$HOME/.config/$d"; cp -a "$SRC/.config/$d/." "$HOME/.config/$d/"
  fi
done
if [ -e "$HOME/scripts" ]; then cp -a "$HOME/scripts" "$BK/scripts"; fi
mkdir -p "$HOME/scripts"; cp -a "$SRC/scripts/." "$HOME/scripts/"
chmod +x "$HOME"/scripts/*.py "$HOME"/scripts/*.sh 2>/dev/null || true
echo "Done. Your previous config is in $BK"
echo "Next: ~/scripts/theme-set.py Kanagawa   (pick any theme), then log out and back in."
