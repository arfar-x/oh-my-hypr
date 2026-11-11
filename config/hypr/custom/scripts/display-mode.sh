#!/usr/bin/env bash
# GNOME-style display mode picker (Super+P): Join (extend), Mirror, primary only, secondary only.
# Usage: display-mode.sh [join|mirror|primary|secondary|info]  (no arg opens the quickshell picker)
set -u

# Same pill the keyboard-layout switch uses (see switch-layout.sh)
osd() { qs -c "${qsConfig:-ii}" ipc call osdVolume layoutIcon "${2:-}" "$1" 2>/dev/null || qs ipc call osdVolume layoutIcon "${2:-}" "$1"; }

mons=$(hyprctl monitors all -j)
mapfile -t names < <(jq -r '.[].name' <<<"$mons")

if [ "${#names[@]}" -lt 2 ] && [ "${1:-}" != info ]; then
  osd "Only one display"
  exit 0
fi

# Primary = built-in panel (eDP/LVDS/DSI) if present, else the first monitor. Secondary = first other.
primary=${names[0]}
for n in "${names[@]}"; do case "$n" in eDP*|LVDS*|DSI*) primary=$n; break;; esac; done
secondary=
for n in "${names[@]}"; do [ "$n" != "$primary" ] && { secondary=$n; break; }; done

mode=${1:-}
case "$mode" in
  info)
    # current = which of the four modes matches the live state (the picker pre-selects it)
    cur=join
    if [ "${#names[@]}" -ge 2 ]; then
      pdis=$(jq -r --arg n "$primary" '.[]|select(.name==$n)|.disabled' <<<"$mons")
      sdis=$(jq -r --arg n "$secondary" '.[]|select(.name==$n)|.disabled' <<<"$mons")
      smir=$(jq -r --arg n "$secondary" '.[]|select(.name==$n)|.mirrorOf' <<<"$mons")
      if [ "$sdis" = true ]; then cur=primary
      elif [ "$pdis" = true ]; then cur=secondary
      elif [ "$smir" != none ]; then cur=mirror; fi
    fi
    printf 'count=%s\nprimary=%s\nsecondary=%s\ncurrent=%s\n' "${#names[@]}" "$primary" "$secondary" "$cur"; exit 0 ;;
  "")   exec qs -c "${qsConfig:-ii}" ipc call displayMode open ;;
esac

scale() { jq -r --arg n "$1" '(.[]|select(.name==$n)|.scale) // 1' <<<"$mons"; }
is_off() { [ "$(jq -r --arg n "$1" '.[]|select(.name==$n)|.disabled' <<<"$mons")" = true ]; }

# Logical width of the primary: where the secondary goes to sit right next to it.
pw=$(jq -r --arg n "$primary" '.[]|select(.name==$n)|((.width / (.scale // 1)) | round)' <<<"$mons")

# mon NAME POSITION [off] [mirror]
# Every step below keeps all enabled monitors apart. Hyprland checks the layout after each call and
# shows "Monitor X overlaps with other monitor(s)" if two enabled monitors ever share space, even
# briefly, so the monitor that is not at 0x0 is always moved out of the way first.
mon() {
  local lua="hl.monitor({ output = \"$1\", mode = \"preferred\", position = \"$2\", scale = $(scale "$1")"
  [ "${3:-}" = off ] && lua+=", disabled = true" || lua+=", disabled = false"
  lua+=", mirror = \"${4:-}\" })"
  hyprctl eval "$lua" >/dev/null
}

case "$mode" in
  join)
    mon "$secondary" "${pw}x0"; mon "$primary" 0x0
    icon=view_column_2; label="Join Displays" ;;
  mirror)
    mon "$secondary" "${pw}x0"; mon "$primary" 0x0; mon "$secondary" "${pw}x0" on "$primary"
    icon=content_copy; label="Mirror" ;;
  primary)
    if is_off "$primary"; then mon "$secondary" "${pw}x0"; fi
    mon "$primary" 0x0; mon "$secondary" auto off
    icon=laptop_mac; label="Primary Only" ;;
  secondary)
    mon "$secondary" "${pw}x0"; mon "$primary" auto off; mon "$secondary" 0x0
    icon=desktop_windows; label="Secondary Only" ;;
  *) exit 1 ;;
esac

# Turning a monitor off makes quickshell tear down and rebuild its per-screen windows, and a pill sent
# before that finishes is lost. In the single-display modes wait (up to ~8s) until quickshell has put
# its layer surfaces back on the screen that remains, then show the pill.
shell_ready() { hyprctl layers -j | jq -e --arg n "$1" '(.[$n].levels // {})|[.[][]?.namespace|select(startswith("quickshell:"))]|length>0' >/dev/null; }
case "$mode" in
  primary|secondary)
    remaining=$primary; [ "$mode" = secondary ] && remaining=$secondary
    for _ in $(seq 40); do shell_ready "$remaining" && break; sleep 0.2; done
    sleep 0.5 ;;
  *) sleep 0.3 ;;
esac
osd "$label" "$icon"
