#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${FH_SESSION:-} == 1 ]] || exit 1
# Update this private D-Bus daemon after Wayland and the Hyprland socket exist.
# Do NOT use --systemd/--all: Plasma's shared user manager must stay untouched.
dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE \
    XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_DATA_DIRS DCONF_PROFILE \
    QT_QPA_PLATFORMTHEME XCURSOR_THEME XCURSOR_SIZE
# Input inherits XKB_DEFAULT_LAYOUT when SDDM supplies it.
exec python3 "$FH_PROJECT_HOME/bin/session-ready.py"
