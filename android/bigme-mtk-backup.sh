#!/usr/bin/env bash
#
# bigme-mtk-backup — full partition backup of an MT6765 (or other MTK) device
# via mtkclient's BootROM exploit. Device must be OFF and put into BROM mode
# by holding both volume keys while plugging in USB.
#
# Usage:
#   bigme-mtk-backup <output-dir>
#
# Prerequisites:
#   - mtkclient cloned at $MTKCLIENT_DIR (default: ~/src/mtkclient)
#   - mtkclient Python deps installed (pip install -r requirements.txt)
#   - udev rules installed so non-root user can talk to the device:
#       sudo cp ~/src/mtkclient/mtkclient/Setup/Linux/*.rules /etc/udev/rules.d/
#       sudo udevadm control --reload && sudo udevadm trigger
#   - Device physically connected over USB, OFF, in BROM mode
#     (Bigme InkNote Color+: power off, hold Vol-Up + Vol-Down, plug USB)
#   - dmesg should show idVendor=0e8d idProduct=0003 (BROM) or 2000 (Preloader)
#
# What it does (read-only — does not modify the device):
#   1. Reads partition table via BROM exploit.
#   2. Dumps every partition to <output-dir>/<partition>.bin
#   3. Writes SHA-256 sums for each dump.
#   4. Emits a manifest.json with partition sizes and fingerprints.
#
# Recovery note:
#   If unlock or flash later bricks the device, the same BROM exploit works
#   in reverse: `mtk w <partition> <backup>.bin` restores from these dumps.
#   Keep this backup dir — it is your only route back to stock.

set -euo pipefail

MTKCLIENT_DIR="${MTKCLIENT_DIR:-$HOME/src/mtkclient}"

die() { echo "error: $*" >&2; exit 1; }

out_dir="${1:-}"
[[ -n "$out_dir" ]] || { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

[[ -d "$MTKCLIENT_DIR" ]] || die "mtkclient not found at $MTKCLIENT_DIR (set \$MTKCLIENT_DIR)"
[[ -f "$MTKCLIENT_DIR/mtk.py" ]] || die "$MTKCLIENT_DIR/mtk.py missing"

# Verify mtkclient deps are importable before touching the device.
if ! python3 -c 'import mtkclient' 2>/dev/null \
  && ! python3 -c 'import sys; sys.path.insert(0,"'"$MTKCLIENT_DIR"'"); import mtkclient' 2>/dev/null; then
  die "mtkclient Python module not importable — run: (cd $MTKCLIENT_DIR && pip install --user -r requirements.txt)"
fi

mkdir -p -- "$out_dir"
cd -- "$out_dir"

echo "[1/3] reading partition table"
python3 "$MTKCLIENT_DIR/mtk.py" printgpt | tee gpt.txt

echo
echo "[2/3] dumping all partitions (this will take several minutes)"
python3 "$MTKCLIENT_DIR/mtk.py" rl "$out_dir" --skip userdata

echo
echo "[3/3] hashing dumps + writing manifest"
{
  echo "{"
  echo "  \"generated_at\": \"$(date -Iseconds)\","
  echo "  \"mtkclient_head\": \"$(cd "$MTKCLIENT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo unknown)\","
  echo "  \"partitions\": {"
  first=1
  for f in *.bin; do
    [[ -f "$f" ]] || continue
    size=$(stat -c %s -- "$f")
    hash=$(sha256sum -- "$f" | awk '{print $1}')
    [[ $first -eq 1 ]] && first=0 || echo ","
    printf '    "%s": {"size": %d, "sha256": "%s"}' "${f%.bin}" "$size" "$hash"
  done
  echo
  echo "  }"
  echo "}"
} > manifest.json

echo
echo "done."
echo "  backup dir:  $(pwd)"
echo "  manifest:    $(pwd)/manifest.json"
echo "  restore one: python3 $MTKCLIENT_DIR/mtk.py w <partition> <partition>.bin"
echo "  restore all: python3 $MTKCLIENT_DIR/mtk.py wl $(pwd)"
