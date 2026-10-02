#!/bin/bash
STATE="/tmp/current_wallpaper.txt"
img=$(cat "$STATE" 2>/dev/null)
[ -z "$img" ] && img="$HOME/wallpapers/kanagawa.jpg"
if command -v awww-daemon >/dev/null 2>&1; then
    awww-daemon &
    sleep 1
    awww img "$img" --transition-type simple --transition-fps 60 --transition-step 2
else
    swaybg -i "$img" -m fill &
fi
