# IMX708 Driver Rebuild After GPIO Fix

The reset GPIO was incorrectly set to 54 (GEN1_I2C_SCL_PI3) instead of 62 (CAM0_PWDN = GPIO H6).
This fix enables proper camera reset control.

## Step 1: Pull the Fix

```bash
cd ~/dev/Nvidia-Jetson-Toolkit/NVIDIA-Jetson-IMX708-RPIV3/patches_orin_nano_jp62/driver
git pull
```

## Step 2: Rebuild Driver and DTBO

```bash
./build.sh
```

## Step 3: Install

```bash
sudo ./build.sh install
```

## Step 4: Re-apply Overlay to DTB Files

```bash
# Apply to kernel_ prefixed DTB
sudo fdtoverlay -i /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb.backup \
  -o /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb \
  /boot/tegra234-camera-imx708-orin-nano.dtbo

# Apply to non-prefixed DTB
sudo fdtoverlay -i /boot/tegra234-p3768-0000+p3767-0005-nv-super.dtb.backup \
  -o /boot/tegra234-p3768-0000+p3767-0005-nv-super.dtb \
  /boot/tegra234-camera-imx708-orin-nano.dtbo
```

## Step 5: Reboot

```bash
sudo reboot
```

---

## Verification Commands (After Reboot)

### Check I2C Detection

```bash
sudo i2cdetect -y -r 2
```

**Expected**: Device at address `1a` should appear:
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- 1a -- -- -- -- --
...
```

### Check GPIO State

```bash
sudo cat /sys/kernel/debug/gpio | grep -iE "H6|cam|62"
```

### Check Video Device

```bash
ls /dev/video*
```

**Expected**: `/dev/video0` should exist.

### Check Kernel Messages

```bash
sudo dmesg | grep -i imx708
```

**Expected**: Should show successful probe messages, no errors.

### Check Device Tree Node

```bash
ls /sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a/
```

### Full Diagnostic

```bash
./diagnose_full.sh
```

---

## Test Camera with GStreamer

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

### Camera still not detected on I2C

1. Power cycle the Jetson (full shutdown, not just reboot)
2. Check cable orientation: blue stripe UP on Jetson side, contacts DOWN
3. Try a different ribbon cable
4. Verify camera connector latches are fully closed

### GPIO not toggling

Check if GPIO 62 is being controlled:
```bash
sudo cat /sys/kernel/debug/gpio | grep -A5 -B5 "gpiochip0"
```

### Device tree node missing

Verify DTB has overlay applied:
```bash
dtc -I dtb -O dts /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb 2>/dev/null | grep -i imx708
```
