#!/bin/bash
# Check if device tree overlay was actually applied at boot

echo "=== Device Tree Check ==="
echo ""

echo "1. Check if imx708 node exists in LIVE device tree:"
if ls /sys/firmware/devicetree/base/bus@0/i2c@3180000/ 2>/dev/null | grep -q imx; then
    echo "   ✓ imx708 node FOUND"
    ls /sys/firmware/devicetree/base/bus@0/i2c@3180000/ | grep imx
else
    echo "   ✗ imx708 node NOT found"
    echo "   Contents of i2c@3180000:"
    ls /sys/firmware/devicetree/base/bus@0/i2c@3180000/ 2>/dev/null || echo "   (path doesn't exist)"
fi

echo ""
echo "2. Check tegra-camera-platform:"
if [ -d /sys/firmware/devicetree/base/tegra-camera-platform ]; then
    echo "   ✓ tegra-camera-platform EXISTS"
else
    echo "   ✗ tegra-camera-platform NOT found"
fi

echo ""
echo "3. DTB file sizes (larger = has overlay):"
echo "   /boot/ location (used by bootloader):"
ls -la /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb* 2>/dev/null || echo "   NOT FOUND"
echo ""
echo "   /boot/dtb/ location:"
ls -la /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb* 2>/dev/null || echo "   NOT FOUND"

echo ""
echo "4. Check imx708 in DTB files:"
echo "   /boot/kernel_*.dtb:"
if dtc -I dtb -O dts /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb 2>/dev/null | grep -q imx708; then
    echo "   ✓ imx708 FOUND in file"
else
    echo "   ✗ imx708 NOT in file"
fi

echo ""
echo "=== End Check ==="
