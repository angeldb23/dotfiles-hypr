#!/usr/bin/env bash

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprland-show-desktop"
mkdir -p "$STATE_DIR"

CURRENT=$(hyprctl activeworkspace -j | jq -r '.name')
STATE="$STATE_DIR/$CURRENT"

# value=0 -> ventanas invisibles | value=1 -> visibles
apply_opacity() {
    local value="$1" addrs="$2"
    hyprctl eval "
        for _, a in ipairs({ $addrs }) do
            for _, p in ipairs({ 'opacity', 'opacity_inactive', 'opacity_fullscreen' }) do
                hl.dispatch(hl.dsp.window.set_prop({ prop = p, value = '$value', window = 'address:' .. a }))
            end
        end
    " >/dev/null 2>&1
}

# Restaurar
if [ -f "$STATE" ]; then
    ADDRS=$(sed 's/.*/"&"/' "$STATE" | paste -sd,)
    apply_opacity 1 "$ADDRS"
    rm -f "$STATE"
    exit 0
fi

# Ocultar
WINDOWS=$(hyprctl clients -j |
    jq -r --arg ws "$CURRENT" '
        .[]
        | select(.workspace.name == $ws)
        | select(.mapped == true)
        | .address
    ')

[ -z "$WINDOWS" ] && exit 0
printf '%s\n' "$WINDOWS" > "$STATE"

ADDRS=$(printf '%s\n' "$WINDOWS" | sed 's/.*/"&"/' | paste -sd,)
apply_opacity 0 "$ADDRS"
