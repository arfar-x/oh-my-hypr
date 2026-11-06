-- Faster, smoother window move/resize (Super+Z float toggle, tiling reflow)
hl.curve("smoothOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.2, bezier = "smoothOut", style = "slide" })
