#!/usr/bin/env bash
# Apply oh-my-hypr on top of a stock end-4 (illogical-impulse) install.
# Existing files are backed up next to themselves as <file>.pre-oh-my-hypr.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/config" && pwd)"
DST="${XDG_CONFIG_HOME:-$HOME/.config}"
cd "$SRC"
find . -type f | while read -r f; do
  f="${f#./}"
  mkdir -p "$DST/$(dirname "$f")"
  if [ -e "$DST/$f" ] && ! cmp -s "$f" "$DST/$f" && [ ! -e "$DST/$f.pre-oh-my-hypr" ]; then
    cp -a "$DST/$f" "$DST/$f.pre-oh-my-hypr"
  fi
  cp -a "$f" "$DST/$f"
  echo "installed $f"
done
command -v hyprctl >/dev/null && hyprctl reload || true
echo "Done. Restart quickshell to load QML changes: killall qs quickshell; qs -c ii &"
