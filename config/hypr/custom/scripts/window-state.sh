#!/usr/bin/env bash
# Usage: window-state.sh minimize | unminimize | show-desktop
# Windows are parked on special workspaces; addresses and origin workspaces are
# recorded so they can be put back exactly where they were.
state="${XDG_RUNTIME_DIR:-/tmp}/hypr-window-state"
mkdir -p "$state"

park() { hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$2', window = 'address:$1', follow = false })" >/dev/null; }

case "$1" in
minimize)
    win=$(hyprctl activewindow -j)
    addr=$(jq -r '.address // empty' <<<"$win")
    [ -z "$addr" ] && exit 0
    # Already parked on a special workspace: nothing to do
    [ "$(jq -r '.workspace.id' <<<"$win")" -lt 0 ] && exit 0
    echo "$addr" >>"$state/minimized"
    # Shrink-to-dock effect (quickshell minimizeFx); needs a moment to grab the snapshot
    mon=$(jq -r '.monitor' <<<"$win")
    read -r mx my < <(hyprctl monitors -j | jq -r --argjson m "$mon" '.[]|select(.id==$m)|"\(.x) \(.y)"')
    read -r wx wy ww wh mname < <(hyprctl clients -j | jq -r --arg a "$addr" '.[]|select(.address==$a)|"\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1]) \(.monitor)"')
    mname=$(hyprctl monitors -j | jq -r --argjson m "$mon" '.[]|select(.id==$m)|.name')
    qs -c ii ipc call minimizeFx run "$addr" $((wx - mx)) $((wy - my)) "$ww" "$wh" "$mname" >/dev/null 2>&1 && sleep 0.12
    park "$addr" minimized
    # no_focus_fallback leaves focus on the hidden window; hand it to the next one
    ws=$(jq -r '.workspace.id' <<<"$win")
    next=$(hyprctl clients -j | jq -r --argjson ws "$ws" '[.[]|select(.workspace.id==$ws and .mapped)]|sort_by(.focusHistoryID)|.[0].address // empty')
    [ -n "$next" ] && hyprctl dispatch "hl.dsp.focus({ window = 'address:$next' })" >/dev/null
    ;;
unminimize)
    [ -s "$state/minimized" ] || exit 0
    cur=$(hyprctl activeworkspace -j | jq -r .id)
    # Pop entries until one is still a window parked in special:minimized
    while [ -s "$state/minimized" ]; do
        addr=$(tail -n1 "$state/minimized")
        sed -i '$d' "$state/minimized"
        if hyprctl clients -j | jq -e --arg a "$addr" '.[]|select(.address==$a and .workspace.name=="special:minimized")' >/dev/null; then
            hyprctl dispatch "hl.dsp.window.move({ workspace = '$cur', window = 'address:$addr' })" >/dev/null
            break
        fi
    done
    ;;
show-desktop)
    if [ -s "$state/desktop" ]; then
        while read -r addr ws; do
            hyprctl dispatch "hl.dsp.window.move({ workspace = '$ws', window = 'address:$addr', follow = false })" >/dev/null
        done <"$state/desktop"
        rm -f "$state/desktop"
        [ -n "$(sed -n 1p "$state/desktop-focus" 2>/dev/null)" ] &&
            hyprctl dispatch "hl.dsp.focus({ window = 'address:$(cat "$state/desktop-focus")' })" >/dev/null
        rm -f "$state/desktop-focus"
    else
        hyprctl activewindow -j | jq -r '.address // empty' >"$state/desktop-focus"
        hyprctl clients -j | jq -r '.[] | select(.mapped and (.workspace.id > 0)) | "\(.address) \(.workspace.id)"' >"$state/desktop"
        while read -r addr ws; do park "$addr" desktop; done <"$state/desktop"
    fi
    ;;
esac
