# oh-my-hypr

Personal customizations for a stock [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse) install. `config/` mirrors `~/.config`; only files that differ from upstream are included.

Apply: `./install.sh` (backs up replaced files as `*.pre-oh-my-hypr`).

## What's in it
- **hypr/custom/keybinds.lua** – Ctrl+B tmux-style resize mode (arrows, Ctrl+Arrow = bigger steps, Esc/Enter/Ctrl+B exit); hold Super+X + left-drag to resize; Super+Up maximize, Super+Down minimize, Super+Shift+Z restore, Super+D show desktop, Super+Z float/tile; Super+Tab workspace cycle with overview preview; Super+A fuzzel.
- **hypr/custom/per-app-rules.lua / rules.lua** – translucency + blur for VS Code, Kitty, Telegram; fuzzel blur; overview layer blur.
- **hypr/custom/scripts/** – minimize / show-desktop state handling and watcher.
- **hypr/custom/general.lua** – window move/resize animation curve.
- **hypr/hyprland/{general,keybinds}.lua, hyprlock.conf** – small edits to upstream (scroll factor, Super+A, workspace move keys, 12h lock clock).
- **quickshell/ii** – overview with browsable app list (IdleAppBrowser), category chips, pinned apps, letter sections.

Requires fuzzel. Written against dots-hyprland commit 2f2a376.
