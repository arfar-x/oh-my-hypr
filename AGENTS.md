# AGENTS.md

Personal customizations layered on a stock [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse) install. Not an application: no build, no tests, no CI. See [README.md](README.md) for what each customization does.

## Layout
- `config/` mirrors `~/.config`. Only files that **differ from upstream** live here; do not add unchanged upstream files.
- `config/hypr/custom/*.lua` – user override files that upstream loads and never overwrites. Put new Hyprland behavior here.
- `config/hypr/hyprland/*.lua`, `hyprlock.conf` – small edits to upstream files. Keep these minimal.
- `config/quickshell/ii/` – QML edits and additions to the `ii` shell (Alt+Tab picker in `modules/ii/altTab/`, registered in `panelFamilies/IllogicalImpulseFamily.qml`).
- `install.sh` – copies `config/` into `~/.config`, backing up replaced files as `<file>.pre-oh-my-hypr`, then runs `hyprctl reload`.

## Workflow: live config is the working copy
The files actually running are in `~/.config`, not in this repo. Edit and test there, then copy the changed files back into `config/`.
- Find what needs syncing (run from `config/`):
  `for f in $(find . -type f | sed 's|^\./||'); do if [ ! -e ~/.config/$f ]; then echo "GONE $f"; elif ! cmp -s "$f" ~/.config/$f; then echo "DIFF $f"; fi; done`
- A `DIFF` may be an unrelated live setting. Check `diff` before copying it in.
- A new file under `~/.config` that belongs to a customization must be added to `config/` at the same relative path. A file deleted live must be `git rm`'d here.
- Update the matching bullet in `README.md` when behavior changes.

## Verify changes
- Hyprland (Lua config): `hyprctl reload`, then `hyprctl configerrors` (empty output = OK).
- Quickshell QML: edits hot-reload; confirm with `qs -c ii log` and `qs -c ii ipc show` (a new IPC target should be listed). Full restart: `killall qs quickshell; qs -c ii &`.
- Keybinds: `hyprctl binds -j` shows what registered.
- Hyprland dispatchers can be exercised without a keypress, e.g. `hyprctl dispatch "hl.dsp.focus({ last = true })"`.

## Conventions
- Hyprland config is Lua (`hl.*` API; type stubs at `/usr/share/hypr/stubs/hl.meta.lua`), not hyprlang.
- Override an upstream binding in `custom/keybinds.lua` with `hl.unbind(...)` followed by `hl.bind(...)`; override upstream global functions (e.g. `workspace_in_group`) by redefining them there too.
- Only generic, reproducible configuration belongs here. Never commit personal or machine-specific data: usernames or home paths, API keys/tokens/endpoints, company or account names, hardware device paths, locale/keyboard-layout choices, wallpapers. Check `git diff` for these before every commit; do not mirror whole live settings files such as `illogical-impulse/config.json`.
- Commit messages: Conventional Commits (`type(scope): subject`, e.g. `feat(altTab): ...`). Plain text describing the change only. Never add Claude- or agent-specific metadata: no `Co-Authored-By` trailers naming an AI, no "Generated with ..." lines, no tool or agent names.
- README states it is written against dots-hyprland commit `2f2a376`; upstream changes may require re-syncing the edited upstream files.
