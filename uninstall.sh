#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
trap on_error ERR
DRY_RUN=0
case "${1:-}" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) echo 'Usage: ./uninstall.sh [--dry-run]'; exit 0 ;;
    '') ;;
    *) die "Unknown option: $1" ;;
esac
(( $# <= 1 )) || die 'Too many arguments.'
(( EUID != 0 )) || die 'Run as your normal user without sudo.'
[[ -z ${FH_SESSION:-} ]] || die 'Log out of Hyprland first; run uninstall from Plasma or a TTY.'
project_paths
[[ -f $STATE_DIR/manifest.json ]] || { log 'No recorded installation for this user.'; exit 0; }
require_command python3
require_command flock
if (( ! DRY_RUN )); then
    exec 9>"$STATE_DIR/operation.lock"
    flock -n 9 || die 'The project session or another install/uninstall is active. Log out first.'
fi
SESSION_FILE=fedora-hyprland-dms-$(id -u).desktop
SYSTEM_SESSION=/usr/share/wayland-sessions/$SESSION_FILE
# Check manifest paths and all backups before removing the login entry.
python3 "$ROOT/lib/deploy.py" uninstall --dry-run >/dev/null
if [[ -e $SYSTEM_SESSION ]]; then
    if [[ ! -L $SYSTEM_SESSION ]] && cmp -s "$STATE_DIR/$SESSION_FILE" "$SYSTEM_SESSION"; then
        run sudo rm -- "$SYSTEM_SESSION"
    else
        warn "Changed SDDM entry retained: $SYSTEM_SESSION"
    fi
fi
args=()
(( DRY_RUN == 0 )) || args+=(--dry-run)
python3 "$ROOT/lib/deploy.py" uninstall "${args[@]}"
log 'Packages, COPRs, snapshots, backups, and modified/generated settings are retained. Plasma was not changed.'
