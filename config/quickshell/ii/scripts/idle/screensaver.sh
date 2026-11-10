#!/usr/bin/env bash
# Usage: screensaver.sh start [matrix|bonsai] | stop | toggle
# Covers every monitor with an overlay terminal animation over the dimmed desktop.
# Any key, click or mouse movement closes it (the terminal reports mouse input, and a
# second hypridle calls "stop" on resume as a fallback).
cls=ii-screensaver
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"

self=$(readlink -f "$0")
watchconf="${XDG_RUNTIME_DIR:-/tmp}/ii-screensaver-hypridle.conf"
pidfile="${XDG_RUNTIME_DIR:-/tmp}/ii-screensaver-poll.pid"
tokenfile="${XDG_RUNTIME_DIR:-/tmp}/ii-screensaver-token"
panelpat="[k]itten panel.*app-id=$cls"
running() { pgrep -f -- "$panelpat" >/dev/null; }

start() {
    # Close anything left over from a previous run first
    stop
    local style=${1:-$(jq -r '.idle.screensaverStyle // "random"' "$cfg" 2>/dev/null)}
    # Background: the desktop darkened according to the active profile's dimmed brightness
    # (scaled by 0.6: a full-strength overlay turns an already dark desktop pure black)
    local profile key bright opacity
    profile=$(powerprofilesctl get 2>/dev/null)
    case $profile in power-saver) key=powerSaver ;; performance) key=performance ;; *) key=balanced ;; esac
    bright=$(jq -r --arg k "$key" '.idle[$k].dimBrightness // 10' "$cfg" 2>/dev/null)
    opacity=$(awk -v b="${bright:-10}" 'BEGIN { printf "%.2f", (100 - b) / 100 * 0.6 }')

    if [ "$style" = random ]; then
        local avail=() c
        for c in cmatrix cbonsai hollywood genact; do
            command -v "$c" >/dev/null 2>&1 && avail+=("$c")
        done
        style=${avail[RANDOM % ${#avail[@]}]:-cmatrix}
    fi

    # "desktop": translucent blurred backdrop over the live desktop and active workspace.
    # "wallpaper": the wallpaper image darkened to the dimmed brightness (falls back to desktop
    # for a video wallpaper or a missing file).
    local wall bg backdrop
    backdrop=$(jq -r '.idle.screensaverBackdrop // "desktop"' "$cfg" 2>/dev/null)
    wall=
    [ "$backdrop" = wallpaper ] && wall=$(jq -r '.background.wallpaperPath // empty' "$cfg" 2>/dev/null)
    wall=${wall#file://}
    case ${wall,,} in
        *.jpg|*.jpeg|*.png|*.webp) [ -f "$wall" ] || wall= ;;
        *) wall= ;;
    esac
    if [ -n "$wall" ]; then
        bg=(-o "background_image=$wall" -o background_image_layout=cscaled
            -o "background_tint=$opacity" -o background_opacity=1)
    else
        bg=(-o background_opacity="$opacity")
    fi

    # Sleep first so the animation reads the final size. Mouse tracking makes mouse
    # movement and clicks arrive as input, which ends the animation like a keypress.
    local cmd
    case $style in
        # cbonsai's own -S mode quits on the resize event fullscreen causes, so wait for a key ourselves.
        # A long life and high multiplier grow one large tree, step by step, then a new one starts.
        bonsai|cbonsai) cmd='cbonsai -l -i -t 0.02 -w 8 -L 90 -M 6 -b 2 -c "&,@" & p=$!; read -rsn1; kill $p' ;;
        hollywood)      cmd='hollywood' ;;
        genact)         cmd='genact' ;;
        *)              cmd='cmatrix -s -B -C cyan' ;;
    esac
    # The wrapper stops everything when its animation ends, but only if it is still the current run
    local token="$$-$RANDOM"
    echo "$token" > "$tokenfile"
    cmd="sleep 0.6; printf '\\033[?1003h\\033[?1006h'; $cmd; [ \"\$(cat '$tokenfile')\" = '$token' ] && '$self' stop"

    # One overlay layer-shell panel per monitor, above the bar, with a translucent black
    # background so the dimmed desktop shows through while the animation stays bright
    local name
    for name in $(hyprctl monitors -j | jq -r '.[].name'); do
        setsid kitten panel --edge=center --layer=overlay --focus-policy=exclusive \
            --class "$cls" --output-name "$name" \
            -o background=#000000 -o color0=#000000 -o color6=#00e5ff -o color14=#00e5ff \
            -o color2=#3fb950 -o color10=#7ee787 -o color3=#a0693a -o color11=#d9a066 -o bold_is_bright=yes "${bg[@]}" \
            -o window_padding_width=0 -o placement_strategy=top-left -o remember_window_size=no \
            -o confirm_os_window_close=0 -o enable_audio_bell=no \
            sh -c "$cmd" >/dev/null 2>&1 &
    done

    # Mouse movement dismisses it whatever is running: poll the cursor position
    if [ -z "$SCREENSAVER_NOWATCH" ]; then
        (
            sleep 1
            # Keys and mouse buttons are caught by Hyprland's "screensaver" submap
            hyprctl dispatch 'hl.dsp.submap("screensaver")' >/dev/null 2>&1
            sleep 0.5
            p0=$(hyprctl cursorpos 2>/dev/null)
            while sleep 0.25; do
                [ "$(hyprctl cursorpos 2>/dev/null)" != "$p0" ] && break
            done
            "$self" stop
        ) >/dev/null 2>&1 &
        echo $! > "$pidfile"
    fi

    # Any key or mouse movement dismisses it: a second hypridle that fires "stop" on resume
    [ -n "$SCREENSAVER_NOWATCH" ] || printf 'listener {\n    timeout = 2\n    on-timeout = true\n    on-resume = %s stop\n}\n' "$self" > "$watchconf"
    [ -n "$SCREENSAVER_NOWATCH" ] || setsid hypridle -c "$watchconf" >/dev/null 2>&1 &
}

stop() {
    [ "$(hyprctl submap 2>/dev/null)" = screensaver ] && hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1
    [ -f "$pidfile" ] && { pkill -P "$(cat "$pidfile")" 2>/dev/null; kill "$(cat "$pidfile")" 2>/dev/null; rm -f "$pidfile"; }
    pkill -f -- "hypridle -c $watchconf"
    pkill -f -- "$panelpat"
    sleep 0.1
    # Animations that run in their own tmux server (hollywood) outlive the window
    pkill -x hollywood 2>/dev/null; pkill -x genact 2>/dev/null
    tmux kill-session -t hollywood 2>/dev/null
}

case $1 in
    start) start "$2" ;;
    stop) stop ;;
    toggle) if running; then stop; else start "$2"; fi ;;
    *) echo "usage: $0 start [matrix|bonsai] | stop | toggle" >&2; exit 1 ;;
esac
