# IMX708 Camera Driver for JetPack 6.2

Out-of-tree driver for the Sony IMX708 camera sensor (Raspberry Pi Camera Module 3) on NVIDIA Jetson Orin Nano running JetPack 6.2 (L4T R36.4.x).

> ### ⚠️ Read this first — JetPack 6.2 specifics
>
> This README documents the **standard RidgeRun driver flow**, which targets
> JetPack 6.0. On **JetPack 6.2**, three of those steps do **not** work as
> written, and the top-level [installation guide](../../docs/installation.md) is
> the authoritative path:
>
> 1. **Use the corrected overlay**, not the bundled `dts/` one. The overlays in
>    this directory carry RidgeRun's original CSI parameters
>    (`channel@1`, `discontinuous_clk="yes"`, `lane_polarity="6"`), which cause
>    `uncorr_err: request timed out` on JP6.2. Use
>    [`../../docs/overlays/imx708-nvidia-csi.dts`](../../docs/overlays/imx708-nvidia-csi.dts)
>    (`channel@0`, `discontinuous_clk="no"`, `lane_polarity="0"`).
> 2. **Pre-merge the overlay** into the base DTB with `fdtoverlay` and use an
>    `FDT` line in `extlinux.conf`. The `OVERLAYS` directive and `jetson-io` are
>    ignored by the UEFI boot flow on JP6.2 — see
>    [`scripts/apply_overlay.sh`](scripts/apply_overlay.sh) and
>    [`scripts/fix_extlinux.sh`](scripts/fix_extlinux.sh).
> 3. **Capture with `v4l2-ctl`, not `nvarguscamerasrc`.** The `nvargus` examples
>    below require ISP tuning files that don't exist for the IMX708; use the raw
>    Bayer + Python path from the installation guide.
>
> The **build/install steps below (the kernel module) are still correct** — you
> do need `nv_imx708.ko` from here. It's only the overlay/boot/capture steps that
> differ on JP6.2.

## Important: CAM1 Port Only

**JetPack 6.2 only supports the IMX708 camera on the CAM1 port, NOT CAM0.**

Connect your camera ribbon cable to the **CAM1** connector on the Jetson Orin Nano (contacts facing toward the heatsink).

### Port Mapping

| Port | CSI Interface | I2C Bus | jetson-io Selection |
|------|---------------|---------|---------------------|
| CAM0 | serial_a | Bus 2 | IMX477-A |
| CAM1 | serial_c | Bus 9 (via cam_i2cmux) | IMX477-C |

## Prerequisites

- Jetson Orin Nano Developer Kit
- JetPack 6.2 (L4T R36.4.3) installed and booted
- IMX708-based camera (e.g., Arducam 12MP IMX708 Wide-Angle, Raspberry Pi Camera Module 3)
- Camera connected to CSI **CAM1** port

## Quick Start

### 1. Install Dependencies

```bash
sudo apt update
sudo apt install -y build-essential device-tree-compiler nvidia-l4t-kernel-headers
```

### 2. Build the Driver

```bash
cd NVIDIA-Jetson-IMX708-RPIV3/driver
./build.sh
```

Or using make directly:

```bash
make
```

### 3. Install

```bash
sudo ./build.sh install
```

Or:

```bash
sudo make install
```

### 4. Configure the device tree

> **JetPack 6.2:** skip `jetson-io` — its "Camera IMX477-C" mode causes capture
> timeouts, and the overlay it writes is ignored by UEFI. Instead, build the
> corrected overlay and pre-merge it into the base DTB:
>
> ```bash
> dtc -@ -I dts -O dtb -o imx708-nvidia-csi.dtbo \
>     ../../docs/overlays/imx708-nvidia-csi.dts
> sudo fdtoverlay -i <base-dtb> -o <merged-dtb> imx708-nvidia-csi.dtbo
> # then point the FDT line in extlinux.conf at <merged-dtb> and reboot
> ```
>
> [../../docs/installation.md](../../docs/installation.md) has the exact DTB
> paths. `scripts/apply_overlay.sh` + `scripts/fix_extlinux.sh` can automate the
> merge and boot wiring — adjust the `OVERLAY`/`DTB` variables at the top of
> those scripts to match the corrected overlay you built.

For reference, the standard JetPack 6.0 flow (does **not** work on JP6.2) was:

```bash
cd /opt/nvidia/jetson-io/
sudo python3 jetson-io.py
# Select "Camera IMX477-C" (C = CAM1 port)
# Save and reboot
```

### 5. Reboot

```bash
sudo reboot
```

### 6. Validate

After reboot, run the validation script:

```bash
./scripts/validate.sh
```

Or check manually:

```bash
# Check I2C - camera should appear at 0x1a on bus 9
sudo i2cdetect -y -r 9

# Check module loaded
lsmod | grep imx708

# Check dmesg for probe
dmesg | grep imx708

# List video devices
v4l2-ctl --list-devices
```

**Expected I2C output** (bus 9 for CAM1):
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- 1a -- -- -- -- --
...
```

## Usage

> **JetPack 6.2:** the `nvarguscamerasrc` pipelines below need ISP tuning files
> that don't exist for the IMX708 and will fail with black frames or errors. Use
> the [Raw Bayer Capture (v4l2)](#raw-bayer-capture-v4l2) method plus the Python
> processing in [../../docs/installation.md](../../docs/installation.md#image-capture-and-processing).
> The `nvargus` examples are retained for JetPack 6.0 / ISP-tuned setups.

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
│   ├── tegra234-camera-imx708-orin-nano.dts       # CAM0 device tree
│   └── tegra234-camera-imx708-orin-nano-cam1.dts  # CAM1 device tree
├── scripts/
│   ├── validate.sh          # Installation validation (7 tests)
│   ├── diagnose_full.sh     # Comprehensive diagnostic (15 sections)
│   ├── apply_overlay.sh     # Apply DTB overlay to boot partition
│   └── fix_extlinux.sh      # Fix extlinux.conf bootloader config
├── Makefile                 # Main build Makefile
├── build.sh                 # Build script
└── README.md                # This file
```

## Troubleshooting

### Camera not detected on I2C

1. Verify camera is connected to **CAM1** (not CAM0)
2. Verify the active `FDT` entry points to the pre-merged DTB described in
   [`../../docs/installation.md`](../../docs/installation.md)
3. Power cycle the Jetson (full shutdown, not just reboot)
4. Check cable orientation: contacts facing the heatsink

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

3. Check GPIO state:
   ```bash
   sudo cat /sys/kernel/debug/gpio | grep -iE "gpio-62|PJ"
   ```

4. Check device tree:
   ```bash
   sudo dtc -I fs -O dts /proc/device-tree 2>/dev/null | grep -A10 "imx708\|imx477"
   ```

### Full diagnostic

```bash
./scripts/diagnose_full.sh
```

### nvarguscamerasrc fails

This is expected without ISP tuning files. Use v4l2src for raw capture instead:

```bash
gst-launch-1.0 v4l2src device=/dev/video0 ! \
    'video/x-bayer,width=4608,height=2592,format=rggb' ! \
    bayer2rgb ! videoconvert ! xvimagesink
```

## Alternative: Arducam Official Installer

Arducam provides an official installer for IMX708 on JetPack 6.2:

```bash
cd ~
wget https://github.com/ArduCAM/MIPI_Camera/releases/download/v0.0.3/install_full.sh
chmod +x install_full.sh
./install_full.sh -m imx708
```

**Note**: Only CAM1 port is supported.

## Uninstall

```bash
./build.sh uninstall
```

Then revert your boot configuration and reboot. On **JetPack 6.2** that means
restoring the original `FDT` line in `/boot/extlinux/extlinux.conf` (or its
`.backup`) so it points at the stock DTB rather than the merged
`…-imx708-nvidia-csi.dtb`. On JetPack 6.0 setups, remove the `OVERLAYS` line
instead.

## Credits

- Original driver by [RidgeRun Engineering](https://www.ridgerun.com)
- JetPack 6.2 port based on RidgeRun's JP6.0 patch
- Sony IMX708 sensor documentation

## License

**GPL-2.0.** This driver is derived from RidgeRun's `nv_imx708` driver and the
Linux kernel. The full license text is in [`COPYING`](COPYING); the controlling
copyright and license notices are in each source file's header (NVIDIA,
RidgeRun, and Raspberry Pi Ltd).

## Support

For issues with this port, please open an issue on the repository.

For commercial support and additional camera drivers, contact RidgeRun at https://www.ridgerun.com/contact
