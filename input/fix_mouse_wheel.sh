#!/bin/bash

# Mouse wheel fix - USB HID driver reload
# This is the ONLY method that works for this specific mouse wheel issue

echo "=== USB HID Driver Reload ==="
echo "Reloading USB HID drivers to fix mouse wheel..."
echo

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script requires sudo privileges to reload kernel modules."
    echo "Please run: sudo $0"
    exit 1
fi

echo "🔄 Removing usbhid module..."
modprobe -r usbhid
if [ $? -eq 0 ]; then
    echo "✓ usbhid module removed"
else
    echo "❌ Failed to remove usbhid module"
    exit 1
fi

echo "⏳ Waiting 2 seconds..."
sleep 2

echo "🔄 Loading usbhid module..."
modprobe usbhid
if [ $? -eq 0 ]; then
    echo "✓ usbhid module loaded"
else
    echo "❌ Failed to load usbhid module"
    exit 1
fi

echo
echo "🎉 USB HID driver reload complete!"
echo "Your mouse wheel should now be working properly."
echo
echo "💡 Tip: You can also run this one-liner:"
echo "sudo modprobe -r usbhid && sleep 2 && sudo modprobe usbhid"
