#!/usr/bin/env bash
# Alterna barra Quickshell (qs) y waybar. Uso: bar-toggle.sh [qs|waybar|restore|status]
MODE_FILE="$HOME/.cache/bar-mode.txt"
WARM_FILE="$HOME/.cache/bar-warm.txt"
QS_PAT="(quickshell|qs) -c (bar|notifs|settings|launcher|wifi)"
cur=$(cat "$MODE_FILE" 2>/dev/null || echo waybar)

kill_qs_all() {
  pkill -f "$QS_PAT" 2>/dev/null
  local i=0
  while [ $i -lt 10 ] && pgrep -f "$QS_PAT" >/dev/null 2>&1; do
    sleep 0.1; i=$((i+1))
  done
  pkill -9 -f "$QS_PAT" 2>/dev/null
}

kill_waybar_all() {
  pkill -x waybar 2>/dev/null
  pkill -x swaync 2>/dev/null
  local i=0
  while [ $i -lt 10 ] && pgrep -x waybar >/dev/null 2>&1; do
    sleep 0.1; i=$((i+1))
  done
  pkill -9 -x waybar 2>/dev/null
  pkill -9 -x swaync 2>/dev/null
}

use_qs() {
  kill_waybar_all
  kill_qs_all
  echo qs > "$MODE_FILE"
  qs -c notifs -d >/dev/null 2>&1
  qs -c bar -d >/dev/null 2>&1
  if [ "$(cat "$WARM_FILE" 2>/dev/null)" = "on" ]; then
    qs -c launcher -d >/dev/null 2>&1
  fi
  ( sleep 1; python3 "$HOME/scripts/qs-settings.py" apply >/dev/null 2>&1 ) &
}

use_waybar() {
  kill_qs_all
  kill_waybar_all
  echo waybar > "$MODE_FILE"
  setsid waybar >/dev/null 2>&1 &
  setsid swaync >/dev/null 2>&1 &
  [ -x "$HOME/scripts/swaync-mode.sh" ] && "$HOME/scripts/swaync-mode.sh" >/dev/null 2>&1 &
}

case "$1" in
  qs) use_qs ;;
  waybar) use_waybar ;;
  restore) [ "$cur" = "qs" ] && use_qs || use_waybar ;;
  status) echo "$cur" ;;
  *) [ "$cur" = "qs" ] && use_waybar || use_qs ;;
esac
