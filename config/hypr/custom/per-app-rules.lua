-- Per-application window rules.

-- VS Code: match HyDE's 80% opacity and allow Hyprland to blur behind it.
hl.window_rule({
    match = {class = "^(code-oss|[Cc]ode|codium|vscodium)$"},
    opacity = "0.8 override 0.8 override 1.0 override",
    no_blur = false
})

-- Kitty: match HyDE's 80% opacity and allow Hyprland to blur behind it.
hl.window_rule({
    match = {class = "^kitty$"},
    opacity = "0.8 override 0.8 override 1.0 override",
    no_blur = false
})

-- Telegram: same translucency + blur as VS Code.
hl.window_rule({
    match = {class = "^org\\.telegram\\.desktop$"},
    opacity = "0.8 override 0.8 override 1.0 override",
    no_blur = false
})

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

