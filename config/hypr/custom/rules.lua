
-- App-specific appearance and behavior overrides.
dofile(HOME .. "/.config/hypr/custom/per-app-rules.lua")

-- Let the overview's translucent launcher pill show blurred background
hl.layer_rule({ match = { namespace = "quickshell:overview" }, ignore_alpha = 0.3 })
-- The blanket xray rule above hides windows from layer blur; the overview should blur what is behind it
hl.layer_rule({ match = { namespace = "quickshell:overview" }, xray = false })

-- The network popup animates itself (slide/scale in QML); Hyprland's own layer animation would stack on top
hl.layer_rule({ match = { namespace = "^quickshell:networkPopup$" }, no_anim = true })
