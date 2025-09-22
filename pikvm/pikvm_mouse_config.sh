#!/bin/bash
# PiKVM Mouse Configuration Script for macOS compatibility
# Run this ON the PiKVM device

echo "=== Configuring PiKVM for macOS Mouse Compatibility ==="

# Backup existing config
cp /etc/kvmd/override.yaml /etc/kvmd/override.yaml.backup 2>/dev/null || echo "No existing override.yaml"

# Create mouse-friendly configuration
cat > /etc/kvmd/override.yaml << 'YAML'
# PiKVM Configuration for macOS Mouse Compatibility

hid:
    mouse:
        absolute: false          # Use relative mouse mode for better macOS compatibility
        horizontal_wheel: false  # Disable horizontal wheel to prevent conflicts
        
kvmd:
    hid:
        mouse_alt: false        # Disable alternative mouse handling
        
# Optional: Reduce USB polling rate if issues persist
usb:
    gadget:
        manufacturer: "PiKVM"
        product: "Composite KVM Device"
        
# GPIO settings for USB reset capability
gpio:
    drivers:
        __gpio_usb_reset__:
            type: gpio
            pin: 4
            mode: output
            initial: true
    scheme:
        usb_reset:
            driver: __gpio_usb_reset__
            pin: 4
            mode: output
YAML

echo "Configuration written to /etc/kvmd/override.yaml"
echo "Restarting kvmd service..."
systemctl restart kvmd

echo "Done! The mouse should now work better with macOS."
echo "If issues persist, try switching to 'Relative Mouse Mode' in the web interface."
