#!/usr/bin/env python3
"""Guard an upstream DMS 1.6 migration which currently ignores XDG_CONFIG_HOME."""
from pathlib import Path

legacy = Path.home() / ".config/hypr"
if (legacy / "hyprland.lua").exists():
    affected = [p for p in [legacy / "hyprland.conf", *(legacy / "dms").glob("*.conf")]
                if p.is_symlink() or p.is_file()]
    if affected:
        raise SystemExit(
            "DMS 1.6 would migrate files in your original ~/.config/hypr despite XDG isolation. "
            "Startup was stopped before that can happen. Back up and relocate obsolete .conf "
            "files yourself, or retain your current Hyprland setup. See docs/troubleshooting.md.\n"
            + "\n".join(str(p) for p in affected))
