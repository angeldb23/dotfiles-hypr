#!/bin/bash
# WiFi network menu with cache (opens instantly)
W=$'\uf1eb'; L=$'\uf023'; C=$'\uf00c'
CACHE=/tmp/wifi-list.cache
now=$(date +%s)
if [ -f "$CACHE" ] && [ $(( now - $(stat -c %Y "$CACHE") )) -lt 30 ]; then
  LIST=$(cat "$CACHE")
  ( nmcli -t -f SSID,SECURITY,IN-USE device wifi list 2>/dev/null | awk -F: 'NF>=2 && $1!=""' | sort -u -t: -k1,1 > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE" ) &
else
  LIST=$(nmcli -t -f SSID,SECURITY,IN-USE device wifi list 2>/dev/null | awk -F: 'NF>=2 && $1!=""' | sort -u -t: -k1,1)
  [ -n "$LIST" ] && echo "$LIST" > "$CACHE"
fi
if [ -z "$LIST" ]; then
  notify-send "WiFi" "No networks found (check that WiFi is turned on)"
  exit 0
fi
entries=""
while IFS=: read -r ssid sec inuse; do
  if [ "$inuse" = "*" ]; then icon="$C"; elif [ -n "$sec" ]; then icon="$L"; else icon="$W"; fi
  entries+="$icon  $ssid"$'\n'
done <<< "$LIST"
sel=$(printf '%s' "$entries" | fuzzel --dmenu --lines=8)
[ -z "$sel" ] && exit 0
ssid="${sel#*  }"
sec=$(awk -F: -v s="$ssid" '$1==s{print $2; exit}' <<< "$LIST")
if [ -z "$sec" ]; then
  nmcli device wifi connect "$ssid" && notify-send "WiFi" "Connected to $ssid" || notify-send "WiFi" "Could not connect to $ssid"
else
  pass=$(fuzzel --dmenu --password --lines=1)
  [ -z "$pass" ] && exit 0
  nmcli device wifi connect "$ssid" password "$pass" && notify-send "WiFi" "Connected to $ssid" || notify-send "WiFi" "Wrong password?"
fi
rm -f "$CACHE"
