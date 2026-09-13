#!/usr/bin/env bash
# Shared constants consumed by lib/packages.sh.
# shellcheck disable=SC2034
HYPR_COPR=lionheartp/Hyprland
HYPR_REPO=copr:copr.fedorainfracloud.org:lionheartp:Hyprland
DMS_COPR=avengemedia/dms
DMS_REPO=copr:copr.fedorainfracloud.org:avengemedia:dms
DANK_COPR=avengemedia/danklinux
DANK_REPO=copr:copr.fedorainfracloud.org:avengemedia:danklinux
OFFICIAL=(--disable-repo='*' --enable-repo=fedora --enable-repo=updates)
ensure_copr() {
    local project=$1 repository=$2 enabled
    enabled=$(dnf -q repolist --enabled) || die 'Cannot enumerate enabled repositories.'
    if grep -Fq "$repository" <<< "$enabled"; then return; fi
    if ! dnf copr --help >/dev/null 2>&1; then
        sudo dnf "${OFFICIAL[@]}" install dnf5-plugins || die 'DNF COPR support could not be installed.'
    fi
    log "Enabling upstream-recommended repository $project (see docs/upstream.md)."
    sudo dnf copr enable "$project" || die "Cannot enable $project for Fedora $FEDORA_VERSION. No user config deployed."
    if ! grep -Fxq "$project" "$STATE_DIR/repositories-added.txt" 2>/dev/null; then
        printf '%s\n' "$project" >> "$STATE_DIR/repositories-added.txt"
    fi
}
