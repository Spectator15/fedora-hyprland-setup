#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/fedora.sh
source "$ROOT/lib/fedora.sh"
# shellcheck source=../lib/repositories.sh
source "$ROOT/lib/repositories.sh"
# shellcheck source=../lib/packages.sh
source "$ROOT/lib/packages.sh"
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
for number in 43 44; do
    printf 'ID="fedora"\nVERSION_ID="%s"\n' "$number" > "$test_dir/os-release"
    [[ $(fedora_version "$test_dir/os-release") == "$number" ]]
done
printf "ID='fedora'\r\nVERSION_ID='44'\r\n" > "$test_dir/os-release"
[[ $(fedora_version "$test_dir/os-release") == 44 ]]
printf 'ID=fedora\nVERSION_ID=44' > "$test_dir/os-release"
[[ $(fedora_version "$test_dir/os-release") == 44 ]]
# shellcheck disable=SC2016
for value in rawhide '$(touch NEVER_EXECUTED)' ''; do
    printf 'ID=fedora\nVERSION_ID=%s\n' "$value" > "$test_dir/os-release"
    if fedora_version "$test_dir/os-release"; then die 'Invalid version accepted'; fi
done
printf 'ID=ubuntu\nVERSION_ID=44\n' > "$test_dir/os-release"
if fedora_version "$test_dir/os-release"; then die 'Non-Fedora accepted'; fi
version_supported 0.56.2
if version_supported 0.55.3; then exit 1; fi
if version_supported 0.57.0; then exit 1; fi
version_at_least 1.6.1 1.6.0
if version_at_least 1.5.0 1.6.0; then exit 1; fi
printf 'PASS: Fedora parsing and compatibility boundaries\n'

STATE_DIR=$test_dir FEDORA_VERSION=44 DRY_RUN=0 WITH_EXTRAS=1 WITH_RECORDING=1
export STATE_DIR
calls=$test_dir/calls
# Mock only external effects; run production package selection logic twice.
sudo() { printf '%s\n' "$*" >> "$calls"; }
# sudo is also mocked above; there is no subprocess boundary in these tests.
# shellcheck disable=SC2032
dnf() {
    case "$*" in
        *'repolist --enabled'*) printf '%s\n' "$HYPR_REPO" "$DMS_REPO" "$DANK_REPO" ;;
        *) return 95 ;;
    esac
}
rpm() {
    case "$*" in
        *"--qf"*hyprland) printf 0.56.2 ;;
        *"--qf"*dms) printf 1.6.1 ;;
        *"--qf"*quickshell) printf 0.3.1 ;;
        *"--qf"*matugen) printf 4.2.0 ;;
        *) return 0 ;;
    esac
}
package_version() {
    case "$1 $*" in
        *copr*hyprland*|hyprland*copr*) echo 0.56.2 ;;
        dms*copr*) echo 1.6.1 ;;
        quickshell*copr*) echo 0.3.1 ;;
        matugen*copr*) echo 4.2.0 ;;
        *) return 0 ;;
    esac
}
install_packages
install_packages
[[ ! -e $calls && ! -e $STATE_DIR/repositories-added.txt ]]
printf 'PASS: current packages and enabled COPRs are not reinstalled/re-enabled\n'
(
    rpm() { return 1; }
    dnf() {
        case "$*" in *repolist*) printf '%s\n' "$HYPR_REPO" "$DMS_REPO" "$DANK_REPO" ;; *) return 0 ;; esac
    }
    if (install_packages) > "$test_dir/missing-package" 2>&1; then die 'Missing package accepted'; fi
    grep -q 'Required Fedora package' "$test_dir/missing-package"
    [[ ! -e $calls ]]
)
printf 'PASS: missing package refuses config deployment\n'
(
    dnf() { return 0; }
    sudo() { return 9; }
    if (ensure_copr "$HYPR_COPR" "$HYPR_REPO") > "$test_dir/missing-repo" 2>&1; then die 'Missing COPR accepted'; fi
    grep -q 'Cannot enable' "$test_dir/missing-repo"
    [[ ! -e $STATE_DIR/repositories-added.txt ]]
)
printf 'PASS: missing repository records no false success\n'
(
    fedora_version() { echo 42; }
    if (validate_fedora) > "$test_dir/unsupported" 2>&1; then die 'Unsupported Fedora accepted'; fi
    grep -q 'outside the researched' "$test_dir/unsupported"
)
printf 'PASS: unsupported Fedora stops before Fedora-specific actions\n'
package_version() { return 1; }
if (install_packages) >/dev/null 2>&1; then die 'Network failure was incorrectly accepted'; fi
[[ ! -e $calls ]]
printf 'PASS: unavailable metadata fails before package changes\n'
(
    XDG_STATE_HOME=$test_dir/unsafe
    mkdir -p "$XDG_STATE_HOME"
    ln -s "$test_dir" "$XDG_STATE_HOME/fedora-hyprland-setup"
    if (project_paths) >/dev/null 2>&1; then die 'Symlinked state accepted'; fi
)
printf 'PASS: unsafe state rejected before lock mutation\n'
(
    for XDG_DATA_HOME in "$test_dir/unsupported=path" "$test_dir/unsupported%path"; do
        if (project_paths) >/dev/null 2>&1; then die 'Unrepresentable desktop executable path accepted'; fi
        [[ ! -e $XDG_DATA_HOME ]]
    done
)
printf 'PASS: unsupported desktop executable path rejected before mutation\n'
