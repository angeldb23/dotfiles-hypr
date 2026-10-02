#!/bin/bash
pidof hyprlock >/dev/null && exit 0
python3 "$HOME/scripts/lock-gen.py" >/dev/null 2>&1
exec hyprlock
