#!/usr/bin/env bash
if ! qs -c launcher ipc call launcher wallpapers 2>/dev/null; then
  qs -c launcher -d
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.3
    qs -c launcher ipc call launcher wallpapers 2>/dev/null && exit 0
  done
fi
