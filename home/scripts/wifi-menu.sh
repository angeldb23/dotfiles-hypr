#!/usr/bin/env bash
# Panel de WiFi (Quickshell). Backup del menu viejo: wifi-menu.sh.bak-fuzzel
if ! qs -c wifi ipc call wifi toggle 2>/dev/null; then
  qs -c wifi -d
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.3
    qs -c wifi ipc call wifi toggle 2>/dev/null && exit 0
  done
fi
