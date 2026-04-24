#!/usr/bin/env bash
#
# bigme-dpi — set or reset display density on an ADB-connected Android
# device. Works on any device with ADB; convenience wrapper around
# `wm density`.
#
# Usage:
#   bigme-dpi                       # show current density
#   bigme-dpi <value>               # set density (e.g. 240, 280, 300, 360)
#   bigme-dpi reset                 # revert to hardware default
#
# Common values on a 10.3" 1860x2480 e-ink panel:
#   240 — compact, fits more content (good for reference material)
#   280 — slight shrink from stock
#   300 — Bigme stock
#   360 — noticeably larger, easier on the eyes for reading
#   420 — big, accessibility-sized
#
# Target device:
#   Uses $ADB_DEVICE if set; otherwise picks the first `adb devices` entry.
#   Override inline with: ADB_DEVICE=192.168.78.36:40045 bigme-dpi 280

set -euo pipefail

adb_bin="${ADB:-adb}"
command -v "$adb_bin" >/dev/null 2>&1 || {
  # Fall back to Android SDK platform-tools if adb isn't on PATH.
  if [[ -x "$HOME/Android/Sdk/platform-tools/adb" ]]; then
    adb_bin="$HOME/Android/Sdk/platform-tools/adb"
  else
    echo "error: adb not found (set \$ADB or install platform-tools)" >&2
    exit 1
  fi
}

target=()
if [[ -z "${ADB_DEVICE:-}" ]] && command -v bigme-connect >/dev/null 2>&1; then
  ADB_DEVICE="$(bigme-connect --quiet 2>/dev/null || true)"
fi
if [[ -n "${ADB_DEVICE:-}" ]]; then
  target=(-s "$ADB_DEVICE")
fi

case "${1:-}" in
  ""|show|status)
    "$adb_bin" "${target[@]}" shell 'wm size; wm density'
    ;;
  reset)
    "$adb_bin" "${target[@]}" shell 'wm density reset'
    echo "density reset to hardware default"
    "$adb_bin" "${target[@]}" shell 'wm density'
    ;;
  [0-9]*)
    "$adb_bin" "${target[@]}" shell "wm density $1"
    "$adb_bin" "${target[@]}" shell 'wm density'
    ;;
  -h|--help)
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "usage: bigme-dpi [<value>|reset|show]" >&2
    exit 1
    ;;
esac
