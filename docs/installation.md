# Arducam IMX708 Camera Driver Installation Guide

**Hardware**: Arducam IMX708 12MP Wide-Angle Camera
**Platform**: NVIDIA Jetson Orin Nano Super (8GB)
**JetPack**: 6.2 (L4T R36.4.3)
**Interface**: CSI-2 (CAM1 port, 15-pin ribbon cable)
**Kernel**: 5.15.148-tegra
**Driver**: RidgeRun nv_imx708 v2.0.6-jp62

> **Status**: ✅ Working as of December 24, 2025. Captures high-quality 4608x2592 @ 14fps images.

---

## Table of Contents

1. [Hardware Requirements](#hardware-requirements)
2. [Physical Setup](#physical-setup)
3. [Quick Start](#quick-start)
4. [What Works vs What Doesn't](#what-works-vs-what-doesnt)
5. [Installation from Scratch](#installation-from-scratch)
6. [Image Capture and Processing](#image-capture-and-processing)
7. [Troubleshooting](#troubleshooting)
8. [Key Learnings](#key-learnings-december-2025)
9. [Credits](#credits)

---

## Hardware Requirements

### Required Components

| Component | Model | Notes |
|-----------|-------|-------|
| Single Board Computer | NVIDIA Jetson Orin Nano Super (8GB) | Also works with Orin Nano 4GB |
| Camera Module | Arducam IMX708 12MP Wide-Angle | Sony IMX708 sensor |
| Ribbon Cable | 15-pin to 22-pin CSI FFC | 15cm or 30cm length |
| Storage | microSD 64GB+ or NVMe SSD | NVMe recommended for performance |

### Where to Buy

- **Arducam IMX708**: [Arducam Store](https://www.arducam.com/product/arducam-12mp-imx708-wide-angle-camera-module-for-raspberry-pi/) or Amazon
- **Jetson Orin Nano**: [NVIDIA Partners](https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin/) or Seeed Studio
- **Ribbon Cable**: Ensure 15-pin (camera side) to 22-pin (Jetson side) adapter if needed

### Software Requirements

- JetPack 6.2 (L4T R36.4.3) - [Download](https://developer.nvidia.com/embedded/jetpack)
- RidgeRun IMX708 Driver v2.0.6-jp62 - [GitHub](https://github.com/RidgeRun/NVIDIA-Jetson-IMX708-RPIV3)

---

## Physical Setup

### Camera Connection

⚠️ **IMPORTANT**: Power off the Jetson before connecting or disconnecting the camera!

1. **Locate CAM1 port** on the Jetson Orin Nano carrier board (not CAM0)
2. **Open the connector latch** by gently pulling up on the black plastic tab
3. **Insert the ribbon cable**:
   - Blue side (contacts) facing **toward the heatsink/fan**
   - Ensure cable is fully inserted and straight
4. **Close the latch** to secure the cable
5. **Verify connection** - cable should not move when gently tugged

### Common Connection Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Wrong port (CAM0 instead of CAM1) | No /dev/video0 | Use CAM1 port |
| Cable backwards | No /dev/video0 | Blue/contacts toward heatsink |
| Cable not fully inserted | Intermittent detection | Re-seat cable firmly |
| Latch not closed | Capture timeouts | Close connector latch |
| Damaged ribbon cable | No detection or errors | Replace cable |

---

## Quick Start

```bash
# 1. Connect camera to CAM1 port (power off first!)

# 2. Install the RidgeRun IMX708 driver (already done on this system)
# Driver location: /lib/modules/5.15.148-tegra/updates/drivers/media/i2c/nv_imx708.ko

# 3. Boot with the custom IMX708 overlay
# Current config: /boot/tegra234-p3768-0000+p3767-0005-imx708-nvidia-csi.dtb

# 4. Verify camera
ls /dev/video0
v4l2-ctl -d /dev/video0 --all

# 5. Capture test image
v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=1 --stream-to=/tmp/test.raw

# 6. Convert to viewable image (see Python script below)
```

---

## What Works vs What Doesn't

### Working Solution

| Component | Configuration | Notes |
|-----------|---------------|-------|
| Driver | `nv_imx708.ko` (RidgeRun) | Compatible with `sony,imx708` |
| Device Tree | Custom merged DTB | NVIDIA CSI structure + IMX708 sensor params |
| Capture | `v4l2-ctl --stream-mmap` | Raw Bayer RG10 format |
| Processing | Python + OpenCV | Percentile normalization + debayer + white balance |

### What Does NOT Work

| Approach | Problem |
|----------|---------|
| `jetson-io` with IMX477-C | Capture timeouts, no frames |
| `nvarguscamerasrc` | Requires ISP tuning files (not available for IMX708) |
| GStreamer `v4l2src` | Format negotiation fails ("not-negotiated" error) |
| RidgeRun's channel@1 overlay | cam_i2cmux not created, media links fail |
| OVERLAYS directive in extlinux.conf | UEFI boot doesn't apply runtime overlays |
| Simple bit-shift normalization | Produces overexposed/washed out images |

---

## Technical Details

### Working Device Tree Configuration

The key insight: Use NVIDIA's CSI pipeline structure (channel@0, port@0) with IMX708 sensor parameters.

**Critical Settings** (from working overlay):
```dts
// Sensor node
rbpcv3_imx708_c@1a {
    compatible = "sony,imx708";
    reg = <0x1a>;

    mode0 {
        tegra_sinterface = "serial_c";    // CSI port C for CAM1
        discontinuous_clk = "no";          // NVIDIA's setting (not "yes")
        lane_polarity = "0";               // NVIDIA's setting (not "6")
        active_w = "4608";
        active_h = "2592";
        max_framerate = "14000000";        // 14 fps
        embedded_metadata_height = "4";    // IMX708 specific
    };
};

// NVCSI channel - uses channel@0 even for CAM1!
channel@0 {
    reg = <0x00>;
    ports {
        port@0 {
            endpoint@0 {
                port-index = <0x02>;       // CSI port C
                bus-width = <0x02>;        // 2 lanes
            };
        };
    };
};
```

### Boot Configuration

**Current `/boot/extlinux/extlinux.conf`**:
```
DEFAULT IMX708-nvidia-csi

LABEL IMX708-nvidia-csi
      MENU LABEL IMX708 Camera (NVIDIA CSI parameters)
      LINUX /boot/Image
      INITRD /boot/initrd
      FDT /boot/tegra234-p3768-0000+p3767-0005-imx708-nvidia-csi.dtb
      APPEND ${cbootargs} root=/dev/mmcblk0p1 rw rootwait ...
```

### Driver Info

```bash
$ modinfo nv_imx708
filename:    /lib/modules/5.15.148-tegra/updates/drivers/media/i2c/nv_imx708.ko
version:     2.0.6-jp62
license:     GPL v2
author:      RidgeRun <support@ridgerun.com>
alias:       of:N*T*Csony,imx708
alias:       of:N*T*Cridgerun,imx477
```

---

## Image Capture and Processing

### Why nvarguscamerasrc Doesn't Work

`nvarguscamerasrc` requires NVIDIA ISP (Image Signal Processor) tuning files specific to each sensor. These files contain:
- Color correction matrices
- Lens shading correction
- Noise reduction parameters
- Auto-exposure/white-balance algorithms

Without ISP tuning for IMX708, `nvarguscamerasrc` produces errors or black frames.

### Working Capture Method

Use `v4l2-ctl` to capture raw Bayer frames, then process with Python:

```bash
# Capture raw frame
v4l2-ctl -d /dev/video0 \
    --set-fmt-video=width=4608,height=2592,pixelformat=RG10 \
    --stream-mmap --stream-count=1 \
    --stream-to=/tmp/frame.raw
```

### Python Processing Script

```python
#!/usr/bin/env python3
"""
Convert IMX708 raw Bayer to color image with proper normalization.
"""
import numpy as np
import cv2

def process_imx708_raw(raw_path, output_path):
    # Read raw Bayer data (16-bit container for 10-bit data)
    raw_data = np.fromfile(raw_path, dtype=np.uint16)

    # Reshape to image dimensions
    width, height = 4608, 2592
    img = raw_data[:width * height].reshape((height, width))

    # Normalize using percentile stretch (handles varying lighting)
    p2, p98 = np.percentile(img, [2, 98])
    img_norm = np.clip((img.astype(float) - p2) / (p98 - p2) * 255, 0, 255).astype(np.uint8)

    # Debayer (RGGB Bayer pattern)
    color = cv2.cvtColor(img_norm, cv2.COLOR_BAYER_RG2BGR)

    # Simple white balance (gray world assumption)
    b, g, r = cv2.split(color)
    avg = (r.mean() + g.mean() + b.mean()) / 3
    r = np.clip(r * (avg / r.mean()), 0, 255).astype(np.uint8)
    g = np.clip(g * (avg / g.mean()), 0, 255).astype(np.uint8)
    b = np.clip(b * (avg / b.mean()), 0, 255).astype(np.uint8)
    color_wb = cv2.merge([b, g, r])

    # Save
    cv2.imwrite(output_path, color_wb, [cv2.IMWRITE_JPEG_QUALITY, 95])
    print(f"Saved: {output_path}")

    return color_wb

if __name__ == "__main__":
    process_imx708_raw("/tmp/frame.raw", "/tmp/frame.jpg")
```

### Camera Controls

```bash
# Available controls
v4l2-ctl -d /dev/video0 --list-ctrls-menus

# Key controls:
# - exposure: 500-65488 (microseconds)
# - gain: 16-257
# - frame_rate: 2000000-14000000 (in micro-fps, so 14000000 = 14fps)

# Set exposure (increase for dark environments)
v4l2-ctl -d /dev/video0 -c exposure=20000

# Set gain (increase for dark environments, but adds noise)
v4l2-ctl -d /dev/video0 -c gain=64
```

---

## Installation from Scratch

Complete installation guide if you're starting fresh.

### Prerequisites

```bash
# On Jetson - Install build dependencies
sudo apt update
sudo apt install -y build-essential device-tree-compiler \
    nvidia-l4t-kernel-headers nvidia-l4t-kernel-oot-headers git
```

### 1. Get the RidgeRun Driver

```bash
# On your development machine (Mac/Linux)
git clone https://github.com/RidgeRun/NVIDIA-Jetson-IMX708-RPIV3.git
cd NVIDIA-Jetson-IMX708-RPIV3

# Copy the JetPack 6.2 driver to Jetson
rsync -avz NVIDIA-Jetson-IMX708-RPIV3/driver/ jetson:~/imx708-driver/
```

Or download directly on Jetson:
```bash
# On Jetson
git clone https://github.com/RidgeRun/NVIDIA-Jetson-IMX708-RPIV3.git
cd NVIDIA-Jetson-IMX708-RPIV3/driver
```

### 2. Build on Jetson

```bash
cd ~/imx708-driver
sudo apt install -y build-essential device-tree-compiler \
    nvidia-l4t-kernel-headers nvidia-l4t-kernel-oot-headers
./build.sh
./build.sh install
```

### 3. Create Device Tree Overlay

Use the overlay source in `docs/overlays/imx708-nvidia-csi.dts`:

```bash
# Compile overlay
dtc -@ -I dts -O dtb -o imx708-nvidia-csi.dtbo imx708-nvidia-csi.dts

# Merge with base DTB
sudo fdtoverlay \
    -i /boot/tegra234-p3768-0000+p3767-0005-nv.dtb \
    -o /boot/tegra234-p3768-0000+p3767-0005-imx708-nvidia-csi.dtb \
    imx708-nvidia-csi.dtbo
```

### 4. Update Boot Configuration

Edit `/boot/extlinux/extlinux.conf`:
```
DEFAULT IMX708-nvidia-csi

LABEL IMX708-nvidia-csi
      MENU LABEL IMX708 Camera
      LINUX /boot/Image
      INITRD /boot/initrd
      FDT /boot/tegra234-p3768-0000+p3767-0005-imx708-nvidia-csi.dtb
      APPEND ${cbootargs} root=/dev/mmcblk0p1 rw rootwait rootfstype=ext4 ...
```

### 5. Reboot and Verify

```bash
sudo reboot

# After reboot
ls /dev/video0
v4l2-ctl -d /dev/video0 --info
dmesg | grep imx708
```

---

## Troubleshooting

### Verifying Successful Installation

When everything is working correctly, you should see:

**1. Device file exists:**
```bash
$ ls -la /dev/video0
crw-rw---- 1 root video 81, 0 Dec 24 10:00 /dev/video0
```

**2. Driver loaded:**
```bash
$ lsmod | grep imx708
nv_imx708              28672  1
```

**3. Camera detected in dmesg:**
```bash
$ sudo dmesg | grep -E 'imx708|nvcsi|tegra-capt'
[    7.097626] imx708 9-001a: probing v4l2 sensor at addr 0x1a
[    7.097748] imx708 9-001a: tegracam sensor driver:imx708_v2.0.6
[    7.398908] tegra-camrtc-capture-vi tegra-capture-vi: subdev imx708 9-001a bound
[    7.398922] imx708 9-001a: detected imx708 sensor
```

**4. V4L2 device info:**
```bash
$ v4l2-ctl -d /dev/video0 --info
Driver Info:
        Driver name      : tegra-video
        Card type        : vi-output, imx708 9-001a
        Bus info         : platform:tegra-capture-vi:1
```

### No /dev/video0

1. Check driver loaded: `lsmod | grep imx708`
2. Check device tree: `cat /sys/firmware/devicetree/base/bus@0/cam_i2cmux/i2c@1/*/compatible`
3. Check dmesg: `dmesg | grep -E 'imx708|nvcsi|tegra-capt'`

### Capture Timeouts

If you see "uncorr_err: request timed out":
- Verify CSI parameters: `discontinuous_clk = "no"`, `lane_polarity = "0"`
- Check ribbon cable connection
- Try lower resolution or frame rate

### Dark/Overexposed Images

Adjust exposure and gain:
```bash
# For dark environment
v4l2-ctl -d /dev/video0 -c exposure=40000 -c gain=100

# For bright environment
v4l2-ctl -d /dev/video0 -c exposure=5000 -c gain=16
```

---

## Key Learnings (December 2025)

1. **jetson-io IMX477-C mode does NOT work** for IMX708 - produces capture timeouts
2. **OVERLAYS directive doesn't work** with UEFI boot - must pre-merge with fdtoverlay
3. **Use NVIDIA's channel structure** (channel@0/port@0) even for CAM1 physical port
4. **CSI PHY parameters matter**: NVIDIA's settings work, RidgeRun's original values cause timeouts
5. **nvarguscamerasrc needs ISP tuning** - use v4l2-ctl + Python processing instead
6. **Raw Bayer data needs percentile normalization** - simple bit-shift (>>2) produces overexposed images
7. **White balance is essential** - gray world assumption corrects color cast in processed images

### Critical CSI Parameter Comparison

| Parameter | RidgeRun Original (FAILS) | NVIDIA Working (SUCCESS) |
|-----------|---------------------------|--------------------------|
| `discontinuous_clk` | `"yes"` | `"no"` |
| `lane_polarity` | `"6"` | `"0"` |
| `channel` | `channel@1` | `channel@0` |

The RidgeRun driver's original overlay used CSI parameters that cause "uncorr_err: request timed out" errors. Using NVIDIA's CSI parameters (from their IMX219/IMX477 overlays) with the IMX708 sensor settings resolves these issues.

---

## Files Reference

| File | Location | Purpose |
|------|----------|---------|
| Driver module | `/lib/modules/.../nv_imx708.ko` | Kernel driver |
| Working DTB | `/boot/tegra234-p3768-0000+p3767-0005-imx708-nvidia-csi.dtb` | Device tree |
| Overlay source | `docs/overlays/imx708-nvidia-csi.dts` | Overlay DTS |
| Boot config | `/boot/extlinux/extlinux.conf` | Boot menu |

---

## Specifications

| Parameter | Value |
|-----------|-------|
| Sensor | Sony IMX708 |
| Resolution | 4608 x 2592 (12MP) |
| Frame Rate | 14 fps (max at full resolution) |
| Pixel Format | RG10 (10-bit Bayer RGRG/GBGB) |
| Interface | CSI-2, 2 lanes |
| I2C Address | 0x1a |
| I2C Bus | Bus 9 (CAM1 port) |

---

## Advanced Usage

### Continuous Capture for Video/Streaming

```python
#!/usr/bin/env python3
"""
Continuous capture from IMX708 with real-time processing.
Useful for video recording or streaming applications.
"""
import numpy as np
import cv2
import subprocess
import time

WIDTH, HEIGHT = 4608, 2592
FRAME_SIZE = WIDTH * HEIGHT * 2  # 16-bit per pixel

def capture_continuous(num_frames=30, output_dir="/tmp"):
    """Capture multiple frames continuously."""

    # Start v4l2-ctl streaming process
    cmd = [
        "v4l2-ctl", "-d", "/dev/video0",
        "--set-fmt-video=width={},height={},pixelformat=RG10".format(WIDTH, HEIGHT),
        "--stream-mmap", "--stream-count={}".format(num_frames),
        "--stream-to=-"  # Output to stdout
    ]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    for i in range(num_frames):
        # Read one frame
        raw_data = proc.stdout.read(FRAME_SIZE)
        if len(raw_data) < FRAME_SIZE:
            break

        # Convert to numpy array
        img = np.frombuffer(raw_data, dtype=np.uint16).reshape((HEIGHT, WIDTH))

        # Process (fast version for real-time)
        img_8bit = (img >> 2).astype(np.uint8)  # Quick conversion
        color = cv2.cvtColor(img_8bit, cv2.COLOR_BAYER_RG2BGR)

        # Save or display
        cv2.imwrite(f"{output_dir}/frame_{i:04d}.jpg", color)
        print(f"Captured frame {i+1}/{num_frames}")

    proc.wait()

if __name__ == "__main__":
    capture_continuous(num_frames=10)
```

### Integration with OpenCV

```python
#!/usr/bin/env python3
"""
OpenCV integration for computer vision applications.
"""
import numpy as np
import cv2
import subprocess

class IMX708Camera:
    def __init__(self, width=4608, height=2592):
        self.width = width
        self.height = height
        self.frame_size = width * height * 2

    def capture_frame(self):
        """Capture a single processed frame."""
        cmd = [
            "v4l2-ctl", "-d", "/dev/video0",
            f"--set-fmt-video=width={self.width},height={self.height},pixelformat=RG10",
            "--stream-mmap", "--stream-count=1", "--stream-to=-"
        ]

        result = subprocess.run(cmd, capture_output=True)
        raw = np.frombuffer(result.stdout, dtype=np.uint16)
        img = raw[:self.width * self.height].reshape((self.height, self.width))

        # Normalize and debayer
        p2, p98 = np.percentile(img, [2, 98])
        img_norm = np.clip((img.astype(float) - p2) / (p98 - p2) * 255, 0, 255).astype(np.uint8)
        color = cv2.cvtColor(img_norm, cv2.COLOR_BAYER_RG2BGR)

        return color

# Usage
camera = IMX708Camera()
frame = camera.capture_frame()
# Now use frame with any OpenCV function
gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
edges = cv2.Canny(gray, 100, 200)
```

---

## Known Limitations

- **Single resolution mode**: Only 4608x2592 @ 14fps available (no binned modes)
- **No hardware ISP**: Must process raw Bayer in software
- **No autofocus**: IMX708 has fixed focus (wide-angle lens)
- **No nvarguscamerasrc**: Can't use NVIDIA's camera pipeline directly

---

## Credits

This guide was developed through extensive testing and debugging on the Jetson Orin Nano Super platform.

### Acknowledgments

- **[RidgeRun](https://ridgerun.com/)** - For the nv_imx708 driver and ongoing Jetson camera support
- **[NVIDIA](https://developer.nvidia.com/)** - For the Jetson platform and comprehensive documentation
- **[Arducam](https://www.arducam.com/)** - For the IMX708 camera module
- **Jetson Community** - For discussions and shared knowledge on NVIDIA Developer Forums

### Driver License

The RidgeRun nv_imx708 driver is licensed under GPL v2.

### Contributing

Found an issue or have improvements? Please:
1. Open an issue on the repository
2. Submit a pull request with your changes
3. Share your experiences on the [NVIDIA Developer Forums](https://forums.developer.nvidia.com/)

---

**Last Updated**: December 24, 2025
**Status**: ✅ Working - High quality 12MP captures confirmed
**Tested On**: Jetson Orin Nano Super 8GB, JetPack 6.2, Arducam IMX708
