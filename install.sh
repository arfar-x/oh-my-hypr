#!/usr/bin/env bash
# Apply oh-my-hypr on top of a stock end-4 (illogical-impulse) install.
# Idempotent: files are overwritten only when they differ, no backups or other
# leftovers are created, and a second run changes nothing.
# Replaced files are the stock end-4 ones; restore them from dots-hyprland if needed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
CHANGED=0

# sync SRC_FILE DST_FILE LABEL
sync() {
  if [ -e "$2" ] && cmp -s "$1" "$2"; then
    return
  fi
  mkdir -p "$(dirname "$2")"
  cp -a "$1" "$2"
  CHANGED=1
  echo "installed $3"
}

cd "$ROOT/config"
DST="${XDG_CONFIG_HOME:-$HOME/.config}"
while read -r f; do
  f="${f#./}"
  sync "$f" "$DST/$f" "$f"
done < <(find . -type f | sort)

# Terminal palette (kitty + fish) pinned to the reference look. end-4 regenerates
# these from the wallpaper, so a later wallpaper/theme change replaces them;
# rerunning this script puts them back.
TDST="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/terminal"
for f in kitty-theme.conf sequences.txt; do
  sync "$ROOT/state/terminal/$f" "$TDST/$f" "terminal palette $f"
done

for c in kitty fish starship eza; do
  command -v "$c" >/dev/null || echo "WARNING: '$c' is not installed (needed for the kitty/fish look)"
done
fc-match "JetBrains Mono Nerd Font" | grep -qi "JetBrainsMono Nerd Font" || echo "WARNING: JetBrains Mono Nerd Font missing (pacman -S ttf-jetbrains-mono-nerd)"

if [ "$CHANGED" = 1 ]; then
  command -v hyprctl >/dev/null && hyprctl reload || true
  echo "Done. Restart quickshell to load QML changes: killall qs quickshell; qs -c ii &"
else
  echo "Already up to date."
fi
