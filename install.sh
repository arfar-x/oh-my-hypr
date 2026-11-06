#!/usr/bin/env bash
# Apply oh-my-hypr on top of a stock end-4 (illogical-impulse) install.
# Existing files are backed up next to themselves as <file>.pre-oh-my-hypr.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/config"
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

# Terminal palette (kitty + fish) pinned to the reference look. end-4 regenerates
# these from the wallpaper, so they are replaced the next time the wallpaper/theme changes.
TSRC="$ROOT/state/terminal"
TDST="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/terminal"
mkdir -p "$TDST"
for f in kitty-theme.conf sequences.txt; do
  if [ -e "$TDST/$f" ] && ! cmp -s "$TSRC/$f" "$TDST/$f" && [ ! -e "$TDST/$f.pre-oh-my-hypr" ]; then
    cp -a "$TDST/$f" "$TDST/$f.pre-oh-my-hypr"
  fi
  cp -a "$TSRC/$f" "$TDST/$f"
  echo "installed terminal palette $f"
done

for c in kitty fish starship eza; do
  command -v "$c" >/dev/null || echo "WARNING: '$c' is not installed (needed for the kitty/fish look)"
done
fc-match "JetBrains Mono Nerd Font" | grep -qi "JetBrainsMono Nerd Font" || echo "WARNING: JetBrains Mono Nerd Font missing (pacman -S ttf-jetbrains-mono-nerd)"

command -v hyprctl >/dev/null && hyprctl reload || true
echo "Done. Restart quickshell to load QML changes: killall qs quickshell; qs -c ii &"
