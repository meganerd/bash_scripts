#!/usr/bin/env bash
#
# bigme-font — set or reset global font scale on an ADB-connected Android
# device. Works on any device; convenience wrapper around
# `settings put system font_scale`.
#
# Usage:
#   bigme-font                        # show current font scale
#   bigme-font <value>                # set scale (e.g. 0.85, 1.0, 1.15, 1.3, 1.5)
#   bigme-font reset                  # back to 1.0
#   bigme-font apply <package>        # force-stop app so it re-reads scale
#
# Common values:
#   0.85 — Android "Small"
#   1.0  — default
#   1.15 — Android "Large"
#   1.30 — Android "Largest"
#   1.5  — larger than Settings UI permits (still honored by framework)
#   2.0  — accessibility-sized, risks broken layouts
#
# Target device:
#   Uses $ADB_DEVICE if set; otherwise picks the first `adb devices` entry.
#   Override inline with: ADB_DEVICE=192.168.78.36:43725 bigme-font 1.15
#
# Note: font_scale is separate from display density (see bigme-dpi).
#   - density scales layout (icons, padding, row heights)
#   - font_scale scales only text rendered at `sp` units
#   Apps that use fixed `dp`/px for text (custom drawing, e-ink note apps)
#   may ignore both.

set -euo pipefail

adb_bin="${ADB:-adb}"
command -v "$adb_bin" >/dev/null 2>&1 || {
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
[[ -n "${ADB_DEVICE:-}" ]] && target=(-s "$ADB_DEVICE")

show() {
  local v
  v="$("$adb_bin" "${target[@]}" shell 'settings get system font_scale' | tr -d '\r')"
  [[ -z "$v" || "$v" == "null" ]] && v="1.0 (unset, using default)"
  echo "font_scale=$v"
}

set_scale() {
  local val="$1"
  "$adb_bin" "${target[@]}" shell "settings put system font_scale $val"
  show
}

case "${1:-}" in
  ""|show|status)
    show
    ;;
  reset)
    set_scale "1.0"
    ;;
  apply)
    pkg="${2:-}"
    [[ -n "$pkg" ]] || { echo "usage: bigme-font apply <package>" >&2; exit 1; }
    "$adb_bin" "${target[@]}" shell "am force-stop $pkg"
    echo "force-stopped $pkg — open it again to pick up the new font scale"
    ;;
  -h|--help)
    sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  [0-9]*\.[0-9]*|[0-9]*)
    set_scale "$1"
    ;;
  *)
    echo "usage: bigme-font [<value>|reset|show|apply <pkg>]" >&2
    exit 1
    ;;
esac
