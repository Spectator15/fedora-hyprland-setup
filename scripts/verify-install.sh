#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/fedora.sh
source "$ROOT/lib/fedora.sh"
if [[ ${FH_SESSION:-} == 1 ]]; then
    PROJECT_HOME=$FH_PROJECT_HOME
    PROFILE=$PROJECT_HOME/profile
    # CONFIG_BASE and STATE_DIR were retained by the session wrapper.
else
    project_paths
fi
export PROJECT_HOME PROFILE
failures=0
check() {
    local label=$1; shift
    if "$@"; then log "PASS: $label"; else warn "FAIL: $label"; failures=$((failures + 1)); fi
}
version=$(fedora_version || true)
case "$version" in
    43|44) log "PASS: Fedora $version" ;;
    *) warn 'FAIL: expected Fedora 43/44'; failures=$((failures + 1)) ;;
esac
for command in Hyprland hyprctl dms qs matugen kitty dolphin wl-copy dbus-run-session dbus-update-activation-environment python3 flock; do
    check "command $command" command -v "$command"
done
if command -v dms >/dev/null; then check 'DMS version' dms version; fi
if command -v rpm >/dev/null; then
    check 'Plasma and SDDM packages retained' rpm -q plasma-workspace sddm
    hypr_version=$(rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || true)
    check "Hyprland API version $hypr_version" version_supported "$hypr_version"
    dms_version=$(rpm -q --qf '%{VERSION}' dms 2>/dev/null || true)
    check "DMS API version $dms_version" dms_supported "$dms_version"
    log 'Existing power stack (informational):'
    rpm -q tuned tuned-ppd power-profiles-daemon tlp 2>/dev/null || true
fi
check 'Plasma session available' bash -c 'compgen -G "/usr/share/wayland-sessions/plasma*.desktop" >/dev/null'
check 'Project SDDM session available' test -f "/usr/share/wayland-sessions/fedora-hyprland-dms-$(id -u).desktop"
check 'Project configuration and Plasma isolation' python3 "$ROOT/lib/verify.py"
check 'Original Hyprland files safe from DMS legacy migration' python3 "$ROOT/runtime/preflight.py"
if command -v Hyprland >/dev/null && [[ -f $PROFILE/config/hypr/hyprland.lua ]]; then
    check 'Hyprland native configuration parser' env XDG_CONFIG_HOME="$PROFILE/config" \
        FH_PROJECT_HOME="$PROJECT_HOME" Hyprland --verify-config --config "$PROFILE/config/hypr/hyprland.lua"
fi
if [[ ${FH_SESSION:-} == 1 && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    check 'Running Hyprland and keybind conflicts' python3 "$ROOT/lib/verify.py" --live
    check 'DMS shell responds' timeout 8 dms ipc call theme getMode
    check 'Screen-sharing portal' test -f /usr/share/xdg-desktop-portal/portals/hyprland.portal
else
    log 'SKIP: compositor, DMS IPC, input hardware and live portals (outside the project session).'
fi
log "$failures failed checks. Real hardware checks are in docs/testing.md."
(( failures == 0 ))
