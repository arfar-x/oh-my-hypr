

-- Restore minimized windows when they get focused (dock click, Alt+Tab)
hl.on("hyprland.start", function()
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/minimized-watcher.sh")
end)
