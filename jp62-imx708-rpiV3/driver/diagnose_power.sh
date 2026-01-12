#!/bin/bash
# Power and connection diagnostic for IMX708 camera

echo "=== IMX708 Power & Connection Diagnostic ==="
echo ""

echo "1. Check camera power rails status:"
echo "   (Looking for cam-related regulators)"
for reg in /sys/class/regulator/regulator.*/; do
    name=$(cat "${reg}name" 2>/dev/null)
    state=$(cat "${reg}state" 2>/dev/null)
    if echo "$name" | grep -qiE "cam|avdd|dvdd|iovdd|vana|vdig|vddio"; then
        echo "   $name: $state"
    fi
done

echo ""
echo "2. Check I2C controller status:"
for i2c in /sys/bus/i2c/devices/i2c-*/; do
    bus=$(basename "$i2c")
    name=$(cat "${i2c}name" 2>/dev/null || echo "unknown")
    echo "   $bus: $name"
done

echo ""
echo "3. Current I2C bus 2 state (camera bus):"
sudo i2cdetect -y -r 2 2>/dev/null || echo "   (i2cdetect failed)"

echo ""
echo "4. Check pinmux for I2C2 (CAM0):"
if [ -f /sys/kernel/debug/pinctrl/2430000.pinmux/pinmux-pins ]; then
    sudo cat /sys/kernel/debug/pinctrl/2430000.pinmux/pinmux-pins 2>/dev/null | grep -i "cam\|i2c" | head -10
else
    echo "   Pinmux debug not available"
fi

echo ""
echo "5. Check if camera reset GPIO is configured:"
if [ -d /sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a ]; then
    echo "   ✓ IMX708 device tree node exists"
    echo "   Reset GPIO config:"
    cat /sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a/reset-gpios 2>/dev/null | xxd | head -2
else
    echo "   ✗ IMX708 device tree node NOT found"
fi

echo ""
echo "6. Try forcing I2C bus reset:"
echo "   Unbinding and rebinding I2C controller..."
I2C_DEV="3180000.i2c"
if [ -d "/sys/bus/platform/drivers/tegra-i2c/$I2C_DEV" ]; then
    echo "$I2C_DEV" | sudo tee /sys/bus/platform/drivers/tegra-i2c/unbind 2>/dev/null
    sleep 0.5
    echo "$I2C_DEV" | sudo tee /sys/bus/platform/drivers/tegra-i2c/bind 2>/dev/null
    sleep 0.5
    echo "   Re-checking I2C bus 2:"
    sudo i2cdetect -y -r 2 2>/dev/null
else
    echo "   I2C controller path not found"
fi

echo ""
echo "7. Check dmesg for recent I2C errors:"
sudo dmesg | grep -iE "i2c.*error|i2c.*fail|i2c.*timeout|3180000" | tail -10

echo ""
echo "=== Power Diagnostic Complete ==="
echo ""
echo "NEXT STEPS if camera still not detected:"
echo "  1. Power off Jetson completely (not just reboot)"
echo "  2. Disconnect and reconnect camera ribbon cable"
echo "  3. Verify: Blue stripe faces AWAY from heatsink on Jetson side"
echo "  4. Ensure connector latches are CLOSED (push down firmly)"
echo "  5. Power on and run: sudo i2cdetect -y -r 2"
echo ""
echo "If 0x1a appears → camera connected successfully"
echo "If still empty → possible hardware issue with cable or camera"
