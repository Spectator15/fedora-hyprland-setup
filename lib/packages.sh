#!/usr/bin/env bash
# Package queries use only the explicitly selected repositories.
package_version() {
    local package=$1; shift
    dnf -q "$@" repoquery --available --latest-limit=1 --arch="$(rpm --eval '%{_arch}')",noarch \
        --queryformat $'%{version}\n' "$package" | sort -Vu | tail -n 1
}
install_packages() {
    local candidate installed='' package available
    local -a packages=(kitty dolphin qt6-qtbase-gui qt5-qtbase-gui adw-gtk3-theme
        breeze-icon-theme breeze-cursor-theme google-noto-sans-fonts
        google-noto-sans-mono-fonts wl-clipboard xorg-x11-server-Xwayland
        xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde
        pipewire wireplumber upower python3 lua dbus-tools dbus-daemon util-linux)
    (( WITH_EXTRAS )) && packages+=(tesseract tesseract-langpack-eng zbar btop)
    (( WITH_RECORDING )) && packages+=(obs-studio)
    if (( DRY_RUN )); then
        log 'Would query Fedora for Hyprland 0.56.x and DMS 1.6.x, with Quickshell >=0.3.'
        log 'If unavailable: use lionheartp/Hyprland, avengemedia/dms, and avengemedia/danklinux (DMS runtime/dgop).'
        log 'Would check packages and show DNF transactions. Dry-run does not refresh metadata, use sudo, or enable repositories.'
        run sudo dnf install --setopt=install_weak_deps=False "${packages[@]}" dms quickshell matugen hyprland xdg-desktop-portal-hyprland
        return
    fi
    local -a repos=("${OFFICIAL[@]}")
    candidate=$(package_version hyprland "${OFFICIAL[@]}") || die 'Cannot query Fedora package metadata.'
    if ! version_supported "$candidate"; then
        ensure_copr "$HYPR_COPR" "$HYPR_REPO"
        repos+=(--enable-repo="$HYPR_REPO")
    fi
    candidate=$(package_version dms "${OFFICIAL[@]}") || die 'Cannot query DMS package availability.'
    if ! dms_supported "$candidate"; then
        ensure_copr "$DMS_COPR" "$DMS_REPO"
        repos+=(--enable-repo="$DMS_REPO")
        # Stable DMS requires dgop from the companion repository.
        ensure_copr "$DANK_COPR" "$DANK_REPO"
        repos+=(--enable-repo="$DANK_REPO")
    else
        candidate=$(package_version quickshell "${OFFICIAL[@]}") || die 'Cannot query Quickshell package metadata.'
        if ! version_at_least "$candidate" 0.3.0; then
            ensure_copr "$DANK_COPR" "$DANK_REPO"
            repos+=(--enable-repo="$DANK_REPO")
        fi
    fi
    candidate=$(package_version matugen "${OFFICIAL[@]}") || die 'Cannot query Matugen package metadata.'
    if ! version_at_least "$candidate" 3.1.0; then
        ensure_copr "$DANK_COPR" "$DANK_REPO"
        repos+=(--enable-repo="$DANK_REPO")
    else
        packages+=(matugen) # install from Fedora first, even if a COPR has newer
    fi
    candidate=$(package_version hyprland "${repos[@]}") || die 'Hyprland repository metadata unavailable.'
    version_supported "$candidate" || die "Available Hyprland '$candidate' is incompatible; expected 0.56.x. No user config deployed."
    log "Hyprland candidate: $candidate"
    candidate=$(package_version dms "${repos[@]}") || die 'Cannot query DMS repository metadata.'
    dms_supported "$candidate" || die 'DMS 1.6.x is unavailable. A new minor release needs an isolation/API review before use.'
    candidate=$(package_version quickshell "${repos[@]}") || die 'Cannot query Quickshell repository metadata.'
    version_at_least "$candidate" 0.3.0 || die 'Quickshell >=0.3 is unavailable in the verified sources.'
    candidate=$(package_version matugen "${repos[@]}") || die 'Cannot query Matugen repository metadata.'
    version_at_least "$candidate" 3.1.0 || die 'Matugen >=3.1 is unavailable in the verified sources.'
    for package in "${packages[@]}"; do
        rpm -q "$package" >/dev/null 2>&1 && continue
        available=$(dnf -q "${OFFICIAL[@]}" repoquery --available --queryformat $'%{name}\n' "$package") || die "Cannot query $package."
        grep -Fxq "$package" <<< "$available" || die "Required Fedora package '$package' is unavailable. No unverified repository fallback is used."
    done
    local -a missing=() protect=(--setopt=install_weak_deps=False
        '--setopt=protected_packages=dnf,dnf5,glob:/etc/dnf/protected.d/*.conf,plasma-workspace,plasma-desktop,sddm')
    for package in "${packages[@]}"; do rpm -q "$package" >/dev/null 2>&1 || missing+=("$package"); done
    if ((${#missing[@]})); then
        sudo dnf "${OFFICIAL[@]}" install "${protect[@]}" "${missing[@]}" || die 'Fedora package transaction failed. No user config deployed.'
    fi
    missing=()
    for package in hyprland dms quickshell matugen xdg-desktop-portal-hyprland; do
        installed=$(rpm -q --qf '%{VERSION}' "$package" 2>/dev/null || true)
        case "$package" in
            hyprland) version_supported "$installed" && continue ;;
            dms) dms_supported "$installed" && continue ;;
            quickshell) version_at_least "$installed" 0.3.0 && continue ;;
            matugen) version_at_least "$installed" 3.1.0 && continue ;;
            *) rpm -q "$package" >/dev/null 2>&1 && continue ;;
        esac
        missing+=("$package")
    done
    if ((${#missing[@]})); then
        sudo dnf "${repos[@]}" install "${protect[@]}" "${missing[@]}" ||
            die 'Stack dependencies could not be resolved. Do not use --allowerasing; inspect repository versions while retaining Plasma.'
    fi
    version_supported "$(rpm -q --qf '%{VERSION}' hyprland)" || die 'Installed Hyprland is outside the supported Lua API range.'
    dms_supported "$(rpm -q --qf '%{VERSION}' dms)" || die 'Installed DMS is outside the reviewed 1.6.x range.'
    rpm -q "${packages[@]}" hyprland dms quickshell matugen xdg-desktop-portal-hyprland > "$STATE_DIR/packages-observed.txt"
}
