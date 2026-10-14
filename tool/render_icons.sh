#!/usr/bin/env bash
# Render assets/icon/conclock.svg (and its variants) to PNGs with headless
# Chrome, then regenerate platform icons:
#   tool/render_icons.sh && dart run flutter_launcher_icons
set -euo pipefail
cd "$(dirname "$0")/.."
DIR=assets/icon
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Variants: full-bleed square (iOS masks it itself) and the bare clock
# (Android adaptive foreground, which supplies its own background).
sed 's|<rect x="64" y="64" width="896" height="896" rx="208"|<rect x="0" y="0" width="1024" height="1024" rx="0"|' \
  "$DIR/conclock.svg" > "$TMP/conclock-full.svg"
sed '/<!-- Tile -->/{n;d}' "$DIR/conclock.svg" > "$TMP/conclock-foreground.svg"
cp "$DIR/conclock.svg" "$TMP/conclock.svg"

for name in conclock conclock-full conclock-foreground; do
  printf '<html><body style="margin:0"><img src="%s.svg" width="1024" height="1024"></body></html>' \
    "$name" > "$TMP/$name.html"
  google-chrome --headless=new --disable-gpu --hide-scrollbars \
    --default-background-color=00000000 --window-size=1024,1024 \
    --allow-file-access-from-files --screenshot="$DIR/$name.png" \
    "file://$TMP/$name.html" 2>/dev/null
done
convert "$DIR/conclock.png" -resize 256x256 "$DIR/conclock-256.png"
ls -l "$DIR"
