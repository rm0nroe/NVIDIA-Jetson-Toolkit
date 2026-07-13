#!/bin/bash
#
# validate.sh - Validate IMX708 camera installation on Jetson Orin Nano
# For JetPack 6.2 (L4T R36.4.x)
#
# Run this after rebooting to verify the camera is detected
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
echo_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    if [ "$1" -eq 0 ]; then
        echo_pass "$2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo_fail "$2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=========================================="
echo "IMX708 Camera Validation Script"
echo "JetPack 6.2 (L4T R36.4.x)"
echo "=========================================="
echo ""

# Test 1: Check kernel module is loaded
echo_info "Test 1: Checking kernel module..."
if lsmod | grep -q "nv_imx708"; then
    test_result 0 "Kernel module 'nv_imx708' is loaded"
else
    test_result 1 "Kernel module 'nv_imx708' is NOT loaded"
    echo_info "Try: sudo modprobe nv_imx708"
fi

# Test 2: Check dmesg for imx708 probe
echo ""
echo_info "Test 2: Checking driver probe in dmesg..."
if dmesg | grep -qi "imx708.*probe\|detected imx708"; then
    test_result 0 "IMX708 driver probe messages found in dmesg"
    echo_info "Driver messages:"
    dmesg | grep -i imx708 | tail -5
else
    test_result 1 "No IMX708 probe messages in dmesg"
    echo_info "Checking for errors:"
    dmesg | grep -i "imx708\|camera\|csi\|nvcsi" | tail -10 || true
fi

# Test 3: Check device tree
echo ""
echo_info "Test 3: Checking device tree..."
# CAM1 node (JetPack 6.2): sensor lives under cam_i2cmux/i2c@1 as rbpcv3_imx708_c@1a
DT_PATH="/proc/device-tree/bus@0/cam_i2cmux/i2c@1/rbpcv3_imx708_c@1a"
if [ -d "$DT_PATH" ]; then
    test_result 0 "IMX708 device tree node exists"
    if [ -f "$DT_PATH/status" ]; then
        STATUS=$(cat "$DT_PATH/status" 2>/dev/null | tr -d '\0')
        echo_info "Device status: $STATUS"
    fi
else
    test_result 1 "IMX708 device tree node not found"
    echo_info "Checking if overlay was applied..."
    if [ -f "/proc/device-tree/tegra-camera-platform/modules/module0/badge" ]; then
        BADGE=$(cat "/proc/device-tree/tegra-camera-platform/modules/module0/badge" 2>/dev/null | tr -d '\0')
        echo_info "Camera module badge: $BADGE"
    fi
fi

# Test 4: Check video device
echo ""
echo_info "Test 4: Checking video device..."
if [ -e /dev/video0 ]; then
    test_result 0 "/dev/video0 exists"
    echo_info "Video devices:"
    ls -la /dev/video* 2>/dev/null || true
else
    test_result 1 "/dev/video0 does NOT exist"
fi

# Test 5: Check v4l2-ctl device list
echo ""
echo_info "Test 5: Checking V4L2 device list..."
if command -v v4l2-ctl &> /dev/null; then
    V4L2_OUTPUT=$(v4l2-ctl --list-devices 2>&1)
    if echo "$V4L2_OUTPUT" | grep -qi "imx708\|video0"; then
        test_result 0 "IMX708 found in v4l2-ctl device list"
        echo_info "V4L2 devices:"
        echo "$V4L2_OUTPUT"
    else
        test_result 1 "IMX708 NOT found in v4l2-ctl device list"
        echo_info "V4L2 output: $V4L2_OUTPUT"
    fi
else
    echo_warn "v4l2-ctl not installed. Install with: sudo apt install v4l2-utils"
fi

# Test 6: Check I2C communication
echo ""
echo_info "Test 6: Checking I2C bus..."
if command -v i2cdetect &> /dev/null; then
    # Check I2C bus 9 (cam_i2c on Orin Nano)
    I2C_SCAN=$(sudo i2cdetect -y -r 9 2>&1 || echo "scan_failed")
    if echo "$I2C_SCAN" | grep -q "1a"; then
        test_result 0 "IMX708 detected at I2C address 0x1a on bus 9"
    elif echo "$I2C_SCAN" | grep -q "UU"; then
        test_result 0 "Device at 0x1a is in use (driver bound)"
    else
        test_result 1 "IMX708 NOT detected at I2C address 0x1a"
        echo_info "I2C bus 9 scan:"
        echo "$I2C_SCAN" | head -10
    fi
else
    echo_warn "i2cdetect not installed. Install with: sudo apt install i2c-tools"
fi

# Test 7: Check the active extlinux entry points at a merged IMX708 DTB
echo ""
echo_info "Test 7: Checking bootloader configuration..."
# JetPack 6.2 ignores the OVERLAYS directive; the working config uses an FDT
# line pointing at a DTB that already has the imx708 overlay merged in.
EXTLINUX="/boot/extlinux/extlinux.conf"
if [ -f "$EXTLINUX" ]; then
    DEFAULT_LABEL=$(awk 'toupper($1) == "DEFAULT" { print $2; exit }' "$EXTLINUX")
    FDT_PATH=$(awk -v default_label="$DEFAULT_LABEL" '
        toupper($1) == "LABEL" {
            if (default_label == "" && !seen_label) {
                active = 1
            } else {
                active = ($2 == default_label)
            }
            seen_label = 1
            next
        }
        active && toupper($1) == "FDT" { print $2; exit }
    ' "$EXTLINUX")

    if [ -z "$FDT_PATH" ]; then
        test_result 1 "No FDT line found in the active extlinux.conf entry"
        echo_info "Set the active entry's FDT line to the pre-merged DTB."
        echo_info "See docs/installation.md for the verified JP6.2 procedure."
    elif [ ! -f "$FDT_PATH" ]; then
        test_result 1 "Active FDT file does not exist: $FDT_PATH"
    elif command -v dtc &> /dev/null; then
        if dtc -I dtb -O dts "$FDT_PATH" 2>/dev/null | grep -qi "imx708"; then
            test_result 0 "Active FDT contains the merged IMX708 device tree"
            echo_info "Active FDT: $FDT_PATH"
        else
            test_result 1 "Active FDT does not contain an IMX708 device-tree node"
            echo_info "Active FDT: $FDT_PATH"
        fi
    elif strings "$FDT_PATH" 2>/dev/null | grep -qi "imx708"; then
        test_result 0 "Active FDT contains the merged IMX708 device tree"
        echo_info "Active FDT: $FDT_PATH"
    else
        test_result 1 "Could not verify IMX708 content in the active FDT"
        echo_info "Install device-tree-compiler for a definitive check: sudo apt install device-tree-compiler"
    fi
else
    echo_warn "extlinux.conf not found"
fi

# Summary
echo ""
echo "=========================================="
echo "VALIDATION SUMMARY"
echo "=========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo_pass "All tests passed! Camera should be operational."
    echo ""
    echo "Capture a raw frame with (IMX708 lacks the ISP tuning required by nvarguscamerasrc):"
    echo "  v4l2-ctl -d /dev/video0 \\"
    echo "    --set-fmt-video=width=4608,height=2592,pixelformat=RG10 \\"
    echo "    --stream-mmap --stream-count=1 --stream-to=/tmp/frame.raw"
    echo "  # then debayer in Python/OpenCV (see docs/installation.md)"
else
    echo_fail "Some tests failed. Please check the errors above."
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Verify camera is physically connected to the CAM1 port (not CAM0)"
    echo "  2. Check kernel module: sudo modprobe nv_imx708"
    echo "  3. Check dmesg for errors: dmesg | grep -i imx708"
    echo "  4. Verify the FDT line in extlinux.conf points at the merged imx708 DTB"
    echo "  5. Reboot if the DTB/boot config was just changed"
fi

exit $TESTS_FAILED
