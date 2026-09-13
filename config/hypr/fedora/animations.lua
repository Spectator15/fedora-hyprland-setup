-- Small adaptation of Dusky's FLUID "Showcase" curves, with shorter timings
-- and less zoom. Upstream MIT notice: LICENSES/Dusky-MIT.txt; see docs/upstream.md.
hl.curve("fh_overshoot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("fh_fluid", { type = "bezier", points = { {0.25, 1}, {0, 1} } })
hl.curve("fh_snap", { type = "bezier", points = { {0.5, 0.9}, {0.1, 1.05} } })
hl.curve("fh_linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.5, bezier = "fh_overshoot", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "fh_snap", style = "popin 96%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "fh_fluid" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "fh_overshoot", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, bezier = "fh_fluid", style = "slidevert" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "fh_fluid" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "fh_linear" })
hl.animation({ leaf = "borderangle", enabled = false }) -- no continuous idle rendering
hl.animation({ leaf = "layersOut", enabled = false })
