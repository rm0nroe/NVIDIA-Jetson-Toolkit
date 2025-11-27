# IMX708 Camera Driver for JetPack 6.2

Out-of-tree driver for the Sony IMX708 camera sensor (Raspberry Pi Camera Module 3) on NVIDIA Jetson Orin Nano running JetPack 6.2 (L4T R36.4.x).

## Prerequisites

- Jetson Orin Nano Developer Kit
- JetPack 6.2 (L4T R36.4.3) installed and booted
- IMX708-based camera (e.g., Arducam UC-376, Raspberry Pi Camera Module 3)
- Camera connected to CSI CAM0 port

## Quick Start

### 1. Install Dependencies

```bash
sudo apt update
sudo apt install -y build-essential device-tree-compiler nvidia-l4t-kernel-headers
```

### 2. Build the Driver

```bash
cd patches_orin_nano_jp62/driver
./build.sh
```

Or using make directly:

```bash
make
```

### 3. Install

```bash
./build.sh install
```

Or:

```bash
sudo make install
```

### 4. Configure Bootloader

Edit `/boot/extlinux/extlinux.conf` and add the OVERLAYS line after the FDT line:

```
LABEL primary
    MENU LABEL primary kernel
    LINUX /boot/Image
    FDT /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv.dtb
    OVERLAYS /boot/tegra234-camera-imx708-orin-nano.dtbo
    ...
```

### 5. Reboot

```bash
sudo reboot
```

### 6. Validate

After reboot, run the validation script:

```bash
./validate.sh
```

Or check manually:

```bash
# Check module loaded
lsmod | grep imx708

# Check dmesg for probe
dmesg | grep imx708

# List video devices
v4l2-ctl --list-devices
```

## Usage

### Display Preview

```bash
SENSOR_ID=0
FRAMERATE=14
gst-launch-1.0 nvarguscamerasrc sensor-id=$SENSOR_ID ! \
    "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=$FRAMERATE/1" ! \
    nvvidconv ! xvimagesink
```

### MP4 Recording

```bash
gst-launch-1.0 -e nvarguscamerasrc sensor-id=0 ! \
    "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=14/1" ! \
    nvv4l2h264enc ! h264parse ! mp4mux ! \
    filesink location=test_recording.mp4
```

### JPEG Snapshots

```bash
gst-launch-1.0 -e nvarguscamerasrc num-buffers=10 sensor-id=0 ! \
    "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=14/1" ! \
    nvjpegenc ! multifilesink location=snapshot_%03d.jpg
```

### Raw Bayer Capture (v4l2)

```bash
v4l2-ctl -d /dev/video0 \
    --set-fmt-video=width=4608,height=2592,pixelformat=RG10 \
    --set-ctrl bypass_mode=0 \
    --stream-mmap \
    --stream-count=5 \
    --stream-to=capture.raw
```

## Supported Features

### Resolution and Framerate

| Mode | Resolution | Framerate |
|------|------------|-----------|
| 0    | 4608x2592  | 2-14 fps  |

### Controls

- Gain (analog)
- Exposure time
- Frame rate
- Group hold

## File Structure

```
driver/
├── src/
│   ├── nv_imx708.c          # Main driver source
│   ├── imx708_mode_tbls.h   # Mode register tables
│   └── Makefile
├── include/
│   └── imx708.h             # Driver header
├── dts/
│   └── tegra234-camera-imx708-orin-nano.dts  # Device tree overlay
├── Makefile                 # Main build Makefile
├── build.sh                 # Build script
├── validate.sh              # Installation validation
└── README.md                # This file
```

## Troubleshooting

### Module fails to load

Check kernel version matches:

```bash
uname -r
modinfo src/nv_imx708.ko | grep vermagic
```

If mismatch, rebuild with correct headers.

### No /dev/video0

1. Verify overlay is loaded:
   ```bash
   cat /proc/device-tree/tegra-camera-platform/modules/module0/badge
   ```

2. Check I2C communication:
   ```bash
   sudo i2cdetect -y -r 9
   # Should show device at 0x1a
   ```

3. Check physical connection to CAM0 port

### nvarguscamerasrc fails

This is expected without ISP tuning files. Use v4l2src for raw capture instead:

```bash
gst-launch-1.0 v4l2src device=/dev/video0 ! \
    'video/x-bayer,width=4608,height=2592,format=rggb' ! \
    bayer2rgb ! videoconvert ! xvimagesink
```

## Uninstall

```bash
./build.sh uninstall
```

Then remove the OVERLAYS line from `/boot/extlinux/extlinux.conf` and reboot.

## Credits

- Original driver by [RidgeRun Engineering](https://www.ridgerun.com)
- JetPack 6.2 port based on RidgeRun's JP6.0 patch
- Sony IMX708 sensor documentation

## License

GPL v2 - See source files for full license text.

## Support

For issues with this port, please open an issue on the repository.

For commercial support and additional camera drivers, contact RidgeRun at https://www.ridgerun.com/contact
