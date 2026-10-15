#!/bin/bash

WALL_DIR="$HOME/wallpapers"
STATE="$HOME/.cache/current_wallpaper.txt"

mkdir -p "$WALL_DIR" "$HOME/.cache/awww"

# Usar el wallpaper guardado si existe
img=$(cat "$STATE" 2>/dev/null)

# Si no existe, elegir el primer wallpaper disponible
if [ -z "$img" ] || [ ! -f "$img" ]; then
    img=$(find "$WALL_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | sort | head -n 1)

    [ -z "$img" ] && exit 0

    printf '%s\n' "$img" > "$STATE"
fi

# Arrancar awww si todavía no está corriendo
if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon >/tmp/awww.log 2>&1 &
    sleep 1
fi

awww img "$img" \
    --transition-type simple \
    --transition-fps 60 \
    --transition-step 2
