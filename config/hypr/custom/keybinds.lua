hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

hl.bind("SUPER + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), {description = "Input: Switch keyboard layout"})

hl.bind("ALT + Tab", hl.dsp.focus({ last = true }), { description = "Window: Focus last window" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.focus({ last = true }), { description = "Window: Focus last window" })

hl.unbind("SUPER + Tab")

-- Cycle workspaces; the overview opens as a preview only if Super is still held
-- after tabPreviewDelay ms without another Tab press, and closes on Super release.
-- toggleReleaseInterrupt stops the Super release from also toggling search.
local qsIpcSearch = "qs -c $qsConfig ipc call search"
local tabPreviewDelay = 250
local tabPreview = false
local previewShown = false
local previewTimer = nil
local function cycleWorkspace(target)
    hl.dispatch(hl.dsp.focus({ workspace = target }))
    tabPreview = true
    hl.dispatch(hl.dsp.exec_cmd(qsIpcSearch .. " toggleReleaseInterrupt"))
    if previewShown then return end
    if previewTimer then previewTimer:set_enabled(false) end
    previewTimer = hl.timer(function()
        if not tabPreview then return end
        previewShown = true
        hl.dispatch(hl.dsp.exec_cmd(qsIpcSearch .. " previewOpen"))
    end, { timeout = tabPreviewDelay, type = "oneshot" })
end
hl.bind("SUPER + Tab", function() cycleWorkspace("+1") end, { description = "Workspace: Focus next (preview while Super held)" })
hl.bind("SUPER + SHIFT + Tab", function() cycleWorkspace("-1") end, { description = "Workspace: Focus previous (preview while Super held)" })
for _, key in ipairs({ "SUPER_L", "SUPER_R" }) do
    hl.bind(key, function()
        if not tabPreview then return end
        tabPreview = false
        if previewTimer then previewTimer:set_enabled(false) end
        if previewShown then
            previewShown = false
            hl.dispatch(hl.dsp.exec_cmd(qsIpcSearch .. " close"))
        end
    end, { release = true, ignore_mods = true, transparent = true })
end

hl.unbind("SUPER + A")
hl.bind("SUPER + A", hl.dsp.exec_cmd(qsIpcSearch .. " toggle || pkill fuzzel || fuzzel"), { description = "Launcher: Toggle app launcher (fuzzel if the shell is down)" })

-- Window state: Super+Up maximize, Super+Down minimize, Super+D show desktop
local windowState = HOME .. "/.config/hypr/custom/scripts/window-state.sh"
for _, k in ipairs({ "SUPER + Up", "SUPER + Down", "SUPER + D", "SUPER + ALT + Space" }) do hl.unbind(k) end
hl.bind("SUPER + Up", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize/restore" })
hl.bind("SUPER + Down", hl.dsp.exec_cmd(windowState .. " minimize"), { description = "Window: Minimize" })
hl.bind("SUPER + SHIFT + Z", hl.dsp.exec_cmd(windowState .. " unminimize"), { description = "Window: Restore last minimized" })
hl.bind("SUPER + D", hl.dsp.exec_cmd(windowState .. " show-desktop"), { description = "Show desktop / restore windows" })
-- Floating a tiled window keeps its geometry, so nothing would visibly happen. Resize it to
-- 70% of the monitor and centre it so windowsMove animates the transition; tiling again
-- animates back into the layout.
hl.bind("SUPER + Z", function()
    local w = hl.get_active_window()
    if not w then return end
    if w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = "address:" .. w.address }))
        return
    end
    local mon = w.monitor or hl.get_active_monitor()
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = "address:" .. w.address }))
    if mon then
        local tw, th = math.floor(mon.width * 0.7), math.floor(mon.height * 0.7)
        hl.dispatch(hl.dsp.window.resize({ x = tw, y = th, exact = true, window = "address:" .. w.address }))
        hl.dispatch(hl.dsp.window.center({ window = "address:" .. w.address }))
    end
end, { description = "Window: Float/Tile" })

-- tmux-style resize: Ctrl+B enters a submap, arrows resize (repeatable), Esc/Enter/Ctrl+B exits.
local resizeStep = 40
hl.bind("CTRL + B", hl.dsp.submap("tmux-resize"), { description = "Window: tmux-style resize mode" })
hl.define_submap("tmux-resize", function()
    local dirs = { Left = { -resizeStep, 0 }, Right = { resizeStep, 0 }, Up = { 0, -resizeStep }, Down = { 0, resizeStep } }
    for key, d in pairs(dirs) do
        hl.bind(key, hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
        hl.bind("CTRL + " .. key, hl.dsp.window.resize({ x = d[1] * 3, y = d[2] * 3, relative = true }), { repeating = true })
    end
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("CTRL + B", hl.dsp.submap("reset"))
end)

-- Hold Super+X, then Super+left-drag resizes the window; releasing X exits.
hl.unbind("SUPER + X")
hl.bind("SUPER + X", hl.dsp.submap("x-resize"), { description = "Window: hold + left-drag to resize" })
hl.define_submap("x-resize", function()
    hl.bind("SUPER + mouse:272", hl.dsp.window.resize(), { mouse = true })
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

-- Release binds must be universal so they fire inside the submap; only act while in x-resize.
local function leaveXResize()
    if hl.get_current_submap() == "x-resize" then hl.dispatch(hl.dsp.submap("reset")) end
end
for _, k in ipairs({ "X", "SUPER + X", "Super_L", "Super_R", "SUPER + Super_L", "SUPER + Super_R", "code:53", "SUPER + code:53", "code:133", "code:134" }) do
    hl.bind(k, leaveXResize, { release = true, submap_universal = true, non_consuming = true })
end

-- A minimized window that gets focus (dock click, Alt+Tab) returns to the current
-- workspace instead of opening special:minimized on screen. Runs inside Hyprland.
local restoredAt = {}  -- address -> os.time(); keeps the park hook from re-hiding a just-restored window

hl.on("window.active", function(win)
    if not win or not win.workspace or win.workspace.name ~= "special:minimized" then return end
    restoredAt[win.address] = os.time()
    local mon = hl.get_active_monitor()
    local ws = mon and mon.active_workspace
    if not ws then return end
    hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = "address:" .. win.address }))
    if mon.active_special_workspace then
        hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))
    end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
end)

-- Clicking a tiled window sends overlapping floating windows to the back. Hyprland always
-- draws floating above tiled, so they are parked on special:minimized (restore via dock,
-- Alt+Tab or SUPER+SHIFT+Z).
local function rectOf(w)
    local at, sz = w.at, w.size
    local x, y = at.x or at[1], at.y or at[2]
    local ww, hh = sz.x or sz[1], sz.y or sz[2]
    return x, y, ww, hh
end

hl.on("window.active", function(win)
    if not win or win.floating or not win.workspace or win.workspace.id < 0 then return end
    local ax, ay, aw, ah = rectOf(win)
    for _, w in ipairs(hl.get_workspace_windows(win.workspace.id)) do
        if w.floating and w.mapped and not w.pinned and w.address ~= win.address
            and os.time() - (restoredAt[w.address] or 0) > 3 then
            local x, y, ww, hh = rectOf(w)
            if x < ax + aw and ax < x + ww and y < ay + ah and ay < y + hh then
                local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-window-state/minimized", "a")
                if f then f:write(w.address, "\n"); f:close() end
                hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", window = "address:" .. w.address, follow = false }))
            end
        end
    end
end)

-- Alt+Tab window picker (quickshell altTab module). Hold Alt, Tab cycles, arrows move, release Alt focuses.
-- While the picker is open we sit in the "alt-tab" submap so Alt+Arrows only navigate the picker;
-- everywhere else Alt+Arrows keep working in apps. Binds are universal so they work in and out of it.
local qsIpcAlt = "qs -c $qsConfig ipc call altTab"
local altTabOpen = false
local function altTabCall(cmd)
    altTabOpen = true
    hl.dispatch(hl.dsp.submap("alt-tab"))
    hl.dispatch(hl.dsp.exec_cmd(qsIpcAlt .. " " .. cmd .. " || hyprctl dispatch 'hl.dsp.focus({ last = true })'"))
end
for _, k in ipairs({ "ALT + Tab", "ALT + SHIFT + Tab" }) do hl.unbind(k) end
hl.bind("ALT + Tab", function() altTabCall("next") end, { description = "Window: Alt+Tab picker (next)", submap_universal = true })
hl.bind("ALT + SHIFT + Tab", function() altTabCall("prev") end, { description = "Window: Alt+Tab picker (previous)", submap_universal = true })
hl.define_submap("alt-tab", function()
    for key, cmd in pairs({ Left = "left", Right = "right", Up = "up", Down = "down" }) do
        hl.bind("ALT + " .. key, hl.dsp.exec_cmd(qsIpcAlt .. " " .. cmd), { repeating = true })
    end
    hl.bind("Escape", function()
        altTabOpen = false
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd(qsIpcAlt .. " cancel"))
    end)
end)
for _, k in ipairs({ "ALT_L", "ALT_R" }) do
    hl.bind(k, function()
        if not altTabOpen then return end
        altTabOpen = false
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd(qsIpcAlt .. " confirm"))
    end, { release = true, ignore_mods = true, transparent = true, submap_universal = true })
end
