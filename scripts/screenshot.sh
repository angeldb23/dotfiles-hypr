#!/bin/bash
TS=$(date +%Y%m%d_%H%M%S)
TMP="/tmp/shot_$TS.png"
case "$1" in
  area) grim -g "$(slurp)" "$TMP" || exit 0 ;;
  clip) grim -g "$(slurp)" - | wl-copy --type image/png
        notify-send "Screenshot" "Copied to clipboard"
        exit 0 ;;
  *)    grim "$TMP" || exit 0 ;;
esac
python3 "$HOME/scripts/screenshot-popup.py" "$TMP"
