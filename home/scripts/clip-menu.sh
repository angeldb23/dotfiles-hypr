#!/bin/bash
sel=$(cliphist list | fuzzel --dmenu --lines=10 --width=50)
[ -n "$sel" ] && printf '%s' "$sel" | cliphist decode | wl-copy
