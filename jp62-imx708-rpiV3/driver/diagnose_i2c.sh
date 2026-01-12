#!/bin/bash
# Diagnose I2C and GPIO for IMX708 camera

echo "=== IMX708 I2C/GPIO Diagnostic ==="
echo ""

# Check if i2c-tools installed
if ! command -v i2cdetect &> /dev/null; then
    echo "Installing i2c-tools..."
    sudo apt-get update && sudo apt-get install -y i2c-tools
fi

echo "1. Scanning ALL I2C buses for camera (0x1a or 0x10):"
echo "   IMX708 addresses: 0x1a (default), 0x10 (alternate)"
echo ""

for bus in 0 1 2 3 4 5 6 7 8 9 10; do
    if [ -e "/dev/i2c-$bus" ]; then
        echo "--- Bus $bus ---"
        sudo i2cdetect -y -r $bus 2>/dev/null | grep -E "^00:|^10:|^20:" | head -5
        # Check specifically for 0x1a and 0x10
        if sudo i2cdetect -y -r $bus 2>/dev/null | grep -qE "1a|10"; then
            echo "   *** POSSIBLE CAMERA FOUND ON BUS $bus ***"
        fi
        echo ""
    fi
done

echo "2. I2C bus to physical mapping:"
echo "   i2c-0: /bus@0/i2c@3160000 (Gen1)"
echo "   i2c-1: /bus@0/i2c@c240000 (Gen2)"
echo "   i2c-2: /bus@0/i2c@3180000 (CAM I2C - expected for camera)"
echo "   i2c-3: /bus@0/i2c@3190000"
echo ""

echo "3. Check if camera node exists in device tree:"
if [ -d "/sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a" ]; then
    echo "   ✓ Camera node EXISTS in device tree"
    ls -la /sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a/
else
    echo "   ✗ Camera node NOT found in device tree"
    echo "   Checking what's in i2c@3180000:"
    ls /sys/firmware/devicetree/base/bus@0/i2c@3180000/ 2>/dev/null || echo "   Path doesn't exist"
fi

echo ""
echo "4. GPIO status check:"
echo "   Looking for GPIO chip and available GPIOs..."
ls -la /sys/class/gpio/ 2>/dev/null | head -10
echo ""
cat /sys/kernel/debug/gpio 2>/dev/null | grep -iE "gpio|CAM" | head -20 || echo "   Need root for GPIO debug"

echo ""
echo "5. Check tegra-camera-platform:"
if [ -d "/sys/firmware/devicetree/base/tegra-camera-platform" ]; then
    echo "   ✓ tegra-camera-platform node exists"
else
    echo "   ✗ tegra-camera-platform NOT found"
fi

echo ""
echo "6. Physical connection check:"
echo "   Is the camera ribbon cable connected to CAM0 (22-pin connector)?"
echo "   - Blue side of ribbon faces AWAY from the board"
echo "   - Connector latch must be closed"
echo ""

echo "7. Power rails check (requires camera to be probed):"
sudo cat /sys/kernel/debug/regulator/regulator_summary 2>/dev/null | grep -iE "cam|imx|avdd|dvdd|iovdd" | head -10 || echo "   No camera regulators found"

echo ""
echo "=== End Diagnostic ==="
echo ""
echo "NEXT STEPS:"
echo "1. If camera found on different bus - update DTS target-path"
echo "2. If no camera on any bus - check physical connection"
echo "3. If camera node missing from DT - overlay not applied correctly"
