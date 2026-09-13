#!/usr/bin/env bash
set -Eeuo pipefail
FH_PROJECT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export FH_PROJECT_HOME
# Read JSON as data, never evaluate shell code from persisted paths.
mapfile -t original_paths < <(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print("\n".join(p[k] for k in ("CONFIG_BASE", "DATA_BASE", "STATE_DIR")))' "$FH_PROJECT_HOME/paths.json")
[[ ${#original_paths[@]} == 3 ]] || exit 1
CONFIG_BASE=${original_paths[0]} DATA_BASE=${original_paths[1]} STATE_DIR=${original_paths[2]}
PROJECT_HOME=$FH_PROJECT_HOME
export CONFIG_BASE DATA_BASE STATE_DIR PROJECT_HOME
[[ ! -L $STATE_DIR && ! -L $STATE_DIR/operation.lock ]] || exit 1
[[ -f $STATE_DIR/manifest.json ]] || { echo 'Install this project for the selected user first.' >&2; exit 1; }
[[ -f $FH_PROJECT_HOME/profile/config/hypr/hyprland.lua ]] || exit 1
python3 "$FH_PROJECT_HOME/bin/preflight.py"
# Package updates may outpace the API review; keep Plasma as a usable fallback.
[[ $(rpm -q --qf '%{VERSION}' hyprland) =~ ^0\.56\.[0-9]+$ ]] || { echo 'Hyprland version changed; update/review this project from Plasma.' >&2; exit 1; }
[[ $(rpm -q --qf '%{VERSION}' dms) =~ ^1\.6\.[0-9]+$ ]] || { echo 'DMS version changed; update/review this project from Plasma.' >&2; exit 1; }
# Concurrent graphical desktops under one UID can share browser profiles and
# PipeWire; require logout instead of trying to edit another session's state.
if systemctl --user is-active --quiet plasma-workspace.target; then
    echo 'Log out of Plasma before starting Hyprland (do not use Switch User for the same account).' >&2
    exit 1
fi
if systemctl --user is-active --quiet dms.service; then
    echo 'A separate dms.service is active. Stop it before starting this dedicated session; see troubleshooting.' >&2
    exit 1
fi
exec 9>"$STATE_DIR/operation.lock"
flock -n 9 || { echo 'An install, uninstall, or project session is already active.' >&2; exit 1; }
python3 "$FH_PROJECT_HOME/bin/deploy.py" links
export XDG_CONFIG_HOME="$FH_PROJECT_HOME/profile/config"
export XDG_DATA_HOME="$FH_PROJECT_HOME/profile/data"
export XDG_STATE_HOME="$FH_PROJECT_HOME/profile/state"
export XDG_DATA_DIRS="$DATA_BASE:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export DCONF_PROFILE="$XDG_CONFIG_HOME/dconf-profile"
export XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland
# Fedora supplies the GTK platform plugin for both Qt 5 and Qt 6. No global
# qt6ct override, which otherwise fails to style Qt5/KDE apps consistently.
export QT_QPA_PLATFORMTHEME=gtk3
export HYPRLAND_NO_SD_VARS=1
# Guard the released compositor's additional unguarded exec-once import path.
export PATH="$FH_PROJECT_HOME/bin/env-guard:$PATH"
export XCURSOR_THEME=breeze_cursors XCURSOR_SIZE=24
export DMS_DISABLE_CAVA=1 FH_SESSION=1
# Theme exports belong to these child processes only. No profile/environment.d
# files and no systemd --user environment are changed.
exec dbus-run-session -- python3 "$FH_PROJECT_HOME/bin/session.py"
