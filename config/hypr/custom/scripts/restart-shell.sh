#!/usr/bin/env bash
# Recover a wedged quickshell (and refresh the Hyprland config) WITHOUT tearing
# down the compositor or any running clients (terminals, opencode, browsers...).
#
# Why this and not a compositor restart: the Hyprland BINARY owns the Wayland
# socket. Restarting it kills every Wayland client (your kitty/opencode windows).
# Almost every Super-key bind routes through quickshell, so when the shell's main
# thread busy-loops its IPC goes deaf and the whole keybind surface looks dead.
# Restarting only the shell fixes that and leaves all windows untouched.
#
# Bound to ALT + F2 (see custom/keybinds.lua).

set -u
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Accept the config name as $1. If empty, fall back to env then "ii".
# (qsConfig is a Hyprland-internal var, not exported to our environment, so the
#  keybind passes it explicitly via Hyprland's $qsConfig expansion.)
QS_CONFIG="${1:-${qsConfig:-ii}}"
QS_BIN="$(command -v qs || echo /usr/bin/qs)"
LOCK="$XDG_RUNTIME_DIR/hypr-restart-shell.lock"
LOG="$XDG_RUNTIME_DIR/hypr-restart-shell.log"
HYPR_SCRIPTS="$HOME/.config/hypr/hyprland/scripts"

notify() {
    command -v notify-send >/dev/null 2>&1 && \
        notify-send "Desktop recovery" "$1" -a "Hyprland" -t 4000 >/dev/null 2>&1
}

# --- single-flight: refuse to stack if a recovery is already running -----------
if [[ -e "$LOCK" ]]; then
    # Stale lock (older than 30s) is cleared; otherwise bail out.
    if [[ -n "$(find "$LOCK" -mmin +0.5 2>/dev/null)" ]]; then
        rm -f "$LOCK"
    else
        notify "Recovery already in progress…"
        exit 0
    fi
fi
trap 'rm -f "$LOCK"' EXIT
: > "$LOCK"

{
    echo "===== $(date '+%F %T') recovery ====="

    # 1. Kill the wedged shell and any stuck `qs ... ipc call` clients it spawned.
    #    Kill by exact executable name (qs) only, never by a -f substring that could
    #    match this script's own caller. Guard against our own PID and ancestors.
    self=$$
    declare -A skip=()
    for p in "$self" "$PPID"; do
        while [[ -n "$p" && "$p" != 0 && "$p" != 1 ]]; do
            skip["$p"]=1
            p="$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)"
        done
    done

    # The shell binary: exact match "-x qs".
    for pid in $(pgrep -x qs 2>/dev/null); do
        [[ -n "${skip[$pid]:-}" ]] && continue
        kill -9 "$pid" 2>/dev/null
    done
    # Any client still stuck on the shell's IPC (its command line holds "ipc call").
    for pid in $(pgrep -f " ipc call " 2>/dev/null); do
        [[ -n "${skip[$pid]:-}" ]] && continue
        kill -9 "$pid" 2>/dev/null
    done
    sleep 0.3

    # 2. Refresh the Hyprland config in place. Non-destructive: clients are kept.
    command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1

    # 3. Relaunch the shell, detached from this script's tree so it survives.
    #    setsid puts it in its own session; stdout goes to the recovery log.
    setsid "$QS_BIN" -c "$QS_CONFIG" >>"$LOG" 2>&1 < /dev/null &

    # 4. Wait for the shell's IPC to come back up (or report the failure).
    ok=0
    for _ in $(seq 1 20); do
        sleep 0.5
        if timeout 2 "$QS_BIN" -c "$QS_CONFIG" ipc show >/dev/null 2>&1; then
            ok=1
            break
        fi
    done

    if [[ "$ok" == 1 ]]; then
        echo "shell healthy after recovery"
        notify "Shell restarted — shortcuts restored."
    else
        echo "shell did NOT come back; see $LOG"
        notify "Shell failed to restart — check $LOG"
    fi
} >>"$LOG" 2>&1
