-- Per-application window rules.

-- Frosted-glass windows: translucent with Hyprland blur behind them.
-- Hyprland's opacity applies to the whole window, text included, so text-heavy apps
-- get a higher focused value for readability. Unfocused windows stay at the base glass level.
local GLASS = 0.8

local function glass(class, focused)
    hl.window_rule({
        match = {class = class},
        opacity = string.format("%s override %s override 1.0 override", focused, GLASS),
        no_blur = false
    })
end

glass("^(code-oss|[Cc]ode|codium|vscodium)$", 0.92) -- VS Code: dense small text
glass("^kitty$", GLASS)
glass("^org\\.telegram\\.desktop$", 0.90) -- Telegram: chat text
glass("^com\\.nousresearch\\.hermes$", 0.90) -- Hermes: chat text

-- Fuzzel: frosted glass
hl.layer_rule({
    name = "fuzzel-blur",
    match = {
        namespace = "^fuzzel$",
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.10,
})


-- Alt+Tab picker: frosted glass like kitty/telegram/vscode.
-- xray off so the blur samples the windows behind it, not just the wallpaper.
hl.layer_rule({
    name = "alttab-blur",
    match = { namespace = "^quickshell:altTab$" },
    blur = true,
    ignore_alpha = 0.1,
    xray = false,
})
