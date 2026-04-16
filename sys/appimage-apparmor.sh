#!/bin/bash
#
# appimage-apparmor.sh - Create an AppArmor profile to allow user namespaces for an AppImage
#
# On Ubuntu 24.04+, AppArmor restricts unprivileged user namespaces by default.
# Electron/Chromium AppImages need userns for sandboxing and will crash without it.
# This script creates a permissive AppArmor profile that grants userns to a given AppImage.
#
# Usage: appimage-apparmor.sh <path-to-appimage>

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path-to-appimage>"
    exit 1
fi

APPIMAGE_PATH="$(realpath "$1")"

if [[ ! -f "$APPIMAGE_PATH" ]]; then
    echo "Error: '$APPIMAGE_PATH' does not exist or is not a file."
    exit 1
fi

if [[ ! -x "$APPIMAGE_PATH" ]]; then
    echo "Error: '$APPIMAGE_PATH' is not executable."
    exit 1
fi

# Derive a profile name from the filename (lowercase, alphanumeric + hyphens)
BASENAME="$(basename "$APPIMAGE_PATH")"
PROFILE_NAME="$(echo "$BASENAME" | sed 's/\.appimage$//i' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')"
PROFILE_PATH="/etc/apparmor.d/${PROFILE_NAME}"

if [[ -f "$PROFILE_PATH" ]]; then
    echo "Profile already exists at $PROFILE_PATH:"
    cat "$PROFILE_PATH"
    echo ""
    read -rp "Overwrite? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "Creating AppArmor profile:"
echo "  AppImage:  $APPIMAGE_PATH"
echo "  Profile:   $PROFILE_PATH"
echo "  Name:      $PROFILE_NAME"
echo ""

sudo tee "$PROFILE_PATH" > /dev/null <<EOF
abi <abi/4.0>,
include <tunables/global>

profile ${PROFILE_NAME} ${APPIMAGE_PATH} flags=(unconfined) {
  userns,
  include if exists <local/${PROFILE_NAME}>
}
EOF

sudo apparmor_parser -r "$PROFILE_PATH"

echo "Done. AppArmor profile '${PROFILE_NAME}' loaded."
echo "You can now run: $APPIMAGE_PATH"
