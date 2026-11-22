# Runbook: recovering a dead keybind surface (wedged quickshell)

## Symptom

Keyboard shortcuts stop responding on the desktop. Nothing obvious is wrong
otherwise: windows are still drawn, the pointer moves, apps that are already
open keep working — but Super+anything does nothing, the launcher (Super+A)
does not open, and Alt+Tab does nothing.

The compositor is healthy. Hyprland is running, its config loaded with no
errors, and its bind table is populated:

```sh
hyprctl version                 # prints the version, so the session is alive
hyprctl configerrors            # empty output = config parsed fine
hyprctl binds >/dev/null && echo "binds registered"
```

Do not chase the Hyprland config: if those three are fine, the config is not
the problem.

## Root cause

Almost every keybind routes through **quickshell** — either as a Hyprland
global shortcut (`hl.dsp.global("quickshell:...")`) or by shelling out to its
IPC (`hl.dsp.exec_cmd("qs -c $qsConfig ipc call ...")`). If the quickshell
process wedges, its event loop stops answering IPC and stops servicing global
shortcuts, so every bind that touches it appears dead. Hyprland keeps firing
the binds, but the process they call never replies.

The wedge is specifically the shell's **main thread spinning in a busy-loop**:
it stays at ~100% of one core, so its Qt event loop never returns to handle
IPC requests. Do **not** restart the compositor for this. The Hyprland *binary*
owns the Wayland socket; restarting it kills every Wayland client (terminals,
editors, any session running in a terminal window). Only the shell needs to go.

## Confirm the diagnosis

With a healthy shell, `qs ipc show` lists its targets and returns immediately.
With a wedged shell it hangs. Two checks:

```sh
# 1. IPC goes deaf (hangs -> the `timeout` kills it, exit 124)
timeout 3 qs -c ii ipc show >/dev/null 2>&1; echo "exit=$?"   # 0 = healthy, 124 = deaf

# 2. The main thread is pegged on CPU
top -H -b -n1 -p "$(pgrep -x qs)" | head                     # main thread near 99%
```

`124` from the first command **and** a pegged main thread = wedged shell.

Extra signs, if you look:

- The shell process has been up a long time and its RSS has grown large.
- Its IPC clients are stuck: `ps -o pid,ppid,stat,cmd --ppid "$(pgrep -x qs)"`
  shows many `qs -c ii ipc call ...` children that never exit, and
  `ss -xp | grep qs` shows connections stuck `ESTAB`.
- Hyprland's spawn of a bind hangs: repeated presses pile up those children.

## Fix (fast path)

Press **Alt+F2**. That runs `~/.config/hypr/custom/scripts/restart-shell.sh`,
which:

1. kills the wedged shell (`pgrep -x qs`) and any client still stuck on its IPC
   (command lines containing ` ipc call `), skipping its own process and
   ancestors;
2. reloads the Hyprland config (`hyprctl reload` — non-destructive, clients
   kept);
3. relaunches the shell detached (`setsid qs -c ii`), then waits for IPC to
   answer and reports the outcome with a notification.

Same thing from a terminal:

```sh
~/.config/hypr/custom/scripts/restart-shell.sh ii
```

It is single-flight: a lock file in `$XDG_RUNTIME_DIR` (stale after 30s) stops
a second press from stacking. Log: `$XDG_RUNTIME_DIR/hypr-restart-shell.log`.

Nothing you are running is interrupted. The script deliberately never restarts
the compositor binary for exactly that reason.

## Automatic recovery (watchdog)

A systemd user timer runs `~/.config/hypr/custom/scripts/shell-watchdog.sh`
every 30s and restarts the shell on its own if it is frozen. It acts **only**
when the shell is proven wedged — IPC silent twice in a row **and** the main
thread CPU-pegged over a 1s sample — so a healthy shell is never touched. In a
non-Hyprland session it is a no-op.

```sh
systemctl --user status hypr-shell-watchdog.timer      # enabled + active
systemctl --user list-timers hypr-shell-watchdog.timer
systemctl --user start hypr-shell-watchdog.service     # run one check now
journalctl --user -u hypr-shell-watchdog.service -n20  # what the checks saw
journalctl --user -t hypr-shell-watchdog -n20          # logged freeze events
```

Units: `config/systemd/user/hypr-shell-watchdog.{service,timer}`. They use the
systemd `%h` specifier for the home directory so they stay portable;
`install.sh` copies them into `~/.config/systemd/user/`. After editing a unit:

```sh
systemctl --user daemon-reload
systemctl --user restart hypr-shell-watchdog.timer
```

## Verify the fix

```sh
timeout 3 qs -c ii ipc show >/dev/null 2>&1; echo "exit=$?"   # 0 = healthy
hyprctl binds >/dev/null && echo "binds registered"
```

Then press a couple of Super binds (Super+A launcher, Super+Tab) and confirm
they respond.

## Prevention

Automatic recovery is in place; the *recurrence* is not yet fixed. A busy-loop
comes from a specific QML module inside the shell, and the shell is launched
with stdout to `/dev/null`, so a freeze leaves no log. To catch the next one:

- The watchdog logs a line when it recovers; the fresh shell's startup output
  goes to `$XDG_RUNTIME_DIR/hypr-restart-shell.log`, and quickshell keeps its
  own log under `$XDG_RUNTIME_DIR/quickshell/`.
- To reproduce with full output, run it in the foreground:

  ```sh
  pkill -x qs; qs -c ii 2>&1 | tee /tmp/qs.log
  ```

  Leave it until it wedges, then read `/tmp/qs.log`. The last module to log
  before the hang, or a repeating burst of the same debug line, names the
  culprit. Fix or disable that module, then update this runbook's Prevention
  section and the matching README bullet.

## Escape hatch

If the shell refuses to come back (recovery reports failure, or you want a
clean slate), restart the shell by hand and read its output:

```sh
pkill -x qs
qs -c ii 2>&1 | tee /tmp/qs.log
```

Log out and back in only as a last resort — that kills every open client.
