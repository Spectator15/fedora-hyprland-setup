#!/usr/bin/env bash
fedora_version() {
    # Parse os-release as data, never execute it with source/eval.
    local file=${1:-/etc/os-release} key value id='' version=''
    [[ -r $file ]] || return 1
    while IFS='=' read -r key value || [[ -n $key ]]; do
        value=${value%$'\r'}
        value=${value#\"}; value=${value%\"}
        value=${value#\'}; value=${value%\'}
        case "$key" in ID) id=$value ;; VERSION_ID) version=$value ;; esac
    done < "$file"
    [[ $id == fedora && $version =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$version"
}
validate_fedora() {
    FEDORA_VERSION=$(fedora_version /etc/os-release) || die 'This installer supports Fedora KDE, not this operating system.'
    case "$FEDORA_VERSION" in
        43|44) ;;
        *) die "Fedora $FEDORA_VERSION is outside the researched 43/44 range. Review compatibility before adding a release." ;;
    esac
    [[ ! -e /run/ostree-booted ]] || die 'Atomic/Kinoite systems need a different package workflow; this installer supports traditional Fedora KDE.'
    require_command dnf
    require_command rpm
    rpm -q plasma-workspace sddm >/dev/null || die 'An existing Fedora KDE installation with Plasma and SDDM is required.'
    compgen -G '/usr/share/wayland-sessions/plasma*.desktop' >/dev/null || die 'Plasma Wayland session file is missing. Repair Fedora KDE first.'
    log "Fedora $FEDORA_VERSION KDE detected; Plasma and SDDM will be retained."
}
version_supported() {
    # Bound the rapidly changing Lua API. Widen only after reviewing upstream.
    [[ $1 =~ ^0\.56\.[0-9]+$ ]]
}
dms_supported() { [[ $1 =~ ^1\.6\.[0-9]+$ ]]; }
version_at_least() {
    [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+([.^~+-].*)?$ ]] || return 1
    [[ $(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1) == "$2" ]]
}
