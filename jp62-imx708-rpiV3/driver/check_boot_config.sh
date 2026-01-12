#!/bin/bash
# Check boot configuration and DTB loading mechanism

echo "=== Boot Configuration Check ==="
echo ""

echo "1. extlinux.conf contents:"
cat /boot/extlinux/extlinux.conf
echo ""

echo "2. Check for FDT/FDTDIR in extlinux:"
grep -E "FDT|FDTDIR" /boot/extlinux/extlinux.conf || echo "   No FDT line found (bootloader auto-selects)"
echo ""

echo "3. Boot partitions:"
lsblk -o NAME,SIZE,MOUNTPOINT,LABEL | head -20
echo ""

echo "4. Check UEFI/cboot DTB location:"
echo "   Looking for DTB partition..."
sudo fdisk -l 2>/dev/null | grep -i dtb || echo "   No DTB partition label found"
echo ""

echo "5. Kernel boot command line:"
cat /proc/cmdline
echo ""

echo "6. Check jetson-io tool (if available):"
if [ -f /opt/nvidia/jetson-io/config-by-hardware.py ]; then
    echo "   ✓ jetson-io tool found"
    echo "   Available hardware configs:"
    sudo /opt/nvidia/jetson-io/config-by-hardware.py -l 2>/dev/null | head -20
else
    echo "   ✗ jetson-io tool not found"
fi

echo ""
echo "7. Check /boot/dtb symbolic link:"
ls -la /boot/dtb 2>/dev/null || echo "   /boot/dtb is a directory, not a link"

echo ""
echo "8. NVIDIA DTB update tools:"
which nv-update-dtb 2>/dev/null || echo "   nv-update-dtb not found"
ls /opt/nvidia/l4t-bootloader-config/ 2>/dev/null || echo "   l4t-bootloader-config not found"

echo ""
echo "=== Possible Solution ==="
echo "Try adding explicit FDT line to extlinux.conf:"
echo "   FDT /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb"

echo ""
echo "=== End Check ==="
