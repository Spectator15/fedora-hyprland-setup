#!/usr/bin/env bash
# Native parser check, not a graphical session test.
set -Eeuo pipefail
[[ ${FH_DISPOSABLE_TEST:-} == 1 && $EUID != 0 ]] || exit 1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
export HOME=$test_home CONFIG_BASE=$test_home/.config DATA_BASE=$test_home/.local/share
export STATE_DIR=$test_home/state PROJECT_HOME=$test_home/project
export XDG_RUNTIME_DIR=$test_home/run
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
Hyprland --version
dms version
python3 "$ROOT/tests/check-desktop-entry.py"
dms setup headless --compositor hyprland --terminal kitty --no-systemd
python3 "$ROOT/lib/deploy.py" install --root "$ROOT" --stage "$test_home" --extras
export XDG_CONFIG_HOME=$PROJECT_HOME/profile/config FH_PROJECT_HOME=$PROJECT_HOME
Hyprland --verify-config --config "$XDG_CONFIG_HOME/hypr/hyprland.lua"
python3 "$ROOT/lib/verify.py"
dms keybinds show hyprland > "$test_home/keybinds.json"
python3 "$ROOT/tests/check-cheatsheet.py" "$test_home/keybinds.json"
export XDG_DATA_HOME=$PROJECT_HOME/profile/data XDG_STATE_HOME=$PROJECT_HOME/profile/state
export DCONF_PROFILE=$XDG_CONFIG_HOME/dconf-profile XDG_CURRENT_DESKTOP=Hyprland
# Only the same four template families enabled in the shipped settings.
# This invokes the installed DMS/Matugen CLI, without a compositor or real home.
dbus-run-session -- dms matugen generate --kind hex --value '#8aadf4' --mode dark \
    --state-dir "$XDG_STATE_HOME/DankMaterialShell" --config-dir "$XDG_CONFIG_HOME" \
    --shell-dir /usr/share/quickshell/dms --run-user-templates=false \
    --skip-templates niri,mangowc,qt5ct,qt6ct,fcitx5,firefox,pywalfox,zenbrowser,vesktop,vencord,equibop,ghostty,foot,alacritty,wezterm,nvim,dgop,vscode,emacs,zed
for file in gtk-3.0/dank-colors.css gtk-4.0/dank-colors.css kitty/dank-theme.conf hypr/dms/colors.lua; do
    [[ -s $XDG_CONFIG_HOME/$file ]]
done
[[ -s $XDG_DATA_HOME/color-schemes/DankMatugen.colors ]]
Hyprland --verify-config --config "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf 'PASS: real DMS/Matugen generation and generated Hyprland colour syntax\n'
printf '\nrequire("fedora.clamshell")\n' >> "$XDG_CONFIG_HOME/hypr/hyprland.lua"
Hyprland --verify-config --config "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf 'PASS: optional clamshell native syntax\n'
