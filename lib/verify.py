#!/usr/bin/env python3
"""Read-only diagnostics. Never starts a compositor or writes user configuration."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    if "--live" in sys.argv:
        errors = subprocess.check_output(["hyprctl", "configerrors"], text=True).strip()
        if errors and errors != "ok":
            raise ValueError(errors)
        binds = json.loads(subprocess.check_output(["hyprctl", "-j", "binds"], text=True))
        keys = set()
        for bind in binds:
            identity = (bind.get("submap", ""), bind.get("modmask"), bind.get("key", "").lower(), bind.get("keycode"), bind.get("release", False), bind.get("mouse", False))
            if identity in keys:
                raise ValueError(f"Duplicate live bind: {identity}")
            keys.add(identity)
        print("PASS: no live config errors/duplicate bind identities")
        return
    project = Path(os.environ["PROJECT_HOME"])
    profile = project / "profile/config"
    files = ["hypr/hyprland.lua", "hypr/dms/binds-user.lua", "hypr/dms/colors.lua",
             "hypr/dms/outputs.lua", "hypr/dms/layout.lua", "hypr/dms/cursor.lua",
             "hypr/dms/windowrules.lua", "hypr/fedora/keybinds.lua", "hypr/fedora/input.lua",
             "DankMaterialShell/settings.json", "xdg-desktop-portal/hyprland-portals.conf"]
    for name in files:
        if not (profile / name).is_file():
            raise ValueError(f"Missing config: {profile / name}")
    for path in project.rglob("*"):
        if path.is_symlink() and not path.exists():
            raise ValueError(f"Broken symlink: {path}")
    for name in ("hypr", "DankMaterialShell", "gtk-3.0", "gtk-4.0", "qt5ct", "qt6ct", "dconf", "kdeglobals"):
        if (profile / name).is_symlink():
            raise ValueError(f"Theme isolation violated: {name} is a symlink")
    for path in (profile / "hypr").rglob("*.lua"):
        content = "\n".join(line for line in path.read_text().splitlines() if not line.lstrip().startswith("--"))
        if re.search(r'\bcm\s*=\s*["\'](?:hdr[^"\']*|wide)["\']|bitdepth\s*=\s*10|cm_auto_hdr\s*=\s*[1-9]', content):
            raise ValueError(f"HDR/wide-gamut enabled in {path}")
    if 'fingers = 3, direction = "horizontal", action = "workspace"' not in (profile / "hypr/fedora/input.lua").read_text():
        raise ValueError("Native three-finger workspace gesture missing")
    settings = json.loads((profile / "DankMaterialShell/settings.json").read_text())
    if settings.get("matugenTemplateVscode"):
        print("NOTE: editor theme integration enabled by user; editor settings may be shared with Plasma")
    base = Path(os.environ.get("CONFIG_BASE", str(Path.home() / ".config")))
    globals_to_check = [Path.home() / ".profile", Path.home() / ".bash_profile", Path.home() / ".bashrc", Path("/etc/environment")]
    globals_to_check.extend((base / "environment.d").glob("*"))
    globals_to_check.extend(Path("/etc/profile.d").glob("*"))
    for path in globals_to_check:
        if path.is_file():
            content = path.read_text(errors="replace")
            if "fedora-hyprland-setup" in content and re.search(r"QT_QPA_PLATFORMTHEME|QT_STYLE_OVERRIDE|GTK_THEME|XDG_CONFIG_HOME|XDG_DATA_DIRS|DBUS_SESSION_BUS_ADDRESS|import-environment", content):
                raise ValueError(f"Project theme export found in shared startup file: {path}")
    print("PASS: files, links, gestures, SDR defaults and Plasma theme isolation")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"FAIL: {error}") from error
