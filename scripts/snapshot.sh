#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
command -v snapper >/dev/null || { echo 'Snapshot requested, but Snapper is not installed/configured. No snapshot created.' >&2; exit 1; }
[[ $(findmnt -n -o FSTYPE /) == btrfs ]] || { echo 'Snapshot requested, but / is not Btrfs.' >&2; exit 1; }
sudo snapper -c root get-config | grep -Eq '^SUBVOLUME[[:space:]]*\|[[:space:]]*/[[:space:]]*$' || {
    echo 'An existing Snapper configuration named root, covering /, is required. This installer will not create/change a snapshot layout.' >&2
    exit 1
}
sudo snapper -c root create --type single --description 'Before fedora-hyprland-setup install' --print-number
printf 'Snapshot created. A root snapshot may exclude /home; project configuration backups are separate.\n'
