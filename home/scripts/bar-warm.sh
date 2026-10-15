#!/usr/bin/env bash
# on  = launcher qs prendido en modo qs (apertura instantanea, +~200 MB)
# off = launcher qs bajo demanda (ahorra, abre en ~1 s)
F="$HOME/.cache/bar-warm.txt"
case "$1" in
  on)     echo on  > "$F" ;;
  off)    echo off > "$F" ;;
  status) cat "$F" 2>/dev/null || echo off; exit 0 ;;
  *)      if [ "$(cat "$F" 2>/dev/null)" = "on" ]; then echo off > "$F"; else echo on > "$F"; fi ;;
esac
if [ "$(cat "$HOME/.cache/bar-mode.txt" 2>/dev/null)" = "qs" ]; then
  if [ "$(cat "$F")" = "on" ]; then
    pgrep -f "(quickshell|qs) -c launcher" >/dev/null 2>&1 || qs -c launcher -d >/dev/null 2>&1
  else
    pkill -f "(quickshell|qs) -c launcher" 2>/dev/null
  fi
fi
echo "warm launcher: $(cat "$F")"
