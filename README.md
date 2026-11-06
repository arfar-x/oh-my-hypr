# oh-my-hypr

Personal customizations for a stock [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse) install. `config/` mirrors `~/.config`; only files that differ from upstream are included.

Apply: `./install.sh` (idempotent: overwrites only changed files, creates no backups or leftovers).

Remove everything again: `./uninstall.sh` (`--dry-run` to preview). Restores the stock end-4 version of every file, deletes files this repo added, and has end-4 regenerate the terminal palette. Needs network access to fetch the stock files.

## What's in it
- **hypr/custom/keybinds.lua** – Ctrl+B tmux-style resize mode (arrows, Ctrl+Arrow = bigger steps, Esc/Enter/Ctrl+B exit); hold Super+X + left-drag to resize; Super+Up maximize, Super+Down minimize, Super+Shift+Z restore, Super+D show desktop, Super+Z float/tile; Alt+Tab window picker (hold Alt, Tab cycles, release focuses); Super+Tab workspace cycle with overview preview; Super+A fuzzel.
- **hypr/custom/per-app-rules.lua / rules.lua** – translucency + blur for VS Code, Kitty, Telegram; fuzzel, overview and Alt+Tab picker layer blur.
- **hypr/custom/scripts/** – minimize / show-desktop state handling. Focusing a minimized window (dock click, Alt+Tab) restores it via a `window.active` hook in keybinds.lua. Clicking (not merely hovering) a tiled window parks overlapping floating windows the same way (floating always draws above tiled in Hyprland). Minimize plays a shrink-to-dock effect (quickshell minimizeFx); Super+Z resizes to 70% and centres when floating so the toggle animates.
- **hypr/custom/variables.lua** – Super+Enter / Ctrl+Alt+T open kitty first (upstream prefers foot, which would bypass the kitty look and rules).
- **hypr/custom/general.lua** – window move/resize animation curve.
- **hypr/hyprland/{general,keybinds}.lua, hyprlock.conf** – small edits to upstream (scroll factor, Super+A, workspace move keys, 12h lock clock).
- **quickshell/ii** – overview with browsable app list (IdleAppBrowser), category chips, pinned apps, letter sections.
- **quickshell/ii/modules/ii/altTab** – Alt+Tab picker: live thumbnails, minimized windows included, hover close button, frosted background; registered in panelFamilies/IllogicalImpulseFamily.qml.
- **quickshell/ii/modules/ii/minimizeFx** – snapshot of the window shrinks toward the dock when minimized; called over IPC by window-state.sh.
- **state/terminal** – kitty-theme.conf + sequences.txt, the generated terminal palette (kitty colors and fish/starship color sequences) pinned so kitty and fish look identical on a new machine. The kitty and fish configs themselves are stock end-4; kitty's 80% opacity + blur comes from per-app-rules.lua. end-4 overwrites the palette when the wallpaper/theme changes.

Requires fuzzel, kitty, fish, starship, eza, ttf-jetbrains-mono-nerd. Written against dots-hyprland commit 2f2a376.
