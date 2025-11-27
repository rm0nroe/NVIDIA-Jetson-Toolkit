#!/bin/bash
# Apply IMX708 device tree overlay to boot DTB
# This script merges the overlay directly since JetPack 6.2 doesn't process OVERLAYS directive

set -e

DTB_DIR="/boot/dtb"
DTB_NAME="kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb"
DTB_PATH="${DTB_DIR}/${DTB_NAME}"
DTB_BACKUP="${DTB_PATH}.backup"
OVERLAY="/boot/tegra234-camera-imx708-orin-nano.dtbo"

echo "=== IMX708 Device Tree Overlay Application ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run with sudo"
    exit 1
fi

# Check overlay exists
if [ ! -f "$OVERLAY" ]; then
    echo "ERROR: Overlay not found at $OVERLAY"
    echo "Run './build.sh install' first"
    exit 1
fi

# Check DTB exists
if [ ! -f "$DTB_PATH" ]; then
    echo "ERROR: Boot DTB not found at $DTB_PATH"
    echo "Available DTBs:"
    ls -la "$DTB_DIR"/*.dtb 2>/dev/null || echo "  None found"
    exit 1
fi

# Create backup if it doesn't exist
if [ ! -f "$DTB_BACKUP" ]; then
    echo "Creating backup of original DTB..."
    cp "$DTB_PATH" "$DTB_BACKUP"
    echo "  Backup created: $DTB_BACKUP"
else
    echo "Backup already exists: $DTB_BACKUP"
fi

# Merge overlay into DTB
echo ""
echo "Merging overlay into boot DTB..."
fdtoverlay -i "$DTB_BACKUP" -o "$DTB_PATH" "$OVERLAY"

if [ $? -eq 0 ]; then
    echo "  SUCCESS: Overlay merged"
else
    echo "  ERROR: fdtoverlay failed"
    echo "  Restoring backup..."
    cp "$DTB_BACKUP" "$DTB_PATH"
    exit 1
fi

# Verify merge
echo ""
echo "Verifying merge..."
if command -v dtc &> /dev/null; then
    if dtc -I dtb -O dts "$DTB_PATH" 2>/dev/null | grep -q "imx708"; then
        echo "  VERIFIED: imx708 node found in merged DTB"
    else
        echo "  WARNING: imx708 node not found (dtc check)"
    fi
else
    echo "  Skipping dtc verification (dtc not installed)"
fi

echo ""
echo "=== Done ==="
echo ""
echo "Reboot required for changes to take effect."
read -p "Reboot now? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    reboot
else
    echo "Run 'sudo reboot' when ready."
fi
