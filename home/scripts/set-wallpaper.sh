#!/bin/bash
# Uso: set-wallpaper.sh /ruta/al/wallpaper
# Hace lo mismo que change-wallpaper.sh pero con el wallpaper que le pasas
img="$1"
[ -f "$img" ] || exit 1
STATE="$HOME/.cache/current_wallpaper.txt"
OPT_DIR="$HOME/.cache/wallfull"
echo "$img" > "$STATE"
opt="$OPT_DIR/$(basename "${img%.*}").jpg"
[ -f "$opt" ] && img="$opt"
pgrep -x awww-daemon >/dev/null || { setsid awww-daemon >/tmp/awww.log 2>&1 </dev/null & sleep 1; }
awww img "$img" --transition-type any --transition-fps 60 --transition-step 12

# Siempre regenerar Dynamic en themes.json cuando cambia el wallpaper
# Si el tema activo es Dynamic, también aplicarlo para actualizar shells
if [ "$(cat "$HOME/.cache/theme.txt" 2>/dev/null)" = "Dynamic" ]; then
    setsid flock "$HOME/.cache/dynamic-theme.lock" python3 "$HOME/scripts/dynamic-theme.py" >/dev/null 2>&1 </dev/null &
else
    setsid flock "$HOME/.cache/dynamic-theme.lock" python3 "$HOME/scripts/dynamic-theme.py" --no-apply >/dev/null 2>&1 </dev/null &
fi
