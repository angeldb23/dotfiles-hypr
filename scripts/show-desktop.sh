#!/bin/bash
# Toggle show desktop: moves ALL windows together (batch) so they don't overlap
STATE=/tmp/show-desktop.txt
if [ -s "$STATE" ]; then
  cmds=""
  while read -r addr ws; do
    cmds+="dispatch hl.dsp.window.move({ workspace = $ws, follow = false, window = \"address:$addr\" }) ; "
  done < "$STATE"
  hyprctl --batch "$cmds" >/dev/null
  : > "$STATE"
else
  cur=$(hyprctl activeworkspace -j | jq -r .id)
  hyprctl clients -j | jq -r --argjson w "$cur" '.[] | select(.workspace.id==$w and .mapped) | "\(.address) \(.workspace.id)"' > "$STATE"
  [ -s "$STATE" ] || exit 0
  cmds=""
  while read -r addr ws; do
    cmds+="dispatch hl.dsp.window.move({ workspace = \"special:hidden\", follow = false, window = \"address:$addr\" }) ; "
  done < "$STATE"
  hyprctl --batch "$cmds" >/dev/null
fi
