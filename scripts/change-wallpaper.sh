#!/bin/bash
WALL_DIR="$HOME/wallpapers"
OPT_DIR="$HOME/.cache/wallfull"
STATE="$HOME/.cache/current_wallpaper.txt"
pgrep -x awww-daemon >/dev/null || { setsid awww-daemon >/tmp/awww.log 2>&1 </dev/null & sleep 1; }
mapfile -t wallpapers < <(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | sort)
[ ${#wallpapers[@]} -eq 0 ] && exit 1
current=""; [ -f "$STATE" ] && current=$(cat "$STATE")
idx=-1
for i in "${!wallpapers[@]}"; do [[ "${wallpapers[$i]}" == "$current" ]] && idx=$i && break; done
if [ ${#wallpapers[@]} -gt 1 ]; then
  next=$idx
  while [ "$next" = "$idx" ]; do next=$((RANDOM % ${#wallpapers[@]})); done
else
  next=0
fi
img="${wallpapers[$next]}"
echo "$img" > "$STATE"
opt="$OPT_DIR/$(basename "${img%.*}").jpg"
[ -f "$opt" ] && img="$opt"
if command -v awww >/dev/null 2>&1 && pgrep -x awww-daemon >/dev/null; then
  awww img "$img" --transition-type any --transition-fps 60 --transition-step 12
else
  pkill -x swaybg
  swaybg -i "$img" -m fill &
fi
