#!/bin/bash
# Hardware diagnostic for IMX708 camera I2C failure

echo "=== IMX708 Hardware Diagnostic ==="
echo ""

echo "1. Scan ALL I2C buses for ANY device:"
for bus in 0 1 2 3 4 5 6 7 8 9 10; do
    if [ -e "/dev/i2c-$bus" ]; then
        echo ""
        echo "=== I2C Bus $bus ==="
        sudo i2cdetect -y -r $bus 2>/dev/null
    fi
done

echo ""
echo "2. Check GPIO state for camera reset:"
echo "   Looking for CAM-related GPIOs..."
sudo cat /sys/kernel/debug/gpio 2>/dev/null | grep -iE "cam|reset|H6|gpio-5|gpio-6" | head -20 || echo "   (need root for GPIO debug)"

echo ""
echo "3. Check camera reset GPIO from device tree:"
echo "   DTS reset-gpios setting:"
cat /sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a/reset-gpios 2>/dev/null | xxd || echo "   (not found or not readable)"

echo ""
echo "4. Check regulator/power status:"
sudo cat /sys/kernel/debug/regulator/regulator_summary 2>/dev/null | grep -iE "cam|avdd|dvdd|iovdd|imx" | head -10 || echo "   No camera regulators found"

echo ""
echo "5. Physical connection checklist:"
echo "   [ ] Camera ribbon cable firmly seated in CAM0 connector"
echo "   [ ] Connector latch is CLOSED (pushed down)"
echo "   [ ] Blue side of ribbon faces AWAY from Jetson board"
echo "   [ ] Cable not damaged or creased"
echo "   [ ] Camera module LED (if any) lit when powered"

echo ""
echo "6. Try manual GPIO reset toggle:"
echo "   (This may help wake up the camera)"

# Try to find and toggle reset GPIO
RESET_GPIO=""
for gpio in 54 62 56 118 149; do
    if [ -e "/sys/class/gpio/gpio$gpio" ] || echo $gpio > /sys/class/gpio/export 2>/dev/null; then
        echo "   Testing GPIO $gpio..."
        echo out > /sys/class/gpio/gpio$gpio/direction 2>/dev/null
        echo 0 > /sys/class/gpio/gpio$gpio/value 2>/dev/null
        sleep 0.1
        echo 1 > /sys/class/gpio/gpio$gpio/value 2>/dev/null
        sleep 0.1
    fi
done

echo ""
echo "7. Re-check I2C bus 2 after GPIO toggle:"
sudo i2cdetect -y -r 2 2>/dev/null

echo ""
echo "=== End Diagnostic ==="
echo ""
echo "If camera still not detected on I2C:"
echo "  - Double-check physical cable connection"
echo "  - Try reseating the ribbon cable"
echo "  - Verify camera works on Raspberry Pi (if possible)"
echo "  - Check if Arducam UC-376 needs different I2C address"
