#!/usr/bin/env bash
# When a minimized window gets focus (dock click, Alt+Tab, notification...), move it
# back to the current workspace instead of letting special:minimized sit on screen.
sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
state="$XDG_RUNTIME_DIR/hypr-window-state/minimized"

restore() { # $1 = window address (with 0x)
    cur=$(hyprctl activeworkspace -j | jq -r .id)
    hyprctl dispatch "hl.dsp.window.move({ workspace = '$cur', window = 'address:$1' })" >/dev/null
    [ -f "$state" ] && sed -i "\|^$1\$|d" "$state"
    # Close the special workspace overlay if it is still showing
    if [ -n "$(hyprctl monitors -j | jq -r '.[]|select(.focused).specialWorkspace.name')" ]; then
        hyprctl dispatch "hl.dsp.workspace.toggle_special('minimized')" >/dev/null
    fi
    hyprctl dispatch "hl.dsp.focus({ window = 'address:$1' })" >/dev/null
}

in_minimized() {
    hyprctl clients -j | jq -e --arg a "$1" '.[]|select(.address==$a and .workspace.name=="special:minimized")' >/dev/null
}

socat -u "UNIX-CONNECT:$sock" - | while IFS= read -r line; do
    case "$line" in
    activewindowv2">>"*)
        addr="0x${line#activewindowv2>>}"
        [ "$addr" != "0x" ] && in_minimized "$addr" && restore "$addr"
        ;;
    activespecial">>special:minimized,"*)
        addr=$(hyprctl activewindow -j | jq -r '.address // empty')
        [ -n "$addr" ] && in_minimized "$addr" && restore "$addr"
        ;;
    esac
done
