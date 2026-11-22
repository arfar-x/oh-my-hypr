#!/usr/bin/env bash
# Watchdog: detect a wedged quickshell and restart just the shell + reload the
# Hyprland config, so shortcuts come back on their own without touching clients.
#
# Run by hypr-shell-watchdog.timer (systemd --user), every ~30s.
# It acts ONLY when the shell is proven frozen:
#   - the shell process exists, AND
#   - its IPC does not answer within a short timeout.
# A healthy shell is left completely alone.

set -u
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

QS_CONFIG="ii"
QS_BIN="$(command -v qs || echo /usr/bin/qs)"
RECOVER="$HOME/.config/hypr/custom/scripts/restart-shell.sh"

# Nothing to watch if we're not in a Hyprland session.
if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
    exit 0
fi

# Shell not running at all? Let the session's own startup handle it; don't fight it.
pgrep -x qs >/dev/null 2>&1 || exit 0

# Prove a freeze: the IPC must stay silent twice in a row.
for _ in 1 2; do
    if timeout 3 "$QS_BIN" -c "$QS_CONFIG" ipc show >/dev/null 2>&1; then
        exit 0   # shell answered -> healthy
    fi
    sleep 1
done

# Also require the main thread to actually be pegged, to avoid restarting a shell
# that is merely busy during startup. If it's not spinning, leave it be.
# Sum utime+stime (fields 14,15) for each qs process. The comm field "(qs)" has
# no spaces, so a space-split is safe here. Fields 14/15 = utime/stime.
cpu_jiffies() {
    for pid in $(pgrep -x qs 2>/dev/null); do
        cut -d' ' -f14,15 "/proc/$pid/stat" 2>/dev/null \
            | awk '{ print $1+$2 }'
    done
}
sum_before="$(cpu_jiffies | awk '{s+=$1} END {print s+0}')"
sleep 1
sum_after="$(cpu_jiffies | awk '{s+=$1} END {print s+0}')"
busy=0
delta=$(( sum_after - sum_before ))
(( delta > 50 )) && busy=1   # >50 jiffies/sec = >50% of one core

if (( busy == 1 )); then
    logger -t hypr-shell-watchdog "quickshell frozen (IPC deaf + CPU pegged); recovering"
    "$RECOVER" "$QS_CONFIG"
fi
