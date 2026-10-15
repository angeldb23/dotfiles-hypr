#!/bin/bash
# Ajusta swaync segun la barra activa (qs = barra nueva a la izquierda, otro = waybar)
mode=$(cat ~/.cache/bar-mode.txt 2>/dev/null)

# Solo ajusta config si swaync esta corriendo
if pgrep -x swaync >/dev/null 2>&1; then
    python3 - "$HOME/.config/swaync/config.json" "$HOME/.config/swaync/style.css" "$mode" <<'PY'
import json, re, sys
cfg, css, mode = sys.argv[1], sys.argv[2], sys.argv[3]
c = json.load(open(cfg))
c["notification-grouping"] = False
if mode == "qs":
    c.update({"control-center-positionX": "left", "control-center-positionY": "bottom",
              "control-center-margin-top": 8, "control-center-margin-bottom": 8,
              "control-center-margin-left": 0, "control-center-margin-right": 0})
    block = ".control-center { border-radius: 0 22px 22px 0; border-left-width: 0; }"
else:
    c.update({"control-center-positionX": "right", "control-center-positionY": "top",
              "control-center-margin-top": 40, "control-center-margin-right": 6,
              "control-center-margin-bottom": 0, "control-center-margin-left": 0})
    block = ""
json.dump(c, open(cfg, "w"), indent=2)
s = open(css).read()
s = re.sub(r"\n?/\* MODE-START \*/.*?/\* MODE-END \*/\n?", "\n", s, flags=re.S)
s = s.rstrip("\n") + "\n/* MODE-START */\n" + block + "\n/* MODE-END */\n"
open(css, "w").write(s)
PY

    # Timeout de 5s en cada llamada a swaync-client
    timeout 5 swaync-client -R >/dev/null 2>&1
    timeout 5 swaync-client -rs >/dev/null 2>&1
fi
