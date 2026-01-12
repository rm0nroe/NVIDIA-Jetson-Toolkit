#!/bin/bash
# Check IMX708 camera status after reboot

echo "=== IMX708 Camera Status Check ==="
echo ""

echo "1. Kernel module status:"
if lsmod | grep -q nv_imx708; then
    echo "   ✓ nv_imx708 module is loaded"
else
    echo "   ✗ nv_imx708 module NOT loaded"
fi

echo ""
echo "2. Video devices:"
if ls /dev/video* 2>/dev/null; then
    echo "   ✓ Video device(s) found"
else
    echo "   ✗ No /dev/video* devices found"
fi

echo ""
echo "3. IMX708 dmesg logs:"
sudo dmesg | grep -i imx708

echo ""
echo "4. Camera/sensor probe logs:"
sudo dmesg | grep -iE "imx708|tegra-capt|nvcsi|camera|sensor.*probe" | head -20

echo ""
echo "5. I2C device check (address 0x1a on bus 2):"
if command -v i2cdetect &> /dev/null; then
    sudo i2cdetect -y -r 2 2>/dev/null | grep -E "^10:|^20:" || echo "   Run 'sudo apt install i2c-tools' for I2C diagnostics"
else
    echo "   i2c-tools not installed (optional)"
fi

echo ""
echo "=== End of Check ==="
