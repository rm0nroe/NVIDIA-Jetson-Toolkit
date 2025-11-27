#!/bin/bash
#
# build.sh - Build IMX708 driver natively on Jetson Orin Nano
# For JetPack 6.2 (L4T R36.4.x)
#
# Usage: ./build.sh [clean|install|uninstall]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "IMX708 Camera Driver Build Script"
echo "JetPack 6.2 (L4T R36.4.x)"
echo "=========================================="
echo ""

# Check if running on Jetson
check_platform() {
    if [ ! -f /etc/nv_tegra_release ]; then
        echo_warn "This does not appear to be a Jetson device"
        echo_warn "Native build may not work correctly"
    else
        echo_info "Detected Jetson platform:"
        cat /etc/nv_tegra_release
    fi
}

# Check and install dependencies
check_dependencies() {
    echo_info "Checking dependencies..."

    local missing_deps=()

    # Check for kernel headers
    KERNEL_VER=$(uname -r)
    KERNEL_HEADERS="/lib/modules/${KERNEL_VER}/build"

    if [ ! -d "$KERNEL_HEADERS" ]; then
        echo_error "Kernel headers not found at $KERNEL_HEADERS"
        echo_info "Installing kernel headers..."
        sudo apt-get update
        sudo apt-get install -y nvidia-l4t-kernel-headers || {
            echo_error "Failed to install kernel headers"
            echo_info "Try: sudo apt install nvidia-l4t-kernel-headers"
            exit 1
        }
    fi

    # Check for dtc
    if ! command -v dtc &> /dev/null; then
        missing_deps+=("device-tree-compiler")
    fi

    # Check for build-essential
    if ! command -v make &> /dev/null; then
        missing_deps+=("build-essential")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo_info "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing_deps[@]}"
    fi

    echo_info "All dependencies satisfied"
}

# Build the driver
do_build() {
    echo_info "Kernel version: $(uname -r)"
    echo_info "Kernel headers: /lib/modules/$(uname -r)/build"
    echo ""

    echo_info "Building kernel module..."
    make modules

    if [ -f "src/nv_imx708.ko" ]; then
        echo_info "Kernel module built successfully: src/nv_imx708.ko"
    else
        echo_error "Kernel module build failed"
        exit 1
    fi

    echo ""
    echo_info "Building device tree overlay..."
    make dtbo

    if [ -f "tegra234-camera-imx708-orin-nano.dtbo" ]; then
        echo_info "Device tree overlay built: tegra234-camera-imx708-orin-nano.dtbo"
    else
        echo_error "Device tree overlay build failed"
        exit 1
    fi

    echo ""
    echo "=========================================="
    echo_info "Build completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Install: ./build.sh install"
    echo "  2. Or run: sudo make install"
    echo "=========================================="
}

# Clean build artifacts
do_clean() {
    echo_info "Cleaning build artifacts..."
    make clean
    echo_info "Clean complete"
}

# Install the driver
do_install() {
    echo_info "Installing IMX708 driver..."

    # Check if built
    if [ ! -f "src/nv_imx708.ko" ] || [ ! -f "tegra234-camera-imx708-orin-nano.dtbo" ]; then
        echo_warn "Build artifacts not found, building first..."
        do_build
    fi

    make install
}

# Uninstall the driver
do_uninstall() {
    echo_info "Uninstalling IMX708 driver..."
    make uninstall
}

# Main
check_platform

case "${1:-build}" in
    build)
        check_dependencies
        do_build
        ;;
    clean)
        do_clean
        ;;
    install)
        check_dependencies
        do_install
        ;;
    uninstall)
        do_uninstall
        ;;
    *)
        echo "Usage: $0 [build|clean|install|uninstall]"
        echo ""
        echo "Commands:"
        echo "  build     - Build kernel module and device tree overlay (default)"
        echo "  clean     - Remove build artifacts"
        echo "  install   - Build and install driver"
        echo "  uninstall - Remove installed driver"
        exit 1
        ;;
esac
