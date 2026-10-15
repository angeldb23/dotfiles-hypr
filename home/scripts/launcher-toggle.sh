#!/usr/bin/env bash
# Abre/cierra el launcher qs; lo levanta si no esta vivo
if qs -c launcher ipc call launcher toggle 2>/dev/null; then exit 0; fi
qs -c launcher -d >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleep 0.3
  qs -c launcher ipc call launcher toggle 2>/dev/null && exit 0
done
