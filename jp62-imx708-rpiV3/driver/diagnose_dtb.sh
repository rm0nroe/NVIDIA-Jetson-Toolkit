#!/bin/bash
# Diagnose DTB loading and overlay application

echo "=== DTB Diagnostic ==="
echo ""

echo "1. Check current boot DTB still has imx708:"
if sudo dtc -I dtb -O dts /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb 2>/dev/null | grep -q imx708; then
    echo "   ✓ imx708 FOUND in /boot/dtb/*.dtb file"
else
    echo "   ✗ imx708 NOT in /boot/dtb/*.dtb file - overlay was lost!"
fi

echo ""
echo "2. Check what DTB the system actually booted with:"
echo "   /proc/device-tree source:"
sudo cat /proc/device-tree/nvidia,dtsfilename 2>/dev/null || echo "   (not available)"
echo ""

echo "3. Check live device tree for imx708:"
if sudo find /proc/device-tree -name "*imx708*" 2>/dev/null | grep -q imx708; then
    echo "   ✓ imx708 found in live device tree"
    sudo find /proc/device-tree -name "*imx708*" 2>/dev/null
else
    echo "   ✗ imx708 NOT in live device tree"
fi

echo ""
echo "4. List all DTB files in /boot:"
ls -la /boot/dtb/*.dtb* 2>/dev/null
ls -la /boot/*.dtb* 2>/dev/null

echo ""
echo "5. Check extlinux.conf FDT line:"
grep -E "FDT|FDTDIR|OVERLAYS" /boot/extlinux/extlinux.conf 2>/dev/null || echo "   No FDT/OVERLAYS lines"

echo ""
echo "6. Compare backup vs current DTB size:"
if [ -f /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb.backup ]; then
    BACKUP_SIZE=$(stat -c%s /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb.backup)
    CURRENT_SIZE=$(stat -c%s /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb)
    echo "   Backup:  $BACKUP_SIZE bytes"
    echo "   Current: $CURRENT_SIZE bytes"
    if [ "$CURRENT_SIZE" -gt "$BACKUP_SIZE" ]; then
        echo "   ✓ Current is larger (overlay likely applied)"
    else
        echo "   ✗ Current same/smaller size (overlay may be missing)"
    fi
else
    echo "   No backup file found"
fi

echo ""
echo "7. Re-apply overlay if needed:"
echo "   Run: sudo ./apply_overlay.sh"
echo ""
echo "=== End Diagnostic ==="
