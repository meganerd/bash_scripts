#!/bin/bash
# PiKVM Mouse Fix Script
# Usage: ./pikvm_mouse_fix.sh [pikvm-ip] [username] [password]

PIKVM_IP=${1:-"pikvm.local"}
USERNAME=${2:-"admin"}
PASSWORD=${3:-"admin"}

echo "=== PiKVM Mouse Fix Tool ==="
echo "Target: $PIKVM_IP"
echo

echo "1. Testing connectivity..."
if ping -c 1 "$PIKVM_IP" > /dev/null 2>&1; then
    echo "✓ PiKVM reachable"
else
    echo "✗ PiKVM not reachable at $PIKVM_IP"
    echo "Try: nmap -sn 192.168.1.0/24 | grep pikvm"
    exit 1
fi

echo
echo "2. Trying API reset methods..."

# Method 1: HID Reset via API
echo "Attempting HID reset..."
curl -s -u "$USERNAME:$PASSWORD" -X POST "http://$PIKVM_IP/api/hid/reset" || echo "API method failed"

sleep 2

# Method 2: Mass storage reset
echo "Attempting mass storage reset..."
curl -s -u "$USERNAME:$PASSWORD" -X POST "http://$PIKVM_IP/api/msd/reset" || echo "MSD reset failed"

echo
echo "3. SSH-based fixes (if API fails)..."
echo "Run these commands via SSH to $PIKVM_IP:"
echo "  systemctl restart kvmd"
echo "  kvmd-otgmsd --reset"
echo "  echo '' > /sys/kernel/config/usb_gadget/kvmd/UDC"
echo "  echo ci_hdrc.0 > /sys/kernel/config/usb_gadget/kvmd/UDC"

echo
echo "4. If problem persists, create this config file on PiKVM:"
echo "   /etc/kvmd/override.yaml"
echo "   ---"
echo "   hid:"
echo "     mouse:"
echo "       absolute: false"
echo "       horizontal_wheel: false"
echo "   Then: systemctl restart kvmd"
