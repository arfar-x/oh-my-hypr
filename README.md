<div align="center">

# oh-my-hypr

**Personal customizations layered on a stock [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse) install.**

![Hyprland](https://img.shields.io/badge/Hyprland-Lua%20config-58E1FF?style=flat-square)
![Quickshell](https://img.shields.io/badge/Quickshell-ii%20shell-9B87F5?style=flat-square)
![Upstream](https://img.shields.io/badge/dots--hyprland-2f2a376-informational?style=flat-square)
![Platform](https://img.shields.io/badge/Arch-Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

</div>

`config/` mirrors `~/.config`. Only files that **differ from upstream** are included.

## Contents

- [Quick start](#quick-start)
- [Requirements](#requirements)
- [Hyprland](#hyprland)
- [Quickshell: windows and overlays](#quickshell-windows-and-overlays)
- [Quickshell: bar](#quickshell-bar)
- [Quickshell: on-screen display](#quickshell-on-screen-display)
- [Quickshell: settings and services](#quickshell-settings-and-services)
- [Terminal and recovery](#terminal-and-recovery)

## Quick start

| Action | Command | Notes |
|---|---|---|
| Install | `./install.sh` | Idempotent. Overwrites only changed files and creates no backups or leftovers. |
| Install without packages | `./install.sh --skip-deps` | Skips the package step below. |
| Preview removal | `./uninstall.sh --dry-run` | Shows what would be restored or deleted. |
| Uninstall | `./uninstall.sh` | Restores the stock end-4 version of every file, deletes files this repo added, and has end-4 regenerate the terminal palette. Needs network access to fetch the stock files. |

`install.sh` also installs the packages the customizations need, using `sudo pacman` and `yay`/`paru`, and enables `power-profiles-daemon`:

- **Idle settings:** `power-profiles-daemon`, `hypridle`, `brightnessctl`, `jq`
- **Screensaver:** `kitty`, `cmatrix`, `genact`, `cbonsai`, `hollywood` (the last two from the AUR)

## Requirements

`fuzzel`, `kitty`, `fish`, `starship`, `eza`, `ttf-jetbrains-mono-nerd`.

Written against dots-hyprland commit `2f2a376`.

---

## Hyprland

### Keybinds: `hypr/custom/keybinds.lua`

| Keys | Action |
|---|---|
| `Ctrl+B` | tmux-style **resize mode**. Arrows resize, `Ctrl+Arrow` takes bigger steps, `Esc`/`Enter`/`Ctrl+B` exit. |
| `Ctrl+Super+Space` | **Cycle the tiling model** of the active workspace: dwindle, then master left/top/right/bottom (tmux next-layout style). Re-tiles only tiled windows. No-op while any window on the workspace is maximized or fullscreen, or when fewer than 2 are tiled. |
| Hold `Super+X` + left-drag | Resize a window. |
| `Super+Up` / `Super+Down` | Maximize / minimize. |
| `Super+Shift+Z` | Restore. |
| `Super+D` | Show desktop. |
| `Super+Z` | Float / tile. |
| `Alt+Tab` | Window picker. Hold Alt, Tab cycles, release focuses. |
| `Super+Tab` | Workspace cycle with overview preview. |
| `Super+A` | fuzzel. |
| `Super+P` | Display mode picker (see [displayMode](#quickshell-windows-and-overlays)). Window pin moves to `Super+Alt+P`. |
| `Alt+F2` | Restart a wedged shell (see [Terminal and recovery](#terminal-and-recovery)). |
| `Ctrl+Super+Z` | Toggle the terminal screensaver. |

Pressing any key while Super is held cancels the tap-Super-to-open-launcher action. Upstream's catchall bind isn't allowed outside submaps in the Lua API, so a raw key-event handler does it. Super+mouse drag/scroll binds cancel it too.

### Rules and appearance

- **`hypr/custom/per-app-rules.lua` and `rules.lua`**: translucency and blur for VS Code, Kitty, Telegram and Hermes through one shared `glass()` helper. The base is 80%. When focused, VS Code is 92% and Telegram and Hermes are 90%, for readability. fuzzel, overview and the Alt+Tab picker get layer blur.
- **`hypr/custom/variables.lua`**: `Super+Enter` and `Ctrl+Alt+T` open kitty first. Upstream prefers foot, which would bypass the kitty look and rules.
- **`hypr/custom/general.lua`**: window move/resize animation curve.
- **`hypr/hyprland/{general,keybinds}.lua`, `hyprlock.conf`**: small edits to upstream (scroll factor, `Super+A`, workspace move keys, 12h lock clock).

### Window state: `hypr/custom/scripts/`

Minimize and show-desktop state handling:

- **Restore on focus.** Focusing a minimized window (dock click, Alt+Tab) restores it through a `window.active` hook in `keybinds.lua`.
- **Park on click.** Clicking a tiled window (not merely hovering) parks overlapping floating windows the same way, because floating always draws above tiled in Hyprland.
- **Minimize effect.** Minimize plays a shrink-to-dock effect (quickshell `minimizeFx`).
- **Float toggle.** `Super+Z` resizes to 70% and centres when floating, so the toggle animates, and tags the window `zfloat`.
- **Border.** A rotating gradient border (primary, tertiary and secondary of the wallpaper palette, with a `borderangle` loop animation in `general.lua`) comes from a rule appended to the matugen `hyprland/colors.lua` template. It follows the wallpaper and shows after the next wallpaper/palette regeneration.

### Display modes: `hypr/custom/scripts/display-mode.sh`

Applies a display mode with `hyprctl eval hl.monitor{...}`: `join | mirror | primary | secondary`. `info` prints the monitors and the current mode.

- **Primary monitor** is the built-in panel (eDP/LVDS/DSI), or the first monitor.
- **Overlap warning.** Steps are ordered so two enabled monitors never share space, because Hyprland warns "Monitor X overlaps with other monitor(s)" even for a momentary overlap.
- **Feedback.** The result shows as the layout OSD pill with an icon. In the single-display modes it waits until quickshell has redrawn on the remaining screen.
- **Not persisted.** A reload goes back to the configured layout.

---

## Quickshell: windows and overlays

| Module | What it does |
|---|---|
| `quickshell/ii` | Overview with a browsable app list (`IdleAppBrowser`), category chips, pinned apps and letter sections. |
| `modules/ii/altTab` | **Alt+Tab picker.** Live thumbnails, minimized windows included, hover close button, frosted background, and one picker per monitor with a short fade. Registered in `panelFamilies/IllogicalImpulseFamily.qml`. |
| `modules/ii/displayMode` | **`Super+P` display mode picker** in the Alt+Tab card style, with drawn two-monitor icons: *Join Displays (extend)*, *Mirror*, *Primary Only*, *Secondary Only*. Hold Super; `P` (or `Super+Left/Right`) cycles, releasing Super applies, `Esc` cancels. It opens on the current mode, so a quick tap changes nothing. Driven over IPC (`displayMode open\|next\|prev\|left\|right\|confirm\|cancel`) from a submap in `hypr/custom/keybinds.lua`, and registered in `panelFamilies/IllogicalImpulseFamily.qml`. Also available as a `displayMode` quick toggle in the right sidebar's Android-style panel (add it in the panel's edit mode). |
| `modules/ii/minimizeFx` | A snapshot of the window shrinks toward the dock when minimized. Called over IPC by `window-state.sh`. |

## Quickshell: bar

### Network popup: `modules/ii/bar/NetworkPopup.qml`

A separate network button in the bar. It replaces the icon inside the right sidebar button.

- Click opens a popup with the current wired connection on top (the active Wi-Fi network is listed first), the Wi-Fi switch, nearby networks (connect, password prompt) and VPN on/off switches.
- Opens on the screen whose button was clicked (multi-monitor safe) and slides in without blinking.
- Uses a fixed-size window with an input mask so it never resizes while open. `custom/rules.lua` turns off Hyprland's own layer animation for it.
- A VPN-connected icon shows in the bar while any VPN/tunnel is up (NetworkManager VPN/WireGuard or tun/wg/ppp-style interfaces). A critical notification fires when it drops.
- VPN state, listing and toggle live in `services/Network.qml`. `BarContent.qml` and `GlobalStates.qml` carry the small wiring edits.

### Layout tweaks: `bar/{ClockWidget,BarContent,SysTray,StyledPopup}.qml`, `sidebarRight/SidebarRightContent.qml`

- Larger, bold clock.
- Right-hand icons reordered, left to right: language indicator (switches the layout on click), notification bell, tray, mic/mute and Bluetooth (only while relevant), network (with the VPN icon in the same button), battery, then the sidebar toggle, rightmost.
- The two centre groups are narrowed by 117px to give the icon container room for three more icons.
- **Overflow menu.** When the icons don't fit, a "⋯" button appears next to the language indicator. The overflowing icons move into its dropdown in this order: microphone, bell, tray icons one by one, then mute, Bluetooth, network. The dropdown hosts the real widgets, so tray menus and the network list still work from it. The check runs on a short timer, needs spare room before un-hiding, and stops re-evaluating after a burst of changes, so a measurement loop cannot hang the shell.
- Popups are clamped to stay on screen.
- The colour picker and dark/light toggle live in the right sidebar's top button row. To remove them from the bar, turn off `bar.utilButtons.showColorPicker`, `showDarkModeToggle` and `showKeyboardToggle` in the live config.

### Public IP: `bar/PublicIpWidget.qml` + `services/PublicIp.qml`

A public IP widget on the right side of the bar, showing a country flag and the IP from a default source.

- Checked every 5 minutes.
- Left-click refreshes, right-click copies, and it notifies when the IP changes.
- Hovering shows location and ISP, and checks the other sources for comparison (30s timeout, per-source errors).
- Sources and the default are set in `PublicIp.qml`. `BarContent.qml` carries the small wiring edit.

### Workspaces

- **`modules/common/models/WorkspaceModel.qml`**: the bar no longer shows a stray `special` pill when no special workspace is open. Upstream falls back to the name `special` whenever the monitor lookup returns nothing.
- **`bar/Workspaces.qml`, `services/HyprlandData.qml`, `WorkspaceModel.qml`**: with the desktop shown (`Super+D` parks all windows on `special:desktop`), the workspace pills keep their app icons in the shrinked "Super held" form (number plus a small corner icon) instead of going blank. `HyprlandData` reads the `hypr-window-state/desktop` origin mapping that `window-state.sh` writes, so each parked window's icon lands back on its origin workspace and such workspaces still count as occupied.
- **`services/HyprlandXkb.qml`**: the keyboard-layout indicator follows only the main keyboard. Hyprland emits `activelayout` per input device, and devices that register as keyboards (e.g. Bluetooth headsets) can sit on a different layout and made the indicator show the wrong one.

## Quickshell: on-screen display

All under `modules/ii/onScreenDisplay/`.

- **Power profile.** Changing the power profile shows the same OSD pill as the keyboard layout, with the profile icon and "Switched to ...".
- **Keyboard layout.** `Super+Space` shows the new layout as a minimal OSD pill (`indicators/LayoutIndicator.qml`, IPC `osdVolume layout <label>`, driven by `hypr/custom/scripts/switch-layout.sh`) instead of a notification. `OnScreenDisplay.qml` also gives every OSD indicator (volume, brightness, gamma, layout) one shared fade and spring-scale animation, and keeps the window alive briefly so the exit animation plays. `GlobalStates.qml` carries `osdLayoutLabel`.
- **Icon variant.** IPC `osdVolume layoutIcon <icon> <label>` shows the same pill with a Material symbol before the label (used by the display mode picker). The OSD falls back to the first remaining screen when Hyprland has no focused monitor, which happens after a monitor is turned off.

## Quickshell: settings and services

### Desktop clock font: `background/widgets/clock/ClockWidget.qml`, `settings/BackgroundConfig.qml`, `state/fonts`

The desktop clock's digital digits gain a **Number font style** picker in *Settings > Background*:

- The stock Google Sans Flex. Re-selecting it restores the original size, weight and roundness.
- **Dot matrix** or **Dot matrix (mono)**: Matrix Sans Print / Matrix Mono Print (OFL, in `state/fonts/`, installed to `~/.local/share/fonts/matrix-sans` by `install.sh`). This is the round 5×7 LED-dot look.

The lock screen always mirrors the desktop clock style (digital or cookie). The old separate "clock style (locked)" option is gone, so the two can never drift apart.

### Idle settings: `settings/GeneralConfig.qml`, `common/Config.qml`, `services/IdleManager.qml`, `scripts/idle/apply.sh`

Under `Super+I > General > Idle`, per power profile (power saver / balanced / performance), set the minutes until each step. `0` disables a step:

| Step | Extra setting |
|---|---|
| Dim | dimmed brightness % |
| Screensaver | |
| Lock | |
| Screen off | |
| Suspend | |

`IdleManager` regenerates `hypr/hypridle.conf` and restarts hypridle when the active profile or a value changes. Needs `power-profiles-daemon`.

### Terminal screensaver: `scripts/idle/screensaver.sh`, `keybinds.lua`, `rules.lua`

- `Ctrl+Super+Z` toggles it. The Idle settings can also start it after N idle minutes (a hypridle step before lock).
- It puts an overlay panel (kitty `panel`, above the bar) on every monitor over your desktop. The panel is blurred and darkened by the profile's dimmed brightness (or the wallpaper, see "Screensaver backdrop"). It runs cmatrix, cbonsai (one large tree growing step by step), hollywood or genact. "Random" picks among the installed ones.
- While it runs, a Hyprland `screensaver` submap makes any key or mouse button stop it. Moving the mouse stops it too, whatever the animation does with input.
- `rules.lua` blurs the panel's layer.

### OpenRouter AI provider: `services/ai/OpenRouterApiStrategy.qml`

An OpenRouter provider for the `Super+B` AI sidebar.

| Feature | How |
|---|---|
| Model catalogue | The full OpenRouter catalogue is fetched at startup and searchable with `/model`. |
| Cost | Per-chat cost chip and `/credits`. |
| Reasoning | `/reasoning off\|low\|medium\|high` |
| Web search | `/tool search` enables OpenRouter web search. |
| Attachments | `/attach` sends images and PDFs. |
| API keys | From `OPENROUTER_API_KEY` / `GEMINI_API_KEY` / `MISTRAL_API_KEY`. A key saved with `/key` wins. |

Small edits in `services/Ai.qml`, `services/ai/{AiModel,ApiStrategy,OpenAiApiStrategy}.qml` and `sidebarLeft/AiChat.qml`.

## Terminal and recovery

### Pinned palette: `state/terminal`

`kitty-theme.conf` and `sequences.txt` are the generated terminal palette (kitty colors and fish/starship color sequences), pinned so kitty and fish look identical on a new machine. The kitty and fish configs themselves are stock end-4. Kitty's 80% opacity and blur come from the `glass()` helper in `per-app-rules.lua`. end-4 overwrites the palette when the wallpaper or theme changes.

### Shell recovery: `restart-shell.sh`, `shell-watchdog.sh`, `systemd/user/hypr-shell-watchdog.*`

Recovery for when a wedged quickshell takes the whole keybind surface down. Nearly every Super bind routes through the shell, and when its main thread busy-loops, its IPC goes deaf.

- **`Alt+F2`** runs `restart-shell.sh`. It kills the frozen shell and any client stuck on its IPC, reloads the Hyprland config, and relaunches the shell detached. It never touches the compositor binary, which would kill every Wayland client.
- **Watchdog.** A systemd user timer checks every 30s and restarts only when the shell is proven frozen (IPC silent twice and main thread CPU-pegged). A healthy shell is untouched.

See [RUNBOOK.md](RUNBOOK.md).
