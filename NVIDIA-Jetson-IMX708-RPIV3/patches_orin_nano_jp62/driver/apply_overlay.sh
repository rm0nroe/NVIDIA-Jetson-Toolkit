#!/bin/bash
# Apply IMX708 device tree overlay to boot DTB
# This script merges the overlay directly since JetPack 6.2 doesn't process OVERLAYS directive
#
# NOTE: JetPack 6.2 may load DTB from /boot/ OR /boot/dtb/ - we update BOTH

set -e

DTB_NAME="kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb"
OVERLAY="/boot/tegra234-camera-imx708-orin-nano.dtbo"

# Both possible DTB locations
DTB_LOCATIONS=(
    "/boot/${DTB_NAME}"
    "/boot/dtb/${DTB_NAME}"
)

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

# Process each DTB location
for DTB_PATH in "${DTB_LOCATIONS[@]}"; do
    if [ ! -f "$DTB_PATH" ]; then
        echo "Skipping $DTB_PATH (not found)"
        continue
    fi

    DTB_BACKUP="${DTB_PATH}.backup"

    echo "Processing: $DTB_PATH"

    # Create backup if it doesn't exist
    if [ ! -f "$DTB_BACKUP" ]; then
        echo "  Creating backup..."
        cp "$DTB_PATH" "$DTB_BACKUP"
        echo "  Backup: $DTB_BACKUP"
    else
        echo "  Backup exists: $DTB_BACKUP"
    fi

    # Merge overlay into DTB
    echo "  Merging overlay..."
    if fdtoverlay -i "$DTB_BACKUP" -o "$DTB_PATH" "$OVERLAY"; then
        echo "  SUCCESS: Overlay merged"

        # Verify merge
        if command -v dtc &> /dev/null; then
            if dtc -I dtb -O dts "$DTB_PATH" 2>/dev/null | grep -q "imx708"; then
                echo "  VERIFIED: imx708 node found"
            else
                echo "  WARNING: imx708 not found in verification"
            fi
        fi
    else
        echo "  ERROR: fdtoverlay failed"
        echo "  Restoring backup..."
        cp "$DTB_BACKUP" "$DTB_PATH"
    fi
    echo ""
done

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
