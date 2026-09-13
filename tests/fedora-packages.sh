#!/usr/bin/env bash
# Integration probe for a disposable Fedora container/filesystem ONLY.
set -Eeuo pipefail
[[ ${FH_DISPOSABLE_TEST:-} == 1 && $EUID == 0 ]] || { echo 'Set FH_DISPOSABLE_TEST=1 only inside a disposable Fedora test container.' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/fedora.sh
source "$ROOT/lib/fedora.sh"
# shellcheck source=../lib/repositories.sh
source "$ROOT/lib/repositories.sh"
# shellcheck source=../lib/packages.sh
source "$ROOT/lib/packages.sh"
FEDORA_VERSION=$(fedora_version)
DRY_RUN=0 WITH_EXTRAS=1 WITH_RECORDING=1
STATE_DIR=/var/tmp/fh-package-test
mkdir -p "$STATE_DIR"
# Only the disposable container automatically accepts package transactions.
sudo() { "$1" -y "${@:2}"; }
install_packages
printf 'PASS: all selected packages installed/resolved in Fedora %s\n' "$FEDORA_VERSION"
Hyprland --version
rpm -q hyprland dms dms-cli quickshell matugen xdg-desktop-portal-hyprland
id fh-test >/dev/null 2>&1 || useradd --create-home fh-test
runuser -u fh-test -- bash "$ROOT/tests/fedora-config.sh"
