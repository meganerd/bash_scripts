#!/usr/bin/env bash
#
# bigme-recon — ADB-level state dump of a Bigme (or any MTK) Android device
# before attempting an unlock / GSI flash. Safe and read-only.
#
# Usage:
#   bigme-recon                     # print to stdout
#   bigme-recon <dir>               # save individual artifacts into <dir>
#
# Target device:
#   Uses $ADB_DEVICE if set; otherwise picks the first `adb devices` entry.
#   Override inline with: ADB_DEVICE=192.168.78.36:40045 bigme-recon out/

set -euo pipefail

adb_bin="${ADB:-adb}"
command -v "$adb_bin" >/dev/null 2>&1 || {
  if [[ -x "$HOME/Android/Sdk/platform-tools/adb" ]]; then
    adb_bin="$HOME/Android/Sdk/platform-tools/adb"
  else
    echo "error: adb not found" >&2
    exit 1
  fi
}

target=()
if [[ -z "${ADB_DEVICE:-}" ]] && command -v bigme-connect >/dev/null 2>&1; then
  ADB_DEVICE="$(bigme-connect --quiet 2>/dev/null || true)"
fi
[[ -n "${ADB_DEVICE:-}" ]] && target=(-s "$ADB_DEVICE")

out_dir="${1:-}"
if [[ -n "$out_dir" ]]; then
  mkdir -p -- "$out_dir"
fi

run() {
  local label="$1" cmd="$2" outfile=""
  [[ -n "$out_dir" ]] && outfile="$out_dir/${label}.txt"
  local header="==== $label ===="
  if [[ -n "$outfile" ]]; then
    { echo "$header"; "$adb_bin" "${target[@]}" shell "$cmd" 2>&1; } | tee "$outfile"
  else
    echo "$header"
    "$adb_bin" "${target[@]}" shell "$cmd" 2>&1
  fi
  echo
}

run "adb_devices" "true"
"$adb_bin" "${target[@]}" get-state >/dev/null 2>&1 || {
  echo "error: no ADB device reachable — set ADB_DEVICE or run \`adb connect\` first" >&2
  exit 1
}

run "build_fingerprint" 'getprop | grep -E "ro\.(product|build|boot|hardware|board|mediatek)" | sort'
run "bootloader_state"  'for p in ro.boot.verifiedbootstate ro.boot.veritymode ro.boot.vbmeta.device_state ro.boot.vbmeta.hash_alg ro.boot.vbmeta.avb_version sys.oem_unlock_allowed ro.oem_unlock_supported ro.boot.flash.locked ro.bootloader ro.boot.slot_suffix; do echo "$p=$(getprop $p)"; done'
run "treble_gsi_caps"   'for p in ro.treble.enabled ro.vndk.version ro.product.first_api_level ro.build.version.sdk ro.build.version.release ro.build.version.security_patch ro.build.fingerprint; do echo "$p=$(getprop $p)"; done'
run "partitions"        'ls -la /dev/block/by-name/ 2>/dev/null'
run "super_layout"      'lpdump 2>/dev/null || echo "lpdump not available"'
run "display"           'wm size; wm density; dumpsys display | grep -E "mBase|PhysicalSize|DensityDpi" | head -10'
run "dev_settings"      'for k in development_settings_enabled adb_enabled oem_unlock_enabled; do v=$(settings get global $k 2>/dev/null); echo "$k=$v"; done'
run "selinux_root"      'getenforce; id'
run "cpu_mem"           'uname -a; cat /proc/cpuinfo | grep -m1 "model name"; free -h 2>/dev/null || cat /proc/meminfo | head -3'
run "installed_apps"    'pm list packages -f -3 | sort'

echo "== recon complete =="
if [[ -n "$out_dir" ]]; then
  echo "artifacts in: $out_dir"
fi
