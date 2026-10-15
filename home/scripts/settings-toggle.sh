#!/usr/bin/env bash
# Abre/cierra la app de ajustes. Solo funciona con la barra nueva (Quickshell).
echo "$(date +%T.%N) invocado | modo=$(cat "$HOME/.cache/bar-mode.txt" 2>/dev/null) | corriendo=$(pgrep -f '(quickshell|qs) -c settings' | tr '\n' ' ') | PATH=$PATH" >> /tmp/settings-toggle.log
if [ "$(cat "$HOME/.cache/bar-mode.txt" 2>/dev/null)" != "qs" ]; then
  notify-send "Settings" "Disponible solo con la barra nueva (Super + B)"
  exit 0
fi
if pgrep -f "(quickshell|qs) -c settings" >/dev/null; then
  pkill -f "(quickshell|qs) -c settings"
else
  setsid qs -c settings >>/tmp/settings-toggle.log 2>&1 &
fi
