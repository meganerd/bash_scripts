#!/usr/bin/env bash
#
# bigme-connect — find the Bigme tablet's wireless-ADB port and connect.
#
# Wireless debugging on Android 11 randomizes the ADB port every time
# it's toggled. This script:
#   1. Reuses an existing connection if `adb devices` already has one.
#   2. Scans the configured IP for an open port in the ADB range.
#   3. Falls back to MAC-based discovery across the LAN if the IP moved.
#   4. Prints `IP:PORT` on stdout so callers can do:
#        ADB_DEVICE=$(bigme-connect) bigme-dpi 260
#
# Config file: ~/.config/bigme/device.conf (auto-created template if absent).
#
# Flags:
#   -q, --quiet       suppress progress on stderr
#   -r, --refresh     ignore existing adb connection, rediscover
#   -h, --help        this help

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bigme"
CONFIG_FILE="$CONFIG_DIR/device.conf"

log() { [[ "${QUIET:-0}" == 1 ]] || echo "$*" >&2; }
die() { echo "error: $*" >&2; exit 1; }

# Resolve adb binary.
adb_bin="${ADB:-adb}"
if ! command -v "$adb_bin" >/dev/null 2>&1; then
  if [[ -x "$HOME/Android/Sdk/platform-tools/adb" ]]; then
    adb_bin="$HOME/Android/Sdk/platform-tools/adb"
  else
    die "adb not found (set \$ADB or install platform-tools)"
  fi
fi

QUIET=0
REFRESH=0
while (($#)); do
  case "$1" in
    -q|--quiet)   QUIET=1; shift ;;
    -r|--refresh) REFRESH=1; shift ;;
    -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown option: $1" ;;
  esac
done

# Seed config if absent.
if [[ ! -f "$CONFIG_FILE" ]]; then
  mkdir -p -- "$CONFIG_DIR"
  cat >"$CONFIG_FILE" <<'EOF'
# Bigme tablet device config. Fill in the values from your device.
TABLET_IP=
TABLET_MAC=
ADB_PORT_RANGE=30000-50000
LAN_CIDR=
EOF
  die "config seeded at $CONFIG_FILE — fill in TABLET_IP and re-run"
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"
: "${ADB_PORT_RANGE:=30000-50000}"
[[ -n "${TABLET_IP:-}" ]] || die "TABLET_IP not set in $CONFIG_FILE"

# --- Step 1: reuse existing connection ---------------------------------------
if [[ "$REFRESH" -eq 0 ]]; then
  existing="$("$adb_bin" devices 2>/dev/null | awk -v ip="$TABLET_IP" '$1 ~ ip && $2=="device" {print $1; exit}')"
  if [[ -n "$existing" ]]; then
    log "reusing existing adb device: $existing"
    echo "$existing"
    exit 0
  fi
fi

# --- Step 2: locate tablet's current IP --------------------------------------
target_ip="$TABLET_IP"
if ! ping -c 1 -W 1 "$target_ip" >/dev/null 2>&1; then
  log "$target_ip not answering — searching LAN for MAC $TABLET_MAC"
  if [[ -z "${TABLET_MAC:-}" || -z "${LAN_CIDR:-}" ]]; then
    die "$target_ip unreachable and TABLET_MAC/LAN_CIDR not set — wake the tablet, or update $CONFIG_FILE"
  fi
  # Prime ARP via a quick sweep (doesn't need root).
  nmap -sn -T4 "$LAN_CIDR" >/dev/null 2>&1 || true
  mac_norm="$(echo "$TABLET_MAC" | tr 'A-Z' 'a-z')"
  found_ip="$(ip neigh show 2>/dev/null | awk -v mac="$mac_norm" 'tolower($0) ~ mac {print $1; exit}')"
  if [[ -z "$found_ip" ]]; then
    found_ip="$(arp -n 2>/dev/null | awk -v mac="$mac_norm" 'tolower($0) ~ mac {print $1; exit}')"
  fi
  [[ -n "$found_ip" ]] || die "couldn't find MAC $TABLET_MAC on $LAN_CIDR — wake the tablet and re-enable wireless debugging"
  target_ip="$found_ip"
  log "tablet moved to $target_ip — updating config"
  # Persist the new IP.
  if grep -q '^TABLET_IP=' "$CONFIG_FILE"; then
    sed -i "s|^TABLET_IP=.*|TABLET_IP=$target_ip|" "$CONFIG_FILE"
  fi
fi

# --- Step 3: scan for the ADB port -------------------------------------------
log "scanning $target_ip:$ADB_PORT_RANGE for adb port"
port="$(nmap -p "$ADB_PORT_RANGE" --open -T4 "$target_ip" 2>/dev/null \
  | awk -F/ '/^[0-9]+\/tcp/ {print $1; exit}')"
if [[ -z "$port" ]]; then
  die "no open port in $ADB_PORT_RANGE — tablet is probably asleep or wireless debugging is off (Settings → Developer options → Wireless debugging)"
fi

# --- Step 4: connect & verify -------------------------------------------------
target="$target_ip:$port"
log "connecting to $target"
connect_out="$("$adb_bin" connect "$target" 2>&1)"
log "$connect_out"

# Give adb a moment to settle, then verify the device transitioned to 'device'.
for _ in 1 2 3; do
  state="$("$adb_bin" devices 2>/dev/null | awk -v t="$target" '$1==t {print $2}')"
  [[ "$state" == "device" ]] && break
  sleep 0.5
done
[[ "$state" == "device" ]] || die "adb did not transition to device state (saw: '$state') — is the tablet paired? run: adb pair <ip>:<pair-port>"

echo "$target"
