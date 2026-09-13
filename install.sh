#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/fedora.sh
source "$ROOT/lib/fedora.sh"
# shellcheck source=lib/repositories.sh
source "$ROOT/lib/repositories.sh"
# shellcheck source=lib/packages.sh
source "$ROOT/lib/packages.sh"
main() {
    DRY_RUN=0 WITH_EXTRAS=0 WITH_RECORDING=0 SNAPSHOT=0
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --with-extras) WITH_EXTRAS=1 ;;
            --with-recording) WITH_RECORDING=1 ;;
            --snapshot) SNAPSHOT=1 ;;
            --help|-h)
                printf 'Usage: ./install.sh [--dry-run] [--with-extras] [--with-recording] [--snapshot]\n'
                exit 0 ;;
            *) die "Unknown option: $arg" ;;
        esac
    done
    trap on_error ERR
    (( EUID != 0 )) || die 'Run ./install.sh as your normal user, without sudo. Individual package/session operations request sudo.'
    validate_fedora
    project_paths
    require_command python3
    python3 "$ROOT/runtime/preflight.py"
    deploy_args=()
    (( WITH_EXTRAS == 0 )) || deploy_args+=(--extras)
    if (( DRY_RUN )); then
        install_packages
        (( SNAPSHOT == 0 )) || log 'Would create a Snapper root snapshot only if an existing root configuration is usable.'
        log 'Would stage DMS headless setup in a temporary home, then seed its generated Lua integration.'
        python3 "$ROOT/lib/deploy.py" plan --root "$ROOT" "${deploy_args[@]}"
        exit 0
    fi
    [[ -z ${FH_SESSION:-} ]] || die 'Log out of the project Hyprland session and run this from Plasma or a TTY before updating.'
    require_command flock
    mkdir -p -- "$STATE_DIR"
    chmod 700 "$STATE_DIR"
    exec 9>"$STATE_DIR/operation.lock"
    flock -n 9 || die 'Another install/uninstall is running.'
    if (( SNAPSHOT )); then "$ROOT/scripts/snapshot.sh"; fi
    install_packages
    require_command Hyprland
    require_command dms
    dms setup headless --help | grep -q -- '--no-systemd' || die 'This DMS package lacks supported headless Lua setup. Upgrade DMS through Fedora before continuing.'
    STAGE=$(mktemp -d "$STATE_DIR/stage.XXXXXXXX")
    cleanup() { rm -rf -- "$STAGE"; }
    trap cleanup EXIT
    # Upstream setup currently uses HOME/.config explicitly. Run only in a disposable
    # staging home, with no real session/systemd access. Never run upstream force on HOME.
    env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
        HOME="$STAGE" XDG_CONFIG_HOME="$STAGE/.config" XDG_STATE_HOME="$STAGE/.local/state" \
        XDG_DATA_HOME="$STAGE/.local/share" \
        dms setup headless --compositor hyprland --terminal kitty --no-systemd
    [[ -f $STAGE/.config/hypr/dms/colors.lua ]] || die 'DMS did not generate the expected Lua integration files. No configuration deployed.'
    python3 "$ROOT/lib/deploy.py" install --root "$ROOT" --stage "$STAGE" "${deploy_args[@]}"
    env XDG_CONFIG_HOME="$PROFILE/config" FH_PROJECT_HOME="$PROJECT_HOME" \
        Hyprland --verify-config --config "$PROFILE/config/hypr/hyprland.lua" || die 'Native Hyprland parser rejected this configuration. The SDDM entry was not installed; inspect the error or use uninstall.sh.'
    SESSION_FILE=fedora-hyprland-dms-$(id -u).desktop
    SYSTEM_SESSION=/usr/share/wayland-sessions/$SESSION_FILE
    [[ ! -L $SYSTEM_SESSION ]] || die "Refusing symlinked SDDM entry: $SYSTEM_SESSION"
    if [[ -e $SYSTEM_SESSION ]] && ! cmp -s "$STATE_DIR/$SESSION_FILE" "$SYSTEM_SESSION"; then
        die "A different file exists at $SYSTEM_SESSION. Inspect it; it will not be overwritten."
    fi
    sudo install -m 644 -- "$STATE_DIR/$SESSION_FILE" "$SYSTEM_SESSION"
    log 'Installed. Log out and choose Hyprland (Fedora DMS) in SDDM. Plasma is unchanged.'
    "$ROOT/scripts/verify-install.sh"
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
