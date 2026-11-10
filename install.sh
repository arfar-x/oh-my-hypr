#!/usr/bin/env bash
# Apply oh-my-hypr on top of a stock end-4 (illogical-impulse) install.
# Idempotent: files are overwritten only when they differ, no backups or other
# leftovers are created, and a second run changes nothing.
# Replaced files are the stock end-4 ones; restore them from dots-hyprland if needed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
CHANGED=0

# Packages the customizations need. Skip with: ./install.sh --skip-deps
#   idle/power profiles: power-profiles-daemon (service), hypridle, brightnessctl, jq
#   screensaver: kitty, cmatrix, genact (repo) and cbonsai, hollywood (AUR)
REPO_DEPS=(power-profiles-daemon hypridle brightnessctl jq kitty cmatrix genact)
AUR_DEPS=(cbonsai hollywood)

install_deps() {
  command -v pacman >/dev/null || { echo "NOTE: not an Arch system; install manually: ${REPO_DEPS[*]} ${AUR_DEPS[*]}"; return; }
  local missing=() aur_missing=() p
  for p in "${REPO_DEPS[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
  for p in "${AUR_DEPS[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || aur_missing+=("$p"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Installing: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}" || echo "WARNING: could not install: ${missing[*]}"
  fi
  if [ "${#aur_missing[@]}" -gt 0 ]; then
    local helper=""
    for p in yay paru; do command -v "$p" >/dev/null && { helper="$p"; break; }; done
    if [ -n "$helper" ]; then
      echo "Installing from the AUR: ${aur_missing[*]}"
      "$helper" -S --needed "${aur_missing[@]}" || echo "WARNING: could not install: ${aur_missing[*]}"
    else
      echo "WARNING: no AUR helper (yay/paru); install manually: ${aur_missing[*]}"
    fi
  fi
  # The Idle settings follow the active power profile, which needs this service running
  if ! systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then
    echo "Enabling power-profiles-daemon"
    sudo systemctl enable --now power-profiles-daemon || echo "WARNING: could not enable power-profiles-daemon"
  fi
}
if [ "${1:-}" != "--skip-deps" ]; then install_deps; fi

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
  if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
    echo "Reloaded Hyprland."
  else
    echo "NOTE: Hyprland was not reloaded (no running session here). Log in to Hyprland, or run 'hyprctl reload' inside it, for the rules to take effect."
  fi
  echo "Done. Restart quickshell to load QML changes: killall qs quickshell; qs -c ii &"
else
  echo "Already up to date."
fi
