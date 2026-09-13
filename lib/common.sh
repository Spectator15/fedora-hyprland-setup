#!/usr/bin/env bash
# Shared by the installer and diagnostics. No work occurs merely by sourcing it.
log() { printf '[fedora-hyprland] %s\n' "$*"; }
warn() { printf '[warning] %s\n' "$*" >&2; }
die() { printf '[error] %s\n' "$*" >&2; exit 1; }
run() {
    if (( DRY_RUN )); then
        printf '[dry-run]'; printf ' %q' "$@"; printf '\n'
    else
        "$@"
    fi
}
require_command() { command -v "$1" >/dev/null || die "Missing command: $1"; }
project_paths() {
    CONFIG_BASE=${XDG_CONFIG_HOME:-$HOME/.config}
    DATA_BASE=${XDG_DATA_HOME:-$HOME/.local/share}
    STATE_BASE=${XDG_STATE_HOME:-$HOME/.local/state}
    PROJECT_HOME=$DATA_BASE/fedora-hyprland-setup
    STATE_DIR=$STATE_BASE/fedora-hyprland-setup
    PROFILE=$PROJECT_HOME/profile
    local path
    for path in "$HOME" "$CONFIG_BASE" "$DATA_BASE" "$STATE_BASE"; do
        [[ $path == /* && $path != *$'\n'* && $path != *$'\r'* ]] || die 'HOME and XDG paths must be absolute and contain no newlines.'
    done
    [[ $PROJECT_HOME != *=* && $PROJECT_HOME != *%* ]] || die "XDG_DATA_HOME cannot contain '=' or '%': desktop launchers cannot reliably represent that executable path."
    # Check before opening a lock or writing anything through these paths.
    for path in "$PROJECT_HOME" "$STATE_DIR" "$STATE_DIR/operation.lock" "$STATE_DIR/manifest.json" "$STATE_DIR/backups" \
        "$STATE_DIR/packages-observed.txt" "$STATE_DIR/repositories-added.txt"; do
        [[ ! -L $path ]] || die "Refusing symlinked installation state: $path"
    done
    export CONFIG_BASE DATA_BASE STATE_BASE PROJECT_HOME STATE_DIR PROFILE
}
on_error() {
    local status=$?
    printf '[error] Command failed near line %s (status %s).\n' "${BASH_LINENO[0]}" "$status" >&2
    printf 'No packages are removed automatically. Rerun after fixing the error; uninstall.sh can restore recorded configuration changes.\n' >&2
    exit "$status"
}
