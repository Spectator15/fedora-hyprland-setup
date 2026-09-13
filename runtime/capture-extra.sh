#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${FH_SESSION:-} == 1 ]] || { echo 'Run this from the project Hyprland session.' >&2; exit 1; }
case "${1:-}" in
    ocr) command -v tesseract >/dev/null || { echo 'Install with --with-extras first.' >&2; exit 1; } ;;
    qr) command -v zbarimg >/dev/null || { echo 'Install with --with-extras first.' >&2; exit 1; } ;;
    *) echo 'Usage: capture-extra.sh ocr|qr' >&2; exit 1 ;;
esac
capture=$(mktemp --suffix=.png)
trap 'rm -f -- "$capture"' EXIT
# Cancel/failure never replaces the clipboard with an empty capture.
dms screenshot --no-file --no-clipboard --no-notify --stdout > "$capture"
[[ -s $capture ]] || exit 0
if [[ $1 == ocr ]]; then
    result=$(tesseract "$capture" stdout 2>/dev/null)
else
    result=$(zbarimg --quiet --raw "$capture")
fi
[[ -n $result ]] || exit 0
printf '%s' "$result" | wl-copy --type text/plain
if command -v notify-send >/dev/null; then notify-send 'Screen capture' 'Recognised text copied to the clipboard'; fi
