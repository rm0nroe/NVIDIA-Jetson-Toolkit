# IMX708 Driver Rebuild After GPIO Fix

The reset GPIO was incorrectly set using mainline Linux GPIO offset formula (7*8+6=62).
JetPack 6.2/L4T 36.4 uses different GPIO port offsets - PH.06 (CAM0_PWDN) is at offset **49**, not 62.

**Root Cause**: NVIDIA has [conflicting tegra234-gpio.h definitions](https://forums.developer.nvidia.com/t/conflicting-tegra234-gpio-defs/262485)
between mainline Linux and JetPack kernels.

**Fix**: Changed `reset-gpios = <&gpio 62 1>` to `reset-gpios = <&gpio 49 1>`

---

## Quick Start

```bash
# 1. Pull the fix
cd ~/dev/Nvidia-Jetson-Toolkit/NVIDIA-Jetson-IMX708-RPIV3/patches_orin_nano_jp62/driver
git pull

# 2. Rebuild and install
./build.sh
sudo ./build.sh install

# 3. Re-apply overlay to DTBs
sudo fdtoverlay -i /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb.backup -o /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb /boot/tegra234-camera-imx708-orin-nano.dtbo

sudo fdtoverlay -i /boot/tegra234-p3768-0000+p3767-0005-nv-super.dtb.backup -o /boot/tegra234-p3768-0000+p3767-0005-nv-super.dtb /boot/tegra234-camera-imx708-orin-nano.dtbo

# 4. Reboot
sudo reboot
```

---

## Verification (After Reboot)

```bash
# Check I2C - should show device at 0x1a
sudo i2cdetect -y -r 2

# Check video device - should show /dev/video0
ls /dev/video*

# Check kernel messages - should show successful probe
sudo dmesg | grep -i imx708
```

**Expected I2C output**:
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- 1a -- -- -- -- --
...
```

---

## Test Camera

```bash
SENSOR_ID=0
FRAMERATE=14

# Display test
gst-launch-1.0 nvarguscamerasrc sensor-id=$SENSOR_ID ! \
  "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=$FRAMERATE/1" ! \
  queue ! nvegltransform ! nveglglessink

# Record to MP4
gst-launch-1.0 -e nvarguscamerasrc sensor-id=$SENSOR_ID ! \
  "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=$FRAMERATE/1" ! \
  nvv4l2h264enc ! h264parse ! mp4mux ! filesink location=test.mp4
```

---

## Troubleshooting

### Camera not detected on I2C

1. Power cycle the Jetson (full shutdown, not just reboot)
2. Check cable orientation: blue stripe UP on Jetson side, contacts DOWN
3. Try a different ribbon cable
4. Verify camera connector latches are fully closed

### Check GPIO state

```bash
sudo cat /sys/kernel/debug/gpio | grep -iE "PH.06|gpio-397"
```

### Check device tree overlay applied

```bash
dtc -I dtb -O dts /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb 2>/dev/null | grep -i imx708
```

### Check device tree node exists

```bash
ls /sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a/
```

### Full diagnostic

```bash
./diagnose_full.sh
```
