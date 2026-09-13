-- SDR, native preferred resolution/refresh, readable 1x scaling on the 1080p panel.
-- DMS Display Settings can create per-output overrides in dms/outputs.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb", bitdepth = 8 })
hl.config({
    general = { layout = "dwindle", gaps_in = 5, gaps_out = 10, border_size = 2, resize_on_border = true },
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        blur = { enabled = true, size = 3, passes = 2, new_optimizations = true },
        shadow = { enabled = true, range = 16, render_power = 3, color = "rgba(00000045)" },
    },
    dwindle = { preserve_split = true },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, vrr = 0 },
    render = { cm_auto_hdr = 0 },
})
-- DMS animates its own surfaces; avoid double animations and capture artifacts.
hl.layer_rule({ match = { namespace = "^dms:.*" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })
